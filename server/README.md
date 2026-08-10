# server — ディレクター（進行役）

会話の裏で理解カルテを更新し、次の一手を決める。**状態を持たない。**

> [!CAUTION]
> **このworktreeの実装では**生成AI入口を公開環境で強制停止する。ローカルまたはVercel developmentで
> `DEKISUGI_INTERNAL_AI_TESTING=1` の場合だけ `/api/live-token`、`/api/director`、
> `/api/realtime-grant` を開く。
> production / preview、および `NODE_ENV=production` はフラグがあっても解除できず、認証後に
> `503 {"error":"generative_ai_unavailable"}` を返し、rate・quota・Googleを呼ばない。
> 学校や年齢による例外設定はない。公開再開にはレビュー付きのコード変更が必要。
>
> **2026-08-10現在、この停止差分はVercel productionへ未デプロイ。**
> 稼働中の旧本番は `GET /api/live-token` が200を返すことを読み取りで確認済み。
> 明示承認後に緊急停止のみを分離デプロイし、実APIの503を確認するまで
> 「本番は停止済み」と扱わない。

学校向けTeam API（admin / join / leave / summary / contribution）もproduction / preview、
および `NODE_ENV=production` では無条件に `503 {"error":"school_features_unavailable"}` を返す。ローカルまたはVercel
developmentで `DEKISUGI_INTERNAL_SCHOOL_TESTING=1` の場合だけ開き、AI用フラグとは分離する。
こちらも公開再開は環境変数操作ではなく、DPA・学校契約の確認を伴うコードレビューで行う。

Upstash / RevenueCatへ個人・端末・回答データを送る入口も別のguardで強制停止する。
`/api/subscription-sync`、`/api/revenuecat-webhook`、`/api/survey` のPOSTは、production / preview、
および `NODE_ENV=production` で無条件に
`503 {"error":"restricted_data_processing_unavailable"}` を返す。ローカルまたはVercel developmentで
`DEKISUGI_INTERNAL_RESTRICTED_DATA_TESTING=1` の場合だけ開く。既存記録を確認・削除できるよう、
管理者認証済みのsurvey GET / DELETEはこのguardの対象外とする。

### 外部契約を使わないLAN social

実在する別端末間のフレンズクエストと週次リーグは、上記Team APIやUpstashを
再開せず、管理PC上のLAN coordinatorとして分離している。`server/api/`外なので
VercelへFunction deployされない。自己署名TLSを生成し、Flutterが参加コード内の
SHA-256 fingerprintをpinする。詳細と起動方法は
[LAN social設計](../docs/lan-social-2026.md)を参照する。

管理PC向けにはmacOS arm64 / Windows x64 / Linux x64のNode SEA artifactを生成するworkflowがあり、実行先へ
repo、Node.js、npm、OpenSSLを要求しない。build・smokeは`npm run social:binary`と
`npm run social:binary:smoke`。macOS / Linuxは実行権限を保持するtar.gz、Windowsはzipへ固め、
`npm run social:binary:reproducible`で連続buildに加え、別の一時source directoryからも
SEA本体とarchive双方のSHA-256が一致することを確認する。
buildにはSEAを有効にした公式Node.js 26.5以上を使う。Homebrew版Nodeで
`Single executable application is disabled`になる場合は、公式配布binaryを
`DEKISUGI_SEA_NODE=/absolute/path/to/node`で指定する。GitHub Actionsは
`actions/setup-node`の公式Node.js 26.7.0を使う。
Node SEAが現在サポートしないmacOS x64はartifact対象に含めず、Intel Macでは
Node.jsを入れたsource起動を使う。
署名・notarize前のため現状はpilot用で、学校配布済みとは扱わない。

```
端末（Flutter）
 ├─ Gemini Live へ WebSocket 直結（音声はここを通らない）
 ├─ 逐語・理解カルテを端末が保持
 └─ POST /api/director  { unitId, dossier, utterances, secondsLeft, turnCount }
                     →  { corrections, dossier, nextInstruction, lureId, lureText, shouldEnd, endReason }

Vercel（ステートレス）
├─ GET  /api/units     … 単元カタログと空のカルテ
├─ POST /api/director  … カルテ更新 + 次の一手
├─ POST /api/realtime-grant … OpenAI Realtime短命credential（公開環境は停止）
├─ POST /api/subscription-sync … RevenueCat から Plus を再照会（公開環境は停止）
├─ POST /api/revenuecat-webhook … Plus 状態変更の受信（公開環境は停止）
└─ POST /api/survey    … アンケート回答の保存（公開環境は停止）
```

理解カルテは「1台の端末が持つ1つの会話」の状態なので、端末が持ってリクエストごとに送る。
会話内容のDBは持たない。利用枠・再開窓・Plus entitlement の運用状態だけを KV に持つ。

## 動かす

