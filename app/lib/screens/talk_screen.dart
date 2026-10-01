import 'dart:async';

import 'package:provider/provider.dart';

import '../config/app_radius.dart';
import '../config/app_theme.dart';
import '../config/env.dart';
import '../config/motion.dart';
import '../models/dossier.dart';
import '../models/mission.dart';
import '../models/unit.dart';
import '../services/live_session.dart';
import '../services/mic_stream.dart';
import '../services/reminders.dart';
import '../services/session_store.dart';
import '../services/units_client.dart';
import '../ui/_material.dart';
import '../widgets/dossier_bar.dart';
import '../widgets/mission_ui.dart';
import '../widgets/quota_view.dart';
import '../widgets/session_complete.dart';
import '../widgets/stage.dart';
import 'offline_practice_screen.dart';
import 'review_screen.dart';
import '../config/app_language.dart' as lang;

/// 会話画面。
///
/// キャラクターを中心に置き、その下に理解カルテ、逐語、操作を並べる。
/// **状態は「キャラの見た目」と「文字」の両方で出す** — 動きが止まっている
/// 端末（Reduce Motion / 古い端末）でも、いま何が起きているか分かる必要がある。
class TalkScreen extends StatefulWidget {
  const TalkScreen({
    super.key,
    required this.unitTitle,
    this.conceptLabel,
    this.onOpenPlus,
    this.offlineSection,
    this.offlineMissionKind = MissionKind.teach,
  });

  /// いま教えている単元。**画面に出す。**
  /// 教材を隠しているので、何について話しているかの手がかりが要る
  final String unitTitle;

  /// 1概念ミッションの表示名。nullは旧来の単元全体会話。
  final String? conceptLabel;

  /// Plus が設定済みのビルドだけで渡す。画面を閉じた後は、購入の有無に
  /// かかわらずサーバーの現在枠を読み直す。
  final Future<void> Function()? onOpenPlus;

  /// 教材を閉じたあとも、通信なしで学習行為を続けるための節。
  ///
  /// 単元全体会話や、焦点節を解決できなかった場合は null のままにする。
  /// 導線は接続失敗時だけに出し、通常のLive会話と競合させない。
  final Section? offlineSection;

  /// 直前に選んだミッション種別。端末内練習でも課題の文脈を失わせない。
  final MissionKind offlineMissionKind;

  @override
  State<TalkScreen> createState() => _TalkScreenState();
}

