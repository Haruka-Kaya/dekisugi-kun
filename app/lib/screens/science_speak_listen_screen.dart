import 'dart:async';

import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../models/game_path.dart';
import '../models/unit.dart';
import '../services/local_pronunciation_practice.dart';
import '../services/local_voice_practice.dart';
import '../ui/_material.dart';
import '../widgets/readable_width.dart';
import '../widgets/science_challenge_support.dart';

/// 教材を閉じたまま、声または文字で科学を説明し、自分で比較する画面。
///
/// 音声は16kHz PCMとしてRAMに最大60秒だけ保持し、端末外へ送らない。文字も
/// このStateのcontroller以外へ渡さない。どちらも自動採点せず、正本との比較後に
/// 本人が「残す／直す」を選んで初めて完了できる。
class ScienceSpeakListenScreen extends StatefulWidget {
  const ScienceSpeakListenScreen({
    super.key,
    required this.section,
    required this.conceptLabel,
    required this.practiceAttempt,
    required this.onCompleted,
    this.onReturnToPath,
    this.pronunciationPractice,
    this.voicePractice,
  });

  final Section section;
  final String conceptLabel;
  final int practiceAttempt;
  final VoidCallback onCompleted;
  final VoidCallback? onReturnToPath;

  /// テスト用の差し替え口。認識候補を画面へ公開しないservice単位で渡す。
  @visibleForTesting
  final LocalPronunciationPractice? pronunciationPractice;

  /// テスト用の差し替え口。渡した場合も画面が所有し、route終了時にdisposeする。
  @visibleForTesting
  final LocalVoicePractice? voicePractice;

  @override
  State<ScienceSpeakListenScreen> createState() =>
      _ScienceSpeakListenScreenState();
}

enum _ExplainStep { pronunciation, choose, voice, text, compare, complete }

enum _AnswerRoute { voice, text }

class _ScienceSpeakListenScreenState extends State<ScienceSpeakListenScreen> {
  final _text = TextEditingController();
  final _pronunciationText = TextEditingController();
  final _scroll = ScrollController();
  late final LocalVoicePractice _voice;
  LocalPronunciationPractice? _pronunciation;
  StreamSubscription<LocalVoicePracticeSnapshot>? _voiceSubscription;
  StreamSubscription<LocalPronunciationSnapshot>? _pronunciationSubscription;

  _ExplainStep _step = _ExplainStep.pronunciation;
  _AnswerRoute? _answerRoute;
  late LocalVoicePracticeSnapshot _voiceSnapshot;
  LocalPronunciationSnapshot _pronunciationSnapshot =
      const LocalPronunciationSnapshot(LocalPronunciationState.unavailable);
  String? _submittedText;
  String? _revisionBaseline;
  bool _pronunciationTextMode = false;
  bool _pronunciationVerifiedByVoice = false;
  bool _pronunciationStopBusy = false;
  bool _voicePlayed = false;
  bool _voiceBusy = false;
  bool _completionStarted = false;
  bool _returnStarted = false;

  LocalPracticeVariant get _variant =>
      widget.section.practiceVariantForAttempt(widget.practiceAttempt);

  @override
  void initState() {
    super.initState();
    _voice = widget.voicePractice ?? LocalVoicePractice();
    _voiceSnapshot = _voice.snapshot;
    _voiceSubscription = _voice.changes.listen((snapshot) {
      if (mounted) setState(() => _voiceSnapshot = snapshot);
    });
    final speaking = widget.section.localSpeakingPractice;
    if (speaking != null) {
      _pronunciation =
          widget.pronunciationPractice ??
          LocalPronunciationPractice(
            targetPhrase: speaking.targetPhrase,
            acceptedTranscripts: speaking.acceptedTranscripts,
          );
      _pronunciationSnapshot = _pronunciation!.snapshot;
      _pronunciationSubscription = _pronunciation!.changes.listen((snapshot) {
        if (mounted) setState(() => _pronunciationSnapshot = snapshot);
      });
    }
    _text.addListener(_onTextChanged);
    _pronunciationText.addListener(_onPronunciationTextChanged);
  }

  void _onTextChanged() {
    if (mounted && _step == _ExplainStep.text) setState(() {});
  }

