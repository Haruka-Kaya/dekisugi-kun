import '../../models/game_hub.dart';
import '../../models/game_path.dart';
import '../../models/day_key.dart';
import '../../models/game_economy.dart';
import '../../models/unit.dart';
import '../../models/streak.dart' show streakAfterMiss;
import '../domain/learning_economy.dart';
import '../domain/learning_event.dart';
import '../domain/learning_monthly_badge.dart';
import '../domain/learning_policy.dart';
import '../domain/learning_progress.dart';
import 'game_path_projection.dart';
import 'learning_economy_catalog_projection.dart';
import 'learning_monthly_badge_projection.dart';

class LearningGameProjectionResult {
  const LearningGameProjectionResult({
    required this.path,
    required this.player,
    required this.quests,
    required this.duePracticeCount,
    required this.localCoopQuests,
    required this.economy,
    required this.leagueHistory,
    required this.featureState,
    required this.monthlyBadges,
  });

  final GamePathViewData path;
  final PlayerSummaryView player;
  final List<QuestView> quests;
  final int duePracticeCount;
  final List<LearningLocalCoopQuestView> localCoopQuests;
  final LearningEconomyView economy;
  final List<LearningLeagueWeek> leagueHistory;
  final LearningMotivationFeatureState featureState;
  final List<LearningMonthlyBadgeAward> monthlyBadges;
}

class LearningLocalCoopQuestView {
  const LearningLocalCoopQuestView({
    required this.runId,
    required this.progress,
    required this.target,
    required this.participantCount,
    required this.contributingParticipantCount,
    required this.gemReward,
    required this.completed,
  });

  final String runId;
  final int progress;
  final int target;
  final int participantCount;
  final int contributingParticipantCount;
  final int gemReward;
  final bool completed;
}

class LearningEconomyView {
  const LearningEconomyView({
    required this.available,
    required this.gems,
    required this.streakFreezeRefillGemCost,
    required this.challengeHeartRecoveryGemCost,
    required this.canRefillStreakFreeze,
    required this.canRecoverChallengeHearts,
    required this.cosmeticItems,
    required this.equippedPathMascotStyle,
    required this.timedChallengePassGemCost,
    required this.timedChallengePassActive,
    required this.canPurchaseTimedChallengePass,
  });

  final bool available;
  final int gems;
  final int? streakFreezeRefillGemCost;
  final int? challengeHeartRecoveryGemCost;
  final bool canRefillStreakFreeze;
  final bool canRecoverChallengeHearts;
  final List<GameCosmeticItemView> cosmeticItems;
  final LearningPathMascotStyle equippedPathMascotStyle;
  final int? timedChallengePassGemCost;
  final bool timedChallengePassActive;
  final bool canPurchaseTimedChallengePass;
}

/// append-only台帳から、6タブで共有する表示値を一度だけ導く。
///
/// 画面ごとにXP・streak・dueを再計算させない。学校scopeはDBで報酬不可だが、
/// ここでも個人walletを混ぜず、ハート無制限・gem 0として表示する。
class LearningGameProjection {
  const LearningGameProjection({
    this.pathProjection = const GamePathProjection(),
    this.monthlyBadgeProjection = const LearningMonthlyBadgeProjection(),
    this.economyCatalogProjection = const LearningEconomyCatalogProjection(),
  });

  final GamePathProjection pathProjection;
  final LearningMonthlyBadgeProjection monthlyBadgeProjection;
  final LearningEconomyCatalogProjection economyCatalogProjection;

