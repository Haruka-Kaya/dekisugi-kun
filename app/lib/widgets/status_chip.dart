import '../config/app_radius.dart';
import '../config/app_theme.dart';
import '../ui/_material.dart';

/// 説明の結果を表すチップ。
///
/// **色 + アイコン形状 + テキストラベルの3点セットが不可分な1単位** (SC 1.4.1)。
/// 「色だけ」「アイコンだけ」で状態を伝える使い方はしない。
/// 白背景では4状態のペア間 3:1 が原理的に不可能なので、色は補助でしかない
/// （`attendance_system/DESIGN.md` §2.3 に証明がある）。
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.dense = false});

  final ExplainStatus status;

  /// 一覧に並べるときの詰めた表示。文字は小さくしない（本文 14px 未満は使わない）。
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final fg = c.fgFor(status);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.chipFor(status),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon(status), size: 18, color: fg),
          const SizedBox(width: 6),
          Text(
            statusLabel(status),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                // チップ内は1行なので行間を持たせない（上下の余白が二重になる）
                ?.copyWith(color: fg, height: 1.0, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
