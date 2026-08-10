import '../../models/unit.dart';
import '../domain/learning_event.dart';
import '../domain/learning_progress.dart';

/// Repair Hubが起動する、catalog正本に対応できた構造課題の種類。
enum LearningRepairActivityKind {
  practice,
  listening,
  notationOrder,
  notationSymbol,
  notationGraph,
}

/// Repair対象になった理由。active needは期限復習より常に先に並ぶ。
enum LearningRepairReason { activeNeed, due }

/// 回答や選択肢を含まない、Repair画面を開くための最小target。
final class LearningRepairTarget {
  const LearningRepairTarget({
    required this.reason,
    required this.activityKind,
    required this.unitId,
    required this.conceptKey,
    required this.skillId,
    required this.practiceAttempt,
    this.needCode,
  });

  final LearningRepairReason reason;
  final LearningRepairActivityKind activityKind;
  final String unitId;
  final String conceptKey;
  final String skillId;

  /// active needだけが持つcatalog固定コード。回答・選択肢IDではない。
  final String? needCode;

  /// practice variantを決定する既存の巡回index。Notationでは0。
  final int practiceAttempt;

  /// Homeがexact repair成功eventへそのまま渡す、回答を含まないmetadata。
  LearningRepairResolution get resolutionMetadata {
    final code = needCode;
    if (reason != LearningRepairReason.activeNeed || code == null) {
      throw StateError('due target cannot resolve an active need');
    }
    return LearningRepairResolution(
      unitId: unitId,
      conceptKey: conceptKey,
      skillId: skillId,
      needCode: code,
      routeKind: switch (activityKind) {
        LearningRepairActivityKind.practice => LearningRepairRouteKind.practice,
        LearningRepairActivityKind.listening =>
          LearningRepairRouteKind.listening,
        LearningRepairActivityKind.notationOrder =>
          LearningRepairRouteKind.notationOrder,
        LearningRepairActivityKind.notationSymbol =>
          LearningRepairRouteKind.notationSymbol,
        LearningRepairActivityKind.notationGraph =>
          LearningRepairRouteKind.notationGraph,
      },
      practiceAttempt: practiceAttempt,
    );
  }
}

/// 未知コードを課題へ推測変換せずに返す、fail-closedな計画結果。
final class LearningRepairPlan {
  const LearningRepairPlan({
    required this.targets,
    required this.unmappedActiveNeeds,
    required this.unmappedDueSkillIds,
  });

  final List<LearningRepairTarget> targets;
  final List<LearningActiveNeed> unmappedActiveNeeds;
  final List<String> unmappedDueSkillIds;
}

/// active needと期限到来skillを、同じcatalog正本からRepair順へ投影する。
final class LearningRepairPlanner {
  const LearningRepairPlanner();

  LearningRepairPlan build({
    required LearningProgressSnapshot snapshot,
    required Iterable<UnitDetail> catalog,
    required String today,
  }) {
    _requireLearningDay(today);
    final index = _RepairCatalogIndex.build(catalog);
    final targets = <LearningRepairTarget>[];
    final unmappedNeeds = <LearningActiveNeed>[];
    final mappedNeedSkills = <String>{};

    final needs = [...snapshot.activeNeeds]
      ..sort((left, right) {
        final day = left.firstObservedDay.compareTo(right.firstObservedDay);
        if (day != 0) return day;
        final skill = left.skillId.compareTo(right.skillId);
        if (skill != 0) return skill;
        return left.needCode.compareTo(right.needCode);
      });
    for (final need in needs) {
      final entry = need.scope == snapshot.scope
          ? index.byNeed[_needKey(need.skillId, need.needCode)]
          : null;
      if (entry == null) {
        unmappedNeeds.add(need);
        continue;
      }
      mappedNeedSkills.add(need.skillId);
      targets.add(
        LearningRepairTarget(
          reason: LearningRepairReason.activeNeed,
          activityKind: entry.activityKind,
          unitId: entry.unitId,
          conceptKey: entry.conceptKey,
          skillId: need.skillId,
          needCode: need.needCode,
          practiceAttempt: entry.practiceAttempt,
        ),
      );
    }

    final dueSkills =
        snapshot.skills
            .where(
              (skill) =>
                  skill.scope == snapshot.scope &&
                  (skill.lastOutcome == LearningSkillOutcome.needsPractice ||
                      skill.nextDueDay.compareTo(today) <= 0),
            )
            .toList()
          ..sort((left, right) {
            final day = left.nextDueDay.compareTo(right.nextDueDay);
            if (day != 0) return day;
            return left.skillId.compareTo(right.skillId);
          });
    final unmappedDueSkills = <String>[];
    for (final skill in dueSkills) {
      if (mappedNeedSkills.contains(skill.skillId)) continue;
      final entry = index.bySkill[skill.skillId];
      if (entry == null) {
        unmappedDueSkills.add(skill.skillId);
        continue;
      }
      targets.add(
        LearningRepairTarget(
          reason: LearningRepairReason.due,
          activityKind: LearningRepairActivityKind.practice,
          unitId: entry.unitId,
          conceptKey: entry.conceptKey,
          skillId: skill.skillId,
          practiceAttempt: skill.successfulRetrievals,
        ),
      );
    }

    return LearningRepairPlan(
      targets: List.unmodifiable(targets),
      unmappedActiveNeeds: List.unmodifiable(unmappedNeeds),
      unmappedDueSkillIds: List.unmodifiable(unmappedDueSkills),
    );
  }
}

final class _RepairCatalogIndex {
  const _RepairCatalogIndex({required this.byNeed, required this.bySkill});

