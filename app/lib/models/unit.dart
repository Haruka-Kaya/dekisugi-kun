/// 単元と、生徒が読む教材。
///
/// カタログの正はサーバ（`server/lib/units.ts`）。端末は取りに来て**保存する**。
/// 初回オフライン用の写しも同梱するが、これはサーバ定義から機械生成し、
/// 不変条件テストで完全一致を強制する。科学内容を2か所で手編集しない。
///
/// 保存と同梱fallbackは、**復習が通信の有無に左右されないようにする**ため。
/// 「もう一度見るところ」で読み直せないなら、弱点を出す意味が薄い。
library;

import 'dart:math' as math;

import '../services/transcript_text.dart';

/// 一覧に公開する1概念。Storyの事件名も詳細と同じcatalog正本から受け取る。
class UnitConcept {
  const UnitConcept({
    required this.key,
    required this.label,
    required this.storyTitle,
  });

  final String key;
  final String label;
  final String storyTitle;

  static UnitConcept? fromJson(Map<String, Object?> json) {
    if (!_hasExactKeys(json, const {'key', 'label', 'storyTitle'})) {
      return null;
    }
    final key = _notationText(json['key'], maxLength: 128);
    final label = _notationText(json['label'], maxLength: 300);
    final storyTitle = _notationText(json['storyTitle'], maxLength: 300);
    if (key == null || label == null || storyTitle == null) {
      return null;
    }
    return UnitConcept(key: key, label: label, storyTitle: storyTitle);
  }

  Map<String, Object?> toJson() => {
    'key': key,
    'label': label,
    'storyTitle': storyTitle,
  };
}

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
  final List<UnitConcept> concepts;

  final int sectionCount;

  static UnitSummary? fromJson(
    Map<String, Object?> json, {
    bool allowSections = false,
  }) {
    final expectedKeys = {
      'id',
      'title',
      'brief',
      'concepts',
      'sectionCount',
      if (allowSections) 'sections',
    };
    if (!_hasExactKeys(json, expectedKeys)) return null;
    final id = _notationText(json['id'], maxLength: 128);
    final title = _notationText(json['title'], maxLength: 300);
    final brief = _notationText(json['brief'], maxLength: 2000);
    final raw = json['concepts'];
    final sectionCount = json['sectionCount'];
    if (id == null ||
        title == null ||
        brief == null ||
        raw is! List ||
        raw.isEmpty ||
        raw.any((concept) => concept is! Map) ||
        sectionCount is! num ||
        !sectionCount.isFinite ||
        sectionCount.toInt() != sectionCount ||
        sectionCount <= 0) {
      return null;
    }
    final concepts = <UnitConcept>[];
    for (final rawConcept in raw.cast<Map>()) {
      final conceptJson = _stringKeyedMap(rawConcept);
      if (conceptJson == null) return null;
      final concept = UnitConcept.fromJson(conceptJson);
      if (concept == null) return null;
      concepts.add(concept);
    }
    if (concepts.map((concept) => concept.key).toSet().length !=
            concepts.length ||
        concepts.map((concept) => concept.storyTitle).toSet().length !=
            concepts.length) {
      return null;
    }
    return UnitSummary(
      id: id,
      title: title,
      brief: brief,
      concepts: concepts,
      sectionCount: sectionCount.toInt(),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'brief': brief,
    'concepts': [for (final c in concepts) c.toJson()],
    'sectionCount': sectionCount,
  };
}

/// 端末内checkpointの1選択肢。
class LocalCheckpointOption {
  const LocalCheckpointOption({
    required this.id,
    required this.text,
    this.hint,
    this.needCode,
  });

  final String id;
  final String text;

  /// 誤答を答えに置き換えず、見直す科学的観点だけを返す。
  final String? hint;

  /// 誤答だけが持つ、選択肢IDや文言から独立した一般化need。
  final String? needCode;

  static LocalCheckpointOption? fromJson(Map<String, Object?> json) {
    final hasNeed = json.containsKey('needCode');
    final expectedKeys = hasNeed
        ? const {'id', 'text', 'hint', 'needCode'}
        : const {'id', 'text'};
    if (!_hasExactKeys(json, expectedKeys)) return null;
    final id = json['id'] as String?;
    final text = json['text'] as String?;
    final hint = json['hint'] as String?;
    final needCode = hasNeed ? _needCodeText(json['needCode']) : null;
    if (id == null ||
        id.trim().isEmpty ||
        text == null ||
        text.trim().isEmpty ||
        (hasNeed &&
            (hint == null || hint.trim().isEmpty || needCode == null))) {
      return null;
    }
    return LocalCheckpointOption(
      id: id,
      text: text,
      hint: hint,
      needCode: needCode,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'text': text,
    if (hint != null) 'hint': hint,
    if (needCode != null) 'needCode': needCode,
  };
}

///
/// 自由記述を自動採点せず、固定の思い込みを3択で見破る端末内checkpoint。
/// 通過しても習得・理解度・会話枠は更新しない。
class LocalCheckpoint {
  const LocalCheckpoint({
    required this.lure,
    required this.options,
    required this.correctOptionId,
    required this.explanation,
  });

  final String lure;
  final List<LocalCheckpointOption> options;
  final String correctOptionId;
  final String explanation;

  LocalCheckpointOption? optionFor(String id) {
    for (final option in options) {
      if (option.id == id) return option;
    }
    return null;
  }

  static LocalCheckpoint? fromJson(Map<String, Object?> json) {
    if (!_hasExactKeys(json, const {
      'lure',
      'options',
      'correctOptionId',
      'explanation',
    })) {
      return null;
    }
    final lure = json['lure'] as String?;
    final correctOptionId = json['correctOptionId'] as String?;
    final explanation = json['explanation'] as String?;
    final rawOptions = json['options'];
    if (lure == null ||
        lure.trim().isEmpty ||
        correctOptionId == null ||
        correctOptionId.trim().isEmpty ||
        explanation == null ||
        explanation.trim().isEmpty ||
        rawOptions is! List ||
        rawOptions.length != 3 ||
        rawOptions.any((option) => option is! Map)) {
      return null;
    }

    final options = rawOptions
        .whereType<Map>()
        .map(
          (option) =>
              LocalCheckpointOption.fromJson(option.cast<String, Object?>()),
        )
        .nonNulls
        .toList();
    if (options.length != 3 ||
        options.map((option) => option.id).toSet().length != 3 ||
        options.where((option) => option.id == correctOptionId).length != 1) {
      return null;
    }
    for (final option in options) {
      if (option.id != correctOptionId &&
          (option.hint == null ||
              option.hint!.trim().isEmpty ||
              option.needCode == null)) {
        return null;
      }
      if (option.id == correctOptionId &&
          (option.hint != null || option.needCode != null)) {
        return null;
      }
    }

    return LocalCheckpoint(
      lure: lure,
      options: options,
      correctOptionId: correctOptionId,
      explanation: explanation,
    );
  }

  Map<String, Object?> toJson() => {
    'lure': lure,
    'options': [for (final option in options) option.toJson()],
    'correctOptionId': correctOptionId,
    'explanation': explanation,
  };
}

/// 端末内の具体場面で行う構造化操作。
enum LocalCognitiveTaskKind {
  singleSelect,
  classify,
  sequence;

  String get wire => name;

  static LocalCognitiveTaskKind? parse(Object? value) => switch (value) {
    'singleSelect' => LocalCognitiveTaskKind.singleSelect,
    'classify' => LocalCognitiveTaskKind.classify,
    'sequence' => LocalCognitiveTaskKind.sequence,
    _ => null,
  };
}

/// 見た目ではなく、課題で必要になる科学的な判断。
enum LocalCognitiveOperation {
  prediction,
  conditionClassify,
  causalOrder,
  forceDirection,
  quantityCompare,
  experimentPlan;

  String get wire => name;

