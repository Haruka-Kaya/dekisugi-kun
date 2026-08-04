import 'package:provider/provider.dart';

import 'config/app_theme.dart';
import 'config/env.dart';
import 'config/motion.dart';
import 'screens/consent_screen.dart';
import 'screens/talk_screen.dart';
import 'services/consent.dart';
import 'services/device_identity.dart';
import 'services/director_client.dart';
import 'services/live_session.dart';
import 'services/session_store.dart';
import 'ui/_material.dart';

/// 明暗テーマを固定して起動するための開発用スイッチ。
///
/// `flutter run --dart-define=FORCE_BRIGHTNESS=dark` のように使う。
/// 未指定なら端末の設定に従う（本番の挙動）。
const String _kForceBrightness =
    String.fromEnvironment('FORCE_BRIGHTNESS', defaultValue: '');

ThemeMode get _themeMode => switch (_kForceBrightness) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

/// いま扱う単元。単元の選択画面はまだ作っていない。
const String kUnitId = 'force-motion';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 記録の置き場を先に開く。開けなくてもアプリは動く（記録が残らないだけ）
  final store = await openSessionStore();
  runApp(DekisugiApp(store: store));
}

class DekisugiApp extends StatelessWidget {
  const DekisugiApp({super.key, required this.store});

  final SessionStore store;

  @override
  Widget build(BuildContext context) {
    final identity =
        DeviceIdentity(baseUrl: Env.directorUrl, store: store);

    return MultiProvider(
      providers: [
        Provider<SessionStore>.value(value: store),
        Provider<ConsentStore>.value(value: ConsentStore(store)),
        ChangeNotifierProvider(
          create: (_) => LiveSessionController(
            apiKey: Env.geminiApiKey,
            unitId: kUnitId,
            store: store,
            director:
                DirectorClient(baseUrl: Env.directorUrl, identity: identity),
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
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: 1.0,
          maxScaleFactor: 1.6,
          // 「動きを減らす」設定は Android と iOS で出所が違う。
          // ここで両方を1つにまとめて配る
          child: ReduceMotionScope(child: child ?? const SizedBox.shrink()),
        ),
        home: const _Gate(),
      ),
    );
  }
}

/// 同意を確かめてから会話画面へ入れる。
///
/// **同意の判定は毎回読み直す。** 「同意済み」を1つのフラグで持つと、
/// 文面の版を上げたときや条件を足したときに、古い記録が通り続ける。
class _Gate extends StatefulWidget {
  const _Gate();

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  ConsentRecord? _consent;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final got = await context.read<ConsentStore>().load();
    if (!mounted) return;
    setState(() {
      _consent = got;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_consent?.isValid == true) return const TalkScreen();

    return ConsentScreen(
      onAgreed: (record) async {
        await context.read<ConsentStore>().save(record);
        if (mounted) setState(() => _consent = record);
      },
    );
  }
}
