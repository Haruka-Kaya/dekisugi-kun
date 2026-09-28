import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/motion.dart';
import 'package:dekisugi/learning/domain/learning_need.dart';
import 'package:dekisugi/models/unit.dart';
import 'package:dekisugi/screens/science_diagram_screen.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/cognitive_task_input.dart';
import 'package:flutter_test/flutter_test.dart';

const _checkpoint = LocalCheckpoint(
  lure: '比べる条件を変えても、結果はいつも同じになる。',
  options: [
    LocalCheckpointOption(
      id: 'always-same',
      text: 'いつも同じになる。',
      hint: '変えた条件と結果を分けて見ます。',
    ),
    LocalCheckpointOption(
      id: 'never-compare',
      text: '条件は比べられない。',
      hint: '一つだけ条件を変える場合を考えます。',
    ),
    LocalCheckpointOption(id: 'control-one', text: '一つだけ条件を変えて比べる。'),
  ],
  correctOptionId: 'control-one',
  explanation: '条件を一つだけ変えると、結果に影響した条件を分けて考えられます。',
);

const _singleTask = LocalCognitiveTask(
  kind: LocalCognitiveTaskKind.singleSelect,
  operation: LocalCognitiveOperation.prediction,
  needCode: 'science.heat-transfer.foundation',
  items: [
    LocalCognitiveTaskItem(id: 'single-a', text: '水温は下がる'),
    LocalCognitiveTaskItem(id: 'single-b', text: '水温は上がる'),
  ],
  targets: [],
  solution: LocalSingleSelectSolution(selectedItemId: 'single-b'),
);

const _classifyTask = LocalCognitiveTask(
  kind: LocalCognitiveTaskKind.classify,
  operation: LocalCognitiveOperation.experimentPlan,
  needCode: 'science.heat-transfer.conditions',
  items: [
    LocalCognitiveTaskItem(id: 'heater', text: 'ヒーターの強さ'),
    LocalCognitiveTaskItem(id: 'water', text: '水の量'),
    LocalCognitiveTaskItem(id: 'temperature', text: '5分後の水温'),
  ],
  targets: [
    LocalCognitiveTaskTarget(id: 'change', label: '変える'),
    LocalCognitiveTaskTarget(id: 'hold', label: 'そろえる'),
    LocalCognitiveTaskTarget(id: 'measure', label: '測る'),
  ],
  solution: LocalClassifySolution(
    targetByItemId: {
      'heater': 'change',
      'water': 'hold',
      'temperature': 'measure',
    },
  ),
);

const _sequenceTask = LocalCognitiveTask(
  kind: LocalCognitiveTaskKind.sequence,
  operation: LocalCognitiveOperation.causalOrder,
  needCode: 'science.heat-transfer.transfer',
  items: [
    LocalCognitiveTaskItem(id: 'steam', text: '水蒸気が増える'),
    LocalCognitiveTaskItem(id: 'heat', text: '水を加熱する'),
    LocalCognitiveTaskItem(id: 'boil', text: '水が沸騰する'),
  ],
  targets: [],
  solution: LocalSequenceSolution(orderedItemIds: ['heat', 'boil', 'steam']),
);

const _variants = [
  LocalPracticeVariant(
    stage: LocalPracticeStage.foundation,
    recallPrompt: '温度変化を思い出す。',
    reasoningPrompt: '温度が変わる理由を考える。',
    transferPrompt: '水を同じ時間だけ加熱すると、水温はどうなる？',
    expectedOutcome: '比較後だけ見える結果・選択',
    expectedReason: '比較後だけ見える理由・選択',
    cognitiveTask: _singleTask,
    checkpoint: _checkpoint,
  ),
  LocalPracticeVariant(
    stage: LocalPracticeStage.conditions,
    recallPrompt: '条件制御を思い出す。',
    reasoningPrompt: '公平な比較を考える。',
    transferPrompt: 'ヒーターの強さと水温の関係を調べる実験を組む。',
    expectedOutcome: '比較後だけ見える結果・分類',
    expectedReason: '比較後だけ見える理由・分類',
    cognitiveTask: _classifyTask,
    checkpoint: _checkpoint,
  ),
  LocalPracticeVariant(
    stage: LocalPracticeStage.transfer,
    recallPrompt: '沸騰の原理を思い出す。',
    reasoningPrompt: '現象の前後を考える。',
    transferPrompt: '水を温め始めてから水蒸気が増えるまでを順に組む。',
    expectedOutcome: '比較後だけ見える結果・順序',
    expectedReason: '比較後だけ見える理由・順序',
    cognitiveTask: _sequenceTask,
    checkpoint: _checkpoint,
  ),
];

const _section = Section(
  conceptKey: 'heat-transfer',
  title: '水の温度変化',
  body: ['条件をそろえて、加熱時間と水温を比べます。'],
  tryIt: '水の加熱実験を計画する。',
  localCheckpoint: _checkpoint,
  localPracticeVariants: _variants,
);

