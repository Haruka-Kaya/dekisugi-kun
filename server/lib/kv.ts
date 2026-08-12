/**
 * Upstash Redis の薄い口。**`quota.ts` と同じ資格情報を使う。**
 *
 * 保存先を増やさないのは、増やすたびに
 * 「どれが本物でどれが空か」を確かめる場所が増えるため。
 */

export const kvUrl = () => process.env.KV_REST_API_URL
export const kvToken = () => process.env.KV_REST_API_TOKEN

export function hasKv(): boolean {
  return Boolean(kvUrl() && kvToken())
}

/** パイプラインで叩く。**失敗は投げる**（黙って落とすと保存できていないのに成功に見える） */
export async function kv(commands: string[][]): Promise<unknown[]> {
  const res = await fetch(`${kvUrl()}/pipeline`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${kvToken()}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(commands),
  })
  if (!res.ok) throw new Error(`KV エラー: ${res.status}`)
  const out = (await res.json()) as unknown
  if (!Array.isArray(out) || out.length !== commands.length) {
    throw new Error('KV 応答の形式が不正です')
  }
  return out.map((entry, index) => {
    if (!entry || typeof entry !== 'object' || Array.isArray(entry)) {
      throw new Error(`KV command ${index + 1} の応答形式が不正です`)
    }
    const result = entry as { error?: unknown; result?: unknown }
    if (typeof result.error === 'string' && result.error.length > 0) {
      // Upstash pipelineはcommand失敗でもHTTP 200を返す。error本文は入力値を
      // 含み得るためログへ転記せず、command位置だけを通知する。
      throw new Error(`KV command ${index + 1} が失敗しました`)
    }
    if (!Object.prototype.hasOwnProperty.call(result, 'result')) {
      throw new Error(`KV command ${index + 1} にresultがありません`)
    }
    return result.result
  })
}
