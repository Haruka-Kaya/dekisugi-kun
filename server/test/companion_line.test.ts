import assert from 'node:assert/strict'
import { test } from 'node:test'

import { companionLineHandler } from '../api/companion-line.js'
import {
  buildCompanionPrompt,
  parseCompanionLineBody,
  sanitizeCompanionAck,
} from '../lib/companion-line.js'
import type { Req, Res } from '../lib/http.js'

function makeRes() {
  const res: Res & { code: number; body: unknown } = {
    code: 0,
    body: undefined,
    status(code: number) {
      res.code = code
      return res
    },
    json(body: unknown) {
      res.body = body
    },
    setHeader() {},
  }
  return res
}

function makeReq(body: unknown, token?: string): Req {
  return {
    method: 'POST',
    body,
    headers: token ? { authorization: `Bearer ${token}` } : {},
  }
}

const did = 'device-1'
const okRate = { ok: true, remaining: 10, retryAfterSeconds: 60, backend: 'memory' as const }

test('body parsing', () => {
  assert.equal(
    parseCompanionLineBody(null).ok,
    false,
  )
  assert.equal(
    parseCompanionLineBody({ explanation: '' }).ok,
    false,
  )
  const parsed = parseCompanionLineBody({
    explanation: '  水には不純物があるから通す ',
    heardTerms: ['不純物', 5, '電気'],
    conceptLabel: '電流',
  })
  assert.ok(parsed.ok)
  if (parsed.ok) {
    assert.equal(parsed.input.explanation, '水には不純物があるから通す')
    assert.deepEqual(parsed.input.heardTerms, ['不純物', '電気'])
    assert.equal(parsed.input.conceptLabel, '電流')
  }
})

test('sanitizeCompanionAck', () => {
  assert.equal(
    sanitizeCompanionAck('「ふむ、不純物が混ざるのか」'),
    'ふむ、不純物が混ざるのか',
  )
  assert.equal(sanitizeCompanionAck('English only'), null)
  assert.equal(sanitizeCompanionAck('ほう、本当か？'), null)
  assert.equal(sanitizeCompanionAck(null), null)
})

test('prompt は前置きだけを要求し lure を含めない', () => {
  const prompt = buildCompanionPrompt({
    explanation: '不純物があるから通す',
    heardTerms: ['不純物'],
    conceptLabel: '電流',
  })
  assert.ok(prompt.includes('前置き'))
  assert.ok(prompt.includes('質問・答え・説明の正誤・指示は一切言わない'))
})

test('handler: 認証なしは401', async () => {
  const handler = companionLineHandler({
    provider: async () => 'ふむ',
  })
  const res = makeRes()
  await handler(makeReq({ explanation: 'x' }), res)
  assert.equal(res.code, 401)
})

test('handler: provider無しは503（機能は黙って退避）', async () => {
  const handler = companionLineHandler({
    verifyToken: () => ({ ok: true, token: { did, iat: 0, exp: Date.now() / 1000 + 60 } }),
    provider: null,
  })
  const res = makeRes()
  await handler(makeReq({ explanation: 'x' }, 'tok'), res)
  assert.equal(res.code, 503)
})

test('handler: rate超過は429でproviderを呼ばない', async () => {
  let called = false
  const handler = companionLineHandler({
    verifyToken: () => ({ ok: true, token: { did, iat: 0, exp: Date.now() / 1000 + 60 } }),
    checkRate: async () => ({
      ok: false,
      remaining: 0,
      retryAfterSeconds: 30,
      backend: 'memory' as const,
    }),
    provider: async () => {
      called = true
      return 'x'
    },
  })
  const res = makeRes()
  await handler(makeReq({ explanation: 'x' }, 'tok'), res)
  assert.equal(res.code, 429)
  assert.equal(called, false)
})

test('handler: 正常��は生成されたackを返す', async () => {
  const handler = companionLineHandler({
    verifyToken: () => ({ ok: true, token: { did, iat: 0, exp: Date.now() / 1000 + 60 } }),
    checkRate: async () => okRate,
    provider: async () => '「ふむ、不純物が混ざるのか」',
  })
  const res = makeRes()
  await handler(
    makeReq(
      { explanation: '水には不純物があるから通す', heardTerms: ['不純物'], conceptLabel: '電流' },
      'tok',
    ),
    res,
  )
  assert.equal(res.code, 200)
  assert.deepEqual(res.body, { ack: 'ふむ、不純物が混ざるのか' })
})

test('handler: 生成不合格はack:null', async () => {
  const handler = companionLineHandler({
    verifyToken: () => ({ ok: true, token: { did, iat: 0, exp: Date.now() / 1000 + 60 } }),
    checkRate: async () => okRate,
    provider: async () => 'I cannot help with that?',
  })
  const res = makeRes()
  await handler(makeReq({ explanation: 'x' }, 'tok'), res)
  assert.equal(res.code, 200)
  assert.deepEqual(res.body, { ack: null })
})
