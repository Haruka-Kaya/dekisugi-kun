import '../learning/domain/learning_event.dart';
import '../learning/domain/learning_progress.dart';
import '../models/classroom_mission.dart';
import '../models/day_key.dart';
import 'session_store.dart';

/// 学校授業の比較フロー完了を、回答を含まない共通学習台帳へ橋渡しする。
///
/// このAPIが受け取るのはcatalog上の[ClassroomAssignment]だけ。自由記述、
/// 選択肢、正誤、反応時間は引数にもeventにも存在しない。
abstract final class ClassroomLearningCompletion {
  static const _courseId = 'science-ja-v1';
  static const _contentVersion = 'catalog-v4';

  /// 同じassignmentを同じ学習日に再送しても、同じevent IDになる。
  static LearningEventCommand eventFor(
    ClassroomAssignment assignment, {
    required DateTime occurredAt,
  }) {
    final learningDay = dayKeyOf(occurredAt.toLocal());
    return LearningEventCommand(
      eventId: 'school:$learningDay:${assignment.id}',
      scope: LearningScope.schoolLocal,
      origin: LearningOrigin.schoolAssignment,
      courseId: _courseId,
      // 教師はPath順と独立してA/B/Cを配る。必修nodeへ直接clearを付けると
      // 前提を飛ばすため、共同目標専用の安定nodeに分離する。
      nodeId: nodeIdFor(assignment),
      activityId: 'school.round-${assignment.round.code.toLowerCase()}.v1',
      skillIds: {
        '${assignment.mission.unit.id}/${assignment.mission.conceptKey}',
      },
      activityKind: activityKindFor(assignment.round),
      outcome: LearningAttemptOutcome.completed,
      // 授業完了は比較フローを操作した証拠。正答・理解・転移成功へ格上げしない。
      evidence: LearningEvidenceLevel.selfCompared,
      contentVersion: _contentVersion,
      learningDay: learningDay,
      // event IDだけでなく全fieldを決定論化し、同日の別route再送も同一command
      // として扱う。正確な完了時刻は学校の最小台帳には保存しない。
      occurredAt: dayStartOf(learningDay).toUtc(),
    );
  }

  /// [SessionStore]の公開APIだけを使って、学校scopeへ冪等commitする。
  static Future<CommitLearningResult> commit({
    required SessionStore store,
    required ClassroomAssignment assignment,
    DateTime? occurredAt,
  }) => store.commitLearningEvent(
    eventFor(assignment, occurredAt: occurredAt ?? DateTime.now()),
  );

  static String nodeIdFor(ClassroomAssignment assignment) =>
      'classroom:v1:${assignment.mission.unit.id}:'
      '${assignment.mission.conceptKey}:'
      'round-${assignment.round.code.toLowerCase()}';

  static LearningActivityKind activityKindFor(ClassroomRound round) =>
      switch (round) {
        ClassroomRound.a => LearningActivityKind.read,
        ClassroomRound.b => LearningActivityKind.diagram,
        ClassroomRound.c => LearningActivityKind.transfer,
      };
}
