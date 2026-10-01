import 'dart:async';

import '../config/app_language.dart' as lang;
import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../config/motion.dart';
import '../learning/domain/learning_heart.dart';
import '../learning/domain/learning_need.dart';
import '../models/game_path.dart';
import '../models/mission.dart';
import '../models/unit.dart';
import '../ui/_material.dart';
import '../widgets/cognitive_task_input.dart';
import '../widgets/emphasis_text.dart';
import '../widgets/game_activity_scaffold.dart';
import '../widgets/readable_width.dart';
import '../widgets/science_challenge_support.dart';
import '../widgets/prediction_result_compare.dart';

String get _fallbackCheckpointHint => lang.t(
  '教材の成立条件と、選んだ説明の理由を見直す。',
  'Review the conditions in the material and the reason for your choice.',
);

/// 通信や生成AIを使わず、教材を読んだ直後の学習行為を最後まで続ける画面。
///
/// ここで行うのは本人による想起・補足・具体場面への適用、固定3択の確認、
/// 予想と教材の結果の自己比較だけ。入力は画面の [TextEditingController] にしか
/// 置かず、自動採点、理解度判定、[MissionPhase.clear] への更新、会話枠の消費を
/// 一切行わない。
class OfflinePracticeScreen extends StatefulWidget {
  const OfflinePracticeScreen({
    super.key,
    required this.section,
    required this.conceptLabel,
    required this.missionKind,
    this.practiceAttempt = 0,
    this.completionReference,
    this.onCheckpointCompleted,
    this.onNeedEvidence,
    this.onHeartLoss,
  });

  /// 直前に読んだ節。本文はcheckpointを正しく終えるまで再表示しない。
  final Section section;
  final String conceptLabel;
  final MissionKind missionKind;

  /// この概念を直前までに完了した回数。自由記述や選択回答ではなく、既存の
  /// 最小ローテーション記録だけから渡し、3種類の公開教材を巡回させる。
  final int practiceAttempt;

  /// 授業で教師が指定した教材番号。回答とは切り離し、完了画面で本人が
  /// 「指定された課題を最後まで見直した」ことだけを見せるために使う。
  /// 個人導線では表示しない。
  final String? completionReference;

  /// 正答内容や自由記述を渡さず、「この概念を最後まで練習した」という印だけ
  /// 端末内へ残すためのcallback。未指定なら従来どおり何も保存しない。
  final Future<void> Function()? onCheckpointCompleted;
  final LearningNeedEvidenceReported? onNeedEvidence;
  final LearningHeartLossReported? onHeartLoss;

  @override
  State<OfflinePracticeScreen> createState() => _OfflinePracticeScreenState();
}

enum _PracticeStep { recall, task, reasoning, checkpoint, compare, complete }

class _OfflinePracticeScreenState extends State<OfflinePracticeScreen> {
  final _recall = TextEditingController();
  final _reasoning = TextEditingController();
  final _checkpointCorrection = TextEditingController();
  final _reflection = TextEditingController();
  final _scroll = ScrollController();
  final _checkpointHintKey = GlobalKey();

  _PracticeStep _step = _PracticeStep.recall;
  CognitiveTaskResponse? _taskResponse;
  String? _selectedCheckpointOptionId;
  String? _wrongCheckpointOptionId;
  String? _learnerCheckpointCorrection;
  String? _taskRewriteBaseline;
  final Set<String> _reviewedCheckpointOptionIds = <String>{};
  bool _checkpointResolved = false;
  bool _rewritingTaskAfterResult = false;
  PredictionComparisonDecision? _comparisonDecision;
  bool _completionStarted = false;
  bool _progressSaving = false;
  bool _progressSaved = false;
  bool _progressSaveFailed = false;
  bool _needEvidenceReported = false;

  LocalPracticeVariant get _variant =>
      widget.section.practiceVariantForAttempt(widget.practiceAttempt);

  LocalCheckpoint get _checkpoint => _variant.checkpoint;

  LocalCognitiveTaskPrompt get _taskPrompt => _variant.cognitiveTask.prompt;

  String get _taskSummary => _taskResponse == null
      ? ''
      : cognitiveTaskResponseSummary(_taskPrompt, _taskResponse!);

  String get _solutionSummary =>
      cognitiveTaskSolutionSummary(_variant.cognitiveTask);

  String get _comparisonOutcome => lang.t(
    '教材の組み方\n$_solutionSummary\n\n現象の結果\n${_variant.expectedOutcome}',
    'Material\'s build\n$_solutionSummary\n\nResult\n${_variant.expectedOutcome}',
  );

  String get _correctCheckpointText =>
      _checkpoint.optionFor(_checkpoint.correctOptionId)?.text ?? '';

  int get _stepNumber => switch (_step) {
    _PracticeStep.recall => 1,
    _PracticeStep.task => 2,
    _PracticeStep.reasoning => 3,
    _PracticeStep.checkpoint ||
    _PracticeStep.compare ||
    _PracticeStep.complete => 4,
  };

  bool get _canContinue {
    return switch (_step) {
      _PracticeStep.recall => _recall.text.trim().isNotEmpty,
      _PracticeStep.task =>
        isCognitiveTaskResponseComplete(_taskPrompt, _taskResponse) &&
            (!_rewritingTaskAfterResult ||
                _taskSummary != _taskRewriteBaseline),
      _PracticeStep.reasoning => _reasoning.text.trim().isNotEmpty,
      _PracticeStep.compare => _reflection.text.trim().isNotEmpty,
      _PracticeStep.checkpoint || _PracticeStep.complete => false,
    };
  }

  bool get _canRetryCheckpoint {
    final correction = _checkpointCorrection.text.trim();
    return correction.isNotEmpty;
  }

