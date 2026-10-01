import 'package:dekisugi/learning/domain/learning_need.dart';
import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('同じrunの有限訂正は観測needを保持し即解消へ変換しない', () {
    final buffer = LearningNeedEvidenceBuffer();
    buffer.record(
      LearningNeedEvidence(
        conceptKey: 'fall',
        needCode: 'science.fall.foundation',
        kind: LearningNeedEvidenceKind.observed,
      ),
    );
    buffer.record(
      LearningNeedEvidence(
        conceptKey: 'fall',
        needCode: 'science.fall.foundation',
        kind: LearningNeedEvidenceKind.demonstrated,
      ),
    );

    expect(buffer.observedBySkill('force-motion'), {
      'force-motion/fall': {'science.fall.foundation'},
    });
    expect(buffer.demonstratedBySkill('force-motion'), isEmpty);
  });

  test('誤りの無い構造成功は一般化needだけを解消mapへ変換する', () {
    final buffer = LearningNeedEvidenceBuffer();
    buffer.record(
      LearningNeedEvidence(
        conceptKey: 'fall',
        needCode: 'science.fall.conditions',
        kind: LearningNeedEvidenceKind.demonstrated,
      ),
    );

    expect(buffer.observedBySkill('force-motion'), isEmpty);
    expect(buffer.demonstratedBySkill('force-motion'), {
      'force-motion/fall': {'science.fall.conditions'},
    });
  });

  test('構造成功でないeventや同時観測からneed解消を捏造できない', () {
    LearningEventCommand command({
      required LearningAttemptOutcome outcome,
      required LearningEvidenceLevel evidence,
      Map<String, Iterable<String>> observed = const {},
    }) => LearningEventCommand(
      eventId: 'event.need.validation',
      scope: LearningScope.personal,
      origin: LearningOrigin.practice,
      courseId: 'course.jhs-science',
      nodeId: 'node.repair',
      activityId: 'activity.repair.v1',
      skillIds: const {'force-motion/fall'},
      activityKind: LearningActivityKind.diagram,
      outcome: outcome,
      evidence: evidence,
      contentVersion: 'catalog.v6',
      learningDay: '2026-08-10',
      occurredAt: DateTime.utc(2026, 8, 10, 12),
      practiceNeedCodes: observed,
      resolvedPracticeNeedCodes: const {
        'force-motion/fall': {'science.fall.foundation'},
      },
    );

    expect(
      () => command(
        outcome: LearningAttemptOutcome.corrected,
        evidence: LearningEvidenceLevel.structuredCorrection,
      ),
      throwsArgumentError,
    );
    expect(
      () => command(
        outcome: LearningAttemptOutcome.structuredSuccess,
        evidence: LearningEvidenceLevel.selfCompared,
      ),
      throwsArgumentError,
    );
    expect(
      () => command(
        outcome: LearningAttemptOutcome.structuredSuccess,
        evidence: LearningEvidenceLevel.structuredCorrection,
        observed: const {
          'force-motion/fall': {'science.fall.foundation'},
        },
      ),
      throwsArgumentError,
    );
  });

  test('exact Repair metadataと一致するpractice成功だけがneed解消を受理される', () {
    final metadata = LearningRepairResolution(
      unitId: 'force-motion',
      conceptKey: 'fall',
      skillId: 'force-motion/fall',
      needCode: 'science.fall.listening.conditions.transcript',
      routeKind: LearningRepairRouteKind.listening,
      practiceAttempt: 1,
    );
    LearningEventCommand command({
      LearningOrigin origin = LearningOrigin.practice,
      LearningActivityKind activityKind = LearningActivityKind.listen,
      LearningRepairResolution? repairResolution,
    }) => LearningEventCommand(
      eventId: 'event.need.exact-repair',
      scope: LearningScope.personal,
      origin: origin,
      courseId: 'course.jhs-science',
      nodeId: 'node.repair.listening',
      activityId: 'activity.repair.listening.v1',
      skillIds: const {'force-motion/fall'},
      activityKind: activityKind,
      outcome: LearningAttemptOutcome.structuredSuccess,
      evidence: LearningEvidenceLevel.structuredCorrection,
      contentVersion: 'catalog.v9',
      learningDay: '2026-08-10',
      occurredAt: DateTime.utc(2026, 8, 10, 12),
      resolvedPracticeNeedCodes: const {
        'force-motion/fall': {'science.fall.listening.conditions.transcript'},
      },
      repairResolution: repairResolution,
    );

    expect(() => command(repairResolution: metadata), returnsNormally);
    expect(() => command(), throwsArgumentError);
    expect(
      () => command(origin: LearningOrigin.path, repairResolution: metadata),
      throwsArgumentError,
    );
    expect(
      () => command(
        activityKind: LearningActivityKind.diagram,
        repairResolution: metadata,
      ),
      throwsArgumentError,
    );
    expect(
      () => LearningRepairResolution(
        unitId: 'force-motion',
        conceptKey: 'fall',
        skillId: 'force-motion/fall',
        needCode: 'science.fall.listening.transfer.transcript',
        routeKind: LearningRepairRouteKind.listening,
        practiceAttempt: 1,
      ),
      throwsArgumentError,
    );
  });

  test('空値・異なるconcept・回答らしい文字列をneed evidenceにできない', () {
    expect(
      () => LearningNeedEvidence(
        conceptKey: '',
        needCode: 'science.fall.foundation',
        kind: LearningNeedEvidenceKind.observed,
      ),
      throwsArgumentError,
    );
    expect(
      () => LearningNeedEvidence(
        conceptKey: 'fall',
        needCode: 'science.inertia.foundation',
        kind: LearningNeedEvidenceKind.observed,
      ),
      throwsArgumentError,
    );
    expect(
      () => LearningNeedEvidence(
        conceptKey: 'fall',
        needCode: '選択肢Aを選んだ',
        kind: LearningNeedEvidenceKind.observed,
      ),
      throwsArgumentError,
    );
  });
}
