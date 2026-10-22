import assert from 'node:assert/strict'
import { afterEach, beforeEach, describe, it } from 'node:test'
import {
  parseSchoolClass, parseSchoolControlRequest, parseSchoolStaffSession,
  parseSchoolTenant, parseStaffMembership,
} from '../lib/school-control-contracts.js'
import { authorizeSchoolOperation, type SchoolPolicyAdapters } from '../lib/school-control-policy.js'

const NOW = 10_000
const session = () => ({
  tenantId: 'tenant-a', staffId: 'staff-a', sessionId: 'session-a',
  authenticatedAt: 1_000, expiresAt: 20_000, mfaVerifiedAt: 2_000,
})
const tenant = () => ({ tenantId: 'tenant-a', status: 'active' })
const membership = () => ({
  tenantId: 'tenant-a', staffId: 'staff-a', role: 'teacher', status: 'active', classIds: ['class-a'],
})
const classroom = () => ({
  tenantId: 'tenant-a', schoolId: 'school-a', classId: 'class-a', schoolYearId: 'year-a', status: 'active',
})
const request = () => ({ operation: 'read_concept_aggregate', tenantId: 'tenant-a', classId: 'class-a' })

function fixture() {
  const data: Record<'session' | 'tenant' | 'membership' | 'classroom', unknown> = {
    session: session(), tenant: tenant(), membership: membership(), classroom: classroom(),
  }
  const calls: unknown[][] = []
  const adapters: SchoolPolicyAdapters = {
    async authenticate() { calls.push(['authenticate']); return data.session },
    async loadTenant(id) { calls.push(['tenant', id]); return data.tenant },
    async loadMembership(id, staffId) { calls.push(['membership', id, staffId]); return data.membership },
    async loadClass(id, classId) { calls.push(['class', id, classId]); return data.classroom },
  }
  return { data, calls, adapters, run: (input: unknown = request()) =>
    authorizeSchoolOperation(input, adapters, () => NOW) }
}

const ENV_KEYS = ['NODE_ENV', 'VERCEL_ENV', 'DEKISUGI_INTERNAL_SCHOOL_TESTING'] as const
let environment: (string | undefined)[]
beforeEach(() => {
  environment = ENV_KEYS.map(key => process.env[key])
  process.env.NODE_ENV = 'test'
  delete process.env.VERCEL_ENV
  process.env.DEKISUGI_INTERNAL_SCHOOL_TESTING = '1'
})
afterEach(() => ENV_KEYS.forEach((key, index) => {
  const value = environment[index]
  if (value === undefined) delete process.env[key]
  else process.env[key] = value
}))

