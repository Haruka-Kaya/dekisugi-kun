import 'dart:async';

import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../learning/domain/learning_heart.dart';
import '../learning/domain/learning_need.dart';
import '../models/game_path.dart';
import '../models/unit.dart';
import '../services/challenge_deadline.dart';
import '../ui/_material.dart';
import '../widgets/science_challenge_support.dart';
import '../widgets/science_mini_game_widgets.dart';

@immutable
class ScienceLightningOption {
  const ScienceLightningOption({required this.id, required this.text});

  final String id;
  final String text;
}

@immutable
class ScienceLightningQuestion {
  const ScienceLightningQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctOptionId,
    this.needCode,
  });

  final String id;
  final String prompt;
  final List<ScienceLightningOption> options;
  final String correctOptionId;
  final String? needCode;
}

@immutable
class ScienceLightningContent {
  const ScienceLightningContent({
    required this.questions,
    required this.timeLimit,
  });

  final List<ScienceLightningQuestion> questions;
  final Duration timeLimit;
}

enum _LightningPhase { intro, playing, result }

enum _LightningOutcome { cleared, needsReview, timeUp }

/// 固定された短い問題列を順番に解くLightning。
///
/// 1問でも誤るとそのrunを閉じ、次の選択肢や後続問題を出さない。時間切れと
/// 誤答だけ回答内容を含まないheart lossを通知し、時間切れでは減らさない。
/// 全問通過後の明示CTAだけが完了を通知する。
class ScienceLightningScreen extends StatefulWidget {
  const ScienceLightningScreen({
    super.key,
    required this.section,
    required this.conceptLabel,
    required this.practiceAttempt,
    required this.content,
    required this.onCompleted,
    required this.onRetryRequested,
    this.onNeedEvidence,
    this.onHeartLoss,
    this.elapsedClock,
  }) : assert(practiceAttempt >= 0);

  final Section section;
  final String conceptLabel;
  final int practiceAttempt;
  final ScienceLightningContent content;
  final VoidCallback onCompleted;
  final Future<bool> Function() onRetryRequested;
  final LearningNeedEvidenceReported? onNeedEvidence;
  final LearningHeartLossReported? onHeartLoss;
  final ChallengeElapsedClock? elapsedClock;

  @override
  State<ScienceLightningScreen> createState() => _ScienceLightningScreenState();
}

