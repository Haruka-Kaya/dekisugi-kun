import '../config/app_language.dart' as localize;
import 'package:flutter/services.dart';

import '../config/app_language.dart';
import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../models/lan_social.dart';
import '../services/lan_social_client.dart';
import '../services/session_store.dart';
import '../ui/_material.dart';
import '../widgets/participant_qr_code.dart';
import 'qr_scan_screen.dart';

typedef LanSocialClientFactory =
    LanSocialClient Function(LanSocialEndpoint endpoint);

/// 同じWi-Fi上の実在参加者とつながる入口。
///
/// 参加前の明示同意、roomごとの不透明資格情報、5人未満の順位秘匿をUIでも
/// 崩さない。学校と成人local-onlyは入口・client構成の両方をfail-closedにする。
class LanSocialScreen extends StatefulWidget {
  const LanSocialScreen({
    super.key,
    required this.store,
    required this.schoolMode,
    this.lanSocialAllowed = false,
    this.clientFactory,
    this.scanConnectionCode,
  });

  final SessionStore store;
  final bool schoolMode;

  /// 成人online同意ツリーからだけtrueを渡す。local-only personal/schoolはfalse。
  final bool lanSocialAllowed;
  final LanSocialClientFactory? clientFactory;

  /// QRのカメラ実装を差し替えるテスト用の入口。読み取り後も参加は行わない。
  final Future<String?> Function(BuildContext context)? scanConnectionCode;

  @override
  State<LanSocialScreen> createState() => _LanSocialScreenState();
}

class _LanSocialScreenState extends State<LanSocialScreen> {
  final _connectionCode = TextEditingController();
  final _clients = <LanSocialRoomKind, LanSocialClient>{};
  final _snapshots = <LanSocialRoomKind, LanSocialSnapshot>{};
  final _pendingLeaves = <LanSocialRoomKind>{};

