import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/game_tokens.dart';
import 'package:dekisugi/config/motion.dart';
import 'package:dekisugi/learning/domain/learning_economy.dart';
import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/learning/domain/learning_progress.dart';
import 'package:dekisugi/learning/services/game_content_projection.dart';
import 'package:dekisugi/learning/services/local_weekly_league_projection.dart';
import 'package:dekisugi/models/game_hub.dart';
import 'package:dekisugi/models/game_path.dart';
import 'package:dekisugi/models/league_ladder.dart';
import 'package:dekisugi/screens/game_profile_screen.dart';
import 'package:dekisugi/screens/league_screen.dart';
import 'package:dekisugi/screens/notation_lab_hub_screen.dart';
import 'package:dekisugi/screens/path_screen.dart';
import 'package:dekisugi/screens/practice_hub_screen.dart';
import 'package:dekisugi/screens/science_match_lab_screen.dart';
import 'package:dekisugi/screens/stories_screen.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/game_activity_scaffold.dart';
import 'package:dekisugi/widgets/game_completion_celebration.dart';
import 'package:dekisugi/widgets/game_shell.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/raster_stable_golden.dart';
import 'support/science_challenge_fixture.dart';

const _phone = Size(390, 844);
const _wide = Size(1024, 768);

const _status = GamePlayerStatus(
  streakDays: 14,
  streakFreezeRemaining: 2,
  gems: 1280,
  hearts: 4,
);

const _pathNodes = <GamePathNode>[
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
    rewardLabel: '+10 探究記録',
  ),
  GamePathNode(
    id: 'challenge',
    title: '実験の順番を組む',
    description: '確かめたい条件を一つだけ変える実験を組みます。',
    kind: GamePathNodeKind.challenge,
    state: GamePathNodeState.inProgress,
    completedLessons: 1,
    totalLessons: 3,
  ),
  GamePathNode(
    id: 'practice',
    title: '別の場面でたしかめる',
    description: '前に扱った考え方を、新しい場面へ使います。',
    kind: GamePathNodeKind.practice,
    state: GamePathNodeState.reviewDue,
  ),
  GamePathNode(
    id: 'listening',
    title: '観察の説明を聞く',
    description: '条件を表す言葉を聞き分けます。',
    kind: GamePathNodeKind.listening,
    state: GamePathNodeState.available,
  ),
  GamePathNode(
    id: 'speaking',
    title: '結果を教え返す',
    description: '観察した違いを自分の言葉で説明します。',
    kind: GamePathNodeKind.speaking,
    state: GamePathNodeState.available,
  ),
  GamePathNode(
    id: 'case-file',
    title: '消えた落下記録',
    description: 'デキすぎ君の実験ノートを読み、途中で予想します。',
    kind: GamePathNodeKind.story,
    state: GamePathNodeState.locked,
  ),
];

const _pathUnit = GamePathUnit(
  id: 'force-motion',
  ordinal: 1,
  title: '力と運動',
  objective: '落ち方の違いを、重さではなく条件から説明する',
  nodes: _pathNodes,
  completedSteps: 2,
  totalSteps: 7,
  guidebookTitle: '力と運動の観察ガイド',
  characterReaction: GameCharacterReaction.encourage,
  characterMessage: 'まず予想してから、条件を一つずつ見よう。',
);

