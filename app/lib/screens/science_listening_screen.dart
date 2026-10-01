import 'dart:async';

import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../learning/domain/learning_heart.dart';
import '../learning/domain/learning_need.dart';
import '../models/game_path.dart';
import '../models/unit.dart';
import '../services/local_narration.dart';
import '../services/transcript_text.dart';
import '../ui/_material.dart';
import '../widgets/readable_width.dart';
import '../widgets/science_challenge_support.dart';

/// 固定の科学説明を聞き、文字起こしと意味判断を分けて行うListen課題。
///
/// サーバー採点は使わない。入力文と選択はこのStateだけに保持し、
/// callbackへはcatalog固定need/heart IDだけを渡す。誤答後は残りを総当たり
/// させず、本人の文字起こしと教材正本をsubmit後に直接比較する。
class ScienceListeningScreen extends StatefulWidget {
  const ScienceListeningScreen({
    super.key,
    required this.section,
    required this.conceptLabel,
    required this.practiceAttempt,
    required this.onCompleted,
    this.onReturnToPath,
    this.narration,
    this.bundledHumanRecording,
    this.repairNeedCode,
    this.onNeedEvidence,
    this.onHeartLoss,
  });

  final Section section;
  final String conceptLabel;
  final int practiceAttempt;
  final VoidCallback onCompleted;
  final LearningNeedEvidenceReported? onNeedEvidence;
  final LearningHeartLossReported? onHeartLoss;
  final VoidCallback? onReturnToPath;

  @visibleForTesting
  final LocalNarration? narration;

  /// 実ファイルを同梱した場合だけ指定する。現行catalog v9は録音資産を
  /// 持たないためproductionではnull。端末TTSを人の録音と表示しない。
  final BundledHumanNarrationAsset? bundledHumanRecording;

  /// Repair Plannerが選んだListening専用need。通常pathではnull。
  /// 回答を含まず、現在のconcept×stageと一致しない値はfail-closedにする。
  final String? repairNeedCode;

  @override
  State<ScienceListeningScreen> createState() => _ScienceListeningScreenState();
}

enum _ListeningPhase {
  prepare,
  transcribe,
  transcriptCompare,
  answer,
  hint,
  compare,
  done,
  textOnlyDone,
}

class _ScienceListeningScreenState extends State<ScienceListeningScreen> {
  late final LocalNarration _narration;
  final _scroll = ScrollController();
  final _transcript = TextEditingController();
  final _transcriptFocus = FocusNode();

  _ListeningPhase _phase = _ListeningPhase.prepare;
  bool _speaking = false;
  bool _heard = false;
  bool _showTextFallback = false;
  bool _textOnly = false;
  bool _completionStarted = false;
  bool _returnStarted = false;
  bool? _transcriptMatched;
  LocalNarrationDelivery? _delivery;
  String? _selectedOptionId;
  final Set<String> _reportedNeedCodes = {};
  bool _heartLossReported = false;

  LocalPracticeVariant get _variant =>
      widget.section.practiceVariantForAttempt(widget.practiceAttempt);

  LocalCheckpoint get _checkpoint => _variant.checkpoint;

  LocalListeningNeedCodes get _listeningNeedCodes =>
      _variant.listeningNeedCodes ??
      (throw StateError('catalog v9 Listening needCodes are required'));

  LocalCheckpointOption? get _selectedOption {
    final id = _selectedOptionId;
    return id == null ? null : _checkpoint.optionFor(id);
  }

  LocalCheckpointOption? get _correctOption =>
      _checkpoint.optionFor(_checkpoint.correctOptionId);

  GameCharacterReaction get _mascotReaction {
    if (_speaking) return GameCharacterReaction.speaking;
    return switch (_phase) {
      _ListeningPhase.prepare => GameCharacterReaction.invite,
      _ListeningPhase.transcribe ||
      _ListeningPhase.answer => GameCharacterReaction.thinking,
      _ListeningPhase.transcriptCompare ||
      _ListeningPhase.hint ||
      _ListeningPhase.compare => GameCharacterReaction.encourage,
      _ListeningPhase.done => GameCharacterReaction.celebrate,
      _ListeningPhase.textOnlyDone => GameCharacterReaction.encourage,
    };
  }

