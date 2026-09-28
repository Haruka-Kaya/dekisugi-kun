import '../../services/session_store.dart';
import '../domain/learning_economy.dart';
import '../domain/learning_event.dart';
import '../domain/learning_policy.dart';
import '../domain/learning_progress.dart';
import 'local_weekly_league_catch_up.dart';

/// UI・path plannerが使う学習台帳の境界。
///
/// 既存の会話保存APIを画面へ漏らさず、学習ゲームの書き込みを必ず
/// [commit] の原子的な経路へ集約する。
abstract interface class LearningProgressStore {
  Future<CommitLearningResult> commit(LearningEventCommand event);

  Future<LearningQuestMaterializationResult> materializeQuestDefinitions({
    required LearningScope scope,
    required Iterable<LearningQuestDefinition> definitions,
  });

  Future<LearningProgressSnapshot> snapshot(LearningScope scope);

  Future<LearningRun> beginRun(LearningRun run);

  Future<LearningRun> checkpointRun(
    String runId, {
    required int activityIndex,
    int? challengeHearts,
    required DateTime updatedAt,
  });

  /// 完了eventを作らない任意ミニゲームの一時runを明示的に破棄する。
  Future<void> discardRun(String runId);

  /// 個人固定課題のheartを1つだけ、冪等に消費する。
  ///
  /// [lossId]を同じ内容で再送しても二重消費しない。正誤や回答は受け取らない。
  Future<LearningChallengeHeartSpendResult> spendChallengeHeart(
    String runId, {
    required String lossId,
    required int activityIndex,
    required String learningDay,
    required DateTime occurredAt,
  });

  /// 明示したrun-local participant slotだけで端末内協力questを開始する。
  Future<LearningLocalCoopRun> beginLocalCoopRun(
    LearningLocalCoopRunCommand command,
  );

  /// 経過した30分ごとに個人heartを1つ戻す。満タンまたは学校では呼ばない。
  Future<LearningChallengeHeartRefreshResult> refreshChallengeHearts({
    required String learningDay,
    required DateTime occurredAt,
  });

  /// 完了済みの専用回復練習eventを根拠に、個人heartを1つ戻す。
  Future<LearningChallengeHeartPracticeRecoveryResult>
  recoverChallengeHeartWithPractice({
    required String recoveryId,
    required String sourceEventId,
    required String learningDay,
    required DateTime occurredAt,
  });

  /// commit済みのmeaningful eventを端末内協力questへ1回だけ紐付ける。
  Future<LearningLocalCoopContributionResult> contributeLocalCoopRun(
    String runId, {
    required String contributionId,
    required String participantId,
    required String eventId,
    required DateTime occurredAt,
  });

  Future<List<LearningLocalCoopContribution>> localCoopContributions(
    Set<String> runIds,
  );

  /// Store内の匿名実績だけから、終了済みの端末手渡し週次tierを一度だけ確定する。
  Future<LearningLocalLeagueFinalizeResult> finalizeLocalWeeklyLeague({
    required String weekKey,
    required DateTime finalizedAt,
  });

  Future<LearningLocalLeagueCatchUpResult> catchUpLocalWeeklyLeagues({
    required String currentWeekKey,
    required DateTime finalizedAt,
    String? afterWeekKey,
  });

  Future<LearningGemSpendResult> replenishStreakFreezeWithGems({
    required String spendId,
    required String learningDay,
    required DateTime occurredAt,
  });

  Future<LearningGemSpendResult> recoverChallengeHeartsWithGems({
    required String spendId,
    required String learningDay,
    required DateTime occurredAt,
  });

  Future<LearningCosmeticPurchaseResult> purchaseCosmeticWithGems({
    required LearningScope scope,
    required String spendId,
    required String productId,
    required String learningDay,
    required DateTime occurredAt,
  });

  Future<LearningCosmeticEquipResult> equipCosmetic({
    required LearningScope scope,
    required String productId,
    required DateTime occurredAt,
  });

  /// Plus entitlement確認時に、Plus限定の見た目を所有へ付ける。
  Future<LearningCosmeticState> grantPlusCosmetics({
    required LearningScope scope,
    required DateTime occurredAt,
  });

  Future<LearningChallengePassPurchaseResult> purchaseChallengePassWithGems({
    required LearningScope scope,
    required String spendId,
    required String productId,
    required String learningDay,
    required DateTime occurredAt,
  });

  Future<LearningRun?> activeRun({
    required LearningScope scope,
    String? nodeId,
  });

  Future<void> clearScope(LearningScope scope);
}

final class SessionLearningProgressStore implements LearningProgressStore {
  const SessionLearningProgressStore(
    this._store, {
    this.rules = const LearningCommitRules(),
    this.economyPolicy = const SafeLearningEconomyPolicyV1(),
    this.economyCatalog = const SafeLearningEconomyCatalogV1(),
  });

  final SessionStore _store;
  final LearningCommitRules rules;
  final SafeLearningEconomyPolicyV1 economyPolicy;
  final SafeLearningEconomyCatalogV1 economyCatalog;

  @override
  Future<CommitLearningResult> commit(LearningEventCommand event) =>
      _store.commitLearningEvent(event, rules: rules);

  @override
  Future<LearningQuestMaterializationResult> materializeQuestDefinitions({
    required LearningScope scope,
    required Iterable<LearningQuestDefinition> definitions,
  }) => _store.materializeLearningQuestDefinitions(
    scope: scope,
    definitions: definitions,
  );

  @override
  Future<LearningProgressSnapshot> snapshot(LearningScope scope) =>
      _store.learningProgressSnapshot(scope);

