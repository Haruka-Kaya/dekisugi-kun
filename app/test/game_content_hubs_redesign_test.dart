import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/game_tokens.dart';
import 'package:dekisugi/config/motion.dart';
import 'package:dekisugi/learning/domain/learning_economy.dart';
import 'package:dekisugi/learning/services/daily_audio_practice_plan.dart';
import 'package:dekisugi/models/game_hub.dart';
import 'package:dekisugi/models/game_path.dart';
import 'package:dekisugi/screens/notation_lab_hub_screen.dart';
import 'package:dekisugi/screens/practice_hub_screen.dart';
import 'package:dekisugi/screens/stories_screen.dart';
import 'package:dekisugi/widgets/game_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

const _practiceModes = [
  PracticeModeView(
    id: 'practice:heart-recovery',
    title: '学習ハート回復',
    description: '固定課題を1件終えて1個戻す。',
    kind: PracticeModeKind.heartRecovery,
    enabled: true,
  ),
  PracticeModeView(
    id: 'practice:personalized',
    title: 'あなた向け復習',
    description: '忘れかけた概念を別の場面で思い出す。',
    kind: PracticeModeKind.personalized,
    enabled: true,
    badge: '復習 2件',
  ),
  PracticeModeView(
    id: 'practice:resume',
    title: '続きから学ぶ',
    description: '中断した固定課題の続きに戻る。',
    kind: PracticeModeKind.resume,
    enabled: true,
  ),
  PracticeModeView(
    id: 'practice:repair',
    title: '思い込みを直す',
    description: '残った学習needを別の問いで解き直す。',
    kind: PracticeModeKind.repair,
    enabled: true,
  ),
  PracticeModeView(
    id: 'practice:diagram',
    title: '図で考える',
    description: '条件と結果を図に組み直す。',
    kind: PracticeModeKind.diagram,
    enabled: true,
  ),
  PracticeModeView(
    id: 'practice:timed',
    title: '時間制チャレンジ',
    description: '任意の速度練習。',
    kind: PracticeModeKind.timed,
    enabled: true,
  ),
  PracticeModeView(
    id: 'practice:match',
    title: '組み合わせラボ',
    description: '条件と理由を対応させる。',
    kind: PracticeModeKind.match,
    enabled: true,
  ),
  PracticeModeView(
    id: 'practice:lightning',
    title: 'ライトニング',
    description: '短い固定課題を連続して解く。',
    kind: PracticeModeKind.lightning,
    enabled: false,
  ),
];

const _audioPlan = DailyAudioPracticePlan(
  learningDay: '2026-08-10',
  missions: [
    DailyAudioMission(
      nodeId: 'path:v1:motion:fall:listening',
      unitId: 'motion',
      conceptKey: 'fall',
      conceptLabel: '落下',
      kind: DailyAudioMissionKind.listening,
      practiceAttempt: 1,
      completedToday: false,
    ),
    DailyAudioMission(
      nodeId: 'path:v1:motion:fall:speaking',
      unitId: 'motion',
      conceptKey: 'fall',
      conceptLabel: '落下',
      kind: DailyAudioMissionKind.speaking,
      practiceAttempt: 2,
      completedToday: true,
    ),
  ],
);

const _notationEntries = [
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
    description: '前の学習を終えると、式を扱えます。',
    state: NotationLabState.locked,
  ),
];

Widget _host({
  required Widget child,
  required String fixtureKey,
  Brightness brightness = Brightness.light,
  TextScaler textScaler = TextScaler.noScaling,
  bool disableAnimations = false,
  ValueChanged<bool>? onReduceMotion,
}) => MaterialApp(
  key: ValueKey(fixtureKey),
  theme: buildAppTheme(brightness),
  builder: (context, page) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: textScaler, disableAnimations: disableAnimations),
    child: ReduceMotionScope(
      child: Builder(
        builder: (scopeContext) {
          onReduceMotion?.call(ReduceMotionScope.of(scopeContext));
          return page!;
        },
      ),
    ),
  ),
  home: Scaffold(body: child),
);