class _TalkScreenState extends State<TalkScreen> with WidgetsBindingObserver {
  /// 中断していた会話。あれば「続きから」を出す
  SavedSession? _unfinished;
  bool _checkingUnfinished = true;
  bool _pausingForBackground = false;
  bool _allowPop = false;
  Reminders? _reminders;
  bool _remindersEnabled = true;
  bool _settingReminder = false;
  bool _openingPlus = false;
  int _reminderHour = 20;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lookForUnfinished();
    // 残りは会話を始める前に見せる（枠は引かない）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LiveSessionController>().refreshQuota();
      unawaited(_loadReminderOffer());
    });
  }

  Future<void> _loadReminderOffer() async {
    Reminders? reminders;
    try {
      reminders = context.read<Reminders>();
    } on ProviderNotFoundException {
      return;
    }
    final enabled = await reminders.isEnabled();
    final hour = await reminders.hour();
    if (!mounted) return;
    setState(() {
      _reminders = reminders;
      _remindersEnabled = enabled;
      _reminderHour = hour;
    });
  }

  Future<void> _enableTomorrowReminder() async {
    final reminders = _reminders;
    final label = widget.conceptLabel;
    if (reminders == null || label == null || _settingReminder) return;
    setState(() => _settingReminder = true);
    try {
      final allowed = await reminders.requestPermission();
      if (!allowed) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(lang.t('端末の設定で通知が切られています。', 'Notifications are turned off in your device settings.'))));
        }
        return;
      }
      await reminders.setEnabled(true);
      await reminders.scheduleTomorrowCase(label);
      if (mounted) {
        setState(() => _remindersEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lang.t('明日$_reminderHour時ごろに、次のCASEを知らせます。', 'I\'ll remind you about the next CASE tomorrow around $_reminderHour:00.'))),
        );
      }
    } finally {
      if (mounted) setState(() => _settingReminder = false);
    }
  }

  Future<void> _openPlus() async {
    final open = widget.onOpenPlus;
    if (open == null || _openingPlus) return;
    setState(() => _openingPlus = true);
    try {
      await open();
      if (!mounted) return;
      await context.read<LiveSessionController>().refreshQuota();
    } finally {
      if (mounted) setState(() => _openingPlus = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        // マイク権限などのOSダイアログでもinactiveになる。ここで止めると、
        // 初回の「声ではなす」が許可直後に自己キャンセルされる。
        return;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // 画面が見えないのに録音を続けない。会話は未完了として端末へ残し、
        // 戻ったときに本人が「続きから」を選ぶ
        unawaited(_pauseForBackground());
    }
  }

  Future<void> _pauseForBackground() async {
    if (_pausingForBackground || !mounted) return;
    final live = context.read<LiveSessionController>();
    if (!live.isActive) return;
    final store = context.read<SessionStore>();

    _pausingForBackground = true;
    try {
      await live.stop();
      final saved = await store.unfinished(
        unitId: live.unitId,
        focusConceptKey: live.focusConceptKey,
        missionKind: live.missionKind,
      );
      if (mounted) {
        setState(() {
          _unfinished = saved;
          _checkingUnfinished = false;
        });
      }
    } catch (e) {
      debugPrint('中断した会話の保存確認に失敗: $e');
    } finally {
      _pausingForBackground = false;
    }
  }

  Future<void> _lookForUnfinished() async {
    final live = context.read<LiveSessionController>();
    final store = context.read<SessionStore>();
    try {
      final saved = await store.unfinished(
        unitId: live.unitId,
        focusConceptKey: live.focusConceptKey,
        missionKind: live.missionKind,
      );
      if (mounted) setState(() => _unfinished = saved);
    } catch (e) {
      debugPrint('中断した会話の読み込みに失敗: $e');
    } finally {
      if (mounted) setState(() => _checkingUnfinished = false);
    }
  }

  Future<void> _resume() async {
    final saved = _unfinished;
    if (saved == null) return;
    final live = context.read<LiveSessionController>();
    if (await live.resumeSaved(saved)) {
      setState(() => _unfinished = null);
      await live.start();
    }
  }

  Future<void> _discard() async {
    final saved = _unfinished;
    if (saved == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(lang.t('この会話を捨てますか？', 'Discard this conversation?')),
        content: Text(
          lang.t('ここまで話した言葉と会話ノートが端末から消えます。'
          'この操作は元に戻せません。', 'The words you said and your conversation notes will be deleted from this device. This cannot be undone.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(lang.t('会話を残す', 'Keep conversation')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: Text(lang.t('この会話を捨てる', 'Discard conversation')),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    final discarded = await context.read<LiveSessionController>().discardSaved(
      saved,
    );
    if (discarded && mounted) setState(() => _unfinished = null);
  }

  /// 会話中に画面を離れようとしたときの確認。
  ///
  /// ここを離れると会話は終わり、**教材を読み直せる場所に戻れてしまう**（C2 の抜け道）。
  /// 塞ぎきることはできないが、うっかり出てしまうのは防ぐ。
  Future<bool> _confirmLeave() async {
    // 文字入力中でも確認面をキーボードの上へ押し潰させない。
    // 大きな文字では本文と操作をdialog内でスクロールできるようにする。
    FocusManager.instance.primaryFocus?.unfocus();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(lang.t('いったんやめますか？', 'Take a break?')),
        content: Text(
          lang.t('ここを出ると会話は終わります。'
          'いま話したところまでは残るので、あとから続きにできます。', 'Leaving here ends the conversation. What you\'ve said so far is kept, so you can continue later.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(lang.t('つづける', 'Keep going')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(lang.t('いったんやめる', 'Take a break')),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _pauseAndLeave() async {
    if (!await _confirmLeave() || !mounted) return;
    final navigator = Navigator.of(context);
    await context.read<LiveSessionController>().stop();
    if (mounted) navigator.pop();
  }

  void _openReview() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReviewScreen(
          store: context.read<SessionStore>(),
          units: context.read<UnitsClient>(),
        ),
      ),
    );
  }

  void _goHome() {
    if (!mounted) return;
    setState(() => _allowPop = true);
    // PopScopeへ許可が反映された次のフレームで、Pickerなど中間画面も含めて戻す。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    });
  }

  bool _canContinueOffline(LiveSessionController live) {
    if (widget.offlineSection == null || live.state != LiveState.failed) {
      return false;
    }
    return switch (live.failure) {
      LiveFailure.network || LiveFailure.auth || LiveFailure.unknown => true,
      LiveFailure.noPermission || null => false,
    };
  }

  void _continueOffline() {
    final section = widget.offlineSection;
    if (section == null || !mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _allowPop = true);
    unawaited(
      Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => OfflinePracticeScreen(
            section: section,
            conceptLabel: widget.conceptLabel ?? section.title,
            missionKind: widget.offlineMissionKind,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLeaveWithoutSaving() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text(lang.t('保存せずホームへ戻りますか？', 'Go home without saving?')),
        content: Text(
          lang.t('今回話した言葉がノートに残らない可能性があります。'
          'この画面で、もう一度保存できます。', 'The words you said this time may not be saved to your notes. You can try saving again on this screen.'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(false);
              unawaited(
                context.read<LiveSessionController>().retryCompletionSave(),
              );
            },
            child: Text(lang.t('保存をやり直す', 'Try saving again')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: Text(lang.t('保存せず戻る', 'Go back without saving')),
          ),
        ],
      ),
    );
    if (leave == true) _goHome();
  }

  @override
  Widget build(BuildContext context) {
    final live = context.watch<LiveSessionController>();
    final saveNeedsAttention =
        live.state == LiveState.done &&
        (live.completionSaveFailed || live.completionSaveInProgress);
    final completed = live.state == LiveState.done;

    return PopScope(
      canPop: _allowPop || (!live.isActive && !completed),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !mounted) return;
        if (saveNeedsAttention) {
          if (live.completionSaveInProgress) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(lang.t('ノートへの保存が終わるまでお待ちください。', 'Please wait until saving to your notes is finished.'))),
            );
          } else {
            await _confirmLeaveWithoutSaving();
          }
          return;
        }
        if (completed) {
          _goHome();
          return;
        }
        await _pauseAndLeave();
      },
      child: _build(context, live),
    );
  }

  Widget _build(BuildContext context, LiveSessionController live) {
    final missionCleared = switch (live.focusConceptKey) {
      final key? => missionSnapshotFor(
        conceptKey: key,
        dossier: live.dossier,
        lastLureId: live.lastLureId,
      ).isClear,
      null => false,
    };
    final canOfferTomorrowCase =
        missionCleared &&
        !live.completionSaveFailed &&
        live.missionKind != MissionKind.caseRetry &&
        !_remindersEnabled &&
        _reminders != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.conceptLabel ?? widget.unitTitle,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.jaWeight(FontWeight.w700),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // 残りは**最初から見せる**。減ってから知らせると、
          // 会話の途中で急に切れて何が起きたか分からなくなる
          Padding(
            // 200%文字ではchipが約32dpになる。標準56dpのAppBarへ
            // 戻しても切れないよう、上下余白を合わせて20dp以内にする。
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: QuotaChip(live: live),
          ),
          // **会話中に教材を開かせない（C2）。** ReviewScreenを重ねるだけだと
          // TalkScreenはdisposeされず、マイクもWebSocketも動き続ける
          if (!live.isActive && live.state != LiveState.done)
            IconButton(
              tooltip: lang.t('もう一度見るところ', 'What to look at again'),
              onPressed: _openReview,
              icon: const Icon(Icons.bookmarks_outlined),
            ),
          if (live.isActive)
            IconButton(
              tooltip: lang.t('いったんやめる', 'Take a break'),
              onPressed: _pauseAndLeave,
              icon: const Icon(Icons.pause_circle_outline),
            ),
        ],
      ),
      body: !Env.hasServer
          ? _MissingServer(
              onPracticeOffline: widget.offlineSection == null
                  ? null
                  : _continueOffline,
            )
          : live.state == LiveState.done
          ? SessionCompleteView(
              achievements: live.sessionAchievements,
              missionLabel: widget.conceptLabel,
              missionKind: live.missionKind,
              missionCleared: missionCleared,
              onRemindTomorrow: canOfferTomorrowCase
                  ? () => unawaited(_enableTomorrowReminder())
                  : null,
              reminderBusy: _settingReminder,
              reminderHour: _reminderHour,
              saveFailed: live.completionSaveFailed,
              saving: live.completionSaveInProgress,
              // Picker 経由では Home → Picker → Talk のスタックになる。
              // 1画面だけ戻すと「ホーム」と書いてあるのにPickerへ戻る。
              onHome: _goHome,
              onReview: _openReview,
              onRetry: () => unawaited(live.retryCompletionSave()),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final showComposer =
                    live.state != LiveState.outOfTime &&
                    ((!_checkingUnfinished && _unfinished == null) ||
                        live.isActive);
                return Column(
                  children: [
                    // Stage・会話ノート・安全案内は高さを固定せず、まとめて
                    // スクロールさせる。大きな文字でも逐語を押し潰さない。
                    Expanded(
                      child: _ConversationViewport(
                        turnCount: live.transcript.length,
                        interimLength: live.interimStudentText.length,
                        children: [
                          if (live.focusConceptKey case final conceptKey?)
                            TeachingMissionBoard(
                              conceptKey: conceptKey,
                              conceptLabel:
                                  widget.conceptLabel ??
                                  _labelFor(live.dossier, conceptKey) ??
                                  widget.unitTitle,
                              tactic: live.tactic,
                              dossier: live.dossier,
                              lastLureId: live.lastLureId,
                              missionKind: live.missionKind,
                              challengeText: live.challengeText,
                            ),
                          Stage(live: live),
                          if (_unfinished != null && !live.isRunning)
                            _ResumeBanner(
                              saved: _unfinished!,
                              canResume: live.state != LiveState.outOfTime,
                              onResume: _resume,
                              onDiscard: _discard,
                            ),
                          if (live.failure != null)
                            _FailureBanner(failure: live.failure!),
                          if (_canContinueOffline(live))
                            _OfflinePracticeOffer(onContinue: _continueOffline),
                          if (live.recordingIssue != null)
                            _IssueBanner(issue: live.recordingIssue!),
                          if (live.suspectsSelfInterruption)
                            const _EchoBanner(),
                          if (live.focusConceptKey == null &&
                              live.dossier != null)
                            DossierBar(dossier: live.dossier!),
                          if (live.state == LiveState.outOfTime)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                              child: OutOfTimeCard(
                                resetsAt: live.quotaResetsAt,
                                plusBusy: _openingPlus,
                                onOpenPlus: widget.onOpenPlus == null
                                    ? null
                                    : () => unawaited(_openPlus()),
                              ),
                            ),
                          _TurnLog(live: live),
                        ],
                      ),
                    ),
                    if (showComposer)
                      // キーボード＋200%文字＋複数行入力でもFlexを溢れさせない。
                      // 通常時は自然高、狭いときだけcomposer内をスクロールする。
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * 0.58,
                        ),
                        child: SingleChildScrollView(
                          child: _Composer(live: live, onPause: _pauseAndLeave),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }

  String? _labelFor(Dossier? dossier, String conceptKey) {
    for (final slot in dossier?.slots ?? const <Slot>[]) {
      if (slot.key == conceptKey && slot.label.isNotEmpty) return slot.label;
    }
    return null;
  }
}

