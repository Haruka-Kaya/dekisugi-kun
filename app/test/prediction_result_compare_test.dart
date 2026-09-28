import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/prediction_result_compare.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('予想・教材結果・理由を同時に見せ、自己比較の1文まで完了を開けない', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    final reflection = TextEditingController();
    addTearDown(reflection.dispose);
    PredictionComparisonDecision? decision;
    var completed = 0;
    var rewrites = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: StatefulBuilder(
                builder: (context, setInnerState) => PredictionResultCompare(
                  situation: '2つの球を真空中で同時に落とす。',
                  prediction: '重い球が先に着くと思う。',
                  predictionReason: '重いほど重力が大きいと思った。',
                  result: '2つは同時に着く。',
                  explanation: '空気抵抗がなければ、落下加速度は重さによらない。',
                  sourceParagraphs: const ['重力と動かしにくさが同じ割合で変わります。'],
                  decision: decision,
                  reflectionController: reflection,
                  onDecisionChanged: (next) {
                    setInnerState(() => decision = next);
                  },
                  onReflectionChanged: () => setInnerState(() {}),
                  onRewritePrediction: () => rewrites += 1,
                  onComplete: () => completed += 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.bySemanticsLabel(RegExp(r'^チェックポイント通過。自分の予想と教材の結果を比べて')),
      findsOneWidget,
    );
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('prediction-result-compare')))
          .getSemanticsData()
          .flagsCollection
          .isLiveRegion,
      isTrue,
    );
    expect(find.text('重い球が先に着くと思う。'), findsOneWidget);
    expect(find.text('重いほど重力が大きいと思った。'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('prediction-result-prediction-reason')),
      findsOneWidget,
    );
    expect(find.text('2つは同時に着く。'), findsOneWidget);
    expect(find.text('空気抵抗がなければ、落下加速度は重さによらない。'), findsOneWidget);
    expect(find.textContaining('正解です'), findsNothing);
    expect(find.textContaining('不正解'), findsNothing);
    expect(find.textContaining('点数'), findsNothing);

    final complete = find.byKey(const ValueKey('prediction-result-complete'));
    expect(tester.widget<FilledButton>(complete).onPressed, isNull);
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('prediction-result-decision-keep')),
          )
          .height,
      greaterThanOrEqualTo(64),
    );

    final revise = find.byKey(
      const ValueKey('prediction-result-decision-revise'),
    );
    await tester.ensureVisible(revise);
    await tester.tap(revise);
    await tester.pump();
    expect(find.text('教材を見て直す理由'), findsOneWidget);
    expect(tester.widget<FilledButton>(complete).onPressed, isNull);

    final input = find.byKey(
      const ValueKey('prediction-result-reflection-input'),
    );
    await tester.ensureVisible(input);
    await tester.enterText(input, '重さではなく、落下加速度を比べる。');
    await tester.pump();
    await tester.ensureVisible(complete);
    await tester.pump();
    expect(tester.getSize(complete).height, greaterThanOrEqualTo(48));
    expect(tester.widget<FilledButton>(complete).onPressed, isNotNull);
    await tester.tap(complete);
    expect(completed, 1);

    final rewrite = find.byKey(const ValueKey('prediction-result-rewrite'));
    await tester.ensureVisible(rewrite);
    await tester.tap(rewrite);
    expect(rewrites, 1);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
