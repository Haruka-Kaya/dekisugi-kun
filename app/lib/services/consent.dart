import 'dart:convert';

import 'session_store.dart';
import '../config/app_language.dart';

/// 同意の版。**文面を変えたら必ず上げる。**
///
/// 上げると、すでに同意した人にもう一度出る。
/// 上げ忘れると、古い文面にしか同意していない人を「同意済み」として扱うことになる。
const int kConsentVersion = 5;

/// どの利用経路で必要な手続を確認したか。
///
/// ## なぜ分けるのか
///
/// 生徒が自分で使う場合と、学校が配って使う場合とで、
/// 同意を取る相手も、取る手段も違う。
///
/// - 個人利用: 端末の前にいる本人（現在は18歳以上のみ利用可能）
/// - 学校利用: 学校が必要な手続を別途確認・管理する経路。
///   生徒の端末で「保護者に確認しました」を押させても、その記録の代わりにはならない
///
/// 学校経由のときに端末で自己申告させると、**学校側の記録より弱い情報で上書きしてしまう。**
/// だから経路そのものを分ける。
enum ConsentRoute {
  /// 生徒（または保護者）が端末で同意した
  self,

  /// 学校が必要な手続を確認し、学校向けに配布した
  school;

  static ConsentRoute? parse(Object? v) => switch (v) {
    'self' => ConsentRoute.self,
    'school' => ConsentRoute.school,
    // 未知値や欠落をselfへ倒すと、壊れた記録が成人個人の同意へ化ける。
    _ => null,
  };

  String get wire => name;
}

/// 外部サービスに送る情報。
///
/// Plus を使わない間は RevenueCat SDK を起動しない。
/// Plus 画面を開いたり、購入・復元したりする場面では、
/// 匿名IDであっても送信対象になることを隠さない。
List<(String, String)> get kExternalServiceDisclosure => [
  (
    t('Google（AI との会話）', 'Google (conversation with the AI)'),
    t(
      '声と、話したり入力したりした文字を、会話の処理のために送ります。',
      'Your voice and the text you speak or type are sent to process the conversation.',
    ),
  ),
  (
    t(
      '生成AIサービス（デキすぎ君の返事の文面）',
      "Generative AI service (wording of Dekisugi-kun's replies)",
    ),
    t(
      '説明を聞き終えたあとの返事の前置きを作るため、入力した説明文と'
          'そこから聞き取れた言葉、単元名を本アプリのサーバ経由で'
          '生成AIサービス（OpenAI または同等の提供元）へ送ります。'
          '送るのはその3点だけで、氏名・ID・声・選択肢や正解の文面は送りません。',
      'To write the opening of the reply after hearing your explanation, the '
          'explanation you typed, the words recognized from it, and the unit name '
          "are sent through this app's server to a generative AI service (OpenAI "
          'or an equivalent provider). Only these 3 items are sent. Your name, ID, '
          'voice, and the text of answer choices or correct answers are not sent.',
    ),
  ),
  (
    t('RevenueCat（Plus の購入管理）', 'RevenueCat (managing Plus purchases)'),
    t(
      'Plus 画面を開くなど SDK を使う場面で、端末ごとにアプリが作った匿名UUID、'
          '端末の種類とOS、最終利用時刻が送られることがあります。購入・復元時は、'
          'Apple のレシートまたは Google の購入トークンなどの取引情報も扱われ、'
          'Apple App Store または Google Play と連携します。',
      'When the SDK is used, such as when you open the Plus screen, an anonymous '
          'UUID created by the app for each device, the device type and OS, and the '
          'last time the app was used may be sent. When purchasing or restoring, '
          "transaction information such as Apple's receipt or Google's purchase "
          'token is also handled, in connection with the Apple App Store or '
          'Google Play.',
    ),
  ),
  (
    t('RevenueCat へ送らないもの', 'What is not sent to RevenueCat'),
    t(
      '氏名、メールアドレス、広告ID、会話の逐語、声のデータは RevenueCat へ送りません。',
      'Your name, email address, advertising ID, conversation transcripts, and '
          'voice data are not sent to RevenueCat.',
    ),
  ),
];

