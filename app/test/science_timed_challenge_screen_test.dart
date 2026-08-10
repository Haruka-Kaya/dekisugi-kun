import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/motion.dart';
import 'package:dekisugi/learning/domain/learning_heart.dart';
import 'package:dekisugi/learning/domain/learning_need.dart';
import 'package:dekisugi/screens/science_timed_challenge_screen.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/science_challenge_fixture.dart';

Widget _wrap({
  Duration timeLimit = const Duration(seconds: 60),
  VoidCallback? onFinished,
  double textScale = 1,
  bool disableAnimations = false,
  LearningNeedEvidenceReported? onNeedEvidence,
  LearningHeartLossReported? onHeartLoss,
  Duration Function()? elapsedClock,
}) => MaterialApp(
  theme: buildAppTheme(Brightness.light),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: disableAnimations,
    ),
    child: ReduceMotionScope(child: child!),
  ),
  home: ScienceTimedChallengeScreen(
    section: challengeSection,
    conceptLabel: '落下の速さ',
    practiceAttempt: challengePracticeAttempt,
    timeLimit: timeLimit,
    onFinished: onFinished ?? () {},
    onNeedEvidence: onNeedEvidence,
    onHeartLoss: onHeartLoss,
    elapsedClock: elapsedClock,
  ),
);

