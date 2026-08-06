/// 理解カルテ。サーバの `server/lib/dossier.ts` と1対1で対応する。
///
/// **状態を持つのは端末**で、サーバはリクエストごとにこれを受け取って返すだけ。
/// DB もセッションも要らない。
library;

/// 生徒がその概念を説明できたか。
enum SlotStatus {
  untouched,
  thin,
  explained;

  static SlotStatus parse(Object? v) => switch (v) {
        'thin' => SlotStatus.thin,
        'explained' => SlotStatus.explained,
        // 知らない値は「まだ触れていない」に倒す。
        // explained 側に倒すと、説明していないものを説明済みとして扱ってしまう
        _ => SlotStatus.untouched,
      };

  String get wire => name;
}

/// 誤概念を誘発した結果。**正誤の採点ではなく行動の観測。**
enum ProbeResult {
  notTried,
  unclear,
  corrected,
  accepted;

  static ProbeResult parse(Object? v) => switch (v) {
        'unclear' => ProbeResult.unclear,
        'corrected' => ProbeResult.corrected,
        'accepted' => ProbeResult.accepted,
        // 知らない値を accepted に倒さないこと。
        // accepted は「誤解している」という強い主張で、間違えると
        // 触れてもいない誤解を弱点として突きつけることになる
        _ => ProbeResult.notTried,
      };

  String get wire => name;
}

class Probe {
  const Probe({
    required this.id,
    required this.result,
    required this.evidence,
    this.countered = false,
  });

  final String id;
  final ProbeResult result;

  /// 判断の根拠になった生徒の発話ID
  final List<String> evidence;

  /// 訂正できなかったあと、正しい内容を差し出し済みか
  final bool countered;

  factory Probe.fromJson(Map<String, dynamic> json) => Probe(
        id: json['id'] as String? ?? '',
        result: ProbeResult.parse(json['result']),
        evidence: _strings(json['evidence']),
        countered: json['countered'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'result': result.wire,
        'evidence': evidence,
        'countered': countered,
      };
}

class Slot {
  const Slot({
    required this.key,
    required this.label,
    required this.status,
    required this.content,
    required this.evidence,
    required this.followUpHint,
    required this.probes,
  });

  final String key;

  /// 画面に出す名前。端末に単元カタログを持たせないためサーバが入れてくる
  final String label;
  final SlotStatus status;

  /// 生徒が説明した内容（校正済み）
  final String content;
  final List<String> evidence;
  final String followUpHint;
  final List<Probe> probes;

  /// 根拠が無いなら、status が何であれ埋まっていない。
  /// サーバ側でも同じ計算をしているが、**表示のたびに端末でも守る**。
  bool get isEmpty => evidence.isEmpty || status == SlotStatus.untouched;

  /// 訂正できなかった誤概念があるか。
  bool get hasAcceptedMisconception =>
      probes.any((p) => p.result == ProbeResult.accepted);

  /// 説明しきれたか。**根拠が無ければ status を信じない。**
  bool get isExplained => !isEmpty && status == SlotStatus.explained;

  factory Slot.fromJson(Map<String, dynamic> json) => Slot(
        key: json['key'] as String? ?? '',
        label: json['label'] as String? ?? '',
        status: SlotStatus.parse(json['status']),
        content: json['content'] as String? ?? '',
        evidence: _strings(json['evidence']),
        followUpHint: json['followUpHint'] as String? ?? '',
        probes: (json['probes'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(Probe.fromJson)
                .toList() ??
            const [],
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'status': status.wire,
        'content': content,
        'evidence': evidence,
        'followUpHint': followUpHint,
        'probes': probes.map((p) => p.toJson()).toList(),
      };
}

class Dossier {
  const Dossier({
    required this.unitId,
    required this.slots,
    required this.coverage,
  });

  final String unitId;
  final List<Slot> slots;

  /// 0〜100。サーバが計算した重み付き充足度
  final int coverage;

  /// 説明しきれた概念のキー。
  Set<String> get explainedKeys =>
      {for (final s in slots) if (s.isExplained) s.key};

  factory Dossier.fromJson(Map<String, dynamic> json) => Dossier(
        unitId: json['unitId'] as String? ?? '',
        slots: (json['slots'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(Slot.fromJson)
                .toList() ??
            const [],
        coverage: (json['coverage'] as num?)?.round() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'unitId': unitId,
        'slots': slots.map((s) => s.toJson()).toList(),
        'coverage': coverage,
      };
}

/// 会話の1発話。
class Utterance {
  const Utterance({
    required this.id,
    required this.isStudent,
    required this.text,
    this.corrected,
  });

  final String id;
  final bool isStudent;

  /// 生の文字起こし。同音異義語で崩れている前提で扱う
  final String text;

  /// ディレクターが文脈で校正した結果。記録はこちらを使う
  final String? corrected;

  String get display => corrected ?? text;

  Utterance withCorrection(String c) =>
      Utterance(id: id, isStudent: isStudent, text: text, corrected: c);

  Map<String, dynamic> toJson() => {
        'id': id,
        'speaker': isStudent ? 'student' : 'ai',
        'text': text,
        if (corrected != null) 'corrected': corrected,
      };
}

/// ディレクターの応答。
class DirectorResult {
  const DirectorResult({
    required this.corrections,
    required this.dossier,
    required this.nextInstruction,
    required this.lureId,
    required this.shouldEnd,
    required this.endReason,
  });

  final Map<String, String> corrections;
  final Dossier dossier;

  /// `[DIRECTOR]` に載せて注入する指示。終了時は空
  final String nextInstruction;

  /// 指示が誤概念の誘発なら、その ID。記録の突き合わせに使う
  final String? lureId;
  final bool shouldEnd;
  final String endReason;

  factory DirectorResult.fromJson(Map<String, dynamic> json) => DirectorResult(
        corrections: {
          for (final c in (json['corrections'] as List?) ?? const [])
            if (c is Map && c['id'] is String && c['corrected'] is String)
              c['id'] as String: c['corrected'] as String,
        },
        dossier: Dossier.fromJson(
            (json['dossier'] as Map?)?.cast<String, dynamic>() ?? const {}),
        nextInstruction: json['nextInstruction'] as String? ?? '',
        lureId: json['lureId'] as String?,
        shouldEnd: json['shouldEnd'] == true,
        endReason: json['endReason'] as String? ?? '',
      );
}

List<String> _strings(Object? v) =>
    (v as List?)?.whereType<String>().toList() ?? const [];

/// 前のカルテには無く、いま「説明できた」に上がった概念。
///
/// 継続の判定と、画面の祝う演出の**両方がこれを見る**。
/// 別々に数えると、片方だけ祝って記録が付かない（あるいはその逆）が起きる。
///
/// **すでに説明できていたものは数えない。** 同じ概念を何度説明しても
/// 積み上がるようにすると、水増しが構造的に可能になる。
Set<String> newlyExplained(Dossier? before, Dossier after) {
  final had = before?.explainedKeys ?? const <String>{};
  return after.explainedKeys.difference(had);
}
