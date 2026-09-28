import { networkInterfaces } from 'node:os'
import { homedir } from 'node:os'
import { join, resolve } from 'node:path'
import { isSea } from 'node:sea'

import { createLanSocialHttpServer, isPrivateLanAddress } from '../lib/lan-social-http.js'
import { LanSocialCoordinator, LanSocialFileStore } from '../lib/lan-social.js'
import { openLanSocialTlsIdentity } from '../lib/lan-social-tls.js'

type CliOptions = {
  host: string
  port: number
  data: string
  allowLan: boolean
}

function parseArgs(argv: string[]): CliOptions {
  const options: CliOptions = {
    host: '127.0.0.1',
    port: 8787,
    data: defaultDataPath(),
    allowLan: false,
  }
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index]
    const next = argv[index + 1]
    if (arg === '--host' && next) {
      options.host = next
      index += 1
    } else if (arg === '--port' && next) {
      options.port = Number(next)
      index += 1
    } else if (arg === '--data' && next) {
      options.data = resolve(next)
      index += 1
    } else if (arg === '--allow-lan') {
      options.allowLan = true
    } else {
      throw new Error(`unknown argument: ${arg}`)
    }
  }
  if (!Number.isInteger(options.port) || options.port < 1 || options.port > 65_535) {
    throw new Error('port must be 1-65535')
  }
  const wildcard = options.host === '0.0.0.0' || options.host === '::'
  if (wildcard && !options.allowLan) {
    throw new Error('LANへ公開するときは --allow-lan を明示してください')
  }
  if (!wildcard && !isPrivateLanAddress(options.host)) {
    throw new Error('hostはloopbackまたはprivate LAN addressだけです')
  }
  if (process.env.VERCEL_ENV !== undefined) {
    throw new Error('LAN coordinatorはVercel環境では起動しません')
  }
  return options
}

function defaultDataPath(): string {
  if (!isSea()) return resolve('.local-data/lan-social-v1.json')
  const applicationDirectory = process.platform === 'win32'
    ? join(process.env.LOCALAPPDATA || join(homedir(), 'AppData', 'Local'), 'Dekisugi')
    : process.platform === 'darwin'
      ? join(homedir(), 'Library', 'Application Support', 'Dekisugi')
      : join(process.env.XDG_STATE_HOME || join(homedir(), '.local', 'state'), 'dekisugi')
  return join(applicationDirectory, 'lan-social-v1.json')
}

async function main(): Promise<void> {
  const options = parseArgs(process.argv.slice(2))
  const store = await LanSocialFileStore.open(options.data)
  const coordinator = new LanSocialCoordinator(store)
  const tls = await openLanSocialTlsIdentity(resolve(options.data, '..'))
  const server = createLanSocialHttpServer({ coordinator, tls })

  await new Promise<void>((resolveListen, reject) => {
    server.once('error', reject)
    server.listen(options.port, options.host, () => resolveListen())
  })

  const urls = options.host === '0.0.0.0' || options.host === '::'
    ? privateIpv4Addresses().map((address) => `https://${address}:${options.port}`)
    : [`https://${options.host.includes(':') ? `[${options.host}]` : options.host}:${options.port}`]

  process.stdout.write([
    'デキすぎ君 LAN social coordinator を開始しました。',
    `保存先: ${options.data}`,
    ...urls.map((url) => `接続先: ${url}`),
    `証明書SHA-256: ${tls.fingerprintSha256}`,
    `証明書期限: ${tls.validTo}`,
    `管理キー: ${store.coordinatorKey}`,
    '管理者は接続先・証明書SHA-256・管理キーをアプリの部屋作成画面へ入力します。',
    '参加者へ渡すDKS1参加コードに管理キーは入りません。',
    '',
  ].join('\n'))

  const stop = () => {
    server.close(() => process.exit(0))
  }
  process.once('SIGINT', stop)
  process.once('SIGTERM', stop)
}

void main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : 'unknown coordinator failure'
  process.stderr.write(`LAN coordinatorを開始できません: ${message}\n`)
  process.exitCode = 1
})

function privateIpv4Addresses(): string[] {
  const out = new Set<string>()
  for (const values of Object.values(networkInterfaces())) {
    for (const value of values ?? []) {
      if (value.family === 'IPv4' && !value.internal && isPrivateLanAddress(value.address)) {
        out.add(value.address)
      }
    }
  }
  return [...out].sort()
}
