/// クラス・部活のチーム。
///
/// ## 個人を持ち込まない
///
/// サーバは名簿も個人別の内訳も返さないが、端末側にも**受け皿を作らない**。
/// 置き場が無ければ、将来サーバが誤って返しても画面に出しようがない。
///
/// 「やっていない人を可視化しない」は表示の配慮ではなく、
/// **通る場所を全部塞ぐ**ことで守る。
library;

import '../config/app_language.dart';

/// 参加しているチーム。端末に控えておく。
class TeamMembership {
  const TeamMembership({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, Object?> toJson() => {'id': id, 'name': name};

  static TeamMembership? fromJson(Map<String, dynamic>? json) {
    final id = json?['id'] as String?;
    final name = json?['name'] as String?;
    if (id == null || id.isEmpty) return null;
    return TeamMembership(id: id, name: name ?? '');
  }
}

/// チーム到達。**チーム単位で、個人には出ない。**
class Milestone {
  const Milestone({
    required this.key,
    required this.label,
    required this.reached,
  });

  final String key;
  final String label;
  final bool reached;
}

/// チームの合計。
///
/// > [!important] 人数が足りないうちは合計が来ない
/// > 2人のチームでは `teamTotal - myTotal` が相手1人の値そのものになる。
/// > サーバは5人未満で [total] を null にする。
/// > **0 で埋めないこと。** 0 は「誰もやっていない」という別の意味になる。
class TeamSummary {
  const TeamSummary({
    required this.pending,
    required this.name,
    required this.total,
    required this.myTotal,
    required this.memberCount,
    required this.periodStart,
    required this.periodEnd,
    required this.milestones,
  });

  /// 人数が足りず、まだ合計を出せない
  final bool pending;

  final String name;

  /// チーム全体。**[pending] のときは null**
  final int? total;

  final int myTotal;

  /// 5人単位に丸めた人数。**実人数ではない**
  final int memberCount;

  final String periodStart;
  final String periodEnd;
  final List<Milestone> milestones;

  /// 直近で到達したもの。無ければ null
  Milestone? get latestReached {
    Milestone? out;
    for (final m in milestones) {
      if (m.reached) out = m;
    }
    return out;
  }

  /// **知っているキーだけ読む。** 増えた欄は素通りして端末に入らない。
  ///
  /// 個人に関わるものをサーバが誤って返しても、ここに受け皿が無いので
  /// 画面まで到達しない。
  factory TeamSummary.fromJson(Map<String, dynamic> json) => TeamSummary(
    pending: json['state'] == 'pending',
    name: json['teamName'] as String? ?? '',
    total: (json['teamTotal'] as num?)?.toInt(),
    myTotal: (json['myTotal'] as num?)?.toInt() ?? 0,
    memberCount: (json['memberCount'] as num?)?.toInt() ?? 0,
    periodStart: json['periodStart'] as String? ?? '',
    periodEnd: json['periodEnd'] as String? ?? '',
    milestones: [
      for (final m in (json['milestones'] as List?) ?? const [])
        if (m is Map && m['key'] is String)
          Milestone(
            key: m['key'] as String,
            label: m['label'] as String? ?? '',
            reached: m['reached'] == true,
          ),
    ],
  );
}

/// 参加できなかった理由。**画面の文言を1か所に閉じる。**
enum JoinFailure {
  /// そのコードは無い
  unknownCode,

  /// 期限切れ・失効
  expired,

  /// すでに別のチームにいる
  inOtherTeam,

  /// 人数がいっぱい
  teamFull,

  /// 抜けた直後で、まだ入り直せない
  cooldown,

  network,
  unknown;

  static JoinFailure fromError(String? code, int? status) => switch (code) {
    'unknown_code' => JoinFailure.unknownCode,
    'expired' => JoinFailure.expired,
    'in_other_team' => JoinFailure.inOtherTeam,
    'team_full' => JoinFailure.teamFull,
    'cooldown' => JoinFailure.cooldown,
    _ => status == null ? JoinFailure.network : JoinFailure.unknown,
  };

  /// 生徒に見せる文。**責めない。次にやることを書く。**
  String get message => switch (this) {
    JoinFailure.unknownCode =>
      t(
        'そのコードは見つかりませんでした。'
            '打ち間違いがないか確かめてください。',
        "We couldn't find that code. Check for typos.",
      ),
    JoinFailure.expired =>
      t(
        'このコードは使えなくなっています。'
            '先生にもう一度もらってください。',
        'This code no longer works. Ask your teacher for a new one.',
      ),
    JoinFailure.inOtherTeam =>
      t(
        'すでに別のクラスに入っています。'
            '移るときは、先にいまのクラスから抜けてください。',
        "You're already in another class. To switch, leave your current class first.",
      ),
    JoinFailure.teamFull =>
      t(
        'このクラスは人数がいっぱいです。'
            '先生に伝えてください。',
        'This class is full. Please tell your teacher.',
      ),
    JoinFailure.cooldown =>
      t(
        'クラスを抜けたばかりです。'
            '入り直せるのは1週間後になります。',
        'You just left this class. You can rejoin in one week.',
      ),
    JoinFailure.network =>
      t(
        '通信できませんでした。'
            'つながるところでもう一度ためしてください。',
        "Couldn't connect. Try again where you have a connection.",
      ),
    JoinFailure.unknown =>
      t(
        'うまくいきませんでした。'
            'しばらくしてからもう一度ためしてください。',
        'Something went wrong. Please try again in a little while.',
      ),
  };
}
