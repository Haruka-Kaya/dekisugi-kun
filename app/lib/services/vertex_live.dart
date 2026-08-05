import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'live_token_client.dart';

/// Vertex AI の Live API に直接つなぐ最小のクライアント。
///
/// ## なぜ `gemini_live` パッケージを使わないか
///
/// あれは Gemini Developer API 専用で、URL を自分で組み立て
/// `?key=` でキーを載せる。Vertex は**別ホスト・別パス・Bearer ヘッダ**なので、
/// 差し替える余地が無い。протокол は JSON over WebSocket で単純なので自分で書く。
///
/// ## 発話の区切りは端末が決める
///
/// **Vertex では自動VADが働かない。** 音声を送ってもエラーも出ずに黙って
/// 捨てられる（実測: 聞き取り0・返答0バイト）。
/// `activityStart` / `activityEnd` で囲むと通る。
///
/// → 「いつ喋りはじめて、いつ終わったか」を端末が判断して伝える。
///   間違えると会話そのものが成立しない。
class VertexLiveSession {
  VertexLiveSession._(this._socket, this.grant);

  final WebSocket _socket;
  final LiveGrant grant;

  final _events = StreamController<LiveEvent>.broadcast();

  /// 受信したもの。画面と記録はこれだけを見る。
  Stream<LiveEvent> get events => _events.stream;

  bool _closed = false;
  bool get isClosed => _closed;

  /// いま「喋っている」と伝えてあるか。二重に送らないための状態
  bool _activityOpen = false;

  static Future<VertexLiveSession> connect(LiveGrant grant) async {
    final socket = await WebSocket.connect(
      grant.wsUrl,
      headers: {'Authorization': 'Bearer ${grant.token}'},
    );
    final session = VertexLiveSession._(socket, grant);
    session._listen();
    // setup は接続直後に1回だけ。**サーバが返した設定をそのまま送る**
    session._send({
      'setup': {'model': grant.model, ...grant.setupConfig},
    });
    return session;
  }

  void _listen() {
    _socket.listen(
      (raw) {
        try {
          _handle(jsonDecode(raw is String ? raw : utf8.decode(raw as List<int>))
              as Map<String, dynamic>);
        } catch (e) {
          debugPrint('Live のメッセージを読めなかった: $e');
        }
      },
      onError: (Object e) {
        _emit(LiveEvent.failed('$e'));
        _finish();
      },
      onDone: () {
        // 1000 は正常終了。**Vertex は約10分でここに来る**（セッション上限）
        _emit(LiveEvent.closed(_socket.closeCode, _socket.closeReason));
        _finish();
      },
      cancelOnError: false,
    );
  }

  /// 閉じたあとに届いたものは捨てる。
  ///
  /// `cancelOnError: false` なので、エラーのあとに `onDone` も来る。
  /// エラー側で閉じたストリームへ `onDone` が書き込むと
  /// `Bad state: Cannot add new events after calling close` で
  /// **未処理例外**になり、本当の失敗理由がその陰に隠れる（実機で発生）。
  /// 自分で `close()` したときも、ソケットの `onDone` は後から届く。
  void _emit(LiveEvent e) {
    if (_events.isClosed) return;
    _events.add(e);
  }

  void _handle(Map<String, dynamic> m) {
    if (m['setupComplete'] != null) {
      _emit(const LiveEvent.ready());
      return;
    }
    if (m['error'] != null) {
      _emit(LiveEvent.failed(jsonEncode(m['error'])));
      return;
    }

    final handle = (m['sessionResumptionUpdate'] as Map?)?['newHandle'] as String?;
    if (handle != null && handle.isNotEmpty) {
      _emit(LiveEvent.resumptionHandle(handle));
    }
    if (m['goAway'] != null) _emit(const LiveEvent.goingAway());

    final sc = m['serverContent'] as Map?;
    if (sc == null) return;

    // 割り込み。**最優先で伝える**
    if (sc['interrupted'] == true) {
      _emit(const LiveEvent.interrupted());
      return;
    }

    final parts = (sc['modelTurn'] as Map?)?['parts'] as List?;
    if (parts != null) {
      for (final p in parts.whereType<Map>()) {
        final b64 = (p['inlineData'] as Map?)?['data'] as String?;
        if (b64 == null || b64.isEmpty) continue;
        _emit(LiveEvent.audio(base64Decode(b64)));
      }
    }

    final interim = (sc['interimInputTranscription'] as Map?)?['text'] as String?;
    if (interim != null && interim.isNotEmpty) {
      _emit(LiveEvent.interimStudent(interim));
    }
    final input = (sc['inputTranscription'] as Map?)?['text'] as String?;
    if (input != null && input.isNotEmpty) _emit(LiveEvent.studentText(input));
    final output = (sc['outputTranscription'] as Map?)?['text'] as String?;
    if (output != null && output.isNotEmpty) _emit(LiveEvent.aiText(output));

    if (sc['turnComplete'] == true) _emit(const LiveEvent.turnComplete());
  }

