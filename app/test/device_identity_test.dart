import 'package:dekisugi/services/device_identity.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('公開App User IDは保存された予測困難なUUID v4だけ', () async {
    final store = MemorySessionStore();
    final firstIdentity = DeviceIdentity(baseUrl: '', store: store);
    final first = await firstIdentity.anonymousAppUserId;
    final second = await DeviceIdentity(
      baseUrl: '',
      store: store,
    ).anonymousAppUserId;

    expect(
      first,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
    expect(second, first);
    expect(first.contains('@'), isFalse);
    expect(first.length, lessThanOrEqualTo(100));
  });

  test('identity reset後はApp User IDも作り直す', () async {
    final store = MemorySessionStore();
    final identity = DeviceIdentity(baseUrl: '', store: store);
    final before = await identity.anonymousAppUserId;

    await identity.reset();
    final after = await identity.anonymousAppUserId;

    expect(after, isNot(before));
  });
}