  @override
  void initState() {
    super.initState();
    _narration = widget.narration ?? PlatformLocalNarration();
    final repairNeedCode = widget.repairNeedCode;
    if (repairNeedCode != null &&
        repairNeedCode != _listeningNeedCodes.transcript &&
        repairNeedCode != _listeningNeedCodes.meaning) {
      throw StateError('Repair needCode does not match this Listening task');
    }
    assert(
      widget.bundledHumanRecording == null ||
          widget.bundledHumanRecording!.transcript == _checkpoint.lure,
      '録音assetの文字起こしはListening正本と一致が必要',
    );
  }

  @override
  void dispose() {
    _transcript.dispose();
    _transcriptFocus.dispose();
    _scroll.dispose();
    unawaited(_narration.dispose());
    super.dispose();
  }

  Future<void> _listen() async {
    if (_speaking || _phase == _ListeningPhase.done) return;
    setState(() => _speaking = true);
    final result = await _narration.play(
      LocalNarrationRequest(
        text: _checkpoint.lure,
        bundledHumanRecording: widget.bundledHumanRecording,
      ),
    );
    if (!mounted) return;
    setState(() {
      _speaking = false;
      _delivery = result.delivery;
      if (result.completed) {
        _heard = true;
        if (_phase == _ListeningPhase.prepare) {
          _phase = _ListeningPhase.transcribe;
        }
      } else {
        _showTextFallback = true;
      }
    });
    _toTop();
  }

  void _useTextFallback() {
    if (_speaking || !_showTextFallback) return;
    setState(() {
      _heard = false;
      _textOnly = true;
      _phase = _ListeningPhase.answer;
    });
    _toTop();
  }

  void _transcriptChanged(String _) {
    if (_phase == _ListeningPhase.transcribe) setState(() {});
  }

  void _submitTranscript() {
    if (_phase != _ListeningPhase.transcribe ||
        !_heard ||
        _transcript.text.trim().isEmpty) {
      return;
    }
    _transcriptFocus.unfocus();
    final matched = isExactChallengeText(_transcript.text, _checkpoint.lure);
    _reportNeedCode(
      _listeningNeedCodes.transcript,
      matched
          ? LearningNeedEvidenceKind.demonstrated
          : LearningNeedEvidenceKind.observed,
    );
    if (!matched) {
      _reportHeartLoss('listening:${widget.practiceAttempt}:transcript');
    }
    setState(() {
      _transcriptMatched = matched;
      _phase = _ListeningPhase.transcriptCompare;
    });
    _toTop();
  }

  void _openMeaningQuestion() {
    if (_phase != _ListeningPhase.transcriptCompare) return;
    setState(() => _phase = _ListeningPhase.answer);
    _toTop();
  }

  void _select(String id) {
    if (_phase != _ListeningPhase.answer || _checkpoint.optionFor(id) == null) {
      return;
    }
    setState(() => _selectedOptionId = id);
  }

  void _submit() {
    if (_phase != _ListeningPhase.answer || _selectedOptionId == null) return;
    final correct = _selectedOptionId == _checkpoint.correctOptionId;
    if (!_textOnly) {
      _reportNeedCode(
        _listeningNeedCodes.meaning,
        correct
            ? LearningNeedEvidenceKind.demonstrated
            : LearningNeedEvidenceKind.observed,
      );
    }
    if (!correct && !_textOnly) {
      _reportHeartLoss('listening:${widget.practiceAttempt}:checkpoint');
    }
    setState(() {
      _phase = correct ? _ListeningPhase.compare : _ListeningPhase.hint;
    });
    _toTop();
  }

  void _reportNeedCode(String? generalizedCode, LearningNeedEvidenceKind kind) {
    if (generalizedCode == null || !_reportedNeedCodes.add(generalizedCode)) {
      return;
    }
    widget.onNeedEvidence?.call(
      LearningNeedEvidence(
        conceptKey: widget.section.conceptKey,
        needCode: generalizedCode,
        kind: kind,
      ),
    );
  }

  void _reportHeartLoss(String fixedTaskId) {
    if (_heartLossReported) return;
    _heartLossReported = true;
    widget.onHeartLoss?.call(
      LearningHeartLossEvidence(fixedTaskId: fixedTaskId),
    );
  }

