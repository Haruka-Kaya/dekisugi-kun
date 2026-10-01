import 'dart:async';
import 'dart:math' as math;

import '../config/app_language.dart';
import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../config/motion.dart';
import '../learning/domain/learning_economy.dart';
import '../models/game_path.dart';
import '../ui/_material.dart';
import 'learning_path.dart';

enum GameCompletionAction { nextStep, reviewResult }

@immutable
class GameCompletionSummary {
  const GameCompletionSummary({
    required this.eyebrow,
    required this.title,
    required this.message,
    required this.elapsed,
    required this.xpAwarded,
    required this.gemsAwarded,
    required this.showPersonalRewards,
    this.mascotStyle = LearningPathMascotStyle.standard,
  }) : assert(xpAwarded >= 0),
       assert(gemsAwarded >= 0);

  final String eyebrow;
  final String title;
  final String message;

  /// この完了面だけに出す経過時間。保存層へは渡さない。
  final Duration elapsed;
  final int xpAwarded;
  final int gemsAwarded;
  final bool showPersonalRewards;
  final LearningPathMascotStyle mascotStyle;
}

Future<GameCompletionAction?> showGameCompletionCelebration(
  BuildContext context, {
  required GameCompletionSummary summary,
}) {
  unawaited(Motion.celebrateHaptic());
  final colors = context.gamePalette;
  return showDialog<GameCompletionAction>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    barrierColor: colors.ink.withValues(alpha: .48),
    builder: (dialogContext) => GameCompletionCelebration(summary: summary),
  );
}

/// 保存成功後だけ表示する、探究ノート共通の記録票。
///
/// 中央バーストや紙吹雪ではなく、保存した事実を一枚の観察記録として返す。
/// 回答本文・正答率・反応時間は受け取らないため、測っていない理解度を
/// 演出のために作らない。
class GameCompletionCelebration extends StatelessWidget {
  const GameCompletionCelebration({super.key, required this.summary});

  final GameCompletionSummary summary;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final reduceMotion = ReduceMotionScope.of(context);
    final viewport = MediaQuery.sizeOf(context);
    final maxHeight = math.max(320.0, viewport.height - GameTokens.spaceXl * 2);

