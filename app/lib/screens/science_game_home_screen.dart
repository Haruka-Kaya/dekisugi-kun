import 'dart:async';

import '../learning/domain/learning_event.dart';
import '../learning/domain/learning_economy.dart';
import '../learning/domain/learning_heart.dart';
import '../learning/domain/learning_need.dart';
import '../learning/domain/learning_policy.dart';
import '../learning/domain/learning_progress.dart';
import '../learning/services/daily_audio_practice_plan.dart';
import '../learning/services/game_content_projection.dart';
import '../learning/services/game_path_projection.dart';
import '../learning/services/learning_game_projection.dart';
import '../learning/services/learning_progress_store.dart';
import '../learning/services/learning_quest_plan_v2.dart';
import '../learning/services/learning_repair_planner.dart';
import '../learning/services/local_weekly_league_projection.dart';
import '../learning/services/science_activity_content.dart';
import '../models/day_key.dart';
import '../models/game_hub.dart';
import '../models/game_path.dart';
import '../models/lan_social.dart';
import '../models/mission.dart';
import '../models/unit.dart';
import '../services/lan_social_client.dart';
import '../services/local_practice_store.dart';
import '../services/session_store.dart';
import '../services/units_client.dart';
import '../ui/_material.dart';
import '../widgets/game_activity_scaffold.dart';
import '../widgets/game_completion_celebration.dart';
import '../widgets/game_shell.dart';
import 'game_profile_screen.dart';
import 'game_economy_sheet.dart';
import 'league_screen.dart';
import 'lan_social_screen.dart';
import 'notation_lab_hub_screen.dart';
import 'offline_practice_screen.dart';
import 'path_screen.dart';
import 'practice_hub_screen.dart';
import 'science_diagram_screen.dart';
import 'science_legendary_screen.dart';
import 'science_lesson_screen.dart';
import 'science_listening_screen.dart';
import 'science_lightning_screen.dart';
import 'science_match_lab_screen.dart';
import 'science_notation_lab_screen.dart';
import 'science_speak_listen_screen.dart';
import 'science_story_screen.dart';
import 'science_timed_challenge_screen.dart';
import 'science_unit_legendary_screen.dart';
import 'stories_screen.dart';
import 'timed_challenge_entry_dialog.dart';

typedef LanSocialMeaningfulEventContributor =
    Future<void> Function(LearningEventRecord event);

/// Homeの共通Quest boardへ渡す、LAN Friendsの検証済みsnapshot。
///
/// テストtransportもproductionと同じ匿名room ID・集約状態だけを渡し、氏名・
/// 回答・端末IDをHomeへ持ち込まない。nullは「まだroomへ参加していない」。
typedef LanSocialFriendsQuestLoader =
    Future<LanSocialFriendsQuestState?> Function();

final class LanSocialFriendsQuestState {
  const LanSocialFriendsQuestState({
    required this.roomId,
    required this.snapshot,
  });

  final String roomId;
  final LanSocialFriendsSnapshot snapshot;
}

/// 外側のrouteから、表示中の学習台帳snapshotだけを再読込するためのハンドル。
///
/// 学校授業の完了routeが閉じた直後など、activity route以外で台帳が更新された
/// 場合に使う。回答や画面内部stateは公開しない。
class ScienceGameHomeController {
  _ScienceGameHomeScreenState? _state;

  Future<void> reloadSnapshot() async {
    final state = _state;
    if (state != null && state.mounted) await state._reloadSnapshot();
  }

  void _attach(_ScienceGameHomeScreenState state) => _state = state;

  void _detach(_ScienceGameHomeScreenState state) {
    if (identical(_state, state)) _state = null;
  }
}

/// catalog・学習台帳・6タブを結ぶ、理科ゲームの実ホーム。
///
/// 回答本文は各activity routeにだけ存在し、この画面へ戻さない。ここが受け取る
/// callbackは「どのnodeを、どの証拠レベルまで終えたか」だけ。
class ScienceGameHomeScreen extends StatefulWidget {
  const ScienceGameHomeScreen({
    super.key,
    required this.units,
    required this.sessionStore,
    required this.scope,
    required this.schoolMode,
    required this.onOpenSettings,
    this.controller,
    this.legacyProgress,
    this.onOpenClassroom,
    this.onExitLocalMode,
    this.lanSocialAllowed = false,
    this.lanSocialMeaningfulEventContributor,
    this.lanSocialFriendsQuestLoader,
    this.now,
  });

  final UnitsClient units;
  final SessionStore sessionStore;
  final LearningScope scope;
  final bool schoolMode;
  final VoidCallback onOpenSettings;
  final ScienceGameHomeController? controller;
  final VoidCallback? onOpenClassroom;
  final VoidCallback? onExitLocalMode;

  /// 成人online同意ツリーからだけtrueを渡す。local-only/schoolは既定false。
  final bool lanSocialAllowed;

  /// テストまたは別transport用。未指定時はTLS pin済みLAN clientを使う。
  final LanSocialMeaningfulEventContributor?
  lanSocialMeaningfulEventContributor;

  /// LAN coordinatorを使わずHome統合を検証するための匿名snapshot loader。
  @visibleForTesting
  final LanSocialFriendsQuestLoader? lanSocialFriendsQuestLoader;

  /// 学習日の午前4時境界を決定する時計。productionでは端末時刻を使う。
  @visibleForTesting
  final DateTime Function()? now;

  /// 旧4段階で確実に完了した概念だけをread/diagramへ橋渡しする。
  /// 新規書込は現行学習台帳だけに行い、旧回数を増やさない。
  final LocalPracticeStore? legacyProgress;

  @override
  State<ScienceGameHomeScreen> createState() => _ScienceGameHomeScreenState();
}

