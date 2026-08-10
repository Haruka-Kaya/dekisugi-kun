import 'dart:async';

import 'package:dekisugi/models/dossier.dart';
import 'package:dekisugi/models/mission.dart';
import 'package:dekisugi/services/director_client.dart';
import 'package:dekisugi/services/live_session.dart';
import 'package:dekisugi/services/live_token_client.dart';
import 'package:dekisugi/services/pcm_player.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_live.dart';
import 'support/live_fakes.dart';

const _m01Lure = 'えっと、じゃあ重いものの方が速く落ちるってこと？';

class _DelayedTokens extends FakeTokens {
  _DelayedTokens(super.grant);

  final release = Completer<void>();

  @override
  Future<LiveGrant> reserve(
    String unitId, {
    String? resumeHandle,
    String? focusConceptKey,
    TeachingTactic tactic = TeachingTactic.reason,
    MissionKind missionKind = MissionKind.teach,
  }) async {
    await release.future;
    return super.reserve(
      unitId,
      resumeHandle: resumeHandle,
      focusConceptKey: focusConceptKey,
      tactic: tactic,
      missionKind: missionKind,
    );
  }
}

class _ControlledDirector extends DirectorClient {
  _ControlledDirector() : super(baseUrl: 'https://director.test');

  final _pending = <Completer<DirectorResult?>>[];
  final calls = <({Dossier? dossier, List<Utterance> utterances})>[];

  int get pendingCount => _pending.length;
  TeachingTactic? lastTeachingTactic;
  MissionKind? lastMissionKind;

  @override
  Future<DirectorResult?> run({
    required String unitId,
    String? focusConceptKey,
    TeachingTactic tactic = TeachingTactic.reason,
    MissionKind missionKind = MissionKind.teach,
    Dossier? dossier,
    required List<Utterance> utterances,
    required double secondsLeft,
    required int turnCount,
  }) {
    lastTeachingTactic = tactic;
    lastMissionKind = missionKind;
    calls.add((dossier: dossier, utterances: List.of(utterances)));
    final completer = Completer<DirectorResult?>();
    _pending.add(completer);
    return completer.future;
  }

  void completeNext(DirectorResult result) {
    if (_pending.isEmpty) throw StateError('待機中のDirector呼び出しがない');
    _pending.removeAt(0).complete(result);
  }
}

class _DelayedFirstSaveStore extends MemorySessionStore {
  final releaseFirstSave = Completer<void>();
  final savedProbeResults = <ProbeResult?>[];
  int saveCalls = 0;

  @override
  Future<void> saveProgress(
    int sessionId, {
    required List<Utterance> transcript,
    Dossier? dossier,
  }) async {
    final call = ++saveCalls;
    if (call == 1) await releaseFirstSave.future;
    await super.saveProgress(
      sessionId,
      transcript: transcript,
      dossier: dossier,
    );
    savedProbeResults.add(dossier?.slots.single.probes.single.result);
  }
}

Dossier _challengeDossier(ProbeResult result) => Dossier(
  unitId: 'force-motion',
  slots: [
    Slot(
      key: 'fall',
      label: '落下の速さ',
      status: SlotStatus.explained,
      content: '重さによらない',
      evidence: const ['u01'],
      followUpHint: '',
      probes: [Probe(id: 'M01', result: result, evidence: const [])],
    ),
  ],
  coverage: 100,
);

DirectorResult _directorResult({
  required ProbeResult probe,
  required String instruction,
  String? lureId,
  String? lureText,
}) => DirectorResult(
  corrections: const {},
  dossier: _challengeDossier(probe),
  nextInstruction: instruction,
  lureId: lureId,
  lureText: lureText,
  shouldEnd: false,
  endReason: '',
);

