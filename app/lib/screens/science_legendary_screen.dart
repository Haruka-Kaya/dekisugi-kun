import '../config/app_language.dart' as localize;
import '../config/app_language.dart' as lang;
import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../config/motion.dart';
import '../learning/domain/learning_heart.dart';
import '../learning/domain/learning_need.dart';
import '../models/game_path.dart';
import '../models/unit.dart';
import '../ui/_material.dart';
import '../widgets/cognitive_task_input.dart';
import '../widgets/game_activity_scaffold.dart';
import '../widgets/science_challenge_support.dart';

enum _LegendaryPhase { task, checkpoint, compare, done }

/// 同じ固定課題エンジンを、報酬つき高難度と無罰の期限復習で使い分ける。
enum ScienceLegendaryPresentation { legendary, spacedReview }

/// 翌学習日以降にだけ開く、ヒントなしの固定高難度課題。
///
/// 解放日の判定はこの画面で推測せず、上位の学習進行が算出した[isUnlocked]を
/// 必ず受け取る。構造課題とcheckpointを最初の回答で両方通過し、正本との
/// 自己比較を書いた場合だけ[onCompleted]を一度呼ぶ。callbackへ回答本文は渡さない。
class ScienceLegendaryScreen extends StatefulWidget {
  const ScienceLegendaryScreen({
    super.key,
    required this.section,
    required this.conceptLabel,
    required this.practiceAttempt,
    required this.isUnlocked,
    required this.onCompleted,
    this.presentation = ScienceLegendaryPresentation.legendary,
    this.onNotCleared,
    this.onReturnToPath,
    this.onNeedEvidence,
    this.onHeartLoss,
  }) : assert(practiceAttempt >= 0);

  final Section section;
  final String conceptLabel;
  final int practiceAttempt;
  final bool isUnlocked;

  /// spacedTransfer相当の完了通知。回答本文や初回正誤は含めない。
  final VoidCallback onCompleted;
  final ScienceLegendaryPresentation presentation;

  /// 未クリア時に画面を閉じる任意通知。結果や回答本文は含めない。
  final VoidCallback? onNotCleared;

  /// クリア完了面の明示操作でだけ呼ぶPath帰還通知。
  /// [onCompleted]とは独立し、完了時に自動では呼ばない。
  final VoidCallback? onReturnToPath;

  /// 回答を含めず、catalog固定の一般化needだけを通知する。
  final LearningNeedEvidenceReported? onNeedEvidence;
  final LearningHeartLossReported? onHeartLoss;

  @override
  State<ScienceLegendaryScreen> createState() => _ScienceLegendaryScreenState();
}

