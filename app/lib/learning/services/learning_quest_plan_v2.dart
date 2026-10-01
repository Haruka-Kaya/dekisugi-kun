import '../../models/day_key.dart';
import '../../models/game_path.dart';
import '../../models/lan_social.dart';
import '../domain/learning_event.dart';
import '../domain/learning_monthly_badge.dart';
import '../domain/learning_policy.dart';
import '../domain/learning_progress.dart';

/// 観察予定が開く先。UIのindexを保存せず、Homeがこの値を現在の6タブへ変換する。
enum LearningQuestDestination {
  path,
  stories,
  practice,
  notation,
  profile,
  lanSocial,
}

/// 遷移先の中で、CTAが指す固有の学習入口。
///
/// 文字列keyをplannerへ渡さないため、画面改名や翻訳で保存契約が変わらない。
enum LearningQuestFocus {
  currentPathNode,
  nextStory,
  dailyListening,
  dailySpeaking,
  nextDiagram,
  nextNotation,
  duePractice,
  monthlyBadgeCollection,
  localFriendsQuest,
  lanFriendsQuest,
}

/// Under-18本人利用を含むlocal-only、成人同意済みLAN、学校を混ぜない境界。
enum LearningQuestAudience {
  personalLocalOnly,
  personalLanConsented,
  schoolLocal;

  LearningScope get scope => this == LearningQuestAudience.schoolLocal
      ? LearningScope.schoolLocal
      : LearningScope.personal;

  bool get allowsPersonalRewards => scope == LearningScope.personal;
  bool get allowsLanFriends =>
      this == LearningQuestAudience.personalLanConsented;
}

enum LearningDailyQuestVariant {
  comparePrediction,
  storyCase,
  listening,
  speaking,
  diagram,
  notation,
  transfer,
  spacedReview,
}

enum LearningQuestPresentationKind { daily, monthly, friend, classroom }

final class LearningQuestAction {
  const LearningQuestAction({
    required this.label,
    required this.destination,
    required this.focus,
  });

  final String label;
  final LearningQuestDestination destination;
  final LearningQuestFocus focus;
}

/// 観察予定ボードへ渡す、進捗を含まない固定表示契約。
final class LearningQuestPresentation {
  const LearningQuestPresentation({
    required this.questInstanceId,
    required this.kind,
    required this.title,
    required this.description,
    required this.action,
  });

  final String questInstanceId;
  final LearningQuestPresentationKind kind;
  final String title;
  final String description;
  final LearningQuestAction action;
}

/// 同日に表示したvariantを0件の時点で保存するためのplanner出力。
///
/// 現Storeは最初のmatching eventでしかQuest行を作らない。Home統合時は、この
/// listを新しい冪等materialize APIへ渡してから観察予定を公開する。そうしないと
/// 別activityの完了で候補集合が変わり、未着手のdailyが同日中に差し替わりうる。
final class LearningQuestPlanV2 {
  LearningQuestPlanV2({
    required this.learningDay,
    required this.audience,
    required LearningQuestDefinition? dailyDefinition,
    required LearningQuestPresentation? dailyPresentation,
    required Iterable<LearningQuestDefinition> activeDefinitions,
    required Iterable<LearningQuestDefinition> definitionsToMaterialize,
    required Map<String, LearningQuestPresentation> presentations,
  }) : _dailyDefinition = dailyDefinition,
       _dailyPresentation = dailyPresentation,
       activeDefinitions = List.unmodifiable(activeDefinitions),
       definitionsToMaterialize = List.unmodifiable(definitionsToMaterialize),
       presentations = Map.unmodifiable(presentations) {
    if ((dailyDefinition == null) != (dailyPresentation == null)) {
      throw ArgumentError('daily definition and presentation must agree');
    }
  }

  final String learningDay;
  final LearningQuestAudience audience;
  final LearningQuestDefinition? _dailyDefinition;
  final LearningQuestPresentation? _dailyPresentation;
  final List<LearningQuestDefinition> activeDefinitions;
  final List<LearningQuestDefinition> definitionsToMaterialize;
  final Map<String, LearningQuestPresentation> presentations;

  bool get hasDailyQuest => _dailyDefinition != null;

