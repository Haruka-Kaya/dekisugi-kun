import 'learning_event.dart';

/// 報酬計算の差し替え口。
///
/// 実装は端末DB transactionの中から呼ばれる。I/Oを行わず、同じ入力には
/// 同じ値を返すこと。
abstract interface class LearningRewardPolicy {
  int xpForEvent({
    required LearningEventCommand event,
    required bool meaningfulProgress,
    required int xpEarnedOnDay,
  });
}

/// 初期リリースの安全側ルール。
///
/// - node初回clear、または期限到来後のspaced retrievalだけ
/// - 速さ・連続正解・誤答数では増減しない
/// - 1日上限を超えてランキング用の反復作業を作れない
///
/// 数値は効果量の主張ではなく、差し替え可能なlaunch設定。
final class SafeLearningRewardPolicyV1 implements LearningRewardPolicy {
  const SafeLearningRewardPolicyV1({
    this.xpPerDistinctNode = 10,
    this.dailyXpCap = 30,
  }) : assert(xpPerDistinctNode > 0),
       assert(dailyXpCap >= xpPerDistinctNode);

  final int xpPerDistinctNode;
  final int dailyXpCap;

  @override
  int xpForEvent({
    required LearningEventCommand event,
    required bool meaningfulProgress,
    required int xpEarnedOnDay,
  }) {
    if (!event.allowsRewards || !meaningfulProgress) return 0;
    final left = dailyXpCap - xpEarnedOnDay;
    if (left <= 0) return 0;
    return left < xpPerDistinctNode ? left : xpPerDistinctNode;
  }
}

/// 連続記録の保護と学習heart回復に使うlaunch設定。
///
/// 金額は学習効果の主張ではなくversionedな設定。固定cosmeticと任意Timed券は
/// `SafeLearningEconomyCatalogV1`で別管理し、保存層は汎用spend APIを公開しない。
final class SafeLearningEconomyPolicyV1 {
  const SafeLearningEconomyPolicyV1({
    this.streakFreezeRefillGemCost = 3,
    this.challengeHeartRecoveryGemCost = 2,
    this.maxPaidFreezeRefillsPerWeek = 1,
  }) : assert(streakFreezeRefillGemCost > 0),
       assert(challengeHeartRecoveryGemCost > 0),
       assert(maxPaidFreezeRefillsPerWeek > 0);

  final int streakFreezeRefillGemCost;
  final int challengeHeartRecoveryGemCost;
  final int maxPaidFreezeRefillsPerWeek;

  /// release buildでも不正な差し替え設定を残高計算へ入れない。
  void validate() {
    if (streakFreezeRefillGemCost <= 0 ||
        challengeHeartRecoveryGemCost <= 0 ||
        maxPaidFreezeRefillsPerWeek <= 0) {
      throw ArgumentError('learning economy policy requires positive values');
    }
  }
}

abstract interface class LearningSpacingPolicy {
  int gapDaysFor({
    required LearningEventCommand event,
    required int successfulRetrievals,
  });
}

/// 「不決着は今日、完了直後は翌日、異日の転移成功で間隔を伸ばす」。
///
/// 1/3/7/14/30日は既存の端末内復習とそろえるためのlaunch設定で、最適値の
/// 主張ではない。ポリシーをversionedにして後から測定結果へ差し替える。
final class SafeLearningSpacingPolicyV1 implements LearningSpacingPolicy {
  const SafeLearningSpacingPolicyV1();

  static const _spacedGaps = [1, 3, 7, 14, 30];

  @override
  int gapDaysFor({
    required LearningEventCommand event,
    required int successfulRetrievals,
  }) {
    if (event.outcome == LearningAttemptOutcome.retryNeeded) return 0;
    if (event.evidence != LearningEvidenceLevel.spacedTransfer) return 1;
    final index = successfulRetrievals.clamp(0, _spacedGaps.length - 1);
    return _spacedGaps[index];
  }
}

/// 日・週・月の実体化済みクエスト。
///
/// `questInstanceId`には期間を含める（例 `daily:2026-08-10:retrieval`）。
/// 友達・学校ランキングの識別子はここへ入れない。
final class LearningQuestDefinition {
  factory LearningQuestDefinition.daily({
    required String learningDay,
    required String questKey,
    required String definitionVersion,
    required int target,
    required int rewardGems,
    Set<LearningOrigin> allowedOrigins = const {},
    Set<LearningActivityKind> allowedActivityKinds = const {},
    LearningEvidenceLevel minimumEvidence = LearningEvidenceLevel.selfCompared,
  }) {
    _requireLearningDay(learningDay);
    _requirePolicyId(questKey, 'questKey');
    return LearningQuestDefinition(
      questInstanceId: 'daily:$learningDay:$questKey',
      definitionVersion: definitionVersion,
      target: target,
      rewardGems: rewardGems,
      allowedOrigins: allowedOrigins,
      allowedActivityKinds: allowedActivityKinds,
      minimumEvidence: minimumEvidence,
    );
  }