class _MissingServer extends StatelessWidget {
  const _MissingServer({this.onPracticeOffline});

  final VoidCallback? onPracticeOffline;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
      children: [
        Icon(
          Icons.cloud_off_outlined,
          size: 40,
          color: t.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text(
          lang.t('会話の接続先を確認できません', 'Can\'t reach the conversation server'),
          style: t.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          onPracticeOffline == null
              ? lang.t('あとでもう一度お試しください。', 'Please try again later.')
              : lang.t('端末内練習を続けるか、あとでもう一度お試しください。', 'Keep practicing on this device, or try again later.'),
          style: t.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        if (onPracticeOffline case final onContinue?) ...[
          const SizedBox(height: 24),
          _OfflinePracticeOffer(onContinue: onContinue),
        ],
      ],
    );
  }
}

/// 中断していた会話の再開。
///
/// **「アプリを離れた」ではなく「OS に殺された」前提**で作ってある。
/// 発話は1ターンごとに端末へ書いているので、落ちた直前まで残っている。
/// Live の接続自体は復元できないが、復元するのは逐語と理解カルテなので、
/// ディレクターがそれを読んで続きから指示を出せる。
class _ResumeBanner extends StatelessWidget {
  const _ResumeBanner({
    required this.saved,
    required this.canResume,
    required this.onResume,
    required this.onDiscard,
  });

