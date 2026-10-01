import 'dart:async';

import '../config/app_language.dart' as l10n;
import '../config/app_radius.dart';
import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../models/classroom_mission.dart';
import '../models/unit.dart';
import '../services/local_classroom_run_store.dart';
import '../services/units_client.dart';
import '../ui/_material.dart';
import '../widgets/readable_width.dart';
import '../widgets/studio_ui.dart';
import '../widgets/participant_qr_code.dart';
import 'material_screen.dart';
import 'offline_practice_screen.dart';
import 'qr_scan_screen.dart';

/// 端末内ホームに置く、授業への短い入口。
///
/// 途中記録または最後に終えた授業があれば、教材番号と概念をここで見せる。
/// 無ければ教師が板書した教材番号から始められることだけを伝える。
class LocalClassroomEntryCard extends StatefulWidget {
  const LocalClassroomEntryCard({
    super.key,
    required this.units,
    required this.runStore,
    required this.onOpen,
  });

  final UnitsClient units;
  final LocalClassroomRunStore runStore;
  final VoidCallback onOpen;

  @override
  State<LocalClassroomEntryCard> createState() =>
      _LocalClassroomEntryCardState();
}

class _LocalClassroomEntryCardState extends State<LocalClassroomEntryCard> {
  ClassroomAssignment? _assignment;
  LocalClassroomRun? _run;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant LocalClassroomEntryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 親画面へ戻ったとき、同じstoreインスタンスでも途中位置は完了・破棄で
    // 変わり得る。親の再buildを再読込の合図として使う。
    _load();
  }

  Future<void> _load() async {
    try {
      final units = await widget.units.list();
      final run = await widget.runStore.load();
      if (!mounted) return;
      final missions = ClassroomMission.fromUnits(units);
      setState(() {
        _run = run;
        _assignment = run == null
            ? null
            : ClassroomAssignment.findByRun(
                missions,
                unitId: run.unitId,
                conceptKey: run.conceptKey,
                practiceAttempt: run.practiceAttempt,
              );
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _run = null;
        _assignment = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.appColors;
    final run = _run;
    final assignment = _assignment;
    final hasRun = run != null && assignment != null;
    final completed = hasRun && run.stage == LocalClassroomStage.completed;
    final title = completed
        ? l10n.t('最後に終えた授業', 'Last finished lesson')
        : hasRun
        ? l10n.t('途中の授業を再開', 'Resume lesson in progress')
        : l10n.t('先生の教材番号で始める', 'Start with your teacher\'s lesson code');
    final description = completed
        ? l10n.t(
            '${assignment.classroomCode}  ${assignment.mission.conceptLabel}\n'
                '比較フローの操作完了。内容・理解は未確認です。',
            '${assignment.classroomCode}  ${assignment.mission.conceptLabel}\n'
                'Comparison steps done. Content and understanding not checked.',
          )
        : hasRun
        ? '${assignment.classroomCode}  ${assignment.mission.conceptLabel}\n'
              '${run.stage == LocalClassroomStage.material ? l10n.t('教材の最初から再開します。', 'You\'ll restart from the beginning of the lesson.') : l10n.t('説明の最初から再開します。入力内容は保存していません。', 'You\'ll restart from the beginning of your explanation. What you typed was not saved.')}'
        : l10n.t(
            '黒板の「01-02-A」のような番号から、同じ概念と同じ問いをすぐ開けます。',
            'Use a code from the board like "01-02-A" to open the same concept and question right away.',
          );

    return Semantics(
      key: const ValueKey('local-classroom-entry-card'),
      button: true,
      enabled: !_loading,
      label: l10n.t('$title。$description', '$title. $description'),
      onTap: _loading ? null : widget.onOpen,
      child: ExcludeSemantics(
        child: Material(
          color: colors.warmSurface,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _loading ? null : widget.onOpen,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 15, 14, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      completed
                          ? Icons.task_alt_outlined
                          : hasRun
                          ? Icons.play_circle_outline
                          : Icons.school_outlined,
                      color: colors.onWarmSurface,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _loading
                                ? l10n.t(
                                    '授業の教材を確認しています',
                                    'Checking lesson materials',
                                  )
                                : title,
                            style: t.textTheme.titleSmall
                                ?.copyWith(color: colors.onWarmSurface)
                                .jaWeight(FontWeight.w700),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _loading
                                ? l10n.t(
                                    '端末内の情報だけを読み込みます。',
                                    'Only data on this device is loaded.',
                                  )
                                : description,
                            style: t.textTheme.bodySmall?.copyWith(
                              color: colors.onWarmSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_loading)
                      SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.onWarmSurface,
                        ),
                      )
                    else
                      Icon(
                        Icons.arrow_forward,
                        size: 20,
                        color: colors.onWarmSurface,
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

/// 授業の5〜10分で、全員が同じ端末内教材を開くための1画面完結入口。
///
/// 教材番号は同梱カタログの位置であり、学校や生徒を識別しない。
/// 回答本文を保存せず、OS終了後は同じ概念の安全な先頭から再開する。
/// 完了後は、正答や理解ではなく比較フローの操作を終えた印だけを1件残す。
class LocalClassroomScreen extends StatefulWidget {
  const LocalClassroomScreen({
    super.key,
    required this.units,
    required this.runStore,
    this.onAssignmentCompleted,
    this.onRunChanged,
    this.scanClassroomCode,
  });

  final UnitsClient units;
  final LocalClassroomRunStore runStore;

  /// 比較フローを終えたcatalog上の課題だけを通知する。
  ///
  /// 自由記述、選択肢、正誤は渡さない。同じpractice route内では成功するまで
  /// 再試行でき、成功後は重ねて通知しない。[occurredAt]は回答時刻ではなく、
  /// 端末に保存済みの比較フロー完了時刻。
  final Future<void> Function(
    ClassroomAssignment assignment,
    DateTime occurredAt,
  )?
  onAssignmentCompleted;
  final Future<void> Function()? onRunChanged;

  /// QRのカメラ実装を差し替えるテスト用の入口。読取後も教材は開始しない。
  final Future<String?> Function(BuildContext context)? scanClassroomCode;

  @override
  State<LocalClassroomScreen> createState() => _LocalClassroomScreenState();
}

class _LocalClassroomScreenState extends State<LocalClassroomScreen> {
  final _number = TextEditingController();
  List<ClassroomMission> _missions = const [];
  LocalClassroomRun? _run;
  bool _loading = true;
  bool _busy = false;
  bool _submittedInvalid = false;
  String? _loadError;
  final Set<String> _publishedCompletionKeys = {};
  final Map<String, Future<void>> _completionPublishes = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final units = await widget.units.list();
      final run = await widget.runStore.load();
      if (!mounted) return;
      final missions = ClassroomMission.fromUnits(units);
      setState(() {
        _missions = missions;
        _run = run;
        _loading = false;
      });
      if (run?.stage == LocalClassroomStage.completed) {
        final assignment = ClassroomAssignment.findByRun(
          missions,
          unitId: run!.unitId,
          conceptKey: run.conceptKey,
          practiceAttempt: run.practiceAttempt,
        );
        if (assignment != null) {
          await _reconcileCompletedRun(assignment, run);
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = l10n.t(
          '端末内の教材を読み込めませんでした。',
          'Couldn\'t load the lessons on this device.',
        );
      });
    }
  }

  String _completionKey(LocalClassroomRun run) =>
      '${run.id}/${run.updatedAt.toUtc().microsecondsSinceEpoch}';

  Future<void> _publishCompletion(
    ClassroomAssignment assignment,
    LocalClassroomRun run,
  ) async {
    final callback = widget.onAssignmentCompleted;
    if (callback == null) return;
    final key = _completionKey(run);
    if (_publishedCompletionKeys.contains(key)) return;
    final inFlight = _completionPublishes[key];
    if (inFlight != null) return inFlight;
    final publish = Future<void>.sync(
      () => callback(assignment, run.updatedAt),
    );
    _completionPublishes[key] = publish;
    try {
      await publish;
      _publishedCompletionKeys.add(key);
    } finally {
      _completionPublishes.remove(key);
    }
  }

  Future<void> _reconcileCompletedRun(
    ClassroomAssignment assignment,
    LocalClassroomRun run,
  ) async {
    if (widget.onAssignmentCompleted == null) return;
    try {
      await _publishCompletion(assignment, run);
      await widget.onRunChanged?.call();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = l10n.t(
          '完了した授業を、この端末の学習記録へ反映できませんでした。もう一度お試しください。',
          'Couldn\'t add the finished lesson to this device\'s learning record. Please try again.',
        );
      });
    }
  }

  ClassroomAssignment? get _numberAssignment =>
      ClassroomAssignment.findByClassroomCode(_missions, _number.text);

  ClassroomAssignment? get _resumeAssignment {
    final run = _run;
    if (run == null) return null;
    return ClassroomAssignment.findByRun(
      _missions,
      unitId: run.unitId,
      conceptKey: run.conceptKey,
      practiceAttempt: run.practiceAttempt,
    );
  }

  Future<UnitDetail?> _detailFor(ClassroomAssignment assignment) async {
    final mission = assignment.mission;
    final detail = await widget.units.detail(mission.unit.id);
    if (detail == null || detail.sectionFor(mission.conceptKey) == null) {
      if (mounted) {
        setState(() {
          _loadError = l10n.t(
            '「${mission.conceptLabel}」の教材を開けませんでした。',
            'Couldn\'t open the lesson "${mission.conceptLabel}".',
          );
        });
      }
      return null;
    }
    return detail;
  }

  Future<bool> _confirmSwitch(ClassroomAssignment next) async {
    final run = _run;
    if (run == null || run.id == next.id) return true;
    final current = _resumeAssignment;
    final completed = run.stage == LocalClassroomStage.completed;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(
          completed
              ? l10n.t('最後の完了表示を入れ替えますか？', 'Replace the last completed lesson?')
              : l10n.t('途中の教材を切り替えますか？', 'Switch from the lesson in progress?'),
        ),
        content: Text(
          completed
              ? l10n.t(
                  '${current?.classroomCode ?? l10n.t('直近', 'Recent')}  ${current?.mission.conceptLabel ?? l10n.t('以前の教材', 'Previous lesson')}の完了表示は、'
                      '新しい教材の再開位置に入れ替わります。回答本文は保存していません。',
                  'The completion for ${current?.classroomCode ?? l10n.t('直近', 'Recent')}  ${current?.mission.conceptLabel ?? l10n.t('以前の教材', 'Previous lesson')} '
                      'will be replaced by the new lesson\'s resume point. Your answers were not saved.',
                )
              : l10n.t(
                  '${current?.classroomCode ?? l10n.t('途中', 'In progress')}  ${current?.mission.conceptLabel ?? l10n.t('以前の教材', 'Previous lesson')}の再開位置は消えます。'
                      '入力した説明は保存していません。',
                  'The resume point for ${current?.classroomCode ?? l10n.t('途中', 'In progress')}  ${current?.mission.conceptLabel ?? l10n.t('以前の教材', 'Previous lesson')} will be deleted. '
                      'Your explanation was not saved.',
                ),
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              completed
                  ? l10n.t('完了表示を残す', 'Keep completion')
                  : l10n.t('途中の教材を残す', 'Keep current lesson'),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              completed
                  ? l10n.t('新しい教材を始める', 'Start new lesson')
                  : l10n.t('切り替える', 'Switch'),
            ),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _startFromNumber() async {
    if (_busy) return;
    final assignment = _numberAssignment;
    if (assignment == null) {
      setState(() => _submittedInvalid = true);
      return;
    }
    await _start(assignment);
  }

  Future<void> _scanClassroomCode() async {
    if (_busy) return;
    final raw =
        await (widget.scanClassroomCode?.call(context) ??
            Navigator.of(context).push<String>(
              MaterialPageRoute<String>(builder: (_) => const QrScanScreen()),
            ));
    if (!mounted || raw == null) return;
    final code = ClassroomAssignment.classroomCodeFromQrPayload(raw);
    if (code == null ||
        ClassroomAssignment.findByClassroomCode(_missions, code) == null) {
      setState(() {
        _submittedInvalid = true;
        _loadError = l10n.t(
          'このQRは現在の同梱教材の授業コードではありません。先生の教材QRを読み取ってください。',
          'This QR isn\'t a lesson code for the current built-in lessons. Scan your teacher\'s lesson QR.',
        );
      });
      return;
    }
    setState(() {
      _number.text = code;
      _submittedInvalid = false;
      _loadError = null;
    });
  }

  Future<void> _openTeacherPreparation() async {
    if (_busy) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => TeacherLocalClassroomScreen(units: widget.units),
      ),
    );
  }

  Future<void> _start(
    ClassroomAssignment assignment, {
    UnitDetail? detail,
  }) async {
    // 同じ教材の途中位置があるなら、教材先頭へ黙って巻き戻さない。
    // 完了済みなら「同じ教材をもう一度」として新しい教材段階から始める。
    if (_run?.id == assignment.id &&
        _run?.stage != LocalClassroomStage.completed) {
      await _resume();
      return;
    }
    if (_busy || !await _confirmSwitch(assignment)) return;
    setState(() {
      _busy = true;
      _loadError = null;
    });
    try {
      final mission = assignment.mission;
      final got = detail ?? await _detailFor(assignment);
      if (got == null || !mounted) return;
      await widget.runStore.begin(
        unitId: mission.unit.id,
        conceptKey: mission.conceptKey,
        practiceAttempt: assignment.practiceAttempt,
      );
      if (!mounted) return;
      setState(() {
        _run = LocalClassroomRun(
          unitId: mission.unit.id,
          conceptKey: mission.conceptKey,
          practiceAttempt: assignment.practiceAttempt,
          stage: LocalClassroomStage.material,
          updatedAt: DateTime.now().toUtc(),
        );
      });
      await _openMaterial(got, assignment);
    } catch (_) {
      if (mounted) {
        setState(
          () => _loadError = l10n.t(
            '再開位置を端末に保存できませんでした。もう一度お試しください。',
            'Couldn\'t save the resume point on this device. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _load();
      }
    }
  }

  Future<void> _resume() async {
    final run = _run;
    final assignment = _resumeAssignment;
    if (_busy || run == null || assignment == null) return;
    setState(() {
      _busy = true;
      _loadError = null;
    });
    try {
      final detail = await _detailFor(assignment);
      if (detail == null || !mounted) return;
      switch (run.stage) {
        case LocalClassroomStage.material:
          await _openMaterial(detail, assignment);
          break;
        case LocalClassroomStage.practice:
          await Navigator.of(context).push(_offlineRoute(detail, assignment));
          break;
        case LocalClassroomStage.completed:
          return;
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _loadError = l10n.t(
            '途中の教材を開けませんでした。もう一度お試しください。',
            'Couldn\'t open the lesson in progress. Please try again.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _load();
      }
    }
  }

  Future<void> _openMaterial(
    UnitDetail detail,
    ClassroomAssignment assignment,
  ) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => MaterialScreen(
        unit: detail,
        focusConceptKey: assignment.mission.conceptKey,
        missionKind: assignment.missionKind,
        practiceAttempt: assignment.practiceAttempt,
        onDone: (_) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => _PracticePreparingScreen(
                runStore: widget.runStore,
                unitId: assignment.mission.unit.id,
                conceptKey: assignment.mission.conceptKey,
                practiceAttempt: assignment.practiceAttempt,
                route: () => _offlineRoute(detail, assignment),
              ),
            ),
          );
        },
      ),
    ),
  );

  MaterialPageRoute<void> _offlineRoute(
    UnitDetail detail,
    ClassroomAssignment assignment,
  ) {
    var runCompletionRecorded = false;
    var assignmentCompletionRecorded = false;
    LocalClassroomRun? completedRun;
    final mission = assignment.mission;
    final section = detail.sectionFor(mission.conceptKey)!;
    return MaterialPageRoute<void>(
      builder: (_) => OfflinePracticeScreen(
        section: section,
        conceptLabel: mission.conceptLabel,
        missionKind: assignment.missionKind,
        practiceAttempt: assignment.practiceAttempt,
        completionReference: assignment.classroomCode,
        onCheckpointCompleted: () async {
          if (!runCompletionRecorded) {
            completedRun = await widget.runStore.complete(
              unitId: mission.unit.id,
              conceptKey: mission.conceptKey,
              practiceAttempt: assignment.practiceAttempt,
            );
            runCompletionRecorded = true;
          }
          if (!assignmentCompletionRecorded) {
            await _publishCompletion(assignment, completedRun!);
            assignmentCompletionRecorded = true;
          }
          await widget.onRunChanged?.call();
        },
      ),
    );
  }

  Future<void> _browse() async {
    if (_busy) return;
    final assignment = await Navigator.of(context).push<ClassroomAssignment>(
      MaterialPageRoute<ClassroomAssignment>(
        builder: (_) => ClassroomAssignmentListScreen(
          assignments: ClassroomAssignment.fromMissions(_missions),
        ),
      ),
    );
    if (!mounted || assignment == null) return;
    await _start(assignment);
  }

  Future<void> _discard() async {
    final run = _run;
    if (_busy || run == null) return;
    final assignment = _resumeAssignment;
    final completed = run.stage == LocalClassroomStage.completed;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(
          completed
              ? l10n.t('最後の完了表示を消しますか？', 'Delete the last completed lesson?')
              : l10n.t('途中の再開位置を消しますか？', 'Delete the resume point?'),
        ),
        content: Text(
          completed
              ? l10n.t(
                  '${assignment?.classroomCode ?? ''} ${assignment?.mission.conceptLabel ?? l10n.t('最後に終えた教材', 'Last finished lesson')}の完了表示を、'
                      'この端末から消します。回答本文はもともと保存していません。',
                  'This deletes the completion for ${assignment?.classroomCode ?? ''} ${assignment?.mission.conceptLabel ?? l10n.t('最後に終えた教材', 'Last finished lesson')} '
                      'from this device. Your answers were never saved.',
                )
              : l10n.t(
                  '${assignment?.classroomCode ?? ''} ${assignment?.mission.conceptLabel ?? l10n.t('途中の教材', 'Lesson in progress')}の再開位置だけを消します。'
                      '回答本文はもともと保存していません。',
                  'This deletes only the resume point for ${assignment?.classroomCode ?? ''} ${assignment?.mission.conceptLabel ?? l10n.t('途中の教材', 'Lesson in progress')}. '
                      'Your answers were never saved.',
                ),
        ),
        actions: [
          TextButton(
            autofocus: true,
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              completed
                  ? l10n.t('完了表示を残す', 'Keep completion')
                  : l10n.t('再開位置を残す', 'Keep resume point'),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              completed
                  ? l10n.t('完了表示を消す', 'Delete completion')
                  : l10n.t('再開位置を消す', 'Delete resume point'),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.runStore.clear();
      if (mounted) await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assignment = _numberAssignment;
    final run = _run;
    final resume = _resumeAssignment;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('授業の教材を開く', 'Open a class lesson'))),
      body: SafeArea(
        top: false,
        child: ReadableWidth(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              18,
              12,
              18,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              StudioPageIntro(
                eyebrow: 'CLASSROOM  /  DEVICE ONLY',
                title: l10n.t(
                  '同じ教材に、すぐそろう。',
                  'Everyone on the same lesson, fast.',
                ),
                body: l10n.t(
                  '先生が示したA/B/C付きの教材番号で、同じ概念と同じ問いを開きます。',
                  'Use the lesson code with A/B/C from your teacher to open the same concept and question.',
                ),
              ),
              const SizedBox(height: 18),
              const _ClassroomPrivacyNote(),
              const SizedBox(height: 10),
              const _CatalogVersionNote(),
              const SizedBox(height: 22),
              if (_loading)
                const LinearProgressIndicator(
                  key: ValueKey('local-classroom-loading'),
                )
              else ...[
                if (run != null) ...[
                  if (run.stage == LocalClassroomStage.completed)
                    _CompletedCard(
                      run: run,
                      assignment: resume,
                      busy: _busy,
                      onRepeat: resume == null ? null : () => _start(resume),
                      onDiscard: _discard,
                    )
                  else
                    _ResumeCard(
                      run: run,
                      assignment: resume,
                      busy: _busy,
                      onResume: _resume,
                      onDiscard: _discard,
                    ),
                  const SizedBox(height: 22),
                ],
                _MaterialNumberForm(
                  controller: _number,
                  assignment: assignment,
                  submittedInvalid: _submittedInvalid,
                  busy: _busy,
                  onChanged: (_) => setState(() {
                    _submittedInvalid = false;
                    _loadError = null;
                  }),
                  onSubmit: _startFromNumber,
                  onScan: _scanClassroomCode,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey('local-classroom-teacher-preparation'),
                  onPressed: _busy ? null : _openTeacherPreparation,
                  icon: const Icon(Icons.qr_code_2_outlined),
                  label: Text(
                    l10n.t('先生が教材QRを準備する', 'Teacher: prepare a lesson QR'),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey('local-classroom-browse'),
                  onPressed: _busy ? null : _browse,
                  icon: const Icon(Icons.auto_stories_outlined),
                  label: Text(
                    l10n.t(
                      '教材番号が分からないときは一覧を見る',
                      'Don\'t know the code? See the list',
                    ),
                  ),
                ),
              ],
              if (_loadError case final message?) ...[
                const SizedBox(height: 14),
                _InlineError(message: message, onRetry: _load),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassroomPrivacyNote extends StatelessWidget {
  const _ClassroomPrivacyNote();

  static String get label => l10n.t(
    '外部送信なし。アカウント、生徒名、学校・学級、回答本文は保存しません。'
        '途中または最後に終えた教材と概念、A/B/Cのラウンド、段階、更新日時だけをこの端末に保存します。'
        '学校で終えた授業は個人練習のローテーションに加えません',
    'Nothing is sent out. No accounts, student names, school or class, or answers are saved. '
        'Only the in-progress or last finished lesson and concept, the A/B/C round, the stage, and the update time are saved on this device. '
        'Lessons finished at school are not added to your personal practice rotation',
  );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.appColors;
    return Semantics(
      key: const ValueKey('local-classroom-privacy'),
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
          decoration: BoxDecoration(
            color: colors.coolSurface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.phonelink_lock_outlined, color: colors.onCoolSurface),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.t(
                    '外部へ送りません。アカウント、生徒名、学校・学級、回答本文は保存しません。'
                        '途中または最後に終えた教材・概念・A/B/Cのラウンド・段階・更新日時だけを、'
                        'この端末に1件残します。学校で終えた授業は、個人練習のローテーションには加えません。',
                    'Nothing is sent out. No accounts, student names, school or class, or answers are saved. '
                        'Only one entry (the in-progress or last finished lesson, concept, A/B/C round, stage, and update time) '
                        'is kept on this device. Lessons finished at school are not added to your personal practice rotation.',
                  ),
                  style: t.textTheme.bodySmall?.copyWith(
                    color: colors.onCoolSurface,
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

class _CatalogVersionNote extends StatelessWidget {
  const _CatalogVersionNote();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    return Semantics(
      key: const ValueKey('local-classroom-catalog-version'),
      container: true,
      label: l10n.t(
        '先生と生徒は同じアプリ版を使ってください。教材版が違うと番号の対応が異なる場合があります',
        'Teachers and students should use the same app version. Different lesson versions may map codes differently',
      ),
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.system_update_alt_outlined,
              size: 19,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.t(
                  '先生と生徒は同じアプリ版を使ってください。'
                      '教材版が違うと、番号の対応が異なる場合があります。',
                  'Teachers and students should use the same app version. '
                      'Different lesson versions may map codes differently.',
                ),
                style: t.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
    required this.run,
    required this.assignment,
    required this.busy,
    required this.onResume,
    required this.onDiscard,
  });

  final LocalClassroomRun run;
  final ClassroomAssignment? assignment;
  final bool busy;
  final VoidCallback onResume;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.appColors;
    final found = assignment != null;
    final restart = run.stage == LocalClassroomStage.material
        ? l10n.t(
            '教材の最初から再開します。',
            'You\'ll restart from the beginning of the lesson.',
          )
        : l10n.t(
            '入力内容は保存していないため、説明の最初から再開します。',
            'What you typed was not saved, so you\'ll restart from the beginning of your explanation.',
          );
    return Semantics(
      key: const ValueKey('local-classroom-resume-card'),
      container: true,
      label: found
          ? l10n.t(
              '途中の授業。教材番号${assignment!.classroomCode}、${assignment!.mission.conceptLabel}、${assignment!.round.label}。$restart',
              'Lesson in progress. Code ${assignment!.classroomCode}, ${assignment!.mission.conceptLabel}, ${assignment!.round.label}. $restart',
            )
          : l10n.t(
              '途中の教材は現在の同梱教材にありません。再開位置を消せます',
              'The lesson in progress isn\'t in the current built-in lessons. You can delete the resume point',
            ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
        decoration: BoxDecoration(
          color: colors.warmSurface,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.t('途中の授業', 'Lesson in progress'),
                    style: t.textTheme.labelLarge
                        ?.copyWith(color: colors.onWarmSurface)
                        .jaWeight(FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    found
                        ? '${assignment!.classroomCode}  ${assignment!.mission.conceptLabel}'
                        : l10n.t(
                            'この教材は現在のカタログにありません',
                            'This lesson isn\'t in the current catalog',
                          ),
                    style: t.textTheme.titleMedium
                        ?.copyWith(color: colors.onWarmSurface)
                        .jaWeight(FontWeight.w700),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    found
                        ? l10n.t(
                            '${assignment!.round.label}。$restart',
                            '${assignment!.round.label}. $restart',
                          )
                        : l10n.t(
                            '教材の更新後に見つからないため、再開はできません。',
                            'It can\'t be found after the lesson update, so it can\'t be resumed.',
                          ),
                    style: t.textTheme.bodySmall?.copyWith(
                      color: colors.onWarmSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (found) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const ValueKey('local-classroom-resume'),
                onPressed: busy ? null : onResume,
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  busy
                      ? l10n.t('開いています…', 'Opening…')
                      : l10n.t('この教材を再開', 'Resume this lesson'),
                ),
              ),
            ],
            const SizedBox(height: 4),
            TextButton(
              key: const ValueKey('local-classroom-discard'),
              onPressed: busy ? null : onDiscard,
              child: Text(l10n.t('途中の再開位置を消す', 'Delete resume point')),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedCard extends StatelessWidget {
  const _CompletedCard({
    required this.run,
    required this.assignment,
    required this.busy,
    required this.onRepeat,
    required this.onDiscard,
  });

  final LocalClassroomRun run;
  final ClassroomAssignment? assignment;
  final bool busy;
  final VoidCallback? onRepeat;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.appColors;
    final found = assignment != null;
    final completedAt = _formatLocalClassroomDateTime(run.updatedAt);
    final reference = found
        ? l10n.t(
            '教材番号${assignment!.classroomCode}、${assignment!.mission.conceptLabel}、${assignment!.round.label}',
            'Code ${assignment!.classroomCode}, ${assignment!.mission.conceptLabel}, ${assignment!.round.label}',
          )
        : l10n.t(
            '最後に終えた教材は現在の同梱教材にありません',
            'The last finished lesson isn\'t in the current built-in lessons',
          );
    return Semantics(
      key: const ValueKey('local-classroom-completed-card'),
      container: true,
      label: l10n.t(
        '最後に終えた授業。$reference。完了日時$completedAt。'
            '比較フローの操作完了。内容と理解は未確認です。回答本文は保存していません。'
            '個人練習のローテーションには加えていません',
        'Last finished lesson. $reference. Completed $completedAt. '
            'Comparison steps done. Content and understanding not checked. Your answers were not saved. '
            'Not added to your personal practice rotation',
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
        decoration: BoxDecoration(
          color: colors.coolSurface,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.task_alt_outlined,
                        color: colors.onCoolSurface,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          l10n.t('最後に終えた授業', 'Last finished lesson'),
                          style: t.textTheme.labelLarge
                              ?.copyWith(color: colors.onCoolSurface)
                              .jaWeight(FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    found
                        ? '${assignment!.classroomCode}  ${assignment!.mission.conceptLabel}'
                        : l10n.t(
                            'この教材は現在のカタログにありません',
                            'This lesson isn\'t in the current catalog',
                          ),
                    style: t.textTheme.titleMedium
                        ?.copyWith(color: colors.onCoolSurface)
                        .jaWeight(FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    found
                        ? l10n.t(
                            '${assignment!.round.label} · 完了日時 $completedAt',
                            '${assignment!.round.label} · Completed $completedAt',
                          )
                        : l10n.t('完了日時 $completedAt', 'Completed $completedAt'),
                    style: t.textTheme.bodySmall?.copyWith(
                      color: colors.onCoolSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.t(
                      '比較フローの操作完了。内容・理解は未確認です。',
                      'Comparison steps done. Content and understanding not checked.',
                    ),
                    style: t.textTheme.bodyMedium
                        ?.copyWith(color: colors.onCoolSurface)
                        .jaWeight(FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    l10n.t(
                      '回答本文は保存していません。学校で終えた授業は、個人練習のローテーションには加えていません。',
                      'Your answers were not saved. Lessons finished at school are not added to your personal practice rotation.',
                    ),
                    style: t.textTheme.bodySmall?.copyWith(
                      color: colors.onCoolSurface,
                    ),
                  ),
                ],
              ),
            ),
            if (onRepeat != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                key: const ValueKey('local-classroom-repeat-completed'),
                onPressed: busy ? null : onRepeat,
                icon: const Icon(Icons.replay_outlined),
                label: Text(
                  busy
                      ? l10n.t('開いています…', 'Opening…')
                      : l10n.t('同じ教材をもう一度', 'Do the same lesson again'),
                ),
              ),
            ],
            const SizedBox(height: 4),
            TextButton(
              key: const ValueKey('local-classroom-discard-completed'),
              onPressed: busy ? null : onDiscard,
              child: Text(l10n.t('完了表示を消す', 'Delete completion')),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatLocalClassroomDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${local.year}/${two(local.month)}/${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

class _MaterialNumberForm extends StatelessWidget {
  const _MaterialNumberForm({
    required this.controller,
    required this.assignment,
    required this.submittedInvalid,
    required this.busy,
    required this.onChanged,
    required this.onSubmit,
    required this.onScan,
  });

  final TextEditingController controller;
  final ClassroomAssignment? assignment;
  final bool submittedInvalid;
  final bool busy;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 17),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.t('黒板の教材番号', 'Lesson code on the board'),
            style: t.textTheme.titleMedium?.jaWeight(FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            l10n.t(
              '例：01-02-A（概念01-02の、ラウンドA）',
              'Example: 01-02-A (concept 01-02, round A)',
            ),
            style: t.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.t(
              'A：原理　B：条件　C：別の場面。A/B/Cまで黒板どおり入力します。',
              'A: principle  B: conditions  C: new situation. Type it exactly as on the board, including A/B/C.',
            ),
            style: t.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('local-classroom-number'),
            controller: controller,
            enabled: !busy,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.go,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l10n.t('教材番号', 'Lesson code'),
              hintText: '01-02-A',
              errorText: submittedInvalid
                  ? l10n.t(
                      'A/B/Cまで含む、一覧の教材番号を入力してください',
                      'Enter a lesson code from the list, including A/B/C',
                    )
                  : null,
            ),
            onChanged: onChanged,
            onSubmitted: (_) => onSubmit(),
          ),
          if (assignment != null) ...[
            const SizedBox(height: 12),
            Semantics(
              key: const ValueKey('local-classroom-number-match'),
              container: true,
              label: l10n.t(
                '教材番号${assignment!.classroomCode}、${assignment!.mission.conceptLabel}、${assignment!.mission.unit.title}、${assignment!.round.label}',
                'Code ${assignment!.classroomCode}, ${assignment!.mission.conceptLabel}, ${assignment!.mission.unit.title}, ${assignment!.round.label}',
              ),
              child: ExcludeSemantics(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${assignment!.classroomCode}  ${assignment!.mission.conceptLabel}',
                        style: t.textTheme.titleSmall
                            ?.copyWith(color: scheme.onPrimaryContainer)
                            .jaWeight(FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${assignment!.mission.unit.title} · ${assignment!.round.label}',
                        style: t.textTheme.bodySmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('local-classroom-scan-code'),
              onPressed: busy ? null : onScan,
              icon: const Icon(Icons.qr_code_scanner_outlined),
              label: Text(l10n.t('教材QRを読み取る', 'Scan lesson QR')),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const ValueKey('local-classroom-start'),
            onPressed: busy ? null : onSubmit,
            icon: const Icon(Icons.arrow_forward),
            label: Text(
              busy
                  ? l10n.t('教材を開いています…', 'Opening lesson…')
                  : l10n.t('この教材を開く', 'Open this lesson'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 先生が板書の代わりに、端末内教材のQRを表示する画面。
///
/// これは名簿・成績・学校サーバーを扱わない「授業準備」だけの画面である。
/// 認証付きの先生用集計は、この端末内モードと混同しない。
class TeacherLocalClassroomScreen extends StatefulWidget {
  const TeacherLocalClassroomScreen({super.key, required this.units});

  final UnitsClient units;

  @override
  State<TeacherLocalClassroomScreen> createState() =>
      _TeacherLocalClassroomScreenState();
}

class _TeacherLocalClassroomScreenState
    extends State<TeacherLocalClassroomScreen> {
  List<ClassroomAssignment> _assignments = const [];
  ClassroomAssignment? _selected;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final units = await widget.units.list();
      if (!mounted) return;
      final assignments = ClassroomAssignment.fromMissions(
        ClassroomMission.fromUnits(units),
      );
      setState(() {
        _assignments = assignments;
        _selected = assignments.isEmpty ? null : assignments.first;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = l10n.t(
          '端末内の教材を読み込めませんでした。',
          'Couldn\'t load the lessons on this device.',
        ),
      );
    }
  }

  Future<void> _chooseAssignment() async {
    final picked = await Navigator.of(context).push<ClassroomAssignment>(
      MaterialPageRoute<ClassroomAssignment>(
        builder: (_) =>
            ClassroomAssignmentListScreen(assignments: _assignments),
      ),
    );
    if (mounted && picked != null) setState(() => _selected = picked);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final theme = Theme.of(context);
    final assignment = _selected;
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(title: Text(l10n.t('先生の授業準備', 'Teacher lesson prep'))),
      body: SafeArea(
        top: false,
        child: ReadableWidth(
          child: ListView(
            key: const ValueKey('teacher-local-classroom-screen'),
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 48),
            children: [
              Semantics(
                header: true,
                child: Text(
                  l10n.t('教材QRを準備する', 'Prepare a lesson QR'),
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(color: colors.ink)
                      .jaWeight(FontWeight.w900),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.t(
                  'このQRには同梱教材の番号だけが入ります。生徒名、学級、回答、成績、端末ID、LANの管理キーは扱いません。生徒は読み取った後に教材名を確認してから開始します。',
                  'This QR contains only a built-in lesson code. No student names, classes, answers, grades, device IDs, or LAN admin keys. Students check the lesson name after scanning, then start.',
                ),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.inkMuted,
                ),
              ),
              const SizedBox(height: 20),
              if (_error case final message?)
                _InlineError(message: message, onRetry: _load)
              else if (assignment == null)
                const Center(child: CircularProgressIndicator())
              else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    border: Border.all(color: colors.border),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${assignment.classroomCode}  ${assignment.mission.conceptLabel}',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(color: colors.ink)
                            .jaWeight(FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.t(
                          '${assignment.mission.unit.title}・${assignment.round.label}',
                          '${assignment.mission.unit.title} · ${assignment.round.label}',
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: ParticipantQrCode(
                          data: assignment.classroomQrPayload,
                          semanticLabel: l10n.t(
                            '教材QR。教材番号${assignment.classroomCode}。個人情報やLANの参加情報は含まれていません。',
                            'Lesson QR. Code ${assignment.classroomCode}. Contains no personal info or LAN join info.',
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          key: const ValueKey('teacher-local-classroom-select'),
                          onPressed: _chooseAssignment,
                          icon: const Icon(Icons.edit_note_outlined),
                          label: Text(
                            l10n.t('教材とラウンドを選ぶ', 'Choose lesson and round'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.t(
                    'この端末内モードは、認証付きの先生管理画面や成績集計ではありません。学校サーバーへ接続せず、QRの利用記録も保存しません。',
                    'This on-device mode is not a signed-in teacher dashboard or gradebook. It never connects to a school server and does not log QR use.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.inkMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 教師が板書するコードを、ラウンドまで省略せず確認する一覧。
///
/// 通常の教材pickerへ委譲するとA/B/Cが決まらず、端末履歴へ判断を戻してしまう。
/// そのため教室フロー内だけは、概念とroundを1つの選択として返す。
class ClassroomAssignmentListScreen extends StatelessWidget {
  const ClassroomAssignmentListScreen({super.key, required this.assignments});

  final List<ClassroomAssignment> assignments;

  @override
  Widget build(BuildContext context) {
    final missions = <ClassroomMission>[];
    final seen = <String>{};
    for (final assignment in assignments) {
      if (seen.add(assignment.mission.id)) missions.add(assignment.mission);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('教材番号の一覧', 'Lesson code list'))),
      body: SafeArea(
        top: false,
        child: ReadableWidth(
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(
              18,
              12,
              18,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            itemCount: missions.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              if (index == 0) {
                return StudioPageIntro(
                  eyebrow: l10n.t(
                    'CODE LIST  /  A・B・C',
                    'CODE LIST  /  A · B · C',
                  ),
                  title: l10n.t('問いまで同じにする。', 'Match down to the question.'),
                  body: l10n.t(
                    '先生が示すのは「01-02-A」のようなA/B/C付きの番号です。文字まで同じ番号を選びます。',
                    'Your teacher shows a code with A/B/C, like "01-02-A". Pick the exact same code, letter included.',
                  ),
                );
              }
              final mission = missions[index - 1];
              final rounds = assignments
                  .where((assignment) => assignment.mission.id == mission.id)
                  .toList(growable: false);
              return _AssignmentListCard(mission: mission, assignments: rounds);
            },
          ),
        ),
      ),
    );
  }
}

class _AssignmentListCard extends StatelessWidget {
  const _AssignmentListCard({required this.mission, required this.assignments});

  final ClassroomMission mission;
  final List<ClassroomAssignment> assignments;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${mission.materialNumber}  ${mission.conceptLabel}',
            style: t.textTheme.titleSmall?.jaWeight(FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            mission.unit.title,
            style: t.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          for (var index = 0; index < assignments.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            Semantics(
              button: true,
              onTap: () => Navigator.of(context).pop(assignments[index]),
              label: l10n.t(
                '教材番号${assignments[index].classroomCode}、${mission.conceptLabel}、${assignments[index].round.label}',
                'Code ${assignments[index].classroomCode}, ${mission.conceptLabel}, ${assignments[index].round.label}',
              ),
              child: ExcludeSemantics(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: OutlinedButton(
                    key: ValueKey(
                      'local-classroom-assignment-${assignments[index].classroomCode}',
                    ),
                    onPressed: () =>
                        Navigator.of(context).pop(assignments[index]),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${assignments[index].classroomCode}  ${assignments[index].round.label}',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PracticePreparingScreen extends StatefulWidget {
  const _PracticePreparingScreen({
    required this.runStore,
    required this.unitId,
    required this.conceptKey,
    required this.practiceAttempt,
    required this.route,
  });

  final LocalClassroomRunStore runStore;
  final String unitId;
  final String conceptKey;
  final int practiceAttempt;
  final MaterialPageRoute<void> Function() route;

  @override
  State<_PracticePreparingScreen> createState() =>
      _PracticePreparingScreenState();
}

class _PracticePreparingScreenState extends State<_PracticePreparingScreen> {
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _saveAndOpen();
  }

  Future<void> _saveAndOpen() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.runStore.enterPractice(
        unitId: widget.unitId,
        conceptKey: widget.conceptKey,
        practiceAttempt: widget.practiceAttempt,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(widget.route());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l10n.t(
          '練習の再開位置を保存できませんでした。',
          'Couldn\'t save your practice resume point.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(l10n.t('練習を準備', 'Preparing practice'))),
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error == null) ...[
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 16),
                Text(
                  l10n.t(
                    '端末内に再開位置を残しています',
                    'Your resume point is kept on this device',
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 14),
                FilledButton(
                  key: const ValueKey('local-classroom-practice-retry'),
                  onPressed: _saveAndOpen,
                  child: Text(
                    l10n.t('もう一度保存して練習へ', 'Save again and go to practice'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            TextButton(
              onPressed: onRetry,
              child: Text(l10n.t('もう一度読み込む', 'Reload')),
            ),
          ],
        ),
      ),
    );
  }
}
