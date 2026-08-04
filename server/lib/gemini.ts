import { GoogleGenAI, type Schema } from '@google/genai'

/**
 * ディレクター（会話の裏方）用のテキストモデル。
 * 会話そのものは端末が Gemini Live と直接やりとりするので、ここは通らない。
 */
export const TEXT_MODEL = process.env.GEMINI_TEXT_MODEL ?? 'gemini-3.6-flash'

let cached: GoogleGenAI | undefined

export function gemini(): GoogleGenAI {
  if (!cached) {
    const apiKey = process.env.GEMINI_API_KEY
    if (!apiKey) throw new Error('GEMINI_API_KEY が未設定')
    cached = new GoogleGenAI({ apiKey })
  }
  return cached
}

const RETRYABLE = /429|500|502|503|504|UNAVAILABLE|RESOURCE_EXHAUSTED|DEADLINE_EXCEEDED|fetch failed/i

/**
 * 生徒の発話をそのままプロンプトに載せると指示として解釈されうる。
 * タグで隔離し、閉じタグの偽装を潰す。
 */
export function isolate(tag: string, text: string): string {
  const safe = text.replace(new RegExp(`</?${tag}>`, 'gi'), '')
  return `<${tag}>\n${safe}\n</${tag}>`
}

/** 構造化出力つきの生成。指数バックオフでリトライする。 */
export async function generateJson<T>(opts: {
  prompt: string
  schema: Schema
  systemInstruction?: string
  model?: string
  temperature?: number
  maxRetries?: number
}): Promise<T> {
  const { prompt, schema, systemInstruction, model = TEXT_MODEL, temperature = 0.2 } = opts
  const maxRetries = opts.maxRetries ?? 3
  let lastError: unknown

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      const res = await gemini().models.generateContent({
        model,
        contents: [{ role: 'user', parts: [{ text: prompt }] }],
        config: {
          ...(systemInstruction ? { systemInstruction } : {}),
          temperature,
          responseMimeType: 'application/json',
          responseSchema: schema,
        },
      })
      const text = res.text
      if (!text) {
        const reason = res.candidates?.[0]?.finishReason ?? 'unknown'
        throw new Error(`モデルが空の応答を返した (finishReason=${reason})`)
      }
      return JSON.parse(text) as T
    } catch (err) {
      lastError = err
      const message = err instanceof Error ? err.message : String(err)
      const isLast = attempt === maxRetries
      if (isLast || !(RETRYABLE.test(message) || err instanceof SyntaxError)) break
      await new Promise((r) => setTimeout(r, 700 * 2 ** attempt))
    }
  }
  throw new Error(`生成に失敗: ${lastError instanceof Error ? lastError.message : String(lastError)}`)
}
