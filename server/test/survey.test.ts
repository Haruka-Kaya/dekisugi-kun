import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { afterEach, beforeEach, describe, it } from 'node:test'

import survey, { handleSurvey } from '../api/survey.js'
import {
  MAX_BYTES,
  MAX_RESPONSES_PER_SESSION_HOUR,
  MAX_SURVEY_RESPONSES_PER_HOUR,
  SURVEY_IDLE_RETENTION_SECONDS,
  SURVEY_KINDS,
  isSurveyKind,
  tooManyForSession,
} from '../lib/survey.js'

const SURVEY_ORIGIN = 'https://rika-chousa.vercel.app'
const SURVEY_HOST = 'rika-chousa.vercel.app'
const SESSION_A = '2bb832aa-6ca7-46e4-90fd-5af4d04144d8'
const SESSION_B = 'dbeceaf5-bc4f-486b-bf78-0f6c459fdc35'

function fakeRes() {
  const out: {
    code?: number
    body?: unknown
    headers: Record<string, string>
  } = {
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
  v: 3,
  kind: 'misconception',
  sessionId: SESSION_A,
  done: true,
  meta: { grade: '中学3年', like: '好き' },
  ans: [
    ['M01', '落下', 2],
    ['M02', '慣性', 1],
    ['M03', '摩擦と静止', 2],
    ['M04', '作用・反作用', 2],
  ].map(([id, topic, pick], i) => ({
    id,
    topic,
    explain: `${topic}について条件をそろえて考えました`,
    explainMs: 1200 + i,
    lureReply: '前提を確認すると、その考え方とは異なります',
    lureMs: 800 + i,
    pick,
    pickPos: i,
    pick2: pick,
    pickPos2: 3 - i,
    learned: '習った',
    mcMs: 900 + i,
    correct: true,
    heldMisconception: false,
    groundTruth: 'understood',
    correct1: true,
    heldMisconception1: false,
  })),
  ...extra,
})

const typeAnswer = (extra: Record<string, unknown> = {}) => ({
  v: 3,
  kind: 'type',
  sessionId: SESSION_B,
  meta: {
    grade: '高校1年',
    light: 'ふつう',
    scale: '標準のまま',
  },
  lh: [1.45, 1.6, 1.75, 1.9],
  ls: [0, 0.02, 0.04],
  ans: [
    ['lh', { lh: 1.45, ls: 0 }, { lh: 1.6, ls: 0 }],
    ['lh', { lh: 1.45, ls: 0 }, { lh: 1.75, ls: 0 }],
    ['lh', { lh: 1.45, ls: 0 }, { lh: 1.9, ls: 0 }],
    ['lh', { lh: 1.6, ls: 0 }, { lh: 1.75, ls: 0 }],
    ['lh', { lh: 1.6, ls: 0 }, { lh: 1.9, ls: 0 }],
    ['lh', { lh: 1.75, ls: 0 }, { lh: 1.9, ls: 0 }],
    ['ls', { lh: 1.75, ls: 0 }, { lh: 1.75, ls: 0.02 }],
    ['ls', { lh: 1.75, ls: 0 }, { lh: 1.75, ls: 0.04 }],
    ['ls', { lh: 1.75, ls: 0.02 }, { lh: 1.75, ls: 0.04 }],
    ['catch', { lh: 1, ls: 0 }, { lh: 1.75, ls: 0 }],
  ].map(([d, pick, other], i) => ({
    i,
    d,
    pick,
    other,
    side: i % 2 === 0 ? 'a' : 'b',
    flip: i % 2,
    tx: ['sci1', 'soc1', 'sci2'][i % 3],
    ms: 500 + i,
  })),
  ...extra,
})

function browserHeaders(origin = SURVEY_ORIGIN) {
  return {
    host: SURVEY_HOST,
    'x-forwarded-host': SURVEY_HOST,
    'x-forwarded-proto': 'https',
    origin,
  }
}

type KvValue = string | string[]

