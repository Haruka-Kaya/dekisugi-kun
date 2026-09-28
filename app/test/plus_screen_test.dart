import 'dart:async';

import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/models/purchase.dart';
import 'package:dekisugi/screens/plus_screen.dart';
import 'package:dekisugi/services/purchase_service.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:flutter_test/flutter_test.dart';

const monthly = PlusPackage(
  id: 'current::monthly',
  offeringIdentifier: 'current',
  packageIdentifier: r'$rc_monthly',
  productIdentifier: 'plus_monthly',
  title: 'Plus 月ごと',
  description: 'ストアが返した説明',
  price: '¥980',
  packageType: 'monthly',
  billingModel: PlusBillingModel.autoRenewingSubscription,
  subscriptionPeriod: 'P1M',
);

const yearly = PlusPackage(
  id: 'current::annual',
  offeringIdentifier: 'current',
  packageIdentifier: r'$rc_annual',
  productIdentifier: 'plus_annual',
  title: 'Plus 年ごと',
  description: '別のストア商品',
  price: '¥8,800',
  packageType: 'annual',
  billingModel: PlusBillingModel.autoRenewingSubscription,
  subscriptionPeriod: 'P1Y',
);

const missingPeriod = PlusPackage(
  id: 'current::unknown-period',
  offeringIdentifier: 'current',
  packageIdentifier: r'$rc_custom',
  productIdentifier: 'plus_custom',
  title: 'Plus 期間不明',
  description: '期間が届かなかった商品',
  price: '¥500',
  packageType: 'custom',
  billingModel: PlusBillingModel.autoRenewingSubscription,
);

const introductory = PlusPackage(
  id: 'current::intro',
  offeringIdentifier: 'current',
  packageIdentifier: r'$rc_monthly_intro',
  productIdentifier: 'plus_monthly_intro',
  title: 'Plus 体験つき',
  description: '体験条件がある商品',
  price: '¥980',
  packageType: 'monthly',
  billingModel: PlusBillingModel.autoRenewingSubscription,
  subscriptionPeriod: 'P1M',
  hasIntroductoryOffer: true,
);

const readyOverview = PurchaseOverview(
  availability: PurchaseAvailability.ready,
  plus: PlusAccess.inactive(),
  currentOffering: PlusOffering(identifier: 'current', packages: [monthly]),
);

