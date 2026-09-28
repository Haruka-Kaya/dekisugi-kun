/// 角丸の一元管理。
///
/// 画面ごとの場当たり的な角丸を避け、単一の [base] から倍率で導出する。
/// **画面側で数値を直接書かないこと。**
/// px オフセット版（`base - 4` のような書き方）は base が 0 のとき負値になるので使わない。
abstract final class AppRadius {
  /// 導出の基準。これだけを動かせば全体の印象が変わる。
  // 小さい操作まで丸くしすぎるとゲーム画面に寄るため、通常部品は引き締める。
  // 大きな会話ステージだけは [stage] で別のシルエットを与える。
  static const double base = 10.0;

  static const double sm = base * 0.6; // 6  … チップ内の小要素
  static const double md = base * 0.8; // 8  … 入れ子の面
  static const double lg = base * 1.0; // 10 … 入力欄
  static const double xl = base * 1.4; // 14 … ボタン・通常カード
  static const double xxl = base * 1.8; // 18 … シート・大きな面

  /// キャラクターと主行動を載せる、画面に1つだけの大きな面。
  static const double stage = base * 2.8;

  /// 完全な丸。チップやアバターなど「丸である」ことに意味がある要素だけに使う。
  /// [base] から導出しないので、base を変えても追従しない（それが正しい）。
  static const double pill = 999.0;
}
