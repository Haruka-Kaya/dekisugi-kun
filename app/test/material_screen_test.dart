import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/models/unit.dart';
import 'package:dekisugi/screens/material_screen.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:flutter_test/flutter_test.dart';

Section section(String key, {int paragraphs = 2, String? title}) => Section(
      conceptKey: key,
      title: title ?? '$key の話',
      body: [for (var i = 0; i < paragraphs; i++) '$key の段落$i。' * 12],
      tryIt: '$key を手を動かして確かめる。',
    );

UnitDetail unit({List<Section>? sections}) => UnitDetail(
      summary: const UnitSummary(
        id: 'force-motion',
        title: '力と運動',
        brief: 'ざっくりした紹介。',
        concepts: [(key: 'fall', label: '落下の速さ')],
        sectionCount: 2,
      ),
      sections: sections ?? [section('fall'), section('inertia')],
    );

Widget wrap(Widget child) => MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: child,
    );

void main() {
  group('教材を読む画面', () {
    testWidgets('このあと説明することを先に伝える（C1）', (tester) async {
      await tester.pumpWidget(wrap(MaterialScreen(unit: unit(), onDone: () {})));
      expect(find.textContaining('説明してもらいます'), findsOneWidget);
      // **会話中に見られないことを先に言う。** 不意に消えると裏切りになる
      expect(find.textContaining('見られません'), findsOneWidget);
    });

    testWidgets('読み終わるまで進めない', (tester) async {
      // 読まずに会話へ入ると「説明できない」だけの体験になり、
      // 誤概念を訂正できなくても、習っていないからなのか区別がつかない
      await tester.pumpWidget(wrap(MaterialScreen(unit: unit(), onDone: () {})));
      await tester.pump();

      final button = find.widgetWithText(FilledButton, 'デキすぎ君に教える');
      expect(button, findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(find.textContaining('最後まで読むと'), findsOneWidget);
    });

    testWidgets('最後まで送ると進める', (tester) async {
      var done = false;
      await tester
          .pumpWidget(wrap(MaterialScreen(unit: unit(), onDone: () => done = true)));
      await tester.pump();

      await tester.drag(find.byType(ListView), const Offset(0, -4000));
      await tester.pumpAndSettle();

      final button = find.widgetWithText(FilledButton, 'デキすぎ君に教える');
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      await tester.tap(button);
      expect(done, isTrue);
    });

    testWidgets('1画面に収まるときも進める', (tester) async {
      // スクロールが起きない短い教材で、永久に押せなくならないこと
      await tester.pumpWidget(wrap(MaterialScreen(
        unit: unit(sections: [section('fall', paragraphs: 1)]),
        onDone: () {},
      )));
      await tester.pumpAndSettle();

      final button = find.widgetWithText(FilledButton, 'デキすぎ君に教える');
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    });

    testWidgets('やってみるを出す', (tester) async {
      await tester.pumpWidget(wrap(MaterialScreen(unit: unit(), onDone: () {})));
      expect(find.text('やってみる'), findsWidgets);
    });
  });

  group('復習から開いたとき', () {
    testWidgets('その節だけを出す', (tester) async {
      await tester.pumpWidget(wrap(MaterialScreen(
        unit: unit(),
        focusConceptKey: 'inertia',
        onDone: () {},
      )));
      await tester.pump();

      expect(find.text('inertia の話'), findsOneWidget);
      expect(find.text('fall の話'), findsNothing);
    });

    testWidgets('会話へ進ませない（読み直しに来ただけ）', (tester) async {
      await tester.pumpWidget(wrap(MaterialScreen(
        unit: unit(),
        focusConceptKey: 'inertia',
        onDone: () {},
      )));
      await tester.pump();

      expect(find.text('デキすぎ君に教える'), findsNothing);
      expect(find.text('もどる'), findsOneWidget);
    });

    testWidgets('節が無ければ単元まるごと出す', (tester) async {
      await tester.pumpWidget(wrap(MaterialScreen(
        unit: unit(),
        focusConceptKey: 'nope',
        onDone: () {},
      )));
      await tester.pump();
      expect(find.text('fall の話'), findsOneWidget);
    });
  });
}
