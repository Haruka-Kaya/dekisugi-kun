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

/// Unit末Legendaryで出す、catalog由来の1 concept分。
///
/// [practiceAttempt]は回答ではなく、固定variantを選ぶ公開進行値だけを持つ。
class ScienceUnitLegendaryChallenge {
  const ScienceUnitLegendaryChallenge({
    required this.section,
    required this.conceptLabel,
    required this.practiceAttempt,
  }) : assert(conceptLabel != ''),
       assert(practiceAttempt >= 0);

  final Section section;
  final String conceptLabel;
  final int practiceAttempt;

  LocalPracticeVariant get variant =>
      section.practiceVariantForAttempt(practiceAttempt);
}

enum _UnitLegendaryPhase { task, checkpoint, compare, done }

/// Unit内の全conceptを横断する、回答非保存の固定高難度課題。
///
/// 各conceptの構造課題とcheckpointを最初の回答で確定し、全問を終えるまで
/// 正本を表示しない。callbackは完了・未クリアという派生結果だけを通知し、
/// 選択、正誤内訳、自己比較文は画面を閉じると破棄する。
class ScienceUnitLegendaryScreen extends StatefulWidget {
  const ScienceUnitLegendaryScreen({
    super.key,
    required this.unitTitle,
    required this.challenges,
    required this.isUnlocked,
    required this.onCompleted,
    this.onNeedEvidence,
    this.onNotCleared,
    this.onReturnToPath,
    this.onHeartLoss,
  }) : assert(unitTitle != ''),
       assert(challenges.length > 0);

  final String unitTitle;
  final List<ScienceUnitLegendaryChallenge> challenges;
  final bool isUnlocked;
  final VoidCallback onCompleted;

  /// 回答そのものではなく、catalog固定の一般化needだけをconcept付きで返す。
  final LearningNeedEvidenceReported? onNeedEvidence;
  final VoidCallback? onNotCleared;
  final VoidCallback? onReturnToPath;
  final LearningHeartLossReported? onHeartLoss;

  @override
  State<ScienceUnitLegendaryScreen> createState() =>
      _ScienceUnitLegendaryScreenState();
}

