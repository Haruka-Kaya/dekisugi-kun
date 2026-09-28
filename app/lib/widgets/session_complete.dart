import '../config/app_radius.dart';
import '../config/app_theme.dart';
import '../models/streak.dart';
import '../models/mission.dart';
import '../services/live_session.dart';
import '../ui/_material.dart';
import 'character.dart';
import 'readable_width.dart';
import 'studio_ui.dart';

/// 会話の終わりに、行動の成果そのものを返す画面。
///
/// XPやポイントではなく、evidence が指す生徒発話を見せる（C5）。
/// 1件も増えなかったときは成功を作らず、記録したことだけを伝える。
class SessionCompleteView extends StatelessWidget {
  const SessionCompleteView({
    super.key,
    required this.achievements,
    required this.saveFailed,
    required this.saving,
    required this.onHome,
    required this.onReview,
    required this.onRetry,
    this.onRemindTomorrow,
    this.reminderBusy = false,
    this.reminderHour = 20,
    this.missionLabel,
    this.missionCleared = false,
    this.missionKind = MissionKind.teach,
  });

  final List<ExplainedItem> achievements;
  final bool saveFailed;
  final bool saving;
  final VoidCallback onHome;
  final VoidCallback onReview;
  final VoidCallback onRetry;
  final VoidCallback? onRemindTomorrow;
  final bool reminderBusy;
  final int reminderHour;
  final String? missionLabel;
  final bool missionCleared;
  final MissionKind missionKind;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final hasWords = achievements.isNotEmpty;
    final isMission = missionLabel?.isNotEmpty == true;
    final cleared = isMission && missionCleared && hasWords && !saveFailed;
    final clearEyebrow = switch (missionKind) {
      MissionKind.teach => 'MISSION CLEAR  ·  教え切った',
      MissionKind.repair => 'REPAIR CLEAR  ·  決着した',
      MissionKind.caseRetry => 'CASE CLEAR  ·  別の場面でも使えた',
    };
    final clearTitle = switch (missionKind) {
      MissionKind.teach => '「$missionLabel」を\n教え切った。',
      MissionKind.repair => '「$missionLabel」に\n今度こそ決着した。',
      MissionKind.caseRetry => '「$missionLabel」を\n別の場面でも使えた。',
    };
    final clearBody = switch (missionKind) {
      MissionKind.teach => '自分の説明で、デキすぎ君の思い込みまで見破りました。',
      MissionKind.repair => '曖昧だった条件や理由を組み直し、思い込みに決着しました。',
      MissionKind.caseRetry => '具体場面の予想と理由をつなげ、思い込みまで見破りました。',
    };

