"""PNG圧縮差だけを許容し、画素・寸法・alphaの変更は拒否する。"""
import importlib.util
import io
from pathlib import Path
import unittest

from PIL import Image

spec = importlib.util.spec_from_file_location("make_icon", Path(__file__).with_name("make-icon.py"))
make_icon = importlib.util.module_from_spec(spec)
spec.loader.exec_module(make_icon)


def png(image, compression):
    output = io.BytesIO()
    image.save(output, format="PNG", compress_level=compression)
    return output.getvalue()


class AssetComparisonTest(unittest.TestCase):
    def test_compression_only_difference(self):
        image = Image.new("RGB", (32, 32), (24, 60, 91))
        first, second = png(image, 0), png(image, 9)
        self.assertNotEqual(first, second)
        self.assertTrue(make_icon._same_asset(first, second, png=True))

    def test_pixel_size_alpha_and_invalid_file_are_rejected(self):
        image = Image.new("RGB", (32, 32), (24, 60, 91))
        expected = png(image, 9)
        changed = image.copy()
        changed.putpixel((0, 0), (25, 60, 91))
        for candidate in (png(changed, 9), png(image.resize((16, 16)), 9),
                          png(image.convert("RGBA"), 9), b"invalid"):
            with self.subTest(candidate=len(candidate)):
                self.assertFalse(make_icon._same_asset(candidate, expected, png=True))

    def test_non_png_sources_require_identical_bytes(self):
        self.assertFalse(make_icon._same_asset(b"first", b"second", png=False))


if __name__ == "__main__":
    unittest.main()
