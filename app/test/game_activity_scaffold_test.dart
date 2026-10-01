import 'dart:ui' show SemanticsAction;

import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/game_tokens.dart';
import 'package:dekisugi/config/motion.dart';
import 'package:dekisugi/learning/domain/learning_economy.dart';
import 'package:dekisugi/models/game_path.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/dekisugi_character_art.dart';
import 'package:dekisugi/widgets/game_activity_scaffold.dart';
import 'package:dekisugi/widgets/science_challenge_support.dart';
import 'package:flutter_test/flutter_test.dart';

const _initialStatus = GamePlayerStatus(
  streakDays: 12,
  streakFreezeRemaining: 1,
  gems: 84,
  hearts: 4,
);

class _ScopedActivityProbe extends StatelessWidget {
  const _ScopedActivityProbe();

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Scaffold(
      appBar: GameActivityScaffold.hasSharedChrome(context)
          ? null
          : AppBar(title: const Text('子画面のAppBar')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ScienceActivityMascotBadge(
                icon: Icons.science_outlined,
                accent: colors.pathActive,
                onAccent: colors.onPathActive,
              ),
              const Text('fixed statusの下で、activity本文だけがスクロールします。'),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      '320x568・文字200%・Reduce Motionの${brightness.name}でstatus更新と48dp操作面を保つ',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final semantics = tester.ensureSemantics();
        final status = GameActivityStatusController(_initialStatus);
        addTearDown(status.dispose);
        var exits = 0;

        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: ReduceMotionScope(child: child!),
            ),
            home: GameActivityScaffold(
              statusListenable: status,
              schoolMode: false,
              onExit: () => exits += 1,
              mascotStyle: LearningPathMascotStyle.orbit,
              child: const _ScopedActivityProbe(),
            ),
          ),
        );
        await tester.pump();

        expect(find.byKey(const ValueKey('game-activity-scaffold')), findsOne);
        expect(
          find.byKey(const ValueKey('game-activity-top-chrome')),
          findsOne,
        );
        expect(find.byKey(const ValueKey('game-activity-status')), findsOne);
        expect(find.byKey(const ValueKey('player-status-bar')), findsOne);
        expect(find.byType(AppBar), findsNothing);
        expect(
          tester
              .widget<DekisugiCharacterArt>(find.byType(DekisugiCharacterArt))
              .decoration,
          DekisugiCharacterDecoration.orbit,
        );
        final exitSemantics = tester.getSemantics(
          find.bySemanticsLabel('前の画面へ戻る'),
        );
        expect(
          exitSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
        );
        expect(find.bySemanticsLabel('試行余力、5枠中4枠'), findsOne);
        final exitSize = tester.getSize(
          find.byKey(const ValueKey('game-activity-exit')),
        );
        expect(exitSize.width, greaterThanOrEqualTo(48));
        expect(exitSize.height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);

        status.replace(
          const GamePlayerStatus(
            streakDays: 12,
            streakFreezeRemaining: 1,
            gems: 84,
            hearts: 3,
          ),
        );
        await tester.pump();
        expect(find.bySemanticsLabel('試行余力、5枠中3枠'), findsOne);
        expect(find.bySemanticsLabel('試行余力、5枠中4枠'), findsNothing);

        await tester.tap(find.byKey(const ValueKey('game-activity-exit')));
        expect(exits, 1);
        semantics.dispose();
      },
    );
  }

  testWidgets('1024dpでは固定statusを可読幅600dp以内に留める', (tester) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final status = GameActivityStatusController(_initialStatus);
    addTearDown(status.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: GameActivityScaffold(
          statusListenable: status,
          schoolMode: false,
          child: const Scaffold(body: Center(child: Text('WIDE ACTIVITY'))),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.getSize(find.byKey(const ValueKey('game-activity-status'))).width,
      lessThanOrEqualTo(600),
    );
    expect(find.text('WIDE ACTIVITY'), findsOne);
    expect(tester.takeException(), isNull);
  });

  testWidgets('共有chrome外では課題自身のAppBarを保つ', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const _ScopedActivityProbe(),
      ),
    );

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('子画面のAppBar'), findsOneWidget);
    expect(
      tester
          .widget<DekisugiCharacterArt>(find.byType(DekisugiCharacterArt))
          .decoration,
      DekisugiCharacterDecoration.standard,
    );
  });
}
