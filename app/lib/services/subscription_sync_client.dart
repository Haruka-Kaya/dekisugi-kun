import 'package:dio/dio.dart';

import 'device_identity.dart';

/// RevenueCat の現在値をサーバへ照会し、会話枠へ反映した結果。
///
/// 端末の SDK が返した entitlement はここへ渡さない。正とするのは、署名付き
/// device token の DID を使ってサーバが RevenueCat REST API から読んだ値だけ。
class SyncedSubscriptionAccess {
  const SyncedSubscriptionAccess({
    required this.entitled,
    required this.expiresAt,
  });

  final bool entitled;
  final DateTime? expiresAt;
}

enum SubscriptionSyncFailure {
  notConfigured,
  authenticationUnavailable,
  unauthorized,
  unavailable,
  invalidResponse,
}

class SubscriptionSyncException implements Exception {
  const SubscriptionSyncException(this.failure, {this.statusCode});

  final SubscriptionSyncFailure failure;
  final int? statusCode;

  @override
  String toString() =>
      'SubscriptionSyncException($failure, statusCode: $statusCode)';
}

/// 購入・復元直後に、RevenueCat webhook を待たずサーバの会話枠を同期する。
class SubscriptionSyncClient {
  SubscriptionSyncClient({
    required this.baseUrl,
    required this.identity,
    Dio? dio,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 20),
               headers: {'Content-Type': 'application/json'},
               validateStatus: (_) => true,
             ),
           );

  final String baseUrl;
  final DeviceIdentity identity;
  final Dio _dio;

  bool get isConfigured => baseUrl.isNotEmpty;

  /// サーバが RevenueCat から確認した現在値を quota へ反映する。
  ///
  /// リクエスト本文は送らない。端末が `entitled: true` と自己申告できる経路を
  /// 作らず、署名付き device token だけで対象インストールを特定する。
  Future<SyncedSubscriptionAccess> sync() async {
    if (!isConfigured) {
      throw const SubscriptionSyncException(
        SubscriptionSyncFailure.notConfigured,
      );
    }

    final response = await _send();
    if (response.statusCode != 200) {
      throw SubscriptionSyncException(
        response.statusCode == 401
            ? SubscriptionSyncFailure.unauthorized
            : SubscriptionSyncFailure.unavailable,
        statusCode: response.statusCode,
      );
    }

    final data = response.data;
    if (data is! Map) {
      throw const SubscriptionSyncException(
        SubscriptionSyncFailure.invalidResponse,
      );
    }
    final map = data.cast<Object?, Object?>();
    final entitled = map['entitled'];
    final expiresAtValue = map['expiresAt'];
    if (entitled is! bool ||
        (expiresAtValue != null && expiresAtValue is! String)) {
      throw const SubscriptionSyncException(
        SubscriptionSyncFailure.invalidResponse,
      );
    }

    final expiresAt = expiresAtValue == null
        ? null
        : DateTime.tryParse(expiresAtValue as String);
    // サーバの現在の契約では、有効なら期限を、無効なら null を返す。
    // 形の崩れた応答を「有効」と解釈しない。
    if ((expiresAtValue != null && expiresAt == null) ||
        entitled != (expiresAt != null)) {
      throw const SubscriptionSyncException(
        SubscriptionSyncFailure.invalidResponse,
      );
    }

    return SyncedSubscriptionAccess(entitled: entitled, expiresAt: expiresAt);
  }

  /// 401 のときだけ一度トークンを再登録し、同じ同期を再送する。
  Future<Response<Object?>> _send() async {
    var token = await identity.token();
    if (token == null) {
      throw const SubscriptionSyncException(
        SubscriptionSyncFailure.authenticationUnavailable,
      );
    }

    var response = await _post(token);
    if (response.statusCode == 401) {
      token = await identity.token(force: true);
      if (token == null) {
        throw const SubscriptionSyncException(
          SubscriptionSyncFailure.authenticationUnavailable,
        );
      }
      response = await _post(token);
    }
    return response;
  }

  Future<Response<Object?>> _post(String token) => _dio.post<Object?>(
    '$baseUrl/api/subscription-sync',
    options: Options(headers: {'Authorization': 'Bearer $token'}),
  );
}
