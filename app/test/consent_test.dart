import 'package:dekisugi/screens/consent_screen.dart';
import 'package:dekisugi/services/consent.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:flutter_test/flutter_test.dart';

ConsentRecord record({
  AgeBand band = AgeBand.adult,
  bool? guardian,
  bool transfer = true,
  int version = kConsentVersion,
}) =>
    ConsentRecord(
      ageBand: band,
      guardianPresent: guardian,
      transferAgreed: transfer,
      agreedAt: DateTime(2026, 8, 5),
      version: version,
    );

void main() {
  group('越境移転の説明', () {
    test('3点すべてを持つ', () {
      // 「海外に送信されることがあります」だけでは足りない。
      // 国名・その国の制度・移転先の措置を実際に表示する必要がある
      expect(kTransferDisclosure, hasLength(3));
      for (final (label, body) in kTransferDisclosure) {
        expect(label, isNotEmpty);
        expect(body.length, greaterThan(15), reason: '$label の説明が短すぎる');
      }
    });

    test('国名を明示している', () {
      final all = kTransferDisclosure.map((e) => e.$2).join();
      expect(all.contains('アメリカ'), isTrue);
    });

    test('その国の制度が日本と同じでないことに触れている', () {
      final all = kTransferDisclosure.map((e) => e.$2).join();
      expect(all.contains('法律') || all.contains('きまり'), isTrue);
      expect(all.contains('日本と同じしくみではない') || all.contains('ありません'), isTrue);
    });

    test('移転先が講じている措置に触れている', () {
      final all = kTransferDisclosure.map((e) => e.$2).join();
      expect(all.contains('暗号化') || all.contains('契約'), isTrue);
    });
  });

  group('同意の有効性', () {
    test('大人が移転に同意していれば有効', () {
      expect(record().isValid, isTrue);
    });

    test('移転に同意していなければ無効', () {
      expect(record(transfer: false).isValid, isFalse);
    });

    test('16歳未満で保護者の確認が無ければ無効', () {
      expect(record(band: AgeBand.under16, guardian: null).isValid, isFalse);
      expect(record(band: AgeBand.under16, guardian: false).isValid, isFalse);
      expect(record(band: AgeBand.under16, guardian: true).isValid, isTrue);
    });

    test('版が違えば無効（文面を変えたら取り直す）', () {
      expect(record(version: kConsentVersion - 1).isValid, isFalse);
    });
  });

  group('年齢の帯', () {
    test('生年月日を持たない', () {
      // 必要なのは「16歳未満かどうか」だけ。要らないものを集めない
      final json = record().toJson();
      expect(json.containsKey('birthday'), isFalse);
      expect(json.containsKey('age'), isFalse);
    });

    test('知らない値を adult に落とさない', () {
      // 保護が要る側に倒す
      expect(AgeBand.parse('grownup'), isNull);
      expect(AgeBand.parse(null), isNull);
      expect(AgeBand.parse(18), isNull);
    });
  });

  group('保管', () {
    late ConsentStore store;
    setUp(() => store = ConsentStore(MemorySessionStore()));

    test('保存して読み出せる', () async {
      await store.save(record(band: AgeBand.under16, guardian: true));
      final got = await store.load();
      expect(got?.ageBand, AgeBand.under16);
      expect(got?.guardianPresent, isTrue);
      expect(got?.isValid, isTrue);
    });

    test('何も無ければ null', () async {
      expect(await store.load(), isNull);
    });

    test('壊れていたら「同意していない」に倒す', () async {
      final inner = MemorySessionStore();
      await inner.setSetting('consent', '{ぐちゃぐちゃ');
      expect(await ConsentStore(inner).load(), isNull);
    });

    test('消せる', () async {
      await store.save(record());
      await store.clear();
      expect(await store.load(), isNull);
    });
  });

  group('同意画面', () {
    Widget wrap(void Function(ConsentRecord) onAgreed) => MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: ConsentScreen(onAgreed: (r) async => onAgreed(r)),
        );

    setUp(() {
      // 既定の 800x600 だと ListView の下半分が組まれず、
      // ボタンもチェックボックスも見つからない
      final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(900, 2600);
      view.devicePixelRatio = 1.0;
    });

    tearDown(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
          .resetPhysicalSize();
    });

    testWidgets('何も選ばないうちは進めない', (tester) async {
      await tester.pumpWidget(wrap((_) {}));
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull, reason: '同意前に押せてしまう');
    });

    testWidgets('16歳未満を選ぶと保護者の確認欄が出る', (tester) async {
      await tester.pumpWidget(wrap((_) {}));
      expect(find.text('おうちの人といっしょに確認しました'), findsNothing);

      await tester.tap(find.text('15歳以下'));
      await tester.pumpAndSettle();
      expect(find.text('おうちの人といっしょに確認しました'), findsOneWidget);
    });

    testWidgets('16歳未満は保護者の確認まで揃わないと進めない', (tester) async {
      ConsentRecord? got;
      await tester.pumpWidget(wrap((r) => got = r));

      await tester.tap(find.text('15歳以下'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('上の内容を読んで、海外への送信に同意します'));
      await tester.pumpAndSettle();

      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull);

      await tester.tap(find.text('おうちの人といっしょに確認しました'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('はじめる'));
      await tester.pumpAndSettle();

      expect(got?.ageBand, AgeBand.under16);
      expect(got?.guardianPresent, isTrue);
      expect(got?.isValid, isTrue);
    });

    testWidgets('越境移転の3点が画面に出ている', (tester) async {
      await tester.pumpWidget(wrap((_) {}));
      for (final (label, _) in kTransferDisclosure) {
        expect(find.text(label), findsOneWidget, reason: '$label が出ていない');
      }
    });
  });
}
