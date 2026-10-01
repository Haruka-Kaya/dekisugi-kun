import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/screens/timed_challenge_entry_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({required ValueChanged<bool> onResult}) => MaterialApp(
  theme: buildAppTheme(Brightness.dark),
  home: Scaffold(
    body: Builder(
      builder: (context) => Center(
        child: FilledButton(
          onPressed: () async =>
              onResult(await confirmTimedChallengeEntry(context, gemCost: 1)),
          child: const Text('開く'),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('時間観察券は用途と無料実験を明示して確認後だけ承認する', (tester) async {
    bool? result;
    await tester.pumpWidget(_host(onResult: (value) => result = value));

    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('timed-entry-confirmation')),
      findsOneWidget,
    );
    expect(find.textContaining('今日の学習日は何度でも'), findsOneWidget);
    expect(find.textContaining('探究ノート・探究記録・正答は購入できません'), findsOneWidget);
    expect(find.textContaining('対応づけ実験と連続観察は無料'), findsOneWidget);
    expect(result, isNull);

    await tester.tap(find.byKey(const ValueKey('timed-entry-confirm')));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('dark・320x568・文字200%で取消できoverflowしない', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    bool? result;
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(2),
        ),
        child: _host(onResult: (value) => result = value),
      ),
    );
    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('timed-entry-cancel')));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
