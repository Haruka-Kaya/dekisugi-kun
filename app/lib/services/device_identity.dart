import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'session_store.dart';

/// 端末の身元。**個人を特定しない。**
///
/// 端末が自分で作った UUID をサーバに預け、署名付きトークンを受け取る。
/// 名前もメールも端末の識別子（IMEI・広告ID など）も使わない。
/// 目的は「同じ端末であること」を示して回数制限を成立させることだけ。
///
/// 段階5 前は APK に焼いた共有トークンだったので、1本抜ければ全員が通れ、
/// しかも**止める手段が無かった**。これは端末ごとに切れる。
class DeviceIdentity {
  DeviceIdentity({required this.baseUrl, required SessionStore store, Dio? dio})
      : _store = store,
        _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: {'Content-Type': 'application/json'},
              validateStatus: (_) => true,
            ));

  final String baseUrl;
  final SessionStore _store;
  final Dio _dio;

  static const _kDeviceId = 'device_id';
  static const _kToken = 'device_token';
  static const _kTokenExp = 'device_token_exp';

  String? _cached;

  /// いま使えるトークン。無ければ取りに行く。
  ///
  /// 失敗したら null。**会話は止めない**（ディレクターが働かないだけ）。
  Future<String?> token({bool force = false}) async {
    if (!force && _cached != null) return _cached;
    if (baseUrl.isEmpty) return null;

    if (!force) {
      final saved = await _store.getSetting(_kToken);
      final exp = int.tryParse(await _store.getSetting(_kTokenExp) ?? '');
      // 期限の手前で取り直す。ぴったりだと会話の途中で切れる
      final margin = DateTime.now()
          .add(const Duration(days: 1))
          .millisecondsSinceEpoch;
      if (saved != null && exp != null && exp > margin) {
        _cached = saved;
        return saved;
      }
    }

    return _register();
  }

  Future<String?> _register() async {
    final deviceId = await _deviceId();
    try {
      final res = await _dio.post<Object?>(
        '$baseUrl/api/register',
        data: {'deviceId': deviceId},
      );
      if (res.statusCode != 200 || res.data is! Map) {
        debugPrint('端末の登録に失敗: HTTP ${res.statusCode}');
        return null;
      }
      final map = (res.data! as Map).cast<String, dynamic>();
      final token = map['token'] as String?;
      final expiresIn = (map['expiresIn'] as num?)?.toInt();
      if (token == null || token.isEmpty) return null;

      _cached = token;
      await _store.setSetting(_kToken, token);
      if (expiresIn != null) {
        final exp = DateTime.now()
            .add(Duration(seconds: expiresIn))
            .millisecondsSinceEpoch;
        await _store.setSetting(_kTokenExp, '$exp');
      }
      return token;
    } catch (e) {
      debugPrint('端末の登録で例外: $e');
      return null;
    }
  }

  /// 端末IDは初回に1度だけ作って残す。
  Future<String> _deviceId() async {
    final saved = await _store.getSetting(_kDeviceId);
    if (saved != null && saved.isNotEmpty) return saved;
    final id = _uuidV4();
    await _store.setSetting(_kDeviceId, id);
    return id;
  }

  /// UUID v4。
  ///
  /// **`Random()` を使わない。** 既定の乱数は予測できるので、
  /// 他人の端末IDを当てられてしまう。
  static String _uuidV4() {
    final rnd = Random.secure();
    final b = List<int>.generate(16, (_) => rnd.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // version 4
    b[8] = (b[8] & 0x3f) | 0x80; // variant 10
    String hex(int from, int to) =>
        b.sublist(from, to).map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }

  /// 端末を作り直す（テストと、記録を消したときのため）。
  Future<void> reset() async {
    _cached = null;
    await _store.setSetting(_kToken, null);
    await _store.setSetting(_kTokenExp, null);
    await _store.setSetting(_kDeviceId, null);
  }
}

/// base64url。トークンの中身を覗くために使う（検証はしない）。
Map<String, dynamic>? peekTokenClaims(String token) {
  try {
    final payload = token.split('.').first;
    final pad = '=' * ((4 - payload.length % 4) % 4);
    final json = utf8.decode(base64Url.decode(payload + pad));
    return (jsonDecode(json) as Map).cast<String, dynamic>();
  } catch (_) {
    return null;
  }
}
