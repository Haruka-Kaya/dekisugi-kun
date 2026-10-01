import { bearer, type Req, type Res } from '../lib/http.js'
import { verifyToken } from '../lib/auth.js'
import { checkRate } from '../lib/ratelimit.js'
import { syncRevenueCatEntitlement } from '../lib/revenuecat.js'
import { restrictedDataProcessingEnabled } from '../lib/restricted-data-processing.js'

/** 購入・復元直後にwebhookを待たず、署名tokenのDIDをRevenueCatへ照会する。 */
export async function handleSubscriptionSync(
  req: Req,
  res: Res,
  options: {
    sync?: typeof syncRevenueCatEntitlement
    check?: typeof checkRate
  } = {},
): Promise<void> {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST')
    res.status(405).json({ error: 'method_not_allowed' })
    return
  }
  const auth = verifyToken(bearer(req))
  if (!auth.ok) {
    res.status(401).json({ error: auth.reason === 'expired' ? 'token_expired' : 'unauthorized' })
    return
  }
  if (!restrictedDataProcessingEnabled()) {
    res.status(503).json({ error: 'restricted_data_processing_unavailable' })
    return
  }
  // registerは匿名で作れるため、署名tokenだけでは無制限なREST中継を防げない。
  // 会話と同じ端末別・全体rateを使い、RevenueCat API側まで連打を運ばない。
  const rate = await (options.check ?? checkRate)(auth.token.did)
  res.setHeader('X-RateLimit-Backend', rate.backend)
  if (!rate.ok) {
    res.setHeader('Retry-After', String(rate.retryAfterSeconds))
    res.status(429).json({
      error: 'rate_limited',
      retryAfter: rate.retryAfterSeconds,
    })
    return
  }
  try {
    const access = await (options.sync ?? syncRevenueCatEntitlement)(auth.token.did)
    res.status(200).json({
      entitled: access.active,
      expiresAt: access.expiresAtMs == null
        ? null
        : new Date(access.expiresAtMs).toISOString(),
    })
  } catch (e) {
    console.error('RevenueCat on-demand sync failed', e)
    res.status(502).json({ error: 'revenuecat_sync_failed' })
  }
}

export default async function handler(req: Req, res: Res): Promise<void> {
  await handleSubscriptionSync(req, res)
}