  static LocalCognitiveOperation? parse(Object? value) => switch (value) {
    'prediction' => LocalCognitiveOperation.prediction,
    'conditionClassify' => LocalCognitiveOperation.conditionClassify,
    'causalOrder' => LocalCognitiveOperation.causalOrder,
    'forceDirection' => LocalCognitiveOperation.forceDirection,
    'quantityCompare' => LocalCognitiveOperation.quantityCompare,
    'experimentPlan' => LocalCognitiveOperation.experimentPlan,
    _ => null,
  };
}

class LocalCognitiveTaskItem {
  const LocalCognitiveTaskItem({required this.id, required this.text});

  final String id;
  final String text;

  Map<String, Object?> toJson() => {'id': id, 'text': text};

  static LocalCognitiveTaskItem? fromJson(Map<String, Object?> json) {
    if (json.length != 2 ||
        !json.containsKey('id') ||
        !json.containsKey('text')) {
      return null;
    }
    final id = json['id'];
    final text = json['text'];
    if (id is! String ||
        id.trim().isEmpty ||
        id.length > 128 ||
        _answerSignalingId.hasMatch(id) ||
        text is! String ||
        text.trim().isEmpty ||
        text.length > 2000) {
      return null;
    }
    return LocalCognitiveTaskItem(id: id, text: text);
  }
}

class LocalCognitiveTaskTarget {
  const LocalCognitiveTaskTarget({required this.id, required this.label});

  final String id;
  final String label;

  Map<String, Object?> toJson() => {'id': id, 'label': label};

  static LocalCognitiveTaskTarget? fromJson(Map<String, Object?> json) {
    if (json.length != 2 ||
        !json.containsKey('id') ||
        !json.containsKey('label')) {
      return null;
    }
    final id = json['id'];
    final label = json['label'];
    if (id is! String ||
        id.trim().isEmpty ||
        id.length > 128 ||
        _answerSignalingId.hasMatch(id) ||
        label is! String ||
        label.trim().isEmpty ||
        label.length > 1000) {
      return null;
    }
    return LocalCognitiveTaskTarget(id: id, label: label);
  }
}

/// 回答widgetへ渡してよい、正解を含まない公開部分。
class LocalCognitiveTaskPrompt {
  const LocalCognitiveTaskPrompt({
    required this.kind,
    required this.operation,
    required this.items,
    required this.targets,
  });

  final LocalCognitiveTaskKind kind;
  final LocalCognitiveOperation operation;
  final List<LocalCognitiveTaskItem> items;

  /// classify以外では空。
  final List<LocalCognitiveTaskTarget> targets;
}

sealed class LocalCognitiveTaskSolution {
  const LocalCognitiveTaskSolution();

  Map<String, Object?> toJson();
}

final class LocalSingleSelectSolution extends LocalCognitiveTaskSolution {
  const LocalSingleSelectSolution({required this.selectedItemId});

  final String selectedItemId;

  @override
  Map<String, Object?> toJson() => {'selectedItemId': selectedItemId};
}

final class LocalClassifySolution extends LocalCognitiveTaskSolution {
  const LocalClassifySolution({required this.targetByItemId});

  final Map<String, String> targetByItemId;

  @override
  Map<String, Object?> toJson() => {'targetByItemId': targetByItemId};
}

final class LocalSequenceSolution extends LocalCognitiveTaskSolution {
  const LocalSequenceSolution({required this.orderedItemIds});

  final List<String> orderedItemIds;

  @override
  Map<String, Object?> toJson() => {'orderedItemIds': orderedItemIds};
}

/// 具体場面の問いに直接答える、最大4項目の構造化課題。
///
/// 入力中のwidgetには [prompt] だけを渡す。[solution]は比較画面まで渡さず、
/// 正答をSemanticsやwidget treeへ先出ししない。
class LocalCognitiveTask {
  const LocalCognitiveTask({
    required this.kind,
    required this.operation,
    required this.items,
    required this.targets,
    required this.solution,
    this.needCode,
  }) : assert(
         (kind == LocalCognitiveTaskKind.singleSelect &&
                 solution is LocalSingleSelectSolution) ||
             (kind == LocalCognitiveTaskKind.classify &&
                 solution is LocalClassifySolution) ||
             (kind == LocalCognitiveTaskKind.sequence &&
                 solution is LocalSequenceSolution),
       );

  final LocalCognitiveTaskKind kind;
  final LocalCognitiveOperation operation;
  final List<LocalCognitiveTaskItem> items;
  final List<LocalCognitiveTaskTarget> targets;
  final LocalCognitiveTaskSolution solution;

  /// この構造課題全体の誤入力を一般化したneed。回答の組合せは含めない。
  final String? needCode;

  LocalCognitiveTaskPrompt get prompt => LocalCognitiveTaskPrompt(
    kind: kind,
    operation: operation,
    items: items,
    targets: targets,
  );

  Map<String, Object?> toJson() => {
    'kind': kind.wire,
    'operation': operation.wire,
    if (needCode != null) 'needCode': needCode,
    'items': [for (final item in items) item.toJson()],
    if (kind == LocalCognitiveTaskKind.classify)
      'targets': [for (final target in targets) target.toJson()],
    'solution': solution.toJson(),
  };

  static LocalCognitiveTask? fromJson(Map<String, Object?> json) {
    final kind = LocalCognitiveTaskKind.parse(json['kind']);
    final operation = LocalCognitiveOperation.parse(json['operation']);
    final needCode = _needCodeText(json['needCode']);
    if (kind == null || operation == null || needCode == null) return null;
    final allowedKeys = kind == LocalCognitiveTaskKind.classify
        ? const {
            'kind',
            'operation',
            'needCode',
            'items',
            'targets',
            'solution',
          }
        : const {'kind', 'operation', 'needCode', 'items', 'solution'};
    if (json.length != allowedKeys.length ||
        json.keys.any((key) => !allowedKeys.contains(key))) {
      return null;
    }

    final rawItems = json['items'];
    final minimumItems = kind == LocalCognitiveTaskKind.singleSelect ? 2 : 3;
    if (rawItems is! List ||
        rawItems.length < minimumItems ||
        rawItems.length > 4 ||
        rawItems.any((item) => item is! Map)) {
      return null;
    }
    final items = <LocalCognitiveTaskItem>[];
    for (final rawItem in rawItems.cast<Map>()) {
      final itemJson = _stringKeyedMap(rawItem);
      if (itemJson == null) return null;
      final item = LocalCognitiveTaskItem.fromJson(itemJson);
      if (item == null) return null;
      items.add(item);
    }
    final itemIds = items.map((item) => item.id).toSet();
    if (itemIds.length != items.length) return null;

    final rawSolution = json['solution'];
    final solutionJson = _stringKeyedMap(rawSolution);
    if (solutionJson == null) return null;

    switch (kind) {
      case LocalCognitiveTaskKind.singleSelect:
        if (solutionJson.length != 1 ||
            !solutionJson.containsKey('selectedItemId')) {
          return null;
        }
        final selectedItemId = solutionJson['selectedItemId'];
        if (selectedItemId is! String || !itemIds.contains(selectedItemId)) {
          return null;
        }
        return LocalCognitiveTask(
          kind: kind,
          operation: operation,
          items: List.unmodifiable(items),
          targets: const [],
          solution: LocalSingleSelectSolution(selectedItemId: selectedItemId),
          needCode: needCode,
        );

      case LocalCognitiveTaskKind.classify:
        final rawTargets = json['targets'];
        if (rawTargets is! List ||
            rawTargets.length < 2 ||
            rawTargets.length > 3 ||
            rawTargets.any((target) => target is! Map) ||
            solutionJson.length != 1 ||
            !solutionJson.containsKey('targetByItemId')) {
          return null;
        }
        final targets = <LocalCognitiveTaskTarget>[];
        for (final rawTarget in rawTargets.cast<Map>()) {
          final targetJson = _stringKeyedMap(rawTarget);
          if (targetJson == null) return null;
          final target = LocalCognitiveTaskTarget.fromJson(targetJson);
          if (target == null) return null;
          targets.add(target);
        }
        final targetIds = targets.map((target) => target.id).toSet();
        if (targetIds.length != targets.length) return null;
        final rawAssignments = solutionJson['targetByItemId'];
        if (rawAssignments is! Map || rawAssignments.length != items.length) {
          return null;
        }
        final assignments = <String, String>{};
        for (final entry in rawAssignments.entries) {
          if (entry.key is! String ||
              entry.value is! String ||
              !itemIds.contains(entry.key) ||
              !targetIds.contains(entry.value)) {
            return null;
          }
          assignments[entry.key as String] = entry.value as String;
        }
        if (assignments.keys.toSet().length != itemIds.length) return null;
        return LocalCognitiveTask(
          kind: kind,
          operation: operation,
          items: List.unmodifiable(items),
          targets: List.unmodifiable(targets),
          solution: LocalClassifySolution(
            targetByItemId: Map.unmodifiable(assignments),
          ),
          needCode: needCode,
        );

      case LocalCognitiveTaskKind.sequence:
        if (solutionJson.length != 1 ||
            !solutionJson.containsKey('orderedItemIds')) {
          return null;
        }
        final rawOrder = solutionJson['orderedItemIds'];
        if (rawOrder is! List ||
            rawOrder.length != items.length ||
            rawOrder.any((id) => id is! String)) {
          return null;
        }
        final orderedItemIds = rawOrder.cast<String>();
        if (orderedItemIds.toSet().length != itemIds.length ||
            !orderedItemIds.every(itemIds.contains) ||
            _sameOrder(items.map((item) => item.id).toList(), orderedItemIds)) {
          return null;
        }
        return LocalCognitiveTask(
          kind: kind,
          operation: operation,
          items: List.unmodifiable(items),
          targets: const [],
          solution: LocalSequenceSolution(
            orderedItemIds: List.unmodifiable(orderedItemIds),
          ),
          needCode: needCode,
        );
    }
  }

