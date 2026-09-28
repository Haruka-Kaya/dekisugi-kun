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

  /// `flutter test` のfake asyncでは実isolateの完了を待てないので、
  /// test/flutter_test_config.dart からtrueにして同期decodeへ切り替える。
  @visibleForTesting
  static bool debugSynchronousBundledCatalog = false;

  bool get isConfigured => baseUrl.isNotEmpty;

  // schemaを保存keyへ含め、coverageとtagged Notationの無いv9以前を
  // v10として推測せず同梱正本へ退避する。
  static const _listKey = 'units.v10.list';
  static const _bundledCatalogAsset = 'assets/catalog/units.ja.json';
  String _detailKey(String unitId) => 'units.v10.detail.$unitId';

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
      final envelope = res.data;
      if (envelope is! Map ||
          envelope.length != 2 ||
          envelope.keys.any(
            (key) =>
                key is! String ||
                !const {'schemaVersion', 'units'}.contains(key),
          ) ||
          envelope['schemaVersion'] != 10) {
        return null;
      }

      return _parseSummaryList(envelope['units']);
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
      if (envelope is! Map || envelope['schemaVersion'] != 10) return null;
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
      return _parseSummaryList(jsonDecode(raw)) ?? const [];
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
      // 700KB超の decode＋全単元のfromJsonをmain isolateですると起動中に
      // frameを落とすので、別isolateへ逃がす。
      if (debugSynchronousBundledCatalog) {
        return _decodeBundledCatalog(raw);
      }
      return await compute(_decodeBundledCatalog, raw);
    } catch (e) {
      debugPrint('同梱した教材を読めなかった: $e');
      return null;
    }
  }

  static bool _isUsableSummary(UnitSummary summary) =>
      summary.title.trim().isNotEmpty &&
      summary.concepts.isNotEmpty &&
      summary.sectionCount > 0;

  /// 一覧は1単元でも壊れていれば全体を拒否する。
  ///
  /// onlineとv10 cacheで同じfail-closed規則を使い、壊れた要素だけを
  /// `nonNulls`で落として別の単元を部分採用しない。
  static List<UnitSummary>? _parseSummaryList(Object? rawUnits) {
    if (rawUnits is! List || rawUnits.isEmpty) return null;
    final summaries = <UnitSummary>[];
    final unitIds = <String>{};
    for (final rawUnit in rawUnits) {
      if (rawUnit is! Map || rawUnit.keys.any((key) => key is! String)) {
        return null;
      }
      final summary = UnitSummary.fromJson(rawUnit.cast<String, Object?>());
      if (summary == null ||
          !_isUsableSummary(summary) ||
          !unitIds.add(summary.id)) {
        return null;
      }
      summaries.add(summary);
    }
    return summaries;
  }

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

/// 同梱カタログJSONの decode → schema検証 → UnitDetail化。
/// `compute` 経由で別isolateから呼ぶためトップレベルに置く。
_BundledCatalog? _decodeBundledCatalog(String raw) {
  try {
    final json = jsonDecode(raw);
    // v10からcoverageと概念固有のNotation task unionも必須。
    // 旧版や未知schemaから誤診対象を推測せず、catalog全体を拒否する。
    if (json is! Map ||
        json.length != 3 ||
        json.keys.any(
          (key) =>
              !const {'schemaVersion', 'language', 'units'}.contains(key),
        ) ||
        json['schemaVersion'] != 10 ||
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
      if (detail == null || !UnitsClient._isUsableDetail(detail)) return null;
      // 重複IDは、一覧で選んだ教材と本文が一意にならないので全体を拒否する。
      if (details.containsKey(detail.id)) return null;
      summaries.add(detail.summary);
      details[detail.id] = detail;
    }
    if (details.isEmpty) return null;
    return _BundledCatalog(summaries: summaries, details: details);
  } catch (_) {
    return null;
  }
}
