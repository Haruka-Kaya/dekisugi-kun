import 'dart:async';

import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/models/unit.dart';
import 'package:dekisugi/screens/material_screen.dart';
import 'package:dekisugi/screens/unit_picker_screen.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:dekisugi/services/units_client.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:flutter_test/flutter_test.dart';

const _checkpoint = LocalCheckpoint(
  lure: '固定思い込み。',
  options: [
    LocalCheckpointOption(id: 'correct', text: '正答。'),
    LocalCheckpointOption(id: 'wrong-1', text: '誤答1。', hint: 'ヒント1。'),
    LocalCheckpointOption(id: 'wrong-2', text: '誤答2。', hint: 'ヒント2。'),
  ],
  correctOptionId: 'correct',
  explanation: '正答説明。',
);

const _summary = UnitSummary(
  id: 'force-motion',
  title: '力と運動',
  brief:
      'ものが落ちる速さ、動き続けるとき、止まるとき。'
      '力がはたらいているかどうかを、動きから読み取る単元です。',
  concepts: [
    UnitConcept(key: 'fall', label: '落下の速さ', storyTitle: '落下事件'),
    UnitConcept(key: 'inertia', label: '止まる理由', storyTitle: '慣性事件'),
  ],
  sectionCount: 2,
);

const _completeDetail = UnitDetail(
  summary: _summary,
  sections: [
    Section(
      conceptKey: 'fall',
      title: '落下の速さ',
      body: ['重力だけがはたらくときの動きを確かめよう。'],
      tryIt: '紙を丸めて落とす。',
      localCheckpoint: _checkpoint,
    ),
    Section(
      conceptKey: 'inertia',
      title: '止まる理由',
      body: ['動き続けるものには、どんな力がはたらくだろう。'],
      tryIt: '机の上で消しゴムをすべらせる。',
      localCheckpoint: _checkpoint,
    ),
  ],
);

class _ControlledUnitsClient extends UnitsClient {
  _ControlledUnitsClient({required this.onDetail})
    : super(baseUrl: '', store: MemorySessionStore());

  final Future<UnitDetail?> Function(String unitId) onDetail;
  int detailCalls = 0;

  @override
  Future<List<UnitSummary>> list() async => const [_summary];

  @override
  Future<UnitDetail?> detail(String unitId) {
    detailCalls += 1;
    return onDetail(unitId);
  }
}

class _PreparedCatalogClient extends UnitsClient {
  _PreparedCatalogClient({required this.summaries, required this.details})
    : super(baseUrl: '', store: MemorySessionStore());

  final List<UnitSummary> summaries;
  final Map<String, UnitDetail> details;

  @override
  Future<List<UnitSummary>> list() async => summaries;

  @override
  Future<UnitDetail?> detail(String unitId) async => details[unitId];
}

/// 新規インストールから教材本文までの実導線を、画面間遷移ごと通す。
class _OfflineLearningJourney extends StatelessWidget {
  const _OfflineLearningJourney({required this.units});

  final UnitsClient units;

  @override
  Widget build(BuildContext context) => UnitPickerScreen(
    units: units,
    onPick: (unit, conceptKey) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MaterialScreen(
            unit: unit,
            focusConceptKey: conceptKey,
            onDone: (_) {},
          ),
        ),
      );
    },
  );
}

