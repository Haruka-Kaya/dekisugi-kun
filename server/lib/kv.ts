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
  const out = (await res.json()) as Array<{ result: unknown }>
  return out.map((o) => o.result)
}
