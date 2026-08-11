import 'dart:convert';

import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/learning/domain/learning_economy.dart';
import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/learning/domain/learning_monthly_badge.dart';
import 'package:dekisugi/learning/domain/learning_policy.dart';
import 'package:dekisugi/learning/domain/learning_progress.dart';
import 'package:dekisugi/learning/services/game_path_projection.dart';
import 'package:dekisugi/learning/services/learning_quest_plan_v2.dart';
import 'package:dekisugi/learning/services/local_weekly_league_catch_up.dart';
import 'package:dekisugi/learning/services/local_weekly_league_projection.dart';
import 'package:dekisugi/models/day_key.dart';
import 'package:dekisugi/models/game_path.dart';
import 'package:dekisugi/models/lan_social.dart';
import 'package:dekisugi/models/unit.dart';
import 'package:dekisugi/screens/science_game_home_screen.dart';
import 'package:dekisugi/screens/science_listening_screen.dart';
import 'package:dekisugi/screens/science_speak_listen_screen.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:dekisugi/services/units_client.dart';
import 'package:dekisugi/widgets/science_challenge_support.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

LocalCheckpoint _checkpointFor(LocalPracticeStage stage) => LocalCheckpoint(
  lure: '重い物体ほど速く落ちる。',
  options: [
    const LocalCheckpointOption(id: 'same', text: '真空では同じ加速度'),
    LocalCheckpointOption(
      id: 'heavy',
      text: '重い方が速い',
      hint: '空気抵抗を除いた条件を見る',
      needCode: 'science.fall.${stage.wire}',
    ),
    LocalCheckpointOption(
      id: 'light',
      text: '軽い方が速い',
      hint: '質量と加速度を分けて見る',
      needCode: 'science.fall.${stage.wire}',
    ),
  ],
  correctOptionId: 'same',
  explanation: '真空では質量に関係なく同じ加速度になる。',
);

LocalCognitiveTask _taskFor(LocalPracticeStage stage) => LocalCognitiveTask(
  kind: LocalCognitiveTaskKind.singleSelect,
  operation: LocalCognitiveOperation.prediction,
  items: const [
    LocalCognitiveTaskItem(
      id: 'review-conditions',
      text: '教材の条件を確かめてから、この場面の結果を予想する。',
    ),
    LocalCognitiveTaskItem(id: 'skip-conditions', text: '条件を確かめず、印象だけで結果を決める。'),
  ],
  targets: const [],
  solution: const LocalSingleSelectSolution(
    selectedItemId: 'review-conditions',
  ),
  needCode: 'science.fall.${stage.wire}',
);

LocalPracticeVariant _variant(LocalPracticeStage stage) => LocalPracticeVariant(
  stage: stage,
  recallPrompt: '落下の速さは重さだけで決まるか予想する。',
  reasoningPrompt: '空気抵抗の条件を考える。',
  transferPrompt: '紙を丸めた場合を予想する。${stage.name}',
  expectedOutcome: '丸めた紙の方が先に着きやすい。',
  expectedReason: '空気抵抗の受け方が変わるから。',
  cognitiveTask: _taskFor(stage),
  checkpoint: _checkpointFor(stage),
  listeningNeedCodes: LocalListeningNeedCodes(
    transcript: 'science.fall.listening.${stage.wire}.transcript',
    meaning: 'science.fall.listening.${stage.wire}.meaning',
  ),
);

const _tracePattern = LocalNotationTracePattern(
  semanticsLabel: '左から右へ一本の線をなぞる',
  strokes: [
    LocalNotationTraceStroke(
      id: 'main',
      label: '左から右',
      points: [
        LocalNotationTracePoint(x: 0.1, y: 0.5),
        LocalNotationTracePoint(x: 0.5, y: 0.5),
        LocalNotationTracePoint(x: 0.9, y: 0.5),
      ],
    ),
  ],
  strokeOrderIds: ['main'],
);

const _notation = LocalNotationLab(
  orderTasks: [
    LocalNotationOrderTask(
      id: 'force-arrow',
      title: '力の矢印',
      prompt: '力の矢印を意味の順に並べる。',
      traceGuide: '作用点から向き、大きさの順に確かめる。',
      tracePattern: _tracePattern,
      tokens: [
        LocalNotationToken(id: 'direction', label: '向き'),
        LocalNotationToken(id: 'origin', label: '作用点'),
      ],
      correctOrderIds: ['origin', 'direction'],
      solutionSummary: '矢印は作用点から向きへ読む。',
      needCode: 'science.fall.notation.arrow',
    ),
    LocalNotationOrderTask(
      id: 'acceleration-equation',
      title: '加速度の式',
      prompt: '結果を左辺、原因を右辺に組む。',
      traceGuide: '加速度、等号、力÷質量の順に読む。',
      tracePattern: _tracePattern,
      tokens: [
        LocalNotationToken(id: 'cause', label: '力÷質量'),
        LocalNotationToken(id: 'equals', label: '＝'),
        LocalNotationToken(id: 'result', label: '加速度'),
      ],
      correctOrderIds: ['result', 'equals', 'cause'],
      solutionSummary: '加速度＝力÷質量。',
      needCode: 'science.fall.notation.equation',
    ),
  ],
  symbolMatch: LocalNotationSymbolTask(
    prompt: '加速度の単位を選ぶ。',
    choices: [
      LocalNotationChoice(id: 'wrong-unit', label: 'm/s'),
      LocalNotationChoice(id: 'right-unit', label: 'm/s²'),
    ],
    correctChoiceId: 'right-unit',
    solutionSummary: '加速度の単位はm/s²。',
    needCode: 'science.fall.notation.symbol',
  ),
  graphRead: LocalNotationGraphTask(
    prompt: '速度―時間グラフの傾きが表す量を選ぶ。',
    graphNotation: ['縦軸 速度', '横軸 時間 →'],
    graphSemanticsLabel: '縦軸が速度、横軸が時間のグラフ',
    choices: [
      LocalNotationChoice(id: 'distance', label: '距離'),
      LocalNotationChoice(id: 'acceleration', label: '加速度'),
    ],
    correctChoiceId: 'acceleration',
    solutionSummary: '速度―時間グラフの傾きは加速度。',
    needCode: 'science.fall.notation.graph',
  ),
);

const _story = LocalScienceStory(
  id: 'story.motion.fall.test',
  title: '落下研究室の紙対決',
  setting: '同じ紙を平らなままと丸めた状態で比べる研究室。',
  foundationNeedCode: 'science.fall.foundation',
  characters: [
    LocalScienceStoryCharacter(id: 'student', name: '生徒', role: '予想する人'),
    LocalScienceStoryCharacter(id: 'mentor', name: '先輩', role: '条件を確かめる人'),
  ],
  openingLines: [
    LocalScienceStoryLine(
      id: 'open.1',
      speakerId: 'student',
      text: '紙なら、どんな形でも同時に落ちると思う。',
    ),
    LocalScienceStoryLine(
      id: 'open.2',
      speakerId: 'mentor',
      text: '同じ重さでも、空気の受け方は同じかな。',
    ),
    LocalScienceStoryLine(
      id: 'open.3',
      speakerId: 'student',
      text: '形を変えて比べてみよう。',
    ),
  ],
  choiceLine: LocalScienceStoryLine(
    id: 'choice',
    speakerId: 'mentor',
    text: '重い物体ほど速く落ちる。',
  ),
  choiceResponses: [
    LocalScienceStoryChoiceResponse(
      optionId: 'same',
      line: LocalScienceStoryLine(
        id: 'response.same',
        speakerId: 'mentor',
        text: '真空という条件なら、その比較が使えるね。',
      ),
    ),
    LocalScienceStoryChoiceResponse(
      optionId: 'heavy',
      line: LocalScienceStoryLine(
        id: 'response.heavy',
        speakerId: 'student',
        text: '重さだけで決めず、空気抵抗も分けてみる。',
      ),
    ),
    LocalScienceStoryChoiceResponse(
      optionId: 'light',
      line: LocalScienceStoryLine(
        id: 'response.light',
        speakerId: 'mentor',
        text: '軽さではなく、形で変わる条件を見よう。',
      ),
    ),
  ],
  resolutionLines: [
    LocalScienceStoryLine(
      id: 'resolution.1',
      speakerId: 'student',
      text: '丸めた紙の方が先に着いた。',
    ),
    LocalScienceStoryLine(
      id: 'resolution.2',
      speakerId: 'mentor',
      text: '同じ紙でも空気抵抗の受け方が変わったからだね。',
    ),
  ],
  scientificResolution: LocalScienceStoryResolution(
    outcome: '丸めた紙の方が先に着きやすい。',
    reason: '空気抵抗の受け方が変わるから。',
  ),
  punchline: LocalScienceStoryLine(
    id: 'punchline',
    speakerId: 'student',
    text: '紙も形を変えると、急に本気を出すんだ。',
  ),
);

final _unit = UnitDetail(
  summary: const UnitSummary(
    id: 'motion',
    title: '力と運動',
    brief: '落下を条件から考える',
    concepts: [
      UnitConcept(
        key: 'fall',
        label: '落下',
        storyTitle: '落下研究室の紙対決',
        field: UnitCurriculumField.energy,
        grade: 3,
        curriculumRefs: [
          UnitCurriculumReference(
            document: 'mext-jhs-science-2017',
            section: '第1分野 (5) 運動とエネルギー',
            pages: [61, 62],
            url:
                'https://www.mext.go.jp/component/a_menu/education/'
                'micro_detail/__icsFiles/afieldfile/2019/03/18/'
                '1387018_005.pdf',
          ),
        ],
        prerequisites: [],
        difficulty: 2,
        safety: UnitSafety(
          level: UnitSafetyLevel.homeSafe,
          guidance: '同じ紙だけを手の高さから落とし、人や壊れ物へ向けない。',
        ),
      ),
    ],
    sectionCount: 1,
  ),
  sections: [
    Section(
      conceptKey: 'fall',
      title: '落下のしくみ',
      body: const ['物体には重力がはたらく。', '真空では同じ加速度で落ちる。'],
      tryIt: '紙を平らなままと丸めた状態で比べる。',
      localCheckpoint: _checkpointFor(LocalPracticeStage.foundation),
      localSpeakingPractice: const LocalSpeakingPractice(
        targetPhrase: '空気抵抗を無視すれば落下の速さは重さによらない',
        acceptedTranscripts: ['空気抵抗を無視すれば落下の速さは重さによらない'],
      ),
      localPracticeVariants: [
        for (final stage in LocalPracticeStage.values) _variant(stage),
      ],
      notationLab: _notation,
      scienceStory: _story,
    ),
  ],
);

class _CatalogBundle extends CachingAssetBundle {
  _CatalogBundle()
    : bytes = Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'schemaVersion': 10,
            'language': 'ja',
            'units': [_unit.toJson()],
          }),
        ),
      );

  final Uint8List bytes;

  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(bytes);
}

class _FailFirstHeartStore extends MemorySessionStore {
  bool _shouldFail = true;
  int spendRequests = 0;

  @override
  Future<LearningChallengeHeartSpendResult> spendLearningChallengeHeart(
    String runId, {
    required String lossId,
    required int activityIndex,
    required String learningDay,
    required DateTime occurredAt,
  }) {
    spendRequests++;
    if (_shouldFail) {
      _shouldFail = false;
      return Future.error(StateError('injected heart write failure'));
    }
    return super.spendLearningChallengeHeart(
      runId,
      lossId: lossId,
      activityIndex: activityIndex,
      learningDay: learningDay,
      occurredAt: occurredAt,
    );
  }
}

class _FailFirstHeartRecoveryStore extends MemorySessionStore {
  bool _shouldFail = true;
  int appliedRecoveries = 0;
  final recoveryRequests =
      <
        ({
          String recoveryId,
          String sourceEventId,
          String learningDay,
          DateTime occurredAt,
        })
      >[];

  @override
  Future<LearningChallengeHeartPracticeRecoveryResult>
  recoverLearningChallengeHeartWithPractice({
    required String recoveryId,
    required String sourceEventId,
    required String learningDay,
    required DateTime occurredAt,
  }) async {
    recoveryRequests.add((
      recoveryId: recoveryId,
      sourceEventId: sourceEventId,
      learningDay: learningDay,
      occurredAt: occurredAt,
    ));
    if (_shouldFail) {
      _shouldFail = false;
      throw StateError('injected recovery write failure');
    }
    final result = await super.recoverLearningChallengeHeartWithPractice(
      recoveryId: recoveryId,
      sourceEventId: sourceEventId,
      learningDay: learningDay,
      occurredAt: occurredAt,
    );
    if (result.applied) appliedRecoveries++;
    return result;
  }
}

class _CountingHeartStore extends MemorySessionStore {
  int appliedHeartLosses = 0;
  final lossIds = <String>[];

  @override
  Future<LearningChallengeHeartSpendResult> spendLearningChallengeHeart(
    String runId, {
    required String lossId,
    required int activityIndex,
    required String learningDay,
    required DateTime occurredAt,
  }) async {
    final result = await super.spendLearningChallengeHeart(
      runId,
      lossId: lossId,
      activityIndex: activityIndex,
      learningDay: learningDay,
      occurredAt: occurredAt,
    );
    if (runId != 'seed-heart-depletion') {
      lossIds.add(lossId);
      if (result.spent) appliedHeartLosses++;
    }
    return result;
  }
}

class _FailLocalCoopReadStore extends MemorySessionStore {
  @override
  Future<List<LearningLocalCoopContribution>> localCoopContributions(
    Set<String> runIds,
  ) => Future.error(StateError('injected optional league read failure'));
}

class _FailLocalLeagueFinalizeStore extends MemorySessionStore {
  @override
  Future<LearningLocalLeagueCatchUpResult> catchUpLearningLocalWeeklyLeagues({
    required String currentWeekKey,
    required DateTime finalizedAt,
    String? afterWeekKey,
  }) => Future.error(StateError('injected optional league finalize failure'));
}

class _FailQuestMaterializationStore extends MemorySessionStore {
  @override
  Future<LearningQuestMaterializationResult>
  materializeLearningQuestDefinitions({
    required LearningScope scope,
    required Iterable<LearningQuestDefinition> definitions,
  }) => Future.error(StateError('injected quest materialization failure'));
}

class _FailNextLearningCommitStore extends MemorySessionStore {
  bool failNextCommit = false;

  @override
  Future<CommitLearningResult> commitLearningEvent(
    LearningEventCommand event, {
    LearningCommitRules rules = const LearningCommitRules(),
  }) {
    if (failNextCommit) {
      failNextCommit = false;
      return Future.error(StateError('injected learning commit failure'));
    }
    return super.commitLearningEvent(event, rules: rules);
  }
}

class _ReplayRewardResultStore extends MemorySessionStore {
  @override
  Future<CommitLearningResult> commitLearningEvent(
    LearningEventCommand event, {
    LearningCommitRules rules = const LearningCommitRules(),
  }) async {
    final result = await super.commitLearningEvent(event, rules: rules);
    return CommitLearningResult(
      event: result.event,
      inserted: false,
      node: result.node,
      skills: result.skills,
      rewards: result.rewards,
      quests: result.quests,
    );
  }
}

class _ReplayOptionalNeedStore extends MemorySessionStore {
  final optionalNeedCommits = <({String eventId, bool inserted})>[];

  @override
  Future<CommitLearningResult> commitLearningEvent(
    LearningEventCommand event, {
    LearningCommitRules rules = const LearningCommitRules(),
  }) async {
    final first = await super.commitLearningEvent(event, rules: rules);
    if (event.activityId != 'practice.match.need.v1') return first;

    optionalNeedCommits.add((eventId: event.eventId, inserted: first.inserted));
    final replay = await super.commitLearningEvent(event, rules: rules);
    optionalNeedCommits.add((
      eventId: event.eventId,
      inserted: replay.inserted,
    ));
    return replay;
  }
}

class _FailOptionalMatchNeedStore extends _CountingHeartStore {
  int failedNeedWrites = 0;

  @override
  Future<CommitLearningResult> commitLearningEvent(
    LearningEventCommand event, {
    LearningCommitRules rules = const LearningCommitRules(),
  }) {
    if (event.activityId == 'practice.match.need.v1') {
      failedNeedWrites++;
      return Future.error(StateError('injected optional need write failure'));
    }
    return super.commitLearningEvent(event, rules: rules);
  }
}

Widget _app(
  MemorySessionStore store, {
  bool schoolMode = false,
  double textScale = 1,
  bool lanSocialAllowed = false,
  LanSocialMeaningfulEventContributor? lanSocialContributor,
  LanSocialFriendsQuestLoader? lanSocialFriendsQuestLoader,
  DateTime Function()? now,
}) {
  final units = UnitsClient(
    baseUrl: '',
    store: store,
    assetBundle: _CatalogBundle(),
  );
  return MaterialApp(
    theme: buildAppTheme(Brightness.light),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: ScienceGameHomeScreen(
      units: units,
      sessionStore: store,
      scope: schoolMode ? LearningScope.schoolLocal : LearningScope.personal,
      schoolMode: schoolMode,
      lanSocialAllowed: lanSocialAllowed,
      lanSocialMeaningfulEventContributor: lanSocialContributor,
      lanSocialFriendsQuestLoader: lanSocialFriendsQuestLoader,
      now: now,
      onOpenSettings: () {},
    ),
  );
}

void _expectSingleActivityChrome(WidgetTester tester) {
  expect(find.byKey(const ValueKey('game-activity-scaffold')), findsOneWidget);
  expect(
    find.byKey(const ValueKey('game-activity-top-chrome')),
    findsOneWidget,
  );
  expect(find.byKey(const ValueKey('game-activity-status')), findsOneWidget);
  expect(find.byKey(const ValueKey('game-activity-exit')), findsOneWidget);
  expect(find.byKey(const ValueKey('player-status-bar')), findsOneWidget);
  expect(find.byType(AppBar), findsNothing);
  final exitSize = tester.getSize(
    find.byKey(const ValueKey('game-activity-exit')),
  );
  expect(exitSize.width, greaterThanOrEqualTo(48));
  expect(exitSize.height, greaterThanOrEqualTo(48));
}

Future<void> _exitActivity(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('game-activity-exit')));
  await tester.pumpAndSettle();
}

Future<void> _depletePersonalHearts(
  MemorySessionStore store, {
  int remaining = 0,
}) async {
  assert(remaining >= 0 && remaining <= 5);
  final base = DateTime.now().subtract(const Duration(seconds: 10));
  await store.beginLearningRun(
    LearningRun(
      runId: 'seed-heart-depletion',
      scope: LearningScope.personal,
      nodeId: 'seed:heart:depletion',
      activityIndex: 0,
      challengeHearts: 5,
      contentVersion: 'catalog-v6',
      updatedAt: base.toUtc(),
    ),
  );
  for (var index = 1; index <= 5 - remaining; index++) {
    final at = base.add(Duration(seconds: index));
    await store.spendLearningChallengeHeart(
      'seed-heart-depletion',
      lossId: 'seed-heart-depletion:loss:$index',
      activityIndex: index,
      learningDay: dayKeyOf(at),
      occurredAt: at.toUtc(),
    );
  }
}

Future<void> _seedNodes(
  MemorySessionStore store,
  Iterable<GamePathNodeKind> kinds, {
  LearningScope scope = LearningScope.personal,
  DateTime? at,
}) async {
  final occurredAt = at ?? DateTime.now().subtract(const Duration(days: 1));
  for (final kind in kinds) {
    await store.commitLearningEvent(
      LearningEventCommand(
        eventId: 'seed-${kind.name}',
        scope: scope,
        origin: scope == LearningScope.schoolLocal
            ? LearningOrigin.schoolAssignment
            : switch (kind) {
                GamePathNodeKind.story => LearningOrigin.story,
                GamePathNodeKind.practice => LearningOrigin.lab,
                GamePathNodeKind.challenge ||
                GamePathNodeKind.legendary => LearningOrigin.challenge,
                _ => LearningOrigin.path,
              },
        courseId: 'science-ja-v1',
        nodeId: GamePathProjection.nodeId('motion', 'fall', kind),
        activityId: 'seed.${kind.name}',
        skillIds: const {'motion/fall'},
        activityKind: switch (kind) {
          GamePathNodeKind.lesson => LearningActivityKind.read,
          GamePathNodeKind.practice => LearningActivityKind.diagram,
          GamePathNodeKind.story => LearningActivityKind.story,
          GamePathNodeKind.listening => LearningActivityKind.listen,
          GamePathNodeKind.speaking => LearningActivityKind.speak,
          GamePathNodeKind.challenge ||
          GamePathNodeKind.legendary => LearningActivityKind.transfer,
        },
        outcome: LearningAttemptOutcome.completed,
        evidence: LearningEvidenceLevel.selfCompared,
        contentVersion: 'catalog-v4',
        learningDay: dayKeyOf(occurredAt),
        occurredAt: occurredAt.toUtc(),
      ),
      rules: const LearningCommitRules(),
    );
  }
}

