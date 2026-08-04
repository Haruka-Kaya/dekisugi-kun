import 'dart:collection';

/// ディレクター（サーバ側の進行役）からの指示を、AI が黙っている間だけ流す。
///
/// ## なぜ即座に送らないのか
///
/// `jiyu-kenkyu-ai` の実測で、**AI が喋っている最中に注入すると質問が捨てられる**。
/// 発話の生成中に新しい入力が来ると、モデルは進行中のターンを打ち切って
/// 新しい方に応答し、直前に組み立てていた問いかけが消える。
///
/// なので「いま静かか」を外から教えてもらい、静かなときにだけ吐き出す。
///
/// ## なぜ待たせても壊れないのか
///
/// ディレクターは会話の**次の一手**を指示するもので、いま喋っている内容への
/// 割り込みではない。1ターン遅れて届いても意味が変わらない。
class DirectorQueue {
  DirectorQueue({this.prefix = '[DIRECTOR]', this.maxPending = 3});

  /// この接頭辞が付いた文字列は「読み上げずに自分の言葉へ変換する」よう
  /// システム指示で教えてある。接頭辞を変えるならシステム指示も同時に変える。
  final String prefix;

  /// 溜め込みの上限。溢れたら**古い方を捨てる**。
  /// 進行の指示は鮮度がすべてで、古い指示を後から実行させると会話が巻き戻る。
  final int maxPending;

  final Queue<String> _pending = Queue<String>();

  int get pendingCount => _pending.length;
  bool get hasPending => _pending.isNotEmpty;

  /// 指示を積む。捨てられた古い指示があれば返す（ログ用）。
  String? add(String instruction) {
    final text = instruction.trim();
    if (text.isEmpty) return null;
    _pending.add(text);
    if (_pending.length > maxPending) return _pending.removeFirst();
    return null;
  }

  /// 静かなら次の1件を接頭辞付きで返す。喋っている間は null。
  ///
  /// **1回に1件しか出さない。** まとめて送るとモデルが1つの発話に混ぜてしまい、
  /// 誤概念の誘発と質問が同じターンに乗って観測が濁る。
  String? takeIfQuiet(bool quiet) {
    if (!quiet || _pending.isEmpty) return null;
    return '$prefix ${_pending.removeFirst()}';
  }

  void clear() => _pending.clear();
}
