import '../config/app_language.dart';
import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../learning/domain/learning_heart.dart';
import '../learning/domain/learning_need.dart';
import '../models/game_path.dart';
import '../models/unit.dart';
import '../ui/_material.dart';
import '../widgets/game_activity_scaffold.dart';
import '../widgets/science_challenge_support.dart';
import '../widgets/science_mini_game_widgets.dart';

import 'dart:math' as math;

import 'package:flutter/gestures.dart';

@immutable
class ScienceNotationToken {
  const ScienceNotationToken({required this.id, required this.label});

  final String id;
  final String label;
}

@immutable
class ScienceNotationTracePoint {
  const ScienceNotationTracePoint({required this.x, required this.y});

  final double x;
  final double y;
}

@immutable
class ScienceNotationTraceStroke {
  const ScienceNotationTraceStroke({
    required this.id,
    required this.label,
    required this.points,
  });

  final String id;
  final String label;
  final List<ScienceNotationTracePoint> points;
}

@immutable
class ScienceNotationTracePattern {
  const ScienceNotationTracePattern({
    required this.semanticsLabel,
    required this.strokes,
    required this.strokeOrderIds,
  });

  final String semanticsLabel;
  final List<ScienceNotationTraceStroke> strokes;
  final List<String> strokeOrderIds;

  ScienceNotationTraceStroke strokeFor(String id) =>
      strokes.singleWhere((stroke) => stroke.id == id);
}

/// 矢印の筆順や式の並びを、catalog側で定義する課題。
@immutable
class ScienceNotationOrderTask {
  const ScienceNotationOrderTask({
    required this.id,
    required this.title,
    required this.prompt,
    required this.traceGuide,
    required this.tracePattern,
    required this.tokens,
    required this.correctOrderIds,
    required this.solutionSummary,
    this.needCode,
  });

  final String id;
  final String title;
  final String prompt;

  /// 正答そのものではなく、線を置く向き・読む向きだけを示すガイド。
  final String traceGuide;
  final ScienceNotationTracePattern tracePattern;
  final List<ScienceNotationToken> tokens;
  final List<String> correctOrderIds;

  /// 正解送信後だけ表示してよい教材正本。
  final String solutionSummary;
  final String? needCode;
}

@immutable
class ScienceNotationChoice {
  const ScienceNotationChoice({required this.id, required this.label});

  final String id;
  final String label;
}

/// 単位記号と意味を対応させる、catalog駆動の選択課題。
@immutable
class ScienceNotationSymbolTask {
  const ScienceNotationSymbolTask({
    required this.prompt,
    required this.choices,
    required this.correctChoiceId,
    required this.solutionSummary,
    this.needCode,
  });

  final String prompt;
  final List<ScienceNotationChoice> choices;
  final String correctChoiceId;
  final String solutionSummary;
  final String? needCode;
}

/// 軸・矢印・線の変化を読ませる、catalog駆動のグラフ課題。
@immutable
class ScienceNotationGraphTask {
  const ScienceNotationGraphTask({
    required this.prompt,
    required this.graphNotation,
    required this.graphSemanticsLabel,
    required this.choices,
    required this.correctChoiceId,
    required this.solutionSummary,
    this.needCode,
  });

  final String prompt;
  final List<String> graphNotation;
  final String graphSemanticsLabel;
  final List<ScienceNotationChoice> choices;
  final String correctChoiceId;
  final String solutionSummary;
  final String? needCode;
}

@immutable
sealed class ScienceNotationTask {
  const ScienceNotationTask({
    required this.kind,
    required this.id,
    required this.title,
    required this.prompt,
    required this.solutionSummary,
    this.needCode,
  });

  final LocalNotationTaskKind kind;
  final String id;
  final String title;
  final String prompt;
  final String solutionSummary;
  final String? needCode;
}

@immutable
final class ScienceNotationArrangeTask extends ScienceNotationTask {
  const ScienceNotationArrangeTask({
    required super.kind,
    required super.id,
    required super.title,
    required super.prompt,
    required super.solutionSummary,
    required this.guide,
    required this.tokens,
    required this.correctOrderIds,
    this.tracePattern,
    super.needCode,
  });

  final String guide;
  final ScienceNotationTracePattern? tracePattern;
  final List<ScienceNotationToken> tokens;
  final List<String> correctOrderIds;
}

@immutable
final class ScienceNotationChoiceTask extends ScienceNotationTask {
  const ScienceNotationChoiceTask({
    required super.kind,
    required super.id,
    required super.title,
    required super.prompt,
    required super.solutionSummary,
    required this.representation,
    required this.representationSemanticsLabel,
    required this.choices,
    required this.correctChoiceId,
    super.needCode,
  });

  final List<String> representation;
  final String representationSemanticsLabel;
  final List<ScienceNotationChoice> choices;
  final String correctChoiceId;
}

@immutable
class ScienceNotationLabContent {
  const ScienceNotationLabContent({
    required List<ScienceNotationOrderTask> orderTasks,
    required ScienceNotationSymbolTask symbolMatch,
    required ScienceNotationGraphTask graphRead,
  }) : _legacyOrderTasks = orderTasks,
       _legacySymbolMatch = symbolMatch,
       _legacyGraphRead = graphRead,
       _taggedTasks = const [];

  const ScienceNotationLabContent.tagged({
    required List<ScienceNotationTask> tasks,
  }) : _taggedTasks = tasks,
       _legacyOrderTasks = null,
       _legacySymbolMatch = null,
       _legacyGraphRead = null;

