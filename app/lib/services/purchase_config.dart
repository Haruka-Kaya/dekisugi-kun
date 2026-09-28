import 'package:flutter/foundation.dart';

enum RevenueCatKeySource { ios, android, testStore, none }

enum RevenueCatConfigIssue {
  none,
  unsupportedPlatform,
  missingKey,
  invalidPublicKey,
}

/// `--dart-define` から RevenueCat の**公開** SDK key だけを選ぶ。
///
/// - `REVENUECAT_IOS_PUBLIC_SDK_KEY=appl_...`
/// - `REVENUECAT_ANDROID_PUBLIC_SDK_KEY=goog_...`
/// - 開発時のみ `REVENUECAT_USE_TEST_STORE=true`
///   `REVENUECAT_TEST_PUBLIC_SDK_KEY=test_...`
/// - entitlement 名を変える場合のみ
///   `REVENUECAT_PLUS_ENTITLEMENT_ID=plus`
///
/// Test Store key は release build では無視する。RevenueCat の secret key は
/// クライアントに渡してはならない。
@immutable
class RevenueCatPurchaseConfig {
  const RevenueCatPurchaseConfig._({
    required this.publicSdkKey,
    required this.keySource,
    required this.issue,
    required this.plusEntitlementIdentifier,
  });

  factory RevenueCatPurchaseConfig.fromEnvironment({
    TargetPlatform? platform,
    bool? releaseMode,
    bool? web,
  }) {
    const iosKey = String.fromEnvironment('REVENUECAT_IOS_PUBLIC_SDK_KEY');
    const androidKey = String.fromEnvironment(
      'REVENUECAT_ANDROID_PUBLIC_SDK_KEY',
    );
    const testKey = String.fromEnvironment('REVENUECAT_TEST_PUBLIC_SDK_KEY');
    const useTestStore = bool.fromEnvironment('REVENUECAT_USE_TEST_STORE');
    const entitlement = String.fromEnvironment(
      'REVENUECAT_PLUS_ENTITLEMENT_ID',
      defaultValue: 'plus',
    );

    return RevenueCatPurchaseConfig.fromValues(
      platform: platform ?? defaultTargetPlatform,
      releaseMode: releaseMode ?? kReleaseMode,
      web: web ?? kIsWeb,
      iosPublicSdkKey: iosKey,
      androidPublicSdkKey: androidKey,
      testStorePublicSdkKey: testKey,
      useTestStore: useTestStore,
      plusEntitlementIdentifier: entitlement,
    );
  }

  /// 値の選択規則をプラグイン無しで検証するための factory。
  @visibleForTesting
  factory RevenueCatPurchaseConfig.fromValues({
    required TargetPlatform platform,
    required bool releaseMode,
    required bool web,
    String iosPublicSdkKey = '',
    String androidPublicSdkKey = '',
    String testStorePublicSdkKey = '',
    bool useTestStore = false,
    String plusEntitlementIdentifier = 'plus',
  }) {
    final entitlement = plusEntitlementIdentifier.trim().isEmpty
        ? 'plus'
        : plusEntitlementIdentifier.trim();

    if (web ||
        (platform != TargetPlatform.iOS &&
            platform != TargetPlatform.android)) {
      return RevenueCatPurchaseConfig._(
        publicSdkKey: null,
        keySource: RevenueCatKeySource.none,
        issue: RevenueCatConfigIssue.unsupportedPlatform,
        plusEntitlementIdentifier: entitlement,
      );
    }

    // Test Store を指定したのに key が無い場合、実ストアへ黙ってフォールバック
    // しない。release build ではこの分岐自体へ入らないため test_ key は出荷されない。
    if (!releaseMode && useTestStore) {
      return _withKey(
        testStorePublicSdkKey,
        RevenueCatKeySource.testStore,
        entitlement,
      );
    }

    return switch (platform) {
      TargetPlatform.iOS => _withKey(
        iosPublicSdkKey,
        RevenueCatKeySource.ios,
        entitlement,
      ),
      TargetPlatform.android => _withKey(
        androidPublicSdkKey,
        RevenueCatKeySource.android,
        entitlement,
      ),
      _ => throw StateError('unreachable platform'),
    };
  }

  static RevenueCatPurchaseConfig _withKey(
    String rawKey,
    RevenueCatKeySource source,
    String entitlement,
  ) {
    final key = rawKey.trim();
    if (key.isEmpty) {
      return RevenueCatPurchaseConfig._(
        publicSdkKey: null,
        keySource: RevenueCatKeySource.none,
        issue: RevenueCatConfigIssue.missingKey,
        plusEntitlementIdentifier: entitlement,
      );
    }

    final expectedPrefix = switch (source) {
      RevenueCatKeySource.ios => 'appl_',
      RevenueCatKeySource.android => 'goog_',
      RevenueCatKeySource.testStore => 'test_',
      RevenueCatKeySource.none => '',
    };
    if (!key.startsWith(expectedPrefix)) {
      return RevenueCatPurchaseConfig._(
        publicSdkKey: null,
        keySource: RevenueCatKeySource.none,
        issue: RevenueCatConfigIssue.invalidPublicKey,
        plusEntitlementIdentifier: entitlement,
      );
    }

    return RevenueCatPurchaseConfig._(
      publicSdkKey: key,
      keySource: source,
      issue: RevenueCatConfigIssue.none,
      plusEntitlementIdentifier: entitlement,
    );
  }

  final String? publicSdkKey;
  final RevenueCatKeySource keySource;
  final RevenueCatConfigIssue issue;
  final String plusEntitlementIdentifier;

  bool get enabled =>
      publicSdkKey != null && issue == RevenueCatConfigIssue.none;
  bool get usesTestStore => keySource == RevenueCatKeySource.testStore;
}
