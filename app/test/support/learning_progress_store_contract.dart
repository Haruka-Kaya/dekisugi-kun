import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/learning/domain/learning_economy.dart';
import 'package:dekisugi/learning/domain/learning_policy.dart';
import 'package:dekisugi/learning/domain/learning_progress.dart';
import 'package:dekisugi/learning/services/learning_progress_store.dart';
import 'package:dekisugi/learning/services/learning_quest_plan_v2.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

typedef LearningSessionStoreFactory = Future<SessionStore> Function();

void runLearningProgressStoreContract(
  String name,
  LearningSessionStoreFactory create,
) {
  group('$name 学習台帳契約', () {
    late SessionStore session;
    late LearningProgressStore learning;

    setUp(() async {
      session = await create();
      learning = SessionLearningProgressStore(
        session,
        rules: LearningCommitRules(
          quests: [
            LearningQuestDefinition(
              questInstanceId: 'daily:2026-08-10:two-nodes',
              definitionVersion: 'quest.v1',
              target: 2,
              rewardGems: 3,
            ),
          ],
        ),
      );
    });

    tearDown(() => session.close());

    test('personal eventをnode/skill/day/rewardへ原子的に投影する', () async {
      final result = await learning.commit(_event('event.1'));

      expect(result.inserted, isTrue);
      expect(result.node.state, LearningNodeState.cleared);
      expect(result.node.attemptCount, 1);
      expect(result.skills.single.lastOutcome, LearningSkillOutcome.completed);
      expect(result.skills.single.nextDueDay, '2026-08-11');
      expect(result.rewards.single.type, LearningRewardType.xp);
      expect(result.rewards.single.amount, 10);

      final snapshot = await learning.snapshot(LearningScope.personal);
      expect(snapshot.events, hasLength(1));
      expect(snapshot.nodes, hasLength(1));
      expect(snapshot.skills, hasLength(1));
      expect(snapshot.days.single.qualifyingCount, 1);
      expect(snapshot.wallet.xp, 10);
      expect(snapshot.wallet.gems, 0);
      expect(snapshot.quests.single.progress, 1);
    });

    test('同じeventを100回再送しても一度しか加算しない', () async {
      final command = _event('event.idempotent');
      CommitLearningResult? last;
      for (var i = 0; i < 100; i++) {
        last = await learning.commit(command);
      }

      expect(last?.inserted, isFalse);
      final snapshot = await learning.snapshot(LearningScope.personal);
      expect(snapshot.events, hasLength(1));
      expect(snapshot.nodes.single.attemptCount, 1);
      expect(snapshot.days.single.qualifyingCount, 1);
      expect(snapshot.wallet.xp, 10);
      expect(snapshot.quests.single.progress, 1);
    });

    test('同じevent IDを別内容へ使い回すと拒否する', () async {
      await learning.commit(_event('event.reused'));

      await expectLater(
        learning.commit(_event('event.reused', nodeId: 'node.other')),
        throwsStateError,
      );
      final snapshot = await learning.snapshot(LearningScope.personal);
      expect(snapshot.events, hasLength(1));
      expect(snapshot.nodes.single.nodeId, 'node.fall');
    });

    test('schoolLocalはpersonalと分離し報酬とquestを一切作らない', () async {
      final result = await learning.commit(
        _event(
          'event.school',
          scope: LearningScope.schoolLocal,
          nodeId: 'node.school.fall',
        ),
      );

      expect(result.rewards, isEmpty);
      expect(result.quests, isEmpty);
      final personal = await learning.snapshot(LearningScope.personal);
      final school = await learning.snapshot(LearningScope.schoolLocal);
      expect(personal.events, isEmpty);
      expect(personal.nodes, isEmpty);
      expect(personal.wallet.xp, 0);
      expect(personal.wallet.gems, 0);
      expect(personal.quests, isEmpty);
      expect(school.events, hasLength(1));
      expect(school.nodes, hasLength(1));
      expect(school.rewards, isEmpty);
      expect(school.quests, isEmpty);
    });

    test('V2 definitionをprogress 0・報酬0で冪等materializeする', () async {
      final plan = _v2Plan();

      final first = await learning.materializeQuestDefinitions(
        scope: LearningScope.personal,
        definitions: plan.definitionsToMaterialize,
      );

      expect(first.changed, isTrue);
      expect(first.insertedCount, 2);
      expect(
        first.quests.map((quest) => quest.questInstanceId),
        plan.definitionsToMaterialize.map(
          (definition) => definition.questInstanceId,
        ),
      );
      expect(first.quests.map((quest) => quest.progress), everyElement(0));
      expect(
        first.quests.map((quest) => quest.completedAt),
        everyElement(isNull),
      );
      expect(
        first.quests.map((quest) => quest.rewardedAt),
        everyElement(isNull),
      );

      var snapshot = await learning.snapshot(LearningScope.personal);
      expect(snapshot.quests, hasLength(2));
      expect(snapshot.quests.map((quest) => quest.progress), everyElement(0));
      expect(snapshot.events, isEmpty);
      expect(snapshot.nodes, isEmpty);
      expect(snapshot.days, isEmpty);
      expect(snapshot.rewards, isEmpty);
      expect(snapshot.wallet.xp, 0);
      expect(snapshot.wallet.gems, 0);

      final replay = await learning.materializeQuestDefinitions(
        scope: LearningScope.personal,
        definitions: plan.definitionsToMaterialize,
      );
      expect(replay.changed, isFalse);
      expect(replay.insertedCount, 0);
      expect(replay.quests.map((quest) => quest.progress), everyElement(0));
      snapshot = await learning.snapshot(LearningScope.personal);
      expect(snapshot.quests, hasLength(2));
      expect(snapshot.rewards, isEmpty);
    });

    test('V2同一IDのtarget・version・filter・reward改変を全て拒否する', () async {
      final plan = _v2Plan();
      await learning.materializeQuestDefinitions(
        scope: LearningScope.personal,
        definitions: plan.definitionsToMaterialize,
      );
      final daily = plan.dailyDefinition;
      final changed = <LearningQuestDefinition>[
        _copyQuest(daily, target: daily.target + 1),
        _copyQuest(daily, definitionVersion: '${daily.definitionVersion}.x'),
        _copyQuest(daily, allowedOrigins: const {LearningOrigin.practice}),
        _copyQuest(
          daily,
          allowedActivityKinds: const {LearningActivityKind.read},
        ),
        _copyQuest(
          daily,
          minimumEvidence: LearningEvidenceLevel.structuredCorrection,
        ),
        _copyQuest(daily, rewardGems: daily.rewardGems + 1),
      ];

      for (final altered in changed) {
        await expectLater(
          learning.materializeQuestDefinitions(
            scope: LearningScope.personal,
            definitions: [altered],
          ),
          throwsStateError,
          reason: altered.questInstanceId,
        );
      }
      final alteredCommit = SessionLearningProgressStore(
        session,
        rules: LearningCommitRules(quests: [changed[2]]),
      );
      await expectLater(
        Future.sync(
          () => alteredCommit.commit(_event('event.v2.altered-filter')),
        ),
        throwsStateError,
      );

      final otherDaily = _v2Plan(
        variant: LearningDailyQuestVariant.notation,
      ).dailyDefinition;
      final nextDayDaily = _v2Plan(
        day: 11,
        variant: LearningDailyQuestVariant.diagram,
      ).dailyDefinition;
      await expectLater(
        learning.materializeQuestDefinitions(
          scope: LearningScope.personal,
          definitions: [nextDayDaily, otherDaily],
        ),
        throwsStateError,
      );
      final snapshot = await learning.snapshot(LearningScope.personal);
      expect(snapshot.quests, hasLength(2));
      expect(
        snapshot.quests.any(
          (quest) => quest.questInstanceId == nextDayDaily.questInstanceId,
        ),
        isFalse,
        reason: '後続definitionの衝突でbatch全体をrollbackする',
      );
      expect(snapshot.quests.map((quest) => quest.progress), everyElement(0));
      expect(snapshot.events, isEmpty);
      expect(snapshot.rewards, isEmpty);
    });

    test('school materializeは空listだけをno-opとし個人Quest・報酬を作らない', () async {
      final school = const LearningQuestPlannerV2().build(
        now: DateTime(2026, 8, 10, 12),
        audience: LearningQuestAudience.schoolLocal,
      );
      final noOp = await learning.materializeQuestDefinitions(
        scope: LearningScope.schoolLocal,
        definitions: school.definitionsToMaterialize,
      );
      expect(noOp.changed, isFalse);
      expect(noOp.quests, isEmpty);

      await expectLater(
        learning.materializeQuestDefinitions(
          scope: LearningScope.schoolLocal,
          definitions: _v2Plan().definitionsToMaterialize,
        ),
        throwsArgumentError,
      );
      final personal = await learning.snapshot(LearningScope.personal);
      final schoolSnapshot = await learning.snapshot(LearningScope.schoolLocal);
      expect(personal.quests, isEmpty);
      expect(personal.rewards, isEmpty);
      expect(schoolSnapshot.quests, isEmpty);
      expect(schoolSnapshot.rewards, isEmpty);
    });

    test('policyがevent insert後にthrowしても全projectionをrollbackする', () async {
      final failing = SessionLearningProgressStore(
        session,
        rules: const LearningCommitRules(rewardPolicy: _ThrowingRewardPolicy()),
      );

      await expectLater(
        failing.commit(_event('event.rollback')),
        throwsA(isA<StateError>()),
      );
      final snapshot = await learning.snapshot(LearningScope.personal);
      expect(snapshot.events, isEmpty);
      expect(snapshot.nodes, isEmpty);
      expect(snapshot.skills, isEmpty);
      expect(snapshot.days, isEmpty);
      expect(snapshot.rewards, isEmpty);
    });

    test('同じnodeの同日反復と4件目にはXPを付けない', () async {
      await learning.commit(_event('event.cap.1', nodeId: 'node.1'));
      await learning.commit(_event('event.cap.repeat', nodeId: 'node.1'));
      await learning.commit(_event('event.cap.2', nodeId: 'node.2'));
      await learning.commit(_event('event.cap.3', nodeId: 'node.3'));
      await learning.commit(_event('event.cap.4', nodeId: 'node.4'));

      final snapshot = await learning.snapshot(LearningScope.personal);
      expect(snapshot.events, hasLength(5));
      expect(snapshot.wallet.xp, 30);
      expect(
        snapshot.rewards.where(
          (reward) => reward.type == LearningRewardType.xp,
        ),
        hasLength(3),
      );
      expect(
        snapshot.quests.single.progress,
        2,
        reason: '同じnodeの反復はquest水増しにしない',
      );
      expect(snapshot.wallet.gems, 3);
    });

    test('clear済みnodeの翌日反復ではXPとquestを進めない', () async {
      await learning.commit(
        _event('event.repeat.base', nodeId: 'node.repeat', day: '2026-08-10'),
      );

      final repeated = await learning.commit(
        _event(
          'event.repeat.next-day',
          nodeId: 'node.repeat',
          day: '2026-08-11',
        ),
      );

      expect(repeated.node.state, LearningNodeState.cleared);
      expect(repeated.rewards, isEmpty);
      expect(repeated.quests, isEmpty);
      final snapshot = await learning.snapshot(LearningScope.personal);
      expect(snapshot.wallet.xp, 10);
      expect(snapshot.wallet.gems, 0);
      expect(snapshot.quests.single.progress, 1);
    });

    test('dailyとmonthly questは同じmeaningful eventだけを期間内で冪等投影する', () async {
      final periodLearning = SessionLearningProgressStore(
        session,
        rules: LearningCommitRules(
          quests: [
            LearningQuestDefinition.daily(
              learningDay: '2026-08-10',
              questKey: 'first',
              definitionVersion: 'quest.period.v1',
              target: 1,
              rewardGems: 2,
            ),
            LearningQuestDefinition.monthly(
              learningMonth: '2026-08',
              questKey: 'two',
              definitionVersion: 'quest.period.v1',
              target: 2,
              rewardGems: 4,
            ),
          ],
        ),
      );
      final first = _event(
        'event.period.first',
        nodeId: 'node.period.first',
        day: '2026-08-10',
      );
      await periodLearning.commit(first);
      await periodLearning.commit(first);
      await periodLearning.commit(
        _event(
          'event.period.repeat',
          nodeId: 'node.period.first',
          day: '2026-08-11',
        ),
      );
      await periodLearning.commit(
        _event(
          'event.period.second',
          nodeId: 'node.period.second',
          day: '2026-08-11',
        ),
      );
      await periodLearning.commit(
        _event(
          'event.period.next-month',
          nodeId: 'node.period.next-month',
          day: '2026-09-01',
        ),
      );

      final snapshot = await periodLearning.snapshot(LearningScope.personal);
      final byId = {
        for (final quest in snapshot.quests) quest.questInstanceId: quest,
      };
      expect(byId['daily:2026-08-10:first']?.progress, 1);
      expect(byId['monthly:2026-08:two']?.progress, 2);
      expect(snapshot.wallet.gems, 6);
      expect(
        snapshot.rewards.where((item) => item.type == LearningRewardType.gems),
        hasLength(2),
      );
    });

    test('ローカル協力questは明示した2slotのmeaningful eventだけで完了する', () async {
      expect(await learning.localCoopContributions(const {}), isEmpty);
      expect(
        await learning.localCoopContributions(const {'coop.unknown'}),
        isEmpty,
      );
      await expectLater(
        learning.localCoopContributions(const {'invalid run id'}),
        throwsArgumentError,
      );

      final run = await learning.beginLocalCoopRun(
        LearningLocalCoopRunCommand(
          runId: 'coop.shared-device.1',
          participantIds: const {'slot.a', 'slot.b'},
          target: 3,
          rewardGems: 5,
          startDay: '2026-08-10',
          endDay: '2026-08-31',
          definitionVersion: 'coop.v1',
          startedAt: DateTime(2026, 8, 10, 9),
        ),
      );
      expect(run.participantIds, {'slot.a', 'slot.b'});
      expect(run.progress, 0);

      await learning.commit(_event('event.coop.a', nodeId: 'node.coop.a'));
      final first = await learning.contributeLocalCoopRun(
        run.runId,
        contributionId: 'contribution.coop.a',
        participantId: 'slot.a',
        eventId: 'event.coop.a',
        occurredAt: DateTime(2026, 8, 10, 12, 1),
      );
      expect(first.applied, isTrue);
      expect(first.run.progress, 1);
      expect(first.run.completed, isFalse);
      final replay = await learning.contributeLocalCoopRun(
        run.runId,
        contributionId: 'contribution.coop.a',
        participantId: 'slot.a',
        eventId: 'event.coop.a',
        occurredAt: DateTime(2026, 8, 10, 12, 1),
      );
      expect(replay.applied, isFalse);
      expect(replay.run.progress, 1);

      await learning.commit(
        _event(
          'event.coop.not-meaningful',
          nodeId: 'node.coop.a',
          day: '2026-08-11',
        ),
      );
      await expectLater(
        learning.contributeLocalCoopRun(
          run.runId,
          contributionId: 'contribution.coop.invalid',
          participantId: 'slot.b',
          eventId: 'event.coop.not-meaningful',
          occurredAt: DateTime(2026, 8, 11, 12, 1),
        ),
        throwsStateError,
      );

      await learning.commit(
        _event(
          'event.coop.a-second',
          nodeId: 'node.coop.a-second',
          day: '2026-08-11',
        ),
      );
      final sameParticipant = await learning.contributeLocalCoopRun(
        run.runId,
        contributionId: 'contribution.coop.a-second',
        participantId: 'slot.a',
        eventId: 'event.coop.a-second',
        occurredAt: DateTime(2026, 8, 11, 12, 2),
      );
      expect(sameParticipant.run.progress, 2);
      expect(
        sameParticipant.run.completed,
        isFalse,
        reason: 'target到達だけで実在しない2人目を寄与済みにしない',
      );

      await learning.commit(
        _event('event.coop.b', nodeId: 'node.coop.b', day: '2026-08-12'),
      );
      final completed = await learning.contributeLocalCoopRun(
        run.runId,
        contributionId: 'contribution.coop.b',
        participantId: 'slot.b',
        eventId: 'event.coop.b',
        occurredAt: DateTime(2026, 8, 12, 12, 1),
      );
      expect(completed.run.completed, isTrue);
      expect(completed.run.contributingParticipantIds, {'slot.a', 'slot.b'});
      expect(completed.rewards.single.amount, 5);

      final contributions = await learning.localCoopContributions({
        run.runId,
        'coop.unknown',
      });
      expect(
        contributions
            .map(
              (item) => (
                item.runId,
                item.participantId,
                item.eventId,
                item.scope,
                item.learningDay,
                item.meaningfulProgress,
              ),
            )
            .toList(),
        [
          (
            run.runId,
            'slot.a',
            'event.coop.a',
            LearningScope.personal,
            '2026-08-10',
            true,
          ),
          (
            run.runId,
            'slot.a',
            'event.coop.a-second',
            LearningScope.personal,
            '2026-08-11',
            true,
          ),
          (
            run.runId,
            'slot.b',
            'event.coop.b',
            LearningScope.personal,
            '2026-08-12',
            true,
          ),
        ],
      );

      final snapshot = await learning.snapshot(LearningScope.personal);
      expect(snapshot.localCoopRuns.single.progress, 3);
      expect(
        snapshot.quests
            .singleWhere((item) => item.questInstanceId == run.questInstanceId)
            .completed,
        isTrue,
      );
      expect(snapshot.motivationFeatures.externalFriendsAvailable, isFalse);
      expect(snapshot.motivationFeatures.externalLeagueAvailable, isFalse);
    });

    test('同じmeaningful eventを複数のlocal coop runへ横流しできない', () async {
      Future<LearningLocalCoopRun> start(String runId) =>
          learning.beginLocalCoopRun(
            LearningLocalCoopRunCommand(
              runId: runId,
              participantIds: const {'slot.a', 'slot.b'},
              target: 2,
              rewardGems: 5,
              startDay: '2026-08-10',
              endDay: '2026-08-31',
              definitionVersion: 'coop.v1',
              startedAt: DateTime(2026, 8, 10, 9),
            ),
          );
      final firstRun = await start('coop.no-cross-run-reuse.1');
      final secondRun = await start('coop.no-cross-run-reuse.2');
      await learning.commit(
        _event('event.coop.shared-once', nodeId: 'node.coop.shared-once'),
      );
      await learning.contributeLocalCoopRun(
        firstRun.runId,
        contributionId: 'contribution.coop.shared-first',
        participantId: 'slot.a',
        eventId: 'event.coop.shared-once',
        occurredAt: DateTime(2026, 8, 10, 12, 1),
      );

      await expectLater(
        learning.contributeLocalCoopRun(
          secondRun.runId,
          contributionId: 'contribution.coop.shared-second',
          participantId: 'slot.a',
          eventId: 'event.coop.shared-once',
          occurredAt: DateTime(2026, 8, 10, 12, 2),
        ),
        throwsStateError,
      );
      final runs = (await learning.snapshot(
        LearningScope.personal,
      )).localCoopRuns;
      expect(
        runs.singleWhere((item) => item.runId == firstRun.runId).progress,
        1,
      );
      expect(
        runs.singleWhere((item) => item.runId == secondRun.runId).progress,
        0,
      );
    });

    test('freeze補充とheart全回復は既存契約を保ち、消費ID再送では減らない', () async {
      final richLearning = SessionLearningProgressStore(
        session,
        rules: LearningCommitRules(
          quests: [
            LearningQuestDefinition(
              questInstanceId: 'daily:2026-08-10:economy',
              definitionVersion: 'quest.economy.v1',
              target: 1,
              rewardGems: 10,
            ),
          ],
        ),
      );
      await richLearning.commit(
        _event('event.economy.base', nodeId: 'node.economy.base'),
      );
      await richLearning.commit(
        _event(
          'event.economy.freeze-1',
          nodeId: 'node.economy.freeze-1',
          day: '2026-08-12',
        ),
      );
      expect(
        (await richLearning.snapshot(
          LearningScope.personal,
        )).streakFreezeRemainingFor('2026-08-12'),
        0,
      );
      final refill = await richLearning.replenishStreakFreezeWithGems(
        spendId: 'spend.freeze.1',
        learningDay: '2026-08-12',
        occurredAt: DateTime(2026, 8, 12, 13),
      );
      expect(refill.applied, isTrue);
      expect(refill.remainingGems, 7);
      expect(refill.streakFreezeRemaining, 1);
      final refillReplay = await richLearning.replenishStreakFreezeWithGems(
        spendId: 'spend.freeze.1',
        learningDay: '2026-08-12',
        occurredAt: DateTime(2026, 8, 12, 13),
      );
      expect(refillReplay.applied, isFalse);
      expect(refillReplay.remainingGems, 7);
      await richLearning.commit(
        _event(
          'event.economy.freeze-2',
          nodeId: 'node.economy.freeze-2',
          day: '2026-08-14',
        ),
      );
      expect(
        (await richLearning.snapshot(LearningScope.personal)).freezes,
        hasLength(2),
      );
      await expectLater(
        richLearning.replenishStreakFreezeWithGems(
          spendId: 'spend.freeze.weekly-limit',
          learningDay: '2026-08-14',
          occurredAt: DateTime(2026, 8, 14, 13),
        ),
        throwsStateError,
      );

      await richLearning.beginRun(
        LearningRun(
          runId: 'run.economy.hearts',
          scope: LearningScope.personal,
          nodeId: 'node.legendary.economy',
          activityIndex: 0,
          challengeHearts: 5,
          contentVersion: 'catalog.v5',
          updatedAt: DateTime(2026, 8, 14, 14),
        ),
      );
      await richLearning.spendChallengeHeart(
        'run.economy.hearts',
        lossId: 'loss.economy.1',
        activityIndex: 1,
        learningDay: '2026-08-14',
        occurredAt: DateTime(2026, 8, 14, 14, 1),
      );
      final recovery = await richLearning.recoverChallengeHeartsWithGems(
        spendId: 'spend.hearts.1',
        learningDay: '2026-08-14',
        occurredAt: DateTime(2026, 8, 14, 14, 2),
      );
      expect(recovery.challengeHearts.current, 5);
      expect(recovery.remainingGems, 5);
      final recoveryReplay = await richLearning.recoverChallengeHeartsWithGems(
        spendId: 'spend.hearts.1',
        learningDay: '2026-08-14',
        occurredAt: DateTime(2026, 8, 14, 14, 2),
      );
      expect(recoveryReplay.applied, isFalse);
      expect(recoveryReplay.remainingGems, 5);

      final snapshot = await richLearning.snapshot(LearningScope.personal);
      expect(snapshot.gemSpends, hasLength(2));
      expect(snapshot.wallet.gems, 5);
      expect(snapshot.nodes, isNotEmpty, reason: '通常Path進捗は結晶残高でロックしない');
    });

    test('固定cosmeticは購入を冪等記録し所有済みだけを装備する', () async {
      final richLearning = SessionLearningProgressStore(
        session,
        rules: LearningCommitRules(
          quests: [
            LearningQuestDefinition.daily(
              learningDay: '2026-08-10',
              questKey: 'cosmetic-economy',
              definitionVersion: 'economy.cosmetic.test.v1',
              target: 1,
              rewardGems: 12,
            ),
          ],
        ),
      );
      await richLearning.commit(
        _event('event.cosmetic.reward', nodeId: 'node.cosmetic.reward'),
      );
      final before = await richLearning.snapshot(LearningScope.personal);
      expect(
        before.cosmetics?.equippedPathMascotId,
        SafeLearningEconomyCatalogV1.standardMascotId,
      );

      final at = DateTime(2026, 8, 10, 14);
      final bought = await richLearning.purchaseCosmeticWithGems(
        scope: LearningScope.personal,
        spendId: 'spend.cosmetic.orbit',
        productId: SafeLearningEconomyCatalogV1.orbitMascotId,
        learningDay: '2026-08-10',
        occurredAt: at,
      );
      expect(bought.applied, isTrue);
      expect(bought.remainingGems, 8);
      expect(
        bought.cosmetics.equippedPathMascotId,
        SafeLearningEconomyCatalogV1.orbitMascotId,
      );
      final replay = await richLearning.purchaseCosmeticWithGems(
        scope: LearningScope.personal,
        spendId: 'spend.cosmetic.orbit',
        productId: SafeLearningEconomyCatalogV1.orbitMascotId,
        learningDay: '2026-08-10',
        occurredAt: at,
      );
      expect(replay.applied, isFalse);
      expect(replay.remainingGems, 8);
      await expectLater(
        richLearning.purchaseCosmeticWithGems(
          scope: LearningScope.personal,
          spendId: 'spend.cosmetic.orbit',
          productId: SafeLearningEconomyCatalogV1.novaMascotId,
          learningDay: '2026-08-10',
          occurredAt: at,
        ),
        throwsStateError,
      );

      final standard = await richLearning.equipCosmetic(
        scope: LearningScope.personal,
        productId: SafeLearningEconomyCatalogV1.standardMascotId,
        occurredAt: at.add(const Duration(minutes: 1)),
      );
      expect(standard.changed, isTrue);
      expect(
        standard.cosmetics.equippedPathMascotId,
        SafeLearningEconomyCatalogV1.standardMascotId,
      );
      await expectLater(
        richLearning.equipCosmetic(
          scope: LearningScope.personal,
          productId: SafeLearningEconomyCatalogV1.novaMascotId,
          occurredAt: at.add(const Duration(minutes: 2)),
        ),
        throwsStateError,
      );
      await expectLater(
        richLearning.purchaseCosmeticWithGems(
          scope: LearningScope.personal,
          spendId: 'spend.cosmetic.orbit.duplicate',
          productId: SafeLearningEconomyCatalogV1.orbitMascotId,
          learningDay: '2026-08-10',
          occurredAt: at.add(const Duration(minutes: 3)),
        ),
        throwsStateError,
      );
      final snapshot = await richLearning.snapshot(LearningScope.personal);
      expect(snapshot.wallet.gems, 8);
      expect(snapshot.gemSpends, hasLength(1));
      expect(
        snapshot.gemSpends.single.referenceId,
        SafeLearningEconomyCatalogV1.orbitMascotId,
      );
    });

    test('Timed当日券は同じ学習日に一度だけ消費し翌日は別券にする', () async {
      final richLearning = SessionLearningProgressStore(
        session,
        rules: LearningCommitRules(
          quests: [
            LearningQuestDefinition.daily(
              learningDay: '2026-08-10',
              questKey: 'timed-pass-economy',
              definitionVersion: 'economy.timed.test.v1',
              target: 1,
              rewardGems: 3,
            ),
          ],
        ),
      );
      await richLearning.commit(
        _event('event.timed.reward', nodeId: 'node.timed.reward'),
      );
      final at = DateTime(2026, 8, 10, 15);
      final bought = await richLearning.purchaseChallengePassWithGems(
        scope: LearningScope.personal,
        spendId: 'spend.timed.2026-08-10',
        productId: SafeLearningEconomyCatalogV1.timedDayPassId,
        learningDay: '2026-08-10',
        occurredAt: at,
      );
      expect(bought.applied, isTrue);
      expect(bought.remainingGems, 2);
      final replay = await richLearning.purchaseChallengePassWithGems(
        scope: LearningScope.personal,
        spendId: 'spend.timed.2026-08-10',
        productId: SafeLearningEconomyCatalogV1.timedDayPassId,
        learningDay: '2026-08-10',
        occurredAt: at,
      );
      expect(replay.applied, isFalse);
      await expectLater(
        richLearning.purchaseChallengePassWithGems(
          scope: LearningScope.personal,
          spendId: 'spend.timed.2026-08-10',
          productId: SafeLearningEconomyCatalogV1.timedDayPassId,
          learningDay: '2026-08-10',
          occurredAt: at.add(const Duration(seconds: 1)),
        ),
        throwsStateError,
      );
      final sameDay = await richLearning.purchaseChallengePassWithGems(
        scope: LearningScope.personal,
        spendId: 'spend.timed.same-day.other-request',
        productId: SafeLearningEconomyCatalogV1.timedDayPassId,
        learningDay: '2026-08-10',
        occurredAt: at.add(const Duration(minutes: 1)),
      );
      expect(sameDay.applied, isFalse);
      expect(sameDay.remainingGems, 2);
      final nextDay = await richLearning.purchaseChallengePassWithGems(
        scope: LearningScope.personal,
        spendId: 'spend.timed.2026-08-11',
        productId: SafeLearningEconomyCatalogV1.timedDayPassId,
        learningDay: '2026-08-11',
        occurredAt: DateTime(2026, 8, 11, 15),
      );
      expect(nextDay.applied, isTrue);
      final snapshot = await richLearning.snapshot(LearningScope.personal);
      expect(snapshot.wallet.gems, 1);
      expect(snapshot.gemSpends, hasLength(2));
      expect(
        snapshot.hasChallengePass(
          productId: SafeLearningEconomyCatalogV1.timedDayPassId,
          learningDay: '2026-08-10',
        ),
        isTrue,
      );
    });

    test('残高不足とschoolLocalでは商品・券を消費せず残高を非負に保つ', () async {
      await expectLater(
        learning.purchaseCosmeticWithGems(
          scope: LearningScope.personal,
          spendId: 'spend.cosmetic.no-gems',
          productId: SafeLearningEconomyCatalogV1.orbitMascotId,
          learningDay: '2026-08-10',
          occurredAt: DateTime(2026, 8, 10, 16),
        ),
        throwsStateError,
      );
      await expectLater(
        learning.purchaseChallengePassWithGems(
          scope: LearningScope.personal,
          spendId: 'spend.timed.no-gems',
          productId: SafeLearningEconomyCatalogV1.timedDayPassId,
          learningDay: '2026-08-10',
          occurredAt: DateTime(2026, 8, 10, 16, 1),
        ),
        throwsStateError,
      );
      for (final operation in <Future<Object?> Function()>[
        () => learning.purchaseCosmeticWithGems(
          scope: LearningScope.schoolLocal,
          spendId: 'spend.school.cosmetic',
          productId: SafeLearningEconomyCatalogV1.orbitMascotId,
          learningDay: '2026-08-10',
          occurredAt: DateTime(2026, 8, 10, 16, 2),
        ),
        () => learning.equipCosmetic(
          scope: LearningScope.schoolLocal,
          productId: SafeLearningEconomyCatalogV1.standardMascotId,
          occurredAt: DateTime(2026, 8, 10, 16, 3),
        ),
        () => learning.purchaseChallengePassWithGems(
          scope: LearningScope.schoolLocal,
          spendId: 'spend.school.timed',
          productId: SafeLearningEconomyCatalogV1.timedDayPassId,
          learningDay: '2026-08-10',
          occurredAt: DateTime(2026, 8, 10, 16, 4),
        ),
      ]) {
        await expectLater(operation(), throwsStateError);
      }
      final personal = await learning.snapshot(LearningScope.personal);
      final school = await learning.snapshot(LearningScope.schoolLocal);
      expect(personal.wallet.gems, 0);
      expect(personal.gemSpends, isEmpty);
      expect(school.cosmetics, isNull);
      expect(school.gemSpends, isEmpty);
    });

    test('残高不足のheart回復は台帳とstateを変更しない', () async {
      await learning.beginRun(
        LearningRun(
          runId: 'run.no-gems',
          scope: LearningScope.personal,
          nodeId: 'node.legendary.no-gems',
          activityIndex: 0,
          challengeHearts: 5,
          contentVersion: 'catalog.v5',
          updatedAt: DateTime(2026, 8, 10, 10),
        ),
      );
      await learning.spendChallengeHeart(
        'run.no-gems',
        lossId: 'loss.no-gems',
        activityIndex: 1,
        learningDay: '2026-08-10',
        occurredAt: DateTime(2026, 8, 10, 10, 1),
      );

      await expectLater(
        learning.recoverChallengeHeartsWithGems(
          spendId: 'spend.no-gems',
          learningDay: '2026-08-10',
          occurredAt: DateTime(2026, 8, 10, 10, 2),
        ),
        throwsStateError,
      );
      final snapshot = await learning.snapshot(LearningScope.personal);
      expect(snapshot.challengeHearts?.current, 4);
      expect(snapshot.gemSpends, isEmpty);
      expect(snapshot.wallet.gems, 0);
    });

    test('残数があるfreezeと満タンheartへ結晶を誤消費しない', () async {
      final richLearning = SessionLearningProgressStore(
        session,
        rules: LearningCommitRules(
          quests: [
            LearningQuestDefinition.daily(
              learningDay: '2026-08-10',
              questKey: 'no-waste',
              definitionVersion: 'quest.no-waste.v1',
              target: 1,
              rewardGems: 5,
            ),
          ],
        ),
      );
      await richLearning.commit(
        _event('event.no-waste', nodeId: 'node.no-waste'),
      );

      await expectLater(
        richLearning.replenishStreakFreezeWithGems(
          spendId: 'spend.no-waste.freeze',
          learningDay: '2026-08-10',
          occurredAt: DateTime(2026, 8, 10, 13),
        ),
        throwsStateError,
      );
      await expectLater(
        richLearning.recoverChallengeHeartsWithGems(
          spendId: 'spend.no-waste.hearts',
          learningDay: '2026-08-10',
          occurredAt: DateTime(2026, 8, 10, 13, 1),
        ),
        throwsStateError,
      );
      final snapshot = await richLearning.snapshot(LearningScope.personal);
      expect(snapshot.wallet.gems, 5);
      expect(snapshot.gemSpends, isEmpty);
      expect(snapshot.challengeHearts?.current, 5);
      expect(snapshot.streakFreezeRemainingFor('2026-08-10'), 1);
    });

    test('残高不足のfreeze補充は台帳と残数を変更しない', () async {
      await learning.commit(
        _event('event.freeze.no-gems.base', nodeId: 'node.freeze.no-gems.base'),
      );
      await learning.commit(
        _event(
          'event.freeze.no-gems.gap',
          nodeId: 'node.freeze.no-gems.gap',
          day: '2026-08-12',
        ),
      );

      await expectLater(
        learning.replenishStreakFreezeWithGems(
          spendId: 'spend.freeze.no-gems',
          learningDay: '2026-08-12',
          occurredAt: DateTime(2026, 8, 12, 13),
        ),
        throwsStateError,
      );
      final snapshot = await learning.snapshot(LearningScope.personal);
      expect(snapshot.gemSpends, isEmpty);
      expect(snapshot.wallet.gems, 0);
      expect(snapshot.streakFreezeRemainingFor('2026-08-12'), 0);
    });

    test('retryはnodeをclearせずskillを今日のpracticeへ戻す', () async {
      final result = await learning.commit(
        _event(
          'event.retry',
          outcome: LearningAttemptOutcome.retryNeeded,
          evidence: LearningEvidenceLevel.participation,
        ),
      );

      expect(result.node.state, LearningNodeState.inProgress);
      expect(
        result.skills.single.lastOutcome,
        LearningSkillOutcome.needsPractice,
      );
      expect(result.skills.single.nextDueDay, '2026-08-10');
      expect(result.rewards, isEmpty);
      expect((await learning.snapshot(LearningScope.personal)).days, isEmpty);
    });

    test('進捗skillと独立した固定needを冪等保存し回答内容はsnapshotへ出さない', () async {
      final command = _event(
        'event.need.independent',
        nodeId: 'node.unit.legendary',
        outcome: LearningAttemptOutcome.retryNeeded,
        evidence: LearningEvidenceLevel.participation,
        skillIds: const {'unit.legendary.synthetic'},
        practiceNeedCodes: const {
          'force-motion/fall': {'science.fall.foundation'},
        },
      );

      expect((await learning.commit(command)).inserted, isTrue);
      expect((await learning.commit(command)).inserted, isFalse);
      final snapshot = await learning.snapshot(LearningScope.personal);
      expect(snapshot.events, hasLength(1));
      expect(snapshot.activeNeeds, hasLength(1));
      expect(snapshot.activeNeeds.single.skillId, 'force-motion/fall');
      expect(snapshot.activeNeeds.single.needCode, 'science.fall.foundation');
      expect(snapshot.activeNeeds.single.firstObservedDay, '2026-08-10');
      expect(snapshot.activeNeeds.single.lastObservedDay, '2026-08-10');
    });

    test('有限訂正でnodeをclearしてneedを保持し、後の対応構造成功だけが解消する', () async {
      const needs = {
        'force-motion/fall': {'science.fall.foundation'},
      };
      final corrected = await learning.commit(
        _event(
          'event.need.corrected',
          nodeId: 'node.need.finite-correction',
          evidence: LearningEvidenceLevel.structuredCorrection,
          practiceNeedCodes: needs,
        ),
      );

      expect(corrected.node.state, LearningNodeState.cleared);
      expect(
        (await learning.snapshot(
          LearningScope.personal,
        )).activeNeeds.single.needCode,
        'science.fall.foundation',
      );

      await learning.commit(
        _event(
          'event.need.demonstrated',
          nodeId: 'node.need.repair',
          day: '2026-08-11',
          evidence: LearningEvidenceLevel.structuredCorrection,
          origin: LearningOrigin.practice,
          activityKind: LearningActivityKind.diagram,
          skillIds: const {'force-motion/fall'},
          resolvedPracticeNeedCodes: needs,
          repairResolution: _practiceResolution('science.fall.foundation', 0),
        ),
      );
      expect(
        (await learning.snapshot(LearningScope.personal)).activeNeeds,
        isEmpty,
      );
    });

    test('通常成功やmetadata無し成功をactive need tombstoneとして受理しない', () {
      const needs = {
        'force-motion/fall': {'science.fall.foundation'},
      };
      expect(
        () => _event(
          'event.need.no-repair-metadata',
          skillIds: const {'force-motion/fall'},
          resolvedPracticeNeedCodes: needs,
        ),
        throwsArgumentError,
      );
      expect(
        () => _event(
          'event.need.story-success',
          origin: LearningOrigin.story,
          activityKind: LearningActivityKind.story,
          skillIds: const {'force-motion/fall'},
          resolvedPracticeNeedCodes: needs,
          repairResolution: _practiceResolution('science.fall.foundation', 0),
        ),
        throwsArgumentError,
      );
    });

    test('解消後の古いretryではneedが復活せず、新しい観測だけが再開する', () async {
      const needs = {
        'force-motion/fall': {'science.fall.conditions'},
      };
      await learning.commit(
        _event(
          'event.need.observed',
          nodeId: 'node.need.observed',
          day: '2026-08-10',
          outcome: LearningAttemptOutcome.retryNeeded,
          evidence: LearningEvidenceLevel.participation,
          practiceNeedCodes: needs,
        ),
      );
      await learning.commit(
        _event(
          'event.need.resolved',
          nodeId: 'node.need.resolved',
          day: '2026-08-11',
          evidence: LearningEvidenceLevel.structuredCorrection,
          origin: LearningOrigin.practice,
          activityKind: LearningActivityKind.diagram,
          skillIds: const {'force-motion/fall'},
          resolvedPracticeNeedCodes: needs,
          repairResolution: _practiceResolution('science.fall.conditions', 1),
        ),
      );
      await learning.commit(
        _event(
          'event.need.stale-retry',
          nodeId: 'node.need.stale',
          day: '2026-08-09',
          outcome: LearningAttemptOutcome.retryNeeded,
          evidence: LearningEvidenceLevel.participation,
          practiceNeedCodes: needs,
        ),
      );
      expect(
        (await learning.snapshot(LearningScope.personal)).activeNeeds,
        isEmpty,
      );

      await learning.commit(
        _event(
          'event.need.new-retry',
          nodeId: 'node.need.new',
          day: '2026-08-12',
          outcome: LearningAttemptOutcome.retryNeeded,
          evidence: LearningEvidenceLevel.participation,
          practiceNeedCodes: needs,
        ),
      );
      expect(
        (await learning.snapshot(
          LearningScope.personal,
        )).activeNeeds.single.lastObservedDay,
        '2026-08-12',
      );
    });

    test('同学習日でもRepair後の新しい観測は復活し、同じ観測の再送は冪等', () async {
      const needs = {
        'force-motion/fall': {'science.fall.transfer'},
      };
      final firstObservation = _event(
        'need:v2:run.first:0:2026-08-10:match:stable',
        nodeId: 'optional:v1:force-motion:fall:match:need',
        day: '2026-08-10',
        occurredAt: DateTime(2026, 8, 10, 8),
        outcome: LearningAttemptOutcome.retryNeeded,
        evidence: LearningEvidenceLevel.participation,
        origin: LearningOrigin.practice,
        activityKind: LearningActivityKind.timed,
        activityId: 'practice.match.need.v1',
        skillIds: const {'force-motion/fall'},
        practiceNeedCodes: needs,
      );
      expect((await learning.commit(firstObservation)).inserted, isTrue);
      expect((await learning.commit(firstObservation)).inserted, isFalse);

      await learning.commit(
        _event(
          'event.need.same-day-resolved',
          nodeId: 'node.need.same-day-repair',
          day: '2026-08-10',
          occurredAt: DateTime(2026, 8, 10, 9),
          evidence: LearningEvidenceLevel.structuredCorrection,
          origin: LearningOrigin.practice,
          activityKind: LearningActivityKind.diagram,
          skillIds: const {'force-motion/fall'},
          resolvedPracticeNeedCodes: needs,
          repairResolution: _practiceResolution('science.fall.transfer', 2),
        ),
      );
      expect(
        (await learning.snapshot(LearningScope.personal)).activeNeeds,
        isEmpty,
      );

      final secondObservation = _event(
        'need:v2:run.second:0:2026-08-10:match:stable',
        nodeId: 'optional:v1:force-motion:fall:match:need',
        day: '2026-08-10',
        occurredAt: DateTime(2026, 8, 10, 10),
        outcome: LearningAttemptOutcome.retryNeeded,
        evidence: LearningEvidenceLevel.participation,
        origin: LearningOrigin.practice,
        activityKind: LearningActivityKind.timed,
        activityId: 'practice.match.need.v1',
        skillIds: const {'force-motion/fall'},
        practiceNeedCodes: needs,
      );
      expect((await learning.commit(secondObservation)).inserted, isTrue);
      expect((await learning.commit(secondObservation)).inserted, isFalse);

      final snapshot = await learning.snapshot(LearningScope.personal);
      expect(snapshot.events, hasLength(3));
      expect(snapshot.activeNeeds, hasLength(1));
      expect(snapshot.activeNeeds.single.skillId, 'force-motion/fall');
      expect(snapshot.activeNeeds.single.needCode, 'science.fall.transfer');
      expect(snapshot.activeNeeds.single.firstObservedDay, '2026-08-10');
      expect(snapshot.activeNeeds.single.lastObservedDay, '2026-08-10');
      expect(
        snapshot.activeNeeds.single.lastObservedAt,
        DateTime(2026, 8, 10, 10),
      );
    });

    test('午前4時を跨ぐRepair後は新学習日の観測だけを復活させ再送を冪等化する', () async {
      const needs = {
        'force-motion/fall': {'science.fall.foundation'},
      };
      await learning.commit(
        _event(
          'event:run.legendary:need:0:2026-08-09:stable',
          nodeId: 'unit-legendary:v2:force-motion',
          day: '2026-08-09',
          occurredAt: DateTime(2026, 8, 10, 3, 59),
          outcome: LearningAttemptOutcome.retryNeeded,
          evidence: LearningEvidenceLevel.participation,
          origin: LearningOrigin.challenge,
          activityKind: LearningActivityKind.transfer,
          activityId: 'path.unit-legendary.v2.retry',
          skillIds: const {'force-motion/fall'},
          practiceNeedCodes: needs,
        ),
      );
      await learning.commit(
        _event(
          'event.need.cutover-resolved',
          nodeId: 'node.need.cutover-repair',
          day: '2026-08-10',
          occurredAt: DateTime(2026, 8, 10, 4),
          evidence: LearningEvidenceLevel.structuredCorrection,
          origin: LearningOrigin.practice,
          activityKind: LearningActivityKind.diagram,
          skillIds: const {'force-motion/fall'},
          resolvedPracticeNeedCodes: needs,
          repairResolution: _practiceResolution('science.fall.foundation', 0),
        ),
      );
      expect(
        (await learning.snapshot(LearningScope.personal)).activeNeeds,
        isEmpty,
      );

      final newLearningDayObservation = _event(
        'event:run.legendary:need:1:2026-08-10:stable',
        nodeId: 'unit-legendary:v2:force-motion',
        day: '2026-08-10',
        occurredAt: DateTime(2026, 8, 10, 4, 1),
        outcome: LearningAttemptOutcome.retryNeeded,
        evidence: LearningEvidenceLevel.participation,
        origin: LearningOrigin.challenge,
        activityKind: LearningActivityKind.transfer,
        activityId: 'path.unit-legendary.v2.retry',
        skillIds: const {'force-motion/fall'},
        practiceNeedCodes: needs,
      );
      expect(
        (await learning.commit(newLearningDayObservation)).inserted,
        isTrue,
      );
      expect(
        (await learning.commit(newLearningDayObservation)).inserted,
        isFalse,
      );

      final snapshot = await learning.snapshot(LearningScope.personal);
      expect(snapshot.events, hasLength(3));
      expect(snapshot.activeNeeds, hasLength(1));
      expect(snapshot.activeNeeds.single.needCode, 'science.fall.foundation');
      expect(snapshot.activeNeeds.single.firstObservedDay, '2026-08-10');
      expect(snapshot.activeNeeds.single.lastObservedDay, '2026-08-10');
      expect(
        snapshot.activeNeeds.single.lastObservedAt,
        DateTime(2026, 8, 10, 4, 1),
      );
    });

    test('同じskillとneedでもschoolとpersonalを分離する', () async {
      const needs = {
        'force-motion/fall': {'science.fall.transfer'},
      };
      await learning.commit(
        _event(
          'event.need.personal',
          nodeId: 'node.need.personal',
          outcome: LearningAttemptOutcome.retryNeeded,
          evidence: LearningEvidenceLevel.participation,
          practiceNeedCodes: needs,
        ),
      );
      await learning.commit(
        _event(
          'event.need.school',
          scope: LearningScope.schoolLocal,
          nodeId: 'node.need.school',
          outcome: LearningAttemptOutcome.retryNeeded,
          evidence: LearningEvidenceLevel.participation,
          practiceNeedCodes: needs,
        ),
      );
      await learning.commit(
        _event(
          'event.need.personal-resolved',
          nodeId: 'node.need.personal-repair',
          day: '2026-08-11',
          evidence: LearningEvidenceLevel.structuredCorrection,
          origin: LearningOrigin.practice,
          activityKind: LearningActivityKind.diagram,
          skillIds: const {'force-motion/fall'},
          resolvedPracticeNeedCodes: needs,
          repairResolution: _practiceResolution('science.fall.transfer', 2),
        ),
      );

      expect(
        (await learning.snapshot(LearningScope.personal)).activeNeeds,
        isEmpty,
      );
      final school = await learning.snapshot(LearningScope.schoolLocal);
      expect(school.activeNeeds, hasLength(1));
      expect(school.activeNeeds.single.scope, LearningScope.schoolLocal);
    });

    test('retry後の初回non-spaced成功は成功日を記録して翌日を期限にする', () async {
      await learning.commit(
        _event(
          'event.retry-first.retry',
          outcome: LearningAttemptOutcome.retryNeeded,
          evidence: LearningEvidenceLevel.participation,
        ),
      );

      final completed = await learning.commit(
        _event(
          'event.retry-first.completed',
          nodeId: 'node.retry-first.completed',
          day: '2026-08-11',
        ),
      );

      expect(
        completed.skills.single.lastOutcome,
        LearningSkillOutcome.completed,
      );
      expect(completed.skills.single.successfulRetrievals, 0);
      expect(completed.skills.single.lastSuccessDay, '2026-08-11');
      expect(completed.skills.single.nextDueDay, '2026-08-12');
    });

    test('異日のtransferはretainedへ進み復習間隔を伸ばす', () async {
      await learning.commit(_event('event.base'));
      final result = await learning.commit(
        _event(
          'event.spaced',
          nodeId: 'node.case',
          day: '2026-08-11',
          evidence: LearningEvidenceLevel.spacedTransfer,
          activityKind: LearningActivityKind.transfer,
        ),
      );

      expect(result.skills.single.lastOutcome, LearningSkillOutcome.retained);
      expect(result.skills.single.successfulRetrievals, 1);
      expect(result.skills.single.nextDueDay, '2026-08-14');
    });

    test('既存completedへのnon-spaced再完了は初回の成功日と翌日期限を延期しない', () async {
      await learning.commit(_event('event.non-spaced.base', day: '2026-08-10'));
      final repeated = await learning.commit(
        _event(
          'event.non-spaced.repeat',
          nodeId: 'node.non-spaced.repeat',
          day: '2026-08-11',
          activityKind: LearningActivityKind.story,
        ),
      );

      expect(
        repeated.skills.single.lastOutcome,
        LearningSkillOutcome.completed,
      );
      expect(repeated.skills.single.successfulRetrievals, 0);
      expect(repeated.skills.single.lastAttemptDay, '2026-08-11');
      expect(repeated.skills.single.lastSuccessDay, '2026-08-10');
      expect(repeated.skills.single.nextDueDay, '2026-08-11');
    });

    test('同日・過去日・期限前のspacedTransferは進めず、期限到来時だけ進める', () async {
      await learning.commit(_event('event.spacing.base', day: '2026-08-10'));
      final firstRetrieval = await learning.commit(
        _event(
          'event.spacing.first',
          nodeId: 'node.spacing.first',
          day: '2026-08-11',
          evidence: LearningEvidenceLevel.spacedTransfer,
          activityKind: LearningActivityKind.transfer,
        ),
      );
      expect(firstRetrieval.skills.single.successfulRetrievals, 1);
      expect(firstRetrieval.skills.single.lastSuccessDay, '2026-08-11');
      expect(firstRetrieval.skills.single.nextDueDay, '2026-08-14');

      final sameDay = await learning.commit(
        _event(
          'event.spacing.same-day',
          nodeId: 'node.spacing.same-day',
          day: '2026-08-11',
          evidence: LearningEvidenceLevel.spacedTransfer,
          activityKind: LearningActivityKind.transfer,
        ),
      );
      expect(sameDay.skills.single.lastOutcome, LearningSkillOutcome.retained);
      expect(sameDay.skills.single.successfulRetrievals, 1);
      expect(sameDay.skills.single.lastSuccessDay, '2026-08-11');
      expect(sameDay.skills.single.nextDueDay, '2026-08-14');

      final pastDay = await learning.commit(
        _event(
          'event.spacing.past-day',
          nodeId: 'node.spacing.past-day',
          day: '2026-08-09',
          evidence: LearningEvidenceLevel.spacedTransfer,
          activityKind: LearningActivityKind.transfer,
        ),
      );
      expect(pastDay.skills.single.lastOutcome, LearningSkillOutcome.retained);
      expect(pastDay.skills.single.successfulRetrievals, 1);
      expect(pastDay.skills.single.lastAttemptDay, '2026-08-11');
      expect(pastDay.skills.single.lastSuccessDay, '2026-08-11');
      expect(pastDay.skills.single.nextDueDay, '2026-08-14');

      final early = await learning.commit(
        _event(
          'event.spacing.early',
          nodeId: 'node.legendary.early',
          day: '2026-08-12',
          evidence: LearningEvidenceLevel.spacedTransfer,
          activityKind: LearningActivityKind.transfer,
          origin: LearningOrigin.challenge,
        ),
      );
      expect(early.skills.single.lastOutcome, LearningSkillOutcome.retained);
      expect(early.skills.single.successfulRetrievals, 1);
      expect(early.skills.single.lastAttemptDay, '2026-08-12');
      expect(early.skills.single.lastSuccessDay, '2026-08-11');
      expect(early.skills.single.nextDueDay, '2026-08-14');
      expect(early.rewards, isEmpty);
      expect(early.quests, isEmpty);

      final due = await learning.commit(
        _event(
          'event.spacing.due',
          nodeId: 'node.legendary.due',
          day: '2026-08-14',
          evidence: LearningEvidenceLevel.spacedTransfer,
          activityKind: LearningActivityKind.transfer,
          origin: LearningOrigin.challenge,
        ),
      );
      expect(due.skills.single.lastOutcome, LearningSkillOutcome.retained);
      expect(due.skills.single.successfulRetrievals, 2);
      expect(due.skills.single.lastSuccessDay, '2026-08-14');
      expect(due.skills.single.nextDueDay, '2026-08-21');
      expect(due.rewards.single.type, LearningRewardType.xp);
    });

    test('retained後のnon-spaced再完了は保持証拠と復習期限を後退・延期しない', () async {
      await learning.commit(_event('event.retain.base', day: '2026-08-10'));
      await learning.commit(
        _event(
          'event.retain.spaced',
          nodeId: 'node.retain.spaced',
          day: '2026-08-11',
          evidence: LearningEvidenceLevel.spacedTransfer,
          activityKind: LearningActivityKind.transfer,
        ),
      );

      final lessonAgain = await learning.commit(
        _event(
          'event.retain.lesson-again',
          nodeId: 'node.retain.lesson',
          day: '2026-08-12',
          evidence: LearningEvidenceLevel.selfCompared,
          activityKind: LearningActivityKind.read,
        ),
      );
      expect(
        lessonAgain.skills.single.lastOutcome,
        LearningSkillOutcome.retained,
      );
      expect(lessonAgain.skills.single.successfulRetrievals, 1);
      expect(lessonAgain.skills.single.lastAttemptDay, '2026-08-12');
      expect(lessonAgain.skills.single.lastSuccessDay, '2026-08-11');
      expect(lessonAgain.skills.single.nextDueDay, '2026-08-14');

      final afterDuePractice = await learning.commit(
        _event(
          'event.retain.after-due',
          nodeId: 'node.retain.practice',
          day: '2026-08-15',
          evidence: LearningEvidenceLevel.structuredCorrection,
          activityKind: LearningActivityKind.diagram,
        ),
      );
      expect(
        afterDuePractice.skills.single.lastOutcome,
        LearningSkillOutcome.retained,
      );
      expect(afterDuePractice.skills.single.successfulRetrievals, 1);
      expect(afterDuePractice.skills.single.lastAttemptDay, '2026-08-15');
      expect(afterDuePractice.skills.single.lastSuccessDay, '2026-08-11');
      expect(afterDuePractice.skills.single.nextDueDay, '2026-08-14');
    });

    test('新しい成功後に届いた過去日のretryは保持状態と期限を巻き戻さない', () async {
      await learning.commit(_event('event.order.base', day: '2026-08-10'));
      await learning.commit(
        _event(
          'event.order.spaced',
          nodeId: 'node.order.spaced',
          day: '2026-08-11',
          evidence: LearningEvidenceLevel.spacedTransfer,
          activityKind: LearningActivityKind.transfer,
        ),
      );
      await learning.commit(
        _event(
          'event.order.latest',
          nodeId: 'node.order.latest',
          day: '2026-08-12',
          activityKind: LearningActivityKind.story,
        ),
      );

      final staleRetry = await learning.commit(
        _event(
          'event.order.stale-retry',
          nodeId: 'node.order.stale-retry',
          day: '2026-08-09',
          outcome: LearningAttemptOutcome.retryNeeded,
          evidence: LearningEvidenceLevel.participation,
        ),
      );

      expect(
        staleRetry.skills.single.lastOutcome,
        LearningSkillOutcome.retained,
      );
      expect(staleRetry.skills.single.successfulRetrievals, 1);
      expect(staleRetry.skills.single.lastAttemptDay, '2026-08-12');
      expect(staleRetry.skills.single.lastSuccessDay, '2026-08-11');
      expect(staleRetry.skills.single.nextDueDay, '2026-08-14');
      expect(staleRetry.rewards, isEmpty);
      expect(staleRetry.quests, isEmpty);
    });

    test('runはactivity番号とheartだけ復元し安全な消費を経てcommit時に消す', () async {
      final started = await learning.beginRun(
        LearningRun(
          runId: 'run.1',
          scope: LearningScope.personal,
          nodeId: 'node.fall',
          activityIndex: 0,
          challengeHearts: 5,
          contentVersion: 'catalog.v5',
          updatedAt: DateTime(2026, 8, 10, 10),
        ),
      );
      expect(started.activityIndex, 0);

      final spent = await learning.spendChallengeHeart(
        'run.1',
        lossId: 'loss.1',
        activityIndex: 2,
        learningDay: '2026-08-10',
        occurredAt: DateTime(2026, 8, 10, 10, 1),
      );
      expect(spent.spent, isTrue);
      expect(spent.state.current, 4);
      expect(
        (await learning.activeRun(
          scope: LearningScope.personal,
        ))?.activityIndex,
        2,
      );

      await learning.commit(_event('event.run', runId: 'run.1'));
      expect(await learning.activeRun(scope: LearningScope.personal), isNull);
    });

    test('freezeはpersonalの1日欠けだけを週1回、eventと同じtransactionで守る', () async {
      await learning.commit(_event('event.freeze.base', day: '2026-08-10'));
      final gapEvent = _event('event.freeze.gap', day: '2026-08-12');
      await learning.commit(gapEvent);
      await learning.commit(gapEvent);
      await learning.commit(_event('event.freeze.capped', day: '2026-08-14'));
      await learning.commit(_event('event.freeze.bridge', day: '2026-08-17'));
      await learning.commit(_event('event.freeze.next', day: '2026-08-18'));
      await learning.commit(
        _event('event.freeze.next-week', day: '2026-08-20'),
      );

      final snapshot = await learning.snapshot(LearningScope.personal);
      expect(snapshot.freezes.map((item) => item.day), [
        '2026-08-11',
        '2026-08-19',
      ]);
      expect(snapshot.freezes.first.weekKey, '2026-08-10');
      expect(snapshot.freezes.last.weekKey, '2026-08-17');
      expect(snapshot.streakFreezeRemainingFor('2026-08-12'), 0);
      expect(snapshot.streakFreezeRemainingFor('2026-08-20'), 0);
    });

    test('2日以上の欠けとschoolLocalにはfreezeを作らない', () async {
      await learning.commit(_event('event.long-gap.1', day: '2026-08-10'));
      await learning.commit(_event('event.long-gap.2', day: '2026-08-13'));
      await learning.commit(
        _event('event.long-gap.out-of-order', day: '2026-08-12'),
      );
      await learning.commit(
        _event(
          'event.school-gap.1',
          scope: LearningScope.schoolLocal,
          nodeId: 'node.school.1',
          day: '2026-08-10',
        ),
      );
      await learning.commit(
        _event(
          'event.school-gap.2',
          scope: LearningScope.schoolLocal,
          nodeId: 'node.school.2',
          day: '2026-08-12',
        ),
      );

      expect(
        (await learning.snapshot(LearningScope.personal)).freezes,
        isEmpty,
      );
      final school = await learning.snapshot(LearningScope.schoolLocal);
      expect(school.freezes, isEmpty);
      expect(school.streakFreezeRemainingFor('2026-08-12'), 0);
    });

    test('freeze候補後にpolicyがthrowするとfreezeもeventもrollbackする', () async {
      await learning.commit(_event('event.freeze.rollback.base'));
      final failing = SessionLearningProgressStore(
        session,
        rules: const LearningCommitRules(rewardPolicy: _ThrowingRewardPolicy()),
      );

      await expectLater(
        failing.commit(_event('event.freeze.rollback.gap', day: '2026-08-12')),
        throwsStateError,
      );
      final snapshot = await learning.snapshot(LearningScope.personal);
      expect(snapshot.events, hasLength(1));
      expect(snapshot.freezes, isEmpty);
    });

    test('heart消費はloss IDで冪等、30分ごとと専用回復練習だけで1個戻る', () async {
      await learning.beginRun(
        LearningRun(
          runId: 'run.hearts',
          scope: LearningScope.personal,
          nodeId: 'node.legendary',
          activityIndex: 0,
          challengeHearts: 5,
          contentVersion: 'catalog.v5',
          updatedAt: DateTime(2026, 8, 10, 10),
        ),
      );

      for (var index = 1; index <= 5; index++) {
        final result = await learning.spendChallengeHeart(
          'run.hearts',
          lossId: 'loss.hearts.$index',
          activityIndex: index,
          learningDay: '2026-08-10',
          occurredAt: DateTime(2026, 8, 10, 10, index),
        );
        expect(result.state.current, 5 - index);
      }
      final replay = await learning.spendChallengeHeart(
        'run.hearts',
        lossId: 'loss.hearts.5',
        activityIndex: 5,
        learningDay: '2026-08-10',
        occurredAt: DateTime(2026, 8, 10, 10, 5),
      );
      expect(replay.spent, isFalse);
      expect(replay.state.current, 0);
      await expectLater(
        learning.spendChallengeHeart(
          'run.hearts',
          lossId: 'loss.hearts.empty',
          activityIndex: 6,
          learningDay: '2026-08-10',
          occurredAt: DateTime(2026, 8, 10, 10, 6),
        ),
        throwsStateError,
      );
      await expectLater(
        learning.checkpointRun(
          'run.hearts',
          activityIndex: 6,
          challengeHearts: 5,
          updatedAt: DateTime(2026, 8, 10, 10, 6),
        ),
        throwsStateError,
      );

      final ordinary = await learning.commit(
        _event(
          'event.hearts.ordinary',
          nodeId: 'node.ordinary',
          occurredAt: DateTime(2026, 8, 10, 10, 7),
        ),
      );
      expect(ordinary.node.state, LearningNodeState.cleared);
      expect(
        (await learning.snapshot(
          LearningScope.personal,
        )).challengeHearts?.current,
        0,
      );

      final tooEarly = await learning.refreshChallengeHearts(
        learningDay: '2026-08-10',
        occurredAt: DateTime(2026, 8, 10, 10, 34),
      );
      expect(tooEarly.recovered, 0);
      expect(tooEarly.state.current, 0);
      final timedRecovery = await learning.refreshChallengeHearts(
        learningDay: '2026-08-10',
        occurredAt: DateTime(2026, 8, 10, 10, 35),
      );
      expect(timedRecovery.recovered, 1);
      expect(timedRecovery.state.current, 1);

      await learning.spendChallengeHeart(
        'run.hearts',
        lossId: 'loss.hearts.after-time',
        activityIndex: 6,
        learningDay: '2026-08-10',
        occurredAt: DateTime(2026, 8, 10, 10, 36),
      );
      await learning.commit(
        _event(
          'event.hearts.normal-practice',
          nodeId: 'node.normal-practice',
          origin: LearningOrigin.practice,
          occurredAt: DateTime(2026, 8, 10, 10, 37),
        ),
      );
      expect(
        (await learning.snapshot(
          LearningScope.personal,
        )).challengeHearts?.current,
        0,
      );

      await learning.commit(
        _event(
          'event.hearts.recovery-practice',
          nodeId: 'node.heart-recovery',
          origin: LearningOrigin.practice,
          activityId: 'practice.heart-recovery.v1',
          activityKind: LearningActivityKind.diagram,
          occurredAt: DateTime(2026, 8, 10, 10, 38),
        ),
      );
      final practiceRecovery = await learning.recoverChallengeHeartWithPractice(
        recoveryId: 'heart-recovery.test.1',
        sourceEventId: 'event.hearts.recovery-practice',
        learningDay: '2026-08-10',
        occurredAt: DateTime(2026, 8, 10, 10, 38),
      );
      expect(practiceRecovery.applied, isTrue);
      expect(practiceRecovery.recovered, 1);
      expect(practiceRecovery.state.current, 1);
      final replayPractice = await learning.recoverChallengeHeartWithPractice(
        recoveryId: 'heart-recovery.test.1',
        sourceEventId: 'event.hearts.recovery-practice',
        learningDay: '2026-08-10',
        occurredAt: DateTime(2026, 8, 10, 10, 38),
      );
      expect(replayPractice.applied, isFalse);
      expect(
        (await learning.snapshot(
          LearningScope.personal,
        )).challengeHearts?.current,
        1,
      );
    });

    test('週次leagueは実XPだけで昇格・降格履歴を確定し外部順位を持たない', () async {
      for (var index = 0; index < 3; index++) {
        await learning.commit(
          _event(
            'event.league.w1a.$index',
            nodeId: 'node.league.w1a.$index',
            day: '2026-08-03',
          ),
        );
        await learning.commit(
          _event(
            'event.league.w1b.$index',
            nodeId: 'node.league.w1b.$index',
            day: '2026-08-04',
          ),
        );
      }
      await learning.commit(
        _event('event.league.w2', nodeId: 'node.league.w2', day: '2026-08-10'),
      );
      var history = (await learning.snapshot(
        LearningScope.personal,
      )).leagueHistory;
      expect(history, hasLength(1));
      expect(history.single.weekKey, '2026-08-03');
      expect(history.single.xp, 60);
      expect(history.single.previousTier, LearningLeagueTier.observer);
      expect(history.single.tier, LearningLeagueTier.experimenter);
      expect(history.single.movement, LearningLeagueMovement.promoted);

      await learning.commit(
        _event('event.league.w3', nodeId: 'node.league.w3', day: '2026-08-17'),
      );
      history = (await learning.snapshot(LearningScope.personal)).leagueHistory;
      expect(history, hasLength(2));
      expect(history.last.weekKey, '2026-08-10');
      expect(history.last.xp, 10);
      expect(history.last.previousTier, LearningLeagueTier.experimenter);
      expect(history.last.tier, LearningLeagueTier.observer);
      expect(history.last.movement, LearningLeagueMovement.demoted);
      expect(
        (await learning.snapshot(LearningScope.schoolLocal)).leagueHistory,
        isEmpty,
      );
    });

    test('scope削除はもう一方のscopeを巻き込まない', () async {
      final richLearning = SessionLearningProgressStore(
        session,
        rules: LearningCommitRules(
          quests: [
            LearningQuestDefinition(
              questInstanceId: 'daily:2026-08-10:clear',
              definitionVersion: 'quest.clear.v1',
              target: 1,
              rewardGems: 5,
            ),
          ],
        ),
      );
      await richLearning.commit(_event('event.personal'));
      await richLearning.beginRun(
        LearningRun(
          runId: 'run.clear',
          scope: LearningScope.personal,
          nodeId: 'node.clear.legendary',
          activityIndex: 0,
          challengeHearts: 5,
          contentVersion: 'catalog.v5',
          updatedAt: DateTime(2026, 8, 10, 13),
        ),
      );
      await richLearning.spendChallengeHeart(
        'run.clear',
        lossId: 'loss.clear',
        activityIndex: 1,
        learningDay: '2026-08-10',
        occurredAt: DateTime(2026, 8, 10, 13, 1),
      );
      await richLearning.recoverChallengeHeartsWithGems(
        spendId: 'spend.clear',
        learningDay: '2026-08-10',
        occurredAt: DateTime(2026, 8, 10, 13, 2),
      );
      await richLearning.beginLocalCoopRun(
        LearningLocalCoopRunCommand(
          runId: 'coop.clear',
          participantIds: const {'slot.a', 'slot.b'},
          target: 2,
          rewardGems: 1,
          startDay: '2026-08-10',
          endDay: '2026-08-31',
          definitionVersion: 'coop.clear.v1',
          startedAt: DateTime(2026, 8, 10, 14),
        ),
      );
      await richLearning.commit(
        _event(
          'event.personal.next-week',
          nodeId: 'node.personal.next-week',
          day: '2026-08-17',
        ),
      );
      await learning.commit(
        _event(
          'event.school.keep',
          scope: LearningScope.schoolLocal,
          nodeId: 'node.school',
        ),
      );

      await learning.clearScope(LearningScope.personal);
      final personal = await learning.snapshot(LearningScope.personal);
      expect(personal.events, isEmpty);
      expect(personal.rewards, isEmpty);
      expect(personal.gemSpends, isEmpty);
      expect(personal.localCoopRuns, isEmpty);
      expect(personal.leagueHistory, isEmpty);
      expect(personal.challengeHearts?.current, 5);
      expect(
        (await learning.snapshot(LearningScope.schoolLocal)).events,
        hasLength(1),
      );
    });
  });
}

