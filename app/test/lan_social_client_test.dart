import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dekisugi/learning/domain/learning_event.dart';
import 'package:dekisugi/learning/domain/learning_progress.dart';
import 'package:dekisugi/models/lan_social.dart';
import 'package:dekisugi/services/lan_social_client.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/stub_dio.dart';

const baseUrl = 'https://192.168.1.20:8787';
const pin = '1111111111111111111111111111111111111111111111111111111111111111';
const roomId = 'aaaaaaaaaaaaaaaaaaaaaaaa';
const participantId = 'bbbbbbbbbbbbbbbbbbbbbbbb';
const credential =
    '$roomId.$participantId.CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC';
const invite = '2345-6789-ABCD';
const endpoint = LanSocialEndpoint(baseUrl: baseUrl, certificateSha256: pin);

LanSocialConnectionCode code([
  LanSocialRoomKind kind = LanSocialRoomKind.friends,
]) =>
    LanSocialConnectionCode(endpoint: endpoint, inviteCode: invite, kind: kind);

String membershipJson({
  LanSocialRoomKind kind = LanSocialRoomKind.friends,
  String? extra,
}) =>
    '{'
    '"protocolVersion":1,'
    '"roomId":"$roomId",'
    '"kind":"${kind.wire}",'
    '"credential":"$credential",'
    '"expiresAt":"2026-08-17T00:00:00.000Z",'
    '"weekStart":${kind == LanSocialRoomKind.league ? '"2026-08-10"' : 'null'}'
    '${extra ?? ''}'
    '}';

const friendsSnapshotJson =
    '{'
    '"protocolVersion":1,'
    '"kind":"friends",'
    '"state":"active",'
    '"participantBand":"two",'
    '"myContributed":true,'
    '"completed":false,'
    '"expiresAt":"2026-08-17T00:00:00.000Z"'
    '}';

const completedFriendsSnapshotJson =
    '{'
    '"protocolVersion":1,'
    '"kind":"friends",'
    '"state":"completed",'
    '"participantBand":"two",'
    '"myContributed":true,'
    '"completed":true,'
    '"expiresAt":"2026-08-17T00:00:00.000Z"'
    '}';

const privateLeagueSnapshotJson =
    '{'
    '"protocolVersion":1,'
    '"kind":"league",'
    '"state":"waiting_for_privacy_threshold",'
    '"participantBand":"under5",'
    '"standings":[],'
    '"myXp":10,'
    '"weekStart":"2026-08-10",'
    '"weekEnd":"2026-08-16",'
    '"expiresAt":"2026-08-17T00:00:00.000Z"'
    '}';

String friendsTerminalReceiptJson({
  String receiptRoomId = roomId,
  bool completed = true,
  String? extra,
}) =>
    '{'
    '"protocolVersion":1,'
    '"roomId":"$receiptRoomId",'
    '"kind":"friends",'
    '"completed":$completed,'
    '"settledAt":"2026-08-17T00:00:00.000Z"'
    '${extra ?? ''}'
    '}';

String leagueTerminalReceiptJson({
  String receiptRoomId = roomId,
  String weekStart = '2026-08-10',
  bool privacyThresholdReached = true,
  int xp = 30,
  int? rank = 1,
  bool tied = false,
  int? participantCount = 5,
  String? extra,
}) {
  final value = <String, Object?>{
    'protocolVersion': 1,
    'roomId': receiptRoomId,
    'kind': 'league',
    'weekStart': weekStart,
    'participantBand': privacyThresholdReached ? '5-8' : 'under5',
    'xp': privacyThresholdReached ? xp : 0,
    'rank': privacyThresholdReached ? rank : null,
    'tied': privacyThresholdReached ? tied : false,
    'participantCount': privacyThresholdReached ? participantCount : null,
    'settledAt': '2026-08-17T00:00:00.000Z',
  };
  if (extra case final String key) value[key] = 'forbidden';
  return jsonEncode(value);
}

LanSocialMembership terminalMembership(LanSocialRoomKind kind) =>
    LanSocialMembership(
      baseUrl: baseUrl,
      certificateSha256: pin,
      roomId: roomId,
      kind: kind,
      credential: credential,
      eventSalt: 'Z' * 32,
      expiresAt: DateTime.utc(2026, 8, 17),
      weekStart: kind == LanSocialRoomKind.league ? '2026-08-10' : null,
    );

Future<void> saveTerminalMembership(
  SessionStore store,
  LanSocialRoomKind kind,
) => store.setSetting(
  'lan_social.memberships.v1',
  jsonEncode({
    'version': 1,
    'memberships': [terminalMembership(kind).toJson()],
  }),
);

