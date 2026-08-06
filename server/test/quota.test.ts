import assert from 'node:assert/strict'
import { beforeEach, describe, it } from 'node:test'

import liveToken from '../api/live-token.js'
import { issueToken } from '../lib/auth.js'
import { jstDayKey } from '../lib/day.js'
import { liveSessionConfig } from '../lib/live-config.js'
import { clampBySessions } from '../lib/team.js'
import {
  FREE_SESSIONS_PER_DAY,
  MINUTES_PER_SESSION,
  MAX_RESUMES_PER_WINDOW,
  RESUME_WINDOW_MINUTES,
  claimResume,
  grantEntitlement,
  openResumeWindow,
  peekRemaining,
  reserveSession,
  sessionsOn,
  SESSION_RECORD_TTL_SECONDS,
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

describe('繋ぎ直し（10分の壁）', () => {
  // Vertex は約9分でセッションを切る（実測 code=1000）。
  // そこで会話を終わらせると「10分と言われたのに9分で切られた」ように見える。
  //
  // 繋ぎ直しで枠を引かないと決めると、端末が偽のハンドルを送り続けるだけで
  // 無限に無料になる。**ハンドルはサーバが一度も見ていない**ので
  // （Vertex から端末へ直接届く）中身の検証はできない。
  //
  // だから時間と回数の両方で縛る。**時間だけでは足りない** —
  // 窓の12分のあいだ何本でも同時に張れると、
  // PER_DEVICE_HOURLY = 80 のぶんだけ音声代が膨らむ。

  const authed = () => ({ authorization: `Bearer ${issueToken(device())}` })
  const unit = { unitId: 'force-motion' }

  it('窓は1セッションぶんより長い', () => {
    // Vertex が切るのは約9分。窓が10分ちょうどだと、
    // 切れた瞬間には閉じている可能性がある
    assert.ok(RESUME_WINDOW_MINUTES > MINUTES_PER_SESSION)
  })

  it('枠を引くと窓が開く', async () => {
    const id = device()
    assert.equal(await claimResume(id, NOW), false)
    await openResumeWindow(id, NOW)
    assert.equal(await claimResume(id, NOW + 60_000), true)
  })

  it('窓は時間で閉じる', async () => {
    const id = device()
    await openResumeWindow(id, NOW)
    const after = NOW + (RESUME_WINDOW_MINUTES + 1) * 60_000
    assert.equal(await claimResume(id, after), false,
      '窓が閉じないと1枠で無限に話せる')
  })

  it('窓の中でも回数で閉じる', async () => {
    // **時間だけでは縛りきれない。** 窓の12分のあいだ何本でも
    // 同時に張れてしまうと、1枠のつもりが何十枠ぶんの音声代になる
    // （PER_DEVICE_HOURLY = 80 なので最大80本）
    const id = device()
    await openResumeWindow(id, NOW)
    for (let i = 1; i <= MAX_RESUMES_PER_WINDOW; i++) {
      assert.equal(await claimResume(id, NOW + 1000), true, `${i}回目で止まった`)
    }
    assert.equal(await claimResume(id, NOW + 1000), false,
      '回数の上限を超えても通っている')
  })

  it('端末側の上限より1つだけ多い', () => {
    // 端末は maxResumeAttempts = 2 で諦める。
    // サーバがそれより厳しいと、正しい端末が理由もなく弾かれる
    assert.ok(MAX_RESUMES_PER_WINDOW > 2)
  })

  it('新しい窓では回数も戻る', async () => {
    // 戻さないと、2つ目の窓が1つ目の残数を引き継いで即座に閉じる
    const id = device()
    await openResumeWindow(id, NOW)
    for (let i = 0; i < MAX_RESUMES_PER_WINDOW; i++) await claimResume(id, NOW + 1000)
    assert.equal(await claimResume(id, NOW + 1000), false)

    const later = NOW + 3600_000
    await openResumeWindow(id, later)
    assert.equal(await claimResume(id, later + 1000), true, '回数が戻っていない')
  })

  it('窓の外で叩いても回数を削れない', async () => {
    // 窓の外で数えると、他人の…ではなく自分の次の窓を先に削れてしまう
    const id = device()
    for (let i = 0; i < 10; i++) await claimResume(id, NOW)
    await openResumeWindow(id, NOW)
    assert.equal(await claimResume(id, NOW + 1000), true)
  })

  it('繋ぎ直しは枠を引かない', async () => {
    const h = authed()
    const first = fakeRes()
    await liveToken({ method: 'POST', headers: h, body: unit }, first.res)

    const resume = fakeRes()
    await liveToken(
      { method: 'POST', headers: h, body: { ...unit, resumeHandle: 'h-1' } },
      resume.res,
    )
    assert.equal(resume.out.headers['X-Resumed'], '1')

    const left = fakeRes()
    await liveToken({ method: 'GET', headers: h }, left.res)
    assert.equal(
      (left.out.body as { remainingSessions: number }).remainingSessions,
      FREE_SESSIONS_PER_DAY - 1,
      '繋ぎ直しで枠が減っている',
    )
  })

  it('窓が開いていなければ、ハンドルがあっても普通に引く', async () => {
    // いきなり resumeHandle を送りつけても無料にはならない
    const h = authed()
    const { res, out } = fakeRes()
    await liveToken(
      { method: 'POST', headers: h, body: { ...unit, resumeHandle: 'h-1' } },
      res,
    )
    assert.equal(out.headers['X-Resumed'], '0')

    const left = fakeRes()
    await liveToken({ method: 'GET', headers: h }, left.res)
    assert.equal(
      (left.out.body as { remainingSessions: number }).remainingSessions,
      FREE_SESSIONS_PER_DAY - 1,
    )
  })

  it('繋ぎ直しても窓は延びない', async () => {
    // ここが崩れると、繋ぎ直すたびに窓が開き直って無限になる。
    // 窓の残り時間は最初に枠を引いた時刻だけで決まる
    const id = device()
    await openResumeWindow(id, NOW)
    const nearEnd = NOW + (RESUME_WINDOW_MINUTES - 1) * 60_000
    assert.equal(await claimResume(id, nearEnd), true)
    const afterEnd = NOW + (RESUME_WINDOW_MINUTES + 1) * 60_000
    assert.equal(await claimResume(id, afterEnd), false)
  })

  it('空のハンドルは繋ぎ直しとして扱わない', async () => {
    const h = authed()
    const first = fakeRes()
    await liveToken({ method: 'POST', headers: h, body: unit }, first.res)

    const { res, out } = fakeRes()
    await liveToken(
      { method: 'POST', headers: h, body: { ...unit, resumeHandle: '' } },
      res,
    )
    assert.equal(out.headers['X-Resumed'], '0')
  })

  it('長すぎるハンドルは受け取らない', async () => {
    const h = authed()
    const first = fakeRes()
    await liveToken({ method: 'POST', headers: h, body: unit }, first.res)

    const { res, out } = fakeRes()
    await liveToken(
      { method: 'POST', headers: h, body: { ...unit, resumeHandle: 'x'.repeat(5000) } },
      res,
    )
    assert.equal(out.headers['X-Resumed'], '0')
  })

  it('繋ぎ直しでも単元は確かめる', async () => {
    const h = authed()
    const first = fakeRes()
    await liveToken({ method: 'POST', headers: h, body: unit }, first.res)

    const { res, out } = fakeRes()
    await liveToken(
      { method: 'POST', headers: h, body: { unitId: 'no-such', resumeHandle: 'h' } },
      res,
    )
    assert.equal(out.code, 400)
  })
})

describe('setupConfig の再開', () => {
  it('ハンドルがあれば sessionResumption に載る', () => {
    const cfg = liveSessionConfig(undefined, '[D:x]', 'h-1')
    assert.deepEqual(cfg.sessionResumption, { handle: 'h-1' })
  })

  it('ハンドルが無ければ空のまま（新しい会話）', () => {
    const cfg = liveSessionConfig(undefined, '[D:x]')
    assert.deepEqual(cfg.sessionResumption, {})
  })
})

describe('会話の実績（チームの裏取りに使う）', () => {
  it('配った日は数えられる', async () => {
    const id = device()
    assert.equal(await sessionsOn(id, jstDayKey(NOW)), undefined)
    await reserveSession(id, NOW)
    assert.equal(await sessionsOn(id, jstDayKey(NOW)), 1)
    await reserveSession(id, NOW)
    assert.equal(await sessionsOn(id, jstDayKey(NOW)), 2)
  })

  it('課金済みでも記録する', async () => {
    // 以前は entitled のとき記録の前に return していた。
    // そのままだと、課金した生徒だけチームに貢献できなくなる
    const id = device()
    await grantEntitlement(id, NOW + 30 * 24 * 3600_000)
    const v = await reserveSession(id, NOW)
    assert.equal(v.entitled, true)
    assert.equal(await sessionsOn(id, jstDayKey(NOW)), 1, '課金済みだと記録が残らない')
  })

  it('記録が無いことの意味を、日の古さで分ける', () => {
    // 一律にすると必ずどちらかで間違える:
    // 一律0ならオフラインで溜めた分を捨て、
    // 一律1なら会話せずに毎日1点を稼げる
    assert.equal(clampBySessions(3, undefined, 0, 8), 0, 'きょう会話せずに点が入る')
    assert.equal(clampBySessions(3, undefined, 8, 8), 0)
    assert.equal(clampBySessions(3, undefined, 9, 8), 1, '古い分を捨てている')
  })

  it('その日は会話していないと分かれば 0', () => {
    assert.equal(clampBySessions(3, 0, 0, 8), 0)
  })

  it('会話1回につき最大2点、上限は3点', () => {
    assert.equal(clampBySessions(3, 1, 0, 8), 2)
    assert.equal(clampBySessions(3, 2, 0, 8), 3)
    assert.equal(clampBySessions(3, 99, 0, 8), 3)
    assert.equal(clampBySessions(1, 99, 0, 8), 1, '申告より多くは入らない')
  })

  it('記録の寿命は、さかのぼれる日数に届く長さにする', () => {
    // 2日だと、オフラインで溜めたぶんの裏が取れない
    assert.ok(SESSION_RECORD_TTL_SECONDS >= 7 * 86400)
  })
})
