import 'dart:convert';

import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/game_tokens.dart';
import 'package:dekisugi/models/lan_social.dart';
import 'package:dekisugi/screens/lan_social_screen.dart';
import 'package:dekisugi/services/lan_social_client.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/stub_dio.dart';

const _baseUrl = 'https://192.168.1.20:8787';
const _pin = '1111111111111111111111111111111111111111111111111111111111111111';
const _roomId = 'aaaaaaaaaaaaaaaaaaaaaaaa';
const _participantId = 'bbbbbbbbbbbbbbbbbbbbbbbb';
const _credential =
    '$_roomId.$_participantId.CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC';
const _invite = '2345-6789-ABCD';
const _endpoint = LanSocialEndpoint(baseUrl: _baseUrl, certificateSha256: _pin);

LanSocialConnectionCode _code(LanSocialRoomKind kind) =>
    LanSocialConnectionCode(
      endpoint: _endpoint,
      inviteCode: _invite,
      kind: kind,
    );

String _membershipJson(LanSocialRoomKind kind) =>
    '{'
    '"protocolVersion":1,'
    '"roomId":"$_roomId",'
    '"kind":"${kind.wire}",'
    '"credential":"$_credential",'
    '"expiresAt":"2026-08-17T00:00:00.000Z",'
    '"weekStart":${kind == LanSocialRoomKind.league ? '"2026-08-10"' : 'null'}'
    '}';

const _friendsActive =
    '{'
    '"protocolVersion":1,'
    '"kind":"friends",'
    '"state":"active",'
    '"participantBand":"two",'
    '"myContributed":false,'
    '"completed":false,'
    '"expiresAt":"2026-08-17T00:00:00.000Z"'
    '}';

const _leaguePrivate =
    '{'
    '"protocolVersion":1,'
    '"kind":"league",'
    '"state":"waiting_for_privacy_threshold",'
    '"participantBand":"under5",'
    '"standings":[],'
    '"myXp":20,'
    '"weekStart":"2026-08-10",'
    '"weekEnd":"2026-08-16",'
    '"expiresAt":"2026-08-17T00:00:00.000Z"'
    '}';

const _leagueExpired =
    '{'
    '"protocolVersion":1,'
    '"kind":"league",'
    '"state":"expired",'
    '"participantBand":"5-8",'
    '"standings":['
    '{"rank":1,"xp":30,"isMe":true,"tied":false},'
    '{"rank":2,"xp":20,"isMe":false,"tied":false},'
    '{"rank":3,"xp":10,"isMe":false,"tied":false},'
    '{"rank":4,"xp":0,"isMe":false,"tied":true},'
    '{"rank":4,"xp":0,"isMe":false,"tied":true}'
    '],'
    '"myXp":30,'
    '"weekStart":"2026-08-10",'
    '"weekEnd":"2026-08-16",'
    '"expiresAt":"2026-08-17T00:00:00.000Z"'
    '}';

