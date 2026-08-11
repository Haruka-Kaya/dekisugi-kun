import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/motion.dart';
import 'package:dekisugi/learning/domain/learning_heart.dart';
import 'package:dekisugi/learning/domain/learning_need.dart';
import 'package:dekisugi/models/unit.dart';
import 'package:dekisugi/screens/science_notation_lab_screen.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/science_challenge_support.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/science_challenge_fixture.dart';

const _arrowTrace = ScienceNotationTracePattern(
  semanticsLabel: '始点から軸、上の矢じり、下の矢じりの順になぞります。',
  strokes: [
    ScienceNotationTraceStroke(
      id: 'arrow.shaft',
      label: '矢印の軸',
      points: [
        ScienceNotationTracePoint(x: 0.15, y: 0.5),
        ScienceNotationTracePoint(x: 0.48, y: 0.5),
        ScienceNotationTracePoint(x: 0.80, y: 0.5),
      ],
    ),
    ScienceNotationTraceStroke(
      id: 'arrow.upper',
      label: '上の矢じり',
      points: [
        ScienceNotationTracePoint(x: 0.62, y: 0.30),
        ScienceNotationTracePoint(x: 0.71, y: 0.40),
        ScienceNotationTracePoint(x: 0.80, y: 0.5),
      ],
    ),
    ScienceNotationTraceStroke(
      id: 'arrow.lower',
      label: '下の矢じり',
      points: [
        ScienceNotationTracePoint(x: 0.80, y: 0.5),
        ScienceNotationTracePoint(x: 0.71, y: 0.60),
        ScienceNotationTracePoint(x: 0.62, y: 0.70),
      ],
    ),
  ],
  strokeOrderIds: ['arrow.shaft', 'arrow.upper', 'arrow.lower'],
);

const _formulaTrace = ScienceNotationTracePattern(
  semanticsLabel: '式を左から右へ読み、意味を結ぶ順になぞります。',
  strokes: [
    ScienceNotationTraceStroke(
      id: 'formula.read',
      label: '左辺から右辺への線',
      points: [
        ScienceNotationTracePoint(x: 0.12, y: 0.62),
        ScienceNotationTracePoint(x: 0.50, y: 0.62),
        ScienceNotationTracePoint(x: 0.88, y: 0.62),
      ],
    ),
    ScienceNotationTraceStroke(
      id: 'formula.link',
      label: '量を結ぶ線',
      points: [
        ScienceNotationTracePoint(x: 0.30, y: 0.35),
        ScienceNotationTracePoint(x: 0.50, y: 0.48),
        ScienceNotationTracePoint(x: 0.70, y: 0.35),
      ],
    ),
  ],
  strokeOrderIds: ['formula.read', 'formula.link'],
);

