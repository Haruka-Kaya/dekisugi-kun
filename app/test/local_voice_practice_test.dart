import 'dart:async';
import 'dart:typed_data';

import 'package:dekisugi/services/local_voice_practice.dart';
import 'package:dekisugi/services/mic_stream.dart';
import 'package:dekisugi/services/pcm_player.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMic extends MicStream {
  _FakeMic({this.allowed = true});

  final bool allowed;
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
    started = allowed;
    return allowed;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    started = false;
  }

  void emit(Uint8List bytes) => _chunks.add(bytes);

  @override
  Future<void> dispose() async {
    disposed = true;
    started = false;
    await _chunks.close();
    await _levels.close();
  }
}

class _FakeSink implements PcmSink {
  void Function(int)? callback;
  int? sampleRate;
  int startCalls = 0;
  int fedBytes = 0;
  bool released = false;

  @override
  Future<void> setLogLevel(LogLevel level) async {}

  @override
  Future<void> setup({
    required int sampleRate,
    required int channelCount,
  }) async {
    this.sampleRate = sampleRate;
  }

  @override
  Future<void> setFeedThreshold(int frames) async {}

  @override
  void setFeedCallback(void Function(int remainingFrames)? cb) {
    callback = cb;
  }

  @override
  void feed(PcmArrayInt16 buffer) {
    fedBytes += buffer.bytes.lengthInBytes;
  }

  @override
  void start() => startCalls++;

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
    expect(player.pendingBytes, 0);
    await practice.dispose();
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
