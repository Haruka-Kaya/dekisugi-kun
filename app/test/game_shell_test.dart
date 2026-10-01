import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/models/game_path.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/game_shell.dart';
import 'package:flutter_test/flutter_test.dart';

const _status = GamePlayerStatus(
  streakDays: 14,
  streakFreezeRemaining: 2,
  gems: 1280,
  hearts: 4,
);

const _schoolStatus = GamePlayerStatus(
  streakDays: 0,
  streakFreezeRemaining: 0,
  gems: 0,
  hearts: 5,
  unlimitedHearts: true,
);

const _quests = <GameQuest>[
  GameQuest(
    id: 'daily-compare',
    title: '予想と結果を1回比べる',
    description: '答えを見る前の予想と、教材の結果を比べます。',
    kind: GameQuestKind.daily,
    state: GameQuestState.active,
    current: 0,
    target: 1,
    rewardLabel: '結晶 5個',
  ),
];

const _schoolQuests = <GameQuest>[
  GameQuest(
    id: 'classroom-observe',
    title: 'この端末で観察を1件終える',
    description: '授業中の端末内目標です。',
    kind: GameQuestKind.classroom,
    state: GameQuestState.completed,
    current: 1,
    target: 1,
    rewardLabel: '結晶 5個',
  ),
];

const _friendQuest = GameQuest(
  id: 'local-coop:pair:2026-08-10:v1',
  title: '端末内ペアクエスト',
  description: '同じ端末を2人で交代して進めます。',
  kind: GameQuestKind.friend,
  state: GameQuestState.active,
  current: 1,
  target: 2,
  rewardLabel: '結晶 3個',
);

