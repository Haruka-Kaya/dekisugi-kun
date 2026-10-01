import { grantEntitlement, revokeEntitlement } from './quota.js'

const UUID_V4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
const LIFETIME_EXPIRY_MS = Date.UTC(2100, 0, 1)

export type RevenueCatAccess = {
  active: boolean
  expiresAtMs: number | null
}

type RevenueCatSubscriber = {
  subscriber?: {
    entitlements?: Record<string, { expires_date?: string | null }>
  }
}

export function isDeviceAppUserId(value: unknown): value is string {
  return typeof value === 'string' && UUID_V4.test(value)
}

/** RevenueCat v1 subscriber応答から、Plusが現在有効かだけを読む。 */
export function plusAccessFromSubscriber(
  body: unknown,
  entitlementId: string,
  now = Date.now(),
): RevenueCatAccess {
  if (!body || typeof body !== 'object') return { active: false, expiresAtMs: null }
  const entitlement = (body as RevenueCatSubscriber).subscriber?.entitlements?.[entitlementId]
  if (!entitlement) return { active: false, expiresAtMs: null }
  if (entitlement.expires_date === null) {
    return { active: true, expiresAtMs: LIFETIME_EXPIRY_MS }
  }
  if (typeof entitlement.expires_date !== 'string') {
    return { active: false, expiresAtMs: null }
  }
  const expiresAtMs = Date.parse(entitlement.expires_date)
  if (!Number.isFinite(expiresAtMs) || expiresAtMs <= now) {
    return { active: false, expiresAtMs: null }
  }
  return { active: true, expiresAtMs }
}

export async function fetchRevenueCatAccess(
  appUserId: string,
  options: {
    apiKey?: string
    entitlementId?: string
    now?: number
    fetcher?: typeof fetch
  } = {},
): Promise<RevenueCatAccess> {
  if (!isDeviceAppUserId(appUserId)) throw new Error('invalid RevenueCat app user id')
  const apiKey = options.apiKey ?? process.env.REVENUECAT_API_KEY
  if (!apiKey) throw new Error('REVENUECAT_API_KEY is not configured')
  const entitlementId = options.entitlementId ?? process.env.REVENUECAT_ENTITLEMENT_ID ?? 'plus'
  const response = await (options.fetcher ?? fetch)(
    `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}`,
    {
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
    },
  )
  if (!response.ok) throw new Error(`RevenueCat subscriber sync failed: ${response.status}`)
  return plusAccessFromSubscriber(await response.json(), entitlementId, options.now)
}

/** REST APIの現在値を正として、既存quota entitlementへ反映する。 */
export async function syncRevenueCatEntitlement(
  appUserId: string,
  options: {
    fetchAccess?: typeof fetchRevenueCatAccess
    grant?: typeof grantEntitlement
    revoke?: typeof revokeEntitlement
  } = {},
): Promise<RevenueCatAccess> {
  const access = await (options.fetchAccess ?? fetchRevenueCatAccess)(appUserId)
  if (access.active && access.expiresAtMs != null) {
    await (options.grant ?? grantEntitlement)(appUserId, access.expiresAtMs)
  } else {
    await (options.revoke ?? revokeEntitlement)(appUserId)
  }
  return access
}