  final List<ScienceNotationTask> _taggedTasks;
  final List<ScienceNotationOrderTask>? _legacyOrderTasks;
  final ScienceNotationSymbolTask? _legacySymbolMatch;
  final ScienceNotationGraphTask? _legacyGraphRead;

  List<ScienceNotationTask> get tasks {
    if (_taggedTasks.isNotEmpty) return _taggedTasks;
    final orderTasks = _legacyOrderTasks ?? const <ScienceNotationOrderTask>[];
    final symbol = _legacySymbolMatch;
    final graph = _legacyGraphRead;
    return List.unmodifiable([
      for (var index = 0; index < orderTasks.length; index++)
        ScienceNotationArrangeTask(
          kind: index == 0
              ? LocalNotationTaskKind.sequence
              : LocalNotationTaskKind.modelBuild,
          id: orderTasks[index].id,
          title: orderTasks[index].title,
          prompt: orderTasks[index].prompt,
          solutionSummary: orderTasks[index].solutionSummary,
          guide: orderTasks[index].traceGuide,
          tracePattern: orderTasks[index].tracePattern,
          tokens: orderTasks[index].tokens,
          correctOrderIds: orderTasks[index].correctOrderIds,
          needCode: orderTasks[index].needCode,
        ),
      if (symbol != null)
        ScienceNotationChoiceTask(
          kind: LocalNotationTaskKind.symbolMatch,
          id: 'legacy.symbol',
          title: t('単位記号を意味と結ぶ', 'Match unit symbols to meanings'),
          prompt: symbol.prompt,
          solutionSummary: symbol.solutionSummary,
          representation: const [],
          representationSemanticsLabel: t('選択肢の記号と意味を対応させます。', 'Match each symbol to its meaning.'),
          choices: symbol.choices,
          correctChoiceId: symbol.correctChoiceId,
          needCode: symbol.needCode,
        ),
      if (graph != null)
        ScienceNotationChoiceTask(
          kind: LocalNotationTaskKind.graphRead,
          id: 'legacy.graph',
          title: t('グラフと矢印を読む', 'Read graphs and arrows'),
          prompt: graph.prompt,
          solutionSummary: graph.solutionSummary,
          representation: graph.graphNotation,
          representationSemanticsLabel: graph.graphSemanticsLabel,
          choices: graph.choices,
          correctChoiceId: graph.correctChoiceId,
          needCode: graph.needCode,
        ),
    ]);
  }

  /// 矢印のなぞりと式の組み立てを別課題として最低1つずつ渡す。
  List<ScienceNotationOrderTask> get orderTasks =>
      _legacyOrderTasks ?? const [];
  ScienceNotationSymbolTask get symbolMatch => _legacySymbolMatch!;
  ScienceNotationGraphTask get graphRead => _legacyGraphRead!;
}

/// 理科の記号を「なぞる・組む・読む」で扱うNotation Lab。
///
/// 回答と見直し文はState内だけに保持し、callbackには完了通知とcatalog固定の
/// 一般化needだけを渡す。選択IDや本文は渡さない。
class ScienceNotationLabScreen extends StatefulWidget {
  const ScienceNotationLabScreen({
    super.key,
    required this.section,
    required this.conceptLabel,
    required this.practiceAttempt,
    required this.content,
    required this.onCompleted,
    required this.onRetryRequested,
    this.focusNeedCode,
    this.onNeedEvidence,
    this.onHeartLoss,
  }) : assert(practiceAttempt >= 0);

  final Section section;
  final String conceptLabel;
  final int practiceAttempt;
  final ScienceNotationLabContent content;
  final VoidCallback onCompleted;
  final Future<bool> Function() onRetryRequested;

  /// Repair plannerがcatalogで照合済みの固定needだけを練習するときに渡す。
  ///
  /// nullなら従来どおり全課題を順に扱う。不明・重複codeは推測せず起動を拒否する。
  final String? focusNeedCode;
  final LearningNeedEvidenceReported? onNeedEvidence;
  final LearningHeartLossReported? onHeartLoss;

  @override
  State<ScienceNotationLabScreen> createState() =>
      _ScienceNotationLabScreenState();
}

