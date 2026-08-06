import assert from 'node:assert/strict'
import { afterEach, beforeEach, describe, it } from 'node:test'

import admin from '../api/team/admin.js'
import join from '../api/team/join.js'
import leave from '../api/team/leave.js'
import { issueToken } from '../lib/auth.js'
import {
  CODE_ALPHABET,
  CODE_LENGTH,
  MAX_MEMBERS,
  MIN_MEMBERS_FOR_TOTAL,
  memberId,
  newInviteCode,
  normalizeCode,
  normalizeTeamName,
} from '../lib/team.js'
import { keys } from '../lib/team-store.js'
import { useFakeKv, type FakeKv } from './support/fake_kv.js'

let seq = 0
const device = () => `dev-${++seq}`

function fakeRes() {
  const out: { code?: number; body?: any; headers: Record<string, string> } = { headers: {} }
  const res = {
    status(c: number) {
      out.code = c
      return res
    },
    json(b: unknown) {
      out.body = b
    },
    setHeader(n: string, v: string) {
      out.headers[n] = v
    },
  }
  return { res, out }
}

const ADMIN = 'admin-token-for-tests'

let fake: FakeKv
let restore: () => void

beforeEach(() => {
  process.env.AUTH_SECRET = 'x'.repeat(48)
  process.env.TEAM_ADMIN_TOKEN = ADMIN
  const f = useFakeKv()
  fake = f.kv
  restore = f.restore
})
afterEach(() => {
  restore()
  delete process.env.TEAM_ADMIN_TOKEN
})

/** チームを1つ作って招待コードを返す。 */
async function makeTeam(name = '2年A組'): Promise<{ code: string; teamId: string }> {
  const { res, out } = fakeRes()
  await admin(
    { method: 'POST', headers: { authorization: `Bearer ${ADMIN}` }, body: { name } },
    res,
  )
  assert.equal(out.code, 200, JSON.stringify(out.body))
  return { code: out.body.inviteCode as string, teamId: out.body.teamId as string }
}

/** 端末を1つ作ってチームに入れる。 */
async function joinAs(code: string, did = device()) {
  const { res, out } = fakeRes()
  await join(
    { method: 'POST', headers: { authorization: `Bearer ${issueToken(did)}` }, body: { inviteCode: code } },
    res,
  )
  return { did, ...out }
}

describe('招待コード', () => {
  it('読み違えやすい文字を使わない', () => {
    // 紙に書いて配る。0/O と 1/I/L は取り違えの元
    for (const bad of ['0', 'O', '1', 'I', 'L', 'U']) {
      assert.ok(!CODE_ALPHABET.includes(bad), `${bad} が入っている`)
    }
    const code = newInviteCode()
    assert.equal(code.length, CODE_LENGTH)
  })

  it('ハイフンも小文字も受ける', () => {
    const code = newInviteCode()
    const shown = `${code.slice(0, 4)}-${code.slice(4)}`
    assert.equal(normalizeCode(shown.toLowerCase()), code)
    assert.equal(normalizeCode(` ${shown} `), code)
  })

  it('形が違えば受けない', () => {
    for (const v of [undefined, '', 'ABC', 'A'.repeat(20), 'ABCD-EFG0', 42]) {
      assert.equal(normalizeCode(v), undefined, `${String(v)} を受けてしまった`)
    }
  })
})

describe('チーム名', () => {
  it('長すぎるもの・空・URL を弾く', () => {
    assert.equal(normalizeTeamName(''), undefined)
    assert.equal(normalizeTeamName('あ'.repeat(25)), undefined)
    assert.equal(normalizeTeamName('http://example.com'), undefined)
    assert.equal(normalizeTeamName(42), undefined)
  })

  it('改行を潰して前後を落とす', () => {
    assert.equal(normalizeTeamName('  2年A組\n '), '2年A組')
  })
})

