import 'mission.dart';
import 'unit.dart';
import '../config/app_language.dart';

/// 板書コードで固定する授業ラウンド。
///
/// 端末履歴から選ばない。教師と全生徒が同じコードを入力したとき、同じ教材、
/// prompt、checkpointになるための公開契約。
enum ClassroomRound {
  a(
    code: 'A',
    practiceAttempt: 0,
    labelJa: '原理を思い出す',
    labelEn: 'Recall the principle',
  ),
  b(
    code: 'B',
    practiceAttempt: 1,
    labelJa: '条件を見分ける',
    labelEn: 'Tell the conditions apart',
  ),
  c(
    code: 'C',
    practiceAttempt: 2,
    labelJa: '別の場面へ使う',
    labelEn: 'Apply it to a new situation',
  );

  const ClassroomRound({
    required this.code,
    required this.practiceAttempt,
    required this._labelJa,
    required this._labelEn,
  });

  final String code;
  final int practiceAttempt;
  final String _labelJa;
  final String _labelEn;

  String get label => t(_labelJa, _labelEn);

  /// Aは本文から初めて説明する。B/Cは答えを見せず、指定場面へ適用する。
  MissionKind get missionKind => switch (this) {
    ClassroomRound.a => MissionKind.teach,
    ClassroomRound.b || ClassroomRound.c => MissionKind.caseRetry,
  };

  LocalPracticeStage get practiceStage =>
      LocalPracticeStage.values[practiceAttempt];

  static ClassroomRound? fromPracticeAttempt(int value) => switch (value) {
    0 => ClassroomRound.a,
    1 => ClassroomRound.b,
    2 => ClassroomRound.c,
    _ => null,
  };
}

/// 教師と生徒が同じ教材を指すための、カタログ内の位置。
///
/// 学校・学級を識別するコードではない。アプリ同梱教材の順番を
/// `01-02` のように短く表しただけで、外部照合や通信は行わない。
/// 実際の授業コードは、これに [ClassroomRound] のA/B/Cを必ず付ける。
class ClassroomMission {
  const ClassroomMission({
    required this.unit,
    required this.conceptKey,
    required this.conceptLabel,
    required this.unitNumber,
    required this.conceptNumber,
  });

  final UnitSummary unit;
  final String conceptKey;
  final String conceptLabel;
  final int unitNumber;
  final int conceptNumber;

  String get id => '${unit.id}/$conceptKey';

  String get materialNumber =>
      '${unitNumber.toString().padLeft(2, '0')}-'
      '${conceptNumber.toString().padLeft(2, '0')}';

  static List<ClassroomMission> fromUnits(List<UnitSummary> units) => [
    for (var unitIndex = 0; unitIndex < units.length; unitIndex++)
      for (
        var conceptIndex = 0;
        conceptIndex < units[unitIndex].concepts.length;
        conceptIndex++
      )
        ClassroomMission(
          unit: units[unitIndex],
          conceptKey: units[unitIndex].concepts[conceptIndex].key,
          conceptLabel: units[unitIndex].concepts[conceptIndex].label,
          unitNumber: unitIndex + 1,
          conceptNumber: conceptIndex + 1,
        ),
  ];

  static ClassroomMission? findById(
    List<ClassroomMission> missions, {
    required String unitId,
    required String conceptKey,
  }) {
    for (final mission in missions) {
      if (mission.unit.id == unitId && mission.conceptKey == conceptKey) {
        return mission;
      }
    }
    return null;
  }
}

/// 1つの概念と1つのroundを固定した、授業中の実際の課題。
class ClassroomAssignment {
  const ClassroomAssignment({required this.mission, required this.round});

  final ClassroomMission mission;
  final ClassroomRound round;

  String get id => '${mission.id}/$practiceAttempt';
  String get classroomCode => '${mission.materialNumber}-${round.code}';

  /// 教室内だけで配る教材番号のQR payload。
  ///
  /// 学校・学級・生徒・端末を識別せず、LANの参加コードとも混同しない。
  String get classroomQrPayload => 'DKSC1:$classroomCode';
  int get practiceAttempt => round.practiceAttempt;
  MissionKind get missionKind => round.missionKind;

  LocalPracticeVariant variantFor(Section section) =>
      section.practiceVariantForAttempt(practiceAttempt);

  static List<ClassroomAssignment> fromMissions(
    List<ClassroomMission> missions,
  ) => [
    for (final mission in missions)
      for (final round in ClassroomRound.values)
        ClassroomAssignment(mission: mission, round: round),
  ];

  static ClassroomAssignment? findByClassroomCode(
    List<ClassroomMission> missions,
    String input,
  ) {
    final normalized = normalizeClassroomCode(input);
    if (normalized == null) return null;
    for (final assignment in fromMissions(missions)) {
      if (assignment.classroomCode == normalized) return assignment;
    }
    return null;
  }

  static ClassroomAssignment? findByRun(
    List<ClassroomMission> missions, {
    required String unitId,
    required String conceptKey,
    required int practiceAttempt,
  }) {
    final mission = ClassroomMission.findById(
      missions,
      unitId: unitId,
      conceptKey: conceptKey,
    );
    final round = ClassroomRound.fromPracticeAttempt(practiceAttempt);
    if (mission == null || round == null) return null;
    return ClassroomAssignment(mission: mission, round: round);
  }

  /// 板書を日本語キーボードで入力しても同じ授業コードとして扱う。
  ///
  /// `1-2-a` / `０１ー０２ーＡ` / `01 02 b` を正規形へそろえる。
  /// roundの無い旧`01-02`は、端末履歴で課題が変わるため受け付けない。
  static String? normalizeClassroomCode(String input) {
    const fullWidthDigits = '０１２３４５６７８９';
    final buffer = StringBuffer();
    for (final rune in input.trim().runes) {
      final char = String.fromCharCode(rune);
      final digit = fullWidthDigits.indexOf(char);
      if (digit >= 0) {
        buffer.write(digit);
      } else if ('-ー−―‐‑‒–—―'.contains(char) || char.trim().isEmpty) {
        buffer.write('-');
      } else if (char == 'Ａ' || char == 'Ｂ' || char == 'Ｃ') {
        buffer.write(switch (char) {
          'Ａ' => 'A',
          'Ｂ' => 'B',
          _ => 'C',
        });
      } else {
        buffer.write(char.toUpperCase());
      }
    }

    final compact = buffer.toString().replaceAll(RegExp('-+'), '-');
    final match = RegExp(r'^(\d{1,2})-(\d{1,2})-([ABC])$').firstMatch(compact);
    if (match == null) return null;
    final unit = int.tryParse(match.group(1)!);
    final concept = int.tryParse(match.group(2)!);
    if (unit == null || concept == null || unit < 1 || concept < 1) {
      return null;
    }
    return '${unit.toString().padLeft(2, '0')}-'
        '${concept.toString().padLeft(2, '0')}-${match.group(3)!}';
  }

  /// [classroomQrPayload]から教材番号だけを取り出す。
  ///
  /// QRを読んだだけでは教材を開始しない。画面側で概念名を確認してから
  /// 「この教材を開く」を明示的に押す。
  static String? classroomCodeFromQrPayload(String input) {
    const prefix = 'DKSC1:';
    if (!input.trim().toUpperCase().startsWith(prefix)) return null;
    return normalizeClassroomCode(input.trim().substring(prefix.length));
  }
}
