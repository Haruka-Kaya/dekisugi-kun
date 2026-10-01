import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/day_key.dart';
import '../models/dossier.dart';
import '../models/mission.dart';
import '../models/review.dart';
import '../models/streak.dart';
import 'director_client.dart';
import 'director_queue.dart';
import 'live_token_client.dart';
import 'mic_stream.dart';
import 'pcm_player.dart';
import 'session_store.dart';
import 'speech_gate.dart';
import 'transcript_text.dart';
import 'vertex_live.dart';

/// 会話の見え方。**画面はこれだけを描き分ける。**
enum LiveState {
  idle,
  connecting,
  listening,
  thinking,
  speaking,
  done,

  /// 今日の無料ぶんを使い切った。**失敗ではなく仕様**
  outOfTime,
  failed,
}

/// 会話が成立しなかった理由。画面に出す文言を1か所に閉じる。
enum LiveFailure { noPermission, network, auth, unknown }

/// Vertex Live との会話ぜんぶ。
///
/// - 音声は端末と Vertex の間を直接流れる。**サーバは経由しない**
/// - 逐語と理解カルテは**端末が持つ**。サーバは状態を持たない
/// - ディレクターは1ターンごとに呼ぶが、**await しない**（実測6秒かかる）
///
/// > [!important] 発話の区切りは端末が決める
/// > Vertex では自動VADが働かず、音声を送っても黙って捨てられる。
/// > `activityStart` / `activityEnd` で囲んで初めて届く。
/// > つまり [SpeechGate] は表示のためだけの仕組みではなくなり、
/// > **これが狂うと会話そのものが成立しない。**
class LiveSessionController extends ChangeNotifier {
  LiveSessionController({
    required this.tokens,
    required this.unitId,
    this.focusConceptKey,
    TeachingTactic tactic = TeachingTactic.reason,
    this.missionKind = MissionKind.teach,
    DirectorClient? director,
    SessionStore? store,
    MicStream? mic,
    PcmPlayer? player,
    SpeechGate? gate,
    DirectorQueue? queue,
  }) : _tactic = missionKind == MissionKind.caseRetry
           ? TeachingTactic.reason
           : tactic,
       // 公開constructorのnamed parameter名を保つ。
       // ignore: prefer_initializing_formals
       _director = director,
       // ignore: prefer_initializing_formals
       _store = store,
       _mic = mic ?? MicStream(),
       _player = player ?? PcmPlayer(),
       _gate = gate ?? SpeechGate(),
       _queue = queue ?? DirectorQueue();

  TeachingTactic _tactic;

  /// 会話1回ぶんの資格情報をもらう先。
  final LiveTokenClient tokens;

  /// どの単元を教えてもらうか。
  final String unitId;

  /// この会話で扱う概念。null のときだけ従来の単元全体モードになる。
  ///
  /// 教材では1概念だけ読ませているため、ここをLive/Directorの両方へ渡さないと
  /// 読んでいない概念まで質問され、短いミッションという約束が崩れる。
  final String? focusConceptKey;

  /// 初回説明・組み直し・後日の具体場面のどれとして挑むか。
  /// API、端末保存、HUDで同じ値を使い、表示だけのRETRYにしない。
  final MissionKind missionKind;

  /// 教材を閉じる前に本人が選んだ、説明を始める足場。
  TeachingTactic get tactic => _tactic;

  final DirectorClient? _director;
  final SessionStore? _store;
  final MicStream _mic;
  final PcmPlayer _player;
  final SpeechGate _gate;
  final DirectorQueue _queue;

  VertexLiveSession? _session;
  StreamSubscription<LiveEvent>? _eventSub;
  StreamSubscription<Uint8List>? _micSub;
  StreamSubscription<double>? _levelSub;
  Timer? _drainTimer;
  final Stopwatch _clock = Stopwatch();

  /// いま使っている会話ブロック。残り回数の表示にも使う
  LiveGrant? grant;

  /// 今日の残り回数。課金済みなら null
  int? remainingSessions;

  /// 1回あたりの分数（サーバが教えてくれる）
  int minutesPerSession = 10;

  /// 無料枠が戻る時刻
  DateTime? quotaResetsAt;

  LiveState _state = LiveState.idle;
  LiveFailure? _failure;
  bool _closing = false;
  bool _directorBusy = false;
  bool _directorDirty = false;
  _DirectorFlight? _directorFlight;
  bool _disposed = false;

  /// 開始・停止の世代。接続待ちや権限ダイアログの途中で停止された古い処理が、
  /// 後からマイクやWebSocketを開き直すのを防ぐ。
  int _runGeneration = 0;

  /// stop はライフサイクル・画面操作・Director・切断から同時に来る。
  /// 実処理は必ず1本にまとめ、競合したら完了要求を優先する。
  Future<void>? _stopInFlight;
  LiveState _requestedStopState = LiveState.idle;

  /// Vertex が配る「続きから繋ぎ直す」ための札。**最後の1つだけ持つ。**
  ///
  /// サーバは一度もこれを見ない（Vertex から端末へ直接届く）ので、
  /// サーバ側で中身を検証することはできない。
  String? _resumeHandle;

  /// 連続で繋ぎ直した回数。会話が始まるたびに 0 に戻す
  int _resumeAttempts = 0;

  /// 会話の逐語。**時系列で1本。** 記録も画面もこれを見る。
  final List<Utterance> transcript = [];
  int _seq = 0;

  Dossier? dossier;
  String? lastLureId;
  String? challengeText;

  /// Liveへ送信済みで、まだAIの応答が確定していないDirector指示。
  /// queueへ積んだだけではtrueにしない。先行するAI発話を誤って
  /// LAST CHALLENGEへ結びつけるため。
  bool _directorInstructionInFlight = false;
  String? _inFlightChallengeLureId;
  String? _inFlightChallengeLureText;
  int? _sessionId;
  bool resumed = false;

  /// この会話を最後まで終えた時点で「説明できた」と確認できる内容。
  ///
  /// **本文はディレクターの `slot.content` ではなく、evidence が指す
  /// 実在の生徒発話から作る。** 完了画面と端末保存が同じ値を見る。
  final List<ExplainedItem> _sessionAchievements = [];
  List<ExplainedItem> get sessionAchievements =>
      List.unmodifiable(_sessionAchievements);

