import '../config/app_language.dart' as localize;
import '../config/app_language.dart' as lang;
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
                  label: Text(lang.t('授業コードから始める', 'Start with a class code')),
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
            icon: Icon(Icons.hexagon_outlined),
            label: Text(lang.t('装備と結晶を確認', 'View gear and gems')),
          );
    return GamePageScaffold(
      scrollKey: const ValueKey('game-profile-screen'),
      children: [
        GameHeroSurface(
          surfaceKey: const ValueKey('game-profile-progress'),
          color: colors.pathActive,
          foregroundColor: colors.onPathActive,
          eyebrow: schoolMode
              ? lang.t('この端末の研究室', 'This device\'s lab')
              : lang.t('自分の研究室', 'My lab'),
          title: lang.t(
            '${player.completedNodes} / ${player.totalNodes} 観察項目',
            '${player.completedNodes} / ${player.totalNodes} nodes',
          ),
          body: schoolMode
              ? lang.t('この端末の到達だけを確認します。', 'See progress on this device.')
              : lang.t(
                  'デキすぎ君の装備と、説明・復習・挑戦の記録を同じ部屋で振り返ります。',
                  'Review Dekisugi-kun\'s gear and your teaching, reviews, and challenges here.',
                ),
          semanticSummary:
              localize.t(
                '${schoolMode ? localize.t('この端末の', "On this device: ") : localize.t('自分の', "Your ")}研究室。',
                '${schoolMode ? localize.t('この端末の', "On this device: ") : localize.t('自分の', "Your ")}lab.',
              ) +
              localize.t(
                '${player.completedNodes}/${player.totalNodes}観察項目',
                '${player.completedNodes}/${player.totalNodes} observation items',
              ),
          leading: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(GameTokens.radiusSm),
              border: Border.all(color: colors.border),
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
            tooltip: lang.t('設定を開く', 'Open settings'),
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
                      lang.t('探究ノートの到達', 'Learning path progress'),
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
                      icon: Icons.calendar_view_week_outlined,
                      label: lang.t('連続観測', 'Learning streak'),
                      value: lang.t(
                        '${player.streakDays}日',
                        '${player.streakDays} days',
                      ),
                      iconColor: colors.continuity,
                    ),
                    _Metric(
                      icon: Icons.shield_outlined,
                      label: lang.t('記録保護', 'Streak shields'),
                      value: lang.t(
                        '${player.freezeCount}個',
                        '${player.freezeCount}',
                      ),
                      iconColor: colors.pathActive,
                    ),
                    _Metric(
                      icon: Icons.hexagon_outlined,
                      label: lang.t('ひらめき結晶', 'Insight gems'),
                      value: lang.t('${player.gems}個', '${player.gems}'),
                      iconColor: colors.crystal,
                    ),
                  ],
                  _Metric(
                    icon: Icons.notes_rounded,
                    label: lang.t('説明の見直し', 'Explanation reviews'),
                    value: lang.t(
                      '$explanationCount回',
                      '$explanationCount times',
                    ),
                    iconColor: colors.ink,
                  ),
                  if (plusSupporter && !schoolMode)
                    _Metric(
                      icon: Icons.workspace_premium_outlined,
                      label: lang.t('Plus サポーター', 'Plus supporter'),
                      value: lang.t('応援中', 'Supporting'),
                      iconColor: colors.pathActive,
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
                GameSectionHeader(
                  title: lang.t('デキすぎ君のカルテ', 'Dekisugi-kun\'s record'),
                  description: lang.t(
                    'デキすぎ君が持っている思い込みと、あなたの説明で訂正できたところの記録。',
                    'A record of Dekisugi-kun\'s misconceptions and what your teaching helped correct.',
                  ),
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
                  label: Text(
                    lang.t('思い込みの記録を見る', 'View misconception record'),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (!schoolMode &&
            onStartLocalCoop != null &&
            onSelectCoopParticipant != null) ...[
          const SizedBox(height: GameTokens.spaceXl),
          GameSectionHeader(
            title: lang.t('同じ端末で共同観測', 'Team up on one device'),
            description: lang.t(
              '実在する二人が端末を手渡しして進めます。',
              'Two real players take turns on one device.',
            ),
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
                ? lang.t(
                    '学校課題は個人の探究記録・結晶・連続観測へ加算しません。回答本文と音声も保存しません。',
                    'Class work does not add personal XP, gems, or streak days. Answers and audio are not saved.',
                  )
                : lang.t(
                    '試行余力は固定課題の誤答で1枠減り、0では新しい通常観察を始めません。30分ごと、または専用の回復練習1件で1枠回復し、結晶2個で全回復できます。到達済みの探究ノートは失いません。',
                    'A wrong answer on a set task costs one heart. At zero hearts, you cannot start a new lesson. Restore one every 30 minutes or with a recovery exercise, or refill them all for two gems. Your path progress stays.',
                  ),
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
      label: badges.isEmpty
          ? lang.t('月間観測印。まだありません', 'Monthly badges. None yet')
          : lang.t(
              '月間観測印、${badges.length}個',
              'Monthly badges: ${badges.length}',
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GameSectionHeader(
            title: lang.t('月間観測印', 'Monthly badges'),
            description: lang.t(
              '月の観察目標を達成した記録です。結晶では購入できません。',
              'Earn these by meeting monthly learning goals. Gems cannot buy them.',
            ),
          ),
          const SizedBox(height: GameTokens.spaceMd),
          if (badges.isEmpty)
            GameSolidSurface(
              surfaceKey: const ValueKey('game-profile-monthly-badges-empty'),
              raised: true,
              child: Text(
                lang.t(
                  '今月の観察予定を達成すると、ここに最初の観測印が加わります。',
                  'Complete this month\'s quest to earn your first observation badge.',
                ),
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
    final displayTitle = badge.title.replaceAll(
      localize.t('観測バッジ', "Observation badges"),
      localize.t('観測印', "Observation stamps"),
    );
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
      label: lang.t(
        '$displayTitle。記録済み。${badge.description}',
        '${badge.title}. Earned. ${badge.description}',
      ),
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
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(GameTokens.radiusSm),
                  border: Border.all(color: colors.border),
                ),
                child: Icon(icon, color: foreground),
              ),
              const SizedBox(width: GameTokens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
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
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
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
              Icon(icon, color: iconColor),
              const SizedBox(width: GameTokens.spaceSm),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: t.textTheme.labelSmall?.copyWith(
                      color: colors.inkMuted,
                    ),
                  ),
                  Text(
                    value,
                    style: t.textTheme.titleMedium
                        ?.copyWith(color: colors.ink)
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
    final displayTitle = _questDisplayTitle(quest.title);
    return Semantics(
      key: ValueKey('game-profile-quest-${quest.id}'),
      container: true,
      label: localize.t(
        '$displayTitle、${quest.progress}/${quest.target}${quest.isComplete ? '、完了' : ''}${showReward ? '、結晶${quest.gemReward}個' : ''}',
        '$displayTitle, ${quest.progress}/${quest.target}${quest.isComplete ? ', complete' : ''}${showReward ? ', ${quest.gemReward} gems' : ''}',
      ),
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
                      displayTitle,
                      style: t.textTheme.titleSmall?.jaWeight(FontWeight.w800),
                    ),
                  ),
                  if (showReward)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.hexagon_outlined,
                          size: 18,
                          color: colors.gem,
                        ),
                        const SizedBox(width: GameTokens.spaceXs),
                        Text(
                          '${quest.gemReward}',
                          style: t.textTheme.labelLarge
                              ?.copyWith(color: colors.gem)
                              .jaWeight(FontWeight.w900),
                        ),
                      ],
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

String _questDisplayTitle(String title) => title
    .replaceAll('学習パス', '探究ノート')
    .replaceAll('Path', '探究ノート')
    .replaceAll('クエスト', '観察予定');

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
            title: schoolMode
                ? lang.t('今日の授業目標（この端末）', 'Today\'s class goal (this device)')
                : lang.t('今日の観察予定', 'Today\'s quests'),
            description: lang.t(
              'アプリ滞在時間ではなく、探究ノートを前へ進める行為だけを数えます。',
              'Only actions that move your learning path forward count, not time in the app.',
            ),
          ),
          const SizedBox(height: GameTokens.spaceMd),
          if (quests.isEmpty)
            Text(
              lang.t('今日は新しい観察予定がありません。', 'No new quests today.'),
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
        GameSectionHeader(
          title: lang.t('つながりと設定', 'Connections and settings'),
          description: lang.t(
            '通信モードは、学習記録と分けてここから確認します。',
            'Check connection mode here, separate from your learning record.',
          ),
        ),
        if (onOpenLanSocial != null) ...[
          const SizedBox(height: GameTokens.spaceMd),
          OutlinedButton.icon(
            key: const ValueKey('game-profile-open-lan-social'),
            onPressed: onOpenLanSocial,
            icon: const Icon(Icons.groups_2_outlined),
            label: Text(lang.t('実参加者といっしょに学ぶ', 'Learn with real players')),
          ),
        ],
        if (onExitLocalMode != null) ...[
          const SizedBox(height: GameTokens.spaceSm),
          TextButton.icon(
            key: const ValueKey('game-profile-exit-local-mode'),
            onPressed: onExitLocalMode,
            icon: const Icon(Icons.sync_alt_outlined),
            label: Text(lang.t('通信モード確認へ戻る', 'Back to connection mode')),
          ),
        ],
      ],
    ),
  );
}
