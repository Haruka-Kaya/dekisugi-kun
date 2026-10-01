# アプリアイコンを、キャラクターと同じ図形から作る。
#
# 画面の中のデキすぎ君と別物を描くと、ストアで見たものと開いたものが食い違う。
# 形も色も `app/lib/widgets/character.dart` と `app_theme.dart` に合わせてある。
#
#   python tools/make-icon.py
#
# 出力:
#   docs/store/icon-1024.png         iOS / 元画像
#   docs/store/icon-512.png          Play の「アプリアイコン」
#   docs/store/feature-1024x500.png  フィーチャーグラフィック
#   Android のlegacy / adaptive foregroundと、iOSの全ランチャーアイコン

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent

# app/lib/config/app_theme.dart の light と同じ値
BODY = (0x5B, 0x62, 0xD6)
FACE = (0xFF, 0xFF, 0xFF)
ACCENT = (0xFF, 0xC4, 0x6B)
BG = (0xF6, 0xF2, 0xE9)
INK = (0x1C, 0x23, 0x33)
MUTED = (0x62, 0x67, 0x75)


def draw_character(d: ImageDraw.ImageDraw, cx: float, cy: float, r: float) -> None:
    """character.dart の paint() と同じ順・同じ比率で描く。"""
    # ① 房（右上）
    d.rounded_rectangle(
        [cx + r * 0.35 - r * 0.09, cy - r * 1.12 - r * 0.21,
         cx + r * 0.35 + r * 0.09, cy - r * 1.12 + r * 0.21],
        radius=r * 0.09, fill=BODY)
    d.ellipse(
        [cx + r * 0.35 - r * 0.15, cy - r * 1.35 - r * 0.15,
         cx + r * 0.35 + r * 0.15, cy - r * 1.35 + r * 0.15],
        fill=ACCENT)

    # ② 体（**頭より横に広い**。狭いと「あご」に見える）
    bw = r * 2.3
    d.rounded_rectangle(
        [cx - bw / 2, cy + r * 1.28 - r * 0.45,
         cx + bw / 2, cy + r * 1.28 + r * 0.45],
        radius=r * 0.34, fill=BODY)

    # ③ 頭
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=BODY)

    # ④ 目とハイライト
    eye_r = r * 0.20
    for side in (-1, 1):
        ex = cx + r * 0.40 * side
        ey = cy - r * 0.05
        d.ellipse([ex - eye_r, ey - eye_r, ex + eye_r, ey + eye_r], fill=FACE)
        hr = eye_r * 0.26
        hx, hy = ex + eye_r * 0.32, ey - eye_r * 0.34
        d.ellipse([hx - hr, hy - hr, hx + hr, hy + hr], fill=BODY)


def render(size: int, scale: int = 4) -> Image.Image:
    """アンチエイリアスのため大きく描いて縮める。"""
    s = size * scale
    img = Image.new("RGB", (s, s), BG)
    d = ImageDraw.Draw(img)
    # 頭の半径は 0.22 が上限。これより大きいと体の下端が切れる。
    # Android はランチャーで角丸に切り取るので、四辺に余白が要る
    draw_character(d, s / 2, s * 0.42, s * 0.22)
    return img.resize((size, size), Image.LANCZOS)


def adaptive_foreground(size: int, scale: int = 4) -> Image.Image:
    """Android Adaptive Iconの108dp前景。安全領域の中へ図形だけを置く。"""
    s = size * scale
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # マスクや端末ごとの視差移動で切れないよう、66dpの安全領域に収める。
    draw_character(d, s / 2, s * 0.48, s * 0.18)
    return img.resize((size, size), Image.LANCZOS)


def launch_mascot(width: int, height: int, scale: int = 4) -> Image.Image:
    """起動画面用の透明マスコット。文字や進捗表示は入れない。"""
    w, h = width * scale, height * scale
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw_character(d, w / 2, h * 0.43, h * 0.235)
    return img.resize((width, height), Image.LANCZOS)


