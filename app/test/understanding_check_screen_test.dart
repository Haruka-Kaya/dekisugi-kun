import 'package:dekisugi/config/app_language.dart' as lang;
import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/screens/understanding_check_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => lang.appLanguage = lang.AppLanguage.ja);
  testWidgets(
    'before answers get no feedback; teaching hides source; export excludes explanation',
    (tester) async {
      lang.appLanguage = lang.AppLanguage.en;
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: const UnderstandingCheckScreen(),
        ),
      );
      Future<void> tap(String key) async {
        final finder = find.byKey(ValueKey(key));
        await tester.scrollUntilVisible(
          finder,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(finder);
        await tester.pumpAndSettle();
        for (final text in tester.widgetList<Text>(find.byType(Text))) {
          expect(text.data ?? '', isNot(matches(RegExp(r'[\u3040-\u30ff\u4e00-\u9fff]'))));
        }
      }

      await tap('check-start');
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('check-next')))
            .onPressed,
        isNull,
      );
      for (final answer in [0, 0, 2]) {
        await tap('check-option-$answer');
        expect(find.textContaining('Correct answer:'), findsNothing);
        await tap('check-next');
      }
      expect(
        find.textContaining('When gravity is the only force'),
        findsOneWidget,
      );
      await tap('check-hide');
      expect(
        find.textContaining('When gravity is the only force'),
        findsNothing,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('check-teach')))
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('check-explanation')),
        'private learner explanation',
      );
      await tester.pump();
      await tap('check-teach');
      expect(find.textContaining('not automatic grading'), findsOneWidget);
      await tap('check-after');
      for (final answer in [0, 1, 2, 2]) {
        await tap('check-option-$answer');
        await tap('check-next');
      }
      expect(
        find.text('Before 2/3 → After 3/3\nNew situation 1/1'),
        findsOneWidget,
      );
      expect(find.textContaining('have not been validated'), findsOneWidget);
      await tap('check-copy');
      expect(copied, contains('fall-check-v1,2,3,3,3,1,1'));
      expect(copied, isNot(contains('private learner explanation')));
      expect(copied, contains('not proof of efficacy'));
      await tester.pumpWidget(const SizedBox.shrink());
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    },
  );
}
