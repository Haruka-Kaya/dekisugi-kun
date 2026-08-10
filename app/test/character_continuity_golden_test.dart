import 'dart:typed_data';

import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/motion.dart';
import 'package:dekisugi/learning/domain/learning_economy.dart';
import 'package:dekisugi/models/game_path.dart';
import 'package:dekisugi/services/live_session.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/character.dart';
import 'package:dekisugi/widgets/dekisugi_character_art.dart';
import 'package:dekisugi/widgets/learning_path.dart';
import 'package:flutter_test/flutter_test.dart';

/// macOS と Linux の software rasterizer で、ごく少数の anti-alias pixel だけが
/// 異なる。構図や色の変化を通さないよう、1280x640 のうち最大32px相当だけを
/// 許可する。pose / decoration / palette は下の構造assertでも別に固定する。
class _RasterStableGoldenComparator extends LocalFileComparator {
  _RasterStableGoldenComparator(super.testFile);

  static const _maxDiffFraction = 0.00004;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= _maxDiffFraction) {
      result.dispose();
      return true;
    }

    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

Widget _sheet(Brightness brightness) => MaterialApp(
  theme: buildAppTheme(brightness),
  debugShowCheckedModeBanner: false,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: ReduceMotionScope(child: child!),
  ),
  home: Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Character(state: LiveState.idle, size: 88),
              SizedBox(width: 8),
              PathMascotPreview(
                reaction: GameCharacterReaction.none,
                size: 88,
                style: LearningPathMascotStyle.standard,
              ),
              SizedBox(width: 20),
              Character(state: LiveState.thinking, size: 88),
              SizedBox(width: 8),
              PathMascotPreview(
                reaction: GameCharacterReaction.thinking,
                size: 88,
                style: LearningPathMascotStyle.standard,
              ),
              SizedBox(width: 20),
              Character(state: LiveState.done, size: 88),
              SizedBox(width: 8),
              PathMascotPreview(
                reaction: GameCharacterReaction.celebrate,
                size: 88,
                style: LearningPathMascotStyle.standard,
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PathMascotPreview(
                reaction: GameCharacterReaction.encourage,
                size: 112,
                style: LearningPathMascotStyle.standard,
              ),
              SizedBox(width: 20),
              PathMascotPreview(
                reaction: GameCharacterReaction.encourage,
                size: 112,
                style: LearningPathMascotStyle.orbit,
              ),
              SizedBox(width: 20),
              PathMascotPreview(
                reaction: GameCharacterReaction.encourage,
                size: 112,
                style: LearningPathMascotStyle.nova,
              ),
            ],
          ),
        ],
      ),
    ),
  ),
);

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('LiveとPathの同一pose・3装飾 — ${brightness.name}', (tester) async {
      final previousComparator = goldenFileComparator;
      goldenFileComparator = _RasterStableGoldenComparator(
        Uri.parse('test/character_continuity_golden_test.dart'),
      );
      addTearDown(() => goldenFileComparator = previousComparator);

      tester.view.physicalSize = const Size(1280, 640);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_sheet(brightness));
      await tester.pump();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/character_continuity_${brightness.name}.png',
        ),
      );

      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final pair in const <(LiveState, GameCharacterReaction)>[
    (LiveState.idle, GameCharacterReaction.none),
    (LiveState.thinking, GameCharacterReaction.thinking),
    (LiveState.done, GameCharacterReaction.celebrate),
  ]) {
    testWidgets('${pair.$1.name}はLiveとPathで同じ描画入力を使う', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: ReduceMotionScope(child: child!),
          ),
          home: Scaffold(
            body: Row(
              children: [
                Character(state: pair.$1, size: 96),
                PathMascotPreview(
                  reaction: pair.$2,
                  size: 96,
                  style: LearningPathMascotStyle.standard,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      final art = tester
          .widgetList<DekisugiCharacterArt>(find.byType(DekisugiCharacterArt))
          .toList(growable: false);
      expect(art, hasLength(2));
      expect(art[0].pose, art[1].pose);
      expect(art[0].decoration, art[1].decoration);
      expect(art[0].body, art[1].body);
      expect(art[0].face, art[1].face);
      expect(art[0].accent, art[1].accent);
      expect(art[0].signal, art[1].signal);
      expect(art[0].eyeOpen, art[1].eyeOpen);
      expect(art[0].thinkPhase, art[1].thinkPhase);
      expect(art[0].voiceBounce, art[1].voiceBounce);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
    });
  }
}
