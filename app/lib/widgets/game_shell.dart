import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../config/motion.dart';
import '../models/game_path.dart';
import '../ui/_material.dart';
import 'player_status_bar.dart';
import 'readable_width.dart';

enum GameTab { path, stories, practice, notation, league, profile }

typedef GameQuestTabResolver = GameTab Function(GameQuest quest);

extension on GameTab {
  String get shortLabel => switch (this) {
    GameTab.path => '学ぶ',
    GameTab.stories => '物語',
    GameTab.practice => '練習',
    GameTab.notation => '記号',
    GameTab.league => '競う',
    GameTab.profile => '自分',
  };

  String get semanticsLabel => switch (this) {
    GameTab.path => '学習パス',
    GameTab.stories => '理科の物語',
    GameTab.practice => '個別練習',
    GameTab.notation => '理科の記号ラボ',
    GameTab.league => '探究リーグ',
    GameTab.profile => '自分の学習記録',
  };

  IconData get icon => switch (this) {
    GameTab.path => Icons.route_outlined,
    GameTab.stories => Icons.auto_stories_outlined,
    GameTab.practice => Icons.fitness_center_outlined,
    GameTab.notation => Icons.functions_outlined,
    GameTab.league => Icons.emoji_events_outlined,
    GameTab.profile => Icons.face_outlined,
  };

  IconData get selectedIcon => switch (this) {
    GameTab.path => Icons.route,
    GameTab.stories => Icons.auto_stories,
    GameTab.practice => Icons.fitness_center,
    GameTab.notation => Icons.functions_rounded,
    GameTab.league => Icons.emoji_events,
    GameTab.profile => Icons.face,
  };
}

/// Path・Story・Practice・Notation・League・Profileを保持するアプリ骨格。
///
/// [IndexedStack]を使い、タブを移動してもPathのスクロール位置や練習一覧を失わない。
class GameShell extends StatefulWidget {
  const GameShell({
    super.key,
    required this.path,
    required this.stories,
    required this.practice,
    required this.notation,
    required this.league,
    required this.profile,
    this.initialTab = GameTab.path,
    this.onTabChanged,
    this.schoolMode = false,
    this.playerStatus,
    this.quests = const <GameQuest>[],
    this.onQuestSelected,
    this.questTabFor,
    this.questUnavailable = false,
    this.onQuestRetry,
    this.onStreakTap,
    this.onGemsTap,
    this.onHeartsTap,
  });

  final Widget path;
  final Widget stories;
  final Widget practice;
  final Widget notation;
  final Widget league;
  final Widget profile;
  final GameTab initialTab;
  final ValueChanged<GameTab>? onTabChanged;
  final bool schoolMode;
  final GamePlayerStatus? playerStatus;
  final List<GameQuest> quests;
  final GameQuestCallback? onQuestSelected;
  final GameQuestTabResolver? questTabFor;
  final bool questUnavailable;
  final VoidCallback? onQuestRetry;
  final VoidCallback? onStreakTap;
  final VoidCallback? onGemsTap;
  final VoidCallback? onHeartsTap;

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  late GameTab _tab = widget.initialTab;

  void _select(GameTab tab) {
    if (_tab == tab) return;
    setState(() => _tab = tab);
    widget.onTabChanged?.call(tab);
  }

  void _selectQuest(GameQuest quest) {
    _select(
      widget.questTabFor?.call(quest) ??
          (quest.kind == GameQuestKind.friend ? GameTab.profile : GameTab.path),
    );
    widget.onQuestSelected?.call(quest);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      widget.path,
      widget.stories,
      widget.practice,
      widget.notation,
      widget.league,
      widget.profile,
    ];
    final content = IndexedStack(index: _tab.index, children: pages);
    final playerStatus = widget.playerStatus;
    final shellContent = playerStatus == null
        ? content
        : SafeArea(
            bottom: false,
            child: Column(
              key: const ValueKey('game-shell-content'),
              children: [
                GamePlayerStatusHeader(
                  status: playerStatus,
                  quests: widget.quests,
                  schoolMode: widget.schoolMode,
                  // Questは進捗を眺めるだけのカードにせず、種類ごとの実行場所へ
                  // 必ず移動する。上位callbackは画面遷移後の追加処理だけを担う。
                  onQuestSelected: _selectQuest,
                  questUnavailable: widget.questUnavailable,
                  onQuestRetry: widget.onQuestRetry,
                  onStreakTap: widget.onStreakTap,
                  onGemsTap: widget.onGemsTap,
                  onHeartsTap: widget.onHeartsTap,
                ),
                Expanded(child: content),
              ],
            ),
          );
    if (isWide(context)) {
      return Scaffold(
        body: Row(
          children: [
            _GameTabRail(
              selected: _tab,
              schoolMode: widget.schoolMode,
              onSelect: _select,
            ),
            Expanded(child: shellContent),
          ],
        ),
      );
    }
    return Scaffold(
      body: shellContent,
      bottomNavigationBar: _GameTabBar(
        selected: _tab,
        schoolMode: widget.schoolMode,
        onSelect: _select,
      ),
    );
  }
}

