import '../ui/_material.dart';
import '../ui/adaptive.dart';
import 'game_tokens.dart';

/// 同梱している可変フォントの family 名（pubspec.yaml の `fonts:` と一致させる）。
///
/// `google_fonts` は使わない。あれは実行時にネットワークから取りに行くので、
/// 初回起動がオフラインだと和文が出ず、端末によって描画も変わる。
const String kFontFamily = 'NotoSansJP';

/// 和文本文の行高。
///
/// M3 の既定 1.43 は Noto Sans JP の自然行高 1.448em より小さく、
/// **和文には行間を1ミリも足していない**。読み物の分量が多いので自分で決める。
/// （`.claude/docs/flutter-app-ui-2026.md` の実測に基づく）
const double kBodyLineHeight = 1.7;

/// 可変フォントのウェイト軸を [TextStyle.fontWeight] から明示的に引く。
///
/// 同梱しているのは可変フォント1本なので、pubspec の `weight:` による
/// ファイル選択が使えない。`fontWeight` だけを渡したときエンジンが
/// wght 軸を動かすのか**合成太字（グリフを太らせる偽ボールド）**にするのかは
/// 環境依存で、`flutter test` では実在しない family でも同じ幅が返るため
/// 検証もできない（実測: 存在しない family と w400/w900 がすべて 528.0px）。
///
/// 依存しないのが正解。**軸の値を毎回書く。**
/// ウェイトを変えるときは `style.jaWeight(FontWeight.w700)` を使うこと。
extension JaTextStyle on TextStyle {
  TextStyle jaWeight(FontWeight w) => copyWith(
    fontWeight: w,
    fontVariations: [FontVariation('wght', w.value.toDouble())],
  );
}

/// TextTheme の全スタイルに、それぞれの fontWeight に対応する wght 軸を刻む。
TextTheme _pinWeightAxis(TextTheme t) {
  TextStyle? pin(TextStyle? s) => s?.jaWeight(s.fontWeight ?? FontWeight.w400);
  return TextTheme(
    displayLarge: pin(t.displayLarge),
    displayMedium: pin(t.displayMedium),
    displaySmall: pin(t.displaySmall),
    headlineLarge: pin(t.headlineLarge),
    headlineMedium: pin(t.headlineMedium),
    headlineSmall: pin(t.headlineSmall),
    titleLarge: pin(t.titleLarge),
    titleMedium: pin(t.titleMedium),
    titleSmall: pin(t.titleSmall),
    bodyLarge: pin(t.bodyLarge),
    bodyMedium: pin(t.bodyMedium),
    bodySmall: pin(t.bodySmall),
    labelLarge: pin(t.labelLarge),
    labelMedium: pin(t.labelMedium),
    labelSmall: pin(t.labelSmall),
  );
}

/// 日本語の見出しだけ約物の余白を詰める。
///
/// Noto Sans JP では `palt` が実際に効き、「」、。を含む短い見出しが締まる。
/// 本文へ全面適用すると読みづらくなるため、display / headline / title に限定する。
TextTheme _tightenJapaneseHeadings(TextTheme t) {
  TextStyle? palt(TextStyle? s) =>
      s?.copyWith(fontFeatures: const <FontFeature>[FontFeature('palt')]);
  return t.copyWith(
    displayLarge: palt(t.displayLarge),
    displayMedium: palt(t.displayMedium),
    displaySmall: palt(t.displaySmall),
    headlineLarge: palt(t.headlineLarge),
    headlineMedium: palt(t.headlineMedium),
    headlineSmall: palt(t.headlineSmall),
    titleLarge: palt(t.titleLarge),
    titleMedium: palt(t.titleMedium),
    titleSmall: palt(t.titleSmall),
  );
}

