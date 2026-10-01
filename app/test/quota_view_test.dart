import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/models/mission.dart';
import 'package:dekisugi/services/device_identity.dart';
import 'package:dekisugi/services/live_session.dart';
import 'package:dekisugi/services/live_token_client.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/quota_view.dart';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/stub_dio.dart';

LiveSessionController controller({int? remaining, DateTime? resetsAt}) {
  final store = MemorySessionStore();
  final c = LiveSessionController(
    unitId: 'force-motion',
    store: store,
    tokens: LiveTokenClient(
      baseUrl: 'https://example.test',
      identity: DeviceIdentity(baseUrl: '', store: store),
    ),
  );
  c.remainingSessions = remaining;
  c.quotaResetsAt = resetsAt;
  return c;
}

Widget wrap(Widget child) => MaterialApp(
  theme: buildAppTheme(Brightness.light),
  home: Scaffold(body: child),
);

void main() {
  group('のこり回数の表示', () {
    testWidgets('回数を出す', (tester) async {
      await tester.pumpWidget(wrap(QuotaChip(live: controller(remaining: 2))));
      expect(find.text('あと2回'), findsOneWidget);
    });

    testWidgets('残り1回でアイコンが変わる（色だけで伝えない）', (tester) async {
      await tester.pumpWidget(wrap(QuotaChip(live: controller(remaining: 1))));
      expect(find.byIcon(Icons.hourglass_bottom), findsOneWidget);

      await tester.pumpWidget(wrap(QuotaChip(live: controller(remaining: 2))));
      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets('分からないうちは何も出さない', (tester) async {
      // 「0回」と誤解させない
      await tester.pumpWidget(wrap(QuotaChip(live: controller())));
      expect(find.textContaining('あと'), findsNothing);
    });
  });

  group('使い切ったときの案内', () {
    testWidgets('責めず、いつ戻るかを出す', (tester) async {
      final at = DateTime.now().add(const Duration(hours: 5));
      await tester.pumpWidget(wrap(OutOfTimeCard(resetsAt: at)));

      expect(find.textContaining('きょうのぶんは終わり'), findsOneWidget);
      expect(find.textContaining('時ごろ'), findsOneWidget);
      // 失敗の顔をさせない
      expect(find.textContaining('エラー'), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('戻る時刻が分からなくても文が壊れない', (tester) async {
      await tester.pumpWidget(wrap(const OutOfTimeCard(resetsAt: null)));
      expect(find.textContaining('日付が変わったころ'), findsOneWidget);
    });

    testWidgets('待つあいだの行き先を出す', (tester) async {
      await tester.pumpWidget(wrap(const OutOfTimeCard(resetsAt: null)));
      expect(find.textContaining('もう一度見るところ'), findsOneWidget);
    });

    testWidgets('Plus導線は指定時だけ出し、連打中は無効にする', (tester) async {
      var opens = 0;
      await tester.pumpWidget(
        wrap(OutOfTimeCard(resetsAt: null, onOpenPlus: () => opens++)),
      );

      await tester.tap(find.text('Plusで会話回数を広げる'));
      expect(opens, 1);

      await tester.pumpWidget(
        wrap(
          OutOfTimeCard(
            resetsAt: null,
            onOpenPlus: () => opens++,
            plusBusy: true,
          ),
        ),
      );
      expect(find.text('Plusを確認しています…'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });
  });

  test('Plus反映後は使い切り状態から開始前へ戻る', () async {
    var entitled = false;
    final store = MemorySessionStore();
    final tokens = LiveTokenClient(
      baseUrl: 'https://example.test',
      identity: DeviceIdentity(baseUrl: '', store: store),
      dio: fakeDio({
        'GET https://example.test/api/live-token': () => json200(
          entitled
              ? '{"remainingSessions":null,"entitled":true}'
              : '{"remainingSessions":0,"entitled":false}',
        ),
      }),
    );
    final live = LiveSessionController(
      unitId: 'force-motion',
      store: store,
      tokens: tokens,
    );

    await live.refreshQuota();
    expect(live.state, LiveState.outOfTime);

    entitled = true;
    await live.refreshQuota();
    expect(live.state, LiveState.idle);
    expect(live.remainingSessions, isNull);
  });

  group('LiveTokenClient', () {
    LiveTokenClient client(Map<String, Response<Object?> Function()> routes) =>
        LiveTokenClient(
          baseUrl: 'https://example.test',
          identity: DeviceIdentity(baseUrl: '', store: MemorySessionStore()),
          dio: fakeDio(routes),
        );

    test('確保できたら中身を読む', () async {
      final c = client({
        'POST https://example.test/api/live-token': () => json200('''
{"token":"ya29.abc","wsUrl":"wss://x.googleapis.com/ws/y","model":"projects/p/locations/l/publishers/google/models/m","setupConfig":{"generationConfig":{"responseModalities":["AUDIO"]}},
 "expiresAt":"2099-01-01T00:00:00Z","sessionMinutes":10,
 "remainingSessions":1,"entitled":false,"resetsAt":"2099-01-02T00:00:00Z"}'''),
      });
      final g = await c.reserve('force-motion');
      expect(g.token, 'ya29.abc');
      expect(g.sessionMinutes, 10);
      expect(g.remainingSessions, 1);
      expect(g.setupConfig.isNotEmpty, isTrue);
    });

    test('1概念ミッションを資格情報の設定へ失わず送る', () async {
      Object? sent;
      final store = MemorySessionStore();
      final c = LiveTokenClient(
        baseUrl: 'https://example.test',
        identity: DeviceIdentity(baseUrl: '', store: store),
        dio: fakeDio({
          'POST https://example.test/api/live-token': () => json200('''
{"token":"ya29.abc","wsUrl":"wss://x.googleapis.com/ws/y","model":"m",
"setupConfig":{"generationConfig":{"responseModalities":["AUDIO"]}},
"expiresAt":"2099-01-01T00:00:00Z","sessionMinutes":10,
"remainingSessions":1,"entitled":false}
'''),
        }, onRequest: (options) => sent = options.data),
      );

      await c.reserve(
        'force-motion',
        focusConceptKey: 'fall',
        tactic: TeachingTactic.example,
      );

      final body = (sent as Map).cast<String, dynamic>();
      expect(body['unitId'], 'force-motion');
      expect(body['focusConceptKey'], 'fall');
      expect(body['teachingTactic'], 'example');
      expect(body['missionKind'], 'teach');
    });

    test('402 は QuotaExhausted（エラーにしない）', () async {
      final c = client({
        'POST https://example.test/api/live-token': () => jsonRes(
          402,
          '{"error":"quota_exhausted","resetsAt":"2099-01-02T00:00:00Z"}',
        ),
      });
      await expectLater(
        c.reserve('force-motion'),
        throwsA(isA<QuotaExhausted>()),
      );
    });

    test('中身が足りないトークンを受け取らない', () async {
      // 空のトークンで繋ぎにいくと、原因の分からない接続失敗になる
      final c = client({
        'POST https://example.test/api/live-token': () =>
            json200('{"model":"m"}'),
      });
      await expectLater(
        c.reserve('force-motion'),
        throwsA(isA<LiveTokenUnavailable>()),
      );
    });

    test('peek は失敗しても null（画面を止めない）', () async {
      final c = client({
        'GET https://example.test/api/live-token': () => jsonRes(500, '{}'),
      });
      expect(await c.peek(), isNull);
    });

    test('peek は残りと戻る時刻を読む', () async {
      final c = client({
        'GET https://example.test/api/live-token': () => json200(
          '{"remainingSessions":0,"minutesPerSession":10,"entitled":false,"resetsAt":"2099-01-02T00:00:00Z"}',
        ),
      });
      final q = await c.peek();
      expect(q!.remainingSessions, 0);
      expect(q.isExhausted, isTrue);
    });

    test('課金済みは残りが null でも使い切り扱いにしない', () async {
      final c = client({
        'GET https://example.test/api/live-token': () =>
            json200('{"remainingSessions":null,"entitled":true}'),
      });
      final q = await c.peek();
      expect(q!.isExhausted, isFalse);
    });
  });
}
