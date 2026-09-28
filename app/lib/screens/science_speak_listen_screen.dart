import 'dart:async';

import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../learning/domain/explanation_coverage.dart';
import '../learning/domain/learning_heart.dart';
import '../learning/domain/learning_need.dart';
import '../learning/services/local_companion_voice.dart';
import '../models/game_path.dart';
import '../models/unit.dart';
import '../services/device_identity.dart';
import '../services/local_narration.dart';
import '../services/local_pronunciation_practice.dart';
import '../services/local_voice_practice.dart';
import '../services/remote_companion_engine.dart';
import '../ui/_material.dart';
import 'package:provider/provider.dart';
import '../widgets/game_activity_scaffold.dart';
import '../widgets/learning_path.dart';
import '../widgets/readable_width.dart';

/// 教材を閉じ、生徒がデキすぎ君へ教えてから固定の問い返しに答える画面。
///
/// 自由発話・自由記述の正誤は採点しない。説明が進むには、その概念の
/// 「大事な言葉」をデキすぎ君が聞き取れることが条件 —— 無関係な文では
/// 「もう少し聞かせて」と返す。語彙の聞き取りと誤概念の確認は端末内だけで
/// 行う。返事の前置きの生成（外部AI、同意文面の「生成AIサービス」項）が
/// 有効なビルドでは、文字で書いた説明がサーバ経由で生成AIへ送られる —
/// 送るのは説明文と聞き取れた言葉と単元名だけで、lure・正解・選択肢は
/// 送らない。音声は16kHz PCMとしてRAMに最大60秒だけ保持し、
/// 文字、選択内容、認識候補とともに保存しない。完了callbackへ渡すのは一般化
/// needと固定課題位置だけで、回答そのものは含めない。
class ScienceSpeakListenScreen extends StatefulWidget {
  const ScienceSpeakListenScreen({
    super.key,
    required this.section,
    required this.conceptLabel,
    required this.practiceAttempt,
    required this.onCompleted,
    this.onReturnToPath,
    this.onNeedEvidence,
    this.onHeartLoss,
    this.narration,
    this.voicePractice,
    this.speechRecognizer,
    this.companionVoice,
  });

  final Section section;
  final String conceptLabel;
  final int practiceAttempt;

  /// 回答を渡さず、固定問い返しの構造成功・誤答needだけを通知する。
  final LearningNeedEvidenceReported? onNeedEvidence;

  /// 誤答した固定課題位置だけを通知する。選択肢IDは渡さない。
  final LearningHeartLossReported? onHeartLoss;

  /// 回答をRAMから破棄し、比較完了画面へ移ったあと一度だけ呼ぶ。
  final VoidCallback onCompleted;

  final VoidCallback? onReturnToPath;

  /// テスト用の差し替え口。画面に表示済みの固定質問だけを渡す。
  @visibleForTesting
  final LocalNarration? narration;

  /// テスト用の差し替え口。渡した場合も画面が所有し、route終了時にdisposeする。
  @visibleForTesting
  final LocalVoicePractice? voicePractice;

  /// 声の説明の「聞き取り確認」に使うオンデバイス認識。テスト用の差し替え口。
  @visibleForTesting
  final OnDeviceSpeechRecognizer? speechRecognizer;

  /// 返事の前置きを生成する経路。null なら環境の既定を解決する
  /// （外部AIが無効なら固定文へ退避）。テスト用の差し替え口。
  @visibleForTesting
  final CompanionVoice? companionVoice;

  @override
  State<ScienceSpeakListenScreen> createState() =>
      _ScienceSpeakListenScreenState();
}

enum _ExplainStep { choose, voice, text, echo, followUp, compare, complete }

enum _AnswerRoute { voice, text }

/// 聞き取り確認の入力方法。声が使えない端末では文字で同じことをする。
enum _EchoInput { voice, text }

enum _EchoPhase { listening, idle, heard }