  /// JSON/APIにcognitiveTaskが無かった時代のdirect fixtureだけの退避。
  /// 科学内容を推測せず、実教材の正答やcheckpoint文も流用しない。
  static const safeLegacyFallback = LocalCognitiveTask(
    kind: LocalCognitiveTaskKind.singleSelect,
    operation: LocalCognitiveOperation.prediction,
    items: [
      LocalCognitiveTaskItem(
        id: 'review-conditions',
        text: '教材の条件を確かめてから、この場面の結果を予想する。',
      ),
      LocalCognitiveTaskItem(
        id: 'skip-conditions',
        text: '条件を確かめず、印象だけで結果を決める。',
      ),
    ],
    targets: [],
    solution: LocalSingleSelectSolution(selectedItemId: 'review-conditions'),
  );

  static bool _sameOrder(List<String> left, List<String> right) {
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }
}

final _answerSignalingId = RegExp(
  r'(^|[-_])(correct|incorrect|right|wrong|answer|solution|true|false|yes|no)([-_]|$)',
  caseSensitive: false,
);

Map<String, Object?>? _stringKeyedMap(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) return null;
  return {for (final entry in value.entries) entry.key as String: entry.value};
}

/// 同じ概念を繰り返すときの、端末内練習の認知的な段階。
///
/// 保存値ではなく公開教材の契約。完了回数 `n` に対して `n % 3` の段階を
/// 選ぶため、自由記述やvariant IDを新たに保存しない。
enum LocalPracticeStage {
  foundation,
  conditions,
  transfer;

  String get wire => name;

  String get label => switch (this) {
    LocalPracticeStage.foundation => '原理を思い出す',
    LocalPracticeStage.conditions => '条件を見分ける',
    LocalPracticeStage.transfer => '別の場面へ使う',
  };

  static LocalPracticeStage? parse(Object? value) => switch (value) {
    'foundation' => LocalPracticeStage.foundation,
    'conditions' => LocalPracticeStage.conditions,
    'transfer' => LocalPracticeStage.transfer,
    _ => null,
  };
}

/// Listeningの文字起こし誤差と科学的意味誤答を分離する固定need。
///
/// 回答本文や選択肢IDは含めず、catalogのconceptとstageだけから決まる。
final class LocalListeningNeedCodes {
  const LocalListeningNeedCodes({
    required this.transcript,
    required this.meaning,
  });

  final String transcript;
  final String meaning;

  static LocalListeningNeedCodes? fromJson(Map<String, Object?> json) {
    if (!_hasExactKeys(json, const {'transcript', 'meaning'})) return null;
    final transcript = _needCodeText(json['transcript']);
    final meaning = _needCodeText(json['meaning']);
    if (transcript == null || meaning == null || transcript == meaning) {
      return null;
    }
    return LocalListeningNeedCodes(transcript: transcript, meaning: meaning);
  }

  Map<String, Object?> toJson() => {
    'transcript': transcript,
    'meaning': meaning,
  };
}

/// 1回分の「想起 → 理由・条件 → 具体場面 → 誤概念訂正」。
///
/// promptは問いだけを持つ。[expectedOutcome]と[expectedReason]は
/// [transferPrompt]に1:1対応する比較用の答えで、予想後まで画面へ出さない。
/// [checkpoint]は別の誤概念訂正であり、比較の答えに流用しない。
class LocalPracticeVariant {
  const LocalPracticeVariant({
    required this.stage,
    required this.recallPrompt,
    required this.reasoningPrompt,
    required this.transferPrompt,
    required this.expectedOutcome,
    required this.expectedReason,
    required this.cognitiveTask,
    required this.checkpoint,
    this.listeningNeedCodes,
  });

  final LocalPracticeStage stage;
  final String recallPrompt;
  final String reasoningPrompt;
  final String transferPrompt;
  final String expectedOutcome;
  final String expectedReason;
  final LocalCognitiveTask cognitiveTask;
  final LocalCheckpoint checkpoint;

  /// JSON/API/同梱catalog v9では必須。direct fixtureだけはnullを許す。
  final LocalListeningNeedCodes? listeningNeedCodes;

  static LocalPracticeVariant? fromJson(Map<String, Object?> json) {
    const allowedKeys = {
      'stage',
      'recallPrompt',
      'reasoningPrompt',
      'transferPrompt',
      'expectedOutcome',
      'expectedReason',
      'cognitiveTask',
      'checkpoint',
      'listeningNeedCodes',
    };
    if (json.length != allowedKeys.length ||
        json.keys.any((key) => !allowedKeys.contains(key))) {
      return null;
    }
    final stage = LocalPracticeStage.parse(json['stage']);
    final recallPrompt = json['recallPrompt'] as String?;
    final reasoningPrompt = json['reasoningPrompt'] as String?;
    final transferPrompt = json['transferPrompt'] as String?;
    final expectedOutcome = json['expectedOutcome'] as String?;
    final expectedReason = json['expectedReason'] as String?;
    final cognitiveTaskJson = _stringKeyedMap(json['cognitiveTask']);
    final cognitiveTask = cognitiveTaskJson == null
        ? null
        : LocalCognitiveTask.fromJson(cognitiveTaskJson);
    final rawCheckpoint = json['checkpoint'];
    final checkpoint = rawCheckpoint is Map
        ? LocalCheckpoint.fromJson(rawCheckpoint.cast<String, Object?>())
        : null;
    final listeningJson = _stringKeyedMap(json['listeningNeedCodes']);
    final listeningNeedCodes = listeningJson == null
        ? null
        : LocalListeningNeedCodes.fromJson(listeningJson);
    if (stage == null ||
        recallPrompt == null ||
        recallPrompt.trim().isEmpty ||
        reasoningPrompt == null ||
        reasoningPrompt.trim().isEmpty ||
        transferPrompt == null ||
        transferPrompt.trim().isEmpty ||
        expectedOutcome == null ||
        expectedOutcome.trim().isEmpty ||
        expectedReason == null ||
        expectedReason.trim().isEmpty ||
        cognitiveTask == null ||
        checkpoint == null ||
        listeningNeedCodes == null) {
      return null;
    }
    return LocalPracticeVariant(
      stage: stage,
      recallPrompt: recallPrompt,
      reasoningPrompt: reasoningPrompt,
      transferPrompt: transferPrompt,
      expectedOutcome: expectedOutcome,
      expectedReason: expectedReason,
      cognitiveTask: cognitiveTask,
      checkpoint: checkpoint,
      listeningNeedCodes: listeningNeedCodes,
    );
  }

