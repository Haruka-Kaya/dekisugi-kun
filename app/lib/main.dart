import 'dart:async';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'config/app_radius.dart';
import 'config/app_theme.dart';
import 'config/env.dart';
import 'config/motion.dart';
import 'learning/domain/learning_event.dart';
import 'models/classroom_mission.dart';
import 'models/mission.dart';
import 'models/team.dart';
import 'models/unit.dart';
import 'screens/consent_screen.dart';
import 'screens/home_screen.dart';
import 'screens/local_classroom_screen.dart';
import 'screens/material_screen.dart';
import 'screens/offline_practice_screen.dart';
import 'screens/plus_screen.dart';
import 'screens/review_screen.dart';
import 'screens/science_game_home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/unit_picker_screen.dart';
import 'widgets/session_store_bootstrap.dart';
import 'screens/talk_screen.dart';
import 'services/consent.dart';
import 'services/classroom_learning_completion.dart';
import 'services/device_identity.dart';
import 'services/director_client.dart';
import 'services/live_session.dart';
import 'services/live_token_client.dart';
import 'services/local_classroom_run_store.dart';
import 'services/local_practice_schedule.dart';
import 'services/local_practice_store.dart';
import 'services/purchase_config.dart';
import 'services/purchase_service.dart';
import 'services/reminders.dart';
import 'services/revenuecat_purchase_adapter.dart';
import 'services/session_store.dart';
import 'services/subscription_sync_client.dart';
import 'services/team_client.dart';
import 'services/units_client.dart';
import 'ui/_material.dart';
import 'widgets/character.dart';
import 'widgets/readable_width.dart';
import 'widgets/studio_ui.dart';

/// 明暗テーマを固定して起動するための開発用スイッチ。
///
/// `flutter run --dart-define=FORCE_BRIGHTNESS=dark` のように使う。
/// 未指定なら端末の設定に従う（本番の挙動）。
const String _kForceBrightness = String.fromEnvironment(
  'FORCE_BRIGHTNESS',
  defaultValue: '',
);

ThemeMode get _themeMode => switch (_kForceBrightness) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

/// 会話の入れ物は**単元ごとに作る。**
///
/// 逐語も理解カルテも1つの単元の話なので、使い回すと前の単元の説明が
/// 次の単元のカルテに混ざる。単元を選んだ時点で作り、離れたら捨てる。
LiveSessionController _controllerFor(
  BuildContext context,
  String unitId, {
  String? focusConceptKey,
  TeachingTactic tactic = TeachingTactic.reason,
  MissionKind missionKind = MissionKind.teach,
}) {
  final store = context.read<SessionStore>();
  final identity = context.read<DeviceIdentity>();
  return LiveSessionController(
    unitId: unitId,
    focusConceptKey: focusConceptKey,
    tactic: tactic,
    missionKind: missionKind,
    store: store,
    // **APIキーは端末に無い。** 会話ごとにサーバから時間つきの資格情報をもらう
    tokens: LiveTokenClient(baseUrl: identity.baseUrl, identity: identity),
    director: DirectorClient(baseUrl: identity.baseUrl, identity: identity),
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 永続DBを開けた時だけ本編を構築する。保存失敗時にMemoryへ黙って
  // fallbackすると、獲得XPや学習Pathが再起動で全消失するため許可しない。
  runApp(
    SessionStoreBootstrap(
      openStore: openSessionStore,
      appBuilder: (store) => DekisugiApp(store: store),
    ),
  );
}

class DekisugiApp extends StatelessWidget {
  DekisugiApp({
    super.key,
    required this.store,
    this.serverUrl = Env.directorUrl,
    this.localCatalogAssets,
    RouteObserver<ModalRoute<void>>? routeObserver,
  }) : routeObserver = routeObserver ?? RouteObserver<ModalRoute<void>>();

  final SessionStore store;

  /// テストでは空にして、成人オンライン用Providerの配線を実通信なしで検証する。
  /// 本番エントリポイントは[Env.directorUrl]をそのまま使う。
  final String serverUrl;

  /// 端末内カタログのAssetBundle。未指定ならアプリ同梱[rootBundle]を使う。
  /// 小さい決定論fixtureで端末内E2Eを行うテストだけ差し替える。
  final AssetBundle? localCatalogAssets;

  /// Material → Talk はroute replacementなので、pushのFutureだけでは
  /// 復帰を追えない。アプリインスタンスごとに監視し、別テストや別ツリーの
  /// routeを混ぜない。
  final RouteObserver<ModalRoute<void>> routeObserver;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SessionStore>.value(value: store),
        Provider<ConsentStore>.value(value: ConsentStore(store)),
        Provider<Reminders>.value(value: Reminders(store: store)),
      ],
      child: MaterialApp(
        title: 'デキすぎ君',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ja'),
        supportedLocales: const [Locale('ja')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: buildAppTheme(Brightness.light),
        darkTheme: buildAppTheme(Brightness.dark),
        themeMode: _themeMode,
        navigatorObservers: [routeObserver],
        // Android 14 の最大200%まで端末設定を尊重する。
        // 主要画面は320dp・200%でスクロール可能なことをテストする。
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: 1.0,
          maxScaleFactor: 2.0,
          // 「動きを減らす」設定は Android と iOS で出所が違う。
          // ここで両方を1つにまとめて配る
          child: ReduceMotionScope(child: child ?? const SizedBox.shrink()),
        ),
        home: _Gate(
          serverUrl: serverUrl,
          localCatalogAssets: localCatalogAssets,
        ),
      ),
    );
  }
}

