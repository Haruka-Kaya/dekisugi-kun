import { createHash } from 'node:crypto'
import { createReadStream, createWriteStream } from 'node:fs'
import {
  chmod,
  copyFile,
  mkdir,
  readFile,
  readdir,
  rename,
  rm,
  utimes,
  writeFile,
} from 'node:fs/promises'
import { basename, dirname, join, resolve } from 'node:path'
import { pipeline } from 'node:stream/promises'
import { fileURLToPath } from 'node:url'
import { createGzip } from 'node:zlib'
import { spawn } from 'node:child_process'

import { build } from 'esbuild'
import yazl from 'yazl'

const scriptDirectory = dirname(fileURLToPath(import.meta.url))
const serverRoot = resolve(scriptDirectory, '..')
const distRoot = resolve(serverRoot, 'dist')
const platform = process.platform
const architecture = process.arch
const builderNode = resolve(process.env.DEKISUGI_SEA_NODE || process.execPath)
const executableName = platform === 'win32'
  ? 'dekisugi-lan-coordinator.exe'
  : 'dekisugi-lan-coordinator'
const packageName = `dekisugi-lan-coordinator-${platform}-${architecture}`
const outputDirectory = resolve(distRoot, packageName)
const reproducibleTimestamp = new Date('2000-01-01T00:00:00.000Z')
// ZIPのDOS timestampはlocal getterを使うため、全timezoneで同じfieldになるlocal date。
const reproducibleZipTimestamp = new Date(2000, 0, 1, 0, 0, 0, 0)

const builderVersion = await nodeVersion(builderNode)
assertSupportedBuilder(builderVersion)
assertChildOf(outputDirectory, distRoot)

await mkdir(distRoot, { recursive: true })
const workDirectory = resolve(distRoot, `.sea-build-${platform}-${architecture}`)
const stagedPackage = resolve(distRoot, `.${packageName}.${process.pid}.tmp`)
const temporaryTar = resolve(distRoot, `.${packageName}.${process.pid}.tar.tmp`)
assertChildOf(workDirectory, distRoot)
assertChildOf(temporaryTar, distRoot)

