import { verifyToken } from '../lib/auth.js'
import { createLiveGrant } from '../lib/live-token.js'
import { MINUTES_PER_SESSION, peekRemaining, reserveSession } from '../lib/quota.js'
import { checkRate } from '../lib/ratelimit.js'
import { unitById } from '../lib/units.js'

/** 本文が文字列で来ることがある。壊れていても 500 にしない */
function safeJson(raw: string): unknown {
  try {
    return JSON.parse(raw)
  } catch {
    return undefined
  }
}

/**
 * 会話を始めるための資格情報を渡す。
 *
 * **Vertex の鍵はここにしか無い。** 端末が持つのは期限つきのアクセストークンだけ。
 *
 * 1セッションは **Vertex 自身が約10分で打ち切る**（実測 `code=1000`）ので、
 * 1回渡す = 約10分の会話。枠は**セッション数**で数える。
 *
 * GET  … 今日あと何回始められるか（引かずに見るだけ。画面表示用）
 * POST … 1回ぶん確保して資格情報を渡す
 */

type Req = {
  method?: string
  headers?: Record<string, string | string[] | undefined>
  body?: unknown
}
type Res = {
  status: (code: number) => Res
  json: (body: unknown) => void
  setHeader: (name: string, value: string) => void
}

function bearer(req: Req): string | undefined {
  const raw = req.headers?.authorization ?? req.headers?.Authorization
  const value = Array.isArray(raw) ? raw[0] : raw
  if (typeof value !== 'string') return undefined
  const m = /^Bearer\s+(.+)$/i.exec(value.trim())
  return m ? m[1] : undefined
}

export default async function handler(req: Req, res: Res) {
  if (req.method !== 'POST' && req.method !== 'GET') {
    res.setHeader('Allow', 'GET, POST')
    res.status(405).json({ error: 'method_not_allowed' })
    return
  }

  const auth = verifyToken(bearer(req))
  if (!auth.ok) {
    res.status(401).json({ error: auth.reason === 'expired' ? 'token_expired' : 'unauthorized' })
    return
  }
  const deviceId = auth.token.did

  if (req.method === 'GET') {
    const left = await peekRemaining(deviceId)
    res.status(200).json({
      remainingSessions: Number.isFinite(left.remainingSessions)
        ? left.remainingSessions
        : null,
      minutesPerSession: MINUTES_PER_SESSION,
      entitled: left.entitled,
      resetsAt: left.resetsAt,
    })
    return
  }

  // **単元は枠を引く前に確かめる。** 引いてから弾くと、
  // 会話していないのに1回ぶん減る
  const body = typeof req.body === 'string' ? safeJson(req.body) : req.body
  const unitId = (body as { unitId?: unknown } | undefined)?.unitId
  if (typeof unitId !== 'string' || !unitById(unitId)) {
    res.status(400).json({ error: 'unknown_unit' })
    return
  }

  // 濫用の歯止め。**Vertex を呼ぶ前に落とす**
  const rate = await checkRate(deviceId)
  res.setHeader('X-RateLimit-Backend', rate.backend)
  if (!rate.ok) {
    res.setHeader('Retry-After', String(rate.retryAfterSeconds))
    res.status(429).json({ error: 'rate_limited', retryAfter: rate.retryAfterSeconds })
    return
  }

  // **先に引いてから渡す。** 渡してから引くと、途中で落ちたときに
  // 使われたのに引かれていない回数が残る
  const quota = await reserveSession(deviceId)
  res.setHeader('X-Quota-Backend', quota.backend)
  if (!quota.granted) {
    res.status(402).json({
      error: 'quota_exhausted',
      remainingSessions: 0,
      resetsAt: quota.resetsAt,
    })
    return
  }

  try {
    const grant = await createLiveGrant(unitId)
    res.status(200).json({
      ...grant,
      remainingSessions: Number.isFinite(quota.remainingSessions)
        ? quota.remainingSessions
        : null,
      entitled: quota.entitled,
      resetsAt: quota.resetsAt,
    })
  } catch (e) {
    // 中身は返さない。資格情報の断片が混ざりうる
    console.error('会話の資格情報を作れなかった', e)
    res.status(502).json({ error: 'grant_failed' })
  }
}
