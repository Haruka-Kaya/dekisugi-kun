import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/game_tokens.dart';
import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/learning/domain/learning_progress.dart';
import 'package:dekisugi/learning/services/local_weekly_league_projection.dart';
import 'package:dekisugi/models/game_hub.dart';
import 'package:dekisugi/models/league_ladder.dart';
import 'package:dekisugi/screens/game_profile_screen.dart';
import 'package:dekisugi/screens/league_screen.dart';
import 'package:dekisugi/screens/practice_hub_screen.dart';
import 'package:dekisugi/screens/stories_screen.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:flutter_test/flutter_test.dart';

const _episodes = [
  StoryEpisodeView(
    id: 'available',
    title: '浮く力の謎',
    conceptLabel: '浮力',
    chapterLabel: 'CASE 01',
    state: GameContentState.available,
    minutes: 3,
  ),
  StoryEpisodeView(
    id: 'locked',
    title: '真空の落下事件',
    conceptLabel: '力と運動',
    chapterLabel: 'CASE 02',
    state: GameContentState.locked,
    minutes: 4,
  ),
  StoryEpisodeView(
    id: 'progress',
    title: '回路に流れる手がかり',
    conceptLabel: '電流',
    chapterLabel: 'CASE 03',
    state: GameContentState.inProgress,
    minutes: 5,
  ),
  StoryEpisodeView(
    id: 'completed',
    title: '光の進み方',
    conceptLabel: '光の屈折',
    chapterLabel: 'CASE 04',
    state: GameContentState.completed,
    minutes: 3,
  ),
  StoryEpisodeView(
    id: 'review',
    title: '磁界をもう一度調べる',
    conceptLabel: '電流と磁界',
    chapterLabel: 'CASE 05',
    state: GameContentState.dueReview,
    minutes: 4,
  ),
];

