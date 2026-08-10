import 'dart:convert';

import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/models/review.dart';
import 'package:dekisugi/models/unit.dart';
import 'package:dekisugi/screens/material_screen.dart';
import 'package:dekisugi/screens/review_screen.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:dekisugi/services/units_client.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:flutter_test/flutter_test.dart';

LocalCheckpoint _checkpointFor(LocalPracticeStage stage) => LocalCheckpoint(
  lure: '固定思い込み。',
  options: [
    const LocalCheckpointOption(id: 'correct', text: '正答。'),
    LocalCheckpointOption(
      id: 'wrong-1',
      text: '誤答1。',
      hint: 'ヒント1。',
      needCode: 'science.fall.${stage.wire}',
    ),
    LocalCheckpointOption(
      id: 'wrong-2',
      text: '誤答2。',
      hint: 'ヒント2。',
      needCode: 'science.fall.${stage.wire}',
    ),
  ],
  correctOptionId: 'correct',
  explanation: '正答説明。',
);

LocalCognitiveTask _cognitiveTaskFor(LocalPracticeStage stage) =>
    LocalCognitiveTask(
      kind: LocalCognitiveTaskKind.singleSelect,
      operation: LocalCognitiveOperation.prediction,
      items: const [
        LocalCognitiveTaskItem(id: 'condition', text: '条件を確かめる。'),
        LocalCognitiveTaskItem(id: 'impression', text: '印象だけで決める。'),
      ],
      targets: const [],
      solution: const LocalSingleSelectSolution(selectedItemId: 'condition'),
      needCode: 'science.fall.${stage.wire}',
    );

LocalListeningNeedCodes _listeningNeedCodesFor(LocalPracticeStage stage) =>
    LocalListeningNeedCodes(
      transcript: 'science.fall.listening.${stage.wire}.transcript',
      meaning: 'science.fall.listening.${stage.wire}.meaning',
    );

final _checkpoint = _checkpointFor(LocalPracticeStage.foundation);

final _variants = [
  LocalPracticeVariant(
    stage: LocalPracticeStage.foundation,
    recallPrompt: '中心の考えを説明する。',
    reasoningPrompt: '理由を足す。',
    transferPrompt: '場面Aを予想する。',
    expectedOutcome: '結果A。',
    expectedReason: '理由A。',
    cognitiveTask: _cognitiveTaskFor(LocalPracticeStage.foundation),
    checkpoint: _checkpoint,
    listeningNeedCodes: _listeningNeedCodesFor(LocalPracticeStage.foundation),
  ),
  LocalPracticeVariant(
    stage: LocalPracticeStage.conditions,
    recallPrompt: '条件を説明する。',
    reasoningPrompt: '条件の理由を足す。',
    transferPrompt: '場面Bを予想する。',
    expectedOutcome: '結果B。',
    expectedReason: '理由B。',
    cognitiveTask: _cognitiveTaskFor(LocalPracticeStage.conditions),
    checkpoint: _checkpointFor(LocalPracticeStage.conditions),
    listeningNeedCodes: _listeningNeedCodesFor(LocalPracticeStage.conditions),
  ),
  LocalPracticeVariant(
    stage: LocalPracticeStage.transfer,
    recallPrompt: '別場面の考えを説明する。',
    reasoningPrompt: '別場面の理由を足す。',
    transferPrompt: '場面Cを予想する。',
    expectedOutcome: '結果C。',
    expectedReason: '理由C。',
    cognitiveTask: _cognitiveTaskFor(LocalPracticeStage.transfer),
    checkpoint: _checkpointFor(LocalPracticeStage.transfer),
    listeningNeedCodes: _listeningNeedCodesFor(LocalPracticeStage.transfer),
  ),
];

const _trace = LocalNotationTracePattern(
  semanticsLabel: '左から右へなぞる。',
  strokes: [
    LocalNotationTraceStroke(
      id: 'fixture.stroke',
      label: '確認線',
      points: [
        LocalNotationTracePoint(x: 0.1, y: 0.5),
        LocalNotationTracePoint(x: 0.5, y: 0.5),
        LocalNotationTracePoint(x: 0.9, y: 0.5),
      ],
    ),
  ],
  strokeOrderIds: ['fixture.stroke'],
);