const _content = ScienceNotationLabContent(
  orderTasks: [
    ScienceNotationOrderTask(
      id: 'arrow',
      title: '矢印をなぞる順番',
      prompt: '力の矢印を、始点から矢じりまで順番に組みます。',
      traceGuide: '始点から線を引き、最後に矢じりを置きます。',
      tracePattern: _arrowTrace,
      tokens: [
        ScienceNotationToken(id: 'arrow-head-down', label: '矢じり下'),
        ScienceNotationToken(id: 'arrow-line', label: '右へ線'),
        ScienceNotationToken(id: 'arrow-start', label: '始点'),
        ScienceNotationToken(id: 'arrow-head-up', label: '矢じり上'),
      ],
      correctOrderIds: [
        'arrow-start',
        'arrow-line',
        'arrow-head-up',
        'arrow-head-down',
      ],
      solutionSummary: '矢印は始点、線、矢じりの順で意味を持ちます。',
      needCode: 'science.fall.notation.arrow',
    ),
    ScienceNotationOrderTask(
      id: 'formula',
      title: '速さの式を組む',
      prompt: '量と演算記号を、読む順番に並べます。',
      traceGuide: '式は左から右へ読みます。',
      tracePattern: _formulaTrace,
      tokens: [
        ScienceNotationToken(id: 'time', label: '時間'),
        ScienceNotationToken(id: 'equal', label: '＝'),
        ScienceNotationToken(id: 'speed', label: '速さ'),
        ScienceNotationToken(id: 'divide', label: '÷'),
        ScienceNotationToken(id: 'distance', label: '距離'),
      ],
      correctOrderIds: ['speed', 'equal', 'distance', 'divide', 'time'],
      solutionSummary: '速さは、距離を時間で割った量です。',
      needCode: 'science.fall.notation.equation',
    ),
  ],
  symbolMatch: ScienceNotationSymbolTask(
    prompt: '「1秒あたりに進むメートル」を表す単位記号はどれ？',
    choices: [
      ScienceNotationChoice(id: 'm', label: 'm'),
      ScienceNotationChoice(id: 'mps', label: 'm/s'),
      ScienceNotationChoice(id: 's', label: 's'),
    ],
    correctChoiceId: 'mps',
    solutionSummary: 'm/sは、1秒あたりに進むメートルを表します。',
    needCode: 'science.fall.notation.symbol',
  ),
  graphRead: ScienceNotationGraphTask(
    prompt: '時間が右へ進むとき、この線から読める変化はどれ？',
    graphNotation: ['距離 ↑', '     ／', '時間 ───→'],
    graphSemanticsLabel: '横軸は時間で右向き、縦軸は距離で上向き。線は右上がり。',
    choices: [
      ScienceNotationChoice(id: 'decrease', label: '距離が減る'),
      ScienceNotationChoice(id: 'increase', label: '距離が増える'),
      ScienceNotationChoice(id: 'same', label: '距離は変わらない'),
    ],
    correctChoiceId: 'increase',
    solutionSummary: '右上がりの線は、時間とともに距離が増えることを表します。',
    needCode: 'science.fall.notation.graph',
  ),
);

const _taggedContent = ScienceNotationLabContent.tagged(
  tasks: [
    ScienceNotationArrangeTask(
      kind: LocalNotationTaskKind.sequence,
      id: 'cells.sequence',
      title: '体の階層を組み立てる',
      prompt: '小さい単位から大きい単位へ並べる。',
      solutionSummary: '細胞が集まって組織と器官をつくります。',
      guide: '細胞から個体へ広げます。',
      tokens: [
        ScienceNotationToken(id: 'tissue', label: '組織'),
        ScienceNotationToken(id: 'organ', label: '器官'),
        ScienceNotationToken(id: 'cell', label: '細胞'),
      ],
      correctOrderIds: ['cell', 'tissue', 'organ'],
      needCode: 'science.fall.notation.sequence',
    ),
    ScienceNotationChoiceTask(
      kind: LocalNotationTaskKind.labelDiagram,
      id: 'cells.labelDiagram',
      title: '細胞図の境界を見分ける',
      prompt: '外側の厚い境界はどれ？',
      solutionSummary: '細胞膜の外側にある厚い境界は細胞壁です。',
      representation: ['┏━━━━┓ 外側の境界', '┃ ┌──┐ ┃ 内側の膜'],
      representationSemanticsLabel: '外側に厚い境界、内側に細い膜がある細胞図。',
      choices: [
        ScienceNotationChoice(id: 'membrane', label: '細胞膜'),
        ScienceNotationChoice(id: 'wall', label: '細胞壁'),
        ScienceNotationChoice(id: 'chloroplast', label: '葉緑体'),
      ],
      correctChoiceId: 'wall',
      needCode: 'science.fall.notation.labelDiagram',
    ),
  ],
);

