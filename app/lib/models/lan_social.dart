/// 外部クラウドを使わず、同一LAN上の実参加者だけで成立するsocial契約。
///
/// 氏名、回答、選択肢、音声、端末IDの受け皿を型に作らない。サーバが将来それらを
/// 誤って返しても、未知欄を含む応答はparseせずfail-closedにする。
library;

import 'dart:convert';

import 'league_ladder.dart';

export 'league_ladder.dart';

final class LanSocialEndpoint {
  const LanSocialEndpoint({
    required this.baseUrl,
    required this.certificateSha256,
  });

  final String baseUrl;
  final String certificateSha256;

  Map<String, Object?> toJson() => {
    'baseUrl': baseUrl,
    'certificateSha256': certificateSha256,
  };
}

/// QRまたは貼り付けで渡す参加コード。管理キーは構造上入れられない。
final class LanSocialConnectionCode {
  const LanSocialConnectionCode({
    required this.endpoint,
    required this.inviteCode,
    required this.kind,
  });

  static const prefix = 'DKS1.';

  final LanSocialEndpoint endpoint;
  final String inviteCode;
  final LanSocialRoomKind kind;

  String encode() {
    final payload = jsonEncode({
      'v': 1,
      'u': endpoint.baseUrl,
      'p': endpoint.certificateSha256,
      'i': inviteCode,
      'k': kind.wire,
    });
    return '$prefix${base64Url.encode(utf8.encode(payload)).replaceAll('=', '')}';
  }

  static LanSocialConnectionCode parse(String value) {
    final clean = value.trim();
    if (!clean.startsWith(prefix) || clean.length > 512) {
      throw const FormatException('invalid LAN social connection code');
    }
    try {
      final encoded = clean.substring(prefix.length);
      final padded = encoded.padRight(
        encoded.length + (4 - encoded.length % 4) % 4,
        '=',
      );
      final decoded = jsonDecode(utf8.decode(base64Url.decode(padded)));
      if (decoded is! Map) throw const FormatException();
      final json = decoded.cast<String, Object?>();
      _requireExactKeys(json, const {'v', 'u', 'p', 'i', 'k'});
      final baseUrl = json['u'];
      final pin = json['p'];
      final invite = json['i'];
      final kind = LanSocialRoomKind.parse(json['k']);
      if (json['v'] != 1 ||
          baseUrl is! String ||
          !baseUrl.startsWith('https://') ||
          pin is! String ||
          !_certificateSha256.hasMatch(pin) ||
          invite is! String ||
          !_inviteCode.hasMatch(invite) ||
          kind == null) {
        throw const FormatException('invalid LAN social connection code');
      }
      return LanSocialConnectionCode(
        endpoint: LanSocialEndpoint(baseUrl: baseUrl, certificateSha256: pin),
        inviteCode: invite,
        kind: kind,
      );
    } on FormatException {
      rethrow;
    } on Object {
      throw const FormatException('invalid LAN social connection code');
    }
  }
}

enum LanSocialRoomKind {
  friends,
  league;

  String get wire => name;

  static LanSocialRoomKind? parse(Object? value) => switch (value) {
    'friends' => LanSocialRoomKind.friends,
    'league' => LanSocialRoomKind.league,
    _ => null,
  };
}

final class LanSocialCreatedRoom {
  const LanSocialCreatedRoom({
    required this.roomId,
    required this.kind,
    required this.inviteCode,
    required this.capacity,
    required this.expiresAt,
    required this.weekStart,
  });

  final String roomId;
  final LanSocialRoomKind kind;
  final String inviteCode;
  final int capacity;
  final DateTime expiresAt;
  final String? weekStart;

