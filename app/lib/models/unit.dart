/// 単元と、生徒が読む教材。
///
/// カタログの正はサーバ（`server/lib/units.ts`）。端末は取りに来て**保存する**。
/// 写しを焼き込まないのは、教材と誤概念が概念キーで結びついていて、
/// 2か所で編集すると黙ってずれるため。
///
/// 保存するのは、**復習が通信の有無に左右されないようにする**ため。
/// 「もう一度見るところ」で読み直せないなら、弱点を出す意味が薄い。
library;

/// 一覧に出すぶん。教材の本文は含まない。
class UnitSummary {
  const UnitSummary({
    required this.id,
    required this.title,
    required this.brief,
    required this.concepts,
    required this.sectionCount,
  });

  final String id;
  final String title;
  final String brief;

  /// 何を説明することになるか。**選ぶ前に見せる**（心の準備をさせる）
  final List<({String key, String label})> concepts;

  final int sectionCount;

  static UnitSummary? fromJson(Map<String, Object?> json) {
    final id = json['id'] as String?;
    if (id == null || id.isEmpty) return null;
    final raw = json['concepts'];
    return UnitSummary(
      id: id,
      title: json['title'] as String? ?? '',
      brief: json['brief'] as String? ?? '',
      concepts: raw is List
          ? raw
              .whereType<Map>()
              .map((c) => (
                    key: c['key'] as String? ?? '',
                    label: c['label'] as String? ?? '',
                  ))
              .where((c) => c.key.isNotEmpty)
              .toList()
          : const [],
      sectionCount: (json['sectionCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'brief': brief,
        'concepts': [
          for (final c in concepts) {'key': c.key, 'label': c.label},
        ],
        'sectionCount': sectionCount,
      };
}

/// 教材の1節。**概念と1対1**なので、復習から読み直す先を指せる。
class Section {
  const Section({
    required this.conceptKey,
    required this.title,
    required this.body,
    required this.tryIt,
  });

  final String conceptKey;
  final String title;

  /// 段落。1段落1トピック
  final List<String> body;

  /// 手を動かして確かめられること
  final String tryIt;

  static Section? fromJson(Map<String, Object?> json) {
    final key = json['conceptKey'] as String?;
    if (key == null || key.isEmpty) return null;
    final raw = json['body'];
    final body = raw is List ? raw.whereType<String>().toList() : const <String>[];
    // 本文が無い節は出しても読めない
    if (body.isEmpty) return null;
    return Section(
      conceptKey: key,
      title: json['title'] as String? ?? '',
      body: body,
      tryIt: json['tryIt'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() => {
        'conceptKey': conceptKey,
        'title': title,
        'body': body,
        'tryIt': tryIt,
      };

  /// おおよその読了時間。**読む前に見せる**（何分かかるか分からないと始めにくい）
  ///
  /// 中学生の黙読はおよそ 400〜600 字/分とされる。**出典は取っていない**ので、
  /// 遅めの 400 で見積もって、短すぎる表示にならないようにする。
  Duration get readingTime {
    final chars = body.fold<int>(0, (n, p) => n + p.length) + tryIt.length;
    final seconds = (chars / 400 * 60).ceil();
    return Duration(seconds: seconds < 30 ? 30 : seconds);
  }
}

/// 教材つきの単元。
class UnitDetail {
  const UnitDetail({required this.summary, required this.sections});

  final UnitSummary summary;
  final List<Section> sections;

  String get id => summary.id;
  String get title => summary.title;

  /// 全部読むのにかかるおおよその時間
  Duration get readingTime =>
      sections.fold(Duration.zero, (d, s) => d + s.readingTime);

  /// その概念の教材。無ければ null（復習は案内だけになる）
  Section? sectionFor(String conceptKey) {
    for (final s in sections) {
      if (s.conceptKey == conceptKey) return s;
    }
    return null;
  }

  static UnitDetail? fromJson(Map<String, Object?> json) {
    final summary = UnitSummary.fromJson(json);
    if (summary == null) return null;
    final raw = json['sections'];
    final sections = raw is List
        ? raw
            .whereType<Map>()
            .map((s) => Section.fromJson(s.cast<String, Object?>()))
            .nonNulls
            .toList()
        : const <Section>[];
    return UnitDetail(summary: summary, sections: sections);
  }

  Map<String, Object?> toJson() => {
        ...summary.toJson(),
        'sections': [for (final s in sections) s.toJson()],
      };
}
