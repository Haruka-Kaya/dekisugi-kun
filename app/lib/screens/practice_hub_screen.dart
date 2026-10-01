import '../config/app_language.dart' as lang;
import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../learning/domain/learning_economy.dart';
import '../learning/services/daily_audio_practice_plan.dart';
import '../models/game_hub.dart';
import '../models/game_path.dart';
import '../ui/_material.dart';
import '../widgets/daily_audio_practice_panel.dart';
import '../widgets/game_page.dart';

class PracticeHubScreen extends StatelessWidget {
  const PracticeHubScreen({
    super.key,
    required this.modes,
    required this.dueCount,
    required this.onOpen,
    this.dailyAudioPlan,
    this.onOpenDailyAudio,
    this.mascotStyle = LearningPathMascotStyle.standard,
  }) : assert(
         dailyAudioPlan == null || onOpenDailyAudio != null,
         'onOpenDailyAudio is required when dailyAudioPlan is provided.',
       );

  final List<PracticeModeView> modes;
  final int dueCount;
  final ValueChanged<PracticeModeView> onOpen;
  final DailyAudioPracticePlan? dailyAudioPlan;
  final ValueChanged<DailyAudioMission>? onOpenDailyAudio;
  final LearningPathMascotStyle mascotStyle;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final hasDueReview = dueCount > 0;
    final dueBackground = hasDueReview
        ? colors.pathReview
        : colors.surfaceRaised;
    final dueForeground = hasDueReview ? colors.onPathReview : colors.ink;
    return GamePageScaffold(
      scrollKey: const ValueKey('practice-hub-screen'),
      children: [
        GameHeroSurface(
          surfaceKey: const ValueKey('practice-due-summary'),
          color: dueBackground,
          foregroundColor: dueForeground,
          eyebrow: lang.t('練習ラボ', 'Practice Lab'),
          title: dueCount == 0
              ? lang.t('次の復習を準備中', 'Preparing your next review')
              : lang.t('今日の復習 $dueCount件', 'Today\'s reviews: $dueCount'),
          body: dueCount == 0
              ? lang.t(
                  '忘れかけたところを、違う方法で取り出します。復習は翌学習日から届きます。',
                  'Recall what you\'re starting to forget in a new way. Reviews arrive from your next study day.',
                )
              : lang.t(
                  '思い出す→別場面へ使う。終えると次の間隔が開きます。',
                  'Recall → apply to a new scenario. Finish to set the next interval.',
                ),
          semanticSummary: dueCount == 0
              ? lang.t(
                  '今日が期限の復習はありません。次の復習を準備中',
                  'No reviews due today. Preparing your next review',
                )
              : lang.t(
                  '今日が期限の復習、$dueCount件。思い出し練習ができます',
                  '$dueCount reviews due today. Recall practice is available',
                ),
          mascotReaction: hasDueReview
              ? GameCharacterReaction.encourage
              : GameCharacterReaction.invite,
          mascotStyle: mascotStyle,
          content: GameSolidSurface(
            padding: const EdgeInsets.all(GameTokens.spaceMd),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  hasDueReview
                      ? Icons.notifications_active_outlined
                      : Icons.route_outlined,
                  color: colors.pathReview,
                ),
                const SizedBox(width: GameTokens.spaceSm),
                Expanded(
                  child: Text(
                    hasDueReview
                        ? lang.t(
                            '今日の期限を終えても、他の練習は自由に選べます。',
                            'Even after today\'s reviews, you can freely choose other practice.',
                          )
                        : lang.t(
                            '探究ノートはいつでも進められます。',
                            'You can continue the learning path anytime.',
                          ),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.ink),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (dailyAudioPlan case final plan?) ...[
          const SizedBox(height: GameTokens.spaceXl),
          GameSectionHeader(
            title: lang.t('音声観察', 'Audio missions'),
            description: lang.t(
              '聞く課題と話す課題を、別々の学習として開きます。',
              'Listening and speaking tasks open as separate activities.',
            ),
          ),
          const SizedBox(height: GameTokens.spaceMd),
          DailyAudioPracticePanel(plan: plan, onOpen: onOpenDailyAudio!),
        ],
        const SizedBox(height: GameTokens.spaceXl),
        GameSectionHeader(
          title: lang.t('練習メニュー', 'Practice menu'),
          description: lang.t(
            '今の学習状態に必要な方法を選びます。準備中の項目は開きません。',
            'Choose what you need right now. Items in preparation are locked.',
          ),
        ),
        const SizedBox(height: GameTokens.spaceMd),
        if (modes.isEmpty)
          GameSolidSurface(
            raised: true,
            child: Text(
              lang.t('練習メニューを準備しています。', 'Preparing the practice menu.'),
            ),
          )
        else
          GameResponsiveGrid(
            children: [
              for (final mode in modes)
                _PracticeLane(mode: mode, onOpen: () => onOpen(mode)),
            ],
          ),
        const SizedBox(height: GameTokens.spaceXl),
        GameSolidSurface(
          surfaceKey: const ValueKey('practice-policy'),
          raised: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: colors.inkMuted),
              const SizedBox(width: GameTokens.spaceSm),
              Expanded(
                child: Text(
                  lang.t(
                    '時間観察は任意です。時間切れでも探究ノート、連続観測、学校課題は失いません。',
                    'Timed modes are optional. Running out of time won\'t cost your learning path, streak, or school assignments.',
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.inkMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PracticeLane extends StatelessWidget {
  const _PracticeLane({required this.mode, required this.onOpen});

  final PracticeModeView mode;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    final icon = switch (mode.kind) {
      PracticeModeKind.heartRecovery => Icons.battery_charging_full_rounded,
      PracticeModeKind.personalized => Icons.tune_rounded,
      PracticeModeKind.resume => Icons.play_arrow_rounded,
      PracticeModeKind.repair => Icons.build_circle_outlined,
      PracticeModeKind.listenSpeak => Icons.record_voice_over_outlined,
      PracticeModeKind.diagram => Icons.account_tree_outlined,
      PracticeModeKind.timed => Icons.timer_outlined,
      PracticeModeKind.match => Icons.grid_view_rounded,
      PracticeModeKind.lightning => Icons.playlist_add_check_rounded,
    };
    return Semantics(
      button: mode.enabled,
      enabled: mode.enabled,
      label: lang.t(
        '${mode.title}。${mode.description}'
            '。${mode.enabled ? '利用できます' : '準備中'}'
            '${mode.badge == null ? '' : '。${mode.badge}'}',
        '${mode.title}. ${mode.description}'
            '. ${mode.enabled ? 'Available' : 'Coming soon'}'
            '${mode.badge == null ? '' : '. ${mode.badge}'}',
      ),
      onTap: mode.enabled ? onOpen : null,
      child: ExcludeSemantics(
        child: Material(
          key: ValueKey('practice-mode-${mode.id}'),
          color: mode.enabled ? colors.surface : colors.surfaceRaised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(GameTokens.radiusMd),
            side: BorderSide(color: colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: mode.enabled ? onOpen : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: GameTokens.hubTileMinHeight,
              ),
              child: Padding(
                padding: const EdgeInsets.all(GameTokens.spaceLg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      key: ValueKey('practice-mode-icon-${mode.id}'),
                      width: GameTokens.minTouchTarget,
                      height: GameTokens.minTouchTarget,
                      decoration: BoxDecoration(
                        color: mode.enabled
                            ? colors.pathReview
                            : colors.pathLocked,
                        borderRadius: BorderRadius.circular(
                          GameTokens.radiusSm,
                        ),
                      ),
                      child: Icon(
                        icon,
                        color: mode.enabled
                            ? colors.onPathReview
                            : colors.onPathLocked,
                      ),
                    ),
                    const SizedBox(width: GameTokens.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mode.title,
                            style: t.textTheme.titleMedium
                                ?.copyWith(color: colors.ink)
                                .jaWeight(FontWeight.w800),
                          ),
                          const SizedBox(height: GameTokens.spaceXs),
                          Text(
                            mode.description,
                            style: t.textTheme.bodySmall?.copyWith(
                              color: colors.inkMuted,
                            ),
                          ),
                          const SizedBox(height: GameTokens.spaceSm),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                mode.enabled
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.lock_outline_rounded,
                                size: GameTokens.statusIconSize,
                                color: mode.enabled
                                    ? colors.pathReview
                                    : colors.inkMuted,
                              ),
                              const SizedBox(width: GameTokens.spaceXs),
                              Expanded(
                                child: Text(
                                  mode.enabled
                                      ? mode.badge == null
                                            ? lang.t('利用できます', 'Available')
                                            : lang.t(
                                                '利用できます ・ ${mode.badge}',
                                                'Available · ${mode.badge}',
                                              )
                                      : mode.badge == null
                                      ? lang.t('準備中', 'Coming soon')
                                      : lang.t(
                                          '準備中 ・ ${mode.badge}',
                                          'Coming soon · ${mode.badge}',
                                        ),
                                  style: t.textTheme.labelMedium
                                      ?.copyWith(
                                        color: mode.enabled
                                            ? colors.pathReview
                                            : colors.inkMuted,
                                      )
                                      .jaWeight(FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: GameTokens.spaceXs),
                    Icon(
                      mode.enabled ? Icons.chevron_right : Icons.lock_outline,
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