const _leagueTerminalReceipt =
    '{'
    '"protocolVersion":1,'
    '"roomId":"$_roomId",'
    '"kind":"league",'
    '"weekStart":"2026-08-10",'
    '"participantBand":"5-8",'
    '"xp":30,'
    '"rank":1,'
    '"tied":false,'
    '"participantCount":5,'
    '"settledAt":"2026-08-17T00:00:00.000Z"'
    '}';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget app(Widget child, {Brightness brightness = Brightness.light}) =>
      MaterialApp(theme: buildAppTheme(brightness), home: child);

  void compactLargeText(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Future<void> scrollThrough(WidgetTester tester) async {
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final list = find.byType(ListView);
    expect(list, findsOneWidget);
    for (var index = 0; index < 14; index += 1) {
      await tester.drag(list, const Offset(0, -260));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  }

  Future<void> pumpUntilFound(WidgetTester tester, Finder target) async {
    for (var attempt = 0; attempt < 30; attempt += 1) {
      await tester.pump(const Duration(milliseconds: 50));
      if (target.evaluate().isNotEmpty) return;
      final scrollable = find.byType(Scrollable);
      if (scrollable.evaluate().isNotEmpty) {
        final position = tester
            .state<ScrollableState>(scrollable.first)
            .position;
        position.jumpTo(
          (position.pixels + 220).clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
          ),
        );
      }
    }
    expect(target, findsWidgets);
  }

  Future<void> reveal(WidgetTester tester, Finder target) async {
    if (target.evaluate().isEmpty) await pumpUntilFound(tester, target);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
  }

  Dio socialDio({
    required LanSocialRoomKind kind,
    required String snapshot,
    void Function(RequestOptions request)? onRequest,
  }) => fakeDio({
    'POST $_baseUrl/v1/lan-social/join': () =>
        jsonRes(200, _membershipJson(kind)),
    'GET $_baseUrl/v1/lan-social/snapshot': () => jsonRes(200, snapshot),
  }, onRequest: onRequest);

  Future<void> prepareMembership({
    required MemorySessionStore store,
    required Dio dio,
    required LanSocialRoomKind kind,
  }) async {
    final client = LanSocialClient(
      endpoint: _endpoint,
      store: store,
      dio: dio,
      opaqueKeyFactory: () => 'D' * 32,
    );
    final result = await client.join(_code(kind), explicitOptIn: true);
    expect(result.joined, isTrue);
  }

  testWidgets('学校モードはleagueを入口ごと隠し、送信境界をSemanticsで示す', (tester) async {
    final semantics = tester.ensureSemantics();
    compactLargeText(tester);
    final store = MemorySessionStore();
    var clientCreated = false;
    await tester.pumpWidget(
      app(
        LanSocialScreen(
          store: store,
          schoolMode: true,
          lanSocialAllowed: true,
          clientFactory: (endpoint) {
            clientCreated = true;
            return LanSocialClient(
              endpoint: endpoint,
              store: store,
              dio: fakeDio({}),
            );
          },
        ),
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('lan-social-kind-league')), findsNothing);
    expect(find.byKey(const ValueKey('lan-social-join')), findsNothing);
    expect(
      find.byKey(const ValueKey('open-lan-social-coordinator')),
      findsNothing,
    );
    expect(clientCreated, isFalse);
    expect(find.text('学校の端末内モードでは利用できません'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('LANへの接続と送信はありません')), findsOneWidget);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      GamePalette.dark.canvas,
    );

    await scrollThrough(tester);
    semantics.dispose();
  });

  testWidgets('成人personalでもlocal-only既定は接続先も参加操作も作らない', (tester) async {
    var clientCreated = false;
    await tester.pumpWidget(
      app(
        LanSocialScreen(
          store: MemorySessionStore(),
          schoolMode: false,
          clientFactory: (_) {
            clientCreated = true;
            throw StateError('must stay unreachable');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('通信しないモードでは利用できません'), findsOneWidget);
    expect(find.byKey(const ValueKey('lan-social-join')), findsNothing);
    expect(
      find.byKey(const ValueKey('open-lan-social-coordinator')),
      findsNothing,
    );
    expect(clientCreated, isFalse);
  });

  testWidgets('明示opt-in後だけ別端末friendsへ参加し、個人データを送らない', (tester) async {
    final semantics = tester.ensureSemantics();
    final store = MemorySessionStore();
    final requests = <RequestOptions>[];
    final dio = socialDio(
      kind: LanSocialRoomKind.friends,
      snapshot: _friendsActive,
      onRequest: requests.add,
    );
    await tester.pumpWidget(
      app(
        LanSocialScreen(
          store: store,
          schoolMode: false,
          lanSocialAllowed: true,
          clientFactory: (endpoint) =>
              LanSocialClient(endpoint: endpoint, store: store, dio: dio),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('lan-social-connection-code')),
      _code(LanSocialRoomKind.friends).encode(),
    );
    final optIn = find.byKey(const ValueKey('lan-social-explicit-opt-in'));
    await reveal(tester, optIn);
    await tester.tap(optIn);
    await tester.pump();
    final join = find.byKey(const ValueKey('lan-social-join'));
    await reveal(tester, join);
    await tester.tap(join);
    await tester.pumpAndSettle();

    expect(find.text('ふたりそろいました'), findsOneWidget);
    expect(find.textContaining('結晶1個'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('ふたりそろいました。自分の1回：まだ')), findsOneWidget);
    final joinRequest = requests.singleWhere(
      (request) => request.path.endsWith('/join'),
    );
    expect((joinRequest.data as Map).keys.toSet(), {
      'inviteCode',
      'joinKey',
      'optIn',
      'consentVersion',
    });
    final sent = jsonEncode(joinRequest.data);
    for (final forbidden in ['name', 'answer', 'audio', 'deviceId']) {
      expect(sent.contains(forbidden), isFalse);
    }
    semantics.dispose();
  });

  testWidgets('QR読取は参加コードを入れるだけで、明示同意まで通信しない', (tester) async {
    final store = MemorySessionStore();
    final requests = <RequestOptions>[];
    await tester.pumpWidget(
      app(
        LanSocialScreen(
          store: store,
          schoolMode: false,
          lanSocialAllowed: true,
          scanConnectionCode: (_) async =>
              _code(LanSocialRoomKind.league).encode(),
          clientFactory: (endpoint) => LanSocialClient(
            endpoint: endpoint,
            store: store,
            dio: socialDio(
              kind: LanSocialRoomKind.league,
              snapshot: _leaguePrivate,
              onRequest: requests.add,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await reveal(tester, find.byKey(const ValueKey('lan-social-scan-code')));
    await tester.tap(find.byKey(const ValueKey('lan-social-scan-code')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('lan-social-connection-code')),
          )
          .controller!
          .text,
      _code(LanSocialRoomKind.league).encode(),
    );
    expect(requests, isEmpty);
  });

  testWidgets('退出503はjoined資格を保持し、画面再起動後に再試行できる', (tester) async {
    final store = MemorySessionStore();
    var leaveAttempts = 0;
    final dio = fakeDio({
      'POST $_baseUrl/v1/lan-social/join': () =>
          jsonRes(200, _membershipJson(LanSocialRoomKind.friends)),
      'GET $_baseUrl/v1/lan-social/snapshot': () =>
          jsonRes(200, _friendsActive),
      'POST $_baseUrl/v1/lan-social/leave': () {
        leaveAttempts += 1;
        return jsonRes(leaveAttempts == 1 ? 503 : 204, '{}');
      },
    });
    await tester.runAsync(
      () => prepareMembership(
        store: store,
        dio: dio,
        kind: LanSocialRoomKind.friends,
      ),
    );

    Widget screen() => app(
      LanSocialScreen(
        store: store,
        schoolMode: false,
        lanSocialAllowed: true,
        clientFactory: (endpoint) =>
            LanSocialClient(endpoint: endpoint, store: store, dio: dio),
      ),
    );

    Future<void> requestLeave() async {
      final leave = find.byKey(const ValueKey('lan-social-leave'));
      await reveal(tester, leave);
      await tester.tap(leave);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '参加をやめる'));
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(screen());
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('lan-social-leave')),
    );
    await requestLeave();

    expect(leaveAttempts, 1);
    expect(
      find.text('退出を完了できませんでした。参加資格は端末に保持しています。接続を確認してもう一度試してください。'),
      findsOneWidget,
    );
    expect(find.text('退出をもう一度送る'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('lan-social-refresh')),
      findsNothing,
      reason: '退出保留中は状態取得より退出再試行だけを出す',
    );
    expect(
      await LanSocialClient.savedMemberships(store),
      hasLength(1),
      reason: 'UIも失敗を成功表示せず、retry credentialを残す',
    );
    expect(find.byKey(const ValueKey('lan-social-leave')), findsOneWidget);

    await tester.pumpWidget(app(const SizedBox.shrink()));
    await tester.pumpAndSettle();
    await tester.pumpWidget(screen());
    await pumpUntilFound(
      tester,
      find.byKey(const ValueKey('lan-social-leave')),
    );
    expect(
      find.text('退出を完了できませんでした。参加資格は端末に保持しています。接続を確認してもう一度試してください。'),
      findsOneWidget,
      reason: '退出保留は画面再起動後も復元する',
    );
    await requestLeave();

    expect(leaveAttempts, 2);
    expect(find.text('この端末の参加を解除しました。'), findsOneWidget);
    expect(await LanSocialClient.savedMemberships(store), isEmpty);
    expect(find.byKey(const ValueKey('lan-social-join')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('5人未満は自分のXPも実人数も画面へ出さず320dp・文200%で崩れない', (tester) async {
    compactLargeText(tester);
    final store = MemorySessionStore();
    final dio = socialDio(
      kind: LanSocialRoomKind.league,
      snapshot: _leaguePrivate,
    );
    await tester.runAsync(
      () => prepareMembership(
        store: store,
        dio: dio,
        kind: LanSocialRoomKind.league,
      ),
    );
    await tester.pumpWidget(
      app(
        LanSocialScreen(
          store: store,
          schoolMode: false,
          lanSocialAllowed: true,
          clientFactory: (endpoint) =>
              LanSocialClient(endpoint: endpoint, store: store, dio: dio),
        ),
      ),
    );
    final shield = find.byKey(const ValueKey('lan-social-league-private'));
    await pumpUntilFound(tester, shield);

    expect(shield, findsOneWidget);
    expect(find.text('20 XP'), findsNothing);
    for (var index = 0; index < 8; index += 1) {
      expect(find.byKey(ValueKey('lan-social-standing-$index')), findsNothing);
    }
    expect(find.textContaining('実人数を表示しません'), findsOneWidget);
    await scrollThrough(tester);
  });

  testWidgets('実在5枠だけを匿名表示し、10段tierと昇格履歴をdark/200%で示す', (tester) async {
    final semantics = tester.ensureSemantics();
    compactLargeText(tester);
    final store = MemorySessionStore();
    final dio = socialDio(
      kind: LanSocialRoomKind.league,
      snapshot: _leagueExpired,
    );
    await tester.runAsync(
      () => prepareMembership(
        store: store,
        dio: dio,
        kind: LanSocialRoomKind.league,
      ),
    );
    await tester.pumpWidget(
      app(
        LanSocialScreen(
          store: store,
          schoolMode: false,
          lanSocialAllowed: true,
          clientFactory: (endpoint) =>
              LanSocialClient(endpoint: endpoint, store: store, dio: dio),
        ),
        brightness: Brightness.dark,
      ),
    );
    final currentTier = find.byKey(const ValueKey('lan-social-current-tier'));
    await pumpUntilFound(tester, currentTier);

    expect(currentTier, findsOneWidget);
    expect(find.text('シルバー'), findsWidgets);
    for (final tier in LanSocialLeagueTier.values) {
      expect(find.text(tier.label), findsWidgets);
    }
    for (var index = 0; index < 5; index += 1) {
      expect(
        find.byKey(ValueKey('lan-social-standing-$index')),
        findsOneWidget,
      );
    }
    expect(find.byKey(const ValueKey('lan-social-standing-5')), findsNothing);
    expect(find.textContaining(_roomId), findsNothing);
    expect(find.textContaining(_participantId), findsNothing);
    expect(find.bySemanticsLabel(RegExp('1位、自分、30 XP')), findsOneWidget);
    expect(find.textContaining('昇格：ブロンズ → シルバー'), findsOneWidget);
    await scrollThrough(tester);
    semantics.dispose();
  });

  testWidgets('room削除後のreceiptを端末履歴へ確定し、再参加画面へ戻す', (tester) async {
    final store = MemorySessionStore();
    final dio = fakeDio({
      'POST $_baseUrl/v1/lan-social/join': () =>
          jsonRes(200, _membershipJson(LanSocialRoomKind.league)),
      'GET $_baseUrl/v1/lan-social/snapshot': () => jsonRes(401, '{}'),
      'GET $_baseUrl/v1/lan-social/settlement': () =>
          jsonRes(200, _leagueTerminalReceipt),
    });
    await tester.runAsync(
      () => prepareMembership(
        store: store,
        dio: dio,
        kind: LanSocialRoomKind.league,
      ),
    );

    await tester.pumpWidget(
      app(
        LanSocialScreen(
          store: store,
          schoolMode: false,
          lanSocialAllowed: true,
          clientFactory: (endpoint) =>
              LanSocialClient(endpoint: endpoint, store: store, dio: dio),
        ),
      ),
    );
    await pumpUntilFound(tester, find.text('週のリーグ1位を端末に保存しました。'));

    expect(find.text('週のリーグ1位を端末に保存しました。'), findsOneWidget);
    await pumpUntilFound(tester, find.byKey(const ValueKey('lan-social-join')));
    expect(find.byKey(const ValueKey('lan-social-join')), findsOneWidget);
    expect(await LanSocialClient.savedMemberships(store), isEmpty);
    final profile = await LanSocialClient(
      endpoint: _endpoint,
      store: store,
      dio: fakeDio({}),
    ).leagueProfile();
    expect(profile.currentTier, LanSocialLeagueTier.silver);
    expect(profile.history, hasLength(1));
  });

  testWidgets('部屋作成はadmin secretをコードへ混ぜず、入力後に端末UIから消す', (tester) async {
    final semantics = tester.ensureSemantics();
    compactLargeText(tester);
    final store = MemorySessionStore();
    final requests = <RequestOptions>[];
    const admin = 'ADMIN-SECRET-IS-SEPARATE-1234567890';
    final dio = fakeDio({
      'POST $_baseUrl/v1/lan-social/rooms': () => jsonRes(
        201,
        '{'
        '"protocolVersion":1,'
        '"roomId":"$_roomId",'
        '"kind":"league",'
        '"inviteCode":"$_invite",'
        '"capacity":8,'
        '"expiresAt":"2026-08-17T00:00:00.000Z",'
        '"weekStart":"2026-08-10"'
        '}',
      ),
    }, onRequest: requests.add);
    await tester.pumpWidget(
      app(
        LanSocialRoomCreateScreen(
          store: store,
          schoolMode: false,
          lanSocialAllowed: true,
          clientFactory: (endpoint) =>
              LanSocialClient(endpoint: endpoint, store: store, dio: dio),
        ),
      ),
    );

    final endpointField = find.byKey(const ValueKey('lan-social-endpoint'));
    await pumpUntilFound(tester, endpointField);
    await tester.enterText(endpointField, _baseUrl);
    final fingerprintField = find.byKey(
      const ValueKey('lan-social-fingerprint'),
    );
    await pumpUntilFound(tester, fingerprintField);
    await tester.enterText(fingerprintField, _pin);
    final adminField = find.byKey(const ValueKey('lan-social-coordinator-key'));
    await pumpUntilFound(tester, adminField);
    final adminController = tester.widget<TextField>(adminField).controller!;
    await tester.enterText(adminField, admin);
    tester.testTextInput.hide();
    await tester.pump();
    final league = find.byKey(const ValueKey('lan-social-kind-league'));
    await reveal(tester, league);
    await tester.tap(league);
    await tester.pump();
    final capacity = find.byKey(const ValueKey('lan-social-capacity-8'));
    await reveal(tester, capacity);
    await tester.tap(capacity);
    await tester.pump();
    final optIn = find.byKey(const ValueKey('lan-social-create-opt-in'));
    await reveal(tester, optIn);
    await tester.tap(optIn);
    await tester.pump();
    final create = find.byKey(const ValueKey('lan-social-create-room'));
    await reveal(tester, create);
    expect(tester.getSize(create).height, greaterThanOrEqualTo(48));
    await tester.tap(create);
    await tester.pumpAndSettle();

    final createdCode = find.byKey(const ValueKey('lan-social-created-code'));
    await pumpUntilFound(tester, createdCode);
    final codeWidget = tester.widget<SelectableText>(createdCode);
    final encoded = codeWidget.data!;
    final parsed = LanSocialConnectionCode.parse(encoded);
    expect(parsed.kind, LanSocialRoomKind.league);
    expect(parsed.endpoint.certificateSha256, _pin);
    expect(encoded.contains(admin), isFalse);
    final request = requests.single;
    expect(request.headers['X-Dekisugi-Coordinator-Key'], admin);
    expect(jsonEncode(request.data).contains(admin), isFalse);
    expect((request.data as Map).keys.toSet(), {
      'kind',
      'capacity',
      'createKey',
      'optIn',
      'consentVersion',
    });
    expect(adminController.text, isEmpty);
    expect(find.byKey(const ValueKey('participant-qr-code')), findsOneWidget);
    await scrollThrough(tester);
    semantics.dispose();
  });

  testWidgets('学校向け部屋作成にも個人league設定を出さない', (tester) async {
    await tester.pumpWidget(
      app(
        LanSocialRoomCreateScreen(
          store: MemorySessionStore(),
          schoolMode: true,
        ),
      ),
    );
    expect(find.byKey(const ValueKey('lan-social-kind-league')), findsNothing);
    expect(find.byKey(const ValueKey('lan-social-capacity-5')), findsNothing);
    expect(find.text('学校の端末内モードでは利用できません'), findsOneWidget);
    expect(find.byKey(const ValueKey('lan-social-create-room')), findsNothing);
  });
}
