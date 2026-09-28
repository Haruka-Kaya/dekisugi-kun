import 'dart:io';

import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/learning/domain/learning_monthly_badge.dart';
import 'package:dekisugi/learning/domain/learning_policy.dart';
import 'package:dekisugi/learning/domain/learning_progress.dart';
import 'package:dekisugi/learning/services/learning_game_projection.dart';
import 'package:dekisugi/learning/services/learning_progress_store.dart';
import 'package:dekisugi/learning/services/learning_quest_plan.dart';
import 'package:dekisugi/models/day_key.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  const planner = LearningQuestPlannerV1();

  group('LearningQuestPlannerV1', () {
    test('午前4時までは同じ定義で、4時から次の1件／2件目標へ切り替わる', () {
      final atStart = planner.build(
        now: DateTime(2026, 8, 10, 4),
        scope: LearningScope.personal,
      );
      final beforeNextCutover = planner.build(
        now: DateTime(2026, 8, 11, 3, 59, 59),
        scope: LearningScope.personal,
      );
      final atNextCutover = planner.build(
        now: DateTime(2026, 8, 11, 4),
        scope: LearningScope.personal,
      );

      expect(atStart.learningDay, '2026-08-10');
      expect(beforeNextCutover.learningDay, atStart.learningDay);
      expect(
        _definitionSignature(beforeNextCutover.dailyDefinition),
        _definitionSignature(atStart.dailyDefinition),
      );
      expect(beforeNextCutover.dailyTitle, atStart.dailyTitle);
      expect(atNextCutover.learningDay, '2026-08-11');
      expect(
        atNextCutover.dailyDefinition.target,
        isNot(atStart.dailyDefinition.target),
      );
      expect(
        {atStart.dailyDefinition.target, atNextCutover.dailyDefinition.target},
        {1, 2},
      );
    });

    test('同日再起動は保存済み定義を維持し、旧one-actionも途中で2件へ変えない', () {
      final twoActionDay = _dayForTarget(planner, 2);
      final fresh = planner.build(
        now: twoActionDay,
        scope: LearningScope.personal,
      );
      final savedTwo = LearningQuestProgress(
        scope: LearningScope.personal,
        questInstanceId: fresh.dailyDefinition.questInstanceId,
        progress: 1,
        target: 2,
        completedAt: null,
        rewardedAt: null,
        definitionVersion: LearningQuestPlannerV1.twoActionsDefinitionVersion,
      );
      final restarted = planner.build(
        now: DateTime(
          twoActionDay.year,
          twoActionDay.month,
          twoActionDay.day + 1,
          3,
          59,
        ),
        scope: LearningScope.personal,
        persistedQuests: [savedTwo],
      );
      expect(
        _definitionSignature(restarted.dailyDefinition),
        _definitionSignature(fresh.dailyDefinition),
      );

      final day = fresh.learningDay;
      final legacy = LearningQuestProgress(
        scope: LearningScope.personal,
        questInstanceId: 'daily:$day:one-action',
        progress: 1,
        target: 1,
        completedAt: twoActionDay,
        rewardedAt: twoActionDay,
        definitionVersion: LearningQuestPlannerV1.oneActionDefinitionVersion,
      );
      final compatible = planner.build(
        now: twoActionDay,
        scope: LearningScope.personal,
        persistedQuests: [legacy],
      );
      expect(
        compatible.dailyDefinition.questInstanceId,
        legacy.questInstanceId,
      );
      expect(compatible.dailyDefinition.target, 1);
      expect(
        compatible.dailyTitle,
        LearningQuestPlannerV1.personalOneActionTitle,
      );
    });

    test('personalは正確な1件／2件titleと月間12件を返し、kindを限定しない', () {
      for (final target in const [1, 2]) {
        final plan = planner.build(
          now: _dayForTarget(planner, target),
          scope: LearningScope.personal,
        );
        final daily = plan.dailyDefinition;
        final monthly = plan.activeQuestDefinitions.singleWhere(
          (quest) => quest.questInstanceId.startsWith('monthly:'),
        );

        expect(daily.target, target);
        expect(
          plan.dailyTitle,
          target == 1
              ? LearningQuestPlannerV1.personalOneActionTitle
              : LearningQuestPlannerV1.personalTwoActionsTitle,
        );
        expect(daily.allowedOrigins, isEmpty);
        expect(daily.allowedActivityKinds, isEmpty);
        expect(daily.minimumEvidence, LearningEvidenceLevel.selfCompared);
        expect(daily.rewardGems, 1);
        expect(monthly.target, LearningMonthlyBadgeCatalogV1.target);
        expect(
          monthly.definitionVersion,
          LearningMonthlyBadgeCatalogV1.definitionVersion,
        );
        expect(monthly.rewardGems, 8);
        expect(plan.questTitles[monthly.questInstanceId], '今月、意味のある学習を12件終える');
        expect(plan.commitRules.quests, same(plan.activeQuestDefinitions));
      }
    });

    test('schoolLocalは既存の端末授業1件だけを無報酬で維持する', () {
      final plan = planner.build(
        now: DateTime(2026, 8, 10, 12),
        scope: LearningScope.schoolLocal,
      );

      expect(plan.activeQuestDefinitions, hasLength(1));
      expect(
        plan.dailyDefinition.questInstanceId,
        'daily:2026-08-10:one-action',
      );
      expect(
        plan.dailyDefinition.definitionVersion,
        LearningQuestPlannerV1.oneActionDefinitionVersion,
      );
      expect(plan.dailyDefinition.target, 1);
      expect(plan.dailyDefinition.rewardGems, 0);
      expect(plan.dailyTitle, LearningQuestPlannerV1.schoolDailyTitle);
      expect(
        plan.activeQuestDefinitions.any(
          (quest) => quest.questInstanceId.startsWith('monthly:'),
        ),
        isFalse,
      );
    });

    test('保存済みinstanceのtarget/version不一致は安全側に拒否する', () {
      final twoActionDay = _dayForTarget(planner, 2);
      final day = dayKeyOf(twoActionDay);
      final incompatible = LearningQuestProgress(
        scope: LearningScope.personal,
        questInstanceId: 'daily:$day:two-actions',
        progress: 1,
        target: 1,
        completedAt: null,
        rewardedAt: null,
        definitionVersion: LearningQuestPlannerV1.twoActionsDefinitionVersion,
      );

      expect(
        () => planner.build(
          now: twoActionDay,
          scope: LearningScope.personal,
          persistedQuests: [incompatible],
        ),
        throwsStateError,
      );
    });
  });

  group('quest plan + existing store', () {
    test('SQLite再起動後も同じ学習日の実体化済みtargetを引き継ぐ', () async {
      final tmp = Directory.systemTemp.createTempSync('dekisugi-quest-plan-');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final path = p.join(tmp.path, 'learning.db');
      final now = _dayForTarget(planner, 2);
      final initialPlan = planner.build(
        now: now,
        scope: LearningScope.personal,
      );

      final firstStore = await SqfliteSessionStore.open(path: path);
      final firstProgress = SessionLearningProgressStore(
        firstStore,
        rules: initialPlan.commitRules,
      );
      await firstProgress.commit(
        _event(day: initialPlan.learningDay, index: 0, nodeIndex: 0),
      );
      await firstStore.close();

      final secondStore = await SqfliteSessionStore.open(path: path);
      final restored = await secondStore.learningProgressSnapshot(
        LearningScope.personal,
      );
      final restartedPlan = planner.build(
        now: DateTime(now.year, now.month, now.day + 1, 3, 59),
        scope: LearningScope.personal,
        persistedQuests: restored.quests,
      );
      final secondProgress = SessionLearningProgressStore(
        secondStore,
        rules: restartedPlan.commitRules,
      );
      await secondProgress.commit(
        _event(day: restartedPlan.learningDay, index: 1, nodeIndex: 0),
      );
      await secondProgress.commit(
        _event(day: restartedPlan.learningDay, index: 2, nodeIndex: 1),
      );
      final completed = await secondProgress.snapshot(LearningScope.personal);
      final daily = completed.quests.singleWhere(
        (quest) =>
            quest.questInstanceId ==
            restartedPlan.dailyDefinition.questInstanceId,
      );

      expect(
        _definitionSignature(restartedPlan.dailyDefinition),
        _definitionSignature(initialPlan.dailyDefinition),
      );
      expect(daily.target, 2);
      expect(daily.progress, 2);
      expect(daily.completed, isTrue);
      await secondStore.close();
    });

    test('2件日は同じcleared nodeの周回を数えず、別meaningful nodeだけで完了する', () async {
      final now = _dayForTarget(planner, 2);
      final plan = planner.build(now: now, scope: LearningScope.personal);
      final store = MemorySessionStore();
      final progress = SessionLearningProgressStore(
        store,
        rules: plan.commitRules,
      );

      final first = await progress.commit(
        _event(day: plan.learningDay, index: 0, nodeIndex: 0),
      );
      final repeated = await progress.commit(
        _event(day: plan.learningDay, index: 1, nodeIndex: 0),
      );
      var snapshot = await progress.snapshot(LearningScope.personal);
      var daily = snapshot.quests.singleWhere(
        (quest) =>
            quest.questInstanceId == plan.dailyDefinition.questInstanceId,
      );

      expect(first.event.meaningfulProgress, isTrue);
      expect(repeated.event.meaningfulProgress, isFalse);
      expect(daily.progress, 1);
      expect(daily.completed, isFalse);

      final secondNode = await progress.commit(
        _event(day: plan.learningDay, index: 2, nodeIndex: 1),
      );
      snapshot = await progress.snapshot(LearningScope.personal);
      daily = snapshot.quests.singleWhere(
        (quest) =>
            quest.questInstanceId == plan.dailyDefinition.questInstanceId,
      );
      expect(secondNode.event.meaningfulProgress, isTrue);
      expect(daily.progress, 2);
      expect(daily.completed, isTrue);
      expect(snapshot.wallet.gems, 1);
    });

    test('daily 1/2件とmonthly 12件は同じmeaningful台帳で併存する', () async {
      final now = _dayForTarget(planner, 2);
      final plan = planner.build(now: now, scope: LearningScope.personal);
      final progress = SessionLearningProgressStore(
        MemorySessionStore(),
        rules: plan.commitRules,
      );

      for (var index = 0; index < 12; index++) {
        await progress.commit(
          _event(day: plan.learningDay, index: index, nodeIndex: index),
        );
      }
      final snapshot = await progress.snapshot(LearningScope.personal);
      final daily = snapshot.quests.singleWhere(
        (quest) =>
            quest.questInstanceId == plan.dailyDefinition.questInstanceId,
      );
      final monthly = snapshot.quests.singleWhere(
        (quest) => quest.questInstanceId.startsWith('monthly:'),
      );

      expect(daily.progress, 2);
      expect(daily.completed, isTrue);
      expect(monthly.progress, 12);
      expect(monthly.completed, isTrue);
      expect(snapshot.wallet.gems, 9);
    });

    test('school eventは報酬を作らず、projection上の端末授業目標だけを進める', () async {
      final now = DateTime(2026, 8, 10, 12);
      final plan = planner.build(now: now, scope: LearningScope.schoolLocal);
      final progress = SessionLearningProgressStore(
        MemorySessionStore(),
        rules: plan.commitRules,
      );
      await progress.commit(
        _event(
          day: plan.learningDay,
          index: 0,
          nodeIndex: 0,
          scope: LearningScope.schoolLocal,
          origin: LearningOrigin.schoolAssignment,
        ),
      );
      final snapshot = await progress.snapshot(LearningScope.schoolLocal);
      final game = const LearningGameProjection().build(
        catalog: const [],
        snapshot: snapshot,
        now: now,
        schoolMode: true,
        questTitles: plan.questTitles,
        activeQuestDefinitions: plan.activeQuestDefinitions,
      );

      expect(snapshot.rewards, isEmpty);
      expect(snapshot.quests, isEmpty);
      expect(snapshot.wallet.gems, 0);
      expect(game.quests, hasLength(1));
      expect(game.quests.single.title, LearningQuestPlannerV1.schoolDailyTitle);
      expect(game.quests.single.progress, 1);
      expect(game.quests.single.target, 1);
      expect(game.quests.single.gemReward, 0);
    });
  });
}