  LanSocialRoomKind _selected = LanSocialRoomKind.friends;
  LanSocialLeagueProfile _leagueProfile =
      const LanSocialLeagueProfile.initial();
  bool _restoring = true;
  bool _busy = false;
  bool _explicitOptIn = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _connectionCode.dispose();
    super.dispose();
  }

  LanSocialClient _clientFor(LanSocialEndpoint endpoint) =>
      widget.clientFactory?.call(endpoint) ??
      LanSocialClient(endpoint: endpoint, store: widget.store);

  Future<void> _restore() async {
    if (!widget.lanSocialAllowed || widget.schoolMode) {
      if (mounted) setState(() => _restoring = false);
      return;
    }
    final restored = await LanSocialClient.savedMemberships(widget.store);
    if (!mounted) return;
    for (final membership in restored) {
      if (widget.schoolMode && membership.kind == LanSocialRoomKind.league) {
        continue;
      }
      try {
        final client = _clientFor(
          LanSocialEndpoint(
            baseUrl: membership.baseUrl,
            certificateSha256: membership.certificateSha256,
          ),
        );
        _clients[membership.kind] = client;
        try {
          if (await client.leavePending(membership.kind)) {
            _pendingLeaves.add(membership.kind);
          }
        } on Object {
          // pending印を読めない場合も新しい寄与を許さず、退出再試行へ倒す。
          _pendingLeaves.add(membership.kind);
        }
      } on ArgumentError {
        // 壊れた/public endpointへフォールバック接続しない。
      }
    }
    if (!widget.schoolMode &&
        !_clients.containsKey(LanSocialRoomKind.friends) &&
        _clients.containsKey(LanSocialRoomKind.league)) {
      _selected = LanSocialRoomKind.league;
    }
    setState(() => _restoring = false);
    for (final kind in _clients.keys.toList(growable: false)) {
      if (!_pendingLeaves.contains(kind)) {
        await _refresh(kind, announceFailure: false);
      }
    }
  }

  Future<void> _join() async {
    if (_busy ||
        !_explicitOptIn ||
        !widget.lanSocialAllowed ||
        widget.schoolMode) {
      return;
    }
    LanSocialConnectionCode code;
    try {
      code = LanSocialConnectionCode.parse(_connectionCode.text);
    } on FormatException {
      _setMessage(
        t('参加コードを確認してください。', 'Please check the join code.'),
        isError: true,
      );
      return;
    }
    if (widget.schoolMode && code.kind == LanSocialRoomKind.league) {
      _setMessage(
        t(
          '学校モードでは個人順位の共同観測に参加できません。',
          'In school mode, you can\'t join the weekly league with individual rankings.',
        ),
        isError: true,
      );
      return;
    }
    if (code.kind != _selected) {
      _setMessage(
        t(
          '選んだ遊びと参加コードの種類が一致しません。',
          'The join code doesn\'t match the activity you chose.',
        ),
        isError: true,
      );
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });
    LanSocialClient client;
    try {
      client = _clientFor(code.endpoint);
    } on ArgumentError {
      setState(() => _busy = false);
      _setMessage(
        t(
          'private HTTPS接続先として確認できない参加コードです。',
          'This join code can\'t be verified as a private HTTPS address.',
        ),
        isError: true,
      );
      return;
    }
    LanSocialJoinResult result;
    try {
      result = await client.join(code, explicitOptIn: true);
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      _setMessage(
        t(
          '安全に参加状態を保存できなかったため、参加しませんでした。',
          'Couldn\'t safely save your join status, so you were not joined.',
        ),
        isError: true,
      );
      return;
    }
    if (!mounted) return;
    if (!result.joined) {
      setState(() => _busy = false);
      _setMessage(_joinErrorLabel(result.error), isError: true);
      return;
    }
    _clients[code.kind] = client;
    _pendingLeaves.remove(code.kind);
    _connectionCode.clear();
    setState(() {
      _busy = false;
      _explicitOptIn = false;
      _message = t(
        '参加しました。学習成果が記録されると自動で共同進捗へ反映されます。',
        'Joined. Your learning results will count toward shared progress automatically.',
      );
      _messageIsError = false;
    });
    await _refresh(code.kind, announceFailure: false);
  }

  Future<void> _scanConnectionCode() async {
    if (_busy) return;
    final raw =
        await (widget.scanConnectionCode?.call(context) ??
            Navigator.of(context).push<String>(
              MaterialPageRoute<String>(builder: (_) => const QrScanScreen()),
            ));
    if (!mounted || raw == null) return;
    try {
      final code = LanSocialConnectionCode.parse(raw);
      setState(() {
        _connectionCode.text = code.encode();
        _selected = code.kind;
        _explicitOptIn = false;
        _message = t(
          '参加コードを読み取りました。送信範囲を確認してから参加に同意してください。',
          'Join code scanned. Check what will be sent, then agree to join.',
        );
        _messageIsError = false;
      });
    } on FormatException {
      _setMessage(
        t(
          'これはLAN参加コードのQRではありません。DKS1.から始まるコードを読み取ってください。',
          'This isn\'t a LAN join code QR. Scan a code that starts with DKS1.',
        ),
        isError: true,
      );
    }
  }

  Future<void> _refresh(
    LanSocialRoomKind kind, {
    bool announceFailure = true,
  }) async {
    final client = _clients[kind];
    if (client == null) return;
    if (announceFailure && mounted) setState(() => _busy = true);
    LanSocialRefreshResult? refreshed;
    try {
      refreshed = await client.refresh(kind);
    } on Object {
      refreshed = null;
    }
    if (!mounted) return;
    if (refreshed == null) {
      LanSocialMembership? membership;
      var membershipRead = false;
      try {
        membership = await client.saved(kind);
        membershipRead = true;
      } on Object {
        // 保存状態を確認できないときは、所属を推測で消さない。
      }
      if (!mounted) return;
      if (membershipRead && membership == null) {
        _clients.remove(kind);
        _snapshots.remove(kind);
      }
      setState(() {
        _busy = false;
        if (announceFailure) {
          _message = t(
            'コーディネーターに接続できませんでした。証明書や同じWi-Fiへの接続を確認してください。',
            'Couldn\'t connect to the coordinator. Check the certificate and that you\'re on the same Wi-Fi.',
          );
          _messageIsError = true;
        }
      });
      return;
    }
    final current = refreshed;
    if (current.terminalReceipt case final LanSocialTerminalReceipt receipt) {
      _clients.remove(kind);
      _snapshots.remove(kind);
      _pendingLeaves.remove(kind);
      setState(() {
        _busy = false;
        _leagueProfile = current.leagueProfile;
        _message = _terminalSettlementMessage(receipt);
        _messageIsError = false;
      });
      return;
    }
    final snapshot = current.snapshot;
    if (snapshot == null) return;
    setState(() {
      _busy = false;
      _snapshots[kind] = snapshot;
      _leagueProfile = current.leagueProfile;
      if (announceFailure) {
        _message = t('最新の状態に更新しました。', 'Updated to the latest status.');
        _messageIsError = false;
      }
    });
  }

  String _terminalSettlementMessage(LanSocialTerminalReceipt receipt) {
    return switch (receipt) {
      LanSocialFriendsTerminalReceipt(:final completed) =>
        completed
            ? t(
                '共同観察の達成を端末に確定しました。結晶はこの部屋につき1個です。',
                'Friends quest completion saved on this device. You get one crystal per room.',
              )
            : t(
                '共同観察は未達成で終了しました。',
                'The friends quest ended without being completed.',
              ),
      LanSocialLeagueTerminalReceipt(
        :final privacyThresholdReached,
        :final rank,
      ) =>
        !privacyThresholdReached
            ? t(
                '参加者が5人未満だったため、順位を保存せず共同観測を終了しました。',
                'Fewer than 5 people joined, so the league ended without saving rankings.',
              )
            : rank == null
            ? t(
                '共同観測の結果を「順位なし」として端末に保存しました。',
                'Saved this week\'s league result as "no rank" on this device.',
              )
            : t(
                '共同観測の$rank位を端末に保存しました。',
                'Saved this week\'s league rank #$rank on this device.',
              ),
    };
  }

  Future<void> _leave(LanSocialRoomKind kind) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('参加をやめますか？', 'Leave this room?')),
        content: Text(
          t(
            'この端末の参加資格を消し、コーディネーターにも退出を伝えます。これまでの週ごとの観測級履歴は端末内に残ります。',
            'This deletes this device\'s membership and tells the coordinator you left. Your weekly tier history stays on this device.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t('続ける', 'Stay')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(t('参加をやめる', 'Leave')),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    final client = _clients[kind];
    if (client == null) return;
    setState(() => _busy = true);
    bool removed;
    try {
      removed = await client.leave(kind);
    } on Object {
      // coordinatorで退出済みでも端末保存に失敗した可能性がある。資格情報を
      // 推測で捨てず、次の401/204までjoined表示と再試行導線を維持する。
      if (!mounted) return;
      setState(() {
        _busy = false;
        _pendingLeaves.add(kind);
      });
      _setMessage(
        t(
          '参加解除を安全に保存できませんでした。もう一度試してください。',
          'Couldn\'t safely save that you left. Please try again.',
        ),
        isError: true,
      );
      return;
    }
    if (!mounted) return;
    if (!removed) {
      setState(() {
        _busy = false;
        _pendingLeaves.add(kind);
        _message = null;
      });
      return;
    }
    setState(() {
      _busy = false;
      _clients.remove(kind);
      _snapshots.remove(kind);
      _pendingLeaves.remove(kind);
      _message = t('この端末の参加を解除しました。', 'This device has left the room.');
      _messageIsError = false;
    });
  }

  void _setMessage(String value, {required bool isError}) {
    if (!mounted) return;
    setState(() {
      _message = value;
      _messageIsError = isError;
    });
  }

  Future<void> _openCoordinatorSettings() async {
    if (!widget.lanSocialAllowed || widget.schoolMode) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => LanSocialRoomCreateScreen(
          store: widget.store,
          schoolMode: widget.schoolMode,
          lanSocialAllowed: widget.lanSocialAllowed,
          clientFactory: widget.clientFactory,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.lanSocialAllowed || widget.schoolMode) {
      return _LanSocialUnavailableScreen(schoolMode: widget.schoolMode);
    }
    final colors = context.gamePalette;
    final theme = Theme.of(context);
    final joined = _clients.containsKey(_selected);
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        title: Text(
          t('いっしょに学ぶ', 'Learn together'),
          style: theme.textTheme.titleLarge
              ?.copyWith(color: colors.ink)
              .jaWeight(FontWeight.w900),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          key: const ValueKey('lan-social-screen'),
          padding: const EdgeInsets.fromLTRB(
            GameTokens.spaceLg,
            GameTokens.spaceMd,
            GameTokens.spaceLg,
            48,
          ),
          children: [
            Semantics(
              header: true,
              child: Text(
                t('本当に参加した人と進める', 'Play only with real people who joined'),
                style: theme.textTheme.headlineSmall
                    ?.copyWith(color: colors.ink)
                    .jaWeight(FontWeight.w900),
              ),
            ),
            const SizedBox(height: GameTokens.spaceSm),
            Text(
              t(
                '架空の相手は出しません。同じWi-Fi上のコーディネーターに接続し、実在する参加者だけで遊びます。',
                'No fake opponents. Connect to a coordinator on the same Wi-Fi and play only with real participants.',
              ),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.inkMuted,
              ),
            ),
            const SizedBox(height: GameTokens.spaceXl),
            const _PrivacyDisclosure(),
            const SizedBox(height: GameTokens.spaceXl),
            if (!widget.schoolMode) ...[
              _KindButton(
                kind: LanSocialRoomKind.friends,
                selected: _selected == LanSocialRoomKind.friends,
                joined: _clients.containsKey(LanSocialRoomKind.friends),
                onPressed: _busy
                    ? null
                    : () =>
                          setState(() => _selected = LanSocialRoomKind.friends),
              ),
              const SizedBox(height: GameTokens.spaceSm),
              _KindButton(
                kind: LanSocialRoomKind.league,
                selected: _selected == LanSocialRoomKind.league,
                joined: _clients.containsKey(LanSocialRoomKind.league),
                onPressed: _busy
                    ? null
                    : () =>
                          setState(() => _selected = LanSocialRoomKind.league),
              ),
              const SizedBox(height: GameTokens.spaceXl),
            ],
            if (_message != null) ...[
              _LiveMessage(value: _message!, isError: _messageIsError),
              const SizedBox(height: GameTokens.spaceLg),
            ],
            if (_restoring)
              _LoadingState(label: t('参加状態を確認しています', 'Checking join status'))
            else if (joined)
              _JoinedRoom(
                kind: _selected,
                snapshot: _snapshots[_selected],
                leagueProfile: _leagueProfile,
                leavePending: _pendingLeaves.contains(_selected),
                busy: _busy,
                onRefresh: () => _refresh(_selected),
                onLeave: () => _leave(_selected),
              )
            else
              _JoinRoom(
                kind: _selected,
                controller: _connectionCode,
                explicitOptIn: _explicitOptIn,
                busy: _busy,
                onOptInChanged: (value) =>
                    setState(() => _explicitOptIn = value),
                onJoin: _join,
                onScan: _scanConnectionCode,
              ),
            const SizedBox(height: GameTokens.spaceXl),
            _Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('コーディネーターを用意する人へ', 'For whoever sets up the coordinator'),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: colors.ink)
                        .jaWeight(FontWeight.w800),
                  ),
                  const SizedBox(height: GameTokens.spaceSm),
                  Text(
                    t(
                      '学校・家庭の管理PCでLAN coordinatorを起動したあと、HTTPS接続先、証明書fingerprint、管理キーを設定します。',
                      'After starting the LAN coordinator on a school or home admin PC, set the HTTPS address, certificate fingerprint, and admin key.',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.inkMuted,
                    ),
                  ),
                  const SizedBox(height: GameTokens.spaceMd),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const ValueKey('open-lan-social-coordinator'),
                      onPressed: _busy ? null : _openCoordinatorSettings,
                      icon: const Icon(Icons.settings_ethernet_outlined),
                      label: Text(t('部屋を作る設定', 'Room setup')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyDisclosure extends StatelessWidget {
  const _PrivacyDisclosure();

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final theme = Theme.of(context);
    return _Surface(
      semanticLabel: t(
        '送るものは明示同意、不透明な参加資格、学習日、学習成果の一方向ハッシュ。送らないものは氏名、回答、選択肢、音声、端末ID。',
        'Sent: your explicit consent, an opaque membership token, the study date, and a one-way hash of your learning results. Not sent: your name, answers, choices, voice, or device ID.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_outlined, color: colors.pathComplete),
              const SizedBox(width: GameTokens.spaceSm),
              Expanded(
                child: Text(
                  t('送る情報を最小にします', 'We send as little as possible'),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: colors.ink)
                      .jaWeight(FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: GameTokens.spaceMd),
          _DisclosureLine(
            icon: Icons.upload_outlined,
            title: t('送るもの', 'What is sent'),
            body: t(
              '参加への同意、不透明な参加資格、学習日、学習成果eventの一方向ハッシュ',
              'Your consent to join, an opaque membership token, the study date, and a one-way hash of learning events',
            ),
          ),
          const SizedBox(height: GameTokens.spaceMd),
          _DisclosureLine(
            icon: Icons.visibility_off_outlined,
            title: t('送らないもの', 'What is not sent'),
            body: t(
              '氏名、回答・選択肢、音声、端末ID',
              'Name, answers and choices, voice, device ID',
            ),
          ),
          const SizedBox(height: GameTokens.spaceMd),
          Text(
            t(
              '接続先はprivate/loopback HTTPSだけです。参加コード内の証明書fingerprintと一致しない相手には接続しません。',
              'Only private/loopback HTTPS addresses are allowed. We never connect if the certificate fingerprint doesn\'t match the join code.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(color: colors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _DisclosureLine extends StatelessWidget {
  const _DisclosureLine({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colors.pathActive),
        const SizedBox(width: GameTokens.spaceSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: colors.ink)
                    .jaWeight(FontWeight.w800),
              ),
              Text(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KindButton extends StatelessWidget {
  const _KindButton({
    required this.kind,
    required this.selected,
    required this.joined,
    required this.onPressed,
  });

  final LanSocialRoomKind kind;
  final bool selected;
  final bool joined;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = switch (kind) {
      LanSocialRoomKind.friends => t('共同観察', 'Duo quest'),
      LanSocialRoomKind.league => t('共同観測', 'Weekly league'),
    };
    return Semantics(
      button: true,
      selected: selected,
      label: '$label${joined ? t('、参加中', ', joined') : ''}',
      child: SizedBox(
        width: double.infinity,
        child: selected
            ? FilledButton.icon(
                key: ValueKey('lan-social-kind-${kind.wire}'),
                onPressed: onPressed,
                icon: Icon(
                  kind == LanSocialRoomKind.friends
                      ? Icons.fact_check_outlined
                      : Icons.format_list_numbered_outlined,
                ),
                label: Text('$label${joined ? t('（参加中）', ' (joined)') : ''}'),
              )
            : OutlinedButton.icon(
                key: ValueKey('lan-social-kind-${kind.wire}'),
                onPressed: onPressed,
                icon: Icon(
                  kind == LanSocialRoomKind.friends
                      ? Icons.fact_check_outlined
                      : Icons.format_list_numbered_outlined,
                ),
                label: Text('$label${joined ? t('（参加中）', ' (joined)') : ''}'),
              ),
      ),
    );
  }
}

class _JoinRoom extends StatelessWidget {
  const _JoinRoom({
    required this.kind,
    required this.controller,
    required this.explicitOptIn,
    required this.busy,
    required this.onOptInChanged,
    required this.onJoin,
    required this.onScan,
  });

  final LanSocialRoomKind kind;
  final TextEditingController controller;
  final bool explicitOptIn;
  final bool busy;
  final ValueChanged<bool> onOptInChanged;
  final VoidCallback onJoin;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final theme = Theme.of(context);
    final title = kind == LanSocialRoomKind.friends
        ? t('共同観察に参加', 'Join a duo quest')
        : t('共同観測に参加', 'Join the weekly league');
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: theme.textTheme.titleLarge
                  ?.copyWith(color: colors.ink)
                  .jaWeight(FontWeight.w900),
            ),
          ),
          const SizedBox(height: GameTokens.spaceSm),
          Text(
            kind == LanSocialRoomKind.friends
                ? t(
                    '別端末の相手と1回ずつ学習成果を積むと共同達成です。相手の回答や得点は見えません。',
                    'You complete it together when you and a partner on another device each add one learning result. You can\'t see their answers or score.',
                  )
                : t(
                    '5人以上の実参加者がそろった週だけ匿名順位を表示します。5人未満では順位も得点も表示しません。',
                    'Anonymous rankings appear only in weeks with 5 or more real participants. With fewer than 5, no rankings or scores are shown.',
                  ),
            style: theme.textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
          ),
          const SizedBox(height: GameTokens.spaceLg),
          TextField(
            key: const ValueKey('lan-social-connection-code'),
            controller: controller,
            enabled: !busy,
            minLines: 2,
            maxLines: 5,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: t('参加コード', 'Join code'),
              hintText: t('DKS1. から始まるコード', 'A code starting with DKS1.'),
            ),
          ),
          const SizedBox(height: GameTokens.spaceMd),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('lan-social-scan-code'),
              onPressed: busy ? null : onScan,
              icon: const Icon(Icons.qr_code_scanner_outlined),
              label: Text(t('QRを読み取る', 'Scan QR code')),
            ),
          ),
          const SizedBox(height: GameTokens.spaceMd),
          CheckboxListTile(
            key: const ValueKey('lan-social-explicit-opt-in'),
            value: explicitOptIn,
            onChanged: busy ? null : (value) => onOptInChanged(value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              t(
                '上記の送信範囲を確認し、この部屋への参加に同意します',
                'I\'ve checked what will be sent above and agree to join this room',
              ),
            ),
          ),
          const SizedBox(height: GameTokens.spaceMd),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('lan-social-join'),
              onPressed: explicitOptIn && !busy ? onJoin : null,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login_outlined),
              label: Text(
                busy ? t('接続しています', 'Connecting') : t('参加する', 'Join'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinedRoom extends StatelessWidget {
  const _JoinedRoom({
    required this.kind,
    required this.snapshot,
    required this.leagueProfile,
    required this.leavePending,
    required this.busy,
    required this.onRefresh,
    required this.onLeave,
  });

  final LanSocialRoomKind kind;
  final LanSocialSnapshot? snapshot;
  final LanSocialLeagueProfile leagueProfile;
  final bool leavePending;
  final bool busy;
  final VoidCallback onRefresh;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (leavePending)
          _LiveMessage(
            value: t(
              '退出を完了できませんでした。参加資格は端末に保持しています。接続を確認してもう一度試してください。',
              'Couldn\'t finish leaving. Your membership is still kept on this device. Check your connection and try again.',
            ),
            isError: true,
          )
        else if (snapshot == null)
          _LoadingState(
            label: t('コーディネーターの状態を待っています', 'Waiting for the coordinator'),
          )
        else if (snapshot case final LanSocialFriendsSnapshot friends)
          _FriendsRoom(snapshot: friends)
        else if (snapshot case final LanSocialLeagueSnapshot league)
          _LeagueRoom(snapshot: league, profile: leagueProfile),
        const SizedBox(height: GameTokens.spaceLg),
        if (!leavePending) ...[
          OutlinedButton.icon(
            key: const ValueKey('lan-social-refresh'),
            onPressed: busy ? null : onRefresh,
            icon: busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_outlined),
            label: Text(t('最新の状態に更新', 'Refresh status')),
          ),
          const SizedBox(height: GameTokens.spaceSm),
        ],
        TextButton.icon(
          key: const ValueKey('lan-social-leave'),
          onPressed: busy ? null : onLeave,
          icon: const Icon(Icons.logout_outlined),
          label: Text(
            leavePending
                ? t('退出をもう一度送る', 'Send leave request again')
                : kind == LanSocialRoomKind.friends
                ? t('共同観察の参加をやめる', 'Leave the duo quest')
                : t('共同観測の参加をやめる', 'Leave the weekly league'),
          ),
        ),
      ],
    );
  }
}

class _FriendsRoom extends StatelessWidget {
  const _FriendsRoom({required this.snapshot});

  final LanSocialFriendsSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final theme = Theme.of(context);
    final state = switch (snapshot.state) {
      LanSocialFriendsState.waitingForPartner => (
        icon: Icons.person_add_alt_1_outlined,
        title: t('相手を待っています', 'Waiting for your partner'),
        body: t(
          '参加コードを、いっしょに学ぶ1人へ渡してください。',
          'Give the join code to the one person you\'re learning with.',
        ),
      ),
      LanSocialFriendsState.active => (
        icon: Icons.fact_check_outlined,
        title: t('ふたりそろいました', 'You\'re both here'),
        body: snapshot.myContributed
            ? t(
                'あなたの学習成果は届きました。相手の1回を待っています。',
                'Your learning result arrived. Waiting for your partner\'s turn.',
              )
            : t(
                'ふたりがそれぞれ学習成果を1回積むと達成し、結晶1個を受け取れます。',
                'When you each add one learning result, you complete the quest and get 1 crystal.',
              ),
      ),
      LanSocialFriendsState.completed => (
        icon: Icons.assignment_turned_in_outlined,
        title: t('共同観察を達成しました', 'Duo quest complete'),
        body: t(
          '実在するふたりが、それぞれ学習成果を積みました。達成報酬の結晶1個は、この端末に一度だけ記録されます。',
          'Two real people each added a learning result. The 1-crystal reward is recorded on this device only once.',
        ),
      ),
      LanSocialFriendsState.expired => (
        icon: Icons.event_busy_outlined,
        title: t('この共同観察は終了しました', 'This quest has ended'),
        body: snapshot.completed
            ? t('終了前に、ふたりで達成しています。', 'You two completed it before it ended.')
            : t(
                '新しい参加コードで次の共同観察へ参加できます。',
                'Use a new join code to join the next quest.',
              ),
      ),
    };
    final myState = snapshot.myContributed
        ? t('自分の1回：完了', 'Your turn: done')
        : t('自分の1回：まだ', 'Your turn: not yet');
    final partnerState = !snapshot.partnerJoined
        ? t('相手：参加待ち', 'Partner: waiting to join')
        : snapshot.completed
        ? t('相手の1回：完了', 'Partner\'s turn: done')
        : t('相手の1回：内容・得点は非表示', 'Partner\'s turn: details and score hidden');
    return Semantics(
      container: true,
      label: t(
        '${state.title}。$myState。$partnerState。',
        '${state.title}. $myState. $partnerState.',
      ),
      child: ExcludeSemantics(
        child: _Surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(state.icon, size: 40, color: colors.pathComplete),
              const SizedBox(height: GameTokens.spaceMd),
              Text(
                state.title,
                key: const ValueKey('lan-social-friends-state'),
                style: theme.textTheme.titleLarge
                    ?.copyWith(color: colors.ink)
                    .jaWeight(FontWeight.w900),
              ),
              const SizedBox(height: GameTokens.spaceSm),
              Text(
                state.body,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.inkMuted,
                ),
              ),
              const SizedBox(height: GameTokens.spaceLg),
              _StateLine(
                icon: snapshot.myContributed
                    ? Icons.check_circle_outline
                    : Icons.radio_button_unchecked,
                text: myState,
              ),
              const SizedBox(height: GameTokens.spaceSm),
              _StateLine(
                icon: !snapshot.partnerJoined
                    ? Icons.hourglass_empty_outlined
                    : snapshot.completed
                    ? Icons.check_circle_outline
                    : Icons.privacy_tip_outlined,
                text: partnerState,
              ),
              const SizedBox(height: GameTokens.spaceLg),
              Text(
                t(
                  '相手の氏名・回答・音声・端末ID・個別得点は受け取りません。',
                  'We never receive your partner\'s name, answers, voice, device ID, or individual score.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeagueRoom extends StatelessWidget {
  const _LeagueRoom({required this.snapshot, required this.profile});

  final LanSocialLeagueSnapshot snapshot;
  final LanSocialLeagueProfile profile;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Surface(
          semanticLabel: t(
            '現在の観測級は${profile.currentTier.displayLabel}',
            'Current tier: ${profile.currentTier.label}',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('自分の観測級', 'Your weekly tier'),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.inkMuted,
                ),
              ),
              const SizedBox(height: GameTokens.spaceXs),
              Text(
                profile.currentTier.displayLabel,
                key: const ValueKey('lan-social-current-tier'),
                style: theme.textTheme.headlineSmall
                    ?.copyWith(color: colors.ink)
                    .jaWeight(FontWeight.w900),
              ),
              const SizedBox(height: GameTokens.spaceMd),
              Wrap(
                spacing: GameTokens.spaceSm,
                runSpacing: GameTokens.spaceSm,
                children: [
                  for (final tier in LanSocialLeagueTier.values)
                    _TierLabel(
                      tier: tier,
                      current: tier == profile.currentTier,
                    ),
                ],
              ),
              const SizedBox(height: GameTokens.spaceMd),
              Text(
                t(
                  '実参加者の今週順位と、端末内だけの観測級履歴は別に扱います。',
                  'This week\'s ranking among real participants is kept separate from your on-device tier history.',
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.inkMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: GameTokens.spaceLg),
        if (!snapshot.privacyThresholdReached)
          _LeaguePrivacyShield(expired: snapshot.expired)
        else
          _LeagueStandings(snapshot: snapshot),
        if (profile.history.isNotEmpty) ...[
          const SizedBox(height: GameTokens.spaceLg),
          _LeagueHistory(history: profile.history),
        ],
      ],
    );
  }
}

class _LeaguePrivacyShield extends StatelessWidget {
  const _LeaguePrivacyShield({required this.expired});

  final bool expired;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final theme = Theme.of(context);
    return _Surface(
      semanticLabel: t(
        'プライバシー保護中。5人未満のため順位と得点は非表示。',
        'Privacy protected. Rankings and scores are hidden with fewer than 5 people.',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 40, color: colors.pathActive),
          const SizedBox(height: GameTokens.spaceMd),
          Text(
            t('順位はまだ表示しません', 'Rankings aren\'t shown yet'),
            key: const ValueKey('lan-social-league-private'),
            style: theme.textTheme.titleLarge
                ?.copyWith(color: colors.ink)
                .jaWeight(FontWeight.w900),
          ),
          const SizedBox(height: GameTokens.spaceSm),
          Text(
            expired
                ? t(
                    'この週は5人のプライバシー閾値に届かなかったため、順位も得点も作らずに終了しました。',
                    'This week didn\'t reach the 5-person privacy threshold, so it ended without any rankings or scores.',
                  )
                : t(
                    '5人以上になるまで、順位、自分を含む得点、実人数を表示しません。架空の参加者で埋めることもありません。',
                    'Until there are 5 or more people, we don\'t show rankings, scores (including yours), or the headcount. We never fill in fake participants.',
                  ),
            style: theme.textTheme.bodyLarge?.copyWith(color: colors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _LeagueStandings extends StatelessWidget {
  const _LeagueStandings({required this.snapshot});

  final LanSocialLeagueSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final theme = Theme.of(context);
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              snapshot.expired
                  ? t('今週の確定順位', 'This week\'s final ranking')
                  : t('今週の匿名順位', 'This week\'s anonymous ranking'),
              style: theme.textTheme.titleLarge
                  ?.copyWith(color: colors.ink)
                  .jaWeight(FontWeight.w900),
            ),
          ),
          const SizedBox(height: GameTokens.spaceXs),
          Text(
            t(
              '${snapshot.weekStart} 〜 ${snapshot.weekEnd}',
              '${snapshot.weekStart} – ${snapshot.weekEnd}',
            ),
            style: theme.textTheme.bodySmall?.copyWith(color: colors.inkMuted),
          ),
          const SizedBox(height: GameTokens.spaceLg),
          for (
            var index = 0;
            index < snapshot.standings.length;
            index += 1
          ) ...[
            _StandingRow(standing: snapshot.standings[index], index: index),
            if (index < snapshot.standings.length - 1)
              const Divider(height: GameTokens.spaceXl),
          ],
          const SizedBox(height: GameTokens.spaceMd),
          Text(
            t(
              '名前や公開participant IDはありません。表示行は、参加した実在端末の分だけです。',
              'No names or public participant IDs. Each row is one real device that joined.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(color: colors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({required this.standing, required this.index});

  final LanSocialLeagueStanding standing;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final theme = Theme.of(context);
    final rank = standing.rank == null
        ? t('順位なし', 'No rank')
        : t('${standing.rank}位', '#${standing.rank}');
    final participant = standing.isMe
        ? t('自分', 'You')
        : t('匿名の参加者 ${index + 1}', 'Anonymous participant ${index + 1}');
    final tied = standing.tied ? t('、同順位', ', tied') : '';
    return Semantics(
      container: true,
      label: t(
        '$rank、$participant、${standing.xp} 探究記録$tied',
        '$rank, $participant, ${standing.xp} XP$tied',
      ),
      child: ExcludeSemantics(
        child: Container(
          key: ValueKey('lan-social-standing-$index'),
          padding: const EdgeInsets.symmetric(vertical: GameTokens.spaceXs),
          color: standing.isMe ? colors.surfaceRaised : Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$rank  $participant${standing.tied ? t('（同順位）', ' (tied)') : ''}',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: colors.ink)
                    .jaWeight(
                      standing.isMe ? FontWeight.w900 : FontWeight.w700,
                    ),
              ),
              const SizedBox(height: GameTokens.spaceXs),
              Text(
                localize.t(
                  '${standing.xp} 探究記録',
                  '${standing.xp} learning record',
                ),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeagueHistory extends StatelessWidget {
  const _LeagueHistory({required this.history});

  final List<LanSocialLeagueWeek> history;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final theme = Theme.of(context);
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              t('昇格・降格の履歴', 'Promotion and demotion history'),
              style: theme.textTheme.titleLarge
                  ?.copyWith(color: colors.ink)
                  .jaWeight(FontWeight.w900),
            ),
          ),
          const SizedBox(height: GameTokens.spaceMd),
          for (final week in history.take(8)) ...[
            _LeagueHistoryRow(week: week),
            const SizedBox(height: GameTokens.spaceSm),
          ],
        ],
      ),
    );
  }
}

class _LeagueHistoryRow extends StatelessWidget {
  const _LeagueHistoryRow({required this.week});

  final LanSocialLeagueWeek week;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final theme = Theme.of(context);
    final movement = switch (week.movement) {
      LanSocialLeagueMovement.promoted => (
        icon: Icons.arrow_upward_outlined,
        label: t('昇格', 'Promoted'),
      ),
      LanSocialLeagueMovement.stayed => (
        icon: Icons.horizontal_rule_outlined,
        label: t('維持', 'Stayed'),
      ),
      LanSocialLeagueMovement.demoted => (
        icon: Icons.arrow_downward_outlined,
        label: t('降格', 'Demoted'),
      ),
    };
    return Semantics(
      label: t(
        '${week.weekStart}の週、${week.previousTier.displayLabel}から${week.tier.displayLabel}へ${movement.label}',
        'Week of ${week.weekStart}: ${movement.label} from ${week.previousTier.label} to ${week.tier.label}',
      ),
      child: ExcludeSemantics(
        child: Container(
          key: ValueKey('lan-social-history-${week.weekStart}'),
          padding: const EdgeInsets.all(GameTokens.spaceMd),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(GameTokens.radiusMd),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(movement.icon, color: colors.pathActive),
              const SizedBox(width: GameTokens.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${movement.label}：${week.previousTier.displayLabel} → ${week.tier.displayLabel}',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: colors.ink)
                          .jaWeight(FontWeight.w800),
                    ),
                    Text(
                      week.weekStart,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TierLabel extends StatelessWidget {
  const _TierLabel({required this.tier, required this.current});

  final LanSocialLeagueTier tier;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final theme = Theme.of(context);
    final label = tier.displayLabel;
    return Semantics(
      label: '$label${current ? localize.t('、現在', ", current") : ''}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: GameTokens.spaceMd,
            vertical: GameTokens.spaceSm,
          ),
          decoration: BoxDecoration(
            color: current ? colors.pathActive : colors.surfaceRaised,
            borderRadius: BorderRadius.circular(GameTokens.radiusPill),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: current ? colors.onPathActive : colors.ink)
                .jaWeight(current ? FontWeight.w900 : FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _StateLine extends StatelessWidget {
  const _StateLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: colors.pathActive),
        const SizedBox(width: GameTokens.spaceSm),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: colors.ink),
          ),
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: label,
    child: const Center(
      child: Padding(
        padding: EdgeInsets.all(GameTokens.spaceXl),
        child: CircularProgressIndicator(),
      ),
    ),
  );
}

class _LiveMessage extends StatelessWidget {
  const _LiveMessage({required this.value, required this.isError});

  final String value;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      label: value,
      child: ExcludeSemantics(
        child: Container(
          key: const ValueKey('lan-social-live-message'),
          padding: const EdgeInsets.all(GameTokens.spaceMd),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            border: Border.all(
              color: isError ? theme.colorScheme.error : colors.border,
            ),
            borderRadius: BorderRadius.circular(GameTokens.radiusMd),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: isError ? theme.colorScheme.error : colors.pathComplete,
              ),
              const SizedBox(width: GameTokens.spaceSm),
              Expanded(
                child: Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child, this.semanticLabel});

  final Widget child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final content = Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GameTokens.radiusLg),
        side: BorderSide(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(GameTokens.spaceLg),
        child: child,
      ),
    );
    if (semanticLabel == null) return content;
    return Semantics(
      container: true,
      label: semanticLabel,
      child: ExcludeSemantics(child: content),
    );
  }
}

/// 管理PCで発行されたadmin keyを、参加コードと分離したまま使う部屋作成画面。
class LanSocialRoomCreateScreen extends StatefulWidget {
  const LanSocialRoomCreateScreen({
    super.key,
    required this.store,
    required this.schoolMode,
    this.lanSocialAllowed = false,
    this.clientFactory,
  });

  final SessionStore store;
  final bool schoolMode;
  final bool lanSocialAllowed;
  final LanSocialClientFactory? clientFactory;

  @override
  State<LanSocialRoomCreateScreen> createState() =>
      _LanSocialRoomCreateScreenState();
}

class _LanSocialRoomCreateScreenState extends State<LanSocialRoomCreateScreen> {
  final _endpoint = TextEditingController();
  final _fingerprint = TextEditingController();
  final _coordinatorKey = TextEditingController();
  LanSocialRoomKind _kind = LanSocialRoomKind.friends;
  int _capacity = 5;
  bool _explicitOptIn = false;
  bool _busy = false;
  String? _createdCode;
  String? _message;
  bool _messageIsError = false;

  @override
  void dispose() {
    _endpoint.dispose();
    _fingerprint.dispose();
    _coordinatorKey.clear();
    _coordinatorKey.dispose();
    super.dispose();
  }

  LanSocialClient _clientFor(LanSocialEndpoint endpoint) =>
      widget.clientFactory?.call(endpoint) ??
      LanSocialClient(endpoint: endpoint, store: widget.store);

  Future<void> _create() async {
    if (_busy ||
        !_explicitOptIn ||
        !widget.lanSocialAllowed ||
        widget.schoolMode) {
      return;
    }
    final endpoint = LanSocialEndpoint(
      baseUrl: _endpoint.text.trim(),
      certificateSha256: _fingerprint.text.trim().toLowerCase(),
    );
    LanSocialClient client;
    try {
      client = _clientFor(endpoint);
    } on ArgumentError {
      _setMessage(
        t(
          '接続先はprivate/loopback HTTPSのIP、fingerprintは64桁のSHA-256を入力してください。',
          'Enter a private/loopback HTTPS IP as the address, and a 64-character SHA-256 as the fingerprint.',
        ),
        isError: true,
      );
      return;
    }
    final adminKey = _coordinatorKey.text;
    if (adminKey.length < 32) {
      _setMessage(
        t(
          '管理キーを確認してください。参加コードとは別の値です。',
          'Please check the admin key. It is different from the join code.',
        ),
        isError: true,
      );
      return;
    }
    setState(() {
      _busy = true;
      _createdCode = null;
      _message = null;
    });
    LanSocialCreatedRoom? room;
    try {
      room = await client.createRoom(
        kind: _kind,
        capacity: _kind == LanSocialRoomKind.friends ? 2 : _capacity,
        coordinatorKey: adminKey,
        explicitOptIn: true,
      );
    } on Object {
      room = null;
    } finally {
      _coordinatorKey.clear();
    }
    if (!mounted) return;
    if (room == null) {
      setState(() => _busy = false);
      _setMessage(
        t(
          '部屋を作れませんでした。管理キー、証明書、同じWi-Fiへの接続を確認してください。',
          'Couldn\'t create the room. Check the admin key, certificate, and that you\'re on the same Wi-Fi.',
        ),
        isError: true,
      );
      return;
    }
    final code = client.connectionCodeFor(room).encode();
    setState(() {
      _busy = false;
      _explicitOptIn = false;
      _createdCode = code;
      _message = t(
        '参加者用コードを作りました。管理キーは含まれていません。',
        'Participant code created. It does not include the admin key.',
      );
      _messageIsError = false;
    });
  }

  Future<void> _copyCode() async {
    final code = _createdCode;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t('参加者用コードをコピーしました', 'Participant code copied'))),
    );
  }

  void _setMessage(String value, {required bool isError}) {
    if (!mounted) return;
    setState(() {
      _message = value;
      _messageIsError = isError;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.lanSocialAllowed || widget.schoolMode) {
      return _LanSocialUnavailableScreen(schoolMode: widget.schoolMode);
    }
    final colors = context.gamePalette;
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(title: Text(t('LANの部屋を作る', 'Create a LAN room'))),
      body: SafeArea(
        top: false,
        child: ListView(
          key: const ValueKey('lan-social-create-screen'),
          padding: const EdgeInsets.fromLTRB(
            GameTokens.spaceLg,
            GameTokens.spaceMd,
            GameTokens.spaceLg,
            48,
          ),
          children: [
            Semantics(
              header: true,
              child: Text(
                t(
                  '管理キーは参加者へ渡しません',
                  'Never share the admin key with participants',
                ),
                style: theme.textTheme.headlineSmall
                    ?.copyWith(color: colors.ink)
                    .jaWeight(FontWeight.w900),
              ),
            ),
            const SizedBox(height: GameTokens.spaceSm),
            Text(
              t(
                'この設定は、管理PCでLAN coordinatorを起動した先生・保護者向けです。参加者用コードにはHTTPS接続先、証明書fingerprint、room inviteだけが入ります。',
                'This setup is for teachers or parents who started the LAN coordinator on an admin PC. The participant code contains only the HTTPS address, certificate fingerprint, and room invite.',
              ),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.inkMuted,
              ),
            ),
            const SizedBox(height: GameTokens.spaceXl),
            _Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    key: const ValueKey('lan-social-endpoint'),
                    controller: _endpoint,
                    enabled: !_busy,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: t('private HTTPS接続先', 'Private HTTPS address'),
                      hintText: 'https://192.168.1.20:8787',
                    ),
                  ),
                  const SizedBox(height: GameTokens.spaceMd),
                  TextField(
                    key: const ValueKey('lan-social-fingerprint'),
                    controller: _fingerprint,
                    enabled: !_busy,
                    minLines: 2,
                    maxLines: 3,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: t(
                        '証明書SHA-256 fingerprint',
                        'Certificate SHA-256 fingerprint',
                      ),
                      hintText: t('64桁の小文字hex', '64 lowercase hex characters'),
                    ),
                  ),
                  const SizedBox(height: GameTokens.spaceMd),
                  TextField(
                    key: const ValueKey('lan-social-coordinator-key'),
                    controller: _coordinatorKey,
                    enabled: !_busy,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: t('管理キー', 'Admin key'),
                      helperText: t(
                        '管理PCの画面から直接入力し、保存しません',
                        'Type it directly from the admin PC screen. It is not saved',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: GameTokens.spaceXl),
            if (!widget.schoolMode) ...[
              _KindButton(
                kind: LanSocialRoomKind.friends,
                selected: _kind == LanSocialRoomKind.friends,
                joined: false,
                onPressed: _busy
                    ? null
                    : () => setState(() => _kind = LanSocialRoomKind.friends),
              ),
              const SizedBox(height: GameTokens.spaceSm),
              _KindButton(
                kind: LanSocialRoomKind.league,
                selected: _kind == LanSocialRoomKind.league,
                joined: false,
                onPressed: _busy
                    ? null
                    : () => setState(() => _kind = LanSocialRoomKind.league),
              ),
            ],
            if (_kind == LanSocialRoomKind.league && !widget.schoolMode) ...[
              const SizedBox(height: GameTokens.spaceLg),
              Text(
                t('参加枠（5〜8人）', 'Spots (5–8 people)'),
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: colors.ink)
                    .jaWeight(FontWeight.w800),
              ),
              const SizedBox(height: GameTokens.spaceSm),
              Wrap(
                spacing: GameTokens.spaceSm,
                runSpacing: GameTokens.spaceSm,
                children: [
                  for (var value = 5; value <= 8; value += 1)
                    Semantics(
                      button: true,
                      selected: _capacity == value,
                      label: t('$value人', '$value people'),
                      child: SizedBox(
                        height: GameTokens.minTouchTarget,
                        child: _capacity == value
                            ? FilledButton(
                                key: ValueKey('lan-social-capacity-$value'),
                                onPressed: _busy
                                    ? null
                                    : () => setState(() => _capacity = value),
                                child: Text(t('$value人', '$value people')),
                              )
                            : OutlinedButton(
                                key: ValueKey('lan-social-capacity-$value'),
                                onPressed: _busy
                                    ? null
                                    : () => setState(() => _capacity = value),
                                child: Text(t('$value人', '$value people')),
                              ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: GameTokens.spaceLg),
            CheckboxListTile(
              key: const ValueKey('lan-social-create-opt-in'),
              value: _explicitOptIn,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _explicitOptIn = value ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                t(
                  'この管理PCに部屋情報を保存し、参加コードを発行することに同意します',
                  'I agree to save room info on this admin PC and issue a join code',
                ),
              ),
              subtitle: Text(
                t(
                  '氏名、回答、音声、端末IDを部屋情報として受け取りません',
                  'Names, answers, voice, and device IDs are never collected as room info',
                ),
              ),
            ),
            const SizedBox(height: GameTokens.spaceMd),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('lan-social-create-room'),
                onPressed: _explicitOptIn && !_busy ? _create : null,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_link_outlined),
                label: Text(
                  _busy
                      ? t('作成しています', 'Creating')
                      : t('参加者用コードを作る', 'Create participant code'),
                ),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: GameTokens.spaceLg),
              _LiveMessage(value: _message!, isError: _messageIsError),
            ],
            if (_createdCode != null) ...[
              const SizedBox(height: GameTokens.spaceLg),
              _Surface(
                semanticLabel: t(
                  '参加者用コード。管理キーは含まれていません。',
                  'Participant code. Does not include the admin key.',
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('参加者用コード', 'Participant code'),
                      style: theme.textTheme.titleLarge
                          ?.copyWith(color: colors.ink)
                          .jaWeight(FontWeight.w900),
                    ),
                    const SizedBox(height: GameTokens.spaceSm),
                    Center(
                      child: ParticipantQrCode(
                        data: _createdCode!,
                        semanticLabel: t(
                          '参加者用QR。管理キー、生徒名、回答、音声、端末IDは含まれていません。',
                          'Participant QR. Does not include the admin key, student names, answers, voice, or device IDs.',
                        ),
                      ),
                    ),
                    const SizedBox(height: GameTokens.spaceMd),
                    SelectableText(
                      _createdCode!,
                      key: const ValueKey('lan-social-created-code'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: GameTokens.spaceMd),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        key: const ValueKey('lan-social-copy-code'),
                        onPressed: _copyCode,
                        icon: const Icon(Icons.copy_outlined),
                        label: Text(t('コードをコピー', 'Copy code')),
                      ),
                    ),
                    const SizedBox(height: GameTokens.spaceSm),
                    Text(
                      t(
                        '管理キーは構造上このコードとQRへ入りません。参加する人は、読み取り後にも送信範囲への同意が必要です。',
                        'By design, the admin key can never be in this code or QR. Participants still have to agree to what is sent after scanning.',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LanSocialUnavailableScreen extends StatelessWidget {
  const _LanSocialUnavailableScreen({required this.schoolMode});

  final bool schoolMode;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final theme = Theme.of(context);
    final title = schoolMode
        ? t('学校の端末内モードでは利用できません', 'Not available in school on-device mode')
        : t('通信しないモードでは利用できません', 'Not available in offline mode');
    final body = schoolMode
        ? t(
            '現在の学校向け契約は、学校serverへ接続せず、入力も学習記録も送らないlocal-onlyです。LAN coordinatorへも参加資格、学習日、event hashを送信しません。',
            'The current school plan is local-only: it never connects to a school server or sends your input or learning records. Nothing (membership, study date, or event hash) is sent to a LAN coordinator either.',
          )
        : t(
            'LANの共同機能は、成人onlineモードで送信範囲へ明示同意した場合だけ利用できます。local-onlyでは接続先を作らず、何も送信しません。',
            'LAN group features are available only in adult online mode after you explicitly agree to what is sent. Local-only mode creates no connections and sends nothing.',
          );
    return Scaffold(
      key: const ValueKey('lan-social-unavailable'),
      backgroundColor: colors.canvas,
      appBar: AppBar(title: Text(t('いっしょに学ぶ', 'Learn together'))),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            GameTokens.spaceLg,
            GameTokens.spaceXl,
            GameTokens.spaceLg,
            48,
          ),
          children: [
            _Surface(
              semanticLabel: t(
                '$title。LANへの接続と送信はありません。',
                '$title. No LAN connection and nothing is sent.',
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.portable_wifi_off_outlined,
                    size: 40,
                    color: colors.pathLocked,
                  ),
                  const SizedBox(height: GameTokens.spaceMd),
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(color: colors.ink)
                        .jaWeight(FontWeight.w900),
                  ),
                  const SizedBox(height: GameTokens.spaceSm),
                  Text(
                    body,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _joinErrorLabel(LanSocialClientError? error) => switch (error) {
  LanSocialClientError.optInRequired => t(
    '参加前の同意が必要です。',
    'You need to agree before joining.',
  ),
  LanSocialClientError.invalidConnectionCode => t(
    '参加コードを確認してください。',
    'Please check the join code.',
  ),
  LanSocialClientError.alreadyJoined => t(
    'この種類の部屋にはすでに参加しています。',
    'You\'ve already joined this type of room.',
  ),
  LanSocialClientError.roomNotFound => t('部屋が見つかりません。', 'Room not found.'),
  LanSocialClientError.roomExpired => t(
    'この部屋は終了しています。',
    'This room has ended.',
  ),
  LanSocialClientError.roomFull => t('この部屋の参加枠は埋まっています。', 'This room is full.'),
  LanSocialClientError.rateLimited => t(
    '試行回数の上限です。しばらく待ってください。',
    'Too many attempts. Please wait a while.',
  ),
  LanSocialClientError.unauthorized => t(
    '参加資格を確認できませんでした。',
    'Couldn\'t verify your membership.',
  ),
  LanSocialClientError.schoolLeagueDisabled => t(
    '学校モードでは共同観測に参加できません。',
    'You can\'t join the weekly league in school mode.',
  ),
  LanSocialClientError.wrongDay => t(
    '学習日の確認に失敗しました。',
    'Couldn\'t verify the study date.',
  ),
  LanSocialClientError.invalidResponse => t(
    '安全な応答として確認できなかったため、参加しませんでした。',
    'The response couldn\'t be verified as safe, so you were not joined.',
  ),
  LanSocialClientError.notJoined ||
  LanSocialClientError.notMeaningful ||
  LanSocialClientError.unavailable ||
  null => t(
    '接続できませんでした。証明書と同じWi-Fiへの接続を確認してください。',
    'Couldn\'t connect. Check the certificate and that you\'re on the same Wi-Fi.',
  ),
};
