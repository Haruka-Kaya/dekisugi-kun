import '../../config/app_language.dart';
import '../../models/game_economy.dart';
import '../domain/learning_economy.dart';

/// 固定商品とpersonal所有状態を交換面DTOへ変換する。
final class LearningEconomyCatalogProjection {
  const LearningEconomyCatalogProjection({
    this.catalog = const SafeLearningEconomyCatalogV1(),
  });

  final SafeLearningEconomyCatalogV1 catalog;

  List<GameCosmeticItemView> cosmetics({
    required int gems,
    required LearningCosmeticState state,
    bool schoolMode = false,
  }) {
    catalog.validate();
    if (schoolMode) return const [];
    final result = <GameCosmeticItemView>[];
    for (final product in SafeLearningEconomyCatalogV1.cosmetics) {
      final owned = product.isDefault || state.owns(product.productId);
      result.add(
        GameCosmeticItemView(
          productId: product.productId,
          title: t(product.title, product.titleEn),
          description: t(product.description, product.descriptionEn),
          gemCost: product.gemCost,
          mascotStyle: product.mascotStyle,
          owned: owned,
          equipped: state.equippedPathMascotId == product.productId,
          canPurchase:
              !product.requiresPlusAccess &&
              !owned &&
              gems >= product.gemCost,
          requiresPlusAccess: product.requiresPlusAccess,
        ),
      );
    }
    return List.unmodifiable(result);
  }
}
