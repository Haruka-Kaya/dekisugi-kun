import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

/// Gemini Live が返す 24kHz / モノラル / PCM16 のストリームを再生する。
///
/// ## なぜ自前でキューを持つのか
///
/// `flutter_pcm_sound` には **キューを空にする API が無い**（`setup` で作り直すか
/// `release` で壊すかの2択）。届いた音を全部 `feed()` してしまうと、
/// 生徒が割り込んで喋りはじめても AI の声が最後まで鳴り続ける。
///
/// なので**再生待ちの音は Dart 側で保持し、native には常に少量しか渡さない**。
/// 割り込みが来たら Dart 側のキューを捨てる。すでに native に渡した分は鳴るが、
/// その量は [_thresholdFrames] + [_chunkFrames] を超えない（既定で約100ms）。
///
/// ## 公式 example を踏襲しなかった理由
///
/// `gemini_live` の example はターン全体をバッファして WAV ヘッダを付けてから
/// `audioplayers` で鳴らす。生成が終わるまで一切音が出ないので、会話には使えない。
class PcmPlayer {
  PcmPlayer({PcmSink? sink}) : _sink = sink ?? const FlutterPcmSink();

  final PcmSink _sink;

  /// Gemini Live の出力レート。入力の 16kHz とは違うので取り違えないこと。
  static const int sampleRate = 24000;

  /// native のキューがこれを下回ったら補充する。
  static const int _thresholdFrames = 1200; // 50ms @24kHz

  /// 1回の補充量。
  static const int _chunkFrames = 1200; // 50ms @24kHz

  /// 割り込み時に鳴り残る最大時間。**この値が割り込みの体感を決める。**
  static Duration get maxResidual => Duration(
      microseconds:
          ((_thresholdFrames + _chunkFrames) * 1000000 / sampleRate).round());

  final Queue<Uint8List> _pending = Queue<Uint8List>();
  final _level = StreamController<double>.broadcast();
  int _pendingBytes = 0;
  bool _ready = false;
  bool _disposed = false;

  /// いま native へ渡した音の大きさ（0.0〜1.0）。
  ///
  /// キャラクターの動きをこれで駆動する。**口は動かさない** —
  /// Gemini Live は音素タイミングを返さないので、口の形は作れない。
  /// 体の上下は振幅の包絡でよく、音素の精度を主張しない。
  ///
  /// 50ms 先読みで渡しているので、実際に鳴る音より 50〜100ms 早い。
  Stream<double> get level => _level.stream;

  /// 再生待ちのバイト数。テストと画面の状態表示に使う。
  int get pendingBytes => _pendingBytes;

  bool get hasPending => _pendingBytes > 0;

  Future<void> init() async {
    if (_ready || _disposed) return;
    await _sink.setLogLevel(LogLevel.none);
    await _sink.setup(sampleRate: sampleRate, channelCount: 1);
    await _sink.setFeedThreshold(_thresholdFrames);
    _sink.setFeedCallback(_onFeed);
    _ready = true;
  }

  /// 届いた PCM16 チャンクを再生待ちに積む。
  void enqueue(Uint8List pcm) {
    if (_disposed || pcm.isEmpty) return;
    // 奇数バイトは 16bit サンプルとして解釈できない。落として境界を守る
    final usable = pcm.length.isEven ? pcm : pcm.sublist(0, pcm.length - 1);
    if (usable.isEmpty) return;
    _pending.add(usable);
    _pendingBytes += usable.length;
    // 止まっていたら鳴らしはじめる（native 側は「一度 feed されるまで」動かない）
    _sink.start();
  }

  /// 割り込み。**再生待ちを捨てる。**
  ///
  /// すでに native に渡した分は鳴り切る（最大 [maxResidual]）。
  /// ここで `setup` をやり直せば即座に黙らせられるが、AudioTrack を作り直すので
  /// プツッと鳴るうえ、次の発話までの遅延が増える。割り切って捨てるだけにする。
  void stopNow() {
    _pending.clear();
    _pendingBytes = 0;
    // 捨てた瞬間に静かになったことを伝える。
    // 伝えないと、割り込んだのにキャラが揺れ続ける
    if (!_disposed) _level.add(0);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    stopNow();
    _disposed = true;
    _sink.setFeedCallback(null);
    if (_ready) await _sink.release();
    _ready = false;
    await _level.close();
  }

