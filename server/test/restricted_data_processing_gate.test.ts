import assert from 'node:assert/strict'
import { beforeEach, describe, it } from 'node:test'

import { handleRevenueCatWebhook } from '../api/revenuecat-webhook.js'
import { handleSubscriptionSync } from '../api/subscription-sync.js'
import { handleSurvey } from '../api/survey.js'
import { issueToken } from '../lib/auth.js'
import { restrictedDataProcessingEnabled } from '../lib/restricted-data-processing.js'
import type { Req } from '../lib/http.js'

const DEVICE = '84d70bba-b28b-40ca-9d91-3ed0908f66df'

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
  delete process.env.KV_REST_API_URL
  delete process.env.KV_REST_API_TOKEN
  delete process.env.SURVEY_ADMIN_TOKEN
  delete process.env.REVENUECAT_WEBHOOK_AUTH
})

describe('制限対象データ処理の運用スイッチ', () => {
  it('ローカルまたはVercel developmentで専用フラグが厳密に1のときだけ開く', () => {
    for (const value of [undefined, '', 'true', '01', '1 ', 'yes']) {
      if (value == null) delete process.env.DEKISUGI_INTERNAL_RESTRICTED_DATA_TESTING
      else process.env.DEKISUGI_INTERNAL_RESTRICTED_DATA_TESTING = value
      assert.equal(restrictedDataProcessingEnabled(), false, JSON.stringify(value))
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
      assert.equal(restrictedDataProcessingEnabled(), false, JSON.stringify(environment))
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

  it('survey POSTはbody・IP・rate・KVより前に止まり、GET/DELETEは維持する', async () => {
    const calls = { body: 0, ip: 0, rate: 0, save: 0 }
    const request: Req = { method: 'POST' }
    Object.defineProperty(request, 'body', {
      get() {
        calls.body++
        throw new Error('bodyを読んだ')
      },
    })
    const stopped = fakeRes()
    await handleSurvey(request, stopped.res, {
      callerIpOf: () => {
        calls.ip++
        return '192.0.2.1'
      },
      tooMany: async () => {
        calls.rate++
        return false
      },
      save: async () => {
        calls.save++
        return { ok: true, count: 1 }
      },
    })
    assert.equal(stopped.out.code, 503)
    assert.deepEqual(stopped.out.body, {
      error: 'restricted_data_processing_unavailable',
    })
    assert.deepEqual(calls, { body: 0, ip: 0, rate: 0, save: 0 })

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
    const calls = { rate: 0, sync: 0, ip: 0, surveyRate: 0, save: 0 }
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
      await handleSurvey(
        { method: 'POST', body: { kind: 'misconception' } },
        survey.res,
        {
          callerIpOf: () => {
            calls.ip++
            return '192.0.2.1'
          },
          tooMany: async () => {
            calls.surveyRate++
            return false
          },
          save: async () => {
            calls.save++
            return { ok: true, count: 1 }
          },
        },
      )
      assert.equal(survey.out.code, 503, environment)
    }

    assert.deepEqual(calls, { rate: 0, sync: 0, ip: 0, surveyRate: 0, save: 0 })
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
  it('Vercel developmentと専用フラグの組み合わせだけsurvey POSTを開く', async () => {
    process.env.VERCEL_ENV = 'development'
    process.env.DEKISUGI_INTERNAL_RESTRICTED_DATA_TESTING = '1'
    const calls = { ip: 0, rate: 0, save: 0 }
    const response = fakeRes()
    await handleSurvey(
      { method: 'POST', body: { kind: 'misconception' } },
      response.res,
      {
        callerIpOf: () => {
          calls.ip++
          return '192.0.2.1'
        },
        tooMany: async () => {
          calls.rate++
          return false
        },
        save: async () => {
          calls.save++
          return { ok: true, count: 1 }
        },
      },
    )
    assert.equal(response.out.code, 200)
    assert.deepEqual(response.out.body, { ok: true, count: 1 })
    assert.deepEqual(calls, { ip: 1, rate: 1, save: 1 })
  })
})
