/// 自由説明に「大事な言葉」が入っているかを端末内だけで確かめる。
///
/// 正しさは採点しない —— 答え合わせは固定の問い返しと教材との
/// 自己比較が担う。ここで確かめるのは「デキすぎ君が説明を聞いて、
/// この概念の言葉を拾えたか」だけ。無関係な文や空白では
/// 「もう少し聞かせて」と返し、意味ある語彙を含む説明だけを
/// 先へ進める最小限の合図。
///
/// 教材の期待文([LocalPracticeVariant.expectedOutcome]/[expectedReason])
/// からキーワードを抽出し、生徒の説明との語彙重なりを見る。
/// 外部APIは呼ばず、説明文・認識候補ともに保存・送信しない。
library;

/// [ExplanationCoverage.assess] の結果。
class ExplanationCoverage {
  const ExplanationCoverage({
    required this.cueTerms,
    required this.matchedTerms,
    required this.requiredHits,
  });

  /// 期待文から拾った「大事な言葉」。画面は聞き取れた分だけを表示し、
  /// 未検出の語を答えとして見せない。
  final List<String> cueTerms;

  /// 説明の中に実際に現れたcue。
  final List<String> matchedTerms;

  /// 「聞き取れた」とみなすために必要なcue数。
  final int requiredHits;

  /// cueを取れる教材が無い（legacy fallback等）ときfalse。
  /// 判定できないときは塞がず通す —— 迷ったら観測しない憲法と同じ。
  bool get isAssessable => cueTerms.isNotEmpty;

  bool get isSufficient => !isAssessable || matchedTerms.length >= requiredHits;
}

/// 漢字の連なり。「質量保存」「空気抵抗」などの複合語を拾う。
final _kanjiRun = RegExp(r'[一-鿿々〆]+');

/// カタカナ語。「エネルギー」「ニュートン」など。長音を含める。
final _katakanaRun = RegExp(r'[ァ-ヺー]+');

/// 英数字のまとまり。「CO2」「pH」など。
final _alnumRun = RegExp(r'[A-Za-z0-9]+');

/// 説明を振るう定型の足場語。これだけを並べても「教えた」ことにしない。
const _stopwords = {
  'こと',
  'もの',
  'ため',
  '場合',
  'ところ',
  'よう',
  '同じ',
  '説明',
  '答え',
  '教材',
  '比較',
  '確認',
  '問題',
  '質問',
  '選択肢',
  'チェックポイント',
  '旧形式',
  '直接',
  '対応',
  '以下',
  '以上',
  '読み直',
  '流用',
};

/// [source] から大事な言葉の候補を抽出する。
///
/// 漢字・カタカナは2文字以上の連なり、英数字は2文字以上のまとまり。
/// 句読点を挟まない連なりだけを取るので、文としての自然さは問わない。
List<String> extractCueTerms(String source) {
  final terms = <String>[];
  final seen = <String>{};
  void collect(RegExp pattern, int minLength) {
    for (final match in pattern.allMatches(source)) {
      final term = match.group(0)!;
      if (term.length < minLength || _stopwords.contains(term)) continue;
      if (seen.add(term)) terms.add(term);
    }
  }

  collect(_kanjiRun, 2);
  collect(_katakanaRun, 2);
  collect(_alnumRun, 2);
  return terms;
}

/// cueが説明へ現れたかを見る「表れ形」。
///
/// - 2字の漢字語は語頭も足す（「落下」に対して「落ちる」、
///   「重さ」に対して「重い」が同じ言葉を指すため）。
/// - 3字以上は全体に加えて先頭2字・末尾2字（「空気の抵抗」は
///   「空気抵抗」へ「抵抗」で届く）。
/// - カタカナ・英数字も同じ考え方。ゆるい一致でよい —
///   意味を採るのでなく、語彙が点っているかだけを見る。
bool _isAllKanji(String value) => value.runes.every(
  (rune) => rune >= 0x4e00 && rune <= 0x9fff || rune == 0x3005 || rune == 0x3006,
);

List<String> _cueStems(String cue) {
  if (cue.length < 2) return [cue];
  if (cue.length == 2) {
    // 語頭の漢字は語幹として拾う。「落下」→「落ちる」「重さ」→「重い」。
    // 漢字語だけに限定し、「CO」→「C」や「ニュ」→「ニ」の過剰一致は避ける。
    return _isAllKanji(cue) ? [cue, cue.substring(0, 1)] : [cue];
  }
  return {cue, cue.substring(0, 2), cue.substring(cue.length - 2)}.toList();
}

/// 比較用の正規化。空白・句読点・全角半角を吸収し、
/// ひらがなはカタカナへ寄せる（「えねるぎー」≈「エネルギー」）。
String _normalizeForMatch(String raw) {
  final buffer = StringBuffer();
  for (final rune in raw.runes) {
    if (rune == 0x3000) continue;
    if (rune >= 0x3041 && rune <= 0x3096) {
      buffer.writeCharCode(rune + 0x60);
      continue;
    }
    if (rune >= 0xff01 && rune <= 0xff5e) {
      buffer.writeCharCode(rune - 0xfee0);
      continue;
    }
    // 和文・英数字以外の記号・空白は境界を残さず落とす。
    final isSpace = rune == 0x20 || rune == 0x09 || rune == 0x0a || rune == 0x0d;
    if (isSpace) continue;
    buffer.writeCharCode(rune);
  }
  var text = buffer.toString().toLowerCase();
  text = text.replaceAll(
    RegExp(r'''[、。,.!?，．！？…〜~'‘’"“”「」『』（）()\[\]{}:：;；\-‐‑‒–—―−]'''),
    '',
  );
  return text;
}

/// 自由説明の中の「大事な言葉」の点在を評価する。
///
/// [sources] は正しさの正本（expectedOutcome/expectedReasonなど
/// 説明フェーズ中は画面に出ない文字列）。空なら判定不能として通す。
/// [maxCueTerms] は1教材あたりのcue上限 —— 先に現れた語を優先する。
ExplanationCoverage assessExplanation(
  String explanation, {
  required Iterable<String> sources,
  int maxCueTerms = 14,
}) {
  final cues = <String>[];
  final seen = <String>{};
  for (final source in sources) {
    for (final term in extractCueTerms(source)) {
      if (cues.length >= maxCueTerms) break;
      if (seen.add(term)) cues.add(term);
    }
    if (cues.length >= maxCueTerms) break;
  }
  if (cues.isEmpty) {
    return const ExplanationCoverage(
      cueTerms: [],
      matchedTerms: [],
      requiredHits: 0,
    );
  }
  final normalized = _normalizeForMatch(explanation);
  final matched = <String>[
    for (final cue in cues)
      if (_cueStems(cue).any(normalized.contains)) cue,
  ];
  // 4語以上ある概念は2語届いて「聞き取れた」。少ない概念は1語で十分。
  final requiredHits = cues.length >= 4 ? 2 : 1;
  return ExplanationCoverage(
    cueTerms: List.unmodifiable(cues),
    matchedTerms: List.unmodifiable(matched),
    requiredHits: requiredHits,
  );
}
