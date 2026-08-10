import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;

import '../config/game_tokens.dart';
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
    this.exitTooltip = '学習パスへ戻る',
  });

  final ValueListenable<GamePlayerStatus> statusListenable;
  final bool schoolMode;
  final Widget child;
  final VoidCallback? onExit;
  final String exitTooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Scaffold(
      key: const ValueKey('game-activity-scaffold'),
      backgroundColor: colors.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ColoredBox(
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
                        if (onExit != null) ...[
                          Semantics(
                            button: true,
                            label: exitTooltip,
                            child: ExcludeSemantics(
                              child: IconButton(
                                key: const ValueKey('game-activity-exit'),
                                onPressed: onExit,
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
                        ],
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
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

/// 開いているactivityへ、Homeが再投影した最新statusだけを流す。
class GameActivityStatusController extends ValueNotifier<GamePlayerStatus> {
  GameActivityStatusController(super.value);

  void replace(GamePlayerStatus status) {
    value = status;
  }
}