/// アプリ共通のテーマ。基準は `.claude/docs/web-design-2026.md` と
/// `.claude/docs/flutter-app-ui-2026.md`。
///
/// 色を変えるときは、調査済みUI資料の適用範囲とコントラストを先に確認すること。
/// ここの値は sRGB 変換後に WCAG コントラスト比を計算して検証済みで、
/// 「なんとなく良さそう」で変えると基準を割る。
///
/// Liquid Glass とグラデーション背景は使わず、階層はソリッドな面・余白・
/// 必要最小限の境界線で作る。白い汎用カードの反復ではなく、会話・本人の言葉・
/// 補助導線ごとに役割の異なる面を使う。

/// 説明の結果を表す4状態。
///
/// デキすぎ君は「間違えること」が前提の製品なので、[weak] を失敗として扱わない。
/// 色そのものは attendance_app の検証済みパレットを流用するが、
/// **アイコンと文言で「次にやること」という枠組みに置き換える**（下記 [statusIcon]）。
enum ExplainStatus {
  /// 説明できた。誘導された誤概念を訂正できた
  gotIt,

  /// 説明はできたが、条件や理由が抜けている
  shaky,

  /// 訂正できなかった。**弱点＝復習に回すもの**。失敗ではない
  weak,

  /// まだ触れていない
  untouched,
}