class _ScienceGameHomeScreenState extends State<ScienceGameHomeScreen>
    with WidgetsBindingObserver {
  static const _courseId = 'science-ja-v1';
  static const _contentVersion = 'catalog-v10';

  final _gameProjection = const LearningGameProjection();
  final _contentProjection = const GameContentProjection();
  final _dailyAudioPlanner = const DailyAudioPracticePlanner();
  final _dailyQuestAvailability =
      const LearningDailyQuestAvailabilityProjection();
  final _questPlanner = const LearningQuestPlannerV2();
  final _questBoardProjection = const LearningQuestBoardProjectionV2();
  final _repairPlanner = const LearningRepairPlanner();
  final Map<String, UnitDetail> _detailCache = {};
  List<UnitSummary> _catalog = const [];
  LearningProgressSnapshot? _snapshot;
  LearningQuestPlanV2? _activeQuestPlan;
  LearningFriendsQuestBoardSource? _lanFriendsQuestSource;
  Set<String> _legacyCompleted = const {};
  bool _loading = true;
  bool _loadFailed = false;
  bool _questUnavailable = false;
  String? _openingNodeId;
  int _runSerial = 0;
  _PendingGemSpend? _pendingFreezeSpend;
  _PendingGemSpend? _pendingHeartSpend;
  final _pendingCosmeticSpends = <String, _PendingGemSpend>{};
  String? _selectedCoopParticipantId;
  bool _startingCoop = false;
  bool _startingWeeklyLeague = false;
  int _weeklyLeagueParticipantCount = 2;
  List<LearningLocalCoopContribution> _localCoopContributions = const [];
  LanSocialMeaningfulProgressDispatcher? _lanSocialDispatcher;
  Timer? _learningDayBoundaryTimer;
  GameActivityStatusController? _activityStatus;

  DateTime _now() => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller?._attach(this);
    _scheduleLearningDayBoundaryRefresh();
    _load();
  }

  @override
  void didUpdateWidget(covariant ScienceGameHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (!identical(oldWidget.sessionStore, widget.sessionStore)) {
      _lanSocialDispatcher = null;
    }
    if (!identical(oldWidget.now, widget.now)) {
      _scheduleLearningDayBoundaryRefresh();
    }
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _learningDayBoundaryTimer?.cancel();
    _activityStatus?.dispose();
    _activityStatus = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleLearningDayBoundaryRefresh();
      unawaited(_reloadSnapshot());
    }
  }

  void _scheduleLearningDayBoundaryRefresh() {
    _learningDayBoundaryTimer?.cancel();
    final now = _now();
    var next = DateTime(now.year, now.month, now.day, kDayCutoverHour);
    if (!next.isAfter(now)) {
      next = DateTime(now.year, now.month, now.day + 1, kDayCutoverHour);
    }
    _learningDayBoundaryTimer = Timer(next.difference(now), () async {
      _learningDayBoundaryTimer = null;
      if (!mounted) return;
      await _reloadSnapshot();
      if (mounted) _scheduleLearningDayBoundaryRefresh();
    });
  }

  SessionLearningProgressStore _progressStore(DateTime now) {
    final plan = _activeQuestPlan;
    final rules = plan != null && plan.learningDay == dayKeyOf(now.toLocal())
        ? plan.commitRules
        : const LearningCommitRules();
    return SessionLearningProgressStore(widget.sessionStore, rules: rules);
  }

  SessionLearningProgressStore get _baseProgressStore =>
      SessionLearningProgressStore(widget.sessionStore);

  LearningQuestAudience get _questAudience {
    if (widget.schoolMode || widget.scope == LearningScope.schoolLocal) {
      return LearningQuestAudience.schoolLocal;
    }
    return widget.lanSocialAllowed
        ? LearningQuestAudience.personalLanConsented
        : LearningQuestAudience.personalLocalOnly;
  }

  LearningGameProjectionResult _baseGameForQuestPlan({
    required List<UnitSummary> catalog,
    required LearningProgressSnapshot snapshot,
    required Set<String> legacyCompleted,
    required DateTime now,
  }) => _gameProjection.build(
    catalog: catalog,
    snapshot: snapshot,
    now: now,
    schoolMode: widget.schoolMode,
    legacyCompletedSkillIds: legacyCompleted,
  );

  LearningQuestPlanV2 _buildQuestPlan({
    required List<UnitSummary> catalog,
    required LearningProgressSnapshot snapshot,
    required Set<String> legacyCompleted,
    required DateTime now,
  }) {
    final audience = _questAudience;
    if (audience == LearningQuestAudience.schoolLocal) {
      return _questPlanner.build(
        now: now,
        audience: audience,
        persistedQuests: snapshot.quests,
      );
    }
    final base = _baseGameForQuestPlan(
      catalog: catalog,
      snapshot: snapshot,
      legacyCompleted: legacyCompleted,
      now: now,
    );
    final learningDay = dayKeyOf(now.toLocal());
    final audio = _dailyAudioPlanner.build(
      catalog: catalog,
      path: base.path,
      snapshot: snapshot,
      learningDay: learningDay,
    );
    bool hasMeaningfulAudio(DailyAudioMissionKind kind) {
      final mission = audio.missionOf(kind);
      if (mission == null || mission.completedToday) return false;
      final node = _pathNodeIn(base.path, mission.nodeId);
      return node != null &&
          (node.state == GamePathNodeState.available ||
              node.state == GamePathNodeState.inProgress);
    }

    final clearedNodeIds = {
      for (final node in snapshot.nodes)
        if (node.state == LearningNodeState.cleared) node.nodeId,
    };
    final pathNodes = {
      for (final unit in base.path.units)
        for (final node in unit.nodes) node.id: node,
    };
    final hasMeaningfulNotation = catalog.any(
      (unit) => unit.concepts.any((concept) {
        final practice =
            pathNodes[GamePathProjection.nodeId(
              unit.id,
              concept.key,
              GamePathNodeKind.practice,
            )];
        return practice?.canOpen == true &&
            !clearedNodeIds.contains(_notationNodeId(unit.id, concept.key));
      }),
    );
    final variants = _dailyQuestAvailability.build(
      path: base.path,
      hasMeaningfulNotation: hasMeaningfulNotation,
      hasDueSpacedReview: base.duePracticeCount > 0,
      hasDailyListening: hasMeaningfulAudio(DailyAudioMissionKind.listening),
      hasDailySpeaking: hasMeaningfulAudio(DailyAudioMissionKind.speaking),
    );
    return _questPlanner.build(
      now: now,
      audience: audience,
      availableVariants: variants,
      persistedQuests: snapshot.quests,
    );
  }

  Future<({LearningProgressSnapshot snapshot, LearningQuestPlanV2 plan})>
  _materializeQuestPlan({
    required LearningProgressStore store,
    required List<UnitSummary> catalog,
    required LearningProgressSnapshot snapshot,
    required Set<String> legacyCompleted,
    required DateTime now,
  }) async {
    var plan = _buildQuestPlan(
      catalog: catalog,
      snapshot: snapshot,
      legacyCompleted: legacyCompleted,
      now: now,
    );
    await store.materializeQuestDefinitions(
      scope: widget.scope,
      definitions: plan.definitionsToMaterialize,
    );
    final materializedSnapshot = await store.snapshot(widget.scope);
    plan = _buildQuestPlan(
      catalog: catalog,
      snapshot: materializedSnapshot,
      legacyCompleted: legacyCompleted,
      now: now,
    );
    if (plan.definitionsToMaterialize.isNotEmpty) {
      throw StateError('Quest plan was not fixed by materialization');
    }
    return (snapshot: materializedSnapshot, plan: plan);
  }

  Future<_LanFriendsQuestRefresh> _loadLanFriendsQuest() async {
    if (!_questAudience.allowsLanFriends) {
      return const _LanFriendsQuestRefresh.unavailable();
    }
    final injected = widget.lanSocialFriendsQuestLoader;
    if (injected != null) {
      try {
        return _LanFriendsQuestRefresh.authoritative(await injected());
      } catch (_) {
        return const _LanFriendsQuestRefresh.unavailable();
      }
    }
    try {
      final memberships = await LanSocialClient.savedMemberships(
        widget.sessionStore,
      );
      final friends = memberships
          .where((membership) => membership.kind == LanSocialRoomKind.friends)
          .toList(growable: false);
      if (friends.isEmpty) {
        return const _LanFriendsQuestRefresh.authoritative(null);
      }
      if (friends.length != 1) {
        return const _LanFriendsQuestRefresh.unavailable();
      }
      final membership = friends.single;
      final client = LanSocialClient(
        endpoint: LanSocialEndpoint(
          baseUrl: membership.baseUrl,
          certificateSha256: membership.certificateSha256,
        ),
        store: widget.sessionStore,
      );
      final snapshot = await client.snapshot(LanSocialRoomKind.friends);
      if (snapshot is! LanSocialFriendsSnapshot) {
        return const _LanFriendsQuestRefresh.unavailable();
      }
      return _LanFriendsQuestRefresh.authoritative(
        LanSocialFriendsQuestState(
          roomId: membership.roomId,
          snapshot: snapshot,
        ),
      );
    } catch (_) {
      return const _LanFriendsQuestRefresh.unavailable();
    }
  }

  LearningFriendsQuestBoardSource _projectLanFriendsQuest(
    LanSocialFriendsQuestState? state,
    LearningProgressSnapshot snapshot,
  ) {
    if (state == null) return LearningFriendsQuestBoardSource.lanInvite();
    final rewardId = 'gems.lan-friends.v1:${state.roomId}';
    final rewardRecorded = snapshot.rewards.any(
      (reward) =>
          reward.entryId == rewardId &&
          reward.scope == LearningScope.personal &&
          reward.type == LearningRewardType.gems &&
          reward.amount == 1 &&
          reward.reason == 'lan-friends.v1:${state.roomId}' &&
          reward.sourceEventId == null,
    );
    return LearningFriendsQuestBoardSource.lanRoom(
      roomId: state.roomId,
      snapshot: state.snapshot,
      rewardRecorded: rewardRecorded,
    );
  }

  Future<
    ({
      LearningProgressSnapshot snapshot,
      LearningQuestPlanV2 plan,
      LearningFriendsQuestBoardSource? source,
    })
  >
  _refreshLanFriendsQuest({
    required LearningProgressStore store,
    required List<UnitSummary> catalog,
    required Set<String> legacyCompleted,
    required DateTime now,
    required LearningProgressSnapshot snapshot,
    required LearningQuestPlanV2 plan,
    required LearningFriendsQuestBoardSource? previousSource,
  }) async {
    if (!_questAudience.allowsLanFriends) {
      return (snapshot: snapshot, plan: plan, source: null);
    }
    final refresh = await _loadLanFriendsQuest();
    if (!refresh.authoritative) {
      return (snapshot: snapshot, plan: plan, source: previousSource);
    }
    try {
      // production snapshotは達成報酬を同じSessionStoreへ冪等に反映しうるため、
      // roomがある場合は報酬台帳を再読込してからboard stateを決める。
      final nextSnapshot = refresh.state == null
          ? snapshot
          : await store.snapshot(widget.scope);
      final nextPlan = _buildQuestPlan(
        catalog: catalog,
        snapshot: nextSnapshot,
        legacyCompleted: legacyCompleted,
        now: now,
      );
      if (nextPlan.definitionsToMaterialize.isNotEmpty) {
        throw StateError('LAN refresh changed the materialized Quest plan');
      }
      return (
        snapshot: nextSnapshot,
        plan: nextPlan,
        source: _projectLanFriendsQuest(refresh.state, nextSnapshot),
      );
    } catch (_) {
      return (snapshot: snapshot, plan: plan, source: previousSource);
    }
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }
    try {
      final catalog = await widget.units.list();
      final details = await Future.wait([
        for (final unit in catalog)
          () async {
            try {
              return await widget.units.detail(unit.id);
            } catch (_) {
              return null;
            }
          }(),
      ]);
      final legacy = await widget.legacyProgress?.records() ?? const [];
      final legacyCompleted = {
        for (final record in legacy) '${record.unitId}/${record.conceptKey}',
      };
      final now = _now();
      final store = _baseProgressStore;
      if (!widget.schoolMode) {
        await store.refreshChallengeHearts(
          learningDay: dayKeyOf(now),
          occurredAt: now.toUtc(),
        );
      }
      var snapshot = await _snapshotWithLocalLeagueFinalization(store, now);
      LearningQuestPlanV2? plan;
      LearningFriendsQuestBoardSource? lanSource;
      var questUnavailable = false;
      try {
        final materialized = await _materializeQuestPlan(
          store: store,
          catalog: catalog,
          snapshot: snapshot,
          legacyCompleted: legacyCompleted,
          now: now,
        );
        snapshot = materialized.snapshot;
        plan = materialized.plan;
        final lan = await _refreshLanFriendsQuest(
          store: store,
          catalog: catalog,
          legacyCompleted: legacyCompleted,
          now: now,
          snapshot: snapshot,
          plan: plan,
          previousSource: _lanFriendsQuestSource,
        );
        snapshot = lan.snapshot;
        plan = lan.plan;
        lanSource = lan.source;
      } catch (_) {
        // Quest definitionを保存できない時はrulesなし・boardなしでfail closedに
        // する。catalogと学習台帳は有効なのでPath全体をblankにはしない。
        plan = null;
        lanSource = null;
        questUnavailable = true;
      }
      var contributions = const <LearningLocalCoopContribution>[];
      try {
        contributions = await store.localCoopContributions({
          for (final run in snapshot.localCoopRuns) run.runId,
        });
      } catch (_) {
        // 任意のリーグ参照障害で、学習Pathと保存済み進捗を消さない。
      }
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _detailCache
          ..clear()
          ..addEntries(
            details.whereType<UnitDetail>().map(
              (detail) => MapEntry(detail.id, detail),
            ),
          );
        _snapshot = snapshot;
        _activeQuestPlan = plan;
        _lanFriendsQuestSource = lanSource;
        _questUnavailable = questUnavailable;
        _localCoopContributions = contributions;
        _legacyCompleted = legacyCompleted;
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

  Future<void> _reloadSnapshot() async {
    try {
      final now = _now();
      final store = _baseProgressStore;
      if (!widget.schoolMode) {
        await store.refreshChallengeHearts(
          learningDay: dayKeyOf(now),
          occurredAt: now.toUtc(),
        );
      }
      var snapshot = await _snapshotWithLocalLeagueFinalization(store, now);
      final materialized = await _materializeQuestPlan(
        store: store,
        catalog: _catalog,
        snapshot: snapshot,
        legacyCompleted: _legacyCompleted,
        now: now,
      );
      snapshot = materialized.snapshot;
      var plan = materialized.plan;
      final lan = await _refreshLanFriendsQuest(
        store: store,
        catalog: _catalog,
        legacyCompleted: _legacyCompleted,
        now: now,
        snapshot: snapshot,
        plan: plan,
        previousSource: _lanFriendsQuestSource,
      );
      snapshot = lan.snapshot;
      plan = lan.plan;
      var contributions = _localCoopContributions;
      try {
        contributions = await store.localCoopContributions({
          for (final run in snapshot.localCoopRuns) run.runId,
        });
      } catch (_) {
        // 最後に検証できたリーグ表示を保ち、学習進捗だけは更新する。
      }
      if (mounted) {
        setState(() {
          _snapshot = snapshot;
          _activeQuestPlan = plan;
          _lanFriendsQuestSource = lan.source;
          _questUnavailable = false;
          _localCoopContributions = contributions;
        });
        final status = _game?.path.status;
        if (status != null) _activityStatus?.replace(status);
      }
    } catch (_) {
      // 既に描画できるsnapshotを通信不能のように消さない。
      if (mounted) setState(() => _questUnavailable = true);
    }
  }

  LearningGameProjectionResult? get _game {
    final snapshot = _snapshot;
    final questPlan = _activeQuestPlan;
    if (snapshot == null || _catalog.isEmpty) return null;
    final now = _now();
    final currentPlan = questPlan?.learningDay == dayKeyOf(now.toLocal())
        ? questPlan
        : null;
    return _gameProjection.build(
      catalog: _catalog,
      snapshot: snapshot,
      now: now,
      schoolMode: widget.schoolMode,
      legacyCompletedSkillIds: _legacyCompleted,
      questTitles: currentPlan == null
          ? const {}
          : {
              for (final entry in currentPlan.presentations.entries)
                entry.key: entry.value.title,
            },
      activeQuestDefinitions: currentPlan?.activeDefinitions ?? const [],
    );
  }

  GameActivityStatusController _beginActivityStatus() {
    final status = _game?.path.status;
    if (status == null) {
      throw StateError('Activity status requires a projected game snapshot.');
    }
    assert(_activityStatus == null, 'Only one activity route may be open.');
    final controller = GameActivityStatusController(status);
    _activityStatus = controller;
    return controller;
  }

  void _endActivityStatus(GameActivityStatusController controller) {
    if (!identical(_activityStatus, controller)) return;
    _activityStatus = null;
    controller.dispose();
  }

  Widget _activityFrame({
    required GameActivityStatusController status,
    required Widget child,
    VoidCallback? onExit,
  }) => GameActivityScaffold(
    statusListenable: status,
    schoolMode: widget.schoolMode,
    onExit: onExit,
    mascotStyle:
        _game?.economy.equippedPathMascotStyle ??
        LearningPathMascotStyle.standard,
    child: child,
  );

  Future<LearningProgressSnapshot> _snapshotWithLocalLeagueFinalization(
    LearningProgressStore store,
    DateTime now,
  ) async {
    if (!widget.schoolMode &&
        !widget.lanSocialAllowed &&
        widget.scope == LearningScope.personal) {
      final currentLearningDay = dayKeyOf(now);
      final currentWeek = learningWeekKey(currentLearningDay);
      try {
        await store.catchUpLocalWeeklyLeagues(
          currentWeekKey: currentWeek,
          finalizedAt: now.toUtc(),
        );
      } catch (_) {
        // 任意の端末内League catch-upに失敗しても、学習Pathの永続進捗は表示する。
      }
    }
    return store.snapshot(widget.scope);
  }

  GameContentProjectionResult? get _content {
    final game = _game;
    if (game == null) return null;
    final activeRepairCount = widget.schoolMode
        ? 0
        : _repairPlan?.targets
                  .where(
                    (target) =>
                        target.reason == LearningRepairReason.activeNeed,
                  )
                  .length ??
              0;
    final base = _contentProjection.build(
      catalog: _catalog,
      path: game.path,
      duePracticeCount: game.duePracticeCount,
      activeRepairCount: activeRepairCount,
      schoolMode: widget.schoolMode,
      timedChallengeGemCost: game.economy.timedChallengePassGemCost,
      timedChallengePassActive: game.economy.timedChallengePassActive,
      canPurchaseTimedChallengePass: game.economy.canPurchaseTimedChallengePass,
    );
    final hearts = _snapshot?.challengeHearts;
    final heartsEmpty = !widget.schoolMode && (hearts?.current ?? 0) <= 0;
    final modes = <PracticeModeView>[
      if (!widget.schoolMode)
        PracticeModeView(
          id: 'practice:heart-recovery',
          title: 'ハート回復練習',
          description: hearts?.current == hearts?.maximum
              ? 'ハートは満タンです。減ったときに、固定課題の練習で1個戻せます。'
              : '固定課題を最後まで見直すと、ハートを1個戻せます。',
          kind: PracticeModeKind.heartRecovery,
          enabled: hearts != null && hearts.current < hearts.maximum,
          badge: hearts == null ? null : '${hearts.current}/${hearts.maximum}',
        ),
      for (final mode in base.practiceModes)
        if (heartsEmpty)
          PracticeModeView(
            id: mode.id,
            title: mode.title,
            description: 'ハート回復練習を終えると再開できます。',
            kind: mode.kind,
            enabled: false,
            badge: 'ハート0',
          )
        else
          mode,
    ];
    return GameContentProjectionResult(
      stories: base.stories,
      practiceModes: List.unmodifiable(modes),
    );
  }

  bool get _personalHeartsEmpty =>
      !widget.schoolMode && (_snapshot?.challengeHearts?.current ?? 0) <= 0;

  Future<bool> _ensureNormalLearningCanStart() async {
    if (widget.schoolMode) return true;
    final now = _now();
    try {
      final result = await _progressStore(now).refreshChallengeHearts(
        learningDay: dayKeyOf(now),
        occurredAt: now.toUtc(),
      );
      if (result.recovered > 0) await _reloadSnapshot();
      if (result.state.current > 0) return true;
    } catch (_) {
      // 最後に検証できたsnapshotが0なら安全側に開始を止める。
      if (!_personalHeartsEmpty) return true;
    }
    if (mounted) {
      _message('ハートがありません。練習タブの「ハート回復練習」で1個戻せます。');
    }
    return false;
  }

  LearningRepairPlan? get _repairPlan {
    final snapshot = _snapshot;
    if (snapshot == null || _detailCache.isEmpty) return null;
    return _repairPlanner.build(
      snapshot: snapshot,
      catalog: _catalog
          .map((unit) => _detailCache[unit.id])
          .whereType<UnitDetail>(),
      today: dayKeyOf(_now()),
    );
  }

  DailyAudioPracticePlan? get _dailyAudioPlan {
    final game = _game;
    final snapshot = _snapshot;
    if (game == null || snapshot == null) return null;
    return _dailyAudioPlanner.build(
      catalog: _catalog,
      path: game.path,
      snapshot: snapshot,
      learningDay: dayKeyOf(_now()),
    );
  }

  Map<String, _NodeTarget> get _targets {
    final out = <String, _NodeTarget>{};
    for (final unit in _catalog) {
      for (final concept in unit.concepts) {
        for (final kind in GamePathNodeKind.values.where(
          (candidate) => candidate != GamePathNodeKind.legendary,
        )) {
          final id = GamePathProjection.nodeId(unit.id, concept.key, kind);
          out[id] = _NodeTarget(
            nodeId: id,
            unit: unit,
            conceptKey: concept.key,
            conceptLabel: concept.label,
            kind: kind,
          );
        }
      }
      final legendaryId = GamePathProjection.unitLegendaryNodeId(unit.id);
      out[legendaryId] = _NodeTarget(
        nodeId: legendaryId,
        unit: unit,
        conceptKey: 'unit',
        conceptLabel: unit.title,
        kind: GamePathNodeKind.legendary,
      );
    }
    return out;
  }

  Map<String, _NodeTarget> get _notationTargets => {
    for (final unit in _catalog)
      for (final concept in unit.concepts)
        _notationNodeId(unit.id, concept.key): _NodeTarget(
          nodeId: _notationNodeId(unit.id, concept.key),
          unit: unit,
          conceptKey: concept.key,
          conceptLabel: concept.label,
          kind: GamePathNodeKind.practice,
        ),
  };

  List<NotationLabEntry> get _notationEntries {
    final game = _game;
    if (game == null) return const [];
    final pathNodes = {
      for (final unit in game.path.units)
        for (final node in unit.nodes) node.id: node,
    };
    final completed = {
      for (final node in _snapshot?.nodes ?? const <LearningNodeProgress>[])
        if (node.state == LearningNodeState.cleared) node.nodeId,
    };
    return [
      for (final unit in _catalog)
        for (final concept in unit.concepts)
          NotationLabEntry(
            id: _notationNodeId(unit.id, concept.key),
            unitTitle: unit.title,
            conceptLabel: concept.label,
            description: '矢印・式・単位・グラフを、意味の順に扱います。',
            state: _notationState(
              unlocked:
                  pathNodes[GamePathProjection.nodeId(
                        unit.id,
                        concept.key,
                        GamePathNodeKind.practice,
                      )]
                      ?.state !=
                  GamePathNodeState.locked,
              completed: completed.contains(
                _notationNodeId(unit.id, concept.key),
              ),
              due: _dueSkillIds.contains('${unit.id}/${concept.key}'),
            ),
          ),
    ];
  }

  GamePathNode? _nodeFor(String id) {
    final game = _game;
    if (game == null) return null;
    for (final unit in game.path.units) {
      for (final node in unit.nodes) {
        if (node.id == id) return node;
      }
    }
    return null;
  }

  Set<String> get _dueSkillIds {
    final today = dayKeyOf(_now());
    final catalogSkillIds = {
      for (final unit in _catalog)
        for (final concept in unit.concepts) '${unit.id}/${concept.key}',
    };
    return {
      for (final skill in _snapshot?.skills ?? const [])
        if (catalogSkillIds.contains(skill.skillId) &&
            (skill.lastOutcome == LearningSkillOutcome.needsPractice ||
                skill.nextDueDay.compareTo(today) <= 0))
          skill.skillId,
    };
  }

  int get _explanationReviewCount =>
      (_snapshot?.events ?? const <LearningEventRecord>[])
          .where(
            (event) =>
                event.activityKind == LearningActivityKind.speak &&
                event.outcome != LearningAttemptOutcome.retryNeeded,
          )
          .length;

  LearningLocalCoopRun? get _currentLocalCoopRun {
    if (widget.schoolMode) return null;
    final today = dayKeyOf(_now());
    final candidates = [
      for (final run
          in _snapshot?.localCoopRuns ?? const <LearningLocalCoopRun>[])
        if (run.definitionVersion ==
                LocalWeeklyLeagueProjection.pairBridgeDefinitionVersion &&
            run.startDay.compareTo(today) <= 0 &&
            run.endDay.compareTo(today) >= 0)
          run,
    ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return candidates.firstOrNull;
  }

  LearningFriendsQuestBoardSource? get _friendsQuestSource {
    switch (_questAudience) {
      case LearningQuestAudience.schoolLocal:
        return null;
      case LearningQuestAudience.personalLanConsented:
        return _lanFriendsQuestSource;
      case LearningQuestAudience.personalLocalOnly:
        final run = _currentLocalCoopRun;
        if (run != null) {
          return LearningFriendsQuestBoardSource.localRun(run);
        }
        if (_localWeeklyLeague?.availability ==
            LocalWeeklyLeagueAvailability.active) {
          return null;
        }
        return LearningFriendsQuestBoardSource.localInvite(
          weekKey: learningWeekKey(dayKeyOf(_now())),
        );
    }
  }

  int get _schoolDailyQuestProgress {
    final plan = _activeQuestPlan;
    final snapshot = _snapshot;
    if (plan == null ||
        plan.learningDay != dayKeyOf(_now().toLocal()) ||
        snapshot == null ||
        !widget.schoolMode) {
      return 0;
    }
    final definition = plan.dailyDefinition;
    final distinct = <String>{};
    for (final event in snapshot.events) {
      if (event.scope != LearningScope.schoolLocal ||
          !definition.includesLearningDay(event.learningDay) ||
          event.outcome == LearningAttemptOutcome.retryNeeded ||
          event.evidence.rank < definition.minimumEvidence.rank ||
          (definition.allowedOrigins.isNotEmpty &&
              !definition.allowedOrigins.contains(event.origin)) ||
          (definition.allowedActivityKinds.isNotEmpty &&
              !definition.allowedActivityKinds.contains(event.activityKind))) {
        continue;
      }
      distinct.add('${event.learningDay}/${event.nodeId}');
    }
    return distinct.length.clamp(0, definition.target);
  }

  List<LearningQuestBoardItem> get _questBoardItems {
    final plan = _activeQuestPlan;
    final snapshot = _snapshot;
    if (plan == null ||
        plan.learningDay != dayKeyOf(_now().toLocal()) ||
        snapshot == null) {
      return const [];
    }
    return _questBoardProjection.build(
      plan: plan,
      persistedQuests: snapshot.quests,
      friends: _friendsQuestSource,
      schoolDailyProgress: _schoolDailyQuestProgress,
    );
  }

  List<GameQuest> get _headerQuests => [
    for (final item in _questBoardItems) _gameQuest(item),
  ];

  GameQuest _gameQuest(LearningQuestBoardItem item) => GameQuest(
    id: item.id,
    title: item.title,
    description: item.description,
    kind: switch (item.kind) {
      LearningQuestPresentationKind.daily => GameQuestKind.daily,
      LearningQuestPresentationKind.monthly => GameQuestKind.monthly,
      LearningQuestPresentationKind.friend => GameQuestKind.friend,
      LearningQuestPresentationKind.classroom => GameQuestKind.classroom,
    },
    state: switch (item.state) {
      LearningQuestBoardState.active => GameQuestState.active,
      LearningQuestBoardState.completed => GameQuestState.completed,
      LearningQuestBoardState.rewarded => GameQuestState.claimed,
    },
    current: item.current,
    target: item.target,
    rewardLabel: item.rewardGems > 0 ? '結晶${item.rewardGems}個' : null,
    actionLabel: item.action.label,
  );

  GameTab _questTabFor(GameQuest quest) {
    final item = _questBoardItems
        .where((candidate) => candidate.id == quest.id)
        .firstOrNull;
    return switch (item?.action.destination) {
      LearningQuestDestination.stories => GameTab.stories,
      LearningQuestDestination.practice => GameTab.practice,
      LearningQuestDestination.notation => GameTab.notation,
      LearningQuestDestination.profile => GameTab.profile,
      LearningQuestDestination.lanSocial => GameTab.league,
      LearningQuestDestination.path || null => GameTab.path,
    };
  }

  Future<void> _openQuestAction(String questId) async {
    final item = _questBoardItems
        .where((candidate) => candidate.id == questId)
        .firstOrNull;
    if (item == null) return;
    // bottom sheetのpopを先に確定し、同じNavigatorへactivity routeを積む。
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    switch (item.action.focus) {
      case LearningQuestFocus.currentPathNode:
        final currentId = _game?.path.currentNodeId;
        final node = currentId == null ? null : _nodeFor(currentId);
        if (node != null && node.canOpen) await _openNode(node);
      case LearningQuestFocus.nextStory:
        final currentId = _game?.path.currentNodeId;
        final episode = _content?.stories
            .where(
              (candidate) =>
                  candidate.state == GameContentState.available ||
                  candidate.state == GameContentState.inProgress,
            )
            .where(
              (candidate) => currentId == null || candidate.id == currentId,
            )
            .firstOrNull;
        final fallback =
            episode ??
            _content?.stories
                .where(
                  (candidate) =>
                      candidate.state == GameContentState.available ||
                      candidate.state == GameContentState.inProgress,
                )
                .firstOrNull;
        if (fallback != null) await _openStory(fallback);
      case LearningQuestFocus.dailyListening:
        final mission = _dailyAudioPlan?.missionOf(
          DailyAudioMissionKind.listening,
        );
        if (mission != null) await _openDailyAudio(mission);
      case LearningQuestFocus.dailySpeaking:
        final mission = _dailyAudioPlan?.missionOf(
          DailyAudioMissionKind.speaking,
        );
        if (mission != null) await _openDailyAudio(mission);
      case LearningQuestFocus.nextDiagram:
        final currentId = _game?.path.currentNodeId;
        final current = currentId == null ? null : _nodeFor(currentId);
        final node = current?.kind == GamePathNodeKind.practice
            ? current
            : _game?.path.units
                  .expand((unit) => unit.nodes)
                  .where(
                    (candidate) =>
                        candidate.kind == GamePathNodeKind.practice &&
                        (candidate.state == GamePathNodeState.available ||
                            candidate.state == GamePathNodeState.inProgress),
                  )
                  .firstOrNull;
        if (node != null) await _openNode(node);
      case LearningQuestFocus.nextNotation:
        final entry = _notationEntries
            .where((candidate) => candidate.state == NotationLabState.available)
            .firstOrNull;
        if (entry != null) await _openNotation(entry);
      case LearningQuestFocus.duePractice:
        final mode = _content?.practiceModes
            .where(
              (candidate) =>
                  candidate.kind == PracticeModeKind.personalized &&
                  candidate.enabled,
            )
            .firstOrNull;
        if (mode != null) await _openPractice(mode);
      case LearningQuestFocus.monthlyBadgeCollection:
        return;
      case LearningQuestFocus.localFriendsQuest:
        await _startLocalCoop();
      case LearningQuestFocus.lanFriendsQuest:
        await _openLanSocial();
    }
  }

  LocalWeeklyLeagueView? get _localWeeklyLeague {
    final snapshot = _snapshot;
    if (snapshot == null || widget.schoolMode) return null;
    final weekKey = learningWeekKey(dayKeyOf(_now()));
    return LocalWeeklyLeagueProjection.project(
      scope: widget.scope,
      weekKey: weekKey,
      runs: snapshot.localCoopRuns,
      contributions: _localCoopContributions,
      history: snapshot.localLeagueHistory,
    );
  }

  LearningLocalCoopRun? get _activeContributionRun {
    final snapshot = _snapshot;
    if (snapshot == null || widget.schoolMode) return null;
    final pair = _currentLocalCoopRun;
    if (pair != null && !pair.completed) return pair;
    final activeRunId = _localWeeklyLeague?.activeRunId;
    if (activeRunId == null) return null;
    return snapshot.localCoopRuns
        .where((run) => run.runId == activeRunId && !run.completed)
        .firstOrNull;
  }

  bool _nodeBelongsToDueSkill(GamePathNode node) {
    final target = _targets[node.id];
    return target != null &&
        _dueSkillIds.contains('${target.unit.id}/${target.conceptKey}');
  }

  Future<UnitDetail?> _detailFor(String unitId) async {
    final cached = _detailCache[unitId];
    if (cached != null) return cached;
    final detail = await widget.units.detail(unitId);
    if (detail != null) _detailCache[unitId] = detail;
    return detail;
  }

  Future<LearningRun> _startRun(_NodeTarget target) async {
    final now = DateTime.now();
    final store = _progressStore(now);
    final existing = await store.activeRun(
      scope: widget.scope,
      nodeId: target.nodeId,
    );
    if (existing != null) {
      final persisted = await store.snapshot(widget.scope);
      final retryPrefix =
          'event:${existing.runId}:need:${existing.activityIndex}:';
      final currentRetryWasPartiallySaved = persisted.events.any(
        (event) => event.eventId.startsWith(retryPrefix),
      );
      final reopenedAt = now.toUtc();
      if (currentRetryWasPartiallySaved ||
          !reopenedAt.isAfter(existing.updatedAt)) {
        // need eventだけ成功してheart/checkpointが失敗した場合は、同じpayloadを
        // 再送できるよう時刻を変えない。未来時刻へも巻き戻さない。
        return existing;
      }
      // 完了済みの前回失敗から再入場した試行だけ、回答を保存せず開始時刻を
      // 進める。これによりRepair後の再観測を古い証拠として捨てない。
      return store.checkpointRun(
        existing.runId,
        activityIndex: existing.activityIndex,
        updatedAt: reopenedAt,
      );
    }
    final run = LearningRun(
      runId:
          'run:${now.microsecondsSinceEpoch}:${(_runSerial++).toRadixString(36)}',
      scope: widget.scope,
      nodeId: target.nodeId,
      activityIndex: 0,
      challengeHearts: widget.schoolMode
          ? null
          : LearningChallengeHeartState.defaultMaximum,
      contentVersion: _contentVersion,
      updatedAt: now.toUtc(),
    );
    final started = await store.beginRun(run);
    await _reloadSnapshot();
    return started;
  }

  Future<void> _openNode(
    GamePathNode node, {
    LearningOrigin? eventOrigin,
    bool spacedReview = false,
    int? practiceAttemptOverride,
    LearningRepairTarget? repairTarget,
  }) async {
    final target = _targets[node.id];
    if (target == null || !node.canOpen || _openingNodeId != null || !mounted) {
      return;
    }
    if (!await _ensureNormalLearningCanStart() || !mounted) return;
    setState(() => _openingNodeId = node.id);
    try {
      final detail = await _detailFor(target.unit.id);
      if (!mounted) return;
      if (target.kind == GamePathNodeKind.legendary) {
        final orderedSections = <Section>[];
        for (final concept in target.unit.concepts) {
          final section = detail?.sectionFor(concept.key);
          if (section == null) {
            _message('この単元の高難度課題を開けませんでした。もう一度お試しください。');
            return;
          }
          orderedSections.add(section);
        }
        if (orderedSections.isEmpty) {
          _message('この単元の高難度課題を開けませんでした。もう一度お試しください。');
          return;
        }
        final run = await _startRun(target);
        if (!mounted) return;
        await _pushUnitLegendary(
          target: target,
          sections: orderedSections,
          run: run,
        );
        if (mounted) await _reloadSnapshot();
        return;
      }
      final section = detail?.sectionFor(target.conceptKey);
      if (section == null) {
        _message('この教材を開けませんでした。もう一度お試しください。');
        return;
      }
      final run = await _startRun(target);
      if (!mounted) return;
      await _pushActivity(
        target: target,
        section: section,
        run: run,
        eventOrigin: eventOrigin,
        spacedReview: spacedReview,
        practiceAttemptOverride: practiceAttemptOverride,
        repairTarget: repairTarget,
      );
      if (mounted) await _reloadSnapshot();
    } catch (_) {
      if (mounted) _message('学習を開始できませんでした。もう一度お試しください。');
    } finally {
      if (mounted) setState(() => _openingNodeId = null);
    }
  }

  Future<void> _pushActivity({
    required _NodeTarget target,
    required Section section,
    required LearningRun run,
    LearningOrigin? eventOrigin,
    bool spacedReview = false,
    int? practiceAttemptOverride,
    LearningRepairTarget? repairTarget,
  }) async {
    final startedAt = DateTime.now();
    final attempt =
        practiceAttemptOverride ??
        (spacedReview
            ? _spacedReviewAttempt(target, run)
            : _practiceAttempt(target, run: run));
    final needEvidence = LearningNeedEvidenceBuffer();
    final heartLosses = _HeartLossQueue(
      run: run,
      onApply: _applyFixedTaskHeartLoss,
    );
    final observedNeedWrites = _ObservedNeedWriteQueue(
      onPersist: (evidence) => _recordActivityObservedNeed(
        target: target,
        run: run,
        evidence: evidence,
        origin: repairTarget != null
            ? LearningOrigin.practice
            : eventOrigin ?? _originFor(target.kind),
      ),
    );
    void recordNeedEvidence(LearningNeedEvidence evidence) {
      needEvidence.record(evidence);
      observedNeedWrites.record(evidence);
    }

    void reportHeartLoss(LearningHeartLossEvidence evidence) {
      heartLosses.reportAfter(evidence, beforeApply: observedNeedWrites.drain);
    }

    Future<void>? save;
    BuildContext? activityContext;
    Future<void> startCompletionSave() {
      final existing = save;
      if (existing != null) return existing;
      late final Future<void> work;
      work = () async {
        await observedNeedWrites.drain();
        await heartLosses.drain();
        final action = await _commitNode(
          target: target,
          run: run,
          eventOrigin: eventOrigin,
          spacedReview: spacedReview,
          needEvidence: needEvidence,
          repairTarget: repairTarget,
          elapsed: DateTime.now().difference(startedAt),
        );
        final routeContext = activityContext;
        if (action == GameCompletionAction.nextStep &&
            routeContext != null &&
            routeContext.mounted) {
          Navigator.of(routeContext).pop();
        }
      }();
      save = work;
      // void callbackのactivityでも保存失敗をunhandledにしない。一方、章ボスは
      // raw Futureをawaitして失敗表示と再試行を行うため、例外自体は潰さない。
      unawaited(
        work.then<void>(
          (_) {},
          onError: (Object error, StackTrace stackTrace) {
            if (identical(save, work)) save = null;
          },
        ),
      );
      return work;
    }

    void completed() => unawaited(_guardRouteSave(startCompletionSave()));

    void returnToPath(BuildContext routeContext) {
      unawaited(_returnAfterSave(routeContext, save));
    }

    void notCleared() {
      save ??= _guardRouteSave(
        _recordUnclearedNeed(
          target: target,
          run: run,
          needEvidence: needEvidence,
          afterRecorded: () async {
            await observedNeedWrites.drain();
            await heartLosses.drain();
            await _ensureUnclearedRunAdvanced(run);
          },
        ),
      );
    }

    final activityStatus = _beginActivityStatus();
    final route = MaterialPageRoute<void>(
      builder: (routeContext) {
        activityContext = routeContext;
        final activity = switch (target.kind) {
          GamePathNodeKind.lesson => ScienceLessonScreen(
            section: section,
            conceptLabel: target.conceptLabel,
            practiceAttempt: attempt,
            onCompleted: completed,
            onReturnToPath: () => returnToPath(routeContext),
          ),
          GamePathNodeKind.practice when spacedReview => ScienceLegendaryScreen(
            section: section,
            conceptLabel: target.conceptLabel,
            practiceAttempt: attempt,
            isUnlocked: true,
            presentation: ScienceLegendaryPresentation.spacedReview,
            onCompleted: completed,
            onNotCleared: notCleared,
            onNeedEvidence: recordNeedEvidence,
            onHeartLoss: reportHeartLoss,
            onReturnToPath: () => returnToPath(routeContext),
          ),
          GamePathNodeKind.practice => ScienceDiagramScreen(
            section: section,
            conceptLabel: target.conceptLabel,
            practiceAttempt: attempt,
            onCompleted: completed,
            onNeedEvidence: recordNeedEvidence,
            onHeartLoss: reportHeartLoss,
            onReturnToPath: () => returnToPath(routeContext),
          ),
          GamePathNodeKind.story => ScienceStoryScreen(
            section: section,
            conceptLabel: target.conceptLabel,
            practiceAttempt: attempt,
            onCompleted: completed,
            onNeedEvidence: recordNeedEvidence,
            onHeartLoss: reportHeartLoss,
            onReturnToPath: () => returnToPath(routeContext),
          ),
          GamePathNodeKind.listening => ScienceListeningScreen(
            section: section,
            conceptLabel: target.conceptLabel,
            practiceAttempt: attempt,
            repairNeedCode: repairTarget?.needCode,
            onCompleted: completed,
            onNeedEvidence: recordNeedEvidence,
            onHeartLoss: reportHeartLoss,
            onReturnToPath: () => returnToPath(routeContext),
          ),
          GamePathNodeKind.speaking => ScienceSpeakListenScreen(
            section: section,
            conceptLabel: target.conceptLabel,
            practiceAttempt: attempt,
            onCompleted: completed,
            onNeedEvidence: recordNeedEvidence,
            onHeartLoss: reportHeartLoss,
            onReturnToPath: () => returnToPath(routeContext),
          ),
          GamePathNodeKind.challenge => OfflinePracticeScreen(
            section: section,
            conceptLabel: target.conceptLabel,
            missionKind: MissionKind.caseRetry,
            practiceAttempt: attempt,
            onCheckpointCompleted: startCompletionSave,
            onNeedEvidence: recordNeedEvidence,
            onHeartLoss: reportHeartLoss,
          ),
          GamePathNodeKind.legendary => ScienceLegendaryScreen(
            section: section,
            conceptLabel: target.conceptLabel,
            practiceAttempt: attempt,
            isUnlocked: switch (_nodeFor(target.nodeId)?.state) {
              GamePathNodeState.legendaryAvailable ||
              GamePathNodeState.legendaryCompleted => true,
              _ => false,
            },
            onCompleted: completed,
            onNotCleared: notCleared,
            onNeedEvidence: recordNeedEvidence,
            onHeartLoss: reportHeartLoss,
            onReturnToPath: () => returnToPath(routeContext),
          ),
        };
        final needsSharedExit = switch (target.kind) {
          GamePathNodeKind.lesson ||
          GamePathNodeKind.story ||
          GamePathNodeKind.listening ||
          GamePathNodeKind.speaking => true,
          _ => false,
        };
        return _activityFrame(
          status: activityStatus,
          onExit: needsSharedExit
              ? () => Navigator.maybePop(routeContext)
              : null,
          child: activity,
        );
      },
    );
    try {
      await Navigator.of(context).push(route);
      await observedNeedWrites.drain();
      await heartLosses.drain();
    } finally {
      _endActivityStatus(activityStatus);
    }
  }

  Future<void> _pushUnitLegendary({
    required _NodeTarget target,
    required List<Section> sections,
    required LearningRun run,
  }) async {
    final startedAt = DateTime.now();
    final needEvidence = LearningNeedEvidenceBuffer();
    final heartLosses = _HeartLossQueue(
      run: run,
      onApply: _applyFixedTaskHeartLoss,
    );
    final observedNeedWrites = _ObservedNeedWriteQueue(
      onPersist: (evidence) => _recordActivityObservedNeed(
        target: target,
        run: run,
        evidence: evidence,
        origin: LearningOrigin.challenge,
      ),
    );
    void recordNeedEvidence(LearningNeedEvidence evidence) {
      needEvidence.record(evidence);
      observedNeedWrites.record(evidence);
    }

    void reportHeartLoss(LearningHeartLossEvidence evidence) {
      heartLosses.reportAfter(evidence, beforeApply: observedNeedWrites.drain);
    }

    final conceptsByKey = {
      for (final concept in target.unit.concepts) concept.key: concept,
    };
    final challenges = <ScienceUnitLegendaryChallenge>[
      for (var index = 0; index < sections.length; index++)
        ScienceUnitLegendaryChallenge(
          section: sections[index],
          conceptLabel:
              conceptsByKey[sections[index].conceptKey]?.label ??
              sections[index].title,
          practiceAttempt: _unitLegendaryAttempt(
            target,
            run: run,
            conceptIndex: index,
          ),
        ),
    ];
    Future<void>? save;
    BuildContext? activityContext;
    void completed() {
      save ??= _guardRouteSave(() async {
        await observedNeedWrites.drain();
        await heartLosses.drain();
        final action = await _commitUnitLegendary(
          target: target,
          run: run,
          needEvidence: needEvidence,
          elapsed: DateTime.now().difference(startedAt),
        );
        final routeContext = activityContext;
        if (action == GameCompletionAction.nextStep &&
            routeContext != null &&
            routeContext.mounted) {
          Navigator.of(routeContext).pop();
        }
      }());
    }

    void notCleared() {
      save ??= _guardRouteSave(() async {
        await observedNeedWrites.drain();
        await _recordUnitLegendaryFailure(
          target: target,
          run: run,
          needEvidence: needEvidence,
          afterRecorded: () async {
            await heartLosses.drain();
            await _ensureUnclearedRunAdvanced(run);
          },
        );
      }());
    }

    void returnToPath(BuildContext routeContext) {
      unawaited(_returnAfterSave(routeContext, save));
    }

    final activityStatus = _beginActivityStatus();
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (routeContext) {
            activityContext = routeContext;
            return _activityFrame(
              status: activityStatus,
              child: ScienceUnitLegendaryScreen(
                unitTitle: target.unit.title,
                challenges: challenges,
                isUnlocked: _nodeFor(target.nodeId)?.canOpen ?? false,
                onCompleted: completed,
                onNeedEvidence: recordNeedEvidence,
                onHeartLoss: reportHeartLoss,
                onNotCleared: notCleared,
                onReturnToPath: () => returnToPath(routeContext),
              ),
            );
          },
        ),
      );
      await observedNeedWrites.drain();
      await heartLosses.drain();
    } finally {
      _endActivityStatus(activityStatus);
    }
  }

  Future<void> _returnAfterSave(
    BuildContext routeContext,
    Future<void>? save,
  ) async {
    try {
      if (save != null) await save;
    } catch (_) {
      // Pathは未完了のまま。帰還後に再試行できる。
    }
    if (routeContext.mounted) Navigator.of(routeContext).pop();
  }

  Future<void> _guardRouteSave(Future<void> work) async {
    try {
      await work;
    } catch (_) {
      // 各保存処理がユーザー向け再試行案内を出す。callback直後からlistenerを
      // 付け、明示的なPath帰還より先に失敗してもunhandled Futureにしない。
    }
  }

  Future<GameCompletionAction?> _commitNode({
    required _NodeTarget target,
    required LearningRun run,
    LearningOrigin? eventOrigin,
    bool spacedReview = false,
    LearningNeedEvidenceBuffer? needEvidence,
    LearningRepairTarget? repairTarget,
    required Duration elapsed,
  }) async {
    final now = DateTime.now();
    final observedNeeds =
        needEvidence?.observedBySkill(target.unit.id) ?? const {};
    final demonstratedNeeds =
        needEvidence?.demonstratedBySkill(target.unit.id) ?? const {};
    final hasObservedNeed = observedNeeds.values.any(
      (codes) => codes.isNotEmpty,
    );
    final hasDemonstratedNeed = demonstratedNeeds.values.any(
      (codes) => codes.isNotEmpty,
    );
    final repairNeedCode = repairTarget?.needCode;
    final resolvesRepair =
        repairTarget != null &&
        repairNeedCode != null &&
        !hasObservedNeed &&
        (demonstratedNeeds[repairTarget.skillId]?.contains(repairNeedCode) ??
            false);
    final resolvedNeeds = resolvesRepair
        ? <String, Set<String>>{
            repairTarget.skillId: <String>{repairNeedCode},
          }
        : const <String, Set<String>>{};
    final isDueStructuredPractice =
        spacedReview &&
        eventOrigin == LearningOrigin.practice &&
        target.kind == GamePathNodeKind.practice &&
        _dueSkillIds.contains('${target.unit.id}/${target.conceptKey}');
    final outcome = hasObservedNeed
        ? LearningAttemptOutcome.corrected
        : hasDemonstratedNeed
        ? LearningAttemptOutcome.structuredSuccess
        : _outcomeFor(target.kind);
    final evidence = hasObservedNeed
        ? LearningEvidenceLevel.structuredCorrection
        : isDueStructuredPractice && hasDemonstratedNeed
        ? LearningEvidenceLevel.spacedTransfer
        : hasDemonstratedNeed
        ? target.kind == GamePathNodeKind.challenge
              ? LearningEvidenceLevel.transfer
              : LearningEvidenceLevel.structuredCorrection
        : isDueStructuredPractice
        ? LearningEvidenceLevel.spacedTransfer
        : _evidenceFor(target.kind);
    final event = LearningEventCommand(
      eventId: 'event:${run.runId}',
      scope: widget.scope,
      origin: widget.schoolMode
          ? LearningOrigin.schoolAssignment
          : repairTarget != null
          ? LearningOrigin.practice
          : eventOrigin ?? _originFor(target.kind),
      courseId: _courseId,
      nodeId: target.nodeId,
      activityId: 'path.${target.kind.name}.v1',
      skillIds: {'${target.unit.id}/${target.conceptKey}'},
      activityKind: _activityKindFor(target.kind),
      outcome: outcome,
      evidence: evidence,
      contentVersion: _contentVersion,
      learningDay: dayKeyOf(now),
      occurredAt: now.toUtc(),
      runId: run.runId,
      practiceNeedCodes: observedNeeds,
      resolvedPracticeNeedCodes: resolvedNeeds,
      repairResolution: resolvesRepair ? repairTarget.resolutionMetadata : null,
    );
    try {
      final result = await _progressStore(now).commit(event);
      await _reloadSnapshot();
      await _contributeSelectedCoopParticipant(result);
      unawaited(_dispatchLanSocialAfterCommit(result));
      if (!mounted) return null;
      return _showCompletionCelebration(
        result: result,
        elapsed: elapsed,
        eyebrow: _completionEyebrow(target.kind),
        title: result.inserted ? 'やった！一歩進んだ' : 'もう一度、確かめられた',
        message: _completionMessage(target.kind, hasObservedNeed),
      );
    } catch (_) {
      if (mounted) _message('端末への進捗保存が完了していません。Pathからもう一度開けます。');
      rethrow;
    }
  }

  Future<GameCompletionAction?> _commitUnitLegendary({
    required _NodeTarget target,
    required LearningRun run,
    required LearningNeedEvidenceBuffer needEvidence,
    required Duration elapsed,
  }) async {
    final now = DateTime.now();
    final unitSkillId = GamePathProjection.unitLegendarySkillId(target.unit.id);
    final unitNodeWasCleared =
        (_snapshot?.nodes ?? const <LearningNodeProgress>[]).any(
          (node) =>
              node.nodeId == target.nodeId &&
              node.state == LearningNodeState.cleared,
        );
    final legacyPromoted = _legacyUnitLegendaryWasFullyCleared(target.unit);
    final event = LearningEventCommand(
      eventId: 'event:${run.runId}',
      scope: widget.scope,
      origin: widget.schoolMode
          ? LearningOrigin.schoolAssignment
          : LearningOrigin.challenge,
      courseId: _courseId,
      nodeId: target.nodeId,
      activityId: 'path.unit-legendary.v2',
      skillIds: {unitSkillId},
      activityKind: LearningActivityKind.transfer,
      outcome: LearningAttemptOutcome.structuredSuccess,
      // 新しいunit skillの初回はtransfer、期限到来後だけspacedTransfer。
      // 旧concept Legendary全clearからの初回v2記録はspacedとしてbootstrapし、
      // node初回報酬・questを重複生成しない。
      evidence: unitNodeWasCleared || legacyPromoted
          ? LearningEvidenceLevel.spacedTransfer
          : LearningEvidenceLevel.transfer,
      contentVersion: _contentVersion,
      learningDay: dayKeyOf(now),
      occurredAt: now.toUtc(),
      runId: run.runId,
      practiceNeedCodes: needEvidence.observedBySkill(target.unit.id),
    );
    try {
      final result = await _progressStore(now).commit(event);
      await _reloadSnapshot();
      await _contributeSelectedCoopParticipant(result);
      unawaited(_dispatchLanSocialAfterCommit(result));
      if (!mounted) return null;
      return _showCompletionCelebration(
        result: result,
        elapsed: elapsed,
        eyebrow: 'UNIT LEGENDARY COMPLETE',
        title: '高難度チャレンジをクリア！',
        message: '${target.unit.title}の固定課題を最後まで確かめました。',
      );
    } catch (_) {
      if (mounted) _message('端末への進捗保存が完了していません。Pathからもう一度開けます。');
      rethrow;
    }
  }

  Future<GameCompletionAction?> _showCompletionCelebration({
    required CommitLearningResult result,
    required Duration elapsed,
    required String eyebrow,
    required String title,
    required String message,
  }) {
    // 冪等再送では保存層が既存eventに紐づくrewardを返す。今回新しく得た値として
    // 再表示しないよう、insertされたcommitだけを獲得報酬として扱う。
    final xp = result.inserted
        ? result.rewards
              .where((entry) => entry.type == LearningRewardType.xp)
              .fold(0, (sum, entry) => sum + entry.amount)
        : 0;
    final gems = result.inserted
        ? result.rewards
              .where((entry) => entry.type == LearningRewardType.gems)
              .fold(0, (sum, entry) => sum + entry.amount)
        : 0;
    return showGameCompletionCelebration(
      context,
      summary: GameCompletionSummary(
        eyebrow: widget.schoolMode ? 'CLASS MISSION COMPLETE' : eyebrow,
        title: widget.schoolMode ? 'この端末の授業ミッションを完了' : title,
        message: widget.schoolMode
            ? '個人のXP・結晶・Pathには加算せず、この端末の授業記録だけを更新しました。'
            : message,
        elapsed: elapsed,
        xpAwarded: xp,
        gemsAwarded: gems,
        showPersonalRewards: !widget.schoolMode,
        mascotStyle:
            _game?.economy.equippedPathMascotStyle ??
            LearningPathMascotStyle.standard,
      ),
    );
  }

  Future<void> _recordUnclearedNeed({
    required _NodeTarget target,
    required LearningRun run,
    required LearningNeedEvidenceBuffer needEvidence,
    required Future<void> Function() afterRecorded,
  }) async {
    final now = DateTime.now();
    final observedAt = run.updatedAt.toUtc();
    final learningDay = dayKeyOf(observedAt.toLocal());
    final observedNeeds = needEvidence.observedBySkill(target.unit.id);
    if (observedNeeds.values.any((codes) => codes.isNotEmpty)) {
      final event = LearningEventCommand(
        eventId:
            'event:${run.runId}:need:${run.activityIndex}:$learningDay:'
            '${_stableNeedFingerprint(observedNeeds)}',
        scope: widget.scope,
        origin: widget.schoolMode
            ? LearningOrigin.schoolAssignment
            : target.kind == GamePathNodeKind.practice
            ? LearningOrigin.practice
            : _originFor(target.kind),
        courseId: _courseId,
        nodeId: target.nodeId,
        activityId: 'path.${target.kind.name}.retry.v1',
        skillIds: {'${target.unit.id}/${target.conceptKey}'},
        activityKind: _activityKindFor(target.kind),
        outcome: LearningAttemptOutcome.retryNeeded,
        evidence: LearningEvidenceLevel.participation,
        contentVersion: _contentVersion,
        learningDay: learningDay,
        occurredAt: observedAt,
        runId: null,
        practiceNeedCodes: observedNeeds,
      );
      await _progressStore(now).commit(event);
    }
    await afterRecorded();
  }

  /// 固定課題の誤答を、heart消費より先に独立したneed eventとして保存する。
  ///
  /// 画面を訂正途中で閉じてもRepair対象だけを失わないための境界。回答本文・
  /// 選択肢IDは受け取らず、catalogの一般化needだけを冪等に保存する。通常完了時の
  /// eventにも同じneedが含まれるが、projectorは同一codeを重複加算しない。
  Future<void> _recordActivityObservedNeed({
    required _NodeTarget target,
    required LearningRun run,
    required LearningNeedEvidence evidence,
    required LearningOrigin origin,
    String? nodeId,
    String? activityId,
    LearningActivityKind? activityKind,
  }) async {
    final matchesTarget = target.kind == GamePathNodeKind.legendary
        ? target.unit.concepts.any(
            (concept) => concept.key == evidence.conceptKey,
          )
        : evidence.conceptKey == target.conceptKey;
    if (evidence.kind != LearningNeedEvidenceKind.observed || !matchesTarget) {
      return;
    }
    final now = DateTime.now();
    final observedAt = run.updatedAt.toUtc();
    final learningDay = dayKeyOf(observedAt.toLocal());
    final skillId = '${target.unit.id}/${evidence.conceptKey}';
    final observedNeeds = <String, Set<String>>{
      skillId: {evidence.needCode},
    };
    final event = LearningEventCommand(
      eventId:
          'need:v3:${run.runId}:${run.activityIndex}:$learningDay:'
          '${_stableNeedFingerprint(observedNeeds)}',
      scope: widget.scope,
      origin: widget.schoolMode ? LearningOrigin.schoolAssignment : origin,
      courseId: _courseId,
      nodeId: nodeId ?? target.nodeId,
      activityId: activityId ?? 'path.${target.kind.name}.need.v1',
      skillIds: {skillId},
      activityKind: activityKind ?? _activityKindFor(target.kind),
      outcome: LearningAttemptOutcome.retryNeeded,
      evidence: LearningEvidenceLevel.participation,
      contentVersion: _contentVersion,
      learningDay: learningDay,
      occurredAt: observedAt,
      practiceNeedCodes: observedNeeds,
    );
    try {
      await _progressStore(now).commit(event);
    } catch (_) {
      if (mounted) _message('見つけた復習ポイントを端末へ保存できませんでした。');
      rethrow;
    }
  }

  /// 任意ミニゲームで見つけた固定needだけを保存する。
  ///
  /// Path node、XP、streak、questは進めず、回答・選択肢・時間も保存しない。
  /// 解消は時間制の正解ではなく、通常のexact Repairで構造成功した時だけ行う。
  Future<void> _recordOptionalPracticeNeed({
    required _NodeTarget target,
    required PracticeModeKind mode,
    required LearningNeedEvidence evidence,
    required LearningRun run,
  }) async {
    if (evidence.kind != LearningNeedEvidenceKind.observed ||
        evidence.conceptKey != target.conceptKey) {
      return;
    }
    final now = DateTime.now();
    final observedAt = run.updatedAt.toUtc();
    final learningDay = dayKeyOf(observedAt.toLocal());
    final skillId = '${target.unit.id}/${target.conceptKey}';
    final observedNeeds = <String, Set<String>>{
      skillId: {evidence.needCode},
    };
    final fingerprint = _stableNeedFingerprint(observedNeeds);
    final event = LearningEventCommand(
      // 同一route内の再送は同じrun/indexで冪等、Repair後にもう一度開いた
      // routeは新しいrun markerになり、同じneedでも正しく再活性化する。
      eventId:
          'need:v2:${run.runId}:${run.activityIndex}:'
          '$learningDay:${mode.name}:$fingerprint',
      scope: widget.scope,
      origin: widget.schoolMode
          ? LearningOrigin.schoolAssignment
          : LearningOrigin.practice,
      courseId: _courseId,
      nodeId:
          'optional:v1:${target.unit.id}:${target.conceptKey}:${mode.name}:need',
      activityId: 'practice.${mode.name}.need.v1',
      skillIds: {skillId},
      activityKind: LearningActivityKind.timed,
      outcome: LearningAttemptOutcome.retryNeeded,
      evidence: LearningEvidenceLevel.participation,
      contentVersion: _contentVersion,
      learningDay: learningDay,
      occurredAt: observedAt,
      practiceNeedCodes: observedNeeds,
    );
    try {
      await _progressStore(now).commit(event);
      await _reloadSnapshot();
    } catch (_) {
      if (mounted) _message('見つけた復習ポイントを端末へ保存できませんでした。');
      rethrow;
    }
  }

  Future<void> _recordUnitLegendaryFailure({
    required _NodeTarget target,
    required LearningRun run,
    required LearningNeedEvidenceBuffer needEvidence,
    required Future<void> Function() afterRecorded,
  }) async {
    final now = DateTime.now();
    final observedAt = run.updatedAt.toUtc();
    final learningDay = dayKeyOf(observedAt.toLocal());
    final observedNeeds = needEvidence.observedBySkill(target.unit.id);
    // need eventとheart消費は別transactionなので、前者だけ成功しても同じ
    // run位置・学習日・固定needなら完全同一commandとして再送できるようにする。
    final failureEventId =
        'event:${run.runId}:need:${run.activityIndex}:$learningDay:'
        '${_stableNeedFingerprint(observedNeeds)}';
    final event = LearningEventCommand(
      eventId: failureEventId,
      scope: widget.scope,
      origin: widget.schoolMode
          ? LearningOrigin.schoolAssignment
          : LearningOrigin.challenge,
      courseId: _courseId,
      nodeId: target.nodeId,
      activityId: 'path.unit-legendary.v2.retry',
      skillIds: {GamePathProjection.unitLegendarySkillId(target.unit.id)},
      activityKind: LearningActivityKind.transfer,
      outcome: LearningAttemptOutcome.retryNeeded,
      evidence: LearningEvidenceLevel.participation,
      contentVersion: _contentVersion,
      learningDay: learningDay,
      occurredAt: observedAt,
      // need観測とheart消費は別の冪等台帳。retry eventでactive runを消さない。
      runId: null,
      practiceNeedCodes: observedNeeds,
    );
    try {
      await _progressStore(now).commit(event);
      await afterRecorded();
    } catch (_) {
      if (mounted) _message('未クリア記録を端末へ保存できませんでした。もう一度お試しください。');
      rethrow;
    }
  }

  bool _legacyUnitLegendaryWasFullyCleared(UnitSummary unit) {
    final cleared = {
      for (final node in _snapshot?.nodes ?? const <LearningNodeProgress>[])
        if (node.state == LearningNodeState.cleared) node.nodeId,
    };
    return unit.concepts.isNotEmpty &&
        unit.concepts.every(
          (concept) => cleared.contains(
            GamePathProjection.legacyConceptLegendaryNodeId(
              unit.id,
              concept.key,
            ),
          ),
        );
  }

  Future<void> _applyFixedTaskHeartLoss(_PendingHeartLoss loss) async {
    if (widget.schoolMode) return;
    try {
      final result = await _progressStore(loss.occurredAt.toLocal())
          .spendChallengeHeart(
            loss.runId,
            lossId: loss.lossId,
            activityIndex: loss.activityIndex,
            learningDay: loss.learningDay,
            occurredAt: loss.occurredAt,
          );
      if (mounted && result.spent) {
        await _reloadSnapshot();
      }
    } catch (_) {
      if (mounted) _message('ハートの記録が完了していません。');
      rethrow;
    }
  }

  Future<void> _ensureUnclearedRunAdvanced(LearningRun original) async {
    final now = DateTime.now();
    final store = _progressStore(now);
    final current = await store.activeRun(
      scope: widget.scope,
      nodeId: original.nodeId,
    );
    if (current == null || current.runId != original.runId) return;
    if (current.activityIndex > original.activityIndex) {
      await _reloadSnapshot();
      return;
    }
    await store.checkpointRun(
      current.runId,
      activityIndex: current.activityIndex + 1,
      updatedAt: now.toUtc(),
    );
    await _reloadSnapshot();
  }

  int _spacedReviewAttempt(_NodeTarget target, LearningRun run) {
    final skill = _snapshot?.skills
        .where(
          (item) => item.skillId == '${target.unit.id}/${target.conceptKey}',
        )
        .firstOrNull;
    return (skill?.successfulRetrievals ?? 0) + run.activityIndex;
  }

  int _unitLegendaryAttempt(
    _NodeTarget target, {
    required LearningRun run,
    required int conceptIndex,
  }) {
    final skillId = GamePathProjection.unitLegendarySkillId(target.unit.id);
    final skill = _snapshot?.skills
        .where((item) => item.skillId == skillId)
        .firstOrNull;
    // 未クリアごとにunit全体のvariantをずらし、同じ固定問題をheartの数だけ
    // 暗記する攻略を防ぐ。concept間も開始variantをずらす。
    return (skill?.successfulRetrievals ?? 0) +
        run.activityIndex +
        conceptIndex;
  }

  int _practiceAttempt(_NodeTarget target, {LearningRun? run}) {
    if (target.kind == GamePathNodeKind.legendary) {
      final skill = _snapshot?.skills
          .where(
            (item) =>
                item.skillId ==
                GamePathProjection.unitLegendarySkillId(target.unit.id),
          )
          .firstOrNull;
      // 未クリアrunは残る。失敗回数をvariantへ足し、同じ固定問題を
      // ハートの数だけ暗記して通す攻略にしない。
      return (skill?.successfulRetrievals ?? 0) + (run?.activityIndex ?? 0);
    }
    return switch (target.kind) {
      GamePathNodeKind.lesson || GamePathNodeKind.story => 0,
      GamePathNodeKind.practice || GamePathNodeKind.listening => 1,
      GamePathNodeKind.speaking ||
      GamePathNodeKind.challenge ||
      GamePathNodeKind.legendary => 2,
    };
  }

  Future<void> _openNotation(
    NotationLabEntry entry, {
    String? focusNeedCode,
    LearningRepairTarget? repairTarget,
  }) async {
    final target = _notationTargets[entry.id];
    if (target == null ||
        !entry.canOpen ||
        _openingNodeId != null ||
        !mounted) {
      return;
    }
    if (!await _ensureNormalLearningCanStart() || !mounted) return;
    setState(() => _openingNodeId = entry.id);
    try {
      final detail = await _detailFor(target.unit.id);
      if (!mounted) return;
      final section = detail?.sectionFor(target.conceptKey);
      final content = section == null
          ? null
          : ScienceActivityContent.notationFor(section);
      if (section == null || content == null) {
        _message('この記号課題を開けませんでした。');
        return;
      }
      final run = await _startStandaloneRun(entry.id);
      if (!mounted) return;
      final startedAt = DateTime.now();
      final attempt =
          (_snapshot?.nodes
                  .where((node) => node.nodeId == entry.id)
                  .firstOrNull
                  ?.attemptCount ??
              0) +
          run.activityIndex;
      final needEvidence = LearningNeedEvidenceBuffer();
      final heartLosses = _HeartLossQueue(
        run: run,
        onApply: _applyFixedTaskHeartLoss,
      );
      final observedNeedWrites = _ObservedNeedWriteQueue(
        onPersist: (evidence) => _recordActivityObservedNeed(
          target: target,
          run: run,
          evidence: evidence,
          origin: repairTarget != null
              ? LearningOrigin.practice
              : LearningOrigin.lab,
          nodeId: run.nodeId,
          activityId: 'notation.need.v1',
          activityKind: LearningActivityKind.equation,
        ),
      );
      void recordNeedEvidence(LearningNeedEvidence evidence) {
        needEvidence.record(evidence);
        observedNeedWrites.record(evidence);
      }

      void reportHeartLoss(LearningHeartLossEvidence evidence) {
        heartLosses.reportAfter(
          evidence,
          beforeApply: observedNeedWrites.drain,
        );
      }

      Future<bool> allowRetry() async {
        try {
          await observedNeedWrites.drain();
          await heartLosses.drain();
        } catch (_) {
          return false;
        }
        return _ensureNormalLearningCanStart();
      }

      final activityStatus = _beginActivityStatus();
      try {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (routeContext) {
              Future<void>? save;
              return _activityFrame(
                status: activityStatus,
                child: ScienceNotationLabScreen(
                  section: section,
                  conceptLabel: target.conceptLabel,
                  practiceAttempt: attempt,
                  content: content,
                  focusNeedCode: focusNeedCode,
                  onNeedEvidence: recordNeedEvidence,
                  onHeartLoss: reportHeartLoss,
                  onRetryRequested: allowRetry,
                  onCompleted: () {
                    save ??= () async {
                      await observedNeedWrites.drain();
                      await heartLosses.drain();
                      final action = await _commitNotation(
                        target: target,
                        run: run,
                        needEvidence: needEvidence,
                        repairTarget: repairTarget,
                        elapsed: DateTime.now().difference(startedAt),
                      );
                      if (action == GameCompletionAction.nextStep &&
                          routeContext.mounted) {
                        Navigator.of(routeContext).pop();
                      }
                    }();
                    unawaited(_guardRouteSave(save!));
                  },
                ),
              );
            },
          ),
        );
        await observedNeedWrites.drain();
        await heartLosses.drain();
      } finally {
        _endActivityStatus(activityStatus);
      }
      if (mounted) await _reloadSnapshot();
    } catch (_) {
      if (mounted) _message('記号ラボを開始できませんでした。');
    } finally {
      if (mounted) setState(() => _openingNodeId = null);
    }
  }

  Future<LearningRun> _startStandaloneRun(
    String nodeId, {
    bool usesHearts = true,
    bool replaceExisting = false,
  }) async {
    final now = DateTime.now();
    final store = _progressStore(now);
    final existing = await store.activeRun(scope: widget.scope, nodeId: nodeId);
    if (existing != null) {
      if (!replaceExisting) return existing;
      // 任意ミニゲームは回答・残り時間を保存しない。OS終了で一時runだけが
      // 残った場合、古い試行を再開したように見せず、新しいrunへ切り替える。
      // heart loss台帳はrunとは独立して残るため、消費済みheartは戻らない。
      await store.discardRun(existing.runId);
    }
    return store.beginRun(
      LearningRun(
        runId:
            'run:${now.microsecondsSinceEpoch}:${(_runSerial++).toRadixString(36)}',
        scope: widget.scope,
        nodeId: nodeId,
        activityIndex: 0,
        challengeHearts: widget.schoolMode || !usesHearts
            ? null
            : LearningChallengeHeartState.defaultMaximum,
        contentVersion: _contentVersion,
        updatedAt: now.toUtc(),
      ),
    );
  }

  Future<GameCompletionAction?> _commitNotation({
    required _NodeTarget target,
    required LearningRun run,
    required LearningNeedEvidenceBuffer needEvidence,
    LearningRepairTarget? repairTarget,
    required Duration elapsed,
  }) async {
    final now = DateTime.now();
    final observedNeeds = needEvidence.observedBySkill(target.unit.id);
    final demonstratedNeeds = needEvidence.demonstratedBySkill(target.unit.id);
    final hasObservedNeed = observedNeeds.values.any(
      (codes) => codes.isNotEmpty,
    );
    final repairNeedCode = repairTarget?.needCode;
    final resolvesRepair =
        repairTarget != null &&
        repairNeedCode != null &&
        !hasObservedNeed &&
        (demonstratedNeeds[repairTarget.skillId]?.contains(repairNeedCode) ??
            false);
    final resolvedNeeds = resolvesRepair
        ? <String, Set<String>>{
            repairTarget.skillId: <String>{repairNeedCode},
          }
        : const <String, Set<String>>{};
    final event = LearningEventCommand(
      eventId: 'event:${run.runId}',
      scope: widget.scope,
      origin: widget.schoolMode
          ? LearningOrigin.schoolAssignment
          : repairTarget != null
          ? LearningOrigin.practice
          : LearningOrigin.lab,
      courseId: _courseId,
      nodeId: run.nodeId,
      activityId: 'notation.v1',
      skillIds: {'${target.unit.id}/${target.conceptKey}'},
      activityKind: LearningActivityKind.equation,
      outcome: hasObservedNeed
          ? LearningAttemptOutcome.corrected
          : LearningAttemptOutcome.structuredSuccess,
      evidence: LearningEvidenceLevel.structuredCorrection,
      contentVersion: _contentVersion,
      learningDay: dayKeyOf(now),
      occurredAt: now.toUtc(),
      runId: run.runId,
      practiceNeedCodes: observedNeeds,
      resolvedPracticeNeedCodes: resolvedNeeds,
      repairResolution: resolvesRepair ? repairTarget.resolutionMetadata : null,
    );
    try {
      final result = await _progressStore(now).commit(event);
      await _reloadSnapshot();
      await _contributeSelectedCoopParticipant(result);
      unawaited(_dispatchLanSocialAfterCommit(result));
      if (!mounted) return null;
      return _showCompletionCelebration(
        result: result,
        elapsed: elapsed,
        eyebrow: 'NOTATION LAB COMPLETE',
        title: result.inserted ? 'やった！記号を読み切った' : '記号をもう一度確かめた',
        message: 'なぞる・組む・読む課題を終え、記号と意味をつなげました。',
      );
    } catch (_) {
      if (mounted) _message('記号ラボの完了を端末へ保存できませんでした。');
      rethrow;
    }
  }

  Future<void> _openStory(StoryEpisodeView episode) async {
    final node = _nodeFor(episode.id);
    if (node != null) await _openNode(node);
  }

  Future<void> _showEconomy() async {
    final game = _game;
    if (game == null || widget.schoolMode || !game.economy.available) return;
    await showGameEconomySheet(
      context,
      economy: game.economy,
      player: game.player,
      onRefillStreakFreeze: _refillStreakFreeze,
      onRecoverChallengeHearts: _recoverChallengeHearts,
      onPurchaseCosmetic: _purchaseCosmetic,
      onEquipCosmetic: _equipCosmetic,
    );
  }

  Future<void> _startLocalCoop() async {
    if (widget.schoolMode || _startingCoop || !mounted) return;
    final existing = _currentLocalCoopRun;
    if (existing != null) {
      final pending = existing.participantIds
          .where((id) => !existing.contributingParticipantIds.contains(id))
          .firstOrNull;
      if (pending != null) setState(() => _selectedCoopParticipantId = pending);
      return;
    }
    if (_localWeeklyLeague?.availability ==
        LocalWeeklyLeagueAvailability.active) {
      _message('今週は週次リーグを開始済みです。仲間クエストは次の週に作れます。');
      return;
    }
    setState(() => _startingCoop = true);
    final now = DateTime.now();
    final learningDay = dayKeyOf(now);
    final weekStart = learningWeekKey(learningDay);
    final runId = 'pair:$weekStart:v1';
    try {
      final run = await _progressStore(now).beginLocalCoopRun(
        LearningLocalCoopRunCommand(
          runId: runId,
          participantIds: {'$runId:a', '$runId:b'},
          target: 2,
          rewardGems: 3,
          startDay: weekStart,
          endDay: _learningDayPlus(weekStart, 6),
          definitionVersion: 'local-pair.v1',
          startedAt: now.toUtc(),
        ),
      );
      if (!mounted) return;
      setState(
        () => _selectedCoopParticipantId =
            (run.participantIds.toList()..sort()).first,
      );
      await _reloadSnapshot();
      if (mounted) _message('端末内ペアクエストを始めました。1人目の学習を選択中です。');
    } catch (_) {
      if (mounted) _message('ペアクエストを開始できませんでした。');
    } finally {
      if (mounted) setState(() => _startingCoop = false);
    }
  }

  Future<void> _startWeeklyLeague(int participantCount) async {
    if (widget.schoolMode ||
        _startingWeeklyLeague ||
        participantCount < 2 ||
        participantCount > 8 ||
        _localWeeklyLeague?.availability !=
            LocalWeeklyLeagueAvailability.notStarted ||
        !mounted) {
      return;
    }
    setState(() => _startingWeeklyLeague = true);
    final weekKey = learningWeekKey(dayKeyOf(DateTime.now()));
    final runId = 'league:$weekKey:r1:v1';
    final participants = {
      for (var index = 1; index <= participantCount; index++)
        'league:$weekKey:slot:$index',
    };
    try {
      final run = await _progressStore(DateTime.now()).beginLocalCoopRun(
        LearningLocalCoopRunCommand(
          runId: runId,
          participantIds: participants,
          target: participantCount,
          rewardGems: 0,
          startDay: weekKey,
          endDay: _learningDayPlus(weekKey, 6),
          definitionVersion: LocalWeeklyLeagueProjection.definitionVersion,
          startedAt: dayStartOf(
            weekKey,
          ).toUtc().add(const Duration(minutes: 1)),
        ),
      );
      if (!mounted) return;
      setState(() {
        _weeklyLeagueParticipantCount = participantCount;
        _selectedCoopParticipantId =
            (run.participantIds.toList()..sort()).first;
      });
      await _reloadSnapshot();
      if (mounted) _message('実在する$participantCount人の週次リーグを始めました。');
    } catch (_) {
      if (mounted) _message('週次リーグを開始できませんでした。');
    } finally {
      if (mounted) setState(() => _startingWeeklyLeague = false);
    }
  }

  Future<void> _startNextWeeklyLeagueRound() async {
    if (widget.schoolMode || _startingWeeklyLeague || !mounted) return;
    final view = _localWeeklyLeague;
    final snapshot = _snapshot;
    if (view == null ||
        snapshot == null ||
        view.availability != LocalWeeklyLeagueAvailability.active ||
        view.activeRunId != null) {
      return;
    }
    final weekKey = view.weekKey;
    final recognized =
        snapshot.localCoopRuns
            .where(
              (run) =>
                  run.scope == LearningScope.personal &&
                  run.startDay == weekKey &&
                  (run.definitionVersion ==
                          LocalWeeklyLeagueProjection.definitionVersion ||
                      run.definitionVersion ==
                          LocalWeeklyLeagueProjection
                              .pairBridgeDefinitionVersion),
            )
            .toList()
          ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final first = recognized.firstOrNull;
    if (first == null || first.participantIds.length < 2) return;
    final round = recognized.length + 1;
    final runId = 'league:$weekKey:r$round:v1';
    setState(() => _startingWeeklyLeague = true);
    try {
      final run = await _progressStore(DateTime.now()).beginLocalCoopRun(
        LearningLocalCoopRunCommand(
          runId: runId,
          participantIds: first.participantIds,
          target: first.participantIds.length,
          rewardGems: 0,
          startDay: weekKey,
          endDay: _learningDayPlus(weekKey, 6),
          definitionVersion: LocalWeeklyLeagueProjection.definitionVersion,
          startedAt: dayStartOf(weekKey).toUtc().add(Duration(minutes: round)),
        ),
      );
      if (!mounted) return;
      setState(
        () => _selectedCoopParticipantId =
            (run.participantIds.toList()..sort()).first,
      );
      await _reloadSnapshot();
      if (mounted) _message('同じ参加枠で次のラウンドを始めました。');
    } catch (_) {
      if (mounted) _message('次のラウンドを開始できませんでした。');
    } finally {
      if (mounted) setState(() => _startingWeeklyLeague = false);
    }
  }

  void _selectCoopParticipant(String participantId) {
    final run = _activeContributionRun;
    if (run == null ||
        run.completed ||
        !run.participantIds.contains(participantId) ||
        run.contributingParticipantIds.contains(participantId)) {
      return;
    }
    setState(() => _selectedCoopParticipantId = participantId);
    _message('次に完了した意味のある学習を、この参加枠の1件として数えます。');
  }

  Future<void> _contributeSelectedCoopParticipant(
    CommitLearningResult result,
  ) async {
    if (widget.schoolMode || !result.inserted) return;
    final participantId = _selectedCoopParticipantId;
    final run = _activeContributionRun;
    if (participantId == null ||
        run == null ||
        run.completed ||
        !run.participantIds.contains(participantId) ||
        run.contributingParticipantIds.contains(participantId)) {
      return;
    }
    try {
      final contribution =
          await _progressStore(
            result.event.occurredAt.toLocal(),
          ).contributeLocalCoopRun(
            run.runId,
            contributionId: 'coop:${run.runId}:${result.event.eventId}',
            participantId: participantId,
            eventId: result.event.eventId,
            occurredAt: result.event.occurredAt,
          );
      if (!mounted) return;
      setState(() => _selectedCoopParticipantId = null);
      await _reloadSnapshot();
      if (mounted) {
        final isPair =
            contribution.run.definitionVersion ==
            LocalWeeklyLeagueProjection.pairBridgeDefinitionVersion;
        _message(
          contribution.run.completed
              ? isPair
                    ? '2人の学習がそろいました。仲間クエスト達成です。'
                    : '全員の学習がそろいました。次のラウンドを作れます。'
              : '1人分の学習を記録しました。次の人を選んでください。',
        );
      }
    } on StateError {
      if (mounted) {
        _message('この完了は周回だったため、参加者リーグには数えませんでした。');
      }
    } catch (_) {
      if (mounted) _message('参加者リーグへの記録が完了していません。');
    }
  }

  /// 端末へのcommitが成功し、保存層がmeaningfulと確定したeventだけを送る。
  ///
  /// social側のmembership破損、TLS、snapshot、報酬書込の失敗はここで閉じ、
  /// 既に成功した学習commitやPathの描画を失敗扱いにしない。
  Future<void> _dispatchLanSocialAfterCommit(
    CommitLearningResult result,
  ) async {
    if (!widget.lanSocialAllowed ||
        widget.schoolMode ||
        widget.scope != LearningScope.personal ||
        result.event.scope != LearningScope.personal ||
        !result.event.meaningfulProgress) {
      return;
    }
    try {
      final contributor = widget.lanSocialMeaningfulEventContributor;
      if (contributor != null) {
        await contributor(result.event);
      } else {
        final dispatcher = _lanSocialDispatcher ??=
            LanSocialMeaningfulProgressDispatcher(store: widget.sessionStore);
        await dispatcher.contribute(result.event);
      }
      await _reloadSnapshot();
    } on Object {
      // 学習commitは既に成功済み。social失敗をPathへ逆流させない。
    }
  }

  Future<void> _openLanSocial() async {
    if (!widget.lanSocialAllowed ||
        widget.schoolMode ||
        widget.scope != LearningScope.personal ||
        !mounted) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => LanSocialScreen(
          store: widget.sessionStore,
          schoolMode: false,
          lanSocialAllowed: true,
        ),
      ),
    );
    if (mounted) await _reloadSnapshot();
  }

  Future<void> _refillStreakFreeze() async {
    final now = DateTime.now();
    final request = _pendingFreezeSpend ??= _PendingGemSpend(
      id: 'gem:freeze:${now.microsecondsSinceEpoch}',
      learningDay: dayKeyOf(now),
      occurredAt: now.toUtc(),
    );
    final result = await _progressStore(now).replenishStreakFreezeWithGems(
      spendId: request.id,
      learningDay: request.learningDay,
      occurredAt: request.occurredAt,
    );
    _pendingFreezeSpend = null;
    await _reloadSnapshot();
    if (mounted) {
      _message('連続記録の保護を補充しました。結晶は残り${result.remainingGems}個です。');
    }
  }

  Future<void> _recoverChallengeHearts() async {
    final now = DateTime.now();
    final request = _pendingHeartSpend ??= _PendingGemSpend(
      id: 'gem:hearts:${now.microsecondsSinceEpoch}',
      learningDay: dayKeyOf(now),
      occurredAt: now.toUtc(),
    );
    final result = await _progressStore(now).recoverChallengeHeartsWithGems(
      spendId: request.id,
      learningDay: request.learningDay,
      occurredAt: request.occurredAt,
    );
    _pendingHeartSpend = null;
    await _reloadSnapshot();
    if (mounted) {
      _message(
        '学習ハートを${result.challengeHearts.current}個へ戻しました。結晶は残り${result.remainingGems}個です。',
      );
    }
  }

  Future<void> _purchaseCosmetic(String productId) async {
    if (widget.schoolMode) {
      throw StateError('school mode has no gem economy');
    }
    final now = DateTime.now();
    final request = _pendingCosmeticSpends.putIfAbsent(
      productId,
      () => _PendingGemSpend(
        id: 'gem:cosmetic:$productId:${now.microsecondsSinceEpoch}',
        learningDay: dayKeyOf(now),
        occurredAt: now.toUtc(),
      ),
    );
    final result = await _progressStore(now).purchaseCosmeticWithGems(
      scope: widget.scope,
      spendId: request.id,
      productId: productId,
      learningDay: request.learningDay,
      occurredAt: request.occurredAt,
    );
    _pendingCosmeticSpends.remove(productId);
    await _reloadSnapshot();
    if (mounted) {
      _message('Pathマスコットを変更しました。結晶は残り${result.remainingGems}個です。');
    }
  }

  Future<void> _equipCosmetic(String productId) async {
    if (widget.schoolMode) {
      throw StateError('school mode has no gem economy');
    }
    final now = DateTime.now();
    await _progressStore(now).equipCosmetic(
      scope: widget.scope,
      productId: productId,
      occurredAt: now.toUtc(),
    );
    await _reloadSnapshot();
    if (mounted) _message('Pathマスコットの見た目を変更しました。');
  }

  Future<void> _openRepairTarget(LearningRepairTarget repair) async {
    final summary = _catalog
        .where((unit) => unit.id == repair.unitId)
        .firstOrNull;
    if (summary == null || repair.needCode == null) {
      _message('この見直し課題を教材へ対応できませんでした。');
      return;
    }
    switch (repair.activityKind) {
      case LearningRepairActivityKind.practice:
        final node = _nodeFor(
          GamePathProjection.nodeId(
            repair.unitId,
            repair.conceptKey,
            GamePathNodeKind.practice,
          ),
        );
        if (node == null || !node.canOpen) {
          _message('この見直し課題は、学習パスを進めると開きます。');
          return;
        }
        await _openNode(
          node,
          eventOrigin: LearningOrigin.practice,
          practiceAttemptOverride: repair.practiceAttempt,
          repairTarget: repair,
        );
        return;
      case LearningRepairActivityKind.listening:
        final node = _nodeFor(
          GamePathProjection.nodeId(
            repair.unitId,
            repair.conceptKey,
            GamePathNodeKind.listening,
          ),
        );
        if (node == null || !node.canOpen) {
          _message('この聞き直し課題は、学習パスを進めると開きます。');
          return;
        }
        await _openNode(
          node,
          eventOrigin: LearningOrigin.practice,
          practiceAttemptOverride: repair.practiceAttempt,
          repairTarget: repair,
        );
        return;
      case LearningRepairActivityKind.notationOrder ||
          LearningRepairActivityKind.notationSymbol ||
          LearningRepairActivityKind.notationGraph:
        final entry = _notationEntries
            .where(
              (candidate) =>
                  candidate.id ==
                  _notationNodeId(repair.unitId, repair.conceptKey),
            )
            .firstOrNull;
        if (entry == null || !entry.canOpen) {
          _message('この記号の見直しは、学習パスを進めると開きます。');
          return;
        }
        await _openNotation(
          entry,
          focusNeedCode: repair.needCode,
          repairTarget: repair,
        );
        return;
    }
  }

  Future<void> _openHeartRecoveryPractice() async {
    if (widget.schoolMode || _openingNodeId != null || !mounted) return;
    final now = DateTime.now();
    try {
      await _progressStore(now).refreshChallengeHearts(
        learningDay: dayKeyOf(now),
        occurredAt: now.toUtc(),
      );
      await _reloadSnapshot();
    } catch (_) {
      if (mounted) _message('ハートの状態を確認できませんでした。');
      return;
    }
    final hearts = _snapshot?.challengeHearts;
    if (hearts == null || hearts.current >= hearts.maximum) {
      if (mounted) _message('ハートは満タンです。');
      return;
    }
    final node = _game?.path.units
        .expand((unit) => unit.nodes)
        .where(
          (candidate) =>
              candidate.kind == GamePathNodeKind.practice && candidate.canOpen,
        )
        .firstOrNull;
    final target = node == null ? null : _targets[node.id];
    if (target == null) {
      _message('最初の「しくみ図」を開くと、ハート回復練習を使えます。');
      return;
    }
    final recoveryNodeId =
        'heart-recovery:v1:${target.unit.id}:${target.conceptKey}';
    setState(() => _openingNodeId = recoveryNodeId);
    try {
      final detail = await _detailFor(target.unit.id);
      if (!mounted) return;
      final section = detail?.sectionFor(target.conceptKey);
      if (section == null) {
        _message('ハート回復練習を開けませんでした。');
        return;
      }
      final run = await _startStandaloneRun(recoveryNodeId, usesHearts: false);
      if (!mounted) return;
      final needEvidence = LearningNeedEvidenceBuffer();
      final recoveryOccurredAt = DateTime.now().toUtc();
      Future<void>? recoverySave;
      var recoverySaved = false;

      Future<void> saveRecovery() async {
        if (recoverySaved) return;
        final pending = recoverySave;
        if (pending != null) {
          await pending;
          return;
        }
        final next = _commitHeartRecoveryPractice(
          target: target,
          run: run,
          needEvidence: needEvidence,
          occurredAt: recoveryOccurredAt,
        );
        recoverySave = next;
        try {
          await next;
          recoverySaved = true;
        } finally {
          if (identical(recoverySave, next)) recoverySave = null;
        }
      }

      void completed() {
        unawaited(_guardRouteSave(saveRecovery()));
      }

      void returnToPractice(BuildContext routeContext) {
        unawaited(() async {
          try {
            await saveRecovery();
          } catch (_) {
            // 同じ画面・runを保ち、同じevent/recovery IDで再度保存できる。
            return;
          }
          if (routeContext.mounted) Navigator.of(routeContext).pop();
        }());
      }

      final activityStatus = _beginActivityStatus();
      try {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (routeContext) => _activityFrame(
              status: activityStatus,
              child: ScienceDiagramScreen(
                section: section,
                conceptLabel: target.conceptLabel,
                practiceAttempt: _practiceAttempt(target, run: run),
                onCompleted: completed,
                onNeedEvidence: needEvidence.record,
                // 回復練習は0heartでも完了できる唯一の固定課題。
                onHeartLoss: null,
                onReturnToPath: () => returnToPractice(routeContext),
              ),
            ),
          ),
        );
      } finally {
        _endActivityStatus(activityStatus);
      }
      if (mounted) await _reloadSnapshot();
    } catch (_) {
      if (mounted) _message('ハート回復練習を完了できませんでした。もう一度お試しください。');
    } finally {
      if (mounted) setState(() => _openingNodeId = null);
    }
  }

  Future<void> _commitHeartRecoveryPractice({
    required _NodeTarget target,
    required LearningRun run,
    required LearningNeedEvidenceBuffer needEvidence,
    required DateTime occurredAt,
  }) async {
    final now = occurredAt.toLocal();
    final learningDay = dayKeyOf(now);
    final observedNeeds = needEvidence.observedBySkill(target.unit.id);
    final event = LearningEventCommand(
      eventId: 'event:${run.runId}',
      scope: LearningScope.personal,
      origin: LearningOrigin.practice,
      courseId: _courseId,
      nodeId: run.nodeId,
      activityId: 'practice.heart-recovery.v1',
      skillIds: {'${target.unit.id}/${target.conceptKey}'},
      activityKind: LearningActivityKind.diagram,
      outcome: observedNeeds.values.any((codes) => codes.isNotEmpty)
          ? LearningAttemptOutcome.corrected
          : LearningAttemptOutcome.structuredSuccess,
      evidence: LearningEvidenceLevel.structuredCorrection,
      contentVersion: _contentVersion,
      learningDay: learningDay,
      occurredAt: occurredAt,
      runId: run.runId,
      practiceNeedCodes: observedNeeds,
    );
    try {
      final store = _progressStore(now);
      final commit = await store.commit(event);
      final recovery = await store.recoverChallengeHeartWithPractice(
        recoveryId: 'heart-recovery:${run.runId}',
        sourceEventId: event.eventId,
        learningDay: learningDay,
        occurredAt: occurredAt,
      );
      await _reloadSnapshot();
      await _contributeSelectedCoopParticipant(commit);
      unawaited(_dispatchLanSocialAfterCommit(commit));
      if (mounted) {
        _message(
          recovery.recovered > 0
              ? 'ハート +1（${recovery.state.current}/${recovery.state.maximum}）'
              : '練習中の時間回復で、ハートは満タンになりました。',
        );
      }
    } catch (_) {
      if (mounted) _message('ハート回復の保存が完了していません。');
      rethrow;
    }
  }

  Future<void> _openPractice(PracticeModeView mode) async {
    final game = _game;
    if (game == null) return;
    if (mode.kind == PracticeModeKind.heartRecovery) {
      await _openHeartRecoveryPractice();
      return;
    }
    if (mode.kind == PracticeModeKind.repair && widget.schoolMode) {
      _message('見直し課題は個人学習で使えます。授業では学習パスから進めます。');
      return;
    }
    if (!await _ensureNormalLearningCanStart() || !mounted) return;
    if (mode.kind == PracticeModeKind.repair) {
      final repair = _repairPlan?.targets
          .where((target) => target.reason == LearningRepairReason.activeNeed)
          .firstOrNull;
      if (repair != null) {
        await _openRepairTarget(repair);
        return;
      }
      _message('現在、直す復習ポイントはありません。');
      return;
    }
    final nodes = game.path.units.expand((unit) => unit.nodes).toList();
    GamePathNode? target;
    switch (mode.kind) {
      case PracticeModeKind.heartRecovery:
        return;
      case PracticeModeKind.personalized:
        target = nodes
            .where(
              (node) =>
                  _nodeBelongsToDueSkill(node) &&
                  (node.state == GamePathNodeState.reviewDue ||
                      node.state == GamePathNodeState.legendaryAvailable ||
                      node.state == GamePathNodeState.available ||
                      node.state == GamePathNodeState.inProgress),
            )
            .firstOrNull;
      case PracticeModeKind.resume:
        target = nodes
            .where((node) => node.state == GamePathNodeState.inProgress)
            .firstOrNull;
      case PracticeModeKind.repair:
        return;
      case PracticeModeKind.listenSpeak:
        target = nodes
            .where(
              (node) =>
                  node.canOpen &&
                  (node.kind == GamePathNodeKind.listening ||
                      node.kind == GamePathNodeKind.speaking),
            )
            .firstOrNull;
      case PracticeModeKind.diagram:
        target = nodes
            .where(
              (node) => node.canOpen && node.kind == GamePathNodeKind.practice,
            )
            .firstOrNull;
      case PracticeModeKind.timed:
      case PracticeModeKind.match:
      case PracticeModeKind.lightning:
        target = nodes
            .where(
              (node) => node.canOpen && node.kind == GamePathNodeKind.challenge,
            )
            .firstOrNull;
    }
    if (target == null) {
      _message('この練習は、学習パスを進めると開きます。');
      return;
    }
    if (mode.kind == PracticeModeKind.timed ||
        mode.kind == PracticeModeKind.match ||
        mode.kind == PracticeModeKind.lightning) {
      await _openTimedPractice(target, mode.kind);
    } else {
      await _openNode(
        target,
        eventOrigin: mode.kind == PracticeModeKind.resume
            ? null
            : LearningOrigin.practice,
        spacedReview: mode.kind == PracticeModeKind.personalized,
      );
    }
  }

  Future<void> _openDailyAudio(DailyAudioMission mission) async {
    final target = _targets[mission.nodeId];
    final expectedKind = switch (mission.kind) {
      DailyAudioMissionKind.listening => GamePathNodeKind.listening,
      DailyAudioMissionKind.speaking => GamePathNodeKind.speaking,
    };
    if (target == null ||
        target.unit.id != mission.unitId ||
        target.conceptKey != mission.conceptKey ||
        target.kind != expectedKind ||
        _nodeFor(mission.nodeId)?.canOpen != true ||
        _openingNodeId != null ||
        !mounted) {
      return;
    }
    if (!await _ensureNormalLearningCanStart() || !mounted) return;
    setState(() => _openingNodeId = mission.nodeId);
    try {
      final detail = await _detailFor(mission.unitId);
      if (!mounted) return;
      final section = detail?.sectionFor(mission.conceptKey);
      if (section == null) {
        _message('今日の音声ミッションを開けませんでした。もう一度お試しください。');
        return;
      }
      final run = await _startRun(target);
      if (!mounted) return;
      final startedAt = DateTime.now();
      final needEvidence = LearningNeedEvidenceBuffer();
      final heartLosses = _HeartLossQueue(
        run: run,
        onApply: _applyFixedTaskHeartLoss,
      );
      final observedNeedWrites = _ObservedNeedWriteQueue(
        onPersist: (evidence) => _recordActivityObservedNeed(
          target: target,
          run: run,
          evidence: evidence,
          origin: LearningOrigin.practice,
        ),
      );
      void recordNeedEvidence(LearningNeedEvidence evidence) {
        needEvidence.record(evidence);
        observedNeedWrites.record(evidence);
      }

      void reportHeartLoss(LearningHeartLossEvidence evidence) {
        heartLosses.reportAfter(
          evidence,
          beforeApply: observedNeedWrites.drain,
        );
      }

      Future<void>? save;
      BuildContext? activityContext;
      void completed() {
        save ??= _guardRouteSave(() async {
          await observedNeedWrites.drain();
          await heartLosses.drain();
          final action = await _commitNode(
            target: target,
            run: run,
            eventOrigin: LearningOrigin.practice,
            needEvidence: needEvidence,
            elapsed: DateTime.now().difference(startedAt),
          );
          final routeContext = activityContext;
          if (action == GameCompletionAction.nextStep &&
              routeContext != null &&
              routeContext.mounted) {
            Navigator.of(routeContext).pop();
          }
        }());
      }

      void returnToPractice(BuildContext routeContext) {
        unawaited(_returnAfterSave(routeContext, save));
      }

      final activityStatus = _beginActivityStatus();
      try {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (routeContext) {
              activityContext = routeContext;
              final activity = switch (mission.kind) {
                DailyAudioMissionKind.listening => ScienceListeningScreen(
                  section: section,
                  conceptLabel: mission.conceptLabel,
                  practiceAttempt: mission.practiceAttempt,
                  onCompleted: completed,
                  onNeedEvidence: recordNeedEvidence,
                  onHeartLoss: reportHeartLoss,
                  onReturnToPath: () => returnToPractice(routeContext),
                ),
                DailyAudioMissionKind.speaking => ScienceSpeakListenScreen(
                  section: section,
                  conceptLabel: mission.conceptLabel,
                  practiceAttempt: mission.practiceAttempt,
                  onCompleted: completed,
                  onNeedEvidence: recordNeedEvidence,
                  onHeartLoss: reportHeartLoss,
                  onReturnToPath: () => returnToPractice(routeContext),
                ),
              };
              return _activityFrame(
                status: activityStatus,
                onExit: () => Navigator.maybePop(routeContext),
                child: activity,
              );
            },
          ),
        );
        await observedNeedWrites.drain();
        await heartLosses.drain();
      } finally {
        _endActivityStatus(activityStatus);
      }
      if (mounted) await _reloadSnapshot();
    } catch (_) {
      if (mounted) _message('今日の音声ミッションを開始できませんでした。');
    } finally {
      if (mounted) setState(() => _openingNodeId = null);
    }
  }

  Future<bool> _ensureTimedChallengePass() async {
    if (widget.schoolMode) return true;
    final game = _game;
    if (game == null) return false;
    if (game.economy.timedChallengePassActive) return true;
    final cost = game.economy.timedChallengePassGemCost;
    if (cost == null || !game.economy.canPurchaseTimedChallengePass) {
      _message('結晶が足りません。Match / Lightningは結晶なしで遊べます。');
      return false;
    }
    final approved = await confirmTimedChallengeEntry(context, gemCost: cost);
    if (!approved || !mounted) return false;
    final now = DateTime.now();
    final learningDay = dayKeyOf(now);
    try {
      final result = await _progressStore(now).purchaseChallengePassWithGems(
        scope: widget.scope,
        spendId: 'gem:timed-pass:$learningDay',
        productId: SafeLearningEconomyCatalogV1.timedDayPassId,
        learningDay: learningDay,
        occurredAt: dayStartOf(learningDay).toUtc(),
      );
      await _reloadSnapshot();
      if (mounted && result.applied) {
        _message('今日のタイム挑戦券を使いました。結晶は残り${result.remainingGems}個です。');
      }
      return mounted;
    } catch (_) {
      if (mounted) _message('タイム挑戦券を記録できませんでした。残高を確認してください。');
      return false;
    }
  }

  /// 任意の時間制はPath nodeを開始・完了せず、固定誤答needだけを台帳へ残す。
  Future<void> _openTimedPractice(
    GamePathNode node,
    PracticeModeKind mode,
  ) async {
    final target = _targets[node.id];
    if (target == null || !node.canOpen || _openingNodeId != null || !mounted) {
      return;
    }
    setState(() => _openingNodeId = node.id);
    try {
      final detail = await _detailFor(target.unit.id);
      if (!mounted) return;
      final section = detail?.sectionFor(target.conceptKey);
      if (section == null) {
        _message('この教材を開けませんでした。もう一度お試しください。');
        return;
      }
      if (mode == PracticeModeKind.timed &&
          !await _ensureTimedChallengePass()) {
        return;
      }
      final run = await _startStandaloneRun(
        'optional-heart:v1:${mode.name}:${target.nodeId}',
        replaceExisting: true,
      );
      if (!mounted) return;
      final attempt = _practiceAttempt(target, run: run) + run.activityIndex;
      final heartLosses = _HeartLossQueue(
        run: run,
        onApply: _applyFixedTaskHeartLoss,
      );
      final observedNeedWrites = _ObservedNeedWriteQueue(
        onPersist: (evidence) => _recordOptionalPracticeNeed(
          target: target,
          mode: mode,
          evidence: evidence,
          run: run,
        ),
      );
      Future<bool> allowRetry() async {
        try {
          await observedNeedWrites.drain();
          await heartLosses.drain();
        } catch (_) {
          return false;
        }
        return _ensureNormalLearningCanStart();
      }

      void reportNeed(LearningNeedEvidence evidence) {
        observedNeedWrites.record(evidence);
      }

      void reportHeartLoss(LearningHeartLossEvidence evidence) {
        heartLosses.reportAfter(
          evidence,
          beforeApply: observedNeedWrites.drain,
        );
      }

      void finish(BuildContext routeContext) {
        unawaited(
          _guardRouteSave(() async {
            await observedNeedWrites.drain();
            await heartLosses.drain();
            if (routeContext.mounted) Navigator.of(routeContext).pop();
          }()),
        );
      }

      final activityStatus = _beginActivityStatus();
      try {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (routeContext) => _activityFrame(
              status: activityStatus,
              child: switch (mode) {
                PracticeModeKind.match => ScienceMatchLabScreen(
                  section: section,
                  conceptLabel: target.conceptLabel,
                  practiceAttempt: attempt,
                  content: ScienceActivityContent.matchFor(
                    section,
                    practiceAttempt: attempt,
                  ),
                  onNeedEvidence: reportNeed,
                  onHeartLoss: reportHeartLoss,
                  onRetryRequested: allowRetry,
                  onCompleted: () => finish(routeContext),
                ),
                PracticeModeKind.lightning => ScienceLightningScreen(
                  section: section,
                  conceptLabel: target.conceptLabel,
                  practiceAttempt: attempt,
                  content: ScienceActivityContent.lightningFor(section),
                  onNeedEvidence: reportNeed,
                  onHeartLoss: reportHeartLoss,
                  onRetryRequested: allowRetry,
                  onCompleted: () => finish(routeContext),
                ),
                _ => ScienceTimedChallengeScreen(
                  section: section,
                  conceptLabel: target.conceptLabel,
                  practiceAttempt: attempt,
                  onNeedEvidence: reportNeed,
                  onHeartLoss: reportHeartLoss,
                  onFinished: () => finish(routeContext),
                ),
              },
            ),
          ),
        );
        await observedNeedWrites.drain();
        await heartLosses.drain();
      } finally {
        _endActivityStatus(activityStatus);
      }
      await _progressStore(DateTime.now()).discardRun(run.runId);
      if (mounted) await _reloadSnapshot();
    } catch (_) {
      if (mounted) _message('時間制チャレンジを開けませんでした。');
    } finally {
      if (mounted) setState(() => _openingNodeId = null);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final game = _game;
    final content = _content;
    final dailyAudioPlan = _dailyAudioPlan;
    if (_loadFailed || game == null || content == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.science_outlined, size: 54),
                  const SizedBox(height: 14),
                  const Text('学習パスを準備できませんでした。'),
                  const SizedBox(height: 14),
                  FilledButton(onPressed: _load, child: const Text('もう一度読み込む')),
                ],
              ),
            ),
          ),
        ),
      );
    }
    // まだ端末内eventが無い学校では、架空のクラス人数や0件の集計を出さず
    // 既存の協力案内を保つ。最初の授業完了後だけ実共同目標を渡す。
    final classroomQuest = widget.schoolMode
        ? game.quests.where((quest) => quest.progress > 0).firstOrNull
        : null;
    final headerQuests = _headerQuests;

    return GameShell(
      schoolMode: widget.schoolMode,
      playerStatus: game.path.status,
      quests: headerQuests,
      questTabFor: _questTabFor,
      onQuestSelected: (quest) => unawaited(_openQuestAction(quest.id)),
      questUnavailable: _questUnavailable,
      onQuestRetry: () => unawaited(_reloadSnapshot()),
      onStreakTap: widget.schoolMode ? null : () => unawaited(_showEconomy()),
      onGemsTap: widget.schoolMode ? null : () => unawaited(_showEconomy()),
      onHeartsTap: widget.schoolMode ? null : () => unawaited(_showEconomy()),
      path: PathScreen(
        data: game.path,
        mascotStyle: game.economy.equippedPathMascotStyle,
        onNodeStart: (node) => unawaited(_openNode(node)),
        showStatusHeader: false,
      ),
      stories: StoriesScreen(
        episodes: content.stories,
        onOpen: (episode) => unawaited(_openStory(episode)),
        mascotStyle: game.economy.equippedPathMascotStyle,
      ),
      practice: PracticeHubScreen(
        modes: content.practiceModes
            .where((mode) => mode.kind != PracticeModeKind.listenSpeak)
            .toList(growable: false),
        dueCount: game.duePracticeCount,
        onOpen: (mode) => unawaited(_openPractice(mode)),
        dailyAudioPlan: dailyAudioPlan,
        onOpenDailyAudio: (mission) => unawaited(_openDailyAudio(mission)),
        mascotStyle: game.economy.equippedPathMascotStyle,
      ),
      notation: NotationLabHubScreen(
        entries: _notationEntries,
        onOpen: (entry) => unawaited(_openNotation(entry)),
        mascotStyle: game.economy.equippedPathMascotStyle,
      ),
      league: LeagueScreen(
        player: game.player,
        schoolMode: widget.schoolMode,
        mascotStyle: game.economy.equippedPathMascotStyle,
        onOpenLanSocial: widget.lanSocialAllowed && !widget.schoolMode
            ? () => unawaited(_openLanSocial())
            : null,
        classCompleted: classroomQuest?.progress ?? 0,
        classTarget: classroomQuest?.target ?? 0,
        history: game.leagueHistory,
        localWeeklyLeague: widget.lanSocialAllowed ? null : _localWeeklyLeague,
        localWeeklyLeagueSetupParticipantCount: _weeklyLeagueParticipantCount,
        onLocalWeeklyLeagueSetupParticipantCountChanged:
            widget.schoolMode || widget.lanSocialAllowed
            ? null
            : (count) => setState(
                () => _weeklyLeagueParticipantCount = count.clamp(2, 8),
              ),
        onStartLocalWeeklyLeague: widget.schoolMode || widget.lanSocialAllowed
            ? null
            : (count) => unawaited(_startWeeklyLeague(count)),
        selectedLocalWeeklyLeagueParticipantId: _selectedCoopParticipantId,
        onSelectLocalWeeklyLeagueParticipant:
            widget.schoolMode || widget.lanSocialAllowed
            ? null
            : _selectCoopParticipant,
        onStartNextLocalWeeklyLeagueRound:
            widget.schoolMode || widget.lanSocialAllowed
            ? null
            : () => unawaited(_startNextWeeklyLeagueRound()),
      ),
      profile: GameProfileScreen(
        player: game.player,
        quests: game.quests,
        monthlyBadges: game.monthlyBadges,
        mascotStyle: game.economy.equippedPathMascotStyle,
        schoolMode: widget.schoolMode,
        explanationCount: _explanationReviewCount,
        onOpenEconomy: widget.schoolMode
            ? null
            : () => unawaited(_showEconomy()),
        onOpenLanSocial: widget.lanSocialAllowed && !widget.schoolMode
            ? () => unawaited(_openLanSocial())
            : null,
        localCoopRun: widget.lanSocialAllowed ? null : _currentLocalCoopRun,
        selectedCoopParticipantId: _selectedCoopParticipantId,
        onStartLocalCoop: widget.schoolMode || widget.lanSocialAllowed
            ? null
            : () => unawaited(_startLocalCoop()),
        onSelectCoopParticipant: widget.schoolMode || widget.lanSocialAllowed
            ? null
            : _selectCoopParticipant,
        localCoopUnavailableReason:
            !widget.schoolMode &&
                _currentLocalCoopRun == null &&
                _localWeeklyLeague?.availability ==
                    LocalWeeklyLeagueAvailability.active
            ? '今週は週次リーグを開始済みです。学習イベントを二重計上しないため、ペアクエストは次の週に作れます。'
            : null,
        onOpenSettings: widget.onOpenSettings,
        onOpenClassroom: widget.onOpenClassroom,
        onExitLocalMode: widget.onExitLocalMode,
      ),
    );
  }
}

