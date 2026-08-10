import 'dart:async';
import 'dart:math' as math;

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

/// 保存成功後だけ表示する、Path共通の達成面。
///
/// 毎回の操作を跳ねさせず、完了時の500msだけをexpressiveにする。回答本文・
/// 正答率・反応時間は受け取らないため、測っていない理解度を演出のために作らない。
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
        borderRadius: BorderRadius.circular(GameTokens.radiusSheet),
        side: BorderSide(color: colors.border),
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
                  builder: (context, progress, child) => Transform.translate(
                    offset: Offset(0, (1 - progress) * 18),
                    child: Transform.scale(
                      scale: .82 + (.18 * progress),
                      child: Opacity(opacity: progress, child: child),
                    ),
                  ),
                  child: _CelebrationHero(mascotStyle: summary.mascotStyle),
                ),
                const SizedBox(height: GameTokens.spaceLg),
                Text(
                  summary.eyebrow,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: colors.pathComplete)
                      .jaWeight(FontWeight.w800),
                ),
                const SizedBox(height: GameTokens.spaceXs),
                Text(
                  summary.title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(color: colors.ink, height: 1.35)
                      .jaWeight(FontWeight.w800),
                ),
                const SizedBox(height: GameTokens.spaceSm),
                Text(
                  summary.message,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: colors.inkMuted),
                ),
                const SizedBox(height: GameTokens.spaceXl),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: GameTokens.spaceSm,
                  runSpacing: GameTokens.spaceSm,
                  children: [
                    if (summary.showPersonalRewards)
                      _CompletionMetric(
                        key: const ValueKey('completion-xp'),
                        icon: Icons.bolt_rounded,
                        value: '+${summary.xpAwarded}',
                        label: summary.xpAwarded == 0 ? 'XP（今回は加算なし）' : 'XP',
                        color: colors.streak,
                      ),
                    if (summary.showPersonalRewards && summary.gemsAwarded > 0)
                      _CompletionMetric(
                        key: const ValueKey('completion-gems'),
                        icon: Icons.diamond_rounded,
                        value: '+${summary.gemsAwarded}',
                        label: '結晶',
                        color: colors.gem,
                      ),
                    _CompletionMetric(
                      key: const ValueKey('completion-time'),
                      icon: Icons.timer_outlined,
                      value: _formatElapsed(summary.elapsed),
                      label: '今回の時間',
                      color: colors.pathReview,
                    ),
                  ],
                ),
                const SizedBox(height: GameTokens.spaceSm),
                Text(
                  '時間はこの完了画面だけに表示し、端末へ保存しません。',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
                ),
                const SizedBox(height: GameTokens.spaceXl),
                FilledButton.icon(
                  key: const ValueKey('completion-next-step'),
                  onPressed: () =>
                      Navigator.of(context).pop(GameCompletionAction.nextStep),
                  icon: const Icon(Icons.route_rounded),
                  label: const Text('次の一歩をマップで見る'),
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
                  label: const Text('学習結果を見直す'),
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

class _CelebrationHero extends StatelessWidget {
  const _CelebrationHero({required this.mascotStyle});

  final LearningPathMascotStyle mascotStyle;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return SizedBox(
      height: 146,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: CustomPaint(
                painter: _CelebrationBurstPainter(
                  primary: colors.pathComplete,
                  secondary: colors.legendary,
                  tertiary: colors.story,
                ),
              ),
            ),
          ),
          Semantics(
            label: '${mascotStyle.label}が笑顔で学習完了を祝っています',
            child: ExcludeSemantics(
              child: PathMascotPreview(
                reaction: GameCharacterReaction.celebrate,
                size: 112,
                style: mascotStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionMetric extends StatelessWidget {
  const _CompletionMetric({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Semantics(
      label: '$label、$value',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(
            minWidth: 132,
            minHeight: GameTokens.minTouchTarget,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: GameTokens.spaceMd,
            vertical: GameTokens.spaceSm,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(GameTokens.radiusMd),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: GameTokens.spaceSm),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: colors.ink)
                          .jaWeight(FontWeight.w800),
                    ),
                    Text(
                      label,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
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

class _CelebrationBurstPainter extends CustomPainter {
  const _CelebrationBurstPainter({
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });

  final Color primary;
  final Color secondary;
  final Color tertiary;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * .42;
    final colors = [primary, secondary, tertiary];
    for (var index = 0; index < 12; index++) {
      final angle = (math.pi * 2 * index / 12) - math.pi / 2;
      final distance = radius * (index.isEven ? .92 : .72);
      final point =
          center + Offset(math.cos(angle), math.sin(angle)) * distance;
      final paint = Paint()..color = colors[index % colors.length];
      if (index % 3 == 0) {
        final path = Path()
          ..moveTo(point.dx, point.dy - 5)
          ..lineTo(point.dx + 4, point.dy)
          ..lineTo(point.dx, point.dy + 5)
          ..lineTo(point.dx - 4, point.dy)
          ..close();
        canvas.drawPath(path, paint);
      } else {
        canvas.drawCircle(point, index.isEven ? 4 : 3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_CelebrationBurstPainter oldDelegate) =>
      oldDelegate.primary != primary ||
      oldDelegate.secondary != secondary ||
      oldDelegate.tertiary != tertiary;
}

String _formatElapsed(Duration elapsed) {
  final seconds = math.max(1, elapsed.inSeconds);
  final minutes = seconds ~/ 60;
  final rest = seconds % 60;
  if (minutes == 0) return '$seconds秒';
  if (minutes < 60) return '$minutes:${rest.toString().padLeft(2, '0')}';
  final hours = minutes ~/ 60;
  return '$hours:${(minutes % 60).toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
}
