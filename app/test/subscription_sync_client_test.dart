import 'package:dekisugi/services/device_identity.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:dekisugi/services/subscription_sync_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/stub_dio.dart';

const baseUrl = 'https://example.test';

void main() {
  test('署名付きdevice tokenだけで同期し、有効期限を型付きで返す', () async {
    RequestOptions? request;
    final identity = _Identity(tokens: const ['signed-device-token']);
    final client = SubscriptionSyncClient(
      baseUrl: baseUrl,
      identity: identity,
      dio: fakeDio({
        'POST $baseUrl/api/subscription-sync': () =>
            json200('{"entitled":true,"expiresAt":"2026-09-01T00:00:00.000Z"}'),
      }, onRequest: (options) => request = options),
    );

    final access = await client.sync();

    expect(access.entitled, isTrue);
    expect(access.expiresAt, DateTime.utc(2026, 9));
    expect(request?.headers['Authorization'], 'Bearer signed-device-token');
    expect(request?.data, isNull, reason: '端末のentitlement自己申告を本文へ含めない');
    expect(identity.forces, [false]);
  });

  test('無効な権利はexpiresAtなしで返す', () async {
    final client = _client(
      identity: _Identity(tokens: const ['token']),
      response: '{"entitled":false,"expiresAt":null}',
    );

    final access = await client.sync();

    expect(access.entitled, isFalse);
    expect(access.expiresAt, isNull);
  });

  test('401ならdevice tokenを一度だけ再登録して再送する', () async {
    var calls = 0;
    final headers = <String?>[];
    final identity = _Identity(tokens: const ['old-token', 'new-token']);
    final client = SubscriptionSyncClient(
      baseUrl: baseUrl,
      identity: identity,
      dio: fakeDio(
        {
          'POST $baseUrl/api/subscription-sync': () {
            calls += 1;
            return calls == 1
                ? jsonRes(401, '{"error":"token_expired"}')
                : json200('{"entitled":false,"expiresAt":null}');
          },
        },
        onRequest: (options) {
          headers.add(options.headers['Authorization'] as String?);
        },
      ),
    );

    await client.sync();

    expect(identity.forces, [false, true]);
    expect(headers, ['Bearer old-token', 'Bearer new-token']);
    expect(calls, 2);
  });

  test('再登録後も401なら3回目は送らずunauthorizedにする', () async {
    var calls = 0;
    final identity = _Identity(tokens: const ['old-token', 'new-token']);
    final client = SubscriptionSyncClient(
      baseUrl: baseUrl,
      identity: identity,
      dio: fakeDio({
        'POST $baseUrl/api/subscription-sync': () {
          calls += 1;
          return jsonRes(401, '{"error":"unauthorized"}');
        },
      }),
    );

    await expectLater(
      client.sync(),
      throwsA(
        isA<SubscriptionSyncException>()
            .having(
              (error) => error.failure,
              'failure',
              SubscriptionSyncFailure.unauthorized,
            )
            .having((error) => error.statusCode, 'statusCode', 401),
      ),
    );
    expect(calls, 2);
    expect(identity.forces, [false, true]);
  });

  test('tokenを取得できなければ未署名リクエストを送らない', () async {
    var requests = 0;
    final client = SubscriptionSyncClient(
      baseUrl: baseUrl,
      identity: _Identity(tokens: const [null]),
      dio: fakeDio({}, onRequest: (_) => requests += 1),
    );

    await expectLater(
      client.sync(),
      throwsA(
        isA<SubscriptionSyncException>().having(
          (error) => error.failure,
          'failure',
          SubscriptionSyncFailure.authenticationUnavailable,
        ),
      ),
    );
    expect(requests, 0);
  });

  test('entitledとexpiresAtの型・組み合わせが崩れた応答を拒否する', () async {
    for (final response in <String>[
      '{"entitled":"true","expiresAt":"2026-09-01T00:00:00.000Z"}',
      '{"entitled":true,"expiresAt":"not-a-date"}',
      '{"entitled":true,"expiresAt":null}',
      '{"entitled":false,"expiresAt":"2026-09-01T00:00:00.000Z"}',
    ]) {
      final client = _client(
        identity: _Identity(tokens: const ['token']),
        response: response,
      );

      await expectLater(
        client.sync(),
        throwsA(
          isA<SubscriptionSyncException>().having(
            (error) => error.failure,
            'failure',
            SubscriptionSyncFailure.invalidResponse,
          ),
        ),
        reason: response,
      );
    }
  });

  test('未設定ならidentityも通信も使わない', () async {
    var requests = 0;
    final identity = _Identity(tokens: const ['token']);
    final client = SubscriptionSyncClient(
      baseUrl: '',
      identity: identity,
      dio: fakeDio({}, onRequest: (_) => requests += 1),
    );

    await expectLater(
      client.sync(),
      throwsA(
        isA<SubscriptionSyncException>().having(
          (error) => error.failure,
          'failure',
          SubscriptionSyncFailure.notConfigured,
        ),
      ),
    );
    expect(identity.forces, isEmpty);
    expect(requests, 0);
  });

  test('サーバ失敗をentitlement無効へ読み替えない', () async {
    final identity = _Identity(tokens: const ['token']);
    final client = SubscriptionSyncClient(
      baseUrl: baseUrl,
      identity: identity,
      dio: fakeDio({
        'POST $baseUrl/api/subscription-sync': () =>
            jsonRes(502, '{"error":"revenuecat_sync_failed"}'),
      }),
    );

    await expectLater(
      client.sync(),
      throwsA(
        isA<SubscriptionSyncException>()
            .having(
              (error) => error.failure,
              'failure',
              SubscriptionSyncFailure.unavailable,
            )
            .having((error) => error.statusCode, 'statusCode', 502),
      ),
    );
  });
}

SubscriptionSyncClient _client({
  required _Identity identity,
  required String response,
}) => SubscriptionSyncClient(
  baseUrl: baseUrl,
  identity: identity,
  dio: fakeDio({
    'POST $baseUrl/api/subscription-sync': () => json200(response),
  }),
);

class _Identity extends DeviceIdentity {
  _Identity({required this.tokens})
    : super(baseUrl: '', store: MemorySessionStore());

  final List<String?> tokens;
  final List<bool> forces = [];

  @override
  Future<String?> token({bool force = false}) async {
    forces.add(force);
    final index = forces.length - 1;
    return tokens[index < tokens.length ? index : tokens.length - 1];
  }
}
