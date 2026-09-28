import '../config/app_language.dart' as lang;
import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../learning/services/learning_game_projection.dart';
import '../models/game_hub.dart';
import '../ui/_material.dart';
import '../widgets/game_cosmetic_item.dart';

typedef GameEconomyAction = Future<void> Function();
typedef GameEconomyProductAction = Future<void> Function(String productId);

Future<void> showGameEconomySheet(
  BuildContext context, {
  required LearningEconomyView economy,
  required PlayerSummaryView player,
  required GameEconomyAction onRefillStreakFreeze,
  required GameEconomyAction onRecoverChallengeHearts,
  required GameEconomyProductAction onPurchaseCosmetic,
  required GameEconomyProductAction onEquipCosmetic,
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
  builder: (sheetContext) => GameEconomySheet(
    economy: economy,
    player: player,
    onRefillStreakFreeze: onRefillStreakFreeze,
    onRecoverChallengeHearts: onRecoverChallengeHearts,
    onPurchaseCosmetic: onPurchaseCosmetic,
    onEquipCosmetic: onEquipCosmetic,
    onClose: () => Navigator.of(sheetContext).pop(),
  ),
);

/// 端末内で獲得した結晶だけを使う、用途限定の交換面。
///
/// 実課金、汎用アイテムID、回答・正誤は扱わない。通常Pathと通常Practiceの
/// 利用資格にも影響させず、保護・ハートとPathの見た目だけを補助する。
class GameEconomySheet extends StatefulWidget {
  const GameEconomySheet({
    super.key,
    required this.economy,
    required this.player,
    required this.onRefillStreakFreeze,
    required this.onRecoverChallengeHearts,
    required this.onPurchaseCosmetic,
    required this.onEquipCosmetic,
    required this.onClose,
  });

  final LearningEconomyView economy;
  final PlayerSummaryView player;
  final GameEconomyAction onRefillStreakFreeze;
  final GameEconomyAction onRecoverChallengeHearts;
  final GameEconomyProductAction onPurchaseCosmetic;
  final GameEconomyProductAction onEquipCosmetic;
  final VoidCallback onClose;

  @override
  State<GameEconomySheet> createState() => _GameEconomySheetState();
}

class _GameEconomySheetState extends State<GameEconomySheet> {
  String? _busyAction;
  String? _status;

  Future<void> _confirmAndRun({
    required String actionId,
    required String title,
    required String body,
    required GameEconomyAction action,
  }) async {
    if (_busyAction != null) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            key: ValueKey('economy-$actionId-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(lang.t('やめる', 'Cancel')),
          ),
          FilledButton(
            key: ValueKey('economy-$actionId-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(lang.t('結晶を使う', 'Spend gems')),
          ),
        ],
      ),
    );
    if (approved != true || !mounted || _busyAction != null) return;
    await _runAction(actionId: actionId, action: action);
  }

  Future<void> _runAction({
    required String actionId,
    required GameEconomyAction action,
  }) async {
    if (_busyAction != null) return;
    setState(() {
      _busyAction = actionId;
      _status = null;
    });
    try {
      await action();
      if (!mounted) return;
      setState(
        () =>
            _status = lang.t('交換を端末へ記録しました。', 'Exchange saved on this device.'),
      );
      widget.onClose();
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _status = lang.t(
          '交換できませんでした。残高と現在の状態を確認してください。',
          'Could not exchange. Check your gem balance and current status.',
        ),
      );
    } finally {
      if (mounted) setState(() => _busyAction = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    final economy = widget.economy;
    final freezeCost = economy.streakFreezeRefillGemCost;
    final heartCost = economy.challengeHeartRecoveryGemCost;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: SingleChildScrollView(
        key: const ValueKey('game-economy-sheet'),
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
                        lang.t('ひらめき結晶', 'Insight gems'),
                        style: t.textTheme.headlineSmall
                            ?.copyWith(color: colors.ink)
                            .jaWeight(FontWeight.w900),
                      ),
                      const SizedBox(height: GameTokens.spaceXs),
                      Semantics(
                        label: lang.t(
                          '現在、結晶${economy.gems}個',
                          'Current balance: ${economy.gems} gems',
                        ),
                        child: ExcludeSemantics(
                          child: Text(
                            '◆ ${economy.gems}',
                            style: t.textTheme.titleLarge
                                ?.copyWith(color: colors.gem)
                                .jaWeight(FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('game-economy-close'),
                  tooltip: lang.t('閉じる', 'Close'),
                  onPressed: _busyAction == null ? widget.onClose : null,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: GameTokens.spaceMd),
            Text(
              lang.t(
                '学習で得た結晶を、保護・ハート・Pathの見た目に使えます。実課金では増やせません。',
                'Use gems earned from learning for streak shields, hearts, or your Path mascot. Gems cannot be bought with money.',
              ),
              style: t.textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
            ),
            const SizedBox(height: GameTokens.spaceXl),
            _EconomyItem(
              key: const ValueKey('economy-freeze-item'),
              actionId: 'freeze',
              icon: Icons.ac_unit_rounded,
              title: lang.t('連続記録の保護を補充', 'Refill a streak shield'),
              description: lang.t(
                '今週使える保護を1回分補充します。週の補充上限に達した場合は使えません。',
                'Add one shield for this week. Unavailable when the weekly refill limit is reached.',
              ),
              currentLabel: lang.t(
                '現在 ${widget.player.freezeCount}回分',
                'Currently ${widget.player.freezeCount} shields',
              ),
              cost: freezeCost,
              enabled:
                  _busyAction == null &&
                  economy.canRefillStreakFreeze &&
                  freezeCost != null,
              busy: _busyAction == 'freeze',
              onTap: freezeCost == null
                  ? null
                  : () => _confirmAndRun(
                      actionId: 'freeze',
                      title: lang.t(
                        '連続記録の保護を補充しますか？',
                        'Refill a streak shield?',
                      ),
                      body: lang.t(
                        '結晶$freezeCost個を使い、今週の保護を1回分補充します。',
                        'Spend $freezeCost gems to add one shield this week.',
                      ),
                      action: widget.onRefillStreakFreeze,
                    ),
            ),
            const SizedBox(height: GameTokens.spaceMd),
            _EconomyItem(
              key: const ValueKey('economy-hearts-item'),
              actionId: 'hearts',
              icon: Icons.favorite_rounded,
              title: lang.t('学習ハートを全回復', 'Refill all learning hearts'),
              description: lang.t(
                '固定課題で使うハートを${widget.player.maxChallengeHearts}個まで戻します。30分ごと、または回復練習でも1個戻ります。',
                'Restore hearts to ${widget.player.maxChallengeHearts}. You can also recover one every 30 minutes or with a recovery exercise.',
              ),
              currentLabel: lang.t(
                '現在 ${widget.player.challengeHearts} / ${widget.player.maxChallengeHearts}',
                'Currently ${widget.player.challengeHearts} / ${widget.player.maxChallengeHearts}',
              ),
              cost: heartCost,
              enabled:
                  _busyAction == null &&
                  economy.canRecoverChallengeHearts &&
                  heartCost != null,
              busy: _busyAction == 'hearts',
              onTap: heartCost == null
                  ? null
                  : () => _confirmAndRun(
                      actionId: 'hearts',
                      title: lang.t(
                        '学習ハートを全回復しますか？',
                        'Refill all learning hearts?',
                      ),
                      body: lang.t(
                        '結晶$heartCost個を使い、学習ハートを全回復します。',
                        'Spend $heartCost gems to refill all learning hearts.',
                      ),
                      action: widget.onRecoverChallengeHearts,
                    ),
            ),
            const SizedBox(height: GameTokens.spaceXl),
            Text(
              lang.t('Pathマスコット', 'Path mascot'),
              style: t.textTheme.titleLarge
                  ?.copyWith(color: colors.ink)
                  .jaWeight(FontWeight.w900),
            ),
            const SizedBox(height: GameTokens.spaceXs),
            Text(
              lang.t(
                '見た目だけを変更します。学習進行・XP・正答・ハートは購入できません。',
                'Change the look only. You cannot buy progress, XP, correct answers, or hearts.',
              ),
              style: t.textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
            ),
            const SizedBox(height: GameTokens.spaceMd),
            for (
              var index = 0;
              index < economy.cosmeticItems.length;
              index++
            ) ...[
              if (index > 0) const SizedBox(height: GameTokens.spaceMd),
              GameCosmeticItemCard(
                key: ValueKey(
                  'economy-cosmetic-${economy.cosmeticItems[index].productId}',
                ),
                item: economy.cosmeticItems[index],
                busy:
                    _busyAction ==
                    'cosmetic:${economy.cosmeticItems[index].productId}',
                onPurchase: () => _confirmAndRun(
                  actionId:
                      'cosmetic:${economy.cosmeticItems[index].productId}',
                  title: lang.t(
                    '${economy.cosmeticItems[index].title}を購入しますか？',
                    'Buy ${economy.cosmeticItems[index].title}?',
                  ),
                  body: lang.t(
                    '結晶${economy.cosmeticItems[index].gemCost}個を使い、Pathの見た目だけを変更します。学習進行や正答は変わりません。',
                    'Spend ${economy.cosmeticItems[index].gemCost} gems to change the look of your Path. Progress and answers stay the same.',
                  ),
                  action: () => widget.onPurchaseCosmetic(
                    economy.cosmeticItems[index].productId,
                  ),
                ),
                onEquip: () => _runAction(
                  actionId:
                      'cosmetic:${economy.cosmeticItems[index].productId}',
                  action: () => widget.onEquipCosmetic(
                    economy.cosmeticItems[index].productId,
                  ),
                ),
              ),
            ],
            if (_status != null) ...[
              const SizedBox(height: GameTokens.spaceMd),
              Semantics(
                liveRegion: true,
                label: _status,
                child: Text(
                  _status!,
                  key: const ValueKey('game-economy-status'),
                  style: t.textTheme.bodyMedium?.copyWith(color: colors.ink),
                ),
              ),
            ],
            const SizedBox(height: GameTokens.spaceLg),
            Container(
              padding: const EdgeInsets.all(GameTokens.spaceLg),
              decoration: BoxDecoration(
                color: colors.surfaceRaised,
                borderRadius: BorderRadius.circular(GameTokens.radiusMd),
                border: Border.all(color: colors.border),
              ),
              child: Text(
                lang.t(
                  '結晶は速度や誤答回数では増減しません。Timed当日券は練習タブで参加前に確認します。Match / Lightning、時間回復、ハート回復練習は無料です。学校モードでは結晶経済を使いません。',
                  'Speed and wrong answers do not affect gems. Confirm a Timed day pass in Practice before joining. Match, Lightning, timed recovery, and heart recovery practice are free. Gems are not used in class mode.',
                ),
                style: t.textTheme.bodySmall?.copyWith(color: colors.inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EconomyItem extends StatelessWidget {
  const _EconomyItem({
    super.key,
    required this.actionId,
    required this.icon,
    required this.title,
    required this.description,
    required this.currentLabel,
    required this.cost,
    required this.enabled,
    required this.busy,
    required this.onTap,
  });

  final String actionId;
  final IconData icon;
  final String title;
  final String description;
  final String currentLabel;
  final int? cost;
  final bool enabled;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    final action = enabled ? onTap : null;
    return Semantics(
      button: action != null,
      enabled: action != null,
      label:
          '$title。$description。$currentLabel。'
          '${cost == null ? lang.t('利用できません', 'Unavailable') : lang.t('結晶$cost個', '$cost gems')}。'
          '${enabled ? lang.t('交換できます', 'Available to exchange') : lang.t('現在は交換できません', 'Cannot exchange right now')}',
      onTap: action,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(GameTokens.spaceLg),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(GameTokens.radiusLg),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: colors.gem, size: 30),
                  const SizedBox(width: GameTokens.spaceSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: t.textTheme.titleMedium
                              ?.copyWith(color: colors.ink)
                              .jaWeight(FontWeight.w800),
                        ),
                        const SizedBox(height: GameTokens.spaceXs),
                        Text(
                          currentLabel,
                          style: t.textTheme.labelLarge?.copyWith(
                            color: colors.pathActive,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: GameTokens.spaceSm),
              Text(
                description,
                style: t.textTheme.bodySmall?.copyWith(color: colors.inkMuted),
              ),
              const SizedBox(height: GameTokens.spaceMd),
              FilledButton.icon(
                key: ValueKey('economy-$actionId-action'),
                onPressed: action,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.diamond_rounded),
                label: Text(
                  busy
                      ? lang.t('記録中…', 'Saving…')
                      : cost == null
                      ? lang.t('利用できません', 'Unavailable')
                      : lang.t('◆ $cost で交換', 'Exchange for ◆ $cost'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
