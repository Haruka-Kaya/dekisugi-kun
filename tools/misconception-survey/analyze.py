#!/usr/bin/env python3
"""実生徒の回答に対して、誤概念の「判定」と「誘発」を比べる。

合成データ版（tools/misconception-spike）は循環していて無効だった。
こちらは ground truth を**選択式で独立に**取るので循環しない。

    ① 選択式          → ground truth（誤概念を持っているか。機械採点）
    ② 自由記述の説明   → 経路A の入力（LLM が「誤りが含まれるか」を判定）
    ③ 誘導文への返事   → 経路B の入力（LLM は「否定されたか」だけを判定）

使い方:
    python analyze.py codes.txt                # 集計のみ（LLM を呼ばない）
    python analyze.py codes.txt --judge        # 経路A/B を実行して精度を測る
"""
import argparse, base64, json, os, pathlib, re, sys, time
from collections import defaultdict

sys.stdout.reconfigure(encoding="utf-8")
HERE = pathlib.Path(__file__).parent
ITEMS = {i["id"]: i for i in json.loads((HERE / "items.json").read_text(encoding="utf-8"))["items"]}
MODEL = os.environ.get("SPIKE_MODEL", "gemini-3.6-flash")


def load(paths):
    out = []
    for pat in paths:
        for p in pathlib.Path().glob(pat) if "*" in pat else [pathlib.Path(pat)]:
            raw = p.read_text(encoding="utf-8")
            if p.suffix == ".json":
                got = json.loads(raw)
                # サーバから引いたものは配列で来る（fetch-survey.ps1）。
                # 1件だけの JSON も従来どおり読める
                out.extend(got) if isinstance(got, list) else out.append(got)
                continue
            for line in raw.splitlines():
                line = line.strip()
                if not line:
                    continue
                try:
                    out.append(json.loads(base64.b64decode(line).decode("utf-8")))
                except Exception as e:
                    print(f"  [skip] 復号できない行: {line[:36]}... ({e})", file=sys.stderr)
    return out


def dedupe(recs):
    """同じ回答者の追記を1件にまとめる。

    アンケートは1問終わるごとに送る（途中でやめた人のぶんを残すため）ので、
    同じ sessionId が何度も届く。**いちばん進んだものだけ**を採る。

    sessionId が無いのは旧版（v1）。そのまま残す。
    """
    best, plain = {}, []
    for r in recs:
        if not isinstance(r, dict):
            continue
        sid = r.get("sessionId")
        if not sid:
            plain.append(r)
            continue
        cur = best.get(sid)
        n = len(r.get("ans") or [])
        if cur is None or n > len(cur.get("ans") or []):
            best[sid] = r
    return plain + list(best.values())


def kappa(tp, fp, fn, tn):
    n = tp + fp + fn + tn
    if n == 0:
        return 0.0
    po = (tp + tn) / n
    pe = ((tp + fp) * (tp + fn) + (fn + tn) * (fp + tn)) / (n * n)
    return (po - pe) / (1 - pe) if pe != 1 else 0.0


# ----------------------------------------------------------------- 判定パス
def make_client():
    from google import genai
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        for p in (HERE / ".env.local", pathlib.Path(r"C:\Users\kayah\jiyu-kenkyu-ai\.env.local")):
            if p.exists():
                m = re.search(r"GEMINI_API_KEY\s*=\s*(\S+)", p.read_text(encoding="utf-8"))
                if m:
                    key = m.group(1).strip().strip('"').strip("'"); break
    if not key:
        raise SystemExit("GEMINI_API_KEY が見つかりません")
    return genai.Client(api_key=key)


def gen(client, prompt, schema, tries=4):
    from google.genai import types
    for i in range(tries):
        try:
            r = client.models.generate_content(
                model=MODEL, contents=prompt,
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    response_schema=schema, temperature=0.0),
            )
            return json.loads(r.text)
        except Exception as e:
            if i == tries - 1:
                raise
            if any(c in str(e) for c in ("429", "503", "500", "UNAVAILABLE", "RESOURCE_EXHAUSTED")):
                time.sleep(2 ** i * 1.5)
            else:
                raise


JUDGE = {"type": "object",
         "properties": {"has_misconception": {"type": "boolean"},
                        "which": {"type": "string"},
                        "confidence": {"type": "string"}},
         "required": ["has_misconception", "which", "confidence"]}
