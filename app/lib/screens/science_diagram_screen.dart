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

enum _ReflectionChoice { keep, revise }

/// Path上の「しくみ図」レッスン。
///
/// 回答・理由・最後の一文はこのrouteのStateにだけ置き、保存も送信もしない。
/// 正解を含む[LocalCognitiveTask]はsubmit後の比較サブツリーでだけ文字列化する。
class ScienceDiagramScreen extends StatefulWidget {
  const ScienceDiagramScreen({
    super.key,
    required this.section,
    required this.conceptLabel,
    required this.practiceAttempt,
    required this.onCompleted,
    this.onReturnToPath,
    this.onNeedEvidence,
    this.onHeartLoss,
  }) : assert(practiceAttempt >= 0);

  final Section section;
  final String conceptLabel;
  final int practiceAttempt;
  final VoidCallback onCompleted;
  final LearningNeedEvidenceReported? onNeedEvidence;
  final LearningHeartLossReported? onHeartLoss;

  /// 完了の保存通知とは分けて、本人が明示的に学習パスへ戻るときだけ呼ぶ。
  final VoidCallback? onReturnToPath;

  @override
  State<ScienceDiagramScreen> createState() => _ScienceDiagramScreenState();
}

class _ScienceDiagramScreenState extends State<ScienceDiagramScreen> {
  final TextEditingController _reason = TextEditingController();
  final TextEditingController _reflection = TextEditingController();
  final ScrollController _scroll = ScrollController();

  CognitiveTaskResponse? _response;
  _ReflectionChoice? _reflectionChoice;
  bool _submitted = false;
  bool _completionCalled = false;
  bool _finished = false;
  bool _needEvidenceReported = false;

  LocalPracticeVariant get _variant =>
      widget.section.practiceVariantForAttempt(widget.practiceAttempt);

  LocalCognitiveTaskPrompt get _prompt => _variant.cognitiveTask.prompt;

  bool get _canSubmit =>
      isCognitiveTaskResponseComplete(_prompt, _response) &&
      _reason.text.trim().isNotEmpty;

  bool get _canComplete =>
      _response != null &&
      matchesCognitiveTaskSolution(_variant.cognitiveTask, _response) &&
      _reflectionChoice != null &&
      _reflection.text.trim().isNotEmpty;