  final SavedSession saved;
  final bool canResume;
  final VoidCallback onResume;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    final turns = saved.transcript.where((u) => u.isStudent).length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: c.highlightFlash,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.t('前回の続きがあります', 'You have a conversation to continue'),
            style: t.textTheme.titleSmall?.jaWeight(FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(lang.t('$turns回ぶんの会話が端末に残っています。', '$turns turns of conversation are saved on this device.'), style: t.textTheme.bodySmall),
          if (!canResume) ...[
            const SizedBox(height: 6),
            Text(lang.t('会話できる回数が戻るまで、この続きは端末に残ります。', 'This conversation stays on your device until your conversation count resets.'), style: t.textTheme.bodySmall),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              // 破棄は主導線から弱めるが、取り消せない意味は明示する
              TextButton(onPressed: onDiscard, child: Text(lang.t('この会話を捨てる', 'Discard conversation'))),
              if (canResume)
                FilledButton(onPressed: onResume, child: Text(lang.t('続きから', 'Continue'))),
            ],
          ),
        ],
      ),
    );
  }
}

/// 続けられなくなった理由。**色だけでなくアイコンと文言で出す**（SC 1.4.1）。
class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.failure});

  final LiveFailure failure;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    final text = switch (failure) {
      LiveFailure.noPermission => lang.t('マイクを使う許可がありません', 'No permission to use the microphone'),
      LiveFailure.network => lang.t('ネットワークにつながりません', 'Can\'t connect to the network'),
      LiveFailure.auth => lang.t('接続を確認できませんでした。少し待って、もう一度お試しください', 'Couldn\'t confirm the connection. Please wait a moment and try again'),
      LiveFailure.unknown => lang.t('続けられませんでした', 'Couldn\'t continue'),
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.weakChip,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        children: [
          // 失敗の合図には ✗ を使ってよい。ここは生徒の理解の話ではない
          Icon(Icons.error_outline, size: 18, color: c.weakFg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: t.textTheme.bodyMedium?.copyWith(color: c.weakFg),
            ),
          ),
        ],
      ),
    );
  }
}

