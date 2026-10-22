/**
 * Internal school-control contracts. These are not HTTP request/response schemas.
 * IDs belong to the school domain, never device UUIDs, LAN keys, or IdP tokens.
 * No names, student answers, audio, or arbitrary metadata are accepted.
 */
export type SchoolTenant = Readonly<{
  tenantId: string
  status: 'active' | 'suspended'
}>

export type SchoolClass = Readonly<{
  tenantId: string
  schoolId: string
  classId: string
  schoolYearId: string
  status: 'active' | 'archived'
}>

export type StaffMembership = Readonly<{
  tenantId: string
  staffId: string
  role: 'admin' | 'teacher' | 'support'
  status: 'active' | 'suspended' | 'revoked'
  classIds: readonly string[]
}>

/** Supplied only by a server-side identity adapter after authentication. Times are epoch ms. */
export type SchoolStaffSession = Readonly<{
  tenantId: string
  staffId: string
  sessionId: string
  authenticatedAt: number
  expiresAt: number
  mfaVerifiedAt: number | null
}>

const CLASS_OPERATIONS = ['read_concept_aggregate', 'manage_class', 'manage_enrollment'] as const
const TENANT_OPERATIONS = ['manage_staff', 'manage_license', 'read_audit', 'request_deletion'] as const

export type SchoolOperation = typeof CLASS_OPERATIONS[number] | typeof TENANT_OPERATIONS[number]
export type SchoolControlRequest = Readonly<{
  operation: SchoolOperation
  tenantId: string
  /** Required for class operations; null for tenant operations. */
  classId: string | null
}>

/** Exact own data properties only: no inherited claims, accessors, or hidden fields. */
function record(value: unknown, keys: readonly string[]): Record<string, unknown> | undefined {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) return
  const prototype = Object.getPrototypeOf(value)
  if (prototype !== Object.prototype && prototype !== null) return
  if (Reflect.ownKeys(value).length !== keys.length) return
  const descriptors = Object.getOwnPropertyDescriptors(value)
  const out: Record<string, unknown> = Object.create(null)
  for (const key of keys) {
    const descriptor = descriptors[key]
    if (!descriptor || !('value' in descriptor) || !descriptor.enumerable) return
    out[key] = descriptor.value
  }
  return out
}

function id(value: unknown): value is string {
  return typeof value === 'string' && /^[A-Za-z0-9][A-Za-z0-9_-]{0,127}$/.test(value)
}

function timestamp(value: unknown): value is number {
  return typeof value === 'number' && Number.isSafeInteger(value) && value >= 0
}

function ids(value: unknown): readonly string[] | undefined {
  if (!Array.isArray(value) || Object.getPrototypeOf(value) !== Array.prototype) return
  if (Reflect.ownKeys(value).length !== value.length + 1) return
  const out: string[] = []
  for (let index = 0; index < value.length; index++) {
    const descriptor = Object.getOwnPropertyDescriptor(value, String(index))
    if (!descriptor || !('value' in descriptor) || !descriptor.enumerable || !id(descriptor.value)) return
    out.push(descriptor.value)
  }
  if (new Set(out).size !== out.length) return
  return Object.freeze(out)
}

export function parseSchoolTenant(value: unknown): SchoolTenant | undefined {
  const v = record(value, ['tenantId', 'status'])
  if (!v || !id(v.tenantId) || (v.status !== 'active' && v.status !== 'suspended')) return
  return Object.freeze({ tenantId: v.tenantId, status: v.status })
}

export function parseSchoolClass(value: unknown): SchoolClass | undefined {
  const v = record(value, ['tenantId', 'schoolId', 'classId', 'schoolYearId', 'status'])
  if (!v || !id(v.tenantId) || !id(v.schoolId) || !id(v.classId) || !id(v.schoolYearId)) return
  if (v.status !== 'active' && v.status !== 'archived') return
  return Object.freeze({
    tenantId: v.tenantId, schoolId: v.schoolId, classId: v.classId,
    schoolYearId: v.schoolYearId, status: v.status,
  })
}

export function parseStaffMembership(value: unknown): StaffMembership | undefined {
  const v = record(value, ['tenantId', 'staffId', 'role', 'status', 'classIds'])
  if (!v || !id(v.tenantId) || !id(v.staffId)) return
  if (v.role !== 'admin' && v.role !== 'teacher' && v.role !== 'support') return
  if (v.status !== 'active' && v.status !== 'suspended' && v.status !== 'revoked') return
  const classIds = ids(v.classIds)
  if (!classIds) return
  return Object.freeze({
    tenantId: v.tenantId, staffId: v.staffId, role: v.role, status: v.status,
    classIds,
  })
}

export function parseSchoolStaffSession(value: unknown): SchoolStaffSession | undefined {
  const v = record(value, [
    'tenantId', 'staffId', 'sessionId', 'authenticatedAt', 'expiresAt', 'mfaVerifiedAt',
  ])
  if (!v || !id(v.tenantId) || !id(v.staffId) || !id(v.sessionId)) return
  if (!timestamp(v.authenticatedAt) || !timestamp(v.expiresAt)) return
  if (v.expiresAt <= v.authenticatedAt) return
  if (v.mfaVerifiedAt !== null && (!timestamp(v.mfaVerifiedAt)
    || v.mfaVerifiedAt < v.authenticatedAt || v.mfaVerifiedAt >= v.expiresAt)) return
  return Object.freeze({
    tenantId: v.tenantId, staffId: v.staffId, sessionId: v.sessionId,
    authenticatedAt: v.authenticatedAt, expiresAt: v.expiresAt, mfaVerifiedAt: v.mfaVerifiedAt,
  })
}

export function parseSchoolControlRequest(value: unknown): SchoolControlRequest | undefined {
  const v = record(value, ['operation', 'tenantId', 'classId'])
  if (!v || !id(v.tenantId) || typeof v.operation !== 'string') return
  const classOperation = (CLASS_OPERATIONS as readonly string[]).includes(v.operation)
  const tenantOperation = (TENANT_OPERATIONS as readonly string[]).includes(v.operation)
  if ((!classOperation && !tenantOperation)
    || (classOperation ? !id(v.classId) : v.classId !== null)) return
  return Object.freeze({
    operation: v.operation as SchoolOperation, tenantId: v.tenantId,
    classId: v.classId as string | null,
  })
}