  @override
  void didUpdateWidget(covariant ScienceDiagramScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.section, widget.section) ||
        oldWidget.practiceAttempt != widget.practiceAttempt) {
      _reason.clear();
      _reflection.clear();
      _response = null;
      _reflectionChoice = null;
      _submitted = false;
      _completionCalled = false;
      _finished = false;
      _needEvidenceReported = false;
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    _reflection.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canSubmit || _submitted) return;
    final correct = matchesCognitiveTaskSolution(
      _variant.cognitiveTask,
      _response,
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
          fixedTaskId: 'diagram:${widget.practiceAttempt}:cognitive',
        ),
      );
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submitted = true);
    _returnToTop();
  }

  void _reportNeed(String? needCode, LearningNeedEvidenceKind kind) {
    if (_needEvidenceReported || needCode == null) return;
    _needEvidenceReported = true;
    widget.onNeedEvidence?.call(
      LearningNeedEvidence(
        conceptKey: widget.section.conceptKey,
        needCode: needCode,
        kind: kind,
      ),
    );
  }

  void _complete() {
    if (!_canComplete || _completionCalled) return;
    _completionCalled = true;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _finished = true);
    widget.onCompleted();
  }

  void _tryAgain() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _submitted = false;
      _response = null;
      _reflectionChoice = null;
      _reflection.clear();
    });
    _returnToTop();
  }

  void _returnToPath() {
    final callback = widget.onReturnToPath;
    if (callback != null) {
      callback();
    } else {
      Navigator.of(context).maybePop();
    }
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
    final headerBody = _finished
        ? lang.t(
            '自分の組み方と教材を比べ終えました。',
            'You compared your build with the material.',
          )
        : _submitted
        ? lang.t(
            '自分の組み方と教材のしくみを比べます。',
            'Compare your build with the material\'s mechanism.',
          )
        : lang.t(
            'カードでしくみを組み、理由を一文で説明します。',
            'Build the mechanism with cards and explain why in one sentence.',
          );

    return Scaffold(
      key: const ValueKey('science-diagram-screen'),
      backgroundColor: colors.canvas,
      appBar: hasSharedChrome
          ? null
          : AppBar(
              backgroundColor: colors.canvas,
              foregroundColor: colors.ink,
              title: Text(
                lang.t('しくみ図', 'Mechanism diagram'),
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
              key: const ValueKey('science-diagram-scroll'),
              controller: _scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                GameTokens.spaceLg,
                GameTokens.spaceSm,
                GameTokens.spaceLg,
                GameTokens.spaceXl + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ScienceChallengeHeader(
                    eyebrow: 'しくみ図  /  観察中',
                    title: widget.conceptLabel,
                    body: headerBody,
                    icon: Icons.account_tree_rounded,
                    accent: colors.pathReview,
                    onAccent: colors.onPathReview,
                    mascotReaction: _finished
                        ? GameCharacterReaction.celebrate
                        : _submitted
                        ? GameCharacterReaction.encourage
                        : GameCharacterReaction.thinking,
                  ),
                  const SizedBox(height: GameTokens.spaceLg),
                  AnimatedSwitcher(
                    duration: reduceMotion ? Duration.zero : Motion.state,
                    switchInCurve: Motion.stateCurve,
                    switchOutCurve: Motion.quickCurve,
                    child: _finished
                        ? _FinishedStep(
                            key: const ValueKey('science-diagram-finished'),
                            conceptLabel: widget.conceptLabel,
                            onReturnToPath: widget.onReturnToPath,
                          )
                        : _submitted
                        ? _ComparisonStep(
                            key: const ValueKey('science-diagram-compare'),
                            conceptLabel: widget.conceptLabel,
                            transferPrompt: _variant.transferPrompt,
                            prompt: _prompt,
                            response: _response!,
                            reason: _reason.text.trim(),
                            // solutionを文字列化するのはsubmit後のこの分岐だけ。
                            solutionSummary: cognitiveTaskSolutionSummary(
                              _variant.cognitiveTask,
                            ),
                            expectedOutcome: _variant.expectedOutcome,
                            expectedReason: _variant.expectedReason,
                            isCorrect: matchesCognitiveTaskSolution(
                              _variant.cognitiveTask,
                              _response,
                            ),
                            choice: _reflectionChoice,
                            reflectionController: _reflection,
                            canComplete: _canComplete,
                            onChoiceChanged: (choice) =>
                                setState(() => _reflectionChoice = choice),
                            onReflectionChanged: (_) => setState(() {}),
                            onComplete: _complete,
                            onTryAgain: _tryAgain,
                            onDefer: _returnToPath,
                          )
                        : _ComposeStep(
                            key: const ValueKey('science-diagram-compose'),
                            conceptLabel: widget.conceptLabel,
                            transferPrompt: _variant.transferPrompt,
                            prompt: _prompt,
                            response: _response,
                            reasonController: _reason,
                            canSubmit: _canSubmit,
                            onResponseChanged: (response) =>
                                setState(() => _response = response),
                            onReasonChanged: (_) => setState(() {}),
                            onSubmit: _submit,
                            onDefer: _returnToPath,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposeStep extends StatelessWidget {
  const _ComposeStep({
    super.key,
    required this.conceptLabel,
    required this.transferPrompt,
    required this.prompt,
    required this.response,
    required this.reasonController,
    required this.canSubmit,
    required this.onResponseChanged,
    required this.onReasonChanged,
    required this.onSubmit,
    required this.onDefer,
  });

  final String conceptLabel;
  final String transferPrompt;
  final LocalCognitiveTaskPrompt prompt;
  final CognitiveTaskResponse? response;
  final TextEditingController reasonController;
  final bool canSubmit;
  final ValueChanged<CognitiveTaskResponse> onResponseChanged;
  final ValueChanged<String> onReasonChanged;
  final VoidCallback onSubmit;
  final VoidCallback onDefer;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    final responseReady = isCognitiveTaskResponseComplete(prompt, response);

    return Semantics(
      container: true,
      label: lang.t(
        'しくみ図、第1段階。カードで考えを組み、理由を一文書く',
        'Mechanism diagram, step 1. Build your idea with cards and write one sentence of reasoning',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LessonHeader(
            step: '1 / 2',
            eyebrow: 'しくみを組む',
            title: conceptLabel,
            body: lang.t(
              '先にカードで予想を組み、そのあと決め手を一文だけ書きます。',
              'First build your prediction with cards, then write the key reason in one sentence.',
            ),
          ),
          const SizedBox(height: GameTokens.spaceXl),
          _PromptSurface(prompt: transferPrompt),
          const SizedBox(height: GameTokens.spaceXl),
          CognitiveTaskInput(
            prompt: prompt,
            response: response,
            onChanged: onResponseChanged,
          ),
          const SizedBox(height: GameTokens.spaceXl),
          AnimatedSwitcher(
            duration: ReduceMotionScope.of(context)
                ? Duration.zero
                : Motion.state,
            child: responseReady
                ? Column(
                    key: const ValueKey('science-diagram-reason-area'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CognitiveTaskResponseSummary(
                        prompt: prompt,
                        response: response!,
                        label: lang.t('あなたの組み方', 'Your build'),
                      ),
                      const SizedBox(height: GameTokens.spaceLg),
                      Text(
                        lang.t('なぜそう考えた？', 'Why do you think so?'),
                        style: t.textTheme.titleLarge
                            ?.copyWith(color: colors.ink)
                            .jaWeight(FontWeight.w800),
                      ),
                      const SizedBox(height: GameTokens.spaceXs),
                      Text(
                        lang.t(
                          '条件・力の向き・変化の順から、決め手を一文で書きます。',
                          'Write the key reason in one sentence: a condition, force direction, or order of change.',
                        ),
                        style: t.textTheme.bodyMedium?.copyWith(
                          color: colors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: GameTokens.spaceMd),
                      _LocalSentenceField(
                        key: const ValueKey('science-diagram-reason'),
                        controller: reasonController,
                        label: lang.t(
                          'この答えにした理由（1文）',
                          'Why you chose this answer (1 sentence)',
                        ),
                        hint: lang.t(
                          '例：変えた条件が一つだけだから。',
                          'e.g. Because only one condition was changed.',
                        ),
                        onChanged: onReasonChanged,
                      ),
                      const SizedBox(height: GameTokens.spaceLg),
                      FilledButton.icon(
                        key: const ValueKey('science-diagram-submit'),
                        onPressed: canSubmit ? onSubmit : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          backgroundColor: colors.pathActive,
                          foregroundColor: colors.onPathActive,
                        ),
                        icon: const Icon(Icons.compare_arrows_rounded),
                        label: Text(
                          lang.t(
                            '教材の組み方と比べる',
                            'Compare with the material\'s build',
                          ),
                        ),
                      ),
                    ],
                  )
                : Container(
                    key: const ValueKey('science-diagram-reason-locked'),
                    padding: const EdgeInsets.all(GameTokens.spaceLg),
                    decoration: BoxDecoration(
                      color: colors.surfaceRaised,
                      borderRadius: BorderRadius.circular(GameTokens.radiusLg),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.arrow_upward_rounded,
                          color: colors.pathActive,
                        ),
                        const SizedBox(width: GameTokens.spaceSm),
                        Expanded(
                          child: Text(
                            lang.t(
                              'カードをすべて決めると、理由を書く欄が開きます。',
                              'Set all the cards to open the reason field.',
                            ),
                            style: t.textTheme.bodyMedium?.copyWith(
                              color: colors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: GameTokens.spaceLg),
          _PrivacyNote(),
          const SizedBox(height: GameTokens.spaceSm),
          _DeferDiagramButton(onPressed: onDefer),
        ],
      ),
    );
  }
}

class _ComparisonStep extends StatelessWidget {
  const _ComparisonStep({
    super.key,
    required this.conceptLabel,
    required this.transferPrompt,
    required this.prompt,
    required this.response,
    required this.reason,
    required this.solutionSummary,
    required this.expectedOutcome,
    required this.expectedReason,
    required this.isCorrect,
    required this.choice,
    required this.reflectionController,
    required this.canComplete,
    required this.onChoiceChanged,
    required this.onReflectionChanged,
    required this.onComplete,
    required this.onTryAgain,
    required this.onDefer,
  });

  final String conceptLabel;
  final String transferPrompt;
  final LocalCognitiveTaskPrompt prompt;
  final CognitiveTaskResponse response;
  final String reason;
  final String solutionSummary;
  final String expectedOutcome;
  final String expectedReason;
  final bool isCorrect;
  final _ReflectionChoice? choice;
  final TextEditingController reflectionController;
  final bool canComplete;
  final ValueChanged<_ReflectionChoice> onChoiceChanged;
  final ValueChanged<String> onReflectionChanged;
  final VoidCallback onComplete;
  final VoidCallback onTryAgain;
  final VoidCallback onDefer;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;

    return Semantics(
      container: true,
      label: lang.t(
        'しくみ図、第2段階。自分の組み方と教材を比べる',
        'Mechanism diagram, step 2. Compare your build with the material',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LessonHeader(
            step: '2 / 2',
            eyebrow: '教材と比べる',
            title: conceptLabel,
            body: lang.t(
              '教材の根拠と照らし、違っていたら組み直してから自分の一文を残します。',
              'No scoring. Find the differences, then keep your own one sentence.',
            ),
          ),
          const SizedBox(height: GameTokens.spaceXl),
          _PromptSurface(prompt: transferPrompt),
          const SizedBox(height: GameTokens.spaceLg),
          CognitiveTaskResponseSummary(
            prompt: prompt,
            response: response,
            label: lang.t('あなたの組み方', 'Your build'),
          ),
          const SizedBox(height: GameTokens.spaceMd),
          _ReasonSurface(reason: reason),
          const SizedBox(height: GameTokens.spaceXl),
          _MaterialComparison(
            solutionSummary: solutionSummary,
            expectedOutcome: expectedOutcome,
            expectedReason: expectedReason,
          ),
          if (!isCorrect) ...[
            const SizedBox(height: GameTokens.spaceLg),
            ScienceChallengeSurface(
              label: '教材の組み方と違うところがあります',
              icon: Icons.menu_book_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('教材の根拠を見て、もう一度カードを組みます。'),
                  const SizedBox(height: GameTokens.spaceMd),
                  OutlinedButton.icon(
                    key: const ValueKey('science-diagram-try-again'),
                    onPressed: onTryAgain,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('カードを組み直す'),
                  ),
                ],
              ),
            ),
          ],
          if (isCorrect) ...[
            const SizedBox(height: GameTokens.spaceXl),
            Text(
              '自分の考えをどうする？',
              style: t.textTheme.titleLarge
                  ?.copyWith(color: colors.ink)
                  .jaWeight(FontWeight.w800),
            ),
            const SizedBox(height: GameTokens.spaceXs),
            Text(
              '教材と同じでも違っていても、次に使う自分の一文を選びます。',
              style: t.textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
            ),
            const SizedBox(height: GameTokens.spaceMd),
            _DecisionButton(
              key: const ValueKey('science-diagram-keep'),
              label: 'この考えを残す',
              description: '理由をより短く、使える形にする',
              icon: Icons.bookmark_add_outlined,
              selected: choice == _ReflectionChoice.keep,
              onTap: () => onChoiceChanged(_ReflectionChoice.keep),
            ),
            const SizedBox(height: GameTokens.spaceSm),
            _DecisionButton(
              key: const ValueKey('science-diagram-revise'),
              label: '考えを直す',
              description: '比較して変わったところを書き直す',
              icon: Icons.edit_note_rounded,
              selected: choice == _ReflectionChoice.revise,
              onTap: () => onChoiceChanged(_ReflectionChoice.revise),
            ),
            if (choice != null) ...[
              const SizedBox(height: GameTokens.spaceLg),
              _LocalSentenceField(
                key: const ValueKey('science-diagram-reflection'),
                controller: reflectionController,
                label: choice == _ReflectionChoice.keep
                    ? '残したい自分の一文'
                    : '直して残す自分の一文',
                hint: choice == _ReflectionChoice.keep
                    ? '次の場面でも使える言い方にする'
                    : '変わった考えを一文にする',
                onChanged: onReflectionChanged,
              ),
              const SizedBox(height: GameTokens.spaceLg),
              FilledButton.icon(
                key: const ValueKey('science-diagram-complete'),
                onPressed: canComplete ? onComplete : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: colors.pathActive,
                  foregroundColor: colors.onPathActive,
                ),
                icon: const Icon(Icons.check_rounded),
                label: const Text('この一文で完了'),
              ),
            ],
          ],
          const SizedBox(height: GameTokens.spaceLg),
          _PrivacyNote(),
          const SizedBox(height: GameTokens.spaceSm),
          _DeferDiagramButton(onPressed: onDefer),
        ],
      ),
    );
  }
}

class _DeferDiagramButton extends StatelessWidget {
  const _DeferDiagramButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    key: const ValueKey('science-diagram-defer'),
    onPressed: onPressed,
    icon: const Icon(Icons.bookmark_add_outlined),
    label: const Text('このステップは後でやる'),
  );
}

class _LessonHeader extends StatelessWidget {
  const _LessonHeader({
    required this.step,
    required this.eyebrow,
    required this.title,
    required this.body,
  });

  final String step;
  final String eyebrow;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: GameTokens.spaceSm,
          runSpacing: GameTokens.spaceXs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: colors.pathActive,
                borderRadius: BorderRadius.circular(GameTokens.radiusPill),
              ),
              child: Text(
                '観察手順 $step',
                style: t.textTheme.labelMedium
                    ?.copyWith(color: colors.onPathActive)
                    .jaWeight(FontWeight.w800),
              ),
            ),
            Text(
              eyebrow,
              style: t.textTheme.labelLarge
                  ?.copyWith(color: colors.pathActive)
                  .jaWeight(FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: GameTokens.spaceSm),
        Text(
          title,
          style: t.textTheme.headlineMedium
              ?.copyWith(color: colors.ink, height: 1.35)
              .jaWeight(FontWeight.w800),
        ),
        const SizedBox(height: GameTokens.spaceSm),
        Text(
          body,
          style: t.textTheme.bodyLarge?.copyWith(color: colors.inkMuted),
        ),
      ],
    );
  }
}

