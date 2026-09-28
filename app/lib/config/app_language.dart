import 'dart:ui' show Locale;

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../services/session_store.dart';

/// 表示言語の既定。
///
/// `--dart-define=APP_LANG=en` で英語起動するビルドを作れる。
/// 未指定は日本語（現行ビルドと同じ動作）。
const String kDefaultAppLang = String.fromEnvironment(
  'APP_LANG',
  defaultValue: 'ja',
);

/// アプリの表示言語。
///
/// 教材の同梱カタログ・サーバの `?lang=`・画面文言の3箇所に効く。
enum AppLanguage {
  ja,
  en;

  Locale get locale => switch (this) {
        AppLanguage.ja => const Locale('ja'),
        AppLanguage.en => const Locale('en'),
      };

  /// この言語の同梱教材カタログのassetパス。
  String get bundledCatalogAsset =>
      'assets/catalog/units.$name.json';

  static AppLanguage? parse(String? raw) => switch (raw) {
        'ja' => AppLanguage.ja,
        'en' => AppLanguage.en,
        _ => null,
      };
}

/// 現在の言語。
///
/// [AppLanguageController.load] が起動時に確定させる。テストや、
/// Controllerをまだ読んでいない起動直前のコードは既定言語として振る舞う。
AppLanguage appLanguage = AppLanguage.parse(kDefaultAppLang) ?? AppLanguage.ja;

/// 画面文言を言語で選ぶ最小の分岐。
///
/// 「翻訳メモリ」や多言語フレームワークは要らない。日本語は現行画面が
/// 正本で、英語は審査用の2言語目として各所の文言の隣に添える。
String t(String ja, String en) =>
    appLanguage == AppLanguage.en ? en : ja;

/// 言語の選択を保存・配信する。
///
/// 再起動を跨いで保存し、切り替えた時点で MaterialApp の locale と
/// 教材カタログの参照先をまとめて切り替える。
class AppLanguageController extends ChangeNotifier {
  AppLanguageController._(this._store, this._language) {
    appLanguage = _language;
  }

  final SessionStore _store;
  AppLanguage _language;

  static const _settingKey = 'app_lang';

  /// 保存済みの選択（無ければビルド既定）で作る。
  static Future<AppLanguageController> load(SessionStore store) async {
    final saved = AppLanguage.parse(await store.getSetting(_settingKey));
    return AppLanguageController._(
      store,
      saved ?? AppLanguage.parse(kDefaultAppLang) ?? AppLanguage.ja,
    );
  }

  AppLanguage get language => _language;

  Future<void> setLanguage(AppLanguage language) async {
    if (language == _language) return;
    _language = language;
    appLanguage = language;
    notifyListeners();
    await _store.setSetting(_settingKey, language.name);
  }
}
