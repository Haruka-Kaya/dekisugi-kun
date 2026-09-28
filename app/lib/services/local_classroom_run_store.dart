import 'dart:convert';

import 'session_store.dart';

/// 端末内の授業ミッションが、どこまで進んだか。
///
/// 自由記述を保存しないため、練習中の細かな入力段階は持たない。
/// [practice] からの再開は必ず「見ずに説明する」の最初へ戻る。
/// [completed] は比較フローの操作を終えたことだけを表し、正答や理解の
/// 判定には使わない。
enum LocalClassroomStage { material, practice, completed }

/// 授業中の再開位置、または最後に終えた授業を示す最小記録。
///
/// 生徒名、学校・学級、アカウント、回答、選択肢は含めない。
class LocalClassroomRun {
  const LocalClassroomRun({
    required this.unitId,
    required this.conceptKey,
    required this.practiceAttempt,
    required this.stage,
    required this.updatedAt,
  });

  final String unitId;
  final String conceptKey;

  /// 板書コード末尾のA/B/Cに対応する、0始まりの公開教材ラウンド。
  ///
  /// 完了履歴から再計算しない。再起動後も同じ問いとcheckpointへ戻すための
  /// 教材位置であり、回答や成績ではない。[stage] が [LocalClassroomStage.completed]
  /// のときも、比較フローの操作完了を示すだけである。
  final int practiceAttempt;
  final LocalClassroomStage stage;
  final DateTime updatedAt;

  String get id => '$unitId/$conceptKey/$practiceAttempt';

  Map<String, Object?> toJson() => {
    'unitId': unitId,
    'conceptKey': conceptKey,
    'practiceAttempt': practiceAttempt,
    'stage': stage.name,
    'updatedAt': updatedAt.toUtc().millisecondsSinceEpoch,
  };

  static LocalClassroomRun? fromJson(Map<String, Object?> json) {
    const allowedKeys = {
      'unitId',
      'conceptKey',
      'practiceAttempt',
      'stage',
      'updatedAt',
    };
    if (json.length != allowedKeys.length ||
        json.keys.any((key) => !allowedKeys.contains(key))) {
      return null;
    }

    final unitId = json['unitId'];
    final conceptKey = json['conceptKey'];
    final practiceAttempt = json['practiceAttempt'];
    final stageName = json['stage'];
    final updatedAt = json['updatedAt'];
    if (unitId is! String ||
        unitId.trim().isEmpty ||
        unitId.length > 128 ||
        conceptKey is! String ||
        conceptKey.trim().isEmpty ||
        conceptKey.length > 128 ||
        practiceAttempt is! int ||
        practiceAttempt < 0 ||
        practiceAttempt > 2 ||
        stageName is! String ||
        updatedAt is! num ||
        !updatedAt.isFinite ||
        updatedAt.toInt() != updatedAt ||
        updatedAt <= 0) {
      return null;
    }

    final stage = LocalClassroomStage.values
        .where((value) => value.name == stageName)
        .firstOrNull;
    if (stage == null) return null;

    final date = DateTime.fromMillisecondsSinceEpoch(
      updatedAt.toInt(),
      isUtc: true,
    );
    if (date.year < 2020 || date.year > 2200) return null;

    return LocalClassroomRun(
      unitId: unitId,
      conceptKey: conceptKey,
      practiceAttempt: practiceAttempt,
      stage: stage,
      updatedAt: date,
    );
  }
}

/// 端末内授業の「場所」または直近の操作完了だけを[SessionStore.settings]へ残す。
///
/// 既存の5項目を使って1件だけを上書きする。学校で指定されたA/B/Cは
/// 個人練習のローテーションへ混ぜず、このstoreだけで保持する。
class LocalClassroomRunStore {
  LocalClassroomRunStore(this._store);

  static const settingKey = 'local_classroom_run_v1';
  static const _version = 2;

  final SessionStore _store;
  Future<void> _writeTail = Future<void>.value();

  Future<LocalClassroomRun?> load() => _serialize(_loadCurrent);

