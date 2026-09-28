# Shipaton 2026 — 勝つための提出計画

更新: 2026-08-11

> [!warning] この文書は旧Live構想を含む提出計画の履歴です
> AI後輩とのLive会話、本人発話の保存、daily Live課金を前提にした本文・台本は、
> 現行productionの説明や提出文へ流用しないでください。現在の正本は
> `README.md`、`docs/game-redesign-2026.md`、`docs/game-goal-completion-matrix.md`です。
> 現行は端末内Teach-back＋固定問い返しで、音声PCM・自由文・選択肢IDを保存／送信しません。

> [!danger] 旧Vertex Live経路を有効化したビルドは提出しない
> Google Cloud Service Specific Terms §20(d) により、中高生向け本アプリで現在の
> 生成 AI 構成を公開できない。Store 提出、審査員への外部配布、学校実証は、
> 未成年向け利用が可能な AI 基盤への移行または Google との書面契約まで停止する。
> 年齢ゲートや保護者同意だけでは解除しない。

## 1. 作品の一文

> Dekisugi turns studying into a teach-back mission: explain one science idea,
> catch an AI student's misconception, and prove you can use the idea in a new case.

日本語: 「理科を覚える」のではなく、AI後輩へ教え、思い込みを見破り、別の場面でも使えることを確かめる学習ミッション。

## 2. 公式要件と現在地

公式情報:

