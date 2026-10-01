import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../learning/domain/learning_event.dart';
import '../models/lan_social.dart';
import 'session_store.dart';

const String lanSocialConsentVersion = 'lan-social.v1';

enum LanSocialClientError {
  optInRequired,
  invalidConnectionCode,
  alreadyJoined,
  notJoined,
  notMeaningful,
  schoolLeagueDisabled,
  unauthorized,
  roomNotFound,
  roomExpired,
  roomFull,
  rateLimited,
  wrongDay,
  unavailable,
  invalidResponse,
}

final class LanSocialJoinResult {
  const LanSocialJoinResult({this.membership, this.error});

  final LanSocialMembership? membership;
  final LanSocialClientError? error;

  bool get joined => membership != null && error == null;
}

final class LanSocialContributionResult {
  const LanSocialContributionResult({
    required this.applied,
    required this.xpAdded,
    required this.snapshot,
  });

  final bool applied;
  final int xpAdded;
  final LanSocialSnapshot snapshot;
}

final class LanSocialRefreshResult {
  const LanSocialRefreshResult.live({
    required this.snapshot,
    required this.leagueProfile,
  }) : terminalReceipt = null;

  const LanSocialRefreshResult.settled({
    required this.terminalReceipt,
    required this.leagueProfile,
  }) : snapshot = null;

  final LanSocialSnapshot? snapshot;
  final LanSocialTerminalReceipt? terminalReceipt;
  final LanSocialLeagueProfile leagueProfile;
}

final class _LanSocialRemoteState {
  const _LanSocialRemoteState.live(this.snapshot) : terminalReceipt = null;

  const _LanSocialRemoteState.settled(this.terminalReceipt) : snapshot = null;

  const _LanSocialRemoteState.unavailable()
    : snapshot = null,
      terminalReceipt = null;

  final LanSocialSnapshot? snapshot;
  final LanSocialTerminalReceipt? terminalReceipt;
}

typedef LanSocialProgressClientFactory =
    LanSocialClient Function(LanSocialEndpoint endpoint);

/// 端末へ確定済みのmeaningful eventだけを、保存済みの各LAN roomへ反映する。
///
/// membershipの破損・TLS・coordinator停止は各roomのsocial更新だけを閉じ、
/// 呼び出し元の学習commitへ例外を戻さない。school eventは構造上送信しない。
final class LanSocialMeaningfulProgressDispatcher {
  LanSocialMeaningfulProgressDispatcher({
    required this.store,
    this.clientFactory,
  });

  final SessionStore store;
  final LanSocialProgressClientFactory? clientFactory;
  final Map<String, LanSocialClient> _clients = {};
  Future<void> _tail = Future<void>.value();

  Future<void> contribute(LearningEventRecord event) {
    final result = _tail.then((_) => _contributeNow(event));
    _tail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace stackTrace) {},
    );
    return result;
  }

  Future<void> _contributeNow(LearningEventRecord event) async {
    if (event.scope != LearningScope.personal || !event.meaningfulProgress) {
      return;
    }
    List<LanSocialMembership> memberships;
    try {
      memberships = await LanSocialClient.savedMemberships(store);
    } on Object {
      return;
    }
    for (final membership in memberships) {
      try {
        final endpoint = LanSocialEndpoint(
          baseUrl: membership.baseUrl,
          certificateSha256: membership.certificateSha256,
        );
        final key = '${endpoint.baseUrl}|${endpoint.certificateSha256}';
        final client = _clients.putIfAbsent(
          key,
          () =>
              clientFactory?.call(endpoint) ??
              LanSocialClient(endpoint: endpoint, store: store),
        );
        await client.contributeMeaningfulEvent(
          kind: membership.kind,
          event: event,
        );
      } on Object {
        // 次のroomは独立に試す。social障害を学習commitの成否へ混ぜない。
      }
    }
  }
}

/// 自己署名TLSをfingerprint pinし、private LANだけへ接続するsocial client。
///
/// [DeviceIdentity]を受け取らない。join keyはroomごとの乱数で、同じ端末を別room間で
/// 追跡できない。送信可能な学習情報は日キーとsalted event idempotency keyだけ。
final class LanSocialClient {
  factory LanSocialClient({
    required LanSocialEndpoint endpoint,
    required SessionStore store,
    Dio? dio,
    String Function()? opaqueKeyFactory,
  }) {
    final checked = validateLanSocialEndpoint(endpoint);
    return LanSocialClient._(
      endpoint: checked,
      store: store,
      dio: dio ?? _pinnedDio(checked),
      opaqueKeyFactory: opaqueKeyFactory ?? _newOpaqueKey,
    );
  }