  bool _completionSaveFailed = false;
  bool get completionSaveFailed => _completionSaveFailed;
  bool _completionSaveInProgress = false;
  bool get completionSaveInProgress => _completionSaveInProgress;
  bool _progressPersisted = false;
  bool _achievementsPersisted = false;
  bool _recordFinished = false;

  /// ターンごとの非同期保存を直列化する。完了時の最終dossierが、遅れて終わった
  /// 古いsaveProgressに上書きされるのを防ぐ。
  Future<void> _persistTail = Future<void>.value();

  final StringBuffer _aiBuf = StringBuffer();
  final StringBuffer _studentBuf = StringBuffer();

  /// いま喋っている途中の文字起こし。確定前なので記録には使わない。
  String interimStudentText = '';

  /// 直近の出来事。**画面に出せる形で持つ。** release でも消えない
  final List<String> notes = [];

  final List<double> _peaks = [];
  int _selfInterruptions = 0;

  /// 文字で送った生徒の発話がターン確定を待っている
  bool _pendingStudentTurn = false;

  /// AI の再生が終わった時刻。エコーの尾を待つのに使う
  Duration? _playbackEndedAt;

  /// 再生が終わってからマイクを開けるまで。
  ///
  /// スピーカーが鳴りやんでも部屋の反射は少し残る。
  /// [PcmPlayer.maxResidual]（≤100ms）に余裕を足した値。
  static const Duration echoTail = Duration(milliseconds: 250);

  /// いまマイクを聞かないか。**AI が喋っている間は閉じる（半二重）。**
  ///
  /// この端末では AEC が効かず、AI の声を自分で拾って
  /// 「内容をを」のような文字列が**生徒の発話として記録された**（実機で確認）。
  /// 体験が悪くなるだけでなく、カルテとディレクターがそれを読むので
  /// 測定そのものが壊れる。
  ///
  /// 代わりに割り込みができなくなるが、この製品では AI の発話が
  /// 1〜2文・40字ほどなので失うものは小さい。
  /// 止めたいときは画面をタップする（[silenceAi]）。
  bool get _micMuted {
    if (_player.hasPending) return true;
    final ended = _playbackEndedAt;
    return ended != null && _clock.elapsed - ended < echoTail;
  }

  /// マイクを聞いているか。画面の表示に使う。
  bool get isListeningToMic => isRunning && !_micMuted;

  /// 文字で始めた会話に、あとからマイクを足す。
  ///
  /// 「声ではなす」を押した時点で初めて許可を求める。
  /// 断られても会話は続く（文字だけで進める）。
  Future<bool> enableMic() async {
    if (!isRunning || _micSub != null) return _micSub != null;
    final generation = _runGeneration;
    if (!await _mic.hasPermission()) return false;
    if (generation != _runGeneration || !isRunning) return false;
    if (!await _mic.start()) return false;
    if (generation != _runGeneration || !isRunning) {
      await _mic.stop();
      return false;
    }
    _gate.reset();
    _micSub = _mic.chunks.listen(_onMicChunk);
    _levelSub = _mic.level.listen(_onLevel);
    _note('マイクを後から有効にした');
    _notify();
    return true;
  }

  /// マイクを聞いているか（許可済みで動いているか）。
  bool get hasMic => _micSub != null;

  /// AI の発話を途中で止める。**タップから呼ぶ。**
  ///
  /// マイクでの割り込みは AEC が無いと成立しないので、
  /// 止める手段は音ではなく操作で持つ。会話は終わらせない。
  void silenceAi() {
    if (!isRunning) return;
    if (!_player.hasPending && _state != LiveState.speaking) return;
    _player.stopNow();
    _playbackEndedAt = _clock.elapsed;
    _note('AI の発話をタップで止めた');
    _setState(LiveState.listening);
    _pumpDirector();
  }

  LiveState get state => _state;
  LiveFailure? get failure => _failure;
  bool get isRunning => _session != null && !_session!.isClosed;

  /// 接続待ちを含め、画面を離れる前に明示的な停止が必要な状態。
  bool get isActive => _state == LiveState.connecting || isRunning;

  int get turnCount => transcript.where((u) => u.isStudent).length;
  Duration get elapsed => _clock.elapsed;

  /// ディレクターの終了判断に渡す残り秒。**セッションの上限から引く。**
  double get secondsLeft =>
      (Duration(minutes: minutesPerSession) - _clock.elapsed).inMilliseconds /
      1000.0;

  RecordingIssue? get recordingIssue => diagnose(_peaks);

  /// AI が自分の声を拾って自分を止めている疑いがあるか。
  ///
  /// エコーキャンセルが効かない端末では、スピーカーから出た AI の声を
  /// マイクが拾い、割り込みと判定されて発話が打ち切られる。
  /// 端末が AEC を持つかは `record` から分からないので**挙動から推定する**。
  bool get suspectsSelfInterruption => _selfInterruptions >= 3;

  Stream<double> get micLevel => _mic.level;
  Stream<double> get voiceLevel => _player.level;
  Duration get maxResidualAudio => PcmPlayer.maxResidual;

  // ── 開始と終了 ─────────────────────────────────────────────

  /// 中断していた会話を読み込む。**[start] の前に呼ぶ。**
  Future<bool> resumeSaved(SavedSession saved) async {
    if (_disposed || _state != LiveState.idle) return false;
    if (saved.unitId != unitId ||
        saved.focusConceptKey != focusConceptKey ||
        saved.missionKind != missionKind) {
      return false;
    }

    transcript
      ..clear()
      ..addAll(saved.transcript);
    final verifiedLureIds = <String>{};
    for (final utterance in transcript) {
      final lureId = utterance.challengeLureId;
      final expected = utterance.challengeLureText;
      if (!utterance.isStudent &&
          lureId != null &&
          expected != null &&
          isExactChallengeText(utterance.text, expected)) {
        verifiedLureIds.add(lureId);
      }
    }
    dossier = _retainVerifiedChallenges(saved.dossier, verifiedLureIds);
    lastLureId = null;
    challengeText = null;
    for (final utterance in transcript.reversed) {
      final lureId = utterance.challengeLureId;
      final expected = utterance.challengeLureText;
      if (!utterance.isStudent &&
          lureId != null &&
          expected != null &&
          isExactChallengeText(utterance.text, expected)) {
        lastLureId = lureId;
        challengeText = utterance.text.trim();
        break;
      }
    }
    _sessionAchievements.clear();
    _completionSaveFailed = false;
    _progressPersisted = false;
    _achievementsPersisted = false;
    _recordFinished = false;
    // 発話IDは連番。**使い回すとディレクターの根拠が別の発言を指す**
    _seq = transcript.length;
    _sessionId = saved.id;
    resumed = true;
    _tactic = missionKind == MissionKind.caseRetry
        ? TeachingTactic.reason
        : saved.tactic ?? _tactic;
    _notify();
    return true;
  }

