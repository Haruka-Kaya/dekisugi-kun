import '../config/app_language.dart' as lang;
import '../config/app_radius.dart';
import '../config/app_theme.dart';
import '../config/motion.dart';
import '../models/dossier.dart';
import '../models/mission.dart';
import '../ui/_material.dart';

/// 本人が何をすれば進むのかを1つだけ示す、教えるミッションのHUD。
///
/// 進捗率やポイントではなく、実際の説明と誤概念への反応で3段階が進む。
class TeachingMissionBoard extends StatefulWidget {
  const TeachingMissionBoard({
    super.key,
    required this.conceptKey,
    required this.conceptLabel,
    required this.tactic,
    required this.dossier,
    required this.lastLureId,
    this.missionKind = MissionKind.teach,
    this.challengeText,
  });

  final String conceptKey;
  final String conceptLabel;
  final TeachingTactic tactic;
  final Dossier? dossier;
  final String? lastLureId;
  final MissionKind missionKind;
  final String? challengeText;

  @override
  State<TeachingMissionBoard> createState() => _TeachingMissionBoardState();
}

class _TeachingMissionBoardState extends State<TeachingMissionBoard> {
  late MissionSnapshot _previous;

  MissionSnapshot get _snapshot => missionSnapshotFor(
    conceptKey: widget.conceptKey,
    dossier: widget.dossier,
    lastLureId: widget.lastLureId,
  );

  @override
  void initState() {
    super.initState();
    _previous = _snapshot;
  }

