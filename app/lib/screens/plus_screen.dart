import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_language.dart' as l10n;
import '../config/app_radius.dart';
import '../config/app_theme.dart';
import '../models/purchase.dart';
import '../services/purchase_service.dart';
import '../ui/_material.dart';
import '../widgets/readable_width.dart';
import '../widgets/studio_ui.dart';

/// 保護者向け復習プラン・共有レポート・限定マスコットを届ける、自前の Plus 購入画面。
///
/// 価格・商品名・説明・請求期間は RevenueCat が返した Current Offering だけを表示する。
/// 画面側で無料体験や割引を推測せず、全条件を表示できない商品は購入を止める。
class PlusScreen extends StatefulWidget {
  const PlusScreen({
    super.key,
    required this.purchaseService,
    this.onClose,
    this.onEntitlementSync,
    this.onPlusActivated,
    this.openExternalUri,
  });

  final PurchaseService purchaseService;
  final VoidCallback? onClose;

  /// SDK が Plus active を返したとき、端末内の Plus 特典を付与する。
  ///
  /// 成否を同期メッセージに混ぜない。失敗しても購入自体は有効なので、
  /// 呼び出し側で握り潰してよい。
  final Future<void> Function()? onPlusActivated;

  /// 購入・復元後、サーバー側の会話枠へ反映できたかを確認する。
  ///
  /// 単体利用時は省略できる。指定時は SDK が active を返した場合にだけ呼び、
  /// false または例外なら再購入させず、この同期だけを再試行できるようにする。
  final Future<bool> Function()? onEntitlementSync;

  /// Privacy・ストア規約・購読管理を開く境界。テストではOSを呼ばない fake を渡す。
  final Future<bool> Function(Uri uri)? openExternalUri;

  @override
  State<PlusScreen> createState() => _PlusScreenState();
}

