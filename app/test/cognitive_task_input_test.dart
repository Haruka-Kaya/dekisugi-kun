import 'dart:ui' show SemanticsAction, Tristate;

import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/models/unit.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/cognitive_task_input.dart';
import 'package:flutter_test/flutter_test.dart';

const _choicePrompt = LocalCognitiveTaskPrompt(
  kind: LocalCognitiveTaskKind.singleSelect,
  operation: LocalCognitiveOperation.prediction,
  items: [
    LocalCognitiveTaskItem(id: 'heavy', text: '重い球が先に着く'),
    LocalCognitiveTaskItem(id: 'same-time', text: 'ほぼ同時に着く'),
    LocalCognitiveTaskItem(id: 'light', text: '軽い球が先に着く'),
  ],
  targets: [],
);

const _classifyTask = LocalCognitiveTask(
  kind: LocalCognitiveTaskKind.classify,
  operation: LocalCognitiveOperation.experimentPlan,
  items: [
    LocalCognitiveTaskItem(id: 'mass', text: '球の質量'),
    LocalCognitiveTaskItem(id: 'shape', text: '球の形'),
    LocalCognitiveTaskItem(id: 'arrival', text: '着地時刻'),
  ],
  targets: [
    LocalCognitiveTaskTarget(id: 'change', label: '変える'),
    LocalCognitiveTaskTarget(id: 'hold', label: 'そろえる'),
    LocalCognitiveTaskTarget(id: 'measure', label: '測る'),
  ],
  solution: LocalClassifySolution(
    targetByItemId: {'mass': 'change', 'shape': 'hold', 'arrival': 'measure'},
  ),
);

const _sequenceTask = LocalCognitiveTask(
  kind: LocalCognitiveTaskKind.sequence,
  operation: LocalCognitiveOperation.causalOrder,
  items: [
    LocalCognitiveTaskItem(id: 'voltage', text: '誘導電圧が生じる'),
    LocalCognitiveTaskItem(id: 'flux', text: '磁束が変化する'),
    LocalCognitiveTaskItem(id: 'current', text: '閉回路に電流が流れる'),
  ],
  targets: [],
  solution: LocalSequenceSolution(
    orderedItemIds: ['flux', 'voltage', 'current'],
  ),
);

