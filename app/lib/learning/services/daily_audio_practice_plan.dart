import '../../models/game_path.dart';
import '../../models/unit.dart';
import '../domain/learning_event.dart';
import '../domain/learning_progress.dart';
import 'game_path_projection.dart';

enum DailyAudioMissionKind { listening, speaking }

/// その学習日に出す音声練習の参照だけを持つ。
///
/// 教材本文・正答・録音・自由記述は持たず、起動時にcatalog detailを読み直す。
final class DailyAudioMission {
  const DailyAudioMission({
    required this.nodeId,
    required this.unitId,
    required this.conceptKey,
    required this.conceptLabel,
    required this.kind,
    required this.practiceAttempt,
    required this.completedToday,
  });

  final String nodeId;
  final String unitId;
  final String conceptKey;
  final String conceptLabel;
  final DailyAudioMissionKind kind;
  final int practiceAttempt;

  /// 同じ4時区切りの学習日に、この固定node/activityを完了したか。
  ///
  /// 回答・選択肢・録音からは推測せず、保存済み学習eventだけから投影する。
  final bool completedToday;
}

final class DailyAudioPracticePlan {
  const DailyAudioPracticePlan({
    required this.learningDay,
    required this.missions,
  });

  final String learningDay;
  final List<DailyAudioMission> missions;

  DailyAudioMission? missionOf(DailyAudioMissionKind kind) {
    for (final mission in missions) {
      if (mission.kind == kind) return mission;
    }
    return null;
  }
}

/// Pathで実際に到達した概念から、聞く課題と話す課題を1件ずつ選ぶ。
///
/// 同じ学習日は常に同じ課題を返す。候補が複数あれば学習日ごとに巡回し、
/// 未解放nodeを日次練習から先取りしない。
final class DailyAudioPracticePlanner {
  const DailyAudioPracticePlanner();

  DailyAudioPracticePlan build({
    required List<UnitSummary> catalog,
    required GamePathViewData path,
    required LearningProgressSnapshot snapshot,
    required String learningDay,
  }) {
    final day = _parseLearningDay(learningDay);
    final nodesById = {
      for (final unit in path.units)
        for (final node in unit.nodes) node.id: node,
    };
    final missions = <DailyAudioMission>[];

    for (final kind in DailyAudioMissionKind.values) {
      final candidates = <_AudioCandidate>[];
      for (final unit in catalog) {
        for (final concept in unit.concepts) {
          final pathKind = switch (kind) {
            DailyAudioMissionKind.listening => GamePathNodeKind.listening,
            DailyAudioMissionKind.speaking => GamePathNodeKind.speaking,
          };
          final nodeId = GamePathProjection.nodeId(
            unit.id,
            concept.key,
            pathKind,
          );
          final node = nodesById[nodeId];
          if (node == null || !node.canOpen) continue;
          candidates.add(
            _AudioCandidate(
              unitId: unit.id,
              conceptKey: concept.key,
              conceptLabel: concept.label,
              node: node,
            ),
          );
        }
      }
      if (candidates.isEmpty) continue;

      final completedToday = candidates
          .where(
            (candidate) => _completedToday(
              snapshot: snapshot,
              candidate: candidate,
              kind: kind,
              learningDay: learningDay,
            ),
          )
          .toList(growable: false);
      // 新しく進めるnodeを、完了済みの再演より先に出す。
      // ただし今日すでに完了したnodeがあれば同じmissionを保ち、完了直後に
      // 別nodeへ差し替わって「未完了」に戻らないようにする。
      final active = completedToday.isEmpty
          ? candidates
                .where((candidate) => !_isCompleted(candidate.node.state))
                .toList(growable: false)
          : const <_AudioCandidate>[];
      final pool = completedToday.isNotEmpty
          ? completedToday
          : active.isEmpty
          ? candidates
          : active;
      final selected = pool[_dayOrdinal(day) % pool.length];
      missions.add(
        DailyAudioMission(
          nodeId: selected.node.id,
          unitId: selected.unitId,
          conceptKey: selected.conceptKey,
          conceptLabel: selected.conceptLabel,
          kind: kind,
          practiceAttempt: _practiceAttempt(day, selected.node.id),
          completedToday: completedToday.contains(selected),
        ),
      );
    }

    return DailyAudioPracticePlan(
      learningDay: learningDay,
      missions: List.unmodifiable(missions),
    );
  }

  static bool _isCompleted(GamePathNodeState state) =>
      state == GamePathNodeState.completed ||
      state == GamePathNodeState.legendaryCompleted;

  static bool _completedToday({
    required LearningProgressSnapshot snapshot,
    required _AudioCandidate candidate,
    required DailyAudioMissionKind kind,
    required String learningDay,
  }) {
    final expectedActivityId = switch (kind) {
      DailyAudioMissionKind.listening => 'path.listening.v1',
      DailyAudioMissionKind.speaking => 'path.speaking.v1',
    };
    final expectedActivityKind = switch (kind) {
      DailyAudioMissionKind.listening => LearningActivityKind.listen,
      DailyAudioMissionKind.speaking => LearningActivityKind.speak,
    };
    return snapshot.events.any(
      (event) =>
          event.scope == snapshot.scope &&
          event.learningDay == learningDay &&
          event.nodeId == candidate.node.id &&
          event.activityId == expectedActivityId &&
          event.activityKind == expectedActivityKind &&
          event.outcome != LearningAttemptOutcome.retryNeeded &&
          event.evidence.rank >= LearningEvidenceLevel.selfCompared.rank,
    );
  }

  static DateTime _parseLearningDay(String value) {
    final match = RegExp(r'^\d{4}-\d{2}-\d{2}$').firstMatch(value);
    if (match == null) throw ArgumentError.value(value, 'learningDay');
    final parsed = DateTime.tryParse('${value}T00:00:00Z');
    if (parsed == null || _formatDay(parsed) != value) {
      throw ArgumentError.value(value, 'learningDay');
    }
    return parsed;
  }

  static int _dayOrdinal(DateTime day) =>
      day.difference(DateTime.utc(1970)).inDays;

  static int _practiceAttempt(DateTime day, String nodeId) {
    var hash = _dayOrdinal(day) & 0x7fffffff;
    for (final codeUnit in nodeId.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x7fffffff;
    }
    return hash % 3;
  }

  static String _formatDay(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

final class _AudioCandidate {
  const _AudioCandidate({
    required this.unitId,
    required this.conceptKey,
    required this.conceptLabel,
    required this.node,
  });

  final String unitId;
  final String conceptKey;
  final String conceptLabel;
  final GamePathNode node;
}
