import '../config/app_language.dart';
import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../learning/domain/learning_economy.dart';
import '../models/game_path.dart';
import '../models/unit.dart';
import '../ui/_material.dart';
import 'cognitive_task_input.dart';
import 'game_activity_scaffold.dart';
import 'learning_path.dart';

/// 画面内だけにある構造化回答と、catalog v4の固定解を照合する。
///
/// 回答は文字列化・保存・callback化しない。この関数もboolしか返さないため、
/// Timed / Legendaryのrouteを離れた時点で回答内容は破棄される。
bool matchesCognitiveTaskSolution(
  LocalCognitiveTask task,
  CognitiveTaskResponse? response,
) => switch ((task.solution, response)) {
  (
    LocalSingleSelectSolution(:final selectedItemId),
    SingleSelectTaskResponse(selectedItemId: final actual),
  ) =>
    actual == selectedItemId,
  (
    LocalClassifySolution(:final targetByItemId),
    ClassifyTaskResponse(targetByItemId: final actual),
  ) =>
    actual.length == targetByItemId.length &&
        targetByItemId.entries.every(
          (entry) => actual[entry.key] == entry.value,
        ),
  (
    LocalSequenceSolution(:final orderedItemIds),
    SequenceTaskResponse(orderedItemIds: final actual),
  ) =>
    _sameOrder(actual, orderedItemIds),
  _ => false,
};

