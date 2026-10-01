import 'dart:io';

import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('learning ledger v14 migration', () {
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('dekisugi_learning'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('v6の会話・復習・設定を保ったままv14へ上げる', () async {
      final path = await _makeV6(p.join(tmp.path, 'from-v6.db'));
      final store = await SqfliteSessionStore.open(path: path);
      addTearDown(store.close);

      expect(await store.getSetting('device_id'), 'legacy-device');
      expect((await store.reviewItems()).single.label, '落下の速さ');
      expect(await store.progressFor('force-motion', 'fall'), isNotNull);

      await store.commitLearningEvent(_personalEvent('event.after-upgrade'));
      final snapshot = await store.learningProgressSnapshot(
        LearningScope.personal,
      );
      expect(snapshot.events, hasLength(1));
      expect(snapshot.wallet.xp, 10);
    });

    test('新規DBはv14全表を持ち回答・音声・選択内容の列を持たない', () async {
      final path = p.join(tmp.path, 'fresh.db');
      final store = await SqfliteSessionStore.open(path: path);
      await store.close();

      final db = await databaseFactory.openDatabase(path);
      addTearDown(db.close);
      expect(await db.getVersion(), 14);

      final tables = (await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'learning_%'",
      )).map((row) => row['name'] as String).toSet();
      expect(
        tables,
        containsAll({
          'learning_events',
          'learning_event_skills',
          'learning_practice_needs',
          'learning_need_state',
          'learning_node_progress',
          'learning_skill_progress',
          'learning_days',
          'learning_reward_ledger',
          'learning_quest_progress',
          'learning_quest_events',
          'learning_freezes',
          'learning_challenge_heart_state',
          'learning_challenge_heart_losses',
          'learning_challenge_heart_practice_recoveries',
          'learning_runs',
          'learning_gem_spends',
          'learning_cosmetic_loadout',
          'learning_cosmetic_grants',
          'learning_local_coop_runs',
          'learning_local_coop_participants',
          'learning_local_coop_contributions',
          'learning_league_history',
          'learning_local_league_history',
        }),
      );

      final forbidden = RegExp(
        r'(answer|response|transcript|audio|voice|selection|free_text)',
        caseSensitive: false,
      );
      for (final table in tables) {
        final columns = await db.rawQuery('PRAGMA table_info($table)');
        expect(
          columns.map((column) => column['name']).whereType<String>(),
          everyElement(isNot(matches(forbidden))),
          reason: '$table must not gain a raw response column',
        );
      }

      final needColumns = (await db.rawQuery(
        'PRAGMA table_info(learning_practice_needs)',
      )).map((column) => column['name']).toSet();
      expect(needColumns, contains('resolved'));
      final spendColumns = (await db.rawQuery(
        'PRAGMA table_info(learning_gem_spends)',
      )).map((column) => column['name']).toSet();
      expect(spendColumns, contains('reference_id'));
      final economyIndexes = (await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' "
        "AND name LIKE 'learning_gem_%'",
      )).map((row) => row['name']).toSet();
      expect(
        economyIndexes,
        containsAll({
          'learning_gem_cosmetic_product_idx',
          'learning_gem_challenge_day_idx',
        }),
      );
    });

    test('v11の既存spendを保持して固定reference列と初期loadoutを追加する', () async {
      final path = p.join(tmp.path, 'from-v11.db');
      final store = await SqfliteSessionStore.open(path: path);
      await store.close();
      final db = await databaseFactory.openDatabase(path);
      await db.execute('DROP TABLE learning_local_league_history');
      await db.execute('DROP TABLE learning_cosmetic_loadout');
      await db.execute('DROP TABLE learning_cosmetic_grants');
      await db.execute('DROP TABLE learning_gem_spends');
      await db.execute('''
        CREATE TABLE learning_gem_spends(
          spend_id TEXT PRIMARY KEY,
          scope TEXT NOT NULL CHECK(scope = 'personal'),
          spend_kind TEXT NOT NULL CHECK(spend_kind IN (
            'streakFreezeRefill', 'challengeHeartRecovery'
          )),
          amount INTEGER NOT NULL CHECK(amount > 0),
          learning_day TEXT NOT NULL,
          week_key TEXT,
          occurred_at INTEGER NOT NULL,
          CHECK(
            (spend_kind = 'streakFreezeRefill' AND week_key IS NOT NULL) OR
            (spend_kind = 'challengeHeartRecovery' AND week_key IS NULL)
          )
        )
      ''');
      await db.insert('learning_reward_ledger', {
        'entry_id': 'legacy-gems',
        'scope': 'personal',
        'reward_type': 'gems',
        'amount': 5,
        'reason': 'legacy-test',
        'source_event_id': null,
        'created_at': 1,
      });
      await db.insert('learning_gem_spends', {
        'spend_id': 'legacy-heart-spend',
        'scope': 'personal',
        'spend_kind': 'challengeHeartRecovery',
        'amount': 2,
        'learning_day': '2026-08-09',
        'week_key': null,
        'occurred_at': 2,
      });
      await db.setVersion(11);
      await db.close();

      final upgraded = await SqfliteSessionStore.open(path: path);
      addTearDown(upgraded.close);
      final snapshot = await upgraded.learningProgressSnapshot(
        LearningScope.personal,
      );
      expect(snapshot.wallet.gems, 3);
      expect(snapshot.gemSpends.single.referenceId, isNull);
      expect(snapshot.gemSpends.single.kind.wire, 'challengeHeartRecovery');
      expect(
        snapshot.cosmetics?.equippedPathMascotId,
        'cosmetic.path-mascot.standard.v1',
      );
    });

    test('v9の固定needを推測解消せずactive stateへ移す', () async {
      final path = p.join(tmp.path, 'from-v9.db');
      final store = await SqfliteSessionStore.open(path: path);
      await store.close();
      final db = await databaseFactory.openDatabase(path);
      await db.execute('DROP TABLE learning_local_league_history');
      await db.execute('DROP TABLE learning_need_state');
      await db.execute('DROP TABLE learning_cosmetic_loadout');
      await db.execute('DROP TABLE learning_cosmetic_grants');
      await db.execute(
        'DROP TABLE learning_challenge_heart_practice_recoveries',
      );
      await db.execute(
        'ALTER TABLE learning_practice_needs DROP COLUMN resolved',
      );
      await db.setVersion(9);
      await db.insert('learning_events', {
        'id': 'event.v9.need',
        'scope': 'personal',
        'origin': 'challenge',
        'course_id': 'course.jhs-science',
        'node_id': 'node.unit.legendary',
        'activity_id': 'activity.unit.legendary',
        'activity_kind': 'transfer',
        'outcome': 'retryNeeded',
        'evidence_rank': 0,
        'content_version': 'catalog.v5',
        'learning_day': '2026-08-09',
        'occurred_at': DateTime(2026, 8, 9, 12).millisecondsSinceEpoch,
        'run_id': null,
        'source_session_id': null,
        'reward_eligible': 0,
        'meaningful_progress': 0,
      });
      await db.insert('learning_event_skills', {
        'event_id': 'event.v9.need',
        'skill_id': 'unit.legendary.synthetic',
      });
      await db.insert('learning_practice_needs', {
        'event_id': 'event.v9.need',
        'skill_id': 'force-motion/fall',
        'need_code': 'science.fall.foundation',
      });
      await db.close();

      final upgraded = await SqfliteSessionStore.open(path: path);
      addTearDown(upgraded.close);
      final snapshot = await upgraded.learningProgressSnapshot(
        LearningScope.personal,
      );
      expect(snapshot.activeNeeds, hasLength(1));
      expect(snapshot.activeNeeds.single.skillId, 'force-motion/fall');
      expect(snapshot.activeNeeds.single.needCode, 'science.fall.foundation');
      expect(snapshot.activeNeeds.single.firstObservedDay, '2026-08-09');
    });

    test('v7 runのheartをv9共有stateへ移し学校runは無制限へ正規化する', () async {
      final path = p.join(tmp.path, 'from-v7.db');
      final store = await SqfliteSessionStore.open(path: path);
      await store.close();
      final db = await databaseFactory.openDatabase(path);
      await db.execute('DROP TABLE learning_local_league_history');
      await db.execute('DROP TABLE learning_league_history');
      await db.execute('DROP TABLE learning_local_coop_contributions');
      await db.execute('DROP TABLE learning_local_coop_participants');
      await db.execute('DROP TABLE learning_local_coop_runs');
      await db.execute('DROP TABLE learning_gem_spends');
      await db.execute('DROP TABLE learning_cosmetic_loadout');
      await db.execute('DROP TABLE learning_cosmetic_grants');
      await db.execute(
        'DROP TABLE learning_challenge_heart_practice_recoveries',
      );
      await db.execute('DROP TABLE learning_need_state');
      await db.execute(
        'ALTER TABLE learning_practice_needs DROP COLUMN resolved',
      );
      await db.execute(
        'ALTER TABLE learning_events DROP COLUMN meaningful_progress',
      );
      await db.execute('DROP TABLE learning_challenge_heart_losses');
      await db.execute('DROP TABLE learning_challenge_heart_state');
      await db.setVersion(7);
      await db.insert('learning_runs', {
        'run_id': 'run.personal.v7',
        'scope': 'personal',
        'node_id': 'node.legendary',
        'activity_index': 1,
        'challenge_hearts': 3,
        'content_version': 'catalog.v5',
        'updated_at': 100,
      });
      await db.insert('learning_runs', {
        'run_id': 'run.school.v7',
        'scope': 'schoolLocal',
        'node_id': 'node.school.legendary',
        'activity_index': 0,
        'challenge_hearts': 5,
        'content_version': 'catalog.v5',
        'updated_at': 200,
      });
      await db.close();

      final upgraded = await SqfliteSessionStore.open(path: path);
      addTearDown(upgraded.close);
      final personal = await upgraded.learningProgressSnapshot(
        LearningScope.personal,
      );
      final school = await upgraded.learningProgressSnapshot(
        LearningScope.schoolLocal,
      );
      expect(personal.challengeHearts?.current, 3);
      expect(personal.runs.single.challengeHearts, 3);
      expect(school.challengeHearts, isNull);
      expect(school.runs.single.challengeHearts, isNull);
    });

    test('v8 eventはmeaningfulと推測せずfalseでv9へ移す', () async {
      final path = p.join(tmp.path, 'from-v8.db');
      final store = await SqfliteSessionStore.open(path: path);
      await store.close();
      final db = await databaseFactory.openDatabase(path);
      await db.execute('DROP TABLE learning_local_league_history');
      await db.execute('DROP TABLE learning_league_history');
      await db.execute('DROP TABLE learning_local_coop_contributions');
      await db.execute('DROP TABLE learning_local_coop_participants');
      await db.execute('DROP TABLE learning_local_coop_runs');
      await db.execute('DROP TABLE learning_gem_spends');
      await db.execute('DROP TABLE learning_cosmetic_loadout');
      await db.execute('DROP TABLE learning_cosmetic_grants');
      await db.execute(
        'DROP TABLE learning_challenge_heart_practice_recoveries',
      );
      await db.execute('DROP TABLE learning_need_state');
      await db.execute(
        'ALTER TABLE learning_practice_needs DROP COLUMN resolved',
      );
      await db.execute(
        'ALTER TABLE learning_events DROP COLUMN meaningful_progress',
      );
      await db.execute('''
        CREATE UNIQUE INDEX learning_freezes_week_idx
        ON learning_freezes(scope, week_key)
      ''');
      await db.setVersion(8);
      await db.insert('learning_events', {
        'id': 'event.v8.legacy',
        'scope': 'personal',
        'origin': 'path',
        'course_id': 'course.jhs-science',
        'node_id': 'node.v8',
        'activity_id': 'activity.v8',
        'activity_kind': 'singleSelect',
        'outcome': 'structuredSuccess',
        'evidence_rank': 1,
        'content_version': 'catalog.v5',
        'learning_day': '2026-08-09',
        'occurred_at': DateTime(2026, 8, 9, 12).millisecondsSinceEpoch,
        'run_id': null,
        'source_session_id': null,
        'reward_eligible': 1,
      });
      await db.close();

      final upgraded = await SqfliteSessionStore.open(path: path);
      addTearDown(upgraded.close);
      final snapshot = await upgraded.learningProgressSnapshot(
        LearningScope.personal,
      );
      expect(snapshot.events.single.meaningfulProgress, isFalse);
      expect(snapshot.wallet.gems, 0);
      expect(snapshot.localCoopRuns, isEmpty);
      expect(snapshot.leagueHistory, isEmpty);
    });

    test('SQLへ直接school rewardを入れても制約が拒否する', () async {
      final path = p.join(tmp.path, 'school-constraint.db');
      final store = await SqfliteSessionStore.open(path: path);
      await store.close();
      final db = await databaseFactory.openDatabase(path);
      addTearDown(db.close);

      await expectLater(
        db.insert('learning_reward_ledger', {
          'entry_id': 'bad-school-reward',
          'scope': 'schoolLocal',
          'reward_type': 'xp',
          'amount': 10,
          'reason': 'must-fail',
          'source_event_id': null,
          'created_at': 1,
        }),
        throwsA(anything),
      );
      expect(await db.query('learning_reward_ledger'), isEmpty);

      await expectLater(
        db.insert('learning_gem_spends', {
          'spend_id': 'bad-school-spend',
          'scope': 'schoolLocal',
          'spend_kind': 'challengeHeartRecovery',
          'amount': 2,
          'learning_day': '2026-08-10',
          'week_key': null,
          'occurred_at': 1,
        }),
        throwsA(anything),
      );
      expect(await db.query('learning_gem_spends'), isEmpty);
    });
  });
}

