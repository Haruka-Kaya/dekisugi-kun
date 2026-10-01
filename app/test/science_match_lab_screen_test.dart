import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/motion.dart';
import 'package:dekisugi/learning/domain/learning_heart.dart';
import 'package:dekisugi/learning/domain/learning_need.dart';
import 'package:dekisugi/learning/services/science_activity_content.dart';
import 'package:dekisugi/screens/science_match_lab_screen.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/science_challenge_fixture.dart';

const _pairs = [
  ScienceMatchPair(
    id: 'vacuum',
    concept: '真空中の落下',
    correctTargetId: 'same-acceleration',
    needCode: 'science.fall.transfer',
  ),
  ScienceMatchPair(
    id: 'air',
    concept: '空気中で形が違う物体',
    correctTargetId: 'drag-differs',
    needCode: 'science.fall.transfer',
  ),
];

const _targets = [
  ScienceMatchTarget(id: 'heavier-first', text: '重い物体ほど必ず先に着く'),
  ScienceMatchTarget(id: 'drag-differs', text: '空気抵抗の受け方で着地時刻が変わる'),
  ScienceMatchTarget(id: 'same-acceleration', text: '重さが違っても落下加速度は同じ'),
];

Widget _wrap({
  VoidCallback? onCompleted,
  Duration timeLimit = const Duration(seconds: 30),
  double textScale = 1,
  bool disableAnimations = false,
  Brightness brightness = Brightness.light,
  LearningHeartLossReported? onHeartLoss,
  LearningNeedEvidenceReported? onNeedEvidence,
  Future<bool> Function()? onRetryRequested,
  Duration Function()? elapsedClock,
}) => MaterialApp(
  theme: buildAppTheme(brightness),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: disableAnimations,
    ),
    child: ReduceMotionScope(child: child!),
  ),
  home: ScienceMatchLabScreen(
    section: challengeSection,
    conceptLabel: '落下の条件',
    practiceAttempt: challengePracticeAttempt,
    content: ScienceMatchLabContent(
      pairs: _pairs,
      targets: _targets,
      timeLimit: timeLimit,
    ),
    onCompleted: onCompleted ?? () {},
    onNeedEvidence: onNeedEvidence,
    onHeartLoss: onHeartLoss,
    onRetryRequested: onRetryRequested ?? () async => true,
    elapsedClock: elapsedClock,
  ),
);

