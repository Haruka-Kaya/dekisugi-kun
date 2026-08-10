import assert from 'node:assert/strict'
import { beforeEach, describe, it } from 'node:test'

import { handleRevenueCatWebhook } from '../api/revenuecat-webhook.js'
import { handleSubscriptionSync } from '../api/subscription-sync.js'
import { handleSurvey } from '../api/survey.js'
import { issueToken } from '../lib/auth.js'
import { restrictedDataProcessingEnabled } from '../lib/restricted-data-processing.js'
import type { Req } from '../lib/http.js'

const DEVICE = '84d70bba-b28b-40ca-9d91-3ed0908f66df'
const SURVEY_BODY = {
  v: 3,
  kind: 'misconception',
  sessionId: '2bb832aa-6ca7-46e4-90fd-5af4d04144d8',
  done: false,
  meta: { grade: '中学3年', like: '好き' },
  ans: [
    {
      id: 'M01',
      topic: '落下',
      explain: '重さだけでは落ちる速さは変わらないと思います',
      explainMs: 1200,
      lureReply: '空気抵抗がなければ同時です',
      lureMs: 800,
      pick: 2,
      pickPos: 1,
      pick2: 2,
      pickPos2: 0,
      learned: '習った',
      mcMs: 900,
      correct: true,
      heldMisconception: false,
      groundTruth: 'understood',
      correct1: true,
      heldMisconception1: false,
    },
  ],
} as const

function fakeRes() {
  const out: {
    code?: number
    body?: unknown
    headers: Record<string, string>
  } = { headers: {} }
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
  delete process.env.DEKISUGI_INTERNAL_RESTRICTED_DATA_TESTING
  delete process.env.DEKISUGI_ANONYMOUS_SURVEY_ENABLED
  delete process.env.KV_REST_API_URL
  delete process.env.KV_REST_API_TOKEN
  delete process.env.SURVEY_ADMIN_TOKEN
  delete process.env.REVENUECAT_WEBHOOK_AUTH
})

describe('制限対象データ処理の運用スイッチ', () => {
  it('ローカルまたはVercel developmentで専用フラグが厳密に1のときだけ開く', () => {
    for (const value of [undefined, '', 'true', '01', '1 ', 'yes']) {
      if (value == null)
        delete process.env.DEKISUGI_INTERNAL_RESTRICTED_DATA_TESTING
      else process.env.DEKISUGI_INTERNAL_RESTRICTED_DATA_TESTING = value
      assert.equal(
        restrictedDataProcessingEnabled(),
        false,
        JSON.stringify(value),
      )
    }

    process.env.DEKISUGI_INTERNAL_RESTRICTED_DATA_TESTING = '1'
    assert.equal(restrictedDataProcessingEnabled(), true)
    process.env.VERCEL_ENV = 'development'
    assert.equal(restrictedDataProcessingEnabled(), true)
  })

  it('production・preview・未知の明示環境はフラグがあっても開かない', () => {
    process.env.DEKISUGI_INTERNAL_RESTRICTED_DATA_TESTING = '1'
    for (const environment of ['production', 'preview', 'staging', '']) {
      process.env.VERCEL_ENV = environment
      assert.equal(
        restrictedDataProcessingEnabled(),
        false,
        JSON.stringify(environment),
      )
    }
  })

  it('Vercel外とVercel developmentのどちらもNODE_ENV=productionなら開かない', () => {
    process.env.NODE_ENV = 'production'
    process.env.DEKISUGI_INTERNAL_RESTRICTED_DATA_TESTING = '1'
    assert.equal(restrictedDataProcessingEnabled(), false)

    process.env.VERCEL_ENV = 'development'
    assert.equal(restrictedDataProcessingEnabled(), false)
  })
})

