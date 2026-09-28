import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/env.dart';
import 'package:dekisugi/models/dossier.dart';
import 'package:dekisugi/models/mission.dart';
import 'package:dekisugi/models/unit.dart';
import 'package:dekisugi/screens/offline_practice_screen.dart';
import 'package:dekisugi/screens/talk_screen.dart';
import 'package:dekisugi/services/live_session.dart';
import 'package:dekisugi/services/pcm_player.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:dekisugi/services/units_client.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/quota_view.dart';
import 'package:dekisugi/widgets/session_complete.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'support/fake_live.dart';
import 'support/live_fakes.dart';

class _TalkController extends LiveSessionController {
  _TalkController({required MemorySessionStore store, required FakeMic mic})
    : super(
        unitId: 'force-motion',
        focusConceptKey: 'fall',
        tactic: TeachingTactic.example,
        tokens: FakeTokens(grantFor(1)),
        store: store,
        mic: mic,
        player: PcmPlayer(sink: FakeSink()),
      );

  bool running = true;
  LiveState current = LiveState.listening;
  LiveState? stoppedTo;
  bool saveFailed = false;
  bool saving = false;
  LiveFailure? currentFailure;
  int refreshCalls = 0;
  final sentTexts = <String>[];

  void addTurn(Utterance utterance) {
    transcript.add(utterance);
    notifyListeners();
  }

  void setDossier(Dossier value) {
    dossier = value;
    notifyListeners();
  }

  @override
  bool get isRunning => running;

  @override
  bool get isActive => current == LiveState.connecting || running;

  @override
  bool get hasMic => running;

  @override
  LiveState get state => current;

  @override
  LiveFailure? get failure => currentFailure;

  @override
  bool get completionSaveFailed => saveFailed;

  @override
  bool get completionSaveInProgress => saving;

  @override
  Future<void> refreshQuota() async {
    refreshCalls++;
  }

  @override
  Future<bool> sendStudentText(String text) async {
    sentTexts.add(text);
    return true;
  }

  @override
  Future<void> stop({LiveState to = LiveState.idle}) async {
    stoppedTo = to;
    running = false;
    current = to;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMic mic;
  late MemorySessionStore store;
  late _TalkController live;

  setUp(() async {
    mic = FakeMic();
    store = MemorySessionStore();
    final id = await store.startSession(
      'force-motion',
      focusConceptKey: 'fall',
      tactic: TeachingTactic.example,
    );
    await store.saveProgress(
      id,
      transcript: const [
        Utterance(id: 'u01', isStudent: true, text: '重さは関係ない'),
      ],
    );
    live = _TalkController(store: store, mic: mic);
  });

  tearDown(() async {
    await live.dispose();
  });

  Widget wrap({
    double textScale = 1,
    double bottomInset = 0,
    Future<void> Function()? onOpenPlus,
    Section? offlineSection,
    MissionKind offlineMissionKind = MissionKind.teach,
  }) => MultiProvider(
    providers: [
      ChangeNotifierProvider<LiveSessionController>.value(value: live),
      Provider<SessionStore>.value(value: store),
      Provider<UnitsClient>.value(
        value: UnitsClient(baseUrl: '', store: store),
      ),
    ],
    child: MaterialApp(
      theme: buildAppTheme(Brightness.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          viewInsets: EdgeInsets.only(bottom: bottomInset),
        ),
        child: child!,
      ),
      home: TalkScreen(
        unitTitle: '力と運動',
        conceptLabel: '落下の速さ',
        onOpenPlus: onOpenPlus,
        offlineSection: offlineSection,
        offlineMissionKind: offlineMissionKind,
      ),
    ),
  );

  const offlineSection = Section(
    conceptKey: 'fall',
    title: '落下の速さ',
    body: ['空気抵抗を無視すると、重さに関係なく同じ加速度で落ちる。'],
    tryIt: '真空で重い球と軽い球を同時に落とすとどうなる？',
    localCheckpoint: LocalCheckpoint(
      lure: '空気がなくても重い球が先に着く。',
      options: [
        LocalCheckpointOption(id: 'correct', text: '同時に着く。'),
        LocalCheckpointOption(id: 'wrong-1', text: '重い球。', hint: '重さを見直す。'),
        LocalCheckpointOption(id: 'wrong-2', text: '軽い球。', hint: '重さを見直す。'),
      ],
      correctOptionId: 'correct',
      explanation: '落下加速度は重さによらない。',
    ),
  );

