import '../config/app_language.dart' as lang;
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
            lang.t('あと$left回', '$left left'),
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
                  lang.t('きょうのぶんは終わりです', "That's it for today"),
                  style: t.textTheme.titleSmall
                      ?.copyWith(color: c.onCoolSurface)
                      .jaWeight(FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            lang.t(
              '無料で話せるのは1日2回までです。1回はおよそ10分です。'
                  '${_resetText(resetsAt)}に、またいちから話せるようになります。',
              'Free talks are limited to 2 a day, about 10 minutes each. '
                  'You can talk again ${_resetText(resetsAt)}.',
            ),
            style: t.textTheme.bodyMedium?.copyWith(color: c.onCoolSurface),
          ),
          const SizedBox(height: 12),
          Text(
            lang.t(
              '待っているあいだは、「もう一度見るところ」で'
                  'うまく説明しきれなかったところを見直せます。',
              'While you wait, use "Review spots" to '
                  'go over what you could not fully explain.',
            ),
            style: t.textTheme.bodySmall?.copyWith(
              color: c.onCoolSurface.withValues(alpha: 0.82),
            ),
          ),
          if (onOpenPlus != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: plusBusy ? null : onOpenPlus,
              child: Text(
                plusBusy
                    ? lang.t('Plusを確認しています…', 'Checking Plus…')
                    : lang.t('Plusで会話回数を広げる', 'Get more talks with Plus'),
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
    if (at == null) return lang.t('日付が変わったころ', 'after midnight');
    final local = at.toLocal();
    final now = DateTime.now();
    final sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final h = local.hour.toString();
    return sameDay
        ? lang.t('きょうの$h時ごろ', 'today around $h:00')
        : lang.t('あすの$h時ごろ', 'tomorrow around $h:00');
  }
}
