import 'dart:typed_data';

import 'package:dio/dio.dart';

/// 応答を固定した Dio。ネットワークを使わない。
///
/// キーは `'<METHOD> <path>'`。クエリは見ない（同じ経路で
/// 一覧と1件を出し分けている API があるため、必要なら本文で分ける）。
Dio fakeDio(Map<String, Response<Object?> Function()> routes) {
  final dio = Dio(BaseOptions(validateStatus: (_) => true));
  dio.httpClientAdapter = _StubAdapter(routes);
  return dio;
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.routes);
  final Map<String, Response<Object?> Function()> routes;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final key = '${options.method} ${options.path}';
    final make = routes[key];
    if (make == null) return ResponseBody.fromString('{}', 404);
    final res = make();
    return ResponseBody.fromString(
      res.data is String ? res.data! as String : '',
      res.statusCode ?? 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

Response<Object?> jsonRes(int code, String body) => Response<Object?>(
    requestOptions: RequestOptions(), statusCode: code, data: body);

Response<Object?> json200(String body) => jsonRes(200, body);
