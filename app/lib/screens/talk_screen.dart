import 'package:provider/provider.dart';

import '../config/app_radius.dart';
import '../config/app_theme.dart';
import '../config/env.dart';
import '../services/live_session.dart';
import '../services/mic_stream.dart';
import '../ui/_material.dart';
import '../widgets/dossier_bar.dart';
import '../widgets/stage.dart';

/// 会話画面。
///
/// キャラクターを中心に置き、その下に理解カルテ、逐語、操作を並べる。
/// **状態は「キャラの見た目」と「文字」の両方で出す** — 動きが止まっている
/// 端末（Reduce Motion / 古い端末）でも、いま何が起きているか分かる必要がある。
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
                Stage(live: live),
                if (live.failure != null) _FailureBanner(failure: live.failure!),
                if (live.recordingIssue != null)
                  _IssueBanner(issue: live.recordingIssue!),
                if (live.dossier != null) DossierBar(dossier: live.dossier!),
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

/// 続けられなくなった理由。**色だけでなくアイコンと文言で出す**（SC 1.4.1）。
class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.failure});

  final LiveFailure failure;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    final text = switch (failure) {
      LiveFailure.noPermission => 'マイクを使う許可がありません',
      LiveFailure.network => 'ネットワークにつながりません',
      LiveFailure.auth => 'APIキーが受け付けられませんでした',
      LiveFailure.unknown => '続けられませんでした',
    };

    return Container(
      width: double.infinity,
      color: c.weakChip,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // 失敗の合図には ✗ を使ってよい。ここは生徒の理解の話ではない
          Icon(Icons.error_outline, size: 18, color: c.weakFg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: t.textTheme.bodyMedium?.copyWith(color: c.weakFg)),
          ),
        ],
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
          child: Text(
            'ボタンを押して、教えたいことを声で説明してください。',
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
        final interim =
            i == rows.length - 1 && live.interimStudentText.isNotEmpty && isStudent;
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
              style:
                  t.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
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
            // 音量は「聞こえている」を音より先に目で返す層。
            // 高さぶんの場所は常に確保して、出たり消えたりで行が跳ねないようにする
            SizedBox(height: 6, child: running ? _MicLevel(live: live) : null),
            const SizedBox(height: 10),
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
