import assert from 'node:assert/strict'
import { beforeEach, describe, it } from 'node:test'

import {
  handleRevenueCatWebhook,
  webhookAppUserIds,
} from '../api/revenuecat-webhook.js'
import { handleSubscriptionSync } from '../api/subscription-sync.js'
import { issueToken } from '../lib/auth.js'
import {
  fetchRevenueCatAccess,
  plusAccessFromSubscriber,
  syncRevenueCatEntitlement,
  type RevenueCatAccess,
} from '../lib/revenuecat.js'

const DEVICE = 'a6c5d5c4-9220-4e2e-8cf8-526345e5d678'
const OTHER_DEVICE = '5f69fe4e-6ee7-496c-9412-c9d47c53a71b'
const NOW = Date.UTC(2026, 7, 9, 12)

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

beforeEach(() => {
  process.env.AUTH_SECRET = 'x'.repeat(48)
  delete process.env.NODE_ENV
  delete process.env.VERCEL_ENV
  process.env.DEKISUGI_INTERNAL_RESTRICTED_DATA_TESTING = '1'
  delete process.env.REVENUECAT_API_KEY
  delete process.env.REVENUECAT_ENTITLEMENT_ID
  delete process.env.REVENUECAT_WEBHOOK_AUTH
})

describe('RevenueCat subscriberの現在値', () => {
  it('未来の期限だけを有効として読む', () => {
    const future = new Date(NOW + 3600_000).toISOString()
    assert.deepEqual(
      plusAccessFromSubscriber({
        subscriber: { entitlements: { plus: { expires_date: future } } },
      }, 'plus', NOW),
      { active: true, expiresAtMs: NOW + 3600_000 },
    )
  })

  it('期限切れ・欠落・壊れた日付は無効にする', () => {
    const expired = {
      subscriber: {
        entitlements: { plus: { expires_date: new Date(NOW - 1).toISOString() } },
      },
    }
    assert.deepEqual(plusAccessFromSubscriber(expired, 'plus', NOW), {
      active: false,
      expiresAtMs: null,
    })
    assert.deepEqual(plusAccessFromSubscriber({ subscriber: {} }, 'plus', NOW), {
      active: false,
      expiresAtMs: null,
    })
    assert.deepEqual(plusAccessFromSubscriber({
      subscriber: { entitlements: { plus: {} } },
    }, 'plus', NOW), { active: false, expiresAtMs: null })
    assert.deepEqual(plusAccessFromSubscriber({
      subscriber: { entitlements: { plus: { expires_date: 'not-a-date' } } },
    }, 'plus', NOW), { active: false, expiresAtMs: null })
  })

  it('expires_date=nullはlifetimeとして扱う', () => {
    const access = plusAccessFromSubscriber({
      subscriber: { entitlements: { plus: { expires_date: null } } },
    }, 'plus', NOW)
    assert.equal(access.active, true)
    assert.equal(access.expiresAtMs, Date.UTC(2100, 0, 1))
  })

  it('REST APIへsecret keyとcustom app user IDを送る', async () => {
    let calledUrl = ''
    let calledAuth = ''
    const fetcher: typeof fetch = async (input, init) => {
      calledUrl = String(input)
      calledAuth = new Headers(init?.headers).get('authorization') ?? ''
      return new Response(JSON.stringify({
        subscriber: {
          entitlements: {
            plus: { expires_date: new Date(NOW + 60_000).toISOString() },
          },
        },
      }), { status: 200, headers: { 'content-type': 'application/json' } })
    }

    const access = await fetchRevenueCatAccess(DEVICE, {
      apiKey: 'rc-secret',
      entitlementId: 'plus',
      now: NOW,
      fetcher,
    })
    assert.equal(calledUrl, `https://api.revenuecat.com/v1/subscribers/${DEVICE}`)
    assert.equal(calledAuth, 'Bearer rc-secret')
    assert.equal(access.active, true)
  })

  it('REST APIの失敗とcustom UUIDでないIDを拒否する', async () => {
    const failed: typeof fetch = async () => new Response('', { status: 503 })
    await assert.rejects(
      fetchRevenueCatAccess(DEVICE, { apiKey: 'rc-secret', fetcher: failed }),
      /503/,
    )
    await assert.rejects(
      fetchRevenueCatAccess('$RCAnonymousID:someone', {
        apiKey: 'rc-secret',
        fetcher: failed,
      }),
      /invalid RevenueCat app user id/,
    )
  })

  it('現在有効ならgrant、無効ならrevokeする', async () => {
    const granted: Array<[string, number]> = []
    const revoked: string[] = []
    const active: RevenueCatAccess = { active: true, expiresAtMs: NOW + 1000 }

    await syncRevenueCatEntitlement(DEVICE, {
      fetchAccess: async () => active,
      grant: async (id, expiresAt) => { granted.push([id, expiresAt]) },
      revoke: async (id) => { revoked.push(id) },
    })
    assert.deepEqual(granted, [[DEVICE, NOW + 1000]])
    assert.equal(revoked.length, 0)

    await syncRevenueCatEntitlement(DEVICE, {
      fetchAccess: async () => ({ active: false, expiresAtMs: null }),
      grant: async (id, expiresAt) => { granted.push([id, expiresAt]) },
      revoke: async (id) => { revoked.push(id) },
    })
    assert.deepEqual(revoked, [DEVICE])
  })
})

