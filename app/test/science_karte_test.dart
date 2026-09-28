import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/learning/domain/learning_progress.dart';
import 'package:dekisugi/learning/services/learning_karte_projection.dart';
import 'package:dekisugi/models/unit.dart';
import 'package:dekisugi/screens/science_karte_screen.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _misconception = UnitConceptMisconception(
  id: 'M01',
  statement: '止まっている物には力がはたらかない。',
  correct: '止まっていても重力などの力がはたらき、つり合っている。',
);

const _catalog = [
  UnitSummary(
    id: 'force-motion',
    title: '力と運動',
    brief: '力と運動を説明する',
    concepts: [
      UnitConcept(
        key: 'fall',
        label: '落下',
        storyTitle: '落下事件',
        misconception: _misconception,
      ),
      UnitConcept(key: 'inertia', label: '慣性', storyTitle: '慣性事件'),
    ],
    sectionCount: 2,
  ),
];

LearningNeedStateView needState({
  String skillId = 'force-motion/fall',
  String needCode = 'science.fall.foundation',
  String? firstDay = '2026-08-10',
  String? lastDay = '2026-08-10',
  String? resolvedDay,
}) => LearningNeedStateView(
  scope: LearningScope.personal,
  skillId: skillId,
  needCode: needCode,
  firstObservedDay: firstDay,
  lastObservedDay: lastDay,
  resolvedDay: resolvedDay,
);

LearningEventCommand needEvent({
  required String eventId,
  required String nodeId,
  required String learningDay,
  required DateTime occurredAt,
  required LearningAttemptOutcome outcome,
  required LearningEvidenceLevel evidence,
  Map<String, Iterable<String>> observed = const {},
  Map<String, Iterable<String>> resolved = const {},
  LearningRepairResolution? repairResolution,
}) => LearningEventCommand(
  eventId: eventId,
  scope: LearningScope.personal,
  origin: LearningOrigin.practice,
  courseId: 'course.jhs-science',
  nodeId: nodeId,
  activityId: 'activity.karte.v1',
  skillIds: const {'force-motion/fall'},
  activityKind: LearningActivityKind.diagram,
  outcome: outcome,
  evidence: evidence,
  contentVersion: 'catalog.v10',
  learningDay: learningDay,
  occurredAt: occurredAt,
  practiceNeedCodes: observed,
  resolvedPracticeNeedCodes: resolved,
  repairResolution: repairResolution,
);

final _repairFoundation = LearningRepairResolution(
  unitId: 'force-motion',
  conceptKey: 'fall',
  skillId: 'force-motion/fall',
  needCode: 'science.fall.foundation',
  routeKind: LearningRepairRouteKind.practice,
  practiceAttempt: 0,
);

