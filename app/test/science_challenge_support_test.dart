import 'dart:math' as math;

import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/game_tokens.dart';
import 'package:dekisugi/learning/domain/learning_economy.dart';
import 'package:dekisugi/models/game_path.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/dekisugi_character_art.dart';
import 'package:dekisugi/widgets/learning_path.dart';
import 'package:dekisugi/widgets/science_challenge_support.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color foreground, Color background) {
  final lighter = math.max(
    foreground.computeLuminance(),
    background.computeLuminance(),
  );
  final darker = math.min(
    foreground.computeLuminance(),
    background.computeLuminance(),
  );
  return (lighter + 0.05) / (darker + 0.05);
}

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

  testWidgets('72px枠をmascot 52pxとactivity icon 20pxの非重複領域に分ける', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      for (final style in LearningPathMascotStyle.values) {
        for (final reaction in GameCharacterReaction.values) {
          await tester.pumpWidget(
            MaterialApp(
              theme: buildAppTheme(Brightness.light),
              home: Scaffold(
                body: Center(
                  child: ScienceActivityMascotBadge(
                    icon: Icons.science_outlined,
                    accent: GamePalette.light.pathActive,
                    onAccent: GamePalette.light.onPathActive,
                    mascotStyle: style,
                    mascotReaction: reaction,
                  ),
                ),
              ),
            ),
          );

          final frame = find.byKey(
            const ValueKey('science-activity-mascot-badge'),
          );
          final mascotRegion = find.byKey(
            const ValueKey('science-activity-mascot-region'),
          );
          final mascotSurface = find.byKey(
            const ValueKey('science-activity-mascot-surface'),
          );
          final activityIcon = find.byKey(
            const ValueKey('science-activity-kind-icon'),
          );
          expect(tester.getSize(frame), const Size.square(72));
          expect(tester.getSize(mascotRegion), const Size.square(52));
          expect(tester.getRect(mascotSurface), tester.getRect(mascotRegion));
          expect(tester.getSize(activityIcon), const Size.square(20));
          expect(
            tester.getRect(mascotRegion).overlaps(tester.getRect(activityIcon)),
            isFalse,
            reason: '${style.name}/${reaction.name}の形とactivity iconが重なった',
          );

          final art = tester.widget<DekisugiCharacterArt>(
            find.byType(DekisugiCharacterArt),
          );
          expect(art.size, 52);
          expect(art.decoration, switch (style) {
            LearningPathMascotStyle.standard =>
              DekisugiCharacterDecoration.standard,
            LearningPathMascotStyle.orbit => DekisugiCharacterDecoration.orbit,
            LearningPathMascotStyle.nova => DekisugiCharacterDecoration.nova,
          });
          expect(art.pose, switch (reaction) {
            GameCharacterReaction.none => DekisugiCharacterPose.idle,
            GameCharacterReaction.invite => DekisugiCharacterPose.invite,
            GameCharacterReaction.listening => DekisugiCharacterPose.listening,
            GameCharacterReaction.thinking => DekisugiCharacterPose.thinking,
            GameCharacterReaction.encourage => DekisugiCharacterPose.encourage,
            GameCharacterReaction.speaking => DekisugiCharacterPose.speaking,
            GameCharacterReaction.celebrate => DekisugiCharacterPose.celebrate,
            GameCharacterReaction.outOfTime => DekisugiCharacterPose.outOfTime,
            GameCharacterReaction.retry => DekisugiCharacterPose.retry,
          });
          expect(
            find.bySemanticsLabel('${style.label}、${reaction.semanticsLabel}'),
            findsNothing,
            reason: '外側のまとめSemanticsと二重に読ませない',
          );
          expect(
            find.bySemanticsLabel('デキすぎ君。${reaction.semanticsLabel}'),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        }
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('Lab Briefは中立面・4dp罫線・矩形の観察印で情報を分ける', (tester) async {
    for (final brightness in Brightness.values) {
      final theme = buildAppTheme(brightness);
      final palette = theme.extension<GamePalette>()!;
      final character = theme.extension<AppColors>()!;
      final accents = <String, (Color, Color)>{
        'pathActive': (palette.pathActive, palette.onPathActive),
        'pathComplete': (palette.pathComplete, palette.onPathComplete),
        'pathReview': (palette.pathReview, palette.onPathReview),
        'pathLocked': (palette.pathLocked, palette.onPathLocked),
        'story': (palette.story, palette.onStory),
        'legendary': (palette.legendary, palette.onLegendary),
        'surfaceRaised': (palette.surfaceRaised, palette.ink),
      };

      for (final entry in accents.entries) {
        final (accent, onAccent) = entry.value;
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey('${brightness.name}-${entry.key}'),
            theme: theme,
            darkTheme: theme,
            themeMode: brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            home: Scaffold(
              body: ScienceChallengeHeader(
                eyebrow: '観察 1 / 2',
                title: '条件を見つける',
                body: '標本を比べます。',
                icon: Icons.science_outlined,
                accent: accent,
                onAccent: onAccent,
              ),
            ),
          ),
        );

        final art = tester.widget<DekisugiCharacterArt>(
          find.byType(DekisugiCharacterArt),
        );
        final surface = tester.widget<Container>(
          find.byKey(const ValueKey('science-activity-mascot-surface')),
        );
        final decoration = surface.decoration! as BoxDecoration;
        final brief = tester.widget<Container>(
          find.byKey(const ValueKey('science-challenge-lab-brief')),
        );
        final briefDecoration = brief.decoration! as BoxDecoration;
        final accentRule = tester.widget<ColoredBox>(
          find.byKey(const ValueKey('science-challenge-accent-rule')),
        );
        expect(art.body, character.charBody);
        expect(briefDecoration.color, palette.benchRaised);
        expect(briefDecoration.gradient, isNull);
        expect(briefDecoration.boxShadow, isNull);
        expect(accentRule.color, accent);
        expect(
          tester
              .getSize(
                find.byKey(const ValueKey('science-challenge-accent-rule')),
              )
              .width,
          GameTokens.accentRuleWidth,
        );
        expect(decoration.color, palette.bench);
        expect(decoration.gradient, isNull);
        expect(decoration.boxShadow, isNull);
        expect(
          _contrast(art.body, decoration.color!),
          greaterThanOrEqualTo(3),
          reason: '${brightness.name}/${entry.key}/charBody/backing',
        );
        expect(decoration.border, isA<Border>());
        final border = decoration.border! as Border;
        expect(border.top.color, palette.inkMuted);
        expect(border.top.width, GameTokens.strongBorderWidth);
        expect(
          _contrast(border.top.color, decoration.color!),
          greaterThanOrEqualTo(3),
          reason: '${brightness.name}/${entry.key}/observation stamp border',
        );
        final kindIcon = tester.widget<Container>(
          find.byKey(const ValueKey('science-activity-kind-icon')),
        );
        final kindDecoration = kindIcon.decoration! as BoxDecoration;
        expect(kindDecoration.color, accent);
        expect(kindDecoration.shape, BoxShape.rectangle);
        expect(
          _contrast(onAccent, accent),
          greaterThanOrEqualTo(4.5),
          reason: '${brightness.name}/${entry.key}/activity kind icon',
        );
        expect(tester.takeException(), isNull);
      }
    }
  });
}
