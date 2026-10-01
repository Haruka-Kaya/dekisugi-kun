/// 学習ゲーム全体で共有する、保存可能な学習行為の最小表現。
///
/// この型には自由記述、音声、選んだ選択肢、反応時間を置かない。
/// UI の回答状態は各画面だけが持ち、端末へ残すのは「どの学習行為を
/// どの証拠レベルまで終えたか」という派生状態だけにする。
library;

enum LearningScope {
  personal,
  schoolLocal;

  String get wire => name;

  static LearningScope? parse(Object? value) => switch (value) {
    'personal' => LearningScope.personal,
    'schoolLocal' => LearningScope.schoolLocal,
    _ => null,
  };
}

enum LearningOrigin {
  path,
  practice,
  story,
  lab,
  challenge,
  legacyImport,
  schoolAssignment;

  String get wire => name;

  static LearningOrigin? parse(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

enum LearningActivityKind {
  read,
  predict,
  singleSelect,
  classify,
  sequence,
  listen,
  speak,
  diagram,
  equation,
  story,
  transfer,
  checkpoint,
  timed;

  String get wire => name;

  static LearningActivityKind? parse(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// Repair Plannerが回答を保存せずに固定できる課題経路。
enum LearningRepairRouteKind {
  practice,
  listening,
  notationOrder,
  notationSymbol,
  notationGraph;

  String get wire => name;

  LearningActivityKind get expectedActivityKind => switch (this) {
    LearningRepairRouteKind.practice => LearningActivityKind.diagram,
    LearningRepairRouteKind.listening => LearningActivityKind.listen,
    LearningRepairRouteKind.notationOrder ||
    LearningRepairRouteKind.notationSymbol ||
    LearningRepairRouteKind.notationGraph => LearningActivityKind.equation,
  };
}

/// active needをexact repairで解消するときの、回答を含まないstable metadata。
///
/// catalogのunit/concept/stage/課題種別からだけ作れる。正答、選択肢ID、入力文は
/// 受け取らない。通常pathやStory/Bossの成功をneed tombstoneへ流用させないため、
/// [LearningEventCommand]がorigin・activity・解消mapとの完全一致を検証する。
final class LearningRepairResolution {
  LearningRepairResolution({
    required this.unitId,
    required this.conceptKey,
    required this.skillId,
    required this.needCode,
    required this.routeKind,
    required this.practiceAttempt,
  }) {
    _requireId(unitId, 'repairResolution.unitId');
    _requireId(conceptKey, 'repairResolution.conceptKey');
    _requireId(skillId, 'repairResolution.skillId');
    _requireId(needCode, 'repairResolution.needCode');
    if (!RegExp(r'^[A-Za-z][A-Za-z0-9]{0,63}$').hasMatch(conceptKey) ||
        skillId != '$unitId/$conceptKey') {
      throw ArgumentError('repairResolution skill does not match target');
    }
    if (practiceAttempt < 0 || practiceAttempt > 2) {
      throw ArgumentError.value(
        practiceAttempt,
        'repairResolution.practiceAttempt',
      );
    }
    final stage = const [
      'foundation',
      'conditions',
      'transfer',
    ][practiceAttempt % 3];
    final matches = switch (routeKind) {
      LearningRepairRouteKind.practice =>
        needCode == 'science.$conceptKey.$stage',
      LearningRepairRouteKind.listening =>
        needCode == 'science.$conceptKey.listening.$stage.transcript' ||
            needCode == 'science.$conceptKey.listening.$stage.meaning',
      LearningRepairRouteKind.notationOrder =>
        needCode == 'science.$conceptKey.notation.arrow' ||
            needCode == 'science.$conceptKey.notation.equation',
      LearningRepairRouteKind.notationSymbol =>
        needCode == 'science.$conceptKey.notation.symbol',
      LearningRepairRouteKind.notationGraph =>
        needCode == 'science.$conceptKey.notation.graph',
    };
    if (!matches ||
        (routeKind != LearningRepairRouteKind.practice &&
            routeKind != LearningRepairRouteKind.listening &&
            practiceAttempt != 0)) {
      throw ArgumentError('repairResolution does not match canonical route');
    }
  }

  final String unitId;
  final String conceptKey;
  final String skillId;
  final String needCode;
  final LearningRepairRouteKind routeKind;
  final int practiceAttempt;
}

/// 学習行為の終了状態。
///
/// [structuredSuccess] は固定解を持つ構造化課題だけに使う。自由記述や音声を
/// この値へ自動変換しない。
enum LearningAttemptOutcome {
  completed,
  retryNeeded,
  corrected,
  structuredSuccess;

  String get wire => name;

  static LearningAttemptOutcome? parse(Object? value) {
    for (final candidate in values) {
      if (candidate.wire == value) return candidate;
    }
    return null;
  }
}

/// 「画面を開いた」ではなく、どの学習証拠まで成立したか。
///
/// 数字はDBへ保存する公開契約なので、並べ替えない。
enum LearningEvidenceLevel {
  participation(0),
  selfCompared(1),
  structuredCorrection(2),
  transfer(3),
  spacedTransfer(4);

  const LearningEvidenceLevel(this.rank);

  final int rank;

  static LearningEvidenceLevel? fromRank(Object? value) {
    if (value is! int) return null;
    for (final candidate in values) {
      if (candidate.rank == value) return candidate;
    }
    return null;
  }
}

/// 端末へ確定する1学習イベント。
///
/// ID類はASCIIの不透明IDだけを受け付ける。回答本文を`activityId`などへ
/// 迂回して保存しにくくするため、長さと文字集合も狭くしている。
final class LearningEventCommand {
  LearningEventCommand({
    required this.eventId,
    required this.scope,
    required this.origin,
    required this.courseId,
    required this.nodeId,
    required this.activityId,
    required Iterable<String> skillIds,
    required this.activityKind,
    required this.outcome,
    required this.evidence,
    required this.contentVersion,
    required this.learningDay,
    required this.occurredAt,
    this.runId,
    this.sourceSessionId,
    Map<String, Iterable<String>> practiceNeedCodes = const {},
    Map<String, Iterable<String>> resolvedPracticeNeedCodes = const {},
    this.repairResolution,
  }) : skillIds = _validatedIds(skillIds, field: 'skillIds'),
       practiceNeedCodes = _validatedNeeds(
         practiceNeedCodes,
         field: 'practiceNeedCodes',
       ),
       resolvedPracticeNeedCodes = _validatedNeeds(
         resolvedPracticeNeedCodes,
         field: 'resolvedPracticeNeedCodes',
       ) {
    _requireId(eventId, 'eventId');
    _requireId(courseId, 'courseId');
    _requireId(nodeId, 'nodeId');
    _requireId(activityId, 'activityId');
    _requireId(contentVersion, 'contentVersion');
    if (runId case final value?) _requireId(value, 'runId');
    if (!_dayPattern.hasMatch(learningDay)) {
      throw ArgumentError.value(learningDay, 'learningDay', 'YYYY-MM-DD only');
    }
    if (occurredAt.millisecondsSinceEpoch < 0) {
      throw ArgumentError.value(occurredAt, 'occurredAt');
    }
    if (sourceSessionId != null && sourceSessionId! < 1) {
      throw ArgumentError.value(sourceSessionId, 'sourceSessionId');
    }
    if (origin == LearningOrigin.schoolAssignment &&
        scope != LearningScope.schoolLocal) {
      throw ArgumentError(
        'schoolAssignment events require the schoolLocal scope',
      );
    }
    if (scope == LearningScope.schoolLocal &&
        origin != LearningOrigin.schoolAssignment) {
      throw ArgumentError(
        'schoolLocal events must use the schoolAssignment origin',
      );
    }
    for (final entry in this.resolvedPracticeNeedCodes.entries) {
      if (entry.value.any(
        this.practiceNeedCodes[entry.key]?.contains ?? (_) => false,
      )) {
        throw ArgumentError(
          'a practice need cannot be observed and resolved by one event',
        );
      }
    }
    if (this.resolvedPracticeNeedCodes.isNotEmpty &&
        (outcome != LearningAttemptOutcome.structuredSuccess ||
            evidence.rank < LearningEvidenceLevel.structuredCorrection.rank)) {
      throw ArgumentError(
        'practice needs require corresponding structured success to resolve',
      );
    }
    final resolution = repairResolution;
    if (this.resolvedPracticeNeedCodes.isEmpty) {
      if (resolution != null) {
        throw ArgumentError('repairResolution requires one resolved need');
      }
    } else {
      final entries = this.resolvedPracticeNeedCodes.entries;
      final entry = entries.length == 1 ? entries.first : null;
      if (resolution == null ||
          origin != LearningOrigin.practice ||
          entry == null ||
          entry.key != resolution.skillId ||
          entry.value.length != 1 ||
          !entry.value.contains(resolution.needCode) ||
          !skillIds.contains(resolution.skillId) ||
          activityKind != resolution.routeKind.expectedActivityKind) {
        throw ArgumentError(
          'resolved need requires the exact planner repair target',
        );
      }
    }
  }

  final String eventId;
  final LearningScope scope;
  final LearningOrigin origin;
  final String courseId;
  final String nodeId;
  final String activityId;
  final Set<String> skillIds;
  final LearningActivityKind activityKind;
  final LearningAttemptOutcome outcome;
  final LearningEvidenceLevel evidence;
  final String contentVersion;
  final String learningDay;
  final DateTime occurredAt;
  final String? runId;
  final int? sourceSessionId;
  final LearningRepairResolution? repairResolution;

  /// カタログで定義した固定コードだけ。誤答本文や選択肢本文は入れない。
  ///
  /// unit全体のchallengeは複数conceptを1 node eventで確定するため、mapの
  /// skill keyは進捗更新用[skillIds]とは独立してよい。plannerがcatalog正本と
  /// 対応しない組をfail-closedで除外する。
  final Map<String, Set<String>> practiceNeedCodes;

  /// 対応する構造課題を成功したときだけ指定する固定コード。
  ///
  /// 回答や選択肢IDは受け取らず、カタログの一般化needだけを解消する。
  final Map<String, Set<String>> resolvedPracticeNeedCodes;

  bool get qualifiesForLearningDay =>
      outcome != LearningAttemptOutcome.retryNeeded &&
      evidence.rank >= LearningEvidenceLevel.selfCompared.rank;

  /// 学校課題と旧データ移行には報酬を付けない。
  bool get allowsRewards =>
      scope == LearningScope.personal &&
      origin != LearningOrigin.legacyImport &&
      qualifiesForLearningDay;
}

final class LearningEventRecord {
  const LearningEventRecord({
    required this.eventId,
    required this.scope,
    required this.origin,
    required this.courseId,
    required this.nodeId,
    required this.activityId,
    required this.activityKind,
    required this.outcome,
    required this.evidence,
    required this.contentVersion,
    required this.learningDay,
    required this.occurredAt,
    required this.runId,
    required this.sourceSessionId,
    required this.rewardEligible,
    this.meaningfulProgress = false,
  });

  final String eventId;
  final LearningScope scope;
  final LearningOrigin origin;
  final String courseId;
  final String nodeId;
  final String activityId;
  final LearningActivityKind activityKind;
  final LearningAttemptOutcome outcome;
  final LearningEvidenceLevel evidence;
  final String contentVersion;
  final String learningDay;
  final DateTime occurredAt;
  final String? runId;
  final int? sourceSessionId;
  final bool rewardEligible;

  /// node初回clear、または期限到来後のspaced retrievalだけをtrueにする。
  ///
  /// v8以前のeventは安全側にfalseで移行し、後から報酬対象へ推測し直さない。
  final bool meaningfulProgress;
}

final RegExp _identifierPattern = RegExp(
  r'^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$',
);
final RegExp _dayPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

void _requireId(String value, String field) {
  if (!_identifierPattern.hasMatch(value)) {
    throw ArgumentError.value(value, field, 'opaque ASCII identifier required');
  }
}

Set<String> _validatedIds(Iterable<String> values, {required String field}) {
  final out = <String>{};
  for (final value in values) {
    _requireId(value, field);
    if (!out.add(value)) throw ArgumentError('$field contains a duplicate');
  }
  if (out.isEmpty) throw ArgumentError('$field must not be empty');
  if (out.length > 16) throw ArgumentError('$field has too many values');
  return Set.unmodifiable(out);
}

Map<String, Set<String>> _validatedNeeds(
  Map<String, Iterable<String>> values, {
  required String field,
}) {
  final out = <String, Set<String>>{};
  for (final entry in values.entries) {
    _requireId(entry.key, '$field.skillId');
    final codes = <String>{};
    for (final code in entry.value) {
      _requireId(code, '$field.code');
      if (!codes.add(code)) {
        throw ArgumentError('$field contains a duplicate');
      }
    }
    if (codes.length > 8) {
      throw ArgumentError('$field has too many values');
    }
    if (codes.isNotEmpty) out[entry.key] = Set.unmodifiable(codes);
  }
  return Map.unmodifiable(out);
}
