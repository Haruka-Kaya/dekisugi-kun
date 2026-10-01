# Shipaton 2026 — Next Gen Award（学生枠）提出チェックリスト

対象賞: **Next Gen Award**（在学生のみ。ストア公開不要・審査は demo video + 公開リポジトリ）。
締切: **2026-09-30 23:45 PDT**（Submission Period 終了）。
一次ソース: https://revenuecat-shipaton-2026.devpost.com/rules

> このファイルは Next Gen 枠の提出物だけを扱う。一般枠（ストア公開必須）の
> 作業は `docs/shipaton-2026.md` と `docs/play-console.md` を参照。

---

## 1. ルール上の必須条件（現状）

| 条件 | 状態 | 根拠・残作業 |
|---|---|---|
| iOS / iPadOS / macOS / Android 向けの動作するアプリ | ✅ | Flutter Android。`flutter run` で端末内モードがネットワークなしで動く |
| RevenueCat SDK が≥1件の購入（または RC Ads）を動かす | 🟡 コード済み・実演要設定 | `purchases_flutter` 実装済み（`app/lib/services/revenuecat_purchase_adapter.dart`）。動画で購入を実演するには RevenueCat Test Store（`REVENUECAT_USE_TEST_STORE` + `test_` 公開キー）のプロジェクト設定が必要 |
| 公開済みでない新規アプリ | ✅ | ストア未公開 |
| リポジトリ public + OSS ライセンス（About 検出） | 🟡 | `LICENSE`（MIT）追加済み。**GitHub で private → public への変更はユーザー操作** |
| ソース・素材・実行手順がリポジトリに全てある | ✅ | README に英語 quick start 追加済み（同梱 catalog でオフライン動作） |
| <2 分のデモ動画（YouTube/Vimeo 公開） | 🟡 動画完成・公開未確認 | `docs/shipaton-demo-2026/shipaton-demo-v8.mp4`（84.17秒・1920×1080横長・英語ナレーション／字幕。現行Field NotebookをAndroidエミュレーターで撮影し、予想→教材→説明→問い返し／ヒント→記録→RevenueCat Test Store購入と特典を収録）。物理端末QA・外部公開・提出とは区別する |
| テキスト説明（英語） | ✅ | `docs/shipaton-submission-copy.md` 更新済み |
| 1024×1024 アイコン | ✅ | `docs/store/icon-1024.png` |
| ≥1枚のスクリーンショット 1179×2556・端末フレームなし | ✅ | `docs/store-shots-2026/devpost/shot-1179x2556.png` |
| Devpost 登録は学生/学術メール（JetBrains/swot で検証） | ⬜ | ユーザー操作 |
| 未成年の場合: 保護者同意フォーム | ⬜ | https://forms.gle/Gx2Cr4X8WPk9V1q77 を締切までに提出（該当する場合） |
| 提出物は英語 or 英訳付き | 🟡 | 動画に英語字幕。リポジトリ本文は日本語だが英語 quick start + 英語提出文で対応 |

## 2. Plus（RevenueCat 購入）の正直な現状

- 実装: paywall → `purchasePackage` → entitlement `plus` → 端末内特典付与、まで実配線済み。サーバ側再照会（`/api/subscription-sync`・`/api/revenuecat-webhook`）も実装・テスト済みだが、現状は Live 会話枠（提供停止中）のゲートにのみ使う。
- 特典（応援プラン）: 購入・復元で aurora マスコット（`cosmetic.path-mascot.aurora.v1`）を `learning_cosmetic_grants` 台帳へ即付与 — **現行配布ビルドで実際に発動し、entitlement 失効後も保持される**。加えてカルテ画面に「保護者の方へのレポート」カードが開き、訂正できた思い込みを共有できる文面をコピーできる。Live 会話枠の上限解除は同機能の提供再開時に有効になる扱いで、paywall・提出文ともその旨を明記済み。
- 動画で購入を見せる場合は Test Store ビルドで実演する（`REVENUECAT_USE_TEST_STORE=true --dart-define` + `test_` キー）。ストアアカウント不要。

## 3. ユーザー側の残作業（Devin にはできない）

1. **GitHub → Settings → Danger Zone → Change visibility → Public**（LICENSE 検出を確認）
2. RevenueCat 無料アカウント → Test Store アプリ + entitlement `plus` + offering を設定 → `test_` 公開キーを取得
3. Devpost アカウント（学生メールで登録）→ Enter a Submission
4. 未成年なら保護者同意フォーム提出
5. デモ動画を YouTube か Vimeo に公開して URL を提出フォームへ
6. 任意: `#Shipaton #BuildInPublic` 投稿で別賞も狙える

## 4. 審査基準（Next Gen）

- アイデアが明確・有用・面白い・独創的か
- 動画とリポジトリから中核機能が分かるか（meaningful progress toward a working app）
- RevenueCat を購読/購入/広告などに思慮深く使っているか
- 技術選択・プロダクト思考・作り込みの丁寧さ

→ 「AI が先に答えを教えない」「音声と文字が対等」「自由記述を採点しない設計判断」は
副文で前面に出す（`docs/shipaton-submission-copy.md`）。
