import '../config/app_language.dart' as localize;
import 'dart:async';

import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../learning/domain/learning_heart.dart';
import '../learning/domain/learning_need.dart';
import '../models/game_path.dart';
import '../models/unit.dart';
import '../services/local_narration.dart';
import '../ui/_material.dart';
import '../widgets/readable_width.dart';
import '../widgets/science_challenge_support.dart';
import '../config/app_language.dart';

/// 固定教材だけで完結する、3幕の科学ストーリー。
///
/// 生成AIや自由記述の採点は使わない。現在のvariantにある具体場面と固定の
/// 誤概念を、状況 → 判断 → 観察・訂正の順で比べる。選択内容はこのStateに
/// だけ保持し、完了callbackへも渡さない。
class ScienceStoryScreen extends StatefulWidget {
  const ScienceStoryScreen({
    super.key,
    required this.section,
    required this.conceptLabel,
    required this.practiceAttempt,
    required this.onCompleted,
    this.onReturnToPath,
    this.narration,
    this.onNeedEvidence,
    this.onHeartLoss,
  });

  final Section section;
  final String conceptLabel;
  final int practiceAttempt;

  /// 回答内容を渡さず、ストーリーを最後まで比較した事実だけを通知する。
  /// 連打や再構築があっても、このWidgetの生存中は一度しか呼ばない。
  final VoidCallback onCompleted;
  final LearningNeedEvidenceReported? onNeedEvidence;
  final LearningHeartLossReported? onHeartLoss;

  /// 完了を画面に残した後、学習パスへ明示的に戻る操作を通知する。
  final VoidCallback? onReturnToPath;

  @visibleForTesting
  final LocalNarration? narration;

  @override
  State<ScienceStoryScreen> createState() => _ScienceStoryScreenState();
}

enum _StoryScene { situation, judgment, reaction, comparison, complete }

