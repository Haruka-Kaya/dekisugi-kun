import 'dart:async';

import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/learning/domain/learning_economy.dart';
import 'package:dekisugi/learning/services/learning_game_projection.dart';
import 'package:dekisugi/models/game_economy.dart';
import 'package:dekisugi/models/game_hub.dart';
import 'package:dekisugi/screens/game_economy_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _player = PlayerSummaryView(
  xp: 30,
  gems: 7,
  streakDays: 4,
  freezeCount: 0,
  challengeHearts: 3,
  maxChallengeHearts: 5,
  completedNodes: 2,
  totalNodes: 8,
  leagueName: '観察者',
  weeklyLeagueXp: 30,
  nextLeagueXp: 60,
);

const _economy = LearningEconomyView(
  available: true,
  gems: 7,
  streakFreezeRefillGemCost: 3,
  challengeHeartRecoveryGemCost: 2,
  canRefillStreakFreeze: true,
  canRecoverChallengeHearts: true,
  cosmeticItems: [
    GameCosmeticItemView(
      productId: SafeLearningEconomyCatalogV1.standardMascotId,
      title: 'いつものデキすぎ君',
      description: '標準の見た目です。',
      gemCost: 0,
      mascotStyle: LearningPathMascotStyle.standard,
      owned: true,
      equipped: true,
      canPurchase: false,
    ),
    GameCosmeticItemView(
      productId: SafeLearningEconomyCatalogV1.orbitMascotId,
      title: '軌道リング',
      description: '見た目だけを変えます。',
      gemCost: 4,
      mascotStyle: LearningPathMascotStyle.orbit,
      owned: false,
      equipped: false,
      canPurchase: true,
    ),
  ],
  equippedPathMascotStyle: LearningPathMascotStyle.standard,
  timedChallengePassGemCost: 1,
  timedChallengePassActive: false,
  canPurchaseTimedChallengePass: true,
);

Widget _host({
  required Future<void> Function() onFreeze,
  required Future<void> Function() onHearts,
  Future<void> Function(String productId)? onPurchase,
  Future<void> Function(String productId)? onEquip,
  LearningEconomyView economy = _economy,
}) => MaterialApp(
  theme: buildAppTheme(Brightness.light),
  home: Scaffold(
    body: GameEconomySheet(
      economy: economy,
      player: _player,
      onRefillStreakFreeze: onFreeze,
      onRecoverChallengeHearts: onHearts,
      onPurchaseCosmetic: onPurchase ?? (_) async {},
      onEquipCosmetic: onEquip ?? (_) async {},
      onClose: () {},
    ),
  ),
);

void main() {
  testWidgets('結晶消費は確認後だけ一度実行し、通常Pathを止めない説明を保つ', (tester) async {
    var calls = 0;
    final gate = Completer<void>();
    await tester.pumpWidget(
      _host(
        onFreeze: () async {
          calls++;
          await gate.future;
        },
        onHearts: () async {},
      ),
    );

    await tester.tap(find.byKey(const ValueKey('economy-freeze-action')));
    await tester.pump();
    expect(calls, 0);
    expect(find.text('連続記録の保護を補充しますか？'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('economy-freeze-confirm')));
    await tester.pump();
    expect(calls, 1);

    await tester.tap(find.byKey(const ValueKey('economy-hearts-action')));
    await tester.pump();
    expect(calls, 1, reason: '別操作も保存中は開始しない');
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('交換を端末へ記録しました。'), findsOneWidget);
    expect(find.textContaining('学習進行・XP・正答・ハートは購入できません'), findsOneWidget);
  });

  testWidgets('Pathマスコットは価格確認後だけ固定product IDで購入する', (tester) async {
    String? purchased;
    await tester.pumpWidget(
      _host(
        onFreeze: () async {},
        onHearts: () async {},
        onPurchase: (productId) async => purchased = productId,
      ),
    );

    final action = find.byKey(
      const ValueKey('economy-cosmetic-cosmetic.path-mascot.orbit.v1-action'),
    );
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(purchased, isNull);
    expect(find.text('軌道リングを購入しますか？'), findsOneWidget);
    expect(find.textContaining('学習進行や正答は変わりません'), findsOneWidget);
    await tester.tap(
      find.byKey(
        const ValueKey(
          'economy-cosmetic:cosmetic.path-mascot.orbit.v1-confirm',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(purchased, SafeLearningEconomyCatalogV1.orbitMascotId);
  });

  testWidgets('利用不可状態はcallbackを呼ばず、320dp・文字200%でoverflowしない', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var calls = 0;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(2),
        ),
        child: _host(
          economy: const LearningEconomyView(
            available: true,
            gems: 0,
            streakFreezeRefillGemCost: 3,
            challengeHeartRecoveryGemCost: 2,
            canRefillStreakFreeze: false,
            canRecoverChallengeHearts: false,
            cosmeticItems: [],
            equippedPathMascotStyle: LearningPathMascotStyle.standard,
            timedChallengePassGemCost: 1,
            timedChallengePassActive: false,
            canPurchaseTimedChallengePass: false,
          ),
          onFreeze: () async => calls++,
          onHearts: () async => calls++,
        ),
      ),
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('economy-hearts-action')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('economy-hearts-action')));
    await tester.pump();
    expect(calls, 0);
    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    semantics.dispose();
  });
}
