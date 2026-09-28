import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../learning/domain/learning_economy.dart';
import '../models/game_path.dart';
import '../ui/_material.dart';
import 'learning_path.dart';

/// Orbit Lab のハブ画面で共有する、幅・余白・背景の骨格。
///
/// 画面ごとに `ListView + padding + maxWidth` を作り直さない。小さい端末では
/// 16dp、通常端末では24dpの余白を使い、広い端末では本文幅だけを止める。
class GamePageScaffold extends StatelessWidget {
  const GamePageScaffold({
    super.key,
    required this.scrollKey,
    required this.children,
    this.maxWidth = GameTokens.gamePageMaxWidth,
  });

  final Key scrollKey;
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final width = MediaQuery.sizeOf(context).width;
    final gutter = width < 360 ? GameTokens.spaceLg : GameTokens.spaceXl;
    return ColoredBox(
      color: colors.canvas,
      child: SafeArea(
        bottom: false,
        child: ListView(
          key: scrollKey,
          padding: EdgeInsets.fromLTRB(
            gutter,
            GameTokens.spaceXl,
            gutter,
            GameTokens.gamePageBottomPadding +
                MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 1画面に1つだけ置く主役面。色・角丸・余白を全ハブで揃える。
class GameHeroSurface extends StatelessWidget {
  const GameHeroSurface({
    super.key,
    this.surfaceKey,
    required this.color,
    required this.foregroundColor,
    required this.eyebrow,
    required this.title,
    required this.body,
    this.leading,
    this.mascotReaction,
    this.mascotStyle = LearningPathMascotStyle.standard,
    this.semanticSummary,
    this.trailing,
    this.content,
    this.primaryAction,
  }) : assert(
         leading != null || mascotReaction != null,
         'GameHeroSurface needs a leading widget or mascot reaction.',
       );

  final Color color;
  final Key? surfaceKey;
  final Color foregroundColor;
  final String eyebrow;
  final String title;
  final String body;
  final Widget? leading;
  final GameCharacterReaction? mascotReaction;
  final LearningPathMascotStyle mascotStyle;
  final String? semanticSummary;
  final Widget? trailing;
  final Widget? content;
  final Widget? primaryAction;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget excludeFromSummary(Widget child) =>
        semanticSummary == null ? child : ExcludeSemantics(child: child);

    return Semantics(
      container: true,
      explicitChildNodes: true,
      header: semanticSummary != null,
      label: semanticSummary,
      child: Container(
        key: surfaceKey,
        padding: const EdgeInsets.all(GameTokens.spaceXl),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(GameTokens.radiusLg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox.square(
                  dimension: GameTokens.heroLeadingSize,
                  child: mascotReaction == null
                      ? Center(child: leading)
                      : _GameHeroMascot(
                          reaction: mascotReaction!,
                          style: mascotStyle,
                        ),
                ),
                const SizedBox(width: GameTokens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      excludeFromSummary(
                        Text(
                          eyebrow,
                          style: t.labelLarge
                              ?.copyWith(color: foregroundColor)
                              .jaWeight(FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: GameTokens.spaceXs),
                      excludeFromSummary(
                        Semantics(
                          header: true,
                          child: Text(
                            title,
                            style: t.headlineSmall
                                ?.copyWith(
                                  color: foregroundColor,
                                  height: GameTokens.heroTitleLineHeight,
                                )
                                .jaWeight(FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: GameTokens.spaceSm),
                  trailing!,
                ],
              ],
            ),
            const SizedBox(height: GameTokens.spaceMd),
            excludeFromSummary(
              Text(body, style: t.bodyMedium?.copyWith(color: foregroundColor)),
            ),
            if (content != null) ...[
              const SizedBox(height: GameTokens.spaceLg),
              content!,
            ],
            if (primaryAction != null) ...[
              const SizedBox(height: GameTokens.spaceLg),
              primaryAction!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Hubごとに表情だけを変える静止マスコット。
///
/// Tickerや自動loopを持たず、Reduce Motionでも同じ表情とSemanticsを保つ。
class _GameHeroMascot extends StatelessWidget {
  const _GameHeroMascot({required this.reaction, required this.style});

  final GameCharacterReaction reaction;
  final LearningPathMascotStyle style;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Semantics(
      key: const ValueKey('game-hero-mascot'),
      image: true,
      label: '${style.label}が${reaction.semanticsLabel}',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: PathMascotPreview(
              reaction: reaction,
              size: GameTokens.heroMascotSize,
              style: style,
            ),
          ),
        ),
      ),
    );
  }
}

/// Hero左上の記号。画面ごとにサイズと円を作り直さない。
class GameHeroIcon extends StatelessWidget {
  const GameHeroIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.foregroundColor,
  });

  final IconData icon;
  final Color color;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: Center(
      child: Icon(icon, size: GameTokens.heroIconSize, color: foregroundColor),
    ),
  );
}

class GameSectionHeader extends StatelessWidget {
  const GameSectionHeader({
    super.key,
    required this.title,
    this.description,
    this.trailing,
  });

  final String title;
  final String? description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final colors = context.gamePalette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: t.titleLarge
                      ?.copyWith(color: colors.ink)
                      .jaWeight(FontWeight.w900),
                ),
              ),
              if (description case final description?) ...[
                const SizedBox(height: GameTokens.spaceXs),
                Text(
                  description,
                  style: t.bodySmall?.copyWith(color: colors.inkMuted),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: GameTokens.spaceSm),
          trailing!,
        ],
      ],
    );
  }
}

/// 汎用Cardを重ねず、役割のある情報だけを載せる一段の面。
class GameSolidSurface extends StatelessWidget {
  const GameSolidSurface({
    super.key,
    this.surfaceKey,
    required this.child,
    this.raised = false,
    this.accent,
    this.padding = const EdgeInsets.all(GameTokens.spaceLg),
  });

