import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../learning/domain/learning_economy.dart';
import '../models/game_path.dart';
import '../services/session_store.dart';
import '../ui/_material.dart';
import 'learning_path.dart';

typedef SessionStoreOpener = Future<SessionStore> Function();
typedef SessionStoreAppBuilder = Widget Function(SessionStore store);

/// 永続DBを開けた時だけ本編を構築する起動境界。
///
/// Android / iOS / macOSで保存に失敗した際、Memory storeへ黙って退避して
/// 「保存できたように見えて再起動で全消失」する状態を作らない。
class SessionStoreBootstrap extends StatefulWidget {
  const SessionStoreBootstrap({
    super.key,
    required this.openStore,
    required this.appBuilder,
  });

  final SessionStoreOpener openStore;
  final SessionStoreAppBuilder appBuilder;

  @override
  State<SessionStoreBootstrap> createState() => _SessionStoreBootstrapState();
}

class _SessionStoreBootstrapState extends State<SessionStoreBootstrap> {
  late Future<SessionStore> _opening = widget.openStore();

  void _retry() {
    final opening = widget.openStore();
    setState(() {
      _opening = opening;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SessionStore>(
      future: _opening,
      builder: (context, snapshot) {
        final store = snapshot.data;
        if (store != null) return widget.appBuilder(store);
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(Brightness.light),
          darkTheme: buildAppTheme(Brightness.dark),
          themeMode: ThemeMode.system,
          home: _SessionStoreOpeningPage(
            failed: snapshot.hasError,
            onRetry: snapshot.hasError ? _retry : null,
          ),
        );
      },
    );
  }
}

class _SessionStoreOpeningPage extends StatelessWidget {
  const _SessionStoreOpeningPage({required this.failed, required this.onRetry});

  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final textTheme = Theme.of(context).textTheme;
    final title = failed ? '学習記録の保存先を開けませんでした' : '学習記録を準備しています';
    final message = failed
        ? '記録が消える一時モードでは開始しません。端末の空き容量を確認して、もう一度お試しください。'
        : '前回の続きと、今日の学習パスを読み込んでいます。';

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(GameTokens.spaceXl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Semantics(
                key: const ValueKey('session-store-bootstrap-status'),
                container: true,
                liveRegion: true,
                label: '$title。$message',
                child: ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.all(GameTokens.spaceXl),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(
                        GameTokens.radiusSheet,
                      ),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.center,
                          child: PathMascotPreview(
                            reaction: failed
                                ? GameCharacterReaction.encourage
                                : GameCharacterReaction.thinking,
                            size: 92,
                            style: LearningPathMascotStyle.standard,
                          ),
                        ),
                        const SizedBox(height: GameTokens.spaceLg),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: textTheme.headlineSmall
                              ?.copyWith(color: colors.ink)
                              .jaWeight(FontWeight.w800),
                        ),
                        const SizedBox(height: GameTokens.spaceSm),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyLarge?.copyWith(
                            color: colors.inkMuted,
                          ),
                        ),
                        if (onRetry != null) ...[
                          const SizedBox(height: GameTokens.spaceXl),
                          SizedBox(
                            height: 56,
                            child: FilledButton.icon(
                              key: const ValueKey(
                                'session-store-bootstrap-retry',
                              ),
                              onPressed: onRetry,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('もう一度開く'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
