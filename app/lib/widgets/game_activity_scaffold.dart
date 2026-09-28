import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;

import '../config/game_tokens.dart';
import '../learning/domain/learning_economy.dart';
import '../models/game_path.dart';
import '../ui/_material.dart';
import 'player_status_bar.dart';

/// Activity routeの外枠。
///
/// 6タブの[GameShell]から別routeへ進んでも、開始時の推測値ではなくHomeが
/// 再読込した実snapshotを上部へ固定表示する。本文は既存activityのScaffoldを
/// そのまま受けられるため、各課題固有のstateを共通chromeへ持ち込まない。
class GameActivityScaffold extends StatelessWidget {
  const GameActivityScaffold({
    super.key,
    required this.statusListenable,
    required this.schoolMode,
    required this.child,
    this.onExit,
    this.exitTooltip = '前の画面へ戻る',
    this.mascotStyle = LearningPathMascotStyle.standard,
  });

  final ValueListenable<GamePlayerStatus> statusListenable;
  final bool schoolMode;
  final Widget child;
  final VoidCallback? onExit;
  final String exitTooltip;
  final LearningPathMascotStyle mascotStyle;

  /// Homeのactivity route内かどうかを、各課題の公開APIを増やさず判定する。
  ///
  /// 単体で開く課題は従来どおり自身のAppBarを表示し、共有chrome配下だけ
  /// 子AppBarを抑止する。これにより戻る操作とHUDをroute上に各1個だけ置く。
  static bool hasSharedChrome(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GameActivityChromeScope>() !=
      null;

  /// Homeで装備中のマスコットをactivityの共通headerへ引き継ぐ。
  ///
  /// 単体widget testや共通chrome外では標準スタイルを使う。
  static LearningPathMascotStyle mascotStyleOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_GameActivityChromeScope>()
          ?.mascotStyle ??
      LearningPathMascotStyle.standard;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final exit = onExit ?? () => Navigator.maybePop(context);
    return Scaffold(
      key: const ValueKey('game-activity-scaffold'),
      backgroundColor: colors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ColoredBox(
              key: const ValueKey('game-activity-top-chrome'),
              color: colors.canvas,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  GameTokens.spaceMd,
                  GameTokens.spaceSm,
                  GameTokens.spaceMd,
                  GameTokens.spaceXs,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: GameTokens.readablePathWidth,
                    ),
                    child: Row(
                      key: const ValueKey('game-activity-status'),
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Semantics(
                          button: true,
                          label: exitTooltip,
                          onTap: exit,
                          child: ExcludeSemantics(
                            child: IconButton(
                              key: const ValueKey('game-activity-exit'),
                              onPressed: exit,
                              tooltip: exitTooltip,
                              icon: const Icon(Icons.arrow_back_rounded),
                              style: IconButton.styleFrom(
                                minimumSize: const Size.square(
                                  GameTokens.minTouchTarget,
                                ),
                                foregroundColor: colors.ink,
                                backgroundColor: colors.surface,
                                side: BorderSide(color: colors.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    GameTokens.radiusMd,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: GameTokens.spaceSm),
                        Expanded(
                          child: ValueListenableBuilder<GamePlayerStatus>(
                            valueListenable: statusListenable,
                            builder: (context, status, _) => PlayerStatusBar(
                              status: status,
                              schoolMode: schoolMode,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _GameActivityChromeScope(
                mascotStyle: mascotStyle,
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameActivityChromeScope extends InheritedWidget {
  const _GameActivityChromeScope({
    required this.mascotStyle,
    required super.child,
  });

  final LearningPathMascotStyle mascotStyle;

  @override
  bool updateShouldNotify(_GameActivityChromeScope oldWidget) =>
      mascotStyle != oldWidget.mascotStyle;
}

/// 開いているactivityへ、Homeが再投影した最新statusだけを流す。
class GameActivityStatusController extends ValueNotifier<GamePlayerStatus> {
  GameActivityStatusController(super.value);

  void replace(GamePlayerStatus status) {
    value = status;
  }
}
