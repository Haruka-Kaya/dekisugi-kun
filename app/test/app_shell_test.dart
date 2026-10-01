import 'dart:convert';
import 'dart:ui' show SemanticsAction, Tristate;

import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/learning/services/game_path_projection.dart';
import 'package:dekisugi/main.dart';
import 'package:dekisugi/models/classroom_mission.dart';
import 'package:dekisugi/models/game_path.dart';
import 'package:dekisugi/screens/consent_screen.dart';
import 'package:dekisugi/screens/game_economy_sheet.dart';
import 'package:dekisugi/screens/game_profile_screen.dart';
import 'package:dekisugi/screens/league_screen.dart';
import 'package:dekisugi/screens/lan_social_screen.dart';
import 'package:dekisugi/screens/local_classroom_screen.dart';
import 'package:dekisugi/screens/path_screen.dart';
import 'package:dekisugi/screens/science_game_home_screen.dart';
import 'package:dekisugi/screens/science_lesson_screen.dart';
import 'package:dekisugi/screens/settings_screen.dart';
import 'package:dekisugi/services/consent.dart';
import 'package:dekisugi/services/device_identity.dart';
import 'package:dekisugi/services/local_practice_store.dart';
import 'package:dekisugi/services/purchase_service.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:dekisugi/services/subscription_sync_client.dart';
import 'package:dekisugi/services/team_client.dart';
import 'package:dekisugi/services/units_client.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _JsonAssetBundle extends CachingAssetBundle {
  _JsonAssetBundle(this.source);

  final String source;

  @override
  Future<ByteData> load(String key) async {
    final bytes = Uint8List.fromList(utf8.encode(source));
    return ByteData.sublistView(bytes);
  }
}

Map<String, Object?> _checkpoint(String prefix, String needCode) => {
  'lure': '$prefixについての固定の思い込み',
  'options': [
    {'id': '${prefix}a', 'text': '正しい説明'},
    {
      'id': '${prefix}b',
      'text': '誤った説明1',
      'hint': '条件を見直す',
      'needCode': needCode,
    },
    {
      'id': '${prefix}c',
      'text': '誤った説明2',
      'hint': '理由を見直す',
      'needCode': needCode,
    },
  ],
  'correctOptionId': '${prefix}a',
  'explanation': '$prefixの正しい考え方',
};

Map<String, Object?> _cognitiveTask(String prefix, String needCode) => {
  'kind': 'singleSelect',
  'operation': 'prediction',
  'needCode': needCode,
  'items': [
    {'id': '$prefix-observe', 'text': '$prefixの条件を確かめて予想する'},
    {'id': '$prefix-impression', 'text': '$prefixを印象だけで予想する'},
  ],
  'solution': {'selectedItemId': '$prefix-observe'},
};

List<Map<String, Object?>> _practiceVariants(String prefix) => [
  {
    'stage': 'foundation',
    'recallPrompt': '$prefixの中心となる考えを思い出す。',
    'reasoningPrompt': '$prefixが成り立つ理由を足す。',
    'transferPrompt': '$prefixの最初の具体場面を予想する。',
    'expectedOutcome': '$prefixの最初の場面で起きる結果。',
    'expectedReason': '$prefixの最初の場面でその結果になる理由。',
    'cognitiveTask': _cognitiveTask(
      '$prefix-foundation',
      'science.$prefix.foundation',
    ),
    'checkpoint': _checkpoint(prefix, 'science.$prefix.foundation'),
    'listeningNeedCodes': _listeningNeedCodes(prefix, 'foundation'),
  },
  {
    'stage': 'conditions',
    'recallPrompt': '$prefixの成立条件を思い出す。',
    'reasoningPrompt': '$prefixの条件を区別する。',
    'transferPrompt': '$prefixの条件を変えた場面を予想する。',
    'expectedOutcome': '$prefixの条件を変えた場面の結果。',
    'expectedReason': '$prefixの条件の違いが結果を変える理由。',
    'cognitiveTask': _cognitiveTask(
      '$prefix-conditions',
      'science.$prefix.conditions',
    ),
    'checkpoint': _checkpoint(
      '$prefix-conditions',
      'science.$prefix.conditions',
    ),
    'listeningNeedCodes': _listeningNeedCodes(prefix, 'conditions'),
  },
  {
    'stage': 'transfer',
    'recallPrompt': '$prefixを別場面で使うための原理を思い出す。',
    'reasoningPrompt': '$prefixを別場面へつなぐ理由を書く。',
    'transferPrompt': '$prefixの未見の具体場面を予想する。',
    'expectedOutcome': '$prefixの未見の具体場面で起きる結果。',
    'expectedReason': '$prefixの原理を未見の場面へ適用する理由。',
    'cognitiveTask': _cognitiveTask(
      '$prefix-transfer',
      'science.$prefix.transfer',
    ),
    'checkpoint': _checkpoint('$prefix-transfer', 'science.$prefix.transfer'),
    'listeningNeedCodes': _listeningNeedCodes(prefix, 'transfer'),
  },
];