/** survey が実際に発行する Upstash command を通す最小の偽ストア。 */
function useSurveyKv() {
  const originalFetch = globalThis.fetch
  const data = new Map<string, KvValue>()
  const log: string[][] = []

  function list(key: string): string[] {
    const current = data.get(key)
    if (current === undefined) {
      const created: string[] = []
      data.set(key, created)
      return created
    }
    if (!Array.isArray(current)) throw new Error(`listではない: ${key}`)
    return current
  }

  function command(parts: string[]): unknown {
    log.push(parts)
    const [rawOp, key = '', ...args] = parts
    if (rawOp?.toUpperCase() === 'EVAL') {
      const script = parts[1] ?? ''
      if (script.includes('session_count')) {
        const sessionKey = parts[3] ?? ''
        const globalKey = parts[4] ?? ''
        const currentGlobal = Number(data.get(globalKey) ?? '0')
        if (currentGlobal >= MAX_SURVEY_RESPONSES_PER_HOUR) {
          return [-1, currentGlobal]
        }
        const sessionCount = Number(data.get(sessionKey) ?? '0') + 1
        data.set(sessionKey, String(sessionCount))
        if (sessionCount > MAX_RESPONSES_PER_SESSION_HOUR) {
          return [sessionCount, -1]
        }
        const globalCount = currentGlobal + 1
        data.set(globalKey, String(globalCount))
        return [sessionCount, globalCount]
      }
      const listName = parts[3] ?? ''
      if (script.includes("redis.call('DEL'")) {
        const rows = list(listName)
        const expected = Number(parts[4])
        if (rows.length !== expected) return -rows.length - 1
        const removed = rows.length
        data.delete(listName)
        return removed
      }
      return list(listName).push(parts[4] ?? '')
    }
    switch (rawOp?.toUpperCase()) {
      case 'LLEN':
        return list(key).length
      case 'RPUSH':
        return list(key).push(...args)
      case 'LRANGE': {
        const rows = list(key)
        const start = Number(args[0] ?? 0)
        const rawEnd = Number(args[1] ?? -1)
        const end = rawEnd < 0 ? rows.length : rawEnd + 1
        return rows.slice(start, end)
      }
      case 'INCR': {
        const next = Number(data.get(key) ?? '0') + 1
        data.set(key, String(next))
        return next
      }
      case 'EXPIRE':
        return data.has(key) ? 1 : 0
      case 'DEL': {
        const existed = data.delete(key)
        return existed ? 1 : 0
      }
      case 'LREM': {
        const rows = list(key)
        const value = args[1]
        const at = rows.indexOf(value ?? '')
        if (at < 0) return 0
        rows.splice(at, 1)
        return 1
      }
      default:
        throw new Error(`未対応のsurvey KV command: ${rawOp}`)
    }
  }

  process.env.KV_REST_API_URL = 'https://survey-kv.test'
  process.env.KV_REST_API_TOKEN = 'test-token'
  globalThis.fetch = (async (input: unknown, init?: { body?: string }) => {
    if (!String(input).startsWith('https://survey-kv.test/')) {
      return originalFetch(input as never, init as never)
    }
    const commands = JSON.parse(init?.body ?? '[]') as string[][]
    return new Response(
      JSON.stringify(commands.map((parts) => ({ result: command(parts) }))),
      { status: 200 },
    )
  }) as typeof fetch

  return {
    data,
    log,
    restore() {
      globalThis.fetch = originalFetch
      delete process.env.KV_REST_API_URL
      delete process.env.KV_REST_API_TOKEN
    },
  }
}

let restoreKv: (() => void) | undefined

