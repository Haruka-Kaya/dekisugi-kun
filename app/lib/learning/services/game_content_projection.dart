import '../../config/app_language.dart' as localize;
import '../../models/game_hub.dart';
import '../../models/game_path.dart';
import '../../models/unit.dart';
import 'game_path_projection.dart';
import '../../config/app_language.dart';

class GameContentProjectionResult {
  const GameContentProjectionResult({
    required this.stories,
    required this.practiceModes,
  });

  final List<StoryEpisodeView> stories;
  final List<PracticeModeView> practiceModes;
}

/// 探究ノートと別タブを同じnode状態から組み立てる。
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
        ? t('任意・試行余力は無制限', 'Optional · Unlimited hearts')
        : timedChallengeGemCost == null
        ? t('任意・誤答は試行余力-1', 'Optional · Wrong answer: -1 heart')
        : timedChallengePassActive
        ? t(
            '今日の時間観察券あり・誤答は試行余力-1',
            'Today\'s pass active · Wrong answer: -1 heart',
          )
        : canPurchaseTimedChallengePass
        ? t(
            '◆ $timedChallengeGemCostで今日参加・誤答は試行余力-1',
            '◆ $timedChallengeGemCost to join today · Wrong answer: -1 heart',
          )
        : t(
            '結晶不足・対応づけ実験／連続観察は無料',
            'Not enough gems · Match / Lightning are free',
          );

    return GameContentProjectionResult(
      stories: List.unmodifiable(stories),
      practiceModes: List.unmodifiable([
        PracticeModeView(
          id: 'practice:personalized',
          title: t('今日の個別練習', 'Today\'s personal practice'),
          description: duePracticeCount == 0
              ? t(
                  '期限が来るまでは探究ノートを進めます。',
                  'Continue the Path until something\'s due.',
                )
              : t(
                  '期限が来た概念を、別の操作で取り出します。',
                  'Recall due concepts with a different activity.',
                ),
          kind: PracticeModeKind.personalized,
          enabled: duePracticeCount > 0,
          badge: duePracticeCount == 0
              ? null
              : t('$duePracticeCount件', '$duePracticeCount'),
        ),
        PracticeModeView(
          id: 'practice:resume',
          title: t('続きから', 'Continue'),
          description: resumeCount == 0
              ? t('中断中の探究課題はありません。', 'No paused Path tasks.')
              : t(
                  '中断した探究課題を、保存された位置から再開します。',
                  'Resume a paused Path task from where you saved it.',
                ),
          kind: PracticeModeKind.resume,
          enabled: resumeCount > 0,
          badge: resumeCount == 0 ? null : t('$resumeCount件', '$resumeCount'),
        ),
        PracticeModeView(
          id: 'practice:repair',
          title: t('思い込みを直す', 'Fix misconceptions'),
          description: activeRepairCount == 0
              ? t(
                  '固定課題で見つかった復習ポイントはありません。',
                  'No review points found in fixed tasks.',
                )
              : t(
                  '見つかった復習ポイントを、対応する固定課題で確かめます。',
                  'Check the review points you found with matching fixed tasks.',
                ),
          kind: PracticeModeKind.repair,
          enabled: activeRepairCount > 0,
          badge: activeRepairCount == 0
              ? null
              : t('$activeRepairCount件', '$activeRepairCount'),
        ),
        PracticeModeView(
          id: 'practice:listen-speak',
          title: t('聞く・話すラボ', 'Listen & Speak Lab'),
          description: t(
            '声と文字を同格にして、自分の説明を聞き直します。',
            'Treat voice and text equally, and listen back to your own explanation.',
          ),
          kind: PracticeModeKind.listenSpeak,
          enabled: hasListenSpeak,
        ),
        PracticeModeView(
          id: 'practice:diagram',
          title: t('図と条件のラボ', 'Diagrams & Conditions Lab'),
          description: t(
            '選ぶ・分類する・順に組む操作で関係を確かめます。',
            'Check relationships by choosing, sorting, and ordering.',
          ),
          kind: PracticeModeKind.diagram,
          enabled: hasDiagram,
        ),
        PracticeModeView(
          id: 'practice:timed',
          title: t('時間観察', 'Time Challenge'),
          description: t(
            '時間を観察しながら、固定の転移問題を解きます。',
            'Solve fixed transfer problems within the time limit.',
          ),
          kind: PracticeModeKind.timed,
          enabled: hasChallenge && timedHasEntry,
          badge: timedBadge,
        ),
        PracticeModeView(
          id: 'practice:match',
          title: localize.t('対応づけ実験', "Matching Lab"),
          description: t(
            '観察・理由・訂正を、対応する説明へすばやく結びます。',
            'Quickly link observations, reasons, and corrections to the right explanations.',
          ),
          kind: PracticeModeKind.match,
          enabled: hasChallenge,
          badge: hasChallenge
              ? schoolMode
                    ? t('45秒・試行余力は無制限', '45 sec · Unlimited hearts')
                    : t('45秒・誤答は試行余力-1', '45 sec · Wrong answer: -1 heart')
              : null,
        ),
        PracticeModeView(
          id: 'practice:lightning',
          title: localize.t('連続観察', "Observation Sprint"),
          description: t(
            '3ラウンドの思い込み訂正を順番に判断します。',
            'Judge 3 rounds of misconception fixes in order.',
          ),
          kind: PracticeModeKind.lightning,
          enabled: hasChallenge,
          badge: hasChallenge
              ? schoolMode
                    ? t('50秒・試行余力は無制限', '50 sec · Unlimited hearts')
                    : t('50秒・誤答は試行余力-1', '50 sec · Wrong answer: -1 heart')
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