class _ScienceUnitLegendaryScreenState
    extends State<ScienceUnitLegendaryScreen> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _reflection = TextEditingController();

  late List<CognitiveTaskResponse?> _taskResponses;
  late List<String?> _checkpointOptionIds;
  late List<bool> _taskCorrect;
  late List<bool> _checkpointCorrect;
  _UnitLegendaryPhase _phase = _UnitLegendaryPhase.task;
  int _challengeIndex = 0;
  bool _completionCalled = false;
  bool _notClearedCalled = false;
  bool _returnCalled = false;
  bool _stoppedAfterWrong = false;

  ScienceUnitLegendaryChallenge get _challenge =>
      widget.challenges[_challengeIndex];
  LocalPracticeVariant get _variant => _challenge.variant;
  int get _questionCount => widget.challenges.length * 2;
  int get _questionNumber =>
      (_challengeIndex * 2) +
      (_phase == _UnitLegendaryPhase.checkpoint ? 2 : 1);

  bool get _taskComplete => isCognitiveTaskResponseComplete(
    _variant.cognitiveTask.prompt,
    _taskResponses[_challengeIndex],
  );

  bool get _cleared =>
      _taskCorrect.every((value) => value) &&
      _checkpointCorrect.every((value) => value);
  bool get _canFinish => _reflection.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _initializeAnswers();
  }

  @override
  void didUpdateWidget(covariant ScienceUnitLegendaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameChallengeContract(oldWidget, widget)) _reset();
  }

  void _initializeAnswers() {
    _taskResponses = List<CognitiveTaskResponse?>.filled(
      widget.challenges.length,
      null,
    );
    _checkpointOptionIds = List<String?>.filled(widget.challenges.length, null);
    _taskCorrect = List<bool>.filled(widget.challenges.length, false);
    _checkpointCorrect = List<bool>.filled(widget.challenges.length, false);
  }

  void _reset() {
    _reflection.clear();
    _phase = _UnitLegendaryPhase.task;
    _challengeIndex = 0;
    _completionCalled = false;
    _notClearedCalled = false;
    _returnCalled = false;
    _stoppedAfterWrong = false;
    _initializeAnswers();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _reflection.dispose();
    super.dispose();
  }

  void _submitTask() {
    if (_phase != _UnitLegendaryPhase.task || !_taskComplete) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final correct = matchesCognitiveTaskSolution(
      _variant.cognitiveTask,
      _taskResponses[_challengeIndex],
    );
    _taskCorrect[_challengeIndex] = correct;
    _reportNeed(
      _variant.cognitiveTask.needCode,
      correct
          ? LearningNeedEvidenceKind.demonstrated
          : LearningNeedEvidenceKind.observed,
    );
    if (!correct) {
      widget.onHeartLoss?.call(
        LearningHeartLossEvidence(
          fixedTaskId:
              'unit-legendary:${_challenge.section.conceptKey}:'
              '${_challenge.practiceAttempt}:cognitive',
        ),
      );
      _stopAfterWrong();
      return;
    }
    setState(() => _phase = _UnitLegendaryPhase.checkpoint);
    _returnToTop();
  }

  void _submitCheckpoint() {
    final optionId = _checkpointOptionIds[_challengeIndex];
    if (_phase != _UnitLegendaryPhase.checkpoint || optionId == null) return;
    final correct = optionId == _variant.checkpoint.correctOptionId;
    _checkpointCorrect[_challengeIndex] = correct;
    final generalizedNeedCode = _variant.checkpoint.options
        .where((option) => option.id != _variant.checkpoint.correctOptionId)
        .map((option) => option.needCode)
        .nonNulls
        .firstOrNull;
    _reportNeed(
      generalizedNeedCode,
      correct
          ? LearningNeedEvidenceKind.demonstrated
          : LearningNeedEvidenceKind.observed,
    );
    if (!correct) {
      widget.onHeartLoss?.call(
        LearningHeartLossEvidence(
          fixedTaskId:
              'unit-legendary:${_challenge.section.conceptKey}:'
              '${_challenge.practiceAttempt}:checkpoint',
        ),
      );
      _stopAfterWrong();
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    if (_challengeIndex + 1 < widget.challenges.length) {
      setState(() {
        _challengeIndex++;
        _phase = _UnitLegendaryPhase.task;
      });
      _returnToTop();
      return;
    }
    setState(() => _phase = _UnitLegendaryPhase.compare);
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
      _phase = _UnitLegendaryPhase.done;
    });
    _returnToTop();
  }

  void _reportNeed(String? needCode, LearningNeedEvidenceKind kind) {
    if (needCode == null) return;
    widget.onNeedEvidence?.call(
      LearningNeedEvidence(
        conceptKey: _challenge.section.conceptKey,
        needCode: needCode,
        kind: kind,
      ),
    );
  }

  void _finishComparison() {
    if (_phase != _UnitLegendaryPhase.compare || !_canFinish) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_cleared && !_completionCalled) {
      _completionCalled = true;
      setState(() => _phase = _UnitLegendaryPhase.done);
      widget.onCompleted();
      return;
    }
    setState(() => _phase = _UnitLegendaryPhase.done);
  }

  void _returnToPath() {
    if (_phase != _UnitLegendaryPhase.done ||
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
      key: const ValueKey('science-unit-legendary-screen'),
      backgroundColor: colors.canvas,
      appBar: hasSharedChrome
          ? null
          : AppBar(
              backgroundColor: colors.canvas,
              foregroundColor: colors.ink,
              title: Text(
                '単元の高難度検証',
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
              key: const ValueKey('science-unit-legendary-scroll'),
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
                        _UnitLegendaryPhase.task => _task(context),
                        _UnitLegendaryPhase.checkpoint => _checkpoint(context),
                        _UnitLegendaryPhase.compare => _comparison(context),
                        _UnitLegendaryPhase.done => _done(context),
                      },
                    )
                  : _locked(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _locked(BuildContext context) {
    final colors = context.gamePalette;
    return Column(
      key: const ValueKey('unit-legendary-locked'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScienceChallengeHeader(
          eyebrow: 'ラボ・ブリーフ  /  単元の高難度検証  /  準備中',
          title: widget.unitTitle,
          body: 'この単元の全総合検証を終えた、次の学習日から開きます。',
          icon: Icons.lock_clock_outlined,
          accent: colors.pathLocked,
          onAccent: colors.onPathLocked,
          mascotReaction: GameCharacterReaction.thinking,
        ),
        const SizedBox(height: GameTokens.spaceXl),
        const ScienceChallengeSurface(
          label: '通常の探究ノートは止まりません',
          icon: Icons.route_outlined,
          child: Text('単元の高難度検証は任意です。待っている間も、次の単元・復習・学校課題へ進めます。'),
        ),
      ],
    );
  }

  Widget _task(BuildContext context) {
    final colors = context.gamePalette;
    return Column(
      key: ValueKey('unit-legendary-task-${_challenge.section.conceptKey}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScienceChallengeHeader(
          eyebrow: 'ラボ・ブリーフ  /  単元の高難度検証  /  $_questionNumber/$_questionCount',
          title: _challenge.conceptLabel,
          body: '単元内${widget.challenges.length}概念を横断します。全問を確定するまで正本は開きません。',
          icon: Icons.fact_check_outlined,
          accent: colors.legendary,
          onAccent: colors.onLegendary,
          mascotReaction: GameCharacterReaction.thinking,
        ),
        const SizedBox(height: GameTokens.spaceXl),
        ScienceChallengeSurface(
          label: '別の場面へ使う',
          icon: Icons.science_outlined,
          child: Text(_variant.transferPrompt),
        ),
        const SizedBox(height: GameTokens.spaceLg),
        CognitiveTaskInput(
          prompt: _variant.cognitiveTask.prompt,
          response: _taskResponses[_challengeIndex],
          onChanged: (response) =>
              setState(() => _taskResponses[_challengeIndex] = response),
        ),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengePrimaryButton(
          key: const ValueKey('unit-legendary-task-submit'),
          label: 'この答えで確定する',
          icon: Icons.lock_outline,
          onPressed: _taskComplete ? _submitTask : null,
          backgroundColor: colors.legendary,
          foregroundColor: colors.onLegendary,
        ),
        const SizedBox(height: GameTokens.spaceLg),
        const ScienceChallengePrivacyNote(),
      ],
    );
  }

  Widget _checkpoint(BuildContext context) {
    final colors = context.gamePalette;
    final checkpoint = _variant.checkpoint;
    return Column(
      key: ValueKey(
        'unit-legendary-checkpoint-${_challenge.section.conceptKey}',
      ),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScienceChallengeHeader(
          eyebrow: 'ラボ・ブリーフ  /  単元の高難度検証  /  $_questionNumber/$_questionCount',
          title: '${_challenge.conceptLabel}の思い込み',
          body: 'ヒントなしで最初の判断を確定します。まだ正本は表示しません。',
          icon: Icons.fact_check_outlined,
          accent: colors.legendary,
          onAccent: colors.onLegendary,
          mascotReaction: GameCharacterReaction.thinking,
        ),
        const SizedBox(height: GameTokens.spaceXl),
        ScienceChallengeSurface(
          label: 'デキすぎ君の説明',
          icon: Icons.psychology_alt_outlined,
          child: Text(checkpoint.lure),
        ),
        const SizedBox(height: GameTokens.spaceLg),
        for (var index = 0; index < checkpoint.options.length; index++) ...[
          _UnitLegendaryChoice(
            key: ValueKey(
              'unit-legendary-checkpoint-option-'
              '${_challenge.section.conceptKey}-${checkpoint.options[index].id}',
            ),
            text: checkpoint.options[index].text,
            position: index + 1,
            count: checkpoint.options.length,
            selected:
                checkpoint.options[index].id ==
                _checkpointOptionIds[_challengeIndex],
            onPressed: () => setState(
              () => _checkpointOptionIds[_challengeIndex] =
                  checkpoint.options[index].id,
            ),
          ),
          if (index < checkpoint.options.length - 1)
            const SizedBox(height: GameTokens.spaceSm),
        ],
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengePrimaryButton(
          key: const ValueKey('unit-legendary-checkpoint-submit'),
          label: '最初の判断を確定する',
          icon: Icons.lock_outline,
          onPressed: _checkpointOptionIds[_challengeIndex] == null
              ? null
              : _submitCheckpoint,
          backgroundColor: colors.legendary,
          foregroundColor: colors.onLegendary,
        ),
      ],
    );
  }

  Widget _comparison(BuildContext context) {
    final colors = context.gamePalette;
    return Column(
      key: const ValueKey('unit-legendary-comparison'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScienceChallengeHeader(
          eyebrow: 'ラボ・ブリーフ  /  単元の高難度検証  /  比較',
          title: '単元全体を正本と比べる',
          body: _cleared
              ? '全${widget.challenges.length}概念の固定問題を、最初の回答で通過しました。'
              : '全回答は確定済みです。違いを見つけ、通常練習へつなげます。',
          icon: _cleared
              ? Icons.fact_check_outlined
              : Icons.compare_arrows_rounded,
          accent: colors.legendary,
          onAccent: colors.onLegendary,
          mascotReaction: _cleared
              ? GameCharacterReaction.celebrate
              : GameCharacterReaction.encourage,
        ),
        const SizedBox(height: GameTokens.spaceXl),
        for (var index = 0; index < widget.challenges.length; index++) ...[
          Semantics(
            header: true,
            child: Text(
              '${index + 1}. ${widget.challenges[index].conceptLabel}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.jaWeight(FontWeight.w800),
            ),
          ),
          const SizedBox(height: GameTokens.spaceSm),
          ScienceChallengeComparison(
            task: widget.challenges[index].variant.cognitiveTask,
            response: _taskResponses[index]!,
            expectedOutcome: widget.challenges[index].variant.expectedOutcome,
            expectedReason: widget.challenges[index].variant.expectedReason,
            checkpoint: widget.challenges[index].variant.checkpoint,
            selectedCheckpointOptionId: _checkpointOptionIds[index]!,
          ),
          if (index < widget.challenges.length - 1)
            const SizedBox(height: GameTokens.spaceXl),
        ],
        const SizedBox(height: GameTokens.spaceLg),
        Semantics(
          textField: true,
          label: '単元の自己比較。概念同士のつながりを一文で書く',
          child: TextField(
            key: const ValueKey('unit-legendary-reflection'),
            controller: _reflection,
            minLines: 2,
            maxLines: 5,
            maxLength: 300,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: '概念をつないで見つけたこと（1文）',
              hintText: '例：条件が変わると、同じ力でも結果の見方が変わる。',
              alignLabelWithHint: true,
            ),
          ),
        ),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengePrimaryButton(
          key: const ValueKey('unit-legendary-finish'),
          label: _cleared ? '単元の高難度検証を完了' : '通常練習へ戻る',
          icon: _cleared ? Icons.verified_outlined : Icons.refresh_rounded,
          onPressed: _canFinish ? _finishComparison : null,
          backgroundColor: _cleared ? colors.legendary : colors.pathReview,
          foregroundColor: _cleared ? colors.onLegendary : colors.onPathReview,
        ),
        const SizedBox(height: GameTokens.spaceLg),
        const ScienceChallengePrivacyNote(),
      ],
    );
  }

  Widget _done(BuildContext context) {
    final colors = context.gamePalette;
    return Column(
      key: const ValueKey('unit-legendary-done'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScienceChallengeHeader(
          eyebrow: 'ラボ・ブリーフ  /  単元の高難度検証  /  記録',
          title: _cleared
              ? '単元の高難度検証を完了'
              : _stoppedAfterWrong
              ? '今回はここまで'
              : '自己比較を完了',
          body: _cleared
              ? '単元内の複数概念を、別場面の固定問題で横断しました。'
              : _stoppedAfterWrong
              ? '最初の誤答でこの検証を終了しました。試行余力が0なら、回復練習の後で別の固定問題を検証できます。'
              : '単元の高難度検証は未完了です。通常練習で確かめ、また検証できます。',
          icon: _cleared
              ? Icons.fact_check_outlined
              : Icons.psychology_alt_outlined,
          accent: _cleared ? colors.legendary : colors.pathReview,
          onAccent: _cleared ? colors.onLegendary : colors.onPathReview,
          mascotReaction: _cleared
              ? GameCharacterReaction.celebrate
              : GameCharacterReaction.encourage,
        ),
        const SizedBox(height: GameTokens.spaceXl),
        ScienceChallengeSurface(
          label: _cleared ? '習得の断定ではありません' : '通常の探究ノートは失いません',
          icon: Icons.info_outline,
          child: Text(
            _cleared
                ? '表示するのは「単元の高難度検証を完了」です。単元全体の理解を自動判定しません。'
                : _stoppedAfterWrong
                ? '次の固定問題と正解は開いていません。回答内容も保存しません。'
                : '通常の探究ノート・連続観測・学校課題の利用条件は変わりません。',
          ),
        ),
        if (widget.onReturnToPath != null) ...[
          const SizedBox(height: GameTokens.spaceLg),
          ScienceChallengePrimaryButton(
            key: const ValueKey('unit-legendary-return-to-path'),
            label: _cleared ? '探究ノートへ戻る' : '通常練習へ戻る',
            icon: Icons.route_outlined,
            onPressed: _returnCalled ? null : _returnToPath,
            backgroundColor: colors.pathActive,
            foregroundColor: colors.onPathActive,
          ),
        ],
      ],
    );
  }
}

class _UnitLegendaryChoice extends StatelessWidget {
  const _UnitLegendaryChoice({
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
          color: selected
              ? colors.legendary.withValues(alpha: 0.16)
              : colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GameTokens.radiusMd),
            side: BorderSide(
              color: selected ? colors.legendary : colors.border,
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
                      color: selected ? colors.legendary : colors.inkMuted,
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

bool _sameChallengeContract(
  ScienceUnitLegendaryScreen left,
  ScienceUnitLegendaryScreen right,
) {
  if (left.isUnlocked != right.isUnlocked ||
      left.unitTitle != right.unitTitle ||
      left.challenges.length != right.challenges.length) {
    return false;
  }
  for (var index = 0; index < left.challenges.length; index++) {
    final a = left.challenges[index];
    final b = right.challenges[index];
    if (!identical(a.section, b.section) ||
        a.conceptLabel != b.conceptLabel ||
        a.practiceAttempt != b.practiceAttempt) {
      return false;
    }
  }
  return true;
}