  /// [hasDailyQuest]がtrueのplanだけで使う。既存の型付きplanner利用を保つ。
  LearningQuestDefinition get dailyDefinition =>
      _dailyDefinition ??
      (throw StateError('no meaningful daily quest is available'));

  LearningQuestPresentation get dailyPresentation =>
      _dailyPresentation ??
      (throw StateError('no meaningful daily quest is available'));

  LearningCommitRules get commitRules =>
      LearningCommitRules(quests: activeDefinitions);
}

/// 現在の探究ノートと、意味のある未完了Notation／期限復習だけから候補を作る。
///
/// 完了済みnodeの単なる周回はStoreでmeaningfulにならないため候補にしない。
final class LearningDailyQuestAvailabilityProjection {
  const LearningDailyQuestAvailabilityProjection();

  Set<LearningDailyQuestVariant> build({
    required GamePathViewData path,
    bool hasMeaningfulNotation = false,
    bool hasDueSpacedReview = false,
    bool hasDailyListening = false,
    bool hasDailySpeaking = false,
  }) {
    final variants = <LearningDailyQuestVariant>{};
    final currentId = path.currentNodeId;
    if (currentId != null) {
      GamePathNode? current;
      for (final unit in path.units) {
        for (final node in unit.nodes) {
          if (node.id == currentId) current = node;
        }
      }
      if (current != null &&
          (current.state == GamePathNodeState.available ||
              current.state == GamePathNodeState.inProgress)) {
        variants.add(_variantForPathKind(current.kind));
      }
    }
    if (hasMeaningfulNotation) variants.add(LearningDailyQuestVariant.notation);
    if (hasDailyListening) variants.add(LearningDailyQuestVariant.listening);
    if (hasDailySpeaking) variants.add(LearningDailyQuestVariant.speaking);
    if (hasDueSpacedReview) {
      variants.add(LearningDailyQuestVariant.spacedReview);
    }
    return Set.unmodifiable(variants);
  }

  static LearningDailyQuestVariant _variantForPathKind(GamePathNodeKind kind) =>
      switch (kind) {
        GamePathNodeKind.lesson => LearningDailyQuestVariant.comparePrediction,
        GamePathNodeKind.story => LearningDailyQuestVariant.storyCase,
        GamePathNodeKind.listening => LearningDailyQuestVariant.listening,
        GamePathNodeKind.speaking => LearningDailyQuestVariant.speaking,
        GamePathNodeKind.practice => LearningDailyQuestVariant.diagram,
        GamePathNodeKind.challenge ||
        GamePathNodeKind.legendary => LearningDailyQuestVariant.transfer,
      };
}

/// 件数交互ではなく、到達可能な学習行為を学習日ごとに巡回するV2 planner。
///
/// - 4時境界は[dayKeyOf]だけを正本にする。
/// - 新規日は候補の中から日ordinalで決定論的に選ぶ。
/// - 0件でmaterialize済みの同日definitionがあれば、候補が変わっても復元する。
/// - dailyはすべてmeaningful event 1件で達成し、反復作業を要求しない。
/// - monthlyは同じmeaningful台帳12件と固定badgeを維持する。
final class LearningQuestPlannerV2 {
  const LearningQuestPlannerV2();

  static const String definitionVersion = 'daily.content.v2';
  static const int dailyTarget = 1;
  static const int dailyRewardGems = 1;
  static const int monthlyRewardGems = 8;

  /// 永続schemaへfiltersや報酬額を追加せず、instance IDをmetadataの正本にする。
  ///
  /// V2でmaterializeできるIDは、ここからorigin/activity/evidence/rewardを含む
  /// definition全体を一意に復元できなければならない。Storeもcommit時と
  /// materialize時にこの関数を使い、同じIDへ別条件を差し込ませない。
  static LearningQuestDefinition canonicalDefinitionForInstanceId(
    String questInstanceId,
  ) {
    final parts = questInstanceId.split(':');
    if (parts.length == 3 && parts.first == 'daily') {
      _DailyQuestSpec? spec;
      for (final candidate in _dailySpecs.values) {
        if (candidate.key == parts[2]) {
          spec = candidate;
          break;
        }
      }
      if (spec != null) return spec.definition(parts[1]);
    }
    if (parts.length == 3 &&
        parts.first == 'monthly' &&
        parts[2] == LearningMonthlyBadgeCatalogV1.questKey) {
      return LearningQuestDefinition.monthly(
        learningMonth: parts[1],
        questKey: LearningMonthlyBadgeCatalogV1.questKey,
        definitionVersion: LearningMonthlyBadgeCatalogV1.definitionVersion,
        target: LearningMonthlyBadgeCatalogV1.target,
        rewardGems: monthlyRewardGems,
      );
    }
    throw ArgumentError.value(
      questInstanceId,
      'questInstanceId',
      'a canonical V2 daily or monthly quest ID is required',
    );
  }

