import '../../models/day_key.dart';
import '../domain/learning_event.dart';
import '../domain/learning_monthly_badge.dart';
import '../domain/learning_policy.dart';
import '../domain/learning_progress.dart';
import '../../config/app_language.dart';

/// Homeが保存rulesと表示projectionへ同じquest定義を渡すためのpure DTO。
///
/// 回答、選択肢、正誤回数、速度、録音、自由記述は入力にも出力にも持たない。
/// Homeは同じplanの[commitRules]を保存境界へ、[questTitles]と
/// [activeQuestDefinitions]を`LearningGameProjection.build`へ渡す。
final class LearningQuestPlan {
  LearningQuestPlan({
    required this.learningDay,
    required this.scope,
    required this.dailyDefinition,
    required Iterable<LearningQuestDefinition> activeQuestDefinitions,
    required Map<String, String> questTitles,
  }) : activeQuestDefinitions = List.unmodifiable(activeQuestDefinitions),
       questTitles = Map.unmodifiable(questTitles);

  final String learningDay;
  final LearningScope scope;
  final LearningQuestDefinition dailyDefinition;
  final List<LearningQuestDefinition> activeQuestDefinitions;
  final Map<String, String> questTitles;

  /// `SessionLearningProgressStore`へそのまま渡す同一定義。
  LearningCommitRules get commitRules =>
      LearningCommitRules(quests: activeQuestDefinitions);

  String get dailyTitle => questTitles[dailyDefinition.questInstanceId]!;
}

/// 達成可能性を優先した日次／月次quest planner。
///
/// personalの日次目標はmeaningful action 1件と2件を学習日ごとに交互にする。
/// kind / originを限定しないので、未解放の特定activityや期限前の復習を要求しない。
/// 2件日は同じcleared nodeの周回では進まず、保存層がmeaningfulと確定した別node
/// 初回clearまたは期限到来後のspaced retrievalだけが2件目になる。
///
/// 既存の1件questを同日の途中で2件へ差し替えないよう、保存済みの既知daily
/// instanceがあればそれを優先する。回答等は見ず、questの公開metadataだけを使う。
final class LearningQuestPlannerV1 {
  const LearningQuestPlannerV1();

  static const String oneActionKey = 'one-action';
  static const String oneActionDefinitionVersion = 'daily.v1';
  static const String twoActionsKey = 'two-actions';
  static const String twoActionsDefinitionVersion = 'daily.v2';

  static const int oneActionTarget = 1;
  static const int twoActionsTarget = 2;
  static const int personalDailyRewardGems = 1;
  static const int personalMonthlyRewardGems = 8;

  static String get schoolDailyTitle => t('今日の学習を1件終える', 'Finish 1 learning activity today');
  static String get personalOneActionTitle => t('今日、意味のある学習を1件終える', 'Finish 1 meaningful learning activity today');
  static String get personalTwoActionsTitle => t('今日、意味のある学習を2件終える', 'Finish 2 meaningful learning activities today');

  LearningQuestPlan build({
    required DateTime now,
    required LearningScope scope,
    Iterable<LearningQuestProgress> persistedQuests = const [],
  }) {
    final learningDay = dayKeyOf(now.toLocal());
    final schoolMode = scope == LearningScope.schoolLocal;
    final daily = schoolMode
        ? _oneActionDefinition(learningDay: learningDay, rewardGems: 0)
        : _personalDailyDefinition(
            learningDay: learningDay,
            persistedQuests: persistedQuests,
          );
    final learningMonth = learningDay.substring(0, 7);
    final definitions = <LearningQuestDefinition>[
      daily,
      if (!schoolMode)
        LearningQuestDefinition.monthly(
          learningMonth: learningMonth,
          questKey: LearningMonthlyBadgeCatalogV1.questKey,
          definitionVersion: LearningMonthlyBadgeCatalogV1.definitionVersion,
          target: LearningMonthlyBadgeCatalogV1.target,
          rewardGems: personalMonthlyRewardGems,
        ),
    ];
    final titles = <String, String>{
      daily.questInstanceId: schoolMode
          ? schoolDailyTitle
          : daily.target == oneActionTarget
          ? personalOneActionTitle
          : personalTwoActionsTitle,
      if (!schoolMode)
        'monthly:$learningMonth:${LearningMonthlyBadgeCatalogV1.questKey}':
            t('今月、意味のある学習を${LearningMonthlyBadgeCatalogV1.target}件終える', 'Finish ${LearningMonthlyBadgeCatalogV1.target} meaningful learning activities this month'),
    };
    return LearningQuestPlan(
      learningDay: learningDay,
      scope: scope,
      dailyDefinition: daily,
      activeQuestDefinitions: definitions,
      questTitles: titles,
    );
  }

  LearningQuestDefinition _personalDailyDefinition({
    required String learningDay,
    required Iterable<LearningQuestProgress> persistedQuests,
  }) {
    final oneId = _dailyId(learningDay, oneActionKey);
    final twoId = _dailyId(learningDay, twoActionsKey);
    final materialized = persistedQuests
        .where((quest) => quest.scope == LearningScope.personal)
        .where(
          (quest) =>
              quest.questInstanceId == oneId || quest.questInstanceId == twoId,
        )
        .toList(growable: false);
    if (materialized.length > 1) {
      throw StateError('multiple daily quest variants were materialized');
    }
    if (materialized case [final saved]) {
      if (saved.questInstanceId == oneId) {
        _requireCompatibleMaterializedQuest(
          saved,
          target: oneActionTarget,
          definitionVersion: oneActionDefinitionVersion,
        );
        return _oneActionDefinition(
          learningDay: learningDay,
          rewardGems: personalDailyRewardGems,
        );
      }
      _requireCompatibleMaterializedQuest(
        saved,
        target: twoActionsTarget,
        definitionVersion: twoActionsDefinitionVersion,
      );
      return _twoActionsDefinition(learningDay);
    }

    return _dayOrdinal(learningDay).isEven
        ? _oneActionDefinition(
            learningDay: learningDay,
            rewardGems: personalDailyRewardGems,
          )
        : _twoActionsDefinition(learningDay);
  }

  static LearningQuestDefinition _oneActionDefinition({
    required String learningDay,
    required int rewardGems,
  }) => LearningQuestDefinition.daily(
    learningDay: learningDay,
    questKey: oneActionKey,
    definitionVersion: oneActionDefinitionVersion,
    target: oneActionTarget,
    rewardGems: rewardGems,
  );

  static LearningQuestDefinition _twoActionsDefinition(String learningDay) =>
      LearningQuestDefinition.daily(
        learningDay: learningDay,
        questKey: twoActionsKey,
        definitionVersion: twoActionsDefinitionVersion,
        target: twoActionsTarget,
        rewardGems: personalDailyRewardGems,
      );

  static void _requireCompatibleMaterializedQuest(
    LearningQuestProgress saved, {
    required int target,
    required String definitionVersion,
  }) {
    if (saved.target != target ||
        saved.definitionVersion != definitionVersion) {
      throw StateError('materialized daily quest definition is incompatible');
    }
  }

  static String _dailyId(String learningDay, String key) =>
      'daily:$learningDay:$key';

  static int _dayOrdinal(String learningDay) => DateTime.parse(
    '${learningDay}T00:00:00Z',
  ).difference(DateTime.utc(1970)).inDays;
}
