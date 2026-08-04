import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

/// マイク入力を Gemini Live が受け取れる形（16kHz / モノラル / PCM16）で流す。
///
/// ## ノイズ抑制について
///
/// `.claude/docs/asr-noise-2026.md` の結論は「**ASR の前段にノイズ抑制を
/// 追加してはいけない**」で、否定しているのは**自前で足す抑制段**。
/// 同文書 §10 の実装判断は「プラットフォーム標準の抑制は維持する」なので、
/// [RecordConfig.noiseSuppress] は有効のままにする。
///
/// [RecordConfig.echoCancel] は品質の話ではなく**成立条件**。
/// 切るとスピーカーから出た AI の声を自分のマイクが拾い、
/// 自分の発話で自分を割り込ませて会話が壊れる。
class MicStream {
  MicStream({AudioRecorder? recorder}) : _rec = recorder ?? AudioRecorder();

  final AudioRecorder _rec;
  StreamSubscription<Uint8List>? _sub;
  final _out = StreamController<Uint8List>.broadcast();
  final _level = StreamController<double>.broadcast();
  final _chunker = PcmChunker(bytesPerChunk: chunkBytes);

  /// Gemini Live の入力レート。出力の 24kHz と取り違えないこと。
  static const int sampleRate = 16000;

  /// 送出の単位。100ms ぶん。細切れに送ると WebSocket のフレームが増えるだけで、
  /// 大きくすると発話終了の検知が遅れる。
  static const int chunkBytes = sampleRate * 2 ~/ 10;

  /// 100ms ごとの PCM16。そのまま `session.sendRealtimeInput` に渡せる。
  Stream<Uint8List> get chunks => _out.stream;

  /// 0.0〜1.0 のピーク音量。「聞いている」表示と録音異常の判定に使う。
  Stream<double> get level => _level.stream;

  bool get isRecording => _sub != null;

  Future<bool> hasPermission() => _rec.hasPermission();

  /// 録音を開始する。権限が無ければ false。
  ///
  /// [speakerphone] を false にすると Android では通話用スピーカー（耳に当てる方）
  /// から音が出る。会話アプリとしては据え置きで使うので既定は true。
  Future<bool> start({bool speakerphone = true}) async {
    if (_sub != null) return true;
    if (!await _rec.hasPermission()) return false;

    final stream = await _rec.startStream(RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: sampleRate,
      numChannels: 1,
      echoCancel: true,
      noiseSuppress: true,
      // AGC は入れない。音量を機械が動かすと、こちらが持つピーク値の意味が消える
      autoGain: false,
      androidConfig: AndroidRecordConfig(
        audioSource: AndroidAudioSource.voiceCommunication,
        // これを入れないと AEC が出力側を参照できず、端末によっては
        // AI の声を自分で拾って自己割り込みする
        audioManagerMode: AudioManagerMode.modeInCommunication,
        speakerphone: speakerphone,
      ),
      // iOS 既定（defaultToSpeaker + Bluetooth 許可）のままでよい
      iosConfig: const IosRecordConfig(),
    ));

    _chunker.reset();
    _sub = stream.listen(
      (data) {
        _level.add(peakOf(data));
        for (final chunk in _chunker.add(data)) {
          _out.add(chunk);
        }
      },
      onError: _out.addError,
      cancelOnError: false,
    );
    return true;
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    // 端数を出し切る。切り捨てると語尾が落ちる
    final tail = _chunker.flush();
    if (tail != null) _out.add(tail);
    if (await _rec.isRecording()) await _rec.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _out.close();
    await _level.close();
    await _rec.dispose();
  }
}

/// PCM16 リトルエンディアンのピーク音量を 0.0〜1.0 で返す。
double peakOf(Uint8List pcm) {
  if (pcm.length < 2) return 0;
  final view = ByteData.sublistView(pcm);
  final samples = pcm.length ~/ 2;
  var peak = 0;
  for (var i = 0; i < samples; i++) {
    final v = view.getInt16(i * 2, Endian.little).abs();
    if (v > peak) peak = v;
  }
  // -32768 の絶対値は 32768。32767 で割ると 1.0 を超える
  return (peak / 32768).clamp(0.0, 1.0);
}

/// 録音の異常。`jiyu-kenkyu-ai/lib/telemetry.ts` のしきい値を移植したもの。
enum RecordingIssue {
  /// ほぼ無音。マイクが塞がれているか、権限はあるが拾えていない
  silent,

  /// 音量が小さい。マイクが遠い
  quiet,

  /// 歪んでいる。近すぎるか音量過大
  clipped,
}

/// ピーク値の列から録音の異常を判定する。異常が無ければ null。
///
/// **抑制で救おうとしないこと。** 効くのはマイク距離と会場の静けさで、
/// 前処理では戻らない（`asr-noise-2026.md` §2, §5）。
RecordingIssue? diagnose(List<double> peaks) {
  if (peaks.isEmpty) return null;
  var maxPeak = 0.0;
  var clippedCount = 0;
  for (final p in peaks) {
    if (p > maxPeak) maxPeak = p;
    if (p >= 0.99) clippedCount++;
  }
  if (maxPeak < 0.02) return RecordingIssue.silent;
  if (clippedCount / peaks.length > 0.05) return RecordingIssue.clipped;
  if (maxPeak < 0.08) return RecordingIssue.quiet;
  return null;
}

/// 可変長で届くバイト列を固定長のチャンクに詰め直す。
///
/// プラットフォームが返す1回ぶんの長さは端末任せで、そのまま送ると
/// フレームが細切れになったり大きすぎたりする。
class PcmChunker {
  PcmChunker({required this.bytesPerChunk})
      : assert(bytesPerChunk > 0 && bytesPerChunk.isEven);

  final int bytesPerChunk;
  final BytesBuilder _buf = BytesBuilder(copy: true);

  /// 溜まったぶんだけ固定長チャンクを返す。足りなければ空。
  ///
  /// 返すのは**コピー**。ビューを返すと、受け手が `.buffer` を触ったときに
  /// 裏のバッファ全体を掴んでしまう
  List<Uint8List> add(Uint8List data) {
    _buf.add(data);
    if (_buf.length < bytesPerChunk) return const [];

    final all = _buf.takeBytes(); // takeBytes は内部を空にする
    final out = <Uint8List>[];
    var i = 0;
    while (all.length - i >= bytesPerChunk) {
      out.add(all.sublist(i, i + bytesPerChunk));
      i += bytesPerChunk;
    }
    if (i < all.length) _buf.add(all.sublist(i));
    return out;
  }

  /// 端数を吐き出す。16bit 境界は保つ。
  Uint8List? flush() {
    if (_buf.isEmpty) return null;
    final all = _buf.takeBytes();
    final usable = all.length.isEven ? all : all.sublist(0, all.length - 1);
    return usable.isEmpty ? null : usable;
  }

  void reset() => _buf.clear();
}