  /// 再開候補を破棄し、Controller側に残っている同じセッションの参照も外す。
  /// DBだけ終了すると、次の通常開始が同じIDへ新しいVertex文脈を混ぜてしまう。
  Future<bool> discardSaved(SavedSession saved) async {
    if (_disposed ||
        isActive ||
        saved.unitId != unitId ||
        saved.focusConceptKey != focusConceptKey ||
        saved.missionKind != missionKind) {
      return false;
    }
    final store = _store;
    if (store == null) return false;

    await store.finishSession(saved.id);
    if (_sessionId == saved.id) {
      _sessionId = null;
      transcript.clear();
      dossier = null;
      lastLureId = null;
      challengeText = null;
      _directorInstructionInFlight = false;
      _inFlightChallengeLureId = null;
      _inFlightChallengeLureText = null;
      _directorDirty = false;
      _directorFlight = null;
      _directorBusy = false;
      _seq = 0;
      resumed = false;
      _sessionAchievements.clear();
      _completionSaveFailed = false;
      _progressPersisted = false;
      _achievementsPersisted = false;
      _recordFinished = false;
      _notify();
    }
    return true;
  }

  /// 今日あと何回始められるかを見る。**枠を引かない。**
  Future<void> refreshQuota() async {
    final q = await tokens.peek();
    if (q == null || _disposed) return;
    remainingSessions = q.remainingSessions;
    minutesPerSession = q.minutesPerSession;
    quotaResetsAt = q.resetsAt;
    if (q.isExhausted && _state == LiveState.idle) {
      _setState(LiveState.outOfTime);
    } else if (!q.isExhausted && _state == LiveState.outOfTime) {
      // Plus購入・復元、または日付更新後。表示だけ更新してoutOfTimeへ
      // 閉じ込めると、サーバーでは利用可能なのに開始ボタンが戻らない。
      _setState(LiveState.idle);
    } else {
      _notify();
    }
  }

  /// 会話を始める。
  ///
  /// [withMic] を false にすると、**マイクの許可を求めずに**繋ぐ。
  ///
  /// > [!important] 文字だけの生徒にマイクを要求しない
  /// > C8 は「人前で声を出せない生徒」のための経路（恥ずかしいと答えた
  /// > 日本人 71.1%）。その生徒に、文字を打つだけでマイクの許可を
  /// > 求めるのでは本末転倒になる（実機で気づいた）。
  Future<void> start({bool withMic = true}) async {
    const startable = {
      LiveState.idle,
      LiveState.failed,
      LiveState.done,
      LiveState.outOfTime,
    };
    if (!startable.contains(_state)) return;

    final continuingSession = _sessionId != null;
    final generation = ++_runGeneration;
    _setState(LiveState.connecting);
    _failure = null;
    _closing = false;
    _directorBusy = false;
    _directorDirty = false;
    _directorFlight = null;
    _completionSaveFailed = false;
    _progressPersisted = false;
    _achievementsPersisted = false;
    _recordFinished = false;
    _sessionAchievements.clear();
    if (!continuingSession) {
      lastLureId = null;
      challengeText = null;
    }
    _queue.clear();
    _directorInstructionInFlight = false;
    _inFlightChallengeLureId = null;
    _inFlightChallengeLureText = null;
    // 前の会話の札を持ち越さない。持ち越すと、別の会話の続きに繋ぎにいく
    _resumeHandle = null;
    _resumeAttempts = 0;

    // 記録の行を先に作る。途中で落ちても発話が行き場を失わないように
    if (_sessionId == null && _store != null) {
      final createdId = await _store.startSession(
        unitId,
        focusConceptKey: focusConceptKey,
        tactic: _tactic,
        missionKind: missionKind,
      );
      if (!_isCurrentRun(generation)) {
        await _store.finishSession(createdId);
        return;
      }
      _sessionId = createdId;
    }

    if (withMic) {
      final allowed = await _mic.hasPermission();
      if (!_isCurrentRun(generation)) return;
      if (!allowed) {
        _fail(LiveFailure.noPermission);
        return;
      }
    }

    try {
      await _player.init();
      if (!_isCurrentRun(generation)) return;
      if (!await _connect(generation: generation)) return;
      if (withMic) {
        final started = await _mic.start();
        if (!_isCurrentRun(generation)) {
          if (started) await _mic.stop();
          return;
        }
        if (!started) {
          await stop();
          if (_disposed) return;
          _fail(LiveFailure.noPermission);
          return;
        }
      }
      if (!_isCurrentRun(generation)) return;
      _clock
        ..reset()
        ..start();
      _gate.reset();
      if (withMic) {
        _micSub = _mic.chunks.listen(_onMicChunk);
        _levelSub = _mic.level.listen(_onLevel);
      }
      _drainTimer = Timer.periodic(
        const Duration(milliseconds: 120),
        (_) => _syncState(),
      );
      _setState(LiveState.listening);

      _note('開始: 残り $remainingSessions 回 / $minutesPerSession 分');
      // **会話したこと自体は連続の条件にしない**（C5）。
      // 後から「文字だけで済ませた生徒がどれくらいいるか」を見るために取る
      unawaited(_store?.recordActivity(dayKeyOf(DateTime.now()), sessions: 1));
      // 口火はディレクターに切らせる（C1）
      _kickDirector();
    } on QuotaExhausted catch (e) {
      if (!_isCurrentRun(generation)) return;
      quotaResetsAt = e.resetsAt;
      remainingSessions = 0;
      _setState(LiveState.outOfTime);
    } catch (e, s) {
      if (!_isCurrentRun(generation)) return;
      debugPrint('Live 接続に失敗: $e\n$s');
      final failure = _classify(e);
      if (isRunning) await stop();
      if (!_disposed) _fail(failure);
    }
  }

  bool _isCurrentRun(int generation) =>
      generation == _runGeneration && !_closing && !_disposed;

