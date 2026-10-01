import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/motion.dart';
import 'package:dekisugi/learning/domain/learning_heart.dart';
import 'package:dekisugi/learning/domain/learning_need.dart';
import 'package:dekisugi/learning/services/local_companion_voice.dart';
import 'package:dekisugi/models/unit.dart';
import 'package:dekisugi/screens/science_speak_listen_screen.dart';
import 'package:dekisugi/services/local_narration.dart';
import 'package:dekisugi/services/local_pronunciation_practice.dart';
import 'package:dekisugi/services/local_voice_practice.dart';
import 'package:dekisugi/services/mic_stream.dart';
import 'package:dekisugi/services/pcm_player.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:flutter_test/flutter_test.dart';

const _task = LocalCognitiveTask(
  kind: LocalCognitiveTaskKind.singleSelect,
  operation: LocalCognitiveOperation.prediction,
  needCode: 'science.fall.foundation',
  items: [
    LocalCognitiveTaskItem(id: 'heavy-a', text: '重い球が先'),
    LocalCognitiveTaskItem(id: 'same-a', text: '同時'),
  ],
  targets: [],
  solution: LocalSingleSelectSolution(selectedItemId: 'same-a'),
);

LocalCheckpoint _checkpoint(LocalPracticeStage stage) {
  final needCode = 'science.fall.${stage.wire}';
  return LocalCheckpoint(
    lure: '${stage.wire}：重い球ほど先に着く。',
    options: [
      LocalCheckpointOption(
        id: 'heavy',
        text: '重い球が先に着く。',
        hint: '動かしにくさも比べます。',
        needCode: needCode,
      ),
      const LocalCheckpointOption(id: 'same', text: '同時に着く。'),
      LocalCheckpointOption(
        id: 'light',
        text: '軽い球が先に着く。',
        hint: '軽さだけでは決まりません。',
        needCode: needCode,
      ),
    ],
    correctOptionId: 'same',
    explanation: '${stage.wire}：落下加速度は重さによりません。',
  );
}

LocalPracticeVariant _variant(LocalPracticeStage stage, String marker) =>
    LocalPracticeVariant(
      stage: stage,
      recallPrompt: '$marker：原理を教材なしで思い出してください。',
      reasoningPrompt: '$marker：理由と成立条件を足してください。',
      transferPrompt: '$marker：別の場面で起きることを予想してください。',
      // 聞き取り確認のcue正本。説明はこれらの言葉を点在させて届く。
      expectedOutcome: '$marker：空気抵抗を無視すれば落下の速さは重さによらない。',
      expectedReason: '$marker：重力と空気抵抗で落下が変わる。',
      cognitiveTask: _task,
      checkpoint: _checkpoint(stage),
    );

final _section = Section(
  conceptKey: 'fall',
  title: '落下の速さ',
  body: const ['この本文は説明中に表示してはいけません。'],
  tryIt: '落下を比べる。',
  localCheckpoint: _checkpoint(LocalPracticeStage.foundation),
  localSpeakingPractice: const LocalSpeakingPractice(
    targetPhrase: '空気抵抗を無視すれば落下の速さは重さによらない',
    acceptedTranscripts: ['空気抵抗を無視すれば落下の速さは重さによらない'],
  ),
  localPracticeVariants: [
    _variant(LocalPracticeStage.foundation, 'A'),
    _variant(LocalPracticeStage.conditions, 'B'),
    _variant(LocalPracticeStage.transfer, 'C'),
  ],
);

class _FakeMic extends MicStream {
  _FakeMic({this.allowed = true});

  bool allowed;
  Completer<bool>? startGate;
  int? throwOnStartCall;
  bool throwOnEveryStop = false;
  bool throwOnDisposeAfterCleanup = false;
  bool preserveStartedOnDisposeFailure = false;
  final disposeCleanupCompleted = Completer<void>();
  final _chunks = StreamController<Uint8List>.broadcast();
  final _levels = StreamController<double>.broadcast();
  bool started = false;
  bool disposed = false;
  int startCalls = 0;
  int stopCalls = 0;

  @override
  Stream<Uint8List> get chunks => _chunks.stream;

  @override
  Stream<double> get level => _levels.stream;

  @override
  bool get isRecording => started;

  @override
  Future<bool> start({bool speakerphone = true}) async {
    startCalls++;
    if (throwOnStartCall == startCalls) throw StateError('mic start failed');
    final result = startGate == null ? allowed : await startGate!.future;
    started = result;
    return result;
  }

  @override
  Future<void> stop() {
    stopCalls++;
    if (throwOnEveryStop) {
      return Future<void>.error(StateError('mic stop failed'));
    }
    started = false;
    return Future<void>.value();
  }

  void emit(int bytes) => _chunks.add(Uint8List(bytes));

  void fail() => _chunks.addError(StateError('mic failed'));

  @override
  Future<void> dispose() async {
    disposed = true;
    if (!preserveStartedOnDisposeFailure) started = false;
    await _chunks.close();
    await _levels.close();
    disposeCleanupCompleted.complete();
    if (throwOnDisposeAfterCleanup) {
      throw StateError('mic dispose failed');
    }
  }
}

class _FakeSink implements PcmSink {
  void Function(int)? callback;
  int? sampleRate;
  int startCalls = 0;
  bool released = false;
  bool throwOnFeed = false;

  void requestFeed([int remainingFrames = 0]) {
    callback?.call(remainingFrames);
  }

  @override
  Future<void> setLogLevel(LogLevel level) async {}

  @override
  Future<void> setup({
    required int sampleRate,
    required int channelCount,
  }) async {
    this.sampleRate = sampleRate;
  }

  @override
  Future<void> setFeedThreshold(int frames) async {}

