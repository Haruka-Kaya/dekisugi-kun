import 'dart:ui' show SemanticsAction;

import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/game_tokens.dart';
import 'package:dekisugi/learning/domain/learning_economy.dart';
import 'package:dekisugi/learning/domain/learning_monthly_badge.dart';
import 'package:dekisugi/learning/services/local_weekly_league_projection.dart';
import 'package:dekisugi/models/game_hub.dart';
import 'package:dekisugi/screens/game_profile_screen.dart';
import 'package:dekisugi/screens/league_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    id: 'daily:one-action',
    title: '学習パスを1件進める',
    progress: 0,
    target: 1,
    gemReward: 1,
  ),
];

const _notStarted = LocalWeeklyLeagueView(
  availability: LocalWeeklyLeagueAvailability.notStarted,
  weekKey: '2026-08-10',
  endDay: null,
  standings: [],
  activeRunId: null,
  integrityConflictCount: 0,
);

const _activeLocal = LocalWeeklyLeagueView(
  availability: LocalWeeklyLeagueAvailability.active,
  weekKey: '2026-08-10',
  endDay: '2026-08-16',
  standings: [
    LocalWeeklyLeagueStanding(
      participantId: 'opaque.local.1',
      slotNumber: 1,
      meaningfulEventCount: 1,
      rank: 1,
      tied: true,
    ),
    LocalWeeklyLeagueStanding(
      participantId: 'opaque.local.2',
      slotNumber: 2,
      meaningfulEventCount: 1,
      rank: 1,
      tied: true,
    ),
  ],
  activeRunId: 'local-weekly-league.round.1',
  integrityConflictCount: 0,
);

final _badges = [
  for (final (index, style) in LearningMonthlyBadgeStyle.values.indexed)
    LearningMonthlyBadgeAward(
      badgeId: 'badge.$index',
      sourceQuestInstanceId: 'monthly:2026-08:badge-$index',
      learningMonth: '2026-08',
      title: '観測バッジ${index + 1}',
      description: '意味のある学習の記録です。',
      style: style,
      unlockedAt: DateTime.utc(2026, 8, 20 + index),
    ),
];

Widget _host({
  required Widget child,
  Brightness brightness = Brightness.light,
  TextScaler textScaler = TextScaler.noScaling,
}) => MaterialApp(
  theme: buildAppTheme(brightness),
  builder: (context, page) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: page!,
  ),
  home: Scaffold(body: child),
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