def feature_graphic() -> Image.Image:
    scale = 4
    w, h = 1024 * scale, 500 * scale
    img = Image.new("RGB", (w, h), BG)
    d = ImageDraw.Draw(img)
    draw_character(d, w * 0.25, h * 0.42, h * 0.24)

    font_path = ROOT / "app" / "assets" / "fonts" / "NotoSansJP-Variable.ttf"
    title = ImageFont.truetype(str(font_path), 48 * scale)
    body = ImageFont.truetype(str(font_path), 22 * scale)
    label = ImageFont.truetype(str(font_path), 16 * scale)

    d.text((520 * scale, 102 * scale), "AIデキすぎ君", font=label, fill=MUTED)
    d.text((520 * scale, 145 * scale), "覚える側から、", font=title, fill=INK)
    d.text((520 * scale, 207 * scale), "教える側へ。", font=title, fill=INK)
    d.text(
        (520 * scale, 310 * scale),
        "読んで、閉じて、AIに教える。",
        font=body,
        fill=MUTED,
    )
    return img.resize((1024, 500), Image.LANCZOS)


def main() -> None:
    store = ROOT / "docs" / "store"
    store.mkdir(parents=True, exist_ok=True)

    render(1024).save(store / "icon-1024.png")
    # Google Playのストアアイコンは32-bit PNGが必要。見た目は不透明でも
    # alpha channelを持つRGBAで保存する。
    render(512).convert("RGBA").save(store / "icon-512.png")
    feature_graphic().save(store / "feature-1024x500.png")

    # Android のランチャーアイコン。密度ごとの寸法は固定
    res = ROOT / "app" / "android" / "app" / "src" / "main" / "res"
    for folder, legacy_px, adaptive_px in [
        ("mipmap-mdpi", 48, 108),
        ("mipmap-hdpi", 72, 162),
        ("mipmap-xhdpi", 96, 216),
        ("mipmap-xxhdpi", 144, 324),
        ("mipmap-xxxhdpi", 192, 432),
    ]:
        out = res / folder
        out.mkdir(parents=True, exist_ok=True)
        render(legacy_px).save(out / "ic_launcher.png")
        adaptive_foreground(adaptive_px).save(out / "ic_launcher_foreground.png")

    launch = res / "drawable-nodpi"
    launch.mkdir(parents=True, exist_ok=True)
    # nodpiは端末密度で再拡大されないため、Android用は2倍で持つ。
    launch_mascot(336, 370).save(launch / "launch_mascot.png")

    ios = (
        ROOT
        / "app"
        / "ios"
        / "Runner"
        / "Assets.xcassets"
        / "AppIcon.appiconset"
    )
    for filename, px in [
        ("Icon-App-20x20@1x.png", 20),
        ("Icon-App-20x20@2x.png", 40),
        ("Icon-App-20x20@3x.png", 60),
        ("Icon-App-29x29@1x.png", 29),
        ("Icon-App-29x29@2x.png", 58),
        ("Icon-App-29x29@3x.png", 87),
        ("Icon-App-40x40@1x.png", 40),
        ("Icon-App-40x40@2x.png", 80),
        ("Icon-App-40x40@3x.png", 120),
        ("Icon-App-60x60@2x.png", 120),
        ("Icon-App-60x60@3x.png", 180),
        ("Icon-App-76x76@1x.png", 76),
        ("Icon-App-76x76@2x.png", 152),
        ("Icon-App-83.5x83.5@2x.png", 167),
        ("Icon-App-1024x1024@1x.png", 1024),
    ]:
        render(px).save(ios / filename)

    ios_launch = (
        ROOT
        / "app"
        / "ios"
        / "Runner"
        / "Assets.xcassets"
        / "LaunchImage.imageset"
    )
    for filename, scale in [
        ("LaunchImage.png", 1),
        ("LaunchImage@2x.png", 2),
        ("LaunchImage@3x.png", 3),
    ]:
        launch_mascot(168 * scale, 185 * scale).save(ios_launch / filename)

    print("store画像 / Android / iOS アイコンを出力した")


if __name__ == "__main__":
    main()