/// Material の ColorScheme に無い、アプリ固有の役割色。
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.charBody,
    required this.charFace,
    required this.charAccent,
    required this.borderStrong,
    required this.highlightFlash,
    required this.gotItFg,
    required this.gotItChip,
    required this.shakyFg,
    required this.shakyChip,
    required this.weakFg,
    required this.weakChip,
    required this.untouchedFg,
    required this.untouchedChip,
    required this.heroSurface,
    required this.onHeroSurface,
    required this.heroMuted,
    required this.warmSurface,
    required this.onWarmSurface,
    required this.coolSurface,
    required this.onCoolSurface,
  });

  /// デキすぎ君の体。
  ///
  /// 4つの状態色（緑・橙・赤・灰）のどれとも重ならない色を使う。
  /// 重なると「キャラの色」と「理解の状態」の意味が混ざる。
  final Color charBody;

  /// 目。[charBody] の上で 3:1 以上（SC 1.4.11 — 意味を持つ図形）。
  final Color charFace;

  /// 房・耳など、状態を形で示す部分。
  final Color charAccent;

  /// 入力欄など「どこが操作対象か」を境界線で伝えるコントロール用。
  /// 装飾的な区切り線 (ColorScheme.outlineVariant) は 3:1 不要だが、
  /// こちらは SC 1.4.11 Non-text Contrast の 3:1 を満たす必要がある。
  final Color borderStrong;

  /// 「ここが更新された」等の一時的な強調。
  /// ステータス色を流用しない（状態と無関係な演出に状態の色を使うと意味が混ざる）。
  final Color highlightFlash;

  // 検証済みの状態色。前景はチップ上・ページ上とも 4.5:1 以上。
  final Color gotItFg, gotItChip;
  final Color shakyFg, shakyChip;
  final Color weakFg, weakChip;
  final Color untouchedFg, untouchedChip;

  /// ホームと会話の主役になる記録面。
  /// [buildAppTheme] では Field Notebook の中立な raised surface へ接続する。
  final Color heroSurface;
  final Color onHeroSurface;
  final Color heroMuted;

  /// 本人の言葉・教材の実験など、温度のある内容を置く面。
  final Color warmSurface;
  final Color onWarmSurface;

  /// 計画や補助導線を置く静かな面。
  final Color coolSurface;
  final Color onCoolSurface;

  static const light = AppColors(
    charBody: Color(0xFF5B62D6),
    charFace: Color(0xFFFFFFFF), // 体の上で 5.00:1
    charAccent: Color(0xFFFFC46B), // 体の上で 3.17:1
    borderStrong: Color(0xFF7A7C84), // warm canvas に対し 3:1 以上
    highlightFlash: Color(0xFFD8EBFB),
    gotItFg: Color(0xFF1D753A),
    gotItChip: Color(0xFFE9F6EB),
    shakyFg: Color(0xFF925A29),
    shakyChip: Color(0xFFFEEFE3),
    weakFg: Color(0xFFBA4643),
    weakChip: Color(0xFFFDECEA),
    untouchedFg: Color(0xFF696E7A),
    untouchedChip: Color(0xFFF0F2F4),
    heroSurface: Color(0xFF222B4F),
    onHeroSurface: Color(0xFFFFFFFF),
    heroMuted: Color(0xFFC6CDEA),
    warmSurface: Color(0xFFFFE7C6),
    onWarmSurface: Color(0xFF5B3518),
    coolSurface: Color(0xFFE3E8FF),
    onCoolSurface: Color(0xFF222B4F),
  );

  static const dark = AppColors(
    charBody: Color(0xFF6068DC),
    charFace: Color(0xFF14151A), // 体の上で 4.01:1
    charAccent: Color(0xFFFFD08A), // 体の上で 3.20:1
    borderStrong: Color(0xFF737789), // dark paper に対し 3:1 以上
    highlightFlash: Color(0xFF233849),
    gotItFg: Color(0xFF419B5A),
    gotItChip: Color(0xFF18271B),
    shakyFg: Color(0xFFB97C2B),
    shakyChip: Color(0xFF2D2011),
    weakFg: Color(0xFFDA645E),
    weakChip: Color(0xFF331C1A),
    untouchedFg: Color(0xFF838A96),
    untouchedChip: Color(0xFF212326),
    heroSurface: Color(0xFF252E5A),
    onHeroSurface: Color(0xFFF7F7FF),
    heroMuted: Color(0xFFC6CDEA),
    warmSurface: Color(0xFF3A2A1C),
    onWarmSurface: Color(0xFFFFE7C6),
    coolSurface: Color(0xFF202A4F),
    onCoolSurface: Color(0xFFDDE3FF),
  );

  /// 状態から前景色を引く。
  ///
  /// **未知の値は [ExplainStatus.untouched] に落とす。[weak] に落とさないこと** —
  /// 「まだ触れていない」と「直せなかった」は別の状態で、
  /// 取り違えると触れてもいない概念を弱点として突きつけることになる。
  Color fgFor(ExplainStatus s) => switch (s) {
    ExplainStatus.gotIt => gotItFg,
    ExplainStatus.shaky => shakyFg,
    ExplainStatus.weak => weakFg,
    ExplainStatus.untouched => untouchedFg,
  };

  Color chipFor(ExplainStatus s) => switch (s) {
    ExplainStatus.gotIt => gotItChip,
    ExplainStatus.shaky => shakyChip,
    ExplainStatus.weak => weakChip,
    ExplainStatus.untouched => untouchedChip,
  };

  @override
  AppColors copyWith({
    Color? charBody,
    Color? charFace,
    Color? charAccent,
    Color? borderStrong,
    Color? highlightFlash,
    Color? gotItFg,
    Color? gotItChip,
    Color? shakyFg,
    Color? shakyChip,
    Color? weakFg,
    Color? weakChip,
    Color? untouchedFg,
    Color? untouchedChip,
    Color? heroSurface,
    Color? onHeroSurface,
    Color? heroMuted,
    Color? warmSurface,
    Color? onWarmSurface,
    Color? coolSurface,
    Color? onCoolSurface,
  }) => AppColors(
    charBody: charBody ?? this.charBody,
    charFace: charFace ?? this.charFace,
    charAccent: charAccent ?? this.charAccent,
    borderStrong: borderStrong ?? this.borderStrong,
    highlightFlash: highlightFlash ?? this.highlightFlash,
    gotItFg: gotItFg ?? this.gotItFg,
    gotItChip: gotItChip ?? this.gotItChip,
    shakyFg: shakyFg ?? this.shakyFg,
    shakyChip: shakyChip ?? this.shakyChip,
    weakFg: weakFg ?? this.weakFg,
    weakChip: weakChip ?? this.weakChip,
    untouchedFg: untouchedFg ?? this.untouchedFg,
    untouchedChip: untouchedChip ?? this.untouchedChip,
    heroSurface: heroSurface ?? this.heroSurface,
    onHeroSurface: onHeroSurface ?? this.onHeroSurface,
    heroMuted: heroMuted ?? this.heroMuted,
    warmSurface: warmSurface ?? this.warmSurface,
    onWarmSurface: onWarmSurface ?? this.onWarmSurface,
    coolSurface: coolSurface ?? this.coolSurface,
    onCoolSurface: onCoolSurface ?? this.onCoolSurface,
  );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      charBody: Color.lerp(charBody, other.charBody, t)!,
      charFace: Color.lerp(charFace, other.charFace, t)!,
      charAccent: Color.lerp(charAccent, other.charAccent, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      highlightFlash: Color.lerp(highlightFlash, other.highlightFlash, t)!,
      gotItFg: Color.lerp(gotItFg, other.gotItFg, t)!,
      gotItChip: Color.lerp(gotItChip, other.gotItChip, t)!,
      shakyFg: Color.lerp(shakyFg, other.shakyFg, t)!,
      shakyChip: Color.lerp(shakyChip, other.shakyChip, t)!,
      weakFg: Color.lerp(weakFg, other.weakFg, t)!,
      weakChip: Color.lerp(weakChip, other.weakChip, t)!,
      untouchedFg: Color.lerp(untouchedFg, other.untouchedFg, t)!,
      untouchedChip: Color.lerp(untouchedChip, other.untouchedChip, t)!,
      heroSurface: Color.lerp(heroSurface, other.heroSurface, t)!,
      onHeroSurface: Color.lerp(onHeroSurface, other.onHeroSurface, t)!,
      heroMuted: Color.lerp(heroMuted, other.heroMuted, t)!,
      warmSurface: Color.lerp(warmSurface, other.warmSurface, t)!,
      onWarmSurface: Color.lerp(onWarmSurface, other.onWarmSurface, t)!,
      coolSurface: Color.lerp(coolSurface, other.coolSurface, t)!,
      onCoolSurface: Color.lerp(onCoolSurface, other.onCoolSurface, t)!,
    );
  }
}

