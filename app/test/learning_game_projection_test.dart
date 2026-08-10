import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/learning/domain/learning_economy.dart';
import 'package:dekisugi/learning/domain/learning_policy.dart';
import 'package:dekisugi/learning/domain/learning_progress.dart';
import 'package:dekisugi/learning/services/game_path_projection.dart';
import 'package:dekisugi/learning/services/learning_game_projection.dart';
import 'package:dekisugi/models/game_path.dart';
import 'package:dekisugi/models/unit.dart';
import 'package:flutter_test/flutter_test.dart';

const _catalog = [
  UnitSummary(
    id: 'motion',
    title: '運動',
    brief: '力と運動を説明する',
    concepts: [UnitConcept(key: 'fall', label: '落下', storyTitle: '落下事件')],
    sectionCount: 1,
  ),
];

const _twoConceptCatalog = [
  UnitSummary(
    id: 'motion',
    title: '運動',
    brief: '力と運動を説明する',
    concepts: [
      UnitConcept(key: 'fall', label: '落下', storyTitle: '落下事件'),
      UnitConcept(key: 'inertia', label: '慣性', storyTitle: '慣性事件'),
    ],
    sectionCount: 2,
  ),
];

LearningProgressSnapshot snapshot({
  LearningScope scope = LearningScope.personal,
  List<LearningNodeProgress> nodes = const [],
  List<LearningSkillProgress> skills = const [],
  List<LearningDay> days = const [],
  List<LearningStreakFreeze> freezes = const [],
  List<LearningEventRecord> events = const [],
  List<LearningRewardEntry> rewards = const [],
  List<LearningQuestProgress> quests = const [],
  List<LearningRun> runs = const [],
  List<LearningGemSpend> gemSpends = const [],
  LearningCosmeticState? cosmetics,
  List<LearningLocalCoopRun> localCoopRuns = const [],
  List<LearningLeagueWeek> leagueHistory = const [],
}) => LearningProgressSnapshot(
  scope: scope,
  events: events,
  nodes: nodes,
  skills: skills,
  days: days,
  freezes: freezes,
  challengeHearts: scope == LearningScope.personal
      ? const LearningChallengeHeartState.initial()
      : null,
  rewards: rewards,
  quests: quests,
  runs: runs,
  gemSpends: gemSpends,
  cosmetics: cosmetics,
  localCoopRuns: localCoopRuns,
  leagueHistory: leagueHistory,
);

