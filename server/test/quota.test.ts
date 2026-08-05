import assert from 'node:assert/strict'
import { beforeEach, describe, it } from 'node:test'

import liveToken from '../api/live-token.js'
import { issueToken } from '../lib/auth.js'
import {
  FREE_SESSIONS_PER_DAY,
  MINUTES_PER_SESSION,
  grantEntitlement,
  peekRemaining,
  reserveSession,
} from '../lib/quota.js'

const NOW = Date.UTC(2026, 7, 5, 3, 0) // JST 12:00
let seq = 0
const device = () => `dev-${NOW}-${++seq}`

function fakeRes() {
  const out: { code?: number; body?: unknown; headers: Record<string, string> } = {
    headers: {},
  }
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

beforeEach(() => {
  process.env.AUTH_SECRET = 'x'.repeat(48)
  delete process.env.KV_REST_API_URL
  delete process.env.KV_REST_API_TOKEN
})

describe('セッション数で数える', () => {
  // 分で数えるのをやめた理由:
  // Vertex ではトークンの寿命が会話時間を縛らない。代わりに Vertex 自身が
  // セッションを約10分で打ち切る（実測 code=1000）。縛れる単位が変わった。

  it('1セッションの想定は約10分', () => {
    assert.equal(MINUTES_PER_SESSION, 10)
  })

  it('無料枠のぶんだけ通す', async () => {
    const id = device()
    for (let i = 1; i <= FREE_SESSIONS_PER_DAY; i++) {
      const v = await reserveSession(id, NOW)
      assert.equal(v.granted, true, `${i}回目で止まった`)
      assert.equal(v.remainingSessions, FREE_SESSIONS_PER_DAY - i)
    }
  })

  it('使い切ったら通さない', async () => {
    const id = device()
    for (let i = 0; i < FREE_SESSIONS_PER_DAY; i++) await reserveSession(id, NOW)
    const over = await reserveSession(id, NOW)
    assert.equal(over.granted, false)
    assert.equal(over.remainingSessions, 0)
  })

  it('先に引いてから渡す（渡してから引かない）', async () => {
    // 渡してから引くと、途中で落ちたときに使われたのに引かれていない回数が残る
    const id = device()
    await reserveSession(id, NOW)
    const left = await peekRemaining(id, NOW)
    assert.equal(left.remainingSessions, FREE_SESSIONS_PER_DAY - 1)
  })

  it('日付が変われば戻る', async () => {
    const id = device()
    for (let i = 0; i < FREE_SESSIONS_PER_DAY; i++) await reserveSession(id, NOW)
    assert.equal((await reserveSession(id, NOW)).granted, false)
    assert.equal((await reserveSession(id, NOW + 24 * 3600_000)).granted, true)
  })

  it('日本時間の0時で切る（UTC で切らない）', async () => {
    // UTC で切ると夜9時に枠が戻って不自然
    const jstEvening = Date.UTC(2026, 7, 5, 12, 0) // JST 21:00
    const jstNextMorning = Date.UTC(2026, 7, 5, 16, 0) // JST 翌 01:00
    const id = device()
    for (let i = 0; i < FREE_SESSIONS_PER_DAY; i++) await reserveSession(id, jstEvening)
    assert.equal((await reserveSession(id, jstEvening)).granted, false)
    assert.equal(
      (await reserveSession(id, jstNextMorning)).granted,
      true,
      'JST の日付が変わっても戻っていない',
    )
  })

  it('別の端末は互いに影響しない', async () => {
    const a = device()
    for (let i = 0; i <= FREE_SESSIONS_PER_DAY; i++) await reserveSession(a, NOW)
    assert.equal((await reserveSession(device(), NOW)).granted, true)
  })

  it('peek は引かない', async () => {
    const id = device()
    await peekRemaining(id, NOW)
    await peekRemaining(id, NOW)
    assert.equal((await reserveSession(id, NOW)).remainingSessions,
      FREE_SESSIONS_PER_DAY - 1)
  })
})

describe('課金済み', () => {
  it('上限にかからない', async () => {
    const id = device()
    await grantEntitlement(id, NOW + 30 * 24 * 3600_000)
    for (let i = 0; i < FREE_SESSIONS_PER_DAY + 5; i++) {
      assert.equal((await reserveSession(id, NOW)).granted, true)
    }
    assert.equal((await reserveSession(id, NOW)).entitled, true)
  })

  it('期限が切れたら無料枠に戻る', async () => {
    const id = device()
    await grantEntitlement(id, NOW + 1000)
    assert.equal((await reserveSession(id, NOW)).entitled, true)
    assert.equal((await reserveSession(id, NOW + 2000)).entitled, false)
  })
})

describe('/api/live-token', () => {
  const authed = () => ({ authorization: `Bearer ${issueToken(device())}` })

  it('トークンが無ければ 401', async () => {
    const { res, out } = fakeRes()
    await liveToken({ method: 'POST', headers: {} }, res)
    assert.equal(out.code, 401)
  })

  it('GET は引かずに残りを返す', async () => {
    const h = authed()
    const a = fakeRes()
    await liveToken({ method: 'GET', headers: h }, a.res)
    assert.equal(a.out.code, 200)
    const body = a.out.body as { remainingSessions: number; minutesPerSession: number }
    assert.equal(body.remainingSessions, FREE_SESSIONS_PER_DAY)
    assert.equal(body.minutesPerSession, MINUTES_PER_SESSION)

    const b = fakeRes()
    await liveToken({ method: 'GET', headers: h }, b.res)
    assert.equal(
      (b.out.body as { remainingSessions: number }).remainingSessions,
      FREE_SESSIONS_PER_DAY,
      'GET が枠を消費している',
    )
  })

  const unit = { unitId: 'force-motion' }

  it('使い切ったら 402 を返す', async () => {
    const h = authed()
    // 資格情報の発行は失敗しうる（環境変数が無い等）が、枠は先に引かれる
    for (let i = 0; i < FREE_SESSIONS_PER_DAY; i++) {
      const { res } = fakeRes()
      await liveToken({ method: 'POST', headers: h, body: unit }, res)
    }
    const { res, out } = fakeRes()
    await liveToken({ method: 'POST', headers: h, body: unit }, res)
    assert.equal(out.code, 402)
    assert.equal((out.body as { error: string }).error, 'quota_exhausted')
    assert.ok((out.body as { resetsAt: string }).resetsAt)
  })

  it('単元が無ければ 400。**枠を引かない**', async () => {
    // 単元を渡さないと、デキすぎ君は何を教わるのか知らないまま喋りはじめる
    // （実機で「力と運動」の会話が酸化銀の話で始まった）。
    // ここで弾く。引いてから弾くと、会話していないのに1回減る
    const h = authed()
    for (const body of [undefined, {}, { unitId: 'no-such-unit' }, { unitId: 42 }]) {
      const { res, out } = fakeRes()
      await liveToken({ method: 'POST', headers: h, body }, res)
      assert.equal(out.code, 400)
      assert.equal((out.body as { error: string }).error, 'unknown_unit')
    }

    const after = fakeRes()
    await liveToken({ method: 'GET', headers: h }, after.res)
    assert.equal(
      (after.out.body as { remainingSessions: number }).remainingSessions,
      FREE_SESSIONS_PER_DAY,
    )
  })

  it('本文が文字列でも読む', async () => {
    const { res, out } = fakeRes()
    await liveToken({ method: 'POST', headers: authed(), body: JSON.stringify(unit) }, res)
    assert.notEqual(out.code, 400)
  })

  it('DELETE は 405', async () => {
    const { res, out } = fakeRes()
    await liveToken({ method: 'DELETE' }, res)
    assert.equal(out.code, 405)
    assert.equal(out.headers.Allow, 'GET, POST')
  })
})
