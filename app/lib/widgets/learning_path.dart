import 'dart:math' as math;

import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../config/motion.dart';
import '../learning/domain/learning_economy.dart';
import '../models/game_path.dart';
import '../ui/_material.dart';

typedef GamePathNodeCallback = void Function(GamePathNode node);
typedef GamePathUnitCallback = void Function(GamePathUnit unit);

/// 単元・復習・物語・高難度課題を、前へ進む一本のPathとして描く。
///
/// Pathは表示専用DTOだけを受け取る。どのノードを解放するか、完了と認めるかは
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
              '学習パスを準備しています',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(color: colors.ink)
                  .jaWeight(FontWeight.w800),
            ),
            const SizedBox(height: GameTokens.spaceSm),
            Text(
              '教材を読み込めると、ここに次の一歩が現れます。',
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
        _NodeCanvas(
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
          color: colors.pathActive,
          borderRadius: BorderRadius.circular(GameTokens.radiusLg),
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
                        'UNIT ${unit.ordinal.toString().padLeft(2, '0')}',
                        style: t.textTheme.labelLarge
                            ?.copyWith(color: colors.onPathActive)
                            .jaWeight(FontWeight.w800),
                      ),
                      const SizedBox(height: GameTokens.spaceXs),
                      Text(
                        unit.title,
                        style: t.textTheme.headlineSmall
                            ?.copyWith(color: colors.onPathActive, height: 1.35)
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
                        backgroundColor: colors.surface,
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
              style: t.textTheme.bodyMedium?.copyWith(
                color: colors.onPathActive,
              ),
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
                          color: colors.surface,
                          backgroundColor: colors.onPathActive.withValues(
                            alpha: 0.28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: GameTokens.spaceMd),
                Text(
                  '${unit.completedSteps}/${unit.totalSteps}',
                  style: t.textTheme.labelLarge
                      ?.copyWith(color: colors.onPathActive)
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
    final colors = context.gamePalette;
    final (body, face, accent, signal) = switch (style) {
      LearningPathMascotStyle.standard => (
        colors.story,
        colors.onStory,
        colors.legendary,
        colors.pathReview,
      ),
      LearningPathMascotStyle.orbit => (
        colors.pathReview,
        colors.onPathReview,
        colors.legendary,
        colors.story,
      ),
      LearningPathMascotStyle.nova => (
        colors.story,
        colors.onStory,
        colors.legendary,
        colors.pathActive,
      ),
    };
    return Semantics(
      container: true,
      image: true,
      label: '${style.label}、${reaction.semanticsLabel}',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: CustomPaint(
            key: ValueKey<String>('path-mascot-${style.wire}'),
            painter: _PathMascotPainter(
              reaction: reaction,
              style: style,
              body: body,
              face: face,
              accent: accent,
              signal: signal,
            ),
          ),
        ),
      ),
    );
  }
}

class _PathMascotPainter extends CustomPainter {
  const _PathMascotPainter({
    required this.reaction,
    required this.style,
    required this.body,
    required this.face,
    required this.accent,
    required this.signal,
  });

  final GameCharacterReaction reaction;
  final LearningPathMascotStyle style;
  final Color body;
  final Color face;
  final Color accent;
  final Color signal;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(w * 0.5, w * 0.43);
    final radius = w * 0.27;
    final bodyPaint = Paint()..color = body;

    // 表情だけでなくシルエットでも感情を区別する。小さい表示や
    // 色覚に依存しない状態でも、手招き・思案・応援・祝福が残る。
    final armPaint = Paint()
      ..color = body
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.085
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    switch (reaction) {
      case GameCharacterReaction.invite:
        canvas.drawPath(
          Path()
            ..moveTo(w * 0.72, w * 0.66)
            ..lineTo(w * 0.86, w * 0.49)
            ..lineTo(w * 0.80, w * 0.36),
          armPaint,
        );
        break;
      case GameCharacterReaction.thinking:
        canvas.drawLine(
          Offset(w * 0.70, w * 0.68),
          Offset(w * 0.68, w * 0.48),
          armPaint,
        );
        break;
      case GameCharacterReaction.encourage:
        canvas.drawLine(
          Offset(w * 0.30, w * 0.67),
          Offset(w * 0.13, w * 0.55),
          armPaint,
        );
        canvas.drawLine(
          Offset(w * 0.70, w * 0.67),
          Offset(w * 0.87, w * 0.55),
          armPaint,
        );
        break;
      case GameCharacterReaction.celebrate:
        canvas.drawLine(
          Offset(w * 0.30, w * 0.66),
          Offset(w * 0.15, w * 0.31),
          armPaint,
        );
        canvas.drawLine(
          Offset(w * 0.70, w * 0.66),
          Offset(w * 0.85, w * 0.31),
          armPaint,
        );
        break;
      case GameCharacterReaction.none:
        break;
    }