void main() {
  const projection = LearningGameProjection();

  test('node/skill/day/rewardをPathと全タブの同じ値へ投影する', () {
    final lessonId = GamePathProjection.nodeId(
      'motion',
      'fall',
      GamePathNodeKind.lesson,
    );
    final result = projection.build(
      catalog: _catalog,
      snapshot: snapshot(
        nodes: [
          LearningNodeProgress(
            scope: LearningScope.personal,
            nodeId: lessonId,
            state: LearningNodeState.cleared,
            attemptCount: 1,
            bestEvidence: LearningEvidenceLevel.selfCompared,
            lastAttemptDay: '2026-08-10',
            lastEventId: 'event-1',
            completedAt: DateTime.utc(2026, 8, 10),
            contentVersion: 'v1',
          ),
        ],
        skills: const [
          LearningSkillProgress(
            scope: LearningScope.personal,
            skillId: 'motion/fall',
            lastOutcome: LearningSkillOutcome.completed,
            successfulRetrievals: 0,
            lastAttemptDay: '2026-08-10',
            lastSuccessDay: '2026-08-10',
            nextDueDay: '2026-08-11',
            lastEventId: 'event-1',
          ),
        ],
        days: [
          LearningDay(
            scope: LearningScope.personal,
            day: '2026-08-10',
            qualifyingCount: 1,
            firstEventAt: DateTime.utc(2026, 8, 10),
            lastEventAt: DateTime.utc(2026, 8, 10),
          ),
        ],
        rewards: [
          LearningRewardEntry(
            entryId: 'reward-1',
            scope: LearningScope.personal,
            type: LearningRewardType.xp,
            amount: 10,
            reason: 'node-first',
            sourceEventId: 'event-1',
            createdAt: DateTime.utc(2026, 8, 10),
          ),
        ],
      ),
      now: DateTime(2026, 8, 10, 12),
    );
    expect(
      result.path.units.single.nodes.first.state,
      GamePathNodeState.completed,
    );
    expect(result.path.currentNodeId, contains(':practice'));
    expect(result.player.xp, 10);
    expect(result.player.streakDays, 1);
  });

  test('学校scopeはwalletを表示せずハート無制限で個人報酬を混ぜない', () {
    final result = projection.build(
      catalog: _catalog,
      snapshot: snapshot(
        scope: LearningScope.schoolLocal,
        rewards: [
          LearningRewardEntry(
            entryId: 'invalid-display-only',
            scope: LearningScope.schoolLocal,
            type: LearningRewardType.xp,
            amount: 99,
            reason: 'should-not-show',
            sourceEventId: null,
            createdAt: DateTime.utc(2026, 8, 10),
          ),
        ],
      ),
      now: DateTime(2026, 8, 10, 12),
      schoolMode: true,
    );
    expect(result.player.xp, 0);
    expect(result.player.gems, 0);
    expect(result.path.status.unlimitedHearts, isTrue);
  });

  test('回答を保存しないactive runだけでPathを続きから状態にする', () {
    final lessonId = GamePathProjection.nodeId(
      'motion',
      'fall',
      GamePathNodeKind.lesson,
    );
    final result = projection.build(
      catalog: _catalog,
      snapshot: snapshot(
        runs: [
          LearningRun(
            runId: 'run-1',
            scope: LearningScope.personal,
            nodeId: lessonId,
            activityIndex: 0,
            challengeHearts: null,
            contentVersion: 'v1',
            updatedAt: DateTime.utc(2026, 8, 10),
          ),
        ],
      ),
      now: DateTime(2026, 8, 10, 12),
    );
    expect(
      result.path.units.single.nodes.first.state,
      GamePathNodeState.inProgress,
    );
  });

  test('freeze消費日を連続日数へ含め、当週の実残数を表示する', () {
    final result = projection.build(
      catalog: _catalog,
      snapshot: snapshot(
        days: [_day('2026-08-12'), _day('2026-08-10')],
        freezes: [
          LearningStreakFreeze(
            scope: LearningScope.personal,
            day: '2026-08-11',
            weekKey: '2026-08-10',
            usedAt: DateTime.utc(2026, 8, 12),
          ),
        ],
      ),
      now: DateTime(2026, 8, 12, 12),
    );

    expect(
      result.player.streakDays,
      2,
      reason: 'freezeは連続を守るが、実際の学習日として水増ししない',
    );
    expect(result.player.freezeCount, 0);
    expect(result.path.status.streakFreezeRemaining, 0);
  });

  test('利用可能なfreezeは学習前から1日の欠けを仮保護して完了後の突然復活を防ぐ', () {
    final start = DateTime.utc(2026, 4, 21);
    final days = <LearningDay>[
      for (var index = 0; index < 110; index += 1)
        _day(_dayKeyForTest(start.add(Duration(days: index)))),
    ];

    final result = projection.build(
      catalog: _catalog,
      snapshot: snapshot(days: days),
      // 110日目の翌日を1日だけ空け、その次の日の朝に開いた状態。
      now: DateTime(2026, 8, 10, 12),
    );

    expect(result.player.streakDays, 110);
    expect(result.player.freezeCount, 1, reason: '日曜の欠けは前週枠で守り、月曜の今週枠を先に消費しない');
  });

  test('同じ週の仮freezeは残数を先に0表示し、commit後の保存状態へ自然に収束する', () {
    final gemReward = LearningRewardEntry(
      entryId: 'freeze-refill-gems',
      scope: LearningScope.personal,
      type: LearningRewardType.gems,
      amount: 3,
      reason: 'test',
      sourceEventId: null,
      createdAt: DateTime.utc(2026, 8, 10),
    );
    final beforeCommit = projection.build(
      catalog: _catalog,
      snapshot: snapshot(days: [_day('2026-08-10')], rewards: [gemReward]),
      now: DateTime(2026, 8, 12, 12),
    );
    expect(beforeCommit.player.streakDays, 1);
    expect(beforeCommit.player.freezeCount, 0);
    expect(
      beforeCommit.economy.canRefillStreakFreeze,
      isFalse,
      reason: '仮残数0でも保存層の枠は未消費なので、押して必ず失敗する交換CTAを出さない',
    );

    final afterCommit = projection.build(
      catalog: _catalog,
      snapshot: snapshot(
        days: [_day('2026-08-10'), _day('2026-08-12')],
        freezes: [
          LearningStreakFreeze(
            scope: LearningScope.personal,
            day: '2026-08-11',
            weekKey: '2026-08-10',
            usedAt: DateTime.utc(2026, 8, 12, 4),
          ),
        ],
        rewards: [gemReward],
      ),
      now: DateTime(2026, 8, 12, 12),
    );
    expect(afterCommit.player.streakDays, 2);
    expect(afterCommit.player.freezeCount, 0);
    expect(afterCommit.economy.canRefillStreakFreeze, isTrue);
  });

  test('4時の学習日境界より前には翌日の仮freezeを適用しない', () {
    final beforeCutover = projection.build(
      catalog: _catalog,
      snapshot: snapshot(days: [_day('2026-08-10')]),
      now: DateTime(2026, 8, 12, 3, 59),
    );
    expect(beforeCutover.player.streakDays, 1);
    expect(beforeCutover.player.freezeCount, 1);

    final afterCutover = projection.build(
      catalog: _catalog,
      snapshot: snapshot(days: [_day('2026-08-10')]),
      now: DateTime(2026, 8, 12, 4),
    );
    expect(afterCutover.player.streakDays, 1);
    expect(afterCutover.player.freezeCount, 0);
  });

  test('2日以上の欠け・学校scope・未来eventには仮freezeを適用しない', () {
    final twoDayGap = projection.build(
      catalog: _catalog,
      snapshot: snapshot(days: [_day('2026-08-09')]),
      now: DateTime(2026, 8, 12, 12),
    );
    expect(twoDayGap.player.freezeCount, 1);

    final school = projection.build(
      catalog: _catalog,
      snapshot: snapshot(
        scope: LearningScope.schoolLocal,
        days: [
          LearningDay(
            scope: LearningScope.schoolLocal,
            day: '2026-08-10',
            qualifyingCount: 1,
            firstEventAt: DateTime.utc(2026, 8, 10),
            lastEventAt: DateTime.utc(2026, 8, 10),
          ),
        ],
      ),
      now: DateTime(2026, 8, 12, 12),
      schoolMode: true,
    );
    expect(school.player.freezeCount, 0);

    final futureEvent = projection.build(
      catalog: _catalog,
      snapshot: snapshot(days: [_day('2026-08-10'), _day('2026-08-13')]),
      now: DateTime(2026, 8, 12, 12),
    );
    expect(futureEvent.player.freezeCount, 1);
  });

  test('長く離れたときは減衰を繰り返し、事実でない1日を残さない', () {
    final result = projection.build(
      catalog: _catalog,
      snapshot: snapshot(days: [_day('2026-07-01')]),
      now: DateTime(2026, 8, 10, 12),
    );

    expect(result.player.streakDays, 0);
  });

  test('unit Legendaryは全章ボスの最後の初回clear翌日だけ解放する', () {
    final challengeId = GamePathProjection.nodeId(
      'motion',
      'fall',
      GamePathNodeKind.challenge,
    );
    final skill = _skill(
      lastSuccessDay: '2026-08-09',
      nextDueDay: '2026-08-10',
    );
    final locked = projection.build(
      catalog: _catalog,
      snapshot: snapshot(skills: [skill]),
      now: DateTime(2026, 8, 10, 12),
    );
    expect(_legendary(locked).state, GamePathNodeState.locked);

    final available = projection.build(
      catalog: _catalog,
      snapshot: snapshot(nodes: [_node(challengeId)], skills: [skill]),
      now: DateTime(2026, 8, 10, 12),
    );
    expect(_legendary(available).state, GamePathNodeState.legendaryAvailable);

    final bossToday = projection.build(
      catalog: _catalog,
      snapshot: snapshot(
        nodes: [_node(challengeId, lastAttemptDay: '2026-08-10')],
        skills: [skill],
      ),
      now: DateTime(2026, 8, 10, 12),
    );
    expect(
      _legendary(bossToday).state,
      GamePathNodeState.locked,
      reason: '初回skill成功日が古くても章ボス当日は解放しない',
    );

    final replayedBossToday = projection.build(
      catalog: _catalog,
      snapshot: snapshot(
        nodes: [
          _node(
            challengeId,
            lastAttemptDay: '2026-08-10',
            completedDay: '2026-08-09',
          ),
        ],
        skills: [skill],
      ),
      now: DateTime(2026, 8, 10, 12),
    );
    expect(
      _legendary(replayedBossToday).state,
      GamePathNodeState.legendaryAvailable,
      reason: '章ボスの再演日で初回clear日を上書きしない',
    );
  });

  test('Profile完了数は復習期限でも減らず、Legendary実績を必修分母へ混ぜない', () {
    final nodes = [
      for (final kind in GamePathNodeKind.values)
        _node(GamePathProjection.nodeId('motion', 'fall', kind)),
    ];
    final result = projection.build(
      catalog: _catalog,
      snapshot: snapshot(
        nodes: nodes,
        skills: [
          _skill(lastSuccessDay: '2026-08-09', nextDueDay: '2026-08-10'),
        ],
      ),
      now: DateTime(2026, 8, 10, 12),
    );

    expect(result.player.completedNodes, 6);
    expect(result.player.totalNodes, 6);
    expect(
      result.path.units.single.nodes
          .singleWhere((node) => node.kind == GamePathNodeKind.practice)
          .state,
      GamePathNodeState.reviewDue,
    );
    expect(_legendary(result).state, GamePathNodeState.legendaryAvailable);
  });

  test('完了済みLegendaryは期限前は実績表示、期限到来日に再挑戦へ戻る', () {
    final challengeId = GamePathProjection.nodeId(
      'motion',
      'fall',
      GamePathNodeKind.challenge,
    );
    final legendaryId = GamePathProjection.unitLegendaryNodeId('motion');
    final nodes = [_node(challengeId), _node(legendaryId)];

    final beforeDue = projection.build(
      catalog: _catalog,
      snapshot: snapshot(
        nodes: nodes,
        skills: [_unitLegendarySkill('2026-08-10', '2026-08-13')],
      ),
      now: DateTime(2026, 8, 12, 12),
    );
    expect(_legendary(beforeDue).state, GamePathNodeState.legendaryCompleted);

    final due = projection.build(
      catalog: _catalog,
      snapshot: snapshot(
        nodes: nodes,
        skills: [_unitLegendarySkill('2026-08-10', '2026-08-13')],
      ),
      now: DateTime(2026, 8, 13, 12),
    );
    expect(_legendary(due).state, GamePathNodeState.legendaryAvailable);
  });

  test('旧concept Legendaryは0/一部を昇格せず、全clearだけ無報酬でunit実績へ移す', () {
    final bossFall = GamePathProjection.nodeId(
      'motion',
      'fall',
      GamePathNodeKind.challenge,
    );
    final bossInertia = GamePathProjection.nodeId(
      'motion',
      'inertia',
      GamePathNodeKind.challenge,
    );
    final legacyFall = GamePathProjection.legacyConceptLegendaryNodeId(
      'motion',
      'fall',
    );
    final legacyInertia = GamePathProjection.legacyConceptLegendaryNodeId(
      'motion',
      'inertia',
    );
    final bosses = [_node(bossFall), _node(bossInertia)];

    final oneBossOnly = projection.build(
      catalog: _twoConceptCatalog,
      snapshot: snapshot(nodes: [_node(bossFall)]),
      now: DateTime(2026, 8, 10, 12),
    );
    expect(
      _legendary(oneBossOnly).state,
      GamePathNodeState.locked,
      reason: 'unit内の一部Bossだけでは解放しない',
    );

    final lastBossToday = projection.build(
      catalog: _twoConceptCatalog,
      snapshot: snapshot(
        nodes: [
          _node(bossFall),
          _node(bossInertia, lastAttemptDay: '2026-08-10'),
        ],
      ),
      now: DateTime(2026, 8, 10, 12),
    );
    expect(
      _legendary(lastBossToday).state,
      GamePathNodeState.locked,
      reason: '最後のBoss初回clear当日は解放しない',
    );

    final noLegacy = projection.build(
      catalog: _twoConceptCatalog,
      snapshot: snapshot(nodes: bosses),
      now: DateTime(2026, 8, 10, 12),
    );
    expect(_legendary(noLegacy).state, GamePathNodeState.legendaryAvailable);
    expect(_legendary(noLegacy).rewardLabel, contains('XP'));

    final oldRun = LearningRun(
      runId: 'run.old.legendary',
      scope: LearningScope.personal,
      nodeId: legacyFall,
      activityIndex: 2,
      challengeHearts: 3,
      contentVersion: 'catalog-v4',
      updatedAt: DateTime.utc(2026, 8, 10),
    );
    final partial = projection.build(
      catalog: _twoConceptCatalog,
      snapshot: snapshot(nodes: [...bosses, _node(legacyFall)], runs: [oldRun]),
      now: DateTime(2026, 8, 10, 12),
    );
    expect(
      _legendary(partial).state,
      GamePathNodeState.legendaryAvailable,
      reason: '一部clearと旧active runを新unit完了へ捏造しない',
    );

    final migrated = projection.build(
      catalog: _twoConceptCatalog,
      snapshot: snapshot(
        nodes: [...bosses, _node(legacyFall), _node(legacyInertia)],
        skills: [
          _skill(
            skillId: 'motion/fall',
            lastSuccessDay: '2026-08-09',
            nextDueDay: '2026-08-11',
          ),
          _skill(
            skillId: 'motion/inertia',
            lastSuccessDay: '2026-08-09',
            nextDueDay: '2026-08-11',
          ),
        ],
        rewards: [
          LearningRewardEntry(
            entryId: 'old-xp',
            scope: LearningScope.personal,
            type: LearningRewardType.xp,
            amount: 20,
            reason: 'old.legendary',
            sourceEventId: null,
            createdAt: DateTime.utc(2026, 8, 9),
          ),
        ],
      ),
      now: DateTime(2026, 8, 10, 12),
    );
    expect(_legendary(migrated).state, GamePathNodeState.legendaryCompleted);
    expect(_legendary(migrated).rewardLabel, isNull);
    expect(migrated.player.xp, 20, reason: 'projection移行は報酬eventを生成しない');

    final migratedDue = projection.build(
      catalog: _twoConceptCatalog,
      snapshot: snapshot(
        nodes: [...bosses, _node(legacyFall), _node(legacyInertia)],
        skills: [
          _skill(
            skillId: 'motion/fall',
            lastSuccessDay: '2026-08-09',
            nextDueDay: '2026-08-10',
          ),
          _skill(
            skillId: 'motion/inertia',
            lastSuccessDay: '2026-08-09',
            nextDueDay: '2026-08-12',
          ),
        ],
      ),
      now: DateTime(2026, 8, 10, 12),
    );
    expect(_legendary(migratedDue).state, GamePathNodeState.legendaryAvailable);
    expect(
      _legendary(migratedDue).rewardLabel,
      isNull,
      reason: '旧全clearからの最初のv2記録へ初回報酬を予告しない',
    );
  });

  test('unit専用skillのdueだけで再解放し、個別練習件数へ混ぜない', () {
    final legendaryId = GamePathProjection.unitLegendaryNodeId('motion');
    final beforeDue = projection.build(
      catalog: _catalog,
      snapshot: snapshot(
        nodes: [_node(legendaryId)],
        skills: [_unitLegendarySkill('2026-08-10', '2026-08-12')],
      ),
      now: DateTime(2026, 8, 11, 12),
    );
    expect(_legendary(beforeDue).state, GamePathNodeState.legendaryCompleted);
    expect(beforeDue.duePracticeCount, 0);

    final due = projection.build(
      catalog: _catalog,
      snapshot: snapshot(
        nodes: [_node(legendaryId)],
        skills: [_unitLegendarySkill('2026-08-10', '2026-08-12')],
      ),
      now: DateTime(2026, 8, 12, 12),
    );
    expect(_legendary(due).state, GamePathNodeState.legendaryAvailable);
    expect(due.duePracticeCount, 0);
  });

  test('当日questはcommit前から0で表示し、DB進捗と定義済み結晶を重複なく使う', () {
    final definition = LearningQuestDefinition(
      questInstanceId: 'daily:2026-08-10:one-node',
      definitionVersion: 'quest.v1',
      target: 2,
      rewardGems: 1,
    );
    final before = projection.build(
      catalog: _catalog,
      snapshot: snapshot(),
      now: DateTime(2026, 8, 10, 12),
      activeQuestDefinitions: [definition],
      questTitles: {definition.questInstanceId: '今日の観察を進める'},
    );
    expect(before.quests, hasLength(1));
    expect(before.quests.single.progress, 0);
    expect(before.quests.single.gemReward, 1);
    expect(before.path.quests.single.rewardLabel, '結晶1個');

    final after = projection.build(
      catalog: _catalog,
      snapshot: snapshot(
        quests: [
          LearningQuestProgress(
            scope: LearningScope.personal,
            questInstanceId: definition.questInstanceId,
            progress: 1,
            target: 2,
            completedAt: null,
            rewardedAt: null,
            definitionVersion: 'quest.v1',
          ),
        ],
      ),
      now: DateTime(2026, 8, 10, 12),
      activeQuestDefinitions: [definition],
    );
    expect(after.quests, hasLength(1));
    expect(after.quests.single.progress, 1);
    expect(after.quests.single.gemReward, 1);

    final school = projection.build(
      catalog: _catalog,
      snapshot: snapshot(
        scope: LearningScope.schoolLocal,
        events: [
          _eventRecord(
            'event.school.past',
            '2026-08-09',
            scope: LearningScope.schoolLocal,
          ),
          _eventRecord(
            'event.school',
            '2026-08-10',
            scope: LearningScope.schoolLocal,
          ),
        ],
      ),
      now: DateTime(2026, 8, 10, 12),
      schoolMode: true,
      activeQuestDefinitions: [definition],
    );
    expect(school.quests.single.gemReward, 0);
    expect(school.quests.single.progress, 1);
    expect(school.path.quests.single.kind, GameQuestKind.classroom);
    expect(school.path.quests.single.rewardLabel, isNull);
  });

  test('rewarded monthly questだけを個人badgeへ一度投影し学校には出さない', () {
    final monthly = LearningQuestProgress(
      scope: LearningScope.personal,
      questInstanceId: 'monthly:2026-08:twelve-actions',
      progress: 12,
      target: 12,
      completedAt: DateTime.utc(2026, 8, 20),
      rewardedAt: DateTime.utc(2026, 8, 20),
      definitionVersion: 'monthly.v1',
    );
    final personal = projection.build(
      catalog: _catalog,
      snapshot: snapshot(quests: [monthly]),
      now: DateTime(2026, 8, 20, 12),
    );
    expect(personal.monthlyBadges, hasLength(1));
    expect(
      personal.monthlyBadges.single.badgeId,
      'badge.monthly.2026-08.twelve-actions',
    );

    final school = projection.build(
      catalog: _catalog,
      snapshot: snapshot(scope: LearningScope.schoolLocal, quests: [monthly]),
      now: DateTime(2026, 8, 20, 12),
      schoolMode: true,
    );
    expect(school.monthlyBadges, isEmpty);
  });

  test('leagueのtier・現在値・次目標はすべて今週XPだけを正本にする', () {
    final oldEvent = _eventRecord('event.old', '2026-08-03');
    final currentEvent = _eventRecord('event.current', '2026-08-10');
    final result = projection.build(
      catalog: _catalog,
      snapshot: snapshot(
        events: [oldEvent, currentEvent],
        rewards: [
          _xp('xp.old', oldEvent.eventId, 190, oldEvent.occurredAt),
          _xp('xp.current', currentEvent.eventId, 10, currentEvent.occurredAt),
        ],
      ),
      now: DateTime(2026, 8, 10, 12),
    );

    expect(result.player.xp, 200);
    expect(result.player.weeklyLeagueXp, 10);
    expect(result.player.leagueName, '観察者');
    expect(result.player.nextLeagueXp, 60);

    final weeklyMaximum = projection.build(
      catalog: _catalog,
      snapshot: snapshot(
        events: [currentEvent],
        rewards: [
          _xp(
            'xp.weekly-max',
            currentEvent.eventId,
            210,
            currentEvent.occurredAt,
          ),
        ],
      ),
      now: DateTime(2026, 8, 10, 12),
    );
    expect(weeklyMaximum.player.leagueName, '研究主任');
    expect(weeklyMaximum.player.nextLeagueXp, 210);
  });

  test('ローカル協力・結晶用途・league履歴は実台帳だけを投影し外部相手を作らない', () {
    final localQuest = LearningQuestProgress(
      scope: LearningScope.personal,
      questInstanceId: 'local-coop:run.shared',
      progress: 1,
      target: 2,
      completedAt: null,
      rewardedAt: null,
      definitionVersion: 'coop.v1',
    );
    final result = projection.build(
      catalog: _catalog,
      snapshot: snapshot(
        rewards: [
          LearningRewardEntry(
            entryId: 'gems.earned',
            scope: LearningScope.personal,
            type: LearningRewardType.gems,
            amount: 5,
            reason: 'quest.real',
            sourceEventId: null,
            createdAt: DateTime(2026, 8, 10),
          ),
        ],
        gemSpends: [
          LearningGemSpend(
            spendId: 'spend.real',
            scope: LearningScope.personal,
            kind: LearningGemSpendKind.challengeHeartRecovery,
            amount: 2,
            learningDay: '2026-08-10',
            weekKey: null,
            occurredAt: DateTime(2026, 8, 10, 10),
          ),
        ],
        quests: [localQuest],
        localCoopRuns: [
          LearningLocalCoopRun(
            runId: 'run.shared',
            scope: LearningScope.personal,
            questInstanceId: localQuest.questInstanceId,
            participantIds: const {'slot.a', 'slot.b'},
            contributingParticipantIds: const {'slot.a'},
            progress: 1,
            target: 2,
            rewardGems: 4,
            startDay: '2026-08-10',
            endDay: '2026-08-31',
            definitionVersion: 'coop.v1',
            startedAt: DateTime(2026, 8, 10, 9),
            completedAt: null,
            rewardedAt: null,
          ),
        ],
        leagueHistory: [
          LearningLeagueWeek(
            scope: LearningScope.personal,
            weekKey: '2026-08-03',
            xp: 60,
            previousTier: LearningLeagueTier.observer,
            tier: LearningLeagueTier.experimenter,
            movement: LearningLeagueMovement.promoted,
            finalizedAt: DateTime(2026, 8, 10),
          ),
        ],
      ),
      now: DateTime(2026, 8, 10, 12),
    );

    expect(result.quests, isEmpty, reason: 'local coopをフレンズquestへ偽装しない');
    expect(result.path.quests, isEmpty);
    expect(result.localCoopQuests.single.participantCount, 2);
    expect(result.localCoopQuests.single.contributingParticipantCount, 1);
    expect(result.localCoopQuests.single.gemReward, 4);
    expect(result.economy.gems, 3);
    expect(result.economy.streakFreezeRefillGemCost, 3);
    expect(result.economy.challengeHeartRecoveryGemCost, 2);
    expect(result.economy.canRefillStreakFreeze, isFalse);
    expect(result.economy.canRecoverChallengeHearts, isFalse);
    expect(result.economy.cosmeticItems, hasLength(3));
    expect(result.economy.timedChallengePassGemCost, 1);
    expect(result.economy.timedChallengePassActive, isFalse);
    expect(result.economy.canPurchaseTimedChallengePass, isTrue);
    expect(
      result.leagueHistory.single.movement,
      LearningLeagueMovement.promoted,
    );
    expect(result.featureState.externalFriendsAvailable, isFalse);
    expect(result.featureState.externalLeagueAvailable, isFalse);

    final school = projection.build(
      catalog: _catalog,
      snapshot: snapshot(scope: LearningScope.schoolLocal),
      now: DateTime(2026, 8, 10, 12),
      schoolMode: true,
    );
    expect(school.localCoopQuests, isEmpty);
    expect(school.economy.available, isFalse);
    expect(school.economy.streakFreezeRefillGemCost, isNull);
    expect(school.economy.cosmeticItems, isEmpty);
    expect(school.economy.timedChallengePassGemCost, isNull);
    expect(school.economy.canPurchaseTimedChallengePass, isFalse);
    expect(school.leagueHistory, isEmpty);
    expect(school.featureState.gemEconomyAvailable, isFalse);
    expect(school.featureState.localCoopRunsAvailable, isFalse);
    expect(school.player.weeklyLeagueXp, 0);
    expect(school.player.nextLeagueXp, 0);
  });

  test('購入済みmascotと当日Timed passを固定台帳から投影する', () {
    final result = projection.build(
      catalog: _catalog,
      snapshot: snapshot(
        rewards: [
          LearningRewardEntry(
            entryId: 'gems.catalog',
            scope: LearningScope.personal,
            type: LearningRewardType.gems,
            amount: 10,
            reason: 'test',
            sourceEventId: null,
            createdAt: DateTime(2026, 8, 10),
          ),
        ],
        cosmetics: const LearningCosmeticState(
          ownedProductIds: {
            SafeLearningEconomyCatalogV1.standardMascotId,
            SafeLearningEconomyCatalogV1.orbitMascotId,
          },
          equippedPathMascotId: SafeLearningEconomyCatalogV1.orbitMascotId,
        ),
        gemSpends: [
          LearningGemSpend(
            spendId: 'spend.cosmetic',
            scope: LearningScope.personal,
            kind: LearningGemSpendKind.cosmeticPurchase,
            amount: 4,
            learningDay: '2026-08-10',
            weekKey: null,
            occurredAt: DateTime(2026, 8, 10, 10),
            referenceId: SafeLearningEconomyCatalogV1.orbitMascotId,
          ),
          LearningGemSpend(
            spendId: 'spend.timed',
            scope: LearningScope.personal,
            kind: LearningGemSpendKind.challengeEntry,
            amount: 1,
            learningDay: '2026-08-10',
            weekKey: null,
            occurredAt: DateTime(2026, 8, 10, 11),
            referenceId: SafeLearningEconomyCatalogV1.timedDayPassId,
          ),
        ],
      ),
      now: DateTime(2026, 8, 10, 12),
    );

    expect(
      result.economy.equippedPathMascotStyle,
      LearningPathMascotStyle.orbit,
    );
    expect(
      result.economy.cosmeticItems
          .singleWhere(
            (item) =>
                item.productId == SafeLearningEconomyCatalogV1.orbitMascotId,
          )
          .equipped,
      isTrue,
    );
    expect(result.economy.timedChallengePassActive, isTrue);
    expect(result.economy.canPurchaseTimedChallengePass, isFalse);
  });

  test('economy表示は保存側へ渡すpolicyと同じ実コストだけを返す', () {
    const policy = SafeLearningEconomyPolicyV1(
      streakFreezeRefillGemCost: 7,
      challengeHeartRecoveryGemCost: 5,
    );
    final result = projection.build(
      catalog: _catalog,
      snapshot: snapshot(),
      now: DateTime(2026, 8, 10, 12),
      economyPolicy: policy,
    );

    expect(result.economy.streakFreezeRefillGemCost, 7);
    expect(result.economy.challengeHeartRecoveryGemCost, 5);
  });

  test('当日30 XP到達後は、次のnodeへXPを表示しない', () {
    final events = [
      _eventRecord('event.cap.1', '2026-08-10'),
      _eventRecord('event.cap.2', '2026-08-10'),
      _eventRecord('event.cap.3', '2026-08-10'),
    ];
    final result = projection.build(
      catalog: _catalog,
      snapshot: snapshot(
        events: events,
        rewards: [
          for (final event in events)
            _xp('xp.${event.eventId}', event.eventId, 10, event.occurredAt),
        ],
      ),
      now: DateTime(2026, 8, 10, 12),
    );

    final next = result.path.units.single.nodes.first;
    expect(next.state, GamePathNodeState.available);
    expect(next.rewardLabel, isNull);
  });

  test('午前4時までは前の学習日としてquest・期限・streak・leagueを揃える', () {
    final definition = LearningQuestDefinition(
      questInstanceId: 'daily:2026-08-09:one-node',
      definitionVersion: 'quest.v1',
      target: 1,
      rewardGems: 1,
    );
    final event = _eventRecord('event.before-cutover', '2026-08-09');
    final result = projection.build(
      catalog: _catalog,
      snapshot: snapshot(
        skills: [
          _skill(lastSuccessDay: '2026-08-09', nextDueDay: '2026-08-10'),
        ],
        days: [_day('2026-08-09')],
        events: [event],
        rewards: [
          _xp('xp.before-cutover', event.eventId, 10, event.occurredAt),
        ],
      ),
      now: DateTime(2026, 8, 10, 1),
      activeQuestDefinitions: [definition],
    );

    expect(result.quests.single.id, definition.questInstanceId);
    expect(result.duePracticeCount, 0);
    expect(result.player.streakDays, 1);
    expect(result.player.weeklyLeagueXp, 10);
  });

  test('午前4時前に章ボスを終えても、次の学習日にはLegendaryを解放する', () {
    final challengeId = GamePathProjection.nodeId(
      'motion',
      'fall',
      GamePathNodeKind.challenge,
    );
    final result = projection.build(
      catalog: _catalog,
      snapshot: snapshot(
        nodes: [
          LearningNodeProgress(
            scope: LearningScope.personal,
            nodeId: challengeId,
            state: LearningNodeState.cleared,
            attemptCount: 1,
            bestEvidence: LearningEvidenceLevel.transfer,
            lastAttemptDay: '2026-08-09',
            lastEventId: 'event-boss-before-cutover',
            completedAt: DateTime(2026, 8, 10, 1),
            contentVersion: 'v1',
          ),
        ],
        skills: [
          _skill(lastSuccessDay: '2026-08-09', nextDueDay: '2026-08-10'),
        ],
      ),
      now: DateTime(2026, 8, 10, 5),
    );

    expect(_legendary(result).state, GamePathNodeState.legendaryAvailable);
  });
}

