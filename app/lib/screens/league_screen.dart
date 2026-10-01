import '../config/app_language.dart' as lang;
import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../learning/domain/learning_economy.dart';
import '../learning/domain/learning_progress.dart';
import '../learning/services/local_weekly_league_projection.dart';
import '../models/game_hub.dart';
import '../models/game_path.dart';
import '../models/league_ladder.dart';
import '../ui/_material.dart';
import '../widgets/game_page.dart';
import '../widgets/local_weekly_league_panel.dart';

class LeagueScreen extends StatelessWidget {
  const LeagueScreen({
    super.key,
    required this.player,
    required this.schoolMode,
    this.classCompleted = 0,
    this.classTarget = 0,
    this.history = const [],
    this.localWeeklyLeague,
    this.localWeeklyLeagueSetupParticipantCount = 2,
    this.onLocalWeeklyLeagueSetupParticipantCountChanged,
    this.onStartLocalWeeklyLeague,
    this.selectedLocalWeeklyLeagueParticipantId,
    this.onSelectLocalWeeklyLeagueParticipant,
    this.onStartNextLocalWeeklyLeagueRound,
    this.onOpenLanSocial,
    this.mascotStyle = LearningPathMascotStyle.standard,
  }) : assert(
         localWeeklyLeagueSetupParticipantCount >= 2 &&
             localWeeklyLeagueSetupParticipantCount <= 8,
       );

  final PlayerSummaryView player;
  final bool schoolMode;
  final int classCompleted;
  final int classTarget;
  final List<LearningLeagueWeek> history;
  final LocalWeeklyLeagueView? localWeeklyLeague;
  final int localWeeklyLeagueSetupParticipantCount;
  final ValueChanged<int>? onLocalWeeklyLeagueSetupParticipantCountChanged;
  final ValueChanged<int>? onStartLocalWeeklyLeague;
  final String? selectedLocalWeeklyLeagueParticipantId;
  final ValueChanged<String>? onSelectLocalWeeklyLeagueParticipant;
  final VoidCallback? onStartNextLocalWeeklyLeagueRound;
  final VoidCallback? onOpenLanSocial;
  final LearningPathMascotStyle mascotStyle;

  @override
  Widget build(BuildContext context) {
    final lanSocialOnline = !schoolMode && onOpenLanSocial != null;
    final target = schoolMode ? classTarget : 0;
    final current = schoolMode ? classCompleted : 0;
    final ratio = target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0);
    return GamePageScaffold(
      scrollKey: const ValueKey('league-screen'),
      children: [
        if (schoolMode)
          _SchoolArena(
            current: current,
            target: target,
            ratio: ratio,
            mascotStyle: mascotStyle,
          )
        else if (lanSocialOnline)
          _OnlineArena(onOpen: onOpenLanSocial!, mascotStyle: mascotStyle)
        else
          _LocalArena(
            localWeeklyLeague: localWeeklyLeague,
            setupParticipantCount: localWeeklyLeagueSetupParticipantCount,
            onSetupParticipantCountChanged:
                onLocalWeeklyLeagueSetupParticipantCountChanged,
            onStart: onStartLocalWeeklyLeague,
            selectedParticipantId: selectedLocalWeeklyLeagueParticipantId,
            onSelectParticipant: onSelectLocalWeeklyLeagueParticipant,
            onStartNextRound: onStartNextLocalWeeklyLeagueRound,
            mascotStyle: mascotStyle,
          ),
        if (!schoolMode &&
            !lanSocialOnline &&
            (localWeeklyLeague?.history.isNotEmpty ?? false)) ...[
          const SizedBox(height: GameTokens.spaceXl),
          GameSectionHeader(
            title: lang.t('共同観測の記録', 'Past weeks'),
            description: lang.t(
              'この端末の観測者の実順位から、週終了後に一度だけ確定した記録です。',
              'Final results from real player rankings on this device, set once after each week ends.',
            ),
          ),
          const SizedBox(height: GameTokens.spaceMd),
          GameResponsiveGrid(
            children: [
              for (final week in localWeeklyLeague!.history.take(4))
                _LocalLeagueHistoryRow(week: week),
            ],
          ),
        ],
        const SizedBox(height: GameTokens.spaceXl),
        OutlinedButton.icon(
          key: const ValueKey('league-rules-disclosure'),
          onPressed: () => _showLeagueRules(
            context,
            schoolMode: schoolMode,
            lanSocialOnline: lanSocialOnline,
            hasLocalParticipants: localWeeklyLeague != null,
          ),
          icon: const Icon(Icons.policy_outlined),
          label: Text(lang.t('ルールとプライバシー', 'Rules and privacy')),
        ),
      ],
    );
  }
}

