import assert from 'node:assert/strict'
import { afterEach, beforeEach, describe, it } from 'node:test'
import { MAX_MEMBERS } from '../lib/team.js'
import { CONTRIBUTE_TEAM_SCRIPT } from '../lib/team-membership-scripts.js'
import { contribute, createTeam, joinTeam, keys, leaveTeam } from '../lib/team-store.js'
import { useFakeKv } from './support/fake_kv.js'

describe('atomic team membership boundary', () => {
  let fixture: ReturnType<typeof useFakeKv>
  beforeEach(() => { fixture = useFakeKv() })
  afterEach(() => fixture.restore())

  it('never admits two members into the last seat', async () => {
    const { kv } = fixture
    const { team, code } = await createTeam('Synthetic class', { now: kv.now })
    for (let i = 0; i < MAX_MEMBERS - 1; i++) kv.run(['SADD', keys.members(team.id), `filler-${i}`])
    const results = await Promise.all(['one', 'two'].map((mid) => joinTeam(mid, code.code, kv.now)))
    assert.equal(results.filter((r) => r.ok).length, 1)
    assert.equal(kv.run(['SCARD', keys.members(team.id)]), MAX_MEMBERS)
  })

  it('keeps one membership when the same member concurrently chooses two teams', async () => {
    const { kv } = fixture
    const a = await createTeam('Synthetic A', { now: kv.now })
    const b = await createTeam('Synthetic B', { now: kv.now })
    const results = await Promise.all([a, b].map((t) => joinTeam('same', t.code.code, kv.now)))
    assert.equal(results.filter((r) => r.ok).length, 1)
    assert.equal(Number(kv.run(['SISMEMBER', keys.members(a.team.id), 'same']))
      + Number(kv.run(['SISMEMBER', keys.members(b.team.id), 'same'])), 1)
  })

  it('returns one created membership and one idempotent retry', async () => {
    const { kv } = fixture
    const { team, code } = await createTeam('Synthetic class', { now: kv.now })
    const results = await Promise.all([joinTeam('same', code.code, kv.now), joinTeam('same', code.code, kv.now)])
    assert.ok(results.every((r) => r.ok && r.memberCount === 1))
    assert.equal(results.filter((r) => r.ok && !r.alreadyIn).length, 1)
    assert.equal(kv.run(['SCARD', keys.members(team.id)]), 1)
  })

  it('does not accept malformed join or leave execution results', async () => {
    const { kv } = fixture
    const { team, code } = await createTeam('Synthetic class', { now: kv.now })
    const original = globalThis.fetch
    for (const result of [null, [], [1], [1, 'class', 'week', 'start', 'end', -1, 0], [0, 'unexpected']]) {
      globalThis.fetch = (async (input, init) => {
        const commands = JSON.parse(String(init?.body)) as string[][]
        if (commands[0]?.[0] === 'EVAL') return new Response(JSON.stringify([{ result }]))
        return original(input, init)
      }) as typeof fetch
      await assert.rejects(joinTeam('same', code.code, kv.now), /チーム参加応答の形式が不正/)
    }
    globalThis.fetch = (async () => new Response(JSON.stringify([{ result: '1' }]))) as typeof fetch
    await assert.rejects(leaveTeam('same', team.id, kv.now), /チーム退出応答の形式が不正/)
    globalThis.fetch = original
  })

  it('rejects a delayed contribution after the membership has been removed', async () => {
    const { kv } = fixture
    const { team, code } = await createTeam('Synthetic class', { now: kv.now })
    await joinTeam('same', code.code, kv.now)
    await contribute('same', team, [{ day: team.periodStart, value: 1 }])
    const original = globalThis.fetch
    let left = false
    globalThis.fetch = (async (input, init) => {
      const commands = JSON.parse(String(init?.body)) as string[][]
      if (!left && commands[0]?.[1] === CONTRIBUTE_TEAM_SCRIPT) {
        left = true
        assert.equal(await leaveTeam('same', team.id, kv.now), true)
      }
      return original(input, init)
    }) as typeof fetch
    const result = await contribute('same', team, [{ day: team.periodStart, value: 3 }])
    assert.deepEqual(result, { applied: [], rejected: [{ day: team.periodStart, reason: 'not_in_team' }] })
    assert.equal(kv.run(['HGET', keys.memberDays(team.id, 'same'), team.periodStart]), null)
    assert.equal(kv.run(['HGET', keys.sum(team.id, team.periodId), 'total']), '1')
  })

  it('adds each daily increase once even when requests overlap', async () => {
    const { kv } = fixture
    const { team, code } = await createTeam('Synthetic class', { now: kv.now })
    await joinTeam('same', code.code, kv.now)
    const results = await Promise.all([1, 3, 2, 3].map((value) => contribute('same', team, [{ day: team.periodStart, value }])))
    assert.equal(results.flatMap((r) => r.applied).reduce((sum, r) => sum + r.added, 0), 3)
    assert.equal(kv.run(['HGET', keys.memberDays(team.id, 'same'), team.periodStart]), '3')
    assert.equal(kv.run(['HGET', keys.sum(team.id, team.periodId), 'total']), '3')
  })
})
