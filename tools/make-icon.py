#!/usr/bin/env python3
"""Runtimeのデキすぎ君からnative/storeブランド画像を再生成する。

キャラクターの形・色をPythonへ複製しない。Flutter testが公開Widget
``DekisugiCharacterArt`` を直接PNGへ書き出し、このscriptは合成、resize、
PNGのRGB/RGBA化だけを行う。

生成:
    uv run --with-requirements tools/requirements-icons.txt tools/make-icon.py

追跡済みassetとの一致、2回生成のbyte一致、寸法・alpha・safe-zone・参照:
    uv run --with-requirements tools/requirements-icons.txt tools/make-icon.py --check
"""

from __future__ import annotations

import argparse
import io
import json
from pathlib import Path
from typing import Dict, Iterable, Mapping

from PIL import Image, ImageChops, ImageOps


ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "app"
RES = APP / "android" / "app" / "src" / "main" / "res"
IOS_ASSETS = APP / "ios" / "Runner" / "Assets.xcassets"
STORE = ROOT / "docs" / "store"

LIGHT_GOLDEN = APP / "test" / "goldens" / "native_brand_character_light.png"
DARK_GOLDEN = APP / "test" / "goldens" / "native_brand_character_dark.png"
MONOCHROME_GOLDEN = (
    APP / "test" / "goldens" / "native_brand_character_monochrome.png"
)
FEATURE_GOLDEN = APP / "test" / "goldens" / "native_brand_feature.png"

ANDROID_DENSITIES = {
    "mdpi": (48, 108, 1),
    "hdpi": (72, 162, 1.5),
    "xhdpi": (96, 216, 2),
    "xxhdpi": (144, 324, 3),
    "xxxhdpi": (192, 432, 4),
}

IOS_ICONS = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}


def _golden(path: Path, expected: tuple[int, int]) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    if image.size != expected:
        raise RuntimeError(f"native brand source goldenの寸法が不正です: {path}: {image.size}")
    return image


def _rgb(hex_value: str) -> tuple[int, int, int]:
    value = hex_value.removeprefix("#")
    if len(value) != 6:
        raise ValueError(f"6桁sRGBではありません: {hex_value}")
    return tuple(int(value[index : index + 2], 16) for index in (0, 2, 4))


def _png(image: Image.Image, *, mode: str) -> bytes:
    converted = image.convert(mode)
    output = io.BytesIO()
    # metadataを付けず、同一環境・同一encoder設定でbyteを固定する。
    converted.save(output, format="PNG", optimize=False, compress_level=9)
    return output.getvalue()


