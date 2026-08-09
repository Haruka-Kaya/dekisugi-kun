import 'dart:async';

import '../config/app_radius.dart';
import '../config/app_theme.dart';
import '../models/exam_plan.dart';
import '../models/reminder.dart';
import '../models/streak.dart';
import '../models/team.dart';
import '../models/unit.dart';
import '../services/session_store.dart';
import '../services/reminders.dart';
import '../services/team_client.dart';
import '../services/units_client.dart';
import '../services/live_session.dart';
import '../ui/_material.dart';
import '../ui/adaptive.dart';
import '../widgets/character.dart';
import '../widgets/readable_width.dart';
import 'settings_screen.dart';
import 'team_join_screen.dart';
import '../widgets/streak_line.dart';
import '../widgets/team_card.dart';

/// ホーム。**並び順が優先順位の宣言そのもの。**
///
/// 1. 考査までの日数と残っている概念の数（数字だが**残作業**であって報酬ではない）
/// 2. きょうの1件（主 CTA）
/// 3. 言えるようになったこと（**報酬の本体**）
/// 4. もう一度見るところ
/// 5. 継続日数と猶予（**小さく、最下部**）
///
/// この順序を変えるときは根拠から見直すこと。
/// streak を上に出すと、狙っている層（Duolingo の14日保持率が全年齢中最低の
/// 高校生年代）に最も効かないものを主役に据えることになる。
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.store,
    required this.units,
    this.team,
    this.reminders,
    required this.onStart,
    required this.onOpenReview,
    required this.onPickUnit,
  });

  final SessionStore store;
  final UnitsClient units;

  /// クラスの合計。**無くてもアプリは成立する**（付随物なので）
  final TeamClient? team;

  /// まいにちの声かけ。これも付随物
  final Reminders? reminders;

  /// きょうの1件を始める。単元IDと、どの概念に焦点を当てるか
  final void Function(UnitSummary unit, String conceptKey) onStart;

  final VoidCallback onOpenReview;

  /// ほかの単元を選ぶ
  final VoidCallback onPickUnit;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ExamPlan? _plan;
  StreakView? _streak;
  List<ExplainedItem> _said = const [];
  List<UnitSummary> _units = const [];
  TeamSummary? _team;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // `list()` は取れなければ保存したものを返す。
    // 通信が無くても電車の中で開ける
    final units = await widget.units.list();

    final reviews = await widget.store.reviewItems();
    final exam = await widget.store.examDate();
    final days = await widget.store.days();
    final said = await widget.store.explained();

    if (!mounted) return;
    final now = DateTime.now();
    setState(() {
      _units = units;
      _said = said;
      _plan = buildExamPlan(
        now: now,
        examDate: exam,
        units: units,
        reviews: reviews,
        explainedKeys: {for (final e in said) '${e.unitId}/${e.conceptKey}'},
      );
      // **連続日数は保存しない。** 毎回ここで数える
      _streak = computeStreak(records: days, now: now, examDate: exam);
      _loading = false;
    });

    // クラスは付随物。**待たせない。取れなければ出さないだけ**
    unawaited(_loadTeam());
    // 文面は状態で変わるので、開くたびに次の1件を立て直す
    unawaited(_rescheduleReminder());
  }

  /// 次の声かけを立て直す。**失敗しても何も止めない。**
  Future<void> _rescheduleReminder() async {
    final r = widget.reminders;
    final plan = _plan;
    final streak = _streak;
    if (r == null || plan == null || streak == null) return;
    await r.reschedule(
      ReminderState(
        daysLeft: plan.daysLeft,
        remaining: plan.remaining,
        dueCount: plan.due.length,
        graceLeft: streak.graceLeft,
        doneToday: streak.doneToday,
        restDay: streak.restDay,
      ),
    );
  }

  /// クラスの合計を後から足す。会話も画面も止めない。
  Future<void> _loadTeam() async {
    final client = widget.team;
    if (client == null) return;
    // 冪等なので、いつ何度送ってもよい
    await client.syncContributions();
    final s = await client.summary();
    if (mounted) setState(() => _team = s);
  }

  Future<void> _openTeam() async {
    final client = widget.team;
    if (client == null) return;
    if (_team == null) {
      final joined = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => TeamJoinScreen(client: client)),
      );
      if (joined == true) await _loadTeam();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('クラスから抜けますか？'),
        content: const Text(
          'いままでの分はクラスの合計に残りますが、'
          'あなたの記録は消えます。\n\n'
          '入り直せるのは1週間後です。'
          '同じ日をもう一度数えられないようにするためです。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('クラスに残る'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('クラスから抜ける'),
          ),
        ],
      ),
    );
    if (leave != true) return;
    await client.leave();
    if (mounted) setState(() => _team = null);
  }

  Future<void> _pickExamDate() async {
    final now = DateTime.now();
    final picked = await pickDate(
      context,
      initial: _plan?.examDate ?? now.add(const Duration(days: 14)),
      first: now,
      last: now.add(const Duration(days: 365)),
      helpText: '次の定期考査はいつ？',
    );
    if (picked == null) return;
    await widget.store.setExamDate(picked);
    await _load();
  }

  void _startToday() {
    final task = _plan?.today;
    if (task == null) return;
    final matches = _units.where((u) => u.id == task.unitId);
    if (matches.isEmpty) return;
    widget.onStart(matches.first, task.conceptKey);
  }

  Future<void> _openSettings() async {
    final r = widget.reminders;
    if (r == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SettingsScreen(reminders: r)),
    );
    await _rescheduleReminder();
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    if (_loading || plan == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'デキすぎ君',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.jaWeight(FontWeight.w700),
        ),
        actions: [
          if (widget.reminders != null)
            IconButton(
              tooltip: '設定',
              onPressed: _openSettings,
              icon: const Icon(Icons.tune),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ReadableWidth(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              12,
              12,
              12,
              12 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              _CompanionIntro(plan: plan),
              const SizedBox(height: 8),
              _TodayCard(plan: plan, onStart: _startToday),
              const SizedBox(height: 8),
              _ExamCard(plan: plan, onTap: _pickExamDate),
              const SizedBox(height: 24),
              _SaidItList(items: _said),
              const SizedBox(height: 24),
              Text(
                'ほかにできること',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.jaWeight(FontWeight.w700),
              ),
              const SizedBox(height: 6),
              _RowLink(
                icon: Icons.replay,
                label: 'もう一度見るところ',
                description: plan.due.isEmpty
                    ? 'いま見直すものはありません'
                    : '${plan.due.length}件を、忘れる前に見直す',
                onTap: () async {
                  widget.onOpenReview();
                  await _load();
                },
              ),
              _RowLink(
                icon: Icons.auto_stories_outlined,
                label: '教えるテーマを選ぶ',
                description: 'ほかの単元から、自分で選んで始める',
                onTap: widget.onPickUnit,
              ),
              if (_team case final s?) ...[
                const SizedBox(height: 18),
                TeamCard(summary: s, onLeave: _openTeam),
              ] else if (widget.team != null)
                _RowLink(
                  icon: Icons.groups_outlined,
                  label: 'クラスに入る',
                  description: '誰かと競わず、クラス全体の説明を集める',
                  onTap: _openTeam,
                ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              // **継続は最下部に小さく。** 主役にしない
              if (_streak case final s?) StreakLine(streak: s),
            ],
          ),
        ),
      ),
    );
  }
}

