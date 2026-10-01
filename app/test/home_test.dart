import 'dart:async';

import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/models/concept_progress.dart';
import 'package:dekisugi/models/exam_plan.dart';
import 'package:dekisugi/models/mission.dart';
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
{"schemaVersion":10,"units":[{"id":"force-motion","title":"力と運動","brief":"ざっくり",
"concepts":[
{"key":"c0","label":"概念0","storyTitle":"概念0の事件","field":"energy","grade":3,
"curriculumRefs":[{"document":"mext-jhs-science-2017","section":"第1分野 (5)(イ)","pages":[55],"url":"https://www.mext.go.jp/component/a_menu/education/micro_detail/__icsFiles/afieldfile/2019/03/18/1387018_005.pdf"}],
"prerequisites":[],"difficulty":1,"safety":{"level":"referenceOnly","guidance":"テストfixtureでは観察を行わない。"}},
{"key":"c1","label":"概念1","storyTitle":"概念1の事件","field":"energy","grade":3,
"curriculumRefs":[{"document":"mext-jhs-science-2017","section":"第1分野 (5)(イ)","pages":[56],"url":"https://www.mext.go.jp/component/a_menu/education/micro_detail/__icsFiles/afieldfile/2019/03/18/1387018_005.pdf"}],
"prerequisites":[],"difficulty":1,"safety":{"level":"referenceOnly","guidance":"テストfixtureでは観察を行わない。"}}],
"sectionCount":2}]}
''';

class _PreparedHomeUnitsClient extends UnitsClient {
  _PreparedHomeUnitsClient(this.summaries)
    : super(baseUrl: '', store: MemorySessionStore());

  final List<UnitSummary> summaries;

  @override
  Future<List<UnitSummary>> list() async => summaries;
}

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
          for (var i = 0; i < concepts; i++)
            UnitConcept(key: 'c$i', label: '概念$i', storyTitle: '概念$iの事件'),
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

    test('全部説明済みでも期限が来たCASEを今日の1件にする', () {
      final p = buildExamPlan(
        now: DateTime(2026, 8, 6, 12),
        examDate: null,
        units: [unit()],
        reviews: const [],
        explainedKeys: {'force-motion/c0', 'force-motion/c1'},
        progress: [
          ConceptProgress(
            unitId: 'force-motion',
            conceptKey: 'c0',
            lastOutcome: ConceptOutcome.learned,
            successfulRetrievals: 0,
            lastAttemptDay: '2026-08-05',
            lastSuccessDay: '2026-08-05',
            nextDueDay: '2026-08-06',
            sourceSessionId: 1,
          ),
          ConceptProgress(
            unitId: 'force-motion',
            conceptKey: 'c1',
            lastOutcome: ConceptOutcome.retained,
            successfulRetrievals: 1,
            lastAttemptDay: '2026-08-06',
            lastSuccessDay: '2026-08-06',
            nextDueDay: '2026-08-09',
            sourceSessionId: 2,
          ),
        ],
      );

      expect(p.remaining, 0);
      expect(p.today?.conceptKey, 'c0');
      expect(p.today?.missionKind, MissionKind.caseRetry);
    });

    test('期限が来たREPAIRをCASEより先に出す', () {
      ConceptProgress progress(String key, ConceptOutcome outcome) =>
          ConceptProgress(
            unitId: 'force-motion',
            conceptKey: key,
            lastOutcome: outcome,
            successfulRetrievals: 0,
            lastAttemptDay: '2026-08-05',
            lastSuccessDay: outcome == ConceptOutcome.rematchNeeded
                ? null
                : '2026-08-05',
            nextDueDay: '2026-08-05',
            sourceSessionId: 1,
          );
      final p = buildExamPlan(
        now: now,
        examDate: null,
        units: [unit()],
        reviews: const [],
        explainedKeys: const {},
        progress: [
          progress('c0', ConceptOutcome.learned),
          progress('c1', ConceptOutcome.rematchNeeded),
        ],
      );

      expect(p.today?.conceptKey, 'c1');
      expect(p.today?.missionKind, MissionKind.repair);
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

    Widget wrap({
      double textScale = 1,
      Future<void> Function(
        UnitSummary unit,
        String conceptKey,
        MissionKind missionKind,
      )?
      onStart,
      VoidCallback? onOpenReview,
    }) => MaterialApp(
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
        onStart: onStart ?? (a, b, c) async {},
        onOpenReview: onOpenReview ?? () {},
        onPickUnit: () {},
      ),
    );

    setUp(() => store = MemorySessionStore());

    testWidgets('主 CTA がきょうの1件を出す', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.textContaining('TODAY MISSION'), findsOneWidget);
      expect(find.text('ミッション開始'), findsOneWidget);
      expect(
        find.byType(Character),
        findsOneWidget,
        reason: 'ホームが管理画面ではなく、デキすぎ君との場所に見える必要がある',
      );
    });

    testWidgets('成人self向けconsumer Homeにはクラス導線を出さない', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('クラスに入る'), findsNothing);
      expect(find.textContaining('クラス全体の説明'), findsNothing);
    });

    testWidgets('成功翌日はCASEを表示だけでなく開始コールバックまで渡す', (tester) async {
      final completedAt = DateTime.now().subtract(const Duration(days: 2));
      final sessionId = await store.startSession(
        'force-motion',
        focusConceptKey: 'c0',
        missionKind: MissionKind.teach,
      );
      await store.completeMission(
        sessionId,
        cleared: true,
        completedAt: completedAt,
        explained: ExplainedItem(
          unitId: 'force-motion',
          conceptKey: 'c0',
          label: '概念0',
          said: '理由まで説明した',
          at: completedAt,
        ),
      );
      MissionKind? openedKind;
      await tester.pumpWidget(
        wrap(
          onStart: (unit, conceptKey, missionKind) async {
            expect(conceptKey, 'c0');
            openedKind = missionKind;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('CASE MISSION'), findsOneWidget);
      expect(find.text('ケース開始'), findsOneWidget);
      await tester.tap(find.text('ケース開始'));
      await tester.pump();
      expect(openedKind, MissionKind.caseRetry);
    });

    testWidgets('主 CTA は読み上げでもボタンとして操作できる', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(wrap());
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel('ミッション開始'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('主 CTA を連打しても教材を1回しか開かない', (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final gate = Completer<void>();
      var opened = 0;
      await tester.pumpWidget(
        wrap(
          textScale: 2,
          onStart: (unit, conceptKey, missionKind) {
            opened++;
            return gate.future;
          },
        ),
      );
      await tester.pumpAndSettle();

      final button = find.widgetWithText(FilledButton, 'ミッション開始');
      final onPressed = tester.widget<FilledButton>(button).onPressed!;
      onPressed();
      onPressed();
      await tester.pump();

      expect(opened, 1);
      expect(find.text('ミッションを開いています…'), findsOneWidget);
      expect(tester.takeException(), isNull);
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('見直し導線を連打しても画面を1枚しか開かない', (tester) async {
      var opened = 0;
      await tester.pumpWidget(wrap(onOpenReview: () => opened++));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('もう一度見るところ'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      final tile = find.ancestor(
        of: find.text('もう一度見るところ'),
        matching: find.byType(InkWell),
      );
      final onTap = tester.widget<InkWell>(tile).onTap!;
      onTap();
      onTap();
      await tester.pumpAndSettle();

      expect(opened, 1);
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

    testWidgets('教材を会話へ置換した後でも、ホーム復帰時に成果を読み直す', (tester) async {
      final observer = RouteObserver<ModalRoute<void>>();
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          navigatorObservers: [observer],
          theme: buildAppTheme(Brightness.light),
          home: HomeScreen(
            store: store,
            units: UnitsClient(
              baseUrl: 'https://example.test',
              store: store,
              dio: fakeDio({
                'GET https://example.test/api/units': () =>
                    jsonRes(200, _listJson),
              }),
            ),
            routeObserver: observer,
            onStart: (a, b, c) async {},
            onOpenReview: () {},
            onPickUnit: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('空気の抵抗を無視すれば'), findsNothing);

      final materialRoute = navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('教材を読む')),
        ),
      );
      await tester.pumpAndSettle();
      final talkRoute = navigatorKey.currentState!.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('会話中')),
        ),
      );
      await tester.pumpAndSettle();
      await materialRoute;
      await store.recordExplained(
        ExplainedItem(
          unitId: 'force-motion',
          conceptKey: 'c0',
          label: '概念0',
          said: '空気の抵抗を無視すれば重さによらない',
          at: DateTime(2026, 8, 9),
        ),
      );

      navigatorKey.currentState!.pop();
      await talkRoute;
      await tester.pumpAndSettle();

      expect(
        find.textContaining('空気の抵抗を無視すれば重さによらない'),
        findsOneWidget,
        reason: 'ホームが古いままだと、会話で得た成果が消えたように見える',
      );
    });

    testWidgets('考査日が未設定でも壊れない', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.textContaining('次の考査日を入れると'), findsOneWidget);
    });

    testWidgets('過ぎた考査日を「きょう」と表示しない', (tester) async {
      await store.setExamDate(DateTime.now().subtract(const Duration(days: 2)));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('次の考査日を入れ直す'), findsOneWidget);
      expect(find.text('前の考査日は終了しています'), findsOneWidget);
      expect(find.text('きょうが考査日'), findsNothing);
    });

    testWidgets('320dp・文字200%でも主導線が横にはみ出さない', (tester) async {
      tester.view.physicalSize = const Size(320, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(wrap(textScale: 2));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('ミッション開始'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -4000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('新規インストールで通信が無くても同梱教材から今日の1件を出す', (tester) async {
      // 電車の中で初めて開いても、通信エラー画面で終わらせない
      // schema v3の実assetは50KBを超えて背景isolateを使うため、正本の
      // 読み込み自体はrunAsyncで検証し、Widgetには読み込み済み一覧を渡す。
      final source = UnitsClient(baseUrl: '', store: MemorySessionStore());
      final bundled = await tester.runAsync(source.list);
      expect(bundled, isNotEmpty);
      final offline = MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: HomeScreen(
          store: store,
          units: _PreparedHomeUnitsClient(bundled!),
          onStart: (a, b, c) async {},
          onOpenReview: () {},
          onPickUnit: () {},
        ),
      );
      await tester.pumpWidget(offline);
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('教材を、まだ開けません。'), findsNothing);
      expect(find.textContaining('落下の速さ'), findsOneWidget);
      expect(find.text('ミッション開始'), findsOneWidget);
    });
  });
}