  Map<String, Object?> toJson() => {
    'stage': stage.wire,
    'recallPrompt': recallPrompt,
    'reasoningPrompt': reasoningPrompt,
    'transferPrompt': transferPrompt,
    'expectedOutcome': expectedOutcome,
    'expectedReason': expectedReason,
    'cognitiveTask': cognitiveTask.toJson(),
    'checkpoint': checkpoint.toJson(),
    if (listeningNeedCodes != null)
      'listeningNeedCodes': listeningNeedCodes!.toJson(),
  };
}

/// Notation Labで並べる、意味を持つ最小の記号札。
class LocalNotationToken {
  const LocalNotationToken({required this.id, required this.label});

  final String id;
  final String label;

  static LocalNotationToken? fromJson(Map<String, Object?> json) {
    if (!_hasExactKeys(json, const {'id', 'label'})) return null;
    final id = _notationText(json['id'], maxLength: 128);
    final label = _notationText(json['label'], maxLength: 200);
    if (id == null || label == null) return null;
    return LocalNotationToken(id: id, label: label);
  }

  Map<String, Object?> toJson() => {'id': id, 'label': label};
}

/// 端末サイズに依存しない、0..1で正規化したstroke上の点。
class LocalNotationTracePoint {
  const LocalNotationTracePoint({required this.x, required this.y});

  final double x;
  final double y;

  static LocalNotationTracePoint? fromJson(Map<String, Object?> json) {
    if (!_hasExactKeys(json, const {'x', 'y'})) return null;
    final rawX = json['x'];
    final rawY = json['y'];
    if (rawX is! num || rawY is! num) return null;
    final x = rawX.toDouble();
    final y = rawY.toDouble();
    if (!x.isFinite || !y.isFinite || x < 0 || x > 1 || y < 0 || y > 1) {
      return null;
    }
    return LocalNotationTracePoint(x: x, y: y);
  }

  Map<String, Object?> toJson() => {'x': x, 'y': y};
}

class LocalNotationTraceStroke {
  const LocalNotationTraceStroke({
    required this.id,
    required this.label,
    required this.points,
  });

  final String id;
  final String label;
  final List<LocalNotationTracePoint> points;

  static LocalNotationTraceStroke? fromJson(Map<String, Object?> json) {
    if (!_hasExactKeys(json, const {'id', 'label', 'points'})) return null;
    final id = _notationText(json['id'], maxLength: 160);
    final label = _notationText(json['label'], maxLength: 300);
    final rawPoints = json['points'];
    if (id == null ||
        label == null ||
        rawPoints is! List ||
        rawPoints.length < 3 ||
        rawPoints.length > 32 ||
        rawPoints.any((point) => point is! Map)) {
      return null;
    }
    final points = <LocalNotationTracePoint>[];
    for (final rawPoint in rawPoints.cast<Map>()) {
      final pointJson = _stringKeyedMap(rawPoint);
      if (pointJson == null) return null;
      final point = LocalNotationTracePoint.fromJson(pointJson);
      if (point == null) return null;
      points.add(point);
    }
    var length = 0.0;
    for (var index = 1; index < points.length; index++) {
      final dx = points[index].x - points[index - 1].x;
      final dy = points[index].y - points[index - 1].y;
      length += math.sqrt(dx * dx + dy * dy);
    }
    if (length < 0.15) return null;
    return LocalNotationTraceStroke(
      id: id,
      label: label,
      points: List.unmodifiable(points),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'points': [for (final point in points) point.toJson()],
  };
}

class LocalNotationTracePattern {
  const LocalNotationTracePattern({
    required this.semanticsLabel,
    required this.strokes,
    required this.strokeOrderIds,
  });

  final String semanticsLabel;
  final List<LocalNotationTraceStroke> strokes;
  final List<String> strokeOrderIds;

  static LocalNotationTracePattern? fromJson(Map<String, Object?> json) {
    if (!_hasExactKeys(json, const {
      'semanticsLabel',
      'strokes',
      'strokeOrderIds',
    })) {
      return null;
    }
    final semanticsLabel = _notationText(
      json['semanticsLabel'],
      maxLength: 2000,
    );
    final rawStrokes = json['strokes'];
    final rawOrder = json['strokeOrderIds'];
    if (semanticsLabel == null ||
        rawStrokes is! List ||
        rawStrokes.isEmpty ||
        rawStrokes.length > 6 ||
        rawStrokes.any((stroke) => stroke is! Map) ||
        rawOrder is! List ||
        rawOrder.length != rawStrokes.length ||
        rawOrder.any((id) => id is! String)) {
      return null;
    }
    final strokes = <LocalNotationTraceStroke>[];
    for (final rawStroke in rawStrokes.cast<Map>()) {
      final strokeJson = _stringKeyedMap(rawStroke);
      if (strokeJson == null) return null;
      final stroke = LocalNotationTraceStroke.fromJson(strokeJson);
      if (stroke == null) return null;
      strokes.add(stroke);
    }
    final ids = strokes.map((stroke) => stroke.id).toSet();
    final order = rawOrder.cast<String>();
    if (ids.length != strokes.length ||
        order.toSet().length != strokes.length ||
        !order.every(ids.contains) ||
        !ids.every(order.contains)) {
      return null;
    }
    return LocalNotationTracePattern(
      semanticsLabel: semanticsLabel,
      strokes: List.unmodifiable(strokes),
      strokeOrderIds: List.unmodifiable(order),
    );
  }

  LocalNotationTraceStroke strokeFor(String id) =>
      strokes.singleWhere((stroke) => stroke.id == id);

  Map<String, Object?> toJson() => {
    'semanticsLabel': semanticsLabel,
    'strokes': [for (final stroke in strokes) stroke.toJson()],
    'strokeOrderIds': strokeOrderIds,
  };
}

/// 矢印のstroke順または式のtoken順を組む固定課題。
class LocalNotationOrderTask {
  const LocalNotationOrderTask({
    required this.id,
    required this.title,
    required this.prompt,
    required this.traceGuide,
    required this.tracePattern,
    required this.tokens,
    required this.correctOrderIds,
    required this.solutionSummary,
    this.needCode,
  });

  final String id;
  final String title;
  final String prompt;
  final String traceGuide;
  final LocalNotationTracePattern tracePattern;
  final List<LocalNotationToken> tokens;
  final List<String> correctOrderIds;
  final String solutionSummary;
  final String? needCode;