void main() {
  testWidgets(
    'Leagueは320x568・文字200%のlight/darkでschool/local/onlineを完全scrollできる',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();

      for (final brightness in Brightness.values) {
        for (final mode in ['school', 'local', 'online']) {
          final school = mode == 'school';
          final online = mode == 'online';
          await tester.pumpWidget(
            KeyedSubtree(
              key: ValueKey('league-$mode-${brightness.name}'),
              child: _host(
                brightness: brightness,
                textScaler: const TextScaler.linear(2),
                child: LeagueScreen(
                  player: _player,
                  schoolMode: school,
                  mascotStyle: LearningPathMascotStyle.orbit,
                  classCompleted: school ? 1 : 0,
                  classTarget: school ? 3 : 0,
                  localWeeklyLeague: mode == 'local' ? _notStarted : null,
                  onLocalWeeklyLeagueSetupParticipantCountChanged:
                      mode == 'local' ? (_) {} : null,
                  onStartLocalWeeklyLeague: mode == 'local' ? (_) {} : null,
                  onOpenLanSocial: online ? () {} : null,
                ),
              ),
            ),
          );
          await tester.pump();

          expect(
            find.byKey(const ValueKey('game-hero-mascot')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('path-mascot-orbit')),
            findsOneWidget,
          );

          if (school) {
            expect(find.text('生徒の個人順位は表示しない'), findsOneWidget);
            expect(
              find.byKey(const ValueKey('local-weekly-league-panel')),
              findsNothing,
            );
          } else if (online) {
            final open = find.byKey(const ValueKey('league-open-lan-social'));
            expect(tester.getSize(open).height, greaterThanOrEqualTo(48));
            expect(find.textContaining('実在5〜8人'), findsOneWidget);
            expect(find.textContaining('接続前・現在の人数と順位は非表示'), findsOneWidget);
            expect(find.textContaining('観測級10までの10段階'), findsOneWidget);
            expect(find.byIcon(Icons.workspace_premium_outlined), findsNothing);
            expect(find.byIcon(Icons.emoji_events_outlined), findsNothing);
            expect(
              find.byKey(const ValueKey('local-weekly-league-panel')),
              findsNothing,
            );
          } else {
            final setup = find.byKey(
              const ValueKey('local-weekly-league-setup-open'),
            );
            await _reveal(tester, setup, const ValueKey('league-screen'));
            expect(tester.getSize(setup).height, greaterThanOrEqualTo(48));
            await tester.tap(setup);
            await tester.pumpAndSettle();
            for (final key in [
              'local-weekly-league-count-minus',
              'local-weekly-league-count-plus',
              'local-weekly-league-start',
            ]) {
              expect(
                tester.getSize(find.byKey(ValueKey(key))).height,
                greaterThanOrEqualTo(48),
              );
            }
            expect(
              find.textContaining('名前・account・回答・正誤は保存しません'),
              findsOneWidget,
            );
            await tester.tapAt(const Offset(4, 4));
            await tester.pumpAndSettle();
          }

          final rules = find.byKey(const ValueKey('league-rules-disclosure'));
          await _reveal(tester, rules, const ValueKey('league-screen'));
          expect(tester.getSize(rules).height, greaterThanOrEqualTo(48));
          await tester.tap(rules);
          await tester.pumpAndSettle();
          expect(find.text('共同観測のルールと保存範囲'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tapAt(const Offset(4, 4));
          await tester.pumpAndSettle();
        }
      }
      semantics.dispose();
    },
  );

  testWidgets('active localは320x568・文字200%・light/darkでもHero見出しとルールCTAを各1つにする', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        _host(
          brightness: brightness,
          textScaler: const TextScaler.linear(2),
          child: LeagueScreen(
            player: _player,
            schoolMode: false,
            localWeeklyLeague: _activeLocal,
            selectedLocalWeeklyLeagueParticipantId: 'opaque.local.1',
            onSelectLocalWeeklyLeagueParticipant: (_) {},
          ),
        ),
      );
      await tester.pump();

      final hero = find.byKey(const ValueKey('league-progress'));
      final heroHeading = find.descendant(
        of: hero,
        matching: find.text('観測級01の共同観測'),
      );
      expect(heroHeading, findsOneWidget);
      expect(
        tester
            .getSemantics(heroHeading)
            .getSemanticsData()
            .flagsCollection
            .isHeader,
        isTrue,
      );
      expect(
        find.text('端末手渡し共同観測'),
        findsNothing,
        reason: 'embedded panelの見出しは外側Heroと競合させない',
      );
      expect(
        find.bySemanticsLabel(RegExp('端末手渡し共同観測。実在する2人、観察2件')),
        findsOneWidget,
        reason: '見出しを省いてもactive状態の読み上げは維持する',
      );

      expect(
        find.byKey(const ValueKey('local-weekly-league-rules')),
        findsNothing,
        reason: 'embedded panelは内側のルールCTAを構築しない',
      );
      final rules = find.byKey(const ValueKey('league-rules-disclosure'));
      expect(rules, findsOneWidget);
      expect(find.text('ルールとプライバシー'), findsOneWidget);
      expect(find.text('計測ルールと保存範囲'), findsNothing);
      await _reveal(tester, rules, const ValueKey('league-screen'));
      expect(
        tester.getSize(rules).height,
        greaterThanOrEqualTo(GameTokens.minTouchTarget),
      );
      final rulesSemantics = tester.getSemantics(rules).getSemanticsData();
      expect(rulesSemantics.label, contains('ルールとプライバシー'));
      expect(rulesSemantics.flagsCollection.isButton, isTrue);
      expect(rulesSemantics.hasAction(SemanticsAction.tap), isTrue);

      await tester.tap(rules);
      await tester.pumpAndSettle();
      expect(find.text('共同観測のルールと保存範囲'), findsOneWidget);
      expect(find.text('同じ学習の周回は数えない'), findsOneWidget);
      expect(find.textContaining('氏名・account・回答・正誤は表示・保存しません'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
    }

    semantics.dispose();
  });

  testWidgets('Profileはマスコット・バッジ棚・quest boardを主役にし320dp/200%で溢れない', (
    tester,
  ) async {
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
          key: ValueKey('profile-${brightness.name}'),
          child: _host(
            brightness: brightness,
            textScaler: const TextScaler.linear(2),
            child: GameProfileScreen(
              player: _player,
              quests: _quests,
              schoolMode: false,
              explanationCount: 2,
              monthlyBadges: _badges,
              mascotStyle: LearningPathMascotStyle.orbit,
              onOpenSettings: () {},
              onOpenEconomy: () {},
              onOpenLanSocial: () {},
              onExitLocalMode: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      final hero = find.byKey(const ValueKey('game-profile-progress'));
      expect(find.byKey(const ValueKey('path-mascot-orbit')), findsOneWidget);
      expect(
        find.descendant(
          of: hero,
          matching: find.byKey(const ValueKey('game-profile-metric-ひらめき結晶')),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: hero,
          matching: find.byIcon(Icons.electric_bolt_rounded),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: hero, matching: find.byIcon(Icons.diamond_rounded)),
        findsNothing,
      );
      expect(
        tester.widget<Text>(find.text('連続観測')).style?.color,
        palette.inkMuted,
      );
      expect(tester.widget<Text>(find.text('4日')).style?.color, palette.ink);
      final settings = find.byKey(const ValueKey('game-profile-settings'));
      final economy = find.byKey(const ValueKey('game-profile-open-economy'));
      expect(tester.getSize(settings).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(economy).height, greaterThanOrEqualTo(48));

      final social = find.byKey(const ValueKey('game-profile-open-lan-social'));
      expect(
        find.descendant(of: hero, matching: social),
        findsNothing,
        reason: '通信モードは研究室の主CTAにしない',
      );
      await _reveal(tester, social, const ValueKey('game-profile-screen'));
      expect(tester.getSize(social).height, greaterThanOrEqualTo(48));
      expect(
        tester.getTopLeft(social).dy,
        greaterThan(
          tester
              .getTopLeft(
                find.byKey(const ValueKey('game-profile-quest-board')),
              )
              .dy,
        ),
      );
      expect(find.text('月間観測印'), findsOneWidget);
      expect(find.textContaining('観測バッジ'), findsNothing);
      expect(find.text('今日の観察予定'), findsOneWidget);
      expect(find.text('探究ノートを1件進める'), findsOneWidget);
      expect(find.textContaining('専用の回復練習1件'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    await tester.pumpWidget(
      _host(
        brightness: Brightness.dark,
        textScaler: const TextScaler.linear(2),
        child: GameProfileScreen(
          player: _player,
          quests: _quests,
          schoolMode: true,
          onOpenSettings: () {},
          onOpenClassroom: () {},
        ),
      ),
    );
    expect(find.text('今日の授業目標（この端末）'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('game-profile-monthly-badges')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('game-profile-open-lan-social')),
      findsNothing,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('game-profile-open-classroom')))
          .height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('700dp+は本文を720dpに抑えbadge棚を3列にする', (tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        child: GameProfileScreen(
          player: _player,
          quests: _quests,
          schoolMode: false,
          monthlyBadges: _badges,
          onOpenSettings: () {},
        ),
      ),
    );
    await tester.pump();

    final hero = find.byKey(const ValueKey('game-profile-progress'));
    expect(
      tester.getSize(hero).width,
      lessThanOrEqualTo(GameTokens.gamePageMaxWidth),
    );
    expect(tester.getTopLeft(hero).dx, closeTo(140, 1));
    final badge0 = find.byKey(const ValueKey('monthly-badge-badge.0'));
    final badge1 = find.byKey(const ValueKey('monthly-badge-badge.1'));
    final badge2 = find.byKey(const ValueKey('monthly-badge-badge.2'));
    expect(
      tester.getTopLeft(badge0).dy,
      closeTo(tester.getTopLeft(badge1).dy, 1),
    );
    expect(
      tester.getTopLeft(badge1).dy,
      closeTo(tester.getTopLeft(badge2).dy, 1),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _host(
        child: LeagueScreen(
          player: _player,
          schoolMode: false,
          onOpenLanSocial: () {},
        ),
      ),
    );
    final leagueHero = find.byKey(const ValueKey('league-lan-social-summary'));
    expect(
      tester.getSize(leagueHero).width,
      lessThanOrEqualTo(GameTokens.gamePageMaxWidth),
    );
    expect(tester.getTopLeft(leagueHero).dx, closeTo(140, 1));
  });

  testWidgets('arenaと研究室はtokenのsolid面だけを使う', (tester) async {
    await tester.pumpWidget(
      _host(
        brightness: Brightness.dark,
        child: LeagueScreen(
          player: _player,
          schoolMode: false,
          onOpenLanSocial: () {},
        ),
      ),
    );
    final leagueDecoration = _decoration(
      tester,
      find.byKey(const ValueKey('league-lan-social-summary')),
    );
    expect(leagueDecoration.color, GamePalette.dark.surfaceRaised);
    expect(leagueDecoration.border, isNotNull);
    expect(leagueDecoration.gradient, isNull);
    expect(leagueDecoration.boxShadow, isNull);

    await tester.pumpWidget(
      _host(
        brightness: Brightness.dark,
        child: GameProfileScreen(
          player: _player,
          quests: _quests,
          schoolMode: false,
          onOpenSettings: () {},
        ),
      ),
    );
    final profileDecoration = _decoration(
      tester,
      find.byKey(const ValueKey('game-profile-progress')),
    );
    expect(profileDecoration.color, GamePalette.dark.surfaceRaised);
    expect(profileDecoration.border, isNotNull);
    expect(profileDecoration.gradient, isNull);
    expect(profileDecoration.boxShadow, isNull);
  });
}