class _PlusScreenState extends State<PlusScreen> {
  PurchaseOverview? _overview;
  _Notice? _notice;
  bool _loading = true;
  bool _busy = false;
  bool _linkBusy = false;
  bool _syncPending = false;
  String? _busyPackageId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() {
      _loading = true;
      _notice = null;
    });

    PurchaseOverview overview;
    try {
      overview = await widget.purchaseService.load();
    } catch (_) {
      overview = const PurchaseOverview.unavailable('ui_load_failed');
    }
    if (!mounted) return;

    // Webhook が遅れている／端末が長くオフラインだった場合でも、Store 側の
    // active 表示だけを信じて「枠へ反映済み」とは扱わない。購入直後と同じ
    // server-authoritative な照合を、既存購入を読み込んだときにも一度行う。
    final shouldSync =
        overview.plus.isActive && widget.onEntitlementSync != null;
    final synced = shouldSync ? await _syncEntitlement() : true;
    if (overview.plus.isActive) await _grantPlusPerks();
    if (!mounted) return;
    setState(() {
      _overview = overview;
      _loading = false;
      _syncPending = !synced;
      _notice = !shouldSync
          ? null
          : synced
          ? _Notice(
              l10n.t(
                'Plusと会話枠の状態を確認しました。',
                'Plus and your conversation allowance are confirmed.',
              ),
              _NoticeTone.confirmation,
            )
          : _Notice(
              l10n.t(
                'Plusの購入情報は確認できましたが、会話枠への反映を確認できませんでした。'
                    '通信を確認して再試行してください。購入をやり直す必要はありません。',
                'Your Plus purchase was confirmed, but we couldn\'t confirm your conversation allowance was updated. '
                    'Check your connection and retry. You don\'t need to buy again.',
              ),
              _NoticeTone.problem,
            );
    });
  }

  Future<void> _purchase(PlusPackage package) async {
    if (_busy || _PackageDisclosure.from(package) == null) return;
    setState(() {
      _busy = true;
      _busyPackageId = package.id;
      _notice = null;
    });

    PurchaseActionResult result;
    try {
      result = await widget.purchaseService.purchase(package);
    } catch (_) {
      result = const PurchaseActionResult(
        outcome: PurchaseActionOutcome.failed,
        plus: null,
        failureCode: 'ui_purchase_failed',
      );
    }
    if (!mounted) return;
    await _handleAction(result, restored: false);
  }

  Future<void> _restore() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _busyPackageId = null;
      _notice = null;
    });

    PurchaseActionResult result;
    try {
      result = await widget.purchaseService.restore();
    } catch (_) {
      result = const PurchaseActionResult(
        outcome: PurchaseActionOutcome.failed,
        plus: null,
        failureCode: 'ui_restore_failed',
      );
    }
    if (!mounted) return;
    await _handleAction(result, restored: true);
  }

  Future<void> _handleAction(
    PurchaseActionResult result, {
    required bool restored,
  }) async {
    switch (result.outcome) {
      case PurchaseActionOutcome.cancelled:
        setState(() {
          _busy = false;
          _busyPackageId = null;
          _notice = _Notice(
            l10n.t(
              '購入は完了していません。料金は発生していません。',
              'The purchase was not completed. You have not been charged.',
            ),
            _NoticeTone.information,
          );
        });
        return;
      case PurchaseActionOutcome.failed:
        setState(() {
          _busy = false;
          _busyPackageId = null;
          _notice = _Notice(
            restored
                ? l10n.t(
                    '購入情報を復元できませんでした。通信を確認して、もう一度お試しください。',
                    'Couldn\'t restore your purchase. Check your connection and try again.',
                  )
                : l10n.t(
                    '購入を完了できませんでした。ストアの状態を確認して、もう一度お試しください。',
                    'Couldn\'t complete the purchase. Check the store status and try again.',
                  ),
            _NoticeTone.problem,
          );
        });
        return;
      case PurchaseActionOutcome.disabled:
        setState(() {
          _busy = false;
          _busyPackageId = null;
          _overview = const PurchaseOverview.disabled();
          _notice = null;
        });
        return;
      case PurchaseActionOutcome.completed:
        break;
    }

    final plus = result.plus;
    if (plus == null) {
      setState(() {
        _busy = false;
        _busyPackageId = null;
        _notice = _Notice(
          l10n.t(
            'ストアの確認結果を受け取れませんでした。もう一度お試しください。',
            'Didn\'t get a response from the store. Please try again.',
          ),
          _NoticeTone.problem,
        );
      });
      return;
    }

    _replacePlus(plus);
    if (!plus.isActive) {
      setState(() {
        _busy = false;
        _busyPackageId = null;
        _notice = _Notice(
          restored
              ? l10n.t(
                  'このストアアカウントで、有効なPlusは見つかりませんでした。新しい購入は行っていません。',
                  'No active Plus was found for this store account. No new purchase was made.',
                )
              : l10n.t(
                  '購入情報を確認しましたが、Plusは有効になっていません。料金や契約の状態はストアで確認できます。',
                  'We checked your purchase, but Plus is not active. You can check charges and subscription status in the store.',
                ),
          _NoticeTone.information,
        );
      });
      return;
    }

    final synced = await _syncEntitlement();
    await _grantPlusPerks();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _busyPackageId = null;
      _syncPending = !synced;
      _notice = synced
          ? _Notice(
              restored
                  ? l10n.t(
                      'Plusを復元し、限定マスコットと会話枠への反映を確認しました。',
                      'Plus restored. Your exclusive mascot and conversation allowance are confirmed.',
                    )
                  : l10n.t(
                      'Plusが有効になり、限定マスコットを受け取りました。',
                      'Plus is active, and you got the exclusive mascot.',
                    ),
              _NoticeTone.confirmation,
            )
          : _Notice(
              l10n.t(
                '購入情報は確認できましたが、会話枠への反映を確認できませんでした。'
                    '通信を確認して再試行してください。購入をやり直す必要はありません。',
                'Your Plus purchase was confirmed, but we couldn\'t confirm your conversation allowance was updated. '
                    'Check your connection and retry. You don\'t need to buy again.',
              ),
              _NoticeTone.problem,
            );
    });
  }

  Future<bool> _syncEntitlement() async {
    final sync = widget.onEntitlementSync;
    if (sync == null) return true;
    try {
      return await sync();
    } catch (_) {
      return false;
    }
  }

  Future<void> _grantPlusPerks() async {
    final grant = widget.onPlusActivated;
    if (grant == null) return;
    try {
      await grant();
    } catch (_) {}
  }

  Future<void> _retrySync() async {
    if (_busy || !_syncPending) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    final synced = await _syncEntitlement();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _syncPending = !synced;
      _notice = synced
          ? _Notice(
              l10n.t(
                '会話枠への反映を確認しました。',
                'Your conversation allowance is confirmed.',
              ),
              _NoticeTone.confirmation,
            )
          : _Notice(
              l10n.t(
                '購入情報は確認できましたが、会話枠への反映を確認できませんでした。'
                    '通信を確認して再試行してください。購入をやり直す必要はありません。',
                'Your Plus purchase was confirmed, but we couldn\'t confirm your conversation allowance was updated. '
                    'Check your connection and retry. You don\'t need to buy again.',
              ),
              _NoticeTone.problem,
            );
    });
  }

  Future<void> _openExternal(Uri uri) async {
    if (_busy || _linkBusy) return;
    setState(() => _linkBusy = true);

    var opened = false;
    try {
      final open = widget.openExternalUri;
      opened = open != null
          ? await open(uri)
          : await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    setState(() {
      _linkBusy = false;
      if (!opened) {
        _notice = _Notice(
          l10n.t(
            'ページを開けませんでした。通信とブラウザの設定を確認して、もう一度お試しください。',
            'Couldn\'t open the page. Check your connection and browser settings, then try again.',
          ),
          _NoticeTone.problem,
        );
      }
    });
  }

  void _replacePlus(PlusAccess plus) {
    final previous = _overview;
    _overview = PurchaseOverview(
      availability: previous?.availability ?? PurchaseAvailability.ready,
      plus: plus,
      currentOffering: previous?.currentOffering,
      failureCode: previous?.failureCode,
    );
  }

  void _close() {
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.t('Plusを閉じる', 'Close Plus'),
          onPressed: _close,
          icon: const Icon(Icons.close),
        ),
        title: Text(l10n.t('デキすぎ君 Plus', 'Dekisugi-kun Plus')),
      ),
      body: SafeArea(
        top: false,
        child: ReadableWidth(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              StudioPageIntro(
                eyebrow: l10n.t('PLUS  ·  サポータープラン', 'PLUS  ·  Supporter plan'),
                title: l10n.t(
                  '次の復習を、\n家族で一緒に。',
                  'Make the next review\na family conversation.',
                ),
                body: l10n.t(
                  '復習する単元、保護者が聞く問い、共有レポートをひとつに。限定マスコットも使えます。',
                  'A next-review topic, questions to ask, and a shareable report. Plus an exclusive mascot.',
                ),
              ),
              const SizedBox(height: 22),
              const _PlanDifference(),
              const SizedBox(height: 14),
              const _AlwaysFree(),
              const SizedBox(height: 26),
              if (_loading)
                const _LoadingStore()
              else ...[
                _StoreContent(
                  overview: _overview!,
                  busy: _busy,
                  busyPackageId: _busyPackageId,
                  syncPending: _syncPending,
                  onPurchase: _purchase,
                  onRestore: _restore,
                  onReload: _load,
                  onRetrySync: _retrySync,
                  onClose: _close,
                ),
                if (_notice case final notice?) ...[
                  const SizedBox(height: 16),
                  _NoticePanel(notice: notice),
                ],
                const SizedBox(height: 24),
                _SubscriptionLinks(
                  busy: _busy || _linkBusy,
                  managementUri: _managementUri(_overview!.plus),
                  termsUri: _storeTermsUri(),
                  onOpen: _openExternal,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Uri _managementUri(PlusAccess access) {
    final revenueCat = _safeHttpsUri(access.managementUrl);
    if (revenueCat != null) return revenueCat;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => Uri.parse(
        'https://apps.apple.com/account/subscriptions',
      ),
      _ => Uri.parse('https://play.google.com/store/account/subscriptions'),
    };
  }

  Uri _storeTermsUri() => switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.macOS => Uri.parse(
      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
    ),
    _ => Uri.parse('https://play.google.com/about/play-terms/'),
  };

  static Uri? _safeHttpsUri(String? value) {
    final uri = Uri.tryParse(value?.trim() ?? '');
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    return uri;
  }
}

class _PlanDifference extends StatelessWidget {
  const _PlanDifference();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    return Semantics(
      container: true,
      label: l10n.t(
        '教材・ミッション・理解確認は無料。Plusは保護者向け復習プランと共有レポート、限定マスコットです。',
        'Lessons, missions and understanding checks are free. Plus adds a family review plan, a shareable report and an exclusive mascot.',
      ),
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: c.heroSurface,
            borderRadius: BorderRadius.circular(AppRadius.stage),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PlanLine(
                label: l10n.t('無料', 'Free'),
                value: l10n.t(
                  '教材とミッションは全部無料',
                  'All lessons and missions are free',
                ),
                detail: l10n.t(
                  '教え返し・自分の記録・理解確認も無料です',
                  'Teaching, your own record and understanding checks stay free',
                ),
                foreground: c.onHeroSurface,
                muted: c.heroMuted,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(color: c.heroMuted.withValues(alpha: 0.35)),
              ),
              _PlanLine(
                label: 'Plus',
                value: l10n.t(
                  '保護者向け復習プラン・共有レポート',
                  'Family review plan and shareable report',
                ),
                detail: l10n.t(
                  '次に確かめる概念、保護者が聞ける問い、新しい場面での確認を、端末内の観察記録からまとめます。コピーして共有できます。オーロラマントも使えます。',
                  'Turn local observation records into a next topic, a question a parent can ask, and a check in a new situation. Copy the plan to share it. Includes the Aurora Cape mascot.',
                ),
                foreground: c.onHeroSurface,
                muted: c.heroMuted,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.t(
                  'AI会話は全プランで休止中です。Plusの購入で学習効果を保証するものではありません。',
                  'AI conversations are paused on all plans. Buying Plus does not guarantee better learning.',
                ),
                style: t.textTheme.bodySmall?.copyWith(color: c.heroMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanLine extends StatelessWidget {
  const _PlanLine({
    required this.label,
    required this.value,
    required this.detail,
    required this.foreground,
    required this.muted,
  });

  final String label;
  final String value;
  final String detail;
  final Color foreground;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: t.textTheme.labelMedium
              ?.copyWith(color: muted)
              .jaWeight(FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: t.textTheme.titleLarge
              ?.copyWith(color: foreground)
              .jaWeight(FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(detail, style: t.textTheme.bodySmall?.copyWith(color: muted)),
      ],
    );
  }
}

class _AlwaysFree extends StatelessWidget {
  const _AlwaysFree();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.coolSurface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_open_outlined, color: c.onCoolSurface),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.t(
                    '学ぶための土台は、課金で閉じません',
                    'The basics of learning are never behind a paywall',
                  ),
                  style: t.textTheme.titleSmall
                      ?.copyWith(color: c.onCoolSurface)
                      .jaWeight(FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t(
              '本人のノート、文字入力、アクセシビリティ機能、REPAIRは無料のままです。'
                  '理解確認も無料です。Plusは保護者向けの復習整理と共有、限定マスコットのプランです。',
              'Your notes, text input, accessibility features, and REPAIR stay free. '
                  'Understanding checks also stay free. Plus adds family review planning, sharing, and an exclusive mascot.',
            ),
            style: t.textTheme.bodySmall?.copyWith(color: c.onCoolSurface),
          ),
        ],
      ),
    );
  }
}

