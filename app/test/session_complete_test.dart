import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/models/mission.dart';
import 'package:dekisugi/models/streak.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/session_complete.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap({
    List<ExplainedItem> achievements = const [],
    VoidCallback? onHome,
    VoidCallback? onReview,
    VoidCallback? onRetry,
    VoidCallback? onRemindTomorrow,
    bool saveFailed = false,
    bool saving = false,
    String? missionLabel,
    bool missionCleared = false,
    MissionKind missionKind = MissionKind.teach,
    bool reminderBusy = false,
    int reminderHour = 20,
    double textScale = 1,
  }) => MaterialApp(
    theme: buildAppTheme(Brightness.light),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: child!,
    ),
    home: Scaffold(
      body: SessionCompleteView(
        achievements: achievements,
        saveFailed: saveFailed,
        saving: saving,
        missionLabel: missionLabel,
        missionCleared: missionCleared,
        missionKind: missionKind,
        onRemindTomorrow: onRemindTomorrow,
        reminderBusy: reminderBusy,
        reminderHour: reminderHour,
        onHome: onHome ?? () {},
        onReview: onReview ?? () {},
        onRetry: onRetry ?? () {},
      ),
    ),
  );

  ExplainedItem achievement() => ExplainedItem(
    unitId: 'force-motion',
    conceptKey: 'fall',
    label: '落下の速さ',
    said: '空気の抵抗がなければ重さは関係ない',
    at: DateTime(2026, 8, 9),
  );

  testWidgets('ノートの署名面で、本人が話した言葉を主役にする', (tester) async {
    await tester.pumpWidget(wrap(achievements: [achievement()]));

    expect(find.textContaining('デキすぎ君の\nノートに残った'), findsOneWidget);
    expect(find.text('「空気の抵抗がなければ重さは関係ない」'), findsOneWidget);
    expect(find.text('—  あなたが話した言葉'), findsOneWidget);
    for (final banned in ['ポイント', 'XP', 'レベル', 'ランキング', 'スコア']) {
      expect(find.textContaining(banned), findsNothing);
    }
  });

  testWidgets('成果が0件なら成功を作らず、次の一手を出す', (tester) async {
    await tester.pumpWidget(wrap());

    expect(find.text('次に言葉にするところ'), findsOneWidget);
    expect(find.textContaining('ノートに残った'), findsOneWidget);
    expect(find.textContaining('あなたが話した言葉'), findsNothing);
    expect(find.textContaining('次に話すこと'), findsWidgets);
  });

  testWidgets('訂正の証拠があるミッションだけCLEARと表示する', (tester) async {
    await tester.pumpWidget(
      wrap(
        achievements: [achievement()],
        missionLabel: '落下の速さ',
        missionCleared: true,
      ),
    );

    expect(find.textContaining('MISSION CLEAR'), findsOneWidget);
    expect(find.textContaining('「落下の速さ」を\n教え切った'), findsOneWidget);

    await tester.pumpWidget(
      wrap(
        achievements: [achievement()],
        missionLabel: '落下の速さ',
        missionCleared: false,
      ),
    );
    await tester.pump();

    expect(find.textContaining('MISSION CLEAR'), findsNothing);
    expect(find.textContaining('MISSION LOG'), findsOneWidget);
  });

  testWidgets('ホームと見直しの操作が働く', (tester) async {
    var home = 0;
    var review = 0;
    await tester.pumpWidget(
      wrap(
        achievements: [achievement()],
        onHome: () => home++,
        onReview: () => review++,
      ),
    );

    final homeButton = find.text('ホームでノートを見る');
    await tester.ensureVisible(homeButton);
    await tester.tap(homeButton);
    final reviewButton = find.widgetWithText(OutlinedButton, '次に話すことを整える');
    await tester.ensureVisible(reviewButton);
    await tester.tap(reviewButton);
    expect(home, 1);
    expect(review, 1);
  });

  testWidgets('CASE CLEARは別場面でも使えた成果として返す', (tester) async {
    await tester.pumpWidget(
      wrap(
        achievements: [achievement()],
        missionLabel: '落下の速さ',
        missionCleared: true,
        missionKind: MissionKind.caseRetry,
      ),
    );

    expect(find.textContaining('CASE CLEAR'), findsOneWidget);
    expect(find.textContaining('別の場面でも使えた'), findsWidgets);
    expect(find.textContaining('具体場面の予想と理由'), findsOneWidget);
  });

  testWidgets('本人が選ぶまで通知権限を求めず、翌日CASEを具体的に示す', (tester) async {
    var enabled = 0;
    await tester.pumpWidget(
      wrap(
        achievements: [achievement()],
        missionLabel: '落下の速さ',
        missionCleared: true,
        reminderHour: 19,
        onRemindTomorrow: () => enabled++,
      ),
    );

    expect(find.textContaining('NEXT CASE'), findsOneWidget);
    expect(find.textContaining('別の場面で使います'), findsOneWidget);
    expect(enabled, 0, reason: '完了画面を開いただけで許可を求めてはいけない');
    final button = find.text('明日19時ごろに知らせる');
    await tester.ensureVisible(button);
    await tester.tap(button);
    expect(enabled, 1);
  });

  testWidgets('保存失敗を成功扱いせず、再試行と退出を分ける', (tester) async {
    var retry = 0;
    var home = 0;
    await tester.pumpWidget(
      wrap(
        achievements: [achievement()],
        saveFailed: true,
        onRetry: () => retry++,
        onHome: () => home++,
      ),
    );

    expect(find.text('端末への保存が完了していません。'), findsOneWidget);
    expect(find.textContaining('まだノートに'), findsOneWidget);
    expect(find.text('デキすぎ君のノート'), findsNothing);
    final retryButton = find.text('もう一度保存する');
    await tester.scrollUntilVisible(
      retryButton,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(retryButton);
    final homeButton = find.text('保存せずホームへ');
    await tester.scrollUntilVisible(
      homeButton,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(homeButton);
    expect(retry, 1);
    expect(home, 1);
  });

  testWidgets('320dp・文字200%でも末尾まで操作できる', (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrap(achievements: [achievement(), achievement()], textScale: 2),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('ホームでノートを見る'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
