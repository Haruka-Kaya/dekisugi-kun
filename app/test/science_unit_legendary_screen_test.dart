import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/motion.dart';
import 'package:dekisugi/learning/domain/learning_need.dart';
import 'package:dekisugi/models/unit.dart';
import 'package:dekisugi/screens/science_unit_legendary_screen.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/science_challenge_fixture.dart';

const _inertiaCheckpoint = LocalCheckpoint(
  lure: '台車を押すのをやめると、力がなくなるのでその場で止まる。',
  options: [
    LocalCheckpointOption(
      id: 'stop-now',
      text: '押すのをやめた場所ですぐ止まる。',
      hint: '運動を変える力と、動いている状態を分けます。',
      needCode: 'science.inertia.transfer',
    ),
    LocalCheckpointOption(id: 'keep-then-slow', text: '進み続け、摩擦で次第に遅くなる。'),
    LocalCheckpointOption(
      id: 'speed-up',
      text: '押すのをやめた後も速くなる。',
      hint: '速さを増す向きの力が残っているか確かめます。',
      needCode: 'science.inertia.transfer',
    ),
  ],
  correctOptionId: 'keep-then-slow',
  explanation: '物体は運動状態を保とうとし、床との摩擦が速さを下げます。',
);

const _inertiaTask = LocalCognitiveTask(
  kind: LocalCognitiveTaskKind.singleSelect,
  operation: LocalCognitiveOperation.prediction,
  items: [
    LocalCognitiveTaskItem(id: 'stop', text: 'その場で止まる'),
    LocalCognitiveTaskItem(id: 'keep-moving', text: '進み続けてから遅くなる'),
    LocalCognitiveTaskItem(id: 'accelerate', text: 'さらに速くなる'),
  ],
  targets: [],
  solution: LocalSingleSelectSolution(selectedItemId: 'keep-moving'),
  needCode: 'science.inertia.transfer',
);

const _inertiaVariant = LocalPracticeVariant(
  stage: LocalPracticeStage.transfer,
  recallPrompt: '慣性を思い出す。',
  reasoningPrompt: '合力と摩擦を分ける。',
  transferPrompt: '水平な床の台車を押して手を離すと、直後はどう動く？',
  expectedOutcome: '台車は直後も進み続け、その後ゆっくり遅くなります。',
  expectedReason: '慣性で運動を保ち、摩擦が運動を変えるためです。',
  cognitiveTask: _inertiaTask,
  checkpoint: _inertiaCheckpoint,
);

const _inertiaSection = Section(
  conceptKey: 'inertia',
  title: '慣性',
  body: ['合力が0なら、物体は運動状態を保ちます。'],
  tryIt: '台車を押して手を離す。',
  localCheckpoint: _inertiaCheckpoint,
  localPracticeVariants: [_inertiaVariant, _inertiaVariant, _inertiaVariant],
);

const _challenges = [
  ScienceUnitLegendaryChallenge(
    section: challengeSection,
    conceptLabel: '落下',
    practiceAttempt: challengePracticeAttempt,
  ),
  ScienceUnitLegendaryChallenge(
    section: _inertiaSection,
    conceptLabel: '慣性',
    practiceAttempt: 2,
  ),
];

Widget _wrap({
  bool isUnlocked = true,
  VoidCallback? onCompleted,
  VoidCallback? onNotCleared,
  VoidCallback? onReturnToPath,
  LearningNeedEvidenceReported? onNeedEvidence,
  double textScale = 1,
}) => MaterialApp(
  theme: buildAppTheme(Brightness.light),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: true,
    ),
    child: ReduceMotionScope(child: child!),
  ),
  home: ScienceUnitLegendaryScreen(
    unitTitle: '力と運動',
    challenges: _challenges,
    isUnlocked: isUnlocked,
    onCompleted: onCompleted ?? () {},
    onNeedEvidence: onNeedEvidence,
    onNotCleared: onNotCleared,
    onReturnToPath: onReturnToPath,
  ),
);