class _ScienceNotationLabScreenState extends State<ScienceNotationLabScreen> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _review = TextEditingController();

  int _step = 0;
  final List<String> _orderedIds = [];
  String? _choiceId;
  bool _lockedAfterWrong = false;
  bool _tracePending = false;
  bool _traceCompleted = false;
  int _traceSession = 0;
  bool _completionCalled = false;
  bool _retryChecking = false;
  final Set<String> _observedNeedCodes = {};
  final Set<String> _demonstratedNeedCodes = {};
  late final List<int> _stepIndexes;

  LocalPracticeVariant get _variant =>
      widget.section.practiceVariantForAttempt(widget.practiceAttempt);

  int get _stepCount => _stepIndexes.length;
  bool get _complete => _step >= _stepCount;
  int get _contentStep => _stepIndexes[_step];
  ScienceNotationTask get _currentTask => widget.content.tasks[_contentStep];
  bool get _isArrangeStep => _currentTask is ScienceNotationArrangeTask;
  bool get _reviewReady => _review.text.trim().runes.length >= 6;

  @override
  void initState() {
    super.initState();
    assert(_debugValidateNotationContent(widget.content));
    _stepIndexes = _notationStepIndexes(
      widget.content,
      focusNeedCode: widget.focusNeedCode,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    _review.dispose();
    super.dispose();
  }

  void _selectOrderToken(String id) {
    if (_lockedAfterWrong || _orderedIds.contains(id)) return;
    setState(() => _orderedIds.add(id));
  }

  void _clearOrder() {
    if (_lockedAfterWrong || _orderedIds.isEmpty) return;
    setState(_orderedIds.clear);
  }

  void _selectChoice(String id) {
    if (_lockedAfterWrong) return;
    setState(() => _choiceId = id);
  }

  void _submit() {
    if (_complete || _lockedAfterWrong) return;
    final answered = _isArrangeStep
        ? _orderedIds.isNotEmpty
        : _choiceId != null;
    if (!answered) return;

    final correct = switch (_currentTask) {
      ScienceNotationArrangeTask task => _sameOrder(
        _orderedIds,
        task.correctOrderIds,
      ),
      ScienceNotationChoiceTask task => _choiceId == task.correctChoiceId,
    };
    if (!correct) {
      _reportNeed(_currentNeedCode, correct: false);
      widget.onHeartLoss?.call(
        LearningHeartLossEvidence(
          fixedTaskId:
              'notation:${widget.practiceAttempt}:${_fixedTaskIdForStep()}',
        ),
      );
      setState(() => _lockedAfterWrong = true);
      return;
    }
    if (_currentTask case final ScienceNotationArrangeTask task
        when task.tracePattern != null) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() {
        _tracePending = true;
        _traceCompleted = false;
        _traceSession++;
      });
      _returnToTop();
      return;
    }
    _advanceStepAfterSuccess();
  }

  void _advanceStepAfterSuccess() {
    _reportNeed(_currentNeedCode, correct: true);
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _step++;
      _orderedIds.clear();
      _choiceId = null;
      _tracePending = false;
      _traceCompleted = false;
      _review.clear();
    });
    _returnToTop();
  }

  void _finishTrace() {
    if (!_tracePending || !_traceCompleted || !_isArrangeStep) return;
    _advanceStepAfterSuccess();
  }

  String? get _currentNeedCode => _currentTask.needCode;

  String _fixedTaskIdForStep() =>
      '${_currentTask.kind.wire}:${_currentTask.id}';

  void _reportNeed(String? needCode, {required bool correct}) {
    if (needCode == null) return;
    final kind = correct
        ? LearningNeedEvidenceKind.demonstrated
        : LearningNeedEvidenceKind.observed;
    if (kind == LearningNeedEvidenceKind.observed) {
      if (!_observedNeedCodes.add(needCode)) return;
    } else if (_observedNeedCodes.contains(needCode) ||
        !_demonstratedNeedCodes.add(needCode)) {
      return;
    }
    widget.onNeedEvidence?.call(
      LearningNeedEvidence(
        conceptKey: widget.section.conceptKey,
        needCode: needCode,
        kind: kind,
      ),
    );
  }

  Future<void> _retryStep() async {
    if (!_lockedAfterWrong || !_reviewReady || _retryChecking) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _retryChecking = true);
    var allowed = false;
    try {
      allowed = await widget.onRetryRequested();
    } catch (_) {
      allowed = false;
    }
    if (!mounted) return;
    if (!allowed) {
      setState(() => _retryChecking = false);
      return;
    }
    setState(() {
      _lockedAfterWrong = false;
      _orderedIds.clear();
      _choiceId = null;
      _tracePending = false;
      _traceCompleted = false;
      _traceSession++;
      _review.clear();
      _retryChecking = false;
    });
  }

  void _completeLab() {
    if (!_complete || _completionCalled) return;
    _completionCalled = true;
    widget.onCompleted();
  }

  void _returnToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final hasSharedChrome = GameActivityScaffold.hasSharedChrome(context);
    return Scaffold(
      key: const ValueKey('science-notation-lab-screen'),
      backgroundColor: colors.canvas,
      appBar: hasSharedChrome
          ? null
          : AppBar(
              backgroundColor: colors.canvas,
              foregroundColor: colors.ink,
              title: Text(
                'Notation Lab',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.jaWeight(FontWeight.w800),
              ),
            ),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              key: const ValueKey('science-notation-scroll'),
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(
                GameTokens.spaceLg,
                GameTokens.spaceSm,
                GameTokens.spaceLg,
                GameTokens.spaceXl + MediaQuery.paddingOf(context).bottom,
              ),
              child: _complete ? _buildComplete(context) : _buildTask(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTask(BuildContext context) {
    final colors = context.gamePalette;
    final stepLabel = 'STEP ${_step + 1} / $_stepCount';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScienceChallengeHeader(
          eyebrow: '$stepLabel  /  NOTATION LAB',
          title: widget.conceptLabel,
          body: t('記号・モデル・図表を組み立て、意味と結びます。', 'Build symbols, models, and charts, and link them to meanings.'),
          icon: Icons.draw_outlined,
          accent: colors.story,
          onAccent: colors.onStory,
          mascotReaction: GameCharacterReaction.thinking,
        ),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengeSurface(
          label: t('この単元の場面', 'Scenario for this unit'),
          icon: Icons.science_outlined,
          child: Text(_variant.transferPrompt),
        ),
        const SizedBox(height: GameTokens.spaceLg),
        if (_isArrangeStep && _tracePending)
          _buildTraceStrengthening(
            context,
            _currentTask as ScienceNotationArrangeTask,
          )
        else if (_isArrangeStep)
          _buildArrangeTask(context, _currentTask as ScienceNotationArrangeTask)
        else
          _buildChoiceTask(context, _currentTask as ScienceNotationChoiceTask),
        if (_lockedAfterWrong) ...[
          const SizedBox(height: GameTokens.spaceLg),
          _buildReview(context),
        ],
        const SizedBox(height: GameTokens.spaceLg),
        if (_tracePending)
          ScienceChallengePrimaryButton(
            key: const ValueKey('notation-trace-continue'),
            label: t('なぞりを終えて次へ', 'Finish tracing and continue'),
            icon: Icons.arrow_forward_rounded,
            onPressed: _traceCompleted ? _finishTrace : null,
            backgroundColor: colors.story,
            foregroundColor: colors.onStory,
          )
        else
          ScienceChallengePrimaryButton(
            key: const ValueKey('notation-submit'),
            label: t('この組み方で確認する', 'Check this build'),
            icon: Icons.check_rounded,
            onPressed: _canSubmit ? _submit : null,
            backgroundColor: colors.story,
            foregroundColor: colors.onStory,
          ),
        const SizedBox(height: GameTokens.spaceLg),
        const ScienceChallengePrivacyNote(),
      ],
    );
  }

  bool get _canSubmit =>
      !_lockedAfterWrong &&
      !_tracePending &&
      (_isArrangeStep
          ? _orderedIds.length ==
                (_currentTask as ScienceNotationArrangeTask)
                    .correctOrderIds
                    .length
          : _choiceId != null);

  Widget _buildArrangeTask(
    BuildContext context,
    ScienceNotationArrangeTask task,
  ) {
    final colors = context.gamePalette;
    final selectedLabels = _orderedIds
        .map((id) => task.tokens.firstWhere((token) => token.id == id).label)
        .join('  ');
    return ScienceChallengeSurface(
      label: task.title,
      icon: Icons.gesture_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(task.prompt),
          const SizedBox(height: GameTokens.spaceSm),
          Semantics(
            label: t('なぞる向き。${task.guide}', 'Tracing direction. ${task.guide}'),
            child: Text(
              task.guide,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
            ),
          ),
          const SizedBox(height: GameTokens.spaceLg),
          Semantics(
            key: const ValueKey('notation-order-output'),
            container: true,
            label: selectedLabels.isEmpty
                ? t('まだ何も並べていません', 'Nothing placed yet')
                : t('現在の並び。$selectedLabels', 'Current order. $selectedLabels'),
            child: ExcludeSemantics(
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(GameTokens.spaceMd),
                decoration: BoxDecoration(
                  color: colors.surfaceRaised,
                  borderRadius: BorderRadius.circular(GameTokens.radiusSm),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  selectedLabels.isEmpty ? t('ここに順番に並びます', 'Tiles appear here in order') : selectedLabels,
                ),
              ),
            ),
          ),
          const SizedBox(height: GameTokens.spaceMd),
          Wrap(
            spacing: GameTokens.spaceSm,
            runSpacing: GameTokens.spaceSm,
            children: [
              for (final token in task.tokens)
                Semantics(
                  button: true,
                  enabled:
                      !_lockedAfterWrong && !_orderedIds.contains(token.id),
                  label: t('組み札。${token.label}', 'Tile. ${token.label}'),
                  child: OutlinedButton(
                    key: ValueKey('notation-order-token-${token.id}'),
                    onPressed:
                        _lockedAfterWrong || _orderedIds.contains(token.id)
                        ? null
                        : () => _selectOrderToken(token.id),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(56, 56),
                      foregroundColor: colors.ink,
                    ),
                    child: Text(token.label),
                  ),
                ),
            ],
          ),
          const SizedBox(height: GameTokens.spaceSm),
          TextButton.icon(
            key: const ValueKey('notation-order-clear'),
            onPressed: _lockedAfterWrong || _orderedIds.isEmpty
                ? null
                : _clearOrder,
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(GameTokens.minTouchTarget),
              foregroundColor: colors.ink,
            ),
            icon: const Icon(Icons.restart_alt_rounded),
            label: Text(t('送信前に組み直す', 'Rebuild before submitting')),
          ),
        ],
      ),
    );
  }

  Widget _buildTraceStrengthening(
    BuildContext context,
    ScienceNotationArrangeTask task,
  ) {
    final colors = context.gamePalette;
    final canonical = task.correctOrderIds
        .map((id) => task.tokens.singleWhere((token) => token.id == id).label)
        .join('  ');
    return ScienceChallengeSurface(
      key: ValueKey('notation-trace-surface-${task.id}'),
      label: t('正答のあとに、指で定着', 'After the right answer, trace to lock it in'),
      icon: Icons.swipe_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            label: t('正しい組み方。$canonical。${task.solutionSummary}', 'Correct build. $canonical. ${task.solutionSummary}'),
            child: ExcludeSemantics(
              child: Container(
                padding: const EdgeInsets.all(GameTokens.spaceMd),
                decoration: BoxDecoration(
                  color: colors.surfaceRaised,
                  borderRadius: BorderRadius.circular(GameTokens.radiusSm),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  children: [
                    Text(
                      canonical,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(color: colors.ink)
                          .jaWeight(FontWeight.w800),
                    ),
                    const SizedBox(height: GameTokens.spaceSm),
                    Text(
                      task.solutionSummary,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: GameTokens.spaceMd),
          Text(
            t('線から指を離さず、表示された順に1本ずつなぞります。離れた場合は、その1本だけやり直します。', 'Trace each line in the order shown without lifting your finger. If you lift it, redo just that line.'),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
          ),
          const SizedBox(height: GameTokens.spaceMd),
          _NotationTraceBoard(
            key: ValueKey('notation-trace-board-${task.id}-$_traceSession'),
            pattern: task.tracePattern!,
            onCompletedChanged: (complete) {
              if (!mounted || _traceCompleted == complete) return;
              setState(() => _traceCompleted = complete);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceTask(
    BuildContext context,
    ScienceNotationChoiceTask task,
  ) {
    final colors = context.gamePalette;
    return ScienceChallengeSurface(
      label: task.title,
      icon: _choiceTaskIcon(task.kind),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(task.prompt),
          if (task.representation.isNotEmpty) ...[
            const SizedBox(height: GameTokens.spaceMd),
            Semantics(
              container: true,
              image: true,
              label: task.representationSemanticsLabel,
              child: ExcludeSemantics(
                child: Container(
                  padding: const EdgeInsets.all(GameTokens.spaceLg),
                  decoration: BoxDecoration(
                    color: colors.surfaceRaised,
                    borderRadius: BorderRadius.circular(GameTokens.radiusSm),
                    border: Border.all(color: colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final line in task.representation)
                        Text(
                          line,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: colors.ink)
                              .jaWeight(FontWeight.w800),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: GameTokens.spaceLg),
          for (var index = 0; index < task.choices.length; index++) ...[
            ScienceMiniGameChoice(
              key: ValueKey(
                '${_choiceTaskKeyPrefix(task.kind)}-${task.choices[index].id}',
              ),
              text: task.choices[index].label,
              position: index + 1,
              count: task.choices.length,
              selected: _choiceId == task.choices[index].id,
              onPressed: _lockedAfterWrong
                  ? null
                  : () => _selectChoice(task.choices[index].id),
            ),
            if (index < task.choices.length - 1)
              const SizedBox(height: GameTokens.spaceSm),
          ],
        ],
      ),
    );
  }

  IconData _choiceTaskIcon(LocalNotationTaskKind kind) => switch (kind) {
    LocalNotationTaskKind.labelDiagram => Icons.account_tree_outlined,
    LocalNotationTaskKind.tableRead => Icons.table_chart_outlined,
    LocalNotationTaskKind.graphRead => Icons.show_chart_rounded,
    LocalNotationTaskKind.symbolMatch => Icons.straighten_outlined,
    _ => Icons.fact_check_outlined,
  };

  String _choiceTaskKeyPrefix(LocalNotationTaskKind kind) => switch (kind) {
    LocalNotationTaskKind.symbolMatch => 'notation-symbol',
    LocalNotationTaskKind.graphRead => 'notation-graph',
    _ => 'notation-${kind.wire}',
  };

  Widget _buildReview(BuildContext context) {
    final colors = context.gamePalette;
    return ScienceChallengeSurface(
      label: t('ここで一度、見直す', 'Pause and review'),
      icon: Icons.lock_clock_outlined,
      backgroundColor: colors.surfaceRaised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t('別の札を続けて押すことはできません。見直す点を1文だけ残すと、同じ課題を組み直せます。', 'You can\'t just tap another tile. Write one sentence about what to review, then rebuild the same task.')),
          const SizedBox(height: GameTokens.spaceMd),
          TextField(
            key: const ValueKey('notation-review'),
            controller: _review,
            minLines: 2,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: t('どこを見直す？（6文字以上）', 'What will you review? (6+ characters)'),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: GameTokens.spaceMd),
          OutlinedButton.icon(
            key: const ValueKey('notation-retry'),
            onPressed: _reviewReady && !_retryChecking ? _retryStep : null,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              foregroundColor: colors.ink,
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_retryChecking ? t('ハートを確認中…', 'Checking hearts…') : t('この課題だけ組み直す', 'Rebuild just this task')),
          ),
        ],
      ),
    );
  }

  Widget _buildComplete(BuildContext context) {
    final colors = context.gamePalette;
    final summaries = _stepIndexes
        .map((index) => _notationSolutionSummary(widget.content, index))
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScienceChallengeHeader(
          eyebrow: 'NOTATION LAB  /  COMPLETE',
          title: t('記号を意味とつなげました', 'You linked symbols to meanings'),
          body: widget.conceptLabel,
          icon: Icons.fact_check_outlined,
          accent: colors.pathComplete,
          onAccent: colors.onPathComplete,
          mascotReaction: GameCharacterReaction.celebrate,
        ),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengeSurface(
          label: t('読み方の確認', 'How to read it'),
          icon: Icons.menu_book_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final summary in summaries) ...[
                Text('・$summary'),
                const SizedBox(height: GameTokens.spaceSm),
              ],
            ],
          ),
        ),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengePrimaryButton(
          key: const ValueKey('notation-complete'),
          label: t('Notation Labを完了する', 'Finish Notation Lab'),
          icon: Icons.check_circle_outline_rounded,
          onPressed: _completionCalled ? null : _completeLab,
          backgroundColor: colors.pathComplete,
          foregroundColor: colors.onPathComplete,
        ),
        const SizedBox(height: GameTokens.spaceLg),
        const ScienceChallengePrivacyNote(),
      ],
    );
  }
}

