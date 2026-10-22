import assert from 'node:assert/strict'
import { afterEach, beforeEach, describe, it } from 'node:test'
import { MAX_MEMBERS } from '../lib/team.js'
import { CHANGE_COOLDOWN_SECONDS, contribute, createTeam, joinTeam, keys, leaveTeam } from '../lib/team-store.js'
import { useRedisKv } from './support/redis_kv.js'

// Invoked explicitly by Server CI; never uses application or production Redis credentials.
describe('school team membership against isolated Redis', () => {
  let redis: Awaited<ReturnType<typeof useRedisKv>>
  const now = Date.now()
  const makeTeam = (name = 'Synthetic class') => createTeam(name, { now })
  beforeEach(async () => { redis = await useRedisKv() })
  afterEach(async () => { if (redis) await redis.restore() })

  it('admits only one concurrent member into the last seat', async () => {
    const { team, code } = await makeTeam()
    await redis.run(['SADD', keys.members(team.id), ...Array.from({ length: MAX_MEMBERS - 1 }, (_, i) => `filler-${i}`)])
    const results = await Promise.all(Array.from({ length: 24 }, (_, i) => joinTeam(`new-${i}`, code.code, now)))
    assert.equal(results.filter((r) => r.ok).length, 1)
    assert.equal(results.filter((r) => !r.ok && r.reason === 'team_full').length, 23)
    assert.equal(await redis.run(['SCARD', keys.members(team.id)]), MAX_MEMBERS)
  })

  it('concurrent retries of one member are idempotent', async () => {
    const { team, code } = await makeTeam()
    const results = await Promise.all(Array.from({ length: 12 }, () => joinTeam('same', code.code, now)))
    assert.ok(results.every((r) => r.ok && r.memberCount === 1))
    assert.equal(results.filter((r) => r.ok && !r.alreadyIn).length, 1)
    assert.equal(await redis.run(['SCARD', keys.members(team.id)]), 1)
    assert.equal(await redis.run(['GET', keys.mine('same')]), team.id)
  })

  it('one member cannot join two teams concurrently', async () => {
    const a = await makeTeam('Synthetic A')
    const b = await makeTeam('Synthetic B')
    const results = await Promise.all([joinTeam('same', a.code.code, now), joinTeam('same', b.code.code, now)])
    assert.equal(results.filter((r) => r.ok).length, 1)
    assert.equal(results.filter((r) => !r.ok && r.reason === 'in_other_team').length, 1)
    const memberships = await Promise.all([a, b].map((t) => redis.run(['SISMEMBER', keys.members(t.team.id), 'same'])))
    assert.equal(Number(memberships[0]) + Number(memberships[1]), 1)
    const winner = results.find((r) => r.ok)
    assert.ok(winner?.ok)
    assert.equal(await redis.run(['GET', keys.mine('same')]), winner.team.id)
  })

  it('rechecks code revocation after the preliminary lookup', async () => {
    const { team, code } = await makeTeam()
    redis.hooks.beforeEval = async () => { await redis.run(['HSET', keys.code(code.code), 'revoked', '1']) }
    assert.deepEqual(await joinTeam('same', code.code, now), { ok: false, reason: 'expired' })
    assert.equal(await redis.run(['SCARD', keys.members(team.id)]), 0)
    assert.equal(await redis.run(['GET', keys.mine('same')]), null)
  })

  it('rejects expired, malformed or retargeted codes without a write', async () => {
    const { team, code } = await makeTeam()
    for (const value of [String(now), 'invalid']) {
      await redis.run(['HSET', keys.code(code.code), 'expiresAt', value])
      assert.deepEqual(await joinTeam('same', code.code, now), { ok: false, reason: 'expired' })
    }
    await redis.run(['HSET', keys.code(code.code), 'expiresAt', String(now + 60_000)])
    redis.hooks.beforeEval = async () => { await redis.run(['HSET', keys.code(code.code), 'teamId', 'other']) }
    assert.deepEqual(await joinTeam('same', code.code, now), { ok: false, reason: 'unknown_code' })
    assert.equal(await redis.run(['SCARD', keys.members(team.id)]), 0)
    assert.equal(await redis.run(['GET', keys.mine('same')]), null)
  })

  it('leave and another-team join cannot bypass the cooldown', async () => {
    const a = await makeTeam('Synthetic A')
    const b = await makeTeam('Synthetic B')
    assert.ok((await joinTeam('same', a.code.code, now)).ok)
    await redis.run(['HSET', keys.memberDays(a.team.id, 'same'), '2026-10-22', '3'])
    await redis.run(['HSET', keys.sum(a.team.id, a.team.periodId), 'total', '7'])
    const [left, joined] = await Promise.all([leaveTeam('same', a.team.id, now), joinTeam('same', b.code.code, now)])
    assert.equal(left, true)
    assert.equal(joined.ok, false)
    assert.equal(await redis.run(['GET', keys.mine('same')]), null)
    assert.equal(await redis.run(['SCARD', keys.members(a.team.id)]), 0)
    assert.equal(await redis.run(['SCARD', keys.members(b.team.id)]), 0)
    assert.equal(await redis.run(['EXISTS', keys.memberDays(a.team.id, 'same')]), 0)
    assert.equal(await redis.run(['HGET', keys.sum(a.team.id, a.team.periodId), 'total']), '7')
    assert.equal(await redis.run(['GET', keys.cooldown('same')]), String(now + CHANGE_COOLDOWN_SECONDS * 1000))
    assert.deepEqual(await joinTeam('same', a.code.code, now), { ok: false, reason: 'cooldown' })
    assert.ok((await joinTeam('same', b.code.code, now + CHANGE_COOLDOWN_SECONDS * 1000)).ok)
  })

  it('duplicate leaves change membership exactly once', async () => {
    const { team, code } = await makeTeam()
    await joinTeam('same', code.code, now)
    const results = await Promise.all([leaveTeam('same', team.id, now), leaveTeam('same', team.id, now + 1)])
    assert.equal(results.filter(Boolean).length, 1)
    assert.equal(await redis.run(['SCARD', keys.members(team.id)]), 0)
  })

  it('never deletes a different current membership from a stale leave', async () => {
    const a = await makeTeam('Synthetic A')
    const b = await makeTeam('Synthetic B')
    await joinTeam('same', b.code.code, now)
    await redis.run(['SADD', keys.members(a.team.id), 'same'])
    assert.equal(await leaveTeam('same', a.team.id, now), false)
    assert.deepEqual(await joinTeam('same', a.code.code, now), { ok: false, reason: 'in_other_team' })
    assert.equal(await redis.run(['GET', keys.mine('same')]), b.team.id)
    assert.equal(await redis.run(['SISMEMBER', keys.members(b.team.id), 'same']), 1)
    assert.equal(await redis.run(['GET', keys.cooldown('same')]), null)
  })

  it('Redis type failures do not create a partial membership', async () => {
    const { team, code } = await makeTeam()
    await redis.run(['SET', keys.members(team.id), 'wrong-type'])
    await assert.rejects(joinTeam('same', code.code, now), /KV command/)
    assert.equal(await redis.run(['GET', keys.mine('same')]), null)
    assert.equal(await redis.run(['GET', keys.members(team.id)]), 'wrong-type')
  })

  it('a queued contribution cannot recreate individual records after leaving', async () => {
    const { team, code } = await makeTeam()
    await joinTeam('same', code.code, now)
    await contribute('same', team, [{ day: team.periodStart, value: 1 }])
    redis.hooks.beforeEval = async () => { assert.equal(await leaveTeam('same', team.id, now), true) }
    const result = await contribute('same', team, [{ day: team.periodStart, value: 3 }])
    assert.deepEqual(result, { applied: [], rejected: [{ day: team.periodStart, reason: 'not_in_team' }] })
    assert.equal(await redis.run(['EXISTS', keys.memberDays(team.id, 'same')]), 0)
    assert.equal(await redis.run(['HGET', keys.sum(team.id, team.periodId), 'total']), '1')
  })

  it('concurrent daily contributions increment only the highest observed delta', async () => {
    const { team, code } = await makeTeam()
    await joinTeam('same', code.code, now)
    const values = [1, 3, 2, 3, 1, 2, 3, 3]
    const results = await Promise.all(values.map((value) => contribute('same', team, [{ day: team.periodStart, value }])))
    assert.ok(results.every((r) => r.rejected.length === 0))
    assert.equal(results.flatMap((r) => r.applied).reduce((sum, r) => sum + r.added, 0), 3)
    assert.equal(await redis.run(['HGET', keys.memberDays(team.id, 'same'), team.periodStart]), '3')
    assert.equal(await redis.run(['HGET', keys.sum(team.id, team.periodId), 'total']), '3')
  })

  it('a failed aggregate increment does not advance the individual day', async () => {
    const { team, code } = await makeTeam()
    await joinTeam('same', code.code, now)
    await contribute('same', team, [{ day: team.periodStart, value: 1 }])
    await redis.run(['HSET', keys.sum(team.id, team.periodId), 'total', 'not-an-integer'])
    await assert.rejects(contribute('same', team, [{ day: team.periodStart, value: 3 }]), /KV command/)
    assert.equal(await redis.run(['HGET', keys.memberDays(team.id, 'same'), team.periodStart]), '1')
    assert.equal(await redis.run(['HGET', keys.sum(team.id, team.periodId), 'total']), 'not-an-integer')
  })

  it('rejects a contribution from an obsolete team period', async () => {
    const { team, code } = await makeTeam()
    await joinTeam('same', code.code, now)
    await redis.run(['HSET', keys.team(team.id), 'periodId', 'other-period'])
    const result = await contribute('same', team, [{ day: team.periodStart, value: 3 }])
    assert.deepEqual(result, { applied: [], rejected: [{ day: team.periodStart, reason: 'not_in_team' }] })
    assert.equal(await redis.run(['EXISTS', keys.memberDays(team.id, 'same')]), 0)
    assert.equal(await redis.run(['EXISTS', keys.sum(team.id, team.periodId)]), 0)
  })
})
