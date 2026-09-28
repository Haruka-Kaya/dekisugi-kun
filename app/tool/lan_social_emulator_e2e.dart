/// Opt-in Android-emulator E2E probe for the LAN social protocol.
///
/// This is intentionally not part of the ordinary test suite: it requires a
/// locally running coordinator and uses the Android TLS stack against
/// `10.0.2.2`.  It exercises the same `LanSocialClient` used by the app.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dekisugi/models/lan_social.dart';
import 'package:dekisugi/services/lan_social_client.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:flutter/material.dart';

const _mode = String.fromEnvironment('LAN_E2E_MODE');
const _endpoint = String.fromEnvironment('LAN_E2E_ENDPOINT');
const _fingerprint = String.fromEnvironment('LAN_E2E_FINGERPRINT');
const _coordinatorKey = String.fromEnvironment('LAN_E2E_COORDINATOR_KEY');
const _connectionCode = String.fromEnvironment('LAN_E2E_CONNECTION_CODE');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(home: _ProbePage()));
  unawaited(_run());
}

Future<void> _run() async {
  try {
    switch (_mode) {
      case 'friends_creator':
        await _createAndJoinFriends();
      case 'friends_participant':
        await _joinFriendsFromCode();
      case 'league_five':
        await _createAndJoinLeague();
      default:
        throw ArgumentError('LAN_E2E_MODE is required');
    }
    _ProbeState.value.value = 'PASS $_mode';
    // The marker is parsed by the host runner; it deliberately contains no
    // credential or coordinator key.
    // ignore: avoid_print
    print('LAN_EMULATOR_E2E_PASS mode=$_mode');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    exit(0);
  } catch (error, stackTrace) {
    _ProbeState.value.value = 'FAIL $_mode: $error';
    // ignore: avoid_print
    print('LAN_EMULATOR_E2E_FAIL mode=$_mode error=$error\n$stackTrace');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    exit(1);
  }
}

LanSocialEndpoint _configuredEndpoint() {
  if (_endpoint.isEmpty || _fingerprint.isEmpty) {
    throw ArgumentError('LAN_E2E_ENDPOINT and LAN_E2E_FINGERPRINT are required');
  }
  return LanSocialEndpoint(
    baseUrl: _endpoint,
    certificateSha256: _fingerprint,
  );
}

Future<void> _createAndJoinFriends() async {
  final store = MemorySessionStore();
  final client = LanSocialClient(endpoint: _configuredEndpoint(), store: store);
  final room = await client.createRoom(
    kind: LanSocialRoomKind.friends,
    capacity: 2,
    coordinatorKey: _coordinatorKey,
    explicitOptIn: true,
  );
  if (room == null) throw StateError('friends room was not created');
  final code = client.connectionCodeFor(room);
  final joined = await client.join(code, explicitOptIn: true);
  if (!joined.joined) throw StateError('creator could not join: ${joined.error}');
  final snapshot = await client.snapshot(LanSocialRoomKind.friends);
  if (snapshot is! LanSocialFriendsSnapshot || snapshot.partnerJoined) {
    throw StateError('friends room did not begin in one-participant state');
  }
  // The code carries only endpoint, certificate pin, invite, and kind.
  // ignore: avoid_print
  print('LAN_EMULATOR_E2E_CONNECTION_CODE=${code.encode()}');
}

Future<void> _joinFriendsFromCode() async {
  final code = LanSocialConnectionCode.parse(_connectionCode);
  await _probePinnedHealth(code.endpoint);
  final client = LanSocialClient(
    endpoint: code.endpoint,
    store: MemorySessionStore(),
  );
  final joined = await client.join(code, explicitOptIn: true);
  if (!joined.joined) throw StateError('participant could not join: ${joined.error}');
  final snapshot = await client.snapshot(LanSocialRoomKind.friends);
  if (snapshot is! LanSocialFriendsSnapshot || !snapshot.partnerJoined) {
    throw StateError('friends room did not become active');
  }
  await client.leave(LanSocialRoomKind.friends);
}

Future<void> _probePinnedHealth(LanSocialEndpoint endpoint) async {
  final http = HttpClient(context: SecurityContext(withTrustedRoots: false));
  http.badCertificateCallback = (certificate, host, port) =>
      sha256.convert(certificate.der).toString() == endpoint.certificateSha256;
  try {
    final request = await http.getUrl(
      Uri.parse('${endpoint.baseUrl}/v1/lan-social/health'),
    );
    final response = await request.close();
    final body = await response.transform(const Utf8Decoder()).join();
    // ignore: avoid_print
    print('LAN_EMULATOR_E2E_HEALTH status=${response.statusCode} body=$body');
  } finally {
    http.close(force: true);
  }
}

Future<void> _createAndJoinLeague() async {
  final endpoint = _configuredEndpoint();
  final owner = LanSocialClient(endpoint: endpoint, store: MemorySessionStore());
  final room = await owner.createRoom(
    kind: LanSocialRoomKind.league,
    capacity: 5,
    coordinatorKey: _coordinatorKey,
    explicitOptIn: true,
  );
  if (room == null) throw StateError('league room was not created');
  final code = owner.connectionCodeFor(room);
  final clients = List<LanSocialClient>.generate(
    5,
    (_) => LanSocialClient(endpoint: endpoint, store: MemorySessionStore()),
  );
  for (final client in clients) {
    final joined = await client.join(code, explicitOptIn: true);
    if (!joined.joined) throw StateError('league participant could not join');
  }
  final snapshot = await clients.first.snapshot(LanSocialRoomKind.league);
  if (snapshot is! LanSocialLeagueSnapshot ||
      !snapshot.privacyThresholdReached ||
      snapshot.standings.length != 5) {
    throw StateError('league privacy threshold was not reached');
  }
  for (final client in clients) {
    await client.leave(LanSocialRoomKind.league);
  }
}

class _ProbeState {
  static final ValueNotifier<String> value = ValueNotifier<String>('running');
}

class _ProbePage extends StatelessWidget {
  const _ProbePage();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ValueListenableBuilder<String>(
        valueListenable: _ProbeState.value,
        builder: (context, value, child) => Text(value),
      ),
    ),
  );
}