/// 正答開示後だけ構築する、catalog固定strokeの実gesture強化。
///
/// pointer座標はこのStateから外へ出さず、stroke完了時にも生の軌跡を保持しない。
/// accessibilityNavigationでは同じstroke順を56dpボタンで確認する。
class _NotationTraceBoard extends StatefulWidget {
  const _NotationTraceBoard({
    super.key,
    required this.pattern,
    required this.onCompletedChanged,
  });

  final ScienceNotationTracePattern pattern;
  final ValueChanged<bool> onCompletedChanged;

  @override
  State<_NotationTraceBoard> createState() => _NotationTraceBoardState();
}

class _NotationTraceBoardState extends State<_NotationTraceBoard> {
  final List<String> _completedStrokeIds = [];
  final List<Offset> _pointerPath = [];
  bool _activeGesture = false;
  int? _activePointer;
  bool _reachedStrokeEnd = false;
  int _nextPointIndex = 0;
  String? _error;

  bool get _complete =>
      _completedStrokeIds.length == widget.pattern.strokeOrderIds.length;

  ScienceNotationTraceStroke? get _currentStroke {
    if (_complete) return null;
    return widget.pattern.strokeFor(
      widget.pattern.strokeOrderIds[_completedStrokeIds.length],
    );
  }

  void _completeAccessibleStroke() {
    final stroke = _currentStroke;
    if (stroke == null) return;
    setState(() {
      _completedStrokeIds.add(stroke.id);
      _error = null;
    });
    widget.onCompletedChanged(_complete);
  }

