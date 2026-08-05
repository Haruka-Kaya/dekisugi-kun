import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'device_identity.dart';

/// 会話を始めるための一時トークンをサーバから受け取る。
///
/// **APIキーは端末に無い。** 持つのは短命で使い切りのトークンだけで、
/// その期限が来るとセッションごと切られる
/// （実測: `code=1011 auth token has expired`、発行58秒後）。
///
/// つまり**サーバが渡した分数を端末側では伸ばせない**。
/// これが「1日15分の無料枠」を成り立たせている。
class LiveTokenClient {
  LiveTokenClient({
    required this.baseUrl,
    required this.identity,
    Dio? dio,
  }) : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              headers: {'Content-Type': 'application/json'},
              validateStatus: (_) => true,
            ));

  final String baseUrl;
  final DeviceIdentity identity;
  final Dio _dio;

  bool get isConfigured => baseUrl.isNotEmpty;

  /// 会話時間を確保してトークンを受け取る。
  ///
  /// 枠を使い切っていたら [QuotaExhausted] を投げる。
  /// **これは失敗ではなく仕様**なので、画面はエラーではなく案内を出す。
  Future<LiveGrant> reserve() async {
    if (!isConfigured) throw const LiveTokenUnavailable('接続先が設定されていません');

    final res = await _send(
      (h) => _dio.post<Object?>('$baseUrl/api/live-token', options: Options(headers: h)),
    );
    final data = (res.data as Map?)?.cast<String, dynamic>();

    if (res.statusCode == 402) {
      throw QuotaExhausted(
        resetsAt: DateTime.tryParse(data?['resetsAt'] as String? ?? ''),
      );
    }
    if (res.statusCode != 200 || data == null) {
      throw LiveTokenUnavailable('トークンを受け取れませんでした（HTTP ${res.statusCode}）');
    }

    final token = data['token'] as String?;
    final model = data['model'] as String?;
    if (token == null || token.isEmpty || model == null || model.isEmpty) {
      throw const LiveTokenUnavailable('トークンの中身が足りません');
    }

    return LiveGrant(
      token: token,
      model: model,
      apiVersion: data['apiVersion'] as String? ?? 'v1alpha',
      expiresAt: DateTime.tryParse(data['expiresAt'] as String? ?? '') ??
          DateTime.now().add(const Duration(minutes: 5)),
      grantedMinutes: (data['grantedMinutes'] as num?)?.toInt() ?? 0,
      remainingMinutes: (data['remainingMinutes'] as num?)?.toInt(),
      entitled: data['entitled'] == true,
      resetsAt: DateTime.tryParse(data['resetsAt'] as String? ?? ''),
    );
  }

  /// 今日あと何分使えるか。**枠を引かない。**
  ///
  /// 見るだけなので、失敗しても null を返して画面は黙って先へ進める。
  Future<QuotaStatus?> peek() async {
    if (!isConfigured) return null;
    try {
      final res = await _send(
        (h) => _dio.get<Object?>('$baseUrl/api/live-token', options: Options(headers: h)),
      );
      final data = (res.data as Map?)?.cast<String, dynamic>();
      if (res.statusCode != 200 || data == null) return null;
      return QuotaStatus(
        remainingMinutes: (data['remainingMinutes'] as num?)?.toInt(),
        entitled: data['entitled'] == true,
        resetsAt: DateTime.tryParse(data['resetsAt'] as String? ?? ''),
      );
    } catch (e) {
      debugPrint('残り時間の取得に失敗: $e');
      return null;
    }
  }

  /// 401 のときだけ1回、端末トークンを取り直して再送する。
  Future<Response<Object?>> _send(
    Future<Response<Object?>> Function(Map<String, String>?) call,
  ) async {
    var token = await identity.token();
    var res = await call(_headers(token));
    if (res.statusCode == 401) {
      token = await identity.token(force: true);
      if (token != null) res = await call(_headers(token));
    }
    return res;
  }

  Map<String, String>? _headers(String? token) =>
      token == null ? null : {'Authorization': 'Bearer $token'};
}

/// サーバが確保してくれた会話1ブロック。
class LiveGrant {
  const LiveGrant({
    required this.token,
    required this.model,
    required this.apiVersion,
    required this.expiresAt,
    required this.grantedMinutes,
    required this.remainingMinutes,
    required this.entitled,
    required this.resetsAt,
  });

  /// Gemini Live に繋ぐための一時トークン
  final String token;

  /// 繋ぐモデル。**サーバが決める**（端末では選べない）
  final String model;

  /// 一時トークンは v1alpha でしか通らない
  final String apiVersion;

  /// この時刻を過ぎるとセッションごと切られる
  final DateTime expiresAt;

  final int grantedMinutes;

  /// 今日の残り。課金済みなら null
  final int? remainingMinutes;
  final bool entitled;
  final DateTime? resetsAt;

  Duration remaining(DateTime now) {
    final d = expiresAt.difference(now);
    return d.isNegative ? Duration.zero : d;
  }
}

class QuotaStatus {
  const QuotaStatus({
    required this.remainingMinutes,
    required this.entitled,
    required this.resetsAt,
  });

  /// 課金済みなら null（上限が無い）
  final int? remainingMinutes;
  final bool entitled;
  final DateTime? resetsAt;

  bool get isExhausted => !entitled && (remainingMinutes ?? 1) <= 0;
}

/// 今日の無料枠を使い切った。**エラーではなく仕様。**
class QuotaExhausted implements Exception {
  const QuotaExhausted({this.resetsAt});
  final DateTime? resetsAt;

  @override
  String toString() => 'QuotaExhausted(resetsAt: $resetsAt)';
}

/// トークンが取れなかった。こちらは本当の失敗。
class LiveTokenUnavailable implements Exception {
  const LiveTokenUnavailable(this.messageJa);
  final String messageJa;

  @override
  String toString() => 'LiveTokenUnavailable: $messageJa';
}
