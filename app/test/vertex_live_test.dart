import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dekisugi/services/live_token_client.dart';
import 'package:dekisugi/services/vertex_live.dart';
import 'package:flutter_test/flutter_test.dart';

/// 本物の WebSocket を1本立てる。閉じ方の順序を再現したいので、
/// モックではなく実物を使う（この不具合は順序でしか出ない）。
class FakeLive {
  FakeLive(this._server, this.port);

  final HttpServer _server;
  final int port;
  final _sockets = <WebSocket>[];
  final _received = <Map<String, dynamic>>[];

  List<Map<String, dynamic>> get received => _received;

  static Future<FakeLive> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final live = FakeLive(server, server.port);
    unawaited(live._accept());
    return live;
  }

  Future<void> _accept() async {
    await for (final req in _server) {
      final ws = await WebSocketTransformer.upgrade(req);
      _sockets.add(ws);
      ws.listen((raw) {
        _received.add(jsonDecode(raw as String) as Map<String, dynamic>);
        ws.add(jsonEncode({'setupComplete': {}}));
      }, onError: (_) {});
    }
  }

  /// サーバ側から切る。**閉じる順序を作るためのもの。**
  Future<void> hangUp() async {
    for (final ws in _sockets) {
      await ws.close(1000, 'done');
    }
  }

  Future<void> dispose() async {
    await hangUp();
    await _server.close(force: true);
  }
}

LiveGrant grantFor(int port) => LiveGrant(
      token: 'test',
      wsUrl: 'ws://127.0.0.1:$port',
      model: 'projects/p/locations/l/publishers/google/models/m',
      setupConfig: const {'generationConfig': {}},
      expiresAt: DateTime.now().add(const Duration(minutes: 30)),
      sessionMinutes: 10,
      remainingSessions: 1,
      entitled: false,
      resetsAt: null,
    );

void main() {
  late FakeLive server;

  setUp(() async => server = await FakeLive.start());
  tearDown(() async => server.dispose());

  test('接続すると setup を1回だけ送る', () async {
    final s = await VertexLiveSession.connect(grantFor(server.port));
    await s.events.firstWhere((e) => e is LiveReady);

    expect(server.received.length, 1);
    final setup = server.received.first['setup'] as Map<String, dynamic>;
    expect(setup['model'], contains('publishers/google/models/m'));
    // サーバが返した設定をそのまま載せる
    expect(setup['generationConfig'], isNotNull);
    await s.close();
  });

  test('自分で閉じたあとにソケットが終了しても落ちない', () async {
    // 実機で出た不具合: close() でストリームを閉じたあとに
    // ソケットの onDone が届き、閉じたストリームへ書き込んで
    // `Bad state: Cannot add new events after calling close` になった。
    // 未処理例外なので、**本当の失敗理由がその陰に隠れる。**
    final s = await VertexLiveSession.connect(grantFor(server.port));
    await s.events.firstWhere((e) => e is LiveReady);

    final errors = <Object>[];
    await runZonedGuarded(() async {
      await s.close();
      await server.hangUp();
      // onDone が届くのを待つ
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }, (e, _) => errors.add(e));

    expect(errors, isEmpty);
    expect(s.isClosed, isTrue);
  });

  test('サーバから切られたら LiveClosed を1回だけ流して終わる', () async {
    final s = await VertexLiveSession.connect(grantFor(server.port));
    final seen = <LiveEvent>[];
    s.events.listen(seen.add);
    await s.events.firstWhere((e) => e is LiveReady);

    final errors = <Object>[];
    await runZonedGuarded(() async {
      await server.hangUp();
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }, (e, _) => errors.add(e));

    expect(errors, isEmpty);
    expect(seen.whereType<LiveClosed>().length, 1);
    expect(s.isClosed, isTrue);
  });

  test('閉じたあとは送らない', () async {
    final s = await VertexLiveSession.connect(grantFor(server.port));
    await s.events.firstWhere((e) => e is LiveReady);
    await s.close();

    // 例外を投げずに黙って捨てる
    s.beginSpeech();
    s.sendAudio(Uint8List.fromList([0, 0, 0, 0]));
    s.endSpeech();
    s.sendText('[DIRECTOR] 何か');

    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(server.received.length, 1); // setup だけ
  });

  test('activityStart の前の音声は送らない', () async {
    // Vertex は activityStart の外の音声を黙って捨てる。
    // 送っても無駄なだけでなく、送った気になるのが危ない
    final s = await VertexLiveSession.connect(grantFor(server.port));
    await s.events.firstWhere((e) => e is LiveReady);

    s.sendAudio(Uint8List.fromList([1, 2, 3, 4]));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(server.received.where((m) => m.containsKey('realtimeInput')), isEmpty);

    s.beginSpeech();
    s.sendAudio(Uint8List.fromList([1, 2, 3, 4]));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final sent = server.received.where((m) => m.containsKey('realtimeInput')).toList();
    expect(sent.length, 2); // activityStart と audio
    await s.close();
  });
}
