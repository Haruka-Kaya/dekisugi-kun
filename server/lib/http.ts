/**
 * HTTP まわりの共通部品。
 *
 * `Req` / `Res` の型と `bearer` / `queryOf` が5つのハンドラに散っていた。
 * 経路を増やすたびに写経が増え、片方だけ直した形の食い違いが生まれる。
 *
 * **フレームワークの型に依存しない。** Vercel の `VercelRequest` を
 * そのまま使うと、テストが実物を組み立てないと書けなくなる。
 * ここで必要な形だけを宣言しておけば、テストは素のオブジェクトで足りる。
 */

export type Req = {
  method?: string
  headers?: Record<string, string | string[] | undefined>
  body?: unknown
  query?: Record<string, string | string[] | undefined>
  url?: string
}

export type Res = {
  status: (code: number) => Res
  json: (body: unknown) => void
  setHeader: (name: string, value: string) => void
}

/** 大文字小文字を無視してヘッダを1つ取る。 */
export function header(req: Req, name: string): string | undefined {
  const raw = req.headers?.[name] ?? req.headers?.[name.toLowerCase()]
  return Array.isArray(raw) ? raw[0] : raw
}

/** `Authorization: Bearer xxx` の xxx。 */
export function bearer(req: Req): string | undefined {
  const value = header(req, 'authorization') ?? header(req, 'Authorization')
  if (typeof value !== 'string') return undefined
  const m = /^Bearer\s+(.+)$/i.exec(value.trim())
  return m ? m[1] : undefined
}

/**
 * クエリを1つ取る。
 *
 * **`req.query` だけを見ない。** query を組み立てない実行環境があり、
 * そこでは URL から読むしかない（実際に取りこぼした）。
 */
export function queryOf(req: Req, key: string): string | undefined {
  const q = req.query?.[key]
  const fromQuery = Array.isArray(q) ? q[0] : q
  if (typeof fromQuery === 'string' && fromQuery) return fromQuery
  const m = new RegExp(`[?&]${key}=([^&]+)`).exec(req.url ?? '')
  return m ? decodeURIComponent(m[1]!) : undefined
}

/**
 * 呼び出し元。**特定のためではなく連投を抑えるためだけに使う。**
 *
 * 個人を追う目的では使わないこと。IP は個人情報になりうる。
 */
export function callerIp(req: Req): string {
  const fwd = header(req, 'x-forwarded-for') ?? ''
  return fwd.split(',')[0]!.trim() || (header(req, 'x-real-ip') ?? '')
}

/**
 * 本文を JSON として読む。**文字列で来ることがある。**
 *
 * 壊れていても 500 にしない。呼び出し側が 400 を返せるように undefined を返す。
 */
export function parseBody(body: unknown): unknown {
  if (typeof body !== 'string') return body
  try {
    return JSON.parse(body)
  } catch {
    return undefined
  }
}