class _ScienceLegendaryScreenState extends State<ScienceLegendaryScreen> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _reflection = TextEditingController();

  _LegendaryPhase _phase = _LegendaryPhase.task;
  CognitiveTaskResponse? _taskResponse;
  String? _checkpointOptionId;
  bool _taskCorrect = false;
  bool _checkpointCorrect = false;
  bool _completionCalled = false;
  bool _notClearedCalled = false;
  bool _returnCalled = false;
  bool _needObserved = false;
  bool _needDemonstrated = false;
  bool _stoppedAfterWrong = false;

  LocalPracticeVariant get _variant =>
      widget.section.practiceVariantForAttempt(widget.practiceAttempt);

  bool get _taskComplete => isCognitiveTaskResponseComplete(
    _variant.cognitiveTask.prompt,
    _taskResponse,
  );

  bool get _cleared => _taskCorrect && _checkpointCorrect;
  bool get _canFinish => _reflection.text.trim().isNotEmpty;

  @override
  void didUpdateWidget(covariant ScienceLegendaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.section, widget.section) ||
        oldWidget.practiceAttempt != widget.practiceAttempt ||
        oldWidget.isUnlocked != widget.isUnlocked ||
        oldWidget.presentation != widget.presentation) {
      _reset();
    }
  }

  void _reset() {
    _reflection.clear();
    _phase = _LegendaryPhase.task;
    _taskResponse = null;
    _checkpointOptionId = null;
    _taskCorrect = false;
    _checkpointCorrect = false;
    _completionCalled = false;
    _notClearedCalled = false;
    _returnCalled = false;
    _needObserved = false;
    _needDemonstrated = false;
    _stoppedAfterWrong = false;
  }

  @override
  void dispose() {
    _scroll.dispose();
    _reflection.dispose();
    super.dispose();
  }

  void _submitTask() {
    if (_phase != _LegendaryPhase.task || !_taskComplete) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _taskCorrect = matchesCognitiveTaskSolution(
      _variant.cognitiveTask,
      _taskResponse,
    );
    _reportNeed(
      _variant.cognitiveTask.needCode,
      _taskCorrect
          ? LearningNeedEvidenceKind.demonstrated
          : LearningNeedEvidenceKind.observed,
    );
    if (!_taskCorrect) {
      widget.onHeartLoss?.call(
        LearningHeartLossEvidence(
          fixedTaskId: 'legendary:${widget.practiceAttempt}:cognitive',
        ),
      );
      _stopAfterWrong();
      return;
    }
    setState(() => _phase = _LegendaryPhase.checkpoint);
    _returnToTop();
  }

  void _submitCheckpoint() {
    if (_phase != _LegendaryPhase.checkpoint || _checkpointOptionId == null) {
      return;
    }
    _checkpointCorrect =
        _checkpointOptionId == _variant.checkpoint.correctOptionId;
    final needCode = _variant.checkpoint.options
        .where((option) => option.id != _variant.checkpoint.correctOptionId)
        .map((option) => option.needCode)
        .nonNulls
        .firstOrNull;
    _reportNeed(
      needCode,
      _checkpointCorrect
          ? LearningNeedEvidenceKind.demonstrated
          : LearningNeedEvidenceKind.observed,
    );
    if (!_checkpointCorrect) {
      widget.onHeartLoss?.call(
        LearningHeartLossEvidence(
          fixedTaskId: 'legendary:${widget.practiceAttempt}:checkpoint',
        ),
      );
      _stopAfterWrong();
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _phase = _LegendaryPhase.compare);
    _returnToTop();
  }

  void _stopAfterWrong() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_notClearedCalled) {
      _notClearedCalled = true;
      widget.onNotCleared?.call();
    }
    setState(() {
      _stoppedAfterWrong = true;
      _phase = _LegendaryPhase.done;
    });
    _returnToTop();
  }

  void _reportNeed(String? needCode, LearningNeedEvidenceKind kind) {
    if (needCode == null) return;
    if (kind == LearningNeedEvidenceKind.observed) {
      if (_needObserved) return;
      _needObserved = true;
    } else {
      if (_needObserved || _needDemonstrated) return;
      _needDemonstrated = true;
    }
    widget.onNeedEvidence?.call(
      LearningNeedEvidence(
        conceptKey: widget.section.conceptKey,
        needCode: needCode,
        kind: kind,
      ),
    );
  }

  void _finishComparison() {
    if (_phase != _LegendaryPhase.compare || !_canFinish) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_cleared) {
      if (_completionCalled) return;
      _completionCalled = true;
      setState(() => _phase = _LegendaryPhase.done);
      widget.onCompleted();
      return;
    }
    setState(() => _phase = _LegendaryPhase.done);
  }

  void _returnToPath() {
    if (_phase != _LegendaryPhase.done ||
        _returnCalled ||
        widget.onReturnToPath == null) {
      return;
    }
    _returnCalled = true;
    setState(() {});
    widget.onReturnToPath!();
  }

  void _returnToTop() {
    final reduceMotion = ReduceMotionScope.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      if (reduceMotion) {
        _scroll.jumpTo(0);
      } else {
        _scroll.animateTo(0, duration: Motion.state, curve: Motion.stateCurve);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final reduceMotion = ReduceMotionScope.of(context);
    final hasSharedChrome = GameActivityScaffold.hasSharedChrome(context);
    return Scaffold(
      key: const ValueKey('science-legendary-screen'),
      backgroundColor: colors.canvas,
      appBar: hasSharedChrome
          ? null
          : AppBar(
              backgroundColor: colors.canvas,
              foregroundColor: colors.ink,
              title: Text(
                widget.presentation == ScienceLegendaryPresentation.legendary
                    ? localize.t('高難度検証', "Advanced Check")
                    : lang.t('間隔を空けた再検証', 'Scheduled review'),
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
              key: const ValueKey('science-legendary-scroll'),
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                GameTokens.spaceLg,
                GameTokens.spaceSm,
                GameTokens.spaceLg,
                GameTokens.spaceXl + MediaQuery.paddingOf(context).bottom,
              ),
              child: widget.isUnlocked
                  ? AnimatedSwitcher(
                      duration: reduceMotion ? Duration.zero : Motion.state,
                      switchInCurve: Motion.stateCurve,
                      switchOutCurve: Motion.quickCurve,
                      child: switch (_phase) {
                        _LegendaryPhase.task => _LegendaryTask(
                          key: const ValueKey('legendary-task'),
                          conceptLabel: widget.conceptLabel,
                          variant: _variant,
                          presentation: widget.presentation,
                          response: _taskResponse,
                          onChanged: (response) =>
                              setState(() => _taskResponse = response),
                          onSubmit: _taskComplete ? _submitTask : null,
                        ),
                        _LegendaryPhase.checkpoint => _LegendaryCheckpoint(
                          key: const ValueKey('legendary-checkpoint'),
                          checkpoint: _variant.checkpoint,
                          presentation: widget.presentation,
                          selectedOptionId: _checkpointOptionId,
                          onSelected: (id) =>
                              setState(() => _checkpointOptionId = id),
                          onSubmit: _checkpointOptionId == null
                              ? null
                              : _submitCheckpoint,
                        ),
                        _LegendaryPhase.compare => _LegendaryComparison(
                          key: const ValueKey('legendary-comparison'),
                          variant: _variant,
                          presentation: widget.presentation,
                          response: _taskResponse!,
                          checkpointOptionId: _checkpointOptionId!,
                          cleared: _cleared,
                          reflection: _reflection,
                          canFinish: _canFinish,
                          onReflectionChanged: (_) => setState(() {}),
                          onFinish: _finishComparison,
                        ),
                        _LegendaryPhase.done => _LegendaryDone(
                          key: const ValueKey('legendary-done'),
                          cleared: _cleared,
                          stoppedAfterWrong: _stoppedAfterWrong,
                          presentation: widget.presentation,
                          onReturnToPath:
                              widget.onReturnToPath == null || _returnCalled
                              ? null
                              : _returnToPath,
                        ),
                      },
                    )
                  : _LegendaryLocked(
                      key: const ValueKey('legendary-locked'),
                      conceptLabel: widget.conceptLabel,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendaryLocked extends StatelessWidget {
  const _LegendaryLocked({super.key, required this.conceptLabel});

  final String conceptLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScienceChallengeHeader(
          eyebrow: localize.t(
            'ラボ・ブリーフ  /  高難度検証  /  準備中',
            "LAB BRIEF / ADVANCED CHECK / PREPARING",
          ),
          title: conceptLabel,
          body: lang.t(
            'この高難度検証は、通常課題を終えた翌学習日以降に開きます。',
            'This advanced challenge unlocks on the next learning day after you finish the regular task.',
          ),
          icon: Icons.lock_clock_outlined,
          accent: colors.pathLocked,
          onAccent: colors.onPathLocked,
          mascotReaction: GameCharacterReaction.thinking,
        ),
        const SizedBox(height: GameTokens.spaceXl),
        ScienceChallengeSurface(
          label: lang.t(
            '今は探究ノートを進められます',
            'You can continue on your regular Path',
          ),
          icon: Icons.route_outlined,
          child: Text(
            lang.t(
              '待っている間も、通常課題・復習・学校課題は止まりません。解放日はこの画面では推測しません。',
              'You can still do regular lessons, reviews, and class work while you wait. This screen does not guess the unlock date.',
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendaryTask extends StatelessWidget {
  const _LegendaryTask({
    super.key,
    required this.conceptLabel,
    required this.variant,
    required this.presentation,
    required this.response,
    required this.onChanged,
    required this.onSubmit,
  });

  final String conceptLabel;
  final LocalPracticeVariant variant;
  final ScienceLegendaryPresentation presentation;
  final CognitiveTaskResponse? response;
  final ValueChanged<CognitiveTaskResponse> onChanged;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final legendary = presentation == ScienceLegendaryPresentation.legendary;
    final accent = legendary ? colors.legendary : colors.pathReview;
    final onAccent = legendary ? colors.onLegendary : colors.onPathReview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScienceChallengeHeader(
          eyebrow: localize.t(
            'ラボ・ブリーフ  /  ${legendary ? localize.t('高難度検証', "Advanced Check") : localize.t('間隔を空けた再検証', "Spaced Review")}  /  1/3',
            'LAB BRIEF / ${legendary ? localize.t('高難度検証', "Advanced Check") : localize.t('間隔を空けた再検証', "Spaced Review")}  /  1/3',
          ),
          title: conceptLabel,
          body: lang.t(
            'ヒントなし・一度だけの回答です。まず構造課題を組みます。',
            'No hints and only one first answer. Start by building the structure.',
          ),
          icon: legendary
              ? Icons.fact_check_outlined
              : Icons.event_repeat_outlined,
          accent: accent,
          onAccent: onAccent,
          mascotReaction: GameCharacterReaction.thinking,
        ),
        const SizedBox(height: GameTokens.spaceXl),
        ScienceChallengeSurface(
          label: lang.t('別の場面へ使う', 'Apply it in a new situation'),
          icon: Icons.science_outlined,
          child: Text(variant.transferPrompt),
        ),
        const SizedBox(height: GameTokens.spaceLg),
        CognitiveTaskInput(
          prompt: variant.cognitiveTask.prompt,
          response: response,
          onChanged: onChanged,
        ),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengePrimaryButton(
          key: const ValueKey('legendary-task-submit'),
          label: lang.t('この答えで確定する', 'Submit this answer'),
          icon: Icons.lock_outline,
          onPressed: onSubmit,
          backgroundColor: accent,
          foregroundColor: onAccent,
        ),
        const SizedBox(height: GameTokens.spaceLg),
        const ScienceChallengePrivacyNote(),
      ],
    );
  }
}

class _LegendaryCheckpoint extends StatelessWidget {
  const _LegendaryCheckpoint({
    super.key,
    required this.checkpoint,
    required this.presentation,
    required this.selectedOptionId,
    required this.onSelected,
    required this.onSubmit,
  });

  final LocalCheckpoint checkpoint;
  final ScienceLegendaryPresentation presentation;
  final String? selectedOptionId;
  final ValueChanged<String> onSelected;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final legendary = presentation == ScienceLegendaryPresentation.legendary;
    final accent = legendary ? colors.legendary : colors.pathReview;
    final onAccent = legendary ? colors.onLegendary : colors.onPathReview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScienceChallengeHeader(
          eyebrow: localize.t(
            'ラボ・ブリーフ  /  ${legendary ? localize.t('高難度検証', "Advanced Check") : localize.t('間隔を空けた再検証', "Spaced Review")}  /  2/3',
            'LAB BRIEF / ${legendary ? localize.t('高難度検証', "Advanced Check") : localize.t('間隔を空けた再検証', "Spaced Review")}  /  2/3',
          ),
          title: lang.t('思い込みを見破る', 'Spot the misconception'),
          body: lang.t(
            'ヒントは出ません。最初の判断を確定すると、すぐ自己比較へ進みます。',
            'No hints. Submit your first choice, then compare it with the answer.',
          ),
          icon: Icons.fact_check_outlined,
          accent: accent,
          onAccent: onAccent,
          mascotReaction: GameCharacterReaction.thinking,
        ),
        const SizedBox(height: GameTokens.spaceXl),
        ScienceChallengeSurface(
          label: lang.t('デキすぎ君の説明', 'Dekisugi-kun\'s explanation'),
          icon: Icons.psychology_alt_outlined,
          child: Text(checkpoint.lure),
        ),
        const SizedBox(height: GameTokens.spaceLg),
        for (var index = 0; index < checkpoint.options.length; index++) ...[
          _LegendaryChoice(
            key: ValueKey(
              'legendary-checkpoint-option-${checkpoint.options[index].id}',
            ),
            text: checkpoint.options[index].text,
            position: index + 1,
            count: checkpoint.options.length,
            selected: checkpoint.options[index].id == selectedOptionId,
            accent: accent,
            onPressed: () => onSelected(checkpoint.options[index].id),
          ),
          if (index < checkpoint.options.length - 1)
            const SizedBox(height: GameTokens.spaceSm),
        ],
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengePrimaryButton(
          key: const ValueKey('legendary-checkpoint-submit'),
          label: lang.t('最初の判断を確定する', 'Submit your first choice'),
          icon: Icons.lock_outline,
          onPressed: onSubmit,
          backgroundColor: accent,
          foregroundColor: onAccent,
        ),
      ],
    );
  }
}

class _LegendaryChoice extends StatelessWidget {
  const _LegendaryChoice({
    super.key,
    required this.text,
    required this.position,
    required this.count,
    required this.selected,
    required this.accent,
    required this.onPressed,
  });

  final String text;
  final int position;
  final int count;
  final bool selected;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Semantics(
      button: true,
      selected: selected,
      label: lang.t(
        '選択肢$position、全$count件中。$text${selected ? '。選択中' : ''}',
        "Option $position of $count. $text${selected ? '. Selected' : ''}",
      ),
      child: ExcludeSemantics(
        child: Material(
          color: selected ? accent.withValues(alpha: 0.16) : colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GameTokens.radiusMd),
            side: BorderSide(
              color: selected ? accent : colors.border,
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: GameTokens.minTouchTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.all(GameTokens.spaceLg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: selected ? accent : colors.inkMuted,
                    ),
                    const SizedBox(width: GameTokens.spaceMd),
                    Expanded(child: Text(text)),
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

class _LegendaryComparison extends StatelessWidget {
  const _LegendaryComparison({
    super.key,
    required this.variant,
    required this.presentation,
    required this.response,
    required this.checkpointOptionId,
    required this.cleared,
    required this.reflection,
    required this.canFinish,
    required this.onReflectionChanged,
    required this.onFinish,
  });

  final LocalPracticeVariant variant;
  final ScienceLegendaryPresentation presentation;
  final CognitiveTaskResponse response;
  final String checkpointOptionId;
  final bool cleared;
  final TextEditingController reflection;
  final bool canFinish;
  final ValueChanged<String> onReflectionChanged;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final legendary = presentation == ScienceLegendaryPresentation.legendary;
    final accent = legendary ? colors.legendary : colors.pathReview;
    final onAccent = legendary ? colors.onLegendary : colors.onPathReview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScienceChallengeHeader(
          eyebrow: localize.t(
            'ラボ・ブリーフ  /  ${legendary ? localize.t('高難度検証', "Advanced Check") : localize.t('間隔を空けた再検証', "Spaced Review")}  /  3/3',
            'LAB BRIEF / ${legendary ? localize.t('高難度検証', "Advanced Check") : localize.t('間隔を空けた再検証', "Spaced Review")}  /  3/3',
          ),
          title: lang.t('正本と自己比較する', 'Compare with the model answer'),
          body: cleared
              ? lang.t(
                  '2つの固定問題を最初の回答で通過しました。最後に根拠を言葉にします。',
                  'You passed both set questions on your first try. Now explain your reasoning.',
                )
              : lang.t(
                  '最初の回答はここで確定です。違いを見つけ、通常練習へつなげます。',
                  'Your first answer is final. Find the differences and use them in regular practice.',
                ),
          icon: cleared
              ? Icons.fact_check_outlined
              : Icons.compare_arrows_rounded,
          accent: accent,
          onAccent: onAccent,
          mascotReaction: cleared
              ? GameCharacterReaction.celebrate
              : GameCharacterReaction.encourage,
        ),
        const SizedBox(height: GameTokens.spaceXl),
        ScienceChallengeComparison(
          task: variant.cognitiveTask,
          response: response,
          expectedOutcome: variant.expectedOutcome,
          expectedReason: variant.expectedReason,
          checkpoint: variant.checkpoint,
          selectedCheckpointOptionId: checkpointOptionId,
        ),
        const SizedBox(height: GameTokens.spaceLg),
        Semantics(
          textField: true,
          label: lang.t(
            '自己比較。自分の考えと教材の違いを一文で書く',
            'Self-check. Write one sentence about how your thinking differs from the material.',
          ),
          child: TextField(
            key: const ValueKey('legendary-reflection'),
            controller: reflection,
            minLines: 2,
            maxLines: 5,
            maxLength: 300,
            textInputAction: TextInputAction.done,
            onChanged: onReflectionChanged,
            decoration: InputDecoration(
              labelText: lang.t(
                '比べて見つけたこと（1文）',
                'What you noticed (one sentence)',
              ),
              hintText: lang.t(
                '例：条件を一つ見落としていた。',
                'Example: I missed one condition.',
              ),
              alignLabelWithHint: true,
            ),
          ),
        ),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengePrimaryButton(
          key: const ValueKey('legendary-finish'),
          label: cleared
              ? legendary
                    ? lang.t('高難度検証を完了', 'Advanced challenge cleared')
                    : lang.t('間隔を空けた再検証を完了', 'Scheduled review cleared')
              : lang.t(
                  '答えを比べて通常練習へ戻る',
                  'Compare answers and return to practice',
                ),
          icon: cleared ? Icons.verified_outlined : Icons.refresh_rounded,
          onPressed: canFinish ? onFinish : null,
          backgroundColor: cleared ? accent : colors.pathReview,
          foregroundColor: cleared ? onAccent : colors.onPathReview,
        ),
        const SizedBox(height: GameTokens.spaceLg),
        const ScienceChallengePrivacyNote(),
      ],
    );
  }
}

class _LegendaryDone extends StatelessWidget {
  const _LegendaryDone({
    super.key,
    required this.cleared,
    required this.stoppedAfterWrong,
    required this.presentation,
    required this.onReturnToPath,
  });

  final bool cleared;
  final bool stoppedAfterWrong;
  final ScienceLegendaryPresentation presentation;
  final VoidCallback? onReturnToPath;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final legendary = presentation == ScienceLegendaryPresentation.legendary;
    final accent = legendary ? colors.legendary : colors.pathReview;
    final onAccent = legendary ? colors.onLegendary : colors.onPathReview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScienceChallengeHeader(
          eyebrow: localize.t(
            'ラボ・ブリーフ  /  ${legendary ? localize.t('高難度検証', "Advanced Check") : localize.t('間隔を空けた再検証', "Spaced Review")}  /  記録',
            'LAB BRIEF / ${legendary ? localize.t('高難度検証', "Advanced Check") : localize.t('間隔を空けた再検証', "Spaced Review")} / RECORD',
          ),
          title: cleared
              ? legendary
                    ? lang.t('高難度検証を完了', 'Advanced challenge cleared')
                    : lang.t('間隔を空けた再検証を完了', 'Scheduled review cleared')
              : stoppedAfterWrong
              ? lang.t('今回はここまで', 'That\'s it for now')
              : lang.t('自己比較を完了', 'Self-check complete'),
          body: cleared
              ? lang.t(
                  '翌学習日の別場面で、固定問題と誤概念訂正を通過しました。',
                  'On a later learning day, you solved set questions in a new situation and corrected a misconception.',
                )
              : stoppedAfterWrong
              ? lang.t(
                  '最初の誤答でこの検証を終了しました。試行余力が0なら、回復練習の後で別の固定問題を検証できます。',
                  'This challenge ended after the first wrong answer. If you have zero hearts, do a recovery exercise before trying a different set question.',
                )
              : legendary
              ? lang.t(
                  '高難度検証は未完了です。通常練習で確かめ、また検証できます。',
                  'Legendary is not cleared yet. Review in regular practice, then try again.',
                )
              : lang.t(
                  '今回は再検証の完了になりません。別の問題でまた確かめられます。',
                  'This review is not cleared yet. You can try a different question later.',
                ),
          icon: cleared
              ? Icons.fact_check_outlined
              : Icons.psychology_alt_outlined,
          accent: cleared ? accent : colors.pathReview,
          onAccent: cleared ? onAccent : colors.onPathReview,
          mascotReaction: cleared
              ? GameCharacterReaction.celebrate
              : GameCharacterReaction.encourage,
        ),
        const SizedBox(height: GameTokens.spaceXl),
        ScienceChallengeSurface(
          label: cleared
              ? lang.t('習得の断定ではありません', 'This does not prove mastery')
              : lang.t('進行は失いません', 'Your progress stays'),
          icon: Icons.info_outline,
          child: Text(
            cleared
                ? legendary
                      ? lang.t(
                          '表示するのは「高難度検証を完了」です。内容全体の理解を自動判定しません。',
                          'This shows "Advanced challenge cleared." It does not judge your overall understanding.',
                        )
                      : lang.t(
                          '固定問題を初回回答で通過したため、次の復習日を更新します。内容全体の理解は断定しません。',
                          'You passed set questions on your first try, so your next review date is updated. This does not prove overall understanding.',
                        )
                : stoppedAfterWrong
                ? lang.t(
                    '次の固定問題と正解は開いていません。回答内容も保存しません。',
                    'The next set question and its answer stay hidden. Your answers are not saved.',
                  )
                : lang.t(
                    '探究ノート・連続観測・報酬・通常練習の利用条件は変わりません。',
                    'Your Path, streak, rewards, and regular practice remain available.',
                  ),
          ),
        ),
        if (onReturnToPath != null) ...[
          const SizedBox(height: GameTokens.spaceLg),
          ScienceChallengePrimaryButton(
            key: const ValueKey('legendary-return-to-path'),
            label: cleared
                ? legendary
                      ? lang.t('探究ノートへ戻る', 'Back to learning path')
                      : lang.t('練習タブへ戻る', 'Back to Practice')
                : lang.t('通常練習へ戻る', 'Back to regular practice'),
            icon: Icons.route_outlined,
            onPressed: onReturnToPath,
            backgroundColor: colors.pathActive,
            foregroundColor: colors.onPathActive,
          ),
        ],
      ],
    );
  }
}
