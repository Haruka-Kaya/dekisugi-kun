import 'package:provider/provider.dart';

import '../config/app_radius.dart';
import '../config/app_theme.dart';
import '../config/env.dart';
import '../services/live_session.dart';
import '../services/mic_stream.dart';
import '../ui/_material.dart';

/// 段階1 の会話画面。
///
/// **これは仕上げではない。** キャラクターと演出は段階3。
/// いまは「音声が往復し、割り込めて、切れずに続く」ことを実機で確かめるための画面で、
/// そのために状態・文字起こし・音量・異常を全部見えるようにしてある。
class TalkScreen extends StatelessWidget {
  const TalkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final live = context.watch<LiveSessionController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('デキすぎ君に教える'),
        actions: [
          if (live.isRunning)
            IconButton(
              tooltip: '終わる',
              onPressed: live.stop,
              icon: const Icon(Icons.stop_circle_outlined),
            ),
        ],
      ),
      body: !Env.hasGeminiKey
          ? const _MissingKey()
          : Column(
              children: [
                _StateBanner(state: live.state, failure: live.failure),
                if (live.recordingIssue != null)
                  _IssueBanner(issue: live.recordingIssue!),
                Expanded(child: _TurnLog(live: live)),
                _Composer(live: live),
              ],
            ),
    );
  }
}

class _MissingKey extends StatelessWidget {
  const _MissingKey();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.key_off, size: 40, color: t.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('APIキーが渡されていません', style: t.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'tools\\run-dev.ps1 から起動するか、'
              '--dart-define=GEMINI_API_KEY=... を付けてビルドしてください。',
              style: t.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// いまどの状態かを、色・アイコン・文言の3点セットで出す (SC 1.4.1)。
class _StateBanner extends StatelessWidget {
  const _StateBanner({required this.state, required this.failure});

  final LiveState state;
  final LiveFailure? failure;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;

    final (IconData icon, String label, Color fg, Color bg) = switch (state) {
      LiveState.idle => (
          Icons.circle_outlined,
          'まだ始まっていません',
          c.untouchedFg,
          c.untouchedChip
        ),
      LiveState.connecting => (
          Icons.sync,
          'つないでいます',
          c.untouchedFg,
          c.untouchedChip
        ),
      LiveState.listening => (
          Icons.hearing,
          '聞いています',
          c.gotItFg,
          c.gotItChip
        ),
      LiveState.thinking => (
          Icons.more_horiz,
          '考えています',
          c.shakyFg,
          c.shakyChip
        ),
      LiveState.speaking => (
          Icons.graphic_eq,
          '話しています',
          t.colorScheme.primary,
          t.colorScheme.primaryContainer
        ),
      LiveState.failed => (
          Icons.bookmark,
          _failureText(failure),
          c.weakFg,
          c.weakChip
        ),
    };

    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: t.textTheme.titleSmall
                  ?.copyWith(color: fg, height: 1.3)
                  .jaWeight(FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  static String _failureText(LiveFailure? f) => switch (f) {
        LiveFailure.noPermission => 'マイクを使う許可がありません',
        LiveFailure.network => 'ネットワークにつながりません',
        LiveFailure.auth => 'APIキーが受け付けられませんでした',
        _ => '続けられませんでした',
      };
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
      RecordingIssue.silent => 'マイクが音を拾えていません。ふさいでいないか確かめてください。',
      RecordingIssue.quiet => '声が小さいようです。マイクに近づいてください。',
      RecordingIssue.clipped => '音が大きすぎて割れています。少し離れてください。',
    };

    return Container(
      width: double.infinity,
      color: c.shakyChip,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.mic_none, size: 18, color: c.shakyFg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: t.textTheme.bodySmall?.copyWith(color: c.shakyFg)),
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
    // 生徒と AI を交互に並べる。片方が続くこともあるので、単純に時系列で持たず
    // それぞれの列を突き合わせる（段階2 で1本の逐語に置き換える）
    final rows = <(bool isStudent, String text)>[];
    final n = live.studentTurns.length > live.aiTurns.length
        ? live.studentTurns.length
        : live.aiTurns.length;
    for (var i = 0; i < n; i++) {
      if (i < live.studentTurns.length) rows.add((true, live.studentTurns[i]));
      if (i < live.aiTurns.length) rows.add((false, live.aiTurns[i]));
    }
    if (live.interimStudentText.isNotEmpty) {
      rows.add((true, live.interimStudentText));
    }

    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'マイクのボタンを押して、教えたいことを声で説明してください。',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final (isStudent, text) = rows[i];
        final interim = i == rows.length - 1 &&
            live.interimStudentText.isNotEmpty &&
            isStudent;
        return _Bubble(isStudent: isStudent, text: text, interim: interim);
      },
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
          color: isStudent ? scheme.secondaryContainer : scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isStudent ? 'あなた' : 'デキすぎ君',
              style: t.textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
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
              Text('…変換中',
                  style: t.textTheme.labelSmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.live});

  final LiveSessionController live;

  @override
  Widget build(BuildContext context) {
    final running = live.isRunning;
    final busy = live.state == LiveState.connecting;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (running) _MicLevel(live: live),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: busy ? null : (running ? live.stop : live.start),
              icon: Icon(running ? Icons.stop : Icons.mic),
              label: Text(running ? 'おわる' : 'はなしかける'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 音量。「聞こえている」ことを音より先に目で返す。
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
        final v = (snap.data ?? 0).clamp(0.0, 1.0);
        return Semantics(
          label: '入力音量',
          value: '${(v * 100).round()}パーセント',
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
