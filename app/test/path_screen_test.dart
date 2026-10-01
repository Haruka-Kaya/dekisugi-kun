import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/motion.dart';
import 'package:dekisugi/learning/domain/learning_economy.dart';
import 'package:dekisugi/models/game_path.dart';
import 'package:dekisugi/screens/path_screen.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:flutter_test/flutter_test.dart';

const _status = GamePlayerStatus(
  streakDays: 14,
  streakFreezeRemaining: 2,
  gems: 1280,
  hearts: 4,
);

const _nodes = <GamePathNode>[
  GamePathNode(
    id: 'completed',
    title: '落ちる前に予想する',
    description: '重さが違う2つを同時に落とした結果を予想します。',
    kind: GamePathNodeKind.lesson,
    state: GamePathNodeState.completed,
    completedLessons: 1,
    learningActions: ['結果を先に予想する', '教材と見比べる'],
  ),
  GamePathNode(
    id: 'available',
    title: '空気の影響を見分ける',
    description: '落下の条件を分類し、違いが生まれる理由を考えます。',
    kind: GamePathNodeKind.lesson,
    state: GamePathNodeState.available,
    estimatedMinutes: 4,
    learningActions: ['条件を2つに分類する', '分類した理由を自分の言葉で足す'],
    rewardLabel: '+10 XP',
  ),
  GamePathNode(
    id: 'in-progress',
    title: '実験の順番を組む',
    description: '確かめたい条件を一つだけ変える実験を組みます。',
    kind: GamePathNodeKind.challenge,
    state: GamePathNodeState.inProgress,
    completedLessons: 1,
    totalLessons: 3,
  ),
  GamePathNode(
    id: 'review',
    title: '別の場面でたしかめる',
    description: '前に扱った考え方を、新しい場面へ使います。',
    kind: GamePathNodeKind.practice,
    state: GamePathNodeState.reviewDue,
  ),
  GamePathNode(
    id: 'story',
    title: '消えた落下記録',
    description: 'デキすぎ君の実験ノートを読み、途中で予想します。',
    kind: GamePathNodeKind.story,
    state: GamePathNodeState.locked,
  ),
  GamePathNode(
    id: 'legendary',
    title: '落下の博士チャレンジ',
    description: 'ヒントなしで未知の場面に考え方を使います。',
    kind: GamePathNodeKind.legendary,
    state: GamePathNodeState.legendaryAvailable,
  ),
  GamePathNode(
    id: 'legendary-complete',
    title: '実験計画の博士チャレンジ',
    description: '条件をそろえた実験計画を完成させます。',
    kind: GamePathNodeKind.legendary,
    state: GamePathNodeState.legendaryCompleted,
  ),
];

const _unit = GamePathUnit(
  id: 'force-motion',
  ordinal: 1,
  title: '力と運動',
  objective: '落ち方の違いを、重さではなく条件から説明する',
  nodes: _nodes,
  completedSteps: 2,
  totalSteps: 7,
  guidebookTitle: '力と運動のガイド',
  characterReaction: GameCharacterReaction.encourage,
  characterMessage: 'まず予想してから、条件を一つずつ見よう。',
);

const _quests = <GameQuest>[
  GameQuest(
    id: 'daily-compare',
    title: '予想と結果を1回比べる',
    description: '答えを見る前の予想を残し、教材の結果と見比べます。',
    kind: GameQuestKind.daily,
    state: GameQuestState.active,
    current: 0,
    target: 1,
    rewardLabel: '結晶 5個',
  ),
];

const _data = GamePathViewData(
  status: _status,
  units: [_unit],
  currentNodeId: 'available',
  quests: _quests,
);

Future<void> _pumpPath(
  WidgetTester tester, {
  double textScale = 1,
  GamePathViewData data = _data,
  void Function(GamePathNode node)? onNodeStart,
  LearningPathMascotStyle mascotStyle = LearningPathMascotStyle.standard,
}) => tester.pumpWidget(
  MaterialApp(
    theme: buildAppTheme(Brightness.light),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: ReduceMotionScope(
      child: PathScreen(
        data: data,
        onNodeStart: onNodeStart,
        mascotStyle: mascotStyle,
      ),
    ),
  ),
);