class _ScienceStoryScreenState extends State<ScienceStoryScreen>
    with WidgetsBindingObserver {
  late final LocalNarration _narration;
  _StoryScene _scene = _StoryScene.situation;
  String? _selectedOptionId;
  bool _completionStarted = false;
  bool _returnStarted = false;
  bool _speaking = false;
  bool _needEvidenceReported = false;
  int _narrationEpoch = 0;

  @override
  void initState() {
    super.initState();
    assert(widget.section.scienceStory != null);
    _narration = widget.narration ?? PlatformLocalNarration();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _stopNarrationForSceneChange();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _narrationEpoch++;
    unawaited(_narration.dispose());
    super.dispose();
  }

  // Science StoryはSectionごとに1本。回数で条件/transferへ差し替えず、
  // catalogで対応検証済みのfoundation variantだけを正本として使う。
  LocalPracticeVariant get _variant =>
      widget.section.practiceVariantForAttempt(0);

  LocalScienceStory get _story => widget.section.scienceStory!;

  LocalCheckpoint get _checkpoint => _variant.checkpoint;

  int get _act => switch (_scene) {
    _StoryScene.situation => 1,
    _StoryScene.judgment || _StoryScene.reaction => 2,
    _StoryScene.comparison || _StoryScene.complete => 3,
  };

  LocalCheckpointOption? get _selectedOption {
    final id = _selectedOptionId;
    return id == null ? null : _checkpoint.optionFor(id);
  }

  LocalCheckpointOption? get _correctOption =>
      _checkpoint.optionFor(_checkpoint.correctOptionId);

  String _spokenLines(Iterable<LocalScienceStoryLine> lines) =>
      lines.map((line) => line.text).join(' ');

  Future<void> _speak(String text) async {
    if (_speaking) return;
    final epoch = ++_narrationEpoch;
    setState(() => _speaking = true);
    final completed = await _narration.speak(text);
    if (!mounted || epoch != _narrationEpoch) return;
    setState(() => _speaking = false);
    if (!completed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t(
              '端末の読み上げを使えません。文字で続けられます。',
              'Text-to-speech isn\'t available on this device. You can continue with text.',
            ),
          ),
        ),
      );
    }
  }

  void _stopNarrationForSceneChange() {
    _narrationEpoch++;
    if (_speaking) setState(() => _speaking = false);
    unawaited(_narration.stop());
  }

  void _openJudgment() {
    if (_scene != _StoryScene.situation || _speaking) return;
    _stopNarrationForSceneChange();
    setState(() => _scene = _StoryScene.judgment);
  }

  void _selectOption(String id) {
    if (_scene != _StoryScene.judgment ||
        _speaking ||
        _checkpoint.optionFor(id) == null) {
      return;
    }
    setState(() => _selectedOptionId = id);
  }

  void _submitJudgment() {
    if (_scene != _StoryScene.judgment ||
        _speaking ||
        _selectedOptionId == null) {
      return;
    }
    final correct = _selectedOptionId == _checkpoint.correctOptionId;
    _reportNeed(
      _selectedOption,
      correct
          ? LearningNeedEvidenceKind.demonstrated
          : LearningNeedEvidenceKind.observed,
    );
    if (!correct) {
      widget.onHeartLoss?.call(
        LearningHeartLossEvidence(
          fixedTaskId: 'story:${widget.practiceAttempt}:judgment',
        ),
      );
    }
    _stopNarrationForSceneChange();
    setState(() {
      _scene = _StoryScene.reaction;
    });
  }

  void _reportNeed(
    LocalCheckpointOption? option,
    LearningNeedEvidenceKind kind,
  ) {
    final needCode = option?.needCode;
    // 正答optionはneedCodeを持たないため、同じcheckpointの誤答に付いた
    // 一般化codeを取得する。選択肢IDはcallbackへ渡さない。
    final generalizedCode =
        needCode ??
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

  void _openComparisonAfterReaction() {
    if (_scene != _StoryScene.reaction || _speaking) return;
    // 選択肢へは戻さない。残りを順番に試す代わりに、誤答の観点を確認して
    // 固定教材の観察・訂正と直接比較する。
    _stopNarrationForSceneChange();
    setState(() => _scene = _StoryScene.comparison);
  }

  void _complete() {
    if (_scene != _StoryScene.comparison || _speaking || _completionStarted) {
      return;
    }
    _stopNarrationForSceneChange();
    setState(() {
      _completionStarted = true;
      _scene = _StoryScene.complete;
    });
    widget.onCompleted();
  }

  void _returnToPath() {
    if (_scene != _StoryScene.complete || _returnStarted) return;
    _returnStarted = true;
    _stopNarrationForSceneChange();
    final callback = widget.onReturnToPath;
    if (callback != null) {
      callback();
    } else {
      Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _StoryHeader(
              storyTitle: _story.title,
              conceptLabel: widget.conceptLabel,
              stageLabel: _variant.stage.label,
              act: _act,
              reaction: _speaking
                  ? GameCharacterReaction.speaking
                  : switch (_scene) {
                      _StoryScene.situation => GameCharacterReaction.invite,
                      _StoryScene.judgment => GameCharacterReaction.thinking,
                      _StoryScene.reaction ||
                      _StoryScene.comparison => GameCharacterReaction.encourage,
                      _StoryScene.complete => GameCharacterReaction.celebrate,
                    },
            ),
            Expanded(
              child: SingleChildScrollView(
                key: const ValueKey('science-story-scroll'),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: ReadableWidth(
                  child: switch (_scene) {
                    _StoryScene.situation => _SituationAct(
                      story: _story,
                      speaking: _speaking,
                      onListen: () => _speak(_spokenLines(_story.openingLines)),
                      onContinue: _openJudgment,
                    ),
                    _StoryScene.judgment => _JudgmentAct(
                      story: _story,
                      speaking: _speaking,
                      onListen: () => _speak(_story.choiceLine.text),
                      options: _checkpoint.options,
                      selectedOptionId: _selectedOptionId,
                      onSelect: _selectOption,
                      onSubmit: _selectedOptionId == null
                          ? null
                          : _submitJudgment,
                    ),
                    _StoryScene.reaction => _ReactionAct(
                      story: _story,
                      response: _story.responseFor(_selectedOptionId!),
                      selectedText: _selectedOption?.text ?? '',
                      hint: _selectedOption?.hint,
                      selectedCorrect:
                          _selectedOptionId == _checkpoint.correctOptionId,
                      speaking: _speaking,
                      onListen: () => _speak(
                        _story.responseFor(_selectedOptionId!).line.text,
                      ),
                      onContinue: _openComparisonAfterReaction,
                    ),
                    _StoryScene.comparison => _ComparisonAct(
                      story: _story,
                      selectedText: _selectedOption?.text ?? '',
                      selectedCorrect:
                          _selectedOptionId == _checkpoint.correctOptionId,
                      outcome: _story.scientificResolution.outcome,
                      reason: _story.scientificResolution.reason,
                      correction: _correctOption?.text ?? '',
                      explanation: _checkpoint.explanation,
                      speaking: _speaking,
                      onListen: () => _speak(
                        _spokenLines([
                          ..._story.resolutionLines,
                          _story.punchline,
                        ]),
                      ),
                      onComplete: _complete,
                    ),
                    _StoryScene.complete => _CompleteAct(
                      onReturnToPath: _returnToPath,
                    ),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: context.gamePalette.canvas,
    );
  }
}

class _StoryHeader extends StatelessWidget {
  const _StoryHeader({
    required this.storyTitle,
    required this.conceptLabel,
    required this.stageLabel,
    required this.act,
    required this.reaction,
  });

  final String storyTitle;
  final String conceptLabel;
  final String stageLabel;
  final int act;
  final GameCharacterReaction reaction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    return Semantics(
      container: true,
      label:
          localize.t(
            '理科事件、3幕中$act。$storyTitle。$conceptLabel。$stageLabel。',
            'Science case, act $act. $storyTitle. $conceptLabel. $stageLabel. ',
          ) +
          localize.t(
            'デキすぎ君。${reaction.semanticsLabel}',
            'Dekisugi-kun. ${reaction.semanticsLabel}',
          ),
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
                    icon: Icons.auto_stories_rounded,
                    accent: context.gamePalette.story,
                    onAccent: context.gamePalette.onStory,
                    mascotReaction: reaction,
                  ),
                ),
                const SizedBox(height: GameTokens.spaceSm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        localize.t(
                          '理科事件  /  第$act幕・全3幕',
                          'SCIENCE CASE / ACT $act OF 3',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: colors.story)
                            .jaWeight(FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      stageLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.inkMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  storyTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.jaWeight(FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  conceptLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.inkMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (var index = 1; index <= 3; index++) ...[
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: index <= act
                                ? colors.story
                                : colors.pathLocked,
                            borderRadius: BorderRadius.circular(
                              GameTokens.radiusPill,
                            ),
                          ),
                        ),
                      ),
                      if (index < 3) const SizedBox(width: 6),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SituationAct extends StatelessWidget {
  const _SituationAct({
    required this.story,
    required this.speaking,
    required this.onListen,
    required this.onContinue,
  });

  final LocalScienceStory story;
  final bool speaking;
  final VoidCallback onListen;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return _ActLayout(
      key: const ValueKey('science-story-situation'),
      eyebrow: t('第1幕  /  事件発生', 'Act 1  /  The case'),
      title: story.title,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CaseSurface(text: story.setting),
          const SizedBox(height: 14),
          for (var index = 0; index < story.openingLines.length; index++) ...[
            _StoryLineSurface(story: story, line: story.openingLines[index]),
            if (index < story.openingLines.length - 1)
              const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
          _ListenButton(
            buttonKey: const ValueKey('science-story-listen-situation'),
            speaking: speaking,
            onPressed: onListen,
          ),
        ],
      ),
      action: _PrimaryAction(
        buttonKey: const ValueKey('science-story-open-judgment'),
        label: t('デキすぎ君の考えを聞く', 'Hear Dekisugi-kun\'s idea'),
        icon: Icons.arrow_forward,
        onPressed: onContinue,
      ),
    );
  }
}

class _JudgmentAct extends StatelessWidget {
  const _JudgmentAct({
    required this.story,
    required this.speaking,
    required this.onListen,
    required this.options,
    required this.selectedOptionId,
    required this.onSelect,
    required this.onSubmit,
  });

  final LocalScienceStory story;
  final bool speaking;
  final VoidCallback onListen;
  final List<LocalCheckpointOption> options;
  final String? selectedOptionId;
  final ValueChanged<String> onSelect;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return _ActLayout(
      key: const ValueKey('science-story-judgment'),
      eyebrow: t('第2幕  /  判断', 'Act 2  /  Decision'),
      title: t('デキすぎ君の説明を見破る', 'See through Dekisugi-kun\'s explanation'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StoryLineSurface(
            story: story,
            line: story.choiceLine,
            emphasized: true,
          ),
          const SizedBox(height: 12),
          _ListenButton(
            buttonKey: const ValueKey('science-story-listen-judgment'),
            speaking: speaking,
            onPressed: onListen,
          ),
          const SizedBox(height: 18),
          Text(
            t(
              'どの説明なら、観察と条件を結び付けられる？',
              'Which explanation connects the observation and the conditions?',
            ),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.jaWeight(FontWeight.w700),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < options.length; index++) ...[
            _StoryOptionButton(
              option: options[index],
              index: index,
              count: options.length,
              selected: options[index].id == selectedOptionId,
              onPressed: () => onSelect(options[index].id),
            ),
            if (index < options.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
      action: _PrimaryAction(
        buttonKey: const ValueKey('science-story-submit-judgment'),
        label: t('この判断で観察へ進む', 'Go to the observation with this choice'),
        icon: Icons.arrow_forward,
        onPressed: onSubmit,
      ),
    );
  }
}

class _ReactionAct extends StatelessWidget {
  const _ReactionAct({
    required this.story,
    required this.response,
    required this.selectedText,
    required this.hint,
    required this.selectedCorrect,
    required this.speaking,
    required this.onListen,
    required this.onContinue,
  });

  final LocalScienceStory story;
  final LocalScienceStoryChoiceResponse response;
  final String selectedText;
  final String? hint;
  final bool selectedCorrect;
  final bool speaking;
  final VoidCallback onListen;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    return _ActLayout(
      key: const ValueKey('science-story-reaction'),
      eyebrow: t('第2幕  /  人物の反応', 'Act 2  /  Reactions'),
      title: selectedCorrect
          ? t('その判断に、事件班がうなずいた', 'The case team nodded at your choice')
          : t('その判断に、事件班から待った', 'The case team said "wait" to your choice'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StoryLineSurface(
            story: story,
            line: response.line,
            emphasized: true,
          ),
          const SizedBox(height: 12),
          _ListenButton(
            buttonKey: const ValueKey('science-story-listen-reaction'),
            speaking: speaking,
            onPressed: onListen,
          ),
          const SizedBox(height: 14),
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
                  t('選んだ説明', 'Your chosen explanation'),
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: colors.ink)
                      .jaWeight(FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  selectedText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.ink,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    t('観察の手がかり', 'Observation clue'),
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: colors.ink)
                        .jaWeight(FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hint!,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: colors.ink)
                        .jaWeight(FontWeight.w700),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            selectedCorrect
                ? t(
                    'この反応のあと、観察結果と科学的な理由で判断を確かめます。',
                    'After this reaction, you\'ll check your choice with the observations and the scientific reason.',
                  )
                : t(
                    '残りの選択肢は順番に試しません。手がかりを使って、観察と教材の訂正を直接比べます。',
                    'You won\'t try the other options one by one. Use the clue to compare the observation directly with the material\'s correction.',
                  ),
            style: theme.textTheme.bodySmall?.copyWith(color: colors.inkMuted),
          ),
        ],
      ),
      action: _PrimaryAction(
        buttonKey: const ValueKey('science-story-reaction-to-comparison'),
        label: t('観察と訂正を比べる', 'Compare observation and correction'),
        icon: Icons.compare_arrows,
        onPressed: onContinue,
      ),
    );
  }
}

class _ComparisonAct extends StatelessWidget {
  const _ComparisonAct({
    required this.story,
    required this.selectedText,
    required this.selectedCorrect,
    required this.outcome,
    required this.reason,
    required this.correction,
    required this.explanation,
    required this.speaking,
    required this.onListen,
    required this.onComplete,
  });

  final LocalScienceStory story;
  final String selectedText;
  final bool selectedCorrect;
  final String outcome;
  final String reason;
  final String correction;
  final String explanation;
  final bool speaking;
  final VoidCallback onListen;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    return _ActLayout(
      key: const ValueKey('science-story-comparison'),
      eyebrow: t('第3幕  /  観察と訂正', 'Act 3  /  Observation and correction'),
      title: selectedCorrect
          ? t('判断を、観察で確かめる', 'Check your choice with the observation')
          : t(
              '判断と観察の違いに決着する',
              'Settle the gap between your choice and the observation',
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (
            var index = 0;
            index < story.resolutionLines.length;
            index++
          ) ...[
            _StoryLineSurface(story: story, line: story.resolutionLines[index]),
            if (index < story.resolutionLines.length - 1)
              const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
          _ComparisonSurface(
            key: const ValueKey('science-story-observation'),
            label: t('状況の観察', 'Observing the situation'),
            icon: Icons.visibility_outlined,
            color: colors.surfaceRaised,
            foreground: colors.ink,
            primary: outcome,
            secondary: reason,
          ),
          const SizedBox(height: 12),
          Semantics(
            container: true,
            label: t(
              '思い込みの直し方。$correction。$explanation',
              'How to fix the misconception. $correction. $explanation',
            ),
            child: ExcludeSemantics(
              child: _ComparisonSurface(
                key: const ValueKey('science-story-correction'),
                label: t('デキすぎ君への訂正', 'Correction for Dekisugi-kun'),
                icon: Icons.fact_check_outlined,
                color: colors.surfaceRaised,
                foreground: colors.ink,
                primary: correction,
                secondary: explanation,
              ),
            ),
          ),
          if (!selectedCorrect) ...[
            const SizedBox(height: 12),
            Text(
              t('最初の判断：$selectedText', 'First choice: $selectedText'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.inkMuted,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _StoryLineSurface(
            key: const ValueKey('science-story-punchline'),
            story: story,
            line: story.punchline,
            emphasized: true,
          ),
          const SizedBox(height: 12),
          _ListenButton(
            buttonKey: const ValueKey('science-story-listen-comparison'),
            speaking: speaking,
            onPressed: onListen,
          ),
        ],
      ),
      action: _PrimaryAction(
        buttonKey: const ValueKey('science-story-complete'),
        label: t('事件の記録を終える', 'Finish the story'),
        icon: Icons.check,
        onPressed: onComplete,
      ),
    );
  }
}

class _ListenButton extends StatelessWidget {
  const _ListenButton({
    required this.buttonKey,
    required this.speaking,
    required this.onPressed,
  });

  final Key buttonKey;
  final bool speaking;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    key: buttonKey,
    onPressed: speaking ? null : onPressed,
    icon: Icon(speaking ? Icons.graphic_eq_rounded : Icons.volume_up_outlined),
    label: Text(
      speaking
          ? t('読み上げ中…', 'Reading aloud…')
          : t('この場面を聞く', 'Listen to this scene'),
    ),
    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
  );
}

class _CompleteAct extends StatelessWidget {
  const _CompleteAct({required this.onReturnToPath});

  final VoidCallback onReturnToPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    return Column(
      children: [
        Semantics(
          key: const ValueKey('science-story-finished'),
          container: true,
          label: t(
            '理科事件完了。判断を観察と教材の訂正まで比べました。',
            'Science story complete. You compared your choice with the observation and the material\'s correction.',
          ),
          child: ExcludeSemantics(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 28),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 26),
              decoration: BoxDecoration(
                color: colors.surfaceRaised,
                borderRadius: BorderRadius.circular(GameTokens.radiusSheet),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    size: 40,
                    color: colors.ink,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    t('事件の記録を完了', 'Story complete'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(color: colors.ink)
                        .jaWeight(FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t(
                      '判断を、観察と教材の訂正まで比べました。',
                      'You compared your choice with the observation and the material\'s correction.',
                    ),
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
          key: const ValueKey('science-story-return-to-path'),
          onPressed: onReturnToPath,
          icon: const Icon(Icons.route_outlined),
          label: Text(t('探究ノートへ戻る', 'Back to the learning path')),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
          ),
        ),
      ],
    );
  }
}

class _ActLayout extends StatelessWidget {
  const _ActLayout({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.action,
  });

  final String eyebrow;
  final String title;
  final Widget body;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: theme.textTheme.labelMedium
              ?.copyWith(color: colors.story)
              .jaWeight(FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: theme.textTheme.headlineSmall?.jaWeight(FontWeight.w700),
        ),
        const SizedBox(height: 18),
        body,
        const SizedBox(height: 24),
        action,
      ],
    );
  }
}

