import '../config/app_radius.dart';
import '../services/consent.dart';
import '../ui/_material.dart';

/// 最初に1度だけ出す同意画面。
///
/// ## 何を出すかは法律で決まっている
///
/// 個人データを外国の第三者へ渡すときは、本人に**次の3点**を伝えたうえで
/// 同意を得る必要がある（個人情報保護法 28条／規則17条）:
///
/// 1. **移転先の国の名前**
/// 2. **その国の個人情報保護制度**（日本と同等かどうか）
/// 3. **移転先が講じている保護措置**
///
/// 「海外に送信されることがあります」だけでは足りない。**3つを実際に表示する。**
///
/// ## 16歳未満
///
/// 2028年7月までに、16歳未満の同意には保護者の関与が必要になる。
/// いま作る画面なので**最初から入れておく**（あとから足すと、
/// すでに使っている利用者の同意を取り直すことになる）。
///
/// > [!warning] 法務の最終確認は受けていない
/// > 文面と年齢の扱いは、公開前に必ず専門家に見てもらうこと。
/// > ここにあるのは「何を表示すべきか」の実装であって、文面の保証ではない。
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key, required this.onAgreed});

  final Future<void> Function(ConsentRecord) onAgreed;

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  AgeBand? _band;
  bool _guardianPresent = false;
  bool _agreedTransfer = false;
  bool _busy = false;

  bool get _needsGuardian => _band == AgeBand.under16;

  bool get _canProceed =>
      _band != null &&
      _agreedTransfer &&
      (!_needsGuardian || _guardianPresent) &&
      !_busy;

  Future<void> _submit() async {
    if (!_canProceed) return;
    setState(() => _busy = true);
    await widget.onAgreed(ConsentRecord(
      ageBand: _band!,
      guardianPresent: _needsGuardian ? _guardianPresent : null,
      transferAgreed: true,
      agreedAt: DateTime.now(),
      version: kConsentVersion,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('はじめる前に')),
      // **下のシステム余白を自分で足す。** ListView に padding を渡すと
      // Flutter は MediaQuery の余白を足さなくなるので、
      // 最後の「はじめる」がナビゲーションバーの下に潜る（実機で確認）
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          Text('あなたのことを教えてください', style: t.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('年齢によって、必要な手続きが変わります。',
              style: t.textTheme.bodySmall
                  ?.copyWith(color: t.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          // RadioListTile の groupValue/onChanged は非推奨。RadioGroup で束ねる
          RadioGroup<AgeBand>(
            groupValue: _band,
            onChanged: (v) => setState(() => _band = v),
            child: Column(
              children: [
                for (final band in AgeBand.values)
                  RadioListTile<AgeBand>(
                    value: band,
                    title: Text(band.label),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
          if (_needsGuardian) ...[
            const SizedBox(height: 8),
            _GuardianCard(
              checked: _guardianPresent,
              onChanged: (v) => setState(() => _guardianPresent = v),
            ),
          ],
          const SizedBox(height: 20),
          const _TransferCard(),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _agreedTransfer,
            onChanged: (v) => setState(() => _agreedTransfer = v ?? false),
            title: const Text('上の内容を読んで、海外への送信に同意します'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 16),
          FilledButton(
            // 同意していないときは**押せない**ようにする。
            // 押せてしまうと「同意した」の記録が実態と食い違う
            onPressed: _canProceed ? _submit : null,
            child: const Text('はじめる'),
          ),
          if (_needsGuardian && !_guardianPresent)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'おうちの人といっしょに確認してから、はじめてください。',
                style: t.textTheme.bodySmall
                    ?.copyWith(color: t.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _GuardianCard extends StatelessWidget {
  const _GuardianCard({required this.checked, required this.onChanged});

  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.family_restroom, size: 20),
                const SizedBox(width: 8),
                Text('おうちの人の確認', style: t.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '16歳未満の場合、このアプリを使うことについて、'
              'おうちの人の確認が必要です。',
              style: t.textTheme.bodyMedium,
            ),
            CheckboxListTile(
              value: checked,
              onChanged: (v) => onChanged(v ?? false),
              title: const Text('おうちの人といっしょに確認しました'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
    );
  }
}

/// 越境移転の説明。**3点を省略しない。**
class _TransferCard extends StatelessWidget {
  const _TransferCard();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.public, size: 20),
              const SizedBox(width: 8),
              Text('声とことばが海外に送られます', style: t.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'デキすぎ君と話すと、あなたの声と、話した内容の文字が'
            'Google のサービスに送られます。',
            style: t.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          for (final (label, body) in kTransferDisclosure)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: t.textTheme.labelLarge
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(body, style: t.textTheme.bodyMedium),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