  Future<void> stop({LiveState to = LiveState.idle}) {
    // **誰が止めたかを残す。** 実機で会話が勝手に終わったとき、
    // 終了の経路が3つ（Vertex の切断／ディレクターの終了判断／画面）あって
    // どれを通ったのか分からなかった
    _note(
      'stop(to: ${to.name}) ${_clock.elapsed.inSeconds}秒 '
      '${_caller(StackTrace.current)}',
    );

    // 接続待ち・権限待ちを含む古い開始処理を、この呼び出し時点で無効化する。
    _runGeneration++;

    final active = _stopInFlight;
    if (active != null) {
      if (to == LiveState.done) _requestedStopState = LiveState.done;
      return active;
    }

    // 完了後の重複stopで成果を二重加算せず、doneをidleへも戻さない。
    // 保存失敗の再試行は retryCompletionSave() に一本化する。
    if (_state == LiveState.done && !isRunning) {
      return Future.value();
    }

    _requestedStopState = to;
    final completer = Completer<void>();
    _stopInFlight = completer.future;
    unawaited(() async {
      try {
        await _performStop();
      } catch (e, s) {
        debugPrint('会話の停止処理に失敗: $e\n$s');
      } finally {
        _closing = false;
        _stopInFlight = null;
        if (!completer.isCompleted) completer.complete();
      }
    }());
    return completer.future;
  }

  Future<void> _performStop() async {
    _closing = true;
    // stop() は世代を進めるため、通常の完了コールバックはこの応答を捨てる。
    // 先に切り離して手元へ保持し、done のときだけ接続を閉じたあとで回収する。
    // idle はこの Future を待たない。
    final stoppedDirectorFlight = _directorFlight;
    final directorWasDirty = _directorDirty;
    _directorFlight = null;
    _directorBusy = false;
    _directorDirty = false;
    _drainTimer?.cancel();
    _drainTimer = null;
    final micSub = _micSub;
    final levelSub = _levelSub;
    final eventSub = _eventSub;
    _micSub = null;
    _levelSub = null;
    _eventSub = null;

    // まず入力を遮断する。DB保存やWebSocket closeを待っている間も、
    // 背景で音声が送られ続けない順序にする。
    await _cancelSafely(micSub, 'マイク音声購読');
    await _cancelSafely(levelSub, '音量購読');
    try {
      await _mic.stop();
    } catch (e) {
      debugPrint('マイク停止に失敗: $e');
    }

    _clock.stop();
    _player.stopNow();
    await _cancelSafely(eventSub, 'Liveイベント購読');

    final session = _session;
    _session = null;
    try {
      await session?.close();
    } catch (e) {
      debugPrint('Live接続の終了に失敗: $e');
    }

    // 受信済みbufferを逐語へ移す。ここで生徒発話が増えた場合も、最終Directorに
    // 必ず再評価させる。逆順だと最後の訂正が成果から落ちる。
    final flushedStudentTurn = _flushTurns();
    final needsLatestDirector = directorWasDirty || flushedStudentTurn;

    var persisted = false;
    var completionFinalized = false;
    while (true) {
      final target = _requestedStopState;
      if (target == LiveState.done && !completionFinalized) {
        await _drainDirectorForCompletion(
          stoppedDirectorFlight,
          needsLatestEvaluation: needsLatestDirector,
        );
        // Directorが更新した最終dossierを、atomic completeMissionより先に残す。
        _progressPersisted = await _persist();
        persisted = true;
        await _finalizeCompletion();
        completionFinalized = true;
      } else if (!persisted) {
        // manual idle はDirectorを待たず、いま端末にある状態だけを残す。
        _progressPersisted = await _persist();
        persisted = true;
      }

      _setState(target);
      // idle の最終 notify 中に listener が stop(done) へ昇格しても、
      // stateだけdoneにせず、成果保存まで同じ停止処理で完走する。
      if (_requestedStopState == target) break;
    }
    _closing = false;
  }

  Future<void> _finalizeCompletion() async {
    _prepareFinalAchievements();
    if (focusConceptKey != null) {
      // 1概念ミッションは成果・再挑戦予定・完了数・session終了を
      // SessionStoreの1transactionで確定する。途中killや保存再試行で
      // MISSION CLEARを二重加算しない。
      if (_progressPersisted) {
        _recordFinished = await _completeFocusedMission();
      }
      _achievementsPersisted = _recordFinished;
    } else {
      // focusを持たない旧クライアントの単元全体会話だけは従来互換。
      _achievementsPersisted = await _saveAchievements(_sessionAchievements);
      if (_progressPersisted && _achievementsPersisted) {
        _recordFinished = await _finishRecord();
      }
    }
    _completionSaveFailed =
        !_progressPersisted || !_achievementsPersisted || !_recordFinished;
  }

