import 'package:dekisugi/services/director_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DirectorQueue', () {
    test('喋っている間は出さない', () {
      // 生成中に注入するとモデルが進行中のターンを捨てる（jiyu-kenkyu-ai の実測）
      final q = DirectorQueue();
      q.add('誤概念を口にして');
      expect(q.takeIfQuiet(false), isNull);
      expect(q.hasPending, isTrue);
    });

    test('静かになったら接頭辞付きで出す', () {
      final q = DirectorQueue();
      q.add('誤概念を口にして');
      expect(q.takeIfQuiet(true), '[DIRECTOR] 誤概念を口にして');
      expect(q.hasPending, isFalse);
    });

    test('1回に1件しか出さない', () {
      // まとめて送るとモデルが1発話に混ぜ、誤概念の誘発と質問が同じターンに乗る
      final q = DirectorQueue();
      q.add('A');
      q.add('B');
      expect(q.takeIfQuiet(true), '[DIRECTOR] A');
      expect(q.pendingCount, 1);
    });

    test('溢れたら古い方を捨てる', () {
      // 進行の指示は鮮度がすべて。古い指示を後から実行させると会話が巻き戻る
      final q = DirectorQueue(maxPending: 2);
      expect(q.add('1'), isNull);
      expect(q.add('2'), isNull);
      expect(q.add('3'), '1', reason: '捨てたのが新しい方になっている');
      expect(q.takeIfQuiet(true), '[DIRECTOR] 2');
    });

    test('空文字は積まない', () {
      final q = DirectorQueue();
      q.add('');
      q.add('   ');
      expect(q.hasPending, isFalse);
    });

    test('前後の空白を落とす', () {
      final q = DirectorQueue();
      q.add('  誤概念  ');
      expect(q.takeIfQuiet(true), '[DIRECTOR] 誤概念');
    });

    test('空なら静かでも null', () {
      expect(DirectorQueue().takeIfQuiet(true), isNull);
    });

    test('clear で溜まりが消える', () {
      final q = DirectorQueue()..add('A');
      q.clear();
      expect(q.takeIfQuiet(true), isNull);
    });

    test('接頭辞はサーバの取り決めと一致している', () {
      // システム指示はサーバが一時トークンに焼き込むようになったので、
      // 突き合わせ先は `server/lib/live-config.ts` の DIRECTOR_PREFIX。
      // ここがずれると、モデルは指示をそのまま読み上げる。
      // **両方を1か所から生成する仕組みは無い**ので、値でしか縛れない
      expect(DirectorQueue().prefix, '[DIRECTOR]');
    });
  });
}