  static LanSocialCreatedRoom fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const {
      'protocolVersion',
      'roomId',
      'kind',
      'inviteCode',
      'capacity',
      'expiresAt',
      'weekStart',
    });
    final kind = LanSocialRoomKind.parse(json['kind']);
    final roomId = json['roomId'];
    final inviteCode = json['inviteCode'];
    final capacity = json['capacity'];
    final expiresAt = DateTime.tryParse(json['expiresAt'] as String? ?? '');
    final weekStart = json['weekStart'];
    if (json['protocolVersion'] != 1 ||
        kind == null ||
        roomId is! String ||
        !_roomId.hasMatch(roomId) ||
        inviteCode is! String ||
        !_inviteCode.hasMatch(inviteCode) ||
        capacity is! int ||
        (kind == LanSocialRoomKind.friends && capacity != 2) ||
        (kind == LanSocialRoomKind.league && (capacity < 5 || capacity > 8)) ||
        expiresAt == null ||
        expiresAt.isBefore(DateTime.fromMillisecondsSinceEpoch(0)) ||
        !(weekStart == null ||
            (weekStart is String && _dayKey.hasMatch(weekStart))) ||
        (kind == LanSocialRoomKind.league) != (weekStart is String)) {
      throw const FormatException('invalid LAN social room');
    }
    return LanSocialCreatedRoom(
      roomId: roomId,
      kind: kind,
      inviteCode: inviteCode,
      capacity: capacity,
      expiresAt: expiresAt.toUtc(),
      weekStart: weekStart as String?,
    );
  }
}

final class LanSocialMembership {
  const LanSocialMembership({
    required this.baseUrl,
    required this.certificateSha256,
    required this.roomId,
    required this.kind,
    required this.credential,
    required this.eventSalt,
    required this.expiresAt,
    required this.weekStart,
  });

  final String baseUrl;
  final String certificateSha256;
  final String roomId;
  final LanSocialRoomKind kind;
  final String credential;

  /// ローカルevent IDをroom固有のidempotency keyへ変換するための端末内乱数。
  final String eventSalt;
  final DateTime expiresAt;
  final String? weekStart;

  Map<String, Object?> toJson() => {
    'baseUrl': baseUrl,
    'certificateSha256': certificateSha256,
    'roomId': roomId,
    'kind': kind.wire,
    'credential': credential,
    'eventSalt': eventSalt,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'weekStart': weekStart,
  };

  static LanSocialMembership fromServerJson(
    Map<String, Object?> json, {
    required String baseUrl,
    required String certificateSha256,
    required String eventSalt,
  }) {
    _requireExactKeys(json, const {
      'protocolVersion',
      'roomId',
      'kind',
      'credential',
      'expiresAt',
      'weekStart',
    });
    return _parse(
      baseUrl: baseUrl,
      certificateSha256: certificateSha256,
      roomId: json['roomId'],
      kind: json['kind'],
      credential: json['credential'],
      eventSalt: eventSalt,
      expiresAt: json['expiresAt'],
      weekStart: json['weekStart'],
      protocolVersion: json['protocolVersion'],
    );
  }

  static LanSocialMembership fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const {
      'baseUrl',
      'certificateSha256',
      'roomId',
      'kind',
      'credential',
      'eventSalt',
      'expiresAt',
      'weekStart',
    });
    return _parse(
      baseUrl: json['baseUrl'],
      certificateSha256: json['certificateSha256'],
      roomId: json['roomId'],
      kind: json['kind'],
      credential: json['credential'],
      eventSalt: json['eventSalt'],
      expiresAt: json['expiresAt'],
      weekStart: json['weekStart'],
      protocolVersion: 1,
    );
  }

  static LanSocialMembership _parse({
    required Object? baseUrl,
    required Object? certificateSha256,
    required Object? roomId,
    required Object? kind,
    required Object? credential,
    required Object? eventSalt,
    required Object? expiresAt,
    required Object? weekStart,
    required Object? protocolVersion,
  }) {
    final parsedKind = LanSocialRoomKind.parse(kind);
    final parsedExpiresAt = DateTime.tryParse(expiresAt as String? ?? '');
    if (protocolVersion != 1 ||
        baseUrl is! String ||
        baseUrl.isEmpty ||
        certificateSha256 is! String ||
        !_certificateSha256.hasMatch(certificateSha256) ||
        roomId is! String ||
        !_roomId.hasMatch(roomId) ||
        parsedKind == null ||
        credential is! String ||
        !_credential.hasMatch(credential) ||
        !credential.startsWith('$roomId.') ||
        eventSalt is! String ||
        !_opaqueKey.hasMatch(eventSalt) ||
        parsedExpiresAt == null ||
        !(weekStart == null ||
            (weekStart is String && _dayKey.hasMatch(weekStart))) ||
        (parsedKind == LanSocialRoomKind.league) != (weekStart is String)) {
      throw const FormatException('invalid LAN social membership');
    }
    return LanSocialMembership(
      baseUrl: baseUrl,
      certificateSha256: certificateSha256,
      roomId: roomId,
      kind: parsedKind,
      credential: credential,
      eventSalt: eventSalt,
      expiresAt: parsedExpiresAt.toUtc(),
      weekStart: weekStart as String?,
    );
  }
}