Map<String, Object?> _listeningNeedCodes(String prefix, String stage) => {
  'transcript': 'science.$prefix.listening.$stage.transcript',
  'meaning': 'science.$prefix.listening.$stage.meaning',
};

Map<String, Object?> _tracePattern(String id) => {
  'semanticsLabel': '$idを左から右へなぞる。',
  'strokes': [
    {
      'id': '$id-stroke',
      'label': '確認線',
      'points': [
        {'x': 0.1, 'y': 0.5},
        {'x': 0.5, 'y': 0.5},
        {'x': 0.9, 'y': 0.5},
      ],
    },
  ],
  'strokeOrderIds': ['$id-stroke'],
};

Map<String, Object?> _notationLab(String prefix) => {
  'orderTasks': [
    {
      'id': '$prefix-arrow',
      'needCode': 'science.$prefix.notation.arrow',
      'title': '$prefixの矢印',
      'prompt': '$prefixの矢印を意味の順に並べる。',
      'traceGuide': '作用点から向きの順に確かめる。',
      'tracePattern': _tracePattern('$prefix-arrow'),
      'tokens': [
        {'id': '$prefix-direction', 'label': '向き'},
        {'id': '$prefix-origin', 'label': '作用点'},
      ],
      'correctOrderIds': ['$prefix-origin', '$prefix-direction'],
      'solutionSummary': '作用点から向きへ読む。',
    },
    {
      'id': '$prefix-equation',
      'needCode': 'science.$prefix.notation.equation',
      'title': '$prefixの式',
      'prompt': '$prefixの結果と原因を式にする。',
      'traceGuide': '結果、等号、原因の順に確かめる。',
      'tracePattern': _tracePattern('$prefix-equation'),
      'tokens': [
        {'id': '$prefix-cause', 'label': '原因'},
        {'id': '$prefix-equals', 'label': '＝'},
        {'id': '$prefix-result', 'label': '結果'},
      ],
      'correctOrderIds': ['$prefix-result', '$prefix-equals', '$prefix-cause'],
      'solutionSummary': '結果＝原因の関係で表す。',
    },
  ],
  'symbolMatch': {
    'needCode': 'science.$prefix.notation.symbol',
    'prompt': '$prefixの単位記号を選ぶ。',
    'choices': [
      {'id': '$prefix-unit-wrong', 'label': '誤った単位'},
      {'id': '$prefix-unit-right', 'label': '正しい単位'},
    ],
    'correctChoiceId': '$prefix-unit-right',
    'solutionSummary': '$prefixの量に対応する単位を使う。',
  },
  'graphRead': {
    'needCode': 'science.$prefix.notation.graph',
    'prompt': '$prefixのグラフで増え方を読む。',
    'graphNotation': ['縦軸 $prefix', '横軸 時間 →'],
    'graphSemanticsLabel': '縦軸が$prefix、横軸が時間のグラフ',
    'choices': [
      {'id': '$prefix-graph-flat', 'label': '変化しない'},
      {'id': '$prefix-graph-rise', 'label': '増えている'},
    ],
    'correctChoiceId': '$prefix-graph-rise',
    'solutionSummary': '右上がりなら$prefixは増えている。',
  },
};