/// 状態のアイコン。**色だけで状態を伝えない** (SC 1.4.1)。
/// 色 + アイコン形状 + テキストラベルの3点セットで1単位。
///
/// [ExplainStatus.weak] に ✗ や ! を使わない。
/// デキすぎ君では説明できないことが日常で、それは失敗ではなく
/// 「次に復習するもの」。しおりを挟む形にして枠組みを変える。
IconData statusIcon(ExplainStatus s) => switch (s) {
  ExplainStatus.gotIt => Icons.check_circle,
  ExplainStatus.shaky => Icons.contrast, // 半分だけ塗られた円
  ExplainStatus.weak => Icons.bookmark, // 「ここを覚えておく」
  ExplainStatus.untouched => Icons.circle_outlined,
};

/// 状態のラベル。アイコンと必ずセットで出す。
String statusLabel(ExplainStatus s) => switch (s) {
  ExplainStatus.gotIt => '説明できた',
  ExplainStatus.shaky => 'あと少し',
  ExplainStatus.weak => 'ここを復習',
  ExplainStatus.untouched => 'まだ',
};

/// 拡張色への短縮アクセス。`final c = context.appColors;`
extension AppColorsX on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final gamePalette = isDark ? GamePalette.dark : GamePalette.light;
  final legacyColors = isDark ? AppColors.dark : AppColors.light;
  final appColors = legacyColors.copyWith(
    heroSurface: gamePalette.benchRaised,
    onHeroSurface: gamePalette.ink,
    heroMuted: gamePalette.inkMuted,
    warmSurface: gamePalette.benchRaised,
    onWarmSurface: gamePalette.ink,
    coolSurface: gamePalette.benchRaised,
    onCoolSurface: gamePalette.ink,
  );

  // Material 標準部品も Field Notebook と同じ paper / bench / ink から作る。
  // 探究ログからレッスンへ移っても、同じ観察記録の続きとして読めるようにする。
  // 状態色は引き続き AppColors が担う。
  final scheme =
      ColorScheme.fromSeed(
        seedColor: gamePalette.action,
        brightness: brightness,
      ).copyWith(
        primary: gamePalette.action,
        onPrimary: gamePalette.onAction,
        primaryContainer: gamePalette.benchRaised,
        onPrimaryContainer: gamePalette.ink,
        secondary: gamePalette.caseFile,
        onSecondary: gamePalette.onCaseFile,
        secondaryContainer: gamePalette.benchRaised,
        onSecondaryContainer: gamePalette.ink,
        // ColorScheme.copyWith は ThemeData.copyWith とは別物で、
        // 「M3 が半分しか効かない」罠には該当しない。
        surface: gamePalette.paper,
        onSurface: gamePalette.ink,
        onSurfaceVariant: gamePalette.inkMuted,
        surfaceContainerLowest: gamePalette.bench,
        surfaceContainerLow: gamePalette.bench,
        surfaceContainer: gamePalette.benchRaised,
        surfaceContainerHigh: gamePalette.benchRaised,
        surfaceContainerHighest: gamePalette.locked,
        outline: gamePalette.inkMuted,
        outlineVariant: gamePalette.border,
      );

  // 本文だけ行高を上書きする。見出し・ラベルは1行で使うので M3 の値のまま。
  // leadingDistribution: even は M3 の TextTheme に既に入っているので触らない。
  final baseText = _tightenJapaneseHeadings(
    _pinWeightAxis(
      ThemeData(
        brightness: brightness,
      ).textTheme.apply(fontFamily: kFontFamily),
    ),
  );
  final textTheme = baseText.copyWith(
    bodyLarge: baseText.bodyLarge?.copyWith(height: kBodyLineHeight),
    bodyMedium: baseText.bodyMedium?.copyWith(height: kBodyLineHeight),
    bodySmall: baseText.bodySmall?.copyWith(height: kBodyLineHeight),
  );

  // ThemeData は light / dark それぞれ**コンストラクタで一発生成する**。
  // copyWith で継ぎ足さず、M3 の既定とアプリのトークンを同時に確定する。
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,

    // **波紋は Android の署名。** iOS に持ち込むと、面や色をどれだけ
    // 中立にしても「移植したもの」に見える。
    // 色・角丸・余白はプラットフォームで変えないが、**動きの作法だけは分ける**
    splashFactory: isApple ? NoSplash.splashFactory : InkSparkle.splashFactory,
    fontFamily: kFontFamily,
    textTheme: textTheme,
    extensions: <ThemeExtension<dynamic>>[appColors, gamePalette],

    // 影で階層を作らない。ソリッドな面と余白、必要な境界線だけで組む。
    // saveLayer を誘発する表現は Impeller で不利で、iOS には退避路が無い。
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GameTokens.radiusLg),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 68,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: scheme.secondaryContainer,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GameTokens.radiusSm),
      ),
      height: 64,
    ),

    // 入力欄の枠は borderStrong。装飾の区切り線と違い、
    // 「どこが入力欄か」を伝える唯一の手がかりなので 3:1 が要る (SC 1.4.11)。
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GameTokens.radiusMd),
        borderSide: BorderSide(color: appColors.borderStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GameTokens.radiusMd),
        borderSide: BorderSide(color: appColors.borderStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(GameTokens.radiusMd),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      filled: true,
      fillColor: scheme.surfaceContainer,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GameTokens.radiusMd),
        ),
        minimumSize: const Size(0, 54),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: textTheme.labelLarge?.jaWeight(FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GameTokens.radiusMd),
        ),
        side: BorderSide(color: appColors.borderStrong),
        minimumSize: const Size(0, 54),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: textTheme.labelLarge?.jaWeight(FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GameTokens.radiusSm),
        ),
        textStyle: textTheme.labelLarge?.jaWeight(FontWeight.w700),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GameTokens.radiusSm),
      ),
      side: BorderSide(color: scheme.outlineVariant),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      space: 1,
      thickness: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: gamePalette.ink,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: gamePalette.bench,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GameTokens.radiusSm),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: gamePalette.bench,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(GameTokens.radiusSheet),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GameTokens.radiusLg),
      ),
    ),
  );
}
