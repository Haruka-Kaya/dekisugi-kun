import 'dart:io';

import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/learning/domain/learning_monthly_badge.dart';
import 'package:dekisugi/learning/domain/learning_policy.dart';
import 'package:dekisugi/learning/domain/learning_progress.dart';
import 'package:dekisugi/learning/services/game_path_projection.dart';
import 'package:dekisugi/learning/services/learning_monthly_badge_projection.dart';
import 'package:dekisugi/learning/services/learning_progress_store.dart';
import 'package:dekisugi/learning/services/learning_quest_plan_v2.dart';
import 'package:dekisugi/models/day_key.dart';
import 'package:dekisugi/models/game_path.dart';
import 'package:dekisugi/models/lan_social.dart';
import 'package:dekisugi/models/unit.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _planner = LearningQuestPlannerV2();
const _boardProjection = LearningQuestBoardProjectionV2();
const _allVariants = <LearningDailyQuestVariant>{
  LearningDailyQuestVariant.comparePrediction,
  LearningDailyQuestVariant.storyCase,
  LearningDailyQuestVariant.listening,
  LearningDailyQuestVariant.speaking,
  LearningDailyQuestVariant.diagram,
  LearningDailyQuestVariant.notation,
  LearningDailyQuestVariant.transfer,
  LearningDailyQuestVariant.spacedReview,
};

const _status = GamePlayerStatus(
  streakDays: 0,
  streakFreezeRemaining: 0,
  gems: 0,
  hearts: 5,
);

