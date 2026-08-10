import { header, queryOf, type Req, type Res } from '../lib/http.js'
import {
  MAX_BYTES,
  anonymousSurveyEnabled,
  clearResponsesIfCount,
  countResponses,
  deleteResponseByReceipt,
  isSurveyKind,
  isSurveyReceipt,
  listResponses,
  saveResponse,
  tooManyForSession,
  validateAnonymousSurveyResponse,
} from '../lib/survey.js'

type SurveyDependencies = {
  tooMany: typeof tooManyForSession
  save: typeof saveResponse
}

const defaultDependencies: SurveyDependencies = {
  tooMany: tooManyForSession,
  save: saveResponse,
}

/**
 * アンケートの回答を受け取る。ログインや端末登録は要求しない。
 *
 * 氏名・学校・連絡先を構造化fieldとして受け付けず、明示的な連絡先を含む自由記述も
 * 拒否する。IP・User-Agentは保存しない。kindごとのexact schemaへ正規化できた回答だけを
 * Upstashへ保存し、成功時は件数ではなくopaque receiptを返す。
 */
export async function handleSurvey(
  req: Req,
  res: Res,
  options: Partial<SurveyDependencies> = {},
): Promise<void> {
  res.setHeader('Cache-Control', 'no-store')
  if (!allowOrigin(req, res)) return

  if (req.method === 'OPTIONS') {
    res.status(204).json({})
    return
  }
  if (req.method === 'GET') return exportResponses(req, res)
  if (req.method === 'DELETE') return removeResponses(req, res)
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'GET, POST, DELETE, OPTIONS')
    res.status(405).json({ error: 'method_not_allowed' })
    return
  }

  // Team・生成AI・RevenueCatとは独立した匿名survey専用switch。
  if (!anonymousSurveyEnabled()) {
    res.status(503).json({ error: 'anonymous_survey_unavailable' })
    return
  }

  const parsedBody = parseBoundedJson(req.body)
  if (!parsedBody.ok) {
    res.status(parsedBody.status).json({ error: parsedBody.error })
    return
  }
  const validated = validateAnonymousSurveyResponse(parsedBody.value)
  if (!validated.ok) {
    res.status(400).json({ error: validated.error })
    return
  }

  const dependencies = { ...defaultDependencies, ...options }
  try {
    if (await dependencies.tooMany(validated.response.sessionId)) {
      res.status(429).json({ error: 'too_many' })
      return
    }
    const saved = await dependencies.save(
      validated.response.kind,
      JSON.stringify(validated.response),
    )
    if (!saved.ok) {
      // 200を返して実は消えている状態にしない。画面はfallback codeを表示する。
      res.status(503).json({ error: saved.reason })
      return
    }
    res.status(200).json({ ok: true, receipt: saved.receipt })
  } catch (error) {
    console.error('アンケートを保存できなかった', error)
    res.status(503).json({ error: 'store_failed' })
  }
}

export default async function handler(req: Req, res: Res): Promise<void> {
  await handleSurvey(req, res)
}

type ParsedBody =
  | { ok: true; value: unknown }
  | {
      ok: false
      status: 400 | 413
      error: 'invalid_json' | 'empty_body' | 'too_large'
    }

function parseBoundedJson(raw: unknown): ParsedBody {
  if (typeof raw === 'string') {
    if (Buffer.byteLength(raw, 'utf8') > MAX_BYTES) {
      return { ok: false, status: 413, error: 'too_large' }
    }
    try {
      const value = JSON.parse(raw) as unknown
      if (value == null) return { ok: false, status: 400, error: 'empty_body' }
      return { ok: true, value }
    } catch {
      return { ok: false, status: 400, error: 'invalid_json' }
    }
  }
  if (raw == null) return { ok: false, status: 400, error: 'empty_body' }
  try {
    const json = JSON.stringify(raw)
    if (json == null) return { ok: false, status: 400, error: 'invalid_json' }
    if (Buffer.byteLength(json, 'utf8') > MAX_BYTES) {
      return { ok: false, status: 413, error: 'too_large' }
    }
    return { ok: true, value: raw }
  } catch {
    return { ok: false, status: 400, error: 'invalid_json' }
  }
}