  void _openComparison() {
    if (_phase != _ListeningPhase.hint) return;
    setState(() => _phase = _ListeningPhase.compare);
    _toTop();
  }

  void _complete() {
    if (_phase != _ListeningPhase.compare || _completionStarted) return;
    _completionStarted = true;
    setState(
      () => _phase = _textOnly
          ? _ListeningPhase.textOnlyDone
          : _ListeningPhase.done,
    );
    if (!_textOnly) widget.onCompleted();
    _toTop();
  }

  void _returnToPath() {
    if ((_phase != _ListeningPhase.done &&
            _phase != _ListeningPhase.textOnlyDone) ||
        _returnStarted) {
      return;
    }
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
    final colors = context.gamePalette;
    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: CustomScrollView(
          key: const ValueKey('science-listening-scroll'),
          controller: _scroll,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                GameTokens.spaceLg,
                GameTokens.spaceLg,
                GameTokens.spaceLg,
                GameTokens.spaceXxl,
              ),
              sliver: SliverToBoxAdapter(
                child: ReadableWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ScienceChallengeHeader(
                        eyebrow: 'LISTEN LAB  /  ${_stepLabel(_phase)}',
                        title: widget.conceptLabel,
                        body: '固定教材を端末内音声で聞き、条件と説明を結び付けます。',
                        icon: Icons.headphones_rounded,
                        accent: colors.pathActive,
                        onAccent: colors.onPathActive,
                        mascotReaction: _mascotReaction,
                      ),
                      const SizedBox(height: GameTokens.spaceLg),
                      switch (_phase) {
                        _ListeningPhase.prepare => _Prepare(
                          prompt: _variant.transferPrompt,
                          speaking: _speaking,
                          showTextFallback: _showTextFallback,
                          lure: _checkpoint.lure,
                          bundledHumanRecording: widget.bundledHumanRecording,
                          onListen: _speaking ? null : _listen,
                          onUseText: _showTextFallback
                              ? _useTextFallback
                              : null,
                        ),
                        _ListeningPhase.transcribe => _Transcribe(
                          controller: _transcript,
                          focusNode: _transcriptFocus,
                          speaking: _speaking,
                          delivery: _delivery,
                          onChanged: _transcriptChanged,
                          onReplay: _speaking ? null : _listen,
                          onSubmit: _transcript.text.trim().isEmpty
                              ? null
                              : _submitTranscript,
                        ),
                        _ListeningPhase.transcriptCompare =>
                          _TranscriptComparison(
                            transcript: _transcript.text,
                            source: _checkpoint.lure,
                            matched: _transcriptMatched == true,
                            onContinue: _openMeaningQuestion,
                          ),
                        _ListeningPhase.answer => _Answer(
                          options: _checkpoint.options,
                          selectedOptionId: _selectedOptionId,
                          speaking: _speaking,
                          onReplay: _speaking ? null : _listen,
                          onSelect: _select,
                          onSubmit: _selectedOptionId == null ? null : _submit,
                          textOnlySource: _textOnly ? _checkpoint.lure : null,
                        ),
                        _ListeningPhase.hint => _Hint(
                          selectedText: _selectedOption?.text ?? '',
                          hint: _selectedOption?.hint ?? '条件と結果のつながりを見直します。',
                          onContinue: _openComparison,
                        ),
                        _ListeningPhase.compare => _Comparison(
                          lure: _checkpoint.lure,
                          selectedText: _selectedOption?.text ?? '',
                          correction: _correctOption?.text ?? '',
                          explanation: _checkpoint.explanation,
                          selectedCorrect:
                              _selectedOptionId == _checkpoint.correctOptionId,
                          textOnly: _textOnly,
                          onComplete: _complete,
                        ),
                        _ListeningPhase.done => _Done(
                          onReturnToPath: _returnToPath,
                        ),
                        _ListeningPhase.textOnlyDone => _TextOnlyDone(
                          onReturnToPath: _returnToPath,
                        ),
                      },
                      const SizedBox(height: GameTokens.spaceLg),
                      const ScienceChallengePrivacyNote(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Prepare extends StatelessWidget {
  const _Prepare({
    required this.prompt,
    required this.speaking,
    required this.showTextFallback,
    required this.lure,
    required this.bundledHumanRecording,
    required this.onListen,
    required this.onUseText,
  });

  final String prompt;
  final bool speaking;
  final bool showTextFallback;
  final String lure;
  final BundledHumanNarrationAsset? bundledHumanRecording;
  final VoidCallback? onListen;
  final VoidCallback? onUseText;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScienceChallengeSurface(
          label: '聞く前の場面',
          icon: Icons.visibility_outlined,
          child: Text(prompt),
        ),
        const SizedBox(height: GameTokens.spaceMd),
        ScienceChallengeSurface(
          label: '音声の出所',
          icon: Icons.volume_up_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bundledHumanRecording == null
                    ? 'この教材に人の録音はまだ同梱されていません。端末の音声合成で読み上げます。'
                    : '同梱された${bundledHumanRecording!.narratorLabel}の録音を優先します。再生できない場合だけ端末の音声合成へ切り替えます。',
              ),
              const SizedBox(height: GameTokens.spaceSm),
              Text(
                speaking
                    ? '再生中です。最後まで聞いてから文字起こしへ進みます。'
                    : '説明文は再生が終わるまで画面に出ません。何度でも聞き直せます。',
              ),
            ],
          ),
        ),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengePrimaryButton(
          label: speaking ? '読み上げ中…' : '説明を聞く',
          icon: speaking ? Icons.graphic_eq_rounded : Icons.play_arrow_rounded,
          onPressed: onListen,
          backgroundColor: colors.pathActive,
          foregroundColor: colors.onPathActive,
        ),
        if (showTextFallback) ...[
          const SizedBox(height: GameTokens.spaceMd),
          Semantics(
            liveRegion: true,
            label: '端末の読み上げを使えません。文字で同じ課題に進めます。',
            child: ScienceChallengeSurface(
              label: '読み上げを使えませんでした',
              icon: Icons.subtitles_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('文字で同じ説明を確認して続けられます。'),
                  const SizedBox(height: GameTokens.spaceSm),
                  Text(lure),
                  const SizedBox(height: GameTokens.spaceSm),
                  const Text('音声を確認できていないため、文字起こしは採点せず、意味の判断だけに進みます。'),
                  const SizedBox(height: GameTokens.spaceMd),
                  OutlinedButton.icon(
                    key: const ValueKey('listening-text-fallback'),
                    onPressed: onUseText,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('文字で判断へ進む'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Transcribe extends StatelessWidget {
  const _Transcribe({
    required this.controller,
    required this.focusNode,
    required this.speaking,
    required this.delivery,
    required this.onChanged,
    required this.onReplay,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool speaking;
  final LocalNarrationDelivery? delivery;
  final ValueChanged<String> onChanged;
  final VoidCallback? onReplay;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final sourceLabel = switch (delivery) {
      LocalNarrationDelivery.bundledHumanRecording => '同梱された人の録音',
      LocalNarrationDelivery.deviceSpeechSynthesis => '端末の音声合成',
      _ => '音声',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          label: '$sourceLabelの再生が完了しました。聞こえた文を入力してください。',
          child: ScienceChallengeSurface(
            label: '聞こえた文を文字にする',
            icon: Icons.subtitles_rounded,
            child: Text('$sourceLabelを聞きました。句読点や空白の違いは問いません。語の追加・省略は教材と比べます。'),
          ),
        ),
        const SizedBox(height: GameTokens.spaceMd),
        OutlinedButton.icon(
          key: const ValueKey('listening-replay-transcription'),
          onPressed: onReplay,
          icon: Icon(
            speaking ? Icons.graphic_eq_rounded : Icons.replay_rounded,
          ),
          label: Text(speaking ? '再生中…' : 'もう一度聞く'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
          ),
        ),
        const SizedBox(height: GameTokens.spaceMd),
        Semantics(
          textField: true,
          label: '聞こえた文の文字起こし。回答本文は保存も送信もしません。',
          child: TextField(
            key: const ValueKey('listening-transcription-input'),
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            minLines: 3,
            maxLines: 6,
            maxLength: 800,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit?.call(),
            decoration: const InputDecoration(
              labelText: '聞こえた文',
              hintText: 'ここに文字起こしを入力',
              alignLabelWithHint: true,
            ),
          ),
        ),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengePrimaryButton(
          label: '教材の文と比べる',
          icon: Icons.compare_arrows_rounded,
          onPressed: onSubmit,
          backgroundColor: colors.pathActive,
          foregroundColor: colors.onPathActive,
        ),
      ],
    );
  }
}

class _TranscriptComparison extends StatelessWidget {
  const _TranscriptComparison({
    required this.transcript,
    required this.source,
    required this.matched,
    required this.onContinue,
  });

  final String transcript;
  final String source;
  final bool matched;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          label: matched ? '文字起こしは教材と一致しました。' : '文字起こしに追加または省略があります。教材の文と比べます。',
          child: ScienceChallengeSurface(
            label: matched ? '聞き取った語が一致' : '聞き取りの差を確認',
            icon: matched
                ? Icons.check_circle_outline_rounded
                : Icons.find_in_page_outlined,
            backgroundColor: (matched ? colors.pathComplete : colors.pathReview)
                .withValues(alpha: .12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('あなたの文字起こし：$transcript'),
                const SizedBox(height: GameTokens.spaceSm),
                Text('教材の文：$source'),
                if (!matched) ...[
                  const SizedBox(height: GameTokens.spaceSm),
                  const Text('差のあった箇所を確認し、次は文全体の意味を判断します。'),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengePrimaryButton(
          key: const ValueKey('listening-open-meaning'),
          label: '文の意味を判断する',
          icon: Icons.arrow_forward_rounded,
          onPressed: onContinue,
          backgroundColor: matched ? colors.pathComplete : colors.pathReview,
          foregroundColor: matched
              ? colors.onPathComplete
              : colors.onPathReview,
        ),
      ],
    );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({
    required this.options,
    required this.selectedOptionId,
    required this.speaking,
    required this.onReplay,
    required this.onSelect,
    required this.onSubmit,
    required this.textOnlySource,
  });

  final List<LocalCheckpointOption> options;
  final String? selectedOptionId;
  final bool speaking;
  final VoidCallback? onReplay;
  final ValueChanged<String> onSelect;
  final VoidCallback? onSubmit;
  final String? textOnlySource;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (textOnlySource case final source?) ...[
          ScienceChallengeSurface(
            label: '文字教材（聞き取り観察とは別の学習）',
            icon: Icons.article_outlined,
            child: Text(source),
          ),
        ] else
          OutlinedButton.icon(
            key: const ValueKey('listening-replay'),
            onPressed: onReplay,
            icon: Icon(
              speaking ? Icons.graphic_eq_rounded : Icons.replay_rounded,
            ),
            label: Text(speaking ? '読み上げ中…' : 'もう一度聞く'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        const SizedBox(height: GameTokens.spaceLg),
        Text(
          textOnlySource == null
              ? '聞いた説明を、観察に合う形へ直すなら？'
              : '表示した説明を、観察に合う形へ直すなら？',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.jaWeight(FontWeight.w800),
        ),
        const SizedBox(height: GameTokens.spaceMd),
        for (var index = 0; index < options.length; index++) ...[
          Semantics(
            selected: options[index].id == selectedOptionId,
            button: true,
            label: '${index + 1}番。${options[index].text}',
            child: ExcludeSemantics(
              child: OutlinedButton(
                key: ValueKey('listening-option-${options[index].id}'),
                onPressed: () => onSelect(options[index].id),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  alignment: Alignment.centerLeft,
                  backgroundColor: options[index].id == selectedOptionId
                      ? colors.pathActive.withValues(alpha: .12)
                      : colors.surface,
                  side: BorderSide(
                    color: options[index].id == selectedOptionId
                        ? colors.pathActive
                        : colors.border,
                    width: options[index].id == selectedOptionId ? 2 : 1,
                  ),
                ),
                child: Text(options[index].text),
              ),
            ),
          ),
          if (index < options.length - 1)
            const SizedBox(height: GameTokens.spaceSm),
        ],
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengePrimaryButton(
          label: 'この判断で比べる',
          icon: Icons.compare_arrows_rounded,
          onPressed: onSubmit,
          backgroundColor: colors.pathActive,
          foregroundColor: colors.onPathActive,
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({
    required this.selectedText,
    required this.hint,
    required this.onContinue,
  });

  final String selectedText;
  final String hint;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          label: '別の条件を確認します。選んだ説明、$selectedText。見直す観点、$hint',
          child: ScienceChallengeSurface(
            label: '別の条件を確認する',
            icon: Icons.travel_explore_rounded,
            backgroundColor: colors.pathReview.withValues(alpha: .12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('選んだ説明：$selectedText'),
                const SizedBox(height: GameTokens.spaceSm),
                Text('見直す観点：$hint'),
              ],
            ),
          ),
        ),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengePrimaryButton(
          label: '教材の訂正と比べる',
          icon: Icons.arrow_forward_rounded,
          onPressed: onContinue,
          backgroundColor: colors.pathReview,
          foregroundColor: colors.onPathReview,
        ),
      ],
    );
  }
}

class _Comparison extends StatelessWidget {
  const _Comparison({
    required this.lure,
    required this.selectedText,
    required this.correction,
    required this.explanation,
    required this.selectedCorrect,
    required this.textOnly,
    required this.onComplete,
  });

  final String lure;
  final String selectedText;
  final String correction;
  final String explanation;
  final bool selectedCorrect;
  final bool textOnly;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScienceChallengeSurface(
          label: textOnly ? '表示した文字教材' : '聞いた説明',
          icon: textOnly ? Icons.article_outlined : Icons.hearing_rounded,
          child: Text(lure),
        ),
        const SizedBox(height: GameTokens.spaceMd),
        ScienceChallengeSurface(
          label: selectedCorrect ? '選んだ説明は条件と一致' : '選んだ説明と教材を比較',
          icon: selectedCorrect
              ? Icons.check_circle_outline_rounded
              : Icons.compare_arrows_rounded,
          backgroundColor: colors.pathComplete.withValues(alpha: .12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('自分の判断：$selectedText'),
              const SizedBox(height: GameTokens.spaceSm),
              Text('教材の訂正：$correction'),
              const SizedBox(height: GameTokens.spaceSm),
              Text(explanation),
            ],
          ),
        ),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengePrimaryButton(
          label: textOnly ? '文字教材の確認を終える' : '聞き取りを完了する',
          icon: Icons.check_rounded,
          onPressed: onComplete,
          backgroundColor: colors.pathComplete,
          foregroundColor: colors.onPathComplete,
        ),
      ],
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({required this.onReturnToPath});

  final VoidCallback onReturnToPath;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScienceChallengeSurface(
          label: 'LISTEN LAB COMPLETE',
          icon: Icons.headphones_rounded,
          backgroundColor: colors.pathComplete.withValues(alpha: .12),
          child: const Text('聞いた説明を、観察条件と正しい訂正へ結び付けました。'),
        ),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengePrimaryButton(
          key: const ValueKey('listening-return-to-path'),
          label: '探究ノートへ戻る',
          icon: Icons.route_rounded,
          onPressed: onReturnToPath,
          backgroundColor: colors.pathActive,
          foregroundColor: colors.onPathActive,
        ),
      ],
    );
  }
}

