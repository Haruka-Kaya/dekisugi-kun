import 'dart:io';
import 'dart:ui' show SemanticsAction;

import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/learning/domain/learning_need.dart';
import 'package:dekisugi/models/game_path.dart';
import 'package:dekisugi/models/mission.dart';
import 'package:dekisugi/models/unit.dart';
import 'package:dekisugi/screens/offline_practice_screen.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/science_challenge_support.dart';
import 'package:flutter_test/flutter_test.dart';

const _checkpoint = LocalCheckpoint(
  lure: '空気のない場所でも、重い球のほうが先に着く。',
  options: [
    LocalCheckpointOption(
      id: 'heavy',
      text: '重い球が先に着く。',
      hint: '重力と動かしにくさの両方を考える。',
      needCode: 'science.fall.foundation',
    ),
    LocalCheckpointOption(id: 'together', text: '2つは同時に着く。'),
    LocalCheckpointOption(
      id: 'light',
      text: '軽い球が先に着く。',
      hint: '重さだけで落下加速度は変わらない。',
      needCode: 'science.fall.foundation',
    ),
  ],
  correctOptionId: 'together',
  explanation: '空気抵抗を無視すれば、落下加速度は重さによらない。',
);

const _conditionsCheckpoint = LocalCheckpoint(
  lure: '羽根が遅く落ちたので、質量だけが落下加速度を決める。',
  options: [
    LocalCheckpointOption(
      id: 'mass-only',
      text: '質量だけの効果だと決められる。',
      hint: '形と空気抵抗の条件も比べます。',
      needCode: 'science.fall.conditions',
    ),
    LocalCheckpointOption(
      id: 'air-same',
      text: '空気はどの物体も同じだけ押す。',
      hint: '空気抵抗は形や面積でも変わります。',
      needCode: 'science.fall.conditions',
    ),
    LocalCheckpointOption(id: 'control-conditions', text: '形や空気抵抗の影響を分けて比べる。'),
  ],
  correctOptionId: 'control-conditions',
  explanation: '質量以外の条件をそろえないと、質量だけの効果とはいえません。',
);

const _transferCheckpoint = LocalCheckpoint(
  lure: '磁石が止まっていても、コイルには電流が流れ続ける。',
  options: [
    LocalCheckpointOption(
      id: 'field-enough',
      text: '磁界があれば変化しなくても流れ続ける。',
      hint: '磁束が時間とともに変わるかを見ます。',
      needCode: 'science.fall.transfer',
    ),
    LocalCheckpointOption(
      id: 'current-first',
      text: '電流が先に流れてから磁束が変わる。',
      hint: '原因と結果の順番を見直します。',
      needCode: 'science.fall.transfer',
    ),
    LocalCheckpointOption(
      id: 'change-needed',
      text: '磁束が変化すると誘導電圧が生じ、閉回路なら電流が流れる。',
    ),
  ],
  correctOptionId: 'change-needed',
  explanation: '磁束の変化が誘導電圧を生み、閉回路で電流になります。',
);

const _choiceTask = LocalCognitiveTask(
  kind: LocalCognitiveTaskKind.singleSelect,
  operation: LocalCognitiveOperation.prediction,
  items: [
    LocalCognitiveTaskItem(id: 'heavy-first', text: '重い球が先に着く'),
    LocalCognitiveTaskItem(id: 'same-time', text: '2つは同時に着く'),
    LocalCognitiveTaskItem(id: 'light-first', text: '軽い球が先に着く'),
  ],
  targets: [],
  solution: LocalSingleSelectSolution(selectedItemId: 'same-time'),
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
    LocalCognitiveTaskItem(id: 'current', text: '閉回路に電流が流れる'),
    LocalCognitiveTaskItem(id: 'flux', text: '磁束が変化する'),
    LocalCognitiveTaskItem(id: 'voltage', text: '誘導電圧が生じる'),
  ],
  targets: [],
  solution: LocalSequenceSolution(
    orderedItemIds: ['flux', 'voltage', 'current'],
  ),
);