class _LoadingStore extends StatelessWidget {
  const _LoadingStore();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: l10n.t('ストアのプランを読み込んでいます', 'Loading store plans'),
      child: const ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _StoreContent extends StatelessWidget {
  const _StoreContent({
    required this.overview,
    required this.busy,
    required this.busyPackageId,
    required this.syncPending,
    required this.onPurchase,
    required this.onRestore,
    required this.onReload,
    required this.onRetrySync,
    required this.onClose,
  });

  final PurchaseOverview overview;
  final bool busy;
  final String? busyPackageId;
  final bool syncPending;
  final ValueChanged<PlusPackage> onPurchase;
  final VoidCallback onRestore;
  final VoidCallback onReload;
  final VoidCallback onRetrySync;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    if (syncPending) {
      return _SyncRetry(busy: busy, onRetry: onRetrySync, onClose: onClose);
    }
    if (overview.plus.isActive) {
      return _ActivePlus(
        access: overview.plus,
        busy: busy,
        onRestore: onRestore,
        onClose: onClose,
      );
    }
    return switch (overview.availability) {
      PurchaseAvailability.disabled => _DisabledPlus(onClose: onClose),
      PurchaseAvailability.unavailable => _UnavailableStore(
        busy: busy,
        onReload: onReload,
        onRestore: onRestore,
      ),
      PurchaseAvailability.ready => _AvailablePackages(
        offering: overview.currentOffering,
        busy: busy,
        busyPackageId: busyPackageId,
        onPurchase: onPurchase,
        onRestore: onRestore,
        onReload: onReload,
      ),
    };
  }
}