  Future<LocalClassroomRun?> _loadCurrent() async {
    final raw = await _store.getSetting(settingKey);
    if (raw == null || raw.isEmpty) return null;

    LocalClassroomRun? restored;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map &&
          decoded.length == 2 &&
          decoded.containsKey('version') &&
          decoded.containsKey('run') &&
          decoded['version'] == _version) {
        final run = decoded['run'];
        if (run is Map) {
          restored = LocalClassroomRun.fromJson(run.cast<String, Object?>());
        }
      }
    } on FormatException {
      // 壊れた、または旧版の曖昧な再開位置は次の行で破棄する。
    } on TypeError {
      // 同上。
    } on RangeError {
      // 同上。
    }
    if (restored != null) return restored;

    // v1にはroundが無く、履歴次第で課題が変わる。推測でAへ移行しない。
    await _store.setSetting(settingKey, null);
    return null;
  }

  Future<LocalClassroomRun> begin({
    required String unitId,
    required String conceptKey,
    required int practiceAttempt,
    DateTime? updatedAt,
  }) => _save(
    unitId: unitId,
    conceptKey: conceptKey,
    practiceAttempt: practiceAttempt,
    stage: LocalClassroomStage.material,
    updatedAt: updatedAt,
  );

  Future<LocalClassroomRun> enterPractice({
    required String unitId,
    required String conceptKey,
    required int practiceAttempt,
    DateTime? updatedAt,
  }) => _save(
    unitId: unitId,
    conceptKey: conceptKey,
    practiceAttempt: practiceAttempt,
    stage: LocalClassroomStage.practice,
    updatedAt: updatedAt,
  );

  /// 現在の授業と一致する練習だけを、比較フローの操作完了として残す。
  ///
  /// 回答本文や正誤は受け取らない。教材・概念・A/B/Cのどれかが違う場合や、
  /// 教材段階のままの場合は、別の授業を誤って完了表示にしないため拒否する。
  Future<LocalClassroomRun> complete({
    required String unitId,
    required String conceptKey,
    required int practiceAttempt,
    DateTime? updatedAt,
  }) {
    final cleanUnitId = unitId.trim();
    final cleanConceptKey = conceptKey.trim();
    _validateIdentity(
      unitId: cleanUnitId,
      conceptKey: cleanConceptKey,
      practiceAttempt: practiceAttempt,
    );
    return _serialize(() async {
      final current = await _loadCurrent();
      final expectedId = '$cleanUnitId/$cleanConceptKey/$practiceAttempt';
      if (current == null || current.id != expectedId) {
        throw StateError('classroom run does not match completion');
      }
      if (current.stage != LocalClassroomStage.practice) {
        throw StateError('classroom run is not in practice');
      }
      final completed = LocalClassroomRun(
        unitId: cleanUnitId,
        conceptKey: cleanConceptKey,
        practiceAttempt: practiceAttempt,
        stage: LocalClassroomStage.completed,
        updatedAt: _storedTimestamp(updatedAt ?? DateTime.now()),
      );
      await _write(completed);
      return completed;
    });
  }

  Future<LocalClassroomRun> _save({
    required String unitId,
    required String conceptKey,
    required int practiceAttempt,
    required LocalClassroomStage stage,
    DateTime? updatedAt,
  }) {
    final cleanUnitId = unitId.trim();
    final cleanConceptKey = conceptKey.trim();
    _validateIdentity(
      unitId: cleanUnitId,
      conceptKey: cleanConceptKey,
      practiceAttempt: practiceAttempt,
    );
    final run = LocalClassroomRun(
      unitId: cleanUnitId,
      conceptKey: cleanConceptKey,
      practiceAttempt: practiceAttempt,
      stage: stage,
      updatedAt: _storedTimestamp(updatedAt ?? DateTime.now()),
    );
    return _serialize(() async {
      await _write(run);
      return run;
    });
  }

  void _validateIdentity({
    required String unitId,
    required String conceptKey,
    required int practiceAttempt,
  }) {
    if (unitId.isEmpty ||
        unitId.length > 128 ||
        conceptKey.isEmpty ||
        conceptKey.length > 128) {
      throw ArgumentError('unitId and conceptKey must be 1–128 characters');
    }
    if (practiceAttempt < 0 || practiceAttempt > 2) {
      throw ArgumentError.value(
        practiceAttempt,
        'practiceAttempt',
        'must be 0, 1, or 2',
      );
    }
  }

  Future<void> _write(LocalClassroomRun run) => _store.setSetting(
    settingKey,
    jsonEncode({'version': _version, 'run': run.toJson()}),
  );

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

DateTime _storedTimestamp(DateTime value) =>
    DateTime.fromMillisecondsSinceEpoch(
      value.toUtc().millisecondsSinceEpoch,
      isUtc: true,
    );
