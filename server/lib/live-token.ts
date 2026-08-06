import { type Lang, localizeUnit } from './i18n.js'
import { LIVE_MODEL, liveSessionConfig, newDirectorPrefix } from './live-config.js'
import { unitById } from './units.js'
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
  /**
   * ディレクターの指示に付ける合図。**セッションごとに違う。**
   * 端末はこれを使って注入する。固定だと生徒が騙れる
   */
  directorPrefix: string

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

  /**
   * 前の会話の続きとして繋ぎ直すものか。
   *
   * 端末はこれが `true` のときだけ「切れ目を見せない再接続」をする。
   * `false` のまま繋ぎ直すと、**いままでの会話を忘れた状態**で
   * 途中から再開してしまい、生徒には別人が現れたように見える。
   */
  resumed: boolean
}

/**
 * [unitId] は**必ず渡す。** 渡さないと、モデルは何を教わるのか
 * 知らないまま会話を始め、単元と無関係な話題を持ち出す（実機で確認）。
 * 知らない ID なら単元なしで作らず、呼び出し側に落とさせる。
 *
 * [resumeHandle] があれば、その会話の続きとして繋ぐ。
 */
export async function createLiveGrant(
  unitId: string,
  resumeHandle?: string,
  lang: Lang = 'ja',
): Promise<LiveGrant> {
  const raw = unitById(unitId)
  if (!raw) throw new Error(`未知の単元: ${unitId}`)
  // **システム指示に入る単元名と概念も訳す。**
  // ここが日本語のままだと、英語で話しているのに
  // 概念の名前だけ日本語で出てくる
  const unit = localizeUnit(raw, lang)

  const { token, expiresAt } = await vertexAccessToken()
  // **毎回作り直す。** 使い回すと、1度知られた合図がずっと通る
  const directorPrefix = newDirectorPrefix()

  return {
    directorPrefix,
    token,
    wsUrl:
      `wss://${VERTEX_LOCATION}-aiplatform.googleapis.com` +
      '/ws/google.cloud.aiplatform.v1beta1.LlmBidiService/BidiGenerateContent',
    model:
      `projects/${VERTEX_PROJECT}/locations/${VERTEX_LOCATION}` +
      `/publishers/google/models/${LIVE_MODEL}`,
    setupConfig: liveSessionConfig(unit, directorPrefix, resumeHandle, lang),
    expiresAt: expiresAt.toISOString(),
    // 実測: 9分時点で code=1000 "The operation was cancelled."
    sessionMinutes: 10,
    resumed: Boolean(resumeHandle),
  }
}
