import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/learning/domain/learning_progress.dart';
import 'package:dekisugi/learning/services/local_weekly_league_projection.dart';
import 'package:dekisugi/models/league_ladder.dart';
import 'package:flutter_test/flutter_test.dart';

const _week = '2026-08-10';
const _weekEnd = '2026-08-16';

LearningLocalCoopRun _run(
  String id, {
  Set<String> participants = const {'slot.a', 'slot.b'},
  bool completed = false,
  int round = 1,
  String definitionVersion = LocalWeeklyLeagueProjection.definitionVersion,
}) => LearningLocalCoopRun(
  runId: id,
  scope: LearningScope.personal,
  questInstanceId: 'local-coop:$id',
  participantIds: participants,
  contributingParticipantIds: completed ? participants : const {},
  progress: completed ? participants.length : 0,
  target: participants.length,
  rewardGems: 0,
  startDay: _week,
  endDay: _weekEnd,
  definitionVersion: definitionVersion,
  startedAt: DateTime.utc(2026, 8, 10, round),
  completedAt: completed ? DateTime.utc(2026, 8, 10, round, 30) : null,
  rewardedAt: completed ? DateTime.utc(2026, 8, 10, round, 30) : null,
);

LearningLocalCoopContribution _entry(
  String runId,
  String participantId,
  String eventId, {
  String day = _week,
  LearningScope scope = LearningScope.personal,
  bool meaningful = true,
}) => LearningLocalCoopContribution(
  runId: runId,
  participantId: participantId,
  eventId: eventId,
  scope: scope,
  learningDay: day,
  meaningfulProgress: meaningful,
);