final class _LanFriendsQuestRefresh {
  const _LanFriendsQuestRefresh.unavailable()
    : authoritative = false,
      state = null;

  const _LanFriendsQuestRefresh.authoritative(this.state)
    : authoritative = true;

  final bool authoritative;
  final LanSocialFriendsQuestState? state;
}

class _NodeTarget {
  const _NodeTarget({
    required this.nodeId,
    required this.unit,
    required this.conceptKey,
    required this.conceptLabel,
    required this.kind,
  });

  final String nodeId;
  final UnitSummary unit;
  final String conceptKey;
  final String conceptLabel;
  final GamePathNodeKind kind;
}

GamePathNode? _pathNodeIn(GamePathViewData path, String id) {
  for (final unit in path.units) {
    for (final node in unit.nodes) {
      if (node.id == id) return node;
    }
  }
  return null;
}

class _PendingGemSpend {
  const _PendingGemSpend({
    required this.id,
    required this.learningDay,
    required this.occurredAt,
  });

  final String id;
  final String learningDay;
  final DateTime occurredAt;
}

final class _PendingHeartLoss {
  const _PendingHeartLoss({
    required this.runId,
    required this.lossId,
    required this.activityIndex,
    required this.learningDay,
    required this.occurredAt,
  });

  final String runId;
  final String lossId;
  final int activityIndex;
  final String learningDay;
  final DateTime occurredAt;
}

