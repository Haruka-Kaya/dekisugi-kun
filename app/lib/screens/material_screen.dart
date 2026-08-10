import '../config/app_radius.dart';
import '../config/app_theme.dart';
import '../models/mission.dart';
import '../models/unit.dart';
import '../ui/_material.dart';
import '../widgets/emphasis_text.dart';
import '../widgets/readable_width.dart';
import '../widgets/studio_ui.dart';

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
    this.missionKind = MissionKind.teach,
    this.practiceAttempt = 0,
    this.review = false,
  });

  final UnitDetail unit;

  /// 読み終わった。会話へ進む
  final ValueChanged<TeachingTactic> onDone;

  /// 開く節。指定があればそこだけを出す。
  ///
  /// **「復習かどうか」とは別物。** ホームの「きょうの1件」も
  /// 1つの節だけを開くが、そこから会話へ進む。
  /// 兼ねさせていたせいで、ホームの主 CTA が行き止まりになっていた（実機で発覚）。
  final String? focusConceptKey;

  /// 教材の使い方。同じ概念でも初回・立て直し・別場面への適用で
  /// 学習行為を変え、同じ会話の繰り返しにしない。
  final MissionKind missionKind;

  /// 端末内でこの概念を完了した回数。CASEではこの値から選んだ公開variantの
  /// 場面だけを見せ、続く練習画面と同じ課題を保つ。
  final int practiceAttempt;

  /// 読み直しだけで、会話へ進まない。
  final bool review;

  @override
  State<MaterialScreen> createState() => _MaterialScreenState();
}

class _MaterialScreenState extends State<MaterialScreen> {
  final _scroll = ScrollController();
  bool _reachedEnd = false;
  bool _completing = false;
  TeachingTactic? _tactic;

  bool get _isReview => widget.review;
  bool get _isCase => !_isReview && widget.missionKind == MissionKind.caseRetry;

  LocalPracticeVariant _variantFor(Section section) =>
      section.practiceVariantForAttempt(widget.practiceAttempt);

  String _casePromptFor(Section section) {
    // JSON/API教材は必ずvariantを持つ。直接構築する既存fixtureだけは旧形式を
    // 許すが、tryItまで空なら汎用問題へ黙って差し替えず、欠損として止める。
    if (section.localPracticeVariants.isEmpty) return section.tryIt.trim();
    return _variantFor(section).transferPrompt.trim();
  }

  List<Section> get _sections {
    final key = widget.focusConceptKey;
    if (key == null) return widget.unit.sections;
    final one = widget.unit.sectionFor(key);
    // 1概念ミッションの教材が欠けていても、単元全体へ黙って広げない。
    // 「今日の1件」が突然長い会話になるより、再読込できる失敗面に止める。
    if (one == null || (_isCase && _casePromptFor(one).isEmpty)) {
      return const [];
    }
    return [one];
  }

