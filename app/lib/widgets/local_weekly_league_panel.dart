import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../learning/services/local_weekly_league_projection.dart';
import '../ui/_material.dart';
import 'game_page.dart';

/// 実在する2〜8人が同じ端末を手渡す、personal専用の週次リーグ。
///
/// 参加者名・account・回答は受け取らず、不透明slotも画面へ表示しない。
class LocalWeeklyLeaguePanel extends StatelessWidget {
  const LocalWeeklyLeaguePanel({
    super.key,
    required this.view,
    this.setupParticipantCount = 2,
    this.onSetupParticipantCountChanged,
    this.onStart,
    this.selectedParticipantId,
    this.onSelectParticipant,
    this.onStartNextRound,
    this.embedded = false,
  }) : assert(setupParticipantCount >= 2 && setupParticipantCount <= 8);

  final LocalWeeklyLeagueView view;
  final int setupParticipantCount;
  final ValueChanged<int>? onSetupParticipantCountChanged;
  final ValueChanged<int>? onStart;
  final String? selectedParticipantId;
  final ValueChanged<String>? onSelectParticipant;
  final VoidCallback? onStartNextRound;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!embedded) ...[
          const _LeagueHeader(),
          const SizedBox(height: GameTokens.spaceLg),
        ],
        switch (view.availability) {
          LocalWeeklyLeagueAvailability.schoolDisabled =>
            const _UnavailableMessage(
              key: ValueKey('local-weekly-league-school-disabled'),
              icon: Icons.school_outlined,
              title: '学校モードでは使いません',
              body: '生徒どうしの個人順位は作らず、授業の課題完了だけを別に扱います。',
            ),
          LocalWeeklyLeagueAvailability.invalidData =>
            const _UnavailableMessage(
              key: ValueKey('local-weekly-league-invalid'),
              icon: Icons.shield_outlined,
              title: '順位を安全に表示できません',
              body: '参加枠や期間が一致しないため、得点を推測せず表示を止めました。',
            ),
          LocalWeeklyLeagueAvailability.notStarted => _LeagueSetup(
            participantCount: setupParticipantCount,
            onParticipantCountChanged: onSetupParticipantCountChanged,
            onStart: onStart,
          ),
          LocalWeeklyLeagueAvailability.active => _ActiveLeague(
            view: view,
            selectedParticipantId: selectedParticipantId,
            onSelectParticipant: onSelectParticipant,
            onStartNextRound: onStartNextRound,
            showRulesDisclosure: !embedded,
          ),
        },
      ],
    );
    return Semantics(
      key: const ValueKey('local-weekly-league-panel'),
      container: true,
      label: _panelSemantics,
      child: embedded
          ? GameSolidSurface(child: content)
          : GameSolidSurface(accent: colors.story, child: content),
    );
  }

  String get _panelSemantics => switch (view.availability) {
    LocalWeeklyLeagueAvailability.schoolDisabled =>
      '端末手渡し共同観測。学校モードでは個人順位を作りません',
    LocalWeeklyLeagueAvailability.invalidData => '端末手渡し共同観測。データを推測せず表示を停止しました',
    LocalWeeklyLeagueAvailability.notStarted => '端末手渡し共同観測。実在する2人から8人で開始できます',
    LocalWeeklyLeagueAvailability.active =>
      '端末手渡し共同観測。実在する${view.participantCount}人、'
          '観察${view.totalMeaningfulEventCount}件、'
          '${view.tierFinalizationEligible ? '週終了後に観測級確定' : '5人未満のため観測級確定なし'}',
  };
}

