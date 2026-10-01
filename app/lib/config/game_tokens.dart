import '../ui/_material.dart';

/// 学習世界「Field Notebook」の色。
///
/// 暖かな観察紙、実験器具の teal、標本ラベルの copper を基調にする。
/// 状態は色だけで表さず、探究ログ側で必ず形・アイコン・文言を併記する。
///
/// `pathActive` などの旧名は保存値や画面実装を一斉に改名しないために維持し、
/// 新しい画面では [action] など、用途を表す別名を使う。
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

  /// 観察紙の背景。
  Color get paper => canvas;

  /// 標本や記録を置く実験台の面。
  Color get bench => surface;

  /// 一段持ち上げた記録面。
  Color get benchRaised => surfaceRaised;

  /// 次の観察へ進む操作。
  Color get action => pathActive;
  Color get onAction => onPathActive;

  /// 観察済み・根拠を確認済みの状態。
  Color get evidence => pathComplete;
  Color get onEvidence => onPathComplete;

  /// 再観察する項目。
  Color get revisit => pathReview;
  Color get onRevisit => onPathReview;

  /// まだ開いていない記録。
  Color get locked => pathLocked;
  Color get onLocked => onPathLocked;

  /// 理科事件簿などのケースファイル。
  Color get caseFile => story;
  Color get onCaseFile => onStory;

  /// ヒントなしで行う総合検証。
  Color get fieldTest => legendary;
  Color get onFieldTest => onLegendary;

  /// 学習日の連続記録。
  Color get continuity => streak;

  /// ひらめき結晶。
  Color get crystal => gem;

  /// 再試行に使える余力。
  Color get attempt => heart;
  Color get onAttempt => onHeart;

  static const light = GamePalette(
    canvas: Color(0xFFF6F3EA),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFE2F0F2),
    ink: Color(0xFF14252B),
    inkMuted: Color(0xFF465A62),
    border: Color(0xFFA5BEC2),
    pathActive: Color(0xFF006A73),
    onPathActive: Color(0xFFFFFFFF),
    pathComplete: Color(0xFF1D6B45),
    onPathComplete: Color(0xFFFFFFFF),
    pathReview: Color(0xFFA33C10),
    onPathReview: Color(0xFFFFFFFF),
    pathLocked: Color(0xFFD9DEDC),
    onPathLocked: Color(0xFF4A585A),
    story: Color(0xFF4F3A79),
    onStory: Color(0xFFFFFFFF),
    legendary: Color(0xFFA56800),
    onLegendary: Color(0xFF000000),
    // 連続記録・結晶・試行余力は本文色へ流用せず、短い値とアイコンに使う。
    streak: Color(0xFFB93E1B),
    gem: Color(0xFF334C9E),
    heart: Color(0xFFAD2E52),
    onHeart: Color(0xFFFFFFFF),
  );

  static const dark = GamePalette(
    canvas: Color(0xFF121719),
    surface: Color(0xFF192124),
    surfaceRaised: Color(0xFF232E31),
    ink: Color(0xFFF1EEE5),
    inkMuted: Color(0xFFB9C4C4),
    border: Color(0xFF465356),
    pathActive: Color(0xFF72CDD3),
    onPathActive: Color(0xFF082A2E),
    pathComplete: Color(0xFF8CC6A7),
    onPathComplete: Color(0xFF10251B),
    pathReview: Color(0xFFE3A175),
    onPathReview: Color(0xFF331A0C),
    pathLocked: Color(0xFF2E383A),
    onPathLocked: Color(0xFFC4CECE),
    story: Color(0xFFC6B2E1),
    onStory: Color(0xFF291A37),
    legendary: Color(0xFFE8C15B),
    onLegendary: Color(0xFF30260B),
    streak: Color(0xFFFFB088),
    gem: Color(0xFFAAB9E8),
    heart: Color(0xFFF095A6),
    onHeart: Color(0xFF390B15),
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

  /// Field Notebook は紙・罫線・標本枠で階層を作る。角丸を主役にしない。
  static const double radiusXs = 2;
  static const double radiusSm = 6;
  static const double radiusMd = 10;
  static const double radiusLg = 14;
  static const double radiusSheet = 18;
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
  static const double accentRuleWidth = 4;

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