/// 同意を確かめてから会話画面へ入れる。
///
/// **同意の判定は毎回読み直す。** 「同意済み」を1つのフラグで持つと、
/// 文面の版を上げたときや条件を足したときに、古い記録が通り続ける。
class _Gate extends StatefulWidget {
  const _Gate({required this.serverUrl, required this.localCatalogAssets});

  final String serverUrl;
  final AssetBundle? localCatalogAssets;

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  final _localGameController = ScienceGameHomeController();
  ConsentRecord? _consent;
  UnitsClient? _localOnlyUnits;
  LocalPracticeStore? _localPractice;
  LocalClassroomRunStore? _localClassroomRun;
  LearningScope _localOnlyScope = LearningScope.personal;
  bool _loading = true;
  bool _showTabGuide = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final got = await context.read<ConsentStore>().load();
    if (!mounted) return;
    setState(() {
      _consent = got;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Character(state: LiveState.idle, size: 112),
              const SizedBox(height: 14),
              Text(
                '教える準備をしています',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.jaWeight(FontWeight.w700),
              ),
            ],
          ),
        ),
      );
    }
    if (_consent?.isValid == true) {
      return _OnlineServices(
        serverUrl: widget.serverUrl,
        localCatalogAssets: widget.localCatalogAssets,
        allowIndividualPurchases: _consent!.allowsIndividualPurchases,
        showTabGuide: _showTabGuide,
        onTabGuideDismissed: () => setState(() => _showTabGuide = false),
      );
    }
    if (_localOnlyUnits case final units?) {
      final store = context.read<SessionStore>();
      final progress = _localPractice ??= LocalPracticeStore(store);
      final schoolMode = _localOnlyScope == LearningScope.schoolLocal;
      return ScienceGameHomeScreen(
        units: units,
        sessionStore: store,
        scope: _localOnlyScope,
        schoolMode: schoolMode,
        showTabGuide: _showTabGuide,
        onTabGuideDismissed: () => setState(() => _showTabGuide = false),
        lanSocialAllowed: false,
        controller: _localGameController,
        // 旧端末内練習は個人記録。学校scopeへ混ぜない。
        legacyProgress: schoolMode ? null : progress,
        onOpenSettings: () => _openLocalSettings(context),
        onOpenClassroom: schoolMode
            ? () => _openLocalClassroom(context, units)
            : null,
        onExitLocalMode: _exitLocalMode,
      );
    }

    return ConsentScreen(
      onUseLocalOnly: () => _enterLocalMode(scope: LearningScope.personal),
      onUseRestrictedLocalRoute: (route) => _enterLocalMode(
        scope: switch (route) {
          RestrictedLocalRoute.under18Self => LearningScope.personal,
          RestrictedLocalRoute.school => LearningScope.schoolLocal,
        },
      ),
      onAgreed: (record) async {
        final consentStore = context.read<ConsentStore>();
        // UIの表示状態を信頼せず、外部通信より先に保存可能性を検証する。
        // 現在は成人の個人利用だけが有効なので、学校・未成年の記録から
        // Team APIを呼ぶ経路もここでfail-closedにする。
        if (!record.isValid) return JoinFailure.unknown;
        if (record.route == ConsentRoute.school) {
          // 学校経路にはTeamClient自体を提供していない。UIを改造しても
          // 招待確認や同意保存へ抜けられないよう、ここでも閉じる。
          return JoinFailure.unknown;
        }
        await consentStore.save(record);
        if (mounted) {
          setState(() {
            _consent = record;
            _showTabGuide = true;
          });
        }
        return null;
      },
    );
  }

  void _enterLocalMode({required LearningScope scope}) {
    assert(
      scope == LearningScope.personal || scope == LearningScope.schoolLocal,
    );
    // 端末内モードの選択、年齢、本人/学校経路は保存していないため、旧版の
    // schoolLocalを本人利用だったと推測して移すmigrationは行わない。再起動時は
    // 入口へ戻り、今回選んだ経路だけをpersonal/schoolLocalへ明示的に割り当てる。
    setState(() {
      _localOnlyScope = scope;
      _showTabGuide = true;
      _localOnlyUnits = UnitsClient(
        baseUrl: '',
        // 保存済みのサーバ教材も読まず、このビルドに同梱した正本だけを使う。
        store: MemorySessionStore(),
        assetBundle: widget.localCatalogAssets,
      );
    });
  }

  void _exitLocalMode() {
    setState(() {
      _localOnlyUnits = null;
      _localOnlyScope = LearningScope.personal;
    });
  }

  void _openLocalSettings(BuildContext routeContext) {
    unawaited(
      Navigator.of(routeContext).push<void>(
        MaterialPageRoute<void>(
          builder: (_) =>
              SettingsScreen(reminders: routeContext.read<Reminders>()),
        ),
      ),
    );
  }

  void _openLocalClassroom(BuildContext routeContext, UnitsClient units) {
    unawaited(_pushLocalClassroom(routeContext, units));
  }

  Future<void> _pushLocalClassroom(
    BuildContext routeContext,
    UnitsClient units,
  ) async {
    final store = routeContext.read<SessionStore>();
    final runStore = _localClassroomRun ??= LocalClassroomRunStore(store);
    await Navigator.of(routeContext).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LocalClassroomScreen(
          units: units,
          runStore: runStore,
          onAssignmentCompleted: (assignment, occurredAt) =>
              _recordSchoolAssignment(store, assignment, occurredAt),
          onRunChanged: _localGameController.reloadSnapshot,
        ),
      ),
    );
    if (mounted) await _localGameController.reloadSnapshot();
  }

  Future<void> _recordSchoolAssignment(
    SessionStore store,
    ClassroomAssignment assignment,
    DateTime occurredAt,
  ) async {
    await ClassroomLearningCompletion.commit(
      store: store,
      assignment: assignment,
      occurredAt: occurredAt,
    );
  }
}

