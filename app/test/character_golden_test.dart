// キャラクターの4状態を1枚に並べて書き出す。
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
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (s, voice) in const [
                (LiveState.idle, 0.0),
                (LiveState.listening, 0.0),
                (LiveState.thinking, 0.0),
                (LiveState.speaking, 0.8),
              ])
                Character(state: s, voiceLevel: voice, size: 150),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final b in Brightness.values) {
    testWidgets('キャラクターの4状態 — $b', (tester) async {
      // 論理サイズ = physicalSize / devicePixelRatio。4体を1行に並べるので 640 要る
      tester.view.physicalSize = const Size(1280, 420);
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
