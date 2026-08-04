import '../models/dossier.dart';

/// 復習に回す理由。**「弱点」とは呼ばない**（C9）。
enum ReviewReason {
  /// 誤概念を訂正できなかった
  notCorrected,

  /// 説明が薄いまま（条件や理由が抜けている）
  thin;

  static ReviewReason parse(Object? v) =>
      v == 'notCorrected' ? ReviewReason.notCorrected : ReviewReason.thin;

  String get wire => name;

  /// 生徒に見せる文。**責めない。**
  String get label => switch (this) {
        ReviewReason.notCorrected => 'もう一度たしかめたいところ',
        ReviewReason.thin => 'あと少しで説明しきれるところ',
      };
}

/// 次に見直す1件。
class ReviewItem {
  const ReviewItem({
    required this.unitId,
    required this.conceptKey,
    required this.label,
    required this.reason,
    required this.lastSeen,
  });

  final String unitId;
  final String conceptKey;
  final String label;
  final ReviewReason reason;

  /// 最後にこの概念を扱った日時
  final DateTime lastSeen;

  /// 何日後に見直すか（[nextGap] の結果）を足した日。
  DateTime dueAt(Duration gap) => lastSeen.add(gap);

  Map<String, Object?> toRow() => {
        'unit_id': unitId,
        'concept_key': conceptKey,
        'label': label,
        'reason': reason.wire,
        'last_seen': lastSeen.millisecondsSinceEpoch,
      };

  factory ReviewItem.fromRow(Map<String, Object?> row) => ReviewItem(
        unitId: row['unit_id'] as String? ?? '',
        conceptKey: row['concept_key'] as String? ?? '',
        label: row['label'] as String? ?? '',
        reason: ReviewReason.parse(row['reason']),
        lastSeen: DateTime.fromMillisecondsSinceEpoch(
            (row['last_seen'] as int?) ?? 0),
      );
}

/// カルテから復習に回すものを取り出す。
///
/// **`unclear` は含めない。** 判断がついていないものを「できていない」側に置くと、
/// 触れてもいないことを突きつけることになる（サーバの `toReview()` と同じ規則）。
List<ReviewItem> reviewItemsOf(Dossier dossier, DateTime now) {
  final out = <ReviewItem>[];
  for (final s in dossier.slots) {
    if (s.isEmpty) continue; // まだ触れていない = 「できなかった」ではない
    final reason = s.hasAcceptedMisconception
        ? ReviewReason.notCorrected
        : (s.status == SlotStatus.thin ? ReviewReason.thin : null);
    if (reason == null) continue;
    out.add(ReviewItem(
      unitId: dossier.unitId,
      conceptKey: s.key,
      label: s.label,
      reason: reason,
      lastSeen: now,
    ));
  }
  return out;
}

/// 次にこの概念を見るまでの間隔。
///
/// ## 根拠と、根拠が無いところ
///
/// **確かなのは方向だけ**: Cepeda 2006「最適な復習間隔は**保持したい期間に応じて伸びる**」。
/// 中高生には定期考査という明確な保持期限があるので、そこから逆算できる。
/// これが日本の中高生に固有で、競合が真似しにくい部分でもある。
///
/// > [!warning] 比率 [_ratio] はこのプロジェクトで検証していない
/// > 「保持期間に比例して伸びる」は確認済みだが、**何%が最適かは未確認**。
/// > いまの値は仮で、実データが取れたら差し替える。
/// > 単調性（考査が遠いほど間隔が伸びる）だけはテストで縛ってある。
///
/// 考査日が未設定なら、伸びていく固定の階段を使う。
Duration nextGap({
  required DateTime now,
  DateTime? examDate,
  required int timesSeen,
}) {
  if (examDate != null) {
    final daysLeft = examDate.difference(now).inDays;
    // 考査が過ぎている・当日なら、間隔を空けている場合ではない
    if (daysLeft <= 1) return const Duration(days: 1);
    final gap = (daysLeft * _ratio).round();
    return Duration(days: gap.clamp(1, _maxGapDays));
  }

  // 考査日が分からないとき。回数に応じて伸ばす
  const ladder = [1, 3, 7, 14, 30];
  return Duration(days: ladder[timesSeen.clamp(0, ladder.length - 1)]);
}

/// 保持期間に対する復習間隔の比率。**仮の値**（上のコメントを読むこと）。
const double _ratio = 0.15;

/// 上限。これ以上空けると考査までに1回も回ってこない
const int _maxGapDays = 21;