  void _onPronunciationTextChanged() {
    if (mounted && _step == _ExplainStep.pronunciation) setState(() {});
  }

  @override
  void dispose() {
    _text.removeListener(_onTextChanged);
    _text.clear();
    _text.dispose();
    _pronunciationText.removeListener(_onPronunciationTextChanged);
    _pronunciationText.clear();
    _pronunciationText.dispose();
    _scroll.dispose();
    unawaited(_voiceSubscription?.cancel());
    unawaited(_pronunciationSubscription?.cancel());
    unawaited(_voice.dispose());
    unawaited(_pronunciation?.dispose());
    super.dispose();
  }

  bool get _canSubmitText {
    final answer = _text.text.trim();
    if (answer.isEmpty) return false;
    final baseline = _revisionBaseline;
    return baseline == null || answer != baseline;
  }

  bool get _typedTargetMatches =>
      _pronunciation?.matchesTypedTarget(_pronunciationText.text) ?? false;

  bool get _canSubmitVoice =>
      !_voiceBusy &&
      _voiceSnapshot.hasRecording &&
      _voiceSnapshot.state != LocalVoicePracticeState.recording &&
      _voicePlayed;

  void _startPronunciationRecognition() {
    final practice = _pronunciation;
    if (_step != _ExplainStep.pronunciation ||
        practice == null ||
        _pronunciationSnapshot.state == LocalPronunciationState.listening) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    _pronunciationText.clear();
    setState(() {
      _pronunciationTextMode = false;
      _pronunciationVerifiedByVoice = false;
    });
    unawaited(practice.start());
  }

  Future<void> _stopPronunciationRecognition() async {
    final practice = _pronunciation;
    if (_step != _ExplainStep.pronunciation ||
        practice == null ||
        _pronunciationSnapshot.state != LocalPronunciationState.listening ||
        _pronunciationStopBusy) {
      return;
    }
    setState(() => _pronunciationStopBusy = true);
    await practice.stop();
    if (mounted) setState(() => _pronunciationStopBusy = false);
  }

