import '../config/app_radius.dart';
import '../config/app_theme.dart';
import '../ui/_material.dart';

/// 「デキすぎ君」固有の画面骨格。
///
/// Material の Card / ListTile をそのまま並べると、内容が違っても全画面が
/// 設定画面のように見える。ここでは、会話・本人の言葉・補助導線の強さを
/// 面と余白で分ける。ゲームの盤面やポイント表示にはしない。

class StudioWordmark extends StatelessWidget {
  const StudioWordmark({super.key, this.action, this.actionTooltip});

  final VoidCallback? action;
  final String? actionTooltip;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;

    return Row(
      children: [
        const _AntennaMark(),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'デキすぎ君',
            style: t.textTheme.titleLarge?.jaWeight(FontWeight.w700),
          ),
        ),
        if (action != null)
          IconButton.filledTonal(
            tooltip: actionTooltip,
            onPressed: action,
            icon: const Icon(Icons.tune, size: 21),
            style: IconButton.styleFrom(
              backgroundColor: scheme.surfaceContainer,
              foregroundColor: scheme.onSurface,
            ),
          ),
      ],
    );
  }
}

class _AntennaMark extends StatelessWidget {
  const _AntennaMark();

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Semantics(
      excludeSemantics: true,
      child: SizedBox(
        width: 24,
        height: 30,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: c.charBody,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            Positioned(
              top: 1,
              right: 2,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: c.charAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StudioSectionHeader extends StatelessWidget {
  const StudioSectionHeader({
    super.key,
    required this.title,
    this.description,
    this.leading,
    this.trailing,
  });

  final String title;
  final String? description;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[
          Padding(padding: const EdgeInsets.only(top: 2), child: leading),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: t.textTheme.titleLarge?.jaWeight(FontWeight.w700),
              ),
              if (description != null) ...[
                const SizedBox(height: 4),
                Text(
                  description!,
                  style: t.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

/// 補助導線。一般的な ListTile の見た目を避け、1つの短い読み物として置く。
class StudioActionTile extends StatelessWidget {
  const StudioActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.warm = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool warm;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    final background = warm ? c.warmSurface : c.coolSurface;
    final foreground = warm ? c.onWarmSurface : c.onCoolSurface;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.xxl),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: foreground.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(icon, size: 21, color: foreground),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: t.textTheme.titleSmall
                          ?.copyWith(color: foreground)
                          .jaWeight(FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: t.textTheme.bodySmall?.copyWith(
                        color: foreground.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Icon(Icons.arrow_forward, size: 19, color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StudioPageIntro extends StatelessWidget {
  const StudioPageIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    this.body,
  });

  final String eyebrow;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: t.textTheme.labelMedium
              ?.copyWith(color: scheme.primary)
              .jaWeight(FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: t.textTheme.headlineMedium?.jaWeight(FontWeight.w700),
        ),
        if (body != null) ...[
          const SizedBox(height: 8),
          Text(
            body!,
            style: t.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
