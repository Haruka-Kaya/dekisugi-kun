import '../config/app_language.dart';
import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../learning/services/daily_audio_practice_plan.dart';
import '../ui/_material.dart';

class DailyAudioPracticePanel extends StatelessWidget {
  const DailyAudioPracticePanel({
    super.key,
    required this.plan,
    required this.onOpen,
  });

  final DailyAudioPracticePlan plan;
  final ValueChanged<DailyAudioMission> onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('daily-audio-practice-panel'),
      padding: const EdgeInsets.all(GameTokens.spaceLg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(GameTokens.radiusLg),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.hearing_rounded, color: colors.pathReview, size: 30),
              const SizedBox(width: GameTokens.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('今日の音声ミッション', "Today's audio missions"),
                      style: theme.textTheme.titleLarge
                          ?.copyWith(color: colors.ink)
                          .jaWeight(FontWeight.w900),
                    ),
                    const SizedBox(height: GameTokens.spaceXs),
                    Text(
                      t(
                        '聞く課題と話す課題は別々です。どちらも回答・録音を保存しません。',
                        'Listening and speaking are separate tasks. Neither saves your answers or recordings.',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: GameTokens.spaceMd),
          _AudioMissionButton(
            kind: DailyAudioMissionKind.listening,
            mission: plan.missionOf(DailyAudioMissionKind.listening),
            onOpen: onOpen,
          ),
          const SizedBox(height: GameTokens.spaceSm),
          _AudioMissionButton(
            kind: DailyAudioMissionKind.speaking,
            mission: plan.missionOf(DailyAudioMissionKind.speaking),
            onOpen: onOpen,
          ),
        ],
      ),
    );
  }
}

class _AudioMissionButton extends StatelessWidget {
  const _AudioMissionButton({
    required this.kind,
    required this.mission,
    required this.onOpen,
  });

  final DailyAudioMissionKind kind;
  final DailyAudioMission? mission;
  final ValueChanged<DailyAudioMission> onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final theme = Theme.of(context);
    final available = mission != null;
    final title = switch (kind) {
      DailyAudioMissionKind.listening => t('今日の「聞く」', "Today's Listening"),
      DailyAudioMissionKind.speaking => t('今日の「話す」', "Today's Speaking"),
    };
    final description = switch (kind) {
      DailyAudioMissionKind.listening =>
        available
            ? t(
                '${mission!.conceptLabel}の固定説明を聞き、条件を判断します。',
                'Listen to a set explanation of ${mission!.conceptLabel} and judge the conditions.',
              )
            : t(
                'PathでListeningまで進むと開きます。',
                'Unlocks when you reach Listening on the Path.',
              ),
      DailyAudioMissionKind.speaking =>
        available
            ? t(
                '${mission!.conceptLabel}を説明し、自分で再生・再読して比べます。',
                'Explain ${mission!.conceptLabel}, then play it back or reread it to compare.',
              )
            : t(
                'PathでSpeakingまで進むと開きます。',
                'Unlocks when you reach Speaking on the Path.',
              ),
    };
    final icon = switch (kind) {
      DailyAudioMissionKind.listening => Icons.headphones_rounded,
      DailyAudioMissionKind.speaking => Icons.mic_rounded,
    };
    final completedToday = mission?.completedToday ?? false;
    return Semantics(
      button: available,
      enabled: available,
      label:
          '$title${t('。', '. ')}$description${t('。', ' ')}${!available
              ? t('未解放', 'Locked')
              : completedToday
              ? t('今日完了。もう一度練習できます', 'Done today. You can practice again')
              : t('今日の1件、利用できます', "Today's mission is available")}',
      onTap: available ? () => onOpen(mission!) : null,
      child: ExcludeSemantics(
        child: Material(
          key: ValueKey('daily-audio-${kind.name}'),
          color: available ? colors.surfaceRaised : colors.canvas,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GameTokens.radiusMd),
            side: BorderSide(
              color: available ? colors.pathReview : colors.border,
              width: available ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: available ? () => onOpen(mission!) : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 82),
              child: Padding(
                padding: const EdgeInsets.all(GameTokens.spaceMd),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox.square(
                      dimension: GameTokens.minTouchTarget,
                      child: Icon(
                        available ? icon : Icons.lock_outline_rounded,
                        color: available
                            ? colors.pathReview
                            : colors.onPathLocked,
                      ),
                    ),
                    const SizedBox(width: GameTokens.spaceSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(color: colors.ink)
                                .jaWeight(FontWeight.w800),
                          ),
                          const SizedBox(height: GameTokens.spaceXs),
                          Text(
                            description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.inkMuted,
                            ),
                          ),
                          if (completedToday) ...[
                            const SizedBox(height: GameTokens.spaceSm),
                            Row(
                              key: ValueKey(
                                'daily-audio-${kind.name}-completed',
                              ),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 20,
                                  color: colors.pathReview,
                                ),
                                const SizedBox(width: GameTokens.spaceXs),
                                Expanded(
                                  child: Text(
                                    t(
                                      '今日完了／もう一度練習',
                                      'Done today / Practice again',
                                    ),
                                    key: ValueKey(
                                      'daily-audio-${kind.name}-replay',
                                    ),
                                    style: theme.textTheme.labelLarge
                                        ?.copyWith(color: colors.ink)
                                        .jaWeight(FontWeight.w800),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: GameTokens.spaceXs),
                    Icon(
                      available
                          ? Icons.chevron_right_rounded
                          : Icons.lock_outline_rounded,
                      color: colors.inkMuted,
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