StoriesScreen _stories({
  LearningPathMascotStyle mascotStyle = LearningPathMascotStyle.standard,
  List<StoryEpisodeView> episodes = _episodes,
  ValueChanged<StoryEpisodeView>? onOpen,
}) => StoriesScreen(
  episodes: episodes,
  onOpen: onOpen ?? (_) {},
  mascotStyle: mascotStyle,
);

PracticeHubScreen _practice({
  LearningPathMascotStyle mascotStyle = LearningPathMascotStyle.standard,
}) => PracticeHubScreen(
  modes: _practiceModes,
  dueCount: 2,
  onOpen: (_) {},
  dailyAudioPlan: _audioPlan,
  onOpenDailyAudio: (_) {},
  mascotStyle: mascotStyle,
);

NotationLabHubScreen _notation({
  LearningPathMascotStyle mascotStyle = LearningPathMascotStyle.standard,
  List<NotationLabEntry> entries = _notationEntries,
  ValueChanged<NotationLabEntry>? onOpen,
}) => NotationLabHubScreen(
  entries: entries,
  onOpen: onOpen ?? (_) {},
  mascotStyle: mascotStyle,
);

Finder _scrollable(Key screenKey) => find
    .descendant(of: find.byKey(screenKey), matching: find.byType(Scrollable))
    .first;

Future<void> _reveal(WidgetTester tester, Finder target, Key screenKey) async {
  await tester.scrollUntilVisible(
    target,
    180,
    scrollable: _scrollable(screenKey),
  );
  await tester.pump();
}

BoxDecoration _decoration(WidgetTester tester, Finder finder) =>
    tester.widget<Container>(finder).decoration! as BoxDecoration;

GameCharacterReaction _heroReaction(WidgetTester tester) => tester
    .widget<GameHeroSurface>(find.byType(GameHeroSurface))
    .mascotReaction!;

