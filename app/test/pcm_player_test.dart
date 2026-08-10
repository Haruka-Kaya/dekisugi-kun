import 'dart:typed_data';

import 'package:dekisugi/services/pcm_player.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:flutter_test/flutter_test.dart';

/// native を差し替えた偽の再生口。渡されたバイト列をそのまま記録する。
class FakeSink implements PcmSink {
  final List<Uint8List> fed = [];
  void Function(int)? _cb;
  bool released = false;
  int startCalls = 0;
  int? setupSampleRate;

  /// native がキューを消化して補充を求めた、という状況を作る。
  void requestFeed([int remaining = 0]) => _cb?.call(remaining);

  Uint8List get allFed {
    final total = fed.fold<int>(0, (a, b) => a + b.length);
    final out = Uint8List(total);
    var i = 0;
    for (final f in fed) {
      out.setRange(i, i + f.length, f);
      i += f.length;
    }
    return out;
  }

  @override
  Future<void> setLogLevel(LogLevel level) async {}
  @override
  Future<void> setup({
    required int sampleRate,
    required int channelCount,
  }) async {
    setupSampleRate = sampleRate;
  }

  @override
  Future<void> setFeedThreshold(int frames) async {}
  @override
  void setFeedCallback(void Function(int)? cb) => _cb = cb;
  @override
  void feed(PcmArrayInt16 buffer) =>
      fed.add(Uint8List.fromList(buffer.bytes.buffer.asUint8List()));
  @override
  void start() => startCalls++;
  @override
  Future<void> release() async => released = true;
}

/// 0,1,2,... と続く検証しやすい PCM を作る
Uint8List ramp(int bytes, {int from = 0}) =>
    Uint8List.fromList(List.generate(bytes, (i) => (from + i) % 256));