  @override
  void dispose() {
    _recall.dispose();
    _reasoning.dispose();
    _checkpointCorrection.dispose();
    _reflection.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == _PracticeStep.checkpoint ||
        _step == _PracticeStep.compare ||
        _step == _PracticeStep.complete ||
        !_canContinue) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _step = switch (_step) {
        _PracticeStep.recall => _PracticeStep.task,
        _PracticeStep.task => _PracticeStep.reasoning,
        _PracticeStep.reasoning =>
          _checkpointResolved
              ? _PracticeStep.compare
              : _PracticeStep.checkpoint,
        _PracticeStep.checkpoint => _PracticeStep.checkpoint,
        _PracticeStep.compare => _PracticeStep.compare,
        _PracticeStep.complete => _PracticeStep.complete,
      };
      if (_step == _PracticeStep.compare) {
        _rewritingTaskAfterResult = false;
        _taskRewriteBaseline = null;
      }
    });
    _returnToTop();
  }

  void _back() {
    if (_step == _PracticeStep.recall ||
        _step == _PracticeStep.compare ||
        _step == _PracticeStep.complete) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _step = switch (_step) {
        _PracticeStep.task =>
          _rewritingTaskAfterResult ? _PracticeStep.task : _PracticeStep.recall,
        _PracticeStep.reasoning => _PracticeStep.task,
        _PracticeStep.checkpoint =>
          _wrongCheckpointOptionId == null
              ? _PracticeStep.reasoning
              : _PracticeStep.checkpoint,
        _PracticeStep.recall ||
        _PracticeStep.compare ||
        _PracticeStep.complete => _step,
      };
      if (_step == _PracticeStep.reasoning) {
        _selectedCheckpointOptionId = null;
      }
    });
    _returnToTop();
  }

  void _selectCheckpoint(String optionId) {
    if (_wrongCheckpointOptionId != null) return;
    setState(() {
      _selectedCheckpointOptionId = optionId;
    });
  }

  void _changeTaskResponse(CognitiveTaskResponse response) {
    if (_step != _PracticeStep.task) return;
    setState(() => _taskResponse = response);
  }

  void _submitCheckpoint() {
    if (_step != _PracticeStep.checkpoint || _wrongCheckpointOptionId != null) {
      return;
    }
    final selected = _selectedCheckpointOptionId;
    if (selected == null) return;

    if (selected == _checkpoint.correctOptionId) {
      if (_checkpointResolved) return;
      _reportNeed(
        _checkpoint.optionFor(selected),
        LearningNeedEvidenceKind.demonstrated,
      );
      setState(() {
        _checkpointResolved = true;
        _wrongCheckpointOptionId = null;
        _comparisonDecision = null;
        _reflection.clear();
        _step = _PracticeStep.compare;
      });
      _returnToTop();
      return;
    }

    _reportNeed(
      _checkpoint.optionFor(selected),
      LearningNeedEvidenceKind.observed,
    );
    widget.onHeartLoss?.call(
      LearningHeartLossEvidence(
        fixedTaskId: 'offline:${widget.practiceAttempt}:checkpoint',
      ),
    );

    setState(() {
      _wrongCheckpointOptionId = selected;
      _reviewedCheckpointOptionIds.add(selected);
      _selectedCheckpointOptionId = null;
      _checkpointCorrection.clear();
    });
    _showCheckpointHint();
  }

  void _reportNeed(
    LocalCheckpointOption? option,
    LearningNeedEvidenceKind kind,
  ) {
    final generalizedCode =
        option?.needCode ??
        _checkpoint.options
            .where((candidate) => candidate.id != _checkpoint.correctOptionId)
            .map((candidate) => candidate.needCode)
            .nonNulls
            .firstOrNull;
    if (_needEvidenceReported || generalizedCode == null) return;
    _needEvidenceReported = true;
    widget.onNeedEvidence?.call(
      LearningNeedEvidence(
        conceptKey: widget.section.conceptKey,
        needCode: generalizedCode,
        kind: kind,
      ),
    );
  }

  void _compareCheckpointCorrection() {
    if (_step != _PracticeStep.checkpoint ||
        _wrongCheckpointOptionId == null ||
        !_canRetryCheckpoint) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      // 誤答後に残りの選択肢を順番に試させない。本人が先に訂正文を
      // 作ってから教材の訂正と比較し、総当たりを完了条件にしない。
      _learnerCheckpointCorrection = _checkpointCorrection.text.trim();
      _checkpointResolved = true;
      _comparisonDecision = null;
      _reflection.clear();
      _step = _PracticeStep.compare;
    });
    _returnToTop();
  }

  void _chooseComparisonDecision(PredictionComparisonDecision decision) {
    if (_step != _PracticeStep.compare) return;
    setState(() => _comparisonDecision = decision);
  }

  void _rewriteTask() {
    if (_step != _PracticeStep.compare) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _rewritingTaskAfterResult = true;
      _taskRewriteBaseline = _taskSummary;
      _reasoning.clear();
      _comparisonDecision = null;
      _reflection.clear();
      _step = _PracticeStep.task;
    });
    _returnToTop();
  }

  void _completeComparison() {
    if (_step != _PracticeStep.compare ||
        _comparisonDecision == null ||
        _reflection.text.trim().isEmpty ||
        _completionStarted) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    _completionStarted = true;
    setState(() => _step = _PracticeStep.complete);
    _returnToTop();
    if (widget.onCheckpointCompleted != null) {
      unawaited(_savePracticeProgress());
    }
  }

  Future<void> _savePracticeProgress() async {
    final save = widget.onCheckpointCompleted;
    if (save == null || _progressSaving || _progressSaved) return;
    setState(() {
      _progressSaving = true;
      _progressSaveFailed = false;
    });
    try {
      await save();
      if (!mounted) return;
      setState(() {
        _progressSaving = false;
        _progressSaved = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _progressSaving = false;
        _progressSaveFailed = true;
      });
    }
  }

  void _showCheckpointHint() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final hintContext = _checkpointHintKey.currentContext;
      if (hintContext == null) return;
      final reduceMotion = ReduceMotionScope.of(context);
      unawaited(
        Scrollable.ensureVisible(
          hintContext,
          // フィードバックは200%文字でも画面より高くなり得る。末尾へ合わせると
          // 見出しと「選んだ考え」が画面外へ消えるため、必ず先頭から見せる。
          alignment: 0,
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  void _returnToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(0);
    });
  }

  void _goHome() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final hasSharedChrome = GameActivityScaffold.hasSharedChrome(context);
    return Scaffold(
      key: const ValueKey('offline-practice-screen'),
      backgroundColor: colors.canvas,
      appBar: hasSharedChrome
          ? null
          : AppBar(
              backgroundColor: colors.canvas,
              foregroundColor: colors.ink,
              surfaceTintColor: Colors.transparent,
              title: Text(
                widget.missionKind == MissionKind.caseRetry
                    ? lang.t('総合検証', 'Chapter boss')
                    : lang.t('端末内で練習', 'On-device practice'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.jaWeight(FontWeight.w700),
              ),
            ),
      body: SafeArea(
        top: false,
        child: ReadableWidth(
          child: SingleChildScrollView(
            key: const ValueKey('offline-practice-scroll'),
            controller: _scroll,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _LocalOnlyNotice(),
                const SizedBox(height: 22),
                if (_step == _PracticeStep.complete)
                  _Completion(
                    section: widget.section,
                    expectedOutcome: _variant.expectedOutcome,
                    expectedReason: _variant.expectedReason,
                    solutionSummary: _solutionSummary,
                    checkpointCorrection: _correctCheckpointText,
                    checkpointExplanation: _checkpoint.explanation,
                    learnerCheckpointCorrection: _learnerCheckpointCorrection,
                    conceptLabel: widget.conceptLabel,
                    completionReference: widget.completionReference,
                    recall: _recall.text.trim(),
                    reasoning: _reasoning.text.trim(),
                    taskResponse: _taskSummary,
                    comparisonDecision: _comparisonDecision!,
                    reflection: _reflection.text.trim(),
                    recordsPracticeMark: widget.onCheckpointCompleted != null,
                    progressSaving: _progressSaving,
                    progressSaved: _progressSaved,
                    progressSaveFailed: _progressSaveFailed,
                    onRetryProgress: _savePracticeProgress,
                    onHome: _goHome,
                  )
                else ...[
                  _PracticeHeader(
                    step: _stepNumber,
                    conceptLabel: widget.conceptLabel,
                    missionKind: widget.missionKind,
                    practiceStage: _variant.stage,
                  ),
                  const SizedBox(height: 26),
                  switch (_step) {
                    _PracticeStep.recall => _RecallStep(
                      prompt: _variant.recallPrompt,
                      controller: _recall,
                      canContinue: _canContinue,
                      onChanged: (_) => setState(() {}),
                      onNext: _next,
                    ),
                    _PracticeStep.task => _TaskStep(
                      prompt: _variant.transferPrompt,
                      taskPrompt: _taskPrompt,
                      response: _taskResponse,
                      rewritingAfterResult: _rewritingTaskAfterResult,
                      canContinue: _canContinue,
                      onChanged: _changeTaskResponse,
                      onBack: _back,
                      onNext: _next,
                    ),
                    _PracticeStep.reasoning => _ReasoningStep(
                      prompt: _variant.reasoningPrompt,
                      taskPrompt: _taskPrompt,
                      response: _taskResponse!,
                      controller: _reasoning,
                      canContinue: _canContinue,
                      onChanged: (_) => setState(() {}),
                      onBack: _back,
                      onNext: _next,
                    ),
                    _PracticeStep.checkpoint => _CheckpointStep(
                      checkpoint: _checkpoint,
                      selectedOptionId: _selectedCheckpointOptionId,
                      wrongOptionId: _wrongCheckpointOptionId,
                      reviewedOptionIds: _reviewedCheckpointOptionIds,
                      hintKey: _checkpointHintKey,
                      correctionController: _checkpointCorrection,
                      canRetry: _canRetryCheckpoint,
                      onSelect: _selectCheckpoint,
                      onSubmit: _submitCheckpoint,
                      onCorrectionChanged: () => setState(() {}),
                      onRetry: _compareCheckpointCorrection,
                      onBack: _back,
                    ),
                    _PracticeStep.compare => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CheckpointResolution(
                          correction: _correctCheckpointText,
                          explanation: _checkpoint.explanation,
                          learnerCorrection: _learnerCheckpointCorrection,
                          liveRegion: true,
                        ),
                        const SizedBox(height: 22),
                        PredictionResultCompare(
                          situation: _variant.transferPrompt,
                          prediction: _taskSummary,
                          predictionReason: _reasoning.text.trim(),
                          result: _comparisonOutcome,
                          explanation: _variant.expectedReason,
                          sourceParagraphs: widget.section.body,
                          decision: _comparisonDecision,
                          reflectionController: _reflection,
                          onDecisionChanged: _chooseComparisonDecision,
                          onReflectionChanged: () => setState(() {}),
                          onRewritePrediction: _rewriteTask,
                          onComplete: _completeComparison,
                        ),
                      ],
                    ),
                    _PracticeStep.complete => const SizedBox.shrink(),
                  },
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LocalOnlyNotice extends StatelessWidget {
  const _LocalOnlyNotice();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    return Semantics(
      container: true,
      label: lang.t(
        '端末内だけの練習。入力は送信も保存もされません',
        'On-device practice only. Your input is not sent or saved',
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(GameTokens.radiusMd),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(Icons.phonelink_lock_outlined, color: colors.ink),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                lang.t(
                  'この練習は端末内だけで進みます。入力は送信・保存されません。',
                  'This practice runs only on your device. Your input is not sent or saved.',
                ),
                style: t.textTheme.bodyMedium?.copyWith(color: colors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeHeader extends StatelessWidget {
  const _PracticeHeader({
    required this.step,
    required this.conceptLabel,
    required this.missionKind,
    required this.practiceStage,
  });

  final int step;
  final String conceptLabel;
  final MissionKind missionKind;
  final LocalPracticeStage practiceStage;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final reaction = switch (step) {
      1 => GameCharacterReaction.invite,
      2 || 3 => GameCharacterReaction.thinking,
      _ => GameCharacterReaction.encourage,
    };
    return Semantics(
      key: ValueKey('offline-practice-step-$step'),
      container: true,
      liveRegion: true,
      label: lang.t(
        '端末内練習、4段階のうち$step段階目',
        'On-device practice, step $step of 4',
      ),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScienceChallengeHeader(
              eyebrow:
                  'ラボ・ブリーフ  /  総合検証  /  ${practiceStage.label}  /  $step/4',
              title: conceptLabel,
              body: _missionLabel,
              icon: Icons.fitness_center_rounded,
              accent: colors.pathReview,
              onAccent: colors.onPathReview,
              mascotReaction: reaction,
            ),
            const SizedBox(height: GameTokens.spaceSm),
            LinearProgressIndicator(
              value: step / 4,
              minHeight: GameTokens.compactProgressTrackHeight,
              color: colors.pathReview,
              backgroundColor: colors.surfaceRaised,
              borderRadius: BorderRadius.circular(GameTokens.radiusPill),
            ),
          ],
        ),
      ),
    );
  }

  String get _missionLabel => switch (missionKind) {
    MissionKind.teach => lang.t('自分の言葉で説明', 'Explain in your own words'),
    MissionKind.repair => lang.t('説明を組み直す', 'Rebuild your explanation'),
    MissionKind.caseRetry => lang.t('別の場面で確かめる', 'Test it in a new scenario'),
  };
}

class _RecallStep extends StatelessWidget {
  const _RecallStep({
    required this.prompt,
    required this.controller,
    required this.canContinue,
    required this.onChanged,
    required this.onNext,
  });

  final String prompt;
  final TextEditingController controller;
  final bool canContinue;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: lang.t('第1段階、教材を見ずに説明する', 'Step 1: explain without the material'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepTitle(
            number: '01',
            title: lang.t('教材を閉じたまま、説明する', 'Explain with the material closed'),
            body: prompt,
          ),
          const SizedBox(height: 18),
          _PracticeInput(
            key: const ValueKey('offline-recall-input'),
            controller: controller,
            label: lang.t('自分の説明', 'Your explanation'),
            hint: lang.t('結論から書いてみる', 'Start with your conclusion'),
            onChanged: onChanged,
          ),
          const SizedBox(height: 10),
          const _InputRequirement(),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const ValueKey('offline-recall-next'),
            onPressed: canContinue ? onNext : null,
            icon: const Icon(Icons.arrow_forward),
            label: Text(lang.t('説明を書いた', 'I\'ve written it')),
          ),
        ],
      ),
    );
  }
}

