import { schoolTestingEnabled } from './school-access.js'
import {
  parseSchoolClass, parseSchoolControlRequest, parseSchoolStaffSession,
  parseSchoolTenant, parseStaffMembership,
  type SchoolControlRequest, type SchoolStaffSession,
} from './school-control-contracts.js'

/**
 * Trusted server adapters, not fields supplied by an HTTP client.
 * authenticate must validate the selected IdP/session, revocation and MFA evidence.
 * Repository reads must return current authoritative records, not request claims.
 * No production adapters exist yet; parsing a session is NOT authentication.
 */
export interface SchoolPolicyAdapters {
  authenticate(): Promise<unknown>
  loadTenant(tenantId: string): Promise<unknown>
  loadMembership(tenantId: string, staffId: string): Promise<unknown>
  loadClass(tenantId: string, classId: string): Promise<unknown>
}

export type SchoolPolicyDecision =
  | Readonly<{ allowed: false }>
  | Readonly<{ allowed: true; staffId: string; request: SchoolControlRequest }>

const DENIED: SchoolPolicyDecision = Object.freeze({ allowed: false })

function sessionCurrent(session: SchoolStaffSession, now: number): boolean {
  return Number.isSafeInteger(now) && now >= 0 && session.authenticatedAt <= now
    && session.expiresAt > now && session.mfaVerifiedAt !== null && session.mfaVerifiedAt <= now
}

/**
 * Internal authorization only; executes no operation and writes/returns no student data.
 * A future handler must use the returned scope, enforce payload/aggregate privacy,
 * recheck permissions in its transaction, and commit a redacted audit entry.
 */
export async function authorizeSchoolOperation(
  rawRequest: unknown,
  adapters: SchoolPolicyAdapters,
  clock: () => number = Date.now,
): Promise<SchoolPolicyDecision> {
  if (!schoolTestingEnabled()) return DENIED
  try {
    // Snapshot the request before awaiting an adapter; callers cannot swap its scope.
    const request = parseSchoolControlRequest(rawRequest)
    if (!request) return DENIED
    const session = parseSchoolStaffSession(await adapters.authenticate())
    if (!session || session.tenantId !== request.tenantId || !sessionCurrent(session, clock())) return DENIED
    const tenant = parseSchoolTenant(await adapters.loadTenant(request.tenantId))
    if (!tenant || tenant.tenantId !== request.tenantId || tenant.status !== 'active') return DENIED
    const membership = parseStaffMembership(
      await adapters.loadMembership(request.tenantId, session.staffId),
    )
    if (!membership || membership.tenantId !== request.tenantId
      || membership.staffId !== session.staffId || membership.status !== 'active') return DENIED

    // The initial matrix grants teachers only assigned-class aggregate reads.
    // Support has no grant until its specific support workflow has been designed.
    if (membership.role !== 'admin'
      && !(membership.role === 'teacher' && request.operation === 'read_concept_aggregate'
        && request.classId !== null && membership.classIds.includes(request.classId))) return DENIED

    if (request.classId !== null) {
      const target = parseSchoolClass(await adapters.loadClass(request.tenantId, request.classId))
      if (!target || target.tenantId !== request.tenantId || target.classId !== request.classId
        || target.status !== 'active') return DENIED
    }

    // Check time after I/O as well as the deployment gate; an expired session never grants.
    if (!schoolTestingEnabled() || !sessionCurrent(session, clock())) return DENIED
    return Object.freeze({ allowed: true, staffId: session.staffId, request })
  } catch {
    // Storage/identity failures and malformed adapter objects never bypass authorization.
    return DENIED
  }
}
