import 'dart:io';

import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/ui/adaptive.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

/// **「Android の移植」に見えないようにする。**
///
/// ただし iOS らしくするのではない。この製品のデザインは DESIGN.md の数値で
/// 組んであり、どちらの OS の流儀でもない。
///
/// 分けてよいのは **OS が作法を持っているものだけ**（日付・時刻・スイッチ・波紋）。
/// 色や角丸まで分けると「1つの製品」ではなく「2つの製品」になる。
void main() {
  tearDown(() => kDebugOverridePlatform = null);

  group('分けるのは作法だけ', () {
    test('色・余白・角丸はプラットフォームで変えない', () {
      // ここが分岐しはじめると、DESIGN.md の根拠が二重になり、
      // 片方だけ古くなる
      kDebugOverridePlatform = false;
      final android = buildAppTheme(Brightness.light);
      kDebugOverridePlatform = true;
      final ios = buildAppTheme(Brightness.light);

      expect(ios.colorScheme.primary, android.colorScheme.primary);
      expect(ios.colorScheme.surface, android.colorScheme.surface);
      expect(ios.cardTheme.shape, android.cardTheme.shape);
      expect(ios.cardTheme.color, android.cardTheme.color);
      expect(ios.appBarTheme.shape, android.appBarTheme.shape);
      expect(ios.textTheme.bodyMedium?.fontSize,
          android.textTheme.bodyMedium?.fontSize);
    });

    test('波紋だけは分ける（Android の署名なので）', () {
      kDebugOverridePlatform = false;
      expect(buildAppTheme(Brightness.light).splashFactory,
          isNot(NoSplash.splashFactory));

      kDebugOverridePlatform = true;
      expect(buildAppTheme(Brightness.light).splashFactory,
          NoSplash.splashFactory,
          reason: 'iOS で波紋が出ると、面をどれだけ中立にしても移植に見える');
    });

    test('影で階層を作らないのは両方共通', () {
      for (final apple in [true, false]) {
        kDebugOverridePlatform = apple;
        final t = buildAppTheme(Brightness.light);
        expect(t.cardTheme.elevation, 0);
        expect(t.appBarTheme.elevation, 0);
        expect(t.appBarTheme.scrolledUnderElevation, 0);
      }
    });
  });

  group('日付と時刻', () {
    Widget wrap(Widget child) => MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: Scaffold(body: child),
        );

    testWidgets('iOS ではホイール、Android ではカレンダー', (tester) async {
      // 丸い文字盤とカレンダーは Material 固有。
      // **実機の iPad で最も目立った Android の顔がこれだった**
      for (final apple in [true, false]) {
        kDebugOverridePlatform = apple;
        await tester.pumpWidget(wrap(Builder(
          builder: (ctx) => TextButton(
            onPressed: () => pickDate(
              ctx,
              initial: DateTime(2026, 8, 20),
              first: DateTime(2026, 8, 1),
              last: DateTime(2026, 12, 31),
              helpText: '次の定期考査はいつ？',
            ),
            child: const Text('open'),
          ),
        )));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.byType(CupertinoDatePicker), apple ? findsOneWidget : findsNothing,
            reason: 'apple=$apple');
        expect(find.byType(CalendarDatePicker), apple ? findsNothing : findsOneWidget,
            reason: 'apple=$apple');

        // 片づけ
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
      }
    });

    testWidgets('iOS のシートでも文言は日本語', (tester) async {
      kDebugOverridePlatform = true;
      await tester.pumpWidget(wrap(Builder(
        builder: (ctx) => TextButton(
          onPressed: () => pickHour(ctx, initial: 20, helpText: '何時に知らせますか'),
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('何時に知らせますか'), findsOneWidget);
      expect(find.text('やめる'), findsOneWidget);
      expect(find.text('決定'), findsOneWidget);
    });

    testWidgets('時刻は「時」だけ選ばせる', (tester) async {
      // 通知は1日1通で、分単位の精度に意味が無い。
      // 選ばせる幅を狭めるほど選ぶのが楽になる
      kDebugOverridePlatform = true;
      int? got;
      await tester.pumpWidget(wrap(Builder(
        builder: (ctx) => TextButton(
          onPressed: () async => got = await pickHour(ctx, initial: 20),
          child: const Text('open'),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('決定'));
      await tester.pumpAndSettle();

      expect(got, 20);
    });
  });

  group('OS の記号に合わせる部品', () {
    test('スイッチは adaptive を使う', () {
      // 形がそのまま OS の記号になっている
      final src = File('lib/screens/settings_screen.dart').readAsStringSync();
      expect(src.contains('SwitchListTile.adaptive'), isTrue);
      expect(RegExp(r'SwitchListTile\((?!\.)').hasMatch(src), isFalse,
          reason: '素の SwitchListTile が残っている');
    });

    test('Material の日付・時刻を直接呼んでいる画面が無い', () {
      // 呼び出しを1か所（ui/adaptive.dart）に閉じる。
      // 画面から直接呼ぶと、片方の画面だけ Android の顔が残る
      for (final f in Directory('lib/screens').listSync().whereType<File>()) {
        final src = f.readAsStringSync();
        for (final call in ['showDatePicker(', 'showTimePicker(']) {
          expect(src.contains(call), isFalse,
              reason: '${f.path} が $call を直接呼んでいる。pickDate/pickHour を使う');
        }
      }
    });
  });
}
