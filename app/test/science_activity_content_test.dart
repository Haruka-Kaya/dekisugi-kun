import 'package:dekisugi/learning/services/science_activity_content.dart';
import 'package:dekisugi/models/unit.dart';
import 'package:dekisugi/screens/science_notation_lab_screen.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:dekisugi/services/units_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Matchはcanonical対応を保ったまま全23concept・3variantの正答位置を分散する', () async {
    final client = UnitsClient(baseUrl: '', store: MemorySessionStore());
    final summaries = await client.list();
    var conceptCount = 0;
    final presentationSignatures = <String>{};

    for (final summary in summaries) {
      final detail = (await client.detail(summary.id))!;
      for (final section in detail.sections) {
        conceptCount++;
        final positionsByPair = <String, Set<int>>{
          'observation': <int>{},
          'reasoning': <int>{},
          'correction': <int>{},
        };

        for (
          var attempt = 0;
          attempt < LocalPracticeStage.values.length;
          attempt++
        ) {
          final variant = section.practiceVariantForAttempt(attempt);
          final first = ScienceActivityContent.matchFor(
            section,
            practiceAttempt: attempt,
          );
          final second = ScienceActivityContent.matchFor(
            section,
            practiceAttempt: attempt,
          );
          expect(
            second.targets.map((target) => (target.id, target.text)),
            first.targets.map((target) => (target.id, target.text)),
            reason: '${section.conceptKey}/${variant.stage.wire}: 非決定的',
          );
          final correctOption = variant.checkpoint.optionFor(
            variant.checkpoint.correctOptionId,
          )!;
          expect(
            {for (final target in first.targets) target.id: target.text},
            {
              'outcome': variant.expectedOutcome,
              'reason': variant.expectedReason,
              'correction': correctOption.text,
            },
          );
          expect(first.pairs.map((pair) => pair.needCode).toSet(), {
            variant.cognitiveTask.needCode,
          });
          expect(
            {for (final pair in first.pairs) pair.id: pair.correctTargetId},
            const {
              'observation': 'outcome',
              'reasoning': 'reason',
              'correction': 'correction',
            },
          );
          for (final pair in first.pairs) {
            positionsByPair[pair.id]!.add(
              first.targets.indexWhere(
                (target) => target.id == pair.correctTargetId,
              ),
            );
          }
          presentationSignatures.add(
            first.targets.map((target) => target.id).join('>'),
          );
        }

        for (final entry in positionsByPair.entries) {
          expect(entry.value, {
            0,
            1,
            2,
          }, reason: '${section.conceptKey}/${entry.key}: 正答位置が巡回しない');
        }
      }
    }

    expect(conceptCount, 23);
    expect(
      presentationSignatures.length,
      3,
      reason: '固定3→1→2の位置戦略を全variantへ再利用できてしまう',
    );
  });

  test('Matchは未知concept・不足variantを教材内容から推測せず拒否する', () async {
    final client = UnitsClient(baseUrl: '', store: MemorySessionStore());
    final detail = (await client.detail((await client.list()).first.id))!;
    final source = detail.sections.first;
    Section clone({required String conceptKey, required variants}) => Section(
      conceptKey: conceptKey,
      title: source.title,
      body: source.body,
      tryIt: source.tryIt,
      localCheckpoint: source.localCheckpoint,
      localSpeakingPractice: source.localSpeakingPractice,
      localPracticeVariants: variants,
      notationLab: source.notationLab,
      scienceStory: source.scienceStory,
    );

    expect(
      () => ScienceActivityContent.matchFor(
        clone(
          conceptKey: 'unknown-concept',
          variants: source.localPracticeVariants,
        ),
        practiceAttempt: 0,
      ),
      throwsStateError,
    );
    expect(
      () => ScienceActivityContent.matchFor(
        clone(
          conceptKey: source.conceptKey,
          variants: source.localPracticeVariants.take(2).toList(),
        ),
        practiceAttempt: 0,
      ),
      throwsStateError,
    );
    expect(
      () => ScienceActivityContent.matchFor(source, practiceAttempt: -1),
      throwsStateError,
    );
  });

  test('同梱catalogの全23concept・80 task・22 traceをUIへ損失なく変換する', () async {
    final client = UnitsClient(baseUrl: '', store: MemorySessionStore());
    final summaries = await client.list();
    var count = 0;
    var taskCount = 0;
    var traceCount = 0;
    final taskKinds = <LocalNotationTaskKind>{};

    for (final summary in summaries) {
      final detail = await client.detail(summary.id);
      expect(detail, isNotNull, reason: summary.id);
      for (final concept in summary.concepts) {
        count++;
        final section = detail!.sectionFor(concept.key);
        expect(section, isNotNull, reason: '${summary.id}/${concept.key}');
        final source = section!.notationLab;
        final converted = ScienceActivityContent.notationFor(section);
        expect(source, isNotNull, reason: '${summary.id}/${concept.key}');
        expect(converted, isNotNull, reason: '${summary.id}/${concept.key}');

        expect(converted!.tasks.length, source!.tasks.length);
        for (var index = 0; index < source.tasks.length; index++) {
          final left = converted.tasks[index];
          final right = source.tasks[index];
          taskCount++;
          taskKinds.add(right.kind);
          expect(left.id, right.id);
          expect(left.kind, right.kind);
          expect(left.title, right.title);
          expect(left.prompt, right.prompt);
          expect(left.solutionSummary, right.solutionSummary);
          expect(left.needCode, right.needCode);
          switch ((left, right)) {
            case (
              ScienceNotationArrangeTask left,
              LocalNotationArrangeTask right,
            ):
              expect(left.guide, right.guide);
              expect(
                left.tokens.map((token) => (token.id, token.label)),
                right.tokens.map((token) => (token.id, token.label)),
              );
              expect(left.correctOrderIds, right.correctOrderIds);
              expect(left.tracePattern == null, right.tracePattern == null);
              final rightTrace = right.tracePattern;
              final leftTrace = left.tracePattern;
              if (rightTrace == null || leftTrace == null) break;
              traceCount++;
              expect(leftTrace.semanticsLabel, rightTrace.semanticsLabel);
              expect(leftTrace.strokeOrderIds, rightTrace.strokeOrderIds);
              expect(leftTrace.strokes.length, rightTrace.strokes.length);
              for (
                var strokeIndex = 0;
                strokeIndex < rightTrace.strokes.length;
                strokeIndex++
              ) {
                final convertedStroke = leftTrace.strokes[strokeIndex];
                final sourceStroke = rightTrace.strokes[strokeIndex];
                expect(convertedStroke.id, sourceStroke.id);
                expect(convertedStroke.label, sourceStroke.label);
                expect(
                  convertedStroke.points.map((point) => [point.x, point.y]),
                  sourceStroke.points.map((point) => [point.x, point.y]),
                );
              }
            case (
              ScienceNotationChoiceTask left,
              LocalNotationChoiceTask right,
            ):
              expect(left.representation, right.representation);
              expect(
                left.representationSemanticsLabel,
                right.representationSemanticsLabel,
              );
              expect(
                left.choices.map((choice) => (choice.id, choice.label)),
                right.choices.map((choice) => (choice.id, choice.label)),
              );
              expect(left.correctChoiceId, right.correctChoiceId);
            default:
              fail('${summary.id}/${concept.key}/$index: task型が変わった');
          }
        }
      }
    }

    expect(count, 23);
    expect(taskCount, 80);
    expect(traceCount, 22);
    expect(taskKinds, LocalNotationTaskKind.values.toSet());
  });

  test('正本を持たない未知conceptへ式や単位を推測しない', () async {
    final client = UnitsClient(baseUrl: '', store: MemorySessionStore());
    final firstSummary = (await client.list()).first;
    final detail = (await client.detail(firstSummary.id))!;
    final source = detail.sections.first;
    final unknown = Section(
      conceptKey: 'unknown-concept',
      title: source.title,
      body: source.body,
      tryIt: source.tryIt,
      localCheckpoint: source.localCheckpoint,
      localPracticeVariants: source.localPracticeVariants,
    );

    expect(ScienceActivityContent.notationFor(unknown), isNull);
  });
}