  testWidgets('接続失敗かつ焦点教材がある時だけ端末内練習へroute replacementする', (tester) async {
    live
      ..running = false
      ..current = LiveState.failed
      ..currentFailure = LiveFailure.network;
    await tester.pumpWidget(
      wrap(
        offlineSection: offlineSection,
        offlineMissionKind: MissionKind.repair,
      ),
    );
    await tester.pumpAndSettle();

    final cta = find.byKey(const ValueKey('continue-offline-practice'));
    await tester.scrollUntilVisible(
      cta,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(cta);
    await tester.pump();
    expect(cta.hitTestable(), findsOneWidget);
    expect(tester.getSize(cta).height, greaterThanOrEqualTo(48));

    await tester.tap(cta);
    await tester.pumpAndSettle();

    expect(
      find.byType(TalkScreen),
      findsNothing,
      reason: 'Talkを残すと接続や教材経路が重なる',
    );
    final practice = tester.widget<OfflinePracticeScreen>(
      find.byType(OfflinePracticeScreen),
    );
    expect(practice.section, same(offlineSection));
    expect(practice.conceptLabel, '落下の速さ');
    expect(practice.missionKind, MissionKind.repair);
  });

  testWidgets('通常状態・マイク拒否・焦点教材なしでは端末内練習を出さない', (tester) async {
    live
      ..running = false
      ..current = LiveState.idle
      ..currentFailure = null;
    await tester.pumpWidget(wrap(offlineSection: offlineSection));
    await tester.pump();
    expect(find.text('端末内で練習を続ける'), findsNothing);

    live
      ..current = LiveState.failed
      ..currentFailure = LiveFailure.noPermission
      ..notifyListeners();
    await tester.pump();
    expect(
      find.text('端末内で練習を続ける'),
      findsNothing,
      reason: 'マイク拒否時は既存の文字Live経路を使える',
    );

    await tester.pumpWidget(wrap());
    await tester.pump();
    live
      ..currentFailure = LiveFailure.network
      ..notifyListeners();
    await tester.pump();
    expect(find.text('端末内で練習を続ける'), findsNothing);
  });

  testWidgets('接続先未設定buildも焦点教材があれば端末内練習を出す', (tester) async {
    // 通常の全テストは公開接続先を既定値で持つ。専用コマンド
    // `flutter test --dart-define=SERVER_URL= test/talk_safety_test.dart`
    // ではこの分岐を実際に描画して検証する。
    if (Env.hasServer) return;

    await tester.pumpWidget(wrap(offlineSection: offlineSection));
    await tester.pumpAndSettle();

    expect(find.text('会話の接続先を確認できません'), findsOneWidget);
    expect(find.textContaining('あとでもう一度お試しください'), findsOneWidget);
    expect(find.textContaining('--dart-define'), findsNothing);
    final cta = find.byKey(const ValueKey('continue-offline-practice'));
    await tester.scrollUntilVisible(
      cta,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(cta);
    expect(cta.hitTestable(), findsOneWidget);
    await tester.tap(cta);
    await tester.pumpAndSettle();
    expect(find.byType(OfflinePracticeScreen), findsOneWidget);
  });

  testWidgets('会話中は復習教材を開けず、中断の意味を明示する', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(live.isRunning, isTrue);
    expect(
      find.byIcon(Icons.bookmarks_outlined),
      findsNothing,
      reason: '教材を見ながら説明できるとC2が破れる',
    );
    expect(find.byTooltip('いったんやめる'), findsOneWidget);
    expect(find.byTooltip('終わる'), findsNothing);
    expect(find.text('いったんやめる'), findsOneWidget);
    expect(find.text('おわる'), findsNothing);
  });

  testWidgets('会話ツールではなく、現在の学習ミッションを最初から示す', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.textContaining('MISSION 1/3'), findsOneWidget);
    expect(find.text('まず、自分の言葉で教える'), findsOneWidget);
    expect(find.textContaining('身近な例から'), findsOneWidget);

    live.setDossier(
      Dossier(
        unitId: 'force-motion',
        slots: [
          Slot(
            key: 'fall',
            label: '落下の速さ',
            status: SlotStatus.explained,
            content: '',
            evidence: const ['u01'],
            followUpHint: '',
            probes: const [],
          ),
        ],
        coverage: 100,
      ),
    );
    await tester.pump();

    expect(find.textContaining('MISSION 2/3'), findsOneWidget);
    expect(find.text('デキすぎ君の思い込みを見破る'), findsOneWidget);
  });

  testWidgets('作戦の書き出しは下書きに入るだけで、自動送信しない', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();
    final turnsBefore = live.transcript.length;

    await tester.tap(find.widgetWithText(ActionChip, 'たとえば、'));
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'たとえば、',
    );
    expect(live.transcript.length, turnsBefore, reason: '考える前に定型文を回答として送っている');
  });

  testWidgets('手動の「いったんやめる」は完了扱いにしない', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    await tester.tap(find.byTooltip('いったんやめる'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'いったんやめる'),
      ),
    );
    await tester.pumpAndSettle();

    expect(live.stoppedTo, LiveState.idle);
    expect(live.stoppedTo, isNot(LiveState.done));
    expect(await store.unfinished(), isNotNull);
  });

  testWidgets('自動完了後は入力欄を消して成果画面を一度だけ出す', (tester) async {
    live
      ..running = false
      ..current = LiveState.done;
    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.byType(SessionCompleteView), findsOneWidget);
    expect(find.text('教えてくれて、ありがとう。'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('声ではなす'), findsNothing);
  });

  testWidgets('完了保存に失敗したとき、システムBackでも損失を明示する', (tester) async {
    live
      ..running = false
      ..current = LiveState.done
      ..saveFailed = true;
    await tester.pumpWidget(wrap());
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('保存せずホームへ戻りますか？'), findsOneWidget);
    expect(find.text('保存をやり直す'), findsOneWidget);
    expect(find.text('保存せず戻る'), findsOneWidget);
  });

  testWidgets('きょうの枠を使い切った後は開始操作を出さない', (tester) async {
    live
      ..running = false
      ..current = LiveState.outOfTime;
    await tester.pumpWidget(wrap());
    await tester.pump();

    expect(find.textContaining('きょうのぶんは終わり'), findsWidgets);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('声ではなす'), findsNothing);
  });

  testWidgets('Plus画面から戻ると、購入の有無を自己申告せずサーバー枠を再取得する', (tester) async {
    var opens = 0;
    live
      ..running = false
      ..current = LiveState.outOfTime;
    await tester.pumpWidget(
      wrap(
        onOpenPlus: () async {
          opens++;
        },
      ),
    );
    await tester.pump();
    final initialRefreshes = live.refreshCalls;

    await tester.scrollUntilVisible(
      find.text('Plusで会話回数を広げる'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    final plusButton = find.text('Plusで会話回数を広げる');
    expect(plusButton, findsOneWidget);
    await tester.ensureVisible(plusButton);
    await tester.pumpAndSettle();
    expect(plusButton, findsOneWidget);
    await tester.tap(plusButton);
    await tester.pumpAndSettle();

    expect(opens, 1);
    expect(live.refreshCalls, initialRefreshes + 1);
  });

  testWidgets('枠が戻るまでは、保存済み会話の再開をno-opで出さない', (tester) async {
    live
      ..running = false
      ..current = LiveState.outOfTime;
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('前回の続きがあります'), findsOneWidget);
    expect(find.textContaining('回数が戻るまで'), findsOneWidget);
    expect(find.text('続きから'), findsNothing);
  });

  testWidgets('保存済み会話を捨てる前に、結果を明示して確認する', (tester) async {
    live
      ..running = false
      ..current = LiveState.idle;
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('この会話を捨てる'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -100));
    await tester.pump();
    await tester.tap(find.text('この会話を捨てる'));
    await tester.pumpAndSettle();
    expect(find.text('この会話を捨てますか？'), findsOneWidget);
    expect(find.text('会話を残す'), findsOneWidget);
    expect(await store.unfinished(), isNotNull);

    await tester.tap(find.text('会話を残す'));
    await tester.pumpAndSettle();
    expect(await store.unfinished(), isNotNull);
  });

  testWidgets('バックグラウンドへ移ると録音と接続を止め、続きとして残す', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();
    expect(live.isRunning, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    // paused のままではテストbinding自体がフレームを描かない。
    // 実装には停止イベントが同期で届いているので、描画だけ再開して
    // その後のmicrotaskをpumpする
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(live.isRunning, isFalse);
    expect(live.hasMic, isFalse, reason: '画面が見えない間も録音している');
    expect(await store.unfinished(), isNotNull, reason: '中断した会話が失われている');
    expect(find.textContaining('前回の続きがあります'), findsOneWidget);
    expect(find.byType(TextField), findsNothing, reason: '「続きから」を通らず新規接続できる');
    expect(find.text('声ではなす'), findsNothing);
  });

  testWidgets('接続待ちのまま背景へ移っても停止する', (tester) async {
    live
      ..running = false
      ..current = LiveState.connecting;
    await tester.pumpWidget(wrap());
    await tester.pump();
    expect(live.isActive, isTrue);
    expect(
      tester.widget<TextField>(find.byType(TextField)).enabled,
      isFalse,
      reason: '接続待ちで送ると入力文が受理されず消える',
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(live.stoppedTo, LiveState.idle);
    expect(live.state, LiveState.idle);
  });

  testWidgets('OS権限ダイアログのinactiveだけでは初回接続を止めない', (tester) async {
    live
      ..running = false
      ..current = LiveState.connecting;
    await tester.pumpWidget(wrap());
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();

    expect(live.stoppedTo, isNull);
    expect(live.state, LiveState.connecting);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('320dp・文字200%でも会話の停止操作まで使える', (tester) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(textScale: 2));
    await tester.pump();

    expect(find.byTooltip('いったんやめる'), findsOneWidget);
    expect(find.text('いったんやめる'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320dp・文字200%でも残り回数をAppBar内で読める', (tester) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    live.remainingSessions = 2;

    await tester.pumpWidget(wrap(textScale: 2));
    await tester.pump();

    expect(find.text('あと2回'), findsOneWidget);
    expect(
      tester.getSize(find.byType(QuotaChip)).height,
      greaterThanOrEqualTo(32),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('小画面・文字200%・キーボード表示でも操作面の全操作へ到達できる', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(textScale: 2, bottomInset: 280));
    await tester.pump();

    final composer = find.byType(SingleChildScrollView);
    final composerScrollable = find.descendant(
      of: composer,
      matching: find.byType(Scrollable),
    );
    expect(composer, findsOneWidget);
    expect(composerScrollable, findsWidgets);
    final composerScrollState = tester
        .stateList<ScrollableState>(composerScrollable)
        .singleWhere((state) => state.position.maxScrollExtent > 0);
    expect(
      composerScrollState.position.maxScrollExtent,
      greaterThan(0),
      reason: '狭い表示領域ではcomposer内だけをスクロールできる必要がある',
    );

    final starter = find.widgetWithText(ActionChip, 'たとえば、');
    await tester.ensureVisible(starter);
    await tester.pump();
    expect(starter.hitTestable(), findsOneWidget);
    await tester.tap(starter);
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      'たとえば、',
    );

    final input = find.byType(TextField);
    await tester.ensureVisible(input);
    await tester.pump();
    expect(input.hitTestable(), findsOneWidget);
    const answer = '一行目\n二行目\n三行目\n四行目';
    await tester.enterText(input, answer);
    await tester.pump();

    expect(tester.takeException(), isNull);

    final send = find.byTooltip('送る');
    await tester.ensureVisible(send);
    await tester.pump();
    expect(send.hitTestable(), findsOneWidget);
    expect(
      composerScrollState.position.pixels,
      greaterThan(0),
      reason: '固定距離ではなくcomposer自身が操作まで実際にスクロールしている',
    );
    await tester.tap(send);
    await tester.pump();
    expect(live.sentTexts, [answer]);

    final pause = find.widgetWithText(OutlinedButton, 'いったんやめる');
    await tester.ensureVisible(pause);
    await tester.pump();
    expect(pause.hitTestable(), findsOneWidget);

    await tester.ensureVisible(starter);
    await tester.pump();
    expect(
      starter.hitTestable(),
      findsOneWidget,
      reason: '下端から導入ヒントへも戻れる必要がある',
    );
  });

  testWidgets('小画面・文字200%・キーボード表示中も中断確認が溢れない', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(textScale: 2, bottomInset: 280));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '考えを書いている途中');

    // 入力中はcaretを見せるためcomposerがTextFieldへ戻る。常に見える
    // AppBar側の中断操作から、キーボード上の確認面を検証する。
    final pause = find.byTooltip('いったんやめる');
    expect(pause.hitTestable(), findsOneWidget);
    await tester.tap(pause);
    await tester.pumpAndSettle();

    expect(find.text('いったんやめますか？'), findsOneWidget);
    expect(find.text('つづける').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('最初の発話が届くと最新の会話へ追従する', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    for (var i = 0; i < 12; i++) {
      live.addTurn(
        Utterance(
          id: 'turn-$i',
          isStudent: i.isEven,
          text: i == 11 ? 'いちばん新しい問い' : '会話の本文を少し長く表示します $i',
        ),
      );
    }
    await tester.pumpAndSettle();

    expect(find.text('いちばん新しい問い').hitTestable(), findsOneWidget);
  });

  testWidgets('過去の会話を読んでいる間は位置を奪わず、新着へ戻れる', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();

    for (var i = 0; i < 14; i++) {
      live.addTurn(
        Utterance(
          id: 'history-$i',
          isStudent: i.isEven,
          text: '読み返せる長さの会話をここに残します $i',
        ),
      );
    }
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pump();

    live.addTurn(
      const Utterance(id: 'newest', isStudent: false, text: '新しく届いた問いです'),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('新しい会話'), findsOneWidget);
    expect(find.text('新しく届いた問いです').hitTestable(), findsNothing);

    await tester.tap(find.text('新しい会話'));
    await tester.pumpAndSettle();
    expect(find.text('新しく届いた問いです').hitTestable(), findsOneWidget);
  });
}