/// Room本体が削除されたあとも、発行済みcredentialで回収できる最小の確定結果。
///
/// 回答、音声、端末ID、participant IDを受ける欄を持たない。未知欄を含む応答は
/// fail-closedにし、保存済みmembershipとroom/kind/weekが一致した場合だけclientが
/// 端末台帳へ反映する。
sealed class LanSocialTerminalReceipt {
  const LanSocialTerminalReceipt({
    required this.roomId,
    required this.kind,
    required this.settledAt,
  });

  final String roomId;
  final LanSocialRoomKind kind;
  final DateTime settledAt;

  static LanSocialTerminalReceipt fromJson(Map<String, Object?> json) {
    return switch (LanSocialRoomKind.parse(json['kind'])) {
      LanSocialRoomKind.friends => LanSocialFriendsTerminalReceipt.fromJson(
        json,
      ),
      LanSocialRoomKind.league => LanSocialLeagueTerminalReceipt.fromJson(json),
      null => throw const FormatException(
        'invalid LAN social terminal receipt kind',
      ),
    };
  }
}

final class LanSocialFriendsTerminalReceipt extends LanSocialTerminalReceipt {
  const LanSocialFriendsTerminalReceipt({
    required super.roomId,
    required this.completed,
    required super.settledAt,
  }) : super(kind: LanSocialRoomKind.friends);

  final bool completed;

  static LanSocialFriendsTerminalReceipt fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const {
      'protocolVersion',
      'roomId',
      'kind',
      'completed',
      'settledAt',
    });
    final roomId = json['roomId'];
    final completed = json['completed'];
    final settledAt = DateTime.tryParse(json['settledAt'] as String? ?? '');
    if (json['protocolVersion'] != 1 ||
        json['kind'] != 'friends' ||
        roomId is! String ||
        !_roomId.hasMatch(roomId) ||
        completed is! bool ||
        settledAt == null ||
        settledAt.isBefore(DateTime.fromMillisecondsSinceEpoch(0))) {
      throw const FormatException('invalid friends terminal receipt');
    }
    return LanSocialFriendsTerminalReceipt(
      roomId: roomId,
      completed: completed,
      settledAt: settledAt.toUtc(),
    );
  }
}

final class LanSocialLeagueTerminalReceipt extends LanSocialTerminalReceipt {
  const LanSocialLeagueTerminalReceipt({
    required super.roomId,
    required this.weekStart,
    required this.privacyThresholdReached,
    required this.xp,
    required this.rank,
    required this.tied,
    required this.participantCount,
    required super.settledAt,
  }) : super(kind: LanSocialRoomKind.league);

  final String weekStart;
  final bool privacyThresholdReached;
  final int xp;
  final int? rank;
  final bool tied;
  final int? participantCount;

  static LanSocialLeagueTerminalReceipt fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const {
      'protocolVersion',
      'roomId',
      'kind',
      'weekStart',
      'participantBand',
      'xp',
      'rank',
      'tied',
      'participantCount',
      'settledAt',
    });
    final roomId = json['roomId'];
    final weekStart = json['weekStart'];
    final participantBand = json['participantBand'];
    final xp = json['xp'];
    final rank = json['rank'];
    final tied = json['tied'];
    final participantCount = json['participantCount'];
    final settledAt = DateTime.tryParse(json['settledAt'] as String? ?? '');
    if (json['protocolVersion'] != 1 ||
        json['kind'] != 'league' ||
        roomId is! String ||
        !_roomId.hasMatch(roomId) ||
        weekStart is! String ||
        !_dayKey.hasMatch(weekStart) ||
        (participantBand != 'under5' && participantBand != '5-8') ||
        xp is! int ||
        xp < 0 ||
        xp % 10 != 0 ||
        !(rank == null || (rank is int && rank >= 1 && rank <= 8)) ||
        tied is! bool ||
        !(participantCount == null ||
            (participantCount is int &&
                participantCount >= 5 &&
                participantCount <= 8)) ||
        settledAt == null ||
        settledAt.isBefore(DateTime.fromMillisecondsSinceEpoch(0))) {
      throw const FormatException('invalid league terminal receipt');
    }
    final thresholdReached = participantBand == '5-8';
    if ((!thresholdReached &&
            (xp != 0 || rank != null || tied || participantCount != null)) ||
        (thresholdReached &&
            (participantCount == null ||
                (rank != null && (rank as int) > (participantCount as int))))) {
      throw const FormatException('invalid league terminal privacy result');
    }
    return LanSocialLeagueTerminalReceipt(
      roomId: roomId,
      weekStart: weekStart,
      privacyThresholdReached: thresholdReached,
      xp: xp,
      rank: rank as int?,
      tied: tied,
      participantCount: participantCount as int?,
      settledAt: settledAt.toUtc(),
    );
  }
}

