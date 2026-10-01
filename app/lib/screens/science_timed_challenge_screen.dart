import 'dart:async';

import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../config/motion.dart';
import '../learning/domain/learning_heart.dart';
import '../learning/domain/learning_need.dart';
import '../models/game_path.dart';
import '../models/unit.dart';
import '../services/challenge_deadline.dart';
import '../ui/_material.dart';
import '../widgets/cognitive_task_input.dart';
import '../widgets/game_activity_scaffold.dart';
import '../widgets/science_challenge_support.dart';

enum _TimedPhase { intro, task, checkpoint, result }

enum _TimedOutcome { cleared, needsReview, timeUp }

/// 任意の時間制ミニゲーム。
///
/// catalog v4の固定問題だけを使い、速度・回答・残り時間は保存もcallbackも
/// しない。[onFinished]は結果を持たないため、Path解放・streak・報酬の根拠には
/// 使えない。時間切れはheartを減らさず、固定問題の誤答だけが回答内容を含まない
/// [onHeartLoss]を一度通知する。
class ScienceTimedChallengeScreen extends StatefulWidget {
  const ScienceTimedChallengeScreen({
    super.key,
    required this.section,
    required this.conceptLabel,
    required this.practiceAttempt,
    required this.onFinished,
    this.timeLimit = const Duration(seconds: 60),
    this.onNeedEvidence,
    this.onHeartLoss,
    this.elapsedClock,
  }) : assert(practiceAttempt >= 0),
       assert(timeLimit > Duration.zero);

  final Section section;
  final String conceptLabel;
  final int practiceAttempt;

  /// 結果・回答・反応時間を含まない、画面を閉じるためだけの通知。
  final VoidCallback onFinished;
  final LearningNeedEvidenceReported? onNeedEvidence;
  final LearningHeartLossReported? onHeartLoss;
  final Duration timeLimit;

  /// Monotonic elapsed time source used by lifecycle regression tests.
  final ChallengeElapsedClock? elapsedClock;

  @override
  State<ScienceTimedChallengeScreen> createState() =>
      _ScienceTimedChallengeScreenState();
}

