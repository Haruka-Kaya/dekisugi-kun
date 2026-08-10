import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../models/game_economy.dart';
import '../models/game_path.dart';
import '../ui/_material.dart';
import 'learning_path.dart';

/// 固定catalogから投影されたPathマスコット商品だけを表示するカード。
///
/// 購入可否は保存層と同じcatalog projectionが決める。カードから価格や
/// 任意IDを組み立てず、呼び出し側へ固定product IDだけを返す。
class GameCosmeticItemCard extends StatelessWidget {
  const GameCosmeticItemCard({
    super.key,
    required this.item,
    required this.busy,
    required this.onPurchase,
    required this.onEquip,
  });

  final GameCosmeticItemView item;
  final bool busy;
  final VoidCallback? onPurchase;
  final VoidCallback? onEquip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    final VoidCallback? action = busy
        ? null
        : item.equipped
        ? null
        : item.owned
        ? onEquip
        : item.canPurchase
        ? onPurchase
        : null;
    final actionLabel = busy
        ? '記録中…'
        : item.equipped
        ? '装備中'
        : item.owned
        ? 'この見た目にする'
        : item.canPurchase
        ? '◆ ${item.gemCost} で購入して装備'
        : '結晶が足りません';
    final stateLabel = item.equipped
        ? '装備中'
        : item.owned
        ? '購入済み'
        : '未購入、結晶${item.gemCost}個';

    return Semantics(
      container: true,
      button: action != null,
      enabled: action != null,
      label: '${item.title}。${item.description}。$stateLabel。$actionLabel',
      onTap: action,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(GameTokens.spaceLg),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(GameTokens.radiusLg),
            border: Border.all(
              color: item.equipped ? colors.pathActive : colors.border,
              width: item.equipped ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox.square(
                    dimension: 64,
                    child: Center(
                      child: PathMascotPreview(
                        reaction: GameCharacterReaction.invite,
                        size: 58,
                        style: item.mascotStyle,
                      ),
                    ),
                  ),
                  const SizedBox(width: GameTokens.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: colors.ink)
                              .jaWeight(FontWeight.w800),
                        ),
                        const SizedBox(height: GameTokens.spaceXs),
                        Text(
                          stateLabel,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: item.equipped
                                ? colors.pathActive
                                : colors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: GameTokens.spaceSm),
              Text(
                item.description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.inkMuted,
                ),
              ),
              const SizedBox(height: GameTokens.spaceMd),
              FilledButton(
                key: ValueKey('economy-cosmetic-${item.productId}-action'),
                onPressed: action,
                child: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