sealed class LanSocialSnapshot {
  const LanSocialSnapshot({required this.kind, required this.expiresAt});

  final LanSocialRoomKind kind;
  final DateTime expiresAt;

  bool get expired;

  static LanSocialSnapshot fromJson(Map<String, Object?> json) {
    return switch (LanSocialRoomKind.parse(json['kind'])) {
      LanSocialRoomKind.friends => LanSocialFriendsSnapshot.fromJson(json),
      LanSocialRoomKind.league => LanSocialLeagueSnapshot.fromJson(json),
      null => throw const FormatException('invalid LAN social snapshot kind'),
    };
  }
}

enum LanSocialFriendsState {
  waitingForPartner,
  active,
  completed,
  expired;

  static LanSocialFriendsState? parse(Object? value) => switch (value) {
    'waiting_for_partner' => LanSocialFriendsState.waitingForPartner,
    'active' => LanSocialFriendsState.active,
    'completed' => LanSocialFriendsState.completed,
    'expired' => LanSocialFriendsState.expired,
    _ => null,
  };
}

final class LanSocialFriendsSnapshot extends LanSocialSnapshot {
  const LanSocialFriendsSnapshot({
    required this.state,
    required this.partnerJoined,
    required this.myContributed,
    required this.completed,
    required super.expiresAt,
  }) : super(kind: LanSocialRoomKind.friends);

  final LanSocialFriendsState state;

  /// 2人部屋なのでone/two以上の人数情報を保持しない。
  final bool partnerJoined;
  final bool myContributed;
  final bool completed;

  @override
  bool get expired => state == LanSocialFriendsState.expired;

  static LanSocialFriendsSnapshot fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const {
      'protocolVersion',
      'kind',
      'state',
      'participantBand',
      'myContributed',
      'completed',
      'expiresAt',
    });
    final state = LanSocialFriendsState.parse(json['state']);
    final participantBand = json['participantBand'];
    final expiresAt = DateTime.tryParse(json['expiresAt'] as String? ?? '');
    if (json['protocolVersion'] != 1 ||
        json['kind'] != 'friends' ||
        state == null ||
        (participantBand != 'one' && participantBand != 'two') ||
        json['myContributed'] is! bool ||
        json['completed'] is! bool ||
        expiresAt == null ||
        (state == LanSocialFriendsState.waitingForPartner &&
            (participantBand != 'one' || json['completed'] == true)) ||
        (state == LanSocialFriendsState.active &&
            (participantBand != 'two' || json['completed'] == true)) ||
        (state == LanSocialFriendsState.completed &&
            (participantBand != 'two' || json['completed'] != true)) ||
        (json['completed'] == true && participantBand != 'two')) {
      throw const FormatException('invalid friends snapshot');
    }
    return LanSocialFriendsSnapshot(
      state: state,
      partnerJoined: participantBand == 'two',
      myContributed: json['myContributed'] as bool,
      completed: json['completed'] as bool,
      expiresAt: expiresAt.toUtc(),
    );
  }
}

enum LanSocialLeagueState {
  waitingForPrivacyThreshold,
  active,
  expired;

  static LanSocialLeagueState? parse(Object? value) => switch (value) {
    'waiting_for_privacy_threshold' =>
      LanSocialLeagueState.waitingForPrivacyThreshold,
    'active' => LanSocialLeagueState.active,
    'expired' => LanSocialLeagueState.expired,
    _ => null,
  };
}

final class LanSocialLeagueStanding {
  const LanSocialLeagueStanding({
    required this.rank,
    required this.xp,
    required this.isMe,
    required this.tied,
  });

