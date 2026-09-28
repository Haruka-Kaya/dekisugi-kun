# AGENTS.md — dekisugi-kun

> **English abstract (for judges):** This file is the product constitution.
> Dekisugi-kun is a middle/high-school science app (Flutter + Vercel) where
> students *teach* an AI companion — the AI never answers first (learning by
> teaching). C1–C9 pin evidence-based invariants: hide the textbook while the
> student explains (C2), never make points the main motivator (C5), text input
> is a first-class peer of voice (C8), and never declare a "weakness" — gaps
> are elicited and observed (C9). See `docs/product-overview-en.md` for the
> full English overview.

**セッション開始時の行動**: このファイルを全部読めば全体像は分かる。`git log -1` で現在地を確認し、`CLAUDE.md` の「現況」セクションを読む。**「全体像を把握して」でコードをスキャンし直さない。**

---

## 一行で言うと

中高生が AI に理科を「教える」学習アプリ（Flutter + Vercel）。AI が先に正解を教えない。生徒が説明 → AI が固定の問い返し → 弱点だけ残る。

---

## 現在地（2026-09-14）

| 項目 | 状態 |
|---|---|
| 安定ブランチ | `main` = `f7a599d` |
| 作業ブランチ | `codex/full-game-ui-overhaul`（UIオーバーホール中） |
| ゲームUIフェーズ | 実施中 |
| テスト | `app` 1209件・`server` 373件（いずれも通信なし） |
| 年齢規約問題 | **未解決** — 外部AI会話は学校・未成年に配布禁止（`docs/age-restriction.md` §3） |
| アンケート n数 | 18件（目標40件。設計根拠がまだデータで支えられていない） |
| iOS実機確認 | 未実施（シミュレータのみ）|

---

## ファイルマップ（読むときだけ開く）

```
app/lib/
  main.dart          エントリポイント
  screens/           全画面（〜screen.dart / 〜dialog.dart）
  services/          API通信・音声・LAN
  models/            データ型
  config/            定数・テーマ

server/
  test/              *.test.ts 通信なし・*.live.test.ts は DEKISUGI_LIVE=1 必須
  public/survey/     誘発アンケート配信

tools/
  misconception-survey/  check_items.py・analyze.py

docs/
  age-restriction.md     ← 学校導入前に必ず読む
  curriculum-expansion-2026.md
  game-redesign-2026.md
```

---

## 絶対に崩さない約束（プロダクト憲法 C1〜C9）

違反する変更・提案をしない。数値は論文根拠で確定している。

| # | 内容 |
|---|---|
| C1 | 学習開始前に「このあと説明してもらう」を成立させる |
| C2 | 説明フェーズで教材を画面から隠す |
| C3 | AI は必ず訂正・補完を返す |
| C4 | AI は質問を返す（聞くだけ禁止）|
| C5 | **ポイント付与を主動線にしない**（内発動機 d=−0.40）|
| C6 | **streak をゼロに戻さない**（猶予枠の残数を明示）|
| C7 | 700 ms 以内に「聞いている」を返す |
| C8 | テキスト入力を音声と対等な第一級の経路にする |
| C9 | 「弱点です」と断定しない。誘発して観測する |

---

## よく使うコマンド

```bash
# テスト
cd app && flutter test                          # 1209件・約20秒
cd server && npm test                           # 373件・2.6秒
DEKISUGI_LIVE=1 npx tsx --test test/grant.live.test.ts   # 本番接続・課金あり

# 設問カタログ検査（項目を足したら必ず）
python tools/misconception-survey/check_items.py

# ビルド
cd app && flutter build apk --split-per-abi
cd app && flutter build ios --release --no-codesign   # 署名なし確認
```

---

## ブランチとデプロイ

- `main` = Vercel 本番（Production Branch 名は逆転させてある）
- `dev` = Vercel preview
- 手動デプロイ: **リポジトリ直下**から `vercel --prod`（`server/` から叩かない）
- Root Directory は `server/`

---

## やってはいけないこと

- 外部AI会話（Vertex / OpenAI Realtime）を学校・未成年に繋ぐデプロイ
- Live API の `/api/live-token` や `/api/director` を production で有効化
- C1〜C9 に反する機能変更
- `DEKISUGI_LIVE=1` なしで live テストを実行（本番課金）
- 設問カタログを変えた後に `check_items.py` をスキップ

---

## 未解決のブロッカー

1. **年齢規約** — Google Cloud TOS §20(d) で中高生向け生成AI禁止。学校展開前に別プロバイダー移行 or Google 個別契約が必要
2. **外部AI配布停止差分が本番未反映**（2026-08-10 時点）— 学校配布前に `/api/live-token` を本番で 503 にする
3. **iOS 実機未確認** — 録音・実再生・権限拒否・background 停止は未確認
4. **アンケート n=18** — 誘発効果の根拠がまだデータで支えられていない