function allowedOrigins(): Set<string> {
  const origins = new Set(['https://rika-chousa.vercel.app'])
  const deployment = process.env.VERCEL_URL
  if (deployment && /^[a-z0-9.-]+\.vercel\.app$/i.test(deployment)) {
    origins.add(`https://${deployment}`)
  }
  for (const origin of (
    process.env.DEKISUGI_SURVEY_ALLOWED_ORIGINS ?? ''
  ).split(',')) {
    const trimmed = origin.trim()
    if (/^https:\/\/[a-z0-9.-]+(?::\d+)?$/i.test(trimmed)) origins.add(trimmed)
  }
  if (process.env.VERCEL_ENV !== 'production') {
    origins.add('http://localhost:3000')
    origins.add('http://127.0.0.1:3000')
  }
  return origins
}

/** ブラウザのcross-origin投稿はexact allowlist。Originなしの同一origin/CLIは許可する。 */
function allowOrigin(req: Req, res: Res): boolean {
  const origin = header(req, 'origin')
  res.setHeader('Vary', 'Origin')
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization')
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS')
  if (origin == null) return true
  if (!allowedOrigins().has(origin)) {
    res.status(403).json({ error: 'origin_not_allowed' })
    return false
  }
  res.setHeader('Access-Control-Allow-Origin', origin)
  return true
}

/** 管理トークン未設定時は、集計・削除経路を常に閉じる。 */
function isAdmin(req: Req): boolean {
  const expected = process.env.SURVEY_ADMIN_TOKEN
  const given = header(req, 'authorization')?.replace(/^Bearer\s+/i, '')
  return Boolean(expected) && given === expected
}

/** receipt指定なら1件だけ、指定なしなら既存の件数一致付き全削除。 */
async function removeResponses(req: Req, res: Res) {
  if (!isAdmin(req)) {
    res.status(401).json({ error: 'unauthorized' })
    return
  }
  const kind = queryOf(req, 'kind')
  if (!isSurveyKind(kind)) {
    res.status(400).json({ error: 'unknown_kind' })
    return
  }

  const receipt = queryOf(req, 'receipt')
  if (receipt != null) {
    if (!isSurveyReceipt(receipt)) {
      res.status(400).json({ error: 'invalid_receipt' })
      return
    }
    const removed = await deleteResponseByReceipt(kind, receipt)
    if (!removed) {
      res.status(404).json({ error: 'receipt_not_found' })
      return
    }
    res.status(200).json({ ok: true, removed: 1 })
    return
  }

  const expected = Number(queryOf(req, 'expect'))
  if (!Number.isInteger(expected) || expected < 0) {
    res
      .status(409)
      .json({ error: 'count_mismatch', count: await countResponses(kind) })
    return
  }
  const cleared = await clearResponsesIfCount(kind, expected)
  if (!cleared.ok) {
    res.status(409).json({ error: 'count_mismatch', count: cleared.count })
    return
  }
  res.status(200).json({ ok: true, removed: cleared.removed })
}

async function exportResponses(req: Req, res: Res) {
  if (!isAdmin(req)) {
    res.status(401).json({ error: 'unauthorized' })
    return
  }
  const kind = queryOf(req, 'kind')
  if (!isSurveyKind(kind)) {
    res.status(400).json({ error: 'unknown_kind' })
    return
  }
  if (queryOf(req, 'countOnly') === '1') {
    res.status(200).json({ kind, count: await countResponses(kind) })
    return
  }
  const rows = await listResponses(kind)
  res.setHeader('Cache-Control', 'no-store')
  res.status(200).json({ kind, count: rows.length, responses: rows })
}
