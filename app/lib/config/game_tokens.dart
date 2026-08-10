import '../ui/_material.dart';

/// 学習世界「Orbit Lab」の色。
///
/// Duolingo の緑を写すのではなく、理科の観察・軌道・実験器具を連想する
/// cobalt / teal / violet を中心にする。状態は色だけで表さず、Path 側で必ず
/// 形・アイコン・文言を併記する。
@immutable
class GamePalette extends ThemeExtension<GamePalette> {
  const GamePalette({
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.ink,
    required this.inkMuted,
    required this.border,
    required this.pathActive,
    required this.onPathActive,
    required this.pathComplete,
    required this.onPathComplete,
    required this.pathReview,
    required this.onPathReview,
    required this.pathLocked,
    required this.onPathLocked,
    required this.story,
    required this.onStory,
    required this.legendary,
    required this.onLegendary,
    required this.streak,
    required this.gem,
    required this.heart,
    required this.onHeart,
  });

  final Color canvas;
  final Color surface;
  final Color surfaceRaised;
  final Color ink;
  final Color inkMuted;
  final Color border;
  final Color pathActive;
  final Color onPathActive;
  final Color pathComplete;
  final Color onPathComplete;
  final Color pathReview;
  final Color onPathReview;
  final Color pathLocked;
  final Color onPathLocked;
  final Color story;
  final Color onStory;
  final Color legendary;
  final Color onLegendary;
  final Color streak;
  final Color gem;
  final Color heart;
  final Color onHeart;

  static const light = GamePalette(
    canvas: Color(0xFFF7F9FF),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFEEF3FF),
    ink: Color(0xFF17223A),
    inkMuted: Color(0xFF59657A),
    border: Color(0xFFD7DEEA),
    pathActive: Color(0xFF2457D6),
    onPathActive: Color(0xFFFFFFFF),
    pathComplete: Color(0xFF167344),
    onPathComplete: Color(0xFFFFFFFF),
    pathReview: Color(0xFF006D71),
    onPathReview: Color(0xFFFFFFFF),
    pathLocked: Color(0xFFDCE3ED),
    onPathLocked: Color(0xFF59657A),
    story: Color(0xFF7046C8),
    onStory: Color(0xFFFFFFFF),
    legendary: Color(0xFFF2B705),
    onLegendary: Color(0xFF2B2100),
    // 明るい橙・紫・赤を白背景の本文色へ流用しない。ここでは大きな
    // アイコンと短い数字だけに使い、意味はSemanticsでも返す。
    streak: Color(0xFFA84B00),
    gem: Color(0xFF7046C8),
    heart: Color(0xFFB73552),
    onHeart: Color(0xFFFFFFFF),
  );

  static const dark = GamePalette(
    canvas: Color(0xFF101522),
    surface: Color(0xFF171D2B),
    surfaceRaised: Color(0xFF20283A),
    ink: Color(0xFFF5F7FC),
    inkMuted: Color(0xFFB8C0D3),
    border: Color(0xFF3B465C),
    pathActive: Color(0xFF89A9FF),
    onPathActive: Color(0xFF0B1C48),
    pathComplete: Color(0xFF6BD396),
    onPathComplete: Color(0xFF082718),
    pathReview: Color(0xFF63D1D4),
    onPathReview: Color(0xFF062A2C),
    pathLocked: Color(0xFF313B4E),
    onPathLocked: Color(0xFFC0C8D8),
    story: Color(0xFFC0A1FF),
    onStory: Color(0xFF251346),
    legendary: Color(0xFFFFD35A),
    onLegendary: Color(0xFF2B2100),
    streak: Color(0xFFFFA766),
    gem: Color(0xFFC0A1FF),
    heart: Color(0xFFFF91A7),
    onHeart: Color(0xFF3B0715),
  );

  @override
  GamePalette copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceRaised,
    Color? ink,
    Color? inkMuted,
    Color? border,
    Color? pathActive,
    Color? onPathActive,
    Color? pathComplete,
    Color? onPathComplete,
    Color? pathReview,
    Color? onPathReview,
    Color? pathLocked,
    Color? onPathLocked,
    Color? story,
    Color? onStory,
    Color? legendary,
    Color? onLegendary,
    Color? streak,
    Color? gem,
    Color? heart,
    Color? onHeart,
  }) => GamePalette(
    canvas: canvas ?? this.canvas,
    surface: surface ?? this.surface,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    ink: ink ?? this.ink,
    inkMuted: inkMuted ?? this.inkMuted,
    border: border ?? this.border,
    pathActive: pathActive ?? this.pathActive,
    onPathActive: onPathActive ?? this.onPathActive,
    pathComplete: pathComplete ?? this.pathComplete,
    onPathComplete: onPathComplete ?? this.onPathComplete,
    pathReview: pathReview ?? this.pathReview,
    onPathReview: onPathReview ?? this.onPathReview,
    pathLocked: pathLocked ?? this.pathLocked,
    onPathLocked: onPathLocked ?? this.onPathLocked,
    story: story ?? this.story,
    onStory: onStory ?? this.onStory,
    legendary: legendary ?? this.legendary,
    onLegendary: onLegendary ?? this.onLegendary,
    streak: streak ?? this.streak,
    gem: gem ?? this.gem,
    heart: heart ?? this.heart,
    onHeart: onHeart ?? this.onHeart,
  );

  @override
  GamePalette lerp(ThemeExtension<GamePalette>? other, double t) {
    if (other is! GamePalette) return this;
    return GamePalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      pathActive: Color.lerp(pathActive, other.pathActive, t)!,
      onPathActive: Color.lerp(onPathActive, other.onPathActive, t)!,
      pathComplete: Color.lerp(pathComplete, other.pathComplete, t)!,
      onPathComplete: Color.lerp(onPathComplete, other.onPathComplete, t)!,
      pathReview: Color.lerp(pathReview, other.pathReview, t)!,
      onPathReview: Color.lerp(onPathReview, other.onPathReview, t)!,
      pathLocked: Color.lerp(pathLocked, other.pathLocked, t)!,
      onPathLocked: Color.lerp(onPathLocked, other.onPathLocked, t)!,
      story: Color.lerp(story, other.story, t)!,
      onStory: Color.lerp(onStory, other.onStory, t)!,
      legendary: Color.lerp(legendary, other.legendary, t)!,
      onLegendary: Color.lerp(onLegendary, other.onLegendary, t)!,
      streak: Color.lerp(streak, other.streak, t)!,
      gem: Color.lerp(gem, other.gem, t)!,
      heart: Color.lerp(heart, other.heart, t)!,
      onHeart: Color.lerp(onHeart, other.onHeart, t)!,
    );
  }
}