  final int? rank;
  final int xp;
  final bool isMe;
  final bool tied;

  static LanSocialLeagueStanding fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const {'rank', 'xp', 'isMe', 'tied'});
    final rank = json['rank'];
    final xp = json['xp'];
    if (!(rank == null || (rank is int && rank >= 1 && rank <= 8)) ||
        xp is! int ||
        xp < 0 ||
        xp > 100000 ||
        xp % 10 != 0 ||
        json['isMe'] is! bool ||
        json['tied'] is! bool) {
      throw const FormatException('invalid league standing');
    }
    return LanSocialLeagueStanding(
      rank: rank as int?,
      xp: xp,
      isMe: json['isMe'] as bool,
      tied: json['tied'] as bool,
    );
  }
}

final class LanSocialLeagueSnapshot extends LanSocialSnapshot {
  const LanSocialLeagueSnapshot({
    required this.state,
    required this.privacyThresholdReached,
    required this.standings,
    required this.myXp,
    required this.weekStart,
    required this.weekEnd,
    required super.expiresAt,
  }) : super(kind: LanSocialRoomKind.league);

  final LanSocialLeagueState state;
  final bool privacyThresholdReached;
  final List<LanSocialLeagueStanding> standings;
  final int myXp;
  final String weekStart;
  final String weekEnd;

  @override
  bool get expired => state == LanSocialLeagueState.expired;

  LanSocialLeagueStanding? get mine =>
      standings.where((standing) => standing.isMe).firstOrNull;

  static LanSocialLeagueSnapshot fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const {
      'protocolVersion',
      'kind',
      'state',
      'participantBand',
      'standings',
      'myXp',
      'weekStart',
      'weekEnd',
      'expiresAt',
    });
    final state = LanSocialLeagueState.parse(json['state']);
    final band = json['participantBand'];
    final rawStandings = json['standings'];
    final myXp = json['myXp'];
    final weekStart = json['weekStart'];
    final weekEnd = json['weekEnd'];
    final expiresAt = DateTime.tryParse(json['expiresAt'] as String? ?? '');
    if (json['protocolVersion'] != 1 ||
        json['kind'] != 'league' ||
        state == null ||
        (band != 'under5' && band != '5-8') ||
        rawStandings is! List ||
        myXp is! int ||
        myXp < 0 ||
        myXp % 10 != 0 ||
        weekStart is! String ||
        !_dayKey.hasMatch(weekStart) ||
        weekEnd is! String ||
        !_dayKey.hasMatch(weekEnd) ||
        expiresAt == null) {
      throw const FormatException('invalid league snapshot');
    }
    final standings = <LanSocialLeagueStanding>[];
    for (final raw in rawStandings) {
      if (raw is! Map) throw const FormatException('invalid league standings');
      standings.add(
        LanSocialLeagueStanding.fromJson(raw.cast<String, Object?>()),
      );
    }
    final thresholdReached = band == '5-8';
    if ((!thresholdReached && standings.isNotEmpty) ||
        (state == LanSocialLeagueState.waitingForPrivacyThreshold &&
            thresholdReached) ||
        (state == LanSocialLeagueState.active && !thresholdReached) ||
        (thresholdReached &&
            (standings.length < 5 ||
                standings.length > 8 ||
                standings.where((standing) => standing.isMe).length != 1 ||
                standings.singleWhere((standing) => standing.isMe).xp !=
                    myXp)) ||
        !_validStandingOrder(standings)) {
      throw const FormatException('league privacy threshold mismatch');
    }
    return LanSocialLeagueSnapshot(
      state: state,
      privacyThresholdReached: thresholdReached,
      standings: List.unmodifiable(standings),
      myXp: myXp,
      weekStart: weekStart,
      weekEnd: weekEnd,
      expiresAt: expiresAt.toUtc(),
    );
  }
}

final class LanSocialLeagueWeek {
  const LanSocialLeagueWeek({
    required this.roomId,
    required this.weekStart,
    required this.xp,
    required this.rank,
    required this.participantCount,
    required this.previousTier,
    required this.tier,
    required this.movement,
    required this.finalizedAt,
  });

  final String roomId;
  final String weekStart;
  final int xp;
  final int? rank;
  final int participantCount;
  final LanSocialLeagueTier previousTier;
  final LanSocialLeagueTier tier;
  final LanSocialLeagueMovement movement;
  final DateTime finalizedAt;

