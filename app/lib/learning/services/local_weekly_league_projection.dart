import '../domain/learning_event.dart';
import '../domain/learning_progress.dart';
import '../../models/league_ladder.dart';

enum LocalWeeklyLeagueAvailability {
  /// 成人personalで、少なくとも1つの週次runがある。
  active,

  /// personalだが、まだ参加枠を作っていない。
  notStarted,

  /// schoolLocalでは個人順位を作らない。
  schoolDisabled,

  /// 不透明ID・参加人数・期間・参加枠が壊れており、安全に表示できない。
  invalidData,
}

final class LocalWeeklyLeagueStanding {
  const LocalWeeklyLeagueStanding({
    required this.participantId,
    required this.slotNumber,
    required this.meaningfulEventCount,
    required this.rank,
    required this.tied,
  });

  /// run内でのみ使う不透明ID。表示名として使ってはいけない。
  final String participantId;
  final int slotNumber;
  final int meaningfulEventCount;

  /// 全員0件の間は順位を断定しないためnull。
  ///
  /// 同点はcompetition ranking（1, 1, 3）で同じrankを共有する。
  final int? rank;
  final bool tied;
}

final class LocalWeeklyLeagueView {
  const LocalWeeklyLeagueView({
    required this.availability,
    required this.weekKey,
    required this.endDay,
    required this.standings,
    required this.activeRunId,
    required this.integrityConflictCount,
    this.currentTier = LanSocialLeagueTier.bronze,
    this.history = const [],
  });

  final LocalWeeklyLeagueAvailability availability;
  final String weekKey;
  final String? endDay;
  final List<LocalWeeklyLeagueStanding> standings;

  /// 追加入力を受け付けられる最新round。nullなら次roundを作る必要がある。
  final String? activeRunId;

  /// 同じeventの枠またぎなど、得点から除外した不整合の件数。
  final int integrityConflictCount;
  final LanSocialLeagueTier currentTier;
  final List<LearningLocalLeagueWeek> history;

  bool get enabled => availability == LocalWeeklyLeagueAvailability.active;
  int get participantCount => standings.length;
  int get totalMeaningfulEventCount => standings.fold(
    0,
    (total, standing) => total + standing.meaningfulEventCount,
  );

  /// 長期tierの対象は、匿名IDを外へ出さないslot 1だけ。
  LocalWeeklyLeagueStanding? get deviceLearnerStanding {
    for (final standing in standings) {
      if (standing.slotNumber == 1) return standing;
    }
    return null;
  }

  bool get tierFinalizationEligible => enabled && participantCount >= 5;
}

/// 実在する2〜8人が同じ端末を手渡す週次リーグの純粋投影。
///
/// 1つの[LearningLocalCoopRun]は全員が参加すると閉じるため、同じ週・同じ枠の
/// runをroundとして追加できる。週の得点は全roundを横断して集計する。
abstract final class LocalWeeklyLeagueProjection {
  /// 週次リーグとして集計する専用round。
  static const definitionVersion = 'local-weekly-league.v1';

  /// その週に先に始めた実在2人のペアクエストだけは第1roundへ橋渡しする。
  /// それ以外の協力runは、参加枠が違っても順位を壊さないよう無視する。
  static const pairBridgeDefinitionVersion = 'local-pair.v1';

