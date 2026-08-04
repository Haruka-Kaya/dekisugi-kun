import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/motion.dart';
import 'package:dekisugi/services/live_session.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/character.dart';
import 'package:flutter_test/flutter_test.dart';

/// キャラは AppColors（ThemeExtension）から色を取るので、テーマが要る
Widget wrap(Widget child, {bool reduceMotion = false}) => MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: ReduceMotionScope(child: Center(child: child)),
      ),
    );

/// キャラのサブツリーでティッカーが動いているか。
///
/// MaterialApp 自身も TickerMode を差し込むので、**Character の中のものだけ**を見る。
bool tickerEnabled(WidgetTester tester) {
  final finder = find.descendant(
    of: find.byType(Character),
    matching: find.byType(TickerMode),
  );
  return tester.widget<TickerMode>(finder).enabled;
}

void main() {
  group('待機中は動かさない', () {
    // 実測で、毎フレーム描き続けると1コアの71〜91%を食う。
    // fps を落としても効かない（Rive は約61%がフレーム非依存）。効くのは止めることだけ。
    for (final s in [
      LiveState.idle,
      LiveState.connecting,
      LiveState.done,
      LiveState.failed,
    ]) {
      testWidgets('$s ではティッカーを止める', (tester) async {
        await tester.pumpWidget(wrap(Character(state: s)));
        expect(tickerEnabled(tester), isFalse);
      });
    }

    testWidgets('話しているときもティッカーは要らない（声の大きさで描くだけ）', (tester) async {
      await tester.pumpWidget(wrap(const Character(state: LiveState.speaking)));
      expect(tickerEnabled(tester), isFalse);
    });

    testWidgets('聞いている・考えているときだけ動かす', (tester) async {
      await tester.pumpWidget(wrap(const Character(state: LiveState.listening)));
      expect(tickerEnabled(tester), isTrue);

      await tester.pumpWidget(wrap(const Character(state: LiveState.thinking)));
      expect(tickerEnabled(tester), isTrue);
      // repeat() を止めてからテストを終える
      await tester.pumpWidget(wrap(const Character(state: LiveState.idle)));
    });
  });

  group('Reduce Motion', () {
    testWidgets('設定されていればどの状態でも動かさない', (tester) async {
      for (final s in [LiveState.listening, LiveState.thinking]) {
        await tester.pumpWidget(
            wrap(Character(state: s), reduceMotion: true));
        expect(tickerEnabled(tester), isFalse, reason: '$s で動いている');
      }
    });

    testWidgets('動きを止めても描画は出る（消えない）', (tester) async {
      await tester.pumpWidget(
          wrap(const Character(state: LiveState.thinking), reduceMotion: true));
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('状態の切り替え', () {
    testWidgets('連続で切り替えても落ちない', (tester) async {
      for (final s in LiveState.values) {
        await tester.pumpWidget(wrap(Character(state: s)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpWidget(wrap(const Character(state: LiveState.idle)));
      expect(tester.takeException(), isNull);
    });

    testWidgets('破棄してもタイマーが残らない', (tester) async {
      await tester.pumpWidget(wrap(const Character(state: LiveState.listening)));
      await tester.pumpWidget(wrap(const SizedBox()));
      // まばたきの予約時間を越えて進める。残っていれば例外になる
      await tester.pump(Motion.blinkInterval * 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('Motion のトークン', () {
    test('M3 の定数をそのまま使う（数値を自作しない）', () {
      expect(Motion.quick, Durations.short2);
      expect(Motion.state, Durations.medium2);
      expect(Motion.celebrate, Durations.long2);
      expect(Motion.blink, Durations.short3);
    });

    test('達成は emphasizedDecelerate、繰り返し操作は standard', () {
      // emphasizedDecelerate は仕様上「画面内に入ってくる要素」用
      expect(Motion.celebrateCurve, Easing.emphasizedDecelerate);
      expect(Motion.quickCurve, Easing.standard);
    });

    test('まばたきの稼働率が 5% 未満', () {
      // ここが待機中の CPU を決める。上げると常時アニメと同じ問題になる
      final duty = Motion.blink.inMilliseconds / Motion.blinkInterval.inMilliseconds;
      expect(duty, lessThan(0.05));
    });
  });
}
