import { bearer, type Req, type Res } from '../lib/http.js'
import { verifyToken } from '../lib/auth.js'
import { checkRate, rateBackend } from '../lib/ratelimit.js'
import {
  buildCompanionPrompt,
  companionProviderFromEnv,
  parseCompanionLineBody,
  sanitizeCompanionAck,
  type CompanionProvider,
} from '../lib/companion-line.js'

type CompanionLineDeps = {
  verifyToken: typeof verifyToken
  checkRate: typeof checkRate
  provider: CompanionProvider | null
}

const defaultDeps = (): CompanionLineDeps => ({
  verifyToken,
  checkRate,
  provider: companionProviderFromEnv(),
})

/**
 * デキすぎ君の返事の前置きを生成する。**状態を持たない。**
 *
 * 旧生成経路（director/live-token）とは別口。送られるのは
 * 「生徒が書いた説明・聞き取れた言葉・単元名」だけで、
 * lure・正解・選択肢はサーバへ送らない。
 *
 * 生成したのは前置きのみ。問い返しの文面と3択は端末内のカタログを
 * 逐語で使うので、生成AIが教理を変える余地はない。
 *
 * プロバイダーのキー（COMPANION_AI_API_KEY）が無い環境では
 * 常に 503 を返し、クライアントはカタログの固定文へ退避する。
 * `generativeAiEnabled`（旧経路の全停止スイッチ）には従わない —
 * この経路は未成年利用を前提に保護者同意の開示と併せて設計した、
 * 外部AI提供の唯一の口。
 */
export function companionLineHandler(
  overrides: Partial<CompanionLineDeps> = {},
) {
  const deps: CompanionLineDeps = { ...defaultDeps(), ...overrides }
  return async function handler(req: Req, res: Res) {
    if (req.method !== 'POST') {
      res.setHeader('Allow', 'POST')
      res.status(405).json({ error: 'method_not_allowed' })
      return
    }
    const auth = deps.verifyToken(bearer(req))
    if (!auth.ok) {
      res.status(401).json({
        error: auth.reason === 'expired' ? 'token_expired' : 'unauthorized',
      })
      return
    }

    res.setHeader('X-RateLimit-Backend', rateBackend())
    res.setHeader('Cache-Control', 'no-store')

    const provider = deps.provider
    if (!provider) {
      res.status(503).json({ error: 'companion_ai_unavailable' })
      return
    }

    const parsed = parseCompanionLineBody(req.body)
    if (!parsed.ok) {
      res.status(400).json({ error: parsed.error })
      return
    }

    const rate = await deps.checkRate(auth.token.did)
    res.setHeader('X-RateLimit-Remaining', String(rate.remaining))
    if (!rate.ok) {
      res.setHeader('Retry-After', String(rate.retryAfterSeconds))
      res.status(429).json({
        error: 'rate_limited',
        retryAfter: rate.retryAfterSeconds,
      })
      return
    }

    const raw = await provider(buildCompanionPrompt(parsed.input))
    const ack = sanitizeCompanionAck(raw)
    res.status(200).json({ ack })
  }
}

export default companionLineHandler()
