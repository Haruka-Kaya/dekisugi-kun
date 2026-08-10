import 'dart:async';

import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/motion.dart';
import 'package:dekisugi/learning/domain/learning_heart.dart';
import 'package:dekisugi/learning/domain/learning_need.dart';
import 'package:dekisugi/screens/science_listening_screen.dart';
import 'package:dekisugi/services/local_narration.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/science_challenge_fixture.dart';

final class _PendingNarration implements LocalNarration {
  final started = Completer<void>();
  final result = Completer<LocalNarrationResult>();

  @override
  Future<LocalNarrationResult> play(LocalNarrationRequest request) {
    if (!started.isCompleted) started.complete();
    return result.future;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {
    if (!result.isCompleted) {
      result.complete(const LocalNarrationResult.unavailable());
    }
  }
}

Widget _app({
  required LocalNarration narration,
  VoidCallback? onCompleted,
  VoidCallback? onReturnToPath,
  LearningNeedEvidenceReported? onNeedEvidence,
  LearningHeartLossReported? onHeartLoss,
  BundledHumanNarrationAsset? bundledHumanRecording,
  double textScale = 1,
  bool disableAnimations = false,
}) => MaterialApp(
  theme: buildAppTheme(Brightness.light),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: disableAnimations,
    ),
    child: ReduceMotionScope(child: child!),
  ),
  home: ScienceListeningScreen(
    section: challengeSection,
    conceptLabel: '落下の速さ',
    practiceAttempt: challengePracticeAttempt,
    narration: narration,
    bundledHumanRecording: bundledHumanRecording,
    onCompleted: onCompleted ?? () {},
    onReturnToPath: onReturnToPath,
    onNeedEvidence: onNeedEvidence,
    onHeartLoss: onHeartLoss,
  ),
);

Finder get _scroll => find.byType(Scrollable).first;

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 160, scrollable: _scroll);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _transcribeAndOpenMeaning(
  WidgetTester tester, {
  required String transcript,
}) async {
  await tester.enterText(
    find.byKey(const ValueKey('listening-transcription-input')),
    transcript,
  );
  await tester.pump();
  await _tapVisible(tester, find.text('教材の文と比べる'));
  await _tapVisible(
    tester,
    find.byKey(const ValueKey('listening-open-meaning')),
  );
}

