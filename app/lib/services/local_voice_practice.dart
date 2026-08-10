import 'dart:async';
import 'dart:typed_data';

import 'mic_stream.dart';
import 'pcm_player.dart';

enum LocalVoicePracticeState {
  idle,
  recording,
  recorded,
  playing,
  permissionDenied,
  failed,
  disposed,
}

class LocalVoicePracticeSnapshot {
  const LocalVoicePracticeSnapshot({
    required this.state,
    required this.recordedBytes,
    required this.duration,
  });

  final LocalVoicePracticeState state;
  final int recordedBytes;
  final Duration duration;

  bool get hasRecording => recordedBytes > 0;
}

/// 端末内の説明を、16kHz/mono/PCM16のままRAMだけに保持して聞き返す。
///
/// ファイル、設定、DB、ネットワーク、ASRには一切渡さない。最大60秒で受け取りを
/// 打ち切り、[dispose]で未再生キューを止めてバイト列もゼロ埋めして破棄する。
class LocalVoicePractice {
  LocalVoicePractice({
    MicStream? mic,
    PcmPlayer? player,
    Duration recordingLimit = maxRecordingDuration,
  }) : _mic = mic ?? MicStream(),
       _player = player ?? PcmPlayer(playbackSampleRate: MicStream.sampleRate),
       recordingLimit = _boundedLimit(recordingLimit),
       _snapshot = const LocalVoicePracticeSnapshot(
         state: LocalVoicePracticeState.idle,
         recordedBytes: 0,
         duration: Duration.zero,
       );

  static const Duration maxRecordingDuration = Duration(seconds: 60);
  static const int bytesPerSecond = MicStream.sampleRate * 2;
  static const int maxRecordingBytes = bytesPerSecond * 60;

  final MicStream _mic;
  final PcmPlayer _player;
  final Duration recordingLimit;
  final _changes = StreamController<LocalVoicePracticeSnapshot>.broadcast();

  LocalVoicePracticeSnapshot _snapshot;
  LocalVoicePracticeSnapshot get snapshot => _snapshot;
  Stream<LocalVoicePracticeSnapshot> get changes => _changes.stream;

  StreamSubscription<Uint8List>? _chunkSubscription;
  Timer? _recordingTimer;
  Timer? _playbackTimer;
  BytesBuilder _recording = BytesBuilder(copy: true);
  Uint8List? _recorded;
  Future<void>? _stopInFlight;
  Future<void>? _disposeInFlight;
  bool _disposed = false;

  int get _limitBytes {
    final bytes =
        bytesPerSecond *
        recordingLimit.inMicroseconds ~/
        Duration.microsecondsPerSecond;
    return bytes.clamp(2, maxRecordingBytes).toInt() & ~1;
  }

  bool get isDisposed => _disposed;

  /// 権限拒否ならfalse。OSの権限ダイアログ以外の外部処理は行わない。
  Future<bool> startRecording() async {
    if (_disposed || _snapshot.state == LocalVoicePracticeState.recording) {
      return false;
    }
    await stopPlayback();
    _wipeRecorded();
    _wipeBuilder();

    _chunkSubscription = _mic.chunks.listen(
      _onChunk,
      onError: (_) => unawaited(_failRecording()),
      cancelOnError: false,
    );
    // startStream直後の最初のPCMを落とさないよう、購読と状態を先に整える。
    _emit(LocalVoicePracticeState.recording);
    final started = await _mic.start();
    if (_disposed) {
      await _mic.stop();
      _cancelChunkSubscription();
      return false;
    }
    if (!started) {
      _cancelChunkSubscription();
      _emit(LocalVoicePracticeState.permissionDenied);
      return false;
    }

    _recordingTimer = Timer(recordingLimit, () => unawaited(stopRecording()));
    return true;
  }

  Future<void> stopRecording() {
    if (_disposed || _snapshot.state != LocalVoicePracticeState.recording) {
      return Future<void>.value();
    }
    return _stopInFlight ??= _stopRecordingImpl().whenComplete(() {
      _stopInFlight = null;
    });
  }

  Future<void> _stopRecordingImpl() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    // MicStream.stopは語尾の端数をchunksへflushする。購読はその後に切る。
    await _mic.stop();
    _cancelChunkSubscription();
    if (_disposed) return;

