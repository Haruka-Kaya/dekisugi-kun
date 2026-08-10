import 'dart:io';

import 'package:dekisugi/models/concept_progress.dart';
import 'package:dekisugi/models/dossier.dart';
import 'package:dekisugi/models/mission.dart';
import 'package:dekisugi/models/review.dart';
import 'package:dekisugi/models/streak.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/session_store_contract.dart';

/// sqflite の**実体**を相手にする。
///
/// これまで `SessionStore` のテストはメモリ版しか触っておらず、
/// `SqfliteSessionStore` は1行も通っていなかった。
/// スキーマの変更は実体で確かめないと、実機で初めて壊れる。
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // メモリ版と実体に、同じ契約を流す
  runSessionStoreContract('メモリ', () async => MemorySessionStore());
  runSessionStoreContract(
    'sqflite',
    () async => SqfliteSessionStore.open(path: inMemoryDatabasePath),
  );

  group('スキーマの更新', () {
    late Directory tmp;

    setUp(() => tmp = Directory.systemTemp.createTempSync('dekisugi_mig'));
    tearDown(() => tmp.deleteSync(recursive: true));

    /// v1 のころの DB を手で作る。**当時のスキーマをここに固定する**
    /// （`_migrations[0]` を後から書き換えたら、このテストが落ちる）。
    ///
    /// `:memory:` は開くたびに別物になるので**使えない**。
    /// 更新を試すには、閉じても残るファイルが要る。
    Future<String> makeV1({required bool withRow}) async {
      final path = p.join(tmp.path, 'dekisugi.db');
      final db = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(version: 1),
      );
      await db.execute('''
        CREATE TABLE sessions(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          unit_id TEXT NOT NULL,
          started_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          ended_at INTEGER,
          dossier TEXT,
          transcript TEXT NOT NULL DEFAULT '[]'
        )''');
      await db.execute('''
        CREATE TABLE reviews(
          unit_id TEXT NOT NULL,
          concept_key TEXT NOT NULL,
          label TEXT NOT NULL,
          reason TEXT NOT NULL,
          last_seen INTEGER NOT NULL,
          PRIMARY KEY(unit_id, concept_key)
        )''');
      await db.execute(
        'CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)',
      );
      if (withRow) {
        await db.insert('sessions', {
          'unit_id': 'force-motion',
          'started_at': DateTime(2026, 7, 1).millisecondsSinceEpoch,
          'updated_at': DateTime(2026, 7, 1).millisecondsSinceEpoch,
          'transcript': '[{"id":"old","speaker":"student","text":"昔の会話"}]',
        });
        await db.insert('reviews', {
          'unit_id': 'force-motion',
          'concept_key': 'fall',
          'label': '落下の速さ',
          'reason': 'notCorrected',
          'last_seen': DateTime(2026, 7, 1).millisecondsSinceEpoch,
        });
        await db.insert('settings', {'key': 'device_id', 'value': 'abc'});
      }
      // **閉じないと同じ in-memory を開き直せない**
      await db.close();
      return path;
    }

    /// Mission Path導入直前（v5）のDB。reviewを優先しつつ、reviewの無い
    /// explainedだけを翌日のretentionへ移せることを固定する。
    Future<String> makeV5() async {
      final path = p.join(tmp.path, 'v5.db');
      final db = await databaseFactory.openDatabase(
        path,
        options: OpenDatabaseOptions(version: 5),
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
          teaching_tactic TEXT
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
      await db.execute(
        'CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)',
      );
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
      await db.insert('sessions', {
        'unit_id': 'force-motion',
        'focus_concept_key': 'fall',
        'teaching_tactic': 'reason',
        'started_at': DateTime(2026, 8, 5).millisecondsSinceEpoch,
        'updated_at': DateTime(2026, 8, 5).millisecondsSinceEpoch,
        'transcript': '[{"id":"old","speaker":"student","text":"説明"}]',
      });
      await db.insert('reviews', {
        'unit_id': 'force-motion',
        'concept_key': 'fall',
        'label': '落下の速さ',
        'reason': 'notCorrected',
        // 午前4時境界より前なので8/6の学習。
        'last_seen': DateTime(2026, 8, 7, 3, 30).millisecondsSinceEpoch,
        'times_seen': 2,
      });
      // 過去に説明済みでも、より新しいreviewがあればrematchを優先する。
      await db.insert('explained', {
        'unit_id': 'force-motion',
        'concept_key': 'fall',
        'label': '落下の速さ',
        'said': '古い成功',
        'at': DateTime(2026, 8, 1, 12).millisecondsSinceEpoch,
      });
      await db.insert('explained', {
        'unit_id': 'force-motion',
        'concept_key': 'inertia',
        'label': '慣性',
        'said': '力がなくても運動を続ける',
        'at': DateTime(2026, 8, 8, 12).millisecondsSinceEpoch,
      });
      await db.close();
      return path;
    }

    test('v1 の記録を消さずに更新する', () async {
      final path = await makeV1(withRow: true);
      final store = await SqfliteSessionStore.open(path: path);
      addTearDown(store.close);

      final items = await store.reviewItems();
      expect(items, hasLength(1), reason: '更新で復習の記録が消えた');
      expect(items.first.label, '落下の速さ');
      expect(items.first.timesSeen, 0, reason: '既存行は既定値で埋まるべき');
      expect(items.first.lastReviewedAt, isNull);

      final oldSession = await store.unfinished(unitId: 'force-motion');
      expect(oldSession?.transcript.single.text, '昔の会話');
      expect(oldSession?.focusConceptKey, isNull, reason: '既存行は単元全体会話として残す');
      expect(oldSession?.tactic, isNull, reason: '既存行へ説明の足場を捏造してはいけない');

      // 端末IDが消えると、生徒から見て別人になる（枠も同意も引き継がれない）
      expect(await store.getSetting('device_id'), 'abc');

      final progress = await store.progressFor('force-motion', 'fall');
      expect(progress?.lastOutcome, ConceptOutcome.rematchNeeded);
      expect(progress?.nextMissionKind, MissionKind.repair);
    });

    test('v5のreviewとexplainedをMission Pathへ損失なく移す', () async {
      final path = await makeV5();
      final store = await SqfliteSessionStore.open(path: path);
      addTearDown(store.close);

      final fall = await store.progressFor('force-motion', 'fall');
      expect(fall?.lastOutcome, ConceptOutcome.rematchNeeded);
      expect(fall?.lastAttemptDay, '2026-08-06');
      expect(fall?.lastSuccessDay, isNull);
      expect(fall?.nextDueDay, '2026-08-06');
      expect(fall?.sourceSessionId, isNull);

      final inertia = await store.progressFor('force-motion', 'inertia');
      expect(inertia?.lastOutcome, ConceptOutcome.learned);
      expect(inertia?.lastAttemptDay, '2026-08-08');
      expect(inertia?.lastSuccessDay, '2026-08-08');
      expect(inertia?.nextDueDay, '2026-08-09');
      expect(inertia?.nextMissionKind, MissionKind.caseRetry);

      final oldSession = await store.unfinished(
        unitId: 'force-motion',
        focusConceptKey: 'fall',
        missionKind: MissionKind.teach,
      );
      expect(oldSession?.missionKind, MissionKind.teach);
      expect(await store.conceptProgress(), hasLength(2));
    });

    test('更新した DB でも見直し回数が動く', () async {
      final path = await makeV1(withRow: true);
      final store = await SqfliteSessionStore.open(path: path);
      addTearDown(store.close);

      await store.markReviewed('force-motion', 'fall');
      expect((await store.reviewItems()).first.timesSeen, 1);
    });

    test('空の DB は最初から最新のスキーマになる', () async {
      // 新規インストールと更新でスキーマがずれると、
      // 片方でしか出ない不具合になる
      final store = await SqfliteSessionStore.open(
        path: p.join(tmp.path, 'new.db'),
      );
      addTearDown(store.close);

      await store.upsertReviews([
        ReviewItem(
          unitId: 'force-motion',
          conceptKey: 'fall',
          label: '落下の速さ',
          reason: ReviewReason.notCorrected,
          lastSeen: DateTime(2026, 8, 1),
        ),
      ]);
      await store.markReviewed('force-motion', 'fall');
      expect((await store.reviewItems()).first.timesSeen, 1);
    });

    test('最新スキーマはv13でも概念複合PKと完了冪等列を保つ', () async {
      final path = p.join(tmp.path, 'schema-v13.db');
      final store = await SqfliteSessionStore.open(path: path);
      await store.close();

      final db = await databaseFactory.openDatabase(path);
      addTearDown(db.close);
      expect(await db.getVersion(), 13);

      final progressColumns = await db.rawQuery(
        'PRAGMA table_info(concept_progress)',
      );
      final byName = {
        for (final column in progressColumns) column['name'] as String: column,
      };
      expect(
        byName.keys,
        containsAll(<String>{
          'unit_id',
          'concept_key',
          'last_outcome',
          'successful_retrievals',
          'last_attempt_day',
          'last_success_day',
          'next_due_day',
          'source_session_id',
        }),
      );
      expect(byName['unit_id']?['pk'], 1);
      expect(byName['concept_key']?['pk'], 2);

      final sessionColumns = await db.rawQuery('PRAGMA table_info(sessions)');
      expect(
        sessionColumns.map((column) => column['name']),
        containsAll(['mission_kind', 'completion_applied']),
      );
    });

    test('v1 から更新しても日ごとの記録が使える', () async {
      // v3 で足した表は `onUpgrade` でしか作られない。
      // ここが抜けると「新規インストールでは動くが、更新した端末では落ちる」
      final path = await makeV1(withRow: true);
      final store = await SqfliteSessionStore.open(path: path);
      addTearDown(store.close);

      await store.recordActivity('2026-08-06', done: 1);
      expect((await store.days()).single.done, 1);
    });

    test('v1 から更新しても「言えるようになったこと」が使える', () async {
      // v4 で足した表も onUpgrade でしか作られない
      final path = await makeV1(withRow: true);
      final store = await SqfliteSessionStore.open(path: path);
      addTearDown(store.close);

      await store.recordExplained(
        ExplainedItem(
          unitId: 'force-motion',
          conceptKey: 'fall',
          label: '落下の速さ',
          said: '重さによらない',
          at: DateTime(2026, 8, 6),
        ),
      );
      expect((await store.explained()).single.said, '重さによらない');
    });

    test('更新済みの DB を開き直しても記録が残る', () async {
      // 2回目の起動で `onUpgrade` は走らない。
      // そこで壊れると「初回だけ動く」という気づきにくい形になる
      final path = await makeV1(withRow: true);
      final a = await SqfliteSessionStore.open(path: path);
      await a.markReviewed('force-motion', 'fall');
      await a.close();

      final b = await SqfliteSessionStore.open(path: path);
      addTearDown(b.close);
      expect((await b.reviewItems()).single.timesSeen, 1);
    });

    test('1概念ミッションの文脈を閉じて開き直しても復元できる', () async {
      final path = p.join(tmp.path, 'mission.db');
      final a = await SqfliteSessionStore.open(path: path);
      final id = await a.startSession(
        'force-motion',
        focusConceptKey: 'fall',
        tactic: TeachingTactic.experiment,
      );
      await a.saveProgress(
        id,
        transcript: const [
          Utterance(id: 'u1', isStudent: true, text: '実験から説明する'),
        ],
      );
      await a.close();

      final b = await SqfliteSessionStore.open(path: path);
      addTearDown(b.close);
      final saved = await b.unfinished(
        unitId: 'force-motion',
        focusConceptKey: 'fall',
      );
      expect(saved?.id, id);
      expect(saved?.focusConceptKey, 'fall');
      expect(saved?.tactic, TeachingTactic.experiment);
      expect(saved?.transcript.single.text, '実験から説明する');
    });
  });
}
