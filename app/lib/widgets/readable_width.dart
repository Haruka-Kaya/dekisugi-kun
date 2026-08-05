import '../ui/_material.dart';

/// 本文の幅を、読める範囲で止める。
///
/// ## なぜ要るか
///
/// iPad（学校が配っている端末）は横幅が広い。
/// スマホ前提のまま画面いっぱいに広げると、1行が長くなりすぎて
/// **行を折り返したときに次の行頭を見失う。**
///
/// 和文の1行の目安は 35〜45字。本文 16px で 1文字 ≒ 16px なので、
/// 上限を 640 とすると 40字前後になる。
///
/// > [!note] 数値の根拠
/// > 和文の適切な行長について、`.claude/docs/` の3文書に**一次ソースは無い**。
/// > ここは活字の慣習（1行 35〜45字）から置いた値で、実測ではない。
/// > 生徒に読ませて確かめる余地がある。
///
/// ## 会話画面には使わない
///
/// キャラクターと逐語は中央に寄せるより、画面の広さを使ったほうがよい。
/// **読み物にだけ効かせる。**
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({
    super.key,
    required this.child,
    this.maxWidth = 640,
    this.tight = false,
  });

  final Widget child;
  final double maxWidth;

  /// 高さを子に合わせる。
  ///
  /// **画面下のバーに使うときは true。** 既定のままだと [Align] が
  /// 高さいっぱいに広がり、`bottomNavigationBar` が画面を占領して
  /// 本文が消える（テストで捕まえた）。
  final bool tight;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      heightFactor: tight ? 1.0 : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// いま横に広い画面か。**iPad かどうかではなく、幅で判断する。**
///
/// 端末の種類で分けると、iPhone の横向きや Android タブレット、
/// iPad の Split View を取りこぼす。
bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= 700;
