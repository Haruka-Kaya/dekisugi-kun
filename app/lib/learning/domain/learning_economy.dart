/// 端末内ジェム経済の固定カタログ。
///
/// UIから価格や任意の商品IDを渡して残高を減らさない。保存層はこのカタログを
/// 正本として再照合し、学習の完了・XP・正答を商品へ追加できない構造にする。
library;

import '../../config/app_language.dart';

enum LearningCosmeticSlot {
  pathMascot;

  String get wire => name;

  static LearningCosmeticSlot? parse(Object? value) => switch (value) {
    'pathMascot' => LearningCosmeticSlot.pathMascot,
    _ => null,
  };
}

enum LearningPathMascotStyle {
  standard,
  orbit,
  nova,
  aurora;

  String get wire => name;

  static LearningPathMascotStyle? parse(Object? value) => switch (value) {
    'standard' => LearningPathMascotStyle.standard,
    'orbit' => LearningPathMascotStyle.orbit,
    'nova' => LearningPathMascotStyle.nova,
    'aurora' => LearningPathMascotStyle.aurora,
    _ => null,
  };

  String get label => switch (this) {
    LearningPathMascotStyle.standard => t('いつものデキすぎ君', 'Classic Dekisugi-kun'),
    LearningPathMascotStyle.orbit => t(
      '軌道リングのデキすぎ君',
      'Orbit Ring Dekisugi-kun',
    ),
    LearningPathMascotStyle.nova => t(
      '星雲スーツのデキすぎ君',
      'Nebula Suit Dekisugi-kun',
    ),
    LearningPathMascotStyle.aurora => t(
      'オーロラマントのデキすぎ君',
      'Aurora Cape Dekisugi-kun',
    ),
  };
}

final class LearningCosmeticProduct {
  const LearningCosmeticProduct({
    required this.productId,
    required this.title,
    required this.titleEn,
    required this.description,
    required this.descriptionEn,
    required this.slot,
    required this.mascotStyle,
    required this.gemCost,
    this.requiresPlusAccess = false,
  }) : assert(gemCost >= 0);

  final String productId;
  final String title;
  final String titleEn;
  final String description;
  final String descriptionEn;
  final LearningCosmeticSlot slot;
  final LearningPathMascotStyle mascotStyle;
  final int gemCost;

  /// Plus entitlement でのみ受け取れる特典。結晶では売らない。
  final bool requiresPlusAccess;

  bool get isDefault => gemCost == 0 && !requiresPlusAccess;
}

final class LearningChallengePassProduct {
  const LearningChallengePassProduct({
    required this.productId,
    required this.title,
    required this.description,
    required this.gemCost,
  }) : assert(gemCost > 0);

  final String productId;
  final String title;
  final String description;
  final int gemCost;
}

/// personal scopeだけが持てる、購入済み見た目と現在の装備。
///
/// 購入済みIDと装備IDだけを保存し、色値や自由入力を永続化しない。
final class LearningCosmeticState {
  const LearningCosmeticState({
    required this.ownedProductIds,
    required this.equippedPathMascotId,
  });

  const LearningCosmeticState.initial()
    : ownedProductIds = const {SafeLearningEconomyCatalogV1.standardMascotId},
      equippedPathMascotId = SafeLearningEconomyCatalogV1.standardMascotId;

  final Set<String> ownedProductIds;
  final String equippedPathMascotId;

  bool owns(String productId) => ownedProductIds.contains(productId);
}

final class LearningCosmeticPurchaseResult {
  const LearningCosmeticPurchaseResult({
    required this.applied,
    required this.productId,
    required this.remainingGems,
    required this.cosmetics,
  });

  final bool applied;
  final String productId;
  final int remainingGems;
  final LearningCosmeticState cosmetics;
}

final class LearningCosmeticEquipResult {
  const LearningCosmeticEquipResult({
    required this.changed,
    required this.cosmetics,
  });

  final bool changed;
  final LearningCosmeticState cosmetics;
}

final class LearningChallengePassPurchaseResult {
  const LearningChallengePassPurchaseResult({
    required this.applied,
    required this.productId,
    required this.learningDay,
    required this.remainingGems,
  });

  final bool applied;
  final String productId;
  final String learningDay;
  final int remainingGems;
}

/// launch時点で保存層とUIが共有するversionedカタログ。
///
/// - cosmeticは探究ノート用マスコットの描画だけを変える
/// - challenge passは任意の時間制画面への当日入場だけを許可する
/// - 学習node、証拠レベル、報酬、正答へ影響する商品を持たない
final class SafeLearningEconomyCatalogV1 {
  const SafeLearningEconomyCatalogV1();

