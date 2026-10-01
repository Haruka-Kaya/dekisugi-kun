import 'dart:async';

import 'package:flutter/services.dart';

import 'transcript_text.dart';

enum LocalPronunciationState {
  idle,
  listening,
  matched,
  noSpeech,
  unrelatedSpeech,
  permissionDenied,
  unavailable,
  failed,
  disposed,
}

class LocalPronunciationSnapshot {
  const LocalPronunciationSnapshot(this.state);

  /// 認識候補は画面StateやStoreへ出さず、達成可否だけを公開する。
  final LocalPronunciationState state;
}

enum OnDeviceSpeechStatus {
  recognized,
  noSpeech,
  unrelatedSpeech,
  permissionDenied,
  unavailable,
  failed,
  cancelled,
}

class OnDeviceSpeechResult {
  const OnDeviceSpeechResult({
    required this.status,
    this.candidates = const [],
  });

  final OnDeviceSpeechStatus status;

  /// [LocalPronunciationPractice]内の完全一致にだけ使う一時値。
  final List<String> candidates;
}

abstract interface class OnDeviceSpeechRecognizer {
  Future<OnDeviceSpeechResult> recognize({String languageTag = 'ja-JP'});

  Future<void> stop();

  Future<void> cancel();
}

/// Android/iOSの「オンデバイス専用」認識bridge。
///
/// Androidは`createOnDeviceSpeechRecognizer`、iOSは
/// `requiresOnDeviceRecognition = true`をnative側で強制する。通常のrecognizerへ
/// fallbackしないため、端末内モデルが無い場合は[OnDeviceSpeechStatus.unavailable]。
class PlatformOnDeviceSpeechRecognizer implements OnDeviceSpeechRecognizer {
  PlatformOnDeviceSpeechRecognizer({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName =
      'jp.dekisugi.dekisugi/on_device_speech_recognition';
  final MethodChannel _channel;

  @override
  Future<OnDeviceSpeechResult> recognize({String languageTag = 'ja-JP'}) async {
    try {
      final raw = await _channel.invokeMapMethod<Object?, Object?>(
        'recognize',
        {'language': languageTag},
      );
      if (raw == null) {
        return const OnDeviceSpeechResult(status: OnDeviceSpeechStatus.failed);
      }
      final status = switch (raw['status']) {
        'recognized' => OnDeviceSpeechStatus.recognized,
        'noSpeech' => OnDeviceSpeechStatus.noSpeech,
        'unrelatedSpeech' => OnDeviceSpeechStatus.unrelatedSpeech,
        'permissionDenied' => OnDeviceSpeechStatus.permissionDenied,
        'unavailable' => OnDeviceSpeechStatus.unavailable,
        'cancelled' => OnDeviceSpeechStatus.cancelled,
        _ => OnDeviceSpeechStatus.failed,
      };
      final rawCandidates = raw['candidates'];
      if (status != OnDeviceSpeechStatus.recognized) {
        return OnDeviceSpeechResult(status: status);
      }
      if (rawCandidates is! List ||
          rawCandidates.isEmpty ||
          rawCandidates.length > 10 ||
          rawCandidates.any(
            (candidate) =>
                candidate is! String ||
                candidate.trim().isEmpty ||
                candidate.length > 512,
          )) {
        return const OnDeviceSpeechResult(status: OnDeviceSpeechStatus.failed);
      }
      return OnDeviceSpeechResult(
        status: status,
        candidates: List.unmodifiable(rawCandidates.cast<String>()),
      );
    } on PlatformException {
      return const OnDeviceSpeechResult(status: OnDeviceSpeechStatus.failed);
    } on MissingPluginException {
      return const OnDeviceSpeechResult(
        status: OnDeviceSpeechStatus.unavailable,
      );
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException {
      // recognize側の最終結果をfail-closedで受ける。停止失敗だけで達成にしない。
    } on MissingPluginException {
      // desktop/testにnative実装が無ければ、待機中のrecognizeがunavailableになる。
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } on PlatformException {
      // route破棄時は結果を使わない。native側もlifecycleで必ず破棄する。
    } on MissingPluginException {
      // native実装が無い環境では破棄対象も無い。
    }
  }
}

/// catalog固定語句と、OSのオンデバイス認識候補をRAM内だけで完全一致する。
///
/// 音声バッファはnative recognizerへ渡したら保持せず、認識候補もsnapshotへ含めない。
/// 意味類似・部分一致・confidence閾値では達成にしない。
class LocalPronunciationPractice {
  LocalPronunciationPractice({
    required String targetPhrase,
    required List<String> acceptedTranscripts,
    OnDeviceSpeechRecognizer? recognizer,
  }) : assert(targetPhrase.trim().isNotEmpty),
       assert(acceptedTranscripts.isNotEmpty),
       _targetPhrase = targetPhrase,
       _acceptedTranscripts = List.unmodifiable(acceptedTranscripts),
       _recognizer = recognizer ?? PlatformOnDeviceSpeechRecognizer();

  final String _targetPhrase;
  final List<String> _acceptedTranscripts;
  final OnDeviceSpeechRecognizer _recognizer;
  final _changes = StreamController<LocalPronunciationSnapshot>.broadcast();

  LocalPronunciationSnapshot _snapshot = const LocalPronunciationSnapshot(
    LocalPronunciationState.idle,
  );
  LocalPronunciationSnapshot get snapshot => _snapshot;
  Stream<LocalPronunciationSnapshot> get changes => _changes.stream;

  Future<void>? _recognitionInFlight;
  Future<void>? _disposeInFlight;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  /// 文字代替は表示正本そのものだけを受理する。これは発音確認ではない。
  bool matchesTypedTarget(String value) =>
      isExactChallengeText(value, _targetPhrase);

  Future<void> start() {
    if (_disposed || _recognitionInFlight != null) {
      return Future<void>.value();
    }
    final operation = _recognize();
    _recognitionInFlight = operation.whenComplete(() {
      _recognitionInFlight = null;
    });
    return _recognitionInFlight!;
  }

  Future<void> _recognize() async {
    _emit(LocalPronunciationState.listening);
    final result = await _recognizer.recognize();
    if (_disposed) return;
    final state = switch (result.status) {
      OnDeviceSpeechStatus.recognized =>
        result.candidates.any(
              (actual) => _acceptedTranscripts.any(
                (expected) => isExactChallengeText(actual, expected),
              ),
            )
            ? LocalPronunciationState.matched
            : LocalPronunciationState.unrelatedSpeech,
      OnDeviceSpeechStatus.noSpeech => LocalPronunciationState.noSpeech,
      OnDeviceSpeechStatus.unrelatedSpeech =>
        LocalPronunciationState.unrelatedSpeech,
      OnDeviceSpeechStatus.permissionDenied =>
        LocalPronunciationState.permissionDenied,
      OnDeviceSpeechStatus.unavailable => LocalPronunciationState.unavailable,
      OnDeviceSpeechStatus.failed => LocalPronunciationState.failed,
      OnDeviceSpeechStatus.cancelled => LocalPronunciationState.idle,
    };
    _emit(state);
  }

  Future<void> stop() async {
    if (_disposed || _snapshot.state != LocalPronunciationState.listening) {
      return;
    }
    await _recognizer.stop();
  }

  Future<void> cancelAttempt() async {
    if (_disposed) return;
    await _recognizer.cancel();
    if (!_disposed) _emit(LocalPronunciationState.idle);
  }

  void reset() {
    if (_disposed || _snapshot.state == LocalPronunciationState.listening) {
      return;
    }
    _emit(LocalPronunciationState.idle);
  }

  void _emit(LocalPronunciationState state) {
    if (_disposed && state != LocalPronunciationState.disposed) return;
    _snapshot = LocalPronunciationSnapshot(state);
    if (!_changes.isClosed) _changes.add(_snapshot);
  }

  Future<void> dispose() => _disposeInFlight ??= _dispose();

  Future<void> _dispose() async {
    if (_disposed) return;
    _disposed = true;
    _snapshot = const LocalPronunciationSnapshot(
      LocalPronunciationState.disposed,
    );
    if (!_changes.isClosed) _changes.add(_snapshot);
    await _recognizer.cancel();
    await _changes.close();
  }
}
