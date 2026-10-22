import 'dart:io';

import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/learning/domain/learning_progress.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

typedef _StoreFactory = Future<SessionStore> Function();

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  for (final entry in <String, _StoreFactory>{
    'Memory': () async => MemorySessionStore(),
    'SQLite': () => SqfliteSessionStore.open(path: inMemoryDatabasePath),
  }.entries) {
    group('${entry.key} 学校端末の学習リセット', () {
      late SessionStore store;

      setUp(() async => store = await entry.value());
      tearDown(() => store.close());

      test('学校台帳と授業再開だけを消し、再実行しても個人・旧会話・設定を保つ', () async {
        await _seed(store);
        await _expectSchoolPresent(store);

        await store.resetSchoolLearningData();
        await _expectSchoolCleared(store);
        await _expectPersonalPreserved(store);

        await store.resetSchoolLearningData();
        await _expectSchoolCleared(store);
        await _expectPersonalPreserved(store);

        // リセット後の新しい世代は通常どおり保存できる。
        await store.commitLearningEvent(
          _event('event.school.fresh', LearningScope.schoolLocal),
        );
        final fresh = await store.learningProgressSnapshot(
          LearningScope.schoolLocal,
        );
        expect(fresh.events.single.eventId, 'event.school.fresh');
      });

      test('既存のscope削除は授業再開の設定を削除しない', () async {
        await _seed(store);
        await store.clearLearningScope(LearningScope.schoolLocal);

        final school = await store.learningProgressSnapshot(
          LearningScope.schoolLocal,
        );
        expect(school.events, isEmpty);
        expect(await store.getSetting(kLocalClassroomRunSettingKey), 'resume');
        await _expectPersonalPreserved(store);
      });
    });
  }

  test('Memoryは学校台帳と授業再開を同じ同期区間で削除する', () async {
    final store = MemorySessionStore();
    addTearDown(store.close);
    await _seed(store);

    final reset = store.resetSchoolLearningData();
    final immediatelyReadSetting = store.getSetting(kLocalClassroomRunSettingKey);
    await reset;

    expect(await immediatelyReadSetting, isNull);
    await _expectSchoolCleared(store);
  });

  test('SQLiteは最後の設定削除に失敗すると学校台帳もrollbackし、再起動後に再試行できる', () async {
    final temp = Directory.systemTemp.createTempSync('school-reset-rollback');
    addTearDown(() => temp.deleteSync(recursive: true));
    final path = p.join(temp.path, 'school.db');
    await _withStore(path, _seed);
    await _withDatabase(path, (db) async {
      await db.execute('''
        CREATE TRIGGER fail_school_reset
        BEFORE DELETE ON settings
        WHEN OLD.key = 'local_classroom_run_v1'
        BEGIN
          SELECT RAISE(ABORT, 'forced school reset failure');
        END
      ''');
    });

    await _withStore(path, (store) async {
      await expectLater(
        store.resetSchoolLearningData(),
        throwsA(isA<DatabaseException>()),
      );
      await _expectSchoolPresent(store);
      await _expectPersonalPreserved(store);
      // event本体だけでなくskill・needの子行も戻っているため再送が一致する。
      final replay = await store.commitLearningEvent(
        _event('event.schoolLocal.retry', LearningScope.schoolLocal, retry: true),
      );
      expect(replay.inserted, isFalse);
    });

    // transactionの取り消しは同じ接続の読み取りだけでなく再起動後も残る。
    await _withStore(path, (store) async {
      await _expectSchoolPresent(store);
      await _expectPersonalPreserved(store);
    });
    await _withDatabase(path, (db) => db.execute('DROP TRIGGER fail_school_reset'));
    await _withStore(path, (store) async {
      await store.resetSchoolLearningData();
      await _expectSchoolCleared(store);
      await _expectPersonalPreserved(store);
    });
    await _withStore(path, (store) async {
      await _expectSchoolCleared(store);
      await _expectPersonalPreserved(store);
    });
  });
}

