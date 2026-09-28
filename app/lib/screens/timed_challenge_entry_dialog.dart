import '../config/app_language.dart' as lang;
import '../ui/_material.dart';

/// 任意Timedだけに結晶を使う前の、明示確認。
///
/// 価格は固定catalogから投影された値だけを受け取る。回答・正誤・速度は
/// 受け取らず、通常Pathや無料challengeの利用資格にも触れない。
Future<bool> confirmTimedChallengeEntry(
  BuildContext context, {
  required int gemCost,
}) async {
  if (gemCost <= 0) {
    throw ArgumentError.value(gemCost, 'gemCost', 'positive cost required');
  }
  final approved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const ValueKey('timed-entry-confirmation'),
      title: Text(lang.t('今日のタイム挑戦券', 'Today\'s timed challenge pass')),
      content: SingleChildScrollView(
        child: Text(
          lang.t(
                '結晶$gemCost個で、今日の学習日は何度でもタイムチャレンジへ参加できます。',
                'Spend $gemCost gems to join timed challenges as often as you like today.',
              ) +
              lang.t(
                'Path・XP・正答は購入できません。Match / Lightningは無料です。',
                ' You cannot buy Path progress, XP, or correct answers. Match and Lightning are free.',
              ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('timed-entry-cancel'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(lang.t('やめる', 'Cancel')),
        ),
        FilledButton(
          key: const ValueKey('timed-entry-confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(lang.t('結晶$gemCost個で参加', 'Join for $gemCost gems')),
        ),
      ],
    ),
  );
  return approved ?? false;
}
