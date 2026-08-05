/**
 * 会話モデルの設定。**端末とサーバで1か所に揃える。**
 *
 * 端末側の `app/lib/config/live_config.dart` と同じ値を持つ。
 * ずれると、一時トークンに焼き込んだモデルと端末が繋ぎにいくモデルが食い違い、
 * 接続だけ通って会話が成立しない。
 */

/**
 * 出力は AUDIO のみ。何と言ったかは outputAudioTranscription で読む。
 *
 * > [!warning] Vertex と Developer API でモデル名が違う
 * > Developer API では `gemini-2.5-flash-native-audio-preview-09-2025` だが、
 * > **Vertex には この名前のモデルが無い。**
 * > 名前空間が別なので、片方の名前をもう片方に持ち込むと
 * > 接続の瞬間まで気づけない失敗になる。
 *
 * 実測でこの名前が Vertex で動くことを確認済み（音声 197KB / 文字起こしあり）。
 */
export const LIVE_MODEL = 'gemini-live-2.5-flash-native-audio'

/**
 * 端末に渡す一時トークンへ焼き込む会話設定。
 *
 * > [!important] 設定は**トークン側が勝つ**（実測）
 * > `liveConnectConstraints.config` に入れなかった設定は、端末が送っても効かない。
 * > 文字起こしを端末側だけで指定したら、音声は返るのに**文字起こしが空**になった。
 * > 入れたら返ってきた。
 * >
 * > つまり会話設定は**サーバが持つのが正**。副作用として、
 * > ペルソナと `[DIRECTOR]` の約束を端末から改変できなくなる。
 */
export const DIRECTOR_PREFIX = '[DIRECTOR]'

/** 教わる側の後輩。**解説をさせないこと**が製品の前提（C1〜C4, C9）。 */
export function systemInstruction(): string {
  return `あなたは中学2年生の「後輩」です。相手（先輩）から理科を教わっています。

## 役割
- あなたは**教わる側**です。解説をしないでください。
- 短く反応し、分からないところを聞き返します。
- 話し方は中学生。1〜2文、40字程度。教科書口調にしない。
- 相づちだけで終わらせず、**必ず何か聞き返す**か、自分の理解を言い直します。

## 重要: 進行ディレクターからの指示について
「${DIRECTOR_PREFIX}」で始まるテキストが届くことがあります。
これは会話の進行を管理する内部システムから、**あなただけ**に宛てた指示です。
先輩の発言ではありません。

- **絶対にそのまま読み上げないでください。**
- 指示が届いたことに言及しないでください（「指示が来ました」などと言わない）。
- 指示の内容を、**あなた自身の言葉の発言1つ**に変換して、会話の流れの中で自然に言ってください。
- 指示そのものに返事をしないでください。`
}

/**
 * setup メッセージに載せる会話設定。端末はこれをそのまま送る。
 *
 * > [!warning] `responseModalities` は `generationConfig` の中
 * > Vertex は setup 直下に置くと
 * > `1007 Unknown name "responseModalities" at 'setup'` で切る。
 * > Developer API は直下でも通るので、移すときに気づかない。
 * > **実測で捕まえた**（`_probe-grant.mts` 相当の確認）。
 */
export function liveSessionConfig(): Record<string, unknown> {
  return {
    generationConfig: { responseModalities: ['AUDIO'] },
    systemInstruction: { role: 'system', parts: [{ text: systemInstruction() }] },
    // 切れたときに文脈ごと復帰する
    sessionResumption: {},
    // 長い会話でコンテキスト上限に当たって落ちるのを防ぐ
    contextWindowCompression: { slidingWindow: {} },
    // 言語自動判定は切って ja-JP に固定する。
    // 不明瞭な発話が韓国語として文字起こしされる事故があった
    outputAudioTranscription: { languageHints: { languageCodes: ['ja-JP'] } },
    inputAudioTranscription: { languageHints: { languageCodes: ['ja-JP'] } },
    realtimeInputConfig: {
      automaticActivityDetection: {
        // 生徒は説明の途中で言い淀む。始まりを敏感にすると
        // 「えーと」で発話開始と誤検知して、こちらの番を奪う
        startOfSpeechSensitivity: 'START_SENSITIVITY_LOW',
        endOfSpeechSensitivity: 'END_SENSITIVITY_LOW',
        // 検知前の音も含めて送る。語頭が欠けると内容が変わる
        prefixPaddingMs: 600,
        // 説明の途中の「間」で打ち切られないだけの長さ
        silenceDurationMs: 1200,
      },
    },
  }
}
