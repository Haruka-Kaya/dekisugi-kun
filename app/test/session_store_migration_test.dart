import 'dart:io';

import 'package:dekisugi/models/review.dart';
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
      'sqflite', () async => SqfliteSessionStore.open(path: inMemoryDatabasePath));

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
      final db = await databaseFactory.openDatabase(path,
          options: OpenDatabaseOptions(version: 1));
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
      await db
          .execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)');
      if (withRow) {
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

    test('v1 の記録を消さずに更新する', () async {
      final path = await makeV1(withRow: true);
      final store = await SqfliteSessionStore.open(path: path);
      addTearDown(store.close);

      final items = await store.reviewItems();
      expect(items, hasLength(1), reason: '更新で復習の記録が消えた');
      expect(items.first.label, '落下の速さ');
      expect(items.first.timesSeen, 0, reason: '既存行は既定値で埋まるべき');
      expect(items.first.lastReviewedAt, isNull);

      // 端末IDが消えると、生徒から見て別人になる（枠も同意も引き継がれない）
      expect(await store.getSetting('device_id'), 'abc');
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
      final store =
          await SqfliteSessionStore.open(path: p.join(tmp.path, 'new.db'));
      addTearDown(store.close);

      await store.upsertReviews([
        ReviewItem(
          unitId: 'force-motion',
          conceptKey: 'fall',
          label: '落下の速さ',
          reason: ReviewReason.notCorrected,
          lastSeen: DateTime(2026, 8, 1),
        )
      ]);
      await store.markReviewed('force-motion', 'fall');
      expect((await store.reviewItems()).first.timesSeen, 1);
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
  });
}