  @override
  Future<LearningRun> beginRun(LearningRun run) => _store.beginLearningRun(run);

  @override
  Future<LearningRun> checkpointRun(
    String runId, {
    required int activityIndex,
    int? challengeHearts,
    required DateTime updatedAt,
  }) => _store.checkpointLearningRun(
    runId,
    activityIndex: activityIndex,
    challengeHearts: challengeHearts,
    updatedAt: updatedAt,
  );

  @override
  Future<void> discardRun(String runId) => _store.discardLearningRun(runId);

  @override
  Future<LearningChallengeHeartSpendResult> spendChallengeHeart(
    String runId, {
    required String lossId,
    required int activityIndex,
    required String learningDay,
    required DateTime occurredAt,
  }) => _store.spendLearningChallengeHeart(
    runId,
    lossId: lossId,
    activityIndex: activityIndex,
    learningDay: learningDay,
    occurredAt: occurredAt,
  );

  @override
  Future<LearningChallengeHeartRefreshResult> refreshChallengeHearts({
    required String learningDay,
    required DateTime occurredAt,
  }) => _store.refreshLearningChallengeHearts(
    learningDay: learningDay,
    occurredAt: occurredAt,
  );

  @override
  Future<LearningChallengeHeartPracticeRecoveryResult>
  recoverChallengeHeartWithPractice({
    required String recoveryId,
    required String sourceEventId,
    required String learningDay,
    required DateTime occurredAt,
  }) => _store.recoverLearningChallengeHeartWithPractice(
    recoveryId: recoveryId,
    sourceEventId: sourceEventId,
    learningDay: learningDay,
    occurredAt: occurredAt,
  );

  @override
  Future<LearningLocalCoopRun> beginLocalCoopRun(
    LearningLocalCoopRunCommand command,
  ) => _store.beginLearningLocalCoopRun(command);

  @override
  Future<LearningLocalCoopContributionResult> contributeLocalCoopRun(
    String runId, {
    required String contributionId,
    required String participantId,
    required String eventId,
    required DateTime occurredAt,
  }) => _store.contributeLearningLocalCoopRun(
    runId,
    contributionId: contributionId,
    participantId: participantId,
    eventId: eventId,
    occurredAt: occurredAt,
  );

  @override
  Future<List<LearningLocalCoopContribution>> localCoopContributions(
    Set<String> runIds,
  ) => _store.localCoopContributions(runIds);

  @override
  Future<LearningLocalLeagueFinalizeResult> finalizeLocalWeeklyLeague({
    required String weekKey,
    required DateTime finalizedAt,
  }) => _store.finalizeLearningLocalWeeklyLeague(
    weekKey: weekKey,
    finalizedAt: finalizedAt,
  );

  @override
  Future<LearningLocalLeagueCatchUpResult> catchUpLocalWeeklyLeagues({
    required String currentWeekKey,
    required DateTime finalizedAt,
    String? afterWeekKey,
  }) => _store.catchUpLearningLocalWeeklyLeagues(
    currentWeekKey: currentWeekKey,
    finalizedAt: finalizedAt,
    afterWeekKey: afterWeekKey,
  );

  @override
  Future<LearningGemSpendResult> replenishStreakFreezeWithGems({
    required String spendId,
    required String learningDay,
    required DateTime occurredAt,
  }) => _store.replenishLearningStreakFreezeWithGems(
    spendId: spendId,
    learningDay: learningDay,
    occurredAt: occurredAt,
    economyPolicy: economyPolicy,
  );

  @override
  Future<LearningGemSpendResult> recoverChallengeHeartsWithGems({
    required String spendId,
    required String learningDay,
    required DateTime occurredAt,
  }) => _store.recoverLearningChallengeHeartsWithGems(
    spendId: spendId,
    learningDay: learningDay,
    occurredAt: occurredAt,
    economyPolicy: economyPolicy,
  );

  @override
  Future<LearningCosmeticPurchaseResult> purchaseCosmeticWithGems({
    required LearningScope scope,
    required String spendId,
    required String productId,
    required String learningDay,
    required DateTime occurredAt,
  }) => _store.purchaseLearningCosmeticWithGems(
    scope: scope,
    spendId: spendId,
    productId: productId,
    learningDay: learningDay,
    occurredAt: occurredAt,
    catalog: economyCatalog,
  );

  @override
  Future<LearningCosmeticEquipResult> equipCosmetic({
    required LearningScope scope,
    required String productId,
    required DateTime occurredAt,
  }) => _store.equipLearningCosmetic(
    scope: scope,
    productId: productId,
    occurredAt: occurredAt,
    catalog: economyCatalog,
  );

  @override
  Future<LearningCosmeticState> grantPlusCosmetics({
    required LearningScope scope,
    required DateTime occurredAt,
  }) => _store.grantLearningPlusCosmetics(
    scope: scope,
    occurredAt: occurredAt,
    catalog: economyCatalog,
  );

  @override
  Future<LearningChallengePassPurchaseResult> purchaseChallengePassWithGems({
    required LearningScope scope,
    required String spendId,
    required String productId,
    required String learningDay,
    required DateTime occurredAt,
  }) => _store.purchaseLearningChallengePassWithGems(
    scope: scope,
    spendId: spendId,
    productId: productId,
    learningDay: learningDay,
    occurredAt: occurredAt,
    catalog: economyCatalog,
  );

  @override
  Future<LearningRun?> activeRun({
    required LearningScope scope,
    String? nodeId,
  }) => _store.activeLearningRun(scope: scope, nodeId: nodeId);

  @override
  Future<void> clearScope(LearningScope scope) =>
      _store.clearLearningScope(scope);
}
