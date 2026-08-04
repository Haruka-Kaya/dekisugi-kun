import '../config/app_radius.dart';
import '../config/app_theme.dart';
import '../models/review.dart';
import '../services/session_store.dart';
import '../ui/_material.dart';

/// 復習の画面。
///
/// **「弱点」と言わない**（C9）。誘発の判定は行動の観測でしかなく、
/// 聞き流しただけでも「訂正しなかった」に見える。
/// 出すのは「もう一度たしかめたいところ」までで、誤解していると断定しない。
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.store});

  final SessionStore store;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  List<ReviewItem>? _items;
  DateTime? _exam;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await widget.store.reviewItems();
    final exam = await widget.store.examDate();
    if (!mounted) return;
    setState(() {
      _items = items;
      _exam = exam;
    });
  }

  Future<void> _pickExamDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _exam ?? now.add(const Duration(days: 14)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: '次の定期考査はいつ？',
    );
    if (picked == null) return;
    await widget.store.setExamDate(picked);
    if (mounted) setState(() => _exam = picked);
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;

    return Scaffold(
      appBar: AppBar(title: const Text('もう一度見るところ')),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _ExamCard(exam: _exam, onTap: _pickExamDate),
                if (items.isEmpty)
                  const _Empty()
                else
                  for (final item in items)
                    _ReviewTile(
                      item: item,
                      exam: _exam,
                      onDone: () async {
                        await widget.store
                            .clearReview(item.unitId, item.conceptKey);
                        await _load();
                      },
                    ),
              ],
            ),
    );
  }
}

/// 考査日。**復習間隔をここから逆算する。**
class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.exam, required this.onTap});

  final DateTime? exam;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final days = exam?.difference(DateTime.now()).inDays;

    return Card(
      child: ListTile(
        leading: const Icon(Icons.event),
        title: Text(exam == null ? '次の考査日を決める' : '次の考査まで あと$days日'),
        subtitle: Text(
          exam == null
              ? '考査日が分かると、見直す間隔をそこから逆算できます。'
              : '${exam!.year}年${exam!.month}月${exam!.day}日',
          style: t.textTheme.bodySmall,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.check_circle_outline,
              size: 40, color: t.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('いまは見直すところがありません',
              style: t.textTheme.titleSmall, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('デキすぎ君に教えると、うまく説明しきれなかったところがここに残ります。',
              style: t.textTheme.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.item,
    required this.exam,
    required this.onDone,
  });

  final ReviewItem item;
  final DateTime? exam;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    final now = DateTime.now();

    // 理由で色を分ける。**どちらも「できていない」ではない**
    final status = item.reason == ReviewReason.notCorrected
        ? ExplainStatus.weak
        : ExplainStatus.shaky;
    final fg = c.fgFor(status);

    final gap = nextGap(now: now, examDate: exam, timesSeen: 0);
    final due = item.dueAt(gap);
    final ready = !due.isAfter(now);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 色だけで伝えない (SC 1.4.1)
                Icon(statusIcon(status), size: 18, color: fg),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item.label,
                      style: t.textTheme.titleSmall?.jaWeight(FontWeight.w600)),
                ),
                _DueChip(ready: ready, due: due),
              ],
            ),
            const SizedBox(height: 6),
            Text(item.reason.label,
                style: t.textTheme.bodyMedium?.copyWith(color: fg)),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: onDone,
                child: const Text('もう覚えた'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DueChip extends StatelessWidget {
  const _DueChip({required this.ready, required this.due});

  final bool ready;
  final DateTime due;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    final left = due.difference(DateTime.now()).inDays;
    final fg = ready ? c.gotItFg : c.untouchedFg;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ready ? c.gotItChip : c.untouchedChip,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        ready ? 'いま' : 'あと${left + 1}日',
        style: t.textTheme.bodySmall?.copyWith(color: fg, height: 1.0),
      ),
    );
  }
}
