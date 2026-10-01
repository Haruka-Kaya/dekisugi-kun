import '../config/app_language.dart' as lang;
import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../models/game_path.dart';
import '../ui/_material.dart';

typedef GameQuestCallback = void Function(GameQuest quest);

/// 6タブで固定する、プレイヤー状態とクエストへの入口。
///
/// [PlayerStatusBar]単体は数値表示に責務を絞り、このwidgetが画面幅・余白・
/// Quest sheetをまとめる。Pathを単独表示するときと[GameShell]配下で同じ
/// headerを再利用できるよう、SafeAreaや固定位置は親へ委ねる。
class GamePlayerStatusHeader extends StatelessWidget {
  const GamePlayerStatusHeader({
    super.key,
    required this.status,
    required this.quests,
    this.schoolMode = false,
    this.onQuestSelected,
    this.questUnavailable = false,
    this.onQuestRetry,
    this.onStreakTap,
    this.onGemsTap,
    this.onHeartsTap,
  });

  final GamePlayerStatus status;
  final List<GameQuest> quests;
  final bool schoolMode;
  final GameQuestCallback? onQuestSelected;
  final bool questUnavailable;
  final VoidCallback? onQuestRetry;
  final VoidCallback? onStreakTap;
  final VoidCallback? onGemsTap;
  final VoidCallback? onHeartsTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final pendingQuestCount = quests
        .where((quest) => quest.state == GameQuestState.active)
        .length;
    return ColoredBox(
      key: const ValueKey('game-player-status-header'),
      color: colors.canvas,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          GameTokens.spaceMd,
          GameTokens.spaceSm,
          GameTokens.spaceMd,
          GameTokens.spaceXs,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: GameTokens.readablePathWidth,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: PlayerStatusBar(
                    status: status,
                    schoolMode: schoolMode,
                    onStreakTap: onStreakTap,
                    onGemsTap: onGemsTap,
                    onHeartsTap: onHeartsTap,
                  ),
                ),
                const SizedBox(width: GameTokens.spaceSm),
                _QuestButton(
                  count: pendingQuestCount,
                  schoolMode: schoolMode,
                  onTap: () => showGameQuestSheet(
                    context,
                    quests: quests,
                    schoolMode: schoolMode,
                    onQuestSelected: onQuestSelected,
                    questUnavailable: questUnavailable,
                    onQuestRetry: onQuestRetry,
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

/// Path上部の3つの継続情報。
///
/// 数値を煽る見出しにはせず、学習Pathを開いたまま現在値を確かめる小さな
/// 操作として置く。3セルとも320dpで48dp以上を保ち、200%文字でも横幅を
/// 奪わないよう視覚ラベルは短い数字だけにする。
class PlayerStatusBar extends StatelessWidget {
  const PlayerStatusBar({
    super.key,
    required this.status,
    this.schoolMode = false,
    this.onStreakTap,
    this.onGemsTap,
    this.onHeartsTap,
  });

  final GamePlayerStatus status;
  final bool schoolMode;
  final VoidCallback? onStreakTap;
  final VoidCallback? onGemsTap;
  final VoidCallback? onHeartsTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(GameTokens.radiusMd),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        key: const ValueKey('player-status-bar'),
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!schoolMode) ...[
            Expanded(
              child: _StatusItem(
                key: const ValueKey('player-status-streak'),
                icon: Icons.electric_bolt_rounded,
                iconColor: colors.streak,
                visualValue: _compact(status.streakDays),
                semanticLabel: lang.t(
                  '連続学習、${status.streakDays}日。'
                      '連続記録の保護、${status.streakFreezeRemaining}回分',
                  'Streak, ${status.streakDays} days. '
                      'Streak freezes left: ${status.streakFreezeRemaining}',
                ),
                tooltip: lang.t('連続学習', 'Streak'),
                onTap: onStreakTap,
              ),
            ),
            _Divider(color: colors.border),
            Expanded(
              child: _StatusItem(
                key: const ValueKey('player-status-gems'),
                icon: Icons.diamond_rounded,
                iconColor: colors.gem,
                visualValue: _compact(status.gems),
                semanticLabel: lang.t(
                  'ひらめき結晶、${status.gems}個',
                  'Spark gems, ${status.gems}',
                ),
                tooltip: lang.t('ひらめき結晶', 'Spark gems'),
                onTap: onGemsTap,
              ),
            ),
            _Divider(color: colors.border),
          ],
          Expanded(
            child: _StatusItem(
              key: const ValueKey('player-status-hearts'),
              icon: Icons.favorite_rounded,
              iconColor: colors.heart,
              visualValue: status.unlimitedHearts ? '∞' : '${status.hearts}',
              semanticLabel: status.unlimitedHearts
                  ? schoolMode
                        ? lang.t(
                            '授業モード。ハート、無制限。個人報酬は記録しません',
                            'Class mode. Hearts, unlimited. Personal rewards are not recorded',
                          )
                        : lang.t('ハート、無制限', 'Hearts, unlimited')
                  : lang.t(
                      '学習ハート、${status.maxHearts}個中${status.hearts}個',
                      'Hearts, ${status.hearts} of ${status.maxHearts}',
                    ),
              tooltip: lang.t('学習ハート', 'Hearts'),
              onTap: onHeartsTap,
            ),
          ),
        ],
      ),
    );
  }

  static String _compact(int value) => value > 999 ? '999+' : '$value';
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: color);
}

