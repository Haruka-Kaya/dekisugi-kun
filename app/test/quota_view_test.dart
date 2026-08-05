import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/services/device_identity.dart';
import 'package:dekisugi/services/live_session.dart';
import 'package:dekisugi/services/live_token_client.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/quota_view.dart';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// 応答を固定した Dio。ネットワークを使わない。
Dio fakeDio(Map<String, Response<Object?> Function()> routes) {
  final dio = Dio(BaseOptions(validateStatus: (_) => true));
  dio.httpClientAdapter = _StubAdapter(routes);
  return dio;
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.routes);
  final Map<String, Response<Object?> Function()> routes;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final key = '${options.method} ${options.path}';
    final make = routes[key];
    if (make == null) return ResponseBody.fromString('{}', 404);
    final res = make();
    return ResponseBody.fromString(
      res.data is String ? res.data! as String : '',
      res.statusCode ?? 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Response<Object?> json(int code, String body) =>
    Response<Object?>(requestOptions: RequestOptions(), statusCode: code, data: body);

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
        'POST https://example.test/api/live-token': () => json(200, '''
{"token":"ya29.abc","wsUrl":"wss://x.googleapis.com/ws/y","model":"projects/p/locations/l/publishers/google/models/m","setupConfig":{"generationConfig":{"responseModalities":["AUDIO"]}},
 "expiresAt":"2099-01-01T00:00:00Z","sessionMinutes":10,
 "remainingSessions":1,"entitled":false,"resetsAt":"2099-01-02T00:00:00Z"}'''),
      });
      final g = await c.reserve();
      expect(g.token, 'ya29.abc');
      expect(g.sessionMinutes, 10);
      expect(g.remainingSessions, 1);
      expect(g.setupConfig.isNotEmpty, isTrue);
    });

    test('402 は QuotaExhausted（エラーにしない）', () async {
      final c = client({
        'POST https://example.test/api/live-token': () =>
            json(402, '{"error":"quota_exhausted","resetsAt":"2099-01-02T00:00:00Z"}'),
      });
      await expectLater(c.reserve(), throwsA(isA<QuotaExhausted>()));
    });

    test('中身が足りないトークンを受け取らない', () async {
      // 空のトークンで繋ぎにいくと、原因の分からない接続失敗になる
      final c = client({
        'POST https://example.test/api/live-token': () =>
            json(200, '{"model":"m"}'),
      });
      await expectLater(c.reserve(), throwsA(isA<LiveTokenUnavailable>()));
    });

    test('peek は失敗しても null（画面を止めない）', () async {
      final c = client({
        'GET https://example.test/api/live-token': () => json(500, '{}'),
      });
      expect(await c.peek(), isNull);
    });

    test('peek は残りと戻る時刻を読む', () async {
      final c = client({
        'GET https://example.test/api/live-token': () => json(200,
            '{"remainingSessions":0,"minutesPerSession":10,"entitled":false,"resetsAt":"2099-01-02T00:00:00Z"}'),
      });
      final q = await c.peek();
      expect(q!.remainingSessions, 0);
      expect(q.isExhausted, isTrue);
    });

    test('課金済みは残りが null でも使い切り扱いにしない', () async {
      final c = client({
        'GET https://example.test/api/live-token': () =>
            json(200, '{"remainingSessions":null,"entitled":true}'),
      });
      final q = await c.peek();
      expect(q!.isExhausted, isFalse);
    });
  });
}
