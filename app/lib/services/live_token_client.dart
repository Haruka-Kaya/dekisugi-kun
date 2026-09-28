import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/mission.dart';
import 'device_identity.dart';

/// 会話を始めるための資格情報をサーバから受け取る。
///
/// **Vertex の鍵は端末に無い。** 持つのは期限つきのアクセストークンだけで、
/// それで始められる会話は **Vertex 自身が約10分で打ち切る**
/// （実測 `code=1000 The operation was cancelled.`）。
///
/// つまり1回もらう＝約10分ぶん。だから枠は**セッション数**で数える。
class LiveTokenClient {
  LiveTokenClient({required this.baseUrl, required this.identity, Dio? dio})
    : _dio =
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

  /// 会話を1回ぶん確保して資格情報を受け取る。
  ///
  /// [unitId] は**必ず渡す。** サーバはこれを見てシステム指示に単元を埋める。
  /// 渡さないと、デキすぎ君は何を教わるのか知らないまま喋りはじめる。
  ///
  /// 枠を使い切っていたら [QuotaExhausted] を投げる。
  /// **これは失敗ではなく仕様**なので、画面はエラーではなく案内を出す。
  ///
  /// [resumeHandle] を渡すと、**枠を消費せずに**同じ会話の続きを取り直す。
  /// Vertex は約10分でセッションを切るので、渡さないと10分ごとに
  /// 生徒の残り回数が1つずつ減っていく。
  /// ハンドルは `setupConfig` に焼き込むのがサーバの仕事で、端末は渡すだけ。
  Future<LiveGrant> reserve(
    String unitId, {
    String? resumeHandle,
    String? focusConceptKey,
    TeachingTactic tactic = TeachingTactic.reason,
    MissionKind missionKind = MissionKind.teach,
  }) async {
    if (!isConfigured) throw const LiveTokenUnavailable('接続先が設定されていません');

    final res = await _send(
      (h) => _dio.post<Object?>(
        '$baseUrl/api/live-token',
        data: {
          'unitId': unitId,
          // きょう扱う1概念。省略時だけ従来どおり単元全体を扱う。
          'focusConceptKey': ?focusConceptKey,
          // 初回・組み直し・後日の具体場面で、AIの最初の問いも変える。
          'missionKind': missionKind.wire,
          // 教材で本人が選んだ説明の足場。CASEはControllerがreasonへ固定する。
          'teachingTactic': tactic.wire,
          // null なら項目ごと落ちる
          'resumeHandle': ?resumeHandle,
        },
        options: Options(headers: h),
      ),
    );
    final data = (res.data as Map?)?.cast<String, dynamic>();

    if (res.statusCode == 402) {
      throw QuotaExhausted(
        resetsAt: DateTime.tryParse(data?['resetsAt'] as String? ?? ''),
      );
    }
    if (res.statusCode != 200 || data == null) {
      throw LiveTokenUnavailable('資格情報を受け取れませんでした（HTTP ${res.statusCode}）');
    }

    final token = data['token'] as String?;
    final wsUrl = data['wsUrl'] as String?;
    final model = data['model'] as String?;
    final setup = (data['setupConfig'] as Map?)?.cast<String, dynamic>();
    // **中身が足りないまま繋ぎにいかない。** 原因の分からない接続失敗になる
    if (token == null ||
        token.isEmpty ||
        wsUrl == null ||
        !wsUrl.startsWith('wss://') ||
        model == null ||
        model.isEmpty ||
        setup == null ||
        setup.isEmpty) {
      throw const LiveTokenUnavailable('資格情報の中身が足りません');
    }

    return LiveGrant(
      // 無ければ固定の合図に落とす（古いサーバ相手でも会話は成立させる）
      directorPrefix:
          (data['directorPrefix'] as String?)?.trim().isNotEmpty == true
          ? data['directorPrefix'] as String
          : '[DIRECTOR]',
      token: token,
      wsUrl: wsUrl,
      model: model,
      setupConfig: setup,
      expiresAt:
          DateTime.tryParse(data['expiresAt'] as String? ?? '') ??
          DateTime.now().add(const Duration(minutes: 30)),
      sessionMinutes: (data['sessionMinutes'] as num?)?.toInt() ?? 10,
      remainingSessions: (data['remainingSessions'] as num?)?.toInt(),
      entitled: data['entitled'] == true,
      resetsAt: DateTime.tryParse(data['resetsAt'] as String? ?? ''),
      // **無ければ false。** 再開に未対応の古いサーバ相手に
      // 繋ぎ直すと、会話を忘れた状態で途中から再開してしまう
      resumed: data['resumed'] == true,
    );
  }