class _AvailablePackages extends StatelessWidget {
  const _AvailablePackages({
    required this.offering,
    required this.busy,
    required this.busyPackageId,
    required this.onPurchase,
    required this.onRestore,
    required this.onReload,
  });

  final PlusOffering? offering;
  final bool busy;
  final String? busyPackageId;
  final ValueChanged<PlusPackage> onPurchase;
  final VoidCallback onRestore;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final packages = offering?.packages ?? const <PlusPackage>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (packages.isEmpty) ...[
          _StoreExplanation(
            icon: Icons.receipt_long_outlined,
            title: l10n.t('現在選べるプランがありません', 'No plans are available right now'),
            body: l10n.t(
              'ストアから価格と期間を確認できないため、推測した料金は表示しません。',
              'We couldn\'t get the price and period from the store, so we won\'t show a guessed price.',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: busy ? null : onReload,
            child: Text(l10n.t('プランをもう一度確認', 'Check plans again')),
          ),
        ] else ...[
          StudioSectionHeader(
            title: l10n.t('ストアのプラン', 'Store plans'),
            description: l10n.t(
              '料金・請求期間・更新条件は、いまストアから届いた内容です。',
              'Price, billing period, and renewal terms are exactly what the store just sent.',
            ),
            leading: Icon(Icons.storefront_outlined),
          ),
          const SizedBox(height: 12),
          for (final package in packages) ...[
            _PackagePanel(
              package: package,
              busy: busy,
              isCurrentAction: busyPackageId == package.id,
              onPurchase: () => onPurchase(package),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            l10n.t(
              'Plusに申し込まなくても無料機能は使えます。請求と解約は端末のストアで管理され、'
                  '購入前にストアの確認画面でも最終条件を確認できます。',
              'Free features work without Plus. Billing and cancellation are managed in your device\'s store, '
                  'and you can review the final terms on the store\'s confirmation screen before buying.',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 10),
        TextButton(
          onPressed: busy ? null : onRestore,
          child: Text(l10n.t('以前の購入を復元', 'Restore previous purchase')),
        ),
      ],
    );
  }
}

class _PackagePanel extends StatelessWidget {
  const _PackagePanel({
    required this.package,
    required this.busy,
    required this.isCurrentAction,
    required this.onPurchase,
  });

