import assert from 'node:assert/strict'
import { beforeEach, describe, it } from 'node:test'

import liveToken from '../api/live-token.js'
import { issueToken } from '../lib/auth.js'
import {
  FREE_MINUTES_PER_DAY,
  MAX_BLOCK_MINUTES,
  MIN_BLOCK_MINUTES,
  grantEntitlement,
  peekRemaining,
  reserveMinutes,
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

describe('無料枠', () => {
  it('初回は最大ブロックを渡す', async () => {
    const v = await reserveMinutes(device(), NOW)
    assert.equal(v.grantedMinutes, MAX_BLOCK_MINUTES)
    assert.equal(v.remainingMinutes, FREE_MINUTES_PER_DAY - MAX_BLOCK_MINUTES)
  })

  it('残りが少なければ残りぶんだけ渡す', async () => {
    const id = device()
    await reserveMinutes(id, NOW) // 10分
    const v = await reserveMinutes(id, NOW)
    assert.equal(v.grantedMinutes, FREE_MINUTES_PER_DAY - MAX_BLOCK_MINUTES) // 5分
    assert.equal(v.remainingMinutes, 0)
  })

  it('使い切ったら渡さない', async () => {
    const id = device()
    await reserveMinutes(id, NOW)
    await reserveMinutes(id, NOW)
    const v = await reserveMinutes(id, NOW)
    assert.equal(v.grantedMinutes, 0)
  })

  it('会話にならない長さは渡さない', async () => {
    // 残り1分でトークンを渡しても、繋いだ瞬間に切れて体験が壊れるだけ
    assert.ok(MIN_BLOCK_MINUTES >= 2)
  })

  it('先に引いてから渡す（渡してから引かない）', async () => {
    // 渡してから引くと、途中で落ちたときに使われたのに引かれていない時間が残る
    const id = device()
    await reserveMinutes(id, NOW)
    const left = await peekRemaining(id, NOW)
    assert.equal(left.remainingMinutes, FREE_MINUTES_PER_DAY - MAX_BLOCK_MINUTES)
  })

  it('日付が変われば戻る', async () => {
    const id = device()
    await reserveMinutes(id, NOW)
    await reserveMinutes(id, NOW)
    assert.equal((await reserveMinutes(id, NOW)).grantedMinutes, 0)

    const tomorrow = NOW + 24 * 3600_000
    assert.equal((await reserveMinutes(id, tomorrow)).grantedMinutes, MAX_BLOCK_MINUTES)
  })

  it('日本時間の0時で切る（UTC で切らない）', async () => {
    // UTC で切ると夜9時に枠が戻って不自然
    const jstEvening = Date.UTC(2026, 7, 5, 12, 0) // JST 21:00
    const jstNextMorning = Date.UTC(2026, 7, 5, 16, 0) // JST 翌 01:00
    const id = device()
    await reserveMinutes(id, jstEvening)
    await reserveMinutes(id, jstEvening)
    assert.equal((await reserveMinutes(id, jstEvening)).grantedMinutes, 0)
    assert.equal(
      (await reserveMinutes(id, jstNextMorning)).grantedMinutes,
      MAX_BLOCK_MINUTES,
      'JST の日付が変わっても戻っていない',
    )
  })

  it('別の端末は互いに影響しない', async () => {
    const a = device()
    await reserveMinutes(a, NOW)
    await reserveMinutes(a, NOW)
    assert.equal((await reserveMinutes(device(), NOW)).grantedMinutes, MAX_BLOCK_MINUTES)
  })

  it('peek は引かない', async () => {
    const id = device()
    await peekRemaining(id, NOW)
    await peekRemaining(id, NOW)
    assert.equal((await reserveMinutes(id, NOW)).grantedMinutes, MAX_BLOCK_MINUTES)
  })
})

describe('課金済み', () => {
  it('上限にかからない', async () => {
    const id = device()
    await grantEntitlement(id, NOW + 30 * 24 * 3600_000)
    for (let i = 0; i < 5; i++) {
      assert.equal((await reserveMinutes(id, NOW)).grantedMinutes, MAX_BLOCK_MINUTES)
    }
    assert.equal((await reserveMinutes(id, NOW)).entitled, true)
  })

  it('期限が切れたら無料枠に戻る', async () => {
    const id = device()
    await grantEntitlement(id, NOW + 1000)
    assert.equal((await reserveMinutes(id, NOW)).entitled, true)
    assert.equal((await reserveMinutes(id, NOW + 2000)).entitled, false)
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
    assert.equal((a.out.body as { remainingMinutes: number }).remainingMinutes,
      FREE_MINUTES_PER_DAY)

    const b = fakeRes()
    await liveToken({ method: 'GET', headers: h }, b.res)
    assert.equal((b.out.body as { remainingMinutes: number }).remainingMinutes,
      FREE_MINUTES_PER_DAY, 'GET が枠を消費している')
  })

  it('使い切ったら 402 を返す', async () => {
    const h = authed()
    // 2回で 15分を使い切る（GEMINI_API_KEY が無いので発行は 502 になるが、枠は引かれる）
    for (let i = 0; i < 2; i++) {
      const { res } = fakeRes()
      await liveToken({ method: 'POST', headers: h }, res)
    }
    const { res, out } = fakeRes()
    await liveToken({ method: 'POST', headers: h }, res)
    assert.equal(out.code, 402)
    assert.deepEqual((out.body as { error: string }).error, 'quota_exhausted')
    assert.ok((out.body as { resetsAt: string }).resetsAt)
  })

  it('DELETE は 405', async () => {
    const { res, out } = fakeRes()
    await liveToken({ method: 'DELETE' }, res)
    assert.equal(out.code, 405)
    assert.equal(out.headers.Allow, 'GET, POST')
  })
})
