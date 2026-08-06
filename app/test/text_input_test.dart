import 'dart:io';

import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/screens/talk_screen.dart';
import 'package:dekisugi/services/live_session.dart';
import 'package:dekisugi/services/pcm_player.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:dekisugi/services/units_client.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/fake_live.dart';
import 'support/live_fakes.dart';

/// **C8 — テキスト入力を音声と対等な第一級の経路にする。**
///
/// 根拠: 人前での音声利用を恥ずかしいと答えた日本人が 71.1%。
/// 電車・教室・家族のいる部屋で声を出せない生徒にとって、
/// 音声しか無いアプリは存在しないのと同じになる。
///
/// かつては `--dart-define=DEKISUGI_TEXT_INPUT=true` の検証用機能で、
/// **憲法に書いてあるのに実装が破っている**状態だった。
/// ここのテストはその状態に戻ることを防ぐためにある。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('C8: 文字入力は第一級', () {
    test('ソースに dart-define のゲートが残っていない', () {
      // 画面のツリーを見るテストだけだと、
      // 「定数が true に固定されているから出ている」場合を見逃す。
      // **ゲートそのものが消えていること**をソースで確かめる
      final src = File('lib/screens/talk_screen.dart').readAsStringSync();
      expect(src.contains('DEKISUGI_TEXT_INPUT'), isFalse,
          reason: '文字入力が dart-define で隠されている。C8 違反');
      expect(src.contains('kTextInputEnabled'), isFalse);
    });

    testWidgets('会話を始める前から入力欄が出ている', (tester) async {
      await tester.pumpWidget(_wrap(_controller()));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget,
          reason: '「先にマイクを押してから文字を打つ」を要求すると音声が既定＝一級のままになる');
      expect(find.text('文字で説明する'), findsOneWidget);
    });

    testWidgets('入力欄と送信ボタンが 48dp を割らない', (tester) async {
      // DESIGN.md: 主要操作は 48dp 以上。
      // IconButton の既定は 40dp なので、明示しないと割る
      await tester.pumpWidget(_wrap(_controller()));
      await tester.pump();

      // Icon そのものは 24dp。**測るのは押せる範囲**なのでボタンまで遡る
      final send = tester.getSize(find.ancestor(
        of: find.byIcon(Icons.send),
        matching: find.byType(IconButton),
      ));
      expect(send.height, greaterThanOrEqualTo(48));
      expect(send.width, greaterThanOrEqualTo(48));

      expect(tester.getSize(find.byType(TextField)).height,
          greaterThanOrEqualTo(48));
    });
  });

  group('C8: 未接続でも送れる', () {
    late FakeLive server;
    late LiveSessionController live;

    setUp(() async {
      server = await FakeLive.start();
      live = _controller(port: server.port);
    });

    tearDown(() async {
      await live.stop();
      await server.dispose();
    });

    test('繋がっていない状態で送ると、自分で繋いでから送る', () async {
      expect(live.isRunning, isFalse);

      await live.sendStudentText('重いほうが速く落ちると思ってた');
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(live.isRunning, isTrue, reason: 'マイクを押さずに送れないと C8 を満たさない');
      expect(live.transcript.where((u) => u.isStudent).map((u) => u.text),
          contains('重いほうが速く落ちると思ってた'));
    });

    test('空白だけなら繋ぎにいかない', () async {
      // 誤タップで枠を1回消費させない
      await live.sendStudentText('   ');
      expect(live.isRunning, isFalse);
    });
  });
}

LiveSessionController _controller({int? port}) => LiveSessionController(
      unitId: 'force-motion',
      tokens: FakeTokens(grantFor(port ?? 1)),
      store: MemorySessionStore(),
      mic: FakeMic(),
      player: PcmPlayer(sink: FakeSink()),
    );

Widget _wrap(LiveSessionController live) {
  final store = MemorySessionStore();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LiveSessionController>.value(value: live),
      Provider<SessionStore>.value(value: store),
      Provider<UnitsClient>.value(
          value: UnitsClient(baseUrl: '', store: store)),
    ],
    child: MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: const TalkScreen(unitTitle: '力と運動'),
    ),
  );
}