LearningQuestPlanV2 _v2Plan({
  int day = 10,
  LearningDailyQuestVariant variant = LearningDailyQuestVariant.listening,
}) => const LearningQuestPlannerV2().build(
  now: DateTime(2026, 8, day, 12),
  audience: LearningQuestAudience.personalLocalOnly,
  availableVariants: {variant},
);

LearningQuestDefinition _copyQuest(
  LearningQuestDefinition source, {
  String? definitionVersion,
  int? target,
  int? rewardGems,
  Set<LearningOrigin>? allowedOrigins,
  Set<LearningActivityKind>? allowedActivityKinds,
  LearningEvidenceLevel? minimumEvidence,
}) => LearningQuestDefinition(
  questInstanceId: source.questInstanceId,
  definitionVersion: definitionVersion ?? source.definitionVersion,
  target: target ?? source.target,
  rewardGems: rewardGems ?? source.rewardGems,
  allowedOrigins: allowedOrigins ?? source.allowedOrigins,
  allowedActivityKinds: allowedActivityKinds ?? source.allowedActivityKinds,
  minimumEvidence: minimumEvidence ?? source.minimumEvidence,
);

LearningEventCommand _event(
  String eventId, {
  LearningScope scope = LearningScope.personal,
  String nodeId = 'node.fall',
  String day = '2026-08-10',
  LearningAttemptOutcome outcome = LearningAttemptOutcome.structuredSuccess,
  LearningEvidenceLevel evidence = LearningEvidenceLevel.selfCompared,
  LearningActivityKind activityKind = LearningActivityKind.singleSelect,
  LearningOrigin? origin,
  String activityId = 'activity.fall.1',
  String? runId,
  DateTime? occurredAt,
  Iterable<String> skillIds = const {'concept.fall'},
  Map<String, Iterable<String>>? practiceNeedCodes,
  Map<String, Iterable<String>> resolvedPracticeNeedCodes = const {},
  LearningRepairResolution? repairResolution,
}) => LearningEventCommand(
  eventId: eventId,
  scope: scope,
  origin: scope == LearningScope.schoolLocal
      ? LearningOrigin.schoolAssignment
      : origin ?? LearningOrigin.path,
  courseId: 'course.jhs-science',
  nodeId: nodeId,
  activityId: activityId,
  skillIds: skillIds,
  activityKind: activityKind,
  outcome: outcome,
  evidence: evidence,
  contentVersion: 'catalog.v6',
  learningDay: day,
  occurredAt: occurredAt ?? DateTime.parse('${day}T12:00:00'),
  runId: runId,
  practiceNeedCodes:
      practiceNeedCodes ??
      (outcome == LearningAttemptOutcome.retryNeeded
          ? const {
              'concept.fall': {'condition.air-resistance'},
            }
          : const {}),
  resolvedPracticeNeedCodes: resolvedPracticeNeedCodes,
  repairResolution: repairResolution,
);

LearningRepairResolution _practiceResolution(String needCode, int attempt) =>
    LearningRepairResolution(
      unitId: 'force-motion',
      conceptKey: 'fall',
      skillId: 'force-motion/fall',
      needCode: needCode,
      routeKind: LearningRepairRouteKind.practice,
      practiceAttempt: attempt,
    );

final class _ThrowingRewardPolicy implements LearningRewardPolicy {
  const _ThrowingRewardPolicy();

  @override
  int xpForEvent({
    required LearningEventCommand event,
    required bool meaningfulProgress,
    required int xpEarnedOnDay,
  }) => throw StateError('injected failure after event insert');
}