class _ScienceTimedChallengeScreenState
    extends State<ScienceTimedChallengeScreen>
    with WidgetsBindingObserver {
  final ScrollController _scroll = ScrollController();

  Timer? _timer;
  late ChallengeDeadline _deadline;
  _TimedPhase _phase = _TimedPhase.intro;
  _TimedOutcome? _outcome;
  CognitiveTaskResponse? _taskResponse;
  String? _checkpointOptionId;
  late int _remainingSeconds;
  bool _finishCalled = false;
  bool _needObserved = false;
  bool _needDemonstrated = false;

  LocalPracticeVariant get _variant =>
      widget.section.practiceVariantForAttempt(widget.practiceAttempt);

  bool get _taskComplete => isCognitiveTaskResponseComplete(
    _variant.cognitiveTask.prompt,
    _taskResponse,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _deadline = ChallengeDeadline(
      widget.timeLimit,
      elapsedClock: widget.elapsedClock,
    );
    _remainingSeconds = _initialSeconds;
  }

  @override
  void didUpdateWidget(covariant ScienceTimedChallengeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.section, widget.section) ||
        oldWidget.practiceAttempt != widget.practiceAttempt ||
        oldWidget.timeLimit != widget.timeLimit ||
        oldWidget.elapsedClock != widget.elapsedClock) {
      _deadline = ChallengeDeadline(
        widget.timeLimit,
        elapsedClock: widget.elapsedClock,
      );
      _reset();
    }
  }

  int get _initialSeconds => _deadline.initialSeconds;

  void _reset() {
    _timer?.cancel();
    _deadline.reset(limit: widget.timeLimit);
    _phase = _TimedPhase.intro;
    _outcome = null;
    _taskResponse = null;
    _checkpointOptionId = null;
    _remainingSeconds = _initialSeconds;
    _finishCalled = false;
    _needObserved = false;
    _needDemonstrated = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _deadline.stop();
    _scroll.dispose();
    super.dispose();
  }

  void _start() {
    if (_phase != _TimedPhase.intro) return;
    _deadline.start();
    setState(() {
      _phase = _TimedPhase.task;
      _remainingSeconds = _deadline.remainingSeconds;
    });
    _startTicker();
  }

  void _startTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _syncCountdown(foregroundTick: true);
    });
  }

  void _syncCountdown({
    bool restartTicker = false,
    bool foregroundTick = false,
  }) {
    if (!mounted ||
        _phase == _TimedPhase.intro ||
        _phase == _TimedPhase.result) {
      return;
    }
    var remaining = _deadline.remainingSeconds;
    if (foregroundTick && _remainingSeconds > 0) {
      final tickRemaining = _remainingSeconds - 1;
      if (tickRemaining < remaining) remaining = tickRemaining;
    }
    if (remaining == 0) {
      _end(_TimedOutcome.timeUp);
      return;
    }
    if (remaining != _remainingSeconds) {
      setState(() => _remainingSeconds = remaining);
    }
    if (restartTicker) _startTicker();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _syncCountdown(restartTicker: true);
        return;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _timer?.cancel();
        _timer = null;
        return;
    }
  }

  void _submitTask() {
    if (_phase != _TimedPhase.task || !_taskComplete) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final correct = matchesCognitiveTaskSolution(
      _variant.cognitiveTask,
      _taskResponse,
    );
    _reportNeed(
      _variant.cognitiveTask.needCode,
      correct
          ? LearningNeedEvidenceKind.demonstrated
          : LearningNeedEvidenceKind.observed,
    );
    if (!correct) {
      widget.onHeartLoss?.call(
        LearningHeartLossEvidence(
          fixedTaskId: 'timed:${widget.practiceAttempt}:cognitive',
        ),
      );
      _end(_TimedOutcome.needsReview);
      return;
    }
    setState(() => _phase = _TimedPhase.checkpoint);
    _returnToTop();
  }

  void _submitCheckpoint() {
    if (_phase != _TimedPhase.checkpoint || _checkpointOptionId == null) {
      return;
    }
    final cleared = _checkpointOptionId == _variant.checkpoint.correctOptionId;
    final needCode = _variant.checkpoint.options
        .where((option) => option.id != _variant.checkpoint.correctOptionId)
        .map((option) => option.needCode)
        .nonNulls
        .firstOrNull;
    _reportNeed(
      needCode,
      cleared
          ? LearningNeedEvidenceKind.demonstrated
          : LearningNeedEvidenceKind.observed,
    );
    if (!cleared) {
      widget.onHeartLoss?.call(
        LearningHeartLossEvidence(
          fixedTaskId: 'timed:${widget.practiceAttempt}:checkpoint',
        ),
      );
    }
    _end(cleared ? _TimedOutcome.cleared : _TimedOutcome.needsReview);
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

  void _end(_TimedOutcome outcome) {
    if (!mounted || _phase == _TimedPhase.result) return;
    _timer?.cancel();
    _timer = null;
    _deadline.stop();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _outcome = outcome;
      _phase = _TimedPhase.result;
    });
    _returnToTop();
  }

  void _finish() {
    if (_finishCalled) return;
    _finishCalled = true;
    widget.onFinished();
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
      key: const ValueKey('science-timed-challenge-screen'),
      backgroundColor: colors.canvas,
      appBar: hasSharedChrome
          ? null
          : AppBar(
              backgroundColor: colors.canvas,
              foregroundColor: colors.ink,
              title: Text(
                '時間観察',
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
              key: const ValueKey('science-timed-scroll'),
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(
                GameTokens.spaceLg,
                GameTokens.spaceSm,
                GameTokens.spaceLg,
                GameTokens.spaceXl + MediaQuery.paddingOf(context).bottom,
              ),
              child: AnimatedSwitcher(
                duration: reduceMotion ? Duration.zero : Motion.state,
                switchInCurve: Motion.stateCurve,
                switchOutCurve: Motion.quickCurve,
                child: switch (_phase) {
                  _TimedPhase.intro => _TimedIntro(
                    key: const ValueKey('timed-intro'),
                    conceptLabel: widget.conceptLabel,
                    seconds: _initialSeconds,
                    onStart: _start,
                  ),
                  _TimedPhase.task => _TimedTask(
                    key: const ValueKey('timed-task'),
                    variant: _variant,
                    remainingSeconds: _remainingSeconds,
                    response: _taskResponse,
                    onChanged: (response) =>
                        setState(() => _taskResponse = response),
                    onSubmit: _taskComplete ? _submitTask : null,
                  ),
                  _TimedPhase.checkpoint => _TimedCheckpoint(
                    key: const ValueKey('timed-checkpoint'),
                    checkpoint: _variant.checkpoint,
                    remainingSeconds: _remainingSeconds,
                    selectedOptionId: _checkpointOptionId,
                    onSelected: (id) =>
                        setState(() => _checkpointOptionId = id),
                    onSubmit: _checkpointOptionId == null
                        ? null
                        : _submitCheckpoint,
                  ),
                  _TimedPhase.result => _TimedResult(
                    key: const ValueKey('timed-result'),
                    outcome: _outcome!,
                    variant: _variant,
                    response: _taskResponse,
                    checkpointOptionId: _checkpointOptionId,
                    onFinish: _finish,
                  ),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimedIntro extends StatelessWidget {
  const _TimedIntro({
    super.key,
    required this.conceptLabel,
    required this.seconds,
    required this.onStart,
  });

  final String conceptLabel;
  final int seconds;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScienceChallengeHeader(
          eyebrow: 'ラボ・ブリーフ  /  時間観察  /  任意',
          title: conceptLabel,
          body: '固定の2問を$seconds秒で解きます。速さは学習の代わりにはなりません。',
          icon: Icons.timer_outlined,
          accent: colors.pathReview,
          onAccent: colors.onPathReview,
          mascotReaction: GameCharacterReaction.invite,
        ),
        const SizedBox(height: GameTokens.spaceXl),
        ScienceChallengeSurface(
          label: '時間切れは失点なし',
          icon: Icons.shield_outlined,
          child: const Text(
            '時間切れでは試行余力は減りません。固定問題の誤答だけ、個人モードでは試行余力が1つ減ります。'
            '探究ノート・連続観測・報酬・学校課題は変わらず、学校モードは試行余力が無制限です。',
          ),
        ),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengePrimaryButton(
          key: const ValueKey('timed-start'),
          label: '時間観察を始める',
          icon: Icons.play_arrow_rounded,
          onPressed: onStart,
          backgroundColor: colors.pathReview,
          foregroundColor: colors.onPathReview,
        ),
        const SizedBox(height: GameTokens.spaceLg),
        const ScienceChallengePrivacyNote(),
      ],
    );
  }
}

class _TimedTask extends StatelessWidget {
  const _TimedTask({
    super.key,
    required this.variant,
    required this.remainingSeconds,
    required this.response,
    required this.onChanged,
    required this.onSubmit,
  });

  final LocalPracticeVariant variant;
  final int remainingSeconds;
  final CognitiveTaskResponse? response;
  final ValueChanged<CognitiveTaskResponse> onChanged;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Countdown(seconds: remainingSeconds, stepLabel: '1問目、しくみを組む'),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengeSurface(
          label: '場面',
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
          key: const ValueKey('timed-task-submit'),
          label: 'この答えで次へ',
          icon: Icons.arrow_forward_rounded,
          onPressed: onSubmit,
          backgroundColor: colors.pathReview,
          foregroundColor: colors.onPathReview,
        ),
        const SizedBox(height: GameTokens.spaceLg),
        const ScienceChallengePrivacyNote(),
      ],
    );
  }
}