class _GameTabBar extends StatelessWidget {
  const _GameTabBar({
    required this.selected,
    required this.schoolMode,
    required this.onSelect,
  });

  final GameTab selected;
  final bool schoolMode;
  final ValueChanged<GameTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    return Material(
      color: colors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 72,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final tab in GameTab.values)
                  Expanded(
                    child: Semantics(
                      key: ValueKey('game-tab-${tab.name}'),
                      button: true,
                      selected: selected == tab,
                      label: _semanticLabel(tab, schoolMode: schoolMode),
                      onTap: () => onSelect(tab),
                      child: ExcludeSemantics(
                        child: InkWell(
                          onTap: () => onSelect(tab),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 72),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                                vertical: 4,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _iconFor(
                                      tab,
                                      selected: selected == tab,
                                      schoolMode: schoolMode,
                                    ),
                                    color: selected == tab
                                        ? colors.pathActive
                                        : colors.inkMuted,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _shortLabel(tab, schoolMode: schoolMode),
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                    style: theme.textTheme.labelSmall
                                        ?.copyWith(
                                          color: selected == tab
                                              ? colors.pathActive
                                              : colors.inkMuted,
                                        )
                                        .jaWeight(
                                          selected == tab
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameTabRail extends StatelessWidget {
  const _GameTabRail({
    required this.selected,
    required this.schoolMode,
    required this.onSelect,
  });

  final GameTab selected;
  final bool schoolMode;
  final ValueChanged<GameTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    final extended = MediaQuery.sizeOf(context).width >= 1000;
    final reduceMotion = ReduceMotionScope.of(context);
    return Material(
      key: const ValueKey('game-tab-rail'),
      color: colors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: colors.border)),
        ),
        child: SafeArea(
          right: false,
          child: SizedBox(
            width: extended ? 216 : 104,
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: GameTokens.spaceSm,
                vertical: GameTokens.spaceLg,
              ),
              children: [
                for (final tab in GameTab.values) ...[
                  Semantics(
                    key: ValueKey('game-tab-${tab.name}'),
                    button: true,
                    selected: selected == tab,
                    label: _semanticLabel(tab, schoolMode: schoolMode),
                    onTap: () => onSelect(tab),
                    child: ExcludeSemantics(
                      child: InkWell(
                        onTap: () => onSelect(tab),
                        borderRadius: BorderRadius.circular(
                          GameTokens.radiusMd,
                        ),
                        child: AnimatedContainer(
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 100),
                          constraints: const BoxConstraints(minHeight: 64),
                          padding: EdgeInsets.symmetric(
                            horizontal: extended
                                ? GameTokens.spaceLg
                                : GameTokens.spaceSm,
                            vertical: GameTokens.spaceSm,
                          ),
                          decoration: BoxDecoration(
                            color: selected == tab
                                ? colors.surfaceRaised
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(
                              GameTokens.radiusMd,
                            ),
                            border: Border.all(
                              color: selected == tab
                                  ? colors.pathActive
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: extended
                              ? Row(
                                  children: [
                                    Icon(
                                      _iconFor(
                                        tab,
                                        selected: selected == tab,
                                        schoolMode: schoolMode,
                                      ),
                                      color: selected == tab
                                          ? colors.pathActive
                                          : colors.inkMuted,
                                    ),
                                    const SizedBox(width: GameTokens.spaceMd),
                                    Expanded(
                                      child: Text(
                                        _shortLabel(
                                          tab,
                                          schoolMode: schoolMode,
                                        ),
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              color: selected == tab
                                                  ? colors.pathActive
                                                  : colors.inkMuted,
                                            )
                                            .jaWeight(
                                              selected == tab
                                                  ? FontWeight.w800
                                                  : FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _iconFor(
                                        tab,
                                        selected: selected == tab,
                                        schoolMode: schoolMode,
                                      ),
                                      color: selected == tab
                                          ? colors.pathActive
                                          : colors.inkMuted,
                                    ),
                                    const SizedBox(height: GameTokens.spaceXs),
                                    Text(
                                      _shortLabel(tab, schoolMode: schoolMode),
                                      maxLines: 1,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: selected == tab
                                                ? colors.pathActive
                                                : colors.inkMuted,
                                          )
                                          .jaWeight(
                                            selected == tab
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: GameTokens.spaceSm),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _semanticLabel(GameTab tab, {required bool schoolMode}) =>
    schoolMode && tab == GameTab.league ? 'この端末の授業目標' : tab.semanticsLabel;

String _shortLabel(GameTab tab, {required bool schoolMode}) =>
    schoolMode && tab == GameTab.league ? '協力' : tab.shortLabel;

IconData _iconFor(
  GameTab tab, {
  required bool selected,
  required bool schoolMode,
}) => schoolMode && tab == GameTab.league
    ? Icons.groups_rounded
    : selected
    ? tab.selectedIcon
    : tab.icon;