class _LocalLeagueHistoryRow extends StatelessWidget {
  const _LocalLeagueHistoryRow({required this.week});

  final LearningLocalLeagueWeek week;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    final movement = switch (week.movement) {
      LanSocialLeagueMovement.promoted => (
        label: lang.t('上位級へ', 'Promoted'),
        icon: Icons.arrow_upward_rounded,
        color: colors.pathComplete,
      ),
      LanSocialLeagueMovement.stayed => (
        label: lang.t('同級維持', 'Stayed'),
        icon: Icons.horizontal_rule_rounded,
        color: colors.pathActive,
      ),
      LanSocialLeagueMovement.demoted => (
        label: lang.t('下位級へ', 'Demoted'),
        icon: Icons.arrow_downward_rounded,
        color: colors.heart,
      ),
    };
    final rankLabel = week.rank == null
        ? lang.t('順位なし', 'No rank')
        : week.tied
        ? lang.t('同率${week.rank}位', 'Tied for ${week.rank}')
        : lang.t('${week.rank}位', 'Rank ${week.rank}');
    return Semantics(
      container: true,
      label:
          lang.t(
            '${week.weekKey}の週、${week.tier.displayLabel}、$rankLabel、',
            'Week ${week.weekKey}, ${week.tier.label}, $rankLabel,',
          ) +
          lang.t(
            '観察${week.meaningfulEventCount}件、${movement.label}',
            ' ${week.meaningfulEventCount} activities, ${movement.label}',
          ),
      child: ExcludeSemantics(
        child: Container(
          key: ValueKey('local-league-history-${week.weekKey}'),
          padding: const EdgeInsets.all(GameTokens.spaceMd),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(GameTokens.radiusMd),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(movement.icon, color: movement.color),
              const SizedBox(width: GameTokens.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      week.weekKey,
                      style: t.textTheme.labelMedium?.copyWith(
                        color: colors.inkMuted,
                      ),
                    ),
                    Text(
                      '${week.tier.displayLabel} ・ $rankLabel ・ '
                      '観察${week.meaningfulEventCount}件',
                      style: t.textTheme.titleSmall
                          ?.copyWith(color: colors.ink)
                          .jaWeight(FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Text(
                movement.label,
                style: t.textTheme.labelLarge
                    ?.copyWith(color: movement.color)
                    .jaWeight(FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SchoolArena extends StatelessWidget {
  const _SchoolArena({
    required this.current,
    required this.target,
    required this.ratio,
    required this.mascotStyle,
  });

  final int current;
  final int target;
  final double ratio;
  final LearningPathMascotStyle mascotStyle;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final hasMission = target > 0;
    return GameHeroSurface(
      surfaceKey: ValueKey(
        hasMission ? 'league-progress' : 'league-school-local',
      ),
      color: colors.story,
      foregroundColor: colors.onStory,
      eyebrow: lang.t('授業の共同観測', 'Class exploration'),
      title: hasMission
          ? lang.t('この端末の観察目標', 'Class mission on this device')
          : lang.t('同じ課題を、並んで観察する', 'Take on the same task together'),
      body: hasMission
          ? lang.t(
              'この端末の完了だけを表示します。クラス全体の件数と個人順位は作りません。',
              'Only completions on this device are shown. No class totals or individual rankings are created.',
            )
          : lang.t(
              '先生の教材コードで同じ課題を開けます。この端末は個人順位やクラス全体の件数を集計しません。',
              'Use your teacher\'s material code to open the same task. This device does not count individual ranks or class totals.',
            ),
      semanticSummary: hasMission
          ? lang.t(
              'この端末の授業目標、$current、目標$target。クラス全体の件数は集計しません',
              'Class goal on this device: $current of $target. Class totals are not collected.',
            )
          : lang.t(
              '端末内の協力モード。同じ課題に並んで挑む。個人順位とクラス全体の件数は集計しません',
              'Co-op mode on this device. Take on the same task together. No individual ranks or class totals are collected.',
            ),
      mascotReaction: GameCharacterReaction.encourage,
      mascotStyle: mascotStyle,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasMission) ...[
            _ArenaProgress(
              current: current,
              target: target,
              ratio: ratio,
              indicatorKey: const ValueKey('league-progress-indicator'),
            ),
            const SizedBox(height: GameTokens.spaceMd),
          ],
          _ArenaInsetFact(
            icon: Icons.visibility_off_outlined,
            text: lang.t('生徒の個人順位は表示しない', 'No individual student ranks'),
          ),
        ],
      ),
    );
  }
}

class _OnlineArena extends StatelessWidget {
  const _OnlineArena({required this.onOpen, required this.mascotStyle});

  final VoidCallback onOpen;
  final LearningPathMascotStyle mascotStyle;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return GameHeroSurface(
      surfaceKey: const ValueKey('league-lan-social-summary'),
      color: colors.story,
      foregroundColor: colors.onStory,
      eyebrow: lang.t('実参加者の共同観測', 'Real-player league'),
      title: lang.t(
        '同じWi‑Fiの仲間と、今週を観測する',
        'Compete this week with friends on the same Wi-Fi',
      ),
      body: lang.t(
        '実在5〜8人が接続したときだけ開きます。5人未満では順位も人数も表示しません。',
        'Opens only when 5–8 real players connect. Ranks and player counts are hidden below 5.',
      ),
      semanticSummary: lang.t(
        '実参加者の共同観測。実在5人から8人。5人未満では順位と人数を表示しません',
        'Real-player league. 5 to 8 real players. Ranks and player counts stay hidden below 5.',
      ),
      mascotReaction: GameCharacterReaction.invite,
      mascotStyle: mascotStyle,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ArenaInsetFact(
            icon: Icons.wifi_find_rounded,
            text: lang.t(
              '接続前・現在の人数と順位は非表示',
              'Hide player count and ranks before connection',
            ),
          ),
          SizedBox(height: GameTokens.spaceSm),
          _ArenaInsetFact(
            icon: Icons.verified_user_outlined,
            text: lang.t('実参加者だけを匿名表示', 'Show real players anonymously'),
          ),
          SizedBox(height: GameTokens.spaceSm),
          _ArenaInsetFact(
            icon: Icons.fact_check_outlined,
            text: lang.t(
              '観測級01から観測級10までの10段階',
              '10 tiers from Bronze to Diamond',
            ),
          ),
        ],
      ),
      primaryAction: FilledButton.icon(
        key: const ValueKey('league-open-lan-social'),
        style: FilledButton.styleFrom(
          backgroundColor: colors.surface,
          foregroundColor: colors.story,
          minimumSize: const Size.fromHeight(GameTokens.minTouchTarget),
        ),
        onPressed: onOpen,
        icon: const Icon(Icons.radar_rounded),
        label: Text(lang.t('共同観測を開く', 'Connect with friends')),
      ),
    );
  }
}

class _LocalArena extends StatelessWidget {
  const _LocalArena({
    required this.localWeeklyLeague,
    required this.setupParticipantCount,
    required this.onSetupParticipantCountChanged,
    required this.onStart,
    required this.selectedParticipantId,
    required this.onSelectParticipant,
    required this.onStartNextRound,
    required this.mascotStyle,
  });

