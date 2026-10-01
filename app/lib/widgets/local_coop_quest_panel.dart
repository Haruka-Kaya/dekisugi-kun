import '../config/app_language.dart' as localize;
import '../config/app_language.dart' as lang;
import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../learning/domain/learning_progress.dart';
import '../ui/_material.dart';

class LocalCoopQuestPanel extends StatelessWidget {
  const LocalCoopQuestPanel({
    super.key,
    required this.run,
    required this.selectedParticipantId,
    required this.onStart,
    required this.onSelectParticipant,
    this.unavailableReason,
  });

  final LearningLocalCoopRun? run;
  final String? selectedParticipantId;
  final VoidCallback onStart;
  final ValueChanged<String> onSelectParticipant;
  final String? unavailableReason;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    final active = run;
    return Container(
      key: const ValueKey('local-coop-quest-panel'),
      padding: const EdgeInsets.all(GameTokens.spaceLg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(GameTokens.radiusMd),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              key: const ValueKey('local-coop-record-rule'),
              width: 64,
              height: 4,
              color: colors.caseFile,
            ),
          ),
          const SizedBox(height: GameTokens.spaceMd),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.group_work_outlined, color: colors.caseFile, size: 30),
              const SizedBox(width: GameTokens.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lang.t('ふたりの共同観察', 'On-device pair quest'),
                      style: t.textTheme.titleLarge
                          ?.copyWith(color: colors.ink)
                          .jaWeight(FontWeight.w900),
                    ),
                    const SizedBox(height: GameTokens.spaceXs),
                    Text(
                      lang.t(
                        '実在する2人がこの端末を手渡し、それぞれ観察記録を1件ずつ残します。名前・回答・正誤は保存しません。',
                        'Two real people pass this device and each finish one lesson. Names, answers, and results are not saved.',
                      ),
                      style: t.textTheme.bodySmall?.copyWith(
                        color: colors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: GameTokens.spaceMd),
          if (active == null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  key: const ValueKey('local-coop-start'),
                  onPressed: unavailableReason == null ? onStart : null,
                  icon: const Icon(Icons.group_add_outlined),
                  label: Text(lang.t('ふたりの観察を準備する', 'Create a 2-person quest')),
                ),
                if (unavailableReason case final reason?) ...[
                  const SizedBox(height: GameTokens.spaceSm),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      reason,
                      key: const ValueKey('local-coop-unavailable-reason'),
                      style: t.textTheme.bodySmall?.copyWith(
                        color: colors.inkMuted,
                      ),
                    ),
                  ),
                ],
              ],
            )
          else ...[
            Semantics(
              label: localize.t(
                'ふたりの共同観察、${active.target}件中${active.progress}件${active.completed ? '、達成済み' : '、進行中'}、結晶${active.rewardGems}個',
                'Partner observation, ${active.progress} of ${active.target}, ${active.completed ? 'completed' : 'in progress'}, ${active.rewardGems} gems',
              ),
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LinearProgressIndicator(
                      value: (active.progress / active.target).clamp(0.0, 1.0),
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(GameTokens.radiusXs),
                      color: active.completed
                          ? colors.pathComplete
                          : colors.caseFile,
                      backgroundColor: colors.border,
                    ),
                    const SizedBox(height: GameTokens.spaceXs),
                    Text(
                      localize.t(
                        '観察記録 ${active.progress} / ${active.target}  ・  結晶 ${active.rewardGems}',
                        'Observations ${active.progress} / ${active.target} · Gems ${active.rewardGems}',
                      ),
                      textAlign: TextAlign.end,
                      style: t.textTheme.labelLarge?.copyWith(
                        color: colors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: GameTokens.spaceMd),
            if (active.completed)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, color: colors.pathComplete),
                  const SizedBox(width: GameTokens.spaceSm),
                  Expanded(
                    child: Text(
                      lang.t(
                        'ふたりの観察記録がそろいました。報酬は端末内の個人の結晶残高へ一度だけ記録済みです。',
                        'Both learners are done. The reward was recorded once to the personal wallet on this device.',
                      ),
                      style: t.textTheme.bodyMedium?.copyWith(
                        color: colors.ink,
                      ),
                    ),
                  ),
                ],
              )
            else ...[
              Text(
                lang.t('次に観察する人を選ぶ', 'Choose who learns next'),
                style: t.textTheme.titleSmall
                    ?.copyWith(color: colors.ink)
                    .jaWeight(FontWeight.w800),
              ),
              const SizedBox(height: GameTokens.spaceSm),
              for (final entry in active.participantIds.toList()..sort()) ...[
                _ParticipantButton(
                  slotNumber:
                      (active.participantIds.toList()..sort()).indexOf(entry) +
                      1,
                  participantId: entry,
                  contributed: active.contributingParticipantIds.contains(
                    entry,
                  ),
                  selected: selectedParticipantId == entry,
                  onTap: () => onSelectParticipant(entry),
                ),
                const SizedBox(height: GameTokens.spaceSm),
              ],
              Text(
                selectedParticipantId == null
                    ? lang.t(
                        '人を選んでから探究ノートへ戻り、初回観察または期限の来た再観察を1件終えてください。',
                        'Choose a person, then go back to the Path and finish one new lesson or due review.',
                      )
                    : lang.t(
                        '選択中です。次に完了した意味のある観察1件だけを、この枠へ記録します。',
                        'Selected. Only the next meaningful lesson finished will be recorded to this slot.',
                      ),
                style: t.textTheme.bodySmall?.copyWith(color: colors.inkMuted),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ParticipantButton extends StatelessWidget {
  const _ParticipantButton({
    required this.slotNumber,
    required this.participantId,
    required this.contributed,
    required this.selected,
    required this.onTap,
  });

  final int slotNumber;
  final String participantId;
  final bool contributed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = lang.t('$slotNumber人目', 'Person $slotNumber');
    return Semantics(
      button: !contributed,
      enabled: !contributed,
      selected: selected,
      label:
          '$label、${contributed
              ? localize.t('観察記録済み', "Observation recorded")
              : selected
              ? localize.t('次に観察する人として選択中', "Selected as the next observer")
              : localize.t('未選択', "Not selected")}',
      onTap: contributed ? null : onTap,
      child: ExcludeSemantics(
        child: OutlinedButton.icon(
          key: ValueKey('local-coop-participant-$participantId'),
          onPressed: contributed ? null : onTap,
          icon: Icon(
            contributed
                ? Icons.check_circle
                : selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
          ),
          label: Text(
            contributed
                ? lang.t('$label ・ 記録済み', '$label · Recorded')
                : selected
                ? lang.t('$label ・ 選択中', '$label · Selected')
                : lang.t('$labelを選ぶ', 'Choose $label'),
          ),
        ),
      ),
    );
  }
}
