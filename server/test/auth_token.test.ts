import assert from 'node:assert/strict'
import { beforeEach, describe, it } from 'node:test'

import {
  isValidDeviceId,
  issueToken,
  TOKEN_TTL_SECONDS,
  verifyToken,
} from '../lib/auth.js'
import { checkRate, GLOBAL_DAILY, PER_DEVICE_HOURLY, rateBackend } from '../lib/ratelimit.js'

const DEVICE = '3f2504e0-4f89-11d3-9a0c-0305e82c3301'
const NOW = 1_785_000_000_000

beforeEach(() => {
  process.env.AUTH_SECRET = 'x'.repeat(48)
  delete process.env.KV_REST_API_URL
  delete process.env.KV_REST_API_TOKEN
})

describe('端末トークン', () => {
  it('発行したものを検証できる', () => {
    const got = verifyToken(issueToken(DEVICE, NOW), NOW)
    assert.equal(got.ok, true)
    assert.equal(got.ok && got.token.did, DEVICE)
  })

  it('署名を1文字変えたら通らない', () => {
    const t = issueToken(DEVICE, NOW)
    const broken = t.slice(0, -1) + (t.at(-1) === 'A' ? 'B' : 'A')
    assert.deepEqual(verifyToken(broken, NOW), { ok: false, reason: 'bad_signature' })
  })

  it('中身を書き換えたら通らない', () => {
    // 端末IDを差し替えて他人になりすませない
    const t = issueToken(DEVICE, NOW)
    const [, sig] = t.split('.')
    const evil = Buffer.from(
      JSON.stringify({ did: 'other', iat: 0, exp: 9e9 }),
      'utf8',
    ).toString('base64url')
    assert.deepEqual(verifyToken(`${evil}.${sig}`, NOW), {
      ok: false,
      reason: 'bad_signature',
    })
  })

  it('期限が切れたら通らない', () => {
    const t = issueToken(DEVICE, NOW)
    const after = NOW + (TOKEN_TTL_SECONDS + 1) * 1000
    assert.deepEqual(verifyToken(t, after), { ok: false, reason: 'expired' })
  })

  it('鍵が変われば古いトークンは通らない（失効させられる）', () => {
    const t = issueToken(DEVICE, NOW)
    process.env.AUTH_SECRET = 'y'.repeat(48)
    assert.equal(verifyToken(t, NOW).ok, false)
  })

  it('壊れた入力で落ちない', () => {
    for (const bad of ['', '.', 'abc', 'a.b.c', undefined]) {
      const got = verifyToken(bad as string | undefined, NOW)
      assert.equal(got.ok, false, `通ってしまった: ${bad}`)
    }
  })

  it('署名の無い payload で期限切れを撃ち分けられない', () => {
    // 署名を確かめる前に期限を見ると、内部の状態が漏れる
    const payload = Buffer.from(
      JSON.stringify({ did: DEVICE, iat: 0, exp: 1 }),
      'utf8',
    ).toString('base64url')
    assert.deepEqual(verifyToken(`${payload}.deadbeef`, NOW), {
      ok: false,
      reason: 'bad_signature',
    })
  })

  it('AUTH_SECRET が無ければ発行しない', () => {
    delete process.env.AUTH_SECRET
    assert.throws(() => issueToken(DEVICE, NOW))
  })

  it('短すぎる AUTH_SECRET を拒む', () => {
    process.env.AUTH_SECRET = 'short'
    assert.throws(() => issueToken(DEVICE, NOW))
  })
})

describe('端末IDの形式', () => {
  it('UUID だけ受ける', () => {
    assert.equal(isValidDeviceId(DEVICE), true)
    for (const bad of ['', 'abc', 123, null, DEVICE + 'x', '../../etc']) {
      assert.equal(isValidDeviceId(bad), false, `通ってしまった: ${bad}`)
    }
  })
})

describe('レート制限', () => {
  it('保存先が無いときは memory と申告する', async () => {
    // 「本物の制限がかかっている」と誤解しないための申告
    assert.equal(rateBackend(), 'memory')
    const v = await checkRate('dev-a', NOW)
    assert.equal(v.backend, 'memory')
  })

  it('上限を超えたら止める', async () => {
    const id = `dev-${NOW}-1`
    let last = await checkRate(id, NOW)
    for (let i = 1; i < PER_DEVICE_HOURLY; i++) last = await checkRate(id, NOW)
    assert.equal(last.ok, true, '上限内で止まっている')

    const over = await checkRate(id, NOW)
    assert.equal(over.ok, false)
    assert.ok(over.retryAfterSeconds > 0)
  })

  it('別の端末は互いに影響しない', async () => {
    const a = `dev-${NOW}-a`
    const b = `dev-${NOW}-b`
    for (let i = 0; i <= PER_DEVICE_HOURLY; i++) await checkRate(a, NOW)
    assert.equal((await checkRate(b, NOW)).ok, true)
  })

  it('端末上限後の429連打で全体上限を消費できない', async () => {
    const noisy = `dev-${NOW}-noisy`
    for (let i = 0; i <= GLOBAL_DAILY; i++) {
      await checkRate(noisy, NOW)
    }

    // 端末上限を超えた呼び出しはGeminiへ進まないので、globalへ足さない。
    const other = await checkRate(`dev-${NOW}-still-available`, NOW)
    assert.equal(other.ok, true)
  })

  it('窓が変われば戻る', async () => {
    const id = `dev-${NOW}-w`
    for (let i = 0; i <= PER_DEVICE_HOURLY; i++) await checkRate(id, NOW)
    assert.equal((await checkRate(id, NOW)).ok, false)
    // 1時間後
    assert.equal((await checkRate(id, NOW + 3_600_000)).ok, true)
  })

  it('全体の上限が端末ごとの上限より大きい', () => {
    // 逆だと、1台使っただけで全体が止まる
    assert.ok(GLOBAL_DAILY > PER_DEVICE_HOURLY)
  })
})
