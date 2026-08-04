import 'dart:typed_data';

import 'package:dekisugi/services/mic_stream.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List ramp(int bytes, {int from = 0}) =>
    Uint8List.fromList(List.generate(bytes, (i) => (from + i) % 256));

/// PCM16 リトルエンディアンを組み立てる
Uint8List pcm(List<int> samples) {
  final b = ByteData(samples.length * 2);
  for (var i = 0; i < samples.length; i++) {
    b.setInt16(i * 2, samples[i], Endian.little);
  }
  return b.buffer.asUint8List();
}

void main() {
  group('PcmChunker', () {
    test('固定長に詰め直し、順序を崩さない', () {
      final c = PcmChunker(bytesPerChunk: 10);
      final got = <int>[];
      for (final piece in [ramp(3), ramp(3, from: 3), ramp(20, from: 6)]) {
        for (final chunk in c.add(piece)) {
          expect(chunk.length, 10);
          got.addAll(chunk);
        }
      }
      expect(got, equals(ramp(20).toList()));
      expect(c.flush(), equals(ramp(6, from: 20)));
    });

    test('1回の入力から複数チャンクを取り出せる', () {
      final c = PcmChunker(bytesPerChunk: 4);
      expect(c.add(ramp(14)).length, 3);
      expect(c.flush()!.length, 2);
    });

    test('足りないうちは何も出さない', () {
      final c = PcmChunker(bytesPerChunk: 100);
      expect(c.add(ramp(99)), isEmpty);
      expect(c.add(ramp(1, from: 99)).length, 1);
    });

    test('flush は端数を出し切り、16bit 境界を保つ', () {
      final c = PcmChunker(bytesPerChunk: 100);
      c.add(ramp(7)); // 奇数
      final tail = c.flush()!;
      expect(tail.length, 6, reason: '奇数バイトを残すと以降のサンプルが半分ずれる');
    });

    test('flush は2度目に null を返す', () {
      final c = PcmChunker(bytesPerChunk: 4);
      c.add(ramp(2));
      expect(c.flush(), isNotNull);
      expect(c.flush(), isNull);
    });

    test('返すチャンクは裏のバッファを共有しない', () {
      // ビューを返すと、受け手が .buffer を触ったとき無関係な領域まで掴む
      final c = PcmChunker(bytesPerChunk: 4);
      final chunk = c.add(ramp(12)).first;
      expect(chunk.buffer.lengthInBytes, 4);
    });

    test('reset で溜まりが消える', () {
      final c = PcmChunker(bytesPerChunk: 100);
      c.add(ramp(50));
      c.reset();
      expect(c.flush(), isNull);
    });
  });

  group('peakOf', () {
    test('無音は 0', () {
      expect(peakOf(pcm([0, 0, 0])), 0.0);
    });

    test('最大振幅は 1.0 を超えない', () {
      // -32768 の絶対値は 32768。32767 で割ると 1.0 を超える
      expect(peakOf(pcm([-32768])), lessThanOrEqualTo(1.0));
      expect(peakOf(pcm([32767])), lessThanOrEqualTo(1.0));
    });

    test('負の側のピークも拾う', () {
      expect(peakOf(pcm([0, -16384, 0])), closeTo(0.5, 0.001));
    });

    test('半端なバイト数でも落ちない', () {
      expect(peakOf(Uint8List.fromList([1])), 0.0);
      expect(peakOf(Uint8List(0)), 0.0);
    });
  });

  group('diagnose', () {
    test('ほぼ無音を silent と判定する', () {
      expect(diagnose([0.001, 0.0, 0.01]), RecordingIssue.silent);
    });

    test('小さい音を quiet と判定する', () {
      expect(diagnose([0.03, 0.05, 0.07]), RecordingIssue.quiet);
    });

    test('歪みを clipped と判定する', () {
      final peaks = List<double>.filled(100, 0.5);
      for (var i = 0; i < 10; i++) {
        peaks[i] = 1.0;
      }
      expect(diagnose(peaks), RecordingIssue.clipped);
    });

    test('歪みは無音判定より優先されない', () {
      // 全部 0 に近ければ silent。clipped の判定が先に出ると原因を取り違える
      expect(diagnose([0.0, 0.0]), RecordingIssue.silent);
    });

    test('正常なら null', () {
      expect(diagnose([0.1, 0.4, 0.6]), isNull);
    });

    test('空の入力では判定しない', () {
      expect(diagnose([]), isNull);
    });
  });

  group('定数', () {
    test('入力は 16kHz、チャンクは 100ms', () {
      expect(MicStream.sampleRate, 16000);
      expect(MicStream.chunkBytes, 3200);
    });
  });
}
