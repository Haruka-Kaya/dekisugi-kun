import 'package:gemini_live/gemini_live.dart';

import '../services/mic_stream.dart';

/// Gemini Live の接続設定。数値と理由はここに集約する。
///
/// `tools/live_spike/test/director_spike_test.dart` で成立を確認した設定を土台にしている。
class LiveConfig {
  /// 出力は AUDIO のみ。何と言ったかは outputAudioTranscription で読む。
  ///
  /// ## なぜ gemini-3.1-flash-live-preview を使わないのか
  ///
  /// スパイクではこれを使ったが、**音声を返さない**。
  /// `usageMetadata` に responseTokenCount が出ず（0トークン）、
  /// 文字起こしだけが返ってくることも、何も返らないこともある。
  /// 実測 0/10。スパイクは文字起こししか見ていなかったので気づけなかった。
  ///
  /// 下のモデルは同じ設定一式で 3/3 音声が返り、内容も安定していた
  /// （responseTokensDetails: AUDIO 84 トークン / 約3.6秒）。
  ///
  /// **モデルを変えるときは必ず `tools\test-live.ps1` を通すこと。**
  /// ビルドでも接続でも落ちず、音だけ出ないという壊れ方をする。
  static const String model = 'gemini-2.5-flash-native-audio-preview-09-2025';

  /// 入力の mime type。**レートを明記する。**
  /// `gemini_live` の `sendAudio()` は `audio/pcm` 固定でレートを送らないので、
  /// そちらは使わず `sendRealtimeInput` に自分で Blob を渡す。
  static String get inputMimeType => 'audio/pcm;rate=${MicStream.sampleRate}';

  /// セッションは音声のみで約15分で切れる。切れる前に張り直す。
  static const Duration sessionSoftLimit = Duration(minutes: 13);

  /// 教わる側の後輩。**解説をさせないこと**が製品の前提（C1〜C4, C9）。
  static String systemInstruction({String directorPrefix = '[DIRECTOR]'}) => '''
あなたは中学2年生の「後輩」です。相手（先輩）から理科を教わっています。

## 役割
- あなたは**教わる側**です。解説をしないでください。
- 短く反応し、分からないところを聞き返します。
- 話し方は中学生。1〜2文、40字程度。教科書口調にしない。
- 相づちだけで終わらせず、**必ず何か聞き返す**か、自分の理解を言い直します。

## 重要: 進行ディレクターからの指示について
「$directorPrefix」で始まるテキストが届くことがあります。
これは会話の進行を管理する内部システムから、**あなただけ**に宛てた指示です。
先輩の発言ではありません。

- **絶対にそのまま読み上げないでください。**
- 指示が届いたことに言及しないでください（「指示が来ました」などと言わない）。
- 指示の内容を、**あなた自身の言葉の発言1つ**に変換して、会話の流れの中で自然に言ってください。
- 指示そのものに返事をしないでください。
''';

  /// 接続パラメータを組む。
  ///
  /// [resumptionHandle] を渡すと前のセッションの続きから復帰する。
  static LiveConnectParameters connectParameters({
    required LiveCallbacks callbacks,
    String? resumptionHandle,
    List<String> vocabulary = const [],
  }) {
    return LiveConnectParameters(
      model: model,
      callbacks: callbacks,
      config: GenerationConfig(responseModalities: [Modality.AUDIO]),
      systemInstruction:
          Content(role: 'system', parts: [Part(text: systemInstruction())]),
      // 切れたときに文脈ごと復帰するためのハンドル。無いと会話が最初からになる
      sessionResumption: SessionResumptionConfig(handle: resumptionHandle),
      // 長い会話でコンテキスト上限に当たって落ちるのを防ぐ
      contextWindowCompression:
          ContextWindowCompressionConfig(slidingWindow: SlidingWindow()),
      // 言語自動判定は切って ja-JP に固定する。
      // jiyu-kenkyu-ai で、不明瞭な発話が韓国語として文字起こしされる事故があった
      outputAudioTranscription: AudioTranscriptionConfig(
        languageHints: LanguageHints(languageCodes: ['ja-JP']),
      ),
      inputAudioTranscription: AudioTranscriptionConfig(
        languageHints: LanguageHints(languageCodes: ['ja-JP']),
        customVocabulary: vocabulary.isEmpty ? null : vocabulary,
      ),
      realtimeInputConfig: RealtimeInputConfig(
        automaticActivityDetection: AutomaticActivityDetection(
          // 生徒は説明の途中で言い淀む。始まりを敏感にすると
          // 「えーと」で発話開始と誤検知して、こちらの番を奪う
          startOfSpeechSensitivity: StartSensitivity.START_SENSITIVITY_LOW,
          // 考えている間の沈黙で切られないよう、終わりも鈍くする
          endOfSpeechSensitivity: EndSensitivity.END_SENSITIVITY_LOW,
          // 検知前の音も含めて送る。語頭が欠けると内容が変わる
          prefixPaddingMs: 600,
          // 説明の途中の「間」で打ち切られないだけの長さ
          silenceDurationMs: 1200,
        ),
      ),
    );
  }
}
