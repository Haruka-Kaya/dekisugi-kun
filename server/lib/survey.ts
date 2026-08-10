import { createHash, randomBytes } from 'node:crypto'

import { hasKv, kv } from './kv.js'

/** 受け付けるアンケートの種類。知らない種類は保存しない。 */
export const SURVEY_KINDS = ['misconception', 'type'] as const
export type SurveyKind = (typeof SURVEY_KINDS)[number]

/** 自由記述を含めても十分な上限。上限判定はschema検証より先に行う。 */
export const MAX_BYTES = 64 * 1024

/** 種類ごとの保存上限。Luaで判定と追加を1回にまとめる。 */
export const MAX_RESPONSES = 5000

/** 調査終了後に回答一覧を残し続けない。最後の新着から90日でRedis keyごと失効。 */
export const SURVEY_IDLE_RETENTION_SECONDS = 90 * 24 * 60 * 60

/** 同じ匿名sessionが1時間に送れる件数。理科は進捗4回+完了1回。 */
export const MAX_RESPONSES_PER_SESSION_HOUR = 12

/** UUIDを取り替える連投でも保存先全体を短時間で埋められない上限。 */
export const MAX_SURVEY_RESPONSES_PER_HOUR = 240

const GRADE = [
  '中学1年',
  '中学2年',
  '中学3年',
  '高校1年',
  '高校2年',
  '高校3年',
  'その他',
] as const
const LIKE = ['好き', 'ふつう', '苦手'] as const
const LEARNED = ['習った', 'まだ', 'おぼえてない'] as const
const LIGHT = ['明るい', 'ふつう', '暗い'] as const
const SCALE = [
  '標準のまま',
  '大きくしている',
  '小さくしている',
  'わからない',
] as const
const GROUND_TRUTH = [
  'understood',
  'misconception',
  'inconsistent',
  'other',
] as const
const LH = [1.45, 1.6, 1.75, 1.9] as const
const LS = [0, 0.02, 0.04] as const
const TYPE_TEXT_KEYS = ['sci1', 'soc1', 'sci2'] as const

const MISCONCEPTION_ITEMS = {
  M01: { topic: '落下', correct: 2, trap: 0, correct2: 2, trap2: 0 },
  M02: { topic: '慣性', correct: 1, trap: 0, correct2: 1, trap2: 0 },
  M03: { topic: '摩擦と静止', correct: 2, trap: 0, correct2: 2, trap2: 3 },
  M04: { topic: '作用・反作用', correct: 2, trap: 0, correct2: 2, trap2: 0 },
  M05: { topic: '力のつり合い', correct: 1, trap: 0, correct2: 1, trap2: 0 },
  M06: { topic: '圧力', correct: 2, trap: 0, correct2: 1, trap2: 0 },
  M07: { topic: '浮力', correct: 2, trap: 0, correct2: 1, trap2: 0 },
  M08: { topic: '投げ上げ', correct: 1, trap: 0, correct2: 1, trap2: 0 },
} as const

type JsonObject = Record<string, unknown>

export type AnonymousSurveyResponse = JsonObject & {
  v: 3
  kind: SurveyKind
  sessionId: string
}

export type SurveyValidationResult =
  | { ok: true; response: AnonymousSurveyResponse }
  | { ok: false; error: 'invalid_schema' | 'personal_information' }

export function isSurveyKind(value: unknown): value is SurveyKind {
  return (
    typeof value === 'string' &&
    (SURVEY_KINDS as readonly string[]).includes(value)
  )
}

/**
 * 匿名アンケートだけの明示的なproduction switch。
 *
 * 学校Team・生成AI・RevenueCatのguardとは共有しない。匿名回答を開けても、
 * それらの外部処理が一緒に開かないことをコード境界で保つ。
 */
export function anonymousSurveyEnabled(): boolean {
  return process.env.DEKISUGI_ANONYMOUS_SURVEY_ENABLED === '1'
}

function objectOf(value: unknown): JsonObject | undefined {
  if (!value || typeof value !== 'object' || Array.isArray(value))
    return undefined
  return value as JsonObject
}