class _LeagueHeader extends StatelessWidget {
  const _LeagueHeader();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.assignment_outlined,
          color: colors.story,
          size: GameTokens.spaceXxl,
        ),
        const SizedBox(width: GameTokens.spaceSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '端末手渡し共同観測',
                style: t.textTheme.titleLarge
                    ?.copyWith(color: colors.ink)
                    .jaWeight(FontWeight.w900),
              ),
              const SizedBox(height: GameTokens.spaceXs),
              Text(
                'slot 1は「この端末の観測者」、他slotは週内匿名です。架空の相手やオンラインの偽順位は足しません。',
                style: t.textTheme.bodySmall?.copyWith(color: colors.inkMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LeagueSetup extends StatelessWidget {
  const _LeagueSetup({
    required this.participantCount,
    required this.onParticipantCountChanged,
    required this.onStart,
  });

  final int participantCount;
  final ValueChanged<int>? onParticipantCountChanged;
  final ValueChanged<int>? onStart;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '実在する参加者で始める',
          style: t.textTheme.titleSmall
              ?.copyWith(color: colors.ink)
              .jaWeight(FontWeight.w800),
        ),
        const SizedBox(height: GameTokens.spaceSm),
        Text(
          '同じ場所にいる2〜8人が端末を手渡します。2〜4人は途中順位だけ、5〜8人の週は終了後に10段階の観測級を確定します。',
          style: t.textTheme.bodySmall?.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: GameTokens.spaceMd),
        FilledButton.icon(
          key: const ValueKey('local-weekly-league-setup-open'),
          onPressed: onStart == null && onParticipantCountChanged == null
              ? null
              : () => _openSetup(context),
          icon: const Icon(Icons.group_add_outlined),
          label: const Text('人数を決めて始める'),
        ),
      ],
    );
  }

  Future<void> _openSetup(BuildContext context) async {
    var selectedCount = participantCount;
    await showGamePageSheet<void>(
      context: context,
      title: '端末手渡し共同観測を作る',
      child: StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          void update(int next) {
            setSheetState(() => selectedCount = next);
            onParticipantCountChanged?.call(next);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '参加する人数',
                style: Theme.of(sheetContext).textTheme.titleSmall
                    ?.copyWith(color: sheetContext.gamePalette.ink)
                    .jaWeight(FontWeight.w800),
              ),
              const SizedBox(height: GameTokens.spaceSm),
              Semantics(
                label: '参加人数、$selectedCount人',
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _CountButton(
                        key: const ValueKey('local-weekly-league-count-minus'),
                        semanticLabel: '参加人数を1人減らす',
                        icon: Icons.remove,
                        onPressed: selectedCount <= 2
                            ? null
                            : () => update(selectedCount - 1),
                      ),
                      SizedBox(
                        width: GameTokens.countControlLabelWidth,
                        child: Text(
                          '$selectedCount人',
                          textAlign: TextAlign.center,
                          style: Theme.of(sheetContext).textTheme.headlineSmall
                              ?.copyWith(color: sheetContext.gamePalette.ink)
                              .jaWeight(FontWeight.w900),
                        ),
                      ),
                      _CountButton(
                        key: const ValueKey('local-weekly-league-count-plus'),
                        semanticLabel: '参加人数を1人増やす',
                        icon: Icons.add,
                        onPressed: selectedCount >= 8
                            ? null
                            : () => update(selectedCount + 1),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: GameTokens.spaceLg),
              FilledButton.icon(
                key: const ValueKey('local-weekly-league-start'),
                onPressed: onStart == null
                    ? null
                    : () {
                        onStart!(selectedCount);
                        Navigator.of(sheetContext).pop();
                      },
                icon: const Icon(Icons.group_add_outlined),
                label: Text('実在する$selectedCount人で始める'),
              ),
              const SizedBox(height: GameTokens.spaceSm),
              Text(
                'slot 1だけを「この端末の観測者」と明示します。他slotは週内匿名で、名前・account・回答・正誤は保存しません。',
                style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                  color: sheetContext.gamePalette.inkMuted,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CountButton extends StatelessWidget {
  const _CountButton({
    super.key,
    required this.semanticLabel,
    required this.icon,
    required this.onPressed,
  });

  final String semanticLabel;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    label: semanticLabel,
    child: ExcludeSemantics(
      child: IconButton.outlined(
        constraints: const BoxConstraints.tightFor(
          width: GameTokens.minTouchTarget,
          height: GameTokens.minTouchTarget,
        ),
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    ),
  );
}

class _ActiveLeague extends StatelessWidget {
  const _ActiveLeague({
    required this.view,
    required this.selectedParticipantId,
    required this.onSelectParticipant,
    required this.onStartNextRound,
    required this.showRulesDisclosure,
  });

  final LocalWeeklyLeagueView view;
  final String? selectedParticipantId;
  final ValueChanged<String>? onSelectParticipant;
  final VoidCallback? onStartNextRound;
  final bool showRulesDisclosure;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    final canSelect = view.activeRunId != null && onSelectParticipant != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${view.weekKey} 〜 ${view.endDay}',
          style: t.textTheme.labelLarge?.copyWith(color: colors.inkMuted),
        ),
        const SizedBox(height: GameTokens.spaceXs),
        Text(
          '今週の途中経過',
          style: t.textTheme.titleLarge
              ?.copyWith(color: colors.ink)
              .jaWeight(FontWeight.w900),
        ),
        const SizedBox(height: GameTokens.spaceMd),
        GameResponsiveGrid(
          children: [
            for (final standing in view.standings)
              _StandingRow(
                standing: standing,
                selected: selectedParticipantId == standing.participantId,
                onTap: canSelect
                    ? () => onSelectParticipant!(standing.participantId)
                    : null,
              ),
          ],
        ),
        const SizedBox(height: GameTokens.spaceMd),
        _InlineNotice(
          icon: view.tierFinalizationEligible
              ? Icons.fact_check_outlined
              : Icons.info_outline_rounded,
          text: view.tierFinalizationEligible
              ? 'この週は終了後に一度だけ確定します。唯一1位は+1段、唯一最下位は-1段、同率と全員0件は据置です。'
              : '5人未満のため、この週は途中順位を表示しても観測級の履歴を作りません。',
        ),
        if (view.integrityConflictCount > 0) ...[
          const SizedBox(height: GameTokens.spaceMd),
          _InlineNotice(
            icon: Icons.shield_outlined,
            text:
                '重複した学習記録${view.integrityConflictCount}件は、'
                '誰の得点にもせず除外しました。',
          ),
        ],
        const SizedBox(height: GameTokens.spaceMd),
        if (view.activeRunId == null)
          FilledButton.icon(
            key: const ValueKey('local-weekly-league-next-round'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(
                GameTokens.minTouchTarget,
                GameTokens.minTouchTarget,
              ),
            ),
            onPressed: onStartNextRound,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('同じ参加枠で次のラウンドを作る'),
          )
        else
          Text(
            canSelect
                ? '次に観察する人を選ぶと、その人の次の意味ある観察1件だけを数えます。'
                : '次の観察を記録する参加枠は、探究画面側から選べます。',
            style: t.textTheme.bodySmall?.copyWith(color: colors.inkMuted),
          ),
        if (showRulesDisclosure) ...[
          const SizedBox(height: GameTokens.spaceMd),
          OutlinedButton.icon(
            key: const ValueKey('local-weekly-league-rules'),
            onPressed: () => showGamePageSheet<void>(
              context: context,
              title: '端末手渡し共同観測の計測ルール',
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _InlineNotice(
                    icon: Icons.replay_outlined,
                    text: '同じ学習の周回は0件です。同じeventを別の人や別roundへ使い回せません。',
                  ),
                  SizedBox(height: GameTokens.spaceMd),
                  _InlineNotice(
                    icon: Icons.lock_open_outlined,
                    text: '順位や参加枠を選ばなくても、探究ノートと練習はいつでも続けられます。',
                  ),
                  SizedBox(height: GameTokens.spaceMd),
                  _InlineNotice(
                    icon: Icons.shield_outlined,
                    text:
                        'slot 1は「この端末の観測者」、他slotは「2人目〜8人目」と件数だけを使い、名前・account・回答・正誤を表示・保存しません。',
                  ),
                ],
              ),
            ),
            icon: const Icon(Icons.policy_outlined),
            label: const Text('計測ルールと保存範囲'),
          ),
        ],
      ],
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({
    required this.standing,
    required this.selected,
    required this.onTap,
  });

  final LocalWeeklyLeagueStanding standing;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    final rankLabel = standing.rank == null
        ? '順位なし'
        : standing.tied
        ? '同率${standing.rank}位'
        : '${standing.rank}位';
    final semanticLabel =
        '${standing.slotNumber == 1 ? 'この端末の観測者' : '${standing.slotNumber}人目'}、$rankLabel、'
        '観察${standing.meaningfulEventCount}件'
        '${selected ? '、次に観察する人として選択中' : ''}';
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: GameTokens.minTouchTarget),
      child: Padding(
        padding: const EdgeInsets.all(GameTokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: GameTokens.compactAvatarSize,
                  height: GameTokens.compactAvatarSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? colors.story : colors.surfaceRaised,
                    borderRadius: BorderRadius.circular(GameTokens.radiusSm),
                    border: Border.all(color: colors.border),
                  ),
                  child: Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.person_outline,
                    color: selected ? colors.onStory : colors.ink,
                  ),
                ),
                const SizedBox(width: GameTokens.spaceSm),
                Expanded(
                  child: Text(
                    standing.slotNumber == 1
                        ? 'この端末の観測者'
                        : '${standing.slotNumber}人目',
                    style: t.textTheme.titleMedium
                        ?.copyWith(color: colors.ink)
                        .jaWeight(FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: GameTokens.spaceXs),
            Wrap(
              spacing: GameTokens.spaceSm,
              runSpacing: GameTokens.spaceXs,
              children: [
                _StatusLabel(
                  icon: standing.tied
                      ? Icons.people_outline
                      : standing.rank == null
                      ? Icons.horizontal_rule_rounded
                      : Icons.format_list_numbered_rounded,
                  label: rankLabel,
                ),
                _StatusLabel(
                  icon: Icons.school_outlined,
                  label: '${standing.meaningfulEventCount}件',
                ),
                if (selected)
                  const _StatusLabel(
                    icon: Icons.check_circle_outline,
                    label: '選択中',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      selected: selected,
      label: semanticLabel,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? colors.surfaceRaised : colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GameTokens.radiusMd),
            side: BorderSide(
              color: selected ? colors.story : colors.border,
              width: selected ? GameTokens.strongBorderWidth : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: onTap == null
              ? content
              : InkWell(
                  key: ValueKey(
                    'local-weekly-league-participant-${standing.participantId}',
                  ),
                  onTap: onTap,
                  child: content,
                ),
        ),
      ),
    );
  }
}

class _StatusLabel extends StatelessWidget {
  const _StatusLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: colors.inkMuted),
        const SizedBox(width: GameTokens.spaceXs),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: colors.ink),
        ),
      ],
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: colors.inkMuted),
        const SizedBox(width: GameTokens.spaceSm),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
          ),
        ),
      ],
    );
  }
}

class _UnavailableMessage extends StatelessWidget {
  const _UnavailableMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colors.inkMuted, size: GameTokens.spaceXxl),
        const SizedBox(width: GameTokens.spaceSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: t.textTheme.titleMedium
                    ?.copyWith(color: colors.ink)
                    .jaWeight(FontWeight.w800),
              ),
              const SizedBox(height: GameTokens.spaceXs),
              Text(
                body,
                style: t.textTheme.bodySmall?.copyWith(color: colors.inkMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
