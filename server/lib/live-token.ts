import { LIVE_MODEL, liveSessionConfig } from './live-config.js'
import { VERTEX_LOCATION, VERTEX_PROJECT, vertexAccessToken } from './vertex.js'

/**
 * 会話を始めるために端末へ渡すもの。
 *
 * ## 端末に何を渡し、何を渡さないか
 *
 * 渡すのは**Vertex のアクセストークンと接続先**だけ。
 * サービスアカウントの鍵はサーバから出ない。
 *
 * > [!warning] トークンは60分有効で、権限は絞ってあるだけ
 * > Developer API の ephemeral token と違い、寿命を分単位で決められない。
 * > 60分のあいだ、このトークンでできることは
 * > **サービスアカウントの権限の範囲すべて**になる。
 * > だからサービスアカウントには `roles/aiplatform.user` しか付けていない。
 *
 * ## 会話設定は端末が送る
 *
 * Vertex には ephemeral token が無く、設定を焼き込めない。
 * そのため**システム指示を端末が送る**ことになり、
 * ペルソナと `[DIRECTOR]` の約束は端末側で改変できてしまう。
 *
 * サーバが同じ設定を返して端末はそれを送るだけ、という形にしてあるので、
 * 「正しい設定はサーバが持っている」ことは保てる。
 * **改変を防ぎたければ音声を中継するしかない**（いまはしていない）。
 */

export type LiveGrant = {
  /** Vertex のアクセストークン */
  token: string
  /** 接続先の WebSocket URL */
  wsUrl: string
  /** setup メッセージに入れるモデルのフルパス */
  model: string
  /** 端末がそのまま送る会話設定 */
  setupConfig: Record<string, unknown>
  /** このトークンが使えなくなる時刻（ISO 8601） */
  expiresAt: string
  /** 1セッションのおおよその上限（分）。**Vertex 側が切る** */
  sessionMinutes: number
}

export async function createLiveGrant(): Promise<LiveGrant> {
  const { token, expiresAt } = await vertexAccessToken()

  return {
    token,
    wsUrl:
      `wss://${VERTEX_LOCATION}-aiplatform.googleapis.com` +
      '/ws/google.cloud.aiplatform.v1beta1.LlmBidiService/BidiGenerateContent',
    model:
      `projects/${VERTEX_PROJECT}/locations/${VERTEX_LOCATION}` +
      `/publishers/google/models/${LIVE_MODEL}`,
    setupConfig: liveSessionConfig(),
    expiresAt: expiresAt.toISOString(),
    // 実測: 9分時点で code=1000 "The operation was cancelled."
    sessionMinutes: 10,
  }
}
