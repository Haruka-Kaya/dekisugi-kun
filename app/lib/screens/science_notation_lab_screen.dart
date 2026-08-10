import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../learning/domain/learning_heart.dart';
import '../learning/domain/learning_need.dart';
import '../models/game_path.dart';
import '../models/unit.dart';
import '../ui/_material.dart';
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
class ScienceNotationLabContent {
  const ScienceNotationLabContent({
    required this.orderTasks,
    required this.symbolMatch,
    required this.graphRead,
  });

  /// 矢印のなぞりと式の組み立てを別課題として最低1つずつ渡す。
  final List<ScienceNotationOrderTask> orderTasks;
  final ScienceNotationSymbolTask symbolMatch;
  final ScienceNotationGraphTask graphRead;
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
  bool get _isOrderStep => _contentStep < widget.content.orderTasks.length;
  bool get _isSymbolStep => _contentStep == widget.content.orderTasks.length;
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
    final answered = _isOrderStep ? _orderedIds.isNotEmpty : _choiceId != null;
    if (!answered) return;

    final correct = switch ((_isOrderStep, _isSymbolStep)) {
      (true, _) => _sameOrder(
        _orderedIds,
        widget.content.orderTasks[_contentStep].correctOrderIds,
      ),
      (false, true) => _choiceId == widget.content.symbolMatch.correctChoiceId,
      (false, false) => _choiceId == widget.content.graphRead.correctChoiceId,
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
    if (_isOrderStep) {
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
    if (!_tracePending || !_traceCompleted || !_isOrderStep) return;
    _advanceStepAfterSuccess();
  }

  String? get _currentNeedCode => _isOrderStep
      ? widget.content.orderTasks[_contentStep].needCode
      : _isSymbolStep
      ? widget.content.symbolMatch.needCode
      : widget.content.graphRead.needCode;

  String _fixedTaskIdForStep() => _isOrderStep
      ? 'order:${widget.content.orderTasks[_contentStep].id}'
      : _isSymbolStep
      ? 'symbol'
      : 'graph';

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
    return Scaffold(
      key: const ValueKey('science-notation-lab-screen'),
      backgroundColor: colors.canvas,
      appBar: AppBar(
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
          body: '記号をなぞり、式を組み、グラフを読みます。',
          icon: Icons.draw_outlined,
          accent: colors.story,
          onAccent: colors.onStory,
          mascotReaction: GameCharacterReaction.thinking,
        ),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengeSurface(
          label: 'この単元の場面',
          icon: Icons.science_outlined,
          child: Text(
            '${_variant.transferPrompt}\n\n${_variant.cognitiveTask.prompt}',
          ),
        ),
        const SizedBox(height: GameTokens.spaceLg),
        if (_isOrderStep && _tracePending)
          _buildTraceStrengthening(
            context,
            widget.content.orderTasks[_contentStep],
          )
        else if (_isOrderStep)
          _buildOrderTask(context, widget.content.orderTasks[_contentStep])
        else if (_isSymbolStep)
          _buildSymbolTask(context)
        else
          _buildGraphTask(context),
        if (_lockedAfterWrong) ...[
          const SizedBox(height: GameTokens.spaceLg),
          _buildReview(context),
        ],
        const SizedBox(height: GameTokens.spaceLg),
        if (_tracePending)
          ScienceChallengePrimaryButton(
            key: const ValueKey('notation-trace-continue'),
            label: 'なぞりを終えて次へ',
            icon: Icons.arrow_forward_rounded,
            onPressed: _traceCompleted ? _finishTrace : null,
            backgroundColor: colors.story,
            foregroundColor: colors.onStory,
          )
        else
          ScienceChallengePrimaryButton(
            key: const ValueKey('notation-submit'),
            label: 'この組み方で確認する',
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
      (_isOrderStep
          ? _orderedIds.length ==
                widget.content.orderTasks[_contentStep].correctOrderIds.length
          : _choiceId != null);

  Widget _buildOrderTask(BuildContext context, ScienceNotationOrderTask task) {
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
            label: 'なぞる向き。${task.traceGuide}',
            child: Text(
              task.traceGuide,
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
                ? 'まだ何も並べていません'
                : '現在の並び。$selectedLabels',
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
                  selectedLabels.isEmpty ? 'ここに順番に並びます' : selectedLabels,
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
                  label: '組み札。${token.label}',
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
            label: const Text('送信前に組み直す'),
          ),
        ],
      ),
    );
  }

