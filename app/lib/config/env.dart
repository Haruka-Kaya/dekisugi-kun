/// ビルド時に埋め込む設定。
///
/// **キーをソースに書かないこと。** `--dart-define` で渡す:
///
/// ```powershell
/// flutter run --dart-define=GEMINI_API_KEY=xxxx
/// # tools\run-dev.ps1 が .env.local から読んで渡してくれる
/// ```
///
/// 段階5 で、端末に生キーを置かない形（サーバが ephemeral token を発行）に差し替える。
/// `--dart-define` は APK の中に平文で残るので、**配布ビルドでは使えない**。
abstract final class Env {
  static const String geminiApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  static bool get hasGeminiKey => geminiApiKey.isNotEmpty;

  /// ディレクター（進行役）の置き場。空なら会話はできるが進行しない。
  /// 例: `--dart-define=DIRECTOR_URL=https://dekisugi.vercel.app`
  static const String directorUrl =
      String.fromEnvironment('DIRECTOR_URL', defaultValue: '');

  static bool get hasDirector => directorUrl.isNotEmpty;

  /// ディレクターの門を通すトークン。**認証ではない**（APK から取り出せる）。
  /// 段階5 で本物の認証に入れ替える。
  static const String directorToken =
      String.fromEnvironment('DIRECTOR_TOKEN', defaultValue: '');
}
