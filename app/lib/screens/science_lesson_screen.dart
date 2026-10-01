import '../config/app_language.dart';
import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../models/game_path.dart';
import '../models/unit.dart';
import '../ui/_material.dart';
import '../widgets/emphasis_text.dart';
import '../widgets/readable_width.dart';
import '../widgets/science_challenge_support.dart';

enum _LessonStep { predict, read, compare, complete }

enum _LessonDecision { keep, revise }

/// Path上の文字学習。予想→本文→自己比較の順で、答えの先出しを防ぐ。
///
/// 自由記述はrouteのStateだけに置き、保存・送信・自動採点を行わない。
class ScienceLessonScreen extends StatefulWidget {
  const ScienceLessonScreen({
    super.key,
    required this.section,
    required this.conceptLabel,
    required this.practiceAttempt,
    required this.onCompleted,
    this.onReturnToPath,
  }) : assert(practiceAttempt >= 0);

  final Section section;
  final String conceptLabel;
  final int practiceAttempt;
  final VoidCallback onCompleted;
  final VoidCallback? onReturnToPath;

  @override
  State<ScienceLessonScreen> createState() => _ScienceLessonScreenState();
}

class _ScienceLessonScreenState extends State<ScienceLessonScreen> {
  final _prediction = TextEditingController();
  final _reflection = TextEditingController();
  final _scroll = ScrollController();
  _LessonStep _step = _LessonStep.predict;
  _LessonDecision? _decision;
  String? _submittedPrediction;
  bool _completionCalled = false;

  LocalPracticeVariant get _variant =>
      widget.section.practiceVariantForAttempt(widget.practiceAttempt);

  @override
  void initState() {
    super.initState();
    _prediction.addListener(_changed);
    _reflection.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _prediction.removeListener(_changed);
    _reflection.removeListener(_changed);
    _prediction.clear();
    _reflection.clear();
    _prediction.dispose();
    _reflection.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _openText() {
    final value = _prediction.text.trim();
    if (_step != _LessonStep.predict || value.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _submittedPrediction = value;
      _step = _LessonStep.read;
    });
    _top();
  }

  void _openComparison() {
    if (_step != _LessonStep.read) return;
    setState(() => _step = _LessonStep.compare);
    _top();
  }

