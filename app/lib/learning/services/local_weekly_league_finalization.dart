import '../../models/day_key.dart';
import '../../models/league_ladder.dart';
import '../domain/learning_event.dart';
import '../domain/learning_progress.dart';
import 'local_weekly_league_projection.dart';

/// 保存済みの匿名run / contribution投影だけから週次tierを確定する純粋契約。
///
/// 呼出し元は順位・件数・氏名・回答を渡せない。[view]の順位はStore内の
/// [LocalWeeklyLeagueProjection]が導出し、5〜8人の週だけを終了後に確定する。
abstract final class LocalWeeklyLeagueFinalization {
  static LearningLocalLeagueFinalizeResult finalize({
    required LocalWeeklyLeagueView view,
    required Iterable<LearningLocalLeagueWeek> history,
    required DateTime finalizedAt,
  }) {
    final normalizedWeek = learningWeekKey(view.weekKey);
    if (normalizedWeek != view.weekKey) {
      throw ArgumentError.value(
        view.weekKey,
        'view.weekKey',
        'Monday required',
      );
    }
    final orderedHistory =
        history
            .where((week) => week.scope == LearningScope.personal)
            .toList(growable: false)
          ..sort((left, right) => right.weekKey.compareTo(left.weekKey));
    for (final existing in orderedHistory) {
      if (existing.weekKey == view.weekKey) {
        return LearningLocalLeagueFinalizeResult(
          status: LearningLocalLeagueFinalizeStatus.alreadyFinalized,
          week: existing,
        );
      }
    }
    if (orderedHistory.any(
      (week) => week.weekKey.compareTo(view.weekKey) > 0,
    )) {
      return const LearningLocalLeagueFinalizeResult(
        status: LearningLocalLeagueFinalizeStatus.outOfOrder,
        week: null,
      );
    }
    if (view.availability == LocalWeeklyLeagueAvailability.notStarted) {
      return const LearningLocalLeagueFinalizeResult(
        status: LearningLocalLeagueFinalizeStatus.notStarted,
        week: null,
      );
    }
    if (view.availability != LocalWeeklyLeagueAvailability.active ||
        view.endDay == null) {
      return const LearningLocalLeagueFinalizeResult(
        status: LearningLocalLeagueFinalizeStatus.invalidData,
        week: null,
      );
    }
    if (dayKeyOf(finalizedAt.toLocal()).compareTo(view.endDay!) <= 0) {
      return const LearningLocalLeagueFinalizeResult(
        status: LearningLocalLeagueFinalizeStatus.weekInProgress,
        week: null,
      );
    }
    if (view.participantCount < 5) {
      return const LearningLocalLeagueFinalizeResult(
        status: LearningLocalLeagueFinalizeStatus.insufficientParticipants,
        week: null,
      );
    }
    final learner = view.deviceLearnerStanding;
    if (learner == null || view.participantCount > 8) {
      return const LearningLocalLeagueFinalizeResult(
        status: LearningLocalLeagueFinalizeStatus.invalidData,
        week: null,
      );
    }
    final previousTier = orderedHistory.isEmpty
        ? LanSocialLeagueTier.bronze
        : orderedHistory.first.tier;
    final transition = resolveLeagueTierTransition(
      previousTier: previousTier,
      rank: learner.rank,
      tied: learner.tied,
      participantCount: view.participantCount,
      score: learner.meaningfulEventCount,
    );
    final week = LearningLocalLeagueWeek(
      scope: LearningScope.personal,
      weekKey: view.weekKey,
      meaningfulEventCount: learner.meaningfulEventCount,
      rank: learner.rank,
      tied: learner.tied,
      participantCount: view.participantCount,
      previousTier: transition.previousTier,
      tier: transition.tier,
      movement: transition.movement,
      finalizedAt: finalizedAt.toUtc(),
    );
    return LearningLocalLeagueFinalizeResult(
      status: LearningLocalLeagueFinalizeStatus.finalized,
      week: week,
    );
  }
}
