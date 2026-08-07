import '../config/app_radius.dart';
import '../config/app_theme.dart';
import '../models/team.dart';
import '../ui/_material.dart';

/// クラスの合計。
///
/// ## 出すのは量だけ
///
/// 誰が何をしたかは出さない。順位も出さない。
/// **未達成者を晒す設計は日本の教室では離脱の引き金**になる
/// （L@S 2022 は streak 喪失によるアカウント放棄を記録している）。
///
/// リーグや降格も入れない。Duolingo のリーグ +17% は大母集団が前提で、
/// 1クラスの規模だと降格の可視化がそのまま
/// 「やっていない人の可視化」に化ける。
class TeamCard extends StatelessWidget {
  const TeamCard({super.key, required this.summary, required this.onLeave});

  final TeamSummary summary;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.groups_outlined, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    summary.name.isEmpty ? 'クラス' : summary.name,
                    style: t.textTheme.titleMedium?.jaWeight(FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: onLeave,
                  icon: const Icon(Icons.more_horiz),
                  tooltip: 'クラスの設定',
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (summary.pending)
              _Pending(memberCount: summary.memberCount)
            else
              _Totals(summary: summary),
            if (summary.latestReached case final m?) ...[
              const SizedBox(height: 10),
              _Reached(label: m.label),
            ],
          ],
        ),
      ),
    );
  }
}

/// 人数が足りないうちの見せ方。
///
/// **「0」と出さない。** 0 は「誰もやっていない」という別の意味になり、
/// 事実でないことを画面が言うことになる。
class _Pending extends StatelessWidget {
  const _Pending({required this.memberCount});

  final int memberCount;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.hourglass_empty, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'クラスの合計は、$memberCount人あつまってから出ます。'
            '\n少ない人数だと、合計から一人ひとりの数が分かってしまうためです。',
            style: t.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.summary});

  final TeamSummary summary;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('クラスで集まった説明',
                style: t.textTheme.labelMedium
                    ?.copyWith(color: scheme.onSurfaceVariant)),
            Text('${summary.total ?? 0}',
                style: t.textTheme.headlineMedium?.jaWeight(FontWeight.w700)),
          ],
        ),
        const SizedBox(width: 20),
        // **自分のぶんは添えるだけ。** 比べさせない
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text('うち あなた ${summary.myTotal}',
              style: t.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        ),
      ],
    );
  }
}

class _Reached extends StatelessWidget {
  const _Reached({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          // 色だけで伝えない (SC 1.4.1)
          Icon(Icons.flag_outlined, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: t.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
