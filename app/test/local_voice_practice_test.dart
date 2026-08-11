import 'dart:async';
import 'dart:typed_data';

import 'package:dekisugi/services/local_voice_practice.dart';
import 'package:dekisugi/services/mic_stream.dart';
import 'package:dekisugi/services/pcm_player.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMic extends MicStream {
  _FakeMic({this.allowed = true});

  bool allowed;
  Completer<bool>? startGate;
  int? throwOnStartCall;
  int? throwOnStopCall;
  final Set<int> throwOnStopCalls = <int>{};
  bool throwOnEveryStop = false;
  bool stopThrowsSynchronously = false;
  bool throwOnDisposeAfterCleanup = false;
  bool preserveStartedOnDisposeFailure = false;
  final _chunks = StreamController<Uint8List>.broadcast();
  final _levels = StreamController<double>.broadcast();
  bool started = false;
  bool disposed = false;
  int startCalls = 0;
  int stopCalls = 0;

  @override
  Stream<Uint8List> get chunks => _chunks.stream;

  @override
  Stream<double> get level => _levels.stream;

  @override
  bool get isRecording => started;

  @override
  Future<bool> start({bool speakerphone = true}) async {
    startCalls++;
    if (throwOnStartCall == startCalls) throw StateError('mic start failed');
    final result = startGate == null ? allowed : await startGate!.future;
    started = result;
    return result;
  }

  @override
  Future<void> stop() {
    stopCalls++;
    final fails =
        throwOnEveryStop ||
        throwOnStopCall == stopCalls ||
        throwOnStopCalls.contains(stopCalls);
    if (fails) {
      if (stopThrowsSynchronously) throw StateError('mic stop failed');
      return Future<void>.error(StateError('mic stop failed'));
    }
    started = false;
    return Future<void>.value();
  }

  void emit(Uint8List bytes) => _chunks.add(bytes);

  @override
  Future<void> dispose() async {
    disposed = true;
    if (!preserveStartedOnDisposeFailure) started = false;
    await _chunks.close();
    await _levels.close();
    if (throwOnDisposeAfterCleanup) {
      throw StateError('mic dispose failed');
    }
  }
}

class _FakeSink implements PcmSink {
  void Function(int)? callback;
  int? sampleRate;
  int startCalls = 0;
  int fedBytes = 0;
  bool released = false;
  bool throwOnSetup = false;
  bool throwOnStart = false;
  bool throwOnFeed = false;

  void requestFeed([int remainingFrames = 0]) {
    callback?.call(remainingFrames);
  }

  @override
  Future<void> setLogLevel(LogLevel level) async {}

  @override
  Future<void> setup({
    required int sampleRate,
    required int channelCount,
  }) async {
    if (throwOnSetup) throw StateError('player setup failed');
    this.sampleRate = sampleRate;
  }

  @override
  Future<void> setFeedThreshold(int frames) async {}

  @override
  void setFeedCallback(void Function(int remainingFrames)? cb) {
    callback = cb;
  }

  @override
  Future<void> feed(PcmArrayInt16 buffer) async {
    if (throwOnFeed) throw StateError('player feed failed');
    fedBytes += buffer.bytes.lengthInBytes;
  }

  @override
  void start() {
    startCalls++;
    if (throwOnStart) throw StateError('player enqueue failed');
  }

  @override
  Future<void> release() async {
    released = true;
  }
}