class _TaskStep extends StatelessWidget {
  const _TaskStep({
    required this.prompt,
    required this.taskPrompt,
    required this.response,
    required this.rewritingAfterResult,
    required this.canContinue,
    required this.onChanged,
    required this.onBack,
    required this.onNext,
  });

  final String prompt;
  final LocalCognitiveTaskPrompt taskPrompt;
  final CognitiveTaskResponse? response;
  final bool rewritingAfterResult;
  final bool canContinue;
  final ValueChanged<CognitiveTaskResponse> onChanged;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: rewritingAfterResult
          ? lang.t(
              '第2段階へ戻り、教材の結果を閉じて科学タスクを組み直す',
              'Back to step 2: hide the result and rebuild the science task',
            )
          : lang.t(
              '第2段階、具体場面を科学タスクで考える',
              'Step 2: work through a real scenario with a science task',
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepTitle(
            number: '02',
            title: rewritingAfterResult
                ? lang.t('結果を閉じて、組み直す', 'Hide the result and rebuild')
                : lang.t('科学タスクを、組む', 'Build the science task'),
            body: rewritingAfterResult
                ? lang.t(
                    'さっき見た結果は表示しません。カードを使って、自分の答えをもう一度組みます。',
                    'The result you just saw is hidden. Use the cards to build your answer again.',
                  )
                : lang.t(
                    '文章を写す代わりに、選ぶ・分類する・順に組む操作で考えます。',
                    'Instead of copying text, think by choosing, sorting, and ordering.',
                  ),
          ),
          const SizedBox(height: 18),
          _TryIt(situation: prompt),
          const SizedBox(height: 18),
          CognitiveTaskInput(
            prompt: taskPrompt,
            response: response,
            onChanged: onChanged,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const ValueKey('offline-task-next'),
            onPressed: canContinue ? onNext : null,
            icon: const Icon(Icons.arrow_forward),
            label: Text(
              rewritingAfterResult
                  ? lang.t(
                      '組み直した答えに理由を足す',
                      'Add a reason to your rebuilt answer',
                    )
                  : lang.t('この答えに理由を足す', 'Add a reason to this answer'),
            ),
          ),
          if (!rewritingAfterResult) ...[
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              label: Text(
                lang.t('最初の説明を書き直す', 'Rewrite your first explanation'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReasoningStep extends StatelessWidget {
  const _ReasoningStep({
    required this.prompt,
    required this.taskPrompt,
    required this.response,
    required this.controller,
    required this.canContinue,
    required this.onChanged,
    required this.onBack,
    required this.onNext,
  });

  final String prompt;
  final LocalCognitiveTaskPrompt taskPrompt;
  final CognitiveTaskResponse response;
  final TextEditingController controller;
  final bool canContinue;
  final ValueChanged<String> onChanged;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: lang.t(
        '第3段階、組んだ答えの根拠を一つ書く',
        'Step 3: write one reason for your answer',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepTitle(
            number: '03',
            title: lang.t('決め手を、1つ書く', 'Write one key reason'),
            body: prompt,
          ),
          const SizedBox(height: 18),
          CognitiveTaskResponseSummary(prompt: taskPrompt, response: response),
          const SizedBox(height: 18),
          _PracticeInput(
            key: const ValueKey('offline-reasoning-input'),
            controller: controller,
            label: lang.t('この答えにした理由', 'Why you chose this answer'),
            hint: lang.t(
              '条件・力の向き・変化の順など、決め手を1つ',
              'One key reason: a condition, force direction, order of change, etc.',
            ),
            onChanged: onChanged,
          ),
          const SizedBox(height: 10),
          const _InputRequirement(),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const ValueKey('offline-reasoning-next'),
            onPressed: canContinue ? onNext : null,
            icon: const Icon(Icons.arrow_forward),
            label: Text(lang.t('チェックポイントへ', 'To the checkpoint')),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            label: Text(lang.t('科学タスクを組み直す', 'Rebuild the science task')),
          ),
        ],
      ),
    );
  }
}

class _CheckpointStep extends StatelessWidget {
  const _CheckpointStep({
    required this.checkpoint,
    required this.selectedOptionId,
    required this.wrongOptionId,
    required this.reviewedOptionIds,
    required this.hintKey,
    required this.correctionController,
    required this.canRetry,
    required this.onSelect,
    required this.onSubmit,
    required this.onCorrectionChanged,
    required this.onRetry,
    required this.onBack,
  });