describe('停止中のAPI境界', () => {
  it('subscription-syncは認証後、rate・RevenueCatより前に止まる', async () => {
    const calls = { rate: 0, sync: 0 }
    const dependencies = {
      check: async () => {
        calls.rate++
        throw new Error('rateへ進んだ')
      },
      sync: async () => {
        calls.sync++
        throw new Error('RevenueCatへ進んだ')
      },
    }

    const unauthorized = fakeRes()
    await handleSubscriptionSync(
      { method: 'POST', headers: {} },
      unauthorized.res,
      dependencies,
    )
    assert.equal(unauthorized.out.code, 401)

    const stopped = fakeRes()
    await handleSubscriptionSync(
      { method: 'POST', headers: authed() },
      stopped.res,
      dependencies,
    )
    assert.equal(stopped.out.code, 503)
    assert.deepEqual(stopped.out.body, {
      error: 'restricted_data_processing_unavailable',
    })
    assert.deepEqual(calls, { rate: 0, sync: 0 })
  })

  it('webhookは設定・認証後、body読取・RevenueCat同期より前に止まる', async () => {
    const noConfig = fakeRes()
    await handleRevenueCatWebhook({ method: 'POST' }, noConfig.res)
    assert.deepEqual(noConfig.out.body, { error: 'revenuecat_not_configured' })

    const unauthorized = fakeRes()
    await handleRevenueCatWebhook(
      { method: 'POST', headers: { authorization: 'Bearer wrong' } },
      unauthorized.res,
      { expectedAuthorization: 'Bearer expected' },
    )
    assert.equal(unauthorized.out.code, 401)

    let bodyReads = 0
    let syncCalls = 0
    const request: Req = {
      method: 'POST',
      headers: { authorization: 'Bearer expected' },
    }
    Object.defineProperty(request, 'body', {
      get() {
        bodyReads++
        throw new Error('bodyを読んだ')
      },
    })
    const stopped = fakeRes()
    await handleRevenueCatWebhook(request, stopped.res, {
      expectedAuthorization: 'Bearer expected',
      sync: async () => {
        syncCalls++
        throw new Error('RevenueCatへ進んだ')
      },
    })
    assert.equal(stopped.out.code, 503)
    assert.deepEqual(stopped.out.body, {
      error: 'restricted_data_processing_unavailable',
    })
    assert.equal(bodyReads, 0)
    assert.equal(syncCalls, 0)
  })

  it('survey POSTはbody・rate・KVより前に止まり、GET/DELETEは維持する', async () => {
    const calls = { body: 0, rate: 0, save: 0 }
    const request: Req = { method: 'POST' }
    Object.defineProperty(request, 'body', {
      get() {
        calls.body++
        throw new Error('bodyを読んだ')
      },
    })
    const stopped = fakeRes()
    await handleSurvey(request, stopped.res, {
      tooMany: async () => {
        calls.rate++
        return false
      },
      save: async () => {
        calls.save++
        return { ok: true, receipt: 'sr_not_reached' }
      },
    })
    assert.equal(stopped.out.code, 503)
    assert.deepEqual(stopped.out.body, {
      error: 'anonymous_survey_unavailable',
    })
    assert.deepEqual(calls, { body: 0, rate: 0, save: 0 })

    process.env.SURVEY_ADMIN_TOKEN = 'admin'
    const get = fakeRes()
    await handleSurvey(
      {
        method: 'GET',
        query: { kind: 'misconception' },
        headers: { authorization: 'Bearer admin' },
      },
      get.res,
    )
    assert.equal(get.out.code, 200)

    const remove = fakeRes()
    await handleSurvey(
      {
        method: 'DELETE',
        query: { kind: 'misconception', expect: '0' },
        headers: { authorization: 'Bearer admin' },
      },
      remove.res,
    )
    assert.equal(remove.out.code, 200)
  })

  it('production/previewではフラグを付けても全入口が依存処理へ進まない', async () => {
    const calls = { rate: 0, sync: 0, surveyRate: 0, save: 0 }
    process.env.DEKISUGI_INTERNAL_RESTRICTED_DATA_TESTING = '1'

    for (const environment of ['production', 'preview']) {
      process.env.VERCEL_ENV = environment

      const subscription = fakeRes()
      await handleSubscriptionSync(
        { method: 'POST', headers: authed() },
        subscription.res,
        {
          check: async () => {
            calls.rate++
            throw new Error('rateへ進んだ')
          },
          sync: async () => {
            calls.sync++
            throw new Error('RevenueCatへ進んだ')
          },
        },
      )
      assert.equal(subscription.out.code, 503, environment)

      const webhook = fakeRes()
      await handleRevenueCatWebhook(
        {
          method: 'POST',
          headers: { authorization: 'Bearer expected' },
          body: { event: { app_user_id: DEVICE } },
        },
        webhook.res,
        {
          expectedAuthorization: 'Bearer expected',
          sync: async () => {
            calls.sync++
            throw new Error('RevenueCatへ進んだ')
          },
        },
      )
      assert.equal(webhook.out.code, 503, environment)

      const survey = fakeRes()
      await handleSurvey({ method: 'POST', body: SURVEY_BODY }, survey.res, {
        tooMany: async () => {
          calls.surveyRate++
          return false
        },
        save: async () => {
          calls.save++
          return { ok: true, receipt: 'sr_not_reached' }
        },
      })
      assert.equal(survey.out.code, 503, environment)
    }

    assert.deepEqual(calls, { rate: 0, sync: 0, surveyRate: 0, save: 0 })
  })

  it('productionの匿名survey専用flagは厳密な1だけを受け、他の外部処理を開かない', async () => {
    process.env.NODE_ENV = 'production'
    process.env.VERCEL_ENV = 'production'

    for (const value of [undefined, '', 'true', '01', '1 ', 'yes']) {
      if (value === undefined)
        delete process.env.DEKISUGI_ANONYMOUS_SURVEY_ENABLED
      else process.env.DEKISUGI_ANONYMOUS_SURVEY_ENABLED = value
      let calls = 0
      const response = fakeRes()
      await handleSurvey({ method: 'POST', body: SURVEY_BODY }, response.res, {
        tooMany: async () => {
          calls++
          return false
        },
        save: async () => {
          calls++
          return { ok: true, receipt: 'sr_not_reached' }
        },
      })
      assert.equal(response.out.code, 503, JSON.stringify(value))
      assert.equal(calls, 0, JSON.stringify(value))
    }

    process.env.DEKISUGI_ANONYMOUS_SURVEY_ENABLED = '1'
    const surveyCalls = { rate: 0, save: 0 }
    const survey = fakeRes()
    await handleSurvey({ method: 'POST', body: SURVEY_BODY }, survey.res, {
      tooMany: async (sessionId: string) => {
        surveyCalls.rate++
        assert.equal(sessionId, SURVEY_BODY.sessionId)
        return false
      },
      save: async () => {
        surveyCalls.save++
        return { ok: true, receipt: 'sr_mCcH2eFdVgcj7u2mWveurh4e' }
      },
    })
    assert.equal(survey.out.code, 200)
    assert.deepEqual(survey.out.body, {
      ok: true,
      receipt: 'sr_mCcH2eFdVgcj7u2mWveurh4e',
    })
    assert.deepEqual(surveyCalls, { rate: 1, save: 1 })
    assert.equal(restrictedDataProcessingEnabled(), false)

    const otherCalls = { rate: 0, sync: 0 }
    const subscription = fakeRes()
    await handleSubscriptionSync(
      { method: 'POST', headers: authed() },
      subscription.res,
      {
        check: async () => {
          otherCalls.rate++
          throw new Error('rateへ進んだ')
        },
        sync: async () => {
          otherCalls.sync++
          throw new Error('RevenueCatへ進んだ')
        },
      },
    )
    assert.equal(subscription.out.code, 503)

    const webhook = fakeRes()
    await handleRevenueCatWebhook(
      {
        method: 'POST',
        headers: { authorization: 'Bearer expected' },
        body: { event: { app_user_id: DEVICE } },
      },
      webhook.res,
      {
        expectedAuthorization: 'Bearer expected',
        sync: async () => {
          otherCalls.sync++
          throw new Error('RevenueCatへ進んだ')
        },
      },
    )
    assert.equal(webhook.out.code, 503)
    assert.deepEqual(otherCalls, { rate: 0, sync: 0 })
  })

  it('previewも匿名survey専用flagが1のときだけ開く', async () => {
    process.env.VERCEL_ENV = 'preview'
    process.env.DEKISUGI_ANONYMOUS_SURVEY_ENABLED = '1'
    const calls = { rate: 0, save: 0 }
    const response = fakeRes()
    await handleSurvey({ method: 'POST', body: SURVEY_BODY }, response.res, {
      tooMany: async () => {
        calls.rate++
        return false
      },
      save: async () => {
        calls.save++
        return { ok: true, receipt: 'sr_yKbeFy3Wj7nTBt6aYppH4mSK' }
      },
    })
    assert.equal(response.out.code, 200)
    assert.deepEqual(response.out.body, {
      ok: true,
      receipt: 'sr_yKbeFy3Wj7nTBt6aYppH4mSK',
    })
    assert.deepEqual(calls, { rate: 1, save: 1 })
  })

  it('Vercel developmentでもNODE_ENV=productionなら実endpointは503', async () => {
    process.env.NODE_ENV = 'production'
    process.env.VERCEL_ENV = 'development'
    process.env.DEKISUGI_INTERNAL_RESTRICTED_DATA_TESTING = '1'
    let calls = 0
    const response = fakeRes()
    await handleSubscriptionSync(
      { method: 'POST', headers: authed() },
      response.res,
      {
        check: async () => {
          calls++
          throw new Error('rateへ進んだ')
        },
        sync: async () => {
          calls++
          throw new Error('RevenueCatへ進んだ')
        },
      },
    )
    assert.equal(response.out.code, 503)
    assert.equal(calls, 0)
  })
})