class _StatusItem extends StatelessWidget {
  const _StatusItem({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.visualValue,
    required this.semanticLabel,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String visualValue;
  final String semanticLabel;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: GameTokens.minTouchTarget,
        minWidth: GameTokens.minTouchTarget,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: GameTokens.spaceSm,
          vertical: GameTokens.spaceSm,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 23, color: iconColor),
            const SizedBox(width: GameTokens.spaceXs),
            Flexible(
              child: Text(
                visualValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(color: colors.ink, height: 1.0)
                    .jaWeight(FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      container: true,
      button: onTap != null,
      enabled: onTap == null ? null : true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: onTap == null
            ? content
            : Tooltip(
                message: tooltip,
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(GameTokens.radiusMd),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(onTap: onTap, child: content),
                ),
              ),
      ),
    );
  }
}

class _QuestButton extends StatelessWidget {
  const _QuestButton({
    required this.count,
    required this.schoolMode,
    required this.onTap,
  });

  final int count;
  final bool schoolMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final noun = schoolMode
        ? lang.t('授業目標', 'Class goals')
        : lang.t('クエスト', 'Quests');
    final label = count == 0
        ? lang.t('$noun。進行中はありません', '$noun. None in progress')
        : lang.t('$noun。進行中$count件', '$noun. $count in progress');
    return Semantics(
      key: const ValueKey('game-quest-button'),
      button: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Tooltip(
          message: noun,
          child: Material(
            color: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(GameTokens.radiusMd),
              side: BorderSide(color: colors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox.square(
                dimension: GameTokens.minTouchTarget,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.emoji_events_rounded, color: colors.pathActive),
                    if (count > 0)
                      Positioned(
                        right: 2,
                        top: 2,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.heart,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.surface, width: 2),
                          ),
                          child: Text(
                            count > 9 ? '9+' : '$count',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: colors.onHeart,
                                  height: 1.0,
                                  fontSize: 10,
                                )
                                .jaWeight(FontWeight.w800),
                          ),
                        ),
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

Future<void> showGameQuestSheet(
  BuildContext context, {
  required List<GameQuest> quests,
  required bool schoolMode,
  required GameQuestCallback? onQuestSelected,
  bool questUnavailable = false,
  VoidCallback? onQuestRetry,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: context.gamePalette.surface,
  constraints: const BoxConstraints(maxWidth: 640),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(GameTokens.radiusSheet),
    ),
  ),
  builder: (sheetContext) {
    final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.88;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: _QuestSheet(
        quests: quests,
        schoolMode: schoolMode,
        questUnavailable: questUnavailable,
        onQuestRetry: onQuestRetry == null
            ? null
            : () {
                Navigator.of(sheetContext).pop();
                onQuestRetry();
              },
        onQuestSelected: onQuestSelected == null
            ? null
            : (quest) {
                Navigator.of(sheetContext).pop();
                onQuestSelected(quest);
              },
      ),
    );
  },
);

class _QuestSheet extends StatelessWidget {
  const _QuestSheet({
    required this.quests,
    required this.schoolMode,
    required this.onQuestSelected,
    required this.questUnavailable,
    required this.onQuestRetry,
  });

