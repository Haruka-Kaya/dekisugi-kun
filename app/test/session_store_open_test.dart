import 'package:dekisugi/services/session_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('Androidの永続DB open失敗をMemoryへ隠さず呼び出し元へ返す', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await expectLater(
      openSessionStore(
        openPersistentStore: () async =>
            throw StateError('injected database open failure'),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('iOS/macOSと同じ本番境界では成功した永続storeだけを返す', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final persistent = MemorySessionStore();

    final opened = await openSessionStore(
      openPersistentStore: () async => persistent,
    );

    expect(opened, same(persistent));
  });

  test('Windows開発プレビューは永続openerを呼ばずMemoryを使う', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    var persistentOpenCalled = false;

    final opened = await openSessionStore(
      openPersistentStore: () async {
        persistentOpenCalled = true;
        throw StateError('must not be called');
      },
    );

    expect(opened, isA<MemorySessionStore>());
    expect(persistentOpenCalled, isFalse);
  });
}