/// 同一routeで観測したcanonical needを一度だけ書き、heartの前提にする。
final class _ObservedNeedWriteQueue {
  _ObservedNeedWriteQueue({required this.onPersist});

  final Future<void> Function(LearningNeedEvidence evidence) onPersist;
  final Map<String, Future<void>> _writes = {};

  void record(LearningNeedEvidence evidence) {
    if (evidence.kind != LearningNeedEvidenceKind.observed) return;
    final key = '${evidence.conceptKey}:${evidence.needCode}';
    if (_writes.containsKey(key)) return;
    final work = onPersist(evidence);
    _writes[key] = work;
    // callback直後に失敗してもunhandledにせず、drain側には元のerrorを残す。
    unawaited(work.then<void>((_) {}, onError: (Object _, StackTrace _) {}));
  }

  Future<void> drain() async {
    for (final write in _writes.values) {
      await write;
    }
  }
}

/// 画面内の同期callbackを、保存順が確定した冪等heart lossへ直列化する。
///
/// fixed task ID自体は保存せずfingerprintだけをloss IDへ使う。選択内容は
/// callbackへ来ないため、誤答本文・選択肢・反応時間が台帳へ流れない。
final class _HeartLossQueue {
  _HeartLossQueue({required LearningRun run, required this.onApply})
    : _runId = run.runId,
      _nextActivityIndex = run.activityIndex;