LearningEventRecord event({
  String eventId = 'event-1',
  LearningScope scope = LearningScope.personal,
  bool meaningful = true,
}) => LearningEventRecord(
  eventId: eventId,
  scope: scope,
  origin: scope == LearningScope.schoolLocal
      ? LearningOrigin.schoolAssignment
      : LearningOrigin.path,
  courseId: 'science-jhs-v1',
  nodeId: 'fall-lesson',
  activityId: 'fall-checkpoint',
  activityKind: LearningActivityKind.checkpoint,
  outcome: LearningAttemptOutcome.structuredSuccess,
  evidence: LearningEvidenceLevel.structuredCorrection,
  contentVersion: 'v1',
  learningDay: '2026-08-10',
  occurredAt: DateTime.utc(2026, 8, 10, 3),
  runId: null,
  sourceSessionId: null,
  rewardEligible: true,
  meaningfulProgress: meaningful,
);

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('参加コードとendpoint境界', () {
    test('endpoint・certificate pin・invite・kindだけをround-tripする', () {
      final encoded = code(LanSocialRoomKind.league).encode();
      final decoded = LanSocialConnectionCode.parse(encoded);
      expect(decoded.endpoint.baseUrl, baseUrl);
      expect(decoded.endpoint.certificateSha256, pin);
      expect(decoded.inviteCode, invite);
      expect(decoded.kind, LanSocialRoomKind.league);

      final payload = utf8.decode(
        base64Url.decode(
          encoded
              .substring(LanSocialConnectionCode.prefix.length)
              .padRight(
                encoded.length -
                    LanSocialConnectionCode.prefix.length +
                    (4 -
                            (encoded.length -
                                    LanSocialConnectionCode.prefix.length) %
                                4) %
                        4,
                '=',
              ),
        ),
      );
      for (final forbidden in [
        'admin',
        'coordinatorKey',
        'deviceId',
        'name',
        'answer',
        'audio',
      ]) {
        expect(payload.contains(forbidden), isFalse);
      }
    });

    test('HTTP・public IP・DNS名・pinなしを拒否する', () {
      for (final candidate in [
        const LanSocialEndpoint(
          baseUrl: 'http://192.168.1.2:8787',
          certificateSha256: pin,
        ),
        const LanSocialEndpoint(
          baseUrl: 'https://203.0.113.8:8787',
          certificateSha256: pin,
        ),
        const LanSocialEndpoint(
          baseUrl: 'https://example.test:8787',
          certificateSha256: pin,
        ),
        const LanSocialEndpoint(baseUrl: baseUrl, certificateSha256: 'short'),
      ]) {
        expect(() => validateLanSocialEndpoint(candidate), throwsArgumentError);
      }
      expect(validateLanSocialEndpoint(endpoint).baseUrl, baseUrl);
      expect(
        validateLanSocialEndpoint(
          const LanSocialEndpoint(
            baseUrl: 'https://[::1]:8787',
            certificateSha256: pin,
          ),
        ).baseUrl,
        'https://[::1]:8787',
      );
    });

    test('応答へ個人欄が増えたら無視せずparseを拒否する', () {
      final json =
          jsonDecode(
                friendsSnapshotJson.replaceFirst(
                  '"expiresAt"',
                  '"studentName":"山田","expiresAt"',
                ),
              )
              as Map;
      expect(
        () => LanSocialSnapshot.fromJson(json.cast<String, Object?>()),
        throwsFormatException,
      );
    });

    test('terminal receiptは最小欄だけを厳密にparseする', () {
      final friends = LanSocialTerminalReceipt.fromJson(
        (jsonDecode(friendsTerminalReceiptJson()) as Map)
            .cast<String, Object?>(),
      );
      expect(friends, isA<LanSocialFriendsTerminalReceipt>());
      expect((friends as LanSocialFriendsTerminalReceipt).completed, isTrue);

      final league = LanSocialTerminalReceipt.fromJson(
        (jsonDecode(leagueTerminalReceiptJson()) as Map)
            .cast<String, Object?>(),
      );
      expect(league, isA<LanSocialLeagueTerminalReceipt>());
      final result = league as LanSocialLeagueTerminalReceipt;
      expect(result.privacyThresholdReached, isTrue);
      expect(result.rank, 1);
      expect(result.participantCount, 5);

      final private = LanSocialTerminalReceipt.fromJson(
        (jsonDecode(leagueTerminalReceiptJson(privacyThresholdReached: false))
                as Map)
            .cast<String, Object?>(),
      );
      expect(
        (private as LanSocialLeagueTerminalReceipt).participantCount,
        isNull,
      );
    });

    test('terminal receiptの個人欄・矛盾・実人数越えを拒否する', () {
      for (final raw in [
        friendsTerminalReceiptJson(extra: ',"studentName":"山田"'),
        leagueTerminalReceiptJson(extra: 'audio'),
        leagueTerminalReceiptJson(rank: 6, participantCount: 5),
        jsonEncode({
          'protocolVersion': 1,
          'roomId': roomId,
          'kind': 'league',
          'weekStart': '2026-08-10',
          'participantBand': 'under5',
          'xp': 10,
          'rank': 1,
          'tied': false,
          'participantCount': 5,
          'settledAt': '2026-08-17T00:00:00.000Z',
        }),
      ]) {
        final decoded = (jsonDecode(raw) as Map).cast<String, Object?>();
        expect(
          () => LanSocialTerminalReceipt.fromJson(decoded),
          throwsFormatException,
          reason: raw,
        );
      }
    });

    test('expired時の共同達成は保持し、矛盾したtier履歴は拒否する', () {
      final expiredCompleted = jsonDecode(
        friendsSnapshotJson
            .replaceFirst('"state":"active"', '"state":"expired"')
            .replaceFirst('"completed":false', '"completed":true'),
      );
      final parsed = LanSocialSnapshot.fromJson(
        (expiredCompleted as Map).cast<String, Object?>(),
      );
      expect((parsed as LanSocialFriendsSnapshot).completed, isTrue);

      final history = <String, Object?>{
        'roomId': roomId,
        'weekStart': '2026-08-03',
        'xp': 30,
        'rank': 1,
        'participantCount': 5,
        'previousTier': 'bronze',
        'tier': 'gold',
        'movement': 'promoted',
        'finalizedAt': '2026-08-10T00:00:00.000Z',
      };
      expect(
        () => LanSocialLeagueWeek.fromJson(history),
        throwsFormatException,
      );
    });
  });

  group('参加と再送', () {
    test('明示opt-inなしでは通信も保存もしない', () async {
      final store = MemorySessionStore();
      var requests = 0;
      final client = LanSocialClient(
        endpoint: endpoint,
        store: store,
        dio: fakeDio({}, onRequest: (_) => requests += 1),
      );
      final result = await client.join(code(), explicitOptIn: false);
      expect(result.error, LanSocialClientError.optInRequired);
      expect(requests, 0);
      expect(await client.saved(LanSocialRoomKind.friends), isNull);
    });

    test('joinは端末IDを送らずroom固有乱数だけを保存する', () async {
      final store = MemorySessionStore();
      Object? body;
      final keys = ['D' * 32, 'E' * 32].iterator;
      String nextKey() {
        keys.moveNext();
        return keys.current;
      }

      final client = LanSocialClient(
        endpoint: endpoint,
        store: store,
        opaqueKeyFactory: nextKey,
        dio: fakeDio({
          'POST $baseUrl/v1/lan-social/join': () =>
              jsonRes(200, membershipJson()),
        }, onRequest: (request) => body = request.data),
      );
      final result = await client.join(code(), explicitOptIn: true);
      expect(result.joined, isTrue);
      expect((body as Map).keys.toSet(), {
        'inviteCode',
        'joinKey',
        'optIn',
        'consentVersion',
      });
      expect((body as Map)['joinKey'], 'D' * 32);
      final sent = jsonEncode(body);
      for (final forbidden in ['deviceId', 'studentName', 'answer', 'audio']) {
        expect(sent.contains(forbidden), isFalse);
      }
      final saved = await client.saved(LanSocialRoomKind.friends);
      expect(saved?.eventSalt, 'E' * 32);
      expect(saved?.certificateSha256, pin);
    });

    test('応答を失って再起動しても同じjoin keyを再送する', () async {
      final store = MemorySessionStore();
      final sent = <Object?>[];
      final first = LanSocialClient(
        endpoint: endpoint,
        store: store,
        opaqueKeyFactory: () => 'F' * 32,
        dio: fakeDio({
          'POST $baseUrl/v1/lan-social/join': () => jsonRes(503, '{}'),
        }, onRequest: (request) => sent.add(request.data)),
      );
      expect((await first.join(code(), explicitOptIn: true)).joined, isFalse);
      var generatedAfterRestart = false;
      final second = LanSocialClient(
        endpoint: endpoint,
        store: store,
        opaqueKeyFactory: () {
          generatedAfterRestart = true;
          return 'G' * 32;
        },
        dio: fakeDio({
          'POST $baseUrl/v1/lan-social/join': () =>
              jsonRes(200, membershipJson()),
        }, onRequest: (request) => sent.add(request.data)),
      );
      expect((await second.join(code(), explicitOptIn: true)).joined, isTrue);
      expect(generatedAfterRestart, isFalse);
      expect((sent[0] as Map)['joinKey'], (sent[1] as Map)['joinKey']);
    });

    test('server応答に氏名が混じれば所属を保存しない', () async {
      final store = MemorySessionStore();
      final client = LanSocialClient(
        endpoint: endpoint,
        store: store,
        opaqueKeyFactory: () => 'H' * 32,
        dio: fakeDio({
          'POST $baseUrl/v1/lan-social/join': () =>
              jsonRes(200, membershipJson(extra: ',"studentName":"山田"')),
        }),
      );
      final result = await client.join(code(), explicitOptIn: true);
      expect(result.error, LanSocialClientError.invalidResponse);
      expect(await client.saved(LanSocialRoomKind.friends), isNull);
    });
  });

  group('退出の再試行', () {
    test('503ではmembershipを保持し、再起動後の204でだけ削除する', () async {
      final store = MemorySessionStore();
      final requests = <RequestOptions>[];
      final first = LanSocialClient(
        endpoint: endpoint,
        store: store,
        opaqueKeyFactory: () => 'V' * 32,
        dio: fakeDio({
          'POST $baseUrl/v1/lan-social/join': () =>
              jsonRes(200, membershipJson()),
          'POST $baseUrl/v1/lan-social/leave': () => jsonRes(503, '{}'),
        }, onRequest: requests.add),
      );
      expect((await first.join(code(), explicitOptIn: true)).joined, isTrue);

      expect(await first.leave(LanSocialRoomKind.friends), isFalse);
      expect(
        await first.saved(LanSocialRoomKind.friends),
        isNotNull,
        reason: 'coordinator側の退出が未確認なら再試行資格を失わない',
      );
      expect(await first.leavePending(LanSocialRoomKind.friends), isTrue);
      expect(
        await first.contributeMeaningfulEvent(
          kind: LanSocialRoomKind.friends,
          event: event(eventId: 'must-not-send-after-opt-out'),
        ),
        isNull,
        reason: '退出保留中はcredentialを保持しても新しい学習を送らない',
      );
      expect(
        requests.where((request) => request.path.endsWith('/contribution')),
        isEmpty,
      );

      final restarted = LanSocialClient(
        endpoint: endpoint,
        store: store,
        dio: fakeDio({
          'POST $baseUrl/v1/lan-social/leave': () => jsonRes(204, '{}'),
        }, onRequest: requests.add),
      );
      expect(await restarted.saved(LanSocialRoomKind.friends), isNotNull);
      expect(await restarted.leave(LanSocialRoomKind.friends), isTrue);
      expect(await restarted.saved(LanSocialRoomKind.friends), isNull);
      expect(await restarted.leavePending(LanSocialRoomKind.friends), isFalse);
      final leaveRequests = requests
          .where((request) => request.path.endsWith('/leave'))
          .toList(growable: false);
      expect(leaveRequests, hasLength(2));
      expect(
        leaveRequests
            .map((request) => request.headers['Authorization'])
            .toSet(),
        {'Bearer $credential'},
      );
    });

    test('401はcoordinatorですでに無効な資格として端末から削除する', () async {
      final store = MemorySessionStore();
      final joining = LanSocialClient(
        endpoint: endpoint,
        store: store,
        opaqueKeyFactory: () => 'W' * 32,
        dio: fakeDio({
          'POST $baseUrl/v1/lan-social/join': () =>
              jsonRes(200, membershipJson()),
        }),
      );
      expect((await joining.join(code(), explicitOptIn: true)).joined, isTrue);
      final client = LanSocialClient(
        endpoint: endpoint,
        store: store,
        dio: fakeDio({
          'POST $baseUrl/v1/lan-social/leave': () => jsonRes(401, '{}'),
        }),
      );

      expect(await client.leave(LanSocialRoomKind.friends), isTrue);
      expect(await client.saved(LanSocialRoomKind.friends), isNull);
    });
  });

  group('期限後terminal receipt', () {
    test('Friendsは401後のreceiptを保存してからmembershipを消す', () async {
      final store = MemorySessionStore();
      await saveTerminalMembership(store, LanSocialRoomKind.friends);
      final requests = <RequestOptions>[];
      final client = LanSocialClient(
        endpoint: endpoint,
        store: store,
        dio: fakeDio({
          'GET $baseUrl/v1/lan-social/snapshot': () => jsonRes(401, '{}'),
          'GET $baseUrl/v1/lan-social/settlement': () =>
              jsonRes(200, friendsTerminalReceiptJson()),
        }, onRequest: requests.add),
      );

      final refreshed = await client.refresh(LanSocialRoomKind.friends);
      expect(
        refreshed?.terminalReceipt,
        isA<LanSocialFriendsTerminalReceipt>(),
      );
      expect(await client.saved(LanSocialRoomKind.friends), isNull);
      final progress = await store.learningProgressSnapshot(
        LearningScope.personal,
      );
      expect(progress.wallet.gems, 1);
      expect(progress.rewards.single.reason, 'lan-friends.v1:$roomId');
      expect(requests.map((request) => request.path), [
        '$baseUrl/v1/lan-social/snapshot',
        '$baseUrl/v1/lan-social/settlement',
      ]);
      expect(
        requests.map((request) => request.headers['Authorization']).toSet(),
        {'Bearer $credential'},
      );
    });

    test('学習寄与が期限切410を返しても同じreceipt導線で確定する', () async {
      final store = MemorySessionStore();
      await saveTerminalMembership(store, LanSocialRoomKind.friends);
      final client = LanSocialClient(
        endpoint: endpoint,
        store: store,
        dio: fakeDio({
          'POST $baseUrl/v1/lan-social/contribution': () => jsonRes(410, '{}'),
          'GET $baseUrl/v1/lan-social/settlement': () =>
              jsonRes(200, friendsTerminalReceiptJson()),
        }),
      );

      expect(
        await client.contributeMeaningfulEvent(
          kind: LanSocialRoomKind.friends,
          event: event(),
        ),
        isNull,
      );
      expect(await client.saved(LanSocialRoomKind.friends), isNull);
      expect(
        (await store.learningProgressSnapshot(
          LearningScope.personal,
        )).wallet.gems,
        1,
      );
    });

    test('membership削除失敗から再起動してもFriends報酬を二重付与しない', () async {
      final store = _FailFirstTerminalMembershipRemovalStore();
      await saveTerminalMembership(store, LanSocialRoomKind.friends);
      final dio = fakeDio({
        'GET $baseUrl/v1/lan-social/snapshot': () => jsonRes(401, '{}'),
        'GET $baseUrl/v1/lan-social/settlement': () =>
            jsonRes(200, friendsTerminalReceiptJson()),
      });

      final first = LanSocialClient(endpoint: endpoint, store: store, dio: dio);
      expect(await first.refresh(LanSocialRoomKind.friends), isNull);
      expect(await first.saved(LanSocialRoomKind.friends), isNotNull);
      expect(
        (await store.learningProgressSnapshot(
          LearningScope.personal,
        )).wallet.gems,
        1,
      );

      final restarted = LanSocialClient(
        endpoint: endpoint,
        store: store,
        dio: dio,
      );
      expect(
        (await restarted.refresh(LanSocialRoomKind.friends))?.terminalReceipt,
        isA<LanSocialFriendsTerminalReceipt>(),
      );
      final progress = await store.learningProgressSnapshot(
        LearningScope.personal,
      );
      expect(progress.wallet.gems, 1);
      expect(progress.rewards, hasLength(1));
      expect(await restarted.saved(LanSocialRoomKind.friends), isNull);
    });

    test('League receiptの実順位を10段tierへexact-onceで保存する', () async {
      final store = _FailFirstTerminalMembershipRemovalStore();
      await saveTerminalMembership(store, LanSocialRoomKind.league);
      final dio = fakeDio({
        'GET $baseUrl/v1/lan-social/snapshot': () => jsonRes(401, '{}'),
        'GET $baseUrl/v1/lan-social/settlement': () =>
            jsonRes(200, leagueTerminalReceiptJson()),
      });

      final first = LanSocialClient(endpoint: endpoint, store: store, dio: dio);
      expect(await first.refresh(LanSocialRoomKind.league), isNull);
      var profile = await first.leagueProfile();
      expect(profile.currentTier, LanSocialLeagueTier.silver);
      expect(profile.history, hasLength(1));
      expect(profile.history.single.rank, 1);
      expect(profile.history.single.finalizedAt, DateTime.utc(2026, 8, 17));
      expect(await first.saved(LanSocialRoomKind.league), isNotNull);

      final restarted = LanSocialClient(
        endpoint: endpoint,
        store: store,
        dio: dio,
      );
      final settled = await restarted.refresh(LanSocialRoomKind.league);
      expect(settled?.terminalReceipt, isA<LanSocialLeagueTerminalReceipt>());
      profile = await restarted.leagueProfile();
      expect(profile.currentTier, LanSocialLeagueTier.silver);
      expect(profile.history, hasLength(1));
      expect(await restarted.saved(LanSocialRoomKind.league), isNull);
    });

    test('SQLite端末の再起動後にreceiptを回収し、次の再起動で履歴を復元する', () async {
      final directory = await Directory.systemTemp.createTemp(
        'dekisugi-lan-settlement-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = p.join(directory.path, 'settlement.db');

      final beforeOffline = await SqfliteSessionStore.open(path: path);
      await saveTerminalMembership(beforeOffline, LanSocialRoomKind.league);
      await beforeOffline.close();

      final afterOffline = await SqfliteSessionStore.open(path: path);
      final dio = fakeDio({
        'GET $baseUrl/v1/lan-social/snapshot': () => jsonRes(401, '{}'),
        'GET $baseUrl/v1/lan-social/settlement': () =>
            jsonRes(200, leagueTerminalReceiptJson()),
      });
      final settling = LanSocialClient(
        endpoint: endpoint,
        store: afterOffline,
        dio: dio,
      );
      expect(
        (await settling.refresh(LanSocialRoomKind.league))?.terminalReceipt,
        isA<LanSocialLeagueTerminalReceipt>(),
      );
      await afterOffline.close();

      final reopened = await SqfliteSessionStore.open(path: path);
      final restored = LanSocialClient(
        endpoint: endpoint,
        store: reopened,
        dio: fakeDio({}),
      );
      final profile = await restored.leagueProfile();
      expect(profile.currentTier, LanSocialLeagueTier.silver);
      expect(profile.history, hasLength(1));
      expect(profile.history.single.roomId, roomId);
      expect(await restored.saved(LanSocialRoomKind.league), isNull);
      await reopened.close();
    });

    test('5人未満receiptは人数・XP・順位を保存せず所属だけ終了する', () async {
      final store = MemorySessionStore();
      await saveTerminalMembership(store, LanSocialRoomKind.league);
      final client = LanSocialClient(
        endpoint: endpoint,
        store: store,
        dio: fakeDio({
          'GET $baseUrl/v1/lan-social/snapshot': () => jsonRes(401, '{}'),
          'GET $baseUrl/v1/lan-social/settlement': () => jsonRes(
            200,
            leagueTerminalReceiptJson(privacyThresholdReached: false),
          ),
        }),
      );

      final result = await client.refresh(LanSocialRoomKind.league);
      final receipt = result?.terminalReceipt;
      expect(receipt, isA<LanSocialLeagueTerminalReceipt>());
      expect(
        (receipt as LanSocialLeagueTerminalReceipt).participantCount,
        isNull,
      );
      expect((await client.leagueProfile()).history, isEmpty);
      expect(await client.saved(LanSocialRoomKind.league), isNull);
    });

    test('404・409・503ではreceipt再試行用membershipを保持する', () async {
      for (final status in [404, 409, 503]) {
        final store = MemorySessionStore();
        await saveTerminalMembership(store, LanSocialRoomKind.league);
        final client = LanSocialClient(
          endpoint: endpoint,
          store: store,
          dio: fakeDio({
            'GET $baseUrl/v1/lan-social/snapshot': () => jsonRes(401, '{}'),
            'GET $baseUrl/v1/lan-social/settlement': () =>
                jsonRes(status, '{}'),
          }),
        );

        expect(await client.refresh(LanSocialRoomKind.league), isNull);
        expect(
          await client.saved(LanSocialRoomKind.league),
          isNotNull,
          reason: 'status=$status',
        );
        expect((await client.leagueProfile()).history, isEmpty);
      }
    });

    test('異なるreceipt room/weekと未知欄は保存せずmembershipを残す', () async {
      for (final receipt in [
        leagueTerminalReceiptJson(receiptRoomId: 'f' * 24),
        leagueTerminalReceiptJson(weekStart: '2026-08-03'),
        leagueTerminalReceiptJson(extra: 'studentName'),
      ]) {
        final store = MemorySessionStore();
        await saveTerminalMembership(store, LanSocialRoomKind.league);
        final client = LanSocialClient(
          endpoint: endpoint,
          store: store,
          dio: fakeDio({
            'GET $baseUrl/v1/lan-social/snapshot': () => jsonRes(401, '{}'),
            'GET $baseUrl/v1/lan-social/settlement': () =>
                jsonRes(200, receipt),
          }),
        );

        expect(await client.refresh(LanSocialRoomKind.league), isNull);
        expect(await client.saved(LanSocialRoomKind.league), isNotNull);
        expect((await client.leagueProfile()).history, isEmpty);
      }
    });

    test('端末tier保存が失敗した回はmembershipを消さず再試行する', () async {
      final store = _FailFirstTerminalLeagueProfileStore();
      await saveTerminalMembership(store, LanSocialRoomKind.league);
      final dio = fakeDio({
        'GET $baseUrl/v1/lan-social/snapshot': () => jsonRes(401, '{}'),
        'GET $baseUrl/v1/lan-social/settlement': () =>
            jsonRes(200, leagueTerminalReceiptJson()),
      });
      final client = LanSocialClient(
        endpoint: endpoint,
        store: store,
        dio: dio,
      );

      expect(await client.refresh(LanSocialRoomKind.league), isNull);
      expect(await client.saved(LanSocialRoomKind.league), isNotNull);
      expect((await client.leagueProfile()).history, isEmpty);

      final retry = await client.refresh(LanSocialRoomKind.league);
      expect(retry?.terminalReceipt, isA<LanSocialLeagueTerminalReceipt>());
      expect((await client.leagueProfile()).history, hasLength(1));
      expect(await client.saved(LanSocialRoomKind.league), isNull);
    });

    test('receipt保存期間後の410は終了済みとしてmembershipを消す', () async {
      final store = MemorySessionStore();
      await saveTerminalMembership(store, LanSocialRoomKind.friends);
      final client = LanSocialClient(
        endpoint: endpoint,
        store: store,
        dio: fakeDio({
          'GET $baseUrl/v1/lan-social/snapshot': () => jsonRes(401, '{}'),
          'GET $baseUrl/v1/lan-social/settlement': () => jsonRes(410, '{}'),
        }),
      );

      expect(await client.refresh(LanSocialRoomKind.friends), isNull);
      expect(await client.saved(LanSocialRoomKind.friends), isNull);
      expect(
        (await store.learningProgressSnapshot(
          LearningScope.personal,
        )).wallet.gems,
        0,
      );
    });
  });

  group('意味のある学習だけを寄与する', () {
    Future<LanSocialClient> joinedClient({
      required MemorySessionStore store,
      required void Function(RequestOptions) onRequest,
      LanSocialRoomKind kind = LanSocialRoomKind.friends,
    }) async {
      final client = LanSocialClient(
        endpoint: endpoint,
        store: store,
        opaqueKeyFactory: () => 'J' * 32,
        dio: fakeDio({
          'POST $baseUrl/v1/lan-social/join': () =>
              jsonRes(200, membershipJson(kind: kind)),
          'POST $baseUrl/v1/lan-social/contribution': () => jsonRes(
            200,
            '{"applied":true,"xpAdded":0,"snapshot":$friendsSnapshotJson}',
          ),
        }, onRequest: onRequest),
      );
      expect(
        (await client.join(code(kind), explicitOptIn: true)).joined,
        isTrue,
      );
      return client;
    }

    test('salted idempotency keyと学習日だけを送る', () async {
      final requests = <RequestOptions>[];
      final client = await joinedClient(
        store: MemorySessionStore(),
        onRequest: requests.add,
      );
      final result = await client.contributeMeaningfulEvent(
        kind: LanSocialRoomKind.friends,
        event: event(eventId: 'local-event-secret'),
      );
      expect(result?.applied, isTrue);
      expect(result?.xpAdded, 0, reason: 'Friendsは共同状態だけで個別得点を返さない');
      final request = requests.last;
      expect((request.data as Map).keys.toSet(), {
        'idempotencyKey',
        'learningDay',
      });
      expect(
        (request.data as Map)['idempotencyKey'],
        isNot('local-event-secret'),
      );
      expect(jsonEncode(request.data).contains('local-event-secret'), isFalse);
    });

    test('meaningfulでないeventは通信しない', () async {
      final requests = <RequestOptions>[];
      final client = await joinedClient(
        store: MemorySessionStore(),
        onRequest: requests.add,
      );
      final before = requests.length;
      expect(
        await client.contributeMeaningfulEvent(
          kind: LanSocialRoomKind.friends,
          event: event(meaningful: false),
        ),
        isNull,
      );
      expect(requests.length, before);
    });

    test('schoolLocal eventを個人順位leagueへ送らない', () async {
      final requests = <RequestOptions>[];
      final client = await joinedClient(
        store: MemorySessionStore(),
        onRequest: requests.add,
        kind: LanSocialRoomKind.league,
      );
      final before = requests.length;
      expect(
        await client.contributeMeaningfulEvent(
          kind: LanSocialRoomKind.league,
          event: event(scope: LearningScope.schoolLocal),
        ),
        isNull,
      );
      expect(requests.length, before);
    });

    test('2人達成応答は同じroomへ固定1結晶だけを付与する', () async {
      final store = MemorySessionStore();
      var contributionCount = 0;
      final client = LanSocialClient(
        endpoint: endpoint,
        store: store,
        opaqueKeyFactory: () => 'Q' * 32,
        dio: fakeDio({
          'POST $baseUrl/v1/lan-social/join': () =>
              jsonRes(200, membershipJson()),
          'POST $baseUrl/v1/lan-social/contribution': () {
            contributionCount += 1;
            return jsonRes(
              200,
              '{"applied":${contributionCount == 1},'
              '"xpAdded":0,'
              '"snapshot":$completedFriendsSnapshotJson}',
            );
          },
        }),
      );
      expect((await client.join(code(), explicitOptIn: true)).joined, isTrue);

      await client.contributeMeaningfulEvent(
        kind: LanSocialRoomKind.friends,
        event: event(),
      );
      await client.contributeMeaningfulEvent(
        kind: LanSocialRoomKind.friends,
        event: event(),
      );

      final snapshot = await store.learningProgressSnapshot(
        LearningScope.personal,
      );
      expect(snapshot.wallet.gems, 1);
      expect(snapshot.events, isEmpty, reason: 'LAN報酬は学習eventを生成しない');
      expect(snapshot.rewards.single.reason, 'lan-friends.v1:$roomId');
    });

    test('壊れたmembershipやclient失敗を学習側へthrowせずfail-closedにする', () async {
      final corrupt = MemorySessionStore();
      await corrupt.setSetting(
        'lan_social.memberships.v1',
        '{"version":1,"memberships":[{"deviceId":"raw"}]}',
      );
      var constructed = 0;
      await LanSocialMeaningfulProgressDispatcher(
        store: corrupt,
        clientFactory: (_) {
          constructed += 1;
          throw StateError('must not construct from corrupt membership');
        },
      ).contribute(event());
      expect(constructed, 0);

      final joinedStore = MemorySessionStore();
      final joining = LanSocialClient(
        endpoint: endpoint,
        store: joinedStore,
        opaqueKeyFactory: () => 'R' * 32,
        dio: fakeDio({
          'POST $baseUrl/v1/lan-social/join': () =>
              jsonRes(200, membershipJson()),
        }),
      );
      expect((await joining.join(code(), explicitOptIn: true)).joined, isTrue);
      await LanSocialMeaningfulProgressDispatcher(
        store: joinedStore,
        clientFactory: (endpoint) => LanSocialClient(
          endpoint: endpoint,
          store: joinedStore,
          dio: fakeDio({}),
        ),
      ).contribute(event());
      expect(
        await joinedStore.learningProgressSnapshot(LearningScope.personal),
        isA<LearningProgressSnapshot>(),
      );
    });

    test('1つの確定eventを保存済みfriendsとleagueの両方へ自動寄与する', () async {
      final store = MemorySessionStore();
      final leagueRoomId = 'd' * 24;
      final memberships = [
        LanSocialMembership(
          baseUrl: baseUrl,
          certificateSha256: pin,
          roomId: roomId,
          kind: LanSocialRoomKind.friends,
          credential: credential,
          eventSalt: 'S' * 32,
          expiresAt: DateTime.utc(2026, 8, 17),
          weekStart: null,
        ),
        LanSocialMembership(
          baseUrl: baseUrl,
          certificateSha256: pin,
          roomId: leagueRoomId,
          kind: LanSocialRoomKind.league,
          credential: '$leagueRoomId.$participantId.${'T' * 43}',
          eventSalt: 'U' * 32,
          expiresAt: DateTime.utc(2026, 8, 17),
          weekStart: '2026-08-10',
        ),
      ];
      await store.setSetting(
        'lan_social.memberships.v1',
        jsonEncode({
          'version': 1,
          'memberships': [
            for (final membership in memberships) membership.toJson(),
          ],
        }),
      );
      var calls = 0;
      final requests = <RequestOptions>[];
      final dio = fakeDio({
        'POST $baseUrl/v1/lan-social/contribution': () {
          calls += 1;
          final snapshot = calls == 1
              ? friendsSnapshotJson
              : privateLeagueSnapshotJson;
          return jsonRes(
            200,
            '{"applied":true,"xpAdded":${calls == 1 ? 0 : 10},"snapshot":$snapshot}',
          );
        },
      }, onRequest: requests.add);

      await LanSocialMeaningfulProgressDispatcher(
        store: store,
        clientFactory: (endpoint) =>
            LanSocialClient(endpoint: endpoint, store: store, dio: dio),
      ).contribute(event());

      expect(calls, 2);
      expect(
        requests
            .where((request) => request.path.endsWith('/contribution'))
            .map((request) => request.headers['Authorization'])
            .toSet(),
        {'Bearer $credential', 'Bearer ${memberships[1].credential}'},
      );
    });
  });

  group('実順位と10段tier', () {
    test('BronzeからDiamondまで実週結果だけで昇格し、同じ週を二重確定しない', () async {
      final store = MemorySessionStore();
      final client = LanSocialClient(
        endpoint: endpoint,
        store: store,
        dio: fakeDio({}),
      );
      for (var index = 0; index < 9; index += 1) {
        final id = index.toRadixString(16).padLeft(24, '0');
        final week = '2026-${(index + 1).toString().padLeft(2, '0')}-02';
        final membership = _membership(roomId: id, weekStart: week);
        final snapshot = _expiredLeague(weekStart: week, myRank: 1, myXp: 30);
        final profile = await client.finalizeLeague(
          membership: membership,
          snapshot: snapshot,
          finalizedAt: DateTime.utc(2026, index + 1, 9),
        );
        expect(profile.currentTier.index, index + 1);
        final replay = await client.finalizeLeague(
          membership: membership,
          snapshot: snapshot,
        );
        expect(replay.history.length, index + 1);
      }
      final profile = await client.leagueProfile();
      expect(profile.currentTier, LanSocialLeagueTier.diamond);
      expect(profile.history.first.movement, LanSocialLeagueMovement.promoted);
      expect(profile.history.first.previousTier, LanSocialLeagueTier.obsidian);
    });

    test('unique最下位だけ降格し、同率最下位や全員0では恣意的に降格しない', () async {
      final store = MemorySessionStore();
      final client = LanSocialClient(
        endpoint: endpoint,
        store: store,
        dio: fakeDio({}),
      );
      final promoted = await client.finalizeLeague(
        membership: _membership(roomId: '1' * 24, weekStart: '2026-08-03'),
        snapshot: _expiredLeague(weekStart: '2026-08-03', myRank: 1, myXp: 30),
      );
      expect(promoted.currentTier, LanSocialLeagueTier.silver);

      final tied = await client.finalizeLeague(
        membership: _membership(roomId: '2' * 24, weekStart: '2026-08-10'),
        snapshot: _expiredLeague(
          weekStart: '2026-08-10',
          myRank: 4,
          myXp: 0,
          mineTied: true,
        ),
      );
      expect(tied.currentTier, LanSocialLeagueTier.silver);
      expect(tied.history.first.movement, LanSocialLeagueMovement.stayed);

      final demoted = await client.finalizeLeague(
        membership: _membership(roomId: '3' * 24, weekStart: '2026-08-17'),
        snapshot: _expiredLeague(weekStart: '2026-08-17', myRank: 5, myXp: 0),
      );
      expect(demoted.currentTier, LanSocialLeagueTier.bronze);
      expect(demoted.history.first.movement, LanSocialLeagueMovement.demoted);
    });

    test('10段をBronzeからDiamondの順で固定する', () {
      expect(LanSocialLeagueTier.values.map((tier) => tier.label), [
        'ブロンズ',
        'シルバー',
        'ゴールド',
        'サファイア',
        'ルビー',
        'エメラルド',
        'アメジスト',
        'パール',
        'オブシディアン',
        'ダイヤモンド',
      ]);
    });
  });

  test('自己署名TLSは一致pinだけ通し、異なるpinは拒否する', () async {
    final fixture = await _TlsFixture.start();
    addTearDown(fixture.close);
    final good = LanSocialClient(
      endpoint: fixture.endpoint,
      store: MemorySessionStore(),
      opaqueKeyFactory: () => 'K' * 32,
    );
    final room = await good.createRoom(
      kind: LanSocialRoomKind.friends,
      capacity: 2,
      coordinatorKey: 'L' * 32,
      explicitOptIn: true,
    );
    expect(room?.inviteCode, invite);

    final badStore = MemorySessionStore();
    final badEndpoint = LanSocialEndpoint(
      baseUrl: fixture.endpoint.baseUrl,
      certificateSha256: 'f' * 64,
    );
    final bad = LanSocialClient(
      endpoint: badEndpoint,
      store: badStore,
      opaqueKeyFactory: () => 'M' * 32,
    );
    expect(
      await bad.createRoom(
        kind: LanSocialRoomKind.friends,
        capacity: 2,
        coordinatorKey: 'N' * 32,
        explicitOptIn: true,
      ),
      isNull,
    );

    final membership = LanSocialMembership(
      baseUrl: badEndpoint.baseUrl,
      certificateSha256: badEndpoint.certificateSha256,
      roomId: roomId,
      kind: LanSocialRoomKind.friends,
      credential: credential,
      eventSalt: 'P' * 32,
      expiresAt: DateTime.utc(2026, 8, 17),
      weekStart: null,
    );
    await badStore.setSetting(
      'lan_social.memberships.v1',
      jsonEncode({
        'version': 1,
        'memberships': [membership.toJson()],
      }),
    );
    expect(await bad.refresh(LanSocialRoomKind.friends), isNull);
    expect(
      await bad.saved(LanSocialRoomKind.friends),
      isNotNull,
      reason: 'TLS pin failure must keep terminal receipt retry eligibility',
    );
  });
}