try {
  await rm(workDirectory, { recursive: true, force: true })
  await mkdir(workDirectory, { recursive: true })
  await rm(stagedPackage, { recursive: true, force: true })
  await mkdir(stagedPackage, { recursive: true })
  await rm(temporaryTar, { force: true })

  const bundle = resolve(workDirectory, 'lan-social-coordinator.cjs')
  await build({
    entryPoints: [resolve(serverRoot, 'scripts/lan-social-server.ts')],
    outfile: bundle,
    bundle: true,
    platform: 'node',
    format: 'cjs',
    target: 'node26',
    sourcemap: false,
    legalComments: 'none',
    minify: false,
    packages: 'bundle',
  })
  // esbuildは同じES moduleでもcheckout境界の判定によって先頭の
  // `"use strict";`だけを増減させることがある。bundle本体は同一なので、
  // SEA入力を意味保存の形で正規化し、source directory依存を除く。
  const bundledSource = await readFile(bundle, 'utf8')
  const normalizedBundle = bundledSource.replace(/^"use strict";\r?\n/, '')
  if (normalizedBundle.includes(serverRoot)) {
    throw new Error('absolute checkout path leaked into LAN coordinator bundle')
  }
  await writeFile(bundle, normalizedBundle, 'utf8')

  const builtExecutable = resolve(workDirectory, executableName)
  const executable = resolve(stagedPackage, executableName)
  const seaConfiguration = resolve(workDirectory, 'sea-config.json')
  await writeFile(
    seaConfiguration,
    `${JSON.stringify({
      // SEA payloadへcheckoutの絶対pathを埋め込まない。設定fileとbuilderの
      // cwdをwork directoryへ揃え、同じsourceを別directoryでbuildしても
      // 同じ実行fileになるよう相対pathだけを渡す。
      main: basename(bundle),
      mainFormat: 'commonjs',
      executable: builderNode,
      output: executableName,
      disableExperimentalSEAWarning: true,
      useSnapshot: false,
      useCodeCache: false,
      execArgvExtension: 'none',
    }, null, 2)}\n`,
    'utf8',
  )
  await run(
    builderNode,
    ['--build-sea', basename(seaConfiguration)],
    workDirectory,
  )
  // SEA injectionで公式Nodeの既存署名は無効になる。pilot artifactは実行可能性の
  // ためad-hoc再署名し、Developer ID署名済みとは主張しない。
  if (platform === 'darwin') {
    await run('/usr/bin/codesign', [
      '--sign', '-',
      '--force',
      '--timestamp=none',
      '--identifier', 'jp.dekisugi.lan-coordinator',
      builtExecutable,
    ], serverRoot)
  }
  if (platform !== 'win32') await chmod(builtExecutable, 0o755)
  await copyFile(builtExecutable, executable)
  if (platform !== 'win32') await chmod(executable, 0o755)

  const launcher = platform === 'win32' ? 'start-coordinator.cmd' :
    platform === 'darwin' ? 'start-coordinator.command' : 'start-coordinator.sh'
  await copyFile(
    resolve(serverRoot, 'coordinator-launchers', launcher),
    resolve(stagedPackage, launcher),
  )
  if (platform !== 'win32') {
    await chmod(resolve(stagedPackage, launcher), 0o755)
  }

  const digest = await sha256(executable)
  const manifest = {
    formatVersion: 1,
    protocolVersion: 1,
    platform,
    architecture,
    nodeVersion: builderVersion,
    executable: executableName,
    sha256: digest,
    codeSigning: platform === 'darwin' ? 'ad-hoc-pilot' : 'none',
    generatedSecrets: false,
    runtimeStateLocation: 'OS user data directory unless --data is supplied',
  }
  await writeFile(
    resolve(stagedPackage, 'build-manifest.json'),
    `${JSON.stringify(manifest, null, 2)}\n`,
    'utf8',
  )
  await writeFile(
    resolve(stagedPackage, 'SHA256SUMS.txt'),
    `${digest}  ${executableName}\n`,
    'utf8',
  )
  await copyFile(
    resolve(serverRoot, 'coordinator-launchers', 'README.txt'),
    resolve(stagedPackage, 'README.txt'),
  )

  // Build時には鍵・管理キー・room状態を生成しない。成果物に紛れ込んだ場合は停止する。
  const packagedNames = new Set([
    executableName,
    launcher,
    'build-manifest.json',
    'SHA256SUMS.txt',
    'README.txt',
  ])
  const stagedNames = new Set(await readdir(stagedPackage))
  if (stagedNames.size !== packagedNames.size ||
      [...stagedNames].some((name) => !packagedNames.has(name))) {
    throw new Error('unexpected file in LAN coordinator artifact')
  }
  // tar/zipへ実行時刻を混ぜない。同じNode・platform・arch・sourceなら、
  // 配布archiveまで同じSHA-256になることをreproducibility testで固定する。
  await Promise.all([
    ...[...packagedNames].map((name) => utimes(
      resolve(stagedPackage, name),
      reproducibleTimestamp,
      reproducibleTimestamp,
    )),
    utimes(stagedPackage, reproducibleTimestamp, reproducibleTimestamp),
  ])

  await rm(outputDirectory, { recursive: true, force: true })
  await rename(stagedPackage, outputDirectory)
  const archiveName = platform === 'win32' ? `${packageName}.zip` : `${packageName}.tar.gz`
  const archivePath = resolve(distRoot, archiveName)
  const archiveChecksumPath = `${archivePath}.sha256`
  await Promise.all([
    rm(archivePath, { force: true }),
    rm(archiveChecksumPath, { force: true }),
  ])
  if (platform === 'win32') {
    await writeDeterministicZip(stagedNames, outputDirectory, archivePath)
  } else {
    const normalizedOwner = platform === 'darwin'
      ? ['--uid', '0', '--gid', '0', '--uname', 'root', '--gname', 'root']
      : ['--owner=0', '--group=0', '--numeric-owner', '--sort=name']
    await run(
      'tar',
      [...normalizedOwner, '-cf', temporaryTar, '-C', distRoot, packageName],
      distRoot,
      { ...process.env, COPYFILE_DISABLE: '1' },
    )
    // bsdtarのgzip headerは現在時刻を含む。Node zlibのmtime=0 headerで
    // 同一tarを圧縮し、配布archive自体も再現可能にする。
    await pipeline(
      createReadStream(temporaryTar),
      createGzip({ level: 9 }),
      createWriteStream(archivePath, { flags: 'wx', mode: 0o644 }),
    )
    await rm(temporaryTar, { force: true })
  }
  const archiveDigest = await sha256(archivePath)
  await writeFile(
    archiveChecksumPath,
    `${archiveDigest}  ${archiveName}\n`,
    'utf8',
  )
  process.stdout.write([
    `LAN coordinator package: ${outputDirectory}`,
    `Executable SHA-256: ${digest}`,
    `Archive: ${archivePath}`,
    `Archive SHA-256: ${archiveDigest}`,
    'TLS key, coordinator key, room state: runtime generation only',
    '',
  ].join('\n'))
} finally {
  await Promise.allSettled([
    rm(workDirectory, { recursive: true, force: true }),
    rm(stagedPackage, { recursive: true, force: true }),
    rm(temporaryTar, { force: true }),
  ])
}

