import 'learning_event.dart';
import 'learning_economy.dart';
import '../../models/league_ladder.dart';

enum LearningNodeState {
  inProgress,
  cleared;

  String get wire => name;

  static LearningNodeState? parse(Object? value) => switch (value) {
    'inProgress' => LearningNodeState.inProgress,
    'cleared' => LearningNodeState.cleared,
    _ => null,
  };
}

/// 概念・図・式など、再出題単位の最後の派生状態。
///
/// 能力の断定ではなく、次にどの学習行為を出すかだけを表す。
enum LearningSkillOutcome {
  needsPractice,
  completed,
  retained;

  String get wire => name;

  static LearningSkillOutcome? parse(Object? value) => switch (value) {
    'completed' => LearningSkillOutcome.completed,
    'retained' => LearningSkillOutcome.retained,
    'needsPractice' => LearningSkillOutcome.needsPractice,
    _ => null,
  };
}

final class LearningNodeProgress {
  const LearningNodeProgress({
    required this.scope,
    required this.nodeId,
    required this.state,
    required this.attemptCount,
    required this.bestEvidence,
    required this.lastAttemptDay,
    required this.lastEventId,
    required this.completedAt,
    required this.contentVersion,
  });

  final LearningScope scope;
  final String nodeId;
  final LearningNodeState state;
  final int attemptCount;
  final LearningEvidenceLevel bestEvidence;
  final String lastAttemptDay;
  final String lastEventId;
  final DateTime? completedAt;
  final String contentVersion;
}

final class LearningSkillProgress {
  const LearningSkillProgress({
    required this.scope,
    required this.skillId,
    required this.lastOutcome,
    required this.successfulRetrievals,
    required this.lastAttemptDay,
    required this.lastSuccessDay,
    required this.nextDueDay,
    required this.lastEventId,
  });

  final LearningScope scope;
  final String skillId;
  final LearningSkillOutcome lastOutcome;
  final int successfulRetrievals;
  final String lastAttemptDay;
  final String? lastSuccessDay;
  final String nextDueDay;
  final String lastEventId;
}

/// 固定教材の誤答から観測した、次の構造練習を選ぶための一般化need。
///
/// 誤答本文・選択肢ID・音声は持たない。解消済みのtombstoneは保存層だけに残し、
/// snapshotには現在activeな行だけを返す。
final class LearningActiveNeed {
  const LearningActiveNeed({
    required this.scope,
    required this.skillId,
    required this.needCode,
    required this.firstObservedDay,
    required this.lastObservedDay,
    required this.lastObservedAt,
  });

  final LearningScope scope;
  final String skillId;
  final String needCode;
  final String firstObservedDay;
  final String lastObservedDay;
  final DateTime lastObservedAt;
}

final class LearningDay {
  const LearningDay({
    required this.scope,
    required this.day,
    required this.qualifyingCount,
    required this.firstEventAt,
    required this.lastEventAt,
  });

  final LearningScope scope;
  final String day;
  final int qualifyingCount;
  final DateTime firstEventAt;
  final DateTime lastEventAt;
}

/// 連続学習を保護するために実際に消費された1日分のfreeze。
///
/// `day`は学習しなかった日、`weekKey`はその日を含む月曜始まりの週を表す。
/// personal scopeだけが保持でき、学校課題の進捗には混ぜない。
final class LearningStreakFreeze {
  const LearningStreakFreeze({
    required this.scope,
    required this.day,
    required this.weekKey,
    required this.usedAt,
  });

  final LearningScope scope;
  final String day;
  final String weekKey;
  final DateTime usedAt;
}

enum LearningGemSpendKind {
  streakFreezeRefill,
  challengeHeartRecovery,
  cosmeticPurchase,
  challengeEntry;

  String get wire => name;

  static LearningGemSpendKind? parse(Object? value) => switch (value) {
    'streakFreezeRefill' => LearningGemSpendKind.streakFreezeRefill,
    'challengeHeartRecovery' => LearningGemSpendKind.challengeHeartRecovery,
    'cosmeticPurchase' => LearningGemSpendKind.cosmeticPurchase,
    'challengeEntry' => LearningGemSpendKind.challengeEntry,
    _ => null,
  };
}

/// 結晶の実消費。回答や正誤は持たず、固定catalogの安全な用途だけを残す。
final class LearningGemSpend {
  const LearningGemSpend({
    required this.spendId,
    required this.scope,
    required this.kind,
    required this.amount,
    required this.learningDay,
    required this.weekKey,
    required this.occurredAt,
    this.referenceId,
  });