  static LocalNotationOrderTask? fromJson(Map<String, Object?> json) {
    if (!_hasExactKeys(json, const {
      'id',
      'needCode',
      'title',
      'prompt',
      'traceGuide',
      'tracePattern',
      'tokens',
      'correctOrderIds',
      'solutionSummary',
    })) {
      return null;
    }
    final id = _notationText(json['id'], maxLength: 128);
    final needCode = _needCodeText(json['needCode']);
    final title = _notationText(json['title'], maxLength: 200);
    final prompt = _notationText(json['prompt'], maxLength: 2000);
    final traceGuide = _notationText(json['traceGuide'], maxLength: 2000);
    final traceJson = _stringKeyedMap(json['tracePattern']);
    final tracePattern = traceJson == null
        ? null
        : LocalNotationTracePattern.fromJson(traceJson);
    final solutionSummary = _notationText(
      json['solutionSummary'],
      maxLength: 2000,
    );
    final rawTokens = json['tokens'];
    final rawOrder = json['correctOrderIds'];
    if (id == null ||
        needCode == null ||
        title == null ||
        prompt == null ||
        traceGuide == null ||
        tracePattern == null ||
        solutionSummary == null ||
        rawTokens is! List ||
        rawTokens.length < 2 ||
        rawTokens.length > 8 ||
        rawTokens.any((token) => token is! Map) ||
        rawOrder is! List ||
        rawOrder.length != rawTokens.length ||
        rawOrder.any((value) => value is! String)) {
      return null;
    }
    final tokens = <LocalNotationToken>[];
    for (final rawToken in rawTokens.cast<Map>()) {
      final tokenJson = _stringKeyedMap(rawToken);
      if (tokenJson == null) return null;
      final token = LocalNotationToken.fromJson(tokenJson);
      if (token == null) return null;
      tokens.add(token);
    }
    final tokenIds = tokens.map((token) => token.id).toSet();
    final order = rawOrder.cast<String>();
    if (tokenIds.length != tokens.length ||
        order.toSet().length != tokens.length ||
        !order.every(tokenIds.contains) ||
        _sameStringOrder(tokens.map((token) => token.id).toList(), order)) {
      return null;
    }
    return LocalNotationOrderTask(
      id: id,
      title: title,
      prompt: prompt,
      traceGuide: traceGuide,
      tracePattern: tracePattern,
      tokens: List.unmodifiable(tokens),
      correctOrderIds: List.unmodifiable(order),
      solutionSummary: solutionSummary,
      needCode: needCode,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    if (needCode != null) 'needCode': needCode,
    'title': title,
    'prompt': prompt,
    'traceGuide': traceGuide,
    'tracePattern': tracePattern.toJson(),
    'tokens': [for (final token in tokens) token.toJson()],
    'correctOrderIds': correctOrderIds,
    'solutionSummary': solutionSummary,
  };
}

class LocalNotationChoice {
  const LocalNotationChoice({required this.id, required this.label});

  final String id;
  final String label;

  static LocalNotationChoice? fromJson(Map<String, Object?> json) {
    if (!_hasExactKeys(json, const {'id', 'label'})) return null;
    final id = _notationText(json['id'], maxLength: 128);
    final label = _notationText(json['label'], maxLength: 1000);
    if (id == null || label == null) return null;
    return LocalNotationChoice(id: id, label: label);
  }

  Map<String, Object?> toJson() => {'id': id, 'label': label};
}

class LocalNotationSymbolTask {
  const LocalNotationSymbolTask({
    required this.prompt,
    required this.choices,
    required this.correctChoiceId,
    required this.solutionSummary,
    this.needCode,
  });

  final String prompt;
  final List<LocalNotationChoice> choices;
  final String correctChoiceId;
  final String solutionSummary;
  final String? needCode;

  static LocalNotationSymbolTask? fromJson(Map<String, Object?> json) {
    if (!_hasExactKeys(json, const {
      'prompt',
      'needCode',
      'choices',
      'correctChoiceId',
      'solutionSummary',
    })) {
      return null;
    }
    final prompt = _notationText(json['prompt'], maxLength: 2000);
    final needCode = _needCodeText(json['needCode']);
    final correctChoiceId = _notationText(
      json['correctChoiceId'],
      maxLength: 128,
    );
    final solutionSummary = _notationText(
      json['solutionSummary'],
      maxLength: 2000,
    );
    final parsed = _parseNotationChoices(json['choices']);
    if (prompt == null ||
        needCode == null ||
        correctChoiceId == null ||
        solutionSummary == null ||
        parsed == null ||
        parsed.where((choice) => choice.id == correctChoiceId).length != 1) {
      return null;
    }
    return LocalNotationSymbolTask(
      prompt: prompt,
      choices: parsed,
      correctChoiceId: correctChoiceId,
      solutionSummary: solutionSummary,
      needCode: needCode,
    );
  }

  Map<String, Object?> toJson() => {
    'prompt': prompt,
    if (needCode != null) 'needCode': needCode,
    'choices': [for (final choice in choices) choice.toJson()],
    'correctChoiceId': correctChoiceId,
    'solutionSummary': solutionSummary,
  };
}

class LocalNotationGraphTask {
  const LocalNotationGraphTask({
    required this.prompt,
    required this.graphNotation,
    required this.graphSemanticsLabel,
    required this.choices,
    required this.correctChoiceId,
    required this.solutionSummary,
    this.needCode,
  });

  final String prompt;
  final List<String> graphNotation;
  final String graphSemanticsLabel;
  final List<LocalNotationChoice> choices;
  final String correctChoiceId;
  final String solutionSummary;
  final String? needCode;

  static LocalNotationGraphTask? fromJson(Map<String, Object?> json) {
    if (!_hasExactKeys(json, const {
      'prompt',
      'needCode',
      'graphNotation',
      'graphSemanticsLabel',
      'choices',
      'correctChoiceId',
      'solutionSummary',
    })) {
      return null;
    }
    final prompt = _notationText(json['prompt'], maxLength: 2000);
    final needCode = _needCodeText(json['needCode']);
    final graphSemanticsLabel = _notationText(
      json['graphSemanticsLabel'],
      maxLength: 2000,
    );
    final correctChoiceId = _notationText(
      json['correctChoiceId'],
      maxLength: 128,
    );
    final solutionSummary = _notationText(
      json['solutionSummary'],
      maxLength: 2000,
    );
    final rawNotation = json['graphNotation'];
    final parsedChoices = _parseNotationChoices(json['choices']);
    if (prompt == null ||
        needCode == null ||
        graphSemanticsLabel == null ||
        correctChoiceId == null ||
        solutionSummary == null ||
        rawNotation is! List ||
        rawNotation.length < 2 ||
        rawNotation.length > 8 ||
        rawNotation.any(
          (line) => line is! String || line.trim().isEmpty || line.length > 200,
        ) ||
        parsedChoices == null ||
        parsedChoices.where((choice) => choice.id == correctChoiceId).length !=
            1) {
      return null;
    }
    return LocalNotationGraphTask(
      prompt: prompt,
      graphNotation: List.unmodifiable(rawNotation.cast<String>()),
      graphSemanticsLabel: graphSemanticsLabel,
      choices: parsedChoices,
      correctChoiceId: correctChoiceId,
      solutionSummary: solutionSummary,
      needCode: needCode,
    );
  }

  Map<String, Object?> toJson() => {
    'prompt': prompt,
    if (needCode != null) 'needCode': needCode,
    'graphNotation': graphNotation,
    'graphSemanticsLabel': graphSemanticsLabel,
    'choices': [for (final choice in choices) choice.toJson()],
    'correctChoiceId': correctChoiceId,
    'solutionSummary': solutionSummary,
  };
}

/// server catalog v8から損失なく復元するNotation Lab正本。
class LocalNotationLab {
  const LocalNotationLab({
    required this.orderTasks,
    required this.symbolMatch,
    required this.graphRead,
  });

  final List<LocalNotationOrderTask> orderTasks;
  final LocalNotationSymbolTask symbolMatch;
  final LocalNotationGraphTask graphRead;