  LanSocialClient._({
    required this.endpoint,
    required SessionStore store,
    required Dio dio,
    required String Function() opaqueKeyFactory,
  }) : // 公開factoryのnamed parameter名を保つ。
       // ignore: prefer_initializing_formals
       _store = store,
       // ignore: prefer_initializing_formals
       _dio = dio,
       // ignore: prefer_initializing_formals
       _opaqueKeyFactory = opaqueKeyFactory;

  static const _membershipsKey = 'lan_social.memberships.v1';
  static const _pendingJoinKey = 'lan_social.pending_join.v1';
  static const _pendingCreateKey = 'lan_social.pending_create.v1';
  static const _pendingLeavePrefix = 'lan_social.pending_leave.v1';
  static const _leagueProfileKey = 'lan_social.league_profile.v1';

  final LanSocialEndpoint endpoint;
  final SessionStore _store;
  final Dio _dio;
  final String Function() _opaqueKeyFactory;
  Future<void> _writeTail = Future<void>.value();

  static LanSocialClient fromConnectionCode({
    required String connectionCode,
    required SessionStore store,
    Dio? dio,
    String Function()? opaqueKeyFactory,
  }) {
    final parsed = LanSocialConnectionCode.parse(connectionCode);
    return LanSocialClient(
      endpoint: parsed.endpoint,
      store: store,
      dio: dio,
      opaqueKeyFactory: opaqueKeyFactory,
    );
  }

  /// 起動時の復元用。credentialsはUIへ表示せず、client再構成にだけ使う。
  static Future<List<LanSocialMembership>> savedMemberships(
    SessionStore store,
  ) => _readMemberships(store);

  LanSocialConnectionCode connectionCodeFor(LanSocialCreatedRoom room) =>
      LanSocialConnectionCode(
        endpoint: endpoint,
        inviteCode: room.inviteCode,
        kind: room.kind,
      );