  static const String standardMascotId = 'cosmetic.path-mascot.standard.v1';
  static const String orbitMascotId = 'cosmetic.path-mascot.orbit.v1';
  static const String novaMascotId = 'cosmetic.path-mascot.nova.v1';
  static const String auroraMascotId = 'cosmetic.path-mascot.aurora.v1';
  static const String timedDayPassId = 'challenge.timed.day-pass.v1';

  static const LearningCosmeticProduct standardMascot = LearningCosmeticProduct(
    productId: standardMascotId,
    title: 'いつものデキすぎ君',
    titleEn: 'Everyday Dekisugi-kun',
    description: '標準の探究ノート用マスコットです。いつでも選べます。',
    descriptionEn: 'The standard field-notebook mascot. Always available.',
    slot: LearningCosmeticSlot.pathMascot,
    mascotStyle: LearningPathMascotStyle.standard,
    gemCost: 0,
  );

  static const LearningCosmeticProduct orbitMascot = LearningCosmeticProduct(
    productId: orbitMascotId,
    title: '軌道リング',
    titleEn: 'Orbit Ring',
    description: 'デキすぎ君の周りを、小さな観測衛星が回る見た目です。',
    descriptionEn:
        'A look with a tiny observation satellite orbiting Dekisugi-kun.',
    slot: LearningCosmeticSlot.pathMascot,
    mascotStyle: LearningPathMascotStyle.orbit,
    gemCost: 4,
  );

  static const LearningCosmeticProduct novaMascot = LearningCosmeticProduct(
    productId: novaMascotId,
    title: '星雲スーツ',
    titleEn: 'Nebula Suit',
    description: '星の合図が付いた、紫の研究スーツの見た目です。',
    descriptionEn: 'A purple research suit marked with star signs.',
    slot: LearningCosmeticSlot.pathMascot,
    mascotStyle: LearningPathMascotStyle.nova,
    gemCost: 6,
  );

  static const LearningChallengePassProduct timedDayPass =
      LearningChallengePassProduct(
        productId: timedDayPassId,
        title: '今日のタイム挑戦券',
        description: '購入した学習日は、時間観察へ何度でも入れます。',
        gemCost: 1,
      );

  static const LearningCosmeticProduct auroraMascot = LearningCosmeticProduct(
    productId: auroraMascotId,
    title: 'オーロラマント',
    titleEn: 'Aurora Cape',
    description: 'Plusサポーターへの印。オーロラの光をまとった、夜空色のマントの見た目です。',
    descriptionEn:
        'A badge for Plus supporters: a night-sky cape wrapped in aurora light.',
    slot: LearningCosmeticSlot.pathMascot,
    mascotStyle: LearningPathMascotStyle.aurora,
    gemCost: 0,
    requiresPlusAccess: true,
  );

  static const List<LearningCosmeticProduct> cosmetics = [
    standardMascot,
    orbitMascot,
    novaMascot,
    auroraMascot,
  ];

  /// Plus entitlement が確認できたときに所有へ付ける特典一覧。
  static List<LearningCosmeticProduct> get plusCosmetics =>
      List.unmodifiable(cosmetics.where((item) => item.requiresPlusAccess));

  LearningCosmeticProduct cosmetic(String productId) {
    for (final product in cosmetics) {
      if (product.productId == productId) return product;
    }
    throw ArgumentError.value(
      productId,
      'productId',
      'unknown learning cosmetic product',
    );
  }

  LearningChallengePassProduct challengePass(String productId) {
    if (productId == timedDayPass.productId) return timedDayPass;
    throw ArgumentError.value(
      productId,
      'productId',
      'unknown learning challenge pass product',
    );
  }

  void validate() {
    final ids = <String>{};
    for (final product in cosmetics) {
      if (!_catalogIdPattern.hasMatch(product.productId) ||
          !ids.add(product.productId) ||
          product.title.trim().isEmpty ||
          product.description.trim().isEmpty ||
          (product.isDefault !=
              (product.productId == standardMascot.productId))) {
        throw StateError('invalid learning cosmetic catalog');
      }
    }
    final styles = cosmetics.map((item) => item.mascotStyle).toSet();
    if (styles.length != LearningPathMascotStyle.values.length ||
        cosmetics.where((item) => item.isDefault).length != 1 ||
        !_catalogIdPattern.hasMatch(timedDayPass.productId) ||
        ids.contains(timedDayPass.productId) ||
        timedDayPass.title.trim().isEmpty ||
        timedDayPass.description.trim().isEmpty ||
        timedDayPass.gemCost <= 0) {
      throw StateError('invalid learning economy catalog');
    }
  }
}

final RegExp _catalogIdPattern = RegExp(
  r'^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$',
);
