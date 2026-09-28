import '../domain/learning_progress.dart';
import '../../models/unit.dart';
import '../../config/app_language.dart';

/// 理解カルテの概念カード。誤答本文ではなく、カタログの誤概念と
/// 一般化need状態だけを画面へ渡す。
final class LearningKarteConcept {
  const LearningKarteConcept({
    required this.unitId,
    required this.unitTitle,
    required this.conceptKey,
    required this.label,
    required this.grade,
    required this.field,
    required this.misconception,
    required this.activeNeeds,
    required this.resolvedNeeds,
    required this.taught,
  });

  final String unitId;
  final String unitTitle;
  final String conceptKey;
  final String label;
  final int grade;
  final UnitCurriculumField field;
  final UnitConceptMisconception? misconception;

  /// いま観測中の一般化needの種別（`science.<concept>.<suffix>` の suffix）。
  final List<String> activeNeeds;

  /// あなたの説明で解消できたneedの種別。
  final List<String> resolvedNeeds;

  /// この概念の練習・説明を一度でも始めたか。未開始の概念は思い込み本文を
  /// 表示したまま、状態chipと「まだ一緒に確かめていない」の注記で区別する。
  final bool taught;

  bool get hasActiveNeeds => activeNeeds.isNotEmpty;
  bool get hasResolvedNeeds => resolvedNeeds.isNotEmpty;
}

/// `science.<concept>.<suffix>` の suffix を、カルテ表示用の作業名へ変換する。
///
/// 未知のsuffixはそのまま返す（カタログ進化で見えなくなる事故を避ける）。
String learningKarteNeedKindLabel(String needCode) {
  final parts = needCode.split('.');
  if (parts.length < 3 || parts.first != 'science') return needCode;
  final suffix = parts.sublist(2).join('.');
  return _needKindLabels[suffix] ?? suffix;
}

Map<String, String> get _needKindLabels => {
  'foundation': t('仕組みの土台', 'Basic mechanism'),
  'conditions': t('条件の整理', 'Sorting out conditions'),
  'transfer': t('別の場面への応用', 'Applying to new situations'),
  'notation.tableRead': t('表の読み取り', 'Reading tables'),
  'notation.sequence': t('手順と順番', 'Steps and order'),
  'notation.symbol': t('記号の書き分け', 'Writing symbols correctly'),
  'notation.arrow': t('矢印と向き', 'Arrows and direction'),
  'notation.equation': t('式の表現', 'Writing equations'),
  'notation.graph': t('グラフ', 'Graphs'),
  'notation.graphRead': t('グラフの読み取り', 'Reading graphs'),
  'notation.modelBuild': t('モデル化', 'Modeling'),
  'notation.labelDiagram': t('図へのラベル付け', 'Labeling diagrams'),
  'notation.symbolMatch': t('記号の対応づけ', 'Matching symbols'),
};

/// カルテ全体の見出し数字。
final class LearningKarteSummary {
  const LearningKarteSummary({
    required this.conceptCount,
    required this.taughtCount,
    required this.activeNeedCount,
    required this.resolvedNeedCount,
  });

  final int conceptCount;
  final int taughtCount;
  final int activeNeedCount;
  final int resolvedNeedCount;
}

final class LearningKarteView {
  const LearningKarteView({required this.concepts, required this.summary});

  final List<LearningKarteConcept> concepts;
  final LearningKarteSummary summary;
}

/// catalog + need状態 + skill進捗を、カルテの並びへ投影する。
///
/// needの`skillId`は `<unitId>/<conceptKey>` 形。C9に従い、ここでは
/// 生徒の弱点とは呼ばず「デキすぎ君が迷っている作業」として扱う。
final class LearningKarteProjection {
  const LearningKarteProjection();

  LearningKarteView build({
    required List<UnitSummary> catalog,
    required List<LearningNeedStateView> needStates,
    required List<LearningSkillProgress> skills,
  }) {
    final taughtSkillIds = {
      for (final skill in skills) skill.skillId,
    };
    final activeBySkill = <String, Set<String>>{};
    final resolvedBySkill = <String, Set<String>>{};
    for (final state in needStates) {
      if (state.resolved) {
        resolvedBySkill.putIfAbsent(state.skillId, () => {}).add(state.needCode);
      } else if (state.active) {
        activeBySkill.putIfAbsent(state.skillId, () => {}).add(state.needCode);
      }
    }

    final concepts = <LearningKarteConcept>[];
    for (final unit in catalog) {
      for (final concept in unit.concepts) {
        final skillId = '${unit.id}/${concept.key}';
        final active = activeBySkill[skillId] ?? const <String>{};
        final resolved = resolvedBySkill[skillId] ?? const <String>{};
        concepts.add(
          LearningKarteConcept(
            unitId: unit.id,
            unitTitle: unit.title,
            conceptKey: concept.key,
            label: concept.label,
            grade: concept.grade,
            field: concept.field,
            misconception: concept.misconception,
            activeNeeds: List.unmodifiable(active.map(_needSuffix)),
            resolvedNeeds: List.unmodifiable(resolved.map(_needSuffix)),
            taught:
                taughtSkillIds.contains(skillId) ||
                active.isNotEmpty ||
                resolved.isNotEmpty,
          ),
        );
      }
    }
    return LearningKarteView(
      concepts: List.unmodifiable(concepts),
      summary: LearningKarteSummary(
        conceptCount: concepts.length,
        taughtCount: concepts.where((c) => c.taught).length,
        activeNeedCount: concepts.fold(0, (sum, c) => sum + c.activeNeeds.length),
        resolvedNeedCount: concepts.fold(
          0,
          (sum, c) => sum + c.resolvedNeeds.length,
        ),
      ),
    );
  }

  static String _needSuffix(String needCode) {
    final parts = needCode.split('.');
    return parts.length < 3 ? needCode : parts.sublist(2).join('.');
  }
}
