import '../config/app_language.dart' as lang;
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
      MissionKind.teach => lang.t(
        'MISSION CLEAR  ·  教え切った',
        'MISSION CLEAR  ·  Fully taught',
      ),
      MissionKind.repair => lang.t(
        'REPAIR CLEAR  ·  決着した',
        'REPAIR CLEAR  ·  Settled',
      ),
      MissionKind.caseRetry => lang.t(
        'CASE CLEAR  ·  別の場面でも使えた',
        'CASE CLEAR  ·  Worked in a new situation',
      ),
    };
    final clearTitle = switch (missionKind) {
      MissionKind.teach => lang.t(
        '「$missionLabel」を\n教え切った。',
        'You fully taught\n"$missionLabel".',
      ),
      MissionKind.repair => lang.t(
        '「$missionLabel」に\n今度こそ決着した。',
        'You finally settled\n"$missionLabel".',
      ),
      MissionKind.caseRetry => lang.t(
        '「$missionLabel」を\n別の場面でも使えた。',
        'You used "$missionLabel"\nin a new situation.',
      ),
    };
    final clearBody = switch (missionKind) {
      MissionKind.teach => lang.t(
        '自分の説明で、デキすぎ君の思い込みまで見破りました。',
        "With your own explanation, you caught Dekisugi-kun's misconception.",
      ),
      MissionKind.repair => lang.t(
        '曖昧だった条件や理由を組み直し、思い込みに決着しました。',
        'You rebuilt the unclear conditions and reasons and settled the misconception.',
      ),
      MissionKind.caseRetry => lang.t(
        '具体場面の予想と理由をつなげ、思い込みまで見破りました。',
        'You connected a prediction and reason for a real situation and caught the misconception.',
      ),
    };

    final announcement = saveFailed
        ? lang.t(
            '会話が完了しました。ノートへの保存に失敗しました。',
            'Conversation finished. Saving to the notebook failed.',
          )
        : lang.t(
            '会話が完了しました。デキすぎ君のノートに保存しました。',
            "Conversation finished. Saved to Dekisugi-kun's notebook.",
          );

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
                    ? lang.t(
                        'NOT SAVED  ·  まだ保存できていません',
                        'NOT SAVED  ·  Not saved yet',
                      )
                    : cleared
                    ? clearEyebrow
                    : isMission
                    ? lang.t(
                        'MISSION LOG  ·  ここまで進んだ',
                        'MISSION LOG  ·  Progress so far',
                      )
                    : lang.t(
                        'DEKISUGI NOTE  ·  今日の記録',
                        "DEKISUGI NOTE  ·  Today's record",
                      ),
                title: saveFailed
                    ? lang.t(
                        'まだノートに\n残せていません。',
                        'Not saved to\nthe notebook yet.',
                      )
                    : cleared
                    ? clearTitle
                    : isMission && !hasWords
                    ? lang.t(
                        '次は、ここから\nもう一度挑める。',
                        'Next time, you can\ntry again from here.',
                      )
                    : hasWords
                    ? lang.t(
                        'デキすぎ君の\nノートに残った。',
                        "It's in Dekisugi-kun's\nnotebook.",
                      )
                    : lang.t(
                        '話したところまで、\nノートに残った。',
                        'What you said is\nin the notebook.',
                      ),
                body: cleared
                    ? clearBody
                    : lang.t('教えてくれて、ありがとう。', 'Thanks for teaching me.'),
              ),
              const SizedBox(height: 10),
              Text(
                saveFailed
                    ? lang.t(
                        '話した言葉は、まだこの画面にだけ残っています。',
                        'What you said is only on this screen for now.',
                      )
                    : hasWords
                    ? lang.t(
                        '要約ではなく、あなたが実際に話した言葉です。',
                        'These are not summaries. They are your actual words.',
                      )
                    : lang.t(
                        '今回は、まだ一文として残せる説明はありません。',
                        'This time, there is no explanation to keep as a sentence yet.',
                      ),
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
                  StudioSectionHeader(
                    title: lang.t('この会話で残った言葉', 'Words from this conversation'),
                    description: lang.t(
                      'どれも、あなた自身が話した文です。',
                      'Every one is a sentence you said yourself.',
                    ),
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
                        ? (saving
                              ? lang.t('保存しています…', 'Saving…')
                              : lang.t('もう一度保存する', 'Save again'))
                        : lang.t('ホームでノートを見る', 'See the notebook at Home'),
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
                    saveFailed
                        ? lang.t('保存せずホームへ', 'Go Home without saving')
                        : lang.t('次に話すことを整える', 'Prepare what to say next'),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              if (saveFailed) ...[
                const SizedBox(height: 4),
                TextButton(
                  onPressed: onReview,
                  child: Text(lang.t('次に話すことを整える', 'Prepare what to say next')),
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
            lang.t('NEXT CASE  /  明日', 'NEXT CASE  /  Tomorrow'),
            style: t.textTheme.labelMedium
                ?.copyWith(color: c.onCoolSurface)
                .jaWeight(FontWeight.w700),
          ),
          const SizedBox(height: 7),
          Text(
            lang.t(
              '次は、教材の答えを見ずに別の場面で使います。',
              'Next time, you will use it in a new situation without looking at the answer.',
            ),
            style: t.textTheme.bodyMedium?.copyWith(color: c.onCoolSurface),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: busy ? null : onEnable,
              style: OutlinedButton.styleFrom(foregroundColor: c.onCoolSurface),
              child: Text(
                busy
                    ? lang.t('設定しています…', 'Setting up…')
                    : lang.t(
                        '明日$hour時ごろに知らせる',
                        'Remind me tomorrow around $hour:00',
                      ),
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
                      lang.t(
                        '端末への保存が完了していません。',
                        'Saving to this device is not finished.',
                      ),
                      style: t.textTheme.titleSmall
                          ?.copyWith(color: scheme.onErrorContainer)
                          .jaWeight(FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      lang.t(
                        'ホームへ戻る前に再試行できます。'
                            '保存せず戻ると、この言葉がノートに残る保証はありません。',
                        'You can retry before going Home. '
                            'If you go back without saving, these words may not stay in the notebook.',
                      ),
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
              label: lang.t('ノートに保存しています', 'Saving to the notebook'),
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
      label: lang.t(
        '${item.label}。あなたが話した言葉。${item.said}',
        '${item.label}. Your words. ${item.said}',
      ),
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
                      saved
                          ? lang.t('デキすぎ君のノート', "Dekisugi-kun's notebook")
                          : lang.t('この画面に残っている言葉', 'Words on this screen'),
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
                lang.t('「${item.said}」', '"${item.said}"'),
                style:
                    (primary
                            ? t.textTheme.headlineSmall
                            : t.textTheme.titleMedium)
                        ?.copyWith(color: c.onWarmSurface, height: 1.55)
                        .jaWeight(primary ? FontWeight.w700 : FontWeight.w600),
              ),
              const SizedBox(height: 18),
              Text(
                lang.t('—  あなたが話した言葉', '—  Your words'),
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
            lang.t('次に言葉にするところ', 'What to explain next'),
            style: t.textTheme.titleMedium
                ?.copyWith(color: c.onCoolSurface)
                .jaWeight(FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            lang.t(
              '今回まだ説明しきれなかったところは、'
                  '「次に話すこと」として整えられます。',
              'Parts you could not fully explain this time '
                  'can be set up as "What to say next".',
            ),
            style: t.textTheme.bodyMedium?.copyWith(color: c.onCoolSurface),
          ),
        ],
      ),
    );
  }
}
