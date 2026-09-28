import 'dart:async';

import 'package:flutter/services.dart';

import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../learning/domain/learning_economy.dart';
import '../learning/domain/learning_event.dart';
import '../learning/services/learning_karte_projection.dart';
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
                      tooltip: 'もどる',
                    ),
                    const SizedBox(width: GameTokens.spaceSm),
                    Expanded(
                      child: Text(
                        'デキすぎ君のカルテ',
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
                  eyebrow: '思い込みの記録',
                  title: view == null
                      ? '読み込み中…'
                      : '訂正できた ${view.summary.resolvedNeedCount}・'
                            '迷い中 ${view.summary.activeNeedCount}',
                  body: 'デキすぎ君は教科書にありがちな思い込みを'
                      '${view == null ? '' : view.summary.conceptCount}個持っています。'
                      'あなたの説明で、ひとつずつ訂正していきます。',
                  semanticSummary: 'デキすぎ君のカルテ。思い込みの記録。',
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
                    'ここにあるのは答え合わせではなく、デキすぎ君が持っている思い込みと、'
                    'あなたの説明で変わったところの記録です。誤答の本文や音声は残りません。',
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
                      'カタログをまだ読めていません。',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
                    ),
                  )
                else
                  for (final unit in _unitsInOrder(view)) ...[
                    GameSectionHeader(
                      title: unit.title,
                      description: 'この単元の思い込みと、観測した作業の記録。',
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
              'デキすぎ君の思い込み',
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
                'あなたの説明で分かったこと: ${entry.misconception!.correct}',
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
              'まだ一緒に確かめていない思い込みです。',
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
        ? ('迷い中', colors.story, colors.onStory)
        : entry.hasResolvedNeeds
        ? ('訂正できた', colors.pathComplete, colors.surface)
        : entry.taught
        ? ('観測中', colors.surface, colors.inkMuted)
        : ('これから', colors.surface, colors.inkMuted);
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
                  '保護者の方へのレポート',
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
                    'Plusサポーター特典',
                    style: t.textTheme.labelSmall?.copyWith(
                      color: colors.inkMuted,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: GameTokens.spaceSm),
          Text(
            supporter
                ? 'お子さまの説明でデキすぎ君が理解した思い込みを、'
                      '保護者の方に渡せる文章でまとめます。'
                : 'お子さまがデキすぎ君に教えて直した思い込みを、'
                      '保護者の方へ渡せるレポートにまとめられます。',
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
            child: Text(supporter ? 'レポートを開く' : 'Plusを見る'),
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
      'デキすぎ君のカルテ — 保護者の方へのレポート',
      '',
      'デキすぎ君は、教科書にありがちな思い込みを持っているAIです。',
      'お子さまは教材を読んでからデキすぎ君に説明し、デキすぎ君が'
          '分かるまで付き合います。ここにまとめるのは、お子さまの説明で'
          'デキすぎ君の思い込みがどう変わったかの記録です。',
      '',
      '■ お子さまの説明で分かってもらえた思い込み（${_resolved.length}件）',
      for (final entry in _resolved) ...[
        '・「${entry.misconception!.statement}」（${entry.unitTitle}）',
        '  → ${entry.misconception!.correct}',
      ],
      if (_resolved.isEmpty) '・まだありません。',
      '',
      '■ いま一緒に確かめている思い込み（${_inProgress.length}件）',
      for (final entry in _inProgress)
        '・「${entry.misconception!.statement}」（${entry.unitTitle}）'
            '— お子さまの説明がまだ届ききっていません。',
      if (_inProgress.isEmpty) '・ありません。',
      '',
      '残り $_untouchedCount 件の思い込みは、これから一緒に確かめます。',
      '',
      '※ お子さまの誤答の本文・音声・点数は記録されていません。このレポートは'
          'AI の思い込みの変化だけをまとめたものです。',
    ];
    return lines.join('\n');
  }

  Future<void> _copyReport(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _reportText()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('レポートをコピーしました')));
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
                  tooltip: 'もどる',
                ),
                const SizedBox(width: GameTokens.spaceSm),
                Expanded(
                  child: Text(
                    '保護者の方へのレポート',
                    style: t.textTheme.titleMedium
                        ?.copyWith(color: colors.ink)
                        .jaWeight(FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: GameTokens.spaceMd),
            GameSolidSurface(
              raised: true,
              padding: const EdgeInsets.all(GameTokens.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'デキすぎ君は、教科書にありがちな思い込みを持っているAIです。'
                    'お子さまは教材を読んでからデキすぎ君に説明し、デキすぎ君が'
                    '分かるまで付き合います。',
                    style: t.textTheme.bodySmall?.copyWith(
                      color: colors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: GameTokens.spaceLg),
                  Text(
                    'お子さまの説明で分かってもらえた思い込み（${_resolved.length}件）',
                    style: t.textTheme.titleSmall
                        ?.copyWith(color: colors.ink)
                        .jaWeight(FontWeight.w800),
                  ),
                  const SizedBox(height: GameTokens.spaceSm),
                  if (_resolved.isEmpty)
                    Text(
                      'まだありません。',
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
                    'いま一緒に確かめている思い込み（${_inProgress.length}件）',
                    style: t.textTheme.titleSmall
                        ?.copyWith(color: colors.ink)
                        .jaWeight(FontWeight.w800),
                  ),
                  const SizedBox(height: GameTokens.spaceSm),
                  if (_inProgress.isEmpty)
                    Text(
                      'ありません。',
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
                          '「${entry.misconception!.statement}」'
                          '— 説明がまだ届ききっていません。',
                          style: t.textTheme.bodySmall?.copyWith(
                            color: colors.ink,
                          ),
                        ),
                      ),
                  const SizedBox(height: GameTokens.spaceMd),
                  Text(
                    '残り $_untouchedCount 件の思い込みは、これから一緒に確かめます。',
                    style: t.textTheme.bodySmall?.copyWith(
                      color: colors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: GameTokens.spaceLg),
                  Text(
                    '※ お子さまの誤答の本文・音声・点数は記録されていません。'
                    'このレポートはAIの思い込みの変化だけをまとめたものです。',
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
              label: const Text('レポートをコピー'),
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
      label: '$label、${resolved ? '解消した' : 'まだ迷っている'}',
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