Future<void> _flushAsync() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('権限拒否は音声を作らずpermissionDeniedへ倒す', () async {
    final mic = _FakeMic(allowed: false);
    final sink = _FakeSink();
    final practice = LocalVoicePractice(
      mic: mic,
      player: PcmPlayer(sink: sink, playbackSampleRate: MicStream.sampleRate),
    );

    expect(await practice.startRecording(), isFalse);
    expect(practice.snapshot.state, LocalVoicePracticeState.permissionDenied);
    expect(practice.snapshot.recordedBytes, 0);
    expect(sink.startCalls, 0);

    await practice.dispose();
    expect(mic.disposed, isTrue);
  });

  test('PCMを指定時間のRAM上限で切り、奇数バイトも保持しない', () async {
    final mic = _FakeMic();
    final sink = _FakeSink();
    final practice = LocalVoicePractice(
      mic: mic,
      player: PcmPlayer(sink: sink, playbackSampleRate: MicStream.sampleRate),
      recordingLimit: const Duration(milliseconds: 100),
    );

    expect(LocalVoicePractice.maxRecordingBytes, 16000 * 2 * 60);
    expect(await practice.startRecording(), isTrue);
    mic.emit(Uint8List(5001));
    await _flushAsync();

    expect(practice.snapshot.state, LocalVoicePracticeState.recorded);
    expect(practice.snapshot.recordedBytes, 3200);
    expect(practice.snapshot.recordedBytes.isEven, isTrue);
    expect(practice.snapshot.duration, const Duration(milliseconds: 100));
    expect(mic.started, isFalse, reason: '上限到達時に自動停止する');

    await practice.dispose();
  });

  test('録音を入力と同じ16kHzで再生し、clearでRAMと再生待ちを破棄する', () async {
    final mic = _FakeMic();
    final sink = _FakeSink();
    final player = PcmPlayer(
      sink: sink,
      playbackSampleRate: MicStream.sampleRate,
    );
    final practice = LocalVoicePractice(mic: mic, player: player);

    await practice.startRecording();
    mic.emit(Uint8List(3200));
    await _flushAsync();
    await practice.stopRecording();
    expect(await practice.playRecording(), isTrue);

    expect(sink.sampleRate, 16000);
    expect(sink.startCalls, 1);
    expect(player.pendingBytes, 3200);

    await practice.clear();
    expect(practice.snapshot.state, LocalVoicePracticeState.idle);
    expect(practice.snapshot.recordedBytes, 0);
    expect(practice.snapshot.playbackCompleted, isFalse);
    expect(player.pendingBytes, 0);
    await practice.dispose();
  });

  test('録音を自然終了まで再生した場合だけplaybackCompletedになる', () async {
    final mic = _FakeMic();
    final sink = _FakeSink();
    final practice = LocalVoicePractice(
      mic: mic,
      player: PcmPlayer(sink: sink, playbackSampleRate: MicStream.sampleRate),
    );

    await practice.startRecording();
    mic.emit(Uint8List(3200));
    await _flushAsync();
    await practice.stopRecording();
    expect(practice.snapshot.playbackCompleted, isFalse);

    expect(await practice.playRecording(), isTrue);
    expect(practice.snapshot.playbackCompleted, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(practice.snapshot.state, LocalVoicePracticeState.playing);
    expect(
      practice.snapshot.playbackCompleted,
      isFalse,
      reason: 'wall timerだけでは実際に聞き終えた証拠にならない',
    );

    sink.requestFeed();
    await _flushAsync();
    sink.requestFeed();
    await _flushAsync();
    expect(practice.snapshot.playbackCompleted, isFalse);
    sink.requestFeed();
    await _flushAsync();
    expect(practice.snapshot.state, LocalVoicePracticeState.recorded);
    expect(practice.snapshot.playbackCompleted, isTrue);

    expect(await practice.playRecording(), isTrue);
    sink.requestFeed();
    await practice.stopPlayback();
    expect(practice.snapshot.state, LocalVoicePracticeState.recorded);
    expect(
      practice.snapshot.playbackCompleted,
      isFalse,
      reason: '途中停止を説明の聞き返し完了にしない',
    );
    await practice.dispose();
  });

  test('遅いmic.start中のstopは復帰後のhidden micとtimerを残さない', () async {
    final mic = _FakeMic()..startGate = Completer<bool>();
    final practice = LocalVoicePractice(
      mic: mic,
      player: PcmPlayer(
        sink: _FakeSink(),
        playbackSampleRate: MicStream.sampleRate,
      ),
      recordingLimit: const Duration(milliseconds: 20),
    );

    final starting = practice.startRecording();
    await _flushAsync();
    expect(practice.snapshot.state, LocalVoicePracticeState.recording);

    await practice.stopRecording();
    expect(practice.snapshot.state, LocalVoicePracticeState.idle);
    expect(mic.started, isFalse);

    mic.startGate!.complete(true);
    expect(await starting, isFalse);
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(mic.started, isFalse, reason: '遅れて成功したnative micを即停止する');
    expect(practice.snapshot.state, LocalVoicePracticeState.idle);
    expect(mic.stopCalls, greaterThanOrEqualTo(2));
    await practice.dispose();
  });

  test('mic start/stopとplayer init/enqueue例外をfailedへ正規化する', () async {
    final startMic = _FakeMic()..throwOnStartCall = 1;
    final startPractice = LocalVoicePractice(
      mic: startMic,
      player: PcmPlayer(
        sink: _FakeSink(),
        playbackSampleRate: MicStream.sampleRate,
      ),
    );
    expect(await startPractice.startRecording(), isFalse);
    expect(startPractice.snapshot.state, LocalVoicePracticeState.failed);
    await startPractice.dispose();

    final stopMic = _FakeMic()..throwOnStopCall = 1;
    final stopPractice = LocalVoicePractice(
      mic: stopMic,
      player: PcmPlayer(
        sink: _FakeSink(),
        playbackSampleRate: MicStream.sampleRate,
      ),
    );
    expect(await stopPractice.startRecording(), isTrue);
    stopMic.emit(Uint8List(3200));
    await _flushAsync();
    await stopPractice.stopRecording();
    expect(stopPractice.snapshot.state, LocalVoicePracticeState.failed);
    await stopPractice.dispose();

    for (final failure in <String>['init', 'enqueue', 'feed']) {
      final mic = _FakeMic();
      final sink = _FakeSink();
      final practice = LocalVoicePractice(
        mic: mic,
        player: PcmPlayer(sink: sink, playbackSampleRate: MicStream.sampleRate),
      );
      await practice.startRecording();
      mic.emit(Uint8List(3200));
      await _flushAsync();
      await practice.stopRecording();
      if (failure == 'init') {
        sink.throwOnSetup = true;
      } else {
        if (failure == 'enqueue') {
          sink.throwOnStart = true;
        } else {
          sink.throwOnFeed = true;
        }
      }

      final started = await practice.playRecording();
      if (failure == 'feed') {
        expect(started, isTrue);
        sink.requestFeed();
        await _flushAsync();
      } else {
        expect(started, isFalse);
      }
      expect(practice.snapshot.state, LocalVoicePracticeState.failed);
      expect(practice.snapshot.playbackCompleted, isFalse);
      await practice.dispose();
    }
  });

  test('stop失敗後のclearは停止を再試行し、成功後だけidleへ戻す', () async {
    final mic = _FakeMic()..throwOnStopCall = 1;
    final practice = LocalVoicePractice(
      mic: mic,
      player: PcmPlayer(
        sink: _FakeSink(),
        playbackSampleRate: MicStream.sampleRate,
      ),
    );

    expect(await practice.startRecording(), isTrue);
    await practice.stopRecording();
    expect(practice.snapshot.state, LocalVoicePracticeState.failed);
    expect(mic.started, isTrue, reason: 'stop例外後はnative録音の可能性が残る');

    await practice.clear();

    expect(mic.stopCalls, 2);
    expect(mic.started, isFalse);
    expect(practice.snapshot.state, LocalVoicePracticeState.idle);
    await practice.dispose();
  });

  test('clearで停止再試行も失敗した場合はidleへ偽装せずfailedを維持する', () async {
    final mic = _FakeMic()..throwOnStopCalls.addAll(<int>{1, 2});
    final practice = LocalVoicePractice(
      mic: mic,
      player: PcmPlayer(
        sink: _FakeSink(),
        playbackSampleRate: MicStream.sampleRate,
      ),
    );

    expect(await practice.startRecording(), isTrue);
    await practice.stopRecording();
    await practice.clear();

    expect(mic.stopCalls, 2);
    expect(mic.started, isTrue);
    expect(practice.snapshot.state, LocalVoicePracticeState.failed);
    await practice.dispose();
  });

  test('stop失敗後のdisposeは停止を再試行してからmicを解放する', () async {
    final mic = _FakeMic()..throwOnStopCall = 1;
    final practice = LocalVoicePractice(
      mic: mic,
      player: PcmPlayer(
        sink: _FakeSink(),
        playbackSampleRate: MicStream.sampleRate,
      ),
    );

    expect(await practice.startRecording(), isTrue);
    await practice.stopRecording();
    expect(mic.started, isTrue);

    await practice.dispose();

    expect(mic.stopCalls, 2);
    expect(mic.started, isFalse);
    expect(mic.disposed, isTrue);
    expect(practice.snapshot.state, LocalVoicePracticeState.disposed);
  });

  test('stop連続失敗とmic dispose例外でもplayer・subscription・changesを全解放する', () async {
    final mic = _FakeMic()
      ..throwOnEveryStop = true
      ..stopThrowsSynchronously = true
      ..throwOnDisposeAfterCleanup = true
      ..preserveStartedOnDisposeFailure = true;
    final sink = _FakeSink();
    final player = PcmPlayer(
      sink: sink,
      playbackSampleRate: MicStream.sampleRate,
    );
    await player.init();
    final practice = LocalVoicePractice(mic: mic, player: player);
    final changesDone = Completer<void>();
    practice.changes.listen((_) {}, onDone: changesDone.complete);
    expect(await practice.startRecording(), isTrue);

    await expectLater(practice.dispose(), throwsA(isA<StateError>()));

    expect(mic.stopCalls, 2, reason: 'route dispose中にbest-effortを複数回行う');
    expect(mic.disposed, isTrue);
    expect(mic.started, isTrue, reason: '停止もdisposeも未保証ならfalseへ偽装しない');
    expect(sink.released, isTrue, reason: 'mic失敗と独立してplayerを解放する');
    expect(practice.snapshot.state, LocalVoicePracticeState.disposed);
    expect(practice.snapshot.recordedBytes, 0);
    await changesDone.future;
  });

  test('60秒を超える設定を受けても60秒・1920000byteへ丸める', () async {
    final mic = _FakeMic();
    final practice = LocalVoicePractice(
      mic: mic,
      player: PcmPlayer(
        sink: _FakeSink(),
        playbackSampleRate: MicStream.sampleRate,
      ),
      recordingLimit: const Duration(minutes: 3),
    );

    expect(practice.recordingLimit, LocalVoicePractice.maxRecordingDuration);
    await practice.startRecording();
    mic.emit(Uint8List(LocalVoicePractice.maxRecordingBytes + 200));
    await _flushAsync();
    expect(
      practice.snapshot.recordedBytes,
      LocalVoicePractice.maxRecordingBytes,
    );
    expect(practice.snapshot.duration, const Duration(seconds: 60));
    await practice.dispose();
  });

  test('disposeは録音中でも停止・ゼロ化・player解放まで行い二重でも安全', () async {
    final mic = _FakeMic();
    final sink = _FakeSink();
    final practice = LocalVoicePractice(
      mic: mic,
      player: PcmPlayer(sink: sink, playbackSampleRate: MicStream.sampleRate),
    );

    await practice.startRecording();
    mic.emit(Uint8List(6400));
    await _flushAsync();
    expect(practice.snapshot.recordedBytes, 6400);

    await practice.dispose();
    await practice.dispose();

    expect(practice.isDisposed, isTrue);
    expect(practice.snapshot.state, LocalVoicePracticeState.disposed);
    expect(practice.snapshot.recordedBytes, 0);
    expect(mic.started, isFalse);
    expect(mic.disposed, isTrue);
    // 再生初期化前ならnative口へ触らず終える。
    expect(sink.released, isFalse);
  });
}
