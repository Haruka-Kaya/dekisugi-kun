import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dekisugi/config/app_theme.dart';
import 'package:dekisugi/config/game_tokens.dart';
import 'package:dekisugi/config/motion.dart';
import 'package:dekisugi/models/unit.dart';
import 'package:dekisugi/screens/science_speak_listen_screen.dart';
import 'package:dekisugi/services/local_pronunciation_practice.dart';
import 'package:dekisugi/services/local_voice_practice.dart';
import 'package:dekisugi/services/mic_stream.dart';
import 'package:dekisugi/services/pcm_player.dart';
import 'package:dekisugi/ui/_material.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:flutter_test/flutter_test.dart';

const _checkpoint = LocalCheckpoint(
  lure: '重い球ほど先に着く。',
  options: [
    LocalCheckpointOption(id: 'heavy', text: '重い球が先に着く。', hint: '動かしにくさも比べます。'),
    LocalCheckpointOption(id: 'same', text: '同時に着く。'),
    LocalCheckpointOption(
      id: 'light',
      text: '軽い球が先に着く。',
      hint: '軽さだけでは決まりません。',
    ),
  ],
  correctOptionId: 'same',
  explanation: '落下加速度は重さによりません。',
);

const _task = LocalCognitiveTask(
  kind: LocalCognitiveTaskKind.singleSelect,
  operation: LocalCognitiveOperation.prediction,
  items: [
    LocalCognitiveTaskItem(id: 'heavy-a', text: '重い球が先'),
    LocalCognitiveTaskItem(id: 'same-a', text: '同時'),
  ],
  targets: [],
  solution: LocalSingleSelectSolution(selectedItemId: 'same-a'),
);

LocalPracticeVariant _variant(LocalPracticeStage stage, String marker) =>
    LocalPracticeVariant(
      stage: stage,
      recallPrompt: '$marker：原理を教材なしで思い出してください。',
      reasoningPrompt: '$marker：理由と成立条件を足してください。',
      transferPrompt: '$marker：別の場面で起きることを予想してください。',
      expectedOutcome: '$marker：教材の観察結果です。',
      expectedReason: '$marker：教材の理由と条件です。',
      cognitiveTask: _task,
      checkpoint: _checkpoint,
    );

