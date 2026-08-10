/**
 * レート制限。**Gemini の請求が青天井になるのを防ぐ最後の砦。**
 *
 * ## 保存先が無いと本当の制限はかけられない
 *
 * Vercel の関数はリクエストごとに別のインスタンスになりうるので、
 * プロセス内のカウンタは**同じインスタンスに当たったときしか効かない**。
 * 効くこともあるが、**当てにしてはいけない**。
 *
 * したがって:
 * - `KV_REST_API_URL` / `KV_REST_API_TOKEN` があれば Upstash Redis を使う（本物）
 * - 無ければプロセス内カウンタに落ちる（**気休め**。ログに警告を出す）
 *
 * 一般公開の前に KV を必ず繋ぐこと。繋がっていないことは
 * `/api/director` の応答ヘッダ `X-RateLimit-Backend` で外から分かるようにしてある。
 */

export type RateVerdict = {
  ok: boolean
  /** この窓であと何回叩けるか */
  remaining: number
  /** 制限に当たったとき、何秒後に再試行してよいか */
  retryAfterSeconds: number
  /** 'kv' なら本物、'memory' なら気休め */
  backend: 'kv' | 'memory'
}

/** 1端末あたりの上限。会話1回はディレクター呼び出し約20回。 */
export const PER_DEVICE_HOURLY = 80
export const PER_DEVICE_DAILY = 400

/**
 * 全体の1日上限。**個別の制限をすり抜けられても、ここで請求が止まる。**
 * 端末を大量に作られると1端末あたりの制限は意味を失うので、この砦が要る。
 */
export const GLOBAL_DAILY = 20000

const kvUrl = () => process.env.KV_REST_API_URL
const kvToken = () => process.env.KV_REST_API_TOKEN

export function rateBackend(): 'kv' | 'memory' {
  return kvUrl() && kvToken() ? 'kv' : 'memory'
}

/** Upstash REST の INCR + EXPIRE。1往復で済むようパイプラインで送る。 */
async function bump(key: string, ttlSeconds: number): Promise<number> {
  const res = await fetch(`${kvUrl()}/pipeline`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${kvToken()}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify([
      ['INCR', key],
      ['EXPIRE', key, String(ttlSeconds), 'NX'],
    ]),
  })
  if (!res.ok) throw new Error(`KV エラー: ${res.status}`)
  const out = (await res.json()) as Array<{ result: number }>
  return Number(out?.[0]?.result ?? 0)
}

/** プロセス内カウンタ。**インスタンスをまたがないので当てにしない。** */
const local = new Map<string, { count: number; resetAt: number }>()

function bumpLocal(key: string, ttlSeconds: number, now: number): number {
  const cur = local.get(key)
  if (!cur || cur.resetAt <= now) {
    local.set(key, { count: 1, resetAt: now + ttlSeconds * 1000 })
    return 1
  }
  cur.count += 1
  // 際限なく増えないよう、期限切れを掃除する
  if (local.size > 5000) {
    for (const [k, v] of local) if (v.resetAt <= now) local.delete(k)
  }
  return cur.count
}

/**
 * 1リクエストぶん数える。
 *
 * **数えるのは「呼ばれた回数」であって成否ではない。**
 * 失敗しても Gemini を呼んだぶんの費用は発生している。
 */
export async function checkRate(
  deviceId: string,
  now = Date.now(),
): Promise<RateVerdict> {
  const backend = rateBackend()
  const hourBucket = Math.floor(now / 3_600_000)
  const dayBucket = Math.floor(now / 86_400_000)

  const deviceKeys: Array<[key: string, ttl: number, limit: number]> = [
    [`d:${deviceId}:h:${hourBucket}`, 3600, PER_DEVICE_HOURLY],
    [`d:${deviceId}:d:${dayBucket}`, 86400, PER_DEVICE_DAILY],
  ]

  let worstRemaining = Number.POSITIVE_INFINITY
  let blocked = false
  let retryAfter = 60

  for (const [key, ttl, limit] of deviceKeys) {
    let count: number
    try {
      count = backend === 'kv' ? await bump(key, ttl) : bumpLocal(key, ttl, now)
    } catch (e) {
      // KV が落ちているときに会話まで止めない。**開ける方に倒す**。
      // 締める方に倒すと、KV の障害がそのまま全滅になる
      console.error('レート制限の記録に失敗（通す）', e)
      continue
    }
    const remaining = Math.max(0, limit - count)
    if (remaining < worstRemaining) worstRemaining = remaining
    if (count > limit) {
      blocked = true
      // 窓の残り時間を返す。固定値だと窓の頭で当たった人が長く待つ
      const windowMs = ttl * 1000
      retryAfter = Math.max(1, Math.ceil((windowMs - (now % windowMs)) / 1000))
    }
  }

  // 端末上限を超えたリクエストは、ここから先のGeminiを呼ばない。
  // そのため全体枠にも数えない。先にglobalを増やすと、1台が429を連打するだけで
  // 全利用者のGLOBAL_DAILYを使い切れる。
  if (!blocked) {
    const key = `g:d:${dayBucket}`
    try {
      const count = backend === 'kv'
        ? await bump(key, 86400)
        : bumpLocal(key, 86400, now)
      const remaining = Math.max(0, GLOBAL_DAILY - count)
      if (remaining < worstRemaining) worstRemaining = remaining
      if (count > GLOBAL_DAILY) {
        blocked = true
        retryAfter = Math.max(
          1,
          Math.ceil((86_400_000 - (now % 86_400_000)) / 1000),
        )
      }
    } catch (e) {
      // 既存契約どおり、保存障害だけは会話全体を止めない。
      console.error('全体レート制限の記録に失敗（通す）', e)
    }
  }

  return {
    ok: !blocked,
    remaining: Number.isFinite(worstRemaining) ? worstRemaining : 0,
    retryAfterSeconds: retryAfter,
    backend,
  }
}