  Future<void> _usePronunciationText() async {
    if (_step != _ExplainStep.pronunciation || _pronunciation == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await _pronunciation!.cancelAttempt();
    if (!mounted) return;
    setState(() {
      _pronunciationTextMode = true;
      _pronunciationVerifiedByVoice = false;
    });
    _toTop();
  }

  void _continueAfterRecognizedPhrase() {
    if (_step != _ExplainStep.pronunciation ||
        _pronunciationSnapshot.state != LocalPronunciationState.matched) {
      return;
    }
    setState(() {
      _pronunciationVerifiedByVoice = true;
      _pronunciationTextMode = false;
      _step = _ExplainStep.choose;
    });
    _toTop();
  }

  void _continueAfterTypedPhrase() {
    if (_step != _ExplainStep.pronunciation || !_typedTargetMatches) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _pronunciationText.clear();
    setState(() {
      _pronunciationVerifiedByVoice = false;
      _pronunciationTextMode = false;
      _step = _ExplainStep.choose;
    });
    _toTop();
  }

  void _leaveUnavailableSpeaking() {
    if (_step != _ExplainStep.pronunciation || _returnStarted) return;
    _returnStarted = true;
    final callback = widget.onReturnToPath;
    if (callback != null) {
      callback();
    } else {
      Navigator.maybePop(context);
    }
  }

  Future<void> _chooseVoice() async {
    if (_step != _ExplainStep.choose && _step != _ExplainStep.text) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _text.clear();
    _submittedText = null;
    setState(() {
      _answerRoute = _AnswerRoute.voice;
      _step = _ExplainStep.voice;
      _voicePlayed = false;
      _revisionBaseline = null;
    });
    _toTop();
  }

  Future<void> _chooseText() async {
    if (_step != _ExplainStep.choose && _step != _ExplainStep.voice) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await _voice.clear();
    if (!mounted) return;
    setState(() {
      _answerRoute = _AnswerRoute.text;
      _step = _ExplainStep.text;
      _voicePlayed = false;
      _revisionBaseline = null;
    });
    _toTop();
  }

  Future<void> _startRecording() async {
    if (_step != _ExplainStep.voice || _voiceBusy) return;
    setState(() {
      _voiceBusy = true;
      _voicePlayed = false;
    });
    await _voice.startRecording();
    if (mounted) {
      setState(() {
        _voiceBusy = false;
        _voiceSnapshot = _voice.snapshot;
      });
    }
  }

  Future<void> _stopRecording() async {
    if (_step != _ExplainStep.voice || _voiceBusy) return;
    setState(() => _voiceBusy = true);
    await _voice.stopRecording();
    if (mounted) {
      setState(() {
        _voiceBusy = false;
        _voiceSnapshot = _voice.snapshot;
      });
    }
  }

  Future<void> _playRecording() async {
    final canPlay =
        _step == _ExplainStep.voice ||
        (_step == _ExplainStep.compare && _answerRoute == _AnswerRoute.voice);
    if (!canPlay || _voiceBusy) return;
    setState(() => _voiceBusy = true);
    final started = await _voice.playRecording();
    if (!mounted) return;
    setState(() {
      _voiceBusy = false;
      _voiceSnapshot = _voice.snapshot;
      if (started) _voicePlayed = true;
    });
  }

  Future<void> _recordAgain() async {
    if (_step != _ExplainStep.voice || _voiceBusy) return;
    setState(() => _voiceBusy = true);
    await _voice.clear();
    if (!mounted) return;
    setState(() {
      _voiceBusy = false;
      _voiceSnapshot = _voice.snapshot;
      _voicePlayed = false;
    });
    await _startRecording();
  }

  void _submitVoice() {
    if (_step != _ExplainStep.voice || !_canSubmitVoice) return;
    setState(() {
      _answerRoute = _AnswerRoute.voice;
      _step = _ExplainStep.compare;
      _revisionBaseline = null;
    });
    _toTop();
  }

  void _submitText() {
    if (_step != _ExplainStep.text || !_canSubmitText) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _submittedText = _text.text.trim();
      _answerRoute = _AnswerRoute.text;
      _step = _ExplainStep.compare;
      _revisionBaseline = null;
    });
    _toTop();
  }

  Future<void> _revise() async {
    if (_step != _ExplainStep.compare) return;
    if (_answerRoute == _AnswerRoute.voice) {
      await _voice.clear();
      if (!mounted) return;
      setState(() {
        _voicePlayed = false;
        _step = _ExplainStep.voice;
      });
    } else {
      setState(() {
        _revisionBaseline = _submittedText;
        _step = _ExplainStep.text;
      });
    }
    _toTop();
  }

  Future<void> _keepAndComplete() async {
    if (_step != _ExplainStep.compare || _completionStarted) return;
    _completionStarted = true;
    await _voice.clear();
    if (!mounted || _step != _ExplainStep.compare) return;
    _text.clear();
    _submittedText = null;
    _revisionBaseline = null;
    setState(() {
      _step = _ExplainStep.complete;
    });
    widget.onCompleted();
  }

  void _returnToPath() {
    if (_step != _ExplainStep.complete || _returnStarted) return;
    _returnStarted = true;
    final callback = widget.onReturnToPath;
    if (callback != null) {
      callback();
    } else {
      Navigator.maybePop(context);
    }
  }

  void _toTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              conceptLabel: widget.conceptLabel,
              stageLabel: _variant.stage.label,
              step: _step,
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('science-speak-listen-scroll'),
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: ReadableWidth(child: _body()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() => switch (_step) {
    _ExplainStep.pronunciation =>
      widget.section.localSpeakingPractice == null
          ? _MissingSpeakingTarget(onReturnToPath: _leaveUnavailableSpeaking)
          : _PronunciationGate(
              targetPhrase: widget.section.localSpeakingPractice!.targetPhrase,
              snapshot: _pronunciationSnapshot,
              textMode: _pronunciationTextMode,
              stopBusy: _pronunciationStopBusy,
              textController: _pronunciationText,
              typedTargetMatches: _typedTargetMatches,
              onStart: _startPronunciationRecognition,
              onStop: _stopPronunciationRecognition,
              onUseText: _usePronunciationText,
              onContinueVoice: _continueAfterRecognizedPhrase,
              onContinueText: _continueAfterTypedPhrase,
            ),
    _ExplainStep.choose => _ChooseRoute(
      prompts: _PromptSet.fromVariant(_variant),
      onVoice: _chooseVoice,
      onText: _chooseText,
    ),
    _ExplainStep.voice => _VoiceAnswer(
      prompts: _PromptSet.fromVariant(_variant),
      snapshot: _voiceSnapshot,
      busy: _voiceBusy,
      played: _voicePlayed,
      canSubmit: _canSubmitVoice,
      onStart: _startRecording,
      onStop: _stopRecording,
      onPlay: _playRecording,
      onRecordAgain: _recordAgain,
      onUseText: _chooseText,
      onSubmit: _submitVoice,
    ),
    _ExplainStep.text => _TextAnswer(
      prompts: _PromptSet.fromVariant(_variant),
      controller: _text,
      isRevision: _revisionBaseline != null,
      canSubmit: _canSubmitText,
      onUseVoice: _chooseVoice,
      onSubmit: _submitText,
    ),
    _ExplainStep.compare => _SelfComparison(
      route: _answerRoute!,
      submittedText: _submittedText,
      outcome: _variant.expectedOutcome,
      reason: _variant.expectedReason,
      onReplay: _answerRoute == _AnswerRoute.voice ? _playRecording : null,
      onRevise: _revise,
      onKeep: _keepAndComplete,
    ),
    _ExplainStep.complete => _Complete(
      pronunciationVerifiedByVoice: _pronunciationVerifiedByVoice,
      onReturnToPath: _returnToPath,
    ),
  };
}