/// 接続だけが成立しなかったときの、完全ローカルな学習継続導線。
///
/// マイク拒否なら文字Liveが使えるため出さない。枠切れにも出さない。
/// 「オフラインでも理解判定できる」と誤認させず、行うことを練習に限定する。
class _OfflinePracticeOffer extends StatelessWidget {
  const _OfflinePracticeOffer({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final colors = context.appColors;
    return Semantics(
      container: true,
      label: lang.t('接続できないため、端末内の文字練習を利用できます', 'Can\'t connect, so you can use text practice on this device'),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: colors.coolSurface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.phonelink_lock_outlined,
                    color: colors.onCoolSurface,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    lang.t('会話につながらなくても、教材を閉じた練習は続けられます。', 'Even without a conversation connection, you can keep practicing with the material closed.'),
                    style: t.textTheme.bodyMedium?.copyWith(
                      color: colors.onCoolSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey('continue-offline-practice'),
              onPressed: onContinue,
              icon: const Icon(Icons.edit_note_outlined),
              label: Text(lang.t('端末内で練習を続ける', 'Keep practicing on this device')),
            ),
            const SizedBox(height: 6),
            Text(
              lang.t('入力は送信・保存せず、会話できる回数も使いません。', 'Your input is not sent or saved, and it doesn\'t use your conversation count.'),
              style: t.textTheme.bodySmall?.copyWith(
                color: colors.onCoolSurface,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// 録音がおかしいときに出す。**黙って進めない。**
///
/// ノイズ抑制で救おうとしないこと。効くのはマイク距離と場所の静けさで、
/// 前処理では戻らない（`asr-noise-2026.md` §2, §5）。
class _IssueBanner extends StatelessWidget {
  const _IssueBanner({required this.issue});

  final RecordingIssue issue;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    final text = switch (issue) {
      RecordingIssue.silent => lang.t('マイクが音を拾えていません。ふさいでいないか確かめてください。', 'The microphone isn\'t picking up sound. Make sure it isn\'t covered.'),
      RecordingIssue.quiet => lang.t('声が小さいようです。マイクに近づいてください。', 'Your voice seems quiet. Move closer to the microphone.'),
      RecordingIssue.clipped => lang.t('音が大きすぎて割れています。少し離れてください。', 'The sound is too loud and distorted. Move back a little.'),
    };

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.shakyChip,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        children: [
          Icon(Icons.mic_none, size: 18, color: c.shakyFg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: t.textTheme.bodySmall?.copyWith(color: c.shakyFg),
            ),
          ),
        ],
      ),
    );
  }
}

/// AI が自分の声を拾って自分を止めている疑い。
///
/// エコーキャンセルが効かない端末で起きる。会話がぶつ切りになるのに、
/// 生徒には理由が分からない。**黙って壊れたままにしない。**
/// 直す手段は端末側に無いので、**イヤホンという実際に効く回避策**を出す。
class _EchoBanner extends StatelessWidget {
  const _EchoBanner();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: c.shakyChip,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        children: [
          Icon(Icons.headphones, size: 18, color: c.shakyFg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              lang.t('デキすぎ君の声をマイクが拾っているようです。'
              'イヤホンをつけると話しやすくなります。', 'The microphone seems to be picking up Dekisugi-kun\'s voice. Using earphones makes it easier to talk.'),
              style: t.textTheme.bodySmall?.copyWith(color: c.shakyFg),
            ),
          ),
        ],
      ),
    );
  }
}

