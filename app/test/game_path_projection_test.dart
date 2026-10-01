import 'package:dekisugi/learning/services/game_path_projection.dart';
import 'package:dekisugi/models/game_path.dart';
import 'package:dekisugi/models/unit.dart';
import 'package:flutter_test/flutter_test.dart';

const _catalog = [
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

const _status = GamePlayerStatus(
  streakDays: 2,
  streakFreezeRemaining: 1,
  gems: 30,
  hearts: 5,
);

void main() {
  const projection = GamePathProjection();

  test('各概念へ6必修、unit末へv2 Legendaryを1件だけ作る', () {
    final view = projection.build(
      catalog: _catalog,
      progress: const GamePathProgressInput(),
      status: _status,
    );
    expect(view.units, hasLength(1));
    expect(view.units.single.nodes, hasLength(13));
    expect(view.units.single.nodes.first.state, GamePathNodeState.available);
    expect(
      view.units.single.nodes
          .skip(1)
          .every((node) => node.state == GamePathNodeState.locked),
      isTrue,
    );
    expect(view.currentNodeId, contains(':fall:lesson'));
    final listening = view.units.single.nodes.singleWhere(
      (node) => node.id.contains(':fall:listening'),
    );
    expect(listening.title, '説明を聞いて見抜く');
    expect(listening.description, contains('教材の説明を聞き'));
    expect(listening.learningActions, contains('条件を判断する'));
    final legendary = view.units.single.nodes.singleWhere(
      (node) => node.kind == GamePathNodeKind.legendary,
    );
    expect(legendary.id, 'path:v2:motion:unit:legendary');
    expect(
      view.units.single.nodes.where(
        (node) =>
            node.id.startsWith('path:v1:motion:') &&
            node.kind == GamePathNodeKind.legendary,
      ),
      isEmpty,
    );
  });

  test('Legendary未解放は次概念を止めず、required順だけでcurrentを決める', () {
    final firstConceptRequired = {
      for (final kind in const [
        GamePathNodeKind.lesson,
        GamePathNodeKind.practice,
        GamePathNodeKind.story,
        GamePathNodeKind.listening,
        GamePathNodeKind.speaking,
        GamePathNodeKind.challenge,
      ])
        GamePathProjection.nodeId('motion', 'fall', kind),
    };
    final view = projection.build(
      catalog: _catalog,
      progress: GamePathProgressInput(clearedNodeIds: firstConceptRequired),
      status: _status,
    );
    expect(view.currentNodeId, contains(':inertia:lesson'));
    expect(
      view.units.single.nodes
          .where((node) => node.kind == GamePathNodeKind.legendary)
          .first
          .state,
      GamePathNodeState.locked,
    );
  });

  test('旧4段階完了は教材と構造taskだけを移行し、Story等を捏造しない', () {
    final view = projection.build(
      catalog: _catalog,
      progress: const GamePathProgressInput(
        legacyCompletedSkillIds: {'motion/fall'},
      ),
      status: _status,
    );
    final fallNodes = view.units.single.nodes.take(6).toList();
    expect(fallNodes[0].state, GamePathNodeState.completed);
    expect(fallNodes[1].state, GamePathNodeState.completed);
    expect(fallNodes[2].state, GamePathNodeState.available);
    expect(fallNodes[3].state, GamePathNodeState.locked);
  });

  test('単元末の高難度検証は報酬表示を探究記録へ統一し、unit IDで状態を受け取る', () {
    final available = projection.build(
      catalog: _catalog,
      progress: const GamePathProgressInput(
        legendaryAvailableUnitIds: {'motion'},
        legendaryRewardEligibleUnitIds: {'motion'},
      ),
      status: _status,
    );
    final availableNode = available.units.single.nodes.singleWhere(
      (node) => node.kind == GamePathNodeKind.legendary,
    );
    expect(availableNode.state, GamePathNodeState.legendaryAvailable);
    expect(availableNode.rewardLabel, contains('探究記録'));

    final migrated = projection.build(
      catalog: _catalog,
      progress: const GamePathProgressInput(
        legendaryCompletedUnitIds: {'motion'},
      ),
      status: _status,
    );
    final migratedNode = migrated.units.single.nodes.singleWhere(
      (node) => node.kind == GamePathNodeKind.legendary,
    );
    expect(migratedNode.state, GamePathNodeState.legendaryCompleted);
    expect(migratedNode.rewardLabel, isNull);
  });

  test('復習期限が来ても完了歩数は後退しない', () {
    final practiceId = GamePathProjection.nodeId(
      'motion',
      'fall',
      GamePathNodeKind.practice,
    );
    final view = projection.build(
      catalog: _catalog,
      progress: GamePathProgressInput(
        clearedNodeIds: {practiceId},
        reviewDueSkillIds: const {'motion/fall'},
      ),
      status: _status,
    );
    expect(
      view.units.single.nodes.firstWhere((node) => node.id == practiceId).state,
      GamePathNodeState.reviewDue,
    );
    expect(view.units.single.completedSteps, 1);
  });

  test('完了済み再演にはXPを予告せず、初回と期限復習だけ表示する', () {
    final lessonId = GamePathProjection.nodeId(
      'motion',
      'fall',
      GamePathNodeKind.lesson,
    );
    final practiceId = GamePathProjection.nodeId(
      'motion',
      'fall',
      GamePathNodeKind.practice,
    );
    final view = projection.build(
      catalog: _catalog,
      progress: GamePathProgressInput(
        clearedNodeIds: {lessonId, practiceId},
        reviewDueSkillIds: const {'motion/fall'},
      ),
      status: _status,
    );
    final lesson = view.units.single.nodes.singleWhere(
      (node) => node.id == lessonId,
    );
    final practice = view.units.single.nodes.singleWhere(
      (node) => node.id == practiceId,
    );
    expect(lesson.state, GamePathNodeState.completed);
    expect(lesson.rewardLabel, isNull);
    expect(practice.state, GamePathNodeState.reviewDue);
    expect(practice.rewardLabel, contains('初回・期限復習・1日上限まで'));
  });

  test('当日のXP上限に達したら、未完了nodeにも報酬を予告しない', () {
    final view = projection.build(
      catalog: _catalog,
      progress: const GamePathProgressInput(),
      status: _status,
      rewardXpAvailable: 0,
    );

    expect(view.units.single.nodes.first.state, GamePathNodeState.available);
    expect(view.units.single.nodes.first.rewardLabel, isNull);
  });

  test('学校モードは報酬ラベルを出さず、ハート無制限statusを保持する', () {
    final view = projection.build(
      catalog: _catalog,
      progress: const GamePathProgressInput(),
      status: const GamePlayerStatus(
        streakDays: 0,
        streakFreezeRemaining: 0,
        gems: 0,
        hearts: 0,
        unlimitedHearts: true,
      ),
      schoolMode: true,
    );
    expect(view.schoolMode, isTrue);
    expect(view.status.unlimitedHearts, isTrue);
    expect(
      view.units.single.nodes.every((node) => node.rewardLabel == null),
      isTrue,
    );
  });
}