describe('school contracts', () => {
  const contracts = [
    [parseSchoolTenant, tenant], [parseSchoolClass, classroom],
    [parseStaffMembership, membership], [parseSchoolStaffSession, session],
    [parseSchoolControlRequest, request],
  ] as const

  it('accepts only exact records and rejects extra personal-data and credential fields', () => {
    for (const [parse, value] of contracts) {
      assert.ok(parse(value()))
      for (const extra of ['audio', 'answer', 'studentName', 'ranking', 'deviceId', 'token', 'metadata']) {
        assert.equal(parse({ ...value(), [extra]: 'synthetic' }), undefined, extra)
      }
      for (const key of Object.keys(value())) {
        const missing: Record<string, unknown> = { ...value() }
        delete missing[key]
        assert.equal(parse(missing), undefined, key)
      }
      for (const invalid of [null, [], 'token', true, 0, Object.create(value())]) {
        assert.equal(parse(invalid), undefined)
      }
    }
  })

  it('rejects accessors, nonenumerable fields, symbols and prototype pollution', () => {
    let invoked = false
    const getter = { ...tenant() }
    Object.defineProperty(getter, 'status', { get() { invoked = true; return 'active' } })
    assert.equal(parseSchoolTenant(getter), undefined)
    assert.equal(invoked, false)
    assert.equal(parseSchoolTenant(Object.defineProperty(tenant(), 'status', { enumerable: false })), undefined)
    assert.equal(parseSchoolTenant({ ...tenant(), [Symbol('extra')]: 'x' }), undefined)
    assert.equal(parseSchoolTenant(JSON.parse('{"tenantId":"tenant-a","status":"active","__proto__":{}}')), undefined)
  })

  it('rejects empty or non-opaque identifiers and unknown states or roles', () => {
    for (const tenantId of ['', 'school@example.test', '../tenant-a', 'a'.repeat(129), 1]) {
      assert.equal(parseSchoolTenant({ ...tenant(), tenantId }), undefined)
    }
    assert.equal(parseSchoolTenant({ ...tenant(), status: 'enabled' }), undefined)
    assert.equal(parseStaffMembership({ ...membership(), role: 'superadmin' }), undefined)
    assert.equal(parseStaffMembership({ ...membership(), status: 'enabled' }), undefined)
    assert.equal(parseSchoolClass({ ...classroom(), status: 'enabled' }), undefined)
  })

  it('requires unique, present class identifiers and returns detached immutable snapshots', () => {
    for (const classIds of [
      ['class-a', 'class-a'], [''], [null], new Array(1),
      Object.assign(['class-a'], { metadata: 'synthetic' }),
      Object.defineProperty(['class-a'], '0', { get() { throw new Error('must not read') } }),
    ]) {
      assert.equal(parseStaffMembership({ ...membership(), classIds }), undefined)
    }
    const input = membership()
    const parsed = parseStaffMembership(input)!
    input.classIds.push('class-b')
    input.role = 'admin'
    assert.deepEqual(parsed.classIds, ['class-a'])
    assert.equal(parsed.role, 'teacher')
    assert.ok(Object.isFrozen(parsed) && Object.isFrozen(parsed.classIds))
  })

  it('requires explicit scope and refuses unknown operations and client-supplied authority', () => {
    for (const input of [
      { ...request(), operation: 'export_students' }, { ...request(), operation: 'toString' },
      { ...request(), operation: 'delete_tenant' }, { ...request(), classId: null },
      { ...request(), operation: 'read_audit' }, { ...request(), role: 'admin' },
    ]) assert.equal(parseSchoolControlRequest(input), undefined)
    assert.ok(parseSchoolControlRequest({ ...request(), operation: 'read_audit', classId: null }))
  })

  it('rejects impossible session and MFA timestamps without coercion', () => {
    for (const expiresAt of [0, 1_000, Infinity, NaN, 20_000.5, '20000', Number.MAX_SAFE_INTEGER + 1]) {
      assert.equal(parseSchoolStaffSession({ ...session(), expiresAt }), undefined)
    }
    for (const mfaVerifiedAt of [-1, 999, 20_000, true, '2000']) {
      assert.equal(parseSchoolStaffSession({ ...session(), mfaVerifiedAt }), undefined)
    }
    assert.ok(parseSchoolStaffSession({ ...session(), mfaVerifiedAt: null }))
  })
})

