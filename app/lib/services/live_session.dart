import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:gemini_live/gemini_live.dart';

import '../config/live_config.dart';
import '../models/dossier.dart';
import '../models/review.dart';
import 'director_client.dart';
import 'director_queue.dart';
import 'mic_stream.dart';
import 'pcm_player.dart';
import 'session_store.dart';
import 'speech_gate.dart';

/// 会話の見え方。**画面はこの6つだけを描き分ける。**
enum LiveState {
  /// まだ始まっていない
  idle,

  /// 繋いでいる最中
  connecting,

  /// 生徒の話を聞いている
  listening,

  /// 生徒が喋り終わり、AI の声を待っている
  thinking,

  /// AI が喋っている
  speaking,

  /// 一通り終わった
  done,

  /// 続けられない
  failed,
}

/// 会話が成立しなかった理由。画面に出す文言を1か所に閉じる。
enum LiveFailure { noPermission, network, auth, unknown }

/// Gemini Live との会話ぜんぶ。
///
/// - 音声は端末とモデルの間を直接流れる。**サーバは経由しない**
/// - 逐語と理解カルテは**端末が持つ**。サーバは状態を持たない
/// - ディレクターは1ターンごとに呼ぶが、**await しない**（実測6秒かかる）
class LiveSessionController extends ChangeNotifier {
  LiveSessionController({
    required this.apiKey,
    required this.unitId,
    DirectorClient? director,
    SessionStore? store,
    MicStream? mic,
    PcmPlayer? player,
    SpeechGate? gate,
    DirectorQueue? queue,
    this.sessionBudget = const Duration(minutes: 10),
  })  : _director = director,
        _store = store,
        _mic = mic ?? MicStream(),
        _player = player ?? PcmPlayer(),
        _gate = gate ?? SpeechGate(),
        _queue = queue ?? DirectorQueue();

  /// 段階5 でサーバ発行の ephemeral token に差し替える。
  /// **本番の APK に生キーを焼かないこと。**
  final String apiKey;

  /// どの単元を教えてもらうか。
  final String unitId;

  /// 1回の会話の持ち時間。ディレクターの終了判断に渡す。
  final Duration sessionBudget;

  final DirectorClient? _director;
  final SessionStore? _store;
  final MicStream _mic;
  final PcmPlayer _player;
  final SpeechGate _gate;
  final DirectorQueue _queue;

  LiveSession? _session;
  StreamSubscription<Uint8List>? _micSub;
  StreamSubscription<double>? _levelSub;
  Timer? _drainTimer;
  final Stopwatch _clock = Stopwatch();

  LiveState _state = LiveState.idle;
  LiveFailure? _failure;
  String? _resumptionHandle;
  bool _closing = false;

  /// ディレクターは1つずつ。重ねて呼ぶと古い結果が新しいカルテを上書きする
  bool _directorBusy = false;

  /// 会話の逐語。**時系列で1本。** 記録も画面もこれを見る。
  final List<Utterance> transcript = [];
  int _seq = 0;

  /// いま分かっている理解カルテ。ディレクターが返すたびに置き換わる。
  Dossier? dossier;

  /// 直近で誘発を指示した誤概念。AI が実際に口にしたかの突き合わせに使う。
  String? lastLureId;

  /// 端末に残している会話の行。null なら記録していない
  int? _sessionId;

  /// 前回の続きから始めたか。画面の文言を変えるために持つ
  bool resumed = false;

  final StringBuffer _aiBuf = StringBuffer();
  final StringBuffer _studentBuf = StringBuffer();

  /// いま喋っている途中の文字起こし。確定前なので記録には使わない。
  String interimStudentText = '';

  /// 録音の異常判定に使うピーク列。
  final List<double> _peaks = [];

  LiveState get state => _state;
  LiveFailure? get failure => _failure;
  bool get isRunning => _session != null && !_session!.isClosed;

  /// 何往復目か。ディレクターの終了判断に渡す。
  int get turnCount => transcript.where((u) => u.isStudent).length;

  Duration get elapsed => _clock.elapsed;
  double get secondsLeft =>
      (sessionBudget - _clock.elapsed).inMilliseconds / 1000.0;

  /// 直近の録音が変なら理由を返す。「聞こえていない」を黙って進めないため。
  RecordingIssue? get recordingIssue => diagnose(_peaks);

  /// 入力音量。**音より先に目で「聞こえている」を返す**ために画面へ流す。
  /// 毎フレーム notifyListeners すると画面全体が組み直されるので、
  /// ここだけは Stream で受け渡して再構築の範囲を音量バーに閉じる。
  Stream<double> get micLevel => _mic.level;

  /// AI の声の大きさ。キャラクターの動きを駆動する。
  /// **口の動きには使わない**（音素タイミングが無いので作れない）。
  Stream<double> get voiceLevel => _player.level;

  /// 割り込みで鳴り残る最大時間。画面の説明に使う。
  Duration get maxResidualAudio => PcmPlayer.maxResidual;

