import { timingSafeEqual } from 'node:crypto'

import { header, parseBody, type Req, type Res } from '../lib/http.js'
import { isDeviceAppUserId, syncRevenueCatEntitlement } from '../lib/revenuecat.js'
import { restrictedDataProcessingEnabled } from '../lib/restricted-data-processing.js'

const MAX_BODY_BYTES = 64 * 1024

function bodyByteLength(body: unknown): number {
  if (typeof body === 'string') return Buffer.byteLength(body, 'utf8')
  try {
    const encoded = JSON.stringify(body)
    return encoded == null ? 0 : Buffer.byteLength(encoded, 'utf8')
  } catch {
    return MAX_BODY_BYTES + 1
  }
}

function authorized(req: Req, expected: string | undefined): boolean {
  const received = header(req, 'authorization')
  if (!expected || !received) return false
  const a = Buffer.from(received)
  const b = Buffer.from(expected)
  return a.length === b.length && timingSafeEqual(a, b)
}

/** TRANSFERを含め、webhookに現れたcustom UUIDだけを同期対象にする。 */
export function webhookAppUserIds(body: unknown): string[] {
  if (!body || typeof body !== 'object') return []
  const event = (body as { event?: unknown }).event
  if (!event || typeof event !== 'object') return []
  const e = event as Record<string, unknown>
  const candidates: unknown[] = [e.app_user_id, e.original_app_user_id]
  for (const field of ['aliases', 'transferred_from', 'transferred_to']) {
    const values = e[field]
    if (Array.isArray(values)) candidates.push(...values)
  }
  return [...new Set(candidates.filter(isDeviceAppUserId))]
}

export async function handleRevenueCatWebhook(
  req: Req,
  res: Res,
  options: {
    expectedAuthorization?: string
    sync?: typeof syncRevenueCatEntitlement
  } = {},
): Promise<void> {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST')
    res.status(405).json({ error: 'method_not_allowed' })
    return
  }
  const expected = options.expectedAuthorization ?? process.env.REVENUECAT_WEBHOOK_AUTH
  if (!expected) {
    res.status(503).json({ error: 'revenuecat_not_configured' })
    return
  }
  if (!authorized(req, expected)) {
    res.status(401).json({ error: 'unauthorized' })
    return
  }
  if (!restrictedDataProcessingEnabled()) {
    res.status(503).json({ error: 'restricted_data_processing_unavailable' })
    return
  }
  if (bodyByteLength(req.body) > MAX_BODY_BYTES) {
    res.status(413).json({ error: 'too_large' })
    return
  }
  const body = parseBody(req.body)
  if (body == null) {
    res.status(400).json({ error: 'invalid_json' })
    return
  }
  const appUserIds = webhookAppUserIds(body)
  try {
    const sync = options.sync ?? syncRevenueCatEntitlement
    await Promise.all(appUserIds.map((id) => sync(id)))
    // RevenueCatの自動anonymous IDだけのイベントは処理不要。再送ループにしない。
    res.status(200).json({ ok: true, synced: appUserIds.length })
  } catch (e) {
    console.error('RevenueCat entitlement sync failed', e)
    // 2xxにせずRevenueCatのretryへ委ねる。
    res.status(502).json({ error: 'revenuecat_sync_failed' })
  }
}

export default async function handler(req: Req, res: Res): Promise<void> {
  await handleRevenueCatWebhook(req, res)
}