  Future<LanSocialCreatedRoom?> createRoom({
    required LanSocialRoomKind kind,
    required int capacity,
    required String coordinatorKey,
    required bool explicitOptIn,
  }) async {
    if (!explicitOptIn || coordinatorKey.length < 32) return null;
    final pending = await _pendingCreate(kind: kind, capacity: capacity);
    try {
      final response = await _dio.post<Object?>(
        '${endpoint.baseUrl}/v1/lan-social/rooms',
        data: {
          'kind': kind.wire,
          'capacity': capacity,
          'createKey': pending.createKey,
          'optIn': true,
          'consentVersion': lanSocialConsentVersion,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'X-Dekisugi-Coordinator-Key': coordinatorKey,
          },
        ),
      );
      if (response.statusCode != 201) return null;
      final room = LanSocialCreatedRoom.fromJson(_responseMap(response.data));
      if (room.kind != kind || room.capacity != capacity) return null;
      await _store.setSetting(_pendingCreateKey, null);
      return room;
    } on DioException {
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<void> discardPendingRoomCreation() =>
      _store.setSetting(_pendingCreateKey, null);

  Future<LanSocialJoinResult> join(
    LanSocialConnectionCode code, {
    required bool explicitOptIn,
  }) async {
    if (!explicitOptIn) {
      return const LanSocialJoinResult(
        error: LanSocialClientError.optInRequired,
      );
    }
    LanSocialEndpoint checked;
    try {
      checked = validateLanSocialEndpoint(code.endpoint);
    } on ArgumentError {
      return const LanSocialJoinResult(
        error: LanSocialClientError.invalidConnectionCode,
      );
    }
    if (checked.baseUrl != endpoint.baseUrl ||
        checked.certificateSha256 != endpoint.certificateSha256) {
      return const LanSocialJoinResult(
        error: LanSocialClientError.invalidConnectionCode,
      );
    }
    if (await saved(code.kind) != null) {
      return const LanSocialJoinResult(
        error: LanSocialClientError.alreadyJoined,
      );
    }
    final pending = await _pendingJoin(code);
    try {
      final response = await _dio.post<Object?>(
        '${endpoint.baseUrl}/v1/lan-social/join',
        data: {
          'inviteCode': code.inviteCode,
          'joinKey': pending.joinKey,
          'optIn': true,
          'consentVersion': lanSocialConsentVersion,
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      if (response.statusCode != 200) {
        return LanSocialJoinResult(error: _errorFor(response));
      }
      final membership = LanSocialMembership.fromServerJson(
        _responseMap(response.data),
        baseUrl: endpoint.baseUrl,
        certificateSha256: endpoint.certificateSha256,
        eventSalt: pending.eventSalt,
      );
      if (membership.kind != code.kind) {
        return const LanSocialJoinResult(
          error: LanSocialClientError.invalidResponse,
        );
      }
      await _saveMembership(membership);
      await _store.setSetting(_pendingLeaveKey(code.kind), null);
      await _store.setSetting(_pendingJoinKey, null);
      return LanSocialJoinResult(membership: membership);
    } on DioException {
      return const LanSocialJoinResult(error: LanSocialClientError.unavailable);
    } on FormatException {
      return const LanSocialJoinResult(
        error: LanSocialClientError.invalidResponse,
      );
    }
  }

  Future<LanSocialMembership?> saved(LanSocialRoomKind kind) async {
    final memberships = await _loadMemberships();
    return memberships
        .where(
          (membership) =>
              membership.kind == kind &&
              membership.baseUrl == endpoint.baseUrl &&
              membership.certificateSha256 == endpoint.certificateSha256,
        )
        .firstOrNull;
  }

  Future<LanSocialSnapshot?> snapshot(LanSocialRoomKind kind) async {
    final membership = await saved(kind);
    if (membership == null) return null;
    final remote = await _remoteState(membership);
    return remote.snapshot;
  }

  Future<_LanSocialRemoteState> _remoteState(
    LanSocialMembership membership,
  ) async {
    try {
      final response = await _dio.get<Object?>(
        '${endpoint.baseUrl}/v1/lan-social/snapshot',
        options: Options(
          headers: {'Authorization': 'Bearer ${membership.credential}'},
        ),
      );
      if (response.statusCode == 401 || response.statusCode == 410) {
        return await _fetchAndApplyTerminalSettlement(membership);
      }
      if (response.statusCode != 200) {
        return const _LanSocialRemoteState.unavailable();
      }
      final current = LanSocialSnapshot.fromJson(_responseMap(response.data));
      if (current.kind != membership.kind ||
          (current is LanSocialLeagueSnapshot &&
              current.weekStart != membership.weekStart)) {
        return const _LanSocialRemoteState.unavailable();
      }
      await _grantFriendsRewardIfCompleted(membership, current);
      return _LanSocialRemoteState.live(current);
    } on Object {
      return const _LanSocialRemoteState.unavailable();
    }
  }

  Future<LanSocialRefreshResult?> refresh(LanSocialRoomKind kind) async {
    final membership = await saved(kind);
    if (membership == null) return null;
    final remote = await _remoteState(membership);
    var profile = await leagueProfile();
    if (remote.snapshot case final LanSocialLeagueSnapshot league) {
      profile = await finalizeLeague(membership: membership, snapshot: league);
    }
    if (remote.snapshot case final LanSocialSnapshot current) {
      return LanSocialRefreshResult.live(
        snapshot: current,
        leagueProfile: profile,
      );
    }
    if (remote.terminalReceipt case final LanSocialTerminalReceipt receipt) {
      return LanSocialRefreshResult.settled(
        terminalReceipt: receipt,
        leagueProfile: profile,
      );
    }
    return null;
  }

  Future<LanSocialContributionResult?> contributeMeaningfulEvent({
    required LanSocialRoomKind kind,
    required LearningEventRecord event,
  }) async {
    final membership = await saved(kind);
    if (membership == null ||
        !event.meaningfulProgress ||
        await _leavePendingFor(membership)) {
      return null;
    }
    if (kind == LanSocialRoomKind.league &&
        event.scope == LearningScope.schoolLocal) {
      return null;
    }
    final idempotencyKey = _eventKey(membership, event.eventId);
    try {
      final response = await _dio.post<Object?>(
        '${endpoint.baseUrl}/v1/lan-social/contribution',
        data: {
          'idempotencyKey': idempotencyKey,
          'learningDay': event.learningDay,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${membership.credential}',
          },
        ),
      );
      if (response.statusCode == 401 || response.statusCode == 410) {
        await _fetchAndApplyTerminalSettlement(membership);
        return null;
      }
      if (response.statusCode != 200) return null;
      final json = _responseMap(response.data);
      _requireExactKeys(json, const {'applied', 'xpAdded', 'snapshot'});
      final applied = json['applied'];
      final xpAdded = json['xpAdded'];
      final rawSnapshot = json['snapshot'];
      final expectedXp = kind == LanSocialRoomKind.league ? 10 : 0;
      if (applied is! bool ||
          xpAdded is! int ||
          (applied && xpAdded != expectedXp) ||
          (!applied && xpAdded != 0) ||
          rawSnapshot is! Map) {
        return null;
      }
      final parsed = LanSocialSnapshot.fromJson(
        rawSnapshot.cast<String, Object?>(),
      );
      if (parsed.kind != kind) return null;
      await _grantFriendsRewardIfCompleted(membership, parsed);
      return LanSocialContributionResult(
        applied: applied,
        xpAdded: xpAdded,
        snapshot: parsed,
      );
    } on DioException {
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<_LanSocialRemoteState> _fetchAndApplyTerminalSettlement(
    LanSocialMembership membership,
  ) async {
    try {
      final response = await _dio.get<Object?>(
        '${endpoint.baseUrl}/v1/lan-social/settlement',
        options: Options(
          headers: {'Authorization': 'Bearer ${membership.credential}'},
        ),
      );
      if (response.statusCode == 401 || response.statusCode == 410) {
        await _store.setSetting(_pendingLeaveKey(membership.kind), null);
        await _removeMembership(membership);
        return const _LanSocialRemoteState.unavailable();
      }
      // 409はroomがまだ確定前、404は旧coordinator、503/429は再試行可能。
      // いずれもcredentialを消さず、次のrefreshへ持ち越す。
      if (response.statusCode != 200) {
        return const _LanSocialRemoteState.unavailable();
      }
      final receipt = LanSocialTerminalReceipt.fromJson(
        _responseMap(response.data),
      );
      if (receipt.roomId != membership.roomId ||
          receipt.kind != membership.kind ||
          (receipt is LanSocialLeagueTerminalReceipt &&
              receipt.weekStart != membership.weekStart)) {
        return const _LanSocialRemoteState.unavailable();
      }

      // 報酬/tier履歴を先に端末へ確定する。membership削除が失敗しても、次回は
      // room ID冪等性で同じreceiptを再適用できるため二重付与・二重昇格しない。
      await _applyTerminalReceipt(membership, receipt);
      await _store.setSetting(_pendingLeaveKey(membership.kind), null);
      await _removeMembership(membership);
      return _LanSocialRemoteState.settled(receipt);
    } on Object {
      // parse、TLS、local保存のどれが失敗しても再試行資格を失わない。
      return const _LanSocialRemoteState.unavailable();
    }
  }

  Future<void> _applyTerminalReceipt(
    LanSocialMembership membership,
    LanSocialTerminalReceipt receipt,
  ) async {
    switch (receipt) {
      case LanSocialFriendsTerminalReceipt(:final completed, :final settledAt):
        if (completed) {
          await _store.grantLearningLanFriendsReward(
            roomId: membership.roomId,
            completedAt: settledAt,
          );
        }
      case LanSocialLeagueTerminalReceipt(
        :final weekStart,
        :final privacyThresholdReached,
        :final xp,
        :final rank,
        :final tied,
        :final participantCount,
        :final settledAt,
      ):
        if (privacyThresholdReached && participantCount != null) {
          await _finalizeLeagueResult(
            membership: membership,
            weekStart: weekStart,
            xp: xp,
            rank: rank,
            tied: tied,
            participantCount: participantCount,
            finalizedAt: settledAt,
          );
        }
    }
  }

  Future<bool> leave(LanSocialRoomKind kind) async {
    final membership = await saved(kind);
    if (membership == null) return false;
    // opt-outを先に端末へ確定し、応答消失中にHome dispatcherが新しい学習を
    // 送らないようにする。失敗時もこの印とcredentialを残して退出だけ再試行する。
    await _store.setSetting(_pendingLeaveKey(kind), membership.roomId);
    try {
      final response = await _dio.post<Object?>(
        '${endpoint.baseUrl}/v1/lan-social/leave',
        options: Options(
          headers: {'Authorization': 'Bearer ${membership.credential}'},
        ),
      );
      final removedOnServer =
          response.statusCode == 204 || response.statusCode == 401;
      if (!removedOnServer) return false;
      // coordinatorが参加者を削除した、または既に資格情報が無効だと確認できた
      // ときだけ端末側を消す。ここが失敗した場合は資格情報を残し、次回401で
      // 安全に再試行できるよう例外を呼び出し元へ返す。
      await _removeMembership(membership);
      await _store.setSetting(_pendingLeaveKey(kind), null);
      return true;
    } on DioException {
      // timeout/503ではserverが処理したか判断できない。membershipを保持し、
      // participant/contributionを期限まで孤立させないよう再試行可能にする。
      return false;
    }
  }

  /// 退出応答待ちではmembershipを再試行資格として保持するが、学習寄与は止める。
  Future<bool> leavePending(LanSocialRoomKind kind) async {
    final membership = await saved(kind);
    return membership != null && await _leavePendingFor(membership);
  }

  Future<bool> _leavePendingFor(LanSocialMembership membership) async {
    final value = await _store.getSetting(_pendingLeaveKey(membership.kind));
    if (value == null) return false;
    // 未知値や別room値を「送信可」と推測しない。join成功時だけ明示clearする。
    return true;
  }

  static String _pendingLeaveKey(LanSocialRoomKind kind) =>
      '$_pendingLeavePrefix.${kind.wire}';

  Future<void> _grantFriendsRewardIfCompleted(
    LanSocialMembership membership,
    LanSocialSnapshot snapshot,
  ) async {
    if (membership.kind != LanSocialRoomKind.friends ||
        snapshot is! LanSocialFriendsSnapshot ||
        !snapshot.completed) {
      return;
    }
    await _store.grantLearningLanFriendsReward(
      roomId: membership.roomId,
      completedAt: DateTime.now().toUtc(),
    );
  }

  Future<LanSocialLeagueProfile> leagueProfile() async {
    final raw = await _store.getSetting(_leagueProfileKey);
    if (raw == null || raw.isEmpty) {
      return const LanSocialLeagueProfile.initial();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException();
      final json = decoded.cast<String, Object?>();
      _requireExactKeys(json, const {'version', 'currentTier', 'history'});
      final tier = LanSocialLeagueTier.parse(json['currentTier']);
      final rawHistory = json['history'];
      if (json['version'] != 1 || tier == null || rawHistory is! List) {
        throw const FormatException();
      }
      final history = <LanSocialLeagueWeek>[];
      for (final item in rawHistory) {
        if (item is! Map) throw const FormatException();
        history.add(LanSocialLeagueWeek.fromJson(item.cast<String, Object?>()));
      }
      if (history.length > 104 ||
          history.map((item) => item.roomId).toSet().length != history.length ||
          (history.isNotEmpty && history.first.tier != tier)) {
        throw const FormatException();
      }
      return LanSocialLeagueProfile(
        currentTier: tier,
        history: List.unmodifiable(history),
      );
    } on Object {
      // 壊れた履歴を推測で昇降格しない。初期値を返すが、破損物は残して監査可能にする。
      return const LanSocialLeagueProfile.initial();
    }
  }

  Future<LanSocialLeagueProfile> finalizeLeague({
    required LanSocialMembership membership,
    required LanSocialLeagueSnapshot snapshot,
    DateTime? finalizedAt,
  }) async {
    final profile = await leagueProfile();
    if (membership.kind != LanSocialRoomKind.league ||
        membership.roomId.isEmpty ||
        membership.weekStart != snapshot.weekStart ||
        !snapshot.expired ||
        !snapshot.privacyThresholdReached ||
        profile.history.any((week) => week.roomId == membership.roomId)) {
      return profile;
    }
    final mine = snapshot.mine;
    if (mine == null) return profile;

    return _finalizeLeagueResult(
      membership: membership,
      weekStart: snapshot.weekStart,
      xp: mine.xp,
      rank: mine.rank,
      tied: mine.tied,
      participantCount: snapshot.standings.length,
      finalizedAt: (finalizedAt ?? DateTime.now()).toUtc(),
    );
  }

  Future<LanSocialLeagueProfile> _finalizeLeagueResult({
    required LanSocialMembership membership,
    required String weekStart,
    required int xp,
    required int? rank,
    required bool tied,
    required int participantCount,
    required DateTime finalizedAt,
  }) => _serialize(() async {
    final profile = await leagueProfile();
    if (membership.kind != LanSocialRoomKind.league ||
        membership.roomId.isEmpty ||
        membership.weekStart != weekStart ||
        profile.history.any((week) => week.roomId == membership.roomId)) {
      return profile;
    }

    final transition = resolveLeagueTierTransition(
      previousTier: profile.currentTier,
      rank: rank,
      tied: tied,
      participantCount: participantCount,
      score: xp,
    );
    final week = LanSocialLeagueWeek(
      roomId: membership.roomId,
      weekStart: weekStart,
      xp: xp,
      rank: rank,
      participantCount: participantCount,
      previousTier: transition.previousTier,
      tier: transition.tier,
      movement: transition.movement,
      finalizedAt: finalizedAt.toUtc(),
    );
    final history = [
      week,
      ...profile.history,
    ].take(104).toList(growable: false);
    await _store.setSetting(
      _leagueProfileKey,
      jsonEncode({
        'version': 1,
        'currentTier': transition.tier.wire,
        'history': [for (final item in history) item.toJson()],
      }),
    );
    return LanSocialLeagueProfile(
      currentTier: transition.tier,
      history: List.unmodifiable(history),
    );
  });

  Future<_PendingJoin> _pendingJoin(LanSocialConnectionCode code) async {
    final inviteHash = sha256.convert(utf8.encode(code.inviteCode)).toString();
    final raw = await _store.getSetting(_pendingJoinKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final pending = _PendingJoin.fromJson(
            decoded.cast<String, Object?>(),
          );
          if (pending.baseUrl == endpoint.baseUrl &&
              pending.certificateSha256 == endpoint.certificateSha256 &&
              pending.kind == code.kind &&
              pending.inviteHash == inviteHash) {
            return pending;
          }
        }
      } on Object {
        // 条件が一致しない/壊れたpendingは次の新規値で置き換える。
      }
    }
    final pending = _PendingJoin(
      baseUrl: endpoint.baseUrl,
      certificateSha256: endpoint.certificateSha256,
      kind: code.kind,
      inviteHash: inviteHash,
      joinKey: _opaqueKeyFactory(),
      eventSalt: _opaqueKeyFactory(),
    );
    await _store.setSetting(_pendingJoinKey, jsonEncode(pending.toJson()));
    return pending;
  }

  Future<_PendingCreate> _pendingCreate({
    required LanSocialRoomKind kind,
    required int capacity,
  }) async {
    final raw = await _store.getSetting(_pendingCreateKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final pending = _PendingCreate.fromJson(
            decoded.cast<String, Object?>(),
          );
          if (pending.baseUrl == endpoint.baseUrl &&
              pending.certificateSha256 == endpoint.certificateSha256 &&
              pending.kind == kind &&
              pending.capacity == capacity) {
            return pending;
          }
        }
      } on Object {
        // 下で置き換える。
      }
    }
    final pending = _PendingCreate(
      baseUrl: endpoint.baseUrl,
      certificateSha256: endpoint.certificateSha256,
      kind: kind,
      capacity: capacity,
      createKey: _opaqueKeyFactory(),
    );
    await _store.setSetting(_pendingCreateKey, jsonEncode(pending.toJson()));
    return pending;
  }

