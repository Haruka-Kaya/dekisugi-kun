// キャラクターの8状態を160pxと72pxで1枚に並べて書き出す。
//
// 文字は `flutter test` ではダミーフォントになるが、**図形はそのまま描かれる**ので
// キャラクターの見た目はこれで確認できる（キャラに文字は無い）。
//
//   flutter test test/character_golden_test.dart --update-goldens
//
// 差分が出たら「デザインを変えたのか、壊したのか」を必ず判断すること。

import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/motion.dart';
import 'package:dekisugi/services/live_session.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/character.dart';
import 'package:flutter_test/flutter_test.dart';

Widget sheet(Brightness brightness) {
  final theme = buildAppTheme(brightness);
  return MaterialApp(
    theme: theme,
    debugShowCheckedModeBanner: false,
    home: ReduceMotionScope(
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 664,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final state in LiveState.values)
                      Character(
                        state: state,
                        voiceLevel: state == LiveState.speaking ? 0.8 : 0,
                        size: 160,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final state in LiveState.values) ...[
                    Character(
                      state: state,
                      voiceLevel: state == LiveState.speaking ? 0.8 : 0,
                      size: 72,
                    ),
                    if (state != LiveState.values.last)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final b in Brightness.values) {
    testWidgets('キャラクターの8状態 — $b', (tester) async {
      // 論理サイズ = physicalSize / devicePixelRatio。
      // 160pxを4体×2段、72pxを8体×1段で比較する。
      tester.view.physicalSize = const Size(1440, 960);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(sheet(b));
      await tester.pump(const Duration(milliseconds: 120));

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/character_${b.name}.png'),
      );

      // thinking の repeat() を止めてからテストを終える
      await tester.pumpWidget(const SizedBox());
    });
  }
}
