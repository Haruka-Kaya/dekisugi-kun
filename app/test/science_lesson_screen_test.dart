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
  body: ['物体には重力がはたらく。', '真空では**質量に関係なく**同じ加速度で落ちる。'],
  tryIt: '紙を丸めて比べる。',
  localCheckpoint: _checkpoint,
);

Widget _app({required VoidCallback onCompleted}) => MaterialApp(
  theme: buildAppTheme(Brightness.light),
  home: ScienceLessonScreen(
    section: _section,
    conceptLabel: '落下',
    practiceAttempt: 0,
    onCompleted: onCompleted,
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
    expect(find.bySemanticsLabel('デキすぎ君。一緒に考えています'), findsOneWidget);
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
    expect(find.bySemanticsLabel('デキすぎ君。学習を応援しています'), findsOneWidget);
    expect(find.text('物体には重力がはたらく。'), findsOneWidget);
    expect(find.text('真空では質量に関係なく同じ加速度で落ちる。'), findsOneWidget);
    expect(find.textContaining('**'), findsNothing);
    await _scrollTo(
      tester,
      find.byKey(const ValueKey('science-lesson-compare')),
    );
    await tester.tap(find.byKey(const ValueKey('science-lesson-compare')));
    await tester.pump();
    expect(find.text('重さで変わると思う'), findsOneWidget);
    expect(completed, 0);

    await tester.tap(find.text('直す点'));
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
}
