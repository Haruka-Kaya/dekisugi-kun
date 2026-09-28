import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/learning/domain/learning_monthly_badge.dart';
import 'package:dekisugi/models/game_hub.dart';
import 'package:dekisugi/screens/game_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _player = PlayerSummaryView(
  xp: 30,
  gems: 8,
  streakDays: 3,
  freezeCount: 1,
  challengeHearts: 4,
  maxChallengeHearts: 5,
  completedNodes: 2,
  totalNodes: 8,
  leagueName: '観察者',
  weeklyLeagueXp: 30,
  nextLeagueXp: 60,
);

final _badge = LearningMonthlyBadgeAward(
  badgeId: 'badge.monthly.2026-08.twelve-actions',
  sourceQuestInstanceId: 'monthly:2026-08:twelve-actions',
  learningMonth: '2026-08',
  title: '2026年8月 観測バッジ',
  description: '意味のある学習を12件終えた月の記録です。',
  style: LearningMonthlyBadgeStyle.constellation,
  unlockedAt: DateTime.utc(2026, 8, 20),
);

Widget _host({
  required bool schoolMode,
  Brightness brightness = Brightness.dark,
  bool plusSupporter = false,
}) => MaterialApp(
  theme: buildAppTheme(brightness),
  home: GameProfileScreen(
    player: _player,
    quests: const [],
    schoolMode: schoolMode,
    monthlyBadges: [_badge],
    plusSupporter: plusSupporter,
    onOpenSettings: () {},
  ),
);

void main() {
  testWidgets('personal Profileは獲得済み月間バッジを購入品と分けて表示する', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            textScaler: TextScaler.linear(2),
          ),
          child: _host(schoolMode: false),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(
          const ValueKey('monthly-badge-badge.monthly.2026-08.twelve-actions'),
        ),
        240,
      );

      expect(find.text('月間バッジ'), findsOneWidget);
      expect(find.textContaining('結晶では購入できません'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(r'2026年8月 観測バッジ。獲得済み')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('schoolLocalは個人badgeデータを渡されても表示しない', (tester) async {
    await tester.pumpWidget(_host(schoolMode: true));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('game-profile-monthly-badges')),
      findsNothing,
    );
    expect(find.text('2026年8月 観測バッジ'), findsNothing);
  });

  testWidgets('Plusサポーターは個人scopeの研究室にだけ印が出る', (tester) async {
    await tester.pumpWidget(_host(schoolMode: false, plusSupporter: true));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('game-profile-metric-Plus サポーター')),
      findsOneWidget,
    );
    expect(find.text('応援中'), findsOneWidget);
  });

  testWidgets('schoolLocalはplusSupporterフラグがあっても印を出さない', (
    tester,
  ) async {
    await tester.pumpWidget(_host(schoolMode: true, plusSupporter: true));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('game-profile-metric-Plus サポーター')),
      findsNothing,
    );
  });
}
