import '../config/app_language.dart';
import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../ui/_material.dart';

/// 時間制ミニゲームで共通利用する、アニメーションしない残り時間表示。
///
/// 残り時間は画面内の一時状態だけで、回答や速度と一緒に外へ渡さない。
class ScienceMiniGameCountdown extends StatelessWidget {
  const ScienceMiniGameCountdown({
    super.key,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.stepLabel,
  }) : assert(remainingSeconds >= 0),
       assert(totalSeconds > 0);

  final int remainingSeconds;
  final int totalSeconds;
  final String stepLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    final progress = (remainingSeconds / totalSeconds).clamp(0.0, 1.0);
    return Semantics(
      key: const ValueKey('science-mini-game-countdown'),
      container: true,
      liveRegion: true,
      label: t(
        '$stepLabel。残り時間$remainingSeconds秒',
        '$stepLabel. $remainingSeconds seconds left',
      ),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(GameTokens.spaceLg),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(GameTokens.radiusMd),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: GameTokens.spaceSm,
                runSpacing: GameTokens.spaceXs,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Text(
                    stepLabel,
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: colors.ink)
                        .jaWeight(FontWeight.w800),
                  ),
                  Text(
                    t('残り $remainingSeconds 秒', '$remainingSeconds s left'),
                    style: theme.textTheme.labelLarge
                        ?.copyWith(color: colors.pathReview)
                        .jaWeight(FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: GameTokens.spaceSm),
              LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                color: colors.pathReview,
                backgroundColor: colors.border,
                borderRadius: BorderRadius.circular(GameTokens.radiusPill),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 色だけに頼らず、番号・文言・選択状態をSemanticsにも返す選択肢。
class ScienceMiniGameChoice extends StatelessWidget {
  const ScienceMiniGameChoice({
    super.key,
    required this.text,
    required this.position,
    required this.count,
    required this.selected,
    required this.onPressed,
  }) : assert(position > 0),
       assert(count >= position);

  final String text;
  final int position;
  final int count;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      selected: selected,
      label: t(
        '選択肢$position/$count。$text。${selected ? '選択中' : '未選択'}',
        'Choice $position/$count. $text. ${selected ? 'Selected' : 'Not selected'}',
      ),
      child: ExcludeSemantics(
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            alignment: Alignment.centerLeft,
            foregroundColor: selected ? colors.onPathActive : colors.ink,
            backgroundColor: selected ? colors.pathActive : colors.surface,
            side: BorderSide(
              color: selected ? colors.pathActive : colors.border,
              width: selected ? 2 : 1,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: GameTokens.spaceLg,
              vertical: GameTokens.spaceMd,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              const SizedBox(width: GameTokens.spaceSm),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      ),
    );
  }
}