  /// 通常commitでもcanonical照合を強制すべきV2管理definitionかを返す。
  ///
  /// 既知keyのversion改変に加え、V2 versionを未知keyへ流用した場合も管理対象に
  /// 含め、[requireCanonicalMaterializedDefinition]でfail closedにする。
  static bool managesMaterializedDefinition(
    LearningQuestDefinition definition,
  ) {
    if (definition.definitionVersion == definitionVersion) return true;
    final parts = definition.questInstanceId.split(':');
    if (parts.length != 3) return false;
    if (parts.first == 'daily') {
      return _dailySpecs.values.any((spec) => spec.key == parts[2]);
    }
    return parts.first == 'monthly' &&
        parts[2] == LearningMonthlyBadgeCatalogV1.questKey;
  }

  /// IDから復元した正本と、保存・commit予定のmetadata全体を照合する。
  static void requireCanonicalMaterializedDefinition(
    LearningQuestDefinition definition,
  ) {
    final expected = canonicalDefinitionForInstanceId(
      definition.questInstanceId,
    );
    if (definition.definitionVersion != expected.definitionVersion ||
        definition.target != expected.target ||
        definition.rewardGems != expected.rewardGems ||
        definition.minimumEvidence != expected.minimumEvidence ||
        !_sameSet(definition.allowedOrigins, expected.allowedOrigins) ||
        !_sameSet(
          definition.allowedActivityKinds,
          expected.allowedActivityKinds,
        )) {
      throw StateError('V2 quest definition does not match its instance ID');
    }
  }

  LearningQuestPlanV2 build({
    required DateTime now,
    required LearningQuestAudience audience,
    Iterable<LearningDailyQuestVariant> availableVariants = const [],
    Iterable<LearningQuestProgress> persistedQuests = const [],
  }) {
    final learningDay = dayKeyOf(now.toLocal());
    final saved = persistedQuests.toList(growable: false);
    if (audience == LearningQuestAudience.schoolLocal) {
      if (saved.isNotEmpty) {
        throw StateError('school quest definitions must not be persisted');
      }
      return _schoolPlan(learningDay);
    }
    if (saved.any((quest) => quest.scope != LearningScope.personal)) {
      throw StateError('personal quest plan received another scope');
    }

    final dailyRows = saved
        .where((quest) => quest.scope == LearningScope.personal)
        .where(
          (quest) => quest.questInstanceId.startsWith('daily:$learningDay:'),
        )
        .toList(growable: false);
    if (dailyRows.length > 1) {
      throw StateError('multiple daily quest variants were materialized');
    }

    LearningQuestDefinition? daily;
    LearningQuestPresentation? dailyPresentation;
    final definitionsToMaterialize = <LearningQuestDefinition>[];
    if (dailyRows case [final row]) {
      final restored = _restoreDaily(learningDay, row);
      daily = restored.definition;
      dailyPresentation = restored.presentation;
    } else {
      final unique = availableVariants.toSet().toList()
        ..sort((left, right) => left.index.compareTo(right.index));
      if (unique.isNotEmpty) {
        final variant = unique[_dayOrdinal(learningDay) % unique.length];
        final spec = _dailySpecs[variant]!;
        daily = spec.definition(learningDay);
        dailyPresentation = spec.presentation(learningDay);
        definitionsToMaterialize.add(daily);
      }
    }

    final month = learningDay.substring(0, 7);
    final monthly = LearningQuestDefinition.monthly(
      learningMonth: month,
      questKey: LearningMonthlyBadgeCatalogV1.questKey,
      definitionVersion: LearningMonthlyBadgeCatalogV1.definitionVersion,
      target: LearningMonthlyBadgeCatalogV1.target,
      rewardGems: monthlyRewardGems,
    );
    final monthlyPresentation = LearningQuestPresentation(
      questInstanceId: monthly.questInstanceId,
      kind: LearningQuestPresentationKind.monthly,
      title: '今月の観測印を完成させる',
      description: daily == null
          ? '今月の探究記録です。今日は新しい予定を作らず、次の再観察日を待ちます。'
          : '今月、意味のある観察記録を${LearningMonthlyBadgeCatalogV1.target}件積み重ねます。',
      action: daily == null
          ? const LearningQuestAction(
              label: '今月の記録を見る',
              destination: LearningQuestDestination.profile,
              focus: LearningQuestFocus.monthlyBadgeCollection,
            )
          : const LearningQuestAction(
              label: '探究ノートを進める',
              destination: LearningQuestDestination.path,
              focus: LearningQuestFocus.currentPathNode,
            ),
    );
    _validatePersistedDefinition(monthly, saved);
    if (!saved.any(
      (quest) => quest.questInstanceId == monthly.questInstanceId,
    )) {
      definitionsToMaterialize.add(monthly);
    }

    return LearningQuestPlanV2(
      learningDay: learningDay,
      audience: audience,
      dailyDefinition: daily,
      dailyPresentation: dailyPresentation,
      activeDefinitions: [?daily, monthly],
      definitionsToMaterialize: definitionsToMaterialize,
      presentations: {
        if (daily != null) daily.questInstanceId: dailyPresentation!,
        monthly.questInstanceId: monthlyPresentation,
      },
    );
  }