class _ScienceSpeakListenScreenState extends State<ScienceSpeakListenScreen>
    with WidgetsBindingObserver {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  late final LocalVoicePractice _voice;
  late final LocalNarration _narration;
  StreamSubscription<LocalVoicePracticeSnapshot>? _voiceSubscription;

  _ExplainStep _step = _ExplainStep.choose;
  _AnswerRoute? _answerRoute;
  late LocalVoicePracticeSnapshot _voiceSnapshot;
  String? _submittedText;
  String? _revisionBaseline;
  String? _selectedOptionId;
  String? _wrongOptionId;
  bool _isRevision = false;
  bool _textReviewed = false;
  bool _voiceBusy = false;
  bool _questionSpeaking = false;
  bool _questionUnavailable = false;
  bool _needEvidenceReported = false;
  bool _heartLossReported = false;
  bool _hadWrongAnswer = false;
  bool _completionStarted = false;
  bool _returnStarted = false;
  int _narrationEpoch = 0;

  late final OnDeviceSpeechRecognizer _speechRecognizer;
  final _echoText = TextEditingController();
  _EchoInput _echoInput = _EchoInput.voice;
  _EchoPhase _echoPhase = _EchoPhase.idle;
  ExplanationCoverage? _echoCoverage;
  bool _echoMissed = false;
  int _teachMisses = 0;
  bool _coverageBlocked = false;
  late final CompanionVoice _companionVoice;
  String? _generatedAck;
  Future<String?>? _pendingAck;

  LocalPracticeVariant get _variant =>
      widget.section.practiceVariantForAttempt(widget.practiceAttempt);

  LocalCheckpoint get _checkpoint => _variant.checkpoint;

  /// 説明の聞き取りに使う正本。比較まで画面に出ない教材の答えだけを使い、
  /// legacy fallback（汎用文）では語彙を取らない —— 判定不能なら塞がない。
  List<String> get _coverageSources =>
      widget.section.localPracticeVariants.isEmpty
      ? const []
      : [_variant.expectedOutcome, _variant.expectedReason];

  ExplanationCoverage _assess(String explanation) =>
      assessExplanation(explanation, sources: _coverageSources);

  /// 問い返しの文面。生成AIの前置きが届いていれば先頭に置くが、
  /// lureと問いは**必ずカタログの逐語** —— 教理は生成に委ねない。
  String get _spokenQuestion {
    final ack = _generatedAck;
    final prefix =
        ack != null ? '$ack ' : '教えてくれてありがとう。デキすぎ君から一問。';
    return '$prefix${_checkpoint.lure} この考えを科学的に直しているのはどれ？';
  }

  LocalCheckpointOption? get _wrongOption =>
      _wrongOptionId == null ? null : _checkpoint.optionFor(_wrongOptionId!);

  bool get _voicePlaying =>
      _voiceSnapshot.state == LocalVoicePracticeState.playing;

  bool get _canAdvanceVoice =>
      !_voiceBusy &&
      _voiceSnapshot.state == LocalVoicePracticeState.recorded &&
      _voiceSnapshot.hasRecording &&
      _voiceSnapshot.playbackCompleted;

  bool get _voiceRevisionFallbackAllowed =>
      _isRevision &&
      (_voiceSnapshot.state == LocalVoicePracticeState.permissionDenied ||
          _voiceSnapshot.state == LocalVoicePracticeState.failed);

  bool get _canReviewText {
    final answer = _text.text.trim();
    if (answer.isEmpty) return false;
    final baseline = _revisionBaseline;
    return baseline == null || answer != baseline;
  }

  GameCharacterReaction get _characterReaction {
    if (_questionSpeaking) return GameCharacterReaction.speaking;
    if (_voiceSnapshot.state == LocalVoicePracticeState.recording ||
        _voiceSnapshot.state == LocalVoicePracticeState.playing) {
      return GameCharacterReaction.listening;
    }
    return switch (_step) {
      _ExplainStep.choose => GameCharacterReaction.invite,
      _ExplainStep.voice || _ExplainStep.text =>
        _isRevision
            ? GameCharacterReaction.encourage
            : GameCharacterReaction.listening,
      _ExplainStep.echo => _echoPhase == _EchoPhase.listening
          ? GameCharacterReaction.listening
          : GameCharacterReaction.thinking,
      _ExplainStep.followUp => GameCharacterReaction.thinking,
      _ExplainStep.compare => GameCharacterReaction.encourage,
      _ExplainStep.complete => GameCharacterReaction.celebrate,
    };
  }

  @override
  void initState() {
    super.initState();
    _voice = widget.voicePractice ?? LocalVoicePractice();
    _narration = widget.narration ?? PlatformLocalNarration();
    _speechRecognizer =
        widget.speechRecognizer ?? PlatformOnDeviceSpeechRecognizer();
    _companionVoice = _resolveCompanionVoice();
    _voiceSnapshot = _voice.snapshot;
    _voiceSubscription = _voice.changes.listen((snapshot) {
      if (mounted) setState(() => _voiceSnapshot = snapshot);
    });
    _text.addListener(_onTextChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  /// 返事の前置きの生成経路。注入があればそれを使い、なければ
  /// DeviceIdentity（無くても動く → 401 で黙って退避）を拾って環境既定へ。
  CompanionVoice _resolveCompanionVoice() {
    final injected = widget.companionVoice;
    if (injected != null) return injected;
    DeviceIdentity? identity;
    try {
      identity = context.read<DeviceIdentity>();
    } catch (_) {}
    return companionVoiceFromEnvironment(identity: identity);
  }

  void _onTextChanged() {
    if (!mounted || _step != _ExplainStep.text) return;
    setState(() {
      _textReviewed = false;
      _coverageBlocked = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) return;
    unawaited(_suspendAudio());
  }

  Future<void> _suspendAudio() async {
    await _stopQuestionNarration();
    if (_voice.snapshot.state == LocalVoicePracticeState.recording) {
      await _voice.stopRecording();
    }
    await _voice.stopPlayback();
    if (mounted) setState(() => _voiceSnapshot = _voice.snapshot);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _narrationEpoch++;
    _text.removeListener(_onTextChanged);
    _text.clear();
    _text.dispose();
    _echoText.dispose();
    _scroll.dispose();
    final voiceSubscription = _voiceSubscription;
    _voiceSubscription = null;
    // State.disposeはFutureを返せない。所有resourceの各cleanupを独立に試し、
    // どれかが同期・非同期例外になってもunhandled Futureと後続skipを作らない。
    unawaited(_disposeOwnedAudio(voiceSubscription));
    super.dispose();
  }

  Future<void> _disposeOwnedAudio(
    StreamSubscription<LocalVoicePracticeSnapshot>? voiceSubscription,
  ) async {
    Future<void> ignoreFailure(Future<void> Function() cleanup) async {
      try {
        await cleanup();
      } catch (_) {
        // routeは既に破棄済み。例外をUIへ戻さず、残りのcleanupを続ける。
      }
    }

    // cancellationが端末都合で止まっても、native音声のdisposeを待たせない。
    final cleanups = <Future<void>>[
      ignoreFailure(_narration.dispose),
      ignoreFailure(_voice.dispose),
      ignoreFailure(_speechRecognizer.cancel),
    ];
    if (voiceSubscription != null) {
      cleanups.add(ignoreFailure(voiceSubscription.cancel));
    }
    await Future.wait(cleanups);
  }

  Future<void> _chooseVoice() async {
    final canSwitch =
        _step == _ExplainStep.choose ||
        (_step == _ExplainStep.text && !_isRevision);
    if (!canSwitch) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _text.clear();
    _submittedText = null;
    setState(() {
      _answerRoute = _AnswerRoute.voice;
      _step = _ExplainStep.voice;
      _isRevision = false;
      _revisionBaseline = null;
      _textReviewed = false;
    });
    _toTop();
  }

  Future<void> _chooseText() async {
    final revisionFallback =
        _step == _ExplainStep.voice && _voiceRevisionFallbackAllowed;
    final canSwitch =
        _step == _ExplainStep.choose ||
        (_step == _ExplainStep.voice && (!_isRevision || revisionFallback));
    if (!canSwitch) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await _voice.clear();
    if (!mounted) return;
    setState(() {
      _voiceSnapshot = _voice.snapshot;
      _answerRoute = _AnswerRoute.text;
      _step = _ExplainStep.text;
      _isRevision = revisionFallback;
      _revisionBaseline = null;
      _textReviewed = false;
      _coverageBlocked = false;
      _teachMisses = 0;
    });
    _toTop();
  }

  Future<void> _startRecording() async {
    if (_step != _ExplainStep.voice || _voiceBusy || _voicePlaying) return;
    await _stopQuestionNarration();
    if (!mounted || _step != _ExplainStep.voice) return;
    setState(() => _voiceBusy = true);
    try {
      await _voice.startRecording();
    } finally {
      if (mounted) {
        setState(() {
          _voiceBusy = false;
          _voiceSnapshot = _voice.snapshot;
        });
      }
    }
  }

  Future<void> _stopRecording() async {
    if (_step != _ExplainStep.voice || _voiceBusy) return;
    setState(() => _voiceBusy = true);
    try {
      await _voice.stopRecording();
    } finally {
      if (mounted) {
        setState(() {
          _voiceBusy = false;
          _voiceSnapshot = _voice.snapshot;
        });
      }
    }
  }

  Future<void> _playRecording() async {
    final canPlay =
        _step == _ExplainStep.voice ||
        (_step == _ExplainStep.compare && _answerRoute == _AnswerRoute.voice);
    if (!canPlay || _voiceBusy || _voicePlaying) return;
    await _stopQuestionNarration();
    if (!mounted) return;
    setState(() => _voiceBusy = true);
    try {
      await _voice.playRecording();
    } finally {
      if (mounted) {
        setState(() {
          _voiceBusy = false;
          _voiceSnapshot = _voice.snapshot;
        });
      }
    }
  }

  Future<void> _recordAgain() async {
    if (_step != _ExplainStep.voice || _voiceBusy) return;
    setState(() => _voiceBusy = true);
    try {
      await _voice.clear();
    } finally {
      if (mounted) {
        setState(() {
          _voiceBusy = false;
          _voiceSnapshot = _voice.snapshot;
        });
      }
    }
    if (!mounted || _step != _ExplainStep.voice) return;
    await _startRecording();
  }

  Future<void> _advanceVoice() async {
    if (_step != _ExplainStep.voice || !_canAdvanceVoice) return;
    await _voice.stopPlayback();
    if (!mounted || _step != _ExplainStep.voice || !_canAdvanceVoice) return;
    _answerRoute = _AnswerRoute.voice;
    _startEcho();
  }

  /// 声の説明は録音を文字起こししない。代わりに、大事な言葉を
  /// もう一度だけ言ってもらい、オンデバイス認識で聞き取れたか確かめる。
  /// 認識を使えない端末では文字で同じことを確かめる（C8）。
  void _startEcho() {
    setState(() {
      _step = _ExplainStep.echo;
      _echoInput = _EchoInput.voice;
      _echoPhase = _EchoPhase.listening;
      _echoCoverage = null;
      _echoMissed = false;
      _echoText.clear();
    });
    _toTop();
    unawaited(_runEchoRecognition());
  }

  Future<void> _runEchoRecognition() async {
    final result = await _speechRecognizer.recognize();
    if (!mounted || _step != _ExplainStep.echo) return;
    switch (result.status) {
      case OnDeviceSpeechStatus.recognized:
        _applyEchoCoverage(_assess(result.candidates.join(' ')));
      case OnDeviceSpeechStatus.noSpeech ||
            OnDeviceSpeechStatus.unrelatedSpeech:
        setState(() {
          _teachMisses++;
          _echoPhase = _EchoPhase.idle;
          _echoMissed = true;
          _echoCoverage = null;
        });
      default:
        // unavailable / permissionDenied / failed / cancelled —
        // 文字で同じ確認をする。塞がない。
        setState(() {
          _echoInput = _EchoInput.text;
          _echoPhase = _EchoPhase.idle;
        });
    }
  }

  void _applyEchoCoverage(ExplanationCoverage coverage) {
    setState(() {
      _echoCoverage = coverage;
      if (coverage.isSufficient) {
        _echoPhase = _EchoPhase.heard;
      } else {
        _teachMisses++;
        _echoPhase = _EchoPhase.idle;
        _echoMissed = true;
      }
    });
  }

  void _submitEchoText() {
    if (_step != _ExplainStep.echo || _echoInput != _EchoInput.text) return;
    _applyEchoCoverage(_assess(_echoText.text));
  }

  void _useEchoText() {
    if (_step != _ExplainStep.echo) return;
    setState(() {
      _echoInput = _EchoInput.text;
      _echoPhase = _EchoPhase.idle;
      _echoMissed = false;
      _echoCoverage = null;
    });
  }

  /// 何度も届かない説明で生徒を閉じ込めない。2回届かなかったら
  /// 「このまま進む」を開き、確かめは固定の問い返しへ委ねる。
  void _advanceBypassingCoverage() {
    if (_teachMisses < 2) return;
    _advanceAfterTeaching();
  }

  void _reviewText() {
    if (_step != _ExplainStep.text || !_canReviewText) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _textReviewed = true);
  }

  void _advanceText() {
    if (_step != _ExplainStep.text || !_canReviewText || !_textReviewed) {
      return;
    }
    final coverage = _assess(_text.text);
    if (!coverage.isSufficient) {
      // 採点ではなく聞き取り —— 大事な言葉が届かなければ
      // デキすぎ君が「もう少し聞かせて」と返す。答えは教えない。
      setState(() {
        _teachMisses++;
        _coverageBlocked = true;
      });
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    _submittedText = _text.text.trim();
    _answerRoute = _AnswerRoute.text;
    _advanceAfterTeaching();
  }

  void _advanceAfterTeaching() {
    if (_isRevision) {
      setState(() {
        _step = _ExplainStep.compare;
        _isRevision = false;
        _revisionBaseline = null;
        _textReviewed = false;
      });
      _toTop();
      return;
    }

    setState(() {
      _step = _ExplainStep.followUp;
      _selectedOptionId = null;
      _wrongOptionId = null;
      _questionUnavailable = false;
    });
    _toTop();
    _requestCompanionAck();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _step == _ExplainStep.followUp) {
        unawaited(_speakQuestion());
      }
    });
  }

  /// 生徒の説明を外部AIに送り、返事の前置きを生成してもらう。
  /// 説明の文字が無い経路（声のみ）では送らない。結果は届き次第
  /// 表示へ反映するが、問い自体はカタログのままなので遅れても壊れない。
  void _requestCompanionAck() {
    final explanation = _submittedText ?? _echoText.text.trim();
    if (explanation.isEmpty) return;
    final heardTerms = _echoCoverage?.matchedTerms ??
        _assess(explanation).matchedTerms;
    final future = _companionVoice.renderAck(
      explanation: explanation,
      heardTerms: heardTerms,
      conceptLabel: widget.conceptLabel,
      lure: _checkpoint.lure,
    );
    _pendingAck = future;
    future.then((ack) {
      if (!mounted || ack == null || _step != _ExplainStep.followUp) {
        return;
      }
      setState(() => _generatedAck = ack);
    });
  }

  Future<void> _speakQuestion() async {
    if (_step != _ExplainStep.followUp || _questionSpeaking) return;
    final epoch = ++_narrationEpoch;
    setState(() {
      _questionSpeaking = true;
      _questionUnavailable = false;
    });
    // 生成中の前置きがあれば短い猶予で待つ —— 読み上げに乗る方が
    // 「AIが説明を読んだ」実感が伝わる。来なければ固定文で読む。
    final pending = _pendingAck;
    if (pending != null) {
      try {
        await pending.timeout(const Duration(seconds: 3));
      } catch (_) {}
      if (!mounted || epoch != _narrationEpoch) return;
    }
    final completed = await _narration.speak(_spokenQuestion);
    if (!mounted || epoch != _narrationEpoch) return;
    setState(() {
      _questionSpeaking = false;
      _questionUnavailable = !completed;
    });
  }

  Future<void> _stopQuestionNarration() async {
    _narrationEpoch++;
    if (mounted && _questionSpeaking) {
      setState(() => _questionSpeaking = false);
    }
    await _narration.stop();
  }

  void _selectFollowUpOption(String optionId) {
    if (_step != _ExplainStep.followUp ||
        _questionSpeaking ||
        _wrongOptionId != null ||
        _checkpoint.optionFor(optionId) == null) {
      return;
    }
    setState(() => _selectedOptionId = optionId);
  }

  void _submitFollowUp() {
    if (_step != _ExplainStep.followUp ||
        _questionSpeaking ||
        _wrongOptionId != null ||
        _selectedOptionId == null) {
      return;
    }
    final selected = _checkpoint.optionFor(_selectedOptionId!);
    if (selected == null) return;
    final correct = selected.id == _checkpoint.correctOptionId;
    _reportNeed(
      selected,
      correct
          ? LearningNeedEvidenceKind.demonstrated
          : LearningNeedEvidenceKind.observed,
    );

    if (correct) {
      unawaited(_stopQuestionNarration());
      setState(() => _step = _ExplainStep.compare);
      _toTop();
      return;
    }

    _reportHeartLoss();
    setState(() {
      _hadWrongAnswer = true;
      _wrongOptionId = selected.id;
    });
    _toTop();
  }

  void _reportNeed(
    LocalCheckpointOption option,
    LearningNeedEvidenceKind kind,
  ) {
    final generalizedCode =
        option.needCode ??
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

  void _reportHeartLoss() {
    if (_heartLossReported) return;
    _heartLossReported = true;
    widget.onHeartLoss?.call(
      LearningHeartLossEvidence(
        fixedTaskId: 'speaking:${widget.practiceAttempt}:follow-up',
      ),
    );
  }

  Future<void> _beginRequiredRevision() async {
    if (_step != _ExplainStep.followUp || _wrongOption == null) return;
    await _stopQuestionNarration();
    if (!mounted) return;
    await _openRevision();
  }

  Future<void> _reviseFromComparison() async {
    if (_step != _ExplainStep.compare || _voicePlaying) return;
    await _openRevision();
  }

  Future<void> _openRevision() async {
    final route = _answerRoute;
    if (route == null) return;
    if (route == _AnswerRoute.voice) {
      await _voice.clear();
      if (!mounted) return;
      setState(() {
        _voiceSnapshot = _voice.snapshot;
        _step = _ExplainStep.voice;
        _isRevision = true;
        _revisionBaseline = null;
      });
    } else {
      final baseline = _submittedText ?? _text.text.trim();
      _text.text = baseline;
      _text.selection = TextSelection.collapsed(offset: _text.text.length);
      setState(() {
        _step = _ExplainStep.text;
        _isRevision = true;
        _revisionBaseline = baseline;
        _textReviewed = false;
      });
    }
    _toTop();
  }

  Future<void> _keepAndComplete() async {
    if (_step != _ExplainStep.compare || _completionStarted || _voicePlaying) {
      return;
    }
    _completionStarted = true;
    await _stopQuestionNarration();
    await _voice.clear();
    if (!mounted || _step != _ExplainStep.compare) return;
    _text.clear();
    _submittedText = null;
    _revisionBaseline = null;
    _selectedOptionId = null;
    _wrongOptionId = null;
    setState(() {
      _voiceSnapshot = _voice.snapshot;
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
              reaction: _characterReaction,
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
    _ExplainStep.choose => _ChooseRoute(
      prompt: _TeachingPrompt.fromVariant(_variant),
      onVoice: _chooseVoice,
      onText: _chooseText,
    ),
    _ExplainStep.voice => _VoiceAnswer(
      prompt: _TeachingPrompt.fromVariant(_variant),
      snapshot: _voiceSnapshot,
      busy: _voiceBusy,
      isRevision: _isRevision,
      revisionHint: _wrongOption?.hint,
      canAdvance: _canAdvanceVoice,
      allowRouteSwitch: !_isRevision || _voiceRevisionFallbackAllowed,
      routeSwitchIsFallback: _voiceRevisionFallbackAllowed,
      onStart: _startRecording,
      onStop: _stopRecording,
      onPlay: _playRecording,
      onRecordAgain: _recordAgain,
      onUseText: _chooseText,
      onAdvance: _advanceVoice,
    ),
    _ExplainStep.text => _TextAnswer(
      prompt: _TeachingPrompt.fromVariant(_variant),
      controller: _text,
      isRevision: _isRevision,
      revisionHint: _wrongOption?.hint,
      canReview: _canReviewText,
      reviewed: _textReviewed,
      allowRouteSwitch: !_isRevision,
      coverage: _textReviewed || _coverageBlocked
          ? _assess(_text.text)
          : null,
      coverageBlocked: _coverageBlocked,
      canBypass: _teachMisses >= 2,
      onReview: _reviewText,
      onUseVoice: _chooseVoice,
      onAdvance: _advanceText,
      onBypass: _advanceBypassingCoverage,
    ),
    _ExplainStep.echo => _EchoCheck(
      conceptLabel: widget.conceptLabel,
      isRevision: _isRevision,
      input: _echoInput,
      phase: _echoPhase,
      coverage: _echoCoverage,
      missed: _echoMissed,
      canBypass: _teachMisses >= 2,
      controller: _echoText,
      onRetryVoice: _startEcho,
      onUseText: _useEchoText,
      onSubmitText: _submitEchoText,
      onAdvance: _advanceAfterTeaching,
      onBypass: _advanceBypassingCoverage,
    ),
    _ExplainStep.followUp => _FollowUp(
      spokenQuestion: _spokenQuestion,
      aiComposedAck: _generatedAck != null,
      checkpoint: _checkpoint,
      selectedOptionId: _selectedOptionId,
      wrongOption: _wrongOption,
      speaking: _questionSpeaking,
      narrationUnavailable: _questionUnavailable,
      reaction: _characterReaction,
      onReadQuestion: _speakQuestion,
      onStopQuestion: _stopQuestionNarration,
      onSelect: _selectFollowUpOption,
      onSubmit: _submitFollowUp,
      onRevise: _beginRequiredRevision,
    ),
    _ExplainStep.compare => _SelfComparison(
      route: _answerRoute!,
      submittedText: _submittedText,
      outcome: _variant.expectedOutcome,
      reason: _variant.expectedReason,
      checkpointCorrection:
          _checkpoint.optionFor(_checkpoint.correctOptionId)?.text ?? '',
      checkpointExplanation: _checkpoint.explanation,
      revisedAfterHint: _hadWrongAnswer,
      voicePlaying: _voicePlaying,
      onReplay: _answerRoute == _AnswerRoute.voice ? _playRecording : null,
      onRevise: _reviseFromComparison,
      onKeep: _keepAndComplete,
    ),
    _ExplainStep.complete => _Complete(
      usedVoice: _answerRoute == _AnswerRoute.voice,
      revisedAfterHint: _hadWrongAnswer,
      onReturnToPath: _returnToPath,
    ),
  };
}

class _TeachingPrompt {
  const _TeachingPrompt({required this.label, required this.text});

  factory _TeachingPrompt.fromVariant(LocalPracticeVariant variant) =>
      switch (variant.stage) {
        LocalPracticeStage.foundation => _TeachingPrompt(
          label: '原理を思い出す',
          text: variant.recallPrompt,
        ),
        LocalPracticeStage.conditions => _TeachingPrompt(
          label: '理由と条件を説明する',
          text: variant.reasoningPrompt,
        ),
        LocalPracticeStage.transfer => _TeachingPrompt(
          label: '別の場面へ使う',
          text: variant.transferPrompt,
        ),
      };

  final String label;
  final String text;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.conceptLabel,
    required this.stageLabel,
    required this.step,
    required this.reaction,
  });

  final String conceptLabel;
  final String stageLabel;
  final _ExplainStep step;
  final GameCharacterReaction reaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    final stepLabel = switch (step) {
      _ExplainStep.choose => '教え方を選ぶ',
      _ExplainStep.voice || _ExplainStep.text => '教材を隠して教える',
      _ExplainStep.echo => '聞き取れたか確かめる',
      _ExplainStep.followUp => 'デキすぎ君の問い返し',
      _ExplainStep.compare => '教材と振り返る',
      _ExplainStep.complete => '教え返し完了',
    };
    return Semantics(
      container: true,
      label:
          'ティーチバック。$conceptLabel。$stageLabel。$stepLabel。'
          'デキすぎ君。${reaction.semanticsLabel}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: ReadableWidth(
            tight: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                PathMascotPreview(
                  key: const ValueKey('science-teach-back-character'),
                  reaction: reaction,
                  size: 72,
                  style: GameActivityScaffold.mascotStyleOf(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TEACH BACK  /  $stageLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: colors.pathReview)
                            .jaWeight(FontWeight.w700),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        conceptLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.jaWeight(
                          FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        stepLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.inkMuted,
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
    );
  }
}

class _ChooseRoute extends StatelessWidget {
  const _ChooseRoute({
    required this.prompt,
    required this.onVoice,
    required this.onText,
  });

  final _TeachingPrompt prompt;
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
          'デキすぎ君に、あなたが教える番',
          style: theme.textTheme.headlineSmall?.jaWeight(FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          '教材の答えは隠れたままです。説明のあと、デキすぎ君から固定の質問が1つ返ってきます。自由説明は採点も送信もしませんが、大事な言葉が届いたかだけ端末内で確かめます。',
          style: theme.textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: 18),
        _Prompt(prompt: prompt),
        const SizedBox(height: 20),
        _RouteButton(
          buttonKey: const ValueKey('science-explain-choose-voice'),
          icon: Icons.mic_none,
          title: '声で教える',
          body: '最大60秒。録音を最後まで聞いてから、問い返しへ進む',
          onPressed: onVoice,
        ),
        const SizedBox(height: 10),
        _RouteButton(
          buttonKey: const ValueKey('science-explain-choose-text'),
          icon: Icons.keyboard_outlined,
          title: '文字で教える',
          body: '同じ問いへの説明を書き、読み返してから進む',
          onPressed: onText,
        ),
      ],
    );
  }
}

