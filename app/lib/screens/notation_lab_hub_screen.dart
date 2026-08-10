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
    final hero = _notationHeroState(entries);
    final primaryEntry = hero.primaryEntry;
    return GamePageScaffold(
      scrollKey: const ValueKey('notation-lab-hub'),
      children: [
        GameHeroSurface(
          surfaceKey: const ValueKey('notation-lab-hero'),
          color: colors.story,
          foregroundColor: colors.onStory,
          eyebrow: hero.eyebrow,
          title: hero.title,
          body: hero.body,
          semanticSummary:
              '記号ラボ。利用できる課題$available件。復習$reviewDue件。'
              '${hero.semanticState}',
          mascotReaction: hero.reaction,
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
          primaryAction: primaryEntry == null
              ? null
              : FilledButton.icon(
                  key: const ValueKey('notation-lab-primary-action'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.surface,
                    foregroundColor: colors.story,
                    minimumSize: const Size.fromHeight(
                      GameTokens.minTouchTarget,
                    ),
                  ),
                  onPressed: () => onOpen(primaryEntry),
                  icon: Icon(hero.actionIcon),
                  label: Text(hero.actionLabel!),
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

typedef _NotationHeroState = ({
  String eyebrow,
  String title,
  String body,
  String semanticState,
  GameCharacterReaction reaction,
  NotationLabEntry? primaryEntry,
  String? actionLabel,
  IconData? actionIcon,
});

_NotationHeroState _notationHeroState(List<NotationLabEntry> entries) {
  NotationLabEntry? firstWith(NotationLabState state) {
    for (final entry in entries) {
      if (entry.state == state) return entry;
    }
    return null;
  }

  final primary =
      firstWith(NotationLabState.reviewDue) ??
      firstWith(NotationLabState.available);
  if (primary != null) {
    return switch (primary.state) {
      NotationLabState.reviewDue => (
        eyebrow: '記号ラボ ・ 復習',
        title: '「${primary.conceptLabel}」をもう一度',
        body: '${primary.description}「なぞる→組む→読む」の順で思い出します。',
        semanticState: '次は${primary.conceptLabel}を復習します',
        reaction: GameCharacterReaction.encourage,
        primaryEntry: primary,
        actionLabel: '復習をはじめる',
        actionIcon: Icons.replay_rounded,
      ),
      NotationLabState.available => (
        eyebrow: '記号ラボ ・ 次の課題',
        title: primary.conceptLabel,
        body: '${primary.description}記号が表す量と条件を順にたしかめます。',
        semanticState: '次は${primary.conceptLabel}の課題を開きます',
        reaction: GameCharacterReaction.invite,
        primaryEntry: primary,
        actionLabel: '次の課題を開く',
        actionIcon: Icons.play_arrow_rounded,
      ),
      _ => throw StateError(
        'Unsupported primary notation state: ${primary.state}',
      ),
    };
  }

  final allCompleted =
      entries.isNotEmpty &&
      entries.every((entry) => entry.state == NotationLabState.completed);
  if (allCompleted) {
    return (
      eyebrow: '記号ラボ ・ 練習済み',
      title: 'すべての記号課題を練習しました',
      body: '式・単位・矢印・グラフを、次の理科の問いで使えます。',
      semanticState: 'すべての記号課題を練習済みです',
      reaction: GameCharacterReaction.celebrate,
      primaryEntry: null,
      actionLabel: null,
      actionIcon: null,
    );
  }

  if (entries.isEmpty) {
    return (
      eyebrow: '記号ラボ',
      title: '最初の記号課題を準備中',
      body: '学習パスを進めると、式・単位・矢印・グラフの課題が加わります。',
      semanticState: '記号課題を準備中です',
      reaction: GameCharacterReaction.invite,
      primaryEntry: null,
      actionLabel: null,
      actionIcon: null,
    );
  }

  return (
    eyebrow: '記号ラボ ・ 未解放',
    title: '次の記号課題は学習パスで解放',
    body: '現在の必修ノードを終えると、次の記号課題を利用できます。',
    semanticState: '利用できる記号課題はまだありません',
    reaction: GameCharacterReaction.invite,
    primaryEntry: null,
    actionLabel: null,
    actionIcon: null,
  );
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