  static LearningQuestPlanV2 _schoolPlan(String learningDay) {
    final daily = LearningQuestDefinition.daily(
      learningDay: learningDay,
      questKey: 'one-action',
      definitionVersion: 'daily.v1',
      target: 1,
      rewardGems: 0,
    );
    final presentation = LearningQuestPresentation(
      questInstanceId: daily.questInstanceId,
      kind: LearningQuestPresentationKind.classroom,
      title: 'この端末で授業観察を1件記録する',
      description: '個人の探究記録・結晶・共同観測へ混ぜず、この端末の授業予定だけを進めます。',
      action: const LearningQuestAction(
        label: '授業の観察へ',
        destination: LearningQuestDestination.path,
        focus: LearningQuestFocus.currentPathNode,
      ),
    );
    return LearningQuestPlanV2(
      learningDay: learningDay,
      audience: LearningQuestAudience.schoolLocal,
      dailyDefinition: daily,
      dailyPresentation: presentation,
      activeDefinitions: [daily],
      definitionsToMaterialize: const [],
      presentations: {daily.questInstanceId: presentation},
    );
  }

  static _RestoredDaily _restoreDaily(
    String learningDay,
    LearningQuestProgress saved,
  ) {
    final key = saved.questInstanceId.split(':').last;
    for (final entry in _dailySpecs.entries) {
      if (entry.value.key != key) continue;
      final definition = entry.value.definition(learningDay);
      _requireCompatible(saved, definition);
      return _RestoredDaily(
        definition: definition,
        presentation: entry.value.presentation(learningDay),
      );
    }

    final legacy = switch (key) {
      'one-action' => (version: 'daily.v1', target: 1, title: '今日の観察を1件記録する'),
      'two-actions' => (version: 'daily.v2', target: 2, title: '今日の観察を2件記録する'),
      _ => null,
    };
    if (legacy == null) {
      throw StateError('unknown materialized daily quest variant');
    }
    final definition = LearningQuestDefinition.daily(
      learningDay: learningDay,
      questKey: key,
      definitionVersion: legacy.version,
      target: legacy.target,
      rewardGems: dailyRewardGems,
    );
    _requireCompatible(saved, definition);
    return _RestoredDaily(
      definition: definition,
      presentation: LearningQuestPresentation(
        questInstanceId: definition.questInstanceId,
        kind: LearningQuestPresentationKind.daily,
        title: legacy.title,
        description: '同日に開始済みの観察予定です。途中で内容や件数を変えません。',
        action: const LearningQuestAction(
          label: '探究ノートへ',
          destination: LearningQuestDestination.path,
          focus: LearningQuestFocus.currentPathNode,
        ),
      ),
    );
  }

  static void _validatePersistedDefinition(
    LearningQuestDefinition definition,
    Iterable<LearningQuestProgress> persisted,
  ) {
    for (final saved in persisted) {
      if (saved.questInstanceId == definition.questInstanceId) {
        _requireCompatible(saved, definition);
      }
    }
  }

