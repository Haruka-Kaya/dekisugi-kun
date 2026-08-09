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

Widget wrap(Widget child, {double textScale = 1}) => MaterialApp(
  theme: buildAppTheme(Brightness.light),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: child,
);

void main() {
  group('教材を読む画面', () {
    testWidgets('1つの節だけ開いても、会話へ進める', (tester) async {
      // **ホームの「きょうの1件」がここを通る。**
      // 「節を絞る」と「復習だから会話へ進まない」を同じフラグで
      // 兼ねていたせいで、主 CTA が行き止まりになっていた（実機で発覚）
      var done = false;
      await tester.pumpWidget(
        wrap(
          MaterialScreen(
            unit: unit(),
            focusConceptKey: 'fall',
            onDone: () => done = true,
          ),
        ),
      );
      expect(find.text('もどる'), findsNothing, reason: '行き止まりになっている');

      // 最後まで読んでから進む
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      final cta = find.byType(FilledButton);
      expect(cta, findsOneWidget);
      await tester.tap(cta);
      expect(done, isTrue, reason: '会話へ進めない');
    });

    testWidgets('復習からの読み直しは会話へ進まない', (tester) async {
      await tester.pumpWidget(
        wrap(
          MaterialScreen(
            unit: unit(),
            focusConceptKey: 'fall',
            review: true,
            onDone: () {},
          ),
        ),
      );
      expect(find.text('もどる'), findsOneWidget);
    });

    testWidgets('このあと説明することを先に伝える（C1）', (tester) async {
      await tester.pumpWidget(
        wrap(MaterialScreen(unit: unit(), onDone: () {})),
      );
      expect(find.textContaining('説明してもらいます'), findsOneWidget);
      // **会話中に見られないことを先に言う。** 不意に消えると裏切りになる
      expect(find.textContaining('見られません'), findsOneWidget);
    });

    testWidgets('読み終わるまで進めない', (tester) async {
      // 読まずに会話へ入ると「説明できない」だけの体験になり、
      // 誤概念を訂正できなくても、習っていないからなのか区別がつかない
      await tester.pumpWidget(
        wrap(MaterialScreen(unit: unit(), onDone: () {})),
      );
      await tester.pump();

      final button = find.widgetWithText(FilledButton, 'デキすぎ君に教える');
      expect(button, findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(find.textContaining('最後まで読むと'), findsOneWidget);
    });

    testWidgets('最後まで送ると進める', (tester) async {
      var done = false;
      await tester.pumpWidget(
        wrap(MaterialScreen(unit: unit(), onDone: () => done = true)),
      );
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
      await tester.pumpWidget(
        wrap(
          MaterialScreen(
            unit: unit(sections: [section('fall', paragraphs: 1)]),
            onDone: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = find.widgetWithText(FilledButton, 'デキすぎ君に教える');
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    });

    testWidgets('やってみるを出す', (tester) async {
      await tester.pumpWidget(
        wrap(MaterialScreen(unit: unit(), onDone: () {})),
      );
      expect(find.text('やってみる'), findsWidgets);
    });

    testWidgets('320dp・文字200%でも導入情報が横にはみ出さない', (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(MaterialScreen(unit: unit(), onDone: () {}), textScale: 2),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('力と運動'), findsOneWidget);
    });
  });

  group('iPad の広い画面', () {
    // 学校が配っているのは iPad。スマホ前提のまま広げると
    // 1行が長くなりすぎて、折り返したときに次の行頭を見失う
    Future<void> pumpWide(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(2048, 1536); // iPad 横向き相当
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(wrap(child));
      await tester.pumpAndSettle();
    }

    testWidgets('本文の幅を広げすぎない', (tester) async {
      await pumpWide(tester, MaterialScreen(unit: unit(), onDone: () {}));
      final box = tester.getSize(find.byType(ListView));
      expect(box.width, lessThanOrEqualTo(640), reason: '1行が長くなりすぎる');
    });

    testWidgets('広い画面でも操作が消えない', (tester) async {
      // ReadableWidth の Align が高さいっぱいに広がって
      // 下のバーが画面を占領し、本文が消えたことがある
      await pumpWide(tester, MaterialScreen(unit: unit(), onDone: () {}));
      expect(find.textContaining('説明してもらいます'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'デキすぎ君に教える'), findsOneWidget);
    });
  });

  group('復習から開いたとき', () {
    testWidgets('その節だけを出す', (tester) async {
      await tester.pumpWidget(
        wrap(
          MaterialScreen(
            unit: unit(),
            focusConceptKey: 'inertia',
            onDone: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('inertia の話'), findsOneWidget);
      expect(find.text('fall の話'), findsNothing);
    });

    testWidgets('会話へ進ませない（読み直しに来ただけ）', (tester) async {
      // **`review: true` が要る。**
      // 以前は focusConceptKey だけで復習と見なしていて、
      // このテストがその誤った前提を固定していた。
      // おかげでホームの主 CTA が行き止まりでも緑のままだった
      await tester.pumpWidget(
        wrap(
          MaterialScreen(
            unit: unit(),
            focusConceptKey: 'inertia',
            review: true,
            onDone: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('デキすぎ君に教える'), findsNothing);
      expect(find.text('もどる'), findsOneWidget);
      expect(find.text('力と運動'), findsOneWidget, reason: '読み直し中も現在の単元名が必要');
    });

    testWidgets('節が無ければ単元まるごと出す', (tester) async {
      await tester.pumpWidget(
        wrap(
          MaterialScreen(unit: unit(), focusConceptKey: 'nope', onDone: () {}),
        ),
      );
      await tester.pump();
      expect(find.text('fall の話'), findsOneWidget);
    });
  });
}