Future<void> _seedEconomyGems(
  MemorySessionStore store, {
  required String seedId,
  required int amount,
}) async {
  final now = DateTime.now().subtract(const Duration(days: 1));
  final day = dayKeyOf(now);
  await store.commitLearningEvent(
    LearningEventCommand(
      eventId: 'seed-economy-$seedId',
      scope: LearningScope.personal,
      origin: LearningOrigin.path,
      courseId: 'science-ja-v1',
      nodeId: 'seed:economy:$seedId',
      activityId: 'seed.economy.$seedId',
      skillIds: const {'motion/fall'},
      activityKind: LearningActivityKind.read,
      outcome: LearningAttemptOutcome.completed,
      evidence: LearningEvidenceLevel.selfCompared,
      contentVersion: 'catalog-v7',
      learningDay: day,
      occurredAt: now.toUtc(),
    ),
    rules: LearningCommitRules(
      quests: [
        LearningQuestDefinition.daily(
          learningDay: day,
          questKey: 'economy-$seedId',
          definitionVersion: 'economy.test.v1',
          target: 1,
          rewardGems: amount,
        ),
      ],
    ),
  );
}

Future<void> _materializeDailyV2(
  MemorySessionStore store, {
  required String learningDay,
  required String questKey,
}) async {
  await store.materializeLearningQuestDefinitions(
    scope: LearningScope.personal,
    definitions: [
      LearningQuestPlannerV2.canonicalDefinitionForInstanceId(
        'daily:$learningDay:$questKey',
      ),
    ],
  );
}

Future<void> _seedNotationNode(
  MemorySessionStore store, {
  required DateTime at,
}) async {
  await store.commitLearningEvent(
    LearningEventCommand(
      eventId: 'seed-notation-v2',
      scope: LearningScope.personal,
      origin: LearningOrigin.lab,
      courseId: 'science-ja-v1',
      nodeId: 'notation:v1:motion:fall',
      activityId: 'seed.notation.v2',
      skillIds: const {'motion/fall'},
      activityKind: LearningActivityKind.equation,
      outcome: LearningAttemptOutcome.completed,
      evidence: LearningEvidenceLevel.structuredCorrection,
      contentVersion: 'catalog-v9',
      learningDay: dayKeyOf(at),
      occurredAt: at.toUtc(),
    ),
    rules: const LearningCommitRules(),
  );
}

Future<void> _seedMonthlyBadge(MemorySessionStore store) async {
  final now = DateTime.now();
  final day = dayKeyOf(now);
  final month = day.substring(0, 7);
  final quest = LearningQuestDefinition.monthly(
    learningMonth: month,
    questKey: LearningMonthlyBadgeCatalogV1.questKey,
    definitionVersion: LearningMonthlyBadgeCatalogV1.definitionVersion,
    target: LearningMonthlyBadgeCatalogV1.target,
    rewardGems: 8,
  );
  for (var index = 0; index < LearningMonthlyBadgeCatalogV1.target; index++) {
    final occurredAt = now.subtract(
      Duration(minutes: LearningMonthlyBadgeCatalogV1.target - index),
    );
    await store.commitLearningEvent(
      LearningEventCommand(
        eventId: 'seed-monthly-badge-$index',
        scope: LearningScope.personal,
        origin: LearningOrigin.path,
        courseId: 'science-ja-v1',
        nodeId: 'seed:monthly:badge:$index',
        activityId: 'seed.monthly.badge.$index',
        skillIds: const {'motion/fall'},
        activityKind: LearningActivityKind.read,
        outcome: LearningAttemptOutcome.completed,
        evidence: LearningEvidenceLevel.selfCompared,
        contentVersion: 'catalog-v7',
        learningDay: day,
        occurredAt: occurredAt.toUtc(),
      ),
      rules: LearningCommitRules(quests: [quest]),
    );
  }
}

Finder get _unitLegendaryScrollable => find
    .descendant(
      of: find.byKey(const ValueKey('science-unit-legendary-scroll')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _acceptCompletionCelebration(WidgetTester tester) async {
  await tester.pumpAndSettle();
  final celebration = find.byKey(const ValueKey('game-completion-celebration'));
  expect(celebration, findsOneWidget);
  expect(
    find.descendant(
      of: celebration,
      matching: find.byKey(const ValueKey('completion-time')),
    ),
    findsOneWidget,
  );
  expect(
    find.descendant(
      of: celebration,
      matching: find.text('時間はこの完了画面だけに表示し、端末へ保存しません。'),
    ),
    findsOneWidget,
  );
  expect(
    find.descendant(of: celebration, matching: find.textContaining('正答率')),
    findsNothing,
    reason: '測っていない自由記述の正答率を達成演出のために作らない',
  );
  final nextStep = find.byKey(const ValueKey('completion-next-step'));
  await tester.scrollUntilVisible(
    nextStep,
    160,
    scrollable: find
        .descendant(of: celebration, matching: find.byType(Scrollable))
        .first,
  );
  await tester.pump();
  await tester.tap(nextStep);
  await tester.pumpAndSettle();
}

Future<void> _openUnitLegendary(WidgetTester tester) async {
  final id = GamePathProjection.unitLegendaryNodeId('motion');
  final node = find.byKey(ValueKey<String>('game-path-node-$id'));
  final pathScroll = find.descendant(
    of: find.byKey(const PageStorageKey<String>('game-learning-path')),
    matching: find.byType(Scrollable),
  );
  await tester.scrollUntilVisible(node, 240, scrollable: pathScroll);
  await tester.pumpAndSettle();
  await tester.tap(node);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('game-node-sheet-start')));
  await tester.pumpAndSettle();
}

Future<void> _tapUnitLegendary(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    180,
    scrollable: _unitLegendaryScrollable,
  );
  await tester.pump();
  final bounds = tester.getRect(target);
  await tester.tapAt(Offset(bounds.center.dx, bounds.top + 12));
  await tester.pumpAndSettle();
}

Future<void> _completeOneConceptUnitLegendary(WidgetTester tester) async {
  await _tapUnitLegendary(
    tester,
    find.byKey(const ValueKey('cognitive-task-choice-review-conditions')),
  );
  await _tapUnitLegendary(
    tester,
    find.byKey(const ValueKey('unit-legendary-task-submit')),
  );
  await _tapUnitLegendary(
    tester,
    find.byKey(const ValueKey('unit-legendary-checkpoint-option-fall-same')),
  );
  await _tapUnitLegendary(
    tester,
    find.byKey(const ValueKey('unit-legendary-checkpoint-submit')),
  );
  final reflection = find.byKey(const ValueKey('unit-legendary-reflection'));
  await tester.scrollUntilVisible(
    reflection,
    180,
    scrollable: _unitLegendaryScrollable,
  );
  await tester.enterText(reflection, '単元の条件と結果をつないで比較した。');
  await tester.pump();
  await _tapUnitLegendary(
    tester,
    find.byKey(const ValueKey('unit-legendary-finish')),
  );
  await _acceptCompletionCelebration(tester);
}

Future<void> _failOneConceptUnitLegendary(WidgetTester tester) async {
  await _tapUnitLegendary(
    tester,
    find.byKey(const ValueKey('cognitive-task-choice-skip-conditions')),
  );
  await _tapUnitLegendary(
    tester,
    find.byKey(const ValueKey('unit-legendary-task-submit')),
  );
  await _tapUnitLegendary(
    tester,
    find.byKey(const ValueKey('unit-legendary-return-to-path')),
  );
}

Finder get _diagramScrollable => find
    .descendant(
      of: find.byKey(const ValueKey('science-diagram-scroll')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _tapDiagram(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 160, scrollable: _diagramScrollable);
  await tester.pump();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _finishDiagram(
  WidgetTester tester, {
  required bool fixedTaskCorrect,
}) async {
  await _tapDiagram(
    tester,
    find.byKey(
      ValueKey(
        fixedTaskCorrect
            ? 'cognitive-task-choice-review-conditions'
            : 'cognitive-task-choice-skip-conditions',
      ),
    ),
  );
  final reason = find.byKey(const ValueKey('science-diagram-reason'));
  await tester.scrollUntilVisible(reason, 160, scrollable: _diagramScrollable);
  await tester.enterText(reason, '条件を一つずつ分けて結果を予想した。');
  await _tapDiagram(
    tester,
    find.byKey(const ValueKey('science-diagram-submit')),
  );
  await _tapDiagram(
    tester,
    find.byKey(const ValueKey('science-diagram-revise')),
  );
  final reflection = find.byKey(const ValueKey('science-diagram-reflection'));
  await tester.scrollUntilVisible(
    reflection,
    160,
    scrollable: _diagramScrollable,
  );
  await tester.enterText(reflection, '教材の条件と自分の組み方を比べ直した。');
  await _tapDiagram(
    tester,
    find.byKey(const ValueKey('science-diagram-complete')),
  );
  await _acceptCompletionCelebration(tester);
}

Future<void> _activateAccessible(WidgetTester tester, Finder target) async {
  final widget = tester.widget(target);
  if (widget is ButtonStyleButton) {
    widget.onPressed!();
  } else if (widget is Semantics) {
    widget.properties.onTap!();
  } else {
    final semantics = find
        .descendant(of: target, matching: find.byType(Semantics))
        .first;
    tester.widget<Semantics>(semantics).properties.onTap!();
  }
  await tester.pumpAndSettle();
}

Future<void> _finishDiagramAtLargeText(
  WidgetTester tester, {
  required bool fixedTaskCorrect,
}) async {
  await _activateAccessible(
    tester,
    find.byKey(
      ValueKey(
        fixedTaskCorrect
            ? 'cognitive-task-choice-review-conditions'
            : 'cognitive-task-choice-skip-conditions',
      ),
    ),
  );
  await tester.enterText(
    find.byKey(const ValueKey('science-diagram-reason')),
    '条件を一つずつ分けて結果を予想した。',
  );
  await tester.pump();
  await _activateAccessible(
    tester,
    find.byKey(const ValueKey('science-diagram-submit')),
  );
  await _activateAccessible(
    tester,
    find.byKey(const ValueKey('science-diagram-revise')),
  );
  await tester.enterText(
    find.byKey(const ValueKey('science-diagram-reflection')),
    '教材の条件と自分の組み方を比べ直した。',
  );
  await tester.pump();
  await _activateAccessible(
    tester,
    find.byKey(const ValueKey('science-diagram-complete')),
  );
  await _activateAccessible(
    tester,
    find.byKey(const ValueKey('science-diagram-return-to-path')),
  );
}

Future<void> _openOptionalPracticeMode(WidgetTester tester, String mode) async {
  await tester.tap(find.byKey(const ValueKey('game-tab-practice')));
  await tester.pumpAndSettle();
  final tile = find.byKey(ValueKey('practice-mode-practice:$mode'));
  await tester.scrollUntilVisible(
    tile,
    260,
    scrollable: find.descendant(
      of: find.byKey(const ValueKey('practice-hub-screen')),
      matching: find.byType(Scrollable),
    ),
  );
  tester
      .widget<InkWell>(
        find.descendant(of: tile, matching: find.byType(InkWell)),
      )
      .onTap!();
  await tester.pumpAndSettle();
}

Future<void> _tapMiniGameControl(
  WidgetTester tester, {
  required String scrollKey,
  required String controlKey,
}) async {
  final control = find.byKey(ValueKey(controlKey));
  await tester.scrollUntilVisible(
    control,
    160,
    scrollable: find
        .descendant(
          of: find.byKey(ValueKey(scrollKey)),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.pump();
  await tester.tap(control);
  await tester.pumpAndSettle();
}

Future<void> _completeAvailableLesson(
  WidgetTester tester, {
  bool acceptCelebration = true,
}) async {
  await tester.tap(find.byKey(const ValueKey('game-tab-path')));
  await tester.pumpAndSettle();
  final lessonId = GamePathProjection.nodeId(
    'motion',
    'fall',
    GamePathNodeKind.lesson,
  );
  final node = find.byKey(ValueKey<String>('game-path-node-$lessonId'));
  final pathScroll = find.descendant(
    of: find.byKey(const PageStorageKey<String>('game-learning-path')),
    matching: find.byType(Scrollable),
  );
  await tester.scrollUntilVisible(node, 220, scrollable: pathScroll);
  await tester.tap(node);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('game-node-sheet-start')));
  await tester.pumpAndSettle();

  Future<void> scrollToAndTap(Finder target) async {
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('science-lesson-scroll')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    final bounds = tester.getRect(target);
    await tester.tapAt(Offset(bounds.center.dx, bounds.top + 12));
    await tester.pumpAndSettle();
  }

  await tester.enterText(
    find.byKey(const ValueKey('science-lesson-prediction')),
    '重さだけでは決まらないと思う',
  );
  await scrollToAndTap(find.byKey(const ValueKey('science-lesson-reveal')));
  await scrollToAndTap(find.byKey(const ValueKey('science-lesson-compare')));
  await tester.tap(find.text('残す点'));
  await tester.enterText(
    find.byKey(const ValueKey('science-lesson-reflection')),
    '真空という条件を残す',
  );
  await scrollToAndTap(find.byKey(const ValueKey('science-lesson-complete')));
  if (acceptCelebration) {
    await _acceptCompletionCelebration(tester);
  }
}

Future<void> _completeAvailableDiagram(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('game-tab-path')));
  await tester.pumpAndSettle();
  final practiceId = GamePathProjection.nodeId(
    'motion',
    'fall',
    GamePathNodeKind.practice,
  );
  final node = find.byKey(ValueKey<String>('game-path-node-$practiceId'));
  final pathScroll = find.descendant(
    of: find.byKey(const PageStorageKey<String>('game-learning-path')),
    matching: find.byType(Scrollable),
  );
  await tester.scrollUntilVisible(node, 220, scrollable: pathScroll);
  await tester.tap(node);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('game-node-sheet-start')));
  await tester.pumpAndSettle();
  await _finishDiagram(tester, fixedTaskCorrect: true);
}

Future<void> _completeAvailableStory(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('game-tab-path')));
  await tester.pumpAndSettle();
  final storyId = GamePathProjection.nodeId(
    'motion',
    'fall',
    GamePathNodeKind.story,
  );
  final node = find.byKey(ValueKey<String>('game-path-node-$storyId'));
  final pathScroll = find.descendant(
    of: find.byKey(const PageStorageKey<String>('game-learning-path')),
    matching: find.byType(Scrollable),
  );
  await tester.scrollUntilVisible(node, 220, scrollable: pathScroll);
  await tester.tap(node);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('game-node-sheet-start')));
  await tester.pumpAndSettle();

  final storyScroll = find
      .descendant(
        of: find.byKey(const ValueKey('science-story-scroll')),
        matching: find.byType(Scrollable),
      )
      .first;
  Future<void> scrollToAndTap(Finder target) async {
    await tester.scrollUntilVisible(target, 160, scrollable: storyScroll);
    await tester.pump();
    await tester.drag(storyScroll, const Offset(0, -100));
    await tester.pump();
    if (target.hitTestable().evaluate().isEmpty) {
      ScaffoldMessenger.of(tester.element(target)).clearSnackBars();
      await tester.pumpAndSettle();
      await tester.ensureVisible(target);
      await tester.pump();
    }
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  await scrollToAndTap(
    find.byKey(const ValueKey('science-story-open-judgment')),
  );
  await scrollToAndTap(find.byKey(const ValueKey('science-story-option-same')));
  expect(
    tester
        .widget<FilledButton>(
          find.byKey(const ValueKey('science-story-submit-judgment')),
        )
        .onPressed,
    isNotNull,
  );
  await scrollToAndTap(
    find.byKey(const ValueKey('science-story-submit-judgment')),
  );
  await scrollToAndTap(
    find.byKey(const ValueKey('science-story-reaction-to-comparison')),
  );
  await scrollToAndTap(find.byKey(const ValueKey('science-story-complete')));
  await _acceptCompletionCelebration(tester);
}

Future<void> _seedActiveNeed(
  MemorySessionStore store, {
  required String seedId,
  required String needCode,
}) async {
  final now = DateTime.now().subtract(const Duration(minutes: 2));
  await store.commitLearningEvent(
    LearningEventCommand(
      eventId: 'seed-need-$seedId',
      scope: LearningScope.personal,
      origin: LearningOrigin.lab,
      courseId: 'science-ja-v1',
      nodeId: 'seed:need:$seedId',
      activityId: 'seed.need.$seedId',
      skillIds: const {'motion/fall'},
      activityKind: LearningActivityKind.checkpoint,
      outcome: LearningAttemptOutcome.retryNeeded,
      evidence: LearningEvidenceLevel.participation,
      contentVersion: 'catalog-v9',
      learningDay: dayKeyOf(now),
      occurredAt: now.toUtc(),
      practiceNeedCodes: {
        'motion/fall': {needCode},
      },
    ),
  );
}

Future<void> _openFirstRepair(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('game-tab-practice')));
  await tester.pumpAndSettle();
  final repair = find.byKey(const ValueKey('practice-mode-practice:repair'));
  await tester.scrollUntilVisible(
    repair,
    180,
    scrollable: find.descendant(
      of: find.byKey(const ValueKey('practice-hub-screen')),
      matching: find.byType(Scrollable),
    ),
  );
  tester
      .widget<InkWell>(
        find.descendant(of: repair, matching: find.byType(InkWell)),
      )
      .onTap!();
  await tester.pumpAndSettle();
}