describe('POST /api/team/admin', () => {
  it('管理トークンが未設定なら閉じる', async () => {
    delete process.env.TEAM_ADMIN_TOKEN
    const { res, out } = fakeRes()
    await admin({ method: 'POST', headers: {}, body: { name: 'A' } }, res)
    assert.equal(out.code, 401, '未設定で素通しになっている')
  })

  it('合わないトークンを弾く', async () => {
    const { res, out } = fakeRes()
    await admin(
      { method: 'POST', headers: { authorization: 'Bearer nope' }, body: { name: 'A' } },
      res,
    )
    assert.equal(out.code, 401)
  })

  it('コードを配る形で返す', async () => {
    const { code } = await makeTeam()
    assert.match(code, /^[A-Z0-9]{4}-[A-Z0-9]{4}$/)
  })

  it('毎回ちがうコードになる', async () => {
    const a = await makeTeam()
    const b = await makeTeam()
    assert.notEqual(a.code, b.code)
    assert.notEqual(a.teamId, b.teamId)
  })

  it('失効させると入れなくなる', async () => {
    const { code } = await makeTeam()
    const del = fakeRes()
    await admin(
      {
        method: 'DELETE',
        headers: { authorization: `Bearer ${ADMIN}` },
        query: { code },
      },
      del.res,
    )
    assert.equal(del.out.code, 200)

    const r = await joinAs(code)
    assert.equal(r.code, 410, '失効したコードで入れてしまう')
  })

  it('保存先が無ければ 503。**200 を返さない**', async () => {
    restore()
    const { res, out } = fakeRes()
    await admin(
      { method: 'POST', headers: { authorization: `Bearer ${ADMIN}` }, body: { name: 'A' } },
      res,
    )
    assert.equal(out.code, 503)
    restore = () => {}
  })
})

describe('POST /api/team/join', () => {
  it('端末トークンが要る', async () => {
    const { res, out } = fakeRes()
    await join({ method: 'POST', headers: {}, body: { inviteCode: 'ABCD-EFGH' } }, res)
    assert.equal(out.code, 401)
  })

  it('入れる', async () => {
    const { code, teamId } = await makeTeam()
    const r = await joinAs(code)
    assert.equal(r.code, 200)
    assert.equal(r.body.teamId, teamId)
    assert.equal(r.body.teamName, '2年A組')
  })

  it('実人数を返さない', async () => {
    // 1人の増減が見えると「誰かが抜けた」が伝わる
    const { code } = await makeTeam()
    const r = await joinAs(code)
    assert.equal(r.body.memberCount, MIN_MEMBERS_FOR_TOTAL,
      '1人目なのに実人数が漏れている')
  })

  it('知らないコードは 404', async () => {
    const r = await joinAs('ZZZZ-ZZZZ')
    assert.equal(r.code, 404)
  })

  it('同じチームへの二度目は成功にする（冪等）', async () => {
    // 応答を取りこぼして押し直したときに 409 で止めない
    const { code } = await makeTeam()
    const did = device()
    const a = await joinAs(code, did)
    const b = await joinAs(code, did)
    assert.equal(a.code, 200)
    assert.equal(b.code, 200)
  })

  it('別のチームには入れない', async () => {
    const a = await makeTeam('A組')
    const b = await makeTeam('B組')
    const did = device()
    await joinAs(a.code, did)
    const r = await joinAs(b.code, did)
    assert.equal(r.code, 409)
    assert.equal(r.body.error, 'in_other_team')
  })

  it('人数の上限で止まる', async () => {
    const { code, teamId } = await makeTeam()
    // 直に詰めて上限まで埋める（60回 join するのは遅い）
    for (let i = 0; i < MAX_MEMBERS; i++) {
      fake.run(['SADD', keys.members(teamId), `filler-${i}`])
    }
    const r = await joinAs(code)
    assert.equal(r.code, 409)
    assert.equal(r.body.error, 'team_full')
  })

  it('保存先が無ければ 503', async () => {
    restore()
    const { res, out } = fakeRes()
    await join(
      {
        method: 'POST',
        headers: { authorization: `Bearer ${issueToken(device())}` },
        body: { inviteCode: 'ABCD-EFGH' },
      },
      res,
    )
    assert.equal(out.code, 503)
    restore = () => {}
  })
})

