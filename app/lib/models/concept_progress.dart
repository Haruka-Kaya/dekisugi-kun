import 'mission.dart';

/// 1概念について、最後のミッションで確定した学習状態。
///
/// 画面を開いた、教材を読んだ、といった操作では更新しない。
/// 生徒の説明と誤概念への反応が保存まで完了したときだけ進む。
enum ConceptOutcome {
  /// 初回の説明、または修復ミッションを完了した。
  learned,

  /// 説明や訂正が決着せず、間を空けずに組み直す必要がある。
  rematchNeeded,

  /// 後日の別場面でも説明でき、保持を確認できた。
  retained;

  String get wire => name;

  /// 未知の値を成功側へ倒さない。
  ///
  /// 将来のAPKで状態が増えたDBを古いコードが読んでも、学習済みを
  /// 捏造せず修復ミッションを出せる。
  static ConceptOutcome parse(Object? value) => switch (value) {
    'learned' => ConceptOutcome.learned,
    'retained' => ConceptOutcome.retained,
    _ => ConceptOutcome.rematchNeeded,
  };
}

/// Mission Pathを組み立てるための、概念ごとの確定済み状態。
class ConceptProgress {
  const ConceptProgress({
    required this.unitId,
    required this.conceptKey,
    required this.lastOutcome,
    required this.successfulRetrievals,
    required this.lastAttemptDay,
    required this.lastSuccessDay,
    required this.nextDueDay,
    required this.sourceSessionId,
  });

  final String unitId;
  final String conceptKey;
  final ConceptOutcome lastOutcome;

  /// 後日のcase retryで連続して保持を確認できた回数。
  ///
  /// 初回のteachと、説明を組み直すrepairは想起間隔を伸ばす根拠にしない。
  /// 未決着になったら0へ戻し、成功歴を消すのではなく次の間隔だけを
  /// 安全側へ戻す。
  final int successfulRetrievals;

  /// 直近の成否が確定した学習日。`YYYY-MM-DD`、午前4時境界。
  final String lastAttemptDay;

  /// 最後にclearした学習日。まだ一度もclearしていなければnull。
  final String? lastSuccessDay;

  /// 次にMission Pathへ出す学習日。期限超過もこの値を保持する。
  final String nextDueDay;

  /// この状態を書いたセッション。移行データには対応するsessionがないためnull。
  final int? sourceSessionId;

  /// 期限が来たときに要求する学習行為。
  MissionKind get nextMissionKind => lastOutcome == ConceptOutcome.rematchNeeded
      ? MissionKind.repair
      : MissionKind.caseRetry;

  /// ISO形式の日キーは辞書順と日付順が一致する。
  bool isDueOn(String day) => nextDueDay.compareTo(day) <= 0;

  Map<String, Object?> toRow() => {
    'unit_id': unitId,
    'concept_key': conceptKey,
    'last_outcome': lastOutcome.wire,
    'successful_retrievals': successfulRetrievals,
    'last_attempt_day': lastAttemptDay,
    'last_success_day': lastSuccessDay,
    'next_due_day': nextDueDay,
    'source_session_id': sourceSessionId,
  };

  factory ConceptProgress.fromRow(Map<String, Object?> row) => ConceptProgress(
    unitId: row['unit_id'] as String? ?? '',
    conceptKey: row['concept_key'] as String? ?? '',
    lastOutcome: ConceptOutcome.parse(row['last_outcome']),
    successfulRetrievals: ((row['successful_retrievals'] as int?) ?? 0).clamp(
      0,
      1 << 31,
    ),
    lastAttemptDay: row['last_attempt_day'] as String? ?? '',
    lastSuccessDay: row['last_success_day'] as String?,
    nextDueDay: row['next_due_day'] as String? ?? '',
    sourceSessionId: row['source_session_id'] as int?,
  );
}
