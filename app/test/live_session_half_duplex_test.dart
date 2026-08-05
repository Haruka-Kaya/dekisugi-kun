import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dekisugi/services/device_identity.dart';
import 'package:dekisugi/services/live_session.dart';
import 'package:dekisugi/services/live_token_client.dart';
import 'package:dekisugi/services/mic_stream.dart';
import 'package:dekisugi/services/pcm_player.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_live.dart';

/// マイクの代わり。音量とチャンクを外から流し込む。
class FakeMic extends MicStream {
  final _chunks = StreamController<Uint8List>.broadcast();
  final _levels = StreamController<double>.broadcast();
  bool started = false;

  @override
  Stream<Uint8List> get chunks => _chunks.stream;
  @override
  Stream<double> get level => _levels.stream;
  @override
  bool get isRecording => started;

  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<bool> start({bool speakerphone = true}) async => started = true;
  @override
  Future<void> stop() async => started = false;
  @override
  Future<void> dispose() async {
    await _chunks.close();
    await _levels.close();
  }

  /// 音量を1つ流す。**先に音量、次にチャンク**の順で届く実機と同じにする。
  void hear(double peak, Uint8List chunk) {
    _levels.add(peak);
    _chunks.add(chunk);
  }
}

/// スピーカーの代わり。**補充を要求しない**ので、積んだ音は減らない
/// ＝「AI が喋り続けている」状態を作れる。
class FakeSink implements PcmSink {
  bool started = false;
  final fed = <int>[];

  @override
  Future<void> setLogLevel(LogLevel level) async {}
  @override
  Future<void> setup({required int sampleRate, required int channelCount}) async {}
  @override
  Future<void> setFeedThreshold(int frames) async {}
  @override
  void setFeedCallback(void Function(int remainingFrames)? cb) {}
  @override
  void feed(PcmArrayInt16 buffer) => fed.add(buffer.bytes.lengthInBytes);
  @override
  void start() => started = true;
  @override
  Future<void> release() async {}
}

/// 資格情報は偽サーバを指す。
/// `reserve` は wss:// しか受け付けないので、**本番の検査を緩めずに**差し替える。
class FakeTokens extends LiveTokenClient {
  FakeTokens(this.grant)
      : super(baseUrl: 'https://example.test', identity: _NoIdentity());

  final LiveGrant grant;

  @override
  Future<LiveGrant> reserve(String unitId) async => grant;
  @override
  Future<QuotaStatus?> peek() async => null;
}

class _NoIdentity extends DeviceIdentity {
  _NoIdentity() : super(baseUrl: '', store: MemorySessionStore());
  @override
  Future<String?> token({bool force = false}) async => 'x';
}

Uint8List pcm(int bytes) => Uint8List(bytes);

/// 24kHz PCM16 を base64 で。サーバが音声を返したことにする
String audioB64(int bytes) => base64Encode(Uint8List(bytes));

void main() {
  // MicStream のコンストラクタが AudioRecorder を作り、
  // プラットフォームチャネルに触れる。バインディングが無いと落ちる
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLive server;
  late FakeMic mic;
  late FakeSink sink;
  late LiveSessionController live;

  setUp(() async {
    server = await FakeLive.start();
    mic = FakeMic();
    sink = FakeSink();
    live = LiveSessionController(
      unitId: 'force-motion',
      tokens: FakeTokens(grantFor(server.port)),
      store: MemorySessionStore(),
      mic: mic,
      player: PcmPlayer(sink: sink),
    );
  });

  tearDown(() async {
    await live.stop();
    await server.dispose();
  });

  Future<void> settle([int ms = 250]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  test('生徒が喋れば activityStart と音声が届く', () async {
    await live.start();
    await settle();

    mic.hear(0.5, pcm(320));
    await settle();

    expect(server.sawActivityStart, isTrue, reason: 'activityStart が無いと音声は捨てられる');
    expect(server.audioFrames, isNotEmpty);
  });

  test('AI が鳴っている間はマイクの音を1バイトも送らない', () async {
    // この端末では AEC が効かず、AI の声を自分で拾って
    // 「内容をを」が生徒の発話として記録された（実機で確認）。
    // 記録が汚れるとカルテとディレクターがそれを読むので、測定そのものが壊れる
    await live.start();
    await settle();

    mic.hear(0.5, pcm(320));
    await settle();
    final before = server.audioFrames.length;
    expect(before, greaterThan(0));

    // AI が喋りはじめる（偽スピーカーは補充を要求しないので鳴り続ける）
    server.say({
      'serverContent': {
        'modelTurn': {
          'parts': [
            {
              'inlineData': {'mimeType': 'audio/pcm', 'data': audioB64(48000)},
            },
          ],
        },
      },
    });
    await settle();
    expect(live.state, LiveState.speaking);
    expect(live.isListeningToMic, isFalse);

    // AI の声を拾ったつもりで、大きな音を流し込む
    for (var i = 0; i < 10; i++) {
      mic.hear(0.9, pcm(320));
    }
    await settle();

    expect(server.audioFrames.length, before,
        reason: 'AI が鳴っている間に送ったフレームがある');
  });

  test('塞いだときに activityEnd を送る', () async {
    // 送らないと、モデルは生徒の発話が続いていると思って待ち続ける
    await live.start();
    await settle();

    mic.hear(0.5, pcm(320));
    await settle();
    expect(server.sawActivityEnd, isFalse);

    server.say({
      'serverContent': {
        'modelTurn': {
          'parts': [
            {
              'inlineData': {'mimeType': 'audio/pcm', 'data': audioB64(48000)},
            },
          ],
        },
      },
    });
    await settle();
    mic.hear(0.9, pcm(320)); // 塞がれた状態で音量が来る
    await settle();

    expect(server.sawActivityEnd, isTrue);
  });

  test('タップで止めるとマイクが戻る', () async {
    await live.start();
    await settle();

    server.say({
      'serverContent': {
        'modelTurn': {
          'parts': [
            {
              'inlineData': {'mimeType': 'audio/pcm', 'data': audioB64(48000)},
            },
          ],
        },
      },
    });
    await settle();
    expect(live.isListeningToMic, isFalse);

    live.silenceAi();
    // エコーの尾を待つあいだはまだ閉じている
    expect(live.isListeningToMic, isFalse);
    await settle(LiveSessionController.echoTail.inMilliseconds + 150);

    expect(live.isListeningToMic, isTrue);
    expect(live.state, LiveState.listening);
  });

  test('会話が始まっていなければタップしても何も起きない', () async {
    live.silenceAi();
    expect(live.state, LiveState.idle);
  });
}