  static LocalNotationLab? fromJson(Map<String, Object?> json) {
    if (!_hasExactKeys(json, const {
      'orderTasks',
      'symbolMatch',
      'graphRead',
    })) {
      return null;
    }
    final rawTasks = json['orderTasks'];
    final symbolJson = _stringKeyedMap(json['symbolMatch']);
    final graphJson = _stringKeyedMap(json['graphRead']);
    if (rawTasks is! List ||
        rawTasks.length != 2 ||
        rawTasks.any((task) => task is! Map) ||
        symbolJson == null ||
        graphJson == null) {
      return null;
    }
    final tasks = <LocalNotationOrderTask>[];
    for (final rawTask in rawTasks.cast<Map>()) {
      final taskJson = _stringKeyedMap(rawTask);
      if (taskJson == null) return null;
      final task = LocalNotationOrderTask.fromJson(taskJson);
      if (task == null) return null;
      tasks.add(task);
    }
    final symbol = LocalNotationSymbolTask.fromJson(symbolJson);
    final graph = LocalNotationGraphTask.fromJson(graphJson);
    if (tasks.map((task) => task.id).toSet().length != 2 ||
        symbol == null ||
        graph == null) {
      return null;
    }
    return LocalNotationLab(
      orderTasks: List.unmodifiable(tasks),
      symbolMatch: symbol,
      graphRead: graph,
    );
  }

  Map<String, Object?> toJson() => {
    'orderTasks': [for (final task in orderTasks) task.toJson()],
    'symbolMatch': symbolMatch.toJson(),
    'graphRead': graphRead.toJson(),
  };
}

class LocalScienceStoryCharacter {
  const LocalScienceStoryCharacter({
    required this.id,
    required this.name,
    required this.role,
  });

  final String id;
  final String name;
  final String role;

  static LocalScienceStoryCharacter? fromJson(Map<String, Object?> json) {
    if (!_hasExactKeys(json, const {'id', 'name', 'role'})) return null;
    final id = _notationText(json['id'], maxLength: 64);
    final name = _notationText(json['name'], maxLength: 100);
    final role = _notationText(json['role'], maxLength: 200);
    if (id == null || name == null || role == null) return null;
    return LocalScienceStoryCharacter(id: id, name: name, role: role);
  }

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'role': role};
}

class LocalScienceStoryLine {
  const LocalScienceStoryLine({
    required this.id,
    required this.speakerId,
    required this.text,
  });

  final String id;
  final String speakerId;
  final String text;

  static LocalScienceStoryLine? fromJson(Map<String, Object?> json) {
    if (!_hasExactKeys(json, const {'id', 'speakerId', 'text'})) return null;
    final id = _notationText(json['id'], maxLength: 160);
    final speakerId = _notationText(json['speakerId'], maxLength: 64);
    final text = _notationText(json['text'], maxLength: 2000);
    if (id == null || speakerId == null || text == null) return null;
    return LocalScienceStoryLine(id: id, speakerId: speakerId, text: text);
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'speakerId': speakerId,
    'text': text,
  };
}

class LocalScienceStoryChoiceResponse {
  const LocalScienceStoryChoiceResponse({
    required this.optionId,
    required this.line,
  });

  final String optionId;
  final LocalScienceStoryLine line;

  static LocalScienceStoryChoiceResponse? fromJson(Map<String, Object?> json) {
    if (!_hasExactKeys(json, const {'optionId', 'line'})) return null;
    final optionId = _notationText(json['optionId'], maxLength: 128);
    final lineJson = _stringKeyedMap(json['line']);
    final storyLine = lineJson == null
        ? null
        : LocalScienceStoryLine.fromJson(lineJson);
    if (optionId == null || storyLine == null) return null;
    return LocalScienceStoryChoiceResponse(optionId: optionId, line: storyLine);
  }

  Map<String, Object?> toJson() => {
    'optionId': optionId,
    'line': line.toJson(),
  };
}

class LocalScienceStoryResolution {
  const LocalScienceStoryResolution({
    required this.outcome,
    required this.reason,
  });

  final String outcome;
  final String reason;

  static LocalScienceStoryResolution? fromJson(Map<String, Object?> json) {
    if (!_hasExactKeys(json, const {'outcome', 'reason'})) return null;
    final outcome = _notationText(json['outcome'], maxLength: 4000);
    final reason = _notationText(json['reason'], maxLength: 4000);
    if (outcome == null || reason == null) return null;
    return LocalScienceStoryResolution(outcome: outcome, reason: reason);
  }

  Map<String, Object?> toJson() => {'outcome': outcome, 'reason': reason};
}

/// catalog v8から損失なく復元する、1 Sectionに1本の固定Science Story。
class LocalScienceStory {
  const LocalScienceStory({
    required this.id,
    required this.title,
    required this.setting,
    required this.foundationNeedCode,
    required this.characters,
    required this.openingLines,
    required this.choiceLine,
    required this.choiceResponses,
    required this.resolutionLines,
    required this.scientificResolution,
    required this.punchline,
  });

  final String id;
  final String title;
  final String setting;
  final String foundationNeedCode;
  final List<LocalScienceStoryCharacter> characters;
  final List<LocalScienceStoryLine> openingLines;
  final LocalScienceStoryLine choiceLine;
  final List<LocalScienceStoryChoiceResponse> choiceResponses;
  final List<LocalScienceStoryLine> resolutionLines;
  final LocalScienceStoryResolution scientificResolution;
  final LocalScienceStoryLine punchline;

  LocalScienceStoryCharacter characterFor(String id) =>
      characters.singleWhere((character) => character.id == id);

  LocalScienceStoryChoiceResponse responseFor(String optionId) =>
      choiceResponses.singleWhere((response) => response.optionId == optionId);

