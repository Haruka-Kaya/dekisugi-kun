import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/day_key.dart';
import '../models/team.dart';
import 'device_identity.dart';
import 'session_store.dart';

/// クラスの合計とのやりとり。
///
/// ## 送信キューを持たない
///
/// **直近14日ぶんを毎回まるごと送る。** サーバは同じ日を何度受けても
/// 総和が動かない（差分だけ足す）ので、これで十分足りる。
///
/// キューを持つと「送れたか」の状態を端末が管理することになり、
/// 取りこぼしと二重送信の両方を自前で防ぐ羽目になる。
/// **冪等な相手には、状態を持たないほうが壊れない。**
///
/// ## 失敗しても何も止めない
///
/// クラスの合計は会話の付随物であって、これが落ちても学習は続く。
/// 例外は外へ出さず、`null` を返して画面は黙って先へ進む。
class TeamClient {
  TeamClient({
    required this.baseUrl,
    required this.identity,
    required SessionStore store,
    Dio? dio,
  })  : _store = store,
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: {'Content-Type': 'application/json'},
              validateStatus: (_) => true,
            ));

  final String baseUrl;
  final DeviceIdentity identity;
  final SessionStore _store;
  final Dio _dio;

  bool get isConfigured => baseUrl.isNotEmpty;

  static const String _key = 'team.membership';

  /// さかのぼって送る日数。**サーバの受付上限に合わせる。**
  static const int backfillDays = 14;

  // ── 所属 ──────────────────────────────────────────────────

  /// 端末が覚えている所属。**通信しない。**
  Future<TeamMembership?> saved() async {
    final raw = await _store.getSetting(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return TeamMembership.fromJson(
          (jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  Future<void> _remember(TeamMembership? m) =>
      _store.setSetting(_key, m == null ? null : jsonEncode(m.toJson()));

  // ── 参加と退出 ────────────────────────────────────────────

  /// コードで入る。成功したら所属を控える。
  Future<({TeamMembership? team, JoinFailure? error})> join(String code) async {
    if (!isConfigured) return (team: null, error: JoinFailure.network);
    try {
      final res = await _send((h) => _dio.post<Object?>(
            '$baseUrl/api/team/join',
            data: {'inviteCode': code},
            options: Options(headers: h),
          ));
      final data = (res.data as Map?)?.cast<String, dynamic>();
      if (res.statusCode != 200 || data == null) {
        return (
          team: null,
          error: JoinFailure.fromError(data?['error'] as String?, res.statusCode),
        );
      }
      final team = TeamMembership(
        id: data['teamId'] as String? ?? '',
        name: data['teamName'] as String? ?? '',
      );
      if (team.id.isEmpty) return (team: null, error: JoinFailure.unknown);
      await _remember(team);
      return (team: team, error: null);
    } catch (e) {
      debugPrint('クラスに入れなかった: $e');
      return (team: null, error: JoinFailure.network);
    }
  }

  /// 抜ける。**端末側の控えは、サーバが失敗しても消す。**
  ///
  /// 消さないと「抜けたのに入っている」表示のまま何もできなくなる。
  /// サーバ側に残っていても、次に入り直すときに気づける。
  Future<bool> leave() async {
    final team = await saved();
    await _remember(null);
    if (team == null || !isConfigured) return false;
    try {
      final res = await _send((h) => _dio.post<Object?>(
            '$baseUrl/api/team/leave',
            data: {'teamId': team.id},
            options: Options(headers: h),
          ));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('クラスを抜けられなかった: $e');
      return false;
    }
  }

  // ── 合計 ──────────────────────────────────────────────────

  /// クラスの合計。取れなければ null（画面は出さないだけ）。
  Future<TeamSummary?> summary() async {
    if (!isConfigured || await saved() == null) return null;
    try {
      final res = await _send((h) => _dio.get<Object?>(
            '$baseUrl/api/team/summary',
            options: Options(headers: h),
          ));
      final data = (res.data as Map?)?.cast<String, dynamic>();
      if (res.statusCode == 404) {
        // サーバ側では抜けている。端末の控えを合わせる
        await _remember(null);
        return null;
      }
      if (res.statusCode != 200 || data == null) return null;
      return TeamSummary.fromJson(data);
    } catch (e) {
      debugPrint('クラスの合計を取れなかった: $e');
      return null;
    }
  }

  /// 直近ぶんを送る。**冪等なので、いつ何度呼んでもよい。**
  ///
  /// 貢献の真実は端末の `days`。サーバはそれを受け取って合計するだけで、
  /// 端末が「送れたか」を覚えておく必要はない。
  Future<bool> syncContributions({DateTime? now}) async {
    if (!isConfigured || await saved() == null) return false;
    final today = dayKeyOf(now ?? DateTime.now());
    final oldest = shiftDay(today, -backfillDays);

    final days = [
      for (final d in await _store.days(limit: backfillDays * 2))
        if (d.done > 0 &&
            daysBetweenKeys(oldest, d.day) >= 0 &&
            daysBetweenKeys(d.day, today) >= 0)
          {'day': d.day, 'conceptsExplained': d.done, 'sessions': d.sessions},
    ];
    if (days.isEmpty) return true;

    try {
      final res = await _send((h) => _dio.post<Object?>(
            '$baseUrl/api/team/contribution',
            data: {'days': days},
            options: Options(headers: h),
          ));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('クラスへの反映に失敗: $e');
      return false;
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