const _notation = LocalNotationLab(
  orderTasks: [
    LocalNotationOrderTask(
      id: 'arrow',
      title: '矢印を組む',
      prompt: '力の矢印を順に組む。',
      traceGuide: '始点から矢先へ進む。',
      tracePattern: _trace,
      tokens: [
        LocalNotationToken(id: 'head', label: '矢先'),
        LocalNotationToken(id: 'start', label: '始点'),
      ],
      correctOrderIds: ['start', 'head'],
      solutionSummary: '矢印は始点から矢先へ組む。',
      needCode: 'science.fall.notation.arrow',
    ),
    LocalNotationOrderTask(
      id: 'equation',
      title: '式を組む',
      prompt: '速さの式を順に組む。',
      traceGuide: '求める量を左に置く。',
      tracePattern: _trace,
      tokens: [
        LocalNotationToken(id: 'time', label: '時間'),
        LocalNotationToken(id: 'speed', label: '速さ'),
        LocalNotationToken(id: 'distance', label: '距離'),
      ],
      correctOrderIds: ['speed', 'distance', 'time'],
      solutionSummary: '速さは距離を時間で割る。',
      needCode: 'science.fall.notation.equation',
    ),
  ],
  symbolMatch: LocalNotationSymbolTask(
    prompt: '速さの単位を選ぶ。',
    choices: [
      LocalNotationChoice(id: 'wrong', label: 'm'),
      LocalNotationChoice(id: 'right', label: 'm/s'),
    ],
    correctChoiceId: 'right',
    solutionSummary: '速さの単位はm/s。',
    needCode: 'science.fall.notation.symbol',
  ),
  graphRead: LocalNotationGraphTask(
    prompt: '距離―時間グラフの傾きを読む。',
    graphNotation: ['縦軸 距離', '横軸 時間 →'],
    graphSemanticsLabel: '縦軸が距離、横軸が時間のグラフ',
    choices: [
      LocalNotationChoice(id: 'wrong', label: '時間'),
      LocalNotationChoice(id: 'right', label: '速さ'),
    ],
    correctChoiceId: 'right',
    solutionSummary: '距離―時間グラフの傾きは速さ。',
    needCode: 'science.fall.notation.graph',
  ),
);

const _story = LocalScienceStory(
  id: 'fall.paper-race',
  title: '紙ひこうき部、落下レース中止事件',
  setting: '放課後の理科室。',
  foundationNeedCode: 'science.fall.foundation',
  characters: [
    LocalScienceStoryCharacter(id: 'mio', name: 'ミオ', role: '観察'),
    LocalScienceStoryCharacter(id: 'dekisugi', name: 'デキすぎ君', role: '仮説'),
    LocalScienceStoryCharacter(id: 'ren', name: 'レン', role: '記録'),
  ],
  openingLines: [
    LocalScienceStoryLine(id: 'open.1', speakerId: 'mio', text: '紙を比べよう。'),
    LocalScienceStoryLine(id: 'open.2', speakerId: 'ren', text: '条件を記録したよ。'),
    LocalScienceStoryLine(
      id: 'open.3',
      speakerId: 'dekisugi',
      text: 'ぼくの予想を聞いて。',
    ),
  ],
  choiceLine: LocalScienceStoryLine(
    id: 'choice',
    speakerId: 'dekisugi',
    text: '固定思い込み。',
  ),
  choiceResponses: [
    LocalScienceStoryChoiceResponse(
      optionId: 'correct',
      line: LocalScienceStoryLine(
        id: 'response.correct',
        speakerId: 'ren',
        text: '条件まで合っているね。',
      ),
    ),
    LocalScienceStoryChoiceResponse(
      optionId: 'wrong-1',
      line: LocalScienceStoryLine(
        id: 'response.wrong-1',
        speakerId: 'mio',
        text: '条件をもう一度見よう。',
      ),
    ),
    LocalScienceStoryChoiceResponse(
      optionId: 'wrong-2',
      line: LocalScienceStoryLine(
        id: 'response.wrong-2',
        speakerId: 'dekisugi',
        text: '理由も確かめよう。',
      ),
    ),
  ],
  resolutionLines: [
    LocalScienceStoryLine(id: 'resolve.1', speakerId: 'mio', text: '観察できたね。'),
    LocalScienceStoryLine(id: 'resolve.2', speakerId: 'ren', text: '理由も一致したよ。'),
  ],
  scientificResolution: LocalScienceStoryResolution(
    outcome: '結果A。',
    reason: '理由A。',
  ),
  punchline: LocalScienceStoryLine(
    id: 'punchline',
    speakerId: 'dekisugi',
    text: '次は真空でレースだ！',
  ),
);

