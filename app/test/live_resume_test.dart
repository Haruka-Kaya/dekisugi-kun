import 'package:dekisugi/services/live_session.dart';
import 'package:dekisugi/services/pcm_player.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_live.dart';
import 'support/live_fakes.dart';

/// **10分の壁。**
///
/// Vertex は約9分でセッションを切る（実測 `code=1000`）。
/// そこで会話を終わらせると、生徒には
/// 「10分と言われたのに9分で打ち切られた」ように見える。
///
/// 繋ぎ直すこと自体は難しくないが、**枠を余計に消費しないこと**と
/// **会話を忘れないこと**の2つを外すと、直すより悪くなる。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLive server;
  late FakeMic mic;
  late FakeTokens tokens;
  late LiveSessionController live;

  setUp(() async {
    server = await FakeLive.start();
    mic = FakeMic();
    tokens = FakeTokens(grantFor(server.port));
    live = LiveSessionController(
      unitId: 'force-motion',
      tokens: tokens,
      store: MemorySessionStore(),
      mic: mic,
      player: PcmPlayer(sink: FakeSink()),
    );
  });

  tearDown(() async {
    await live.stop();
    await server.dispose();
  });

  Future<void> settle([int ms = 250]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  /// Vertex が配る「続きから」の札。実機ではサーバを経由せず端末に届く
  void sendHandle([String handle = 'h-1']) => server.say({
    'sessionResumptionUpdate': {'newHandle': handle},
  });

  /// 生徒が何か言った状態を作る。**繋ぎ直しで消えないこと**を見るため
  Future<void> saySomething() async {
    await live.sendStudentText('重いほうが速く落ちると思ってた');
    await settle();
  }

  test('セッション上限で切れたら、続きから繋ぎ直す', () async {
    await live.start();
    await settle();
    sendHandle();
    await settle();
    await saySomething();

    await server.hangUp(); // Vertex が code=1000 で切る
    await settle(400);

    expect(live.state, isNot(LiveState.done), reason: '9分で会話が終わってしまう');
    expect(tokens.lastResumeHandle, 'h-1', reason: '札を渡さないと会話を忘れる');
    expect(
      live.transcript.where((u) => u.isStudent),
      hasLength(1),
      reason: '繋ぎ直しで逐語が消えた',
    );
  });

  test('札が届いていなければ繋ぎ直さない', () async {
    // 札なしで繋ぎ直すと、いままでの話を忘れたデキすぎ君が途中から現れる
    await live.start();
    await settle();

    await server.hangUp();
    await settle(400);

    expect(live.state, LiveState.done);
    expect(tokens.reserveCalls, 1);
  });

  test('サーバが再開を受け入れなければ会話を終える', () async {
    // 再開に未対応の古いサーバ。繋ぎ直すと会話を忘れた状態で再開してしまう
    tokens.acceptResume = false;
    await live.start();
    await settle();
    sendHandle();
    await settle();

    await server.hangUp();
    await settle(400);

    expect(live.state, LiveState.done);
  });

  test('繋ぎ直しに失敗したら諦める', () async {
    await live.start();
    await settle();
    sendHandle();
    await settle();

    tokens.failReserve = true;
    await server.hangUp();
    await settle(400);

    expect(live.state, LiveState.done);
  });

  test('繋ぎ直しの上限を超えたら終える', () async {
    // ここが無いと、切れるたびに繋ぎ直して枠と請求を焼く
    await live.start();
    await settle();

    for (var i = 0; i <= LiveSessionController.maxResumeAttempts; i++) {
      sendHandle('h-$i');
      await settle(120);
      await server.hangUp();
      await settle(400);
    }

    expect(live.state, LiveState.done);
    expect(
      tokens.reserveCalls,
      lessThanOrEqualTo(1 + LiveSessionController.maxResumeAttempts),
    );
  });

  test('自分から止めたときは繋ぎ直さない', () async {
    await live.start();
    await settle();
    sendHandle();
    await settle();

    await live.stop();
    await settle(300);

    expect(live.state, LiveState.idle);
    expect(tokens.reserveCalls, 1);
  });

  test('会話を始め直したら前の札を持ち越さない', () async {
    // 別の会話の続きに繋ぎにいくと、前の単元の話が混ざる
    await live.start();
    await settle();
    sendHandle('old');
    await settle();
    await live.stop();

    await live.start();
    await settle();
    await server.hangUp();
    await settle(400);

    expect(live.state, LiveState.done);
    expect(tokens.lastResumeHandle, isNull);
  });
}
