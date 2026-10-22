import 'dart:async';

import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/screens/settings_screen.dart';
import 'package:dekisugi/services/reminders.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/studio_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> showSettings(WidgetTester tester, Future<void> Function()? reset) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: SettingsScreen(reminders: _Reminders(), onResetSchoolLearning: reset),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> openConfirmation(WidgetTester tester) async {
    final tile = find.byKey(const ValueKey('school-learning-reset'));
    final action = find.descendant(of: tile, matching: find.text('学校の学習記録を消す'));
    await tester.scrollUntilVisible(action, 250, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    expect(action.hitTestable(), findsOneWidget);
    await tester.tap(action);
    await tester.pumpAndSettle();
  }

  testWidgets('normal settings have no school deletion entry', (tester) async {
    await showSettings(tester, null);
    expect(find.byKey(const ValueKey('school-learning-reset')), findsNothing);
  });

  testWidgets('confirmation and cancel remain reachable at 200 percent', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    var calls = 0;
    await showSettings(tester, () async { calls++; });
    await openConfirmation(tester);
    expect(find.textContaining('個人モードの記録や通知・言語設定は残ります'), findsOneWidget);
    expect(find.textContaining('元に戻せません'), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.text('残す').hitTestable(), findsOneWidget);
    expect(find.byKey(const ValueKey('confirm-school-reset')).hitTestable(), findsOneWidget);
    await tester.tap(find.text('残す'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.byType(AlertDialog), findsNothing);
    await openConfirmation(tester);
    final confirm = find.byKey(const ValueKey('confirm-school-reset'));
    expect(confirm.hitTestable(), findsOneWidget);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('success waits for completion, prevents repeated activation and back navigation', (tester) async {
    var calls = 0;
    final complete = Completer<void>();
    await showSettings(tester, () { calls++; return complete.future; });
    await openConfirmation(tester);
    await tester.tap(find.byKey(const ValueKey('confirm-school-reset')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(calls, 1);
    expect(find.text('学校の学習記録を消しました。'), findsNothing);
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
    // The callback itself is guarded as well as the disabled pointer surface.
    tester.widget<StudioActionTile>(find.byKey(const ValueKey('school-learning-reset'))).onTap();
    await tester.pump();
    expect(calls, 1);
    complete.complete();
    await tester.pumpAndSettle();
    expect(find.text('学校の学習記録を消しました。'), findsOneWidget);
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isTrue);
  });

  testWidgets('failure is not success and the same action can be retried', (tester) async {
    var calls = 0;
    await showSettings(tester, () async {
      if (++calls == 1) throw StateError('synthetic failure');
    });
    await openConfirmation(tester);
    await tester.tap(find.byKey(const ValueKey('confirm-school-reset')));
    await tester.pumpAndSettle();
    expect(find.text('学校の記録を消せませんでした。もう一度お試しください。'), findsOneWidget);
    expect(find.text('学校の学習記録を消しました。'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await openConfirmation(tester);
    await tester.tap(find.byKey(const ValueKey('confirm-school-reset')));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('学校の学習記録を消しました。'), findsOneWidget);
  });
}

class _Reminders extends Reminders {
  _Reminders() : super(store: MemorySessionStore());
  @override
  Future<bool> isEnabled() async => false;
  @override
  Future<int> hour() async => 20;
}
