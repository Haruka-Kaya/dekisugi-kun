import '../config/app_radius.dart';
import '../config/app_theme.dart';
import '../config/motion.dart';
import '../models/dossier.dart';
import '../ui/_material.dart';

/// 理解カルテを1行にまとめて出す。
///
/// **「弱点」と断定しない**（C9）。
/// 誘発の判定は行動の観測でしかなく、聞き流しただけでも `accepted` に見える。
/// だから出すのは「ここを復習」までで、「あなたは誤解している」とは言わない。
class DossierBar extends StatefulWidget {
  const DossierBar({super.key, required this.dossier});

  final Dossier dossier;

  @override
  State<DossierBar> createState() => _DossierBarState();
}

class _DossierBarState extends State<DossierBar> {
  /// 前回のカルテ。**達成の瞬間を捕まえるためだけに持つ。**
  Dossier? _previous;

  /// いま祝っている概念。演出が終わったら消す
  final Set<String> _celebrating = {};

  @override
  void initState() {
    super.initState();
    _previous = widget.dossier;
  }

  @override
  void didUpdateWidget(DossierBar old) {
    super.didUpdateWidget(old);
    // **記録と同じ根拠で数える**（`newlyExplained`）。
    // 別々に数えると、祝ったのに連続に付かない（逆も）が起きる。
    // 下がったときは何もしない
    final improved = newlyExplained(_previous, widget.dossier);
    _previous = widget.dossier;
    if (improved.isEmpty) return;

    setState(() => _celebrating.addAll(improved));
    // 触覚は**添えるだけ**。Android API 30 未満では鳴らないので、
    // これ単体で達成を伝えてはいけない（色・形・文言が本体）
    Motion.celebrateHaptic();
    Future<void>.delayed(Motion.celebrate * 2, () {
      if (mounted) setState(() => _celebrating.removeAll(improved));
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    final visible = widget.dossier.slots.where((s) => !s.isEmpty).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    final newlySaved = _celebrating.isNotEmpty;
    final panel = Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: c.coolSurface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        border: newlySaved ? Border.all(color: c.gotItFg, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                newlySaved ? Icons.edit_note : Icons.notes,
                size: 21,
                color: c.onCoolSurface,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  liveRegion: newlySaved,
                  child: Text(
                    newlySaved ? '今の説明をノートに残しました' : 'いまの会話ノート',
                    style: t.textTheme.titleSmall
                        ?.copyWith(color: c.onCoolSurface)
                        .jaWeight(FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final slot in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: _NoteLine(slot: slot),
            ),
        ],
      ),
    );

    final reduce = ReduceMotionScope.of(context);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: reduce || !newlySaved
          ? panel
          : TweenAnimationBuilder<double>(
              key: const ValueKey('celebrate'),
              tween: Tween(begin: 0.96, end: 1.0),
              duration: Motion.celebrate,
              curve: Motion.celebrateCurve,
              builder: (context, v, child) => Transform.scale(
                scale: v,
                alignment: Alignment.topCenter,
                child: child,
              ),
              child: panel,
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

class _NoteLine extends StatelessWidget {
  const _NoteLine({required this.slot});

  final Slot slot;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    final status = statusOf(slot);
    final fg = c.fgFor(status);
    return Semantics(
      label: '${slot.label} は ${statusLabel(status)}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(statusIcon(status), size: 17, color: fg),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              slot.label,
              style: t.textTheme.bodyMedium?.copyWith(color: c.onCoolSurface),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: c.chipFor(status),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(
              statusLabel(status),
              style: t.textTheme.labelSmall
                  ?.copyWith(color: fg)
                  .jaWeight(FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