void main() {
  testWidgets('購入したPathマスコットstyleを形とSemanticsの両方へ反映する', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpPath(tester, mascotStyle: LearningPathMascotStyle.orbit);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('path-mascot-orbit')), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'軌道リングのデキすぎ君。まず予想してから')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('Pathの全状態を形と文言を含むSemanticsで返す', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpPath(tester);
      await tester.pumpAndSettle();

      expect(
        find.bySemanticsLabel(RegExp(r'理科レッスン「落ちる前に予想する」。完了。もう一度取り組めます')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'理科レッスン「空気の影響を見分ける」。現在位置。次に進めます')),
        findsOneWidget,
      );
      expect(find.text('次はここ'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('game-path-current-ring-available')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'章ボス「実験の順番を組む」。3回中1回完了')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'復習「別の場面でたしかめる」。復習する時期です')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'理科ストーリー「消えた落下記録」。未解放。前のレッスンを終えると開きます')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'高難度チャレンジ「落下の博士チャレンジ」。高難度課題に挑戦できます')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp(r'高難度チャレンジ「実験計画の博士チャレンジ」。高難度課題を完了')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('連続学習、14日。連続記録の保護、2回分'), findsOneWidget);
      expect(find.bySemanticsLabel('ひらめき結晶、1280個'), findsOneWidget);
      expect(find.bySemanticsLabel('学習ハート、5個中4個'), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('iOSのReduce Motionではノード押下transformを補間しない', (tester) async {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(binding.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await _pumpPath(tester);
    await tester.pump();

    final node = find.byKey(const ValueKey('game-path-node-available'));
    await tester.scrollUntilVisible(
      node,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    final animated = tester.widget<AnimatedContainer>(
      find.descendant(of: node, matching: find.byType(AnimatedContainer)),
    );
    expect(animated.duration, Duration.zero);
  });

  testWidgets('深い進捗から再起動しても現在の「次はここ」を自動で見える位置へ出す', (tester) async {
    final units = List.generate(4, (unitIndex) {
      final nodes = List.generate(6, (nodeIndex) {
        final current = unitIndex == 3 && nodeIndex == 5;
        return GamePathNode(
          id: 'unit-$unitIndex-node-$nodeIndex',
          title: current ? '次に進む実験' : '完了した実験',
          description: '条件を一つずつ確かめます。',
          kind: GamePathNodeKind.lesson,
          state: current
              ? GamePathNodeState.available
              : GamePathNodeState.completed,
        );
      });
      return GamePathUnit(
        id: 'unit-$unitIndex',
        ordinal: unitIndex + 1,
        title: '単元 ${unitIndex + 1}',
        objective: '条件を分けて説明する',
        nodes: nodes,
        completedSteps: unitIndex == 3 ? 5 : 6,
        totalSteps: 6,
      );
    });
    final data = GamePathViewData(
      status: _status,
      units: units,
      currentNodeId: 'unit-3-node-5',
      quests: _quests,
    );

    await _pumpPath(tester, data: data);
    await tester.pumpAndSettle();

    final current = find.byKey(const ValueKey('game-path-node-unit-3-node-5'));
    expect(current.hitTestable(), findsOneWidget);
    expect(find.text('次はここ'), findsOneWidget);
    expect(
      tester.getCenter(current).dy,
      inInclusiveRange(100, tester.view.physicalSize.height - 90),
    );
  });

  testWidgets('ノード詳細sheetは学習行為を示し主CTAでDTOを返す', (tester) async {
    GamePathNode? started;
    await _pumpPath(tester, onNodeStart: (node) => started = node);
    await tester.pumpAndSettle();

    final available = find.byKey(const ValueKey('game-path-node-available'));
    await tester.scrollUntilVisible(
      available,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(available);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('game-node-sheet')), findsOneWidget);
    expect(find.text('空気の影響を見分ける'), findsWidgets);
    expect(find.text('条件を2つに分類する'), findsOneWidget);
    expect(find.text('分類した理由を自分の言葉で足す'), findsOneWidget);
    expect(find.text('完了時 +10 XP'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('game-node-sheet-start')));
    await tester.pumpAndSettle();

    expect(started?.id, 'available');
    expect(find.byKey(const ValueKey('game-node-sheet')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320dp・文字200%でPathとnode/quest sheetが横に溢れない', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pumpPath(tester, textScale: 2, onNodeStart: (_) {});
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const ValueKey('player-status-bar'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('game-path-node-available')))
          .width,
      greaterThanOrEqualTo(72),
    );

    final available = find.byKey(const ValueKey('game-path-node-available'));
    await tester.scrollUntilVisible(
      available,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(available);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game-node-sheet')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('game-node-sheet-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-quest-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game-quest-sheet')), findsOneWidget);
    expect(find.text('予想と結果を1回比べる'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('学校達成は受取表現を出さず、personalの報酬copyは維持する', (tester) async {
    const completedQuest = GameQuest(
      id: 'completed-quest',
      title: '今日の学習を1件終える',
      description: 'この端末で取り組む授業目標です。',
      kind: GameQuestKind.classroom,
      state: GameQuestState.completed,
      current: 1,
      target: 1,
      rewardLabel: '結晶 5個',
    );
    const schoolData = GamePathViewData(
      status: _status,
      units: [_unit],
      quests: [completedQuest],
      schoolMode: true,
    );
    await _pumpPath(tester, data: schoolData);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-quest-button')));
    await tester.pumpAndSettle();

    expect(find.text('この端末で達成済み'), findsOneWidget);
    expect(find.textContaining('報酬を受け取れます'), findsNothing);
    expect(find.text('結晶 5個'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('授業クエスト.*この端末で達成済み')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('game-quest-sheet-close')));
    await tester.pumpAndSettle();
    const personalQuest = GameQuest(
      id: 'completed-personal',
      title: '今日の学習を1件終える',
      description: '学習パスの目標です。',
      kind: GameQuestKind.daily,
      state: GameQuestState.completed,
      current: 1,
      target: 1,
      rewardLabel: '結晶 5個',
    );
    const personalData = GamePathViewData(
      status: _status,
      units: [_unit],
      quests: [personalQuest],
    );
    await _pumpPath(tester, data: personalData);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-quest-button')));
    await tester.pumpAndSettle();

    expect(find.text('達成。報酬を受け取れます'), findsOneWidget);
    expect(find.text('結晶 5個'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('デイリークエスト.*報酬を受け取れます')),
      findsOneWidget,
    );
  });
}
