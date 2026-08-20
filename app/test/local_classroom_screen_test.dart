import 'dart:ui' show SemanticsAction;

import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/models/classroom_mission.dart';
import 'package:dekisugi/models/unit.dart';
import 'package:dekisugi/screens/local_classroom_screen.dart';
import 'package:dekisugi/screens/material_screen.dart';
import 'package:dekisugi/screens/offline_practice_screen.dart';
import 'package:dekisugi/services/local_classroom_run_store.dart';
import 'package:dekisugi/services/local_practice_store.dart';
import 'package:dekisugi/services/classroom_learning_completion.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:dekisugi/services/units_client.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:flutter_test/flutter_test.dart';

const _checkpoint = LocalCheckpoint(
  lure: '重い方が必ず先に落ちる。',
  options: [
    LocalCheckpointOption(id: 'correct', text: '空気抵抗がなければ同時に落ちる。'),
    LocalCheckpointOption(
      id: 'wrong-heavy',
      text: '重い方が先に落ちる。',
      hint: '空気抵抗を無視できる条件を見直そう。',
    ),
    LocalCheckpointOption(
      id: 'wrong-light',
      text: '軽い方が先に落ちる。',
      hint: '重さではなく加速度を比べよう。',
    ),
  ],
  correctOptionId: 'correct',
  explanation: '空気抵抗を無視すれば、重さにかかわらず同じ加速度で落ちる。',
);

const _conditionsCheckpoint = LocalCheckpoint(
  lure: '空気抵抗があっても、どんな形でも必ず同時に落ちる。',
  options: [
    LocalCheckpointOption(id: 'correct', text: '形による空気抵抗の違いをそろえる必要がある。'),
    LocalCheckpointOption(
      id: 'wrong-shape',
      text: '形は結果に影響しない。',
      hint: '空気に触れる面積を比べよう。',
    ),
    LocalCheckpointOption(
      id: 'wrong-weight',
      text: '重さだけをそろえればよい。',
      hint: '空気抵抗の条件を見直そう。',
    ),
  ],
  correctOptionId: 'correct',
  explanation: '現実の落下では、空気抵抗の条件をそろえて比べる。',
);

const _transferCheckpoint = LocalCheckpoint(
  lure: '月では羽毛だけがゆっくり落ちる。',
  options: [
    LocalCheckpointOption(id: 'correct', text: '空気のほぼない月では羽毛と重りは同時に落ちる。'),
    LocalCheckpointOption(
      id: 'wrong-feather',
      text: '羽毛は軽いので落ちない。',
      hint: '空気抵抗の有無を考えよう。',
    ),
    LocalCheckpointOption(
      id: 'wrong-moon',
      text: '月では重力がない。',
      hint: '月でも物体は地面へ落ちる。',
    ),
  ],
  correctOptionId: 'correct',
  explanation: '空気抵抗がほぼなければ、羽毛と重りは同じ加速度で落ちる。',
);

const _practiceVariants = [
  LocalPracticeVariant(
    stage: LocalPracticeStage.foundation,
    recallPrompt: 'A原理：落下の中心となる考えを説明する。',
    reasoningPrompt: 'A理由：なぜそうなるかを説明する。',
    transferPrompt: 'A場面：紙を同じ形にして落とす。',
    expectedOutcome: '同じ形の紙はほぼ同時に落ちる。',
    expectedReason: '形と空気抵抗の条件が同じなら、落下の加速度も同じだから。',
    cognitiveTask: LocalCognitiveTask.safeLegacyFallback,
    checkpoint: _checkpoint,
  ),
  LocalPracticeVariant(
    stage: LocalPracticeStage.conditions,
    recallPrompt: 'B原理：空気抵抗があるときの落下を説明する。',
    reasoningPrompt: 'B条件：比較でそろえる条件を説明する。',
    transferPrompt: 'B場面：広げた紙と丸めた紙を比べる。',
    expectedOutcome: '広げた紙より丸めた紙が先に落ちる。',
    expectedReason: '広げた紙の方が空気抵抗を大きく受けるから。',
    cognitiveTask: LocalCognitiveTask.safeLegacyFallback,
    checkpoint: _conditionsCheckpoint,
  ),
  LocalPracticeVariant(
    stage: LocalPracticeStage.transfer,
    recallPrompt: 'C原理：落下の考えを別の場面へ使う。',
    reasoningPrompt: 'C条件：地球と月の条件の違いを説明する。',
    transferPrompt: 'C場面：月で羽毛と重りを同時に離す。',
    expectedOutcome: '月では羽毛と重りが同時に落ちる。',
    expectedReason: '月には空気がほぼなく、空気抵抗の違いがほぼないから。',
    cognitiveTask: LocalCognitiveTask.safeLegacyFallback,
    checkpoint: _transferCheckpoint,
  ),
];

