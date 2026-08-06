import { verifyToken } from '../lib/auth.js'
import { runDirector, type DirectorInput } from '../lib/director.js'
import { envLang, parseLang } from '../lib/i18n.js'
import { emptyDossier } from '../lib/dossier.js'
import { checkRate } from '../lib/ratelimit.js'
import { unitById } from '../lib/units.js'

/**
 * ディレクター。**状態を持たない。**
 *
 * 理解カルテは「1台の端末が持つ1つの会話」の状態なので、端末が保持して
 * リクエストごとに送る。サーバに DB もロックも要らない。
 *
 * 端末 → ここ → Gemini（テキスト生成）→ ここ → 端末
 * 音声はこの経路を通らない（端末が Gemini Live と直接つながっている）。
 *
 * 端末ごとの署名付きトークン（`/api/register` で取る）と回数制限で守っている。
 *
 * > [!warning] これは本人確認ではない
 * > 誰でも `/api/register` を叩けばトークンを取れる。守っているのは
 * > 「同じ端末であること」までで、端末を大量に作られると1端末あたりの
 * > 制限は意味を失う。だから**全体の1日上限**も別に持っている。
 *
 * > [!warning] 保存先が無いと回数制限は気休め
 * > `KV_REST_API_URL` が未設定だとプロセス内カウンタに落ちる。
 * > 繋がっているかは応答ヘッダ `X-RateLimit-Backend` で分かる。
 */

/** 1リクエストの上限。逐語が長くなるので発話数でも切る */
const MAX_BYTES = 256 * 1024
const MAX_UTTERANCES = 200

/** `Authorization: Bearer xxx` から生のトークンを取る。 */
function bearer(req: Req): string | undefined {
  const raw = req.headers?.authorization ?? req.headers?.Authorization
  const value = Array.isArray(raw) ? raw[0] : raw
  if (typeof value !== 'string') return undefined
  const m = /^Bearer\s+(.+)$/i.exec(value.trim())
  return m ? m[1] : undefined
}

type Req = {
  method?: string
  body?: unknown
  headers?: Record<string, string | string[] | undefined>
}
type Res = {
  status: (code: number) => Res
  json: (body: unknown) => void
  setHeader: (name: string, value: string) => void
}

export default async function handler(req: Req, res: Res) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST')
    res.status(405).json({ error: 'method_not_allowed' })
    return
  }
  // ① 端末の識別。**Gemini を呼ぶ前に落とす**
  const auth = verifyToken(bearer(req))
  if (!auth.ok) {
    // 期限切れは端末側で登録し直せば直る。区別して返す
    res.status(401).json({ error: auth.reason === 'expired' ? 'token_expired' : 'unauthorized' })
    return
  }

  // ② 回数の制限。ここが Gemini の請求を止める最後の砦
  const rate = await checkRate(auth.token.did)
  // 本物の保存先に繋がっているかを外から確認できるようにしておく
  res.setHeader('X-RateLimit-Backend', rate.backend)
  res.setHeader('X-RateLimit-Remaining', String(rate.remaining))
  if (!rate.ok) {
    res.setHeader('Retry-After', String(rate.retryAfterSeconds))
    res.status(429).json({ error: 'rate_limited', retryAfter: rate.retryAfterSeconds })
    return
  }

  let body = req.body
  if (typeof body === 'string') {
    if (Buffer.byteLength(body, 'utf8') > MAX_BYTES) {
      res.status(413).json({ error: 'too_large' })
      return
    }
    try {
      body = JSON.parse(body)
    } catch {
      res.status(400).json({ error: 'invalid_json' })
      return
    }
  }

  const input = parseInput(body)
  if ('error' in input) {
    res.status(400).json(input)
    return
  }

  try {
    const out = await runDirector(input)
    res.status(200).json(out)
  } catch (e) {
    // 中身は返さない。プロンプトやキーの断片が混ざりうる
    console.error('director failed', e)
    res.status(502).json({ error: 'director_failed' })
  }
}

/** 入力の検証。**壊れた入力で LLM を呼ばない。** */
export function parseInput(body: unknown): DirectorInput | { error: string; detail?: string } {
  if (!body || typeof body !== 'object') return { error: 'empty_body' }
  const b = body as Record<string, unknown>

  const unitId = typeof b.unitId === 'string' ? b.unitId : undefined
  const rawDossier = b.dossier as DirectorInput['dossier'] | undefined

  if (!unitId && !rawDossier) return { error: 'unit_required' }
  const resolvedUnitId = rawDossier?.unitId ?? unitId!
  if (!unitById(resolvedUnitId)) {
    return { error: 'unknown_unit', detail: resolvedUnitId }
  }

  // カルテが無い＝会話の1回目。空のカルテから始める
  const dossier =
    rawDossier && Array.isArray(rawDossier.slots) && rawDossier.slots.length > 0
      ? rawDossier
      : emptyDossier(resolvedUnitId)

  const utterances = Array.isArray(b.utterances) ? b.utterances : []
  if (utterances.length > MAX_UTTERANCES) return { error: 'too_many_utterances' }
  for (const u of utterances) {
    if (
      !u ||
      typeof u.id !== 'string' ||
      typeof u.text !== 'string' ||
      (u.speaker !== 'student' && u.speaker !== 'ai')
    ) {
      return { error: 'invalid_utterance' }
    }
  }

  const secondsLeft = typeof b.secondsLeft === 'number' ? b.secondsLeft : 600
  const turnCount = typeof b.turnCount === 'number' ? b.turnCount : 0
  // 端末が明示していればそれが勝つ。無ければ環境変数の既定
  const lang = b.lang == null ? envLang() : parseLang(b.lang)

  return { dossier, utterances, secondsLeft, turnCount, lang }
}
