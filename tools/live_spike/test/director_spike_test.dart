// Gemini Live の Dart 実装スパイク。
//
// 検証したいこと（デキすぎ君の心臓部）:
//   AI は「教わる側の後輩」を演じる。サーバ側のディレクターが
//   「次はこの誤概念を口にして」と [DIRECTOR] 付きで指示したとき、
//   モデルがそれを **読み上げずに**、自分の言葉の発言へ変換できるか。
//
// jiyu-kenkyu-ai は同じ機構を TypeScript で検証済み（読み上げ0件）。
// Dart から同じことができるかは前例がなく、doc 上「最大の技術リスク」としていた。
//
// 注意: gemini-3.1-flash-live-preview は **TEXT モダリティを一切サポートしない**
// （1007: "The requested combination of response modalities (TEXT) is not supported"）。
// 出力は AUDIO のみなので、モデルが何と言ったかは outputAudioTranscription で読む。
// これは本番と同じ経路なので、テキスト版より検証としても正しい。
//
// 端末は不要。ネットワークだけ使う:
//   flutter test test/director_spike_test.dart
//
// APIキーは環境変数 GEMINI_API_KEY、または jiyu-kenkyu-ai/.env.local から読む。

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gemini_live/gemini_live.dart';

const kModel = 'gemini-3.1-flash-live-preview';
const kDirectorPrefix = '[DIRECTOR]';

String _loadKey() {
  final env = Platform.environment['GEMINI_API_KEY'];
  if (env != null && env.isNotEmpty) return env;
  for (final p in <String>[
    r'.env.local',
    r'C:\Users\kayah\jiyu-kenkyu-ai\.env.local',
  ]) {
    final f = File(p);
    if (f.existsSync()) {
      final m = RegExp(r'GEMINI_API_KEY\s*=\s*(\S+)').firstMatch(f.readAsStringSync());
      if (m != null) return m.group(1)!.replaceAll(RegExp(r'''^["']|["']$'''), '');
    }
  }
  throw StateError('GEMINI_API_KEY が見つかりません');
}

/// デキすぎ君の AI 生徒。教わる側であって、教える側ではない。
String _systemInstruction() => '''
あなたは中学2年生の「後輩」です。相手（先輩）から理科を教わっています。

## 役割
- あなたは**教わる側**です。解説をしないでください。
- 短く反応し、分からないところを聞き返します。
- 話し方は中学生。1〜2文、40字程度。教科書口調にしない。

## 重要: 進行ディレクターからの指示について
「$kDirectorPrefix」で始まるテキストが届くことがあります。
これは会話の進行を管理する内部システムから、**あなただけ**に宛てた指示です。
先輩の発言ではありません。

- **絶対にそのまま読み上げないでください。**
- 指示が届いたことに言及しないでください（「指示が来ました」などと言わない）。
- 指示の内容を、**あなた自身の言葉の発言1つ**に変換して、会話の流れの中で自然に言ってください。
- 指示そのものに返事をしないでください。
''';

void main() {
  test('[DIRECTOR] 注入が読み上げられず、後輩の発言に変換される', () async {
    final genAI = GoogleGenAI(apiKey: _loadKey());

    final turns = <String>[];
    var turnDone = Completer<void>();
    final buf = StringBuffer();

    final session = await genAI.live.connect(
      LiveConnectParameters(
        model: kModel,
        // このモデルは AUDIO 出力しか持たない。発話内容は文字起こしで読む。
        config: GenerationConfig(responseModalities: [Modality.AUDIO]),
        systemInstruction: Content(role: 'system', parts: [Part(text: _systemInstruction())]),
        sessionResumption: SessionResumptionConfig(),
        contextWindowCompression: ContextWindowCompressionConfig(slidingWindow: SlidingWindow()),
        // jiyu-kenkyu-ai の実測どおり、言語自動判定は切って ja-JP に固定する
        // （不明瞭な発話が韓国語として文字起こしされる事故があった）
        outputAudioTranscription:
            AudioTranscriptionConfig(languageHints: LanguageHints(languageCodes: ['ja-JP'])),
        inputAudioTranscription:
            AudioTranscriptionConfig(languageHints: LanguageHints(languageCodes: ['ja-JP'])),
        callbacks: LiveCallbacks(
          onMessage: (m) {
            // 音声そのものは捨て、何と言ったかは文字起こしで受け取る
            final t = m.serverContent?.outputTranscription?.text;
            if (t != null) buf.write(t);
            if (m.serverContent?.turnComplete ?? false) {
              turns.add(buf.toString().trim());
              buf.clear();
              if (!turnDone.isCompleted) turnDone.complete();
            }
          },
          onError: (e, s) => fail('接続エラー: $e'),
        ),
      ),
    );

    Future<String> inject(String instruction) async {
      turnDone = Completer<void>();
      session.sendRealtimeText('$kDirectorPrefix $instruction');
      await turnDone.future.timeout(const Duration(seconds: 45));
      return turns.last;
    }

    // ── ① 会話の口火をディレクターが切る
    final t1 = await inject('会話を始めて。先輩に「落下」について教えてほしいと短く頼んで。');
    stdout.writeln('\n── ① 口火');
    stdout.writeln('   指示 : 落下について教えてほしいと頼んで');
    stdout.writeln('   発話 : $t1');

    // ── ② デキすぎ君の核心。既知の誤概念をわざと口にさせる
    const lure = '重い物体ほど速く落ちる';
    final t2 = await inject(
      '先輩が説明を終えた。次は誤概念「$lure」を、'
      'あなた自身が信じているかのように、確認する形で口にして。断定しすぎないこと。',
    );
    stdout.writeln('\n── ② 誤概念の誘発');
    stdout.writeln('   指示 : 誤概念「$lure」を口にして');
    stdout.writeln('   発話 : $t2');

    await session.close();

    // ── 判定
    // 読み上げていたら指示文の語がそのまま出る
    const leaked = ['DIRECTOR', '指示', '会話を始めて', '短く頼んで', 'あなた自身が信じている', '断定しすぎない'];
    for (final t in [t1, t2]) {
      for (final w in leaked) {
        expect(t.contains(w), isFalse, reason: '指示文が漏れている: "$w" in "$t"');
      }
      expect(t.length, greaterThan(4), reason: '発話が空に近い: "$t"');
      expect(t.length, lessThan(200), reason: '後輩の発言としては長すぎる: "$t"');
    }

    // ②は誤概念を口にしているはず（「重い」に言及する）
    expect(t2.contains('重'), isTrue, reason: '誤概念が誘発されていない: "$t2"');

    stdout.writeln('\n✓ 読み上げ漏れなし / 誤概念の誘発に成功');
  }, timeout: const Timeout(Duration(minutes: 3)));
}