class _VoiceAnswer extends StatelessWidget {
  const _VoiceAnswer({
    required this.prompt,
    required this.snapshot,
    required this.busy,
    required this.isRevision,
    required this.revisionHint,
    required this.canAdvance,
    required this.allowRouteSwitch,
    required this.routeSwitchIsFallback,
    required this.onStart,
    required this.onStop,
    required this.onPlay,
    required this.onRecordAgain,
    required this.onUseText,
    required this.onAdvance,
  });

  final _TeachingPrompt prompt;
  final LocalVoicePracticeSnapshot snapshot;
  final bool busy;
  final bool isRevision;
  final String? revisionHint;
  final bool canAdvance;
  final bool allowRouteSwitch;
  final bool routeSwitchIsFallback;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onPlay;
  final VoidCallback onRecordAgain;
  final VoidCallback onUseText;
  final VoidCallback onAdvance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    final recording = snapshot.state == LocalVoicePracticeState.recording;
    final playing = snapshot.state == LocalVoicePracticeState.playing;
    final denied = snapshot.state == LocalVoicePracticeState.permissionDenied;
    final failed = snapshot.state == LocalVoicePracticeState.failed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HiddenMaterialNotice(),
        if (isRevision) ...[
          const SizedBox(height: 12),
          _RevisionHint(hint: revisionHint),
        ],
        const SizedBox(height: 14),
        _Prompt(prompt: prompt),
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
                recording
                    ? Icons.mic
                    : playing
                    ? Icons.hearing
                    : Icons.graphic_eq,
                size: 42,
                color: colors.onPathReview,
              ),
              const SizedBox(height: 10),
              Text(
                recording
                    ? '録音中  ${_durationLabel(snapshot.duration)} / 1:00'
                    : playing
                    ? '自分の説明を最後まで再生中'
                    : snapshot.hasRecording
                    ? snapshot.playbackCompleted
                          ? '${_durationLabel(snapshot.duration)} の説明を最後まで聞きました'
                          : '${_durationLabel(snapshot.duration)} の説明をRAMに保持中'
                    : isRevision
                    ? 'ヒントを使い、同じ声の方法で言い直します。'
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
                  label: isRevision ? '言い直しを録音する' : '録音を始める',
                  icon: Icons.mic,
                  onPressed: busy ? null : onStart,
                  light: true,
                )
              else ...[
                _Action(
                  buttonKey: const ValueKey('science-explain-play-recording'),
                  label: playing
                      ? '最後まで再生中'
                      : snapshot.playbackCompleted
                      ? 'もう一度聞く'
                      : '自分の説明を最後まで聞く',
                  icon: Icons.play_arrow,
                  onPressed: busy || playing ? null : onPlay,
                  light: true,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  key: const ValueKey('science-explain-record-again'),
                  onPressed: busy || playing ? null : onRecordAgain,
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
            text: isRevision
                ? 'マイクを使えませんでした。今回だけ文字へ切り替え、同じヒントから言い直せます。'
                : denied
                ? 'マイクを使えませんでした。最初の説明なら、権限を変えず文字で同じ課題を進められます。'
                : '録音を続けられませんでした。音声は保存されていません。',
          ),
        ],
        const SizedBox(height: 14),
        _Action(
          buttonKey: const ValueKey('science-explain-submit-voice'),
          label: canAdvance
              ? isRevision
                    ? '言い直しを終えて、教材と比べる'
                    : 'デキすぎ君の質問へ'
              : '録音を最後まで聞く',
          icon: isRevision ? Icons.compare_arrows : Icons.question_answer,
          onPressed: canAdvance ? onAdvance : null,
        ),
        if (allowRouteSwitch) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            key: const ValueKey('science-explain-use-text'),
            onPressed: onUseText,
            icon: const Icon(Icons.keyboard_outlined),
            label: Text(routeSwitchIsFallback ? '文字で言い直す' : '文字で教える'),
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ],
    );
  }
}

