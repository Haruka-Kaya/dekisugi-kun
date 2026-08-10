import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../learning/domain/learning_economy.dart';
import '../models/game_path.dart';
import '../models/unit.dart';
import '../ui/_material.dart';
import 'cognitive_task_input.dart';
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
    this.mascotStyle = LearningPathMascotStyle.standard,
    this.mascotReaction = GameCharacterReaction.encourage,
  });

  final String eyebrow;
  final String title;
  final String body;
  final IconData icon;
  final Color accent;
  final Color onAccent;
  final LearningPathMascotStyle mascotStyle;
  final GameCharacterReaction mascotReaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      header: true,
      label: '$eyebrow。$title。$body。デキすぎ君。${mascotReaction.semanticsLabel}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(GameTokens.spaceXl),
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(GameTokens.radiusLg),
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
                    Text(
                      eyebrow,
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: onAccent)
                          .jaWeight(FontWeight.w800),
                    ),
                    const SizedBox(height: GameTokens.spaceXs),
                    Text(
                      title,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(color: onAccent)
                          .jaWeight(FontWeight.w900),
                    ),
                    const SizedBox(height: GameTokens.spaceSm),
                    Text(
                      body,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: onAccent,
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
    this.mascotStyle = LearningPathMascotStyle.standard,
    this.mascotReaction = GameCharacterReaction.encourage,
  });

  final IconData icon;
  final Color accent;
  final Color onAccent;
  final LearningPathMascotStyle mascotStyle;
  final GameCharacterReaction mascotReaction;

  static const double _mascotSize = 52;
  static const double _activityBadgeSize = 20;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'デキすぎ君。${mascotReaction.semanticsLabel}',
    child: ExcludeSemantics(
      child: SizedBox.square(
        key: const ValueKey('science-activity-mascot-badge'),
        dimension: GameTokens.heroLeadingSize,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: PathMascotPreview(
                key: const ValueKey('science-activity-mascot-region'),
                reaction: mascotReaction,
                size: _mascotSize,
                style: mascotStyle,
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
                  color: onAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: accent, width: 2),
                ),
                child: Icon(icon, color: accent, size: 12),
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
      label: '回答は保存も送信もせず、復習コードだけを端末に保存し、成績や理解度の認定には使いません',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.phonelink_lock_outlined, color: colors.inkMuted),
            const SizedBox(width: GameTokens.spaceSm),
            Expanded(
              child: Text(
                '回答・選択内容は保存も送信もしません。復習が必要な場合も、固定の復習コードだけをこの端末に保存し、成績や理解度の認定には使いません。',
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
          label: 'あなたの組み方',
        ),
        const SizedBox(height: GameTokens.spaceMd),
        ScienceChallengeSurface(
          label: '教材の組み方',
          icon: Icons.account_tree_outlined,
          child: Text(cognitiveTaskSolutionSummary(task)),
        ),
        const SizedBox(height: GameTokens.spaceMd),
        ScienceChallengeSurface(
          label: '観察と理由',
          icon: Icons.science_outlined,
          child: Text('$expectedOutcome\n\n$expectedReason'),
        ),
        const SizedBox(height: GameTokens.spaceMd),
        ScienceChallengeSurface(
          label: '思い込みの直し方',
          icon: Icons.fact_check_outlined,
          child: Text(
            'あなたの判断：${selected?.text ?? '未回答'}\n'
            '教材の判断：${correct?.text ?? ''}\n\n'
            '${checkpoint.explanation}',
          ),
        ),
      ],
    );
  }
}
