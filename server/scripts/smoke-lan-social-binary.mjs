import { X509Certificate, createHash } from 'node:crypto'
import { mkdir, mkdtemp, readFile, readdir, rm, stat } from 'node:fs/promises'
import { request } from 'node:https'
import { createServer } from 'node:net'
import { tmpdir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { spawn } from 'node:child_process'

const scriptDirectory = dirname(fileURLToPath(import.meta.url))
const serverRoot = resolve(scriptDirectory, '..')
const platform = process.platform
const architecture = process.arch
const executableName = platform === 'win32'
  ? 'dekisugi-lan-coordinator.exe'
  : 'dekisugi-lan-coordinator'
const packageName = `dekisugi-lan-coordinator-${platform}-${architecture}`
const distRoot = resolve(serverRoot, 'dist')
const archiveName = platform === 'win32' ? `${packageName}.zip` : `${packageName}.tar.gz`
const archivePath = resolve(distRoot, archiveName)
const temporaryDirectory = await mkdtemp(join(tmpdir(), 'dekisugi-lan-smoke-'))
const extractionDirectory = resolve(temporaryDirectory, 'extracted')
const packageDirectory = resolve(extractionDirectory, packageName)
const executable = resolve(packageDirectory, executableName)
const dataPath = resolve(temporaryDirectory, 'state', 'lan-social-v1.json')
const port = await freeLoopbackPort()
let child

try {
  const archiveDigest = createHash('sha256')
    .update(await readFile(archivePath))
    .digest('hex')
  const expectedArchiveLine = `${archiveDigest}  ${archiveName}\n`
  if (await readFile(`${archivePath}.sha256`, 'utf8') !== expectedArchiveLine) {
    throw new Error('archive SHA-256 sidecar does not match')
  }
  await mkdir(extractionDirectory, { recursive: true })
  await extractArchive(archivePath, extractionDirectory)
  if (platform !== 'win32') {
    const launcherName = platform === 'darwin'
      ? 'start-coordinator.command'
      : 'start-coordinator.sh'
    for (const path of [executable, resolve(packageDirectory, launcherName)]) {
      if (((await stat(path)).mode & 0o111) === 0) {
        throw new Error(`archive lost executable permission: ${path}`)
      }
    }
  }
  child = spawn(executable, [
    '--host', '127.0.0.1',
    '--port', String(port),
    '--data', dataPath,
  ], {
    cwd: temporaryDirectory,
    env: { ...process.env, PATH: '' },
    shell: false,
    stdio: ['ignore', 'pipe', 'pipe'],
  })
  const output = await waitForStartup(child)
  const health = await secureHealth(port)
  if (health.ok !== true || health.protocolVersion !== 1 ||
      health.storage !== 'coordinator_local_only') {
    throw new Error(`unexpected coordinator health: ${JSON.stringify(health)}`)
  }

  const state = JSON.parse(await readFile(dataPath, 'utf8'))
  const certificatePath = resolve(dataPath, '..', 'coordinator-cert.pem')
  const privateKeyPath = resolve(dataPath, '..', 'coordinator-key.pem')
  const certificate = new X509Certificate(await readFile(certificatePath))
  const privateKey = await readFile(privateKeyPath, 'utf8')
  const pin = certificate.fingerprint256.replaceAll(':', '').toLowerCase()
  if (!output.includes(`証明書SHA-256: ${pin}`) ||
      !output.includes(`管理キー: ${state.coordinatorKey}`)) {
    throw new Error('runtime setup values were not printed exactly')
  }
  if (state.rooms.length !== 0) throw new Error('smoke start unexpectedly created a room')

  const packaged = await readdir(packageDirectory)
  for (const name of packaged) {
    const bytes = await readFile(resolve(packageDirectory, name))
    if (bytes.includes(Buffer.from(state.coordinatorKey)) ||
        bytes.includes(Buffer.from(privateKey))) {
      throw new Error(`runtime secret leaked into build artifact: ${name}`)
    }
  }
  const manifest = JSON.parse(
    await readFile(resolve(packageDirectory, 'build-manifest.json'), 'utf8'),
  )
  const executableDigest = createHash('sha256')
    .update(await readFile(executable))
    .digest('hex')
  if (manifest.sha256 !== executableDigest || manifest.generatedSecrets !== false) {
    throw new Error('build manifest does not match executable')
  }

  process.stdout.write([
    `SEA smoke passed: ${platform}-${architecture}`,
    'Archive checksum/extraction: passed',
    'HTTPS health: protocol v1 / coordinator_local_only',
    'PATH empty: OpenSSL and Node runtime not required',
    'Runtime secrets: generated outside artifact and absent from package',
    '',
  ].join('\n'))
} finally {
  if (child && child.exitCode === null) {
    child.kill('SIGTERM')
    await Promise.race([
      new Promise((resolveExit) => child.once('exit', resolveExit)),
      new Promise((resolveTimeout) => setTimeout(resolveTimeout, 2_000)),
    ])
    if (child.exitCode === null) child.kill('SIGKILL')
  }
  await rm(temporaryDirectory, { recursive: true, force: true })
}

async function extractArchive(archive, destination) {
  await new Promise((resolveExtract, rejectExtract) => {
    const child = spawn('tar', ['-xf', archive, '-C', destination], {
      cwd: serverRoot,
      stdio: ['ignore', 'pipe', 'pipe'],
      shell: false,
    })
    let stderr = ''
    child.stderr.setEncoding('utf8')
    child.stderr.on('data', (chunk) => { stderr += chunk })
    child.once('error', rejectExtract)
    child.once('close', (code, signal) => {
      if (code === 0) resolveExtract()
      else rejectExtract(new Error(
        `archive extraction failed (${signal || code}): ${stderr}`,
      ))
    })
  })
}

async function freeLoopbackPort() {
  const server = createServer()
  await new Promise((resolveListen, rejectListen) => {
    server.once('error', rejectListen)
    server.listen(0, '127.0.0.1', resolveListen)
  })
  const address = server.address()
  if (!address || typeof address === 'string') throw new Error('could not reserve port')
  await new Promise((resolveClose) => server.close(resolveClose))
  return address.port
}

async function waitForStartup(processHandle) {
  processHandle.stdout.setEncoding('utf8')
  processHandle.stderr.setEncoding('utf8')
  let stdout = ''
  let stderr = ''
  processHandle.stdout.on('data', (chunk) => { stdout += chunk })
  processHandle.stderr.on('data', (chunk) => { stderr += chunk })
  await new Promise((resolveStart, rejectStart) => {
    const timeout = setTimeout(() => {
      rejectStart(new Error(`coordinator startup timed out: ${stderr}`))
    }, 15_000)
    const check = () => {
      if (stdout.includes('管理キー: ')) {
        clearTimeout(timeout)
        resolveStart()
      }
    }
    processHandle.stdout.on('data', check)
    processHandle.once('error', (error) => {
      clearTimeout(timeout)
      rejectStart(error)
    })
    processHandle.once('exit', (code, signal) => {
      clearTimeout(timeout)
      rejectStart(new Error(
        `coordinator exited before startup (${signal || code}): ${stderr}`,
      ))
    })
  })
  return stdout
}

async function secureHealth(port) {
  return new Promise((resolveHealth, rejectHealth) => {
    const req = request({
      hostname: '127.0.0.1',
      port,
      path: '/v1/lan-social/health',
      method: 'GET',
      rejectUnauthorized: false,
      headers: { Host: `127.0.0.1:${port}` },
    }, (response) => {
      let body = ''
      response.setEncoding('utf8')
      response.on('data', (chunk) => { body += chunk })
      response.on('end', () => {
        if (response.statusCode !== 200) {
          rejectHealth(new Error(`health returned ${response.statusCode}: ${body}`))
          return
        }
        try {
          resolveHealth(JSON.parse(body))
        } catch (error) {
          rejectHealth(error)
        }
      })
    })
    req.once('error', rejectHealth)
    req.end()
  })
}
