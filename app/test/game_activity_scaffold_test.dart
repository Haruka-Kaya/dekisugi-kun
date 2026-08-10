import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/motion.dart';
import 'package:dekisugi/models/game_path.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/game_activity_scaffold.dart';
import 'package:flutter_test/flutter_test.dart';

const _initialStatus = GamePlayerStatus(
  streakDays: 12,
  streakFreezeRemaining: 1,
  gems: 84,
  hearts: 4,
);

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
              child: const Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('固定statusの下で、activity本文だけがスクロールします。'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byKey(const ValueKey('game-activity-scaffold')), findsOne);
        expect(find.byKey(const ValueKey('game-activity-status')), findsOne);
        expect(find.bySemanticsLabel('学習ハート、5個中4個'), findsOne);
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
        expect(find.bySemanticsLabel('学習ハート、5個中3個'), findsOne);
        expect(find.bySemanticsLabel('学習ハート、5個中4個'), findsNothing);

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
}