Finder get _scrollable => find
    .descendant(
      of: find.byKey(const ValueKey('science-match-scroll')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 160, scrollable: _scrollable);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _start(WidgetTester tester) =>
    _tap(tester, find.byKey(const ValueKey('match-start')));

Future<void> _answer(WidgetTester tester, String targetId) async {
  await _tap(tester, find.byKey(ValueKey('match-target-$targetId')));
  await _tap(tester, find.byKey(const ValueKey('match-submit')));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Matchの各pairは選択肢IDでなくcatalog variantのcanonical needを持つ', () {
    final content = ScienceActivityContent.matchFor(
      challengeSection,
      practiceAttempt: challengePracticeAttempt,
    );

    expect(content.pairs.map((pair) => pair.needCode).toSet(), {
      challengeVariant.cognitiveTask.needCode,
    });
    expect(
      content.pairs
          .map((pair) => pair.needCode)
          .toSet()
          .intersection(content.targets.map((target) => target.id).toSet()),
      isEmpty,
    );
  });

  testWidgets('概念と条件・結果をcatalog順に結び、明示完了だけを一度通知する', (tester) async {
    var completed = 0;
    await tester.pumpWidget(
      _wrap(disableAnimations: true, onCompleted: () => completed++),
    );
    expect(find.textContaining('Instance of'), findsNothing);

    expect(find.text('対応づけ実験'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('ラボ・ブリーフ.*対応づけ実験')), findsOneWidget);
    await _start(tester);
    expect(find.text('真空中の落下'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('1/2組目.*残り時間30秒')), findsOneWidget);
    await _answer(tester, 'same-acceleration');
    expect(find.text('空気中で形が違う物体'), findsOneWidget);
    await _answer(tester, 'drag-differs');

    expect(find.text('すべて結べました'), findsOneWidget);
    expect(completed, 0);
    final complete = find.byKey(const ValueKey('match-complete'));
    await tester.scrollUntilVisible(complete, 160, scrollable: _scrollable);
    await tester.tap(complete);
    await tester.tap(complete);
    expect(completed, 1);
  });

  testWidgets('誤答でrunを終了し、残り候補を総当たりできず完了通知もしない', (tester) async {
    var completed = 0;
    var retryChecks = 0;
    final heartLosses = <LearningHeartLossEvidence>[];
    final needs = <LearningNeedEvidence>[];
    await tester.pumpWidget(
      _wrap(
        disableAnimations: true,
        onCompleted: () => completed++,
        onHeartLoss: heartLosses.add,
        onNeedEvidence: needs.add,
        onRetryRequested: () async {
          retryChecks++;
          return false;
        },
      ),
    );
    await _start(tester);
    await _answer(tester, 'heavier-first');

    expect(find.text('今回はここまで'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('もう一度取り組めるよう案内しています')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('match-target-same-acceleration')),
      findsNothing,
    );
    expect(find.text('空気中で形が違う物体'), findsNothing);
    expect(find.byKey(const ValueKey('match-complete')), findsNothing);
    expect(completed, 0);
    expect(heartLosses, hasLength(1));
    expect(
      heartLosses.single.fixedTaskId,
      'match:$challengePracticeAttempt:pair:vacuum:run:0',
    );
    expect(needs, hasLength(1));
    expect(needs.single.conceptKey, 'fall');
    expect(needs.single.needCode, 'science.fall.transfer');
    expect(needs.single.kind, LearningNeedEvidenceKind.observed);
    await _tap(tester, find.byKey(const ValueKey('match-retry')));
    await tester.pumpAndSettle();
    expect(retryChecks, 1);
    expect(find.text('今回はここまで'), findsOneWidget);
    expect(find.byKey(const ValueKey('match-start')), findsNothing);
  });

  testWidgets('時間切れはPath・streakを失わず、完了callbackを呼ばない', (tester) async {
    var completed = 0;
    var retryChecks = 0;
    final heartLosses = <LearningHeartLossEvidence>[];
    await tester.pumpWidget(
      _wrap(
        timeLimit: const Duration(seconds: 2),
        disableAnimations: true,
        onCompleted: () => completed++,
        onHeartLoss: heartLosses.add,
        onRetryRequested: () async {
          retryChecks++;
          return true;
        },
      ),
    );
    expect(find.textContaining('学校モードは試行余力が無制限'), findsOneWidget);
    await _start(tester);
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('時間になりました'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('時間になったことを落ち着いて伝えています')),
      findsOneWidget,
    );
    expect(find.textContaining('探究ノート・連続観測・報酬は変わりません'), findsOneWidget);
    expect(find.byKey(const ValueKey('match-complete')), findsNothing);
    expect(completed, 0);
    expect(heartLosses, isEmpty, reason: '時間切れではハートを失わない');
    await _tap(tester, find.byKey(const ValueKey('match-retry')));
    await tester.pumpAndSettle();
    expect(retryChecks, 1);
    expect(find.byKey(const ValueKey('match-start')), findsOneWidget);
  });

  testWidgets('background経過を復帰時に締切へ反映し、timeoutはheart 0件', (tester) async {
    var elapsed = Duration.zero;
    final heartLosses = <LearningHeartLossEvidence>[];
    await tester.pumpWidget(
      _wrap(
        timeLimit: const Duration(seconds: 5),
        disableAnimations: true,
        elapsedClock: () => elapsed,
        onHeartLoss: heartLosses.add,
      ),
    );
    await _start(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    elapsed = const Duration(seconds: 6);
    await tester.pump();
    expect(find.text('真空中の落下'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('時間になりました'), findsOneWidget);
    expect(heartLosses, isEmpty);
  });

  testWidgets('320x568・文200%・Reduce Motionで48dp・Semantics・overflowを守る', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(
        timeLimit: const Duration(minutes: 5),
        textScale: 2,
        disableAnimations: true,
        brightness: Brightness.dark,
      ),
    );

    expect(find.byType(AnimatedSwitcher), findsNothing);
    final start = find.byKey(const ValueKey('match-start'));
    await tester.scrollUntilVisible(start, 160, scrollable: _scrollable);
    expect(tester.getSize(start).height, greaterThanOrEqualTo(48));
    await tester.tap(start);
    await tester.pump();

    final choice = find.byKey(const ValueKey('match-target-same-acceleration'));
    await tester.scrollUntilVisible(choice, 160, scrollable: _scrollable);
    expect(tester.getSize(choice).height, greaterThanOrEqualTo(48));
    expect(find.bySemanticsLabel(RegExp('選択肢3/3.*重さが違っても')), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
