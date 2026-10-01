import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/learning/domain/learning_progress.dart';
import 'package:dekisugi/learning/services/learning_monthly_badge_projection.dart';
import 'package:flutter_test/flutter_test.dart';

LearningProgressSnapshot _snapshot({
  LearningScope scope = LearningScope.personal,
  List<LearningQuestProgress> quests = const [],
}) => LearningProgressSnapshot(
  scope: scope,
  events: const [],
  nodes: const [],
  skills: const [],
  days: const [],
  freezes: const [],
  challengeHearts: scope == LearningScope.personal
      ? const LearningChallengeHeartState.initial()
      : null,
  rewards: const [],
  quests: quests,
  runs: const [],
);

LearningQuestProgress _quest({
  required String id,
  String version = 'monthly.v1',
  int target = 12,
  DateTime? rewardedAt,
}) => LearningQuestProgress(
  scope: LearningScope.personal,
  questInstanceId: id,
  progress: target,
  target: target,
  completedAt: rewardedAt,
  rewardedAt: rewardedAt,
  definitionVersion: version,
);

void main() {
  const projection = LearningMonthlyBadgeProjection();

  test('rewarded済みの固定monthly questだけを月ごとに一意なbadgeへ投影する', () {
    final unlockedAt = DateTime.utc(2026, 8, 20);
    final result = projection.build(
      _snapshot(
        quests: [
          _quest(id: 'monthly:2026-08:twelve-actions', rewardedAt: unlockedAt),
          _quest(id: 'monthly:2026-08:twelve-actions', rewardedAt: unlockedAt),
          _quest(
            id: 'monthly:2026-09:twelve-actions',
            rewardedAt: DateTime.utc(2026, 9, 18),
          ),
        ],
      ),
    );

    expect(result, hasLength(2));
    expect(result.first.learningMonth, '2026-09');
    expect(result.last.badgeId, 'badge.monthly.2026-08.twelve-actions');
    expect(result.last.sourceQuestInstanceId, 'monthly:2026-08:twelve-actions');
  });

  test('未報酬・未知version・異なるtarget・学校scopeはbadgeを作らない', () {
    expect(
      projection.build(
        _snapshot(
          quests: [
            _quest(id: 'monthly:2026-08:twelve-actions'),
            _quest(
              id: 'monthly:2026-08:twelve-actions',
              version: 'monthly.unknown',
              rewardedAt: DateTime.utc(2026, 8, 20),
            ),
            _quest(
              id: 'monthly:2026-08:twelve-actions',
              target: 1,
              rewardedAt: DateTime.utc(2026, 8, 20),
            ),
            _quest(
              id: 'monthly:2026-08:buy-badge',
              rewardedAt: DateTime.utc(2026, 8, 20),
            ),
          ],
        ),
      ),
      isEmpty,
    );
    expect(
      projection.build(
        _snapshot(
          scope: LearningScope.schoolLocal,
          quests: [
            _quest(
              id: 'monthly:2026-08:twelve-actions',
              rewardedAt: DateTime.utc(2026, 8, 20),
            ),
          ],
        ),
      ),
      isEmpty,
    );
  });
}