function exactKeys(value: JsonObject, expected: readonly string[]): boolean {
  const actual = Object.keys(value).sort()
  const sortedExpected = [...expected].sort()
  return (
    actual.length === sortedExpected.length &&
    actual.every((key, i) => key === sortedExpected[i])
  )
}

function oneOf<T extends readonly unknown[]>(
  value: unknown,
  allowed: T,
): value is T[number] {
  return allowed.includes(value)
}

function intIn(value: unknown, min: number, max: number): value is number {
  return Number.isInteger(value) && Number(value) >= min && Number(value) <= max
}

function bool(value: unknown): value is boolean {
  return typeof value === 'boolean'
}

function normalizedText(
  value: unknown,
  min: number,
  max: number,
): string | undefined {
  if (typeof value !== 'string') return undefined
  const text = value.normalize('NFC').replace(/\r\n?/g, '\n').trim()
  if (text.length < min || text.length > max) return undefined
  return text
}

/** 明らかな連絡先だけは保存前に拒否する。自由記述は科学の説明だけを求める。 */
function containsPersonalContact(text: string): boolean {
  return (
    /(?:https?:\/\/|www\.)/iu.test(text) ||
    /[\p{L}\p{N}._%+-]+@[\p{L}\p{N}.-]+\.[\p{L}]{2,}/iu.test(text) ||
    /@[a-z0-9_]{2,}/iu.test(text) ||
    /(?:\d[\s()\-ー]*){9,}/u.test(text)
  )
}

function isUuid(value: unknown): value is string {
  return (
    typeof value === 'string' &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/iu.test(
      value,
    )
  )
}

function sameNumberArray(value: unknown, expected: readonly number[]): boolean {
  return (
    Array.isArray(value) &&
    value.length === expected.length &&
    value.every((item, i) => item === expected[i])
  )
}

function validateMisconception(body: JsonObject): SurveyValidationResult {
  if (!exactKeys(body, ['v', 'kind', 'sessionId', 'done', 'meta', 'ans'])) {
    return { ok: false, error: 'invalid_schema' }
  }
  if (
    body.v !== 3 ||
    body.kind !== 'misconception' ||
    !isUuid(body.sessionId) ||
    !bool(body.done)
  ) {
    return { ok: false, error: 'invalid_schema' }
  }

  const meta = objectOf(body.meta)
  if (
    !meta ||
    !exactKeys(meta, ['grade', 'like']) ||
    !oneOf(meta.grade, GRADE) ||
    !oneOf(meta.like, LIKE)
  ) {
    return { ok: false, error: 'invalid_schema' }
  }

  if (!Array.isArray(body.ans) || body.ans.length < 1 || body.ans.length > 4) {
    return { ok: false, error: 'invalid_schema' }
  }
  if (body.done && body.ans.length !== 4)
    return { ok: false, error: 'invalid_schema' }

  const ids = new Set<string>()
  const answers: JsonObject[] = []
  for (const raw of body.ans) {
    const answer = objectOf(raw)
    if (
      !answer ||
      !exactKeys(answer, [
        'id',
        'topic',
        'explain',
        'explainMs',
        'lureReply',
        'lureMs',
        'pick',
        'pickPos',
        'pick2',
        'pickPos2',
        'learned',
        'mcMs',
        'correct',
        'heldMisconception',
        'groundTruth',
        'correct1',
        'heldMisconception1',
      ])
    ) {
      return { ok: false, error: 'invalid_schema' }
    }

    const item =
      typeof answer.id === 'string'
        ? MISCONCEPTION_ITEMS[answer.id as keyof typeof MISCONCEPTION_ITEMS]
        : undefined
    const explain = normalizedText(answer.explain, 5, 1200)
    const lureReply = normalizedText(answer.lureReply, 2, 1200)
    if (
      !item ||
      ids.has(String(answer.id)) ||
      answer.topic !== item.topic ||
      explain == null ||
      lureReply == null ||
      !intIn(answer.explainMs, 0, 3_600_000) ||
      !intIn(answer.lureMs, 0, 3_600_000) ||
      !intIn(answer.pick, 0, 3) ||
      !intIn(answer.pickPos, 0, 3) ||
      !intIn(answer.pick2, 0, 3) ||
      !intIn(answer.pickPos2, 0, 3) ||
      !oneOf(answer.learned, LEARNED) ||
      !intIn(answer.mcMs, 0, 3_600_000) ||
      !bool(answer.correct) ||
      !bool(answer.heldMisconception) ||
      !oneOf(answer.groundTruth, GROUND_TRUTH) ||
      !bool(answer.correct1) ||
      !bool(answer.heldMisconception1)
    ) {
      return { ok: false, error: 'invalid_schema' }
    }
    if (
      containsPersonalContact(explain) ||
      containsPersonalContact(lureReply)
    ) {
      return { ok: false, error: 'personal_information' }
    }

    const correct1 = answer.pick === item.correct
    const correct2 = answer.pick2 === item.correct2
    const trap1 = answer.pick === item.trap
    const trap2 = answer.pick2 === item.trap2
    const correct = correct1 && correct2
    const heldMisconception = trap1 && trap2
    const groundTruth = correct
      ? 'understood'
      : heldMisconception
        ? 'misconception'
        : correct1 !== correct2 || trap1 !== trap2
          ? 'inconsistent'
          : 'other'
    if (
      answer.correct1 !== correct1 ||
      answer.heldMisconception1 !== trap1 ||
      answer.correct !== correct ||
      answer.heldMisconception !== heldMisconception ||
      answer.groundTruth !== groundTruth
    ) {
      return { ok: false, error: 'invalid_schema' }
    }

    ids.add(String(answer.id))
    answers.push({ ...answer, explain, lureReply })
  }

  return {
    ok: true,
    response: {
      v: 3,
      kind: 'misconception',
      sessionId: body.sessionId,
      done: body.done,
      meta: { grade: meta.grade, like: meta.like },
      ans: answers,
    },
  }
}

