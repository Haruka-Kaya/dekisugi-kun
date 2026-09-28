import '../../models/game_path.dart';
import '../../models/unit.dart';

/// 保存層から受け取る、Path表示に必要な最小の投影。
class GamePathProgressInput {
  const GamePathProgressInput({
    this.clearedNodeIds = const <String>{},
    this.inProgressNodeIds = const <String>{},
    this.reviewDueSkillIds = const <String>{},
    this.legendaryAvailableUnitIds = const <String>{},
    this.legendaryCompletedUnitIds = const <String>{},
    this.legendaryRewardEligibleUnitIds = const <String>{},
    this.legacyCompletedSkillIds = const <String>{},
  });

  final Set<String> clearedNodeIds;
  final Set<String> inProgressNodeIds;

  /// `${unitId}/${conceptKey}`。
  final Set<String> reviewDueSkillIds;

  /// Unit末Legendaryはconceptごとではなく、unit IDで状態を受け取る。
  final Set<String> legendaryAvailableUnitIds;
  final Set<String> legendaryCompletedUnitIds;

  /// 初回clearまたは期限到来後の再挑戦として、実報酬を得られるunit。
  /// 旧concept Legendary全clearからの表示上の昇格は含めない。
  final Set<String> legendaryRewardEligibleUnitIds;

  /// 旧端末内4段階を完走済みの概念。新Pathに存在しなかったStory/Listen/
  /// Speakまで完了扱いにせず、読解と構造taskだけを移行する。
  final Set<String> legacyCompletedSkillIds;
}

/// catalog v5の11概念を、同じ規則でゲームPathへ投影する。
///
/// 科学本文・問題・正答は複製せず、nodeは`unit/concept/kind`の安定IDで正本を
/// 参照する。将来catalog v5が明示nodeを持っても、このIDをlegacy bridgeに使う。
class GamePathProjection {
  const GamePathProjection();

  static const _requiredKinds = <GamePathNodeKind>[
    GamePathNodeKind.lesson,
    GamePathNodeKind.practice,
    GamePathNodeKind.story,
    GamePathNodeKind.listening,
    GamePathNodeKind.speaking,
    GamePathNodeKind.challenge,
  ];

  GamePathViewData build({
    required List<UnitSummary> catalog,
    required GamePathProgressInput progress,
    required GamePlayerStatus status,
    List<GameQuest> quests = const <GameQuest>[],
    bool schoolMode = false,
    int rewardXpAvailable = 10,
  }) {
    assert(rewardXpAvailable >= 0);
    final requiredIds = <String>[];
    for (final unit in catalog) {
      for (final concept in unit.concepts) {
        for (final kind in _requiredKinds) {
          requiredIds.add(nodeId(unit.id, concept.key, kind));
        }
      }
    }
    final cleared = <String>{...progress.clearedNodeIds};
    for (final skillId in progress.legacyCompletedSkillIds) {
      final parts = skillId.split('/');
      if (parts.length != 2) continue;
      // 旧フローで確実に行った「教材を読む」と「構造task」だけを橋渡しする。
      cleared.add(nodeId(parts[0], parts[1], GamePathNodeKind.lesson));
      cleared.add(nodeId(parts[0], parts[1], GamePathNodeKind.practice));
    }
    final currentRequiredId = requiredIds.cast<String?>().firstWhere(
      (id) => id != null && !cleared.contains(id),
      orElse: () => null,
    );

    final units = <GamePathUnit>[];
    for (var unitIndex = 0; unitIndex < catalog.length; unitIndex++) {
      final source = catalog[unitIndex];
      final nodes = <GamePathNode>[];
      for (final concept in source.concepts) {
        final skillId = '${source.id}/${concept.key}';
        for (final kind in _requiredKinds) {
          final id = nodeId(source.id, concept.key, kind);
          final state = _requiredState(
            id: id,
            skillId: skillId,
            currentRequiredId: currentRequiredId,
            progress: progress,
            cleared: cleared,
          );
          nodes.add(
            _node(
              id: id,
              conceptLabel: concept.label,
              kind: kind,
              state: state,
              schoolMode: schoolMode,
              rewardXpAvailable: rewardXpAvailable,
            ),
          );
        }
      }
      final legendaryId = unitLegendaryNodeId(source.id);
      final legendaryState =
          progress.legendaryCompletedUnitIds.contains(source.id)
          ? GamePathNodeState.legendaryCompleted
          : progress.inProgressNodeIds.contains(legendaryId)
          ? GamePathNodeState.inProgress
          : progress.legendaryAvailableUnitIds.contains(source.id)
          ? GamePathNodeState.legendaryAvailable
          : GamePathNodeState.locked;
      nodes.add(
        _node(
          id: legendaryId,
          conceptLabel: source.title,
          kind: GamePathNodeKind.legendary,
          state: legendaryState,
          schoolMode: schoolMode,
          rewardXpAvailable: rewardXpAvailable,
          rewardEligible: progress.legendaryRewardEligibleUnitIds.contains(
            source.id,
          ),
        ),
      );
      final completedSteps = nodes
          .where((node) => _requiredKinds.contains(node.kind))
          .where(
            (node) =>
                node.state == GamePathNodeState.completed ||
                node.state == GamePathNodeState.reviewDue,
          )
          .length;
      final totalSteps = source.concepts.length * _requiredKinds.length;
      if (totalSteps == 0) continue;
      units.add(
        GamePathUnit(
          id: source.id,
          ordinal: unitIndex + 1,
          title: source.title,
          objective: source.brief,
          nodes: List.unmodifiable(nodes),
          completedSteps: completedSteps,
          totalSteps: totalSteps,
          guidebookTitle: '${source.title}のガイド',
          characterReaction:
              currentRequiredId != null &&
                  nodes.any((n) => n.id == currentRequiredId)
              ? GameCharacterReaction.invite
              : GameCharacterReaction.none,
          characterMessage:
              currentRequiredId != null &&
                  nodes.any((n) => n.id == currentRequiredId)
              ? '次はここ。予想してから、ぼくの思い込みを直して！'
              : null,
        ),
      );
    }

    return GamePathViewData(
      status: status,
      units: List.unmodifiable(units),
      currentNodeId: currentRequiredId,
      quests: quests,
      schoolMode: schoolMode,
    );
  }