  final List<GameQuest> quests;
  final bool schoolMode;
  final GameQuestCallback? onQuestSelected;
  final bool questUnavailable;
  final VoidCallback? onQuestRetry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    final title = schoolMode
        ? lang.t('この端末の授業目標', 'Class goals on this device')
        : lang.t('クエスト', 'Quests');
    return Semantics(
      container: true,
      namesRoute: true,
      label: title,
      child: SingleChildScrollView(
        key: const ValueKey('game-quest-sheet'),
        padding: EdgeInsets.fromLTRB(
          GameTokens.spaceXl,
          0,
          GameTokens.spaceXl,
          GameTokens.spaceXl + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: t.textTheme.headlineSmall
                            ?.copyWith(color: colors.ink)
                            .jaWeight(FontWeight.w800),
                      ),
                      const SizedBox(height: GameTokens.spaceXs),
                      Text(
                        schoolMode
                            ? lang.t(
                                '順位やクラス件数は集計せず、この端末で授業の学習を進めます。',
                                'No rankings or class counts are tallied. Class learning continues on this device.',
                              )
                            : lang.t(
                                '学習の中身につながる目標だけを集めています。',
                                'Only goals tied to what you actually learn are collected here.',
                              ),
                        style: t.textTheme.bodyMedium?.copyWith(
                          color: colors.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: GameTokens.spaceSm),
                IconButton(
                  key: const ValueKey('game-quest-sheet-close'),
                  tooltip: lang.t('閉じる', 'Close'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: GameTokens.spaceXl),
            if (quests.isEmpty)
              Container(
                padding: const EdgeInsets.all(GameTokens.spaceLg),
                decoration: BoxDecoration(
                  color: colors.surfaceRaised,
                  borderRadius: BorderRadius.circular(GameTokens.radiusLg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      questUnavailable
                          ? lang.t(
                              'クエストを読み込めませんでした。学習パスはそのまま使えます。',
                              'Could not load quests. The learning path still works.',
                            )
                          : lang.t(
                              'いま進行中のクエストはありません。',
                              'No quests in progress right now.',
                            ),
                      style: t.textTheme.bodyLarge?.copyWith(color: colors.ink),
                    ),
                    if (questUnavailable && onQuestRetry != null) ...[
                      const SizedBox(height: GameTokens.spaceSm),
                      FilledButton.tonal(
                        key: const ValueKey('game-quest-retry'),
                        onPressed: onQuestRetry,
                        child: Text(lang.t('もう一度読み込む', 'Reload')),
                      ),
                    ],
                  ],
                ),
              )
            else
              for (final quest in quests) ...[
                _QuestCard(
                  quest: quest,
                  schoolMode: schoolMode,
                  onTap: onQuestSelected == null
                      ? null
                      : () => onQuestSelected!(quest),
                ),
                const SizedBox(height: GameTokens.spaceMd),
              ],
          ],
        ),
      ),
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({
    required this.quest,
    required this.schoolMode,
    required this.onTap,
  });

  final GameQuest quest;
  final bool schoolMode;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    final kind = switch (quest.kind) {
      GameQuestKind.daily => lang.t('デイリー', 'Daily'),
      GameQuestKind.monthly => lang.t('マンスリー', 'Monthly'),
      GameQuestKind.friend => lang.t('フレンズ', 'Friends'),
      GameQuestKind.classroom => lang.t('授業', 'Class'),
    };
    final state = switch (quest.state) {
      GameQuestState.active => lang.t('進行中', 'In progress'),
      GameQuestState.completed =>
        schoolMode
            ? lang.t('この端末で達成済み', 'Completed on this device')
            : lang.t('達成。報酬を受け取れます', 'Completed. Reward ready to claim'),
      GameQuestState.claimed =>
        schoolMode
            ? lang.t('この端末で達成済み', 'Completed on this device')
            : lang.t('達成済み', 'Completed'),
    };
    final semantic = lang.t(
      '$kindクエスト、${quest.title}。${quest.description}。'
          '${quest.target}回中${quest.current}回。$state',
      '$kind quest, ${quest.title}. ${quest.description}. '
          '${quest.current} of ${quest.target}. $state',
    );

    return Semantics(
      container: true,
      button: onTap != null,
      label: semantic,
      child: Container(
        padding: const EdgeInsets.all(GameTokens.spaceLg),
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(GameTokens.radiusLg),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: GameTokens.spaceSm,
                runSpacing: GameTokens.spaceXs,
                children: [
                  Text(
                    kind,
                    style: t.textTheme.labelLarge
                        ?.copyWith(color: colors.pathActive)
                        .jaWeight(FontWeight.w800),
                  ),
                  Text(
                    state,
                    style: t.textTheme.labelMedium?.copyWith(
                      color: colors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: GameTokens.spaceSm),
            Text(
              quest.title,
              style: t.textTheme.titleMedium
                  ?.copyWith(color: colors.ink)
                  .jaWeight(FontWeight.w800),
            ),
            const SizedBox(height: GameTokens.spaceXs),
            Text(
              quest.description,
              style: t.textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
            ),
            const SizedBox(height: GameTokens.spaceMd),
            ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(GameTokens.radiusPill),
                child: LinearProgressIndicator(
                  value: quest.progress,
                  minHeight: 9,
                  color: quest.state == GameQuestState.active
                      ? colors.pathActive
                      : colors.pathComplete,
                  backgroundColor: colors.border,
                ),
              ),
            ),
            const SizedBox(height: GameTokens.spaceSm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${quest.current}/${quest.target}',
                    style: t.textTheme.labelLarge
                        ?.copyWith(color: colors.ink)
                        .jaWeight(FontWeight.w800),
                  ),
                ),
                if (!schoolMode && quest.rewardLabel != null)
                  Text(
                    quest.rewardLabel!,
                    style: t.textTheme.labelLarge
                        ?.copyWith(color: colors.gem)
                        .jaWeight(FontWeight.w800),
                  ),
              ],
            ),
            if (onTap != null) ...[
              const SizedBox(height: GameTokens.spaceSm),
              TextButton(
                onPressed: onTap,
                child: Text(
                  quest.actionLabel ?? lang.t('このクエストを見る', 'View this quest'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