  final String spendId;
  final LearningScope scope;
  final LearningGemSpendKind kind;
  final int amount;
  final String learningDay;
  final String? weekKey;
  final DateTime occurredAt;

  /// cosmetic / challenge passの固定catalog ID。自由入力や回答は置かない。
  final String? referenceId;
}

final class LearningGemSpendResult {
  const LearningGemSpendResult({
    required this.applied,
    required this.spend,
    required this.remainingGems,
    required this.streakFreezeRemaining,
    required this.challengeHearts,
  });

  final bool applied;
  final LearningGemSpend spend;
  final int remainingGems;
  final int streakFreezeRemaining;
  final LearningChallengeHeartState challengeHearts;
}

/// 個人学習の固定課題で共有する端末内heart状態。
///
/// 学校scopeはこの状態を持たず常に無制限。初期値、上限、時間回復間隔は
/// 公開契約として固定し、画面側が推測した値で増減させない。
final class LearningChallengeHeartState {
  const LearningChallengeHeartState({
    required this.scope,
    required this.current,
    required this.maximum,
    required this.lastLossDay,
    required this.lastRecoveryDay,
    required this.updatedAt,
  });

  static const int defaultMaximum = 5;
  static const Duration recoveryInterval = Duration(minutes: 30);

  const LearningChallengeHeartState.initial()
    : scope = LearningScope.personal,
      current = defaultMaximum,
      maximum = defaultMaximum,
      lastLossDay = null,
      lastRecoveryDay = null,
      updatedAt = null;

  final LearningScope scope;
  final int current;
  final int maximum;
  final String? lastLossDay;
  final String? lastRecoveryDay;
  final DateTime? updatedAt;

  DateTime? get nextRecoveryAt => current >= maximum || updatedAt == null
      ? null
      : updatedAt!.add(recoveryInterval);
}

/// 1回のheart消費結果。`spent == false`は同じloss IDの安全な再送。
final class LearningChallengeHeartSpendResult {
  const LearningChallengeHeartSpendResult({
    required this.spent,
    required this.state,
    required this.run,
  });

  final bool spent;
  final LearningChallengeHeartState state;

  /// 消費後もrunが残っている場合のcheckpoint。完了後の冪等再送ではnull。
  final LearningRun? run;
}

/// 時間経過による回復結果。回復待ちでなければ[recovered]は0。
final class LearningChallengeHeartRefreshResult {
  const LearningChallengeHeartRefreshResult({
    required this.recovered,
    required this.state,
  });

  final int recovered;
  final LearningChallengeHeartState state;
}

/// 専用のハート回復練習を完了した結果。
///
/// [applied]がfalseなら同じrecovery IDの安全な再送。[recovered]は初回に
/// 実際に戻した個数で、時間回復と競合して既に満タンなら0になりうる。
final class LearningChallengeHeartPracticeRecoveryResult {
  const LearningChallengeHeartPracticeRecoveryResult({
    required this.applied,
    required this.recovered,
    required this.state,
  });

  final bool applied;
  final int recovered;
  final LearningChallengeHeartState state;
}

enum LearningRewardType {
  xp,
  gems;

  String get wire => name;

  static LearningRewardType? parse(Object? value) => switch (value) {
    'xp' => LearningRewardType.xp,
    'gems' => LearningRewardType.gems,
    _ => null,
  };
}

final class LearningRewardEntry {
  const LearningRewardEntry({
    required this.entryId,
    required this.scope,
    required this.type,
    required this.amount,
    required this.reason,
    required this.sourceEventId,
    required this.createdAt,
  });

  final String entryId;
  final LearningScope scope;
  final LearningRewardType type;
  final int amount;
  final String reason;
  final String? sourceEventId;
  final DateTime createdAt;
}

/// 認証済みLAN friends roomの達成を、個人の結晶台帳へ一度だけ反映した結果。
///
/// room ID以外の参加者情報や学習eventを報酬台帳へ複製しない。`applied`がfalseなら
/// 同じroomの安全な再読込で、[reward]は初回と同じ固定報酬を指す。
final class LearningLanFriendsRewardResult {
  const LearningLanFriendsRewardResult({
    required this.applied,
    required this.reward,
  });

  final bool applied;
  final LearningRewardEntry reward;
}

