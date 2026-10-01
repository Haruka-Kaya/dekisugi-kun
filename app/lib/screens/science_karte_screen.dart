import 'dart:async';

import 'package:flutter/services.dart';

import '../config/app_language.dart' as lang;
import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../learning/domain/learning_economy.dart';
import '../learning/domain/learning_event.dart';
import '../learning/services/learning_karte_projection.dart';
import '../learning/services/family_review_plan.dart';
import '../models/unit.dart';
import '../services/session_store.dart';
import '../ui/_material.dart';
import '../widgets/game_page.dart';

/// デキすぎ君のカルテ —— 誤概念マップ。
///
/// デキすぎ君が持っている思い込み（誤概念カタログ）と、あなたの説明で
/// 観測・解消できた作業を概念ごとに並べる。生徒の弱点を断定せず（C9）、
/// 「AI がまだ迷っているところ」として表示する。回答本文・音声・選択肢は
/// 保存規約上ここまで来ない。
class ScienceKarteScreen extends StatefulWidget {
  const ScienceKarteScreen({
    super.key,
    required this.catalog,
    required this.store,
    required this.scope,
    this.onOpenPlus,
  });

  final List<UnitSummary> catalog;
  final SessionStore store;
  final LearningScope scope;

  /// Plus特典の案内カードからpaywallを開く。学校・local scopeではnullのまま
  /// （カード自体を出さない）。
  final VoidCallback? onOpenPlus;

  @override
  State<ScienceKarteScreen> createState() => _ScienceKarteScreenState();
}

class _ScienceKarteScreenState extends State<ScienceKarteScreen> {
  static const _projection = LearningKarteProjection();
  late Future<({LearningKarteView view, bool supporter})> _view;

  @override
  void initState() {
    super.initState();
    _view = _load();
  }

