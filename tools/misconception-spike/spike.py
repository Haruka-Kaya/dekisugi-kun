#!/usr/bin/env python3
"""誤概念検出スパイク — 「判定」と「誘発」のどちらが実用に耐えるかを測る。

背景:
  LLM による誤概念の自動検出は precision ≈ 0.19（真の検出1件あたり約4.3件の誤警報）で、
  しかも最も外すのが「だいたい分かるが説明が不完全」な帯＝デキすぎ君の主要ターゲット層。
  提案書の売り「説明できない＝弱点。AIが自動で発見してくれる」は、このままでは加害になる。

仮説:
  誤概念を「判定」するのをやめ、AI生徒が既知の誤概念を口にして「訂正されたか」を見る（誘発）と、
  LLM のタスクが「説明が正しいか」から「直前の文が否定されたか」に変わり、精度が上がる。

測り方:
  合成生徒の知識状態を GROUND_TRUTH として固定し、そこからしか話させない。
  検出側には ground truth を一切見せない。
  経路A（判定）と経路B（誘発）を同じ生徒に対して走らせ、帯別に精度を比べる。

使い方:
    python spike.py --reps 3            # 8誤概念 × 3状態 × 3反復 = 72人
    python spike.py --reps 1 --quick    # 動作確認用
"""
import argparse, json, os, pathlib, random, re, sys, time
from collections import defaultdict

sys.stdout.reconfigure(encoding="utf-8")
from google import genai
from google.genai import types

import catalog

MODEL = os.environ.get("SPIKE_MODEL", "gemini-3.6-flash")
HERE = pathlib.Path(__file__).parent


def load_key():
    if os.environ.get("GEMINI_API_KEY"):
        return os.environ["GEMINI_API_KEY"]
    # jiyu-kenkyu-ai の .env.local を流用（ユーザー承認済み）
    for p in (HERE / ".env.local", pathlib.Path(r"C:\Users\kayah\jiyu-kenkyu-ai\.env.local")):
        if p.exists():
            m = re.search(r"GEMINI_API_KEY\s*=\s*(\S+)", p.read_text(encoding="utf-8"))
            if m:
                return m.group(1).strip().strip('"').strip("'")
    raise SystemExit("GEMINI_API_KEY が見つかりません")


client = genai.Client(api_key=load_key())


def gen(prompt, schema, temperature=1.0, tries=4):
    """構造化出力を1回取る。429/503 は指数バックオフ。"""
    for i in range(tries):
        try:
            r = client.models.generate_content(
                model=MODEL,
                contents=prompt,
                config=types.GenerateContentConfig(
                    response_mime_type="application/json",
                    response_schema=schema,
                    temperature=temperature,
                ),
            )
            return json.loads(r.text)
        except Exception as e:
            msg = str(e)
            if i == tries - 1:
                raise
            if any(c in msg for c in ("429", "503", "500", "UNAVAILABLE", "RESOURCE_EXHAUSTED")):
                time.sleep(2 ** i * 1.5)
            else:
                raise


# ---------------------------------------------------------------- 生徒を作る
UTTER_SCHEMA = {
    "type": "object",
    "properties": {"utterance": {"type": "string"}},
    "required": ["utterance"],
}


def make_student(m, state, seed):
    """知識状態に忠実な「生徒の説明」を1つ作る。ここが GROUND_TRUTH。"""
    if state == "misconception":
        belief = f"あなたが信じていること（本人は正しいと思っている）:\n{m['misconception']}"
    elif state == "correct":
        belief = f"あなたが理解していること:\n{m['correct']}"
    elif state == "ambiguous":
        belief = (
            f"あなたが理解していること（結論はこれで正しい）:\n{m['correct']}\n\n"
            f"ただし話の中で、次の**誤った考えをいったん口に出してから否定**してください:\n"
            f"『{m['misconception']}』\n\n"
            "「前はこう思ってた」「一見こう見えるけど」「〜な気がするけど実際は違った」のように、"
            "誤概念の言い回しを文中に含めたうえで、正しい結論に着地すること。"
        )
    else:
        belief = (
            f"あなたが理解していること:\n{m['correct']}\n\n"
            "ただし説明は不完全にすること。条件や理由を言い落とす、結論だけ言う、"
            "用語が出てこない、など。**内容として誤ったことは絶対に言わない。**"
        )

    prompt = f"""あなたは日本の中学2年生です。理科の「{m['unit']}／{m['topic']}」について、
友達に自分の言葉で説明します。

{belief}

## 話し方
- {catalog.STATE_BRIEF[state]}
- **40〜90字**。中学生が実際に話すくらいの短さ
- 教科書の丸暗記口調にしない。「〜だと思う」「〜じゃん」など話し言葉でよい
- 箇条書きにしない。1〜2文で話す
- バリエーション番号 {seed}（同じ内容でも言い回しを変える）

説明だけを utterance に入れてください。"""
    return gen(prompt, UTTER_SCHEMA, temperature=1.3)["utterance"]


