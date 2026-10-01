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
/// 利用資格にも影響させず、観測記録の保護・試行余力・観察装備だけを補助する。
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
            child: const Text('やめる'),
          ),
          FilledButton(
            key: ValueKey('economy-$actionId-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('結晶を使う'),
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
      setState(() => _status = '交換を端末へ記録しました。');
      widget.onClose();
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = '交換できませんでした。残高と現在の状態を確認してください。');
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
                        'ひらめき結晶',
                        style: t.textTheme.headlineSmall
                            ?.copyWith(color: colors.ink)
                            .jaWeight(FontWeight.w900),
                      ),
                      const SizedBox(height: GameTokens.spaceXs),
                      Semantics(
                        label: '現在、結晶${economy.gems}個',
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
                  tooltip: '閉じる',
                  onPressed: _busyAction == null ? widget.onClose : null,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: GameTokens.spaceMd),
            Text(
              '探究で得た結晶は、忙しい日に連続観察を守る保護、試行余力、デキすぎ君の装いにだけ使えます。学習を速くしたり、正答を買ったりはできません。実課金では増やせません。',
              style: t.textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
            ),
            const SizedBox(height: GameTokens.spaceXl),
            _EconomyItem(
              key: const ValueKey('economy-freeze-item'),
              actionId: 'freeze',
              icon: Icons.ac_unit_rounded,
              title: 'お休みの日の保護を補充',
              description:
                  '1日観察できない日があっても、連続観察の記録を守る1回分です。今週の補充上限に達した場合は使えません。',
              currentLabel: '現在 ${widget.player.freezeCount}回分',
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
                      title: 'お休みの日の保護を補充しますか？',
                      body: '結晶$freezeCost個を使い、1日空いても連続観察の記録を守る保護を1回分補充します。',
                      action: widget.onRefillStreakFreeze,
                    ),
            ),
            const SizedBox(height: GameTokens.spaceMd),
            _EconomyItem(
              key: const ValueKey('economy-hearts-item'),
              actionId: 'hearts',
              icon: Icons.science_rounded,
              title: '試行余力を全回復',
              description:
                  '固定課題で使う試行余力を${widget.player.maxChallengeHearts}枠まで戻します。30分ごと、または回復実験でも1枠戻ります。',
              currentLabel:
                  '現在 ${widget.player.challengeHearts} / ${widget.player.maxChallengeHearts}',
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
                      title: '試行余力を全回復しますか？',
                      body: '結晶$heartCost個を使い、試行余力を全回復します。',
                      action: widget.onRecoverChallengeHearts,
                    ),
            ),
            const SizedBox(height: GameTokens.spaceXl),
            Text(
              'デキすぎ君の観察装備',
              style: t.textTheme.titleLarge
                  ?.copyWith(color: colors.ink)
                  .jaWeight(FontWeight.w900),
            ),
            const SizedBox(height: GameTokens.spaceXs),
            Text(
              '見た目だけを変更します。探究の進行・探究記録・正答・試行余力は購入できません。',
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
                  title: '${economy.cosmeticItems[index].title}を購入しますか？',
                  body:
                      '結晶${economy.cosmeticItems[index].gemCost}個を使い、探究ノートの見た目だけを変更します。探究の進行や正答は変わりません。',
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
                '結晶は速度や誤答回数では増減しません。時間観察の当日券は「実験」で参加前に確認します。対応づけ実験、連続観察、時間回復、試行余力の回復実験は無料です。学校モードでは結晶経済を使いません。',
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
          '${cost == null ? '利用できません' : '結晶$cost個'}。'
          '${enabled ? '交換できます' : '現在は交換できません'}',
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
                    : const Icon(Icons.hexagon_rounded),
                label: Text(
                  busy
                      ? '記録中…'
                      : cost == null
                      ? '利用できません'
                      : '◆ $cost で交換',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