  @override
  void setFeedCallback(void Function(int remainingFrames)? cb) {
    callback = cb;
  }

  @override
  Future<void> feed(PcmArrayInt16 buffer) async {
    if (throwOnFeed) throw StateError('player feed failed');
  }

  @override
  void start() => startCalls++;

  @override
  Future<void> release() async => released = true;
}

class _FixedEngine implements CompanionVoiceEngine {
  _FixedEngine(this.ack);

  final String ack;
  int calls = 0;

  @override
  Future<String?> generateAck({
    required String explanation,
    required List<String> heardTerms,
    required String conceptLabel,
  }) async {
    calls++;
    return ack;
  }
}

/// デフォルトは「落下と重力」が届く認識成功を返す。
class _FakeEchoRecognizer implements OnDeviceSpeechRecognizer {
  _FakeEchoRecognizer({
    this.result = const OnDeviceSpeechResult(
      status: OnDeviceSpeechStatus.recognized,
      candidates: ['落下と重力の関係を説明した'],
    ),
  });

  OnDeviceSpeechResult result;
  int recognizeCalls = 0;

  @override
  Future<OnDeviceSpeechResult> recognize({
    String languageTag = 'ja-JP',
  }) async {
    recognizeCalls++;
    return result;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}

class _HoldingNarration implements LocalNarration {
  final List<LocalNarrationRequest> requests = [];
  Completer<LocalNarrationResult>? _pending;
  int stopCount = 0;
  bool disposed = false;

  @override
  Future<LocalNarrationResult> play(LocalNarrationRequest request) {
    requests.add(request);
    _pending = Completer<LocalNarrationResult>();
    return _pending!.future;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    final pending = _pending;
    if (pending != null && !pending.isCompleted) {
      pending.complete(const LocalNarrationResult.unavailable());
    }
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await stop();
  }
}

class _SynchronouslyFailingNarration implements LocalNarration {
  bool disposeCalled = false;
  final disposeAttempted = Completer<void>();

  @override
  Future<LocalNarrationResult> play(LocalNarrationRequest request) =>
      Future<LocalNarrationResult>.value(
        const LocalNarrationResult.unavailable(),
      );

  @override
  Future<void> stop() => Future<void>.value();

  @override
  Future<void> dispose() {
    disposeCalled = true;
    disposeAttempted.complete();
    throw StateError('narration dispose failed');
  }
}

({LocalVoicePractice practice, _FakeMic mic, _FakeSink sink}) _voice({
  bool allowed = true,
}) {
  final mic = _FakeMic(allowed: allowed);
  final sink = _FakeSink();
  return (
    practice: LocalVoicePractice(
      mic: mic,
      player: PcmPlayer(sink: sink, playbackSampleRate: MicStream.sampleRate),
    ),
    mic: mic,
    sink: sink,
  );
}

Widget _wrap({
  int practiceAttempt = 0,
  required LocalVoicePractice voice,
  LocalNarration? narration,
  OnDeviceSpeechRecognizer? speechRecognizer,
  VoidCallback? onCompleted,
  VoidCallback? onReturnToPath,
  LearningNeedEvidenceReported? onNeedEvidence,
  LearningHeartLossReported? onHeartLoss,
  double textScale = 1,
  bool disableAnimations = false,
  Brightness brightness = Brightness.light,
  CompanionVoice? companionVoice,
  Future<bool> Function()? supporterCheck,
}) => MaterialApp(
  theme: buildAppTheme(brightness),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: disableAnimations,
    ),
    child: ReduceMotionScope(child: child!),
  ),
  home: ScienceSpeakListenScreen(
    section: _section,
    conceptLabel: '落下の速さ',
    practiceAttempt: practiceAttempt,
    onCompleted: onCompleted ?? () {},
    onReturnToPath: onReturnToPath,
    onNeedEvidence: onNeedEvidence,
    onHeartLoss: onHeartLoss,
    narration: narration ?? FakeLocalNarration(),
    voicePractice: voice,
    speechRecognizer: speechRecognizer ?? _FakeEchoRecognizer(),
    companionVoice: companionVoice,
    supporterCheck: supporterCheck,
  ),
);

Finder get _pageScroll => find.byType(Scrollable).first;

Future<void> _tapVisible(WidgetTester tester, Key key) async {
  final target = find.byKey(key);
  await tester.scrollUntilVisible(target, 180, scrollable: _pageScroll);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
}

Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

Future<void> _teachByText(
  WidgetTester tester,
  String text, {
  bool chooseRoute = true,
}) async {
  if (chooseRoute) {
    await _tapVisible(tester, const ValueKey('science-explain-choose-text'));
  }
  final field = find.byKey(const ValueKey('science-explain-text-input'));
  await tester.enterText(field, text);
  await tester.pump();
  await _tapVisible(tester, const ValueKey('science-explain-review-text'));
  await _tapVisible(tester, const ValueKey('science-explain-submit-text'));
  await _flush(tester);
}

Future<void> _recordVoiceAndFinishPlayback(
  WidgetTester tester,
  ({LocalVoicePractice practice, _FakeMic mic, _FakeSink sink}) audio, {
  bool chooseRoute = true,
}) async {
  if (chooseRoute) {
    await _tapVisible(tester, const ValueKey('science-explain-choose-voice'));
  }
  await _tapVisible(tester, const ValueKey('science-explain-start-recording'));
  await _flush(tester);
  audio.mic.emit(3200);
  await _flush(tester);
  await _tapVisible(tester, const ValueKey('science-explain-stop-recording'));
  await _flush(tester);
  await _tapVisible(tester, const ValueKey('science-explain-play-recording'));
  audio.sink.requestFeed();
  audio.sink.requestFeed();
  await _flush(tester);
  audio.sink.requestFeed();
  await _flush(tester);
}