  // ── 開始と終了 ─────────────────────────────────────────────

  /// 中断していた会話を読み込む。**[start] の前に呼ぶ。**
  ///
  /// Live の接続そのものは復元できない（アプリが落ちた時点で切れている）。
  /// 復元するのは**逐語と理解カルテ**で、ディレクターがそれを読んで
  /// 続きから指示を出す。サーバが状態を持たない設計だからこれで足りる。
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

  Future<void> start() async {
    if (_state != LiveState.idle &&
        _state != LiveState.failed &&
        _state != LiveState.done) {
      return;
    }
    _setState(LiveState.connecting);
    _failure = null;

    // 記録の行を先に作る。**会話が始まる前に確保しておく** —
    // 途中で落ちても、そこまでの発話が行き場を失わないように
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
      _micSub = _mic.chunks.listen(_sendAudio);
      _levelSub = _mic.level.listen(_onLevel);
      // 再生が終わったかは native から通知されないので、こちらで見る
      _drainTimer =
          Timer.periodic(const Duration(milliseconds: 120), (_) => _syncState());
      _setState(LiveState.listening);

      // 口火はディレクターに切らせる。AI から「教えて」と頼ませないと
      // 生徒は何を話せばいいか分からない（C1）
      _kickDirector();
    } catch (e, s) {
      debugPrint('Live 接続に失敗: $e\n$s');
      _fail(_classify(e));
    }
  }

  Future<void> stop({LiveState to = LiveState.idle}) async {
    _closing = true;
    // 止める前に書き出す。**このあと OS に殺されても失われないように**
    await _persist();
    if (to == LiveState.done) await _finishRecord();
    _drainTimer?.cancel();
    _drainTimer = null;
    await _micSub?.cancel();
    await _levelSub?.cancel();
    _micSub = null;
    _levelSub = null;
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

  // ── ディレクター ───────────────────────────────────────────

  /// 進行の指示を積む。AI が黙るまで送らない。
  void injectDirector(String instruction) {
    final dropped = _queue.add(instruction);
    if (dropped != null) {
      debugPrint('ディレクターの指示を捨てた（溜まりすぎ）: $dropped');
    }
    _pumpDirector();
  }

  void _pumpDirector() {
    if (_session == null || _session!.isClosed) return;
    // 「静か」= AI が喋っておらず、生徒も喋っていない
    final quiet = _state == LiveState.listening && !_gate.isSpeaking;
    final text = _queue.takeIfQuiet(quiet);
    if (text == null) return;

    // **sendRealtimeText を使わないこと。**
    // `realtimeInput.text` で送ると、モデルは応答を生成して
    // outputTranscription まで返すのに **音声を1バイトも返さない**
    // （実測: 同じモデル・同じ設定で clientContent なら 371KB 返る）。
    // 文字起こしだけ見ていると気づけず、声の出ないアプリになる。
    _session!.sendClientContent(
      turns: [Content(role: 'user', parts: [Part(text: text)])],
      turnComplete: true,
    );
  }

  /// カルテを更新して次の一手をもらう。**await しない。**
  ///
  /// 1回あたり実測6秒。待つと会話が止まる。
  /// 返ってきた時点で注入し、AI が黙っていればそのまま流れる。
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

  /// いまの状態を端末へ書く。**1ターンごとに呼ぶ。**
  ///
  /// Android は裏に回ったアプリを予告なく落とす。`dispose` もライフサイクルの
  /// コールバックも呼ばれる保証がないので、終了時にまとめて書いてはいけない。
  Future<void> _persist() async {
    final id = _sessionId;
    if (id == null || _store == null) return;
    try {
      await _store.saveProgress(id, transcript: transcript, dossier: dossier);
    } catch (e) {
      // 記録に失敗しても会話は止めない
      debugPrint('記録に失敗: $e');
    }
  }

  /// 会話を閉じ、復習に回すものを残す。
  Future<void> _finishRecord() async {
    final id = _sessionId;
    final store = _store;
    if (id == null || store == null) return;
    try {
      await store.finishSession(id);
      final d = dossier;
      if (d != null) {
        await store.upsertReviews(reviewItemsOf(d, DateTime.now()));
      }
    } catch (e) {
      debugPrint('会話の締めに失敗: $e');
    }
    _sessionId = null;
  }

  void _applyDirector(DirectorResult result) {
    // 文字起こしの校正を逐語へ反映する。記録は校正後を使う
    if (result.corrections.isNotEmpty) {
      for (var i = 0; i < transcript.length; i++) {
        final fixed = result.corrections[transcript[i].id];
        if (fixed != null) transcript[i] = transcript[i].withCorrection(fixed);
      }
    }

    dossier = result.dossier;
    lastLureId = result.lureId;
    notifyListeners();
    // カルテが更新された時点で書く。校正結果もここで残る
    unawaited(_persist());

    if (result.shouldEnd) {
      debugPrint('ディレクターが終了を指示: ${result.endReason}');
      unawaited(stop(to: LiveState.done));
      return;
    }
    if (result.nextInstruction.isNotEmpty) {
      injectDirector(result.nextInstruction);
    }
  }

  // ── 接続 ──────────────────────────────────────────────────

  Future<void> _connect() async {
    final genAI = GoogleGenAI(apiKey: apiKey);
    _session = await genAI.live.connect(LiveConfig.connectParameters(
      resumptionHandle: _resumptionHandle,
      callbacks: LiveCallbacks(
        onMessage: _onMessage,
        onError: (e, s) {
          debugPrint('Live エラー: $e\n$s');
          if (!_closing) _fail(_classify(e));
        },
        onClose: (code, reason) {
          debugPrint('Live 切断: $code $reason');
          // 意図した停止でなければ、ハンドルを使って張り直す
          if (!_closing && _state != LiveState.failed && _state != LiveState.done) {
            unawaited(_reconnect());
          }
        },
      ),
    ));
  }

  /// 約15分で切られる。ハンドルを持って繋ぎ直せば会話は続く。
  Future<void> _reconnect() async {
    if (_closing) return;
    _setState(LiveState.connecting);
    _player.stopNow();
    try {
      await _connect();
      _setState(LiveState.listening);
      _pumpDirector();
    } catch (e) {
      debugPrint('再接続に失敗: $e');
      _fail(_classify(e));
    }
  }

  // ── 受信 ──────────────────────────────────────────────────

  void _onMessage(LiveServerMessage m) {
    final sc = m.serverContent;

    // 割り込み。**最優先で音を止める。** 遅れるほど「話を聞かない AI」に見える
    if (sc?.interrupted ?? false) {
      _player.stopNow();
      _flushAiTurn();
      _setState(LiveState.listening);
      return;
    }

    // 再接続用のハンドル。届くたびに最新へ差し替える
    final handle = m.sessionResumptionUpdate?.newHandle;
    if (handle != null && handle.isNotEmpty) _resumptionHandle = handle;

    // 上限が近いことの予告。切られる前にこちらから張り直す
    if (m.goAway != null) unawaited(_reconnect());

    // 音声。parts を自前で回す（message.data は decode→encode し直すので無駄）
    final parts = sc?.modelTurn?.parts;
    if (parts != null) {
      for (final p in parts) {
        final b64 = p.inlineData?.data;
        if (b64 == null || b64.isEmpty) continue;
        _player.enqueue(base64Decode(b64));
        _setState(LiveState.speaking);
      }
    }

    // 文字起こし
    final interim = sc?.interimInputTranscription?.text;
    if (interim != null && interim.isNotEmpty) {
      interimStudentText = interim;
      notifyListeners();
    }
    final userText = sc?.inputTranscription?.text;
    if (userText != null && userText.isNotEmpty) _studentBuf.write(userText);
    final aiText = sc?.outputTranscription?.text;
    if (aiText != null && aiText.isNotEmpty) _aiBuf.write(aiText);

    if (sc?.turnComplete ?? false) {
      final hadStudentTurn = _flushTurns();
      // ターンが終わるたびに書く。ディレクターの応答（6秒）を待たない
      unawaited(_persist());
      _pumpDirector();
      // 生徒が喋ったターンの後だけ呼ぶ。AI の独り言では状況が変わらない
      if (hadStudentTurn) _kickDirector();
    }
  }

  void _flushAiTurn() {
    final t = _aiBuf.toString().trim();
    _aiBuf.clear();
    if (t.isEmpty) return;
    transcript.add(Utterance(id: _nextId(), isStudent: false, text: t));
  }

  /// 溜まっている発話を逐語へ移す。生徒の発話があったら true。
  bool _flushTurns() {
    final s = _studentBuf.toString().trim();
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

  void _sendAudio(Uint8List chunk) {
    final s = _session;
    if (s == null || s.isClosed) return;
    // sendAudio() は mime type にレートを含めないので使わない
    s.sendRealtimeInput(
      audio: Blob(mimeType: LiveConfig.inputMimeType, data: base64Encode(chunk)),
    );
  }

  void _onLevel(double peak) {
    _peaks.add(peak);
    // 判定に使うのは直近だけ。全部持つと古い異常が残り続ける
    if (_peaks.length > 300) _peaks.removeAt(0);

    if (_gate.update(peak, _clock.elapsed)) {
      if (!_gate.isSpeaking && _state == LiveState.listening) {
        // 生徒が言い終わった。**サーバの応答を待たずに**先へ進める
        _setState(LiveState.thinking);
      }
      _pumpDirector();
    }
  }

  // ── 状態 ──────────────────────────────────────────────────

  /// 再生が終わったかを見て speaking から戻す。
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
    if (s.contains('api key') || s.contains('401') || s.contains('403')) {
      return LiveFailure.auth;
    }
    if (s.contains('socket') ||
        s.contains('timeout') ||
        s.contains('network') ||
        s.contains('connection')) {
      return LiveFailure.network;
    }
    return LiveFailure.unknown;
  }
}