Map<String, Object?> _scienceStory(String prefix) {
  final foundation = _practiceVariants(prefix).first;
  final checkpoint = foundation['checkpoint']! as Map<String, Object?>;
  final options = checkpoint['options']! as List<Map<String, Object?>>;
  Map<String, Object?> line(String id, String speaker, String text) => {
    'id': '$prefix-story-$id',
    'speakerId': speaker,
    'text': text,
  };
  return {
    'id': '$prefix-story',
    'title': '$prefixの固定事件',
    'setting': '$prefixを調べる固定の舞台',
    'foundationNeedCode': 'science.$prefix.foundation',
    'characters': [
      {'id': 'mio', 'name': 'ミオ', 'role': '観察'},
      {'id': 'dekisugi', 'name': 'デキすぎ君', 'role': '仮説'},
      {'id': 'ren', 'name': 'レン', 'role': '記録'},
    ],
    'openingLines': [
      line('open-1', 'mio', '$prefixを観察しよう。'),
      line('open-2', 'ren', '条件を記録したよ。'),
      line('open-3', 'dekisugi', '仮説は任せて。'),
    ],
    'choiceLine': line('choice', 'dekisugi', checkpoint['lure']! as String),
    'choiceResponses': [
      for (var index = 0; index < options.length; index++)
        {
          'optionId': options[index]['id'],
          'line': line(
            'response-$index',
            ['mio', 'dekisugi', 'ren'][index],
            '${options[index]['id']}への反応。',
          ),
        },
    ],
    'resolutionLines': [
      line('resolve-1', 'mio', '観察結果を確かめた。'),
      line('resolve-2', 'ren', '理由も一致した。'),
    ],
    'scientificResolution': {
      'outcome': foundation['expectedOutcome'],
      'reason': foundation['expectedReason'],
    },
    'punchline': line('punchline', 'dekisugi', '$prefixの短い落ち。'),
  };
}