function assertSupportedBuilder(version) {
  const [major, minor] = version.split('.').map(Number)
  if (major < 26 || (major === 26 && minor < 5)) {
    throw new Error(
      `LAN coordinator SEA build requires Node.js >=26.5 (builder ${version})`,
    )
  }
}

function assertChildOf(candidate, parent) {
  if (dirname(candidate) !== parent || basename(candidate) === '' || candidate === parent) {
    throw new Error('unsafe LAN coordinator output directory')
  }
}

async function sha256(path) {
  return createHash('sha256').update(await readFile(path)).digest('hex')
}

async function writeDeterministicZip(names, sourceDirectory, archivePath) {
  const zip = new yazl.ZipFile()
  zip.once('error', (error) => zip.outputStream.destroy(error))
  const writeFinished = pipeline(
    zip.outputStream,
    createWriteStream(archivePath, { flags: 'wx', mode: 0o644 }),
  )
  zip.addEmptyDirectory(`${packageName}/`, {
    mtime: reproducibleZipTimestamp,
    mode: 0o40755,
    forceDosTimestamp: true,
  })
  for (const name of [...names].sort()) {
    zip.addFile(
      resolve(sourceDirectory, name),
      `${packageName}/${name}`,
      {
        mtime: reproducibleZipTimestamp,
        mode: 0o100644,
        compressionLevel: 9,
        forceDosTimestamp: true,
      },
    )
  }
  zip.end({ forceZip64Format: false })
  await writeFinished
}

async function nodeVersion(command) {
  return new Promise((resolveVersion, rejectVersion) => {
    const child = spawn(command, ['--version'], {
      cwd: serverRoot,
      stdio: ['ignore', 'pipe', 'pipe'],
      shell: false,
    })
    let stdout = ''
    let stderr = ''
    child.stdout.setEncoding('utf8')
    child.stderr.setEncoding('utf8')
    child.stdout.on('data', (chunk) => { stdout += chunk })
    child.stderr.on('data', (chunk) => { stderr += chunk })
    child.once('error', rejectVersion)
    child.once('close', (code) => {
      if (code !== 0) {
        rejectVersion(new Error(`SEA builder Node failed (${code}): ${stderr.trim()}`))
        return
      }
      const match = /^v(\d+\.\d+\.\d+)$/u.exec(stdout.trim())
      if (!match) {
        rejectVersion(new Error(`unexpected SEA builder version: ${stdout.trim()}`))
        return
      }
      resolveVersion(match[1])
    })
  })
}

async function run(command, args, cwd, environment = process.env) {
  await new Promise((resolveRun, rejectRun) => {
    const child = spawn(command, args, {
      cwd,
      env: environment,
      stdio: 'inherit',
      shell: false,
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
