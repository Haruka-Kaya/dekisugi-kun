/// 実参加者の週次順位からだけ動かす、端末内league共通ladder。
///
/// 成人LANと端末手渡しlocalで、表示名と±1段の規則を分岐させない。
/// 得点の単位はLANではXP、localではmeaningful event件数だが、昇降格に
/// 使うのは唯一1位・唯一最下位・同率という順位関係だけ。
library;

import '../config/app_language.dart';

enum LanSocialLeagueTier {
  bronze('ブロンズ', 'Bronze'),
  silver('シルバー', 'Silver'),
  gold('ゴールド', 'Gold'),
  sapphire('サファイア', 'Sapphire'),
  ruby('ルビー', 'Ruby'),
  emerald('エメラルド', 'Emerald'),
  amethyst('アメジスト', 'Amethyst'),
  pearl('パール', 'Pearl'),
  obsidian('オブシディアン', 'Obsidian'),
  diamond('ダイヤモンド', 'Diamond');

  const LanSocialLeagueTier(this._labelJa, this._labelEn);

  final String _labelJa;
  final String _labelEn;
  String get label => t(_labelJa, _labelEn);
  String get wire => name;

  LanSocialLeagueTier get promoted =>
      index >= values.length - 1 ? this : values[index + 1];
  LanSocialLeagueTier get demoted => index <= 0 ? this : values[index - 1];

  static LanSocialLeagueTier? parse(Object? value) {
    for (final tier in values) {
      if (tier.wire == value) return tier;
    }
    return null;
  }
}

/// 保存済みの宝石名やwire値を変えず、探究ノートUIだけで使う表示名。
extension LanSocialLeagueTierDisplay on LanSocialLeagueTier {
  String get displayLabel => '観測級${(index + 1).toString().padLeft(2, '0')}';
}

enum LanSocialLeagueMovement {
  promoted,
  stayed,
  demoted;

  String get wire => name;

  static LanSocialLeagueMovement? parse(Object? value) {
    for (final movement in values) {
      if (movement.wire == value) return movement;
    }
    return null;
  }
}

final class LeagueTierTransition {
  const LeagueTierTransition({
    required this.previousTier,
    required this.tier,
    required this.movement,
  });

  final LanSocialLeagueTier previousTier;
  final LanSocialLeagueTier tier;
  final LanSocialLeagueMovement movement;
}

/// 5〜8人の実参加者順位を、最大±1段のtier遷移へ変換する。
///
/// - 唯一1位かつ得点あり: +1
/// - 唯一最下位: -1
/// - 同率または全員0件（rank null）: 据置
/// - Bronze / Diamond端: 据置
LeagueTierTransition resolveLeagueTierTransition({
  required LanSocialLeagueTier previousTier,
  required int? rank,
  required bool tied,
  required int participantCount,
  required int score,
}) {
  if (participantCount < 5 || participantCount > 8) {
    throw ArgumentError.value(
      participantCount,
      'participantCount',
      '5 to 8 actual participants required',
    );
  }
  if (score < 0 ||
      (rank != null && (rank < 1 || rank > participantCount)) ||
      (rank == null && (score != 0 || tied))) {
    throw ArgumentError('invalid weekly league standing');
  }

  var tier = previousTier;
  if (rank == 1 && !tied && score > 0) {
    tier = previousTier.promoted;
  } else if (rank == participantCount && !tied) {
    tier = previousTier.demoted;
  }
  final movement = tier.index > previousTier.index
      ? LanSocialLeagueMovement.promoted
      : tier.index < previousTier.index
      ? LanSocialLeagueMovement.demoted
      : LanSocialLeagueMovement.stayed;
  return LeagueTierTransition(
    previousTier: previousTier,
    tier: tier,
    movement: movement,
  );
}

bool isValidLeagueTierTransition({
  required LanSocialLeagueTier previousTier,
  required LanSocialLeagueTier tier,
  required LanSocialLeagueMovement movement,
}) => switch (movement) {
  LanSocialLeagueMovement.promoted => tier.index == previousTier.index + 1,
  LanSocialLeagueMovement.stayed => tier == previousTier,
  LanSocialLeagueMovement.demoted => tier.index + 1 == previousTier.index,
};
