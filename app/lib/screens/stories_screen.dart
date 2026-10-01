import '../config/app_language.dart' as lang;
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
              lang.t(
                '理科事件簿。${episodes.length}件中$readable件が読めます。',
                'Science case files. $readable of ${episodes.length} available.',
              ) +
              lang.t(
                '$completed件完了。${hero.semanticState}',
                ' $completed completed. ${hero.semanticState}',
              ),
          mascotReaction: hero.reaction,
          mascotStyle: mascotStyle,
          content: GameSolidSurface(
            padding: const EdgeInsets.all(GameTokens.spaceMd),
            child: GameResponsiveGrid(
              spacing: GameTokens.spaceSm,
              children: [
                _StoryFact(
                  icon: Icons.menu_book_rounded,
                  label: lang.t('読める', 'Available'),
                  value: lang.t('$readable件', '$readable'),
                ),
                _StoryFact(
                  icon: Icons.check_circle_outline_rounded,
                  label: lang.t('解明済み', 'Solved'),
                  value: lang.t('$completed件', '$completed'),
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
        GameSectionHeader(
          title: lang.t('事件ファイル', 'Case files'),
          description: lang.t(
            '未解放・続き・完了・復習を、形と文字で見分けます。',
            'Use the shapes and labels to tell locked, in-progress, completed, and review cases apart.',
          ),
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
        eyebrow: lang.t('理科事件簿 ・ 続き', 'SCIENCE CASE FILES · CONTINUE'),
        title: lang.t('「${primary.title}」の続き', 'Continue "${primary.title}"'),
        body: lang.t(
          '前回の判断から再開し、観察と理由を最後までつなぎます。',
          'Pick up from your last choice and connect observations with reasons.',
        ),
        semanticState: lang.t(
          '続きの事件は${primary.title}です',
          'Continue the ${primary.title} case',
        ),
        reaction: GameCharacterReaction.encourage,
        primaryEpisode: primary,
        actionLabel: lang.t('続きから読む', 'Continue reading'),
        actionIcon: Icons.play_arrow_rounded,
      ),
      GameContentState.dueReview => (
        eyebrow: lang.t('理科事件簿 ・ 再検証', 'SCIENCE CASE FILES · REVISIT'),
        title: lang.t('「${primary.title}」をもう一度', 'Revisit "${primary.title}"'),
        body: lang.t(
          '前に解明した事件を、条件と結果を思い出しながら再検証します。',
          'Revisit a solved case and recall its conditions and results.',
        ),
        semanticState: lang.t(
          '次は${primary.title}を再検証します',
          'Next, revisit ${primary.title}',
        ),
        reaction: GameCharacterReaction.thinking,
        primaryEpisode: primary,
        actionLabel: lang.t('もう一度調べる', 'Investigate again'),
        actionIcon: Icons.replay_rounded,
      ),
      GameContentState.available => (
        eyebrow: lang.t('理科事件簿 ・ 次の事件', 'SCIENCE CASE FILES · NEXT CASE'),
        title: primary.title,
        body: lang.t(
          '${primary.conceptLabel}の思い込みを、観察と理由で解き明かします。',
          'Use observations and reasons to uncover the misconception about ${primary.conceptLabel}.',
        ),
        semanticState: lang.t(
          '次は${primary.title}を読みます',
          'Read ${primary.title} next',
        ),
        reaction: GameCharacterReaction.invite,
        primaryEpisode: primary,
        actionLabel: lang.t('事件を開く', 'Open case'),
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
      eyebrow: lang.t('理科事件簿 ・ 解明済み', 'SCIENCE CASE FILES · SOLVED'),
      title: lang.t('すべての事件を解明しました', 'All cases solved'),
      body: lang.t(
        '観察した条件と結果を、学習パスで次の問いにつなげられます。',
        'Use the conditions and results you observed to tackle the next question on your learning path.',
      ),
      semanticState: lang.t('すべての事件を解明済みです', 'All cases solved'),
      reaction: GameCharacterReaction.celebrate,
      primaryEpisode: null,
      actionLabel: null,
      actionIcon: null,
    );
  }

  if (episodes.isEmpty) {
    return (
      eyebrow: lang.t('理科事件簿', 'Science case files'),
      title: lang.t('最初の事件を準備中', 'Preparing your first case'),
      body: lang.t(
        '学習パスを進めると、ここに観察ストーリーが現れます。',
        'Move along the learning path to unlock an observation story here.',
      ),
      semanticState: lang.t('事件を準備中です', 'Preparing a case'),
      reaction: GameCharacterReaction.invite,
      primaryEpisode: null,
      actionLabel: null,
      actionIcon: null,
    );
  }

  return (
    eyebrow: lang.t('理科事件簿 ・ 未解放', 'SCIENCE CASE FILES · LOCKED'),
    title: lang.t('次の事件は学習パスで解放', 'Unlock the next case on your learning path'),
    body: lang.t(
      '現在の必修ノードを終えると、次の事件ファイルを読めます。',
      'Finish the current required node to read the next case file.',
    ),
    semanticState: lang.t('読める事件はまだありません', 'No cases available yet'),
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
      label: lang.t(
        '事件簿はまだ未解放。学習パスを進めると開きます',
        'Case files are locked. Continue on the learning path to open them.',
      ),
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
                      lang.t('事件簿はまだ未解放', 'Case files are locked'),
                      style: t.textTheme.titleMedium
                          ?.copyWith(color: colors.ink)
                          .jaWeight(FontWeight.w800),
                    ),
                    const SizedBox(height: GameTokens.spaceSm),
                    Text(
                      lang.t(
                        '学習パスを進めると、事件簿が開きます。',
                        'Keep going on the learning path to open case files.',
                      ),
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
      GameContentState.locked => lang.t('未解放', 'Locked'),
      GameContentState.available => lang.t('読めます', 'Available'),
      GameContentState.inProgress => lang.t('続きから', 'Continue'),
      GameContentState.completed => lang.t('完了', 'Completed'),
      GameContentState.dueReview => lang.t('もう一度', 'Review'),
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
      label: lang.t(
        '${episode.chapterLabel}、${episode.title}。${episode.conceptLabel}。$status。約${episode.minutes}分',
        '${episode.chapterLabel}, ${episode.title}. ${episode.conceptLabel}. $status. About ${episode.minutes} min',
      ),
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
                      lang.t(
                        '${episode.conceptLabel} ・ 約${episode.minutes}分',
                        '${episode.conceptLabel} · About ${episode.minutes} min',
                      ),
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
