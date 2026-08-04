/// 角丸の一元管理。
///
/// attendance_app は 16 / 12 / 10 / 20 が各ファイルに散っており、
/// DESIGN.md §4.2 自身が「集約する」を未完の TODO として記録している。
/// ここでは最初から集約する。**画面側で数値を直接書かないこと。**
///
/// DESIGN.md §4.2 に従い、単一の [base] からの倍率で導出する。
/// px オフセット版（`base - 4` のような書き方）は base が 0 のとき負値になるので使わない。
abstract final class AppRadius {
  /// 導出の基準。これだけを動かせば全体の印象が変わる。
  static const double base = 12.0;

  static const double sm = base * 0.6; // 7.2  … チップ内の小要素
  static const double md = base * 0.8; // 9.6  … 入れ子の面
  static const double lg = base * 1.0; // 12.0 … 入力欄・ボタン
  static const double xl = base * 1.4; // 16.8 … カード
  static const double xxl = base * 1.8; // 21.6 … シート・大きな面

  /// 完全な丸。チップやアバターなど「丸である」ことに意味がある要素だけに使う。
  /// [base] から導出しないので、base を変えても追従しない（それが正しい）。
  static const double pill = 999.0;
}
