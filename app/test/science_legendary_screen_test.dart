import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/motion.dart';
import 'package:dekisugi/learning/domain/learning_need.dart';
import 'package:dekisugi/models/unit.dart';
import 'package:dekisugi/screens/science_legendary_screen.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/cognitive_task_input.dart';
import 'package:dekisugi/widgets/science_challenge_support.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/science_challenge_fixture.dart';

Widget _wrap({
  required bool isUnlocked,
  VoidCallback? onCompleted,
  VoidCallback? onNotCleared,
  VoidCallback? onReturnToPath,
  double textScale = 1,
  bool disableAnimations = false,
  LearningNeedEvidenceReported? onNeedEvidence,
}) => MaterialApp(
  theme: buildAppTheme(Brightness.light),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: disableAnimations,
    ),
    child: ReduceMotionScope(child: child!),
  ),
  home: ScienceLegendaryScreen(
    section: challengeSection,
    conceptLabel: '落下の速さ',
    practiceAttempt: challengePracticeAttempt,
    isUnlocked: isUnlocked,
    onCompleted: onCompleted ?? () {},
    onNotCleared: onNotCleared,
    onReturnToPath: onReturnToPath,
    onNeedEvidence: onNeedEvidence,
  ),
);

Finder get _scrollable => find
    .descendant(
      of: find.byKey(const ValueKey('science-legendary-scroll')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _scrollToAndTap(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 160, scrollable: _scrollable);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
}

Future<void> _answerTask(WidgetTester tester, String id) async {
  await _scrollToAndTap(
    tester,
    find.byKey(ValueKey('cognitive-task-choice-$id')),
  );
  await _scrollToAndTap(
    tester,
    find.byKey(const ValueKey('legendary-task-submit')),
  );
}

Future<void> _answerCheckpoint(WidgetTester tester, String id) async {
  await _scrollToAndTap(
    tester,
    find.byKey(ValueKey('legendary-checkpoint-option-$id')),
  );
  await _scrollToAndTap(
    tester,
    find.byKey(const ValueKey('legendary-checkpoint-submit')),
  );
}

void _expectReferenceHidden(WidgetTester tester) {
  expect(find.textContaining(challengeVariant.expectedOutcome), findsNothing);
  expect(find.textContaining(challengeVariant.expectedReason), findsNothing);
  expect(find.textContaining(challengeCheckpoint.explanation), findsNothing);
  for (final option in challengeCheckpoint.options) {
    if (option.hint != null) {
      expect(find.textContaining(option.hint!), findsNothing);
    }
  }
  expect(
    find.bySemanticsLabel(
      RegExp(RegExp.escape(challengeVariant.expectedOutcome)),
    ),
    findsNothing,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('固定解照合は選択・分類・順序を完全一致でだけ通す', () {
    expect(
      matchesCognitiveTaskSolution(
        challengeTask,
        const SingleSelectTaskResponse('task-together'),
      ),
      isTrue,
    );
    expect(
      matchesCognitiveTaskSolution(
        challengeTask,
        const SingleSelectTaskResponse('task-heavy'),
      ),
      isFalse,
    );

    const classify = LocalCognitiveTask(
      kind: LocalCognitiveTaskKind.classify,
      operation: LocalCognitiveOperation.experimentPlan,
      items: [
        LocalCognitiveTaskItem(id: 'mass', text: '質量'),
        LocalCognitiveTaskItem(id: 'shape', text: '形'),
        LocalCognitiveTaskItem(id: 'time', text: '着地時刻'),
      ],
      targets: [
        LocalCognitiveTaskTarget(id: 'change', label: '変える'),
        LocalCognitiveTaskTarget(id: 'hold', label: 'そろえる'),
        LocalCognitiveTaskTarget(id: 'measure', label: '測る'),
      ],
      solution: LocalClassifySolution(
        targetByItemId: {'mass': 'change', 'shape': 'hold', 'time': 'measure'},
      ),
    );
    expect(
      matchesCognitiveTaskSolution(
        classify,
        ClassifyTaskResponse({
          'mass': 'change',
          'shape': 'hold',
          'time': 'measure',
        }),
      ),
      isTrue,
    );
    expect(
      matchesCognitiveTaskSolution(
        classify,
        ClassifyTaskResponse({
          'mass': 'hold',
          'shape': 'change',
          'time': 'measure',
        }),
      ),
      isFalse,
    );

    const sequence = LocalCognitiveTask(
      kind: LocalCognitiveTaskKind.sequence,
      operation: LocalCognitiveOperation.causalOrder,
      items: [
        LocalCognitiveTaskItem(id: 'current', text: '電流'),
        LocalCognitiveTaskItem(id: 'flux', text: '磁束変化'),
        LocalCognitiveTaskItem(id: 'voltage', text: '誘導電圧'),
      ],
      targets: [],
      solution: LocalSequenceSolution(
        orderedItemIds: ['flux', 'voltage', 'current'],
      ),
    );
    expect(
      matchesCognitiveTaskSolution(
        sequence,
        SequenceTaskResponse(['flux', 'voltage', 'current']),
      ),
      isTrue,
    );
    expect(
      matchesCognitiveTaskSolution(
        sequence,
        SequenceTaskResponse(['current', 'flux', 'voltage']),
      ),
      isFalse,
    );
  });

  testWidgets('上位が未解放なら課題も正本も構築しない', (tester) async {
    final semantics = tester.ensureSemantics();
    var completed = 0;
    var returned = 0;
    await tester.pumpWidget(
      _wrap(
        isUnlocked: false,
        onCompleted: () => completed++,
        onReturnToPath: () => returned++,
      ),
    );

    expect(find.byKey(const ValueKey('legendary-locked')), findsOneWidget);
    expect(find.textContaining('翌学習日以降'), findsOneWidget);
    expect(find.textContaining('通常課題・復習・学校課題'), findsOneWidget);
    expect(find.textContaining('通常レッスン'), findsNothing);
    expect(find.text(challengeVariant.transferPrompt), findsNothing);
    expect(find.text(challengeCheckpoint.lure), findsNothing);
    expect(find.byKey(const ValueKey('cognitive-task-input')), findsNothing);
    _expectReferenceHidden(tester);
    expect(completed, 0);
    expect(returned, 0);
    expect(
      find.byKey(const ValueKey('legendary-return-to-path')),
      findsNothing,
    );
    semantics.dispose();
  });

  testWidgets('ヒントなしの2問→自己比較を通過したときだけ完了を一度通知する', (tester) async {
    final semantics = tester.ensureSemantics();
    var completed = 0;
    var returned = 0;
    await tester.pumpWidget(
      _wrap(
        isUnlocked: true,
        disableAnimations: true,
        onCompleted: () => completed++,
        onReturnToPath: () => returned++,
      ),
    );

    expect(find.byKey(const ValueKey('legendary-task')), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('ラボ・ブリーフ.*高難度検証.*1/3.*落下の速さ.*ヒントなし')),
      findsOneWidget,
    );
    _expectReferenceHidden(tester);
    await _answerTask(tester, 'task-together');

    expect(find.byKey(const ValueKey('legendary-checkpoint')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('選択肢1.*重い球が先に着く')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('cognitive-task-choice-task-heavy')),
      findsNothing,
      reason: '確定した構造課題へ戻って総当たりできない',
    );
    _expectReferenceHidden(tester);
    await _answerCheckpoint(tester, 'same-time');

    expect(find.byKey(const ValueKey('legendary-comparison')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('自己比較.*教材の違いを一文')), findsOneWidget);
    expect(
      find.textContaining(challengeVariant.expectedOutcome),
      findsOneWidget,
    );
    expect(
      find.textContaining(challengeVariant.expectedReason),
      findsOneWidget,
    );
    expect(
      find.textContaining(challengeCheckpoint.explanation),
      findsOneWidget,
    );
    for (final option in challengeCheckpoint.options) {
      if (option.hint != null) {
        expect(find.textContaining(option.hint!), findsNothing);
      }
    }
    expect(completed, 0, reason: '自己比較を書く前は完了にしない');

    final reflection = find.byKey(const ValueKey('legendary-reflection'));
    await tester.scrollUntilVisible(reflection, 160, scrollable: _scrollable);
    await tester.enterText(reflection, '真空という条件を根拠にできていた。');
    await tester.pump();

    final finish = find.byKey(const ValueKey('legendary-finish'));
    await tester.scrollUntilVisible(finish, 160, scrollable: _scrollable);
    await tester.pump();
    await tester.tap(finish);
    await tester.tap(finish);
    await tester.pump();

    expect(completed, 1);
    expect(find.byKey(const ValueKey('legendary-done')), findsOneWidget);
    expect(find.text('高難度検証を完了'), findsOneWidget);
    expect(find.textContaining('習得した'), findsNothing);
    expect(returned, 0, reason: 'onCompletedで自動帰還しない');

    final returnToPath = find.byKey(const ValueKey('legendary-return-to-path'));
    expect(tester.getSize(returnToPath).height, greaterThanOrEqualTo(56));
    expect(find.bySemanticsLabel('探究ノートへ戻る'), findsOneWidget);
    await tester.tap(returnToPath);
    await tester.tap(returnToPath);
    await tester.pump();
    expect(returned, 1);
    semantics.dispose();
  });

  testWidgets('最初の固定誤答で次問を開かず、未クリアを一度だけ通知する', (tester) async {
    var completed = 0;
    var notCleared = 0;
    var returned = 0;
    final needs = <LearningNeedEvidence>[];
    await tester.pumpWidget(
      _wrap(
        isUnlocked: true,
        disableAnimations: true,
        onCompleted: () => completed++,
        onNotCleared: () => notCleared++,
        onReturnToPath: () => returned++,
        onNeedEvidence: needs.add,
      ),
    );
    await _answerTask(tester, 'task-heavy');

    expect(needs, hasLength(1));
    expect(needs.single.conceptKey, 'fall');
    expect(needs.single.needCode, 'science.fall.transfer');
    expect(needs.single.kind, LearningNeedEvidenceKind.observed);

    expect(notCleared, 1, reason: '最初の誤答で失敗を確定し、次の固定問を開かない');

    expect(find.byKey(const ValueKey('legendary-checkpoint')), findsNothing);
    expect(find.byKey(const ValueKey('legendary-comparison')), findsNothing);
    expect(find.byKey(const ValueKey('legendary-done')), findsOneWidget);
    _expectReferenceHidden(tester);

    expect(completed, 0);
    expect(notCleared, 1);
    expect(returned, 0);
    final returnToPractice = find.byKey(
      const ValueKey('legendary-return-to-path'),
    );
    expect(returnToPractice, findsOneWidget);
    expect(find.bySemanticsLabel('通常練習へ戻る'), findsOneWidget);
    await tester.tap(returnToPractice);
    await tester.pump();
    expect(returned, 1);
    expect(find.text('今回はここまで'), findsOneWidget);
    expect(find.textContaining('回復練習'), findsOneWidget);
  });

  testWidgets('320x568・文200%・Reduce Motionで完走でき、操作面は48dp以上', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    var completed = 0;
    var returned = 0;
    await tester.pumpWidget(
      _wrap(
        isUnlocked: true,
        textScale: 2,
        disableAnimations: true,
        onCompleted: () => completed++,
        onReturnToPath: () => returned++,
      ),
    );

    for (final switcher in tester.widgetList<AnimatedSwitcher>(
      find.byType(AnimatedSwitcher),
    )) {
      expect(switcher.duration, Duration.zero);
    }

    final taskChoice = find.byKey(
      const ValueKey('cognitive-task-choice-task-together'),
    );
    await tester.scrollUntilVisible(taskChoice, 160, scrollable: _scrollable);
    expect(tester.getSize(taskChoice).height, greaterThanOrEqualTo(48));
    await tester.tap(taskChoice);
    await tester.pump();

    final taskSubmit = find.byKey(const ValueKey('legendary-task-submit'));
    await tester.scrollUntilVisible(taskSubmit, 160, scrollable: _scrollable);
    expect(tester.getSize(taskSubmit).height, greaterThanOrEqualTo(48));
    await tester.tap(taskSubmit);
    await tester.pump();

    final checkpoint = find.byKey(
      const ValueKey('legendary-checkpoint-option-same-time'),
    );
    await tester.scrollUntilVisible(checkpoint, 160, scrollable: _scrollable);
    expect(tester.getSize(checkpoint).height, greaterThanOrEqualTo(48));
    await tester.tap(checkpoint);
    await tester.pump();

    final checkpointSubmit = find.byKey(
      const ValueKey('legendary-checkpoint-submit'),
    );
    await tester.scrollUntilVisible(
      checkpointSubmit,
      160,
      scrollable: _scrollable,
    );
    expect(tester.getSize(checkpointSubmit).height, greaterThanOrEqualTo(48));
    await tester.tap(checkpointSubmit);
    await tester.pump();

    final reflection = find.byKey(const ValueKey('legendary-reflection'));
    await tester.scrollUntilVisible(reflection, 160, scrollable: _scrollable);
    expect(tester.getSize(reflection).height, greaterThanOrEqualTo(48));
    await tester.enterText(reflection, '条件と結果を比べた。');
    await tester.pump();

    final finish = find.byKey(const ValueKey('legendary-finish'));
    await tester.scrollUntilVisible(finish, 160, scrollable: _scrollable);
    expect(tester.getSize(finish).height, greaterThanOrEqualTo(48));
    await tester.tap(finish);
    await tester.pump();

    expect(completed, 1);
    expect(find.text('高難度検証を完了'), findsOneWidget);
    expect(returned, 0);
    final returnToPath = find.byKey(const ValueKey('legendary-return-to-path'));
    await tester.scrollUntilVisible(returnToPath, 160, scrollable: _scrollable);
    expect(tester.getSize(returnToPath).height, greaterThanOrEqualTo(56));
    await tester.tap(returnToPath);
    await tester.pump();
    expect(returned, 1);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
