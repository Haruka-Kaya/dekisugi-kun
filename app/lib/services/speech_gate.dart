/// マイクの音量から「生徒がいま喋っているか」を端末側で判定する。
///
/// ## なぜサーバの VAD を待たないのか
///
/// 実機の voice-to-voice は約1.3秒。日本語のターン間ギャップは平均+7ms で
/// 10言語中もっとも短く、**沈黙を人間が許す時間が他言語より短い**。
/// この差は技術では埋まらないので UI で埋める — 発話が終わった瞬間に
/// キャラが反応する層を先に出し、音声は後から乗せる。
///
/// そのためには「終わった」を**サーバの応答を待たずに**知る必要がある。
///
/// > [!warning] ここは表示だけの仕組みではない
/// > Vertex は自動VADが働かず、`activityStart` / `activityEnd` で囲まないと
/// > 音声を黙って捨てる。つまりこの判定が**何を送るかも決めている。**
/// > 狂うと会話そのものが成立しない。
///
/// しきい値は AEC / ノイズ抑制の効き方で端末ごとに変わる。実機で詰めること。
class SpeechGate {
  SpeechGate({
    this.onThreshold = 0.06,
    this.offThreshold = 0.03,
    this.hangover = const Duration(milliseconds: 400),
  }) : assert(offThreshold < onThreshold, 'ヒステリシスが逆だと境界で振動する');

  /// 喋りはじめたと判定する音量。
  final double onThreshold;

  /// 喋り終わったと判定する音量。[onThreshold] より低くしてヒステリシスを作る。
  final double offThreshold;

  /// この時間だけ静かなら「終わった」とする。
  /// 短すぎると句読点の間で切れ、長すぎると反応が鈍く見える。
  final Duration hangover;

  bool _speaking = false;
  Duration? _quietSince;

  bool get isSpeaking => _speaking;

  /// 音量を1つ食わせる。状態が変わったら true。
  ///
  /// [now] は単調増加する時刻。`Stopwatch.elapsed` を渡す想定で、
  /// テストから時間を進められるように外から与える。
  ///
  /// [muted] は「いまマイクを聞かない」— AI が喋っている間に立てる。
  /// **しきい値を上げるのではなく閉じる。** スピーカーは端末上にあり
  /// 生徒は数十センチ先なので、AI の声のほうが大きいのが普通で、
  /// どこにしきい値を置いても AI を通すか生徒を切るかのどちらかになる
  /// （AEC が存在するのはこれが解けないため）。
  bool update(double peak, Duration now, {bool muted = false}) {
    if (muted) {
      // 閉じるときは必ず状態変化を返す。返さないと `activityEnd` が送られず、
      // モデルは生徒の発話がまだ続いていると思って待ち続ける
      if (!_speaking) return false;
      _speaking = false;
      _quietSince = null;
      return true;
    }

    if (_speaking) {
      if (peak >= offThreshold) {
        _quietSince = null;
        return false;
      }
      _quietSince ??= now;
      if (now - _quietSince! >= hangover) {
        _speaking = false;
        _quietSince = null;
        return true;
      }
      return false;
    }

    if (peak >= onThreshold) {
      _speaking = true;
      _quietSince = null;
      return true;
    }
    return false;
  }

  void reset() {
    _speaking = false;
    _quietSince = null;
  }
}