  Widget _buildTraceStrengthening(
    BuildContext context,
    ScienceNotationOrderTask task,
  ) {
    final colors = context.gamePalette;
    final canonical = task.correctOrderIds
        .map((id) => task.tokens.singleWhere((token) => token.id == id).label)
        .join('  ');
    return ScienceChallengeSurface(
      key: ValueKey('notation-trace-surface-${task.id}'),
      label: '正答のあとに、指で定着',
      icon: Icons.swipe_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            label: '正しい組み方。$canonical。${task.solutionSummary}',
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
            '線から指を離さず、表示された順に1本ずつなぞります。離れた場合は、その1本だけやり直します。',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
          ),
          const SizedBox(height: GameTokens.spaceMd),
          _NotationTraceBoard(
            key: ValueKey('notation-trace-board-${task.id}-$_traceSession'),
            pattern: task.tracePattern,
            onCompletedChanged: (complete) {
              if (!mounted || _traceCompleted == complete) return;
              setState(() => _traceCompleted = complete);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSymbolTask(BuildContext context) {
    final task = widget.content.symbolMatch;
    return ScienceChallengeSurface(
      label: '単位記号を意味と結ぶ',
      icon: Icons.straighten_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(task.prompt),
          const SizedBox(height: GameTokens.spaceLg),
          for (var index = 0; index < task.choices.length; index++) ...[
            ScienceMiniGameChoice(
              key: ValueKey('notation-symbol-${task.choices[index].id}'),
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

  Widget _buildGraphTask(BuildContext context) {
    final task = widget.content.graphRead;
    final colors = context.gamePalette;
    return ScienceChallengeSurface(
      label: 'グラフと矢印を読む',
      icon: Icons.show_chart_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(task.prompt),
          const SizedBox(height: GameTokens.spaceMd),
          Semantics(
            container: true,
            image: true,
            label: task.graphSemanticsLabel,
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
                    for (final line in task.graphNotation)
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
          const SizedBox(height: GameTokens.spaceLg),
          for (var index = 0; index < task.choices.length; index++) ...[
            ScienceMiniGameChoice(
              key: ValueKey('notation-graph-${task.choices[index].id}'),
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

  Widget _buildReview(BuildContext context) {
    final colors = context.gamePalette;
    return ScienceChallengeSurface(
      label: 'ここで一度、見直す',
      icon: Icons.lock_clock_outlined,
      backgroundColor: colors.surfaceRaised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('別の札を続けて押すことはできません。見直す点を1文だけ残すと、同じ課題を組み直せます。'),
          const SizedBox(height: GameTokens.spaceMd),
          TextField(
            key: const ValueKey('notation-review'),
            controller: _review,
            minLines: 2,
            maxLines: 4,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'どこを見直す？（6文字以上）',
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
            label: Text(_retryChecking ? 'ハートを確認中…' : 'この課題だけ組み直す'),
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
          title: '記号を意味とつなげました',
          body: widget.conceptLabel,
          icon: Icons.fact_check_outlined,
          accent: colors.pathComplete,
          onAccent: colors.onPathComplete,
          mascotReaction: GameCharacterReaction.celebrate,
        ),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengeSurface(
          label: '読み方の確認',
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
          label: 'Notation Labを完了する',
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
      _invalidateGesture('指が複数触れました。この線を1本の指でやり直します。');
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
        _error = '番号の付いた始点から始めてください。';
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
      _invalidateGesture('枠の外へ出ました。この線を始点からやり直します。');
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
      _invalidateGesture('線から離れました。この線を始点からやり直します。');
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
        _error = '途中で指が離れました。この線を始点からやり直します。';
      }
    });
    if (completed) widget.onCompletedChanged(_complete);
  }

  void _cancelGesture(int pointer) {
    if (!_activeGesture || pointer != _activePointer) return;
    _invalidateGesture('操作が中断されました。この線を始点からやり直します。');
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
        ? '全${widget.pattern.strokeOrderIds.length}本を完了しました。'
        : '${_completedStrokeIds.length + 1}本目、${current?.label ?? ''}。';
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
          '${widget.pattern.semanticsLabel} '
          'スクリーンリーダー用に、同じ線順をボタンで確認します。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('読み上げ操作では、線を同じ順番で1本ずつ確認します。'),
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
                  '${index + 1}本目、'
                  '${widget.pattern.strokeFor(widget.pattern.strokeOrderIds[index]).label}。'
                  '${index < _completedStrokeIds.length
                      ? '確認済み'
                      : index == _completedStrokeIds.length
                      ? '確認する'
                      : '前の線の確認後に使えます'}',
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
                  '${index + 1}本目：'
                  '${widget.pattern.strokeFor(widget.pattern.strokeOrderIds[index]).label}',
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
                  const Expanded(child: Text('全ての線を順番に確認しました。')),
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
  final all = List<int>.generate(
    content.orderTasks.length + 2,
    (index) => index,
  );
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
  if (index < content.orderTasks.length) {
    return content.orderTasks[index].needCode;
  }
  if (index == content.orderTasks.length) return content.symbolMatch.needCode;
  return content.graphRead.needCode;
}

String _notationSolutionSummary(ScienceNotationLabContent content, int index) {
  if (index < content.orderTasks.length) {
    return content.orderTasks[index].solutionSummary;
  }
  if (index == content.orderTasks.length) {
    return content.symbolMatch.solutionSummary;
  }
  return content.graphRead.solutionSummary;
}

bool _sameOrder(List<String> actual, List<String> expected) {
  if (actual.length != expected.length) return false;
  for (var index = 0; index < actual.length; index++) {
    if (actual[index] != expected[index]) return false;
  }
  return true;
}

bool _debugValidateNotationContent(ScienceNotationLabContent content) {
  if (content.orderTasks.length < 2 ||
      content.symbolMatch.choices.length < 2 ||
      content.graphRead.choices.length < 2 ||
      content.graphRead.graphNotation.length < 2) {
    return false;
  }
  for (final task in content.orderTasks) {
    final ids = task.tokens.map((token) => token.id).toSet();
    final strokeIds = task.tracePattern.strokes
        .map((stroke) => stroke.id)
        .toSet();
    if (task.tokens.length < 2 ||
        ids.length != task.tokens.length ||
        task.correctOrderIds.length < 2 ||
        task.correctOrderIds.toSet().length != task.correctOrderIds.length ||
        !task.correctOrderIds.every(ids.contains) ||
        task.tracePattern.semanticsLabel.trim().isEmpty ||
        task.tracePattern.strokes.isEmpty ||
        strokeIds.length != task.tracePattern.strokes.length ||
        task.tracePattern.strokeOrderIds.length != strokeIds.length ||
        task.tracePattern.strokeOrderIds.toSet().length != strokeIds.length ||
        !task.tracePattern.strokeOrderIds.every(strokeIds.contains) ||
        task.tracePattern.strokes.any(
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
  }
  final symbolIds = content.symbolMatch.choices
      .map((choice) => choice.id)
      .toSet();
  final graphIds = content.graphRead.choices.map((choice) => choice.id).toSet();
  return symbolIds.length == content.symbolMatch.choices.length &&
      symbolIds.contains(content.symbolMatch.correctChoiceId) &&
      graphIds.length == content.graphRead.choices.length &&
      graphIds.contains(content.graphRead.correctChoiceId);
}
