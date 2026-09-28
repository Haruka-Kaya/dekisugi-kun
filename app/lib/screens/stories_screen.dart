import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../learning/domain/learning_economy.dart';
import '../models/game_hub.dart';
import '../models/game_path.dart';
import '../ui/_material.dart';
import '../widgets/game_page.dart';

class StoriesScreen extends StatelessWidget {
  const StoriesScreen({
    super.key,
    required this.episodes,
    required this.onOpen,
    this.mascotStyle = LearningPathMascotStyle.standard,
  });

  final List<StoryEpisodeView> episodes;
  final ValueChanged<StoryEpisodeView> onOpen;
  final LearningPathMascotStyle mascotStyle;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final readable = episodes
        .where((episode) => episode.state != GameContentState.locked)
        .length;
    final completed = episodes
        .where((episode) => episode.state == GameContentState.completed)
        .length;
    final hero = _storyHeroState(episodes);
    final primaryEpisode = hero.primaryEpisode;
    return GamePageScaffold(
      scrollKey: const ValueKey('stories-screen'),
      children: [
        GameHeroSurface(
          surfaceKey: const ValueKey('stories-hero'),
          color: colors.story,
          foregroundColor: colors.onStory,
          eyebrow: hero.eyebrow,
          title: hero.title,
          body: hero.body,
          semanticSummary:
              '理科事件簿。${episodes.length}件中$readable件が読めます。'
              '$completed件完了。${hero.semanticState}',
          mascotReaction: hero.reaction,
          mascotStyle: mascotStyle,
          content: GameSolidSurface(
            padding: const EdgeInsets.all(GameTokens.spaceMd),
            child: GameResponsiveGrid(
              spacing: GameTokens.spaceSm,
              children: [
                _StoryFact(
                  icon: Icons.menu_book_rounded,
                  label: '読める',
                  value: '$readable件',
                ),
                _StoryFact(
                  icon: Icons.check_circle_outline_rounded,
                  label: '解明済み',
                  value: '$completed件',
                ),
              ],
            ),
          ),
          primaryAction: primaryEpisode == null
              ? null
              : FilledButton.icon(
                  key: const ValueKey('stories-primary-action'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.surface,
                    foregroundColor: colors.story,
                    minimumSize: const Size.fromHeight(
                      GameTokens.minTouchTarget,
                    ),
                  ),
                  onPressed: () => onOpen(primaryEpisode),
                  icon: Icon(hero.actionIcon),
                  label: Text(hero.actionLabel!),
                ),
        ),
        const SizedBox(height: GameTokens.spaceXl),
        const GameSectionHeader(
          title: '事件ファイル',
          description: '未解放・続き・完了・復習を、形と文字で見分けます。',
        ),
        const SizedBox(height: GameTokens.spaceMd),
        if (episodes.isEmpty)
          const _EmptyStories()
        else
          GameResponsiveGrid(
            children: [
              for (final episode in episodes)
                _EpisodeCard(episode: episode, onOpen: () => onOpen(episode)),
            ],
          ),
      ],
    );
  }
}

typedef _StoryHeroState = ({
  String eyebrow,
  String title,
  String body,
  String semanticState,
  GameCharacterReaction reaction,
  StoryEpisodeView? primaryEpisode,
  String? actionLabel,
  IconData? actionIcon,
});

_StoryHeroState _storyHeroState(List<StoryEpisodeView> episodes) {
  StoryEpisodeView? firstWith(GameContentState state) {
    for (final episode in episodes) {
      if (episode.state == state) return episode;
    }
    return null;
  }

  final primary =
      firstWith(GameContentState.inProgress) ??
      firstWith(GameContentState.dueReview) ??
      firstWith(GameContentState.available);
  if (primary != null) {
    return switch (primary.state) {
      GameContentState.inProgress => (
        eyebrow: '理科事件簿 ・ 続き',
        title: '「${primary.title}」の続き',
        body: '前回の判断から再開し、観察と理由を最後までつなぎます。',
        semanticState: '続きの事件は${primary.title}です',
        reaction: GameCharacterReaction.encourage,
        primaryEpisode: primary,
        actionLabel: '続きから読む',
        actionIcon: Icons.play_arrow_rounded,
      ),
      GameContentState.dueReview => (
        eyebrow: '理科事件簿 ・ 再検証',
        title: '「${primary.title}」をもう一度',
        body: '前に解明した事件を、条件と結果を思い出しながら再検証します。',
        semanticState: '次は${primary.title}を再検証します',
        reaction: GameCharacterReaction.thinking,
        primaryEpisode: primary,
        actionLabel: 'もう一度調べる',
        actionIcon: Icons.replay_rounded,
      ),
      GameContentState.available => (
        eyebrow: '理科事件簿 ・ 次の事件',
        title: primary.title,
        body: '${primary.conceptLabel}の思い込みを、観察と理由で解き明かします。',
        semanticState: '次は${primary.title}を読みます',
        reaction: GameCharacterReaction.invite,
        primaryEpisode: primary,
        actionLabel: '事件を開く',
        actionIcon: Icons.menu_book_rounded,
      ),
      _ => throw StateError(
        'Unsupported primary story state: ${primary.state}',
      ),
    };
  }

  final allCompleted =
      episodes.isNotEmpty &&
      episodes.every((episode) => episode.state == GameContentState.completed);
  if (allCompleted) {
    return (
      eyebrow: '理科事件簿 ・ 解明済み',
      title: 'すべての事件を解明しました',
      body: '観察した条件と結果を、学習パスで次の問いにつなげられます。',
      semanticState: 'すべての事件を解明済みです',
      reaction: GameCharacterReaction.celebrate,
      primaryEpisode: null,
      actionLabel: null,
      actionIcon: null,
    );
  }

  if (episodes.isEmpty) {
    return (
      eyebrow: '理科事件簿',
      title: '最初の事件を準備中',
      body: '学習パスを進めると、ここに観察ストーリーが現れます。',
      semanticState: '事件を準備中です',
      reaction: GameCharacterReaction.invite,
      primaryEpisode: null,
      actionLabel: null,
      actionIcon: null,
    );
  }

  return (
    eyebrow: '理科事件簿 ・ 未解放',
    title: '次の事件は学習パスで解放',
    body: '現在の必修ノードを終えると、次の事件ファイルを読めます。',
    semanticState: '読める事件はまだありません',
    reaction: GameCharacterReaction.invite,
    primaryEpisode: null,
    actionLabel: null,
    actionIcon: null,
  );
}

