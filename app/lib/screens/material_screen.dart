import '../config/app_radius.dart';
import '../config/app_theme.dart';
import '../models/unit.dart';
import '../ui/_material.dart';
import '../widgets/emphasis_text.dart';

/// 教材を読む画面。**コア体験の1歩目。**
///
/// ## ここで何が起きるべきか
///
/// 読み終えたときに「このあと自分の言葉で説明する」と分かっていること（C1）。
/// だから最後のボタンは「次へ」ではなく **「デキすぎ君に教える」** で、
/// 読んでいる最中からその先が見えている必要がある。
///
/// ## 読み終わったら消える
///
/// 会話が始まったらこの画面は残さない（C2）。
/// 手元に置いたまま説明できると、想起ではなく音読になる。
/// 戻れないことは**先に伝える** — 不意に閉じられると裏切りになる。
class MaterialScreen extends StatefulWidget {
  const MaterialScreen({
    super.key,
    required this.unit,
    required this.onDone,
    this.focusConceptKey,
  });

  final UnitDetail unit;

  /// 読み終わった。会話へ進む
  final VoidCallback onDone;

  /// 復習から来たときに開く節。指定があればそこだけを出す
  final String? focusConceptKey;

  @override
  State<MaterialScreen> createState() => _MaterialScreenState();
}

class _MaterialScreenState extends State<MaterialScreen> {
  final _scroll = ScrollController();
  bool _reachedEnd = false;

  bool get _isReview => widget.focusConceptKey != null;

  List<Section> get _sections {
    final key = widget.focusConceptKey;
    if (key == null) return widget.unit.sections;
    final one = widget.unit.sectionFor(key);
    return one == null ? widget.unit.sections : [one];
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // 1画面で収まるときは最後まで来たものとして扱う。
    // **スクロールが起きないと永久に押せない**という詰まりを避ける
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  void _onScroll() {
    if (_reachedEnd || !_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.maxScrollExtent <= 0 || p.pixels >= p.maxScrollExtent - 120) {
      setState(() => _reachedEnd = true);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final sections = _sections;

    return Scaffold(
      appBar: AppBar(title: Text(widget.unit.title)),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (!_isReview) _Intro(unit: widget.unit),
          for (final s in sections) ...[
            const SizedBox(height: 20),
            _SectionView(section: s),
          ],
        ],
      ),
      // **操作はスクロールの外に置く。**
      // 中に入れると読み終わるまで組み立てられず、
      // 「押せるようになった」ことに気づけない
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: _isReview
              ? OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('もどる'),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _reachedEnd
                          ? 'ここからは教材を見ずに説明します。'
                          : '最後まで読むと、次へ進めます。',
                      style: t.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        // **読み終わるまで進ませない。** 押せてしまうと、
                        // 読まずに会話へ入って「説明できない」だけの体験になる
                        onPressed: _reachedEnd ? widget.onDone : null,
                        icon: const Icon(Icons.record_voice_over),
                        label: const Text('デキすぎ君に教える'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.unit});

  final UnitDetail unit;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final mins = (unit.readingTime.inSeconds / 60).ceil();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book, size: 20),
              const SizedBox(width: 8),
              Text('読んでから、教えます', style: t.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'このあと、読んだ内容をデキすぎ君に説明してもらいます。',
            style: t.textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          // **先に伝える。** 会話が始まってから消えると裏切りになる
          Text(
            '教材は、話しているあいだは見られません。',
            style: t.textTheme.bodyMedium?.jaWeight(FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text('読むのに およそ$mins分',
                  style: t.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionView extends StatelessWidget {
  const _SectionView({required this.section});

  final Section section;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final c = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(section.title, style: t.textTheme.titleMedium),
        const SizedBox(height: 10),
        for (final p in section.body)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            // 和文の行間は本文スタイル側で確保してある（M3 の 1.43 では足りない）
            child: EmphasisText(p, style: t.textTheme.bodyLarge),
          ),
        if (section.tryIt.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.highlightFlash,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.science_outlined,
                        size: 18, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text('やってみる',
                        style: t.textTheme.labelLarge
                            ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 6),
                EmphasisText(section.tryIt, style: t.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
