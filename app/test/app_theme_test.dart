import 'dart:math' as math;

import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/status_chip.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.x の相対輝度。sRGB の各チャンネルを線形化してから重み付けする。
double _luminance(Color c) {
  double lin(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('AppColors のコントラスト', () {
    // 「検証済み」をコメントで書くと、色を変えたときに嘘になる。
    // 基準そのものをテストにして、割ったらビルドを落とす。
    for (final (name, brightness) in [
      ('ライト', Brightness.light),
      ('ダーク', Brightness.dark),
    ]) {
      group(name, () {
        final theme = buildAppTheme(brightness);
        final c = theme.extension<AppColors>()!;
        final scheme = theme.colorScheme;

        for (final s in ExplainStatus.values) {
          test('$s の前景はチップ上で 4.5:1 以上', () {
            expect(_contrast(c.fgFor(s), c.chipFor(s)),
                greaterThanOrEqualTo(4.5));
          });

          test('$s の前景はページ背景の上でも 4.5:1 以上', () {
            // チップを外して地の上に置く使い方をしても読めること
            expect(_contrast(c.fgFor(s), scheme.surface),
                greaterThanOrEqualTo(4.5));
          });
        }

        test('キャラの目は体の上で 3:1 以上 (SC 1.4.11)', () {
          // 目は装飾ではなく状態を伝える図形。まばたきも表情も読めなくなる
          expect(_contrast(c.charFace, c.charBody), greaterThanOrEqualTo(3.0));
        });

        test('キャラの装飾は体の上で 3:1 以上', () {
          // 耳・声のバー・考え中の点は**状態を伝える唯一の形**なので、
          // 見えないと4状態が区別できなくなる
          expect(_contrast(c.charAccent, c.charBody), greaterThanOrEqualTo(3.0));
        });

        test('キャラの体は背景から浮く（1.5:1 以上）', () {
          expect(_contrast(c.charBody, scheme.surface), greaterThanOrEqualTo(1.5));
        });

        test('キャラの色が状態色と重ならない', () {
          // 重なると「キャラの色」と「理解の状態」の意味が混ざる
          for (final s in ExplainStatus.values) {
            expect(c.charBody, isNot(c.fgFor(s)));
            expect(c.charAccent, isNot(c.fgFor(s)));
          }
        });

        test('borderStrong は操作対象の枠として 3:1 以上 (SC 1.4.11)', () {
          // 入力欄の枠。ライトは地の白、ダークはカード面に対して測る
          final bg = brightness == Brightness.light
              ? scheme.surface
              : scheme.surfaceContainerLow;
          expect(_contrast(c.borderStrong, bg), greaterThanOrEqualTo(3.0));
        });

        test('本文色は背景に対し 4.5:1 以上', () {
          expect(_contrast(scheme.onSurface, scheme.surface),
              greaterThanOrEqualTo(4.5));
          expect(_contrast(scheme.onSurfaceVariant, scheme.surface),
              greaterThanOrEqualTo(4.5));
        });
      });
    }
  });

  group('ExplainStatus の写像', () {
    test('4状態すべてにアイコンとラベルがあり、重複しない', () {
      final icons = ExplainStatus.values.map(statusIcon).toSet();
      final labels = ExplainStatus.values.map(statusLabel).toSet();
      expect(icons.length, ExplainStatus.values.length);
      expect(labels.length, ExplainStatus.values.length);
    });

    test('weak に否定的な記号を使わない', () {
      // ✗ や ! は「失敗した」という枠組みを持ち込む。
      // デキすぎ君では説明できないことが日常なので、そう見せない (C9)。
      // IconData は == を上書きしているので const set にはできない
      final forbidden = <IconData>{
        Icons.close,
        Icons.cancel,
        Icons.error,
        Icons.warning,
        Icons.priority_high,
      };
      expect(forbidden.contains(statusIcon(ExplainStatus.weak)), isFalse);
    });
  });

  group('StatusChip', () {
    testWidgets('色だけでなくアイコンとラベルを必ず出す (SC 1.4.1)', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const Scaffold(
          body: Row(
            children: [
              StatusChip(status: ExplainStatus.gotIt),
              StatusChip(status: ExplainStatus.weak),
            ],
          ),
        ),
      ));

      expect(find.text(statusLabel(ExplainStatus.gotIt)), findsOneWidget);
      expect(find.text(statusLabel(ExplainStatus.weak)), findsOneWidget);
      expect(find.byIcon(statusIcon(ExplainStatus.gotIt)), findsOneWidget);
      expect(find.byIcon(statusIcon(ExplainStatus.weak)), findsOneWidget);
    });
  });
}
