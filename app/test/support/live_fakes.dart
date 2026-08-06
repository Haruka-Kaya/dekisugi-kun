import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dekisugi/services/device_identity.dart';
import 'package:dekisugi/services/live_token_client.dart';
import 'package:dekisugi/services/mic_stream.dart';
import 'package:dekisugi/services/pcm_player.dart';
import 'package:dekisugi/services/session_store.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

/// `LiveSessionController` を実機なしで動かすための差し替え一式。
///
/// **実機でしか出ない不具合を実機なしで捕まえる**ためにある。
/// 半二重・再接続・文字入力は、どれも本物のマイクとスピーカーを
/// 相手にすると再現の条件が揃わない。

/// マイクの代わり。音量とチャンクを外から流し込む。
class FakeMic extends MicStream {
  final _chunks = StreamController<Uint8List>.broadcast();
  final _levels = StreamController<double>.broadcast();
  bool started = false;

  @override
  Stream<Uint8List> get chunks => _chunks.stream;
  @override
  Stream<double> get level => _levels.stream;
  @override
  bool get isRecording => started;

  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<bool> start({bool speakerphone = true}) async => started = true;
  @override
  Future<void> stop() async => started = false;
  @override
  Future<void> dispose() async {
    await _chunks.close();
    await _levels.close();
  }

  /// 音量を1つ流す。**先に音量、次にチャンク**の順で届く実機と同じにする。
  void hear(double peak, Uint8List chunk) {
    _levels.add(peak);
    _chunks.add(chunk);
  }
}

/// スピーカーの代わり。**補充を要求しない**ので、積んだ音は減らない
/// ＝「AI が喋り続けている」状態を作れる。
class FakeSink implements PcmSink {
  bool started = false;
  final fed = <int>[];

  @override
  Future<void> setLogLevel(LogLevel level) async {}
  @override
  Future<void> setup({required int sampleRate, required int channelCount}) async {}
  @override
  Future<void> setFeedThreshold(int frames) async {}
  @override
  void setFeedCallback(void Function(int remainingFrames)? cb) {}
  @override
  void feed(PcmArrayInt16 buffer) => fed.add(buffer.bytes.lengthInBytes);
  @override
  void start() => started = true;
  @override
  Future<void> release() async {}
}

/// 資格情報は偽サーバを指す。
/// `reserve` は wss:// しか受け付けないので、**本番の検査を緩めずに**差し替える。
class FakeTokens extends LiveTokenClient {
  FakeTokens(this.grant)
      : super(baseUrl: 'https://example.test', identity: NoIdentity());

  final LiveGrant grant;

  /// `reserve` が呼ばれた回数。**枠を余計に消費していないこと**の確認に使う。
  int reserveCalls = 0;

  /// 直近の `reserve` に渡された再開ハンドル。
  String? lastResumeHandle;

  /// サーバが再開を受け入れるか。false にすると
  /// 「再開に未対応のサーバ」を再現できる
  bool acceptResume = true;

  /// `reserve` を失敗させる。繋ぎ直しの失敗を再現する
  bool failReserve = false;

  @override
  Future<LiveGrant> reserve(String unitId, {String? resumeHandle}) async {
    reserveCalls++;
    lastResumeHandle = resumeHandle;
    if (failReserve) throw const LiveTokenUnavailable('テスト用の失敗');
    return _withResumed(grant, resumeHandle != null && acceptResume);
  }

  @override
  Future<QuotaStatus?> peek() async => null;
}

/// `resumed` だけ差し替えた控え。`LiveGrant` に copyWith が無いので手で作る
LiveGrant _withResumed(LiveGrant g, bool resumed) => LiveGrant(
      directorPrefix: g.directorPrefix,
      token: g.token,
      wsUrl: g.wsUrl,
      model: g.model,
      setupConfig: g.setupConfig,
      expiresAt: g.expiresAt,
      sessionMinutes: g.sessionMinutes,
      remainingSessions: g.remainingSessions,
      entitled: g.entitled,
      resetsAt: g.resetsAt,
      resumed: resumed,
    );

class NoIdentity extends DeviceIdentity {
  NoIdentity() : super(baseUrl: '', store: MemorySessionStore());
  @override
  Future<String?> token({bool force = false}) async => 'x';
}

Uint8List pcm(int bytes) => Uint8List(bytes);

/// 24kHz PCM16 を base64 で。サーバが音声を返したことにする
String audioB64(int bytes) => base64Encode(Uint8List(bytes));

/// AI が喋りはじめたことにするメッセージ。
Map<String, dynamic> modelAudio(int bytes) => {
      'serverContent': {
        'modelTurn': {
          'parts': [
            {
              'inlineData': {'mimeType': 'audio/pcm', 'data': audioB64(bytes)},
            },
          ],
        },
      },
    };