  LearningGameProjectionResult build({
    required List<UnitSummary> catalog,
    required LearningProgressSnapshot snapshot,
    required DateTime now,
    bool schoolMode = false,
    Set<String> legacyCompletedSkillIds = const <String>{},
    Map<String, String> questTitles = const <String, String>{},
    List<LearningQuestDefinition> activeQuestDefinitions = const [],
    SafeLearningEconomyPolicyV1 economyPolicy =
        const SafeLearningEconomyPolicyV1(),
  }) {
    economyPolicy.validate();
    final today = dayKeyOf(now.toLocal());
    final cleared = <String>{};
    final inProgress = <String>{};
    final nodeProgress = <String, LearningNodeProgress>{};
    for (final node in snapshot.nodes) {
      nodeProgress[node.nodeId] = node;
      if (node.state == LearningNodeState.cleared) {
        cleared.add(node.nodeId);
      } else {
        inProgress.add(node.nodeId);
      }
    }
    // 回答は保存しないが、OS終了後も「このノードに取り組んでいた」ことだけは
    // Pathへ戻す。完了projectionが既にあるnodeはcompletedを優先する。
    for (final run in snapshot.runs) {
      if (!cleared.contains(run.nodeId)) inProgress.add(run.nodeId);
    }

    final catalogSkillIds = {
      for (final unit in catalog)
        for (final concept in unit.concepts) '${unit.id}/${concept.key}',
    };
    final due = <String>{};
    for (final skill in snapshot.skills) {
      if (catalogSkillIds.contains(skill.skillId) &&
          (skill.lastOutcome == LearningSkillOutcome.needsPractice ||
              skill.nextDueDay.compareTo(today) <= 0)) {
        due.add(skill.skillId);
      }
    }

    final skillsById = {
      for (final skill in snapshot.skills) skill.skillId: skill,
    };
    final legendaryAvailableUnits = <String>{};
    final legendaryCompletedUnits = <String>{};
    final legendaryRewardEligibleUnits = <String>{};
    for (final unit in catalog) {
      final unitLegendaryId = GamePathProjection.unitLegendaryNodeId(unit.id);
      final unitLegendarySkill =
          skillsById[GamePathProjection.unitLegendarySkillId(unit.id)];
      final unitLegendaryWasCleared = cleared.contains(unitLegendaryId);
      final legacyLegendaryWasFullyCleared =
          unit.concepts.isNotEmpty &&
          unit.concepts.every(
            (concept) => cleared.contains(
              GamePathProjection.legacyConceptLegendaryNodeId(
                unit.id,
                concept.key,
              ),
            ),
          );
      final firstUnlockAvailable = _allBossesClearedBeforeToday(
        unit: unit,
        cleared: cleared,
        nodeProgress: nodeProgress,
        today: today,
      );

      if (unitLegendaryWasCleared) {
        if (_skillIsDueOnNewDay(unitLegendarySkill, today)) {
          legendaryAvailableUnits.add(unit.id);
          legendaryRewardEligibleUnits.add(unit.id);
        } else {
          legendaryCompletedUnits.add(unit.id);
        }
        continue;
      }

      if (legacyLegendaryWasFullyCleared) {
        // v1 concept Legendaryはappend-only履歴として残し、全concept clear済みの
        // ときだけv2 unit実績へ表示上昇格する。eventや報酬は生成しない。
        final migratedDue = unitLegendarySkill == null
            ? _anyLegacyConceptSkillDue(
                unit: unit,
                skillsById: skillsById,
                today: today,
              )
            : _skillIsDueOnNewDay(unitLegendarySkill, today);
        if (migratedDue) {
          legendaryAvailableUnits.add(unit.id);
        } else {
          legendaryCompletedUnits.add(unit.id);
        }
        continue;
      }

      if (firstUnlockAvailable) {
        legendaryAvailableUnits.add(unit.id);
        legendaryRewardEligibleUnits.add(unit.id);
      }
    }

    final wallet = snapshot.wallet;
    final heartState = snapshot.challengeHearts;
    if (!schoolMode && heartState == null) {
      throw StateError('personal snapshot has no challenge heart state');
    }
    final definitions = <String, LearningQuestDefinition>{};
    final orderedQuestIds = <String>[];
    for (final definition in activeQuestDefinitions) {
      if (definitions.containsKey(definition.questInstanceId)) {
        throw StateError('active quest definition IDs must be unique');
      }
      definitions[definition.questInstanceId] = definition;
      if (_questIsVisibleOn(definition.questInstanceId, today)) {
        orderedQuestIds.add(definition.questInstanceId);
      }
    }
    final persisted = <String, LearningQuestProgress>{};
    for (final quest in snapshot.quests) {
      if (quest.questInstanceId.startsWith('local-coop:')) continue;
      if (!_questIsVisibleOn(quest.questInstanceId, today)) continue;
      persisted[quest.questInstanceId] = quest;
      if (!orderedQuestIds.contains(quest.questInstanceId)) {
        orderedQuestIds.add(quest.questInstanceId);
      }
    }
    final displayedTargets = <String, int>{};
    final displayedProgress = <String, int>{};
    for (final id in orderedQuestIds) {
      final saved = persisted[id];
      final definition = definitions[id];
      final target = saved?.target ?? definition!.target;
      displayedTargets[id] = target;
      displayedProgress[id] =
          saved?.progress ??
          (schoolMode && definition != null
              ? _schoolQuestProgress(
                  events: snapshot.events,
                  definition: definition,
                )
              : 0);
    }
    final quests = <QuestView>[
      for (final id in orderedQuestIds)
        QuestView(
          id: id,
          title: questTitles[id] ?? _questTitle(id),
          progress: displayedProgress[id]!,
          target: displayedTargets[id]!,
          gemReward: schoolMode
              ? 0
              : _knownQuestGemReward(
                  definition: definitions[id],
                  persisted: persisted[id],
                ),
        ),
    ];
    final pathQuests = <GameQuest>[
      for (final id in orderedQuestIds)
        GameQuest(
          id: id,
          title: questTitles[id] ?? _questTitle(id),
          description: schoolMode
              ? 'この端末で取り組む授業目標です。クラス全体の件数は集計しません。'
              : '学習パスの中身を進めるクエストです。',
          kind: id.startsWith('monthly:')
              ? GameQuestKind.monthly
              : schoolMode
              ? GameQuestKind.classroom
              : GameQuestKind.daily,
          state: persisted[id]?.rewardedAt != null
              ? GameQuestState.claimed
              : (persisted[id]?.completed ??
                    displayedProgress[id]! >= displayedTargets[id]!)
              ? GameQuestState.completed
              : GameQuestState.active,
          current: displayedProgress[id]!.clamp(0, displayedTargets[id]!),
          target: displayedTargets[id]!,
          rewardLabel: schoolMode
              ? null
              : _questRewardLabel(
                  _knownQuestGemReward(
                    definition: definitions[id],
                    persisted: persisted[id],
                  ),
                ),
        ),
    ];

    final streakFreezeView = _streakFreezeView(
      snapshot,
      today,
      schoolMode: schoolMode,
    );
    final status = GamePlayerStatus(
      streakDays: _streakDays(
        snapshot.days,
        snapshot.freezes,
        today,
        virtualProtectedDays: streakFreezeView.virtualProtectedDays,
      ),
      streakFreezeRemaining: streakFreezeView.displayedRemaining,
      gems: schoolMode ? 0 : wallet.gems,
      hearts: schoolMode ? 0 : heartState!.current,
      maxHearts: schoolMode
          ? LearningChallengeHeartState.defaultMaximum
          : heartState!.maximum,
      unlimitedHearts: schoolMode,
    );
    final progress = GamePathProgressInput(
      clearedNodeIds: cleared,
      inProgressNodeIds: inProgress,
      reviewDueSkillIds: due,
      legendaryAvailableUnitIds: legendaryAvailableUnits,
      legendaryCompletedUnitIds: legendaryCompletedUnits,
      legendaryRewardEligibleUnitIds: legendaryRewardEligibleUnits,
      legacyCompletedSkillIds: legacyCompletedSkillIds,
    );
    const rewardPolicy = SafeLearningRewardPolicyV1();
    final eventDays = {
      for (final event in snapshot.events) event.eventId: event.learningDay,
    };
    final xpEarnedToday = snapshot.rewards
        .where(
          (reward) =>
              reward.type == LearningRewardType.xp &&
              reward.sourceEventId != null &&
              eventDays[reward.sourceEventId] == today,
        )
        .fold(0, (sum, reward) => sum + reward.amount);
    final rewardXpAvailable = schoolMode
        ? 0
        : (rewardPolicy.dailyXpCap - xpEarnedToday)
              .clamp(0, rewardPolicy.xpPerDistinctNode)
              .toInt();
    final path = pathProjection.build(
      catalog: catalog,
      progress: progress,
      status: status,
      quests: pathQuests,
      schoolMode: schoolMode,
      rewardXpAvailable: rewardXpAvailable,
    );
    final completedNodes = path.units
        .expand((unit) => unit.nodes)
        .where(
          (node) =>
              node.kind != GamePathNodeKind.legendary &&
              (node.state == GamePathNodeState.completed ||
                  node.state == GamePathNodeState.reviewDue),
        )
        .length;
    final totalNodes = path.units
        .expand((unit) => unit.nodes)
        .where((node) => node.kind != GamePathNodeKind.legendary)
        .length;
    final weeklyXp = _weeklyXp(snapshot, today);
    final featureState = schoolMode
        ? const LearningMotivationFeatureState.school()
        : snapshot.motivationFeatures;
    final paidFreezeRefillsThisWeek = snapshot.gemSpends
        .where(
          (item) =>
              item.kind == LearningGemSpendKind.streakFreezeRefill &&
              item.weekKey == learningWeekKey(today),
        )
        .length;
    final localCoopQuests = schoolMode
        ? const <LearningLocalCoopQuestView>[]
        : [
            for (final run in snapshot.localCoopRuns)
              LearningLocalCoopQuestView(
                runId: run.runId,
                progress: run.progress.clamp(0, run.target),
                target: run.target,
                participantCount: run.participantIds.length,
                contributingParticipantCount:
                    run.contributingParticipantIds.length,
                gemReward: run.rewardGems,
                completed: run.completed,
              ),
          ];
    final cosmeticState = schoolMode
        ? const LearningCosmeticState.initial()
        : snapshot.cosmetics ?? const LearningCosmeticState.initial();
    const economyCatalog = SafeLearningEconomyCatalogV1();
    final timedPass = SafeLearningEconomyCatalogV1.timedDayPass;
    final timedPassActive =
        !schoolMode &&
        snapshot.hasChallengePass(
          productId: timedPass.productId,
          learningDay: today,
        );
    final economy = LearningEconomyView(
      available: !schoolMode && featureState.gemEconomyAvailable,
      gems: schoolMode ? 0 : wallet.gems,
      streakFreezeRefillGemCost: schoolMode
          ? null
          : economyPolicy.streakFreezeRefillGemCost,
      challengeHeartRecoveryGemCost: schoolMode
          ? null
          : economyPolicy.challengeHeartRecoveryGemCost,
      canRefillStreakFreeze:
          !schoolMode &&
          snapshot.streakFreezeRemainingFor(today) == 0 &&
          paidFreezeRefillsThisWeek <
              economyPolicy.maxPaidFreezeRefillsPerWeek &&
          wallet.gems >= economyPolicy.streakFreezeRefillGemCost,
      canRecoverChallengeHearts:
          !schoolMode &&
          status.hearts < status.maxHearts &&
          wallet.gems >= economyPolicy.challengeHeartRecoveryGemCost,
      cosmeticItems: economyCatalogProjection.cosmetics(
        gems: schoolMode ? 0 : wallet.gems,
        state: cosmeticState,
        schoolMode: schoolMode,
      ),
      equippedPathMascotStyle: schoolMode
          ? LearningPathMascotStyle.standard
          : economyCatalog
                .cosmetic(cosmeticState.equippedPathMascotId)
                .mascotStyle,
      timedChallengePassGemCost: schoolMode ? null : timedPass.gemCost,
      timedChallengePassActive: timedPassActive,
      canPurchaseTimedChallengePass:
          !schoolMode && !timedPassActive && wallet.gems >= timedPass.gemCost,
    );
    final player = PlayerSummaryView(
      xp: schoolMode ? 0 : wallet.xp,
      gems: schoolMode ? 0 : wallet.gems,
      streakDays: status.streakDays,
      freezeCount: status.streakFreezeRemaining,
      challengeHearts: status.hearts,
      maxChallengeHearts: status.maxHearts,
      completedNodes: completedNodes,
      totalNodes: totalNodes,
      leagueName: schoolMode
          ? '学校モード'
          : learningLeagueTierForXp(weeklyXp).label,
      weeklyLeagueXp: schoolMode ? 0 : weeklyXp,
      nextLeagueXp: schoolMode ? 0 : learningLeagueNextTarget(weeklyXp),
    );
    final monthlyBadges = schoolMode
        ? const <LearningMonthlyBadgeAward>[]
        : monthlyBadgeProjection.build(snapshot);
    return LearningGameProjectionResult(
      path: path,
      player: player,
      quests: List.unmodifiable(quests),
      duePracticeCount: due.length,
      localCoopQuests: List.unmodifiable(localCoopQuests),
      economy: economy,
      leagueHistory: schoolMode
          ? const []
          : List.unmodifiable(snapshot.leagueHistory),
      featureState: featureState,
      monthlyBadges: monthlyBadges,
    );
  }

