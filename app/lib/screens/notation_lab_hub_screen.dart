import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../learning/domain/learning_economy.dart';
import '../models/game_path.dart';
import '../ui/_material.dart';
import '../widgets/game_page.dart';

enum NotationLabState { locked, available, completed, reviewDue }

@immutable
class NotationLabEntry {
  const NotationLabEntry({
    required this.id,
    required this.unitTitle,
    required this.conceptLabel,
    required this.description,
    required this.state,
  });

  final String id;
  final String unitTitle;
  final String conceptLabel;
  final String description;
  final NotationLabState state;

  bool get canOpen => state != NotationLabState.locked;
}

class NotationLabHubScreen extends StatelessWidget {
  const NotationLabHubScreen({
    super.key,
    required this.entries,
    required this.onOpen,
    this.mascotStyle = LearningPathMascotStyle.standard,
  });

  final List<NotationLabEntry> entries;
  final ValueChanged<NotationLabEntry> onOpen;
  final LearningPathMascotStyle mascotStyle;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final available = entries.where((entry) => entry.canOpen).length;
    final reviewDue = entries
        .where((entry) => entry.state == NotationLabState.reviewDue)
        .length;
    return GamePageScaffold(
      scrollKey: const ValueKey('notation-lab-hub'),
      children: [
        GameHeroSurface(
          surfaceKey: const ValueKey('notation-lab-hero'),
          color: colors.story,
          foregroundColor: colors.onStory,
          eyebrow: '数学表現を理科で使う',
          title: '記号ラボ',
          body: '式・単位・矢印・グラフを、「なぞる→組む→読む」の順で練習します。',
          semanticSummary: '記号ラボ。利用できる課題$available件。復習$reviewDue件',
          mascotReaction: GameCharacterReaction.thinking,
          mascotStyle: mascotStyle,
          content: GameSolidSurface(
            padding: const EdgeInsets.all(GameTokens.spaceMd),
            child: Row(
              children: [
                Icon(Icons.task_alt_rounded, color: colors.pathActive),
                const SizedBox(width: GameTokens.spaceSm),
                Expanded(
                  child: Text(
                    '利用できる課題 $available件'
                    '${reviewDue == 0 ? '' : ' ・ 復習 $reviewDue件'}',
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: colors.ink)
                        .jaWeight(FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: GameTokens.spaceXl),
        const GameSectionHeader(
          title: '記号の課題',
          description: '未解放・利用可・練習済み・復習を、アイコンと文字で表示します。',
        ),
        const SizedBox(height: GameTokens.spaceMd),
        if (entries.isEmpty)
          const GameSolidSurface(
            surfaceKey: ValueKey('notation-lab-empty'),
            raised: true,
            child: Text('学習パスを進めると、ここに記号の課題が加わります。'),
          )
        else
          GameResponsiveGrid(
            children: [
              for (final entry in entries)
                _EntryCard(
                  entry: entry,
                  onTap: entry.canOpen ? () => onOpen(entry) : null,
                ),
            ],
          ),
        const SizedBox(height: GameTokens.spaceXl),
        GameSolidSurface(
          surfaceKey: const ValueKey('notation-lab-guide'),
          raised: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.touch_app_outlined, color: colors.inkMuted),
              const SizedBox(width: GameTokens.spaceSm),
              Expanded(
                child: Text(
                  '答えを暗記するのではなく、記号が表す量と条件を順にたしかめます。',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.onTap});

  final NotationLabEntry entry;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    final (
      icon,
      label,
      tileColor,
      tileForeground,
      statusColor,
    ) = switch (entry.state) {
      NotationLabState.locked => (
        Icons.lock_outline_rounded,
        '未解放',
        colors.pathLocked,
        colors.onPathLocked,
        colors.inkMuted,
      ),
      NotationLabState.available => (
        Icons.play_arrow_rounded,
        '利用できます',
        colors.pathActive,
        colors.onPathActive,
        colors.pathActive,
      ),
      NotationLabState.completed => (
        Icons.check_rounded,
        '練習済み',
        colors.pathComplete,
        colors.onPathComplete,
        colors.pathComplete,
      ),
      NotationLabState.reviewDue => (
        Icons.replay_rounded,
        '復習できます',
        colors.pathReview,
        colors.onPathReview,
        colors.pathReview,
      ),
    };
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: '${entry.conceptLabel}の記号ラボ。$label。${entry.description}',
      child: ExcludeSemantics(
        child: Material(
          color: onTap == null ? colors.surfaceRaised : colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GameTokens.radiusMd),
            side: BorderSide(color: colors.border),
          ),
          child: InkWell(
            key: ValueKey('notation-entry-${entry.id}'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(GameTokens.radiusMd),
            child: Padding(
              padding: const EdgeInsets.all(GameTokens.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: GameTokens.minTouchTarget,
                        height: GameTokens.minTouchTarget,
                        decoration: BoxDecoration(
                          color: tileColor,
                          borderRadius: BorderRadius.circular(
                            GameTokens.radiusSm,
                          ),
                        ),
                        child: Icon(icon, color: tileForeground),
                      ),
                      const SizedBox(width: GameTokens.spaceMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.unitTitle,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colors.inkMuted,
                              ),
                            ),
                            const SizedBox(height: GameTokens.spaceXs),
                            Text(
                              entry.conceptLabel,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(color: colors.ink)
                                  .jaWeight(FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: GameTokens.spaceMd),
                  Text(
                    entry.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: GameTokens.spaceSm),
                  Row(
                    children: [
                      Icon(
                        icon,
                        size: GameTokens.statusIconSize,
                        color: statusColor,
                      ),
                      const SizedBox(width: GameTokens.spaceXs),
                      Expanded(
                        child: Text(
                          label,
                          style: theme.textTheme.labelMedium
                              ?.copyWith(color: statusColor)
                              .jaWeight(FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
