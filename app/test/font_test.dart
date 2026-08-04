import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// 同梱フォントまわりの検証。
///
/// **描画結果は `flutter test` では検証できない。**
/// テスト環境は全フォントを固定幅のダミーに潰すので、実在しない family を
/// 指定しても w400 でも w900 でも同じ幅（実測 528.0px）が返る。
/// したがってここで確かめられるのは「アセットが存在するか」と
/// 「スタイルに軸の値が刻まれているか」まで。
/// **グリフが本当に太っているかは実機で目視する**（段階3のチェック項目）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('和文フォントがアセットとして同梱されている', () async {
    final data = await rootBundle.load('assets/fonts/NotoSansJP-Variable.ttf');
    // 取り違え防止。可変フォント1本なので数MB規模になるはず
    expect(data.lengthInBytes, greaterThan(1 << 20));
  });

  test('ライセンス (SIL OFL) を同梱している', () async {
    final ofl = await rootBundle.loadString('assets/fonts/OFL.txt');
    expect(ofl, contains('SIL OPEN FONT LICENSE'));
  });

  group('可変フォントのウェイト軸', () {
    test('jaWeight は fontWeight と wght 軸を必ず揃える', () {
      final s = const TextStyle().jaWeight(FontWeight.w700);
      expect(s.fontWeight, FontWeight.w700);
      expect(s.fontVariations, contains(const FontVariation('wght', 700)));
    });

    for (final brightness in Brightness.values) {
      test('$brightness のテーマの全スタイルに軸が刻まれている', () {
        final t = buildAppTheme(brightness).textTheme;
        final styles = <String, TextStyle?>{
          'displayLarge': t.displayLarge, 'displayMedium': t.displayMedium,
          'displaySmall': t.displaySmall, 'headlineLarge': t.headlineLarge,
          'headlineMedium': t.headlineMedium, 'headlineSmall': t.headlineSmall,
          'titleLarge': t.titleLarge, 'titleMedium': t.titleMedium,
          'titleSmall': t.titleSmall, 'bodyLarge': t.bodyLarge,
          'bodyMedium': t.bodyMedium, 'bodySmall': t.bodySmall,
          'labelLarge': t.labelLarge, 'labelMedium': t.labelMedium,
          'labelSmall': t.labelSmall,
        };

        for (final e in styles.entries) {
          final s = e.value;
          expect(s, isNotNull, reason: '${e.key} が欠けている');
          expect(s!.fontFamily, kFontFamily, reason: '${e.key} が同梱フォントでない');

          final axis = s.fontVariations
              ?.firstWhere((v) => v.axis == 'wght',
                  orElse: () => const FontVariation('wght', -1))
              .value;
          expect(axis, isNotNull, reason: '${e.key} に fontVariations が無い');
          // 軸の値が fontWeight とずれると、見た目と指定が食い違う
          expect(axis, (s.fontWeight ?? FontWeight.w400).value.toDouble(),
              reason: '${e.key} の wght 軸が fontWeight と一致しない');
        }
      });
    }
  });

  test('テーマの本文スタイルが同梱フォントと明示行高を持つ', () {
    final body = buildAppTheme(Brightness.light).textTheme.bodyMedium!;
    expect(body.fontFamily, kFontFamily);
    expect(body.height, kBodyLineHeight);
    // M3 の既定 1.43 のまま残っていたら和文の行間が足りていない
    expect(body.height, greaterThan(1.43));
  });
}