function styleOf(value: unknown): { lh: number; ls: number } | undefined {
  const style = objectOf(value)
  if (
    !style ||
    !exactKeys(style, ['lh', 'ls']) ||
    typeof style.lh !== 'number' ||
    typeof style.ls !== 'number'
  ) {
    return undefined
  }
  return { lh: style.lh, ls: style.ls }
}

type SurveyStyle = { lh: number; ls: number }

function styleKey(style: SurveyStyle): string {
  return `${style.lh}:${style.ls}`
}

function sameStyle(a: SurveyStyle, b: SurveyStyle): boolean {
  return a.lh === b.lh && a.ls === b.ls
}

function trialKey(
  dimension: 'lh' | 'ls' | 'catch',
  a: SurveyStyle,
  b: SurveyStyle,
): string {
  return `${dimension}:${[styleKey(a), styleKey(b)].sort().join('|')}`
}

/** public HTMLが作る総当たり10組。値だけでなく提示の左右反転も検証する。 */
const TYPE_TRIALS = (() => {
  const trials = new Map<string, readonly [SurveyStyle, SurveyStyle]>()
  const addPairs = (
    dimension: 'lh' | 'ls',
    values: readonly number[],
    style: (value: number) => SurveyStyle,
  ) => {
    for (let i = 0; i < values.length; i++) {
      for (let j = i + 1; j < values.length; j++) {
        const pair = [style(values[i]!), style(values[j]!)] as const
        trials.set(trialKey(dimension, pair[0], pair[1]), pair)
      }
    }
  }
  addPairs('lh', LH, (lh) => ({ lh, ls: 0 }))
  addPairs('ls', LS, (ls) => ({ lh: 1.75, ls }))
  const attention = [
    { lh: 1, ls: 0 },
    { lh: 1.75, ls: 0 },
  ] as const
  trials.set(trialKey('catch', attention[0], attention[1]), attention)
  return trials
})()