final class LearningQuestProgress {
  const LearningQuestProgress({
    required this.scope,
    required this.questInstanceId,
    required this.progress,
    required this.target,
    required this.completedAt,
    required this.rewardedAt,
    required this.definitionVersion,
  });

  final LearningScope scope;
  final String questInstanceId;
  final int progress;
  final int target;
  final DateTime? completedAt;
  final DateTime? rewardedAt;
  final String definitionVersion;

  bool get completed => completedAt != null;
}

/// 未着手Questを0件の状態で永続化した結果。
///
/// [insertedCount]が0なら、同じdefinitionの再送で永続状態は変わっていない。
/// [quests]は入力definitionと同じ順序で、既存行を含む現在値を返す。
final class LearningQuestMaterializationResult {
  LearningQuestMaterializationResult({
    required this.insertedCount,
    required Iterable<LearningQuestProgress> quests,
  }) : quests = List.unmodifiable(quests) {
    if (insertedCount < 0 || insertedCount > this.quests.length) {
      throw ArgumentError.value(insertedCount, 'insertedCount');
    }
  }

  final int insertedCount;
  final List<LearningQuestProgress> quests;

  bool get changed => insertedCount > 0;
}

/// 同じ端末を手渡して進める、明示的なローカル協力questの開始契約。
///
/// participant IDはrun内だけで使う不透明なslot ID。名前・アカウント・友達関係を
/// 保存せず、2人以上のslotを明示しない限り協力runを開始できない。
final class LearningLocalCoopRunCommand {
  LearningLocalCoopRunCommand({
    required this.runId,
    required Iterable<String> participantIds,
    required this.target,
    required this.rewardGems,
    required this.startDay,
    required this.endDay,
    required this.definitionVersion,
    required this.startedAt,
  }) : participantIds = Set.unmodifiable(participantIds);

  final String runId;
  final Set<String> participantIds;
  final int target;
  final int rewardGems;
  final String startDay;
  final String endDay;
  final String definitionVersion;
  final DateTime startedAt;

  String get questInstanceId => 'local-coop:$runId';
}

final class LearningLocalCoopRun {
  const LearningLocalCoopRun({
    required this.runId,
    required this.scope,
    required this.questInstanceId,
    required this.participantIds,
    required this.contributingParticipantIds,
    required this.progress,
    required this.target,
    required this.rewardGems,
    required this.startDay,
    required this.endDay,
    required this.definitionVersion,
    required this.startedAt,
    required this.completedAt,
    required this.rewardedAt,
  });

  final String runId;
  final LearningScope scope;
  final String questInstanceId;
  final Set<String> participantIds;
  final Set<String> contributingParticipantIds;
  final int progress;
  final int target;
  final int rewardGems;
  final String startDay;
  final String endDay;
  final String definitionVersion;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime? rewardedAt;

  bool get completed => completedAt != null;
  bool get allParticipantsContributed =>
      contributingParticipantIds.containsAll(participantIds);
}

final class LearningLocalCoopContributionResult {
  const LearningLocalCoopContributionResult({
    required this.applied,
    required this.run,
    required this.rewards,
  });

  final bool applied;
  final LearningLocalCoopRun run;
  final List<LearningRewardEntry> rewards;
}

/// ローカル共同runへ実際に使われた学習eventのread-only参照。
///
/// 氏名・回答・選択肢・音声は持たず、週次集計が実在する端末内参加だけを
/// 数えるためのIDと学習日、保存済みmeaningful判定だけを返す。
final class LearningLocalCoopContribution {
  const LearningLocalCoopContribution({
    required this.runId,
    required this.participantId,
    required this.eventId,
    required this.scope,
    required this.learningDay,
    required this.meaningfulProgress,
  });

  final String runId;
  final String participantId;
  final String eventId;
  final LearningScope scope;
  final String learningDay;
  final bool meaningfulProgress;
}

enum LearningLeagueTier {
  observer,
  experimenter,
  investigator,
  researchLead;

  String get wire => name;

  String get label => switch (this) {
    LearningLeagueTier.observer => '観察者',
    LearningLeagueTier.experimenter => '実験者',
    LearningLeagueTier.investigator => '探究者',
    LearningLeagueTier.researchLead => '研究主任',
  };

