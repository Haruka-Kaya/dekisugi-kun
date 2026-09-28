import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';
import '../learning/services/local_companion_voice.dart';
import 'device_identity.dart';

/// 環境既定の生成経路を解決する。
///
/// 外部AIはビルド時フラグ `DEKISUGI_COMPANION_REMOTE=1` と
/// `SERVER_URL` の両方がある時だけ有効。どちらか欠ければ
/// エンジン無しの CompanionVoice を返し、画面はカタログの
/// 固定文のまま動く。
CompanionVoice companionVoiceFromEnvironment({DeviceIdentity? identity}) {
  const enabled = bool.fromEnvironment('DEKISUGI_COMPANION_REMOTE');
  if (!enabled || !Env.hasServer) return CompanionVoice();
  return CompanionVoice(
    engine: RemoteCompanionEngine(baseUrl: Env.directorUrl, identity: identity),
  );
}

/// サーバ経由の生成AIエンジン（外部AI）。
///
/// 鍵はサーバ側（COMPANION_AI_API_KEY）にだけ置く。端末が送るのは
/// 「生徒が書いた説明・聞き取れた言葉・単元名」の3点だけ —
/// lure・正解・選択肢は送らない。プロンプトはサーバが組み立てる。
///
/// 失敗・タイムアウト・利用不可は全て null を返し、
/// 呼び出し側（CompanionVoice）がカタログの固定文へ退避する。
class RemoteCompanionEngine implements CompanionVoiceEngine {
  RemoteCompanionEngine({required this.baseUrl, this.identity, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 12),
              headers: {'Content-Type': 'application/json'},
              validateStatus: (_) => true,
            ),
          );

  final String baseUrl;

  /// 端末の身元（レート制限のため）。null なら認証なしで叩く。
  final DeviceIdentity? identity;

  final Dio _dio;

  bool get isConfigured => baseUrl.isNotEmpty;

  /// 構造化入力で生成する。失敗は必ず null。
  @override
  Future<String?> generateAck({
    required String explanation,
    required List<String> heardTerms,
    required String conceptLabel,
  }) async {
    if (!isConfigured) return null;
    try {
      final res = await _post(explanation, heardTerms, conceptLabel);
      if (res?.statusCode == 401 && identity != null) {
        // 期限切れ — 取り直して一度だけ再試行
        await identity!.token(force: true);
        final retry = await _post(explanation, heardTerms, conceptLabel);
        return _ackFrom(retry);
      }
      return _ackFrom(res);
    } catch (e) {
      debugPrint('companion-line failed: $e');
      return null;
    }
  }

  Future<Response<Map<String, Object?>>?> _post(
    String explanation,
    List<String> heardTerms,
    String conceptLabel,
  ) async {
    final token = await identity?.token();
    try {
      return await _dio.post<Map<String, Object?>>(
        '$baseUrl/api/companion-line',
        data: {
          'explanation': explanation,
          'heardTerms': heardTerms,
          'conceptLabel': conceptLabel,
        },
        options: token == null
            ? null
            : Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } catch (_) {
      return null;
    }
  }

  String? _ackFrom(Response<Map<String, Object?>>? res) {
    if (res == null || res.statusCode != 200) return null;
    final ack = res.data?['ack'];
    return ack is String && ack.isNotEmpty ? ack : null;
  }
}