LanSocialMembership _membership({
  required String roomId,
  required String weekStart,
}) => LanSocialMembership(
  baseUrl: baseUrl,
  certificateSha256: pin,
  roomId: roomId,
  kind: LanSocialRoomKind.league,
  credential: '$roomId.$participantId.${'C' * 43}',
  eventSalt: 'D' * 32,
  expiresAt: DateTime.utc(2026, 12, 31),
  weekStart: weekStart,
);

LanSocialLeagueSnapshot _expiredLeague({
  required String weekStart,
  required int? myRank,
  required int myXp,
  bool mineTied = false,
}) {
  final standings = switch ((myRank, mineTied)) {
    (1, false) => [
      LanSocialLeagueStanding(rank: 1, xp: myXp, isMe: true, tied: false),
      const LanSocialLeagueStanding(rank: 2, xp: 20, isMe: false, tied: false),
      const LanSocialLeagueStanding(rank: 3, xp: 10, isMe: false, tied: false),
      const LanSocialLeagueStanding(rank: 4, xp: 0, isMe: false, tied: true),
      const LanSocialLeagueStanding(rank: 4, xp: 0, isMe: false, tied: true),
    ],
    (4, true) => [
      const LanSocialLeagueStanding(rank: 1, xp: 30, isMe: false, tied: false),
      const LanSocialLeagueStanding(rank: 2, xp: 20, isMe: false, tied: false),
      const LanSocialLeagueStanding(rank: 3, xp: 10, isMe: false, tied: false),
      LanSocialLeagueStanding(rank: 4, xp: myXp, isMe: true, tied: true),
      LanSocialLeagueStanding(rank: 4, xp: myXp, isMe: false, tied: true),
    ],
    (5, false) => [
      const LanSocialLeagueStanding(rank: 1, xp: 40, isMe: false, tied: false),
      const LanSocialLeagueStanding(rank: 2, xp: 30, isMe: false, tied: false),
      const LanSocialLeagueStanding(rank: 3, xp: 20, isMe: false, tied: false),
      const LanSocialLeagueStanding(rank: 4, xp: 10, isMe: false, tied: false),
      LanSocialLeagueStanding(rank: 5, xp: myXp, isMe: true, tied: false),
    ],
    _ => throw ArgumentError('unsupported league fixture'),
  };
  return LanSocialLeagueSnapshot(
    state: LanSocialLeagueState.expired,
    privacyThresholdReached: true,
    standings: standings,
    myXp: myXp,
    weekStart: weekStart,
    weekEnd: weekStart,
    expiresAt: DateTime.utc(2026, 1, 1),
  );
}