/// 数字やメニューより先に、デキすぎ君との関係を見せる。
///
/// ホームを「管理画面」ではなく「話を聞いてくれる相手のいる場所」にする。
/// キャラクターは待機状態なので常時アニメーションさせない。
class _CompanionIntro extends StatelessWidget {
  const _CompanionIntro({required this.plan});

  final ExamPlan plan;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final task = plan.today;

    return Semantics(
      container: true,
      label: task == null
          ? 'デキすぎ君。きょうの分は聞けました。また話そう。'
          : 'デキすぎ君。きょうは${task.label}の話を聞かせて。',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Character(state: LiveState.idle, size: 84),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'こんにちは。',
                      style: t.textTheme.labelLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task == null
                          ? 'きょうの分は聞けました。\nまた話そう。'
                          : 'きょうは「${task.label}」の話を聞かせて。',
                      style: t.textTheme.titleLarge?.jaWeight(FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 考査までの日数と、残っている概念の数。
///
/// **数字を出すが報酬ではない。** 残っている作業の量であって、
/// 貯めるものではない（C5）。
class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.plan, required this.onTap});

  final ExamPlan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final left = plan.daysLeft;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.calendar_today_outlined,
                  size: 19,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      left == null
                          ? '次の考査日を入れると、そこから逆算します'
                          : left <= 0
                          ? 'きょうが考査日'
                          : '考査まで あと$left日',
                      style: t.textTheme.titleSmall?.jaWeight(FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.remaining == 0
                          ? '説明していないところはありません'
                          : 'まだ説明していないところが ${plan.remaining} つ',
                      style: t.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// きょうの1件。**主 CTA。**
///
/// 連続日数の成立条件もこれと同じ1件。定義を画面と記録で揃えておかないと
/// 「やったのに連続が付かない」が起きる。
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.plan, required this.onStart});

  final ExamPlan plan;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final task = plan.today;

    if (task == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'きょうの分は終わっています',
                style: t.textTheme.titleMedium?.jaWeight(FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'また明日、忘れかけたころに出します。',
                style: t.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      color: scheme.primaryContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 色だけで区別しない (SC 1.4.1)
                Icon(
                  task.isReview ? Icons.replay : Icons.auto_stories_outlined,
                  size: 18,
                  color: scheme.onPrimaryContainer,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    task.isReview ? 'もう一度たしかめる' : 'きょうはこれを説明する',
                    style: t.textTheme.labelLarge?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              task.label,
              style: t.textTheme.headlineSmall
                  ?.copyWith(color: scheme.onPrimaryContainer)
                  .jaWeight(FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '教材を読む  →  自分の言葉で教える',
              style: t.textTheme.bodySmall?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('教材を読む'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 言えるようになったこと。**報酬の本体**（C5）。
///
/// 積み上がるのがポイントではなく**自分が言った文**なので、
/// 既存のループ（教える）に直結し、外的報酬として働かない。
class _SaidItList extends StatelessWidget {
  const _SaidItList({required this.items});

  final List<ExplainedItem> items;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.format_quote, size: 20, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '言えるようになったこと',
                style: t.textTheme.titleMedium?.jaWeight(FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'ここに残るのは、点数ではなくあなた自身の言葉です。',
          style: t.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Text('最初の説明が、ここにそのまま残ります。', style: t.textTheme.bodyMedium),
          )
        else
          for (final (index, e) in items.take(5).indexed) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.label,
                    style: t.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 3),
                  // **生徒自身の言葉が主役。** ここを要約に置き換えない
                  Text(
                    '「${e.said}」',
                    style: t.textTheme.bodyLarge?.jaWeight(FontWeight.w500),
                  ),
                ],
              ),
            ),
            if (index < items.take(5).length - 1) const Divider(),
          ],
        if (items.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'ほか ${items.length - 5} 件',
              style: t.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _RowLink extends StatelessWidget {
  const _RowLink({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      // 主要操作は 48dp 以上
      minTileHeight: 64,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, size: 20, color: scheme.onSurfaceVariant),
      ),
      title: Text(label),
      subtitle: Text(description),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
