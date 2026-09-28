import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 人が収録した同梱音声のasset契約。
///
/// 実ファイルが無い教材にこれを指定してはいけない。[path]は
/// `pubspec.yaml` に同梱した音声だけを指し、[transcript]は再生する
/// 固定教材と逐語一致させる。録音が無い現行catalogはnullのままとし、
/// 端末TTSを「人の録音」と偽装しない。
@immutable
final class BundledHumanNarrationAsset {
  BundledHumanNarrationAsset({
    required this.path,
    required this.transcript,
    required this.narratorLabel,
  }) {
    if (!RegExp(
      r'^assets/audio/listening/[A-Za-z0-9_-]+\.(?:m4a|wav)$',
    ).hasMatch(path)) {
      throw ArgumentError.value(
        path,
        'path',
        'bundled .m4a/.wav under assets/audio/listening required',
      );
    }
    if (transcript.trim().isEmpty || transcript != transcript.trim()) {
      throw ArgumentError.value(
        transcript,
        'transcript',
        'non-empty trimmed fixed transcript required',
      );
    }
    if (narratorLabel.trim().isEmpty || narratorLabel != narratorLabel.trim()) {
      throw ArgumentError.value(
        narratorLabel,
        'narratorLabel',
        'non-empty trimmed narrator label required',
      );
    }
  }

  final String path;
  final String transcript;
  final String narratorLabel;
}

enum LocalNarrationDelivery {
  bundledHumanRecording,
  deviceSpeechSynthesis,
  unavailable,
}

@immutable
final class LocalNarrationRequest {
  const LocalNarrationRequest({
    required this.text,
    this.language = 'ja-JP',
    this.bundledHumanRecording,
  });

  final String text;
  final String language;
  final BundledHumanNarrationAsset? bundledHumanRecording;
}

@immutable
final class LocalNarrationResult {
  const LocalNarrationResult({required this.completed, required this.delivery});

  const LocalNarrationResult.unavailable()
    : completed = false,
      delivery = LocalNarrationDelivery.unavailable;

  final bool completed;
  final LocalNarrationDelivery delivery;
}

/// 固定教材の録音を優先し、無ければ端末音声合成で読み上げる境界。
///
/// 文字列とasset pathはiOS/Androidの端末内channelへだけ渡し、
/// アプリのサーバーへは送らない。[play] は再生の出所を隠さない。
abstract interface class LocalNarration {
  Future<LocalNarrationResult> play(LocalNarrationRequest request);

  Future<void> stop();

  Future<void> dispose();
}

/// Story等の「端末TTSで読む」だけの経路を後方互換に保つ。
extension LocalNarrationSpeechSynthesis on LocalNarration {
  Future<bool> speak(String text, {String language = 'ja-JP'}) async {
    final result = await play(
      LocalNarrationRequest(text: text, language: language),
    );
    return result.completed;
  }
}

final class PlatformLocalNarration implements LocalNarration {
  PlatformLocalNarration({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'jp.dekisugi.dekisugi/local_narration';
  static const _maxCharacters = 800;

  final MethodChannel _channel;
  bool _disposed = false;
  int _playGeneration = 0;

  @override
  Future<LocalNarrationResult> play(LocalNarrationRequest request) async {
    if (_disposed) return const LocalNarrationResult.unavailable();
    final generation = ++_playGeneration;
    final normalized = request.text.trim();
    if (normalized.isEmpty || normalized.length > _maxCharacters) {
      return const LocalNarrationResult.unavailable();
    }
    final recording = request.bundledHumanRecording;
    if (recording != null && recording.transcript.trim() == normalized) {
      try {
        final completed =
            await _channel.invokeMethod<bool>('playBundledHumanRecording', {
              'assetPath': recording.path,
            }) ??
            false;
        if (_disposed || generation != _playGeneration) {
          return const LocalNarrationResult.unavailable();
        }
        if (completed) {
          return const LocalNarrationResult(
            completed: true,
            delivery: LocalNarrationDelivery.bundledHumanRecording,
          );
        }
      } on MissingPluginException {
        // 録音再生に非対応の旧native層では、次の端末TTSへ進む。
      } on PlatformException {
        // 破損・未同梱のassetを人の声として完了扱いしない。
      }
    }
    if (_disposed || generation != _playGeneration) {
      return const LocalNarrationResult.unavailable();
    }
    try {
      final completed =
          await _channel.invokeMethod<bool>('speak', {
            'text': normalized,
            'language': request.language,
          }) ??
          false;
      if (_disposed || generation != _playGeneration) {
        return const LocalNarrationResult.unavailable();
      }
      return LocalNarrationResult(
        completed: completed,
        delivery: completed
            ? LocalNarrationDelivery.deviceSpeechSynthesis
            : LocalNarrationDelivery.unavailable,
      );
    } on MissingPluginException {
      return const LocalNarrationResult.unavailable();
    } on PlatformException {
      return const LocalNarrationResult.unavailable();
    }
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    _playGeneration++;
    await _stopNative();
  }

  Future<void> _stopNative() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on MissingPluginException {
      // Windows/WebのUI確認ではTTSが無い。文字経路を壊さない。
    } on PlatformException {
      // 読み上げ停止の失敗を画面離脱の失敗へ昇格させない。
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _playGeneration++;
    await _stopNative();
  }
}

/// widget test用。正答や教材本文を実装へ注入せず、呼び出しだけ観測する。
@visibleForTesting
final class FakeLocalNarration implements LocalNarration {
  FakeLocalNarration({
    this.available = true,
    this.humanRecordingAvailable = false,
  });

  final bool available;
  final bool humanRecordingAvailable;
  final List<String> spoken = [];
  final List<LocalNarrationRequest> requests = [];
  int stopCount = 0;
  bool disposed = false;

  @override
  Future<LocalNarrationResult> play(LocalNarrationRequest request) async {
    if (disposed || !available) {
      return const LocalNarrationResult.unavailable();
    }
    requests.add(request);
    spoken.add(request.text);
    if (humanRecordingAvailable &&
        request.bundledHumanRecording?.transcript == request.text) {
      return const LocalNarrationResult(
        completed: true,
        delivery: LocalNarrationDelivery.bundledHumanRecording,
      );
    }
    return const LocalNarrationResult(
      completed: true,
      delivery: LocalNarrationDelivery.deviceSpeechSynthesis,
    );
  }

  @override
  Future<void> stop() async => stopCount++;

  @override
  Future<void> dispose() async {
    if (disposed) return;
    await stop();
    disposed = true;
  }
}