const _gameQuests = <GameQuest>[
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

const _pathData = GamePathViewData(
  status: _status,
  units: [_pathUnit],
  currentNodeId: 'available',
  quests: _gameQuests,
);

const _episodes = <StoryEpisodeView>[
  StoryEpisodeView(
    id: 'available',
    title: '浮く力の謎',
    conceptLabel: '浮力',
    chapterLabel: 'CASE 01',
    state: GameContentState.available,
    minutes: 3,
  ),
  StoryEpisodeView(
    id: 'progress',
    title: '回路に流れる手がかり',
    conceptLabel: '電流',
    chapterLabel: 'CASE 02',
    state: GameContentState.inProgress,
    minutes: 5,
  ),
  StoryEpisodeView(
    id: 'completed',
    title: '光の進み方',
    conceptLabel: '光の屈折',
    chapterLabel: 'CASE 03',
    state: GameContentState.completed,
    minutes: 3,
  ),
  StoryEpisodeView(
    id: 'review',
    title: '磁界をもう一度調べる',
    conceptLabel: '電流と磁界',
    chapterLabel: 'CASE 04',
    state: GameContentState.dueReview,
    minutes: 4,
  ),
  StoryEpisodeView(
    id: 'locked',
    title: '真空の落下事件',
    conceptLabel: '力と運動',
    chapterLabel: 'CASE 05',
    state: GameContentState.locked,
    minutes: 4,
  ),
];

final _practiceModes = <PracticeModeView>[
  const PracticeModeView(
    id: 'practice:heart-recovery',
    title: '試行余力の回復実験',
    description: '固定課題を最後まで見直すと、試行余力を1枠戻せます。',
    kind: PracticeModeKind.heartRecovery,
    enabled: true,
    badge: '3/5',
  ),
  ...const GameContentProjection()
      .build(
        catalog: const [],
        path: _pathData,
        duePracticeCount: 2,
        activeRepairCount: 1,
        timedChallengeGemCost: 8,
        canPurchaseTimedChallengePass: true,
      )
      .practiceModes,
];

const _notationEntries = <NotationLabEntry>[
  NotationLabEntry(
    id: 'available',
    unitTitle: '力と運動',
    conceptLabel: '落下の速さ',
    description: '力の矢印をなぞり、式を意味の順に組みます。',
    state: NotationLabState.available,
  ),
  NotationLabEntry(
    id: 'completed',
    unitTitle: '力と運動',
    conceptLabel: '力の単位',
    description: '量と単位の対応を確認します。',
    state: NotationLabState.completed,
  ),
  NotationLabEntry(
    id: 'review',
    unitTitle: '力と運動',
    conceptLabel: '速度のグラフ',
    description: '軸と傾きが表す量をもう一度読みます。',
    state: NotationLabState.reviewDue,
  ),
  NotationLabEntry(
    id: 'locked',
    unitTitle: '電流と回路',
    conceptLabel: 'オームの法則',
    description: '前の観察を終えると、式を扱えます。',
    state: NotationLabState.locked,
  ),
];

const _player = PlayerSummaryView(
  xp: 420,
  gems: 12,
  streakDays: 4,
  freezeCount: 1,
  challengeHearts: 3,
  maxChallengeHearts: 5,
  completedNodes: 8,
  totalNodes: 24,
  leagueName: '観測級03',
  weeklyLeagueXp: 120,
  nextLeagueXp: 500,
);

const _profileQuests = <QuestView>[
  QuestView(
    id: 'daily:2026-08-10:one-action',
    title: '探究ノートを1件進める',
    progress: 0,
    target: 1,
    gemReward: 1,
  ),
];

final _localLeagueHistory = <LearningLocalLeagueWeek>[
  LearningLocalLeagueWeek(
    scope: LearningScope.personal,
    weekKey: '2026-08-03',
    meaningfulEventCount: 2,
    rank: 1,
    tied: false,
    participantCount: 5,
    previousTier: LanSocialLeagueTier.silver,
    tier: LanSocialLeagueTier.gold,
    movement: LanSocialLeagueMovement.promoted,
    finalizedAt: DateTime.utc(2026, 8, 10, 4),
  ),
];

final _localLeague = LocalWeeklyLeagueView(
  availability: LocalWeeklyLeagueAvailability.notStarted,
  weekKey: '2026-08-10',
  endDay: null,
  standings: const [],
  activeRunId: null,
  integrityConflictCount: 0,
  currentTier: LanSocialLeagueTier.gold,
  history: _localLeagueHistory,
);

const _matchPairs = <ScienceMatchPair>[
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

const _matchTargets = <ScienceMatchTarget>[
  ScienceMatchTarget(id: 'heavier-first', text: '重い物体ほど必ず先に着く'),
  ScienceMatchTarget(id: 'drag-differs', text: '空気抵抗の受け方で着地時刻が変わる'),
  ScienceMatchTarget(id: 'same-acceleration', text: '重さが違っても落下加速度は同じ'),
];

const _completionSummary = GameCompletionSummary(
  eyebrow: '教材観察 / 保存済み',
  title: '観察記録を追加しました',
  message: '予想と観察を比べて、次の実験へ進めます。',
  elapsed: Duration(minutes: 4, seconds: 8),
  xpAwarded: 10,
  gemsAwarded: 1,
  showPersonalRewards: true,
  mascotStyle: LearningPathMascotStyle.orbit,
);

final class _Panel {
  const _Panel({required this.brightness, required this.child});

  final Brightness brightness;
  final Widget child;
}

Future<void> _loadNotoSansJp() async {
  final loader = FontLoader(kFontFamily)
    ..addFont(rootBundle.load('assets/fonts/NotoSansJP-Variable.ttf'));
  await loader.load();
}

Widget _panel({
  required Size viewport,
  required Brightness brightness,
  required Widget child,
}) {
  final palette = brightness == Brightness.light
      ? GamePalette.light
      : GamePalette.dark;
  return SizedBox(
    width: viewport.width,
    height: viewport.height,
    child: Theme(
      data: buildAppTheme(
        brightness,
      ).copyWith(platform: TargetPlatform.android),
      child: MediaQuery(
        data: MediaQueryData(
          size: viewport,
          devicePixelRatio: 1,
          textScaler: TextScaler.noScaling,
          platformBrightness: brightness,
          disableAnimations: true,
        ),
        child: ReduceMotionScope(
          child: Material(color: palette.canvas, child: child),
        ),
      ),
    ),
  );
}

Widget _contactSheet({
  required Key key,
  required Size viewport,
  required int columns,
  required List<_Panel> panels,
}) {
  assert(columns > 0);
  assert(panels.isNotEmpty && panels.length % columns == 0);
  final rows = panels.length ~/ columns;
  return RepaintBoundary(
    key: key,
    child: SizedBox(
      width: viewport.width * columns,
      height: viewport.height * rows,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var row = 0; row < rows; row++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var column = 0; column < columns; column++)
                  _panel(
                    viewport: viewport,
                    brightness: panels[row * columns + column].brightness,
                    child: panels[row * columns + column].child,
                  ),
              ],
            ),
        ],
      ),
    ),
  );
}