const _practiceModes = [
  PracticeModeView(
    id: 'personalized',
    title: 'あなた向け復習',
    description: '忘れかけた概念を別の場面で思い出す。',
    kind: PracticeModeKind.personalized,
    enabled: true,
    badge: '復習 2件',
  ),
  PracticeModeView(
    id: 'listen',
    title: '聞く・話す',
    description: '音声で理由を説明する練習。',
    kind: PracticeModeKind.listenSpeak,
    enabled: false,
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
  leagueName: '彗星',
  weeklyLeagueXp: 120,
  nextLeagueXp: 500,
);

const _quests = [
  QuestView(
    id: 'daily:2026-08-10:one-action',
    title: '学習パスを1件進める',
    progress: 0,
    target: 1,
    gemReward: 1,
  ),
];

final _localLeagueHistory = [
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

final _localLeagueView = LocalWeeklyLeagueView(
  availability: LocalWeeklyLeagueAvailability.notStarted,
  weekKey: '2026-08-10',
  endDay: null,
  standings: const [],
  activeRunId: null,
  integrityConflictCount: 0,
  currentTier: LanSocialLeagueTier.gold,
  history: _localLeagueHistory,
);

Widget _app({
  required Widget child,
  required Brightness brightness,
  double textScale = 2,
}) => MaterialApp(
  theme: buildAppTheme(brightness),
  builder: (context, page) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: page!,
  ),
  home: Scaffold(body: child),
);

Finder _scrollableFor(Key key) => find
    .descendant(of: find.byKey(key), matching: find.byType(Scrollable))
    .first;

Future<void> _show(WidgetTester tester, Finder target, Key screenKey) async {
  await tester.scrollUntilVisible(
    target,
    150,
    scrollable: _scrollableFor(screenKey),
  );
  await tester.pump();
}

BoxDecoration _decoration(WidgetTester tester, Finder finder) =>
    tester.widget<Container>(finder).decoration! as BoxDecoration;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestWidgetsFlutterBinding
            .instance
            .platformDispatcher
            .textScaleFactorTestValue =
        1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearTextScaleFactorTestValue();
  });

  testWidgets('Storiesは5状態をicon・label・Semanticsで表しlight/darkに追従する', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    const expected = <String, (String, IconData)>{
      'available': ('読めます', Icons.menu_book_rounded),
      'locked': ('未解放', Icons.lock_outline_rounded),
      'progress': ('続きから', Icons.play_arrow_rounded),
      'completed': ('完了', Icons.check_rounded),
      'review': ('もう一度', Icons.replay_rounded),
    };

    for (final brightness in Brightness.values) {
      final opened = <String>[];
      final palette = brightness == Brightness.light
          ? GamePalette.light
          : GamePalette.dark;
      await tester.pumpWidget(
        KeyedSubtree(
          key: ValueKey('stories-${brightness.name}'),
          child: _app(
            brightness: brightness,
            child: StoriesScreen(
              episodes: _episodes,
              onOpen: (episode) => opened.add(episode.id),
            ),
          ),
        ),
      );
      await tester.pump();

      for (final episode in _episodes) {
        final card = find.byKey(ValueKey('story-episode-${episode.id}'));
        await _show(tester, card, const ValueKey('stories-screen'));
        expect(tester.getSize(card).height, greaterThanOrEqualTo(48));
        expect(
          find.descendant(
            of: find.byKey(ValueKey('story-node-${episode.id}')),
            matching: find.byIcon(expected[episode.id]!.$2),
          ),
          findsOneWidget,
        );
        expect(
          _decoration(
            tester,
            find.byKey(ValueKey('story-node-${episode.id}')),
          ).shape,
          isNot(BoxShape.circle),
          reason: '事件ファイルへ丸いゲームnodeを再導入しない',
        );
        expect(
          find.bySemanticsLabel(
            RegExp(
              '${RegExp.escape(episode.title)}.*${expected[episode.id]!.$1}',
            ),
          ),
          findsOneWidget,
        );
        if (episode.id == 'completed') {
          expect(
            _decoration(
              tester,
              find.byKey(const ValueKey('story-node-completed')),
            ).color,
            palette.pathComplete,
          );
          expect(tester.widget<Material>(card).color, palette.surface);
        }
        if (episode.id == 'available') {
          await tester.tap(card);
          await tester.pump();
          expect(opened, ['available']);
        }
        if (episode.id == 'locked') {
          await tester.tap(card);
          await tester.pump();
          expect(opened, ['available'], reason: '未解放はcallbackを呼ばない');
        }
      }
      expect(tester.takeException(), isNull);
    }

    semantics.dispose();
  });

  testWidgets('Practiceは復習期限と利用可否をtoken・icon・labelで表す', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    for (final brightness in Brightness.values) {
      final opened = <String>[];
      final palette = brightness == Brightness.light
          ? GamePalette.light
          : GamePalette.dark;
      await tester.pumpWidget(
        KeyedSubtree(
          key: ValueKey('practice-${brightness.name}'),
          child: _app(
            brightness: brightness,
            child: PracticeHubScreen(
              modes: _practiceModes,
              dueCount: 2,
              onOpen: (mode) => opened.add(mode.id),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.bySemanticsLabel(RegExp('今日が期限の復習、2件')), findsOneWidget);
      final brief = _decoration(
        tester,
        find.byKey(const ValueKey('practice-due-summary')),
      );
      expect(brief.color, palette.surfaceRaised);
      expect(brief.border, Border.all(color: palette.border));

      final enabled = find.byKey(const ValueKey('practice-mode-personalized'));
      await _show(tester, enabled, const ValueKey('practice-hub-screen'));
      expect(tester.getSize(enabled).height, greaterThanOrEqualTo(48));
      expect(
        find.bySemanticsLabel(RegExp('あなた向け復習.*利用できます.*復習 2件')),
        findsOneWidget,
      );
      expect(
        _decoration(
          tester,
          find.byKey(const ValueKey('practice-mode-icon-personalized')),
        ).color,
        palette.pathReview,
      );
      await tester.tap(enabled);
      await tester.pump();
      expect(opened, ['personalized']);

      final disabled = find.byKey(const ValueKey('practice-mode-listen'));
      await _show(tester, disabled, const ValueKey('practice-hub-screen'));
      expect(tester.getSize(disabled).height, greaterThanOrEqualTo(48));
      expect(find.bySemanticsLabel(RegExp('聞く・話す.*準備中')), findsOneWidget);
      expect(
        find.descendant(of: disabled, matching: find.text('準備中')),
        findsOneWidget,
      );
      await tester.tap(disabled);
      await tester.pump();
      expect(opened, ['personalized'], reason: '準備中はcallbackを呼ばない');
      expect(tester.takeException(), isNull);
    }

    await tester.pumpWidget(
      _app(
        brightness: Brightness.dark,
        child: PracticeHubScreen(modes: const [], dueCount: 0, onOpen: (_) {}),
      ),
    );
    expect(find.bySemanticsLabel(RegExp('今日が期限の復習はありません')), findsOneWidget);
    expect(
      _decoration(
        tester,
        find.byKey(const ValueKey('practice-due-summary')),
      ).color,
      GamePalette.dark.surfaceRaised,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('Leagueは学校の端末内協力面を保ち0/0を出さずlight/darkに追従する', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    for (final brightness in Brightness.values) {
      final palette = brightness == Brightness.light
          ? GamePalette.light
          : GamePalette.dark;
      await tester.pumpWidget(
        KeyedSubtree(
          key: ValueKey('league-school-${brightness.name}'),
          child: _app(
            brightness: brightness,
            child: const LeagueScreen(player: _player, schoolMode: true),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('0 / 0'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('端末内の協力モード.*個人順位.*集計しません')),
        findsOneWidget,
      );
      final hero = find.byKey(const ValueKey('league-school-local'));
      final decoration = _decoration(tester, hero);
      expect(decoration.color, palette.surfaceRaised);
      expect(decoration.border, isNotNull);

      final rules = find.byKey(const ValueKey('league-rules-disclosure'));
      await _show(tester, rules, const ValueKey('league-screen'));
      await tester.tap(rules);
      await tester.pumpAndSettle();
      final thirdRule = find.bySemanticsLabel(RegExp('ルール。生徒の個人順位'));
      expect(thirdRule, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(8, 8));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        KeyedSubtree(
          key: ValueKey('league-school-progress-${brightness.name}'),
          child: _app(
            brightness: brightness,
            child: const LeagueScreen(
              player: _player,
              schoolMode: true,
              classCompleted: 1,
              classTarget: 1,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('この端末の観察目標'), findsOneWidget);
      expect(find.text('クラス共同ミッション'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('この端末の授業目標、1、目標1.*クラス全体の件数は集計しません')),
        findsOneWidget,
      );

      await tester.pumpWidget(
        KeyedSubtree(
          key: ValueKey('league-personal-${brightness.name}'),
          child: _app(
            brightness: brightness,
            child: LeagueScreen(
              player: _player,
              schoolMode: false,
              localWeeklyLeague: _localLeagueView,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('観測級03の共同観測'), findsOneWidget);
      expect(find.textContaining('120 / 500'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('観測級03の共同観測.*実在5人から8人')),
        findsOneWidget,
      );
      expect(
        _decoration(
          tester,
          find.byKey(const ValueKey('league-progress')),
        ).color,
        palette.surfaceRaised,
      );
      await _show(
        tester,
        find.byKey(const ValueKey('local-league-history-2026-08-03')),
        const ValueKey('league-screen'),
      );
      expect(
        find.bySemanticsLabel('2026-08-03の週、観測級03、1位、観察2件、上位級へ'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }

    semantics.dispose();
  });

  testWidgets('Profileは実進捗とprivacy境界を320dp・light/darkで保つ', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    for (final brightness in Brightness.values) {
      var settings = 0;
      final palette = brightness == Brightness.light
          ? GamePalette.light
          : GamePalette.dark;
      await tester.pumpWidget(
        KeyedSubtree(
          key: ValueKey('profile-${brightness.name}'),
          child: _app(
            brightness: brightness,
            child: GameProfileScreen(
              player: _player,
              quests: _quests,
              schoolMode: false,
              explanationCount: 2,
              onOpenSettings: () => settings++,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        _decoration(
          tester,
          find.byKey(const ValueKey('game-profile-progress')),
        ).color,
        palette.surfaceRaised,
      );
      await tester.tap(find.byKey(const ValueKey('game-profile-settings')));
      expect(settings, 1);
      await _show(
        tester,
        find.byKey(const ValueKey('game-profile-metric-説明の見直し')),
        const ValueKey('game-profile-screen'),
      );
      expect(find.bySemanticsLabel('説明の見直し、2回'), findsOneWidget);
      await _show(
        tester,
        find.byKey(
          const ValueKey('game-profile-quest-daily:2026-08-10:one-action'),
        ),
        const ValueKey('game-profile-screen'),
      );
      expect(
        find.bySemanticsLabel(RegExp('探究ノートを1件進める.*結晶1個')),
        findsOneWidget,
      );

      final policy = find.byKey(const ValueKey('game-profile-policy'));
      await _show(tester, policy, const ValueKey('game-profile-screen'));
      expect(_decoration(tester, policy).color, palette.surfaceRaised);
      expect(find.textContaining('専用の回復練習1件'), findsOneWidget);
      expect(find.textContaining('結晶2個で全回復'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await tester.pumpWidget(
      _app(
        brightness: Brightness.dark,
        child: GameProfileScreen(
          player: _player,
          quests: _quests,
          schoolMode: true,
          explanationCount: 1,
          onOpenSettings: () {},
          onOpenClassroom: () {},
        ),
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('game-profile-metric-連続観測')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('game-profile-metric-ひらめき結晶')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('game-profile-open-classroom')),
      findsOneWidget,
    );
    final schoolGoalHeading = find.text('今日の授業目標（この端末）');
    await _show(
      tester,
      schoolGoalHeading,
      const ValueKey('game-profile-screen'),
    );
    expect(schoolGoalHeading, findsOneWidget);
    expect(find.textContaining('今日の共同目標'), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
