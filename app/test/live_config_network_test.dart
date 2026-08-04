// 本番と同じ [LiveConfig] でサーバが接続を受け付けるかを確かめる通信テスト。
//
// なぜ要るか: Live API は設定の組み合わせを**接続後に**拒否する。
// スパイクでは gemini_live がそれを 10秒の TimeoutException として飲み込み、
// 実際の理由（1007: TEXT モダリティ非対応）が見えなかった。
// 設定をいじるたびにここを通せば、実機に持っていく前に落ちる。
//
// 実機は不要。ネットワークと APIキーだけ使う:
//   pwsh tools\test-live.ps1
//
// キーが無い環境では skip する（通常の flutter test を落とさないため）。

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dekisugi/config/live_config.dart';
import 'package:dekisugi/services/director_queue.dart';
import 'package:dekisugi/services/pcm_player.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gemini_live/gemini_live.dart';

String? _key() {
  final env = Platform.environment['GEMINI_API_KEY'];
  if (env != null && env.isNotEmpty) return env;
  for (final p in <String>[
    r'..\.env.local',
    r'C:\Users\kayah\jiyu-kenkyu-ai\.env.local',
  ]) {
    final f = File(p);
    if (!f.existsSync()) continue;
    final m =
        RegExp(r'GEMINI_API_KEY\s*=\s*(\S+)').firstMatch(f.readAsStringSync());
    if (m != null) return m.group(1)!.replaceAll(RegExp(r'''^["']|["']$'''), '');
  }
  return null;
}

/// 受け取った PCM をため込むだけの再生口。実機の音は鳴らさない。
class CountingSink implements PcmSink {
  int fedBytes = 0;
  void Function(int)? cb;

  @override
  Future<void> setLogLevel(LogLevel level) async {}
  @override
  Future<void> setup({required int sampleRate, required int channelCount}) async {}
  @override
  Future<void> setFeedThreshold(int frames) async {}
  @override
  void setFeedCallback(void Function(int)? c) => cb = c;
  @override
  void feed(PcmArrayInt16 buffer) => fedBytes += buffer.bytes.lengthInBytes;
  @override
  void start() => cb?.call(0);
  @override
  Future<void> release() async {}
}

void main() {
  final key = _key();

  test('本番の設定で接続でき、音声バイトが返る', () async {
    final genAI = GoogleGenAI(apiKey: key!);
    final sink = CountingSink();
    final player = PcmPlayer(sink: sink);
    await player.init();

    var audioBytes = 0;
    final transcript = StringBuffer();
    final done = Completer<void>();
    Object? failure;

    final session = await genAI.live.connect(LiveConfig.connectParameters(
      callbacks: LiveCallbacks(
        onMessage: (m) {
          final parts = m.serverContent?.modelTurn?.parts;
          if (parts != null) {
            for (final p in parts) {
              final b64 = p.inlineData?.data;
              if (b64 == null || b64.isEmpty) continue;
              final bytes = base64Decode(b64);
              audioBytes += bytes.length;
              player.enqueue(bytes); // 実際の再生経路に通す
            }
          }
          final t = m.serverContent?.outputTranscription?.text;
          if (t != null) transcript.write(t);
          if ((m.serverContent?.turnComplete ?? false) && !done.isCompleted) {
            done.complete();
          }
        },
        onError: (e, s) {
          failure ??= e;
          if (!done.isCompleted) done.complete();
        },
      ),
    ));

    // ディレクターの指示を、本番と同じ接頭辞・同じ送り方で送る。
    // **sendRealtimeText では音声が返らない**（このテストが存在する理由）
    final q = DirectorQueue()..add('会話を始めて。落下について教えてほしいと短く頼んで。');
    session.sendClientContent(
      turns: [Content(role: 'user', parts: [Part(text: q.takeIfQuiet(true)!)])],
      turnComplete: true,
    );

    await done.future.timeout(const Duration(seconds: 60));
    await session.close();

    final said = transcript.toString().trim();

    expect(failure, isNull, reason: '接続が拒否された: $failure');
    expect(audioBytes, greaterThan(0), reason: '音声が1バイトも返っていない');
    expect(said, isNotEmpty);

    // 製品の前提: ディレクターの指示を**読み上げない**。
    // 漏れると「内部の指示を音読する AI」になり、体験が成立しない
    for (final leak in ['DIRECTOR', '会話を始めて', '短く頼んで']) {
      expect(said.contains(leak), isFalse, reason: '指示が漏れている: "$leak" in "$said"');
    }
    // 後輩の発言として長すぎないこと（解説を始めていない）
    expect(said.length, lessThan(200), reason: '後輩の発言としては長すぎる: "$said"');

    // 再生待ちを実際に吐き出させ、経路がつながっていることまで見る
    while (player.hasPending) {
      sink.cb!(0);
    }
    expect(sink.fedBytes, audioBytes);

    stdout.writeln('\n発話: ${transcript.toString().trim()}');
    stdout.writeln('音声: $audioBytes バイト '
        '(${(audioBytes / 2 / PcmPlayer.sampleRate).toStringAsFixed(1)}秒)');

    await player.dispose();
  },
      timeout: const Timeout(Duration(minutes: 2)),
      skip: key == null ? 'GEMINI_API_KEY が無いので skip' : null);
}