Future<void> _pumpContactSheet(
  WidgetTester tester, {
  required Key key,
  required Size viewport,
  required int columns,
  required List<_Panel> panels,
}) async {
  final rows = panels.length ~/ columns;
  tester.view.physicalSize = Size(
    viewport.width * columns,
    viewport.height * rows,
  );
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(
        Brightness.light,
      ).copyWith(platform: TargetPlatform.android),
      home: Scaffold(
        body: _contactSheet(
          key: key,
          viewport: viewport,
          columns: columns,
          panels: panels,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.binding.transientCallbackCount, 0);
  expect(tester.takeException(), isNull);
}

Widget _shellPath() => GameShell(
  playerStatus: _status,
  quests: _gameQuests,
  path: const PathScreen(
    data: _pathData,
    showStatusHeader: false,
    mascotStyle: LearningPathMascotStyle.orbit,
  ),
  stories: const SizedBox.shrink(),
  practice: const SizedBox.shrink(),
  notation: const SizedBox.shrink(),
  league: const SizedBox.shrink(),
  profile: const SizedBox.shrink(),
);

Widget _stories() => StoriesScreen(
  episodes: _episodes,
  onOpen: (_) {},
  mascotStyle: LearningPathMascotStyle.orbit,
);

Widget _practice() => PracticeHubScreen(
  modes: _practiceModes,
  dueCount: 2,
  onOpen: (_) {},
  mascotStyle: LearningPathMascotStyle.orbit,
);

Widget _notation() => NotationLabHubScreen(
  entries: _notationEntries,
  onOpen: (_) {},
  mascotStyle: LearningPathMascotStyle.orbit,
);

Widget _league() => LeagueScreen(
  player: _player,
  schoolMode: false,
  localWeeklyLeague: _localLeague,
  localWeeklyLeagueSetupParticipantCount: 5,
  onLocalWeeklyLeagueSetupParticipantCountChanged: (_) {},
  onStartLocalWeeklyLeague: (_) {},
  mascotStyle: LearningPathMascotStyle.orbit,
);

Widget _profile() => GameProfileScreen(
  player: _player,
  quests: _profileQuests,
  schoolMode: false,
  explanationCount: 2,
  onOpenSettings: () {},
  onOpenEconomy: () {},
  mascotStyle: LearningPathMascotStyle.orbit,
);

Widget _activity(GameActivityStatusController status) => GameActivityScaffold(
  statusListenable: status,
  schoolMode: false,
  onExit: () {},
  mascotStyle: LearningPathMascotStyle.orbit,
  child: ScienceMatchLabScreen(
    section: challengeSection,
    conceptLabel: '落下の条件',
    practiceAttempt: challengePracticeAttempt,
    content: const ScienceMatchLabContent(
      pairs: _matchPairs,
      targets: _matchTargets,
      timeLimit: Duration(seconds: 30),
    ),
    onCompleted: () {},
    onRetryRequested: () async => true,
    elapsedClock: () => Duration.zero,
  ),
);

Widget _completion() =>
    const GameCompletionCelebration(summary: _completionSummary);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadNotoSansJp);

  late GoldenFileComparator previousComparator;
  setUp(() {
    previousComparator = goldenFileComparator;
    goldenFileComparator = RasterStableGoldenComparator(
      Uri.parse('test/field_notebook_visual_golden_test.dart'),
    );
  });

  tearDown(() {
    goldenFileComparator = previousComparator;
  });

  testWidgets('Shellと探究ノートを390x844のlight/darkで固定する', (tester) async {
    const key = ValueKey('field-notebook-shell-path-phone-golden');
    await _pumpContactSheet(
      tester,
      key: key,
      viewport: _phone,
      columns: 2,
      panels: [
        _Panel(brightness: Brightness.light, child: _shellPath()),
        _Panel(brightness: Brightness.dark, child: _shellPath()),
      ],
    );

    expect(find.byKey(const ValueKey('game-shell-content')), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('game-path-unit-force-motion')),
      findsNWidgets(2),
    );
    expect(find.byKey(const ValueKey('game-tab-rail')), findsNothing);
    await expectLater(
      find.byKey(key),
      matchesGoldenFile('goldens/field_notebook_shell_path_phone.png'),
    );
  });

  testWidgets('Shellと探究ノートをwide railのlight/darkで固定する', (tester) async {
    const key = ValueKey('field-notebook-shell-path-wide-golden');
    await _pumpContactSheet(
      tester,
      key: key,
      viewport: _wide,
      columns: 2,
      panels: [
        _Panel(brightness: Brightness.light, child: _shellPath()),
        _Panel(brightness: Brightness.dark, child: _shellPath()),
      ],
    );

    expect(find.byKey(const ValueKey('game-tab-rail')), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('game-path-unit-force-motion')),
      findsNWidgets(2),
    );
    await expectLater(
      find.byKey(key),
      matchesGoldenFile('goldens/field_notebook_shell_path_wide.png'),
    );
  });

  testWidgets('事件・実験・図解Hubを390x844のlight/darkで固定する', (tester) async {
    const key = ValueKey('field-notebook-content-hubs-golden');
    await _pumpContactSheet(
      tester,
      key: key,
      viewport: _phone,
      columns: 3,
      panels: [
        _Panel(brightness: Brightness.light, child: _stories()),
        _Panel(brightness: Brightness.light, child: _practice()),
        _Panel(brightness: Brightness.light, child: _notation()),
        _Panel(brightness: Brightness.dark, child: _stories()),
        _Panel(brightness: Brightness.dark, child: _practice()),
        _Panel(brightness: Brightness.dark, child: _notation()),
      ],
    );

    expect(find.byKey(const ValueKey('stories-hero')), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('practice-due-summary')),
      findsNWidgets(2),
    );
    expect(find.byKey(const ValueKey('notation-lab-hero')), findsNWidgets(2));
    await expectLater(
      find.byKey(key),
      matchesGoldenFile('goldens/field_notebook_content_hubs_phone.png'),
    );
  });

  testWidgets('共同観測・研究室Hubを390x844のlight/darkで固定する', (tester) async {
    const key = ValueKey('field-notebook-social-hubs-golden');
    await _pumpContactSheet(
      tester,
      key: key,
      viewport: _phone,
      columns: 2,
      panels: [
        _Panel(brightness: Brightness.light, child: _league()),
        _Panel(brightness: Brightness.light, child: _profile()),
        _Panel(brightness: Brightness.dark, child: _league()),
        _Panel(brightness: Brightness.dark, child: _profile()),
      ],
    );

    expect(find.byKey(const ValueKey('league-progress')), findsNWidgets(2));
    expect(
      find.byKey(const ValueKey('game-profile-progress')),
      findsNWidgets(2),
    );
    await expectLater(
      find.byKey(key),
      matchesGoldenFile('goldens/field_notebook_social_hubs_phone.png'),
    );
  });

  testWidgets('共通HUDとactivity Lab Briefを390x844のlight/darkで固定する', (
    tester,
  ) async {
    final lightStatus = GameActivityStatusController(_status);
    final darkStatus = GameActivityStatusController(_status);
    addTearDown(lightStatus.dispose);
    addTearDown(darkStatus.dispose);
    const key = ValueKey('field-notebook-activity-golden');

    await _pumpContactSheet(
      tester,
      key: key,
      viewport: _phone,
      columns: 2,
      panels: [
        _Panel(brightness: Brightness.light, child: _activity(lightStatus)),
        _Panel(brightness: Brightness.dark, child: _activity(darkStatus)),
      ],
    );

    expect(
      find.byKey(const ValueKey('game-activity-scaffold')),
      findsNWidgets(2),
    );
    expect(
      find.byKey(const ValueKey('science-challenge-lab-brief')),
      findsNWidgets(2),
    );
    expect(find.byKey(const ValueKey('match-start')), findsNWidgets(2));
    expect(
      find.textContaining("Instance of 'LocalCognitiveTaskPrompt'"),
      findsNothing,
    );
    expect(find.textContaining('結果を予測する'), findsNWidgets(2));
    await expectLater(
      find.byKey(key),
      matchesGoldenFile('goldens/field_notebook_activity_phone.png'),
    );
  });

  testWidgets('完了記録票を390x844のlight/darkで固定する', (tester) async {
    const key = ValueKey('field-notebook-completion-golden');
    await _pumpContactSheet(
      tester,
      key: key,
      viewport: _phone,
      columns: 2,
      panels: [
        _Panel(brightness: Brightness.light, child: _completion()),
        _Panel(brightness: Brightness.dark, child: _completion()),
      ],
    );

    expect(
      find.byKey(const ValueKey('game-completion-celebration')),
      findsNWidgets(2),
    );
    expect(find.byKey(const ValueKey('completion-ledger')), findsNWidgets(2));
    await expectLater(
      find.byKey(key),
      matchesGoldenFile('goldens/field_notebook_completion_phone.png'),
    );
  });
}
