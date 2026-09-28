import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../learning/domain/learning_economy.dart';
import '../learning/domain/learning_progress.dart';
import '../learning/domain/learning_monthly_badge.dart';
import '../models/game_hub.dart';
import '../models/game_path.dart';
import '../ui/_material.dart';
import '../widgets/game_page.dart';
import '../widgets/learning_path.dart';
import '../widgets/local_coop_quest_panel.dart';

class GameProfileScreen extends StatelessWidget {
  const GameProfileScreen({
    super.key,
    required this.player,
    required this.quests,
    required this.schoolMode,
    required this.onOpenSettings,
    this.explanationCount = 0,
    this.onOpenEconomy,
    this.onOpenKarte,
    this.onOpenLanSocial,
    this.localCoopRun,
    this.selectedCoopParticipantId,
    this.onStartLocalCoop,
    this.onSelectCoopParticipant,
    this.localCoopUnavailableReason,
    this.onOpenClassroom,
    this.onExitLocalMode,
    this.monthlyBadges = const [],
    this.mascotStyle = LearningPathMascotStyle.standard,
    this.plusSupporter = false,
  });

  final PlayerSummaryView player;
  final List<QuestView> quests;
  final bool schoolMode;
  final int explanationCount;
  final VoidCallback? onOpenEconomy;
  final VoidCallback? onOpenKarte;
  final VoidCallback? onOpenLanSocial;
  final LearningLocalCoopRun? localCoopRun;
  final String? selectedCoopParticipantId;
  final VoidCallback? onStartLocalCoop;
  final ValueChanged<String>? onSelectCoopParticipant;
  final String? localCoopUnavailableReason;
  final VoidCallback onOpenSettings;
  final VoidCallback? onOpenClassroom;
  final VoidCallback? onExitLocalMode;
  final List<LearningMonthlyBadgeAward> monthlyBadges;
  final LearningPathMascotStyle mascotStyle;