class _PronunciationGate extends StatelessWidget {
  const _PronunciationGate({
    required this.targetPhrase,
    required this.snapshot,
    required this.textMode,
    required this.stopBusy,
    required this.textController,
    required this.typedTargetMatches,
    required this.onStart,
    required this.onStop,
    required this.onUseText,
    required this.onContinueVoice,
    required this.onContinueText,
  });

  final String targetPhrase;
  final LocalPronunciationSnapshot snapshot;
  final bool textMode;
  final bool stopBusy;
  final TextEditingController textController;
  final bool typedTargetMatches;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onUseText;
  final VoidCallback onContinueVoice;
  final VoidCallback onContinueText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    final listening = snapshot.state == LocalPronunciationState.listening;
    final matched = snapshot.state == LocalPronunciationState.matched;
    final voiceUnavailable = switch (snapshot.state) {
      LocalPronunciationState.permissionDenied ||
      LocalPronunciationState.unavailable => true,
      _ => false,
    };
    final statusText = switch (snapshot.state) {
      LocalPronunciationState.noSpeech =>
        '声を認識できませんでした。静かな場所で、目標語句を最初から話してください。',
      LocalPronunciationState.unrelatedSpeech =>
        '目標語句とは一致しませんでした。別の発話では完了になりません。',
      LocalPronunciationState.permissionDenied =>
        'マイクまたは音声認識の権限がありません。文字で確認できますが、発音確認にはなりません。',
      LocalPronunciationState.unavailable =>
        'この端末には日本語のオンデバイス音声認識がありません。クラウドへは送らず、文字で確認します。',
      LocalPronunciationState.failed =>
        '端末内の音声認識を完了できませんでした。達成にはせず、もう一度試すか文字で確認してください。',
      _ => null,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '目標語句を、声で確かめる',
          style: theme.textTheme.headlineSmall?.jaWeight(FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '端末内の音声認識が、この固定語句と完全に一致したときだけ声の確認を通過します。発音の点数づけはしません。',
          style: theme.textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: 16),
        Semantics(
          key: const ValueKey('science-speaking-target'),
          container: true,
          label: '目標語句。$targetPhrase',
          child: ExcludeSemantics(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surfaceRaised,
                borderRadius: BorderRadius.circular(GameTokens.radiusSheet),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '目標語句',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: colors.ink)
                        .jaWeight(FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    targetPhrase,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(color: colors.ink)
                        .jaWeight(FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (matched) ...[
          _Notice(text: '端末内認識が目標語句と一致しました。認識結果は保存しません。'),
          const SizedBox(height: 12),
          _Action(
            buttonKey: const ValueKey('science-speaking-continue-voice'),
            label: '声の確認を終えて、説明へ進む',
            icon: Icons.check_circle_outline,
            onPressed: onContinueVoice,
          ),
        ] else if (textMode) ...[
          Text(
            '文字で目標語句を確認する',
            style: theme.textTheme.titleSmall?.jaWeight(FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '目標語句を省略せず入力します。この経路は発音達成とは表示されません。',
            style: theme.textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('science-speaking-target-text'),
            controller: textController,
            maxLength: 120,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(hintText: '上の目標語句を、最初から最後まで入力する'),
          ),
          const SizedBox(height: 10),
          _Action(
            buttonKey: const ValueKey('science-speaking-continue-text'),
            label: typedTargetMatches ? '文字で確認して、説明へ進む' : '目標語句と同じ文を入力する',
            icon: Icons.keyboard_outlined,
            onPressed: typedTargetMatches ? onContinueText : null,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            key: const ValueKey('science-speaking-retry-voice'),
            onPressed: voiceUnavailable ? null : onStart,
            icon: const Icon(Icons.mic_none),
            label: const Text('声で確認する'),
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ] else ...[
          if (statusText != null) ...[
            _Notice(text: statusText),
            const SizedBox(height: 12),
          ],
          _Action(
            buttonKey: listening
                ? const ValueKey('science-speaking-stop-recognition')
                : const ValueKey('science-speaking-start-recognition'),
            label: listening
                ? '話し終えたら止める'
                : snapshot.state == LocalPronunciationState.idle
                ? '端末内で声を確認する'
                : 'もう一度、声を確認する',
            icon: listening ? Icons.stop : Icons.mic,
            onPressed: listening
                ? (stopBusy ? null : onStop)
                : (voiceUnavailable ? null : onStart),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            key: const ValueKey('science-speaking-use-text'),
            onPressed: onUseText,
            icon: const Icon(Icons.keyboard_outlined),
            label: const Text('マイクを使わず、文字で確認する'),
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ],
    );
  }
}

class _MissingSpeakingTarget extends StatelessWidget {
  const _MissingSpeakingTarget({required this.onReturnToPath});

  final VoidCallback onReturnToPath;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Speakingを開始できません',
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.jaWeight(FontWeight.w700),
      ),
      const SizedBox(height: 12),
      const _Notice(text: '教材カタログに固定の目標語句がありません。別の文を推測して達成にはしません。'),
      const SizedBox(height: 12),
      _Action(
        buttonKey: const ValueKey('science-speaking-missing-return'),
        label: '学習パスへ戻る',
        icon: Icons.route_outlined,
        onPressed: onReturnToPath,
      ),
    ],
  );
}

class _PromptSet {
  const _PromptSet({
    required this.recall,
    required this.reasoning,
    required this.transfer,
  });

  factory _PromptSet.fromVariant(LocalPracticeVariant variant) => _PromptSet(
    recall: variant.recallPrompt,
    reasoning: variant.reasoningPrompt,
    transfer: variant.transferPrompt,
  );

  final String recall;
  final String reasoning;
  final String transfer;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.conceptLabel,
    required this.stageLabel,
    required this.step,
  });

