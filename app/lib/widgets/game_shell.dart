import '../config/app_language.dart';
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
    GameTab.path => t('探究', 'Explore'),
    GameTab.stories => t('事件', 'Cases'),
    GameTab.practice => t('実験', 'Experiments'),
    GameTab.notation => t('図解', 'Diagrams'),
    GameTab.league => t('共同', 'Together'),
    GameTab.profile => t('研究室', 'My Lab'),
  };

  String get semanticsLabel => switch (this) {
    GameTab.path => t('探究ノート', 'Field Notebook'),
    GameTab.stories => t('理科事件簿', 'Science Cases'),
    GameTab.practice => t('再現実験', 'Experiments'),
    GameTab.notation => t('記号と図解', 'Symbols and Diagrams'),
    GameTab.league => t('共同観測', 'Shared Observations'),
    GameTab.profile => t('自分の研究室', 'My Lab'),
  };

  IconData get icon => switch (this) {
    GameTab.path => Icons.article_outlined,
    GameTab.stories => Icons.folder_open_outlined,
    GameTab.practice => Icons.biotech_outlined,
    GameTab.notation => Icons.schema_outlined,
    GameTab.league => Icons.groups_outlined,
    GameTab.profile => Icons.space_dashboard_outlined,
  };

  IconData get selectedIcon => switch (this) {
    GameTab.path => Icons.article_rounded,
    GameTab.stories => Icons.folder_rounded,
    GameTab.practice => Icons.biotech_rounded,
    GameTab.notation => Icons.schema_rounded,
    GameTab.league => Icons.groups_rounded,
    GameTab.profile => Icons.space_dashboard_rounded,
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
    this.showTabGuide = false,
    this.onTabGuideDismissed,
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

  /// 初回利用の直後だけ、各タブの役割を順番に伝える。
  final bool showTabGuide;
  final VoidCallback? onTabGuideDismissed;

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  late GameTab _tab = widget.initialTab;
  late bool _showTabGuide = widget.showTabGuide;

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
    final shell = isWide(context)
        ? Scaffold(
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
          )
        : Scaffold(
            body: shellContent,
            bottomNavigationBar: _GameTabBar(
              selected: _tab,
              schoolMode: widget.schoolMode,
              onSelect: _select,
            ),
          );
    if (!_showTabGuide) return shell;
    return Stack(
      children: [
        shell,
        GameTabGuide(
          schoolMode: widget.schoolMode,
          onDismissed: () {
            setState(() => _showTabGuide = false);
            widget.onTabGuideDismissed?.call();
          },
        ),
      ],
    );
  }
}

/// 初回の同意後に出す、各タブの役割を一つずつ伝える案内。
///
/// タブ名だけを列挙せず、「いつ開くか」を添える。案内を閉じても進捗は変えず、
/// どの画面にも後から通常のタブ操作で到達できる。
class GameTabGuide extends StatefulWidget {
  const GameTabGuide({
    super.key,
    required this.schoolMode,
    required this.onDismissed,
  });

  final bool schoolMode;
  final VoidCallback onDismissed;

  @override
  State<GameTabGuide> createState() => _GameTabGuideState();
}

class _GameTabGuideState extends State<GameTabGuide> {
  final _controller = PageController();
  var _index = 0;