class _StoryLineSurface extends StatelessWidget {
  const _StoryLineSurface({
    super.key,
    required this.story,
    required this.line,
    this.emphasized = false,
  });

  final LocalScienceStory story;
  final LocalScienceStoryLine line;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    final character = story.characterFor(line.speakerId);
    final (background, foreground, icon) = switch (line.speakerId) {
      'dekisugi' => (colors.story, colors.onStory, Icons.smart_toy_outlined),
      'mio' => (colors.surfaceRaised, colors.ink, Icons.science_outlined),
      _ => (colors.surface, colors.ink, Icons.edit_note_rounded),
    };
    return Semantics(
      container: true,
      label: '${character.name}。${line.text}',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(
              emphasized ? GameTokens.radiusSheet : GameTokens.radiusLg,
            ),
            border: line.speakerId == 'ren'
                ? Border.all(color: colors.border)
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: foreground.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(GameTokens.radiusSm),
                ),
                child: Icon(icon, color: foreground),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      character.name,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: foreground)
                          .jaWeight(FontWeight.w700),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '「${line.text}」',
                      style:
                          (emphasized
                                  ? theme.textTheme.bodyLarge
                                  : theme.textTheme.bodyMedium)
                              ?.copyWith(color: foreground)
                              .jaWeight(
                                emphasized ? FontWeight.w700 : FontWeight.w400,
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

class _CaseSurface extends StatelessWidget {
  const _CaseSurface({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 17),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(GameTokens.radiusLg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localize.t('事件の状況', "Case background"),
            style: theme.textTheme.labelMedium
                ?.copyWith(color: colors.story)
                .jaWeight(FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Text(text, style: theme.textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _StoryOptionButton extends StatelessWidget {
  const _StoryOptionButton({
    required this.option,
    required this.index,
    required this.count,
    required this.selected,
    required this.onPressed,
  });

  final LocalCheckpointOption option;
  final int index;
  final int count;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.gamePalette;
    return Semantics(
      button: true,
      selected: selected,
      label: t(
        '選択肢${index + 1}、全$count件中。${option.text}',
        'Option ${index + 1} of $count. ${option.text}',
      ),
      child: ExcludeSemantics(
        child: OutlinedButton(
          key: ValueKey('science-story-option-${option.id}'),
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            foregroundColor: colors.ink,
            backgroundColor: selected ? colors.surfaceRaised : colors.surface,
            side: BorderSide(
              color: selected ? colors.story : colors.inkMuted,
              width: selected ? 2 : 1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(GameTokens.radiusMd),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 22,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  option.text,
                  style: theme.textTheme.bodyMedium?.jaWeight(FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComparisonSurface extends StatelessWidget {
  const _ComparisonSurface({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.foreground,
    required this.primary,
    required this.secondary,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color foreground;
  final String primary;
  final String secondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(GameTokens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 21, color: foreground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: foreground)
                      .jaWeight(FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            primary,
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: foreground)
                .jaWeight(FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            secondary,
            style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.buttonKey,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      key: buttonKey,
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GameTokens.radiusMd),
        ),
      ),
    );
  }
}
