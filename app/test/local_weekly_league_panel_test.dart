import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/learning/domain/learning_progress.dart';
import 'package:dekisugi/learning/services/local_weekly_league_projection.dart';
import 'package:dekisugi/widgets/local_weekly_league_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _week = '2026-08-10';

LearningLocalCoopRun _run(Set<String> participants, {bool completed = false}) =>
    LearningLocalCoopRun(
      runId: 'league.round.1',
      scope: LearningScope.personal,
      questInstanceId: 'local-coop:league.round.1',
      participantIds: participants,
      contributingParticipantIds: completed ? participants : const {},
      progress: completed ? participants.length : 0,
      target: participants.length,
      rewardGems: 0,
      startDay: _week,
      endDay: '2026-08-16',
      definitionVersion: 'local-weekly-league.v1',
      startedAt: DateTime.utc(2026, 8, 10, 1),
      completedAt: completed ? DateTime.utc(2026, 8, 10, 2) : null,
      rewardedAt: completed ? DateTime.utc(2026, 8, 10, 2) : null,
    );

LearningLocalCoopContribution _entry(String participantId, String eventId) =>
    LearningLocalCoopContribution(
      runId: 'league.round.1',
      participantId: participantId,
      eventId: eventId,
      scope: LearningScope.personal,
      learningDay: _week,
      meaningfulProgress: true,
    );

LocalWeeklyLeagueView _activeView(Set<String> participants) =>
    LocalWeeklyLeagueProjection.project(
      scope: LearningScope.personal,
      weekKey: _week,
      runs: [_run(participants)],
      contributions: [
        _entry(participants.elementAt(0), 'event.first'),
        _entry(participants.elementAt(1), 'event.second'),
      ],
    );

Widget _host(
  LocalWeeklyLeaguePanel panel, {
  TextScaler textScaler = TextScaler.noScaling,
}) => MaterialApp(
  theme: buildAppTheme(Brightness.light),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: child!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      key: const ValueKey('league-scroll'),
      child: panel,
    ),
  ),
);

void main() {
  testWidgets('未開始は2〜8人の実参加枠だけを作り、操作面は48dp以上', (tester) async {
    int? changedCount;
    int? startedCount;
    const view = LocalWeeklyLeagueView(
      availability: LocalWeeklyLeagueAvailability.notStarted,
      weekKey: _week,
      endDay: null,
      standings: [],
      activeRunId: null,
      integrityConflictCount: 0,
    );
    await tester.pumpWidget(
      _host(
        LocalWeeklyLeaguePanel(
          view: view,
          setupParticipantCount: 2,
          onSetupParticipantCountChanged: (value) => changedCount = value,
          onStart: (value) => startedCount = value,
        ),
      ),
    );

    expect(find.textContaining('架空の相手'), findsOneWidget);
    expect(
      find.textContaining('名前・account・回答・正誤は保存しません'),
      findsNothing,
      reason: '人数と保存範囲は開始時の二次開示にまとめる',
    );
    expect(find.textContaining('友達A'), findsNothing);
    final open = find.byKey(const ValueKey('local-weekly-league-setup-open'));
    expect(tester.getSize(open).height, greaterThanOrEqualTo(48));
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.textContaining('名前・account・回答・正誤は保存しません'), findsOneWidget);
    final minus = find.byKey(const ValueKey('local-weekly-league-count-minus'));
    final plus = find.byKey(const ValueKey('local-weekly-league-count-plus'));
    final start = find.byKey(const ValueKey('local-weekly-league-start'));
    expect(tester.getSize(minus), const Size(48, 48));
    expect(tester.getSize(plus), const Size(48, 48));
    expect(tester.getSize(start).height, greaterThanOrEqualTo(48));

    await tester.tap(minus);
    expect(changedCount, isNull, reason: '2人未満へは減らさない');
    await tester.tap(plus);
    expect(changedCount, 3);
    await tester.tap(start);
    expect(startedCount, 3);
  });

  testWidgets('同点は同率表示し、不透明IDを見せず選択callbackだけへ返す', (tester) async {
    const participants = {
      'opaque.participant.a',
      'opaque.participant.b',
      'opaque.participant.c',
    };
    final view = _activeView(participants);
    String? selected;
    await tester.pumpWidget(
      _host(
        LocalWeeklyLeaguePanel(
          view: view,
          selectedParticipantId: 'opaque.participant.a',
          onSelectParticipant: (value) => selected = value,
        ),
      ),
    );

    expect(find.text('同率1位'), findsNWidgets(2));
    expect(find.bySemanticsLabel(RegExp('この端末の観測者、同率1位、観察1件')), findsOneWidget);
    expect(find.textContaining('5人未満のため'), findsOneWidget);
    expect(find.textContaining('opaque.participant'), findsNothing);

    final secondId = view.standings
        .firstWhere((standing) => standing.slotNumber == 2)
        .participantId;
    final second = find.byKey(
      ValueKey('local-weekly-league-participant-$secondId'),
    );
    expect(tester.getSize(second).height, greaterThanOrEqualTo(48));
    await tester.tap(second);
    expect(selected, secondId);

    expect(find.textContaining('周回は0件'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('local-weekly-league-rules')));
    await tester.pumpAndSettle();
    expect(find.textContaining('周回は0件'), findsOneWidget);
    expect(find.textContaining('探究ノートと練習はいつでも'), findsOneWidget);
  });

  testWidgets('schoolLocalは順位・開始・参加枠選択を一切出さない', (tester) async {
    const view = LocalWeeklyLeagueView(
      availability: LocalWeeklyLeagueAvailability.schoolDisabled,
      weekKey: _week,
      endDay: null,
      standings: [],
      activeRunId: null,
      integrityConflictCount: 0,
    );
    await tester.pumpWidget(_host(const LocalWeeklyLeaguePanel(view: view)));

    expect(find.text('学校モードでは使いません'), findsOneWidget);
    expect(find.textContaining('生徒どうしの個人順位は作らず'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('local-weekly-league-start')),
      findsNothing,
    );
    expect(find.textContaining('1人目'), findsNothing);
  });

  testWidgets('320x568・文字200%・8人でもoverflowせず全順位を読める', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    final participants = {
      for (var index = 1; index <= 8; index += 1) 'participant.$index',
    };
    final view = _activeView(participants);
    await tester.pumpWidget(
      _host(
        LocalWeeklyLeaguePanel(view: view, onSelectParticipant: (_) {}),
        textScaler: const TextScaler.linear(2),
      ),
    );

    expect(
      find.bySemanticsLabel(RegExp('端末手渡し共同観測。実在する8人、観察2件')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('8人目、同率3位、観察0件')), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
