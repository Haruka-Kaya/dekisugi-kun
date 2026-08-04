import '../ui/_material.dart';
import 'app_radius.dart';

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

/// アプリ共通のテーマ。基準は `attendance_system/DESIGN.md`（Web と Flutter 共通）。
///
/// 色を変えるときは必ず DESIGN.md の該当節を先に読むこと。
/// ここの値は sRGB 変換後に WCAG コントラスト比を計算して検証済みで、
/// 「なんとなく良さそう」で変えると基準を割る。
///
/// Liquid Glass とグラデーション背景は DESIGN.md §6 で禁止。
/// 階層は**ソリッドな面と境界線**だけで作る:
///   ライト … 背景もカード面も #FFFFFF なので**境界線**が階層を担う
///   ダーク … 背景 < カード面 < 入れ子の面 と**明度差**が階層を担う

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

/// DESIGN.md が定める、Material の ColorScheme に無い色。
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
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
  });

  /// 入力欄など「どこが操作対象か」を境界線で伝えるコントロール用。
  /// 装飾的な区切り線 (ColorScheme.outlineVariant) は 3:1 不要だが、
  /// こちらは SC 1.4.11 Non-text Contrast の 3:1 を満たす必要がある。
  final Color borderStrong;

  /// 「ここが更新された」等の一時的な強調。
  /// ステータス色を流用しない（状態と無関係な演出に状態の色を使うと意味が混ざる）。
  final Color highlightFlash;

  // 状態色 (DESIGN.md §2.4 の検証済み値)。前景はチップ上・ページ上とも 4.5:1 以上。
  final Color gotItFg, gotItChip;
  final Color shakyFg, shakyChip;
  final Color weakFg, weakChip;
  final Color untouchedFg, untouchedChip;

  static const light = AppColors(
    borderStrong: Color(0xFF8D8F93), // 白背景に対し 3.24:1
    highlightFlash: Color(0xFFD8EBFB),
    gotItFg: Color(0xFF207F40), gotItChip: Color(0xFFE9F6EB),
    shakyFg: Color(0xFF9B612E), shakyChip: Color(0xFFFEEFE3),
    weakFg: Color(0xFFBA4643), weakChip: Color(0xFFFDECEA),
    untouchedFg: Color(0xFF696E7A), untouchedChip: Color(0xFFF0F2F4),
  );

  static const dark = AppColors(
    borderStrong: Color(0xFF6D6F72), // カード面 #1E1F22 に対し 3.27:1
    highlightFlash: Color(0xFF233849),
    gotItFg: Color(0xFF419B5A), gotItChip: Color(0xFF18271B),
    shakyFg: Color(0xFFB97C2B), shakyChip: Color(0xFF2D2011),
    weakFg: Color(0xFFDA645E), weakChip: Color(0xFF331C1A),
    untouchedFg: Color(0xFF838A96), untouchedChip: Color(0xFF212326),
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
  }) =>
      AppColors(
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
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
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

  // seed は状態色（緑・橙・赤・灰）のどれとも重ならない色を選ぶ。
  // 重なると「主要操作の色」と「状態の色」の意味が混ざる。
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF4A5FC1),
    brightness: brightness,
  ).copyWith(
    // DESIGN.md §1.3 の確定値。面の役割だけ固定し、それ以外は seed 由来に任せる。
    // ColorScheme.copyWith は ThemeData.copyWith とは別物で、
    // 「M3 が半分しか効かない」罠には該当しない。
    surface: isDark ? const Color(0xFF131416) : const Color(0xFFFFFFFF),
    onSurface: isDark ? const Color(0xFFE6E8EB) : const Color(0xFF24262A),
    onSurfaceVariant:
        isDark ? const Color(0xFFA2A5AA) : const Color(0xFF696C72),
    surfaceContainerLow:
        isDark ? const Color(0xFF1E1F22) : const Color(0xFFFFFFFF),
    surfaceContainer:
        isDark ? const Color(0xFF2A2B2E) : const Color(0xFFF6F7F9),
    surfaceContainerHigh:
        isDark ? const Color(0xFF2A2B2E) : const Color(0xFFF6F7F9),
    outlineVariant: isDark ? const Color(0xFF3E4044) : const Color(0xFFDCDEE1),
  );

  final appColors = isDark ? AppColors.dark : AppColors.light;

  // 本文だけ行高を上書きする。見出し・ラベルは1行で使うので M3 の値のまま。
  // leadingDistribution: even は M3 の TextTheme に既に入っているので触らない。
  final baseText = _pinWeightAxis(
    ThemeData(brightness: brightness).textTheme.apply(fontFamily: kFontFamily),
  );
  final textTheme = baseText.copyWith(
    bodyLarge: baseText.bodyLarge?.copyWith(height: kBodyLineHeight),
    bodyMedium: baseText.bodyMedium?.copyWith(height: kBodyLineHeight),
    bodySmall: baseText.bodySmall?.copyWith(height: kBodyLineHeight),
  );

  // ThemeData は light / dark それぞれ**コンストラクタで一発生成する**。
  // copyWith で継ぎ足すと useMaterial3 の既定が半分しか効かない (DESIGN.md §1.3)。
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: kFontFamily,
    textTheme: textTheme,
    extensions: <ThemeExtension<dynamic>>[appColors],

    // 影で階層を作らない。ソリッドな面と境界線だけで組む (DESIGN.md §1.3 / §6)。
    // saveLayer を誘発する表現は Impeller で不利で、iOS には退避路が無い。
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(bottom: BorderSide(color: scheme.outlineVariant)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: scheme.secondaryContainer,
      height: 64,
    ),

    // 入力欄の枠は borderStrong。装飾の区切り線と違い、
    // 「どこが入力欄か」を伝える唯一の手がかりなので 3:1 が要る (SC 1.4.11)。
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: appColors.borderStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: appColors.borderStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      filled: true,
      fillColor: scheme.surfaceContainer,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        // 主要操作は 48dp 以上 (DESIGN.md §4.3)
        minimumSize: const Size(0, 48),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        side: BorderSide(color: appColors.borderStrong),
        minimumSize: const Size(0, 48),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      side: BorderSide.none,
    ),
    dividerTheme:
        DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
  );
}
