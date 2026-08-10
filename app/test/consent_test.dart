import 'package:dekisugi/screens/consent_screen.dart';
import 'package:dekisugi/models/team.dart';
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
  ConsentRoute route = ConsentRoute.self,
  String? schoolCode,
}) => ConsentRecord(
  ageBand: band,
  guardianPresent: guardian,
  transferAgreed: transfer,
  agreedAt: DateTime(2026, 8, 5),
  version: version,
  route: route,
  schoolCode: schoolCode,
);

void main() {
  group('学校経由の同意', () {
    test('学校コードがあっても、現在は学校経由を有効にしない', () {
      final r = record(
        band: AgeBand.under16,
        guardian: null,
        route: ConsentRoute.school,
        schoolCode: 'sakura-2026',
      );
      expect(r.isCurrentlyEligible, isFalse);
      expect(r.isValid, isFalse);
    });

    test('学校コードが無ければ学校経由として通さない', () {
      // 誰でも「学校から配られた」と言えてしまうと、
      // 15歳以下の保護者確認を素通りできる
      final r = record(
        band: AgeBand.under16,
        route: ConsentRoute.school,
        schoolCode: null,
      );
      expect(r.isValid, isFalse);
      expect(
        record(route: ConsentRoute.school, schoolCode: '').isValid,
        isFalse,
      );
    });

    test('学校経由でも越境移転の同意は要る', () {
      // 学校が取るのは「保護者の同意」であって、
      // 生徒がこの画面を素通りしてよいという意味ではない
      final r = record(
        route: ConsentRoute.school,
        schoolCode: 'sakura-2026',
        transfer: false,
      );
      expect(r.isValid, isFalse);
    });

    test('保存して読み戻せる', () {
      final r = record(
        band: AgeBand.under16,
        route: ConsentRoute.school,
        schoolCode: 'sakura-2026',
      );
      final back = ConsentRecord.fromJson(r.toJson())!;
      expect(back.route, ConsentRoute.school);
      expect(back.schoolCode, 'sakura-2026');
      expect(back.isValid, isFalse, reason: '過去の学校記録も会話へ通さない');
    });

    test('v4成人でも未知・欠落routeは同意済みにしない', () {
      final unknown = record().toJson()..['route'] = 'なにか';
      final missing = record().toJson()..remove('route');

      expect(ConsentRoute.parse('なにか'), isNull);
      expect(ConsentRoute.parse(null), isNull);
      expect(ConsentRecord.fromJson(unknown), isNull);
      expect(ConsentRecord.fromJson(missing), isNull);
    });

    test('学校経由では個人向けStore購入を案内しない', () {
      expect(record().allowsIndividualPurchases, isTrue);
      expect(
        record(
          route: ConsentRoute.school,
          schoolCode: 'sakura-2026',
        ).allowsIndividualPurchases,
        isFalse,
      );
    });
  });

  group('越境移転の説明', () {
    test('文面変更で同意版を更新した', () {
      expect(kConsentVersion, 4);
    });

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

    test('RevenueCat とストアに送る情報を具体的に示す', () {
      final all = kExternalServiceDisclosure
          .map((entry) => '${entry.$1}${entry.$2}')
          .join();
      for (final value in [
        'RevenueCat',
        '匿名UUID',
        '端末の種類',
        'OS',
        '最終利用時刻',
        'Apple',
        'Google',
        '購入トークン',
      ]) {
        expect(all, contains(value), reason: '$value の説明が無い');
      }
    });

    test('RevenueCat へ送らない情報を明示する', () {
      final all = kExternalServiceDisclosure
          .map((entry) => '${entry.$1}${entry.$2}')
          .join();
      for (final value in ['氏名', 'メール', '広告ID', '逐語', '声']) {
        expect(all, contains(value), reason: '$value の非送信説明が無い');
      }
    });
  });

  group('同意の有効性', () {
    test('大人が移転に同意していれば有効', () {
      expect(record().isValid, isTrue);
    });

    test('移転に同意していなければ無効', () {
      expect(record(transfer: false).isValid, isFalse);
    });

    test('18歳未満は保護者確認の有無によらず現在は無効', () {
      expect(record(band: AgeBand.under16, guardian: null).isValid, isFalse);
      expect(record(band: AgeBand.under16, guardian: false).isValid, isFalse);
      expect(record(band: AgeBand.under16, guardian: true).isValid, isFalse);
      expect(record(band: AgeBand.from16to17).isValid, isFalse);
    });

    test('版が違えば無効（文面を変えたら取り直す）', () {
      expect(record(version: kConsentVersion - 1).isValid, isFalse);
    });

    test('旧v3の成人・未成年・学校記録は再起動後も通さない', () {
      expect(record(version: 3).isValid, isFalse);
      expect(
        record(band: AgeBand.under16, guardian: true, version: 3).isValid,
        isFalse,
      );
      expect(
        record(
          route: ConsentRoute.school,
          schoolCode: 'ABCD-EFGH',
          version: 3,
        ).isValid,
        isFalse,
      );
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
      await store.save(record());
      final got = await store.load();
      expect(got?.ageBand, AgeBand.adult);
      expect(got?.isValid, isTrue);
    });

    test('何も無ければ null', () async {
      expect(await store.load(), isNull);
    });

    test('無効な学校・未成年・旧versionは保存せず、既存値も上書きしない', () async {
      final invalidRecords = [
        record(route: ConsentRoute.school, schoolCode: 'ABCD-EFGH'),
        record(band: AgeBand.under16, guardian: true),
        record(version: kConsentVersion - 1),
      ];

      for (final invalid in invalidRecords) {
        final emptyStore = ConsentStore(MemorySessionStore());
        await expectLater(emptyStore.save(invalid), throwsA(isA<StateError>()));
        expect(await emptyStore.load(), isNull);
      }

      final valid = record();
      await store.save(valid);
      for (final invalid in invalidRecords) {
        await expectLater(store.save(invalid), throwsA(isA<StateError>()));
      }
      final got = await store.load();
      expect(got?.toJson(), valid.toJson());
      expect(got?.isValid, isTrue);
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
    Widget wrap(Future<JoinFailure?> Function(ConsentRecord) onAgreed) =>
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: ConsentScreen(onAgreed: onAgreed, onUseLocalOnly: () {}),
        );

    setUp(() {
      // 既定の 800x600 だと ListView の下半分が組まれず、
      // ボタンもチェックボックスも見つからない
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(900, 4200);
      view.devicePixelRatio = 1.0;
    });

    tearDown(() {
      TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
          .resetPhysicalSize();
    });

    testWidgets('同意前に通信なしのおためしミッションを完了できる', (tester) async {
      var agreed = false;
      await tester.pumpWidget(
        wrap((_) async {
          agreed = true;
          return null;
        }),
      );

      expect(find.byKey(const Key('preview-predict-question')), findsOneWidget);
      await tester.tap(find.byKey(const Key('preview-predict-heavy')));
      await tester.pump();
      expect(find.byKey(const Key('preview-feedback')), findsOneWidget);
      expect(find.textContaining('条件は「真空中」'), findsOneWidget);

      await tester.tap(find.byKey(const Key('preview-predict-same')));
      await tester.pump();
      expect(find.byKey(const Key('preview-challenge')), findsOneWidget);

      await tester.tap(find.byKey(const Key('preview-correct-challenge')));
      await tester.pump();
      expect(find.byKey(const Key('preview-clear')), findsOneWidget);
      expect(find.text('空気の抵抗を無視すれば、落下の速さは重さに関係しません。'), findsOneWidget);
      expect(agreed, isFalse, reason: 'おためしで同意完了にしない');
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
    });

    testWidgets('320dp・文字200%でもおためしミッションを操作できる', (tester) async {
      final view =
          TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(320, 568);
      view.devicePixelRatio = 1;
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(Brightness.light),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: ConsentScreen(
              onAgreed: (_) async => null,
              onUseLocalOnly: () {},
            ),
          ),
        );

        expect(
          find.byKey(const Key('preview-predict-question')).hitTestable(),
          findsOneWidget,
          reason: '文字を大きくしても、説明より前に体験の問いが見える',
        );
        final same = find.byKey(const Key('preview-predict-same'));
        await tester.scrollUntilVisible(
          same,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        expect(same, findsOneWidget);
        expect(tester.getSize(same).height, greaterThanOrEqualTo(48));
        await tester.tap(same);
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('preview-challenge')).hitTestable(),
          findsOneWidget,
          reason: '選択肢の位置に残らず、次の思い込みから読める',
        );

        await tester.tap(find.text('そう。重いものほど速く落ちる'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('preview-feedback')).hitTestable(),
          findsOneWidget,
          reason: '誤答した直後に、訂正の手がかりが画面内に見える',
        );

        final correction = find.byKey(const Key('preview-correct-challenge'));
        await tester.scrollUntilVisible(
          correction,
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        expect(tester.getSize(correction).height, greaterThanOrEqualTo(48));
        await tester.tap(correction);
        await tester.pumpAndSettle();

        final clear = find.byKey(const Key('preview-clear'));
        expect(clear, findsOneWidget);
        expect(
          clear.hitTestable(),
          findsOneWidget,
          reason: 'CLEARも中途からではなく、見出しから見せる',
        );
        final clearRegion = find.byKey(const Key('preview-clear-region'));
        expect(clearRegion, findsOneWidget);
        expect(
          tester.getSemantics(clearRegion),
          matchesSemantics(
            label: 'おためしミッションクリア。条件を使って思い込みを見破りました。',
            isLiveRegion: true,
          ),
        );
        final retry = find.widgetWithText(OutlinedButton, 'もう一度ためす');
        await tester.scrollUntilVisible(
          retry,
          120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        final retryRect = tester.getRect(retry);
        final retryLabelRect = tester.getRect(find.text('もう一度ためす'));
        expect(retryRect.contains(retryLabelRect.topLeft), isTrue);
        expect(retryRect.contains(retryLabelRect.bottomRight), isTrue);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('何も選ばないうちは進めない', (tester) async {
      await tester.pumpWidget(wrap((_) async => null));
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull, reason: '同意前に押せてしまう');
    });

    testWidgets('年齢未選択でも外部同意を保存せず端末内モードを選べる', (tester) async {
      var agreed = false;
      var localOnly = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: ConsentScreen(
            onAgreed: (_) async {
              agreed = true;
              return null;
            },
            onUseLocalOnly: () => localOnly = true,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('use-local-only-mode')));
      await tester.pump();

      expect(localOnly, isTrue);
      expect(agreed, isFalse);
    });

    testWidgets('18歳以上でも海外送信に同意せず端末内モードを選べる', (tester) async {
      var agreed = false;
      var localOnly = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: ConsentScreen(
            onAgreed: (_) async {
              agreed = true;
              return null;
            },
            onUseLocalOnly: () => localOnly = true,
          ),
        ),
      );

      await tester.tap(find.text('18歳以上'));
      await tester.pump();
      final transferAgreement = find.ancestor(
        of: find.text('上の内容を読んで、会話時の海外送信に同意します'),
        matching: find.byType(CheckboxListTile),
      );
      expect(tester.widget<CheckboxListTile>(transferAgreement).value, isFalse);
      await tester.tap(find.byKey(const ValueKey('use-local-only-mode')));
      await tester.pump();

      expect(localOnly, isTrue);
      expect(agreed, isFalse);
    });

    testWidgets('18歳以上の個人利用は同意処理へ進める', (tester) async {
      ConsentRecord? got;
      await tester.pumpWidget(
        wrap((record) async {
          got = record;
          return null;
        }),
      );
      await tester.tap(find.text('18歳以上'));
      await tester.tap(find.text('上の内容を読んで、会話時の海外送信に同意します'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      await tester.tap(find.text('はじめる'));
      await tester.pumpAndSettle();
      expect(got?.ageBand, AgeBand.adult);
      expect(got?.route, ConsentRoute.self);
      expect(got?.isValid, isTrue);
    });

    testWidgets('15歳以下の本人利用は型付きrouteで個人端末内へ分岐する', (tester) async {
      var called = false;
      var localOnly = false;
      var legacyRestrictedLocal = false;
      RestrictedLocalRoute? restrictedRoute;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: ConsentScreen(
            onAgreed: (_) async {
              called = true;
              return null;
            },
            onUseLocalOnly: () => localOnly = true,
            onUseRestrictedLocal: () => legacyRestrictedLocal = true,
            onUseRestrictedLocalRoute: (route) => restrictedRoute = route,
          ),
        ),
      );
      await tester.tap(find.text('15歳以下'));
      await tester.pumpAndSettle();
      expect(find.text('外部サービスを使うモードは、18歳未満・学校向けに提供していません。'), findsOneWidget);
      expect(find.text('上の内容を読んで、会話時の海外送信に同意します'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('use-local-only-mode')));
      await tester.pumpAndSettle();
      expect(called, isFalse);
      expect(localOnly, isFalse);
      expect(legacyRestrictedLocal, isFalse, reason: '型付きcallbackを優先する');
      expect(restrictedRoute, RestrictedLocalRoute.under18Self);
    });

    testWidgets('旧restricted callbackだけのcallsiteも互換動作する', (tester) async {
      var restrictedLocal = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: ConsentScreen(
            onAgreed: (_) async => null,
            onUseLocalOnly: () {},
            onUseRestrictedLocal: () => restrictedLocal = true,
          ),
        ),
      );

      await tester.tap(find.text('15歳以下'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('use-local-only-mode')));
      await tester.pumpAndSettle();

      expect(restrictedLocal, isTrue);
    });

    testWidgets('16〜17歳は端末内モードだけを示し、同意処理を呼ばない', (tester) async {
      var called = false;
      await tester.pumpWidget(
        wrap((_) async {
          called = true;
          return null;
        }),
      );
      await tester.tap(find.text('16〜17歳'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('use-local-only-mode')), findsOneWidget);
      expect(find.text('はじめる'), findsNothing);
      await tester.pumpAndSettle();
      expect(called, isFalse);
    });

    testWidgets('越境移転の3点が画面に出ている', (tester) async {
      await tester.pumpWidget(wrap((_) async => null));
      for (final (label, _) in kTransferDisclosure) {
        expect(find.text(label), findsOneWidget, reason: '$label が出ていない');
      }
    });

    testWidgets('RevenueCat の送信内容と非送信内容が画面に出る', (tester) async {
      await tester.pumpWidget(wrap((_) async => null));
      expect(find.text('RevenueCat（Plus の購入管理）'), findsOneWidget);
      expect(find.text('RevenueCat へ送らないもの'), findsOneWidget);
      expect(find.text('Plus を使わない間は、RevenueCat SDK を起動しません。'), findsOneWidget);
    });

    testWidgets('学校経路は準備中をlive regionで示し、同意処理を呼ばない', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        var called = false;
        RestrictedLocalRoute? restrictedRoute;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(Brightness.light),
            home: ConsentScreen(
              onAgreed: (_) async {
                called = true;
                return null;
              },
              onUseLocalOnly: () {},
              onUseRestrictedLocalRoute: (route) => restrictedRoute = route,
            ),
          ),
        );

        await tester.tap(find.text('18歳以上'));
        await tester.tap(find.text('学校からもらって使います'));
        await tester.pumpAndSettle();

        expect(called, isFalse);
        expect(find.byType(TextField), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isFalse,
        );
        const message =
            '外部サービスを使うモードは、18歳未満・学校向けに提供していません。'
            '同梱教材を通信せずに使う「端末内モード」なら、今すぐ学べます。'
            '年齢や同意は保存しません。'
            '外部AI・学校サーバ・購入機能へ接続しません。入力した説明は送信・保存せず、'
            '自動採点や理解認定も行いません。';
        final notice = find.bySemanticsLabel(message);
        expect(notice, findsOneWidget);
        expect(
          tester.getSemantics(notice),
          matchesSemantics(label: message, isLiveRegion: true),
        );
        await tester.tap(find.byKey(const ValueKey('use-local-only-mode')));
        await tester.pumpAndSettle();
        expect(restrictedRoute, RestrictedLocalRoute.school);
      } finally {
        semantics.dispose();
      }
    });
  });
}