  factory _RepairCatalogIndex.build(Iterable<UnitDetail> catalog) {
    final byNeed = <String, _RepairCatalogEntry>{};
    final conflictedNeeds = <String>{};
    final bySkill = <String, _RepairCatalogEntry>{};
    final conflictedSkills = <String>{};

    void addNeed(String skillId, String? needCode, _RepairCatalogEntry entry) {
      if (needCode == null ||
          conflictedNeeds.contains(_needKey(skillId, needCode))) {
        return;
      }
      final key = _needKey(skillId, needCode);
      final previous = byNeed[key];
      if (previous != null && !previous.sameTarget(entry)) {
        byNeed.remove(key);
        conflictedNeeds.add(key);
        return;
      }
      byNeed[key] = entry;
    }

    for (final unit in catalog) {
      for (final section in unit.sections) {
        final skillId = '${unit.id}/${section.conceptKey}';
        if (section.localPracticeVariants.length !=
                LocalPracticeStage.values.length ||
            section.notationLab == null) {
          conflictedSkills.add(skillId);
          bySkill.remove(skillId);
          continue;
        }
        final dueEntry = _RepairCatalogEntry(
          unitId: unit.id,
          conceptKey: section.conceptKey,
          activityKind: LearningRepairActivityKind.practice,
          practiceAttempt: 0,
        );
        if (bySkill.containsKey(skillId)) {
          bySkill.remove(skillId);
          conflictedSkills.add(skillId);
        } else if (!conflictedSkills.contains(skillId)) {
          bySkill[skillId] = dueEntry;
        }

        for (
          var index = 0;
          index < section.localPracticeVariants.length;
          index++
        ) {
          final variant = section.localPracticeVariants[index];
          final expected =
              'science.${section.conceptKey}.${variant.stage.wire}';
          if (variant.cognitiveTask.needCode != expected ||
              variant.checkpoint.options.any(
                (option) => option.id == variant.checkpoint.correctOptionId
                    ? option.needCode != null
                    : option.needCode != expected,
              )) {
            continue;
          }
          addNeed(
            skillId,
            expected,
            _RepairCatalogEntry(
              unitId: unit.id,
              conceptKey: section.conceptKey,
              activityKind: LearningRepairActivityKind.practice,
              practiceAttempt: index,
            ),
          );

          final listening = variant.listeningNeedCodes;
          final listeningPrefix =
              'science.${section.conceptKey}.listening.${variant.stage.wire}';
          if (listening != null &&
              listening.transcript == '$listeningPrefix.transcript' &&
              listening.meaning == '$listeningPrefix.meaning') {
            final listeningEntry = _RepairCatalogEntry(
              unitId: unit.id,
              conceptKey: section.conceptKey,
              activityKind: LearningRepairActivityKind.listening,
              practiceAttempt: index,
            );
            addNeed(skillId, listening.transcript, listeningEntry);
            addNeed(skillId, listening.meaning, listeningEntry);
          }
        }

        final notation = section.notationLab!;
        for (final task in notation.orderTasks) {
          addNeed(
            skillId,
            task.needCode,
            _RepairCatalogEntry(
              unitId: unit.id,
              conceptKey: section.conceptKey,
              activityKind: LearningRepairActivityKind.notationOrder,
              practiceAttempt: 0,
            ),
          );
        }
        addNeed(
          skillId,
          notation.symbolMatch.needCode,
          _RepairCatalogEntry(
            unitId: unit.id,
            conceptKey: section.conceptKey,
            activityKind: LearningRepairActivityKind.notationSymbol,
            practiceAttempt: 0,
          ),
        );
        addNeed(
          skillId,
          notation.graphRead.needCode,
          _RepairCatalogEntry(
            unitId: unit.id,
            conceptKey: section.conceptKey,
            activityKind: LearningRepairActivityKind.notationGraph,
            practiceAttempt: 0,
          ),
        );
      }
    }
    for (final skillId in conflictedSkills) {
      bySkill.remove(skillId);
      byNeed.removeWhere((key, _) => key.startsWith('$skillId\u0000'));
    }
    return _RepairCatalogIndex(
      byNeed: Map.unmodifiable(byNeed),
      bySkill: Map.unmodifiable(bySkill),
    );
  }

  final Map<String, _RepairCatalogEntry> byNeed;
  final Map<String, _RepairCatalogEntry> bySkill;
}

final class _RepairCatalogEntry {
  const _RepairCatalogEntry({
    required this.unitId,
    required this.conceptKey,
    required this.activityKind,
    required this.practiceAttempt,
  });

  final String unitId;
  final String conceptKey;
  final LearningRepairActivityKind activityKind;
  final int practiceAttempt;

  bool sameTarget(_RepairCatalogEntry other) =>
      unitId == other.unitId &&
      conceptKey == other.conceptKey &&
      activityKind == other.activityKind &&
      practiceAttempt == other.practiceAttempt;
}

String _needKey(String skillId, String needCode) => '$skillId\u0000$needCode';

void _requireLearningDay(String day) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(day);
  if (match == null) {
    throw ArgumentError.value(day, 'today', 'YYYY-MM-DD only');
  }
  final parsed = DateTime.utc(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
  final normalized =
      '${parsed.year.toString().padLeft(4, '0')}-'
      '${parsed.month.toString().padLeft(2, '0')}-'
      '${parsed.day.toString().padLeft(2, '0')}';
  if (normalized != day) {
    throw ArgumentError.value(day, 'today', 'valid calendar day required');
  }
}
