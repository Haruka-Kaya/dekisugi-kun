import '../config/game_tokens.dart';
import '../learning/domain/learning_economy.dart';
import '../models/game_path.dart';
import '../ui/_material.dart';
import '../widgets/learning_path.dart';
import '../widgets/player_status_bar.dart';

/// 6タブ構成の主画面になる「学ぶ」タブ。
///
/// BottomNavigationBarは上位のGameShellが持つ。この画面は単独表示もできる。
/// [showStatusHeader]は単独表示の互換用に既定trueとし、GameShellへ入れる場合は
/// falseにしてShellの固定headerだけを使う。
class PathScreen extends StatelessWidget {
  const PathScreen({
    super.key,
    required this.data,
    this.scrollController,
    this.onNodeStart,
    this.onGuidebookOpen,
    this.onQuestSelected,
    this.onStreakTap,
    this.onGemsTap,
    this.onHeartsTap,
    this.mascotStyle = LearningPathMascotStyle.standard,
    this.showStatusHeader = true,
  });

  final GamePathViewData data;
  final ScrollController? scrollController;
  final GamePathNodeCallback? onNodeStart;
  final GamePathUnitCallback? onGuidebookOpen;
  final GameQuestCallback? onQuestSelected;
  final VoidCallback? onStreakTap;
  final VoidCallback? onGemsTap;
  final VoidCallback? onHeartsTap;
  final LearningPathMascotStyle mascotStyle;
  final bool showStatusHeader;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return ColoredBox(
      color: colors.canvas,
      child: SafeArea(
        bottom: true,
        child: Column(
          children: [
            Semantics(
              header: true,
              label: data.title,
              child: const SizedBox.shrink(),
            ),
            if (showStatusHeader)
              GamePlayerStatusHeader(
                status: data.status,
                quests: data.quests,
                schoolMode: data.schoolMode,
                onQuestSelected: onQuestSelected,
                onStreakTap: onStreakTap,
                onGemsTap: onGemsTap,
                onHeartsTap: onHeartsTap,
              ),
            Expanded(
              child: LearningPath(
                units: data.units,
                currentNodeId: data.currentNodeId,
                controller: scrollController,
                onNodeStart: onNodeStart,
                onGuidebookOpen: onGuidebookOpen,
                mascotStyle: mascotStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
