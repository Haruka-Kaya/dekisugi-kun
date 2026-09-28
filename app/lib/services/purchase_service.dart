import '../models/purchase.dart';
import 'device_identity.dart';
import 'purchase_config.dart';

/// RevenueCat SDK との境界。テストでは fake を渡し、MethodChannel を呼ばない。
abstract interface class PurchaseAdapter {
  Future<void> configure({
    required String publicSdkKey,
    required String anonymousAppUserId,
  });

  Future<PlusAccess> plusAccess(String entitlementIdentifier);

  Future<PlusOffering?> currentOffering();

  Future<PlusAccess> purchasePackage(
    PlusPackage package,
    String entitlementIdentifier,
  );

  Future<PlusAccess> restore(String entitlementIdentifier);
}

/// 購入画面とアプリ本体が依存する最小インターフェース。
abstract interface class PurchaseService {
  bool get enabled;

  Future<PurchaseOverview> load();

  Future<PurchaseActionResult> purchase(PlusPackage package);

  Future<PurchaseActionResult> restore();
}

class PurchaseCancelledException implements Exception {
  const PurchaseCancelledException();
}

class PurchaseSdkException implements Exception {
  const PurchaseSdkException(this.code);

  final String code;
}

/// 匿名ID・設定選択・SDK呼び出しを束ねる実装。
///
/// key 未設定なら完全に disabled で、DeviceIdentity も SDK も呼ばない。
/// configure の Future を保持するため、並行する load/purchase/restore からも
/// adapter の configure は1回しか呼ばれない。
class RevenueCatPurchaseService implements PurchaseService {
  RevenueCatPurchaseService({
    required RevenueCatPurchaseConfig config,
    required DeviceIdentity identity,
    required PurchaseAdapter adapter,
  }) : // 公開constructorのnamed parameter名を保つ。
       // ignore: prefer_initializing_formals
       _config = config,
       // ignore: prefer_initializing_formals
       _identity = identity,
       // ignore: prefer_initializing_formals
       _adapter = adapter;

  final RevenueCatPurchaseConfig _config;
  final DeviceIdentity _identity;
  final PurchaseAdapter _adapter;
  Future<void>? _configuration;

  @override
  bool get enabled => _config.enabled;

  Future<void> _ensureConfigured() => _configuration ??= _configure();

  Future<void> _configure() async {
    final key = _config.publicSdkKey;
    if (key == null) throw const PurchaseSdkException('disabled');
    final anonymousId = await _identity.anonymousAppUserId;
    await _adapter.configure(
      publicSdkKey: key,
      anonymousAppUserId: anonymousId,
    );
  }

  @override
  Future<PurchaseOverview> load() async {
    if (!enabled) return const PurchaseOverview.disabled();
    try {
      await _ensureConfigured();
    } catch (error) {
      return PurchaseOverview.unavailable(_failureCode(error));
    }

    final PlusAccess plus;
    try {
      plus = await _adapter.plusAccess(_config.plusEntitlementIdentifier);
    } catch (error) {
      return PurchaseOverview.unavailable(_failureCode(error));
    }

    try {
      final offering = await _adapter.currentOffering();
      return PurchaseOverview(
        availability: PurchaseAvailability.ready,
        plus: plus,
        currentOffering: offering,
      );
    } catch (error) {
      // Offering が読めなくても、取得済み entitlement を失効扱いにしない。
      return PurchaseOverview.unavailable(_failureCode(error), plus: plus);
    }
  }

  @override
  Future<PurchaseActionResult> purchase(PlusPackage package) async {
    if (!enabled) return const PurchaseActionResult.disabled();
    try {
      await _ensureConfigured();
      final plus = await _adapter.purchasePackage(
        package,
        _config.plusEntitlementIdentifier,
      );
      return PurchaseActionResult(
        outcome: PurchaseActionOutcome.completed,
        plus: plus,
      );
    } on PurchaseCancelledException {
      return const PurchaseActionResult(
        outcome: PurchaseActionOutcome.cancelled,
        plus: null,
      );
    } catch (error) {
      return PurchaseActionResult(
        outcome: PurchaseActionOutcome.failed,
        plus: null,
        failureCode: _failureCode(error),
      );
    }
  }

  @override
  Future<PurchaseActionResult> restore() async {
    if (!enabled) return const PurchaseActionResult.disabled();
    try {
      await _ensureConfigured();
      final plus = await _adapter.restore(_config.plusEntitlementIdentifier);
      return PurchaseActionResult(
        outcome: PurchaseActionOutcome.completed,
        plus: plus,
      );
    } catch (error) {
      return PurchaseActionResult(
        outcome: PurchaseActionOutcome.failed,
        plus: null,
        failureCode: _failureCode(error),
      );
    }
  }

  static String _failureCode(Object error) => switch (error) {
    PurchaseSdkException(:final code) => code,
    _ => 'purchase_unavailable',
  };
}