# ------------------------------------------------------- 経路A: 判定（従来型）
JUDGE_SCHEMA = {
    "type": "object",
    "properties": {
        "has_misconception": {"type": "boolean"},
        "which": {"type": "string", "description": "誤概念の内容。無ければ空文字"},
        "confidence": {"type": "string", "description": "high / medium / low"},
    },
    "required": ["has_misconception", "which", "confidence"],
}


def path_a(m, utterance):
    """生徒の説明文を見て、誤概念があるかを LLM に判定させる（提案書の元設計）。"""
    prompt = f"""次は中学2年生が「{m['unit']}／{m['topic']}」について自分の言葉で説明したものです。

## 正しい理解
{m['correct']}

## 生徒の説明
<STUDENT_ANSWER>
{utterance}
</STUDENT_ANSWER>

この説明に**誤った理解（誤概念）が含まれているか**を判定してください。

注意:
- 説明が**短い・不完全**なだけで、書かれている内容自体が誤っていないなら has_misconception は false です
- 言い落としと誤りを混同しないでください
- 判断がつかないときは confidence を low にしてください"""
    return gen(prompt, JUDGE_SCHEMA, temperature=0.0)


def path_a2(m, utterance):
    """開放型。正解を渡さず「誤りがあれば指摘しろ」とだけ言う。

    経路A は正しい理解を渡した上での2値判定なので、実は文献の設定より簡単になっている。
    製品の実態（単元をまたいで自由に話される）に近いのはこちら。
    """
    prompt = f"""次は中学2年生が理科について自分の言葉で説明したものです。

<STUDENT_ANSWER>
{utterance}
</STUDENT_ANSWER>

この説明に**誤った理解（誤概念）が含まれているか**を判定してください。

注意:
- 説明が**短い・不完全**なだけで、書かれている内容自体が誤っていないなら has_misconception は false です
- 判断がつかないときは confidence を low にしてください"""
    return gen(prompt, JUDGE_SCHEMA, temperature=0.0)


# ------------------------------------------------------ 経路B: 誘発（新設計）
CORRECTED_SCHEMA = {
    "type": "object",
    "properties": {
        "corrected": {"type": "boolean", "description": "生徒が直前の発言の誤りを否定・訂正したか"},
        "confidence": {"type": "string"},
    },
    "required": ["corrected", "confidence"],
}


def path_b(m, state, seed):
    """AI生徒が誤概念を口にし、生徒が訂正するかを見る。

    LLM がやる判定は「説明が正しいか」ではなく「直前の文が否定されたか」だけになる。
    """
    # 1) 生徒が lure にどう反応するかを、知識状態に忠実に生成する
    if state == "misconception":
        stance = (
            f"あなたも同じことを信じています（{m['misconception']}）。"
            "だから相手に同意します。訂正はしません。"
        )
    elif state in ("correct", "ambiguous"):
        stance = (
            f"あなたは正しく理解しています（{m['correct']}）。"
            "だから相手の言っていることは違う、と指摘して直します。"
        )
    else:
        stance = (
            f"あなたは正しく理解しています（{m['correct']}）が、説明は苦手です。"
            "相手の言っていることが違うことには気づくので、**うまく説明できなくても否定はします**。"
            "「いや、ちがう気がする」「なんか違う」のような言い方でよい。"
        )

    react_prompt = f"""あなたは日本の中学2年生です。理科の「{m['unit']}／{m['topic']}」について
友達（後輩）に教えています。後輩がこう言いました。

「{m['lure']}」

## あなたの立場
{stance}

## 話し方
- **20〜70字**。話し言葉
- 中学生らしく。教科書口調にしない
- バリエーション番号 {seed}

返事だけを utterance に入れてください。"""
    reply = gen(react_prompt, UTTER_SCHEMA, temperature=1.3)["utterance"]

    # 2) 「訂正されたか」だけを判定する。正誤の内容判断はしない
    judge_prompt = f"""ある人が次の発言をしました。

発言A: 「{m['lure']}」

相手はこう返しました。

<STUDENT_ANSWER>
{reply}
</STUDENT_ANSWER>

**相手は発言Aの内容を否定・訂正しましたか。**

- 「違う」「そうじゃない」など、内容を打ち消していれば corrected = true
- 同意した、あいまいに流した、話題を変えた場合は corrected = false
- **正しいかどうかの判断はしないでください。** 否定されたかどうかだけを見ます"""
    v = gen(judge_prompt, CORRECTED_SCHEMA, temperature=0.0)
    return reply, v


# --------------------------------------------------------------------- 集計
def kappa(tp, fp, fn, tn):
    """Cohen's kappa（2値）。"""
    n = tp + fp + fn + tn
    if n == 0:
        return 0.0
    po = (tp + tn) / n
    pe = ((tp + fp) * (tp + fn) + (fn + tn) * (fp + tn)) / (n * n)
    return (po - pe) / (1 - pe) if pe != 1 else 0.0