const _section = Section(
  conceptKey: 'fall',
  title: '落下の速さ',
  body: [
    '空気の抵抗を無視できるなら、物体は重さに関係なく同じ加速度で落ちます。',
    '形が違うと空気抵抗の影響も変わるため、比べる条件をそろえる必要があります。',
  ],
  tryIt: '同じ形の重い球と軽い球を、真空中で同時に落とすとどうなる？',
  localCheckpoint: _checkpoint,
  localPracticeVariants: [
    LocalPracticeVariant(
      stage: LocalPracticeStage.foundation,
      recallPrompt: '教材を見ずに、落下の中心となる考えを説明してください。',
      reasoningPrompt: '選んだ結果になる理由を、条件と結び付けてください。',
      transferPrompt: '同じ形の重い球と軽い球を、真空中で同時に落とすとどうなる？',
      expectedOutcome: '観察では、2個の球が底へ触れる時刻に差は生じません。',
      expectedReason: '空気抵抗を無視すれば、落下加速度は重さによらないからです。',
      cognitiveTask: _choiceTask,
      checkpoint: _checkpoint,
    ),
    LocalPracticeVariant(
      stage: LocalPracticeStage.conditions,
      recallPrompt: '落下を公平に比べる条件を説明してください。',
      reasoningPrompt: '変える条件とそろえる条件を分けた理由を書いてください。',
      transferPrompt: '重さだけが違う球の落下を比べる実験を計画してください。',
      expectedOutcome: '質量だけを変え、形をそろえ、着地時刻を測ります。',
      expectedReason: '一度に一条件だけを変えると、質量の効果を分けて調べられます。',
      cognitiveTask: _classifyTask,
      checkpoint: _conditionsCheckpoint,
    ),
    LocalPracticeVariant(
      stage: LocalPracticeStage.transfer,
      recallPrompt: '電磁誘導が起きる条件を思い出してください。',
      reasoningPrompt: '組んだ順番になる理由を、磁束と回路で説明してください。',
      transferPrompt: '磁石をコイルへ動かしたときの因果を順に組んでください。',
      expectedOutcome: '磁束の変化の後に誘導電圧が生じ、閉回路なら電流が流れます。',
      expectedReason: '電流そのものではなく、まず磁束の変化が誘導電圧を生むからです。',
      cognitiveTask: _sequenceTask,
      checkpoint: _transferCheckpoint,
    ),
  ],
);

Widget _wrap({
  Widget? home,
  double textScale = 1,
  double bottomInset = 0,
  bool disableAnimations = false,
  Brightness brightness = Brightness.light,
  int practiceAttempt = 0,
  String? completionReference,
  Future<void> Function()? onCheckpointCompleted,
  LearningNeedEvidenceReported? onNeedEvidence,
}) => MaterialApp(
  theme: buildAppTheme(brightness),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
      viewInsets: EdgeInsets.only(bottom: bottomInset),
      disableAnimations: disableAnimations,
    ),
    child: child!,
  ),
  home:
      home ??
      OfflinePracticeScreen(
        section: _section,
        conceptLabel: '落下の速さ',
        missionKind: MissionKind.teach,
        practiceAttempt: practiceAttempt,
        completionReference: completionReference,
        onCheckpointCompleted: onCheckpointCompleted,
        onNeedEvidence: onNeedEvidence,
      ),
);

Finder _field(Key key) =>
    find.descendant(of: find.byKey(key), matching: find.byType(TextField));

