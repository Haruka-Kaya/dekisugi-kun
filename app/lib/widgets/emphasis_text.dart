import '../config/app_theme.dart';
import '../ui/_material.dart';

/// `**ここ**` だけを太字にして表示する。
///
/// ## なぜ Markdown を入れないのか
///
/// 教材で要るのは**強調1つ**だけで、見出しも箇条書きも表もリンクも使わない。
/// パーサを1つ増やすと、書ける記法が増えたぶんだけ
/// 「教材で使ってよい書き方」が曖昧になる。ここは狭いままにしておく。
///
/// 解釈しないまま `Text` に渡すと `**` がそのまま画面に出る（実機で確認）。
///
/// ## 和文の強調は太字で作る
///
/// 斜体は和文で可読性を落とすので使わない。
/// 可変フォントの軸を動かすため [JaTextStyle.jaWeight] を通す。
class EmphasisText extends StatelessWidget {
  const EmphasisText(this.text, {super.key, this.style, this.textAlign});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final parts = splitEmphasis(text);

    // 強調が無ければ素の Text。余計な RichText を作らない
    if (parts.length == 1 && !parts.first.strong) {
      return Text(text, style: base, textAlign: textAlign);
    }

    return Text.rich(
      TextSpan(
        children: [
          for (final p in parts)
            TextSpan(
              text: p.text,
              style: p.strong ? base.jaWeight(FontWeight.w700) : null,
            ),
        ],
      ),
      style: base,
      textAlign: textAlign,
    );
  }
}

/// 文の一片。[strong] なら強調
typedef EmphasisPart = ({String text, bool strong});

/// `**` で囲まれたところを切り出す。
///
/// 閉じていない `**` は**記号のまま残す**。落とすと、書き間違えたときに
/// 文字が消えて気づけない。
List<EmphasisPart> splitEmphasis(String text) {
  if (!text.contains('**')) return [(text: text, strong: false)];

  final out = <EmphasisPart>[];
  var i = 0;
  while (i < text.length) {
    final open = text.indexOf('**', i);
    if (open < 0) break;
    final close = text.indexOf('**', open + 2);
    // 閉じが無い、または中身が空なら強調にしない
    if (close < 0 || close == open + 2) break;

    if (open > i) out.add((text: text.substring(i, open), strong: false));
    out.add((text: text.substring(open + 2, close), strong: true));
    i = close + 2;
  }
  if (i < text.length) out.add((text: text.substring(i), strong: false));
  return out.isEmpty ? [(text: text, strong: false)] : out;
}
