import 'dart:io';

import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/learning/services/learning_progress_store.dart';
import 'package:dekisugi/learning/services/learning_quest_plan_v2.dart';
import 'package:dekisugi/models/day_key.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('SQLite再起動後も0件definitionと同日variantを保ち再送はno-op', () async {
    final temp = Directory.systemTemp.createTempSync('quest-materialize-');
    SqfliteSessionStore? openStore;
    addTearDown(() async {
      await openStore?.close();
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    final databasePath = p.join(temp.path, 'learning.db');
    const planner = LearningQuestPlannerV2();
    final initialPlan = planner.build(
      now: DateTime(2026, 8, 10, 12),
      audience: LearningQuestAudience.personalLocalOnly,
      availableVariants: const {LearningDailyQuestVariant.listening},
    );

    openStore = await SqfliteSessionStore.open(path: databasePath);
    var learning = SessionLearningProgressStore(openStore);
    final first = await learning.materializeQuestDefinitions(
      scope: LearningScope.personal,
      definitions: initialPlan.definitionsToMaterialize,
    );
    expect(first.insertedCount, 2);
    expect(first.quests.map((quest) => quest.progress), everyElement(0));
    expect(first.quests.map((quest) => quest.rewardedAt), everyElement(isNull));
    await openStore.close();
    openStore = null;

    openStore = await SqfliteSessionStore.open(path: databasePath);
    learning = SessionLearningProgressStore(openStore);
    var snapshot = await learning.snapshot(LearningScope.personal);
    expect(snapshot.quests, hasLength(2));
    expect(snapshot.quests.map((quest) => quest.progress), everyElement(0));
    expect(snapshot.rewards, isEmpty);
    expect(snapshot.wallet.gems, 0);

    final restoredPlan = planner.build(
      now: DateTime(2026, 8, 10, 23),
      audience: LearningQuestAudience.personalLocalOnly,
      availableVariants: const {LearningDailyQuestVariant.notation},
      persistedQuests: snapshot.quests,
    );
    expect(restoredPlan.definitionsToMaterialize, isEmpty);
    expect(
      restoredPlan.dailyDefinition.questInstanceId,
      initialPlan.dailyDefinition.questInstanceId,
    );

    final replay = await learning.materializeQuestDefinitions(
      scope: LearningScope.personal,
      definitions: initialPlan.definitionsToMaterialize,
    );
    expect(replay.insertedCount, 0);
    expect(replay.changed, isFalse);

    learning = SessionLearningProgressStore(
      openStore,
      rules: restoredPlan.commitRules,
    );
    final event = LearningEventCommand(
      eventId: 'quest.materialize.restart.listen',
      scope: LearningScope.personal,
      origin: LearningOrigin.practice,
      courseId: 'course.jhs-science',
      nodeId: 'node.quest.materialize.restart.listen',
      activityId: 'activity.quest.materialize.restart.listen',
      skillIds: const {'science/listening'},
      activityKind: LearningActivityKind.listen,
      outcome: LearningAttemptOutcome.structuredSuccess,
      evidence: LearningEvidenceLevel.selfCompared,
      contentVersion: 'catalog.v9',
      learningDay: initialPlan.learningDay,
      occurredAt: dayStartOf(
        initialPlan.learningDay,
      ).add(const Duration(hours: 5)),
    );
    final committed = await learning.commit(event);
    final eventReplay = await learning.commit(event);
    snapshot = await learning.snapshot(LearningScope.personal);
    final daily = snapshot.quests.singleWhere(
      (quest) =>
          quest.questInstanceId == initialPlan.dailyDefinition.questInstanceId,
    );
    final monthly = snapshot.quests.singleWhere(
      (quest) => quest.questInstanceId.startsWith('monthly:'),
    );
    expect(committed.inserted, isTrue);
    expect(eventReplay.inserted, isFalse);
    expect(daily.progress, 1);
    expect(daily.rewardedAt, isNotNull);
    expect(monthly.progress, 1);
    expect(monthly.rewardedAt, isNull);
    expect(snapshot.wallet.gems, 1);
  });
}
