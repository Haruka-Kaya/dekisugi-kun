import assert from 'node:assert/strict'
import { beforeEach, describe, it } from 'node:test'

import director from '../api/director.js'
import register from '../api/register.js'
import { issueToken } from '../lib/auth.js'
import { PER_DEVICE_HOURLY } from '../lib/ratelimit.js'

const DEVICE = '3f2504e0-4f89-11d3-9a0c-0305e82c3301'

/** ハンドラの応答を捕まえる最小のレス */
function fakeRes() {
  const out: { code?: number; body?: unknown; headers: Record<string, string> } = {
    headers: {},
  }
  const res = {
    status(code: number) {
      out.code = code
      return res
    },
    json(body: unknown) {
      out.body = body
    },
    setHeader(name: string, value: string) {
      out.headers[name] = value
    },
  }
  return { res, out }
}

function authed(device = DEVICE): Record<string, string> {
  return { authorization: `Bearer ${issueToken(device)}` }
}

beforeEach(() => {
  process.env.AUTH_SECRET = 'x'.repeat(48)
  delete process.env.VERCEL_ENV
  process.env.DEKISUGI_INTERNAL_AI_TESTING = '1'
  delete process.env.KV_REST_API_URL
})

describe('/api/register', () => {
  it('端末IDを渡すとトークンを返す', async () => {
    const { res, out } = fakeRes()
    await register({ method: 'POST', body: { deviceId: DEVICE } }, res)
    assert.equal(out.code, 200)
    const body = out.body as { token: string; expiresIn: number }
    assert.ok(body.token.includes('.'))
    assert.ok(body.expiresIn > 0)
  })

  it('端末IDの形式が違えば弾く', async () => {
    const { res, out } = fakeRes()
    await register({ method: 'POST', body: { deviceId: 'not-a-uuid' } }, res)
    assert.deepEqual(out.body, { error: 'invalid_device_id' })
  })

  it('AUTH_SECRET が無ければ 503（発行しない）', async () => {
    delete process.env.AUTH_SECRET
    const { res, out } = fakeRes()
    await register({ method: 'POST', body: { deviceId: DEVICE } }, res)
    assert.equal(out.code, 503)
  })

  it('GET は 405', async () => {
    const { res, out } = fakeRes()
    await register({ method: 'GET' }, res)
    assert.equal(out.code, 405)
  })
})

describe('/api/director の門', () => {
  it('トークンが無ければ 401', async () => {
    const { res, out } = fakeRes()
    await director({ method: 'POST', body: {}, headers: {} }, res)
    assert.equal(out.code, 401)
    assert.deepEqual(out.body, { error: 'unauthorized' })
  })

  it('期限切れは区別して返す（端末が登録し直せる）', async () => {
    const old = issueToken(DEVICE, Date.now() - 400 * 24 * 3600 * 1000)
    const { res, out } = fakeRes()
    await director(
      { method: 'POST', body: {}, headers: { authorization: `Bearer ${old}` } },
      res,
    )
    assert.equal(out.code, 401)
    assert.deepEqual(out.body, { error: 'token_expired' })
  })

  it('偽の署名は 401', async () => {
    const { res, out } = fakeRes()
    await director(
      { method: 'POST', body: {}, headers: { authorization: 'Bearer aaa.bbb' } },
      res,
    )
    assert.equal(out.code, 401)
  })

  it('通れば入力の検証まで進む', async () => {
    const { res, out } = fakeRes()
    await director({ method: 'POST', body: {}, headers: authed() }, res)
    assert.equal(out.code, 400)
    assert.deepEqual(out.body, { error: 'unit_required' })
  })

  it('保存先が本物かを応答ヘッダで申告する', async () => {
    // 「本物の制限がかかっている」と誤解しないため、外から見えるようにしてある
    const { res, out } = fakeRes()
    await director({ method: 'POST', body: {}, headers: authed() }, res)
    assert.equal(out.headers['X-RateLimit-Backend'], 'memory')
  })

  it('GET は 405 で Allow を返す', async () => {
    const { res, out } = fakeRes()
    await director({ method: 'GET' }, res)
    assert.equal(out.code, 405)
    assert.equal(out.headers.Allow, 'POST')
  })
})

describe('入力の検証（門を通ったあと）', () => {
  it('壊れた JSON 文字列を 400 で返す', async () => {
    const { res, out } = fakeRes()
    await director({ method: 'POST', body: '{ぐちゃぐちゃ', headers: authed() }, res)
    assert.deepEqual(out.body, { error: 'invalid_json' })
  })

  it('大きすぎる body を 413 で返す（LLM を呼ぶ前に落とす）', async () => {
    const { res, out } = fakeRes()
    await director(
      { method: 'POST', body: 'x'.repeat(300 * 1024), headers: authed() },
      res,
    )
    assert.equal(out.code, 413)
  })

  it('Vercelがparse済みの大きなobjectも413で返す', async () => {
    const { res, out } = fakeRes()
    await director(
      {
        method: 'POST',
        body: {
          unitId: 'force-motion',
          utterances: [{ id: 'u01', speaker: 'student', text: 'あ'.repeat(100 * 1024) }],
        },
        headers: authed(),
      },
      res,
    )
    assert.equal(out.code, 413)
    assert.deepEqual(out.body, { error: 'too_large' })
  })

  it('不正なmissionKindはDirectorでもrateを使う前に400', async () => {
    const missionDevice = 'a6c5d5c4-9220-4e2e-8cf8-526345e5d678'
    const headers = authed(missionDevice)

    // parseInputがrateより後ろに移ると、途中から429になる。
    for (let i = 0; i <= PER_DEVICE_HOURLY; i++) {
      const { res, out } = fakeRes()
      await director(
        {
          method: 'POST',
          headers,
          body: {
            unitId: 'force-motion',
            focusConceptKey: 'fall',
            missionKind: i % 2 === 0 ? 'case' : null,
          },
        },
        res,
      )
      assert.equal(out.code, 400, `${i + 1}回目でrateを消費した`)
      assert.deepEqual(out.body, { error: 'unknown_mission_kind' })
    }
  })

  it('不正なteachingTacticはDirectorでもrateを使う前に400', async () => {
    const tacticDevice = 'a6c5d5c4-9220-4e2e-8cf8-526345e5d679'
    const headers = authed(tacticDevice)

    for (let i = 0; i <= PER_DEVICE_HOURLY; i++) {
      const { res, out } = fakeRes()
      await director(
        {
          method: 'POST',
          headers,
          body: {
            unitId: 'force-motion',
            focusConceptKey: 'fall',
            teachingTactic: i % 2 === 0 ? 'examples' : null,
          },
        },
        res,
      )
      assert.equal(out.code, 400, `${i + 1}回目でrateを消費した`)
      assert.deepEqual(out.body, { error: 'unknown_teaching_tactic' })
    }
  })
})
