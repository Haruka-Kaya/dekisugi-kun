import { GoogleGenAI } from '@google/genai'

import { LIVE_MODEL, liveSessionConfig } from './live-config.js'

/**
 * Gemini Live に繋ぐための一時トークン。
 *
 * ## なぜ要るか
 *
 * これまでは APIキーを `--dart-define` で APK に焼いていた。
 * **APK から取り出せるので、サーバを無視して直接 Gemini を叩ける。**
 * その状態では利用の上限をいくらサーバに書いても意味がない。
 *
 * 鍵はサーバだけが持ち、端末には**短命で使い切りのトークン**を渡す。
 * これで初めて「無料の上限」が成立する。
 *
 * > [!warning] ephemeral token は `v1alpha` でしか通らない
 * > 公式ドキュメントは v1beta と書いているが誤り。
 * > 端末側も `v1alpha` で繋ぐこと。
 */

/**
 * 新しいセッションを張れる猶予。接続に手間取っても間に合う程度。
 *
 * これを過ぎるともうセッションを開けない。**渡した会話時間とは別物**で、
 * 「取ったまま寝かせて後で使う」を防ぐためのもの。
 */
export const NEW_SESSION_WINDOW_MINUTES = 2

export type LiveTokenResult = {
  token: string
  /** ISO 8601。端末はこれを過ぎたら取り直す */
  expiresAt: string
  model: string
  apiVersion: 'v1alpha'
}

/**
 * [minutes] ぶんの会話ができるトークンを作る。
 *
 * **期限が来るとセッションごと切られる**（実測: `code=1011 auth token has expired`、
 * 発行58秒後に切断）。つまりここで渡す寿命が、そのまま与えた会話時間の上限になる。
 */
export async function createLiveToken(
  now = Date.now(),
  minutes = 10,
): Promise<LiveTokenResult> {
  const apiKey = process.env.GEMINI_API_KEY
  if (!apiKey) throw new Error('GEMINI_API_KEY が未設定')

  const ai = new GoogleGenAI({ apiKey, httpOptions: { apiVersion: 'v1alpha' } })
  const expireTime = new Date(now + minutes * 60_000).toISOString()

  const token = await ai.authTokens.create({
    config: {
      uses: 1, // 1接続まで。拾われても使い回せない
      expireTime,
      newSessionExpireTime: new Date(
        now + NEW_SESSION_WINDOW_MINUTES * 60_000,
      ).toISOString(),
      // **モデルと設定をここで固定する。**
      //
      // 端末側で差し替えられると、こちらの想定より高いモデルを呼ばれかねない。
      // それだけでなく、**ここに入れなかった設定は端末が送っても効かない**（実測）。
      // 文字起こしを端末側だけで指定したら、音声は返るのに文字起こしが空になった。
      liveConnectConstraints: {
        model: LIVE_MODEL,
        config: liveSessionConfig() as never,
      },
      httpOptions: { apiVersion: 'v1alpha' },
    },
  })

  const name = token?.name
  if (!name) throw new Error('トークンが返らなかった')

  return {
    token: name,
    expiresAt: expireTime,
    model: LIVE_MODEL,
    apiVersion: 'v1alpha',
  }
}
