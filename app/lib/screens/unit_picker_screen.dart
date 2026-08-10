import '../config/app_radius.dart';
import '../config/app_theme.dart';
import '../models/unit.dart';
import '../services/units_client.dart';
import '../ui/_material.dart';
import '../widgets/readable_width.dart';
import '../widgets/studio_ui.dart';

/// 1回の学習で挑む「概念ミッション」を選ぶ。
///
/// **何を説明することになるかを、選ぶ前に見せる。**
/// 「力と運動」とだけ書かれても、何を求められるのか分からない。
/// 概念を個別の操作にし、教材を読んだ後に言葉にする対象を
/// 最初から1つに絞る。
class UnitPickerScreen extends StatefulWidget {
  const UnitPickerScreen({
    super.key,
    required this.units,
    required this.onPick,
    this.onOpenReview,
  });

  final UnitsClient units;

  /// 教材と、その中で挑む概念を選んだ。
  final void Function(UnitDetail unit, String conceptKey) onPick;

  final VoidCallback? onOpenReview;

  @override
  State<UnitPickerScreen> createState() => _UnitPickerScreenState();
}

class _UnitPickerScreenState extends State<UnitPickerScreen> {
  List<UnitSummary>? _list;
  ({String unitId, String conceptKey})? _loading;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await widget.units.list();
    if (!mounted) return;
    setState(() {
      _list = list;
      _error = list.isEmpty ? '単元を取ってこられませんでした。' : null;
    });
  }

  Future<void> _pick(UnitSummary summary, UnitConcept concept) async {
    // 連打で同じ教材を何度も取りに行かない。
    // setState 後の再ビルドより前に2回目が来てもここで止まる。
    if (_loading != null) return;

    setState(() {
      _loading = (unitId: summary.id, conceptKey: concept.key);
      _error = null;
    });
    final detail = await widget.units.detail(summary.id);
    if (!mounted) return;

    if (detail == null || detail.sectionFor(concept.key) == null) {
      // **教材が無いまま会話へ入れない。** 読まずに説明させることになる
      setState(() {
        _loading = null;
        _error =
            '「${concept.label}」の教材を読み込めませんでした。'
            '通信を確かめてもう一度どうぞ。';
      });
      return;
    }

    // callback は同期に呼ぶ。その間も _loading を残し、遷移前の連打を防ぐ。
    widget.onPick(detail, concept.key);
    if (mounted) setState(() => _loading = null);
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ReadableWidth(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                18,
                6,
                18,
                28 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                _PickerNavigation(onOpenReview: widget.onOpenReview),
                const SizedBox(height: 22),
                const StudioPageIntro(
                  eyebrow: 'LEARNING MISSION  /  SELECT',
                  title: '挑むミッションを選ぼう',
                  body:
                      '1回の挑戦は、1つの考え方だけ。'
                      '教材で確かめたあと、デキすぎ君の思い込みを見破ろう。',
                ),
                const SizedBox(height: 18),
                const _LearningRoute(),
                const SizedBox(height: 28),
                if (_error case final message?) ...[
                  _ErrorNote(message: message, onRetry: _load),
                  const SizedBox(height: 16),
                ],
                if (list == null)
                  const _LoadingContents()
                else if (list.isEmpty)
                  const _EmptyContents()
                else
                  _ContentsSheet(
                    units: list,
                    loading: _loading,
                    onPick: _loading == null ? _pick : null,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerNavigation extends StatelessWidget {
  const _PickerNavigation({required this.onOpenReview});

  final VoidCallback? onOpenReview;

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
            '今日挑むミッション',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.textTheme.titleSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        if (onOpenReview != null)
          IconButton(
            onPressed: onOpenReview,
            icon: const Icon(Icons.bookmark_outline),
            tooltip: 'もう一度見るところ',
          ),
      ],
    );
  }
}

