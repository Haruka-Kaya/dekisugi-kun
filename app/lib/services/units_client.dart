import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/unit.dart';
import 'session_store.dart';

/// 単元カタログと教材を取ってきて、端末に持たせる。
///
/// ## 取れなかったら保存したものを出す
///
/// 教材は**読み物**なので、通信の都合で読めなくなるのは筋が悪い。
/// とくに「もう一度見るところ」は電車の中で開かれる想定で、
/// そこで読めないなら弱点を出す意味が薄い。
///
/// なので取得は「新しいものが取れたら差し替える」であって、
/// **失敗しても前のものを出す**。空を返さない。
class UnitsClient {
  UnitsClient({required this.baseUrl, required SessionStore store, Dio? dio})
      : _store = store,
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              validateStatus: (_) => true,
            ));

  final String baseUrl;
  final SessionStore _store;
  final Dio _dio;

  bool get isConfigured => baseUrl.isNotEmpty;

  static const _listKey = 'units.list';
  String _detailKey(String unitId) => 'units.detail.$unitId';

  /// 単元の一覧。取れなければ保存したもの、それも無ければ空。
  Future<List<UnitSummary>> list() async {
    final fresh = await _fetchList();
    if (fresh != null && fresh.isNotEmpty) {
      await _store.setSetting(
          _listKey, jsonEncode([for (final u in fresh) u.toJson()]));
      return fresh;
    }
    return _cachedList();
  }

  /// 教材つきの1単元。取れなければ保存したもの。
  ///
  /// **両方無ければ null。** 教材が無いまま会話を始めると、
  /// 「教材を読んで説明する」という前提が崩れる。
  Future<UnitDetail?> detail(String unitId) async {
    final fresh = await _fetchDetail(unitId);
    if (fresh != null) {
      await _store.setSetting(_detailKey(unitId), jsonEncode(fresh.toJson()));
      return fresh;
    }
    return _cachedDetail(unitId);
  }

  /// 保存済みだけを見る。**通信しない。**
  Future<UnitDetail?> cachedDetail(String unitId) => _cachedDetail(unitId);

  // ── 通信 ──────────────────────────────────────────────────

  Future<List<UnitSummary>?> _fetchList() async {
    if (!isConfigured) return null;
    try {
      final res = await _dio.get<Object?>('$baseUrl/api/units');
      if (res.statusCode != 200) return null;
      final raw = (res.data as Map?)?['units'];
      if (raw is! List) return null;
      return raw
          .whereType<Map>()
          .map((u) => UnitSummary.fromJson(u.cast<String, Object?>()))
          .nonNulls
          .toList();
    } catch (e) {
      debugPrint('単元一覧の取得に失敗: $e');
      return null;
    }
  }

  Future<UnitDetail?> _fetchDetail(String unitId) async {
    if (!isConfigured) return null;
    try {
      final res = await _dio.get<Object?>(
        '$baseUrl/api/units',
        queryParameters: {'id': unitId},
      );
      if (res.statusCode != 200) return null;
      final raw = (res.data as Map?)?['unit'];
      if (raw is! Map) return null;
      return UnitDetail.fromJson(raw.cast<String, Object?>());
    } catch (e) {
      debugPrint('単元の取得に失敗: $e');
      return null;
    }
  }

  // ── 保存 ──────────────────────────────────────────────────

  Future<List<UnitSummary>> _cachedList() async {
    final raw = await _store.getSetting(_listKey);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map((u) => UnitSummary.fromJson(u.cast<String, Object?>()))
          .nonNulls
          .toList();
    } catch (e) {
      debugPrint('保存した単元一覧を読めなかった: $e');
      return const [];
    }
  }

  Future<UnitDetail?> _cachedDetail(String unitId) async {
    final raw = await _store.getSetting(_detailKey(unitId));
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      return UnitDetail.fromJson(json.cast<String, Object?>());
    } catch (e) {
      debugPrint('保存した教材を読めなかった: $e');
      return null;
    }
  }
}
