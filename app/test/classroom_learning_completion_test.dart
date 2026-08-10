import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/learning/domain/learning_policy.dart';
import 'package:dekisugi/learning/services/learning_game_projection.dart';
import 'package:dekisugi/models/classroom_mission.dart';
import 'package:dekisugi/models/day_key.dart';
import 'package:dekisugi/models/game_path.dart';
import 'package:dekisugi/models/unit.dart';
import 'package:dekisugi/services/classroom_learning_completion.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _answerLikeLabel = '秘密の回答本文と選択肢';
const _unit = UnitSummary(
  id: 'motion',
  title: '力と運動',
  brief: '運動を比べる',
  concepts: [
    UnitConcept(key: 'fall', label: _answerLikeLabel, storyTitle: '落下事件'),
  ],
  sectionCount: 1,
);
const _mission = ClassroomMission(
  unit: _unit,
  conceptKey: 'fall',
  conceptLabel: _answerLikeLabel,
  unitNumber: 1,
  conceptNumber: 1,
);

ClassroomAssignment _assignment(ClassroomRound round) =>
    ClassroomAssignment(mission: _mission, round: round);

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('A/B/CはPath必修nodeと分離した安定IDを持ち、証拠をselfComparedより上げない', () {
    final occurredAt = DateTime(2026, 8, 10, 12);
    final cases = <ClassroomRound, (String, LearningActivityKind)>{
      ClassroomRound.a: ('round-a', LearningActivityKind.read),
      ClassroomRound.b: ('round-b', LearningActivityKind.diagram),
      ClassroomRound.c: ('round-c', LearningActivityKind.transfer),
    };

    for (final MapEntry(key: round, value: expected) in cases.entries) {
      final assignment = _assignment(round);
      final event = ClassroomLearningCompletion.eventFor(
        assignment,
        occurredAt: occurredAt,
      );
      expect(event.nodeId, 'classroom:v1:motion:fall:${expected.$1}');
      expect(event.activityKind, expected.$2);
      expect(event.scope, LearningScope.schoolLocal);
      expect(event.origin, LearningOrigin.schoolAssignment);
      expect(event.outcome, LearningAttemptOutcome.completed);
      expect(
        event.evidence.rank,
        lessThanOrEqualTo(LearningEvidenceLevel.selfCompared.rank),
      );
      expect(event.practiceNeedCodes, isEmpty);
      expect(event.runId, isNull);
      expect(event.sourceSessionId, isNull);

      final persistedMetadata = [
        event.eventId,
        event.courseId,
        event.nodeId,
        event.activityId,
        ...event.skillIds,
        event.contentVersion,
      ].join('|');
      expect(
        persistedMetadata,
        isNot(contains(_answerLikeLabel)),
        reason: 'conceptLabelや回答らしい本文をIDへ迂回して保存しない',
      );
    }
  });

  test('1 assignment×学習日はevent一度で、personal不変・Path上の共同目標へ反映する', () async {
    final store = MemorySessionStore();
    final occurredAt = DateTime(2026, 8, 10, 12);
    final personalAt = DateTime(2026, 8, 10, 9);
    await store.commitLearningEvent(
      LearningEventCommand(
        eventId: 'personal:before',
        scope: LearningScope.personal,
        origin: LearningOrigin.path,
        courseId: 'science-ja-v1',
        nodeId: 'path:v1:personal:seed:lesson',
        activityId: 'path.lesson.v1',
        skillIds: const {'personal/seed'},
        activityKind: LearningActivityKind.read,
        outcome: LearningAttemptOutcome.completed,
        evidence: LearningEvidenceLevel.selfCompared,
        contentVersion: 'catalog-v4',
        learningDay: dayKeyOf(personalAt),
        occurredAt: personalAt.toUtc(),
      ),
    );
    final personalBefore = await store.learningProgressSnapshot(
      LearningScope.personal,
    );

    final assignment = _assignment(ClassroomRound.a);
    final first = await ClassroomLearningCompletion.commit(
      store: store,
      assignment: assignment,
      occurredAt: occurredAt,
    );
    final duplicate = await ClassroomLearningCompletion.commit(
      store: store,
      assignment: assignment,
      occurredAt: occurredAt.add(const Duration(hours: 1)),
    );

    expect(first.inserted, isTrue);
    expect(duplicate.inserted, isFalse);
    expect(duplicate.event.eventId, first.event.eventId);
    expect(
      first.event.eventId,
      'school:${dayKeyOf(occurredAt)}:${assignment.id}',
    );
    expect(
      first.event.occurredAt,
      dayStartOf(dayKeyOf(occurredAt)).toUtc(),
      reason: '同じ学習日の再送で全fieldを一致させ、正確な完了時刻は残さない',
    );

    final school = await store.learningProgressSnapshot(
      LearningScope.schoolLocal,
    );
    expect(school.events, hasLength(1));
    expect(school.nodes, hasLength(1));
    expect(school.nodes.single.nodeId, first.event.nodeId);
    expect(school.nodes.single.state.name, 'cleared');
    expect(school.rewards, isEmpty);
    expect(school.wallet.xp, 0);
    expect(school.wallet.gems, 0);

    final questId = 'daily:${dayKeyOf(occurredAt)}:one-action';
    final game = const LearningGameProjection().build(
      catalog: const [_unit],
      snapshot: school,
      now: occurredAt,
      schoolMode: true,
      questTitles: {questId: '今日の学習を1件終える'},
      activeQuestDefinitions: [
        LearningQuestDefinition(
          questInstanceId: questId,
          definitionVersion: 'daily.v1',
          target: 1,
          rewardGems: 0,
        ),
      ],
    );
    expect(
      game.path.units.single.nodes.any((node) => node.id == first.event.nodeId),
      isFalse,
      reason: '学校assignmentをPath必修nodeのclearに流用しない',
    );
    expect(
      game.path.units.single.nodes.first.state,
      GamePathNodeState.available,
    );
    expect(game.quests.single.progress, 1);
    expect(game.quests.single.target, 1);
    expect(game.quests.single.gemReward, 0);
    expect(game.path.quests.single.current, 1);
    expect(game.path.quests.single.rewardLabel, isNull);

    final personalAfter = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(
      personalAfter.events.map((event) => event.eventId),
      personalBefore.events.map((event) => event.eventId),
    );
    expect(
      personalAfter.nodes.map((node) => node.nodeId),
      personalBefore.nodes.map((node) => node.nodeId),
    );
    expect(personalAfter.wallet.xp, personalBefore.wallet.xp);
    expect(personalAfter.wallet.gems, personalBefore.wallet.gems);
    expect(
      personalAfter.challengeHearts?.current,
      personalBefore.challengeHearts?.current,
    );
  });

  test('C単独完了はPath章ボスと翌日のLegendaryを解放しない', () async {
    final store = MemorySessionStore();
    final occurredAt = DateTime(2026, 8, 10, 12);
    await ClassroomLearningCompletion.commit(
      store: store,
      assignment: _assignment(ClassroomRound.c),
      occurredAt: occurredAt,
    );
    final school = await store.learningProgressSnapshot(
      LearningScope.schoolLocal,
    );
    final game = const LearningGameProjection().build(
      catalog: const [_unit],
      snapshot: school,
      now: occurredAt.add(const Duration(days: 1)),
      schoolMode: true,
    );
    final challenge = game.path.units.single.nodes.singleWhere(
      (node) => node.kind == GamePathNodeKind.challenge,
    );
    final legendary = game.path.units.single.nodes.singleWhere(
      (node) => node.kind == GamePathNodeKind.legendary,
    );
    expect(challenge.state, GamePathNodeState.locked);
    expect(legendary.state, GamePathNodeState.locked);
  });

  test('SQLite公開APIでも同日の別route再送は成功扱いで共同進捗を水増ししない', () async {
    final store = await SqfliteSessionStore.open(path: inMemoryDatabasePath);
    addTearDown(store.close);
    final assignment = _assignment(ClassroomRound.b);
    final first = await ClassroomLearningCompletion.commit(
      store: store,
      assignment: assignment,
      occurredAt: DateTime(2026, 8, 10, 8),
    );
    final duplicate = await ClassroomLearningCompletion.commit(
      store: store,
      assignment: assignment,
      occurredAt: DateTime(2026, 8, 10, 18),
    );

    expect(first.inserted, isTrue);
    expect(duplicate.inserted, isFalse);
    final school = await store.learningProgressSnapshot(
      LearningScope.schoolLocal,
    );
    expect(school.events, hasLength(1));
    expect(school.nodes.single.attemptCount, 1);
    expect(school.days.single.qualifyingCount, 1);
    expect(school.rewards, isEmpty);
  });
}
