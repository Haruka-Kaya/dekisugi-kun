import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../models/dossier.dart';
import '../models/review.dart';
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
    DirectorClient? director,
    SessionStore? store,
    MicStream? mic,
    PcmPlayer? player,
    SpeechGate? gate,
    DirectorQueue? queue,
  })  : _director = director,
        _store = store,
        _mic = mic ?? MicStream(),
        _player = player ?? PcmPlayer(),
        _gate = gate ?? SpeechGate(),
        _queue = queue ?? DirectorQueue();

  /// 会話1回ぶんの資格情報をもらう先。
  final LiveTokenClient tokens;

  /// どの単元を教えてもらうか。
  final String unitId;

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

  /// 会話の逐語。**時系列で1本。** 記録も画面もこれを見る。
  final List<Utterance> transcript = [];
  int _seq = 0;

  Dossier? dossier;
  String? lastLureId;
  int? _sessionId;
  bool resumed = false;

  final StringBuffer _aiBuf = StringBuffer();
  final StringBuffer _studentBuf = StringBuffer();

  /// いま喋っている途中の文字起こし。確定前なので記録には使わない。
  String interimStudentText = '';

  /// 直近の出来事。**画面に出せる形で持つ。** release でも消えない
  final List<String> notes = [];

  final List<double> _peaks = [];
  int _selfInterruptions = 0;

  LiveState get state => _state;
  LiveFailure? get failure => _failure;
  bool get isRunning => _session != null && !_session!.isClosed;

  int get turnCount => transcript.where((u) => u.isStudent).length;
  Duration get elapsed => _clock.elapsed;

  /// ディレクターの終了判断に渡す残り秒。**セッションの上限から引く。**
  double get secondsLeft =>
      (Duration(minutes: minutesPerSession) - _clock.elapsed).inMilliseconds / 1000.0;

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
    if (_state != LiveState.idle) return false;
    if (saved.unitId != unitId) return false;

    transcript
      ..clear()
      ..addAll(saved.transcript);
    dossier = saved.dossier;
    // 発話IDは連番。**使い回すとディレクターの根拠が別の発言を指す**
    _seq = transcript.length;
    _sessionId = saved.id;
    resumed = true;
    notifyListeners();
    return true;
  }

  /// 今日あと何回始められるかを見る。**枠を引かない。**
  Future<void> refreshQuota() async {
    final q = await tokens.peek();
    if (q == null) return;
    remainingSessions = q.remainingSessions;
    minutesPerSession = q.minutesPerSession;
    quotaResetsAt = q.resetsAt;
    if (q.isExhausted && _state == LiveState.idle) {
      _setState(LiveState.outOfTime);
    } else {
      notifyListeners();
    }
  }

  Future<void> start() async {
    const startable = {
      LiveState.idle,
      LiveState.failed,
      LiveState.done,
      LiveState.outOfTime,
    };
    if (!startable.contains(_state)) return;

    _setState(LiveState.connecting);
    _failure = null;
    _closing = false;

    // 記録の行を先に作る。途中で落ちても発話が行き場を失わないように
    _sessionId ??= await _store?.startSession(unitId);

    if (!await _mic.hasPermission()) {
      _fail(LiveFailure.noPermission);
      return;
    }

    try {
      await _player.init();
      await _connect();
      if (!await _mic.start()) {
        _fail(LiveFailure.noPermission);
        return;
      }
      _clock
        ..reset()
        ..start();
      _gate.reset();
      _micSub = _mic.chunks.listen(_onMicChunk);
      _levelSub = _mic.level.listen(_onLevel);
      _drainTimer =
          Timer.periodic(const Duration(milliseconds: 120), (_) => _syncState());
      _setState(LiveState.listening);

      // 口火はディレクターに切らせる（C1）
      _kickDirector();
    } on QuotaExhausted catch (e) {
      quotaResetsAt = e.resetsAt;
      remainingSessions = 0;
      _setState(LiveState.outOfTime);
    } catch (e, s) {
      debugPrint('Live 接続に失敗: $e\n$s');
      _fail(_classify(e));
    }
  }

  Future<void> stop({LiveState to = LiveState.idle}) async {
    _closing = true;
    await _persist();
    if (to == LiveState.done) await _finishRecord();

    _drainTimer?.cancel();
    _drainTimer = null;
    await _micSub?.cancel();
    await _levelSub?.cancel();
    await _eventSub?.cancel();
    _micSub = null;
    _levelSub = null;
    _eventSub = null;
    _clock.stop();
    await _mic.stop();
    _player.stopNow();
    await _session?.close();
    _session = null;
    _flushTurns();
    _setState(to);
    _closing = false;
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _mic.dispose();
    await _player.dispose();
    super.dispose();
  }

  // ── 接続 ──────────────────────────────────────────────────

  Future<void> _connect() async {
    final g = await tokens.reserve(unitId);
    grant = g;
    remainingSessions = g.remainingSessions;
    minutesPerSession = g.sessionMinutes;
    quotaResetsAt = g.resetsAt;

    final session = await VertexLiveSession.connect(g);
    _session = session;
    _eventSub = session.events.listen(_onEvent);
  }

  // ── 受信 ──────────────────────────────────────────────────

  void _onEvent(LiveEvent e) {
    switch (e) {
      case LiveReady():
        break;

      case LiveAudio(:final pcm):
        _player.enqueue(pcm);
        _setState(LiveState.speaking);

      case LiveInterrupted():
        // 割り込み。**最優先で音を止める**
        _noteInterruption();
        _player.stopNow();
        _flushAiTurn();
        _setState(LiveState.listening);

      case LiveInterimStudent(:final text):
        interimStudentText = tidyJa(text);
        notifyListeners();

      case LiveStudentText(:final text):
        _studentBuf.write(text);

      case LiveAiText(:final text):
        _aiBuf.write(text);

      case LiveTurnComplete():
        final hadStudentTurn = _flushTurns();
        unawaited(_persist());
        _pumpDirector();
        // 生徒が喋ったターンの後だけ呼ぶ。AI の独り言では状況が変わらない
        if (hadStudentTurn) _kickDirector();

      case LiveResumptionHandle():
        // 受け取るだけ。セッションは Vertex 側が約10分で切り、
        // そのたびに新しい枠を確保する設計なので、ここでは使わない
        break;

      case LiveGoingAway():
        _note('Live から goAway');

      case LiveClosed(:final code, :final reason):
        _note('Live 切断: code=$code reason=$reason');
        if (!_closing) unawaited(_onSessionEnded());

      case LiveFailed(:final detail):
        _note('Live エラー: $detail');
        if (!_closing) _fail(_classify(detail));
    }
  }

  /// 会話が終わった・落ちたときの記録。**release でも残す。**
  ///
  /// `debugPrint` は release build で消える。実機で会話が18秒で切れたとき、
  /// 理由を書いた行が1つも残っておらず、原因の特定に丸ごと1周かかった。
  /// `developer.log` なら release でも logcat に出る。
  void _note(String message) {
    notes.add(message);
    if (notes.length > 50) notes.removeAt(0);
    developer.log(message, name: 'dekisugi.live');
  }

  /// セッションが終わった（Vertex が約10分で切る）。
  ///
  /// **勝手に次の枠を使わない。** 1回＝1セッションで数えているので、
  /// 続けるかどうかは生徒に決めてもらう。
  Future<void> _onSessionEnded() async {
    await stop(to: LiveState.done);
  }

  void _noteInterruption() {
    if (interimStudentText.isNotEmpty || _studentBuf.isNotEmpty) {
      _selfInterruptions = 0;
      return;
    }
    _selfInterruptions++;
    if (_selfInterruptions == 3) {
      _note('自己割り込みの疑い（エコーキャンセルが効いていない可能性）');
      notifyListeners();
    }
  }

  void _flushAiTurn() {
    // 和文の切れ目に入る空白を落としてから記録する。
    // ここで直しておくとディレクターに渡す逐語も揃う
    final t = tidyJa(_aiBuf.toString());
    _aiBuf.clear();
    if (t.isEmpty) return;
    transcript.add(Utterance(id: _nextId(), isStudent: false, text: t));
  }

  bool _flushTurns() {
    final s = tidyJa(_studentBuf.toString());
    _studentBuf.clear();
    final hadStudent = s.isNotEmpty;
    if (hadStudent) {
      transcript.add(Utterance(id: _nextId(), isStudent: true, text: s));
    }
    interimStudentText = '';
    _flushAiTurn();
    notifyListeners();
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
    final s = _session;
    if (s == null || s.isClosed) return;
    if (!_gate.isSpeaking) return;
    s.sendAudio(chunk);
  }

  void _onLevel(double peak) {
    _peaks.add(peak);
    if (_peaks.length > 300) _peaks.removeAt(0);

    if (!_gate.update(peak, _clock.elapsed)) return;

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

  void injectDirector(String instruction) {
    final dropped = _queue.add(instruction);
    if (dropped != null) debugPrint('ディレクターの指示を捨てた（溜まりすぎ）: $dropped');
    _pumpDirector();
  }

  void _pumpDirector() {
    final s = _session;
    if (s == null || s.isClosed) return;
    // 「静か」= AI が喋っておらず、生徒も喋っていない
    final quiet = _state == LiveState.listening && !_gate.isSpeaking;
    final text = _queue.takeIfQuiet(quiet);
    if (text == null) return;
    // **`realtimeInput.text` を使わないこと。** 音声が返らない
    s.sendText(text);
  }

  /// カルテを更新して次の一手をもらう。**await しない**（実測6秒）。
  void _kickDirector() {
    final client = _director;
    if (client == null || !client.isConfigured || _directorBusy) return;
    _directorBusy = true;

    unawaited(client
        .run(
      unitId: unitId,
      dossier: dossier,
      utterances: List.of(transcript),
      secondsLeft: secondsLeft,
      turnCount: turnCount,
    )
        .then((result) {
      _directorBusy = false;
      if (result == null || _closing) return;
      _applyDirector(result);
    }).catchError((Object e) {
      _directorBusy = false;
      debugPrint('ディレクターで例外: $e');
    }));
  }

  void _applyDirector(DirectorResult result) {
    if (result.corrections.isNotEmpty) {
      for (var i = 0; i < transcript.length; i++) {
        final fixed = result.corrections[transcript[i].id];
        if (fixed != null) transcript[i] = transcript[i].withCorrection(fixed);
      }
    }

    dossier = result.dossier;
    lastLureId = result.lureId;
    notifyListeners();
    unawaited(_persist());

    if (result.shouldEnd) {
      _note('ディレクターが終了を指示: ${result.endReason}');
      unawaited(stop(to: LiveState.done));
      return;
    }
    if (result.nextInstruction.isNotEmpty) injectDirector(result.nextInstruction);
  }

  // ── 記録 ──────────────────────────────────────────────────

  /// いまの状態を端末へ書く。**1ターンごとに呼ぶ。**
  /// Android は裏に回ったアプリを予告なく落とすので、終了時にまとめて書かない。
  Future<void> _persist() async {
    final id = _sessionId;
    if (id == null || _store == null) return;
    try {
      await _store.saveProgress(id, transcript: transcript, dossier: dossier);
    } catch (e) {
      debugPrint('記録に失敗: $e');
    }
  }

  Future<void> _finishRecord() async {
    final id = _sessionId;
    final store = _store;
    if (id == null || store == null) return;
    try {
      await store.finishSession(id);
      final d = dossier;
      if (d != null) await store.upsertReviews(reviewItemsOf(d, DateTime.now()));
    } catch (e) {
      debugPrint('会話の締めに失敗: $e');
    }
    _sessionId = null;
  }

  // ── 状態 ──────────────────────────────────────────────────

  void _syncState() {
    if (_state == LiveState.speaking && !_player.hasPending) {
      _setState(LiveState.listening);
      _pumpDirector();
    }
  }

  void _setState(LiveState s) {
    if (_state == s) return;
    _state = s;
    notifyListeners();
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
