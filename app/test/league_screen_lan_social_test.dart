import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/learning/domain/learning_progress.dart';
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
  leagueName: '研究主任',
  weeklyLeagueXp: 190,
  nextLeagueXp: 210,
);

final _legacyHistory = [
  LearningLeagueWeek(
    scope: LearningScope.personal,
    weekKey: '2026-08-03',
    xp: 190,
    previousTier: LearningLeagueTier.investigator,
    tier: LearningLeagueTier.researchLead,
    movement: LearningLeagueMovement.promoted,
    finalizedAt: DateTime.utc(2026, 8, 10),
  ),
];

Widget _host({
  required bool schoolMode,
  VoidCallback? onOpenLanSocial,
  Brightness brightness = Brightness.light,
  TextScaler textScaler = TextScaler.noScaling,
}) => MaterialApp(
  theme: buildAppTheme(brightness),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: child!,
  ),
  home: LeagueScreen(
    player: _player,
    schoolMode: schoolMode,
    history: _legacyHistory,
    onOpenLanSocial: onOpenLanSocial,
  ),
);

Finder get _scrollable => find
    .descendant(
      of: find.byKey(const ValueKey('league-screen')),
      matching: find.byType(Scrollable),
    )
    .first;

void main() {
  testWidgets('onlineは実参加者leagueだけを主役にし旧4段tierを混ぜない', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    var opened = 0;

    await tester.pumpWidget(
      _host(
        schoolMode: false,
        onOpenLanSocial: () => opened += 1,
        brightness: Brightness.dark,
        textScaler: const TextScaler.linear(2),
      ),
    );

    expect(find.text('実参加者リーグ'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('league-lan-social-summary')),
      findsOneWidget,
    );
    expect(find.textContaining('実在5〜8人'), findsOneWidget);
    expect(find.textContaining('ブロンズからダイヤモンドまでの10段'), findsWidgets);
    expect(find.byKey(const ValueKey('league-progress')), findsNothing);
    expect(find.textContaining('研究主任リーグ'), findsNothing);
    expect(find.text('これまでの週'), findsNothing);
    expect(find.text('オンライン順位は使わない'), findsNothing);

    final open = find.byKey(const ValueKey('league-open-lan-social'));
    await tester.scrollUntilVisible(open, 160, scrollable: _scrollable);
    await tester.pump();
    expect(tester.getSize(open).height, greaterThanOrEqualTo(48));
    await tester.tap(open);
    expect(opened, 1);
    final realParticipantsOnly = find.text('実参加者だけを匿名表示');
    await tester.scrollUntilVisible(
      realParticipantsOnly,
      160,
      scrollable: _scrollable,
    );
    expect(realParticipantsOnly, findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('local-onlyは実参加者10段tierを主表示し旧4段XP tierを外す', (tester) async {
    await tester.pumpWidget(_host(schoolMode: false));

    expect(find.text('実参加者・端末手渡し'), findsOneWidget);
    expect(find.text('ブロンズリーグ'), findsOneWidget);
    expect(find.textContaining('10段tier'), findsOneWidget);
    expect(find.textContaining('研究主任リーグ'), findsNothing);
    expect(find.byKey(const ValueKey('league-progress')), findsOneWidget);
    expect(find.text('これまでの週'), findsNothing);
    expect(
      find.byKey(const ValueKey('league-lan-social-summary')),
      findsNothing,
    );
  });

  testWidgets('schoolはcallbackを渡しても実参加者順位も個人tierも作らない', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      _host(schoolMode: true, onOpenLanSocial: () => opened += 1),
    );

    expect(find.text('授業の探究'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('league-lan-social-summary')),
      findsNothing,
    );
    expect(find.text('生徒の個人順位は表示しない'), findsOneWidget);
    expect(find.textContaining('研究主任リーグ'), findsNothing);
    expect(opened, 0);
  });
}