bool _sameOrder(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

class ScienceChallengeHeader extends StatelessWidget {
  const ScienceChallengeHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.icon,
    required this.accent,
    required this.onAccent,
    this.mascotStyle,
    this.mascotReaction = GameCharacterReaction.encourage,
  });

  final String eyebrow;
  final String title;
  final String body;
  final IconData icon;
  final Color accent;
  final Color onAccent;
  final LearningPathMascotStyle? mascotStyle;
  final GameCharacterReaction mascotReaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    return Semantics(
      container: true,
      header: true,
      label: t(
        '$eyebrow。$title。$body。デキすぎ君。${mascotReaction.semanticsLabel}',
        '$eyebrow. $title. $body. Dekisugi-kun. ${mascotReaction.semanticsLabel}',
      ),
      child: ExcludeSemantics(
        child: Container(
          key: const ValueKey('science-challenge-lab-brief'),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.benchRaised,
            borderRadius: BorderRadius.circular(GameTokens.radiusLg),
            border: Border.all(color: colors.border),
          ),
          child: Stack(
            children: [
              PositionedDirectional(
                start: 0,
                top: 0,
                bottom: 0,
                width: GameTokens.accentRuleWidth,
                child: ColoredBox(
                  key: const ValueKey('science-challenge-accent-rule'),
                  color: accent,
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  GameTokens.spaceXl + GameTokens.accentRuleWidth,
                  GameTokens.spaceXl,
                  GameTokens.spaceXl,
                  GameTokens.spaceXl,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox.square(
                      dimension: GameTokens.heroLeadingSize,
                      child: ScienceActivityMascotBadge(
                        icon: icon,
                        accent: accent,
                        onAccent: onAccent,
                        mascotStyle: mascotStyle,
                        mascotReaction: mascotReaction,
                      ),
                    ),
                    const SizedBox(width: GameTokens.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ScienceLabLabel(
                            color: accent,
                            foregroundColor: onAccent,
                            label: eyebrow,
                          ),
                          const SizedBox(height: GameTokens.spaceSm),
                          Text(
                            title,
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(color: colors.ink)
                                .jaWeight(FontWeight.w900),
                          ),
                          const SizedBox(height: GameTokens.spaceSm),
                          Text(
                            body,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 実験段階を示す、低角丸の標本ラベル。
class _ScienceLabLabel extends StatelessWidget {
  const _ScienceLabLabel({
    required this.color,
    required this.foregroundColor,
    required this.label,
  });

  final Color color;
  final Color foregroundColor;
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(GameTokens.radiusXs),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: GameTokens.spaceSm,
        vertical: GameTokens.spaceXs,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: foregroundColor)
            .jaWeight(FontWeight.w800),
      ),
    ),
  );
}

/// Static companion used at the entrance of learning activities.
///
/// It never loops an animation; the reaction changes only when its parent phase
/// changes. The small icon keeps the activity kind visible without replacing the
/// character with a generic symbol.
class ScienceActivityMascotBadge extends StatelessWidget {
  const ScienceActivityMascotBadge({
    super.key,
    required this.icon,
    required this.accent,
    required this.onAccent,
    this.mascotStyle,
    this.mascotReaction = GameCharacterReaction.encourage,
  });

  final IconData icon;
  final Color accent;
  final Color onAccent;
  final LearningPathMascotStyle? mascotStyle;
  final GameCharacterReaction mascotReaction;

  static const double _mascotSize = 52;
  static const double _activityBadgeSize = 20;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final resolvedMascotStyle =
        mascotStyle ?? GameActivityScaffold.mascotStyleOf(context);
    return Semantics(
      label: t(
        'デキすぎ君。${mascotReaction.semanticsLabel}',
        'Dekisugi-kun. ${mascotReaction.semanticsLabel}',
      ),
      child: ExcludeSemantics(
        child: SizedBox.square(
          key: const ValueKey('science-activity-mascot-badge'),
          dimension: GameTokens.heroLeadingSize,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                child: SizedBox.square(
                  dimension: _mascotSize,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        key: const ValueKey('science-activity-mascot-surface'),
                        decoration: BoxDecoration(
                          color: colors.bench,
                          borderRadius: BorderRadius.circular(
                            GameTokens.radiusSm,
                          ),
                          border: Border.all(
                            color: colors.inkMuted,
                            width: GameTokens.strongBorderWidth,
                          ),
                        ),
                      ),
                      PathMascotPreview(
                        key: const ValueKey('science-activity-mascot-region'),
                        reaction: mascotReaction,
                        size: _mascotSize,
                        style: resolvedMascotStyle,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  key: const ValueKey('science-activity-kind-icon'),
                  width: _activityBadgeSize,
                  height: _activityBadgeSize,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(GameTokens.radiusXs),
                    border: Border.all(
                      color: colors.bench,
                      width: GameTokens.strongBorderWidth,
                    ),
                  ),
                  child: Icon(icon, color: onAccent, size: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScienceChallengeSurface extends StatelessWidget {
  const ScienceChallengeSurface({
    super.key,
    required this.label,
    required this.child,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final Widget child;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    final foreground = foregroundColor ?? colors.ink;
    return Semantics(
      container: true,
      label: label,
      child: Container(
        padding: const EdgeInsets.all(GameTokens.spaceLg),
        decoration: BoxDecoration(
          color: backgroundColor ?? colors.surface,
          borderRadius: BorderRadius.circular(GameTokens.radiusMd),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: foreground),
                  const SizedBox(width: GameTokens.spaceSm),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: foreground)
                        .jaWeight(FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: GameTokens.spaceSm),
            DefaultTextStyle.merge(
              style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class ScienceChallengePrimaryButton extends StatelessWidget {
  const ScienceChallengePrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(56),
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
    ),
    icon: Icon(icon),
    label: Text(label),
  );
}

class ScienceChallengePrivacyNote extends StatelessWidget {
  const ScienceChallengePrivacyNote({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    return Semantics(
      container: true,
      label: t(
        '回答は保存も送信もせず、復習コードだけを端末に保存し、成績や理解度の認定には使いません',
        'Answers are not saved or sent. Only a review code is saved on this device, and it is never used for grades or to certify understanding',
      ),
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.phonelink_lock_outlined, color: colors.inkMuted),
            const SizedBox(width: GameTokens.spaceSm),
            Expanded(
              child: Text(
                t(
                  '回答・選択内容は保存も送信もしません。復習が必要な場合も、固定の復習コードだけをこの端末に保存し、成績や理解度の認定には使いません。',
                  'Your answers and choices are not saved or sent. If a review is needed, only a fixed review code is saved on this device. It is never used for grades or to certify understanding.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.inkMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// submit後だけ構築する、本人の回答とcatalog v4正本の比較。
class ScienceChallengeComparison extends StatelessWidget {
  const ScienceChallengeComparison({
    super.key,
    required this.task,
    required this.response,
    required this.expectedOutcome,
    required this.expectedReason,
    required this.checkpoint,
    required this.selectedCheckpointOptionId,
  });

  final LocalCognitiveTask task;
  final CognitiveTaskResponse response;
  final String expectedOutcome;
  final String expectedReason;
  final LocalCheckpoint checkpoint;
  final String selectedCheckpointOptionId;

  @override
  Widget build(BuildContext context) {
    final selected = checkpoint.optionFor(selectedCheckpointOptionId);
    final correct = checkpoint.optionFor(checkpoint.correctOptionId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CognitiveTaskResponseSummary(
          prompt: task.prompt,
          response: response,
          label: t('あなたの組み方', 'Your approach'),
        ),
        const SizedBox(height: GameTokens.spaceMd),
        ScienceChallengeSurface(
          label: t('教材の組み方', 'The lesson approach'),
          icon: Icons.account_tree_outlined,
          child: Text(cognitiveTaskSolutionSummary(task)),
        ),
        const SizedBox(height: GameTokens.spaceMd),
        ScienceChallengeSurface(
          label: t('観察と理由', 'Observation and reason'),
          icon: Icons.science_outlined,
          child: Text('$expectedOutcome\n\n$expectedReason'),
        ),
        const SizedBox(height: GameTokens.spaceMd),
        ScienceChallengeSurface(
          label: t('思い込みの直し方', 'Fixing the misconception'),
          icon: Icons.fact_check_outlined,
          child: Text(
            t(
              'あなたの判断：${selected?.text ?? '未回答'}\n'
                  '教材の判断：${correct?.text ?? ''}\n\n'
                  '${checkpoint.explanation}',
              'Your answer: ${selected?.text ?? 'No answer'}\n'
                  'Lesson answer: ${correct?.text ?? ''}\n\n'
                  '${checkpoint.explanation}',
            ),
          ),
        ),
      ],
    );
  }
}
