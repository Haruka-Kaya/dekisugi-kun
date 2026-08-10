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
  Widget wrap(Widget child, {double textScale = 1}) => MaterialApp(
    theme: buildAppTheme(Brightness.light),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(body: child),
  );

  StreakView view({
    int days = 5,
    int graceLeft = 2,
    bool doneToday = true,
    bool restDay = false,
  }) => StreakView(
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
        'lib/screens/home_screen.dart',
        'lib/models/exam_plan.dart',
      ]) {
        // **コメントを先に落とす。** 画面に出るのは文字列だけで、
        // 「ポイントを作らない」という説明まで違反にすると、
        // 理由を書けなくなる（実際に誤検知した）。
        //
        // 行ごとに見るのは、引用符が行をまたいで
        // 別の行のコメントを巻き込むのを防ぐため
        final lines = File(
          path,
        ).readAsLinesSync().where((l) => !l.trimLeft().startsWith('//'));

        for (final word in banned) {
          final re = RegExp("'[^']*${RegExp.escape(word)}[^']*'");
          final hits = lines.where(re.hasMatch);
          expect(
            hits,
            isEmpty,
            reason:
                '$path が「$word」を画面に出そうとしている（C5違反）: '
                '${hits.isEmpty ? '' : hits.first.trim()}',
          );
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
      expect(find.textContaining('あと2日'), findsOneWidget);
    });

    testWidgets('残数が減れば表示も減る', (tester) async {
      await tester.pumpWidget(wrap(StreakLine(streak: view(graceLeft: 0))));
      expect(find.textContaining('あと0日'), findsOneWidget);
    });

    testWidgets('形だけで伝えない（SC 1.4.1）', (tester) async {
      // 小さいアイコンの塗り分けだけだと見分けられない
      await tester.pumpWidget(wrap(StreakLine(streak: view(graceLeft: 1))));
      expect(find.byIcon(Icons.event_available), findsOneWidget);
      expect(find.byIcon(Icons.shield), findsNothing);
      expect(find.byIcon(Icons.shield_outlined), findsNothing);
      expect(find.textContaining('あと1日'), findsOneWidget);
    });

    testWidgets('320dp・文字200%では日数と猶予を縦に並べる', (tester) async {
      tester.view.physicalSize = const Size(320, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(StreakLine(streak: view(graceLeft: 2)), textScale: 2),
      );

      final days = tester.getTopLeft(find.textContaining('つづけて'));
      final grace = tester.getTopLeft(find.textContaining('あと2日'));
      expect(grace.dy, greaterThan(days.dy));
      expect(tester.takeException(), isNull);
    });
  });

  group('文言', () {
    testWidgets('0日のときに失点したように見せない', (tester) async {
      await tester.pumpWidget(
        wrap(StreakLine(streak: view(days: 0, doneToday: false))),
      );
      expect(find.textContaining('0日'), findsNothing);
    });

    testWidgets('きょうがまだなら、まだだと分かる', (tester) async {
      await tester.pumpWidget(
        wrap(StreakLine(streak: view(days: 3, doneToday: false))),
      );
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
