import 'dart:convert';

import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/models/team.dart';
import 'package:dekisugi/services/device_identity.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:dekisugi/services/team_client.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/team_card.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/stub_dio.dart';

/// **「やっていない人を可視化しない」を端末側でも塞ぐ。**
///
/// サーバは名簿も個人別の内訳も返さないが、端末に受け皿を作らないことで
/// 二重に守る。将来サーバが誤って返しても、画面に出しようがない状態にする。
void main() {
  const base = 'https://example.test';

  TeamClient client(
    MemorySessionStore store,
    Map<String, Response<Object?> Function()> routes, {
    void Function(RequestOptions)? onRequest,
  }) =>
      TeamClient(
        baseUrl: base,
        identity: _Identity(store),
        store: store,
        dio: fakeDio(routes, onRequest: onRequest),
      );

  String summaryJson({
    String state = 'ready',
    int? teamTotal = 100,
    int myTotal = 7,
    int memberCount = 30,
    String extra = '',
  }) =>
      '{"state":"$state","teamName":"2年A組",'
      '"teamTotal":${teamTotal ?? 'null'},"myTotal":$myTotal,'
      '"memberCount":$memberCount,'
      '"periodStart":"2026-08-03","periodEnd":"2026-08-09",'
      '"milestones":[{"key":"concepts-25","label":"25個あつまりました","reached":true}]'
      '$extra}';

  group('個人を持ち込まない', () {
    test('サーバが名簿を返しても端末に入らない', () async {
      // 置き場が無ければ、画面に出しようがない
      final json = summaryJson(
        extra: ',"members":[{"name":"山田","total":9}],'
            '"ranking":[{"rank":1,"name":"佐藤"}],'
            '"lastActiveAt":"2026-08-06"',
      );
      final s = TeamSummary.fromJson(
          (jsonDecode(json) as Map).cast<String, dynamic>());

      // 読み取ったものに個人が1つも含まれないこと
      final dump = jsonEncode({
        'name': s.name,
        'total': s.total,
        'myTotal': s.myTotal,
        'memberCount': s.memberCount,
        'milestones': [for (final m in s.milestones) m.label],
      });
      for (final w in ['山田', '佐藤', 'ranking', 'lastActive']) {
        expect(dump.contains(w), isFalse, reason: '「$w」が端末に入っている');
      }
    });

    testWidgets('画面に順位や名前を出さない', (tester) async {
      final s = TeamSummary.fromJson(
          (jsonDecode(summaryJson()) as Map).cast<String, dynamic>());
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(body: TeamCard(summary: s, onLeave: () {})),
      ));

      for (final w in ['位', 'ランキング', '順位', 'リーグ']) {
        expect(find.textContaining(w), findsNothing, reason: '「$w」が出ている');
      }
    });
  });

  group('人数が足りないとき', () {
    test('合計は null のまま。0 で埋めない', () {
      // 0 は「誰もやっていない」という別の意味になる
      final s = TeamSummary.fromJson(
          (jsonDecode(summaryJson(state: 'pending', teamTotal: null)) as Map)
              .cast<String, dynamic>());
      expect(s.pending, isTrue);
      expect(s.total, isNull);
    });

    testWidgets('合計の代わりに理由を出す', (tester) async {
      final s = TeamSummary.fromJson(
          (jsonDecode(summaryJson(state: 'pending', teamTotal: null, memberCount: 5))
                  as Map)
              .cast<String, dynamic>());
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(body: TeamCard(summary: s, onLeave: () {})),
      ));

      expect(find.textContaining('5人あつまってから'), findsOneWidget);
      // **0 を出さない**
      expect(find.text('0'), findsNothing);
    });
  });

  group('参加', () {
    test('入れたら所属を控える', () async {
      final store = MemorySessionStore();
      final c = client(store, {
        'POST $base/api/team/join': () =>
            jsonRes(200, '{"teamId":"T1","teamName":"2年A組","memberCount":5}'),
      });
      final r = await c.join('ABCD-EFGH');
      expect(r.team?.name, '2年A組');
      expect((await c.saved())?.id, 'T1');
    });

    test('失敗の理由を、責めない文で返す', () async {
      final cases = {
        404: ('unknown_code', '打ち間違い'),
        410: ('expired', '先生にもう一度'),
        409: ('in_other_team', '別のクラス'),
        429: ('cooldown', '1週間後'),
      };
      for (final e in cases.entries) {
        final store = MemorySessionStore();
        final c = client(store, {
          'POST $base/api/team/join': () =>
              jsonRes(e.key, '{"error":"${e.value.$1}"}'),
        });
        final r = await c.join('ABCD-EFGH');
        expect(r.team, isNull);
        expect(r.error?.message, contains(e.value.$2), reason: e.value.$1);
        expect(await c.saved(), isNull, reason: '失敗したのに所属を控えている');
      }
    });
  });

  group('退出', () {
    test('サーバが失敗しても端末の控えは消す', () async {
      // 消さないと「抜けたのに入っている」表示のまま何もできなくなる
      final store = MemorySessionStore();
      final c = client(store, {
        'POST $base/api/team/join': () =>
            jsonRes(200, '{"teamId":"T1","teamName":"A"}'),
        'POST $base/api/team/leave': () => jsonRes(500, '{}'),
      });
      await c.join('ABCD-EFGH');
      await c.leave();
      expect(await c.saved(), isNull);
    });
  });

  group('貢献の送信', () {
    Future<TeamClient> joined(
      MemorySessionStore store,
      Map<String, Response<Object?> Function()> extra, {
      void Function(RequestOptions)? onRequest,
    }) async {
      final c = client(store, {
        'POST $base/api/team/join': () =>
            jsonRes(200, '{"teamId":"T1","teamName":"A"}'),
        ...extra,
      }, onRequest: onRequest);
      await c.join('ABCD-EFGH');
      return c;
    }

    test('やった日だけ送る', () async {
      final store = MemorySessionStore();
      Object? body;
      final c = await joined(store, {
        'POST $base/api/team/contribution': () => jsonRes(200, '{"applied":[]}'),
      }, onRequest: (o) {
        if (o.path.endsWith('/contribution')) body = o.data;
      });
      await store.recordActivity('2026-08-06', done: 2, sessions: 1);
      await store.recordActivity('2026-08-05', sessions: 1); // 開いただけ
      await c.syncContributions(now: DateTime(2026, 8, 6, 12));

      final days = ((body! as Map)['days'] as List).cast<Map>();
      expect(days.map((d) => d['day']), ['2026-08-06'],
          reason: '開いただけの日を送っている');
      expect(days.single['conceptsExplained'], 2);
    });

    test('古すぎる日は送らない', () async {
      // サーバが受け付ける範囲を超えたものを送っても捨てられるだけ
      final store = MemorySessionStore();
      Object? body;
      final c = await joined(store, {
        'POST $base/api/team/contribution': () => jsonRes(200, '{"applied":[]}'),
      }, onRequest: (o) {
        if (o.path.endsWith('/contribution')) body = o.data;
      });
      await store.recordActivity('2026-08-06', done: 1);
      await store.recordActivity('2026-07-01', done: 1);
      await c.syncContributions(now: DateTime(2026, 8, 6, 12));

      final days = ((body! as Map)['days'] as List).cast<Map>();
      expect(days.map((d) => d['day']), ['2026-08-06']);
    });

    test('未来の日は送らない', () async {
      // 端末の時計がずれても、未来を送りつけない
      final store = MemorySessionStore();
      Object? body;
      final c = await joined(store, {
        'POST $base/api/team/contribution': () => jsonRes(200, '{"applied":[]}'),
      }, onRequest: (o) {
        if (o.path.endsWith('/contribution')) body = o.data;
      });
      await store.recordActivity('2026-08-06', done: 1);
      await store.recordActivity('2026-08-20', done: 1);
      await c.syncContributions(now: DateTime(2026, 8, 6, 12));

      final days = ((body! as Map)['days'] as List).cast<Map>();
      expect(days.map((d) => d['day']), ['2026-08-06']);
    });

    test('何度呼んでも同じものを送る（状態を持たない）', () async {
      // サーバが冪等なので、端末は「送れたか」を覚えなくてよい
      final store = MemorySessionStore();
      final sent = <Object?>[];
      final c = await joined(store, {
        'POST $base/api/team/contribution': () => jsonRes(200, '{"applied":[]}'),
      }, onRequest: (o) {
        if (o.path.endsWith('/contribution')) sent.add(o.data);
      });
      await store.recordActivity('2026-08-06', done: 2);
      await c.syncContributions(now: DateTime(2026, 8, 6, 12));
      await c.syncContributions(now: DateTime(2026, 8, 6, 12));

      expect(sent, hasLength(2));
      expect(jsonEncode(sent[0]), jsonEncode(sent[1]));
    });

    test('チームに入っていなければ送らない', () async {
      final store = MemorySessionStore();
      final c = client(store, {});
      await store.recordActivity('2026-08-06', done: 2);
      expect(await c.syncContributions(now: DateTime(2026, 8, 6, 12)), isFalse);
    });

    test('送るものが無ければ何もせず成功にする', () async {
      final store = MemorySessionStore();
      final c = await joined(store, {});
      expect(await c.syncContributions(now: DateTime(2026, 8, 6, 12)), isTrue);
    });

    test('通信に失敗しても投げない', () async {
      // クラスの合計は会話の付随物。落ちても学習は続く
      final store = MemorySessionStore();
      final c = await joined(store, {
        'POST $base/api/team/contribution': () => jsonRes(503, '{}'),
      });
      await store.recordActivity('2026-08-06', done: 2);
      expect(await c.syncContributions(now: DateTime(2026, 8, 6, 12)), isFalse);
    });
  });

  group('合計の取得', () {
    test('サーバ側で抜けていたら端末の控えも消す', () async {
      final store = MemorySessionStore();
      final c = client(store, {
        'POST $base/api/team/join': () =>
            jsonRes(200, '{"teamId":"T1","teamName":"A"}'),
        'GET $base/api/team/summary': () => jsonRes(404, '{"error":"not_in_team"}'),
      });
      await c.join('ABCD-EFGH');
      expect(await c.summary(), isNull);
      expect(await c.saved(), isNull, reason: '所属が食い違ったままになる');
    });

    test('入っていなければ通信しない', () async {
      final store = MemorySessionStore();
      final c = client(store, {});
      expect(await c.summary(), isNull);
    });
  });
}

class _Identity extends DeviceIdentity {
  _Identity(SessionStore store) : super(baseUrl: '', store: store);
  @override
  Future<String?> token({bool force = false}) async => 'x';
}