  static LocalScienceStory? fromJson(Map<String, Object?> json) {
    if (!_hasExactKeys(json, const {
      'id',
      'title',
      'setting',
      'foundationNeedCode',
      'characters',
      'openingLines',
      'choiceLine',
      'choiceResponses',
      'resolutionLines',
      'scientificResolution',
      'punchline',
    })) {
      return null;
    }
    final id = _notationText(json['id'], maxLength: 160);
    final title = _notationText(json['title'], maxLength: 300);
    final setting = _notationText(json['setting'], maxLength: 1000);
    final foundationNeedCode = _needCodeText(json['foundationNeedCode']);
    final rawCharacters = json['characters'];
    final rawOpening = json['openingLines'];
    final rawResponses = json['choiceResponses'];
    final rawResolution = json['resolutionLines'];
    final choiceJson = _stringKeyedMap(json['choiceLine']);
    final scienceJson = _stringKeyedMap(json['scientificResolution']);
    final punchlineJson = _stringKeyedMap(json['punchline']);
    if (id == null ||
        title == null ||
        setting == null ||
        foundationNeedCode == null ||
        rawCharacters is! List ||
        rawCharacters.length < 2 ||
        rawCharacters.length > 5 ||
        rawCharacters.any((character) => character is! Map) ||
        rawOpening is! List ||
        rawOpening.length < 3 ||
        rawOpening.length > 6 ||
        rawOpening.any((entry) => entry is! Map) ||
        rawResponses is! List ||
        rawResponses.length != 3 ||
        rawResponses.any((entry) => entry is! Map) ||
        rawResolution is! List ||
        rawResolution.length < 2 ||
        rawResolution.length > 4 ||
        rawResolution.any((entry) => entry is! Map) ||
        choiceJson == null ||
        scienceJson == null ||
        punchlineJson == null) {
      return null;
    }

    final characters = <LocalScienceStoryCharacter>[];
    for (final rawCharacter in rawCharacters.cast<Map>()) {
      final characterJson = _stringKeyedMap(rawCharacter);
      if (characterJson == null) return null;
      final character = LocalScienceStoryCharacter.fromJson(characterJson);
      if (character == null) return null;
      characters.add(character);
    }
    final opening = _parseStoryLines(rawOpening);
    final resolution = _parseStoryLines(rawResolution);
    final choiceLine = LocalScienceStoryLine.fromJson(choiceJson);
    final scientificResolution = LocalScienceStoryResolution.fromJson(
      scienceJson,
    );
    final punchline = LocalScienceStoryLine.fromJson(punchlineJson);
    if (characters.map((character) => character.id).toSet().length !=
            characters.length ||
        opening == null ||
        resolution == null ||
        choiceLine == null ||
        scientificResolution == null ||
        punchline == null) {
      return null;
    }
    final responses = <LocalScienceStoryChoiceResponse>[];
    for (final rawResponse in rawResponses.cast<Map>()) {
      final responseJson = _stringKeyedMap(rawResponse);
      if (responseJson == null) return null;
      final response = LocalScienceStoryChoiceResponse.fromJson(responseJson);
      if (response == null) return null;
      responses.add(response);
    }
    if (responses.map((response) => response.optionId).toSet().length != 3) {
      return null;
    }

    final allLines = [
      ...opening,
      choiceLine,
      ...responses.map((response) => response.line),
      ...resolution,
      punchline,
    ];
    final characterIds = characters.map((character) => character.id).toSet();
    if (allLines.map((entry) => entry.id).toSet().length != allLines.length ||
        allLines.any((entry) => !characterIds.contains(entry.speakerId)) ||
        characterIds.any(
          (id) => !allLines.any((entry) => entry.speakerId == id),
        )) {
      return null;
    }
    return LocalScienceStory(
      id: id,
      title: title,
      setting: setting,
      foundationNeedCode: foundationNeedCode,
      characters: List.unmodifiable(characters),
      openingLines: opening,
      choiceLine: choiceLine,
      choiceResponses: List.unmodifiable(responses),
      resolutionLines: resolution,
      scientificResolution: scientificResolution,
      punchline: punchline,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'setting': setting,
    'foundationNeedCode': foundationNeedCode,
    'characters': [for (final character in characters) character.toJson()],
    'openingLines': [for (final line in openingLines) line.toJson()],
    'choiceLine': choiceLine.toJson(),
    'choiceResponses': [
      for (final response in choiceResponses) response.toJson(),
    ],
    'resolutionLines': [for (final line in resolutionLines) line.toJson()],
    'scientificResolution': scientificResolution.toJson(),
    'punchline': punchline.toJson(),
  };
}

List<LocalScienceStoryLine>? _parseStoryLines(Object? raw) {
  if (raw is! List || raw.any((entry) => entry is! Map)) return null;
  final lines = <LocalScienceStoryLine>[];
  for (final rawLine in raw.cast<Map>()) {
    final lineJson = _stringKeyedMap(rawLine);
    if (lineJson == null) return null;
    final line = LocalScienceStoryLine.fromJson(lineJson);
    if (line == null) return null;
    lines.add(line);
  }
  return List.unmodifiable(lines);
}

List<LocalNotationChoice>? _parseNotationChoices(Object? raw) {
  if (raw is! List ||
      raw.length < 2 ||
      raw.length > 5 ||
      raw.any((choice) => choice is! Map)) {
    return null;
  }
  final choices = <LocalNotationChoice>[];
  for (final rawChoice in raw.cast<Map>()) {
    final choiceJson = _stringKeyedMap(rawChoice);
    if (choiceJson == null) return null;
    final choice = LocalNotationChoice.fromJson(choiceJson);
    if (choice == null) return null;
    choices.add(choice);
  }
  if (choices.map((choice) => choice.id).toSet().length != choices.length) {
    return null;
  }
  return List.unmodifiable(choices);
}

/// 必修Speakingで端末内認識と照合する、catalog固定の短い語句。
///
/// [acceptedTranscripts]は意味上の別解ではなく、OSが返す表記揺れだけを持つ。
/// 回答・音声・認識結果はこの正本へ書き戻さない。
class LocalSpeakingPractice {
  const LocalSpeakingPractice({
    required this.targetPhrase,
    required this.acceptedTranscripts,
  });

  final String targetPhrase;
  final List<String> acceptedTranscripts;

  static LocalSpeakingPractice? fromJson(Map<String, Object?> json) {
    if (!_hasExactKeys(json, const {'targetPhrase', 'acceptedTranscripts'})) {
      return null;
    }
    final targetPhrase = json['targetPhrase'];
    final rawAccepted = json['acceptedTranscripts'];
    if (targetPhrase is! String ||
        targetPhrase != targetPhrase.trim() ||
        targetPhrase.runes.length < 12 ||
        targetPhrase.runes.length > 80 ||
        rawAccepted is! List ||
        rawAccepted.isEmpty ||
        rawAccepted.length > 5 ||
        rawAccepted.any((candidate) => candidate is! String)) {
      return null;
    }
    final accepted = rawAccepted.cast<String>();
    final normalizedAccepted = accepted.map(normalizeChallengeText).toList();
    if (accepted.first != targetPhrase ||
        accepted.any(
          (candidate) =>
              candidate != candidate.trim() ||
              candidate.runes.length < 12 ||
              candidate.runes.length > 80,
        ) ||
        normalizedAccepted.any((candidate) => candidate.isEmpty) ||
        normalizedAccepted.toSet().length != accepted.length) {
      return null;
    }
    return LocalSpeakingPractice(
      targetPhrase: targetPhrase,
      acceptedTranscripts: List.unmodifiable(accepted),
    );
  }