const _catalog = <UnitSummary>[
  UnitSummary(
    id: 'motion',
    title: '運動',
    brief: '運動を説明する',
    concepts: [UnitConcept(key: 'fall', label: '落下', storyTitle: '落下事件')],
    sectionCount: 1,
  ),
];

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('LearningDailyQuestAvailabilityProjection', () {
    test('現在の意味あるPath種別と未完了Notation・期限復習だけを候補にする', () {
      final cleared = {
        GamePathProjection.nodeId('motion', 'fall', GamePathNodeKind.lesson),
        GamePathProjection.nodeId('motion', 'fall', GamePathNodeKind.practice),
      };
      final path = const GamePathProjection().build(
        catalog: _catalog,
        progress: GamePathProgressInput(clearedNodeIds: cleared),
        status: _status,
      );

      final projected = const LearningDailyQuestAvailabilityProjection().build(
        path: path,
        hasMeaningfulNotation: true,
        hasDueSpacedReview: true,
      );

      expect(path.currentNodeId, endsWith(':story'));
      expect(projected, {
        LearningDailyQuestVariant.storyCase,
        LearningDailyQuestVariant.notation,
        LearningDailyQuestVariant.spacedReview,
      });
      expect(projected, isNot(contains(LearningDailyQuestVariant.listening)));
    });

    test('course完了・期限なし・未完了Notationなしでは架空候補を作らない', () {
      final cleared = {
        for (final kind in GamePathNodeKind.values)
          if (kind != GamePathNodeKind.legendary)
            GamePathProjection.nodeId('motion', 'fall', kind),
      };
      final path = const GamePathProjection().build(
        catalog: _catalog,
        progress: GamePathProgressInput(clearedNodeIds: cleared),
        status: _status,
      );

      expect(
        const LearningDailyQuestAvailabilityProjection().build(path: path),
        isEmpty,
      );
    });

    test('Pathとは別の未完了Listening・Speaking missionも固有候補に含める', () {
      final path = const GamePathProjection().build(
        catalog: _catalog,
        progress: const GamePathProgressInput(),
        status: _status,
      );

      expect(
        const LearningDailyQuestAvailabilityProjection().build(
          path: path,
          hasDailyListening: true,
          hasDailySpeaking: true,
        ),
        {
          LearningDailyQuestVariant.comparePrediction,
          LearningDailyQuestVariant.listening,
          LearningDailyQuestVariant.speaking,
        },
      );
    });
  });

  group('LearningQuestPlannerV2', () {
    test('全V2 instance keyからfilters・evidence・rewardを含む定義全体を復元する', () {
      final definitions = <LearningQuestDefinition>[];
      for (final variant in _allVariants) {
        final plan = _planner.build(
          now: DateTime(2026, 8, 10, 12),
          audience: LearningQuestAudience.personalLocalOnly,
          availableVariants: {variant},
        );
        definitions.add(plan.dailyDefinition);
      }
      definitions.add(
        _planner
            .build(
              now: DateTime(2026, 8, 10, 12),
              audience: LearningQuestAudience.personalLocalOnly,
              availableVariants: const {
                LearningDailyQuestVariant.comparePrediction,
              },
            )
            .activeDefinitions
            .singleWhere(
              (definition) => definition.questInstanceId.startsWith('monthly:'),
            ),
      );

      for (final definition in definitions) {
        final restored =
            LearningQuestPlannerV2.canonicalDefinitionForInstanceId(
              definition.questInstanceId,
            );
        expect(restored.definitionVersion, definition.definitionVersion);
        expect(restored.target, definition.target);
        expect(restored.rewardGems, definition.rewardGems);
        expect(
          restored.allowedOrigins,
          unorderedEquals(definition.allowedOrigins),
        );
        expect(
          restored.allowedActivityKinds,
          unorderedEquals(definition.allowedActivityKinds),
        );
        expect(restored.minimumEvidence, definition.minimumEvidence);
        expect(
          () => LearningQuestPlannerV2.requireCanonicalMaterializedDefinition(
            definition,
          ),
          returnsNormally,
        );
      }
      expect(
        () => LearningQuestPlannerV2.canonicalDefinitionForInstanceId(
          'daily:2026-08-10:unknown',
        ),
        throwsArgumentError,
      );
    });

    test('8つの固有内容を日替わりで巡回し、titleとCTAを件数文言で代用しない', () {
      final plans = [
        for (var offset = 0; offset < _allVariants.length; offset++)
          _planner.build(
            now: DateTime(2026, 8, 10 + offset, 12),
            audience: LearningQuestAudience.personalLocalOnly,
            availableVariants: _allVariants,
          ),
      ];

      expect(
        plans.map((plan) => plan.dailyDefinition.questInstanceId).toSet(),
        hasLength(_allVariants.length),
      );
      expect(
        plans.map((plan) => plan.dailyPresentation.title).toSet(),
        hasLength(_allVariants.length),
      );
      expect(
        plans.map((plan) => plan.dailyPresentation.action.label).toSet(),
        hasLength(_allVariants.length),
      );
      expect(plans.map((plan) => plan.dailyDefinition.target), everyElement(1));
      expect(
        plans.map((plan) => plan.dailyPresentation.title),
        everyElement(isNot(contains('意味のある学習を1件'))),
      );
      expect(
        plans.map((plan) => plan.dailyPresentation.action.destination),
        everyElement(
          isNot(
            anyOf(
              LearningQuestDestination.profile,
              LearningQuestDestination.lanSocial,
            ),
          ),
        ),
        reason: 'dailyはunder-18本人利用でも成立する端末内学習だけへ送る',
      );
    });

    test('各variantは固有activityだけを数え、無関係なmeaningful eventを数えない', () {
      for (final variant in _allVariants) {
        final plan = _planner.build(
          now: DateTime(2026, 8, 10, 12),
          audience: LearningQuestAudience.personalLocalOnly,
          availableVariants: {variant},
        );
        final definition = plan.dailyDefinition;
        final matching = _eventForDefinition(
          definition,
          eventId: 'variant:${variant.name}:matching',
          nodeId: 'variant:${variant.name}:node',
        );
        final wrong = LearningEventCommand(
          eventId: 'variant:${variant.name}:wrong',
          scope: LearningScope.personal,
          origin: LearningOrigin.path,
          courseId: 'science-ja-v1',
          nodeId: 'variant:${variant.name}:wrong-node',
          activityId: 'quest.v2.wrong',
          skillIds: {'science/${variant.name}'},
          activityKind: LearningActivityKind.classify,
          outcome: LearningAttemptOutcome.structuredSuccess,
          evidence: LearningEvidenceLevel.spacedTransfer,
          contentVersion: 'catalog-v9',
          learningDay: plan.learningDay,
          occurredAt: dayStartOf(plan.learningDay).toUtc(),
        );

        expect(definition.matches(matching), isTrue, reason: variant.name);
        expect(definition.matches(wrong), isFalse, reason: variant.name);
      }
    });

    test('午前4時までは同じ学習日・同じ内容、4時から次の日の内容になる', () {
      final start = _planner.build(
        now: DateTime(2026, 8, 10, 4),
        audience: LearningQuestAudience.personalLocalOnly,
        availableVariants: _allVariants,
      );
      final before = _planner.build(
        now: DateTime(2026, 8, 11, 3, 59, 59),
        audience: LearningQuestAudience.personalLocalOnly,
        availableVariants: _allVariants,
      );
      final after = _planner.build(
        now: DateTime(2026, 8, 11, 4),
        audience: LearningQuestAudience.personalLocalOnly,
        availableVariants: _allVariants,
      );

      expect(start.learningDay, '2026-08-10');
      expect(before.learningDay, start.learningDay);
      expect(
        before.dailyDefinition.questInstanceId,
        start.dailyDefinition.questInstanceId,
      );
      expect(after.learningDay, '2026-08-11');
      expect(
        after.dailyDefinition.questInstanceId,
        isNot(start.dailyDefinition.questInstanceId),
      );
    });

    test('0件materialize済みdefinitionを候補変化後も復元し、同日差し替えない', () {
      final initial = _planner.build(
        now: DateTime(2026, 8, 10, 12),
        audience: LearningQuestAudience.personalLocalOnly,
        availableVariants: const {
          LearningDailyQuestVariant.storyCase,
          LearningDailyQuestVariant.listening,
        },
      );
      final daily = _progressFor(initial.dailyDefinition, progress: 0);
      final monthlyDefinition = initial.activeDefinitions.singleWhere(
        (definition) => definition.questInstanceId.startsWith('monthly:'),
      );
      final monthly = _progressFor(monthlyDefinition, progress: 0);
      final restarted = _planner.build(
        now: DateTime(2026, 8, 10, 23, 59),
        audience: LearningQuestAudience.personalLocalOnly,
        availableVariants: const {LearningDailyQuestVariant.notation},
        persistedQuests: [daily, monthly],
      );

      expect(initial.definitionsToMaterialize, hasLength(2));
      expect(restarted.definitionsToMaterialize, isEmpty);
      expect(
        restarted.dailyDefinition.questInstanceId,
        initial.dailyDefinition.questInstanceId,
      );
      expect(
        restarted.dailyPresentation.action.label,
        initial.dailyPresentation.action.label,
      );
    });

    test('同日開始済みV1を維持し、未知・不整合・複数dailyはfail closedする', () {
      const day = '2026-08-10';
      final legacy = LearningQuestProgress(
        scope: LearningScope.personal,
        questInstanceId: 'daily:$day:two-actions',
        progress: 1,
        target: 2,
        completedAt: null,
        rewardedAt: null,
        definitionVersion: 'daily.v2',
      );
      final restored = _planner.build(
        now: DateTime(2026, 8, 10, 12),
        audience: LearningQuestAudience.personalLocalOnly,
        availableVariants: const {LearningDailyQuestVariant.notation},
        persistedQuests: [legacy],
      );
      expect(restored.dailyDefinition.questInstanceId, legacy.questInstanceId);
      expect(restored.dailyDefinition.target, 2);

      LearningQuestProgress row(String key, {int target = 1}) =>
          LearningQuestProgress(
            scope: LearningScope.personal,
            questInstanceId: 'daily:$day:$key',
            progress: 0,
            target: target,
            completedAt: null,
            rewardedAt: null,
            definitionVersion: LearningQuestPlannerV2.definitionVersion,
          );
      expect(
        () => _planner.build(
          now: DateTime(2026, 8, 10, 12),
          audience: LearningQuestAudience.personalLocalOnly,
          availableVariants: const {LearningDailyQuestVariant.notation},
          persistedQuests: [row('unknown')],
        ),
        throwsStateError,
      );
      expect(
        () => _planner.build(
          now: DateTime(2026, 8, 10, 12),
          audience: LearningQuestAudience.personalLocalOnly,
          availableVariants: const {LearningDailyQuestVariant.notation},
          persistedQuests: [row('notation-trace', target: 2)],
        ),
        throwsStateError,
      );
      expect(
        () => _planner.build(
          now: DateTime(2026, 8, 10, 12),
          audience: LearningQuestAudience.personalLocalOnly,
          availableVariants: const {LearningDailyQuestVariant.notation},
          persistedQuests: [row('notation-trace'), row('compare-prediction')],
        ),
        throwsStateError,
      );
    });

    test('meaningful候補が無い時は達成不能なdailyを捏造しない', () {
      final plan = _planner.build(
        now: DateTime(2026, 8, 10, 12),
        audience: LearningQuestAudience.personalLocalOnly,
      );
      final board = _boardProjection.build(plan: plan);

      expect(plan.hasDailyQuest, isFalse);
      expect(() => plan.dailyDefinition, throwsStateError);
      expect(plan.activeDefinitions, hasLength(1));
      expect(
        plan.activeDefinitions.single.questInstanceId,
        startsWith('monthly:'),
      );
      expect(plan.definitionsToMaterialize, hasLength(1));
      expect(board, hasLength(1));
      expect(board.single.kind, LearningQuestPresentationKind.monthly);
      expect(board.single.description, contains('次の復習日を待ちます'));
      expect(board.single.action.label, '今月の記録を見る');
      expect(board.single.action.destination, LearningQuestDestination.profile);
    });

    test('schoolは端末授業1件・無報酬だけでmonthly/materializeを作らない', () {
      final plan = _planner.build(
        now: DateTime(2026, 8, 10, 12),
        audience: LearningQuestAudience.schoolLocal,
        availableVariants: _allVariants,
      );
      final board = _boardProjection.build(plan: plan, schoolDailyProgress: 1);

      expect(plan.activeDefinitions, hasLength(1));
      expect(plan.definitionsToMaterialize, isEmpty);
      expect(plan.dailyDefinition.rewardGems, 0);
      expect(
        plan.dailyPresentation.kind,
        LearningQuestPresentationKind.classroom,
      );
      expect(board.single.rewardGems, 0);
      expect(board.single.state, LearningQuestBoardState.completed);
    });
  });

  group('LearningQuestBoardProjectionV2', () {
    test('Daily・Monthly・local Friendsを共通boardへ束ね、固有CTAを保持する', () {
      final plan = _planner.build(
        now: DateTime(2026, 8, 10, 12),
        audience: LearningQuestAudience.personalLocalOnly,
        availableVariants: const {LearningDailyQuestVariant.storyCase},
      );
      final monthly = plan.activeDefinitions.singleWhere(
        (definition) => definition.questInstanceId.startsWith('monthly:'),
      );
      final items = _boardProjection.build(
        plan: plan,
        persistedQuests: [
          _progressFor(plan.dailyDefinition, progress: 0),
          _progressFor(
            monthly,
            progress: monthly.target,
            completedAt: DateTime.utc(2026, 8, 20),
            rewardedAt: DateTime.utc(2026, 8, 20),
          ),
        ],
        friends: LearningFriendsQuestBoardSource.localInvite(
          weekKey: '2026-08-10',
        ),
      );

      expect(items.map((item) => item.kind), [
        LearningQuestPresentationKind.daily,
        LearningQuestPresentationKind.monthly,
        LearningQuestPresentationKind.friend,
      ]);
      expect(items.first.action.label, '今日の事件簿を開く');
      expect(items.first.action.destination, LearningQuestDestination.stories);
      expect(items[1].state, LearningQuestBoardState.rewarded);
      expect(items[1].action.label, '獲得バッジを見る');
      expect(items.last.action.label, '2人のクエストを準備する');
      expect(items.last.action.destination, LearningQuestDestination.profile);
    });

    test('local-only・成人LAN同意・schoolのFriends境界を交差させない', () {
      final local = _planner.build(
        now: DateTime(2026, 8, 10, 12),
        audience: LearningQuestAudience.personalLocalOnly,
        availableVariants: const {LearningDailyQuestVariant.comparePrediction},
      );
      final adult = _planner.build(
        now: DateTime(2026, 8, 10, 12),
        audience: LearningQuestAudience.personalLanConsented,
        availableVariants: const {LearningDailyQuestVariant.comparePrediction},
      );
      final school = _planner.build(
        now: DateTime(2026, 8, 10, 12),
        audience: LearningQuestAudience.schoolLocal,
      );
      final localSource = LearningFriendsQuestBoardSource.localInvite(
        weekKey: '2026-08-10',
      );
      final lanSource = LearningFriendsQuestBoardSource.lanInvite();

      expect(
        _boardProjection.build(plan: local, friends: localSource),
        hasLength(3),
      );
      expect(
        _boardProjection.build(plan: adult, friends: lanSource),
        hasLength(3),
      );
      expect(
        () => _boardProjection.build(plan: local, friends: lanSource),
        throwsStateError,
      );
      expect(
        () => _boardProjection.build(plan: adult, friends: localSource),
        throwsStateError,
      );
      expect(
        () => _boardProjection.build(plan: school, friends: localSource),
        throwsStateError,
      );
    });

    test('LAN Friendsは共同状態だけを0/2→1/2→2/2へ投影する', () {
      LearningFriendsQuestBoardSource source({
        required LanSocialFriendsState state,
        required bool partnerJoined,
        required bool mine,
        required bool completed,
        bool rewarded = false,
      }) => LearningFriendsQuestBoardSource.lanRoom(
        roomId: 'abcdef012345abcdef012345',
        snapshot: LanSocialFriendsSnapshot(
          state: state,
          partnerJoined: partnerJoined,
          myContributed: mine,
          completed: completed,
          expiresAt: DateTime.utc(2026, 8, 11),
        ),
        rewardRecorded: rewarded,
      );

      expect(
        source(
          state: LanSocialFriendsState.waitingForPartner,
          partnerJoined: false,
          mine: false,
          completed: false,
        ).item.current,
        0,
      );
      expect(
        source(
          state: LanSocialFriendsState.active,
          partnerJoined: true,
          mine: true,
          completed: false,
        ).item.current,
        1,
      );
      final completed = source(
        state: LanSocialFriendsState.completed,
        partnerJoined: true,
        mine: true,
        completed: true,
        rewarded: true,
      ).item;
      expect(completed.current, 2);
      expect(completed.state, LearningQuestBoardState.rewarded);
      expect(completed.rewardGems, 1);
      expect(completed.action.destination, LearningQuestDestination.lanSocial);
    });
  });

  group('V2 planner + existing Store', () {
    test('Memory/SQLiteで固有activityだけ進み、同じevent再送は報酬を増やさない', () async {
      final tmp = Directory.systemTemp.createTempSync('quest-v2-store-');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final stores = <SessionStore>[
        MemorySessionStore(),
        await SqfliteSessionStore.open(path: p.join(tmp.path, 'learning.db')),
      ];
      for (final store in stores) {
        final plan = _planner.build(
          now: DateTime(2026, 8, 10, 12),
          audience: LearningQuestAudience.personalLocalOnly,
          availableVariants: const {LearningDailyQuestVariant.listening},
        );
        final progress = SessionLearningProgressStore(
          store,
          rules: plan.commitRules,
        );
        await progress.materializeQuestDefinitions(
          scope: LearningScope.personal,
          definitions: [plan.dailyDefinition],
        );
        await progress.commit(
          _event(
            eventId: 'quest:v2:wrong',
            day: plan.learningDay,
            nodeId: 'quest:v2:wrong-node',
            origin: LearningOrigin.path,
            kind: LearningActivityKind.read,
          ),
        );
        var snapshot = await progress.snapshot(LearningScope.personal);
        final untouched = snapshot.quests.singleWhere(
          (quest) =>
              quest.questInstanceId == plan.dailyDefinition.questInstanceId,
        );
        expect(untouched.progress, 0);
        expect(untouched.rewardedAt, isNull);
        expect(
          snapshot.quests.where(
            (quest) =>
                quest.questInstanceId == plan.dailyDefinition.questInstanceId,
          ),
          hasLength(1),
        );

        final matching = _event(
          eventId: 'quest:v2:listening',
          day: plan.learningDay,
          nodeId: 'quest:v2:listening-node',
          origin: LearningOrigin.practice,
          kind: LearningActivityKind.listen,
        );
        final first = await progress.commit(matching);
        final replay = await progress.commit(matching);
        snapshot = await progress.snapshot(LearningScope.personal);
        final daily = snapshot.quests.singleWhere(
          (quest) =>
              quest.questInstanceId == plan.dailyDefinition.questInstanceId,
        );

        expect(first.inserted, isTrue);
        expect(replay.inserted, isFalse);
        expect(daily.progress, 1);
        expect(daily.rewardedAt, isNotNull);
        expect(snapshot.wallet.gems, 1);
        final restarted = _planner.build(
          now: DateTime(2026, 8, 10, 23),
          audience: LearningQuestAudience.personalLocalOnly,
          availableVariants: const {LearningDailyQuestVariant.notation},
          persistedQuests: snapshot.quests,
        );
        expect(
          restarted.dailyDefinition.questInstanceId,
          plan.dailyDefinition.questInstanceId,
        );
      }
      for (final store in stores) {
        await store.close();
      }
    });

    test('monthly 12件は8結晶と一意badgeを作り、daily報酬と二重化しない', () async {
      final store = MemorySessionStore();
      addTearDown(store.close);
      final plan = _planner.build(
        now: DateTime(2026, 8, 10, 12),
        audience: LearningQuestAudience.personalLocalOnly,
        availableVariants: const {LearningDailyQuestVariant.comparePrediction},
      );
      final progress = SessionLearningProgressStore(
        store,
        rules: plan.commitRules,
      );
      for (
        var index = 0;
        index < LearningMonthlyBadgeCatalogV1.target;
        index++
      ) {
        await progress.commit(
          _event(
            eventId: 'quest:v2:monthly-$index',
            day: plan.learningDay,
            nodeId: 'quest:v2:monthly-node-$index',
            origin: LearningOrigin.path,
            kind: LearningActivityKind.read,
          ),
        );
      }
      await progress.commit(
        _event(
          eventId: 'quest:v2:monthly-0',
          day: plan.learningDay,
          nodeId: 'quest:v2:monthly-node-0',
          origin: LearningOrigin.path,
          kind: LearningActivityKind.read,
        ),
      );
      final snapshot = await progress.snapshot(LearningScope.personal);
      final monthly = snapshot.quests.singleWhere(
        (quest) => quest.questInstanceId.startsWith('monthly:'),
      );
      final badges = const LearningMonthlyBadgeProjection().build(snapshot);

      expect(monthly.progress, LearningMonthlyBadgeCatalogV1.target);
      expect(monthly.rewardedAt, isNotNull);
      expect(snapshot.wallet.gems, 9, reason: 'daily 1 + monthly 8');
      expect(badges, hasLength(1));
      expect(badges.single.sourceQuestInstanceId, monthly.questInstanceId);
    });

    test('実2枠Friendsの保存・共同進捗・3結晶・board反映は冪等', () async {
      final store = MemorySessionStore();
      addTearDown(store.close);
      final progress = SessionLearningProgressStore(store);
      final run = await progress.beginLocalCoopRun(
        LearningLocalCoopRunCommand(
          runId: 'pair-v2-test',
          participantIds: const {'pair-v2-test:a', 'pair-v2-test:b'},
          target: 2,
          rewardGems: 3,
          startDay: '2026-08-10',
          endDay: '2026-08-16',
          definitionVersion: 'local-pair.v1',
          startedAt: DateTime.utc(2026, 8, 10, 4),
        ),
      );
      final firstEvent = await progress.commit(
        _event(
          eventId: 'pair-v2:event-a',
          day: '2026-08-10',
          nodeId: 'pair-v2:node-a',
          origin: LearningOrigin.path,
          kind: LearningActivityKind.read,
        ),
      );
      final secondEvent = await progress.commit(
        _event(
          eventId: 'pair-v2:event-b',
          day: '2026-08-10',
          nodeId: 'pair-v2:node-b',
          origin: LearningOrigin.lab,
          kind: LearningActivityKind.diagram,
        ),
      );
      await progress.contributeLocalCoopRun(
        run.runId,
        contributionId: 'pair-v2:contribution-a',
        participantId: 'pair-v2-test:a',
        eventId: firstEvent.event.eventId,
        occurredAt: DateTime.utc(2026, 8, 10, 5),
      );
      final completed = await progress.contributeLocalCoopRun(
        run.runId,
        contributionId: 'pair-v2:contribution-b',
        participantId: 'pair-v2-test:b',
        eventId: secondEvent.event.eventId,
        occurredAt: DateTime.utc(2026, 8, 10, 6),
      );
      final replay = await progress.contributeLocalCoopRun(
        run.runId,
        contributionId: 'pair-v2:contribution-b',
        participantId: 'pair-v2-test:b',
        eventId: secondEvent.event.eventId,
        occurredAt: DateTime.utc(2026, 8, 10, 6),
      );
      final snapshot = await progress.snapshot(LearningScope.personal);
      final plan = _planner.build(
        now: DateTime(2026, 8, 10, 12),
        audience: LearningQuestAudience.personalLocalOnly,
        availableVariants: const {LearningDailyQuestVariant.comparePrediction},
      );
      final board = _boardProjection.build(
        plan: plan,
        friends: LearningFriendsQuestBoardSource.localRun(completed.run),
      );
      final friend = board.singleWhere(
        (item) => item.kind == LearningQuestPresentationKind.friend,
      );

      expect(completed.applied, isTrue);
      expect(completed.run.progress, 2);
      expect(completed.rewards.single.amount, 3);
      expect(replay.applied, isFalse);
      expect(snapshot.wallet.gems, 3);
      expect(friend.current, 2);
      expect(friend.state, LearningQuestBoardState.rewarded);
      expect(friend.action.focus, LearningQuestFocus.localFriendsQuest);
    });
  });
}