/// 対象を選び、確かめ、誤概念を見破るまでを一本の動線として示す。
class _LearningRoute extends StatelessWidget {
  const _LearningRoute();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: scheme.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ミッションの流れ',
            style: t.textTheme.labelMedium
                ?.copyWith(color: scheme.primary)
                .jaWeight(FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '対象を選ぶ  →  教材で確かめる  →  思い込みを見破る',
            style: t.textTheme.bodyMedium?.jaWeight(FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// 単元をジャンル、概念を実際に選ぶミッションとして見せる。
class _ContentsSheet extends StatelessWidget {
  const _ContentsSheet({
    required this.units,
    required this.loading,
    required this.onPick,
  });

  final List<UnitSummary> units;
  final ({String unitId, String conceptKey})? loading;
  final Future<void> Function(UnitSummary summary, UnitConcept concept)? onPick;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 4,
              children: [
                Text(
                  'MISSION LIST  /  挑戦一覧',
                  style: t.textTheme.labelMedium
                      ?.copyWith(color: scheme.onSurfaceVariant)
                      .jaWeight(FontWeight.w700),
                ),
                Text(
                  '全${units.fold<int>(0, (sum, unit) => sum + unit.concepts.length)}ミッション',
                  style: t.textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: scheme.outlineVariant),
          for (var i = 0; i < units.length; i++) ...[
            _ContentsEntry(
              number: i + 1,
              unit: units[i],
              loading: loading,
              onPick: onPick == null
                  ? null
                  : (concept) => onPick!(units[i], concept),
            ),
            if (i != units.length - 1)
              Divider(height: 1, color: scheme.outlineVariant),
          ],
        ],
      ),
    );
  }
}

class _ContentsEntry extends StatelessWidget {
  const _ContentsEntry({
    required this.number,
    required this.unit,
    required this.loading,
    required this.onPick,
  });

  final int number;
  final UnitSummary unit;
  final ({String unitId, String conceptKey})? loading;
  final void Function(UnitConcept concept)? onPick;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final numberLabel = number.toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 38,
                child: Text(
                  numberLabel,
                  style: t.textTheme.titleSmall
                      ?.copyWith(color: scheme.primary)
                      .jaWeight(FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit.title,
                      style: t.textTheme.titleLarge?.jaWeight(FontWeight.w700),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      unit.brief,
                      style: t.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (unit.concepts.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'この単元のミッション',
              style: t.textTheme.labelMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)
                  .jaWeight(FontWeight.w700),
            ),
            const SizedBox(height: 9),
            for (var i = 0; i < unit.concepts.length; i++) ...[
              _ConceptMission(
                unitId: unit.id,
                unitNumber: number,
                missionNumber: i + 1,
                concept: unit.concepts[i],
                busy:
                    loading?.unitId == unit.id &&
                    loading?.conceptKey == unit.concepts[i].key,
                onTap: onPick == null ? null : () => onPick!(unit.concepts[i]),
              ),
              if (i != unit.concepts.length - 1) const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

/// 48dp 以上の「概念1つ」の操作。
///
/// 単元全体ではなく、今回読み、説明し、思い込みを見破る対象を明示する。
class _ConceptMission extends StatelessWidget {
  const _ConceptMission({
    required this.unitId,
    required this.unitNumber,
    required this.missionNumber,
    required this.concept,
    required this.busy,
    required this.onTap,
  });

  final String unitId;
  final int unitNumber;
  final int missionNumber;
  final UnitConcept concept;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final missionLabel =
        '${unitNumber.toString().padLeft(2, '0')}-'
        '${missionNumber.toString().padLeft(2, '0')}';

    return Semantics(
      key: ValueKey('mission-$unitId-${concept.key}'),
      container: true,
      button: true,
      enabled: onTap != null,
      label:
          'ミッション「${concept.label}」を始める。'
          '教材で確かめて、デキすぎ君の思い込みを見破る。',
      value: busy ? '教材を読み込み中' : null,
      child: ExcludeSemantics(
        child: Material(
          color: busy ? scheme.primaryContainer : scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            side: BorderSide(
              color: busy ? scheme.primary : scheme.outlineVariant,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MISSION  $missionLabel',
                      style: t.textTheme.labelSmall
                          ?.copyWith(color: scheme.primary)
                          .jaWeight(FontWeight.w700),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '対象：${concept.label}',
                      style: t.textTheme.titleMedium?.jaWeight(FontWeight.w700),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'この考え方を自分の言葉で説明し、'
                      'デキすぎ君の思い込みを見破る',
                      style: t.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            busy ? '教材を準備中…' : '教材を読んで挑戦',
                            style: t.textTheme.labelMedium
                                ?.copyWith(color: scheme.primary)
                                .jaWeight(FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (busy)
                          const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            Icons.arrow_forward,
                            size: 19,
                            color: scheme.primary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingContents extends StatelessWidget {
  const _LoadingContents();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 180),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: scheme.outlineVariant),
      ),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(),
    );
  }
}

class _EmptyContents extends StatelessWidget {
  const _EmptyContents();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text('単元がまだありません。', style: t.textTheme.bodyMedium),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Icon(
                  Icons.cloud_off,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(message, style: t.textTheme.bodyMedium)),
            ],
          ),
          const SizedBox(height: 4),
          TextButton(onPressed: onRetry, child: const Text('やり直す')),
        ],
      ),
    );
  }
}