  Map<String, Object?> toJson() => {
    'targetPhrase': targetPhrase,
    'acceptedTranscripts': acceptedTranscripts,
  };
}

String? _notationText(Object? raw, {required int maxLength}) {
  if (raw is! String || raw.trim().isEmpty || raw.length > maxLength) {
    return null;
  }
  return raw;
}

final RegExp _needCodePattern = RegExp(
  r'^science\.[A-Za-z][A-Za-z0-9]{0,63}\.'
  r'(foundation|conditions|transfer|notation\.(arrow|equation|symbol|graph)|'
  r'listening\.(foundation|conditions|transfer)\.(transcript|meaning))$',
);

String? _needCodeText(Object? raw) =>
    raw is String && _needCodePattern.hasMatch(raw) ? raw : null;

bool _hasExactKeys(Map<String, Object?> json, Set<String> allowed) =>
    json.length == allowed.length && json.keys.every(allowed.contains);

bool _sameStringOrder(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

/// 教材の1節。**概念と1対1**なので、復習から読み直す先を指せる。
class Section {
  const Section({
    required this.conceptKey,
    required this.title,
    required this.body,
    required this.tryIt,
    required this.localCheckpoint,
    this.localSpeakingPractice,
    this.localPracticeVariants = const [],
    this.notationLab,
    this.scienceStory,
  });

  final String conceptKey;
  final String title;

  /// 段落。1段落1トピック
  final List<String> body;

  /// 手を動かして確かめられること
  final String tryIt;

  /// 旧fixtureと旧API向けの1周目。教材画面には描画しない。
  final LocalCheckpoint localCheckpoint;

  /// JSON/API/同梱catalog v8では必須。direct fixtureだけはnullを許す。
  final LocalSpeakingPractice? localSpeakingPractice;

  /// 原理 → 条件 → 別場面の順で巡回する3回分の端末内練習。
  ///
  /// 直接構築する既存テストだけは空を許す。その場合
  /// [practiceVariantForAttempt] が答えを含まない汎用promptと
  /// [localCheckpoint]から1件を組み立てる。JSON/API/同梱教材は必ず3件必要。
  final List<LocalPracticeVariant> localPracticeVariants;

  /// JSON/API/同梱catalog v8では必須。direct fixtureだけはnullを許す。
  final LocalNotationLab? notationLab;

  /// foundation variantと完全一致する固定Science Story。catalog v8では必須。
  final LocalScienceStory? scienceStory;

  LocalPracticeVariant practiceVariantForAttempt(int completedCount) {
    final variants = localPracticeVariants;
    if (variants.isEmpty) {
      return LocalPracticeVariant(
        stage: LocalPracticeStage.foundation,
        recallPrompt: '教材を見ずに、この概念の中心となる考えを自分の言葉で説明してください。',
        reasoningPrompt: 'その説明が成り立つ条件か、そうなる理由を一つ足してください。',
        transferPrompt: tryIt.trim().isEmpty
            ? 'この考えを使える具体的な場面を一つ考え、起きることを予想してください。'
            : tryIt,
        expectedOutcome: 'この旧形式の教材には、場面へ直接対応する比較結果がありません。',
        expectedReason: 'チェックポイントの正答を場面の答えとして流用せず、教材を読み直してください。',
        cognitiveTask: LocalCognitiveTask.safeLegacyFallback,
        checkpoint: localCheckpoint,
      );
    }
    final safeCount = completedCount < 0 ? 0 : completedCount;
    return variants[safeCount % variants.length];
  }

  static Section? fromJson(Map<String, Object?> json) {
    if (!_hasExactKeys(json, const {
      'conceptKey',
      'title',
      'body',
      'tryIt',
      'localCheckpoint',
      'localSpeakingPractice',
      'localPracticeVariants',
      'notationLab',
      'scienceStory',
    })) {
      return null;
    }
    final key = json['conceptKey'] as String?;
    if (key == null || key.isEmpty) return null;
    final raw = json['body'];
    final body = raw is List
        ? raw.whereType<String>().toList()
        : const <String>[];
    final rawCheckpoint = json['localCheckpoint'];
    final localCheckpoint = rawCheckpoint is Map
        ? LocalCheckpoint.fromJson(rawCheckpoint.cast<String, Object?>())
        : null;
    final speakingJson = _stringKeyedMap(json['localSpeakingPractice']);
    final localSpeakingPractice = speakingJson == null
        ? null
        : LocalSpeakingPractice.fromJson(speakingJson);
    final rawVariants = json['localPracticeVariants'];
    final notationJson = _stringKeyedMap(json['notationLab']);
    final notationLab = notationJson == null
        ? null
        : LocalNotationLab.fromJson(notationJson);
    final storyJson = _stringKeyedMap(json['scienceStory']);
    final scienceStory = storyJson == null
        ? null
        : LocalScienceStory.fromJson(storyJson);
    // 本文が無い節は出しても読めない
    // 3variantの無いv2キャッシュも落とし、正本から生成した同梱教材へ退避させる。
    if (body.isEmpty ||
        localCheckpoint == null ||
        localSpeakingPractice == null ||
        notationLab == null ||
        scienceStory == null ||
        rawVariants is! List ||
        rawVariants.length != LocalPracticeStage.values.length ||
        rawVariants.any((variant) => variant is! Map)) {
      return null;
    }
    final localPracticeVariants = <LocalPracticeVariant>[];
    for (final rawVariant in rawVariants.cast<Map>()) {
      final variant = LocalPracticeVariant.fromJson(
        rawVariant.cast<String, Object?>(),
      );
      if (variant == null) return null;
      localPracticeVariants.add(variant);
    }
    for (var i = 0; i < LocalPracticeStage.values.length; i++) {
      if (localPracticeVariants[i].stage != LocalPracticeStage.values[i]) {
        return null;
      }
      final variant = localPracticeVariants[i];
      final expectedNeedCode = 'science.$key.${variant.stage.wire}';
      final expectedListeningPrefix =
          'science.$key.listening.${variant.stage.wire}';
      final listening = variant.listeningNeedCodes;
      if (variant.cognitiveTask.needCode != expectedNeedCode ||
          listening == null ||
          listening.transcript != '$expectedListeningPrefix.transcript' ||
          listening.meaning != '$expectedListeningPrefix.meaning' ||
          variant.checkpoint.options.any(
            (option) => option.id == variant.checkpoint.correctOptionId
                ? option.needCode != null
                : option.needCode != expectedNeedCode,
          )) {
        return null;
      }
    }
    final foundation = localPracticeVariants.first;
    final foundationOptionIds = foundation.checkpoint.options
        .map((option) => option.id)
        .toSet();
    final storyResponseIds = scienceStory.choiceResponses
        .map((response) => response.optionId)
        .toSet();
    if (scienceStory.foundationNeedCode != 'science.$key.foundation' ||
        scienceStory.foundationNeedCode != foundation.cognitiveTask.needCode ||
        scienceStory.choiceLine.text != foundation.checkpoint.lure ||
        storyResponseIds.length != foundationOptionIds.length ||
        !storyResponseIds.containsAll(foundationOptionIds) ||
        !foundationOptionIds.containsAll(storyResponseIds) ||
        scienceStory.scientificResolution.outcome !=
            foundation.expectedOutcome ||
        scienceStory.scientificResolution.reason != foundation.expectedReason) {
      return null;
    }
    final expectedNotationCodes = {
      'science.$key.notation.arrow',
      'science.$key.notation.equation',
    };
    if (notationLab.orderTasks.map((task) => task.needCode).toSet().length !=
            2 ||
        !notationLab.orderTasks
            .map((task) => task.needCode)
            .toSet()
            .containsAll(expectedNotationCodes) ||
        notationLab.symbolMatch.needCode != 'science.$key.notation.symbol' ||
        notationLab.graphRead.needCode != 'science.$key.notation.graph') {
      return null;
    }
    // 旧クライアント用1周目と新配列の先頭が食い違うカタログは、同じ教材で
    // クライアント世代によって正答が変わるため拒否する。
    if (!_sameCheckpoint(
      localCheckpoint,
      localPracticeVariants.first.checkpoint,
    )) {
      return null;
    }
    return Section(
      conceptKey: key,
      title: json['title'] as String? ?? '',
      body: body,
      tryIt: json['tryIt'] as String? ?? '',
      localCheckpoint: localCheckpoint,
      localSpeakingPractice: localSpeakingPractice,
      localPracticeVariants: localPracticeVariants,
      notationLab: notationLab,
      scienceStory: scienceStory,
    );
  }

  Map<String, Object?> toJson() => {
    'conceptKey': conceptKey,
    'title': title,
    'body': body,
    'tryIt': tryIt,
    'localCheckpoint': localCheckpoint.toJson(),
    if (localSpeakingPractice != null)
      'localSpeakingPractice': localSpeakingPractice!.toJson(),
    'localPracticeVariants': [
      for (final variant in localPracticeVariants) variant.toJson(),
    ],
    if (notationLab != null) 'notationLab': notationLab!.toJson(),
    if (scienceStory != null) 'scienceStory': scienceStory!.toJson(),
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

  static bool _sameCheckpoint(LocalCheckpoint a, LocalCheckpoint b) {
    if (a.lure != b.lure ||
        a.correctOptionId != b.correctOptionId ||
        a.explanation != b.explanation ||
        a.options.length != b.options.length) {
      return false;
    }
    for (var i = 0; i < a.options.length; i++) {
      final left = a.options[i];
      final right = b.options[i];
      if (left.id != right.id ||
          left.text != right.text ||
          left.hint != right.hint ||
          left.needCode != right.needCode) {
        return false;
      }
    }
    return true;
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
    if (!_hasExactKeys(json, const {
      'id',
      'title',
      'brief',
      'concepts',
      'sectionCount',
      'sections',
    })) {
      return null;
    }
    final summary = UnitSummary.fromJson(json, allowSections: true);
    if (summary == null) return null;
    final raw = json['sections'];
    if (raw is! List || raw.any((section) => section is! Map)) return null;
    final sections = <Section>[];
    for (final rawSection in raw.cast<Map>()) {
      final section = Section.fromJson(rawSection.cast<String, Object?>());
      if (section == null) return null;
      sections.add(section);
    }
    if (summary.sectionCount != sections.length) return null;
    final sectionsByConcept = {
      for (final section in sections) section.conceptKey: section,
    };
    if (sectionsByConcept.length != sections.length ||
        summary.concepts.length != sections.length) {
      return null;
    }
    for (final concept in summary.concepts) {
      final section = sectionsByConcept[concept.key];
      if (section == null ||
          section.scienceStory?.title != concept.storyTitle) {
        return null;
      }
    }
    return UnitDetail(summary: summary, sections: sections);
  }

  Map<String, Object?> toJson() => {
    ...summary.toJson(),
    'sections': [for (final s in sections) s.toJson()],
  };
}
