import importlib.util
import io
import json
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path


ANALYZE_PATH = Path(__file__).with_name("analyze.py")
SPEC = importlib.util.spec_from_file_location("type_survey_analyze", ANALYZE_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"analyze.py を読み込めません: {ANALYZE_PATH}")
analyze = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(analyze)


def response(version, grade, *, legacy_env=False):
    record = {
        "v": version,
        "kind": "type",
        "meta": {
            "grade": grade,
            "light": "ふつう",
            "scale": "標準のまま",
        },
        "ans": [
            {
                "i": 0,
                "d": "lh",
                "pick": {"lh": 1.75, "ls": 0},
                "other": {"lh": 1.45, "ls": 0},
                "side": "a",
                "flip": 0,
                "tx": "sci1",
                "ms": 1500,
            },
            {
                "i": 9,
                "d": "catch",
                "pick": {"lh": 1.75, "ls": 0},
                "other": {"lh": 1.0, "ls": 0},
                "side": "b",
                "flip": 1,
                "tx": "soc1",
                "ms": 1600,
            },
        ],
    }
    if version >= 3:
        record["sessionId"] = "2bb832aa-6ca7-46e4-90fd-5af4d04144d8"
    if legacy_env:
        record["ts"] = "2026-08-06T00:00:00Z"
        record["env"] = {"w": 360, "scaleEst": 1.0, "ua": "legacy", "lang": "ja"}
    return record


class TypeSurveyAnalyzeTest(unittest.TestCase):
    def write_json(self, directory, name, value):
        path = Path(directory) / name
        path.write_text(json.dumps(value, ensure_ascii=False), encoding="utf-8")
        return path

    def test_load_expands_fetch_export_array_and_keeps_single_json(self):
        v2 = response(2, "中学3年", legacy_env=True)
        v3 = response(3, "高校1年")
        with tempfile.TemporaryDirectory() as directory:
            exported = self.write_json(directory, "responses.json", [v2, v3])
            single = self.write_json(directory, "single.json", v3)

            self.assertEqual(analyze.load([str(exported)]), [v2, v3])
            self.assertEqual(analyze.load([str(single)]), [v3])

    def test_main_aggregates_mixed_v2_v3_export_without_env_assumption(self):
        records = [
            response(2, "中学3年", legacy_env=True),
            response(3, "高校1年"),
        ]
        with tempfile.TemporaryDirectory() as directory:
            exported = self.write_json(directory, "responses.json", records)
            output = io.StringIO()
            with redirect_stdout(output):
                analyze.main([str(exported)])

        report = output.getvalue()
        self.assertIn("回収 2 件 / 有効 2 件 / 除外 0 件", report)
        self.assertIn("中学3年=1", report)
        self.assertIn("高校1年=1", report)
        self.assertIn("画面幅: 中央値 360px", report)


if __name__ == "__main__":
    unittest.main()