abstract final class GameTokens {
  static const double spaceXs = 4;
  static const double spaceSm = 8;
  static const double spaceMd = 12;
  static const double spaceLg = 16;
  static const double spaceXl = 24;
  static const double spaceXxl = 32;

  static const double radiusSm = 10;
  static const double radiusMd = 16;
  static const double radiusLg = 22;
  static const double radiusSheet = 28;
  static const double radiusPill = 999;

  static const double minTouchTarget = 48;
  static const double pathNodeSize = 72;
  static const double pathNodeHitSize = 88;
  static const double pathRowHeight = 124;
  static const double readablePathWidth = 600;

  /// Path 以外のゲームハブ画面で使う本文幅。
  ///
  /// League / Profile がタブレット幅いっぱいへ伸びると、同じゲーム内なのに
  /// 管理画面のような密度になる。主役の面と補助情報を一つの列として読める幅で
  /// 止め、700dp 以上では周囲の余白を広げる。
  static const double gamePageMaxWidth = 720;
  static const double gameSheetMaxWidth = 640;
  static const double gamePageBottomPadding = 40;
  static const double heroLeadingSize = 72;
  static const double heroMascotSize = 64;
  static const double heroIconSize = 36;
  static const double compactAvatarSize = 40;
  static const double countControlLabelWidth = 88;
  static const double metricMinWidth = 120;
  static const double progressTrackHeight = 12;
  static const double compactProgressTrackHeight = 8;
  static const double heroTitleLineHeight = 1.35;
  static const double hubTileMinHeight = 96;
  static const double statusIconSize = 18;
  static const double strongBorderWidth = 2;

  /// Themeへ接続する前でも新画面を単独テストできるフォールバック。
  static GamePalette paletteOf(BuildContext context) =>
      Theme.of(context).extension<GamePalette>() ??
      (Theme.of(context).brightness == Brightness.dark
          ? GamePalette.dark
          : GamePalette.light);
}

extension GamePaletteX on BuildContext {
  GamePalette get gamePalette => GameTokens.paletteOf(this);
}
