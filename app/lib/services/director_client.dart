import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/dossier.dart';
import '../models/mission.dart';
import 'device_identity.dart';

/// ディレクター（サーバ側の進行役）を呼ぶ。
///
/// サーバは状態を持たないので、**カルテと逐語を毎回まるごと送る**。
/// 返ってきたカルテで端末側を置き換える。
///
/// 1回あたり実測 6秒前後かかる。**await して次の発話を止めないこと。**
class DirectorClient {
  DirectorClient({required this.baseUrl, this.identity, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              // ディレクターは Gemini を挟むので遅い。実測 6秒前後
              receiveTimeout: const Duration(seconds: 30),
              headers: {'Content-Type': 'application/json'},
              // ステータスで例外を投げさせない。リトライ判断を自分で持つため
              validateStatus: (_) => true,
            ),
          );

  final String baseUrl;

  /// 端末の身元。null なら認証なしで叩く（ローカル開発）
  final DeviceIdentity? identity;

  final Dio _dio;

  bool get isConfigured => baseUrl.isNotEmpty;

  /// カルテを更新し、次の指示を受け取る。
  ///
  /// 失敗しても会話は続く（指示が来ないだけ）。だから例外を投げずに null を返す。
  Future<DirectorResult?> run({
    required String unitId,
    String? focusConceptKey,
    TeachingTactic tactic = TeachingTactic.reason,
    MissionKind missionKind = MissionKind.teach,
    Dossier? dossier,
    required List<Utterance> utterances,
    required double secondsLeft,
    required int turnCount,
  }) async {
    if (!isConfigured) return null;

    final body = {
      'unitId': unitId,
      'focusConceptKey': ?focusConceptKey,
      'teachingTactic': tactic.wire,
      'missionKind': missionKind.wire,
      if (dossier != null) 'dossier': dossier.toJson(),
      'utterances': utterances.map((u) => u.toJson()).toList(),
      'secondsLeft': secondsLeft,
      'turnCount': turnCount,
    };

    try {
      final res = await _withRetry(
        (h) => _dio.post<Object?>(
          '$baseUrl/api/director',
          data: body,
          options: Options(headers: h),
        ),
      );
      final data = res.data;
      if (data is Map) {
        return DirectorResult.fromJson(data.cast<String, dynamic>());
      }
      debugPrint('ディレクターの応答が想定外: ${data.runtimeType}');
      return null;
    } catch (e) {
      // 会話は止めない。指示が来ないだけで、生徒は説明を続けられる
      debugPrint('ディレクター呼び出しに失敗: $e');
      return null;
    }
  }

  /// 単元の一覧。誤概念の文言は含まれない（端末から覗けると誘発が成立しない）。
  Future<List<({String id, String title, String brief})>> units() async {
    if (!isConfigured) return const [];
    try {
      // 単元カタログは門の外。トークンが無くても取れる
      final res = await _withRetry(
        (_) => _dio.get<Object?>('$baseUrl/api/units'),
      );
      final list = (res.data as Map?)?['units'];
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map(
            (u) => (
              id: u['id'] as String? ?? '',
              title: u['title'] as String? ?? '',
              brief: u['brief'] as String? ?? '',
            ),
          )
          .where((u) => u.id.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('単元一覧の取得に失敗: $e');
      return const [];
    }
  }

  /// 指数バックオフ。`Retry-After` があればそちらを優先する。
  /// 400 番台は再送しても同じなので、その場で諦める。
  ///
  /// **401 のときだけ1回、トークンを取り直して再送する。**
  /// 期限が切れただけで会話が止まると、生徒には何が起きたか分からない。
  Future<Response<Object?>> _withRetry(
    Future<Response<Object?>> Function(Map<String, String>? headers) call, {
    int max = 3,
  }) async {
    var delay = const Duration(milliseconds: 700);
    var reissued = false;
    var token = await identity?.token();

    for (var i = 0; ; i++) {
      final headers = token == null
          ? null
          : <String, String>{'Authorization': 'Bearer $token'};
      late final Response<Object?> res;
      try {
        res = await call(headers);
      } on DioException catch (_) {
        if (i < max - 1) {
          await Future<void>.delayed(delay);
          delay *= 2;
          continue;
        }
        rethrow;
      }

      final s = res.statusCode ?? 0;
      if (s == 200) return res;

      if (s == 401 && !reissued && identity != null) {
        reissued = true;
        token = await identity!.token(force: true);
        if (token != null) continue;
      }

      if ((s == 429 || s == 500 || s == 502 || s == 503) && i < max - 1) {
        final ra = int.tryParse(res.headers.value('retry-after') ?? '');
        // Retry-After が長すぎるときは諦める。会話中に何分も待てない
        if (ra != null && ra > 30) {
          throw DirectorException(s, _messageFor(s, res.data));
        }
        await Future<void>.delayed(ra != null ? Duration(seconds: ra) : delay);
        delay *= 2;
        continue;
      }
      throw DirectorException(s, _messageFor(s, res.data));
    }
  }

  static String _messageFor(int status, Object? data) {
    final detail = data is Map ? data['error'] : null;
    return switch (status) {
      400 => '送った内容が受け付けられませんでした（$detail）',
      401 => 'この端末が確認できませんでした',
      404 => 'その単元は見つかりませんでした',
      413 => '会話が長くなりすぎました',
      429 => 'きょうはたくさん話しました。少し時間をあけてください',
      502 => '進行役が応答しませんでした',
      _ => 'エラーが発生しました（HTTP $status）',
    };
  }
}

class DirectorException implements Exception {
  const DirectorException(this.status, this.messageJa);
  final int status;

  /// そのまま画面に出せる日本語
  final String messageJa;

  @override
  String toString() => 'DirectorException($status): $messageJa';
}