class _TextOnlyDone extends StatelessWidget {
  const _TextOnlyDone({required this.onReturnToPath});

  final VoidCallback onReturnToPath;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScienceChallengeSurface(
          label: '文字教材の確認を完了',
          icon: Icons.article_outlined,
          backgroundColor: colors.pathReview.withValues(alpha: .12),
          child: const Text(
            '音声を再生できなかったため、聞き取り観察・探究記録・連続観測には数えません。文字で意味だけを確認しました。',
          ),
        ),
        const SizedBox(height: GameTokens.spaceLg),
        ScienceChallengePrimaryButton(
          key: const ValueKey('listening-text-only-return-to-path'),
          label: '探究ノートへ戻る',
          icon: Icons.route_rounded,
          onPressed: onReturnToPath,
          backgroundColor: colors.pathActive,
          foregroundColor: colors.onPathActive,
        ),
      ],
    );
  }
}

String _stepLabel(_ListeningPhase phase) => switch (phase) {
  _ListeningPhase.prepare => '1 OF 4',
  _ListeningPhase.transcribe || _ListeningPhase.transcriptCompare => '2 OF 4',
  _ListeningPhase.answer || _ListeningPhase.hint => '3 OF 4',
  _ListeningPhase.compare ||
  _ListeningPhase.done ||
  _ListeningPhase.textOnlyDone => '4 OF 4',
};