const _summary = UnitSummary(
  id: 'force-motion',
  title: '力と運動',
  brief: '落下を考える。',
  concepts: [
    UnitConcept(key: 'fall', label: '落下の速さ', storyTitle: '紙ひこうき部、落下レース中止事件'),
  ],
  sectionCount: 1,
);

const _detail = UnitDetail(
  summary: _summary,
  sections: [
    Section(
      conceptKey: 'fall',
      title: '落ちる速さは何で決まるか',
      body: ['空気抵抗を無視すると、物体は重さにかかわらず同じ加速度で落ちます。'],
      tryIt: '同じ形の紙を丸め、同じ高さから落とすとどうなるか予想する。',
      localCheckpoint: _checkpoint,
      localPracticeVariants: _practiceVariants,
    ),
  ],
);

class _LocalUnits extends UnitsClient {
  _LocalUnits() : super(baseUrl: '', store: MemorySessionStore());

  @override
  Future<List<UnitSummary>> list() async => const [_summary];

  @override
  Future<UnitDetail?> detail(String unitId) async =>
      unitId == _summary.id ? _detail : null;
}

Future<void> _pumpClassroom(
  WidgetTester tester, {
  required SessionStore store,
  bool largeText = false,
  Future<void> Function(ClassroomAssignment assignment, DateTime occurredAt)?
  onAssignmentCompleted,
  Future<String?> Function(BuildContext context)? scanClassroomCode,
}) => tester.pumpWidget(
  MaterialApp(
    locale: const Locale('ja'),
    theme: buildAppTheme(Brightness.light),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: largeText
            ? const TextScaler.linear(2)
            : TextScaler.noScaling,
      ),
      child: child!,
    ),
    home: LocalClassroomScreen(
      units: _LocalUnits(),
      runStore: LocalClassroomRunStore(store),
      onAssignmentCompleted: onAssignmentCompleted,
      scanClassroomCode: scanClassroomCode,
    ),
  ),
);

Future<void> _reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isNotEmpty) {
    await tester.ensureVisible(target);
    await tester.pump();
    if (target.hitTestable().evaluate().isNotEmpty) return;
  }
  for (var i = 0; i < 50; i++) {
    if (target.hitTestable().evaluate().isNotEmpty) return;
    final scrollables = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    if (scrollables.evaluate().isEmpty) break;
    final visible = scrollables.hitTestable();
    if (visible.evaluate().isEmpty) break;
    await tester.drag(visible.first, const Offset(0, -190));
    await tester.pump();
  }
  fail('操作対象を表示できませんでした: $target');
}

Future<void> _enterStep(
  WidgetTester tester, {
  required String fieldKey,
  required String buttonKey,
  required String text,
}) async {
  final input = find.descendant(
    of: find.byKey(ValueKey(fieldKey)),
    matching: find.byType(TextField),
  );
  await _reveal(tester, input);
  await tester.enterText(input, text);
  await tester.pump();
  final next = find.byKey(ValueKey(buttonKey));
  await _reveal(tester, next);
  await tester.tap(next);
  await tester.pumpAndSettle();
}

Future<LocalClassroomRun> _seedCompletedRun(
  SessionStore backing, {
  int practiceAttempt = 2,
  DateTime? completedAt,
}) async {
  final store = LocalClassroomRunStore(backing);
  await store.begin(
    unitId: 'force-motion',
    conceptKey: 'fall',
    practiceAttempt: practiceAttempt,
  );
  await store.enterPractice(
    unitId: 'force-motion',
    conceptKey: 'fall',
    practiceAttempt: practiceAttempt,
  );
  return store.complete(
    unitId: 'force-motion',
    conceptKey: 'fall',
    practiceAttempt: practiceAttempt,
    updatedAt: completedAt,
  );
}

