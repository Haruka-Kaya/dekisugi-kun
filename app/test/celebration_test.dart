import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/motion.dart';
import 'package:dekisugi/models/dossier.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/dossier_bar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Dossier build(Map<String, String> statuses, {int coverage = 0}) =>
    Dossier.fromJson({
      'unitId': 'force-motion',
      'coverage': coverage,
      'slots': [
        for (final e in statuses.entries)
          {
            'key': e.key,
            'label': e.key == 'fall' ? '落下の速さ' : '慣性',
            'status': e.value,
            'content': 'x',
            'evidence': ['u02'],
            'followUpHint': '',
            'probes': const [],
          },
      ],
    });

Widget wrap(Dossier d, {bool reduceMotion = false}) => MaterialApp(
  theme: buildAppTheme(Brightness.light),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: ReduceMotionScope(
      child: Scaffold(body: DossierBar(dossier: d)),
    ),
  ),
);

void main() {
  late List<MethodCall> haptics;

  setUp(() {
    haptics = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') haptics.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('達成の演出', () {
    testWidgets('説明できたに上がったら祝う', (tester) async {
      await tester.pumpWidget(wrap(build({'fall': 'thin'})));
      expect(haptics, isEmpty);

      await tester.pumpWidget(wrap(build({'fall': 'explained'})));
      await tester.pump();
      expect(haptics, hasLength(1), reason: '達成の合図が出ていない');
      expect(find.byKey(const ValueKey('celebrate')), findsOneWidget);

      await tester.pumpWidget(wrap(build({'fall': 'untouched'})));
      await tester.pump(Motion.celebrate * 3);
    });

    testWidgets('下がったときは祝わない', (tester) async {
      await tester.pumpWidget(wrap(build({'fall': 'explained'})));
      await tester.pumpWidget(wrap(build({'fall': 'thin'})));
      await tester.pump();
      expect(haptics, isEmpty);
    });

    testWidgets('同じ状態のままなら祝わない（毎回鳴らさない）', (tester) async {
      await tester.pumpWidget(
        wrap(build({'fall': 'explained'}), reduceMotion: true),
      );
      await tester.pumpWidget(
        wrap(build({'fall': 'explained'}, coverage: 50), reduceMotion: true),
      );
      await tester.pump();
      expect(haptics, isEmpty);
    });

    testWidgets('触覚だけに頼らない — 文字とアイコンが常に出ている', (tester) async {
      // 触覚は Android API 30 未満で鳴らない。中高生の端末は古い可能性が高い
      await tester.pumpWidget(wrap(build({'fall': 'explained'})));
      expect(find.text('落下の速さ'), findsOneWidget);
      expect(find.byIcon(statusIcon(ExplainStatus.gotIt)), findsOneWidget);
    });

    testWidgets('Reduce Motion では拡大しないが、達成は伝わる', (tester) async {
      await tester.pumpWidget(
        wrap(build({'fall': 'thin'}), reduceMotion: true),
      );
      await tester.pumpWidget(
        wrap(build({'fall': 'explained'}), reduceMotion: true),
      );
      await tester.pump();

      // 動かさないだけで、状態そのものは出す
      expect(find.byIcon(statusIcon(ExplainStatus.gotIt)), findsOneWidget);
      expect(find.byKey(const ValueKey('celebrate')), findsNothing);

      await tester.pumpWidget(
        wrap(build({'fall': 'untouched'}), reduceMotion: true),
      );
      await tester.pump(Motion.celebrate * 3);
    });
  });

  group('カルテの表示', () {
    testWidgets('採点に見えるパーセントを生徒へ出さない', (tester) async {
      await tester.pumpWidget(wrap(build({'fall': 'thin'}, coverage: 45)));
      expect(find.text('45%'), findsNothing);
      expect(find.text('いまの会話ノート'), findsOneWidget);
    });

    testWidgets('触れた概念だけ状態のアイコンとラベルを出す', (tester) async {
      await tester.pumpWidget(
        wrap(build({'fall': 'explained', 'inertia': 'untouched'})),
      );
      expect(find.text('落下の速さ'), findsOneWidget);
      expect(find.text('慣性'), findsNothing, reason: 'まだ話していない内容を採点一覧に見せない');
    });
  });
}
