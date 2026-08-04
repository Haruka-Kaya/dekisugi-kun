import 'package:provider/provider.dart';

import 'config/app_theme.dart';
import 'config/env.dart';
import 'config/motion.dart';
import 'screens/talk_screen.dart';
import 'services/director_client.dart';
import 'services/live_session.dart';
import 'ui/_material.dart';

/// 明暗テーマを固定して起動するための開発用スイッチ。
///
/// `flutter run --dart-define=FORCE_BRIGHTNESS=dark` のように使う。
/// 未指定なら端末の設定に従う（本番の挙動）。
/// OS のテーマ設定を切り替えずに両方を確認できるようにするためだけのもの。
const String _kForceBrightness =
    String.fromEnvironment('FORCE_BRIGHTNESS', defaultValue: '');

ThemeMode get _themeMode => switch (_kForceBrightness) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

void main() {
  runApp(const DekisugiApp());
}

class DekisugiApp extends StatelessWidget {
  const DekisugiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LiveSessionController(
            apiKey: Env.geminiApiKey,
            // 段階2 はまず力学1単元。単元の選択画面は段階4
            unitId: 'force-motion',
            director: DirectorClient(
              baseUrl: Env.directorUrl,
              token: Env.directorToken,
            ),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'デキすぎ君',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(Brightness.light),
        darkTheme: buildAppTheme(Brightness.dark),
        themeMode: _themeMode,
        // 端末の文字サイズ設定を尊重しつつ上限を切る。
        // 無制限だと 2.0倍以上でレイアウトが壊れ、固定すると弱視の利用者を締め出す。
        // 下限 1.0 は縮小されて読めなくなるのを防ぐため。
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: 1.0,
          maxScaleFactor: 1.6,
          // 「動きを減らす」設定は Android と iOS で出所が違う。
          // ここで両方を1つにまとめて配る
          child: ReduceMotionScope(child: child ?? const SizedBox.shrink()),
        ),
        home: const TalkScreen(),
      ),
    );
  }
}