LearningEventCommand _personalEvent(String id) => LearningEventCommand(
  eventId: id,
  scope: LearningScope.personal,
  origin: LearningOrigin.path,
  courseId: 'course.jhs-science',
  nodeId: 'node.fall',
  activityId: 'activity.fall.1',
  skillIds: const {'concept.fall'},
  activityKind: LearningActivityKind.singleSelect,
  outcome: LearningAttemptOutcome.structuredSuccess,
  evidence: LearningEvidenceLevel.selfCompared,
  contentVersion: 'catalog.v5',
  learningDay: '2026-08-10',
  occurredAt: DateTime(2026, 8, 10, 12),
);

Future<String> _makeV6(String path) async {
  final db = await databaseFactory.openDatabase(
    path,
    options: OpenDatabaseOptions(version: 6),
  );
  await db.execute('''
    CREATE TABLE sessions(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      unit_id TEXT NOT NULL,
      started_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      ended_at INTEGER,
      dossier TEXT,
      transcript TEXT NOT NULL DEFAULT '[]',
      focus_concept_key TEXT,
      teaching_tactic TEXT,
      mission_kind TEXT NOT NULL DEFAULT 'teach',
      completion_applied INTEGER NOT NULL DEFAULT 0
    )''');
  await db.execute('''
    CREATE TABLE reviews(
      unit_id TEXT NOT NULL,
      concept_key TEXT NOT NULL,
      label TEXT NOT NULL,
      reason TEXT NOT NULL,
      last_seen INTEGER NOT NULL,
      times_seen INTEGER NOT NULL DEFAULT 0,
      last_reviewed_at INTEGER,
      PRIMARY KEY(unit_id, concept_key)
    )''');
  await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)');
  await db.execute('''
    CREATE TABLE days(
      day TEXT PRIMARY KEY,
      sessions INTEGER NOT NULL DEFAULT 0,
      done INTEGER NOT NULL DEFAULT 0,
      text_turns INTEGER NOT NULL DEFAULT 0
    )''');
  await db.execute('''
    CREATE TABLE explained(
      unit_id TEXT NOT NULL,
      concept_key TEXT NOT NULL,
      label TEXT NOT NULL,
      said TEXT NOT NULL,
      at INTEGER NOT NULL,
      PRIMARY KEY(unit_id, concept_key)
    )''');
  await db.execute('''
    CREATE TABLE concept_progress(
      unit_id TEXT NOT NULL,
      concept_key TEXT NOT NULL,
      last_outcome TEXT NOT NULL,
      successful_retrievals INTEGER NOT NULL DEFAULT 0,
      last_attempt_day TEXT NOT NULL,
      last_success_day TEXT,
      next_due_day TEXT NOT NULL,
      source_session_id INTEGER,
      PRIMARY KEY(unit_id, concept_key)
    )''');
  await db.insert('settings', {'key': 'device_id', 'value': 'legacy-device'});
  await db.insert('reviews', {
    'unit_id': 'force-motion',
    'concept_key': 'fall',
    'label': '落下の速さ',
    'reason': 'notCorrected',
    'last_seen': DateTime(2026, 8, 1).millisecondsSinceEpoch,
  });
  await db.insert('concept_progress', {
    'unit_id': 'force-motion',
    'concept_key': 'fall',
    'last_outcome': 'rematchNeeded',
    'successful_retrievals': 0,
    'last_attempt_day': '2026-08-01',
    'last_success_day': null,
    'next_due_day': '2026-08-01',
    'source_session_id': null,
  });
  await db.close();
  return path;
}