/// 聞き取り確認を通過する。fake認識器はcue付き成功を返す前提。
Future<void> _passEcho(WidgetTester tester) async {
  await _flush(tester);
  await _tapVisible(tester, const ValueKey('science-explain-echo-advance'));
  await _flush(tester);
}

Future<void> _answerFollowUp(WidgetTester tester, String optionId) async {
  await _tapVisible(
    tester,
    ValueKey('science-explain-follow-up-option-$optionId'),
  );
  await _tapVisible(tester, const ValueKey('science-explain-submit-follow-up'));
  await _flush(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('conditionsではreasoning 1問だけを出し、targetPhrase・正本・問い返しを隠す', (
    tester,
  ) async {
    final audio = _voice();
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(practiceAttempt: 1, voice: audio.practice));

    final active = _section.localPracticeVariants[1];
    expect(find.text(active.reasoningPrompt), findsOneWidget);
    expect(find.text(active.recallPrompt), findsNothing);
    expect(find.text(active.transferPrompt), findsNothing);
    expect(
      find.text(_section.localPracticeVariants[0].recallPrompt),
      findsNothing,
    );
    expect(
      find.text(_section.localSpeakingPractice!.targetPhrase),
      findsNothing,
    );
    expect(find.text(active.expectedOutcome), findsNothing);
    expect(find.text(active.expectedReason), findsNothing);
    expect(find.text(active.checkpoint.lure), findsNothing);
    expect(find.text(active.checkpoint.optionFor('same')!.text), findsNothing);
    expect(find.text(_section.body.first), findsNothing);
    expect(find.bySemanticsLabel(RegExp('教材との振り返り.*B：教材の観察結果')), findsNothing);

    await _tapVisible(tester, const ValueKey('science-explain-choose-text'));
    await tester.enterText(
      find.byKey(const ValueKey('science-explain-text-input')),
      '自分の説明',
    );
    await tester.pump();
    expect(find.text(active.expectedOutcome), findsNothing);
    expect(find.text(active.checkpoint.lure), findsNothing);
    expect(find.text(_section.body.first), findsNothing);
    semantics.dispose();
  });

  for (final testCase
      in <({int attempt, String expected, List<String> hidden})>[
        (
          attempt: 0,
          expected: _section.localPracticeVariants[0].recallPrompt,
          hidden: [
            _section.localPracticeVariants[0].reasoningPrompt,
            _section.localPracticeVariants[0].transferPrompt,
          ],
        ),
        (
          attempt: 1,
          expected: _section.localPracticeVariants[1].reasoningPrompt,
          hidden: [
            _section.localPracticeVariants[1].recallPrompt,
            _section.localPracticeVariants[1].transferPrompt,
          ],
        ),
        (
          attempt: 2,
          expected: _section.localPracticeVariants[2].transferPrompt,
          hidden: [
            _section.localPracticeVariants[2].recallPrompt,
            _section.localPracticeVariants[2].reasoningPrompt,
          ],
        ),
      ]) {
    testWidgets('practiceAttempt ${testCase.attempt} はstage対応の主質問1件だけを表示する', (
      tester,
    ) async {
      final audio = _voice();
      await tester.pumpWidget(
        _wrap(practiceAttempt: testCase.attempt, voice: audio.practice),
      );

      expect(find.text(testCase.expected), findsOneWidget);
      for (final hidden in testCase.hidden) {
        expect(find.text(hidden), findsNothing);
      }
    });
  }

  testWidgets('文字で教えると表示済み固定質問だけを読み、正解need後も比較完了まで保存しない', (tester) async {
    final audio = _voice();
    final narration = FakeLocalNarration();
    final needs = <LearningNeedEvidence>[];
    final hearts = <LearningHeartLossEvidence>[];
    var completed = 0;
    await tester.pumpWidget(
      _wrap(
        voice: audio.practice,
        narration: narration,
        onNeedEvidence: needs.add,
        onHeartLoss: hearts.add,
        onCompleted: () => completed++,
      ),
    );

    const answer = '空気抵抗を無視すると重さによらず、形や空気の条件も見る。';
    await _teachByText(tester, answer);

    final question =
        '教えてくれてありがとう。デキすぎ君から一問。'
        '${_checkpoint(LocalPracticeStage.foundation).lure} '
        'この考えを科学的に直しているのはどれ？';
    expect(
      find.byKey(const ValueKey('science-explain-follow-up')),
      findsOneWidget,
    );
    expect(find.text(question), findsOneWidget);
    expect(narration.spoken, [question]);
    expect(narration.spoken.single, isNot(contains('教材の観察結果')));
    expect(
      narration.spoken.single,
      isNot(contains(_section.localSpeakingPractice!.targetPhrase)),
    );
    expect(completed, 0);

    await _answerFollowUp(tester, 'same');

    expect(needs, hasLength(1));
    expect(needs.single.conceptKey, 'fall');
    expect(needs.single.needCode, 'science.fall.foundation');
    expect(needs.single.kind, LearningNeedEvidenceKind.demonstrated);
    expect(hearts, isEmpty);
    expect(
      find.text(_section.localPracticeVariants.first.expectedOutcome),
      findsOneWidget,
    );
    expect(
      find.text(_section.localPracticeVariants.first.expectedReason),
      findsOneWidget,
    );
    expect(find.text('同時に着く。'), findsOneWidget);
    expect(find.text('foundation：落下加速度は重さによりません。'), findsOneWidget);
    expect(completed, 0, reason: '比較を表示しただけでは進捗を保存しない');

    final keep = find.byKey(const ValueKey('science-explain-keep'));
    await tester.scrollUntilVisible(keep, 180, scrollable: _pageScroll);
    await tester.pump();
    await tester.tap(keep);
    await tester.tap(keep);
    await _flush(tester);

    expect(completed, 1);
    expect(
      find.byKey(const ValueKey('science-explain-finished')),
      findsOneWidget,
    );
    expect(find.textContaining(answer), findsNothing);
    expect(find.textContaining('選択した答えは保存していません'), findsOneWidget);
  });

  testWidgets('誤答はobserved needとheartを各1回だけ出し、選び直さず文字で言い直す', (tester) async {
    final audio = _voice();
    final needs = <LearningNeedEvidence>[];
    final hearts = <LearningHeartLossEvidence>[];
    var completed = 0;
    await tester.pumpWidget(
      _wrap(
        voice: audio.practice,
        onNeedEvidence: needs.add,
        onHeartLoss: hearts.add,
        onCompleted: () => completed++,
      ),
    );
    await _teachByText(tester, '重いほど速く落ちると思う。');
    await _answerFollowUp(tester, 'heavy');

    expect(needs, hasLength(1));
    expect(needs.single.kind, LearningNeedEvidenceKind.observed);
    expect(needs.single.needCode, 'science.fall.foundation');
    expect(hearts, hasLength(1));
    expect(hearts.single.fixedTaskId, 'speaking:0:follow-up');
    expect(find.text('動かしにくさも比べます。'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('science-explain-follow-up-option-same')),
      findsNothing,
      reason: '誤答後に残りの選択肢を総当たりさせない',
    );
    expect(find.text('同時に着く。'), findsNothing);
    expect(
      find.text(_section.localPracticeVariants.first.expectedOutcome),
      findsNothing,
    );
    expect(completed, 0);

    await _tapVisible(tester, const ValueKey('science-explain-start-revision'));
    expect(
      find.byKey(const ValueKey('science-explain-use-voice')),
      findsNothing,
      reason: '誤答後は最初に選んだ文字経路で言い直す',
    );
    final review = find.byKey(const ValueKey('science-explain-review-text'));
    expect(tester.widget<FilledButton>(review).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('science-explain-text-input')),
      '空気抵抗を無視すると、重さによらず同時に落ちる。',
    );
    await tester.pump();
    await _tapVisible(tester, const ValueKey('science-explain-review-text'));
    await _tapVisible(tester, const ValueKey('science-explain-submit-text'));
    await _flush(tester);

    expect(find.text('言い直した説明と、教材を比べる'), findsOneWidget);
    expect(needs, hasLength(1));
    expect(hearts, hasLength(1));
    expect(completed, 0);
    await _tapVisible(tester, const ValueKey('science-explain-keep'));
    await _flush(tester);
    expect(completed, 1);
  });

  testWidgets('声は実feedとdrainが終わるまで問い返しへ進めない', (tester) async {
    final audio = _voice();
    await tester.pumpWidget(_wrap(voice: audio.practice));
    await _tapVisible(tester, const ValueKey('science-explain-choose-voice'));
    await _tapVisible(
      tester,
      const ValueKey('science-explain-start-recording'),
    );
    await _flush(tester);
    audio.mic.emit(3200);
    await _flush(tester);
    await _tapVisible(tester, const ValueKey('science-explain-stop-recording'));
    await _flush(tester);

    final submit = find.byKey(const ValueKey('science-explain-submit-voice'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await _tapVisible(tester, const ValueKey('science-explain-play-recording'));
    expect(audio.sink.sampleRate, 16000);
    expect(audio.sink.startCalls, 1);
    expect(audio.practice.snapshot.playbackCompleted, isFalse);
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.pump(const Duration(milliseconds: 120));
    expect(audio.practice.snapshot.playbackCompleted, isFalse);
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    audio.sink.requestFeed();
    audio.sink.requestFeed();
    await _flush(tester);
    expect(audio.practice.snapshot.playbackCompleted, isFalse);
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    audio.sink.requestFeed();
    await _flush(tester);
    expect(audio.practice.snapshot.playbackCompleted, isTrue);
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);

    await _tapVisible(tester, const ValueKey('science-explain-submit-voice'));
    await _passEcho(tester);
    expect(
      find.byKey(const ValueKey('science-explain-follow-up')),
      findsOneWidget,
    );
  });

  testWidgets('声の誤答は同じ声で再録・自然再生してからだけ比較できる', (tester) async {
    final audio = _voice();
    final needs = <LearningNeedEvidence>[];
    final hearts = <LearningHeartLossEvidence>[];
    await tester.pumpWidget(
      _wrap(
        voice: audio.practice,
        onNeedEvidence: needs.add,
        onHeartLoss: hearts.add,
      ),
    );
    await _recordVoiceAndFinishPlayback(tester, audio);
    await _tapVisible(tester, const ValueKey('science-explain-submit-voice'));
    await _passEcho(tester);
    await _answerFollowUp(tester, 'light');
    await _tapVisible(tester, const ValueKey('science-explain-start-revision'));

    expect(
      find.byKey(const ValueKey('science-explain-use-text')),
      findsNothing,
    );
    await _tapVisible(
      tester,
      const ValueKey('science-explain-start-recording'),
    );
    await _flush(tester);
    audio.mic.emit(3200);
    await _flush(tester);
    await _tapVisible(tester, const ValueKey('science-explain-stop-recording'));
    await _flush(tester);
    final submit = find.byKey(const ValueKey('science-explain-submit-voice'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await _tapVisible(tester, const ValueKey('science-explain-play-recording'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    audio.sink.requestFeed();
    audio.sink.requestFeed();
    await _flush(tester);
    audio.sink.requestFeed();
    await _flush(tester);
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    await _tapVisible(tester, const ValueKey('science-explain-submit-voice'));
    await _passEcho(tester);

    expect(find.text('言い直した説明と、教材を比べる'), findsOneWidget);
    expect(needs, hasLength(1));
    expect(needs.single.kind, LearningNeedEvidenceKind.observed);
    expect(hearts, hasLength(1));
  });

  for (final failure in <String>['permissionDenied', 'failed']) {
    testWidgets('voice revisionの$failure時だけ文字の言い直しへ退避できる', (tester) async {
      final audio = _voice();
      final needs = <LearningNeedEvidence>[];
      final hearts = <LearningHeartLossEvidence>[];
      await tester.pumpWidget(
        _wrap(
          voice: audio.practice,
          onNeedEvidence: needs.add,
          onHeartLoss: hearts.add,
        ),
      );
      await _recordVoiceAndFinishPlayback(tester, audio);
      await _tapVisible(tester, const ValueKey('science-explain-submit-voice'));
      await _passEcho(tester);
      await _answerFollowUp(tester, 'heavy');
      await _tapVisible(
        tester,
        const ValueKey('science-explain-start-revision'),
      );

      expect(
        find.byKey(const ValueKey('science-explain-use-text')),
        findsNothing,
        reason: 'voice revisionは通常、同じ音声経路に固定する',
      );
      if (failure == 'permissionDenied') {
        audio.mic.allowed = false;
      } else {
        audio.mic.throwOnStartCall = 2;
      }
      await _tapVisible(
        tester,
        const ValueKey('science-explain-start-recording'),
      );
      await _flush(tester);
      expect(
        audio.practice.snapshot.state,
        failure == 'permissionDenied'
            ? LocalVoicePracticeState.permissionDenied
            : LocalVoicePracticeState.failed,
      );
      if (failure == 'failed') {
        final startAgain = find.byKey(
          const ValueKey('science-explain-start-recording'),
        );
        expect(
          tester.widget<FilledButton>(startAgain).onPressed,
          isNotNull,
          reason: '2回目start例外後も_voiceBusyをfinallyで解除する',
        );
      }
      expect(find.text('文字で言い直す'), findsOneWidget);
      expect(find.text('動かしにくさも比べます。'), findsOneWidget);
      expect(needs, hasLength(1));
      expect(needs.single.kind, LearningNeedEvidenceKind.observed);
      expect(hearts, hasLength(1));
      expect(hearts.single.fixedTaskId, 'speaking:0:follow-up');

      await _tapVisible(tester, const ValueKey('science-explain-use-text'));
      expect(
        find.byKey(const ValueKey('science-explain-use-voice')),
        findsNothing,
        reason: 'fallback後も誤答revisionとして文字の言い直しに固定する',
      );
      expect(find.text('動かしにくさも比べます。'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('science-explain-text-input')),
        '空気抵抗を無視すると、重さによらず同時に落ちる。',
      );
      await tester.pump();
      await _tapVisible(tester, const ValueKey('science-explain-review-text'));
      await _tapVisible(tester, const ValueKey('science-explain-submit-text'));
      await _flush(tester);

      expect(
        find.byKey(const ValueKey('science-explain-follow-up')),
        findsNothing,
        reason: '固定問い返しを再回答させず、必須の言い直し後は比較へ進む',
      );
      expect(find.text('言い直した説明と、教材を比べる'), findsOneWidget);
      expect(needs, hasLength(1));
      expect(hearts, hasLength(1));
    });
  }

  testWidgets('voice revisionのfeed例外は未処理化せず文字の言い直しへ退避する', (tester) async {
    final audio = _voice();
    final needs = <LearningNeedEvidence>[];
    final hearts = <LearningHeartLossEvidence>[];
    await tester.pumpWidget(
      _wrap(
        voice: audio.practice,
        onNeedEvidence: needs.add,
        onHeartLoss: hearts.add,
      ),
    );
    await _recordVoiceAndFinishPlayback(tester, audio);
    await _tapVisible(tester, const ValueKey('science-explain-submit-voice'));
    await _passEcho(tester);
    await _answerFollowUp(tester, 'heavy');
    await _tapVisible(tester, const ValueKey('science-explain-start-revision'));
    await _tapVisible(
      tester,
      const ValueKey('science-explain-start-recording'),
    );
    await _flush(tester);
    audio.mic.emit(3200);
    await _flush(tester);
    await _tapVisible(tester, const ValueKey('science-explain-stop-recording'));
    await _flush(tester);

    audio.sink.throwOnFeed = true;
    await _tapVisible(tester, const ValueKey('science-explain-play-recording'));
    audio.sink.requestFeed();
    await _flush(tester);

    expect(audio.practice.snapshot.state, LocalVoicePracticeState.failed);
    expect(find.text('文字で言い直す'), findsOneWidget);
    expect(find.text('動かしにくさも比べます。'), findsOneWidget);
    expect(
      tester.takeException(),
      isNull,
      reason: 'native callback例外をUIへ投げ直さない',
    );

    await _tapVisible(tester, const ValueKey('science-explain-use-text'));
    await tester.enterText(
      find.byKey(const ValueKey('science-explain-text-input')),
      '空気抵抗を無視すると、重さによらず同時に落ちる。',
    );
    await tester.pump();
    await _tapVisible(tester, const ValueKey('science-explain-review-text'));
    await _tapVisible(tester, const ValueKey('science-explain-submit-text'));
    await _flush(tester);

    expect(find.text('言い直した説明と、教材を比べる'), findsOneWidget);
    expect(needs, hasLength(1));
    expect(needs.single.kind, LearningNeedEvidenceKind.observed);
    expect(hearts, hasLength(1));
    expect(hearts.single.fixedTaskId, 'speaking:0:follow-up');
  });

  testWidgets('マイク拒否でも回答を作らず、同格の文字経路で固定問い返しまで完走できる', (tester) async {
    final audio = _voice(allowed: false);
    var completed = 0;
    await tester.pumpWidget(
      _wrap(voice: audio.practice, onCompleted: () => completed++),
    );
    await _tapVisible(tester, const ValueKey('science-explain-choose-voice'));
    await _tapVisible(
      tester,
      const ValueKey('science-explain-start-recording'),
    );
    await tester.pumpAndSettle();

    expect(
      audio.practice.snapshot.state,
      LocalVoicePracticeState.permissionDenied,
    );
    expect(audio.practice.snapshot.recordedBytes, 0);
    expect(find.textContaining('マイクを使えませんでした'), findsOneWidget);

    await _tapVisible(tester, const ValueKey('science-explain-use-text'));
    await _teachByText(tester, '文字でも同じ落下と重力の関係を説明する。', chooseRoute: false);
    await _answerFollowUp(tester, 'same');
    await _tapVisible(tester, const ValueKey('science-explain-keep'));
    await _flush(tester);

    expect(completed, 1);
    expect(
      find.byKey(const ValueKey('science-explain-finished')),
      findsOneWidget,
    );
  });

  testWidgets('backgroundは固定TTS・録音・再生を停止し、route終了でRAMを破棄する', (tester) async {
    final narration = _HoldingNarration();
    final textAudio = _voice();
    await tester.pumpWidget(
      _wrap(voice: textAudio.practice, narration: narration),
    );
    await _teachByText(tester, '背景へ移る前に落下と重力を説明した。');
    expect(narration.requests, hasLength(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _flush(tester);
    expect(narration.stopCount, greaterThanOrEqualTo(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox.shrink());
    await _flush(tester);
    await tester.runAsync(textAudio.practice.dispose);
    expect(narration.disposed, isTrue);
    expect(textAudio.practice.isDisposed, isTrue);
    expect(textAudio.practice.snapshot.recordedBytes, 0);

    final voiceAudio = _voice();
    await tester.pumpWidget(_wrap(voice: voiceAudio.practice));
    await _tapVisible(tester, const ValueKey('science-explain-choose-voice'));
    await _tapVisible(
      tester,
      const ValueKey('science-explain-start-recording'),
    );
    await _flush(tester);
    voiceAudio.mic.emit(6400);
    await _flush(tester);
    expect(voiceAudio.mic.started, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _flush(tester);
    expect(voiceAudio.mic.started, isFalse);
    expect(
      voiceAudio.practice.snapshot.state,
      isNot(LocalVoicePracticeState.recording),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await _flush(tester);
    await tester.runAsync(voiceAudio.practice.dispose);
    expect(voiceAudio.practice.snapshot.recordedBytes, 0);
    expect(voiceAudio.mic.disposed, isTrue);
  });

  testWidgets('route disposeは同期・非同期cleanup例外を未処理化せず残りも完走する', (tester) async {
    final narration = _SynchronouslyFailingNarration();
    final audio = _voice();
    audio.mic
      ..throwOnEveryStop = true
      ..throwOnDisposeAfterCleanup = true
      ..preserveStartedOnDisposeFailure = true;
    await tester.pumpWidget(_wrap(voice: audio.practice, narration: narration));
    await _tapVisible(tester, const ValueKey('science-explain-choose-voice'));
    await _tapVisible(
      tester,
      const ValueKey('science-explain-start-recording'),
    );
    await _flush(tester);
    expect(audio.mic.started, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await _flush(tester);
    await tester.runAsync(() async {
      await narration.disposeAttempted.future;
      await audio.mic.disposeCleanupCompleted.future;
    });
    await _flush(tester);

    expect(narration.disposeCalled, isTrue, reason: '同期例外をroute外へ漏らさない');
    expect(audio.mic.disposed, isTrue, reason: '先行cleanup失敗後もvoiceをdisposeする');
    expect(audio.mic.started, isTrue, reason: 'stopとdisposeが未保証なら録音停止済みに偽装しない');
    expect(tester.takeException(), isNull);
  });

  testWidgets('mic.start待機中のbackground遷移は遅延成功後もhidden micを残さない', (
    tester,
  ) async {
    final audio = _voice();
    audio.mic.startGate = Completer<bool>();
    await tester.pumpWidget(_wrap(voice: audio.practice));
    await _tapVisible(tester, const ValueKey('science-explain-choose-voice'));
    await _tapVisible(
      tester,
      const ValueKey('science-explain-start-recording'),
    );
    expect(audio.practice.snapshot.state, LocalVoicePracticeState.recording);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await _flush(tester);
    expect(
      audio.practice.snapshot.state,
      isNot(LocalVoicePracticeState.recording),
    );

    audio.mic.startGate!.complete(true);
    await _flush(tester);
    expect(audio.mic.started, isFalse);
    expect(
      audio.practice.snapshot.state,
      isNot(LocalVoicePracticeState.recording),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _flush(tester);
    final startAgain = find.byKey(
      const ValueKey('science-explain-start-recording'),
    );
    expect(tester.widget<FilledButton>(startAgain).onPressed, isNotNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await _flush(tester);
  });

  testWidgets('完了保存通知と学習パス帰還を分離し、回答をcallbackへ渡さない', (tester) async {
    final audio = _voice();
    final needs = <LearningNeedEvidence>[];
    var completed = 0;
    var returned = 0;
    await tester.pumpWidget(
      _wrap(
        voice: audio.practice,
        onNeedEvidence: needs.add,
        onCompleted: () => completed++,
        onReturnToPath: () => returned++,
      ),
    );
    await _teachByText(tester, '落下と重力の結果、別場面の予想を説明する。');
    await _answerFollowUp(tester, 'same');
    await _tapVisible(tester, const ValueKey('science-explain-keep'));
    await _flush(tester);

    expect(completed, 1);
    expect(returned, 0);
    expect(needs, hasLength(1));
    expect(needs.single.conceptKey, 'fall');
    expect(needs.single.needCode, 'science.fall.foundation');
    final returnButton = find.byKey(
      const ValueKey('science-explain-return-to-path'),
    );
    await tester.scrollUntilVisible(returnButton, 180, scrollable: _pageScroll);
    expect(tester.getSize(returnButton).height, greaterThanOrEqualTo(48));
    await tester.tap(returnButton);
    await tester.pump();
    expect(completed, 1);
    expect(returned, 1);
  });

  testWidgets('320x568・文字200%・Reduce Motionでも誤答後の言い直しを完走できる', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    final audio = _voice();
    var completed = 0;
    await tester.pumpWidget(
      _wrap(
        voice: audio.practice,
        textScale: 2,
        disableAnimations: true,
        onCompleted: () => completed++,
      ),
    );

    await _teachByText(tester, '大きな文字でも、落下と重力の条件まで説明する。');
    await _answerFollowUp(tester, 'heavy');
    final revise = find.byKey(const ValueKey('science-explain-start-revision'));
    await tester.scrollUntilVisible(revise, 180, scrollable: _pageScroll);
    expect(tester.getSize(revise).height, greaterThanOrEqualTo(48));
    await tester.tap(revise);
    await _flush(tester);

    await tester.enterText(
      find.byKey(const ValueKey('science-explain-text-input')),
      '大きな文字でも、落下が重力によらない条件まで言い直す。',
    );
    await tester.pump();
    await _tapVisible(tester, const ValueKey('science-explain-review-text'));
    await _tapVisible(tester, const ValueKey('science-explain-submit-text'));
    await _tapVisible(tester, const ValueKey('science-explain-keep'));
    await _flush(tester);

    expect(completed, 1);
    expect(
      find.byKey(const ValueKey('science-explain-finished')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('1024dp・darkでも単一GamePaletteと段階に対応するcharacter semanticsを保つ', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    final audio = _voice();
    await tester.pumpWidget(
      _wrap(voice: audio.practice, brightness: Brightness.dark),
    );

    final character = find.byKey(
      const ValueKey('science-teach-back-character'),
    );
    expect(Theme.of(tester.element(character)).colorScheme.surface, isNotNull);
    expect(
      find.bySemanticsLabel(RegExp('ティーチバック.*デキすぎ君.*手招き')),
      findsOneWidget,
    );
    expect(tester.getSize(character).width, 72);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  test('実装は回答・選択内容・音声をネットワーク・ファイル・永続Storeへ渡さない', () {
    for (final path in [
      'lib/services/local_voice_practice.dart',
      'lib/services/local_pronunciation_practice.dart',
      'lib/services/local_narration.dart',
      'lib/screens/science_speak_listen_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains("import 'package:dio")), reason: path);
      expect(source, isNot(contains("import 'package:http")), reason: path);
      expect(source, isNot(contains('SessionStore')), reason: path);
      expect(source, isNot(contains('writeAsBytes')), reason: path);
    }

    final needSource = File(
      'lib/learning/domain/learning_need.dart',
    ).readAsStringSync();
    expect(needSource, contains('final String conceptKey;'));
    expect(needSource, contains('final String needCode;'));
    expect(needSource, isNot(contains('answerText')));
    expect(needSource, isNot(contains('optionId')));
    expect(needSource, isNot(contains('audioBytes')));

    final android = File(
      'android/app/src/main/kotlin/jp/dekisugi/dekisugi/MainActivity.kt',
    ).readAsStringSync();
    expect(android, contains('createOnDeviceSpeechRecognizer'));
    expect(android, isNot(contains('createSpeechRecognizer(')));
    final ios = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(ios, contains('supportsOnDeviceRecognition'));
    expect(ios, contains('requiresOnDeviceRecognition = true'));
  });

  testWidgets('大事な言葉が届かない説明はもう一度聞き、届けば問い返しへ進む', (
    tester,
  ) async {
    final audio = _voice();
    await tester.pumpWidget(_wrap(voice: audio.practice));

    await _tapVisible(tester, const ValueKey('science-explain-choose-text'));
    await tester.enterText(
      find.byKey(const ValueKey('science-explain-text-input')),
      'あいうえおかきくけこ',
    );
    await tester.pump();
    await _tapVisible(tester, const ValueKey('science-explain-review-text'));
    expect(
      find.byKey(const ValueKey('science-explain-coverage')),
      findsOneWidget,
    );
    expect(find.text('まだ大事な言葉が届いていないみたい'), findsOneWidget);

    await _tapVisible(tester, const ValueKey('science-explain-submit-text'));
    await _flush(tester);

    expect(
      find.byKey(const ValueKey('science-explain-follow-up')),
      findsNothing,
      reason: '無関係な文は「もう少し聞かせて」と返して進ませない',
    );
    expect(find.textContaining('もう少し聞かせて'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('science-explain-text-input')),
      '空気抵抗を無視すると落下は重さによらない。',
    );
    await tester.pump();
    await _tapVisible(tester, const ValueKey('science-explain-review-text'));
    await _tapVisible(tester, const ValueKey('science-explain-submit-text'));
    await _flush(tester);

    expect(
      find.byKey(const ValueKey('science-explain-follow-up')),
      findsOneWidget,
    );
  });

  testWidgets('読み返した説明の中で聞き取れた言葉が見える', (tester) async {
    final audio = _voice();
    await tester.pumpWidget(_wrap(voice: audio.practice));

    await _tapVisible(tester, const ValueKey('science-explain-choose-text'));
    await tester.enterText(
      find.byKey(const ValueKey('science-explain-text-input')),
      '空気抵抗を無視すると速さが同じになる。',
    );
    await tester.pump();
    await _tapVisible(tester, const ValueKey('science-explain-review-text'));

    expect(
      find.text('デキすぎ君が聞き取れた言葉'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('science-explain-cue-空気抵抗')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('science-explain-cue-無視')),
      findsOneWidget,
    );
    // 届いていない語は答えを漏らすので画面に出さない。
    expect(
      find.byKey(const ValueKey('science-explain-cue-落下')),
      findsNothing,
    );
  });

  testWidgets('声の説明は要点の聞き取りが届いてから問い返しへ進む', (tester) async {
    final audio = _voice();
    final echo = _FakeEchoRecognizer();
    await tester.pumpWidget(
      _wrap(voice: audio.practice, speechRecognizer: echo),
    );

    await _recordVoiceAndFinishPlayback(tester, audio);
    await _tapVisible(tester, const ValueKey('science-explain-submit-voice'));
    await _flush(tester);

    expect(echo.recognizeCalls, 1);
    expect(
      find.byKey(const ValueKey('science-explain-echo')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('science-explain-cue-落下')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('science-explain-follow-up')),
      findsNothing,
      reason: '声の説明も聞き取り確認を通ってから問い返しへ進む',
    );

    await _passEcho(tester);
    expect(
      find.byKey(const ValueKey('science-explain-follow-up')),
      findsOneWidget,
    );
  });

  testWidgets('認識を使えない端末では文字で同じ聞き取りを確かめる', (tester) async {
    final audio = _voice();
    await tester.pumpWidget(
      _wrap(
        voice: audio.practice,
        speechRecognizer: _FakeEchoRecognizer(
          result: const OnDeviceSpeechResult(
            status: OnDeviceSpeechStatus.unavailable,
          ),
        ),
      ),
    );

    await _recordVoiceAndFinishPlayback(tester, audio);
    await _tapVisible(tester, const ValueKey('science-explain-submit-voice'));
    await _flush(tester);

    expect(
      find.byKey(const ValueKey('science-explain-echo-text-input')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('science-explain-echo-text-input')),
      '落下と重力',
    );
    await tester.pump();
    await _tapVisible(
      tester,
      const ValueKey('science-explain-echo-submit-text'),
    );
    await _passEcho(tester);

    expect(
      find.byKey(const ValueKey('science-explain-follow-up')),
      findsOneWidget,
    );
  });

  testWidgets('無関係な声の要点はもう一度聞き、閉じ込めず逃がす', (tester) async {
    final audio = _voice();
    await tester.pumpWidget(
      _wrap(
        voice: audio.practice,
        speechRecognizer: _FakeEchoRecognizer(
          result: const OnDeviceSpeechResult(
            status: OnDeviceSpeechStatus.recognized,
            candidates: ['さっきの天気の話'],
          ),
        ),
      ),
    );

    await _recordVoiceAndFinishPlayback(tester, audio);
    await _tapVisible(tester, const ValueKey('science-explain-submit-voice'));
    await _flush(tester);

    expect(
      find.byKey(const ValueKey('science-explain-follow-up')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('science-explain-echo-voice')),
      findsOneWidget,
    );
    // 1回目は聞き直すだけ。2回届かなければ「このまま進む」を開く。
    await _tapVisible(tester, const ValueKey('science-explain-echo-voice'));
    await _flush(tester);
    expect(
      find.byKey(const ValueKey('science-explain-echo-bypass')),
      findsOneWidget,
    );
    await _tapVisible(tester, const ValueKey('science-explain-echo-bypass'));
    await _flush(tester);
    expect(
      find.byKey(const ValueKey('science-explain-follow-up')),
      findsOneWidget,
    );
  });

  testWidgets('Plusサポーターは説明を読んだ生成前置きが問い返しに乗る', (
    tester,
  ) async {
    final audio = _voice();
    final engine = _FixedEngine('「ふむ、空気抵抗まで見てるのか」');
    await tester.pumpWidget(
      _wrap(
        voice: audio.practice,
        companionVoice: CompanionVoice(engine: engine),
        supporterCheck: () async => true,
      ),
    );

    await _teachByText(tester, '空気抵抗を無視すると落下は重さによらない。');
    expect(
      find.byKey(const ValueKey('science-explain-follow-up')),
      findsOneWidget,
    );
    await _flush(tester);

    final question = tester
        .widget<Text>(
          find.byKey(const ValueKey('science-explain-spoken-question')),
        )
        .data!;
    expect(question, startsWith('ふむ、空気抵抗まで見てるのか'));
    expect(question, contains(_section.localPracticeVariants[0].checkpoint.lure));
  });

  testWidgets('サポーターでなければ生成経路を呼ばず固定文へ退避する', (
    tester,
  ) async {
    final audio = _voice();
    final engine = _FixedEngine('「ふむ、空気抵抗まで見てるのか」');
    await tester.pumpWidget(
      _wrap(
        voice: audio.practice,
        companionVoice: CompanionVoice(engine: engine),
        supporterCheck: () async => false,
      ),
    );

    await _teachByText(tester, '空気抵抗を無視すると落下は重さによらない。');
    expect(
      find.byKey(const ValueKey('science-explain-follow-up')),
      findsOneWidget,
    );
    await _flush(tester);

    expect(engine.calls, 0);
    final question = tester
        .widget<Text>(
          find.byKey(const ValueKey('science-explain-spoken-question')),
        )
        .data!;
    expect(question, startsWith('教えてくれてありがとう。'));
  });

  test('StoryとSpeakingは旧AppColors・ColorSchemeへ戻らない', () {
    for (final path in [
      'lib/screens/science_story_screen.dart',
      'lib/screens/science_speak_listen_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('.appColors')), reason: path);
      expect(source, isNot(contains('.colorScheme')), reason: path);
    }
  });
}
