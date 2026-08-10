import 'package:dekisugi/learning/domain/learning_economy.dart';
import 'package:dekisugi/learning/services/learning_economy_catalog_projection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const projection = LearningEconomyCatalogProjection();

  test('標準は常時所有、購入済みだけ装備可能として固定価格を返す', () {
    const state = LearningCosmeticState(
      ownedProductIds: {
        SafeLearningEconomyCatalogV1.standardMascotId,
        SafeLearningEconomyCatalogV1.orbitMascotId,
      },
      equippedPathMascotId: SafeLearningEconomyCatalogV1.orbitMascotId,
    );
    final items = projection.cosmetics(gems: 5, state: state);
    final byId = {for (final item in items) item.productId: item};

    expect(byId[SafeLearningEconomyCatalogV1.standardMascotId]!.owned, isTrue);
    expect(byId[SafeLearningEconomyCatalogV1.orbitMascotId]!.equipped, isTrue);
    expect(byId[SafeLearningEconomyCatalogV1.novaMascotId]!.gemCost, 6);
    expect(
      byId[SafeLearningEconomyCatalogV1.novaMascotId]!.canPurchase,
      isFalse,
    );
  });

  test('schoolLocalはcatalogを渡しても交換商品を一件も返さない', () {
    expect(
      projection.cosmetics(
        gems: 100,
        state: const LearningCosmeticState.initial(),
        schoolMode: true,
      ),
      isEmpty,
    );
  });
}
