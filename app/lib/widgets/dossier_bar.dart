import '../config/app_radius.dart';
import '../config/app_theme.dart';
import '../models/dossier.dart';
import '../ui/_material.dart';

/// 理解カルテを1行にまとめて出す。
///
/// **「弱点」と断定しない**（C9）。
/// 誘発の判定は行動の観測でしかなく、聞き流しただけでも `accepted` に見える。
/// だから出すのは「ここを復習」までで、「あなたは誤解している」とは言わない。
class DossierBar extends StatelessWidget {
  const DossierBar({super.key, required this.dossier});

  final Dossier dossier;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('説明できたところ', style: t.textTheme.labelLarge),
              const Spacer(),
              Text('${dossier.coverage}%',
                  style: t.textTheme.labelLarge?.jaWeight(FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Semantics(
            label: '説明できたところ',
            value: '${dossier.coverage}パーセント',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: dossier.coverage / 100,
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHigh,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in dossier.slots)
                _ConceptChip(label: s.label, status: statusOf(s)),
            ],
          ),
        ],
      ),
    );
  }
}

/// カルテのスロットを画面の4状態へ写す。
///
/// **`unclear` を [ExplainStatus.weak] に落とさない。**
/// 判断がついていないものを「できていない」側に置くと、
/// 触れてもいないことを突きつけることになる。
ExplainStatus statusOf(Slot slot) {
  if (slot.isEmpty) return ExplainStatus.untouched;
  if (slot.hasAcceptedMisconception) return ExplainStatus.weak;
  return switch (slot.status) {
    SlotStatus.explained => ExplainStatus.gotIt,
    SlotStatus.thin => ExplainStatus.shaky,
    SlotStatus.untouched => ExplainStatus.untouched,
  };
}

class _ConceptChip extends StatelessWidget {
  const _ConceptChip({required this.label, required this.status});

  final String label;
  final ExplainStatus status;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    final fg = c.fgFor(status);

    return Semantics(
      label: '$label は ${statusLabel(status)}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: c.chipFor(status),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 色だけで状態を伝えない (SC 1.4.1)
            Icon(statusIcon(status), size: 16, color: fg),
            const SizedBox(width: 5),
            Text(label,
                style: t.textTheme.bodyMedium?.copyWith(color: fg, height: 1.0)),
          ],
        ),
      ),
    );
  }
}