  Future<List<LanSocialMembership>> _loadMemberships() async {
    return _readMemberships(_store);
  }

  Future<void> _saveMembership(LanSocialMembership membership) =>
      _serialize(() async {
        final existing = await _loadMemberships();
        final next = [
          ...existing.where((item) => item.kind != membership.kind),
          membership,
        ];
        await _writeMemberships(next);
      });

  Future<void> _removeMembership(LanSocialMembership membership) =>
      _serialize(() async {
        final existing = await _loadMemberships();
        await _writeMemberships(
          existing
              .where(
                (item) =>
                    item.kind != membership.kind ||
                    item.roomId != membership.roomId ||
                    item.credential != membership.credential,
              )
              .toList(growable: false),
        );
      });

  Future<void> _writeMemberships(List<LanSocialMembership> values) =>
      _store.setSetting(
        _membershipsKey,
        values.isEmpty
            ? null
            : jsonEncode({
                'version': 1,
                'memberships': [for (final value in values) value.toJson()],
              }),
      );

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _writeTail.then((_) => operation());
    _writeTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace stackTrace) {},
    );
    return result;
  }
}

Future<List<LanSocialMembership>> _readMemberships(SessionStore store) async {
  final raw = await store.getSetting(LanSocialClient._membershipsKey);
  if (raw == null || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw const FormatException();
    final json = decoded.cast<String, Object?>();
    _requireExactKeys(json, const {'version', 'memberships'});
    final values = json['memberships'];
    if (json['version'] != 1 || values is! List || values.length > 2) {
      throw const FormatException();
    }
    final memberships = <LanSocialMembership>[];
    for (final value in values) {
      if (value is! Map) throw const FormatException();
      memberships.add(
        LanSocialMembership.fromJson(value.cast<String, Object?>()),
      );
    }
    if (memberships.map((item) => item.kind).toSet().length !=
        memberships.length) {
      throw const FormatException();
    }
    return List.unmodifiable(memberships);
  } on Object {
    return const [];
  }
}

