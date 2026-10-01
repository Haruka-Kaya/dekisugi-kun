import 'dart:async';

import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../learning/domain/learning_heart.dart';
import '../learning/domain/learning_need.dart';
import '../models/game_path.dart';
import '../models/unit.dart';
import '../services/challenge_deadline.dart';
import '../ui/_material.dart';
import '../widgets/game_activity_scaffold.dart';
import '../widgets/cognitive_task_input.dart';
import '../widgets/science_challenge_support.dart';
import '../widgets/science_mini_game_widgets.dart';

@immutable
class ScienceMatchTarget {
  const ScienceMatchTarget({required this.id, required this.text});

  final String id;
  final String text;
}

@immutable
class ScienceMatchPair {
  const ScienceMatchPair({
    required this.id,
    required this.concept,
    required this.correctTargetId,
    required this.needCode,
  });

  final String id;
  final String concept;
  final String correctTargetId;

  /// catalogが固定した一般化need。選択されたtarget IDとは独立している。
  final String needCode;
}

@immutable
class ScienceMatchLabContent {
  const ScienceMatchLabContent({
    required this.pairs,
    required this.targets,
    required this.timeLimit,
  });

  final List<ScienceMatchPair> pairs;
  final List<ScienceMatchTarget> targets;
  final Duration timeLimit;
}

enum _MatchPhase { intro, playing, result }

enum _MatchOutcome { cleared, needsReview, timeUp }

