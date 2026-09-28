import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/learning/domain/learning_progress.dart';
import 'package:dekisugi/widgets/local_coop_quest_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({
  LearningLocalCoopRun? run,
  String? selected,
  VoidCallback? onStart,
  ValueChanged<String>? onSelect,
}) => MaterialApp(
  theme: buildAppTheme(Brightness.light),
  home: Scaffold(
    body: SingleChildScrollView(
      child: LocalCoopQuestPanel(
        run: run,
        selectedParticipantId: selected,
        onStart: onStart ?? () {},
        onSelectParticipant: onSelect ?? (_) {},
      ),
    ),
  ),
);

LearningLocalCoopRun _run({bool completed = false}) => LearningLocalCoopRun(
  runId: 'pair-1',
  scope: LearningScope.personal,
  questInstanceId: 'local-coop:pair-1',
  participantIds: const {'pair-1:a', 'pair-1:b'},
  contributingParticipantIds: completed
      ? const {'pair-1:a', 'pair-1:b'}
      : const {'pair-1:a'},
  progress: completed ? 2 : 1,
  target: 2,
  rewardGems: 3,
  startDay: '2026-08-10',
  endDay: '2026-08-16',
  definitionVersion: 'local-pair.v1',
  startedAt: DateTime.utc(2026, 8, 10, 4),
  completedAt: completed ? DateTime.utc(2026, 8, 10, 6) : null,
  rewardedAt: completed ? DateTime.utc(2026, 8, 10, 6) : null,
);

void main() {
  testWidgets('架空名を出さず、未完了の実participant slotだけを選べる', (tester) async {
    String? selected;
    await tester.pumpWidget(
      _host(run: _run(), onSelect: (value) => selected = value),
    );
    expect(find.textContaining('名前・回答・正誤は保存しません'), findsOneWidget);
    expect(find.textContaining('友達A'), findsNothing);
    final done = find.byKey(const ValueKey('local-coop-participant-pair-1:a'));
    final pending = find.byKey(
      const ValueKey('local-coop-participant-pair-1:b'),
    );
    await tester.tap(done);
    await tester.tap(pending);
    expect(selected, 'pair-1:b');
  });

  testWidgets('320dp・文字200%で達成と無報酬学校混入なしを読み上げる', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(2),
        ),
        child: _host(run: _run(completed: true)),
      ),
    );
    expect(find.bySemanticsLabel(RegExp('2件中2件、達成済み')), findsOneWidget);
    expect(find.textContaining('個人walletへ一度だけ'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
