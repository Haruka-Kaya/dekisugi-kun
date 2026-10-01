import 'dart:async';
import 'dart:typed_data';

import 'package:dekisugi/services/vertex_live.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_live.dart';

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
    expect(
      server.received.where((m) => m.containsKey('realtimeInput')),
      isEmpty,
    );

    s.beginSpeech();
    s.sendAudio(Uint8List.fromList([1, 2, 3, 4]));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final sent = server.received
        .where((m) => m.containsKey('realtimeInput'))
        .toList();
    expect(sent.length, 2); // activityStart と audio
    await s.close();
  });
}