final class _PendingJoin {
  const _PendingJoin({
    required this.baseUrl,
    required this.certificateSha256,
    required this.kind,
    required this.inviteHash,
    required this.joinKey,
    required this.eventSalt,
  });

  final String baseUrl;
  final String certificateSha256;
  final LanSocialRoomKind kind;
  final String inviteHash;
  final String joinKey;
  final String eventSalt;

  Map<String, Object?> toJson() => {
    'version': 1,
    'baseUrl': baseUrl,
    'certificateSha256': certificateSha256,
    'kind': kind.wire,
    'inviteHash': inviteHash,
    'joinKey': joinKey,
    'eventSalt': eventSalt,
  };

  static _PendingJoin fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const {
      'version',
      'baseUrl',
      'certificateSha256',
      'kind',
      'inviteHash',
      'joinKey',
      'eventSalt',
    });
    final kind = LanSocialRoomKind.parse(json['kind']);
    final baseUrl = json['baseUrl'];
    final certificateSha256 = json['certificateSha256'];
    final inviteHash = json['inviteHash'];
    final joinKey = json['joinKey'];
    final eventSalt = json['eventSalt'];
    if (json['version'] != 1 ||
        json['baseUrl'] is! String ||
        json['certificateSha256'] is! String ||
        inviteHash is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(inviteHash) ||
        joinKey is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{32}$').hasMatch(joinKey) ||
        eventSalt is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{32}$').hasMatch(eventSalt) ||
        kind == null) {
      throw const FormatException();
    }
    validateLanSocialEndpoint(
      LanSocialEndpoint(
        baseUrl: baseUrl as String,
        certificateSha256: certificateSha256 as String,
      ),
    );
    return _PendingJoin(
      baseUrl: baseUrl,
      certificateSha256: certificateSha256,
      kind: kind,
      inviteHash: inviteHash,
      joinKey: joinKey,
      eventSalt: eventSalt,
    );
  }
}

