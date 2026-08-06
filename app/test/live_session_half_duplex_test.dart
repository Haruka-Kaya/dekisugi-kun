import 'package:dekisugi/services/live_session.dart';
import 'package:dekisugi/services/pcm_player.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_live.dart';
import 'support/live_fakes.dart';


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
