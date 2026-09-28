import 'dart:async';

import 'package:dekisugi/models/purchase.dart';
import 'package:dekisugi/services/device_identity.dart';
import 'package:dekisugi/services/purchase_config.dart';
import 'package:dekisugi/services/purchase_service.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const package = PlusPackage(
  id: 'current::monthly',
  offeringIdentifier: 'current',
  packageIdentifier: 'monthly',
  productIdentifier: 'plus_monthly',
  title: 'Plus 月額',
  description: '毎日の追加ミッション',
  price: '¥480',
  packageType: 'monthly',
  billingModel: PlusBillingModel.autoRenewingSubscription,
  subscriptionPeriod: 'P1M',
);

RevenueCatPurchaseConfig enabledConfig() => RevenueCatPurchaseConfig.fromValues(
  platform: TargetPlatform.android,
  releaseMode: false,
  web: false,
  androidPublicSdkKey: 'goog_public-test-value',
);

RevenueCatPurchaseService service(
  MemorySessionStore store,
  PurchaseAdapter adapter, {
  RevenueCatPurchaseConfig? config,
}) => RevenueCatPurchaseService(
  config: config ?? enabledConfig(),
  identity: DeviceIdentity(baseUrl: '', store: store),
  adapter: adapter,
);

void main() {
  test('disabledならidentityもadapterも触らない', () async {
    final store = MemorySessionStore();
    final adapter = FakePurchaseAdapter();
    final disabled = RevenueCatPurchaseConfig.fromValues(
      platform: TargetPlatform.android,
      releaseMode: false,
      web: false,
    );
    final purchases = service(store, adapter, config: disabled);

    final overview = await purchases.load();
    final purchase = await purchases.purchase(package);
    final restore = await purchases.restore();

    expect(purchases.enabled, isFalse);
    expect(overview.availability, PurchaseAvailability.disabled);
    expect(purchase.outcome, PurchaseActionOutcome.disabled);
    expect(restore.outcome, PurchaseActionOutcome.disabled);
    expect(adapter.configureCalls, 0);
    expect(await store.getSetting('device_id'), isNull);
  });

  test('loadで匿名UUID・Plus entitlement・current offeringを取得する', () async {
    final store = MemorySessionStore();
    final adapter = FakePurchaseAdapter(
      access: const PlusAccess(
        isActive: true,
        willRenew: true,
        productIdentifier: 'plus_monthly',
      ),
      offering: const PlusOffering(identifier: 'current', packages: [package]),
    );
    final purchases = service(store, adapter);

    final overview = await purchases.load();

    expect(overview.availability, PurchaseAvailability.ready);
    expect(overview.plus.isActive, isTrue);
    expect(overview.currentOffering?.packages.single.price, '¥480');
    expect(adapter.configureCalls, 1);
    expect(adapter.publicSdkKey, 'goog_public-test-value');
    expect(adapter.anonymousAppUserId, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(adapter.entitlementIdentifiers, everyElement('plus'));
  });

  test('configureは並行操作を含めて1回だけ', () async {
    final store = MemorySessionStore();
    final adapter = FakePurchaseAdapter(configureDelay: true);
    final purchases = service(store, adapter);

    final futures = [
      purchases.load(),
      purchases.restore(),
      purchases.purchase(package),
    ];
    await Future<void>.delayed(Duration.zero);
    expect(adapter.configureCalls, 1);
    adapter.finishConfigure();
    await Future.wait(futures);

    expect(adapter.configureCalls, 1);
  });

  test('購入成功後のPlus状態を返す', () async {
    final adapter = FakePurchaseAdapter(
      purchaseAccess: const PlusAccess(
        isActive: true,
        willRenew: true,
        isTrial: true,
      ),
    );

    final result = await service(
      MemorySessionStore(),
      adapter,
    ).purchase(package);

    expect(result.outcome, PurchaseActionOutcome.completed);
    expect(result.plus?.isActive, isTrue);
    expect(result.plus?.isTrial, isTrue);
    expect(adapter.purchasedPackage, same(package));
  });

  test('ユーザーキャンセルは失敗と区別する', () async {
    final adapter = FakePurchaseAdapter(cancelPurchase: true);

    final result = await service(
      MemorySessionStore(),
      adapter,
    ).purchase(package);

    expect(result.outcome, PurchaseActionOutcome.cancelled);
    expect(result.plus, isNull);
    expect(result.failureCode, isNull);
  });

  test('購入エラーはSDKの生メッセージでなく安定codeを返す', () async {
    final adapter = FakePurchaseAdapter(
      purchaseError: const PurchaseSdkException('networkError'),
    );

    final result = await service(
      MemorySessionStore(),
      adapter,
    ).purchase(package);

    expect(result.outcome, PurchaseActionOutcome.failed);
    expect(result.plus, isNull);
    expect(result.failureCode, 'networkError');
  });

  test('復元完了は購入が無い場合も完了としてinactiveを返す', () async {
    final result = await service(
      MemorySessionStore(),
      FakePurchaseAdapter(),
    ).restore();

    expect(result.outcome, PurchaseActionOutcome.completed);
    expect(result.plus?.isActive, isFalse);
  });

  test('load失敗は一時利用不可になり、例外をUIへ投げない', () async {
    final adapter = FakePurchaseAdapter(
      loadError: const PurchaseSdkException('offlineConnectionError'),
    );

    final overview = await service(MemorySessionStore(), adapter).load();

    expect(overview.availability, PurchaseAvailability.unavailable);
    expect(overview.failureCode, 'offlineConnectionError');
  });

  test('Offering取得だけ失敗しても、確認済みPlus権限を失効扱いにしない', () async {
    final adapter = FakePurchaseAdapter(
      access: const PlusAccess(isActive: true),
      offeringError: const PurchaseSdkException('networkError'),
    );

    final overview = await service(MemorySessionStore(), adapter).load();

    expect(overview.availability, PurchaseAvailability.unavailable);
    expect(overview.plus.isActive, isTrue);
    expect(overview.currentOffering, isNull);
  });
}

class FakePurchaseAdapter implements PurchaseAdapter {
  FakePurchaseAdapter({
    this.access = const PlusAccess.inactive(),
    this.offering,
    this.purchaseAccess = const PlusAccess.inactive(),
    this.cancelPurchase = false,
    this.purchaseError,
    this.loadError,
    this.offeringError,
    this.configureDelay = false,
  });

  final PlusAccess access;
  final PlusOffering? offering;
  final PlusAccess purchaseAccess;
  final bool cancelPurchase;
  final Object? purchaseError;
  final Object? loadError;
  final Object? offeringError;
  final bool configureDelay;
  final Completer<void> _configureCompleter = Completer<void>();

  int configureCalls = 0;
  String? publicSdkKey;
  String? anonymousAppUserId;
  PlusPackage? purchasedPackage;
  final List<String> entitlementIdentifiers = [];

  void finishConfigure() {
    if (!_configureCompleter.isCompleted) _configureCompleter.complete();
  }

  @override
  Future<void> configure({
    required String publicSdkKey,
    required String anonymousAppUserId,
  }) async {
    configureCalls++;
    this.publicSdkKey = publicSdkKey;
    this.anonymousAppUserId = anonymousAppUserId;
    if (configureDelay) await _configureCompleter.future;
  }

  @override
  Future<PlusOffering?> currentOffering() async {
    if (offeringError case final error?) throw error;
    return offering;
  }

  @override
  Future<PlusAccess> plusAccess(String entitlementIdentifier) async {
    entitlementIdentifiers.add(entitlementIdentifier);
    if (loadError case final error?) throw error;
    return access;
  }

  @override
  Future<PlusAccess> purchasePackage(
    PlusPackage package,
    String entitlementIdentifier,
  ) async {
    entitlementIdentifiers.add(entitlementIdentifier);
    purchasedPackage = package;
    if (cancelPurchase) throw const PurchaseCancelledException();
    if (purchaseError case final error?) throw error;
    return purchaseAccess;
  }

  @override
  Future<PlusAccess> restore(String entitlementIdentifier) async {
    entitlementIdentifiers.add(entitlementIdentifier);
    return access;
  }
}
