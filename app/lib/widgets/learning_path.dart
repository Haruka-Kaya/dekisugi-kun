import 'dart:math' as math;

import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../config/motion.dart';
import '../learning/domain/learning_economy.dart';
import '../models/game_path.dart';
import '../ui/_material.dart';
import 'dekisugi_character_art.dart';

typedef GamePathNodeCallback = void Function(GamePathNode node);
typedef GamePathUnitCallback = void Function(GamePathUnit unit);

/// 単元・復習・物語・高難度課題を、連続する探究ログとして描く。
///
/// 表示専用DTOだけを受け取る。どのログを解放するか、完了と認めるかは
/// 呼び出し側の学習ロジックが決める。
class LearningPath extends StatefulWidget {
  const LearningPath({
    super.key,
    required this.units,
    this.currentNodeId,
    this.controller,
    this.onNodeStart,
    this.onGuidebookOpen,
    this.bottomPadding = GameTokens.spaceXxl,
    this.mascotStyle = LearningPathMascotStyle.standard,
  });

  final List<GamePathUnit> units;
  final String? currentNodeId;
  final ScrollController? controller;
  final GamePathNodeCallback? onNodeStart;
  final GamePathUnitCallback? onGuidebookOpen;
  final double bottomPadding;
  final LearningPathMascotStyle mascotStyle;

  @override
  State<LearningPath> createState() => _LearningPathState();
}

class _LearningPathState extends State<LearningPath> {
  GlobalKey _currentNodeKey = GlobalKey(debugLabel: 'game-path-current-node');
  String? _scheduledCurrentNodeId;