class _TextAnswer extends StatelessWidget {
  const _TextAnswer({
    required this.prompt,
    required this.controller,
    required this.isRevision,
    required this.revisionHint,
    required this.canReview,
    required this.reviewed,
    required this.allowRouteSwitch,
    required this.coverage,
    required this.coverageBlocked,
    required this.canBypass,
    required this.onReview,
    required this.onUseVoice,
    required this.onAdvance,
    required this.onBypass,
  });

  final _TeachingPrompt prompt;
  final TextEditingController controller;
  final bool isRevision;
  final String? revisionHint;
  final bool canReview;
  final bool reviewed;
  final bool allowRouteSwitch;

  /// 読み返し後の聞き取り結果。null ならパネル自体を出さない。
  final ExplanationCoverage? coverage;
  final bool coverageBlocked;
  final bool canBypass;
  final VoidCallback onReview;
  final VoidCallback onUseVoice;
  final VoidCallback onAdvance;
  final VoidCallback onBypass;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HiddenMaterialNotice(),
        if (isRevision) ...[
          const SizedBox(height: 12),
          _RevisionHint(hint: revisionHint),
        ],
        const SizedBox(height: 14),
        _Prompt(prompt: prompt),
        const SizedBox(height: 16),
        Text(
          isRevision ? 'ヒントを使って、説明を言い直す' : 'この問いを、自分の言葉で教える',
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
            hintText: '問いへの答えと根拠を、自分の言葉で説明する',
            filled: true,
            fillColor: colors.surfaceRaised,
          ),
        ),
        if (coverage != null) ...[
          const SizedBox(height: 10),
          _CoveragePanel(
            coverage: coverage!,
            blocked: coverageBlocked,
            canBypass: canBypass,
            onBypass: onBypass,
          ),
        ],
        const SizedBox(height: 10),
        _Action(
          buttonKey: const ValueKey('science-explain-review-text'),
          label: reviewed ? '読み返し確認済み' : '自分の説明を読み返した',
          icon: reviewed
              ? Icons.check_circle_outline
              : Icons.chrome_reader_mode,
          onPressed: canReview && !reviewed ? onReview : null,
        ),
        const SizedBox(height: 8),
        _Action(
          buttonKey: const ValueKey('science-explain-submit-text'),
          label: reviewed
              ? isRevision
                    ? '言い直しを終えて、教材と比べる'
                    : 'デキすぎ君の質問へ'
              : '先に自分の説明を読み返す',
          icon: isRevision ? Icons.compare_arrows : Icons.question_answer,
          onPressed: canReview && reviewed ? onAdvance : null,
        ),
        if (allowRouteSwitch) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            key: const ValueKey('science-explain-use-voice'),
            onPressed: onUseVoice,
            icon: const Icon(Icons.mic_none),
            label: const Text('声で教える'),
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ],
    );
  }
}