Future<void> _completeListeningRoute(
  WidgetTester tester, {
  required String transcript,
  bool textOnly = false,
}) async {
  final routeScroll = find
      .descendant(
        of: find.byKey(const ValueKey('science-listening-scroll')),
        matching: find.byType(Scrollable),
      )
      .first;
  Future<void> tap(Finder target) async {
    await tester.scrollUntilVisible(target, 180, scrollable: routeScroll);
    await tester.pump();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  await tap(find.text('説明を聞く'));
  if (textOnly) {
    await tap(find.byKey(const ValueKey('listening-text-fallback')));
  } else {
    await tester.enterText(
      find.byKey(const ValueKey('listening-transcription-input')),
      transcript,
    );
    await tester.pump();
    await tap(find.text('教材の文と比べる'));
    await tap(find.byKey(const ValueKey('listening-open-meaning')));
  }
  await tap(find.byKey(const ValueKey('listening-option-same')));
  await tap(find.text('この判断で比べる'));
  await tap(find.text(textOnly ? '文字教材の確認を終える' : '聞き取りを完了する'));
}

Finder get _offlineScrollable => find
    .descendant(
      of: find.byKey(const ValueKey('offline-practice-scroll')),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _tapOffline(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 160, scrollable: _offlineScrollable);
  await tester.pump();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _enterOffline(
  WidgetTester tester, {
  required Key key,
  required String text,
}) async {
  final keyed = find.byKey(key);
  final field = tester.widget(keyed) is TextField
      ? keyed
      : find.descendant(of: keyed, matching: find.byType(TextField));
  await tester.scrollUntilVisible(field, 160, scrollable: _offlineScrollable);
  await tester.enterText(field, text);
  await tester.pump();
}

Future<void> _finishChapterBoss(WidgetTester tester) async {
  await _enterOffline(
    tester,
    key: const ValueKey('offline-recall-input'),
    text: '条件をそろえて落下を考える。',
  );
  await _tapOffline(tester, find.byKey(const ValueKey('offline-recall-next')));
  await _tapOffline(
    tester,
    find.byKey(const ValueKey('cognitive-task-choice-review-conditions')),
  );
  await _tapOffline(tester, find.byKey(const ValueKey('offline-task-next')));
  await _enterOffline(
    tester,
    key: const ValueKey('offline-reasoning-input'),
    text: '空気抵抗を分けて考えた。',
  );
  await _tapOffline(
    tester,
    find.byKey(const ValueKey('offline-reasoning-next')),
  );
  await _tapOffline(
    tester,
    find.byKey(const ValueKey('offline-checkpoint-option-same')),
  );
  await _tapOffline(
    tester,
    find.byKey(const ValueKey('offline-checkpoint-submit')),
  );
  await _tapOffline(
    tester,
    find.byKey(const ValueKey('prediction-result-decision-keep')),
  );
  await _enterOffline(
    tester,
    key: const ValueKey('prediction-result-reflection-input'),
    text: '自分の予想と教材の条件を比べた。',
  );
  await _tapOffline(
    tester,
    find.byKey(const ValueKey('prediction-result-complete')),
  );
}

void main() {
  testWidgets('online同意時だけ確定済みmeaningful eventを自動寄与する', (tester) async {
    final store = MemorySessionStore();
    final contributed = <LearningEventRecord>[];
    await tester.pumpWidget(
      _app(
        store,
        lanSocialAllowed: true,
        lanSocialContributor: (event) async => contributed.add(event),
      ),
    );
    await tester.pumpAndSettle();

    await _completeAvailableLesson(tester);

    expect(contributed, hasLength(1));
    expect(contributed.single.scope, LearningScope.personal);
    expect(contributed.single.meaningfulProgress, isTrue);
    expect(contributed.single.eventId, startsWith('event:run:'));
  });

  testWidgets('social失敗でも成功済み学習eventとPathをblankにしない', (tester) async {
    final store = MemorySessionStore();
    await tester.pumpWidget(
      _app(
        store,
        lanSocialAllowed: true,
        lanSocialContributor: (_) =>
            Future<void>.error(StateError('injected social snapshot failure')),
      ),
    );
    await tester.pumpAndSettle();

    await _completeAvailableLesson(tester);

    final snapshot = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(snapshot.events, hasLength(1));
    expect(
      find.byKey(const PageStorageKey<String>('game-learning-path')),
      findsOneWidget,
    );
    expect(find.text('学習パスを準備できませんでした。'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('壊れたmembershipと二重reloadでも実dispatcherが学習コアを巻き戻さない', (
    tester,
  ) async {
    final store = MemorySessionStore();
    const corruptMembership =
        '{"version":1,"memberships":[{"deviceId":"raw-device-id"}]}';
    await store.setSetting('lan_social.memberships.v1', corruptMembership);
    await tester.pumpWidget(_app(store, lanSocialAllowed: true));
    await tester.pumpAndSettle();

    await _completeAvailableLesson(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    final snapshot = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(snapshot.events, hasLength(1));
    expect(snapshot.events.single.meaningfulProgress, isTrue);
    expect(
      await store.getSetting('lan_social.memberships.v1'),
      corruptMembership,
      reason: 'Social破損を学習台帳へ混ぜず、推測で資格を作り直さない',
    );
    expect(
      find.byKey(const PageStorageKey<String>('game-learning-path')),
      findsOneWidget,
    );
    expect(find.text('学習パスを準備できませんでした。'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('同梱catalogから6タブと実Lesson routeを開く', (tester) async {
    final store = MemorySessionStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    for (final tab in [
      'path',
      'stories',
      'practice',
      'notation',
      'league',
      'profile',
    ]) {
      expect(find.byKey(ValueKey('game-tab-$tab')), findsOneWidget);
    }
    final statusHeader = find.byKey(
      const ValueKey('game-player-status-header'),
    );
    expect(statusHeader, findsOneWidget);
    expect(find.byKey(const ValueKey('player-status-bar')), findsOneWidget);
    for (final tab in [
      'stories',
      'practice',
      'notation',
      'league',
      'profile',
    ]) {
      await tester.tap(find.byKey(ValueKey<String>('game-tab-$tab')));
      await tester.pumpAndSettle();
      expect(statusHeader, findsOneWidget);
      expect(
        find.byKey(const ValueKey('path-mascot-standard')),
        findsOneWidget,
      );
      if (tab != 'profile') {
        expect(find.byKey(const ValueKey('game-hero-mascot')), findsOneWidget);
      }
    }
    await tester.tap(find.byKey(const ValueKey('game-tab-path')));
    await tester.pumpAndSettle();
    expect(statusHeader, findsOneWidget);
    expect(find.byKey(const ValueKey('player-status-bar')), findsOneWidget);

    final lessonId = GamePathProjection.nodeId(
      'motion',
      'fall',
      GamePathNodeKind.lesson,
    );
    final node = find.byKey(ValueKey<String>('game-path-node-$lessonId'));
    final pathScroll = find.descendant(
      of: find.byKey(const PageStorageKey<String>('game-learning-path')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(node, 220, scrollable: pathScroll);
    await tester.pumpAndSettle();
    await tester.tap(node);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game-node-sheet')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('game-node-sheet-start')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('science-lesson-prediction')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('game-activity-scaffold')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('game-activity-status')), findsOneWidget);
    expect(find.byKey(const ValueKey('game-activity-exit')), findsOneWidget);
    expect(find.bySemanticsLabel('学習ハート、5個中5個'), findsOneWidget);
    _expectSingleActivityChrome(tester);
    expect(find.text('物体には重力がはたらく。'), findsNothing);
  });

  testWidgets('進捗保存に失敗した完了は祝福やXPを先に見せない', (tester) async {
    final store = _FailNextLearningCommitStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    store.failNextCommit = true;

    await _completeAvailableLesson(tester, acceptCelebration: false);

    expect(
      find.byKey(const ValueKey('game-completion-celebration')),
      findsNothing,
    );
    expect(find.text('端末への進捗保存が完了していません。Pathからもう一度開けます。'), findsOneWidget);
    final snapshot = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(snapshot.events, isEmpty);
    expect(snapshot.wallet.xp, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('冪等再送の既存rewardを今回の獲得XPとして再表示しない', (tester) async {
    final store = _ReplayRewardResultStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await _completeAvailableLesson(tester, acceptCelebration: false);

    final celebration = find.byKey(
      const ValueKey('game-completion-celebration'),
    );
    expect(celebration, findsOneWidget);
    expect(
      find.descendant(of: celebration, matching: find.text('+0')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: celebration, matching: find.text('+10')),
      findsNothing,
      reason: '既存eventに紐づくrewardは今回の新規獲得ではない',
    );
    await _acceptCompletionCelebration(tester);
  });

  testWidgets('foregroundの午前4時境界でfreeze仮投影を更新し次の境界も再設定する', (tester) async {
    final store = MemorySessionStore();
    await store.commitLearningEvent(
      LearningEventCommand(
        eventId: 'seed-boundary-day',
        scope: LearningScope.personal,
        origin: LearningOrigin.path,
        courseId: 'science-ja-v1',
        nodeId: 'seed:boundary',
        activityId: 'seed.boundary',
        skillIds: const {'motion/fall'},
        activityKind: LearningActivityKind.read,
        outcome: LearningAttemptOutcome.completed,
        evidence: LearningEvidenceLevel.selfCompared,
        contentVersion: 'catalog-v8',
        learningDay: '2026-08-10',
        occurredAt: DateTime.utc(2026, 8, 10, 12),
      ),
    );
    var now = DateTime(2026, 8, 12, 3, 59);
    await tester.pumpWidget(_app(store, now: () => now));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp(r'連続記録の保護、1回分')), findsOneWidget);

    now = DateTime(2026, 8, 12, 4);
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp(r'連続記録の保護、0回分')), findsOneWidget);

    now = DateTime(2026, 8, 13, 4);
    await tester.pump(const Duration(days: 1));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp(r'連続記録の保護、1回分')),
      findsOneWidget,
      reason: '最初の4時更新後も翌日の境界timerを再設定する',
    );
  });

  testWidgets('任意リーグ参照が失敗してもPathと最新の学習進捗を失わない', (tester) async {
    final store = _FailLocalCoopReadStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const PageStorageKey<String>('game-learning-path')),
      findsOneWidget,
    );
    await _completeAvailableLesson(tester);

    final snapshot = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(snapshot.events, hasLength(1));
    final lessonId = GamePathProjection.nodeId(
      'motion',
      'fall',
      GamePathNodeKind.lesson,
    );
    final node = find.byKey(ValueKey<String>('game-path-node-$lessonId'));
    final pathScroll = find.descendant(
      of: find.byKey(const PageStorageKey<String>('game-learning-path')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(node, 220, scrollable: pathScroll);
    await tester.tap(node);
    await tester.pumpAndSettle();
    expect(find.text('もう一度やる'), findsOneWidget);
  });

  testWidgets('初回5〜10分はLessonから構造練習へ進み報酬・連続学習・Storyを正しく開く', (tester) async {
    final store = MemorySessionStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await _completeAvailableLesson(tester);
    final practiceId = GamePathProjection.nodeId(
      'motion',
      'fall',
      GamePathNodeKind.practice,
    );
    final practiceNode = find.byKey(
      ValueKey<String>('game-path-node-$practiceId'),
    );
    expect(find.text('次はここ'), findsOneWidget);
    expect(
      find.byKey(ValueKey('game-path-current-ring-$practiceId')),
      findsOneWidget,
      reason: '祝福面の主CTAから戻ると次の一歩を形と文言で強調する',
    );
    var pathScroll = find.descendant(
      of: find.byKey(const PageStorageKey<String>('game-learning-path')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(practiceNode, 220, scrollable: pathScroll);
    await tester.tap(practiceNode);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-node-sheet-start')));
    await tester.pumpAndSettle();
    await _finishDiagram(tester, fixedTaskCorrect: true);

    final snapshot = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(snapshot.events, hasLength(2));
    expect(snapshot.wallet.xp, 20);
    expect(snapshot.wallet.gems, 1);
    final daily = snapshot.quests.singleWhere(
      (quest) => quest.questInstanceId.startsWith('daily:'),
    );
    expect(
      daily.questInstanceId,
      'daily:${dayKeyOf(DateTime.now())}:compare-prediction',
    );
    expect(daily.definitionVersion, LearningQuestPlannerV2.definitionVersion);
    expect(daily.target, 1);
    expect(daily.progress, 1);
    expect(find.bySemanticsLabel(RegExp(r'^連続学習、1日')), findsOneWidget);

    final storyId = GamePathProjection.nodeId(
      'motion',
      'fall',
      GamePathNodeKind.story,
    );
    final storyNode = find.byKey(ValueKey<String>('game-path-node-$storyId'));
    expect(
      find.byKey(ValueKey('game-path-current-ring-$storyId')),
      findsOneWidget,
    );
    pathScroll = find.descendant(
      of: find.byKey(const PageStorageKey<String>('game-learning-path')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(storyNode, 220, scrollable: pathScroll);
    await tester.tap(storyNode);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game-node-sheet')), findsOneWidget);
    expect(find.text('レッスン開始'), findsOneWidget);
  });

  testWidgets('学校modeは個人報酬を表示せずハート無制限', (tester) async {
    final store = MemorySessionStore();
    await tester.pumpWidget(_app(store, schoolMode: true));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('ハート、無制限')), findsOneWidget);
    expect(find.text('協力'), findsOneWidget);
    expect(find.bySemanticsLabel('この端末の授業目標'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('game-tab-league')));
    await tester.pumpAndSettle();
    expect(find.text('同じ課題に、並んで挑む'), findsOneWidget);
    expect(find.text('0 / 0'), findsNothing);
  });

  testWidgets('個人heart 0は通常Pathを止め、320x568・文200%の回復練習で1個戻して再起動後に再開する', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final store = MemorySessionStore();
    await _seedNodes(store, const [GamePathNodeKind.lesson]);
    await _depletePersonalHearts(store);
    await tester.pumpWidget(_app(store, textScale: 2));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('学習ハート.*5個中0個')), findsOneWidget);

    final practiceId = GamePathProjection.nodeId(
      'motion',
      'fall',
      GamePathNodeKind.practice,
    );
    final practiceNode = find.byKey(
      ValueKey<String>('game-path-node-$practiceId'),
    );
    tester.widget<Semantics>(practiceNode).properties.onTap!();
    await tester.pumpAndSettle();
    final sheetStart = find.byKey(const ValueKey('game-node-sheet-start'));
    await tester.scrollUntilVisible(
      sheetStart,
      160,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('game-node-sheet')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(sheetStart);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('science-diagram-screen')), findsNothing);
    expect(find.textContaining('ハートがありません'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('game-tab-practice')));
    await tester.pumpAndSettle();
    final recovery = find.byKey(
      const ValueKey('practice-mode-practice:heart-recovery'),
    );
    await tester.scrollUntilVisible(
      recovery,
      140,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('practice-hub-screen')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(tester.getSize(recovery).height, greaterThanOrEqualTo(48));
    tester
        .widget<InkWell>(
          find.descendant(of: recovery, matching: find.byType(InkWell)),
        )
        .onTap!();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('science-diagram-screen')),
      findsOneWidget,
    );
    await _finishDiagramAtLargeText(tester, fixedTaskCorrect: true);

    var snapshot = await store.learningProgressSnapshot(LearningScope.personal);
    expect(snapshot.challengeHearts?.current, 1);
    expect(
      snapshot.events.where(
        (event) => event.activityId == 'practice.heart-recovery.v1',
      ),
      hasLength(1),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(store, textScale: 2));
    await tester.pumpAndSettle();
    snapshot = await store.learningProgressSnapshot(LearningScope.personal);
    expect(snapshot.challengeHearts?.current, 1);

    tester.widget<Semantics>(practiceNode).properties.onTap!();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      sheetStart,
      160,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('game-node-sheet')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(sheetStart);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('science-diagram-screen')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('回復練習は保存fail-first後も同じevent・recovery IDで再実行して1個だけ戻す', (
    tester,
  ) async {
    final store = _FailFirstHeartRecoveryStore();
    await _seedNodes(store, const [GamePathNodeKind.lesson]);
    await _depletePersonalHearts(store);
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('game-tab-practice')));
    await tester.pumpAndSettle();
    final recovery = find.byKey(
      const ValueKey('practice-mode-practice:heart-recovery'),
    );
    await tester.scrollUntilVisible(
      recovery,
      140,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('practice-hub-screen')),
        matching: find.byType(Scrollable),
      ),
    );
    tester
        .widget<InkWell>(
          find.descendant(of: recovery, matching: find.byType(InkWell)),
        )
        .onTap!();
    await tester.pumpAndSettle();
    await _finishDiagramAtLargeText(tester, fixedTaskCorrect: true);

    final snapshot = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(store.recoveryRequests, hasLength(2));
    expect(store.recoveryRequests.toSet(), hasLength(1));
    expect(store.appliedRecoveries, 1);
    expect(snapshot.challengeHearts?.current, 1);
    expect(
      snapshot.events.where(
        (event) => event.activityId == 'practice.heart-recovery.v1',
      ),
      hasLength(1),
    );

    final request = store.recoveryRequests.first;
    final replay = await store.recoverLearningChallengeHeartWithPractice(
      recoveryId: request.recoveryId,
      sourceEventId: request.sourceEventId,
      learningDay: request.learningDay,
      occurredAt: request.occurredAt,
    );
    expect(replay.applied, isFalse);
    expect(store.appliedRecoveries, 1);
    expect(
      (await store.learningProgressSnapshot(
        LearningScope.personal,
      )).challengeHearts?.current,
      1,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('練習タブは日次ListeningとSpeakingを別missionから各専用画面へ開く', (tester) async {
    final store = MemorySessionStore();
    await _seedNodes(store, const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
      GamePathNodeKind.story,
      GamePathNodeKind.listening,
    ]);
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('game-tab-practice')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('daily-audio-practice-panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('practice-mode-practice:listen-speak')),
      findsNothing,
      reason: '聞く・話すを結合した旧laneは日次panelと重複させない',
    );

    await tester.tap(find.byKey(const ValueKey('daily-audio-listening')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('science-listening-scroll')),
      findsOneWidget,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    final speakingMission = find.byKey(const ValueKey('daily-audio-speaking'));
    await tester.scrollUntilVisible(
      speakingMission,
      160,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('practice-hub-screen')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();
    await tester.tap(speakingMission);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('science-speak-listen-scroll')),
      findsOneWidget,
    );

    final snapshot = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(
      snapshot.runs.map((run) => run.nodeId),
      containsAll(<String>{
        GamePathProjection.nodeId('motion', 'fall', GamePathNodeKind.listening),
        GamePathProjection.nodeId('motion', 'fall', GamePathNodeKind.speaking),
      }),
      reason: '回答や音声ではなく各Path nodeのrun位置だけを分離して残す',
    );
  });

  testWidgets(
    'production HomeのListeningは音声→文字起こし→意味判断を完了し、誤りはneed/heartだけ保存する',
    (tester) async {
      const narrationChannel = MethodChannel(
        'jp.dekisugi.dekisugi/local_narration',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(narrationChannel, (call) async {
            if (call.method == 'speak') return true;
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(narrationChannel, null),
      );
      final store = _CountingHeartStore();
      await _seedNodes(store, const [
        GamePathNodeKind.lesson,
        GamePathNodeKind.practice,
        GamePathNodeKind.story,
        GamePathNodeKind.listening,
      ]);
      final before = await store.learningProgressSnapshot(
        LearningScope.personal,
      );
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('game-tab-practice')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('daily-audio-listening')));
      await tester.pumpAndSettle();

      final listening = tester.widget<ScienceListeningScreen>(
        find.byType(ScienceListeningScreen),
      );
      final listeningVariant = _unit.sections.single.practiceVariantForAttempt(
        listening.practiceAttempt,
      );

      final routeScroll = find.byType(Scrollable).first;
      Future<void> tapListening(Finder target) async {
        await tester.scrollUntilVisible(target, 180, scrollable: routeScroll);
        await tester.pump();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      expect(find.textContaining('1 OF 4'), findsOneWidget);
      await tapListening(find.text('説明を聞く'));
      expect(
        find.byKey(const ValueKey('listening-transcription-input')),
        findsOneWidget,
      );
      const privateTranscript = '重い物体だけを聞き取った独自回答';
      await tester.enterText(
        find.byKey(const ValueKey('listening-transcription-input')),
        privateTranscript,
      );
      await tester.pump();
      await tapListening(find.text('教材の文と比べる'));
      expect(find.text('聞き取りの差を確認'), findsOneWidget);
      await tapListening(find.byKey(const ValueKey('listening-open-meaning')));
      await tapListening(find.byKey(const ValueKey('listening-option-same')));
      await tapListening(find.text('この判断で比べる'));
      await tapListening(find.text('聞き取りを完了する'));
      expect(
        find.byKey(const ValueKey('game-completion-celebration')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('completion-next-step')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('science-listening-scroll')),
        findsNothing,
      );

      final after = await store.learningProgressSnapshot(
        LearningScope.personal,
      );
      expect(store.appliedHeartLosses, 1);
      expect(after.challengeHearts?.current, 4);
      expect(after.activeNeeds, hasLength(1));
      expect(after.activeNeeds.single.skillId, 'motion/fall');
      expect(
        after.activeNeeds.single.needCode,
        listeningVariant.listeningNeedCodes!.transcript,
      );
      expect(
        after.events
            .where((event) => event.activityId == 'path.listening.v1')
            .length,
        before.events
                .where((event) => event.activityId == 'path.listening.v1')
                .length +
            1,
      );
      final persistedFixedFields = <String>[
        for (final event in after.events) ...[
          event.eventId,
          event.nodeId,
          event.activityId,
        ],
        for (final need in after.activeNeeds) ...[need.skillId, need.needCode],
        for (final run in after.runs) ...[run.runId, run.nodeId],
      ].join('|');
      expect(persistedFixedFields, isNot(contains(privateTranscript)));
      expect(
        (await store.recentSessions()).expand((session) => session.transcript),
        isEmpty,
        reason: 'Listeningの入力本文を旧逐語sessionへ混ぜない',
      );
    },
  );

  testWidgets('必修Speakingは1文字説明だけではevent・XPを作らず固定問い返しと訂正後だけ完了する', (
    tester,
  ) async {
    const narrationChannel = MethodChannel(
      'jp.dekisugi.dekisugi/local_narration',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(narrationChannel, (call) async {
          if (call.method == 'speak') return true;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(narrationChannel, null),
    );
    final store = MemorySessionStore();
    await _seedNodes(store, const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
      GamePathNodeKind.story,
      GamePathNodeKind.listening,
    ]);
    final before = await store.learningProgressSnapshot(LearningScope.personal);
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-tab-practice')));
    await tester.pumpAndSettle();
    final speakingMission = find.byKey(const ValueKey('daily-audio-speaking'));
    await tester.scrollUntilVisible(
      speakingMission,
      160,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('practice-hub-screen')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();
    await tester.tap(speakingMission);
    await tester.pumpAndSettle();

    final speaking = tester.widget<ScienceSpeakListenScreen>(
      find.byType(ScienceSpeakListenScreen),
    );
    final variant = _unit.sections.single.practiceVariantForAttempt(
      speaking.practiceAttempt,
    );
    final wrongOption = variant.checkpoint.options.firstWhere(
      (option) => option.id != variant.checkpoint.correctOptionId,
    );
    final correctOption = variant.checkpoint.optionFor(
      variant.checkpoint.correctOptionId,
    )!;

    Future<void> tapSpeaking(Key key) async {
      final target = find.byKey(key);
      await tester.scrollUntilVisible(
        target,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    await tapSpeaking(const ValueKey('science-explain-choose-text'));
    await tester.enterText(
      find.byKey(const ValueKey('science-explain-text-input')),
      '一',
    );
    await tester.pump();
    await tapSpeaking(const ValueKey('science-explain-review-text'));
    await tapSpeaking(const ValueKey('science-explain-submit-text'));

    expect(
      find.byKey(const ValueKey('science-explain-follow-up')),
      findsOneWidget,
    );
    final oneCharacterOnly = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(
      oneCharacterOnly.events.where(
        (event) => event.activityId == 'path.speaking.v1',
      ),
      isEmpty,
    );
    expect(oneCharacterOnly.wallet.xp, before.wallet.xp);

    await tapSpeaking(
      ValueKey('science-explain-follow-up-option-${wrongOption.id}'),
    );
    await tapSpeaking(const ValueKey('science-explain-submit-follow-up'));
    expect(
      find.byKey(const ValueKey('science-explain-follow-up-hint')),
      findsOneWidget,
    );
    expect(find.text(correctOption.text), findsNothing);
    await tapSpeaking(const ValueKey('science-explain-start-revision'));
    await tester.enterText(
      find.byKey(const ValueKey('science-explain-text-input')),
      '一。理由と成立条件を足して言い直す',
    );
    await tester.pump();
    await tapSpeaking(const ValueKey('science-explain-review-text'));
    await tapSpeaking(const ValueKey('science-explain-submit-text'));
    expect(
      find.byKey(const ValueKey('science-explain-comparison')),
      findsOneWidget,
    );
    await tapSpeaking(const ValueKey('science-explain-keep'));

    expect(
      find.byKey(const ValueKey('game-completion-celebration')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('completion-next-step')));
    await tester.pumpAndSettle();

    final completed = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(
      completed.events.where((event) => event.activityId == 'path.speaking.v1'),
      hasLength(1),
    );
    expect(
      completed.events
          .singleWhere((event) => event.activityId == 'path.speaking.v1')
          .contentVersion,
      'catalog-v10',
    );
    expect(completed.wallet.xp, before.wallet.xp + 10);
    expect(completed.challengeHearts?.current, 4);
    expect(completed.activeNeeds, hasLength(1));
    expect(completed.activeNeeds.single.needCode, wrongOption.needCode);
    expect(
      (await store.recentSessions()).expand((session) => session.transcript),
      isEmpty,
      reason: 'Speakingの自由説明を旧逐語sessionへ混ぜない',
    );
    final persistedFixedFields = <String>[
      for (final event in completed.events) ...[
        event.eventId,
        event.nodeId,
        event.activityId,
      ],
      for (final need in completed.activeNeeds) ...[
        need.skillId,
        need.needCode,
      ],
    ].join('|');
    expect(persistedFixedFields, isNot(contains('理由と成立条件を足して言い直す')));
  });

  testWidgets('Speakingの誤答直後に戻ってもheartだけを減らさずcanonical needをRepairへ残す', (
    tester,
  ) async {
    const narrationChannel = MethodChannel(
      'jp.dekisugi.dekisugi/local_narration',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(narrationChannel, (call) async {
          if (call.method == 'speak') return true;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(narrationChannel, null),
    );
    final store = MemorySessionStore();
    await _seedNodes(store, const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
      GamePathNodeKind.story,
      GamePathNodeKind.listening,
    ]);
    final before = await store.learningProgressSnapshot(LearningScope.personal);
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-tab-practice')));
    await tester.pumpAndSettle();
    final mission = find.byKey(const ValueKey('daily-audio-speaking'));
    await tester.scrollUntilVisible(
      mission,
      160,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('practice-hub-screen')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();
    await tester.tap(mission);
    await tester.pumpAndSettle();

    final speaking = tester.widget<ScienceSpeakListenScreen>(
      find.byType(ScienceSpeakListenScreen),
    );
    final variant = _unit.sections.single.practiceVariantForAttempt(
      speaking.practiceAttempt,
    );
    final wrongOption = variant.checkpoint.options.firstWhere(
      (option) => option.id != variant.checkpoint.correctOptionId,
    );

    Future<void> tapSpeaking(Key key) async {
      final target = find.byKey(key);
      await tester.scrollUntilVisible(
        target,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    await tapSpeaking(const ValueKey('science-explain-choose-text'));
    await tester.enterText(
      find.byKey(const ValueKey('science-explain-text-input')),
      '一',
    );
    await tapSpeaking(const ValueKey('science-explain-review-text'));
    await tapSpeaking(const ValueKey('science-explain-submit-text'));
    await tapSpeaking(
      ValueKey('science-explain-follow-up-option-${wrongOption.id}'),
    );
    await tapSpeaking(const ValueKey('science-explain-submit-follow-up'));
    expect(
      find.byKey(const ValueKey('science-explain-follow-up-hint')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('game-activity-exit')));
    await tester.pumpAndSettle();

    final after = await store.learningProgressSnapshot(LearningScope.personal);
    expect(
      after.events.where((event) => event.activityId == 'path.speaking.v1'),
      isEmpty,
      reason: '訂正と自己比較を終えていないのでnode完了・XPを作らない',
    );
    expect(after.wallet.xp, before.wallet.xp);
    expect(after.challengeHearts?.current, 4);
    expect(after.activeNeeds, hasLength(1));
    expect(after.activeNeeds.single.needCode, wrongOption.needCode);
    expect(
      after.events.where(
        (event) => event.activityId == 'path.speaking.need.v1',
      ),
      hasLength(1),
    );
  });

  testWidgets('同じ4時学習日の実eventから聞く完了・話す未完了を別表示する', (tester) async {
    final store = MemorySessionStore();
    await _seedNodes(store, const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
      GamePathNodeKind.story,
      GamePathNodeKind.listening,
    ]);
    final before = await store.learningProgressSnapshot(LearningScope.personal);
    final now = DateTime.now();
    await store.commitLearningEvent(
      LearningEventCommand(
        eventId: 'daily-audio-listening-today',
        scope: LearningScope.personal,
        origin: LearningOrigin.practice,
        courseId: 'science-ja-v1',
        nodeId: GamePathProjection.nodeId(
          'motion',
          'fall',
          GamePathNodeKind.listening,
        ),
        activityId: 'path.listening.v1',
        skillIds: const {'motion/fall'},
        activityKind: LearningActivityKind.listen,
        outcome: LearningAttemptOutcome.completed,
        evidence: LearningEvidenceLevel.selfCompared,
        contentVersion: 'catalog-v6',
        learningDay: dayKeyOf(now),
        occurredAt: now.toUtc(),
      ),
      rules: const LearningCommitRules(),
    );
    final after = await store.learningProgressSnapshot(LearningScope.personal);
    expect(
      after.rewards,
      hasLength(before.rewards.length),
      reason: '完了済みnodeの日次再練習eventへ報酬を二重付与しない',
    );

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-tab-practice')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('daily-audio-listening-completed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('daily-audio-speaking-completed')),
      findsNothing,
    );
    expect(
      find.bySemanticsLabel(RegExp('今日の「聞く」.*今日完了.*もう一度練習')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('今日の「話す」.*今日の1件、利用できます')),
      findsOneWidget,
    );
  });

  testWidgets('中断runは「続きから」だけを開き、active mistakeのRepairにはしない', (tester) async {
    final store = MemorySessionStore();
    await _seedNodes(store, const [GamePathNodeKind.lesson]);
    final practiceId = GamePathProjection.nodeId(
      'motion',
      'fall',
      GamePathNodeKind.practice,
    );
    await store.beginLearningRun(
      LearningRun(
        runId: 'resume-practice-run',
        scope: LearningScope.personal,
        nodeId: practiceId,
        activityIndex: 0,
        challengeHearts: 5,
        contentVersion: 'catalog-v6',
        updatedAt: DateTime.now().toUtc(),
      ),
    );

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-tab-practice')));
    await tester.pumpAndSettle();
    final practiceScroll = find.descendant(
      of: find.byKey(const ValueKey('practice-hub-screen')),
      matching: find.byType(Scrollable),
    );
    final resume = find.byKey(const ValueKey('practice-mode-practice:resume'));
    final repair = find.byKey(const ValueKey('practice-mode-practice:repair'));
    await tester.scrollUntilVisible(resume, 180, scrollable: practiceScroll);
    final resumeOnTap = tester
        .widget<InkWell>(
          find.descendant(of: resume, matching: find.byType(InkWell)),
        )
        .onTap;
    expect(resumeOnTap, isNotNull);
    await tester.scrollUntilVisible(repair, 180, scrollable: practiceScroll);
    expect(
      tester
          .widget<InkWell>(
            find.descendant(of: repair, matching: find.byType(InkWell)),
          )
          .onTap,
      isNull,
    );
    expect(
      (await store.learningProgressSnapshot(
        LearningScope.personal,
      )).activeNeeds,
      isEmpty,
    );

    resumeOnTap!();
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('science-diagram-scroll')),
      findsOneWidget,
    );
    expect(
      (await store.learningProgressSnapshot(
        LearningScope.personal,
      )).runs.singleWhere((run) => run.nodeId == practiceId).runId,
      'resume-practice-run',
      reason: '別runを作らず保存済みの中断位置を再開する',
    );
  });

  testWidgets('通常Storyのdemonstrated feedbackでは既存active needを解消しない', (
    tester,
  ) async {
    final store = MemorySessionStore();
    await _seedNodes(store, const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
    ]);
    await _seedActiveNeed(
      store,
      seedId: 'story-foundation',
      needCode: 'science.fall.foundation',
    );
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await _completeAvailableStory(tester);

    final snapshot = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(snapshot.activeNeeds, hasLength(1));
    expect(snapshot.activeNeeds.single.needCode, 'science.fall.foundation');
  });

  testWidgets('通常Listeningの正解では同じListening active needを解消しない', (tester) async {
    const narrationChannel = MethodChannel(
      'jp.dekisugi.dekisugi/local_narration',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(narrationChannel, (call) async => true);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(narrationChannel, null),
    );
    final store = MemorySessionStore();
    await _seedNodes(store, const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
      GamePathNodeKind.story,
    ]);
    await _seedActiveNeed(
      store,
      seedId: 'normal-listening-meaning',
      needCode: 'science.fall.listening.conditions.meaning',
    );
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-tab-practice')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('daily-audio-listening')));
    await tester.pumpAndSettle();

    await _completeListeningRoute(
      tester,
      transcript: _checkpointFor(LocalPracticeStage.conditions).lure,
    );
    await _acceptCompletionCelebration(tester);

    final snapshot = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(snapshot.activeNeeds, hasLength(1));
    expect(
      snapshot.activeNeeds.single.needCode,
      'science.fall.listening.conditions.meaning',
    );
  });

  testWidgets('Listening exact Repairは同時demonstratedのうちplanner targetだけを解消する', (
    tester,
  ) async {
    const narrationChannel = MethodChannel(
      'jp.dekisugi.dekisugi/local_narration',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(narrationChannel, (call) async => true);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(narrationChannel, null),
    );
    final store = MemorySessionStore();
    await _seedNodes(store, const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
      GamePathNodeKind.story,
    ]);
    await _seedActiveNeed(
      store,
      seedId: 'listening-transcript',
      needCode: 'science.fall.listening.conditions.transcript',
    );
    await _seedActiveNeed(
      store,
      seedId: 'listening-meaning',
      needCode: 'science.fall.listening.conditions.meaning',
    );
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await _openFirstRepair(tester);
    await _completeListeningRoute(
      tester,
      transcript: _checkpointFor(LocalPracticeStage.conditions).lure,
    );
    await _acceptCompletionCelebration(tester);

    final snapshot = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(snapshot.activeNeeds, hasLength(1));
    expect(
      snapshot.activeNeeds.single.needCode,
      'science.fall.listening.conditions.transcript',
      reason: 'meaning target成功で同時demonstratedのtranscriptまで消してはいけない',
    );
  });

  testWidgets('Listening transcript Repairの語省略は完了演出後もtarget needを残す', (
    tester,
  ) async {
    const narrationChannel = MethodChannel(
      'jp.dekisugi.dekisugi/local_narration',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(narrationChannel, (call) async => true);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(narrationChannel, null),
    );
    final store = MemorySessionStore();
    await _seedNodes(store, const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
      GamePathNodeKind.story,
    ]);
    await _seedActiveNeed(
      store,
      seedId: 'listening-transcript-omission',
      needCode: 'science.fall.listening.conditions.transcript',
    );
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await _openFirstRepair(tester);
    await _completeListeningRoute(tester, transcript: '重い物体だけ');
    await _acceptCompletionCelebration(tester);

    final snapshot = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(snapshot.activeNeeds, hasLength(1));
    expect(
      snapshot.activeNeeds.single.needCode,
      'science.fall.listening.conditions.transcript',
    );
  });

  testWidgets('TTS unavailableの文字教材完了はevent・XP・streakを作らない', (tester) async {
    const narrationChannel = MethodChannel(
      'jp.dekisugi.dekisugi/local_narration',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(narrationChannel, (call) async => false);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(narrationChannel, null),
    );
    final store = MemorySessionStore();
    await _seedNodes(store, const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
      GamePathNodeKind.story,
    ]);
    final before = await store.learningProgressSnapshot(LearningScope.personal);
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-tab-practice')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('daily-audio-listening')));
    await tester.pumpAndSettle();

    await _completeListeningRoute(tester, transcript: '', textOnly: true);
    expect(
      find.byKey(const ValueKey('game-completion-celebration')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const ValueKey('listening-text-only-return-to-path')),
    );
    await tester.pumpAndSettle();

    final after = await store.learningProgressSnapshot(LearningScope.personal);
    expect(after.events.length, before.events.length);
    expect(after.rewards.length, before.rewards.length);
    expect(after.days.length, before.days.length);
    expect(after.activeNeeds, before.activeNeeds);
  });

  testWidgets('Matchの同一route再送は冪等で、同日Repair後の再誤答はneedを再活性化する', (tester) async {
    final store = _ReplayOptionalNeedStore();
    await _seedNodes(store, const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
      GamePathNodeKind.story,
      GamePathNodeKind.listening,
      GamePathNodeKind.speaking,
    ]);
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await _openOptionalPracticeMode(tester, 'match');
    await _tapMiniGameControl(
      tester,
      scrollKey: 'science-match-scroll',
      controlKey: 'match-start',
    );
    await _tapMiniGameControl(
      tester,
      scrollKey: 'science-match-scroll',
      controlKey: 'match-target-reason',
    );
    await _tapMiniGameControl(
      tester,
      scrollKey: 'science-match-scroll',
      controlKey: 'match-submit',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    final observed = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(observed.activeNeeds, hasLength(1));
    expect(observed.activeNeeds.single.skillId, 'motion/fall');
    expect(observed.activeNeeds.single.needCode, 'science.fall.transfer');
    final needEvents = observed.events
        .where((event) => event.nodeId == 'optional:v1:motion:fall:match:need')
        .toList();
    expect(needEvents, hasLength(1));
    expect(needEvents.single.eventId, startsWith('need:v2:'));
    expect(needEvents.single.activityId, 'practice.match.need.v1');
    expect(needEvents.single.outcome, LearningAttemptOutcome.retryNeeded);
    expect(
      '${needEvents.single.eventId}|${needEvents.single.nodeId}|'
      '${needEvents.single.activityId}',
      isNot(contains('reason')),
      reason: '選んだMatch target IDをイベント識別子へ保存しない',
    );
    expect(observed.runs, isEmpty, reason: '任意Matchのrun位置は帰還時に破棄する');
    expect(store.optionalNeedCommits, [
      (eventId: needEvents.single.eventId, inserted: true),
      (eventId: needEvents.single.eventId, inserted: false),
    ], reason: '同一routeの完全同一command再送は1 eventに収束する');

    final repair = find.byKey(const ValueKey('practice-mode-practice:repair'));
    await tester.scrollUntilVisible(
      repair,
      180,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('practice-hub-screen')),
        matching: find.byType(Scrollable),
      ),
    );
    tester
        .widget<InkWell>(
          find.descendant(of: repair, matching: find.byType(InkWell)),
        )
        .onTap!();
    await tester.pumpAndSettle();
    expect(find.textContaining('transfer'), findsOneWidget);
    await _finishDiagram(tester, fixedTaskCorrect: true);

    final resolved = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(resolved.activeNeeds, isEmpty);
    expect(
      resolved.events.where(
        (event) =>
            event.outcome == LearningAttemptOutcome.structuredSuccess &&
            event.activityKind == LearningActivityKind.diagram,
      ),
      isNotEmpty,
    );

    await _openOptionalPracticeMode(tester, 'match');
    await _tapMiniGameControl(
      tester,
      scrollKey: 'science-match-scroll',
      controlKey: 'match-start',
    );
    await _tapMiniGameControl(
      tester,
      scrollKey: 'science-match-scroll',
      controlKey: 'match-target-reason',
    );
    await _tapMiniGameControl(
      tester,
      scrollKey: 'science-match-scroll',
      controlKey: 'match-submit',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    final reobserved = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(reobserved.activeNeeds, hasLength(1));
    expect(reobserved.activeNeeds.single.skillId, 'motion/fall');
    expect(reobserved.activeNeeds.single.needCode, 'science.fall.transfer');
    final reobservedEvents = reobserved.events
        .where((event) => event.activityId == 'practice.match.need.v1')
        .toList();
    expect(reobservedEvents, hasLength(2));
    expect(
      reobservedEvents.map((event) => event.learningDay).toSet(),
      hasLength(1),
      reason: 'Repair前後の再観測は同じ午前4時境界の学習日内である',
    );
    expect(
      reobservedEvents.map((event) => event.eventId).toSet(),
      hasLength(2),
      reason: '再入場は新しいrun markerで別の観測になる',
    );
    expect(store.optionalNeedCommits.map((commit) => commit.inserted), [
      true,
      false,
      true,
      false,
    ]);
    expect(
      store.optionalNeedCommits.map((commit) => commit.eventId).toSet(),
      hasLength(2),
    );
  });

  testWidgets('OS終了で残った任意Match runは再入場時に置換しRepair後のneedを復活させる', (tester) async {
    final store = MemorySessionStore();
    await _seedNodes(store, const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
      GamePathNodeKind.story,
      GamePathNodeKind.listening,
      GamePathNodeKind.speaking,
    ]);
    final challengeId = GamePathProjection.nodeId(
      'motion',
      'fall',
      GamePathNodeKind.challenge,
    );
    const orphanRunId = 'run.optional.match.orphan';
    final orphanNodeId = 'optional-heart:v1:match:$challengeId';
    final observedAt = DateTime.now().subtract(const Duration(minutes: 2));
    final learningDay = dayKeyOf(observedAt);
    await store.beginLearningRun(
      LearningRun(
        runId: orphanRunId,
        scope: LearningScope.personal,
        nodeId: orphanNodeId,
        activityIndex: 0,
        challengeHearts: 5,
        contentVersion: 'catalog-v6',
        updatedAt: observedAt.toUtc(),
      ),
    );
    final orphanNeedId = 'need:v2:$orphanRunId:0:$learningDay:match:f506ba06';
    await store.commitLearningEvent(
      LearningEventCommand(
        eventId: orphanNeedId,
        scope: LearningScope.personal,
        origin: LearningOrigin.practice,
        courseId: 'science-ja-v1',
        nodeId: 'optional:v1:motion:fall:match:need',
        activityId: 'practice.match.need.v1',
        skillIds: const {'motion/fall'},
        activityKind: LearningActivityKind.timed,
        outcome: LearningAttemptOutcome.retryNeeded,
        evidence: LearningEvidenceLevel.participation,
        contentVersion: 'catalog-v6',
        learningDay: learningDay,
        occurredAt: observedAt.toUtc(),
        practiceNeedCodes: const {
          'motion/fall': {'science.fall.transfer'},
        },
      ),
    );

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    await _openFirstRepair(tester);
    expect(find.textContaining('transfer'), findsOneWidget);
    await _finishDiagram(tester, fixedTaskCorrect: true);

    final repaired = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(repaired.activeNeeds, isEmpty);
    expect(
      repaired.runs.singleWhere((run) => run.nodeId == orphanNodeId).runId,
      orphanRunId,
      reason: 'OS終了では任意routeのpop後cleanupが走らずrunだけが残る',
    );
    final repairEvent = repaired.events.lastWhere(
      (event) =>
          event.outcome == LearningAttemptOutcome.structuredSuccess &&
          event.activityKind == LearningActivityKind.diagram,
    );

    await _openOptionalPracticeMode(tester, 'match');
    final reopened = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    final replacement = reopened.runs.singleWhere(
      (run) => run.nodeId == orphanNodeId,
    );
    expect(replacement.runId, isNot(orphanRunId));
    expect(reopened.runs.where((run) => run.runId == orphanRunId), isEmpty);

    await _tapMiniGameControl(
      tester,
      scrollKey: 'science-match-scroll',
      controlKey: 'match-start',
    );
    await _tapMiniGameControl(
      tester,
      scrollKey: 'science-match-scroll',
      controlKey: 'match-target-reason',
    );
    await _tapMiniGameControl(
      tester,
      scrollKey: 'science-match-scroll',
      controlKey: 'match-submit',
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    final reobserved = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(reobserved.runs, isEmpty);
    expect(reobserved.activeNeeds, hasLength(1));
    expect(reobserved.activeNeeds.single.needCode, 'science.fall.transfer');
    final optionalEvents = reobserved.events
        .where((event) => event.activityId == 'practice.match.need.v1')
        .toList();
    expect(optionalEvents, hasLength(2));
    final replacementEvent = optionalEvents.singleWhere(
      (event) => event.eventId.contains(replacement.runId),
    );
    expect(replacementEvent.eventId, isNot(orphanNeedId));
    expect(
      replacementEvent.occurredAt.isAfter(repairEvent.occurredAt),
      isTrue,
      reason: '新runの観測時刻を使い、Repairより古い観測として捨てない',
    );
  });

  testWidgets('固定課題の誤りを一般化needだけで残し、対応するRepair成功で解消する', (tester) async {
    final store = MemorySessionStore();
    await _seedNodes(store, const [GamePathNodeKind.lesson]);
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    final practiceId = GamePathProjection.nodeId(
      'motion',
      'fall',
      GamePathNodeKind.practice,
    );
    final practiceNode = find.byKey(
      ValueKey<String>('game-path-node-$practiceId'),
    );
    final pathScroll = find.descendant(
      of: find.byKey(const PageStorageKey<String>('game-learning-path')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(practiceNode, 220, scrollable: pathScroll);
    await tester.tap(practiceNode);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-node-sheet-start')));
    await tester.pumpAndSettle();
    await _finishDiagram(tester, fixedTaskCorrect: false);

    final observed = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(observed.activeNeeds, hasLength(1));
    expect(observed.activeNeeds.single.skillId, 'motion/fall');
    expect(observed.activeNeeds.single.needCode, 'science.fall.conditions');
    expect(observed.challengeHearts?.current, 4);

    await tester.tap(find.byKey(const ValueKey('game-tab-practice')));
    await tester.pumpAndSettle();
    final repair = find.byKey(const ValueKey('practice-mode-practice:repair'));
    await tester.scrollUntilVisible(
      repair,
      180,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('practice-hub-screen')),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('思い込みを直す'), findsOneWidget);
    tester
        .widget<InkWell>(
          find.descendant(of: repair, matching: find.byType(InkWell)),
        )
        .onTap!();
    await tester.pumpAndSettle();
    expect(find.textContaining('conditions'), findsOneWidget);
    await _finishDiagram(tester, fixedTaskCorrect: true);

    final resolved = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(resolved.activeNeeds, isEmpty);
    expect(
      resolved.events.where(
        (event) =>
            event.outcome == LearningAttemptOutcome.structuredSuccess &&
            event.activityKind == LearningActivityKind.diagram,
      ),
      isNotEmpty,
    );
  });

  testWidgets('graph needはRepairから該当Notation 1問だけを開いて解消する', (tester) async {
    final store = MemorySessionStore();
    await _seedNodes(store, const [GamePathNodeKind.lesson]);
    final now = DateTime.now();
    await store.commitLearningEvent(
      LearningEventCommand(
        eventId: 'seed-graph-need',
        scope: LearningScope.personal,
        origin: LearningOrigin.lab,
        courseId: 'science-ja-v1',
        nodeId: GamePathProjection.nodeId(
          'motion',
          'fall',
          GamePathNodeKind.practice,
        ),
        activityId: 'seed.graph.retry',
        skillIds: const {'motion/fall'},
        activityKind: LearningActivityKind.equation,
        outcome: LearningAttemptOutcome.retryNeeded,
        evidence: LearningEvidenceLevel.participation,
        contentVersion: 'catalog-v6',
        learningDay: dayKeyOf(now),
        occurredAt: now.toUtc(),
        practiceNeedCodes: const {
          'motion/fall': {'science.fall.notation.graph'},
        },
      ),
    );

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-tab-practice')));
    await tester.pumpAndSettle();
    final repair = find.byKey(const ValueKey('practice-mode-practice:repair'));
    await tester.scrollUntilVisible(
      repair,
      180,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('practice-hub-screen')),
        matching: find.byType(Scrollable),
      ),
    );
    tester
        .widget<InkWell>(
          find.descendant(of: repair, matching: find.byType(InkWell)),
        )
        .onTap!();
    await tester.pumpAndSettle();

    expect(find.text('速度―時間グラフの傾きが表す量を選ぶ。'), findsOneWidget);
    expect(find.text('力の矢印を意味の順に並べる。'), findsNothing);
    expect(find.textContaining('STEP 1 / 1'), findsOneWidget);
    final notationScroll = find
        .descendant(
          of: find.byKey(const ValueKey('science-notation-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    final correct = find.byKey(const ValueKey('notation-graph-acceleration'));
    await tester.scrollUntilVisible(correct, 160, scrollable: notationScroll);
    await tester.tap(correct);
    await tester.pump();
    final submit = find.byKey(const ValueKey('notation-submit'));
    await tester.scrollUntilVisible(submit, 160, scrollable: notationScroll);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    final complete = find.byKey(const ValueKey('notation-complete'));
    await tester.ensureVisible(complete);
    await tester.tap(complete);
    await _acceptCompletionCelebration(tester);

    final snapshot = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(snapshot.activeNeeds, isEmpty);
    expect(
      snapshot.events.last.outcome,
      LearningAttemptOutcome.structuredSuccess,
    );
  });

  testWidgets('Notationの誤答直後にsystem backしてもheartとcanonical needを両方保存する', (
    tester,
  ) async {
    final store = _CountingHeartStore();
    await _seedNodes(store, const [GamePathNodeKind.lesson]);
    final before = await store.learningProgressSnapshot(LearningScope.personal);
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('game-tab-notation')));
    await tester.pumpAndSettle();
    final entry = find.byKey(
      const ValueKey('notation-entry-notation:v1:motion:fall'),
    );
    await tester.scrollUntilVisible(
      entry,
      180,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('notation-lab-hub')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(entry);
    await tester.pumpAndSettle();

    final notationScroll = find
        .descendant(
          of: find.byKey(const ValueKey('science-notation-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    Future<void> notationTap(String key) async {
      final target = find.byKey(ValueKey(key));
      await tester.scrollUntilVisible(target, 160, scrollable: notationScroll);
      await tester.pump();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    await notationTap('notation-order-token-direction');
    await notationTap('notation-order-token-origin');
    await notationTap('notation-submit');
    expect(find.text('ここで一度、見直す'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    final after = await store.learningProgressSnapshot(LearningScope.personal);
    expect(after.wallet.xp, before.wallet.xp);
    expect(after.challengeHearts?.current, 4);
    expect(store.appliedHeartLosses, 1);
    expect(after.activeNeeds, hasLength(1));
    expect(after.activeNeeds.single.skillId, 'motion/fall');
    expect(after.activeNeeds.single.needCode, 'science.fall.notation.arrow');
    final needEvents = after.events
        .where((event) => event.activityId == 'notation.need.v1')
        .toList();
    expect(needEvents, hasLength(1));
    expect(needEvents.single.outcome, LearningAttemptOutcome.retryNeeded);
    expect(
      after.events.where((event) => event.activityId == 'notation.v1'),
      isEmpty,
      reason: '訂正前なのでNotation完了やXPを作らない',
    );
    final persistedFixedFields = <String>[
      for (final event in needEvents) ...[
        event.eventId,
        event.nodeId,
        event.activityId,
      ],
      for (final need in after.activeNeeds) ...[need.skillId, need.needCode],
    ].join('|');
    expect(persistedFixedFields, isNot(contains('direction')));
    expect(persistedFixedFields, isNot(contains('origin')));
    expect(
      (await store.recentSessions()).expand((session) => session.transcript),
      isEmpty,
      reason: '並べた回答やchoice IDを旧逐語sessionへ残さない',
    );
  });

  testWidgets('残り1heartのNotationは誤答保存後に同じ固定課題の組み直しを止める', (tester) async {
    final store = _CountingHeartStore();
    await _seedNodes(store, const [GamePathNodeKind.lesson]);
    await _depletePersonalHearts(store, remaining: 1);
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('game-tab-notation')));
    await tester.pumpAndSettle();
    final entry = find.byKey(
      const ValueKey('notation-entry-notation:v1:motion:fall'),
    );
    await tester.scrollUntilVisible(
      entry,
      180,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('notation-lab-hub')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(entry);
    await tester.pumpAndSettle();

    final notationScroll = find
        .descendant(
          of: find.byKey(const ValueKey('science-notation-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    Future<void> notationTap(String key) async {
      final target = find.byKey(ValueKey(key));
      await tester.scrollUntilVisible(target, 160, scrollable: notationScroll);
      await tester.pump();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    await notationTap('notation-order-token-direction');
    await notationTap('notation-order-token-origin');
    await notationTap('notation-submit');
    await tester.enterText(
      find.byKey(const ValueKey('notation-review')),
      '作用点から順に見直します',
    );
    await tester.pump();
    await notationTap('notation-retry');

    expect(find.text('ここで一度、見直す'), findsOneWidget);
    expect(find.textContaining('ハートがありません'), findsOneWidget);
    final snapshot = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    final run = snapshot.runs.singleWhere(
      (item) => item.nodeId == 'notation:v1:motion:fall',
    );
    expect(snapshot.challengeHearts?.current, 0);
    expect(run.activityIndex, 1);
    expect(run.challengeHearts, 0);
    expect(store.appliedHeartLosses, 1);
    expect(store.lossIds.toSet(), hasLength(1));
  });

  testWidgets('今日のクエストは最初の学習前から実報酬を表示する', (tester) async {
    final store = MemorySessionStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('クエスト。進行中3件'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('game-quest-button')));
    await tester.pumpAndSettle();
    final dailyQuest = find.bySemanticsLabel(RegExp('デイリークエスト、予想してから教材と比べる。'));
    expect(dailyQuest, findsOneWidget);
    expect(
      find.descendant(of: dailyQuest, matching: find.text('0/1')),
      findsOneWidget,
    );
    expect(find.text('結晶1個'), findsOneWidget);
    expect(find.text('今月の観測バッジを完成させる'), findsOneWidget);
    expect(find.textContaining('意味のある学習を12件積み重ねます'), findsOneWidget);
    expect(find.text('0/12'), findsOneWidget);
    expect(find.text('結晶8個'), findsOneWidget);
  });

  testWidgets('materializeしたdailyは同日中に候補が変わっても再起動後まで0件の同じ内容を保つ', (
    tester,
  ) async {
    final store = MemorySessionStore();
    final now = DateTime(2026, 8, 11, 12);
    final day = dayKeyOf(now);

    await tester.pumpWidget(_app(store, now: () => now));
    await tester.pumpAndSettle();
    var snapshot = await store.learningProgressSnapshot(LearningScope.personal);
    final initialDaily = snapshot.quests.singleWhere(
      (quest) => quest.questInstanceId.startsWith('daily:$day:'),
    );
    expect(initialDaily.questInstanceId, 'daily:$day:compare-prediction');
    expect(initialDaily.progress, 0);
    expect(initialDaily.rewardedAt, isNull);
    expect(
      snapshot.quests
          .singleWhere(
            (quest) => quest.questInstanceId.startsWith('monthly:2026-08:'),
          )
          .progress,
      0,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await _seedNodes(store, const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
    ], at: now.subtract(const Duration(minutes: 10)));
    snapshot = await store.learningProgressSnapshot(LearningScope.personal);
    expect(
      snapshot.quests
          .singleWhere(
            (quest) => quest.questInstanceId == initialDaily.questInstanceId,
          )
          .progress,
      0,
      reason: '候補だけを変えたseed commitはHomeの同plan rulesを通っていない',
    );

    await tester.pumpWidget(_app(store, now: () => now));
    await tester.pumpAndSettle();
    snapshot = await store.learningProgressSnapshot(LearningScope.personal);
    final sameDayRows = snapshot.quests
        .where((quest) => quest.questInstanceId.startsWith('daily:$day:'))
        .toList();
    expect(sameDayRows, hasLength(1));
    expect(sameDayRows.single.questInstanceId, initialDaily.questInstanceId);
    expect(sameDayRows.single.progress, 0);

    await tester.tap(find.byKey(const ValueKey('game-quest-button')));
    await tester.pumpAndSettle();
    final daily = find.bySemanticsLabel(RegExp('デイリークエスト、予想してから教材と比べる。'));
    expect(daily, findsOneWidget);
    expect(
      find.descendant(of: daily, matching: find.text('予想の一歩を始める')),
      findsOneWidget,
    );
  });

  final dailyCtaCases =
      <
        ({
          String key,
          String title,
          String action,
          List<GamePathNodeKind> clearedBeforeHome,
          Duration seedAge,
          String destinationKey,
        })
      >[
        (
          key: 'compare-prediction',
          title: '予想してから教材と比べる',
          action: '予想の一歩を始める',
          clearedBeforeHome: const [],
          seedAge: Duration.zero,
          destinationKey: 'science-lesson-scroll',
        ),
        (
          key: 'story-case',
          title: '事件簿を1話解明する',
          action: '今日の事件簿を開く',
          clearedBeforeHome: const [
            GamePathNodeKind.lesson,
            GamePathNodeKind.practice,
          ],
          seedAge: Duration.zero,
          destinationKey: 'science-story-scroll',
        ),
        (
          key: 'listen-for-conditions',
          title: '説明を聞いて条件を見抜く',
          action: '聞くミッションを始める',
          clearedBeforeHome: const [
            GamePathNodeKind.lesson,
            GamePathNodeKind.practice,
            GamePathNodeKind.story,
          ],
          seedAge: Duration.zero,
          destinationKey: 'science-listening-scroll',
        ),
        (
          key: 'explain-it-back',
          title: '理科の説明を自分で伝える',
          action: '話すミッションを始める',
          clearedBeforeHome: const [
            GamePathNodeKind.lesson,
            GamePathNodeKind.practice,
            GamePathNodeKind.story,
            GamePathNodeKind.listening,
          ],
          seedAge: Duration.zero,
          destinationKey: 'science-speak-listen-scroll',
        ),
        (
          key: 'diagram-relations',
          title: '図と条件を1つ組み立てる',
          action: '図の課題を始める',
          clearedBeforeHome: const [GamePathNodeKind.lesson],
          seedAge: Duration.zero,
          destinationKey: 'science-diagram-screen',
        ),
        (
          key: 'notation-trace',
          title: '式・単位・矢印を意味の順になぞる',
          action: '記号ラボを開く',
          clearedBeforeHome: const [GamePathNodeKind.lesson],
          seedAge: Duration.zero,
          destinationKey: 'science-notation-lab-screen',
        ),
        (
          key: 'transfer-challenge',
          title: '別の場面へ原理を1回使う',
          action: 'チャレンジへ進む',
          clearedBeforeHome: const [
            GamePathNodeKind.lesson,
            GamePathNodeKind.practice,
            GamePathNodeKind.story,
            GamePathNodeKind.listening,
            GamePathNodeKind.speaking,
          ],
          seedAge: Duration.zero,
          destinationKey: 'offline-practice-screen',
        ),
        (
          key: 'spaced-review',
          title: '期限の来た内容を思い出す',
          action: '今日の復習を始める',
          clearedBeforeHome: const [GamePathNodeKind.lesson],
          seedAge: const Duration(days: 2),
          destinationKey: 'science-legendary-scroll',
        ),
      ];
  for (final cta in dailyCtaCases) {
    testWidgets('daily固有CTA ${cta.key} は対応する実activityを直接開く', (tester) async {
      final store = MemorySessionStore();
      final now = DateTime(2026, 8, 20, 12);
      final day = dayKeyOf(now);
      await _materializeDailyV2(store, learningDay: day, questKey: cta.key);
      if (cta.clearedBeforeHome.isNotEmpty) {
        await _seedNodes(
          store,
          cta.clearedBeforeHome,
          at: now.subtract(cta.seedAge),
        );
      }

      await tester.pumpWidget(_app(store, now: () => now));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('game-quest-button')));
      await tester.pumpAndSettle();
      final quest = find.bySemanticsLabel(
        RegExp('デイリークエスト、${RegExp.escape(cta.title)}。'),
      );
      expect(quest, findsOneWidget);
      final action = find.descendant(
        of: quest,
        matching: find.text(cta.action),
      );
      expect(action, findsOneWidget);
      await tester.tap(action);
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey<String>(cta.destinationKey)), findsOneWidget);
      _expectSingleActivityChrome(tester);
    });
  }

  testWidgets('意味ある候補0でもdailyを捏造せず復習日待ちを示してPathをblankにしない', (tester) async {
    final store = MemorySessionStore();
    final now = DateTime(2026, 8, 20, 12);
    await _seedNodes(store, GamePathNodeKind.values, at: now);
    await _seedNotationNode(store, at: now.add(const Duration(minutes: 1)));

    await tester.pumpWidget(_app(store, now: () => now));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const PageStorageKey<String>('game-learning-path')),
      findsOneWidget,
    );
    expect(find.text('学習パスを準備できませんでした。'), findsNothing);
    final snapshot = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(
      snapshot.quests.where(
        (quest) => quest.questInstanceId.startsWith('daily:${dayKeyOf(now)}:'),
      ),
      isEmpty,
    );
    expect(
      snapshot.quests.where(
        (quest) => quest.questInstanceId.startsWith('monthly:2026-08:'),
      ),
      hasLength(1),
    );

    await tester.tap(find.byKey(const ValueKey('game-quest-button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('次の復習日を待ちます'), findsOneWidget);
    await tester.tap(find.text('今月の記録を見る'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game-profile-screen')), findsOneWidget);
  });

  testWidgets('Quest materialize失敗はrulesとboardだけを閉じPathをblankにしない', (
    tester,
  ) async {
    final store = _FailQuestMaterializationStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const PageStorageKey<String>('game-learning-path')),
      findsOneWidget,
    );
    expect(find.text('学習パスを準備できませんでした。'), findsNothing);
    expect(
      (await store.learningProgressSnapshot(LearningScope.personal)).quests,
      isEmpty,
    );
    await tester.tap(find.byKey(const ValueKey('game-quest-button')));
    await tester.pumpAndSettle();
    expect(find.text('クエストを読み込めませんでした。学習パスはそのまま使えます。'), findsOneWidget);
    expect(find.byKey(const ValueKey('game-quest-retry')), findsOneWidget);
  });

  testWidgets('LAN Friendsの実snapshot 1/2を共通boardへ出し固有CTAでLAN画面を開く', (
    tester,
  ) async {
    final store = MemorySessionStore();
    final now = DateTime(2026, 8, 20, 12);
    await tester.pumpWidget(
      _app(
        store,
        now: () => now,
        lanSocialAllowed: true,
        lanSocialFriendsQuestLoader: () async => LanSocialFriendsQuestState(
          roomId: 'abcdef012345abcdef012345',
          snapshot: LanSocialFriendsSnapshot(
            state: LanSocialFriendsState.active,
            partnerJoined: true,
            myContributed: true,
            completed: false,
            expiresAt: now.add(const Duration(hours: 2)).toUtc(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-quest-button')));
    await tester.pumpAndSettle();
    final friends = find.bySemanticsLabel(
      RegExp('フレンズクエスト、ふたりクエスト。.*2回中1回。進行中'),
    );
    expect(friends, findsOneWidget);
    final action = find.descendant(
      of: friends,
      matching: find.text('ふたりの進捗を開く'),
    );
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('lan-social-screen')), findsOneWidget);
  });

  testWidgets('月間クエスト達成は購入品でない固定バッジをProfileへ一度だけ表示する', (tester) async {
    final store = MemorySessionStore();
    await _seedMonthlyBadge(store);
    final before = await store.learningProgressSnapshot(LearningScope.personal);
    final monthly = before.quests.singleWhere(
      (quest) => quest.questInstanceId.startsWith('monthly:'),
    );
    expect(monthly.progress, LearningMonthlyBadgeCatalogV1.target);
    expect(monthly.rewardedAt, isNotNull);
    expect(before.wallet.gems, 8);
    expect(before.gemSpends, isEmpty);

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-tab-profile')));
    await tester.pumpAndSettle();
    final badgeId =
        'badge.monthly.${monthly.questInstanceId.split(':')[1]}'
        '.${LearningMonthlyBadgeCatalogV1.questKey}';
    final badge = find.byKey(ValueKey('monthly-badge-$badgeId'));
    await tester.scrollUntilVisible(
      badge,
      220,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('game-profile-screen')),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    expect(badge, findsOneWidget);
    expect(find.textContaining('結晶では購入できません'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('観測バッジ。獲得済み')), findsOneWidget);
    final after = await store.learningProgressSnapshot(LearningScope.personal);
    expect(after.wallet.gems, 8);
    expect(after.gemSpends, isEmpty);
  });

  testWidgets('獲得した結晶で学習ハートを確認後に全回復する', (tester) async {
    final store = MemorySessionStore();
    final now = DateTime.now();
    final day = dayKeyOf(now);
    final rewardAt = now.subtract(const Duration(days: 1));
    final rewardDay = dayKeyOf(rewardAt);
    await store.commitLearningEvent(
      LearningEventCommand(
        eventId: 'seed-economy-reward',
        scope: LearningScope.personal,
        origin: LearningOrigin.path,
        courseId: 'science-ja-v1',
        nodeId: 'seed:economy:reward',
        activityId: 'seed.economy',
        skillIds: const {'motion/fall'},
        activityKind: LearningActivityKind.read,
        outcome: LearningAttemptOutcome.completed,
        evidence: LearningEvidenceLevel.selfCompared,
        contentVersion: 'catalog-v5',
        learningDay: rewardDay,
        occurredAt: rewardAt.toUtc(),
      ),
      rules: LearningCommitRules(
        quests: [
          LearningQuestDefinition.daily(
            learningDay: rewardDay,
            questKey: 'economy-seed',
            definitionVersion: 'economy.test.v1',
            target: 1,
            rewardGems: 10,
          ),
        ],
      ),
    );
    await store.beginLearningRun(
      LearningRun(
        runId: 'run-economy-heart',
        scope: LearningScope.personal,
        nodeId: 'seed:legendary:run',
        activityIndex: 0,
        challengeHearts: 5,
        contentVersion: 'catalog-v5',
        updatedAt: now.toUtc(),
      ),
    );
    await store.spendLearningChallengeHeart(
      'run-economy-heart',
      lossId: 'run-economy-heart:loss:1',
      activityIndex: 1,
      learningDay: day,
      occurredAt: now.add(const Duration(seconds: 1)).toUtc(),
    );

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('学習ハート、5個中4個'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('player-status-gems')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game-economy-sheet')), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('economy-hearts-action')),
    );
    await tester.tap(find.byKey(const ValueKey('economy-hearts-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('economy-hearts-confirm')));
    await tester.pumpAndSettle();

    final snapshot = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(snapshot.wallet.gems, 8);
    expect(snapshot.challengeHearts?.current, 5);
    expect(
      snapshot.gemSpends.single.kind,
      LearningGemSpendKind.challengeHeartRecovery,
    );
    expect(find.byKey(const ValueKey('game-economy-sheet')), findsNothing);
  });

  testWidgets('結晶でPathマスコットだけを購入・装備し、学習進行を変えない', (tester) async {
    final store = MemorySessionStore();
    await _seedEconomyGems(store, seedId: 'cosmetic', amount: 10);
    final before = await store.learningProgressSnapshot(LearningScope.personal);

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('player-status-gems')));
    await tester.pumpAndSettle();

    final sheetScroll = find
        .descendant(
          of: find.byKey(const ValueKey('game-economy-sheet')),
          matching: find.byType(Scrollable),
        )
        .first;
    final orbitAction = find.byKey(
      const ValueKey('economy-cosmetic-cosmetic.path-mascot.orbit.v1-action'),
    );
    await tester.scrollUntilVisible(orbitAction, 220, scrollable: sheetScroll);
    await tester.tap(orbitAction);
    await tester.pumpAndSettle();
    expect(find.text('軌道リングを購入しますか？'), findsOneWidget);
    expect(
      find.text('結晶4個を使い、Pathの見た目だけを変更します。学習進行や正答は変わりません。'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(
        const ValueKey(
          'economy-cosmetic:cosmetic.path-mascot.orbit.v1-confirm',
        ),
      ),
    );
    await tester.pumpAndSettle();

    var after = await store.learningProgressSnapshot(LearningScope.personal);
    expect(after.wallet.gems, before.wallet.gems - 4);
    expect(after.wallet.xp, before.wallet.xp);
    expect(after.events, hasLength(before.events.length));
    expect(after.nodes, hasLength(before.nodes.length));
    expect(after.gemSpends, hasLength(1));
    expect(after.gemSpends.single.kind, LearningGemSpendKind.cosmeticPurchase);
    expect(
      after.cosmetics?.equippedPathMascotId,
      SafeLearningEconomyCatalogV1.orbitMascotId,
    );
    expect(
      after.cosmetics?.ownedProductIds,
      contains(SafeLearningEconomyCatalogV1.orbitMascotId),
    );
    expect(find.byKey(const ValueKey('path-mascot-orbit')), findsOneWidget);

    for (final tab in [
      'stories',
      'practice',
      'notation',
      'league',
      'profile',
    ]) {
      await tester.tap(find.byKey(ValueKey<String>('game-tab-$tab')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('path-mascot-orbit')),
        findsOneWidget,
        reason: '$tabでも装備中mascotを使う',
      );
      if (tab != 'profile') {
        expect(find.byKey(const ValueKey('game-hero-mascot')), findsOneWidget);
      }
      expect(
        find.byKey(const ValueKey('game-player-status-header')),
        findsOneWidget,
      );
    }
    await tester.tap(find.byKey(const ValueKey('game-tab-path')));
    await tester.pumpAndSettle();

    final lessonId = GamePathProjection.nodeId(
      'motion',
      'fall',
      GamePathNodeKind.lesson,
    );
    final lessonNode = find.byKey(ValueKey<String>('game-path-node-$lessonId'));
    await tester.scrollUntilVisible(
      lessonNode,
      220,
      scrollable: find.descendant(
        of: find.byKey(const PageStorageKey<String>('game-learning-path')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(lessonNode);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-node-sheet-start')));
    await tester.pumpAndSettle();
    _expectSingleActivityChrome(tester);
    expect(find.bySemanticsLabel('前の画面へ戻る'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('path-mascot-orbit')),
      findsOneWidget,
      reason: 'activityと完了画面にも6タブと同じ装備を引き継ぐ',
    );
    await _exitActivity(tester);

    await tester.tap(find.byKey(const ValueKey('player-status-gems')));
    await tester.pumpAndSettle();
    final defaultAction = find.byKey(
      const ValueKey(
        'economy-cosmetic-cosmetic.path-mascot.standard.v1-action',
      ),
    );
    await tester.scrollUntilVisible(
      defaultAction,
      220,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('game-economy-sheet')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(defaultAction);
    await tester.pumpAndSettle();

    after = await store.learningProgressSnapshot(LearningScope.personal);
    expect(after.wallet.gems, before.wallet.gems - 4);
    expect(after.gemSpends, hasLength(1));
    expect(
      after.cosmetics?.equippedPathMascotId,
      SafeLearningEconomyCatalogV1.standardMascotId,
    );
    expect(
      after.cosmetics?.ownedProductIds,
      contains(SafeLearningEconomyCatalogV1.orbitMascotId),
    );
    expect(find.byKey(const ValueKey('path-mascot-standard')), findsOneWidget);
  });

  testWidgets('端末内ペア第1roundを実2枠としてリーグへ橋渡しし、別eventの次roundも一意に数える', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final store = MemorySessionStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('game-quest-button')));
    await tester.pumpAndSettle();
    final inviteQuest = find.bySemanticsLabel(
      RegExp('フレンズクエスト、端末内ペアクエストを作る。.*2回中0回。進行中'),
    );
    expect(inviteQuest, findsOneWidget);
    await tester.tap(
      find.descendant(of: inviteQuest, matching: find.text('2人のクエストを準備する')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game-profile-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('local-coop-start')), findsNothing);
    expect(find.textContaining('1人目の学習を選択中'), findsOneWidget);
    expect(find.text('0 / 2  ・  ◆ 3'), findsOneWidget);

    Future<void> expectPairQuestInSheet(int progress, String state) async {
      await tester.tap(find.byKey(const ValueKey('game-quest-button')));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(
          RegExp(
            'フレンズクエスト、端末内ペアクエスト。'
            '.*2回中$progress回。$state',
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('game-quest-sheet-close')));
      await tester.pumpAndSettle();
    }

    await expectPairQuestInSheet(0, '進行中');

    var snapshot = await store.learningProgressSnapshot(LearningScope.personal);
    expect(snapshot.localCoopRuns, hasLength(1));
    final pairRun = snapshot.localCoopRuns.single;
    final participants = pairRun.participantIds.toList()..sort();
    expect(pairRun.definitionVersion, 'local-pair.v1');
    expect(pairRun.participantIds, hasLength(2));
    expect(
      pairRun.participantIds.every((id) => id.startsWith('${pairRun.runId}:')),
      isTrue,
      reason: '氏名ではなくrun内だけの不透明な2枠を保存する',
    );

    await tester.tap(find.byKey(const ValueKey('game-tab-league')));
    await tester.pumpAndSettle();
    final leagueScroll = find
        .descendant(
          of: find.byKey(const ValueKey('league-screen')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('local-weekly-league-panel')),
      180,
      scrollable: leagueScroll,
    );
    expect(find.bySemanticsLabel(RegExp('端末手渡し週次リーグ。実在する2人')), findsOneWidget);
    expect(
      find.byKey(
        ValueKey<String>(
          'local-weekly-league-participant-${participants.first}',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        ValueKey<String>(
          'local-weekly-league-participant-${participants.last}',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('local-weekly-league-start')),
      findsNothing,
      reason: 'ペアrunと別のリーグrunを同時に開始しない',
    );
    final bridgedView = LocalWeeklyLeagueProjection.project(
      scope: LearningScope.personal,
      weekKey: pairRun.startDay,
      runs: snapshot.localCoopRuns,
    );
    expect(bridgedView.activeRunId, pairRun.runId);
    expect(
      bridgedView.standings.map((standing) => standing.participantId),
      containsAll(pairRun.participantIds),
    );

    await _completeAvailableLesson(tester);

    snapshot = await store.learningProgressSnapshot(LearningScope.personal);
    expect(snapshot.localCoopRuns, hasLength(1));
    var updatedPair = snapshot.localCoopRuns.single;
    expect(updatedPair.runId, pairRun.runId);
    expect(updatedPair.progress, 1);
    expect(updatedPair.contributingParticipantIds, hasLength(1));
    expect(updatedPair.completed, isFalse);
    await expectPairQuestInSheet(1, '進行中');
    expect(
      snapshot.wallet.gems,
      1,
      reason: 'daily questの実targetだけ。ペア報酬は2人そろうまで出さない',
    );

    final firstContribution = (await store.localCoopContributions({
      pairRun.runId,
    })).single;
    final secondParticipant = participants.singleWhere(
      (id) => id != firstContribution.participantId,
    );
    await tester.tap(find.byKey(const ValueKey('game-tab-league')));
    await tester.pumpAndSettle();
    final secondParticipantButton = find.byKey(
      ValueKey<String>('local-weekly-league-participant-$secondParticipant'),
    );
    await tester.scrollUntilVisible(
      secondParticipantButton,
      180,
      scrollable: leagueScroll,
    );
    await tester.tap(secondParticipantButton);
    await tester.pumpAndSettle();

    await _completeAvailableDiagram(tester);

    snapshot = await store.learningProgressSnapshot(LearningScope.personal);
    updatedPair = snapshot.localCoopRuns.single;
    final pairContributions = await store.localCoopContributions({
      pairRun.runId,
    });
    expect(updatedPair.progress, 2);
    expect(updatedPair.contributingParticipantIds, pairRun.participantIds);
    expect(updatedPair.completed, isTrue);
    expect(pairContributions, hasLength(2));
    expect(
      pairContributions.map((entry) => entry.participantId).toSet(),
      pairRun.participantIds,
    );
    expect(
      pairContributions.map((entry) => entry.eventId).toSet(),
      hasLength(2),
      reason: '2人は同じ完了を使い回さず、LessonとDiagramの別eventを使う',
    );
    final pairEvents = snapshot.events
        .where(
          (event) => pairContributions.any(
            (contribution) => contribution.eventId == event.eventId,
          ),
        )
        .toList();
    expect(pairEvents, hasLength(2));
    expect(
      pairEvents.map((event) => event.activityId).toSet(),
      {'path.lesson.v1', 'path.practice.v1'},
      reason: '自由回答ではなく固定activityだけを保存する',
    );
    expect(pairEvents.every((event) => event.meaningfulProgress), isTrue);

    await expectPairQuestInSheet(2, '達成済み');
    await tester.tap(find.byKey(const ValueKey('game-tab-profile')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('local-coop-quest-panel')),
      180,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('game-profile-screen')),
        matching: find.byType(Scrollable),
      ),
    );
    final completedPairPanel = find.byKey(
      const ValueKey('local-coop-quest-panel'),
    );
    expect(
      find.descendant(
        of: completedPairPanel,
        matching: find.text('2 / 2  ・  ◆ 3'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: completedPairPanel,
        matching: find.text('2人の学習がそろいました。報酬は端末内の個人walletへ一度だけ記録済みです。'),
      ),
      findsOneWidget,
      reason: 'Profileの恒常表示を一時的なSnackBarとは別に検証する',
    );

    await tester.tap(find.byKey(const ValueKey('game-tab-league')));
    await tester.pumpAndSettle();
    final nextRound = find.byKey(
      const ValueKey('local-weekly-league-next-round'),
    );
    await tester.scrollUntilVisible(nextRound, 180, scrollable: leagueScroll);
    final completedPairView = LocalWeeklyLeagueProjection.project(
      scope: LearningScope.personal,
      weekKey: pairRun.startDay,
      runs: snapshot.localCoopRuns,
      contributions: pairContributions,
    );
    expect(completedPairView.activeRunId, isNull);
    expect(completedPairView.totalMeaningfulEventCount, 2);
    expect(snapshot.localCoopRuns, hasLength(1));

    await tester.tap(nextRound);
    await tester.pumpAndSettle();

    snapshot = await store.learningProgressSnapshot(LearningScope.personal);
    expect(snapshot.localCoopRuns, hasLength(2));
    final leagueRun = snapshot.localCoopRuns.singleWhere(
      (run) => run.definitionVersion == 'local-weekly-league.v1',
    );
    expect(leagueRun.runId, isNot(pairRun.runId));
    expect(leagueRun.participantIds, pairRun.participantIds);
    expect(leagueRun.progress, 0);
    expect(leagueRun.completed, isFalse);
    final secondRoundView = LocalWeeklyLeagueProjection.project(
      scope: LearningScope.personal,
      weekKey: pairRun.startDay,
      runs: snapshot.localCoopRuns,
      contributions: pairContributions,
    );
    expect(secondRoundView.activeRunId, leagueRun.runId);

    // ペア完了と次round開始のSnackBarが順番に消え、Story下端の送信ボタンを
    // 覆わないところまで進める。
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await _completeAvailableStory(tester);

    final finalSnapshot = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    final finalLeagueRun = finalSnapshot.localCoopRuns.singleWhere(
      (run) => run.runId == leagueRun.runId,
    );
    final allContributions = await store.localCoopContributions({
      pairRun.runId,
      leagueRun.runId,
    });
    final leagueContributions = allContributions
        .where((entry) => entry.runId == leagueRun.runId)
        .toList();
    expect(finalLeagueRun.progress, 1);
    expect(finalLeagueRun.contributingParticipantIds, {participants.first});
    expect(leagueContributions, hasLength(1));
    expect(leagueContributions.single.participantId, participants.first);
    expect(
      finalSnapshot.events
          .singleWhere(
            (event) => event.eventId == leagueContributions.single.eventId,
          )
          .activityKind,
      LearningActivityKind.story,
      reason: '新roundにも実際に完了したStory eventだけを寄与させる',
    );
    expect(
      allContributions.map((entry) => entry.eventId).toSet(),
      hasLength(allContributions.length),
      reason: '同じeventを別participant・別roundへ二重計上しない',
    );
    final finalView = LocalWeeklyLeagueProjection.project(
      scope: LearningScope.personal,
      weekKey: pairRun.startDay,
      runs: finalSnapshot.localCoopRuns,
      contributions: allContributions,
    );
    expect(finalView.activeRunId, leagueRun.runId);
    expect(finalView.totalMeaningfulEventCount, 3);
    expect(
      finalView.standings
          .singleWhere(
            (standing) => standing.participantId == participants.first,
          )
          .meaningfulEventCount,
      2,
    );
    expect(
      finalView.standings
          .singleWhere(
            (standing) => standing.participantId == participants.last,
          )
          .meaningfulEventCount,
      1,
    );
  });

  testWidgets('端末手渡し週次リーグは明示した実在3人と意味ある完了だけで順位を作る', (tester) async {
    final store = MemorySessionStore();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('game-tab-league')));
    await tester.pumpAndSettle();
    final leagueScroll = find
        .descendant(
          of: find.byKey(const ValueKey('league-screen')),
          matching: find.byType(Scrollable),
        )
        .first;
    final setup = find.byKey(const ValueKey('local-weekly-league-setup-open'));
    await tester.scrollUntilVisible(setup, 180, scrollable: leagueScroll);
    await tester.tap(setup);
    await tester.pumpAndSettle();
    final plus = find.byKey(const ValueKey('local-weekly-league-count-plus'));
    await tester.tap(
      find.descendant(of: plus, matching: find.byType(IconButton)),
    );
    await tester.pump();
    final start = find.byKey(const ValueKey('local-weekly-league-start'));
    await tester.tap(start);
    await tester.pumpAndSettle();

    var snapshot = await store.learningProgressSnapshot(LearningScope.personal);
    final run = snapshot.localCoopRuns.single;
    expect(run.definitionVersion, 'local-weekly-league.v1');
    expect(run.participantIds, hasLength(3));
    expect(run.target, 3);
    expect(run.rewardGems, 0);
    expect(run.participantIds.every((id) => id.contains(':slot:')), isTrue);
    expect(find.textContaining('実在する3人'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('game-tab-profile')));
    await tester.pumpAndSettle();
    final profileScroll = find
        .descendant(
          of: find.byKey(const ValueKey('game-profile-screen')),
          matching: find.byType(Scrollable),
        )
        .first;
    final unavailable = find.byKey(
      const ValueKey('local-coop-unavailable-reason'),
    );
    await tester.scrollUntilVisible(
      unavailable,
      180,
      scrollable: profileScroll,
    );
    expect(find.textContaining('学習イベントを二重計上しないため'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('local-coop-start')))
          .onPressed,
      isNull,
    );

    await _completeAvailableLesson(tester);

    snapshot = await store.learningProgressSnapshot(LearningScope.personal);
    final updated = snapshot.localCoopRuns.single;
    final contributions = await store.localCoopContributions({updated.runId});
    expect(updated.progress, 1);
    expect(updated.contributingParticipantIds, hasLength(1));
    expect(contributions, hasLength(1));
    expect(contributions.single.meaningfulProgress, isTrue);
    expect(contributions.single.scope, LearningScope.personal);
    expect(
      snapshot.events.any(
        (event) => event.eventId == contributions.single.eventId,
      ),
      isTrue,
    );

    await tester.tap(find.byKey(const ValueKey('game-tab-league')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('local-weekly-league-panel')),
      180,
      scrollable: leagueScroll,
    );
    expect(
      find.bySemanticsLabel(RegExp('この端末の学習者、1位、意味のある学習1件')),
      findsOneWidget,
    );
    expect(find.textContaining('実在する仲間との週次順位だけ'), findsOneWidget);
  });

  testWidgets('2週休眠後の起動でも古い実順位から順に一度だけ確定し10段tierへ反映する', (tester) async {
    final store = MemorySessionStore();
    await _seedLocalLeagueWeek(
      store,
      weekKey: '2026-08-03',
      participantCount: 5,
    );
    await _seedLocalLeagueWeek(
      store,
      weekKey: '2026-08-10',
      participantCount: 5,
    );
    final now = DateTime(2026, 8, 17, 10);

    await tester.pumpWidget(_app(store, now: () => now));
    await tester.pumpAndSettle();

    var snapshot = await store.learningProgressSnapshot(LearningScope.personal);
    expect(snapshot.localLeagueHistory, hasLength(2));
    expect(snapshot.localLeagueHistory.map((week) => week.weekKey), [
      '2026-08-10',
      '2026-08-03',
    ]);
    expect(snapshot.localLeagueHistory.every((week) => week.rank == 1), isTrue);
    expect(snapshot.currentLocalLeagueTier.label, 'ゴールド');

    await tester.tap(find.byKey(const ValueKey('game-tab-league')));
    await tester.pumpAndSettle();
    expect(find.text('ゴールドリーグ'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(store, now: () => now));
    await tester.pumpAndSettle();
    snapshot = await store.learningProgressSnapshot(LearningScope.personal);
    expect(snapshot.localLeagueHistory, hasLength(2));
  });

  testWidgets('任意の前週League確定失敗でも学習Pathのsnapshotを表示する', (tester) async {
    final store = _FailLocalLeagueFinalizeStore();

    await tester.pumpWidget(_app(store, now: () => DateTime(2026, 8, 17, 10)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('game-tab-path')), findsOneWidget);
    expect(find.text('読み込めませんでした'), findsNothing);
    expect(find.text('次はここ'), findsOneWidget);
  });

  testWidgets('任意の時間制は回答なしheart runだけ作りevent・XPを進めず開く', (tester) async {
    final store = MemorySessionStore();
    await _seedNodes(store, const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
      GamePathNodeKind.story,
      GamePathNodeKind.listening,
      GamePathNodeKind.speaking,
    ]);
    await _seedEconomyGems(store, seedId: 'timed-entry', amount: 3);
    final before = await store.learningProgressSnapshot(LearningScope.personal);

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    await _openOptionalPracticeMode(tester, 'timed');
    expect(
      find.byKey(const ValueKey('timed-entry-confirmation')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('timed-entry-cancel')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('science-timed-challenge-screen')),
      findsNothing,
    );
    final cancelled = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(cancelled.wallet.gems, before.wallet.gems);
    expect(cancelled.gemSpends, isEmpty);

    await _openOptionalPracticeMode(tester, 'timed');
    await tester.tap(find.byKey(const ValueKey('timed-entry-confirm')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('science-timed-challenge-screen')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('game-activity-status')), findsOneWidget);
    _expectSingleActivityChrome(tester);

    var after = await store.learningProgressSnapshot(LearningScope.personal);
    expect(after.events.length, before.events.length);
    expect(after.runs, hasLength(1));
    expect(after.runs.single.challengeHearts, 5);
    expect(after.runs.single.nodeId, startsWith('optional-heart:v1:timed:'));
    expect(after.wallet.xp, before.wallet.xp);
    expect(after.wallet.gems, before.wallet.gems - 1);
    expect(after.gemSpends, hasLength(1));
    expect(after.gemSpends.single.kind, LearningGemSpendKind.challengeEntry);
    expect(
      after.gemSpends.single.referenceId,
      SafeLearningEconomyCatalogV1.timedDayPassId,
    );

    await _exitActivity(tester);
    expect(find.byKey(const ValueKey('practice-hub-screen')), findsOneWidget);
    await _openOptionalPracticeMode(tester, 'timed');
    expect(
      find.byKey(const ValueKey('timed-entry-confirmation')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('science-timed-challenge-screen')),
      findsOneWidget,
    );
    _expectSingleActivityChrome(tester);
    after = await store.learningProgressSnapshot(LearningScope.personal);
    expect(after.gemSpends, hasLength(1));
    expect(after.wallet.gems, before.wallet.gems - 1);
  });

  testWidgets('学校の時間制は結晶・確認なしで開く', (tester) async {
    final store = MemorySessionStore();
    await _seedNodes(store, const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
      GamePathNodeKind.story,
      GamePathNodeKind.listening,
      GamePathNodeKind.speaking,
    ], scope: LearningScope.schoolLocal);

    await tester.pumpWidget(_app(store, schoolMode: true));
    await tester.pumpAndSettle();
    await _openOptionalPracticeMode(tester, 'timed');

    expect(
      find.byKey(const ValueKey('timed-entry-confirmation')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('science-timed-challenge-screen')),
      findsOneWidget,
    );
    final snapshot = await store.learningProgressSnapshot(
      LearningScope.schoolLocal,
    );
    expect(snapshot.wallet.gems, 0);
    expect(snapshot.gemSpends, isEmpty);
    expect(snapshot.cosmetics, isNull);
  });

  for (final route in const [
    (mode: 'match', screenKey: 'science-match-lab-screen'),
    (mode: 'lightning', screenKey: 'science-lightning-screen'),
  ]) {
    testWidgets('任意の${route.mode}ミニゲームはPracticeから実画面へ到達する', (tester) async {
      final store = MemorySessionStore();
      await _seedNodes(store, const [
        GamePathNodeKind.lesson,
        GamePathNodeKind.practice,
        GamePathNodeKind.story,
        GamePathNodeKind.listening,
        GamePathNodeKind.speaking,
      ]);
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      await _openOptionalPracticeMode(tester, route.mode);
      expect(find.byKey(ValueKey(route.screenKey)), findsOneWidget);
      _expectSingleActivityChrome(tester);
    });
  }

  testWidgets('Matchのneed保存失敗時はheart commitを進めずheart-onlyを防ぐ', (tester) async {
    final store = _FailOptionalMatchNeedStore();
    await _seedNodes(store, const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
      GamePathNodeKind.story,
      GamePathNodeKind.listening,
      GamePathNodeKind.speaking,
    ]);
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await _openOptionalPracticeMode(tester, 'match');
    await _tapMiniGameControl(
      tester,
      scrollKey: 'science-match-scroll',
      controlKey: 'match-start',
    );
    await _tapMiniGameControl(
      tester,
      scrollKey: 'science-match-scroll',
      controlKey: 'match-target-reason',
    );
    await _tapMiniGameControl(
      tester,
      scrollKey: 'science-match-scroll',
      controlKey: 'match-submit',
    );
    await _tapMiniGameControl(
      tester,
      scrollKey: 'science-match-scroll',
      controlKey: 'match-retry',
    );

    final snapshot = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(store.failedNeedWrites, 1);
    expect(store.appliedHeartLosses, 0);
    expect(snapshot.challengeHearts?.current, 5);
    expect(snapshot.activeNeeds, isEmpty);
    expect(
      snapshot.events.where(
        (event) => event.activityId == 'practice.match.need.v1',
      ),
      isEmpty,
    );
    final run = snapshot.runs.singleWhere(
      (item) => item.nodeId.startsWith('optional-heart:v1:match:'),
    );
    expect(run.activityIndex, 0);
    expect(run.challengeHearts, 5);
    expect(find.byKey(const ValueKey('match-retry')), findsOneWidget);
  });

  for (final challenge in const [
    (
      mode: 'match',
      scrollKey: 'science-match-scroll',
      startKey: 'match-start',
      wrongKey: 'match-target-reason',
      submitKey: 'match-submit',
      retryKey: 'match-retry',
    ),
    (
      mode: 'lightning',
      scrollKey: 'science-lightning-scroll',
      startKey: 'lightning-start',
      wrongKey: 'lightning-option-heavy',
      submitKey: 'lightning-submit',
      retryKey: 'lightning-retry',
    ),
  ]) {
    testWidgets('個人${challenge.mode}は最後のheart消費を待って画面内retryを止める', (
      tester,
    ) async {
      final store = MemorySessionStore();
      await _seedNodes(store, const [
        GamePathNodeKind.lesson,
        GamePathNodeKind.practice,
        GamePathNodeKind.story,
        GamePathNodeKind.listening,
        GamePathNodeKind.speaking,
      ]);
      await _depletePersonalHearts(store, remaining: 1);
      await tester.pumpWidget(_app(store));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('学習ハート、5個中1個'), findsOneWidget);

      await _openOptionalPracticeMode(tester, challenge.mode);
      await _tapMiniGameControl(
        tester,
        scrollKey: challenge.scrollKey,
        controlKey: challenge.startKey,
      );
      await _tapMiniGameControl(
        tester,
        scrollKey: challenge.scrollKey,
        controlKey: challenge.wrongKey,
      );
      await _tapMiniGameControl(
        tester,
        scrollKey: challenge.scrollKey,
        controlKey: challenge.submitKey,
      );
      await _tapMiniGameControl(
        tester,
        scrollKey: challenge.scrollKey,
        controlKey: challenge.retryKey,
      );

      expect(find.byKey(ValueKey(challenge.startKey)), findsNothing);
      expect(find.byKey(ValueKey(challenge.retryKey)), findsOneWidget);
      expect(find.textContaining('ハートがありません'), findsOneWidget);
      expect(
        find.bySemanticsLabel('学習ハート、5個中0個'),
        findsOneWidget,
        reason: '誤答保存後の実snapshotがactivity内固定statusへ反映される',
      );
      _expectSingleActivityChrome(tester);
      final snapshot = await store.learningProgressSnapshot(
        LearningScope.personal,
      );
      final run = snapshot.runs.singleWhere(
        (item) =>
            item.nodeId.startsWith('optional-heart:v1:${challenge.mode}:'),
      );
      expect(snapshot.challengeHearts?.current, 0);
      expect(run.activityIndex, 1);
      expect(run.challengeHearts, 0);
    });

    testWidgets('学校${challenge.mode}は誤答後も無制限のまま画面内retryできる', (tester) async {
      final store = MemorySessionStore();
      await _seedNodes(store, const [
        GamePathNodeKind.lesson,
        GamePathNodeKind.practice,
        GamePathNodeKind.story,
        GamePathNodeKind.listening,
        GamePathNodeKind.speaking,
      ], scope: LearningScope.schoolLocal);
      await tester.pumpWidget(_app(store, schoolMode: true));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('ハート、無制限')), findsOneWidget);

      await _openOptionalPracticeMode(tester, challenge.mode);
      await _tapMiniGameControl(
        tester,
        scrollKey: challenge.scrollKey,
        controlKey: challenge.startKey,
      );
      await _tapMiniGameControl(
        tester,
        scrollKey: challenge.scrollKey,
        controlKey: challenge.wrongKey,
      );
      await _tapMiniGameControl(
        tester,
        scrollKey: challenge.scrollKey,
        controlKey: challenge.submitKey,
      );
      await _tapMiniGameControl(
        tester,
        scrollKey: challenge.scrollKey,
        controlKey: challenge.retryKey,
      );

      expect(find.byKey(ValueKey(challenge.startKey)), findsOneWidget);
      expect(find.byKey(ValueKey(challenge.retryKey)), findsNothing);
      expect(
        (await store.learningProgressSnapshot(
          LearningScope.schoolLocal,
        )).challengeHearts,
        isNull,
      );
    });
  }

  testWidgets('時間制の固定誤答はPathやXPを進めず一般化needだけをRepairへ残す', (tester) async {
    final store = MemorySessionStore();
    await _seedNodes(store, const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
      GamePathNodeKind.story,
      GamePathNodeKind.listening,
      GamePathNodeKind.speaking,
    ]);
    await _seedEconomyGems(store, seedId: 'timed-need', amount: 2);
    final before = await store.learningProgressSnapshot(LearningScope.personal);
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    await _openOptionalPracticeMode(tester, 'timed');
    await tester.tap(find.byKey(const ValueKey('timed-entry-confirm')));
    await tester.pumpAndSettle();

    final timedScroll = find
        .descendant(
          of: find.byKey(const ValueKey('science-timed-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    Future<void> timedTap(Finder target) async {
      await tester.scrollUntilVisible(target, 160, scrollable: timedScroll);
      await tester.pump();
      await tester.drag(timedScroll, const Offset(0, -100));
      await tester.pump();
      final bounds = tester.getRect(target);
      await tester.tapAt(Offset(bounds.center.dx, bounds.top + 12));
      await tester.pumpAndSettle();
    }

    await timedTap(find.byKey(const ValueKey('timed-start')));
    await timedTap(
      find.byKey(const ValueKey('cognitive-task-choice-skip-conditions')),
    );
    await timedTap(find.byKey(const ValueKey('timed-task-submit')));
    await timedTap(find.byKey(const ValueKey('timed-finish')));

    final after = await store.learningProgressSnapshot(LearningScope.personal);
    expect(after.activeNeeds, hasLength(1));
    expect(after.activeNeeds.single.skillId, 'motion/fall');
    expect(after.activeNeeds.single.needCode, 'science.fall.transfer');
    expect(after.wallet.xp, before.wallet.xp);
    expect(after.wallet.gems, before.wallet.gems - 1);
    expect(after.gemSpends, hasLength(1));
    expect(after.gemSpends.single.kind, LearningGemSpendKind.challengeEntry);
    expect(after.days, before.days);
    expect(after.runs, isEmpty);
    final bossId = GamePathProjection.nodeId(
      'motion',
      'fall',
      GamePathNodeKind.challenge,
    );
    expect(after.nodes.where((node) => node.nodeId == bossId), isEmpty);
    expect(
      after.events.where(
        (event) => event.nodeId == 'optional:v1:motion:fall:timed:need',
      ),
      hasLength(1),
    );
  });

  testWidgets('必修の章ボスも固定課題用の共有ハートrunで開始する', (tester) async {
    final store = MemorySessionStore();
    await _seedNodes(store, const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
      GamePathNodeKind.story,
      GamePathNodeKind.listening,
      GamePathNodeKind.speaking,
    ]);
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    final id = GamePathProjection.nodeId(
      'motion',
      'fall',
      GamePathNodeKind.challenge,
    );
    final node = find.byKey(ValueKey<String>('game-path-node-$id'));
    final pathScroll = find.descendant(
      of: find.byKey(const PageStorageKey<String>('game-learning-path')),
      matching: find.byType(Scrollable),
    );
    await tester.drag(pathScroll, const Offset(0, -720));
    await tester.pumpAndSettle();
    await tester.tap(node);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-node-sheet-start')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('offline-recall-input')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('game-activity-scaffold')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('game-activity-status')), findsOneWidget);
    _expectSingleActivityChrome(tester);
    expect(
      find.byKey(const ValueKey('offline-practice-screen')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ScienceChallengeHeader>(find.byType(ScienceChallengeHeader))
          .mascotReaction,
      GameCharacterReaction.invite,
    );
    final snapshot = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    final run = snapshot.runs.singleWhere((item) => item.nodeId == id);
    expect(run.challengeHearts, 5);
    expect(snapshot.challengeHearts?.current, 5);
  });

  testWidgets('章ボスcommit失敗は保存済みや祝福を出さず画面内retryで一度だけ保存する', (tester) async {
    final store = _FailNextLearningCommitStore();
    await _seedNodes(store, const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
      GamePathNodeKind.story,
      GamePathNodeKind.listening,
      GamePathNodeKind.speaking,
    ]);
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    final id = GamePathProjection.nodeId(
      'motion',
      'fall',
      GamePathNodeKind.challenge,
    );
    final node = find.byKey(ValueKey<String>('game-path-node-$id'));
    final pathScroll = find.descendant(
      of: find.byKey(const PageStorageKey<String>('game-learning-path')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(node, 240, scrollable: pathScroll);
    await tester.tap(node);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-node-sheet-start')));
    await tester.pumpAndSettle();

    store.failNextCommit = true;
    await _finishChapterBoss(tester);

    expect(
      find.byKey(const ValueKey('game-completion-celebration')),
      findsNothing,
    );
    expect(find.textContaining('練習済みの印を保存できませんでした'), findsOneWidget);
    expect(find.textContaining('この端末に練習済みの印として残しました'), findsNothing);
    var snapshot = await store.learningProgressSnapshot(LearningScope.personal);
    expect(snapshot.events.where((event) => event.nodeId == id), isEmpty);

    final retry = find.byKey(const ValueKey('offline-progress-retry'));
    await tester.scrollUntilVisible(retry, 160, scrollable: _offlineScrollable);
    await tester.tap(retry);
    final celebration = find.byKey(
      const ValueKey('game-completion-celebration'),
    );
    for (var index = 0; index < 20 && celebration.evaluate().isEmpty; index++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(celebration, findsOneWidget);
    final next = find.byKey(const ValueKey('completion-next-step'));
    await tester.scrollUntilVisible(
      next,
      160,
      scrollable: find
          .descendant(of: celebration, matching: find.byType(Scrollable))
          .first,
    );
    await tester.tap(next);
    await tester.pumpAndSettle();
    snapshot = await store.learningProgressSnapshot(LearningScope.personal);
    expect(snapshot.events.where((event) => event.nodeId == id), hasLength(1));
  });

  testWidgets('翌学習日に解放されたLegendaryは専用画面を開く', (tester) async {
    final store = MemorySessionStore();
    await _seedNodes(store, const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
      GamePathNodeKind.story,
      GamePathNodeKind.listening,
      GamePathNodeKind.speaking,
      GamePathNodeKind.challenge,
    ]);
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    final id = GamePathProjection.unitLegendaryNodeId('motion');
    final node = find.byKey(ValueKey<String>('game-path-node-$id'));
    final pathScroll = find.descendant(
      of: find.byKey(const PageStorageKey<String>('game-learning-path')),
      matching: find.byType(Scrollable),
    );
    // Stack内の蛇行nodeは全件build済みなので、存在だけでは可視判定にならない。
    await tester.drag(pathScroll, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(node);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-node-sheet-start')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('science-unit-legendary-screen')),
      findsOneWidget,
    );
    _expectSingleActivityChrome(tester);
    expect(
      find.byKey(const ValueKey('unit-legendary-task-fall')),
      findsOneWidget,
    );
  });

  testWidgets('unit Legendary完了はv2 nodeと専用skillだけを保存し回答とheartを残さない', (
    tester,
  ) async {
    final store = MemorySessionStore();
    await _seedNodes(store, const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
      GamePathNodeKind.story,
      GamePathNodeKind.listening,
      GamePathNodeKind.speaking,
      GamePathNodeKind.challenge,
    ]);
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await _openUnitLegendary(tester);
    await _completeOneConceptUnitLegendary(tester);

    final id = GamePathProjection.unitLegendaryNodeId('motion');
    final skillId = GamePathProjection.unitLegendarySkillId('motion');
    final snapshot = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    final event = snapshot.events.singleWhere((item) => item.nodeId == id);
    expect(event.activityId, 'path.unit-legendary.v2');
    expect(event.activityKind, LearningActivityKind.transfer);
    expect(event.evidence, LearningEvidenceLevel.transfer);
    expect(event.meaningfulProgress, isTrue);
    expect(
      snapshot.nodes.singleWhere((item) => item.nodeId == id).state,
      LearningNodeState.cleared,
    );
    expect(snapshot.skills.any((item) => item.skillId == skillId), isTrue);
    expect(snapshot.runs.where((item) => item.nodeId == id), isEmpty);
    expect(snapshot.challengeHearts?.current, 5);
  });

  testWidgets('旧concept Legendary全clearはv2へ無報酬昇格し、旧runと新runを混ぜない', (
    tester,
  ) async {
    final store = MemorySessionStore();
    await _seedNodes(store, GamePathNodeKind.values);
    final oldId = GamePathProjection.legacyConceptLegendaryNodeId(
      'motion',
      'fall',
    );
    await store.beginLearningRun(
      LearningRun(
        runId: 'run:legacy:legendary',
        scope: LearningScope.personal,
        nodeId: oldId,
        activityIndex: 2,
        challengeHearts: 5,
        contentVersion: 'catalog-v4',
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    final before = await store.learningProgressSnapshot(LearningScope.personal);
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await _openUnitLegendary(tester);
    final opened = await store.learningProgressSnapshot(LearningScope.personal);
    expect(
      opened.runs.any((run) => run.runId == 'run:legacy:legendary'),
      isTrue,
    );
    expect(
      opened.runs.any(
        (run) => run.nodeId == GamePathProjection.unitLegendaryNodeId('motion'),
      ),
      isTrue,
      reason: '旧runを書換えず、v2 runを別IDで開始する',
    );

    await _completeOneConceptUnitLegendary(tester);
    final after = await store.learningProgressSnapshot(LearningScope.personal);
    final migratedEvent = after.events.singleWhere(
      (event) =>
          event.nodeId == GamePathProjection.unitLegendaryNodeId('motion'),
    );
    expect(migratedEvent.evidence, LearningEvidenceLevel.spacedTransfer);
    expect(migratedEvent.meaningfulProgress, isFalse);
    expect(after.rewards.length, before.rewards.length);
    expect(after.quests.length, opened.quests.length);
    expect(
      after.quests.map(
        (quest) => (
          quest.questInstanceId,
          quest.progress,
          quest.completedAt,
          quest.rewardedAt,
        ),
      ),
      orderedEquals(
        opened.quests.map(
          (quest) => (
            quest.questInstanceId,
            quest.progress,
            quest.completedAt,
            quest.rewardedAt,
          ),
        ),
      ),
    );
    expect(
      after.runs
          .singleWhere((run) => run.runId == 'run:legacy:legendary')
          .activityIndex,
      2,
    );
  });

  testWidgets('期限の個別練習は初回固定解を通した時だけ間隔を進め、正解ならハートを保つ', (tester) async {
    final store = MemorySessionStore();
    await _seedNodes(store, const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
      GamePathNodeKind.story,
      GamePathNodeKind.listening,
      GamePathNodeKind.speaking,
      GamePathNodeKind.challenge,
    ]);
    final before = await store.learningProgressSnapshot(LearningScope.personal);
    expect(before.skills.single.successfulRetrievals, 0);

    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-tab-practice')));
    await tester.pumpAndSettle();
    final personalized = find.byKey(
      const ValueKey('practice-mode-practice:personalized'),
    );
    await tester.scrollUntilVisible(
      personalized,
      180,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('practice-hub-screen')),
        matching: find.byType(Scrollable),
      ),
    );
    tester
        .widget<InkWell>(
          find.descendant(of: personalized, matching: find.byType(InkWell)),
        )
        .onTap!();
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    expect(find.textContaining('SPACED REVIEW'), findsOneWidget);

    final reviewScroll = find
        .descendant(
          of: find.byKey(const ValueKey('science-legendary-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    Future<void> scrollToAndTap(Finder target) async {
      await tester.scrollUntilVisible(target, 180, scrollable: reviewScroll);
      await tester.pump();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    await scrollToAndTap(
      find.byKey(const ValueKey('cognitive-task-choice-review-conditions')),
    );
    await scrollToAndTap(find.byKey(const ValueKey('legendary-task-submit')));
    await scrollToAndTap(
      find.byKey(const ValueKey('legendary-checkpoint-option-same')),
    );
    await scrollToAndTap(
      find.byKey(const ValueKey('legendary-checkpoint-submit')),
    );
    final reflection = find.byKey(const ValueKey('legendary-reflection'));
    await tester.scrollUntilVisible(reflection, 180, scrollable: reviewScroll);
    await tester.enterText(reflection, '条件を先に確かめると、結果を区別できる。');
    await tester.pump();
    await scrollToAndTap(find.byKey(const ValueKey('legendary-finish')));
    await _acceptCompletionCelebration(tester);

    final after = await store.learningProgressSnapshot(LearningScope.personal);
    expect(after.challengeHearts?.current, 5);
    expect(after.skills.single.successfulRetrievals, 1);
    expect(
      after.skills.single.nextDueDay.compareTo(dayKeyOf(DateTime.now())),
      greaterThan(0),
    );
    final reviewEvent = after.events.lastWhere(
      (event) => event.origin == LearningOrigin.practice,
    );
    expect(reviewEvent.evidence, LearningEvidenceLevel.spacedTransfer);
    expect(after.runs, isEmpty);
  });

  testWidgets('期限の個別練習も固定誤答でハートを減らし次の固定課題へ替える', (tester) async {
    final store = MemorySessionStore();
    await _seedNodes(store, const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
      GamePathNodeKind.story,
      GamePathNodeKind.listening,
      GamePathNodeKind.speaking,
      GamePathNodeKind.challenge,
    ]);
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-tab-practice')));
    await tester.pumpAndSettle();
    final personalized = find.byKey(
      const ValueKey('practice-mode-practice:personalized'),
    );
    await tester.scrollUntilVisible(
      personalized,
      180,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('practice-hub-screen')),
        matching: find.byType(Scrollable),
      ),
    );
    tester
        .widget<InkWell>(
          find.descendant(of: personalized, matching: find.byType(InkWell)),
        )
        .onTap!();
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    final reviewScroll = find
        .descendant(
          of: find.byKey(const ValueKey('science-legendary-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    Future<void> scrollToAndTap(Finder target) async {
      await tester.scrollUntilVisible(target, 180, scrollable: reviewScroll);
      await tester.pump();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    await scrollToAndTap(
      find.byKey(const ValueKey('cognitive-task-choice-skip-conditions')),
    );
    await scrollToAndTap(find.byKey(const ValueKey('legendary-task-submit')));
    expect(find.byKey(const ValueKey('legendary-checkpoint')), findsNothing);
    expect(find.text('今回はここまで'), findsOneWidget);

    final failed = await store.learningProgressSnapshot(LearningScope.personal);
    expect(failed.challengeHearts?.current, 4);
    expect(failed.skills.single.successfulRetrievals, 0);
    expect(failed.runs.single.activityIndex, 1);

    await _exitActivity(tester);
    await tester.tap(personalized);
    await tester.pumpAndSettle();
    expect(find.text('紙を丸めた場合を予想する。conditions'), findsOneWidget);
  });

  testWidgets('残り1heartのUnit Legendaryは最初の誤答で終了し、1件だけ消費して再起動後も一致する', (
    tester,
  ) async {
    final store = _CountingHeartStore();
    await _seedNodes(store, const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
      GamePathNodeKind.story,
      GamePathNodeKind.listening,
      GamePathNodeKind.speaking,
      GamePathNodeKind.challenge,
    ]);
    await _depletePersonalHearts(store, remaining: 1);
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await _openUnitLegendary(tester);
    await _tapUnitLegendary(
      tester,
      find.byKey(const ValueKey('cognitive-task-choice-skip-conditions')),
    );
    await _tapUnitLegendary(
      tester,
      find.byKey(const ValueKey('unit-legendary-task-submit')),
    );

    expect(
      find.byKey(const ValueKey('unit-legendary-checkpoint-fall')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('unit-legendary-done')), findsOneWidget);
    expect(find.textContaining('回復練習'), findsOneWidget);
    final id = GamePathProjection.unitLegendaryNodeId('motion');
    var snapshot = await store.learningProgressSnapshot(LearningScope.personal);
    var run = snapshot.runs.singleWhere((item) => item.nodeId == id);
    expect(snapshot.challengeHearts?.current, 0);
    expect(run.activityIndex, 1);
    expect(run.challengeHearts, 0);
    expect(store.appliedHeartLosses, 1);
    expect(store.lossIds.toSet(), hasLength(1));
    expect(
      snapshot.events.where(
        (event) => event.activityId == 'path.unit-legendary.v2.retry',
      ),
      hasLength(1),
    );

    await _tapUnitLegendary(
      tester,
      find.byKey(const ValueKey('unit-legendary-return-to-path')),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    snapshot = await store.learningProgressSnapshot(LearningScope.personal);
    run = snapshot.runs.singleWhere((item) => item.nodeId == id);
    expect(snapshot.challengeHearts?.current, 0);
    expect(run.activityIndex, 1);
    expect(run.challengeHearts, 0);
    expect(store.appliedHeartLosses, 1);
    expect(
      snapshot.events.where(
        (event) => event.activityId == 'path.unit-legendary.v2.retry',
      ),
      hasLength(1),
    );
    expect(find.bySemanticsLabel('学習ハート、5個中0個'), findsOneWidget);
  });

  testWidgets('Legendary未クリアはハートを1個だけ減らしてPathへ戻る', (tester) async {
    final store = MemorySessionStore();
    await _seedNodes(store, const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
      GamePathNodeKind.story,
      GamePathNodeKind.listening,
      GamePathNodeKind.speaking,
      GamePathNodeKind.challenge,
    ]);
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    final id = GamePathProjection.unitLegendaryNodeId('motion');
    final node = find.byKey(ValueKey<String>('game-path-node-$id'));
    final pathScroll = find.descendant(
      of: find.byKey(const PageStorageKey<String>('game-learning-path')),
      matching: find.byType(Scrollable),
    );
    await tester.drag(pathScroll, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(node);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-node-sheet-start')));
    await tester.pumpAndSettle();

    final legendaryScroll = find
        .descendant(
          of: find.byKey(const ValueKey('science-unit-legendary-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    Future<void> scrollToAndTap(Finder target) async {
      await tester.scrollUntilVisible(target, 180, scrollable: legendaryScroll);
      await tester.pump();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    await scrollToAndTap(
      find.byKey(const ValueKey('cognitive-task-choice-skip-conditions')),
    );
    await scrollToAndTap(
      find.byKey(const ValueKey('unit-legendary-task-submit')),
    );
    expect(
      find.byKey(const ValueKey('unit-legendary-checkpoint-fall')),
      findsNothing,
    );
    expect(find.text('今回はここまで'), findsOneWidget);

    expect(
      find.byKey(const ValueKey('science-unit-legendary-screen')),
      findsOneWidget,
    );
    final snapshot = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(snapshot.challengeHearts?.current, 4);
    final run = snapshot.runs.singleWhere((item) => item.nodeId == id);
    expect(run.activityIndex, 1);
    expect(run.challengeHearts, 4);
    final failedNode = snapshot.nodes.singleWhere((item) => item.nodeId == id);
    expect(failedNode.state, LearningNodeState.inProgress);
    expect(failedNode.completedAt, isNull, reason: '未クリアをLegendary完了へ変換しない');
    expect(
      snapshot.activeNeeds,
      contains(
        isA<LearningActiveNeed>()
            .having((need) => need.skillId, 'skillId', 'motion/fall')
            .having(
              (need) => need.needCode,
              'needCode',
              'science.fall.foundation',
            ),
      ),
      reason: '回答や選択肢ではなくcatalog固定needだけを残す',
    );

    final returnToPractice = find.byKey(
      const ValueKey('unit-legendary-return-to-path'),
    );
    await scrollToAndTap(returnToPractice);
    expect(
      find.byKey(const ValueKey('science-unit-legendary-screen')),
      findsNothing,
    );
    expect(find.bySemanticsLabel('学習ハート、5個中4個'), findsOneWidget);

    await tester.tap(node);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-node-sheet-start')));
    await tester.pumpAndSettle();
    expect(
      find.text('紙を丸めた場合を予想する。conditions'),
      findsOneWidget,
      reason: '失敗runのactivityIndexで次の固定課題へ切り替える',
    );
    await _completeOneConceptUnitLegendary(tester);
    final recovered = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    final firstClear = recovered.events.singleWhere(
      (event) => event.activityId == 'path.unit-legendary.v2',
    );
    expect(firstClear.evidence, LearningEvidenceLevel.transfer);
    expect(firstClear.meaningfulProgress, isTrue);
    expect(
      recovered.rewards.where(
        (reward) =>
            reward.sourceEventId == firstClear.eventId &&
            reward.type == LearningRewardType.xp,
      ),
      hasLength(1),
      reason: '初回失敗が作った専用skillを期限復習と誤認せず初回clear報酬を出す',
    );
  });

  testWidgets('need記録後にheart保存だけ失敗しても同じrun位置から冪等に再開できる', (tester) async {
    final store = _FailFirstHeartStore();
    await _seedNodes(store, const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
      GamePathNodeKind.story,
      GamePathNodeKind.listening,
      GamePathNodeKind.speaking,
      GamePathNodeKind.challenge,
    ]);
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await _openUnitLegendary(tester);
    await _failOneConceptUnitLegendary(tester);

    final id = GamePathProjection.unitLegendaryNodeId('motion');
    final afterPartial = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(afterPartial.challengeHearts?.current, 5);
    expect(store.spendRequests, 1);
    expect(
      afterPartial.runs.singleWhere((run) => run.nodeId == id).activityIndex,
      0,
    );
    expect(
      afterPartial.events.where(
        (event) => event.activityId == 'path.unit-legendary.v2.retry',
      ),
      hasLength(1),
    );
    final partiallySavedRetry = afterPartial.events.singleWhere(
      (event) => event.activityId == 'path.unit-legendary.v2.retry',
    );

    await _openUnitLegendary(tester);
    await _failOneConceptUnitLegendary(tester);

    final recovered = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(store.spendRequests, 2);
    expect(recovered.challengeHearts?.current, 4);
    expect(
      recovered.runs.singleWhere((run) => run.nodeId == id).activityIndex,
      1,
    );
    expect(
      recovered.events.where(
        (event) => event.activityId == 'path.unit-legendary.v2.retry',
      ),
      hasLength(1),
      reason: '同じneed eventを再送して二重記録やID衝突を起こさない',
    );
    final retriedEvent = recovered.events.singleWhere(
      (event) => event.activityId == 'path.unit-legendary.v2.retry',
    );
    expect(retriedEvent.eventId, partiallySavedRetry.eventId);
    expect(retriedEvent.learningDay, partiallySavedRetry.learningDay);
    expect(retriedEvent.occurredAt, partiallySavedRetry.occurredAt);
  });

  testWidgets('Legendary失敗をexact Repair後に同runで巡回再失敗すると同needが復活する', (
    tester,
  ) async {
    final store = MemorySessionStore();
    await _seedNodes(store, const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
      GamePathNodeKind.story,
      GamePathNodeKind.listening,
      GamePathNodeKind.speaking,
      GamePathNodeKind.challenge,
    ]);
    await tester.pumpWidget(_app(store));
    await tester.pumpAndSettle();

    await _openUnitLegendary(tester);
    await _failOneConceptUnitLegendary(tester);

    final legendaryId = GamePathProjection.unitLegendaryNodeId('motion');
    final firstFailure = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(firstFailure.activeNeeds, hasLength(1));
    expect(firstFailure.activeNeeds.single.needCode, 'science.fall.foundation');
    final originalRun = firstFailure.runs.singleWhere(
      (run) => run.nodeId == legendaryId,
    );
    expect(originalRun.activityIndex, 1);

    Future<LearningEventRecord> repairActiveNeed() async {
      await _openFirstRepair(tester);
      await _finishDiagram(tester, fixedTaskCorrect: true);
      final repaired = await store.learningProgressSnapshot(
        LearningScope.personal,
      );
      expect(repaired.activeNeeds, isEmpty);
      return repaired.events.lastWhere(
        (event) =>
            event.outcome == LearningAttemptOutcome.structuredSuccess &&
            event.activityKind == LearningActivityKind.diagram,
      );
    }

    Future<LearningProgressSnapshot> reopenAndFail({
      required int activityIndex,
      required String expectedNeedCode,
      required LearningEventRecord afterRepair,
    }) async {
      await tester.tap(find.byKey(const ValueKey('game-tab-path')));
      await tester.pumpAndSettle();
      await _openUnitLegendary(tester);
      final reopened = await store.learningProgressSnapshot(
        LearningScope.personal,
      );
      final reopenedRun = reopened.runs.singleWhere(
        (run) => run.nodeId == legendaryId,
      );
      expect(reopenedRun.runId, originalRun.runId, reason: '必修runの再開契約は保つ');
      expect(reopenedRun.activityIndex, activityIndex);
      expect(reopenedRun.updatedAt.isAfter(afterRepair.occurredAt), isTrue);

      await _failOneConceptUnitLegendary(tester);
      final failed = await store.learningProgressSnapshot(
        LearningScope.personal,
      );
      expect(failed.activeNeeds, hasLength(1));
      expect(failed.activeNeeds.single.needCode, expectedNeedCode);
      final failureEvent = failed.events.singleWhere(
        (event) =>
            event.activityId == 'path.unit-legendary.v2.retry' &&
            event.eventId.contains(':need:$activityIndex:'),
      );
      expect(failureEvent.occurredAt, reopenedRun.updatedAt);
      expect(failureEvent.occurredAt.isAfter(afterRepair.occurredAt), isTrue);
      return failed;
    }

    final foundationRepair = await repairActiveNeed();
    await reopenAndFail(
      activityIndex: 1,
      expectedNeedCode: 'science.fall.conditions',
      afterRepair: foundationRepair,
    );
    final conditionsRepair = await repairActiveNeed();
    await reopenAndFail(
      activityIndex: 2,
      expectedNeedCode: 'science.fall.transfer',
      afterRepair: conditionsRepair,
    );
    final transferRepair = await repairActiveNeed();
    final reobserved = await reopenAndFail(
      activityIndex: 3,
      expectedNeedCode: 'science.fall.foundation',
      afterRepair: transferRepair,
    );
    final retryEvents = reobserved.events
        .where((event) => event.activityId == 'path.unit-legendary.v2.retry')
        .toList();
    expect(retryEvents, hasLength(4));
    expect(retryEvents.map((event) => event.eventId).toSet(), hasLength(4));
  });

  testWidgets('学校Legendaryはハートを減らさず未クリアごとに次の課題へ替える', (tester) async {
    final store = MemorySessionStore();
    await _seedNodes(store, const [
      GamePathNodeKind.lesson,
      GamePathNodeKind.practice,
      GamePathNodeKind.story,
      GamePathNodeKind.listening,
      GamePathNodeKind.speaking,
      GamePathNodeKind.challenge,
    ], scope: LearningScope.schoolLocal);
    await tester.pumpWidget(_app(store, schoolMode: true));
    await tester.pumpAndSettle();

    final id = GamePathProjection.unitLegendaryNodeId('motion');
    final node = find.byKey(ValueKey<String>('game-path-node-$id'));
    final pathScroll = find.descendant(
      of: find.byKey(const PageStorageKey<String>('game-learning-path')),
      matching: find.byType(Scrollable),
    );
    await tester.drag(pathScroll, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(node);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-node-sheet-start')));
    await tester.pumpAndSettle();

    final legendaryScroll = find
        .descendant(
          of: find.byKey(const ValueKey('science-unit-legendary-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    Future<void> scrollToAndTap(Finder target) async {
      await tester.scrollUntilVisible(target, 180, scrollable: legendaryScroll);
      await tester.pump();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    await scrollToAndTap(
      find.byKey(const ValueKey('cognitive-task-choice-skip-conditions')),
    );
    await scrollToAndTap(
      find.byKey(const ValueKey('unit-legendary-task-submit')),
    );
    expect(
      find.byKey(const ValueKey('unit-legendary-checkpoint-fall')),
      findsNothing,
    );
    expect(find.text('今回はここまで'), findsOneWidget);

    final failed = await store.learningProgressSnapshot(
      LearningScope.schoolLocal,
    );
    expect(failed.challengeHearts, isNull);
    expect(
      failed.runs.singleWhere((item) => item.nodeId == id).activityIndex,
      1,
    );

    await _exitActivity(tester);
    await tester.tap(node);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-node-sheet-start')));
    await tester.pumpAndSettle();
    expect(find.text('紙を丸めた場合を予想する。conditions'), findsOneWidget);
  });
}

Future<void> _seedLocalLeagueWeek(
  MemorySessionStore store, {
  required String weekKey,
  required int participantCount,
}) async {
  final runId = 'league:$weekKey:r1';
  await store.beginLearningLocalCoopRun(
    LearningLocalCoopRunCommand(
      runId: runId,
      participantIds: {
        for (var slot = 1; slot <= participantCount; slot += 1)
          'league:$weekKey:slot:$slot',
      },
      target: participantCount,
      rewardGems: 0,
      startDay: weekKey,
      endDay: shiftDay(weekKey, 6),
      definitionVersion: LocalWeeklyLeagueProjection.definitionVersion,
      startedAt: dayStartOf(weekKey).add(const Duration(minutes: 1)).toUtc(),
    ),
  );
  for (var slot = 1; slot <= participantCount; slot += 1) {
    final eventCount = slot == 1 ? 2 : 1;
    for (var sequence = 1; sequence <= eventCount; sequence += 1) {
      final eventId = 'league.$weekKey.slot.$slot.event.$sequence';
      final occurredAt = dayStartOf(
        weekKey,
      ).add(Duration(hours: slot, minutes: sequence)).toUtc();
      await store.commitLearningEvent(
        LearningEventCommand(
          eventId: eventId,
          scope: LearningScope.personal,
          origin: LearningOrigin.path,
          courseId: 'science-ja-v1',
          nodeId: 'league:$weekKey:node:$slot:$sequence',
          activityId: 'league.$weekKey.activity.$slot.$sequence',
          skillIds: {'league:$weekKey:skill:$slot:$sequence'},
          activityKind: LearningActivityKind.transfer,
          outcome: LearningAttemptOutcome.structuredSuccess,
          evidence: LearningEvidenceLevel.transfer,
          contentVersion: 'catalog-v9',
          learningDay: weekKey,
          occurredAt: occurredAt,
        ),
      );
      await store.contributeLearningLocalCoopRun(
        runId,
        contributionId: 'league.$weekKey.contribution.$slot.$sequence',
        participantId: 'league:$weekKey:slot:$slot',
        eventId: eventId,
        occurredAt: occurredAt.add(const Duration(seconds: 1)),
      );
    }
  }
}
