import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/game_tokens.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/learning_path.dart';
import 'package:dekisugi/widgets/science_challenge_support.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Challenge headerは320dp・200%でもmascotと行動を一体表示する', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(GameTokens.spaceLg),
            child: ScienceChallengeHeader(
              eyebrow: 'MISSION 1/2',
              title: '条件を見つける',
              body: '音声を聞いて、変えた条件とそろえた条件を判断します。',
              icon: Icons.headphones_rounded,
              accent: GamePalette.dark.pathReview,
              onAccent: GamePalette.dark.onPathReview,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(PathMascotPreview), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('MISSION 1/2.*条件を見つける.*音声を聞いて')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('デキすぎ君.*学習を応援しています')), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
