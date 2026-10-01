import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/motion.dart';
import 'package:dekisugi/learning/domain/learning_economy.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/game_completion_celebration.dart';
import 'package:flutter_test/flutter_test.dart';

const _summary = GameCompletionSummary(
  eyebrow: '教材観察 / 保存済み',
  title: '観察記録を追加しました',
  message: '予想と観察を比べて、次の実験へ進めます。',
  elapsed: Duration(minutes: 4, seconds: 8),
  xpAwarded: 10,
  gemsAwarded: 1,
  showPersonalRewards: true,
  mascotStyle: LearningPathMascotStyle.orbit,
);

Future<void> _pumpLauncher(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1,
  bool reduceMotion = false,
  ValueChanged<GameCompletionAction?>? onResult,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(Brightness.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: reduceMotion,
        ),
        child: ReduceMotionScope(child: child!),
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              key: const ValueKey('launch-completion'),
              onPressed: () async {
                final result = await showGameCompletionCelebration(
                  context,
                  summary: _summary,
                );
                onResult?.call(result);
              },
              child: const Text('完了面を開く'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('launch-completion')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('保存済みの実値だけを探究ノートの記録票へ出す', (tester) async {
    final semantics = tester.ensureSemantics();
    GameCompletionAction? result;
    await _pumpLauncher(tester, onResult: (value) => result = value);

    expect(find.byKey(const ValueKey('game-completion-celebration')), findsOne);
    expect(find.text('観察記録を追加しました'), findsOne);
    expect(find.bySemanticsLabel(RegExp('観察記録を追加しました')), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('予想と観察を比べて、次の実験へ進めます。')),
      findsOneWidget,
    );
    expect(find.text('+10'), findsOne);
    expect(find.text('+1'), findsOne);
    expect(find.text('4:08'), findsOne);
    expect(find.text('教材観察の記録'), findsOneWidget);
    expect(find.text('観察記録を保存しました'), findsOneWidget);
    expect(find.byKey(const ValueKey('completion-ledger')), findsOneWidget);
    expect(find.bySemanticsLabel('探究記録、+10'), findsOneWidget);
    expect(find.bySemanticsLabel('ひらめき結晶、+1'), findsOneWidget);
    expect(find.bySemanticsLabel('今回の観察時間、4:08'), findsOneWidget);
    expect(find.textContaining('観察時間はこの記録票だけ'), findsOne);
    expect(find.bySemanticsLabel('軌道リングのデキすぎ君が観察記録へ完了印を押しています'), findsOne);
    expect(find.bySemanticsLabel('次の観察へ'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.painter.runtimeType.toString() == '_CelebrationBurstPainter',
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('completion-next-step')));
    await tester.pumpAndSettle();
    expect(result, GameCompletionAction.nextStep);
    semantics.dispose();
  });

  testWidgets('320×568・文字200%でも縦にスクロールして両操作へ届く', (tester) async {
    await _pumpLauncher(
      tester,
      size: const Size(320, 568),
      textScale: 2,
      reduceMotion: true,
    );

    expect(tester.takeException(), isNull);
    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('game-completion-scroll')),
      matching: find.byType(Scrollable),
    );
    final next = find.byKey(const ValueKey('completion-next-step'));
    await tester.scrollUntilVisible(next, 180, scrollable: scrollable);
    expect(tester.getSize(next).height, greaterThanOrEqualTo(56));
    final review = find.byKey(const ValueKey('completion-review-result'));
    await tester.scrollUntilVisible(review, 120, scrollable: scrollable);
    expect(tester.getSize(review).height, greaterThanOrEqualTo(52));
    expect(tester.takeException(), isNull);
  });

  testWidgets('学校scopeでは個人の探究記録・結晶を出さず完了と時間だけを返せる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const schoolSummary = GameCompletionSummary(
      eyebrow: '授業の観察記録 / 保存済み',
      title: 'この端末の授業観察を完了',
      message: '個人の探究記録・結晶・探究ノートには加算していません。',
      elapsed: Duration(seconds: 52),
      xpAwarded: 0,
      gemsAwarded: 0,
      showPersonalRewards: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        builder: (context, child) => ReduceMotionScope(child: child!),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showGameCompletionCelebration(
                context,
                summary: schoolSummary,
              ),
              child: const Text('開く'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('completion-xp')), findsNothing);
    expect(find.byKey(const ValueKey('completion-gems')), findsNothing);
    expect(find.text('52秒'), findsOne);
    expect(find.textContaining('個人の探究記録・結晶・探究ノートには加算していません'), findsOne);
  });
}
