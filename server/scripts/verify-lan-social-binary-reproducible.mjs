import { createHash } from 'node:crypto'
import {
  cp,
  copyFile,
  mkdir,
  mkdtemp,
  readFile,
  rm,
} from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { spawn } from 'node:child_process'

const scriptDirectory = dirname(fileURLToPath(import.meta.url))
const serverRoot = resolve(scriptDirectory, '..')
const packageName = `dekisugi-lan-coordinator-${process.platform}-${process.arch}`

const before = await manifest(serverRoot)
const beforeArchiveSha256 = await archiveSha256(serverRoot)
await buildAt(serverRoot)
const after = await manifest(serverRoot)
const afterArchiveSha256 = await archiveSha256(serverRoot)

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

// 同じcheckout内の連続buildだけでは、絶対pathがpayloadへ混入していても
// 見逃す。必要sourceと同じnode_modulesを別directoryへ置き、そこから作った
// executable/archiveも完全一致することを検査する。
const relocatedRoot = await relocatedServerRoot()
try {
  await buildAt(relocatedRoot)
  const relocated = await manifest(relocatedRoot)
  const relocatedArchiveSha256 = await archiveSha256(relocatedRoot)
  if (after.sha256 !== relocated.sha256 ||
      afterArchiveSha256 !== relocatedArchiveSha256 ||
      after.nodeVersion !== relocated.nodeVersion ||
      after.platform !== relocated.platform ||
      after.architecture !== relocated.architecture) {
    throw new Error(
      [
        'LAN coordinator package depends on checkout path:',
        `executable ${after.sha256} != ${relocated.sha256}`,
        `archive ${afterArchiveSha256} != ${relocatedArchiveSha256}`,
      ].join(' '),
    )
  }
} finally {
  await rm(relocatedRoot, { recursive: true, force: true })
}

process.stdout.write([
  `Reproducible SEA SHA-256: ${after.sha256}`,
  `Reproducible archive SHA-256: ${afterArchiveSha256}`,
  'Reproducible from a relocated source directory: passed',
  '',
].join('\n'))

async function manifest(root) {
  return JSON.parse(await readFile(resolve(
    root,
    'dist',
    packageName,
    'build-manifest.json',
  ), 'utf8'))
}

async function archiveSha256(root) {
  return sha256(resolve(
    root,
    'dist',
    process.platform === 'win32' ? `${packageName}.zip` : `${packageName}.tar.gz`,
  ))
}

async function sha256(path) {
  return createHash('sha256').update(await readFile(path)).digest('hex')
}

async function relocatedServerRoot() {
  const root = await mkdtemp(join(tmpdir(), 'dekisugi-lan-repro-'))
  await Promise.all([
    cp(resolve(serverRoot, 'lib'), resolve(root, 'lib'), { recursive: true }),
    cp(resolve(serverRoot, 'scripts'), resolve(root, 'scripts'), { recursive: true }),
    cp(
      resolve(serverRoot, 'coordinator-launchers'),
      resolve(root, 'coordinator-launchers'),
      { recursive: true },
    ),
    copyFile(resolve(serverRoot, 'package.json'), resolve(root, 'package.json')),
    cp(
      resolve(serverRoot, 'node_modules'),
      resolve(root, 'node_modules'),
      { recursive: true },
    ),
    mkdir(resolve(root, 'dist'), { recursive: true }),
  ])
  return root
}

async function buildAt(root) {
  // package scriptの実体を同じNodeで直接起動する。Windowsでnpm.cmdを
  // shell:false spawnするとEINVALになる一方、shell:trueは不要な解釈面を増やす。
  // script pathは各rootから解決し、relocated checkoutの独立検証を維持する。
  await run(
    process.execPath,
    [resolve(root, 'scripts', 'build-lan-social-binary.mjs')],
    root,
  )
}

async function run(command, args, cwd) {
  await new Promise((resolveRun, rejectRun) => {
    const child = spawn(command, args, {
      cwd,
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