function validateTypeSurvey(body: JsonObject): SurveyValidationResult {
  if (!exactKeys(body, ['v', 'kind', 'sessionId', 'meta', 'lh', 'ls', 'ans'])) {
    return { ok: false, error: 'invalid_schema' }
  }
  if (
    body.v !== 3 ||
    body.kind !== 'type' ||
    !isUuid(body.sessionId) ||
    !sameNumberArray(body.lh, LH) ||
    !sameNumberArray(body.ls, LS)
  ) {
    return { ok: false, error: 'invalid_schema' }
  }

  const meta = objectOf(body.meta)
  if (
    !meta ||
    !exactKeys(meta, ['grade', 'light', 'scale']) ||
    !oneOf(meta.grade, GRADE) ||
    !oneOf(meta.light, LIGHT) ||
    !oneOf(meta.scale, SCALE)
  ) {
    return { ok: false, error: 'invalid_schema' }
  }
  if (!Array.isArray(body.ans) || body.ans.length !== 10) {
    return { ok: false, error: 'invalid_schema' }
  }

  const indices = new Set<number>()
  const trialKeys = new Set<string>()
  const dimensionCounts = { lh: 0, ls: 0, catch: 0 }
  const answers: JsonObject[] = []
  for (const raw of body.ans) {
    const answer = objectOf(raw)
    if (
      !answer ||
      !exactKeys(answer, [
        'i',
        'd',
        'pick',
        'other',
        'side',
        'flip',
        'tx',
        'ms',
      ]) ||
      !intIn(answer.i, 0, 9) ||
      indices.has(Number(answer.i)) ||
      !oneOf(answer.d, ['lh', 'ls', 'catch'] as const) ||
      !oneOf(answer.side, ['a', 'b'] as const) ||
      !oneOf(answer.flip, [0, 1] as const) ||
      !oneOf(answer.tx, ['sci1', 'soc1', 'sci2'] as const) ||
      answer.tx !== TYPE_TEXT_KEYS[Number(answer.i) % TYPE_TEXT_KEYS.length] ||
      !intIn(answer.ms, 0, 600_000)
    ) {
      return { ok: false, error: 'invalid_schema' }
    }
    const pick = styleOf(answer.pick)
    const other = styleOf(answer.other)
    if (!pick || !other || (pick.lh === other.lh && pick.ls === other.ls)) {
      return { ok: false, error: 'invalid_schema' }
    }
    const pair = [pick, other]
    const validPair =
      answer.d === 'lh'
        ? pair.every((style) => oneOf(style.lh, LH) && style.ls === 0)
        : answer.d === 'ls'
          ? pair.every((style) => style.lh === 1.75 && oneOf(style.ls, LS))
          : pair.every(
              (style) =>
                (style.lh === 1 && style.ls === 0) ||
                (style.lh === 1.75 && style.ls === 0),
            )
    if (!validPair) return { ok: false, error: 'invalid_schema' }

    const key = trialKey(answer.d, pick, other)
    const canonicalPair = TYPE_TRIALS.get(key)
    if (!canonicalPair || trialKeys.has(key)) {
      return { ok: false, error: 'invalid_schema' }
    }
    const shownA = answer.side === 'a' ? pick : other
    const shownB = answer.side === 'a' ? other : pick
    const expectedA = answer.flip === 0 ? canonicalPair[0] : canonicalPair[1]
    const expectedB = answer.flip === 0 ? canonicalPair[1] : canonicalPair[0]
    if (!sameStyle(shownA, expectedA) || !sameStyle(shownB, expectedB)) {
      return { ok: false, error: 'invalid_schema' }
    }

    indices.add(Number(answer.i))
    trialKeys.add(key)
    dimensionCounts[answer.d]++
    answers.push({ ...answer, pick, other })
  }
  if (
    dimensionCounts.lh !== 6 ||
    dimensionCounts.ls !== 3 ||
    dimensionCounts.catch !== 1 ||
    trialKeys.size !== TYPE_TRIALS.size
  ) {
    return { ok: false, error: 'invalid_schema' }
  }

  return {
    ok: true,
    response: {
      v: 3,
      kind: 'type',
      sessionId: body.sessionId,
      meta: { grade: meta.grade, light: meta.light, scale: meta.scale },
      lh: [...LH],
      ls: [...LS],
      ans: answers,
    },
  }
}