describe('/api/revenuecat-webhook', () => {
  it('TRANSFER・aliasを含むcustom UUIDを重複なく拾う', () => {
    assert.deepEqual(webhookAppUserIds({
      event: {
        app_user_id: DEVICE,
        original_app_user_id: '$RCAnonymousID:ignore-me',
        aliases: [DEVICE, '$RCAnonymousID:also-ignore'],
        transferred_from: [OTHER_DEVICE],
        transferred_to: [DEVICE],
      },
    }), [DEVICE, OTHER_DEVICE])
  })

  it('未設定・認証不一致・POST以外を閉じる', async () => {
    const noConfig = fakeRes()
    await handleRevenueCatWebhook({ method: 'POST' }, noConfig.res)
    assert.equal(noConfig.out.code, 503)

    const unauthorized = fakeRes()
    await handleRevenueCatWebhook(
      { method: 'POST', headers: { authorization: 'Bearer wrong' } },
      unauthorized.res,
      { expectedAuthorization: 'Bearer expected' },
    )
    assert.equal(unauthorized.out.code, 401)

    const wrongMethod = fakeRes()
    await handleRevenueCatWebhook({ method: 'GET' }, wrongMethod.res)
    assert.equal(wrongMethod.out.code, 405)
    assert.equal(wrongMethod.out.headers.Allow, 'POST')
  })

  it('認証済みイベントの各custom UUIDをREST同期する', async () => {
    const ids: string[] = []
    const response = fakeRes()
    await handleRevenueCatWebhook(
      {
        method: 'POST',
        headers: { authorization: 'Bearer hook-secret' },
        body: JSON.stringify({
          event: { app_user_id: DEVICE, transferred_to: [OTHER_DEVICE] },
        }),
      },
      response.res,
      {
        expectedAuthorization: 'Bearer hook-secret',
        sync: async (id) => {
          ids.push(id)
          return { active: true, expiresAtMs: NOW + 1000 }
        },
      },
    )
    assert.equal(response.out.code, 200)
    assert.deepEqual(response.out.body, { ok: true, synced: 2 })
    assert.deepEqual(ids, [DEVICE, OTHER_DEVICE])
  })

  it('同期失敗は2xxにせずRevenueCatの再送対象にする', async () => {
    const response = fakeRes()
    await handleRevenueCatWebhook(
      {
        method: 'POST',
        headers: { authorization: 'Bearer hook-secret' },
        body: { event: { app_user_id: DEVICE } },
      },
      response.res,
      {
        expectedAuthorization: 'Bearer hook-secret',
        sync: async () => { throw new Error('temporary') },
      },
    )
    assert.equal(response.out.code, 502)
  })

  it('壊れたJSONと大きすぎるbodyを同期前に拒否する', async () => {
    const invalid = fakeRes()
    await handleRevenueCatWebhook(
      {
        method: 'POST',
        headers: { authorization: 'Bearer hook-secret' },
        body: '{broken',
      },
      invalid.res,
      { expectedAuthorization: 'Bearer hook-secret' },
    )
    assert.equal(invalid.out.code, 400)

    const large = fakeRes()
    await handleRevenueCatWebhook(
      {
        method: 'POST',
        headers: { authorization: 'Bearer hook-secret' },
        body: 'x'.repeat(65 * 1024),
      },
      large.res,
      { expectedAuthorization: 'Bearer hook-secret' },
    )
    assert.equal(large.out.code, 413)

    const largeObject = fakeRes()
    await handleRevenueCatWebhook(
      {
        method: 'POST',
        headers: { authorization: 'Bearer hook-secret' },
        body: { event: { padding: 'x'.repeat(65 * 1024) } },
      },
      largeObject.res,
      { expectedAuthorization: 'Bearer hook-secret' },
    )
    assert.equal(largeObject.out.code, 413)
  })
})

