import { randomUUID } from 'node:crypto'
import { createConnection } from 'node:net'

type RedisValue = string | number | null | RedisValue[]

/** Tiny RESP client for an isolated, loopback-only CI Redis, with no new dependencies. */
function command(port: number, parts: string[]): Promise<RedisValue> {
  return new Promise((resolve, reject) => {
    const socket = createConnection({ host: '127.0.0.1', port })
    let input = Buffer.alloc(0)
    let settled = false
    socket.setTimeout(5000, () => socket.destroy(new Error('Redis fixture timed out')))
    socket.once('error', reject)
    socket.once('close', () => { if (!settled) reject(new Error('Redis fixture connection closed')) })
    socket.once('connect', () => {
      socket.write(Buffer.concat([
        Buffer.from(`*${parts.length}\r\n`),
        ...parts.flatMap((part) => {
          const data = Buffer.from(part)
          return [Buffer.from(`$${data.length}\r\n`), data, Buffer.from('\r\n')]
        }),
      ]))
    })
    socket.on('data', (chunk) => {
      input = Buffer.concat([input, typeof chunk === 'string' ? Buffer.from(chunk) : chunk])
      function parse(at: number): [RedisValue, number] | undefined {
        const end = input.indexOf('\r\n', at)
        if (end < 0) return
        const type = String.fromCharCode(input[at]!)
        const line = input.toString('utf8', at + 1, end)
        const next = end + 2
        if (type === '-') throw new Error(`Redis fixture: ${line}`)
        if (type === '+') return [line, next]
        if (type === ':') return [Number(line), next]
        const length = Number(line)
        if (length === -1) return [null, next]
        if (type === '$') {
          if (input.length < next + length + 2) return
          return [input.toString('utf8', next, next + length), next + length + 2]
        }
        if (type === '*') {
          const values: RedisValue[] = []
          let offset = next
          for (let i = 0; i < length; i++) {
            const item = parse(offset)
            if (!item) return
            values.push(item[0])
            offset = item[1]
          }
          return [values, offset]
        }
        throw new Error('Invalid Redis fixture response')
      }
      try {
        const value = parse(0)
        if (value) {
          settled = true
          socket.end()
          resolve(value[0])
        }
      } catch (error) {
        socket.destroy()
        reject(error)
      }
    })
  })
}

export async function useRedisKv() {
  const port = Number(process.env.TEAM_REDIS_TEST_PORT)
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error('TEAM_REDIS_TEST_PORT must point to a disposable local Redis')
  }
  if (await command(port, ['PING']) !== 'PONG') throw new Error('Redis fixture unavailable')
  const prefix = `school-team-test:${randomUUID()}:`
  const keys = new Set<string>()
  const originalFetch = globalThis.fetch
  const originalUrl = process.env.KV_REST_API_URL
  const originalToken = process.env.KV_REST_API_TOKEN
  function scoped(key: string): string {
    const value = prefix + key
    keys.add(value)
    return value
  }
  async function run(parts: string[]): Promise<RedisValue> {
    if (parts[0] === 'EVAL') {
      const count = Number(parts[2])
      return command(port, [
        ...parts.slice(0, 3), ...parts.slice(3, 3 + count).map(scoped), ...parts.slice(3 + count),
      ])
    }
    if (parts[0] === 'DEL') return command(port, ['DEL', ...parts.slice(1).map(scoped)])
    return command(port, [parts[0]!, scoped(parts[1]!), ...parts.slice(2)])
  }
  const hooks: { beforeEval?: () => Promise<void> } = {}
  process.env.KV_REST_API_URL = 'https://school-team-kv.invalid'
  process.env.KV_REST_API_TOKEN = 'synthetic-fixture-token'
  globalThis.fetch = (async (input, init) => {
    if (String(input) !== 'https://school-team-kv.invalid/pipeline') {
      throw new Error('Network access outside Redis fixture is forbidden')
    }
    const parts = JSON.parse(String(init?.body)) as string[][]
    const out = []
    for (const cmd of parts) {
      if (cmd[0] === 'EVAL' && hooks.beforeEval) {
        const hook = hooks.beforeEval
        delete hooks.beforeEval
        await hook()
      }
      try { out.push({ result: await run(cmd) }) }
      catch { out.push({ error: 'synthetic Redis command failure' }) }
    }
    return new Response(JSON.stringify(out), { status: 200 })
  }) as typeof fetch
  return {
    run, hooks,
    async restore() {
      globalThis.fetch = originalFetch
      if (originalUrl === undefined) delete process.env.KV_REST_API_URL
      else process.env.KV_REST_API_URL = originalUrl
      if (originalToken === undefined) delete process.env.KV_REST_API_TOKEN
      else process.env.KV_REST_API_TOKEN = originalToken
      if (keys.size) await command(port, ['DEL', ...keys])
    },
  }
}
