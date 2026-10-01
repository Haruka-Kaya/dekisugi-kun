import {
  X509Certificate,
  createPrivateKey,
  createPublicKey,
  timingSafeEqual,
} from 'node:crypto'
import { readFile, rename, rm, stat, writeFile } from 'node:fs/promises'
import { join } from 'node:path'

import { generate } from 'selfsigned'

import {
  finalizeLanSocialAtomicFile,
  protectLanSocialDirectory,
  protectLanSocialFile,
} from './lan-social-file-security.js'

export type LanSocialTlsIdentity = {
  key: Buffer
  cert: Buffer
  /** QR/接続コードへ入れる、lowercase 64桁のSHA-256 fingerprint。 */
  fingerprintSha256: string
  validTo: string
}

/**
 * coordinator固有の自己署名TLS identityを作成または復元する。
 *
 * 証明書を黙って再生成すると既存端末のpinが突然別サーバを許す余地になるため、
 * 既存ファイルが壊れている・期限切れの場合は起動を止める。
 */
export async function openLanSocialTlsIdentity(
  directory: string,
): Promise<LanSocialTlsIdentity> {
  // Windowsのmode option/chmodはPOSIXのowner/group/otherを表現しないため、
  // fileを作る前に親directoryのACL自体をcurrent userだけへ限定する。
  await protectLanSocialDirectory(directory)
  const certPath = join(directory, 'coordinator-cert.pem')
  const keyPath = join(directory, 'coordinator-key.pem')
  const certExists = await exists(certPath)
  const keyExists = await exists(keyPath)
  if (certExists !== keyExists) {
    throw new Error('TLS certificate/keyの片方だけが存在します。自動修復せず停止します')
  }
  if (!certExists) {
    await generateIdentity(directory, certPath, keyPath)
  }
  // 古いversionが作ったfileや手動copyにも明示的に同じ契約を適用してから読む。
  await Promise.all([
    protectLanSocialFile(certPath),
    protectLanSocialFile(keyPath),
  ])
  const [cert, key] = await Promise.all([readFile(certPath), readFile(keyPath)])
  const certificate = new X509Certificate(cert)
  const validFrom = Date.parse(certificate.validFrom)
  const validTo = Date.parse(certificate.validTo)
  if (!Number.isFinite(validFrom) || !Number.isFinite(validTo) ||
      validFrom > Date.now() + 5 * 60_000 || validTo <= Date.now()) {
    throw new Error('LAN coordinator TLS certificateが有効期間外です')
  }
  const privateKey = createPrivateKey(key)
  const publicFromPrivate = createPublicKey(privateKey).export({
    format: 'der',
    type: 'spki',
  })
  const publicFromCertificate = certificate.publicKey.export({
    format: 'der',
    type: 'spki',
  })
  if (publicFromPrivate.length !== publicFromCertificate.length ||
      !timingSafeEqual(publicFromPrivate, publicFromCertificate) ||
      certificate.subject !== certificate.issuer ||
      !certificate.verify(certificate.publicKey)) {
    throw new Error('LAN coordinator TLS certificateと秘密鍵が一致しません')
  }
  return {
    cert,
    key,
    fingerprintSha256: certificate.fingerprint256.replaceAll(':', '').toLowerCase(),
    validTo: new Date(validTo).toISOString(),
  }
}

async function generateIdentity(
  directory: string,
  certPath: string,
  keyPath: string,
): Promise<void> {
  const suffix = `${process.pid}-${Date.now()}`
  const temporaryCert = join(directory, `coordinator-cert.${suffix}.tmp`)
  const temporaryKey = join(directory, `coordinator-key.${suffix}.tmp`)
  // Node WebCryptoだけで生成する。CNへ端末・学校・人の名前を入れず、秘密鍵を
  // build artifactや参加コードへ焼き込まない。5分の時計ずれだけを許容する。
  const now = Date.now()
  const identity = await generate(
    [{ name: 'commonName', value: 'dekisugi-lan-coordinator' }],
    {
      keyType: 'rsa',
      keySize: 3072,
      algorithm: 'sha256',
      notBeforeDate: new Date(now - 5 * 60_000),
      notAfterDate: new Date(now + 365 * 86_400_000),
      extensions: [
        { name: 'basicConstraints', cA: false, critical: true },
        {
          name: 'keyUsage',
          digitalSignature: true,
          keyEncipherment: true,
          critical: true,
        },
        { name: 'extKeyUsage', serverAuth: true },
      ],
    },
  )
  try {
    await Promise.all([
      writeFile(temporaryCert, identity.cert, {
        encoding: 'utf8',
        flag: 'wx',
        mode: 0o600,
      }),
      writeFile(temporaryKey, identity.private, {
        encoding: 'utf8',
        flag: 'wx',
        mode: 0o600,
      }),
    ])
    // 片方だけ見える窓を小さくする。途中停止時は次回が片側検知でfail-closedになる。
    await rename(temporaryKey, keyPath)
    await rename(temporaryCert, certPath)
    await Promise.all([
      finalizeLanSocialAtomicFile(certPath),
      finalizeLanSocialAtomicFile(keyPath),
    ])
  } catch (error) {
    await Promise.allSettled([
      rm(temporaryCert, { force: true }),
      rm(temporaryKey, { force: true }),
    ])
    throw error
  }
}

async function exists(path: string): Promise<boolean> {
  try {
    await stat(path)
    return true
  } catch (error) {
    if (error && typeof error === 'object' && 'code' in error && error.code === 'ENOENT') {
      return false
    }
    throw error
  }
}