CORR = {"type": "object",
        "properties": {"corrected": {"type": "boolean"}, "confidence": {"type": "string"}},
        "required": ["corrected", "confidence"]}


def path_a(client, item, text):
    """経路A: 説明文そのものを見て誤概念の有無を判定する（提案書の元設計）。"""
    return gen(client, f"""次は中学生が理科の「{item['topic']}」について自分の言葉で説明したものです。

<STUDENT_ANSWER>
{text}
</STUDENT_ANSWER>

この説明に**誤った理解（誤概念）が含まれているか**を判定してください。

- 説明が短い・不完全なだけで、書かれている内容自体が誤っていないなら false
- 言い落としと誤りを混同しないでください
- 判断がつかないときは confidence を low に""", JUDGE)


def path_b(client, item, reply):
    """経路B: 誘導文が否定されたかだけを判定する。正誤の内容判断はしない。"""
    return gen(client, f"""ある人が次の発言をしました。

発言A: 「{item['lure']}」

相手はこう返しました。

<STUDENT_ANSWER>
{reply}
</STUDENT_ANSWER>

**相手は発言Aの内容を否定・訂正しましたか。**

- 内容を打ち消していれば corrected = true
- 同意した、あいまいに流した、話題を変えた場合は false
- **正しいかどうかの判断はしないでください。** 否定されたかどうかだけを見ます""", CORR)