final class _PendingCreate {
  const _PendingCreate({
    required this.baseUrl,
    required this.certificateSha256,
    required this.kind,
    required this.capacity,
    required this.createKey,
  });

  final String baseUrl;
  final String certificateSha256;
  final LanSocialRoomKind kind;
  final int capacity;
  final String createKey;

  Map<String, Object?> toJson() => {
    'version': 1,
    'baseUrl': baseUrl,
    'certificateSha256': certificateSha256,
    'kind': kind.wire,
    'capacity': capacity,
    'createKey': createKey,
  };

  static _PendingCreate fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const {
      'version',
      'baseUrl',
      'certificateSha256',
      'kind',
      'capacity',
      'createKey',
    });
    final kind = LanSocialRoomKind.parse(json['kind']);
    final baseUrl = json['baseUrl'];
    final certificateSha256 = json['certificateSha256'];
    final capacity = json['capacity'];
    final createKey = json['createKey'];
    if (json['version'] != 1 ||
        json['baseUrl'] is! String ||
        json['certificateSha256'] is! String ||
        capacity is! int ||
        createKey is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{32}$').hasMatch(createKey) ||
        (kind == LanSocialRoomKind.friends && capacity != 2) ||
        (kind == LanSocialRoomKind.league && (capacity < 5 || capacity > 8)) ||
        kind == null) {
      throw const FormatException();
    }
    validateLanSocialEndpoint(
      LanSocialEndpoint(
        baseUrl: baseUrl as String,
        certificateSha256: certificateSha256 as String,
      ),
    );
    return _PendingCreate(
      baseUrl: baseUrl,
      certificateSha256: certificateSha256,
      kind: kind,
      capacity: capacity,
      createKey: createKey,
    );
  }
}

