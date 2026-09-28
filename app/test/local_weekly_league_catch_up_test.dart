import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/learning/domain/learning_progress.dart';
import 'package:dekisugi/learning/services/local_weekly_league_catch_up.dart';
import 'package:dekisugi/models/league_ladder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('履歴最終週より後の保存済みrunだけを、現在週を除いて古い順に返す', () {
    final plan = LocalWeeklyLeagueCatchUp.plan(
      currentWeekKey: '2026-09-07',
      history: [_history('2026-08-10')],
      runWeekKeys: const [
        '2026-09-07',
        '2026-08-31',
        '2026-08-10',
        '2026-08-24',
        '2026-08-24',
      ],
    );

    expect(plan.throughWeekKey, '2026-08-31');
    expect(plan.candidateWeekKeys, ['2026-08-24', '2026-08-31']);
    expect(plan.hasMore, isFalse);
  });

  test('空の暦週を捏造せず、bounded passをcursorで次へ進める', () {
    final first = LocalWeeklyLeagueCatchUp.plan(
      currentWeekKey: '2026-09-07',
      history: const [],
      runWeekKeys: const ['2026-08-03', '2026-08-17', '2026-08-31'],
      maxWeeks: 2,
    );
    expect(first.candidateWeekKeys, ['2026-08-03', '2026-08-17']);
    expect(first.remainingCandidateCount, 1);
    expect(first.resumeAfterWeekKey, '2026-08-17');

    final second = LocalWeeklyLeagueCatchUp.plan(
      currentWeekKey: '2026-09-07',
      history: const [],
      runWeekKeys: const ['2026-08-03', '2026-08-17', '2026-08-31'],
      maxWeeks: 2,
      afterWeekKey: first.resumeAfterWeekKey,
    );
    expect(second.candidateWeekKeys, ['2026-08-31']);
    expect(second.hasMore, isFalse);
  });

  test('月曜でない境界と過大なpassをfail-closedで拒否する', () {
    expect(
      () => LocalWeeklyLeagueCatchUp.plan(
        currentWeekKey: '2026-09-08',
        history: const [],
        runWeekKeys: const [],
      ),
      throwsArgumentError,
    );
    expect(
      () => LocalWeeklyLeagueCatchUp.plan(
        currentWeekKey: '2026-09-07',
        history: const [],
        runWeekKeys: const [],
        maxWeeks: LocalWeeklyLeagueCatchUp.defaultMaxWeeksPerPass + 1,
      ),
      throwsArgumentError,
    );
  });
}

LearningLocalLeagueWeek _history(String weekKey) => LearningLocalLeagueWeek(
  scope: LearningScope.personal,
  weekKey: weekKey,
  meaningfulEventCount: 1,
  rank: 1,
  tied: false,
  participantCount: 5,
  previousTier: LanSocialLeagueTier.bronze,
  tier: LanSocialLeagueTier.silver,
  movement: LanSocialLeagueMovement.promoted,
  finalizedAt: DateTime.utc(2026, 8, 17),
);
