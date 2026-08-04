import 'dart:convert';

import 'session_store.dart';

/// 同意の版。**文面を変えたら必ず上げる。**
///
/// 上げると、すでに同意した人にもう一度出る。
/// 上げ忘れると、古い文面にしか同意していない人を「同意済み」として扱うことになる。
const int kConsentVersion = 1;

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
  });

  final AgeBand ageBand;

  /// 16歳未満のときだけ意味がある。それ以外は null
  final bool? guardianPresent;

  final bool transferAgreed;
  final DateTime agreedAt;
  final int version;

  /// この記録で先へ進んでよいか。
  ///
  /// **読み出すたびに判定する。** 「同意済みフラグ」を1つ持つ形にすると、
  /// 版を上げたときや条件を足したときに、古い記録が通り続ける。
  bool get isValid {
    if (!transferAgreed) return false;
    if (version != kConsentVersion) return false;
    if (ageBand == AgeBand.under16 && guardianPresent != true) return false;
    return true;
  }

  Map<String, dynamic> toJson() => {
        'ageBand': ageBand.wire,
        'guardianPresent': guardianPresent,
        'transferAgreed': transferAgreed,
        'agreedAt': agreedAt.toIso8601String(),
        'version': version,
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