  final PlusPackage package;
  final bool busy;
  final bool isCurrentAction;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final title = package.title.trim().isEmpty ? 'Plus' : package.title.trim();
    final description = package.description.trim();
    final disclosure = _PackageDisclosure.from(package);
    final price = package.price.trim();
    final canPurchase = disclosure != null;
    final buttonLabel = canPurchase
        ? l10n.t('$priceで申し込む', 'Subscribe for $price')
        : l10n.t('このプランは購入できません', 'This plan can\'t be purchased');

    return Container(
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
            title,
            style: t.textTheme.titleMedium?.jaWeight(FontWeight.w700),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: t.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            disclosure?.priceAndPeriod ??
                (price.isEmpty
                    ? l10n.t(
                        '価格をストアから取得できませんでした',
                        'Couldn\'t get the price from the store',
                      )
                    : price),
            style: t.textTheme.titleLarge?.jaWeight(FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            disclosure?.renewalTerms ?? _unavailableTerms(package),
            style: t.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            enabled: !busy && canPurchase,
            label: disclosure == null
                ? l10n.t('$title、$buttonLabel', '$title, $buttonLabel')
                : l10n.t(
                    '$title、${disclosure.semanticTerms}、$buttonLabel',
                    '$title, ${disclosure.semanticTerms}, $buttonLabel',
                  ),
            child: ExcludeSemantics(
              child: FilledButton(
                onPressed: busy || !canPurchase ? null : onPurchase,
                child: Text(
                  isCurrentAction
                      ? l10n.t('ストアに確認しています…', 'Checking with the store…')
                      : buttonLabel,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _unavailableTerms(PlusPackage package) {
    if (package.hasIntroductoryOffer) {
      return l10n.t(
        '無料体験または割引後の請求条件を正確に表示できないため、この画面では購入を止めています。',
        'Purchases are paused here because we can\'t accurately show billing after the free trial or discount.',
      );
    }
    if (package.hasInstallments) {
      return l10n.t(
        '分割回数と総支払条件を正確に表示できないため、この画面では購入を止めています。',
        'Purchases are paused here because we can\'t accurately show the installments and total cost.',
      );
    }
    if (package.price.trim().isEmpty) {
      return l10n.t(
        'ストアから実際の価格を確認できないため、この画面では購入を止めています。',
        'Purchases are paused here because we can\'t confirm the actual price from the store.',
      );
    }
    return l10n.t(
      'ストアから請求期間と更新条件を確認できないため、この画面では購入を止めています。',
      'Purchases are paused here because we can\'t confirm the billing period and renewal terms from the store.',
    );
  }
}

class _PackageDisclosure {
  const _PackageDisclosure({
    required this.priceAndPeriod,
    required this.renewalTerms,
    required this.semanticTerms,
  });

  final String priceAndPeriod;
  final String renewalTerms;
  final String semanticTerms;

  static _PackageDisclosure? from(PlusPackage package) {
    final price = package.price.trim();
    if (price.isEmpty ||
        package.hasIntroductoryOffer ||
        package.hasInstallments) {
      return null;
    }

    switch (package.billingModel) {
      case PlusBillingModel.autoRenewingSubscription:
        final period = _localizedPeriod(package.subscriptionPeriod);
        if (period == null) return null;
        return _PackageDisclosure(
          priceAndPeriod: '$price / $period',
          renewalTerms: l10n.t(
            '解約するまで、$periodごとに$priceで自動更新されます。'
                '更新日の確認と解約は端末のストアで行えます。',
            'Renews automatically at $price every $period until you cancel. '
                'Check renewal dates and cancel in your device\'s store.',
          ),
          semanticTerms: l10n.t(
            '$price、$periodごとの自動更新',
            '$price, renews every $period',
          ),
        );
      case PlusBillingModel.prepaidSubscription:
        final period = _localizedPeriod(package.subscriptionPeriod);
        if (period == null) return null;
        return _PackageDisclosure(
          priceAndPeriod: '$price / $period',
          renewalTerms: l10n.t(
            '$period分の前払いです。期間終了時に自動更新されません。',
            'Prepaid for $period. Does not renew automatically when it ends.',
          ),
          semanticTerms: l10n.t(
            '$price、$period分の前払い、自動更新なし',
            '$price, prepaid for $period, no auto-renewal',
          ),
        );
      case PlusBillingModel.oneTimePurchase:
        return _PackageDisclosure(
          priceAndPeriod: l10n.t('$price（1回限り）', '$price (one-time)'),
          renewalTerms: l10n.t(
            '1回限りの支払いです。自動更新されません。',
            'One-time payment. Does not renew automatically.',
          ),
          semanticTerms: l10n.t(
            '$price、1回限りの支払い、自動更新なし',
            '$price, one-time payment, no auto-renewal',
          ),
        );
      case PlusBillingModel.unsupported:
        return null;
    }
  }

  static String? _localizedPeriod(String? value) {
    final match = RegExp(
      r'^P([1-9][0-9]*)([DWMY])$',
    ).firstMatch(value?.trim().toUpperCase() ?? '');
    if (match == null) return null;
    final count = int.tryParse(match.group(1)!);
    if (count == null) return null;
    return switch (match.group(2)) {
      'D' => l10n.t('$count日', '$count ${count == 1 ? 'day' : 'days'}'),
      'W' => l10n.t('$count週間', '$count ${count == 1 ? 'week' : 'weeks'}'),
      'M' => l10n.t('$countか月', '$count ${count == 1 ? 'month' : 'months'}'),
      'Y' => l10n.t('$count年', '$count ${count == 1 ? 'year' : 'years'}'),
      _ => null,
    };
  }
}

class _ActivePlus extends StatelessWidget {
  const _ActivePlus({
    required this.access,
    required this.busy,
    required this.onRestore,
    required this.onClose,
  });

  final PlusAccess access;
  final bool busy;
  final VoidCallback onRestore;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: c.coolSurface,
              borderRadius: BorderRadius.circular(AppRadius.stage),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_outline, color: c.onCoolSurface),
                const SizedBox(height: 10),
                Text(
                  l10n.t('Plusは有効です', 'Plus is active'),
                  style: t.textTheme.titleLarge
                      ?.copyWith(color: c.onCoolSurface)
                      .jaWeight(FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.t(
                    'AIとの会話回数に上限はありません。1回はおよそ10分です。',
                    'No limit on AI conversations. Each lasts about 10 minutes.',
                  ),
                  style: t.textTheme.bodyMedium?.copyWith(
                    color: c.onCoolSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  access.isTrial
                      ? l10n.t(
                          'ストアでは無料体験として確認されています。更新条件は「購読を管理・解約」で確認できます。',
                          'The store shows this as a free trial. See renewal terms under "Manage or cancel subscription."',
                        )
                      : access.willRenew
                      ? l10n.t(
                          'ストアでは自動更新中です。更新日と料金は「購読を管理・解約」で確認できます。',
                          'Auto-renewal is on in the store. See the renewal date and price under "Manage or cancel subscription."',
                        )
                      : access.expiresAt != null
                      ? l10n.t(
                          '自動更新は停止されています。表示された利用期限まではPlusを使えます。',
                          'Auto-renewal is off. You can use Plus until the end date shown.',
                        )
                      : l10n.t(
                          '自動更新は設定されていません。契約状態は「購読を管理・解約」で確認できます。',
                          'Auto-renewal is not set. See your subscription status under "Manage or cancel subscription."',
                        ),
                  style: t.textTheme.bodySmall?.copyWith(
                    color: c.onCoolSurface,
                  ),
                ),
                if (access.expiresAt case final expires?) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.t(
                      'ストアで確認した利用期限: ${_date(expires.toLocal())}',
                      'Active until (per the store): ${_date(expires.toLocal())}',
                    ),
                    style: t.textTheme.bodySmall?.copyWith(
                      color: c.onCoolSurface,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: busy ? null : onClose,
            child: Text(l10n.t('閉じる', 'Close')),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: busy ? null : onRestore,
            child: Text(
              busy
                  ? l10n.t('購入情報を確認しています…', 'Checking your purchase…')
                  : l10n.t('購入情報をもう一度確認', 'Check purchase again'),
            ),
          ),
        ],
      ),
    );
  }

  static String _date(DateTime value) => l10n.t(
    '${value.year}年${value.month}月${value.day}日',
    '${value.year}/${value.month}/${value.day}',
  );
}

class _SyncRetry extends StatelessWidget {
  const _SyncRetry({
    required this.busy,
    required this.onRetry,
    required this.onClose,
  });

  final bool busy;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: busy ? null : onRetry,
          child: Text(
            busy
                ? l10n.t('会話枠を確認しています…', 'Checking conversation allowance…')
                : l10n.t(
                    '会話枠への反映を再試行',
                    'Retry updating conversation allowance',
                  ),
          ),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: busy ? null : onClose,
          child: Text(l10n.t('閉じる', 'Close')),
        ),
      ],
    );
  }
}

