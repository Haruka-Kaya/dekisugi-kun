import 'dart:convert';

import 'session_store.dart';

/// 端末内練習で残す最小の継続情報。
///
/// 自由記述、選んだ誤答、年齢、同意、端末IDは含めない。保存するのは
/// 「どの概念を、いつ、何回最後まで練習したか」だけ。
class LocalPracticeRecord {
  const LocalPracticeRecord({
    required this.unitId,
    required this.conceptKey,
    required this.completedCount,
    required this.lastCompletedAt,
  });

  final String unitId;
  final String conceptKey;
  final int completedCount;
  final DateTime lastCompletedAt;

  String get id => '$unitId/$conceptKey';

  Map<String, Object?> toJson() => {
    'unitId': unitId,
    'conceptKey': conceptKey,
    'completedCount': completedCount,
    'lastCompletedAt': lastCompletedAt.toUtc().millisecondsSinceEpoch,
  };

  static LocalPracticeRecord? fromJson(Map<String, Object?> json) {
    const allowedKeys = {
      'unitId',
      'conceptKey',
      'completedCount',
      'lastCompletedAt',
    };
    if (json.length != allowedKeys.length ||
        json.keys.any((key) => !allowedKeys.contains(key))) {
      return null;
    }
    final unitId = json['unitId'];
    final conceptKey = json['conceptKey'];
    final count = json['completedCount'];
    final at = json['lastCompletedAt'];
    if (unitId is! String ||
        unitId.trim().isEmpty ||
        unitId.length > 128 ||
        conceptKey is! String ||
        conceptKey.trim().isEmpty ||
        conceptKey.length > 128 ||
        count is! num ||
        count.toInt() != count ||
        count < 1 ||
        count > 1000000 ||
        at is! num ||
        at.toInt() != at ||
        at <= 0) {
      return null;
    }
    final date = DateTime.fromMillisecondsSinceEpoch(at.toInt(), isUtc: true);
    if (date.year < 2020 || date.year > 2200) return null;
    return LocalPracticeRecord(
      unitId: unitId,
      conceptKey: conceptKey,
      completedCount: count.toInt(),
      lastCompletedAt: date,
    );
  }
}

/// [SessionStore.settings]上に、端末内練習の印だけを保存する。
///
/// 1つのJSONを直列化して更新するため、連打や画面遷移が重なっても完了回数を
/// 取りこぼさない。壊れた値は学習済みと誤認せず、空として扱う。
class LocalPracticeStore {
  LocalPracticeStore(this._store);

  static const settingKey = 'local_practice_progress_v1';
  static const _version = 1;
  static const _maxRecords = 512;

  final SessionStore _store;
  Future<void> _writeTail = Future<void>.value();

  Future<List<LocalPracticeRecord>> records() async {
    final raw = await _store.getSetting(settingKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map ||
          decoded.length != 2 ||
          !decoded.containsKey('version') ||
          !decoded.containsKey('records') ||
          decoded['version'] != _version) {
        return const [];
      }
      final values = decoded['records'];
      if (values is! List || values.length > _maxRecords) return const [];
      final byId = <String, LocalPracticeRecord>{};
      for (final value in values) {
        if (value is! Map) return const [];
        final record = LocalPracticeRecord.fromJson(
          value.cast<String, Object?>(),
        );
        if (record == null || byId.containsKey(record.id)) return const [];
        byId[record.id] = record;
      }
      final result = byId.values.toList()
        ..sort((a, b) => b.lastCompletedAt.compareTo(a.lastCompletedAt));
      return result;
    } on FormatException {
      return const [];
    } on TypeError {
      return const [];
    } on RangeError {
      return const [];
    }
  }

  Future<LocalPracticeRecord> recordCompletion({
    required String unitId,
    required String conceptKey,
    DateTime? completedAt,
  }) {
    final cleanUnitId = unitId.trim();
    final cleanConceptKey = conceptKey.trim();
    if (cleanUnitId.isEmpty ||
        cleanUnitId.length > 128 ||
        cleanConceptKey.isEmpty ||
        cleanConceptKey.length > 128) {
      throw ArgumentError('unitId and conceptKey must be 1–128 characters');
    }
    final at = (completedAt ?? DateTime.now()).toUtc();
    return _serialize(() async {
      final current = await records();
      final id = '$cleanUnitId/$cleanConceptKey';
      final old = current.where((record) => record.id == id).firstOrNull;
      final next = LocalPracticeRecord(
        unitId: cleanUnitId,
        conceptKey: cleanConceptKey,
        completedCount: (old?.completedCount ?? 0) + 1,
        lastCompletedAt: at,
      );
      final updated = [
        next,
        for (final record in current)
          if (record.id != id) record,
      ];
      if (updated.length > _maxRecords) {
        updated.removeRange(_maxRecords, updated.length);
      }
      await _store.setSetting(
        settingKey,
        jsonEncode({
          'version': _version,
          'records': [for (final record in updated) record.toJson()],
        }),
      );
      return next;
    });
  }

  Future<void> clear() =>
      _serialize(() async => _store.setSetting(settingKey, null));

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _writeTail.then((_) => operation());
    _writeTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace stackTrace) {},
    );
    return result;
  }
}