Future<void> _seed(SessionStore store) async {
  await store.setSetting(kLocalClassroomRunSettingKey, 'resume');
  await store.setSetting('${kLocalClassroomRunSettingKey}_other', 'keep-neighbor');
  await store.setSetting('theme_mode', 'dark');
  await store.startSession('legacy-unit');
  for (final scope in LearningScope.values) {
    await store.commitLearningEvent(_event('event.${scope.wire}', scope));
    await store.commitLearningEvent(
      _event('event.${scope.wire}.retry', scope, retry: true),
    );
    await store.beginLearningRun(
      LearningRun(
        runId: 'run.${scope.wire}',
        scope: scope,
        nodeId: 'node.fall',
        activityIndex: 1,
        challengeHearts: null,
        contentVersion: 'catalog.v6',
        updatedAt: DateTime(2026, 8, 10, 13),
      ),
    );
  }
}

Future<void> _expectSchoolPresent(SessionStore store) async {
  final school = await store.learningProgressSnapshot(LearningScope.schoolLocal);
  expect(school.events, hasLength(2));
  expect(school.nodes.single.attemptCount, 2);
  expect(school.skills, hasLength(1));
  expect(school.days, hasLength(1));
  expect(school.activeNeeds, hasLength(1));
  expect(school.runs.single.runId, 'run.schoolLocal');
  expect(await store.getSetting(kLocalClassroomRunSettingKey), 'resume');
}

Future<void> _expectSchoolCleared(SessionStore store) async {
  final school = await store.learningProgressSnapshot(LearningScope.schoolLocal);
  expect(school.events, isEmpty);
  expect(school.nodes, isEmpty);
  expect(school.skills, isEmpty);
  expect(school.days, isEmpty);
  expect(school.activeNeeds, isEmpty);
  expect(school.runs, isEmpty);
  expect(school.rewards, isEmpty);
  expect(school.quests, isEmpty);
  expect(await store.getSetting(kLocalClassroomRunSettingKey), isNull);
}

Future<void> _expectPersonalPreserved(SessionStore store) async {
  final personal = await store.learningProgressSnapshot(LearningScope.personal);
  expect(personal.events, hasLength(2));
  expect(personal.nodes.single.attemptCount, 2);
  expect(personal.skills, hasLength(1));
  expect(personal.days, hasLength(1));
  expect(personal.activeNeeds, hasLength(1));
  expect(personal.runs.single.runId, 'run.personal');
  expect(personal.wallet.xp, 10);
  expect((await store.recentSessions()).single.unitId, 'legacy-unit');
  expect(await store.getSetting('theme_mode'), 'dark');
  expect(
    await store.getSetting('${kLocalClassroomRunSettingKey}_other'),
    'keep-neighbor',
  );
}

Future<void> _withStore(
  String path,
  Future<void> Function(SessionStore) action,
) async {
  final store = await SqfliteSessionStore.open(path: path);
  try {
    await action(store);
  } finally {
    await store.close();
  }
}

Future<void> _withDatabase(
  String path,
  Future<void> Function(Database) action,
) async {
  final db = await databaseFactory.openDatabase(path);
  try {
    await action(db);
  } finally {
    await db.close();
  }
}

LearningEventCommand _event(
  String id,
  LearningScope scope, {
  bool retry = false,
}) => LearningEventCommand(
  eventId: id,
  scope: scope,
  origin: scope == LearningScope.schoolLocal
      ? LearningOrigin.schoolAssignment
      : LearningOrigin.path,
  courseId: 'course.jhs-science',
  nodeId: 'node.fall',
  activityId: 'activity.fall.1',
  skillIds: const {'concept.fall'},
  activityKind: LearningActivityKind.singleSelect,
  outcome: retry
      ? LearningAttemptOutcome.retryNeeded
      : LearningAttemptOutcome.structuredSuccess,
  evidence: LearningEvidenceLevel.selfCompared,
  contentVersion: 'catalog.v6',
  learningDay: '2026-08-10',
  occurredAt: DateTime(2026, 8, 10, 12, retry ? 1 : 0),
  practiceNeedCodes: retry
      ? const {
          'concept.fall': {'condition.air-resistance'},
        }
      : const {},
);