class _DisabledPlus extends StatelessWidget {
  const _DisabledPlus({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StoreExplanation(
          icon: Icons.info_outline,
          title: l10n.t(
            'このアプリではPlusを購入できません',
            'Plus can\'t be purchased in this app',
          ),
          body: l10n.t(
            'このビルドではストア購入が設定されていません。教材とミッションは無料でそのまま使えます。',
            'Store purchases aren\'t set up in this build. Lessons and missions are still free to use.',
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(onPressed: onClose, child: Text(l10n.t('閉じる', 'Close'))),
      ],
    );
  }
}

class _UnavailableStore extends StatelessWidget {
  const _UnavailableStore({
    required this.busy,
    required this.onReload,
    required this.onRestore,
  });

  final bool busy;
  final VoidCallback onReload;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StoreExplanation(
          icon: Icons.cloud_off_outlined,
          title: l10n.t('ストアの情報を確認できません', 'Can\'t check store information'),
          body: l10n.t(
            '料金を推測せず、確認できるまで購入操作を止めています。無料の機能は引き続き使えます。',
            'We won\'t guess prices, so purchases are paused until we can confirm. Free features still work.',
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: busy ? null : onReload,
          child: Text(l10n.t('ストアへ再接続', 'Reconnect to store')),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: busy ? null : onRestore,
          child: Text(l10n.t('以前の購入を復元', 'Restore previous purchase')),
        ),
      ],
    );
  }
}

