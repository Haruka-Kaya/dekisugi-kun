import 'dart:async';

import 'package:dekisugi/services/local_narration.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/local_narration');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('端末channelへtrim済み本文と言語だけを渡し、dispose後は呼ばない', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'speak';
        });
    final narration = PlatformLocalNarration(channel: channel);

    expect(await narration.speak('  科学の説明  '), isTrue);
    expect(calls.single.method, 'speak');
    expect(calls.single.arguments, {'text': '科学の説明', 'language': 'ja-JP'});

    await narration.dispose();
    expect(calls.last.method, 'stop');
    expect(await narration.speak('もう一度'), isFalse);
    expect(calls.length, 2);
  });

  test('空文字と上限超過はnativeへ渡さずfalse', () async {
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls++;
          return true;
        });
    final narration = PlatformLocalNarration(channel: channel);

    expect(await narration.speak('   '), isFalse);
    expect(await narration.speak('あ' * 801), isFalse);
    expect(calls, 0);
  });

  test('同梱録音assetはListening直下のflat ASCII m4a/wavだけを受け付ける', () {
    const text = '固定教材';
    const narrator = '理科教材ナレーター';
    for (final path in <String>[
      'assets/audio/listening/../secret.m4a',
      'assets/audio/listening/nested/prompt.wav',
      'assets/audio/listening/教材.m4a',
      'assets/audio/listening/prompt.mp3',
      'assets/audio/speaking/prompt.wav',
    ]) {
      expect(
        () => BundledHumanNarrationAsset(
          path: path,
          transcript: text,
          narratorLabel: narrator,
        ),
        throwsArgumentError,
        reason: path,
      );
    }

    expect(
      BundledHumanNarrationAsset(
        path: 'assets/audio/listening/fall-foundation.wav',
        transcript: text,
        narratorLabel: narrator,
      ).path,
      'assets/audio/listening/fall-foundation.wav',
    );
  });

  test('nativeが同梱録音を完了した場合はTTSと分けて出所を返す', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'playBundledHumanRecording';
        });
    final narration = PlatformLocalNarration(channel: channel);
    const text = '空気抵抗を無視すれば落下の速さは重さによらない';
    final recording = BundledHumanNarrationAsset(
      path: 'assets/audio/listening/fall-foundation.m4a',
      transcript: text,
      narratorLabel: '理科教材ナレーター',
    );

    final played = await narration.play(
      LocalNarrationRequest(text: text, bundledHumanRecording: recording),
    );

    expect(played.completed, isTrue);
    expect(played.delivery, LocalNarrationDelivery.bundledHumanRecording);
    expect(calls, hasLength(1));
    expect(calls.single.method, 'playBundledHumanRecording');
    expect(calls.single.arguments, {'assetPath': recording.path});
  });

  test('同梱録音が未対応なら端末TTSへだけfallbackする', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return call.method == 'speak';
        });
    final narration = PlatformLocalNarration(channel: channel);
    const text = '空気抵抗を無視すれば落下の速さは重さによらない';
    final recording = BundledHumanNarrationAsset(
      path: 'assets/audio/listening/fall-foundation.m4a',
      transcript: text,
      narratorLabel: '理科教材ナレーター',
    );

    final played = await narration.play(
      LocalNarrationRequest(text: text, bundledHumanRecording: recording),
    );

    expect(played.completed, isTrue);
    expect(played.delivery, LocalNarrationDelivery.deviceSpeechSynthesis);
    expect(calls.map((call) => call.method), [
      'playBundledHumanRecording',
      'speak',
    ]);
  });

  test('同梱録音の待機中にstopした場合はTTSを再起動しない', () async {
    final assetCompletion = Completer<bool>();
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'playBundledHumanRecording') {
            return assetCompletion.future;
          }
          if (call.method == 'stop') {
            assetCompletion.complete(false);
            return null;
          }
          return true;
        });
    final narration = PlatformLocalNarration(channel: channel);
    const text = '空気抵抗を無視すれば落下の速さは重さによらない';
    final recording = BundledHumanNarrationAsset(
      path: 'assets/audio/listening/fall-foundation.m4a',
      transcript: text,
      narratorLabel: '理科教材ナレーター',
    );

    final playing = narration.play(
      LocalNarrationRequest(text: text, bundledHumanRecording: recording),
    );
    await Future<void>.delayed(Duration.zero);
    await narration.stop();
    final result = await playing;

    expect(result.completed, isFalse);
    expect(result.delivery, LocalNarrationDelivery.unavailable);
    expect(calls.map((call) => call.method), [
      'playBundledHumanRecording',
      'stop',
    ]);
  });
}