/// 越境処理について画面で表示する3点。
///
/// > [!warning] 文面の最終確認は受けていない
/// > 公開前に専門家に見てもらうこと。ここにあるのは
/// > 「何を表示すべきか」の実装であって、文面の保証ではない。
List<(String, String)> get kTransferDisclosure => [
  (
    t('① どこへ送られるか', '① Where the data is sent'),
    t(
      'アメリカ合衆国です。Google のサーバーで会話を処理します。'
          'RevenueCat の課金管理データは、米国の AWS に保存されると公開されています。',
      "The United States of America. Conversations are processed on Google's "
          'servers. RevenueCat has published that its billing management data is '
          'stored on AWS in the United States.',
    ),
  ),
  (
    t('② その国のきまり', "② That country's rules"),
    t(
      'アメリカには、日本の個人情報保護法にあたる国全体の法律がありません。'
          '州ごとのきまりと、分野ごとの法律があります。'
          '日本と同じしくみではない、と考えてください。',
      "The United States has no nationwide law equivalent to Japan's Act on "
          'the Protection of Personal Information. Instead, there are state rules '
          'and laws for specific sectors. Please understand that the system is '
          'not the same as in Japan.',
    ),
  ),
  (
    t('③ 送り先が守っていること', '③ What the recipients commit to'),
    t(
      'Google は、データの取り扱いについて EU が認めた標準契約条項を結び、'
          '暗号化して送受信し、保存する場所と期間を定めています。'
          'RevenueCat は本アプリから委託された処理者として課金管理データを扱い、'
          '通信に TLS を使うと公開しています。詳細は各社の公開資料で確認できます。',
      'For data handling, Google has entered into the Standard Contractual '
          'Clauses approved by the EU, encrypts data when sending and receiving '
          'it, and sets where and for how long data is stored. RevenueCat handles '
          'billing management data as a processor entrusted by this app, and has '
          'published that it uses TLS for communication. Details can be found in '
          "each company's public documentation.",
    ),
  ),
];

/// 年齢の帯。**生年月日は聞かない。**
///
/// 必要なのは年齢帯だけで、生年月日はそれより強い個人情報。
/// 要らないものを集めない。
enum AgeBand {
  under16,
  from16to17,
  adult;

  String get label => switch (this) {
    AgeBand.under16 => t('15歳以下', '15 or younger'),
    AgeBand.from16to17 => t('16〜17歳', '16–17'),
    AgeBand.adult => t('18歳以上', '18 or older'),
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
  /// **学校経由では使わない**（端末の自己申告を学校の記録の代わりにしない）
  final bool? guardianPresent;

  final bool transferAgreed;
  final DateTime agreedAt;
  final int version;

  /// 必要な手続を確認した利用経路
  final ConsentRoute route;

  /// 学校が案内した経路をサーバで確認したときの学校コード。
  /// **コード自体は、保護者同意や学校承認の証跡ではない。**
  final String? schoolCode;

  /// 学校経由の生徒へ、個人向けのアプリ内購入を案内しない。
  ///
  /// 学校利用の費用は学校との一括契約または無料枠で扱う。学校が同意を
  /// 管理している画面へ、別主体である生徒・保護者のStore購入を混ぜない。
  bool get allowsIndividualPurchases => route == ConsentRoute.self;

  /// 現在利用している生成AIサービスの提供条件に合わせた対象範囲。
  /// 学校向けと18歳未満は準備中のため、保存済み記録も会話へ通さない。
  bool get isCurrentlyEligible =>
      route == ConsentRoute.self && ageBand == AgeBand.adult;

  /// この記録で先へ進んでよいか。
  ///
  /// **読み出すたびに判定する。** 「同意済みフラグ」を1つ持つ形にすると、
  /// 版を上げたときや条件を足したときに、古い記録が通り続ける。
  bool get isValid {
    if (!transferAgreed) return false;
    if (version != kConsentVersion) return false;
    if (!isCurrentlyEligible) return false;
    switch (route) {
      case ConsentRoute.self:
        // 将来18歳未満へ提供するときの手続は、最新の規約・法務確認後に決める。
        if (ageBand == AgeBand.under16 && guardianPresent != true) return false;
      case ConsentRoute.school:
        // 学校コードのサーバ検証は保存前に行う。ここでは保存形式だけを検証する。
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
    final route = ConsentRoute.parse(json['route']);
    if (route == null) return null;
    final at = DateTime.tryParse(json['agreedAt'] as String? ?? '');
    if (at == null) return null;
    return ConsentRecord(
      ageBand: band,
      guardianPresent: json['guardianPresent'] as bool?,
      transferAgreed: json['transferAgreed'] == true,
      agreedAt: at,
      version: (json['version'] as num?)?.toInt() ?? 0,
      route: route,
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
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
    } catch (_) {
      // 壊れていたら「同意していない」に倒す。通す方に倒さない
      return null;
    }
  }

  Future<void> save(ConsentRecord record) async {
    // 書き込み側も同じ契約で閉じる。無効な値で、すでに保存済みの有効な
    // 同意を上書きしない。
    if (!record.isValid) {
      throw StateError('invalid consent record');
    }
    await _store.setSetting(_key, jsonEncode(record.toJson()));
  }

  Future<void> clear() => _store.setSetting(_key, null);
}
