import 'dart:math' as math;

import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/game_tokens.dart';
import 'package:dekisugi/screens/notation_lab_hub_screen.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:flutter_test/flutter_test.dart';

const _entries = [
  NotationLabEntry(
    id: 'locked',
    unitTitle: '力と運動',
    conceptLabel: '慣性',
    description: '前の学習を終えると、矢印と式を扱えます。',
    state: NotationLabState.locked,
  ),
  NotationLabEntry(
    id: 'available',
    unitTitle: '力と運動',
    conceptLabel: '落下の速さ',
    description: '力の矢印をなぞり、式を意味の順に組みます。',
    state: NotationLabState.available,
  ),
];

double _contrast(Color foreground, Color background) {
  final lighter = math.max(
    foreground.computeLuminance(),
    background.computeLuminance(),
  );
  final darker = math.min(
    foreground.computeLuminance(),
    background.computeLuminance(),
  );
  return (lighter + 0.05) / (darker + 0.05);
}

Widget _app(Brightness brightness, ValueChanged<NotationLabEntry> onOpen) =>
    MaterialApp(
      theme: buildAppTheme(brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: NotationLabHubScreen(entries: _entries, onOpen: onOpen),
    );

void main() {
  testWidgets('locked状態はlight/darkとも読める前景を使い、320dp・文字200%でも操作できる', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    for (final brightness in Brightness.values) {
      final opened = <String>[];
      final palette = brightness == Brightness.light
          ? GamePalette.light
          : GamePalette.dark;
      await tester.pumpWidget(
        KeyedSubtree(
          key: ValueKey('notation-${brightness.name}'),
          child: _app(brightness, (entry) => opened.add(entry.id)),
        ),
      );
      await tester.pump();

      final locked = find.byKey(const ValueKey('notation-entry-locked'));
      expect(find.bySemanticsLabel(RegExp(r'慣性の記号ラボ。未解放')), findsOneWidget);
      final lockedIcon = tester.widget<Icon>(
        find
            .descendant(
              of: locked,
              matching: find.byIcon(Icons.lock_outline_rounded),
            )
            .first,
      );
      expect(lockedIcon.color, palette.onPathLocked);
      expect(
        _contrast(palette.onPathLocked, palette.pathLocked),
        greaterThanOrEqualTo(4.5),
      );
      await tester.scrollUntilVisible(
        locked,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(locked);
      await tester.pump();
      expect(opened, isEmpty);

      final available = find.byKey(const ValueKey('notation-entry-available'));
      await tester.scrollUntilVisible(
        available,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(tester.getSize(available).height, greaterThanOrEqualTo(48));
      await tester.tap(available);
      await tester.pump();
      expect(opened, ['available']);
      expect(tester.takeException(), isNull);
    }
    semantics.dispose();
  });
}
