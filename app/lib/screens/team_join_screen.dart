import '../services/team_client.dart';
import '../ui/_material.dart';
import '../widgets/readable_width.dart';

/// クラスコードを入れて参加する。
///
/// > [!note] 「あいことば」とは別のもの
/// > あいことばは学校が決めて**サーバへ送らない**もので、
/// > 学校経由かどうかの分岐にだけ使う。
/// > クラスコードは開発者が発行し、どのクラスかを判別するために送る。
/// > 配布資料でも別物として説明している。
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
              16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
          children: [
            Text(
              '先生からもらったクラスコードを入れてください。',
              style: t.textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'クラスに入ると、クラス全体で集まった説明の数が見られます。'
              '誰が何をしたかは出ません。',
              style: t.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              enabled: !_sending,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _join(),
              style: const TextStyle(
                // コードは記号列。**等幅で出す**と読み合わせやすい
                fontFamily: 'monospace',
                letterSpacing: 2,
              ),
              decoration: const InputDecoration(
                constraints: BoxConstraints(minHeight: 56),
                border: OutlineInputBorder(),
                labelText: 'クラスコード',
                hintText: 'ABCD-EFGH',
              ),
            ),
            if (_error case final e?) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 色だけで伝えない (SC 1.4.1)
                  Icon(Icons.info_outline, size: 18, color: scheme.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(e,
                        style: t.textTheme.bodyMedium
                            ?.copyWith(color: scheme.error)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _sending ? null : _join,
              child: Text(_sending ? '確かめています…' : '入る'),
            ),
          ],
        ),
      ),
    );
  }
}
