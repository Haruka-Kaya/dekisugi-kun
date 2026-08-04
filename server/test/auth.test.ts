import assert from 'node:assert/strict'
import { afterEach, describe, it } from 'node:test'

import handler from '../api/director.js'

/** ハンドラの応答を捕まえる最小のレス */
function fakeRes() {
  const out: { code?: number; body?: unknown; headers: Record<string, string> } = { headers: {} }
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

afterEach(() => {
  delete process.env.DIRECTOR_TOKEN
})

describe('門', () => {
  it('トークン未設定なら素通し（ローカル開発）', async () => {
    const { res, out } = fakeRes()
    // 単元を渡さないので 400 で止まる。401 でないことだけ見る
    await handler({ method: 'POST', body: {} }, res)
    assert.notEqual(out.code, 401)
  })

  it('トークンが設定されていて未提示なら 401', async () => {
    process.env.DIRECTOR_TOKEN = 'secret-value'
    const { res, out } = fakeRes()
    await handler({ method: 'POST', body: {}, headers: {} }, res)
    assert.equal(out.code, 401)
  })

  it('トークンが違えば 401', async () => {
    process.env.DIRECTOR_TOKEN = 'secret-value'
    const { res, out } = fakeRes()
    await handler({ method: 'POST', body: {}, headers: { 'x-dekisugi-token': 'wrong-value' } }, res)
    assert.equal(out.code, 401)
  })

  it('長さだけ合っていても通さない', async () => {
    process.env.DIRECTOR_TOKEN = 'secret-value'
    const { res, out } = fakeRes()
    await handler({ method: 'POST', body: {}, headers: { 'x-dekisugi-token': 'xxxxxx-xxxxx' } }, res)
    assert.equal(out.code, 401)
  })

  it('合っていれば通す', async () => {
    process.env.DIRECTOR_TOKEN = 'secret-value'
    const { res, out } = fakeRes()
    await handler(
      { method: 'POST', body: {}, headers: { 'x-dekisugi-token': 'secret-value' } },
      res,
    )
    assert.equal(out.code, 400) // 門は通り、入力の検証で落ちる
  })
})

describe('メソッド', () => {
  it('GET は 405 で Allow を返す', async () => {
    const { res, out } = fakeRes()
    await handler({ method: 'GET' }, res)
    assert.equal(out.code, 405)
    assert.equal(out.headers.Allow, 'POST')
  })
})

describe('入力の検証', () => {
  it('壊れた JSON 文字列を 400 で返す', async () => {
    const { res, out } = fakeRes()
    await handler({ method: 'POST', body: '{ぐちゃぐちゃ' }, res)
    assert.deepEqual(out.body, { error: 'invalid_json' })
  })

  it('大きすぎる body を 413 で返す（LLM を呼ぶ前に落とす）', async () => {
    const { res, out } = fakeRes()
    await handler({ method: 'POST', body: 'x'.repeat(300 * 1024) }, res)
    assert.equal(out.code, 413)
  })
})