  final String conceptLabel;
  final String stageLabel;
  final _ExplainStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    final stepLabel = switch (step) {
      _ExplainStep.pronunciation => '目標語句を確認',
      _ExplainStep.choose => '説明方法を選ぶ',
      _ExplainStep.voice || _ExplainStep.text => '教材を隠して説明',
      _ExplainStep.compare => '教材と自己比較',
      _ExplainStep.complete => '比較完了',
    };
    final mascotReaction = switch (step) {
      _ExplainStep.pronunciation ||
      _ExplainStep.choose => GameCharacterReaction.invite,
      _ExplainStep.voice || _ExplainStep.text => GameCharacterReaction.thinking,
      _ExplainStep.compare => GameCharacterReaction.encourage,
      _ExplainStep.complete => GameCharacterReaction.celebrate,
    };
    return Semantics(
      container: true,
      label:
          'スピークとリッスン。$conceptLabel。$stageLabel。$stepLabel。'
          'デキすぎ君。${mascotReaction.semanticsLabel}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: ReadableWidth(
            tight: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox.square(
                  dimension: GameTokens.heroLeadingSize,
                  child: ScienceActivityMascotBadge(
                    icon: Icons.mic_rounded,
                    accent: context.gamePalette.pathReview,
                    onAccent: context.gamePalette.onPathReview,
                    mascotReaction: mascotReaction,
                  ),
                ),
                const SizedBox(height: GameTokens.spaceSm),
                Text(
                  'SPEAK & LISTEN  /  $stageLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: colors.pathReview)
                      .jaWeight(FontWeight.w700),
                ),
                const SizedBox(height: 7),
                Text(
                  conceptLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.jaWeight(FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  stepLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChooseRoute extends StatelessWidget {
  const _ChooseRoute({
    required this.prompts,
    required this.onVoice,
    required this.onText,
  });

  final _PromptSet prompts;
  final VoidCallback onVoice;
  final VoidCallback onText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '教材を閉じて、自分の説明をつくる',
          style: theme.textTheme.headlineSmall?.jaWeight(FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '声と文字は同じ課題です。声は端末内で自分が聞き返すためだけに使い、送信も採点もしません。',
          style: theme.textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: 18),
        _Prompts(prompts: prompts),
        const SizedBox(height: 20),
        _RouteButton(
          buttonKey: const ValueKey('science-explain-choose-voice'),
          icon: Icons.mic_none,
          title: '声で説明する',
          body: '最大60秒録音し、自分で再生してから比べる',
          onPressed: onVoice,
        ),
        const SizedBox(height: 10),
        _RouteButton(
          buttonKey: const ValueKey('science-explain-choose-text'),
          icon: Icons.keyboard_outlined,
          title: '文字で説明する',
          body: '同じ3つの問いに、ひとつの文章で答える',
          onPressed: onText,
        ),
      ],
    );
  }
}

class _VoiceAnswer extends StatelessWidget {
  const _VoiceAnswer({
    required this.prompts,
    required this.snapshot,
    required this.busy,
    required this.played,
    required this.canSubmit,
    required this.onStart,
    required this.onStop,
    required this.onPlay,
    required this.onRecordAgain,
    required this.onUseText,
    required this.onSubmit,
  });