- [How We Judge Shipaton](https://www.shipaton.com/blog/how-we-judge-shipaton)
- [Shipaton Rules](https://revenuecat-shipaton-2026.devpost.com/rules)
- [RevenueCat Flutter configuration](https://www.revenuecat.com/docs/getting-started/configuring-sdk)
- [RevenueCat App User IDs](https://www.revenuecat.com/docs/customers/identifying-customers)
- [OpenAI Under 18 API Guidance](https://developers.openai.com/api/docs/guides/safety-checks/under-18-api-guidance)
- [OpenAI API data controls](https://developers.openai.com/api/docs/guides/your-data)

| 公式の通過条件 | 現在地 | 完了条件 |
|---|---|---|
| iOS / Androidの機能するモバイルアプリ | Flutter実装済み。現在の統合差分は正式署名・Store審査未完了 | AI基盤移行・規約再確認後に両Storeの公開URLを提出 |
| RevenueCat SDKでIAP | 基盤実装中 | public SDK key、Offering、購入・復元、webhookを本番確認 |
| アプリのデモ動画 | 旧UI動画のみ | 下記台本で英語1:45〜1:55版を再撮影 |
| 英語または英訳つき提出 | 未作成 | 説明・字幕・フォーム回答を英語化 |
| 1024×1024 icon | `docs/store/icon-1024.png`あり | Store実査と提出 |
| 1179×2556 screenshot、端末枠なし | 現UIを`docs/store-shots-2026/shipaton/`へ生成し、寸法・RGB・alphaなし・通知なしを検証済み | 提出フォーム上のupload検証 |
| 審査員が全機能を試せる | 未設定 | 無料トライアルまたはpromo code |
| 動画は2分未満 | 台本は下記 | 1:45〜1:55の英語字幕付き編集版を提出 |
| 通信が無い審査環境 | 同意前30秒ミッションに加え、同梱教材から4段階の端末内練習まで実装済み | Store用ビルドを機内モード・クリーンインストールで実機確認 |

提出期間は公式ルール上 2026-08-01〜2026-09-30。締切直前ではなく、Storeレビューの差し戻し期間を残して公開する。

## 3. 狙う評価軸

### Design

見た目だけではなく、理解証拠によって次の画面と課題が変わることを見せる。

- TEACH: 教材を閉じ、自分の言葉で説明
- REPAIR: 決着しなかった条件・理由を組み直す
- CASE: 答えを見ず、具体場面を予想して原理と結ぶ
- CLEAR: AIが実際に口にした固定誤概念を、後続の本人発話で理由付き訂正したときだけ
- 報酬はXPではなく、本人が実際に話した一文

### 第二候補: Best Game

ゲームの外見ではなく、学習行為をゲームループにする。

- 3段階の明確な現在目標
- AI後輩の反論による相互作用
- 失敗をREPAIRへ、成功を翌日のCASEへ分岐
- 1概念・最大6往復の短いミッション
- ポイント、ガチャ、ランキング、喪失圧力は使わない

### Peace / Impact

- 声と文字を同格にし、教室・電車・家庭でも使える
- 名前・メール・広告IDを持たず、学習逐語と理解記録は端末内
- AIは正解を教える役ではなく、学習者から説明を引き出す後輩
- 学校・18歳未満は外部サービスへ接続せず、同梱教材と固定チェックポイントだけの端末内モードを選べる
- 未成年利用を許可する外部契約、学校向けデータ境界、安全な教材活動、固定された誤概念で運用可能性を示す

### Grand Prize

審査基準にはlaunchとmeasurable tractionが含まれる。ただし現Vertex版では公開・外部計測へ進まない。
AI基盤の移行と同意・プライバシーの再確認後に、以下を計測する。

- 同意完了 → 教材読了 → 初発話 → MISSION CLEAR の到達率
- 初回CLEAR翌日のCASE開始率
- CASE CLEAR率
- D1 / D7再訪（発話本文・音声は分析へ送らない）
- 無料枠到達 → Plus trial開始 → 継続率

分析を導入する場合は、イベント名・時刻・匿名UUID・ミッション種別・成否だけに限定し、プライバシー説明を同時に更新する。

## 4. 2分未満デモ台本（英語、1:50目標）

公式上、提出動画そのものが2分未満。編集マージンを残すため1:50を目標にし、ロゴアニメーションや長い設定説明を入れない。

### 0:00–0:08 — Cold open: catch the misconception

画面: デキすぎ君の固定思い込み → 本人の理由付き訂正 → MISSION CLEARを3カットで見せる。

On-screen subtitle:

> Do not choose the answer. Teach it. Defend it. Use it.

### 0:08–0:18 — Problem + promise

画面: HomeのTODAY MISSIONをすぐ表示。

Voiceover:

> Most study apps ask students to recognize the right answer. Dekisugi asks them to produce it: teach one science idea, challenge a misconception, and use it in a new situation.

### 0:18–0:30 — Choose one mission

画面: 作用・反作用を選択。1概念だけであることを映す。

Voiceover:

> Each mission focuses on one concept and one learning action. No XP, no leaderboard, and no ten-minute tool-like dashboard.

### 0:30–0:42 — Prepare a teaching tactic

画面: 教材の末尾まで読み、「しくみ・理由から」を選ぶ。

Voiceover:

> The student reads a short source, chooses how to explain it, and then the source disappears. That forces recall instead of reading aloud.

### 0:42–1:08 — Teach and face the misconception

画面: 文字または音声で説明し、実再生／明示再読の後にデキすぎ君が固定問い返しを出す。
誤答ならヒントを使って説明を言い直し、正解や自由文を保存せずHUDが2/3へ進む。

Student line:

> The two objects push on each other with equal force in opposite directions.

AI misconception example:

> But doesn't the heavier object push with more force?

Student correction:

> No. The forces are equal. The lighter object changes motion more because the same force acts on less mass.

Voiceover:

> The AI never gives away the lesson. A mission clears only after the learner explains the concept and corrects a misconception the AI actually said, with a reason.

### 1:08–1:24 — Evidence, not points

画面: MISSION CLEARと本人の生発話ノート。

Voiceover:

> The reward is not a coin. It is the learner's own sentence, stored on the device as evidence of what they can now explain.

### 1:24–1:40 — The loop changes tomorrow

画面: 翌日のCASE通知CTA、HomeのCASE MISSION、CASE FILE。

Voiceover:

> Success does not end the course. The next mission removes the lesson answer and asks the learner to predict a concrete case. An unresolved attempt becomes a focused repair mission instead.

### 1:40–1:50 — Why this can ship

画面: 音声/文字の同格操作、匿名・端末保存の短い字幕、Plus面。

Voiceover:

> Dekisugi works by voice or text, keeps learning records on-device, and gives every student the complete core loop for free. Plus unlocks more daily live missions through RevenueCat.

End card:

> Dekisugi — Learn science by teaching it.

## 5. 収益化の線引き

無料でも「教材 → TEACH → 誤概念訂正 → CLEAR → CASE」の学習価値を完結させる。

Free:

- 1日2回のLiveミッション
- 全教材、文字入力、本人のノート、REPAIR / CASE
- 通知と端末内進捗

Plus:

- 1日のLiveミッション上限を解除（rate limitと1回の時間上限は維持）
- Storeの無料トライアル

禁止する課金:

- 本人の過去ノートを人質にする
- 文字入力やアクセシビリティを有料化する
- REPAIRだけを有料にして失敗した生徒を罰する
- streak喪失回避、ガチャ、ランダム報酬

RevenueCatのApp User IDは端末生成の推測困難なUUIDだけを使う。名前、メール、広告ID、逐語、音声、学習内容をcustomer attributesへ送らない。

## 6. 公開前の実動作チェック

1. RevenueCat Test Storeで購入・復元・期限切れを確認
2. webhookまたは信頼できるserver-side照会で、client自己申告なしに`ent:<did>`へ反映
3. 無料端末は3回目が402、Plus端末は3回目も200
4. iOS sandbox / Google Play internal testingで同じ確認
5. 1179×2556の新UIスクリーンショットを再生成し、OCR・RGB・alpha・四隅を検査
6. 1:45〜1:55の動画に英語字幕を焼き込み、音声なしでも意味が通ることを確認
7. promo codeまたはtrialで審査員がPlusを試せる
8. Store URL、privacy URL、support URL、bundle/packageを提出フォームで実査

## 7. 未完了ブロッカー

- 未成年向け利用を明示的に許容するAI基盤への移行。OpenAI Realtimeを使う場合は、対象年齢に必要なZDR承認、年齢に応じたフィルタ、監視・報告・エスカレーション、年齢確認をセットで完了する
- 端末内モードをStore用ビルドのクリーンインストール・機内モードで実機確認すること
- RevenueCat project / entitlement / offering / products / public SDK keys
- App Store / Google Playの正式署名と審査
- RevenueCat webhookの本番secretとentitlement同期
- Google Play推薦面向けの4枚目と、実Store設定後のPlusを含む最終マーケティングセット
- 英語2分未満動画
- Store公開後のactivation / D1計測と初期traction
