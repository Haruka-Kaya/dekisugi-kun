#!/usr/bin/env python3
"""設問カタログの検査。**項目を足したら必ず通すこと。**

条件の書き漏らしは、生徒に指摘されるまで気づけない。
実際に「圧力といってもいろいろある」「場所が地球か宇宙か分からない」と
言われて、二度作り直した。同じ穴に落ちないよう機械で見る。

    python check_items.py
"""
import json
import pathlib
import sys

sys.stdout.reconfigure(encoding="utf-8")
HERE = pathlib.Path(__file__).parent
data = json.loads((HERE / "items.json").read_text(encoding="utf-8"))
items = data["items"]

problems: list[str] = []


def bad(item_id: str, msg: str) -> None:
    problems.append(f"{item_id}: {msg}")


for it in items:
    i = it["id"]
    assume = it.get("assume") or []
    texts = [it.get("q", ""), it.get("q2", "")]

    # --- 前提 ---
    if not isinstance(assume, list) or not assume:
        bad(i, "前提が箇条になっていない")
        continue

    if not any("場所" in a for a in assume):
        bad(i, "前提に**場所**が無い（地球の上か、宇宙空間か）")

    # 「一定の速さ」は誰から見てかで変わる。動きを問う項目には基準系が要る
    if any(k in "".join(texts) for k in ("一定の速さ", "動いて", "すべ", "進んで")):
        if not any("見る人" in a for a in assume):
            bad(i, "動きを問うのに**見る人（基準系）**が無い")

    # --- 使ってはいけない言葉 ---
    for t in assume + texts:
        if "真空" in t:
            bad(i, "「真空」は使わない（宇宙空間と読まれ、重力が無いことになる）")

    # --- 設問本文 ---
    for k in ("q", "q2"):
        t = it.get(k, "")
        if not t:
            bad(i, f"{k} が無い")
            continue
        # **設問だけ読む生徒がいる。** 答えが変わる条件は設問側にも書く
        if not ("地球" in t or "宇宙" in t):
            bad(i, f"{k} の本文に場所が書かれていない")

    # --- 誘導文 ---
    if not it.get("lure", "").rstrip().endswith(("？", "?")):
        bad(i, "lure が問いかけで終わっていない（断定すると訂正しにくい）")

    # --- 選択式 ---
    for k, ok, trap in (("options", "correct", "trap"), ("options2", "correct2", "trap2")):
        opts = it.get(k) or []
        if len(opts) < 3:
            bad(i, f"{k} の選択肢が少ない")
        if it.get(ok) == it.get(trap):
            bad(i, f"{ok} と {trap} が同じ添字を指している")
        for idx_key in (ok, trap):
            if not (0 <= it.get(idx_key, -1) < len(opts)):
                bad(i, f"{idx_key} が選択肢の範囲外")

print(f"{len(items)} 項目を検査しました")
if problems:
    print()
    for p in problems:
        print("  ✖ " + p)
    sys.exit(1)
print("  問題ありません")
