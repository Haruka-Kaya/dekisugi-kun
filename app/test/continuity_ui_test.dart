import 'dart:io';

import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/models/streak.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/streak_line.dart';
import 'package:flutter_test/flutter_test.dart';

/// **C5 — 1問ごとのポイント付与を主動線にしない。**
///
/// 根拠: 従事随伴報酬は内発動機を d = −0.40 で毀損する（Deci et al. 1999。
/// 完了随伴 −0.36 / 遂行随伴 −0.28）。
/// L@S 2022 の逐語 "Through many nights of XP farming, I lost my drive to learn"。
///
/// Duolingo 自身も Total Sessions の欠陥を認め、
/// 品質で重み付けた TSLW へ指標を移している。
void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(body: child),
      );

  StreakView view({
    int days = 5,
    int graceLeft = 2,
    bool doneToday = true,
    bool restDay = false,
  }) =>
      StreakView(
        days: days,
        graceLeft: graceLeft,
        doneToday: doneToday,
        restDay: restDay,
      );

  group('C5: ポイントを作らない', () {
    test('継続まわりのソースに通貨めいた語が出てこない', () {
      // 画面のツリーを見るだけだと、条件次第でしか出ない文言を見逃す。
      // **語そのものが存在しないこと**をソースで確かめる
      const banned = ['ポイント', 'XP', 'レベル', 'ランキング', '順位', 'コイン'];
      for (final path in [
        'lib/widgets/streak_line.dart',
        'lib/models/streak.dart',
      ]) {
        final src = File(path).readAsStringSync();
        for (final word in banned) {
          // コメントでの言及（「ポイントを作らない」等）は許す。
          // 禁じたいのは**画面に出す文字列**なので、引用符の中だけ見る
          final inStrings = RegExp("'[^']*${RegExp.escape(word)}[^']*'")
              .allMatches(src);
          expect(inStrings, isEmpty,
              reason: '$path が「$word」を画面に出そうとしている（C5違反）');
        }
      }
    });

    testWidgets('画面にも数値報酬が出ない', (tester) async {
      await tester.pumpWidget(wrap(StreakLine(streak: view())));
      for (final word in ['ポイント', 'pt', 'XP', 'レベル', 'ランキング']) {
        expect(find.textContaining(word), findsNothing, reason: '「$word」が出ている');
      }
    });
  });

  group('C6: 猶予の残数を明示する', () {
    testWidgets('残数が数字で出る', (tester) async {
      // Sharif & Shu 2021 が示したのは「使わずに済ませること自体が動機になる」
      // という働き。**残っていることが見えていないと機能しない**
      await tester.pumpWidget(wrap(StreakLine(streak: view(graceLeft: 2))));
      expect(find.textContaining('猶予 2'), findsOneWidget);
    });

    testWidgets('残数が減れば表示も減る', (tester) async {
      await tester.pumpWidget(wrap(StreakLine(streak: view(graceLeft: 0))));
      expect(find.textContaining('猶予 0'), findsOneWidget);
    });

    testWidgets('形だけで伝えない（SC 1.4.1）', (tester) async {
      // 小さいアイコンの塗り分けだけだと見分けられない
      await tester.pumpWidget(wrap(StreakLine(streak: view(graceLeft: 1))));
      expect(find.byIcon(Icons.shield), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      expect(find.textContaining('猶予 1'), findsOneWidget);
    });
  });

  group('文言', () {
    testWidgets('0日のときに失点したように見せない', (tester) async {
      await tester.pumpWidget(wrap(StreakLine(streak: view(days: 0, doneToday: false))));
      expect(find.textContaining('0日'), findsNothing);
    });

    testWidgets('きょうがまだなら、まだだと分かる', (tester) async {
      await tester.pumpWidget(
          wrap(StreakLine(streak: view(days: 3, doneToday: false))));
      expect(find.textContaining('3日'), findsOneWidget);
      expect(find.textContaining('これから'), findsOneWidget);
    });

    testWidgets('考査の前日は休んでよいと言う', (tester) async {
      // 考査当日に学習アプリを開かせる設計にしない
      await tester.pumpWidget(wrap(StreakLine(streak: view(restDay: true))));
      expect(find.textContaining('休んでいい'), findsOneWidget);
    });
  });
}