  Future<void> _cancelSafely(
    StreamSubscription<dynamic>? subscription,
    String label,
  ) async {
    if (subscription == null) return;
    try {
      await subscription.cancel();
    } catch (e) {
      debugPrint('$label の停止に失敗: $e');
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
    await _mic.dispose();
    await _player.dispose();
    super.dispose();
  }

  // ── 接続 ──────────────────────────────────────────────────

  Future<bool> _connect({String? resumeHandle, required int generation}) async {
    final g = await tokens.reserve(
      unitId,
      resumeHandle: resumeHandle,
      focusConceptKey: focusConceptKey,
      tactic: _tactic,
      missionKind: missionKind,
    );
    if (!_isCurrentRun(generation)) return false;

    final session = await VertexLiveSession.connect(g);
    if (!_isCurrentRun(generation)) {
      await session.close();
      return false;
    }

    // 合図はサーバが毎回作る。**システム指示に入っているものと必ず揃える**
    grant = g;
    remainingSessions = g.remainingSessions;
    minutesPerSession = g.sessionMinutes;
    quotaResetsAt = g.resetsAt;
    _queue.prefix = g.directorPrefix;

    _session = session;
    _eventSub = session.events.listen(_onEvent);
    return true;
  }

  // ── 受信 ──────────────────────────────────────────────────

  void _onEvent(LiveEvent e) {
    if (_closing || _disposed) return;
    switch (e) {
      case LiveReady():
        _note('setup 完了');

      case LiveAudio(:final pcm):
        _player.enqueue(pcm);
        _setState(LiveState.speaking);

      case LiveInterrupted():
        // 割り込み。**最優先で音を止める**
        _noteInterruption();
        _player.stopNow();
        _flushAiTurn();
        _setState(LiveState.listening);
        _pumpDirector();

      case LiveInterimStudent(:final text):
        interimStudentText = tidyJa(text);
        _notify();

      case LiveStudentText(:final text):
        _studentBuf.write(text);

      case LiveAiText(:final text):
        _aiBuf.write(text);
        _guardInstructionLeak();

      case LiveTurnComplete():
        final hadStudentTurn = _flushTurns();
        unawaited(_persist());
        _pumpDirector();
        // 生徒が喋ったターンの後だけ呼ぶ。AI の独り言では状況が変わらない
        if (hadStudentTurn) _kickDirector();

      case LiveResumptionHandle(:final handle):
        // **最後の1つだけ持つ。** 切れたときにこれで続きから繋ぎ直す
        _resumeHandle = handle;

      case LiveGoingAway():
        // まもなく切る、という予告。ハンドルはこの前後に届いている
        _note('Live から goAway');

      case final LiveClosed closed:
        _note('Live 切断: code=${closed.code} reason=${closed.reason}');
        if (_closing) break;
        if (_canResume(closed)) {
          unawaited(_reconnect());
        } else {
          unawaited(_onSessionEnded());
        }

      case LiveFailed(:final detail):
        _note('Live エラー: $detail');
        if (!_closing) _fail(_classify(detail));
    }
  }

  /// 会話が終わった・落ちたときの記録。**release でも残す。**
  ///
  /// 実機で会話が18秒で切れたとき、理由を書いた行が1つも残っておらず、
  /// 原因の特定に丸ごと1周かかった。
  ///
  /// > [!warning] `developer.log` を使わないこと
  /// > release build では VM サービス側へ流れるだけで logcat に出ない
  /// > （実機で確認。1行も残らなかった）。`debugPrint` は出る。
  ///
  /// [notes] にも積むので、logcat が取れない場面では画面から読める。
  /// 呼び出し元を1行にする。release では記号名が落ちるので、
  /// 分かるのは「どのフレームから来たか」の目安だけ。
  static String _caller(StackTrace s) {
    final lines = s.toString().split('\n');
    return lines.length > 2 ? lines[1].trim() : '';
  }

  void _note(String message) {
    notes.add(message);
    if (notes.length > 50) notes.removeAt(0);
    debugPrint('[live] $message');
  }

  /// 続きから繋ぎ直してよいか。
  ///
  /// Vertex は約9分でセッションを切る（実測 `code=1000`）。
  /// そこで会話を終わらせると、生徒には
  /// 「10分と言われたのに9分で打ち切られた」ように見える。
  ///
  /// **枠を伸ばすためのものではない。** 残り時間が尽きていれば繋ぎ直さない。
  bool _canResume(LiveClosed closed) =>
      closed.isSessionLimit &&
      _resumeHandle != null &&
      secondsLeft > _resumeFloorSeconds &&
      _resumeAttempts < maxResumeAttempts;

  /// 連続で繋ぎ直す上限。**無いと失敗のたびに繋ぎ直して枠と請求を焼く。**
  static const int maxResumeAttempts = 2;

  /// これ以下しか残っていなければ繋ぎ直さない。
  /// 数秒のために接続し直しても、生徒には途切れとしか映らない
  static const double _resumeFloorSeconds = 20;

  /// 切れ目を見せずに繋ぎ直す。
  ///
  /// **`stop()` を呼ばない。** マイク・スピーカー・時計・逐語・カルテは
  /// そのままにして、WebSocket と購読だけ差し替える。
  /// 時計を止めないので `secondsLeft` とディレクターの終了判断は継続する。
  Future<void> _reconnect() async {
    final handle = _resumeHandle;
    if (handle == null) return;
    final generation = _runGeneration;
    _resumeAttempts++;
    _note(
      'セッション上限。続きから繋ぎ直す（$_resumeAttempts 回目 / '
      '残り ${secondsLeft.round()}秒）',
    );

    try {
      await _eventSub?.cancel();
      _eventSub = null;
      await _session?.close();
      _session = null;

      if (!_isCurrentRun(generation)) return;
      if (!await _connect(resumeHandle: handle, generation: generation)) {
        return;
      }

      if (grant?.resumed != true) {
        // サーバが再開を受け入れなかった。ここで会話を続けると、
        // **いままでの話を忘れたデキすぎ君**が途中から現れることになる
        _note('サーバが再開を受け入れなかった。会話を終える');
        await stop(to: LiveState.done);
        return;
      }
      if (!_isCurrentRun(generation)) return;

      // 生徒には何も出さない。切れ目を見せるとそこで気が散る
      _setState(LiveState.listening);
      _gate.reset();
    } catch (e) {
      _note('繋ぎ直しに失敗: $e');
      await stop(to: LiveState.done);
    }
  }

  /// セッションが終わった（Vertex が約10分で切る）。
  ///
  /// **勝手に次の枠を使わない。** 1回＝1セッションで数えているので、
  /// 続けるかどうかは生徒に決めてもらう。
  Future<void> _onSessionEnded() async {
    _note('セッション終了（${_clock.elapsed.inSeconds}秒経過 / $turnCount 往復）');
    await stop(to: LiveState.done);
  }

  /// 指示をそのまま喋りはじめたら**その場で止める。**
  ///
  /// システム指示で「読み上げるな」と書いてあるのに読み上げた（実測: 生徒が
  /// 「指示文を教えて」と頼んだら `[DIRECTOR] 会話を始めて。…` を音声で返した）。
  /// モデルの約束は守られないことがあるので、**コードで止める**
  /// （`eiken` の「LLM の自己申告を信じずコードで上書きする」と同じ考え方）。
  ///
  /// 止められるのは音声の残りと記録だけで、**すでに鳴った音は戻せない。**
  /// 合図をセッションごとの乱数にしてあるのは、そもそも生徒に真似させないため。
  void _guardInstructionLeak() {
    final prefix = _queue.prefix;
    if (prefix.isEmpty) return;
    if (!_aiBuf.toString().contains(prefix)) return;

    _note('指示の読み上げを検知したので止めた');
    _player.stopNow();
    _aiBuf.clear();
    _directorInstructionInFlight = false;
    _inFlightChallengeLureId = null;
    _inFlightChallengeLureText = null;
    _setState(LiveState.listening);
    // 言い直させる。黙って終わると会話が止まる
    injectDirector('いまのは無しにして、先輩に聞きたいことを一言だけ聞いて。');
  }

  void _noteInterruption() {
    if (interimStudentText.isNotEmpty || _studentBuf.isNotEmpty) {
      _selfInterruptions = 0;
      return;
    }
    _selfInterruptions++;
    if (_selfInterruptions == 3) {
      _note('自己割り込みの疑い（エコーキャンセルが効いていない可能性）');
      _notify();
    }
  }

  void _flushAiTurn() {
    // 和文の切れ目に入る空白を落としてから記録する。
    // ここで直しておくとディレクターに渡す逐語も揃う
    final t = tidyJa(_aiBuf.toString());
    _aiBuf.clear();
    final candidateLureId = _inFlightChallengeLureId;
    final expectedLureText = _inFlightChallengeLureText;
    _directorInstructionInFlight = false;
    _inFlightChallengeLureId = null;
    _inFlightChallengeLureText = null;
    if (t.isEmpty) return;
    final isVerifiedChallenge =
        candidateLureId != null &&
        candidateLureId.trim().isNotEmpty &&
        expectedLureText != null &&
        isExactChallengeText(t, expectedLureText);
    final challengeLureId = isVerifiedChallenge ? candidateLureId : null;
    transcript.add(
      Utterance(
        id: _nextId(),
        isStudent: false,
        text: t,
        challengeLureId: challengeLureId,
        challengeLureText: isVerifiedChallenge ? expectedLureText : null,
      ),
    );
    if (challengeLureId != null) {
      lastLureId = challengeLureId;
      challengeText = t;
    } else if (candidateLureId != null) {
      _note('固定challengeと一致しないAI発話を観測対象から外した');
    }
  }

  bool _flushTurns() {
    final s = tidyJa(_studentBuf.toString());
    _studentBuf.clear();
    // 文字で送ったぶんは逐語へ追加済みなので、ここでは「あった」ことだけ引き継ぐ
    final hadStudent = s.isNotEmpty || _pendingStudentTurn;
    _pendingStudentTurn = false;
    if (s.isNotEmpty) {
      transcript.add(Utterance(id: _nextId(), isStudent: true, text: s));
    }
    interimStudentText = '';
    _flushAiTurn();
    _notify();
    return hadStudent;
  }

  /// 発話IDはディレクターが根拠として引用する。**連番で、使い回さない。**
  String _nextId() => 'u${(++_seq).toString().padLeft(2, '0')}';

  // ── 送信 ──────────────────────────────────────────────────

  /// マイクの断片。**喋っていると判断している間だけ送る。**
  ///
  /// Vertex は `activityStart` の外で来た音声を黙って捨てるので、
  /// ここで送らなかったぶんは存在しなかったことになる。
  void _onMicChunk(Uint8List chunk) {
    if (_closing) return;
    final s = _session;
    if (s == null || s.isClosed) return;
    if (!_gate.isSpeaking) return;
    s.sendAudio(chunk);
  }

  void _onLevel(double peak) {
    if (_closing) return;
    // 記録する音量は AI の再生ぶんを除く。混ぜると
    // 「マイクが拾えていない」の判定が AI の声で埋まって出なくなる
    if (!_micMuted) {
      _peaks.add(peak);
      if (_peaks.length > 300) _peaks.removeAt(0);
    }

    if (!_gate.update(peak, _clock.elapsed, muted: _micMuted)) return;

    final s = _session;
    if (s == null || s.isClosed) return;

    if (_gate.isSpeaking) {
      // 喋りはじめた。**これを送らないと以降の音声が全部捨てられる**
      s.beginSpeech();
      if (_state == LiveState.thinking) _setState(LiveState.listening);
    } else {
      // 喋り終わった。**これを送らないとモデルは応答しない**
      s.endSpeech();
      if (_state == LiveState.listening) _setState(LiveState.thinking);
    }
    _pumpDirector();
  }

  // ── ディレクター ───────────────────────────────────────────

  /// 生徒の発話を**文字で**送る。音声と対等な第一級の経路（C8）。
  ///
  /// 人前での音声利用を恥ずかしいと答えた日本人が 71.1%。
  /// 電車・教室・家族のいる部屋で使えないなら、その生徒にとっては
  /// アプリごと存在しないのと同じになる。
  ///
  /// **未接続なら自分で繋いでから送る。** 「先にマイクを押してから文字を打つ」を
  /// 要求すると音声が既定＝一級のままになり、C8 を満たさない。
  /// 画面側に分岐を作らず、ここに寄せてテストできるようにしている。
  ///
  /// 生徒の発話として扱うので、逐語にもディレクターにも普通に流れる。
  /// 逐語へ受理できたときだけ true。接続失敗時は false を返し、入力欄側が
  /// 書きかけの文を消さずに残せるようにする。
  Future<bool> sendStudentText(String text) async {
    final t = text.trim();
    if (t.isEmpty) return false;

    if (!isRunning) {
      // **マイクを求めずに繋ぐ。** 文字だけで済ませたい生徒に
      // マイクの許可を出させない（C8）
      await start(withMic: false);
      // 繋がらなかった。`_failure` は start が立てているのでここでは触らない
      if (!isRunning) return false;
    }

    final s = _session;
    if (s == null || s.isClosed) return false;

    transcript.add(Utterance(id: _nextId(), isStudent: true, text: t));
    // ターンの区切りで「生徒が喋った」と判定させる。
    // 音声経路では _studentBuf を見ているが、こちらは通らない
    _pendingStudentTurn = true;
    _setState(LiveState.thinking);
    _notify();
    s.sendText(t);
    unawaited(_store?.recordActivity(dayKeyOf(DateTime.now()), textTurns: 1));
    return true;
  }

  void injectDirector(
    String instruction, {
    String? challengeLureId,
    String? challengeLureText,
  }) {
    final dropped = _queue.add(
      instruction,
      challengeLureId: challengeLureId,
      challengeLureText: challengeLureText,
    );
    if (dropped != null) debugPrint('ディレクターの指示を捨てた（溜まりすぎ）: $dropped');
    _pumpDirector();
  }

  void _pumpDirector() {
    final s = _session;
    if (s == null || s.isClosed || _directorInstructionInFlight) return;
    // 「静か」= AI が喋っておらず、生徒も喋っていない
    final quiet = _state == LiveState.listening && !_gate.isSpeaking;
    final text = _queue.takeIfQuiet(quiet);
    if (text == null) return;
    _directorInstructionInFlight = true;
    _inFlightChallengeLureId = _queue.lastTakenChallengeLureId;
    _inFlightChallengeLureText = _queue.lastTakenChallengeLureText;
    // **`realtimeInput.text` を使わないこと。** 音声が返らない
    s.sendText(text);
  }

  /// カルテを更新して次の一手をもらう。**await しない**（実測6秒）。
  void _kickDirector() {
    final client = _director;
    if (client == null || !client.isConfigured) return;
    if (_directorFlight != null || _directorBusy) {
      // Director待ちの間に生徒がさらに話した。呼び出しを積み上げず、
      // 返答後に最新逐語で1回だけ再評価する。
      _directorDirty = true;
      return;
    }
    final generation = _runGeneration;
    _directorBusy = true;
    final flight = _DirectorFlight(
      generation: generation,
      response: _requestDirector(client),
    );
    _directorFlight = flight;
    unawaited(_settleDirector(flight));
  }

  Future<DirectorResult?> _requestDirector(DirectorClient client) async =>
      client.run(
        unitId: unitId,
        focusConceptKey: focusConceptKey,
        tactic: _tactic,
        missionKind: missionKind,
        dossier: dossier,
        utterances: List.of(transcript),
        secondsLeft: secondsLeft,
        turnCount: turnCount,
      );

  Future<void> _settleDirector(_DirectorFlight flight) async {
    DirectorResult? result;
    try {
      result = await flight.response;
    } catch (e) {
      debugPrint('ディレクターで例外: $e');
    }
    if (!identical(_directorFlight, flight)) return;
    _directorFlight = null;
    _directorBusy = false;
    if (!_isCurrentRun(flight.generation)) return;

    final rerunLatest = _directorDirty;
    _directorDirty = false;
    if (result != null) {
      // より新しい生徒発話があるなら古い次指示・終了判断は流さず、
      // dossier/correctionだけを土台にして最新1回へまとめる。
      _applyDirector(
        result,
        continueConversation: !rerunLatest,
        persist: !rerunLatest,
      );
    }
    if (rerunLatest && _isCurrentRun(flight.generation)) _kickDirector();
  }

  /// 既存応答と最終評価を各1回だけ待つ。片方が固まっても、もう片方の
  /// 最新逐語評価を試す時間を必ず残し、停止全体も最大12秒に収める。
  static const Duration _directorCompletionStageBudget = Duration(seconds: 6);

  Future<void> _drainDirectorForCompletion(
    _DirectorFlight? flight, {
    required bool needsLatestEvaluation,
  }) async {
    final client = _director;
    if (client == null || !client.isConfigured) return;

    var runLatest = needsLatestEvaluation;
    if (flight != null) {
      final result = await _awaitDirector(flight.response);
      if (result != null) {
        _applyDirector(result, continueConversation: false, persist: false);
      } else {
        runLatest = true;
      }
    }

    if (runLatest) {
      final result = await _awaitDirector(_requestDirector(client));
      if (result != null) {
        _applyDirector(result, continueConversation: false, persist: false);
      }
    }
    _directorDirty = false;
    _directorBusy = false;
  }

  Future<DirectorResult?> _awaitDirector(
    Future<DirectorResult?> response,
  ) async {
    try {
      return await response.timeout(_directorCompletionStageBudget);
    } on TimeoutException {
      _note('最終Directorの待機が上限に達した');
      return null;
    } catch (e) {
      debugPrint('最終Directorで例外: $e');
      return null;
    }
  }

  void _applyDirector(
    DirectorResult result, {
    bool continueConversation = true,
    bool persist = true,
  }) {
    if (result.corrections.isNotEmpty) {
      for (var i = 0; i < transcript.length; i++) {
        final fixed = result.corrections[transcript[i].id];
        if (fixed != null) transcript[i] = transcript[i].withCorrection(fixed);
      }
    }

    dossier = result.dossier;
    _notify();
    if (persist && (!continueConversation || !result.shouldEnd)) {
      unawaited(_persist());
    }

    // stop中の最終評価はdossier/correctionだけを採用する。閉じたsocketへ
    // 次指示を送り返したり、stopを再入させたりしない。
    if (!continueConversation) return;

    if (result.shouldEnd) {
      _note('ディレクターが終了を指示: ${result.endReason}');
      unawaited(stop(to: LiveState.done));
      return;
    }
    if (result.nextInstruction.isNotEmpty) {
      final lureId = result.lureId?.trim();
      final lureText = result.lureText?.trim();
      final hasCompleteLure =
          lureId != null &&
          lureId.isNotEmpty &&
          lureText != null &&
          lureText.isNotEmpty;
      injectDirector(
        result.nextInstruction,
        challengeLureId: hasCompleteLure ? lureId : null,
        challengeLureText: hasCompleteLure ? lureText : null,
      );
    }
  }

  // ── 記録 ──────────────────────────────────────────────────

  /// 会話途中の一時的な explained ではなく、**最終カルテ**から成果を確定する。
  /// 後続の誘発で誤概念を訂正できなかったslotは「言えるようになった」にしない。
  /// 中断再開でも最終dossierと逐語が残るため、前半の成果を復元できる。
  void _prepareFinalAchievements() {
    _sessionAchievements.clear();
    final finalDossier = dossier;
    if (finalDossier == null) return;

    final now = DateTime.now();
    final usedKeys = <String>{};
    for (final slot in finalDossier.slots) {
      if (!slot.isExplained ||
          slot.hasAcceptedMisconception ||
          (focusConceptKey != null &&
              !slot.probes.any(
                (probe) => probe.result == ProbeResult.corrected,
              )) ||
          !usedKeys.add(slot.key)) {
        continue;
      }
      final said = studentExplanationFor(slot, transcript);
      if (said.isEmpty) continue;
      _sessionAchievements.add(
        ExplainedItem(
          unitId: finalDossier.unitId,
          conceptKey: slot.key,
          label: slot.label,
          said: said,
          at: now,
        ),
      );
    }
  }

  Future<bool> _saveAchievements(List<ExplainedItem> items) async {
    final store = _store;
    if (items.isEmpty) return true;
    if (store == null) return false;
    try {
      // recordExplained は同じ概念を置換するため再試行しても増えない。
      // 加算の recordActivity は最後に1回だけ行い、部分成功時の水増しを防ぐ。
      for (final item in items) {
        await store.recordExplained(item);
      }
      await store.recordActivity(dayKeyOf(DateTime.now()), done: items.length);
      return true;
    } catch (e) {
      debugPrint('言えるようになったことの記録に失敗: $e');
      return false;
    }
  }

  /// 完了画面から、失敗した保存処理だけを再試行する。
  Future<bool> retryCompletionSave() async {
    if (_disposed || _state != LiveState.done) return false;
    if (_completionSaveInProgress) return !_completionSaveFailed;

    _completionSaveInProgress = true;
    _notify();
    try {
      if (!_progressPersisted) _progressPersisted = await _persist();
      if (focusConceptKey != null) {
        if (_progressPersisted && !_recordFinished) {
          _recordFinished = await _completeFocusedMission();
        }
        _achievementsPersisted = _recordFinished;
      } else {
        if (!_achievementsPersisted) {
          _achievementsPersisted = await _saveAchievements(
            _sessionAchievements,
          );
        }
        if (_progressPersisted && _achievementsPersisted && !_recordFinished) {
          _recordFinished = await _finishRecord();
        }
      }
      _completionSaveFailed =
          !_progressPersisted || !_achievementsPersisted || !_recordFinished;
      return !_completionSaveFailed;
    } finally {
      _completionSaveInProgress = false;
      _notify();
    }
  }

  /// いまの状態を端末へ書く。**1ターンごとに呼ぶ。**
  /// Android は裏に回ったアプリを予告なく落とすので、終了時にまとめて書かない。
  Future<bool> _persist() {
    final id = _sessionId;
    final store = _store;
    if (id == null || store == null) return Future<bool>.value(true);
    final transcriptSnapshot = List<Utterance>.of(transcript);
    final dossierSnapshot = dossier;
    final write = _persistTail.then((_) async {
      try {
        await store.saveProgress(
          id,
          transcript: transcriptSnapshot,
          dossier: dossierSnapshot,
        );
        return true;
      } catch (e) {
        debugPrint('記録に失敗: $e');
        return false;
      }
    });
    _persistTail = write.then<void>((_) {});
    return write;
  }

  Future<bool> _finishRecord() async {
    final id = _sessionId;
    final store = _store;
    if (id == null || store == null) return true;
    try {
      await store.finishSession(id);
      final d = dossier;
      if (d != null) {
        await store.upsertReviews(reviewItemsOf(d, DateTime.now()));
      }
      _sessionId = null;
      return true;
    } catch (e) {
      debugPrint('会話の締めに失敗: $e');
      return false;
    }
  }

  /// focusedミッションを、画面のCLEAR判定と同じ証拠で原子的に確定する。
  Future<bool> _completeFocusedMission() async {
    final id = _sessionId;
    final store = _store;
    final conceptKey = focusConceptKey;
    if (id == null || store == null || conceptKey == null) return false;

    final now = DateTime.now();
    ExplainedItem? explained;
    for (final item in _sessionAchievements) {
      if (item.unitId == unitId && item.conceptKey == conceptKey) {
        explained = item;
        break;
      }
    }
    final cleared = explained != null;
    ReviewItem? review;
    if (!cleared) {
      Slot? target;
      for (final slot in dossier?.slots ?? const <Slot>[]) {
        if (slot.key == conceptKey) {
          target = slot;
          break;
        }
      }
      final reason = target?.hasAcceptedMisconception == true
          ? ReviewReason.notCorrected
          : target?.status == SlotStatus.thin
          ? ReviewReason.thin
          : ReviewReason.notFinished;
      review = ReviewItem(
        unitId: unitId,
        conceptKey: conceptKey,
        label: switch (target?.label.trim()) {
          final label? when label.isNotEmpty => label,
          _ => conceptKey,
        },
        reason: reason,
        lastSeen: now,
      );
    }

    try {
      await store.completeMission(
        id,
        cleared: cleared,
        completedAt: now,
        explained: explained,
        review: review,
      );
      _sessionId = null;
      return true;
    } catch (e) {
      debugPrint('ミッションの確定に失敗: $e');
      return false;
    }
  }

  // ── 状態 ──────────────────────────────────────────────────

  void _syncState() {
    if (_state == LiveState.speaking && !_player.hasPending) {
      // エコーの尾を待ってからマイクを開ける
      _playbackEndedAt = _clock.elapsed;
      _setState(LiveState.listening);
      _pumpDirector();
    }
  }

  void _setState(LiveState s) {
    if (_state == s) return;
    _state = s;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _fail(LiveFailure f) {
    _failure = f;
    _setState(LiveState.failed);
  }

  LiveFailure _classify(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('401') || s.contains('403') || s.contains('unauthor')) {
      return LiveFailure.auth;
    }
    if (s.contains('socket') ||
        s.contains('timeout') ||
        s.contains('network') ||
        s.contains('connection') ||
        s.contains('failed host lookup')) {
      return LiveFailure.network;
    }
    return LiveFailure.unknown;
  }
}

class _DirectorFlight {
  const _DirectorFlight({required this.generation, required this.response});

  final int generation;
  final Future<DirectorResult?> response;
}

/// 旧クライアントがIDだけで作ったprobe判定を再開時に引き継がない。
///
/// 固定本文とLive発話の一致を検証できたIDのみ保つ。サーバも
/// catalog本文で再検証するため、ここは再接続前のUIをfail-closedにする守り。
Dossier? _retainVerifiedChallenges(
  Dossier? source,
  Set<String> verifiedLureIds,
) {
  if (source == null) return null;
  var changed = false;
  final slots = source.slots.map((slot) {
    final probes = slot.probes.map((probe) {
      if (verifiedLureIds.contains(probe.id) ||
          (probe.result == ProbeResult.notTried &&
              probe.evidence.isEmpty &&
              !probe.countered)) {
        return probe;
      }
      changed = true;
      return Probe(
        id: probe.id,
        result: ProbeResult.notTried,
        evidence: const [],
      );
    }).toList();
    return Slot(
      key: slot.key,
      label: slot.label,
      status: slot.status,
      content: slot.content,
      evidence: slot.evidence,
      followUpHint: slot.followUpHint,
      probes: probes,
    );
  }).toList();
  return changed
      ? Dossier(unitId: source.unitId, slots: slots, coverage: source.coverage)
      : source;
}
