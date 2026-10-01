import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../models/game_path.dart';
import '../ui/_material.dart';

typedef GameQuestCallback = void Function(GameQuest quest);

/// 全研究領域で固定する、研究計器と観察予定への入口。
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

/// 探究ノート上部の研究計器。
///
/// ゲーム資源のアイコン列ではなく、観測日・結晶・残り試行を短いラベル付きで
/// 返す。3セルとも320dpで48dp以上を保ち、色だけに意味を持たせない。
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
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(GameTokens.radiusSm),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Row(
            key: const ValueKey('player-status-bar'),
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!schoolMode) ...[
                Expanded(
                  child: _StatusItem(
                    key: const ValueKey('player-status-streak'),
                    icon: Icons.calendar_view_week_outlined,
                    iconColor: colors.streak,
                    visualValue: _compact(status.streakDays),
                    visualLabel: '観測日',
                    semanticLabel:
                        '連続観測、${status.streakDays}日。'
                        'お休みの日の保護、${status.streakFreezeRemaining}回分',
                    tooltip:
                        '連続観測。忙しい日に1日空いても連続記録を守る保護を${status.streakFreezeRemaining}回分残しています',
                    onTap: onStreakTap,
                  ),
                ),
                _Divider(color: colors.border),
                Expanded(
                  child: _StatusItem(
                    key: const ValueKey('player-status-gems'),
                    icon: Icons.hexagon_outlined,
                    iconColor: colors.gem,
                    visualValue: _compact(status.gems),
                    visualLabel: '結晶',
                    semanticLabel: 'ひらめき結晶、${status.gems}個',
                    tooltip: 'ひらめき結晶。学習を速くしたり正答を買ったりせず、記録の補助だけに使えます',
                    onTap: onGemsTap,
                  ),
                ),
                _Divider(color: colors.border),
              ],
              Expanded(
                child: _StatusItem(
                  key: const ValueKey('player-status-hearts'),
                  icon: Icons.science_outlined,
                  iconColor: colors.heart,
                  visualValue: status.unlimitedHearts
                      ? '∞'
                      : '${status.hearts}',
                  visualLabel: '試行',
                  semanticLabel: status.unlimitedHearts
                      ? schoolMode
                            ? '授業モード。試行、無制限。個人報酬は記録しません'
                            : '試行、無制限'
                      : '試行余力、${status.maxHearts}枠中${status.hearts}枠',
                  tooltip: '試行余力',
                  onTap: onHeartsTap,
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: ColoredBox(color: colors.pathActive),
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
    required this.visualLabel,
    required this.semanticLabel,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String visualValue;
  final String visualLabel;
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
          horizontal: GameTokens.spaceXs,
          vertical: 6,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 19, color: iconColor),
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
            const SizedBox(height: 2),
            Text(
              visualLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: colors.inkMuted, height: 1.0)
                  .jaWeight(FontWeight.w600),
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
      onTap: onTap,
      child: ExcludeSemantics(
        child: onTap == null
            ? content
            : Tooltip(
                message: tooltip,
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(GameTokens.radiusSm),
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
    final noun = schoolMode ? '授業の観察予定' : '今日の観察予定';
    final label = count == 0 ? '$noun。進行中はありません' : '$noun。進行中$count件';
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
              borderRadius: BorderRadius.circular(GameTokens.radiusSm),
              side: BorderSide(color: colors.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                width: 58,
                height: 58,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_note_outlined,
                          size: 21,
                          color: colors.pathActive,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '予定',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.inkMuted, height: 1)
                              .jaWeight(FontWeight.w600),
                        ),
                      ],
                    ),
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
                            borderRadius: BorderRadius.circular(4),
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
    final title = schoolMode ? 'この端末の授業予定' : '観察予定';
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
                            ? '順位やクラス件数は集計せず、この端末で授業の学習を進めます。'
                            : '今日の探究に直接つながる予定だけを集めています。',
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
                  tooltip: '閉じる',
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
                          ? '観察予定を読み込めませんでした。探究ノートはそのまま使えます。'
                          : 'いま取り組み中の観察予定はありません。',
                      style: t.textTheme.bodyLarge?.copyWith(color: colors.ink),
                    ),
                    if (questUnavailable && onQuestRetry != null) ...[
                      const SizedBox(height: GameTokens.spaceSm),
                      FilledButton.tonal(
                        key: const ValueKey('game-quest-retry'),
                        onPressed: onQuestRetry,
                        child: const Text('もう一度読み込む'),
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
      GameQuestKind.daily => '今日',
      GameQuestKind.monthly => '今月',
      GameQuestKind.friend => '共同',
      GameQuestKind.classroom => '授業',
    };
    final state = switch (quest.state) {
      GameQuestState.active => '取り組み中',
      GameQuestState.completed => schoolMode ? 'この端末に記録済み' : '記録済み。結晶を受け取れます',
      GameQuestState.claimed => schoolMode ? 'この端末に記録済み' : '記録済み',
    };
    final semantic =
        '$kindの観察予定、${quest.title}。${quest.description}。'
        '${quest.target}回中${quest.current}回。$state';

    return Semantics(
      container: true,
      button: onTap != null,
      label: semantic,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(GameTokens.radiusMd),
          border: Border.all(color: colors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(GameTokens.spaceLg),
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
                    style: t.textTheme.bodyMedium?.copyWith(
                      color: colors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: GameTokens.spaceMd),
                  ExcludeSemantics(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(GameTokens.radiusSm),
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
                      child: Text(quest.actionLabel ?? 'この予定を開く'),
                    ),
                  ],
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: ColoredBox(color: colors.pathActive),
            ),
          ],
        ),
      ),
    );
  }
}
