import { callerIp, header, queryOf, type Req, type Res } from '../lib/http.js'
import {
  MAX_BYTES,
  clearResponses,
  countResponses,
  isSurveyKind,
  listResponses,
  saveResponse,
  tooManyFrom,
} from '../lib/survey.js'

/**
 * アンケートの回答を受け取る。**認証しない。**
 *
 * 中高生がリンクを開いて答えるだけで終わるようにするのが目的なので、
 * ログインも端末登録も挟まない。代わりに
 * 種類・大きさ・件数・同一経路からの連投で締める。
 *
 * POST /api/survey        … 1件受け取る
 * GET  /api/survey?kind=… … 集計用に取り出す（**管理トークンが要る**）
 */



/** 呼び出し元。**特定のためではなく連投を抑えるためだけに使う。** */


export default async function handler(req: Req, res: Res) {
  // アンケートは別オリジンから開かれることもある（配布のしかたを縛らない）
  res.setHeader('Access-Control-Allow-Origin', '*')
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type')
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS')
  if (req.method === 'OPTIONS') {
    res.status(204).json({})
    return
  }

  if (req.method === 'GET') return exportResponses(req, res)
  if (req.method === 'DELETE') return clearAll(req, res)

  if (req.method !== 'POST') {
    res.setHeader('Allow', 'GET, POST, DELETE')
    res.status(405).json({ error: 'method_not_allowed' })
    return
  }

  let body = req.body
  if (typeof body === 'string') {
    try {
      body = JSON.parse(body)
    } catch {
      res.status(400).json({ error: 'invalid_json' })
      return
    }
  }
  if (!body || typeof body !== 'object') {
    res.status(400).json({ error: 'empty_body' })
    return
  }

  const kind = (body as { kind?: unknown }).kind
  if (!isSurveyKind(kind)) {
    res.status(400).json({ error: 'unknown_kind' })
    return
  }

  const json = JSON.stringify(body)
  if (Buffer.byteLength(json, 'utf8') > MAX_BYTES) {
    res.status(413).json({ error: 'too_large' })
    return
  }

  if (await tooManyFrom(callerIp(req))) {
    res.status(429).json({ error: 'too_many' })
    return
  }

  try {
    const saved = await saveResponse(kind, json)
    if (!saved.ok) {
      // **200 を返して実は消えている、が最悪。**
      // ブラウザはこれを見てコード表示に落ちる
      res.status(503).json({ error: saved.reason })
      return
    }
    res.status(200).json({ ok: true, count: saved.count })
  } catch (e) {
    console.error('アンケートを保存できなかった', e)
    res.status(503).json({ error: 'store_failed' })
  }
}

/**
 * 集計用の取り出し。**中高生の自由記述なので誰でも読めてはいけない。**
 *
 * `SURVEY_ADMIN_TOKEN` を設定していないときは経路ごと閉じる
 * （「未設定なら素通し」にすると、設定を忘れた瞬間に全部読める）。
 */
function isAdmin(req: Req): boolean {
  const expected = process.env.SURVEY_ADMIN_TOKEN
  const given = header(req, 'authorization')?.replace(/^Bearer\s+/i, '')
  return Boolean(expected) && given === expected
}

/**
 * 配る前の試し投稿を片づける。
 *
 * **件数を添えないと消さない。** 集めたあとに誤って呼ぶと戻せないので、
 * 呼ぶ側が「いま何件あるか」を分かっていることを条件にする。
 */
async function clearAll(req: Req, res: Res) {
  if (!isAdmin(req)) {
    res.status(401).json({ error: 'unauthorized' })
    return
  }
  const kind = queryOf(req, 'kind')
  if (!isSurveyKind(kind)) {
    res.status(400).json({ error: 'unknown_kind' })
    return
  }

  const now = await countResponses(kind)
  const expect = Number(queryOf(req, 'expect'))
  if (!Number.isInteger(expect) || expect !== now) {
    res.status(409).json({ error: 'count_mismatch', count: now })
    return
  }

  const removed = await clearResponses(kind)
  res.status(200).json({ ok: true, removed })
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