LearningDay _day(String day) => LearningDay(
  scope: LearningScope.personal,
  day: day,
  qualifyingCount: 1,
  firstEventAt: DateTime.parse('${day}T12:00:00Z'),
  lastEventAt: DateTime.parse('${day}T12:00:00Z'),
);

String _dayKeyForTest(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

LearningNodeProgress _node(
  String id, {
  String lastAttemptDay = '2026-08-09',
  String? completedDay,
}) => LearningNodeProgress(
  scope: LearningScope.personal,
  nodeId: id,
  state: LearningNodeState.cleared,
  attemptCount: 1,
  bestEvidence: LearningEvidenceLevel.selfCompared,
  lastAttemptDay: lastAttemptDay,
  lastEventId: 'event-$id',
  completedAt: DateTime.parse('${completedDay ?? lastAttemptDay}T00:00:00Z'),
  contentVersion: 'v1',
);

LearningSkillProgress _skill({
  String skillId = 'motion/fall',
  required String lastSuccessDay,
  required String nextDueDay,
}) => LearningSkillProgress(
  scope: LearningScope.personal,
  skillId: skillId,
  lastOutcome: LearningSkillOutcome.completed,
  successfulRetrievals: 0,
  lastAttemptDay: lastSuccessDay,
  lastSuccessDay: lastSuccessDay,
  nextDueDay: nextDueDay,
  lastEventId: 'event-skill',
);

LearningSkillProgress _unitLegendarySkill(
  String lastSuccessDay,
  String nextDueDay,
) => _skill(
  skillId: GamePathProjection.unitLegendarySkillId('motion'),
  lastSuccessDay: lastSuccessDay,
  nextDueDay: nextDueDay,
);

GamePathNode _legendary(LearningGameProjectionResult result) => result
    .path
    .units
    .single
    .nodes
    .singleWhere((node) => node.kind == GamePathNodeKind.legendary);

LearningEventRecord _eventRecord(
  String id,
  String day, {
  LearningScope scope = LearningScope.personal,
}) => LearningEventRecord(
  eventId: id,
  scope: scope,
  origin: scope == LearningScope.schoolLocal
      ? LearningOrigin.schoolAssignment
      : LearningOrigin.path,
  courseId: 'course',
  nodeId: 'node.$id',
  activityId: 'activity.$id',
  activityKind: LearningActivityKind.read,
  outcome: LearningAttemptOutcome.completed,
  evidence: LearningEvidenceLevel.selfCompared,
  contentVersion: 'v1',
  learningDay: day,
  occurredAt: DateTime.parse('${day}T12:00:00Z'),
  runId: null,
  sourceSessionId: null,
  rewardEligible: scope == LearningScope.personal,
);

LearningRewardEntry _xp(String id, String eventId, int amount, DateTime at) =>
    LearningRewardEntry(
      entryId: id,
      scope: LearningScope.personal,
      type: LearningRewardType.xp,
      amount: amount,
      reason: 'test',
      sourceEventId: eventId,
      createdAt: at,
    );
