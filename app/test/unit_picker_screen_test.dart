import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/screens/unit_picker_screen.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:dekisugi/services/units_client.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/stub_dio.dart';

const _listJson = '''
{"units":[{"id":"force-motion","title":"力と運動",
"brief":"ものが落ちる速さ、動き続けるとき、止まるとき、投げ上げたとき。力がはたらいているかどうかを、動きから読み取れるようにする単元です。",
"concepts":[{"key":"fall","label":"落下の速さ"},{"key":"inertia","label":"止まる理由"}],
"sectionCount":2}]}
''';

void main() {
  testWidgets('320dp・文字200%でも単元カードが横にはみ出さない', (tester) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final store = MemorySessionStore();
    final units = UnitsClient(
      baseUrl: 'https://example.test',
      store: store,
      dio: fakeDio({
        'GET https://example.test/api/units': () => jsonRes(200, _listJson),
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: UnitPickerScreen(
          units: units,
          onPick: (_) {},
          onOpenReview: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('教材を読む  →  自分の言葉で教える'), findsOneWidget);
  });
}