```powershell
npm install
npm test          # ネットワーク不要
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

次にproductionへデプロイしてよいのは、上記の強制停止を反映する緊急停止リリースだけ。
公開AI・学校機能・制限対象データ処理を再開するデプロイは行わない。production反映は
差分レビューと明示承認を受け、反映後に各APIが`503`であることを確認する。

18歳以上に限定した内部開発確認では、ローカルまたはVercel developmentにだけ
`DEKISUGI_INTERNAL_AI_TESTING=1` を設定できる。production / preview、または
`NODE_ENV=production` では同じ値を設定しても開かない。
公開再開は環境変数操作では行わず、規約確認を伴うレビュー付きコード変更で判断する。

制限対象データ処理を内部確認するときも、ローカルまたはVercel developmentだけに
`DEKISUGI_INTERNAL_RESTRICTED_DATA_TESTING=1` を設定する。production / previewでは同じ値を
設定しても開かない。AI・学校Teamの内部テストフラグとは独立している。

端末側にはデプロイ先を渡す:

```powershell
pwsh ..\tools\run-dev.ps1 -ServerUrl http://localhost:3000
```

## 利用枠（無料は1日2セッション）

以下は許可された内部テスト環境だけで動作する。停止中は残数照会を含め503となり、
枠・レート制限・再開窓を一切消費しない。

```
POST /api/live-token  → 会話用のアクセストークンを発行し、1枠引く
GET  /api/live-token  → 今日あと何回始められるかを、引かずに返す
POST /api/realtime-grant → OpenAI Realtime用の短命credentialを発行し、1枠引く
```

`/api/realtime-grant` は既存Vertex経路を置換せずに追加した移行候補。OpenAI標準API keyを
端末へ返さず、`/v1/realtime/client_secrets` で作った短命credentialだけを返す。
`OPENAI_API_KEY`、OpenAI側で確認済みのZDRを表す
`OPENAI_REALTIME_ZDR_APPROVED=1`、専用HMAC鍵
`OPENAI_SAFETY_IDENTIFIER_SECRET`の全てが必要で、どれか欠ければrate・quotaより前に503となる。
Flutterとのgrant契約と未成年向けの未完了条件は
[OpenAI Realtime移行境界](../docs/openai-realtime-migration.md)に固定する。
client secretは30秒で失効させるが、公式仕様上は期限内の複数session作成とclient側のsession設定
上書きが可能であるため、この経路単体を公開用の費用・学習persona強制境界とは扱わない。

### なぜ端末側で回避できないか

**資格情報はサーバにしか無い。** 端末は `/api/live-token` を通さないと会話を始められない。
Vertex のアクセストークン自体は約60分有効で、会話時間のタイマーには使えない。
Vertex がセッションを約9分で切る実測と、トークン発行回数の記録を組み合わせて上限を作る。

| 値 | |
|---|---|
| 無料枠 | 2セッション/日（日本時間0時に戻る） |
| 1セッション | およそ10分。切断時は12分の窓内で最大3回まで再開 |
| Plus | RevenueCat が有効と確認した期間は日次の会話枠なし |

**先に1枠引いてからトークンを渡す。** 途中切断は、開いた再開窓の中で回数を制限して戻す。

Plus は端末が申告する entitlement を信じない。許可された内部テスト環境では
`/api/subscription-sync` と webhook を受けたサーバーが、RevenueCat REST API から現在値を
読み直して付与・取消する。公開環境では制限対象データ処理guardが先に503を返す。

### 会話設定はサーバが持つ

> [!important] トークンに焼いた設定が勝つ（実測）
> `liveConnectConstraints.config` に入れなかった設定は、端末が送っても効かない。
> 文字起こしを端末側だけで指定したら、音声は返るのに**文字起こしが空**になった。
> 入れたら返ってきた。
>
> 副作用として、ペルソナと `[DIRECTOR]` の約束を**端末から改変できなくなる**。
> `lib/live-config.ts` が唯一の出どころ。

## 守り

| 何 | 状態 |
|---|---|
| 端末ごとの署名付きトークン（`/api/register`） | 稼働中 |
| 生成AI全体guard（production / preview / `NODE_ENV=production`は解除不能） | **強制停止** |
| 制限対象データ処理guard（subscription / webhook / survey POST） | **強制停止** |
| レート制限（端末 80/時・400/日、全体 20000/日） | **Upstash Redis で稼働中** |
| 本人確認・アカウント | **無い**（段階5 の範囲外） |

`AUTH_SECRET` を変えると発行済みトークンが全部失効する ＝ **緊急時の停止スイッチ**。

> [!note] レート制限が本物かは外から確認できる
> `/api/director` の応答ヘッダ `X-RateLimit-Backend` が `kv` なら Upstash に、
> `memory` ならプロセス内カウンタに落ちている。
> memory はインスタンスをまたがないので**気休め**。
>
> 確認（残り回数が減っていけば、リクエストをまたいで数えられている）:
> ```powershell
> (Invoke-WebRequest "$base/api/director" -Method POST -ContentType 'application/json' `
>    -Headers @{Authorization="Bearer $tok"} -Body $body -SkipHttpErrorCheck).Headers['X-RateLimit-Remaining']
> ```

> [!warning] これは本人確認ではない
> 誰でも `/api/register` を叩けばトークンを取れる。守っているのは
> 「同じ端末であること」まで。端末を大量に作られると1端末あたりの制限は
> 意味を失うので、**全体の1日上限**を別に持っている。

## 単元を足す

`lib/units.ts` に概念を、`lib/misconceptions.ts` に誤概念を足す。
**対応する誤概念が無い概念は `npm test` が落とす** — 誘発できない概念は観測手段が無い。

学習指導要領のどの項目に対応するかは**未確認**。
いまは FCI 由来のカタログから逆算した区切りで、教材本体を作るときに突き合わせる。