Future<void> _enterAndContinue(
  WidgetTester tester, {
  required Key fieldKey,
  required Key buttonKey,
  required String text,
}) async {
  final field = _field(fieldKey);
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
  final button = find.byKey(buttonKey);
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _selectChoiceTask(
  WidgetTester tester, {
  String itemId = 'same-time',
}) async {
  final option = find.byKey(ValueKey('cognitive-task-choice-$itemId'));
  await tester.ensureVisible(option);
  await tester.tap(option);
  await tester.pump();
  final next = find.byKey(const ValueKey('offline-task-next'));
  await tester.ensureVisible(next);
  await tester.tap(next);
  await tester.pumpAndSettle();
}

Future<void> _completeClassifyTask(WidgetTester tester) async {
  for (final pair in [
    ('mass', 'change'),
    ('shape', 'hold'),
    ('arrival', 'measure'),
  ]) {
    final target = find.byKey(
      ValueKey('cognitive-task-classify-${pair.$1}-${pair.$2}'),
    );
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pump();
  }
  final next = find.byKey(const ValueKey('offline-task-next'));
  await tester.ensureVisible(next);
  await tester.tap(next);
  await tester.pumpAndSettle();
}

Future<void> _completeSequenceTask(WidgetTester tester) async {
  for (final id in ['flux', 'voltage', 'current']) {
    final add = find.byKey(ValueKey('cognitive-task-sequence-add-$id'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pump();
  }
  final next = find.byKey(const ValueKey('offline-task-next'));
  await tester.ensureVisible(next);
  await tester.tap(next);
  await tester.pumpAndSettle();
}

Future<void> _chooseCheckpoint(
  WidgetTester tester, {
  required String optionId,
}) async {
  final option = find.byKey(ValueKey('offline-checkpoint-option-$optionId'));
  await tester.ensureVisible(option);
  await tester.tap(option);
  await tester.pump();
  final submit = find.byKey(const ValueKey('offline-checkpoint-submit'));
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

Future<void> _reachChoiceCheckpoint(WidgetTester tester) async {
  await _enterAndContinue(
    tester,
    fieldKey: const ValueKey('offline-recall-input'),
    buttonKey: const ValueKey('offline-recall-next'),
    text: '重さではなく、条件をそろえて落下を考える。',
  );
  await _selectChoiceTask(tester);
  await _enterAndContinue(
    tester,
    fieldKey: const ValueKey('offline-reasoning-input'),
    buttonKey: const ValueKey('offline-reasoning-next'),
    text: '空気抵抗を無視できる条件だから。',
  );
}

Future<void> _completeComparison(
  WidgetTester tester, {
  String reflection = '自分の答えと教材の組み方を比べた。',
}) async {
  final decision = find.byKey(
    const ValueKey('prediction-result-decision-keep'),
  );
  await tester.ensureVisible(decision);
  await tester.tap(decision);
  await tester.pump();
  final input = find.byKey(
    const ValueKey('prediction-result-reflection-input'),
  );
  await tester.ensureVisible(input);
  await tester.enterText(input, reflection);
  await tester.pump();
  final complete = find.byKey(const ValueKey('prediction-result-complete'));
  await tester.ensureVisible(complete);
  await tester.tap(complete);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('想起→構造task→根拠→checkpoint→比較の順で、結果を先出ししない', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap());
    await tester.pump();

    expect(
      tester
          .widget<ScienceChallengeHeader>(find.byType(ScienceChallengeHeader))
          .mascotReaction,
      GameCharacterReaction.invite,
    );
    expect(find.text('教材を閉じたまま、説明する'), findsOneWidget);
    expect(find.text(_section.body.first), findsNothing);
    expect(find.text(_section.tryIt), findsNothing);
    expect(
      find.text(_section.localPracticeVariants.first.expectedOutcome),
      findsNothing,
    );

    final recallNext = find.byKey(const ValueKey('offline-recall-next'));
    expect(tester.widget<FilledButton>(recallNext).onPressed, isNull);
    await tester.enterText(
      _field(const ValueKey('offline-recall-input')),
      '  ',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(recallNext).onPressed, isNull);

    await _enterAndContinue(
      tester,
      fieldKey: const ValueKey('offline-recall-input'),
      buttonKey: const ValueKey('offline-recall-next'),
      text: '落下加速度は重さだけでは決まらない。',
    );
    expect(
      tester
          .widget<ScienceChallengeHeader>(find.byType(ScienceChallengeHeader))
          .mascotReaction,
      GameCharacterReaction.thinking,
    );
    expect(find.text('科学タスクを、組む'), findsOneWidget);
    expect(find.text(_section.tryIt), findsOneWidget);
    expect(find.byType(TextField), findsNothing, reason: '第2段階を4つ目の自由記述に戻さない');
    expect(find.textContaining('観察では'), findsNothing);
    final taskNext = find.byKey(const ValueKey('offline-task-next'));
    expect(tester.widget<FilledButton>(taskNext).onPressed, isNull);

    await _selectChoiceTask(tester);
    expect(find.text('決め手を、1つ書く'), findsOneWidget);
    expect(find.text('2つは同時に着く'), findsOneWidget);
    expect(find.textContaining('観察では'), findsNothing);
    final reasonNext = find.byKey(const ValueKey('offline-reasoning-next'));
    expect(tester.widget<FilledButton>(reasonNext).onPressed, isNull);

    await _enterAndContinue(
      tester,
      fieldKey: const ValueKey('offline-reasoning-input'),
      buttonKey: const ValueKey('offline-reasoning-next'),
      text: '空気抵抗を無視できるから。',
    );
    expect(
      find.byKey(const ValueKey('offline-checkpoint-step')),
      findsOneWidget,
    );
    expect(find.textContaining('観察では'), findsNothing);

    await _chooseCheckpoint(tester, optionId: 'together');
    expect(
      find.byKey(const ValueKey('prediction-result-compare')),
      findsOneWidget,
    );
    expect(find.textContaining('教材の組み方'), findsOneWidget);
    expect(find.textContaining('観察では'), findsOneWidget);
    expect(
      find.text(_section.body.first),
      findsNothing,
      reason: '根拠本文は必要なときだけ開く',
    );

    final complete = find.byKey(const ValueKey('prediction-result-complete'));
    expect(tester.widget<FilledButton>(complete).onPressed, isNull);
    await _completeComparison(tester);
    expect(
      find.byKey(const ValueKey('offline-practice-complete')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ScienceChallengeHeader>(find.byType(ScienceChallengeHeader))
          .mascotReaction,
      GameCharacterReaction.celebrate,
    );
    expect(find.textContaining('習得しました'), findsNothing);
    expect(find.textContaining('理解しました'), findsNothing);
  });

  testWidgets('checkpointの正しい直し方と解説は正答後の比較・完了面だけに出す', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_wrap());
    await tester.pump();
    await _reachChoiceCheckpoint(tester);

    expect(
      find.byKey(const ValueKey('offline-checkpoint-resolution')),
      findsNothing,
    );
    expect(find.text(_checkpoint.explanation), findsNothing);

    await _chooseCheckpoint(tester, optionId: 'together');
    final resolution = find.byKey(
      const ValueKey('offline-checkpoint-resolution'),
    );
    expect(resolution, findsOneWidget);
    expect(find.text('思い込みの直し方'), findsOneWidget);
    expect(find.text('2つは同時に着く。'), findsOneWidget);
    expect(find.text(_checkpoint.explanation), findsOneWidget);
    expect(
      tester.getSemantics(resolution).getSemanticsData().label,
      contains('思い込みの直し方。2つは同時に着く。'),
    );

    await _completeComparison(tester);
    expect(
      find.byKey(const ValueKey('offline-checkpoint-resolution')),
      findsOneWidget,
    );
    expect(find.text(_checkpoint.explanation), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('classifyの正しい組み方はtask中のUI/Semanticsになく、比較後だけ現れる', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(practiceAttempt: 1));
    await tester.pump();
    await _enterAndContinue(
      tester,
      fieldKey: const ValueKey('offline-recall-input'),
      buttonKey: const ValueKey('offline-recall-next'),
      text: '公平な比較では、変える条件を一つにする。',
    );

    expect(find.text('球の質量 → 変える'), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'球の質量.*分類先、変える.*選択中')), findsNothing);
    expect(
      find.text(_section.localPracticeVariants[1].expectedOutcome),
      findsNothing,
    );

    await _completeClassifyTask(tester);
    expect(find.text('球の質量 → 変える\n球の形 → そろえる\n着地時刻 → 測る'), findsOneWidget);
    expect(
      find.text(_section.localPracticeVariants[1].expectedOutcome),
      findsNothing,
    );
    await _enterAndContinue(
      tester,
      fieldKey: const ValueKey('offline-reasoning-input'),
      buttonKey: const ValueKey('offline-reasoning-next'),
      text: '一度に変える条件を一つにするため。',
    );
    await _chooseCheckpoint(tester, optionId: 'control-conditions');

    expect(
      find.textContaining('球の質量 → 変える\n球の形 → そろえる\n着地時刻 → 測る'),
      findsWidgets,
    );
    expect(find.textContaining('質量だけを変え'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('sequenceは同じattemptで著者順を保ち、本人が組んだ順と教材順を比較する', (tester) async {
    await tester.pumpWidget(_wrap(practiceAttempt: 2));
    await tester.pump();
    await _enterAndContinue(
      tester,
      fieldKey: const ValueKey('offline-recall-input'),
      buttonKey: const ValueKey('offline-recall-next'),
      text: '磁束の変化が必要。',
    );

    final currentTop = tester.getTopLeft(find.text('閉回路に電流が流れる')).dy;
    final fluxTop = tester.getTopLeft(find.text('磁束が変化する')).dy;
    expect(currentTop, lessThan(fluxTop), reason: 'taskの著者順を端末ごとにshuffleしない');
    expect(find.text('1. 磁束が変化する'), findsNothing);

    await _completeSequenceTask(tester);
    await _enterAndContinue(
      tester,
      fieldKey: const ValueKey('offline-reasoning-input'),
      buttonKey: const ValueKey('offline-reasoning-next'),
      text: '磁束変化が先に誘導電圧を生むから。',
    );
    await _chooseCheckpoint(tester, optionId: 'change-needed');
    expect(
      find.textContaining('1. 磁束が変化する\n2. 誘導電圧が生じる\n3. 閉回路に電流が流れる'),
      findsWidgets,
    );
  });

  testWidgets('checkpoint誤答後は別選択肢を試せず、本人の訂正メモと教材を比較する', (tester) async {
    final semantics = tester.ensureSemantics();
    final needs = <LearningNeedEvidence>[];
    await tester.pumpWidget(_wrap(onNeedEvidence: needs.add));
    await _reachChoiceCheckpoint(tester);

    await _chooseCheckpoint(tester, optionId: 'heavy');
    expect(needs, hasLength(1));
    expect(needs.single.conceptKey, 'fall');
    expect(needs.single.needCode, 'science.fall.foundation');
    expect(needs.single.kind, LearningNeedEvidenceKind.observed);
    final hint = find.byKey(const ValueKey('offline-checkpoint-hint'));
    final hintData = tester.getSemantics(hint).getSemanticsData();
    expect(hintData.label, contains('重力と動かしにくさの両方を考える'));
    expect(hintData.label, isNot(contains('あなたの予想')));
    expect(hintData.label, isNot(contains('2つは同時に着く')));

    final correct = find.byKey(
      const ValueKey('offline-checkpoint-option-together'),
    );
    expect(
      tester
          .getSemantics(correct)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isFalse,
    );
    final retry = find.byKey(const ValueKey('offline-checkpoint-retry'));
    expect(tester.widget<FilledButton>(retry).onPressed, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('offline-checkpoint-correction-input')),
      '重力だけでなく、動かしにくさも比べる。',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(retry).onPressed, isNotNull);
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('prediction-result-compare')),
      findsOneWidget,
    );
    expect(find.text('重力だけでなく、動かしにくさも比べる。'), findsOneWidget);
    expect(find.text('2つは同時に着く。'), findsWidgets);
    expect(
      find.byKey(const ValueKey('offline-checkpoint-option-light')),
      findsNothing,
      reason: '誤答後に残りの選択肢を総当たりさせない',
    );
    semantics.dispose();
  });

  testWidgets('比較後の組み直しでは結果を隠し、構造回答と根拠を更新して比較へ戻る', (tester) async {
    await tester.pumpWidget(_wrap());
    await tester.pump();
    await _enterAndContinue(
      tester,
      fieldKey: const ValueKey('offline-recall-input'),
      buttonKey: const ValueKey('offline-recall-next'),
      text: '条件をそろえる。',
    );
    await _selectChoiceTask(tester, itemId: 'heavy-first');
    await _enterAndContinue(
      tester,
      fieldKey: const ValueKey('offline-reasoning-input'),
      buttonKey: const ValueKey('offline-reasoning-next'),
      text: '重力が大きいと思った。',
    );
    await _chooseCheckpoint(tester, optionId: 'together');

    final rewrite = find.byKey(const ValueKey('prediction-result-rewrite'));
    await tester.ensureVisible(rewrite);
    await tester.tap(rewrite);
    await tester.pumpAndSettle();
    expect(find.textContaining('観察では'), findsNothing);
    final next = find.byKey(const ValueKey('offline-task-next'));
    expect(tester.widget<FilledButton>(next).onPressed, isNull);
    await _selectChoiceTask(tester, itemId: 'same-time');
    expect(_field(const ValueKey('offline-reasoning-input')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(_field(const ValueKey('offline-reasoning-input')))
          .controller
          ?.text,
      isEmpty,
    );
    await _enterAndContinue(
      tester,
      fieldKey: const ValueKey('offline-reasoning-input'),
      buttonKey: const ValueKey('offline-reasoning-next'),
      text: '空気抵抗がない条件では加速度が同じ。',
    );
    expect(
      find.byKey(const ValueKey('prediction-result-compare')),
      findsOneWidget,
    );
    expect(find.textContaining('2つは同時に着く'), findsWidgets);
  });

  testWidgets('自己比較後だけ引数なしcallbackを一度呼び、回答本文は渡さない', (tester) async {
    var saves = 0;
    await tester.pumpWidget(
      _wrap(onCheckpointCompleted: () async => saves += 1),
    );
    await _reachChoiceCheckpoint(tester);
    await _chooseCheckpoint(tester, optionId: 'together');
    expect(saves, 0, reason: 'checkpoint正答だけを完了として保存しない');
    await _completeComparison(tester, reflection: '保存しない振り返り本文');
    expect(saves, 1);
    expect(find.textContaining('カードの選択・分類・順序も保存せず'), findsOneWidget);
    expect(find.textContaining('教材と概念、完了回数、最終完了日時だけ'), findsOneWidget);
  });

  testWidgets('授業用referenceは完了時だけ表示し、理解・習得を断定しない', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(completionReference: '01-02-C', onCheckpointCompleted: () async {}),
    );
    await tester.pump();
    expect(find.textContaining('01-02-C'), findsNothing);
    await _reachChoiceCheckpoint(tester);
    await _chooseCheckpoint(tester, optionId: 'together');
    await _completeComparison(tester);

    final reference = find.byKey(
      const ValueKey('offline-completion-reference'),
    );
    expect(find.text('教材番号 01-02-C'), findsOneWidget);
    expect(
      tester.getSemantics(reference).getSemanticsData().label,
      '完了確認。教材番号01-02-C。この課題を最後まで見直しました',
    );
    expect(find.textContaining('習得しました'), findsNothing);
    expect(find.textContaining('理解しました'), findsNothing);
    expect(find.textContaining('教材番号・概念・A/B/C・完了状態・日時だけ'), findsOneWidget);
    expect(find.textContaining('回答内容と理解は記録・確認していません'), findsOneWidget);
    expect(find.textContaining('完了回数'), findsNothing);
    semantics.dispose();
  });

  testWidgets('dark 320x568・文字200%・キーボード表示でも分類・訂正・比較へ届く', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _wrap(
        textScale: 2,
        bottomInset: 260,
        brightness: Brightness.dark,
        practiceAttempt: 1,
      ),
    );
    await tester.pump();

    await _enterAndContinue(
      tester,
      fieldKey: const ValueKey('offline-recall-input'),
      buttonKey: const ValueKey('offline-recall-next'),
      text: '条件を分けて考える。',
    );
    await _completeClassifyTask(tester);
    await _enterAndContinue(
      tester,
      fieldKey: const ValueKey('offline-reasoning-input'),
      buttonKey: const ValueKey('offline-reasoning-next'),
      text: '質量だけを変える。',
    );
    await _chooseCheckpoint(tester, optionId: 'mass-only');
    final correction = find.byKey(
      const ValueKey('offline-checkpoint-correction-input'),
    );
    await tester.ensureVisible(correction);
    expect(tester.getSize(correction).height, greaterThanOrEqualTo(48));
    await tester.enterText(correction, '形と空気抵抗もそろえて比べる。');
    await tester.pump();
    final retry = find.byKey(const ValueKey('offline-checkpoint-retry'));
    await tester.ensureVisible(retry);
    expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
    await tester.tap(retry);
    await tester.pumpAndSettle();
    await _completeComparison(tester);
    final home = find.byKey(const ValueKey('offline-practice-home'));
    await tester.ensureVisible(home);
    expect(tester.getSize(home).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduce Motionでは誤答フィードバックへの移動を補間しない', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_wrap(textScale: 2, disableAnimations: true));
    await tester.pump();
    await _reachChoiceCheckpoint(tester);

    final wrong = find.byKey(const ValueKey('offline-checkpoint-option-heavy'));
    await tester.ensureVisible(wrong);
    await tester.tap(wrong);
    await tester.pump();
    final submit = find.byKey(const ValueKey('offline-checkpoint-submit'));
    await tester.ensureVisible(submit);
    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('offline-practice-scroll')),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable).position;
    await tester.tap(submit);
    await tester.pump();
    final revealedAt = position.pixels;
    await tester.pump(const Duration(milliseconds: 90));
    expect(
      find.byKey(const ValueKey('offline-checkpoint-hint')),
      findsOneWidget,
    );
    expect(position.pixels, revealedAt);
  });

  testWidgets('完了から中間routeを残さず最初のホームへ戻る', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        theme: buildAppTheme(Brightness.light),
        home: const Scaffold(body: Text('HOME ROOT')),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const OfflinePracticeScreen(
          section: _section,
          conceptLabel: '落下の速さ',
          missionKind: MissionKind.repair,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _reachChoiceCheckpoint(tester);
    await _chooseCheckpoint(tester, optionId: 'together');
    await _completeComparison(tester);
    final home = find.byKey(const ValueKey('offline-practice-home'));
    await tester.ensureVisible(home);
    await tester.tap(home);
    await tester.pumpAndSettle();
    expect(find.text('HOME ROOT'), findsOneWidget);
    expect(find.byType(OfflinePracticeScreen), findsNothing);
  });

  test('画面は保存・採点サービスへ接続せず、入力widgetへsolutionを渡さない', () {
    final source = File(
      'lib/screens/offline_practice_screen.dart',
    ).readAsStringSync();
    final widgetSource = File(
      'lib/widgets/cognitive_task_input.dart',
    ).readAsStringSync();
    for (final forbidden in [
      'SessionStore',
      'ConceptProgress',
      'missionSnapshotFor(',
      'saveProgress(',
      'MISSION CLEAR',
      'mastery',
      "package:dio",
      "package:http",
    ]) {
      expect(source.contains(forbidden), isFalse, reason: forbidden);
      expect(widgetSource.contains(forbidden), isFalse, reason: forbidden);
    }
    expect(
      source.contains('Future<void> Function()? onCheckpointCompleted'),
      isTrue,
    );
    expect(source.contains('prompt: taskPrompt'), isTrue);
    expect(
      widgetSource.contains('final LocalCognitiveTaskPrompt prompt;'),
      isTrue,
    );
    expect(
      widgetSource.contains('final LocalCognitiveTaskSolution solution;'),
      isFalse,
    );
    expect(widgetSource.contains('void save'), isFalse);
  });
}