  static int _streakDays(
    List<LearningDay> days,
    List<LearningStreakFreeze> freezes,
    String today, {
    Set<String> virtualProtectedDays = const {},
  }) {
    final learned = {
      for (final day in days)
        if (day.qualifyingCount > 0) day.day,
    };
    if (learned.isEmpty) return 0;
    final protected = {
      for (final freeze in freezes) freeze.day,
      ...virtualProtectedDays,
    };
    final first = learned
        .where((day) => day.compareTo(today) <= 0)
        .fold<String?>(null, (oldest, day) {
          if (oldest == null || day.compareTo(oldest) < 0) return day;
          return oldest;
        });
    if (first == null) return 0;

    // C6: 長く積み上げた記録を、1日の欠けで突然0へ戻さない。
    // 保存するのは日ごとの事実だけにし、最古の学習日から再生することで
    // 再起動・過去データ移行でも同じ値を導く。freeze日は継続を守るが、
    // 実際に学んだ日ではないため日数そのものは増やさない。
    var cursor = DateTime.parse(first);
    final end = DateTime.parse(today);
    var count = 0;
    while (!cursor.isAfter(end)) {
      final day = _dayKey(cursor);
      if (learned.contains(day)) {
        count += 1;
      } else if (protected.contains(day)) {
        // 維持だけ。学習日として水増ししない。
      } else if (day == today) {
        // 朝アプリを開いただけで、きのうまでの値をさらに減らさない。
        break;
      } else {
        count = streakAfterMiss(count);
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return count;
  }

  static ({Set<String> virtualProtectedDays, int displayedRemaining})
  _streakFreezeView(
    LearningProgressSnapshot snapshot,
    String today, {
    required bool schoolMode,
  }) {
    final currentWeekRemaining = snapshot.streakFreezeRemainingFor(today);
    if (schoolMode || snapshot.scope != LearningScope.personal) {
      return (
        virtualProtectedDays: const <String>{},
        displayedRemaining: currentWeekRemaining,
      );
    }
    final qualifyingDays = snapshot.days
        .where((day) => day.qualifyingCount > 0)
        .map((day) => day.day)
        .toSet();
    if (qualifyingDays.contains(today) ||
        qualifyingDays.any((day) => day.compareTo(today) > 0)) {
      return (
        virtualProtectedDays: const <String>{},
        displayedRemaining: currentWeekRemaining,
      );
    }
    final previousDay = qualifyingDays
        .where((day) => day.compareTo(today) < 0)
        .fold<String?>(null, (latest, day) {
          if (latest == null || day.compareTo(latest) > 0) return day;
          return latest;
        });
    if (previousDay != shiftDay(today, -2)) {
      return (
        virtualProtectedDays: const <String>{},
        displayedRemaining: currentWeekRemaining,
      );
    }
    final missedDay = shiftDay(today, -1);
    if (snapshot.freezes.any((freeze) => freeze.day == missedDay) ||
        snapshot.streakFreezeRemainingFor(missedDay) <= 0) {
      return (
        virtualProtectedDays: const <String>{},
        displayedRemaining: currentWeekRemaining,
      );
    }
    final missedWeekIsCurrentWeek =
        learningWeekKey(missedDay) == learningWeekKey(today);
    return (
      virtualProtectedDays: {missedDay},
      displayedRemaining: missedWeekIsCurrentWeek
          ? (currentWeekRemaining - 1).clamp(0, currentWeekRemaining)
          : currentWeekRemaining,
    );
  }

  static int _weeklyXp(LearningProgressSnapshot snapshot, String today) {
    final now = DateTime.parse(today);
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final firstDay = _dayKey(monday);
    final eventIds = {
      for (final event in snapshot.events)
        if (event.learningDay.compareTo(firstDay) >= 0 &&
            event.learningDay.compareTo(today) <= 0)
          event.eventId,
    };
    return snapshot.rewards
        .where(
          (reward) =>
              reward.type == LearningRewardType.xp &&
              reward.sourceEventId != null &&
              eventIds.contains(reward.sourceEventId),
        )
        .fold(0, (sum, reward) => sum + reward.amount);
  }

  static bool _allBossesClearedBeforeToday({
    required UnitSummary unit,
    required Set<String> cleared,
    required Map<String, LearningNodeProgress> nodeProgress,
    required String today,
  }) {
    if (unit.concepts.isEmpty) return false;
    String? latestCompletedDay;
    for (final concept in unit.concepts) {
      final challengeId = GamePathProjection.nodeId(
        unit.id,
        concept.key,
        GamePathNodeKind.challenge,
      );
      if (!cleared.contains(challengeId)) return false;
      final completedAt = nodeProgress[challengeId]?.completedAt?.toLocal();
      if (completedAt == null) return false;
      final completedDay = dayKeyOf(completedAt);
      if (latestCompletedDay == null ||
          completedDay.compareTo(latestCompletedDay) > 0) {
        latestCompletedDay = completedDay;
      }
    }
    return latestCompletedDay!.compareTo(today) < 0;
  }

  static bool _skillIsDueOnNewDay(LearningSkillProgress? skill, String today) =>
      skill?.lastSuccessDay != null &&
      skill!.lastSuccessDay!.compareTo(today) < 0 &&
      skill.nextDueDay.compareTo(today) <= 0;

  static bool _anyLegacyConceptSkillDue({
    required UnitSummary unit,
    required Map<String, LearningSkillProgress> skillsById,
    required String today,
  }) =>
      unit.concepts.isNotEmpty &&
      unit.concepts.any(
        (concept) =>
            _skillIsDueOnNewDay(skillsById['${unit.id}/${concept.key}'], today),
      );

  static bool _questIsVisibleOn(String id, String today) {
    final split = id.split(':');
    if (split.length < 2) return true;
    if (split.first == 'daily') return split[1] == today;
    if (split.first == 'monthly') {
      return split[1] == today.substring(0, 7);
    }
    return true;
  }

  static int _knownQuestGemReward({
    required LearningQuestDefinition? definition,
    required LearningQuestProgress? persisted,
  }) {
    if (definition == null) return 0;
    if (persisted != null &&
        (persisted.target != definition.target ||
            persisted.definitionVersion != definition.definitionVersion)) {
      return 0;
    }
    return definition.rewardGems;
  }

  static int _schoolQuestProgress({
    required List<LearningEventRecord> events,
    required LearningQuestDefinition definition,
  }) {
    final distinctNodesByDay = <String>{};
    for (final event in events) {
      if (event.scope != LearningScope.schoolLocal ||
          !definition.includesLearningDay(event.learningDay) ||
          event.outcome == LearningAttemptOutcome.retryNeeded ||
          event.evidence.rank < definition.minimumEvidence.rank ||
          (definition.allowedOrigins.isNotEmpty &&
              !definition.allowedOrigins.contains(event.origin)) ||
          (definition.allowedActivityKinds.isNotEmpty &&
              !definition.allowedActivityKinds.contains(event.activityKind))) {
        continue;
      }
      distinctNodesByDay.add('${event.learningDay}/${event.nodeId}');
    }
    return distinctNodesByDay.length.clamp(0, definition.target);
  }

  static String? _questRewardLabel(int amount) =>
      amount > 0 ? '結晶$amount個' : null;

  static String _questTitle(String id) {
    if (id.contains('transfer')) return '別の場面へ1回使う';
    if (id.contains('retrieval') || id.contains('review')) {
      return '期限の来た復習を進める';
    }
    return '学習パスを1件進める';
  }

  static String _dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