void main() {
  test('personalの週内meaningful eventだけをround横断で集計し、同点を同率にする', () {
    const participants = {'slot.a', 'slot.b', 'slot.c', 'slot.d'};
    final result = LocalWeeklyLeagueProjection.project(
      scope: LearningScope.personal,
      weekKey: _week,
      runs: [
        _run('league.round.1', participants: participants, completed: true),
        _run('league.round.2', participants: participants, round: 2),
      ],
      contributions: [
        _entry('league.round.1', 'slot.a', 'event.a.1'),
        _entry('league.round.2', 'slot.a', 'event.a.2', day: '2026-08-11'),
        _entry('league.round.1', 'slot.b', 'event.b.1'),
        _entry('league.round.2', 'slot.b', 'event.b.2', day: '2026-08-16'),
        _entry('league.round.1', 'slot.c', 'event.c.1'),
        _entry('league.round.2', 'slot.d', 'event.loop', meaningful: false),
        _entry(
          'league.round.2',
          'slot.d',
          'event.school',
          scope: LearningScope.schoolLocal,
        ),
        _entry(
          'league.round.2',
          'slot.d',
          'event.next-week',
          day: '2026-08-17',
        ),
        _entry(
          'league.round.2',
          'slot.d',
          'event.invalid-day',
          day: 'not-a-day',
        ),
        _entry('another.run', 'slot.d', 'event.other-run'),
      ],
    );

    expect(result.availability, LocalWeeklyLeagueAvailability.active);
    expect(result.activeRunId, 'league.round.2');
    expect(result.totalMeaningfulEventCount, 5);
    expect(
      result.standings
          .map(
            (standing) => (
              standing.slotNumber,
              standing.meaningfulEventCount,
              standing.rank,
              standing.tied,
            ),
          )
          .toList(),
      const [
        (1, 2, 1, true),
        (2, 2, 1, true),
        (3, 1, 3, false),
        (4, 0, 4, false),
      ],
    );
  });

  test('同じeventの冪等再読込は1件、枠やroundをまたぐ再利用は全員0件', () {
    final first = _run('league.reuse.1', completed: true);
    final second = _run('league.reuse.2', round: 2);
    final result = LocalWeeklyLeagueProjection.project(
      scope: LearningScope.personal,
      weekKey: _week,
      runs: [first, second],
      contributions: [
        _entry(first.runId, 'slot.a', 'event.idempotent'),
        _entry(first.runId, 'slot.a', 'event.idempotent'),
        _entry(first.runId, 'slot.a', 'event.reused'),
        _entry(second.runId, 'slot.b', 'event.reused'),
      ],
    );

    expect(result.integrityConflictCount, 1);
    expect(result.totalMeaningfulEventCount, 1);
    expect(result.standings.map((standing) => standing.meaningfulEventCount), [
      1,
      0,
    ]);
    expect(result.standings.map((standing) => standing.rank), [1, 2]);
  });

  test('全員0件の間は順位も同率も断定しない', () {
    final result = LocalWeeklyLeagueProjection.project(
      scope: LearningScope.personal,
      weekKey: _week,
      runs: [_run('league.empty')],
    );

    expect(result.standings, hasLength(2));
    expect(result.standings.every((standing) => standing.rank == null), isTrue);
    expect(result.standings.every((standing) => !standing.tied), isTrue);
  });

  test('保存済み実順位履歴から10段tierを投影しslot 1を端末学習者に固定する', () {
    final history = [
      LearningLocalLeagueWeek(
        scope: LearningScope.personal,
        weekKey: '2026-08-03',
        meaningfulEventCount: 2,
        rank: 1,
        tied: false,
        participantCount: 5,
        previousTier: LanSocialLeagueTier.bronze,
        tier: LanSocialLeagueTier.silver,
        movement: LanSocialLeagueMovement.promoted,
        finalizedAt: DateTime.utc(2026, 8, 10, 4),
      ),
    ];
    final result = LocalWeeklyLeagueProjection.project(
      scope: LearningScope.personal,
      weekKey: _week,
      runs: [
        _run(
          'league.profile',
          participants: const {
            'slot.a',
            'slot.b',
            'slot.c',
            'slot.d',
            'slot.e',
          },
        ),
      ],
      history: history,
    );

    expect(result.currentTier, LanSocialLeagueTier.silver);
    expect(result.history, history);
    expect(result.deviceLearnerStanding?.slotNumber, 1);
    expect(result.deviceLearnerStanding?.participantId, 'slot.a');
    expect(result.tierFinalizationEligible, isTrue);
  });

  test('schoolLocalはrunや記録が渡っても参加者と順位を返さない', () {
    final result = LocalWeeklyLeagueProjection.project(
      scope: LearningScope.schoolLocal,
      weekKey: _week,
      runs: [_run('league.school')],
      contributions: [_entry('league.school', 'slot.a', 'event.personal')],
    );

    expect(result.availability, LocalWeeklyLeagueAvailability.schoolDisabled);
    expect(result.enabled, isFalse);
    expect(result.standings, isEmpty);
    expect(result.totalMeaningfulEventCount, 0);
  });

  test('runなしは未開始、参加枠がround間で違うデータはfail closed', () {
    final empty = LocalWeeklyLeagueProjection.project(
      scope: LearningScope.personal,
      weekKey: _week,
    );
    expect(empty.availability, LocalWeeklyLeagueAvailability.notStarted);

    final invalid = LocalWeeklyLeagueProjection.project(
      scope: LearningScope.personal,
      weekKey: _week,
      runs: [
        _run('league.invalid.1'),
        _run(
          'league.invalid.2',
          participants: const {'slot.a', 'slot.c'},
          round: 2,
        ),
      ],
    );
    expect(invalid.availability, LocalWeeklyLeagueAvailability.invalidData);
    expect(invalid.standings, isEmpty);
  });

  test('同週の無関係な協力runを無視し、既存ペアクエストだけ第1roundにできる', () {
    final result = LocalWeeklyLeagueProjection.project(
      scope: LearningScope.personal,
      weekKey: _week,
      runs: [
        _run(
          'unrelated.run',
          participants: const {'other.a', 'other.b', 'other.c'},
          definitionVersion: 'another-feature.v1',
        ),
        _run(
          'pair:2026-08-10:v1',
          completed: true,
          definitionVersion:
              LocalWeeklyLeagueProjection.pairBridgeDefinitionVersion,
        ),
        _run('league.round.2', round: 2),
      ],
      contributions: [
        _entry('unrelated.run', 'other.a', 'event.unrelated'),
        _entry('pair:2026-08-10:v1', 'slot.a', 'event.pair'),
        _entry('league.round.2', 'slot.b', 'event.league'),
      ],
    );

    expect(result.availability, LocalWeeklyLeagueAvailability.active);
    expect(result.integrityConflictCount, 0);
    expect(result.totalMeaningfulEventCount, 2);
    expect(result.standings.map((standing) => standing.slotNumber), [1, 2]);
    expect(result.standings.map((standing) => standing.meaningfulEventCount), [
      1,
      1,
    ]);
  });

  test('weekKeyは月曜だけを受け付ける', () {
    expect(
      () => LocalWeeklyLeagueProjection.project(
        scope: LearningScope.personal,
        weekKey: '2026-08-11',
      ),
      throwsArgumentError,
    );
  });
}
