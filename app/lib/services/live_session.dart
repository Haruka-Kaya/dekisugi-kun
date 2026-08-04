import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:gemini_live/gemini_live.dart';

import '../config/live_config.dart';
import 'director_queue.dart';
import 'mic_stream.dart';
import 'pcm_player.dart';
import 'speech_gate.dart';

/// 会話の見え方。**画面はこの4つだけを描き分ける。**
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

  /// 続けられない
  failed,
}

/// 会話が成立しなかった理由。画面に出す文言を1か所に閉じる。
enum LiveFailure { noPermission, network, auth, unknown }

/// Gemini Live との会話ぜんぶ。
///
/// - 音声は端末とモデルの間を直接流れる。**サーバは経由しない**
/// - 何を喋ったかの記録（逐語・理解カルテ）は端末が持つ。サーバは状態を持たない
/// - ディレクターの指示は [injectDirector] で外から積む（段階2でサーバから来る）
class LiveSessionController extends ChangeNotifier {
  LiveSessionController({
    required this.apiKey,
    MicStream? mic,
    PcmPlayer? player,
    SpeechGate? gate,
    DirectorQueue? director,
  })  : _mic = mic ?? MicStream(),
        _player = player ?? PcmPlayer(),
        _gate = gate ?? SpeechGate(),
        _director = director ?? DirectorQueue();

  /// 段階5 でサーバ発行の ephemeral token に差し替える。
  /// **本番の APK に生キーを焼かないこと。**
  final String apiKey;

  final MicStream _mic;
  final PcmPlayer _player;
  final SpeechGate _gate;
  final DirectorQueue _director;

  LiveSession? _session;
  StreamSubscription<Uint8List>? _micSub;
  StreamSubscription<double>? _levelSub;
  Timer? _drainTimer;
  final Stopwatch _clock = Stopwatch();

  LiveState _state = LiveState.idle;
  LiveFailure? _failure;
  String? _resumptionHandle;
  bool _closing = false;

  /// 生徒が言ったこと（確定ぶん）。
  final List<String> studentTurns = [];

  /// AI が言ったこと（確定ぶん）。誤概念を口にしたかの観測はここを見る。
  final List<String> aiTurns = [];

  final StringBuffer _aiBuf = StringBuffer();
  final StringBuffer _studentBuf = StringBuffer();

  /// いま喋っている途中の文字起こし。確定前なので記録には使わない。
  String interimStudentText = '';

  /// 録音の異常判定に使うピーク列。
  final List<double> _peaks = [];

  LiveState get state => _state;
  LiveFailure? get failure => _failure;
  bool get isRunning => _session != null && !_session!.isClosed;

  /// 直近の録音が変なら理由を返す。「聞こえていない」を黙って進めないため。
  RecordingIssue? get recordingIssue => diagnose(_peaks);

  /// 入力音量。**音より先に目で「聞こえている」を返す**ために画面へ流す。
  /// 毎フレーム notifyListeners すると画面全体が組み直されるので、
  /// ここだけは Stream で受け渡して再構築の範囲を音量バーに閉じる。
  Stream<double> get micLevel => _mic.level;

  /// 割り込みで鳴り残る最大時間。画面の説明に使う。
  Duration get maxResidualAudio => PcmPlayer.maxResidual;

  // ── 開始と終了 ─────────────────────────────────────────────

  Future<void> start() async {
    if (_state != LiveState.idle && _state != LiveState.failed) return;
    _setState(LiveState.connecting);
    _failure = null;

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
    } catch (e, s) {
      debugPrint('Live 接続に失敗: $e\n$s');
      _fail(_classify(e));
    }
  }

  Future<void> stop() async {
    _closing = true;
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
    _setState(LiveState.idle);
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
    final dropped = _director.add(instruction);
    if (dropped != null) {
      debugPrint('ディレクターの指示を捨てた（溜まりすぎ）: $dropped');
    }
    _pumpDirector();
  }

  void _pumpDirector() {
    if (_session == null || _session!.isClosed) return;
    // 「静か」= AI が喋っておらず、生徒も喋っていない
    final quiet = _state == LiveState.listening && !_gate.isSpeaking;
    final text = _director.takeIfQuiet(quiet);
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
          if (!_closing && _state != LiveState.failed) unawaited(_reconnect());
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
      _flushTurns();
      _pumpDirector();
    }
  }

  void _flushAiTurn() {
    final t = _aiBuf.toString().trim();
    _aiBuf.clear();
    if (t.isNotEmpty) aiTurns.add(t);
  }

  void _flushTurns() {
    final s = _studentBuf.toString().trim();
    _studentBuf.clear();
    if (s.isNotEmpty) studentTurns.add(s);
    interimStudentText = '';
    _flushAiTurn();
    notifyListeners();
  }

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
