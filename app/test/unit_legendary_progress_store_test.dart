import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/learning/domain/learning_progress.dart';
import 'package:dekisugi/learning/services/game_path_projection.dart';
import 'package:dekisugi/learning/services/learning_progress_store.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

typedef _StoreFactory = Future<SessionStore> Function();

void _runContract(String name, _StoreFactory create) {
  group('$name Unit Legendary保存契約', () {
    late SessionStore session;
    late LearningProgressStore learning;

    setUp(() async {
      session = await create();
      learning = SessionLearningProgressStore(session);
    });

    tearDown(() => session.close());

    test('初回transferと期限spacedだけが報酬・専用skill間隔を進める', () async {
      final first = await learning.commit(
        _event(
          eventId: 'event.unit.first',
          learningDay: '2026-08-10',
          evidence: LearningEvidenceLevel.transfer,
        ),
      );
      expect(first.event.meaningfulProgress, isTrue);
      expect(first.rewards.single.amount, 10);
      expect(first.skills.single.skillId, _skillId);
      expect(first.skills.single.successfulRetrievals, 0);
      expect(first.skills.single.nextDueDay, '2026-08-11');

      final due = await learning.commit(
        _event(
          eventId: 'event.unit.due',
          learningDay: '2026-08-11',
          evidence: LearningEvidenceLevel.spacedTransfer,
        ),
      );
      expect(due.event.meaningfulProgress, isTrue);
      expect(due.rewards.single.amount, 10);
      expect(due.skills.single.successfulRetrievals, 1);
      expect(due.skills.single.nextDueDay, '2026-08-14');
    });

    test('旧全clearのv2 bootstrapはnodeと専用skillだけ作り報酬を遡及生成しない', () async {
      final result = await learning.commit(
        _event(
          eventId: 'event.unit.legacy-bootstrap',
          learningDay: '2026-08-10',
          evidence: LearningEvidenceLevel.spacedTransfer,
        ),
      );

      expect(result.node.nodeId, _nodeId);
      expect(result.node.state, LearningNodeState.cleared);
      expect(result.event.activityId, 'path.unit-legendary.v2');
      expect(result.event.meaningfulProgress, isFalse);
      expect(result.rewards, isEmpty);
      expect(result.quests, isEmpty);
      expect(result.skills.single.skillId, _skillId);
      expect(result.skills.single.successfulRetrievals, 0);
      expect(result.skills.single.nextDueDay, '2026-08-11');

      final snapshot = await learning.snapshot(LearningScope.personal);
      expect(snapshot.wallet.xp, 0);
      expect(snapshot.wallet.gems, 0);
      expect(snapshot.events.single.nodeId, _nodeId);
    });

    test('旧concept runとv2 runは別IDで共存し、v2完了でも旧runを消さない', () async {
      const oldNodeId = 'path:v1:motion:fall:legendary';
      final oldRun = await learning.beginRun(
        LearningRun(
          runId: 'run.old.legendary',
          scope: LearningScope.personal,
          nodeId: oldNodeId,
          activityIndex: 2,
          challengeHearts: 5,
          contentVersion: 'catalog-v4',
          updatedAt: DateTime.utc(2026, 8, 10, 9),
        ),
      );
      final newRun = await learning.beginRun(
        LearningRun(
          runId: 'run.unit.legendary',
          scope: LearningScope.personal,
          nodeId: _nodeId,
          activityIndex: 0,
          challengeHearts: 5,
          contentVersion: 'catalog-v5',
          updatedAt: DateTime.utc(2026, 8, 10, 10),
        ),
      );

      await learning.commit(
        _event(
          eventId: 'event.unit.with-run',
          learningDay: '2026-08-10',
          evidence: LearningEvidenceLevel.transfer,
          runId: newRun.runId,
        ),
      );
      final snapshot = await learning.snapshot(LearningScope.personal);
      expect(snapshot.runs.single.runId, oldRun.runId);
      expect(snapshot.runs.single.nodeId, oldNodeId);
      expect(snapshot.runs.single.activityIndex, 2);
    });
  });
}

final _nodeId = GamePathProjection.unitLegendaryNodeId('motion');
final _skillId = GamePathProjection.unitLegendarySkillId('motion');

LearningEventCommand _event({
  required String eventId,
  required String learningDay,
  required LearningEvidenceLevel evidence,
  String? runId,
}) => LearningEventCommand(
  eventId: eventId,
  scope: LearningScope.personal,
  origin: LearningOrigin.challenge,
  courseId: 'science-ja-v1',
  nodeId: _nodeId,
  activityId: 'path.unit-legendary.v2',
  skillIds: {_skillId},
  activityKind: LearningActivityKind.transfer,
  outcome: LearningAttemptOutcome.structuredSuccess,
  evidence: evidence,
  contentVersion: 'catalog-v5',
  learningDay: learningDay,
  occurredAt: DateTime.parse('${learningDay}T12:00:00Z'),
  runId: runId,
);

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  _runContract('Memory', () async => MemorySessionStore());
  _runContract(
    'SQLite',
    () => SqfliteSessionStore.open(path: inMemoryDatabasePath),
  );
}
