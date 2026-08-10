import assert from 'node:assert/strict'
import { X509Certificate } from 'node:crypto'
import { copyFile, mkdtemp, readFile, rm, stat } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { afterEach, describe, it } from 'node:test'

import { openLanSocialTlsIdentity } from '../lib/lan-social-tls.js'

const temporaryDirectories: string[] = []

afterEach(async () => {
  while (temporaryDirectories.length > 0) {
    await rm(temporaryDirectories.pop()!, { recursive: true, force: true })
  }
})

async function directory(): Promise<string> {
  const value = await mkdtemp(join(tmpdir(), 'dekisugi-lan-tls-'))
  temporaryDirectories.push(value)
  return value
}

describe('LAN coordinator TLS identity', () => {
  it('初回生成後は同じ証明書を再利用しpinを勝手に変えない', async () => {
    const path = await directory()
    const first = await openLanSocialTlsIdentity(path)
    const second = await openLanSocialTlsIdentity(path)
    assert.equal(first.fingerprintSha256, second.fingerprintSha256)
    assert.match(first.fingerprintSha256, /^[a-f0-9]{64}$/)
    assert.deepEqual(first.cert, second.cert)
    assert.deepEqual(first.key, second.key)

    const cert = new X509Certificate(
      await readFile(join(path, 'coordinator-cert.pem')),
    )
    assert.equal(
      first.fingerprintSha256,
      cert.fingerprint256.replaceAll(':', '').toLowerCase(),
    )
  })

  it('証明書と秘密鍵はowner read/writeだけにする', async () => {
    const path = await directory()
    await openLanSocialTlsIdentity(path)
    for (const file of ['coordinator-cert.pem', 'coordinator-key.pem']) {
      const mode = (await stat(join(path, file))).mode & 0o777
      assert.equal(mode, 0o600, `${file} mode=${mode.toString(8)}`)
    }
  })

  it('別coordinatorの秘密鍵へ置換されても再生成せず起動を止める', async () => {
    const first = await directory()
    const second = await directory()
    await openLanSocialTlsIdentity(first)
    await openLanSocialTlsIdentity(second)
    await copyFile(
      join(second, 'coordinator-key.pem'),
      join(first, 'coordinator-key.pem'),
    )
    await assert.rejects(
      openLanSocialTlsIdentity(first),
      /一致しません/,
    )
  })

  it('OpenSSLの無いPATHでもNode WebCryptoだけでRSA 3072 identityを作る', async () => {
    const path = await directory()
    const originalPath = process.env.PATH
    process.env.PATH = ''
    try {
      const identity = await openLanSocialTlsIdentity(path)
      const certificate = new X509Certificate(identity.cert)
      assert.equal(certificate.subject, 'CN=dekisugi-lan-coordinator')
      assert.equal(certificate.issuer, certificate.subject)
      assert.equal(certificate.ca, false)
      assert.equal(certificate.verify(certificate.publicKey), true)
      assert.equal(
        certificate.publicKey.asymmetricKeyDetails?.modulusLength,
        3072,
      )
    } finally {
      if (originalPath === undefined) delete process.env.PATH
      else process.env.PATH = originalPath
    }
  })
})