Widget _wrap({
  required int practiceAttempt,
  VoidCallback? onCompleted,
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
  home: ScienceDiagramScreen(
    section: _section,
    conceptLabel: '水の温度変化',
    practiceAttempt: practiceAttempt,
    onCompleted: onCompleted ?? () {},
    onReturnToPath: onReturnToPath,
    onNeedEvidence: onNeedEvidence,
  ),
);

Finder get _pageScrollable => find
    .descendant(
      of: find.byKey(const ValueKey('science-diagram-scroll')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _scrollToAndTap(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 160, scrollable: _pageScrollable);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
}

Future<void> _answerTask(WidgetTester tester, int practiceAttempt) async {
  switch (practiceAttempt) {
    case 0:
      // 教材と違う組み方でも、正誤判定せず先へ進める。
      await _scrollToAndTap(
        tester,
        find.byKey(const ValueKey('cognitive-task-choice-single-a')),
      );
    case 1:
      for (final pair in [
        ('heater', 'hold'),
        ('water', 'hold'),
        ('temperature', 'hold'),
      ]) {
        await _scrollToAndTap(
          tester,
          find.byKey(ValueKey('cognitive-task-classify-${pair.$1}-${pair.$2}')),
        );
      }
    case 2:
      // 著者順のままで、solutionと異なる順序を残す。
      for (final id in ['steam', 'heat', 'boil']) {
        await _scrollToAndTap(
          tester,
          find.byKey(ValueKey('cognitive-task-sequence-add-$id')),
        );
      }
  }
}

void _expectSolutionHidden(WidgetTester tester, LocalPracticeVariant variant) {
  expect(find.byKey(const ValueKey('science-diagram-solution')), findsNothing);
  expect(find.text('教材の組み方'), findsNothing);
  expect(find.text(variant.expectedOutcome), findsNothing);
  expect(find.text(variant.expectedReason), findsNothing);
  expect(
    find.bySemanticsLabel(RegExp(RegExp.escape(variant.expectedOutcome))),
    findsNothing,
  );
  expect(
    find.bySemanticsLabel(RegExp(RegExp.escape(variant.expectedReason))),
    findsNothing,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('active variantの選択・分類・順序を理由→比較→自分の一文で完了する', (tester) async {
    final semantics = tester.ensureSemantics();

    for (var attempt = 0; attempt < _variants.length; attempt++) {
      final variant = _variants[attempt];
      var completed = 0;
      var returned = 0;
      final needs = <LearningNeedEvidence>[];
      await tester.pumpWidget(
        KeyedSubtree(
          key: ValueKey('science-diagram-case-$attempt'),
          child: _wrap(
            practiceAttempt: attempt,
            disableAnimations: true,
            onCompleted: () => completed++,
            onReturnToPath: () => returned++,
            onNeedEvidence: needs.add,
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('固定の復習コードだけ'), findsOneWidget);
      expect(find.textContaining('成績や理解度の認定には使いません'), findsOneWidget);
      expect(find.text(variant.transferPrompt), findsOneWidget);
      for (final other in _variants.where((item) => item != variant)) {
        expect(find.text(other.transferPrompt), findsNothing);
      }
      _expectSolutionHidden(tester, variant);

      await _answerTask(tester, attempt);
      expect(
        find.byKey(const ValueKey('science-diagram-reason-area')),
        findsOneWidget,
      );
      _expectSolutionHidden(tester, variant);

      await tester.enterText(
        find.byKey(const ValueKey('science-diagram-reason')),
        '条件の違いが結果につながると考えた。',
      );
      await tester.pump();
      _expectSolutionHidden(tester, variant);

      await _scrollToAndTap(
        tester,
        find.byKey(const ValueKey('science-diagram-submit')),
      );
      expect(needs, hasLength(1));
      expect(needs.single.conceptKey, 'heat-transfer');
      expect(needs.single.needCode, variant.cognitiveTask.needCode);
      expect(needs.single.kind, LearningNeedEvidenceKind.observed);
      expect(
        find.byKey(const ValueKey('science-diagram-compare')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('science-diagram-solution')),
        findsOneWidget,
      );
      expect(
        find.text(cognitiveTaskSolutionSummary(variant.cognitiveTask)),
        findsOneWidget,
      );
      expect(find.text(variant.expectedOutcome), findsOneWidget);
      expect(find.text(variant.expectedReason), findsOneWidget);
      expect(find.textContaining('正解'), findsNothing);
      expect(find.textContaining('不正解'), findsNothing);

      await _scrollToAndTap(
        tester,
        find.byKey(const ValueKey('science-diagram-revise')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('science-diagram-reflection')),
        '次は変える条件を一つにして比べる。',
      );
      await tester.pump();

      final complete = find.byKey(const ValueKey('science-diagram-complete'));
      await tester.scrollUntilVisible(
        complete,
        160,
        scrollable: _pageScrollable,
      );
      await tester.pump();
      await tester.tap(complete);
      await tester.tap(complete, warnIfMissed: false);
      await tester.pump();

      expect(completed, 1, reason: 'practiceAttempt=$attempt');
      expect(
        find.byKey(const ValueKey('science-diagram-finished')),
        findsOneWidget,
      );
      expect(returned, 0, reason: '完了時に自動でパスへ戻らない');
      final returnToPath = find.byKey(
        const ValueKey('science-diagram-return-to-path'),
      );
      expect(tester.getSize(returnToPath).height, greaterThanOrEqualTo(48));
      await tester.tap(returnToPath);
      expect(returned, 1);
      expect(find.textContaining('習得した'), findsNothing);
    }

    semantics.dispose();
  });

  testWidgets('送信前はsolutionをwidget treeとSemanticsに入れない', (tester) async {
    final semantics = tester.ensureSemantics();
    final variant = _variants[2];

    await tester.pumpWidget(_wrap(practiceAttempt: 2, disableAnimations: true));
    _expectSolutionHidden(tester, variant);
    expect(find.text('1. 水を加熱する\n2. 水が沸騰する\n3. 水蒸気が増える'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('教材の組み方')), findsNothing);

    await _answerTask(tester, 2);
    await tester.enterText(
      find.byKey(const ValueKey('science-diagram-reason')),
      '現象の前後関係からこの順番にした。',
    );
    await tester.pump();
    _expectSolutionHidden(tester, variant);

    await _scrollToAndTap(
      tester,
      find.byKey(const ValueKey('science-diagram-submit')),
    );
    expect(find.bySemanticsLabel(RegExp('教材の組み方.*水を加熱する')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('320x568・文200%・Reduce Motionでも操作できタッチ面は48dp以上', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    var completed = 0;
    var returned = 0;

    await tester.pumpWidget(
      _wrap(
        practiceAttempt: 1,
        textScale: 2,
        disableAnimations: true,
        onCompleted: () => completed++,
        onReturnToPath: () => returned++,
      ),
    );
    await tester.pump();

    for (final switcher in tester.widgetList<AnimatedSwitcher>(
      find.byType(AnimatedSwitcher),
    )) {
      expect(switcher.duration, Duration.zero);
    }

    for (final pair in [
      ('heater', 'hold'),
      ('water', 'hold'),
      ('temperature', 'hold'),
    ]) {
      final target = find.byKey(
        ValueKey('cognitive-task-classify-${pair.$1}-${pair.$2}'),
      );
      await tester.scrollUntilVisible(target, 160, scrollable: _pageScrollable);
      await tester.pump();
      expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
      await tester.tap(target);
      await tester.pump();
    }

    final reason = find.byKey(const ValueKey('science-diagram-reason'));
    await tester.scrollUntilVisible(reason, 160, scrollable: _pageScrollable);
    await tester.pump();
    expect(tester.getSize(reason).height, greaterThanOrEqualTo(48));
    await tester.enterText(reason, '他の条件をそろえると比べられる。');
    await tester.pump();

    final submit = find.byKey(const ValueKey('science-diagram-submit'));
    await tester.scrollUntilVisible(submit, 160, scrollable: _pageScrollable);
    await tester.pump();
    expect(tester.getSize(submit).height, greaterThanOrEqualTo(48));
    await tester.tap(submit);
    await tester.pump();

    final keep = find.byKey(const ValueKey('science-diagram-keep'));
    await tester.scrollUntilVisible(keep, 160, scrollable: _pageScrollable);
    await tester.pump();
    expect(tester.getSize(keep).height, greaterThanOrEqualTo(48));
    await tester.tap(keep);
    await tester.pump();

    final reflection = find.byKey(const ValueKey('science-diagram-reflection'));
    await tester.scrollUntilVisible(
      reflection,
      160,
      scrollable: _pageScrollable,
    );
    await tester.enterText(reflection, '変える条件を一つだけにする。');
    await tester.pump();

    final complete = find.byKey(const ValueKey('science-diagram-complete'));
    await tester.scrollUntilVisible(complete, 160, scrollable: _pageScrollable);
    await tester.pump();
    expect(tester.getSize(complete).height, greaterThanOrEqualTo(48));
    await tester.tap(complete);
    await tester.pump();

    expect(completed, 1);
    expect(
      find.byKey(const ValueKey('science-diagram-finished')),
      findsOneWidget,
    );
    expect(returned, 0);
    final returnToPath = find.byKey(
      const ValueKey('science-diagram-return-to-path'),
    );
    expect(tester.getSize(returnToPath).height, greaterThanOrEqualTo(48));
    await tester.tap(returnToPath);
    expect(returned, 1);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
