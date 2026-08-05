# アプリアイコンを、キャラクターと同じ図形から作る。
#
# 画面の中のデキすぎ君と別物を描くと、ストアで見たものと開いたものが食い違う。
# 形も色も `app/lib/widgets/character.dart` と `app_theme.dart` に合わせてある。
#
#   python tools/make-icon.py
#
# 出力:
#   docs/store/icon-512.png          Play の「アプリアイコン」
#   docs/store/feature-1024x500.png  フィーチャーグラフィック
#   app/android/app/src/main/res/mipmap-*/ic_launcher.png

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent

# app/lib/config/app_theme.dart の light と同じ値
BODY = (0x5B, 0x62, 0xD6)
FACE = (0xFF, 0xFF, 0xFF)
ACCENT = (0xFF, 0xC4, 0x6B)
BG = (0xF6, 0xF7, 0xF9)


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


def feature_graphic() -> Image.Image:
    scale = 4
    w, h = 1024 * scale, 500 * scale
    img = Image.new("RGB", (w, h), BG)
    d = ImageDraw.Draw(img)
    draw_character(d, w * 0.30, h * 0.42, h * 0.24)
    return img.resize((1024, 500), Image.LANCZOS)


def main() -> None:
    store = ROOT / "docs" / "store"
    store.mkdir(parents=True, exist_ok=True)

    render(512).save(store / "icon-512.png")
    feature_graphic().save(store / "feature-1024x500.png")

    # Android のランチャーアイコン。密度ごとの寸法は固定
    res = ROOT / "app" / "android" / "app" / "src" / "main" / "res"
    for folder, px in [
        ("mipmap-mdpi", 48), ("mipmap-hdpi", 72), ("mipmap-xhdpi", 96),
        ("mipmap-xxhdpi", 144), ("mipmap-xxxhdpi", 192),
    ]:
        out = res / folder
        out.mkdir(parents=True, exist_ok=True)
        render(px).save(out / "ic_launcher.png")

    print("icon-512.png / feature-1024x500.png / mipmap-* を出力した")


if __name__ == "__main__":
    main()