    return Dialog(
      key: const ValueKey('game-completion-celebration'),
      elevation: 0,
      backgroundColor: colors.surface,
      insetPadding: const EdgeInsets.all(GameTokens.spaceMd),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GameTokens.radiusLg),
        side: BorderSide(color: colors.border, width: 2),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: maxHeight),
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          liveRegion: true,
          label: '${summary.title}。${summary.message}',
          child: SingleChildScrollView(
            key: const ValueKey('game-completion-scroll'),
            padding: const EdgeInsets.all(GameTokens.spaceXl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: reduceMotion ? Duration.zero : Motion.celebrate,
                  curve: Motion.celebrateCurve,
                  builder: (context, progress, child) => Opacity(
                    opacity: progress,
                    child: Transform.translate(
                      offset: Offset((1 - progress) * -12, 0),
                      child: child,
                    ),
                  ),
                  child: _ObservationRecordHeader(
                    eyebrow: _observationEyebrow(summary.eyebrow),
                    mascotStyle: summary.mascotStyle,
                  ),
                ),
                const SizedBox(height: GameTokens.spaceLg),
                ExcludeSemantics(
                  child: Text(
                    summary.title,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(color: colors.ink, height: 1.35)
                        .jaWeight(FontWeight.w800),
                  ),
                ),
                const SizedBox(height: GameTokens.spaceSm),
                ExcludeSemantics(
                  child: Text(
                    summary.message,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: colors.inkMuted),
                  ),
                ),
                const SizedBox(height: GameTokens.spaceXl),
                Container(
                  key: const ValueKey('completion-ledger'),
                  decoration: BoxDecoration(
                    color: colors.surfaceRaised,
                    borderRadius: BorderRadius.circular(GameTokens.radiusMd),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    children: [
                      if (summary.showPersonalRewards)
                        _CompletionMetric(
                          key: const ValueKey('completion-xp'),
                          icon: Icons.note_alt_outlined,
                          value: '+${summary.xpAwarded}',
                          label: summary.xpAwarded == 0
                              ? t(
                                  '探究記録（今回は加算なし）',
                                  'Observation record (none added this time)',
                                )
                              : t('探究記録', 'Observation record'),
                          color: colors.streak,
                        ),
                      if (summary.showPersonalRewards &&
                          summary.gemsAwarded > 0)
                        _CompletionMetric(
                          key: const ValueKey('completion-gems'),
                          icon: Icons.hexagon_outlined,
                          value: '+${summary.gemsAwarded}',
                          label: t('ひらめき結晶', 'Insight gems'),
                          color: colors.gem,
                        ),
                      _CompletionMetric(
                        key: ValueKey('completion-time'),
                        icon: Icons.schedule_outlined,
                        value: _formatElapsed(summary.elapsed),
                        label: t('今回の観察時間', 'Time this round'),
                        color: colors.pathReview,
                        last: true,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: GameTokens.spaceSm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_clock_outlined,
                      size: 18,
                      color: colors.inkMuted,
                    ),
                    SizedBox(width: GameTokens.spaceSm),
                    Expanded(
                      child: Text(
                        t(
                          '観察時間はこの記録票だけに表示し、端末へ保存しません。',
                          'Time is shown only on this screen and is not saved on the device.',
                        ),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: GameTokens.spaceXl),
                FilledButton.icon(
                  key: const ValueKey('completion-next-step'),
                  onPressed: () =>
                      Navigator.of(context).pop(GameCompletionAction.nextStep),
                  icon: Icon(Icons.arrow_forward_rounded),
                  label: Text(t('次の観察へ', 'Next observation')),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: colors.pathComplete,
                    foregroundColor: colors.onPathComplete,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(GameTokens.radiusMd),
                    ),
                  ),
                ),
                const SizedBox(height: GameTokens.spaceSm),
                OutlinedButton.icon(
                  key: const ValueKey('completion-review-result'),
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(GameCompletionAction.reviewResult),
                  icon: const Icon(Icons.visibility_outlined),
                  label: Text(t('今回の記録を見る', 'View this observation')),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(GameTokens.radiusMd),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ObservationRecordHeader extends StatelessWidget {
  const _ObservationRecordHeader({
    required this.eyebrow,
    required this.mascotStyle,
  });

  final String eyebrow;
  final LearningPathMascotStyle mascotStyle;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Container(
      key: const ValueKey('completion-record-header'),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(GameTokens.radiusMd),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(GameTokens.spaceMd),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Semantics(
                  label: t(
                    '${mascotStyle.label}が観察記録へ完了印を押しています',
                    '${mascotStyle.label} stamps this observation as complete',
                  ),
                  child: ExcludeSemantics(
                    child: Container(
                      width: 88,
                      height: 88,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(
                          GameTokens.radiusSm,
                        ),
                        border: Border.all(color: colors.border, width: 2),
                      ),
                      child: PathMascotPreview(
                        reaction: GameCharacterReaction.celebrate,
                        size: 82,
                        style: mascotStyle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: GameTokens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        eyebrow,
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: colors.inkMuted)
                            .jaWeight(FontWeight.w700),
                      ),
                      const SizedBox(height: GameTokens.spaceXs),
                      Row(
                        children: [
                          Icon(
                            Icons.task_alt_rounded,
                            color: colors.pathComplete,
                            size: 22,
                          ),
                          const SizedBox(width: GameTokens.spaceSm),
                          Expanded(
                            child: Text(
                              '観察記録を保存しました',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(color: colors.ink)
                                  .jaWeight(FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: ColoredBox(color: colors.pathComplete),
          ),
        ],
      ),
    );
  }
}

String _observationEyebrow(String source) {
  final upper = source.toUpperCase();
  if (source.contains(t('授業', 'Class')) || upper.contains('CLASS')) {
    return t('授業の観察記録', 'Class observation record');
  }
  if (source.contains(t('記号', 'Symbols')) ||
      source.contains(t('図解', 'Diagrams')) ||
      upper.contains('NOTATION')) {
    return t('記号実験の観察記録', 'Symbol observation record');
  }
  if (source.contains(t('事件', 'Cases')) || upper.contains('STORY')) {
    return t('事件簿の観察記録', 'Science case observation record');
  }
  if (source.contains(t('聞き取り', 'Listening')) || upper.contains('LISTEN')) {
    return t('聞き取りの観察記録', 'Listening observation record');
  }
  if (source.contains(t('教え返し', 'Teach-back')) || upper.contains('SPEAK')) {
    return t('教え返しの観察記録', 'Teach-back observation record');
  }
  if (source.contains(t('教材観察', 'Material observation'))) {
    return t('教材観察の記録', 'Material observation record');
  }
  if (source.contains(t('構造実験', 'Structured experiment'))) {
    return t('構造実験の観察記録', 'Experiment observation record');
  }
  if (source.contains(t('高難度', 'Advanced'))) {
    return t('高難度検証の観察記録', 'Advanced observation record');
  }
  if (source.contains(t('総合検証', 'Combined investigation'))) {
    return t('総合検証の観察記録', 'Combined investigation record');
  }
  if (upper.contains('BOSS') ||
      upper.contains('LEGENDARY') ||
      upper.contains('UNIT')) {
    return t('総合検証の観察記録', 'Combined investigation record');
  }
  return t('探究ノート / 保存済み', 'Field Notebook / Saved');
}

class _CompletionMetric extends StatelessWidget {
  const _CompletionMetric({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.last = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Semantics(
      label: '$label、$value',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(
            horizontal: GameTokens.spaceMd,
            vertical: GameTokens.spaceSm,
          ),
          decoration: BoxDecoration(
            border: last
                ? null
                : Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 32,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(GameTokens.radiusSm),
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(icon, color: color, size: 19),
                ),
              ),
              const SizedBox(width: GameTokens.spaceMd),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colors.inkMuted)
                      .jaWeight(FontWeight.w600),
                ),
              ),
              const SizedBox(width: GameTokens.spaceSm),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: colors.ink)
                    .jaWeight(FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatElapsed(Duration elapsed) {
  final seconds = math.max(1, elapsed.inSeconds);
  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  if (minutes == 0) return t('$seconds秒', '${seconds}s');
  if (minutes < 60) return '$minutes:${rest.toString().padLeft(2, '0')}';
  final hours = minutes ~/ 60;
  return '$hours:${(minutes % 60).toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
}