  final _PromptSet prompts;
  final LocalVoicePracticeSnapshot snapshot;
  final bool busy;
  final bool played;
  final bool canSubmit;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onPlay;
  final VoidCallback onRecordAgain;
  final VoidCallback onUseText;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    final recording = snapshot.state == LocalVoicePracticeState.recording;
    final denied = snapshot.state == LocalVoicePracticeState.permissionDenied;
    final failed = snapshot.state == LocalVoicePracticeState.failed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HiddenMaterialNotice(),
        const SizedBox(height: 14),
        _Prompts(prompts: prompts),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.pathReview,
            borderRadius: BorderRadius.circular(GameTokens.radiusSheet),
          ),
          child: Column(
            children: [
              Icon(
                recording ? Icons.mic : Icons.graphic_eq,
                size: 42,
                color: colors.onPathReview,
              ),
              const SizedBox(height: 10),
              Text(
                recording
                    ? '録音中  ${_durationLabel(snapshot.duration)} / 1:00'
                    : snapshot.hasRecording
                    ? '${_durationLabel(snapshot.duration)} の説明をRAMに保持中'
                    : '最大60秒。録音後に必ず自分で聞き返します。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: colors.onPathReview)
                    .jaWeight(FontWeight.w700),
              ),
              const SizedBox(height: 14),
              if (recording)
                _Action(
                  buttonKey: const ValueKey('science-explain-stop-recording'),
                  label: '録音を止める',
                  icon: Icons.stop,
                  onPressed: busy ? null : onStop,
                  light: true,
                )
              else if (!snapshot.hasRecording)
                _Action(
                  buttonKey: const ValueKey('science-explain-start-recording'),
                  label: '録音を始める',
                  icon: Icons.mic,
                  onPressed: busy ? null : onStart,
                  light: true,
                )
              else ...[
                _Action(
                  buttonKey: const ValueKey('science-explain-play-recording'),
                  label: snapshot.state == LocalVoicePracticeState.playing
                      ? '再生中'
                      : played
                      ? 'もう一度聞く'
                      : '自分の説明を聞く',
                  icon: Icons.play_arrow,
                  onPressed: busy ? null : onPlay,
                  light: true,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  key: const ValueKey('science-explain-record-again'),
                  onPressed: busy ? null : onRecordAgain,
                  icon: Icon(Icons.refresh, color: colors.onPathReview),
                  label: Text(
                    '録り直す',
                    style: TextStyle(color: colors.onPathReview),
                  ),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (denied || failed) ...[
          const SizedBox(height: 12),
          _Notice(
            text: denied
                ? 'マイクを使えませんでした。権限を変えなくても、文字で同じ課題を最後まで進められます。'
                : '録音を続けられませんでした。音声は保存されていません。文字で同じ課題を続けられます。',
          ),
        ],
        const SizedBox(height: 14),
        _Action(
          buttonKey: const ValueKey('science-explain-submit-voice'),
          label: played ? 'この説明を教材と比べる' : '先に自分の説明を聞く',
          icon: Icons.compare_arrows,
          onPressed: canSubmit ? onSubmit : null,
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          key: const ValueKey('science-explain-use-text'),
          onPressed: onUseText,
          icon: const Icon(Icons.keyboard_outlined),
          label: const Text('文字で説明する'),
          style: TextButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ],
    );
  }
}

class _TextAnswer extends StatelessWidget {
  const _TextAnswer({
    required this.prompts,
    required this.controller,
    required this.isRevision,
    required this.canSubmit,
    required this.onUseVoice,
    required this.onSubmit,
  });

  final _PromptSet prompts;
  final TextEditingController controller;
  final bool isRevision;
  final bool canSubmit;
  final VoidCallback onUseVoice;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HiddenMaterialNotice(),
        const SizedBox(height: 14),
        _Prompts(prompts: prompts),
        const SizedBox(height: 16),
        Text(
          isRevision ? '教材と比べて、説明を直す' : '3つをつないで説明する',
          style: theme.textTheme.titleSmall?.jaWeight(FontWeight.w700),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('science-explain-text-input'),
          controller: controller,
          minLines: 5,
          maxLines: 10,
          maxLength: 4000,
          decoration: InputDecoration(
            hintText: '結論、理由・条件、別の場面の予想を、自分の言葉でつなげる',
            filled: true,
            fillColor: colors.surfaceRaised,
          ),
        ),
        const SizedBox(height: 12),
        _Action(
          buttonKey: const ValueKey('science-explain-submit-text'),
          label: 'この説明を教材と比べる',
          icon: Icons.compare_arrows,
          onPressed: canSubmit ? onSubmit : null,
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          key: const ValueKey('science-explain-use-voice'),
          onPressed: onUseVoice,
          icon: const Icon(Icons.mic_none),
          label: const Text('声で説明する'),
          style: TextButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ],
    );
  }
}