DateTime _dayForTarget(LearningQuestPlannerV1 planner, int target) {
  final base = DateTime(2026, 8, 10, 12);
  for (var offset = 0; offset < 2; offset++) {
    final candidate = base.add(Duration(days: offset));
    if (planner
            .build(now: candidate, scope: LearningScope.personal)
            .dailyDefinition
            .target ==
        target) {
      return candidate;
    }
  }
  throw StateError('daily target rotation did not contain $target');
}

LearningEventCommand _event({
  required String day,
  required int index,
  required int nodeIndex,
  LearningScope scope = LearningScope.personal,
  LearningOrigin origin = LearningOrigin.path,
}) => LearningEventCommand(
  eventId: 'quest:event-$index',
  scope: scope,
  origin: origin,
  courseId: 'science-ja-v1',
  nodeId: 'path:v1:quest:node-$nodeIndex',
  activityId: 'path.lesson.v1',
  skillIds: {'science/quest-$nodeIndex'},
  activityKind: LearningActivityKind.read,
  outcome: LearningAttemptOutcome.completed,
  evidence: LearningEvidenceLevel.selfCompared,
  contentVersion: 'catalog-v8',
  learningDay: day,
  occurredAt: dayStartOf(day).add(Duration(minutes: index)).toUtc(),
);

Object _definitionSignature(LearningQuestDefinition definition) => (
  definition.questInstanceId,
  definition.definitionVersion,
  definition.target,
  definition.rewardGems,
  definition.minimumEvidence,
);