  static LearningLeagueTier? parse(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

enum LearningLeagueMovement {
  promoted,
  stayed,
  demoted;

  String get wire => name;

  static LearningLeagueMovement? parse(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// 外部対戦相手や順位を含まない、端末内の週次XP tier確定履歴。
final class LearningLeagueWeek {
  const LearningLeagueWeek({
    required this.scope,
    required this.weekKey,
    required this.xp,
    required this.previousTier,
    required this.tier,
    required this.movement,
    required this.finalizedAt,
  });

  final LearningScope scope;
  final String weekKey;
  final int xp;
  final LearningLeagueTier previousTier;
  final LearningLeagueTier tier;
  final LearningLeagueMovement movement;
  final DateTime finalizedAt;
}

/// 同じ端末の実参加者順位を根拠に確定した、slot 1の10段tier履歴。
///
/// 氏名・participant ID・回答・選択肢・正誤・音声は保持しない。slot 1は
/// UI上の「この端末の学習者」で、他slotは週を越えて追跡しない。
final class LearningLocalLeagueWeek {
  const LearningLocalLeagueWeek({
    required this.scope,
    required this.weekKey,
    required this.meaningfulEventCount,
    required this.rank,
    required this.tied,
    required this.participantCount,
    required this.previousTier,
    required this.tier,
    required this.movement,
    required this.finalizedAt,
  });

  final LearningScope scope;
  final String weekKey;
  final int meaningfulEventCount;
  final int? rank;
  final bool tied;
  final int participantCount;
  final LanSocialLeagueTier previousTier;
  final LanSocialLeagueTier tier;
  final LanSocialLeagueMovement movement;
  final DateTime finalizedAt;
}

enum LearningLocalLeagueFinalizeStatus {
  finalized,
  alreadyFinalized,
  weekInProgress,
  notStarted,
  invalidData,
  insufficientParticipants,
  outOfOrder,
}

final class LearningLocalLeagueFinalizeResult {
  const LearningLocalLeagueFinalizeResult({
    required this.status,
    required this.week,
  });

  final LearningLocalLeagueFinalizeStatus status;
  final LearningLocalLeagueWeek? week;

  bool get applied => status == LearningLocalLeagueFinalizeStatus.finalized;
}

LearningLeagueTier learningLeagueTierForXp(int xp) => switch (xp) {
  < 60 => LearningLeagueTier.observer,
  < 120 => LearningLeagueTier.experimenter,
  < 180 => LearningLeagueTier.investigator,
  _ => LearningLeagueTier.researchLead,
};

int learningLeagueNextTarget(int xp) => switch (xp) {
  < 60 => 60,
  < 120 => 120,
  < 180 => 180,
  _ => 210,
};

/// 実装済み/未実装のsocial境界。外部相手を0件の架空データで代用しない。
final class LearningMotivationFeatureState {
  const LearningMotivationFeatureState({
    required this.localCoopRunsAvailable,
    required this.localWeeklyLeagueAvailable,
    required this.externalFriendsAvailable,
    required this.externalLeagueAvailable,
    required this.gemEconomyAvailable,
  });

  const LearningMotivationFeatureState.personalLocalOnly()
    : localCoopRunsAvailable = true,
      localWeeklyLeagueAvailable = true,
      externalFriendsAvailable = false,
      externalLeagueAvailable = false,
      gemEconomyAvailable = true;

  const LearningMotivationFeatureState.school()
    : localCoopRunsAvailable = false,
      localWeeklyLeagueAvailable = false,
      externalFriendsAvailable = false,
      externalLeagueAvailable = false,
      gemEconomyAvailable = false;

  final bool localCoopRunsAvailable;
  final bool localWeeklyLeagueAvailable;
  final bool externalFriendsAvailable;
  final bool externalLeagueAvailable;
  final bool gemEconomyAvailable;
}

/// OS終了後に復元してよい最小状態。
///
/// 回答は含まず、次に表示するactivity番号だけを残す。
final class LearningRun {
  const LearningRun({
    required this.runId,
    required this.scope,
    required this.nodeId,
    required this.activityIndex,
    required this.challengeHearts,
    required this.contentVersion,
    required this.updatedAt,
  });

  final String runId;
  final LearningScope scope;
  final String nodeId;
  final int activityIndex;
  final int? challengeHearts;
  final String contentVersion;
  final DateTime updatedAt;
}

final class LearningWallet {
  const LearningWallet({required this.xp, required this.gems});

  final int xp;
  final int gems;
}

final class LearningProgressSnapshot {
  const LearningProgressSnapshot({
    required this.scope,
    required this.events,
    required this.nodes,
    required this.skills,
    required this.days,
    required this.freezes,
    required this.challengeHearts,
    required this.rewards,
    required this.quests,
    required this.runs,
    this.activeNeeds = const [],
    this.gemSpends = const [],
    this.cosmetics,
    this.localCoopRuns = const [],
    this.leagueHistory = const [],
    this.localLeagueHistory = const [],
  });

  final LearningScope scope;
  final List<LearningEventRecord> events;
  final List<LearningNodeProgress> nodes;
  final List<LearningSkillProgress> skills;
  final List<LearningDay> days;
  final List<LearningStreakFreeze> freezes;

  /// personalは未消費でも初期契約を返す。schoolLocalはheart無制限なのでnull。
  final LearningChallengeHeartState? challengeHearts;
  final List<LearningRewardEntry> rewards;
  final List<LearningQuestProgress> quests;
  final List<LearningRun> runs;
  final List<LearningActiveNeed> activeNeeds;
  final List<LearningGemSpend> gemSpends;

  /// personal storeは常に実状態を返す。fixtureとschoolLocalではnullを許す。
  final LearningCosmeticState? cosmetics;
  final List<LearningLocalCoopRun> localCoopRuns;
  final List<LearningLeagueWeek> leagueHistory;
  final List<LearningLocalLeagueWeek> localLeagueHistory;

  LanSocialLeagueTier get currentLocalLeagueTier => localLeagueHistory.isEmpty
      ? LanSocialLeagueTier.bronze
      : (localLeagueHistory.toList()
              ..sort((left, right) => right.weekKey.compareTo(left.weekKey)))
            .first
            .tier;

  LearningMotivationFeatureState get motivationFeatures =>
      scope == LearningScope.personal
      ? const LearningMotivationFeatureState.personalLocalOnly()
      : const LearningMotivationFeatureState.school();

  LearningWallet get wallet {
    final gems =
        rewards
            .where((entry) => entry.type == LearningRewardType.gems)
            .fold<int>(0, (sum, entry) => sum + entry.amount) -
        gemSpends.fold<int>(0, (sum, entry) => sum + entry.amount);
    if (gems < 0) {
      throw StateError('learning gem balance cannot be negative');
    }
    return LearningWallet(
      xp: rewards
          .where((entry) => entry.type == LearningRewardType.xp)
          .fold(0, (sum, entry) => sum + entry.amount),
      gems: gems,
    );
  }

  bool hasChallengePass({
    required String productId,
    required String learningDay,
  }) =>
      scope == LearningScope.personal &&
      gemSpends.any(
        (item) =>
            item.kind == LearningGemSpendKind.challengeEntry &&
            item.referenceId == productId &&
            item.learningDay == learningDay,
      );

  /// [day]を含む月曜始まりの週で、まだ使えるfreeze数。
  ///
  /// launch契約は1週1回。学校scopeにはfreezeを付与しない。
  int streakFreezeRemainingFor(String day) {
    if (scope != LearningScope.personal) return 0;
    final weekKey = learningWeekKey(day);
    final used = freezes.where((item) => item.weekKey == weekKey).length;
    final refills = gemSpends
        .where(
          (item) =>
              item.kind == LearningGemSpendKind.streakFreezeRefill &&
              item.weekKey == weekKey,
        )
        .length;
    return (1 + refills - used).clamp(0, 1 + refills);
  }
}

final class CommitLearningResult {
  const CommitLearningResult({
    required this.event,
    required this.inserted,
    required this.node,
    required this.skills,
    required this.rewards,
    required this.quests,
  });

  final LearningEventRecord event;
  final bool inserted;
  final LearningNodeProgress node;
  final List<LearningSkillProgress> skills;
  final List<LearningRewardEntry> rewards;
  final List<LearningQuestProgress> quests;
}

/// `YYYY-MM-DD`を、その日を含む月曜日の`YYYY-MM-DD`へ変換する。
String learningWeekKey(String day) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(day);
  if (match == null) {
    throw ArgumentError.value(day, 'day', 'YYYY-MM-DD only');
  }
  final parsed = DateTime.utc(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
  if (_formatLearningDay(parsed) != day) {
    throw ArgumentError.value(day, 'day', 'valid calendar day required');
  }
  return _formatLearningDay(
    parsed.subtract(Duration(days: parsed.weekday - DateTime.monday)),
  );
}

String _formatLearningDay(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';