/// 成人の外部通信同意が有効なツリーだけに、通信・購入サービスを置く。
///
/// 端末内モードの下にはこれらのProvider自体が存在しないため、将来画面を
/// 足したときも、うっかりreadしただけで匿名IDやSDKを起動できない。
class _OnlineServices extends StatelessWidget {
  const _OnlineServices({
    required this.serverUrl,
    required this.localCatalogAssets,
    required this.allowIndividualPurchases,
    required this.showTabGuide,
    required this.onTabGuideDismissed,
  });

  final String serverUrl;
  final AssetBundle? localCatalogAssets;
  final bool allowIndividualPurchases;
  final bool showTabGuide;
  final VoidCallback onTabGuideDismissed;

  @override
  Widget build(BuildContext context) {
    final store = context.read<SessionStore>();
    return MultiProvider(
      providers: [
        // 会話・クラス・購入で同じ匿名インストールIDを使う。token再登録や
        // キャッシュを、それぞれの機能で重複させない。
        Provider<DeviceIdentity>(
          create: (_) => DeviceIdentity(baseUrl: serverUrl, store: store),
        ),
        Provider<UnitsClient>(
          create: (_) => UnitsClient(
            baseUrl: serverUrl,
            store: store,
            assetBundle: localCatalogAssets,
          ),
        ),
        Provider<TeamClient>(
          create: (context) => TeamClient(
            baseUrl: serverUrl,
            identity: context.read<DeviceIdentity>(),
            store: store,
          ),
        ),
        Provider<PurchaseService>(
          create: (context) => RevenueCatPurchaseService(
            config: RevenueCatPurchaseConfig.fromEnvironment(),
            identity: context.read<DeviceIdentity>(),
            adapter: RevenueCatPurchaseAdapter(),
          ),
        ),
        Provider<SubscriptionSyncClient>(
          create: (context) => SubscriptionSyncClient(
            baseUrl: serverUrl,
            identity: context.read<DeviceIdentity>(),
          ),
        ),
      ],
      child: Builder(
        builder: (providerContext) => ScienceGameHomeScreen(
          units: providerContext.read<UnitsClient>(),
          sessionStore: store,
          scope: LearningScope.personal,
          schoolMode: false,
          lanSocialAllowed: true,
          showTabGuide: showTabGuide,
          onTabGuideDismissed: onTabGuideDismissed,
          legacyProgress: LocalPracticeStore(store),
          onOpenSettings: () => _openOnlineSettings(providerContext),
        ),
      ),
    );
  }