void main() {
  testWidgets('読み上げ中は説明ポーズとSemanticsを表示する', (tester) async {
    final semantics = tester.ensureSemantics();
    final narration = _PendingNarration();
    await tester.pumpWidget(_app(narration: narration));

    await _tapVisible(tester, find.text('説明を聞く'));
    await narration.started.future;
    expect(find.bySemanticsLabel(RegExp('デキすぎ君。説明しています')), findsOneWidget);

    narration.result.complete(
      const LocalNarrationResult(
        completed: true,
        delivery: LocalNarrationDelivery.deviceSpeechSynthesis,
      ),
    );
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('デキすぎ君。一緒に考えています')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('音声を最後まで聞く前は正本・文字起こし入力・選択肢を先出ししない', (tester) async {
    final narration = FakeLocalNarration();
    await tester.pumpWidget(_app(narration: narration));

    expect(find.text(challengeCheckpoint.lure), findsNothing);
    expect(
      find.byKey(const ValueKey('listening-option-same-time')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('listening-transcription-input')),
      findsNothing,
    );

    await _tapVisible(tester, find.text('説明を聞く'));

    expect(narration.spoken, [challengeCheckpoint.lure]);
    expect(find.text(challengeCheckpoint.lure), findsNothing);
    expect(
      find.byKey(const ValueKey('listening-transcription-input')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('listening-option-same-time')),
      findsNothing,
    );

    await tester.enterText(
      find.byKey(const ValueKey('listening-transcription-input')),
      challengeCheckpoint.lure,
    );
    await tester.pump();
    await _tapVisible(tester, find.text('教材の文と比べる'));
    expect(find.textContaining(challengeCheckpoint.lure), findsWidgets);
    expect(find.text('聞き取った語が一致'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('listening-option-same-time')),
      findsNothing,
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('listening-open-meaning')),
    );
    expect(
      find.byKey(const ValueKey('listening-option-same-time')),
      findsOneWidget,
    );
  });

  testWidgets('文字起こしの語省略は固定needとheartだけを通知し、本文は渡さない', (tester) async {
    final narration = FakeLocalNarration();
    final needs = <LearningNeedEvidence>[];
    final hearts = <LearningHeartLossEvidence>[];
    await tester.pumpWidget(
      _app(
        narration: narration,
        onNeedEvidence: needs.add,
        onHeartLoss: hearts.add,
      ),
    );
    await _tapVisible(tester, find.text('説明を聞く'));
    await tester.enterText(
      find.byKey(const ValueKey('listening-transcription-input')),
      '重さによらない',
    );
    await tester.pump();
    await _tapVisible(tester, find.text('教材の文と比べる'));

    expect(find.text('聞き取りの差を確認'), findsOneWidget);
    expect(needs, hasLength(1));
    expect(needs.single.conceptKey, challengeSection.conceptKey);
    expect(needs.single.needCode, 'science.fall.listening.transfer.transcript');
    expect(needs.single.kind, LearningNeedEvidenceKind.observed);
    expect(hearts, hasLength(1));
    expect(
      hearts.single.fixedTaskId,
      'listening:$challengePracticeAttempt:transcript',
    );
    expect(hearts.single.fixedTaskId, isNot(contains('重さ')));

    await _tapVisible(
      tester,
      find.byKey(const ValueKey('listening-open-meaning')),
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('listening-option-heavy-first')),
    );
    await _tapVisible(tester, find.text('この判断で比べる'));
    expect(hearts, hasLength(1), reason: '1つのListeningマスでheartを重複消費しない');
    expect(needs, hasLength(2));
    expect(needs.last.needCode, 'science.fall.listening.transfer.meaning');
    expect(needs.last.kind, LearningNeedEvidenceKind.observed);
  });

  testWidgets('誤答は残りを試させずhintから教材訂正へ進み、完了を一度だけ通知する', (tester) async {
    final narration = FakeLocalNarration();
    var completed = 0;
    final needs = <LearningNeedEvidence>[];
    await tester.pumpWidget(
      _app(
        narration: narration,
        onCompleted: () => completed++,
        onNeedEvidence: needs.add,
      ),
    );
    await _tapVisible(tester, find.text('説明を聞く'));
    await _transcribeAndOpenMeaning(
      tester,
      transcript: challengeCheckpoint.lure,
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('listening-option-heavy-first')),
    );
    await _tapVisible(tester, find.text('この判断で比べる'));

    expect(needs, hasLength(2));
    expect(needs.first.conceptKey, 'fall');
    expect(needs.first.needCode, 'science.fall.listening.transfer.transcript');
    expect(needs.first.kind, LearningNeedEvidenceKind.demonstrated);
    expect(needs.last.needCode, 'science.fall.listening.transfer.meaning');
    expect(needs.last.kind, LearningNeedEvidenceKind.observed);

    expect(find.textContaining('別の条件を確認する'), findsWidgets);
    expect(
      find.byKey(const ValueKey('listening-option-light-first')),
      findsNothing,
    );

    await _tapVisible(tester, find.text('教材の訂正と比べる'));
    expect(find.text(challengeCheckpoint.lure), findsOneWidget);
    expect(find.text(challengeCheckpoint.explanation), findsOneWidget);
    expect(completed, 0);

    await _tapVisible(tester, find.text('聞き取りを完了する'));
    await tester.tap(find.text('LISTEN LAB COMPLETE'));
    await tester.pump();
    expect(completed, 1);
  });

  testWidgets('文字起こしと意味の成功を別々の専用needで報告する', (tester) async {
    final narration = FakeLocalNarration();
    final needs = <LearningNeedEvidence>[];
    await tester.pumpWidget(
      _app(narration: narration, onNeedEvidence: needs.add),
    );
    await _tapVisible(tester, find.text('説明を聞く'));
    await _transcribeAndOpenMeaning(
      tester,
      transcript: challengeCheckpoint.lure,
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('listening-option-same-time')),
    );
    await _tapVisible(tester, find.text('この判断で比べる'));

    expect(needs.map((evidence) => (evidence.needCode, evidence.kind)), const [
      (
        'science.fall.listening.transfer.transcript',
        LearningNeedEvidenceKind.demonstrated,
      ),
      (
        'science.fall.listening.transfer.meaning',
        LearningNeedEvidenceKind.demonstrated,
      ),
    ]);
  });

  testWidgets('端末TTSが無い文字経路はListening完了・need・reward callbackにしない', (
    tester,
  ) async {
    final narration = FakeLocalNarration(available: false);
    var completed = 0;
    final needs = <LearningNeedEvidence>[];
    await tester.pumpWidget(
      _app(
        narration: narration,
        onCompleted: () => completed++,
        onNeedEvidence: needs.add,
      ),
    );
    await _tapVisible(tester, find.text('説明を聞く'));

    expect(find.text('読み上げを使えませんでした'), findsOneWidget);
    expect(find.text(challengeCheckpoint.lure), findsOneWidget);
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('listening-text-fallback')),
    );
    expect(
      find.byKey(const ValueKey('listening-option-same-time')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('listening-transcription-input')),
      findsNothing,
      reason: '音声未確認で表示した正本の書き写しをListening成功にしない',
    );
    expect(find.text('文字教材（Listeningとは別の学習）'), findsOneWidget);
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('listening-option-same-time')),
    );
    await _tapVisible(tester, find.text('この判断で比べる'));
    await _tapVisible(tester, find.text('文字教材の確認を終える'));
    expect(find.text('文字教材の確認を完了'), findsOneWidget);
    expect(find.text('LISTEN LAB COMPLETE'), findsNothing);
    expect(completed, 0);
    expect(needs, isEmpty);
  });

  testWidgets('同梱録音と端末TTSを同じ声として表示しない', (tester) async {
    final recording = BundledHumanNarrationAsset(
      path: 'assets/audio/listening/fall-foundation.m4a',
      transcript: challengeCheckpoint.lure,
      narratorLabel: '理科教材ナレーター',
    );
    final narration = FakeLocalNarration(humanRecordingAvailable: true);
    await tester.pumpWidget(
      _app(narration: narration, bundledHumanRecording: recording),
    );

    expect(find.textContaining('理科教材ナレーターの録音'), findsOneWidget);
    await _tapVisible(tester, find.text('説明を聞く'));
    expect(find.textContaining('同梱された人の録音を聞きました'), findsOneWidget);
    expect(narration.requests.single.bundledHumanRecording, same(recording));
  });

  testWidgets('320x568・文字200%でListen全経路が操作でき、route終了で音声を破棄する', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    final narration = FakeLocalNarration();
    var returned = 0;
    await tester.pumpWidget(
      _app(
        narration: narration,
        textScale: 2,
        disableAnimations: true,
        onReturnToPath: () => returned++,
      ),
    );

    await _tapVisible(tester, find.text('説明を聞く'));
    expect(
      find.bySemanticsLabel(RegExp('聞こえた文の文字起こし.*保存も送信もしません')),
      findsOneWidget,
    );
    await _transcribeAndOpenMeaning(
      tester,
      transcript: challengeCheckpoint.lure,
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('listening-option-same-time')),
    );
    await _tapVisible(tester, find.text('この判断で比べる'));
    await _tapVisible(tester, find.text('聞き取りを完了する'));
    final back = find.byKey(const ValueKey('listening-return-to-path'));
    await tester.scrollUntilVisible(back, 160, scrollable: _scroll);
    await tester.pump();
    expect(tester.getSize(back).height, greaterThanOrEqualTo(48));
    await tester.tap(back);
    await tester.pump();
    expect(returned, 1);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(narration.disposed, isTrue);
    semantics.dispose();
  });
}
