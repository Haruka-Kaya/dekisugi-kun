import 'package:flutter/services.dart';

import '../config/app_theme.dart';
import '../config/game_tokens.dart';
import '../models/lan_social.dart';
import '../services/lan_social_client.dart';
import '../services/session_store.dart';
import '../ui/_material.dart';

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
  });

  final SessionStore store;
  final bool schoolMode;

  /// 成人online同意ツリーからだけtrueを渡す。local-only personal/schoolはfalse。
  final bool lanSocialAllowed;
  final LanSocialClientFactory? clientFactory;

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
      _setMessage('参加コードを確認してください。', isError: true);
      return;
    }
    if (widget.schoolMode && code.kind == LanSocialRoomKind.league) {
      _setMessage('学校モードでは個人順位の週次リーグに参加できません。', isError: true);
      return;
    }
    if (code.kind != _selected) {
      _setMessage('選んだ遊びと参加コードの種類が一致しません。', isError: true);
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
      _setMessage('private HTTPS接続先として確認できない参加コードです。', isError: true);
      return;
    }
    LanSocialJoinResult result;
    try {
      result = await client.join(code, explicitOptIn: true);
    } on Object {
      if (!mounted) return;
      setState(() => _busy = false);
      _setMessage('安全に参加状態を保存できなかったため、参加しませんでした。', isError: true);
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
      _message = '参加しました。学習成果が記録されると自動で共同進捗へ反映されます。';
      _messageIsError = false;
    });
    await _refresh(code.kind, announceFailure: false);
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
          _message = 'コーディネーターに接続できませんでした。証明書や同じWi-Fiへの接続を確認してください。';
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
        _message = '最新の状態に更新しました。';
        _messageIsError = false;
      }
    });
  }

  String _terminalSettlementMessage(LanSocialTerminalReceipt receipt) {
    return switch (receipt) {
      LanSocialFriendsTerminalReceipt(:final completed) =>
        completed
            ? 'フレンズクエストの共同達成を端末に確定しました。結晶はこの部屋につき1個です。'
            : 'フレンズクエストは未達成で終了しました。',
      LanSocialLeagueTerminalReceipt(
        :final privacyThresholdReached,
        :final rank,
      ) =>
        !privacyThresholdReached
            ? '参加者が5人未満だったため、順位を保存せずリーグを終了しました。'
            : rank == null
            ? '週のリーグ結果を「順位なし」として端末に保存しました。'
            : '週のリーグ$rank位を端末に保存しました。',
    };
  }

  Future<void> _leave(LanSocialRoomKind kind) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('参加をやめますか？'),
        content: const Text(
          'この端末の参加資格を消し、コーディネーターにも退出を伝えます。これまでの週次tier履歴は端末内に残ります。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('続ける'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('参加をやめる'),
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
      _setMessage('参加解除を安全に保存できませんでした。もう一度試してください。', isError: true);
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
      _message = 'この端末の参加を解除しました。';
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
          'いっしょに学ぶ',
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
                '本当に参加した人と進める',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(color: colors.ink)
                    .jaWeight(FontWeight.w900),
              ),
            ),
            const SizedBox(height: GameTokens.spaceSm),
            Text(
              '架空の相手は出しません。同じWi-Fi上のコーディネーターに接続し、実在する参加者だけで遊びます。',
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
              const _LoadingState(label: '参加状態を確認しています')
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
              ),
            const SizedBox(height: GameTokens.spaceXl),
            _Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'コーディネーターを用意する人へ',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: colors.ink)
                        .jaWeight(FontWeight.w800),
                  ),
                  const SizedBox(height: GameTokens.spaceSm),
                  Text(
                    '学校・家庭の管理PCでLAN coordinatorを起動したあと、HTTPS接続先、証明書fingerprint、管理キーを設定します。',
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
                      label: const Text('部屋を作る設定'),
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
      semanticLabel:
          '送るものは明示同意、不透明な参加資格、学習日、学習成果の一方向ハッシュ。送らないものは氏名、回答、選択肢、音声、端末ID。',
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
                  '送る情報を最小にします',
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
            title: '送るもの',
            body: '参加への同意、不透明な参加資格、学習日、学習成果eventの一方向ハッシュ',
          ),
          const SizedBox(height: GameTokens.spaceMd),
          _DisclosureLine(
            icon: Icons.visibility_off_outlined,
            title: '送らないもの',
            body: '氏名、回答・選択肢、音声、端末ID',
          ),
          const SizedBox(height: GameTokens.spaceMd),
          Text(
            '接続先はprivate/loopback HTTPSだけです。参加コード内の証明書fingerprintと一致しない相手には接続しません。',
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
      LanSocialRoomKind.friends => 'ふたりクエスト',
      LanSocialRoomKind.league => '週次リーグ',
    };
    return Semantics(
      button: true,
      selected: selected,
      label: '$label${joined ? '、参加中' : ''}',
      child: SizedBox(
        width: double.infinity,
        child: selected
            ? FilledButton.icon(
                key: ValueKey('lan-social-kind-${kind.wire}'),
                onPressed: onPressed,
                icon: Icon(
                  kind == LanSocialRoomKind.friends
                      ? Icons.handshake_outlined
                      : Icons.leaderboard_outlined,
                ),
                label: Text('$label${joined ? '（参加中）' : ''}'),
              )
            : OutlinedButton.icon(
                key: ValueKey('lan-social-kind-${kind.wire}'),
                onPressed: onPressed,
                icon: Icon(
                  kind == LanSocialRoomKind.friends
                      ? Icons.handshake_outlined
                      : Icons.leaderboard_outlined,
                ),
                label: Text('$label${joined ? '（参加中）' : ''}'),
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
  });

  final LanSocialRoomKind kind;
  final TextEditingController controller;
  final bool explicitOptIn;
  final bool busy;
  final ValueChanged<bool> onOptInChanged;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final colors = context.gamePalette;
    final theme = Theme.of(context);
    final title = kind == LanSocialRoomKind.friends ? 'ふたりクエストに参加' : '週次リーグに参加';
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
                ? '別端末の相手と1回ずつ学習成果を積むと共同達成です。相手の回答や得点は見えません。'
                : '5人以上の実参加者がそろった週だけ匿名順位を表示します。5人未満では順位も得点も表示しません。',
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
            decoration: const InputDecoration(
              labelText: '参加コード',
              hintText: 'DKS1. から始まるコード',
            ),
          ),
          const SizedBox(height: GameTokens.spaceMd),
          CheckboxListTile(
            key: const ValueKey('lan-social-explicit-opt-in'),
            value: explicitOptIn,
            onChanged: busy ? null : (value) => onOptInChanged(value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('上記の送信範囲を確認し、この部屋への参加に同意します'),
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
              label: Text(busy ? '接続しています' : '参加する'),
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
          const _LiveMessage(
            value: '退出を完了できませんでした。参加資格は端末に保持しています。接続を確認してもう一度試してください。',
            isError: true,
          )
        else if (snapshot == null)
          const _LoadingState(label: 'コーディネーターの状態を待っています')
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
            label: const Text('最新の状態に更新'),
          ),
          const SizedBox(height: GameTokens.spaceSm),
        ],
        TextButton.icon(
          key: const ValueKey('lan-social-leave'),
          onPressed: busy ? null : onLeave,
          icon: const Icon(Icons.logout_outlined),
          label: Text(
            leavePending
                ? '退出をもう一度送る'
                : kind == LanSocialRoomKind.friends
                ? 'ふたりクエストの参加をやめる'
                : '週次リーグの参加をやめる',
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
        title: '相手を待っています',
        body: '参加コードを、いっしょに学ぶ1人へ渡してください。',
      ),
      LanSocialFriendsState.active => (
        icon: Icons.handshake_outlined,
        title: 'ふたりそろいました',
        body: snapshot.myContributed
            ? 'あなたの学習成果は届きました。相手の1回を待っています。'
            : 'ふたりがそれぞれ学習成果を1回積むと達成し、結晶1個を受け取れます。',
      ),
      LanSocialFriendsState.completed => (
        icon: Icons.celebration_outlined,
        title: 'ふたりのクエスト達成',
        body: '実在するふたりが、それぞれ学習成果を積みました。達成報酬の結晶1個は、この端末に一度だけ記録されます。',
      ),
      LanSocialFriendsState.expired => (
        icon: Icons.event_busy_outlined,
        title: 'このクエストは終了しました',
        body: snapshot.completed
            ? '終了前に、ふたりで達成しています。'
            : '新しい参加コードで次のクエストへ参加できます。',
      ),
    };
    final myState = snapshot.myContributed ? '自分の1回：完了' : '自分の1回：まだ';
    final partnerState = !snapshot.partnerJoined
        ? '相手：参加待ち'
        : snapshot.completed
        ? '相手の1回：完了'
        : '相手の1回：内容・得点は非表示';
    return Semantics(
      container: true,
      label: '${state.title}。$myState。$partnerState。',
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
                '相手の氏名・回答・音声・端末ID・個別得点は受け取りません。',
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
          semanticLabel: '現在のtierは${profile.currentTier.label}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '自分の週次tier',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.inkMuted,
                ),
              ),
              const SizedBox(height: GameTokens.spaceXs),
              Text(
                profile.currentTier.label,
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
                '実参加者の今週順位と、端末内だけのtier履歴は別に扱います。',
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
      semanticLabel: 'プライバシー保護中。5人未満のため順位と得点は非表示。',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, size: 40, color: colors.pathActive),
          const SizedBox(height: GameTokens.spaceMd),
          Text(
            '順位はまだ表示しません',
            key: const ValueKey('lan-social-league-private'),
            style: theme.textTheme.titleLarge
                ?.copyWith(color: colors.ink)
                .jaWeight(FontWeight.w900),
          ),
          const SizedBox(height: GameTokens.spaceSm),
          Text(
            expired
                ? 'この週は5人のプライバシー閾値に届かなかったため、順位も得点も作らずに終了しました。'
                : '5人以上になるまで、順位、自分を含む得点、実人数を表示しません。架空の参加者で埋めることもありません。',
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
              snapshot.expired ? '今週の確定順位' : '今週の匿名順位',
              style: theme.textTheme.titleLarge
                  ?.copyWith(color: colors.ink)
                  .jaWeight(FontWeight.w900),
            ),
          ),
          const SizedBox(height: GameTokens.spaceXs),
          Text(
            '${snapshot.weekStart} 〜 ${snapshot.weekEnd}',
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
            '名前や公開participant IDはありません。表示行は、参加した実在端末の分だけです。',
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
    final rank = standing.rank == null ? '順位なし' : '${standing.rank}位';
    final participant = standing.isMe ? '自分' : '匿名の参加者 ${index + 1}';
    final tied = standing.tied ? '、同順位' : '';
    return Semantics(
      container: true,
      label: '$rank、$participant、${standing.xp} XP$tied',
      child: ExcludeSemantics(
        child: Container(
          key: ValueKey('lan-social-standing-$index'),
          padding: const EdgeInsets.symmetric(vertical: GameTokens.spaceXs),
          color: standing.isMe ? colors.surfaceRaised : Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$rank  $participant${standing.tied ? '（同順位）' : ''}',
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: colors.ink)
                    .jaWeight(
                      standing.isMe ? FontWeight.w900 : FontWeight.w700,
                    ),
              ),
              const SizedBox(height: GameTokens.spaceXs),
              Text(
                '${standing.xp} XP',
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
              '昇格・降格の履歴',
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
        label: '昇格',
      ),
      LanSocialLeagueMovement.stayed => (
        icon: Icons.horizontal_rule_outlined,
        label: '維持',
      ),
      LanSocialLeagueMovement.demoted => (
        icon: Icons.arrow_downward_outlined,
        label: '降格',
      ),
    };
    return Semantics(
      label:
          '${week.weekStart}の週、${week.previousTier.label}から${week.tier.label}へ${movement.label}',
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
                      '${movement.label}：${week.previousTier.label} → ${week.tier.label}',
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
    return Semantics(
      label: '${tier.label}${current ? '、現在' : ''}',
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
            tier.label,
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
        '接続先はprivate/loopback HTTPSのIP、fingerprintは64桁のSHA-256を入力してください。',
        isError: true,
      );
      return;
    }
    final adminKey = _coordinatorKey.text;
    if (adminKey.length < 32) {
      _setMessage('管理キーを確認してください。参加コードとは別の値です。', isError: true);
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
      _setMessage('部屋を作れませんでした。管理キー、証明書、同じWi-Fiへの接続を確認してください。', isError: true);
      return;
    }
    final code = client.connectionCodeFor(room).encode();
    setState(() {
      _busy = false;
      _explicitOptIn = false;
      _createdCode = code;
      _message = '参加者用コードを作りました。管理キーは含まれていません。';
      _messageIsError = false;
    });
  }

  Future<void> _copyCode() async {
    final code = _createdCode;
    if (code == null) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('参加者用コードをコピーしました')));
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
      appBar: AppBar(title: const Text('LANの部屋を作る')),
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
                '管理キーは参加者へ渡しません',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(color: colors.ink)
                    .jaWeight(FontWeight.w900),
              ),
            ),
            const SizedBox(height: GameTokens.spaceSm),
            Text(
              'この設定は、管理PCでLAN coordinatorを起動した先生・保護者向けです。参加者用コードにはHTTPS接続先、証明書fingerprint、room inviteだけが入ります。',
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
                    decoration: const InputDecoration(
                      labelText: 'private HTTPS接続先',
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
                    decoration: const InputDecoration(
                      labelText: '証明書SHA-256 fingerprint',
                      hintText: '64桁の小文字hex',
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
                    decoration: const InputDecoration(
                      labelText: '管理キー',
                      helperText: '管理PCの画面から直接入力し、保存しません',
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
                '参加枠（5〜8人）',
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
                      label: '$value人',
                      child: SizedBox(
                        height: GameTokens.minTouchTarget,
                        child: _capacity == value
                            ? FilledButton(
                                key: ValueKey('lan-social-capacity-$value'),
                                onPressed: _busy
                                    ? null
                                    : () => setState(() => _capacity = value),
                                child: Text('$value人'),
                              )
                            : OutlinedButton(
                                key: ValueKey('lan-social-capacity-$value'),
                                onPressed: _busy
                                    ? null
                                    : () => setState(() => _capacity = value),
                                child: Text('$value人'),
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
              title: const Text('この管理PCに部屋情報を保存し、参加コードを発行することに同意します'),
              subtitle: const Text('氏名、回答、音声、端末IDを部屋情報として受け取りません'),
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
                label: Text(_busy ? '作成しています' : '参加者用コードを作る'),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: GameTokens.spaceLg),
              _LiveMessage(value: _message!, isError: _messageIsError),
            ],
            if (_createdCode != null) ...[
              const SizedBox(height: GameTokens.spaceLg),
              _Surface(
                semanticLabel: '参加者用コード。管理キーは含まれていません。',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '参加者用コード',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(color: colors.ink)
                          .jaWeight(FontWeight.w900),
                    ),
                    const SizedBox(height: GameTokens.spaceSm),
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
                        label: const Text('コードをコピー'),
                      ),
                    ),
                    const SizedBox(height: GameTokens.spaceSm),
                    Text(
                      '管理キーは構造上このコードへ入りません。コードをQR化する場合も、この文字列だけを使います。',
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
    final title = schoolMode ? '学校の端末内モードでは利用できません' : '通信しないモードでは利用できません';
    final body = schoolMode
        ? '現在の学校向け契約は、学校serverへ接続せず、入力も学習記録も送らないlocal-onlyです。LAN coordinatorへも参加資格、学習日、event hashを送信しません。'
        : 'LANの共同機能は、成人onlineモードで送信範囲へ明示同意した場合だけ利用できます。local-onlyでは接続先を作らず、何も送信しません。';
    return Scaffold(
      key: const ValueKey('lan-social-unavailable'),
      backgroundColor: colors.canvas,
      appBar: AppBar(title: const Text('いっしょに学ぶ')),
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
              semanticLabel: '$title。LANへの接続と送信はありません。',
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
  LanSocialClientError.optInRequired => '参加前の同意が必要です。',
  LanSocialClientError.invalidConnectionCode => '参加コードを確認してください。',
  LanSocialClientError.alreadyJoined => 'この種類の部屋にはすでに参加しています。',
  LanSocialClientError.roomNotFound => '部屋が見つかりません。',
  LanSocialClientError.roomExpired => 'この部屋は終了しています。',
  LanSocialClientError.roomFull => 'この部屋の参加枠は埋まっています。',
  LanSocialClientError.rateLimited => '試行回数の上限です。しばらく待ってください。',
  LanSocialClientError.unauthorized => '参加資格を確認できませんでした。',
  LanSocialClientError.schoolLeagueDisabled => '学校モードでは週次リーグに参加できません。',
  LanSocialClientError.wrongDay => '学習日の確認に失敗しました。',
  LanSocialClientError.invalidResponse => '安全な応答として確認できなかったため、参加しませんでした。',
  LanSocialClientError.notJoined ||
  LanSocialClientError.notMeaningful ||
  LanSocialClientError.unavailable ||
  null => '接続できませんでした。証明書と同じWi-Fiへの接続を確認してください。',
};
