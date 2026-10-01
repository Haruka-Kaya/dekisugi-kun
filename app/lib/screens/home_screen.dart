import 'dart:async';

import '../config/app_language.dart' as l10n;
import '../config/app_radius.dart';
import '../config/app_theme.dart';
import '../models/exam_plan.dart';
import '../models/mission.dart';
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
import '../widgets/studio_ui.dart';
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
    this.onOpenPlus,
    this.routeObserver,
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

  /// RevenueCat がこのビルドで有効な場合だけ渡す。未設定ビルドでは、
  /// 購入できない架空の導線を出さない。
  final Future<void> Function()? onOpenPlus;

  /// 会話・復習・設定から戻った瞬間に、端末の最新記録を読み直す。
  /// テストや単独利用では省略できる。
  final RouteObserver<ModalRoute<void>>? routeObserver;

  /// きょうの1件を始める。単元IDと、どの概念に焦点を当てるか
  final Future<void> Function(
    UnitSummary unit,
    String conceptKey,
    MissionKind missionKind,
  )
  onStart;

  final VoidCallback onOpenReview;

  /// ほかの単元を選ぶ
  final VoidCallback onPickUnit;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  ExamPlan? _plan;
  StreakView? _streak;
  List<ExplainedItem> _said = const [];
  List<UnitSummary> _units = const [];
  TeamSummary? _team;
  bool _loading = true;
  bool _openingToday = false;
  bool _openingReview = false;
  bool _openingPicker = false;
  bool _openingPlus = false;
  RouteObserver<ModalRoute<void>>? _subscribedObserver;
  ModalRoute<void>? _subscribedRoute;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscribeToRoute();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.routeObserver != widget.routeObserver) _subscribeToRoute();
  }

  void _subscribeToRoute() {
    final observer = widget.routeObserver;
    final route = ModalRoute.of<void>(context);
    if (identical(observer, _subscribedObserver) &&
        identical(route, _subscribedRoute)) {
      return;
    }
    if (_subscribedObserver != null && _subscribedRoute != null) {
      _subscribedObserver!.unsubscribe(this);
    }
    _subscribedObserver = observer;
    _subscribedRoute = route;
    if (observer != null && route != null) observer.subscribe(this, route);
  }

  @override
  void didPopNext() {
    // ホームの上にあった画面が閉じた。会話完了で保存された本人の説明や、
    // 復習・考査日の変更を手動更新なしで反映する
    unawaited(_load());
  }

  @override
  void dispose() {
    if (_subscribedObserver != null && _subscribedRoute != null) {
      _subscribedObserver!.unsubscribe(this);
    }
    super.dispose();
  }

  Future<void> _load() async {
    // `list()` は取れなければ保存したものを返す。
    // 通信が無くても電車の中で開ける
    final units = await widget.units.list();

    final reviews = await widget.store.reviewItems();
    final exam = await widget.store.examDate();
    final days = await widget.store.days();
    final said = await widget.store.explained();
    final progress = await widget.store.conceptProgress();

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
        progress: progress,
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
        dueCount: plan.due.length + plan.pathDue.length,
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
        title: Text(l10n.t('クラスから抜けますか？', 'Leave the class?')),
        content: Text(
          l10n.t(
            'いままでの分はクラスの合計に残りますが、'
                'あなたの記録は消えます。\n\n'
                '入り直せるのは1週間後です。'
                '同じ日をもう一度数えられないようにするためです。',
            'What you\'ve done so far stays in the class total, '
                'but your own record will be deleted.\n\n'
                'You can rejoin after one week. '
                'This keeps the same day from being counted twice.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.t('クラスに残る', 'Stay in class')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.t('クラスから抜ける', 'Leave class')),
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
      helpText: l10n.t('次の定期考査はいつ？', 'When is your next exam?'),
    );
    if (picked == null) return;
    await widget.store.setExamDate(picked);
    await _load();
  }

  Future<void> _startToday() async {
    if (_openingToday) return;
    final task = _plan?.today;
    if (task == null) return;
    final matches = _units.where((u) => u.id == task.unitId);
    if (matches.isEmpty) return;
    setState(() => _openingToday = true);
    try {
      await widget.onStart(matches.first, task.conceptKey, task.missionKind);
    } finally {
      if (mounted) setState(() => _openingToday = false);
    }
  }

  void _openReviewOnce() {
    if (_openingReview) return;
    _openingReview = true;
    widget.onOpenReview();
    // push は同期的に始まる。次のフレームまでは同じタイルからの二重 push を
    // 拒み、その後は新しい route が入力を受け取る。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openingReview = false;
    });
    unawaited(_load());
  }

  void _openPickerOnce() {
    if (_openingPicker) return;
    _openingPicker = true;
    widget.onPickUnit();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openingPicker = false;
    });
  }

  Future<void> _openPlusOnce() async {
    final open = widget.onOpenPlus;
    if (open == null || _openingPlus) return;
    setState(() => _openingPlus = true);
    try {
      await open();
    } finally {
      if (mounted) setState(() => _openingPlus = false);
    }
  }

  Future<void> _openSettings() async {
    final r = widget.reminders;
    if (r == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          reminders: r,
          onOpenPlus: widget.onOpenPlus == null ? null : _openPlusOnce,
        ),
      ),
    );
    await _rescheduleReminder();
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    if (_loading || plan == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_units.isEmpty) {
      return _UnavailableHome(
        onRetry: _load,
        onOpenSettings: widget.reminders == null ? null : _openSettings,
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ReadableWidth(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              18,
              14 + MediaQuery.paddingOf(context).top,
              18,
              20 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              StudioWordmark(
                action: widget.reminders == null ? null : _openSettings,
                actionTooltip: l10n.t('設定', 'Settings'),
              ),
              const SizedBox(height: 22),
              _TodayStudio(
                plan: plan,
                busy: _openingToday,
                onStart: _startToday,
              ),
              const SizedBox(height: 12),
              _ExamCard(plan: plan, onTap: _pickExamDate),
              const SizedBox(height: 32),
              _SaidItList(items: _said),
              const SizedBox(height: 32),
              StudioSectionHeader(
                title: l10n.t('次にできること', 'What you can do next'),
                description: l10n.t(
                  '見直すか、別のテーマを自分で選べます。',
                  'Review, or pick another topic yourself.',
                ),
              ),
              const SizedBox(height: 14),
              StudioActionTile(
                icon: Icons.replay,
                title: l10n.t('もう一度見るところ', 'To review'),
                description: plan.due.isEmpty
                    ? l10n.t('いま見直すものはありません', 'Nothing to review right now')
                    : l10n.t(
                        '${plan.due.length}件を、忘れる前に見直す',
                        'Review ${plan.due.length} before you forget',
                      ),
                onTap: _openReviewOnce,
              ),
              const SizedBox(height: 10),
              StudioActionTile(
                icon: Icons.auto_stories_outlined,
                title: l10n.t('教えるテーマを選ぶ', 'Choose a topic to teach'),
                description: l10n.t(
                  'ほかの単元から、自分で選んで始める',
                  'Pick from other units and start',
                ),
                onTap: _openPickerOnce,
                warm: true,
              ),
              if (widget.onOpenPlus != null) ...[
                const SizedBox(height: 10),
                StudioActionTile(
                  icon: Icons.forum_outlined,
                  title: l10n.t('デキすぎ君 Plus', 'Dekisugi-kun Plus'),
                  description: l10n.t(
                    'Plusは保護者向け復習プランと共有レポート、限定マスコット',
                    'Plus adds a family review plan, shareable report, and exclusive mascot',
                  ),
                  onTap: () => unawaited(_openPlusOnce()),
                ),
              ],
              if (_team case final s?) ...[
                const SizedBox(height: 18),
                TeamCard(summary: s, onLeave: _openTeam),
              ] else if (widget.team != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: StudioActionTile(
                    icon: Icons.groups_outlined,
                    title: l10n.t('クラスに入る', 'Join a class'),
                    description: l10n.t(
                      '誰かと競わず、クラス全体の説明を集める',
                      'No competing. Build up explanations as a whole class',
                    ),
                    onTap: _openTeam,
                  ),
                ),
              const SizedBox(height: 24),
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
class _TodayStudio extends StatelessWidget {
  const _TodayStudio({
    required this.plan,
    required this.busy,
    required this.onStart,
  });

  final ExamPlan plan;
  final bool busy;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    final task = plan.today;

    Widget character(double size) => Container(
      width: size + 12,
      height: size + 12,
      decoration: BoxDecoration(color: c.coolSurface, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Character(state: LiveState.idle, size: size),
    );

    Widget copy({required bool compact}) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              switch (task?.missionKind) {
                MissionKind.repair => Icons.build_outlined,
                MissionKind.caseRetry => Icons.travel_explore_outlined,
                _ => Icons.auto_stories_outlined,
              },
              size: 17,
              color: c.heroMuted,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                task == null
                    ? l10n.t('TODAY MISSION  ·  きょう', 'TODAY MISSION  ·  Today')
                    : switch (task.missionKind) {
                        MissionKind.teach => l10n.t(
                          'TODAY MISSION  ·  きょうの挑戦',
                          'TODAY MISSION  ·  Today\'s challenge',
                        ),
                        MissionKind.repair => l10n.t(
                          'REPAIR MISSION  ·  決着をつける',
                          'REPAIR MISSION  ·  Settle it',
                        ),
                        MissionKind.caseRetry => l10n.t(
                          'CASE MISSION  ·  別の場面でたしかめる',
                          'CASE MISSION  ·  Test it in a new situation',
                        ),
                      },
                style: t.textTheme.labelMedium
                    ?.copyWith(color: c.heroMuted)
                    .jaWeight(FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          task == null
              ? l10n.t('きょうのミッションは\nクリア。', 'Today\'s mission\ncleared.')
              : switch (task.missionKind) {
                  MissionKind.teach => l10n.t(
                    '「${task.label}」を教えて、\n最後の思い込みを見破ろう。',
                    'Teach "${task.label}"\nand spot the last misconception.',
                  ),
                  MissionKind.repair => l10n.t(
                    '「${task.label}」の説明を組み直し、\n今度こそ決着をつけよう。',
                    'Rebuild your explanation of "${task.label}"\nand settle it this time.',
                  ),
                  MissionKind.caseRetry => l10n.t(
                    '「${task.label}」を、\n別の場面でも使ってみよう。',
                    'Try using "${task.label}"\nin a different situation.',
                  ),
                },
          style:
              (compact ? t.textTheme.headlineSmall : t.textTheme.headlineMedium)
                  ?.copyWith(color: c.onHeroSurface, height: 1.35)
                  .jaWeight(FontWeight.w700),
        ),
        const SizedBox(height: 9),
        Text(
          task == null
              ? l10n.t(
                  '今日はここまででも大丈夫。また話したくなったら、ここにいます。',
                  'It\'s fine to stop here today. I\'ll be here when you want to talk again.',
                )
              : switch (task.missionKind) {
                  MissionKind.teach => l10n.t(
                    '作戦を選び、自分の言葉で説明して、デキすぎ君の反論に答えます。',
                    'Pick a strategy, explain in your own words, and answer Dekisugi-kun\'s pushback.',
                  ),
                  MissionKind.repair => l10n.t(
                    '前に曖昧だった条件や理由を、自分の言葉でつなぎ直します。',
                    'Reconnect the conditions and reasons that were fuzzy last time, in your own words.',
                  ),
                  MissionKind.caseRetry => l10n.t(
                    '教材の答えを見ず、具体場面の予想と理由を説明します。',
                    'Without looking at the lesson, predict a real situation and explain why.',
                  ),
                },
          style: t.textTheme.bodySmall?.copyWith(color: c.heroMuted),
        ),
        if (task != null) ...[
          const SizedBox(height: 18),
          FilledButton(
            onPressed: busy ? null : onStart,
            style: FilledButton.styleFrom(
              backgroundColor: c.onHeroSurface,
              foregroundColor: c.heroSurface,
            ),
            child: Text(
              busy
                  ? l10n.t('ミッションを開いています…', 'Opening mission…')
                  : switch (task.missionKind) {
                      MissionKind.teach => l10n.t('ミッション開始', 'Start mission'),
                      MissionKind.repair => l10n.t('リペア開始', 'Start repair'),
                      MissionKind.caseRetry => l10n.t('ケース開始', 'Start case'),
                    },
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );

    // この面全体を ExcludeSemantics すると、中の主 CTA まで読み上げツリーから
    // 消える。見出しと操作を自然な順序で読ませ、ボタンの役割を保つ。
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        decoration: BoxDecoration(
          color: c.heroSurface,
          borderRadius: BorderRadius.circular(AppRadius.stage),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth < 360 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.3;
            if (compact) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: character(constraints.maxWidth < 300 ? 76 : 88),
                    ),
                    copy(compact: true),
                  ],
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 18, 22),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: copy(compact: false)),
                  const SizedBox(width: 8),
                  character(126),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 教材一覧が空のとき、学習完了に見せない。
/// 初回オフラインと本当に教材が無い状態はクライアントから区別できないため、
/// どちらでも安全な「開けない＋再試行」として扱う。
class _UnavailableHome extends StatelessWidget {
  const _UnavailableHome({required this.onRetry, this.onOpenSettings});

  final Future<void> Function() onRetry;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: onRetry,
        child: ReadableWidth(
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              18,
              14 + MediaQuery.paddingOf(context).top,
              18,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              StudioWordmark(
                action: onOpenSettings,
                actionTooltip: l10n.t('設定', 'Settings'),
              ),
              const SizedBox(height: 30),
              StudioPageIntro(
                eyebrow: 'CONVERSATION STUDIO',
                title: l10n.t('教材を、まだ開けません。', 'Can\'t open the lessons yet.'),
                body: l10n.t(
                  '通信を確かめて、もう一度読み込んでください。端末に保存済みの教材があれば、通信なしでも開けます。',
                  'Check your connection and reload. Lessons already saved on this device open without internet.',
                ),
              ),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: c.coolSurface,
                  borderRadius: BorderRadius.circular(AppRadius.stage),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.cloud_off_outlined, color: c.onCoolSurface),
                    const SizedBox(height: 14),
                    Text(
                      l10n.t(
                        '「きょうは終わり」ではありません。',
                        'This doesn\'t mean you\'re done for today.',
                      ),
                      style: t.textTheme.titleMedium
                          ?.copyWith(color: c.onCoolSurface)
                          .jaWeight(FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.t(
                        '教材を読み込めたら、ここに今日の話が出ます。',
                        'Once the lessons load, today\'s topic will show up here.',
                      ),
                      style: t.textTheme.bodyMedium?.copyWith(
                        color: c.onCoolSurface,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.t('もう一度読み込む', 'Reload')),
                      ),
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
                          ? l10n.t(
                              '次の考査日を入れると、そこから逆算します',
                              'Enter your next exam date to plan backward from it',
                            )
                          : left < 0
                          ? l10n.t('次の考査日を入れ直す', 'Set the next exam date')
                          : left == 0
                          ? l10n.t('きょうが考査日', 'Exam day is today')
                          : l10n.t(
                              '考査まで あと$left日',
                              '$left days until the exam',
                            ),
                      style: t.textTheme.titleSmall?.jaWeight(FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      left != null && left < 0
                          ? l10n.t(
                              '前の考査日は終了しています',
                              'Your last exam date has passed',
                            )
                          : plan.remaining == 0
                          ? l10n.t(
                              '説明していないところはありません',
                              'You\'ve explained everything',
                            )
                          : l10n.t(
                              'まだ説明していないところが ${plan.remaining} つ',
                              '${plan.remaining} left to explain',
                            ),
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
        StudioSectionHeader(
          title: l10n.t('言えるようになったこと', 'Things you can now explain'),
          description: l10n.t(
            '点数ではなく、あなたが実際に話した言葉です。',
            'Not scores: the actual words you said.',
          ),
          leading: Icon(Icons.format_quote, size: 22, color: scheme.primary),
        ),
        const SizedBox(height: 14),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            decoration: BoxDecoration(
              color: context.appColors.warmSurface,
              borderRadius: BorderRadius.circular(AppRadius.xxl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '“',
                  style: t.textTheme.headlineLarge?.copyWith(
                    color: context.appColors.onWarmSurface,
                    height: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.t(
                    '最初の説明が、ここに残ります。',
                    'Your first explanation will be kept here.',
                  ),
                  style: t.textTheme.titleMedium
                      ?.copyWith(color: context.appColors.onWarmSurface)
                      .jaWeight(FontWeight.w700),
                ),
              ],
            ),
          )
        else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            decoration: BoxDecoration(
              color: context.appColors.warmSurface,
              borderRadius: BorderRadius.circular(AppRadius.xxl),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  items.first.label,
                  style: t.textTheme.labelMedium?.copyWith(
                    color: context.appColors.onWarmSurface.withValues(
                      alpha: 0.75,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.t('「${items.first.said}」', '"${items.first.said}"'),
                  style: t.textTheme.titleMedium
                      ?.copyWith(
                        color: context.appColors.onWarmSurface,
                        height: 1.55,
                      )
                      .jaWeight(FontWeight.w600),
                ),
              ],
            ),
          ),
          for (final e in items.skip(1).take(4))
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
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
                    l10n.t('「${e.said}」', '"${e.said}"'),
                    style: t.textTheme.bodyLarge?.jaWeight(FontWeight.w500),
                  ),
                  const SizedBox(height: 14),
                  const Divider(),
                ],
              ),
            ),
        ],
        if (items.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              l10n.t('ほか ${items.length - 5} 件', '${items.length - 5} more'),
              style: t.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