LearningQuestProgress _progressFor(
  LearningQuestDefinition definition, {
  required int progress,
  DateTime? completedAt,
  DateTime? rewardedAt,
}) => LearningQuestProgress(
  scope: LearningScope.personal,
  questInstanceId: definition.questInstanceId,
  progress: progress,
  target: definition.target,
  completedAt: completedAt,
  rewardedAt: rewardedAt,
  definitionVersion: definition.definitionVersion,
);

LearningEventCommand _eventForDefinition(
  LearningQuestDefinition definition, {
  required String eventId,
  required String nodeId,
}) => LearningEventCommand(
  eventId: eventId,
  scope: LearningScope.personal,
  origin: definition.allowedOrigins.first,
  courseId: 'science-ja-v1',
  nodeId: nodeId,
  activityId: 'quest.v2.matching',
  skillIds: {'science/quest-v2'},
  activityKind: definition.allowedActivityKinds.first,
  outcome: LearningAttemptOutcome.structuredSuccess,
  evidence: definition.minimumEvidence,
  contentVersion: 'catalog-v9',
  learningDay: definition.questInstanceId.split(':')[1],
  occurredAt: dayStartOf(definition.questInstanceId.split(':')[1]).toUtc(),
);

LearningEventCommand _event({
  required String eventId,
  required String day,
  required String nodeId,
  required LearningOrigin origin,
  required LearningActivityKind kind,
}) => LearningEventCommand(
  eventId: eventId,
  scope: LearningScope.personal,
  origin: origin,
  courseId: 'science-ja-v1',
  nodeId: nodeId,
  activityId: 'quest.v2.${kind.name}',
  skillIds: {'science/$nodeId'},
  activityKind: kind,
  outcome: LearningAttemptOutcome.structuredSuccess,
  evidence:
      kind == LearningActivityKind.story || kind == LearningActivityKind.diagram
      ? LearningEvidenceLevel.structuredCorrection
      : LearningEvidenceLevel.selfCompared,
  contentVersion: 'catalog-v9',
  learningDay: day,
  occurredAt: dayStartOf(day).toUtc(),
);
