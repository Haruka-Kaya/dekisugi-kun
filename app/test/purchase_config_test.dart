import 'package:dekisugi/services/purchase_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RevenueCatPurchaseConfig', () {
    test('key未設定ならdisabled', () {
      final config = RevenueCatPurchaseConfig.fromValues(
        platform: TargetPlatform.android,
        releaseMode: false,
        web: false,
      );

      expect(config.enabled, isFalse);
      expect(config.issue, RevenueCatConfigIssue.missingKey);
      expect(config.publicSdkKey, isNull);
    });

    test('iOSとAndroidで別のpublic keyを選ぶ', () {
      final ios = RevenueCatPurchaseConfig.fromValues(
        platform: TargetPlatform.iOS,
        releaseMode: true,
        web: false,
        iosPublicSdkKey: 'appl_ios-public',
        androidPublicSdkKey: 'goog_android-public',
      );
      final android = RevenueCatPurchaseConfig.fromValues(
        platform: TargetPlatform.android,
        releaseMode: true,
        web: false,
        iosPublicSdkKey: 'appl_ios-public',
        androidPublicSdkKey: 'goog_android-public',
      );

      expect(ios.publicSdkKey, 'appl_ios-public');
      expect(ios.keySource, RevenueCatKeySource.ios);
      expect(android.publicSdkKey, 'goog_android-public');
      expect(android.keySource, RevenueCatKeySource.android);
    });

    test('開発buildは明示したTest Store keyを使える', () {
      final config = RevenueCatPurchaseConfig.fromValues(
        platform: TargetPlatform.android,
        releaseMode: false,
        web: false,
        androidPublicSdkKey: 'goog_production',
        testStorePublicSdkKey: 'test_shipaton',
        useTestStore: true,
      );

      expect(config.enabled, isTrue);
      expect(config.publicSdkKey, 'test_shipaton');
      expect(config.usesTestStore, isTrue);
    });

    test('Test Store指定なのにkeyが無ければproductionへ流さない', () {
      final config = RevenueCatPurchaseConfig.fromValues(
        platform: TargetPlatform.android,
        releaseMode: false,
        web: false,
        androidPublicSdkKey: 'goog_production',
        useTestStore: true,
      );

      expect(config.enabled, isFalse);
      expect(config.issue, RevenueCatConfigIssue.missingKey);
    });

    test('release buildはTest Store keyを絶対に選ばない', () {
      final config = RevenueCatPurchaseConfig.fromValues(
        platform: TargetPlatform.iOS,
        releaseMode: true,
        web: false,
        iosPublicSdkKey: 'appl_production',
        testStorePublicSdkKey: 'test_shipaton',
        useTestStore: true,
      );

      expect(config.publicSdkKey, 'appl_production');
      expect(config.keySource, RevenueCatKeySource.ios);
      expect(config.usesTestStore, isFalse);
    });

    test('platform違い・secretらしきkeyをpublic keyとして受け付けない', () {
      for (final key in ['appl_wrong-platform', 'sk_secret']) {
        final config = RevenueCatPurchaseConfig.fromValues(
          platform: TargetPlatform.android,
          releaseMode: true,
          web: false,
          androidPublicSdkKey: key,
        );

        expect(config.enabled, isFalse, reason: key);
        expect(
          config.issue,
          RevenueCatConfigIssue.invalidPublicKey,
          reason: key,
        );
      }
    });

    test('mobile以外ではkeyがあってもdisabled', () {
      final config = RevenueCatPurchaseConfig.fromValues(
        platform: TargetPlatform.macOS,
        releaseMode: false,
        web: false,
        iosPublicSdkKey: 'appl_public',
      );

      expect(config.enabled, isFalse);
      expect(config.issue, RevenueCatConfigIssue.unsupportedPlatform);
    });

    test('entitlement名の空文字はplusへ戻す', () {
      final config = RevenueCatPurchaseConfig.fromValues(
        platform: TargetPlatform.android,
        releaseMode: false,
        web: false,
        androidPublicSdkKey: 'goog_public',
        plusEntitlementIdentifier: '  ',
      );

      expect(config.plusEntitlementIdentifier, 'plus');
    });
  });
}
