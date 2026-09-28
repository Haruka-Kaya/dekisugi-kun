import 'dart:async';

import '../config/app_radius.dart';
import '../config/app_theme.dart';
import '../config/motion.dart';
import '../models/team.dart';
import '../services/consent.dart';
import '../ui/_material.dart';
import '../widgets/readable_width.dart';
import '../widgets/studio_ui.dart';

/// 外部サービスを使えない端末内入口を、本人利用と学校利用へ分ける。
enum RestrictedLocalRoute {
  /// 18歳未満の本人が、個人のゲーム進捗を端末内だけに保存して使う。
  under18Self,

  /// 学校から案内された利用者が、個人報酬を作らない学校用scopeで使う。
  school,
}

/// 最初に1度だけ出す同意画面。
///
/// ## 何を表示するか
///
/// 外国で処理される情報について、**次の3点**を省略せず表示する:
///
/// 1. **移転先の国の名前**
/// 2. **その国の個人情報保護制度**（日本と同等かどうか）
/// 3. **移転先が講じている保護措置**
///
/// 「海外に送信されることがあります」だけでは足りない。**3つを実際に表示する。**
///
/// ## 18歳未満・学校利用
///
/// 現在利用している生成AIサービスの条件に合わせ、18歳未満と学校経路は
/// 会話を開始させず、同意も保存しない。提供条件が整うまでは解除しない。
///
/// > [!warning] 法務の最終確認は受けていない
/// > 文面と年齢の扱いは、公開前に必ず専門家に見てもらうこと。
/// > ここにあるのは「何を表示すべきか」の実装であって、文面の保証ではない。
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({
    super.key,
    required this.onAgreed,
    required this.onUseLocalOnly,
    this.onUseRestrictedLocal,
    this.onUseRestrictedLocalRoute,
  });

  /// `null` は保存完了、[JoinFailure] は学校コードを確認できなかったことを表す。
  /// 学校経路では、呼び出し側がコードをサーバで確認してから同意を保存する。
  final Future<JoinFailure?> Function(ConsentRecord) onAgreed;

  /// 年齢や同意を保存せず、同梱教材だけを使う端末内モードへ進む。
  final VoidCallback onUseLocalOnly;

  /// 18歳未満・学校経路の案内から端末内モードへ進む旧callback。
  ///
  /// 既存callsite互換のため残す。[onUseRestrictedLocalRoute]があればそちらを
  /// 優先し、省略時はこのcallback、さらに省略時は[onUseLocalOnly]を呼ぶ。
  final VoidCallback? onUseRestrictedLocal;

  /// 18歳未満の本人利用と学校利用を、保存せず明示的に分けるcallback。
  ///
  /// 本人利用は個人の端末内ゲームscope、学校利用は無報酬の学校scopeへ
  /// 呼び出し元が配線する。年齢・選択経路はこの画面のstateにだけ存在する。
  final ValueChanged<RestrictedLocalRoute>? onUseRestrictedLocalRoute;

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  AgeBand? _band;
  bool _guardianPresent = false;
  bool _agreedTransfer = false;
  bool _busy = false;

  /// 学校が案内した経路を確認するための、サーバ発行の学校コード。
  final _schoolCode = TextEditingController();
  bool _viaSchool = false;
  JoinFailure? _schoolJoinFailure;

  bool get _needsGuardian => _band == AgeBand.under16 && !_viaSchool;

  /// 現在の外部サービス条件では、成人の個人利用だけを受け付ける。
  /// 環境変数などで迂回できる解除フラグは置かない。
  bool get _currentlyUnavailable =>
      _viaSchool || (_band != null && _band != AgeBand.adult);

  bool get _canProceed =>
      _band != null &&
      !_currentlyUnavailable &&
      _agreedTransfer &&
      (!_needsGuardian || _guardianPresent) &&
      (!_viaSchool || _schoolCode.text.trim().isNotEmpty) &&
      !_busy;

  void _useRestrictedLocal() {
    final route = _viaSchool
        ? RestrictedLocalRoute.school
        : RestrictedLocalRoute.under18Self;
    final typedCallback = widget.onUseRestrictedLocalRoute;
    if (typedCallback != null) {
      typedCallback(route);
      return;
    }
    (widget.onUseRestrictedLocal ?? widget.onUseLocalOnly)();
  }

  @override
  void dispose() {
    _schoolCode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canProceed) return;
    setState(() {
      _busy = true;
      _schoolJoinFailure = null;
    });
    try {
      final failure = await widget.onAgreed(
        ConsentRecord(
          ageBand: _band!,
          // 学校経路で端末の自己申告を同意証跡の代わりにしない。
          // 現在は学校経路自体をUIで遮断しているため、この分岐は将来用。
          guardianPresent: _needsGuardian ? _guardianPresent : null,
          transferAgreed: true,
          agreedAt: DateTime.now(),
          version: kConsentVersion,
          route: _viaSchool ? ConsentRoute.school : ConsentRoute.self,
          schoolCode: _viaSchool ? _schoolCode.text.trim() : null,
        ),
      );
      if (mounted && _viaSchool && failure != null) {
        setState(() => _schoolJoinFailure = failure);
      }
    } finally {
      // 保存側が画面遷移を行わなかった場合も、無限ローディングにしない。
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ReadableWidth(
          child: ListView(
            // **下のシステム余白を自分で足す。** ListView に padding を渡すと
            // Flutter は MediaQuery の余白を足さなくなるので、
            // 最後の「はじめる」がナビゲーションバーの下に潜る（実機で確認）
            padding: EdgeInsets.fromLTRB(
              16,
              18,
              16,
              32 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              const StudioWordmark(),
              const SizedBox(height: 20),
              const _FirstMissionPreview(),
              const SizedBox(height: 30),
              const StudioPageIntro(
                eyebrow: 'はじめまして',
                title: 'あなたの言葉で、\n「わかった」を確かめる。',
                body:
                    '教材を読んだら、今度はあなたが先生役。'
                    'デキすぎ君に教えると、考えの抜けを一緒に見つけられます。',
              ),
              const SizedBox(height: 34),
              Text(
                _currentlyUnavailable
                    ? '端末内モードなら、確認はここまでです。'
                    : 'ここからは、3つだけ確認します。',
                style: t.textTheme.titleMedium?.jaWeight(FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _currentlyUnavailable
                    ? '年齢や同意を保存せず、同梱教材だけで学べます。'
                    : '安心して話せるように、必要な手続きを順番にご案内します。',
                style: t.textTheme.bodySmall?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              _PaperSection(
                header: const StudioSectionHeader(
                  leading: _StepBadge(step: 1),
                  title: '年齢だけ教えてください',
                  description: '生年月日や氏名は集めません。',
                ),
                child: RadioGroup<AgeBand>(
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
              ),
              const SizedBox(height: 14),
              _PaperSection(
                header: const StudioSectionHeader(
                  leading: _StepBadge(step: 2),
                  title: 'どこから使いますか？',
                  description: '学校から案内された場合だけ、学校コードが必要です。',
                ),
                child: Column(
                  children: [
                    _SchoolCard(
                      on: _viaSchool,
                      controller: _schoolCode,
                      onToggle: (v) => setState(() {
                        _viaSchool = v;
                        _schoolJoinFailure = null;
                        // 学校経由に切り替えたら、端末での保護者確認は捨てる。
                        // 残したままだと、戻したときに押した覚えのないチェックが生きる
                        if (v) _guardianPresent = false;
                      }),
                      onChanged: () => setState(() {
                        _schoolJoinFailure = null;
                      }),
                      failure: _schoolJoinFailure,
                      busy: _busy,
                      acceptingCodes: !_currentlyUnavailable,
                    ),
                    if (_currentlyUnavailable) ...[
                      const SizedBox(height: 12),
                      _UnavailableNotice(onUseLocalOnly: _useRestrictedLocal),
                    ] else if (_needsGuardian) ...[
                      const SizedBox(height: 12),
                      _GuardianCard(
                        checked: _guardianPresent,
                        onChanged: (v) => setState(() => _guardianPresent = v),
                      ),
                    ],
                  ],
                ),
              ),
              if (!_currentlyUnavailable) ...[
                const SizedBox(height: 14),
                _PaperSection(
                  header: const StudioSectionHeader(
                    leading: _StepBadge(step: 3),
                    title: '声・文字・Plus の送り先',
                    description: '話し始める前に、実際の送信内容をお読みください。',
                  ),
                  child: Column(
                    children: [
                      const _TransferCard(),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _agreedTransfer,
                        onChanged: (v) =>
                            setState(() => _agreedTransfer = v ?? false),
                        title: const Text('上の内容を読んで、会話時の海外送信に同意します'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  // 同意していないときは**押せない**ようにする。
                  // 押せてしまうと「同意した」の記録が実態と食い違う
                  onPressed: _canProceed ? _submit : null,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_forward),
                  label: const Text('はじめる'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  key: const ValueKey('use-local-only-mode'),
                  onPressed: widget.onUseLocalOnly,
                  icon: const Icon(Icons.phone_android_outlined),
                  label: const Text('通信しない端末内モードを使う'),
                ),
                const SizedBox(height: 6),
                Text(
                  'こちらは年齢や同意を保存せず、外部AI・学校サーバ・購入機能へ接続しません。',
                  style: t.textTheme.bodySmall?.copyWith(
                    color: t.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_needsGuardian && !_guardianPresent)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'おうちの人といっしょに確認してから、はじめてください。',
                      style: t.textTheme.bodySmall?.copyWith(
                        color: t.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _PreviewPhase { predict, challenge, clear }

/// 同意や通信より前に、学習行為そのものを30秒だけ体験できるミッション。
///
/// ここでは音声・自由文・端末IDを一切扱わない。固定された教材と選択肢だけで
/// 端末内に完結させることで、外部送信への同意を先取りせずに
/// 「予想する → 思い込みを見破る → 条件つきで言い直す」を見せる。
class _FirstMissionPreview extends StatefulWidget {
  const _FirstMissionPreview();

  @override
  State<_FirstMissionPreview> createState() => _FirstMissionPreviewState();
}

class _FirstMissionPreviewState extends State<_FirstMissionPreview> {
  final _cardKey = GlobalKey();
  final _feedbackKey = GlobalKey();
  _PreviewPhase _phase = _PreviewPhase.predict;
  String? _feedback;

  void _answer({required bool correct, required _PreviewPhase next}) {
    setState(() {
      if (correct) {
        _phase = next;
        _feedback = null;
      } else {
        _feedback = switch (_phase) {
          _PreviewPhase.predict => 'まだ決着しません。条件は「真空中」です。空気の抵抗が無いときの落ち方を考えてみよう。',
          _PreviewPhase.challenge => 'その答えだと「重いほど速い」が残ります。重さと落下の速さを分けて返そう。',
          _PreviewPhase.clear => null,
        };
      }
    });
    if (correct) {
      _showPhaseStart();
    } else {
      _showFeedback();
    }
  }

  void _restart() {
    setState(() {
      _phase = _PreviewPhase.predict;
      _feedback = null;
    });
    _showPhaseStart();
  }

  void _showPhaseStart() {
    _showTarget(_cardKey, alignment: 0);
  }

  void _showFeedback() {
    _showTarget(_feedbackKey, alignment: 1);
  }

  void _showTarget(GlobalKey targetKey, {required double alignment}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetContext = targetKey.currentContext;
      if (targetContext == null) return;
      final reduceMotion = ReduceMotionScope.of(context);
      unawaited(
        Scrollable.ensureVisible(
          targetContext,
          alignment: alignment,
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    return Container(
      key: _cardKey,
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
      decoration: BoxDecoration(
        color: c.heroSurface,
        borderRadius: BorderRadius.circular(AppRadius.stage),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: c.charBody,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Icon(Icons.science_outlined, color: c.charFace),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _phase == _PreviewPhase.clear
                          ? 'TUTORIAL CLEAR  /  流れを体験'
                          : '30秒おためしミッション',
                      style: t.textTheme.labelMedium
                          ?.copyWith(color: c.heroMuted)
                          .jaWeight(FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '通信せず、端末の中だけで動きます。',
                      style: t.textTheme.bodySmall?.copyWith(
                        color: c.heroMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_phase == _PreviewPhase.predict) ...[
            Text(
              '真空中で、重い球と軽い球を同じ高さから同時に落とす。どちらが先に着く？',
              key: const Key('preview-predict-question'),
              style: t.textTheme.titleMedium
                  ?.copyWith(color: c.onHeroSurface, height: 1.45)
                  .jaWeight(FontWeight.w700),
            ),
            const SizedBox(height: 14),
            _PreviewChoice(
              key: const Key('preview-predict-heavy'),
              label: '重い球が先に着く',
              onPressed: () =>
                  _answer(correct: false, next: _PreviewPhase.challenge),
            ),
            const SizedBox(height: 8),
            _PreviewChoice(
              key: const Key('preview-predict-same'),
              label: '同時に着く',
              onPressed: () =>
                  _answer(correct: true, next: _PreviewPhase.challenge),
            ),
            const SizedBox(height: 8),
            _PreviewChoice(
              label: '軽い球が先に着く',
              onPressed: () =>
                  _answer(correct: false, next: _PreviewPhase.challenge),
            ),
          ] else if (_phase == _PreviewPhase.challenge) ...[
            Text(
              'デキすぎ君の思い込み',
              style: t.textTheme.labelMedium
                  ?.copyWith(color: c.heroMuted)
                  .jaWeight(FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '「えっと、じゃあ重いものの方が速く落ちるってこと？」',
              key: const Key('preview-challenge'),
              style: t.textTheme.titleMedium
                  ?.copyWith(color: c.onHeroSurface, height: 1.45)
                  .jaWeight(FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              'どこを直す？',
              style: t.textTheme.bodyMedium?.copyWith(color: c.heroMuted),
            ),
            const SizedBox(height: 12),
            _PreviewChoice(
              label: 'そう。重いものほど速く落ちる',
              onPressed: () =>
                  _answer(correct: false, next: _PreviewPhase.clear),
            ),
            const SizedBox(height: 8),
            _PreviewChoice(
              key: const Key('preview-correct-challenge'),
              label: '違う。空気の抵抗を無視すれば、重さに関係なく同時に着く',
              onPressed: () =>
                  _answer(correct: true, next: _PreviewPhase.clear),
            ),
            const SizedBox(height: 8),
            _PreviewChoice(
              label: '違う。軽いものほど速く落ちる',
              onPressed: () =>
                  _answer(correct: false, next: _PreviewPhase.clear),
            ),
          ] else ...[
            Semantics(
              key: const Key('preview-clear-region'),
              container: true,
              liveRegion: true,
              label: 'おためしミッションクリア。条件を使って思い込みを見破りました。',
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '条件を使って、\n思い込みを見破った。',
                      key: const Key('preview-clear'),
                      style: t.textTheme.headlineSmall
                          ?.copyWith(color: c.onHeroSurface, height: 1.35)
                          .jaWeight(FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '空気の抵抗を無視すれば、落下の速さは重さに関係しません。',
                      style: t.textTheme.bodyMedium?.copyWith(
                        color: c.heroMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '本番は選択肢ではなく、あなたの言葉を声か文字で教えます。最初の一言は、うまくなくて大丈夫です。',
              style: t.textTheme.bodySmall?.copyWith(color: c.heroMuted),
            ),
            const SizedBox(height: 12),
            _PreviewChoice(label: 'もう一度ためす', onPressed: _restart),
          ],
          if (_feedback case final feedback?) ...[
            const SizedBox(height: 12),
            Semantics(
              key: _feedbackKey,
              liveRegion: true,
              label: feedback,
              excludeSemantics: true,
              child: Container(
                key: const Key('preview-feedback'),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
                decoration: BoxDecoration(
                  color: c.onHeroSurface.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.refresh, size: 19, color: c.onHeroSurface),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feedback,
                        style: t.textTheme.bodySmall?.copyWith(
                          color: c.onHeroSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewChoice extends StatelessWidget {
  const _PreviewChoice({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: c.onHeroSurface,
        side: BorderSide(color: c.onHeroSurface.withValues(alpha: 0.42)),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      child: Text(label, textAlign: TextAlign.left),
    );
  }
}

class _PaperSection extends StatelessWidget {
  const _PaperSection({required this.header, required this.child});

  final Widget header;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xxl),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [header, const SizedBox(height: 14), child],
        ),
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Semantics(
      label: 'ステップ$step/3',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Text(
          '$step',
          style: t.textTheme.labelLarge
              ?.copyWith(color: t.colorScheme.onPrimaryContainer)
              .jaWeight(FontWeight.w700),
        ),
      ),
    );
  }
}

/// 学校から配られた場合の入口。
///
/// **端末で「保護者に確認しました」を押させない。**
/// 押すのは生徒であって保護者ではないため、学校が必要な手続を確認した記録の
/// 代わりにはならない。弱い自己申告で上書きしないよう、経路そのものを分ける。
///
/// 学校コードは同意そのものの証跡ではない。
/// サーバで有効な招待だと確認し、「学校が案内した経路」へ入るために使う。
class _SchoolCard extends StatelessWidget {
  const _SchoolCard({
    required this.on,
    required this.controller,
    required this.onToggle,
    required this.onChanged,
    required this.failure,
    required this.busy,
    required this.acceptingCodes,
  });

  final bool on;
  final TextEditingController controller;
  final ValueChanged<bool> onToggle;
  final VoidCallback onChanged;
  final JoinFailure? failure;
  final bool busy;
  final bool acceptingCodes;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    return Material(
      color: c.coolSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 4, 14, on ? 14 : 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              value: on,
              onChanged: busy ? null : (v) => onToggle(v ?? false),
              title: Text(
                '学校からもらって使います',
                style: t.textTheme.titleSmall
                    ?.copyWith(color: c.onCoolSurface)
                    .jaWeight(FontWeight.w700),
              ),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            if (on) ...[
              Text(
                '学校から教えてもらった学校コードを入れてください。',
                style: t.textTheme.bodyMedium?.copyWith(color: c.onCoolSurface),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                enabled: !busy && acceptingCodes,
                onChanged: (_) => onChanged(),
                autocorrect: false,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: '学校コード',
                  hintText: 'ABCD-EFGH',
                ),
              ),
              if (failure case final e?) ...[
                const SizedBox(height: 10),
                Semantics(
                  container: true,
                  liveRegion: true,
                  label: '学校コードを確認できません。${e.message}',
                  child: ExcludeSemantics(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: t.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: t.colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              e.message,
                              style: t.textTheme.bodyMedium?.copyWith(
                                color: t.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                acceptingCodes
                    ? 'このコードは、学校が案内した経路の確認に使います。'
                          'コード自体が同意の証明になるものではありません。'
                    : '学校コードの入力と送信は、提供開始までできません。',
                style: t.textTheme.bodySmall?.copyWith(
                  color: c.onCoolSurface.withValues(alpha: 0.82),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 外部サービスの提供条件を満たさない経路を、理由不明の無効ボタンにしない。
class _UnavailableNotice extends StatelessWidget {
  const _UnavailableNotice({required this.onUseLocalOnly});

  final VoidCallback onUseLocalOnly;

  static const message = '外部サービスを使うモードは、18歳未満・学校向けに提供していません。';
  static const action =
      '同梱教材を通信せずに使う「端末内モード」なら、今すぐ学べます。'
      '年齢や同意は保存しません。';
  static const assurance =
      '外部AI・学校サーバ・購入機能へ接続しません。入力した説明は送信・保存せず、'
      '自動採点や理解認定も行いません。';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    return Semantics(
      key: const ValueKey('local-only-unavailable-notice'),
      container: true,
      liveRegion: true,
      explicitChildNodes: true,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label: '$message$action$assurance',
              liveRegion: true,
              child: ExcludeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.phonelink_lock_outlined,
                      color: scheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message,
                            style: t.textTheme.titleSmall
                                ?.copyWith(color: scheme.onTertiaryContainer)
                                .jaWeight(FontWeight.w700),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            action,
                            style: t.textTheme.bodyMedium?.copyWith(
                              color: scheme.onTertiaryContainer,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            assurance,
                            style: t.textTheme.bodySmall?.copyWith(
                              color: scheme.onTertiaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              key: const ValueKey('use-local-only-mode'),
              onPressed: onUseLocalOnly,
              icon: const Icon(Icons.phone_android_outlined),
              label: const Text('通信しない端末内モードを使う'),
            ),
          ],
        ),
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
    final c = context.appColors;
    return Material(
      color: c.warmSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.family_restroom, size: 20, color: c.onWarmSurface),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'おうちの人の確認',
                    style: t.textTheme.titleSmall
                        ?.copyWith(color: c.onWarmSurface)
                        .jaWeight(FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '16歳未満の場合、このアプリを使うことについて、'
              'おうちの人の確認が必要です。',
              style: t.textTheme.bodyMedium?.copyWith(color: c.onWarmSurface),
            ),
            CheckboxListTile(
              value: checked,
              onChanged: (v) => onChanged(v ?? false),
              title: Text(
                'おうちの人といっしょに確認しました',
                style: t.textTheme.bodyMedium?.copyWith(color: c.onWarmSurface),
              ),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
    );
  }
}

/// 外部サービスと越境処理の説明。**3点を省略しない。**
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
              Expanded(
                child: Text('使う機能によって送り先が変わります', style: t.textTheme.titleSmall),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final (label, body) in kExternalServiceDisclosure)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: t.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(body, style: t.textTheme.bodyMedium),
                ],
              ),
            ),
          Text(
            'Plus を使わない間は、RevenueCat SDK を起動しません。',
            style: t.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          for (final (label, body) in kTransferDisclosure)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: t.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
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
