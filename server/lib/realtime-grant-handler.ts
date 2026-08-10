import { verifyToken } from './auth.js'
import { generativeAiEnabled } from './generative-ai.js'
import { bearer, parseBody, type Req, type Res } from './http.js'
import {
  createOpenAiRealtimeGrant,
  openAiRealtimeReady,
} from './openai-realtime.js'
import { reserveSession } from './quota.js'
import { checkRate } from './ratelimit.js'
import { parseRealtimeGrantRequest } from './realtime-grant-request.js'

type RealtimeGrantDeps = {
  checkRate: typeof checkRate
  createGrant: typeof createOpenAiRealtimeGrant
  providerReady: typeof openAiRealtimeReady
  reserveSession: typeof reserveSession
}

const defaultDeps: RealtimeGrantDeps = {
  checkRate,
  createGrant: createOpenAiRealtimeGrant,
  providerReady: openAiRealtimeReady,
  reserveSession,
}

/**
 * provider-neutralなRealtime会話資格情報の発行口。
 *
 * 現在のproviderはOpenAIだが、Flutterはレスポンスの`provider` / `transport` /
 * `credential.kind`を見て接続する。Vertex固有のURLやsetup形式をAPI契約へ
 * 持ち込まず、既存`/api/live-token`も変更しない。
 */
export function realtimeGrantHandler(
  overrides: Partial<RealtimeGrantDeps> = {},
) {
  const deps: RealtimeGrantDeps = { ...defaultDeps, ...overrides }
  return async function handler(req: Req, res: Res) {
    if (req.method !== 'POST') {
      res.setHeader('Allow', 'POST')
      res.status(405).json({ error: 'method_not_allowed' })
      return
    }

    const auth = verifyToken(bearer(req))
    if (!auth.ok) {
      res.status(401).json({
        error: auth.reason === 'expired' ? 'token_expired' : 'unauthorized',
      })
      return
    }

    // 既存のproduction / preview強制停止を最初の砦として維持する。
    // 認証後は本文解析、provider設定、rate、quota、外部APIのすべてより先に止める。
    if (!generativeAiEnabled()) {
      res.status(503).json({ error: 'generative_ai_unavailable' })
      return
    }

    // API keyまたはZDR確認が無ければ、利用枠を引く前に同じ503で閉じる。
    // どちらが欠けているかを端末へ返して運用設定を探索させない。
    if (!deps.providerReady()) {
      res.status(503).json({ error: 'realtime_provider_unavailable' })
      return
    }

    // unknown unit / focus / mission / tactic / langはrate・quota・OpenAIより前。
    const parsed = parseRealtimeGrantRequest(parseBody(req.body))
    if (!parsed.ok) {
      res.status(400).json(parsed.response)
      return
    }

    const deviceId = auth.token.did
    const rate = await deps.checkRate(deviceId)
    res.setHeader('X-RateLimit-Backend', rate.backend)
    res.setHeader('X-RateLimit-Remaining', String(rate.remaining))
    if (!rate.ok) {
      res.setHeader('Retry-After', String(rate.retryAfterSeconds))
      res.status(429).json({
        error: 'rate_limited',
        retryAfter: rate.retryAfterSeconds,
      })
      return
    }

    // 既存providerと同じ日次枠を共有し、credential発行より先に確保する。
    const quota = await deps.reserveSession(deviceId)
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
      const grant = await deps.createGrant(deviceId, parsed.value)
      // 短命credentialをCDN・ブラウザ・端末の共有cacheへ残さない。
      res.setHeader('Cache-Control', 'private, no-store')
      res.setHeader('Pragma', 'no-cache')
      res.status(200).json({
        ...grant,
        quota: {
          remainingSessions: Number.isFinite(quota.remainingSessions)
            ? quota.remainingSessions
            : null,
          entitled: quota.entitled,
          resetsAt: quota.resetsAt,
        },
      })
    } catch {
      // Error本文や上流応答を返さない。標準API keyやcredential断片を
      // レスポンスへ混ぜないため、外向きは固定コードだけにする。
      console.error('Realtime資格情報を作れなかった')
      res.status(502).json({ error: 'grant_failed' })
    }
  }
}

export default realtimeGrantHandler()