  factory LearningQuestDefinition.monthly({
    required String learningMonth,
    required String questKey,
    required String definitionVersion,
    required int target,
    required int rewardGems,
    Set<LearningOrigin> allowedOrigins = const {},
    Set<LearningActivityKind> allowedActivityKinds = const {},
    LearningEvidenceLevel minimumEvidence = LearningEvidenceLevel.selfCompared,
  }) {
    _requireLearningMonth(learningMonth);
    _requirePolicyId(questKey, 'questKey');
    return LearningQuestDefinition(
      questInstanceId: 'monthly:$learningMonth:$questKey',
      definitionVersion: definitionVersion,
      target: target,
      rewardGems: rewardGems,
      allowedOrigins: allowedOrigins,
      allowedActivityKinds: allowedActivityKinds,
      minimumEvidence: minimumEvidence,
    );
  }

  LearningQuestDefinition({
    required this.questInstanceId,
    required this.definitionVersion,
    required this.target,
    required this.rewardGems,
    this.allowedOrigins = const {},
    this.allowedActivityKinds = const {},
    this.minimumEvidence = LearningEvidenceLevel.selfCompared,
  }) {
    _requirePolicyId(questInstanceId, 'questInstanceId');
    _requirePolicyId(definitionVersion, 'definitionVersion');
    if (target < 1 || target > 100) {
      throw ArgumentError.value(target, 'target');
    }
    if (rewardGems < 0 || rewardGems > 100) {
      throw ArgumentError.value(rewardGems, 'rewardGems');
    }
  }

  final String questInstanceId;
  final String definitionVersion;
  final int target;
  final int rewardGems;
  final Set<LearningOrigin> allowedOrigins;
  final Set<LearningActivityKind> allowedActivityKinds;
  final LearningEvidenceLevel minimumEvidence;

  bool matches(LearningEventCommand event) =>
      event.scope == LearningScope.personal &&
      event.origin != LearningOrigin.legacyImport &&
      event.qualifiesForLearningDay &&
      includesLearningDay(event.learningDay) &&
      event.evidence.rank >= minimumEvidence.rank &&
      (allowedOrigins.isEmpty || allowedOrigins.contains(event.origin)) &&
      (allowedActivityKinds.isEmpty ||
          allowedActivityKinds.contains(event.activityKind));

  /// instance IDに期間が含まれるquestは、その期間のeventだけを受け取る。
  bool includesLearningDay(String learningDay) {
    final split = questInstanceId.split(':');
    if (split.length < 2) return true;
    if (split.first == 'daily') return split[1] == learningDay;
    if (split.first == 'monthly') {
      return learningDay.startsWith('${split[1]}-');
    }
    return true;
  }
}

final class LearningCommitRules {
  const LearningCommitRules({
    this.rewardPolicy = const SafeLearningRewardPolicyV1(),
    this.spacingPolicy = const SafeLearningSpacingPolicyV1(),
    this.quests = const [],
  });

  final LearningRewardPolicy rewardPolicy;
  final LearningSpacingPolicy spacingPolicy;
  final List<LearningQuestDefinition> quests;
}

final RegExp _policyId = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$');

void _requirePolicyId(String value, String field) {
  if (!_policyId.hasMatch(value)) {
    throw ArgumentError.value(value, field, 'opaque ASCII identifier required');
  }
}

void _requireLearningDay(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) {
    throw ArgumentError.value(value, 'learningDay', 'YYYY-MM-DD required');
  }
  final parsed = DateTime.utc(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
  final normalized =
      '${parsed.year.toString().padLeft(4, '0')}-'
      '${parsed.month.toString().padLeft(2, '0')}-'
      '${parsed.day.toString().padLeft(2, '0')}';
  if (normalized != value) {
    throw ArgumentError.value(value, 'learningDay', 'valid date required');
  }
}

void _requireLearningMonth(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value);
  final month = match == null ? null : int.tryParse(match.group(2)!);
  if (month == null || month < 1 || month > 12) {
    throw ArgumentError.value(value, 'learningMonth', 'YYYY-MM required');
  }
}