class _TimedCheckpoint extends StatelessWidget {
  const _TimedCheckpoint({
    super.key,
    required this.checkpoint,
    required this.remainingSeconds,
    required this.selectedOptionId,
    required this.onSelected,
    required this.onSubmit,
  });

  final LocalCheckpoint checkpoint;
  final int remainingSeconds;
  final String? selectedOptionId;
  final ValueChanged<String> onSelected;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Countdown(seconds: remainingSeconds, stepLabel: '2問目、思い込みを見破る'),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengeSurface(
          label: 'デキすぎ君の説明',
          icon: Icons.psychology_alt_outlined,
          child: Text(checkpoint.lure),
        ),
        const SizedBox(height: GameTokens.spaceLg),
        for (var index = 0; index < checkpoint.options.length; index++) ...[
          _CheckpointChoice(
            key: ValueKey(
              'timed-checkpoint-option-${checkpoint.options[index].id}',
            ),
            text: checkpoint.options[index].text,
            position: index + 1,
            count: checkpoint.options.length,
            selected: checkpoint.options[index].id == selectedOptionId,
            onPressed: () => onSelected(checkpoint.options[index].id),
          ),
          if (index < checkpoint.options.length - 1)
            const SizedBox(height: GameTokens.spaceSm),
        ],
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengePrimaryButton(
          key: const ValueKey('timed-checkpoint-submit'),
          label: '答えを決定する',
          icon: Icons.flag_outlined,
          onPressed: onSubmit,
          backgroundColor: colors.pathReview,
          foregroundColor: colors.onPathReview,
        ),
      ],
    );
  }
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.seconds, required this.stepLabel});

  final int seconds;
  final String stepLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    return Semantics(
      key: const ValueKey('timed-countdown'),
      container: true,
      label: '$stepLabel。残り時間$seconds秒',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: GameTokens.spaceLg,
            vertical: GameTokens.spaceMd,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(GameTokens.radiusMd),
          ),
          child: Wrap(
            spacing: GameTokens.spaceMd,
            runSpacing: GameTokens.spaceXs,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                stepLabel,
                style: theme.textTheme.titleSmall?.jaWeight(FontWeight.w800),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer_outlined, color: colors.pathReview),
                  const SizedBox(width: GameTokens.spaceXs),
                  Text(
                    '残り $seconds秒',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: colors.pathReview)
                        .jaWeight(FontWeight.w900),
                  ),
                ],
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
    super.key,
    required this.text,
    required this.position,
    required this.count,
    required this.selected,
    required this.onPressed,
  });

  final String text;
  final int position;
  final int count;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Semantics(
      button: true,
      selected: selected,
      label: '選択肢$position、全$count件中。$text${selected ? '。選択中' : ''}',
      child: ExcludeSemantics(
        child: Material(
          color: selected ? colors.surfaceRaised : colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GameTokens.radiusMd),
            side: BorderSide(
              color: selected ? colors.pathReview : colors.border,
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
                      color: selected ? colors.pathReview : colors.inkMuted,
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

class _TimedResult extends StatelessWidget {
  const _TimedResult({
    super.key,
    required this.outcome,
    required this.variant,
    required this.response,
    required this.checkpointOptionId,
    required this.onFinish,
  });

  final _TimedOutcome outcome;
  final LocalPracticeVariant variant;
  final CognitiveTaskResponse? response;
  final String? checkpointOptionId;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final (title, body, icon, accent, foreground) = switch (outcome) {
      _TimedOutcome.cleared => (
        '時間観察を完了',
        '固定問題を最後まで解きました。速さによる追加報酬はありません。',
        Icons.check_circle_outline,
        colors.pathComplete,
        colors.onPathComplete,
      ),
      _TimedOutcome.needsReview => (
        '今回はここまで',
        '一度の回答で終了です。答えを比べ、通常練習でゆっくり確かめられます。',
        Icons.compare_arrows_rounded,
        colors.pathReview,
        colors.onPathReview,
      ),
      _TimedOutcome.timeUp => (
        '時間になりました',
        '未回答でも失うものはありません。答えを見て、通常練習へ戻れます。',
        Icons.timer_off_outlined,
        colors.surfaceRaised,
        colors.ink,
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScienceChallengeHeader(
          eyebrow: 'ラボ・ブリーフ  /  時間観察  /  記録',
          title: title,
          body: body,
          icon: icon,
          accent: accent,
          onAccent: foreground,
          mascotReaction: switch (outcome) {
            _TimedOutcome.cleared => GameCharacterReaction.celebrate,
            _TimedOutcome.needsReview => GameCharacterReaction.retry,
            _TimedOutcome.timeUp => GameCharacterReaction.outOfTime,
          },
        ),
        const SizedBox(height: GameTokens.spaceXl),
        if (response != null)
          ScienceChallengeComparison(
            task: variant.cognitiveTask,
            response: response!,
            expectedOutcome: variant.expectedOutcome,
            expectedReason: variant.expectedReason,
            checkpoint: variant.checkpoint,
            selectedCheckpointOptionId: checkpointOptionId ?? '',
          )
        else ...[
          ScienceChallengeSurface(
            label: '教材の組み方',
            icon: Icons.account_tree_outlined,
            child: Text(cognitiveTaskSolutionSummary(variant.cognitiveTask)),
          ),
          const SizedBox(height: GameTokens.spaceMd),
          ScienceChallengeSurface(
            label: '観察と理由',
            icon: Icons.science_outlined,
            child: Text(
              '${variant.expectedOutcome}\n\n${variant.expectedReason}',
            ),
          ),
        ],
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengeSurface(
          label: '進行と報酬はそのまま',
          icon: Icons.shield_outlined,
          child: const Text(
            '探究ノート・連続観測・報酬・学校課題は増減しません。時間切れでは試行余力も減らず、'
            '固定問題に誤答した場合だけ個人モードの試行余力が1つ減ります。',
          ),
        ),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengePrimaryButton(
          key: const ValueKey('timed-finish'),
          label: '探究ノートの練習へ戻る',
          icon: Icons.arrow_back_rounded,
          onPressed: onFinish,
          backgroundColor: colors.pathReview,
          foregroundColor: colors.onPathReview,
        ),
      ],
    );
  }
}
