import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;

import '../models/purchase.dart';
import 'purchase_service.dart';

/// `purchases_flutter` の型と MethodChannel をこの1ファイルに閉じ込める。
class RevenueCatPurchaseAdapter implements PurchaseAdapter {
  static Future<void>? _configureOnce;
  static String? _configurationFingerprint;

  final Map<String, rc.Package> _packages = {};

  @override
  Future<void> configure({
    required String publicSdkKey,
    required String anonymousAppUserId,
  }) {
    final fingerprint = '$publicSdkKey\u0000$anonymousAppUserId';
    final configured = _configureOnce;
    if (configured != null) {
      if (_configurationFingerprint != fingerprint) {
        throw const PurchaseSdkException('already_configured_for_other_user');
      }
      return configured;
    }

    final config = rc.PurchasesConfiguration(publicSdkKey)
      ..appUserID = anonymousAppUserId
      // 名前・メール・attributes は送らない。広告 attribution も使わないため、
      // SDK による広告系端末IDの自動収集も明示的に止める。
      ..automaticDeviceIdentifierCollectionEnabled = false
      ..diagnosticsEnabled = false;
    _configurationFingerprint = fingerprint;
    return _configureOnce = rc.Purchases.configure(config);
  }

  @override
  Future<PlusAccess> plusAccess(String entitlementIdentifier) async {
    try {
      final info = await rc.Purchases.getCustomerInfo();
      return _access(info, entitlementIdentifier);
    } on PlatformException catch (error) {
      throw _sdkException(error);
    }
  }

  @override
  Future<PlusOffering?> currentOffering() async {
    try {
      final offering = (await rc.Purchases.getOfferings()).current;
      if (offering == null) return null;
      _packages.clear();
      final packages = <PlusPackage>[];
      for (final package in offering.availablePackages) {
        final id = _packageId(offering.identifier, package.identifier);
        _packages[id] = package;
        final product = package.storeProduct;
        packages.add(
          PlusPackage(
            id: id,
            offeringIdentifier: offering.identifier,
            packageIdentifier: package.identifier,
            productIdentifier: product.identifier,
            title: product.title,
            description: product.description,
            price: product.priceString,
            packageType: package.packageType.name,
            billingModel: _billingModel(product),
            subscriptionPeriod: product.subscriptionPeriod,
            hasIntroductoryOffer:
                product.introductoryPrice != null ||
                product.defaultOption?.freePhase != null ||
                product.defaultOption?.introPhase != null,
            hasInstallments: product.defaultOption?.installmentsInfo != null,
          ),
        );
      }
      return PlusOffering(
        identifier: offering.identifier,
        packages: List.unmodifiable(packages),
      );
    } on PlatformException catch (error) {
      throw _sdkException(error);
    }
  }

  @override
  Future<PlusAccess> purchasePackage(
    PlusPackage package,
    String entitlementIdentifier,
  ) async {
    final sdkPackage = _packages[package.id];
    if (sdkPackage == null ||
        sdkPackage.identifier != package.packageIdentifier ||
        sdkPackage.presentedOfferingContext.offeringIdentifier !=
            package.offeringIdentifier) {
      throw const PurchaseSdkException('package_not_loaded');
    }
    try {
      final result = await rc.Purchases.purchase(
        rc.PurchaseParams.package(sdkPackage),
      );
      return _access(result.customerInfo, entitlementIdentifier);
    } on PlatformException catch (error) {
      final code = rc.PurchasesErrorHelper.getErrorCode(error);
      if (code == rc.PurchasesErrorCode.purchaseCancelledError) {
        throw const PurchaseCancelledException();
      }
      throw PurchaseSdkException(code.name);
    }
  }

  @override
  Future<PlusAccess> restore(String entitlementIdentifier) async {
    try {
      final info = await rc.Purchases.restorePurchases();
      return _access(info, entitlementIdentifier);
    } on PlatformException catch (error) {
      throw _sdkException(error);
    }
  }

  static String _packageId(String offering, String package) =>
      '$offering::$package';

  static PlusBillingModel _billingModel(rc.StoreProduct product) {
    if (product.productCategory == rc.ProductCategory.nonSubscription) {
      return PlusBillingModel.oneTimePurchase;
    }
    if (product.productCategory != rc.ProductCategory.subscription &&
        product.subscriptionPeriod == null) {
      return PlusBillingModel.unsupported;
    }
    if (product.defaultOption?.isPrepaid ?? false) {
      return PlusBillingModel.prepaidSubscription;
    }
    return PlusBillingModel.autoRenewingSubscription;
  }

  static PlusAccess _access(
    rc.CustomerInfo info,
    String entitlementIdentifier,
  ) {
    final entitlement = info.entitlements.all[entitlementIdentifier];
    if (entitlement == null) {
      return PlusAccess(isActive: false, managementUrl: info.managementURL);
    }
    return PlusAccess(
      isActive: entitlement.isActive,
      willRenew: entitlement.willRenew,
      expiresAt: entitlement.expirationDate == null
          ? null
          : DateTime.tryParse(entitlement.expirationDate!),
      productIdentifier: entitlement.productIdentifier,
      managementUrl: info.managementURL,
      isTrial: entitlement.periodType == rc.PeriodType.trial,
      isSandbox: entitlement.isSandbox,
    );
  }

  static PurchaseSdkException _sdkException(PlatformException error) =>
      PurchaseSdkException(rc.PurchasesErrorHelper.getErrorCode(error).name);
}
