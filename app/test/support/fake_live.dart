import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dekisugi/services/live_token_client.dart';

/// 本物の WebSocket を1本立てて、Vertex Live のふりをする。
///
/// **モックにしない。** 閉じる順序やフレームの往復でしか出ない不具合が
/// あるので（`Bad state: Cannot add new events after calling close` は
/// 実機でしか出なかった）、実物を通す。
class FakeLive {
  FakeLive(this._server, this.port);

  final HttpServer _server;
  final int port;
  final _sockets = <WebSocket>[];
  final _received = <Map<String, dynamic>>[];

  /// 端末から届いたメッセージ。**送っていないことの確認**にも使う。
  List<Map<String, dynamic>> get received => _received;

  /// `realtimeInput` のうち音声を含むものだけ。
  List<Map<String, dynamic>> get audioFrames => _received
      .where((m) => (m['realtimeInput'] as Map?)?.containsKey('audio') == true)
      .toList();

  bool get sawActivityStart => _received.any(
    (m) => (m['realtimeInput'] as Map?)?.containsKey('activityStart') == true,
  );
  bool get sawActivityEnd => _received.any(
    (m) => (m['realtimeInput'] as Map?)?.containsKey('activityEnd') == true,
  );

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
      ws.listen(
        (raw) {
          final m = jsonDecode(raw as String) as Map<String, dynamic>;
          _received.add(m);
          // A buffered setup frame can arrive after hangUp has closed this
          // socket. Match say's open-state guard before acknowledging it.
          if (m.containsKey('setup') && ws.readyState == WebSocket.open) {
            ws.add(jsonEncode({'setupComplete': {}}));
          }
          // **閉じたソケットを溜めない。** 繋ぎ直しを何度も試すテストで、
          // 古いソケットに書こうとして StreamSink is closed で落ちる
        },
        onError: (_) {},
        onDone: () => _sockets.remove(ws),
      );
    }
  }

  /// サーバから何か言わせる。開いているものにだけ。
  void say(Map<String, dynamic> message) {
    for (final ws in [..._sockets]) {
      if (ws.readyState != WebSocket.open) {
        _sockets.remove(ws);
        continue;
      }
      ws.add(jsonEncode(message));
    }
  }

  /// サーバ側から切る。**閉じる順序を作るためのもの。**
  ///
  /// Vertex がセッション上限で切るとき（実測 `code=1000`）の再現にも使う。
  Future<void> hangUp() async {
    for (final ws in [..._sockets]) {
      await ws.close(1000, 'done');
    }
    _sockets.clear();
  }

  Future<void> dispose() async {
    await hangUp();
    await _server.close(force: true);
  }
}

LiveGrant grantFor(int port, {String directorPrefix = '[D:test]'}) => LiveGrant(
  directorPrefix: directorPrefix,
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