  @override
  void initState() {
    super.initState();
    // CASEは提示された場面について「予想＋理由」を話す固定課題。
    // 作戦選択を挟まず、そのまま理由から話せる足場にする。
    if (_isCase) _tactic = TeachingTactic.reason;
    _scroll.addListener(_onScroll);
    // 1画面で収まるときは最後まで来たものとして扱う。
    // **スクロールが起きないと永久に押せない**という詰まりを避ける
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkInitialExtent());
  }

  /// ListView は初回の post-frame 時点でも、親のサイズ確定が次の frame に
  /// 持ち越されて ScrollMetrics をまだ持たないことがある。
  /// スクロール不能な短い教材は listener が一度も呼ばれないため、有限回だけ
  /// 再確認して「読了できない画面」を作らない。
  void _checkInitialExtent([int attemptsRemaining = 3]) {
    if (!mounted || _reachedEnd) return;

    if (_scroll.hasClients && _scroll.position.hasContentDimensions) {
      _onScroll();
      if (_reachedEnd) return;
    }

    if (attemptsRemaining <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _checkInitialExtent(attemptsRemaining - 1),
    );
  }

  void _onScroll() {
    if (_reachedEnd || !_scroll.hasClients) return;
    final p = _scroll.position;
    if (p.maxScrollExtent <= 0 || p.pixels >= p.maxScrollExtent - 120) {
      setState(() => _reachedEnd = true);
    }
  }

  /// 完了ボタンの連打で Talk を二重 push したり、復習元まで pop しない。
  /// Navigator の置換は次のフレームまで残るため、ボタンの無効化だけでなく
  /// コールバック側でも同期的に一度きりへ閉じる。
  void _complete() {
    if (_completing || !_reachedEnd) return;
    final tactic = _tactic;
    if (!_isReview && tactic == null) return;
    setState(() => _completing = true);
    if (_isReview) {
      Navigator.of(context).pop(true);
    } else {
      widget.onDone(tactic!);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections;

    if (sections.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: ReadableWidth(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
                  child: _ReadingNavigation(
                    review: _isReview,
                    missionKind: widget.missionKind,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.menu_book_outlined,
                            size: 40,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'このミッションの教材を読み込めませんでした',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'もどって、もう一度ミッションを選んでください。',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      // iPad は横に広い。読み物は行が長くなりすぎないよう止める。
      body: ReadableWidth(
        child: ListView(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(
            18,
            6 + MediaQuery.paddingOf(context).top,
            18,
            40,
          ),
          children: [
            _ReadingNavigation(
              review: _isReview,
              missionKind: widget.missionKind,
            ),
            const SizedBox(height: 18),
            _ReadingIntro(
              unit: widget.unit,
              sections: sections,
              review: _isReview,
              missionKind: widget.missionKind,
            ),
            if (!_isReview) ...[
              const SizedBox(height: 20),
              _TeachingPromise(missionKind: widget.missionKind),
            ],
            const SizedBox(height: 28),
            if (_isCase)
              _CaseSheet(
                section: sections.single,
                prompt: _casePromptFor(sections.single),
              )
            else
              _PaperSheet(sections: sections),
            if (!_isReview && !_isCase) ...[
              const SizedBox(height: 26),
              _TacticPicker(
                selected: _tactic,
                onSelected: (value) => setState(() => _tactic = value),
              ),
            ],
          ],
        ),
      ),
      // **操作はスクロールの外に置く。**
      // 中に入れると読み終わるまで組み立てられず、
      // 「押せるようになった」ことに気づけない。
      bottomNavigationBar: _ReadingActionBar(
        review: _isReview,
        reachedEnd: _reachedEnd,
        completing: _completing,
        tacticSelected: _tactic != null,
        missionKind: widget.missionKind,
        onDone: _complete,
      ),
    );
  }
}

class _ReadingNavigation extends StatelessWidget {
  const _ReadingNavigation({required this.review, required this.missionKind});

  final bool review;
  final MissionKind missionKind;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
          tooltip: 'もどる',
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            review
                ? '教材を読み直す'
                : switch (missionKind) {
                    MissionKind.teach => '作戦を準備する',
                    MissionKind.repair => '説明を組み直す',
                    MissionKind.caseRetry => 'ケースを読む',
                  },
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.textTheme.titleSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadingIntro extends StatelessWidget {
  const _ReadingIntro({
    required this.unit,
    required this.sections,
    required this.review,
    required this.missionKind,
  });

  final UnitDetail unit;
  final List<Section> sections;
  final bool review;
  final MissionKind missionKind;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final readingTime = sections.fold(
      Duration.zero,
      (total, section) => total + section.readingTime,
    );
    final mins = (readingTime.inSeconds / 60).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          child: StudioPageIntro(
            eyebrow: review
                ? 'READ AGAIN  /  読み直し'
                : switch (missionKind) {
                    MissionKind.teach => 'MISSION 1/3  /  作戦準備',
                    MissionKind.repair => 'REPAIR 1/3  /  組み直す',
                    MissionKind.caseRetry => 'CASE 1/3  /  別の場面',
                  },
            title: unit.title,
            body: missionKind == MissionKind.caseRetry && !review
                ? '前に説明した考えを、答えの見えない別の場面で使います。'
                : unit.summary.brief,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            _ReadingMeta(
              icon: Icons.schedule,
              label: missionKind == MissionKind.caseRetry && !review
                  ? '考えるのに およそ1分'
                  : '読むのに およそ$mins分',
            ),
            _ReadingMeta(
              icon: missionKind == MissionKind.caseRetry && !review
                  ? Icons.travel_explore_outlined
                  : Icons.menu_book_outlined,
              label: missionKind == MissionKind.caseRetry && !review
                  ? '1ケース'
                  : '${sections.length}章',
            ),
          ],
        ),
        const SizedBox(height: 18),
        Divider(color: scheme.outlineVariant),
      ],
    );
  }
}

