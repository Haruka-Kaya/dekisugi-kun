import 'dart:ui' show SemanticsAction;

import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/screens/consent_screen.dart';
import 'package:dekisugi/screens/settings_screen.dart';
import 'package:dekisugi/screens/team_join_screen.dart';
import 'package:dekisugi/services/consent.dart';
import 'package:dekisugi/services/device_identity.dart';
import 'package:dekisugi/services/reminders.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:dekisugi/services/team_client.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/studio_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child) =>
      MaterialApp(theme: buildAppTheme(Brightness.light), home: child);

  void useCompactLargeText(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Future<void> scrollAndExpectNoLayoutError(WidgetTester tester) async {
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final list = find.byType(ListView);
    expect(list, findsOneWidget);
    for (var i = 0; i < 12; i++) {
      await tester.drag(list, const Offset(0, -420));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  }

  testWidgets('同意は価値を先に伝え、320dp・文200%で崩れない', (tester) async {
    useCompactLargeText(tester);
    await tester.pumpWidget(
      wrap(ConsentScreen(onAgreed: (_) async => null, onUseLocalOnly: () {})),
    );

    expect(find.byType(StudioWordmark), findsOneWidget);
    expect(find.textContaining('生年月日や氏名は集めません'), findsAtLeastNWidgets(1));
    final under16 = find.text('15歳以下');
    await tester.scrollUntilVisible(
      under16,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(under16);
    await tester.pumpAndSettle();
    await tester.tap(under16);
    final next = find.byKey(const ValueKey('consent-next'));
    await tester.scrollUntilVisible(
      next,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();
    final schoolRoute = find.text('学校からもらって使います');
    await tester.scrollUntilVisible(
      schoolRoute,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(schoolRoute);
    await tester.pumpAndSettle();
    await tester.tap(schoolRoute);
    await tester.pumpAndSettle();
    expect(find.text('外部サービスを使うモードは、18歳未満・学校向けに提供していません。'), findsOneWidget);
    final localOnly = find.byKey(const ValueKey('use-local-only-mode'));
    await tester.scrollUntilVisible(
      localOnly,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(localOnly);
    await tester.pumpAndSettle();
    expect(tester.getSize(localOnly).height, greaterThanOrEqualTo(48));
    expect(localOnly.hitTestable(), findsOneWidget);
    await scrollAndExpectNoLayoutError(tester);

    for (final (label, _) in kTransferDisclosure) {
      expect(find.text(label), findsNothing, reason: '端末内経路に外部送信の同意を求めない');
    }
  });

  testWidgets('設定は通知の価値と節度を示し、320dp・文200%で崩れない', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      useCompactLargeText(tester);
      await tester.pumpWidget(
        wrap(SettingsScreen(reminders: _FakeReminders())),
      );

      await tester.pumpAndSettle();
      expect(find.byType(StudioPageIntro), findsOneWidget);
      expect(find.text('まいにち知らせる'), findsOneWidget);
      expect(find.textContaining('何度も呼び戻しません'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('知らせる時刻'),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      final time = tester.getSemantics(find.bySemanticsLabel('知らせる時刻、20時'));
      expect(time.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      await scrollAndExpectNoLayoutError(tester);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('クラス参加は共有範囲を先に示し、320dp・文200%で崩れない', (tester) async {
    useCompactLargeText(tester);
    final store = MemorySessionStore();
    final client = TeamClient(
      baseUrl: '',
      identity: DeviceIdentity(baseUrl: '', store: store),
      store: store,
    );
    await tester.pumpWidget(wrap(TeamJoinScreen(client: client)));

    expect(find.byType(StudioPageIntro), findsOneWidget);
    expect(find.textContaining('名前も順位も使いません'), findsOneWidget);
    await scrollAndExpectNoLayoutError(tester);
    expect(find.text('クラスコード'), findsOneWidget);
  });
}

class _FakeReminders extends Reminders {
  _FakeReminders() : super(store: MemorySessionStore());

  bool enabled = true;
  int selectedHour = 20;

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<int> hour() async => selectedHour;

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> setEnabled(bool on) async => enabled = on;

  @override
  Future<void> setHour(int h) async => selectedHour = h;
}
