import 'package:flutter_test/flutter_test.dart';

import 'package:dekisugi/learning/services/local_companion_voice.dart';

class _StubEngine implements CompanionVoiceEngine {
  _StubEngine(this.response);
  final String? response;

  @override
  Future<String?> generateAck({
    required String explanation,
    required List<String> heardTerms,
    required String conceptLabel,
  }) async =>
      response;
}

class _ThrowingEngine implements CompanionVoiceEngine {
  @override
  Future<String?> generateAck({
    required String explanation,
    required List<String> heardTerms,
    required String conceptLabel,
  }) {
    throw StateError('provider down');
  }
}

void main() {
  const lure = '水は電気を通さない、と思っていた';
  const explanation = '水道水には不純物が混ざっているから電気を通す';
  const concept = '電流';

  group('sanitizeCompanionAck', () {
    test('普通の生成文は整形して通す', () {
      expect(
        sanitizeCompanionAck('「ふむふむ、不純物が混ざるから通すのか」', lure: lure),
        'ふむふむ、不純物が混ざるから通すのか',
      );
    });

    test('空・null は受理しない', () {
      expect(sanitizeCompanionAck(null, lure: lure), isNull);
      expect(sanitizeCompanionAck('   ', lure: lure), isNull);
    });

    test('日本語を含まない出力は受理しない', () {
      expect(sanitizeCompanionAck('That is a nice explanation.', lure: lure),
          isNull);
    });

    test('質問形は受理しない（固定の問いが後続する）', () {
      expect(sanitizeCompanionAck('ふむ、本当にそうかな？', lure: lure), isNull);
      expect(sanitizeCompanionAck('ほう、本当か?', lure: lure), isNull);
    });

    test('lureの丸写しは受理しない', () {
      expect(sanitizeCompanionAck('水は電気を通さない、と思っていた', lure: lure),
          isNull);
    });

    test('長すぎる文は句点で切る', () {
      final long = 'あいうえおかきくけこさしすせそ。${'あ' * 100}';
      final out = sanitizeCompanionAck(long, lure: lure, maxChars: 30);
      expect(out, isNotNull);
      expect(out!.length, lessThanOrEqualTo(30));
      expect(out.endsWith('。') || out.endsWith('…'), isTrue);
    });

    test('改行とマークダウン装飾を除去する', () {
      expect(
        sanitizeCompanionAck('**ふむ**\n不純物ね', lure: lure),
        'ふむ 不純物ね',
      );
    });
  });

  group('CompanionVoice.renderAck', () {
    test('engineが無ければnull（カタログフォールバック）', () async {
      final voice = CompanionVoice();
      expect(voice.available, isFalse);
      expect(
        await voice.renderAck(
          explanation: explanation,
          heardTerms: const ['不純物'],
          conceptLabel: concept,
          lure: lure,
        ),
        isNull,
      );
    });

    test('説明が空ならengineを呼ばずnull', () async {
      var called = false;
      final engine = _StubEngine('ふむ');
      final probe = _ProbeEngine(engine, () => called = true);
      final voice = CompanionVoice(engine: probe);
      expect(
        await voice.renderAck(
          explanation: '  ',
          heardTerms: const [],
          conceptLabel: concept,
          lure: lure,
        ),
        isNull,
      );
      expect(called, isFalse);
    });

    test('engineの出力を検証して返す', () async {
      final voice =
          CompanionVoice(engine: _StubEngine('「ふむ、不純物が混ざるのか」'));
      expect(
        await voice.renderAck(
          explanation: explanation,
          heardTerms: const ['不純物'],
          conceptLabel: concept,
          lure: lure,
        ),
        'ふむ、不純物が混ざるのか',
      );
    });

    test('engineの不合格出力はnull', () async {
      final voice = CompanionVoice(engine: _StubEngine('English only'));
      expect(
        await voice.renderAck(
          explanation: explanation,
          heardTerms: const [],
          conceptLabel: concept,
          lure: lure,
        ),
        isNull,
      );
    });

    test('engineの例外はnull（画面を止めない）', () async {
      final voice = CompanionVoice(engine: _ThrowingEngine());
      expect(
        await voice.renderAck(
          explanation: explanation,
          heardTerms: const [],
          conceptLabel: concept,
          lure: lure,
        ),
        isNull,
      );
    });
  });

  group('buildCompanionAckPrompt', () {
    test('前置きだけを返させる制約を含む', () {
      final prompt = buildCompanionAckPrompt(
        explanation: explanation,
        heardTerms: const ['不純物', '電気'],
        conceptLabel: concept,
      );
      expect(prompt, contains('前置き'));
      expect(prompt, contains(explanation));
      expect(prompt, contains(concept));
      expect(prompt, contains('質問・答え・説明の正誤・指示は一切言わない'));
      // lureや正解は含めない
      expect(prompt, isNot(contains(lure)));
    });
  });
}

class _ProbeEngine implements CompanionVoiceEngine {
  _ProbeEngine(this.inner, this.onCall);
  final CompanionVoiceEngine inner;
  final void Function() onCall;

  @override
  Future<String?> generateAck({
    required String explanation,
    required List<String> heardTerms,
    required String conceptLabel,
  }) {
    onCall();
    return inner.generateAck(
      explanation: explanation,
      heardTerms: heardTerms,
      conceptLabel: conceptLabel,
    );
  }
}