    if (style == LearningPathMascotStyle.orbit) {
      canvas.save();
      canvas.translate(w * 0.5, w * 0.46);
      canvas.rotate(-0.28);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: w * 0.88, height: w * 0.38),
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.045,
      );
      canvas.drawCircle(
        Offset(w * 0.39, 0),
        w * 0.065,
        Paint()..color = signal,
      );
      canvas.restore();
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(w * 0.5, w * 0.76),
          width: w * 0.58,
          height: w * 0.28,
        ),
        Radius.circular(w * 0.12),
      ),
      bodyPaint,
    );
    canvas.drawCircle(center, radius, bodyPaint);

    if (style == LearningPathMascotStyle.nova) {
      final starCenter = Offset(w * 0.5, w * 0.75);
      final star = Path();
      for (var index = 0; index < 10; index++) {
        final angle = -math.pi / 2 + index * math.pi / 5;
        final distance = index.isEven ? w * 0.095 : w * 0.042;
        final point = Offset(
          starCenter.dx + math.cos(angle) * distance,
          starCenter.dy + math.sin(angle) * distance,
        );
        if (index == 0) {
          star.moveTo(point.dx, point.dy);
        } else {
          star.lineTo(point.dx, point.dy);
        }
      }
      star.close();
      canvas.drawPath(star, Paint()..color = accent);
    }

    final antenna = Paint()
      ..color = body
      ..strokeWidth = w * 0.065
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.59, w * 0.18),
      Offset(w * 0.64, w * 0.05),
      antenna,
    );
    canvas.drawCircle(
      Offset(w * 0.65, w * 0.04),
      w * 0.075,
      Paint()..color = accent,
    );

    final eyePaint = Paint()..color = face;
    for (final side in <double>[-1, 1]) {
      final eyeCenter = Offset(
        center.dx + side * radius * 0.42,
        center.dy - radius * 0.06,
      );
      if (reaction == GameCharacterReaction.celebrate) {
        canvas.drawArc(
          Rect.fromCircle(center: eyeCenter, radius: radius * 0.18),
          math.pi * 0.08,
          math.pi * 0.84,
          false,
          Paint()
            ..color = face
            ..style = PaintingStyle.stroke
            ..strokeWidth = radius * 0.11
            ..strokeCap = StrokeCap.round,
        );
      } else {
        canvas.drawCircle(eyeCenter, radius * 0.17, eyePaint);
        if (reaction == GameCharacterReaction.thinking) {
          canvas.drawCircle(
            Offset(eyeCenter.dx + radius * 0.05, eyeCenter.dy - radius * 0.05),
            radius * 0.055,
            Paint()..color = body,
          );
        }
      }
    }

    final mouthPaint = Paint()
      ..color = face
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.11
      ..strokeCap = StrokeCap.round;
    if (reaction == GameCharacterReaction.invite ||
        reaction == GameCharacterReaction.encourage ||
        reaction == GameCharacterReaction.celebrate) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(w * 0.5, w * 0.50),
          width: radius * 0.78,
          height: radius * 0.55,
        ),
        0.12 * math.pi,
        0.76 * math.pi,
        false,
        mouthPaint,
      );
    } else if (reaction == GameCharacterReaction.thinking) {
      canvas.drawLine(
        Offset(w * 0.44, w * 0.53),
        Offset(w * 0.56, w * 0.51),
        mouthPaint,
      );
    } else {
      canvas.drawLine(
        Offset(w * 0.45, w * 0.52),
        Offset(w * 0.55, w * 0.52),
        mouthPaint,
      );
    }

    if (reaction == GameCharacterReaction.thinking) {
      for (var index = 0; index < 3; index++) {
        canvas.drawCircle(
          Offset(w * (0.16 + index * 0.1), w * (0.13 - index * 0.025)),
          w * (0.025 + index * 0.006),
          Paint()..color = signal,
        );
      }
    }
    if (reaction == GameCharacterReaction.encourage ||
        reaction == GameCharacterReaction.celebrate) {
      final badgeCenter = Offset(w * 0.78, w * 0.72);
      canvas.drawCircle(badgeCenter, w * 0.12, Paint()..color = accent);
      final check = Paint()
        ..color = signal
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.045
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(
        Path()
          ..moveTo(w * 0.72, w * 0.72)
          ..lineTo(w * 0.77, w * 0.77)
          ..lineTo(w * 0.85, w * 0.66),
        check,
      );
    }
    if (reaction == GameCharacterReaction.celebrate) {
      final rayPaint = Paint()
        ..color = signal
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035
        ..strokeCap = StrokeCap.round;
      for (final ray in <(Offset, Offset)>[
        (Offset(w * 0.17, w * 0.17), Offset(w * 0.10, w * 0.10)),
        (Offset(w * 0.50, w * 0.07), Offset(w * 0.50, 0)),
        (Offset(w * 0.83, w * 0.17), Offset(w * 0.90, w * 0.10)),
      ]) {
        canvas.drawLine(ray.$1, ray.$2, rayPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PathMascotPainter oldDelegate) =>
      oldDelegate.reaction != reaction ||
      oldDelegate.style != style ||
      oldDelegate.body != body ||
      oldDelegate.face != face ||
      oldDelegate.accent != accent ||
      oldDelegate.signal != signal;
}

class _NodeCanvas extends StatelessWidget {
  const _NodeCanvas({
    required this.nodes,
    required this.currentNodeId,
    required this.currentNodeKey,
    required this.onNodeStart,
  });

  static const _horizontalPattern = <double>[
    -0.05,
    0.72,
    0.34,
    -0.38,
    -0.72,
    -0.18,
    0.54,
  ];

  final List<GamePathNode> nodes;
  final String? currentNodeId;
  final GlobalKey currentNodeKey;
  final GamePathNodeCallback? onNodeStart;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final height = nodes.length * GameTokens.pathRowHeight;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final halfTravel = math.max(
            0.0,
            constraints.maxWidth / 2 - GameTokens.pathNodeHitSize / 2 - 8,
          );
          final centers = <Offset>[
            for (var index = 0; index < nodes.length; index++)
              Offset(
                constraints.maxWidth / 2 +
                    _horizontalPattern[index % _horizontalPattern.length] *
                        halfTravel,
                GameTokens.pathRowHeight / 2 + index * GameTokens.pathRowHeight,
              ),
          ];

          return RepaintBoundary(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ExcludeSemantics(
                    child: CustomPaint(
                      painter: _PathConnectorPainter(
                        centers: centers,
                        states: [for (final node in nodes) node.state],
                        colors: colors,
                      ),
                    ),
                  ),
                ),
                for (var index = 0; index < nodes.length; index++)
                  Positioned(
                    left: centers[index].dx - GameTokens.pathNodeHitSize / 2,
                    top: centers[index].dy - GameTokens.pathNodeHitSize / 2 - 4,
                    width: GameTokens.pathNodeHitSize,
                    child: _PathNodeButton(
                      key: nodes[index].id == currentNodeId
                          ? currentNodeKey
                          : null,
                      node: nodes[index],
                      current: nodes[index].id == currentNodeId,
                      onOpen: nodes[index].canOpen
                          ? () => _showNodeSheet(
                              context,
                              node: nodes[index],
                              onStart: onNodeStart,
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NodeVisualStyle {
  const _NodeVisualStyle({
    required this.fill,
    required this.foreground,
    required this.border,
    required this.rim,
  });

  final Color fill;
  final Color foreground;
  final Color border;
  final Color rim;
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
      fill: colors.pathLocked,
      foreground: colors.onPathLocked,
      border: colors.border,
      rim: colors.border,
    ),
    GamePathNodeState.available => _NodeVisualStyle(
      fill: colors.surface,
      foreground: kindColor,
      border: kindColor,
      rim: kindColor,
    ),
    GamePathNodeState.inProgress => _NodeVisualStyle(
      fill: kindColor,
      foreground: onKind,
      border: kindColor,
      rim: Color.alphaBlend(Colors.black.withValues(alpha: 0.22), kindColor),
    ),
    GamePathNodeState.completed => _NodeVisualStyle(
      fill: colors.pathComplete,
      foreground: colors.onPathComplete,
      border: colors.pathComplete,
      rim: Color.alphaBlend(
        Colors.black.withValues(alpha: 0.22),
        colors.pathComplete,
      ),
    ),
    GamePathNodeState.reviewDue => _NodeVisualStyle(
      fill: colors.pathReview,
      foreground: colors.onPathReview,
      border: colors.pathReview,
      rim: Color.alphaBlend(
        Colors.black.withValues(alpha: 0.22),
        colors.pathReview,
      ),
    ),
    GamePathNodeState.legendaryAvailable ||
    GamePathNodeState.legendaryCompleted => _NodeVisualStyle(
      fill: colors.legendary,
      foreground: colors.onLegendary,
      border: colors.onLegendary,
      rim: Color.alphaBlend(
        Colors.black.withValues(alpha: 0.18),
        colors.legendary,
      ),
    ),
  };
}

class _PathNodeButton extends StatefulWidget {
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
  State<_PathNodeButton> createState() => _PathNodeButtonState();
}

class _PathNodeButtonState extends State<_PathNodeButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || widget.onOpen == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final colors = context.gamePalette;
    final style = _nodeStyle(node, colors);
    final reduceMotion = ReduceMotionScope.of(context);
    final legendary = node.kind == GamePathNodeKind.legendary;
    final progress = node.state == GamePathNodeState.inProgress
        ? node.progress
        : null;
    final semantic = _nodeSemanticLabel(node, current: widget.current);

    return Semantics(
      key: ValueKey<String>('game-path-node-${node.id}'),
      container: true,
      button: widget.onOpen != null,
      enabled: widget.onOpen != null,
      label: semantic,
      onTap: widget.onOpen,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tooltip(
              message: node.title,
              child: GestureDetector(
                excludeFromSemantics: true,
                behavior: HitTestBehavior.opaque,
                onTap: widget.onOpen,
                onTapDown: (_) => _setPressed(true),
                onTapCancel: () => _setPressed(false),
                onTapUp: (_) => _setPressed(false),
                child: SizedBox.square(
                  dimension: GameTokens.pathNodeHitSize,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Positioned(
                        top: 10,
                        child: _NodeShape(
                          size: GameTokens.pathNodeSize,
                          legendary: legendary,
                          fill: style.rim,
                          border: style.rim,
                          borderWidth: 0,
                        ),
                      ),
                      if (progress != null)
                        Positioned(
                          top: 0,
                          child: SizedBox.square(
                            dimension: 82,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 5,
                              color: colors.pathActive,
                              backgroundColor: colors.border,
                            ),
                          ),
                        ),
                      if (widget.current && progress == null)
                        Positioned(
                          top: 0,
                          child: IgnorePointer(
                            child: Container(
                              key: ValueKey(
                                'game-path-current-ring-${node.id}',
                              ),
                              width: 82,
                              height: 82,
                              decoration: BoxDecoration(
                                shape: legendary
                                    ? BoxShape.rectangle
                                    : BoxShape.circle,
                                borderRadius: legendary
                                    ? BorderRadius.circular(GameTokens.radiusLg)
                                    : null,
                                border: Border.all(
                                  color: colors.pathActive,
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      AnimatedContainer(
                        duration: reduceMotion
                            ? Duration.zero
                            : const Duration(milliseconds: 100),
                        curve: Curves.easeOut,
                        transform: Matrix4.translationValues(
                          0,
                          _pressed ? 6 : 2,
                          0,
                        ),
                        child: _NodeShape(
                          size: GameTokens.pathNodeSize,
                          legendary: legendary,
                          fill: style.fill,
                          border: style.border,
                          borderWidth: node.state == GamePathNodeState.available
                              ? 4
                              : 2,
                          child: Icon(
                            _nodeIcon(node),
                            size: 31,
                            color: style.foreground,
                          ),
                        ),
                      ),
                      if (node.state == GamePathNodeState.legendaryCompleted)
                        Positioned(
                          right: 3,
                          top: 0,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colors.pathComplete,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colors.surface,
                                width: 2,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: Icon(
                                Icons.check_rounded,
                                size: 15,
                                color: colors.onPathComplete,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -5),
              child: _NodeBadge(
                label: widget.current ? '次はここ' : _nodeBadge(node),
                foreground: style.foreground,
                background: style.fill,
                border: style.border,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NodeShape extends StatelessWidget {
  const _NodeShape({
    required this.size,
    required this.legendary,
    required this.fill,
    required this.border,
    required this.borderWidth,
    this.child,
  });

  final double size;
  final bool legendary;
  final Color fill;
  final Color border;
  final double borderWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: fill,
      shape: legendary ? BoxShape.rectangle : BoxShape.circle,
      borderRadius: legendary
          ? BorderRadius.circular(GameTokens.radiusLg)
          : null,
      border: borderWidth == 0
          ? null
          : Border.all(color: border, width: borderWidth),
    ),
    child: child,
  );
}

class _NodeBadge extends StatelessWidget {
  const _NodeBadge({
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
    constraints: const BoxConstraints(minHeight: 24),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(GameTokens.radiusPill),
      border: Border.all(color: border),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: foreground, height: 1.0)
          .jaWeight(FontWeight.w800),
    ),
  );
}

IconData _nodeIcon(GamePathNode node) => switch (node.state) {
  GamePathNodeState.locked => Icons.lock_rounded,
  GamePathNodeState.completed => Icons.check_rounded,
  GamePathNodeState.reviewDue => Icons.replay_rounded,
  GamePathNodeState.legendaryAvailable ||
  GamePathNodeState.legendaryCompleted => Icons.workspace_premium_rounded,
  _ => switch (node.kind) {
    GamePathNodeKind.lesson => Icons.science_rounded,
    GamePathNodeKind.story => Icons.menu_book_rounded,
    GamePathNodeKind.listening => Icons.headphones_rounded,
    GamePathNodeKind.speaking => Icons.mic_rounded,
    GamePathNodeKind.practice => Icons.fitness_center_rounded,
    GamePathNodeKind.challenge => Icons.flag_circle_rounded,
    GamePathNodeKind.legendary => Icons.workspace_premium_rounded,
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
  GamePathNodeKind.lesson => '理科レッスン',
  GamePathNodeKind.story => '理科ストーリー',
  GamePathNodeKind.listening => '聞く問題',
  GamePathNodeKind.speaking => '説明する問題',
  GamePathNodeKind.practice => '復習',
  GamePathNodeKind.challenge => '章ボス',
  GamePathNodeKind.legendary => '高難度チャレンジ',
};

String _stateLabel(GamePathNode node) => switch (node.state) {
  GamePathNodeState.locked => '未解放。前のレッスンを終えると開きます',
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
                'このレッスンでやること',
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
                  _ => 'レッスン開始',
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

class _PathConnectorPainter extends CustomPainter {
  const _PathConnectorPainter({
    required this.centers,
    required this.states,
    required this.colors,
  });

  final List<Offset> centers;
  final List<GamePathNodeState> states;
  final GamePalette colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (centers.length < 2) return;
    for (var index = 0; index < centers.length - 1; index++) {
      final from = centers[index];
      final to = centers[index + 1];
      final middleY = (from.dy + to.dy) / 2;
      final segment = Path()
        ..moveTo(from.dx, from.dy)
        ..cubicTo(from.dx, middleY, to.dx, middleY, to.dx, to.dy);
      final future = states[index + 1] == GamePathNodeState.locked;
      final completed = _connectorCompleted(states[index + 1]);
      final paint = Paint()
        ..color = completed ? colors.pathComplete : colors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      if (future) {
        _drawDashedPath(canvas, segment, paint);
      } else {
        canvas.drawPath(segment, paint);
      }
    }
  }

  static bool _connectorCompleted(GamePathNodeState state) => switch (state) {
    GamePathNodeState.completed || GamePathNodeState.legendaryCompleted => true,
    _ => false,
  };

  static void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dash = 9.0;
    const gap = 8.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PathConnectorPainter oldDelegate) =>
      oldDelegate.centers != centers ||
      oldDelegate.states != states ||
      oldDelegate.colors != colors;
}