  final String _runId;
  final Future<void> Function(_PendingHeartLoss loss) onApply;
  int _nextActivityIndex;
  Future<void> _pending = Future<void>.value();
  Object? _firstError;
  StackTrace? _firstStack;

  void report(LearningHeartLossEvidence evidence) => reportAfter(evidence);

  void reportAfter(
    LearningHeartLossEvidence evidence, {
    Future<void> Function()? beforeApply,
  }) {
    final activityIndex = ++_nextActivityIndex;
    final now = DateTime.now();
    final loss = _PendingHeartLoss(
      runId: _runId,
      lossId:
          '$_runId:loss:$activityIndex:'
          '${_stableOpaqueFingerprint(evidence.fixedTaskId)}',
      activityIndex: activityIndex,
      learningDay: dayKeyOf(now),
      occurredAt: now.toUtc(),
    );
    _pending = _pending
        .then((_) async {
          if (_firstError != null) return;
          if (beforeApply != null) await beforeApply();
          await onApply(loss);
        })
        .catchError((Object error, StackTrace stack) {
          _firstError ??= error;
          _firstStack ??= stack;
        });
  }

  Future<void> drain() async {
    await _pending;
    final error = _firstError;
    if (error != null) {
      Error.throwWithStackTrace(error, _firstStack ?? StackTrace.current);
    }
  }
}