class _SelfComparison extends StatelessWidget {
  const _SelfComparison({
    required this.route,
    required this.submittedText,
    required this.outcome,
    required this.reason,
    required this.onReplay,
    required this.onRevise,
    required this.onKeep,
  });

  final _AnswerRoute route;
  final String? submittedText;
  final String outcome;
  final String reason;
  final VoidCallback? onReplay;
  final VoidCallback onRevise;
  final VoidCallback onKeep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    return Semantics(
      key: const ValueKey('science-explain-comparison'),
      container: true,
      label: '教材との自己比較。現象の結果。$outcome。理由と条件。$reason。説明を残すか直すか選びます。',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '自分の説明と、教材を比べる',
              style: theme.textTheme.headlineSmall?.jaWeight(FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'ここでは自動採点しません。足りない条件や理由があるかを、自分で決めます。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.inkMuted,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceRaised,
                borderRadius: BorderRadius.circular(GameTokens.radiusLg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '教材の観察',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: colors.ink)
                        .jaWeight(FontWeight.w700),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    outcome,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: colors.ink)
                        .jaWeight(FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '理由と条件',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: colors.ink)
                        .jaWeight(FontWeight.w700),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    reason,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.ink,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceRaised,
                borderRadius: BorderRadius.circular(GameTokens.radiusLg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '自分の説明',
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: colors.ink)
                        .jaWeight(FontWeight.w700),
                  ),
                  const SizedBox(height: 7),
                  if (route == _AnswerRoute.voice)
                    _Action(
                      buttonKey: const ValueKey(
                        'science-explain-replay-comparison',
                      ),
                      label: '録音をもう一度聞く',
                      icon: Icons.play_arrow,
                      onPressed: onReplay,
                      light: true,
                    )
                  else
                    Text(
                      submittedText ?? '',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.ink,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _Action(
              buttonKey: const ValueKey('science-explain-keep'),
              label: 'この説明を残して終える',
              icon: Icons.check,
              onPressed: onKeep,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('science-explain-revise'),
              onPressed: onRevise,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('説明を直して、もう一度比べる'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Complete extends StatelessWidget {
  const _Complete({
    required this.pronunciationVerifiedByVoice,
    required this.onReturnToPath,
  });

  final bool pronunciationVerifiedByVoice;
  final VoidCallback onReturnToPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    return Column(
      children: [
        Semantics(
          key: const ValueKey('science-explain-finished'),
          container: true,
          label: pronunciationVerifiedByVoice
              ? '自己比較完了。目標語句を端末内の声認識で確認し、説明を教材の観察と理由まで比べました。'
              : '自己比較完了。目標語句を文字で確認し、説明を教材の観察と理由まで比べました。発音は確認していません。',
          child: ExcludeSemantics(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 24),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 26),
              decoration: BoxDecoration(
                color: colors.surfaceRaised,
                borderRadius: BorderRadius.circular(GameTokens.radiusSheet),
              ),
              child: Column(
                children: [
                  Icon(Icons.hearing_outlined, size: 40, color: colors.ink),
                  const SizedBox(height: 12),
                  Text(
                    '自己比較まで完了',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(color: colors.ink)
                        .jaWeight(FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pronunciationVerifiedByVoice
                        ? '目標語句は端末内で声を確認済みです。回答・認識結果は保存せず、音声もRAMから破棄しました。'
                        : '目標語句は文字で確認しました。発音は未確認です。回答と音声は保存していません。',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('science-explain-return-to-path'),
          onPressed: onReturnToPath,
          icon: const Icon(Icons.route_outlined),
          label: const Text('学習パスへ戻る'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
          ),
        ),
      ],
    );
  }
}

class _Prompts extends StatelessWidget {
  const _Prompts({required this.prompts});

  final _PromptSet prompts;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Prompt(number: 1, label: '思い出す', text: prompts.recall),
        const SizedBox(height: 8),
        _Prompt(number: 2, label: '理由・条件', text: prompts.reasoning),
        const SizedBox(height: 8),
        _Prompt(number: 3, label: '別の場面', text: prompts.transfer),
      ],
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt({
    required this.number,
    required this.label,
    required this.text,
  });

  final int number;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(GameTokens.radiusMd),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.pathReview,
              borderRadius: BorderRadius.circular(GameTokens.radiusSm),
            ),
            child: Text(
              '$number',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: colors.onPathReview)
                  .jaWeight(FontWeight.w700),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: colors.pathReview)
                      .jaWeight(FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(text, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HiddenMaterialNotice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(GameTokens.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.visibility_off_outlined, color: colors.ink),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '教材は隠れています。答えを見ずに、自分の言葉で説明します。',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colors.ink)
                  .jaWeight(FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteButton extends StatelessWidget {
  const _RouteButton({
    required this.buttonKey,
    required this.icon,
    required this.title,
    required this.body,
    required this.onPressed,
  });

  final Key buttonKey;
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    return OutlinedButton(
      key: buttonKey,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 68),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GameTokens.radiusMd),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 25),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.buttonKey,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.light = false,
  });

  final Key buttonKey;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return FilledButton.icon(
      key: buttonKey,
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        backgroundColor: light ? colors.onPathReview : null,
        foregroundColor: light ? colors.pathReview : null,
        disabledBackgroundColor: light
            ? colors.onPathReview.withValues(alpha: 0.38)
            : null,
        disabledForegroundColor: light
            ? colors.pathReview.withValues(alpha: 0.68)
            : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GameTokens.radiusMd),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(GameTokens.radiusMd),
        ),
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(color: colors.ink),
        ),
      ),
    );
  }
}

String _durationLabel(Duration duration) {
  final seconds = duration.inSeconds.clamp(0, 60);
  return '0:${seconds.toString().padLeft(2, '0')}';
}