LanSocialEndpoint validateLanSocialEndpoint(LanSocialEndpoint endpoint) {
  final uri = Uri.tryParse(endpoint.baseUrl);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.query.isNotEmpty ||
      uri.fragment.isNotEmpty ||
      (uri.path.isNotEmpty && uri.path != '/') ||
      !_isPrivateLiteral(uri.host) ||
      !RegExp(r'^[a-f0-9]{64}$').hasMatch(endpoint.certificateSha256)) {
    throw ArgumentError.value(
      endpoint.baseUrl,
      'endpoint',
      'private HTTPS IP and SHA-256 pin required',
    );
  }
  final normalizedHost = uri.host.contains(':') ? '[${uri.host}]' : uri.host;
  final normalized =
      'https://$normalizedHost${uri.hasPort ? ':${uri.port}' : ''}';
  return LanSocialEndpoint(
    baseUrl: normalized,
    certificateSha256: endpoint.certificateSha256,
  );
}

bool _isPrivateLiteral(String host) {
  final address = InternetAddress.tryParse(host);
  if (address == null) return false;
  final bytes = address.rawAddress;
  if (address.type == InternetAddressType.IPv4) {
    return bytes[0] == 10 ||
        bytes[0] == 127 ||
        (bytes[0] == 169 && bytes[1] == 254) ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
        (bytes[0] == 192 && bytes[1] == 168);
  }
  return address.isLoopback ||
      (bytes[0] & 0xfe) == 0xfc ||
      (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80);
}