  List<_TabGuideItem> get _items => [
    _TabGuideItem(
      icon: Icons.article_outlined,
      title: t('探究ノート', 'Field Notebook'),
      body: t(
        '今日の教材を開く場所です。まず予想を置き、教材の根拠と比べます。',
        'Open today\'s material, make a prediction, and compare it with the evidence.',
      ),
    ),
    _TabGuideItem(
      icon: Icons.folder_open_outlined,
      title: t('理科事件簿', 'Science Cases'),
      body: t(
        '身近な出来事を手がかりに、理由と条件を考える場所です。',
        'Use everyday events to think about reasons and conditions.',
      ),
    ),
    _TabGuideItem(
      icon: Icons.biotech_outlined,
      title: t('再現実験', 'Experiments'),
      body: t(
        '選ぶ・並べる・分ける課題で、教材の考え方を確かめる場所です。',
        'Check ideas from the material by choosing, ordering, and classifying.',
      ),
    ),
    _TabGuideItem(
      icon: Icons.schema_outlined,
      title: t('記号と図解', 'Symbols and Diagrams'),
      body: t(
        '図や式の意味を、言葉と対応づけて読み直す場所です。',
        'Connect diagrams and equations with words to check their meaning.',
      ),
    ),
    _TabGuideItem(
      icon: Icons.groups_outlined,
      title: widget.schoolMode
          ? t('共同観測', 'Shared Observations')
          : t('共同観測', 'Shared Observations'),
      body: widget.schoolMode
          ? t(
              '同じ端末で順番に取り組む授業用の観察を開く場所です。',
              'Open class observations and take turns on this device.',
            )
          : t(
              '友だちと同じテーマを観察します。回答本文や名前は共有しません。',
              'Observe the same topic with friends. Names and answers are not shared.',
            ),
    ),
    _TabGuideItem(
      icon: Icons.space_dashboard_outlined,
      title: t('自分の研究室', 'My Lab'),
      body: t(
        'これまでの観察と、あとでやる教材を振り返る場所です。',
        'Review your observations and material you plan to try later.',
      ),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _items.length - 1) {
      widget.onDismissed();
      return;
    }
    _controller.nextPage(
      duration: ReduceMotionScope.of(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Material(
      key: const ValueKey('game-tab-guide'),
      color: colors.canvas,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(GameTokens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '画面の見かた',
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: colors.pathActive)
                        .jaWeight(FontWeight.w800),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: const ValueKey('game-tab-guide-dismiss'),
                      onPressed: widget.onDismissed,
                      child: Text('あとで見る'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: GameTokens.spaceMd),
              Semantics(
                label: t('6ページ中${_index + 1}ページ目', 'Page ${_index + 1} of 6'),
                child: LinearProgressIndicator(
                  value: (_index + 1) / _items.length,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(GameTokens.radiusPill),
                ),
              ),
              const SizedBox(height: GameTokens.spaceXl),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _items.length,
                  onPageChanged: (index) => setState(() => _index = index),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: Container(
                              padding: const EdgeInsets.all(GameTokens.spaceXl),
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: BorderRadius.circular(
                                  GameTokens.radiusMd,
                                ),
                                border: Border.all(color: colors.border),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    item.icon,
                                    color: colors.pathActive,
                                    size: 40,
                                  ),
                                  const SizedBox(height: GameTokens.spaceLg),
                                  Text(
                                    item.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(color: colors.ink)
                                        .jaWeight(FontWeight.w900),
                                  ),
                                  const SizedBox(height: GameTokens.spaceMd),
                                  Text(
                                    item.body,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(color: colors.inkMuted),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              FilledButton.icon(
                key: const ValueKey('game-tab-guide-next'),
                onPressed: _next,
                icon: Icon(
                  _index == _items.length - 1
                      ? Icons.check_rounded
                      : Icons.arrow_forward_rounded,
                ),
                label: Text(
                  _index == _items.length - 1
                      ? t('探究を始める', 'Start exploring')
                      : t('次へ', 'Next'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabGuideItem {
  const _TabGuideItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
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
                          child: AnimatedContainer(
                            duration: ReduceMotionScope.of(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 100),
                            constraints: const BoxConstraints(minHeight: 72),
                            decoration: BoxDecoration(
                              color: selected == tab
                                  ? colors.surfaceRaised
                                  : colors.surface,
                              border: Border(
                                top: BorderSide(
                                  color: selected == tab
                                      ? colors.pathActive
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
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
                            border: Border(
                              left: BorderSide(
                                color: selected == tab
                                    ? colors.pathActive
                                    : Colors.transparent,
                                width: 4,
                              ),
                              top: BorderSide(
                                color: selected == tab
                                    ? colors.border
                                    : Colors.transparent,
                              ),
                              right: BorderSide(
                                color: selected == tab
                                    ? colors.border
                                    : Colors.transparent,
                              ),
                              bottom: BorderSide(
                                color: selected == tab
                                    ? colors.border
                                    : Colors.transparent,
                              ),
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
    schoolMode && tab == GameTab.league
    ? t('この端末の共同観測', "This device's class goal")
    : tab.semanticsLabel;

String _shortLabel(GameTab tab, {required bool schoolMode}) =>
    schoolMode && tab == GameTab.league ? t('共同', 'Together') : tab.shortLabel;

IconData _iconFor(
  GameTab tab, {
  required bool selected,
  required bool schoolMode,
}) => schoolMode && tab == GameTab.league
    ? Icons.groups_rounded
    : selected
    ? tab.selectedIcon
    : tab.icon;