  /// native から「キューが減った」と呼ばれる。要求量だけ渡す。
  void _onFeed(int remainingFrames) {
    if (_disposed) return;
    final chunk = _take(_chunkFrames * 2);
    if (chunk == null) {
      // 渡すものが無い＝鳴り終わる。次の enqueue で start() が掛かる
      _level.add(0);
      return;
    }
    _level.add(_peakOf(chunk));
    _sink.feed(PcmArrayInt16(bytes: ByteData.sublistView(chunk)));
  }

  /// PCM16 リトルエンディアンのピークを 0.0〜1.0 で返す。
  static double _peakOf(Uint8List pcm) {
    final view = ByteData.sublistView(pcm);
    final samples = pcm.length ~/ 2;
    var peak = 0;
    // 全サンプルは見ない。50ms ぶんを 8点まで間引いても包絡は十分取れる
    final step = samples <= 8 ? 1 : samples ~/ 8;
    for (var i = 0; i < samples; i += step) {
      final v = view.getInt16(i * 2, Endian.little).abs();
      if (v > peak) peak = v;
    }
    // -32768 の絶対値は 32768。32767 で割ると 1.0 を超える
    return (peak / 32768).clamp(0.0, 1.0);
  }

  /// 先頭から最大 [maxBytes] を切り出す。チャンク境界をまたいで詰める。
  Uint8List? _take(int maxBytes) {
    if (_pending.isEmpty) return null;
    final want = maxBytes < _pendingBytes ? maxBytes : _pendingBytes;
    // 新しい ByteBuffer を確保する。ここは必ずコピーすること —
    // feed() は ByteData ではなく **裏の ByteBuffer 全体**を native に渡すので、
    // 他人のバッファのビューを渡すと無関係な音まで再生される
    final out = Uint8List(want);
    var filled = 0;
    while (filled < want) {
      final head = _pending.first;
      final take = head.length <= want - filled ? head.length : want - filled;
      out.setRange(filled, filled + take, head);
      filled += take;
      if (take == head.length) {
        _pending.removeFirst();
      } else {
        _pending.removeFirst();
        _pending.addFirst(Uint8List.sublistView(head, take));
      }
    }
    _pendingBytes -= want;
    return out;
  }
}

/// native 再生の口。テストで差し替えるために抽象化してある。
abstract class PcmSink {
  Future<void> setLogLevel(LogLevel level);
  Future<void> setup({required int sampleRate, required int channelCount});
  Future<void> setFeedThreshold(int frames);
  void setFeedCallback(void Function(int remainingFrames)? cb);
  void feed(PcmArrayInt16 buffer);
  void start();
  Future<void> release();
}

class FlutterPcmSink implements PcmSink {
  const FlutterPcmSink();

  @override
  Future<void> setLogLevel(LogLevel level) => FlutterPcmSound.setLogLevel(level);

  @override
  Future<void> setup({required int sampleRate, required int channelCount}) =>
      FlutterPcmSound.setup(
        sampleRate: sampleRate,
        channelCount: channelCount,
        // 録音と同時に鳴らすので playAndRecord。既定の playback だと録音が止まる
        iosAudioCategory: IosAudioCategory.playAndRecord,
      );

  @override
  Future<void> setFeedThreshold(int frames) =>
      FlutterPcmSound.setFeedThreshold(frames);

  @override
  void setFeedCallback(void Function(int remainingFrames)? cb) =>
      FlutterPcmSound.setFeedCallback(cb);

  @override
  void feed(PcmArrayInt16 buffer) => FlutterPcmSound.feed(buffer);

  @override
  void start() => FlutterPcmSound.start();

  @override
  Future<void> release() => FlutterPcmSound.release();
}