void main() {
  // MicStream のコンストラクタが AudioRecorder を作り、
  // プラットフォームチャネルに触れる。バインディングが無いと落ちる
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeLive server;
  late FakeMic mic;
  late FakeSink sink;
  late MemorySessionStore store;
  late LiveSessionController live;

  setUp(() async {
    server = await FakeLive.start();
    mic = FakeMic();
    sink = FakeSink();
    store = MemorySessionStore();
    live = LiveSessionController(
      unitId: 'force-motion',
      tokens: FakeTokens(grantFor(server.port)),
      store: store,
      mic: mic,
      player: PcmPlayer(sink: sink),
    );
  });

  tearDown(() async {
    await live.stop();
    await server.dispose();
  });

  Future<void> settle([int ms = 250]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  Future<void> waitUntil(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final end = DateTime.now().add(timeout);
    while (!condition()) {
      if (DateTime.now().isAfter(end)) {
        throw TimeoutException('条件が成立しなかった');
      }
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('教材で選んだ作戦をLiveとDirectorへ失わず渡す', () async {
    final tokens = FakeTokens(grantFor(server.port));
    final director = _ControlledDirector();
    live = LiveSessionController(
      unitId: 'force-motion',
      focusConceptKey: 'fall',
      tactic: TeachingTactic.example,
      missionKind: MissionKind.repair,
      tokens: tokens,
      director: director,
      store: store,
      mic: mic,
      player: PcmPlayer(sink: sink),
    );

    await live.start();
    await settle();

    expect(tokens.lastFocusConceptKey, 'fall');
    expect(tokens.lastTeachingTactic, TeachingTactic.example);
    expect(tokens.lastMissionKind, MissionKind.repair);
    expect(director.lastTeachingTactic, TeachingTactic.example);
    expect(director.lastMissionKind, MissionKind.repair);
  });

  test('中断再開で保存済み作戦をLiveとDirectorへ戻す', () async {
    final id = await store.startSession(
      'force-motion',
      focusConceptKey: 'fall',
      tactic: TeachingTactic.experiment,
      missionKind: MissionKind.repair,
    );
    await store.saveProgress(
      id,
      transcript: const [
        Utterance(id: 'u1', isStudent: true, text: '実験ではこうなった'),
      ],
    );
    final saved = await store.unfinished(
      unitId: 'force-motion',
      focusConceptKey: 'fall',
      missionKind: MissionKind.repair,
    );
    expect(saved, isNotNull);

    final tokens = FakeTokens(grantFor(server.port));
    final director = _ControlledDirector();
    live = LiveSessionController(
      unitId: 'force-motion',
      focusConceptKey: 'fall',
      tactic: TeachingTactic.example,
      missionKind: MissionKind.repair,
      tokens: tokens,
      director: director,
      store: store,
      mic: mic,
      player: PcmPlayer(sink: sink),
    );

    expect(await live.resumeSaved(saved!), isTrue);
    expect(live.tactic, TeachingTactic.experiment);
    await live.start();
    await settle();

    expect(tokens.lastTeachingTactic, TeachingTactic.experiment);
    expect(director.lastTeachingTactic, TeachingTactic.experiment);
  });

  test('CASEは古い作戦値があってもreasonを両APIへ送る', () async {
    final tokens = FakeTokens(grantFor(server.port));
    final director = _ControlledDirector();
    live = LiveSessionController(
      unitId: 'force-motion',
      focusConceptKey: 'fall',
      tactic: TeachingTactic.experiment,
      missionKind: MissionKind.caseRetry,
      tokens: tokens,
      director: director,
      store: store,
      mic: mic,
      player: PcmPlayer(sink: sink),
    );

    await live.start();
    await settle();

    expect(live.tactic, TeachingTactic.reason);
    expect(tokens.lastTeachingTactic, TeachingTactic.reason);
    expect(director.lastTeachingTactic, TeachingTactic.reason);
  });

  test('誘発を実際に話したAI発話だけをchallengeとして再開後まで保つ', () async {
    final director = _ControlledDirector();
    live = LiveSessionController(
      unitId: 'force-motion',
      focusConceptKey: 'fall',
      tokens: FakeTokens(grantFor(server.port)),
      director: director,
      store: store,
      mic: mic,
      player: PcmPlayer(sink: sink),
    );

    await live.start();
    await settle();
    expect(director.pendingCount, 1);

    // Directorの応答より前から生成中だった、普通のAI発話。
    // lure指示はAIが喋り終えるまでqueueで待つ。
    server.say({
      'serverContent': {
        'modelTurn': {
          'parts': [
            {
              'inlineData': {'mimeType': 'audio/pcm', 'data': audioB64(48000)},
            },
          ],
        },
        'outputTranscription': {'text': '先に進んでいた普通の質問です'},
      },
    });
    await settle();
    expect(live.state, LiveState.speaking);

    director.completeNext(
      _directorResult(
        probe: ProbeResult.notTried,
        instruction: '重いものの方が速く落ちると思い込んで質問して。',
        lureId: 'M01',
        lureText: _m01Lure,
      ),
    );
    await settle();
    expect(live.lastLureId, isNull, reason: '実際の固定発話より前はchallenge済みにしない');
    expect(live.challengeText, isNull);

    // queue待ち中に先行発話が確定しても、challengeへ誤採用しない。
    server.say({
      'serverContent': {'turnComplete': true},
    });
    await settle();
    expect(live.transcript.last.text, '先に進んでいた普通の質問です');
    expect(live.transcript.last.challengeLureId, isNull);
    expect(live.challengeText, isNull);

    // 発話を止めて静かになった時点で、初めてlure指示がLiveへ送られる。
    live.silenceAi();
    await settle();
    server.say({
      'serverContent': {
        'outputTranscription': {'text': _m01Lure},
        'turnComplete': true,
      },
    });
    await settle();

    expect(live.challengeText, _m01Lure);
    expect(live.transcript.last.challengeLureId, 'M01');

    // 生徒の返答と通常のAI発話。その後のDirector応答はlureではない。
    server.say({
      'serverContent': {
        'inputTranscription': {'text': '違うよ。条件をそろえると同じだよ'},
        'outputTranscription': {'text': 'どうしてそう言えるの？'},
        'turnComplete': true,
      },
    });
    await settle();
    expect(director.pendingCount, 1);
    director.completeNext(
      _directorResult(
        probe: ProbeResult.corrected,
        instruction: '理由をもう一度だけ聞いて。',
      ),
    );
    await settle();
    expect(live.lastLureId, 'M01');
    expect(live.challengeText, _m01Lure);

    server.say({
      'serverContent': {
        'outputTranscription': {'text': 'では、理由も教えてください'},
        'turnComplete': true,
      },
    });
    await settle();
    expect(live.transcript.last.challengeLureId, isNull);
    expect(live.challengeText, _m01Lure);

    await live.stop();
    final saved = await store.unfinished(
      unitId: 'force-motion',
      focusConceptKey: 'fall',
    );
    expect(saved, isNotNull);
    expect(
      saved!.transcript
          .where((utterance) => utterance.challengeLureId == 'M01')
          .single
          .text,
      _m01Lure,
    );

    final resumedLive = LiveSessionController(
      unitId: 'force-motion',
      focusConceptKey: 'fall',
      tokens: FakeTokens(grantFor(server.port)),
      store: store,
      mic: FakeMic(),
      player: PcmPlayer(sink: FakeSink()),
    );
    addTearDown(resumedLive.dispose);
    expect(await resumedLive.resumeSaved(saved), isTrue);
    expect(resumedLive.lastLureId, 'M01');
    expect(resumedLive.challengeText, _m01Lure);

    // resumeSaved直後だけでなく、Liveへ再接続したあとも消してはいけない。
    await resumedLive.start(withMic: false);
    await settle();
    expect(resumedLive.lastLureId, 'M01');
    expect(resumedLive.challengeText, _m01Lure);
  });

  test('DirectorのIDはあっても固定lureと異なるAI発話はchallengeにしない', () async {
    final director = _ControlledDirector();
    live = LiveSessionController(
      unitId: 'force-motion',
      focusConceptKey: 'fall',
      tokens: FakeTokens(grantFor(server.port)),
      director: director,
      store: store,
      mic: mic,
      player: PcmPlayer(sink: sink),
    );

    await live.start(withMic: false);
    await settle();
    director.completeNext(
      _directorResult(
        probe: ProbeResult.notTried,
        instruction: '固定文だけを言って。',
        lureId: 'M01',
        lureText: _m01Lure,
      ),
    );
    await settle();

    server.say({
      'serverContent': {
        'outputTranscription': {'text': 'なるほど。$_m01Lure'},
        'turnComplete': true,
      },
    });
    await settle();

    expect(live.transcript.last.text, 'なるほど。$_m01Lure');
    expect(live.transcript.last.challengeLureId, isNull);
    expect(live.transcript.last.challengeLureText, isNull);
    expect(live.lastLureId, isNull);
    expect(live.challengeText, isNull);
  });

  test('検証時の固定lureを持たない旧保存逐語は再開時にfail-closed', () async {
    final id = await store.startSession(
      'force-motion',
      focusConceptKey: 'fall',
    );
    await store.saveProgress(
      id,
      transcript: const [
        Utterance(
          id: 'u01',
          isStudent: false,
          text: _m01Lure,
          challengeLureId: 'M01',
        ),
      ],
      dossier: _challengeDossier(ProbeResult.corrected),
    );
    final saved = await store.unfinished(
      unitId: 'force-motion',
      focusConceptKey: 'fall',
    );
    expect(saved, isNotNull);

    live = LiveSessionController(
      unitId: 'force-motion',
      focusConceptKey: 'fall',
      tokens: FakeTokens(grantFor(server.port)),
      store: store,
      mic: mic,
      player: PcmPlayer(sink: sink),
    );
    expect(await live.resumeSaved(saved!), isTrue);
    expect(live.lastLureId, isNull);
    expect(live.challengeText, isNull);
    expect(
      live.dossier?.slots.single.probes.single.result,
      ProbeResult.notTried,
      reason: '旧correctedを保つと再接続前にCLEAR表示できてしまう',
    );
  });

  test('生徒が喋れば activityStart と音声が届く', () async {
    await live.start();
    await settle();

    mic.hear(0.5, pcm(320));
    await settle();

    expect(
      server.sawActivityStart,
      isTrue,
      reason: 'activityStart が無いと音声は捨てられる',
    );
    expect(server.audioFrames, isNotEmpty);
  });

  test('AI が鳴っている間はマイクの音を1バイトも送らない', () async {
    // この端末では AEC が効かず、AI の声を自分で拾って
    // 「内容をを」が生徒の発話として記録された（実機で確認）。
    // 記録が汚れるとカルテとディレクターがそれを読むので、測定そのものが壊れる
    await live.start();
    await settle();

    mic.hear(0.5, pcm(320));
    await settle();
    final before = server.audioFrames.length;
    expect(before, greaterThan(0));

    // AI が喋りはじめる（偽スピーカーは補充を要求しないので鳴り続ける）
    server.say({
      'serverContent': {
        'modelTurn': {
          'parts': [
            {
              'inlineData': {'mimeType': 'audio/pcm', 'data': audioB64(48000)},
            },
          ],
        },
      },
    });
    await settle();
    expect(live.state, LiveState.speaking);
    expect(live.isListeningToMic, isFalse);

    // AI の声を拾ったつもりで、大きな音を流し込む
    for (var i = 0; i < 10; i++) {
      mic.hear(0.9, pcm(320));
    }
    await settle();

    expect(server.audioFrames.length, before, reason: 'AI が鳴っている間に送ったフレームがある');
  });

  test('塞いだときに activityEnd を送る', () async {
    // 送らないと、モデルは生徒の発話が続いていると思って待ち続ける
    await live.start();
    await settle();

    mic.hear(0.5, pcm(320));
    await settle();
    expect(server.sawActivityEnd, isFalse);

    server.say({
      'serverContent': {
        'modelTurn': {
          'parts': [
            {
              'inlineData': {'mimeType': 'audio/pcm', 'data': audioB64(48000)},
            },
          ],
        },
      },
    });
    await settle();
    mic.hear(0.9, pcm(320)); // 塞がれた状態で音量が来る
    await settle();

    expect(server.sawActivityEnd, isTrue);
  });

  test('タップで止めるとマイクが戻る', () async {
    await live.start();
    await settle();

    server.say({
      'serverContent': {
        'modelTurn': {
          'parts': [
            {
              'inlineData': {'mimeType': 'audio/pcm', 'data': audioB64(48000)},
            },
          ],
        },
      },
    });
    await settle();
    expect(live.isListeningToMic, isFalse);

    live.silenceAi();
    // エコーの尾を待つあいだはまだ閉じている
    expect(live.isListeningToMic, isFalse);
    await settle(LiveSessionController.echoTail.inMilliseconds + 150);

    expect(live.isListeningToMic, isTrue);
    expect(live.state, LiveState.listening);
  });

  test('会話が始まっていなければタップしても何も起きない', () async {
    live.silenceAi();
    expect(live.state, LiveState.idle);
  });

  test('停止直前にbufferへ届いた最後の発話も保存する', () async {
    await live.start();
    await settle();
    server.say({
      'serverContent': {
        'inputTranscription': {'text': '停止直前の説明'},
      },
    });
    await settle();

    await live.stop();

    final saved = await store.unfinished(unitId: 'force-motion');
    expect(
      saved?.transcript.where((u) => u.isStudent).map((u) => u.text),
      contains('停止直前の説明'),
      reason: 'bufferをflushする前に保存すると最後の発話が欠落する',
    );
  });

  test('stop idleとdoneが競合しても完了を優先し、処理を二重化しない', () async {
    await live.start();
    await settle();

    final paused = live.stop();
    final completed = live.stop(to: LiveState.done);
    await Future.wait([paused, completed]);

    expect(live.state, LiveState.done);
    expect(live.completionSaveFailed, isFalse);
  });

  test('非再開切断のdoneはin-flight Directorと最新ターンを回収してCLEARする', () async {
    final director = _ControlledDirector();
    final orderedStore = _DelayedFirstSaveStore();
    store = orderedStore;
    live = LiveSessionController(
      unitId: 'force-motion',
      focusConceptKey: 'fall',
      tokens: FakeTokens(grantFor(server.port)),
      director: director,
      store: store,
      mic: mic,
      player: PcmPlayer(sink: sink),
    );
    await live.start(withMic: false);
    await settle();
    expect(director.pendingCount, 1, reason: '開始時のDirectorが待機中');

    server.say({
      'serverContent': {
        'inputTranscription': {'text': '条件をそろえると重さによらず同時に落ちる'},
        'turnComplete': true,
      },
    });
    await settle();
    expect(director.pendingCount, 1, reason: 'busy中は呼び出しを積み増さない');

    await server.hangUp();
    await waitUntil(
      () => live.notes.any((note) => note.startsWith('stop(to: done)')),
    );

    // 切断前から走っていた古い評価をまず返す。最新ターンがdirtyなので、
    // stop処理は次指示を送らず、最新逐語でもう1回だけ評価する。
    director.completeNext(
      _directorResult(probe: ProbeResult.notTried, instruction: '古い次指示は送らない'),
    );
    await waitUntil(() => director.calls.length == 2);
    expect(director.pendingCount, 1);
    expect(
      director.calls.last.utterances
          .where((utterance) => utterance.isStudent)
          .map((utterance) => utterance.text),
      contains('条件をそろえると重さによらず同時に落ちる'),
    );

    director.completeNext(
      _directorResult(
        probe: ProbeResult.corrected,
        instruction: '閉じたLiveへは送られない',
      ),
    );
    expect(orderedStore.saveCalls, 1, reason: '古いターン保存を意図的に待たせている');
    orderedStore.releaseFirstSave.complete();
    await waitUntil(() => live.state == LiveState.done);

    expect(
      live.dossier?.slots.single.probes.single.result,
      ProbeResult.corrected,
    );
    expect(live.sessionAchievements.single.conceptKey, 'fall');
    expect((await store.explained()).single.conceptKey, 'fall');
    expect(await store.reviewItems(), isEmpty);
    expect(
      orderedStore.savedProbeResults.last,
      ProbeResult.corrected,
      reason: '遅い古いsaveProgressより、最終dossierが必ず最後に保存される',
    );
    expect(
      await store.unfinished(unitId: 'force-motion', focusConceptKey: 'fall'),
      isNull,
      reason: '最終dossierをpersistしてからatomic completeMissionする',
    );
  });

  test('Director busy中の複数student turnは最新1回へcoalesceする', () async {
    final director = _ControlledDirector();
    live = LiveSessionController(
      unitId: 'force-motion',
      focusConceptKey: 'fall',
      tokens: FakeTokens(grantFor(server.port)),
      director: director,
      store: store,
      mic: mic,
      player: PcmPlayer(sink: sink),
    );
    await live.start(withMic: false);
    await settle();

    for (final text in ['一回目の説明', '二回目の訂正']) {
      server.say({
        'serverContent': {
          'inputTranscription': {'text': text},
          'turnComplete': true,
        },
      });
      await settle(30);
    }
    expect(director.calls.length, 1);
    expect(director.pendingCount, 1);

    director.completeNext(
      _directorResult(probe: ProbeResult.notTried, instruction: ''),
    );
    await waitUntil(() => director.calls.length == 2);
    expect(director.pendingCount, 1);
    expect(
      director.calls.last.utterances
          .where((utterance) => utterance.isStudent)
          .map((utterance) => utterance.text),
      ['一回目の説明', '二回目の訂正'],
    );

    director.completeNext(
      _directorResult(probe: ProbeResult.corrected, instruction: ''),
    );
    await settle(30);
    expect(director.calls.length, 2, reason: 'dirtyをboolでまとめ、3本目を作らない');
  });

  test('manual idle stopはpending Directorを待たない', () async {
    final director = _ControlledDirector();
    live = LiveSessionController(
      unitId: 'force-motion',
      tokens: FakeTokens(grantFor(server.port)),
      director: director,
      store: store,
      mic: mic,
      player: PcmPlayer(sink: sink),
    );
    await live.start(withMic: false);
    await settle();
    expect(director.pendingCount, 1);

    await live.stop().timeout(const Duration(milliseconds: 500));

    expect(live.state, LiveState.idle);
    expect(director.pendingCount, 1, reason: 'idle停止はDirector完了を待っていない');
    director.completeNext(
      _directorResult(probe: ProbeResult.corrected, instruction: ''),
    );
    await settle(30);
    expect(live.dossier, isNull, reason: '停止後に遅着した応答も適用しない');
  });

  test('idle最終notify中のreentrant done昇格も成果保存まで完走する', () async {
    live = LiveSessionController(
      unitId: 'force-motion',
      focusConceptKey: 'fall',
      tokens: FakeTokens(grantFor(server.port)),
      store: store,
      mic: mic,
      player: PcmPlayer(sink: sink),
    );
    await live.start(withMic: false);
    await settle();
    live.transcript.add(
      const Utterance(id: 'u01', isStudent: true, text: '条件をそろえると重さによらず同時に落ちる'),
    );
    live.dossier = _challengeDossier(ProbeResult.corrected);

    var upgraded = false;
    live.addListener(() {
      if (!upgraded && live.state == LiveState.idle) {
        upgraded = true;
        unawaited(live.stop(to: LiveState.done));
      }
    });

    await live.stop();

    expect(upgraded, isTrue);
    expect(live.state, LiveState.done);
    expect(live.completionSaveFailed, isFalse);
    expect((await store.explained()).single.conceptKey, 'fall');
    expect((await store.days()).single.done, 1);
    expect(
      await store.unfinished(unitId: 'force-motion', focusConceptKey: 'fall'),
      isNull,
    );
  });

  test('接続待ちで停止した古いstartが後からマイクを開かない', () async {
    final delayedMic = FakeMic();
    final delayedTokens = _DelayedTokens(grantFor(server.port));
    final delayedLive = LiveSessionController(
      unitId: 'force-motion',
      tokens: delayedTokens,
      store: MemorySessionStore(),
      mic: delayedMic,
      player: PcmPlayer(sink: FakeSink()),
    );
    addTearDown(delayedLive.dispose);

    final starting = delayedLive.start();
    await settle(30);
    expect(delayedLive.state, LiveState.connecting);

    final stopping = delayedLive.stop();
    delayedTokens.release.complete();
    await Future.wait([starting, stopping]);
    await settle(30);

    expect(delayedLive.state, LiveState.idle);
    expect(delayedLive.isRunning, isFalse);
    expect(delayedMic.started, isFalse, reason: '背景化後にマイクが開き直された');
  });
}