class _PromptSurface extends StatelessWidget {
  const _PromptSurface({required this.prompt});

  final String prompt;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    return Semantics(
      key: const ValueKey('science-diagram-transfer-prompt'),
      container: true,
      label: lang.t('考える場面。$prompt', 'Scenario. $prompt'),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(GameTokens.spaceLg),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(GameTokens.radiusLg),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.science_rounded, color: colors.pathActive),
                  const SizedBox(width: GameTokens.spaceSm),
                  Expanded(
                    child: Text(
                      lang.t('この場面を考える', 'Think about this scenario'),
                      style: t.textTheme.labelLarge
                          ?.copyWith(color: colors.pathActive)
                          .jaWeight(FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: GameTokens.spaceSm),
              Text(
                prompt,
                style: t.textTheme.bodyLarge?.copyWith(color: colors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReasonSurface extends StatelessWidget {
  const _ReasonSurface({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    return Semantics(
      container: true,
      label: lang.t('あなたが書いた理由。$reason', 'Your reason. $reason'),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(GameTokens.spaceLg),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(GameTokens.radiusLg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lang.t('あなたが書いた理由', 'Your reason'),
                style: t.textTheme.labelLarge
                    ?.copyWith(color: colors.inkMuted)
                    .jaWeight(FontWeight.w800),
              ),
              const SizedBox(height: GameTokens.spaceXs),
              Text(
                reason,
                style: t.textTheme.bodyLarge?.copyWith(color: colors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaterialComparison extends StatelessWidget {
  const _MaterialComparison({
    required this.solutionSummary,
    required this.expectedOutcome,
    required this.expectedReason,
  });

  final String solutionSummary;
  final String expectedOutcome;
  final String expectedReason;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Semantics(
      key: const ValueKey('science-diagram-solution'),
      container: true,
      label: lang.t(
        '教材の組み方。$solutionSummary。'
            '教材で確かめた結果。$expectedOutcome。教材の理由。$expectedReason',
        'Material\'s build. $solutionSummary. Result confirmed by the material. $expectedOutcome. Material\'s reason. $expectedReason',
      ),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(GameTokens.spaceLg),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(GameTokens.radiusLg),
            border: Border.all(color: colors.pathReview, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ComparisonLine(
                icon: Icons.account_tree_outlined,
                label: lang.t('教材の組み方', 'Material\'s build'),
                body: solutionSummary,
              ),
              _ComparisonDivider(color: colors.border),
              _ComparisonLine(
                icon: Icons.visibility_outlined,
                label: lang.t('教材で確かめた結果', 'Result confirmed by the material'),
                body: expectedOutcome,
              ),
              _ComparisonDivider(color: colors.border),
              _ComparisonLine(
                icon: Icons.lightbulb_outline_rounded,
                label: lang.t('教材の理由', 'Material\'s reason'),
                body: expectedReason,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComparisonLine extends StatelessWidget {
  const _ComparisonLine({
    required this.icon,
    required this.label,
    required this.body,
  });

  final IconData icon;
  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: colors.pathReview),
            const SizedBox(width: GameTokens.spaceSm),
            Expanded(
              child: Text(
                label,
                style: t.textTheme.labelLarge
                    ?.copyWith(color: colors.pathReview)
                    .jaWeight(FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: GameTokens.spaceXs),
        Text(body, style: t.textTheme.bodyLarge?.copyWith(color: colors.ink)),
      ],
    );
  }
}

class _ComparisonDivider extends StatelessWidget {
  const _ComparisonDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: GameTokens.spaceLg),
    child: Divider(color: color),
  );
}

class _DecisionButton extends StatelessWidget {
  const _DecisionButton({
    super.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: lang.t(
        '$label。$description${selected ? '。選択中' : ''}',
        '$label. $description${selected ? '. Selected' : ''}',
      ),
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? colors.surfaceRaised : colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GameTokens.radiusMd),
            side: BorderSide(
              color: selected ? colors.pathActive : colors.border,
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: GameTokens.minTouchTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.all(GameTokens.spaceMd),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      selected ? Icons.check_circle_rounded : icon,
                      color: colors.pathActive,
                    ),
                    const SizedBox(width: GameTokens.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(color: colors.ink)
                                .jaWeight(FontWeight.w800),
                          ),
                          const SizedBox(height: GameTokens.spaceXs),
                          Text(
                            description,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.inkMuted),
                          ),
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

class _LocalSentenceField extends StatelessWidget {
  const _LocalSentenceField({
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
  Widget build(BuildContext context) => TextField(
    controller: controller,
    minLines: 2,
    maxLines: 3,
    maxLength: 140,
    textInputAction: TextInputAction.done,
    onChanged: onChanged,
    decoration: InputDecoration(labelText: label, hintText: hint),
  );
}

class _PrivacyNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    return Semantics(
      container: true,
      label: lang.t(
        '入力は保存も送信もせず、構造の復習コードだけを端末に保存し、成績や理解度の認定には使いません',
        'Input is not saved or sent. Only a review code for the structure is stored on this device, and it is not used for grades or mastery',
      ),
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.phonelink_lock_outlined,
              size: 20,
              color: colors.inkMuted,
            ),
            const SizedBox(width: GameTokens.spaceSm),
            Expanded(
              child: Text(
                lang.t(
                  '入力内容はこの画面だけで使い、保存・送信しません。構造の不一致があった場合も、固定の復習コードだけをこの端末に保存し、成績や理解度の認定には使いません。',
                  'Your input is used only on this screen and is not saved or sent. If the structure didn\'t match, only a fixed review code is stored on this device. It is not used for grades or mastery.',
                ),
                style: t.textTheme.bodySmall?.copyWith(color: colors.inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinishedStep extends StatelessWidget {
  const _FinishedStep({
    super.key,
    required this.conceptLabel,
    required this.onReturnToPath,
  });

  final String conceptLabel;
  final VoidCallback? onReturnToPath;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    return Semantics(
      container: true,
      liveRegion: true,
      label: lang.t(
        'しくみ図を完了。$conceptLabelを最後まで見比べました',
        'Mechanism diagram complete. You compared $conceptLabel to the end',
      ),
      child: Container(
        padding: const EdgeInsets.all(GameTokens.spaceXl),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(GameTokens.radiusLg),
          border: Border.all(color: colors.pathComplete, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.check_circle_rounded,
              size: 42,
              color: colors.pathComplete,
            ),
            const SizedBox(height: GameTokens.spaceMd),
            Text(
              lang.t('見比べ終わりました', 'Comparison done'),
              style: t.textTheme.headlineSmall
                  ?.copyWith(color: colors.ink)
                  .jaWeight(FontWeight.w800),
            ),
            const SizedBox(height: GameTokens.spaceSm),
            Text(
              lang.t(
                '理解度の自動判定ではなく、自分の考えと教材を最後まで比べた完了です。',
                'This isn\'t an automatic mastery check. It means you compared your idea with the material to the end.',
              ),
              style: t.textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
            ),
            if (onReturnToPath != null) ...[
              const SizedBox(height: GameTokens.spaceXl),
              FilledButton.icon(
                key: const ValueKey('science-diagram-return-to-path'),
                onPressed: onReturnToPath,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  backgroundColor: colors.pathActive,
                  foregroundColor: colors.onPathActive,
                ),
                icon: const Icon(Icons.route_rounded),
                label: Text(lang.t('探究ノートへ戻る', 'Back to learning path')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