Future<void> _pumpPicker(
  WidgetTester tester, {
  required UnitsClient units,
  required void Function(UnitDetail unit, String conceptKey) onPick,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(Brightness.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: UnitPickerScreen(units: units, onPick: onPick, onOpenReview: () {}),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('完全新規でもPickerから実同梱教材本文を開ける', (tester) async {
    // schema v3は33問分を含み50KBを超えるため、rootBundle.loadStringが
    // 背景isolateを使う。正本の読み込みはrunAsyncで検証し、Widget側には
    // その実データを渡してfake clockとisolateの待機を混ぜない。
    final source = UnitsClient(baseUrl: '', store: MemorySessionStore());
    final bundled = await tester.runAsync(source.list);
    final forceMotion = await tester.runAsync(
      () => source.detail('force-motion'),
    );
    expect(bundled, isNotEmpty);
    expect(forceMotion, isNotNull);
    final units = _PreparedCatalogClient(
      summaries: bundled!,
      details: {'force-motion': forceMotion!},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: _OfflineLearningJourney(units: units),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('力と運動'), findsOneWidget);
    final mission = find.byKey(const ValueKey('mission-force-motion-fall'));
    await tester.ensureVisible(mission);
    await tester.tap(mission);
    await tester.pumpAndSettle();

    expect(find.byType(MaterialScreen), findsOneWidget);
    expect(find.text('落ちる速さは何で決まるか'), findsOneWidget);
    expect(find.text('やってみる'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'この作戦で挑む'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320dp・文字200%でも概念ミッションが溢れず48dp以上', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final units = _ControlledUnitsClient(
      onDetail: (_) async => _completeDetail,
    );

    await _pumpPicker(tester, units: units, onPick: (_, _) {}, textScale: 2);

    expect(tester.takeException(), isNull);
    expect(find.text('挑むミッションを選ぼう'), findsOneWidget);
    final route = find.text('対象を選ぶ  →  教材で確かめる  →  思い込みを見破る');
    await tester.scrollUntilVisible(
      route,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(route, findsOneWidget);

    final missionKeys = [
      const ValueKey('mission-force-motion-fall'),
      const ValueKey('mission-force-motion-inertia'),
    ];
    for (final key in missionKeys) {
      final finder = find.byKey(key);
      await tester.scrollUntilVisible(
        finder,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(finder, findsOneWidget);
      expect(tester.getSize(finder).height, greaterThanOrEqualTo(48));
      expect(finder.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('概念を選ぶとdetailを1回だけ取得し、教材とconceptKeyを返す', (tester) async {
    final gate = Completer<UnitDetail?>();
    final units = _ControlledUnitsClient(onDetail: (_) => gate.future);
    final picks = <({UnitDetail unit, String conceptKey})>[];

    await _pumpPicker(
      tester,
      units: units,
      onPick: (unit, conceptKey) {
        picks.add((unit: unit, conceptKey: conceptKey));
      },
    );

    final fall = find.byKey(const ValueKey('mission-force-motion-fall'));
    await tester.tap(fall);
    await tester.tap(fall);
    await tester.pump();

    expect(units.detailCalls, 1, reason: '連打しても教材取得は one-shot');
    expect(picks, isEmpty);
    expect(find.text('教材を準備中…'), findsOneWidget);

    gate.complete(_completeDetail);
    await tester.pumpAndSettle();

    expect(picks, hasLength(1));
    expect(picks.single.unit, same(_completeDetail));
    expect(picks.single.conceptKey, 'fall');
  });

  testWidgets('選んだ概念の教材が無いとミッションを始めない', (tester) async {
    const detailWithoutFall = UnitDetail(
      summary: _summary,
      sections: [
        Section(
          conceptKey: 'inertia',
          title: '止まる理由',
          body: ['この教材はある。'],
          tryIt: '確かめる。',
          localCheckpoint: _checkpoint,
        ),
      ],
    );
    final units = _ControlledUnitsClient(
      onDetail: (_) async => detailWithoutFall,
    );
    final picks = <String>[];

    await _pumpPicker(
      tester,
      units: units,
      onPick: (_, conceptKey) => picks.add(conceptKey),
    );
    await tester.tap(find.byKey(const ValueKey('mission-force-motion-fall')));
    await tester.pumpAndSettle();

    expect(units.detailCalls, 1);
    expect(picks, isEmpty);
    expect(find.textContaining('「落下の速さ」の教材を読み込めませんでした'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mission-force-motion-fall')),
      findsOneWidget,
      reason: 'エラー後は再挑戦できる',
    );
  });

  testWidgets('各概念は学習ゴールを含む独立したボタンとして読まれる', (tester) async {
    final units = _ControlledUnitsClient(
      onDetail: (_) async => _completeDetail,
    );
    final semantics = tester.ensureSemantics();
    try {
      await _pumpPicker(tester, units: units, onPick: (_, _) {});

      expect(
        find.bySemanticsLabel(
          'ミッション「落下の速さ」を始める。'
          '教材で確かめて、デキすぎ君の思い込みを見破る。',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'ミッション「止まる理由」を始める。'
          '教材で確かめて、デキすぎ君の思い込みを見破る。',
        ),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
  });
}
