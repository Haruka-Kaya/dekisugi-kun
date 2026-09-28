import '../config/app_radius.dart';
import '../config/app_theme.dart';
import '../services/team_client.dart';
import '../ui/_material.dart';
import '../widgets/readable_width.dart';
import '../widgets/studio_ui.dart';

/// クラスコードを入れて参加する。
///
/// 初回同意の「学校コード」と同じサーバ発行のTeam招待コードを使う。
/// 初回同意で参加済みなら、通常はこの画面を使わない。
class TeamJoinScreen extends StatefulWidget {
  const TeamJoinScreen({super.key, required this.client});

  final TeamClient client;

  @override
  State<TeamJoinScreen> createState() => _TeamJoinScreenState();
}

class _TeamJoinScreenState extends State<TeamJoinScreen> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _error;

  bool get _canJoin => !_sending && _controller.text.trim().isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_sending) return;
    final code = _controller.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _sending = true;
      _error = null;
    });
    final r = await widget.client.join(code);
    if (!mounted) return;
    if (r.team != null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _sending = false;
      _error = r.error?.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('クラスに入る')),
      body: ReadableWidth(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            28 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            const StudioPageIntro(
              eyebrow: 'クラスと学ぶ',
              title: 'ひとりの説明を、\nみんなの積み重ねへ。',
              body: '比べるのは個人ではなく、クラス全体で集まった説明の数だけです。',
            ),
            const SizedBox(height: 20),
            const _ClassPromise(),
            const SizedBox(height: 26),
            const StudioSectionHeader(
              title: '先生からのコードを入力',
              description: '黒板やプリントにある英数字を、そのまま入れてください。',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.xxl),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '先生からもらったクラスコードを入れてください。',
                    style: t.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    enabled: !_sending,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.go,
                    onChanged: (_) => setState(() => _error = null),
                    onSubmitted: (_) {
                      if (_canJoin) _join();
                    },
                    style: const TextStyle(
                      // コードは記号列。**等幅で出す**と読み合わせやすい
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                    ),
                    decoration: const InputDecoration(
                      constraints: BoxConstraints(minHeight: 56),
                      labelText: 'クラスコード',
                      hintText: 'ABCD-EFGH',
                    ),
                  ),
                  if (_error case final e?) ...[
                    const SizedBox(height: 12),
                    Semantics(
                      container: true,
                      liveRegion: true,
                      label: 'クラスコードを確認できません。$e',
                      child: ExcludeSemantics(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 色だけで伝えない (SC 1.4.1)
                              Icon(
                                Icons.info_outline,
                                size: 20,
                                color: scheme.onErrorContainer,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  e,
                                  style: t.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _canJoin ? _join : null,
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.group_add_outlined),
                    label: Text(_sending ? '確かめています…' : '入る'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const _PrivacyNote(),
          ],
        ),
      ),
    );
  }
}

class _ClassPromise extends StatelessWidget {
  const _ClassPromise();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.warmSurface,
        borderRadius: BorderRadius.circular(AppRadius.stage),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: c.onWarmSurface.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Icon(Icons.forum_outlined, color: c.onWarmSurface),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '教えた数が、クラスの合計に。',
                  style: t.textTheme.titleMedium
                      ?.copyWith(color: c.onWarmSurface)
                      .jaWeight(FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  '名前も順位も使いません。みんなが説明した合計だけが、同じクラスに見えます。',
                  style: t.textTheme.bodySmall?.copyWith(
                    color: c.onWarmSurface.withValues(alpha: 0.84),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.coolSurface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: c.onCoolSurface),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '個人の活動は表示しません',
                  style: t.textTheme.titleSmall
                      ?.copyWith(color: c.onCoolSurface)
                      .jaWeight(FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'クラスに入ると、クラス全体で集まった説明の数が見られます。'
                  '誰が何をしたかは出ません。',
                  style: t.textTheme.bodySmall?.copyWith(
                    color: c.onCoolSurface.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