  void _complete() {
    if (_step != _LessonStep.compare ||
        _decision == null ||
        _reflection.text.trim().isEmpty ||
        _completionCalled) {
      return;
    }
    _completionCalled = true;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _step = _LessonStep.complete);
    widget.onCompleted();
    _top();
  }

  void _top() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.jumpTo(0);
    });
  }

  void _returnToPath() {
    final callback = widget.onReturnToPath;
    if (callback != null) {
      callback();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_step.index + 1) / _LessonStep.values.length;
    return Scaffold(
      backgroundColor: context.gamePalette.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: ReadableWidth(
                tight: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox.square(
                      dimension: GameTokens.heroLeadingSize,
                      child: ScienceActivityMascotBadge(
                        icon: Icons.menu_book_rounded,
                        accent: context.gamePalette.pathActive,
                        onAccent: context.gamePalette.onPathActive,
                        mascotReaction: switch (_step) {
                          _LessonStep.predict => GameCharacterReaction.thinking,
                          _LessonStep.read || _LessonStep.compare =>
                            GameCharacterReaction.encourage,
                          _LessonStep.complete =>
                            GameCharacterReaction.celebrate,
                        },
                      ),
                    ),
                    const SizedBox(width: GameTokens.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TEXT LAB  /  ${widget.conceptLabel}',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: context.gamePalette.pathActive,
                                )
                                .jaWeight(FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Semantics(
                            label: t(
                              '文字学習、4段階中${_step.index + 1}',
                              'Reading lesson, step ${_step.index + 1} of 4',
                            ),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(
                                GameTokens.radiusPill,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                key: const ValueKey('science-lesson-scroll'),
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  ReadableWidth(
                    child: switch (_step) {
                      _LessonStep.predict => _PredictionStep(
                        prompt: _variant.recallPrompt,
                        controller: _prediction,
                        onContinue: _prediction.text.trim().isEmpty
                            ? null
                            : _openText,
                      ),
                      _LessonStep.read => _ReadingStep(
                        section: widget.section,
                        onContinue: _openComparison,
                      ),
                      _LessonStep.compare => _ComparisonStep(
                        prediction: _submittedPrediction ?? '',
                        section: widget.section,
                        decision: _decision,
                        reflection: _reflection,
                        onDecision: (value) =>
                            setState(() => _decision = value),
                        onComplete:
                            _decision != null &&
                                _reflection.text.trim().isNotEmpty
                            ? _complete
                            : null,
                      ),
                      _LessonStep.complete => _LessonComplete(
                        onReturnToPath: _returnToPath,
                      ),
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PredictionStep extends StatelessWidget {
  const _PredictionStep({
    required this.prompt,
    required this.controller,
    required this.onContinue,
  });

  final String prompt;
  final TextEditingController controller;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) => _LessonLayout(
    eyebrow: t('STEP 1  /  答えを見る前に', 'STEP 1  /  Before the answer'),
    title: t('まず、自分の予想を置く。', 'First, make your prediction.'),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Surface(
          label: t('今回の問い', 'Today\'s question'),
          text: prompt,
          interpretEmphasis: true,
        ),
        const SizedBox(height: 12),
        const _TeachBackNotice(),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('science-lesson-prediction'),
          controller: controller,
          minLines: 3,
          maxLines: 5,
          maxLength: 240,
          decoration: InputDecoration(
            labelText: t(
              '読む前の予想（1文以上）',
              'Your prediction before reading (1+ sentences)',
            ),
            hintText: t('いま考えていることを書く', 'Write what you\'re thinking now'),
          ),
        ),
        const SizedBox(height: 8),
        const _LocalOnlyNote(),
      ],
    ),
    action: FilledButton(
      key: const ValueKey('science-lesson-reveal'),
      onPressed: onContinue,
      child: Text(t('予想を置いて、教材を読む', 'Save prediction and read')),
    ),
  );
}

class _TeachBackNotice extends StatelessWidget {
  const _TeachBackNotice();

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: t(
      'この教材のあと、デキすぎ君へ理由と条件を自分の言葉で説明します',
      'After this material, you\'ll explain the reasons and conditions to Dekisugi-kun in your own words',
    ),
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.all(GameTokens.spaceMd),
        decoration: BoxDecoration(
          color: context.gamePalette.surfaceRaised,
          borderRadius: BorderRadius.circular(GameTokens.radiusMd),
          border: Border.all(color: context.gamePalette.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.record_voice_over_rounded,
              size: GameTokens.statusIconSize,
              color: context.gamePalette.pathActive,
            ),
            const SizedBox(width: GameTokens.spaceSm),
            Expanded(
              child: Text(
                t(
                  'このあと、デキすぎ君へ説明します。答えだけでなく「なぜ」と「どんな条件で」を拾ってください。',
                  'Next, you\'ll explain this to Dekisugi-kun. Look for not just the answer, but "why" and "under what conditions."',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.gamePalette.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ReadingStep extends StatelessWidget {
  const _ReadingStep({required this.section, required this.onContinue});

  final Section section;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => _LessonLayout(
    eyebrow: 'STEP 2  /  TEXT',
    title: section.title,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final paragraph in section.body) ...[
          EmphasisText(paragraph, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
        ],
        _Surface(
          label: t('手を動かすなら', 'Try it hands-on'),
          text: section.tryIt,
          interpretEmphasis: true,
        ),
      ],
    ),
    action: FilledButton(
      key: const ValueKey('science-lesson-compare'),
      onPressed: onContinue,
      child: Text(t('最初の予想と比べる', 'Compare with your first prediction')),
    ),
  );
}

class _ComparisonStep extends StatelessWidget {
  const _ComparisonStep({
    required this.prediction,
    required this.section,
    required this.decision,
    required this.reflection,
    required this.onDecision,
    required this.onComplete,
  });

  final String prediction;
  final Section section;
  final _LessonDecision? decision;
  final TextEditingController reflection;
  final ValueChanged<_LessonDecision> onDecision;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) => _LessonLayout(
    eyebrow: 'STEP 3  /  SELF COMPARE',
    title: t('予想を、教材の要点と比べる。', 'Compare your prediction with the key points.'),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Surface(
          label: t('読む前の予想', 'Your prediction before reading'),
          text: prediction,
        ),
        const SizedBox(height: 10),
        _Surface(
          label: t('教材で確かめたこと', 'What the material showed'),
          text: section.body.join('\n\n'),
          interpretEmphasis: true,
        ),
        const SizedBox(height: 18),
        SegmentedButton<_LessonDecision>(
          segments: [
            ButtonSegment(
              value: _LessonDecision.keep,
              label: Text(t('残す点', 'Keep')),
              icon: const Icon(Icons.add_task),
            ),
            ButtonSegment(
              value: _LessonDecision.revise,
              label: Text(t('直す点', 'Fix')),
              icon: const Icon(Icons.edit_note),
            ),
          ],
          selected: {?decision},
          emptySelectionAllowed: true,
          onSelectionChanged: (values) {
            if (values.isNotEmpty) onDecision(values.single);
          },
        ),
        const SizedBox(height: 15),
        TextField(
          key: const ValueKey('science-lesson-reflection'),
          controller: reflection,
          minLines: 2,
          maxLines: 4,
          maxLength: 200,
          decoration: InputDecoration(
            labelText: t('比べて気づいたこと（1文）', 'What you noticed (1 sentence)'),
            hintText: t(
              '予想に残す点、または直す点を書く',
              'Write what to keep or fix in your prediction',
            ),
          ),
        ),
      ],
    ),
    action: FilledButton(
      key: const ValueKey('science-lesson-complete'),
      onPressed: onComplete,
      child: Text(t('文字学習を完了する', 'Finish reading lesson')),
    ),
  );
}

class _LessonComplete extends StatelessWidget {
  const _LessonComplete({required this.onReturnToPath});

  final VoidCallback onReturnToPath;

  @override
  Widget build(BuildContext context) => Semantics(
    key: const ValueKey('science-lesson-finished'),
    container: true,
    label: t(
      '文字学習完了。読む前の予想を教材と比べました。',
      'Reading lesson complete. You compared your prediction with the material.',
    ),
    child: ExcludeSemantics(
      child: _LessonLayout(
        eyebrow: 'TEXT CLEAR',
        title: t('予想と本文を、比べ終えた。', 'Prediction and material compared.'),
        body: const _LocalOnlyNote(),
        action: FilledButton.icon(
          key: const ValueKey('science-lesson-return'),
          onPressed: onReturnToPath,
          icon: const Icon(Icons.route),
          label: Text(t('学習パスへ戻る', 'Back to learning path')),
        ),
      ),
    ),
  );
}

class _LessonLayout extends StatelessWidget {
  const _LessonLayout({
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        eyebrow,
        style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: context.gamePalette.pathActive)
            .jaWeight(FontWeight.w800),
      ),
      const SizedBox(height: 7),
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.jaWeight(FontWeight.w900),
      ),
      const SizedBox(height: 20),
      body,
      const SizedBox(height: 24),
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: GameTokens.minTouchTarget),
        child: action,
      ),
    ],
  );
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.label,
    required this.text,
    this.interpretEmphasis = false,
  });

  final String label;
  final String text;
  final bool interpretEmphasis;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.gamePalette.surface,
      borderRadius: BorderRadius.circular(GameTokens.radiusMd),
      border: Border.all(color: context.gamePalette.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.jaWeight(FontWeight.w800),
        ),
        const SizedBox(height: 7),
        if (interpretEmphasis) EmphasisText(text) else Text(text),
      ],
    ),
  );
}

class _LocalOnlyNote extends StatelessWidget {
  const _LocalOnlyNote();

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: t(
      '入力はこの画面だけで使い、保存も送信も自動採点もしません',
      'Your input is used only on this screen. It is not saved, sent, or auto-graded',
    ),
    child: ExcludeSemantics(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.phonelink_lock_outlined,
            size: 20,
            color: context.gamePalette.inkMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t(
                '入力は保存・送信・自動採点しません。',
                'Input is not saved, sent, or auto-graded.',
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
