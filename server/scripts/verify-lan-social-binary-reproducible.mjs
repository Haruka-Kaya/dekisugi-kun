import { createHash } from 'node:crypto'
import { readFile } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { spawn } from 'node:child_process'

const scriptDirectory = dirname(fileURLToPath(import.meta.url))
const serverRoot = resolve(scriptDirectory, '..')
const manifestPath = resolve(
  serverRoot,
  'dist',
  `dekisugi-lan-coordinator-${process.platform}-${process.arch}`,
  'build-manifest.json',
)
const packageName = `dekisugi-lan-coordinator-${process.platform}-${process.arch}`
const archivePath = resolve(
  serverRoot,
  'dist',
  process.platform === 'win32' ? `${packageName}.zip` : `${packageName}.tar.gz`,
)

const before = await manifest()
const beforeArchiveSha256 = await sha256(archivePath)
await run(process.platform === 'win32' ? 'npm.cmd' : 'npm', ['run', 'social:binary'])
const after = await manifest()
const afterArchiveSha256 = await sha256(archivePath)

if (before.sha256 !== after.sha256 ||
    beforeArchiveSha256 !== afterArchiveSha256 ||
    before.nodeVersion !== after.nodeVersion ||
    before.platform !== after.platform ||
    before.architecture !== after.architecture) {
  throw new Error(
    [
      'LAN coordinator package is not reproducible:',
      `executable ${before.sha256} != ${after.sha256}`,
      `archive ${beforeArchiveSha256} != ${afterArchiveSha256}`,
    ].join(' '),
  )
}

process.stdout.write([
  `Reproducible SEA SHA-256: ${after.sha256}`,
  `Reproducible archive SHA-256: ${afterArchiveSha256}`,
  '',
].join('\n'))

async function manifest() {
  return JSON.parse(await readFile(manifestPath, 'utf8'))
}

async function sha256(path) {
  return createHash('sha256').update(await readFile(path)).digest('hex')
}

async function run(command, args) {
  await new Promise((resolveRun, rejectRun) => {
    const child = spawn(command, args, {
      cwd: serverRoot,
      stdio: 'inherit',
      shell: false,
      env: process.env,
    })
    child.once('error', rejectRun)
    child.once('close', (code, signal) => {
      if (code === 0) resolveRun()
      else rejectRun(new Error(
        `${command} failed (${signal ? `signal ${signal}` : `exit ${code}`})`,
      ))
    })
  })
}
