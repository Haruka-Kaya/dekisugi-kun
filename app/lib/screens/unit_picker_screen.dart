import '../config/app_radius.dart';
import '../models/unit.dart';
import '../services/units_client.dart';
import '../ui/_material.dart';
import '../widgets/readable_width.dart';

/// どの単元を教えるか選ぶ。
///
/// **何を説明することになるかを、選ぶ前に見せる。**
/// 「力と運動」とだけ書かれても、何を求められるのか分からない。
/// 概念のラベルを並べておくと、心の準備ができる。
class UnitPickerScreen extends StatefulWidget {
  const UnitPickerScreen({
    super.key,
    required this.units,
    required this.onPick,
    this.onOpenReview,
  });

  final UnitsClient units;

  /// 単元を選んだ
  final void Function(UnitDetail unit) onPick;

  final VoidCallback? onOpenReview;

  @override
  State<UnitPickerScreen> createState() => _UnitPickerScreenState();
}

class _UnitPickerScreenState extends State<UnitPickerScreen> {
  List<UnitSummary>? _list;
  String? _loadingId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await widget.units.list();
    if (!mounted) return;
    setState(() {
      _list = list;
      _error = list.isEmpty ? '単元を取ってこられませんでした。' : null;
    });
  }

  Future<void> _pick(UnitSummary summary) async {
    setState(() {
      _loadingId = summary.id;
      _error = null;
    });
    final detail = await widget.units.detail(summary.id);
    if (!mounted) return;
    setState(() => _loadingId = null);

    if (detail == null || detail.sections.isEmpty) {
      // **教材が無いまま会話へ入れない。** 読まずに説明させることになる
      setState(() => _error = '教材を読み込めませんでした。通信を確かめてもう一度どうぞ。');
      return;
    }
    widget.onPick(detail);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final list = _list;

    return Scaffold(
      appBar: AppBar(
        title: const Text('何を教える？'),
        actions: [
          if (widget.onOpenReview != null)
            IconButton(
              onPressed: widget.onOpenReview,
              icon: const Icon(Icons.bookmark_outline),
              tooltip: 'もう一度見るところ',
            ),
        ],
      ),
      body: list == null
          ? const Center(child: CircularProgressIndicator())
          // iPad は横に広い。カードを画面いっぱいに伸ばさない
          : ReadableWidth(
              child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                    16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
                children: [
                  if (_error != null) ...[
                    _ErrorNote(message: _error!, onRetry: _load),
                    const SizedBox(height: 12),
                  ],
                  for (final u in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _UnitCard(
                        unit: u,
                        busy: _loadingId == u.id,
                        // 別の単元を読み込んでいる間は押させない
                        onTap: _loadingId == null ? () => _pick(u) : null,
                      ),
                    ),
                  if (list.isEmpty && _error == null)
                    Text('単元がまだありません。', style: t.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({required this.unit, required this.busy, this.onTap});

  final UnitSummary unit;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(unit.title, style: t.textTheme.titleMedium)),
                  if (busy)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(unit.brief, style: t.textTheme.bodyMedium),
              if (unit.concepts.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('説明することになるのは',
                    style: t.textTheme.labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in unit.concepts)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(c.label, style: t.textTheme.bodySmall),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: t.textTheme.bodyMedium)),
          TextButton(onPressed: onRetry, child: const Text('やり直す')),
        ],
      ),
    );
  }
}
