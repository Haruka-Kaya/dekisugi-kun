import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/dossier.dart';
import '../models/review.dart';

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

  Future<void> upsertReviews(List<ReviewItem> items);

  /// 概念を見直した。もう出さない
  Future<void> clearReview(String unitId, String conceptKey);

  /// 次の定期考査。復習間隔の逆算に使う。
  Future<DateTime?> examDate();
  Future<void> setExamDate(DateTime? date);

  Future<void> close();
}

/// sqflite 版。Android / iOS 用。
class SqfliteSessionStore implements SessionStore {
  SqfliteSessionStore._(this._db);

  final Database _db;

  static Future<SqfliteSessionStore> open() async {
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dir, 'dekisugi.db'),
      version: 1,
      onCreate: (db, _) async {
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
    );
    return SqfliteSessionStore._(db);
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
    final batch = _db.batch();
    for (final i in items) {
      batch.insert('reviews', i.toRow(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> clearReview(String unitId, String conceptKey) async {
    await _db.delete('reviews',
        where: 'unit_id = ? AND concept_key = ?', whereArgs: [unitId, conceptKey]);
  }

  @override
  Future<DateTime?> examDate() async {
    final rows =
        await _db.query('settings', where: 'key = ?', whereArgs: ['exam_date']);
    if (rows.isEmpty) return null;
    final v = int.tryParse(rows.first['value'] as String? ?? '');
    return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);
  }

  @override
  Future<void> setExamDate(DateTime? date) async {
    if (date == null) {
      await _db.delete('settings', where: 'key = ?', whereArgs: ['exam_date']);
      return;
    }
    await _db.insert(
      'settings',
      {'key': 'exam_date', 'value': '${date.millisecondsSinceEpoch}'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
      _reviews['${i.unitId}/${i.conceptKey}'] = i;
    }
  }

  @override
  Future<void> clearReview(String unitId, String conceptKey) async {
    _reviews.remove('$unitId/$conceptKey');
  }

  @override
  Future<DateTime?> examDate() async => _exam;

  @override
  Future<void> setExamDate(DateTime? date) async => _exam = date;

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