  static void _requireCompatible(
    LearningQuestProgress saved,
    LearningQuestDefinition definition,
  ) {
    if (saved.scope != LearningScope.personal ||
        saved.target != definition.target ||
        saved.definitionVersion != definition.definitionVersion) {
      throw StateError('materialized quest definition is incompatible');
    }
  }

  static int _dayOrdinal(String learningDay) => DateTime.parse(
    '${learningDay}T00:00:00Z',
  ).difference(DateTime.utc(1970)).inDays;
}

bool _sameSet<T>(Set<T> left, Set<T> right) =>
    left.length == right.length && left.containsAll(right);

enum LearningQuestBoardState { active, completed, rewarded }

final class LearningQuestBoardItem {
  const LearningQuestBoardItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
    required this.current,
    required this.target,
    required this.rewardGems,
    required this.state,
    required this.action,
  });

  final String id;
  final LearningQuestPresentationKind kind;
  final String title;
  final String description;
  final int current;
  final int target;
  final int rewardGems;
  final LearningQuestBoardState state;
  final LearningQuestAction action;
}

enum LearningFriendsQuestChannel { localPair, lan }

/// 共通の観察予定へ渡せる、氏名・回答・友達graphを含まない共同観察投影。
final class LearningFriendsQuestBoardSource {
  const LearningFriendsQuestBoardSource._({
    required this.channel,
    required this.item,
  });

  factory LearningFriendsQuestBoardSource.localInvite({
    required String weekKey,
  }) {
    if (learningWeekKey(weekKey) != weekKey) {
      throw ArgumentError.value(weekKey, 'weekKey', 'Monday required');
    }
    return LearningFriendsQuestBoardSource._(
      channel: LearningFriendsQuestChannel.localPair,
      item: LearningQuestBoardItem(
        id: 'local-pair-invite:$weekKey',
        kind: LearningQuestPresentationKind.friend,
        title: '端末内で共同観察を始める',
        description: '同じ場所にいる2人で端末を交代し、それぞれ観察記録を1件残します。',
        current: 0,
        target: 2,
        rewardGems: 3,
        state: LearningQuestBoardState.active,
        action: const LearningQuestAction(
          label: 'ふたりの観察を準備する',
          destination: LearningQuestDestination.profile,
          focus: LearningQuestFocus.localFriendsQuest,
        ),
      ),
    );
  }

  factory LearningFriendsQuestBoardSource.localRun(LearningLocalCoopRun run) {
    if (run.scope != LearningScope.personal ||
        run.definitionVersion != 'local-pair.v1' ||
        run.target != 2 ||
        run.participantIds.length != 2 ||
        run.rewardGems != 3 ||
        run.progress != run.contributingParticipantIds.length ||
        !run.participantIds.containsAll(run.contributingParticipantIds) ||
        (run.completed != (run.progress == run.target)) ||
        (run.rewardedAt != null && !run.completed)) {
      throw ArgumentError('only a personal two-slot pair quest is supported');
    }
    return LearningFriendsQuestBoardSource._(
      channel: LearningFriendsQuestChannel.localPair,
      item: LearningQuestBoardItem(
        id: run.questInstanceId,
        kind: LearningQuestPresentationKind.friend,
        title: '端末内の共同観察',
        description: '同じ端末を2人で交代し、それぞれ観察記録を1件残します。氏名は保存しません。',
        current: run.progress.clamp(0, run.target),
        target: run.target,
        rewardGems: run.rewardGems,
        state: run.rewardedAt != null
            ? LearningQuestBoardState.rewarded
            : run.completed
            ? LearningQuestBoardState.completed
            : LearningQuestBoardState.active,
        action: const LearningQuestAction(
          label: '担当を選んで観察する',
          destination: LearningQuestDestination.profile,
          focus: LearningQuestFocus.localFriendsQuest,
        ),
      ),
    );
  }

