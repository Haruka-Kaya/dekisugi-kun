/// ゲーム感のある学習Pathを描くための、表示専用DTO。
///
/// 正誤判定・保存・解放条件はここで計算しない。既存の学習ロジックが確定した
/// 結果だけを受け取り、UIが架空の進捗を作らないための境界にする。
library;

import '../config/app_language.dart';

enum GamePathNodeKind {
  lesson,
  story,
  listening,
  speaking,
  practice,
  challenge,
  legendary,
}

enum GamePathNodeState {
  locked,
  available,
  inProgress,
  completed,
  reviewDue,
  legendaryAvailable,
  legendaryCompleted,
}

enum GameCharacterReaction {
  none,
  invite,
  listening,
  thinking,
  encourage,
  speaking,
  celebrate,
  outOfTime,
  retry,
}

extension GameCharacterReactionPresentation on GameCharacterReaction {
  String get semanticsLabel => switch (this) {
    GameCharacterReaction.none => t('そばにいます', 'Right here with you'),
    GameCharacterReaction.invite => t(
      '次の学習へ手招きしています',
      'Inviting you to the next lesson',
    ),
    GameCharacterReaction.listening => t('話を聞いています', 'Listening to you'),
    GameCharacterReaction.thinking => t('一緒に考えています', 'Thinking it through with you'),
    GameCharacterReaction.encourage => t('学習を応援しています', 'Cheering you on'),
    GameCharacterReaction.speaking => t('説明しています', 'Explaining'),
    GameCharacterReaction.celebrate => t(
      '笑顔で成果を祝っています',
      'Smiling and celebrating your progress',
    ),
    GameCharacterReaction.outOfTime => t(
      '時間になったことを落ち着いて伝えています',
      'Calmly letting you know time is up',
    ),
    GameCharacterReaction.retry => t(
      'もう一度取り組めるよう案内しています',
      'Showing you how to try again',
    ),
  };
}

enum GameQuestKind { daily, monthly, friend, classroom }

enum GameQuestState { active, completed, claimed }

class GamePlayerStatus {
  const GamePlayerStatus({
    required this.streakDays,
    required this.streakFreezeRemaining,
    required this.gems,
    required this.hearts,
    this.maxHearts = 5,
    this.unlimitedHearts = false,
  }) : assert(streakDays >= 0),
       assert(streakFreezeRemaining >= 0),
       assert(gems >= 0),
       assert(hearts >= 0),
       assert(maxHearts > 0),
       assert(unlimitedHearts || hearts <= maxHearts);

  final int streakDays;
  final int streakFreezeRemaining;
  final int gems;
  final int hearts;
  final int maxHearts;

  /// 学校の必修Pathなど、間違いで学習を止めてはいけない経路。
  final bool unlimitedHearts;
}

class GamePathNode {
  const GamePathNode({
    required this.id,
    required this.title,
    required this.description,
    required this.kind,
    required this.state,
    this.completedLessons = 0,
    this.totalLessons = 1,
    this.estimatedMinutes,
    this.learningActions = const <String>[],
    this.rewardLabel,
  }) : assert(id != ''),
       assert(title != ''),
       assert(description != ''),
       assert(completedLessons >= 0),
       assert(totalLessons > 0),
       assert(completedLessons <= totalLessons),
       assert(estimatedMinutes == null || estimatedMinutes > 0);

  final String id;
  final String title;
  final String description;
  final GamePathNodeKind kind;
  final GamePathNodeState state;
  final int completedLessons;
  final int totalLessons;
  final int? estimatedMinutes;

  /// 正解ではなく、このノードで行う学習行為だけを渡す。
  final List<String> learningActions;

  /// 「+10 XP」等。学習内容より上へ置かず、無い場合は表示しない。
  final String? rewardLabel;

  double get progress => completedLessons / totalLessons;

  bool get canOpen => state != GamePathNodeState.locked;
}

class GamePathUnit {
  const GamePathUnit({
    required this.id,
    required this.ordinal,
    required this.title,
    required this.objective,
    required this.nodes,
    required this.completedSteps,
    required this.totalSteps,
    this.guidebookTitle,
    this.characterReaction = GameCharacterReaction.none,
    this.characterMessage,
  }) : assert(id != ''),
       assert(ordinal > 0),
       assert(title != ''),
       assert(objective != ''),
       assert(completedSteps >= 0),
       assert(totalSteps > 0),
       assert(completedSteps <= totalSteps),
       assert(
         characterReaction == GameCharacterReaction.none ||
             characterMessage != null,
       );

  final String id;
  final int ordinal;
  final String title;
  final String objective;
  final List<GamePathNode> nodes;
  final int completedSteps;
  final int totalSteps;
  final String? guidebookTitle;
  final GameCharacterReaction characterReaction;
  final String? characterMessage;

  double get progress => completedSteps / totalSteps;
}

class GameQuest {
  const GameQuest({
    required this.id,
    required this.title,
    required this.description,
    required this.kind,
    required this.state,
    required this.current,
    required this.target,
    this.rewardLabel,
    this.actionLabel,
  }) : assert(id != ''),
       assert(title != ''),
       assert(description != ''),
       assert(current >= 0),
       assert(target > 0),
       assert(current <= target),
       assert(actionLabel == null || actionLabel != '');

  final String id;
  final String title;
  final String description;
  final GameQuestKind kind;
  final GameQuestState state;
  final int current;
  final int target;
  final String? rewardLabel;

  /// Quest plannerが決めた固有CTA。nullは旧projectionとの後方互換表示。
  final String? actionLabel;

  double get progress => current / target;
}

class GamePathViewData {
  const GamePathViewData({
    required this.status,
    required this.units,
    this._title,
    this.currentNodeId,
    this.quests = const <GameQuest>[],
    this.schoolMode = false,
  });

  final String? _title;
  String get title => _title ?? t('学習パス', 'Learning Path');
  final GamePlayerStatus status;
  final List<GamePathUnit> units;
  final String? currentNodeId;
  final List<GameQuest> quests;

  /// 学校向けのコピー・リーグ・ハート挙動を上位Shellが切り替えるための印。
  final bool schoolMode;

  int get pendingQuestCount =>
      quests.where((quest) => quest.state == GameQuestState.active).length;
}
