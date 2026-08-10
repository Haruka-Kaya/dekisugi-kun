import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/motion.dart';
import 'package:dekisugi/learning/domain/learning_heart.dart';
import 'package:dekisugi/learning/domain/learning_need.dart';
import 'package:dekisugi/screens/science_lightning_screen.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/science_challenge_fixture.dart';

const _questions = [
  ScienceLightningQuestion(
    id: 'vacuum',
    prompt: '真空中で重さだけが違う2球。落下加速度は？',
    options: [
      ScienceLightningOption(id: 'heavy-fast', text: '重い球ほど大きい'),
      ScienceLightningOption(id: 'same', text: '2球で同じ'),
      ScienceLightningOption(id: 'light-fast', text: '軽い球ほど大きい'),
    ],
    correctOptionId: 'same',
    needCode: 'science.fall.foundation',
  ),
  ScienceLightningQuestion(
    id: 'drag',
    prompt: '同じ質量で形だけが違う。空気中で差を生むものは？',
    options: [
      ScienceLightningOption(id: 'color', text: '物体の色'),
      ScienceLightningOption(id: 'drag', text: '空気抵抗'),
      ScienceLightningOption(id: 'name', text: '物体の名前'),
    ],
    correctOptionId: 'drag',
    needCode: 'science.fall.conditions',
  ),
  ScienceLightningQuestion(
    id: 'axis',
    prompt: '時間―距離グラフの横軸で右へ進む量は？',
    options: [
      ScienceLightningOption(id: 'distance', text: '距離'),
      ScienceLightningOption(id: 'mass', text: '質量'),
      ScienceLightningOption(id: 'time', text: '時間'),
    ],
    correctOptionId: 'time',
    needCode: 'science.fall.transfer',
  ),
];

Widget _wrap({
  VoidCallback? onCompleted,
  Duration timeLimit = const Duration(seconds: 30),
  double textScale = 1,
  bool disableAnimations = false,
  Brightness brightness = Brightness.light,
  LearningNeedEvidenceReported? onNeedEvidence,
  LearningHeartLossReported? onHeartLoss,
  Future<bool> Function()? onRetryRequested,
  Duration Function()? elapsedClock,
}) => MaterialApp(
  theme: buildAppTheme(brightness),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: disableAnimations,
    ),
    child: ReduceMotionScope(child: child!),
  ),
  home: ScienceLightningScreen(
    section: challengeSection,
    conceptLabel: '落下クイック判断',
    practiceAttempt: challengePracticeAttempt,
    content: ScienceLightningContent(
      questions: _questions,
      timeLimit: timeLimit,
    ),
    onCompleted: onCompleted ?? () {},
    onNeedEvidence: onNeedEvidence,
    onHeartLoss: onHeartLoss,
    onRetryRequested: onRetryRequested ?? () async => true,
    elapsedClock: elapsedClock,
  ),
);