final class _FailFirstTerminalMembershipRemovalStore
    extends MemorySessionStore {
  var _failRemoval = true;

  @override
  Future<void> setSetting(String key, String? value) async {
    if (_failRemoval && key == 'lan_social.memberships.v1' && value == null) {
      _failRemoval = false;
      throw StateError('simulated membership removal failure');
    }
    await super.setSetting(key, value);
  }
}

final class _FailFirstTerminalLeagueProfileStore extends MemorySessionStore {
  var _failProfile = true;

  @override
  Future<void> setSetting(String key, String? value) async {
    if (_failProfile && key == 'lan_social.league_profile.v1') {
      _failProfile = false;
      throw StateError('simulated league profile failure');
    }
    await super.setSetting(key, value);
  }
}

final class _TlsFixture {
  const _TlsFixture(this.server, this.directory, this.endpoint);

  final HttpServer server;
  final Directory directory;
  final LanSocialEndpoint endpoint;

  static Future<_TlsFixture> start() async {
    final directory = await Directory.systemTemp.createTemp(
      'dekisugi-tls-pin-',
    );
    final cert = File('${directory.path}/cert.pem');
    final key = File('${directory.path}/key.pem');
    final der = File('${directory.path}/cert.der');
    final generated = await Process.run('openssl', [
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-sha256',
      '-nodes',
      '-days',
      '1',
      '-subj',
      '/CN=dekisugi-lan-test',
      '-keyout',
      key.path,
      '-out',
      cert.path,
    ]);
    if (generated.exitCode != 0) {
      throw StateError('openssl test certificate generation failed');
    }
    final converted = await Process.run('openssl', [
      'x509',
      '-in',
      cert.path,
      '-outform',
      'DER',
      '-out',
      der.path,
    ]);
    if (converted.exitCode != 0) {
      throw StateError('openssl DER conversion failed');
    }
    final context = SecurityContext()
      ..useCertificateChain(cert.path)
      ..usePrivateKey(key.path);
    final server = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      context,
    );
    server.listen((request) async {
      await utf8.decoder.bind(request).join();
      request.response.headers.contentType = ContentType.json;
      request.response.statusCode = HttpStatus.created;
      request.response.write(
        '{'
        '"protocolVersion":1,'
        '"roomId":"$roomId",'
        '"kind":"friends",'
        '"inviteCode":"$invite",'
        '"capacity":2,'
        '"expiresAt":"2026-08-17T00:00:00.000Z",'
        '"weekStart":null'
        '}',
      );
      await request.response.close();
    });
    return _TlsFixture(
      server,
      directory,
      LanSocialEndpoint(
        baseUrl: 'https://127.0.0.1:${server.port}',
        certificateSha256: sha256.convert(await der.readAsBytes()).toString(),
      ),
    );
  }

  Future<void> close() async {
    await server.close(force: true);
    await directory.delete(recursive: true);
  }
}
