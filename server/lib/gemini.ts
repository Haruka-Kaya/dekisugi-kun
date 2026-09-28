import { type Schema } from '@google/genai'

import { vertex } from './vertex.js'

/**
 * ディレクター（会話の裏方）用のテキストモデル。
 * 会話そのものは端末が Live と直接やりとりするので、ここは通らない。
 *
 * > [!important] Developer API と Vertex のどちらも中高生向けには使わない
 * > `ai.google.dev` のキーで叩く Gemini API は、
 * > **18歳未満向けのアプリで使ってはいけない**と規約に明記されている。
 * > 現行の Google Cloud Service Specific Terms §20(d) も同じ用途を禁止し、
 * > Services Summary は Vertex AI API を対象に含めている。
 * > このモジュールは18歳以上の開発確認だけに使用し、未成年・学校経路は fail-closed にする。
 * > 詳細は `docs/age-restriction.md`。
 *
 * モデル名は Vertex の名前空間。Developer API とは別物なので、
 * 変えるときは Vertex に在ることを確かめること。
 */
export const TEXT_MODEL = process.env.VERTEX_TEXT_MODEL ?? 'gemini-2.5-flash'

export function gemini() {
  return vertex()
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
