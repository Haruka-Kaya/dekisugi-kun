import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/learning/domain/learning_progress.dart';
import 'package:dekisugi/learning/services/local_weekly_league_projection.dart';
import 'package:dekisugi/models/game_hub.dart';
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

const _notStarted = LocalWeeklyLeagueView(
  availability: LocalWeeklyLeagueAvailability.notStarted,
  weekKey: '2026-08-10',
  endDay: null,
  standings: [],
  activeRunId: null,
  integrityConflictCount: 0,
);

LearningLocalCoopRun _run(
  Set<String> participantIds, {
  bool completed = false,
}) => LearningLocalCoopRun(
  runId: 'weekly-league.round.1',
  scope: LearningScope.personal,
  questInstanceId: 'local-coop:weekly-league.round.1',
  participantIds: participantIds,
  contributingParticipantIds: completed ? participantIds : const {},
  progress: completed ? participantIds.length : 0,
  target: participantIds.length,
  rewardGems: 0,
  startDay: '2026-08-10',
  endDay: '2026-08-16',
  definitionVersion: 'local-weekly-league.v1',
  startedAt: DateTime.utc(2026, 8, 10, 1),
  completedAt: completed ? DateTime.utc(2026, 8, 10, 2) : null,
  rewardedAt: completed ? DateTime.utc(2026, 8, 10, 2) : null,
);

LearningLocalCoopContribution _entry(String participantId, String eventId) =>
    LearningLocalCoopContribution(
      runId: 'weekly-league.round.1',
      participantId: participantId,
      eventId: eventId,
      scope: LearningScope.personal,
      learningDay: '2026-08-10',
      meaningfulProgress: true,
    );

LocalWeeklyLeagueView _active(
  Set<String> participantIds, {
  bool completed = false,
}) => LocalWeeklyLeagueProjection.project(
  scope: LearningScope.personal,
  weekKey: '2026-08-10',
  runs: [_run(participantIds, completed: completed)],
  contributions: [
    _entry(participantIds.elementAt(0), 'event.first'),
    _entry(participantIds.elementAt(1), 'event.second'),
  ],
);

Widget _host({
  required LocalWeeklyLeagueView? view,
  bool schoolMode = false,
  int setupCount = 2,
  ValueChanged<int>? onCountChanged,
  ValueChanged<int>? onStart,
  String? selected,
  ValueChanged<String>? onSelect,
  VoidCallback? onNextRound,
  TextScaler textScaler = TextScaler.noScaling,
}) => MaterialApp(
  theme: buildAppTheme(Brightness.light),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: child!,
  ),
  home: Scaffold(
    body: LeagueScreen(
      player: _player,
      schoolMode: schoolMode,
      localWeeklyLeague: view,
      localWeeklyLeagueSetupParticipantCount: setupCount,
      onLocalWeeklyLeagueSetupParticipantCountChanged: onCountChanged,
      onStartLocalWeeklyLeague: onStart,
      selectedLocalWeeklyLeagueParticipantId: selected,
      onSelectLocalWeeklyLeagueParticipant: onSelect,
      onStartNextLocalWeeklyLeagueRound: onNextRound,
    ),
  ),
);

Finder get _leagueScrollable => find
    .descendant(
      of: find.byKey(const ValueKey('league-screen')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _show(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 180, scrollable: _leagueScrollable);
  await tester.pump();
}

void main() {
  testWidgets('personalは10段tierの下に未開始panelを置き、設定callbackを透過する', (tester) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    int? changedCount;
    int? startedCount;
    await tester.pumpWidget(
      _host(
        view: _notStarted,
        setupCount: 3,
        onCountChanged: (value) => changedCount = value,
        onStart: (value) => startedCount = value,
      ),
    );

    final heading = find.byKey(const ValueKey('league-local-tier-rule'));
    final selfTier = find.byKey(const ValueKey('league-progress'));
    final participantPanel = find.byKey(
      const ValueKey('local-weekly-league-panel'),
    );
    expect(heading, findsOneWidget);
    expect(find.text('ブロンズリーグ'), findsOneWidget);
    expect(find.textContaining('彗星リーグ'), findsNothing);
    expect(find.textContaining('120 / 500'), findsNothing);
    expect(selfTier, findsOneWidget);
    expect(participantPanel, findsOneWidget);
    expect(
      find.descendant(of: selfTier, matching: heading),
      findsOneWidget,
      reason: '10段tierと参加状態を1つのarena heroにまとめる',
    );
    expect(
      find.descendant(of: selfTier, matching: participantPanel),
      findsOneWidget,
    );

    final open = find.byKey(const ValueKey('local-weekly-league-setup-open'));
    await _show(tester, open);
    await tester.tap(open);
    await tester.pumpAndSettle();
    final plus = find.byKey(const ValueKey('local-weekly-league-count-plus'));
    final start = find.byKey(const ValueKey('local-weekly-league-start'));
    await tester.tap(plus);
    expect(changedCount, 4);
    await tester.tap(start);
    expect(startedCount, 4);
  });

  testWidgets('activeはparticipant選択と次round作成callbackをそのまま返す', (tester) async {
    const participants = {'opaque.a', 'opaque.b'};
    final active = _active(participants);
    String? selected;
    var nextRound = 0;
    await tester.pumpWidget(
      _host(
        view: active,
        onSelect: (value) => selected = value,
        onNextRound: () => nextRound += 1,
      ),
    );

    final secondId = active.standings
        .firstWhere((standing) => standing.slotNumber == 2)
        .participantId;
    final second = find.byKey(
      ValueKey('local-weekly-league-participant-$secondId'),
    );
    await _show(tester, second);
    await tester.tap(second);
    expect(selected, secondId);
    expect(find.textContaining('opaque.'), findsNothing);

    await tester.pumpWidget(
      _host(
        view: _active(participants, completed: true),
        onSelect: (value) => selected = value,
        onNextRound: () => nextRound += 1,
      ),
    );
    final next = find.byKey(const ValueKey('local-weekly-league-next-round'));
    await _show(tester, next);
    await tester.tap(next);
    expect(nextRound, 1);
  });

  testWidgets('schoolはviewとcallbackが渡っても個人順位panelを構築しない', (tester) async {
    var callbackCount = 0;
    await tester.pumpWidget(
      _host(
        view: _notStarted,
        schoolMode: true,
        onCountChanged: (_) => callbackCount += 1,
        onStart: (_) => callbackCount += 1,
        onSelect: (_) => callbackCount += 1,
        onNextRound: () => callbackCount += 1,
      ),
    );

    expect(
      find.byKey(const ValueKey('local-weekly-league-panel')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('league-local-tier-rule')), findsNothing);
    expect(find.text('生徒の個人順位は表示しない'), findsOneWidget);
    expect(callbackCount, 0);
  });

  testWidgets('320x568・文字200%で8人panelまでscrollしてもoverflowしない', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    final participants = {
      for (var index = 1; index <= 8; index += 1) 'opaque.$index',
    };
    await tester.pumpWidget(
      _host(
        view: _active(participants),
        onSelect: (_) {},
        textScaler: const TextScaler.linear(2),
      ),
    );

    final eighth = find.bySemanticsLabel(RegExp('8人目、同率3位、意味のある学習0件'));
    await _show(tester, eighth);
    expect(eighth, findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