void main() {
  testWidgets('共通Heroは要約を一度だけ読み、補足・設定・CTAは独立操作として残す', (tester) async {
    final semantics = tester.ensureSemantics();
    var actionCount = 0;
    final colors = GamePalette.light;

    await tester.pumpWidget(
      _host(
        fixtureKey: 'hero-semantics',
        child: GameHeroSurface(
          color: colors.story,
          foregroundColor: colors.onStory,
          eyebrow: '研究ミッション',
          title: '重力の見出し',
          body: '観察を比べます。',
          semanticSummary: '研究ミッション。重力の見出し。観察を比べます。',
          leading: Semantics(
            label: '装飾アイコン',
            child: const Icon(Icons.science_outlined),
          ),
          trailing: Semantics(
            button: true,
            label: '設定を開く',
            excludeSemantics: true,
            child: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.settings_outlined),
            ),
          ),
          content: Semantics(
            label: '補足情報',
            excludeSemantics: true,
            child: const Text('進捗の補足'),
          ),
          primaryAction: FilledButton(
            onPressed: () => actionCount++,
            child: const Text('続ける'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('研究ミッション'), findsOneWidget);
    expect(find.text('重力の見出し'), findsOneWidget);
    expect(find.text('観察を比べます。'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('研究ミッション')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('重力の見出し')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('観察を比べます。')), findsOneWidget);
    expect(find.bySemanticsLabel('装飾アイコン'), findsOneWidget);
    expect(find.bySemanticsLabel('補足情報'), findsOneWidget);
    expect(find.bySemanticsLabel('設定を開く'), findsOneWidget);
    expect(find.bySemanticsLabel('続ける'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('続ける'));
    await tester.pump();
    expect(actionCount, 1);
    semantics.dispose();
  });

  testWidgets('3つのhubは320x568・文字200%のlight/darkで末尾まで読める', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        _host(
          child: _stories(),
          fixtureKey: 'stories-${brightness.name}',
          brightness: brightness,
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp('理科事件簿.*5件中4件')), findsOneWidget);
      final lastStory = find.byKey(const ValueKey('story-episode-locked'));
      await _reveal(tester, lastStory, const ValueKey('stories-screen'));
      expect(tester.getSize(lastStory).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _host(
          child: _practice(),
          fixtureKey: 'practice-${brightness.name}',
          brightness: brightness,
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp('今日が期限の復習、2件')), findsOneWidget);
      final practiceEnd = find.byKey(const ValueKey('practice-policy'));
      await _reveal(tester, practiceEnd, const ValueKey('practice-hub-screen'));
      expect(find.text('時間制チャレンジ'), findsOneWidget);
      expect(
        tester
            .getSize(
              find.byKey(const ValueKey('practice-mode-practice:lightning')),
            )
            .height,
        greaterThanOrEqualTo(48),
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        _host(
          child: _notation(),
          fixtureKey: 'notation-${brightness.name}',
          brightness: brightness,
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel(RegExp('記号ラボ.*利用できる課題3件')), findsOneWidget);
      final notationEnd = find.byKey(const ValueKey('notation-lab-guide'));
      await _reveal(tester, notationEnd, const ValueKey('notation-lab-hub'));
      expect(
        tester
            .getSize(find.byKey(const ValueKey('notation-entry-locked')))
            .height,
        greaterThanOrEqualTo(48),
      );
      expect(tester.takeException(), isNull);
    }
    semantics.dispose();
  });

  testWidgets('3つのhubは装備中mascotを現在状態のreaction付きHeroへ反映する', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    final fixtures = <({Widget screen, GameCharacterReaction reaction})>[
      (
        screen: _stories(mascotStyle: LearningPathMascotStyle.orbit),
        reaction: GameCharacterReaction.encourage,
      ),
      (
        screen: _practice(mascotStyle: LearningPathMascotStyle.orbit),
        reaction: GameCharacterReaction.encourage,
      ),
      (
        screen: _notation(mascotStyle: LearningPathMascotStyle.orbit),
        reaction: GameCharacterReaction.encourage,
      ),
    ];

    for (final (index, fixture) in fixtures.indexed) {
      await tester.pumpWidget(
        _host(
          child: fixture.screen,
          fixtureKey: 'mascot-$index',
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('game-hero-mascot')), findsOneWidget);
      expect(find.byKey(const ValueKey('path-mascot-orbit')), findsOneWidget);
      expect(_heroReaction(tester), fixture.reaction);
      expect(
        find.bySemanticsLabel('軌道リングのデキすぎ君が${fixture.reaction.semanticsLabel}'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
    semantics.dispose();
  });

  testWidgets('Stories HeroはinProgressを最優先し、続きのreactionと単一CTAへ結ぶ', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    StoryEpisodeView? opened;

    await tester.pumpWidget(
      _host(
        fixtureKey: 'stories-priority',
        brightness: Brightness.dark,
        textScaler: const TextScaler.linear(2),
        child: _stories(
          episodes: [_episodes[0], _episodes[3], _episodes[1]],
          onOpen: (episode) => opened = episode,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('「回路に流れる手がかり」の続き'), findsOneWidget);
    expect(_heroReaction(tester), GameCharacterReaction.encourage);
    expect(
      find.bySemanticsLabel(RegExp('理科事件簿.*続きの事件は回路に流れる手がかり')),
      findsOneWidget,
    );
    final action = find.byKey(const ValueKey('stories-primary-action'));
    expect(action, findsOneWidget);
    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
    await _reveal(tester, action, const ValueKey('stories-screen'));
    await tester.tap(action);
    expect(opened?.id, 'progress');
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('Stories Heroはreview→availableの順で選び、完了と空は独立reactionになる', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _host(
        fixtureKey: 'stories-review',
        child: _stories(episodes: [_episodes[0], _episodes[3]]),
      ),
    );
    expect(find.text('「磁界をもう一度調べる」をもう一度'), findsOneWidget);
    expect(find.text('もう一度調べる'), findsOneWidget);
    expect(_heroReaction(tester), GameCharacterReaction.thinking);

    await tester.pumpWidget(
      _host(
        fixtureKey: 'stories-available',
        child: _stories(episodes: [_episodes[0]]),
      ),
    );
    expect(find.text('浮く力の謎'), findsWidgets);
    expect(find.text('事件を開く'), findsOneWidget);
    expect(_heroReaction(tester), GameCharacterReaction.invite);

    await tester.pumpWidget(
      _host(
        fixtureKey: 'stories-completed',
        child: _stories(episodes: [_episodes[2]]),
      ),
    );
    expect(find.text('すべての事件を解明しました'), findsOneWidget);
    expect(find.byKey(const ValueKey('stories-primary-action')), findsNothing);
    expect(_heroReaction(tester), GameCharacterReaction.celebrate);

    await tester.pumpWidget(
      _host(
        fixtureKey: 'stories-empty',
        child: _stories(episodes: const []),
      ),
    );
    expect(find.text('最初の事件を準備中'), findsOneWidget);
    expect(find.byKey(const ValueKey('stories-primary-action')), findsNothing);
    expect(_heroReaction(tester), GameCharacterReaction.invite);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('Notation HeroはreviewDueを最優先し、次課題のreactionと単一CTAへ結ぶ', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    NotationLabEntry? opened;

    await tester.pumpWidget(
      _host(
        fixtureKey: 'notation-priority',
        brightness: Brightness.dark,
        textScaler: const TextScaler.linear(2),
        child: _notation(
          entries: [_notationEntries[0], _notationEntries[2]],
          onOpen: (entry) => opened = entry,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('「速度のグラフ」をもう一度'), findsOneWidget);
    expect(_heroReaction(tester), GameCharacterReaction.encourage);
    expect(find.bySemanticsLabel(RegExp('記号ラボ.*次は速度のグラフを復習')), findsOneWidget);
    final action = find.byKey(const ValueKey('notation-lab-primary-action'));
    expect(action, findsOneWidget);
    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
    await _reveal(tester, action, const ValueKey('notation-lab-hub'));
    await tester.tap(action);
    expect(opened?.id, 'review');
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('Notation Heroはavailableを直結し、全完了と空は独立reactionになる', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _host(
        fixtureKey: 'notation-available',
        child: _notation(entries: [_notationEntries[0]]),
      ),
    );
    expect(find.text('次の課題を開く'), findsOneWidget);
    expect(_heroReaction(tester), GameCharacterReaction.invite);

    await tester.pumpWidget(
      _host(
        fixtureKey: 'notation-completed',
        child: _notation(entries: [_notationEntries[1]]),
      ),
    );
    expect(find.text('すべての記号課題を練習しました'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('notation-lab-primary-action')),
      findsNothing,
    );
    expect(_heroReaction(tester), GameCharacterReaction.celebrate);

    await tester.pumpWidget(
      _host(
        fixtureKey: 'notation-empty',
        child: _notation(entries: const []),
      ),
    );
    expect(find.text('最初の記号課題を準備中'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('notation-lab-primary-action')),
      findsNothing,
    );
    expect(_heroReaction(tester), GameCharacterReaction.invite);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('700dp+は本文720dp・3列の同じ階層にする', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final fixtures = <({Widget screen, String heroKey, List<String> cards})>[
      (
        screen: _stories(),
        heroKey: 'stories-hero',
        cards: [
          'story-episode-available',
          'story-episode-progress',
          'story-episode-completed',
        ],
      ),
      (
        screen: _practice(),
        heroKey: 'practice-due-summary',
        cards: [
          'practice-mode-practice:heart-recovery',
          'practice-mode-practice:personalized',
          'practice-mode-practice:resume',
        ],
      ),
      (
        screen: _notation(),
        heroKey: 'notation-lab-hero',
        cards: [
          'notation-entry-available',
          'notation-entry-completed',
          'notation-entry-review',
        ],
      ),
    ];

    for (final fixture in fixtures) {
      await tester.pumpWidget(
        _host(child: fixture.screen, fixtureKey: 'wide-${fixture.heroKey}'),
      );
      await tester.pump();
      final hero = find.byKey(ValueKey(fixture.heroKey));
      expect(
        tester.getSize(hero).width,
        lessThanOrEqualTo(GameTokens.gamePageMaxWidth),
      );
      expect(tester.getTopLeft(hero).dx, closeTo(140, 1));
      final firstY = tester
          .getTopLeft(find.byKey(ValueKey(fixture.cards.first)))
          .dy;
      for (final key in fixture.cards.skip(1)) {
        expect(
          tester.getTopLeft(find.byKey(ValueKey(key))).dy,
          closeTo(firstY, 1),
        );
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Android/iOS Reduce Motionでも情報を減らさず末尾へ到達できる', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final binding = TestWidgetsFlutterBinding.instance;
    try {
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        debugDefaultTargetPlatformOverride = platform;
        final ios = platform == TargetPlatform.iOS;
        binding.platformDispatcher.accessibilityFeaturesTestValue =
            FakeAccessibilityFeatures(reduceMotion: ios);
        final fixtures = <({Widget screen, Key screenKey, Finder terminal})>[
          (
            screen: _stories(),
            screenKey: const ValueKey('stories-screen'),
            terminal: find.byKey(const ValueKey('story-episode-locked')),
          ),
          (
            screen: _practice(),
            screenKey: const ValueKey('practice-hub-screen'),
            terminal: find.byKey(const ValueKey('practice-policy')),
          ),
          (
            screen: _notation(),
            screenKey: const ValueKey('notation-lab-hub'),
            terminal: find.byKey(const ValueKey('notation-lab-guide')),
          ),
        ];

        for (var index = 0; index < fixtures.length; index++) {
          final fixture = fixtures[index];
          bool? reduceMotion;
          await tester.pumpWidget(
            _host(
              child: fixture.screen,
              fixtureKey: 'motion-${platform.name}-$index',
              textScaler: const TextScaler.linear(2),
              disableAnimations: !ios,
              onReduceMotion: (value) => reduceMotion = value,
            ),
          );
          await tester.pumpAndSettle();
          expect(reduceMotion, isTrue);
          await _reveal(tester, fixture.terminal, fixture.screenKey);
          expect(fixture.terminal, findsOneWidget);
          expect(
            find.descendant(
              of: find.byKey(fixture.screenKey),
              matching: find.byType(AnimatedContainer),
            ),
            findsNothing,
          );
          expect(tester.binding.transientCallbackCount, 0);
          expect(tester.takeException(), isNull);
        }
      }
    } finally {
      debugDefaultTargetPlatformOverride = null;
      binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
    }
  });

  testWidgets('3つのheroは中立なLab Brief面と4dpのaccent罫線を使う', (tester) async {
    final fixtures = <({Widget screen, String heroKey, Color color})>[
      (
        screen: _stories(),
        heroKey: 'stories-hero',
        color: GamePalette.dark.story,
      ),
      (
        screen: _practice(),
        heroKey: 'practice-due-summary',
        color: GamePalette.dark.pathReview,
      ),
      (
        screen: _notation(),
        heroKey: 'notation-lab-hero',
        color: GamePalette.dark.story,
      ),
    ];
    for (final fixture in fixtures) {
      await tester.pumpWidget(
        _host(
          child: fixture.screen,
          fixtureKey: 'solid-${fixture.heroKey}',
          brightness: Brightness.dark,
        ),
      );
      final decoration = _decoration(
        tester,
        find.byKey(ValueKey(fixture.heroKey)),
      );
      expect(decoration.color, GamePalette.dark.benchRaised);
      expect(decoration.gradient, isNull);
      expect(decoration.boxShadow, isNull);
      expect(decoration.border, isA<Border>());
      final accentRule = find.descendant(
        of: find.byKey(ValueKey(fixture.heroKey)),
        matching: find.byKey(const ValueKey('game-hero-accent-rule')),
      );
      expect(accentRule, findsOneWidget);
      expect(tester.widget<ColoredBox>(accentRule).color, fixture.color);
      expect(tester.getSize(accentRule).width, GameTokens.accentRuleWidth);

      final mascotSurface = find.descendant(
        of: find.byKey(ValueKey(fixture.heroKey)),
        matching: find.byKey(const ValueKey('game-hero-mascot-surface')),
      );
      expect(mascotSurface, findsOneWidget);
      final mascotDecoration = _decoration(tester, mascotSurface);
      expect(mascotDecoration.shape, BoxShape.rectangle);
      expect(
        mascotDecoration.borderRadius,
        BorderRadius.circular(GameTokens.radiusSm),
      );
    }
  });
}
