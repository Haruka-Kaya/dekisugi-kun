import '../../models/game_hub.dart';
import '../../models/game_path.dart';
import '../../models/unit.dart';
import 'game_path_projection.dart';

class GameContentProjectionResult {
  const GameContentProjectionResult({
    required this.stories,
    required this.practiceModes,
  });

  final List<StoryEpisodeView> stories;
  final List<PracticeModeView> practiceModes;
}

/// Pathと別タブを同じnode状態から組み立てる。
///
/// Story一覧や練習ラボが独自に「完了したはず」と推測しないための境界。
/// 正答・教材本文は複製せず、表示用IDから起動時にcatalog detailを読み直す。
class GameContentProjection {
  const GameContentProjection();

  GameContentProjectionResult build({
    required List<UnitSummary> catalog,
    required GamePathViewData path,
    required int duePracticeCount,
    int activeRepairCount = 0,
    bool schoolMode = false,
    int? timedChallengeGemCost,
    bool timedChallengePassActive = false,
    bool canPurchaseTimedChallengePass = true,
  }) {
    if (activeRepairCount < 0) {
      throw ArgumentError.value(
        activeRepairCount,
        'activeRepairCount',
        'non-negative count required',
      );
    }
    if (timedChallengeGemCost != null && timedChallengeGemCost <= 0) {
      throw ArgumentError.value(
        timedChallengeGemCost,
        'timedChallengeGemCost',
        'positive gem cost required',
      );
    }
    final pathNodes = {
      for (final unit in path.units)
        for (final node in unit.nodes) node.id: node,
    };
    final stories = <StoryEpisodeView>[];
    var episodeNumber = 0;
    for (final unit in catalog) {
      for (final concept in unit.concepts) {
        episodeNumber++;
        final nodeId = GamePathProjection.nodeId(
          unit.id,
          concept.key,
          GamePathNodeKind.story,
        );
        final node = pathNodes[nodeId];
        stories.add(
          StoryEpisodeView(
            id: nodeId,
            title: concept.storyTitle,
            conceptLabel: concept.label,
            chapterLabel: 'CASE ${episodeNumber.toString().padLeft(2, '0')}',
            state: _contentState(node?.state),
            minutes: node?.estimatedMinutes ?? 3,
          ),
        );
      }
    }

    final nodes = path.units.expand((unit) => unit.nodes).toList();
    final resumeCount = nodes
        .where((node) => node.state == GamePathNodeState.inProgress)
        .length;
    final hasListenSpeak = nodes.any(
      (node) =>
          node.canOpen &&
          (node.kind == GamePathNodeKind.listening ||
              node.kind == GamePathNodeKind.speaking),
    );
    final hasDiagram = nodes.any(
      (node) => node.canOpen && node.kind == GamePathNodeKind.practice,
    );
    final hasChallenge = nodes
        .where((node) => node.kind == GamePathNodeKind.challenge)
        .any((node) => node.state != GamePathNodeState.locked);
    final timedHasEntry =
        schoolMode ||
        timedChallengeGemCost == null ||
        timedChallengePassActive ||
        canPurchaseTimedChallengePass;
    final timedBadge = !hasChallenge
        ? null
        : schoolMode
        ? '任意・ハート無制限'
        : timedChallengeGemCost == null
        ? '任意・誤答はハート-1'
        : timedChallengePassActive
        ? '今日の挑戦券あり・誤答はハート-1'
        : canPurchaseTimedChallengePass
        ? '◆ $timedChallengeGemCostで今日参加・誤答はハート-1'
        : '結晶不足・Match / Lightningは無料';

    return GameContentProjectionResult(
      stories: List.unmodifiable(stories),
      practiceModes: List.unmodifiable([
        PracticeModeView(
          id: 'practice:personalized',
          title: '今日の個別練習',
          description: duePracticeCount == 0
              ? '期限が来るまではPathを進めます。'
              : '期限が来た概念を、別の操作で取り出します。',
          kind: PracticeModeKind.personalized,
          enabled: duePracticeCount > 0,
          badge: duePracticeCount == 0 ? null : '$duePracticeCount件',
        ),
        PracticeModeView(
          id: 'practice:resume',
          title: '続きから',
          description: resumeCount == 0
              ? '中断中のPath課題はありません。'
              : '中断したPath課題を、保存された位置から再開します。',
          kind: PracticeModeKind.resume,
          enabled: resumeCount > 0,
          badge: resumeCount == 0 ? null : '$resumeCount件',
        ),
        PracticeModeView(
          id: 'practice:repair',
          title: '思い込みを直す',
          description: activeRepairCount == 0
              ? '固定課題で見つかった復習ポイントはありません。'
              : '見つかった復習ポイントを、対応する固定課題で確かめます。',
          kind: PracticeModeKind.repair,
          enabled: activeRepairCount > 0,
          badge: activeRepairCount == 0 ? null : '$activeRepairCount件',
        ),
        PracticeModeView(
          id: 'practice:listen-speak',
          title: '聞く・話すラボ',
          description: '声と文字を同格にして、自分の説明を聞き直します。',
          kind: PracticeModeKind.listenSpeak,
          enabled: hasListenSpeak,
        ),
        PracticeModeView(
          id: 'practice:diagram',
          title: '図と条件のラボ',
          description: '選ぶ・分類する・順に組む操作で関係を確かめます。',
          kind: PracticeModeKind.diagram,
          enabled: hasDiagram,
        ),
        PracticeModeView(
          id: 'practice:timed',
          title: 'タイムチャレンジ',
          description: '固定の転移問題を時間内に解きます。',
          kind: PracticeModeKind.timed,
          enabled: hasChallenge && timedHasEntry,
          badge: timedBadge,
        ),
        PracticeModeView(
          id: 'practice:match',
          title: 'Match Lab',
          description: '観察・理由・訂正を、対応する説明へすばやく結びます。',
          kind: PracticeModeKind.match,
          enabled: hasChallenge,
          badge: hasChallenge
              ? schoolMode
                    ? '45秒・ハート無制限'
                    : '45秒・誤答はハート-1'
              : null,
        ),
        PracticeModeView(
          id: 'practice:lightning',
          title: 'Lightning',
          description: '3ラウンドの思い込み訂正を順番に判断します。',
          kind: PracticeModeKind.lightning,
          enabled: hasChallenge,
          badge: hasChallenge
              ? schoolMode
                    ? '50秒・ハート無制限'
                    : '50秒・誤答はハート-1'
              : null,
        ),
      ]),
    );
  }

  static GameContentState _contentState(GamePathNodeState? state) =>
      switch (state) {
        GamePathNodeState.available => GameContentState.available,
        GamePathNodeState.inProgress => GameContentState.inProgress,
        GamePathNodeState.completed ||
        GamePathNodeState.legendaryCompleted => GameContentState.completed,
        GamePathNodeState.reviewDue ||
        GamePathNodeState.legendaryAvailable => GameContentState.dueReview,
        GamePathNodeState.locked || null => GameContentState.locked,
      };
}