  final LocalWeeklyLeagueView? localWeeklyLeague;
  final int setupParticipantCount;
  final ValueChanged<int>? onSetupParticipantCountChanged;
  final ValueChanged<int>? onStart;
  final String? selectedParticipantId;
  final ValueChanged<String>? onSelectParticipant;
  final VoidCallback? onStartNextRound;
  final LearningPathMascotStyle mascotStyle;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final tier = localWeeklyLeague?.currentTier ?? LanSocialLeagueTier.bronze;
    return GameHeroSurface(
      surfaceKey: const ValueKey('league-progress'),
      color: colors.pathActive,
      foregroundColor: colors.onPathActive,
      eyebrow: lang.t('実参加者・端末手渡し', 'Real players · shared device'),
      title: lang.t('${tier.displayLabel}の共同観測', '${tier.label} league'),
      body: lang.t(
        'slot 1の「この端末の観測者」を、実在する仲間との週次順位だけで観測級01から観測級10へ進めます。',
        'Player in slot 1 advances from Bronze to Diamond through weekly rankings with real friends only.',
      ),
      semanticSummary: lang.t(
        '${tier.displayLabel}の共同観測。この端末の観測者を実在5人から8人の順位で週終了後に確定',
        '${tier.label} league. The player on this device is ranked with 5 to 8 real players after the week ends.',
      ),
      mascotReaction: GameCharacterReaction.celebrate,
      mascotStyle: mascotStyle,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ArenaInsetFact(
            key: ValueKey('league-local-tier-rule'),
            icon: Icons.fact_check_outlined,
            text: lang.t(
              '10段階の観測級は週終了後に一度だけ確定し、1週で最大±1段',
              'The 10-tier ranking is finalized once after the week ends, moving at most one tier per week.',
            ),
          ),
          const SizedBox(height: GameTokens.spaceSm),
          _ArenaInsetFact(
            icon: Icons.groups_2_outlined,
            text: lang.t(
              '2〜4人は途中順位だけ。観測級の確定は実在5〜8人の週だけ',
              'With 2–4 players, ranks are provisional. Tiers are finalized only for weeks with 5–8 real players.',
            ),
          ),
          const SizedBox(height: GameTokens.spaceLg),
          if (localWeeklyLeague case final league?)
            LocalWeeklyLeaguePanel(
              view: league,
              setupParticipantCount: setupParticipantCount,
              onSetupParticipantCountChanged: onSetupParticipantCountChanged,
              onStart: onStart,
              selectedParticipantId: selectedParticipantId,
              onSelectParticipant: onSelectParticipant,
              onStartNextRound: onStartNextRound,
              embedded: true,
            )
          else
            _ArenaInsetFact(
              icon: Icons.shield_outlined,
              text: lang.t(
                '架空の観測者や旧4段の探究記録区分は主表示に使いません',
                'No fictional rivals or old four-tier XP rankings in the main view',
              ),
            ),
        ],
      ),
    );
  }
}

