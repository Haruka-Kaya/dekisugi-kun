import 'package:dekisugi/services/local_pronunciation_practice.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Recognizer implements OnDeviceSpeechRecognizer {
  _Recognizer(this.result);

  OnDeviceSpeechResult result;
  int cancelled = 0;

  @override
  Future<OnDeviceSpeechResult> recognize({
    String languageTag = 'ja-JP',
  }) async => result;

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async => cancelled++;
}

const _target = '最高点でも物体には下向きの重力が働く';
const _accepted = [_target, '最高点でも物体には下向きの重力がはたらく'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('OS表記揺れだけを完全一致で受理し、候補本文はsnapshotへ出さない', () async {
    final recognizer = _Recognizer(
      const OnDeviceSpeechResult(
        status: OnDeviceSpeechStatus.recognized,
        candidates: ['最高点でも、物体には下向きの重力が はたらく。'],
      ),
    );
    final practice = LocalPronunciationPractice(
      targetPhrase: _target,
      acceptedTranscripts: _accepted,
      recognizer: recognizer,
    );

    await practice.start();

    expect(practice.snapshot.state, LocalPronunciationState.matched);
    expect(practice.snapshot.toString(), isNot(contains('最高点')));
    await practice.dispose();
    expect(recognizer.cancelled, 1);
  });

  test('無音と無関係発話を別状態にし、どちらもmatchedにしない', () async {
    final recognizer = _Recognizer(
      const OnDeviceSpeechResult(status: OnDeviceSpeechStatus.noSpeech),
    );
    final practice = LocalPronunciationPractice(
      targetPhrase: _target,
      acceptedTranscripts: _accepted,
      recognizer: recognizer,
    );

    await practice.start();
    expect(practice.snapshot.state, LocalPronunciationState.noSpeech);

    recognizer.result = const OnDeviceSpeechResult(
      status: OnDeviceSpeechStatus.recognized,
      candidates: ['最高点では力がゼロになる'],
    );
    await practice.start();
    expect(practice.snapshot.state, LocalPronunciationState.unrelatedSpeech);
    await practice.dispose();
  });

  test('文字代替も固定目標の完全一致だけを受け、1文字や部分一致を拒否する', () async {
    final practice = LocalPronunciationPractice(
      targetPhrase: _target,
      acceptedTranscripts: _accepted,
      recognizer: _Recognizer(
        const OnDeviceSpeechResult(status: OnDeviceSpeechStatus.cancelled),
      ),
    );

    expect(practice.matchesTypedTarget('最'), isFalse);
    expect(practice.matchesTypedTarget('最高点でも物体には下向きの重力'), isFalse);
    expect(practice.matchesTypedTarget(' 最高点でも、物体には下向きの重力が働く。 '), isTrue);
    await practice.dispose();
  });

  test('platform bridgeはlocaleだけを送り、認識候補と状態をfail-closedで読む', () async {
    const channel = MethodChannel(
      'jp.dekisugi.dekisugi/on_device_speech_recognition',
    );
    final methods = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methods.add(call);
          if (call.method == 'recognize') {
            return <String, Object?>{
              'status': 'recognized',
              'candidates': <String>[_target],
            };
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final recognizer = PlatformOnDeviceSpeechRecognizer(channel: channel);

    final result = await recognizer.recognize();
    await recognizer.stop();
    await recognizer.cancel();

    expect(result.status, OnDeviceSpeechStatus.recognized);
    expect(result.candidates, [_target]);
    expect(methods.map((call) => call.method), ['recognize', 'stop', 'cancel']);
    expect(methods.first.arguments, {'language': 'ja-JP'});
    expect(
      (methods.first.arguments as Map).containsKey('targetPhrase'),
      isFalse,
    );
  });
}
