/// 文字起こしの整形。
///
/// Vertex の日本語の文字起こしは**形態素の切れ目に空白が入る**。
/// 実機の記録: 「最近 さあ 人間 関係 に 悩ん で て さ」
///
/// そのまま出すと読みにくく、ディレクターに渡す逐語も不自然になる。
/// ただし**英数字の間の空白は意味を持つ**ので消してはいけない
/// （「Newton の 第 1 法則」→「Newtonの第1法則」は良いが、
///   「free fall」→「freefall」は壊れる）。
library;

/// 和文とみなす文字。ひらがな・カタカナ・漢字・全角約物。
const _ja =
    r'[々〆぀-ヿㇰ-ㇿ'
    r'㐀-䶿一-鿿豈-﫿'
    r'　-〿！-｠]';

/// 空白を落とす条件 — **片側は必ず和文**であること。
///
/// - 和文 ␣ 和文    … 「人間 関係」→「人間関係」
/// - 和文 ␣ 数字    … 「第 1 法則」→「第1法則」
/// - 数字 ␣ 和文    … 「10 個」→「10個」
///
/// 両側とも英数字なら触らない（「free fall」を壊さない）。
///
/// 先読みを使っているので、連続する切れ目も1回の走査で片づく
/// （空白を消したあと、次の一致は捕捉した文字の直後から始まる）。
final _closable = RegExp('(?:($_ja)[ 　]+(?=$_ja|[0-9])|([0-9])[ 　]+(?=$_ja))');

/// 残った空白の重なりをひとつにまとめる
final _runs = RegExp(r'[ 　]{2,}');

/// challenge 比較で発音内容として扱わない句読点・記号。
final _challengePunctuation = RegExp(
  r'''[、。,.!?，．！？…〜~'‘’"“”「」『』（）()\[\]{}:：;；\-‐‑‒–—―−]''',
  unicode: true,
);
final _challengeWhitespace = RegExp(r'[\s　]+', unicode: true);
final _hasJapanese = RegExp(r'[々〆぀-ヿ㐀-鿿豈-﫿]', unicode: true);

/// 文字起こしを表示・記録に使える形に整える。
String tidyJa(String raw) {
  if (raw.isEmpty) return raw;
  return raw
      .replaceAllMapped(_closable, (m) => m[1] ?? m[2]!)
      .replaceAll(_runs, ' ')
      .trim();
}

/// 固定 lure と Live の文字起こしを比べるための正規化。
///
/// 大文字小文字、全角 ASCII、空白、句読点だけを吸収し、
/// 語の追加・省略は吸収しない。そのため「前後に自然な一言」も
/// challenge としては受理されない。
String normalizeChallengeText(String raw) {
  final compatibilityAscii = String.fromCharCodes(
    raw.runes.map((codePoint) {
      if (codePoint == 0x3000) return 0x20;
      if (codePoint >= 0xff01 && codePoint <= 0xff5e) {
        return codePoint - 0xfee0;
      }
      return codePoint;
    }),
  );
  final normalized = compatibilityAscii
      .toLowerCase()
      .replaceAll(_challengeWhitespace, ' ')
      .replaceAll(_challengePunctuation, '')
      .trim();
  return _hasJapanese.hasMatch(normalized)
      ? normalized.replaceAll(_challengeWhitespace, '')
      : normalized.replaceAll(_challengeWhitespace, ' ');
}

bool isExactChallengeText(String actual, String expected) {
  final normalizedExpected = normalizeChallengeText(expected);
  return normalizedExpected.isNotEmpty &&
      normalizeChallengeText(actual) == normalizedExpected;
}