class _ArenaInsetFact extends StatelessWidget {
  const _ArenaInsetFact({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return GameSolidSurface(
      padding: const EdgeInsets.all(GameTokens.spaceMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.pathActive),
          const SizedBox(width: GameTokens.spaceSm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArenaProgress extends StatelessWidget {
  const _ArenaProgress({
    required this.current,
    required this.target,
    required this.ratio,
    required this.indicatorKey,
  });

  final int current;
  final int target;
  final double ratio;
  final Key indicatorKey;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.gamePalette;
    return GameSolidSurface(
      padding: const EdgeInsets.all(GameTokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$current / $target',
            style: t.textTheme.titleMedium
                ?.copyWith(color: colors.ink)
                .jaWeight(FontWeight.w900),
          ),
          const SizedBox(height: GameTokens.spaceSm),
          LinearProgressIndicator(
            key: indicatorKey,
            value: ratio,
            minHeight: GameTokens.progressTrackHeight,
            borderRadius: BorderRadius.circular(GameTokens.radiusPill),
            backgroundColor: colors.pathLocked,
            color: colors.pathActive,
          ),
        ],
      ),
    );
  }
}

Future<void> _showLeagueRules(
  BuildContext context, {
  required bool schoolMode,
  required bool lanSocialOnline,
  required bool hasLocalParticipants,
}) => showGamePageSheet<void>(
  context: context,
  title: lang.t('共同観測のルールと保存範囲', 'League rules and stored data'),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _LeagueRule(
        icon: Icons.replay_outlined,
        title: lang.t(
          '同じ学習の周回は数えない',
          'Repeats of the same activity do not count',
        ),
        body: lang.t(
          '同じ学習の繰り返しは0件で、別の人やラウンドへ使い回せません。',
          'Repeating an activity counts as zero and cannot be reused for another player or round.',
        ),
      ),
      const SizedBox(height: GameTokens.spaceMd),
      _LeagueRule(
        icon: Icons.speed_outlined,
        title: lang.t('速さではなく、意味のある観察', 'Meaningful learning, not speed'),
        body: lang.t(
          '意味のある完了1件ずつを観察として数え、滞在時間は得点にしません。',
          'Each meaningful completion counts once; time spent does not earn points.',
        ),
      ),
      const SizedBox(height: GameTokens.spaceMd),
      if (schoolMode)
        _LeagueRule(
          icon: Icons.visibility_off_outlined,
          title: lang.t('生徒の個人順位は表示しない', 'No individual student ranks'),
          body: lang.t(
            'この端末の進捗だけを表示し、クラス全体の件数・回答本文・音声を保存しません。',
            'Only this device\'s progress is shown. Class totals, answer text, and audio are not saved.',
          ),
        )
      else if (lanSocialOnline)
        _LeagueRule(
          icon: Icons.verified_user_outlined,
          title: lang.t('実参加者だけを匿名表示', 'Show real players anonymously'),
          body: lang.t(
            '同じWi‑Fiの実在5〜8人だけで構成し、5人未満では順位も人数も開示しません。',
            'Only 5–8 real players on the same Wi-Fi participate. Ranks and counts stay hidden below 5.',
          ),
        )
      else
        _LeagueRule(
          icon: Icons.phonelink_erase_outlined,
          title: lang.t('オンライン順位は使わない', 'No online rankings'),
          body: hasLocalParticipants
              ? lang.t(
                  '同じ端末を手渡しする実在2〜8人を匿名表示し、5〜8人の週だけslot 1の観測級を最大±1段動かします。',
                  'Show 2–8 real players sharing one device anonymously. Slot 1 moves at most one tier in weeks with 5–8 players.',
                )
              : lang.t(
                  '架空の観測者は作らず、実参加者の週を始めるまでは観測級01です。',
                  'No fictional rivals. Stay in Bronze until a week with real players begins.',
                ),
        ),
      const SizedBox(height: GameTokens.spaceMd),
      GameSolidSurface(
        child: Text(
          schoolMode
              ? lang.t(
                  '学校課題は個人の探究記録・結晶・連続観測へ加算しません。',
                  'Class work does not add personal XP, gems, or streak days.',
                )
              : lanSocialOnline
              ? lang.t(
                  '架空の観測者は作らず、観測級01から観測級10までの10段階です。',
                  'No fictional rivals; 10 tiers run from Bronze to Diamond.',
                )
              : lang.t(
                  'slot 1だけを「この端末の観測者」とし、他slotは週内匿名です。氏名・account・回答・正誤は表示・保存しません。',
                  'Only slot 1 is this device\'s player; other slots stay anonymous during the week. Names, accounts, answers, and results are not shown or saved.',
                ),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.gamePalette.inkMuted),
        ),
      ),
    ],
  ),
);

class _LeagueRule extends StatelessWidget {
  const _LeagueRule({
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
    return Semantics(
      container: true,
      label: lang.t('ルール。$title。$body', 'Rule. $title. $body'),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(GameTokens.spaceLg),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(GameTokens.radiusMd),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: colors.pathActive),
              const SizedBox(width: GameTokens.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: t.textTheme.titleSmall
                          ?.copyWith(color: colors.ink)
                          .jaWeight(FontWeight.w800),
                    ),
                    const SizedBox(height: GameTokens.spaceXs),
                    Text(
                      body,
                      style: t.textTheme.bodySmall?.copyWith(
                        color: colors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