  @override
  void didUpdateWidget(TeachingMissionBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _snapshot;
    if (next.step > _previous.step || (next.isClear && !_previous.isClear)) {
      Motion.celebrateHaptic();
    }
    _previous = next;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    final snapshot = _snapshot;
    final copy = _copyFor(snapshot.phase);
    final challenge = snapshot.phase != MissionPhase.teach;
    final missionName = switch (widget.missionKind) {
      MissionKind.teach => lang.t('教えるミッション', 'Teach mission'),
      MissionKind.repair => lang.t('リペアミッション', 'Repair mission'),
      MissionKind.caseRetry => lang.t('ケースミッション', 'Case mission'),
    };

    return Semantics(
      container: true,
      label: lang.t(
        '$missionName、3段階中${snapshot.step}。${widget.conceptLabel}。${copy.title}。${copy.body}',
        '$missionName, step ${snapshot.step} of 3. ${widget.conceptLabel}. ${copy.title}. ${copy.body}',
      ),
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
          decoration: BoxDecoration(
            color: challenge ? c.warmSurface : c.coolSurface,
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            border: snapshot.isClear
                ? Border.all(color: c.gotItFg, width: 2)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      snapshot.isClear
                          ? _clearLabel
                          : '$_missionLabel ${snapshot.step}/3  /  ${widget.conceptLabel}',
                      style: t.textTheme.labelMedium
                          ?.copyWith(
                            color: challenge
                                ? c.onWarmSurface
                                : c.onCoolSurface,
                          )
                          .jaWeight(FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StepDots(step: snapshot.step, clear: snapshot.isClear),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    copy.icon,
                    size: 25,
                    color: challenge ? c.onWarmSurface : c.onCoolSurface,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          copy.title,
                          style: t.textTheme.titleMedium
                              ?.copyWith(
                                color: challenge
                                    ? c.onWarmSurface
                                    : c.onCoolSurface,
                              )
                              .jaWeight(FontWeight.w700),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          copy.body,
                          style: t.textTheme.bodyMedium?.copyWith(
                            color:
                                (challenge ? c.onWarmSurface : c.onCoolSurface)
                                    .withValues(alpha: 0.86),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (snapshot.phase == MissionPhase.teach) ...[
                const SizedBox(height: 13),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
                  decoration: BoxDecoration(
                    color: c.onCoolSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Text(
                    lang.t(
                      '選んだ作戦：${widget.tactic.label}\n${widget.tactic.hint}',
                      'Your strategy: ${widget.tactic.label}\n${widget.tactic.hint}',
                    ),
                    style: t.textTheme.bodySmall?.copyWith(
                      color: c.onCoolSurface,
                    ),
                  ),
                ),
              ] else if (!snapshot.isClear &&
                  widget.challengeText?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 13),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(13, 11, 13, 13),
                  decoration: BoxDecoration(
                    color: c.onWarmSurface.withValues(alpha: 0.08),
                    border: Border(
                      left: BorderSide(color: c.onWarmSurface, width: 3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.t(
                          'LAST CHALLENGE  /  デキすぎ君の考え',
                          'LAST CHALLENGE  /  What Dekisugi-kun thinks',
                        ),
                        style: t.textTheme.labelSmall
                            ?.copyWith(color: c.onWarmSurface)
                            .jaWeight(FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        lang.t(
                          '「${widget.challengeText!.trim()}」',
                          '"${widget.challengeText!.trim()}"',
                        ),
                        style: t.textTheme.bodyMedium
                            ?.copyWith(color: c.onWarmSurface, height: 1.55)
                            .jaWeight(FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String get _missionLabel => switch (widget.missionKind) {
    MissionKind.teach => 'MISSION',
    MissionKind.repair => 'REPAIR',
    MissionKind.caseRetry => 'CASE',
  };

  String get _clearLabel => switch (widget.missionKind) {
    MissionKind.teach => lang.t(
      'MISSION CLEAR  /  教え切った',
      'MISSION CLEAR  /  Fully taught',
    ),
    MissionKind.repair => lang.t(
      'REPAIR CLEAR  /  決着した',
      'REPAIR CLEAR  /  Settled',
    ),
    MissionKind.caseRetry => lang.t(
      'CASE CLEAR  /  別の場面でも使えた',
      'CASE CLEAR  /  Worked in a new situation',
    ),
  };

  ({IconData icon, String title, String body}) _copyFor(
    MissionPhase phase,
  ) => switch ((widget.missionKind, phase)) {
    (MissionKind.caseRetry, MissionPhase.teach) => (
      icon: Icons.travel_explore_outlined,
      title: lang.t('場面の結果を予想する', 'Predict what happens'),
      body: lang.t(
        '答えを思い出すのではなく、この場面で何が起きるかを理由と一緒に話してください。',
        'Do not just recall the answer. Say what will happen in this situation, and why.',
      ),
    ),
    (MissionKind.repair, MissionPhase.teach) => (
      icon: Icons.build_outlined,
      title: lang.t('決着点を組み直す', 'Rebuild the key point'),
      body: lang.t(
        '前に曖昧だったところを、条件や理由までつなげて説明し直してください。',
        'Explain again the part that was unclear before, connecting it to conditions and reasons.',
      ),
    ),
    (_, MissionPhase.teach) => (
      icon: Icons.record_voice_over_outlined,
      title: lang.t('まず、自分の言葉で教える', 'First, teach it in your own words'),
      body: lang.t(
        '覚えた文を当てる問題ではありません。あなたの説明を、声か文字で聞かせてください。',
        'This is not about matching a memorized sentence. Give me your explanation by voice or text.',
      ),
    ),
    (_, MissionPhase.challenge) => (
      icon: Icons.psychology_alt_outlined,
      title: lang.t('デキすぎ君の思い込みを見破る', "Catch Dekisugi-kun's misconception"),
      body: lang.t(
        '相手の考えのどこが違うか、条件や理由をつけて返してください。',
        'Point out what is wrong with his idea, with conditions or reasons.',
      ),
    ),
    (_, MissionPhase.resolve) => (
      icon: Icons.compare_arrows,
      title: lang.t('まだ決着していない', 'Not settled yet'),
      body: lang.t(
        '出てきた2つの考えを比べて、どちらがなぜ正しいかを言い切ってください。',
        'Compare the two ideas that came up and say clearly which one is right and why.',
      ),
    ),
    (MissionKind.caseRetry, MissionPhase.clear) => (
      icon: Icons.verified_outlined,
      title: lang.t('別の場面でも使えた', 'It worked in a new situation'),
      body: lang.t(
        '場面の予想と理由、思い込みへの訂正がつながりました。次は間隔を空けて確かめます。',
        'Your prediction, reason, and correction of the misconception all connected. Next, we will check again after a break.',
      ),
    ),
    (MissionKind.repair, MissionPhase.clear) => (
      icon: Icons.verified_outlined,
      title: lang.t('曖昧だったところに決着した', 'Settled what was unclear'),
      body: lang.t(
        '説明と理由付きの訂正がそろいました。組み直した言葉をノートに残します。',
        'Your explanation and reasoned correction are complete. Your rebuilt words go into the notebook.',
      ),
    ),
    (_, MissionPhase.clear) => (
      icon: Icons.verified_outlined,
      title: lang.t('思い込みを見破った', 'Caught the misconception'),
      body: lang.t(
        '説明と訂正の両方が伝わりました。あなたの言葉をノートに残します。',
        'Both your explanation and your correction came through. Your words go into the notebook.',
      ),
    ),
  };
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.step, required this.clear});

  final int step;
  final bool clear;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 3; i++) ...[
          if (i > 1)
            Container(
              width: 10,
              height: 2,
              color: i <= step
                  ? c.gotItFg
                  : c.onCoolSurface.withValues(alpha: 0.24),
            ),
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= step ? c.gotItFg : Colors.transparent,
              border: Border.all(
                color: i <= step
                    ? c.gotItFg
                    : c.onCoolSurface.withValues(alpha: 0.54),
              ),
            ),
            child: i < step || (clear && i == 3)
                ? Icon(Icons.check, size: 12, color: c.gotItChip)
                : Text(
                    '$i',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: i <= step ? c.gotItChip : c.onCoolSurface,
                      height: 1,
                    ),
                  ),
          ),
        ],
      ],
    );
  }
}
