import 'package:dekisugi/models/league_ladder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BronzeからDiamondの10段ラベルを成人LANとlocalで共用する', () {
    expect(LanSocialLeagueTier.values.map((tier) => tier.label), [
      'ブロンズ',
      'シルバー',
      'ゴールド',
      'サファイア',
      'ルビー',
      'エメラルド',
      'アメジスト',
      'パール',
      'オブシディアン',
      'ダイヤモンド',
    ]);
  });

  test('唯一1位・最下位だけ±1段で、同率・0件・ladder端は据置', () {
    final promoted = resolveLeagueTierTransition(
      previousTier: LanSocialLeagueTier.gold,
      rank: 1,
      tied: false,
      participantCount: 5,
      score: 3,
    );
    expect(promoted.tier, LanSocialLeagueTier.sapphire);
    expect(promoted.movement, LanSocialLeagueMovement.promoted);

    final demoted = resolveLeagueTierTransition(
      previousTier: LanSocialLeagueTier.gold,
      rank: 5,
      tied: false,
      participantCount: 5,
      score: 1,
    );
    expect(demoted.tier, LanSocialLeagueTier.silver);
    expect(demoted.movement, LanSocialLeagueMovement.demoted);

    for (final stayed in [
      resolveLeagueTierTransition(
        previousTier: LanSocialLeagueTier.gold,
        rank: 1,
        tied: true,
        participantCount: 5,
        score: 3,
      ),
      resolveLeagueTierTransition(
        previousTier: LanSocialLeagueTier.gold,
        rank: 4,
        tied: true,
        participantCount: 5,
        score: 1,
      ),
      resolveLeagueTierTransition(
        previousTier: LanSocialLeagueTier.gold,
        rank: null,
        tied: false,
        participantCount: 5,
        score: 0,
      ),
      resolveLeagueTierTransition(
        previousTier: LanSocialLeagueTier.diamond,
        rank: 1,
        tied: false,
        participantCount: 5,
        score: 3,
      ),
      resolveLeagueTierTransition(
        previousTier: LanSocialLeagueTier.bronze,
        rank: 5,
        tied: false,
        participantCount: 5,
        score: 1,
      ),
    ]) {
      expect(stayed.movement, LanSocialLeagueMovement.stayed);
    }
  });

  test('5人未満はtier遷移へ入れない', () {
    expect(
      () => resolveLeagueTierTransition(
        previousTier: LanSocialLeagueTier.bronze,
        rank: 1,
        tied: false,
        participantCount: 4,
        score: 1,
      ),
      throwsArgumentError,
    );
  });
}
