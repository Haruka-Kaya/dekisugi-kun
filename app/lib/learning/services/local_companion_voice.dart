import 'dart:async';

/// デキすぎ君の返事の「前置き」を生成する契約。
///
/// C3（AIは訂正・補完を返す）とC4（AIは質問を返す）を守るため、
/// 生成するのは生徒の説明への応答部分だけ。lure（思い込みの誘発文）と
/// 問いの逐語は必ずカタログをそのまま使い、生成文はその前に置く一言に
/// 限定する。生成失敗・検証不合格は全て null に退避し、
/// 呼び出し側はカタログテンプレへ戻る（決定論フォールバック）。
abstract class CompanionVoiceEngine {
  /// 生の生成文を返す。利用不能・失敗は null。
  Future<String?> generateAck({
    required String explanation,
    required List<String> heardTerms,
    required String conceptLabel,
  });
}

/// 生成された前置きの検証と整形。
///
/// 長すぎる文・質問形（固定の問いが後続するため二重の問いになる）・
/// lureの丸写し・日本語を含まない出力は受理しない。
String? sanitizeCompanionAck(
  String? raw, {
  required String lure,
  int maxChars = 72,
}) {
  if (raw == null) return null;
  var text = raw
      .replaceAll(RegExp(r'[\r\n]+'), ' ')
      .replaceAll(RegExp(r'[#*_`~]+'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  for (final pair in [
    ('「', '」'),
    ('"', '"'),
    ("'", "'"),
    ('（', '）'),
    ('(', ')'),
  ]) {
    if (text.startsWith(pair.$1) && text.endsWith(pair.$2) && text.length > 2) {
      text = text.substring(pair.$1.length, text.length - pair.$2.length).trim();
    }
  }
  if (text.isEmpty) return null;
  if (!RegExp(r'[぀-ヿ一-鿿]').hasMatch(text)) return null;
  if (text.contains('？') || text.contains('?')) return null;
  final lureCore = lure.replaceAll(RegExp(r'\s+'), '');
  if (lureCore.isNotEmpty && text.replaceAll(' ', '').contains(lureCore)) {
    return null;
  }
  if (text.length > maxChars) {
    final cut = text.substring(0, maxChars);
    final lastStop = cut.lastIndexOf('。');
    text = lastStop > 10 ? cut.substring(0, lastStop + 1) : '$cut…';
  }
  return text;
}

/// 前置き生成のプロンプトを組み立てる（サーバ側と同じ規則）。
///
/// モデルには「前置きだけ」を書かせる。lure の内容や正解は渡さず、
/// 回答・説教・追加の問いを禁止して安全側に縛る。
String buildCompanionAckPrompt({
  required String explanation,
  required List<String> heardTerms,
  required String conceptLabel,
}) {
  final terms = heardTerms.take(5).join('、');
  final heardLine = terms.isEmpty
      ? ''
      : '（この説明からは「$terms」という言葉が聞けた。）\n';
  return 'あなたは「デキすぎ君」。理科を学ぶAIパートナーで、自信満々だが教科書の思い込みをいくつか持っている。\n'
      '生徒が「$conceptLabel」について、こう説明してくれた：\n'
      '「$explanation」\n'
      '$heardLine'
      '生徒の説明を受け止める前置きを、50文字以内の日本語でひとことだけ返して。'
      '質問・答え・説明の正誤・指示は一切言わない。生徒が言った内容に触れて、'
      'デキすぎ君らしい、やや自信満々な口調で。前置きの文だけを返す。';
}

/// 前置きの生成を取りまとめる。engineがnullなら常にnull（フォールバック）。
class CompanionVoice {
  CompanionVoice({this.engine});

  final CompanionVoiceEngine? engine;

  bool get available => engine != null;

  /// 生徒の説明への前置きを生成する。必ずnull安全（失敗はnull）。
  Future<String?> renderAck({
    required String explanation,
    required List<String> heardTerms,
    required String conceptLabel,
    required String lure,
    Duration timeout = const Duration(seconds: 15),
  }) {
    final engine = this.engine;
    if (engine == null || explanation.trim().isEmpty) {
      return Future.value(null);
    }
    Future<String?> raw;
    try {
      raw = engine.generateAck(
        explanation: explanation.trim(),
        heardTerms: heardTerms,
        conceptLabel: conceptLabel,
      );
    } catch (_) {
      // 同期throwもnullへ —— 画面は必ずフォールバックで進む
      return Future.value(null);
    }
    return raw
        .timeout(timeout, onTimeout: () => null)
        .then((out) => sanitizeCompanionAck(out, lure: lure))
        .catchError((_) => null);
  }
}
