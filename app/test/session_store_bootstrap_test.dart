import 'dart:async';

import 'package:dekisugi/services/session_store.dart';
import 'package:dekisugi/widgets/session_store_bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('永続storeを開くまで本編を作らず、成功後だけ渡す', (tester) async {
    final opening = Completer<SessionStore>();
    await tester.pumpWidget(
      SessionStoreBootstrap(
        openStore: () => opening.future,
        appBuilder: (_) => const MaterialApp(home: Text('GAME')),
      ),
    );
    await tester.pump();

    expect(find.text('学習記録を準備しています'), findsOneWidget);
    expect(find.text('GAME'), findsNothing);

    opening.complete(MemorySessionStore());
    await tester.pumpAndSettle();
    expect(find.text('GAME'), findsOneWidget);
  });

  testWidgets('保存先エラーを明示し、Memoryへ落とさず再試行後に起動する', (tester) async {
    var attempts = 0;
    Future<SessionStore> open() async {
      attempts += 1;
      if (attempts == 1) throw StateError('injected database open failure');
      return MemorySessionStore();
    }

    await tester.pumpWidget(
      SessionStoreBootstrap(
        openStore: open,
        appBuilder: (_) => const MaterialApp(home: Text('GAME')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('学習記録の保存先を開けませんでした'), findsOneWidget);
    expect(find.textContaining('一時モードでは開始しません'), findsOneWidget);
    expect(find.text('GAME'), findsNothing);
    expect(attempts, 1);

    await tester.tap(
      find.byKey(const ValueKey('session-store-bootstrap-retry')),
    );
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('GAME'), findsOneWidget);
  });

  testWidgets('320x568・文字200%でも保存エラーと56dp再試行を最後まで表示する', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(2),
        ),
        child: SessionStoreBootstrap(
          openStore: () async => throw StateError('injected'),
          appBuilder: (_) => const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final retry = find.byKey(const ValueKey('session-store-bootstrap-retry'));
    expect(retry, findsOneWidget);
    expect(tester.getSize(retry).height, greaterThanOrEqualTo(48));
    expect(
      find.bySemanticsLabel(RegExp('学習記録の保存先を開けませんでした.*一時モードでは開始しません')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