Dio _pinnedDio(LanSocialEndpoint endpoint) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      followRedirects: false,
      maxRedirects: 0,
      validateStatus: (_) => true,
      responseType: ResponseType.json,
    ),
  );
  final expected = endpoint.certificateSha256;
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final context = SecurityContext(withTrustedRoots: false);
      final client = HttpClient(context: context);
      client.badCertificateCallback = (certificate, host, port) {
        final now = DateTime.now();
        if (certificate.startValidity.isAfter(now) ||
            !certificate.endValidity.isAfter(now)) {
          return false;
        }
        final actual = sha256.convert(certificate.der).toString();
        return _constantTimeTextEquals(actual, expected);
      };
      return client;
    },
  );
  return dio;
}

bool _constantTimeTextEquals(String left, String right) {
  if (left.length != right.length) return false;
  var difference = 0;
  for (var index = 0; index < left.length; index += 1) {
    difference |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
  }
  return difference == 0;
}

String _newOpaqueKey() {
  final random = Random.secure();
  final bytes = List<int>.generate(24, (_) => random.nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

String _eventKey(LanSocialMembership membership, String eventId) => base64Url
    .encode(
      sha256
          .convert(
            utf8.encode(
              '${membership.eventSalt}:${membership.roomId}:$eventId',
            ),
          )
          .bytes,
    )
    .replaceAll('=', '');

Map<String, Object?> _responseMap(Object? value) {
  if (value is! Map) throw const FormatException('object required');
  return value.cast<String, Object?>();
}

void _requireExactKeys(Map<String, Object?> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('unexpected LAN social fields');
  }
}

LanSocialClientError _errorFor(Response<Object?> response) {
  final data = response.data is Map
      ? (response.data as Map).cast<String, Object?>()
      : const <String, Object?>{};
  return switch (data['error']) {
    'unknown_room' => LanSocialClientError.roomNotFound,
    'expired' || 'join_revoked' => LanSocialClientError.roomExpired,
    'room_full' => LanSocialClientError.roomFull,
    'rate_limited' || 'daily_limit' => LanSocialClientError.rateLimited,
    'wrong_day' => LanSocialClientError.wrongDay,
    'unauthorized' => LanSocialClientError.unauthorized,
    _ =>
      response.statusCode == 401
          ? LanSocialClientError.unauthorized
          : LanSocialClientError.unavailable,
  };
}