class _TurnLog extends StatelessWidget {
  const _TurnLog({required this.live});

  final LiveSessionController live;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final u in live.transcript) (u.isStudent, u.display),
      if (live.interimStudentText.isNotEmpty) (true, live.interimStudentText),
    ];

    if (rows.isEmpty) {
      // 上寄せにする。中央寄せだと、キャラとの間が不自然に空く
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                lang.t('知っていることを、教えてください。', 'Teach me what you know.'),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.jaWeight(FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 5),
              Text(
                lang.t('声でも文字でも、どちらでも大丈夫です。', 'Voice or text — either is fine.'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            _Bubble(
              isStudent: rows[i].$1,
              text: rows[i].$2,
              interim:
                  i == rows.length - 1 &&
                  live.interimStudentText.isNotEmpty &&
                  rows[i].$1,
            ),
        ],
      ),
    );
  }
}

/// 最新の発話を見せつつ、読み返している人の位置は奪わない会話面。
///
/// 末尾にいるときだけ新しい発話へ追従する。上へ戻って読んでいる間は
/// 自動スクロールせず、明示的なジャンプだけを出す。
class _ConversationViewport extends StatefulWidget {
  const _ConversationViewport({
    required this.turnCount,
    required this.interimLength,
    required this.children,
  });

  final int turnCount;
  final int interimLength;
  final List<Widget> children;

