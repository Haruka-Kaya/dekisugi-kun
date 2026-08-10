import assert from 'node:assert/strict'
import { beforeEach, describe, it } from 'node:test'

import { directorHandler } from '../api/director.js'
import { liveTokenHandler } from '../api/live-token.js'
import { issueToken } from '../lib/auth.js'
import { generativeAiEnabled } from '../lib/generative-ai.js'

const DEVICE = '7440f4ee-67d1-4a58-a17e-445f625bb6b6'

function fakeRes() {
  const out: {
    code?: number
    body?: unknown
    headers: Record<string, string>
  } = {
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

const authed = () => ({ authorization: `Bearer ${issueToken(DEVICE)}` })

beforeEach(() => {
  process.env.AUTH_SECRET = 'x'.repeat(48)
  delete process.env.NODE_ENV
  delete process.env.VERCEL_ENV
  delete process.env.DEKISUGI_INTERNAL_AI_TESTING
  delete process.env.KV_REST_API_URL
  delete process.env.KV_REST_API_TOKEN
})

describe('生成AIの運用スイッチ', () => {
  it('ローカルまたはdevelopmentで内部テストフラグが厳密に1のときだけ開く', () => {
    for (const value of [undefined, '', 'true', '01', '1 ', 'yes']) {
      if (value == null) delete process.env.DEKISUGI_INTERNAL_AI_TESTING
      else process.env.DEKISUGI_INTERNAL_AI_TESTING = value
      assert.equal(generativeAiEnabled(), false, JSON.stringify(value))
    }
    process.env.DEKISUGI_INTERNAL_AI_TESTING = '1'
    assert.equal(generativeAiEnabled(), true)
    process.env.VERCEL_ENV = 'development'
    assert.equal(generativeAiEnabled(), true)
  })

  it('productionとpreviewは内部フラグがあっても解除できない', () => {
    process.env.DEKISUGI_INTERNAL_AI_TESTING = '1'
    for (const environment of ['production', 'preview', 'staging']) {
      process.env.VERCEL_ENV = environment
      assert.equal(generativeAiEnabled(), false, environment)
    }
  })

  it('Vercel外でもNODE_ENV=productionなら内部フラグで解除できない', () => {
    delete process.env.VERCEL_ENV
    process.env.NODE_ENV = 'production'
    process.env.DEKISUGI_INTERNAL_AI_TESTING = '1'
    assert.equal(generativeAiEnabled(), false)

    process.env.VERCEL_ENV = 'development'
    assert.equal(generativeAiEnabled(), false)
  })

  it('停止中も認証を先に行う', async () => {
    for (const handler of [liveTokenHandler(), directorHandler()]) {
      const { res, out } = fakeRes()
      await handler({ method: 'POST', headers: {} }, res)
      assert.equal(out.code, 401)
      assert.deepEqual(out.body, { error: 'unauthorized' })
    }
  })

  it('停止中はGET/POSTともrate・quota・Google処理へ一度も進まない', async () => {
    const calls = { rate: 0, quota: 0, google: 0 }
    const rate = async () => {
      calls.rate++
      throw new Error('rateへ進んだ')
    }
    const quota = async () => {
      calls.quota++
      throw new Error('quotaへ進んだ')
    }
    const google = async () => {
      calls.google++
      throw new Error('Googleへ進んだ')
    }
    const live = liveTokenHandler({
      checkRate: rate,
      claimResume: quota,
      createLiveGrant: google,
      openResumeWindow: quota,
      peekRemaining: quota,
      reserveSession: quota,
    })
    const director = directorHandler({ checkRate: rate, runDirector: google })
    const requests = [
      [live, { method: 'GET', headers: authed() }],
      [
        live,
        { method: 'POST', headers: authed(), body: { unitId: 'force-motion' } },
      ],
      [
        director,
        { method: 'POST', headers: authed(), body: { unitId: 'force-motion' } },
      ],
    ] as const

    for (const [handler, req] of requests) {
      const { res, out } = fakeRes()
      await handler(req, res)
      assert.equal(out.code, 503)
      assert.deepEqual(out.body, { error: 'generative_ai_unavailable' })
    }
    assert.deepEqual(calls, { rate: 0, quota: 0, google: 0 })
  })

  it('内部テスト条件ならlive-token GET/POSTの既存処理へ進む', async () => {
    process.env.DEKISUGI_INTERNAL_AI_TESTING = '1'
    const live = liveTokenHandler({
      checkRate: async () => ({
        ok: true,
        remaining: 79,
        retryAfterSeconds: 60,
        backend: 'memory',
      }),
      peekRemaining: async () => ({
        remainingSessions: 2,
        entitled: false,
        resetsAt: '2026-08-10T15:00:00.000Z',
      }),
      reserveSession: async () => ({
        granted: true,
        remainingSessions: 1,
        entitled: false,
        resetsAt: '2026-08-10T15:00:00.000Z',
        backend: 'memory',
      }),
      openResumeWindow: async () => undefined,
      createLiveGrant: async () => ({
        directorPrefix: '[D:test]',
        token: 'access-token',
        wsUrl: 'wss://example.test/live',
        model: 'projects/test/models/test',
        setupConfig: {},
        expiresAt: '2026-08-10T01:00:00.000Z',
        sessionMinutes: 10,
        resumed: false,
      }),
    })

    const get = fakeRes()
    await live({ method: 'GET', headers: authed() }, get.res)
    assert.equal(get.out.code, 200)
    assert.equal(
      (get.out.body as { remainingSessions: number }).remainingSessions,
      2,
    )

    const post = fakeRes()
    await live(
      { method: 'POST', headers: authed(), body: { unitId: 'force-motion' } },
      post.res,
    )
    assert.equal(post.out.code, 200)
    assert.equal((post.out.body as { token: string }).token, 'access-token')
  })

  it('内部テスト条件ならdirectorの既存処理へ進む', async () => {
    process.env.DEKISUGI_INTERNAL_AI_TESTING = '1'
    let rateCalls = 0
    let providerCalls = 0
    const handler = directorHandler({
      checkRate: async () => {
        rateCalls++
        return {
          ok: true,
          remaining: 79,
          retryAfterSeconds: 60,
          backend: 'memory',
        }
      },
      runDirector: async (input) => {
        providerCalls++
        return {
          corrections: [],
          dossier: input.dossier,
          nextInstruction: '続けてください',
          lureId: null,
          lureText: null,
          shouldEnd: false,
          endReason: '',
        }
      },
    })
    const { res, out } = fakeRes()
    await handler(
      { method: 'POST', headers: authed(), body: { unitId: 'force-motion' } },
      res,
    )
    assert.equal(out.code, 200)
    assert.equal(rateCalls, 1)
    assert.equal(providerCalls, 1)
  })

  it('productionでは内部フラグ付きの実endpointも503', async () => {
    process.env.VERCEL_ENV = 'production'
    process.env.DEKISUGI_INTERNAL_AI_TESTING = '1'
    for (const [handler, req] of [
      [liveTokenHandler(), { method: 'GET', headers: authed() }],
      [
        directorHandler(),
        { method: 'POST', headers: authed(), body: { unitId: 'force-motion' } },
      ],
    ] as const) {
      const { res, out } = fakeRes()
      await handler(req, res)
      assert.equal(out.code, 503)
      assert.deepEqual(out.body, { error: 'generative_ai_unavailable' })
    }
  })
})