def _square_icon(
    source: Image.Image,
    size: int,
    background: tuple[int, int, int],
) -> Image.Image:
    canvas = Image.new("RGB", (size, size), background)
    art_size = round(size * 0.82)
    art = source.resize((art_size, art_size), Image.Resampling.LANCZOS)
    offset = ((size - art_size) // 2, (size - art_size) // 2)
    canvas.paste(art, offset, art)
    return canvas


def _adaptive_foreground(source: Image.Image, size: int) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    # Androidの108dp canvas中央66dpが全maskで残る領域。runtime art自体の
    # ink boundsは72dp square内の約61dpなので、この寸法なら完全に収まる。
    art_size = round(size * (72 / 108))
    art = source.resize((art_size, art_size), Image.Resampling.LANCZOS)
    # idle artは斜めアンテナぶん上側のinkが長い。全adaptive maskの
    # 中央66dpへ輪郭を収めつつ腕・本を縮めないよう、3dpだけ下へ置く。
    offset = (
        (size - art_size) // 2,
        (size - art_size) // 2 + round(size * (3 / 108)),
    )
    canvas.alpha_composite(art, offset)
    return canvas


def _transparent_launch(
    source: Image.Image,
    width: int,
    height: int,
    *,
    art_size: int | None = None,
) -> Image.Image:
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    side = art_size or min(width, height)
    art = source.resize((side, side), Image.Resampling.LANCZOS)
    canvas.alpha_composite(art, ((width - side) // 2, (height - side) // 2))
    return canvas


def _monochrome_mask(source: Image.Image, size: int = 108) -> Image.Image:
    # Flutterが直接描いたblack body / white eyes+bookをalphaへ移す。
    # 元alphaも掛けるため、透明なcanvasは着色されず、eyes/bookはnegative spaceになる。
    rgba = source.convert("RGBA")
    alpha_source = ImageChops.multiply(
        rgba.getchannel("A"),
        ImageOps.invert(rgba.convert("L")),
    )
    alpha_rgba = Image.new("RGBA", source.size, (0, 0, 0, 0))
    alpha_rgba.putalpha(alpha_source)
    return _adaptive_foreground(alpha_rgba, size)


def build_outputs() -> Dict[Path, bytes]:
    light_canvas = _rgb("F4F1E9")
    dark_canvas = _rgb("121719")
    light = _golden(LIGHT_GOLDEN, (512, 512))
    dark = _golden(DARK_GOLDEN, (512, 512))
    monochrome = _golden(MONOCHROME_GOLDEN, (512, 512))
    feature = _golden(FEATURE_GOLDEN, (1024, 500)).convert("RGB")
    outputs: Dict[Path, bytes] = {}

    light_1024 = _square_icon(light, 1024, light_canvas)
    outputs[STORE / "icon-1024.png"] = _png(light_1024, mode="RGB")
    outputs[STORE / "icon-512.png"] = _png(
        light_1024.resize((512, 512), Image.Resampling.LANCZOS),
        mode="RGBA",
    )
    outputs[STORE / "feature-1024x500.png"] = _png(feature, mode="RGB")

    for qualifier, (legacy_size, adaptive_size, _) in ANDROID_DENSITIES.items():
        light_dir = RES / f"mipmap-{qualifier}"
        dark_dir = RES / f"mipmap-night-{qualifier}"
        outputs[light_dir / "ic_launcher.png"] = _png(
            _square_icon(light, legacy_size, light_canvas), mode="RGB"
        )
        outputs[light_dir / "ic_launcher_foreground.png"] = _png(
            _adaptive_foreground(light, adaptive_size), mode="RGBA"
        )
        outputs[dark_dir / "ic_launcher.png"] = _png(
            _square_icon(dark, legacy_size, dark_canvas), mode="RGB"
        )
        outputs[dark_dir / "ic_launcher_foreground.png"] = _png(
            _adaptive_foreground(dark, adaptive_size), mode="RGBA"
        )

    outputs[RES / "drawable-nodpi" / "ic_launcher_monochrome.png"] = _png(
        _monochrome_mask(monochrome), mode="RGBA"
    )
    outputs[RES / "drawable-nodpi" / "launch_mascot.png"] = _png(
        _transparent_launch(light, 336, 370), mode="RGBA"
    )
    outputs[RES / "drawable-night-nodpi" / "launch_mascot.png"] = _png(
        _transparent_launch(dark, 336, 370), mode="RGBA"
    )
    # Android 12+ splashは288dp canvas内の192dp領域へ静止artを置く。
    outputs[RES / "drawable-nodpi" / "launch_mascot_v31.png"] = _png(
        _transparent_launch(light, 288, 288, art_size=192), mode="RGBA"
    )
    outputs[RES / "drawable-night-nodpi" / "launch_mascot_v31.png"] = _png(
        _transparent_launch(dark, 288, 288, art_size=192), mode="RGBA"
    )

    ios_icons = IOS_ASSETS / "AppIcon.appiconset"
    for filename, size in IOS_ICONS.items():
        outputs[ios_icons / filename] = _png(
            _square_icon(light, size, light_canvas), mode="RGB"
        )

    ios_launch = IOS_ASSETS / "LaunchImage.imageset"
    for scale in (1, 2, 3):
        suffix = "" if scale == 1 else f"@{scale}x"
        outputs[ios_launch / f"LaunchImage{suffix}.png"] = _png(
            _transparent_launch(light, 168 * scale, 185 * scale), mode="RGBA"
        )
        outputs[ios_launch / f"LaunchImage-dark{suffix}.png"] = _png(
            _transparent_launch(dark, 168 * scale, 185 * scale), mode="RGBA"
        )

    return outputs


def _image_mode_and_size(payload: bytes) -> tuple[str, tuple[int, int]]:
    with Image.open(io.BytesIO(payload)) as image:
        return image.mode, image.size


def _assert_output_contract(outputs: Mapping[Path, bytes]) -> None:
    for path, payload in outputs.items():
        mode, size = _image_mode_and_size(payload)
        name = path.name
        if "AppIcon.appiconset" in str(path) or (
            name == "ic_launcher.png" and "mipmap" in str(path)
        ) or name in {"icon-1024.png", "feature-1024x500.png"}:
            if mode != "RGB":
                raise AssertionError(f"alpha禁止assetが{mode}です: {path}")
        elif mode != "RGBA":
            raise AssertionError(f"透明assetが{mode}ではありません: {path}")
        if size[0] <= 0 or size[1] <= 0:
            raise AssertionError(f"空のassetです: {path}")

    foreground = outputs[
        RES / "mipmap-mdpi" / "ic_launcher_foreground.png"
    ]
    with Image.open(io.BytesIO(foreground)).convert("RGBA") as image:
        alpha = image.getchannel("A")
        bounds = alpha.point(lambda value: 255 if value > 4 else 0).getbbox()
    if bounds is None:
        raise AssertionError("adaptive foregroundが透明です")
    left, top, right, bottom = bounds
    # getbboxのright/bottomはexclusive。中央66dp=[21,87)。
    if left < 21 or top < 21 or right > 87 or bottom > 87:
        raise AssertionError(f"adaptive foregroundが66dp safe-zone外です: {bounds}")


def _assert_references() -> None:
    v33 = (RES / "mipmap-anydpi-v33" / "ic_launcher.xml").read_text(
        encoding="utf-8"
    )
    if "@drawable/ic_launcher_monochrome" not in v33:
        raise AssertionError("Android 13 themed icon参照がありません")
    if not (RES / "drawable-nodpi" / "ic_launcher_monochrome.png").is_file():
        raise AssertionError("Android monochrome PNGがありません")

    for qualifier in ("values-v31", "values-night-v31"):
        styles = (RES / qualifier / "styles.xml").read_text(encoding="utf-8")
        if "windowSplashScreenBackground" not in styles:
            raise AssertionError(f"{qualifier}にAndroid 12 splash背景がありません")
        if "@drawable/launch_mascot_v31" not in styles:
            raise AssertionError(f"{qualifier}にAndroid 12 mascot参照がありません")

    for set_name in ("AppIcon.appiconset", "LaunchImage.imageset"):
        directory = IOS_ASSETS / set_name
        contents = json.loads((directory / "Contents.json").read_text(encoding="utf-8"))
        for item in contents["images"]:
            filename = item.get("filename")
            if filename and not (directory / filename).is_file():
                raise AssertionError(f"iOS asset参照切れ: {set_name}/{filename}")


def _compare_maps(first: Mapping[Path, bytes], second: Mapping[Path, bytes]) -> None:
    if set(first) != set(second):
        raise AssertionError("2回の生成で出力file集合が変わりました")
    changed = [path for path in first if first[path] != second[path]]
    if changed:
        raise AssertionError(
            "2回の生成がbyte-identicalではありません: "
            + ", ".join(str(path.relative_to(ROOT)) for path in changed)
        )


def _write_outputs(outputs: Mapping[Path, bytes]) -> None:
    for path, payload in outputs.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(payload)


def _check_current(outputs: Mapping[Path, bytes]) -> None:
    missing = [path for path in outputs if not path.is_file()]
    if missing:
        raise AssertionError(
            "生成assetが不足しています: "
            + ", ".join(str(path.relative_to(ROOT)) for path in missing)
        )
    changed = [
        path for path, payload in outputs.items()
        if not _same_asset(path.read_bytes(), payload, png=path.suffix == ".png")
    ]
    if changed:
        raise AssertionError(
            "runtime正本と一致しないassetがあります。tools/make-icon.pyを実行してください: "
            + ", ".join(str(path.relative_to(ROOT)) for path in changed)
        )


def _same_asset(actual: bytes, expected: bytes, *, png: bool) -> bool:
    if actual == expected:
        return True
    if not png:
        return False
    # macOS/Linuxのzlibは同じ画素でもPNGの圧縮byteが異なる。
    # sourceとの一致はmode・寸法・全画素で判定し、同一環境での
    # 2回生成のbyte一致は_compare_mapsで別途要求する。
    try:
        with Image.open(io.BytesIO(actual)) as got, Image.open(io.BytesIO(expected)) as want:
            return (
                got.format == want.format == "PNG"
                and got.mode == want.mode
                and got.size == want.size
                and got.tobytes() == want.tobytes()
            )
    except (OSError, ValueError):
        return False


def generate(*, check: bool) -> None:
    if check:
        first = build_outputs()
        second = build_outputs()
        _compare_maps(first, second)
        _assert_output_contract(first)
        _check_current(first)
        _assert_references()
        print("runtime正本との一致、2回生成、寸法・alpha・safe-zone・参照: OK")
        return

    outputs = build_outputs()
    # 同じgolden正本から2回buildし、encoder処理自体の非決定性も書込前に止める。
    _compare_maps(outputs, build_outputs())
    _assert_output_contract(outputs)
    _write_outputs(outputs)
    print(f"runtime正本からnative/store画像を{len(outputs)}件生成しました")


def main(argv: Iterable[str] | None = None) -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="書き込まず、runtime正本との一致と2回生成の再現性を検証する",
    )
    args = parser.parse_args(argv)
    generate(check=args.check)


if __name__ == "__main__":
    main()