/** 未知fieldを落として保存するのではなく、入力自体を拒否する。 */
export function validateAnonymousSurveyResponse(
  body: unknown,
): SurveyValidationResult {
  const object = objectOf(body)
  if (!object || !isSurveyKind(object.kind))
    return { ok: false, error: 'invalid_schema' }
  return object.kind === 'misconception'
    ? validateMisconception(object)
    : validateTypeSurvey(object)
}

const listKey = (kind: SurveyKind) => `survey:${kind}`

export type SaveResult =
  { ok: true; receipt: string } | { ok: false; reason: 'no_store' | 'full' }

function newReceipt(): string {
  return `sr_${randomBytes(18).toString('base64url')}`
}

export function isSurveyReceipt(value: unknown): value is string {
  return typeof value === 'string' && /^sr_[A-Za-z0-9_-]{24}$/.test(value)
}

/** 1件を原子的に上限確認して保存する。保存できたときだけreceiptを返す。 */
export async function saveResponse(
  kind: SurveyKind,
  responseJson: string,
): Promise<SaveResult> {
  if (!hasKv()) return { ok: false, reason: 'no_store' }

  const receipt = newReceipt()
  const record = JSON.stringify({
    schemaVersion: 1,
    receipt,
    receivedAt: new Date().toISOString(),
    response: JSON.parse(responseJson) as unknown,
  })
  const script = [
    "local n = redis.call('LLEN', KEYS[1])",
    `if n >= ${MAX_RESPONSES} then return -1 end`,
    "local added = redis.call('RPUSH', KEYS[1], ARGV[1])",
    `redis.call('EXPIRE', KEYS[1], ${SURVEY_IDLE_RETENTION_SECONDS})`,
    'return added',
  ].join(' ')
  const [count] = await kv([['EVAL', script, '1', listKey(kind), record]])
  if (count === -1) return { ok: false, reason: 'full' }
  if (
    typeof count !== 'number' ||
    !Number.isSafeInteger(count) ||
    count < 1 ||
    count > MAX_RESPONSES
  ) {
    throw new Error('アンケート保存結果が不正です')
  }
  return { ok: true, receipt }
}

/** 保存されているraw行。receipt削除だけがwrapperを直接扱う。 */
async function listStoredRows(kind: SurveyKind): Promise<string[]> {
  if (!hasKv()) return []
  const [rows] = await kv([['LRANGE', listKey(kind), '0', '-1']])
  if (!Array.isArray(rows) || rows.some((row) => typeof row !== 'string')) {
    throw new Error('アンケート保存行の形式が不正です')
  }
  return rows as string[]
}

/**
 * 集計用の既存契約を維持し、新wrapperはtop-level response JSONへ戻して返す。
 * これによりfetch-survey.ps1と既存analyzerは旧回答と新回答を同時に読める。
 */
export async function listResponses(kind: SurveyKind): Promise<string[]> {
  return (await listStoredRows(kind)).map((row) => {
    try {
      const parsed = JSON.parse(row) as {
        schemaVersion?: unknown
        response?: unknown
      }
      if (
        parsed.schemaVersion === 1 &&
        parsed.response &&
        typeof parsed.response === 'object'
      ) {
        return JSON.stringify(parsed.response)
      }
    } catch {
      // 旧回答や壊れた行は既存どおりrawで返し、集計側がskipできるようにする。
    }
    return row
  })
}