Widget _wrap(Widget child, {double textScale = 1}) => MaterialApp(
  theme: buildAppTheme(Brightness.light),
  builder: (context, page) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: page!,
  ),
  home: Scaffold(
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('singleSelectは著者順の2〜4択を正誤なしで選び、回答完成だけを返す', (tester) async {
    final semantics = tester.ensureSemantics();
    CognitiveTaskResponse? response;

    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setInnerState) => CognitiveTaskInput(
            prompt: _choicePrompt,
            response: response,
            onChanged: (next) => setInnerState(() => response = next),
          ),
        ),
      ),
    );

    final firstTop = tester.getTopLeft(find.text('重い球が先に着く')).dy;
    final secondTop = tester.getTopLeft(find.text('ほぼ同時に着く')).dy;
    final thirdTop = tester.getTopLeft(find.text('軽い球が先に着く')).dy;
    expect(firstTop, lessThan(secondTop));
    expect(secondTop, lessThan(thirdTop));
    expect(isCognitiveTaskResponseComplete(_choicePrompt, response), isFalse);
    expect(find.textContaining('正解'), findsNothing);
    expect(find.textContaining('不正解'), findsNothing);

    final choice = find.byKey(
      const ValueKey('cognitive-task-choice-same-time'),
    );
    await tester.tap(choice);
    await tester.pump();

    expect(isCognitiveTaskResponseComplete(_choicePrompt, response), isTrue);
    expect(cognitiveTaskResponseSummary(_choicePrompt, response!), 'ほぼ同時に着く');
    expect(
      tester.getSemantics(choice).getSemanticsData().label,
      contains('選択肢2、全3件中'),
    );
    expect(
      tester.getSemantics(choice).getSemanticsData().flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(tester.getSize(choice).height, greaterThanOrEqualTo(48));
    semantics.dispose();
  });

  testWidgets('classifyは各カードの分類先を縦に選び、全件を置くまで未完了', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    CognitiveTaskResponse? response;

    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setInnerState) => CognitiveTaskInput(
            prompt: _classifyTask.prompt,
            response: response,
            onChanged: (next) => setInnerState(() => response = next),
          ),
        ),
        textScale: 2,
      ),
    );
    await tester.pump();

    expect(
      find.text('球の質量 → 変える'),
      findsNothing,
      reason: 'solutionの分類関係を回答前に文章として先出ししない',
    );
    for (final pair in [
      ('mass', 'change'),
      ('shape', 'hold'),
      ('arrival', 'measure'),
    ]) {
      final target = find.byKey(
        ValueKey('cognitive-task-classify-${pair.$1}-${pair.$2}'),
      );
      await tester.ensureVisible(target);
      await tester.pump();
      expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
      await tester.tap(target);
      await tester.pump();
    }

    expect(
      isCognitiveTaskResponseComplete(_classifyTask.prompt, response),
      isTrue,
    );
    expect(
      cognitiveTaskResponseSummary(_classifyTask.prompt, response!),
      '球の質量 → 変える\n球の形 → そろえる\n着地時刻 → 測る',
    );
    final selected = find.byKey(
      const ValueKey('cognitive-task-classify-shape-hold'),
    );
    expect(
      tester.getSemantics(selected).getSemanticsData().label,
      contains('カード2、全3件中。球の形。分類先、そろえる。選択中'),
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('sequenceは未配置項目をtapで追加し、番号付き回答をtapで取り消せる', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    CognitiveTaskResponse? response;

    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setInnerState) => CognitiveTaskInput(
            prompt: _sequenceTask.prompt,
            response: response,
            onChanged: (next) => setInnerState(() => response = next),
          ),
        ),
        textScale: 2,
      ),
    );
    await tester.pump();

    expect(find.text('1. 磁束が変化する'), findsNothing);
    for (final id in ['flux', 'voltage', 'current']) {
      final add = find.byKey(ValueKey('cognitive-task-sequence-add-$id'));
      await tester.ensureVisible(add);
      await tester.pump();
      expect(tester.getSize(add).height, greaterThanOrEqualTo(48));
      await tester.tap(add);
      await tester.pump();
    }
    expect(
      isCognitiveTaskResponseComplete(_sequenceTask.prompt, response),
      isTrue,
    );
    expect(
      cognitiveTaskResponseSummary(_sequenceTask.prompt, response!),
      '1. 磁束が変化する\n2. 誘導電圧が生じる\n3. 閉回路に電流が流れる',
    );

    final second = find.byKey(
      const ValueKey('cognitive-task-sequence-placed-voltage'),
    );
    await tester.ensureVisible(second);
    expect(
      tester.getSemantics(second).getSemanticsData().label,
      contains('2番目、全3件中'),
    );
    expect(
      tester
          .getSemantics(second)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    await tester.tap(second);
    await tester.pump();
    expect(
      isCognitiveTaskResponseComplete(_sequenceTask.prompt, response),
      isFalse,
    );
    expect(
      find.byKey(const ValueKey('cognitive-task-sequence-add-voltage')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  test('教材solutionの表示文は比較専用helperでのみ復元する', () {
    expect(
      cognitiveTaskSolutionSummary(_classifyTask),
      '球の質量 → 変える\n球の形 → そろえる\n着地時刻 → 測る',
    );
    expect(
      cognitiveTaskSolutionSummary(_sequenceTask),
      '1. 磁束が変化する\n2. 誘導電圧が生じる\n3. 閉回路に電流が流れる',
    );
  });
}
