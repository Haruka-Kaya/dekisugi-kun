import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { afterEach, beforeEach, describe, it } from 'node:test'
import { runInNewContext } from 'node:vm'

import survey, { handleSurvey } from '../api/survey.js'
import {
  MAX_BYTES,
  MAX_RESPONSES,
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

type KvHash = { type: 'hash'; entries: Record<string, string> }
type KvValue = string | string[] | KvHash

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

  function hash(key: string): KvHash {
    const current = data.get(key)
    if (current === undefined) {
      const created: KvHash = { type: 'hash', entries: {} }
      data.set(key, created)
      return created
    }
    if (
      typeof current !== 'object' ||
      Array.isArray(current) ||
      current.type !== 'hash'
    ) {
      throw new Error(`hashではない: ${key}`)
    }
    return current
  }

  function listLength(key: string): number {
    const current = data.get(key)
    if (current === undefined) return 0
    if (!Array.isArray(current)) throw new Error(`listではない: ${key}`)
    return current.length
  }

  function hashLength(key: string): number {
    const current = data.get(key)
    if (current === undefined) return 0
    if (
      typeof current !== 'object' ||
      Array.isArray(current) ||
      current.type !== 'hash'
    ) {
      throw new Error(`hashではない: ${key}`)
    }
    return Object.keys(current.entries).length
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

      if (script.includes('current_revision_raw')) {
        const legacyKey = parts[3] ?? ''
        const recordKey = parts[4] ?? ''
        const revisionKey = parts[5] ?? ''
        const mutationKey = parts[6] ?? ''
        const field = parts[7] ?? ''
        const incomingRevision = Number(parts[8])
        const incomingRow = parts[9] ?? ''
        const records = hash(recordKey)
        const revisions = hash(revisionKey)
        const current = records.entries[field]
        const currentRevisionRaw = revisions.entries[field]
        if ((current == null) !== (currentRevisionRaw == null)) return [-2, '']
        if (current != null && Number(currentRevisionRaw) >= incomingRevision) {
          return [0, current]
        }
        if (
          current == null &&
          listLength(legacyKey) + hashLength(recordKey) >= MAX_RESPONSES
        ) {
          return [-1, '']
        }
        records.entries[field] = incomingRow
        revisions.entries[field] = String(incomingRevision)
        data.set(mutationKey, String(Number(data.get(mutationKey) ?? '0') + 1))
        return [1, incomingRow]
      }

      if (script.includes('return {legacy, current, mutation}')) {
        const legacyKey = parts[3] ?? ''
        const recordKey = parts[4] ?? ''
        const mutationKey = parts[5] ?? ''
        return [
          data.has(legacyKey) ? [...list(legacyKey)] : [],
          data.has(recordKey) ? Object.values(hash(recordKey).entries) : [],
          Number(data.get(mutationKey) ?? '0'),
        ]
      }

      if (script.includes("local removed = redis.call('LREM'")) {
        const legacyKey = parts[3] ?? ''
        const mutationKey = parts[4] ?? ''
        const candidate = parts[5] ?? ''
        const rows = list(legacyKey)
        const at = rows.indexOf(candidate)
        if (at < 0) return 0
        rows.splice(at, 1)
        data.set(mutationKey, String(Number(data.get(mutationKey) ?? '0') + 1))
        return 1
      }

      if (script.includes('current ~= ARGV[2]')) {
        const recordKey = parts[3] ?? ''
        const revisionKey = parts[4] ?? ''
        const mutationKey = parts[5] ?? ''
        const field = parts[6] ?? ''
        const candidate = parts[7] ?? ''
        const records = hash(recordKey)
        if (records.entries[field] !== candidate) return 0
        delete records.entries[field]
        delete hash(revisionKey).entries[field]
        data.set(mutationKey, String(Number(data.get(mutationKey) ?? '0') + 1))
        return 1
      }

      if (script.includes('legacy_count ~= tonumber(ARGV[1])')) {
        const legacyKey = parts[3] ?? ''
        const recordKey = parts[4] ?? ''
        const revisionKey = parts[5] ?? ''
        const mutationKey = parts[6] ?? ''
        const expectedLegacy = Number(parts[7])
        const expectedCurrent = Number(parts[8])
        const expectedMutation = Number(parts[9])
        if (
          listLength(legacyKey) !== expectedLegacy ||
          hashLength(recordKey) !== expectedCurrent ||
          Number(data.get(mutationKey) ?? '0') !== expectedMutation
        ) {
          return 0
        }
        data.delete(legacyKey)
        data.delete(recordKey)
        data.delete(revisionKey)
        data.set(mutationKey, String(Number(data.get(mutationKey) ?? '0') + 1))
        return 1
      }
      throw new Error('未対応のsurvey EVAL')
    }
    switch (rawOp?.toUpperCase()) {
      case 'LLEN':
        return listLength(key)
      case 'RPUSH':
        return list(key).push(...args)
      case 'LRANGE': {
        const rows = data.has(key) ? list(key) : []
        const start = Number(args[0] ?? 0)
        const rawEnd = Number(args[1] ?? -1)
        const end = rawEnd < 0 ? rows.length : rawEnd + 1
        return rows.slice(start, end)
      }
      case 'HLEN':
        return hashLength(key)
      case 'HVALS': {
        const current = data.get(key)
        return current === undefined ? [] : Object.values(hash(key).entries)
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
    const state = readFileSync(
      new URL('../public/survey/state.js', import.meta.url),
      'utf8',
    )

    for (const [name, html] of [
      ['misconception', rika],
      ['type', type],
    ] as const) {
      assert.match(html, /const ENDPOINT = ["']\/api\/survey["'];/, name)
      assert.match(html, /<script src=["']\.\.\/state\.js["']><\/script>/, name)
      assert.match(html, /SurveyState\.getSessionId\(SURVEY_KIND\)/, name)
      assert.doesNotMatch(html, /\/api\/submit/, name)
    }
    assert.match(state, /crypto\.randomUUID/)
    assert.match(state, /crypto\.getRandomValues/)
    assert.doesNotMatch(
      state,
      /\b(?:response|receipt|answer|ans|email|name)\b/i,
    )

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

  it('調査別の匿名sessionと完了flagだけを保持し、campaign resetを限定する', () => {
    const source = readFileSync(
      new URL('../public/survey/state.js', import.meta.url),
      'utf8',
    )
    const stored = new Map<string, string>([
      ['unrelated', 'keep'],
      ['dekisugi:survey:2026-08-v1:type:session', 'broken-session'],
    ])
    const generated = [SESSION_A, SESSION_B]
    const window = {
      crypto: {
        randomUUID: () => generated.shift(),
      },
      localStorage: {
        getItem: (key: string) => stored.get(key) ?? null,
        setItem: (key: string, value: string) => stored.set(key, value),
        removeItem: (key: string) => stored.delete(key),
      },
    } as {
      SurveyState?: {
        getSessionId(kind: string): string
        isComplete(kind: string): boolean
        markComplete(kind: string): void
        resetCampaign(): void
        otherKind(kind: string): string
      }
      crypto: { randomUUID(): string | undefined }
      localStorage: {
        getItem(key: string): string | null
        setItem(key: string, value: string): void
        removeItem(key: string): void
      }
    }
    runInNewContext(source, { window, Uint8Array, Math })
    const state = window.SurveyState
    assert.ok(state)

    assert.equal(state.getSessionId('misconception'), SESSION_A)
    assert.equal(state.getSessionId('misconception'), SESSION_A)
    assert.equal(state.getSessionId('type'), SESSION_B)
    assert.equal(state.otherKind('misconception'), 'type')
    assert.equal(state.otherKind('type'), 'misconception')
    assert.equal(state.isComplete('misconception'), false)
    state.markComplete('misconception')
    assert.equal(state.isComplete('misconception'), true)
    assert.equal(state.isComplete('type'), false)

    assert.deepEqual([...stored.keys()].sort(), [
      'dekisugi:survey:2026-08-v1:misconception:complete',
      'dekisugi:survey:2026-08-v1:misconception:session',
      'dekisugi:survey:2026-08-v1:type:session',
      'unrelated',
    ])
    state.resetCampaign()
    assert.deepEqual([...stored.entries()], [['unrelated', 'keep']])
  })

  it('localStorageが使えなくてもページ遷移後までsessionと完了状態を維持する', () => {
    const source = readFileSync(
      new URL('../public/survey/state.js', import.meta.url),
      'utf8',
    )
    const generated = [SESSION_A, SESSION_B]
    const sessionStored = new Map<string, string>([['unrelated', 'keep']])
    function pageWindow() {
      return {
        crypto: { randomUUID: () => generated.shift() },
        localStorage: {
          getItem: () => {
            throw new Error('blocked')
          },
          setItem: () => {
            throw new Error('blocked')
          },
          removeItem: () => {
            throw new Error('blocked')
          },
        },
        sessionStorage: {
          getItem: (key: string) => sessionStored.get(key) ?? null,
          setItem: (key: string, value: string) =>
            sessionStored.set(key, value),
          removeItem: (key: string) => sessionStored.delete(key),
        },
      }
    }
    type SurveyWindow = ReturnType<typeof pageWindow> & {
      SurveyState?: {
        getSessionId(kind: string): string
        isComplete(kind: string): boolean
        markComplete(kind: string): void
        resetCampaign(): void
      }
    }
    const first = pageWindow() as SurveyWindow
    runInNewContext(source, { window: first, Uint8Array, Math })
    assert.ok(first.SurveyState)
    assert.equal(first.SurveyState.getSessionId('misconception'), SESSION_A)
    first.SurveyState.markComplete('misconception')

    const second = pageWindow() as SurveyWindow
    runInNewContext(source, { window: second, Uint8Array, Math })
    assert.ok(second.SurveyState)
    assert.equal(second.SurveyState.getSessionId('misconception'), SESSION_A)
    assert.equal(second.SurveyState.isComplete('misconception'), true)
    assert.equal(second.SurveyState.getSessionId('type'), SESSION_B)
    second.SurveyState.resetCampaign()
    assert.deepEqual([...sessionStored.entries()], [['unrelated', 'keep']])
  })

  it('送信200後だけ完了にし、残りの調査へ明示CTAで案内する', () => {
    const rika = readFileSync(
      new URL('../public/survey/rika/index.html', import.meta.url),
      'utf8',
    )
    const type = readFileSync(
      new URL('../public/survey/type/index.html', import.meta.url),
      'utf8',
    )

    for (const [html, destination] of [
      [rika, '/survey/type/'],
      [type, '/survey/rika/'],
    ] as const) {
      assert.match(
        html,
        /if \(r\.status !== 200\) throw[\s\S]*?SurveyState\.markComplete\(SURVEY_KIND\)/,
      )
      assert.match(html, /SurveyState\.isComplete\(SURVEY_KIND\)/)
      assert.match(html, /SurveyState\.isComplete\(OTHER_KIND\)/)
      assert.match(html, /--on-accent\s*:\s*#12161d/i)
      assert.match(html, /color\s*:\s*var\(--on-accent\)/)
      assert.match(
        html,
        /id=["']send-status["'][^>]*role=["']status["'][^>]*aria-live=["']polite["']/,
      )
      assert.match(html, new RegExp(`href=["']${destination}["']`))
      assert.match(html, /残りのアンケートにもご協力ください/)
      assert.match(html, /2つのアンケートは両方とも回答済みです/)
      assert.doesNotMatch(html, /location\.(?:assign|replace)\s*\(/)
      assert.doesNotMatch(
        html,
        /setTimeout\s*\([^)]*(?:survey\/rika|survey\/type)/,
      )
    }
    assert.match(
      rika.replace(/\s+/g, ''),
      /if\(navigator\.sendBeacon\(ENDPOINT,newBlob\(\[body\],\{type:"application\/json"\}\)\)\)return;/,
    )
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
          ) &&
          parts[1]?.includes(
            `redis.call('EXPIRE', KEYS[2], ${SURVEY_IDLE_RETENTION_SECONDS})`,
          ) &&
          parts[1]?.includes(
            `redis.call('EXPIRE', KEYS[3], ${SURVEY_IDLE_RETENTION_SECONDS})`,
          ) &&
          parts[1]?.includes(
            `redis.call('EXPIRE', KEYS[4], ${SURVEY_IDLE_RETENTION_SECONDS})`,
          ),
      ),
      'legacy listとsession hashへ保存と同じLua内で90日idle TTLを設定する',
    )
  })

  it('理科の途中送信と完了送信を同じsessionの1件へまとめる', async () => {
    const store = useSurveyKv()
    restoreKv = store.restore
    const full = answer()

    for (let count = 1; count <= full.ans.length; count++) {
      const progress = fakeRes()
      await survey(
        {
          method: 'POST',
          body: answer({ done: false, ans: full.ans.slice(0, count) }),
        },
        progress.res,
      )
      assert.equal(progress.out.code, 200, `途中${count}問`)
    }
    const completed = fakeRes()
    await survey({ method: 'POST', body: full }, completed.res)
    assert.equal(completed.out.code, 200)

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
    const body = fetched.out.body as {
      count: number
      responses: string[]
    }
    assert.equal(body.count, 1)
    assert.equal(body.responses.length, 1)
    assert.deepEqual(JSON.parse(body.responses[0]!), full)
  })

  it('完了後に古いsendBeaconが届いても巻き戻さず同じreceiptを返す', async () => {
    const store = useSurveyKv()
    restoreKv = store.restore
    const completed = fakeRes()
    await survey({ method: 'POST', body: answer() }, completed.res)
    assert.equal(completed.out.code, 200)
    const receipt = (completed.out.body as { receipt: string }).receipt

    const lateProgress = fakeRes()
    await survey(
      {
        method: 'POST',
        body: answer({ done: false, ans: answer().ans.slice(0, 2) }),
      },
      lateProgress.res,
    )
    assert.equal(lateProgress.out.code, 200)
    assert.equal(
      (lateProgress.out.body as { receipt: string }).receipt,
      receipt,
    )

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
    const rows = (fetched.out.body as { responses: string[] }).responses
    assert.equal(rows.length, 1)
    assert.deepEqual(JSON.parse(rows[0]!), answer())
  })

  it('文字調査の同一送信は1件・同じreceipt、別sessionは別件にする', async () => {
    const store = useSurveyKv()
    restoreKv = store.restore

    const first = fakeRes()
    await survey({ method: 'POST', body: typeAnswer() }, first.res)
    const retry = fakeRes()
    await survey({ method: 'POST', body: typeAnswer() }, retry.res)
    assert.equal(first.out.code, 200)
    assert.equal(retry.out.code, 200)
    assert.equal(
      (retry.out.body as { receipt: string }).receipt,
      (first.out.body as { receipt: string }).receipt,
    )

    const otherSession = fakeRes()
    await survey(
      {
        method: 'POST',
        body: typeAnswer({ sessionId: SESSION_A }),
      },
      otherSession.res,
    )
    assert.equal(otherSession.out.code, 200)

    process.env.SURVEY_ADMIN_TOKEN = 'ほんもの'
    const count = fakeRes()
    await survey(
      {
        method: 'GET',
        query: { kind: 'type', countOnly: '1' },
        headers: { authorization: 'Bearer ほんもの' },
      },
      count.res,
    )
    assert.deepEqual(count.out.body, { kind: 'type', count: 2 })
  })

  it('同じsession・同じ進捗順位の内容違いは先着を維持する', async () => {
    const store = useSurveyKv()
    restoreKv = store.restore
    const firstBody = typeAnswer()
    const changedBody = typeAnswer({
      meta: {
        grade: '中学3年',
        light: '明るい',
        scale: '大きくしている',
      },
    })

    const first = fakeRes()
    await survey({ method: 'POST', body: firstBody }, first.res)
    const changed = fakeRes()
    await survey({ method: 'POST', body: changedBody }, changed.res)
    assert.equal(first.out.code, 200)
    assert.equal(changed.out.code, 200)
    assert.equal(
      (changed.out.body as { receipt: string }).receipt,
      (first.out.body as { receipt: string }).receipt,
    )

    process.env.SURVEY_ADMIN_TOKEN = 'ほんもの'
    const fetched = fakeRes()
    await survey(
      {
        method: 'GET',
        query: { kind: 'type' },
        headers: { authorization: 'Bearer ほんもの' },
      },
      fetched.res,
    )
    const rows = (fetched.out.body as { responses: string[] }).responses
    assert.deepEqual(JSON.parse(rows[0]!), firstBody)
  })

  it('保存上限到達後も既存sessionの完了更新だけは通す', async () => {
    const store = useSurveyKv()
    restoreKv = store.restore
    const full = answer()
    const initial = fakeRes()
    await survey(
      {
        method: 'POST',
        body: answer({ done: false, ans: full.ans.slice(0, 1) }),
      },
      initial.res,
    )
    assert.equal(initial.out.code, 200)
    store.data.set(
      'survey:misconception',
      Array.from({ length: MAX_RESPONSES - 1 }, (_, index) =>
        JSON.stringify({ v: 2, legacy: index }),
      ),
    )

    const upgraded = fakeRes()
    await survey({ method: 'POST', body: full }, upgraded.res)
    assert.equal(upgraded.out.code, 200)

    const newSession = fakeRes()
    await survey(
      {
        method: 'POST',
        body: answer({ sessionId: SESSION_B }),
      },
      newSession.res,
    )
    assert.equal(newSession.out.code, 503)
    assert.deepEqual(newSession.out.body, { error: 'full' })
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

    const rows: string[] = []
    store.data.set('survey:misconception', rows)
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
    assert.equal(rows.length, 1)
    const current = store.data.get('survey:misconception:by-session:v1')
    assert.ok(
      current &&
        typeof current === 'object' &&
        !Array.isArray(current) &&
        current.type === 'hash',
    )
    assert.equal(Object.keys(current.entries).length, 1)
  })

  it('件数が同じでもsnapshot後の途中回答更新を全削除へ巻き込まない', async () => {
    const store = useSurveyKv()
    restoreKv = store.restore
    const full = answer()
    const progress = fakeRes()
    await survey(
      {
        method: 'POST',
        body: { ...full, done: false, ans: full.ans.slice(0, 1) },
      },
      progress.res,
    )
    assert.equal(progress.out.code, 200)

    const storeFetch = globalThis.fetch
    let raced = false
    globalThis.fetch = (async (input: unknown, init?: { body?: string }) => {
      const commands = JSON.parse(init?.body ?? '[]') as string[][]
      if (
        !raced &&
        commands.some((parts) =>
          parts[1]?.includes('legacy_count ~= tonumber(ARGV[1])'),
        )
      ) {
        raced = true
        const records = store.data.get(
          'survey:misconception:by-session:v1',
        ) as KvHash
        const revisions = store.data.get(
          'survey:misconception:revision:v1',
        ) as KvHash
        const field = Object.keys(records.entries)[0]!
        const wrapper = JSON.parse(records.entries[field]!) as {
          response: unknown
        }
        wrapper.response = full
        records.entries[field] = JSON.stringify(wrapper)
        revisions.entries[field] = '9'
        const mutationKey = 'survey:misconception:mutation:v1'
        store.data.set(
          mutationKey,
          String(Number(store.data.get(mutationKey) ?? '0') + 1),
        )
      }
      return storeFetch(input as never, init as never)
    }) as typeof fetch

    process.env.SURVEY_ADMIN_TOKEN = 'ほんもの'
    const removed = fakeRes()
    await survey(
      {
        method: 'DELETE',
        query: { kind: 'misconception', expect: '1' },
        headers: { authorization: 'Bearer ほんもの' },
      },
      removed.res,
    )
    assert.equal(raced, true)
    assert.deepEqual(removed.out.body, { error: 'count_mismatch', count: 1 })

    const fetched = fakeRes()
    await survey(
      {
        method: 'GET',
        query: { kind: 'misconception' },
        headers: { authorization: 'Bearer ほんもの' },
      },
      fetched.res,
    )
    const rows = (fetched.out.body as { responses: string[] }).responses
    assert.equal(rows.length, 1)
    assert.deepEqual(JSON.parse(rows[0]!), full)
  })

  it('並行clear後にmutation世代を再利用せず新着を古いclearから守る', async () => {
    const store = useSurveyKv()
    restoreKv = store.restore
    const first = fakeRes()
    await survey({ method: 'POST', body: answer() }, first.res)
    assert.equal(first.out.code, 200)

    const storeFetch = globalThis.fetch
    let staleClear: string[][] | undefined
    let delayed = false
    globalThis.fetch = (async (input: unknown, init?: { body?: string }) => {
      const commands = JSON.parse(init?.body ?? '[]') as string[][]
      if (
        !delayed &&
        commands.some((parts) =>
          parts[1]?.includes('legacy_count ~= tonumber(ARGV[1])'),
        )
      ) {
        delayed = true
        staleClear = commands
        return new Promise<Response>(() => {})
      }
      return storeFetch(input as never, init as never)
    }) as typeof fetch

    process.env.SURVEY_ADMIN_TOKEN = 'ほんもの'
    const oldClear = survey(
      {
        method: 'DELETE',
        query: { kind: 'misconception', expect: '1' },
        headers: { authorization: 'Bearer ほんもの' },
      },
      fakeRes().res,
    )
    await new Promise<void>((resolve) => setImmediate(resolve))
    assert.ok(staleClear)

    globalThis.fetch = storeFetch
    const activeClear = fakeRes()
    await survey(
      {
        method: 'DELETE',
        query: { kind: 'misconception', expect: '1' },
        headers: { authorization: 'Bearer ほんもの' },
      },
      activeClear.res,
    )
    assert.equal(activeClear.out.code, 200)

    const newSession = fakeRes()
    await survey(
      { method: 'POST', body: answer({ sessionId: SESSION_B }) },
      newSession.res,
    )
    assert.equal(newSession.out.code, 200)

    const staleResponse = await storeFetch('https://survey-kv.test/pipeline', {
      method: 'POST',
      body: JSON.stringify(staleClear),
    } as never)
    const staleResult = (await staleResponse.json()) as Array<{
      result: unknown
    }>
    assert.equal(staleResult[0]?.result, 0)
    void oldClear

    const fetched = fakeRes()
    await survey(
      {
        method: 'GET',
        query: { kind: 'misconception' },
        headers: { authorization: 'Bearer ほんもの' },
      },
      fetched.res,
    )
    const rows = (fetched.out.body as { responses: string[] }).responses
    assert.equal(rows.length, 1)
    assert.equal(JSON.parse(rows[0]!).sessionId, SESSION_B)
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

  it('既存list回答と新しいsession hash回答を同じ管理exportで読める', async () => {
    const store = useSurveyKv()
    restoreKv = store.restore
    const legacy = JSON.stringify({
      v: 2,
      kind: 'misconception',
      sessionId: 'legacy-session',
      done: true,
      ans: [],
    })
    store.data.set('survey:misconception', [legacy])

    const posted = fakeRes()
    await survey({ method: 'POST', body: answer() }, posted.res)
    assert.equal(posted.out.code, 200)

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
    const body = fetched.out.body as {
      count: number
      responses: string[]
    }
    assert.equal(body.count, 2)
    assert.equal(body.responses[0], legacy)
    assert.deepEqual(JSON.parse(body.responses[1]!), answer())
  })

  it('既存listの途中保存と新hashをsession単位で最高進捗1件へ畳む', async () => {
    const store = useSurveyKv()
    restoreKv = store.restore
    const full = answer()
    const progress = (length: number, done = false) =>
      JSON.stringify({ ...full, done, ans: full.ans.slice(0, length) })
    const noSession = JSON.stringify({
      v: 1,
      kind: 'misconception',
      done: true,
      ans: [],
    })
    store.data.set('survey:misconception', [
      progress(1),
      progress(3),
      progress(4),
      progress(4, true),
      noSession,
    ])

    const posted = fakeRes()
    await survey({ method: 'POST', body: full }, posted.res)
    assert.equal(posted.out.code, 200)

    process.env.SURVEY_ADMIN_TOKEN = 'ほんもの'
    const countOnly = fakeRes()
    await survey(
      {
        method: 'GET',
        query: { kind: 'misconception', countOnly: '1' },
        headers: { authorization: 'Bearer ほんもの' },
      },
      countOnly.res,
    )
    assert.deepEqual(countOnly.out.body, { kind: 'misconception', count: 2 })

    const fetched = fakeRes()
    await survey(
      {
        method: 'GET',
        query: { kind: 'misconception' },
        headers: { authorization: 'Bearer ほんもの' },
      },
      fetched.res,
    )
    const body = fetched.out.body as { count: number; responses: string[] }
    assert.equal(body.count, 2)
    assert.ok(
      body.responses.some(
        (row) => JSON.stringify(JSON.parse(row)) === JSON.stringify(full),
      ),
    )
    assert.ok(body.responses.includes(noSession))
  })

  it('全削除のexpectは旧重複を除いた管理件数で照合する', async () => {
    const store = useSurveyKv()
    restoreKv = store.restore
    const full = answer()
    store.data.set('survey:misconception', [
      JSON.stringify({ ...full, done: false, ans: full.ans.slice(0, 1) }),
      JSON.stringify({ ...full, done: false }),
      JSON.stringify(full),
    ])

    process.env.SURVEY_ADMIN_TOKEN = 'ほんもの'
    const removed = fakeRes()
    await survey(
      {
        method: 'DELETE',
        query: { kind: 'misconception', expect: '1' },
        headers: { authorization: 'Bearer ほんもの' },
      },
      removed.res,
    )
    assert.deepEqual(removed.out.body, { ok: true, removed: 1 })
    assert.equal(store.data.has('survey:misconception'), false)
  })
})