void main() {
  testWidgets('初回案内は各タブの役割を順番に示し、いつでも閉じられる', (tester) async {
    var dismissed = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: GameShell(
          showTabGuide: true,
          onTabGuideDismissed: () => dismissed += 1,
          path: const Center(child: Text('PATH')),
          stories: const Center(child: Text('STORIES')),
          practice: const Center(child: Text('PRACTICE')),
          notation: const Center(child: Text('NOTATION')),
          league: const Center(child: Text('LEAGUE')),
          profile: const Center(child: Text('PROFILE')),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('game-tab-guide')), findsOneWidget);
    expect(find.text('探究ノート'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('game-tab-guide-next')));
    await tester.pumpAndSettle();
    expect(find.text('理科事件簿'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('game-tab-guide-dismiss')));
    await tester.pumpAndSettle();
    expect(dismissed, 1);
    expect(find.byKey(const ValueKey('game-tab-guide')), findsNothing);
    expect(find.text('PATH'), findsOneWidget);
  });

  testWidgets('6タブは状態を保持し、320dp・文字200%でも操作できる', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    var pathBuilds = 0;
    var storyBuilds = 0;
    var economyTaps = 0;

    Widget page(String text, VoidCallback built) => _CountBuild(
      onBuild: built,
      child: Center(child: Text(text)),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: GameShell(
          path: page('PATH', () => pathBuilds += 1),
          stories: page('STORIES', () => storyBuilds += 1),
          practice: const Center(child: Text('PRACTICE')),
          notation: const Center(child: Text('NOTATION')),
          league: const Center(child: Text('LEAGUE')),
          profile: const Center(child: Text('PROFILE')),
          playerStatus: _status,
          quests: _quests,
          onStreakTap: () => economyTaps += 1,
          onGemsTap: () => economyTaps += 1,
          onHeartsTap: () => economyTaps += 1,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('PATH'), findsOneWidget);
    expect(find.bySemanticsLabel('探究ノート'), findsOneWidget);
    for (final mimeticResourceIcon in <IconData>[
      Icons.local_fire_department_rounded,
      Icons.diamond_rounded,
      Icons.favorite_rounded,
      Icons.emoji_events_rounded,
      Icons.bolt_rounded,
    ]) {
      expect(
        find.byIcon(mimeticResourceIcon),
        findsNothing,
        reason: '固定headerとnavigationへ旧ゲーム資源の記号を戻さない',
      );
    }
    for (final oldTabLabel in <String>['学ぶ', '物語', '練習', '記号', '競う', '自分']) {
      expect(
        find.text(oldTabLabel),
        findsNothing,
        reason: '6領域はField Notebookの情報設計を正本にする',
      );
    }
    final header = find.byKey(const ValueKey('game-player-status-header'));
    final initialHeaderTop = tester.getTopLeft(header);
    expect(header, findsOneWidget);
    expect(
      find.ancestor(of: header, matching: find.byType(IndexedStack)),
      findsNothing,
      reason: 'status headerはタブpageではなくShellが固定する',
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('player-status-bar'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('game-quest-button'))).height,
      greaterThanOrEqualTo(48),
    );
    for (final tab in [
      'path',
      'stories',
      'practice',
      'notation',
      'league',
      'profile',
    ]) {
      expect(
        tester.getSize(find.byKey(ValueKey('game-tab-$tab'))).height,
        greaterThanOrEqualTo(48),
      );
    }

    const destinations = <String, String>{
      'stories': 'STORIES',
      'practice': 'PRACTICE',
      'notation': 'NOTATION',
      'league': 'LEAGUE',
      'profile': 'PROFILE',
      'path': 'PATH',
    };
    for (final entry in destinations.entries) {
      await tester.tap(find.byKey(ValueKey<String>('game-tab-${entry.key}')));
      await tester.pump();
      expect(find.text(entry.value), findsOneWidget);
      expect(header, findsOneWidget);
      expect(tester.getTopLeft(header), initialHeaderTop);
    }
    expect(pathBuilds, greaterThanOrEqualTo(1));
    expect(storyBuilds, greaterThanOrEqualTo(1));

    await tester.tap(find.byKey(const ValueKey('player-status-gems')));
    expect(economyTaps, 1);
    await tester.tap(find.byKey(const ValueKey('game-quest-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game-quest-sheet')), findsOneWidget);
    expect(find.text('予想と結果を1回比べる'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('700dp以上は影のないside railへ切り替え、6画面を保持する', (tester) async {
    tester.view.physicalSize = const Size(820, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const GameShell(
          path: Center(child: Text('PATH')),
          stories: Center(child: Text('STORIES')),
          practice: Center(child: Text('PRACTICE')),
          notation: Center(child: Text('NOTATION')),
          league: Center(child: Text('LEAGUE')),
          profile: Center(child: Text('PROFILE')),
          playerStatus: _status,
          quests: _quests,
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('game-tab-rail')), findsOneWidget);
    final header = find.byKey(const ValueKey('game-player-status-header'));
    expect(header, findsOneWidget);
    expect(tester.getTopLeft(header).dx, greaterThanOrEqualTo(104));
    expect(
      tester.getSize(find.byKey(const ValueKey('player-status-bar'))).width,
      lessThanOrEqualTo(600),
    );
    expect(find.byType(BottomNavigationBar), findsNothing);
    for (final tab in [
      'path',
      'stories',
      'practice',
      'notation',
      'league',
      'profile',
    ]) {
      expect(
        tester.getSize(find.byKey(ValueKey('game-tab-$tab'))).height,
        greaterThanOrEqualTo(48),
      );
    }

    await tester.tap(find.byKey(const ValueKey('game-tab-stories')));
    await tester.pump();
    expect(find.text('STORIES'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('game-tab-profile')));
    await tester.pump();
    expect(find.text('PROFILE'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('観察予定の主操作は固有callbackなしでも探究ノートへ戻す', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const GameShell(
          initialTab: GameTab.profile,
          path: Center(child: Text('PATH')),
          stories: Center(child: Text('STORIES')),
          practice: Center(child: Text('PRACTICE')),
          notation: Center(child: Text('NOTATION')),
          league: Center(child: Text('LEAGUE')),
          profile: Center(child: Text('PROFILE')),
          playerStatus: _status,
          quests: _quests,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('PROFILE'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('game-quest-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game-quest-sheet')), findsOneWidget);

    await tester.tap(find.text('この予定を開く'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('game-quest-sheet')), findsNothing);
    expect(find.text('PATH'), findsOneWidget);
    expect(
      find.bySemanticsLabel('探究ノート'),
      findsOneWidget,
      reason: 'クエストを閉じた後は次のPath nodeを選べる状態へ戻す',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('端末内ペアクエストの主操作は参加者切替のある自分タブへ移す', (tester) async {
    GameQuest? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: GameShell(
          path: const Center(child: Text('PATH')),
          stories: const Center(child: Text('STORIES')),
          practice: const Center(child: Text('PRACTICE')),
          notation: const Center(child: Text('NOTATION')),
          league: const Center(child: Text('LEAGUE')),
          profile: const Center(child: Text('PROFILE')),
          playerStatus: _status,
          quests: const [_friendQuest],
          onQuestSelected: (quest) => selected = quest,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('game-quest-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('この予定を開く'));
    await tester.pumpAndSettle();

    expect(find.text('PROFILE'), findsOneWidget);
    expect(selected?.id, _friendQuest.id);
    expect(tester.takeException(), isNull);
  });

  testWidgets('学校modeでも固定headerを6タブで保ち、個人報酬を表示しない', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const GameShell(
          schoolMode: true,
          playerStatus: _schoolStatus,
          quests: _schoolQuests,
          path: Center(child: Text('PATH')),
          stories: Center(child: Text('STORIES')),
          practice: Center(child: Text('PRACTICE')),
          notation: Center(child: Text('NOTATION')),
          league: Center(child: Text('LEAGUE')),
          profile: Center(child: Text('PROFILE')),
        ),
      ),
    );
    await tester.pump();

    final header = find.byKey(const ValueKey('game-player-status-header'));
    expect(header, findsOneWidget);
    expect(find.byKey(const ValueKey('player-status-streak')), findsNothing);
    expect(find.byKey(const ValueKey('player-status-gems')), findsNothing);
    expect(find.byKey(const ValueKey('player-status-hearts')), findsOneWidget);
    expect(find.bySemanticsLabel('授業モード。試行、無制限。個人報酬は記録しません'), findsOneWidget);
    expect(find.bySemanticsLabel('授業の観察予定。進行中はありません'), findsOneWidget);

    for (final tab in GameTab.values) {
      await tester.tap(find.byKey(ValueKey<String>('game-tab-${tab.name}')));
      await tester.pump();
      expect(header, findsOneWidget);
    }

    await tester.tap(find.byKey(const ValueKey('game-quest-button')));
    await tester.pumpAndSettle();
    expect(find.text('この端末の授業予定'), findsOneWidget);
    expect(find.text('この端末に記録済み'), findsOneWidget);
    expect(find.text('結晶 5個'), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

class _CountBuild extends StatelessWidget {
  const _CountBuild({required this.onBuild, required this.child});

  final VoidCallback onBuild;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    onBuild();
    return child;
  }
}