  /// Plus特典を所有している。学習報酬ではなく応援の印として表示する。
  final bool plusSupporter;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final progress = player.totalNodes <= 0
        ? 0.0
        : (player.completedNodes / player.totalNodes).clamp(0.0, 1.0);
    final action = schoolMode
        ? onOpenClassroom == null
              ? null
              : FilledButton.icon(
                  key: const ValueKey('game-profile-open-classroom'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.surface,
                    foregroundColor: colors.pathActive,
                    minimumSize: const Size.fromHeight(
                      GameTokens.minTouchTarget,
                    ),
                  ),
                  onPressed: onOpenClassroom,
                  icon: const Icon(Icons.school_outlined),
                  label: const Text('授業コードから始める'),
                )
        : onOpenEconomy == null
        ? null
        : FilledButton.icon(
            key: const ValueKey('game-profile-open-economy'),
            style: FilledButton.styleFrom(
              backgroundColor: colors.surface,
              foregroundColor: colors.pathActive,
              minimumSize: const Size.fromHeight(GameTokens.minTouchTarget),
            ),
            onPressed: onOpenEconomy,
            icon: const Icon(Icons.diamond_outlined),
            label: const Text('装備と結晶を確認'),
          );
    return GamePageScaffold(
      scrollKey: const ValueKey('game-profile-screen'),
      children: [
        GameHeroSurface(
          surfaceKey: const ValueKey('game-profile-progress'),
          color: colors.pathActive,
          foregroundColor: colors.onPathActive,
          eyebrow: schoolMode ? 'この端末の研究室' : '自分の研究室',
          title: '${player.completedNodes} / ${player.totalNodes} ノード',
          body: schoolMode
              ? 'この端末の到達だけを確認します。'
              : 'デキすぎ君の装備と、説明・復習・挑戦の記録を同じ部屋で振り返ります。',
          semanticSummary:
              '${schoolMode ? 'この端末の' : '自分の'}研究室。'
              '${player.completedNodes}/${player.totalNodes}ノード',
          leading: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: PathMascotPreview(
                reaction: GameCharacterReaction.invite,
                size: GameTokens.heroMascotSize,
                style: mascotStyle,
              ),
            ),
          ),
          trailing: IconButton.filled(
            key: const ValueKey('game-profile-settings'),
            style: IconButton.styleFrom(
              backgroundColor: colors.surface,
              foregroundColor: colors.pathActive,
              minimumSize: const Size.square(GameTokens.minTouchTarget),
            ),
            onPressed: onOpenSettings,
            tooltip: '設定を開く',
            icon: const Icon(Icons.settings_outlined),
          ),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GameSolidSurface(
                padding: const EdgeInsets.all(GameTokens.spaceMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '学習パスの到達',
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: colors.ink)
                          .jaWeight(FontWeight.w800),
                    ),
                    const SizedBox(height: GameTokens.spaceSm),
                    LinearProgressIndicator(
                      key: const ValueKey('game-profile-progress-indicator'),
                      value: progress,
                      minHeight: GameTokens.progressTrackHeight,
                      borderRadius: BorderRadius.circular(
                        GameTokens.radiusPill,
                      ),
                      backgroundColor: colors.pathLocked,
                      color: colors.pathActive,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: GameTokens.spaceMd),
              Wrap(
                spacing: GameTokens.spaceLg,
                runSpacing: GameTokens.spaceSm,
                children: [
                  if (!schoolMode) ...[
                    _Metric(
                      icon: Icons.electric_bolt_rounded,
                      label: '連続学習',
                      value: '${player.streakDays}日',
                      foregroundColor: colors.onPathActive,
                    ),
                    _Metric(
                      icon: Icons.ac_unit_rounded,
                      label: '保護',
                      value: '${player.freezeCount}個',
                      foregroundColor: colors.onPathActive,
                    ),
                    _Metric(
                      icon: Icons.diamond_rounded,
                      label: 'ひらめき結晶',
                      value: '${player.gems}個',
                      foregroundColor: colors.onPathActive,
                    ),
                  ],
                  _Metric(
                    icon: Icons.notes_rounded,
                    label: '説明の見直し',
                    value: '$explanationCount回',
                    foregroundColor: colors.onPathActive,
                  ),
                  if (plusSupporter && !schoolMode)
                    _Metric(
                      icon: Icons.workspace_premium_outlined,
                      label: 'Plus サポーター',
                      value: '応援中',
                      foregroundColor: colors.onPathActive,
                    ),
                ],
              ),
            ],
          ),
          primaryAction: action,
        ),
        if (!schoolMode) ...[
          const SizedBox(height: GameTokens.spaceXl),
          _MonthlyBadgeCollection(badges: monthlyBadges),
        ],
        if (onOpenKarte != null) ...[
          const SizedBox(height: GameTokens.spaceXl),
          GameSolidSurface(
            surfaceKey: const ValueKey('game-profile-karte'),
            raised: true,
            accent: colors.story,
            padding: const EdgeInsets.all(GameTokens.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const GameSectionHeader(
                  title: 'デキすぎ君のカルテ',
                  description:
                      'デキすぎ君が持っている思い込みと、あなたの説明で訂正できたところの記録。',
                ),
                const SizedBox(height: GameTokens.spaceMd),
                FilledButton.icon(
                  key: const ValueKey('game-profile-open-karte'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.story,
                    foregroundColor: colors.onStory,
                    minimumSize: const Size.fromHeight(
                      GameTokens.minTouchTarget,
                    ),
                  ),
                  onPressed: onOpenKarte,
                  icon: const Icon(Icons.psychology_alt_outlined),
                  label: const Text('思い込みの記録を見る'),
                ),
              ],
            ),
          ),
        ],
        if (!schoolMode &&
            onStartLocalCoop != null &&
            onSelectCoopParticipant != null) ...[
          const SizedBox(height: GameTokens.spaceXl),
          const GameSectionHeader(
            title: '同じ端末で協力',
            description: '実在する二人が端末を手渡しして進めます。',
          ),
          const SizedBox(height: GameTokens.spaceMd),
          LocalCoopQuestPanel(
            run: localCoopRun,
            selectedParticipantId: selectedCoopParticipantId,
            onStart: onStartLocalCoop!,
            onSelectParticipant: onSelectCoopParticipant!,
            unavailableReason: localCoopUnavailableReason,
          ),
        ],
        const SizedBox(height: GameTokens.spaceXl),
        _QuestBoard(quests: quests, schoolMode: schoolMode),
        const SizedBox(height: GameTokens.spaceLg),
        GameSolidSurface(
          surfaceKey: const ValueKey('game-profile-policy'),
          raised: true,
          child: Text(
            schoolMode
                ? '学校課題は個人XP・結晶・連続学習へ加算しません。回答本文と音声も保存しません。'
                : '学習ハートは固定課題の誤答で1個減り、0では新しい通常学習を始めません。30分ごと、または専用の回復練習1件で1個回復し、結晶2個で全回復できます。到達済みの学習パスは失いません。',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
          ),
        ),
        if (onOpenLanSocial != null || onExitLocalMode != null) ...[
          const SizedBox(height: GameTokens.spaceXl),
          _ConnectionSettings(
            onOpenLanSocial: onOpenLanSocial,
            onExitLocalMode: onExitLocalMode,
          ),
        ],
      ],
    );
  }
}

