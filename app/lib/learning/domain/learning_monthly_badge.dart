/// 月間クエストからだけ獲得できる、非購入のコレクション実績。
library;

import '../../config/app_language.dart';

enum LearningMonthlyBadgeStyle { orbit, telescope, prism, constellation }

final class LearningMonthlyBadgeAward {
  const LearningMonthlyBadgeAward({
    required this.badgeId,
    required this.sourceQuestInstanceId,
    required this.learningMonth,
    required this.title,
    required this.description,
    required this.style,
    required this.unlockedAt,
  });

  final String badgeId;
  final String sourceQuestInstanceId;
  final String learningMonth;
  final String title;
  final String description;
  final LearningMonthlyBadgeStyle style;
  final DateTime unlockedAt;
}

/// launch版で実在するmonthly questとbadgeの1対1対応。
///
/// 購入商品とは別catalogにし、結晶残高や装備状態からbadgeを作れないようにする。
final class LearningMonthlyBadgeCatalogV1 {
  const LearningMonthlyBadgeCatalogV1();

  static const String questKey = 'twelve-actions';
  static const String definitionVersion = 'monthly.v1';
  static const int target = 12;

  LearningMonthlyBadgeAward? awardFor({
    required String questInstanceId,
    required String savedDefinitionVersion,
    required int savedTarget,
    required DateTime? rewardedAt,
  }) {
    if (rewardedAt == null ||
        savedDefinitionVersion != definitionVersion ||
        savedTarget != target) {
      return null;
    }
    final match = _monthlyQuestPattern.firstMatch(questInstanceId);
    if (match == null || match.group(2) != questKey) return null;
    final learningMonth = match.group(1)!;
    final monthNumber = int.parse(learningMonth.substring(5, 7));
    final style = LearningMonthlyBadgeStyle
        .values[(monthNumber - 1) % LearningMonthlyBadgeStyle.values.length];
    final parts = learningMonth.split('-');
    return LearningMonthlyBadgeAward(
      badgeId: 'badge.monthly.$learningMonth.$questKey',
      sourceQuestInstanceId: questInstanceId,
      learningMonth: learningMonth,
      title: t(
        '${parts[0]}年${int.parse(parts[1])}月 観測バッジ',
        'Observation Badge ${int.parse(parts[1])}/${parts[0]}',
      ),
      description: t(
        '意味のある学習を12件終えた月の記録です。',
        'A record of a month with 12 meaningful learning activities done.',
      ),
      style: style,
      unlockedAt: rewardedAt,
    );
  }
}

final RegExp _monthlyQuestPattern = RegExp(
  r'^monthly:(\d{4}-(?:0[1-9]|1[0-2])):([A-Za-z0-9._/-]+)$',
);
