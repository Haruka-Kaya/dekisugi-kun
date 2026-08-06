/// ビルド時に埋め込む設定。
///
/// **APIキーはもう入っていない。**
/// 会話は、サーバが発行する時間つきの一時トークンでしか繋げない。
/// これで APK を覗いても Gemini を直接叩けなくなり、無料枠の上限が成立する。
///
/// ここに残っているのは公開してよい接続先だけ。
abstract final class Env {
  /// サーバの置き場。**これが無いと会話そのものができない。**
  ///
  /// 会話用の一時トークンもここから取る。
  /// 例: `--dart-define=SERVER_URL=https://rika-chousa.vercel.app`
  static const String directorUrl = String.fromEnvironment(
    'SERVER_URL',
    defaultValue: 'https://rika-chousa.vercel.app',
  );

  static bool get hasServer => directorUrl.isNotEmpty;
}