describe('/api/subscription-sync', () => {
  it('署名tokenが無ければRevenueCatへ問い合わせない', async () => {
    let called = false
    const response = fakeRes()
    await handleSubscriptionSync(
      { method: 'POST', headers: {} },
      response.res,
      {
        check: async () => ({
          ok: true,
          remaining: 79,
          retryAfterSeconds: 0,
          backend: 'memory',
        }),
        sync: async () => {
          called = true
          return { active: true, expiresAtMs: NOW }
        },
      },
    )
    assert.equal(response.out.code, 401)
    assert.equal(called, false)
  })

  it('購入・復元後はtokenのDIDだけを同期する', async () => {
    const ids: string[] = []
    const response = fakeRes()
    await handleSubscriptionSync(
      {
        method: 'POST',
        headers: { authorization: `Bearer ${issueToken(DEVICE, NOW)}` },
      },
      response.res,
      {
        check: async () => ({
          ok: true,
          remaining: 79,
          retryAfterSeconds: 0,
          backend: 'memory',
        }),
        sync: async (id) => {
          ids.push(id)
          return { active: true, expiresAtMs: NOW + 3600_000 }
        },
      },
    )
    assert.equal(response.out.code, 200)
    assert.deepEqual(ids, [DEVICE])
    assert.deepEqual(response.out.body, {
      entitled: true,
      expiresAt: new Date(NOW + 3600_000).toISOString(),
    })
  })

  it('同期失敗を成功扱いにしない', async () => {
    const response = fakeRes()
    await handleSubscriptionSync(
      {
        method: 'POST',
        headers: { authorization: `Bearer ${issueToken(DEVICE, NOW)}` },
      },
      response.res,
      {
        check: async () => ({
          ok: true,
          remaining: 79,
          retryAfterSeconds: 0,
          backend: 'memory',
        }),
        sync: async () => { throw new Error('temporary') },
      },
    )
    assert.equal(response.out.code, 502)
  })

  it('端末別rateを超えたらRevenueCatへ問い合わせない', async () => {
    let synced = false
    const response = fakeRes()
    await handleSubscriptionSync(
      {
        method: 'POST',
        headers: { authorization: `Bearer ${issueToken(DEVICE, NOW)}` },
      },
      response.res,
      {
        check: async () => ({
          ok: false,
          remaining: 0,
          retryAfterSeconds: 30,
          backend: 'memory',
        }),
        sync: async () => {
          synced = true
          return { active: true, expiresAtMs: NOW + 1000 }
        },
      },
    )
    assert.equal(response.out.code, 429)
    assert.equal(response.out.headers['Retry-After'], '30')
    assert.equal(synced, false)
  })
})
