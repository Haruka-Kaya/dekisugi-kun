import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/motion.dart';
import 'package:dekisugi/services/live_session.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/character.dart';
import 'package:dekisugi/widgets/dekisugi_character_art.dart';
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
      LiveState.outOfTime,
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
      await tester.pumpWidget(
        wrap(const Character(state: LiveState.listening)),
      );
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
        await tester.pumpWidget(wrap(Character(state: s), reduceMotion: true));
        expect(tickerEnabled(tester), isFalse, reason: '$s で動いている');
      }
    });

    testWidgets('動きを止めても描画は出る（消えない）', (tester) async {
      await tester.pumpWidget(
        wrap(const Character(state: LiveState.thinking), reduceMotion: true),
      );
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
      await tester.pumpWidget(
        wrap(const Character(state: LiveState.listening)),
      );
      await tester.pumpWidget(wrap(const SizedBox()));
      // まばたきの予約時間を越えて進める。残っていれば例外になる
      await tester.pump(Motion.blinkInterval * 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('固有キャラクターと静的ポーズ', () {
    const semanticsByState = <LiveState, String>{
      LiveState.idle: 'デキすぎ君が本を開いて、教わる準備をしています',
      LiveState.connecting: 'デキすぎ君がアンテナを上げて、接続を待っています',
      LiveState.listening: 'デキすぎ君が手を耳に添えて、聞いています',
      LiveState.thinking: 'デキすぎ君があごに手を添えて、考えています',
      LiveState.speaking: 'デキすぎ君が手を広げて、話しています',
      LiveState.done: 'デキすぎ君がノートを持って、完了を祝っています',
      LiveState.outOfTime: 'デキすぎ君が時計を持って、きょうの時間切れを知らせています',
      LiveState.failed: 'デキすぎ君が手を差し出して、再挑戦を案内しています',
    };

    testWidgets('8状態を目線・腕・持ち物の別ポーズとSemanticsへ固定する', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        for (final state in LiveState.values) {
          await tester.pumpWidget(wrap(Character(state: state)));
          expect(
            find.byKey(ValueKey<String>('character-pose-${state.name}')),
            findsOneWidget,
            reason: '$state の固有ポーズがない',
          );
          final art = tester.widget<DekisugiCharacterArt>(
            find.byType(DekisugiCharacterArt),
          );
          expect(art.pose, switch (state) {
            LiveState.idle => DekisugiCharacterPose.idle,
            LiveState.connecting => DekisugiCharacterPose.connecting,
            LiveState.listening => DekisugiCharacterPose.listening,
            LiveState.thinking => DekisugiCharacterPose.thinking,
            LiveState.speaking => DekisugiCharacterPose.speaking,
            LiveState.done => DekisugiCharacterPose.celebrate,
            LiveState.outOfTime => DekisugiCharacterPose.outOfTime,
            LiveState.failed => DekisugiCharacterPose.retry,
          });
          expect(art.decoration, DekisugiCharacterDecoration.standard);
          expect(
            find.bySemanticsLabel(semanticsByState[state]!),
            findsOneWidget,
            reason: '$state の形を読み上げで説明できない',
          );
        }
      } finally {
        await tester.pumpWidget(wrap(const Character(state: LiveState.idle)));
        semantics.dispose();
      }
    });

    for (final size in [72.0, 160.0]) {
      testWidgets('${size.toInt()}pxでもポーズの描画領域を欠かさない', (tester) async {
        await tester.pumpWidget(
          wrap(Character(state: LiveState.failed, size: size)),
        );
        expect(
          tester.getSize(find.byKey(const ValueKey('character-pose-failed'))),
          Size.square(size),
        );
      });
    }

    testWidgets('failedは罰、outOfTimeは失敗と読み上げず再挑戦と時計で分ける', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(wrap(const Character(state: LiveState.failed)));
        expect(find.bySemanticsLabel(RegExp('再挑戦')), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp('罰|だめ')), findsNothing);

        await tester.pumpWidget(
          wrap(const Character(state: LiveState.outOfTime)),
        );
        expect(find.bySemanticsLabel(RegExp('時計.*時間切れ')), findsOneWidget);
        expect(find.bySemanticsLabel(RegExp('失敗|罰|だめ')), findsNothing);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('親が操作ラベルを返すときは重複Semanticsを除外できる', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          wrap(
            const Character(
              state: LiveState.speaking,
              excludeFromSemantics: true,
            ),
          ),
        );
        expect(find.bySemanticsLabel(RegExp('デキすぎ君')), findsNothing);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('bitmap・shader・透過layerへ頼らずCustomPaintだけで描く', (tester) async {
      await tester.pumpWidget(wrap(const Character(state: LiveState.done)));
      expect(find.byType(Image), findsNothing);
      expect(find.byType(ShaderMask), findsNothing);
      expect(find.byType(Opacity), findsNothing);
      expect(find.byType(CustomPaint), findsWidgets);
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
      final duty =
          Motion.blink.inMilliseconds / Motion.blinkInterval.inMilliseconds;
      expect(duty, lessThan(0.05));
    });
  });
}
