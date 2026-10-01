import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/game_tokens.dart';
import 'package:dekisugi/config/motion.dart';
import 'package:dekisugi/learning/domain/learning_need.dart';
import 'package:dekisugi/models/unit.dart';
import 'package:dekisugi/screens/science_story_screen.dart';
import 'package:dekisugi/services/local_narration.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:flutter_test/flutter_test.dart';

const _foundationCheckpoint = LocalCheckpoint(
  lure: '空気のない場所でも、重い球のほうが先に着く。',
  options: [
    LocalCheckpointOption(
      id: 'heavy-first',
      text: '重い球が先に着く。',
      hint: '重力だけでなく、動かしにくさも一緒に比べます。',
      needCode: 'science.fall.foundation',
    ),
    LocalCheckpointOption(id: 'same-time', text: '2つは同時に着く。'),
    LocalCheckpointOption(
      id: 'light-first',
      text: '軽い球が先に着く。',
      hint: '軽いことだけでは、落下加速度の差は決まりません。',
      needCode: 'science.fall.foundation',
    ),
  ],
  correctOptionId: 'same-time',
  explanation: '空気抵抗を無視すれば、落下加速度は重さによらないためです。',
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
      id: 'same-air-force',
      text: '空気はどの物体も同じ大きさで押す。',
      hint: '空気抵抗は形や面積でも変わります。',
      needCode: 'science.fall.conditions',
    ),
    LocalCheckpointOption(id: 'control-air', text: '形や空気抵抗の影響を分けて比べる。'),
  ],
  correctOptionId: 'control-air',
  explanation: '質量以外の条件をそろえないと、質量だけの効果とはいえません。',
);

const _transferCheckpoint = LocalCheckpoint(
  lure: '真空中でも、形が違えば落下加速度は違う。',
  options: [
    LocalCheckpointOption(
      id: 'shape-matters',
      text: '真空でも形によって空気抵抗が変わる。',
      hint: '真空という条件で、空気抵抗が残るかを確かめます。',
      needCode: 'science.fall.transfer',
    ),
    LocalCheckpointOption(
      id: 'gravity-up',
      text: '薄い板には上向きの重力がはたらく。',
      hint: '重力の向きが形で変わるかを見直します。',
      needCode: 'science.fall.transfer',
    ),
    LocalCheckpointOption(id: 'vacuum-same', text: '真空なら形や重さによらず落下加速度は同じ。'),
  ],
  correctOptionId: 'vacuum-same',
  explanation: '真空中では空気抵抗がなく、重力による加速度は形や重さによりません。',
);

const _task = LocalCognitiveTask(
  kind: LocalCognitiveTaskKind.singleSelect,
  operation: LocalCognitiveOperation.prediction,
  items: [
    LocalCognitiveTaskItem(id: 'first-a', text: 'Aが先'),
    LocalCognitiveTaskItem(id: 'together-a', text: '同時'),
  ],
  targets: [],
  solution: LocalSingleSelectSolution(selectedItemId: 'together-a'),
);