describe('POST /api/team/leave', () => {
  async function leaveAs(did: string, teamId?: string) {
    const { res, out } = fakeRes()
    await leave(
      {
        method: 'POST',
        headers: { authorization: `Bearer ${issueToken(did)}` },
        body: teamId ? { teamId } : {},
      },
      res,
    )
    return out
  }

  it('抜けられる', async () => {
    const { code } = await makeTeam()
    const { did } = await joinAs(code)
    const out = await leaveAs(did)
    assert.equal(out.code, 200)
  })

  it('teamId を渡さなくても抜けられる', async () => {
    // 端末が控えを失っていても、サーバが所属を知っている
    const { code } = await makeTeam()
    const { did } = await joinAs(code)
    assert.equal((await leaveAs(did)).code, 200)
  })

  it('入っていなければ 404', async () => {
    assert.equal((await leaveAs(device())).code, 404)
  })

  it('合計を減らさない', async () => {
    // 合計が落ちると「誰かが抜けた」が全員に見える
    const { code, teamId } = await makeTeam()
    const { did } = await joinAs(code)
    const sumKey = keys.sum(teamId, 'w:2026-08-03')
    fake.run(['HINCRBY', sumKey, 'total', '42'])

    await leaveAs(did)
    assert.equal(Number(fake.run(['HGET', sumKey, 'total'])), 42,
      '退出で合計が減っている')
  })

  it('個人の記録は消す', async () => {
    // 残る合計を「誰にも帰属しない集計値」にするため
    const { code, teamId } = await makeTeam()
    const { did } = await joinAs(code)
    const mid = memberId(did)
    fake.run(['HSET', keys.memberDays(teamId, mid), '2026-08-06', '3'])

    await leaveAs(did)
    assert.deepEqual(fake.run(['HGETALL', keys.memberDays(teamId, mid)]), {},
      '個人の記録が残っている')
  })

  it('抜けた直後は別のチームに移れない', async () => {
    const a = await makeTeam('A組')
    const b = await makeTeam('B組')
    const { did } = await joinAs(a.code)
    await leaveAs(did)
    const r = await joinAs(b.code, did)
    assert.equal(r.code, 429)
    assert.equal(r.body.error, 'cooldown')
  })

  it('抜けた直後は**同じチームにも**入り直せない', async () => {
    // ここが本体。退出は合計を減らさず個人の記録だけ消すので、
    // 入り直して同じ日を送り直すと合計に二重で乗る。
    // 移籍だけを止めても塞がらない（設計時に見落として、テストで捕まえた）
    const { code } = await makeTeam()
    const { did } = await joinAs(code)
    await leaveAs(did)

    const r = await joinAs(code, did)
    assert.equal(r.code, 429, '同じチームへ入り直せてしまう＝二重加算の道が開く')
  })

  it('抜けていなければクールダウンは掛からない', async () => {
    // 初参加を止めない
    const { code } = await makeTeam()
    const r = await joinAs(code)
    assert.equal(r.code, 200)
  })
})

describe('保存物', () => {
  it('キーに端末IDが1文字も入らない', async () => {
    const { code } = await makeTeam()
    const did = device()
    await joinAs(code, did)

    for (const key of fake.data.keys()) {
      assert.ok(!key.includes(did), `キーに端末IDが入っている: ${key}`)
    }
  })

  it('値にも端末IDが入らない', async () => {
    const { code } = await makeTeam()
    const did = device()
    await joinAs(code, did)

    const dump = JSON.stringify([...fake.data].map(([k, v]) => [k, v instanceof Set ? [...v] : v instanceof Map ? [...v] : v]))
    assert.ok(!dump.includes(did), '保存物に端末IDが入っている')
  })

  it('すべて t: の下に置く', async () => {
    const { code } = await makeTeam()
    await joinAs(code)
    for (const key of fake.data.keys()) {
      assert.ok(key.startsWith('t:'), `名前空間の外: ${key}`)
    }
  })
})