final _section = Section(
  conceptKey: 'fall',
  title: '落下の速さ',
  body: const ['この本文は説明中に表示してはいけません。'],
  tryIt: '落下を比べる。',
  localCheckpoint: _checkpoint,
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

class _FakeRecognizer implements OnDeviceSpeechRecognizer {
  _FakeRecognizer({
    this.result = const OnDeviceSpeechResult(
      status: OnDeviceSpeechStatus.recognized,
      candidates: ['空気抵抗を無視すれば落下の速さは重さによらない'],
    ),
  });

  OnDeviceSpeechResult result;
  int recognizeCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;

  @override
  Future<OnDeviceSpeechResult> recognize({String languageTag = 'ja-JP'}) async {
    recognizeCalls++;
    return result;
  }

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> cancel() async => cancelCalls++;
}

LocalPronunciationPractice _pronunciation([_FakeRecognizer? recognizer]) =>
    LocalPronunciationPractice(
      targetPhrase: _section.localSpeakingPractice!.targetPhrase,
      acceptedTranscripts: _section.localSpeakingPractice!.acceptedTranscripts,
      recognizer: recognizer ?? _FakeRecognizer(),
    );

class _FakeMic extends MicStream {
  _FakeMic({this.allowed = true});

  final bool allowed;
  final _chunks = StreamController<Uint8List>.broadcast();
  final _levels = StreamController<double>.broadcast();
  bool started = false;
  bool disposed = false;

  @override
  Stream<Uint8List> get chunks => _chunks.stream;

  @override
  Stream<double> get level => _levels.stream;

  @override
  bool get isRecording => started;

  @override
  Future<bool> start({bool speakerphone = true}) async {
    started = allowed;
    return allowed;
  }

  @override
  Future<void> stop() async => started = false;

  void emit(int bytes) => _chunks.add(Uint8List(bytes));

  @override
  Future<void> dispose() async {
    disposed = true;
    started = false;
    await _chunks.close();
    await _levels.close();
  }
}

class _FakeSink implements PcmSink {
  void Function(int)? callback;
  int? sampleRate;
  int startCalls = 0;
  bool released = false;

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
  void feed(PcmArrayInt16 buffer) {}

  @override
  void start() => startCalls++;

  @override
  Future<void> release() async => released = true;
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
  LocalPronunciationPractice? pronunciation,
  VoidCallback? onCompleted,
  VoidCallback? onReturnToPath,
  double textScale = 1,
  bool disableAnimations = false,
  Brightness brightness = Brightness.light,
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
    pronunciationPractice: pronunciation ?? _pronunciation(),
    voicePractice: voice,
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
  for (var i = 0; i < 3; i++) {
    await tester.pump();
  }
}

Future<void> _passSpeakingTargetByText(WidgetTester tester) async {
  await _tapVisible(tester, const ValueKey('science-speaking-use-text'));
  await tester.enterText(
    find.byKey(const ValueKey('science-speaking-target-text')),
    _section.localSpeakingPractice!.targetPhrase,
  );
  await tester.pump();
  await _tapVisible(tester, const ValueKey('science-speaking-continue-text'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('catalog目標語句の端末内認識だけが声の確認を通過する', (tester) async {
    final audio = _voice();
    final recognizer = _FakeRecognizer(
      result: const OnDeviceSpeechResult(
        status: OnDeviceSpeechStatus.recognized,
        candidates: ['空気 抵抗を無視すれば、落下の速さは重さによらない。'],
      ),
    );
    await tester.pumpWidget(
      _wrap(voice: audio.practice, pronunciation: _pronunciation(recognizer)),
    );

    await _tapVisible(
      tester,
      const ValueKey('science-speaking-start-recognition'),
    );
    await _flush(tester);

    expect(recognizer.recognizeCalls, 1);
    expect(
      find.byKey(const ValueKey('science-speaking-continue-voice')),
      findsOneWidget,
    );
    await _tapVisible(
      tester,
      const ValueKey('science-speaking-continue-voice'),
    );
    expect(
      find.byKey(const ValueKey('science-explain-choose-voice')),
      findsOneWidget,
    );
  });

  testWidgets('無音は未達成のままnoSpeechとして再試行を求める', (tester) async {
    final audio = _voice();
    final recognizer = _FakeRecognizer(
      result: const OnDeviceSpeechResult(status: OnDeviceSpeechStatus.noSpeech),
    );
    await tester.pumpWidget(
      _wrap(voice: audio.practice, pronunciation: _pronunciation(recognizer)),
    );

    await _tapVisible(
      tester,
      const ValueKey('science-speaking-start-recognition'),
    );
    await _flush(tester);

    expect(find.textContaining('声を認識できませんでした'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('science-speaking-continue-voice')),
      findsNothing,
    );
  });

  testWidgets('無関係な発話は目標語句と区別し完了にしない', (tester) async {
    final audio = _voice();
    var completed = 0;
    final recognizer = _FakeRecognizer(
      result: const OnDeviceSpeechResult(
        status: OnDeviceSpeechStatus.recognized,
        candidates: ['今日は別の話をします'],
      ),
    );
    await tester.pumpWidget(
      _wrap(
        voice: audio.practice,
        pronunciation: _pronunciation(recognizer),
        onCompleted: () => completed++,
      ),
    );

    await _tapVisible(
      tester,
      const ValueKey('science-speaking-start-recognition'),
    );
    await _flush(tester);

    expect(find.textContaining('目標語句とは一致しませんでした'), findsOneWidget);
    expect(completed, 0);
    expect(
      find.byKey(const ValueKey('science-speaking-continue-voice')),
      findsNothing,
    );
  });

  testWidgets('権限拒否の文字代替は1文字を拒否し、発音未確認と明示する', (tester) async {
    final audio = _voice();
    var completed = 0;
    final recognizer = _FakeRecognizer(
      result: const OnDeviceSpeechResult(
        status: OnDeviceSpeechStatus.permissionDenied,
      ),
    );
    await tester.pumpWidget(
      _wrap(
        voice: audio.practice,
        pronunciation: _pronunciation(recognizer),
        onCompleted: () => completed++,
      ),
    );

    await _tapVisible(
      tester,
      const ValueKey('science-speaking-start-recognition'),
    );
    await _flush(tester);
    expect(find.textContaining('発音確認にはなりません'), findsOneWidget);
    await _tapVisible(tester, const ValueKey('science-speaking-use-text'));
    final field = find.byKey(const ValueKey('science-speaking-target-text'));
    await tester.enterText(field, '空');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('science-speaking-continue-text')),
          )
          .onPressed,
      isNull,
    );

    await tester.enterText(field, _section.localSpeakingPractice!.targetPhrase);
    await tester.pump();
    await _tapVisible(tester, const ValueKey('science-speaking-continue-text'));
    await _tapVisible(tester, const ValueKey('science-explain-choose-text'));
    await tester.enterText(
      find.byKey(const ValueKey('science-explain-text-input')),
      '一',
    );
    await tester.pump();
    await _tapVisible(tester, const ValueKey('science-explain-submit-text'));
    await _tapVisible(tester, const ValueKey('science-explain-keep'));
    await _flush(tester);

    expect(completed, 1);
    expect(find.textContaining('発音は未確認です'), findsOneWidget);
  });

  testWidgets('active variantの3問だけを出し、回答前は教材結果・理由・本文を隠す', (tester) async {
    final audio = _voice();
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(practiceAttempt: 1, voice: audio.practice));
    expect(
      find.text(_section.localSpeakingPractice!.targetPhrase),
      findsOneWidget,
    );
    await _passSpeakingTargetByText(tester);

    final active = _section.localPracticeVariants[1];
    expect(find.text(active.recallPrompt), findsOneWidget);
    expect(find.text(active.reasoningPrompt), findsOneWidget);
    expect(find.text(active.transferPrompt), findsOneWidget);
    expect(
      find.text(_section.localPracticeVariants[0].recallPrompt),
      findsNothing,
    );
    expect(
      find.text(_section.localPracticeVariants[2].recallPrompt),
      findsNothing,
    );
    expect(find.text(active.expectedOutcome), findsNothing);
    expect(find.text(active.expectedReason), findsNothing);
    expect(find.text(_section.body.first), findsNothing);
    expect(find.bySemanticsLabel(RegExp('教材の観察.*B：教材の観察結果')), findsNothing);

    await _tapVisible(tester, const ValueKey('science-explain-choose-text'));
    expect(find.text(active.expectedOutcome), findsNothing);
    expect(find.text(active.expectedReason), findsNothing);
    expect(find.text(_section.body.first), findsNothing);
    semantics.dispose();
  });

  testWidgets('文字入力は自己比較後に残すか直すかを必須にし、callbackは一度だけ', (tester) async {
    final audio = _voice();
    var completed = 0;
    await tester.pumpWidget(
      _wrap(voice: audio.practice, onCompleted: () => completed++),
    );
    await _passSpeakingTargetByText(tester);
    await _tapVisible(tester, const ValueKey('science-explain-choose-text'));

    final field = find.byKey(const ValueKey('science-explain-text-input'));
    await tester.enterText(field, '重さだけでは決まらず、空気抵抗の条件も見る。');
    await tester.pump();
    await _tapVisible(tester, const ValueKey('science-explain-submit-text'));

    final variant = _section.localPracticeVariants.first;
    expect(find.text(variant.expectedOutcome), findsOneWidget);
    expect(find.text(variant.expectedReason), findsOneWidget);
    expect(completed, 0, reason: '比較を開いただけでは完了しない');
    expect(find.byKey(const ValueKey('science-explain-keep')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('science-explain-revise')),
      findsOneWidget,
    );

    await _tapVisible(tester, const ValueKey('science-explain-revise'));
    expect(find.text(variant.expectedOutcome), findsNothing);
    final unchanged = tester.widget<FilledButton>(
      find.byKey(const ValueKey('science-explain-submit-text')),
    );
    expect(unchanged.onPressed, isNull, reason: '直すを選んだら同じ文の再送では進めない');

    await tester.enterText(field, '空気抵抗を無視すれば重さによらず、空気中では形の影響も見る。');
    await tester.pump();
    await _tapVisible(tester, const ValueKey('science-explain-submit-text'));

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
    expect(find.textContaining('習得'), findsNothing);
    expect(find.textContaining('理解した'), findsNothing);
    expect(find.textContaining('空気抵抗を無視すれば重さによらず'), findsNothing);
  });

  testWidgets('マイク拒否でも回答を作らず、同格の文字経路で完走できる', (tester) async {
    final audio = _voice(allowed: false);
    var completed = 0;
    await tester.pumpWidget(
      _wrap(voice: audio.practice, onCompleted: () => completed++),
    );
    await _passSpeakingTargetByText(tester);
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
    expect(find.textContaining('マイクを使えませんでした'), findsOneWidget);
    expect(audio.practice.snapshot.recordedBytes, 0);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('science-explain-submit-voice')),
          )
          .onPressed,
      isNull,
    );

    await _tapVisible(tester, const ValueKey('science-explain-use-text'));
    await tester.enterText(
      find.byKey(const ValueKey('science-explain-text-input')),
      '文字でも同じ原理、条件、別場面を説明する。',
    );
    await tester.pump();
    await _tapVisible(tester, const ValueKey('science-explain-submit-text'));
    await _tapVisible(tester, const ValueKey('science-explain-keep'));
    await tester.pumpAndSettle();

    expect(completed, 1);
    expect(
      find.byKey(const ValueKey('science-explain-finished')),
      findsOneWidget,
    );
  });

  testWidgets('声は録音後に自分で再生するまで比較できず、16kHzで聞き返せる', (tester) async {
    final audio = _voice();
    var completed = 0;
    await tester.pumpWidget(
      _wrap(voice: audio.practice, onCompleted: () => completed++),
    );
    await _passSpeakingTargetByText(tester);
    await _tapVisible(tester, const ValueKey('science-explain-choose-voice'));
    await _tapVisible(
      tester,
      const ValueKey('science-explain-start-recording'),
    );
    await _flush(tester);
    expect(audio.mic.started, isTrue);

    audio.mic.emit(3200);
    await _flush(tester);
    await _tapVisible(tester, const ValueKey('science-explain-stop-recording'));
    await tester.pumpAndSettle();

    final submit = find.byKey(const ValueKey('science-explain-submit-voice'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    expect(find.text('先に自分の説明を聞く'), findsOneWidget);

    await _tapVisible(tester, const ValueKey('science-explain-play-recording'));
    await _flush(tester);
    expect(audio.sink.sampleRate, 16000);
    expect(audio.sink.startCalls, 1);
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);

    await _tapVisible(tester, const ValueKey('science-explain-submit-voice'));
    expect(
      find.text(_section.localPracticeVariants.first.expectedOutcome),
      findsOneWidget,
    );
    await _tapVisible(tester, const ValueKey('science-explain-keep'));
    await _flush(tester);

    expect(completed, 1);
    expect(audio.practice.snapshot.recordedBytes, 0);
  });

  testWidgets('route終了時に録音中でもRAM・マイク・playerを破棄する', (tester) async {
    final audio = _voice();
    await tester.pumpWidget(_wrap(voice: audio.practice));
    await _passSpeakingTargetByText(tester);
    await _tapVisible(tester, const ValueKey('science-explain-choose-voice'));
    await _tapVisible(
      tester,
      const ValueKey('science-explain-start-recording'),
    );
    await _flush(tester);
    audio.mic.emit(6400);
    await _flush(tester);
    expect(audio.practice.snapshot.recordedBytes, 6400);

    await tester.pumpWidget(const SizedBox.shrink());
    await _flush(tester);
    await tester.runAsync(audio.practice.dispose);

    expect(audio.practice.isDisposed, isTrue);
    expect(audio.practice.snapshot.recordedBytes, 0);
    expect(audio.mic.started, isFalse);
    expect(audio.mic.disposed, isTrue);
  });

  testWidgets('完了保存通知と学習パスへの帰還を分離する', (tester) async {
    final audio = _voice();
    var completed = 0;
    var returned = 0;
    await tester.pumpWidget(
      _wrap(
        voice: audio.practice,
        onCompleted: () => completed++,
        onReturnToPath: () => returned++,
      ),
    );
    await _passSpeakingTargetByText(tester);
    await _tapVisible(tester, const ValueKey('science-explain-choose-text'));
    await tester.enterText(
      find.byKey(const ValueKey('science-explain-text-input')),
      '結果、理由と条件、別場面の予想を説明する。',
    );
    await tester.pump();
    await _tapVisible(tester, const ValueKey('science-explain-submit-text'));
    await _tapVisible(tester, const ValueKey('science-explain-keep'));
    await _flush(tester);

    expect(completed, 1);
    expect(returned, 0);
    expect(
      find.byKey(const ValueKey('science-explain-finished')),
      findsOneWidget,
    );
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

  testWidgets('320x568・文字200%・Reduce Motionでも拒否後の文字経路を操作できる', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    final audio = _voice(allowed: false);
    var completed = 0;

    await tester.pumpWidget(
      _wrap(
        voice: audio.practice,
        textScale: 2,
        disableAnimations: true,
        onCompleted: () => completed++,
      ),
    );
    await _passSpeakingTargetByText(tester);

    final voice = find.byKey(const ValueKey('science-explain-choose-voice'));
    await tester.scrollUntilVisible(voice, 180, scrollable: _pageScroll);
    expect(tester.getSize(voice).height, greaterThanOrEqualTo(48));
    await tester.tap(voice);
    await tester.pump();

    final start = find.byKey(const ValueKey('science-explain-start-recording'));
    await tester.scrollUntilVisible(start, 180, scrollable: _pageScroll);
    expect(tester.getSize(start).height, greaterThanOrEqualTo(48));
    await tester.tap(start);
    await _flush(tester);

    final useText = find.byKey(const ValueKey('science-explain-use-text'));
    await tester.scrollUntilVisible(useText, 180, scrollable: _pageScroll);
    expect(tester.getSize(useText).height, greaterThanOrEqualTo(48));
    await tester.tap(useText);
    await _flush(tester);

    final field = find.byKey(const ValueKey('science-explain-text-input'));
    await tester.scrollUntilVisible(field, 180, scrollable: _pageScroll);
    await tester.enterText(field, '大きな文字でも、理由と条件まで説明する。');
    await tester.pump();

    final submit = find.byKey(const ValueKey('science-explain-submit-text'));
    await tester.scrollUntilVisible(submit, 180, scrollable: _pageScroll);
    expect(tester.getSize(submit).height, greaterThanOrEqualTo(48));
    await tester.tap(submit);
    await tester.pumpAndSettle();

    final keep = find.byKey(const ValueKey('science-explain-keep'));
    await tester.scrollUntilVisible(keep, 180, scrollable: _pageScroll);
    expect(tester.getSize(keep).height, greaterThanOrEqualTo(48));
    await tester.tap(keep);
    await _flush(tester);

    expect(completed, 1);
    expect(
      find.byKey(const ValueKey('science-explain-finished')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  test('実装は音声・認識候補をネットワーク・永続Storeへ渡さない', () {
    for (final path in [
      'lib/services/local_voice_practice.dart',
      'lib/services/local_pronunciation_practice.dart',
      'lib/screens/science_speak_listen_screen.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains("import 'package:dio")), reason: path);
      expect(source, isNot(contains("import 'package:http")), reason: path);
      expect(source, isNot(contains('SessionStore')), reason: path);
      expect(source, isNot(contains('writeAsBytes')), reason: path);
    }

    final android = File(
      'android/app/src/main/kotlin/jp/dekisugi/dekisugi/MainActivity.kt',
    ).readAsStringSync();
    expect(android, contains('createOnDeviceSpeechRecognizer'));
    expect(android, isNot(contains('createSpeechRecognizer(')));
    expect(android, contains('override fun onStop()'));
    expect(
      RegExp(
        r'override fun onStop\(\)[\s\S]*cancelRecognition\("cancelled"\)',
      ).hasMatch(android),
      isTrue,
      reason: 'background中もマイク認識を続けない',
    );
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android.permission.RECORD_AUDIO'));
    expect(manifest, contains('android.speech.RecognitionService'));

    final ios = File('ios/Runner/AppDelegate.swift').readAsStringSync();
    expect(ios, contains('supportsOnDeviceRecognition'));
    expect(ios, contains('requiresOnDeviceRecognition = true'));
    final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(infoPlist, contains('NSMicrophoneUsageDescription'));
    expect(infoPlist, contains('NSSpeechRecognitionUsageDescription'));
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

  testWidgets('1024dp・darkでもSpeakingは単一GamePaletteと招待reactionを保つ', (
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

    final target = find.byKey(const ValueKey('science-speaking-target'));
    expect(
      Theme.of(tester.element(target)).colorScheme.surface,
      GamePalette.dark.canvas,
    );
    expect(
      find.bySemanticsLabel(RegExp('スピークとリッスン.*デキすぎ君.*手招き')),
      findsOneWidget,
    );
    expect(tester.getSize(target).width, lessThanOrEqualTo(640));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