const _story = LocalScienceStory(
  id: 'fall.paper-race',
  title: '紙ひこうき部、落下レース中止事件',
  setting: '放課後の理科室。平らな紙と丸めた紙を同時に落とす。',
  foundationNeedCode: 'science.fall.foundation',
  characters: [
    LocalScienceStoryCharacter(id: 'mio', name: 'ミオ', role: '観察'),
    LocalScienceStoryCharacter(id: 'dekisugi', name: 'デキすぎ君', role: '仮説'),
    LocalScienceStoryCharacter(id: 'ren', name: 'レン', role: '記録'),
  ],
  openingLines: [
    LocalScienceStoryLine(
      id: 'fall.open.1',
      speakerId: 'mio',
      text: '同じ紙なのに、丸めたほうが先に床へ着いたよ。',
    ),
    LocalScienceStoryLine(
      id: 'fall.open.2',
      speakerId: 'ren',
      text: '重さは同じ。変えたのは形だけだね。',
    ),
    LocalScienceStoryLine(
      id: 'fall.open.3',
      speakerId: 'dekisugi',
      text: '落下レースは重い選手が有利に決まってる！',
    ),
  ],
  choiceLine: LocalScienceStoryLine(
    id: 'fall.choice',
    speakerId: 'dekisugi',
    text: '空気のない場所でも、重い球のほうが先に着く。',
  ),
  choiceResponses: [
    LocalScienceStoryChoiceResponse(
      optionId: 'heavy-first',
      line: LocalScienceStoryLine(
        id: 'fall.response.heavy',
        speakerId: 'mio',
        text: '同じ重さの紙で差が出た理由が残るね。',
      ),
    ),
    LocalScienceStoryChoiceResponse(
      optionId: 'same-time',
      line: LocalScienceStoryLine(
        id: 'fall.response.same',
        speakerId: 'ren',
        text: '真空という条件まで入っているね。',
      ),
    ),
    LocalScienceStoryChoiceResponse(
      optionId: 'light-first',
      line: LocalScienceStoryLine(
        id: 'fall.response.light',
        speakerId: 'dekisugi',
        text: '軽さ選手権に変更？　でも紙は同じ重さだ！',
      ),
    ),
  ],
  resolutionLines: [
    LocalScienceStoryLine(
      id: 'fall.resolve.1',
      speakerId: 'mio',
      text: '平らな紙は空気を広く受けたんだ。',
    ),
    LocalScienceStoryLine(
      id: 'fall.resolve.2',
      speakerId: 'ren',
      text: '空気を無視できるなら重さだけで到着順は変わらない。',
    ),
  ],
  scientificResolution: LocalScienceStoryResolution(
    outcome: '丸めた紙が先に着き、平らな紙は遅れて着きます。',
    reason: '平らな紙は空気抵抗の影響を大きく受けるためです。',
  ),
  punchline: LocalScienceStoryLine(
    id: 'fall.punchline',
    speakerId: 'dekisugi',
    text: '次は真空で……え、理科室ごと吸っちゃだめ？',
  ),
);

const _section = Section(
  conceptKey: 'fall',
  title: '落下の速さ',
  body: ['空気抵抗を無視すれば、落下加速度は重さによりません。'],
  tryIt: '紙を落として比べる。',
  localCheckpoint: _foundationCheckpoint,
  localPracticeVariants: [
    LocalPracticeVariant(
      stage: LocalPracticeStage.foundation,
      recallPrompt: '落下の原理を説明する。',
      reasoningPrompt: '理由を説明する。',
      transferPrompt: '平らな紙と丸めた紙を空気中で同時に放すと、どうなる？',
      expectedOutcome: '丸めた紙が先に着き、平らな紙は遅れて着きます。',
      expectedReason: '平らな紙は空気抵抗の影響を大きく受けるためです。',
      cognitiveTask: _task,
      checkpoint: _foundationCheckpoint,
    ),
    LocalPracticeVariant(
      stage: LocalPracticeStage.conditions,
      recallPrompt: '比較条件を説明する。',
      reasoningPrompt: '条件の理由を説明する。',
      transferPrompt: '管の空気を減らすと羽根と球の着地時刻の差はどうなる？',
      expectedOutcome: '空気を減らすほど、羽根と球の着地時刻の差は小さくなります。',
      expectedReason: '羽根を遅らせていた空気抵抗が小さくなるためです。',
      cognitiveTask: _task,
      checkpoint: _conditionsCheckpoint,
    ),
    LocalPracticeVariant(
      stage: LocalPracticeStage.transfer,
      recallPrompt: '真空条件を説明する。',
      reasoningPrompt: '公平な比較を説明する。',
      transferPrompt: '真空中で重さだけが違う2球を同時に放すと、どうなる？',
      expectedOutcome: '2個の球は同時に底へ着きます。',
      expectedReason: '真空中の落下加速度は重さによらないためです。',
      cognitiveTask: _task,
      checkpoint: _transferCheckpoint,
    ),
  ],
  scienceStory: _story,
);

Widget _wrap({
  int practiceAttempt = 0,
  VoidCallback? onCompleted,
  VoidCallback? onReturnToPath,
  double textScale = 1,
  bool disableAnimations = false,
  Brightness brightness = Brightness.light,
  LocalNarration? narration,
  LearningNeedEvidenceReported? onNeedEvidence,
}) => MaterialApp(
  theme: buildAppTheme(brightness),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: disableAnimations,
    ),
    child: ReduceMotionScope(child: child!),
  ),
  home: ScienceStoryScreen(
    section: _section,
    conceptLabel: '落下の速さ',
    practiceAttempt: practiceAttempt,
    onCompleted: onCompleted ?? () {},
    onReturnToPath: onReturnToPath,
    narration: narration,
    onNeedEvidence: onNeedEvidence,
  ),
);

