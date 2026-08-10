import 'dart:convert';
import 'dart:io';

import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/learning/domain/learning_progress.dart';
import 'package:dekisugi/learning/services/learning_repair_planner.dart';
import 'package:dekisugi/models/unit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<UnitDetail> catalog;
  late UnitDetail firstUnit;
  late Section firstSection;
  late Section secondSection;

  setUpAll(() async {
    final root =
        jsonDecode(await File('assets/catalog/units.ja.json').readAsString())
            as Map<String, Object?>;
    expect(root['schemaVersion'], 9);
    catalog = [
      for (final raw in root['units']! as List)
        UnitDetail.fromJson((raw as Map).cast<String, Object?>())!,
    ];
    firstUnit = catalog.firstWhere((unit) => unit.sections.length >= 2);
    firstSection = firstUnit.sections.first;
    secondSection = firstUnit.sections[1];
  });

  test('catalog対応済みactive needをdueより先にし、未知値は推測しない', () {
    final firstSkill = '${firstUnit.id}/${firstSection.conceptKey}';
    final secondSkill = '${firstUnit.id}/${secondSection.conceptKey}';
    final practiceCode =
        firstSection.localPracticeVariants.first.cognitiveTask.needCode!;
    final notationCode = firstSection.notationLab!.graphRead.needCode!;
    final snapshot = _snapshot(
      scope: LearningScope.personal,
      activeNeeds: [
        _need(firstSkill, notationCode, day: '2026-08-10'),
        _need(firstSkill, practiceCode, day: '2026-08-09'),
        _need(firstSkill, 'science.${firstSection.conceptKey}.unknown'),
        _need(firstSkill, practiceCode, scope: LearningScope.schoolLocal),
      ],
      skills: [
        _skill(firstSkill, nextDueDay: '2026-08-01'),
        _skill(secondSkill, nextDueDay: '2026-08-10', successfulRetrievals: 4),
        _skill('unknown/skill', nextDueDay: '2026-08-01'),
      ],
    );

    final plan = const LearningRepairPlanner().build(
      snapshot: snapshot,
      catalog: catalog,
      today: '2026-08-10',
    );

    expect(plan.targets, hasLength(3));
    expect(plan.targets[0].reason, LearningRepairReason.activeNeed);
    expect(plan.targets[0].needCode, practiceCode);
    expect(plan.targets[0].activityKind, LearningRepairActivityKind.practice);
    expect(plan.targets[0].practiceAttempt, 0);
    expect(
      plan.targets[0].resolutionMetadata.routeKind,
      LearningRepairRouteKind.practice,
    );
    expect(plan.targets[1].reason, LearningRepairReason.activeNeed);
    expect(plan.targets[1].needCode, notationCode);
    expect(
      plan.targets[1].activityKind,
      LearningRepairActivityKind.notationGraph,
    );
    expect(plan.targets[2].reason, LearningRepairReason.due);
    expect(plan.targets[2].skillId, secondSkill);
    expect(plan.targets[2].practiceAttempt, 4);
    expect(
      () => plan.targets[2].resolutionMetadata,
      throwsStateError,
      reason: '期限復習はactive need tombstoneを作れない',
    );
    expect(
      plan.targets.where((target) => target.skillId == firstSkill),
      hasLength(2),
    );
    expect(plan.unmappedActiveNeeds, hasLength(2));
    expect(plan.unmappedDueSkillIds, ['unknown/skill']);
  });

  test('school snapshotはschool needだけを同じ端末内catalogへ対応させる', () {
    final skillId = '${firstUnit.id}/${firstSection.conceptKey}';
    final needCode =
        firstSection.localPracticeVariants.last.cognitiveTask.needCode!;
    final plan = const LearningRepairPlanner().build(
      snapshot: _snapshot(
        scope: LearningScope.schoolLocal,
        activeNeeds: [
          _need(skillId, needCode, scope: LearningScope.schoolLocal),
          _need(skillId, needCode),
        ],
      ),
      catalog: catalog,
      today: '2026-08-10',
    );

    expect(plan.targets.single.skillId, skillId);
    expect(plan.targets.single.needCode, needCode);
    expect(plan.unmappedActiveNeeds.single.scope, LearningScope.personal);
  });

  test('Listening専用needを同じconcept×stageのListeningへ戻し、未知codeは拒否する', () {
    final skillId = '${firstUnit.id}/${firstSection.conceptKey}';
    final variant = firstSection.localPracticeVariants[1];
    final listening = variant.listeningNeedCodes!;
    final plan = const LearningRepairPlanner().build(
      snapshot: _snapshot(
        scope: LearningScope.personal,
        activeNeeds: [
          _need(skillId, listening.transcript),
          _need(skillId, listening.meaning),
          _need(
            skillId,
            'science.${firstSection.conceptKey}.listening.conditions.unknown',
          ),
        ],
      ),
      catalog: catalog,
      today: '2026-08-10',
    );

    expect(plan.targets, hasLength(2));
    for (final target in plan.targets) {
      expect(target.activityKind, LearningRepairActivityKind.listening);
      expect(target.skillId, skillId);
      expect(target.practiceAttempt, 1);
      expect(
        target.resolutionMetadata.routeKind,
        LearningRepairRouteKind.listening,
      );
      expect(target.resolutionMetadata.needCode, target.needCode);
    }
    expect(plan.targets.map((target) => target.needCode).toSet(), {
      listening.transcript,
      listening.meaning,
    });
    expect(plan.unmappedActiveNeeds, hasLength(1));
    expect(plan.unmappedActiveNeeds.single.needCode, endsWith('.unknown'));
  });

  test('不正なtodayを黙って期限判定に使わない', () {
    expect(
      () => const LearningRepairPlanner().build(
        snapshot: _snapshot(scope: LearningScope.personal),
        catalog: catalog,
        today: '2026-02-30',
      ),
      throwsArgumentError,
    );
  });
}

LearningProgressSnapshot _snapshot({
  required LearningScope scope,
  List<LearningActiveNeed> activeNeeds = const [],
  List<LearningSkillProgress> skills = const [],
}) => LearningProgressSnapshot(
  scope: scope,
  events: const [],
  nodes: const [],
  skills: skills,
  days: const [],
  freezes: const [],
  challengeHearts: scope == LearningScope.personal
      ? const LearningChallengeHeartState.initial()
      : null,
  rewards: const [],
  quests: const [],
  runs: const [],
  activeNeeds: activeNeeds,
);

LearningActiveNeed _need(
  String skillId,
  String needCode, {
  LearningScope scope = LearningScope.personal,
  String day = '2026-08-10',
}) => LearningActiveNeed(
  scope: scope,
  skillId: skillId,
  needCode: needCode,
  firstObservedDay: day,
  lastObservedDay: day,
  lastObservedAt: DateTime.parse('${day}T12:00:00'),
);

LearningSkillProgress _skill(
  String skillId, {
  required String nextDueDay,
  int successfulRetrievals = 0,
}) => LearningSkillProgress(
  scope: LearningScope.personal,
  skillId: skillId,
  lastOutcome: LearningSkillOutcome.completed,
  successfulRetrievals: successfulRetrievals,
  lastAttemptDay: '2026-08-01',
  lastSuccessDay: '2026-08-01',
  nextDueDay: nextDueDay,
  lastEventId: 'event.fixture',
);