  Future<({LearningKarteView view, bool supporter})> _load() async {
    final needStates = await widget.store.learningNeedStates(widget.scope);
    final snapshot = await widget.store.learningProgressSnapshot(widget.scope);
    return (
      view: _projection.build(
        catalog: widget.catalog,
        needStates: needStates,
        skills: snapshot.skills,
      ),
      supporter:
          snapshot.cosmetics?.owns(
            SafeLearningEconomyCatalogV1.auroraMascotId,
          ) ??
          false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: FutureBuilder<({LearningKarteView view, bool supporter})>(
          future: _view,
          builder: (context, snapshot) {
            final view = snapshot.data?.view;
            final supporter = snapshot.data?.supporter ?? false;
            return ListView(
              key: const ValueKey('science-karte-screen'),
              padding: EdgeInsets.fromLTRB(
                GameTokens.spaceXl,
                GameTokens.spaceLg,
                GameTokens.spaceXl,
                GameTokens.spaceXl + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                Row(
                  children: [
                    IconButton(
                      key: const ValueKey('science-karte-back'),
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back),
                      tooltip: lang.t('もどる', 'Back'),
                    ),
                    const SizedBox(width: GameTokens.spaceSm),
                    Expanded(
                      child: Text(
                        lang.t('デキすぎ君のカルテ', 'Dekisugi-kun\'s record'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: colors.ink)
                            .jaWeight(FontWeight.w900),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: GameTokens.spaceMd),
                GameHeroSurface(
                  surfaceKey: const ValueKey('science-karte-summary'),
                  color: colors.story,
                  foregroundColor: colors.onStory,
                  eyebrow: lang.t('思い込みの記録', 'Misconception record'),
                  title: view == null
                      ? lang.t('読み込み中…', 'Loading…')
                      : lang.t(
                              '訂正できた ${view.summary.resolvedNeedCount}・',
                              'Corrected: ${view.summary.resolvedNeedCount} ·',
                            ) +
                            lang.t(
                              '迷い中 ${view.summary.activeNeedCount}',
                              ' Still unsure: ${view.summary.activeNeedCount}',
                            ),
                  body:
                      lang.t('デキすぎ君は教科書にありがちな思い込みを', 'Dekisugi-kun has') +
                      lang.t(
                        '${view == null ? '' : view.summary.conceptCount}個持っています。',
                        ' ${view == null ? '' : view.summary.conceptCount} common textbook misconceptions.',
                      ) +
                      lang.t(
                        'あなたの説明で、ひとつずつ訂正していきます。',
                        ' Your teaching helps correct them one by one.',
                      ),
                  semanticSummary: lang.t(
                    'デキすぎ君のカルテ。思い込みの記録。',
                    'Dekisugi-kun\'s record. Misconception history.',
                  ),
                  leading: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.psychology_alt_outlined,
                        color: colors.story,
                        size: GameTokens.heroMascotSize * 0.55,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: GameTokens.spaceMd),
                GameSolidSurface(
                  surfaceKey: const ValueKey('science-karte-note'),
                  raised: true,
                  child: Text(
                    lang.t(
                          'ここにあるのは答え合わせではなく、デキすぎ君が持っている思い込みと、',
                          'This is a record of Dekisugi-kun\'s misconceptions and',
                        ) +
                        lang.t(
                          'あなたの説明で変わったところの記録です。誤答の本文や音声は残りません。',
                          ' how your teaching changed them, not an answer key. Wrong answers and audio are not saved.',
                        ) +
                        lang.t(
                          '思い込みは、実際の中高生へのアンケート回答をもとに作られました。',
                          ' The misconceptions come from surveys of real middle and high school students.',
                        ),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
                  ),
                ),
                const SizedBox(height: GameTokens.spaceMd),
                if (view != null && widget.onOpenPlus != null)
                  _ParentReportCard(
                    supporter: supporter,
                    onOpenReport: () => unawaited(
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => _KarteParentReportScreen(view: view),
                        ),
                      ),
                    ),
                    onOpenPlus: widget.onOpenPlus!,
                  ),
                const SizedBox(height: GameTokens.spaceXl),
                if (view == null)
                  const Center(child: CircularProgressIndicator())
                else if (view.concepts.isEmpty)
                  GameSolidSurface(
                    raised: true,
                    child: Text(
                      lang.t(
                        'カタログをまだ読めていません。',
                        'The catalog has not loaded yet.',
                      ),
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
                    ),
                  )
                else
                  for (final unit in _unitsInOrder(view)) ...[
                    GameSectionHeader(
                      title: unit.title,
                      description: lang.t(
                        'この単元の思い込みと、観測した作業の記録。',
                        'Misconceptions in this unit and a record of what you observed.',
                      ),
                    ),
                    const SizedBox(height: GameTokens.spaceMd),
                    for (final concept in view.concepts.where(
                      (entry) => entry.unitId == unit.id,
                    )) ...[
                      _KarteConceptCard(entry: concept),
                      const SizedBox(height: GameTokens.spaceMd),
                    ],
                    const SizedBox(height: GameTokens.spaceLg),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }

  List<UnitSummary> _unitsInOrder(LearningKarteView view) {
    final ids = view.concepts.map((entry) => entry.unitId).toSet();
    return widget.catalog.where((unit) => ids.contains(unit.id)).toList();
  }
}

class _KarteConceptCard extends StatelessWidget {
  const _KarteConceptCard({required this.entry});

  final LearningKarteConcept entry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    return GameSolidSurface(
      surfaceKey: ValueKey('karte-concept-${entry.unitId}/${entry.conceptKey}'),
      raised: true,
      padding: const EdgeInsets.all(GameTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  entry.label,
                  style: t.textTheme.titleSmall
                      ?.copyWith(color: colors.ink)
                      .jaWeight(FontWeight.w800),
                ),
              ),
              _KarteStatusChip(entry: entry),
            ],
          ),
          if (entry.misconception != null) ...[
            const SizedBox(height: GameTokens.spaceSm),
            Text(
              lang.t('デキすぎ君の思い込み', 'Dekisugi-kun\'s misconceptions'),
              style: t.textTheme.labelSmall?.copyWith(color: colors.inkMuted),
            ),
            const SizedBox(height: GameTokens.spaceXs),
            Text(
              '「${entry.misconception!.statement}」',
              style: t.textTheme.bodyMedium
                  ?.copyWith(color: colors.ink)
                  .jaWeight(FontWeight.w600),
            ),
          ],
          if (entry.hasResolvedNeeds) ...[
            const SizedBox(height: GameTokens.spaceSm),
            if (entry.misconception != null)
              Text(
                lang.t(
                  'あなたの説明で分かったこと: ${entry.misconception!.correct}',
                  'What your teaching helped clarify: ${entry.misconception!.correct}',
                ),
                style: t.textTheme.bodySmall?.copyWith(
                  color: colors.pathComplete,
                ),
              ),
          ],
          if (entry.hasActiveNeeds || entry.hasResolvedNeeds) ...[
            const SizedBox(height: GameTokens.spaceMd),
            Wrap(
              spacing: GameTokens.spaceSm,
              runSpacing: GameTokens.spaceSm,
              children: [
                for (final need in entry.activeNeeds)
                  _KarteNeedChip(
                    label: learningKarteNeedKindLabel(
                      'science.${entry.conceptKey}.$need',
                    ),
                    resolved: false,
                  ),
                for (final need in entry.resolvedNeeds)
                  _KarteNeedChip(
                    label: learningKarteNeedKindLabel(
                      'science.${entry.conceptKey}.$need',
                    ),
                    resolved: true,
                  ),
              ],
            ),
          ],
          if (!entry.taught && !entry.hasActiveNeeds) ...[
            const SizedBox(height: GameTokens.spaceSm),
            Text(
              lang.t(
                'まだ一緒に確かめていない思い込みです。',
                'You have not explored this misconception together yet.',
              ),
              style: t.textTheme.bodySmall?.copyWith(color: colors.inkMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _KarteStatusChip extends StatelessWidget {
  const _KarteStatusChip({required this.entry});

  final LearningKarteConcept entry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    final (label, fill, foreground) = entry.hasActiveNeeds
        ? (lang.t('迷い中', 'Still unsure'), colors.story, colors.onStory)
        : entry.hasResolvedNeeds
        ? (lang.t('訂正できた', 'Corrected'), colors.pathComplete, colors.surface)
        : entry.taught
        ? (lang.t('観測中', 'Exploring'), colors.surface, colors.inkMuted)
        : (lang.t('これから', 'Up next'), colors.surface, colors.inkMuted);
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: GameTokens.spaceMd,
            vertical: GameTokens.spaceXs,
          ),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(GameTokens.radiusPill),
            border: Border.all(color: colors.border),
          ),
          child: Text(
            label,
            style: t.textTheme.labelSmall
                ?.copyWith(color: foreground)
                .jaWeight(FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

/// 保護者向けレポートの案内カード。Plusサポーターはそのままレポートを開き、
/// それ以外はpaywallへ橋渡しする。学校・local scopeではカード自体を出さない。
class _ParentReportCard extends StatelessWidget {
  const _ParentReportCard({
    required this.supporter,
    required this.onOpenReport,
    required this.onOpenPlus,
  });

  final bool supporter;
  final VoidCallback onOpenReport;
  final VoidCallback onOpenPlus;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    return GameSolidSurface(
      surfaceKey: const ValueKey('science-karte-parent-report'),
      raised: true,
      padding: const EdgeInsets.all(GameTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  lang.t('保護者の方へのレポート', 'Report for parents'),
                  style: t.textTheme.titleSmall
                      ?.copyWith(color: colors.ink)
                      .jaWeight(FontWeight.w800),
                ),
              ),
              if (!supporter)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: GameTokens.spaceMd,
                    vertical: GameTokens.spaceXs,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(GameTokens.radiusPill),
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(
                    lang.t('Plusサポーター特典', 'Plus supporter benefit'),
                    style: t.textTheme.labelSmall?.copyWith(
                      color: colors.inkMuted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: GameTokens.spaceSm),
          Text(
            lang.t(
              '観察記録から次の復習テーマと、保護者が聞ける問いを作ります。回答本文や音声を含めず、コピーして共有できます。',
              'Create a next-review topic and parent prompts from observation records. Copy and share without answer text or audio.',
            ),
            style: t.textTheme.bodySmall?.copyWith(color: colors.inkMuted),
          ),
          const SizedBox(height: GameTokens.spaceMd),
          FilledButton(
            key: ValueKey(
              supporter
                  ? 'science-karte-report-open'
                  : 'science-karte-report-plus',
            ),
            onPressed: supporter ? onOpenReport : onOpenPlus,
            child: Text(
              supporter
                  ? lang.t('レポートを開く', 'Open report')
                  : lang.t('Plusを見る', 'View Plus'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 保護者の方へ渡すための、デキすぎ君カルテの文章レポート。
///
/// 生徒の点数や誤答ではなく「AI の思い込みがどう変わったか」だけをまとめる
/// （C9）。本文は端末内生成で、コピーして渡すだけ。記録される回答・音声は
/// ここにも現れない。
class _KarteParentReportScreen extends StatelessWidget {
  const _KarteParentReportScreen({required this.view});

  final LearningKarteView view;

  List<LearningKarteConcept> get _resolved => view.concepts
      .where((entry) => entry.hasResolvedNeeds && entry.misconception != null)
      .toList();

  List<LearningKarteConcept> get _inProgress => view.concepts
      .where((entry) => entry.hasActiveNeeds && entry.misconception != null)
      .toList();

  int get _untouchedCount => view.concepts
      .where(
        (entry) =>
            !entry.taught && !entry.hasActiveNeeds && !entry.hasResolvedNeeds,
      )
      .length;

  String _reportText() {
    final lines = <String>[
      lang.t(
        'デキすぎ君のカルテ — 保護者の方へのレポート',
        'Dekisugi-kun\'s record — Report for parents',
      ),
      '',
      familyReviewPlan(view),
      '',
      lang.t(
        'デキすぎ君は、教科書にありがちな思い込みを持っているAIです。',
        'Dekisugi-kun is an AI with common textbook misconceptions.',
      ),
      lang.t(
            'お子さまは教材を読んでからデキすぎ君に説明し、デキすぎ君が',
            'Your child reads the material and teaches Dekisugi-kun,',
          ) +
          lang.t(
            '分かるまで付き合います。ここにまとめるのは、お子さまの説明で',
            ' helping him until he understands. This report shows',
          ) +
          lang.t(
            'デキすぎ君の思い込みがどう変わったかの記録です。',
            ' how your child\'s teaching changed his misconceptions.',
          ),
      '',
      lang.t(
        '■ お子さまの説明で分かってもらえた思い込み（${_resolved.length}件）',
        '■ Misconceptions clarified by your child\'s teaching (${_resolved.length})',
      ),
      for (final entry in _resolved) ...[
        lang.t(
          '・「${entry.misconception!.statement}」（${entry.unitTitle}）',
          '• "${entry.misconception!.statement}" (${entry.unitTitle})',
        ),
        lang.t(
          '  → ${entry.misconception!.correct}',
          '  → ${entry.misconception!.correct}',
        ),
      ],
      if (_resolved.isEmpty) lang.t('・まだありません。', '• None yet.'),
      '',
      lang.t(
        '■ いま一緒に確かめている思い込み（${_inProgress.length}件）',
        '■ Misconceptions being explored together (${_inProgress.length})',
      ),
      for (final entry in _inProgress)
        lang.t(
              '・「${entry.misconception!.statement}」（${entry.unitTitle}）',
              '• "${entry.misconception!.statement}" (${entry.unitTitle})',
            ) +
            lang.t('— 次に一緒に確かめる内容です。', ' — A topic to explore together next.'),
      if (_inProgress.isEmpty) lang.t('・ありません。', '• None.'),
      '',
      lang.t(
        '残り $_untouchedCount 件の思い込みは、これから一緒に確かめます。',
        'The remaining $_untouchedCount misconceptions are still to explore together.',
      ),
      '',
      lang.t(
            '※ お子さまの誤答の本文・音声・点数は記録されていません。このレポートは',
            'Note: Wrong answers, audio, and scores are not recorded. This report',
          ) +
          lang.t(
            'AI の思い込みの変化だけをまとめたものです。',
            ' only summarizes how the AI\'s misconceptions changed.',
          ),
    ];
    return lines.join('\n');
  }

  Future<void> _copyReport(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _reportText()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(lang.t('レポートをコピーしました', 'Report copied'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: ListView(
          key: const ValueKey('science-karte-report'),
          padding: EdgeInsets.fromLTRB(
            GameTokens.spaceXl,
            GameTokens.spaceLg,
            GameTokens.spaceXl,
            GameTokens.spaceXl + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            Row(
              children: [
                IconButton(
                  key: const ValueKey('science-karte-report-back'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: lang.t('もどる', 'Back'),
                ),
                const SizedBox(width: GameTokens.spaceSm),
                Expanded(
                  child: Text(
                    lang.t('保護者の方へのレポート', 'Report for parents'),
                    style: t.textTheme.titleMedium
                        ?.copyWith(color: colors.ink)
                        .jaWeight(FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: GameTokens.spaceMd),
            GameSolidSurface(
              surfaceKey: const ValueKey('family-review-plan'),
              padding: const EdgeInsets.all(GameTokens.spaceLg),
              child: Text(
                familyReviewPlan(view),
                style: t.textTheme.bodyMedium?.copyWith(color: colors.ink),
              ),
            ),
            const SizedBox(height: GameTokens.spaceMd),
            GameSolidSurface(
              raised: true,
              padding: const EdgeInsets.all(GameTokens.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    lang.t(
                          'デキすぎ君は、教科書にありがちな思い込みを持っているAIです。',
                          'Dekisugi-kun is an AI with common textbook misconceptions.',
                        ) +
                        lang.t(
                          'お子さまは教材を読んでからデキすぎ君に説明し、デキすぎ君が',
                          ' Your child reads the material and teaches Dekisugi-kun,',
                        ) +
                        lang.t(
                          '分かるまで付き合います。',
                          ' helping him until he understands.',
                        ),
                    style: t.textTheme.bodySmall?.copyWith(
                      color: colors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: GameTokens.spaceLg),
                  Text(
                    lang.t(
                      'お子さまの説明で分かってもらえた思い込み（${_resolved.length}件）',
                      'Misconceptions clarified by your child\'s teaching (${_resolved.length})',
                    ),
                    style: t.textTheme.titleSmall
                        ?.copyWith(color: colors.ink)
                        .jaWeight(FontWeight.w800),
                  ),
                  const SizedBox(height: GameTokens.spaceSm),
                  if (_resolved.isEmpty)
                    Text(
                      lang.t('まだありません。', 'None yet.'),
                      style: t.textTheme.bodySmall?.copyWith(
                        color: colors.inkMuted,
                      ),
                    )
                  else
                    for (final entry in _resolved)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: GameTokens.spaceSm,
                        ),
                        child: Text(
                          '「${entry.misconception!.statement}」\n'
                          '→ ${entry.misconception!.correct}',
                          style: t.textTheme.bodySmall?.copyWith(
                            color: colors.ink,
                          ),
                        ),
                      ),
                  const SizedBox(height: GameTokens.spaceMd),
                  Text(
                    lang.t(
                      'いま一緒に確かめている思い込み（${_inProgress.length}件）',
                      'Misconceptions being explored together (${_inProgress.length})',
                    ),
                    style: t.textTheme.titleSmall
                        ?.copyWith(color: colors.ink)
                        .jaWeight(FontWeight.w800),
                  ),
                  const SizedBox(height: GameTokens.spaceSm),
                  if (_inProgress.isEmpty)
                    Text(
                      lang.t('ありません。', 'None.'),
                      style: t.textTheme.bodySmall?.copyWith(
                        color: colors.inkMuted,
                      ),
                    )
                  else
                    for (final entry in _inProgress)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: GameTokens.spaceSm,
                        ),
                        child: Text(
                          lang.t(
                            '「${entry.misconception!.statement}」'
                                '— 次に一緒に確かめる内容です。',
                            '"${entry.misconception!.statement}" '
                                '— A topic to explore together next.',
                          ),
                          style: t.textTheme.bodySmall?.copyWith(
                            color: colors.ink,
                          ),
                        ),
                      ),
                  const SizedBox(height: GameTokens.spaceMd),
                  Text(
                    lang.t(
                      '残り $_untouchedCount 件の思い込みは、これから一緒に確かめます。',
                      'The remaining $_untouchedCount misconceptions are still to explore together.',
                    ),
                    style: t.textTheme.bodySmall?.copyWith(
                      color: colors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: GameTokens.spaceLg),
                  Text(
                    lang.t(
                          '※ お子さまの誤答の本文・音声・点数は記録されていません。',
                          'Note: Wrong answers, audio, and scores are not recorded.',
                        ) +
                        lang.t(
                          'このレポートはAIの思い込みの変化だけをまとめたものです。',
                          ' This report only summarizes how the AI\'s misconceptions changed.',
                        ),
                    style: t.textTheme.bodySmall?.copyWith(
                      color: colors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: GameTokens.spaceMd),
            FilledButton.icon(
              key: const ValueKey('science-karte-report-copy'),
              onPressed: () => unawaited(_copyReport(context)),
              icon: const Icon(Icons.copy),
              label: Text(lang.t('レポートをコピー', 'Copy report')),
            ),
          ],
        ),
      ),
    );
  }
}

class _KarteNeedChip extends StatelessWidget {
  const _KarteNeedChip({required this.label, required this.resolved});

  final String label;
  final bool resolved;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    final foreground = resolved ? colors.pathComplete : colors.story;
    return Semantics(
      label: lang.t(
        '$label、${resolved ? '解消した' : 'まだ迷っている'}',
        '$label, ${resolved ? 'Resolved' : 'Still unsure'}',
      ),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: GameTokens.spaceMd,
            vertical: GameTokens.spaceXs,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GameTokens.radiusPill),
            border: Border.all(color: foreground),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                resolved ? Icons.check : Icons.psychology_outlined,
                size: 14,
                color: foreground,
              ),
              const SizedBox(width: GameTokens.spaceXs),
              Text(
                label,
                style: t.textTheme.labelSmall?.copyWith(color: foreground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