  @override
  State<_ConversationViewport> createState() => _ConversationViewportState();
}

class _ConversationViewportState extends State<_ConversationViewport> {
  static const _followDistance = 96.0;

  final ScrollController _controller = ScrollController();
  bool _showLatest = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_notePosition);
  }

  @override
  void didUpdateWidget(_ConversationViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed =
        oldWidget.turnCount != widget.turnCount ||
        oldWidget.interimLength != widget.interimLength;
    if (!changed) return;

    final wasAtLatest =
        !_controller.hasClients ||
        oldWidget.turnCount == 0 ||
        _controller.position.extentAfter <= _followDistance;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      if (wasAtLatest) {
        _moveToLatest();
      } else if (!_showLatest) {
        setState(() => _showLatest = true);
      }
    });
  }

  void _notePosition() {
    if (_showLatest &&
        _controller.hasClients &&
        _controller.position.extentAfter <= _followDistance) {
      setState(() => _showLatest = false);
    }
  }

  void _moveToLatest() {
    if (!_controller.hasClients) return;
    final target = _controller.position.maxScrollExtent;
    if (ReduceMotionScope.of(context)) {
      _controller.jumpTo(target);
    } else {
      unawaited(
        _controller.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        ),
      );
    }
    if (_showLatest) setState(() => _showLatest = false);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_notePosition)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListView(
          controller: _controller,
          padding: EdgeInsets.zero,
          children: widget.children,
        ),
        if (_showLatest)
          Positioned(
            right: 12,
            bottom: 12,
            child: FilledButton.tonalIcon(
              onPressed: _moveToLatest,
              icon: const Icon(Icons.arrow_downward),
              label: Text(lang.t('新しい会話', 'New conversation')),
            ),
          ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.isStudent,
    required this.text,
    required this.interim,
  });

  final bool isStudent;
  final String text;

  /// 確定前の文字起こし。あとで変わるので、変わることが見た目で分かるようにする
  final bool interim;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;

    return Align(
      alignment: isStudent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: isStudent
              ? context.appColors.coolSurface
              : context.appColors.warmSurface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isStudent ? lang.t('あなた', 'You') : lang.t('デキすぎ君', 'Dekisugi-kun'),
              style: t.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              text,
              style: t.textTheme.bodyMedium?.copyWith(
                // 確定前は薄くする。色だけの区別にならないよう「…」も付ける
                color: interim ? scheme.onSurfaceVariant : scheme.onSurface,
              ),
            ),
            if (interim)
              Text(
                lang.t('…変換中', '…transcribing'),
                style: t.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.live, required this.onPause});

  final LiveSessionController live;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final running = live.isRunning;
    final busy = live.state == LiveState.connecting;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              lang.t('声でも文字でも、同じように教えられます。', 'You can teach by voice or text just the same.'),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 7),
            SizedBox(height: 6, child: running ? _MicLevel(live: live) : null),
            // **文字は音声と対等（C8）。** 常に出し、切替式にしない。
            _TextInput(live: live),
            const SizedBox(height: 9),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : running
                  ? (live.hasMic ? onPause : live.enableMic)
                  : live.start,
              icon: Icon(
                running ? (live.hasMic ? Icons.pause : Icons.mic) : Icons.mic,
              ),
              label: Text(
                running ? (live.hasMic ? lang.t('いったんやめる', 'Take a break') : lang.t('声でも話す', 'Talk by voice too')) : lang.t('声ではなす', 'Talk by voice'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 文字で説明する経路。**常に出る（C8）。**
///
/// 人前での音声利用を恥ずかしいと答えた日本人が 71.1%。
/// 電車・教室・家族のいる部屋で声を出せない生徒にとって、
/// 音声しか無いアプリは存在しないのと同じになる。
///
/// 未接続でも送れる（`sendStudentText` が自分で繋ぐ）。
/// 「先にマイクを押す」を要求しないのが、対等であることの実質。
class _TextInput extends StatefulWidget {
  const _TextInput({required this.live});

  final LiveSessionController live;

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  final _controller = TextEditingController();

  void _useStarter(String starter) {
    if (_controller.text.trim().isNotEmpty) return;
    _controller.value = TextEditingValue(
      text: starter,
      selection: TextSelection.collapsed(offset: starter.length),
    );
    setState(() {});
  }

  List<String> _starters() {
    final key = widget.live.focusConceptKey;
    if (key == null) return const [];
    final phase = missionSnapshotFor(
      conceptKey: key,
      dossier: widget.live.dossier,
      lastLureId: widget.live.lastLureId,
    ).phase;
    return switch (phase) {
      MissionPhase.teach => [
        switch (widget.live.tactic) {
          TeachingTactic.example => lang.t('たとえば、', 'For example, '),
          TeachingTactic.reason => lang.t('結論から言うと、', 'In short, '),
          TeachingTactic.experiment => lang.t('やってみると、', 'When you try it, '),
        },
      ],
      MissionPhase.challenge => [lang.t('条件をそろえると、', 'If the conditions are the same, '), lang.t('違うと思う。なぜなら、', 'I don\'t think so, because '), lang.t('たとえば、', 'For example, ')],
      MissionPhase.resolve => [lang.t('正しいのは、', 'The right idea is '), lang.t('2つを比べると、', 'Comparing the two, '), lang.t('理由は、', 'The reason is ')],
      MissionPhase.clear => const [],
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 送信中。**繋ぐところから始まる場合があるので数秒かかる。**
  /// この間に二重送信されると、同じ説明が2回逐語に入る
  bool _sending = false;

  Future<void> _send() async {
    if (_sending ||
        widget.live.state == LiveState.connecting ||
        widget.live.state == LiveState.outOfTime ||
        widget.live.state == LiveState.done) {
      return;
    }
    final text = _controller.text;
    if (text.trim().isEmpty) return;

    setState(() => _sending = true);
    try {
      final sent = await widget.live.sendStudentText(text);
      // 接続できなかったときは、書いた文を無言で失わせない。
      // 送信中は入力自体を無効にしているので、成功後に消しても二重送信しない。
      if (sent) _controller.clear();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSend =
        !_sending &&
        widget.live.state != LiveState.connecting &&
        widget.live.state != LiveState.outOfTime &&
        widget.live.state != LiveState.done;

    final starters = _starters();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (starters.isNotEmpty) ...[
            Text(
              lang.t('考え始めるヒント  /  タップしても送信されません', 'Hints to get started  /  Tapping does not send'),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final starter in starters)
                  ActionChip(
                    label: Text(starter),
                    onPressed: canSend ? () => _useStarter(starter) : null,
                  ),
              ],
            ),
            const SizedBox(height: 7),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: canSend,
                  textInputAction: TextInputAction.send,
                  minLines: 1,
                  maxLines: 4,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    // 48dp を割らせない。主要操作は48dp以上を保つ。
                    // isDense を外して既定の高さに戻すのではなく、明示して固定する
                    constraints: BoxConstraints(minHeight: 48),
                    hintText: lang.t('文字で説明する', 'Explain in text'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: canSend ? _send : null,
                icon: const Icon(Icons.send),
                tooltip: lang.t('送る', 'Send'),
                // 既定は 40dp なので明示して広げる
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MicLevel extends StatelessWidget {
  const _MicLevel({required this.live});

  final LiveSessionController live;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return StreamBuilder<double>(
      stream: live.micLevel,
      initialData: 0,
      builder: (context, snap) {
        // AI が喋っている間はマイクを閉じている（半二重）。
        // **バーが動いていると「聞こえている」と誤解する**ので 0 で止める
        final listening = live.isListeningToMic;
        final v = listening ? (snap.data ?? 0).clamp(0.0, 1.0) : 0.0;
        return Semantics(
          label: lang.t('入力音量', 'Input volume'),
          value: listening ? lang.t('${(v * 100).round()}パーセント', '${(v * 100).round()} percent') : lang.t('聞いていません', 'Not listening'),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: v,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainer,
            ),
          ),
        );
      },
    );
  }
}
