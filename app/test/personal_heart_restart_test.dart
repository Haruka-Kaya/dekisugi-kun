import 'dart:io';

import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/learning/domain/learning_progress.dart';
import 'package:dekisugi/models/day_key.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('SQLite再起動後も0heartと時間回復を保ち、学校runは無制限のまま', () async {
    final tmp = Directory.systemTemp.createTempSync('dekisugi-heart-restart-');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final path = p.join(tmp.path, 'learning.db');
    final base = DateTime.utc(2026, 8, 10, 9);

    final first = await SqfliteSessionStore.open(path: path);
    await first.beginLearningRun(
      LearningRun(
        runId: 'personal-heart-run',
        scope: LearningScope.personal,
        nodeId: 'path:v1:motion:fall:practice',
        activityIndex: 0,
        challengeHearts: 5,
        contentVersion: 'catalog-v6',
        updatedAt: base,
      ),
    );
    for (var index = 1; index <= 5; index++) {
      final occurredAt = base.add(Duration(minutes: index));
      await first.spendLearningChallengeHeart(
        'personal-heart-run',
        lossId: 'personal-heart-run:loss:$index:stable-task',
        activityIndex: index,
        learningDay: dayKeyOf(occurredAt),
        occurredAt: occurredAt,
      );
    }
    await first.beginLearningRun(
      LearningRun(
        runId: 'school-unlimited-run',
        scope: LearningScope.schoolLocal,
        nodeId: 'school:path:v1:motion:fall:practice',
        activityIndex: 0,
        challengeHearts: 5,
        contentVersion: 'catalog-v6',
        updatedAt: base,
      ),
    );
    await first.close();

    final second = await SqfliteSessionStore.open(path: path);
    var personal = await second.learningProgressSnapshot(
      LearningScope.personal,
    );
    var school = await second.learningProgressSnapshot(
      LearningScope.schoolLocal,
    );
    expect(personal.challengeHearts?.current, 0);
    expect(personal.runs.single.challengeHearts, 0);
    expect(personal.runs.single.activityIndex, 5);
    expect(school.challengeHearts, isNull);
    expect(school.runs.single.challengeHearts, isNull);

    final refreshed = await second.refreshLearningChallengeHearts(
      learningDay: dayKeyOf(base),
      occurredAt: base.add(const Duration(minutes: 35)),
    );
    expect(refreshed.recovered, 1);
    expect(refreshed.state.current, 1);
    await second.close();

    final third = await SqfliteSessionStore.open(path: path);
    personal = await third.learningProgressSnapshot(LearningScope.personal);
    school = await third.learningProgressSnapshot(LearningScope.schoolLocal);
    expect(personal.challengeHearts?.current, 1);
    expect(personal.runs.single.challengeHearts, 1);
    expect(school.challengeHearts, isNull);
    expect(school.runs.single.challengeHearts, isNull);
    await third.close();
  });
}
