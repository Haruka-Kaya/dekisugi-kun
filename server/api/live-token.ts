import { verifyToken } from '../lib/auth.js'
import { createLiveToken } from '../lib/live-token.js'
import { peekRemaining, reserveMinutes } from '../lib/quota.js'
import { checkRate } from '../lib/ratelimit.js'

/**
 * 会話を始めるための一時トークンを渡す。
 *
 * **APIキーはここにしか無い。** 端末が持つのは短命で使い切りのトークンだけ。
 * トークンの期限が来るとセッションごと切られるので、
 * **渡す寿命がそのまま「与えた会話時間」になる**（端末側で伸ばせない）。
 *
 * GET  … 今日あと何分使えるか（引かずに見るだけ。画面表示用）
 * POST … 1ブロック確保してトークンを渡す
 */

type Req = {
  method?: string
  headers?: Record<string, string | string[] | undefined>
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
      remainingMinutes: Number.isFinite(left.remainingMinutes) ? left.remainingMinutes : null,
      entitled: left.entitled,
      resetsAt: left.resetsAt,
    })
    return
  }

  // 濫用の歯止め。**Gemini を呼ぶ前に落とす**
  const rate = await checkRate(deviceId)
  res.setHeader('X-RateLimit-Backend', rate.backend)
  if (!rate.ok) {
    res.setHeader('Retry-After', String(rate.retryAfterSeconds))
    res.status(429).json({ error: 'rate_limited', retryAfter: rate.retryAfterSeconds })
    return
  }

  // **先に引いてから渡す。** 渡してから引くと、途中で落ちたときに
  // 使われたのに引かれていない時間が残る
  const quota = await reserveMinutes(deviceId)
  res.setHeader('X-Quota-Backend', quota.backend)
  if (quota.grantedMinutes <= 0) {
    res.status(402).json({
      error: 'quota_exhausted',
      remainingMinutes: 0,
      resetsAt: quota.resetsAt,
    })
    return
  }

  try {
    const issued = await createLiveToken(Date.now(), quota.grantedMinutes)
    res.status(200).json({
      ...issued,
      grantedMinutes: quota.grantedMinutes,
      remainingMinutes: Number.isFinite(quota.remainingMinutes)
        ? quota.remainingMinutes
        : null,
      entitled: quota.entitled,
      resetsAt: quota.resetsAt,
    })
  } catch (e) {
    // 中身は返さない。キーの断片が混ざりうる
    console.error('一時トークンの発行に失敗', e)
    res.status(502).json({ error: 'token_failed' })
  }
}
