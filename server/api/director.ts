import { runDirector, type DirectorInput } from '../lib/director.ts'
import { emptyDossier } from '../lib/dossier.ts'
import { unitById } from '../lib/units.ts'

/**
 * ディレクター。**状態を持たない。**
 *
 * 理解カルテは「1台の端末が持つ1つの会話」の状態なので、端末が保持して
 * リクエストごとに送る。サーバに DB もロックも要らない。
 *
 * 端末 → ここ → Gemini（テキスト生成）→ ここ → 端末
 * 音声はこの経路を通らない（端末が Gemini Live と直接つながっている）。
 *
 * > [!warning] いまは誰でも叩ける
 * > 認証とレート制限は段階5。**一般公開の前に必ず入れる。**
 * > 入れないと Gemini の請求が青天井になる。
 */

/** 1リクエストの上限。逐語が長くなるので発話数でも切る */
const MAX_BYTES = 256 * 1024
const MAX_UTTERANCES = 200

/**
 * 最低限の門。**これは認証ではない。**
 *
 * トークンは APK の中に平文で入るので、取り出せる人は誰でも通せる。
 * 止められるのは「URL を見つけただけの通りすがり」まで。
 * それでも、公開直後に無防備で置いて Gemini の請求が伸びるのは防げる。
 *
 * 本物の認証とレート制限は段階5。**一般公開の前に必ず入れ替える。**
 * `DIRECTOR_TOKEN` が未設定なら素通しする（ローカル開発のため）。
 */
function tokenOk(req: Req): boolean {
  const expected = process.env.DIRECTOR_TOKEN
  if (!expected) return true
  const got = req.headers?.['x-dekisugi-token']
  const value = Array.isArray(got) ? got[0] : got
  if (typeof value !== 'string' || value.length !== expected.length) return false
  // 長さが同じときだけ全文字を比較する。早期 return で長さを漏らさない
  let diff = 0
  for (let i = 0; i < expected.length; i++) diff |= value.charCodeAt(i) ^ expected.charCodeAt(i)
  return diff === 0
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
  if (!tokenOk(req)) {
    res.status(401).json({ error: 'unauthorized' })
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

  return { dossier, utterances, secondsLeft, turnCount }
}
