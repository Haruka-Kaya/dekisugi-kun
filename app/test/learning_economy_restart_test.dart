import 'dart:io';

import 'package:dekisugi/learning/domain/learning_economy.dart';
import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/learning/domain/learning_policy.dart';
import 'package:dekisugi/models/day_key.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('SQLite再起動後もcosmetic所有・装備・Timed日次券を冪等に保つ', () async {
    final tmp = Directory.systemTemp.createTempSync('dekisugi-economy-');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final path = p.join(tmp.path, 'learning.db');
    final base = DateTime.utc(2026, 8, 10, 9);
    final day = dayKeyOf(base);

    final first = await SqfliteSessionStore.open(path: path);
    await first.commitLearningEvent(
      LearningEventCommand(
        eventId: 'restart.economy.reward',
        scope: LearningScope.personal,
        origin: LearningOrigin.path,
        courseId: 'science-ja-v1',
        nodeId: 'restart:economy:reward',
        activityId: 'restart.economy.reward',
        skillIds: const {'motion/fall'},
        activityKind: LearningActivityKind.read,
        outcome: LearningAttemptOutcome.completed,
        evidence: LearningEvidenceLevel.selfCompared,
        contentVersion: 'catalog-v7',
        learningDay: day,
        occurredAt: base,
      ),
      rules: LearningCommitRules(
        quests: [
          LearningQuestDefinition.daily(
            learningDay: day,
            questKey: 'restart-economy',
            definitionVersion: 'economy.restart.test.v1',
            target: 1,
            rewardGems: 10,
          ),
        ],
      ),
    );
    await first.purchaseLearningCosmeticWithGems(
      scope: LearningScope.personal,
      spendId: 'restart.spend.cosmetic.orbit',
      productId: SafeLearningEconomyCatalogV1.orbitMascotId,
      learningDay: day,
      occurredAt: base.add(const Duration(minutes: 1)),
    );
    await first.purchaseLearningChallengePassWithGems(
      scope: LearningScope.personal,
      spendId: 'restart.spend.timed.day',
      productId: SafeLearningEconomyCatalogV1.timedDayPassId,
      learningDay: day,
      occurredAt: base.add(const Duration(minutes: 2)),
    );
    await first.close();

    final second = await SqfliteSessionStore.open(path: path);
    var snapshot = await second.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(snapshot.wallet.gems, 5);
    expect(snapshot.gemSpends, hasLength(2));
    expect(
      snapshot.cosmetics?.ownedProductIds,
      contains(SafeLearningEconomyCatalogV1.orbitMascotId),
    );
    expect(
      snapshot.cosmetics?.equippedPathMascotId,
      SafeLearningEconomyCatalogV1.orbitMascotId,
    );
    expect(
      snapshot.hasChallengePass(
        productId: SafeLearningEconomyCatalogV1.timedDayPassId,
        learningDay: day,
      ),
      isTrue,
    );

    final replay = await second.purchaseLearningChallengePassWithGems(
      scope: LearningScope.personal,
      spendId: 'restart.spend.timed.day',
      productId: SafeLearningEconomyCatalogV1.timedDayPassId,
      learningDay: day,
      occurredAt: base.add(const Duration(minutes: 2)),
    );
    expect(replay.applied, isFalse);
    final sameDay = await second.purchaseLearningChallengePassWithGems(
      scope: LearningScope.personal,
      spendId: 'restart.spend.timed.day.other-request',
      productId: SafeLearningEconomyCatalogV1.timedDayPassId,
      learningDay: day,
      occurredAt: base.add(const Duration(minutes: 3)),
    );
    expect(sameDay.applied, isFalse);
    await second.equipLearningCosmetic(
      scope: LearningScope.personal,
      productId: SafeLearningEconomyCatalogV1.standardMascotId,
      occurredAt: base.add(const Duration(minutes: 4)),
    );
    await second.close();

    final third = await SqfliteSessionStore.open(path: path);
    snapshot = await third.learningProgressSnapshot(LearningScope.personal);
    expect(snapshot.wallet.gems, 5);
    expect(snapshot.gemSpends, hasLength(2));
    expect(
      snapshot.cosmetics?.equippedPathMascotId,
      SafeLearningEconomyCatalogV1.standardMascotId,
    );
    expect(
      snapshot.cosmetics?.ownedProductIds,
      contains(SafeLearningEconomyCatalogV1.orbitMascotId),
    );
    await third.close();
  });
}
