import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/models/dossier.dart';
import 'package:dekisugi/models/mission.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/mission_ui.dart';
import 'package:flutter_test/flutter_test.dart';

Slot slot({
  SlotStatus status = SlotStatus.untouched,
  List<String> evidence = const [],
  List<Probe> probes = const [],
}) => Slot(
  key: 'fall',
  label: '落下の速さ',
  status: status,
  content: '',
  evidence: evidence,
  followUpHint: '',
  probes: probes,
);

Dossier dossier(Slot slot) =>
    Dossier(unitId: 'force-motion', slots: [slot], coverage: 0);

Probe probe(ProbeResult result) =>
    Probe(id: 'M01', result: result, evidence: const ['u01']);

Widget wrap({
  required Dossier? dossier,
  String? lastLureId,
  String? challengeText,
  MissionKind missionKind = MissionKind.teach,
  double textScale = 1,
}) => MaterialApp(
  theme: buildAppTheme(Brightness.light),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(
    body: TeachingMissionBoard(
      conceptKey: 'fall',
      conceptLabel: '落下の速さ',
      tactic: TeachingTactic.example,
      dossier: dossier,
      lastLureId: lastLureId,
      missionKind: missionKind,
      challengeText: challengeText,
    ),
  ),
);

void main() {
  group('ミッション進行', () {
    test('操作回数ではなくDossierの学習証拠だけで進む', () {
      expect(
        missionSnapshotFor(conceptKey: 'fall', dossier: null).phase,
        MissionPhase.teach,
      );
      expect(
        missionSnapshotFor(
          conceptKey: 'fall',
          dossier: dossier(
            slot(status: SlotStatus.explained, evidence: const ['u01']),
          ),
        ).phase,
        MissionPhase.challenge,
      );
      expect(
        missionSnapshotFor(
          conceptKey: 'fall',
          dossier: dossier(
            slot(status: SlotStatus.thin, evidence: const ['u01']),
          ),
        ).phase,
        MissionPhase.teach,
        reason: 'まだ説明を整えている途中で、思い込みが出たように見せない',
      );
      expect(
        missionSnapshotFor(
          conceptKey: 'fall',
          dossier: dossier(
            slot(
              status: SlotStatus.explained,
              evidence: const ['u01'],
              probes: [probe(ProbeResult.accepted)],
            ),
          ),
        ).phase,
        MissionPhase.resolve,
      );
      expect(
        missionSnapshotFor(
          conceptKey: 'fall',
          dossier: dossier(
            slot(
              status: SlotStatus.explained,
              evidence: const ['u01'],
              probes: [probe(ProbeResult.corrected)],
            ),
          ),
        ).phase,
        MissionPhase.clear,
      );

      expect(
        missionSnapshotFor(
          conceptKey: 'fall',
          dossier: dossier(
            slot(
              status: SlotStatus.thin,
              evidence: const ['u01'],
              probes: [probe(ProbeResult.corrected)],
            ),
          ),
        ).phase,
        MissionPhase.resolve,
        reason: '思い込みを否定しただけで、概念を説明できていない',
      );
    });

    test('対象外の概念が説明済みでも進まない', () {
      final other = Slot(
        key: 'inertia',
        label: '慣性',
        status: SlotStatus.explained,
        content: '',
        evidence: const ['u01'],
        followUpHint: '',
        probes: [probe(ProbeResult.corrected)],
      );
      expect(
        missionSnapshotFor(conceptKey: 'fall', dossier: dossier(other)).phase,
        MissionPhase.teach,
      );
    });
  });

  group('ミッションHUD', () {
    testWidgets('教え始める前は作戦と最初の行動を示す', (tester) async {
      await tester.pumpWidget(wrap(dossier: null));

      expect(find.textContaining('MISSION 1/3'), findsOneWidget);
      expect(find.text('まず、自分の言葉で教える'), findsOneWidget);
      expect(find.textContaining('身近な例から'), findsOneWidget);
      expect(find.textContaining('ポイント'), findsNothing);
      expect(find.textContaining('XP'), findsNothing);
    });

    testWidgets('訂正できなかった観測を失敗と断定せず、決着の行動を示す', (tester) async {
      await tester.pumpWidget(
        wrap(
          dossier: dossier(
            slot(
              status: SlotStatus.explained,
              evidence: const ['u01'],
              probes: [probe(ProbeResult.accepted)],
            ),
          ),
        ),
      );

      expect(find.text('まだ決着していない'), findsOneWidget);
      expect(find.textContaining('どちらがなぜ正しいか'), findsOneWidget);
      expect(find.textContaining('失敗'), findsNothing);
      expect(find.textContaining('間違い'), findsNothing);
    });

    testWidgets('AIの反論を通常ノートではなくLAST CHALLENGEとして示す', (tester) async {
      await tester.pumpWidget(
        wrap(
          dossier: dossier(
            slot(status: SlotStatus.explained, evidence: const ['u01']),
          ),
          lastLureId: 'M01',
          challengeText: '重いものの方が速く落ちるってこと？',
        ),
      );

      expect(find.textContaining('LAST CHALLENGE'), findsOneWidget);
      expect(find.textContaining('重いものの方が速く落ちる'), findsOneWidget);
      expect(find.text('デキすぎ君の思い込みを見破る'), findsOneWidget);
    });

    testWidgets('320dp・文字200%でも3段階と現在の行動を読める', (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          dossier: dossier(
            slot(
              status: SlotStatus.explained,
              evidence: const ['u01'],
              probes: [probe(ProbeResult.corrected)],
            ),
          ),
          textScale: 2,
        ),
      );

      expect(find.textContaining('MISSION CLEAR'), findsOneWidget);
      expect(find.text('思い込みを見破った'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CASEは別場面への適用を明示し、定義の言い直しにしない', (tester) async {
      await tester.pumpWidget(
        wrap(dossier: null, missionKind: MissionKind.caseRetry),
      );

      expect(find.textContaining('CASE 1/3'), findsOneWidget);
      expect(find.text('場面の結果を予想する'), findsOneWidget);
      expect(find.textContaining('何が起きるか'), findsOneWidget);
      expect(find.text('まず、自分の言葉で教える'), findsNothing);
    });

    testWidgets('CASE CLEARは別場面でも使えた成果として示す', (tester) async {
      await tester.pumpWidget(
        wrap(
          missionKind: MissionKind.caseRetry,
          dossier: dossier(
            slot(
              status: SlotStatus.explained,
              evidence: const ['u01'],
              probes: [probe(ProbeResult.corrected)],
            ),
          ),
        ),
      );

      expect(find.textContaining('CASE CLEAR'), findsOneWidget);
      expect(find.text('別の場面でも使えた'), findsOneWidget);
      expect(find.textContaining('次は間隔を空けて'), findsOneWidget);
    });

    testWidgets('REPAIRは前回の曖昧さを組み直す課題として示す', (tester) async {
      await tester.pumpWidget(
        wrap(dossier: null, missionKind: MissionKind.repair),
      );

      expect(find.textContaining('REPAIR 1/3'), findsOneWidget);
      expect(find.text('決着点を組み直す'), findsOneWidget);
    });
  });
}