Finder get _scrollable => find
    .descendant(
      of: find.byKey(const ValueKey('science-lightning-scroll')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 160, scrollable: _scrollable);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _start(WidgetTester tester) =>
    _tap(tester, find.byKey(const ValueKey('lightning-start')));

Future<void> _answer(WidgetTester tester, String optionId) async {
  await _tap(tester, find.byKey(ValueKey('lightning-option-$optionId')));
  await _tap(tester, find.byKey(const ValueKey('lightning-submit')));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('固定問題列を順番に通過し、明示完了だけを一度通知する', (tester) async {
    var completed = 0;
    await tester.pumpWidget(
      _wrap(disableAnimations: true, onCompleted: () => completed++),
    );
    await _start(tester);

    expect(find.textContaining('落下加速度は？'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('1/3問目.*残り時間30秒')), findsOneWidget);
    await _answer(tester, 'same');
    expect(find.textContaining('空気中で差を生む'), findsOneWidget);
    await _answer(tester, 'drag');
    expect(find.textContaining('横軸で右へ進む'), findsOneWidget);
    await _answer(tester, 'time');

    expect(find.text('固定問題列を完走'), findsOneWidget);
    expect(completed, 0);
    final complete = find.byKey(const ValueKey('lightning-complete'));
    await tester.scrollUntilVisible(complete, 160, scrollable: _scrollable);
    await tester.tap(complete);
    await tester.tap(complete);
    expect(completed, 1);
  });

  testWidgets('誤答は直ちにrunを終了し、別候補と後続問題を総当たりできない', (tester) async {
    var completed = 0;
    var retryChecks = 0;
    final needs = <LearningNeedEvidence>[];
    final heartLosses = <LearningHeartLossEvidence>[];
    await tester.pumpWidget(
      _wrap(
        disableAnimations: true,
        onCompleted: () => completed++,
        onNeedEvidence: needs.add,
        onHeartLoss: heartLosses.add,
        onRetryRequested: () async {
          retryChecks++;
          return false;
        },
      ),
    );
    await _start(tester);
    await _answer(tester, 'heavy-fast');

    expect(needs, hasLength(1));
    expect(needs.single.needCode, 'science.fall.foundation');
    expect(needs.single.kind, LearningNeedEvidenceKind.observed);
    expect(heartLosses, hasLength(1));
    expect(
      heartLosses.single.fixedTaskId,
      'lightning:$challengePracticeAttempt:question:vacuum',
    );

    expect(find.text('今回はここまで'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('もう一度取り組めるよう案内しています')), findsOneWidget);
    expect(find.byKey(const ValueKey('lightning-option-same')), findsNothing);
    expect(find.textContaining('空気中で差を生む'), findsNothing);
    expect(find.byKey(const ValueKey('lightning-complete')), findsNothing);
    expect(completed, 0);
    await _tap(tester, find.byKey(const ValueKey('lightning-retry')));
    await tester.pumpAndSettle();
    expect(retryChecks, 1);
    expect(find.text('今回はここまで'), findsOneWidget);
    expect(find.byKey(const ValueKey('lightning-start')), findsNothing);
  });

  testWidgets('時間切れはPath・streakを失わず、完了callbackを呼ばない', (tester) async {
    var completed = 0;
    var retryChecks = 0;
    final heartLosses = <LearningHeartLossEvidence>[];
    await tester.pumpWidget(
      _wrap(
        timeLimit: const Duration(seconds: 2),
        disableAnimations: true,
        onCompleted: () => completed++,
        onHeartLoss: heartLosses.add,
        onRetryRequested: () async {
          retryChecks++;
          return true;
        },
      ),
    );
    expect(find.textContaining('学校モードはハート無制限'), findsOneWidget);
    await _start(tester);
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('時間になりました'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('時間になったことを落ち着いて伝えています')),
      findsOneWidget,
    );
    expect(find.textContaining('Path・連続学習・報酬は変わりません'), findsOneWidget);
    expect(find.byKey(const ValueKey('lightning-complete')), findsNothing);
    expect(completed, 0);
    expect(heartLosses, isEmpty, reason: '時間切れではハートを失わない');
    await _tap(tester, find.byKey(const ValueKey('lightning-retry')));
    await tester.pumpAndSettle();
    expect(retryChecks, 1);
    expect(find.byKey(const ValueKey('lightning-start')), findsOneWidget);
  });

  testWidgets('background経過を復帰時に締切へ反映し、timeoutはheart 0件', (tester) async {
    var elapsed = Duration.zero;
    final heartLosses = <LearningHeartLossEvidence>[];
    await tester.pumpWidget(
      _wrap(
        timeLimit: const Duration(seconds: 5),
        disableAnimations: true,
        elapsedClock: () => elapsed,
        onHeartLoss: heartLosses.add,
      ),
    );
    await _start(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    elapsed = const Duration(seconds: 6);
    await tester.pump();
    expect(find.textContaining('落下加速度は？'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('時間になりました'), findsOneWidget);
    expect(heartLosses, isEmpty);
  });

  testWidgets('320x568・文200%・Reduce Motionで48dp・Semantics・overflowを守る', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(
        timeLimit: const Duration(minutes: 5),
        textScale: 2,
        disableAnimations: true,
        brightness: Brightness.dark,
      ),
    );

    expect(find.byType(AnimatedSwitcher), findsNothing);
    final start = find.byKey(const ValueKey('lightning-start'));
    await tester.scrollUntilVisible(start, 160, scrollable: _scrollable);
    expect(tester.getSize(start).height, greaterThanOrEqualTo(48));
    await tester.tap(start);
    await tester.pump();

    final choice = find.byKey(const ValueKey('lightning-option-same'));
    await tester.scrollUntilVisible(choice, 160, scrollable: _scrollable);
    expect(tester.getSize(choice).height, greaterThanOrEqualTo(48));
    expect(find.bySemanticsLabel(RegExp('選択肢2/3.*2球で同じ')), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