String get _localCatalogJson => jsonEncode({
  'schemaVersion': 10,
  'language': 'ja',
  'units': [
    {
      'id': 'local-unit',
      'title': '端末内テスト単元',
      'brief': '2概念の決定論fixture',
      'concepts': [
        {
          'key': 'first',
          'label': '最初の考え',
          'storyTitle': 'firstの固定事件',
          'field': 'energy',
          'grade': 3,
          'curriculumRefs': [
            {
              'document': 'mext-jhs-science-2017',
              'section': '第1分野 (5)(イ)',
              'pages': [55],
              'url':
                  'https://www.mext.go.jp/component/a_menu/education/'
                  'micro_detail/__icsFiles/afieldfile/2019/03/18/'
                  '1387018_005.pdf',
            },
          ],
          'prerequisites': <String>[],
          'difficulty': 1,
          'safety': {
            'level': 'referenceOnly',
            'guidance': 'テストfixtureでは観察を行わない。',
          },
        },
        {
          'key': 'second',
          'label': '次の考え',
          'storyTitle': 'secondの固定事件',
          'field': 'energy',
          'grade': 3,
          'curriculumRefs': [
            {
              'document': 'mext-jhs-science-2017',
              'section': '第1分野 (5)(イ)',
              'pages': [56],
              'url':
                  'https://www.mext.go.jp/component/a_menu/education/'
                  'micro_detail/__icsFiles/afieldfile/2019/03/18/'
                  '1387018_005.pdf',
            },
          ],
          'prerequisites': ['first'],
          'difficulty': 1,
          'safety': {
            'level': 'referenceOnly',
            'guidance': 'テストfixtureでは観察を行わない。',
          },
        },
      ],
      'sectionCount': 2,
      'sections': [
        {
          'conceptKey': 'first',
          'title': '最初の教材',
          'body': ['最初の本文'],
          'tryIt': '最初の場面',
          'localCheckpoint': _checkpoint('first', 'science.first.foundation'),
          'localSpeakingPractice': {
            'targetPhrase': '最初の固定目標語句を声または文字で確認する',
            'acceptedTranscripts': ['最初の固定目標語句を声または文字で確認する'],
          },
          'localPracticeVariants': _practiceVariants('first'),
          'notationLab': _notationLab('first'),
          'scienceStory': _scienceStory('first'),
        },
        {
          'conceptKey': 'second',
          'title': '次の教材',
          'body': ['次の本文'],
          'tryIt': '次の場面',
          'localCheckpoint': _checkpoint('second', 'science.second.foundation'),
          'localSpeakingPractice': {
            'targetPhrase': '次の固定目標語句を声または文字で確認する',
            'acceptedTranscripts': ['次の固定目標語句を声または文字で確認する'],
          },
          'localPracticeVariants': _practiceVariants('second'),
          'notationLab': _notationLab('second'),
          'scienceStory': _scienceStory('second'),
        },
      ],
    },
  ],
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> reveal(WidgetTester tester, Finder target) async {
    final containingScrollables = find.ancestor(
      of: target,
      matching: find.byType(Scrollable),
    );
    final scrollable = containingScrollables.evaluate().isNotEmpty
        ? containingScrollables.first
        : find.byType(Scrollable).hitTestable().last;
    for (var i = 0; i < 60; i++) {
      if (target.hitTestable().evaluate().isNotEmpty) return;
      await tester.drag(scrollable, const Offset(0, -220));
      await tester.pump();
    }
    // 画面の後半を確認したあと、上へ移した主CTAへ戻るテストにも使う。
    // ListViewの遅延構築でfinder自体が一時的に0件でも、scrollableは操作できる。
    for (var i = 0; i < 60; i++) {
      if (target.hitTestable().evaluate().isNotEmpty) return;
      await tester.drag(scrollable, const Offset(0, 220));
      await tester.pump();
    }
    fail('操作対象を画面内へ出せませんでした: $target');
  }

  testWidgets('アプリ全体が端末の文字200%を1.6倍へ切り下げない', (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(DekisugiApp(store: MemorySessionStore()));
    await tester.pumpAndSettle();

    final pageContext = tester.element(find.byType(Scaffold).first);
    expect(MediaQuery.textScalerOf(pageContext).scale(10), 20);
    expect(Localizations.localeOf(pageContext).languageCode, 'ja');
    expect(
      MaterialLocalizations.of(pageContext).cancelButtonLabel,
      'キャンセル',
      reason: '日付・時刻選択や標準の戻る操作まで日本語で統一する',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('成人の端末内モードはpersonalの6タブPathを開き、外部Providerを持たない', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final semantics = tester.ensureSemantics();

    final store = MemorySessionStore();
    await tester.pumpWidget(
      DekisugiApp(
        store: store,
        localCatalogAssets: _JsonAssetBundle(_localCatalogJson),
      ),
    );
    await tester.pumpAndSettle();

    final localEntry = find.byKey(const ValueKey('use-local-only-mode'));
    await reveal(tester, localEntry);
    await tester.pump();
    expect(tester.getSize(localEntry).height, greaterThanOrEqualTo(48));
    expect(localEntry.hitTestable(), findsOneWidget);
    final localEntrySemantics = tester
        .getSemantics(localEntry)
        .getSemanticsData();
    expect(localEntrySemantics.label, '通信しない端末内モードを使う');
    expect(localEntrySemantics.hasAction(SemanticsAction.tap), isTrue);
    expect(localEntrySemantics.flagsCollection.isButton, isTrue);
    expect(localEntrySemantics.flagsCollection.isEnabled, Tristate.isTrue);
    await tester.tap(localEntry);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game-tab-guide')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('game-tab-guide-dismiss')));
    await tester.pumpAndSettle();

    final localHome = find.byType(ScienceGameHomeScreen);
    expect(localHome, findsOneWidget);
    final screen = tester.widget<ScienceGameHomeScreen>(localHome);
    expect(screen.scope, LearningScope.personal);
    expect(screen.schoolMode, isFalse);
    expect(screen.lanSocialAllowed, isFalse);
    expect(screen.units.baseUrl, isEmpty);
    expect(screen.units.isConfigured, isFalse);
    expect(screen.legacyProgress, isNotNull);
    expect(find.byKey(const ValueKey('league-open-lan-social')), findsNothing);
    for (final tab in ['path', 'stories', 'practice', 'league', 'profile']) {
      expect(find.byKey(ValueKey('game-tab-$tab')), findsOneWidget);
    }

    // 端末内サブツリーからは外部サービスを取得できない。Providerがlazyな
    // だけでなく、祖先に存在しないことを回帰テストにする。
    final localContext = tester.element(localHome);
    expect(
      () => Provider.of<DeviceIdentity>(localContext, listen: false),
      throwsA(isA<ProviderNotFoundException>()),
    );
    expect(
      () => Provider.of<PurchaseService>(localContext, listen: false),
      throwsA(isA<ProviderNotFoundException>()),
    );
    expect(
      () => Provider.of<TeamClient>(localContext, listen: false),
      throwsA(isA<ProviderNotFoundException>()),
    );
    expect(
      () => Provider.of<SubscriptionSyncClient>(localContext, listen: false),
      throwsA(isA<ProviderNotFoundException>()),
    );

    expect(await ConsentStore(store).load(), isNull);
    expect(await store.getSetting('device_id'), isNull);
    expect(await store.getSetting('device_token'), isNull);
    expect(await store.getSetting('device_token_exp'), isNull);
    expect(
      await store.getSetting(LocalPracticeStore.settingKey),
      isNull,
      reason: 'まだcheckpointを終えていないため練習済みの印も無い',
    );

    final lessonId = GamePathProjection.nodeId(
      'local-unit',
      'first',
      GamePathNodeKind.lesson,
    );
    final node = find.byKey(ValueKey<String>('game-path-node-$lessonId'));
    final pathScroll = find.descendant(
      of: find.byKey(const PageStorageKey<String>('game-learning-path')),
      matching: find.byType(Scrollable),
    );
    for (var attempt = 0; attempt < 20; attempt++) {
      if (node.hitTestable().evaluate().isNotEmpty) break;
      await tester.drag(pathScroll, const Offset(0, -160));
      await tester.pump();
    }
    expect(node.hitTestable(), findsOneWidget);
    await tester.tap(node);
    await tester.pumpAndSettle();
    final start = find.byKey(const ValueKey('game-node-sheet-start'));
    final sheet = find.byKey(const ValueKey('game-node-sheet'));
    for (var attempt = 0; attempt < 20; attempt++) {
      if (start.hitTestable().evaluate().isNotEmpty) break;
      await tester.drag(sheet, const Offset(0, -220));
      await tester.pump();
    }
    expect(start.hitTestable(), findsOneWidget);
    await tester.tap(start);
    await tester.pumpAndSettle();
    expect(find.byType(ScienceLessonScreen), findsOneWidget);
    expect(find.text('最初の本文'), findsNothing, reason: '予想の前に教材本文を見せない');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-tab-profile')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('game-profile-open-lan-social')),
      findsNothing,
      reason: '成人personalでも通信しない端末内ツリーには入口を出さない',
    );
    await tester.tap(find.byKey(const ValueKey('game-profile-settings')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    final exit = find.byKey(const ValueKey('game-profile-exit-local-mode'));
    await reveal(tester, exit);
    expect(tester.getSize(exit).height, greaterThanOrEqualTo(48));
    await tester.tap(exit);
    await tester.pumpAndSettle();
    expect(find.byType(ConsentScreen), findsOneWidget);

    expect(await ConsentStore(store).load(), isNull);
    expect(await store.getSetting('device_id'), isNull);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('18歳未満の本人端末内はpersonal game機構へ到達し、外部Providerを持たない', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final semantics = tester.ensureSemantics();

    final store = MemorySessionStore();
    await tester.pumpWidget(
      DekisugiApp(
        store: store,
        localCatalogAssets: _JsonAssetBundle(_localCatalogJson),
      ),
    );
    await tester.pumpAndSettle();
    final under16 = find.text('15歳以下');
    await reveal(tester, under16);
    await tester.tap(under16);
    await tester.pumpAndSettle();
    final localEntry = find.byKey(const ValueKey('use-local-only-mode'));
    await reveal(tester, localEntry);
    await tester.tap(localEntry);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game-tab-guide')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('game-tab-guide-dismiss')));
    await tester.pumpAndSettle();

    final localHome = find.byType(ScienceGameHomeScreen);
    expect(localHome, findsOneWidget);
    final screen = tester.widget<ScienceGameHomeScreen>(localHome);
    expect(screen.scope, LearningScope.personal);
    expect(screen.schoolMode, isFalse);
    expect(screen.lanSocialAllowed, isFalse);
    expect(screen.legacyProgress, isNotNull);
    expect(find.byKey(const ValueKey('player-status-streak')), findsOneWidget);
    expect(find.byKey(const ValueKey('player-status-gems')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('お休みの日の保護、[0-9]+回分')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('試行余力、5枠中[0-5]枠')), findsOneWidget);

    final path = tester.widget<PathScreen>(find.byType(PathScreen));
    expect(
      path.data.quests.map((quest) => quest.kind),
      containsAll(<GameQuestKind>[GameQuestKind.daily, GameQuestKind.monthly]),
    );
    final localContext = tester.element(localHome);
    for (final lookup in <Object? Function()>[
      () => Provider.of<DeviceIdentity>(localContext, listen: false),
      () => Provider.of<PurchaseService>(localContext, listen: false),
      () => Provider.of<TeamClient>(localContext, listen: false),
      () => Provider.of<SubscriptionSyncClient>(localContext, listen: false),
    ]) {
      expect(lookup, throwsA(isA<ProviderNotFoundException>()));
    }

    await tester.tap(find.byKey(const ValueKey('player-status-gems')));
    await tester.pumpAndSettle();
    expect(
      find.byType(GameEconomySheet),
      findsOneWidget,
      reason: '結晶の用途へ到達できる',
    );
    expect(find.byKey(const ValueKey('economy-freeze-item')), findsOneWidget);
    expect(find.byKey(const ValueKey('economy-hearts-item')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('game-tab-profile')));
    await tester.pumpAndSettle();
    final profile = tester.widget<GameProfileScreen>(
      find.byType(GameProfileScreen),
    );
    expect(profile.schoolMode, isFalse);
    expect(profile.onOpenEconomy, isNotNull);
    expect(profile.onStartLocalCoop, isNotNull, reason: '同じ端末の実参加者Questを使える');
    expect(
      find.byKey(const ValueKey('game-profile-monthly-badges')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('game-tab-league')));
    await tester.pumpAndSettle();
    final league = tester.widget<LeagueScreen>(find.byType(LeagueScreen));
    expect(league.schoolMode, isFalse);
    expect(league.onOpenLanSocial, isNull);
    expect(
      league.onStartLocalWeeklyLeague,
      isNotNull,
      reason: '外部LANなしで同端末の実参加者リーグを開始できる',
    );

    expect(await ConsentStore(store).load(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      DekisugiApp(
        store: store,
        localCatalogAssets: _JsonAssetBundle(_localCatalogJson),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ConsentScreen), findsOneWidget);
    expect(
      find.byType(ScienceGameHomeScreen),
      findsNothing,
      reason: '年齢と本人/学校の選択は未永続なので、再起動時に推測移行しない',
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('学校チェックの端末内だけschoolLocalへ分離し、授業入口と無報酬UIを出す', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final semantics = tester.ensureSemantics();

    final store = MemorySessionStore();
    final personalBefore = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    await LocalPracticeStore(store).recordCompletion(
      unitId: 'local-unit',
      conceptKey: 'first',
      completedAt: DateTime.utc(2026, 8, 9),
    );
    await tester.pumpWidget(
      DekisugiApp(
        store: store,
        localCatalogAssets: _JsonAssetBundle(_localCatalogJson),
      ),
    );
    await tester.pumpAndSettle();
    final under16 = find.text('15歳以下');
    await reveal(tester, under16);
    await tester.tap(under16);
    await tester.pumpAndSettle();
    final next = find.byKey(const ValueKey('consent-next'));
    await reveal(tester, next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    final schoolEntry = find.text('学校からもらって使います');
    await reveal(tester, schoolEntry);
    await tester.tap(schoolEntry);
    await tester.pumpAndSettle();
    final localEntry = find.byKey(const ValueKey('use-local-only-mode'));
    await reveal(tester, localEntry);
    await tester.tap(localEntry);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game-tab-guide')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('game-tab-guide-dismiss')));
    await tester.pumpAndSettle();
    final schoolHome = find.byType(ScienceGameHomeScreen);
    expect(schoolHome, findsOneWidget);
    final screen = tester.widget<ScienceGameHomeScreen>(schoolHome);
    expect(screen.scope, LearningScope.schoolLocal);
    expect(screen.schoolMode, isTrue);
    expect(screen.lanSocialAllowed, isFalse);
    expect(screen.legacyProgress, isNull, reason: '個人の旧完了を学校Pathへ混ぜない');
    expect(find.byKey(const ValueKey('league-open-lan-social')), findsNothing);
    expect(find.byKey(const ValueKey('player-status-streak')), findsNothing);
    expect(find.byKey(const ValueKey('player-status-gems')), findsNothing);
    expect(find.bySemanticsLabel(RegExp('試行、無制限')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('game-tab-profile')));
    await tester.pumpAndSettle();
    final initialSchoolProfile = tester.widget<GameProfileScreen>(
      find.byType(GameProfileScreen),
    );
    expect(initialSchoolProfile.onOpenEconomy, isNull);
    expect(initialSchoolProfile.onStartLocalCoop, isNull);
    expect(
      find.byKey(const ValueKey('game-profile-open-lan-social')),
      findsNothing,
      reason: '学校local-onlyからLAN socialへ到達させない',
    );
    expect(find.text('連続学習'), findsNothing);
    expect(find.text('結晶'), findsNothing);
    final classroom = find.byKey(const ValueKey('game-profile-open-classroom'));
    await reveal(tester, classroom);
    expect(tester.getSize(classroom).height, greaterThanOrEqualTo(48));
    await tester.tap(classroom);
    await tester.pumpAndSettle();
    expect(find.byType(LocalClassroomScreen), findsOneWidget);
    final classroomScroll = find.descendant(
      of: find.byType(LocalClassroomScreen),
      matching: find.byType(Scrollable),
    );
    final number = find.byKey(const ValueKey('local-classroom-number'));
    for (
      var attempt = 0;
      attempt < 20 && number.evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(classroomScroll, const Offset(0, -180));
      await tester.pump();
    }
    expect(number, findsOneWidget);

    final classroomWidget = tester.widget<LocalClassroomScreen>(
      find.byType(LocalClassroomScreen),
    );
    expect(classroomWidget.onAssignmentCompleted, isNotNull);
    final missions = ClassroomMission.fromUnits(
      await classroomWidget.units.list(),
    );
    final assignment = ClassroomAssignment(
      mission: missions.first,
      round: ClassroomRound.a,
    );
    final completedAt = DateTime.now();
    await classroomWidget.onAssignmentCompleted!.call(assignment, completedAt);
    await classroomWidget.onAssignmentCompleted!.call(assignment, completedAt);

    final school = await store.learningProgressSnapshot(
      LearningScope.schoolLocal,
    );
    expect(school.events, hasLength(1), reason: '同じ授業・同じ学習日は1 event');
    final event = school.events.single;
    expect(event.scope, LearningScope.schoolLocal);
    expect(event.origin, LearningOrigin.schoolAssignment);
    expect(event.evidence, LearningEvidenceLevel.selfCompared);
    expect(event.nodeId, 'classroom:v1:local-unit:first:round-a');
    expect(school.rewards, isEmpty);
    final eventMetadata = [
      event.eventId,
      event.courseId,
      event.nodeId,
      event.activityId,
      event.contentVersion,
    ].join('|');
    expect(eventMetadata, isNot(contains('最初の本文')));
    expect(eventMetadata, isNot(contains('正しい説明')));

    final personalAfter = await store.learningProgressSnapshot(
      LearningScope.personal,
    );
    expect(personalAfter.events, hasLength(personalBefore.events.length));
    expect(personalAfter.nodes, hasLength(personalBefore.nodes.length));
    expect(personalAfter.wallet.xp, personalBefore.wallet.xp);
    expect(personalAfter.wallet.gems, personalBefore.wallet.gems);
    expect(
      personalAfter.challengeHearts?.current,
      personalBefore.challengeHearts?.current,
    );

    final classroomContext = tester.element(find.byType(LocalClassroomScreen));
    for (final lookup in <Object? Function()>[
      () => Provider.of<DeviceIdentity>(classroomContext, listen: false),
      () => Provider.of<PurchaseService>(classroomContext, listen: false),
      () => Provider.of<TeamClient>(classroomContext, listen: false),
      () =>
          Provider.of<SubscriptionSyncClient>(classroomContext, listen: false),
    ]) {
      expect(lookup, throwsA(isA<ProviderNotFoundException>()));
    }

    // onRunChangedを直接呼ばずrouteを閉じる。Gateがpush完了後に公開controller
    // からsnapshotを再読込し、共同目標とPathを即時更新する契約を確認する。
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    final profile = tester.widget<GameProfileScreen>(
      find.byType(GameProfileScreen),
    );
    expect(profile.quests.single.progress, 1);
    expect(profile.quests.single.target, 1);
    expect(profile.quests.single.gemReward, 0);
    await tester.tap(find.byKey(const ValueKey('game-tab-league')));
    await tester.pumpAndSettle();
    final league = tester.widget<LeagueScreen>(find.byType(LeagueScreen));
    expect(league.classCompleted, 1);
    expect(league.classTarget, 1);
    expect(league.onStartLocalWeeklyLeague, isNull);
    expect(find.text('この端末の観察目標'), findsOneWidget);
    expect(find.text('クラス共同ミッション'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('game-tab-path')));
    await tester.pumpAndSettle();
    final path = tester.widget<PathScreen>(find.byType(PathScreen));
    expect(path.data.quests.single.current, 1);
    expect(path.data.quests.single.target, 1);
    expect(
      path.data.units
          .expand((unit) => unit.nodes)
          .any((node) => node.id == event.nodeId),
      isFalse,
      reason: '学校assignmentをPath必修nodeのclearへ流用しない',
    );
    expect(
      path.data.units.first.nodes.first.state,
      GamePathNodeState.available,
    );

    expect(await ConsentStore(store).load(), isNull);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('有効な成人同意はProvider境界内のオンライン6タブへ進み、設定を保持する', (tester) async {
    final store = MemorySessionStore();
    await ConsentStore(store).save(
      ConsentRecord(
        ageBand: AgeBand.adult,
        guardianPresent: null,
        transferAgreed: true,
        agreedAt: DateTime(2026, 8, 10),
        version: kConsentVersion,
        route: ConsentRoute.self,
      ),
    );

    // URLを空にするのはテストだけ。Provider配線と同梱fallbackを、実通信を
    // 発生させずに確認する。
    await tester.pumpWidget(
      DekisugiApp(
        store: store,
        serverUrl: '',
        localCatalogAssets: _JsonAssetBundle(_localCatalogJson),
      ),
    );
    final home = find.byType(ScienceGameHomeScreen);
    for (var i = 0; i < 10 && home.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    for (
      var i = 0;
      i < 30 &&
          find.byKey(const ValueKey('game-tab-profile')).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(home, findsOneWidget);
    final game = tester.widget<ScienceGameHomeScreen>(home);
    expect(game.scope, LearningScope.personal);
    expect(game.schoolMode, isFalse);
    expect(game.lanSocialAllowed, isTrue);
    expect(game.legacyProgress, isNotNull);
    final context = tester.element(home);
    expect(
      Provider.of<DeviceIdentity>(context, listen: false).baseUrl,
      isEmpty,
    );
    expect(
      Provider.of<UnitsClient>(context, listen: false).isConfigured,
      isFalse,
    );
    expect(
      Provider.of<PurchaseService>(context, listen: false),
      isA<PurchaseService>(),
    );
    expect(Provider.of<TeamClient>(context, listen: false), isA<TeamClient>());
    expect(
      Provider.of<SubscriptionSyncClient>(context, listen: false),
      isA<SubscriptionSyncClient>(),
    );
    expect(
      await store.getSetting('device_id'),
      isNull,
      reason: 'Provider生成だけではIDを作らない',
    );

    await tester.tap(find.byKey(const ValueKey('game-tab-profile')));
    await tester.pumpAndSettle();
    final social = find.byKey(const ValueKey('game-profile-open-lan-social'));
    await reveal(tester, social);
    expect(social, findsOneWidget);
    expect(tester.getSize(social).height, greaterThanOrEqualTo(48));
    await tester.tap(social);
    await tester.pumpAndSettle();
    expect(find.byType(LanSocialScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-tab-league')));
    await tester.pumpAndSettle();
    final leagueSocial = find.byKey(const ValueKey('league-open-lan-social'));
    await reveal(tester, leagueSocial);
    expect(leagueSocial, findsOneWidget);
    expect(tester.getSize(leagueSocial).height, greaterThanOrEqualTo(48));
    expect(find.text('実参加者の共同観測'), findsOneWidget);
    expect(find.textContaining('5人未満では順位も人数も表示しません'), findsOneWidget);
    expect(find.textContaining('観測級01から観測級10までの10段階'), findsOneWidget);
    expect(find.byKey(const ValueKey('league-progress')), findsNothing);
    expect(
      find.byKey(const ValueKey('local-weekly-league-panel')),
      findsNothing,
      reason: 'onlineでは旧4段tier・端末手渡し代替を第二のleagueとして混ぜない',
    );
    await tester.tap(leagueSocial);
    await tester.pumpAndSettle();
    expect(find.byType(LanSocialScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('game-tab-profile')));
    await tester.pumpAndSettle();
    final settings = find.byKey(const ValueKey('game-profile-settings'));
    await reveal(tester, settings);
    await tester.tap(settings);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
