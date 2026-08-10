import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../ui/_material.dart';
import 'emphasis_text.dart';

/// 教材を見ずに立てた予想と、教材の結果・理由を本人が照合する方法。
///
/// どちらを選んでも理解認定には使わない。入力は画面内の
/// [TextEditingController] にだけ置き、画面を閉じるまでの自己説明に使う。
enum PredictionComparisonDecision {
  keep,
  revise;

  String get actionLabel => switch (this) {
    keep => '残す点がある',
    revise => '直す点がある',
  };

  String get reflectionLabel => switch (this) {
    keep => '結果につながった自分の理由',
    revise => '教材を見て直す理由',
  };

  String get reflectionHint => switch (this) {
    keep => '例：空気抵抗がない条件まで考えられた',
    revise => '例：重さではなく、加速度を比べる',
  };
}

/// 「予測する → 結果を見る → 自分の説明を更新する」を1画面で完結させる。
///
/// このウィジェットは文字列の一致判定も正誤判定も行わない。[onComplete] に
/// 自由記述を渡さないため、練習完了callbackから回答が漏れない。
class PredictionResultCompare extends StatelessWidget {
  const PredictionResultCompare({
    super.key,
    required this.situation,
    required this.prediction,
    required this.predictionReason,
    required this.result,
    required this.explanation,
    required this.sourceParagraphs,
    required this.decision,
    required this.reflectionController,
    required this.onDecisionChanged,
    required this.onReflectionChanged,
    required this.onRewritePrediction,
    required this.onComplete,
  });

  final String situation;
  final String prediction;
  final String predictionReason;
  final String result;
  final String explanation;
  final List<String> sourceParagraphs;
  final PredictionComparisonDecision? decision;
  final TextEditingController reflectionController;
  final ValueChanged<PredictionComparisonDecision> onDecisionChanged;
  final VoidCallback onReflectionChanged;
  final VoidCallback onRewritePrediction;
  final VoidCallback onComplete;

  bool get _canComplete =>
      decision != null && reflectionController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;