void main() {
  group('LearningKarteProjection', () {
    test('active・resolved・未観測をconcept単位で分けて数える', () {
      final view = const LearningKarteProjection().build(
        catalog: _catalog,
        needStates: [
          needState(),
          needState(
            needCode: 'science.fall.conditions',
            resolvedDay: '2026-08-12',
          ),
        ],
        skills: const [],
      );

      expect(view.summary.conceptCount, 2);
      expect(view.summary.taughtCount, 1);
      expect(view.summary.activeNeedCount, 1);
      expect(view.summary.resolvedNeedCount, 1);

      final fall = view.concepts.first;
      expect(fall.misconception, _misconception);
      expect(fall.hasActiveNeeds, isTrue);
      expect(fall.activeNeeds, ['foundation']);
      expect(fall.resolvedNeeds, ['conditions']);

      final inertia = view.concepts.last;
      expect(inertia.taught, isFalse);
      expect(inertia.misconception, isNull);
    });

    test('skill進捗だけのconceptはtaughtに数えneedは空', () {
      final view = const LearningKarteProjection().build(
        catalog: _catalog,
        needStates: const [],
        skills: const [
          LearningSkillProgress(
            scope: LearningScope.personal,
            skillId: 'force-motion/inertia',
            lastOutcome: LearningSkillOutcome.completed,
            successfulRetrievals: 1,
            lastAttemptDay: '2026-08-10',
            lastSuccessDay: '2026-08-10',
            nextDueDay: '2026-08-11',
            lastEventId: 'event.1',
          ),
        ],
      );
      final inertia = view.concepts.last;
      expect(inertia.taught, isTrue);
      expect(inertia.hasActiveNeeds, isFalse);
      expect(inertia.hasResolvedNeeds, isFalse);
      expect(view.summary.taughtCount, 1);
      expect(view.summary.activeNeedCount, 0);
    });

    test('resolvedだけ残るconceptはtaughtでactiveは空', () {
      final view = const LearningKarteProjection().build(
        catalog: _catalog,
        needStates: [needState(resolvedDay: '2026-08-12')],
        skills: const [],
      );
      final fall = view.concepts.first;
      expect(fall.taught, isTrue);
      expect(fall.hasResolvedNeeds, isTrue);
      expect(fall.hasActiveNeeds, isFalse);
      expect(view.summary.resolvedNeedCount, 1);
    });

    test('catalogに無いskillIdのneed状態は無視する', () {
      final view = const LearningKarteProjection().build(
        catalog: _catalog,
        needStates: [needState(skillId: 'other-unit/x')],
        skills: const [],
      );
      expect(view.summary.activeNeedCount, 0);
      expect(view.concepts.first.activeNeeds, isEmpty);
    });

    test('needCodeの接尾辞が日本語の種類ラベルに写る', () {
      expect(
        learningKarteNeedKindLabel('science.fall.foundation'),
        '仕組みの土台',
      );
      expect(
        learningKarteNeedKindLabel('science.fall.notation.graphRead'),
        'グラフの読み取り',
      );
      expect(
        learningKarteNeedKindLabel('science.fall.unknown'),
        'unknown',
      );
    });
  });

  group('SessionStore.learningNeedStates', () {
    test('commitした観測・解消がresolved付きで読める', () async {
      final store = MemorySessionStore();
      await store.commitLearningEvent(
        needEvent(
          eventId: 'karte.need.observe',
          nodeId: 'node.karte.1',
          learningDay: '2026-08-10',
          occurredAt: DateTime.utc(2026, 8, 10, 12),
          outcome: LearningAttemptOutcome.corrected,
          evidence: LearningEvidenceLevel.selfCompared,
          observed: const {
            'force-motion/fall': {'science.fall.foundation'},
          },
        ),
      );
      await store.commitLearningEvent(
        needEvent(
          eventId: 'karte.need.resolve',
          nodeId: 'node.karte.2',
          learningDay: '2026-08-12',
          occurredAt: DateTime.utc(2026, 8, 12, 12),
          outcome: LearningAttemptOutcome.structuredSuccess,
          evidence: LearningEvidenceLevel.structuredCorrection,
          resolved: const {
            'force-motion/fall': {'science.fall.foundation'},
          },
          repairResolution: _repairFoundation,
        ),
      );

      final states = await store.learningNeedStates(LearningScope.personal);
      expect(states, hasLength(1));
      expect(states.single.needCode, 'science.fall.foundation');
      expect(states.single.resolved, isTrue);
      expect(states.single.resolvedDay, '2026-08-12');
      expect(states.single.firstObservedDay, '2026-08-10');
    });
  });

  group('ScienceKarteScreen', () {
    Widget wrap(SessionStore store, {VoidCallback? onOpenPlus}) => MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: ScienceKarteScreen(
        catalog: _catalog,
        store: store,
        scope: LearningScope.personal,
        onOpenPlus: onOpenPlus,
      ),
    );

    testWidgets('思い込みとneed状態・注意書きが出る', (tester) async {
      final store = MemorySessionStore();
      await store.commitLearningEvent(
        needEvent(
          eventId: 'karte.screen.observe',
          nodeId: 'node.karte',
          learningDay: '2026-08-10',
          occurredAt: DateTime.utc(2026, 8, 10, 12),
          outcome: LearningAttemptOutcome.corrected,
          evidence: LearningEvidenceLevel.selfCompared,
          observed: const {
            'force-motion/fall': {'science.fall.foundation'},
          },
        ),
      );

      await tester.pumpWidget(wrap(store));
      await tester.pumpAndSettle();

      expect(find.text('デキすぎ君のカルテ'), findsOneWidget);
      expect(find.textContaining('迷い中 1'), findsOneWidget);
      expect(find.text('落下'), findsOneWidget);
      expect(
        find.textContaining('止まっている物には力がはたらかない'),
        findsOneWidget,
      );
      expect(find.text('仕組みの土台'), findsOneWidget);
      expect(find.text('迷い中'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('これから'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('これから'), findsOneWidget);
      expect(find.textContaining('誤答の本文や音声は残りません'), findsOneWidget);
    });

    testWidgets('解消済みは訂正できた表示に変わる', (tester) async {
      final store = MemorySessionStore();
      await store.commitLearningEvent(
        needEvent(
          eventId: 'karte.screen.resolve.src',
          nodeId: 'node.karte.a',
          learningDay: '2026-08-10',
          occurredAt: DateTime.utc(2026, 8, 10, 12),
          outcome: LearningAttemptOutcome.corrected,
          evidence: LearningEvidenceLevel.selfCompared,
          observed: const {
            'force-motion/fall': {'science.fall.foundation'},
          },
        ),
      );
      await store.commitLearningEvent(
        needEvent(
          eventId: 'karte.screen.resolve',
          nodeId: 'node.karte.b',
          learningDay: '2026-08-12',
          occurredAt: DateTime.utc(2026, 8, 12, 12),
          outcome: LearningAttemptOutcome.structuredSuccess,
          evidence: LearningEvidenceLevel.structuredCorrection,
          resolved: const {
            'force-motion/fall': {'science.fall.foundation'},
          },
          repairResolution: _repairFoundation,
        ),
      );

      await tester.pumpWidget(wrap(store));
      await tester.pumpAndSettle();

      expect(find.text('訂正できた'), findsOneWidget);
      expect(find.textContaining('あなたの説明で分かったこと'), findsOneWidget);
      expect(find.textContaining('つり合っている'), findsOneWidget);
    });

    testWidgets('paywall導線が無ければ保護者レポートカード自体を出さない', (
      tester,
    ) async {
      final store = MemorySessionStore();
      await tester.pumpWidget(wrap(store));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('science-karte-parent-report')),
        findsNothing,
      );
    });

    testWidgets('サポーターでなければレポートカードはpaywallへ橋渡しする', (
      tester,
    ) async {
      final store = MemorySessionStore();
      var plusOpened = 0;
      await tester.pumpWidget(
        wrap(store, onOpenPlus: () => plusOpened++),
      );
      await tester.pumpAndSettle();

      expect(find.text('Plusサポーター特典'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('science-karte-report-plus')),
      );
      await tester.pumpAndSettle();

      expect(plusOpened, 1);
      expect(
        find.byKey(const ValueKey('science-karte-report')),
        findsNothing,
      );
    });

    testWidgets('サポーターは保護者レポートを開いて思い込みの変化を見られる', (
      tester,
    ) async {
      final store = MemorySessionStore();
      await store.commitLearningEvent(
        needEvent(
          eventId: 'karte.report.observe',
          nodeId: 'node.karte.r1',
          learningDay: '2026-08-10',
          occurredAt: DateTime.utc(2026, 8, 10, 12),
          outcome: LearningAttemptOutcome.corrected,
          evidence: LearningEvidenceLevel.selfCompared,
          observed: const {
            'force-motion/fall': {'science.fall.foundation'},
          },
        ),
      );
      await store.commitLearningEvent(
        needEvent(
          eventId: 'karte.report.resolve',
          nodeId: 'node.karte.r2',
          learningDay: '2026-08-12',
          occurredAt: DateTime.utc(2026, 8, 12, 12),
          outcome: LearningAttemptOutcome.structuredSuccess,
          evidence: LearningEvidenceLevel.structuredCorrection,
          resolved: const {
            'force-motion/fall': {'science.fall.foundation'},
          },
          repairResolution: _repairFoundation,
        ),
      );
      await store.grantLearningPlusCosmetics(
        scope: LearningScope.personal,
        occurredAt: DateTime.utc(2026, 8, 12, 13),
      );

      await tester.pumpWidget(wrap(store, onOpenPlus: () {}));
      await tester.pumpAndSettle();

      expect(find.text('Plusサポーター特典'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('science-karte-report-open')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('science-karte-report')),
        findsOneWidget,
      );
      expect(
        find.text('お子さまの説明で分かってもらえた思い込み（1件）'),
        findsOneWidget,
      );
      expect(
        find.textContaining('止まっている物には力がはたらかない'),
        findsWidgets,
      );
      expect(find.textContaining('つり合っている'), findsWidgets);
      expect(
        find.byKey(const ValueKey('science-karte-report-copy')),
        findsOneWidget,
      );
    });
  });
}
