import '../../models/day_key.dart';
import '../domain/learning_event.dart';
import '../domain/learning_progress.dart';

/// One bounded pass over ended local League weeks.
final class LocalWeeklyLeagueCatchUpPlan {
  const LocalWeeklyLeagueCatchUpPlan({
    required this.currentWeekKey,
    required this.throughWeekKey,
    required this.candidateWeekKeys,
    required this.remainingCandidateCount,
    required this.resumeAfterWeekKey,
  });

  final String currentWeekKey;
  final String throughWeekKey;
  final List<String> candidateWeekKeys;
  final int remainingCandidateCount;
  final String? resumeAfterWeekKey;

  bool get hasMore => remainingCandidateCount > 0;
}

/// Results produced by one atomic Store catch-up pass.
final class LearningLocalLeagueCatchUpResult {
  const LearningLocalLeagueCatchUpResult({
    required this.plan,
    required this.results,
  });

  final LocalWeeklyLeagueCatchUpPlan plan;
  final List<LearningLocalLeagueFinalizeResult> results;

  bool get hasMore => plan.hasMore;
  int get appliedCount => results.where((result) => result.applied).length;
}

/// Selects real, saved local League weeks after the latest finalized history.
///
/// Empty calendar weeks are intentionally not synthesized. Candidate weeks come
/// only from persisted local League runs, are ordered oldest-first, and never
/// include the current learning week. The per-pass limit prevents corrupt or
/// unexpectedly large local state from turning app start into an unbounded loop.
abstract final class LocalWeeklyLeagueCatchUp {
  static const int defaultMaxWeeksPerPass = 104;

  static LocalWeeklyLeagueCatchUpPlan plan({
    required String currentWeekKey,
    required Iterable<LearningLocalLeagueWeek> history,
    required Iterable<String> runWeekKeys,
    int maxWeeks = defaultMaxWeeksPerPass,
    String? afterWeekKey,
  }) {
    _requireMonday(currentWeekKey, 'currentWeekKey');
    if (maxWeeks < 1 || maxWeeks > defaultMaxWeeksPerPass) {
      throw ArgumentError.value(
        maxWeeks,
        'maxWeeks',
        'must be between 1 and $defaultMaxWeeksPerPass',
      );
    }
    if (afterWeekKey != null) {
      _requireMonday(afterWeekKey, 'afterWeekKey');
    }

    final personalHistory = history
        .where((week) => week.scope == LearningScope.personal)
        .toList(growable: false);
    for (final week in personalHistory) {
      _requireMonday(week.weekKey, 'history.weekKey');
    }
    personalHistory.sort(
      (left, right) => right.weekKey.compareTo(left.weekKey),
    );
    final latestFinalizedWeek = personalHistory.firstOrNull?.weekKey;
    final throughWeekKey = shiftDay(currentWeekKey, -7);

    final eligible = <String>{};
    for (final weekKey in runWeekKeys) {
      _requireMonday(weekKey, 'runWeekKey');
      if (weekKey.compareTo(currentWeekKey) >= 0 ||
          (afterWeekKey != null && weekKey.compareTo(afterWeekKey) <= 0) ||
          (latestFinalizedWeek != null &&
              weekKey.compareTo(latestFinalizedWeek) <= 0)) {
        continue;
      }
      eligible.add(weekKey);
    }
    final ordered = eligible.toList(growable: false)..sort();
    final selected = ordered.take(maxWeeks).toList(growable: false);
    return LocalWeeklyLeagueCatchUpPlan(
      currentWeekKey: currentWeekKey,
      throughWeekKey: throughWeekKey,
      candidateWeekKeys: List.unmodifiable(selected),
      remainingCandidateCount: ordered.length - selected.length,
      resumeAfterWeekKey:
          ordered.length > selected.length && selected.isNotEmpty
          ? selected.last
          : null,
    );
  }

  static void _requireMonday(String value, String name) {
    if (learningWeekKey(value) != value) {
      throw ArgumentError.value(value, name, 'Monday required');
    }
  }
}
