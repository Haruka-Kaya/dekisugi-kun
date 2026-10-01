import 'package:dekisugi/learning/services/game_content_projection.dart';
import 'package:dekisugi/learning/services/game_path_projection.dart';
import 'package:dekisugi/models/game_hub.dart';
import 'package:dekisugi/models/game_path.dart';
import 'package:dekisugi/models/unit.dart';
import 'package:flutter_test/flutter_test.dart';

const _catalog = [
  UnitSummary(
    id: 'motion',
    title: '運動',
    brief: '運動を説明する',
    concepts: [
      UnitConcept(key: 'fall', label: '落下', storyTitle: '紙ひこうき部、落下レース中止事件'),
    ],
    sectionCount: 1,
  ),
];

const _status = GamePlayerStatus(
  streakDays: 0,
  streakFreezeRemaining: 0,
  gems: 0,
  hearts: 5,
);

void main() {
  const pathProjection = GamePathProjection();
  const projection = GameContentProjection();

  test('Story一覧はPathのstory node状態だけを使う', () {
    final storyId = GamePathProjection.nodeId(
      'motion',
      'fall',
      GamePathNodeKind.story,
    );
    final path = pathProjection.build(
      catalog: _catalog,
      progress: GamePathProgressInput(clearedNodeIds: {storyId}),
      status: _status,
    );
    final result = projection.build(
      catalog: _catalog,
      path: path,
      duePracticeCount: 0,
    );
    expect(result.stories.single.id, storyId);
    expect(result.stories.single.state, GameContentState.completed);
    expect(result.stories.single.title, '紙ひこうき部、落下レース中止事件');
  });

  test('練習ラボは期限・中断・active need・総合検証を別の事実から開く', () {
    final lessonId = GamePathProjection.nodeId(
      'motion',
      'fall',
      GamePathNodeKind.lesson,
    );
    final challengeId = GamePathProjection.nodeId(
      'motion',
      'fall',
      GamePathNodeKind.challenge,
    );
    final path = pathProjection.build(
      catalog: _catalog,
      progress: GamePathProgressInput(
        clearedNodeIds: {lessonId},
        inProgressNodeIds: {challengeId},
      ),
      status: _status,
    );
    final result = projection.build(
      catalog: _catalog,
      path: path,
      duePracticeCount: 1,
    );
    final byKind = {for (final mode in result.practiceModes) mode.kind: mode};
    expect(byKind[PracticeModeKind.personalized]!.enabled, isTrue);
    expect(byKind[PracticeModeKind.resume]!.enabled, isTrue);
    expect(byKind[PracticeModeKind.resume]!.badge, '1件');
    expect(
      byKind[PracticeModeKind.repair]!.enabled,
      isFalse,
      reason: '中断runや期限復習をactive mistakeのRepairに偽装しない',
    );
    // listening/speaking node自体はまだlockedなので、見かけだけの導線を出さない。
    expect(byKind[PracticeModeKind.listenSpeak]!.enabled, isFalse);
    expect(byKind[PracticeModeKind.diagram]!.enabled, isTrue);
    // 実際にchallengeがin progressなので、任意の時間制も開く。
    expect(byKind[PracticeModeKind.timed]!.enabled, isTrue);
    expect(byKind[PracticeModeKind.timed]!.title, '時間観察');
    expect(byKind[PracticeModeKind.match]!.title, '対応づけ実験');
    expect(byKind[PracticeModeKind.lightning]!.title, '連続観察');

    final withNeed = projection.build(
      catalog: _catalog,
      path: path,
      duePracticeCount: 1,
      activeRepairCount: 2,
    );
    final repair = withNeed.practiceModes.singleWhere(
      (mode) => mode.kind == PracticeModeKind.repair,
    );
    expect(repair.enabled, isTrue);
    expect(repair.badge, '2件');
  });

  test('個人タイム挑戦券は残高不足だけを止め、学校と購入済み日は開く', () {
    final challengeId = GamePathProjection.nodeId(
      'motion',
      'fall',
      GamePathNodeKind.challenge,
    );
    final path = pathProjection.build(
      catalog: _catalog,
      progress: GamePathProgressInput(inProgressNodeIds: {challengeId}),
      status: _status,
    );

    GameContentProjectionResult build({
      bool schoolMode = false,
      bool pass = false,
      bool canBuy = true,
    }) => projection.build(
      catalog: _catalog,
      path: path,
      duePracticeCount: 0,
      schoolMode: schoolMode,
      timedChallengeGemCost: 1,
      timedChallengePassActive: pass,
      canPurchaseTimedChallengePass: canBuy,
    );

    PracticeModeView timed(GameContentProjectionResult result) => result
        .practiceModes
        .singleWhere((mode) => mode.kind == PracticeModeKind.timed);

    expect(timed(build(canBuy: false)).enabled, isFalse);
    expect(timed(build(canBuy: false)).badge, contains('結晶不足'));
    expect(timed(build(pass: true, canBuy: false)).enabled, isTrue);
    expect(timed(build(pass: true, canBuy: false)).badge, contains('時間観察券あり'));
    expect(timed(build(schoolMode: true, canBuy: false)).enabled, isTrue);
    expect(timed(build(schoolMode: true, canBuy: false)).badge, '任意・試行余力は無制限');
  });
}
