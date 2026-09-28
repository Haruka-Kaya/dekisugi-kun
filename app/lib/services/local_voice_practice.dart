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
    this.playbackCompleted = false,
  });

  final LocalVoicePracticeState state;
  final int recordedBytes;
  final Duration duration;

  /// 現在の録音を途中停止せず最後まで再生した場合だけtrue。
  ///
  /// 再生ボタンを押した事実ではなく、本人が説明を聞き返した事実を画面の
  /// 進行条件にする。録り直し・clear・再生中断ではfalseへ戻る。
  final bool playbackCompleted;

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
  BytesBuilder _recording = BytesBuilder(copy: true);
  Uint8List? _recorded;
  Future<void>? _stopInFlight;
  Future<void>? _disposeInFlight;
  int _recordingStartGeneration = 0;
  int _nextRecordingSession = 0;
  int? _activeRecordingSession;
  int _playbackGeneration = 0;
  // stopが失敗した場合、UI状態を変えてもnative録音は続いている可能性がある。
  // stop成功またはMicStream.dispose完了までこの事実を保持する。
  bool _micMayBeRecording = false;
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
    // 前回のstop失敗を、次の録音開始で上書きしない。ここ自体を再試行口にする。
    if (_micMayBeRecording && !await _stopMicSafely()) {
      _emit(LocalVoicePracticeState.failed);
      return false;
    }
    await stopPlayback();
    if (_disposed) return false;
    final startGeneration = ++_recordingStartGeneration;
    final recordingSession = ++_nextRecordingSession;
    _wipeRecorded();
    _wipeBuilder();

    StreamSubscription<Uint8List>? subscription;
    try {
      subscription = _mic.chunks.listen(
        (chunk) => _onChunk(recordingSession, chunk),
        onError: (_) => unawaited(_failRecording(recordingSession)),
        cancelOnError: false,
      );
      _chunkSubscription = subscription;
      _activeRecordingSession = recordingSession;
      // startStream直後の最初のPCMを落とさないよう、購読と状態を先に整える。
      _emit(LocalVoicePracticeState.recording);
      // startが例外終了してもnativeだけ開始済みの可能性を捨てない。
      _micMayBeRecording = true;
      final started = await _mic.start();
      _micMayBeRecording = started;
      final stale =
          _disposed ||
          startGeneration != _recordingStartGeneration ||
          _activeRecordingSession != recordingSession ||
          _snapshot.state != LocalVoicePracticeState.recording;
      if (stale) {
        _cancelChunkSubscription(subscription);
        if (started) {
          final stopped = await _stopMicSafely();
          if (!stopped && !_disposed) _emit(LocalVoicePracticeState.failed);
        }
        return false;
      }
      if (!started) {
        _cancelChunkSubscription(subscription);
        _emit(LocalVoicePracticeState.permissionDenied);
        return false;
      }

      _recordingTimer = Timer(recordingLimit, () => unawaited(stopRecording()));
      return true;
    } catch (_) {
      final current =
          !_disposed &&
          startGeneration == _recordingStartGeneration &&
          _activeRecordingSession == recordingSession;
      if (current) {
        await _failRecording(recordingSession);
      } else {
        _cancelChunkSubscription(subscription);
        final stopped = await _stopMicSafely();
        if (!stopped && !_disposed) _emit(LocalVoicePracticeState.failed);
      }
      return false;
    }
  }

  Future<void> stopRecording() {
    if (_disposed ||
        (_snapshot.state != LocalVoicePracticeState.recording &&
            !_micMayBeRecording)) {
      return Future<void>.value();
    }
    final inFlight = _stopInFlight;
    if (inFlight != null) return inFlight;
    // mic.start()が未完了でも、その継続がtimerを再作成しないよう同期的に無効化する。
    _recordingStartGeneration++;
    return _stopInFlight ??= _stopRecordingImpl().whenComplete(() {
      _stopInFlight = null;
    });
  }

  Future<void> _stopRecordingImpl() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    final subscription = _chunkSubscription;
    // MicStream.stopは語尾の端数をchunksへflushする。購読はその後に切る。
    final stopped = await _stopMicSafely();
    _cancelChunkSubscription(subscription);
    if (_disposed) return;
    if (!stopped) {
      _wipeBuilder();
      _wipeRecorded();
      _emit(LocalVoicePracticeState.failed);
      return;
    }
    if (_snapshot.state != LocalVoicePracticeState.recording) return;

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
    if (_disposed) return false;
    final operation = ++_playbackGeneration;
    late final Future<bool> drained;
    try {
      await _player.init();
      if (_disposed || operation != _playbackGeneration) return false;
      drained = _player.enqueueUntilDrained(_recorded!);
    } catch (_) {
      _failPlayback(operation);
      return false;
    }
    if (_disposed || operation != _playbackGeneration) {
      _player.stopNow();
      return false;
    }
    _emit(LocalVoicePracticeState.playing);
    unawaited(_finishPlaybackWhenDrained(operation, drained));
    return true;
  }

  Future<void> stopPlayback() async {
    _playbackGeneration++;
    _player.stopNow();
    if (!_disposed && _snapshot.state == LocalVoicePracticeState.playing) {
      _emit(LocalVoicePracticeState.recorded);
    }
  }

  /// 録り直し・文字入力への切替時に、現在の音声だけを破棄する。
  Future<void> clear() async {
    if (_disposed) return;
    if (_snapshot.state == LocalVoicePracticeState.recording ||
        _micMayBeRecording) {
      await stopRecording();
    }
    await stopPlayback();
    _wipeRecorded();
    _wipeBuilder();
    _emit(
      _micMayBeRecording
          ? LocalVoicePracticeState.failed
          : LocalVoicePracticeState.idle,
    );
  }

  Future<void> _failRecording(int recordingSession) async {
    if (_disposed || _activeRecordingSession != recordingSession) return;
    _recordingStartGeneration++;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    await _stopMicSafely();
    _cancelChunkSubscription();
    _wipeBuilder();
    _wipeRecorded();
    if (!_disposed) _emit(LocalVoicePracticeState.failed);
  }

  void _onChunk(int recordingSession, Uint8List chunk) {
    if (_disposed ||
        _activeRecordingSession != recordingSession ||
        _snapshot.state != LocalVoicePracticeState.recording) {
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

  void _emit(LocalVoicePracticeState state, {bool playbackCompleted = false}) {
    if (_disposed && state != LocalVoicePracticeState.disposed) return;
    final bytes = _recorded?.length ?? _recording.length;
    _snapshot = LocalVoicePracticeSnapshot(
      state: state,
      recordedBytes: bytes,
      duration: _durationForBytes(bytes),
      playbackCompleted: playbackCompleted,
    );
    if (!_changes.isClosed) _changes.add(_snapshot);
  }

  Duration _durationForBytes(int bytes) => Duration(
    microseconds: bytes * Duration.microsecondsPerSecond ~/ bytesPerSecond,
  );

  void _cancelChunkSubscription([StreamSubscription<Uint8List>? expected]) {
    final subscription = expected ?? _chunkSubscription;
    if (expected == null || identical(_chunkSubscription, expected)) {
      _chunkSubscription = null;
      _activeRecordingSession = null;
    }
    // cancelを呼んだ時点で新しいイベントは配送されない。native側の非同期cleanupを
    // 画面状態の更新待ちにせず、遅い端末でも拒否・停止をすぐUIへ返す。
    if (subscription != null) {
      unawaited(_cancelSubscriptionSilently(subscription));
    }
  }

  Future<void> _cancelSubscriptionSilently(
    StreamSubscription<Uint8List> subscription,
  ) async {
    try {
      await subscription.cancel();
    } catch (_) {
      // 通常操作ではUIを詰まらせない。route disposeでは別途awaitして記録する。
    }
  }

  Future<bool> _stopMicSafely() async {
    if (!_micMayBeRecording) return true;
    try {
      await _mic.stop();
      _micMayBeRecording = false;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _finishPlaybackWhenDrained(
    int operation,
    Future<bool> drained,
  ) async {
    final completed = await drained;
    if (_disposed ||
        operation != _playbackGeneration ||
        _snapshot.state != LocalVoicePracticeState.playing) {
      return;
    }
    if (completed) {
      _emit(LocalVoicePracticeState.recorded, playbackCompleted: true);
    } else {
      _failPlayback(operation);
    }
  }

  void _failPlayback(int operation) {
    if (_disposed || operation != _playbackGeneration) return;
    _playbackGeneration++;
    _player.stopNow();
    _emit(LocalVoicePracticeState.failed);
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
    _recordingStartGeneration++;
    _playbackGeneration++;
    _recordingTimer?.cancel();
    _recordingTimer = null;

    Object? firstError;
    StackTrace? firstStack;
    void remember(Object error, StackTrace stack) {
      firstError ??= error;
      firstStack ??= stack;
    }

    Future<void> attempt(Future<void> Function() action) async {
      try {
        await action();
      } catch (error, stack) {
        remember(error, stack);
      }
    }

    // route破棄と同じ同期区間で、参照可能なPCMを先に消す。native停止のawait中に
    // RAMへ回答が残り続けないようにする。
    await attempt(() async => _player.stopNow());
    _wipeRecorded();
    _wipeBuilder();
    _snapshot = const LocalVoicePracticeSnapshot(
      state: LocalVoicePracticeState.disposed,
      recordedBytes: 0,
      duration: Duration.zero,
    );
    if (!_changes.isClosed) {
      try {
        _changes.add(_snapshot);
      } catch (error, stack) {
        remember(error, stack);
      }
    }
    // 1回目が失敗してもroute破棄中にもう一度停止を試す。dispose自体は最後の
    // 防波堤なので、失敗状態のままでもMicStream.disposeまで必ず進める。
    if (!await _stopMicSafely()) await _stopMicSafely();

    final subscription = _chunkSubscription;
    _chunkSubscription = null;
    _activeRecordingSession = null;
    final cleanups = <Future<void>>[];
    if (subscription != null) {
      cleanups.add(attempt(subscription.cancel));
    }

    cleanups.add(attempt(_player.dispose));

    cleanups.add(
      attempt(() async {
        await _mic.dispose();
        // disposeが例外終了したならnative停止は保証できない。falseへ偽装しない。
        _micMayBeRecording = false;
      }),
    );

    cleanups.add(attempt(_changes.close));
    // 1つのplugin Futureが止まっても、他のnative/controller cleanupは開始済みにする。
    await Future.wait(cleanups);

    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStack!);
    }
  }

  static Duration _boundedLimit(Duration value) {
    if (value <= Duration.zero) return const Duration(milliseconds: 1);
    if (value > maxRecordingDuration) return maxRecordingDuration;
    return value;
  }
}