  Offset _normalized(Offset local, Size size) => Offset(
    size.width <= 0 ? -1 : local.dx / size.width,
    size.height <= 0 ? -1 : local.dy / size.height,
  );

  void _startGesture(int pointer, Offset localPosition, Size size) {
    final stroke = _currentStroke;
    if (stroke == null) return;
    if (_activeGesture) {
      _invalidateGesture(t('指が複数触れました。この線を1本の指でやり直します。', 'More than one finger touched. Redo this line with one finger.'));
      return;
    }
    final point = _normalized(localPosition, size);
    final start = stroke.points.first;
    if (!_insideUnit(point) ||
        _distance(point, Offset(start.x, start.y)) > 0.11) {
      setState(() {
        _activeGesture = false;
        _activePointer = null;
        _pointerPath.clear();
        _error = t('番号の付いた始点から始めてください。', 'Start from the numbered starting point.');
      });
      return;
    }
    setState(() {
      _activeGesture = true;
      _activePointer = pointer;
      _reachedStrokeEnd = false;
      _nextPointIndex = 1;
      _pointerPath
        ..clear()
        ..add(localPosition);
      _error = null;
    });
  }

  void _updateGesture(int pointer, Offset localPosition, Size size) {
    if (!_activeGesture || pointer != _activePointer) return;
    final stroke = _currentStroke;
    if (stroke == null) return;
    final point = _normalized(localPosition, size);
    if (!_insideUnit(point)) {
      _invalidateGesture(t('枠の外へ出ました。この線を始点からやり直します。', 'You went outside the frame. Redo this line from the start.'));
      return;
    }
    final nextIndex = _nextPointIndex.clamp(1, stroke.points.length - 1);
    final previous = stroke.points[nextIndex - 1];
    final next = stroke.points[nextIndex];
    final distanceFromSegment = _distanceToSegment(
      point,
      Offset(previous.x, previous.y),
      Offset(next.x, next.y),
    );
    if (distanceFromSegment > 0.12) {
      _invalidateGesture(t('線から離れました。この線を始点からやり直します。', 'You left the line. Redo this line from the start.'));
      return;
    }

    setState(() {
      _pointerPath.add(localPosition);
      if (_distance(point, Offset(next.x, next.y)) <= 0.10) {
        if (_nextPointIndex == stroke.points.length - 1) {
          _reachedStrokeEnd = true;
        } else {
          _nextPointIndex++;
        }
      }
    });
  }

