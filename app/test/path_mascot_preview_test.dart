import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/learning/domain/learning_economy.dart';
import 'package:dekisugi/models/game_path.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/dekisugi_character_art.dart';
import 'package:dekisugi/widgets/learning_path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('マスコットは9反応を形とSemanticsで別々に伝える', (tester) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          body: Wrap(
            children: [
              for (final reaction in GameCharacterReaction.values)
                RepaintBoundary(
                  key: ValueKey<String>('mascot-reaction-${reaction.name}'),
                  child: PathMascotPreview(
                    reaction: reaction,
                    size: 96,
                    style: LearningPathMascotStyle.standard,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    for (final reaction in GameCharacterReaction.values) {
      expect(
        find.bySemanticsLabel(
          '${LearningPathMascotStyle.standard.label}、${reaction.semanticsLabel}',
        ),
        findsOneWidget,
      );
    }

    final art = tester
        .widgetList<DekisugiCharacterArt>(find.byType(DekisugiCharacterArt))
        .toList(growable: false);
    expect(art.map((item) => item.pose), const [
      DekisugiCharacterPose.idle,
      DekisugiCharacterPose.invite,
      DekisugiCharacterPose.listening,
      DekisugiCharacterPose.thinking,
      DekisugiCharacterPose.encourage,
      DekisugiCharacterPose.speaking,
      DekisugiCharacterPose.celebrate,
      DekisugiCharacterPose.outOfTime,
      DekisugiCharacterPose.retry,
    ]);
    expect(
      art.every(
        (item) => item.decoration == DekisugiCharacterDecoration.standard,
      ),
      isTrue,
    );

    final painters = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((paint) => paint.painter)
        .whereType<CustomPainter>()
        .toList(growable: false);
    expect(painters, hasLength(GameCharacterReaction.values.length));
    for (var index = 1; index < painters.length; index++) {
      expect(
        painters[index].shouldRepaint(painters[index - 1]),
        isTrue,
        reason: '感情が変わったら、手・目・持ち物・合図の形を再描画する',
      );
    }
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('economy styleは同じ本体へ装飾だけを足す', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.dark),
        home: Scaffold(
          body: Row(
            children: [
              for (final style in LearningPathMascotStyle.values)
                PathMascotPreview(
                  reaction: GameCharacterReaction.encourage,
                  size: 96,
                  style: style,
                ),
            ],
          ),
        ),
      ),
    );

    final art = tester
        .widgetList<DekisugiCharacterArt>(find.byType(DekisugiCharacterArt))
        .toList(growable: false);
    expect(art, hasLength(LearningPathMascotStyle.values.length));
    expect(
      art.map((item) => item.decoration),
      DekisugiCharacterDecoration.values,
    );
    for (final item in art.skip(1)) {
      expect(item.pose, art.first.pose);
      expect(item.body, art.first.body);
      expect(item.face, art.first.face);
      expect(item.accent, art.first.accent);
      expect(item.signal, art.first.signal);
    }
    expect(art.map((item) => item.ornament).toSet(), hasLength(3)); // auroraはorbitの色を使い回す
    expect(tester.takeException(), isNull);
  });
}
