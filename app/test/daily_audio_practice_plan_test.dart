import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/learning/domain/learning_progress.dart';
import 'package:dekisugi/learning/services/daily_audio_practice_plan.dart';
import 'package:dekisugi/learning/services/game_path_projection.dart';
import 'package:dekisugi/models/game_path.dart';
import 'package:dekisugi/models/unit.dart';
import 'package:flutter_test/flutter_test.dart';

const _catalog = [
  UnitSummary(
    id: 'motion',
    title: '運動',
    brief: '運動を説明する',
    concepts: [
      UnitConcept(key: 'fall', label: '落下', storyTitle: '落下事件'),
      UnitConcept(key: 'inertia', label: '慣性', storyTitle: '慣性事件'),
    ],
    sectionCount: 2,
  ),
];

const _status = GamePlayerStatus(
  streakDays: 0,
  streakFreezeRemaining: 0,
  gems: 0,
  hearts: 5,
);

LearningProgressSnapshot _snapshot({
  List<LearningEventRecord> events = const [],
}) => LearningProgressSnapshot(
  scope: LearningScope.personal,
  events: events,
  nodes: const [],
  skills: const [],
  days: const [],
  freezes: const [],
  challengeHearts: const LearningChallengeHeartState.initial(),
  rewards: const [],
  quests: const [],
  runs: const [],
);

LearningEventRecord _event({
  required String eventId,
  required String nodeId,
  required String activityId,
  required LearningActivityKind activityKind,
  required String learningDay,
  LearningAttemptOutcome outcome = LearningAttemptOutcome.completed,
  LearningEvidenceLevel evidence = LearningEvidenceLevel.selfCompared,
}) => LearningEventRecord(
  eventId: eventId,
  scope: LearningScope.personal,
  origin: LearningOrigin.practice,
  courseId: 'science-ja-v1',
  nodeId: nodeId,
  activityId: activityId,
  activityKind: activityKind,
  outcome: outcome,
  evidence: evidence,
  contentVersion: 'catalog-v6',
  learningDay: learningDay,
  occurredAt: DateTime.utc(2026, 8, 10, 18, 59),
  runId: null,
  sourceSessionId: null,
  rewardEligible: true,
);