void main() {
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
  }

  Widget wrap(
    FakePurchaseService purchases, {
    Future<bool> Function()? onEntitlementSync,
    Future<void> Function()? onPlusActivated,
    Future<bool> Function(Uri uri)? openExternalUri,
    VoidCallback? onClose,
    double textScale = 1,
  }) {
    return MaterialApp(
      theme: buildAppTheme(Brightness.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: PlusScreen(
        purchaseService: purchases,
        onEntitlementSync: onEntitlementSync,
        onPlusActivated: onPlusActivated,
        openExternalUri: openExternalUri,
        onClose: onClose,
      ),
    );
  }

  testWidgets('load中を読み上げ、Current Offeringの実価格だけを表示する', (tester) async {
    final load = Completer<PurchaseOverview>();
    final purchases = FakePurchaseService(loadCompleter: load);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(wrap(purchases));

      await reveal(tester, find.byType(CircularProgressIndicator));
      expect(find.bySemanticsLabel('ストアのプランを読み込んでいます'), findsOneWidget);

      load.complete(readyOverview);
      await tester.pumpAndSettle();
      await reveal(tester, find.text('¥980で申し込む'));

      expect(find.text('Plus 月ごと'), findsOneWidget);
      expect(find.text('ストアが返した説明'), findsOneWidget);
      expect(find.text('¥980 / 1か月'), findsOneWidget);
      expect(find.textContaining('1か月ごとに¥980で自動更新されます'), findsOneWidget);
      expect(find.text('¥980で申し込む'), findsOneWidget);
      expect(find.textContaining('無料体験'), findsNothing);
      expect(find.textContaining('割引'), findsNothing);
      expect(find.textContaining('P1M'), findsNothing);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('年額も月額換算せず、ストアの年額と実期間をそのまま表示する', (tester) async {
    final purchases = FakePurchaseService(
      overview: const PurchaseOverview(
        availability: PurchaseAvailability.ready,
        plus: PlusAccess.inactive(),
        currentOffering: PlusOffering(
          identifier: 'current',
          packages: [yearly],
        ),
      ),
    );
    await tester.pumpWidget(wrap(purchases));
    await tester.pumpAndSettle();

    await reveal(tester, find.text('¥8,800 / 1年'));
    expect(find.text('¥8,800 / 1年'), findsOneWidget);
    expect(find.textContaining('1年ごとに¥8,800で自動更新されます'), findsOneWidget);
    expect(find.textContaining('月あたり'), findsNothing);
  });

  testWidgets('期間欠損や未表示の体験条件がある商品は購入をfail-closedする', (tester) async {
    final purchases = FakePurchaseService(
      overview: const PurchaseOverview(
        availability: PurchaseAvailability.ready,
        plus: PlusAccess.inactive(),
        currentOffering: PlusOffering(
          identifier: 'current',
          packages: [missingPeriod, introductory],
        ),
      ),
    );
    await tester.pumpWidget(wrap(purchases));
    await tester.pumpAndSettle();

    await reveal(tester, find.textContaining('無料体験または割引後の請求条件'));
    expect(find.textContaining('請求期間と更新条件を確認できない'), findsOneWidget);
    expect(find.textContaining('無料体験または割引後の請求条件'), findsOneWidget);
    expect(
      tester
          .widgetList<FilledButton>(find.byType(FilledButton))
          .where((button) => button.onPressed == null),
      hasLength(2),
    );
    expect(purchases.purchaseCalls, 0);
  });

  testWidgets('Plusが広げる範囲と、無料のまま残す学習機能を明記する', (tester) async {
    await tester.pumpWidget(wrap(FakePurchaseService()));
    await tester.pumpAndSettle();

    expect(find.text('教材とミッションは全部無料'), findsOneWidget);
    expect(find.textContaining('およそ10分'), findsWidgets);
    expect(find.text('限定マスコットと、会話回数の上限なし'), findsOneWidget);
    expect(find.textContaining('本人のノート'), findsOneWidget);
    expect(find.textContaining('文字入力'), findsOneWidget);
    expect(find.textContaining('アクセシビリティ機能'), findsOneWidget);
    expect(find.textContaining('REPAIR'), findsOneWidget);

    for (final gameWord in ['XP', 'ポイント', '連続記録', 'ランキング']) {
      expect(find.textContaining(gameWord), findsNothing);
    }
  });

  testWidgets('購入成功と会話枠同期の両方を確認してから有効表示する', (tester) async {
    var syncCalls = 0;
    var perkGrants = 0;
    final purchases = FakePurchaseService(
      purchaseResult: const PurchaseActionResult(
        outcome: PurchaseActionOutcome.completed,
        plus: PlusAccess(isActive: true, willRenew: true),
      ),
    );
    await tester.pumpWidget(
      wrap(
        purchases,
        onEntitlementSync: () async {
          syncCalls++;
          return true;
        },
        onPlusActivated: () async {
          perkGrants++;
        },
      ),
    );
    await tester.pumpAndSettle();

    final buy = find.text('¥980で申し込む');
    await reveal(tester, buy);
    await tester.tap(buy);
    await tester.pumpAndSettle();

    expect(purchases.purchaseCalls, 1);
    expect(purchases.lastPackage, same(monthly));
    expect(syncCalls, 1);
    expect(perkGrants, 1);
    expect(find.text('Plusは有効です'), findsOneWidget);
    expect(find.textContaining('限定マスコットを受け取りました'), findsOneWidget);
    expect(find.text('¥980で申し込む'), findsNothing);
  });

  testWidgets('購入キャンセルをエラー扱いせず、再購入可能なままにする', (tester) async {
    final purchases = FakePurchaseService(
      purchaseResult: const PurchaseActionResult(
        outcome: PurchaseActionOutcome.cancelled,
        plus: null,
      ),
    );
    await tester.pumpWidget(wrap(purchases));
    await tester.pumpAndSettle();

    final buy = find.text('¥980で申し込む');
    await reveal(tester, buy);
    await tester.tap(buy);
    await tester.pumpAndSettle();

    expect(find.textContaining('購入は完了していません'), findsOneWidget);
    expect(find.textContaining('料金は発生していません'), findsOneWidget);
    expect(find.text('¥980で申し込む'), findsOneWidget);
  });

  testWidgets('購入失敗を成功に見せず、同じプランから再試行できる', (tester) async {
    final purchases = FakePurchaseService(
      purchaseResult: const PurchaseActionResult(
        outcome: PurchaseActionOutcome.failed,
        plus: null,
        failureCode: 'networkError',
      ),
    );
    await tester.pumpWidget(wrap(purchases));
    await tester.pumpAndSettle();

    final buy = find.text('¥980で申し込む');
    await reveal(tester, buy);
    await tester.tap(buy);
    await tester.pumpAndSettle();

    expect(find.textContaining('購入を完了できませんでした'), findsOneWidget);
    expect(find.text('Plusは有効です'), findsNothing);
    expect(find.text('¥980で申し込む'), findsOneWidget);
  });

  testWidgets('有効なPlusをloadしたら再購入を勧めない', (tester) async {
    final purchases = FakePurchaseService(
      overview: const PurchaseOverview(
        availability: PurchaseAvailability.ready,
        plus: PlusAccess(isActive: true, willRenew: true),
        currentOffering: PlusOffering(
          identifier: 'current',
          packages: [monthly],
        ),
      ),
    );
    await tester.pumpWidget(wrap(purchases));
    await tester.pumpAndSettle();

    await reveal(tester, find.text('Plusは有効です'));
    expect(find.text('Plusは有効です'), findsOneWidget);
    expect(find.text('¥980で申し込む'), findsNothing);
    expect(find.text('購入情報をもう一度確認'), findsOneWidget);
  });

  testWidgets('RevenueCatの実管理URLとPrivacy・ストア規約へ到達できる', (tester) async {
    final opened = <Uri>[];
    final purchases = FakePurchaseService(
      overview: const PurchaseOverview(
        availability: PurchaseAvailability.ready,
        plus: PlusAccess(
          isActive: true,
          willRenew: true,
          managementUrl: 'https://example.com/store/manage',
        ),
        currentOffering: PlusOffering(
          identifier: 'current',
          packages: [monthly],
        ),
      ),
    );
    await tester.pumpWidget(
      wrap(
        purchases,
        openExternalUri: (uri) async {
          opened.add(uri);
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    for (final label in ['ストアで購読を管理・解約', 'ストア利用規約', 'プライバシーポリシー']) {
      final link = find.text(label);
      await reveal(tester, link);
      await tester.tap(link);
      await tester.pumpAndSettle();
    }

    expect(opened.first, Uri.parse('https://example.com/store/manage'));
    expect(
      opened.last,
      Uri.parse('https://rika-chousa.vercel.app/privacy.html'),
    );
    expect(opened, hasLength(3));
  });

  testWidgets('外部リンクの連打を二重送信せず、失敗を画面で知らせる', (tester) async {
    final opening = Completer<bool>();
    var openCalls = 0;
    final purchases = FakePurchaseService();
    await tester.pumpWidget(
      wrap(
        purchases,
        openExternalUri: (_) {
          openCalls++;
          return opening.future;
        },
      ),
    );
    await tester.pumpAndSettle();

    final privacy = find.text('プライバシーポリシー');
    await reveal(tester, privacy);
    await tester.tap(privacy);
    await tester.tap(privacy);
    await tester.pump();

    expect(openCalls, 1);
    opening.complete(false);
    await tester.pumpAndSettle();
    expect(find.textContaining('ページを開けませんでした'), findsOneWidget);
  });

  testWidgets('起動時に有効なPlusを見つけたら会話枠も照合する', (tester) async {
    var syncCalls = 0;
    final purchases = FakePurchaseService(
      overview: const PurchaseOverview(
        availability: PurchaseAvailability.ready,
        plus: PlusAccess(isActive: true, willRenew: true),
        currentOffering: PlusOffering(
          identifier: 'current',
          packages: [monthly],
        ),
      ),
    );
    await tester.pumpWidget(
      wrap(
        purchases,
        onEntitlementSync: () async {
          syncCalls++;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(syncCalls, 1);
    await reveal(tester, find.text('Plusは有効です'));
    expect(find.text('Plusと会話枠の状態を確認しました。'), findsOneWidget);
    expect(find.text('¥980で申し込む'), findsNothing);
  });

  testWidgets('起動時の会話枠照合失敗は購入でなく同期だけを再試行する', (tester) async {
    var syncCalls = 0;
    final purchases = FakePurchaseService(
      overview: const PurchaseOverview(
        availability: PurchaseAvailability.ready,
        plus: PlusAccess(isActive: true),
        currentOffering: PlusOffering(
          identifier: 'current',
          packages: [monthly],
        ),
      ),
    );
    await tester.pumpWidget(
      wrap(
        purchases,
        onEntitlementSync: () async {
          syncCalls++;
          return syncCalls > 1;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(syncCalls, 1);
    await reveal(tester, find.text('会話枠への反映を再試行'));
    expect(find.textContaining('購入をやり直す必要はありません'), findsOneWidget);
    expect(purchases.purchaseCalls, 0);

    await tester.tap(find.text('会話枠への反映を再試行'));
    await tester.pumpAndSettle();

    expect(syncCalls, 2);
    expect(purchases.purchaseCalls, 0);
    expect(find.text('Plusは有効です'), findsOneWidget);
  });

  testWidgets('disabledを隠さず、架空のプランや復元操作を出さない', (tester) async {
    final purchases = FakePurchaseService(
      enabled: false,
      overview: const PurchaseOverview.disabled(),
    );
    await tester.pumpWidget(wrap(purchases));
    await tester.pumpAndSettle();

    await reveal(tester, find.text('このアプリではPlusを購入できません'));
    expect(find.text('このアプリではPlusを購入できません'), findsOneWidget);
    expect(find.textContaining('そのまま使えます'), findsOneWidget);
    expect(find.text('¥980'), findsNothing);
    expect(find.text('以前の購入を復元'), findsNothing);
  });

  testWidgets('復元でinactiveなら購入済みに見せず、新規請求もないと伝える', (tester) async {
    final purchases = FakePurchaseService(
      restoreResult: const PurchaseActionResult(
        outcome: PurchaseActionOutcome.completed,
        plus: PlusAccess.inactive(),
      ),
    );
    await tester.pumpWidget(wrap(purchases));
    await tester.pumpAndSettle();

    final restore = find.text('以前の購入を復元');
    await reveal(tester, restore);
    await tester.tap(restore);
    await tester.pumpAndSettle();

    expect(purchases.restoreCalls, 1);
    expect(find.textContaining('有効なPlusは見つかりませんでした'), findsOneWidget);
    expect(find.textContaining('新しい購入は行っていません'), findsOneWidget);
    expect(find.text('Plusは有効です'), findsNothing);
  });

  testWidgets('復元でactiveのときだけ会話枠同期を実行する', (tester) async {
    var syncCalls = 0;
    final purchases = FakePurchaseService(
      restoreResult: const PurchaseActionResult(
        outcome: PurchaseActionOutcome.completed,
        plus: PlusAccess(isActive: true),
      ),
    );
    await tester.pumpWidget(
      wrap(
        purchases,
        onEntitlementSync: () async {
          syncCalls++;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    final restore = find.text('以前の購入を復元');
    await reveal(tester, restore);
    await tester.tap(restore);
    await tester.pumpAndSettle();

    expect(syncCalls, 1);
    expect(find.text('Plusは有効です'), findsOneWidget);
  });

  testWidgets('購入結果がinactiveなら会話枠同期を呼ばない', (tester) async {
    var syncCalls = 0;
    final purchases = FakePurchaseService(
      purchaseResult: const PurchaseActionResult(
        outcome: PurchaseActionOutcome.completed,
        plus: PlusAccess.inactive(),
      ),
    );
    await tester.pumpWidget(
      wrap(
        purchases,
        onEntitlementSync: () async {
          syncCalls++;
          return true;
        },
      ),
    );
    await tester.pumpAndSettle();

    final buy = find.text('¥980で申し込む');
    await reveal(tester, buy);
    await tester.tap(buy);
    await tester.pumpAndSettle();

    expect(syncCalls, 0);
    expect(find.textContaining('Plusは有効になっていません'), findsOneWidget);
  });

  testWidgets('会話枠同期失敗は再購入させず、同期だけを再試行する', (tester) async {
    var syncCalls = 0;
    final purchases = FakePurchaseService(
      purchaseResult: const PurchaseActionResult(
        outcome: PurchaseActionOutcome.completed,
        plus: PlusAccess(isActive: true),
      ),
    );
    await tester.pumpWidget(
      wrap(
        purchases,
        onEntitlementSync: () async {
          syncCalls++;
          return syncCalls > 1;
        },
      ),
    );
    await tester.pumpAndSettle();

    final buy = find.text('¥980で申し込む');
    await reveal(tester, buy);
    await tester.tap(buy);
    await tester.pumpAndSettle();

    expect(find.textContaining('会話枠への反映を確認できませんでした'), findsOneWidget);
    expect(find.textContaining('購入をやり直す必要はありません'), findsOneWidget);
    expect(find.text('会話枠への反映を再試行'), findsOneWidget);
    expect(purchases.purchaseCalls, 1);

    await tester.tap(find.text('会話枠への反映を再試行'));
    await tester.pumpAndSettle();

    expect(syncCalls, 2);
    expect(purchases.purchaseCalls, 1);
    expect(find.text('Plusは有効です'), findsOneWidget);
  });

  testWidgets('会話枠同期の例外を画面エラーとして扱い、SDK購入は繰り返さない', (tester) async {
    final purchases = FakePurchaseService(
      purchaseResult: const PurchaseActionResult(
        outcome: PurchaseActionOutcome.completed,
        plus: PlusAccess(isActive: true),
      ),
    );
    await tester.pumpWidget(
      wrap(
        purchases,
        onEntitlementSync: () async => throw StateError('offline'),
      ),
    );
    await tester.pumpAndSettle();

    final buy = find.text('¥980で申し込む');
    await reveal(tester, buy);
    await tester.tap(buy);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('会話枠への反映を再試行'), findsOneWidget);
    expect(purchases.purchaseCalls, 1);
  });

  testWidgets('busy中の連打で購入を二重送信しない', (tester) async {
    final purchase = Completer<PurchaseActionResult>();
    final purchases = FakePurchaseService(purchaseCompleter: purchase);
    await tester.pumpWidget(wrap(purchases));
    await tester.pumpAndSettle();

    final button = find.text('¥980で申し込む');
    await reveal(tester, button);
    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();

    expect(purchases.purchaseCalls, 1);
    expect(find.text('ストアに確認しています…'), findsOneWidget);

    purchase.complete(
      const PurchaseActionResult(
        outcome: PurchaseActionOutcome.cancelled,
        plus: null,
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('購入操作は48dp以上で、価格を含むSemantics名を持つ', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(wrap(FakePurchaseService()));
      await tester.pumpAndSettle();

      final filled = find.widgetWithText(FilledButton, '¥980で申し込む');
      await reveal(tester, filled);
      expect(
        find.bySemanticsLabel(RegExp(r'Plus 月ごと、¥980、1か月ごとの自動更新、¥980で申し込む')),
        findsOneWidget,
      );
      expect(tester.getSize(filled).height, greaterThanOrEqualTo(48));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('320x568・文字200%でも横あふれせず末尾まで操作できる', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final purchases = FakePurchaseService(
      overview: const PurchaseOverview(
        availability: PurchaseAvailability.ready,
        plus: PlusAccess.inactive(),
        currentOffering: PlusOffering(
          identifier: 'current',
          packages: [monthly, yearly],
        ),
      ),
    );
    await tester.pumpWidget(wrap(purchases, textScale: 2));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('プライバシーポリシー'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('以前の購入を復元'), findsOneWidget);
    expect(find.text('ストアで購読を管理・解約'), findsOneWidget);
    expect(find.text('ストア利用規約'), findsOneWidget);
    expect(find.text('プライバシーポリシー'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.widgetWithText(TextButton, 'プライバシーポリシー')).height,
      greaterThanOrEqualTo(48),
    );
  });
}

class FakePurchaseService implements PurchaseService {
  FakePurchaseService({
    this.enabled = true,
    this.overview = readyOverview,
    this.purchaseResult = const PurchaseActionResult(
      outcome: PurchaseActionOutcome.completed,
      plus: PlusAccess(isActive: true),
    ),
    this.restoreResult = const PurchaseActionResult(
      outcome: PurchaseActionOutcome.completed,
      plus: PlusAccess.inactive(),
    ),
    this.loadCompleter,
    this.purchaseCompleter,
  });

  @override
  final bool enabled;
  final PurchaseOverview overview;
  final PurchaseActionResult purchaseResult;
  final PurchaseActionResult restoreResult;
  final Completer<PurchaseOverview>? loadCompleter;
  final Completer<PurchaseActionResult>? purchaseCompleter;

  int loadCalls = 0;
  int purchaseCalls = 0;
  int restoreCalls = 0;
  PlusPackage? lastPackage;

  @override
  Future<PurchaseOverview> load() {
    loadCalls++;
    return loadCompleter?.future ?? Future.value(overview);
  }

  @override
  Future<PurchaseActionResult> purchase(PlusPackage package) {
    purchaseCalls++;
    lastPackage = package;
    return purchaseCompleter?.future ?? Future.value(purchaseResult);
  }

  @override
  Future<PurchaseActionResult> restore() {
    restoreCalls++;
    return Future.value(restoreResult);
  }
}