class _FollowUp extends StatelessWidget {
  const _FollowUp({
    required this.spokenQuestion,
    required this.aiComposedAck,
    required this.checkpoint,
    required this.selectedOptionId,
    required this.wrongOption,
    required this.speaking,
    required this.narrationUnavailable,
    required this.reaction,
    required this.onReadQuestion,
    required this.onStopQuestion,
    required this.onSelect,
    required this.onSubmit,
    required this.onRevise,
  });

  final String spokenQuestion;
  final bool aiComposedAck;
  final LocalCheckpoint checkpoint;
  final String? selectedOptionId;
  final LocalCheckpointOption? wrongOption;
  final bool speaking;
  final bool narrationUnavailable;
  final GameCharacterReaction reaction;
  final VoidCallback onReadQuestion;
  final VoidCallback onStopQuestion;
  final ValueChanged<String> onSelect;
  final VoidCallback onSubmit;
  final VoidCallback onRevise;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    final lockedWrong = wrongOption != null;
    return Semantics(
      key: const ValueKey('science-explain-follow-up'),
      container: true,
      label: lockedWrong
          ? 'デキすぎ君の問い返し。選んだ考えをヒントから言い直します。'
          : 'デキすぎ君の問い返し。$spokenQuestion。固定の3択から選びます。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surfaceRaised,
              borderRadius: BorderRadius.circular(GameTokens.radiusSheet),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                PathMascotPreview(
                  key: const ValueKey('science-follow-up-character'),
                  reaction: reaction,
                  size: 112,
                  style: GameActivityScaffold.mascotStyleOf(context),
                ),
                const SizedBox(height: 12),
                Text(
                  speaking ? 'デキすぎ君が質問しています' : 'デキすぎ君からの問い返し',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: colors.pathReview)
                      .jaWeight(FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  spokenQuestion,
                  key: const ValueKey('science-explain-spoken-question'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.jaWeight(FontWeight.w700),
                ),
                if (aiComposedAck) ...[
                  const SizedBox(height: 6),
                  Text(
                    '返事の前置きは、生成AIがあなたの説明を読んで書きました。',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.inkMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey('science-explain-read-question'),
                  onPressed: speaking ? onStopQuestion : onReadQuestion,
                  icon: Icon(speaking ? Icons.stop : Icons.record_voice_over),
                  label: Text(speaking ? '読み上げを止める' : '質問をもう一度聞く'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          ),
          if (narrationUnavailable) ...[
            const SizedBox(height: 12),
            const _Notice(text: '端末の読み上げを使えません。画面の質問を読んで、そのまま続けられます。'),
          ],
          const SizedBox(height: 18),
          if (lockedWrong) ...[
            _RevisionHint(
              hint: wrongOption!.hint,
              attemptedText: wrongOption!.text,
            ),
            const SizedBox(height: 14),
            _Action(
              buttonKey: const ValueKey('science-explain-start-revision'),
              label: 'ヒントを使って、同じ方法で言い直す',
              icon: Icons.replay,
              onPressed: onRevise,
            ),
            const SizedBox(height: 8),
            Text(
              '他の選択肢を順番に試す代わりに、自分の説明を直します。正しい答えは比較まで表示しません。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.inkMuted,
              ),
            ),
          ] else ...[
            Text(
              '答えを1つ選ぶ',
              style: theme.textTheme.titleMedium?.jaWeight(FontWeight.w700),
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < checkpoint.options.length; i++) ...[
              _CheckpointOptionButton(
                option: checkpoint.options[i],
                index: i,
                selected: selectedOptionId == checkpoint.options[i].id,
                onPressed: speaking
                    ? null
                    : () => onSelect(checkpoint.options[i].id),
              ),
              if (i != checkpoint.options.length - 1)
                const SizedBox(height: 10),
            ],
            const SizedBox(height: 16),
            _Action(
              buttonKey: const ValueKey('science-explain-submit-follow-up'),
              label: 'この答えで決める',
              icon: Icons.fact_check_outlined,
              onPressed: selectedOptionId == null || speaking ? null : onSubmit,
            ),
            const SizedBox(height: 8),
            Text(
              '自由説明は採点しません。この固定問題だけを端末内で確認し、選択内容は保存しません。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.inkMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CheckpointOptionButton extends StatelessWidget {
  const _CheckpointOptionButton({
    required this.option,
    required this.index,
    required this.selected,
    required this.onPressed,
  });

  final LocalCheckpointOption option;
  final int index;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    return OutlinedButton(
      key: ValueKey('science-explain-follow-up-option-${option.id}'),
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 58),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        side: BorderSide(
          color: selected ? colors.pathReview : colors.border,
          width: selected ? 2 : 1,
        ),
        backgroundColor: selected ? colors.surfaceRaised : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GameTokens.radiusMd),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? colors.pathReview : colors.surfaceRaised,
              borderRadius: BorderRadius.circular(GameTokens.radiusSm),
              border: Border.all(color: colors.border),
            ),
            child: selected
                ? Icon(Icons.check, size: 18, color: colors.onPathReview)
                : Text('${index + 1}', style: theme.textTheme.labelMedium),
          ),
          const SizedBox(width: 11),
          Expanded(child: Text(option.text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _SelfComparison extends StatelessWidget {
  const _SelfComparison({
    required this.route,
    required this.submittedText,
    required this.outcome,
    required this.reason,
    required this.checkpointCorrection,
    required this.checkpointExplanation,
    required this.revisedAfterHint,
    required this.voicePlaying,
    required this.onReplay,
    required this.onRevise,
    required this.onKeep,
  });

  final _AnswerRoute route;
  final String? submittedText;
  final String outcome;
  final String reason;
  final String checkpointCorrection;
  final String checkpointExplanation;
  final bool revisedAfterHint;
  final bool voicePlaying;
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
      label:
          '教材との振り返り。現象の結果。$outcome。理由と条件。$reason。'
          '問い返しの直し方。$checkpointCorrection。$checkpointExplanation。'
          '回答は保存せず進捗だけ記録します。',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              revisedAfterHint ? '言い直した説明と、教材を比べる' : '教えた内容と、教材を比べる',
              style: theme.textTheme.headlineSmall?.jaWeight(FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '自由説明そのものの正誤は採点していません。大事な言葉の聞き取りと固定の問い返し、教材との比較で、足りない条件や理由を自分で確かめます。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.inkMuted,
              ),
            ),
            const SizedBox(height: 16),
            _ComparisonCard(
              title: '教材の観察',
              primary: outcome,
              secondaryTitle: '理由と条件',
              secondary: reason,
            ),
            const SizedBox(height: 12),
            _ComparisonCard(
              title: 'デキすぎ君の問いの直し方',
              primary: checkpointCorrection,
              secondaryTitle: 'なぜそう直す？',
              secondary: checkpointExplanation,
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
                      label: voicePlaying ? '再生中' : '録音をもう一度聞く',
                      icon: Icons.play_arrow,
                      onPressed: voicePlaying ? null : onReplay,
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
              label: '比較を終えて、進捗だけ記録',
              icon: Icons.check,
              onPressed: voicePlaying ? null : onKeep,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('science-explain-revise'),
              onPressed: voicePlaying ? null : onRevise,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('説明をもう一度直す'),
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

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({
    required this.title,
    required this.primary,
    required this.secondaryTitle,
    required this.secondary,
  });

  final String title;
  final String primary;
  final String secondaryTitle;
  final String secondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    return Container(
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
            title,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: colors.ink)
                .jaWeight(FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Text(
            primary,
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: colors.ink)
                .jaWeight(FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            secondaryTitle,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: colors.ink)
                .jaWeight(FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Text(
            secondary,
            style: theme.textTheme.bodyMedium?.copyWith(color: colors.ink),
          ),
        ],
      ),
    );
  }
}

class _Complete extends StatelessWidget {
  const _Complete({
    required this.usedVoice,
    required this.revisedAfterHint,
    required this.onReturnToPath,
  });

  final bool usedVoice;
  final bool revisedAfterHint;
  final VoidCallback onReturnToPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    final routeLabel = usedVoice ? '声' : '文字';
    final revisionLabel = revisedAfterHint ? 'ヒントから言い直し、' : '';
    return Column(
      children: [
        Semantics(
          key: const ValueKey('science-explain-finished'),
          container: true,
          label:
              'ティーチバック完了。$routeLabelで教え、$revisionLabel固定の問い返しと教材を比べました。'
              '回答、選択内容、音声は保存せず、進捗だけを記録しました。',
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
                  PathMascotPreview(
                    reaction: GameCharacterReaction.celebrate,
                    size: 120,
                    style: GameActivityScaffold.mascotStyleOf(context),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'デキすぎ君に教えられた！',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(color: colors.ink)
                        .jaWeight(FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$routeLabelで教えた内容と選択した答えは保存していません。端末には学習進捗だけを記録しました。',
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

class _Prompt extends StatelessWidget {
  const _Prompt({required this.prompt});

  final _TeachingPrompt prompt;

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
            child: Icon(
              Icons.question_mark,
              size: 19,
              color: colors.onPathReview,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prompt.label,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: colors.pathReview)
                      .jaWeight(FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(prompt.text, style: theme.textTheme.bodyMedium),
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
              '教材と正しい答えは隠れています。デキすぎ君へ、自分の言葉で教えます。',
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

class _RevisionHint extends StatelessWidget {
  const _RevisionHint({this.hint, this.attemptedText});

  final String? hint;
  final String? attemptedText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    return Semantics(
      key: const ValueKey('science-explain-follow-up-hint'),
      liveRegion: true,
      container: true,
      label:
          'もう一度考えるヒント。${attemptedText == null ? '' : '選んだ考え。$attemptedText。'}'
          '${hint ?? '条件と理由をもう一度つなげます。'}',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(GameTokens.radiusMd),
            border: Border.all(color: colors.pathReview, width: 2),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline, color: colors.pathReview),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ここをもう一度考えよう',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(color: colors.ink)
                          .jaWeight(FontWeight.w700),
                    ),
                    if (attemptedText != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        '選んだ考え: $attemptedText',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.inkMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      hint ?? '条件と理由をもう一度つなげます。',
                      style: theme.textTheme.bodyMedium?.copyWith(
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

/// デキすぎ君が説明から聞き取れた「大事な言葉」の表示。
///
/// 聞き取れた語だけを見せる —— 届いていない語は答えを漏らすので出さない。
/// 届かないときは「もう少し聞かせて」と返し、何度も届かなければ
/// 生徒を閉じ込めないように「このまま進む」を開く。
class _CoveragePanel extends StatelessWidget {
  const _CoveragePanel({
    required this.coverage,
    required this.blocked,
    required this.canBypass,
    required this.onBypass,
  });

  final ExplanationCoverage coverage;
  final bool blocked;
  final bool canBypass;
  final VoidCallback onBypass;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    final heard = coverage.matchedTerms;
    return Container(
      key: const ValueKey('science-explain-coverage'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(GameTokens.radiusMd),
        border: Border.all(
          color: blocked ? colors.pathReview : colors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'デキすぎ君が聞き取れた言葉',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: colors.inkMuted)
                .jaWeight(FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (heard.isEmpty)
            Text(
              'まだ大事な言葉が届いていないみたい',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.inkMuted,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final term in heard)
                  Container(
                    key: ValueKey('science-explain-cue-$term'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colors.pathActive,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      term,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colors.onPathActive,
                      ),
                    ),
                  ),
              ],
            ),
          if (blocked) ...[
            const SizedBox(height: 10),
            Text(
              '「もう少し聞かせて！」大事な言葉がまだ足りないみたい。理由や条件も入れて、もう一度説明してあげて。',
              style: theme.textTheme.bodySmall?.copyWith(color: colors.ink),
            ),
            if (canBypass) ...[
              const SizedBox(height: 4),
              TextButton(
                key: const ValueKey('science-explain-coverage-bypass'),
                onPressed: onBypass,
                child: const Text('この説明のまま進む'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// 声で教えたあとの「聞き取り確認」。デキすぎ君が大事な言葉を
/// もう一度だけ聞き、届いていれば問い返しへ進む。
class _EchoCheck extends StatelessWidget {
  const _EchoCheck({
    required this.conceptLabel,
    required this.isRevision,
    required this.input,
    required this.phase,
    required this.coverage,
    required this.missed,
    required this.canBypass,
    required this.controller,
    required this.onRetryVoice,
    required this.onUseText,
    required this.onSubmitText,
    required this.onAdvance,
    required this.onBypass,
  });

  final String conceptLabel;
  final bool isRevision;
  final _EchoInput input;
  final _EchoPhase phase;
  final ExplanationCoverage? coverage;
  final bool missed;
  final bool canBypass;
  final TextEditingController controller;
  final VoidCallback onRetryVoice;
  final VoidCallback onUseText;
  final VoidCallback onSubmitText;
  final VoidCallback onAdvance;
  final VoidCallback onBypass;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    final listening = phase == _EchoPhase.listening;
    final heard = phase == _EchoPhase.heard;
    return Column(
      key: const ValueKey('science-explain-echo'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _HiddenMaterialNotice(),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(GameTokens.radiusSheet),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            children: [
              PathMascotPreview(
                reaction: listening
                    ? GameCharacterReaction.listening
                    : heard
                    ? GameCharacterReaction.celebrate
                    : GameCharacterReaction.thinking,
                size: 112,
                style: GameActivityScaffold.mascotStyleOf(context),
              ),
              const SizedBox(height: 12),
              Text(
                listening
                    ? 'デキすぎ君が聞いています'
                    : heard
                    ? '届いた！'
                    : 'もう一度だけ教えて',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.jaWeight(FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                listening
                    ? 'いまの説明の大事な言葉を、もう一度だけ声で聞かせてください'
                    : heard
                    ? '$conceptLabel の言葉が届きました'
                    : input == _EchoInput.voice
                    ? '「$conceptLabel」の大事な言葉が届かなかったみたい。理由や条件を入れて、もう一度言ってみて'
                    : '録音から言葉を聞き取れない端末です。代わりに、説明の大事な言葉を書いて確かめます',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.inkMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (input == _EchoInput.voice) ...[
          _Action(
            buttonKey: const ValueKey('science-explain-echo-voice'),
            label: listening
                ? '聞き取り中…'
                : missed
                ? 'もう一度声で言い直す'
                : '要点を声で聞かせる',
            icon: listening ? Icons.hearing : Icons.mic,
            onPressed: listening ? null : onRetryVoice,
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            key: const ValueKey('science-explain-echo-use-text'),
            onPressed: onUseText,
            icon: const Icon(Icons.keyboard_outlined),
            label: const Text('文字で教える'),
            style: TextButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ] else ...[
          TextField(
            key: const ValueKey('science-explain-echo-text-input'),
            controller: controller,
            minLines: 1,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: '説明に入れた大事な言葉を書く',
              filled: true,
              fillColor: colors.surfaceRaised,
            ),
          ),
          const SizedBox(height: 8),
          _Action(
            buttonKey: const ValueKey('science-explain-echo-submit-text'),
            label: 'これで確かめる',
            icon: Icons.fact_check_outlined,
            onPressed: onSubmitText,
          ),
        ],
        if (coverage != null) ...[
          const SizedBox(height: 12),
          _CoveragePanel(
            coverage: coverage!,
            blocked: missed,
            canBypass: canBypass,
            onBypass: onBypass,
          ),
        ],
        if (missed && canBypass) ...[
          const SizedBox(height: 8),
          TextButton(
            key: const ValueKey('science-explain-echo-bypass'),
            onPressed: onBypass,
            child: const Text('このまま進む'),
          ),
        ],
        if (heard) ...[
          const SizedBox(height: 14),
          _Action(
            buttonKey: const ValueKey('science-explain-echo-advance'),
            label: isRevision ? '教材と比べる' : 'デキすぎ君の質問へ',
            icon: isRevision ? Icons.compare_arrows : Icons.question_answer,
            onPressed: onAdvance,
          ),
        ],
      ],
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