  factory LearningFriendsQuestBoardSource.lanInvite() =>
      const LearningFriendsQuestBoardSource._(
        channel: LearningFriendsQuestChannel.lan,
        item: LearningQuestBoardItem(
          id: 'lan-friends-invite',
          kind: LearningQuestPresentationKind.friend,
          title: 'ふたりの共同観察を始める',
          description: '成人同意後、同じWi-Fiの実在する2人がそれぞれ観察記録を1件残します。',
          current: 0,
          target: 2,
          rewardGems: 1,
          state: LearningQuestBoardState.active,
          action: LearningQuestAction(
            label: '参加コードを開く',
            destination: LearningQuestDestination.lanSocial,
            focus: LearningQuestFocus.lanFriendsQuest,
          ),
        ),
      );

  factory LearningFriendsQuestBoardSource.lanRoom({
    required String roomId,
    required LanSocialFriendsSnapshot snapshot,
    required bool rewardRecorded,
  }) {
    if (!RegExp(r'^[a-f0-9]{24}$').hasMatch(roomId)) {
      throw ArgumentError.value(roomId, 'roomId');
    }
    final validSnapshot = switch (snapshot.state) {
      LanSocialFriendsState.waitingForPartner =>
        !snapshot.partnerJoined &&
            !snapshot.myContributed &&
            !snapshot.completed,
      LanSocialFriendsState.active =>
        snapshot.partnerJoined && !snapshot.completed,
      LanSocialFriendsState.completed =>
        snapshot.partnerJoined && snapshot.completed,
      LanSocialFriendsState.expired => true,
    };
    if (!validSnapshot || (rewardRecorded && !snapshot.completed)) {
      throw ArgumentError('inconsistent LAN friends snapshot');
    }
    final current = snapshot.completed
        ? 2
        : snapshot.myContributed
        ? 1
        : 0;
    final description = switch (snapshot.state) {
      LanSocialFriendsState.waitingForPartner =>
        '参加コードを、同じWi-Fiでいっしょに学ぶ1人へ渡します。',
      LanSocialFriendsState.active =>
        snapshot.myContributed
            ? '自分の観察記録は届きました。相手の記録を待っています。'
            : '2人がそれぞれ観察記録を1件残すと達成です。',
      LanSocialFriendsState.completed => '実在する2人の観察記録がそろいました。',
      LanSocialFriendsState.expired =>
        snapshot.completed
            ? '終了前に2人の観察記録がそろいました。'
            : 'この共同観察は終了しました。新しい参加コードで始められます。',
    };
    return LearningFriendsQuestBoardSource._(
      channel: LearningFriendsQuestChannel.lan,
      item: LearningQuestBoardItem(
        id: 'lan-friends:$roomId',
        kind: LearningQuestPresentationKind.friend,
        title: 'ふたりの共同観察',
        description: description,
        current: current,
        target: 2,
        rewardGems: 1,
        state: rewardRecorded
            ? LearningQuestBoardState.rewarded
            : snapshot.completed
            ? LearningQuestBoardState.completed
            : LearningQuestBoardState.active,
        action: const LearningQuestAction(
          label: 'ふたりの観察記録を開く',
          destination: LearningQuestDestination.lanSocial,
          focus: LearningQuestFocus.lanFriendsQuest,
        ),
      ),
    );
  }

  final LearningFriendsQuestChannel channel;
  final LearningQuestBoardItem item;
}

/// 今日・今月・共同観察を同じ順序・同じ状態表現へ束ねるpure projection。
final class LearningQuestBoardProjectionV2 {
  const LearningQuestBoardProjectionV2();

