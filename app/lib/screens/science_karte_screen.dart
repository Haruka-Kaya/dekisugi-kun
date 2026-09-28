import '../config/app_theme.dart';
import '../config/game_tokens.dart';
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
  });

  final List<UnitSummary> catalog;
  final SessionStore store;
  final LearningScope scope;

  @override
  State<ScienceKarteScreen> createState() => _ScienceKarteScreenState();
}

class _ScienceKarteScreenState extends State<ScienceKarteScreen> {
  static const _projection = LearningKarteProjection();
  late Future<LearningKarteView> _view;

  @override
  void initState() {
    super.initState();
    _view = _load();
  }

  Future<LearningKarteView> _load() async {
    final needStates = await widget.store.learningNeedStates(widget.scope);
    final snapshot = await widget.store.learningProgressSnapshot(widget.scope);
    return _projection.build(
      catalog: widget.catalog,
      needStates: needStates,
      skills: snapshot.skills,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: FutureBuilder<LearningKarteView>(
          future: _view,
          builder: (context, snapshot) {
            final view = snapshot.data;
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