  // ── 送信 ──────────────────────────────────────────────────

  /// 生徒が喋りはじめた。**音声を送る前に必ず呼ぶ。**
  void beginSpeech() {
    if (_closed || _activityOpen) return;
    _activityOpen = true;
    _send({
      'realtimeInput': {'activityStart': <String, dynamic>{}},
    });
  }

  /// 生徒が喋り終わった。**呼ばないとモデルは応答しない。**
  void endSpeech() {
    if (_closed || !_activityOpen) return;
    _activityOpen = false;
    _send({
      'realtimeInput': {'activityEnd': <String, dynamic>{}},
    });
  }

  /// 音声の断片。[beginSpeech] と [endSpeech] の間だけ意味がある。
  void sendAudio(Uint8List pcm16) {
    if (_closed || !_activityOpen) return;
    _send({
      'realtimeInput': {
        'audio': {
          'mimeType': 'audio/pcm;rate=$inputSampleRate',
          'data': base64Encode(pcm16),
        },
      },
    });
  }

  /// ディレクターの指示など、テキストで1ターン送る。
  ///
  /// **`realtimeInput.text` を使わないこと。** Developer API では
  /// 文字起こしだけ返って音声が返らなかった。`clientContent` なら返る。
  void sendText(String text) {
    if (_closed) return;
    _send({
      'clientContent': {
        'turns': [
          {
            'role': 'user',
            'parts': [
              {'text': text},
            ],
          },
        ],
        'turnComplete': true,
      },
    });
  }

  void _send(Map<String, dynamic> message) {
    if (_closed) return;
    try {
      _socket.add(jsonEncode(message));
    } catch (e) {
      debugPrint('Live へ送れなかった: $e');
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _socket.close(WebSocketStatus.normalClosure);
    await _events.close();
  }

  void _finish() {
    if (_closed) return;
    _closed = true;
    unawaited(_events.close());
  }

  /// 入力のサンプリングレート。出力の 24kHz と取り違えないこと。
  static const int inputSampleRate = 16000;
}

/// Live から届くもの。
sealed class LiveEvent {
  const LiveEvent();

  const factory LiveEvent.ready() = LiveReady;
  const factory LiveEvent.turnComplete() = LiveTurnComplete;
  const factory LiveEvent.interrupted() = LiveInterrupted;
  const factory LiveEvent.goingAway() = LiveGoingAway;
  const factory LiveEvent.audio(Uint8List pcm) = LiveAudio;
  const factory LiveEvent.studentText(String text) = LiveStudentText;
  const factory LiveEvent.interimStudent(String text) = LiveInterimStudent;
  const factory LiveEvent.aiText(String text) = LiveAiText;
  const factory LiveEvent.resumptionHandle(String handle) = LiveResumptionHandle;
  const factory LiveEvent.failed(String detail) = LiveFailed;
  const factory LiveEvent.closed(int? code, String? reason) = LiveClosed;
}

class LiveReady extends LiveEvent {
  const LiveReady();
}

class LiveTurnComplete extends LiveEvent {
  const LiveTurnComplete();
}

class LiveInterrupted extends LiveEvent {
  const LiveInterrupted();
}

class LiveGoingAway extends LiveEvent {
  const LiveGoingAway();
}

class LiveAudio extends LiveEvent {
  const LiveAudio(this.pcm);
  final Uint8List pcm;
}

class LiveStudentText extends LiveEvent {
  const LiveStudentText(this.text);
  final String text;
}

class LiveInterimStudent extends LiveEvent {
  const LiveInterimStudent(this.text);
  final String text;
}

class LiveAiText extends LiveEvent {
  const LiveAiText(this.text);
  final String text;
}

class LiveResumptionHandle extends LiveEvent {
  const LiveResumptionHandle(this.handle);
  final String handle;
}

class LiveFailed extends LiveEvent {
  const LiveFailed(this.detail);
  final String detail;
}

class LiveClosed extends LiveEvent {
  const LiveClosed(this.code, this.reason);
  final int? code;
  final String? reason;

  /// Vertex がセッション上限で切ったか（実測 約10分で code=1000）
  bool get isSessionLimit => code == 1000;
}
