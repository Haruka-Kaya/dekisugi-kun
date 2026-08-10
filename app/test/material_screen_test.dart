import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/models/mission.dart';
import 'package:dekisugi/models/unit.dart';
import 'package:dekisugi/screens/material_screen.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:flutter_test/flutter_test.dart';

const _checkpoint = LocalCheckpoint(
  lure: '教材には表示しない固定思い込み。',
  options: [
    LocalCheckpointOption(id: 'correct', text: '正しい直し方。'),
    LocalCheckpointOption(id: 'wrong-1', text: '誤答1。', hint: 'ヒント1。'),
    LocalCheckpointOption(id: 'wrong-2', text: '誤答2。', hint: 'ヒント2。'),
  ],
  correctOptionId: 'correct',
  explanation: 'checkpoint後だけ表示する正答説明。',
);

Section section(String key, {int paragraphs = 2, String? title}) => Section(
  conceptKey: key,
  title: title ?? '$key の話',
  body: [for (var i = 0; i < paragraphs; i++) '$key の段落$i。' * 12],
  tryIt: '$key を手を動かして確かめる。',
  localCheckpoint: _checkpoint,
);

UnitDetail unit({List<Section>? sections}) => UnitDetail(
  summary: const UnitSummary(
    id: 'force-motion',
    title: '力と運動',
    brief: 'ざっくりした紹介。',
    concepts: [
      UnitConcept(key: 'fall', label: '落下の速さ', storyTitle: '紙ひこうき部、落下レース中止事件'),
    ],
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
            onDone: (_) => done = true,
          ),
        ),
      );
      expect(find.text('もどる'), findsNothing, reason: '行き止まりになっている');

      // 最後まで読んでから進む
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('身近な例から'));
      await tester.pump();
      final cta = find.byType(FilledButton);
      expect(cta, findsOneWidget);
      await tester.tap(cta);
      expect(done, isTrue, reason: '会話へ進めない');
    });

    testWidgets('対象の節が欠けても単元全体のミッションへ広げない', (tester) async {
      await tester.pumpWidget(
        wrap(
          MaterialScreen(
            unit: unit(),
            focusConceptKey: 'missing-concept',
            onDone: (_) => fail('欠けた教材から会話へ進んだ'),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('教材を読み込めませんでした'), findsOneWidget);
      expect(find.text('fall の話'), findsNothing);
      expect(find.text('inertia の話'), findsNothing);
      expect(find.text('この作戦で挑む'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('復習からの読み直しは会話へ進まない', (tester) async {
      await tester.pumpWidget(
        wrap(
          MaterialScreen(
            unit: unit(),
            focusConceptKey: 'fall',
            review: true,
            onDone: (_) {},
          ),
        ),
      );
      final done = find.widgetWithText(FilledButton, '読み終えた');
      expect(done, findsOneWidget);
      expect(tester.widget<FilledButton>(done).onPressed, isNull);

      await tester.drag(find.byType(ListView), const Offset(0, -4000));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(done).onPressed, isNotNull);
    });

    testWidgets('このあと説明することを先に伝える（C1）', (tester) async {
      await tester.pumpWidget(
        wrap(MaterialScreen(unit: unit(), onDone: (_) {})),
      );
      expect(find.textContaining('思い込みを見破ります'), findsOneWidget);
      // **会話中に見られないことを先に言う。** 不意に消えると裏切りになる
      expect(find.textContaining('見られません'), findsOneWidget);
    });

    testWidgets('読み終わるまで進めない', (tester) async {
      // 読まずに会話へ入ると「説明できない」だけの体験になり、
      // 誤概念を訂正できなくても、習っていないからなのか区別がつかない
      await tester.pumpWidget(
        wrap(MaterialScreen(unit: unit(), onDone: (_) {})),
      );
      await tester.pump();

      final button = find.widgetWithText(FilledButton, 'この作戦で挑む');
      expect(button, findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(find.textContaining('最後まで読んで'), findsOneWidget);
    });

    testWidgets('最後まで送ると進める', (tester) async {
      TeachingTactic? chosen;
      await tester.pumpWidget(
        wrap(MaterialScreen(unit: unit(), onDone: (value) => chosen = value)),
      );
      await tester.pump();

      await tester.fling(find.byType(ListView), const Offset(0, -1000), 10000);
      await tester.pumpAndSettle();

      final button = find.widgetWithText(FilledButton, 'この作戦で挑む');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.tap(find.text('身近な例から'));
      await tester.pump();
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      await tester.tap(button);
      expect(chosen, TeachingTactic.example);
    });

    testWidgets('完了を連打しても会話遷移を1回しか呼ばない', (tester) async {
      var done = 0;
      await tester.pumpWidget(
        wrap(MaterialScreen(unit: unit(), onDone: (_) => done++)),
      );
      await tester.drag(find.byType(ListView), const Offset(0, -4000));
      await tester.pumpAndSettle();

      await tester.tap(find.text('しくみ・理由から'));
      await tester.pump();
      final button = find.widgetWithText(FilledButton, 'この作戦で挑む');
      final onPressed = tester.widget<FilledButton>(button).onPressed!;
      onPressed();
      onPressed();

      expect(done, 1, reason: 'Talk が二重 push される');
    });

    testWidgets('1画面に収まるときも進める', (tester) async {
      // スクロールが起きない短い教材で、永久に押せなくならないこと
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrap(
          MaterialScreen(
            unit: unit(sections: [section('fall', paragraphs: 1)]),
            onDone: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(position.maxScrollExtent, 0, reason: 'テスト名どおり、本文が1画面に収まっている前提');
      final button = find.widgetWithText(FilledButton, 'この作戦で挑む');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      await tester.tap(find.text('試したことから'));
      await tester.pump();
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    });

    testWidgets('やってみるを出す', (tester) async {
      await tester.pumpWidget(
        wrap(MaterialScreen(unit: unit(), onDone: (_) {})),
      );
      expect(find.text('やってみる'), findsWidgets);
    });

    testWidgets('端末内checkpointのlure・選択肢・正答説明を教材画面へ漏らさない', (tester) async {
      await tester.pumpWidget(
        wrap(MaterialScreen(unit: unit(), onDone: (_) {})),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -4000));
      await tester.pumpAndSettle();
      expect(find.textContaining(_checkpoint.lure), findsNothing);
      for (final option in _checkpoint.options) {
        expect(find.text(option.text), findsNothing);
      }
      expect(find.text(_checkpoint.explanation), findsNothing);
    });

    testWidgets('CASEは具体場面だけを出し、教材本文と作戦3択を隠す', (tester) async {
      TeachingTactic? chosen;
      final target = Section(
        conceptKey: 'fall',
        title: '月で落としたら',
        body: const ['正解につながる教材本文はここにある。'],
        tryIt: '月で同じ形の重い球と軽い球を同時に落とす。どうなる？',
        localCheckpoint: _checkpoint,
      );
      await tester.pumpWidget(
        wrap(
          MaterialScreen(
            unit: unit(sections: [target]),
            focusConceptKey: 'fall',
            missionKind: MissionKind.caseRetry,
            onDone: (value) => chosen = value,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('CASE 1/3'), findsOneWidget);
      expect(find.textContaining('月で同じ形'), findsOneWidget);
      expect(find.textContaining('正解につながる教材本文'), findsNothing);
      expect(find.text('どの作戦で教える？'), findsNothing);
      expect(find.text('身近な例から'), findsNothing);

      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      final button = find.widgetWithText(FilledButton, '予想と理由を話す');
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      await tester.tap(button);
      expect(chosen, TeachingTactic.reason);
    });

    testWidgets('CASEはpracticeAttemptと同じvariantの場面だけを出す', (tester) async {
      final target = Section(
        conceptKey: 'fall',
        title: '落下の速さ',
        body: const ['ここには初回教材の答えがある。'],
        tryIt: '旧クライアント用の初回場面。',
        localCheckpoint: _checkpoint,
        localPracticeVariants: const [
          LocalPracticeVariant(
            stage: LocalPracticeStage.foundation,
            recallPrompt: '原理を思い出す。',
            reasoningPrompt: '原理の理由を書く。',
            transferPrompt: 'Aの場面を予想する。',
            expectedOutcome: 'Aの結果。',
            expectedReason: 'Aの理由。',
            cognitiveTask: LocalCognitiveTask.safeLegacyFallback,
            checkpoint: _checkpoint,
          ),
          LocalPracticeVariant(
            stage: LocalPracticeStage.conditions,
            recallPrompt: '条件を思い出す。',
            reasoningPrompt: '条件を区別する。',
            transferPrompt: 'Bの条件を変えた場面を予想する。',
            expectedOutcome: 'Bの結果。',
            expectedReason: 'Bの理由。',
            cognitiveTask: LocalCognitiveTask.safeLegacyFallback,
            checkpoint: _checkpoint,
          ),
          LocalPracticeVariant(
            stage: LocalPracticeStage.transfer,
            recallPrompt: '転移の原理を思い出す。',
            reasoningPrompt: '転移の理由を書く。',
            transferPrompt: 'Cの未見場面を予想する。',
            expectedOutcome: 'Cの結果。',
            expectedReason: 'Cの理由。',
            cognitiveTask: LocalCognitiveTask.safeLegacyFallback,
            checkpoint: _checkpoint,
          ),
        ],
      );

      await tester.pumpWidget(
        wrap(
          MaterialScreen(
            unit: unit(sections: [target]),
            focusConceptKey: 'fall',
            missionKind: MissionKind.caseRetry,
            practiceAttempt: 1,
            onDone: (_) {},
          ),
        ),
      );

      expect(find.text('Bの条件を変えた場面を予想する。'), findsOneWidget);
      expect(find.text('Aの場面を予想する。'), findsNothing);
      expect(find.text('旧クライアント用の初回場面。'), findsNothing);
      expect(find.text('ここには初回教材の答えがある。'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CASE場面が欠けていれば通常教材へフォールバックしない', (tester) async {
      final target = Section(
        conceptKey: 'fall',
        title: '落下',
        body: const ['教材本文'],
        tryIt: '',
        localCheckpoint: _checkpoint,
      );
      await tester.pumpWidget(
        wrap(
          MaterialScreen(
            unit: unit(sections: [target]),
            focusConceptKey: 'fall',
            missionKind: MissionKind.caseRetry,
            onDone: (_) => fail('CASEがないのに会話へ進んだ'),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('教材を読み込めませんでした'), findsOneWidget);
      expect(find.text('教材本文'), findsNothing);
      expect(find.text('予想と理由を話す'), findsNothing);
    });

    testWidgets('320dp・文字200%でも導入情報が横にはみ出さない', (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(MaterialScreen(unit: unit(), onDone: (_) {}), textScale: 2),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('力と運動'), findsOneWidget);
      await tester.fling(find.byType(ListView), const Offset(0, -1000), 10000);
      await tester.pumpAndSettle();
      expect(find.text('この作戦で挑む'), findsOneWidget);
      expect(find.text('身近な例から'), findsOneWidget);
      expect(tester.takeException(), isNull);
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
      await pumpWide(tester, MaterialScreen(unit: unit(), onDone: (_) {}));
      final box = tester.getSize(find.byType(ListView));
      expect(box.width, lessThanOrEqualTo(640), reason: '1行が長くなりすぎる');
    });

    testWidgets('広い画面でも操作が消えない', (tester) async {
      // ReadableWidth の Align が高さいっぱいに広がって
      // 下のバーが画面を占領し、本文が消えたことがある
      await pumpWide(tester, MaterialScreen(unit: unit(), onDone: (_) {}));
      expect(find.textContaining('思い込みを見破ります'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'この作戦で挑む'), findsOneWidget);
    });
  });

  group('復習から開いたとき', () {
    testWidgets('その節だけを出す', (tester) async {
      await tester.pumpWidget(
        wrap(
          MaterialScreen(
            unit: unit(),
            focusConceptKey: 'inertia',
            onDone: (_) {},
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
            onDone: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('この作戦で挑む'), findsNothing);
      expect(find.widgetWithText(FilledButton, '読み終えた'), findsOneWidget);
      expect(find.byTooltip('もどる'), findsOneWidget);
      expect(find.text('力と運動'), findsOneWidget, reason: '読み直し中も現在の単元名が必要');
    });

    testWidgets('読み直す節が無くても単元全体へ広げない', (tester) async {
      await tester.pumpWidget(
        wrap(
          MaterialScreen(
            unit: unit(),
            focusConceptKey: 'nope',
            review: true,
            onDone: (_) {},
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('教材を読み込めませんでした'), findsOneWidget);
      expect(find.text('fall の話'), findsNothing);
      expect(find.widgetWithText(FilledButton, '読み終えた'), findsNothing);
    });
  });
}
