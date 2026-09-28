/**
 * デキすぎ君の「前置き」を生成AIで書く経路。
 *
 * プロバイダーの年齢規約で閉じた旧経路（/api/director, /api/live-token）
 * とは別口。**生成するのは返事の前置きだけ** —— 問い返しの誘導文
 * （lure）と3択はクライアント側のカタログを逐語で使うので、
 * 教理上の正しさは生成AIに委ねない。
 *
 * プロバイダーは OpenAI 互換の chat/completions を想定
 * （環境変数で差し替え可）。APIキーはクライアントに出さない。
 */

/** 入力の上限。長い説明も頭だけで文脈は足りる */
export const MAX_EXPLANATION_CHARS = 900
export const MAX_TERMS = 8
export const MAX_TERM_CHARS = 40
export const MAX_LABEL_CHARS = 60

/** 生成された前置きの長さ（文字）。超過分は句点か記号で切る */
export const MAX_ACK_CHARS = 72

export type CompanionLineInput = {
  explanation: string
  heardTerms: string[]
  conceptLabel: string
}

export type CompanionLineBody =
  | { ok: true; input: CompanionLineInput }
  | { ok: false; error: 'invalid_json' | 'bad_shape' }

/** ボディを入力へ矯正する。 */
export function parseCompanionLineBody(raw: unknown): CompanionLineBody {
  let body = raw
  if (typeof body === 'string') {
    if (Buffer.byteLength(body, 'utf8') > 8 * 1024) {
      return { ok: false, error: 'bad_shape' }
    }
    try {
      body = JSON.parse(body)
    } catch {
      return { ok: false, error: 'invalid_json' }
    }
  }
  if (typeof body !== 'object' || body === null) {
    return { ok: false, error: 'bad_shape' }
  }
  const b = body as Record<string, unknown>
  if (typeof b.explanation !== 'string' || !b.explanation.trim()) {
    return { ok: false, error: 'bad_shape' }
  }
  const explanation = b.explanation.trim().slice(0, MAX_EXPLANATION_CHARS)
  const heardTerms = Array.isArray(b.heardTerms)
    ? b.heardTerms
        .filter((t): t is string => typeof t === 'string')
        .map((t) => t.trim().slice(0, MAX_TERM_CHARS))
        .filter(Boolean)
        .slice(0, MAX_TERMS)
    : []
  const conceptLabel =
    typeof b.conceptLabel === 'string'
      ? b.conceptLabel.trim().slice(0, MAX_LABEL_CHARS)
      : ''
  return { ok: true, input: { explanation, heardTerms, conceptLabel } }
}

/** 前置きだけを書かせるプロンプト。クライアント側の組み立てと同じ規則。 */
export function buildCompanionPrompt(input: CompanionLineInput): string {
  const terms = input.heardTerms.slice(0, 5).join('、')
  const heardLine = terms
    ? `（この説明からは「${terms}」という言葉が聞けた。）\n`
    : ''
  return (
    'あなたは「デキすぎ君」。理科を学ぶAIパートナーで、自信満々だが教科書の思い込みをいくつか持っている。\n' +
    `生徒が「${input.conceptLabel}」について、こう説明してくれた：\n` +
    `「${input.explanation}」\n` +
    heardLine +
    '生徒の説明を受け止める前置きを、50文字以内の日本語でひとことだけ返して。' +
    '質問・答え・説明の正誤・指示は一切言わない。生徒が言った内容に触れて、' +
    'デキすぎ君らしい、やや自信満々な口調で。前置きの文だけを返す。'
  )
}

/**
 * 生成物の検証・整形。
 *
 * 空・日本語なし・質問形（固定の問いが後続するので二重の問いになる）は
 * 受理しない。lure の丸写し検査は lure を持つクライアント側でも行う。
 */
export function sanitizeCompanionAck(
  raw: string | null | undefined,
  maxChars = MAX_ACK_CHARS,
): string | null {
  if (raw == null) return null
  let text = raw
    .replace(/[\r\n]+/g, ' ')
    .replace(/[#*_`~]+/g, '')
    .replace(/\s+/g, ' ')
    .trim()
  const pairs: Array<[string, string]> = [
    ['「', '」'],
    ['"', '"'],
    ["'", "'"],
    ['（', '）'],
    ['(', ')'],
  ]
  for (const [open, close] of pairs) {
    if (text.startsWith(open) && text.endsWith(close) && text.length > 2) {
      text = text.slice(open.length, text.length - close.length).trim()
    }
  }
  if (!text) return null
  if (!/[぀-ヿ一-鿿]/.test(text)) return null
  if (text.includes('？') || text.includes('?')) return null
  if ([...text].length > maxChars) {
    const cut = [...text].slice(0, maxChars).join('')
    const lastStop = cut.lastIndexOf('。')
    text = lastStop > 10 ? cut.slice(0, lastStop + 1) : `${cut}…`
  }
  return text
}

export type CompanionProvider = (prompt: string) => Promise<string | null>

/** OpenAI 互換 chat/completions の呼び出し。fetch は差し替え可能。 */
export function openAiCompatibleProvider(opts: {
  baseUrl: string
  apiKey: string
  model: string
  timeoutMs?: number
  fetchImpl?: typeof fetch
}): CompanionProvider {
  const { baseUrl, apiKey, model, timeoutMs = 8000 } = opts
  const doFetch = opts.fetchImpl ?? fetch
  return async (prompt) => {
    const ctrl = new AbortController()
    const timer = setTimeout(() => ctrl.abort(), timeoutMs)
    try {
      const res = await doFetch(
        `${baseUrl.replace(/\/$/, '')}/chat/completions`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${apiKey}`,
          },
          body: JSON.stringify({
            model,
            messages: [{ role: 'user', content: prompt }],
            max_tokens: 96,
            temperature: 0.7,
          }),
          signal: ctrl.signal,
        },
      )
      if (!res.ok) return null
      const data = (await res.json()) as {
        choices?: Array<{ message?: { content?: string } }>
      }
      return data.choices?.[0]?.message?.content ?? null
    } catch {
      return null
    } finally {
      clearTimeout(timer)
    }
  }
}

/** 環境からプロバイダーを組み立てる。キー未設定なら null（機能は常に黙って退避）。 */
export function companionProviderFromEnv(
  env: NodeJS.ProcessEnv = process.env,
): CompanionProvider | null {
  const apiKey = env.COMPANION_AI_API_KEY
  if (!apiKey) return null
  return openAiCompatibleProvider({
    baseUrl: env.COMPANION_AI_BASE_URL ?? 'https://api.openai.com/v1',
    apiKey,
    model: env.COMPANION_AI_MODEL ?? 'gpt-4o-mini',
  })
}