  final Widget child;
  final Key? surfaceKey;
  final bool raised;
  final Color? accent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Container(
      key: surfaceKey,
      padding: padding,
      decoration: BoxDecoration(
        color: raised ? colors.surfaceRaised : colors.surface,
        borderRadius: BorderRadius.circular(GameTokens.radiusMd),
        border: Border.all(
          color: accent ?? colors.border,
          width: accent == null ? 1 : GameTokens.strongBorderWidth,
        ),
      ),
      child: child,
    );
  }
}

/// 320dp・文字200%では1列、通常幅では2列、700dp以上では3列にする。
class GameResponsiveGrid extends StatelessWidget {
  const GameResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = GameTokens.spaceMd,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scaledBody = MediaQuery.textScalerOf(context).scale(16);
      final largeText = scaledBody >= 24;
      final columns = constraints.maxWidth >= 700 && !largeText
          ? 3
          : constraints.maxWidth >= 420 && !largeText
          ? 2
          : 1;
      final itemWidth =
          (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final child in children)
            SizedBox(width: itemWidth, child: child),
        ],
      );
    },
  );
}

/// ルールや設定など、主画面から一段下げる情報を安全にスクロール表示する。
Future<T?> showGamePageSheet<T>({
  required BuildContext context,
  required String title,
  required Widget child,
}) {
  final colors = context.gamePalette;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: colors.surface,
    constraints: const BoxConstraints(maxWidth: GameTokens.gameSheetMaxWidth),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(GameTokens.radiusSheet),
      ),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .88,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            GameTokens.spaceXl,
            0,
            GameTokens.spaceXl,
            GameTokens.spaceXl + MediaQuery.paddingOf(sheetContext).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(sheetContext).textTheme.headlineSmall
                      ?.copyWith(color: colors.ink)
                      .jaWeight(FontWeight.w900),
                ),
              ),
              const SizedBox(height: GameTokens.spaceLg),
              child,
            ],
          ),
        ),
      ),
    ),
  );
}
