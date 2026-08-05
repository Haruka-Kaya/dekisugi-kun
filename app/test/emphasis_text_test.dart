import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/emphasis_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('splitEmphasis', () {
    test('強調が無ければそのまま1つ', () {
      final p = splitEmphasis('ふつうの文。');
      expect(p.length, 1);
      expect(p.first.strong, isFalse);
      expect(p.first.text, 'ふつうの文。');
    });

    test('囲みを切り出す', () {
      final p = splitEmphasis('これは**大事**です。');
      expect(p.map((e) => e.text).toList(), ['これは', '大事', 'です。']);
      expect(p.map((e) => e.strong).toList(), [false, true, false]);
    });

    test('複数あっても拾う', () {
      final p = splitEmphasis('**あ**と**い**');
      expect(p.where((e) => e.strong).map((e) => e.text).toList(), ['あ', 'い']);
    });

    test('先頭と末尾でも拾う', () {
      final p = splitEmphasis('**先頭**');
      expect(p.length, 1);
      expect(p.first.strong, isTrue);
      expect(p.first.text, '先頭');
    });

    test('閉じていない印は記号のまま残す', () {
      // 落とすと、書き間違えたときに文字が消えて気づけない
      const raw = 'これは**閉じていない';
      final p = splitEmphasis(raw);
      expect(p.map((e) => e.text).join(), raw);
      expect(p.every((e) => !e.strong), isTrue);
    });

    test('空の囲みは強調にしない', () {
      const raw = 'から****です';
      final p = splitEmphasis(raw);
      expect(p.map((e) => e.text).join(), raw);
    });

    test('文字を落とさない', () {
      const raw = 'ただし、これは**空気の抵抗を無視できるとき**の話です。';
      final p = splitEmphasis(raw);
      expect(p.map((e) => e.text).join(), raw.replaceAll('**', ''));
    });
  });

  group('EmphasisText', () {
    Widget wrap(String text) => MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: Scaffold(body: EmphasisText(text)),
        );

    testWidgets('画面に ** を出さない', (tester) async {
      // 解釈しないまま Text に渡すと記号がそのまま出た（実機で確認）
      await tester.pumpWidget(wrap('これは**大事**です。'));
      final widget = tester.widget<Text>(find.byType(Text));
      final shown = widget.textSpan?.toPlainText() ?? widget.data ?? '';
      expect(shown.contains('**'), isFalse);
      expect(shown, 'これは大事です。');
    });

    testWidgets('強調が無ければ素の Text にする', (tester) async {
      await tester.pumpWidget(wrap('ふつうの文。'));
      final widget = tester.widget<Text>(find.byType(Text));
      expect(widget.data, 'ふつうの文。');
      expect(widget.textSpan, isNull);
    });
  });
}
