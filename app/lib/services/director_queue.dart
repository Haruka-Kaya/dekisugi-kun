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
  DirectorQueue({this.maxPending = 3});

  /// この接頭辞が付いた文字列は「読み上げずに自分の言葉へ変換する」よう
  /// システム指示で教えてある。
  ///
  /// **サーバがセッションごとに決める。** 固定の `[DIRECTOR]` にしていたとき、
  /// 生徒がそのまま打てばディレクターを騙れた。同じ文字列がシステム指示にも
  /// 入っているので、**ここだけ変えても効かない**（両方サーバが配る）。
  String prefix = '[DIRECTOR]';

  /// 溜め込みの上限。溢れたら**古い方を捨てる**。
  /// 進行の指示は鮮度がすべてで、古い指示を後から実行させると会話が巻き戻る。
  final int maxPending;

  final Queue<_DirectorInstruction> _pending = Queue<_DirectorInstruction>();

  /// 直前に[takeIfQuiet]で取り出した指示が誤概念の誘発なら、そのID。
  ///
  /// 指示を積んだ時点ではなく、Liveへ実際に送った時点から次のAI発話を
  /// 追跡するために使う。queue待ち中の別発話を誤って紐づけない。
  String? get lastTakenChallengeLureId => _lastTakenChallengeLureId;
  String? _lastTakenChallengeLureId;
  String? get lastTakenChallengeLureText => _lastTakenChallengeLureText;
  String? _lastTakenChallengeLureText;

  int get pendingCount => _pending.length;
  bool get hasPending => _pending.isNotEmpty;

  /// 指示を積む。捨てられた古い指示があれば返す（ログ用）。
  String? add(
    String instruction, {
    String? challengeLureId,
    String? challengeLureText,
  }) {
    final text = instruction.trim();
    if (text.isEmpty) return null;
    _pending.add(
      _DirectorInstruction(
        text: text,
        challengeLureId: challengeLureId,
        challengeLureText: challengeLureText,
      ),
    );
    if (_pending.length > maxPending) return _pending.removeFirst().text;
    return null;
  }

  /// 静かなら次の1件を接頭辞付きで返す。喋っている間は null。
  ///
  /// **1回に1件しか出さない。** まとめて送るとモデルが1つの発話に混ぜてしまい、
  /// 誤概念の誘発と質問が同じターンに乗って観測が濁る。
  String? takeIfQuiet(bool quiet) {
    if (!quiet || _pending.isEmpty) return null;
    final next = _pending.removeFirst();
    _lastTakenChallengeLureId = next.challengeLureId;
    _lastTakenChallengeLureText = next.challengeLureText;
    return '$prefix ${next.text}';
  }

  void clear() {
    _pending.clear();
    _lastTakenChallengeLureId = null;
    _lastTakenChallengeLureText = null;
  }
}

class _DirectorInstruction {
  const _DirectorInstruction({
    required this.text,
    this.challengeLureId,
    this.challengeLureText,
  });

  final String text;
  final String? challengeLureId;
  final String? challengeLureText;
}