  List<LearningQuestBoardItem> build({
    required LearningQuestPlanV2 plan,
    Iterable<LearningQuestProgress> persistedQuests = const [],
    LearningFriendsQuestBoardSource? friends,
    int schoolDailyProgress = 0,
  }) {
    if (schoolDailyProgress < 0) {
      throw ArgumentError.value(schoolDailyProgress, 'schoolDailyProgress');
    }
    _validateFriendsBoundary(plan.audience, friends);
    final persisted = <String, LearningQuestProgress>{};
    for (final quest in persistedQuests) {
      if (quest.scope != plan.audience.scope) {
        throw StateError('quest board received another scope');
      }
      if (quest.progress < 0 ||
          quest.progress > quest.target ||
          (quest.rewardedAt != null && !quest.completed) ||
          persisted.containsKey(quest.questInstanceId)) {
        throw StateError('quest board received invalid persisted progress');
      }
      persisted[quest.questInstanceId] = quest;
    }
    final items = <LearningQuestBoardItem>[];
    for (final definition in plan.activeDefinitions) {
      final saved = persisted[definition.questInstanceId];
      if (saved != null &&
          (saved.target != definition.target ||
              saved.definitionVersion != definition.definitionVersion)) {
        throw StateError('quest board received an incompatible definition');
      }
      final presentation = plan.presentations[definition.questInstanceId];
      if (presentation == null) {
        throw StateError('quest board presentation is missing');
      }
      final progress =
          saved?.progress ??
          (plan.audience == LearningQuestAudience.schoolLocal
              ? schoolDailyProgress
              : 0);
      final current = progress.clamp(0, definition.target);
      final state = saved?.rewardedAt != null
          ? LearningQuestBoardState.rewarded
          : (saved?.completed ?? current >= definition.target)
          ? LearningQuestBoardState.completed
          : LearningQuestBoardState.active;
      final action =
          presentation.kind == LearningQuestPresentationKind.monthly &&
              state != LearningQuestBoardState.active
          ? const LearningQuestAction(
              label: '観測印を見る',
              destination: LearningQuestDestination.profile,
              focus: LearningQuestFocus.monthlyBadgeCollection,
            )
          : presentation.action;
      items.add(
        LearningQuestBoardItem(
          id: definition.questInstanceId,
          kind: presentation.kind,
          title: presentation.title,
          description: presentation.description,
          current: current,
          target: definition.target,
          rewardGems: plan.audience.allowsPersonalRewards
              ? definition.rewardGems
              : 0,
          state: state,
          action: action,
        ),
      );
    }
    if (friends != null) items.add(friends.item);
    return List.unmodifiable(items);
  }

  static void _validateFriendsBoundary(
    LearningQuestAudience audience,
    LearningFriendsQuestBoardSource? friends,
  ) {
    if (friends == null) return;
    final allowed = switch (audience) {
      LearningQuestAudience.personalLocalOnly =>
        friends.channel == LearningFriendsQuestChannel.localPair,
      LearningQuestAudience.personalLanConsented =>
        friends.channel == LearningFriendsQuestChannel.lan,
      LearningQuestAudience.schoolLocal => false,
    };
    if (!allowed) {
      throw StateError('friends quest source is not allowed for this audience');
    }
  }
}

final class _DailyQuestSpec {
  const _DailyQuestSpec({
    required this.key,
    required this.title,
    required this.description,
    required this.action,
    required this.allowedOrigins,
    required this.allowedActivityKinds,
    this.minimumEvidence = LearningEvidenceLevel.selfCompared,
  });

  final String key;
  final String title;
  final String description;
  final LearningQuestAction action;
  final Set<LearningOrigin> allowedOrigins;
  final Set<LearningActivityKind> allowedActivityKinds;
  final LearningEvidenceLevel minimumEvidence;

  LearningQuestDefinition definition(String learningDay) =>
      LearningQuestDefinition.daily(
        learningDay: learningDay,
        questKey: key,
        definitionVersion: LearningQuestPlannerV2.definitionVersion,
        target: LearningQuestPlannerV2.dailyTarget,
        rewardGems: LearningQuestPlannerV2.dailyRewardGems,
        allowedOrigins: allowedOrigins,
        allowedActivityKinds: allowedActivityKinds,
        minimumEvidence: minimumEvidence,
      );

  LearningQuestPresentation presentation(String learningDay) {
    final definition = this.definition(learningDay);
    return LearningQuestPresentation(
      questInstanceId: definition.questInstanceId,
      kind: LearningQuestPresentationKind.daily,
      title: title,
      description: description,
      action: action,
    );
  }
}

