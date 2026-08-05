import 'dart:convert';

import 'session_store.dart';

/// 同意の版。**文面を変えたら必ず上げる。**
///
/// 上げると、すでに同意した人にもう一度出る。
/// 上げ忘れると、古い文面にしか同意していない人を「同意済み」として扱うことになる。
const int kConsentVersion = 2;

/// 同意を**誰が**与えたか。
///
/// ## なぜ分けるのか
///
/// 生徒が自分で使う場合と、学校が配って使う場合とで、
/// 同意を取る相手も、取る手段も違う。
///
/// - 個人利用: 端末の前にいる本人（16歳未満なら保護者が横にいる前提）
/// - 学校利用: **保護者が紙に署名し、学校が保管している。**
///   生徒の端末で「保護者に確認しました」を押させるのは意味がない。
///   押したのは生徒であって保護者ではないし、学校はすでに書面を持っている
///
/// 学校経由のときに端末で自己申告させると、**紙の同意より弱い記録で上書きしてしまう。**
/// だから経路そのものを分ける。
enum ConsentRoute {
  /// 生徒（または保護者）が端末で同意した
  self,

  /// 学校が保護者から書面で同意を取り、学校が配布した
  school;

  static ConsentRoute parse(Object? v) =>
      v == 'school' ? ConsentRoute.school : ConsentRoute.self;

  String get wire => name;
}

/// 越境移転で伝えるべき3点（個人情報保護法 28条／規則17条）。
///
/// 「海外に送信されることがあります」だけでは足りない。
/// **国名・その国の制度・移転先の措置**を実際に表示する必要がある。
///
/// > [!warning] 文面の最終確認は受けていない
/// > 公開前に専門家に見てもらうこと。ここにあるのは
/// > 「何を表示すべきか」の実装であって、文面の保証ではない。
const List<(String, String)> kTransferDisclosure = [
  (
    '① どこへ送られるか',
    'アメリカ合衆国です。Google のサーバーで処理されます。',
  ),
  (
    '② その国のきまり',
    'アメリカには、日本の個人情報保護法にあたる国全体の法律がありません。'
        '州ごとのきまりと、分野ごとの法律があります。'
        '日本と同じしくみではない、と考えてください。',
  ),
  (
    '③ 送り先が守っていること',
    'Google は、データの取り扱いについて EU が認めた標準契約条項を結び、'
        '暗号化して送受信し、保存する場所と期間を定めています。'
        '詳しくは Google のプライバシーポリシーで公開されています。',
  ),
];

/// 年齢の帯。**生年月日は聞かない。**
///
/// 必要なのは「16歳未満かどうか」だけで、生年月日はそれより強い個人情報。
/// 要らないものを集めない。
enum AgeBand {
  under16,
  from16to17,
  adult;

  String get label => switch (this) {
        AgeBand.under16 => '15歳以下',
        AgeBand.from16to17 => '16〜17歳',
        AgeBand.adult => '18歳以上',
      };

  static AgeBand? parse(Object? v) => switch (v) {
        'under16' => AgeBand.under16,
        'from16to17' => AgeBand.from16to17,
        'adult' => AgeBand.adult,
        // 知らない値を adult に落とさない。**保護が要る側に倒す**
        _ => null,
      };

  String get wire => name;
}

/// 同意の記録。端末に残す。
class ConsentRecord {
  const ConsentRecord({
    required this.ageBand,
    required this.guardianPresent,
    required this.transferAgreed,
    required this.agreedAt,
    required this.version,
    this.route = ConsentRoute.self,
    this.schoolCode,
  });

  final AgeBand ageBand;

  /// 16歳未満のときだけ意味がある。それ以外は null。
  /// **学校経由では使わない**（紙の同意があるので端末で自己申告させない）
  final bool? guardianPresent;

  final bool transferAgreed;
  final DateTime agreedAt;
  final int version;

  /// 誰が同意を与えたか
  final ConsentRoute route;

  /// 学校経由のときの合言葉。**どの学校かを識別するためのものではない。**
  /// 「学校から配られた人だけが学校の経路に入る」ための鍵
  final String? schoolCode;

  /// この記録で先へ進んでよいか。
  ///
  /// **読み出すたびに判定する。** 「同意済みフラグ」を1つ持つ形にすると、
  /// 版を上げたときや条件を足したときに、古い記録が通り続ける。
  bool get isValid {
    if (!transferAgreed) return false;
    if (version != kConsentVersion) return false;
    switch (route) {
      case ConsentRoute.self:
        // 15歳以下は保護者の確認が要る（改正個情法40条の2／現行もQ&Aの運用）
        if (ageBand == AgeBand.under16 && guardianPresent != true) return false;
      case ConsentRoute.school:
        // 保護者の同意書は学校が持っている。端末側では合言葉だけを見る
        if (schoolCode == null || schoolCode!.isEmpty) return false;
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
        'ageBand': ageBand.wire,
        'guardianPresent': guardianPresent,
        'transferAgreed': transferAgreed,
        'agreedAt': agreedAt.toIso8601String(),
        'version': version,
        'route': route.wire,
        'schoolCode': schoolCode,
      };

  static ConsentRecord? fromJson(Map<String, dynamic> json) {
    final band = AgeBand.parse(json['ageBand']);
    if (band == null) return null;
    final at = DateTime.tryParse(json['agreedAt'] as String? ?? '');
    if (at == null) return null;
    return ConsentRecord(
      ageBand: band,
      guardianPresent: json['guardianPresent'] as bool?,
      transferAgreed: json['transferAgreed'] == true,
      agreedAt: at,
      version: (json['version'] as num?)?.toInt() ?? 0,
      route: ConsentRoute.parse(json['route']),
      schoolCode: json['schoolCode'] as String?,
    );
  }
}

/// 同意の保管。
class ConsentStore {
  const ConsentStore(this._store);

  final SessionStore _store;

  static const _key = 'consent';

  Future<ConsentRecord?> load() async {
    final raw = await _store.getSetting(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return ConsentRecord.fromJson(
          (jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      // 壊れていたら「同意していない」に倒す。通す方に倒さない
      return null;
    }
  }

  Future<void> save(ConsentRecord record) =>
      _store.setSetting(_key, jsonEncode(record.toJson()));

  Future<void> clear() => _store.setSetting(_key, null);
}
