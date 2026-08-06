import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/dossier.dart';
import '../models/review.dart';
import '../models/streak.dart';

/// 端末に残す会話の記録。
///
/// ## なぜ端末なのか
///
/// 理解カルテは「1台の端末が持つ1つの会話」の状態なので、端末が持てば
/// サーバは状態を持たずに済む。DB もセッションもロックも要らない。
///
/// ## OS に殺される前提で書く
///
/// **「アプリを離れる」ではなく「OS に殺される」前提**で設計する。
/// Android は裏に回ったアプリを予告なく落とすので、`dispose` や
/// ライフサイクルのコールバックが呼ばれる保証はない。
/// だから終了時にまとめて書かず、**1ターンごとに書く**。
class SavedSession {
  const SavedSession({
    required this.id,
    required this.unitId,
    required this.startedAt,
    required this.updatedAt,
    required this.endedAt,
    required this.dossier,
    required this.transcript,
  });

  final int id;
  final String unitId;
  final DateTime startedAt;
  final DateTime updatedAt;

  /// null なら**終わっていない**。次回起動時に再開を提案する
  final DateTime? endedAt;

  final Dossier? dossier;
  final List<Utterance> transcript;

  bool get isFinished => endedAt != null;
}

abstract class SessionStore {
  Future<int> startSession(String unitId);

  /// 1ターンごとに呼ぶ。**上書きで丸ごと保存する。**
  /// 差分更新にすると、途中で落ちたときに壊れた状態が残る。
  Future<void> saveProgress(
    int sessionId, {
    required List<Utterance> transcript,
    Dossier? dossier,
  });

  Future<void> finishSession(int sessionId);

  /// 終わっていない会話。あれば再開を提案する。
  Future<SavedSession?> unfinished();

  Future<List<SavedSession>> recentSessions({int limit = 20});

  /// 復習の一覧。同じ概念は最後の1件だけ残す。
  Future<List<ReviewItem>> reviewItems();

  /// 会話の結果を反映する。**[ReviewItem.timesSeen] は保つ**
  /// （会話するたびに見直し回数が0に戻ると、間隔が伸びない）。
  Future<void> upsertReviews(List<ReviewItem> items);

  /// 見直した。回数を1つ進めて、次の間隔を伸ばす。
  Future<void> markReviewed(String unitId, String conceptKey);

  /// その日の記録を積む。**足し算で、上書きしない。**
  ///
  /// [done] は片づけた「きょうの1件」の数。新しい概念でも、
  /// 期限が来た復習でもよい（教材が8節しかないので、
  /// 新しい概念だけを条件にすると9日目に誰も続けられなくなる）。
  Future<void> recordActivity(
    String day, {
    int sessions = 0,
    int done = 0,
    int textTurns = 0,
  });

  /// 日ごとの記録。新しい順。連続日数はこれを数えて出す。
  Future<List<DayRecord>> days({int limit = 400});

  /// 概念を見直した。もう出さない
  Future<void> clearReview(String unitId, String conceptKey);

  /// 次の定期考査。復習間隔の逆算に使う。
  Future<DateTime?> examDate();
  Future<void> setExamDate(DateTime? date);

  /// 端末に残す小さな値（端末ID・トークン・同意の記録など）。
  ///
  /// **秘密の保管庫ではない。** root を取られた端末では読める。
  /// ここに置いてよいのは「盗まれても本人の情報にならないもの」だけ。
  Future<String?> getSetting(String key);

  /// null を渡すと消す。
  Future<void> setSetting(String key, String? value);

  Future<void> close();
}

/// sqflite 版。Android / iOS 用。
class SqfliteSessionStore implements SessionStore {
  SqfliteSessionStore._(this._db);

  final Database _db;