const _dailySpecs = <LearningDailyQuestVariant, _DailyQuestSpec>{
  LearningDailyQuestVariant.comparePrediction: _DailyQuestSpec(
    key: 'compare-prediction',
    title: '予想と教材を1回照合する',
    description: '答えを見る前の予想を教材の説明と照合し、観察記録へ残します。',
    action: LearningQuestAction(
      label: '予想の観察を始める',
      destination: LearningQuestDestination.path,
      focus: LearningQuestFocus.currentPathNode,
    ),
    allowedOrigins: {LearningOrigin.path},
    allowedActivityKinds: {LearningActivityKind.read},
  ),
  LearningDailyQuestVariant.storyCase: _DailyQuestSpec(
    key: 'story-case',
    title: '事件簿を1話解明する',
    description: '物語の途中で条件を判断し、デキすぎ君の思い込みを直します。',
    action: LearningQuestAction(
      label: '今日の事件簿を開く',
      destination: LearningQuestDestination.stories,
      focus: LearningQuestFocus.nextStory,
    ),
    allowedOrigins: {LearningOrigin.story},
    allowedActivityKinds: {LearningActivityKind.story},
    minimumEvidence: LearningEvidenceLevel.structuredCorrection,
  ),
  LearningDailyQuestVariant.listening: _DailyQuestSpec(
    key: 'listen-for-conditions',
    title: '聞き取り観察で条件を見抜く',
    description: '説明を最後まで聞き、文字起こしと意味を分けて観察します。',
    action: LearningQuestAction(
      label: '聞き取り観察を始める',
      destination: LearningQuestDestination.practice,
      focus: LearningQuestFocus.dailyListening,
    ),
    allowedOrigins: {LearningOrigin.path, LearningOrigin.practice},
    allowedActivityKinds: {LearningActivityKind.listen},
  ),
  LearningDailyQuestVariant.speaking: _DailyQuestSpec(
    key: 'explain-it-back',
    title: '自分のことばで教え返す',
    description: '声または同格の文字経路で説明し、自分で聞き直す・読み直す観察を1件記録します。',
    action: LearningQuestAction(
      label: '教え返しを始める',
      destination: LearningQuestDestination.practice,
      focus: LearningQuestFocus.dailySpeaking,
    ),
    allowedOrigins: {LearningOrigin.path, LearningOrigin.practice},
    allowedActivityKinds: {LearningActivityKind.speak},
  ),
  LearningDailyQuestVariant.diagram: _DailyQuestSpec(
    key: 'diagram-relations',
    title: '図と条件の関係を1つ記録する',
    description: '量・向き・条件の関係を図で組み、教材と照合します。',
    action: LearningQuestAction(
      label: '図の観察を始める',
      destination: LearningQuestDestination.path,
      focus: LearningQuestFocus.nextDiagram,
    ),
    allowedOrigins: {LearningOrigin.lab, LearningOrigin.practice},
    allowedActivityKinds: {LearningActivityKind.diagram},
  ),
  LearningDailyQuestVariant.notation: _DailyQuestSpec(
    key: 'notation-trace',
    title: '式・単位・矢印を意味の順に観察する',
    description: '記号を、なぞる→組む→読むの順で1件確かめます。',
    action: LearningQuestAction(
      label: '記号の観察を開く',
      destination: LearningQuestDestination.notation,
      focus: LearningQuestFocus.nextNotation,
    ),
    allowedOrigins: {LearningOrigin.lab, LearningOrigin.practice},
    allowedActivityKinds: {LearningActivityKind.equation},
    minimumEvidence: LearningEvidenceLevel.structuredCorrection,
  ),
  LearningDailyQuestVariant.transfer: _DailyQuestSpec(
    key: 'transfer-challenge',
    title: '別の場面で原理を1回検証する',
    description: 'ヒントなしの別場面で、同じ原理が使える条件を確かめます。',
    action: LearningQuestAction(
      label: '総合検証へ進む',
      destination: LearningQuestDestination.path,
      focus: LearningQuestFocus.currentPathNode,
    ),
    allowedOrigins: {LearningOrigin.challenge},
    allowedActivityKinds: {LearningActivityKind.transfer},
    minimumEvidence: LearningEvidenceLevel.transfer,
  ),
  LearningDailyQuestVariant.spacedReview: _DailyQuestSpec(
    key: 'spaced-review',
    title: '期限の来た記録を思い出す',
    description: '前回から間隔を空けた内容を、答えを見る前に1件再観察します。',
    action: LearningQuestAction(
      label: '再観察を始める',
      destination: LearningQuestDestination.practice,
      focus: LearningQuestFocus.duePractice,
    ),
    allowedOrigins: {LearningOrigin.practice},
    allowedActivityKinds: {LearningActivityKind.diagram},
    minimumEvidence: LearningEvidenceLevel.spacedTransfer,
  ),
};

final class _RestoredDaily {
  const _RestoredDaily({required this.definition, required this.presentation});

  final LearningQuestDefinition definition;
  final LearningQuestPresentation presentation;
}
