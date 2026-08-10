#!/usr/bin/env python3
"""回答コードを集計する。

使い方:
    # codes.txt に、生徒から集めた結果コードを1行1件で貼る
    python analyze.py codes.txt

JSON ファイル（ダウンロードボタンで出たもの）を直接渡すこともできる:
    python analyze.py results/*.json
"""
import base64, json, sys, glob, math
from collections import defaultdict

def load(paths):
    out = []
    for pat in paths:
        for p in glob.glob(pat):
            with open(p, encoding="utf-8") as source:
                raw = source.read()
            if p.endswith(".json"):
                parsed = json.loads(raw)
                # fetch-survey.ps1 の出力は回答オブジェクトの配列。
                # ダウンロードボタン由来の単体 JSON との互換も保つ。
                out.extend(parsed if isinstance(parsed, list) else [parsed])
                continue
            for line in raw.splitlines():
                line = line.strip()
                if not line:
                    continue
                try:
                    out.append(json.loads(base64.b64decode(line).decode("utf-8")))
                except Exception as e:
                    print(f"  [skip] 復号できない行: {line[:40]}... ({e})", file=sys.stderr)
    return out


def main(paths):
    recs = load(paths)
    if not recs:
        print("回答が読み込めませんでした")
        return

    kept, dropped = [], []
    for r in recs:
        ans = r.get("ans", [])
        catch = [a for a in ans if a.get("d") == "catch"]
        # 注意チェック: 行間1.00 と 1.75 の対で 1.00 を選んだら無作為クリックを疑う
        catch_ok = all(a["pick"]["lh"] > a["other"]["lh"] for a in catch) if catch else False
        # 応答が極端に速い（全問の中央値が1.2秒未満）回答も除外候補
        ms = sorted(a.get("ms", 0) for a in ans)
        med = ms[len(ms) // 2] if ms else 0
        if catch_ok and med >= 1200:
            kept.append(r)
        else:
            dropped.append((r, catch_ok, med))

    print(f"回収 {len(recs)} 件 / 有効 {len(kept)} 件 / 除外 {len(dropped)} 件")
    for r, ok, med in dropped:
        why = []
        if not ok:
            why.append("注意チェック不通過")
        if med < 1200:
            why.append(f"応答が速すぎ(中央値{med}ms)")
        print(f"  除外: {r.get('meta',{}).get('grade','?')} — {' / '.join(why)}")
    if not kept:
        print("\n有効回答がありません")
        return

    for dim, key, label, unit in (("lh", "lh", "行間 (line-height)", "倍"),
                                  ("ls", "ls", "字間 (letter-spacing)", "em")):
        wins = defaultdict(int)
        games = defaultdict(int)
        head = defaultdict(int)      # (勝者, 敗者) -> 回数
        for r in kept:
            for a in r["ans"]:
                if a["d"] != dim:
                    continue
                w, l = a["pick"][key], a["other"][key]
                wins[w] += 1
                games[w] += 1
                games[l] += 1
                head[(w, l)] += 1

        if not games:
            continue
        print(f"\n=== {label} ===")
        print(f"{'水準':>8} {'勝率':>8} {'勝/試行':>10}   Flutter 換算")
        for lv in sorted(games):
            rate = wins[lv] / games[lv]
            if dim == "lh":
                conv = f"height: {lv}"
            else:
                conv = f"letterSpacing: {lv * 16:.2f}  (fontSize 16 のとき)"
            print(f"{lv:>8} {rate:>7.0%} {wins[lv]:>5}/{games[lv]:<4}   {conv}")

        print("  総当たりの内訳:")
        seen = set()
        for (w, l), n in sorted(head.items()):
            if (l, w) in seen:
                continue
            seen.add((w, l))
            m = head.get((l, w), 0)
            tot = n + m
            if tot == 0:
                continue
            # 二項検定の正規近似（n が小さいので参考値）
            z = (n - tot / 2) / math.sqrt(tot / 4) if tot else 0
            sig = " *" if abs(z) >= 1.96 else ""
            print(f"    {w} vs {l}:  {n} - {m}{sig}")
        print("    * = 5%水準で有意（正規近似・多重比較の補正なし。参考値）")

    print("\n=== 属性 ===")
    for k in ("grade", "light", "scale"):
        c = defaultdict(int)
        for r in kept:
            c[r.get("meta", {}).get(k)] += 1
        print(f"  {k}: " + ", ".join(f"{v}={n}" for v, n in sorted(c.items(), key=lambda x: -x[1])))

    widths = [r.get("env", {}).get("w") for r in kept if r.get("env", {}).get("w")]
    scales = [r.get("env", {}).get("scaleEst") for r in kept if r.get("env", {}).get("scaleEst")]
    if widths:
        print(f"  画面幅: 中央値 {sorted(widths)[len(widths)//2]}px  範囲 {min(widths)}–{max(widths)}")
    if scales:
        odd = [s for s in scales if s and abs(s - 1.0) > 0.05]
        print(f"  文字スケール推定: 標準から外れている端末 {len(odd)}/{len(scales)} 件")

    print("""
--- 読むときの注意 ---
* このアンケートが測っているのは「選好」であって読解速度ではない。
  10分読む前提で聞いているが、実際の読解成績を測ってはいない。
* CSS の line-height は上下均等（half-leading）に配る。
  Flutter の既定は proportional なので、結果をそのまま適用するなら
  TextStyle に leadingDistribution: TextLeadingDistribution.even を必ず入れる。
  入れないと Noto Sans JP では 1160:288 ≒ 80:20 で配られ、和文が行箱の下に沈む。
* 字間を広げると行数が増えて折り返しが変わる。
  「字間」ではなく「行数」を見て選んでいる可能性は排除できていない。
* 端末・画面幅・OSのフォントサイズ設定は統制していない。
  属性の偏りが出ていないかを上の集計で必ず確認すること。
""")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1:])