    final announcement = saveFailed
        ? '会話が完了しました。ノートへの保存に失敗しました。'
        : '会話が完了しました。デキすぎ君のノートに保存しました。';

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: SafeArea(
        top: false,
        child: ReadableWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              // 完了時に読み上げるのは短い要約だけ。画面全体をliveRegionにすると、
              // 長い本人の発話やボタンまで一度に再読してしまう。
              Semantics(
                container: true,
                liveRegion: true,
                label: announcement,
                child: const SizedBox.shrink(),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Character(state: LiveState.done, size: 72),
              ),
              const SizedBox(height: 14),
              StudioPageIntro(
                eyebrow: saveFailed
                    ? 'NOT SAVED  ·  まだ保存できていません'
                    : cleared
                    ? clearEyebrow
                    : isMission
                    ? 'MISSION LOG  ·  ここまで進んだ'
                    : 'DEKISUGI NOTE  ·  今日の記録',
                title: saveFailed
                    ? 'まだノートに\n残せていません。'
                    : cleared
                    ? clearTitle
                    : isMission && !hasWords
                    ? '次は、ここから\nもう一度挑める。'
                    : hasWords
                    ? 'デキすぎ君の\nノートに残った。'
                    : '話したところまで、\nノートに残った。',
                body: cleared ? clearBody : '教えてくれて、ありがとう。',
              ),
              const SizedBox(height: 10),
              Text(
                saveFailed
                    ? '話した言葉は、まだこの画面にだけ残っています。'
                    : hasWords
                    ? '要約ではなく、あなたが実際に話した言葉です。'
                    : '今回は、まだ一文として残せる説明はありません。',
                style: t.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 22),
              if (saveFailed) ...[
                _SaveProblem(saving: saving),
                const SizedBox(height: 22),
              ],
              if (!hasWords)
                const _NextBlank()
              else ...[
                _NotebookQuote(
                  item: achievements.first,
                  saved: !saveFailed,
                  primary: true,
                ),
                if (achievements.length > 1) ...[
                  const SizedBox(height: 28),
                  const StudioSectionHeader(
                    title: 'この会話で残った言葉',
                    description: 'どれも、あなた自身が話した文です。',
                    leading: Icon(Icons.format_quote),
                  ),
                  const SizedBox(height: 12),
                  for (final item in achievements.skip(1)) ...[
                    _NotebookQuote(
                      item: item,
                      saved: !saveFailed,
                      primary: false,
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
              const SizedBox(height: 30),
              if (onRemindTomorrow != null) ...[
                _TomorrowCase(
                  hour: reminderHour,
                  busy: reminderBusy,
                  onEnable: onRemindTomorrow!,
                ),
                const SizedBox(height: 18),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saveFailed ? (saving ? null : onRetry) : onHome,
                  child: Text(
                    saveFailed
                        ? (saving ? '保存しています…' : 'もう一度保存する')
                        : 'ホームでノートを見る',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: saveFailed ? onHome : onReview,
                  child: Text(
                    saveFailed ? '保存せずホームへ' : '次に話すことを整える',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              if (saveFailed) ...[
                const SizedBox(height: 4),
                TextButton(
                  onPressed: onReview,
                  child: const Text('次に話すことを整える'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 初回CLEARを翌日のCASEへつなぐ、任意の通知導線。
/// OS権限はこのボタンを押したときだけ求める。
class _TomorrowCase extends StatelessWidget {
  const _TomorrowCase({
    required this.hour,
    required this.busy,
    required this.onEnable,
  });

  final int hour;
  final bool busy;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: c.coolSurface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEXT CASE  /  明日',
            style: t.textTheme.labelMedium
                ?.copyWith(color: c.onCoolSurface)
                .jaWeight(FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Text(
            '次は、教材の答えを見ずに別の場面で使います。',
            style: t.textTheme.bodyMedium?.copyWith(color: c.onCoolSurface),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: busy ? null : onEnable,
              style: OutlinedButton.styleFrom(foregroundColor: c.onCoolSurface),
              child: Text(
                busy ? '設定しています…' : '明日$hour時ごろに知らせる',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 保存に成功したように見せない。再試行中も状態を文字で返す。
class _SaveProblem extends StatelessWidget {
  const _SaveProblem({required this.saving});

  final bool saving;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: scheme.error),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.sync_problem, color: scheme.onErrorContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '端末への保存が完了していません。',
                      style: t.textTheme.titleSmall
                          ?.copyWith(color: scheme.onErrorContainer)
                          .jaWeight(FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'ホームへ戻る前に再試行できます。'
                      '保存せず戻ると、この言葉がノートに残る保証はありません。',
                      style: t.textTheme.bodyMedium?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (saving) ...[
            const SizedBox(height: 14),
            Semantics(
              label: 'ノートに保存しています',
              child: const LinearProgressIndicator(),
            ),
          ],
        ],
      ),
    );
  }
}

/// 本人の発話を、スコアの代わりにセッションの署名として返す。
class _NotebookQuote extends StatelessWidget {
  const _NotebookQuote({
    required this.item,
    required this.saved,
    required this.primary,
  });

  final ExplainedItem item;
  final bool saved;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;

    return Semantics(
      container: true,
      label: '${item.label}。あなたが話した言葉。${item.said}',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(
            primary ? 20 : 18,
            primary ? 20 : 17,
            primary ? 20 : 18,
            primary ? 22 : 18,
          ),
          decoration: BoxDecoration(
            color: c.warmSurface,
            borderRadius: BorderRadius.circular(
              primary ? AppRadius.stage : AppRadius.xxl,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    saved ? Icons.edit_note_outlined : Icons.edit_outlined,
                    size: 21,
                    color: c.onWarmSurface,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      saved ? 'デキすぎ君のノート' : 'この画面に残っている言葉',
                      style: t.textTheme.labelMedium
                          ?.copyWith(color: c.onWarmSurface)
                          .jaWeight(FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                item.label,
                style: t.textTheme.labelMedium?.copyWith(
                  color: c.onWarmSurface.withValues(alpha: 0.76),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '「${item.said}」',
                style:
                    (primary
                            ? t.textTheme.headlineSmall
                            : t.textTheme.titleMedium)
                        ?.copyWith(color: c.onWarmSurface, height: 1.55)
                        .jaWeight(primary ? FontWeight.w700 : FontWeight.w600),
              ),
              const SizedBox(height: 18),
              Text(
                '—  あなたが話した言葉',
                style: t.textTheme.bodySmall?.copyWith(
                  color: c.onWarmSurface.withValues(alpha: 0.78),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextBlank extends StatelessWidget {
  const _NextBlank();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: c.coolSurface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.chat_bubble_outline, size: 24, color: c.onCoolSurface),
          const SizedBox(height: 14),
          Text(
            '次に言葉にするところ',
            style: t.textTheme.titleMedium
                ?.copyWith(color: c.onCoolSurface)
                .jaWeight(FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '今回まだ説明しきれなかったところは、'
            '「次に話すこと」として整えられます。',
            style: t.textTheme.bodyMedium?.copyWith(color: c.onCoolSurface),
          ),
        ],
      ),
    );
  }
}
