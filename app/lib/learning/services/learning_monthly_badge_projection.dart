import '../domain/learning_event.dart';
import '../domain/learning_monthly_badge.dart';
import '../domain/learning_progress.dart';

/// rewarded済みmonthly questを、購入不可のbadge collectionへ投影する。
final class LearningMonthlyBadgeProjection {
  const LearningMonthlyBadgeProjection({
    this.catalog = const LearningMonthlyBadgeCatalogV1(),
  });

  final LearningMonthlyBadgeCatalogV1 catalog;

  List<LearningMonthlyBadgeAward> build(LearningProgressSnapshot snapshot) {
    if (snapshot.scope != LearningScope.personal) return const [];
    final byId = <String, LearningMonthlyBadgeAward>{};
    for (final quest in snapshot.quests) {
      final award = catalog.awardFor(
        questInstanceId: quest.questInstanceId,
        savedDefinitionVersion: quest.definitionVersion,
        savedTarget: quest.target,
        rewardedAt: quest.rewardedAt,
      );
      if (award != null) byId[award.badgeId] = award;
    }
    final result = byId.values.toList()
      ..sort((left, right) {
        final month = right.learningMonth.compareTo(left.learningMonth);
        return month != 0 ? month : left.badgeId.compareTo(right.badgeId);
      });
    return List.unmodifiable(result);
  }
}