  /// スキーマの履歴。**`_migrations[i]` は「バージョン i+1 にするための変更」。**
  ///
  /// 完成形の `CREATE TABLE` を別に持たない。2か所に書くと、
  /// 新規インストールと更新でスキーマがずれて、片方でしか出ない不具合になる。
  /// 新規は空の DB に全件を順に流し、更新は差分だけ流す。
  ///
  /// **追加するときは末尾に足すだけ。既存の要素は書き換えない。**
  /// 書き換えると、すでに更新を終えた端末には二度と適用されない。
  static final List<Future<void> Function(DatabaseExecutor)> _migrations = [
    // v1 — 最初のスキーマ
    (db) async {
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
          'CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT)');
    },
    // v2 — 見直した回数。これが無いと間隔反復が1日目に固定される
    (db) async {
      await db.execute(
          'ALTER TABLE reviews ADD COLUMN times_seen INTEGER NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE reviews ADD COLUMN last_reviewed_at INTEGER');
    },
    // v3 — 日ごとの記録。連続日数はここから毎回数える（保存しない）
    (db) async {
      await db.execute('''
        CREATE TABLE days(
          day TEXT PRIMARY KEY,
          sessions INTEGER NOT NULL DEFAULT 0,
          done INTEGER NOT NULL DEFAULT 0,
          text_turns INTEGER NOT NULL DEFAULT 0
        )''');
    },
  ];

  /// [path] はテスト専用。本番では既定の場所に開く。
  static Future<SqfliteSessionStore> open({String? path}) async {
    final file = path ?? p.join(await getDatabasesPath(), 'dekisugi.db');
    final db = await openDatabase(
      file,
      version: _migrations.length,
      onCreate: (db, version) => _runMigrations(db, 0, version),
      onUpgrade: (db, from, to) => _runMigrations(db, from, to),
      // 古い APK に戻されたとき、新しいスキーマの DB は開けない。
      // **記録を捨ててでも起動する**方を選ぶ（起動不能は復旧の手立てが無い）
      onDowngrade: onDatabaseDowngradeDelete,
    );
    return SqfliteSessionStore._(db);
  }

  /// `from` の次から `to` までを順に流す。
  ///
  /// **ここで `db.transaction()` を呼ばないこと。** `onCreate` / `onUpgrade` は
  /// sqflite が既にトランザクションの中で走らせているので、
  /// 入れ子にすると待ち合わせで固まる。
  static Future<void> _runMigrations(DatabaseExecutor db, int from, int to) async {
    for (var v = from; v < to; v++) {
      await _migrations[v](db);
    }
  }

  @override
  Future<int> startSession(String unitId) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _db.insert('sessions', {
      'unit_id': unitId,
      'started_at': now,
      'updated_at': now,
      'transcript': '[]',
    });
  }

  @override
  Future<void> saveProgress(
    int sessionId, {
    required List<Utterance> transcript,
    Dossier? dossier,
  }) async {
    await _db.update(
      'sessions',
      {
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'transcript': jsonEncode(transcript.map((u) => u.toJson()).toList()),
        if (dossier != null) 'dossier': jsonEncode(dossier.toJson()),
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  @override
  Future<void> finishSession(int sessionId) async {
    await _db.update(
      'sessions',
      {'ended_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  @override
  Future<SavedSession?> unfinished() async {
    final rows = await _db.query('sessions',
        where: 'ended_at IS NULL', // 同じミリ秒に2件あると順序が定まらない。id で確定させる
        orderBy: 'updated_at DESC, id DESC', limit: 1);
    if (rows.isEmpty) return null;
    final s = _toSession(rows.first);
    // 中身が無い会話を「再開しますか」と聞かない
    return s.transcript.isEmpty ? null : s;
  }

  @override
  Future<List<SavedSession>> recentSessions({int limit = 20}) async {
    final rows = await _db.query('sessions',
        orderBy: 'updated_at DESC, id DESC', limit: limit);
    return rows.map(_toSession).toList();
  }

  @override
  Future<List<ReviewItem>> reviewItems() async {
    final rows = await _db.query('reviews', orderBy: 'last_seen ASC');
    return rows.map(ReviewItem.fromRow).toList();
  }

  @override
  Future<void> upsertReviews(List<ReviewItem> items) async {
    // **`ConflictAlgorithm.replace` を使わないこと。**
    // replace は行ごと入れ替えるので、会話するたびに `times_seen` が
    // 0 に戻り、間隔の階段が1段も上がらなくなる。
    // 更新句に `times_seen` と `last_reviewed_at` を**入れない**のが要点。
    final batch = _db.batch();
    for (final i in items) {
      batch.rawInsert(
        '''
        INSERT INTO reviews(unit_id, concept_key, label, reason, last_seen,
                            times_seen, last_reviewed_at)
        VALUES(?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(unit_id, concept_key) DO UPDATE SET
          label = excluded.label,
          reason = excluded.reason,
          last_seen = excluded.last_seen
        ''',
        [
          i.unitId,
          i.conceptKey,
          i.label,
          i.reason.wire,
          i.lastSeen.millisecondsSinceEpoch,
          i.timesSeen,
          i.lastReviewedAt?.millisecondsSinceEpoch,
        ],
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> markReviewed(String unitId, String conceptKey) async {
    await _db.rawUpdate(
      'UPDATE reviews SET times_seen = times_seen + 1, last_reviewed_at = ? '
      'WHERE unit_id = ? AND concept_key = ?',
      [DateTime.now().millisecondsSinceEpoch, unitId, conceptKey],
    );
  }

  @override
  Future<void> clearReview(String unitId, String conceptKey) async {
    await _db.delete('reviews',
        where: 'unit_id = ? AND concept_key = ?', whereArgs: [unitId, conceptKey]);
  }

  @override
  Future<void> recordActivity(
    String day, {
    int sessions = 0,
    int done = 0,
    int textTurns = 0,
  }) async {
    await _db.rawInsert(
      '''
      INSERT INTO days(day, sessions, done, text_turns) VALUES(?, ?, ?, ?)
      ON CONFLICT(day) DO UPDATE SET
        sessions   = sessions   + excluded.sessions,
        done       = done       + excluded.done,
        text_turns = text_turns + excluded.text_turns
      ''',
      [day, sessions, done, textTurns],
    );
  }

  @override
  Future<List<DayRecord>> days({int limit = 400}) async {
    final rows =
        await _db.query('days', orderBy: 'day DESC', limit: limit);
    return rows.map(_toDay).toList();
  }

  static DayRecord _toDay(Map<String, Object?> row) => DayRecord(
        day: row['day'] as String? ?? '',
        sessions: (row['sessions'] as int?) ?? 0,
        done: (row['done'] as int?) ?? 0,
        textTurns: (row['text_turns'] as int?) ?? 0,
      );

  @override
  Future<DateTime?> examDate() async {
    final v = int.tryParse(await getSetting('exam_date') ?? '');
    return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);
  }

  @override
  Future<void> setExamDate(DateTime? date) =>
      setSetting('exam_date', date?.millisecondsSinceEpoch.toString());

  @override
  Future<String?> getSetting(String key) async {
    final rows =
        await _db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  @override
  Future<void> setSetting(String key, String? value) async {
    if (value == null) {
      await _db.delete('settings', where: 'key = ?', whereArgs: [key]);
      return;
    }
    await _db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> close() => _db.close();

  static SavedSession _toSession(Map<String, Object?> row) {
    final dossierJson = row['dossier'] as String?;
    return SavedSession(
      id: row['id'] as int,
      unitId: row['unit_id'] as String? ?? '',
      startedAt:
          DateTime.fromMillisecondsSinceEpoch((row['started_at'] as int?) ?? 0),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch((row['updated_at'] as int?) ?? 0),
      endedAt: row['ended_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(row['ended_at'] as int),
      dossier: dossierJson == null || dossierJson.isEmpty
          ? null
          : Dossier.fromJson(
              (jsonDecode(dossierJson) as Map).cast<String, dynamic>()),
      transcript: decodeTranscript(row['transcript'] as String?),
    );
  }
}

/// 逐語の復元。**壊れていても落とさない**（記録が読めないより、欠けても開く方がまし）。
List<Utterance> decodeTranscript(String? json) {
  if (json == null || json.isEmpty) return const [];
  try {
    final list = jsonDecode(json);
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((m) => Utterance(
              id: m['id'] as String? ?? '',
              isStudent: m['speaker'] == 'student',
              text: m['text'] as String? ?? '',
              corrected: m['corrected'] as String?,
            ))
        .where((u) => u.id.isNotEmpty)
        .toList();
  } catch (e) {
    debugPrint('逐語の復元に失敗: $e');
    return const [];
  }
}

/// メモリ版。テストと、sqflite が動かないプラットフォーム（web / Windows）用。
///
/// **開発プレビューで落ちないためのもので、記録は残らない。**
class MemorySessionStore implements SessionStore {
  final _sessions = <int, SavedSession>{};
  final _reviews = <String, ReviewItem>{};
  final _settings = <String, String>{};
  final _days = <String, DayRecord>{};
  DateTime? _exam;
  int _seq = 0;

  @override
  Future<int> startSession(String unitId) async {
    final id = ++_seq;
    final now = DateTime.now();
    _sessions[id] = SavedSession(
      id: id,
      unitId: unitId,
      startedAt: now,
      updatedAt: now,
      endedAt: null,
      dossier: null,
      transcript: const [],
    );
    return id;
  }

  @override
  Future<void> saveProgress(int sessionId,
      {required List<Utterance> transcript, Dossier? dossier}) async {
    final s = _sessions[sessionId];
    if (s == null) return;
    _sessions[sessionId] = SavedSession(
      id: s.id,
      unitId: s.unitId,
      startedAt: s.startedAt,
      updatedAt: DateTime.now(),
      endedAt: s.endedAt,
      dossier: dossier ?? s.dossier,
      transcript: List.of(transcript),
    );
  }

  @override
  Future<void> finishSession(int sessionId) async {
    final s = _sessions[sessionId];
    if (s == null) return;
    _sessions[sessionId] = SavedSession(
      id: s.id,
      unitId: s.unitId,
      startedAt: s.startedAt,
      updatedAt: s.updatedAt,
      endedAt: DateTime.now(),
      dossier: s.dossier,
      transcript: s.transcript,
    );
  }

  @override
  Future<SavedSession?> unfinished() async {
    final open = _sessions.values
        .where((s) => !s.isFinished && s.transcript.isNotEmpty)
        .toList()
      ..sort(_newestFirst);
    return open.isEmpty ? null : open.first;
  }

  @override
  Future<List<SavedSession>> recentSessions({int limit = 20}) async {
    final all = _sessions.values.toList()..sort(_newestFirst);
    return all.take(limit).toList();
  }

  /// 同じミリ秒に2件あると順序が定まらない。id で確定させる
  static int _newestFirst(SavedSession a, SavedSession b) {
    final byTime = b.updatedAt.compareTo(a.updatedAt);
    return byTime != 0 ? byTime : b.id.compareTo(a.id);
  }

  @override
  Future<List<ReviewItem>> reviewItems() async {
    final all = _reviews.values.toList()
      ..sort((a, b) => a.lastSeen.compareTo(b.lastSeen));
    return all;
  }

  @override
  Future<void> upsertReviews(List<ReviewItem> items) async {
    for (final i in items) {
      final key = '${i.unitId}/${i.conceptKey}';
      final prev = _reviews[key];
      // sqflite 版の ON CONFLICT と同じ規則。**見直した回数は引き継ぐ**
      _reviews[key] = prev == null
          ? i
          : i.copyWith(
              timesSeen: prev.timesSeen,
              lastReviewedAt: prev.lastReviewedAt,
            );
    }
  }

  @override
  Future<void> markReviewed(String unitId, String conceptKey) async {
    final key = '$unitId/$conceptKey';
    final prev = _reviews[key];
    if (prev == null) return;
    _reviews[key] = prev.copyWith(
      timesSeen: prev.timesSeen + 1,
      lastReviewedAt: DateTime.now(),
    );
  }

  @override
  Future<void> clearReview(String unitId, String conceptKey) async {
    _reviews.remove('$unitId/$conceptKey');
  }

  @override
  Future<void> recordActivity(
    String day, {
    int sessions = 0,
    int done = 0,
    int textTurns = 0,
  }) async {
    final prev = _days[day];
    _days[day] = DayRecord(
      day: day,
      sessions: (prev?.sessions ?? 0) + sessions,
      done: (prev?.done ?? 0) + done,
      textTurns: (prev?.textTurns ?? 0) + textTurns,
    );
  }

  @override
  Future<List<DayRecord>> days({int limit = 400}) async {
    final all = _days.values.toList()
      ..sort((a, b) => b.day.compareTo(a.day));
    return all.take(limit).toList();
  }

  @override
  Future<DateTime?> examDate() async => _exam;

  @override
  Future<void> setExamDate(DateTime? date) async => _exam = date;

  @override
  Future<String?> getSetting(String key) async => _settings[key];

  @override
  Future<void> setSetting(String key, String? value) async {
    if (value == null) {
      _settings.remove(key);
    } else {
      _settings[key] = value;
    }
  }

  @override
  Future<void> close() async {}
}

/// 使える方を開く。
///
/// sqflite は Android / iOS / macOS のみ。web と Windows では動かないので、
/// **開発プレビューが落ちないよう**メモリ版に落とす。
Future<SessionStore> openSessionStore() async {
  if (kIsWeb) return MemorySessionStore();
  try {
    return await SqfliteSessionStore.open();
  } catch (e) {
    debugPrint('sqflite が使えないのでメモリに落とす: $e');
    return MemorySessionStore();
  }
}