Future<
  ({
    int attempt,
    String missionKind,
    String materialPrompt,
    String recallPrompt,
    String checkpointLure,
  })
>
_captureRoundB(
  WidgetTester tester, {
  required SessionStore store,
  required int completedCount,
}) async {
  final progress = LocalPracticeStore(store);
  for (var index = 0; index < completedCount; index++) {
    await progress.recordCompletion(
      unitId: 'force-motion',
      conceptKey: 'fall',
      completedAt: DateTime.utc(2026, 8, 1 + index),
    );
  }

  await _pumpClassroom(tester, store: store);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('local-classroom-number')),
    '01-01-B',
  );
  await tester.pump();
  final start = find.byKey(const ValueKey('local-classroom-start'));
  await _reveal(tester, start);
  await tester.tap(start);
  await tester.pumpAndSettle();

  final material = tester.widget<MaterialScreen>(find.byType(MaterialScreen));
  final section = material.unit.sectionFor('fall')!;
  final materialVariant = section.practiceVariantForAttempt(
    material.practiceAttempt,
  );
  expect(material.practiceAttempt, 1);
  expect(material.missionKind.name, 'caseRetry');
  expect(find.text(materialVariant.transferPrompt), findsOneWidget);

  // OS終了後に練習から戻る場合も、履歴を見ず保存済みroundを使う。
  await LocalClassroomRunStore(store).enterPractice(
    unitId: 'force-motion',
    conceptKey: 'fall',
    practiceAttempt: material.practiceAttempt,
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await _pumpClassroom(tester, store: store);
  await tester.pumpAndSettle();
  expect(
    tester
        .getSemantics(find.byKey(const ValueKey('local-classroom-resume-card')))
        .getSemanticsData()
        .label,
    contains('01-01-B'),
  );
  await tester.tap(find.byKey(const ValueKey('local-classroom-resume')));
  await tester.pumpAndSettle();

  final practice = tester.widget<OfflinePracticeScreen>(
    find.byType(OfflinePracticeScreen),
  );
  final practiceVariant = practice.section.practiceVariantForAttempt(
    practice.practiceAttempt,
  );
  return (
    attempt: practice.practiceAttempt,
    missionKind: practice.missionKind.name,
    materialPrompt: materialVariant.transferPrompt,
    recallPrompt: practiceVariant.recallPrompt,
    checkpointLure: practiceVariant.checkpoint.lure,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('先生の教材QRは個人情報なしで表示され、読取後も開始を確認する', (tester) async {
    final store = MemorySessionStore();
    await _pumpClassroom(
      tester,
      store: store,
      scanClassroomCode: (_) async => 'DKSC1:01-01-B',
    );
    await tester.pumpAndSettle();

    final prepare = find.byKey(
      const ValueKey('local-classroom-teacher-preparation'),
    );
    await _reveal(tester, prepare);
    await tester.tap(prepare);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('teacher-local-classroom-screen')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('participant-qr-code')), findsOneWidget);
    expect(find.textContaining('LANの管理キーは扱いません'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    final scan = find.byKey(const ValueKey('local-classroom-scan-code'));
    await _reveal(tester, scan);
    await tester.tap(scan);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('local-classroom-number')),
          )
          .controller!
          .text,
      '01-01-B',
    );
    expect(find.byType(MaterialScreen), findsNothing);
    expect(
      find.byKey(const ValueKey('local-classroom-number-match')),
      findsOneWidget,
    );
  });

  testWidgets('端末内ホームの授業入口は途中概念を読み上げ、1操作で開ける', (tester) async {
    final store = MemorySessionStore();
    await LocalClassroomRunStore(store).enterPractice(
      unitId: 'force-motion',
      conceptKey: 'fall',
      practiceAttempt: 1,
    );
    var opened = 0;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          body: LocalClassroomEntryCard(
            units: _LocalUnits(),
            runStore: LocalClassroomRunStore(store),
            onOpen: () => opened += 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final entry = find.byKey(const ValueKey('local-classroom-entry-card'));
    expect(tester.getSize(entry).height, greaterThanOrEqualTo(48));
    final data = tester.getSemantics(entry).getSemanticsData();
    expect(data.label, contains('途中の授業を再開'));
    expect(data.label, contains('01-01-B  落下の速さ'));
    expect(data.label, contains('入力内容は保存していません'));
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    await tester.tap(entry);
    expect(opened, 1);
    semantics.dispose();
  });

  testWidgets('端末内ホームの授業入口は完了を途中再開や理解済みに見せない', (tester) async {
    final store = MemorySessionStore();
    await _seedCompletedRun(
      store,
      completedAt: DateTime.utc(2026, 8, 10, 8, 30),
    );
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          body: LocalClassroomEntryCard(
            units: _LocalUnits(),
            runStore: LocalClassroomRunStore(store),
            onOpen: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final data = tester
        .getSemantics(find.byKey(const ValueKey('local-classroom-entry-card')))
        .getSemanticsData();
    expect(data.label, contains('最後に終えた授業'));
    expect(data.label, contains('01-01-C  落下の速さ'));
    expect(data.label, contains('比較フローの操作完了'));
    expect(data.label, contains('内容・理解は未確認'));
    expect(data.label, isNot(contains('途中の授業を再開')));
    semantics.dispose();
  });

  testWidgets('同じ01-01-Bは完了履歴0回と5回でも同じpromptとcheckpointに固定する', (tester) async {
    final withoutHistory = await _captureRoundB(
      tester,
      store: MemorySessionStore(),
      completedCount: 0,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final withHistory = await _captureRoundB(
      tester,
      store: MemorySessionStore(),
      completedCount: 5,
    );

    expect(withoutHistory, withHistory);
    expect(withHistory.attempt, 1);
    expect(withHistory.missionKind, 'caseRetry');
    expect(withHistory.materialPrompt, contains('B場面'));
    expect(withHistory.recallPrompt, contains('B原理'));
    expect(withHistory.checkpointLure, contains('空気抵抗'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('旧01-01を拒否し、一覧はA/B/C付きコードを明示する', (tester) async {
    final semantics = tester.ensureSemantics();
    final store = MemorySessionStore();
    await _pumpClassroom(tester, store: store);
    await tester.pumpAndSettle();

    final number = find.byKey(const ValueKey('local-classroom-number'));
    await tester.enterText(number, '01-01');
    await tester.tap(find.byKey(const ValueKey('local-classroom-start')));
    await tester.pump();
    expect(find.textContaining('A/B/Cまで含む'), findsOneWidget);
    expect(find.byType(MaterialScreen), findsNothing);

    final browse = find.byKey(const ValueKey('local-classroom-browse'));
    await _reveal(tester, browse);
    await tester.tap(browse);
    await tester.pumpAndSettle();
    expect(find.byType(ClassroomAssignmentListScreen), findsOneWidget);
    for (final code in ['01-01-A', '01-01-B', '01-01-C']) {
      final button = find.byKey(ValueKey('local-classroom-assignment-$code'));
      expect(button, findsOneWidget);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      expect(
        tester
            .getSemantics(button)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
    }

    await tester.tap(
      find.byKey(const ValueKey('local-classroom-assignment-01-01-C')),
    );
    await tester.pumpAndSettle();
    final material = tester.widget<MaterialScreen>(find.byType(MaterialScreen));
    expect(material.practiceAttempt, 2);
    expect(material.missionKind.name, 'caseRetry');
    expect(find.textContaining('C場面'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('板書番号→中断→再起動→安全な先頭から再開→回答を保存せず授業完了を残す', (tester) async {
    final store = MemorySessionStore();
    await _pumpClassroom(tester, store: store);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('local-classroom-number')),
      '１ー１ーＡ',
    );
    await tester.pump();
    expect(find.textContaining('落下の速さ'), findsOneWidget);
    final start = find.byKey(const ValueKey('local-classroom-start'));
    await _reveal(tester, start);
    await tester.tap(start);
    await tester.pumpAndSettle();

    expect(find.byType(MaterialScreen), findsOneWidget);
    expect(
      (await LocalClassroomRunStore(store).load())?.stage,
      LocalClassroomStage.material,
    );
    expect((await LocalClassroomRunStore(store).load())?.practiceAttempt, 0);

    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pumpAndSettle();
    final tactic = find.text('身近な例から');
    await tester.ensureVisible(tactic);
    await tester.tap(tactic);
    await tester.pump();
    final begin = find.widgetWithText(FilledButton, 'この作戦で挑む');
    await tester.ensureVisible(begin);
    await tester.tap(begin);
    await tester.pumpAndSettle();

    expect(find.byType(OfflinePracticeScreen), findsOneWidget);
    expect(
      (await LocalClassroomRunStore(store).load())?.stage,
      LocalClassroomStage.practice,
    );
    expect((await LocalClassroomRunStore(store).load())?.practiceAttempt, 0);

    await _enterStep(
      tester,
      fieldKey: 'offline-recall-input',
      buttonKey: 'offline-recall-next',
      text: '入力しても保存しない説明',
    );

    // OS終了を再現。同じstoreだけを渡して画面ツリーを作り直す。
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _pumpClassroom(tester, store: store);
    await tester.pumpAndSettle();

    final restoredRun = await LocalClassroomRunStore(store).load();
    expect(restoredRun?.practiceAttempt, 0);
    expect(restoredRun?.stage, LocalClassroomStage.practice);

    final resumeCard = find.byKey(
      const ValueKey('local-classroom-resume-card'),
    );
    expect(resumeCard, findsOneWidget);
    expect(
      tester.getSemantics(resumeCard).getSemanticsData().label,
      contains('入力内容は保存していないため、説明の最初から再開します'),
    );
    await tester.tap(find.byKey(const ValueKey('local-classroom-resume')));
    await tester.pumpAndSettle();

    expect(find.byType(OfflinePracticeScreen), findsOneWidget);
    expect(
      tester
          .widget<OfflinePracticeScreen>(find.byType(OfflinePracticeScreen))
          .practiceAttempt,
      0,
    );
    expect(find.byKey(const ValueKey('offline-recall-input')), findsOneWidget);
    expect(find.text('入力しても保存しない説明'), findsNothing);

    await _enterStep(
      tester,
      fieldKey: 'offline-recall-input',
      buttonKey: 'offline-recall-next',
      text: '重さだけでは決まらない。',
    );
    final taskChoice = find.byKey(
      const ValueKey('cognitive-task-choice-review-conditions'),
    );
    await _reveal(tester, taskChoice);
    await tester.tap(taskChoice);
    await tester.pump();
    final taskNext = find.byKey(const ValueKey('offline-task-next'));
    await _reveal(tester, taskNext);
    await tester.tap(taskNext);
    await tester.pumpAndSettle();
    await _enterStep(
      tester,
      fieldKey: 'offline-reasoning-input',
      buttonKey: 'offline-reasoning-next',
      text: '空気抵抗を無視できる条件で比べる。',
    );

    final correct = find.byKey(
      const ValueKey('offline-checkpoint-option-correct'),
    );
    await _reveal(tester, correct);
    await tester.tap(correct);
    await tester.pump();
    final submit = find.byKey(const ValueKey('offline-checkpoint-submit'));
    await _reveal(tester, submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    final compare = find.byKey(const ValueKey('prediction-result-compare'));
    expect(compare, findsOneWidget);
    final revise = find.byKey(
      const ValueKey('prediction-result-decision-revise'),
    );
    await _reveal(tester, revise);
    await tester.tap(revise);
    await tester.pump();
    final reflection = find.byKey(
      const ValueKey('prediction-result-reflection-input'),
    );
    await _reveal(tester, reflection);
    await tester.enterText(reflection, '重さではなく加速度を比べる。');
    await tester.pump();
    final complete = find.byKey(const ValueKey('prediction-result-complete'));
    await _reveal(tester, complete);
    await tester.tap(complete);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('offline-practice-complete')),
      findsOneWidget,
      reason: '本人が端末を教師へ見せて振り返れる面を残す',
    );
    expect(find.textContaining('01-01-A'), findsWidgets);
    expect(find.text('重さではなく加速度を比べる。'), findsWidgets);
    final completedRun = await LocalClassroomRunStore(store).load();
    expect(completedRun?.stage, LocalClassroomStage.completed);
    expect(completedRun?.practiceAttempt, 0);
    expect(await LocalPracticeStore(store).records(), isEmpty);
    final raw = await store.getSetting(LocalClassroomRunStore.settingKey);
    expect(raw, isNotNull);
    expect(raw, isNot(contains('重さではなく加速度を比べる。')));
    expect(raw, isNot(contains('空気抵抗を無視できる条件で比べる。')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('学校Cの完了は個人回数を変えず、再起動後に正確なroundだけを示す', (tester) async {
    final store = MemorySessionStore();
    var completionCount = 0;
    ClassroomAssignment? completedAssignment;
    DateTime? publishedAt;
    final progress = LocalPracticeStore(store);
    final personalAt = DateTime.utc(2026, 8, 1, 1);
    await progress.recordCompletion(
      unitId: 'force-motion',
      conceptKey: 'fall',
      completedAt: personalAt,
    );
    final personalRawBefore = await store.getSetting(
      LocalPracticeStore.settingKey,
    );
    await LocalClassroomRunStore(store).enterPractice(
      unitId: 'force-motion',
      conceptKey: 'fall',
      practiceAttempt: 2,
    );

    await _pumpClassroom(
      tester,
      store: store,
      onAssignmentCompleted: (assignment, occurredAt) async {
        completionCount++;
        completedAssignment = assignment;
        publishedAt = occurredAt;
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('local-classroom-resume')));
    await tester.pumpAndSettle();
    final practice = tester.widget<OfflinePracticeScreen>(
      find.byType(OfflinePracticeScreen),
    );
    expect(practice.practiceAttempt, 2);
    expect(practice.completionReference, '01-01-C');

    await practice.onCheckpointCompleted!.call();
    final firstCompleted = await LocalClassroomRunStore(store).load();
    expect(firstCompleted?.stage, LocalClassroomStage.completed);
    expect(firstCompleted?.practiceAttempt, 2);
    await practice.onCheckpointCompleted!.call();
    final afterDuplicate = await LocalClassroomRunStore(store).load();
    expect(
      afterDuplicate?.updatedAt,
      firstCompleted?.updatedAt,
      reason: '同じ完了callbackで時刻を動かさない',
    );
    expect(completionCount, 1);
    expect(completedAssignment?.id, 'force-motion/fall/2');
    expect(completedAssignment?.round, ClassroomRound.c);
    expect(publishedAt, firstCompleted?.updatedAt);
    expect(
      await store.getSetting(LocalPracticeStore.settingKey),
      personalRawBefore,
      reason: '学校の明示roundを個人completedCountへ混ぜない',
    );
    final personal = await progress.records();
    expect(personal.single.completedCount, 1);
    expect(personal.single.lastCompletedAt, personalAt);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final semantics = tester.ensureSemantics();
    await _pumpClassroom(tester, store: store);
    await tester.pumpAndSettle();
    final completedCard = find.byKey(
      const ValueKey('local-classroom-completed-card'),
    );
    final label = tester.getSemantics(completedCard).getSemanticsData().label;
    expect(label, contains('教材番号01-01-C'));
    expect(label, contains('別の場面へ使う'));
    expect(label, contains('完了日時'));
    expect(label, contains('比較フローの操作完了'));
    expect(label, contains('内容と理解は未確認'));
    expect(label, contains('個人練習のローテーションには加えていません'));
    expect(find.byKey(const ValueKey('local-classroom-resume')), findsNothing);
    expect(
      find.byKey(const ValueKey('local-classroom-repeat-completed')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('台帳commit初回失敗後も再生成時にcompleted runから同じ完了時刻で回復する', (tester) async {
    final store = MemorySessionStore();
    final personalBefore = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    await LocalClassroomRunStore(store).enterPractice(
      unitId: 'force-motion',
      conceptKey: 'fall',
      practiceAttempt: 1,
      updatedAt: DateTime.utc(2026, 8, 10, 8),
    );
    var callbackCount = 0;
    final receivedAssignments = <ClassroomAssignment>[];
    final receivedTimes = <DateTime>[];

    Future<void> publish(
      ClassroomAssignment assignment,
      DateTime occurredAt,
    ) async {
      callbackCount++;
      receivedAssignments.add(assignment);
      receivedTimes.add(occurredAt);
      if (callbackCount == 1) throw StateError('simulated commit failure');
      await ClassroomLearningCompletion.commit(
        store: store,
        assignment: assignment,
        occurredAt: occurredAt,
      );
    }

    await _pumpClassroom(tester, store: store, onAssignmentCompleted: publish);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('local-classroom-resume')));
    await tester.pumpAndSettle();
    final practice = tester.widget<OfflinePracticeScreen>(
      find.byType(OfflinePracticeScreen),
    );
    await expectLater(
      practice.onCheckpointCompleted!.call(),
      throwsA(isA<StateError>()),
    );
    final completed = await LocalClassroomRunStore(store).load();
    expect(completed?.stage, LocalClassroomStage.completed);
    expect(
      (await store.learningProgressSnapshot(LearningScope.schoolLocal)).events,
      isEmpty,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await _pumpClassroom(tester, store: store, onAssignmentCompleted: publish);
    await tester.pumpAndSettle();

    expect(callbackCount, 2);
    expect(receivedAssignments.map((item) => item.id), [
      'force-motion/fall/1',
      'force-motion/fall/1',
    ]);
    expect(receivedTimes, [completed?.updatedAt, completed?.updatedAt]);
    final school = await store.learningProgressSnapshot(
      LearningScope.schoolLocal,
    );
    expect(school.events, hasLength(1));
    expect(
      school.events.single.nodeId,
      'classroom:v1:force-motion:fall:round-b',
    );
    expect(school.rewards, isEmpty);

    final personalAfter = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(personalAfter.events, hasLength(personalBefore.events.length));
    expect(personalAfter.nodes, hasLength(personalBefore.nodes.length));
    expect(personalAfter.wallet.xp, personalBefore.wallet.xp);
    expect(personalAfter.wallet.gems, personalBefore.wallet.gems);
    final raw = await store.getSetting(LocalClassroomRunStore.settingKey);
    expect(raw, isNot(contains('空気抵抗を無視すると')));
    expect(raw, isNot(contains('正しい説明')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('完了カードから同じコードを再実行できる', (tester) async {
    final store = MemorySessionStore();
    await _seedCompletedRun(store);
    await _pumpClassroom(tester, store: store);
    await tester.pumpAndSettle();

    final repeat = find.byKey(
      const ValueKey('local-classroom-repeat-completed'),
    );
    await _reveal(tester, repeat);
    await tester.tap(repeat);
    await tester.pumpAndSettle();
    final repeatedMaterial = tester.widget<MaterialScreen>(
      find.byType(MaterialScreen),
    );
    expect(repeatedMaterial.practiceAttempt, 2);
    expect(
      (await LocalClassroomRunStore(store).load())?.stage,
      LocalClassroomStage.material,
    );
  });

  testWidgets('新しいコード開始では最後の完了表示を上書きすると明示する', (tester) async {
    final store = MemorySessionStore();
    await _seedCompletedRun(store);
    await _pumpClassroom(tester, store: store);
    await tester.pumpAndSettle();

    final number = find.byKey(const ValueKey('local-classroom-number'));
    await _reveal(tester, number);
    await tester.enterText(number, '01-01-A');
    await tester.pump();
    final start = find.byKey(const ValueKey('local-classroom-start'));
    await _reveal(tester, start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(find.text('最後の完了表示を入れ替えますか？'), findsOneWidget);
    expect(find.textContaining('新しい教材の再開位置に入れ替わります'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '完了表示を残す'));
    await tester.pumpAndSettle();
    expect(
      (await LocalClassroomRunStore(store).load())?.stage,
      LocalClassroomStage.completed,
    );

    await _reveal(tester, start);
    await tester.tap(start);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '新しい教材を始める'));
    await tester.pumpAndSettle();
    final newMaterial = tester.widget<MaterialScreen>(
      find.byType(MaterialScreen),
    );
    expect(newMaterial.practiceAttempt, 0);
    final replaced = await LocalClassroomRunStore(store).load();
    expect(replaced?.stage, LocalClassroomStage.material);
    expect(replaced?.practiceAttempt, 0);
  });

  testWidgets('最後の完了表示は確認後にだけ削除する', (tester) async {
    final store = MemorySessionStore();
    await _seedCompletedRun(store);
    await _pumpClassroom(tester, store: store);
    await tester.pumpAndSettle();

    final discard = find.byKey(
      const ValueKey('local-classroom-discard-completed'),
    );
    await _reveal(tester, discard);
    await tester.tap(discard);
    await tester.pumpAndSettle();
    expect(find.text('最後の完了表示を消しますか？'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '完了表示を残す'));
    await tester.pumpAndSettle();
    expect(await LocalClassroomRunStore(store).load(), isNotNull);

    await tester.tap(discard);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '完了表示を消す'));
    await tester.pumpAndSettle();
    expect(await LocalClassroomRunStore(store).load(), isNull);
    expect(
      find.byKey(const ValueKey('local-classroom-completed-card')),
      findsNothing,
    );
  });

  testWidgets('320x568・文字200%で教材番号と再開操作が48dp以上かつ読み上げ可能', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    final store = MemorySessionStore();
    await LocalClassroomRunStore(store).enterPractice(
      unitId: 'force-motion',
      conceptKey: 'fall',
      practiceAttempt: 1,
    );

    await _pumpClassroom(tester, store: store, largeText: true);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final privacy = find.byKey(const ValueKey('local-classroom-privacy'));
    await _reveal(tester, privacy);
    expect(
      tester.getSemantics(privacy).getSemanticsData().label,
      contains('アカウント、生徒名、学校・学級、回答本文は保存しません'),
    );

    final resume = find.byKey(const ValueKey('local-classroom-resume'));
    await _reveal(tester, resume);
    expect(tester.getSize(resume).height, greaterThanOrEqualTo(48));
    expect(
      tester
          .getSemantics(resume)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );

    final number = find.byKey(const ValueKey('local-classroom-number'));
    await _reveal(tester, number);
    expect(tester.getSize(number).height, greaterThanOrEqualTo(48));
    await tester.enterText(number, '01-01-B');
    await tester.pump();
    final match = find.byKey(const ValueKey('local-classroom-number-match'));
    await _reveal(tester, match);
    expect(
      tester.getSemantics(match).getSemanticsData().label,
      contains('教材番号01-01-B、落下の速さ、力と運動、条件を見分ける'),
    );

    final start = find.byKey(const ValueKey('local-classroom-start'));
    await _reveal(tester, start);
    expect(tester.getSize(start).height, greaterThanOrEqualTo(48));
    expect(start.hitTestable(), findsOneWidget);
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(
      find.byType(OfflinePracticeScreen),
      findsOneWidget,
      reason: '同じ番号は途中位置を消して教材からやり直さず、練習を再開する',
    );
    expect(find.byType(MaterialScreen), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('320x568・文字200%で完了証拠と再実行・削除を読み上げて操作できる', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    final store = MemorySessionStore();
    await _seedCompletedRun(
      store,
      completedAt: DateTime.utc(2026, 8, 10, 8, 30),
    );

    await _pumpClassroom(tester, store: store, largeText: true);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final completed = find.byKey(
      const ValueKey('local-classroom-completed-card'),
    );
    await _reveal(tester, completed);
    final label = tester.getSemantics(completed).getSemanticsData().label;
    expect(label, contains('教材番号01-01-C'));
    expect(label, contains('比較フローの操作完了'));
    expect(label, contains('内容と理解は未確認'));
    expect(label, contains('回答本文は保存していません'));

    for (final key in [
      'local-classroom-repeat-completed',
      'local-classroom-discard-completed',
    ]) {
      final action = find.byKey(ValueKey(key));
      await _reveal(tester, action);
      expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
      expect(
        tester
            .getSemantics(action)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
    }
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('別教材への切替と途中記録の削除は確認なしに実行しない', (tester) async {
    final store = MemorySessionStore();
    await LocalClassroomRunStore(
      store,
    ).begin(unitId: 'force-motion', conceptKey: 'fall', practiceAttempt: 2);
    await _pumpClassroom(tester, store: store);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('local-classroom-discard')));
    await tester.pumpAndSettle();
    expect(find.text('途中の再開位置を消しますか？'), findsOneWidget);
    expect(await LocalClassroomRunStore(store).load(), isNotNull);

    await tester.tap(find.widgetWithText(TextButton, '再開位置を残す'));
    await tester.pumpAndSettle();
    expect(await LocalClassroomRunStore(store).load(), isNotNull);

    await tester.tap(find.byKey(const ValueKey('local-classroom-discard')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '再開位置を消す'));
    await tester.pumpAndSettle();
    expect(await LocalClassroomRunStore(store).load(), isNull);
  });
}