class _StoreExplanation extends StatelessWidget {
  const _StoreExplanation({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = context.appColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.coolSurface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: c.onCoolSurface),
          const SizedBox(height: 8),
          Text(
            title,
            style: t.textTheme.titleMedium
                ?.copyWith(color: c.onCoolSurface)
                .jaWeight(FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: t.textTheme.bodySmall?.copyWith(color: c.onCoolSurface),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionLinks extends StatelessWidget {
  const _SubscriptionLinks({
    required this.busy,
    required this.managementUri,
    required this.termsUri,
    required this.onOpen,
  });

  static final Uri _privacyUri = Uri.parse(
    'https://rika-chousa.vercel.app/privacy.html',
  );

  final bool busy;
  final Uri managementUri;
  final Uri termsUri;
  final ValueChanged<Uri> onOpen;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(color: scheme.outlineVariant),
          const SizedBox(height: 10),
          Text(
            l10n.t('購読の確認・解約', 'Check or cancel subscription'),
            style: t.textTheme.titleSmall?.jaWeight(FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.t(
              '更新日、自動更新、解約の状態は、購入に使ったストアのアカウントで管理できます。',
              'Manage renewal dates, auto-renewal, and cancellation in the store account you used to buy.',
            ),
            style: t.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          _ExternalLinkButton(
            label: l10n.t(
              'ストアで購読を管理・解約',
              'Manage or cancel subscription in store',
            ),
            icon: Icons.open_in_new,
            busy: busy,
            filled: true,
            onPressed: () => onOpen(managementUri),
          ),
          const SizedBox(height: 6),
          _ExternalLinkButton(
            label: l10n.t('ストア利用規約', 'Store terms of use'),
            icon: Icons.description_outlined,
            busy: busy,
            onPressed: () => onOpen(termsUri),
          ),
          const SizedBox(height: 2),
          _ExternalLinkButton(
            label: l10n.t('プライバシーポリシー', 'Privacy policy'),
            icon: Icons.privacy_tip_outlined,
            busy: busy,
            onPressed: () => onOpen(_privacyUri),
          ),
        ],
      ),
    );
  }
}

class _ExternalLinkButton extends StatelessWidget {
  const _ExternalLinkButton({
    required this.label,
    required this.icon,
    required this.busy,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final bool busy;
  final VoidCallback onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final child = Icon(icon, size: 20);
    return Semantics(
      link: true,
      enabled: !busy,
      label: l10n.t('$label、外部ページを開く', '$label, opens external page'),
      child: ExcludeSemantics(
        child: filled
            ? OutlinedButton.icon(
                onPressed: busy ? null : onPressed,
                icon: child,
                label: Text(label, textAlign: TextAlign.center),
              )
            : TextButton.icon(
                onPressed: busy ? null : onPressed,
                icon: child,
                label: Text(label, textAlign: TextAlign.center),
              ),
      ),
    );
  }
}

enum _NoticeTone { information, problem, confirmation }

class _Notice {
  const _Notice(this.text, this.tone);

  final String text;
  final _NoticeTone tone;
}

class _NoticePanel extends StatelessWidget {
  const _NoticePanel({required this.notice});

  final _Notice notice;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final c = context.appColors;
    final (background, foreground, icon) = switch (notice.tone) {
      _NoticeTone.information => (
        c.coolSurface,
        c.onCoolSurface,
        Icons.info_outline,
      ),
      _NoticeTone.problem => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.sync_problem_outlined,
      ),
      _NoticeTone.confirmation => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        Icons.check_circle_outline,
      ),
    };

    return Semantics(
      container: true,
      liveRegion: true,
      label: notice.text,
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: foreground),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  notice.text,
                  style: t.textTheme.bodySmall?.copyWith(color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