class _ReadingMeta extends StatelessWidget {
  const _ReadingMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: scheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          label,
          style: t.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// C1 と C2 を、読み始める前に短い編集注として伝える。
class _TeachingPromise extends StatelessWidget {
  const _TeachingPromise({required this.missionKind});

  final MissionKind missionKind;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: scheme.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            switch (missionKind) {
              MissionKind.teach => 'このミッションのゴール',
              MissionKind.repair => 'このリペアのゴール',
              MissionKind.caseRetry => 'このケースのゴール',
            },
            style: t.textTheme.labelMedium
                ?.copyWith(color: scheme.primary)
                .jaWeight(FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(switch (missionKind) {
            MissionKind.teach => '自分の言葉で教えたあと、デキすぎ君の思い込みを見破ります。',
            MissionKind.repair => '前に曖昧だった説明を組み直し、思い込みに決着をつけます。',
            MissionKind.caseRetry => '場面の結果を予想し、なぜそうなるかまで説明します。',
          }, style: t.textTheme.bodyMedium?.jaWeight(FontWeight.w700)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(
                  Icons.visibility_off_outlined,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  missionKind == MissionKind.caseRetry
                      ? '話しているあいだ、このケースは見られません。'
                      : '話しているあいだ、教材は見られません。',
                  style: t.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 一度説明できた知識を、新しい場面へ使うための問題面。
///
/// 正解や元教材を同時に見せると想起ではなく照合になるため、`tryIt`の状況だけを
/// 1枚で提示する。結果の選択肢は置かず、会話で予想と理由を生成してもらう。
class _CaseSheet extends StatelessWidget {
  const _CaseSheet({required this.section, required this.prompt});

  final Section section;
  final String prompt;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;

    return Semantics(
      container: true,
      label: 'ケース問題。$prompt',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
          decoration: BoxDecoration(
            color: c.warmSurface,
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            border: Border.all(color: c.onWarmSurface.withValues(alpha: 0.28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.travel_explore_outlined,
                    size: 25,
                    color: c.onWarmSurface,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'CASE FILE 01  /  結果を予想せよ',
                      style: t.textTheme.labelLarge
                          ?.copyWith(color: c.onWarmSurface)
                          .jaWeight(FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              Text(
                section.title,
                style: t.textTheme.titleLarge
                    ?.copyWith(color: c.onWarmSurface)
                    .jaWeight(FontWeight.w700),
              ),
              const SizedBox(height: 10),
              EmphasisText(
                prompt,
                style: t.textTheme.bodyLarge
                    ?.copyWith(color: c.onWarmSurface, height: 1.72)
                    .jaWeight(FontWeight.w700),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
                decoration: BoxDecoration(
                  color: c.onWarmSurface.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Text(
                  '答えはまだ表示しません。何が起きるかと、その理由を考えてください。',
                  style: t.textTheme.bodySmall?.copyWith(
                    color: c.onWarmSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 読んだ内容をどう思い出すか、本人が足場を選ぶ。
/// 正解選択ではないため、どれを選んでも学習判定には影響しない。
class _TacticPicker extends StatelessWidget {
  const _TacticPicker({required this.selected, required this.onSelected});

  final TeachingTactic? selected;
  final ValueChanged<TeachingTactic> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 17),
      decoration: BoxDecoration(
        color: c.coolSurface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'どの作戦で教える？',
            style: t.textTheme.titleLarge
                ?.copyWith(color: c.onCoolSurface)
                .jaWeight(FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            '正解を選ぶ問題ではありません。話しやすい入口をひとつ選びます。',
            style: t.textTheme.bodySmall?.copyWith(
              color: c.onCoolSurface.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 13),
          for (final tactic in TeachingTactic.values) ...[
            _TacticOption(
              tactic: tactic,
              selected: selected == tactic,
              onTap: () => onSelected(tactic),
            ),
            if (tactic != TeachingTactic.values.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _TacticOption extends StatelessWidget {
  const _TacticOption({
    required this.tactic,
    required this.selected,
    required this.onTap,
  });

  final TeachingTactic tactic;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    return Semantics(
      button: true,
      selected: selected,
      label: '${tactic.label}。${tactic.hint}',
      child: Material(
        color: selected
            ? c.onCoolSurface.withValues(alpha: 0.12)
            : c.onCoolSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 21,
                    color: c.onCoolSurface,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tactic.label,
                          style: t.textTheme.titleSmall
                              ?.copyWith(color: c.onCoolSurface)
                              .jaWeight(FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tactic.hint,
                          style: t.textTheme.bodySmall?.copyWith(
                            color: c.onCoolSurface.withValues(alpha: 0.82),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 全章を一枚の紙面にまとめ、カードの集合ではなく「読む対象」に見せる。
class _PaperSheet extends StatelessWidget {
  const _PaperSheet({required this.sections});

  final List<Section> sections;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                'DEKISUGI READING PAPER',
                style: t.textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant)
                    .jaWeight(FontWeight.w700),
              ),
              Text(
                '${sections.length} ${sections.length == 1 ? 'CHAPTER' : 'CHAPTERS'}'
                '  /  STUDY EDITION',
                style: t.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: scheme.outlineVariant),
          for (var i = 0; i < sections.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 34),
              Divider(color: scheme.outlineVariant),
              const SizedBox(height: 30),
            ] else
              const SizedBox(height: 24),
            _SectionView(
              section: sections[i],
              number: i + 1,
              total: sections.length,
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionView extends StatelessWidget {
  const _SectionView({
    required this.section,
    required this.number,
    required this.total,
  });

  final Section section;
  final int number;
  final int total;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final c = context.appColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '第$number章  /  全$total章',
          style: t.textTheme.labelMedium
              ?.copyWith(color: scheme.primary)
              .jaWeight(FontWeight.w700),
        ),
        const SizedBox(height: 7),
        Text(
          section.title,
          style: t.textTheme.headlineSmall?.jaWeight(FontWeight.w700),
        ),
        const SizedBox(height: 18),
        for (final p in section.body)
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            // 和文の行間は本文スタイル側で確保してある（M3 の 1.43 では足りない）。
            child: EmphasisText(p, style: t.textTheme.bodyLarge),
          ),
        if (section.tryIt.isNotEmpty) ...[
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
            decoration: BoxDecoration(
              color: c.warmSurface,
              border: Border(
                left: BorderSide(color: c.onWarmSurface, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'やってみる',
                  style: t.textTheme.labelLarge
                      ?.copyWith(color: c.onWarmSurface)
                      .jaWeight(FontWeight.w700),
                ),
                const SizedBox(height: 7),
                EmphasisText(
                  section.tryIt,
                  style: t.textTheme.bodyMedium?.copyWith(
                    color: c.onWarmSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ReadingActionBar extends StatelessWidget {
  const _ReadingActionBar({
    required this.review,
    required this.reachedEnd,
    required this.completing,
    required this.tacticSelected,
    required this.missionKind,
    required this.onDone,
  });

  final bool review;
  final bool reachedEnd;
  final bool completing;
  final bool tacticSelected;
  final MissionKind missionKind;
  final VoidCallback onDone;

  String get _statusText {
    if (missionKind == MissionKind.caseRetry) {
      return reachedEnd ? 'ここからはケースを見ずに、予想と理由を話します。' : 'ケースを最後まで読むと、予想を話せます。';
    }
    if (!reachedEnd) {
      return missionKind == MissionKind.repair
          ? '最後まで読み直して、組み直し方を選ぶと挑戦できます。'
          : '最後まで読んで、教え方を選ぶと挑戦できます。';
    }
    if (!tacticSelected) {
      return missionKind == MissionKind.repair
          ? '組み直し方をひとつ選ぶと、リペアを始められます。'
          : '教え方をひとつ選ぶと、ミッションを始められます。';
    }
    return missionKind == MissionKind.repair
        ? 'ここからは教材を見ずに、選んだ作戦で組み直します。'
        : 'ここからは教材を見ずに、選んだ作戦で挑みます。';
  }

  String get _buttonLabel => switch (missionKind) {
    MissionKind.teach => 'この作戦で挑む',
    MissionKind.repair => 'この作戦で組み直す',
    MissionKind.caseRetry => '予想と理由を話す',
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: ReadableWidth(
          tight: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
            child: review
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          reachedEnd
                              ? '読み直した記録を残せます。'
                              : '最後まで読むと、読み直した記録を残せます。',
                          style: t.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: reachedEnd && !completing ? onDone : null,
                          child: const Text('読み終えた'),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _statusText,
                          style: t.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          // **読み終わるまで進ませない。** 押せてしまうと、
                          // 読まずに会話へ入って「説明できない」だけの体験になる。
                          onPressed: reachedEnd && tacticSelected && !completing
                              ? onDone
                              : null,
                          child: Text(
                            _buttonLabel,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