void main() {
  const planner = DailyAudioPracticePlanner();
  const pathProjection = GamePathProjection();

  test('未解放の音声nodeを先取りせず、到達前は空になる', () {
    final path = pathProjection.build(
      catalog: _catalog,
      progress: const GamePathProgressInput(),
      status: _status,
    );

    final plan = planner.build(
      catalog: _catalog,
      path: path,
      snapshot: _snapshot(),
      learningDay: '2026-08-10',
    );

    expect(plan.missions, isEmpty);
  });

  test('聞く・話すを別missionにし、正答や回答本文をDTOへ持たない', () {
    final cleared = <String>{};
    for (final kind in const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
      GamePathNodeKind.story,
      GamePathNodeKind.listening,
      GamePathNodeKind.speaking,
    ]) {
      cleared.add(GamePathProjection.nodeId('motion', 'fall', kind));
    }
    final path = pathProjection.build(
      catalog: _catalog,
      progress: GamePathProgressInput(clearedNodeIds: cleared),
      status: _status,
    );

    final plan = planner.build(
      catalog: _catalog,
      path: path,
      snapshot: _snapshot(),
      learningDay: '2026-08-10',
    );

    expect(plan.missions, hasLength(2));
    expect(
      plan.missionOf(DailyAudioMissionKind.listening)?.nodeId,
      endsWith(':listening'),
    );
    expect(
      plan.missionOf(DailyAudioMissionKind.speaking)?.nodeId,
      endsWith(':speaking'),
    );
    expect(
      plan.missions.map((mission) => mission.practiceAttempt),
      everyElement(inInclusiveRange(0, 2)),
    );
  });

  test('同じ学習日は決定的で、候補が複数なら日をまたいで巡回する', () {
    final cleared = <String>{};
    for (final concept in const ['fall', 'inertia']) {
      for (final kind in GamePathNodeKind.values) {
        if (kind == GamePathNodeKind.legendary) continue;
        cleared.add(GamePathProjection.nodeId('motion', concept, kind));
      }
    }
    final path = pathProjection.build(
      catalog: _catalog,
      progress: GamePathProgressInput(clearedNodeIds: cleared),
      status: _status,
    );

    DailyAudioPracticePlan plan(String day) => planner.build(
      catalog: _catalog,
      path: path,
      snapshot: _snapshot(),
      learningDay: day,
    );

    expect(
      plan('2026-08-10').missions.map((mission) => mission.nodeId),
      plan('2026-08-10').missions.map((mission) => mission.nodeId),
    );
    expect(
      plan('2026-08-10').missions.map((mission) => mission.conceptKey),
      isNot(plan('2026-08-11').missions.map((mission) => mission.conceptKey)),
    );
  });

  test('同じ4時区切り学習日の該当node/activityだけを2ミッション別に完了投影する', () {
    final cleared = <String>{};
    for (final kind in const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
      GamePathNodeKind.story,
      GamePathNodeKind.listening,
      GamePathNodeKind.speaking,
    ]) {
      cleared.add(GamePathProjection.nodeId('motion', 'fall', kind));
    }
    final path = pathProjection.build(
      catalog: _catalog,
      progress: GamePathProgressInput(clearedNodeIds: cleared),
      status: _status,
    );
    final listeningNode = GamePathProjection.nodeId(
      'motion',
      'fall',
      GamePathNodeKind.listening,
    );
    final speakingNode = GamePathProjection.nodeId(
      'motion',
      'fall',
      GamePathNodeKind.speaking,
    );
    final plan = planner.build(
      catalog: _catalog,
      path: path,
      snapshot: _snapshot(
        events: [
          _event(
            eventId: 'event-listening-yesterday',
            nodeId: listeningNode,
            activityId: 'path.listening.v1',
            activityKind: LearningActivityKind.listen,
            learningDay: '2026-08-09',
          ),
          _event(
            eventId: 'event-wrong-activity',
            nodeId: listeningNode,
            activityId: 'path.speaking.v1',
            activityKind: LearningActivityKind.speak,
            learningDay: '2026-08-10',
          ),
          _event(
            eventId: 'event-speaking-today',
            nodeId: speakingNode,
            activityId: 'path.speaking.v1',
            activityKind: LearningActivityKind.speak,
            learningDay: '2026-08-10',
          ),
        ],
      ),
      learningDay: '2026-08-10',
    );

    expect(
      plan.missionOf(DailyAudioMissionKind.listening)?.completedToday,
      isFalse,
    );
    expect(
      plan.missionOf(DailyAudioMissionKind.speaking)?.completedToday,
      isTrue,
    );
  });

  test('retryNeededやselfCompared未満は今日完了にしない', () {
    final cleared = <String>{};
    for (final kind in const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
      GamePathNodeKind.story,
      GamePathNodeKind.listening,
      GamePathNodeKind.speaking,
    ]) {
      cleared.add(GamePathProjection.nodeId('motion', 'fall', kind));
    }
    final path = pathProjection.build(
      catalog: _catalog,
      progress: GamePathProgressInput(clearedNodeIds: cleared),
      status: _status,
    );
    final plan = planner.build(
      catalog: _catalog,
      path: path,
      snapshot: _snapshot(
        events: [
          _event(
            eventId: 'event-listening-retry',
            nodeId: GamePathProjection.nodeId(
              'motion',
              'fall',
              GamePathNodeKind.listening,
            ),
            activityId: 'path.listening.v1',
            activityKind: LearningActivityKind.listen,
            learningDay: '2026-08-10',
            outcome: LearningAttemptOutcome.retryNeeded,
            evidence: LearningEvidenceLevel.participation,
          ),
        ],
      ),
      learningDay: '2026-08-10',
    );

    expect(
      plan.missionOf(DailyAudioMissionKind.listening)?.completedToday,
      isFalse,
    );
  });

  test('存在しない学習日をfail closedする', () {
    final path = pathProjection.build(
      catalog: _catalog,
      progress: const GamePathProgressInput(),
      status: _status,
    );

    expect(
      () => planner.build(
        catalog: _catalog,
        path: path,
        snapshot: _snapshot(),
        learningDay: '2026-02-30',
      ),
      throwsArgumentError,
    );
  });
}