  void _openOnlineSettings(BuildContext routeContext) {
    final plusAvailable =
        allowIndividualPurchases &&
        routeContext.read<PurchaseService>().enabled;
    unawaited(
      Navigator.of(routeContext).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => SettingsScreen(
            reminders: routeContext.read<Reminders>(),
            onOpenPlus: plusAvailable
                ? () => _Home._openPlus(routeContext)
                : null,
          ),
        ),
      ),
    );
  }
}

/// 学校・18歳未満でも使える、同梱教材だけの学習入口。
///
/// Providerから外部サービスを読まず、[UnitsClient]もbaseUrlなしの専用品を
/// 明示的に受け取る。教材後はTalkを挟まず[OfflinePracticeScreen]へ直行する。
class _LocalOnlyHome extends StatefulWidget {
  const _LocalOnlyHome({
    required this.units,
    required this.progress,
    required this.runStore,
    required this.onExit,
  });

  final UnitsClient units;
  final LocalPracticeStore progress;
  final LocalClassroomRunStore runStore;
  final VoidCallback onExit;

  @override
  State<_LocalOnlyHome> createState() => _LocalOnlyHomeState();
}

class _LocalOnlyHomeState extends State<_LocalOnlyHome>
    with WidgetsBindingObserver {
  static const _assurance =
      '端末内モード。外部AI、学校サーバ、購入機能へ接続しません。'
      '入力した説明は送信も保存もせず、自動採点や理解認定も行いません。'
      '授業課題は直近1件の教材・概念・A/B/C・再開段階または完了状態・更新日時、'
      '個人練習は教材・概念・完了回数・最終完了日時だけを、この端末に残します。';

  List<UnitSummary> _catalog = const [];
  List<LocalPracticeRecord> _records = const [];
  final LocalPracticeSchedule _practiceSchedule = LocalPracticeSchedule();
  Timer? _dayBoundaryTimer;
  bool _loading = true;
  bool _opening = false;
  bool _clearing = false;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleDayBoundaryRefresh();
    _reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dayBoundaryTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _scheduleDayBoundaryRefresh();
    if (mounted) setState(() {});
  }

  void _scheduleDayBoundaryRefresh() {
    _dayBoundaryTimer?.cancel();
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, 4);
    if (!next.isAfter(now)) {
      next = DateTime(now.year, now.month, now.day + 1, 4);
    }
    _dayBoundaryTimer = Timer(next.difference(now), () {
      if (!mounted) return;
      setState(() {});
      _scheduleDayBoundaryRefresh();
    });
  }

  @override
  void didUpdateWidget(covariant _LocalOnlyHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.units != widget.units ||
        oldWidget.progress != widget.progress) {
      _reload();
    }
  }

  Future<void> _reload() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }
    try {
      final catalog = await widget.units.list();
      final records = await widget.progress.records();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _records = records;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Map<String, LocalPracticeRecord> get _recordById => {
    for (final record in _records) record.id: record,
  };

  LocalPracticeScheduleResult get _schedule =>
      _practiceSchedule.select(units: _catalog, records: _records);

  int get _practicedConcepts => _schedule.startedConcepts;

  Future<void> _openPicker() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => UnitPickerScreen(
            units: widget.units,
            onPick: (unit, conceptKey) => _read(unit, conceptKey),
          ),
        ),
      );
      if (mounted) await _reload();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _openNext() async {
    final mission = _schedule.mission;
    if (_opening || mission == null) return;
    setState(() => _opening = true);
    try {
      final unit = await widget.units.detail(mission.unit.id);
      if (!mounted) return;
      if (unit == null || unit.sectionFor(mission.conceptKey) == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('この教材を読み込めませんでした。もう一度お試しください。')),
        );
        return;
      }
      await _read(unit, mission.conceptKey);
      if (mounted) await _reload();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _openClassroom() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LocalClassroomScreen(
            units: widget.units,
            runStore: widget.runStore,
            onRunChanged: _reload,
          ),
        ),
      );
      if (mounted) await _reload();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _read(UnitDetail unit, String conceptKey) async {
    final section = unit.sectionFor(conceptKey);
    final conceptLabel = unit.summary.concepts
        .where((concept) => concept.key == conceptKey)
        .map((concept) => concept.label)
        .firstOrNull;
    if (section == null || conceptLabel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('この教材を読み込めませんでした。もう一度お試しください。')),
      );
      return;
    }

    // 2周目以降を初回と同じ教材・課題に戻さない。端末内の最小記録だけから
    // 判定し、既に完走した概念は答えの見えない具体場面へ適用するCASEとして開く。
    final record = _recordById['${unit.id}/$conceptKey'];
    final practiceAttempt = record?.completedCount ?? 0;
    final missionKind = record == null
        ? MissionKind.teach
        : MissionKind.caseRetry;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MaterialScreen(
          unit: unit,
          focusConceptKey: conceptKey,
          missionKind: missionKind,
          practiceAttempt: practiceAttempt,
          onDone: (_) {
            // 教材は手元に残さず、通信するTalkではなく端末内4段階へ直行する。
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => OfflinePracticeScreen(
                  section: section,
                  conceptLabel: conceptLabel,
                  missionKind: missionKind,
                  practiceAttempt: practiceAttempt,
                  onCheckpointCompleted: () async {
                    await widget.progress.recordCompletion(
                      unitId: unit.id,
                      conceptKey: conceptKey,
                    );
                    // Material はこの画面へ置換されるため、Material route を待つ
                    // Home 側の Future はここより先に完了する。保存直後に背面の
                    // Home を更新し、戻った瞬間から次の1件を正しく見せる。
                    if (mounted) await _reload();
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _clearProgress() async {
    if (_clearing || _practicedConcepts == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: const Text('端末内の練習履歴を消しますか？'),
        content: const Text(
          '教材・概念・完了回数・最終完了日時の印を、この端末から消します。'
          '入力した説明はもともと保存していません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('履歴を残す'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('練習の印を消す'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _clearing = true);
    try {
      await widget.progress.clear();
      if (mounted) await _reload();
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.appColors;
    final schedule = _schedule;
    return Scaffold(
      key: const ValueKey('local-only-home'),
      body: SafeArea(
        bottom: false,
        child: ReadableWidth(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              18,
              14,
              18,
              28 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              const StudioWordmark(),
              const SizedBox(height: 28),
              const StudioPageIntro(
                eyebrow: 'DEVICE-ONLY STUDIO  /  端末内',
                title: '答えを送らず、\n考え抜く。',
                body: '同梱教材を読んで、自分の言葉で思い出し、固定の思い込みを直して、次の1件へ進みます。',
              ),
              const SizedBox(height: 22),
              if (_loading)
                const _LocalMissionLoading()
              else if (schedule.mission case final mission?)
                _LocalMissionCard(
                  mission: mission,
                  practicedConcepts: schedule.startedConcepts,
                  totalConcepts: schedule.totalConcepts,
                  busy: _opening,
                  onStart: _openNext,
                )
              else if (schedule.state ==
                  LocalPracticeScheduleState.waitingForNextDay)
                _LocalMissionWaiting(
                  practicedConcepts: schedule.startedConcepts,
                  totalConcepts: schedule.totalConcepts,
                )
              else
                _LocalMissionUnavailable(failed: _loadFailed, onRetry: _reload),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('local-only-pick-unit'),
                onPressed: _opening ? null : _openPicker,
                icon: const Icon(Icons.auto_stories_outlined),
                label: const Text('自分でほかの教材を選ぶ'),
              ),
              const SizedBox(height: 12),
              LocalClassroomEntryCard(
                units: widget.units,
                runStore: widget.runStore,
                onOpen: _openClassroom,
              ),
              const SizedBox(height: 28),
              Semantics(
                key: const ValueKey('local-only-assurance'),
                container: true,
                label: _assurance,
                child: ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
                    decoration: BoxDecoration(
                      color: colors.coolSurface,
                      borderRadius: BorderRadius.circular(AppRadius.xxl),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.phonelink_lock_outlined,
                              color: colors.onCoolSurface,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'この端末の中だけで学びます',
                                style: t.textTheme.titleSmall
                                    ?.copyWith(color: colors.onCoolSurface)
                                    .jaWeight(FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 9),
                        Text(
                          '外部AI・学校サーバ・購入機能には接続しません。'
                          'ここで入力する説明は送信も保存もされません。'
                          '授業課題は直近1件の教材・概念・A/B/C・再開段階または完了状態・更新日時、'
                          '個人練習は教材・概念・完了回数・最終完了日時だけを、この端末に残します。',
                          style: t.textTheme.bodyMedium?.copyWith(
                            color: colors.onCoolSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '入力した説明は自動採点せず、「理解した」という認定もしません。'
                          '最後の固定3択は、教材の思い込みを自分で直すための確認です。',
                          style: t.textTheme.bodySmall?.copyWith(
                            color: colors.onCoolSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const StudioSectionHeader(
                title: '4段階で、考えを強くする',
                description: '点数ではなく、説明の中身を自分で見直します。',
              ),
              const SizedBox(height: 14),
              const _LocalStep(number: '01', label: '同梱教材を読む'),
              const _LocalStep(number: '02', label: '見ずに、自分の言葉で思い出す'),
              const _LocalStep(number: '03', label: '選ぶ・分類する・順に組む。その理由を足す'),
              const _LocalStep(number: '04', label: '固定の思い込みを直し、組んだ答えを教材と見比べる'),
              if (_practicedConcepts > 0) ...[
                const SizedBox(height: 8),
                TextButton(
                  key: const ValueKey('local-only-clear-progress'),
                  onPressed: _clearing ? null : _clearProgress,
                  child: Text(_clearing ? '消しています…' : '端末内の練習履歴を消す'),
                ),
              ],
              const SizedBox(height: 10),
              TextButton(
                onPressed: widget.onExit,
                child: const Text('通信を使うモードの確認に戻る'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalMissionCard extends StatelessWidget {
  const _LocalMissionCard({
    required this.mission,
    required this.practicedConcepts,
    required this.totalConcepts,
    required this.busy,
    required this.onStart,
  });

  final LocalPracticeScheduledMission mission;
  final int practicedConcepts;
  final int totalConcepts;
  final bool busy;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.appColors;
    final isNew = mission.reason == LocalPracticeMissionReason.newConcept;
    final practiceStage = LocalPracticeStage
        .values[mission.completedCount % LocalPracticeStage.values.length];
    return Semantics(
      key: const ValueKey('local-only-next-mission-card'),
      container: true,
      explicitChildNodes: true,
      label:
          '次の端末内ミッション、${mission.conceptLabel}。'
          '今回は${practiceStage.label}。'
          '全$totalConcepts件のうち$practicedConcepts件に練習済みの印があります',
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
        decoration: BoxDecoration(
          color: colors.warmSurface,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isNew ? 'NEXT LOCAL MISSION' : 'NEXT CASE',
                    style: t.textTheme.labelMedium
                        ?.copyWith(color: colors.onWarmSurface)
                        .jaWeight(FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    mission.conceptLabel,
                    style: t.textTheme.headlineSmall
                        ?.copyWith(color: colors.onWarmSurface)
                        .jaWeight(FontWeight.w800),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    mission.unit.title,
                    style: t.textTheme.bodyMedium?.copyWith(
                      color: colors.onWarmSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '今回：${practiceStage.label}',
                    style: t.textTheme.labelLarge
                        ?.copyWith(color: colors.onWarmSurface)
                        .jaWeight(FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '全$totalConcepts件のうち、$practicedConcepts件に練習済みの印があります。'
                    '${isNew ? 'まだ取り組んでいない1件を先に出します。' : '前の学習日より前に取り組んだ中で、一番間が空いた1件です。'}',
                    style: t.textTheme.bodySmall?.copyWith(
                      color: colors.onWarmSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('local-only-next-mission'),
              onPressed: busy ? null : onStart,
              child: Text(busy ? '教材を開いています…' : 'この1件をはじめる'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalMissionWaiting extends StatelessWidget {
  const _LocalMissionWaiting({
    required this.practicedConcepts,
    required this.totalConcepts,
  });

  final int practicedConcepts;
  final int totalConcepts;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.appColors;
    return Semantics(
      key: const ValueKey('local-only-next-day'),
      container: true,
      label:
          'きょうの予定分はここまで。全$totalConcepts件のうち、'
          '$practicedConcepts件に練習済みの印があります。'
          '次のケースは次の学習日から出します。自分で選ぶ練習と先生の教材番号は今も使えます',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
          decoration: BoxDecoration(
            color: colors.coolSurface,
            borderRadius: BorderRadius.circular(AppRadius.xxl),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.event_available_outlined, color: colors.onCoolSurface),
              const SizedBox(height: 10),
              Text(
                'きょうの予定分はここまで。',
                style: t.textTheme.titleLarge
                    ?.copyWith(color: colors.onCoolSurface)
                    .jaWeight(FontWeight.w800),
              ),
              const SizedBox(height: 7),
              Text(
                '次のケースは、次の学習日から出します。'
                '自分で選ぶ練習と、先生の教材番号は今も使えます。',
                style: t.textTheme.bodyMedium?.copyWith(
                  color: colors.onCoolSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalMissionLoading extends StatelessWidget {
  const _LocalMissionLoading();

  @override
  Widget build(BuildContext context) => Semantics(
    key: const ValueKey('local-only-mission-loading'),
    label: '次の端末内ミッションを準備しています',
    child: const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: LinearProgressIndicator(),
    ),
  );
}

class _LocalMissionUnavailable extends StatelessWidget {
  const _LocalMissionUnavailable({required this.failed, required this.onRetry});

  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('local-only-mission-unavailable'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(failed ? '端末内の教材を読み込めませんでした。' : '端末内の教材がまだありません。'),
      const SizedBox(height: 8),
      OutlinedButton(onPressed: onRetry, child: const Text('もう一度読み込む')),
    ],
  );
}

class _LocalStep extends StatelessWidget {
  const _LocalStep({required this.number, required this.label});

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 38,
            child: Text(
              number,
              style: t.textTheme.labelLarge
                  ?.copyWith(color: scheme.primary)
                  .jaWeight(FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: t.textTheme.bodyLarge?.jaWeight(FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// 単元を選ぶ → 教材を読む → 教える。**この順序がコア体験そのもの。**
///
/// 教材を読まずに会話へ入れる経路は作らない。
/// 読んでいないと「説明できない」だけの体験になり、
/// 誤概念の誘発も「習っていないから訂正できなかった」と区別がつかなくなる。
class _Home extends StatelessWidget {
  const _Home({
    required this.routeObserver,
    required this.allowIndividualPurchases,
  });

  final RouteObserver<ModalRoute<void>> routeObserver;
  final bool allowIndividualPurchases;

  /// 教材を読む → 教える へ入る。**この導線を1か所に閉じる。**
  ///
  /// ホームからも単元一覧からも同じ経路を通す。
  /// 経路が2つあると、片方だけ C2（教材を残さない）を破る形になりやすい。
  static Future<void> _read(
    BuildContext context,
    UnitDetail unit, {
    String? focusConceptKey,
    MissionKind missionKind = MissionKind.teach,
    required bool allowIndividualPurchases,
  }) {
    final plusAvailable = context.read<PurchaseService>().enabled;
    final focusedSection = focusConceptKey == null
        ? null
        : unit.sectionFor(focusConceptKey);
    final focusedConceptLabel = switch (focusConceptKey) {
      final key? =>
        unit.summary.concepts
            .where((concept) => concept.key == key)
            .map((concept) => concept.label)
            .firstOrNull,
      null => null,
    };
    if (focusConceptKey != null &&
        (focusedSection == null ||
            (missionKind == MissionKind.caseRetry &&
                focusedSection.tryIt.trim().isEmpty))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('このミッションの教材を読み込めませんでした。もう一度お試しください。')),
      );
      return Future.value();
    }
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MaterialScreen(
          unit: unit,
          focusConceptKey: focusConceptKey,
          missionKind: missionKind,
          onDone: (tactic) {
            // **教材の画面を残さない**（C2）。戻れると音読になる
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (ctx2) => ChangeNotifierProvider(
                  create: (ctx) => _controllerFor(
                    ctx,
                    unit.summary.id,
                    focusConceptKey: focusConceptKey,
                    tactic: tactic,
                    missionKind: missionKind,
                  ),
                  child: TalkScreen(
                    unitTitle: unit.summary.title,
                    offlineSection: focusedSection,
                    offlineMissionKind: missionKind,
                    onOpenPlus: allowIndividualPurchases && plusAvailable
                        ? () => _openPlus(ctx2)
                        : null,
                    conceptLabel: focusedConceptLabel,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static void _openReview(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReviewScreen(
          store: context.read<SessionStore>(),
          units: context.read<UnitsClient>(),
        ),
      ),
    );
  }

  static void _openPicker(
    BuildContext context, {
    required bool allowIndividualPurchases,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UnitPickerScreen(
          units: context.read<UnitsClient>(),
          onOpenReview: () => _openReview(context),
          onPick: (unit, conceptKey) => _read(
            context,
            unit,
            focusConceptKey: conceptKey,
            missionKind: MissionKind.teach,
            allowIndividualPurchases: allowIndividualPurchases,
          ),
        ),
      ),
    );
  }

  static Future<void> _openPlus(BuildContext context) async {
    final purchases = context.read<PurchaseService>();
    if (!purchases.enabled) return;
    final subscriptionSync = context.read<SubscriptionSyncClient>();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlusScreen(
          purchaseService: purchases,
          onEntitlementSync: () async {
            final access = await subscriptionSync.sync();
            return access.entitled;
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plusAvailable =
        allowIndividualPurchases && context.read<PurchaseService>().enabled;
    return HomeScreen(
      store: context.read<SessionStore>(),
      units: context.read<UnitsClient>(),
      routeObserver: routeObserver,
      // 現在Homeへ到達できるのは成人selfだけ。学校向け提供を再開するまで、
      // TeamClientを画面へ渡さず、旧/改造導線と混同しない。
      team: null,
      reminders: context.read<Reminders>(),
      onOpenPlus: plusAvailable ? () => _openPlus(context) : null,
      onOpenReview: () => _openReview(context),
      onPickUnit: () => _openPicker(
        context,
        allowIndividualPurchases: allowIndividualPurchases,
      ),
      onStart: (summary, conceptKey, missionKind) async {
        final client = context.read<UnitsClient>();
        final detail = await client.detail(summary.id);
        if (!context.mounted) return;
        if (detail == null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('この教材をまだ読み込めていません。')));
          return;
        }
        // **きょうの1件の概念に焦点を当てて読ませる。**
        // 単元まるごと読ませると、1件だけやりたい日に重すぎる
        await _read(
          context,
          detail,
          focusConceptKey: conceptKey,
          missionKind: missionKind,
          allowIndividualPurchases: allowIndividualPurchases,
        );
      },
    );
  }
}
