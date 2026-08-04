import '../config/app_theme.dart';
import '../ui/_material.dart';
import '../widgets/status_chip.dart';

/// 段階0 の足場。テーマが両モードで成立しているかを目視するためだけの画面。
/// 段階1 で会話画面に置き換える。
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('デキすぎ君')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('説明の結果', style: t.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in ExplainStatus.values)
                        StatusChip(status: s),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'あなたが説明して、デキすぎ君がわからないところを聞き返します。'
                    '直せなかったところは弱点ではなく、次に見るところとして残ります。',
                    style: t.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () {},
                  child: const Text('教えはじめる'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () {},
                  child: const Text('あとで'),
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    labelText: '単元をさがす',
                    hintText: '例: 力のはたらき',
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
