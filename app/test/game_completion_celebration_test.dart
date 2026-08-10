import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/motion.dart';
import 'package:dekisugi/learning/domain/learning_economy.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/game_completion_celebration.dart';
import 'package:flutter_test/flutter_test.dart';

const _summary = GameCompletionSummary(
  eyebrow: 'PATH COMPLETE',
  title: 'やった！一歩進んだ',
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
  testWidgets('保存済みのXP・結晶・一時時間と笑顔のマスコットを祝福面に出す', (tester) async {
    GameCompletionAction? result;
    await _pumpLauncher(tester, onResult: (value) => result = value);

    expect(find.byKey(const ValueKey('game-completion-celebration')), findsOne);
    expect(find.text('やった！一歩進んだ'), findsOne);
    expect(find.text('+10'), findsOne);
    expect(find.text('+1'), findsOne);
    expect(find.text('4:08'), findsOne);
    expect(find.textContaining('時間はこの完了画面だけ'), findsOne);
    expect(find.bySemanticsLabel('軌道リングのデキすぎ君が笑顔で学習完了を祝っています'), findsOne);

    await tester.tap(find.byKey(const ValueKey('completion-next-step')));
    await tester.pumpAndSettle();
    expect(result, GameCompletionAction.nextStep);
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

  testWidgets('学校scopeでは個人XP・結晶を演出せず完了と時間だけを返せる', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const schoolSummary = GameCompletionSummary(
      eyebrow: 'CLASS MISSION COMPLETE',
      title: 'この端末の授業ミッションを完了',
      message: '個人のXP・結晶・Pathには加算していません。',
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
    expect(find.textContaining('個人のXP・結晶・Pathには加算していません'), findsOne);
  });
}