/// 回答ではなくcatalog固定need集合だけから作る、process間で安定した短い指紋。
String _stableNeedFingerprint(Map<String, Set<String>> needs) {
  final entries = <String>[];
  final skillIds = needs.keys.toList()..sort();
  for (final skillId in skillIds) {
    final codes = needs[skillId]!.toList()..sort();
    for (final code in codes) {
      entries.add('$skillId=$code');
    }
  }
  return _stableOpaqueFingerprint(entries.join('|'));
}

String _stableOpaqueFingerprint(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

String _notationNodeId(String unitId, String conceptKey) =>
    'notation:v1:$unitId:$conceptKey';

String _learningDayPlus(String day, int offset) {
  final shifted = DateTime.parse(day).add(Duration(days: offset));
  return '${shifted.year.toString().padLeft(4, '0')}-'
      '${shifted.month.toString().padLeft(2, '0')}-'
      '${shifted.day.toString().padLeft(2, '0')}';
}

NotationLabState _notationState({
  required bool unlocked,
  required bool completed,
  required bool due,
}) {
  if (!unlocked) return NotationLabState.locked;
  if (completed && due) return NotationLabState.reviewDue;
  if (completed) return NotationLabState.completed;
  return NotationLabState.available;
}

LearningOrigin _originFor(GamePathNodeKind kind) => switch (kind) {
  GamePathNodeKind.story => LearningOrigin.story,
  GamePathNodeKind.practice => LearningOrigin.lab,
  GamePathNodeKind.challenge ||
  GamePathNodeKind.legendary => LearningOrigin.challenge,
  _ => LearningOrigin.path,
};

LearningActivityKind _activityKindFor(GamePathNodeKind kind) => switch (kind) {
  GamePathNodeKind.lesson => LearningActivityKind.read,
  GamePathNodeKind.practice => LearningActivityKind.diagram,
  GamePathNodeKind.story => LearningActivityKind.story,
  GamePathNodeKind.listening => LearningActivityKind.listen,
  GamePathNodeKind.speaking => LearningActivityKind.speak,
  GamePathNodeKind.challenge ||
  GamePathNodeKind.legendary => LearningActivityKind.transfer,
};

LearningAttemptOutcome _outcomeFor(GamePathNodeKind kind) => switch (kind) {
  GamePathNodeKind.story ||
  GamePathNodeKind.challenge ||
  GamePathNodeKind.legendary => LearningAttemptOutcome.corrected,
  _ => LearningAttemptOutcome.completed,
};

LearningEvidenceLevel _evidenceFor(GamePathNodeKind kind) => switch (kind) {
  GamePathNodeKind.story => LearningEvidenceLevel.structuredCorrection,
  GamePathNodeKind.challenge => LearningEvidenceLevel.transfer,
  GamePathNodeKind.legendary => LearningEvidenceLevel.spacedTransfer,
  _ => LearningEvidenceLevel.selfCompared,
};

String _completionEyebrow(GamePathNodeKind kind) => switch (kind) {
  GamePathNodeKind.lesson => 'TEXT LAB COMPLETE',
  GamePathNodeKind.practice => 'SCIENCE LAB COMPLETE',
  GamePathNodeKind.story => 'SCIENCE STORY COMPLETE',
  GamePathNodeKind.listening => 'LISTEN LAB COMPLETE',
  GamePathNodeKind.speaking => 'SPEAK LAB COMPLETE',
  GamePathNodeKind.challenge => 'BOSS COMPLETE',
  GamePathNodeKind.legendary => 'LEGENDARY COMPLETE',
};

String _completionMessage(GamePathNodeKind kind, bool foundRepairNeed) {
  if (foundRepairNeed) {
    return '見直したポイントを次の個別練習へつなぎ、マップの一歩を進めました。';
  }
  return switch (kind) {
    GamePathNodeKind.lesson => '自分の予想と教材を比べて、次の実験へ進めます。',
    GamePathNodeKind.practice => '条件を構造で確かめて、次の一歩を開きました。',
    GamePathNodeKind.story => '物語の中の思い込みを見つけ、科学の説明へつなげました。',
    GamePathNodeKind.listening => '聞いた説明を条件と結び付け、次の一歩を開きました。',
    GamePathNodeKind.speaking => '自分の声または文字で教え、問い返しを考えて説明を磨きました。',
    GamePathNodeKind.challenge => '別の場面へ考え方を使い、章ボスをクリアしました。',
    GamePathNodeKind.legendary => 'ヒントなしの固定課題を最後まで確かめました。',
  };
}