    _wipeRecorded();
    _recorded = _recording.takeBytes();
    _recording = BytesBuilder(copy: true);
    _emit(
      _recorded!.isEmpty
          ? LocalVoicePracticeState.idle
          : LocalVoicePracticeState.recorded,
    );
  }

  /// 録音を16kHzのまま再生する。録音が無いときはfalse。
  Future<bool> playRecording() async {
    if (_disposed || _recorded == null || _recorded!.isEmpty) return false;
    await stopPlayback();
    await _player.init();
    if (_disposed) return false;

    _player.enqueue(_recorded!);
    _emit(LocalVoicePracticeState.playing);
    _playbackTimer = Timer(_durationForBytes(_recorded!.length), () {
      if (!_disposed && _snapshot.state == LocalVoicePracticeState.playing) {
        _emit(LocalVoicePracticeState.recorded);
      }
    });
    return true;
  }

  Future<void> stopPlayback() async {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _player.stopNow();
    if (!_disposed && _snapshot.state == LocalVoicePracticeState.playing) {
      _emit(LocalVoicePracticeState.recorded);
    }
  }

  /// 録り直し・文字入力への切替時に、現在の音声だけを破棄する。
  Future<void> clear() async {
    if (_disposed) return;
    if (_snapshot.state == LocalVoicePracticeState.recording) {
      await stopRecording();
    }
    await stopPlayback();
    _wipeRecorded();
    _wipeBuilder();
    _emit(LocalVoicePracticeState.idle);
  }

  Future<void> _failRecording() async {
    if (_disposed) return;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    await _mic.stop();
    _cancelChunkSubscription();
    _wipeBuilder();
    _wipeRecorded();
    if (!_disposed) _emit(LocalVoicePracticeState.failed);
  }

  void _onChunk(Uint8List chunk) {
    if (_disposed || _snapshot.state != LocalVoicePracticeState.recording) {
      return;
    }
    final remaining = _limitBytes - _recording.length;
    if (remaining <= 0) {
      unawaited(stopRecording());
      return;
    }
    var take = chunk.length < remaining ? chunk.length : remaining;
    if (take.isOdd) take--;
    if (take > 0) _recording.add(Uint8List.sublistView(chunk, 0, take));
    _emit(LocalVoicePracticeState.recording);
    if (_recording.length >= _limitBytes) unawaited(stopRecording());
  }

  void _emit(LocalVoicePracticeState state) {
    if (_disposed && state != LocalVoicePracticeState.disposed) return;
    final bytes = _recorded?.length ?? _recording.length;
    _snapshot = LocalVoicePracticeSnapshot(
      state: state,
      recordedBytes: bytes,
      duration: _durationForBytes(bytes),
    );
    if (!_changes.isClosed) _changes.add(_snapshot);
  }

  Duration _durationForBytes(int bytes) => Duration(
    microseconds: bytes * Duration.microsecondsPerSecond ~/ bytesPerSecond,
  );

  void _cancelChunkSubscription() {
    final subscription = _chunkSubscription;
    _chunkSubscription = null;
    // cancelを呼んだ時点で新しいイベントは配送されない。native側の非同期cleanupを
    // 画面状態の更新待ちにせず、遅い端末でも拒否・停止をすぐUIへ返す。
    unawaited(subscription?.cancel());
  }

  void _wipeRecorded() {
    _recorded?.fillRange(0, _recorded!.length, 0);
    _recorded = null;
  }

  void _wipeBuilder() {
    if (_recording.isNotEmpty) {
      final bytes = _recording.takeBytes();
      bytes.fillRange(0, bytes.length, 0);
    }
    _recording = BytesBuilder(copy: true);
  }

  Future<void> dispose() => _disposeInFlight ??= _disposeImpl();

  Future<void> _disposeImpl() async {
    if (_disposed) return;
    _disposed = true;
    _recordingTimer?.cancel();
    _playbackTimer?.cancel();
    _recordingTimer = null;
    _playbackTimer = null;

    // route破棄と同じ同期区間で、参照可能なPCMを先に消す。native停止のawait中に
    // RAMへ回答が残り続けないようにする。
    _player.stopNow();
    _wipeRecorded();
    _wipeBuilder();
    _snapshot = const LocalVoicePracticeSnapshot(
      state: LocalVoicePracticeState.disposed,
      recordedBytes: 0,
      duration: Duration.zero,
    );
    if (!_changes.isClosed) _changes.add(_snapshot);
    await _mic.stop();
    _cancelChunkSubscription();
    await _player.dispose();
    await _mic.dispose();
    await _changes.close();
  }

  static Duration _boundedLimit(Duration value) {
    if (value <= Duration.zero) return const Duration(milliseconds: 1);
    if (value > maxRecordingDuration) return maxRecordingDuration;
    return value;
  }
}
