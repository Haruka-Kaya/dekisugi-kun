import 'dossier.dart';

/// 教材を読んだあと、どこから説明を組み立てるか。
///
/// 正解を選ばせるものではなく、想起の足場を本人に選んでもらう。
/// 選択が会話画面まで残ることで、教材を読む行為がミッションの準備になる。
enum TeachingTactic {
  example,
  reason,
  experiment;

  /// サーバと共有する公開API値。既存セッションの保存値でもあるため改名しない。
  String get wire => name;

  String get label => switch (this) {
    TeachingTactic.example => '身近な例から',
    TeachingTactic.reason => 'しくみ・理由から',
    TeachingTactic.experiment => '試したことから',
  };

  String get hint => switch (this) {
    TeachingTactic.example => '「たとえば…」から、身近な場面で説明する',
    TeachingTactic.reason => '結論のあとに「なぜなら…」を続ける',
    TeachingTactic.experiment => 'やってみたことと、その結果から説明する',
  };
}

/// 同じ概念に、どの認知課題として挑むか。
///
/// 見た目の難易度ではなく、実際に要求する学習行為を変える。
/// wire値は端末保存とAPIの双方で使うため、既存値を改名しないこと。
enum MissionKind {
  /// 教材を読んだあと、自分の言葉で初めて教える。
  teach,

  /// 前回決着しなかった説明を組み直す。
  repair,

  /// 後日、具体場面へ知識を使えるか教材の答えを見ずに確かめる。
  caseRetry;

  String get wire => name;

  static MissionKind parse(Object? value) => switch (value) {
    'repair' => MissionKind.repair,
    'caseRetry' => MissionKind.caseRetry,
    _ => MissionKind.teach,
  };
}

/// 1概念の教えるミッション。
///
/// XPや見かけの進捗ではなく、Dossierに残った本人の発話と誤概念への反応だけで
/// 進む。したがって画面を操作しただけではclearにならない。
enum MissionPhase { teach, challenge, resolve, clear }

class MissionSnapshot {
  const MissionSnapshot({required this.phase, required this.slot});

  final MissionPhase phase;
  final Slot? slot;

  /// UI上は3段階。resolveは最終段階の再挑戦で、失敗段階を増やさない。
  int get step => switch (phase) {
    MissionPhase.teach => 1,
    MissionPhase.challenge => 2,
    MissionPhase.resolve || MissionPhase.clear => 3,
  };

  bool get isClear => phase == MissionPhase.clear;
}

/// 現在のカルテから、画面に出すミッション段階を導く。
///
/// [lastLureId] は、誤概念を出す指示が届いた直後（まだ次のDossier更新前）にも
/// チャレンジ表示へ進めるために使う。clearは必ず`corrected`という観測が必要。
MissionSnapshot missionSnapshotFor({
  required String conceptKey,
  required Dossier? dossier,
  String? lastLureId,
}) {
  Slot? target;
  for (final slot in dossier?.slots ?? const <Slot>[]) {
    if (slot.key == conceptKey) {
      target = slot;
      break;
    }
  }

  final probes = target?.probes ?? const <Probe>[];
  final corrected = probes.any(
    (probe) => probe.result == ProbeResult.corrected,
  );
  // 誤概念を否定できただけでは、概念を説明できたことにならない。
  // CASEでも「場面と原理を結びつけた説明」と「根拠付き訂正」の両方が
  // 揃って初めてclearにする。
  if (target?.isExplained == true && corrected) {
    return MissionSnapshot(phase: MissionPhase.clear, slot: target);
  }
  if (corrected) {
    return MissionSnapshot(phase: MissionPhase.resolve, slot: target);
  }
  if (probes.any((probe) => probe.result == ProbeResult.accepted)) {
    return MissionSnapshot(phase: MissionPhase.resolve, slot: target);
  }
  final challengeStarted =
      lastLureId != null ||
      probes.any((probe) => probe.result == ProbeResult.unclear) ||
      target?.isExplained == true;
  return MissionSnapshot(
    phase: challengeStarted ? MissionPhase.challenge : MissionPhase.teach,
    slot: target,
  );
}
