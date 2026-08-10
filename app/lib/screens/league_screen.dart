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
          const GameSectionHeader(
            title: 'これまでの週',
            description: 'この端末の学習者の実順位から、週終了後に一度だけ確定した履歴です。',
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
          label: const Text('ルールとプライバシー'),
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
        label: '昇格',
        icon: Icons.arrow_upward_rounded,
        color: colors.pathComplete,
      ),
      LanSocialLeagueMovement.stayed => (
        label: '維持',
        icon: Icons.horizontal_rule_rounded,
        color: colors.pathActive,
      ),
      LanSocialLeagueMovement.demoted => (
        label: '降格',
        icon: Icons.arrow_downward_rounded,
        color: colors.heart,
      ),
    };
    final rankLabel = week.rank == null
        ? '順位なし'
        : week.tied
        ? '同率${week.rank}位'
        : '${week.rank}位';
    return Semantics(
      container: true,
      label:
          '${week.weekKey}の週、${week.tier.label}、$rankLabel、'
          '${week.meaningfulEventCount}件、${movement.label}',
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
                      '${week.tier.label} ・ $rankLabel ・ '
                      '${week.meaningfulEventCount}件',
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
      eyebrow: '授業の探究',
      title: hasMission ? 'この端末の授業ミッション' : '同じ課題に、並んで挑む',
      body: hasMission
          ? 'この端末の完了だけを表示します。クラス全体の件数と個人順位は作りません。'
          : '先生の教材コードで同じ課題を開けます。この端末は個人順位やクラス全体の件数を集計しません。',
      semanticSummary: hasMission
          ? 'この端末の授業目標、$current、目標$target。クラス全体の件数は集計しません'
          : '端末内の協力モード。同じ課題に並んで挑む。個人順位とクラス全体の件数は集計しません',
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
          const _ArenaInsetFact(
            icon: Icons.visibility_off_outlined,
            text: '生徒の個人順位は表示しない',
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
      eyebrow: '実参加者リーグ',
      title: '同じWi‑Fiの仲間と、今週を競う',
      body: '実在5〜8人が接続したときだけ開きます。5人未満では順位も人数も表示しません。',
      semanticSummary: '実参加者リーグ。実在5人から8人。5人未満では順位と人数を表示しません',
      mascotReaction: GameCharacterReaction.invite,
      mascotStyle: mascotStyle,
      content: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ArenaInsetFact(
            icon: Icons.wifi_find_rounded,
            text: '接続前・現在の人数と順位は非表示',
          ),
          SizedBox(height: GameTokens.spaceSm),
          _ArenaInsetFact(
            icon: Icons.verified_user_outlined,
            text: '実参加者だけを匿名表示',
          ),
          SizedBox(height: GameTokens.spaceSm),
          _ArenaInsetFact(
            icon: Icons.workspace_premium_outlined,
            text: 'ブロンズからダイヤモンドまでの10段',
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
        label: const Text('仲間とつながる'),
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
      eyebrow: '実参加者・端末手渡し',
      title: '${tier.label}リーグ',
      body: 'slot 1の「この端末の学習者」を、実在する仲間との週次順位だけでブロンズからダイヤモンドへ進めます。',
      semanticSummary: '${tier.label}リーグ。この端末の学習者を実在5人から8人の順位で週終了後に確定',
      mascotReaction: GameCharacterReaction.celebrate,
      mascotStyle: mascotStyle,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ArenaInsetFact(
            key: ValueKey('league-local-tier-rule'),
            icon: Icons.workspace_premium_outlined,
            text: '10段tierは週終了後に一度だけ確定し、1週で最大±1段',
          ),
          const SizedBox(height: GameTokens.spaceSm),
          const _ArenaInsetFact(
            icon: Icons.groups_2_outlined,
            text: '2〜4人は途中順位だけ。tier確定は実在5〜8人の週だけ',
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
            const _ArenaInsetFact(
              icon: Icons.shield_outlined,
              text: '架空の対戦相手や旧4段XP tierは主表示に使いません',
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
  title: 'リーグのルールと保存範囲',
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _LeagueRule(
        icon: Icons.replay_outlined,
        title: '同じ学習の周回は数えない',
        body: '同じ学習の繰り返しは0件で、別の人やラウンドへ使い回せません。',
      ),
      const SizedBox(height: GameTokens.spaceMd),
      const _LeagueRule(
        icon: Icons.speed_outlined,
        title: '速さではなく、意味のある学習',
        body: '意味のある完了1件ずつを数え、滞在時間は得点にしません。',
      ),
      const SizedBox(height: GameTokens.spaceMd),
      if (schoolMode)
        const _LeagueRule(
          icon: Icons.visibility_off_outlined,
          title: '生徒の個人順位は表示しない',
          body: 'この端末の進捗だけを表示し、クラス全体の件数・回答本文・音声を保存しません。',
        )
      else if (lanSocialOnline)
        const _LeagueRule(
          icon: Icons.verified_user_outlined,
          title: '実参加者だけを匿名表示',
          body: '同じWi‑Fiの実在5〜8人だけで構成し、5人未満では順位も人数も開示しません。',
        )
      else
        _LeagueRule(
          icon: Icons.phonelink_erase_outlined,
          title: 'オンライン順位は使わない',
          body: hasLocalParticipants
              ? '同じ端末を手渡しする実在2〜8人を匿名表示し、5〜8人の週だけslot 1のtierを最大±1段動かします。'
              : '架空の対戦相手は作らず、実参加者の週を始めるまではブロンズです。',
        ),
      const SizedBox(height: GameTokens.spaceMd),
      GameSolidSurface(
        child: Text(
          schoolMode
              ? '学校課題は個人XP・結晶・連続学習へ加算しません。'
              : lanSocialOnline
              ? '架空の対戦相手は作らず、ブロンズからダイヤモンドまでの10段です。'
              : 'slot 1だけを「この端末の学習者」とし、他slotは週内匿名です。氏名・account・回答・正誤は表示・保存しません。',
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
      label: 'ルール。$title。$body',
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