  static GamePathNodeState _requiredState({
    required String id,
    required String skillId,
    required String? currentRequiredId,
    required GamePathProgressInput progress,
    required Set<String> cleared,
  }) {
    if (cleared.contains(id)) {
      if (progress.reviewDueSkillIds.contains(skillId) &&
          id.endsWith(':practice')) {
        return GamePathNodeState.reviewDue;
      }
      return GamePathNodeState.completed;
    }
    if (progress.inProgressNodeIds.contains(id)) {
      return GamePathNodeState.inProgress;
    }
    return id == currentRequiredId
        ? GamePathNodeState.available
        : GamePathNodeState.locked;
  }

  static GamePathNode _node({
    required String id,
    required String conceptLabel,
    required GamePathNodeKind kind,
    required GamePathNodeState state,
    required bool schoolMode,
    required int rewardXpAvailable,
    bool rewardEligible = true,
  }) {
    final standardReward = '+$rewardXpAvailable XP（初回・期限復習・1日上限まで）';
    final (title, description, actions, minutes, reward) = switch (kind) {
      GamePathNodeKind.lesson => (
        'まず予想する',
        '$conceptLabelの原理を、答えを見る前に予想します。',
        const ['予想する', '教材を読む', '自分の答えと比べる'],
        4,
        standardReward,
      ),
      GamePathNodeKind.practice => (
        '図と条件を組む',
        '$conceptLabelを、選ぶ・分類する・順に組む操作で確かめます。',
        const ['図式化する', '理由を言葉にする', '教材と比べる'],
        4,
        standardReward,
      ),
      GamePathNodeKind.story => (
        '思い込み事件簿',
        'デキすぎ君の思い込みを、観察と理由で直します。',
        const ['物語を読む', '途中で判断する', '誤概念を直す'],
        3,
        standardReward,
      ),
      GamePathNodeKind.listening => (
        '説明を聞いて見抜く',
        '教材の説明を聞き、条件を判断してから正しい理由と照合します。',
        const ['説明を聞く', '条件を判断する', '教材と照合する'],
        3,
        standardReward,
      ),
      GamePathNodeKind.speaking => (
        '自分の言葉で説明',
        '声または文字で説明し、自分で再生・再読して教材と比べます。',
        const ['説明する', '自分で聞き直す', '理由を直す'],
        4,
        standardReward,
      ),
      GamePathNodeKind.challenge => (
        '$conceptLabelの章ボス',
        '$conceptLabelを別の場面へ使い、最後にまとめて答え合わせします。',
        const ['ヒントなしで解く', '別場面へ使う', 'まとめて比較する'],
        5,
        standardReward,
      ),
      GamePathNodeKind.legendary => (
        'レジェンド',
        '翌学習日から挑める、ヒントなしの高難度課題です。',
        const ['間隔を空けて思い出す', 'ヒントなしで解く', '転移を確かめる'],
        5,
        standardReward,
      ),
    };
    return GamePathNode(
      id: id,
      title: title,
      description: description,
      kind: kind,
      state: state,
      estimatedMinutes: minutes,
      learningActions: actions,
      rewardLabel:
          schoolMode ||
              !rewardEligible ||
              rewardXpAvailable == 0 ||
              state == GamePathNodeState.locked ||
              state == GamePathNodeState.completed ||
              state == GamePathNodeState.legendaryCompleted
          ? null
          : reward,
    );
  }

  static String nodeId(
    String unitId,
    String conceptKey,
    GamePathNodeKind kind,
  ) => 'path:v1:$unitId:$conceptKey:${kind.name}';

  /// Unit末に1件だけ置くv2 Legendaryの安定ID。
  static String unitLegendaryNodeId(String unitId) =>
      'path:v2:$unitId:unit:legendary';

  /// Unit Legendaryだけの間隔を管理し、concept skillを一括更新しない。
  static String unitLegendarySkillId(String unitId) =>
      'path:v2:$unitId:unit:legendary-skill';

  /// 旧concept Legendaryのappend-only履歴を読むためだけのID。
  static String legacyConceptLegendaryNodeId(
    String unitId,
    String conceptKey,
  ) => nodeId(unitId, conceptKey, GamePathNodeKind.legendary);
}
