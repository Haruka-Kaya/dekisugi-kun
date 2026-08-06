/**
 * Upstash の REST を偽装する。
 *
 * `lib/kv.ts` は `fetch` で `/pipeline` を叩くだけなので、
 * **`globalThis.fetch` を差し替えれば本物と同じ経路を通せる。**
 * モックのオブジェクトを注入する形にすると、
 * コマンドの綴りやパイプラインの戻り値の形といった
 * **実際に間違えるところ**がテストを素通りしてしまう。
 *
 * 対応しているのは、このプロジェクトが使うコマンドだけ。
 * 知らないコマンドは投げる（黙って null を返すと、
 * 綴りを間違えたまま緑になる）。
 */

type Val = string | Set<string> | Map<string, string>

export class FakeKv {
  readonly data = new Map<string, Val>()
  readonly expires = new Map<string, number>()
  /** 叩かれたコマンド。順序や有無の確認に使う */
  readonly log: string[][] = []

  now = Date.UTC(2026, 7, 6, 3, 0)

  private alive(key: string): boolean {
    const t = this.expires.get(key)
    if (t != null && t <= this.now) {
      this.data.delete(key)
      this.expires.delete(key)
      return false
    }
    return this.data.has(key)
  }

  private hash(key: string): Map<string, string> {
    if (!this.alive(key)) this.data.set(key, new Map())
    const v = this.data.get(key)
    if (!(v instanceof Map)) throw new Error(`型が違う: ${key}`)
    return v
  }

  private set(key: string): Set<string> {
    if (!this.alive(key)) this.data.set(key, new Set())
    const v = this.data.get(key)
    if (!(v instanceof Set)) throw new Error(`型が違う: ${key}`)
    return v
  }

  run(cmd: string[]): unknown {
    this.log.push(cmd)
    const [op, key, ...rest] = cmd
    const k = key ?? ''
    switch (op?.toUpperCase()) {
      case 'GET':
        return this.alive(k) ? (this.data.get(k) as string) : null
      case 'SET': {
        // `SET k v NX EX 5` のような修飾を実装する。
        // 無視すると、ロックが常に取れてしまい**競合のテストが素通りする**
        const opts = rest.slice(1).map((x) => x.toUpperCase())
        if (opts.includes('NX') && this.alive(k)) return null
        this.data.set(k, String(rest[0]))
        this.expires.delete(k)
        const ex = opts.indexOf('EX')
        if (ex >= 0) this.expires.set(k, this.now + Number(rest[1 + ex + 1]) * 1000)
        return 'OK'
      }
      case 'DEL': {
        const had = this.alive(k)
        this.data.delete(k)
        this.expires.delete(k)
        return had ? 1 : 0
      }
      case 'INCR': {
        const n = (this.alive(k) ? Number(this.data.get(k)) : 0) + 1
        this.data.set(k, String(n))
        return n
      }
      case 'EXPIRE': {
        if (!this.alive(k)) return 0
        // NX は「まだ期限が無いときだけ」
        if (rest[1]?.toUpperCase() === 'NX' && this.expires.has(k)) return 0
        this.expires.set(k, this.now + Number(rest[0]) * 1000)
        return 1
      }
      case 'PEXPIREAT':
        if (!this.alive(k)) return 0
        this.expires.set(k, Number(rest[0]))
        return 1
      case 'HSET': {
        const h = this.hash(k)
        for (let i = 0; i + 1 < rest.length; i += 2) h.set(rest[i]!, String(rest[i + 1]))
        return 1
      }
      case 'HGET':
        return this.alive(k) ? (this.hash(k).get(rest[0]!) ?? null) : null
      case 'HGETALL': {
        if (!this.alive(k)) return {}
        return Object.fromEntries(this.hash(k))
      }
      case 'HINCRBY': {
        const h = this.hash(k)
        const n = Number(h.get(rest[0]!) ?? 0) + Number(rest[1])
        h.set(rest[0]!, String(n))
        return n
      }
      case 'SADD': {
        const s = this.set(k)
        const before = s.size
        s.add(String(rest[0]))
        return s.size - before
      }
      case 'SREM': {
        if (!this.alive(k)) return 0
        return this.set(k).delete(String(rest[0])) ? 1 : 0
      }
      case 'SCARD':
        return this.alive(k) ? this.set(k).size : 0
      case 'SISMEMBER':
        return this.alive(k) && this.set(k).has(String(rest[0])) ? 1 : 0
      default:
        throw new Error(`知らないコマンド: ${op}`)
    }
  }
}

/**
 * `fetch` を差し替えて偽の KV に繋ぐ。**戻り値で元に戻す。**
 */
export function useFakeKv(): { kv: FakeKv; restore: () => void } {
  const fake = new FakeKv()
  const original = globalThis.fetch
  process.env.KV_REST_API_URL = 'https://kv.test'
  process.env.KV_REST_API_TOKEN = 'test'

  globalThis.fetch = (async (input: unknown, init?: { body?: string }) => {
    const url = String(input)
    if (!url.startsWith('https://kv.test')) return original(input as never, init as never)
    const cmds = JSON.parse(init?.body ?? '[]') as string[][]
    const out = cmds.map((c) => ({ result: fake.run(c) }))
    return new Response(JSON.stringify(out), { status: 200 })
  }) as typeof fetch

  return {
    kv: fake,
    restore: () => {
      globalThis.fetch = original
      delete process.env.KV_REST_API_URL
      delete process.env.KV_REST_API_TOKEN
    },
  }
}