  void _endGesture(int pointer) {
    if (!_activeGesture || pointer != _activePointer) return;
    final stroke = _currentStroke;
    final completed = stroke != null && _reachedStrokeEnd;
    setState(() {
      _activeGesture = false;
      _activePointer = null;
      _pointerPath.clear();
      _nextPointIndex = 0;
      _reachedStrokeEnd = false;
      if (completed) {
        _completedStrokeIds.add(stroke.id);
        _error = null;
      } else {
        _error = t('途中で指が離れました。この線を始点からやり直します。', 'Your finger lifted midway. Redo this line from the start.');
      }
    });
    if (completed) widget.onCompletedChanged(_complete);
  }

  void _cancelGesture(int pointer) {
    if (!_activeGesture || pointer != _activePointer) return;
    _invalidateGesture(t('操作が中断されました。この線を始点からやり直します。', 'The gesture was interrupted. Redo this line from the start.'));
  }

  void _invalidateGesture(String message) {
    setState(() {
      _activeGesture = false;
      _activePointer = null;
      _reachedStrokeEnd = false;
      _nextPointIndex = 0;
      _pointerPath.clear();
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final accessible = MediaQuery.accessibleNavigationOf(context);
    if (accessible) return _buildAccessibleSequence(context);

    final colors = context.gamePalette;
    final current = _currentStroke;
    final progress = _complete
        ? t('全${widget.pattern.strokeOrderIds.length}本を完了しました。', 'All ${widget.pattern.strokeOrderIds.length} lines done.')
        : t('${_completedStrokeIds.length + 1}本目、${current?.label ?? ''}。', 'Line ${_completedStrokeIds.length + 1}, ${current?.label ?? ''}.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          key: const ValueKey('notation-trace-canvas-semantics'),
          container: true,
          liveRegion: true,
          label: '${widget.pattern.semanticsLabel} $progress ${_error ?? ''}',
          child: ExcludeSemantics(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : 320.0;
                final height = (width * 0.74).clamp(220.0, 300.0);
                final size = Size(width, height);
                return RawGestureDetector(
                  key: const ValueKey('notation-trace-canvas'),
                  behavior: HitTestBehavior.opaque,
                  gestures: _complete
                      ? const {}
                      : {
                          EagerGestureRecognizer:
                              GestureRecognizerFactoryWithHandlers<
                                EagerGestureRecognizer
                              >(EagerGestureRecognizer.new, (_) {}),
                        },
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _complete
                        ? null
                        : (event) => _startGesture(
                            event.pointer,
                            event.localPosition,
                            size,
                          ),
                    onPointerMove: _complete
                        ? null
                        : (event) => _updateGesture(
                            event.pointer,
                            event.localPosition,
                            size,
                          ),
                    onPointerUp: _complete
                        ? null
                        : (event) => _endGesture(event.pointer),
                    onPointerCancel: _complete
                        ? null
                        : (event) => _cancelGesture(event.pointer),
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: CustomPaint(
                        painter: _NotationTracePainter(
                          pattern: widget.pattern,
                          completedStrokeIds: _completedStrokeIds,
                          currentStrokeId: current?.id,
                          pointerPath: _pointerPath,
                          guideColor: colors.border,
                          activeColor: colors.story,
                          completedColor: colors.pathComplete,
                          canvasColor: colors.surfaceRaised,
                          inkColor: colors.ink,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: GameTokens.spaceSm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _complete
                  ? Icons.check_circle_rounded
                  : _error == null
                  ? Icons.touch_app_outlined
                  : Icons.replay_rounded,
              color: _complete ? colors.pathComplete : colors.inkMuted,
            ),
            const SizedBox(width: GameTokens.spaceSm),
            Expanded(
              child: Text(
                _error ?? progress,
                key: const ValueKey('notation-trace-status'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccessibleSequence(BuildContext context) {
    final colors = context.gamePalette;
    return Semantics(
      key: const ValueKey('notation-trace-accessible-sequence'),
      container: true,
      label:
          t('${widget.pattern.semanticsLabel} '
          'スクリーンリーダー用に、同じ線順をボタンで確認します。', '${widget.pattern.semanticsLabel} For screen readers, confirm the same line order with buttons.'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t('読み上げ操作では、線を同じ順番で1本ずつ確認します。', 'With a screen reader, confirm each line in the same order, one at a time.')),
          const SizedBox(height: GameTokens.spaceMd),
          for (
            var index = 0;
            index < widget.pattern.strokeOrderIds.length;
            index++
          ) ...[
            Semantics(
              button: true,
              enabled: index == _completedStrokeIds.length,
              label:
                  t('${index + 1}本目、'
                  '${widget.pattern.strokeFor(widget.pattern.strokeOrderIds[index]).label}。'
                  '${index < _completedStrokeIds.length
                      ? '確認済み'
                      : index == _completedStrokeIds.length
                      ? '確認する'
                      : '前の線の確認後に使えます'}', 'Line ${index + 1}, ' '${widget.pattern.strokeFor(widget.pattern.strokeOrderIds[index]).label}. ' '${index < _completedStrokeIds.length ? 'Checked' : index == _completedStrokeIds.length ? 'Check' : 'Available after the previous line'}'),
              child: OutlinedButton.icon(
                key: ValueKey('notation-trace-accessible-${index + 1}'),
                onPressed: index == _completedStrokeIds.length
                    ? _completeAccessibleStroke
                    : null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  foregroundColor: colors.ink,
                ),
                icon: Icon(
                  index < _completedStrokeIds.length
                      ? Icons.check_circle_rounded
                      : Icons.looks_one_outlined,
                ),
                label: Text(
                  t('${index + 1}本目：'
                  '${widget.pattern.strokeFor(widget.pattern.strokeOrderIds[index]).label}', 'Line ${index + 1}: ' '${widget.pattern.strokeFor(widget.pattern.strokeOrderIds[index]).label}'),
                ),
              ),
            ),
            if (index < widget.pattern.strokeOrderIds.length - 1)
              const SizedBox(height: GameTokens.spaceSm),
          ],
          if (_complete) ...[
            const SizedBox(height: GameTokens.spaceMd),
            Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: colors.pathComplete),
                  const SizedBox(width: GameTokens.spaceSm),
                  Expanded(child: Text(t('全ての線を順番に確認しました。', 'All lines checked in order.'))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotationTracePainter extends CustomPainter {
  const _NotationTracePainter({
    required this.pattern,
    required this.completedStrokeIds,
    required this.currentStrokeId,
    required this.pointerPath,
    required this.guideColor,
    required this.activeColor,
    required this.completedColor,
    required this.canvasColor,
    required this.inkColor,
  });

  final ScienceNotationTracePattern pattern;
  final List<String> completedStrokeIds;
  final String? currentStrokeId;
  final List<Offset> pointerPath;
  final Color guideColor;
  final Color activeColor;
  final Color completedColor;
  final Color canvasColor;
  final Color inkColor;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = canvasColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(GameTokens.radiusSm),
      ),
      background,
    );

    for (
      var orderIndex = 0;
      orderIndex < pattern.strokeOrderIds.length;
      orderIndex++
    ) {
      final stroke = pattern.strokeFor(pattern.strokeOrderIds[orderIndex]);
      final completed = completedStrokeIds.contains(stroke.id);
      final active = stroke.id == currentStrokeId;
      final path = Path();
      for (var index = 0; index < stroke.points.length; index++) {
        final point = Offset(
          stroke.points[index].x * size.width,
          stroke.points[index].y * size.height,
        );
        if (index == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = completed
              ? completedColor
              : active
              ? activeColor
              : guideColor
          ..strokeWidth = completed || active ? 7 : 5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
      final start = stroke.points.first;
      final center = Offset(start.x * size.width, start.y * size.height);
      canvas.drawCircle(
        center,
        15,
        Paint()
          ..color = completed
              ? completedColor
              : active
              ? activeColor
              : guideColor,
      );
      final label = TextPainter(
        text: TextSpan(
          text: '${orderIndex + 1}',
          style: TextStyle(
            color: completed || active ? canvasColor : inkColor,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, center - Offset(label.width / 2, label.height / 2));
    }

    if (pointerPath.length > 1) {
      final userPath = Path()
        ..moveTo(pointerPath.first.dx, pointerPath.first.dy);
      for (final point in pointerPath.skip(1)) {
        userPath.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        userPath,
        Paint()
          ..color = activeColor
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NotationTracePainter oldDelegate) => true;
}

bool _insideUnit(Offset point) =>
    point.dx >= 0 && point.dx <= 1 && point.dy >= 0 && point.dy <= 1;

double _distance(Offset a, Offset b) => (a - b).distance;

double _distanceToSegment(Offset point, Offset start, Offset end) {
  final delta = end - start;
  final lengthSquared = delta.dx * delta.dx + delta.dy * delta.dy;
  if (lengthSquared == 0) return _distance(point, start);
  final projection =
      ((point.dx - start.dx) * delta.dx + (point.dy - start.dy) * delta.dy) /
      lengthSquared;
  final t = math.max(0.0, math.min(1.0, projection));
  return _distance(point, start + delta * t);
}

List<int> _notationStepIndexes(
  ScienceNotationLabContent content, {
  required String? focusNeedCode,
}) {
  final all = List<int>.generate(content.tasks.length, (index) => index);
  if (focusNeedCode == null) return all;
  final matches = [
    for (final index in all)
      if (_notationNeedCode(content, index) == focusNeedCode) index,
  ];
  if (matches.length != 1) {
    throw ArgumentError.value(
      focusNeedCode,
      'focusNeedCode',
      'must identify exactly one catalog notation task',
    );
  }
  return List.unmodifiable(matches);
}

String? _notationNeedCode(ScienceNotationLabContent content, int index) {
  return content.tasks[index].needCode;
}

String _notationSolutionSummary(ScienceNotationLabContent content, int index) {
  return content.tasks[index].solutionSummary;
}

bool _sameOrder(List<String> actual, List<String> expected) {
  if (actual.length != expected.length) return false;
  for (var index = 0; index < actual.length; index++) {
    if (actual[index] != expected[index]) return false;
  }
  return true;
}

bool _debugValidateNotationContent(ScienceNotationLabContent content) {
  final tasks = content.tasks;
  if (tasks.length < 2 ||
      tasks.length > 6 ||
      tasks.map((task) => task.id).toSet().length != tasks.length ||
      tasks.map((task) => task.needCode).toSet().length != tasks.length ||
      tasks.map((task) => task.kind).toSet().length < 2 ||
      !tasks.any((task) => task is ScienceNotationArrangeTask) ||
      !tasks.any((task) => task is ScienceNotationChoiceTask)) {
    return false;
  }
  for (final task in tasks) {
    if (task.id.trim().isEmpty ||
        task.title.trim().isEmpty ||
        task.prompt.trim().isEmpty ||
        task.solutionSummary.trim().isEmpty ||
        task.needCode?.trim().isEmpty == true) {
      return false;
    }
    switch (task) {
      case ScienceNotationArrangeTask():
        final ids = task.tokens.map((token) => token.id).toSet();
        if (task.tokens.length < 2 ||
            task.tokens.length > 6 ||
            ids.length != task.tokens.length ||
            task.correctOrderIds.length != task.tokens.length ||
            task.correctOrderIds.toSet().length != task.tokens.length ||
            !task.correctOrderIds.every(ids.contains) ||
            _sameOrder(
              task.tokens.map((token) => token.id).toList(),
              task.correctOrderIds,
            )) {
          return false;
        }
        final trace = task.tracePattern;
        if (trace == null) continue;
        final strokeIds = trace.strokes.map((stroke) => stroke.id).toSet();
        if (trace.semanticsLabel.trim().isEmpty ||
            trace.strokes.isEmpty ||
            strokeIds.length != trace.strokes.length ||
            trace.strokeOrderIds.length != strokeIds.length ||
            trace.strokeOrderIds.toSet().length != strokeIds.length ||
            !trace.strokeOrderIds.every(strokeIds.contains) ||
            trace.strokes.any(
              (stroke) =>
                  stroke.label.trim().isEmpty ||
                  stroke.points.length < 3 ||
                  stroke.points.any(
                    (point) =>
                        !point.x.isFinite ||
                        !point.y.isFinite ||
                        point.x < 0 ||
                        point.x > 1 ||
                        point.y < 0 ||
                        point.y > 1,
                  ),
            )) {
          return false;
        }
      case ScienceNotationChoiceTask():
        final choiceIds = task.choices.map((choice) => choice.id).toSet();
        if (task.choices.length < 2 ||
            task.choices.length > 5 ||
            choiceIds.length != task.choices.length ||
            !choiceIds.contains(task.correctChoiceId) ||
            task.representationSemanticsLabel.trim().isEmpty ||
            task.representation.length > 10 ||
            (task.kind != LocalNotationTaskKind.symbolMatch &&
                task.representation.length < 2) ||
            task.representation.any((line) => line.trim().isEmpty)) {
          return false;
        }
    }
  }
  return true;
}