/** receiptに一致する新schemaの1件だけを削除する。本番疎通確認の片づけに使う。 */
export async function deleteResponseByReceipt(
  kind: SurveyKind,
  receipt: string,
): Promise<boolean> {
  if (!hasKv()) return false
  const row = (await listStoredRows(kind)).find((candidate) => {
    try {
      return (
        (JSON.parse(candidate) as { receipt?: unknown }).receipt === receipt
      )
    } catch {
      return false
    }
  })
  if (row == null) return false
  const [removed] = await kv([['LREM', listKey(kind), '1', row]])
  if (removed !== 0 && removed !== 1) {
    throw new Error('アンケート削除結果が不正です')
  }
  return removed === 1
}

export type ClearResponsesResult =
  { ok: true; removed: number } | { ok: false; count: number }

/** 件数照合と全削除を1つのLua commandにし、照合後の新着を巻き込まない。 */
export async function clearResponsesIfCount(
  kind: SurveyKind,
  expected: number,
): Promise<ClearResponsesResult> {
  if (!hasKv()) {
    return expected === 0 ? { ok: true, removed: 0 } : { ok: false, count: 0 }
  }
  const script = [
    "local n = redis.call('LLEN', KEYS[1])",
    'if n ~= tonumber(ARGV[1]) then return -n - 1 end',
    "redis.call('DEL', KEYS[1])",
    'return n',
  ].join(' ')
  const [result] = await kv([
    ['EVAL', script, '1', listKey(kind), String(expected)],
  ])
  if (typeof result !== 'number' || !Number.isSafeInteger(result)) {
    throw new Error('アンケート全削除結果が不正です')
  }
  return result >= 0
    ? { ok: true, removed: result }
    : { ok: false, count: -result - 1 }
}

export async function countResponses(kind: SurveyKind): Promise<number> {
  if (!hasKv()) return 0
  const [len] = await kv([['LLEN', listKey(kind)]])
  if (typeof len !== 'number' || !Number.isSafeInteger(len) || len < 0) {
    throw new Error('アンケート件数が不正です')
  }
  return len
}

/** IPを保存せず、session上限と全体burst上限の両方で連投を抑える。 */
export async function tooManyForSession(
  sessionId: string,
  now = Date.now(),
): Promise<boolean> {
  if (!hasKv()) return false
  const digest = createHash('sha256')
    .update(sessionId)
    .digest('base64url')
    .slice(0, 32)
  const key = `survey:session:${digest}:${Math.floor(now / 3_600_000)}`
  const globalKey = `survey:global:${Math.floor(now / 3_600_000)}`
  const script = [
    "local global_count = tonumber(redis.call('GET', KEYS[2]) or '0')",
    `if global_count >= ${MAX_SURVEY_RESPONSES_PER_HOUR} then return {-1, global_count} end`,
    "local session_count = redis.call('INCR', KEYS[1])",
    "if session_count == 1 then redis.call('EXPIRE', KEYS[1], 3600) end",
    `if session_count > ${MAX_RESPONSES_PER_SESSION_HOUR} then return {session_count, -1} end`,
    "global_count = redis.call('INCR', KEYS[2])",
    "if global_count == 1 then redis.call('EXPIRE', KEYS[2], 3600) end",
    'return {session_count, global_count}',
  ].join(' ')
  const [rate] = await kv([['EVAL', script, '2', key, globalKey]])
  if (
    !Array.isArray(rate) ||
    rate.length !== 2 ||
    typeof rate[0] !== 'number' ||
    !Number.isSafeInteger(rate[0]) ||
    (rate[0] < 1 && rate[0] !== -1) ||
    typeof rate[1] !== 'number' ||
    !Number.isSafeInteger(rate[1]) ||
    (rate[1] < 1 && rate[1] !== -1) ||
    (rate[0] === -1 && rate[1] < MAX_SURVEY_RESPONSES_PER_HOUR) ||
    (rate[1] === -1 && rate[0] <= MAX_RESPONSES_PER_SESSION_HOUR)
  ) {
    throw new Error('アンケートrate結果が不正です')
  }
  return (
    rate[0] === -1 ||
    rate[0] > MAX_RESPONSES_PER_SESSION_HOUR ||
    rate[1] > MAX_SURVEY_RESPONSES_PER_HOUR
  )
}
