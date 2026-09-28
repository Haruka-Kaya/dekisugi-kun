import 'package:dekisugi/services/speech_gate.dart';
import 'package:flutter_test/flutter_test.dart';

Duration ms(int v) => Duration(milliseconds: v);

void main() {
  group('SpeechGate', () {
    test('しきい値を超えたら即座に「喋っている」', () {
      final g = SpeechGate();
      expect(g.update(0.5, ms(0)), isTrue);
      expect(g.isSpeaking, isTrue);
    });

    group('AI が喋っている間は閉じる（半二重）', () {
      test('大きな音でも開かない', () {
        // この端末では AEC が効かず、AI の声を自分で拾って
        // 「内容をを」が生徒の発話として記録された（実機で確認）。
        // しきい値を上げるのでは分離できない — スピーカーは端末上、
        // 生徒は数十センチ先で、AI の声のほうが大きい
        final g = SpeechGate();
        expect(g.update(1.0, ms(0), muted: true), isFalse);
        expect(g.isSpeaking, isFalse);
      });

      test('喋っている途中で塞がれたら閉じたことを伝える', () {
        // 状態変化を返さないと activityEnd が送られず、
        // モデルは生徒の発話が続いていると思って待ち続ける
        final g = SpeechGate();
        g.update(0.5, ms(0));
        expect(g.isSpeaking, isTrue);

        expect(g.update(0.5, ms(100), muted: true), isTrue);
        expect(g.isSpeaking, isFalse);
      });

      test('塞がれ続けても変化は1回だけ', () {
        final g = SpeechGate();
        g.update(0.5, ms(0));
        expect(g.update(0.5, ms(100), muted: true), isTrue);
        expect(g.update(0.5, ms(200), muted: true), isFalse);
      });

      test('開いたら普通に判定に戻る', () {
        final g = SpeechGate();
        g.update(0.5, ms(0));
        g.update(0.5, ms(100), muted: true);
        expect(g.update(0.5, ms(200)), isTrue);
        expect(g.isSpeaking, isTrue);
      });
    });

    test('静かになっても hangover のあいだは終わらせない', () {
      // 句読点の「間」で切ると、説明の途中でキャラが反応してしまう
      final g = SpeechGate(hangover: ms(400));
      g.update(0.5, ms(0));

      // 静かになった最初のサンプル（t=100）から測るので、終わるのは t=500
      expect(g.update(0.0, ms(100)), isFalse);
      expect(g.update(0.0, ms(499)), isFalse);
      expect(g.isSpeaking, isTrue);

      expect(g.update(0.0, ms(500)), isTrue);
      expect(g.isSpeaking, isFalse);
    });

    test('途中で声が戻れば hangover を測り直す', () {
      final g = SpeechGate(hangover: ms(400));
      g.update(0.5, ms(0));
      g.update(0.0, ms(100)); // 静かになりかけ
      g.update(0.5, ms(200)); // 続きを喋った
      // 測り直していれば t=500 が起点になり、終わるのは t=900
      expect(g.update(0.0, ms(500)), isFalse);
      expect(g.update(0.0, ms(899)), isFalse, reason: '測り直せていない');
      expect(g.update(0.0, ms(900)), isTrue);
    });

    test('境界で振動しない（ヒステリシス）', () {
      // on と off が同じ値だと、境界付近の音量で状態が毎回変わって画面がちらつく
      final g = SpeechGate(onThreshold: 0.06, offThreshold: 0.03);
      g.update(0.07, ms(0));
      // on を下回っても off より上なら喋り続けている扱い
      expect(g.update(0.05, ms(100)), isFalse);
      expect(g.isSpeaking, isTrue);
    });

    test('小さい音では始まらない', () {
      final g = SpeechGate(onThreshold: 0.06);
      expect(g.update(0.05, ms(0)), isFalse);
      expect(g.isSpeaking, isFalse);
    });

    test('reset で初期状態に戻る', () {
      final g = SpeechGate();
      g.update(0.5, ms(0));
      g.reset();
      expect(g.isSpeaking, isFalse);
      expect(g.update(0.0, ms(10000)), isFalse, reason: 'reset 後に終了通知が出た');
    });

    test('しきい値が逆なら組み立て時に落とす', () {
      expect(
        () => SpeechGate(onThreshold: 0.01, offThreshold: 0.5),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
