import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/models/exam_plan.dart';
import 'package:dekisugi/models/review.dart';
import 'package:dekisugi/models/streak.dart';
import 'package:dekisugi/models/unit.dart';
import 'package:dekisugi/screens/home_screen.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:dekisugi/services/units_client.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/character.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/stub_dio.dart';

const _listJson = '''
{"units":[{"id":"force-motion","title":"力と運動","brief":"ざっくり",
"concepts":[{"key":"c0","label":"概念0"},{"key":"c1","label":"概念1"}],
"sectionCount":2}]}
''';

/// ホームの並び順は**優先順位の宣言そのもの**。
///
/// streak を上に出すと、狙っている層（Duolingo の14日保持率が
/// 全年齢中最低の高校生年代）に最も効かないものを主役に据えることになる。
void main() {
  UnitSummary unit({String id = 'force-motion', int concepts = 2}) =>
      UnitSummary(
        id: id,
        title: '力と運動',
        brief: 'ざっくりした紹介。',
        concepts: [
          for (var i = 0; i < concepts; i++) (key: 'c$i', label: '概念$i'),
        ],
        sectionCount: concepts,
      );

  ReviewItem review({String key = 'c0', int timesSeen = 0, DateTime? seen}) =>
      ReviewItem(
        unitId: 'force-motion',
        conceptKey: key,
        label: '概念0',
        reason: ReviewReason.notCorrected,
        lastSeen: seen ?? DateTime(2026, 7, 1),
        timesSeen: timesSeen,
      );

  group('考査日からの逆算', () {
    final now = DateTime(2026, 8, 6);

    test('考査日が無くても組める', () {
      final p = buildExamPlan(
        now: now,
        examDate: null,
        units: [unit()],
        reviews: const [],
        explainedKeys: const {},
      );
      expect(p.daysLeft, isNull);
      expect(p.totalCount, 2);
      expect(p.remaining, 2);
      expect(p.today?.label, '概念0', reason: 'まだ触れていない概念が出るべき');
    });

    test('残り日数は日で数える（時刻で数えない）', () {
      // 15時に「あと0日」と出すと、まだ丸1日あるのに終わったように見える
      final p = buildExamPlan(
        now: DateTime(2026, 8, 6, 23, 30),
        examDate: DateTime(2026, 8, 8, 9, 0),
        units: [unit()],
        reviews: const [],
        explainedKeys: const {},
      );
      expect(p.daysLeft, 2);
    });

    test('期限が来た復習を、新しい概念より先に出す', () {
      // 忘れかけているものを放置して先へ進むと、考査までに間に合わない
      final p = buildExamPlan(
        now: now,
        examDate: DateTime(2026, 8, 20),
        units: [unit()],
        reviews: [review(seen: DateTime(2026, 7, 1))],
        explainedKeys: const {},
      );
      expect(p.today?.isReview, isTrue);
      expect(p.today?.conceptKey, 'c0');
    });

    test('期限が来ていない復習は出さない', () {
      final p = buildExamPlan(
        now: now,
        examDate: DateTime(2026, 8, 20),
        // きょう扱ったばかり
        reviews: [review(seen: now)],
        units: [unit()],
        explainedKeys: const {},
      );
      expect(p.due, isEmpty);
      expect(p.today?.isReview, isFalse);
    });

    test('説明できた概念は残りから引く', () {
      final p = buildExamPlan(
        now: now,
        examDate: null,
        units: [unit()],
        reviews: const [],
        explainedKeys: {'force-motion/c0'},
      );
      expect(p.doneCount, 1);
      expect(p.remaining, 1);
      expect(p.today?.conceptKey, 'c1');
    });

    test('全部終わっていればきょうの1件は無い', () {
      final p = buildExamPlan(
        now: now,
        examDate: null,
        units: [unit()],
        reviews: const [],
        explainedKeys: {'force-motion/c0', 'force-motion/c1'},
      );
      expect(p.today, isNull);
      expect(p.remaining, 0);
    });

    test('復習に載っている概念を「まだ触れていない」に数えない', () {
      // 二重に出すと、同じ概念が残作業と復習の両方でカウントされる
      final p = buildExamPlan(
        now: now,
        examDate: null,
        units: [unit()],
        reviews: [review(key: 'c0', seen: now)],
        explainedKeys: const {},
      );
      expect(p.untouched.map((c) => c.key), ['c1']);
    });
  });

  group('ホームの画面', () {
    late MemorySessionStore store;

    Widget wrap({double textScale = 1}) => MaterialApp(
      theme: buildAppTheme(Brightness.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: HomeScreen(
        store: store,
        units: UnitsClient(
          baseUrl: 'https://example.test',
          store: store,
          dio: fakeDio({
            'GET https://example.test/api/units': () => jsonRes(200, _listJson),
          }),
        ),
        onStart: (a, b) {},
        onOpenReview: () {},
        onPickUnit: () {},
      ),
    );

    setUp(() => store = MemorySessionStore());

    testWidgets('主 CTA がきょうの1件を出す', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('きょうはこれを説明する'), findsOneWidget);
      expect(find.text('教材を読む'), findsOneWidget);
      expect(
        find.byType(Character),
        findsOneWidget,
        reason: 'ホームが管理画面ではなく、デキすぎ君との場所に見える必要がある',
      );
    });

    testWidgets('C5: ポイントめいたものが出ない', (tester) async {
      // 従事随伴報酬は内発動機を d = −0.40 で毀損する（Deci 1999）
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      for (final w in ['ポイント', 'pt', 'XP', 'レベル', 'ランキング', '順位']) {
        expect(find.textContaining(w), findsNothing, reason: '「$w」が出ている');
      }
    });

    testWidgets('言えるようになったことが、継続日数より上に出る', (tester) async {
      // 並び順を同じフレームで測る。通常の600px高だと末尾の継続欄が
      // ListView の遅延構築範囲外になり、位置を比較できない。
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await store.recordExplained(
        ExplainedItem(
          unitId: 'force-motion',
          conceptKey: 'c0',
          label: '概念0',
          said: '空気の抵抗を無視すれば重さによらない',
          at: DateTime(2026, 8, 6),
        ),
      );
      await store.recordActivity('2026-08-06', done: 1);

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final said = tester.getTopLeft(find.text('言えるようになったこと')).dy;
      final streak = tester.getTopLeft(find.textContaining('猶予')).dy;
      expect(said, lessThan(streak), reason: '報酬の本体より継続日数が上に来ている');
    });

    testWidgets('生徒自身の言葉がそのまま出る', (tester) async {
      // 要約に置き換えない。積み上がるのが自分の文であることが報酬の本体
      await store.recordExplained(
        ExplainedItem(
          unitId: 'force-motion',
          conceptKey: 'c0',
          label: '概念0',
          said: '空気の抵抗を無視すれば重さによらない',
          at: DateTime(2026, 8, 6),
        ),
      );
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.textContaining('空気の抵抗を無視すれば重さによらない'), findsOneWidget);
    });

    testWidgets('考査日が未設定でも壊れない', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.textContaining('次の考査日を入れると'), findsOneWidget);
    });

    testWidgets('320dp・文字200%でも主導線が横にはみ出さない', (tester) async {
      tester.view.physicalSize = const Size(320, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(textScale: 2));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('教材を読む'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -4000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('通信が無くても開ける', (tester) async {
      // 電車の中で開いたときに何も出ないまま終わらせない
      final offline = MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: HomeScreen(
          store: store,
          units: UnitsClient(
            baseUrl: 'https://example.test',
            store: store,
            dio: fakeDio({
              'GET https://example.test/api/units': () => jsonRes(500, '{}'),
            }),
          ),
          onStart: (a, b) {},
          onOpenReview: () {},
          onPickUnit: () {},
        ),
      );
      await tester.pumpWidget(offline);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