  @override
  void didUpdateWidget(covariant LearningPath oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentNodeId != widget.currentNodeId) {
      _currentNodeKey = GlobalKey(debugLabel: 'game-path-current-node');
      _scheduledCurrentNodeId = null;
    }
  }

  void _scheduleCurrentNodeReveal() {
    final currentNodeId = widget.currentNodeId;
    if (currentNodeId == null || _scheduledCurrentNodeId == currentNodeId) {
      return;
    }
    _scheduledCurrentNodeId = currentNodeId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || widget.currentNodeId != currentNodeId) return;
      final targetContext = _currentNodeKey.currentContext;
      if (targetContext == null) {
        _scheduledCurrentNodeId = null;
        return;
      }
      await Scrollable.ensureVisible(
        targetContext,
        alignment: 0.42,
        duration: ReduceMotionScope.of(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    _scheduleCurrentNodeReveal();
    final width = math.min(
      MediaQuery.sizeOf(context).width,
      GameTokens.readablePathWidth,
    );
    if (widget.units.isEmpty) {
      return _EmptyPath(width: width, mascotStyle: widget.mascotStyle);
    }

    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: width,
        child: SingleChildScrollView(
          key: const PageStorageKey<String>('game-learning-path'),
          controller: widget.controller,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final unit in widget.units)
                _PathUnitSection(
                  unit: unit,
                  currentNodeId: widget.currentNodeId,
                  currentNodeKey: _currentNodeKey,
                  onNodeStart: widget.onNodeStart,
                  onGuidebookOpen: widget.onGuidebookOpen,
                  mascotStyle: widget.mascotStyle,
                ),
              SizedBox(height: widget.bottomPadding),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPath extends StatelessWidget {
  const _EmptyPath({required this.width, required this.mascotStyle});

  final double width;
  final LearningPathMascotStyle mascotStyle;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: width,
        child: ListView(
          padding: const EdgeInsets.all(GameTokens.spaceXl),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: PathMascotPreview(
                reaction: GameCharacterReaction.invite,
                size: 84,
                style: mascotStyle,
              ),
            ),
            const SizedBox(height: GameTokens.spaceLg),
            Text(
              '探究ノートを準備しています',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(color: colors.ink)
                  .jaWeight(FontWeight.w800),
            ),
            const SizedBox(height: GameTokens.spaceSm),
            Text(
              '教材を読み込めると、ここに次の観察記録が現れます。',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: colors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _PathUnitSection extends StatelessWidget {
  const _PathUnitSection({
    required this.unit,
    required this.currentNodeId,
    required this.currentNodeKey,
    required this.onNodeStart,
    required this.onGuidebookOpen,
    required this.mascotStyle,
  });

  final GamePathUnit unit;
  final String? currentNodeId;
  final GlobalKey currentNodeKey;
  final GamePathNodeCallback? onNodeStart;
  final GamePathUnitCallback? onGuidebookOpen;
  final LearningPathMascotStyle mascotStyle;

  @override
  Widget build(BuildContext context) => Column(
    key: ValueKey<String>('game-path-unit-${unit.id}'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(
          GameTokens.spaceMd,
          GameTokens.spaceMd,
          GameTokens.spaceMd,
          0,
        ),
        child: _UnitBanner(
          unit: unit,
          onGuidebookOpen:
              unit.guidebookTitle != null && onGuidebookOpen != null
              ? () => onGuidebookOpen!(unit)
              : null,
          mascotStyle: mascotStyle,
        ),
      ),
      if (unit.nodes.isEmpty)
        const SizedBox(height: GameTokens.spaceXl)
      else
        _InquiryTimeline(
          nodes: unit.nodes,
          currentNodeId: currentNodeId,
          currentNodeKey: currentNodeKey,
          onNodeStart: onNodeStart,
        ),
    ],
  );
}

class _UnitBanner extends StatelessWidget {
  const _UnitBanner({
    required this.unit,
    required this.onGuidebookOpen,
    required this.mascotStyle,
  });

  final GamePathUnit unit;
  final VoidCallback? onGuidebookOpen;
  final LearningPathMascotStyle mascotStyle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    final progressLabel = '${unit.totalSteps}個中${unit.completedSteps}個完了';

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label:
          'ユニット${unit.ordinal}、${unit.title}。${unit.objective}。$progressLabel',
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(GameTokens.radiusSm),
          border: Border.all(color: colors.border),
        ),
        padding: const EdgeInsets.fromLTRB(
          GameTokens.spaceLg,
          GameTokens.spaceLg,
          GameTokens.spaceMd,
          GameTokens.spaceLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '研究テーマ ${unit.ordinal.toString().padLeft(2, '0')}',
                        style: t.textTheme.labelLarge
                            ?.copyWith(color: colors.pathActive)
                            .jaWeight(FontWeight.w800),
                      ),
                      const SizedBox(height: GameTokens.spaceXs),
                      Text(
                        unit.title,
                        style: t.textTheme.headlineSmall
                            ?.copyWith(color: colors.ink, height: 1.35)
                            .jaWeight(FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                if (onGuidebookOpen != null) ...[
                  const SizedBox(width: GameTokens.spaceSm),
                  Semantics(
                    label: '${unit.guidebookTitle}を開く',
                    button: true,
                    child: IconButton(
                      key: ValueKey<String>('unit-guidebook-${unit.id}'),
                      tooltip: unit.guidebookTitle,
                      onPressed: onGuidebookOpen,
                      style: IconButton.styleFrom(
                        minimumSize: const Size.square(
                          GameTokens.minTouchTarget,
                        ),
                        backgroundColor: colors.surfaceRaised,
                        foregroundColor: colors.pathActive,
                      ),
                      icon: const Icon(Icons.menu_book_rounded),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: GameTokens.spaceSm),
            Text(
              unit.objective,
              style: t.textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
            ),
            const SizedBox(height: GameTokens.spaceMd),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    label: 'ユニットの進み、$progressLabel',
                    child: ExcludeSemantics(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          GameTokens.radiusPill,
                        ),
                        child: LinearProgressIndicator(
                          value: unit.progress,
                          minHeight: 8,
                          color: colors.pathActive,
                          backgroundColor: colors.border,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: GameTokens.spaceMd),
                Text(
                  '${unit.completedSteps}/${unit.totalSteps}',
                  style: t.textTheme.labelLarge
                      ?.copyWith(color: colors.ink)
                      .jaWeight(FontWeight.w800),
                ),
              ],
            ),
            if (unit.characterReaction != GameCharacterReaction.none &&
                unit.characterMessage != null) ...[
              const SizedBox(height: GameTokens.spaceLg),
              _CharacterReaction(
                reaction: unit.characterReaction,
                message: unit.characterMessage!,
                mascotStyle: mascotStyle,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CharacterReaction extends StatelessWidget {
  const _CharacterReaction({
    required this.reaction,
    required this.message,
    required this.mascotStyle,
  });

  final GameCharacterReaction reaction;
  final String message;
  final LearningPathMascotStyle mascotStyle;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Semantics(
      container: true,
      label: '${mascotStyle.label}。$message',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            PathMascotPreview(reaction: reaction, size: 58, style: mascotStyle),
            const SizedBox(width: GameTokens.spaceSm),
            Expanded(
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(GameTokens.radiusMd),
                ),
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.ink)
                      .jaWeight(FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pathと結晶交換面で共有する、静止したマスコットのプレビュー。
///
/// 会話画面の音声状態とは別物なので、LiveSessionやTickerへ接続しない。反応は
/// 目・アンテナ・記号の形で示し、Reduce Motionでも情報量が変わらない。
/// styleは見た目だけを変え、学習nodeや正答状態を受け取らない。
class PathMascotPreview extends StatelessWidget {
  const PathMascotPreview({
    super.key,
    required this.reaction,
    required this.size,
    required this.style,
  });

  final GameCharacterReaction reaction;
  final double size;
  final LearningPathMascotStyle style;

  @override
  Widget build(BuildContext context) {
    final gameColors = context.gamePalette;
    final characterColors = context.appColors;
    final (decoration, ornament, ornamentSignal) = switch (style) {
      LearningPathMascotStyle.standard => (
        DekisugiCharacterDecoration.standard,
        characterColors.charAccent,
        characterColors.onCoolSurface,
      ),
      LearningPathMascotStyle.orbit => (
        DekisugiCharacterDecoration.orbit,
        gameColors.pathReview,
        gameColors.story,
      ),
      LearningPathMascotStyle.nova => (
        DekisugiCharacterDecoration.nova,
        gameColors.legendary,
        gameColors.onLegendary,
      ),
    };
    return Semantics(
      container: true,
      image: true,
      label: '${style.label}、${reaction.semanticsLabel}',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: DekisugiCharacterArt(
            pose: switch (reaction) {
              GameCharacterReaction.none => DekisugiCharacterPose.idle,
              GameCharacterReaction.invite => DekisugiCharacterPose.invite,
              GameCharacterReaction.listening =>
                DekisugiCharacterPose.listening,
              GameCharacterReaction.thinking => DekisugiCharacterPose.thinking,
              GameCharacterReaction.encourage =>
                DekisugiCharacterPose.encourage,
              GameCharacterReaction.speaking => DekisugiCharacterPose.speaking,
              GameCharacterReaction.celebrate =>
                DekisugiCharacterPose.celebrate,
              GameCharacterReaction.outOfTime =>
                DekisugiCharacterPose.outOfTime,
              GameCharacterReaction.retry => DekisugiCharacterPose.retry,
            },
            decoration: decoration,
            size: size,
            body: characterColors.charBody,
            face: characterColors.charFace,
            accent: characterColors.charAccent,
            signal: characterColors.onCoolSurface,
            ornament: ornament,
            ornamentSignal: ornamentSignal,
            paintKey: ValueKey<String>('path-mascot-${style.wire}'),
          ),
        ),
      ),
    );
  }
}

/// 左の実験レールと、横長の探究ログで学びの連続を示す。
///
/// 各ログの高さは内容と文字サイズに追従する。固定高の画布に配置しないため、
/// 320dp・文字200%でもログ本文と状態ラベルを省略しない。
class _InquiryTimeline extends StatelessWidget {
  const _InquiryTimeline({
    required this.nodes,
    required this.currentNodeId,
    required this.currentNodeKey,
    required this.onNodeStart,
  });

  final List<GamePathNode> nodes;
  final String? currentNodeId;
  final GlobalKey currentNodeKey;
  final GamePathNodeCallback? onNodeStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        GameTokens.spaceMd,
        GameTokens.spaceLg,
        GameTokens.spaceMd,
        GameTokens.spaceXl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            label: '実験レールと探究ログ',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  const SizedBox(
                    width: 52,
                    child: Icon(Icons.straighten_rounded, size: 20),
                  ),
                  const SizedBox(width: GameTokens.spaceSm),
                  Text(
                    '探究ログ',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(color: context.gamePalette.ink)
                        .jaWeight(FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: GameTokens.spaceSm),
          for (var index = 0; index < nodes.length; index++)
            _InquiryLogRow(
              node: nodes[index],
              index: index,
              first: index == 0,
              last: index == nodes.length - 1,
              current: nodes[index].id == currentNodeId,
              currentNodeKey: currentNodeKey,
              onOpen: nodes[index].canOpen
                  ? () => _showNodeSheet(
                      context,
                      node: nodes[index],
                      onStart: onNodeStart,
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

class _InquiryLogRow extends StatelessWidget {
  const _InquiryLogRow({
    required this.node,
    required this.index,
    required this.first,
    required this.last,
    required this.current,
    required this.currentNodeKey,
    required this.onOpen,
  });

  final GamePathNode node;
  final int index;
  final bool first;
  final bool last;
  final bool current;
  final GlobalKey currentNodeKey;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 52,
          child: _ExperimentRail(
            node: node,
            index: index,
            first: first,
            last: last,
            current: current,
          ),
        ),
        const SizedBox(width: GameTokens.spaceSm),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: last ? 0 : GameTokens.spaceMd),
            child: _PathNodeButton(
              key: current ? currentNodeKey : null,
              node: node,
              current: current,
              onOpen: onOpen,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ExperimentRail extends StatelessWidget {
  const _ExperimentRail({
    required this.node,
    required this.index,
    required this.first,
    required this.last,
    required this.current,
  });

  final GamePathNode node;
  final int index;
  final bool first;
  final bool last;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final style = _nodeStyle(node, colors);
    final reduceMotion = ReduceMotionScope.of(context);
    final lineColor = switch (node.state) {
      GamePathNodeState.completed ||
      GamePathNodeState.legendaryCompleted => colors.pathComplete,
      _ => colors.border,
    };

    return Semantics(
      container: true,
      label: '実験レール${index + 1}、${current ? '現在位置、' : ''}${_nodeBadge(node)}',
      child: ExcludeSemantics(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            if (!first)
              Positioned(
                top: 0,
                width: 2,
                height: 14,
                child: ColoredBox(color: lineColor),
              ),
            if (!last)
              Positioned(
                top: 48,
                bottom: 0,
                width: 2,
                child: ColoredBox(color: lineColor),
              ),
            Positioned(
              top: 12,
              child: AnimatedContainer(
                key: ValueKey<String>(
                  current
                      ? 'game-path-current-ring-${node.id}'
                      : 'game-experiment-marker-${node.id}',
                ),
                duration: reduceMotion ? Duration.zero : Motion.quick,
                curve: Motion.quickCurve,
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: style.accent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: current ? colors.pathActive : style.border,
                    width: current ? 3 : 1,
                  ),
                ),
                child: Text(
                  '${index + 1}'.padLeft(2, '0'),
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: style.onAccent, height: 1)
                      .jaWeight(FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NodeVisualStyle {
  const _NodeVisualStyle({
    required this.fill,
    required this.foreground,
    required this.border,
    required this.accent,
    required this.onAccent,
  });

  final Color fill;
  final Color foreground;
  final Color border;
  final Color accent;
  final Color onAccent;
}

_NodeVisualStyle _nodeStyle(GamePathNode node, GamePalette colors) {
  final kindColor = switch (node.kind) {
    GamePathNodeKind.story => colors.story,
    GamePathNodeKind.practice => colors.pathReview,
    GamePathNodeKind.legendary => colors.legendary,
    _ => colors.pathActive,
  };
  final onKind = switch (node.kind) {
    GamePathNodeKind.story => colors.onStory,
    GamePathNodeKind.practice => colors.onPathReview,
    GamePathNodeKind.legendary => colors.onLegendary,
    _ => colors.onPathActive,
  };

  return switch (node.state) {
    GamePathNodeState.locked => _NodeVisualStyle(
      fill: colors.surfaceRaised,
      foreground: colors.onPathLocked,
      border: colors.border,
      accent: colors.pathLocked,
      onAccent: colors.onPathLocked,
    ),
    GamePathNodeState.available => _NodeVisualStyle(
      fill: colors.surface,
      foreground: colors.ink,
      border: kindColor,
      accent: kindColor,
      onAccent: onKind,
    ),
    GamePathNodeState.inProgress => _NodeVisualStyle(
      fill: colors.surface,
      foreground: colors.ink,
      border: kindColor,
      accent: kindColor,
      onAccent: onKind,
    ),
    GamePathNodeState.completed => _NodeVisualStyle(
      fill: colors.surface,
      foreground: colors.ink,
      border: colors.pathComplete,
      accent: colors.pathComplete,
      onAccent: colors.onPathComplete,
    ),
    GamePathNodeState.reviewDue => _NodeVisualStyle(
      fill: colors.surface,
      foreground: colors.ink,
      border: colors.pathReview,
      accent: colors.pathReview,
      onAccent: colors.onPathReview,
    ),
    GamePathNodeState.legendaryAvailable ||
    GamePathNodeState.legendaryCompleted => _NodeVisualStyle(
      fill: colors.surface,
      foreground: colors.ink,
      border: colors.legendary,
      accent: colors.legendary,
      onAccent: colors.onLegendary,
    ),
  };
}

class _PathNodeButton extends StatelessWidget {
  const _PathNodeButton({
    super.key,
    required this.node,
    required this.current,
    required this.onOpen,
  });

  final GamePathNode node;
  final bool current;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final style = _nodeStyle(node, colors);
    final reduceMotion = ReduceMotionScope.of(context);
    final progress = node.state == GamePathNodeState.inProgress
        ? node.progress
        : null;
    final semantic = _nodeSemanticLabel(node, current: current);

    return Semantics(
      key: ValueKey<String>('game-path-node-${node.id}'),
      container: true,
      button: onOpen != null,
      enabled: onOpen != null,
      label: semantic,
      onTap: onOpen,
      child: ExcludeSemantics(
        child: Tooltip(
          message: node.title,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(GameTokens.radiusSm),
              child: AnimatedContainer(
                key: ValueKey<String>('game-inquiry-log-${node.id}'),
                duration: reduceMotion ? Duration.zero : Motion.quick,
                curve: Motion.quickCurve,
                constraints: const BoxConstraints(
                  minHeight: GameTokens.pathNodeHitSize,
                ),
                decoration: BoxDecoration(
                  color: style.fill,
                  borderRadius: BorderRadius.circular(GameTokens.radiusSm),
                  border: Border.all(
                    color: current ? colors.pathActive : style.border,
                    width: current ? 3 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      bottom: 0,
                      left: 0,
                      width: 6,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: style.accent,
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(GameTokens.radiusSm - 1),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        GameTokens.spaceLg + 4,
                        GameTokens.spaceMd,
                        GameTokens.spaceLg,
                        GameTokens.spaceMd,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: GameTokens.spaceSm,
                            runSpacing: GameTokens.spaceXs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _LogLabel(
                                icon: _nodeIcon(node),
                                label: _kindLabel(node.kind),
                                foreground: style.foreground,
                                background: colors.surfaceRaised,
                                border: style.border,
                              ),
                              _LogLabel(
                                label: current ? '次はここ' : _nodeBadge(node),
                                foreground: current
                                    ? colors.onPathActive
                                    : style.foreground,
                                background: current
                                    ? colors.pathActive
                                    : colors.surface,
                                border: current
                                    ? colors.pathActive
                                    : style.border,
                              ),
                            ],
                          ),
                          const SizedBox(height: GameTokens.spaceSm),
                          Text(
                            node.title,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: style.foreground,
                                  height: 1.35,
                                )
                                .jaWeight(FontWeight.w800),
                          ),
                          const SizedBox(height: GameTokens.spaceXs),
                          Text(
                            node.description,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colors.inkMuted),
                          ),
                          if (node.estimatedMinutes != null) ...[
                            const SizedBox(height: GameTokens.spaceSm),
                            Text(
                              '観察目安 ${node.estimatedMinutes}分',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: colors.inkMuted)
                                  .jaWeight(FontWeight.w700),
                            ),
                          ],
                          if (progress != null) ...[
                            const SizedBox(height: GameTokens.spaceMd),
                            Text(
                              '探究記録 ${node.completedLessons}/${node.totalLessons}',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: colors.ink)
                                  .jaWeight(FontWeight.w700),
                            ),
                            const SizedBox(height: GameTokens.spaceXs),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 6,
                                color: style.accent,
                                backgroundColor: colors.border,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogLabel extends StatelessWidget {
  const _LogLabel({
    required this.label,
    required this.foreground,
    required this.background,
    required this.border,
    this.icon,
  });

  final String label;
  final Color foreground;
  final Color background;
  final Color border;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 28),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: GameTokens.spaceXs),
        ],
        Flexible(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: foreground, height: 1.2)
                .jaWeight(FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

IconData _nodeIcon(GamePathNode node) => switch (node.state) {
  GamePathNodeState.locked => Icons.lock_rounded,
  GamePathNodeState.completed => Icons.check_rounded,
  GamePathNodeState.reviewDue => Icons.replay_rounded,
  GamePathNodeState.legendaryAvailable ||
  GamePathNodeState.legendaryCompleted => Icons.fact_check_rounded,
  _ => switch (node.kind) {
    GamePathNodeKind.lesson => Icons.science_rounded,
    GamePathNodeKind.story => Icons.menu_book_rounded,
    GamePathNodeKind.listening => Icons.headphones_rounded,
    GamePathNodeKind.speaking => Icons.mic_rounded,
    GamePathNodeKind.practice => Icons.fitness_center_rounded,
    GamePathNodeKind.challenge => Icons.assignment_turned_in_rounded,
    GamePathNodeKind.legendary => Icons.fact_check_rounded,
  },
};

String _nodeBadge(GamePathNode node) => switch (node.state) {
  GamePathNodeState.locked => '未解放',
  GamePathNodeState.available => '次',
  GamePathNodeState.inProgress =>
    '${node.completedLessons}/${node.totalLessons}',
  GamePathNodeState.completed => '完了',
  GamePathNodeState.reviewDue => '復習',
  GamePathNodeState.legendaryAvailable => '高難度',
  GamePathNodeState.legendaryCompleted => '高難度 完了',
};

String _kindLabel(GamePathNodeKind kind) => switch (kind) {
  GamePathNodeKind.lesson => '教材観察',
  GamePathNodeKind.story => '理科事件簿',
  GamePathNodeKind.listening => '聞き取り観察',
  GamePathNodeKind.speaking => '教え返し',
  GamePathNodeKind.practice => '再観察',
  GamePathNodeKind.challenge => '総合検証',
  GamePathNodeKind.legendary => '高難度検証',
};

String _stateLabel(GamePathNode node) => switch (node.state) {
  GamePathNodeState.locked => '未解放。前の観察記録を終えると開きます',
  GamePathNodeState.available => '次に進めます',
  GamePathNodeState.inProgress =>
    '${node.totalLessons}回中${node.completedLessons}回完了。続きから進めます',
  GamePathNodeState.completed => '完了。もう一度取り組めます',
  GamePathNodeState.reviewDue => '復習する時期です',
  GamePathNodeState.legendaryAvailable => '高難度課題に挑戦できます',
  GamePathNodeState.legendaryCompleted => '高難度課題を完了。もう一度取り組めます',
};

String _nodeSemanticLabel(GamePathNode node, {required bool current}) =>
    '${_kindLabel(node.kind)}「${node.title}」。'
    '${current ? '現在位置。' : ''}'
    '${_stateLabel(node)}。'
    '${node.canOpen ? 'タップして詳細を開きます' : ''}';

Future<void> _showNodeSheet(
  BuildContext context, {
  required GamePathNode node,
  required GamePathNodeCallback? onStart,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: context.gamePalette.surface,
  constraints: const BoxConstraints(maxWidth: 640),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(GameTokens.radiusSheet),
    ),
  ),
  builder: (sheetContext) {
    final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.88;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: _NodeDetailSheet(
        node: node,
        onStart: onStart == null
            ? null
            : () {
                Navigator.of(sheetContext).pop();
                onStart(node);
              },
      ),
    );
  },
);

class _NodeDetailSheet extends StatelessWidget {
  const _NodeDetailSheet({required this.node, required this.onStart});

  final GamePathNode node;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    final style = _nodeStyle(node, colors);

    return Semantics(
      container: true,
      namesRoute: true,
      label: '${node.title}の詳細',
      child: SingleChildScrollView(
        key: const ValueKey('game-node-sheet'),
        padding: EdgeInsets.fromLTRB(
          GameTokens.spaceXl,
          0,
          GameTokens.spaceXl,
          GameTokens.spaceXl + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: GameTokens.spaceSm,
                    runSpacing: GameTokens.spaceSm,
                    children: [
                      _SheetPill(
                        label: _kindLabel(node.kind),
                        foreground: style.foreground,
                        background: style.fill,
                        border: style.border,
                      ),
                      _SheetPill(
                        label: _nodeBadge(node),
                        foreground: colors.ink,
                        background: colors.surfaceRaised,
                        border: colors.border,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: GameTokens.spaceSm),
                IconButton(
                  key: const ValueKey('game-node-sheet-close'),
                  tooltip: '閉じる',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: GameTokens.spaceMd),
            Text(
              node.title,
              style: t.textTheme.headlineMedium
                  ?.copyWith(color: colors.ink, height: 1.35)
                  .jaWeight(FontWeight.w800),
            ),
            const SizedBox(height: GameTokens.spaceSm),
            Text(
              node.description,
              style: t.textTheme.bodyLarge?.copyWith(color: colors.inkMuted),
            ),
            if (node.estimatedMinutes != null) ...[
              const SizedBox(height: GameTokens.spaceMd),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 20,
                    color: colors.inkMuted,
                  ),
                  const SizedBox(width: GameTokens.spaceSm),
                  Expanded(
                    child: Text(
                      '目安 ${node.estimatedMinutes}分',
                      style: t.textTheme.bodyMedium?.copyWith(
                        color: colors.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (node.learningActions.isNotEmpty) ...[
              const SizedBox(height: GameTokens.spaceXl),
              Text(
                'この観察でやること',
                style: t.textTheme.titleMedium
                    ?.copyWith(color: colors.ink)
                    .jaWeight(FontWeight.w800),
              ),
              const SizedBox(height: GameTokens.spaceMd),
              for (final action in node.learningActions) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.science_outlined,
                      size: 21,
                      color: colors.pathActive,
                    ),
                    const SizedBox(width: GameTokens.spaceSm),
                    Expanded(
                      child: Text(
                        action,
                        style: t.textTheme.bodyMedium?.copyWith(
                          color: colors.ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: GameTokens.spaceSm),
              ],
            ],
            if (node.rewardLabel != null) ...[
              const SizedBox(height: GameTokens.spaceMd),
              Text(
                '完了時 ${node.rewardLabel}',
                style: t.textTheme.labelLarge
                    ?.copyWith(color: colors.inkMuted)
                    .jaWeight(FontWeight.w700),
              ),
            ],
            if (onStart != null) ...[
              const SizedBox(height: GameTokens.spaceXl),
              FilledButton(
                key: const ValueKey('game-node-sheet-start'),
                onPressed: onStart,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: colors.pathActive,
                  foregroundColor: colors.onPathActive,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(GameTokens.radiusMd),
                  ),
                ),
                child: Text(switch (node.state) {
                  GamePathNodeState.completed ||
                  GamePathNodeState.legendaryCompleted => 'もう一度やる',
                  GamePathNodeState.inProgress => '続きから進める',
                  GamePathNodeState.reviewDue => '復習をはじめる',
                  GamePathNodeState.legendaryAvailable => '高難度に挑戦',
                  _ => '観察を始める',
                }, textAlign: TextAlign.center),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SheetPill extends StatelessWidget {
  const _SheetPill({
    required this.label,
    required this.foreground,
    required this.background,
    required this.border,
  });

  final String label;
  final Color foreground;
  final Color background;
  final Color border;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(GameTokens.radiusPill),
      border: Border.all(color: border),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelMedium
          ?.copyWith(color: foreground)
          .jaWeight(FontWeight.w700),
    ),
  );
}
