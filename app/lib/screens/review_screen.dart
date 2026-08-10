import '../config/app_radius.dart';
import '../config/app_theme.dart';
import '../models/review.dart';
import '../services/session_store.dart';
import '../services/units_client.dart';
import '../ui/_material.dart';
import '../ui/adaptive.dart';
import '../widgets/readable_width.dart';
import '../widgets/studio_ui.dart';
import 'material_screen.dart';

/// 復習の画面。
///
/// **「弱点」と言わない**（C9）。誘発の判定は行動の観測でしかなく、
/// 聞き流しただけでも「訂正しなかった」に見える。
/// 出すのは「もう一度たしかめたいところ」までで、誤解していると断定しない。
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.store, this.units});

  final SessionStore store;

  /// 教材の取り出し口。**あると「読み直す」が押せる。**
  ///
  /// 無いと、どこを見直すかは出せても**見直す中身が出せない**。
  /// 通信が無くても保存したぶんは読めるので、電車の中でも開ける。
  final UnitsClient? units;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  List<ReviewItem>? _items;
  DateTime? _exam;
  String? _readingKey;

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
    final picked = await pickDate(
      context,
      initial: _exam ?? now.add(const Duration(days: 14)),
      first: now,
      last: now.add(const Duration(days: 365)),
      helpText: '次の定期考査はいつ？',
    );
    if (picked == null) return;
    await widget.store.setExamDate(picked);
    if (mounted) setState(() => _exam = picked);
  }

  /// その概念の教材を開く。
  ///
  /// **保存したものを先に見る。** 通信を待たせると、
  /// 電車の中で開いたときに読めないまま終わる。
  Future<void> _read(ReviewItem item) async {
    if (_readingKey != null) return;
    final units = widget.units;
    if (units == null) return;
    final key = '${item.unitId}/${item.conceptKey}';
    setState(() => _readingKey = key);
    try {
      var unit = await units.cachedDetail(item.unitId);
      unit ??= await units.detail(item.unitId);
      if (!mounted) return;

      final section = unit?.sectionFor(item.conceptKey);
      if (unit == null || section == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('この教材をまだ読み込めていません。')));
        return;
      }
      final reviewed = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => MaterialScreen(
            unit: unit!,
            focusConceptKey: item.conceptKey,
            // **読み直すだけ。** ここから会話へは進ませない
            review: true,
            onDone: (_) {},
          ),
        ),
      );
      if (reviewed != true) return;
      // 明示的に最後まで読んだときだけ、次の間隔を伸ばす。
      // システムBackや上部の「もどる」は未完了なので数えない。
      await widget.store.markReviewed(item.unitId, item.conceptKey);
      await _load();
    } finally {
      if (mounted) setState(() => _readingKey = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final now = DateTime.now();
    final ready = items
        ?.where((item) => _isReady(item, now: now, exam: _exam))
        .toList();
    final later = items
        ?.where((item) => !_isReady(item, now: now, exam: _exam))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('次の話')),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ReadableWidth(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    18,
                    8,
                    18,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    const StudioPageIntro(
                      eyebrow: 'NEXT TALK  ·  次の話',
                      title: '次に話すことを、\nひとつずつ整える。',
                      body:
                          '戻るための復習ではなく、'
                          'デキすぎ君にもう一度話すための準備です。',
                    ),
                    const SizedBox(height: 22),
                    _ExamPlan(exam: _exam, onTap: _pickExamDate),
                    const SizedBox(height: 32),
                    if (items.isEmpty)
                      const _Empty()
                    else ...[
                      if (ready!.isNotEmpty) ...[
                        const StudioSectionHeader(
                          title: 'いま整える話',
                          description: '上から1つ。読み直したら、次に話す準備が進みます。',
                          leading: Icon(Icons.record_voice_over_outlined),
                        ),
                        const SizedBox(height: 14),
                        for (final item in ready) ...[
                          _ForwardStep(
                            item: item,
                            exam: _exam,
                            readAvailable: widget.units != null,
                            reading:
                                _readingKey ==
                                '${item.unitId}/${item.conceptKey}',
                            onRead: widget.units == null || _readingKey != null
                                ? null
                                : () => _read(item),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                      if (later!.isNotEmpty) ...[
                        if (ready.isNotEmpty) const SizedBox(height: 22),
                        const StudioSectionHeader(
                          title: 'この先に話すこと',
                          description: '忘れる前に、もう一度話す日を残しています。',
                          leading: Icon(Icons.calendar_month_outlined),
                        ),
                        const SizedBox(height: 14),
                        for (final item in later) ...[
                          _ForwardStep(
                            item: item,
                            exam: _exam,
                            readAvailable: widget.units != null,
                            reading:
                                _readingKey ==
                                '${item.unitId}/${item.conceptKey}',
                            onRead: widget.units == null || _readingKey != null
                                ? null
                                : () => _read(item),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

bool _isReady(ReviewItem item, {required DateTime now, DateTime? exam}) {
  final gap = nextGap(now: now, examDate: exam, timesSeen: item.timesSeen);
  return !item.dueAt(gap).isAfter(now);
}

/// 考査日は「設定」ではなく、次に話す順番を作る手がかりとして置く。
class _ExamPlan extends StatelessWidget {
  const _ExamPlan({required this.exam, required this.onTap});

  final DateTime? exam;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final days = exam == null
        ? null
        : DateUtils.dateOnly(exam!).difference(today).inDays;

    return StudioActionTile(
      icon: Icons.event_outlined,
      title: exam == null
          ? '考査日から、話す順番をつくる'
          : days! < 0
          ? '次の考査日を入れ直す'
          : days == 0
          ? 'きょうが考査日'
          : '考査まで あと$days日',
      description: exam == null
          ? '日付を入れると、もう一度話す日を逆算します。'
          : days! < 0
          ? '前の考査日は${exam!.year}年${exam!.month}月${exam!.day}日でした。'
          : '${exam!.year}年${exam!.month}月${exam!.day}日に向けた順番です。',
      onTap: onTap,
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      decoration: BoxDecoration(
        color: c.coolSurface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.forum_outlined, size: 28, color: c.onCoolSurface),
          const SizedBox(height: 16),
          Text(
            'いま、整えておく話はありません。',
            style: t.textTheme.titleLarge
                ?.copyWith(color: c.onCoolSurface)
                .jaWeight(FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '次に教えたいテーマをホームから選ぶと、'
            'デキすぎ君との次の話が始まります。',
            style: t.textTheme.bodyMedium?.copyWith(color: c.onCoolSurface),
          ),
        ],
      ),
    );
  }
}

class _ForwardStep extends StatelessWidget {
  const _ForwardStep({
    required this.item,
    required this.exam,
    required this.readAvailable,
    required this.reading,
    this.onRead,
  });

  final ReviewItem item;
  final DateTime? exam;
  final bool readAvailable;
  final bool reading;

  /// 教材を読み直す。取り出せないときは null（ボタンを出さない）
  final VoidCallback? onRead;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    final now = DateTime.now();
    final status = item.reason == ReviewReason.notCorrected
        ? ExplainStatus.weak
        : ExplainStatus.shaky;
    final gap = nextGap(now: now, examDate: exam, timesSeen: item.timesSeen);
    final due = item.dueAt(gap);
    final ready = !due.isAfter(now);
    final background = ready ? c.warmSurface : c.coolSurface;
    final foreground = ready ? c.onWarmSurface : c.onCoolSurface;

    return Semantics(
      container: true,
      label:
          '${item.label}。${item.reason.label}。'
          '${ready ? 'いま準備するテーマ' : 'この先に準備するテーマ'}。',
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
        child: Column(
          key: ValueKey('review-${item.unitId}-${item.conceptKey}'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DueChip(ready: ready, due: due),
                _ReasonChip(reason: item.reason, status: status),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              item.label,
              style: t.textTheme.headlineSmall
                  ?.copyWith(color: foreground, height: 1.4)
                  .jaWeight(FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              ready ? '次に話す前に、ここだけ読み直します。' : '次に話す日のために、ここへ残しています。',
              style: t.textTheme.bodyMedium?.copyWith(color: foreground),
            ),
            const SizedBox(height: 18),
            if (!readAvailable)
              Text(
                '教材を読み込むと、ここから準備できます。',
                style: t.textTheme.bodySmall?.copyWith(color: foreground),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onRead,
                  child: Text(
                    reading ? '教材を開いています…' : '次に話す前に読む',
                    textAlign: TextAlign.center,
                  ),
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
        ready ? 'いま整える' : 'あと${left + 1}日',
        style: t.textTheme.bodySmall?.copyWith(color: fg, height: 1.0),
      ),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.reason, required this.status});

  final ReviewReason reason;
  final ExplainStatus status;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    final foreground = c.fgFor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.chipFor(status),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon(status), size: 16, color: foreground),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              reason.label,
              style: t.textTheme.bodySmall?.copyWith(
                color: foreground,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
