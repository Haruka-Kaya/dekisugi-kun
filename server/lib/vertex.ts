import { GoogleGenAI } from '@google/genai'
import { GoogleAuth, type JWTInput } from 'google-auth-library'

/**
 * Vertex AI（Google Cloud 経由の Gemini）への入口。
 *
 * ## なぜ Gemini Developer API から移したか
 *
 * Developer API（`ai.google.dev` のキー）の追加規約に、こうある:
 *
 * > "You also will not use the Services as part of a website, application, or
 * > other service that is **directed towards or is likely to be accessed by
 * > individuals under the age of 18**."
 *
 * デキすぎ君は中高生向けだと明言している製品なので、真正面から当たる。
 * 有料/無料の区別より前の条項なので、課金しても外れない。
 *
 * 現行の Google Cloud Service Specific Terms §20(d) は、18歳未満向け、
 * または18歳未満がアクセスする可能性が高いサービスでの生成AI利用を禁止する。
 * Services Summary は Vertex AI API / Vertex AI Live API を対象に含めているため、
 * 中高生向けの本製品では Vertex 経路も利用不可。年齢ゲート、学校承認、保護者同意では
 * 解消しない。18歳以上の開発確認に限り、未成年・学校経路は fail-closed にすること。
 * 詳細は `docs/age-restriction.md`。
 *
 * ## 資格情報の置き場
 *
 * - Vercel: `GOOGLE_SERVICE_ACCOUNT_JSON`（キーの中身をそのまま入れる）
 * - ローカル: `secrets/vertex-sa.json`（gitignore 済み）
 *
 * **キーをリポジトリに置かないこと。** Google は公開リポジトリで見つけた
 * サービスアカウントキーを自動で無効化する。
 */

export const VERTEX_PROJECT = process.env.VERTEX_PROJECT ?? 'dekisugi-kun'

/**
 * リージョン。**モデルの提供状況がリージョンで違う**ので、
 * 変えるときは Live のモデルが居るか確かめること。
 */
export const VERTEX_LOCATION = process.env.VERTEX_LOCATION ?? 'us-central1'

let cachedCredentials: JWTInput | undefined

/** サービスアカウントの資格情報。環境変数優先、無ければローカルのファイル。 */
function credentials(): JWTInput | undefined {
  if (cachedCredentials) return cachedCredentials
  const raw = process.env.GOOGLE_SERVICE_ACCOUNT_JSON
  if (raw) {
    try {
      cachedCredentials = JSON.parse(raw) as JWTInput
      return cachedCredentials
    } catch (e) {
      // ここで落とす。壊れた資格情報のまま起動すると、
      // 実際にモデルを呼ぶ瞬間まで気づけない
      throw new Error(`GOOGLE_SERVICE_ACCOUNT_JSON が JSON として読めない: ${e}`)
    }
  }
  return undefined // keyFile / ADC に任せる
}

const SCOPES = ['https://www.googleapis.com/auth/cloud-platform']

export function vertexAuth(): GoogleAuth {
  const creds = credentials()
  if (creds) return new GoogleAuth({ credentials: creds, scopes: SCOPES })
  // ローカル開発。gitignore 済みの場所を見る
  return new GoogleAuth({
    keyFile: process.env.GOOGLE_APPLICATION_CREDENTIALS ?? '../secrets/vertex-sa.json',
    scopes: SCOPES,
  })
}

let cachedClient: GoogleGenAI | undefined

/** テキスト生成用。会話（Live）は別経路。 */
export function vertex(): GoogleGenAI {
  if (!cachedClient) {
    const creds = credentials()
    cachedClient = new GoogleGenAI({
      vertexai: true,
      project: VERTEX_PROJECT,
      location: VERTEX_LOCATION,
      ...(creds
        ? { googleAuthOptions: { credentials: creds, scopes: SCOPES } }
        : {
            googleAuthOptions: {
              keyFile:
                process.env.GOOGLE_APPLICATION_CREDENTIALS ??
                '../secrets/vertex-sa.json',
              scopes: SCOPES,
            },
          }),
    })
  }
  return cachedClient
}

/** 会話用に、期限つきのアクセストークンを取る。 */
export async function vertexAccessToken(): Promise<{
  token: string
  expiresAt: Date
}> {
  const client = await vertexAuth().getClient()
  const res = await client.getAccessToken()
  if (!res.token) throw new Error('アクセストークンが取れなかった')

  // getTokenInfo は AuthClient の共通型に無い。持っている実装だけで使う
  const withInfo = client as { getTokenInfo?: (t: string) => Promise<{ expiry_date?: number }> }
  const info = await withInfo.getTokenInfo?.(res.token).catch(() => null)

  return {
    token: res.token,
    // 期限が読めないときは短めに見積もる。長く見積もって外すと、
    // 切れたトークンで繋ぎにいって原因の分からない失敗になる
    expiresAt: info?.expiry_date
      ? new Date(info.expiry_date)
      : new Date(Date.now() + 30 * 60_000),
  }
}