Finder get _scrollable => find
    .descendant(
      of: find.byKey(const ValueKey('science-unit-legendary-scroll')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _tapVisible(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 180, scrollable: _scrollable);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
}

Future<void> _answerTask(WidgetTester tester, String itemId) async {
  await _tapVisible(
    tester,
    find.byKey(ValueKey('cognitive-task-choice-$itemId')),
  );
  await _tapVisible(
    tester,
    find.byKey(const ValueKey('unit-legendary-task-submit')),
  );
}

Future<void> _answerCheckpoint(
  WidgetTester tester,
  String conceptKey,
  String optionId,
) async {
  await _tapVisible(
    tester,
    find.byKey(
      ValueKey('unit-legendary-checkpoint-option-$conceptKey-$optionId'),
    ),
  );
  await _tapVisible(
    tester,
    find.byKey(const ValueKey('unit-legendary-checkpoint-submit')),
  );
}

void _expectReferencesHidden() {
  expect(find.textContaining(challengeVariant.expectedOutcome), findsNothing);
  expect(find.textContaining(challengeVariant.expectedReason), findsNothing);
  expect(find.textContaining(challengeCheckpoint.explanation), findsNothing);
  expect(find.textContaining(_inertiaVariant.expectedOutcome), findsNothing);
  expect(find.textContaining(_inertiaVariant.expectedReason), findsNothing);
  expect(find.textContaining(_inertiaCheckpoint.explanation), findsNothing);
}

void main() {
  testWidgets('未解放時は複数conceptの問いと正本を構築しない', (tester) async {
    await tester.pumpWidget(_wrap(isUnlocked: false));

    expect(find.byKey(const ValueKey('unit-legendary-locked')), findsOneWidget);
    expect(find.textContaining('全章ボス'), findsOneWidget);
    expect(find.text(challengeVariant.transferPrompt), findsNothing);
    expect(find.text(_inertiaVariant.transferPrompt), findsNothing);
    _expectReferencesHidden();
  });

  testWidgets('全conceptを最初の回答で通過し、全回答後だけ正本と完了を開く', (tester) async {
    var completed = 0;
    var returned = 0;
    await tester.pumpWidget(
      _wrap(onCompleted: () => completed++, onReturnToPath: () => returned++),
    );

    expect(
      find.byKey(const ValueKey('unit-legendary-task-fall')),
      findsOneWidget,
    );
    expect(find.textContaining('1 OF 4'), findsOneWidget);
    _expectReferencesHidden();
    await _answerTask(tester, 'task-together');
    await _answerCheckpoint(tester, 'fall', 'same-time');

    expect(
      find.byKey(const ValueKey('unit-legendary-task-inertia')),
      findsOneWidget,
    );
    expect(find.textContaining('3 OF 4'), findsOneWidget);
    _expectReferencesHidden();
    await _answerTask(tester, 'keep-moving');
    await _answerCheckpoint(tester, 'inertia', 'keep-then-slow');

    expect(
      find.byKey(const ValueKey('unit-legendary-comparison')),
      findsOneWidget,
    );
    expect(
      find.textContaining(challengeVariant.expectedOutcome),
      findsOneWidget,
    );
    expect(
      find.textContaining(_inertiaVariant.expectedOutcome),
      findsOneWidget,
    );
    expect(completed, 0, reason: '自己比較文の入力前は完了にしない');

    final reflection = find.byKey(const ValueKey('unit-legendary-reflection'));
    await tester.scrollUntilVisible(reflection, 180, scrollable: _scrollable);
    await tester.enterText(reflection, '力が運動を変える条件を、落下と慣性で比べた。');
    await tester.pump();
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('unit-legendary-finish')),
    );

    expect(completed, 1);
    expect(find.byKey(const ValueKey('unit-legendary-done')), findsOneWidget);
    expect(find.text('Unit高難度課題クリア'), findsOneWidget);
    expect(find.textContaining('習得した'), findsNothing);
    expect(returned, 0);
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('unit-legendary-return-to-path')),
    );
    expect(returned, 1);
  });

  testWidgets('最初の固定誤答で残りの全問を開かず未クリアを一度だけ通知する', (tester) async {
    var completed = 0;
    var notCleared = 0;
    final evidence = <LearningNeedEvidence>[];
    await tester.pumpWidget(
      _wrap(
        onCompleted: () => completed++,
        onNotCleared: () => notCleared++,
        onNeedEvidence: evidence.add,
      ),
    );

    await _answerTask(tester, 'task-heavy');

    expect(notCleared, 1);
    expect(completed, 0);
    expect(
      evidence,
      contains(
        isA<LearningNeedEvidence>()
            .having((item) => item.conceptKey, 'conceptKey', 'fall')
            .having(
              (item) => item.needCode,
              'needCode',
              'science.fall.transfer',
            )
            .having(
              (item) => item.kind,
              'kind',
              LearningNeedEvidenceKind.observed,
            ),
      ),
      reason: '回答やoption IDではなく、concept付き固定needだけを返す',
    );
    expect(find.byKey(const ValueKey('unit-legendary-done')), findsOneWidget);
    expect(find.textContaining('回復練習'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('unit-legendary-checkpoint-fall')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('unit-legendary-task-inertia')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('unit-legendary-task-fall')),
      findsNothing,
      reason: '最初の誤答後に同じrunで総当たりできない',
    );
    _expectReferencesHidden();
  });

  testWidgets('320x568・文字200%・Reduce Motionでも最初のconceptを操作できる', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(textScale: 2));

    final choice = find.byKey(
      const ValueKey('cognitive-task-choice-task-together'),
    );
    await tester.scrollUntilVisible(choice, 180, scrollable: _scrollable);
    expect(tester.getSize(choice).height, greaterThanOrEqualTo(48));
    await tester.tap(choice);
    await tester.pump();
    final submit = find.byKey(const ValueKey('unit-legendary-task-submit'));
    await tester.scrollUntilVisible(submit, 180, scrollable: _scrollable);
    expect(tester.getSize(submit).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });
}
