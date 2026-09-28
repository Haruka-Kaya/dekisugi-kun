import '../config/app_radius.dart';
import '../config/app_theme.dart';
import '../services/live_session.dart';
import '../ui/_material.dart';

/// 今日あと何回話せるか。
///
/// **残りが減ってから知らせない。** 会話の途中で急に切れると、
/// 生徒には何が起きたか分からない。最初から見えるところに出しておく。
class QuotaChip extends StatelessWidget {
  const QuotaChip({super.key, required this.live});

  final LiveSessionController live;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    final left = live.remainingSessions;

    // 課金済み（上限なし）か、まだ分からないときは出さない
    if (left == null) return const SizedBox.shrink();

    final low = left <= 1;
    final fg = low ? c.shakyFg : c.untouchedFg;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: low ? c.shakyChip : c.untouchedChip,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 色だけで伝えない (SC 1.4.1)
          Icon(
            low ? Icons.hourglass_bottom : Icons.schedule,
            size: 16,
            color: fg,
          ),
          const SizedBox(width: 4),
          Text(
            'あと$left回',
            style: t.textTheme.bodySmall?.copyWith(color: fg, height: 1.0),
          ),
        ],
      ),
    );
  }
}

/// 今日の無料ぶんを使い切ったときの案内。
///
/// **エラーの顔をさせない。** 使い切るのは仕様どおりに起きることで、
/// 生徒が何か間違えたわけではない。
class OutOfTimeCard extends StatelessWidget {
  const OutOfTimeCard({
    super.key,
    required this.resetsAt,
    this.onOpenPlus,
    this.plusBusy = false,
  });

  final DateTime? resetsAt;
  final VoidCallback? onOpenPlus;
  final bool plusBusy;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.coolSurface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.schedule, size: 20, color: c.onCoolSurface),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'きょうのぶんは終わりです',
                  style: t.textTheme.titleSmall
                      ?.copyWith(color: c.onCoolSurface)
                      .jaWeight(FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '無料で話せるのは1日2回までです。1回はおよそ10分です。'
            '${_resetText(resetsAt)}に、またいちから話せるようになります。',
            style: t.textTheme.bodyMedium?.copyWith(color: c.onCoolSurface),
          ),
          const SizedBox(height: 12),
          Text(
            '待っているあいだは、「もう一度見るところ」で'
            'うまく説明しきれなかったところを見直せます。',
            style: t.textTheme.bodySmall?.copyWith(
              color: c.onCoolSurface.withValues(alpha: 0.82),
            ),
          ),
          if (onOpenPlus != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: plusBusy ? null : onOpenPlus,
              child: Text(
                plusBusy ? 'Plusを確認しています…' : 'Plusで会話回数を広げる',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// いつ戻るか。**「明日」で済ませない** — 夜中に使う子には today/tomorrow が紛らわしい。
  static String _resetText(DateTime? at) {
    if (at == null) return '日付が変わったころ';
    final local = at.toLocal();
    final now = DateTime.now();
    final sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final h = local.hour.toString();
    return sameDay ? 'きょうの$h時ごろ' : 'あすの$h時ごろ';
  }
}
