import '../config/app_theme.dart';
import '../models/streak.dart';
import '../ui/_material.dart';

/// continuation の1行。**画面の主役にしない。**
///
/// 中核は「考査までに残っていること」と「チームの合計」で、
/// 連続日数はその下に小さく置く補助にすぎない。
/// Duolingo の streak 14日保持率は高校生年代が全年齢中最低（55%）で、
/// **狙っている層にだけ効かない**ことが分かっている。
///
/// > [!important] 猶予の残数は必ず出す
/// > Sharif & Shu 2021 が示したのは「使わずに済ませること自体が動機になる」
/// > という働き。残っていることが見えていなければ機能しない。
class StreakLine extends StatelessWidget {
  const StreakLine({super.key, required this.streak});

  final StreakView streak;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 360 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _days(t, c),
                    const SizedBox(height: 6),
                    _Grace(left: streak.graceLeft, total: streak.graceTotal),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: _days(t, c)),
                    _Grace(left: streak.graceLeft, total: streak.graceTotal),
                  ],
                ),
        );
      },
    );
  }

  Widget _days(ThemeData t, AppColors c) {
    // **数字を煽らない。** 0 のときに「0日」と出すと、
    // 始める前から失点しているように見える
    final text = switch ((streak.days, streak.restDay)) {
      (_, true) => 'きょうは考査の前。休んでいい日です',
      (0, _) => 'きょう1件やると、ここに日数が出ます',
      (final n, _) when streak.doneToday => '$n日つづけて説明できています',
      (final n, _) => '$n日つづいています。きょうはこれから',
    };
    return Text(
      text,
      style: t.textTheme.bodySmall?.copyWith(
        color: c.fgFor(ExplainStatus.untouched),
      ),
    );
  }
}

/// 猶予の残り。シールドやアイテムの見た目にせず、予定の情報として出す。
class _Grace extends StatelessWidget {
  const _Grace({required this.left, required this.total});

  final int left;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: '今週の猶予',
      value: '$total日中 $left日のこり',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_available, size: 15, color: scheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            '今週の猶予 あと$left日',
            style: t.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
