import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/models/unit.dart';
import 'package:dekisugi/screens/science_lesson_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _checkpoint = LocalCheckpoint(
  lure: '重い方が速い',
  options: [
    LocalCheckpointOption(id: 'a', text: '同時'),
    LocalCheckpointOption(id: 'b', text: '重い', hint: '質量を見る'),
    LocalCheckpointOption(id: 'c', text: '軽い', hint: '条件を見る'),
  ],
  correctOptionId: 'a',
  explanation: '真空なら同時',
);

const _section = Section(
  conceptKey: 'fall',
  title: '落下の本文',
  body: ['物体には重力がはたらく。力の向きも確かめよう。', '真空では**質量に関係なく**同じ加速度で落ちる。空気中では抵抗も考える。'],
  tryIt: '紙を丸めて比べる。',
  localCheckpoint: _checkpoint,
);

Widget _app({
  required VoidCallback onCompleted,
  VoidCallback? onReturnToPath,
}) => MaterialApp(
  theme: buildAppTheme(Brightness.light),
  home: ScienceLessonScreen(
    section: _section,
    conceptLabel: '落下',
    practiceAttempt: 0,
    onCompleted: onCompleted,
    onReturnToPath: onReturnToPath,
  ),
);

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
}

void main() {
  testWidgets('予想前に教材本文を見せず、自己比較後だけ完了する', (tester) async {
    final semantics = tester.ensureSemantics();
    var completed = 0;
    await tester.pumpWidget(_app(onCompleted: () => completed++));
    expect(find.text('教材観察  /  落下'), findsOneWidget);
    expect(find.textContaining('観察手順 1 / 3'), findsOneWidget);
    expect(find.textContaining('TEXT'), findsNothing);
    expect(find.textContaining('STEP'), findsNothing);
    expect(find.bySemanticsLabel('デキすぎ君。一緒に考えています'), findsOneWidget);
    expect(
      find.bySemanticsLabel('この教材のあと、デキすぎ君へ理由と条件を自分の言葉で説明します'),
      findsOneWidget,
    );
    expect(find.textContaining('このあと、デキすぎ君へ説明します'), findsOneWidget);
    expect(find.text('物体には重力がはたらく。'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('science-lesson-reveal')),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byKey(const ValueKey('science-lesson-prediction')),
      '重さで変わると思う',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('science-lesson-reveal')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('science-lesson-reveal')));
    await tester.pump();
    expect(find.textContaining('観察手順 2 / 3'), findsOneWidget);
    expect(find.bySemanticsLabel('デキすぎ君。学習を応援しています'), findsOneWidget);
    expect(find.text('物体には重力がはたらく。'), findsOneWidget);
    expect(find.text('真空では質量に関係なく同じ加速度で落ちる。'), findsOneWidget);
    expect(find.text('物体には重力がはたらく。力の向きも確かめよう。'), findsNothing);
    expect(
      find.text('真空では質量に関係なく同じ加速度で落ちる。空気中では抵抗も考える。', findRichText: true),
      findsNothing,
    );
    expect(find.text('まず押さえる要点'), findsOneWidget);
    await _scrollTo(
      tester,
      find.byKey(const ValueKey('science-lesson-full-text')),
    );
    await tester.tap(find.text('教材をくわしく読む'));
    await tester.pumpAndSettle();
    expect(find.text('物体には重力がはたらく。力の向きも確かめよう。'), findsOneWidget);
    expect(
      find.text('真空では質量に関係なく同じ加速度で落ちる。空気中では抵抗も考える。', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('**'), findsNothing);
    await _scrollTo(
      tester,
      find.byKey(const ValueKey('science-lesson-compare')),
    );
    await tester.tap(find.byKey(const ValueKey('science-lesson-compare')));
    await tester.pump();
    expect(find.textContaining('観察手順 3 / 3'), findsOneWidget);
    expect(find.text('重さで変わると思う'), findsOneWidget);
    expect(completed, 0);

    await _scrollTo(tester, find.text('直す点'));
    await tester.tap(find.text('直す点'));
    await _scrollTo(tester, find.text('同時'));
    await tester.tap(find.text('同時'));
    await tester.pump();
    expect(find.text('教材の根拠と照合できました。'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('science-lesson-reflection')),
      '真空という条件を足す',
    );
    await _scrollTo(
      tester,
      find.byKey(const ValueKey('science-lesson-complete')),
    );
    await tester.tap(find.byKey(const ValueKey('science-lesson-complete')));
    await tester.pump();
    expect(completed, 1);
    expect(
      find.byKey(const ValueKey('science-lesson-finished')),
      findsOneWidget,
    );
    expect(find.text('教材観察  /  完了'), findsOneWidget);
    expect(find.bySemanticsLabel('デキすぎ君。笑顔で成果を祝っています'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('320dp・文字200%でも初期面がoverflowせず操作できる', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: _app(onCompleted: () {}),
      ),
    );
    expect(tester.takeException(), isNull);
    final semantics = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel('入力はこの画面だけで使い、保存も送信も自動採点もしません'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('固定の確かめを外すと自由記述をしても完了できない', (tester) async {
    var completed = 0;
    await tester.pumpWidget(_app(onCompleted: () => completed++));

    await tester.enterText(
      find.byKey(const ValueKey('science-lesson-prediction')),
      '重い方が速いと思う。',
    );
    await _scrollTo(
      tester,
      find.byKey(const ValueKey('science-lesson-reveal')),
    );
    await tester.tap(find.byKey(const ValueKey('science-lesson-reveal')));
    await tester.pump();
    await _scrollTo(
      tester,
      find.byKey(const ValueKey('science-lesson-compare')),
    );
    await tester.tap(find.byKey(const ValueKey('science-lesson-compare')));
    await tester.pump();

    await _scrollTo(tester, find.text('重い'));
    await tester.tap(find.text('重い'));
    await _scrollTo(tester, find.text('直す点'));
    await tester.tap(find.text('直す点'));
    await tester.enterText(
      find.byKey(const ValueKey('science-lesson-reflection')),
      '重さだけで決まると考えた。',
    );
    await tester.pump();

    expect(find.textContaining('教材の根拠を読み直して、もう一度選んでみましょう。'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('science-lesson-complete')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('science-lesson-complete')));
    await tester.pump();
    expect(completed, 0);
  });

  testWidgets('途中で保留すると観察の道へ戻れる', (tester) async {
    var returned = 0;
    await tester.pumpWidget(
      _app(onCompleted: () {}, onReturnToPath: () => returned++),
    );

    await _scrollTo(tester, find.byKey(const ValueKey('science-lesson-defer')));
    await tester.tap(find.byKey(const ValueKey('science-lesson-defer')));
    await tester.pump();

    expect(returned, 1);
  });
}
