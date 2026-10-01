import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOSはLocal Network用途を示しATSの広い例外を追加しない', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<key>NSLocalNetworkUsageDescription</key>'));
    expect(plist, contains('共同観察や共同観測に参加'));
    expect(plist, contains('氏名・回答・音声は送りません'));
    expect(plist, isNot(contains('ペアクエスト')));
    expect(plist, isNot(contains('週次リーグ')));
    expect(plist, isNot(contains('NSAllowsArbitraryLoads')));
    expect(plist, isNot(contains('NSExceptionAllowsInsecureHTTPLoads')));
    expect(plist, isNot(contains('NSBonjourServices')));
  });

  test('AndroidはINTERNETを持ちcleartextと広いtrust設定を拒否する', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, contains('android:usesCleartextTraffic="false"'));
    expect(manifest, isNot(contains('android:usesCleartextTraffic="true"')));
    expect(manifest, isNot(contains('android:networkSecurityConfig')));
  });
}