Finder get _scrollable => find
    .descendant(
      of: find.byKey(const ValueKey('science-timed-scroll')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _scrollToAndTap(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 160, scrollable: _scrollable);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
}

Future<void> _start(WidgetTester tester) =>
    _scrollToAndTap(tester, find.byKey(const ValueKey('timed-start')));

Future<void> _answerTask(WidgetTester tester, String id) async {
  await _scrollToAndTap(
    tester,
    find.byKey(ValueKey('cognitive-task-choice-$id')),
  );
  await _scrollToAndTap(
    tester,
    find.byKey(const ValueKey('timed-task-submit')),
  );
}

Future<void> _answerCheckpoint(WidgetTester tester, String id) async {
  await _scrollToAndTap(
    tester,
    find.byKey(ValueKey('timed-checkpoint-option-$id')),
  );
  await _scrollToAndTap(
    tester,
    find.byKey(const ValueKey('timed-checkpoint-submit')),
  );
}

void _expectReferenceHidden(WidgetTester tester) {
  expect(find.textContaining(challengeVariant.expectedOutcome), findsNothing);
  expect(find.textContaining(challengeVariant.expectedReason), findsNothing);
  expect(find.textContaining(challengeCheckpoint.explanation), findsNothing);
  expect(
    find.textContaining(challengeCheckpoint.options.first.hint!),
    findsNothing,
  );
  expect(find.bySemanticsLabel(RegExp('観察と理由.*2個の球')), findsNothing);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('任意開始前と回答中は正本を先出しせず、時間切れでも何も失わない', (tester) async {
    final semantics = tester.ensureSemantics();
    var finished = 0;
    final heartLosses = <LearningHeartLossEvidence>[];
    void finishCallback() => finished++;
    await tester.pumpWidget(
      _wrap(
        timeLimit: const Duration(seconds: 2),
        disableAnimations: true,
        onFinished: finishCallback,
        onHeartLoss: heartLosses.add,
      ),
    );

    expect(find.textContaining('任意'), findsWidgets);
    expect(find.textContaining('Path・連続学習・報酬'), findsOneWidget);
    expect(find.textContaining('学校モードはハート無制限'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('OPTIONAL.*落下の速さ.*速さは学習の代わりにはなりません')),
      findsOneWidget,
    );
    _expectReferenceHidden(tester);

    await _start(tester);
    expect(find.byKey(const ValueKey('timed-task')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('1問目.*残り時間2秒')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('選択肢1.*重い球が先に着く')), findsOneWidget);
    _expectReferenceHidden(tester);
    expect(finished, 0);

    await tester.pump(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('timed-result')), findsOneWidget);
    expect(find.text('時間になりました'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('時間になったことを落ち着いて伝えています')),
      findsOneWidget,
    );
    expect(find.textContaining('Path・連続学習・報酬'), findsOneWidget);
    expect(finished, 0, reason: '時間切れを外部の完了イベントにしない');
    expect(heartLosses, isEmpty, reason: '時間切れではハートを失わない');

    final finish = find.byKey(const ValueKey('timed-finish'));
    await tester.scrollUntilVisible(finish, 160, scrollable: _scrollable);
    await tester.pump();
    await tester.tap(finish);
    await tester.tap(finish);
    expect(finished, 1);
    semantics.dispose();
  });

  testWidgets('background中も締切が進み、復帰時の時間切れはheartを減らさない', (tester) async {
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
    expect(find.byKey(const ValueKey('timed-task')), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('時間になりました'), findsOneWidget);
    expect(heartLosses, isEmpty);
  });

  testWidgets('誤答は一度で終了し、残りの選択肢を総当たりできない', (tester) async {
    var finished = 0;
    final needs = <LearningNeedEvidence>[];
    final heartLosses = <LearningHeartLossEvidence>[];
    await tester.pumpWidget(
      _wrap(
        disableAnimations: true,
        onFinished: () => finished++,
        onNeedEvidence: needs.add,
        onHeartLoss: heartLosses.add,
      ),
    );
    await _start(tester);
    await _answerTask(tester, 'task-heavy');

    expect(needs, hasLength(1));
    expect(needs.single.needCode, 'science.fall.transfer');
    expect(needs.single.kind, LearningNeedEvidenceKind.observed);
    expect(heartLosses, hasLength(1));
    expect(
      heartLosses.single.fixedTaskId,
      'timed:$challengePracticeAttempt:cognitive',
    );

    expect(find.byKey(const ValueKey('timed-result')), findsOneWidget);
    expect(find.text('今回はここまで'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('もう一度取り組めるよう案内しています')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('cognitive-task-choice-task-together')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('timed-checkpoint')), findsNothing);
    expect(
      find.textContaining(challengeCheckpoint.options.first.hint!),
      findsNothing,
    );
    expect(
      find.textContaining(challengeVariant.expectedOutcome),
      findsOneWidget,
    );
    expect(finished, 0);

    await _scrollToAndTap(tester, find.byKey(const ValueKey('timed-finish')));
    expect(finished, 1);
  });

  testWidgets('固定2問を通過しても速度報酬を作らず、終了通知は一度だけ', (tester) async {
    var finished = 0;
    await tester.pumpWidget(
      _wrap(disableAnimations: true, onFinished: () => finished++),
    );
    await _start(tester);
    await _answerTask(tester, 'task-together');

    expect(find.byKey(const ValueKey('timed-checkpoint')), findsOneWidget);
    _expectReferenceHidden(tester);
    await _answerCheckpoint(tester, 'same-time');

    expect(find.text('2問クリア'), findsOneWidget);
    expect(find.textContaining('追加報酬はありません'), findsOneWidget);
    expect(
      find.textContaining(challengeVariant.expectedOutcome),
      findsOneWidget,
    );
    expect(
      find.textContaining(challengeCheckpoint.explanation),
      findsOneWidget,
    );

    final finish = find.byKey(const ValueKey('timed-finish'));
    await tester.scrollUntilVisible(finish, 160, scrollable: _scrollable);
    await tester.pump();
    await tester.tap(finish);
    await tester.tap(finish);
    expect(finished, 1);
  });

  testWidgets('320x568・文200%・Reduce Motionで完走でき、操作面は48dp以上', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    var finished = 0;
    await tester.pumpWidget(
      _wrap(
        timeLimit: const Duration(minutes: 5),
        textScale: 2,
        disableAnimations: true,
        onFinished: () => finished++,
      ),
    );

    for (final switcher in tester.widgetList<AnimatedSwitcher>(
      find.byType(AnimatedSwitcher),
    )) {
      expect(switcher.duration, Duration.zero);
    }

    final start = find.byKey(const ValueKey('timed-start'));
    await tester.scrollUntilVisible(start, 160, scrollable: _scrollable);
    expect(tester.getSize(start).height, greaterThanOrEqualTo(48));
    await tester.tap(start);
    await tester.pump();

    final taskChoice = find.byKey(
      const ValueKey('cognitive-task-choice-task-together'),
    );
    await tester.scrollUntilVisible(taskChoice, 160, scrollable: _scrollable);
    expect(tester.getSize(taskChoice).height, greaterThanOrEqualTo(48));
    await tester.tap(taskChoice);
    await tester.pump();

    final taskSubmit = find.byKey(const ValueKey('timed-task-submit'));
    await tester.scrollUntilVisible(taskSubmit, 160, scrollable: _scrollable);
    expect(tester.getSize(taskSubmit).height, greaterThanOrEqualTo(48));
    await tester.tap(taskSubmit);
    await tester.pump();

    final checkpoint = find.byKey(
      const ValueKey('timed-checkpoint-option-same-time'),
    );
    await tester.scrollUntilVisible(checkpoint, 160, scrollable: _scrollable);
    expect(tester.getSize(checkpoint).height, greaterThanOrEqualTo(48));
    await tester.tap(checkpoint);
    await tester.pump();

    final checkpointSubmit = find.byKey(
      const ValueKey('timed-checkpoint-submit'),
    );
    await tester.scrollUntilVisible(
      checkpointSubmit,
      160,
      scrollable: _scrollable,
    );
    expect(tester.getSize(checkpointSubmit).height, greaterThanOrEqualTo(48));
    await tester.tap(checkpointSubmit);
    await tester.pump();

    final finish = find.byKey(const ValueKey('timed-finish'));
    await tester.scrollUntilVisible(finish, 160, scrollable: _scrollable);
    expect(tester.getSize(finish).height, greaterThanOrEqualTo(48));
    await tester.tap(finish);
    expect(finished, 1);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