afterEach(() => {
  restoreKv?.()
  restoreKv = undefined
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

describe('配布HTMLとAPIのpayload契約', () => {
  it('両アンケートがv3・匿名session・/api/surveyを使い、環境情報を送らない', () => {
    const rika = readFileSync(
      new URL('../public/survey/rika/index.html', import.meta.url),
      'utf8',
    )
    const type = readFileSync(
      new URL('../public/survey/type/index.html', import.meta.url),
      'utf8',
    )

    for (const [name, html] of [
      ['misconception', rika],
      ['type', type],
    ] as const) {
      assert.match(html, /const ENDPOINT = ["']\/api\/survey["'];/, name)
      assert.match(html, /crypto\.(?:randomUUID|getRandomValues)/, name)
      assert.doesNotMatch(html, /\/api\/submit/, name)
    }

    const rikaPayload =
      /function payload\(done\)\s*\{[\s\S]*?return\s*\{([\s\S]*?)\}\s*;?\s*\}/.exec(
        rika,
      )?.[1]
    const typePayload = /const payload\s*=\s*\{([\s\S]*?)\n\s*\};/.exec(
      type,
    )?.[1]
    assert.ok(rikaPayload)
    assert.ok(typePayload)
    for (const payload of [rikaPayload, typePayload]) {
      assert.match(payload, /v\s*:\s*3/)
      assert.match(payload, /sessionId/)
      assert.doesNotMatch(payload, /\b(?:ts|env|ua|lang|email|name)\s*:/)
    }
  })
})

describe('POST /api/survey', () => {
  beforeEach(() => {
    delete process.env.NODE_ENV
    delete process.env.VERCEL_ENV
    delete process.env.DEKISUGI_INTERNAL_RESTRICTED_DATA_TESTING
    process.env.DEKISUGI_ANONYMOUS_SURVEY_ENABLED = '1'
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

  it('Upstash pipelineがHTTP 200内でerrorを返しても保存成功にしない', async () => {
    process.env.KV_REST_API_URL = 'https://survey-kv.test'
    process.env.KV_REST_API_TOKEN = 'test-token'
    const originalFetch = globalThis.fetch
    globalThis.fetch = (async (_input: unknown, init?: { body?: string }) => {
      const commands = JSON.parse(init?.body ?? '[]') as string[][]
      const isRate = commands[0]?.[1]?.includes('session_count') ?? false
      const result = isRate
        ? [{ result: [1, 1] }]
        : [{ error: 'ERR simulated write failure' }]
      return new Response(JSON.stringify(result), { status: 200 })
    }) as typeof fetch
    restoreKv = () => {
      globalThis.fetch = originalFetch
      delete process.env.KV_REST_API_URL
      delete process.env.KV_REST_API_TOKEN
    }

    const { res, out } = fakeRes()
    await survey(
      { method: 'POST', headers: browserHeaders(), body: answer() },
      res,
    )
    assert.equal(out.code, 503)
    assert.deepEqual(out.body, { error: 'store_failed' })
  })

  it('EVALの保存件数が欠けた応答も保存成功にしない', async () => {
    process.env.KV_REST_API_URL = 'https://survey-kv.test'
    process.env.KV_REST_API_TOKEN = 'test-token'
    const originalFetch = globalThis.fetch
    globalThis.fetch = (async (_input: unknown, init?: { body?: string }) => {
      const commands = JSON.parse(init?.body ?? '[]') as string[][]
      const isRate = commands[0]?.[1]?.includes('session_count') ?? false
      const result = isRate ? [{ result: [1, 1] }] : [{ result: null }]
      return new Response(JSON.stringify(result), { status: 200 })
    }) as typeof fetch
    restoreKv = () => {
      globalThis.fetch = originalFetch
      delete process.env.KV_REST_API_URL
      delete process.env.KV_REST_API_TOKEN
    }

    const { res, out } = fakeRes()
    await survey(
      { method: 'POST', headers: browserHeaders(), body: answer() },
      res,
    )
    assert.equal(out.code, 503)
    assert.deepEqual(out.body, { error: 'store_failed' })
  })

  it('知らない種類は 400', async () => {
    const { res, out } = fakeRes()
    await survey({ method: 'POST', body: answer({ kind: 'いたずら' }) }, res)
    assert.equal(out.code, 400)
    assert.equal((out.body as { error: string }).error, 'invalid_schema')
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

  it('preflightは同一オリジンだけへexactなCORS headerを返す', async () => {
    const { res, out } = fakeRes()
    await survey({ method: 'OPTIONS', headers: browserHeaders() }, res)
    assert.equal(out.code, 204)
    assert.equal(out.headers['Access-Control-Allow-Origin'], SURVEY_ORIGIN)
    assert.notEqual(out.headers['Access-Control-Allow-Origin'], '*')
  })

  it('別オリジンは保存処理より前に拒否する', async () => {
    let calls = 0
    const { res, out } = fakeRes()
    await handleSurvey(
      {
        method: 'POST',
        headers: browserHeaders('https://attacker.example'),
        body: answer(),
      },
      res,
      {
        tooMany: async () => {
          calls++
          return false
        },
        save: async () => {
          calls++
          return { ok: true, receipt: 'sr_not_reached' }
        },
      },
    )
    assert.equal(out.code, 403)
    assert.equal(calls, 0)
  })

  it('Originが無いsendBeacon・CLIは受け付ける', async () => {
    const { res, out } = fakeRes()
    await handleSurvey({ method: 'POST', body: answer() }, res, {
      tooMany: async () => false,
      save: async () => ({
        ok: true,
        receipt: 'sr_7sMeBUX58Ep4heMpdd9Q7Wmw',
      }),
    })
    assert.equal(out.code, 200)
  })

  it('PUT は 405', async () => {
    const { res, out } = fakeRes()
    await survey({ method: 'PUT' }, res)
    assert.equal(out.code, 405)
  })

  it('2種類のexact payloadを保存し、成功時はopaque receiptだけ返す', async () => {
    const store = useSurveyKv()
    restoreKv = store.restore

    for (const body of [answer(), typeAnswer()]) {
      const { res, out } = fakeRes()
      await survey({ method: 'POST', body }, res)
      assert.equal(out.code, 200, JSON.stringify(out.body))
      assert.deepEqual(Object.keys(out.body as object).sort(), [
        'ok',
        'receipt',
      ])
      const receipt = (out.body as { receipt: unknown }).receipt
      assert.equal(typeof receipt, 'string')
      assert.ok((receipt as string).length >= 20)
      assert.ok(!(receipt as string).includes(String(body.sessionId)))
    }
    assert.ok(
      store.log.some(
        (parts) =>
          parts[0] === 'EVAL' &&
          parts[1]?.includes(
            `redis.call('EXPIRE', KEYS[1], ${SURVEY_IDLE_RETENTION_SECONDS})`,
          ),
      ),
      '保存と同じLua内で90日idle TTLを設定する',
    )
  })

  it('文字調査は総当たり・提示文・左右反転が正本と一致する回答だけ保存する', async () => {
    const duplicatePair = typeAnswer()
    duplicatePair.ans[1]!.pick = duplicatePair.ans[0]!.pick
    duplicatePair.ans[1]!.other = duplicatePair.ans[0]!.other

    const wrongText = typeAnswer()
    wrongText.ans[0]!.tx = 'soc1'

    const wrongFlip = typeAnswer()
    wrongFlip.ans[0]!.flip = 1

    for (const body of [duplicatePair, wrongText, wrongFlip]) {
      let calls = 0
      const { res, out } = fakeRes()
      await handleSurvey({ method: 'POST', body }, res, {
        tooMany: async () => {
          calls++
          return false
        },
        save: async () => {
          calls++
          return { ok: true, receipt: 'sr_not_reached' }
        },
      })
      assert.equal(out.code, 400, JSON.stringify(body))
      assert.equal(calls, 0)
    }
  })

  it('top-level・meta・回答・環境情報の未知fieldを無視せず400にする', async () => {
    const invalidBodies: unknown[] = [
      answer({ email: 'student@example.com' }),
      answer({ name: '氏名' }),
      answer({ school: '○○中学校' }),
      answer({ ts: '2026-08-10T00:00:00Z' }),
      answer({ env: { ua: 'browser', lang: 'ja-JP' } }),
      answer({ ua: 'browser' }),
      answer({ lang: 'ja-JP' }),
      answer({ meta: { grade: '中学3年', like: '好き', name: '氏名' } }),
      answer({
        ans: answer().ans.map((item, i) =>
          i === 0
            ? {
                ...item,
                deviceId: '84d70bba-b28b-40ca-9d91-3ed0908f66df',
              }
            : item,
        ),
      }),
      typeAnswer({
        meta: {
          grade: '高校1年',
          light: 'ふつう',
          scale: '標準のまま',
          email: 'student@example.com',
        },
      }),
    ]

    for (const body of invalidBodies) {
      let calls = 0
      const { res, out } = fakeRes()
      await handleSurvey({ method: 'POST', body }, res, {
        tooMany: async () => {
          calls++
          return false
        },
        save: async () => {
          calls++
          return { ok: true, receipt: 'sr_not_reached' }
        },
      })
      assert.equal(out.code, 400, JSON.stringify(body))
      assert.equal(calls, 0, '不正payloadでrate/storeを消費しない')
    }
  })

  it('自由記述に連絡先が含まれる回答を保存しない', async () => {
    const withEmail = answer()
    withEmail.ans[0]!.explain =
      '詳しくは student@example.com に連絡してください'
    const withPhone = answer()
    withPhone.ans[0]!.lureReply = '電話番号は 090-1234-5678 です'

    for (const body of [withEmail, withPhone]) {
      let calls = 0
      const { res, out } = fakeRes()
      await handleSurvey({ method: 'POST', body }, res, {
        tooMany: async () => {
          calls++
          return false
        },
        save: async () => {
          calls++
          return { ok: true, receipt: 'sr_not_reached' }
        },
      })
      assert.equal(out.code, 400)
      assert.deepEqual(out.body, { error: 'personal_information' })
      assert.equal(calls, 0)
    }
  })

  it('sessionIdが無い・壊れている回答は保存しない', async () => {
    for (const sessionId of [undefined, '', 'same-for-everyone', 42]) {
      const body = answer({ sessionId })
      if (sessionId === undefined)
        delete (body as { sessionId?: unknown }).sessionId
      const { res, out } = fakeRes()
      await survey({ method: 'POST', body }, res)
      assert.equal(out.code, 400, JSON.stringify(sessionId))
    }
  })

  it('rateはIPではなくsessionId単位で上限まで許可する', async () => {
    const store = useSurveyKv()
    restoreKv = store.restore
    const ip = '203.0.113.91'
    assert.equal(MAX_RESPONSES_PER_SESSION_HOUR, 12)

    for (let i = 0; i < MAX_RESPONSES_PER_SESSION_HOUR; i++) {
      const { res, out } = fakeRes()
      await survey(
        {
          method: 'POST',
          headers: { 'x-forwarded-for': ip, 'x-real-ip': ip },
          body: answer(),
        },
        res,
      )
      assert.equal(out.code, 200, `同じsessionの${i + 1}件目`)
    }

    const limited = fakeRes()
    await survey(
      {
        method: 'POST',
        headers: { 'x-forwarded-for': ip, 'x-real-ip': ip },
        body: answer(),
      },
      limited.res,
    )
    assert.equal(limited.out.code, 429)

    const another = fakeRes()
    await survey(
      {
        method: 'POST',
        headers: { 'x-forwarded-for': ip, 'x-real-ip': ip },
        body: answer({ sessionId: SESSION_B }),
      },
      another.res,
    )
    assert.equal(another.out.code, 200)
    assert.ok(
      !JSON.stringify(store.log).includes(ip),
      'IPをKV key/valueへ送らない',
    )
  })

  it('sessionIdを取り替えても全体burst上限を超えて保存へ進めない', async () => {
    const store = useSurveyKv()
    restoreKv = store.restore
    const now = Date.UTC(2026, 7, 10, 3)

    for (let i = 0; i < MAX_SURVEY_RESPONSES_PER_HOUR; i++) {
      const sessionId = `00000000-0000-4000-8000-${i
        .toString(16)
        .padStart(12, '0')}`
      assert.equal(await tooManyForSession(sessionId, now), false, String(i))
    }
    for (let i = 0; i < 1000; i++) {
      assert.equal(
        await tooManyForSession(
          `ffffffff-ffff-4fff-8fff-${i.toString(16).padStart(12, '0')}`,
          now,
        ),
        true,
      )
    }
    assert.equal(
      [...store.data.keys()].filter((key) => key.startsWith('survey:session:'))
        .length,
      MAX_SURVEY_RESPONSES_PER_HOUR,
    )
    assert.equal(
      store.data.get(`survey:global:${Math.floor(now / 3_600_000)}`),
      String(MAX_SURVEY_RESPONSES_PER_HOUR),
    )
  })

  it('session上限後の429連打は新しい回答者のglobal枠を消費しない', async () => {
    const store = useSurveyKv()
    restoreKv = store.restore
    const now = Date.UTC(2026, 7, 10, 4)

    for (let i = 0; i < MAX_RESPONSES_PER_SESSION_HOUR; i++) {
      assert.equal(await tooManyForSession(SESSION_A, now), false)
    }
    for (let i = 0; i < MAX_SURVEY_RESPONSES_PER_HOUR + 10; i++) {
      assert.equal(await tooManyForSession(SESSION_A, now), true)
    }
    assert.equal(await tooManyForSession(SESSION_B, now), false)
  })
})

describe('DELETE /api/survey（試し投稿の片づけ）', () => {
  beforeEach(() => {
    delete process.env.SURVEY_ADMIN_TOKEN
    delete process.env.KV_REST_API_URL
    delete process.env.KV_REST_API_TOKEN
    process.env.DEKISUGI_ANONYMOUS_SURVEY_ENABLED = '1'
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

  it('件数確認後に回答が増えても新着を巻き込んで全削除しない', async () => {
    const store = useSurveyKv()
    restoreKv = store.restore
    const first = fakeRes()
    await survey({ method: 'POST', body: answer() }, first.res)
    assert.equal(first.out.code, 200)

    const rows = store.data.get('survey:misconception')
    assert.ok(Array.isArray(rows))
    rows.push(JSON.stringify({ v: 2, kind: 'misconception', ans: [] }))

    process.env.SURVEY_ADMIN_TOKEN = 'ほんもの'
    const { res, out } = fakeRes()
    await survey(
      {
        method: 'DELETE',
        query: { kind: 'misconception', expect: '1' },
        headers: { authorization: 'Bearer ほんもの' },
      },
      res,
    )
    assert.equal(out.code, 409)
    assert.deepEqual(out.body, { error: 'count_mismatch', count: 2 })
    assert.equal(rows.length, 2)
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

  it('成功receiptでその疎通回答1件だけを削除できる', async () => {
    const store = useSurveyKv()
    restoreKv = store.restore
    const posted = fakeRes()
    await survey({ method: 'POST', body: answer() }, posted.res)
    assert.equal(posted.out.code, 200)
    const receipt = (posted.out.body as { receipt: string }).receipt

    process.env.SURVEY_ADMIN_TOKEN = 'ほんもの'
    const removed = fakeRes()
    await survey(
      {
        method: 'DELETE',
        query: { kind: 'misconception', receipt },
        headers: { authorization: 'Bearer ほんもの' },
      },
      removed.res,
    )
    assert.equal(removed.out.code, 200)
    assert.deepEqual(removed.out.body, { ok: true, removed: 1 })

    const fetched = fakeRes()
    await survey(
      {
        method: 'GET',
        query: { kind: 'misconception' },
        headers: { authorization: 'Bearer ほんもの' },
      },
      fetched.res,
    )
    assert.deepEqual(
      (fetched.out.body as { responses: string[] }).responses,
      [],
    )
  })
})

describe('GET /api/survey（取り出し）', () => {
  beforeEach(() => {
    delete process.env.SURVEY_ADMIN_TOKEN
    delete process.env.KV_REST_API_URL
    delete process.env.KV_REST_API_TOKEN
    process.env.DEKISUGI_ANONYMOUS_SURVEY_ENABLED = '1'
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

  it('保存成功後に管理者が同じ回答を取得でき、IPやHTTP UAは保存されない', async () => {
    const store = useSurveyKv()
    restoreKv = store.restore
    const ip = '198.51.100.24'
    const httpUa = 'SecretBrowser/99.0'

    const posted = fakeRes()
    await survey(
      {
        method: 'POST',
        headers: {
          'x-forwarded-for': ip,
          'x-real-ip': ip,
          'user-agent': httpUa,
        },
        body: answer(),
      },
      posted.res,
    )
    assert.equal(posted.out.code, 200, JSON.stringify(posted.out.body))

    process.env.SURVEY_ADMIN_TOKEN = 'ほんもの'
    const fetched = fakeRes()
    await survey(
      {
        method: 'GET',
        query: { kind: 'misconception' },
        headers: { authorization: 'Bearer ほんもの' },
      },
      fetched.res,
    )

    assert.equal(fetched.out.code, 200)
    assert.equal(fetched.out.headers['Cache-Control'], 'no-store')
    const rows = (fetched.out.body as { responses: string[] }).responses
    assert.equal(rows.length, 1)
    assert.deepEqual(JSON.parse(rows[0]!), answer())
    assert.ok(
      !rows[0]!.includes((posted.out.body as { receipt: string }).receipt),
    )
    const persisted = JSON.stringify([...store.data])
    const commands = JSON.stringify(store.log)
    assert.ok(!persisted.includes(ip))
    assert.ok(!persisted.includes(httpUa))
    assert.ok(!commands.includes(ip), 'rate keyにもIPを残さない')
  })
})