  final LocalCheckpoint checkpoint;
  final String? selectedOptionId;
  final String? wrongOptionId;
  final Set<String> reviewedOptionIds;
  final GlobalKey hintKey;
  final TextEditingController correctionController;
  final bool canRetry;
  final ValueChanged<String> onSelect;
  final VoidCallback onSubmit;
  final VoidCallback onCorrectionChanged;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    final wrongOption = wrongOptionId == null
        ? null
        : checkpoint.optionFor(wrongOptionId!);
    final wrongHint = wrongOption == null
        ? null
        : wrongOption.hint ?? _fallbackCheckpointHint;

    return Semantics(
      key: const ValueKey('offline-checkpoint-step'),
      container: true,
      label: lang.t('第4段階、固定の思い込みを見破る', 'Step 4: catch the misconception'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepTitle(
            number: '04',
            title: lang.t('思い込みを、見破る', 'Catch the misconception'),
            body: lang.t(
              'ある生徒のメモを読んで、科学的に正しく直している選択肢を1つ選んでください。',
              'Read a student\'s note and choose the one option that fixes it correctly, scientifically.',
            ),
          ),
          const SizedBox(height: 18),
          _CheckpointLure(lure: checkpoint.lure),
          const SizedBox(height: 20),
          Text(
            lang.t('正しく直しているのはどれ？', 'Which one fixes it correctly?'),
            style: t.textTheme.titleMedium?.jaWeight(FontWeight.w700),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < checkpoint.options.length; i++) ...[
            _CheckpointChoice(
              index: i,
              option: checkpoint.options[i],
              selected: selectedOptionId == checkpoint.options[i].id,
              reviewed: reviewedOptionIds.contains(checkpoint.options[i].id),
              onTap: wrongOptionId == null
                  ? () => onSelect(checkpoint.options[i].id)
                  : null,
            ),
            if (i != checkpoint.options.length - 1) const SizedBox(height: 10),
          ],
          if (wrongHint != null && wrongOption != null) ...[
            const SizedBox(height: 14),
            _CheckpointHint(
              key: hintKey,
              attemptedOption: wrongOption.text,
              hint: wrongHint,
            ),
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('offline-checkpoint-correction-input'),
              controller: correctionController,
              minLines: 3,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              onChanged: (_) => onCorrectionChanged(),
              decoration: InputDecoration(
                labelText: lang.t('訂正メモ', 'Correction note'),
                hintText: lang.t(
                  'このメモのどこを、どう直すかを1文で書く',
                  'In one sentence, write what to fix in this note and how',
                ),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              lang.t(
                'この訂正メモも送信・保存しません。書いたあと、教材の直し方と見比べます。',
                'This correction note isn\'t sent or saved either. After writing it, compare it with the material\'s fix.',
              ),
              style: t.textTheme.bodySmall?.copyWith(color: colors.inkMuted),
            ),
          ],
          const SizedBox(height: 18),
          if (wrongHint != null)
            FilledButton.icon(
              key: const ValueKey('offline-checkpoint-retry'),
              onPressed: canRetry ? onRetry : null,
              icon: const Icon(Icons.compare_arrows_outlined),
              label: Text(
                lang.t('訂正メモと答えを比べる', 'Compare your note with the answer'),
              ),
            )
          else
            FilledButton.icon(
              key: const ValueKey('offline-checkpoint-submit'),
              onPressed: selectedOptionId == null ? null : onSubmit,
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(lang.t('この直し方で決める', 'Go with this fix')),
            ),
          const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: colors.inkMuted),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  lang.t(
                    'これは固定3択の確認です。この結果だけで習得とは判定しません。',
                    'This is a fixed 3-choice check. This result alone doesn\'t mean you\'ve mastered it.',
                  ),
                  style: t.textTheme.bodySmall?.copyWith(
                    color: colors.inkMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (wrongHint == null)
            TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
              label: Text(
                lang.t(
                  '科学タスクの根拠を書き直す',
                  'Rewrite your reason for the science task',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// checkpointで扱った思い込みの訂正。正答後の比較・完了面でだけbuildする。
class _CheckpointResolution extends StatelessWidget {
  const _CheckpointResolution({
    required this.correction,
    required this.explanation,
    required this.liveRegion,
    this.learnerCorrection,
  });

  final String correction;
  final String explanation;
  final bool liveRegion;
  final String? learnerCorrection;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    return Semantics(
      key: const ValueKey('offline-checkpoint-resolution'),
      container: true,
      liveRegion: liveRegion,
      label: lang.t(
        '${learnerCorrection == null ? '' : 'あなたの訂正メモ。$learnerCorrection。'}'
            '思い込みの直し方。$correction。理由。$explanation',
        '${learnerCorrection == null ? '' : 'Your correction note. $learnerCorrection. '}'
            'How to fix the misconception. $correction. Reason. $explanation',
      ),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(GameTokens.radiusMd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.psychology_alt_outlined, color: colors.ink),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      lang.t('思い込みの直し方', 'How to fix the misconception'),
                      style: t.textTheme.titleSmall
                          ?.copyWith(color: colors.ink)
                          .jaWeight(FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              if (learnerCorrection case final learner?) ...[
                Text(
                  lang.t('あなたの訂正メモ', 'Your correction note'),
                  style: t.textTheme.labelMedium
                      ?.copyWith(color: colors.ink)
                      .jaWeight(FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  learner,
                  style: t.textTheme.bodyMedium?.copyWith(color: colors.ink),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                lang.t('教材の直し方', 'Material\'s fix'),
                style: t.textTheme.labelMedium
                    ?.copyWith(color: colors.ink)
                    .jaWeight(FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                correction,
                style: t.textTheme.bodyLarge?.copyWith(color: colors.ink),
              ),
              const SizedBox(height: 8),
              Text(
                explanation,
                style: t.textTheme.bodyMedium?.copyWith(color: colors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckpointLure extends StatelessWidget {
  const _CheckpointLure({required this.lure});

  final String lure;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    return Semantics(
      container: true,
      label: lang.t('見破る思い込み。$lure', 'Misconception to catch. $lure'),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
          decoration: BoxDecoration(
            color: colors.legendary,
            borderRadius: BorderRadius.circular(GameTokens.radiusMd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.psychology_alt_outlined,
                    size: 21,
                    color: colors.onLegendary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lang.t('ある生徒のメモ', 'A student\'s note'),
                      style: t.textTheme.labelLarge
                          ?.copyWith(color: colors.onLegendary)
                          .jaWeight(FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '「$lure」',
                style: t.textTheme.bodyLarge?.copyWith(
                  color: colors.onLegendary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckpointChoice extends StatelessWidget {
  const _CheckpointChoice({
    required this.index,
    required this.option,
    required this.selected,
    required this.reviewed,
    required this.onTap,
  });

  final int index;
  final LocalCheckpointOption option;
  final bool selected;
  final bool reviewed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    final reviewedLabel = reviewed
        ? lang.t(' 前回、見直した選択肢です。', ' You reviewed this option last time.')
        : '';
    return Semantics(
      key: ValueKey('offline-checkpoint-option-${option.id}'),
      button: true,
      enabled: onTap != null,
      selected: selected,
      onTap: onTap,
      label: lang.t(
        '選択肢${index + 1}。${option.text}$reviewedLabel',
        'Option ${index + 1}. ${option.text}$reviewedLabel',
      ),
      child: ExcludeSemantics(
        child: Material(
          color: selected ? colors.pathActive : colors.surface,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: selected ? colors.pathActive : colors.border,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(GameTokens.radiusMd),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        selected
                            ? Icons.radio_button_checked
                            : reviewed
                            ? Icons.replay_circle_filled_outlined
                            : Icons.radio_button_unchecked,
                        color: selected ? colors.onPathActive : colors.inkMuted,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        option.text,
                        style: t.textTheme.bodyMedium?.copyWith(
                          color: selected ? colors.onPathActive : colors.ink,
                        ),
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

class _CheckpointHint extends StatelessWidget {
  const _CheckpointHint({
    super.key,
    required this.attemptedOption,
    required this.hint,
  });

  final String attemptedOption;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    return Semantics(
      container: true,
      liveRegion: true,
      label: lang.t(
        'まだ決着していません。選んだ考え、$attemptedOption。見直す観点、$hint。訂正メモを書いてから再検証します',
        'Not settled yet. Your choice: $attemptedOption. What to review: $hint. Write a correction note, then try again',
      ),
      child: ExcludeSemantics(
        child: Container(
          key: const ValueKey('offline-checkpoint-hint'),
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(GameTokens.radiusMd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, color: colors.pathReview),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      lang.t('まだ決着していません', 'Not settled yet'),
                      style: t.textTheme.labelLarge
                          ?.copyWith(color: colors.pathReview)
                          .jaWeight(FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _FeedbackLine(
                label: lang.t('選んだ考え', 'Your choice'),
                text: attemptedOption,
                foreground: colors.pathReview,
              ),
              const SizedBox(height: 10),
              Container(
                height: 1,
                color: colors.pathReview.withValues(alpha: 0.28),
              ),
              const SizedBox(height: 9),
              _FeedbackLine(
                label: lang.t('見直す観点', 'What to review'),
                text: hint,
                foreground: colors.pathReview,
              ),
              const SizedBox(height: 7),
              Text(
                lang.t(
                  '別の選択肢を試す前に、このメモの直し方を一文にします。',
                  'Before trying another option, write in one sentence how to fix this note.',
                ),
                style: t.textTheme.bodySmall?.copyWith(
                  color: colors.pathReview,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedbackLine extends StatelessWidget {
  const _FeedbackLine({
    required this.label,
    required this.text,
    required this.foreground,
  });

  final String label;
  final String text;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: t.textTheme.labelMedium
              ?.copyWith(color: foreground)
              .jaWeight(FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(text, style: t.textTheme.bodyMedium?.copyWith(color: foreground)),
      ],
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({
    required this.number,
    required this.title,
    required this.body,
  });

  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '手順 $number',
          style: t.textTheme.labelMedium
              ?.copyWith(color: colors.pathReview)
              .jaWeight(FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Text(title, style: t.textTheme.titleLarge?.jaWeight(FontWeight.w800)),
        const SizedBox(height: 8),
        Text(body, style: t.textTheme.bodyLarge),
      ],
    );
  }
}

class _PracticeInput extends StatelessWidget {
  const _PracticeInput({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: 4,
      maxLines: 8,
      textInputAction: TextInputAction.newline,
      keyboardType: TextInputType.multiline,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: true,
      ),
    );
  }
}

class _InputRequirement extends StatelessWidget {
  const _InputRequirement();

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.edit_note_outlined, size: 18, color: colors.inkMuted),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            lang.t(
              '自分の言葉を1つ以上書くと、次へ進めます。',
              'Write at least one thing in your own words to continue.',
            ),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
          ),
        ),
      ],
    );
  }
}

class _TryIt extends StatelessWidget {
  const _TryIt({required this.situation});

  final String situation;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.pathReview),
        borderRadius: BorderRadius.circular(GameTokens.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science_outlined, size: 20, color: colors.pathReview),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lang.t('この場面を考える', 'Think about this scenario'),
                  style: t.textTheme.labelLarge
                      ?.copyWith(color: colors.pathReview)
                      .jaWeight(FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(situation, style: t.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _Completion extends StatelessWidget {
  const _Completion({
    required this.section,
    required this.expectedOutcome,
    required this.expectedReason,
    required this.solutionSummary,
    required this.checkpointCorrection,
    required this.checkpointExplanation,
    required this.learnerCheckpointCorrection,
    required this.conceptLabel,
    required this.completionReference,
    required this.recall,
    required this.reasoning,
    required this.taskResponse,
    required this.comparisonDecision,
    required this.reflection,
    required this.recordsPracticeMark,
    required this.progressSaving,
    required this.progressSaved,
    required this.progressSaveFailed,
    required this.onRetryProgress,
    required this.onHome,
  });

  final Section section;
  final String expectedOutcome;
  final String expectedReason;
  final String solutionSummary;
  final String checkpointCorrection;
  final String checkpointExplanation;
  final String? learnerCheckpointCorrection;
  final String conceptLabel;
  final String? completionReference;
  final String recall;
  final String reasoning;
  final String taskResponse;
  final PredictionComparisonDecision comparisonDecision;
  final String reflection;
  final bool recordsPracticeMark;
  final bool progressSaving;
  final bool progressSaved;
  final bool progressSaveFailed;
  final Future<void> Function() onRetryProgress;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    final isClassroomCompletion = completionReference != null;
    return Semantics(
      key: const ValueKey('offline-practice-complete'),
      container: true,
      liveRegion: true,
      label: lang.t(
        '端末内練習を完了。${completionReference == null ? '' : '教材番号$completionReference。'}'
            'この課題を最後まで見直しました',
        'On-device practice complete. ${completionReference == null ? '' : 'Material No. $completionReference. '}'
            'You reviewed this task to the end',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: ScienceChallengeHeader(
              eyebrow: 'ラボ・ブリーフ  /  総合検証  /  記録',
              title: conceptLabel,
              body: lang.t(
                '自分で組んだ答えと教材の組み方を比べ、この課題を最後まで見直しました。',
                'You compared your build with the material\'s and reviewed this task to the end.',
              ),
              icon: Icons.fact_check_outlined,
              accent: colors.pathComplete,
              onAccent: colors.onPathComplete,
              mascotReaction: GameCharacterReaction.celebrate,
            ),
          ),
          if (completionReference != null) ...[
            const SizedBox(height: 14),
            Semantics(
              key: const ValueKey('offline-completion-reference'),
              container: true,
              label: lang.t(
                '完了確認。教材番号$completionReference。この課題を最後まで見直しました',
                'Completion check. Material No. $completionReference. You reviewed this task to the end',
              ),
              child: ExcludeSemantics(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
                  decoration: BoxDecoration(
                    color: colors.surfaceRaised,
                    borderRadius: BorderRadius.circular(GameTokens.radiusMd),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.assignment_turned_in_outlined,
                        color: colors.ink,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.t(
                                '教材番号 $completionReference',
                                'Material No. $completionReference',
                              ),
                              style: t.textTheme.titleSmall
                                  ?.copyWith(color: colors.ink)
                                  .jaWeight(FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lang.t(
                                'この課題を最後まで見直しました。',
                                'You reviewed this task to the end.',
                              ),
                              style: t.textTheme.bodyMedium?.copyWith(
                                color: colors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 22),
          Container(
            key: const ValueKey('offline-comparison-takeaway'),
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
            decoration: BoxDecoration(
              color: colors.legendary,
              borderRadius: BorderRadius.circular(GameTokens.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.change_circle_outlined,
                      color: colors.onLegendary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        comparisonDecision.actionLabel,
                        style: t.textTheme.labelLarge
                            ?.copyWith(color: colors.onLegendary)
                            .jaWeight(FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(
                  reflection,
                  style: t.textTheme.bodyLarge?.copyWith(
                    color: colors.onLegendary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _CheckpointResolution(
            correction: checkpointCorrection,
            explanation: checkpointExplanation,
            learnerCorrection: learnerCheckpointCorrection,
            liveRegion: false,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
            decoration: BoxDecoration(
              color: colors.surfaceRaised,
              borderRadius: BorderRadius.circular(GameTokens.radiusMd),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: colors.ink),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        lang.t('教材の結果と理由', 'Material\'s result and reason'),
                        style: t.textTheme.labelLarge
                            ?.copyWith(color: colors.ink)
                            .jaWeight(FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  lang.t('教材の組み方', 'Material\'s build'),
                  style: t.textTheme.labelMedium
                      ?.copyWith(color: colors.ink)
                      .jaWeight(FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  solutionSummary,
                  style: t.textTheme.bodyMedium?.copyWith(color: colors.ink),
                ),
                const SizedBox(height: 10),
                Container(height: 1, color: colors.ink.withValues(alpha: 0.24)),
                const SizedBox(height: 9),
                Text(
                  lang.t('教材で確かめた結果', 'Result confirmed by the material'),
                  style: t.textTheme.labelMedium
                      ?.copyWith(color: colors.ink)
                      .jaWeight(FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  expectedOutcome,
                  style: t.textTheme.bodyMedium?.copyWith(color: colors.ink),
                ),
                const SizedBox(height: 10),
                Container(height: 1, color: colors.ink.withValues(alpha: 0.24)),
                const SizedBox(height: 9),
                Text(
                  lang.t('教材の理由', 'Material\'s reason'),
                  style: t.textTheme.labelMedium
                      ?.copyWith(color: colors.ink)
                      .jaWeight(FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  expectedReason,
                  style: t.textTheme.bodyMedium?.copyWith(color: colors.ink),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Semantics(
            container: true,
            liveRegion: recordsPracticeMark,
            child: Container(
              padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
              decoration: BoxDecoration(
                color: colors.surfaceRaised,
                borderRadius: BorderRadius.circular(GameTokens.radiusMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: colors.ink),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          lang.t(
                            '自由記述は送信・保存していません。固定3択は習得判定ではなく、'
                                'カードの選択・分類・順序も保存せず、理解度や会話枠も更新しません。',
                            'Your free-text answers weren\'t sent or saved. The fixed 3-choice check doesn\'t judge how well you\'ve learned it. Card choices, sorting, and order aren\'t saved, and your understanding level and conversation slots aren\'t updated.',
                          ),
                          style: t.textTheme.bodyMedium?.copyWith(
                            color: colors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (recordsPracticeMark) ...[
                    const SizedBox(height: 10),
                    if (progressSaving)
                      Row(
                        children: [
                          SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.ink,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              isClassroomCompletion
                                  ? lang.t(
                                      '授業の完了確認を、この端末に残しています。',
                                      'Class completion is saved on this device.',
                                    )
                                  : lang.t(
                                      '練習済みの印を、この端末に残しています。',
                                      'A practiced mark is saved on this device.',
                                    ),
                              style: t.textTheme.bodySmall?.copyWith(
                                color: colors.ink,
                              ),
                            ),
                          ),
                        ],
                      )
                    else if (progressSaved)
                      Text(
                        isClassroomCompletion
                            ? lang.t(
                                '教材番号・概念・A/B/C・完了状態・日時だけを、'
                                    'この端末に授業の完了確認として残しました。'
                                    '回答内容と理解は記録・確認していません。',
                                'Only the material No., concept, A/B/C, completion status, and date were saved on this device as class completion. Your answers and understanding were not recorded or checked.',
                              )
                            : lang.t(
                                '教材と概念、完了回数、最終完了日時だけを、'
                                    'この端末に練習済みの印として残しました。',
                                'Only the material, concept, completion count, and last completion date were saved on this device as a practiced mark.',
                              ),
                        style: t.textTheme.bodySmall?.copyWith(
                          color: colors.ink,
                        ),
                      )
                    else if (progressSaveFailed) ...[
                      Text(
                        isClassroomCompletion
                            ? lang.t(
                                '授業の完了確認を保存できませんでした。'
                                    '回答内容は保存されていません。',
                                'Couldn\'t save class completion. Your answers were not saved.',
                              )
                            : lang.t(
                                '練習済みの印を保存できませんでした。'
                                    '自由記述は保存されていません。',
                                'Couldn\'t save the practiced mark. Your free-text answers were not saved.',
                              ),
                        style: t.textTheme.bodySmall?.copyWith(
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        key: const ValueKey('offline-progress-retry'),
                        onPressed: onRetryProgress,
                        child: Text(
                          isClassroomCompletion
                              ? lang.t(
                                  '授業の完了確認だけ、もう一度保存する',
                                  'Save class completion again',
                                )
                              : lang.t(
                                  '練習済みの印だけ、もう一度保存する',
                                  'Save practiced mark again',
                                ),
                        ),
                      ),
                    ],
                  ] else ...[
                    const SizedBox(height: 8),
                    Text(
                      lang.t(
                        'この経路では、練習済みの印も更新していません。',
                        'On this path, the practiced mark isn\'t updated either.',
                      ),
                      style: t.textTheme.bodySmall?.copyWith(color: colors.ink),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _SelfCheck(
            section: section,
            recall: recall,
            reasoning: reasoning,
            taskResponse: taskResponse,
            comparisonDecision: comparisonDecision,
            reflection: reflection,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const ValueKey('offline-practice-home'),
            onPressed: progressSaving ? null : onHome,
            icon: const Icon(Icons.check),
            label: Text(lang.t('練習を完了', 'Finish practice')),
          ),
          const SizedBox(height: 8),
          Text(
            lang.t(
              'この画面を閉じると、ここに書いた内容は消えます。',
              'What you\'ve written here disappears when you close this screen.',
            ),
            style: t.textTheme.bodySmall?.copyWith(color: colors.inkMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// 本人が自分の記述と教材を見比べるだけの確認面。
///
/// 教材本文はここまで開示しない。アプリ側は一致・不一致を計算せず、
/// 正誤、点数、理解度を表示しない。
class _SelfCheck extends StatelessWidget {
  const _SelfCheck({
    required this.section,
    required this.recall,
    required this.reasoning,
    required this.taskResponse,
    required this.comparisonDecision,
    required this.reflection,
  });

  final Section section;
  final String recall;
  final String reasoning;
  final String taskResponse;
  final PredictionComparisonDecision comparisonDecision;
  final String reflection;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.border),
        borderRadius: BorderRadius.circular(GameTokens.radiusMd),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const ValueKey('offline-self-check'),
        initiallyExpanded: false,
        leading: const Icon(Icons.menu_book_outlined),
        title: Text(
          lang.t('練習全体を見返す', 'Review the whole practice'),
          style: t.textTheme.titleSmall?.jaWeight(FontWeight.w700),
        ),
        subtitle: Text(
          lang.t(
            '入力はこの画面を閉じると消えます',
            'Your input disappears when you close this screen',
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 2, 16, 18),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(),
          const SizedBox(height: 13),
          Text(
            lang.t(
              'これは採点結果ではありません。予想と教材を比べて、自分で見つけたことの控えです。',
              'This isn\'t a score. It\'s a note of what you found by comparing your prediction with the material.',
            ),
            style: t.textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
          ),
          const SizedBox(height: 16),
          Text(
            lang.t('教材', 'Material'),
            style: t.textTheme.labelLarge?.jaWeight(FontWeight.w700),
          ),
          const SizedBox(height: 7),
          for (final paragraph in section.body) ...[
            EmphasisText(
              paragraph,
              style: t.textTheme.bodyMedium,
              selectable: true,
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          Text(
            lang.t('自分が書いたこと', 'What you wrote'),
            style: t.textTheme.labelLarge?.jaWeight(FontWeight.w700),
          ),
          const SizedBox(height: 8),
          _CheckRow(label: lang.t('説明', 'Explanation'), text: recall),
          _CheckRow(
            label: lang.t('科学タスクで組んだ答え', 'Your science task answer'),
            text: taskResponse,
          ),
          _CheckRow(label: lang.t('答えにした理由', 'Your reason'), text: reasoning),
          _CheckRow(
            label: comparisonDecision.reflectionLabel,
            text: reflection,
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: t.textTheme.labelMedium?.copyWith(color: colors.inkMuted),
          ),
          const SizedBox(height: 3),
          SelectableText(text, style: t.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
