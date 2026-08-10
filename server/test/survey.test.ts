import assert from 'node:assert/strict'
import { beforeEach, describe, it } from 'node:test'

import survey from '../api/survey.js'
import { MAX_BYTES, SURVEY_KINDS, isSurveyKind } from '../lib/survey.js'

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

const answer = (extra: Record<string, unknown> = {}) => ({
  v: 1,
  kind: 'misconception',
  ts: '2026-08-06T00:00:00Z',
  ans: { M01: { pick: 2 } },
  ...extra,
})

describe('アンケートの種類', () => {
  it('知っている種類だけ通す', () => {
    // 知らない種類まで貯めると、保存先がゴミ置き場になる
    for (const k of SURVEY_KINDS) assert.ok(isSurveyKind(k))
    assert.ok(!isSurveyKind('その他'))
    assert.ok(!isSurveyKind(''))
    assert.ok(!isSurveyKind(42))
  })
})

describe('POST /api/survey', () => {
  beforeEach(() => {
    delete process.env.NODE_ENV
    delete process.env.VERCEL_ENV
    process.env.DEKISUGI_INTERNAL_RESTRICTED_DATA_TESTING = '1'
    delete process.env.KV_REST_API_URL
    delete process.env.KV_REST_API_TOKEN
    delete process.env.SURVEY_ADMIN_TOKEN
  })

  it('保存先が無ければ 503。**200 を返さない**', async () => {
    // 200 を返して実は消えている、が最悪。
    // ブラウザはこれを見てコード表示に落ちるので、回答は失われない
    const { res, out } = fakeRes()
    await survey({ method: 'POST', body: answer() }, res)
    assert.equal(out.code, 503)
    assert.equal((out.body as { error: string }).error, 'no_store')
  })

  it('知らない種類は 400', async () => {
    const { res, out } = fakeRes()
    await survey({ method: 'POST', body: answer({ kind: 'いたずら' }) }, res)
    assert.equal(out.code, 400)
    assert.equal((out.body as { error: string }).error, 'unknown_kind')
  })

  it('種類が無ければ 400', async () => {
    const { res, out } = fakeRes()
    const body = answer()
    delete (body as { kind?: unknown }).kind
    await survey({ method: 'POST', body }, res)
    assert.equal(out.code, 400)
  })

  it('大きすぎたら 413', async () => {
    const { res, out } = fakeRes()
    await survey(
      { method: 'POST', body: answer({ pad: 'あ'.repeat(MAX_BYTES) }) },
      res,
    )
    assert.equal(out.code, 413)
  })

  it('本文が文字列でも読む', async () => {
    const { res, out } = fakeRes()
    await survey({ method: 'POST', body: JSON.stringify(answer()) }, res)
    // 保存先が無いので 503。**400 ではない**（読めてはいる）
    assert.equal(out.code, 503)
  })

  it('壊れた JSON は 400', async () => {
    const { res, out } = fakeRes()
    await survey({ method: 'POST', body: '{壊れている' }, res)
    assert.equal(out.code, 400)
    assert.equal((out.body as { error: string }).error, 'invalid_json')
  })

  it('別オリジンから開けるようにしておく', async () => {
    // 配り方を縛らない（LINE でもプリントの QR でも）
    const { res, out } = fakeRes()
    await survey({ method: 'OPTIONS' }, res)
    assert.equal(out.code, 204)
    assert.equal(out.headers['Access-Control-Allow-Origin'], '*')
  })

  it('PUT は 405', async () => {
    const { res, out } = fakeRes()
    await survey({ method: 'PUT' }, res)
    assert.equal(out.code, 405)
  })
})

describe('DELETE /api/survey（試し投稿の片づけ）', () => {
  beforeEach(() => {
    delete process.env.SURVEY_ADMIN_TOKEN
    delete process.env.KV_REST_API_URL
    delete process.env.KV_REST_API_TOKEN
  })

  it('管理トークンが要る', async () => {
    const { res, out } = fakeRes()
    await survey({ method: 'DELETE', query: { kind: 'misconception' } }, res)
    assert.equal(out.code, 401)
  })

  it('件数が合わなければ消さない', async () => {
    // 集めたあとに誤って呼ぶと戻せない。
    // 「いま何件あるか」を分かっていることを条件にする
    process.env.SURVEY_ADMIN_TOKEN = 'ほんもの'
    const { res, out } = fakeRes()
    await survey(
      {
        method: 'DELETE',
        query: { kind: 'misconception', expect: '5' },
        headers: { authorization: 'Bearer ほんもの' },
      },
      res,
    )
    assert.equal(out.code, 409)
    assert.equal((out.body as { count: number }).count, 0)
  })

  it('件数が合えば消す', async () => {
    process.env.SURVEY_ADMIN_TOKEN = 'ほんもの'
    const { res, out } = fakeRes()
    await survey(
      {
        method: 'DELETE',
        query: { kind: 'misconception', expect: '0' },
        headers: { authorization: 'Bearer ほんもの' },
      },
      res,
    )
    assert.equal(out.code, 200)
  })

  it('件数を書かなければ消さない', async () => {
    process.env.SURVEY_ADMIN_TOKEN = 'ほんもの'
    const { res, out } = fakeRes()
    await survey(
      {
        method: 'DELETE',
        query: { kind: 'misconception' },
        headers: { authorization: 'Bearer ほんもの' },
      },
      res,
    )
    assert.equal(out.code, 409)
  })
})

describe('GET /api/survey（取り出し）', () => {
  beforeEach(() => {
    delete process.env.SURVEY_ADMIN_TOKEN
  })

  it('管理トークンが未設定なら閉じる', async () => {
    // 「未設定なら素通し」にすると、設定を忘れた瞬間に全部読める。
    // 中高生の自由記述なので、開いている方に倒さない
    const { res, out } = fakeRes()
    await survey({ method: 'GET', query: { kind: 'misconception' } }, res)
    assert.equal(out.code, 401)
  })

  it('合わないトークンを弾く', async () => {
    process.env.SURVEY_ADMIN_TOKEN = 'ほんもの'
    const { res, out } = fakeRes()
    await survey(
      {
        method: 'GET',
        query: { kind: 'misconception' },
        headers: { authorization: 'Bearer にせもの' },
      },
      res,
    )
    assert.equal(out.code, 401)
  })

  it('合えば取り出せる', async () => {
    process.env.SURVEY_ADMIN_TOKEN = 'ほんもの'
    const { res, out } = fakeRes()
    await survey(
      {
        method: 'GET',
        query: { kind: 'misconception' },
        headers: { authorization: 'Bearer ほんもの' },
      },
      res,
    )
    assert.equal(out.code, 200)
    // 保存先が無いので空。**401 ではない**ことが要点
    assert.deepEqual((out.body as { responses: string[] }).responses, [])
  })

  it('知らない種類は 400', async () => {
    process.env.SURVEY_ADMIN_TOKEN = 'ほんもの'
    const { res, out } = fakeRes()
    await survey(
      {
        method: 'GET',
        query: { kind: 'なにか' },
        headers: { authorization: 'Bearer ほんもの' },
      },
      res,
    )
    assert.equal(out.code, 400)
  })
})
