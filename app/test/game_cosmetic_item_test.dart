import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/learning/domain/learning_economy.dart';
import 'package:dekisugi/models/game_economy.dart';
import 'package:dekisugi/widgets/game_cosmetic_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _orbit = GameCosmeticItemView(
  productId: SafeLearningEconomyCatalogV1.orbitMascotId,
  title: '軌道リング',
  description: '見た目だけを変えます。',
  gemCost: 4,
  mascotStyle: LearningPathMascotStyle.orbit,
  owned: false,
  equipped: false,
  canPurchase: true,
);

Widget _host({
  GameCosmeticItemView item = _orbit,
  required VoidCallback onPurchase,
  required VoidCallback onEquip,
}) => MaterialApp(
  theme: buildAppTheme(Brightness.dark),
  home: Scaffold(
    body: SingleChildScrollView(
      child: GameCosmeticItemCard(
        item: item,
        busy: false,
        onPurchase: onPurchase,
        onEquip: onEquip,
      ),
    ),
  ),
);

void main() {
  testWidgets('未購入は固定productの購入操作だけを返し装備操作を呼ばない', (tester) async {
    var purchases = 0;
    var equips = 0;
    await tester.pumpWidget(
      _host(onPurchase: () => purchases++, onEquip: () => equips++),
    );

    expect(find.byKey(const ValueKey('path-mascot-orbit')), findsOneWidget);
    await tester.tap(
      find.byKey(
        const ValueKey('economy-cosmetic-cosmetic.path-mascot.orbit.v1-action'),
      ),
    );
    expect(purchases, 1);
    expect(equips, 0);
  });

  testWidgets('dark・320x568・文字200%で状態を色だけに頼らず表示する', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    const equipped = GameCosmeticItemView(
      productId: SafeLearningEconomyCatalogV1.orbitMascotId,
      title: '軌道リング',
      description: '見た目だけを変えます。',
      gemCost: 4,
      mascotStyle: LearningPathMascotStyle.orbit,
      owned: true,
      equipped: true,
      canPurchase: false,
    );
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(2),
        ),
        child: _host(item: equipped, onPurchase: () {}, onEquip: () {}),
      ),
    );

    expect(find.text('装備中'), findsWidgets);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