  static final RegExp _opaqueId = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$',
  );

  static LocalWeeklyLeagueView project({
    required LearningScope scope,
    required String weekKey,
    Iterable<LearningLocalCoopRun> runs = const [],
    Iterable<LearningLocalCoopContribution> contributions = const [],
    Iterable<LearningLocalLeagueWeek> history = const [],
  }) {
    final normalizedWeekKey = learningWeekKey(weekKey);
    if (normalizedWeekKey != weekKey) {
      throw ArgumentError.value(weekKey, 'weekKey', 'Monday required');
    }
    final localHistory =
        history
            .where((week) => week.scope == LearningScope.personal)
            .toList(growable: false)
          ..sort((left, right) => right.weekKey.compareTo(left.weekKey));
    final currentTier = localHistory.isEmpty
        ? LanSocialLeagueTier.bronze
        : localHistory.first.tier;
    if (scope == LearningScope.schoolLocal) {
      return LocalWeeklyLeagueView(
        availability: LocalWeeklyLeagueAvailability.schoolDisabled,
        weekKey: weekKey,
        endDay: null,
        standings: const [],
        activeRunId: null,
        integrityConflictCount: 0,
        currentTier: currentTier,
        history: List.unmodifiable(localHistory),
      );
    }

    final weekRuns =
        runs
            .where(
              (run) =>
                  run.scope == LearningScope.personal &&
                  run.startDay == weekKey &&
                  (run.definitionVersion == definitionVersion ||
                      run.definitionVersion == pairBridgeDefinitionVersion),
            )
            .toList()
          ..sort(
            (left, right) => left.startedAt.compareTo(right.startedAt) != 0
                ? left.startedAt.compareTo(right.startedAt)
                : left.runId.compareTo(right.runId),
          );
    if (weekRuns.isEmpty) {
      return LocalWeeklyLeagueView(
        availability: LocalWeeklyLeagueAvailability.notStarted,
        weekKey: weekKey,
        endDay: null,
        standings: const [],
        activeRunId: null,
        integrityConflictCount: 0,
        currentTier: currentTier,
        history: List.unmodifiable(localHistory),
      );
    }

    final first = weekRuns.first;
    final participantIds = first.participantIds.toList()..sort();
    final expectedEndDay = _addDays(weekKey, 6);
    final validHeader =
        _opaqueId.hasMatch(first.runId) &&
        participantIds.length >= 2 &&
        participantIds.length <= 8 &&
        participantIds.every(_opaqueId.hasMatch) &&
        first.endDay == expectedEndDay;
    final sameRoundContract = weekRuns.every(
      (run) =>
          _opaqueId.hasMatch(run.runId) &&
          run.endDay == expectedEndDay &&
          _sameSet(run.participantIds, first.participantIds),
    );
    if (!validHeader || !sameRoundContract) {
      return LocalWeeklyLeagueView(
        availability: LocalWeeklyLeagueAvailability.invalidData,
        weekKey: weekKey,
        endDay: expectedEndDay,
        standings: const [],
        activeRunId: null,
        integrityConflictCount: 0,
        currentTier: currentTier,
        history: List.unmodifiable(localHistory),
      );
    }

    final runIds = {for (final run in weekRuns) run.runId};
    final eligible = <LearningLocalCoopContribution>[];
    var integrityConflictCount = 0;
    for (final contribution in contributions) {
      if (!runIds.contains(contribution.runId)) continue;
      final structurallyValid =
          contribution.scope == LearningScope.personal &&
          contribution.meaningfulProgress &&
          _opaqueId.hasMatch(contribution.eventId) &&
          _opaqueId.hasMatch(contribution.participantId) &&
          first.participantIds.contains(contribution.participantId) &&
          _isDayInWeek(contribution.learningDay, weekKey, expectedEndDay);
      if (!structurallyValid) continue;
      eligible.add(contribution);
    }

    final byEvent = <String, List<LearningLocalCoopContribution>>{};
    for (final contribution in eligible) {
      byEvent.putIfAbsent(contribution.eventId, () => []).add(contribution);
    }
    final counts = {for (final id in participantIds) id: 0};
    for (final eventContributions in byEvent.values) {
      final firstRecord = eventContributions.first;
      final exactReplay = eventContributions.every(
        (record) =>
            record.runId == firstRecord.runId &&
            record.participantId == firstRecord.participantId &&
            record.learningDay == firstRecord.learningDay,
      );
      if (!exactReplay) {
        // 枠やroundをまたいで再利用されたeventは、先着順で誰かへ寄せない。
        // 全件を0点にすることで同率を恣意的に崩さない。
        integrityConflictCount += 1;
        continue;
      }
      counts[firstRecord.participantId] =
          (counts[firstRecord.participantId] ?? 0) + 1;
    }

    final slotNumberById = <String, int>{
      for (var index = 0; index < participantIds.length; index += 1)
        participantIds[index]: index + 1,
    };
    final orderedIds = [...participantIds]
      ..sort((left, right) {
        final byScore = counts[right]!.compareTo(counts[left]!);
        if (byScore != 0) return byScore;
        return slotNumberById[left]!.compareTo(slotNumberById[right]!);
      });
    final anyScore = counts.values.any((value) => value > 0);
    final frequencyByScore = <int, int>{};
    for (final score in counts.values) {
      frequencyByScore[score] = (frequencyByScore[score] ?? 0) + 1;
    }
    final standings = <LocalWeeklyLeagueStanding>[];
    int? previousScore;
    int? previousRank;
    for (var index = 0; index < orderedIds.length; index += 1) {
      final participantId = orderedIds[index];
      final score = counts[participantId]!;
      final rank = !anyScore
          ? null
          : previousScore == score
          ? previousRank
          : index + 1;
      standings.add(
        LocalWeeklyLeagueStanding(
          participantId: participantId,
          slotNumber: slotNumberById[participantId]!,
          meaningfulEventCount: score,
          rank: rank,
          tied: anyScore && (frequencyByScore[score] ?? 0) > 1,
        ),
      );
      previousScore = score;
      previousRank = rank;
    }

    final activeRuns = weekRuns.where((run) => !run.completed).toList();
    return LocalWeeklyLeagueView(
      availability: LocalWeeklyLeagueAvailability.active,
      weekKey: weekKey,
      endDay: expectedEndDay,
      standings: List.unmodifiable(standings),
      activeRunId: activeRuns.isEmpty ? null : activeRuns.last.runId,
      integrityConflictCount: integrityConflictCount,
      currentTier: currentTier,
      history: List.unmodifiable(localHistory),
    );
  }

  static bool _sameSet(Set<String> left, Set<String> right) =>
      left.length == right.length && left.containsAll(right);

  static bool _isDayInWeek(String day, String weekKey, String endDay) {
    try {
      return learningWeekKey(day) == weekKey &&
          day.compareTo(weekKey) >= 0 &&
          day.compareTo(endDay) <= 0;
    } on ArgumentError {
      return false;
    }
  }

  static String _addDays(String day, int days) {
    final parts = day.split('-').map(int.parse).toList(growable: false);
    final value = DateTime.utc(
      parts[0],
      parts[1],
      parts[2],
    ).add(Duration(days: days));
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }
}
