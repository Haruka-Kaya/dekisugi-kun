import 'package:dekisugi/services/transcript_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tidyJa', () {
    test('和文の切れ目の空白を落とす', () {
      // 実機で出たそのままの文字起こし
      expect(tidyJa('最近 さあ 人間 関係 に 悩ん で て さ'), '最近さあ人間関係に悩んでてさ');
    });

    test('全角の空白も落とす', () {
      expect(tidyJa('重い　もの　の　方'), '重いものの方');
    });

    test('英単語の間の空白は残す', () {
      // 消すと別の語になる
      expect(tidyJa('free fall'), 'free fall');
    });

    test('数字は片側が和文なら詰める', () {
      // 英字の直後の空白は残る（「Newtonの」と繋げると別語に見える）
      expect(tidyJa('Newton の 第 1 法則'), 'Newton の第1法則');
      expect(tidyJa('10 個 と 5 個'), '10個と5個');
    });

    test('英数字どうしの空白は残す', () {
      expect(tidyJa('v = 9.8 m / s'), 'v = 9.8 m / s');
    });

    test('約物のまわりも詰める', () {
      expect(tidyJa('そう です か ？ わかり ました 。'), 'そうですか？わかりました。');
    });

    test('前後の空白を落とす', () {
      expect(tidyJa('  はい  '), 'はい');
    });

    test('空文字はそのまま', () {
      expect(tidyJa(''), '');
    });

    test('空白しかなければ空になる', () {
      expect(tidyJa('   '), '');
    });
  });

  group('challenge本文の正規化', () {
    test('日本語ASRの空白・句読点差だけを吸収する', () {
      expect(
        isExactChallengeText(
          'えっと じゃあ 重い もの の 方 が 速く 落ちる って こと?',
          'えっと、じゃあ重いものの方が速く落ちるってこと？',
        ),
        isTrue,
      );
    });

    test('英語の大小文字・約物差だけを吸収する', () {
      expect(
        isExactChallengeText(
          'WAIT - so heavier things fall faster right',
          'Wait — so heavier things fall faster, right?',
        ),
        isTrue,
      );
    });

    test('自然な前後付加や単語の省略は一致にしない', () {
      const lure = 'Wait — so heavier things fall faster, right?';
      expect(isExactChallengeText('Well, $lure', lure), isFalse);
      expect(
        isExactChallengeText('Wait — so things fall faster, right?', lure),
        isFalse,
      );
      expect(isExactChallengeText('', ''), isFalse);
    });
  });
}