void main() {
  late FakeSink sink;
  late PcmPlayer player;

  setUp(() async {
    sink = FakeSink();
    player = PcmPlayer(sink: sink);
    await player.init();
  });

  group('再生待ちの受け渡し', () {
    test('既定はLive用24kHz、指定時はマイク用16kHzでnativeを初期化する', () async {
      expect(sink.setupSampleRate, PcmPlayer.sampleRate);

      final localSink = FakeSink();
      final local = PcmPlayer(sink: localSink, playbackSampleRate: 16000);
      await local.init();

      expect(localSink.setupSampleRate, 16000);
      expect(local.configuredMaxResidual.inMilliseconds, 100);
      await local.dispose();
    });

    test('積んだ順にバイトの並びを崩さず渡す', () {
      // チャンク境界をまたいで詰め直すので、順序が壊れやすい箇所
      player.enqueue(ramp(100));
      player.enqueue(ramp(100, from: 100));
      player.enqueue(ramp(56, from: 200));

      while (player.hasPending) {
        sink.requestFeed();
      }

      expect(sink.allFed, equals(ramp(256)));
    });

    test('1回に渡す量を制限する（全部は渡さない）', () {
      // 割り込みを効かせるには native に貯めさせないことが要。
      // 10秒ぶんを積んでも1回で全部渡ってはいけない
      player.enqueue(ramp(PcmPlayer.sampleRate * 2 * 10));
      sink.requestFeed();

      expect(sink.fed.length, 1);
      expect(sink.fed.first.length, lessThan(PcmPlayer.sampleRate * 2 * 10));
      expect(player.hasPending, isTrue);
    });

    test('16bit の境界を守る（奇数バイトは切り捨てる）', () {
      player.enqueue(ramp(101));
      expect(player.pendingBytes.isEven, isTrue);
      expect(player.pendingBytes, 100);
    });

    test('空の要求では feed しない', () {
      sink.requestFeed();
      expect(sink.fed, isEmpty);
    });

    test('積むたびに start() を掛ける（native は feed されるまで動かない）', () {
      player.enqueue(ramp(10));
      player.enqueue(ramp(10));
      expect(sink.startCalls, 2);
    });
  });

  group('割り込み', () {
    test('stopNow で再生待ちが消える', () {
      player.enqueue(ramp(PcmPlayer.sampleRate * 2 * 5)); // 5秒ぶん
      expect(player.hasPending, isTrue);

      player.stopNow();

      expect(player.pendingBytes, 0);
      sink.requestFeed();
      expect(sink.fed, isEmpty, reason: '捨てたはずの音が native に渡っている');
    });

    test('鳴り残りは 100ms 以内に収まる', () {
      // これが割り込みの体感を決める。native に渡した量の上限を数値で縛る
      player.enqueue(ramp(PcmPlayer.sampleRate * 2 * 5));

      // 最悪ケース: 補充直後に割り込まれる
      sink.requestFeed();
      player.stopNow();

      final residualBytes = sink.allFed.length;
      final residual = Duration(
        microseconds: (residualBytes / 2 * 1000000 / PcmPlayer.sampleRate)
            .round(),
      );
      expect(residual, lessThanOrEqualTo(PcmPlayer.maxResidual));
      expect(PcmPlayer.maxResidual.inMilliseconds, lessThanOrEqualTo(100));
    });

    test('割り込んだあとも再生を再開できる', () {
      player.enqueue(ramp(1000));
      player.stopNow();
      player.enqueue(ramp(40, from: 7));

      while (player.hasPending) {
        sink.requestFeed();
      }
      expect(sink.allFed, equals(ramp(40, from: 7)));
    });
  });

  group('声の大きさ', () {
    /// PCM16 リトルエンディアンを組み立てる
    Uint8List pcm(List<int> samples) {
      final b = ByteData(samples.length * 2);
      for (var i = 0; i < samples.length; i++) {
        b.setInt16(i * 2, samples[i], Endian.little);
      }
      return b.buffer.asUint8List();
    }

    test('渡した音の大きさを流す', () async {
      final seen = <double>[];
      final sub = player.level.listen(seen.add);

      player.enqueue(pcm(List.filled(1200, 16384)));
      sink.requestFeed();
      await Future<void>.delayed(Duration.zero);

      expect(seen, isNotEmpty);
      expect(seen.first, closeTo(0.5, 0.01));
      await sub.cancel();
    });

    test('鳴り終わったら 0 を流す', () async {
      final seen = <double>[];
      final sub = player.level.listen(seen.add);

      sink.requestFeed(); // 渡すものが無い
      await Future<void>.delayed(Duration.zero);

      expect(seen, [0.0]);
      await sub.cancel();
    });

    test('割り込んだ瞬間に 0 を流す', () async {
      // 伝えないと、割り込んだのにキャラが揺れ続ける
      final seen = <double>[];
      final sub = player.level.listen(seen.add);

      player.enqueue(pcm(List.filled(2400, 30000)));
      sink.requestFeed();
      player.stopNow();
      await Future<void>.delayed(Duration.zero);

      expect(seen.last, 0.0);
      await sub.cancel();
    });

    test('最大振幅でも 1.0 を超えない', () async {
      final seen = <double>[];
      final sub = player.level.listen(seen.add);

      player.enqueue(pcm(List.filled(1200, -32768)));
      sink.requestFeed();
      await Future<void>.delayed(Duration.zero);

      expect(seen.first, lessThanOrEqualTo(1.0));
      await sub.cancel();
    });
  });

  group('後始末', () {
    test('dispose 後は積んでも渡さない', () async {
      await player.dispose();
      player.enqueue(ramp(100));
      sink.requestFeed();

      expect(sink.released, isTrue);
      expect(sink.fed, isEmpty);
      expect(player.hasPending, isFalse);
    });

    test('dispose は二重に呼んでも壊れない', () async {
      await player.dispose();
      await player.dispose();
      expect(sink.released, isTrue);
    });
  });
}
