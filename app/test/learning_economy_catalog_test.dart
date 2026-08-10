import 'package:dekisugi/learning/domain/learning_economy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const catalog = SafeLearningEconomyCatalogV1();

  test('固定catalogは見た目と任意challengeだけを持ちID・styleが重複しない', () {
    expect(catalog.validate, returnsNormally);
    expect(
      SafeLearningEconomyCatalogV1.cosmetics.map((item) => item.productId),
      hasLength(3),
    );
    expect(
      SafeLearningEconomyCatalogV1.cosmetics.map((item) => item.productId),
      unorderedEquals({
        SafeLearningEconomyCatalogV1.standardMascotId,
        SafeLearningEconomyCatalogV1.orbitMascotId,
        SafeLearningEconomyCatalogV1.novaMascotId,
      }),
    );
    expect(
      SafeLearningEconomyCatalogV1.cosmetics.map((item) => item.mascotStyle),
      unorderedEquals(LearningPathMascotStyle.values),
    );
    expect(
      SafeLearningEconomyCatalogV1.cosmetics.where((item) => item.isDefault),
      hasLength(1),
    );
    expect(SafeLearningEconomyCatalogV1.timedDayPass.gemCost, 1);
  });

  test('未知の商品IDはfail-closedで価格を返さない', () {
    expect(() => catalog.cosmetic('node.unlock.v1'), throwsArgumentError);
    expect(() => catalog.challengePass('xp.boost.v1'), throwsArgumentError);
  });
}