  /// 今日あと何回始められるか。**枠を引かない。**
  ///
  /// 見るだけなので、失敗しても null を返して画面は黙って先へ進める。
  Future<QuotaStatus?> peek() async {
    if (!isConfigured) return null;
    try {
      final res = await _send(
        (h) => _dio.get<Object?>(
          '$baseUrl/api/live-token',
          options: Options(headers: h),
        ),
      );
      final data = (res.data as Map?)?.cast<String, dynamic>();
      if (res.statusCode != 200 || data == null) return null;
      return QuotaStatus(
        remainingSessions: (data['remainingSessions'] as num?)?.toInt(),
        minutesPerSession: (data['minutesPerSession'] as num?)?.toInt() ?? 10,
        entitled: data['entitled'] == true,
        resetsAt: DateTime.tryParse(data['resetsAt'] as String? ?? ''),
      );
    } catch (e) {
      debugPrint('残り回数の取得に失敗: $e');
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

/// サーバが確保してくれた会話1回ぶん。
class LiveGrant {
  const LiveGrant({
    required this.directorPrefix,
    required this.token,
    required this.wsUrl,
    required this.model,
    required this.setupConfig,
    required this.expiresAt,
    required this.sessionMinutes,
    required this.remainingSessions,
    required this.entitled,
    required this.resetsAt,
    this.resumed = false,
  });

  /// ディレクターの指示に付ける合図。**セッションごとに違う。**
  ///
  /// 固定の `[DIRECTOR]` だったとき、生徒がそのまま打てば指示を騙れた。
  /// 推測できない合図なら騙りは成立しない。
  final String directorPrefix;

  /// Vertex のアクセストークン
  final String token;

  /// 接続先。サーバが決める（端末では組み立てない）
  final String wsUrl;

  /// setup に入れるモデルのフルパス
  final String model;

  /// **そのまま送る会話設定。** 端末で組み立てない。
  /// ペルソナと `[DIRECTOR]` の約束はここに入っている
  final Map<String, dynamic> setupConfig;

  final DateTime expiresAt;

  /// 1セッションのおおよその上限（分）。**Vertex 側が切る**
  final int sessionMinutes;

  /// 今日の残り回数。課金済みなら null
  final int? remainingSessions;
  final bool entitled;
  final DateTime? resetsAt;

  /// 前の会話の続きとして繋ぎ直すものか。
  ///
  /// **サーバが再開を受け入れたときだけ true。** 窓の外で送ったハンドルや、
  /// 再開に未対応のサーバでは false になる。
  /// false のまま繋ぎ直すと、会話を忘れた状態で途中から再開してしまう
  final bool resumed;
}

class QuotaStatus {
  const QuotaStatus({
    required this.remainingSessions,
    required this.minutesPerSession,
    required this.entitled,
    required this.resetsAt,
  });

  /// 課金済みなら null（上限が無い）
  final int? remainingSessions;
  final int minutesPerSession;
  final bool entitled;
  final DateTime? resetsAt;

  bool get isExhausted => !entitled && (remainingSessions ?? 1) <= 0;
}

/// 今日の無料枠を使い切った。**エラーではなく仕様。**
class QuotaExhausted implements Exception {
  const QuotaExhausted({this.resetsAt});
  final DateTime? resetsAt;

  @override
  String toString() => 'QuotaExhausted(resetsAt: $resetsAt)';
}

/// 資格情報が取れなかった。こちらは本当の失敗。
class LiveTokenUnavailable implements Exception {
  const LiveTokenUnavailable(this.messageJa);
  final String messageJa;

  @override
  String toString() => 'LiveTokenUnavailable: $messageJa';
}
