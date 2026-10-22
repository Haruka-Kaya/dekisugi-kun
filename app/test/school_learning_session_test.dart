import 'dart:async';

import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/learning/domain/learning_policy.dart';
import 'package:dekisugi/learning/domain/learning_progress.dart';
import 'package:dekisugi/learning/services/learning_progress_store.dart';
import 'package:dekisugi/services/local_classroom_run_store.dart';
import 'package:dekisugi/services/school_learning_session.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

LearningEventCommand event(String id) => LearningEventCommand(
  eventId: id,
  scope: LearningScope.schoolLocal,
  origin: LearningOrigin.schoolAssignment,
  courseId: 'science-ja-v1',
  nodeId: 'node.school',
  activityId: 'school.read',
  skillIds: const {'unit/concept'},
  activityKind: LearningActivityKind.read,
  outcome: LearningAttemptOutcome.completed,
  evidence: LearningEvidenceLevel.selfCompared,
  contentVersion: 'catalog-v4',
  learningDay: '2026-08-10',
  occurredAt: DateTime.utc(2026, 8, 10, 12),
);

void main() {
  test('drain waits for the actual commit and rejects callbacks after reset', () async {
    final store = _DelayedCommitStore();
    final session = SchoolLearningSession();
    final learning = SessionLearningProgressStore(store, schoolSession: session);
    final pending = learning.commit(event('pending'));
    await store.started.future;
    var drained = false;
    final drain = session.closeAndDrain().then((_) => drained = true);
    await Future<void>.delayed(Duration.zero);
    expect(drained, isFalse);
    await expectLater(learning.commit(event('too-late')), throwsStateError);
    store.release.complete();
    await pending;
    await drain;
    expect((await store.learningProgressSnapshot(LearningScope.schoolLocal)).events, hasLength(1));
    await store.resetSchoolLearningData();
    await expectLater(learning.commit(event('after-reset')), throwsStateError);
    await expectLater(
      learning.materializeQuestDefinitions(scope: LearningScope.schoolLocal, definitions: const []),
      throwsStateError,
    );
    expect((await store.learningProgressSnapshot(LearningScope.schoolLocal)).events, isEmpty);
    final next = SessionLearningProgressStore(store, schoolSession: SchoolLearningSession());
    await next.commit(event('new-generation'));
    expect((await next.snapshot(LearningScope.schoolLocal)).events.single.eventId, 'new-generation');
  });

  test('a failed in-flight write still drains and reports its original failure', () async {
    final session = SchoolLearningSession();
    final release = Completer<void>();
    final write = session.write(() async {
      await release.future;
      throw StateError('synthetic write failure');
    });
    final failure = expectLater(write, throwsStateError);
    final drain = session.closeAndDrain();
    release.complete();
    await failure;
    await drain;
    await session.closeAndDrain();
    await expectLater(session.write(() async {}), throwsStateError);
  });

  test('queued classroom writes cannot run after their generation closes', () async {
    final store = _DelayedReadStore();
    final session = SchoolLearningSession();
    final runs = LocalClassroomRunStore(store, schoolSession: session);
    final read = runs.load();
    await store.started.future;
    final queued = runs.begin(unitId: 'unit', conceptKey: 'concept', practiceAttempt: 0);
    final rejected = expectLater(queued, throwsStateError);
    final drain = session.closeAndDrain();
    store.release.complete();
    await read;
    await rejected;
    await drain;
    await store.resetSchoolLearningData();
    expect(await store.getSetting(LocalClassroomRunStore.settingKey), isNull);
    await expectLater(
      runs.enterPractice(unitId: 'unit', conceptKey: 'concept', practiceAttempt: 0),
      throwsStateError,
    );
    final next = LocalClassroomRunStore(store, schoolSession: SchoolLearningSession());
    await next.begin(unitId: 'unit', conceptKey: 'concept', practiceAttempt: 0);
    expect((await next.load())?.stage, LocalClassroomStage.material);
  });
}

class _DelayedCommitStore extends MemorySessionStore {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<CommitLearningResult> commitLearningEvent(
    LearningEventCommand event, {
    LearningCommitRules rules = const LearningCommitRules(),
  }) async {
    if (!started.isCompleted) started.complete();
    await release.future;
    return super.commitLearningEvent(event, rules: rules);
  }
}

class _DelayedReadStore extends MemorySessionStore {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<String?> getSetting(String key) async {
    if (!started.isCompleted) started.complete();
    await release.future;
    return super.getSetting(key);
  }
}
