import '../../models/unit.dart';
import '../../config/app_language.dart';
import '../../screens/science_lightning_screen.dart';
import '../../screens/science_match_lab_screen.dart';
import '../../screens/science_notation_lab_screen.dart';

/// catalog v10の固定教材を、回答を画面Stateの外へ出さないゲーム課題へ変換する。
final class ScienceActivityContent {
  const ScienceActivityContent._();

  /// Sectionにparse済みのNotation正本が無ければ、概念キーから推測せずnullへ倒す。
  ///
  /// 変換は全fieldを1対1で写すだけで、式・単位・正答・表示順を作り足さない。
  static ScienceNotationLabContent? notationFor(Section section) {
    final source = section.notationLab;
    if (source == null) return null;
    return ScienceNotationLabContent.tagged(
      tasks: [for (final task in source.tasks) _notationTask(task)],
    );
  }

  static ScienceNotationTask _notationTask(LocalNotationTask task) =>
      switch (task) {
        LocalNotationArrangeTask() => ScienceNotationArrangeTask(
          kind: task.kind,
          id: task.id,
          title: task.title,
          prompt: task.prompt,
          solutionSummary: task.solutionSummary,
          guide: task.guide,
          tracePattern: _tracePattern(task.tracePattern),
          tokens: [
            for (final token in task.tokens)
              ScienceNotationToken(id: token.id, label: token.label),
          ],
          correctOrderIds: [...task.correctOrderIds],
          needCode: task.needCode,
        ),
        LocalNotationChoiceTask() => ScienceNotationChoiceTask(
          kind: task.kind,
          id: task.id,
          title: task.title,
          prompt: task.prompt,
          solutionSummary: task.solutionSummary,
          representation: [...task.representation],
          representationSemanticsLabel: task.representationSemanticsLabel,
          choices: [
            for (final choice in task.choices)
              ScienceNotationChoice(id: choice.id, label: choice.label),
          ],
          correctChoiceId: task.correctChoiceId,
          needCode: task.needCode,
        ),
      };

  static ScienceNotationTracePattern? _tracePattern(
    LocalNotationTracePattern? source,
  ) => source == null
      ? null
      : ScienceNotationTracePattern(
          semanticsLabel: source.semanticsLabel,
          strokes: [
            for (final stroke in source.strokes)
              ScienceNotationTraceStroke(
                id: stroke.id,
                label: stroke.label,
                points: [
                  for (final point in stroke.points)
                    ScienceNotationTracePoint(x: point.x, y: point.y),
                ],
              ),
          ],
          strokeOrderIds: [...source.strokeOrderIds],
        );

  static ScienceMatchLabContent matchFor(
    Section section, {
    required int practiceAttempt,
  }) {
    if (practiceAttempt < 0 ||
        section.localPracticeVariants.length !=
            LocalPracticeStage.values.length) {
      throw StateError(
        'catalog Match requires exactly three canonical variants',
      );
    }
    final variant = section.practiceVariantForAttempt(practiceAttempt);
    final needCode = variant.cognitiveTask.needCode;
    final expectedNeedCode =
        'science.${section.conceptKey}.${variant.stage.wire}';
    if (needCode == null || needCode != expectedNeedCode) {
      throw StateError('catalog Match task has no canonical needCode');
    }
    final correction = variant.checkpoint.optionFor(
      variant.checkpoint.correctOptionId,
    );
    if (correction == null ||
        correction.needCode != null ||
        variant.checkpoint.options.any(
          (option) => option.id == variant.checkpoint.correctOptionId
              ? option.needCode != null
              : option.needCode != expectedNeedCode,
        )) {
      throw StateError('catalog Match checkpoint is not canonical');
    }
    final canonicalPairs = [
      ScienceMatchPair(
        id: 'observation',
        concept: t('観察した結果', 'What you observed'),
        correctTargetId: 'outcome',
        needCode: '',
      ),
      ScienceMatchPair(
        id: 'reasoning',
        concept: t('結果を支える理由', 'The reason behind the result'),
        correctTargetId: 'reason',
        needCode: '',
      ),
      ScienceMatchPair(
        id: 'correction',
        concept: t('思い込みの訂正', 'Fixing the misconception'),
        correctTargetId: 'correction',
        needCode: '',
      ),
    ];
    final canonicalTargets = [
      ScienceMatchTarget(id: 'reason', text: variant.expectedReason),
      ScienceMatchTarget(id: 'correction', text: correction.text),
      ScienceMatchTarget(id: 'outcome', text: variant.expectedOutcome),
    ];
    if (canonicalTargets.any((target) => target.text.trim().isEmpty) ||
        canonicalTargets.map((target) => target.text).toSet().length !=
            canonicalTargets.length) {
      throw StateError('catalog Match targets must be distinct and non-empty');
    }
    final presentationTargets = _rotateForMatchPresentation(
      canonicalTargets,
      conceptKey: section.conceptKey,
      stage: variant.stage,
    );
    return ScienceMatchLabContent(
      pairs: [
        for (final pair in canonicalPairs)
          ScienceMatchPair(
            id: pair.id,
            concept: pair.concept,
            correctTargetId: pair.correctTargetId,
            needCode: needCode,
          ),
      ],
      targets: presentationTargets,
      timeLimit: const Duration(seconds: 45),
    );
  }

  static ScienceLightningContent lightningFor(Section section) {
    return ScienceLightningContent(
      questions: [
        for (
          var index = 0;
          index < section.localPracticeVariants.length;
          index++
        )
          _lightningQuestion(section.localPracticeVariants[index], index),
      ],
      timeLimit: const Duration(seconds: 50),
    );
  }

  static ScienceLightningQuestion _lightningQuestion(
    LocalPracticeVariant variant,
    int index,
  ) {
    final checkpoint = variant.checkpoint;
    return ScienceLightningQuestion(
      id: 'round-${index + 1}',
      prompt: '${variant.stage.label}：${checkpoint.lure}',
      options: [
        for (final option in checkpoint.options)
          ScienceLightningOption(id: option.id, text: option.text),
      ],
      correctOptionId: checkpoint.correctOptionId,
      needCode: checkpoint.options
          .where((option) => option.id != checkpoint.correctOptionId)
          .map((option) => option.needCode)
          .nonNulls
          .firstOrNull,
    );
  }
}

/// Matchの表示順だけを、保存不要なcatalog IDから決定論的に回転する。
///
/// 各conceptの3 stageは必ず異なるrotationを通るため、従来の固定
/// `3 -> 1 -> 2` を内容を読まず再利用できない。Dartの`hashCode`はruntime間の
/// 安定性を契約しないため使わず、UTF-16 code unitから同じ32-bit値を作る。
List<T> _rotateForMatchPresentation<T>(
  List<T> canonical, {
  required String conceptKey,
  required LocalPracticeStage stage,
}) {
  if (canonical.length != LocalPracticeStage.values.length ||
      conceptKey.trim().isEmpty) {
    throw StateError('canonical Match presentation IDs are required');
  }
  var hash = 0x811c9dc5;
  for (final codeUnit in conceptKey.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  final offset = ((hash % canonical.length) + stage.index) % canonical.length;
  return List<T>.unmodifiable([
    for (var index = 0; index < canonical.length; index++)
      canonical[(index + offset) % canonical.length],
  ]);
}
