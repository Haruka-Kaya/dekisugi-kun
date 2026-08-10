import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/learning/domain/learning_economy.dart';
import 'package:dekisugi/models/game_path.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/learning_path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('マスコットは5反応を形とSemanticsで別々に伝える', (tester) async {
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
        reason: '感情が変わったら、手・口・目・合図の形を再描画する',
      );
    }
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