describe('許可された内部テスト', () => {
  it('旧internal flag単独ではsurveyを開かず、匿名専用flagでだけ開く', async () => {
    process.env.VERCEL_ENV = 'development'
    process.env.DEKISUGI_INTERNAL_RESTRICTED_DATA_TESTING = '1'
    const calls = { rate: 0, save: 0 }

    const stopped = fakeRes()
    await handleSurvey({ method: 'POST', body: SURVEY_BODY }, stopped.res, {
      tooMany: async () => {
        calls.rate++
        return false
      },
      save: async () => {
        calls.save++
        return { ok: true, receipt: 'sr_not_reached' }
      },
    })
    assert.equal(stopped.out.code, 503)
    assert.deepEqual(calls, { rate: 0, save: 0 })

    process.env.DEKISUGI_ANONYMOUS_SURVEY_ENABLED = '1'
    const response = fakeRes()
    await handleSurvey({ method: 'POST', body: SURVEY_BODY }, response.res, {
      tooMany: async () => {
        calls.rate++
        return false
      },
      save: async () => {
        calls.save++
        return { ok: true, receipt: 'sr_7sMeBUX58Ep4heMpdd9Q7Wmw' }
      },
    })
    assert.equal(response.out.code, 200)
    assert.deepEqual(response.out.body, {
      ok: true,
      receipt: 'sr_7sMeBUX58Ep4heMpdd9Q7Wmw',
    })
    assert.deepEqual(calls, { rate: 1, save: 1 })
  })
})
