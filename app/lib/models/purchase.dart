import 'package:flutter/foundation.dart';

/// Plus entitlement の現在値。
///
/// RevenueCat 固有型を UI に漏らさないための、アプリ内の読み取り専用モデル。
@immutable
class PlusAccess {
  const PlusAccess({
    required this.isActive,
    this.willRenew = false,
    this.expiresAt,
    this.productIdentifier,
    this.managementUrl,
    this.isTrial = false,
    this.isSandbox = false,
  });

  const PlusAccess.inactive()
    : isActive = false,
      willRenew = false,
      expiresAt = null,
      productIdentifier = null,
      managementUrl = null,
      isTrial = false,
      isSandbox = false;

  final bool isActive;
  final bool willRenew;
  final DateTime? expiresAt;
  final String? productIdentifier;

  /// RevenueCat が現在のストア契約に対して返した購読管理URL。
  ///
  /// URL の組み立てを UI 側で推測せず、ストアをまたぐ契約でも正しい管理先へ
  /// 案内するために保持する。非購読・契約なしでは null。
  final String? managementUrl;
  final bool isTrial;
  final bool isSandbox;
}

/// ストア商品がどのように請求されるか。
///
/// 課金画面はこの値と実期間を確認できた場合にだけ購入を許可する。
enum PlusBillingModel {
  autoRenewingSubscription,
  prepaidSubscription,
  oneTimePurchase,
  unsupported,
}

/// RevenueCat Offering に含まれる購入候補。
@immutable
class PlusPackage {
  const PlusPackage({
    required this.id,
    required this.offeringIdentifier,
    required this.packageIdentifier,
    required this.productIdentifier,
    required this.title,
    required this.description,
    required this.price,
    required this.packageType,
    required this.billingModel,
    this.subscriptionPeriod,
    this.hasIntroductoryOffer = false,
    this.hasInstallments = false,
  });

  /// Offering と package の組を表す、プロセス内で一意なID。
  final String id;
  final String offeringIdentifier;
  final String packageIdentifier;
  final String productIdentifier;
  final String title;
  final String description;
  final String price;
  final String packageType;
  final PlusBillingModel billingModel;

  /// ストアが返した ISO 8601 の請求期間。例: P1M / P1Y。
  final String? subscriptionPeriod;

  /// 現画面がまだ正確な全フェーズ表示に対応していない条件。
  ///
  /// これらが true の商品は、通常価格だけを見せて購入させず fail-closed にする。
  final bool hasIntroductoryOffer;
  final bool hasInstallments;
}

/// RevenueCat Dashboard で Current にした Offering。
@immutable
class PlusOffering {
  const PlusOffering({required this.identifier, required this.packages});

  final String identifier;
  final List<PlusPackage> packages;
}

enum PurchaseAvailability {
  /// SDK key が無い、または対象外プラットフォーム。SDK は呼ばない。
  disabled,

  /// SDK から entitlement と offering を取得できた。
  ready,

  /// 設定はあるが、一時的にストアへ到達できなかった。
  unavailable,
}

/// Paywall を描画するのに必要な現在値。
@immutable
class PurchaseOverview {
  const PurchaseOverview({
    required this.availability,
    required this.plus,
    this.currentOffering,
    this.failureCode,
  });

  const PurchaseOverview.disabled()
    : availability = PurchaseAvailability.disabled,
      plus = const PlusAccess.inactive(),
      currentOffering = null,
      failureCode = null;

  const PurchaseOverview.unavailable(
    String code, {
    this.plus = const PlusAccess.inactive(),
  }) : availability = PurchaseAvailability.unavailable,
       currentOffering = null,
       failureCode = code;

  final PurchaseAvailability availability;
  final PlusAccess plus;
  final PlusOffering? currentOffering;

  /// 画面の分岐・診断用の安定した短いコード。SDK の生メッセージは含めない。
  final String? failureCode;
}

enum PurchaseActionOutcome { completed, cancelled, failed, disabled }

/// 購入・復元後の entitlement と操作結果。
@immutable
class PurchaseActionResult {
  const PurchaseActionResult({
    required this.outcome,
    required this.plus,
    this.failureCode,
  });

  const PurchaseActionResult.disabled()
    : outcome = PurchaseActionOutcome.disabled,
      plus = null,
      failureCode = null;

  final PurchaseActionOutcome outcome;

  /// 完了時の新しい状態。cancelled/failed/disabled は既存状態を変えないため null。
  final PlusAccess? plus;
  final String? failureCode;
}
