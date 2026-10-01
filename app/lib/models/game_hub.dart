import 'package:flutter/foundation.dart';

/// 探究ノート以外のゲーム面へ渡す、表示専用の投影。
///
/// ここに自由記述・音声・選択肢は入れない。DBの事実を画面用に整えた値だけを
/// immutable DTOとして渡し、各画面が独自に進捗を推測しないようにする。
@immutable
class StoryEpisodeView {
  const StoryEpisodeView({
    required this.id,
    required this.title,
    required this.conceptLabel,
    required this.chapterLabel,
    required this.state,
    required this.minutes,
  });

  final String id;
  final String title;
  final String conceptLabel;
  final String chapterLabel;
  final GameContentState state;
  final int minutes;
}

enum GameContentState { locked, available, inProgress, completed, dueReview }

@immutable
class PracticeModeView {
  const PracticeModeView({
    required this.id,
    required this.title,
    required this.description,
    required this.kind,
    required this.enabled,
    this.badge,
  });

  final String id;
  final String title;
  final String description;
  final PracticeModeKind kind;
  final bool enabled;
  final String? badge;
}

enum PracticeModeKind {
  heartRecovery,
  personalized,
  resume,
  repair,
  listenSpeak,
  diagram,
  timed,
  match,
  lightning,
}

@immutable
class QuestView {
  const QuestView({
    required this.id,
    required this.title,
    required this.progress,
    required this.target,
    required this.gemReward,
  }) : assert(progress >= 0),
       assert(target > 0),
       assert(gemReward >= 0);

  final String id;
  final String title;
  final int progress;
  final int target;
  final int gemReward;

  bool get isComplete => progress >= target;
}

@immutable
class PlayerSummaryView {
  const PlayerSummaryView({
    required this.xp,
    required this.gems,
    required this.streakDays,
    required this.freezeCount,
    required this.challengeHearts,
    required this.maxChallengeHearts,
    required this.completedNodes,
    required this.totalNodes,
    required this.leagueName,
    required this.weeklyLeagueXp,
    required this.nextLeagueXp,
  });

  final int xp;
  final int gems;
  final int streakDays;
  final int freezeCount;
  final int challengeHearts;
  final int maxChallengeHearts;
  final int completedNodes;
  final int totalNodes;
  final String leagueName;
  final int weeklyLeagueXp;
  final int nextLeagueXp;
}