class _MonthlyBadgeCollection extends StatelessWidget {
  const _MonthlyBadgeCollection({required this.badges});

  final List<LearningMonthlyBadgeAward> badges;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    return Semantics(
      key: const ValueKey('game-profile-monthly-badges'),
      container: true,
      label: badges.isEmpty ? '月間バッジ。まだありません' : '月間バッジ、${badges.length}個',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GameSectionHeader(
            title: '月間バッジ',
            description: '月の学習目標を達成した記録です。結晶では購入できません。',
          ),
          const SizedBox(height: GameTokens.spaceMd),
          if (badges.isEmpty)
            GameSolidSurface(
              surfaceKey: const ValueKey('game-profile-monthly-badges-empty'),
              raised: true,
              child: Text(
                '今月のクエストを達成すると、ここに最初の観測バッジが加わります。',
                style: t.textTheme.bodyMedium?.copyWith(color: colors.ink),
              ),
            )
          else
            GameResponsiveGrid(
              children: [
                for (final badge in badges) _MonthlyBadgeTile(badge: badge),
              ],
            ),
        ],
      ),
    );
  }
}

class _MonthlyBadgeTile extends StatelessWidget {
  const _MonthlyBadgeTile({required this.badge});

  final LearningMonthlyBadgeAward badge;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    final (icon, fill, foreground) = switch (badge.style) {
      LearningMonthlyBadgeStyle.orbit => (
        Icons.public_rounded,
        colors.pathReview,
        colors.onPathReview,
      ),
      LearningMonthlyBadgeStyle.telescope => (
        Icons.travel_explore_rounded,
        colors.pathActive,
        colors.onPathActive,
      ),
      LearningMonthlyBadgeStyle.prism => (
        Icons.change_history_rounded,
        colors.story,
        colors.onStory,
      ),
      LearningMonthlyBadgeStyle.constellation => (
        Icons.auto_awesome_rounded,
        colors.legendary,
        colors.onLegendary,
      ),
    };
    return Semantics(
      label: '${badge.title}。獲得済み。${badge.description}',
      child: ExcludeSemantics(
        child: Container(
          key: ValueKey<String>('monthly-badge-${badge.badgeId}'),
          padding: const EdgeInsets.all(GameTokens.spaceMd),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(GameTokens.radiusMd),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: GameTokens.minTouchTarget,
                height: GameTokens.minTouchTarget,
                decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
                child: Icon(icon, color: foreground),
              ),
              const SizedBox(width: GameTokens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badge.title,
                      style: t.textTheme.titleMedium
                          ?.copyWith(color: colors.ink)
                          .jaWeight(FontWeight.w800),
                    ),
                    const SizedBox(height: GameTokens.spaceXs),
                    Text(
                      badge.description,
                      style: t.textTheme.bodySmall?.copyWith(
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

class _Metric extends StatelessWidget {
  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    required this.foregroundColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Semantics(
      key: ValueKey('game-profile-metric-$label'),
      container: true,
      label: '$label、$value',
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: GameTokens.metricMinWidth,
            minHeight: GameTokens.minTouchTarget,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foregroundColor),
              const SizedBox(width: GameTokens.spaceSm),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: t.textTheme.labelSmall?.copyWith(
                      color: foregroundColor,
                    ),
                  ),
                  Text(
                    value,
                    style: t.textTheme.titleMedium
                        ?.copyWith(color: foregroundColor)
                        .jaWeight(FontWeight.w900),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestRow extends StatelessWidget {
  const _QuestRow({required this.quest, required this.showReward});

  final QuestView quest;
  final bool showReward;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    final progress = quest.target <= 0
        ? 0.0
        : (quest.progress / quest.target).clamp(0.0, 1.0);
    return Semantics(
      key: ValueKey('game-profile-quest-${quest.id}'),
      container: true,
      label:
          '${quest.title}、${quest.progress}/${quest.target}'
          '${quest.isComplete ? '、完了' : ''}'
          '${showReward ? '、結晶${quest.gemReward}個' : ''}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: GameTokens.spaceSm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    quest.isComplete ? Icons.check_circle : Icons.flag_outlined,
                    color: quest.isComplete
                        ? colors.pathComplete
                        : colors.pathActive,
                  ),
                  const SizedBox(width: GameTokens.spaceSm),
                  Expanded(
                    child: Text(
                      quest.title,
                      style: t.textTheme.titleSmall?.jaWeight(FontWeight.w800),
                    ),
                  ),
                  if (showReward)
                    Text(
                      '◆ ${quest.gemReward}',
                      style: t.textTheme.labelLarge
                          ?.copyWith(color: colors.gem)
                          .jaWeight(FontWeight.w900),
                    ),
                ],
              ),
              const SizedBox(height: GameTokens.spaceSm),
              LinearProgressIndicator(
                value: progress,
                minHeight: GameTokens.compactProgressTrackHeight,
                borderRadius: BorderRadius.circular(GameTokens.radiusPill),
                color: quest.isComplete
                    ? colors.pathComplete
                    : colors.pathActive,
                backgroundColor: colors.border,
              ),
              const SizedBox(height: GameTokens.spaceXs),
              Text(
                '${quest.progress} / ${quest.target}',
                textAlign: TextAlign.end,
                style: t.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestBoard extends StatelessWidget {
  const _QuestBoard({required this.quests, required this.schoolMode});

  final List<QuestView> quests;
  final bool schoolMode;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return GameSolidSurface(
      surfaceKey: const ValueKey('game-profile-quest-board'),
      accent: colors.pathActive,
      padding: const EdgeInsets.all(GameTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GameSectionHeader(
            title: schoolMode ? '今日の授業目標（この端末）' : '今日のクエスト',
            description: 'アプリ滞在時間ではなく、学習パスを前へ進める行為だけを数えます。',
          ),
          const SizedBox(height: GameTokens.spaceMd),
          if (quests.isEmpty)
            Text(
              '今日は新しいクエストがありません。',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
            )
          else
            for (var index = 0; index < quests.length; index++) ...[
              if (index > 0) Divider(color: colors.border),
              _QuestRow(quest: quests[index], showReward: !schoolMode),
            ],
        ],
      ),
    );
  }
}

class _ConnectionSettings extends StatelessWidget {
  const _ConnectionSettings({
    required this.onOpenLanSocial,
    required this.onExitLocalMode,
  });

  final VoidCallback? onOpenLanSocial;
  final VoidCallback? onExitLocalMode;

  @override
  Widget build(BuildContext context) => GameSolidSurface(
    raised: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GameSectionHeader(
          title: 'つながりと設定',
          description: '通信モードは、学習記録と分けてここから確認します。',
        ),
        if (onOpenLanSocial != null) ...[
          const SizedBox(height: GameTokens.spaceMd),
          OutlinedButton.icon(
            key: const ValueKey('game-profile-open-lan-social'),
            onPressed: onOpenLanSocial,
            icon: const Icon(Icons.groups_2_outlined),
            label: const Text('実参加者といっしょに学ぶ'),
          ),
        ],
        if (onExitLocalMode != null) ...[
          const SizedBox(height: GameTokens.spaceSm),
          TextButton.icon(
            key: const ValueKey('game-profile-exit-local-mode'),
            onPressed: onExitLocalMode,
            icon: const Icon(Icons.sync_alt_outlined),
            label: const Text('通信モード確認へ戻る'),
          ),
        ],
      ],
    ),
  );
}