Finder get _storyScrollable => find.byType(Scrollable).first;

Future<void> _scrollToAndTap(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 160, scrollable: _storyScrollable);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
}

Future<void> _openJudgment(WidgetTester tester) async {
  await _scrollToAndTap(
    tester,
    find.byKey(const ValueKey('science-story-open-judgment')),
  );
}

Future<void> _chooseAndSubmit(WidgetTester tester, String optionId) async {
  await _scrollToAndTap(
    tester,
    find.byKey(ValueKey('science-story-option-$optionId')),
  );
  await _scrollToAndTap(
    tester,
    find.byKey(const ValueKey('science-story-submit-judgment')),
  );
}

Future<void> _openComparison(WidgetTester tester) => _scrollToAndTap(
  tester,
  find.byKey(const ValueKey('science-story-reaction-to-comparison')),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('practiceAttemptに依存せずSection固有Storyとfoundationだけを固定3幕へ使う', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(practiceAttempt: 1));

    expect(find.text(_story.title), findsWidgets);
    expect(find.text('理科事件  /  第1幕・全3幕'), findsOneWidget);
    expect(find.textContaining('SCIENCE STORY'), findsNothing);
    expect(find.text(_story.setting), findsOneWidget);
    expect(
      find.text(_section.localPracticeVariants[1].transferPrompt),
      findsNothing,
    );
    expect(
      find.text(_section.localPracticeVariants[0].transferPrompt),
      findsNothing,
    );
    expect(
      find.text(_section.localPracticeVariants[2].transferPrompt),
      findsNothing,
    );

    await _openJudgment(tester);
    expect(find.textContaining(_conditionsCheckpoint.lure), findsNothing);
    expect(find.textContaining(_foundationCheckpoint.lure), findsOneWidget);
    expect(find.textContaining(_transferCheckpoint.lure), findsNothing);
  });

  testWidgets('各幕で可視な固定文だけを端末読み上げへ渡し、正答を先出ししない', (tester) async {
    final narration = FakeLocalNarration();
    await tester.pumpWidget(_wrap(narration: narration));

    await _scrollToAndTap(
      tester,
      find.byKey(const ValueKey('science-story-listen-situation')),
    );
    expect(
      narration.spoken.single,
      _story.openingLines.map((line) => line.text).join(' '),
    );
    expect(
      narration.spoken.single,
      isNot(contains(_foundationCheckpoint.explanation)),
    );

    await _openJudgment(tester);
    await _scrollToAndTap(
      tester,
      find.byKey(const ValueKey('science-story-listen-judgment')),
    );
    expect(narration.spoken.last, _foundationCheckpoint.lure);
    expect(narration.spoken.last, isNot(contains('2つは同時に着く')));

    await _chooseAndSubmit(tester, 'same-time');
    await _scrollToAndTap(
      tester,
      find.byKey(const ValueKey('science-story-listen-reaction')),
    );
    expect(narration.spoken.last, _story.responseFor('same-time').line.text);
    await _openComparison(tester);
    await _scrollToAndTap(
      tester,
      find.byKey(const ValueKey('science-story-listen-comparison')),
    );
    expect(
      narration.spoken.last,
      [
        ..._story.resolutionLines,
        _story.punchline,
      ].map((line) => line.text).join(' '),
    );
    expect(
      narration.spoken.last,
      isNot(contains(_foundationCheckpoint.explanation)),
      reason: '可視でも会話ではない解説カードをTTSへ混ぜない',
    );
    expect(narration.stopCount, greaterThanOrEqualTo(3));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(narration.disposed, isTrue);
    expect(narration.stopCount, greaterThanOrEqualTo(4));
  });

  testWidgets('system backで読み上げを停止してStoryを破棄する', (tester) async {
    final narration = FakeLocalNarration();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Builder(
          builder: (context) => FilledButton(
            key: const ValueKey('open-story-route'),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => ReduceMotionScope(
                  child: ScienceStoryScreen(
                    section: _section,
                    conceptLabel: '落下の速さ',
                    practiceAttempt: 0,
                    narration: narration,
                    onCompleted: () {},
                  ),
                ),
              ),
            ),
            child: const Text('Storyを開く'),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-story-route')));
    await tester.pumpAndSettle();
    await _scrollToAndTap(
      tester,
      find.byKey(const ValueKey('science-story-listen-situation')),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(narration.disposed, isTrue);
    expect(narration.stopCount, greaterThanOrEqualTo(1));
    expect(find.byKey(const ValueKey('science-story-situation')), findsNothing);
  });

  testWidgets('backgroundへ移ると可視でなくなった会話の読み上げを停止する', (tester) async {
    final narration = FakeLocalNarration();
    await tester.pumpWidget(_wrap(narration: narration));
    await _scrollToAndTap(
      tester,
      find.byKey(const ValueKey('science-story-listen-situation')),
    );

    final stopsBeforeBackground = narration.stopCount;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(narration.stopCount, greaterThan(stopsBeforeBackground));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('送信前は観察・理由・訂正解説をwidget treeとSemanticsへ出さない', (tester) async {
    final semantics = tester.ensureSemantics();
    final variant = _section.localPracticeVariants.first;
    await tester.pumpWidget(_wrap());

    expect(find.text(variant.expectedOutcome), findsNothing);
    expect(find.text(variant.expectedReason), findsNothing);
    expect(find.text(_foundationCheckpoint.explanation), findsNothing);

    await _openJudgment(tester);
    expect(find.text(_foundationCheckpoint.explanation), findsNothing);
    expect(find.bySemanticsLabel(RegExp('思い込みの直し方')), findsNothing);

    await _chooseAndSubmit(tester, 'same-time');
    expect(
      find.byKey(const ValueKey('science-story-reaction')),
      findsOneWidget,
    );
    expect(find.text(variant.expectedOutcome), findsNothing);
    expect(find.text(variant.expectedReason), findsNothing);
    await _openComparison(tester);
    expect(
      find.byKey(const ValueKey('science-story-comparison')),
      findsOneWidget,
    );
    expect(find.text(variant.expectedOutcome), findsOneWidget);
    expect(find.text(variant.expectedReason), findsOneWidget);
    expect(find.text(_foundationCheckpoint.explanation), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('思い込みの直し方.*2つは同時に着く')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('誤答は人物反応とhint確認後に比較へ合流し、残りを総当たりできない', (tester) async {
    final needs = <LearningNeedEvidence>[];
    await tester.pumpWidget(_wrap(onNeedEvidence: needs.add));
    await _openJudgment(tester);
    await _chooseAndSubmit(tester, 'heavy-first');

    expect(needs, hasLength(1));
    expect(needs.single.conceptKey, 'fall');
    expect(needs.single.needCode, 'science.fall.foundation');
    expect(needs.single.kind, LearningNeedEvidenceKind.observed);

    expect(
      find.byKey(const ValueKey('science-story-reaction')),
      findsOneWidget,
    );
    expect(
      find.textContaining(_story.responseFor('heavy-first').line.text),
      findsOneWidget,
    );
    expect(find.text('重力だけでなく、動かしにくさも一緒に比べます。'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('science-story-option-same-time')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('science-story-option-light-first')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('science-story-submit-judgment')),
      findsNothing,
    );
    expect(find.text(_foundationCheckpoint.explanation), findsNothing);

    await _openComparison(tester);
    expect(
      find.byKey(const ValueKey('science-story-comparison')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('science-story-option-same-time')),
      findsNothing,
    );
    expect(find.text(_foundationCheckpoint.explanation), findsOneWidget);
    expect(find.text('最初の判断：重い球が先に着く。'), findsOneWidget);
  });

  testWidgets('正答・各誤答の全分岐が有限に完了しcallbackは一度だけ', (tester) async {
    for (final option in _foundationCheckpoint.options) {
      var completed = 0;
      await tester.pumpWidget(
        KeyedSubtree(
          key: ValueKey('branch-${option.id}'),
          child: _wrap(onCompleted: () => completed++),
        ),
      );
      await tester.pump();
      await _openJudgment(tester);
      await _chooseAndSubmit(tester, option.id);
      expect(
        find.textContaining(_story.responseFor(option.id).line.text),
        findsOneWidget,
        reason: '${option.id}: 正答を含む全3選択に人物反応が必要',
      );
      await _openComparison(tester);

      final finish = find.byKey(const ValueKey('science-story-complete'));
      await tester.scrollUntilVisible(
        finish,
        160,
        scrollable: _storyScrollable,
      );
      await tester.pump();
      await tester.tap(finish);
      await tester.tap(finish, warnIfMissed: false);
      await tester.pump();

      expect(completed, 1, reason: option.id);
      expect(
        find.byKey(const ValueKey('science-story-finished')),
        findsOneWidget,
      );
      expect(find.textContaining('習得'), findsNothing);
      expect(find.textContaining('理解した'), findsNothing);
    }
  });

  testWidgets('完了通知と学習パスへの明示帰還を分離し、完了面を先に見せる', (tester) async {
    var completed = 0;
    var returned = 0;
    await tester.pumpWidget(
      _wrap(onCompleted: () => completed++, onReturnToPath: () => returned++),
    );
    await _openJudgment(tester);
    await _chooseAndSubmit(tester, 'same-time');
    await _openComparison(tester);
    await _scrollToAndTap(
      tester,
      find.byKey(const ValueKey('science-story-complete')),
    );

    expect(completed, 1);
    expect(returned, 0);
    expect(
      find.byKey(const ValueKey('science-story-finished')),
      findsOneWidget,
    );
    final returnButton = find.byKey(
      const ValueKey('science-story-return-to-path'),
    );
    await tester.scrollUntilVisible(
      returnButton,
      160,
      scrollable: _storyScrollable,
    );
    expect(tester.getSize(returnButton).height, greaterThanOrEqualTo(48));
    await tester.tap(returnButton);
    await tester.pump();

    expect(completed, 1);
    expect(returned, 1);
  });

  testWidgets('320x568・文字200%・Reduce Motionでも3幕を操作でき、操作面は48dp以上', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    var completed = 0;

    await tester.pumpWidget(
      _wrap(
        textScale: 2,
        disableAnimations: true,
        onCompleted: () => completed++,
      ),
    );

    final open = find.byKey(const ValueKey('science-story-open-judgment'));
    await tester.scrollUntilVisible(open, 160, scrollable: _storyScrollable);
    expect(tester.getSize(open).height, greaterThanOrEqualTo(48));
    await tester.tap(open);
    await tester.pumpAndSettle();

    final wrong = find.byKey(
      const ValueKey('science-story-option-heavy-first'),
    );
    await tester.scrollUntilVisible(wrong, 160, scrollable: _storyScrollable);
    expect(tester.getSize(wrong).height, greaterThanOrEqualTo(48));
    await tester.tap(wrong);
    await tester.pump();

    final submit = find.byKey(const ValueKey('science-story-submit-judgment'));
    await tester.scrollUntilVisible(submit, 160, scrollable: _storyScrollable);
    expect(tester.getSize(submit).height, greaterThanOrEqualTo(48));
    await tester.tap(submit);
    await tester.pumpAndSettle();

    final compare = find.byKey(
      const ValueKey('science-story-reaction-to-comparison'),
    );
    await tester.scrollUntilVisible(compare, 160, scrollable: _storyScrollable);
    expect(tester.getSize(compare).height, greaterThanOrEqualTo(48));
    await tester.tap(compare);
    await tester.pumpAndSettle();

    final finish = find.byKey(const ValueKey('science-story-complete'));
    await tester.scrollUntilVisible(finish, 160, scrollable: _storyScrollable);
    expect(tester.getSize(finish).height, greaterThanOrEqualTo(48));
    await tester.tap(finish);
    await tester.pumpAndSettle();

    expect(completed, 1);
    expect(
      find.byKey(const ValueKey('science-story-finished')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('1024dp・darkでもStoryは単一GamePaletteと招待reactionを保つ', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(_wrap(brightness: Brightness.dark));

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, GamePalette.dark.canvas);
    expect(find.bySemanticsLabel(RegExp('理科事件.*デキすぎ君.*手招き')), findsOneWidget);
    final open = find.byKey(const ValueKey('science-story-open-judgment'));
    expect(tester.getSize(open).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