/// 概念と条件・結果を結ぶ、独立した時間制ミニゲーム。
///
/// 誤答はそのrunを直ちに終了するため、同じ問題で選択肢を総当たりできない。
/// 時間切れはheartを減らさず、誤答だけ回答内容を含まないheart lossを通知する。
/// 誤答時はpairに固定されたneedだけを通知し、Match正解で既存needを解消しない。
/// どちらもPath・streak・報酬には接続しない。
class ScienceMatchLabScreen extends StatefulWidget {
  const ScienceMatchLabScreen({
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
  final ScienceMatchLabContent content;
  final VoidCallback onCompleted;
  final Future<bool> Function() onRetryRequested;
  final LearningNeedEvidenceReported? onNeedEvidence;
  final LearningHeartLossReported? onHeartLoss;
  final ChallengeElapsedClock? elapsedClock;

  @override
  State<ScienceMatchLabScreen> createState() => _ScienceMatchLabScreenState();
}

class _ScienceMatchLabScreenState extends State<ScienceMatchLabScreen>
    with WidgetsBindingObserver {
  final ScrollController _scroll = ScrollController();
  Timer? _timer;
  late ChallengeDeadline _deadline;
  _MatchPhase _phase = _MatchPhase.intro;
  _MatchOutcome? _outcome;
  int _pairIndex = 0;
  String? _selectedTargetId;
  late int _remainingSeconds;
  bool _completionCalled = false;
  bool _retryChecking = false;
  final Set<String> _observedNeedCodes = {};

  LocalPracticeVariant get _variant =>
      widget.section.practiceVariantForAttempt(widget.practiceAttempt);
  int get _initialSeconds => _deadline.initialSeconds;

  @override
  void initState() {
    super.initState();
    assert(_debugValidateMatchContent(widget.content));
    WidgetsBinding.instance.addObserver(this);
    _deadline = ChallengeDeadline(
      widget.content.timeLimit,
      elapsedClock: widget.elapsedClock,
    );
    _remainingSeconds = _initialSeconds;
  }

  @override
  void didUpdateWidget(covariant ScienceMatchLabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.section, widget.section) ||
        oldWidget.practiceAttempt != widget.practiceAttempt ||
        !identical(oldWidget.content, widget.content) ||
        oldWidget.elapsedClock != widget.elapsedClock) {
      assert(_debugValidateMatchContent(widget.content));
      _timer?.cancel();
      _deadline = ChallengeDeadline(
        widget.content.timeLimit,
        elapsedClock: widget.elapsedClock,
      );
      _phase = _MatchPhase.intro;
      _outcome = null;
      _pairIndex = 0;
      _selectedTargetId = null;
      _remainingSeconds = _initialSeconds;
      _completionCalled = false;
      _retryChecking = false;
      _observedNeedCodes.clear();
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
    if (_phase != _MatchPhase.intro) return;
    _deadline.start();
    setState(() {
      _phase = _MatchPhase.playing;
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
    if (!mounted || _phase != _MatchPhase.playing) return;
    var remaining = _deadline.remainingSeconds;
    if (foregroundTick && _remainingSeconds > 0) {
      final tickRemaining = _remainingSeconds - 1;
      if (tickRemaining < remaining) remaining = tickRemaining;
    }
    if (remaining == 0) {
      _end(_MatchOutcome.timeUp);
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
    if (_phase != _MatchPhase.playing || _selectedTargetId == null) return;
    final pair = widget.content.pairs[_pairIndex];
    if (_selectedTargetId != pair.correctTargetId) {
      if (_observedNeedCodes.add(pair.needCode)) {
        widget.onNeedEvidence?.call(
          LearningNeedEvidence(
            conceptKey: widget.section.conceptKey,
            needCode: pair.needCode,
            kind: LearningNeedEvidenceKind.observed,
          ),
        );
      }
      widget.onHeartLoss?.call(
        LearningHeartLossEvidence(
          fixedTaskId:
              'match:${widget.practiceAttempt}:pair:${pair.id}:run:$_pairIndex',
        ),
      );
      _end(_MatchOutcome.needsReview);
      return;
    }
    if (_pairIndex == widget.content.pairs.length - 1) {
      _end(_MatchOutcome.cleared);
      return;
    }
    setState(() {
      _pairIndex++;
      _selectedTargetId = null;
    });
    _returnToTop();
  }

  void _end(_MatchOutcome outcome) {
    if (_phase == _MatchPhase.result) return;
    _timer?.cancel();
    _timer = null;
    _deadline.stop();
    setState(() {
      _outcome = outcome;
      _phase = _MatchPhase.result;
      _selectedTargetId = null;
    });
    _returnToTop();
  }

  Future<void> _retry() async {
    if (_phase != _MatchPhase.result ||
        _outcome == _MatchOutcome.cleared ||
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
      _phase = _MatchPhase.intro;
      _outcome = null;
      _pairIndex = 0;
      _selectedTargetId = null;
      _remainingSeconds = _initialSeconds;
      _retryChecking = false;
    });
    _returnToTop();
  }

  void _complete() {
    if (_outcome != _MatchOutcome.cleared || _completionCalled) return;
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
    final hasSharedChrome = GameActivityScaffold.hasSharedChrome(context);
    return Scaffold(
      key: const ValueKey('science-match-lab-screen'),
      backgroundColor: colors.canvas,
      appBar: hasSharedChrome
          ? null
          : AppBar(
              backgroundColor: colors.canvas,
              foregroundColor: colors.ink,
              title: Text(
                '対応づけ実験',
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
              key: const ValueKey('science-match-scroll'),
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(
                GameTokens.spaceLg,
                GameTokens.spaceSm,
                GameTokens.spaceLg,
                GameTokens.spaceXl + MediaQuery.paddingOf(context).bottom,
              ),
              child: switch (_phase) {
                _MatchPhase.intro => _buildIntro(context),
                _MatchPhase.playing => _buildPlaying(context),
                _MatchPhase.result => _buildResult(context),
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
          eyebrow: 'ラボ・ブリーフ  /  対応づけ実験  /  任意',
          title: widget.conceptLabel,
          body: '${widget.content.pairs.length}組を$_initialSeconds秒で結びます。',
          icon: Icons.hub_outlined,
          accent: colors.pathReview,
          onAccent: colors.onPathReview,
          mascotReaction: GameCharacterReaction.invite,
        ),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengeSurface(
          label: '時間切れは失点なし',
          icon: Icons.shield_outlined,
          child: const Text(
            '時間切れでは試行余力は減りません。組み合わせの誤答だけ、個人モードでは試行余力が1つ減ります。'
            '探究ノート・連続観測・報酬は変わらず、学校モードは試行余力が無制限です。',
          ),
        ),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengeSurface(
          label: '学習する場面',
          icon: Icons.science_outlined,
          child: Text(
            '${_variant.transferPrompt}\n\n'
            '${cognitiveTaskPromptSummary(_variant.cognitiveTask.prompt)}',
          ),
        ),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengePrimaryButton(
          key: const ValueKey('match-start'),
          label: '対応づけ実験を始める',
          icon: Icons.play_arrow_rounded,
          onPressed: _start,
          backgroundColor: colors.pathReview,
          foregroundColor: colors.onPathReview,
        ),
        const SizedBox(height: GameTokens.spaceLg),
        const ScienceChallengePrivacyNote(),
      ],
    );
  }

  Widget _buildPlaying(BuildContext context) {
    final colors = context.gamePalette;
    final pair = widget.content.pairs[_pairIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScienceMiniGameCountdown(
          remainingSeconds: _remainingSeconds,
          totalSeconds: _initialSeconds,
          stepLabel: '${_pairIndex + 1}/${widget.content.pairs.length}組目',
        ),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengeSurface(
          label: 'この概念に合う条件・結果は？',
          icon: Icons.psychology_alt_outlined,
          child: Text(
            pair.concept,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: colors.ink)
                .jaWeight(FontWeight.w800),
          ),
        ),
        const SizedBox(height: GameTokens.spaceLg),
        for (var index = 0; index < widget.content.targets.length; index++) ...[
          ScienceMiniGameChoice(
            key: ValueKey('match-target-${widget.content.targets[index].id}'),
            text: widget.content.targets[index].text,
            position: index + 1,
            count: widget.content.targets.length,
            selected: _selectedTargetId == widget.content.targets[index].id,
            onPressed: () => setState(
              () => _selectedTargetId = widget.content.targets[index].id,
            ),
          ),
          if (index < widget.content.targets.length - 1)
            const SizedBox(height: GameTokens.spaceSm),
        ],
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengePrimaryButton(
          key: const ValueKey('match-submit'),
          label: 'この組み合わせで決定',
          icon: Icons.link_rounded,
          onPressed: _selectedTargetId == null ? null : _submit,
          backgroundColor: colors.pathReview,
          foregroundColor: colors.onPathReview,
        ),
        const SizedBox(height: GameTokens.spaceLg),
        const ScienceChallengePrivacyNote(),
      ],
    );
  }

  Widget _buildResult(BuildContext context) {
    final colors = context.gamePalette;
    final cleared = _outcome == _MatchOutcome.cleared;
    final title = switch (_outcome!) {
      _MatchOutcome.cleared => 'すべて結べました',
      _MatchOutcome.needsReview => '今回はここまで',
      _MatchOutcome.timeUp => '時間になりました',
    };
    final body = switch (_outcome!) {
      _MatchOutcome.cleared => '概念と条件・結果を対応させました。',
      _MatchOutcome.needsReview =>
        '同じ問題の残りの選択肢は開きません。教材で条件を確認してから、もう一度対応づけられます。',
      _MatchOutcome.timeUp => '未回答の正解は表示しません。落ち着いて通常練習へ戻れます。',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScienceChallengeHeader(
          eyebrow: 'ラボ・ブリーフ  /  対応づけ実験  /  記録',
          title: title,
          body: body,
          icon: cleared
              ? Icons.check_circle_outline_rounded
              : Icons.pause_circle_outline_rounded,
          accent: cleared ? colors.pathComplete : colors.surfaceRaised,
          onAccent: cleared ? colors.onPathComplete : colors.ink,
          mascotReaction: switch (_outcome!) {
            _MatchOutcome.cleared => GameCharacterReaction.celebrate,
            _MatchOutcome.needsReview => GameCharacterReaction.retry,
            _MatchOutcome.timeUp => GameCharacterReaction.outOfTime,
          },
        ),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengeSurface(
          label: '学習記録への影響',
          icon: Icons.shield_outlined,
          child: const Text('この結果だけでは探究ノート・連続観測・報酬は変わりません。回答と残り時間も保存しません。'),
        ),
        if (cleared) ...[
          const SizedBox(height: GameTokens.spaceLg),
          ScienceChallengePrimaryButton(
            key: const ValueKey('match-complete'),
            label: '対応づけ実験を完了する',
            icon: Icons.check_rounded,
            onPressed: _completionCalled ? null : _complete,
            backgroundColor: colors.pathComplete,
            foregroundColor: colors.onPathComplete,
          ),
        ] else ...[
          const SizedBox(height: GameTokens.spaceLg),
          OutlinedButton.icon(
            key: const ValueKey('match-retry'),
            onPressed: _retryChecking ? null : () => unawaited(_retry()),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              foregroundColor: colors.ink,
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_retryChecking ? '試行余力を確認中…' : '最初からもう一度'),
          ),
        ],
        const SizedBox(height: GameTokens.spaceLg),
        const ScienceChallengePrivacyNote(),
      ],
    );
  }
}

bool _debugValidateMatchContent(ScienceMatchLabContent content) {
  final pairIds = content.pairs.map((pair) => pair.id).toSet();
  final targetIds = content.targets.map((target) => target.id).toSet();
  return content.pairs.length >= 2 &&
      content.targets.length >= 2 &&
      content.timeLimit > Duration.zero &&
      pairIds.length == content.pairs.length &&
      targetIds.length == content.targets.length &&
      content.pairs.every((pair) => pair.needCode.trim().isNotEmpty) &&
      content.pairs.every((pair) => targetIds.contains(pair.correctTargetId));
}
