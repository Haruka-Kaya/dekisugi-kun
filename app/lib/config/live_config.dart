import 'package:gemini_live/gemini_live.dart';

import '../services/mic_stream.dart';

/// Gemini Live に繋ぐときの、**端末側に残った設定だけ**。
///
/// ## 会話設定はここに無い
///
/// モデル・システム指示・VAD・文字起こし・セッション再開は、すべて
/// サーバが一時トークンに焼き込む（`server/lib/live-config.ts`）。
///
/// > [!important] トークンに焼いた設定が勝つ（実測）
/// > `liveConnectConstraints.config` に入っていない設定は、
/// > **端末が送っても効かない。**
/// > 文字起こしを端末側だけで指定したら、音声は返るのに文字起こしが空になった。
/// >
/// > なので端末からは送らない。送っても効かないものを書いておくと、
/// > 「ここを直せば変わる」と勘違いする。
///
/// 副作用として、ペルソナと `[DIRECTOR]` の約束を端末から改変できない。
class LiveConfig {
  /// 入力の mime type。**レートを明記する。**
  /// `gemini_live` の `sendAudio()` は `audio/pcm` 固定でレートを送らないので、
  /// そちらは使わず `sendRealtimeInput` に自分で Blob を渡す。
  static String get inputMimeType => 'audio/pcm;rate=${MicStream.sampleRate}';

  /// 与えられた時間が切れる何秒前に取り直すか。
  ///
  /// 期限が来るとセッションごと切られるので、その前に次を確保して繋ぎ直す。
  /// 短すぎると間に合わず、長すぎると使わないまま枠を捨てることになる。
  static const Duration renewBefore = Duration(seconds: 20);

  /// 接続パラメータ。**config を送らない。**
  static LiveConnectParameters connectParameters({
    required String model,
    required LiveCallbacks callbacks,
  }) {
    return LiveConnectParameters(model: model, callbacks: callbacks);
  }
}