  Map<String, Object?> toJson() => {
    'roomId': roomId,
    'weekStart': weekStart,
    'xp': xp,
    'rank': rank,
    'participantCount': participantCount,
    'previousTier': previousTier.wire,
    'tier': tier.wire,
    'movement': movement.wire,
    'finalizedAt': finalizedAt.toUtc().toIso8601String(),
  };

  static LanSocialLeagueWeek fromJson(Map<String, Object?> json) {
    _requireExactKeys(json, const {
      'roomId',
      'weekStart',
      'xp',
      'rank',
      'participantCount',
      'previousTier',
      'tier',
      'movement',
      'finalizedAt',
    });
    final previousTier = LanSocialLeagueTier.parse(json['previousTier']);
    final tier = LanSocialLeagueTier.parse(json['tier']);
    final movement = LanSocialLeagueMovement.parse(json['movement']);
    final finalizedAt = DateTime.tryParse(json['finalizedAt'] as String? ?? '');
    final rank = json['rank'];
    if (json['roomId'] is! String ||
        !_roomId.hasMatch(json['roomId'] as String) ||
        json['weekStart'] is! String ||
        !_dayKey.hasMatch(json['weekStart'] as String) ||
        json['xp'] is! int ||
        (json['xp'] as int) < 0 ||
        !(rank == null || (rank is int && rank >= 1 && rank <= 8)) ||
        json['participantCount'] is! int ||
        (json['participantCount'] as int) < 5 ||
        (json['participantCount'] as int) > 8 ||
        previousTier == null ||
        tier == null ||
        movement == null ||
        finalizedAt == null ||
        !isValidLeagueTierTransition(
          previousTier: previousTier,
          tier: tier,
          movement: movement,
        )) {
      throw const FormatException('invalid league history');
    }
    return LanSocialLeagueWeek(
      roomId: json['roomId'] as String,
      weekStart: json['weekStart'] as String,
      xp: json['xp'] as int,
      rank: rank as int?,
      participantCount: json['participantCount'] as int,
      previousTier: previousTier,
      tier: tier,
      movement: movement,
      finalizedAt: finalizedAt.toUtc(),
    );
  }
}

final class LanSocialLeagueProfile {
  const LanSocialLeagueProfile({
    required this.currentTier,
    required this.history,
  });

  const LanSocialLeagueProfile.initial()
    : currentTier = LanSocialLeagueTier.bronze,
      history = const [];

  final LanSocialLeagueTier currentTier;
  final List<LanSocialLeagueWeek> history;
}

final RegExp _roomId = RegExp(r'^[a-f0-9]{24}$');
final RegExp _certificateSha256 = RegExp(r'^[a-f0-9]{64}$');
final RegExp _credential = RegExp(
  r'^[a-f0-9]{24}\.[a-f0-9]{24}\.[A-Za-z0-9_-]{43}$',
);
final RegExp _opaqueKey = RegExp(r'^[A-Za-z0-9_-]{32}$');
final RegExp _inviteCode = RegExp(
  r'^[23456789ABCDEFGHJKMNPQRSTVWXYZ]{4}-'
  r'[23456789ABCDEFGHJKMNPQRSTVWXYZ]{4}-'
  r'[23456789ABCDEFGHJKMNPQRSTVWXYZ]{4}$',
);
final RegExp _dayKey = RegExp(r'^\d{4}-\d{2}-\d{2}$');

bool _validStandingOrder(List<LanSocialLeagueStanding> standings) {
  if (standings.isEmpty) return true;
  final anyScore = standings.any((standing) => standing.xp > 0);
  var previousXp = 100001;
  int? previousRank;
  for (var index = 0; index < standings.length; index += 1) {
    final standing = standings[index];
    if (standing.xp > previousXp) return false;
    final sameScore = index > 0 && standing.xp == previousXp;
    final expectedRank = !anyScore
        ? null
        : sameScore
        ? previousRank
        : index + 1;
    final frequency = standings
        .where((candidate) => candidate.xp == standing.xp)
        .length;
    if (standing.rank != expectedRank ||
        standing.tied != (anyScore && frequency > 1)) {
      return false;
    }
    previousXp = standing.xp;
    previousRank = standing.rank;
  }
  return true;
}

void _requireExactKeys(Map<String, Object?> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('unexpected LAN social fields');
  }
}
