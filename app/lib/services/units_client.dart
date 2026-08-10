import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/unit.dart';
import 'session_store.dart';

/// 単元カタログと教材を取ってきて、端末に持たせる。
///
/// ## 取れなかったら保存したもの、最後に同梱教材を出す
///
/// 教材は**読み物**なので、通信の都合で読めなくなるのは筋が悪い。
/// とくに「もう一度見るところ」は電車の中で開かれる想定で、
/// そこで読めないなら弱点を出す意味が薄い。
///
/// なので取得は「新しいものが取れたら差し替える」であって、
/// **失敗しても前のものを出す**。完全な新規インストールでも、
/// サーバ定義から機械生成した同梱教材を出して空にしない。
class UnitsClient {
  UnitsClient({
    required this.baseUrl,
    required SessionStore store,
    Dio? dio,
    AssetBundle? assetBundle,
  }) : // 公開constructorの`store:`名を保つ。
       // ignore: prefer_initializing_formals
       _store = store,
       _assetBundle = assetBundle ?? rootBundle,
       _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 15),
               validateStatus: (_) => true,
             ),
           );

  final String baseUrl;
  final SessionStore _store;
  final Dio _dio;
  final AssetBundle _assetBundle;

  /// 同じアプリ内で端末内/オンライン用Clientを作り直しても、大きい同梱JSONを
  /// isolateへ何度も読み直さない。テストの差替えAssetBundleはidentityごとに分離する。
  static final Expando<Future<_BundledCatalog?>> _sharedBundledCatalog =
      Expando<Future<_BundledCatalog?>>('dekisugi bundled unit catalog');
  Future<_BundledCatalog?>? _bundledCatalogFuture;

  bool get isConfigured => baseUrl.isNotEmpty;

  // schemaを保存keyへ含め、Listening専用needの無いv8以前をv9として
  // 推測せず同梱正本へ退避する。
  static const _listKey = 'units.v9.list';
  static const _bundledCatalogAsset = 'assets/catalog/units.ja.json';
  String _detailKey(String unitId) => 'units.v9.detail.$unitId';

  /// 単元の一覧。新しいもの、保存したもの、同梱教材の順で返す。
  Future<List<UnitSummary>> list() async {
    final fresh = await _fetchList();
    if (fresh != null && fresh.isNotEmpty) {
      await _store.setSetting(
        _listKey,
        jsonEncode([for (final u in fresh) u.toJson()]),
      );
      return fresh;
    }
    final cached = await _cachedList();
    if (cached.isNotEmpty) return cached;

    final bundled = await _bundledCatalog();
    return bundled?.summaries ?? const [];
  }

  /// 教材つきの1単元。新しいもの、保存したもの、同梱教材の順で返す。
  ///
  /// **どこにも無ければ null。** 教材が無いまま会話を始めると、
  /// 「教材を読んで説明する」という前提が崩れる。
  Future<UnitDetail?> detail(String unitId) async {
    final fresh = await _fetchDetail(unitId);
    if (fresh != null) {
      await _store.setSetting(_detailKey(unitId), jsonEncode(fresh.toJson()));
      return fresh;
    }
    final cached = await _cachedDetail(unitId);
    if (cached != null) return cached;

    return (await _bundledCatalog())?.details[unitId];
  }

  /// 端末内だけを見る。保存したもの、同梱教材の順で返し、**通信しない。**
  Future<UnitDetail?> cachedDetail(String unitId) async {
    final cached = await _cachedDetail(unitId);
    if (cached != null) return cached;
    return (await _bundledCatalog())?.details[unitId];
  }

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
          .where(_isUsableSummary)
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
      final envelope = res.data;
      if (envelope is! Map || envelope['schemaVersion'] != 9) return null;
      final raw = envelope['unit'];
      if (raw is! Map) return null;
      final detail = UnitDetail.fromJson(raw.cast<String, Object?>());
      return detail != null && _isUsableDetail(detail) ? detail : null;
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
          .where(_isUsableSummary)
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
      final detail = UnitDetail.fromJson(json.cast<String, Object?>());
      return detail != null && _isUsableDetail(detail) ? detail : null;
    } catch (e) {
      debugPrint('保存した教材を読めなかった: $e');
      return null;
    }
  }

  // ── アプリ同梱教材 ────────────────────────────────────────

  Future<_BundledCatalog?> _bundledCatalog() => _bundledCatalogFuture ??=
      _sharedBundledCatalog[_assetBundle] ??= _readBundledCatalog();

  Future<_BundledCatalog?> _readBundledCatalog() async {
    try {
      final raw = await _assetBundle.loadString(_bundledCatalogAsset);
      final json = jsonDecode(raw);
      // v9からListeningの聞き取り/意味needも別々に必須。
      // 旧版や未知schemaから誤診対象を推測せず、catalog全体を拒否する。
      if (json is! Map ||
          json.length != 3 ||
          json.keys.any(
            (key) =>
                !const {'schemaVersion', 'language', 'units'}.contains(key),
          ) ||
          json['schemaVersion'] != 9 ||
          json['language'] != 'ja') {
        return null;
      }

      final rawUnits = json['units'];
      if (rawUnits is! List || rawUnits.any((unit) => unit is! Map)) {
        return null;
      }

      final summaries = <UnitSummary>[];
      final details = <String, UnitDetail>{};
      for (final rawUnit in rawUnits.cast<Map>()) {
        final detail = UnitDetail.fromJson(rawUnit.cast<String, Object?>());
        if (detail == null || !_isUsableDetail(detail)) return null;
        // 重複IDは、一覧で選んだ教材と本文が一意にならないので全体を拒否する。
        if (details.containsKey(detail.id)) return null;
        summaries.add(detail.summary);
        details[detail.id] = detail;
      }
      if (details.isEmpty) return null;
      return _BundledCatalog(summaries: summaries, details: details);
    } catch (e) {
      debugPrint('同梱した教材を読めなかった: $e');
      return null;
    }
  }

  static bool _isUsableSummary(UnitSummary summary) =>
      summary.title.trim().isNotEmpty &&
      summary.concepts.isNotEmpty &&
      summary.sectionCount > 0;

  static bool _isUsableDetail(UnitDetail detail) {
    if (!_isUsableSummary(detail.summary) ||
        detail.summary.sectionCount != detail.sections.length) {
      return false;
    }
    final conceptKeys = detail.summary.concepts
        .map((concept) => concept.key)
        .toSet();
    final sectionKeys = detail.sections
        .map((section) => section.conceptKey)
        .toSet();
    return conceptKeys.length == detail.summary.concepts.length &&
        sectionKeys.length == detail.sections.length &&
        conceptKeys.length == sectionKeys.length &&
        conceptKeys.containsAll(sectionKeys);
  }
}

class _BundledCatalog {
  const _BundledCatalog({required this.summaries, required this.details});

  final List<UnitSummary> summaries;
  final Map<String, UnitDetail> details;
}
