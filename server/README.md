# server — ディレクター（進行役）

会話の裏で理解カルテを更新し、次の一手を決める。**状態を持たない。**

```
端末（Flutter）
 ├─ Gemini Live へ WebSocket 直結（音声はここを通らない）
 ├─ 逐語・理解カルテを端末が保持
 └─ POST /api/director  { unitId, dossier, utterances, secondsLeft, turnCount }
                     →  { corrections, dossier, nextInstruction, lureId, shouldEnd, endReason }

Vercel（ステートレス）
 ├─ GET  /api/units     … 単元カタログと空のカルテ
 └─ POST /api/director  … カルテ更新 + 次の一手
```

理解カルテは「1台の端末が持つ1つの会話」の状態なので、端末が持ってリクエストごとに送る。
**DB もセッションもロックも要らない。**

## 動かす

```powershell
npm install
npm test          # 56件。ネットワーク不要
npm run test:live # 実際の Gemini に通す（GEMINI_API_KEY が要る）
```

## 設計の要点

### 誤概念は「判定」せず「誘発」する

生徒の自由記述を採点させない。**既知の誤概念を AI 自身が口にして、訂正するかを見る。**
判定の的が「この説明は正しいか」から「いま口にした X を否定したか」に狭まる。

> これは「LLM が判定しない」設計ではない。**的が小さくなる**設計。
> 実生徒データでの精度はまだ測れていない（アンケート回収待ち）。

だから守りを二重にしてある:

| 守り | 理由 |
|---|---|
| `ProbeResult` に `unclear` がある。迷ったらここへ倒す | 聞き流した・詰まった・話題が変わった、を `accepted` と区別する |
| **根拠の発話IDが無い判定は採用しない** | 根拠なしの `accepted` は、触れてもいない誤解を弱点として突きつける |
| `corrected` / `accepted` を `unclear` に戻さない | 一度ついた判断が揺れると復習の中身が毎回変わる |
| `toReview()` は `unclear` を含めない | 判断がついていないものを「できていない」側に置かない（C9） |

### 誤概念の文言は LLM に作らせない

[lure](lib/misconceptions.ts) は固定文。ディレクターが選ぶのは**どれを言うか**だけ。
毎回違う言い方をされると、訂正されたかの観測が条件のそろわない別々の試行になる。

**どれを言うかもコードが決める**（`nextProbe()`）。条件は機械的:
1. その概念を生徒が説明済み（説明の前に出すと、生徒はこちらの誘導に答えるだけになる）
2. まだ誘発していない

### カルテを空に戻さない

`jiyu-kenkyu-ai` の実測で、モデルが根拠を書き忘れただけで空に戻ると
充足度が 56%→31% まで巻き戻り、同じことを何度も説明させることになった。
`runDirector()` の突き合わせで**格下げと根拠なしの上書きを潰している**。

### 充足度はこちらで計算する

モデルの自己申告を使わない。**根拠のないスロットは status を無視して 0 点。**

## デプロイ

```powershell
vercel login          # 人手が要るのはここだけ
vercel link
vercel env add GEMINI_API_KEY production
vercel env add DIRECTOR_TOKEN production
vercel deploy --prod
```

端末側にはデプロイ先を渡す:

```powershell
pwsh ..\tools\run-dev.ps1 -DirectorUrl https://xxxx.vercel.app -DirectorToken xxxx
```

> [!warning] いまの門は認証ではない
> `DIRECTOR_TOKEN` は APK の中に平文で入る。取り出せる人は誰でも通せる。
> 止められるのは「URL を見つけただけの通りすがり」まで。
> **一般公開の前に本物の認証とレート制限へ入れ替える**（段階5）。
> 入れないと Gemini の請求が青天井になる。

## 単元を足す

`lib/units.ts` に概念を、`lib/misconceptions.ts` に誤概念を足す。
**対応する誤概念が無い概念は `npm test` が落とす** — 誘発できない概念は観測手段が無い。

学習指導要領のどの項目に対応するかは**未確認**。
いまは FCI 由来のカタログから逆算した区切りで、教材本体を作るときに突き合わせる。