Widget _wrap({
  VoidCallback? onCompleted,
  double textScale = 1,
  bool disableAnimations = false,
  Brightness brightness = Brightness.light,
  String? focusNeedCode,
  LearningNeedEvidenceReported? onNeedEvidence,
  LearningHeartLossReported? onHeartLoss,
  Future<bool> Function()? onRetryRequested,
  bool accessibleNavigation = false,
  ScienceNotationLabContent content = _content,
}) => MaterialApp(
  theme: buildAppTheme(brightness),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: disableAnimations,
      accessibleNavigation: accessibleNavigation,
    ),
    child: ReduceMotionScope(child: child!),
  ),
  home: ScienceNotationLabScreen(
    section: challengeSection,
    conceptLabel: '速さとグラフ',
    practiceAttempt: challengePracticeAttempt,
    content: content,
    onCompleted: onCompleted ?? () {},
    focusNeedCode: focusNeedCode,
    onNeedEvidence: onNeedEvidence,
    onHeartLoss: onHeartLoss,
    onRetryRequested: onRetryRequested ?? () async => true,
  ),
);

Finder get _scrollable => find
    .descendant(
      of: find.byKey(const ValueKey('science-notation-scroll')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 160, scrollable: _scrollable);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _answerOrder(WidgetTester tester, List<String> ids) async {
  for (final id in ids) {
    await _tap(tester, find.byKey(ValueKey('notation-order-token-$id')));
  }
  await _tap(tester, find.byKey(const ValueKey('notation-submit')));
}

Future<void> _drawStroke(
  WidgetTester tester,
  List<ScienceNotationTracePoint> points,
) async {
  final canvas = find.byKey(const ValueKey('notation-trace-canvas'));
  await tester.scrollUntilVisible(canvas, 120, scrollable: _scrollable);
  await tester.pump();
  final origin = tester.getTopLeft(canvas);
  final size = tester.getSize(canvas);
  Offset global(ScienceNotationTracePoint point) =>
      origin + Offset(point.x * size.width, point.y * size.height);
  final gesture = await tester.startGesture(global(points.first));
  await tester.pump();
  for (final point in points.skip(1)) {
    await gesture.moveTo(global(point));
    await tester.pump();
  }
  await gesture.up();
  await tester.pump();
}

Future<void> _completeTrace(
  WidgetTester tester,
  ScienceNotationTracePattern pattern,
) async {
  if (find
      .byKey(const ValueKey('notation-trace-accessible-sequence'))
      .evaluate()
      .isNotEmpty) {
    for (var index = 1; index <= pattern.strokeOrderIds.length; index++) {
      await _tap(
        tester,
        find.byKey(ValueKey('notation-trace-accessible-$index')),
      );
    }
  } else {
    for (final id in pattern.strokeOrderIds) {
      await _drawStroke(tester, pattern.strokeFor(id).points);
    }
  }
  await _tap(tester, find.byKey(const ValueKey('notation-trace-continue')));
}

Future<void> _completeAll(WidgetTester tester) async {
  await _answerOrder(tester, const [
    'arrow-start',
    'arrow-line',
    'arrow-head-up',
    'arrow-head-down',
  ]);
  await _completeTrace(tester, _arrowTrace);
  await _answerOrder(tester, const [
    'speed',
    'equal',
    'distance',
    'divide',
    'time',
  ]);
  await _completeTrace(tester, _formulaTrace);
  await _tap(tester, find.byKey(const ValueKey('notation-symbol-mps')));
  await _tap(tester, find.byKey(const ValueKey('notation-submit')));
  await _tap(tester, find.byKey(const ValueKey('notation-graph-increase')));
  await _tap(tester, find.byKey(const ValueKey('notation-submit')));
}

void _expectSolutionsHidden() {
  expect(find.textContaining('矢印は始点、線、矢じり'), findsNothing);
  expect(find.textContaining('速さは、距離を時間で'), findsNothing);
  expect(find.textContaining('右上がりの線は'), findsNothing);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('catalogの矢印・式・単位・グラフを順に扱い、正本は完了前に先出ししない', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(disableAnimations: true, accessibleNavigation: true),
    );

    expect(find.text('矢印をなぞる順番'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('なぞる向き.*始点から線')), findsOneWidget);
    expect(find.textContaining('固定の復習コードだけ'), findsOneWidget);
    expect(find.textContaining('成績や理解度の認定には使いません'), findsOneWidget);
    _expectSolutionsHidden();

    await _completeAll(tester);

    expect(find.text('記号を意味とつなげました'), findsOneWidget);
    expect(find.textContaining('矢印は始点、線、矢じり'), findsOneWidget);
    expect(find.textContaining('速さは、距離を時間で'), findsOneWidget);
    expect(find.textContaining('右上がりの線は'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('v10のtrace無しsequenceからlabelDiagramへ回答を保存せず進む', (tester) async {
    final needs = <LearningNeedEvidence>[];
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(
        content: _taggedContent,
        disableAnimations: true,
        onNeedEvidence: needs.add,
      ),
    );

    expect(find.text('体の階層を組み立てる'), findsOneWidget);
    await _answerOrder(tester, const ['cell', 'tissue', 'organ']);
    expect(find.byKey(const ValueKey('notation-trace-canvas')), findsNothing);
    expect(find.text('細胞図の境界を見分ける'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('外側に厚い境界.*内側に細い膜')), findsOneWidget);
    expect(needs.single.needCode, 'science.fall.notation.sequence');

    await _tap(
      tester,
      find.byKey(const ValueKey('notation-labelDiagram-wall')),
    );
    await _tap(tester, find.byKey(const ValueKey('notation-submit')));
    expect(find.text('記号を意味とつなげました'), findsOneWidget);
    expect(needs.map((need) => need.needCode), [
      'science.fall.notation.sequence',
      'science.fall.notation.labelDiagram',
    ]);
    semantics.dispose();
  });

  testWidgets('order正答後もcatalog strokeを規定順の実gestureで完了するまで次へ進めない', (
    tester,
  ) async {
    final needs = <LearningNeedEvidence>[];
    await tester.pumpWidget(
      _wrap(disableAnimations: true, onNeedEvidence: needs.add),
    );

    await _answerOrder(tester, const [
      'arrow-start',
      'arrow-line',
      'arrow-head-up',
      'arrow-head-down',
    ]);

    expect(find.byKey(const ValueKey('notation-trace-canvas')), findsOneWidget);
    expect(find.textContaining('矢印は始点、線、矢じり'), findsOneWidget);
    expect(find.text('速さの式を組む'), findsNothing);
    expect(needs, isEmpty, reason: '指なぞりを終える前にdemonstratedへしない');
    expect(
      tester
          .widget<ScienceChallengePrimaryButton>(
            find.byKey(const ValueKey('notation-trace-continue')),
          )
          .onPressed,
      isNull,
    );

    // 2本目から始める、線から大きく離れる、途中で指を離す操作はいずれも未完了。
    await _drawStroke(tester, _arrowTrace.strokeFor('arrow.upper').points);
    expect(find.textContaining('番号の付いた始点'), findsOneWidget);

    final canvas = find.byKey(const ValueKey('notation-trace-canvas'));
    final origin = tester.getTopLeft(canvas);
    final size = tester.getSize(canvas);
    final start = await tester.startGesture(
      origin + Offset(size.width * 0.15, size.height * 0.5),
    );
    await start.moveTo(origin + Offset(size.width * 0.5, size.height * 0.1));
    await tester.pump();
    await start.up();
    expect(find.textContaining('線から離れました'), findsOneWidget);

    final early = await tester.startGesture(
      origin + Offset(size.width * 0.15, size.height * 0.5),
    );
    await early.moveTo(origin + Offset(size.width * 0.48, size.height * 0.5));
    await early.up();
    await tester.pump();
    expect(find.textContaining('途中で指が離れました'), findsOneWidget);

    final cancelled = await tester.startGesture(
      origin + Offset(size.width * 0.15, size.height * 0.5),
    );
    await cancelled.moveTo(
      origin + Offset(size.width * 0.48, size.height * 0.5),
    );
    await cancelled.moveTo(
      origin + Offset(size.width * 0.80, size.height * 0.5),
    );
    await cancelled.cancel();
    await tester.pump();
    expect(find.textContaining('操作が中断されました'), findsOneWidget);

    await _completeTrace(tester, _arrowTrace);
    expect(find.text('速さの式を組む'), findsOneWidget);
    expect(needs, hasLength(1));
    expect(needs.single.kind, LearningNeedEvidenceKind.demonstrated);
    expect(needs.single.needCode, 'science.fall.notation.arrow');
  });

  testWidgets('なぞり中の同時2 pointerはfail-closedで線を完了しない', (tester) async {
    await tester.pumpWidget(_wrap(disableAnimations: true));
    await _answerOrder(tester, const [
      'arrow-start',
      'arrow-line',
      'arrow-head-up',
      'arrow-head-down',
    ]);

    final canvas = find.byKey(const ValueKey('notation-trace-canvas'));
    await tester.scrollUntilVisible(canvas, 120, scrollable: _scrollable);
    await tester.pump();
    final origin = tester.getTopLeft(canvas);
    final size = tester.getSize(canvas);
    final strokeStart = origin + Offset(size.width * 0.15, size.height * 0.5);
    final first = await tester.startGesture(strokeStart, pointer: 1);
    await tester.pump();
    final second = await tester.startGesture(strokeStart, pointer: 2);
    await tester.pump();
    await first.up();
    await second.up();
    await tester.pump();

    expect(find.textContaining('指が複数触れました'), findsOneWidget);
    expect(
      tester
          .widget<ScienceChallengePrimaryButton>(
            find.byKey(const ValueKey('notation-trace-continue')),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('速さの式を組む'), findsNothing);
  });

  testWidgets('accessibilityNavigationでは正答開示後に同じstroke順を56dpボタンで確認する', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(disableAnimations: true, accessibleNavigation: true),
    );
    await _answerOrder(tester, const [
      'arrow-start',
      'arrow-line',
      'arrow-head-up',
      'arrow-head-down',
    ]);

    expect(find.byKey(const ValueKey('notation-trace-canvas')), findsNothing);
    expect(
      find.byKey(const ValueKey('notation-trace-accessible-sequence')),
      findsOneWidget,
    );
    for (var index = 1; index <= 3; index++) {
      final button = find.byKey(ValueKey('notation-trace-accessible-$index'));
      await tester.scrollUntilVisible(button, 100, scrollable: _scrollable);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      final control = tester.widget<OutlinedButton>(button);
      expect(control.onPressed, isNotNull);
      if (index < 3) {
        expect(
          tester
              .widget<OutlinedButton>(
                find.byKey(ValueKey('notation-trace-accessible-${index + 1}')),
              )
              .onPressed,
          isNull,
        );
      }
      await tester.tap(button);
      await tester.pump();
    }
    expect(find.text('全ての線を順番に確認しました。'), findsOneWidget);
    expect(
      tester
          .widget<ScienceChallengePrimaryButton>(
            find.byKey(const ValueKey('notation-trace-continue')),
          )
          .onPressed,
      isNotNull,
    );
    semantics.dispose();
  });

  testWidgets('誤った並びはロックされ、見直し文なしで別候補を総当たりできない', (tester) async {
    final needs = <LearningNeedEvidence>[];
    await tester.pumpWidget(
      _wrap(disableAnimations: true, onNeedEvidence: needs.add),
    );

    await _answerOrder(tester, const [
      'arrow-line',
      'arrow-start',
      'arrow-head-up',
      'arrow-head-down',
    ]);

    expect(needs, hasLength(1));
    expect(needs.single.needCode, 'science.fall.notation.arrow');
    expect(needs.single.kind, LearningNeedEvidenceKind.observed);

    expect(find.text('ここで一度、見直す'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('notation-retry')))
          .onPressed,
      isNull,
    );
    expect(find.text('矢印をなぞる順番'), findsOneWidget);
    _expectSolutionsHidden();

    final review = find.byKey(const ValueKey('notation-review'));
    await tester.scrollUntilVisible(review, 160, scrollable: _scrollable);
    await tester.enterText(review, '始点から見直します');
    await tester.pump();
    await _tap(tester, find.byKey(const ValueKey('notation-retry')));

    expect(find.text('ここで一度、見直す'), findsNothing);
    expect(find.text('矢印をなぞる順番'), findsOneWidget);
  });

  testWidgets('heart再確認が拒否したら見直し後も同じ固定課題を再開しない', (tester) async {
    final heartLosses = <LearningHeartLossEvidence>[];
    var retryChecks = 0;
    await tester.pumpWidget(
      _wrap(
        disableAnimations: true,
        onHeartLoss: heartLosses.add,
        onRetryRequested: () async {
          retryChecks++;
          return false;
        },
      ),
    );

    await _answerOrder(tester, const [
      'arrow-line',
      'arrow-start',
      'arrow-head-up',
      'arrow-head-down',
    ]);
    await tester.enterText(
      find.byKey(const ValueKey('notation-review')),
      '始点から見直します',
    );
    await tester.pump();
    await _tap(tester, find.byKey(const ValueKey('notation-retry')));
    await tester.pumpAndSettle();

    expect(heartLosses, hasLength(1));
    expect(retryChecks, 1);
    expect(find.text('ここで一度、見直す'), findsOneWidget);
    expect(
      tester
          .widget<ScienceChallengePrimaryButton>(
            find.byKey(const ValueKey('notation-submit')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('明示完了だけを回答なしで一度通知する', (tester) async {
    var completed = 0;
    await tester.pumpWidget(
      _wrap(
        disableAnimations: true,
        accessibleNavigation: true,
        onCompleted: () => completed++,
      ),
    );

    await _completeAll(tester);
    expect(completed, 0);

    final complete = find.byKey(const ValueKey('notation-complete'));
    await tester.scrollUntilVisible(complete, 160, scrollable: _scrollable);
    await tester.tap(complete);
    await tester.tap(complete);
    expect(completed, 1);
  });

  testWidgets('graph needを指定すると対応課題だけを開き、その構造成功だけを返す', (tester) async {
    final needs = <LearningNeedEvidence>[];
    await tester.pumpWidget(
      _wrap(
        disableAnimations: true,
        focusNeedCode: 'science.fall.notation.graph',
        onNeedEvidence: needs.add,
      ),
    );

    expect(find.text('グラフと矢印を読む'), findsOneWidget);
    expect(find.text('矢印をなぞる順番'), findsNothing);
    expect(find.textContaining('STEP 1 / 1'), findsOneWidget);

    await _tap(tester, find.byKey(const ValueKey('notation-graph-increase')));
    await _tap(tester, find.byKey(const ValueKey('notation-submit')));

    expect(find.text('記号を意味とつなげました'), findsOneWidget);
    expect(find.textContaining('右上がりの線は'), findsOneWidget);
    expect(find.textContaining('矢印は始点、線、矢じり'), findsNothing);
    expect(needs, hasLength(1));
    expect(needs.single.needCode, 'science.fall.notation.graph');
    expect(needs.single.kind, LearningNeedEvidenceKind.demonstrated);
  });

  testWidgets('未知のfocus needは別課題へ推測せず起動を拒否する', (tester) async {
    await tester.pumpWidget(
      _wrap(
        disableAnimations: true,
        focusNeedCode: 'science.fall.notation.unknown',
      ),
    );

    expect(tester.takeException(), isA<ArgumentError>());
    expect(find.text('矢印をなぞる順番'), findsNothing);
    expect(find.text('グラフと矢印を読む'), findsNothing);
  });

  testWidgets('320x568・文200%・Reduce Motionで操作面48dp以上かつoverflowしない', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(textScale: 2, disableAnimations: true, brightness: Brightness.dark),
    );

    expect(find.byType(AnimatedSwitcher), findsNothing);
    final token = find.byKey(
      const ValueKey('notation-order-token-arrow-start'),
    );
    await tester.scrollUntilVisible(token, 160, scrollable: _scrollable);
    expect(tester.getSize(token).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);

    await _tap(tester, token);
    final submit = find.byKey(const ValueKey('notation-submit'));
    await tester.scrollUntilVisible(submit, 160, scrollable: _scrollable);
    expect(tester.getSize(submit).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
