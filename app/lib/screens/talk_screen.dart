import 'package:provider/provider.dart';

import '../config/app_radius.dart';
import '../config/app_theme.dart';
import '../config/env.dart';
import '../services/live_session.dart';
import '../services/mic_stream.dart';
import '../services/session_store.dart';
import '../services/units_client.dart';
import '../ui/_material.dart';
import '../widgets/dossier_bar.dart';
import '../widgets/quota_view.dart';
import '../widgets/stage.dart';
import 'review_screen.dart';

/// 会話画面。
///
/// キャラクターを中心に置き、その下に理解カルテ、逐語、操作を並べる。
/// **状態は「キャラの見た目」と「文字」の両方で出す** — 動きが止まっている
/// 端末（Reduce Motion / 古い端末）でも、いま何が起きているか分かる必要がある。
class TalkScreen extends StatefulWidget {
  const TalkScreen({super.key, required this.unitTitle});

  /// いま教えている単元。**画面に出す。**
  /// 教材を隠しているので、何について話しているかの手がかりが要る
  final String unitTitle;

  @override
  State<TalkScreen> createState() => _TalkScreenState();
}

class _TalkScreenState extends State<TalkScreen> {
  /// 中断していた会話。あれば「続きから」を出す
  SavedSession? _unfinished;

  @override
  void initState() {
    super.initState();
    _lookForUnfinished();
    // 残りは会話を始める前に見せる（枠は引かない）
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<LiveSessionController>().refreshQuota());
  }

  Future<void> _lookForUnfinished() async {
    final store = context.read<SessionStore>();
    final saved = await store.unfinished();
    if (mounted) setState(() => _unfinished = saved);
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
    await context.read<SessionStore>().finishSession(saved.id);
    setState(() => _unfinished = null);
  }

  @override
  Widget build(BuildContext context) {
    final live = context.watch<LiveSessionController>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('デキすぎ君に教える'),
            Text(
              widget.unitTitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          // 残りは**最初から見せる**。減ってから知らせると、
          // 会話の途中で急に切れて何が起きたか分からなくなる
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: QuotaChip(live: live),
          ),
          IconButton(
            tooltip: 'もう一度見るところ',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => ReviewScreen(
                store: context.read<SessionStore>(),
                units: context.read<UnitsClient>(),
              ),
            )),
            icon: const Icon(Icons.bookmarks_outlined),
          ),
          if (live.isRunning)
            IconButton(
              tooltip: '終わる',
              onPressed: live.stop,
              icon: const Icon(Icons.stop_circle_outlined),
            ),
        ],
      ),
      body: !Env.hasServer
          ? const _MissingServer()
          : Column(
              children: [
                Stage(live: live),
                if (_unfinished != null && !live.isRunning)
                  _ResumeBanner(
                    saved: _unfinished!,
                    onResume: _resume,
                    onDiscard: _discard,
                  ),
                if (live.failure != null) _FailureBanner(failure: live.failure!),
                if (live.recordingIssue != null)
                  _IssueBanner(issue: live.recordingIssue!),
                if (live.suspectsSelfInterruption) const _EchoBanner(),
                if (live.dossier != null) DossierBar(dossier: live.dossier!),
                if (live.state == LiveState.outOfTime)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: OutOfTimeCard(resetsAt: live.quotaResetsAt),
                  ),
                Expanded(child: _TurnLog(live: live)),
                _Composer(live: live),
              ],
            ),
    );
  }
}

class _MissingServer extends StatelessWidget {
  const _MissingServer();

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
            Text('接続先が設定されていません', style: t.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '--dart-define=SERVER_URL=... を付けてビルドしてください。',
              style: t.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
    required this.onResume,
    required this.onDiscard,
  });

  final SavedSession saved;
  final VoidCallback onResume;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    final turns = saved.transcript.where((u) => u.isStudent).length;

    return Container(
      width: double.infinity,
      color: c.highlightFlash,
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '前回の続きがあります（$turns回ぶん）',
              style: t.textTheme.bodyMedium,
            ),
          ),
          // 破棄は「捨てる」と分かる文言にする。取り消せない操作なので
          TextButton(onPressed: onDiscard, child: const Text('捨てる')),
          FilledButton(onPressed: onResume, child: const Text('続きから')),
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
      color: c.shakyChip,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.headphones, size: 18, color: c.shakyFg),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'デキすぎ君の声をマイクが拾っているようです。'
              'イヤホンをつけると話しやすくなります。',
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
            if (kTextInputEnabled && running) _TextInput(live: live),
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

/// 検証用の文字入力。**既定では出ない。**
///
/// `flutter build apk --dart-define=DEKISUGI_TEXT_INPUT=true` で出る。
/// 音声だと部屋の音・マイクの当たり外れ・読み上げの手間が混ざって、
/// 何を試したのか再現できない。文字なら同じ入力を何度でも通せる。
const bool kTextInputEnabled =
    bool.fromEnvironment('DEKISUGI_TEXT_INPUT');

class _TextInput extends StatefulWidget {
  const _TextInput({required this.live});

  final LiveSessionController live;

  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    widget.live.sendStudentText(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                hintText: '検証用: 文字で送る',
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _send,
            icon: const Icon(Icons.send),
            tooltip: '送る',
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
          label: '入力音量',
          value: listening ? '${(v * 100).round()}パーセント' : '聞いていません',
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
