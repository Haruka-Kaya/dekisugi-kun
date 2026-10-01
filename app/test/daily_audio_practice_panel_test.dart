import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/learning/services/daily_audio_practice_plan.dart';
import 'package:dekisugi/models/game_hub.dart';
import 'package:dekisugi/screens/practice_hub_screen.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:dekisugi/widgets/daily_audio_practice_panel.dart';
import 'package:flutter_test/flutter_test.dart';

const _listening = DailyAudioMission(
  nodeId: 'path:v1:motion:fall:listening',
  unitId: 'motion',
  conceptKey: 'fall',
  conceptLabel: '落下',
  kind: DailyAudioMissionKind.listening,
  practiceAttempt: 1,
  completedToday: false,
);

const _speaking = DailyAudioMission(
  nodeId: 'path:v1:motion:fall:speaking',
  unitId: 'motion',
  conceptKey: 'fall',
  conceptLabel: '落下',
  kind: DailyAudioMissionKind.speaking,
  practiceAttempt: 2,
  completedToday: false,
);

const _completedListening = DailyAudioMission(
  nodeId: 'path:v1:motion:fall:listening',
  unitId: 'motion',
  conceptKey: 'fall',
  conceptLabel: '落下',
  kind: DailyAudioMissionKind.listening,
  practiceAttempt: 1,
  completedToday: true,
);

const _completedSpeaking = DailyAudioMission(
  nodeId: 'path:v1:motion:fall:speaking',
  unitId: 'motion',
  conceptKey: 'fall',
  conceptLabel: '落下',
  kind: DailyAudioMissionKind.speaking,
  practiceAttempt: 2,
  completedToday: true,
);

Widget _app({
  List<DailyAudioMission> missions = const [_listening, _speaking],
  ValueChanged<DailyAudioMission>? onOpen,
  double textScale = 1,
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  theme: buildAppTheme(brightness),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: child!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      child: DailyAudioPracticePanel(
        plan: DailyAudioPracticePlan(
          learningDay: '2026-08-10',
          missions: missions,
        ),
        onOpen: onOpen ?? (_) {},
      ),
    ),
  ),
);

void main() {
  testWidgets('聞く・話すを別の実ミッションとして起動する', (tester) async {
    DailyAudioMission? opened;
    await tester.pumpWidget(_app(onOpen: (mission) => opened = mission));

    expect(find.bySemanticsLabel(RegExp('今日の「聞く」')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('今日の「話す」')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('daily-audio-listening')));
    expect(opened, same(_listening));
    await tester.tap(find.byKey(const ValueKey('daily-audio-speaking')));
    expect(opened, same(_speaking));
  });

  testWidgets('未解放時は両操作を無効にし、320dp・文字200%でも溢れない', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    var calls = 0;

    await tester.pumpWidget(
      _app(missions: const [], onOpen: (_) => calls++, textScale: 2),
    );
    await tester.pump();

    expect(find.bySemanticsLabel(RegExp('Listeningまで進む')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Speakingまで進む')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('daily-audio-listening')));
    await tester.ensureVisible(
      find.byKey(const ValueKey('daily-audio-speaking')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('daily-audio-speaking')));
    expect(calls, 0);
    expect(
      tester.getSize(find.byKey(const ValueKey('daily-audio-speaking'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('dark themeでも状態を色だけにせず表示する', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(brightness: Brightness.dark));

    expect(find.byIcon(Icons.headphones_rounded), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(find.text('今日の「聞く」'), findsOneWidget);
    expect(find.text('今日の「話す」'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('今日の1件、利用できます')), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('聞く完了・話す未完了を別々に示し、完了後も再練習できる', (tester) async {
    final semantics = tester.ensureSemantics();
    final opened = <DailyAudioMission>[];
    await tester.pumpWidget(
      _app(
        missions: const [_completedListening, _speaking],
        onOpen: opened.add,
      ),
    );

    expect(
      find.byKey(const ValueKey('daily-audio-listening-completed')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('daily-audio-speaking-completed')),
      findsNothing,
    );
    expect(
      find.bySemanticsLabel(RegExp('今日の「聞く」.*今日完了.*もう一度練習')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('今日の「話す」.*今日の1件、利用できます')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('daily-audio-listening')));
    await tester.tap(find.byKey(const ValueKey('daily-audio-speaking')));
    expect(opened, [_completedListening, _speaking]);
    semantics.dispose();
  });

  testWidgets('両方完了でも320dp・文字200%でcheckと再練習を読める', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _app(
        missions: const [_completedListening, _completedSpeaking],
        textScale: 2,
      ),
    );
    await tester.pump();
    await tester.ensureVisible(
      find.byKey(const ValueKey('daily-audio-speaking-replay')),
    );
    await tester.pump();

    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
    expect(
      tester.getSize(find.byKey(const ValueKey('daily-audio-speaking'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('練習ラボ内でも結合カードにせず聞く・話すを別起動する', (tester) async {
    final opened = <DailyAudioMission>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: PracticeHubScreen(
          modes: const <PracticeModeView>[],
          dueCount: 0,
          onOpen: (_) {},
          dailyAudioPlan: const DailyAudioPracticePlan(
            learningDay: '2026-08-10',
            missions: [_listening, _speaking],
          ),
          onOpenDailyAudio: opened.add,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('practice-hub-screen')), findsOneWidget);
    expect(find.text('今日の音声ミッション'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('daily-audio-listening')));
    await tester.tap(find.byKey(const ValueKey('daily-audio-speaking')));
    expect(opened, [_listening, _speaking]);
  });
}
