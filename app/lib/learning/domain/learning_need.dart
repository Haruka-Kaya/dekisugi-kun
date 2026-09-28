/// 固定教材の画面から保存境界へ渡してよいneed evidenceの種類。
enum LearningNeedEvidenceKind { observed, demonstrated }

/// 回答を渡さず、一般化needの観測または構造成功だけを通知する最小DTO。
///
/// [conceptKey]はHomeがcatalogのunitとskillを対応させるためのキー。
/// 回答本文・選択肢ID・音声・正誤回数は含めない。
final class LearningNeedEvidence {
  LearningNeedEvidence({
    required this.conceptKey,
    required this.needCode,
    required this.kind,
  }) {
    if (!_learningNeedConceptKey.hasMatch(conceptKey)) {
      throw ArgumentError.value(
        conceptKey,
        'conceptKey',
        'catalog concept key required',
      );
    }
    if (!_learningNeedCode.hasMatch(needCode) ||
        !needCode.startsWith('science.$conceptKey.')) {
      throw ArgumentError.value(
        needCode,
        'needCode',
        'must be a generalized code for the same catalog concept',
      );
    }
  }

  final String conceptKey;
  final String needCode;
  final LearningNeedEvidenceKind kind;
}

final RegExp _learningNeedConceptKey = RegExp(
  r'^[A-Za-z][A-Za-z0-9]*(?:-[A-Za-z0-9]+)*$',
);
final RegExp _learningNeedCode = RegExp(
  r'^science\.[A-Za-z][A-Za-z0-9-]*\.[A-Za-z][A-Za-z0-9-]*(?:\.[A-Za-z][A-Za-z0-9-]*)*$',
);

typedef LearningNeedEvidenceReported =
    void Function(LearningNeedEvidence evidence);

/// 1 run中のneed evidenceを回答非保存のまま重複排除する一時buffer。
///
/// 同じneedを一度でも誤ったrunでは、その後の有限訂正を即解消に数えない。
/// unit全体challengeもconceptKeyを保ったままskill mapへ変換できる。
final class LearningNeedEvidenceBuffer {
  final Map<String, Set<String>> _observed = {};
  final Map<String, Set<String>> _demonstrated = {};

  void record(LearningNeedEvidence evidence) {
    final target = evidence.kind == LearningNeedEvidenceKind.observed
        ? _observed
        : _demonstrated;
    target
        .putIfAbsent(evidence.conceptKey, () => <String>{})
        .add(evidence.needCode);
  }

  Map<String, Set<String>> observedBySkill(String unitId) =>
      _bySkill(unitId, _observed);

  Map<String, Set<String>> demonstratedBySkill(String unitId) {
    final result = <String, Set<String>>{};
    for (final entry in _demonstrated.entries) {
      final observed = _observed[entry.key] ?? const <String>{};
      final codes = entry.value.difference(observed);
      if (codes.isNotEmpty) result['$unitId/${entry.key}'] = codes;
    }
    return Map.unmodifiable(result);
  }

  static Map<String, Set<String>> _bySkill(
    String unitId,
    Map<String, Set<String>> source,
  ) => Map.unmodifiable({
    for (final entry in source.entries)
      if (entry.value.isNotEmpty)
        '$unitId/${entry.key}': Set.unmodifiable(entry.value),
  });
}