void main() {
  late MemorySessionStore store;

  Widget wrap({double textScale = 1}) => MaterialApp(
    theme: buildAppTheme(Brightness.light),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: ReviewScreen(
      store: store,
      units: UnitsClient(baseUrl: '', store: store),
    ),
  );

  ReviewItem item() => ReviewItem(
    unitId: 'force-motion',
    conceptKey: 'fall',
    label: '落下の速さ',
    reason: ReviewReason.notCorrected,
    lastSeen: DateTime(2026, 1, 1),
  );

  setUp(() => store = MemorySessionStore());

  testWidgets('管理リストではなく、次に話すための前進として見せる', (tester) async {
    await store.upsertReviews([item()]);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('次に話すことを、\nひとつずつ整える。'), findsOneWidget);
    expect(find.text('いま整える話'), findsOneWidget);
    expect(find.text('落下の速さ'), findsOneWidget);
    expect(find.text('次に話す前に読む'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(find.byType(ListTile), findsNothing);
    for (final banned in ['ポイント', 'XP', 'レベル', 'ランキング', '弱点']) {
      expect(find.textContaining(banned), findsNothing);
    }
  });

  testWidgets('読むだけ・自己申告だけで学習済みにしない', (tester) async {
    await store.upsertReviews([item()]);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('この話はもう説明できる'), findsNothing);
    expect(find.text('落下の速さ'), findsOneWidget);
    expect(await store.reviewItems(), hasLength(1));
  });

  testWidgets('教材を連打しても読み直し画面を1枚しか開かない', (tester) async {
    final detail = UnitDetail(
      summary: const UnitSummary(
        id: 'force-motion',
        title: '力と運動',
        brief: 'ざっくりした紹介。',
        concepts: [
          UnitConcept(
            key: 'fall',
            label: '落下の速さ',
            storyTitle: '紙ひこうき部、落下レース中止事件',
          ),
        ],
        sectionCount: 1,
      ),
      sections: [
        Section(
          conceptKey: 'fall',
          title: '落下の速さ',
          body: ['空気抵抗の無いときの落下を考える。'],
          tryIt: '紙を落として確かめる。',
          localCheckpoint: _checkpoint,
          localSpeakingPractice: const LocalSpeakingPractice(
            targetPhrase: '真空中では重い球も軽い球も同じ加速度で落下する',
            acceptedTranscripts: [
              '真空中では重い球も軽い球も同じ加速度で落下する',
              '空気抵抗がなければ重い球も軽い球も同じ加速度で落下する',
            ],
          ),
          localPracticeVariants: _variants,
          notationLab: _notation,
          scienceStory: _story,
        ),
      ],
    );
    await store.setSetting(
      'units.v9.detail.force-motion',
      jsonEncode(detail.toJson()),
    );
    await store.upsertReviews([item()]);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    final button = find.widgetWithText(FilledButton, '次に話す前に読む');
    await tester.ensureVisible(button);
    final onPressed = tester.widget<FilledButton>(button).onPressed!;
    onPressed();
    onPressed();
    await tester.pumpAndSettle();

    expect(find.byType(MaterialScreen), findsOneWidget);
  });

  testWidgets('過ぎた考査日を「きょう」と表示しない', (tester) async {
    final past = DateTime.now().subtract(const Duration(days: 2));
    await store.setExamDate(past);
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('次の考査日を入れ直す'), findsOneWidget);
    expect(find.textContaining('前の考査日は'), findsOneWidget);
    expect(find.text('きょうが考査日'), findsNothing);
  });

  testWidgets('320dp・文字200%でも内容と操作を最後まで読める', (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await store.upsertReviews([item()]);
    await tester.pumpWidget(wrap(textScale: 2));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('次に話す前に読む'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