class _ScienceLightningScreenState extends State<ScienceLightningScreen>
    with WidgetsBindingObserver {
  final ScrollController _scroll = ScrollController();
  Timer? _timer;
  late ChallengeDeadline _deadline;
  _LightningPhase _phase = _LightningPhase.intro;
  _LightningOutcome? _outcome;
  int _questionIndex = 0;
  String? _selectedOptionId;
  late int _remainingSeconds;
  bool _completionCalled = false;
  bool _retryChecking = false;
  final Set<String> _observedNeedCodes = {};
  final Set<String> _demonstratedNeedCodes = {};

  LocalPracticeVariant get _variant =>
      widget.section.practiceVariantForAttempt(widget.practiceAttempt);
  int get _initialSeconds => _deadline.initialSeconds;

  @override
  void initState() {
    super.initState();
    assert(_debugValidateLightningContent(widget.content));
    WidgetsBinding.instance.addObserver(this);
    _deadline = ChallengeDeadline(
      widget.content.timeLimit,
      elapsedClock: widget.elapsedClock,
    );
    _remainingSeconds = _initialSeconds;
  }

  @override
  void didUpdateWidget(covariant ScienceLightningScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.section, widget.section) ||
        oldWidget.practiceAttempt != widget.practiceAttempt ||
        !identical(oldWidget.content, widget.content) ||
        oldWidget.elapsedClock != widget.elapsedClock) {
      assert(_debugValidateLightningContent(widget.content));
      _timer?.cancel();
      _deadline = ChallengeDeadline(
        widget.content.timeLimit,
        elapsedClock: widget.elapsedClock,
      );
      _phase = _LightningPhase.intro;
      _outcome = null;
      _questionIndex = 0;
      _selectedOptionId = null;
      _remainingSeconds = _initialSeconds;
      _completionCalled = false;
      _retryChecking = false;
      _observedNeedCodes.clear();
      _demonstratedNeedCodes.clear();
    }
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
    if (_phase != _LightningPhase.intro) return;
    _deadline.start();
    setState(() {
      _phase = _LightningPhase.playing;
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
    if (!mounted || _phase != _LightningPhase.playing) return;
    var remaining = _deadline.remainingSeconds;
    if (foregroundTick && _remainingSeconds > 0) {
      final tickRemaining = _remainingSeconds - 1;
      if (tickRemaining < remaining) remaining = tickRemaining;
    }
    if (remaining == 0) {
      _end(_LightningOutcome.timeUp);
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

  void _submit() {
    if (_phase != _LightningPhase.playing || _selectedOptionId == null) return;
    final question = widget.content.questions[_questionIndex];
    final correct = _selectedOptionId == question.correctOptionId;
    _reportNeed(question.needCode, correct: correct);
    if (!correct) {
      widget.onHeartLoss?.call(
        LearningHeartLossEvidence(
          fixedTaskId:
              'lightning:${widget.practiceAttempt}:question:${question.id}',
        ),
      );
      _end(_LightningOutcome.needsReview);
      return;
    }
    if (_questionIndex == widget.content.questions.length - 1) {
      _end(_LightningOutcome.cleared);
      return;
    }
    setState(() {
      _questionIndex++;
      _selectedOptionId = null;
    });
    _returnToTop();
  }

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

  void _end(_LightningOutcome outcome) {
    if (_phase == _LightningPhase.result) return;
    _timer?.cancel();
    _timer = null;
    _deadline.stop();
    setState(() {
      _outcome = outcome;
      _phase = _LightningPhase.result;
      _selectedOptionId = null;
    });
    _returnToTop();
  }

  Future<void> _retry() async {
    if (_phase != _LightningPhase.result ||
        _outcome == _LightningOutcome.cleared ||
        _retryChecking) {
      return;
    }
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
      _deadline.reset(limit: widget.content.timeLimit);
      _phase = _LightningPhase.intro;
      _outcome = null;
      _questionIndex = 0;
      _selectedOptionId = null;
      _remainingSeconds = _initialSeconds;
      _retryChecking = false;
    });
    _returnToTop();
  }

  void _complete() {
    if (_outcome != _LightningOutcome.cleared || _completionCalled) return;
    _completionCalled = true;
    widget.onCompleted();
  }

  void _returnToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Scaffold(
      key: const ValueKey('science-lightning-screen'),
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.canvas,
        foregroundColor: colors.ink,
        title: Text(
          'Lightning',
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
              key: const ValueKey('science-lightning-scroll'),
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(
                GameTokens.spaceLg,
                GameTokens.spaceSm,
                GameTokens.spaceLg,
                GameTokens.spaceXl + MediaQuery.paddingOf(context).bottom,
              ),
              child: switch (_phase) {
                _LightningPhase.intro => _buildIntro(context),
                _LightningPhase.playing => _buildPlaying(context),
                _LightningPhase.result => _buildResult(context),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntro(BuildContext context) {
    final colors = context.gamePalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScienceChallengeHeader(
          eyebrow: 'OPTIONAL  /  LIGHTNING',
          title: widget.conceptLabel,
          body:
              '${widget.content.questions.length}問の固定列を$_initialSeconds秒で解きます。',
          icon: Icons.bolt_rounded,
          accent: colors.legendary,
          onAccent: colors.onLegendary,
          mascotReaction: GameCharacterReaction.invite,
        ),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengeSurface(
          label: '速さより、根拠',
          icon: Icons.shield_outlined,
          child: const Text(
            '誤答か時間切れでそのrunは終了します。時間切れでは学習ハートは減らず、固定問題の誤答だけ、'
            '個人モードでは1つ減ります。Path・連続学習・報酬は変わらず、学校モードはハート無制限です。',
          ),
        ),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengeSurface(
          label: '学習する場面',
          icon: Icons.science_outlined,
          child: Text(
            '${_variant.transferPrompt}\n\n${_variant.cognitiveTask.prompt}',
          ),
        ),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengePrimaryButton(
          key: const ValueKey('lightning-start'),
          label: 'Lightningを始める',
          icon: Icons.play_arrow_rounded,
          onPressed: _start,
          backgroundColor: colors.legendary,
          foregroundColor: colors.onLegendary,
        ),
        const SizedBox(height: GameTokens.spaceLg),
        const ScienceChallengePrivacyNote(),
      ],
    );
  }

  Widget _buildPlaying(BuildContext context) {
    final colors = context.gamePalette;
    final question = widget.content.questions[_questionIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScienceMiniGameCountdown(
          remainingSeconds: _remainingSeconds,
          totalSeconds: _initialSeconds,
          stepLabel:
              '${_questionIndex + 1}/${widget.content.questions.length}問目',
        ),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengeSurface(
          label: '短く判断する',
          icon: Icons.bolt_outlined,
          child: Text(
            question.prompt,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: colors.ink)
                .jaWeight(FontWeight.w800),
          ),
        ),
        const SizedBox(height: GameTokens.spaceLg),
        for (var index = 0; index < question.options.length; index++) ...[
          ScienceMiniGameChoice(
            key: ValueKey('lightning-option-${question.options[index].id}'),
            text: question.options[index].text,
            position: index + 1,
            count: question.options.length,
            selected: _selectedOptionId == question.options[index].id,
            onPressed: () =>
                setState(() => _selectedOptionId = question.options[index].id),
          ),
          if (index < question.options.length - 1)
            const SizedBox(height: GameTokens.spaceSm),
        ],
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengePrimaryButton(
          key: const ValueKey('lightning-submit'),
          label: 'この答えで決定',
          icon: Icons.arrow_forward_rounded,
          onPressed: _selectedOptionId == null ? null : _submit,
          backgroundColor: colors.legendary,
          foregroundColor: colors.onLegendary,
        ),
        const SizedBox(height: GameTokens.spaceLg),
        const ScienceChallengePrivacyNote(),
      ],
    );
  }

  Widget _buildResult(BuildContext context) {
    final colors = context.gamePalette;
    final cleared = _outcome == _LightningOutcome.cleared;
    final title = switch (_outcome!) {
      _LightningOutcome.cleared => '固定問題列を完走',
      _LightningOutcome.needsReview => '今回はここまで',
      _LightningOutcome.timeUp => '時間になりました',
    };
    final body = switch (_outcome!) {
      _LightningOutcome.cleared => '全問を順番に判断できました。',
      _LightningOutcome.needsReview => '誤答後は別の選択肢や後続問題を開きません。通常練習で根拠を確かめられます。',
      _LightningOutcome.timeUp => '未回答の正解は表示しません。時間は学習成果として保存されません。',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScienceChallengeHeader(
          eyebrow: 'LIGHTNING  /  RESULT',
          title: title,
          body: body,
          icon: cleared ? Icons.bolt_rounded : Icons.pause_circle_outline,
          accent: cleared ? colors.pathComplete : colors.surfaceRaised,
          onAccent: cleared ? colors.onPathComplete : colors.ink,
          mascotReaction: cleared
              ? GameCharacterReaction.celebrate
              : GameCharacterReaction.encourage,
        ),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengeSurface(
          label: '学習記録への影響',
          icon: Icons.shield_outlined,
          child: const Text('この結果だけではPath・連続学習・報酬は変わりません。回答・正誤・残り時間も保存しません。'),
        ),
        const SizedBox(height: GameTokens.spaceLg),
        if (cleared)
          ScienceChallengePrimaryButton(
            key: const ValueKey('lightning-complete'),
            label: 'Lightningを完了する',
            icon: Icons.check_rounded,
            onPressed: _completionCalled ? null : _complete,
            backgroundColor: colors.pathComplete,
            foregroundColor: colors.onPathComplete,
          )
        else
          OutlinedButton.icon(
            key: const ValueKey('lightning-retry'),
            onPressed: _retryChecking ? null : () => unawaited(_retry()),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              foregroundColor: colors.ink,
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_retryChecking ? 'ハートを確認中…' : '最初からもう一度'),
          ),
        const SizedBox(height: GameTokens.spaceLg),
        const ScienceChallengePrivacyNote(),
      ],
    );
  }
}

bool _debugValidateLightningContent(ScienceLightningContent content) {
  final questionIds = content.questions.map((question) => question.id).toSet();
  if (content.questions.length < 2 ||
      content.timeLimit <= Duration.zero ||
      questionIds.length != content.questions.length) {
    return false;
  }
  return content.questions.every((question) {
    final optionIds = question.options.map((option) => option.id).toSet();
    return question.options.length >= 2 &&
        optionIds.length == question.options.length &&
        optionIds.contains(question.correctOptionId);
  });
}