class _EmptyStories extends StatelessWidget {
  const _EmptyStories();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    return Semantics(
      key: const ValueKey('stories-empty'),
      container: true,
      label: '事件簿はまだ未解放。学習パスを進めると開きます',
      child: ExcludeSemantics(
        child: GameSolidSurface(
          raised: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: GameTokens.minTouchTarget,
                height: GameTokens.minTouchTarget,
                decoration: BoxDecoration(
                  color: colors.pathLocked,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  color: colors.onPathLocked,
                ),
              ),
              const SizedBox(width: GameTokens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '事件簿はまだ未解放',
                      style: t.textTheme.titleMedium
                          ?.copyWith(color: colors.ink)
                          .jaWeight(FontWeight.w800),
                    ),
                    const SizedBox(height: GameTokens.spaceSm),
                    Text(
                      '学習パスを進めると、事件簿が開きます。',
                      style: t.textTheme.bodyMedium?.copyWith(
                        color: colors.inkMuted,
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

class _EpisodeCard extends StatelessWidget {
  const _EpisodeCard({required this.episode, required this.onOpen});

  final StoryEpisodeView episode;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    final enabled = episode.state != GameContentState.locked;
    final status = switch (episode.state) {
      GameContentState.locked => '未解放',
      GameContentState.available => '読めます',
      GameContentState.inProgress => '続きから',
      GameContentState.completed => '完了',
      GameContentState.dueReview => 'もう一度',
    };
    final icon = switch (episode.state) {
      GameContentState.locked => Icons.lock_outline_rounded,
      GameContentState.available => Icons.menu_book_rounded,
      GameContentState.inProgress => Icons.play_arrow_rounded,
      GameContentState.completed => Icons.check_rounded,
      GameContentState.dueReview => Icons.replay_rounded,
    };
    final nodeColor = switch (episode.state) {
      GameContentState.locked => colors.pathLocked,
      GameContentState.available => colors.story,
      GameContentState.inProgress => colors.pathActive,
      GameContentState.completed => colors.pathComplete,
      GameContentState.dueReview => colors.pathReview,
    };
    final onNodeColor = switch (episode.state) {
      GameContentState.locked => colors.onPathLocked,
      GameContentState.available => colors.onStory,
      GameContentState.inProgress => colors.onPathActive,
      GameContentState.completed => colors.onPathComplete,
      GameContentState.dueReview => colors.onPathReview,
    };
    final statusColor = enabled ? nodeColor : colors.inkMuted;
    return Semantics(
      button: enabled,
      enabled: enabled,
      label:
          '${episode.chapterLabel}、${episode.title}。${episode.conceptLabel}。'
          '$status。約${episode.minutes}分',
      onTap: enabled ? onOpen : null,
      child: ExcludeSemantics(
        child: Material(
          key: ValueKey('story-episode-${episode.id}'),
          color: enabled ? colors.surface : colors.surfaceRaised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GameTokens.radiusMd),
            side: BorderSide(color: colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onOpen : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: GameTokens.minTouchTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.all(GameTokens.spaceLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          key: ValueKey('story-node-${episode.id}'),
                          width: GameTokens.minTouchTarget,
                          height: GameTokens.minTouchTarget,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: nodeColor,
                            border: Border.all(
                              color: enabled ? nodeColor : colors.border,
                              width: GameTokens.strongBorderWidth,
                            ),
                          ),
                          child: Icon(icon, color: onNodeColor),
                        ),
                        const SizedBox(width: GameTokens.spaceMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                episode.chapterLabel,
                                style: t.textTheme.labelMedium
                                    ?.copyWith(
                                      color: enabled
                                          ? nodeColor
                                          : colors.inkMuted,
                                    )
                                    .jaWeight(FontWeight.w800),
                              ),
                              const SizedBox(height: GameTokens.spaceXs),
                              Text(
                                episode.title,
                                style: t.textTheme.titleMedium
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
                      '${episode.conceptLabel} ・ 約${episode.minutes}分',
                      style: t.textTheme.bodySmall?.copyWith(
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
                            status,
                            style: t.textTheme.labelMedium
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
      ),
    );
  }
}

class _StoryFact extends StatelessWidget {
  const _StoryFact({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Semantics(
      label: '$label、$value',
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: GameTokens.minTouchTarget,
          ),
          child: Row(
            children: [
              Icon(icon, color: colors.story),
              const SizedBox(width: GameTokens.spaceSm),
              Expanded(
                child: Text(
                  '$label $value',
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: colors.ink)
                      .jaWeight(FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
