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
  /// 前回の状態。**達成の瞬間を捕まえるために持つ。**
  Map<String, ExplainStatus> _previous = const {};

  /// いま祝っている概念。演出が終わったら消す
  final Set<String> _celebrating = {};

  @override
  void initState() {
    super.initState();
    _previous = _snapshot(widget.dossier);
  }

  @override
  void didUpdateWidget(DossierBar old) {
    super.didUpdateWidget(old);
    final now = _snapshot(widget.dossier);
    final improved = <String>{};
    for (final e in now.entries) {
      final before = _previous[e.key];
      if (before == null) continue;
      // 「説明できた」に**上がった**ときだけ祝う。下がったときは何もしない
      if (e.value == ExplainStatus.gotIt && before != ExplainStatus.gotIt) {
        improved.add(e.key);
      }
    }
    _previous = now;
    if (improved.isEmpty) return;

    setState(() => _celebrating.addAll(improved));
    // 触覚は**添えるだけ**。Android API 30 未満では鳴らないので、
    // これ単体で達成を伝えてはいけない（色・形・文言が本体）
    Motion.celebrateHaptic();
    Future<void>.delayed(Motion.celebrate * 2, () {
      if (mounted) setState(() => _celebrating.removeAll(improved));
    });
  }

  Map<String, ExplainStatus> _snapshot(Dossier d) =>
      {for (final s in d.slots) s.key: statusOf(s)};

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
              Text('${widget.dossier.coverage}%',
                  style: t.textTheme.labelLarge?.jaWeight(FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Semantics(
            label: '説明できたところ',
            value: '${widget.dossier.coverage}パーセント',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              // 値が変わったら補間する。Tween は使い回さない
              // （TweenAnimationBuilder は渡した Tween を破壊的に書き換える）
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: widget.dossier.coverage / 100),
                duration: Motion.state,
                curve: Motion.stateCurve,
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  backgroundColor: scheme.surfaceContainerHigh,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final s in widget.dossier.slots)
                _ConceptChip(
                  label: s.label,
                  status: statusOf(s),
                  celebrating: _celebrating.contains(s.key),
                ),
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
  const _ConceptChip({
    required this.label,
    required this.status,
    this.celebrating = false,
  });

  final String label;
  final ExplainStatus status;

  /// いま「説明できた」に上がったところ
  final bool celebrating;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    final fg = c.fgFor(status);
    final reduce = ReduceMotionScope.of(context);

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.chipFor(status),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        // 祝っている間は枠でも示す。**動きだけに頼らない**
        border: celebrating ? Border.all(color: fg, width: 2) : null,
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
    );

    return Semantics(
      label: '$label は ${statusLabel(status)}',
      excludeSemantics: true,
      child: reduce || !celebrating
          ? chip
          // 達成の瞬間だけ expressive に振る。
          // 「画面内に入ってくる要素」用として仕様で定義されているカーブ
          : TweenAnimationBuilder<double>(
              key: const ValueKey('celebrate'),
              tween: Tween(begin: 0.85, end: 1.0),
              duration: Motion.celebrate,
              curve: Motion.celebrateCurve,
              builder: (context, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: chip,
            ),
    );
  }
}