def report(rows):
    print("\n" + "=" * 68)
    print("結果")
    print("=" * 68)

    for path in ("A", "A2", "B"):
        # 陽性 = 「この生徒は誤概念を持っている」と検出した
        tp = fp = fn = tn = 0
        band = defaultdict(lambda: [0, 0])  # state -> [誤り数, 件数]
        for r in rows:
            truth = r["state"] in catalog.POSITIVE_STATES
            pred = r[f"pred_{path}"]
            if pred and truth:
                tp += 1
            elif pred and not truth:
                fp += 1
            elif not pred and truth:
                fn += 1
            else:
                tn += 1
            band[r["state"]][1] += 1
            if pred != truth:
                band[r["state"]][0] += 1

        prec = tp / (tp + fp) if tp + fp else 0.0
        rec = tp / (tp + fn) if tp + fn else 0.0
        f1 = 2 * prec * rec / (prec + rec) if prec + rec else 0.0
        name = {"A": "経路A（正解を渡して説明文を判定する）",
                "A2": "経路A2（正解を渡さない開放型の判定）",
                "B": "経路B（誤概念を誘発して訂正を見る）"}[path]
        print(f"\n--- {name} ---")
        print(f"  precision {prec:.2f}   recall {rec:.2f}   F1 {f1:.2f}   κ {kappa(tp, fp, fn, tn):.2f}")
        print(f"  TP {tp}  FP {fp}  FN {fn}  TN {tn}")
        if tp:
            print(f"  真の検出1件あたりの誤警報: {fp / tp:.2f} 件")
        print("  帯別の誤判定率:")
        for st in catalog.STATES:
            bad, tot = band[st]
            if tot:
                mark = {"partial": "  ← 主要ターゲット層", "ambiguous": "  ← 表層に誤概念の語が出る帯"}.get(st, "")
                print(f"    {st:<14} {bad}/{tot} = {bad/tot:.0%}{mark}")

    # 誤警報の中身を見せる（partial を誤概念と誤判定した例が最も有害）
    bad = [r for r in rows if r["state"] not in catalog.POSITIVE_STATES and r["pred_A2"]]
    if bad:
        print(f"\n--- 経路A が『説明が不完全なだけ』を誤概念と誤判定した例（{len(bad)}件中3件） ---")
        for r in bad[:3]:
            print(f"  [{r['id']} {r['state']}] {r['utterance']}")
            print(f"      → AI:「{r['which_A2']}」")

    bad_b = [r for r in rows if r["state"] not in catalog.POSITIVE_STATES and r["pred_B"]]
    if bad_b:
        print(f"\n--- 経路B が同じことをした例（{len(bad_b)}件） ---")
        for r in bad_b[:3]:
            print(f"  [{r['id']}] 返事: {r['reply']}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--reps", type=int, default=3)
    ap.add_argument("--quick", action="store_true", help="誤概念2件だけで回す")
    args = ap.parse_args()

    ms = catalog.MISCONCEPTIONS[:2] if args.quick else catalog.MISCONCEPTIONS
    total = len(ms) * len(catalog.STATES) * args.reps
    print(f"モデル: {MODEL}")
    print(f"合成生徒: {len(ms)}誤概念 × {len(catalog.STATES)}状態 × {args.reps}反復 = {total}人")
    print(f"API呼び出し: 約 {total * 5} 回\n")

    rows = []
    n = 0
    for m in ms:
        for state in catalog.STATES:
            for rep in range(args.reps):
                n += 1
                seed = rep + 1
                try:
                    utt = make_student(m, state, seed)
                    a = path_a(m, utt)
                    a2 = path_a2(m, utt)
                    reply, b = path_b(m, state, seed)
                except Exception as e:
                    print(f"  [{n}/{total}] {m['id']}/{state} 失敗: {str(e)[:90]}")
                    continue
                rows.append({
                    "id": m["id"], "topic": m["topic"], "state": state, "rep": seed,
                    "utterance": utt,
                    "pred_A": bool(a["has_misconception"]), "which_A": a.get("which", ""),
                    "conf_A": a.get("confidence", ""),
                    "pred_A2": bool(a2["has_misconception"]), "which_A2": a2.get("which", ""),
                    "reply": reply,
                    # 経路Bの陽性 = 「訂正されなかった」＝ 誤概念を持っている、と判断する
                    "pred_B": not bool(b["corrected"]), "conf_B": b.get("confidence", ""),
                })
                t = state in catalog.POSITIVE_STATES
                ok_a = "○" if rows[-1]["pred_A"] == t else "×"
                ok_a2 = "○" if rows[-1]["pred_A2"] == t else "×"
                ok_b = "○" if rows[-1]["pred_B"] == t else "×"
                print(f"  [{n}/{total}] {m['id']} {state:<14} A:{ok_a} A2:{ok_a2} B:{ok_b}")

    out = HERE / "results.json"
    out.write_text(json.dumps(rows, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"\n生データ: {out}")
    report(rows)


if __name__ == "__main__":
    main()