# --------------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("paths", nargs="+")
    ap.add_argument("--judge", action="store_true", help="LLM を呼んで経路A/Bの精度を測る")
    args = ap.parse_args()

    recs = dedupe(load(args.paths))
    rows = []
    skipped = 0
    for r in recs:
        # 保存先は追記式で、後から形を直せない。**壊れた1件で全体を落とさない**
        ans = r.get("ans") if isinstance(r, dict) else None
        if not isinstance(ans, list):
            skipped += 1
            continue
        for a in ans:
            if not isinstance(a, dict) or a.get("id") not in ITEMS:
                continue
            rows.append({**a, "grade": r.get("meta", {}).get("grade"),
                         "like": r.get("meta", {}).get("like")})
    print(f"回答者 {len(recs) - skipped} 人 / 回答 {len(rows)} 件")
    if skipped:
        print(f"  （形が違う {skipped} 件は除いた）")
    print()
    if not rows:
        return

    # --- ground truth の分布 ---
    # v2 は選択式2問。**2問そろったときだけ**確かなものとして数え、
    # 食い違い（inconsistent）は陽性にも陰性にも入れない。
    # 判断がついていないのにどちらかへ寄せると、そのぶんが測定の誤差になる
    print("=== 選択式（ground truth）===")
    band = defaultdict(int)
    for r in rows:
        gt = r.get("groundTruth")
        if gt == "inconsistent":
            band["2問が食い違い（判定に使わない）"] += 1
        elif r["correct"]:
            band["正解"] += 1
        elif r["heldMisconception"]:
            band["対象の誤概念"] += 1
        else:
            band["その他の誤答"] += 1
    for k, v in sorted(band.items(), key=lambda x: -x[1]):
        print(f"  {k:<24} {v:>3} 件 ({v/len(rows):.0%})")

    # 2問式がどれだけ効いたか。1問だけの判定と突き合わせる
    two = [r for r in rows if r.get("groundTruth")]
    if two:
        flipped = sum(1 for r in two
                      if r.get("correct1") != r["correct"]
                      or r.get("heldMisconception1") != r["heldMisconception"])
        print(f"\n  1問だけなら別の判定になっていた: {flipped}/{len(two)} 件"
              f"（{flipped/len(two):.0%}）")

    # ここから先の精度は**確かなものだけ**で測る
    rows = [r for r in rows if r.get("groundTruth") != "inconsistent"]
    if not rows:
        print("\n判定に使える回答がありません。")
        return

    print("\n=== 項目別 ===")
    per = defaultdict(lambda: [0, 0, 0])
    for r in rows:
        p = per[r["id"]]
        p[0] += 1
        p[1] += r["correct"]
        p[2] += r["heldMisconception"]
    for i, (k, v) in enumerate(sorted(per.items())):
        it = ITEMS[k]
        print(f"  {k} {it['topic']:<10} n={v[0]:<3} 正答 {v[1]/v[0]:.0%}  対象誤概念 {v[2]/v[0]:.0%}")

    lens = [len(r.get("explain", "")) for r in rows]
    if lens:
        lens.sort()
        print(f"\n説明文の長さ: 中央値 {lens[len(lens)//2]}字  範囲 {lens[0]}〜{lens[-1]}")

    if not args.judge:
        print("\n（--judge を付けると LLM を呼んで経路A/Bの精度を測ります）")
        return

    # --- 経路A / B を実データで走らせる ---
    client = make_client()
    print(f"\nモデル {MODEL} で {len(rows)*2} 回の判定を実行します...\n")
    for n, r in enumerate(rows, 1):
        it = ITEMS[r["id"]]
        try:
            a = path_a(client, it, r.get("explain", ""))
            b = path_b(client, it, r.get("lureReply", ""))
        except Exception as e:
            print(f"  [{n}/{len(rows)}] 失敗: {str(e)[:80]}")
            continue
        r["pred_A"] = bool(a["has_misconception"])
        r["which_A"] = a.get("which", "")
        # 誘導文を否定しなかった = 誤概念を持っている、と判断する
        r["pred_B"] = not bool(b["corrected"])
        t = r["heldMisconception"]
        print(f"  [{n}/{len(rows)}] {r['id']} truth={'誤概念' if t else '−':<4} "
              f"A:{'○' if r['pred_A']==t else '×'} B:{'○' if r['pred_B']==t else '×'}")

    judged = [r for r in rows if "pred_A" in r]
    print(f"\n{'='*60}\n判定できた {len(judged)} 件で評価\n{'='*60}")
    for path in ("A", "B"):
        tp = fp = fn = tn = 0
        bad_band = defaultdict(lambda: [0, 0])
        for r in judged:
            t, p = r["heldMisconception"], r[f"pred_{path}"]
            if p and t: tp += 1
            elif p and not t: fp += 1
            elif not p and t: fn += 1
            else: tn += 1
            key = "正解" if r["correct"] else ("対象の誤概念" if t else "その他の誤答")
            bad_band[key][1] += 1
            if p != t:
                bad_band[key][0] += 1
        prec = tp / (tp + fp) if tp + fp else 0.0
        rec = tp / (tp + fn) if tp + fn else 0.0
        f1 = 2 * prec * rec / (prec + rec) if prec + rec else 0.0
        name = "経路A（説明文を判定する）" if path == "A" else "経路B（誘導文が否定されたかを見る）"
        print(f"\n--- {name} ---")
        print(f"  precision {prec:.2f}  recall {rec:.2f}  F1 {f1:.2f}  κ {kappa(tp,fp,fn,tn):.2f}")
        print(f"  TP {tp}  FP {fp}  FN {fn}  TN {tn}")
        if tp:
            print(f"  真の検出1件あたりの誤警報: {fp/tp:.2f} 件")
        for k, (bad, tot) in sorted(bad_band.items()):
            if tot:
                print(f"    {k:<12} 誤判定 {bad}/{tot} = {bad/tot:.0%}")

    fps = [r for r in judged if not r["heldMisconception"] and r["pred_A"]]
    if fps:
        print(f"\n--- 経路A の誤警報の例（{len(fps)}件中3件）---")
        for r in fps[:3]:
            print(f"  [{r['id']}] {r.get('explain','')[:70]}")
            print(f"      → AI:「{r['which_A'][:70]}」")

    out = HERE / "judged.json"
    out.write_text(json.dumps(judged, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"\n判定済みデータ: {out}")
    print("""
--- 読むときの注意 ---
* ground truth は選択式1問。4択なので当てずっぽうでも25%当たる。
  「対象の誤概念を選んだ」ことは持っている証拠として強いが、
  「正解を選んだ」ことは理解している証拠としてはやや弱い。
* 提示順は 説明 → 誘導文 → 選択式。選択式が最後なので自由記述は選択肢に汚染されないが、
  逆に誘導文を読んだことが選択式の回答に影響した可能性は排除できていない。
* 経路Bの陽性は「誘導文を否定しなかった」。黙って流した回答も陽性になる。
""")


if __name__ == "__main__":
    main()
