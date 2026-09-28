import 'concept_progress.dart';
import 'day_key.dart';
import 'mission.dart';
import 'review.dart';
import 'unit.dart';

/// 考査日から逆算した「きょうやること」。
///
/// ## なぜこれが中核なのか
///
/// 狙っている層に streak が効かない（高校生年代の Duolingo 14日保持率は
/// 全年齢中最低の 55%）以上、継続の軸は別に要る。
/// **定期考査は中高生の生活に実在する締め切り**で、
/// しかも「保持したい期間が決まれば最適な復習間隔も決まる」（Cepeda 2006）
/// という根拠にそのまま乗る。
///
/// ここは日本の中高生に固有で、海外の学習アプリが持ってこられない部分でもある。
///
/// > [!warning] 間隔の比率は既存の [nextGap] に任せる
/// > `nextGap` の `_ratio = 0.15` は「このプロジェクトで検証していない仮の値」と
/// > コード内で自己申告されている。**新しい機能の根拠に使わない**ので、
/// > ここでは計算を持たず、期限の判定だけを担う。
class ExamPlan {
  const ExamPlan({
    required this.examDate,
    required this.daysLeft,
    required this.pathDue,
    required this.due,
    required this.untouched,
    required this.doneCount,
    required this.totalCount,
  });

  /// 次の定期考査。未設定なら null
  final DateTime? examDate;

  /// 考査まであと何日。未設定なら null
  final int? daysLeft;

  /// Mission Path上で期限が来たREPAIR/CASE。失敗した課題を先に直し、
  /// その後に保持確認を出す。教材を読むだけの旧reviewより優先する。
  final List<TodayTask> pathDue;

  /// 見直す期限が来ているもの（近い順）
  final List<ReviewItem> due;

  /// まだ一度も説明していない概念（単元の順）
  final List<ConceptRef> untouched;

  /// 説明できた概念の数
  final int doneCount;

  /// 単元にある概念の総数
  final int totalCount;

  /// 残っている概念の数。**数字だがポイントではなく残作業。**
  int get remaining => (totalCount - doneCount).clamp(0, totalCount);

  /// きょう出す1件。無ければ null（＝きょうはやることが無い）。
  ///
  /// **期限が来た復習を、新しい概念より先に出す。**
  /// 忘れかけているものを放置して先へ進むと、考査までに間に合わない。
  TodayTask? get today {
    if (pathDue.isNotEmpty) return pathDue.first;
    if (due.isNotEmpty) {
      final r = due.first;
      return TodayTask(
        unitId: r.unitId,
        conceptKey: r.conceptKey,
        label: r.label,
        missionKind: MissionKind.repair,
      );
    }
    if (untouched.isNotEmpty) {
      final c = untouched.first;
      return TodayTask(
        unitId: c.unitId,
        conceptKey: c.key,
        label: c.label,
        missionKind: MissionKind.teach,
      );
    }
    return null;
  }
}

/// 単元をまたいで概念を指すための参照。
class ConceptRef {
  const ConceptRef({
    required this.unitId,
    required this.key,
    required this.label,
  });

  final String unitId;
  final String key;
  final String label;
}

/// ホームの主 CTA が指す1件。
///
/// **連続日数の成立条件もこれと同じ**。「きょうの1件」の定義が
/// 画面と記録で1つに揃っていないと、
/// 「やったのに連続が付かない」が起きる。
class TodayTask {
  const TodayTask({
    required this.unitId,
    required this.conceptKey,
    required this.label,
    required this.missionKind,
  });

  final String unitId;
  final String conceptKey;
  final String label;

  /// 見た目のRETRYではなく、会話・保存・Directorまで伝える認知課題。
  final MissionKind missionKind;

  bool get isReview => missionKind != MissionKind.teach;
}

/// 考査日・復習・単元から、きょうの計画を組む。
///
/// [explainedKeys] は「単元ID/概念キー」の集合。
ExamPlan buildExamPlan({
  required DateTime now,
  required DateTime? examDate,
  required List<UnitSummary> units,
  required List<ReviewItem> reviews,
  required Set<String> explainedKeys,
  List<ConceptProgress> progress = const [],
}) {
  final progressById = {
    for (final item in progress) '${item.unitId}/${item.conceptKey}': item,
  };
  final due = <ReviewItem>[];
  for (final r in reviews) {
    if (progressById.containsKey('${r.unitId}/${r.conceptKey}')) continue;
    final gap = nextGap(now: now, examDate: examDate, timesSeen: r.timesSeen);
    if (!r.dueAt(gap).isAfter(now)) due.add(r);
  }
  // 期限が古いものから。放っておいたものほど忘れている
  due.sort((a, b) => a.lastSeen.compareTo(b.lastSeen));

  final todayKey = dayKeyOf(now);
  final labels = <String, String>{
    for (final unit in units)
      for (final concept in unit.concepts)
        '${unit.id}/${concept.key}': concept.label,
  };
  final duePath = <({TodayTask task, String dueDay})>[];
  for (final item in progress) {
    final id = '${item.unitId}/${item.conceptKey}';
    final label = labels[id];
    if (label == null || !item.isDueOn(todayKey)) continue;
    duePath.add((
      task: TodayTask(
        unitId: item.unitId,
        conceptKey: item.conceptKey,
        label: label,
        missionKind: item.nextMissionKind,
      ),
      dueDay: item.nextDueDay,
    ));
  }
  duePath.sort((a, b) {
    final aRepair = a.task.missionKind == MissionKind.repair ? 0 : 1;
    final bRepair = b.task.missionKind == MissionKind.repair ? 0 : 1;
    final byKind = aRepair.compareTo(bRepair);
    if (byKind != 0) return byKind;
    final byDay = a.dueDay.compareTo(b.dueDay);
    if (byDay != 0) return byDay;
    final byUnit = a.task.unitId.compareTo(b.task.unitId);
    return byUnit != 0
        ? byUnit
        : a.task.conceptKey.compareTo(b.task.conceptKey);
  });

  final untouched = <ConceptRef>[];
  var total = 0;
  var done = 0;
  for (final u in units) {
    for (final c in u.concepts) {
      total++;
      final id = '${u.id}/${c.key}';
      final path = progressById[id];
      if (path?.lastSuccessDay != null) {
        done++;
      } else if (path != null) {
        // 一度挑戦済み。未着手へ戻さず、期限が来たREPAIRとして扱う。
      } else if (!reviews.any((r) => '${r.unitId}/${r.conceptKey}' == id)) {
        if (explainedKeys.contains(id)) {
          // v6移行前データのフォールバック。本番DBではprogressへ移行される。
          done++;
        } else {
          // 復習に載っているものは「まだ触れていない」ではない
          untouched.add(ConceptRef(unitId: u.id, key: c.key, label: c.label));
        }
      }
    }
  }

  return ExamPlan(
    examDate: examDate,
    daysLeft: examDate == null ? null : _daysUntil(now, examDate),
    pathDue: [for (final item in duePath) item.task],
    due: due,
    untouched: untouched,
    doneCount: done,
    totalCount: total,
  );
}

/// 日付の差。**時刻ではなく日で数える**（15時に「あと0日」と出さない）。
int _daysUntil(DateTime now, DateTime exam) {
  final a = DateTime(now.year, now.month, now.day);
  final b = DateTime(exam.year, exam.month, exam.day);
  return b.difference(a).inDays;
}