    return Semantics(
      key: const ValueKey('prediction-result-compare'),
      container: true,
      liveRegion: true,
      label: 'チェックポイント通過。自分の予想と教材の結果を比べて、残す点か直す点を選んでください',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '予想と結果を、つなぐ',
            style: t.textTheme.titleLarge?.jaWeight(FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            '当てたかどうかではなく、どの理由を残し、どこを組み直すかを見つけます。',
            style: t.textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          _ComparisonSurface(
            key: const ValueKey('prediction-result-situation'),
            icon: Icons.science_outlined,
            label: '考えた場面',
            text: situation,
            background: colors.surface,
            foreground: colors.ink,
            border: colors.border,
          ),
          const SizedBox(height: 12),
          _ComparisonSurface(
            key: const ValueKey('prediction-result-prediction'),
            icon: Icons.edit_note_outlined,
            label: 'あなたの予想',
            text: prediction,
            background: colors.legendary,
            foreground: colors.onLegendary,
          ),
          const SizedBox(height: 10),
          _ComparisonSurface(
            key: const ValueKey('prediction-result-prediction-reason'),
            icon: Icons.lightbulb_outline,
            label: 'あなたの理由',
            text: predictionReason,
            background: colors.legendary,
            foreground: colors.onLegendary,
          ),
          const SizedBox(height: 8),
          ExcludeSemantics(
            child: Icon(Icons.south_rounded, color: colors.inkMuted, size: 26),
          ),
          const SizedBox(height: 8),
          _ComparisonSurface(
            key: const ValueKey('prediction-result-outcome'),
            icon: Icons.fact_check_outlined,
            label: '教材で確かめた結果',
            text: result,
            detailLabel: '教材の理由',
            detail: explanation,
            background: colors.surfaceRaised,
            foreground: colors.ink,
          ),
          if (sourceParagraphs.isNotEmpty) ...[
            const SizedBox(height: 10),
            Material(
              color: colors.surface,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: colors.border),
                borderRadius: BorderRadius.circular(GameTokens.radiusMd),
              ),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                key: const ValueKey('prediction-result-source'),
                title: Text(
                  '教材の根拠を読み直す',
                  style: t.textTheme.titleSmall?.jaWeight(FontWeight.w700),
                ),
                subtitle: const Text('必要なときだけ開く'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(),
                  const SizedBox(height: 10),
                  for (final paragraph in sourceParagraphs) ...[
                    EmphasisText(
                      paragraph,
                      style: t.textTheme.bodyMedium,
                      selectable: true,
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          Text(
            '比べて、どちらが近い？',
            style: t.textTheme.titleMedium?.jaWeight(FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            'アプリは一致・不一致を判定しません。自分で見つけた方を選びます。',
            style: t.textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
          ),
          const SizedBox(height: 12),
          _DecisionChoice(
            key: const ValueKey('prediction-result-decision-keep'),
            selected: decision == PredictionComparisonDecision.keep,
            icon: Icons.link_outlined,
            title: PredictionComparisonDecision.keep.actionLabel,
            body: '結果につながった、自分の理由を1つ残す',
            onTap: () => onDecisionChanged(PredictionComparisonDecision.keep),
          ),
          const SizedBox(height: 10),
          _DecisionChoice(
            key: const ValueKey('prediction-result-decision-revise'),
            selected: decision == PredictionComparisonDecision.revise,
            icon: Icons.construction_outlined,
            title: PredictionComparisonDecision.revise.actionLabel,
            body: '教材を見て変わった理由を1つ言葉にする',
            onTap: () => onDecisionChanged(PredictionComparisonDecision.revise),
          ),
          if (decision != null) ...[
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('prediction-result-reflection-input'),
              controller: reflectionController,
              minLines: 3,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              onChanged: (_) => onReflectionChanged(),
              decoration: InputDecoration(
                labelText: decision!.reflectionLabel,
                hintText: decision!.reflectionHint,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.phonelink_lock_outlined,
                  size: 18,
                  color: colors.inkMuted,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '比べるための一文です。採点・送信・保存はしません。',
                    style: t.textTheme.bodySmall?.copyWith(
                      color: colors.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const ValueKey('prediction-result-complete'),
            onPressed: _canComplete ? onComplete : null,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('見つけたことを持って完了'),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            key: const ValueKey('prediction-result-rewrite'),
            onPressed: onRewritePrediction,
            icon: const Icon(Icons.replay_outlined),
            label: const Text('結果を閉じて、予想を組み直す'),
          ),
        ],
      ),
    );
  }
}

class _ComparisonSurface extends StatelessWidget {
  const _ComparisonSurface({
    super.key,
    required this.icon,
    required this.label,
    required this.text,
    required this.background,
    required this.foreground,
    this.detailLabel,
    this.detail,
    this.border,
  });

  final IconData icon;
  final String label;
  final String text;
  final String? detailLabel;
  final String? detail;
  final Color background;
  final Color foreground;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
      decoration: BoxDecoration(
        color: background,
        border: border == null ? null : Border.all(color: border!),
        borderRadius: BorderRadius.circular(GameTokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(child: Icon(icon, size: 21, color: foreground)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: t.textTheme.labelLarge
                      ?.copyWith(color: foreground)
                      .jaWeight(FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            text,
            style: t.textTheme.bodyLarge?.copyWith(color: foreground),
          ),
          if (detail != null && detail!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: foreground.withValues(alpha: 0.24)),
            const SizedBox(height: 10),
            Text(
              detailLabel ?? '理由',
              style: t.textTheme.labelMedium
                  ?.copyWith(color: foreground)
                  .jaWeight(FontWeight.w700),
            ),
            const SizedBox(height: 4),
            SelectableText(
              detail!,
              style: t.textTheme.bodyMedium?.copyWith(color: foreground),
            ),
          ],
        ],
      ),
    );
  }
}

class _DecisionChoice extends StatelessWidget {
  const _DecisionChoice({
    super.key,
    required this.selected,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    return Semantics(
      button: true,
      selected: selected,
      onTap: onTap,
      label: '$title。$body',
      child: ExcludeSemantics(
        child: Material(
          color: selected ? colors.pathActive : colors.surface,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: selected ? colors.pathActive : colors.border,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(GameTokens.radiusMd),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      selected ? Icons.check_circle : icon,
                      color: selected ? colors.onPathActive : colors.inkMuted,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: t.textTheme.titleSmall
                                ?.copyWith(
                                  color: selected
                                      ? colors.onPathActive
                                      : colors.ink,
                                )
                                .jaWeight(FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            body,
                            style: t.textTheme.bodySmall?.copyWith(
                              color: selected
                                  ? colors.onPathActive
                                  : colors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