describe('school policy core', () => {
  it('allows a current MFA-authenticated teacher to read only their assigned active class', async () => {
    const f = fixture()
    const result = await f.run()
    assert.deepEqual(result, { allowed: true, staffId: 'staff-a', request: request() })
    assert.deepEqual(f.calls, [
      ['authenticate'], ['tenant', 'tenant-a'], ['membership', 'tenant-a', 'staff-a'],
      ['class', 'tenant-a', 'class-a'],
    ])
  })

  it('explicitly grants each known admin operation with its required scope', async () => {
    const f = fixture()
    f.data.membership = { ...membership(), role: 'admin', classIds: [] }
    for (const operation of ['read_concept_aggregate', 'manage_class', 'manage_enrollment']) {
      assert.equal((await f.run({ ...request(), operation })).allowed, true, operation)
    }
    for (const operation of ['manage_staff', 'manage_license', 'read_audit', 'request_deletion']) {
      assert.equal((await f.run({ ...request(), operation, classId: null })).allowed, true, operation)
    }
  })

  it('does not grant teachers administrative actions or unassigned classes', async () => {
    const f = fixture()
    for (const operation of ['manage_class', 'manage_enrollment']) {
      assert.deepEqual(await f.run({ ...request(), operation }), { allowed: false })
    }
    for (const operation of ['manage_staff', 'manage_license', 'read_audit', 'request_deletion']) {
      assert.deepEqual(await f.run({ ...request(), operation, classId: null }), { allowed: false })
    }
    f.data.membership = { ...membership(), classIds: ['class-b'] }
    assert.deepEqual(await f.run(), { allowed: false })
  })

  it('gives support and unknown roles no implicit permissions', async () => {
    const f = fixture()
    for (const role of ['support', 'superadmin', 'ADMIN', null]) {
      f.data.membership = { ...membership(), role }
      assert.deepEqual(await f.run(), { allowed: false })
      assert.deepEqual(await f.run({ ...request(), operation: 'read_audit', classId: null }), { allowed: false })
    }
  })

  it('denies substituted tenant, principal and resource identifiers at every boundary', async () => {
    const cases = [
      ['session', { ...session(), tenantId: 'tenant-b' }],
      ['tenant', { ...tenant(), tenantId: 'tenant-b' }],
      ['membership', { ...membership(), tenantId: 'tenant-b' }],
      ['membership', { ...membership(), staffId: 'staff-b' }],
      ['classroom', { ...classroom(), tenantId: 'tenant-b' }],
      ['classroom', { ...classroom(), classId: 'class-b' }],
    ] as const
    for (const [key, value] of cases) {
      const f = fixture()
      f.data[key] = value
      assert.deepEqual(await f.run(), { allowed: false }, key)
    }
    assert.deepEqual(await fixture().run({ ...request(), tenantId: 'tenant-b' }), { allowed: false })
  })

  it('denies revoked or missing records and suspended tenants/classes/memberships', async () => {
    for (const key of ['session', 'tenant', 'membership', 'classroom'] as const) {
      const f = fixture()
      f.data[key] = null
      assert.deepEqual(await f.run(), { allowed: false }, key)
    }
    for (const [key, value] of [
      ['tenant', { ...tenant(), status: 'suspended' }],
      ['membership', { ...membership(), status: 'suspended' }],
      ['membership', { ...membership(), status: 'revoked' }],
      ['classroom', { ...classroom(), status: 'archived' }],
    ] as const) {
      const f = fixture()
      f.data[key] = value
      assert.deepEqual(await f.run(), { allowed: false }, key)
    }
  })

  it('requires MFA and a currently valid session, including after adapter I/O', async () => {
    for (const value of [
      { ...session(), mfaVerifiedAt: null }, { ...session(), mfaVerifiedAt: NOW + 1 },
      { ...session(), authenticatedAt: NOW + 1, mfaVerifiedAt: NOW + 2 },
      { ...session(), expiresAt: NOW }, { ...session(), expiresAt: NOW - 1 },
    ]) {
      const f = fixture()
      f.data.session = value
      assert.deepEqual(await f.run(), { allowed: false })
      assert.deepEqual(f.calls, [['authenticate']])
    }
    const f = fixture()
    let currentTime = NOW
    f.adapters.loadClass = async () => { currentTime = 20_000; return classroom() }
    assert.deepEqual(await authorizeSchoolOperation(request(), f.adapters, () => currentTime), { allowed: false })
    for (const now of [NaN, Infinity, -1, 1.5]) {
      assert.deepEqual(await authorizeSchoolOperation(request(), fixture().adapters, () => now), { allowed: false })
    }
  })

  it('fails closed for every adapter failure without exposing the error', async () => {
    for (const key of ['authenticate', 'loadTenant', 'loadMembership', 'loadClass'] as const) {
      const f = fixture()
      f.adapters[key] = async () => { throw new Error('synthetic-private-value') }
      assert.deepEqual(await f.run(), { allowed: false }, key)
    }
  })

  it('never accepts legacy device tokens, LAN keys or an asserted role from the request', async () => {
    for (const input of ['device.token', 'LAN-ADMIN-KEY', { ...request(), role: 'admin' }]) {
      const f = fixture()
      assert.deepEqual(await f.run(input), { allowed: false })
      assert.deepEqual(f.calls, [])
    }
    const f = fixture()
    f.data.session = { did: 'device-a', iat: 1_000, exp: 20_000 }
    assert.deepEqual(await f.run(), { allowed: false })
  })

  it('snapshots request scope before asynchronous authentication', async () => {
    const f = fixture()
    const input = request()
    f.adapters.authenticate = async () => {
      input.tenantId = 'tenant-b'
      input.operation = 'manage_staff'
      return session()
    }
    const result = await f.run(input)
    assert.deepEqual(result, { allowed: true, staffId: 'staff-a', request: request() })
    assert.ok(Object.isFrozen(result))
    if (result.allowed) assert.ok(Object.isFrozen(result.request))
  })
})

describe('existing school deployment gate', () => {
  it('performs zero adapter calls when disabled, in production/preview or an unknown environment', async () => {
    for (const [node, vercel, flag] of [
      ['test', undefined, undefined], ['test', undefined, 'true'], ['production', undefined, '1'],
      ['test', 'production', '1'], ['test', 'preview', '1'], ['test', 'other', '1'],
      ['production', 'development', '1'],
    ]) {
      for (const [key, value] of [
        ['NODE_ENV', node], ['VERCEL_ENV', vercel], ['DEKISUGI_INTERNAL_SCHOOL_TESTING', flag],
      ]) {
        if (value === undefined) delete process.env[key!]
        else process.env[key!] = value
      }
      const f = fixture()
      assert.deepEqual(await f.run(), { allowed: false })
      assert.deepEqual(f.calls, [])
    }
  })

  it('allows explicit internal development testing and rechecks closure after I/O', async () => {
    process.env.VERCEL_ENV = 'development'
    assert.equal((await fixture().run()).allowed, true)
    const f = fixture()
    f.adapters.loadClass = async () => {
      process.env.VERCEL_ENV = 'production'
      return classroom()
    }
    assert.deepEqual(await f.run(), { allowed: false })
  })
})
