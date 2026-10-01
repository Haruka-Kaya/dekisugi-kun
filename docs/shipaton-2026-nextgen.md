# Shipaton 2026 — Next Gen 提出チェックリスト

**締切: 2026-10-02 04:00 日本時間**（10月1日正午PDTへ延長）。
[公式延長告知](https://revenuecat-shipaton-2026.devpost.com/updates/46730-deadline-extended)、
[公式規約](https://revenuecat-shipaton-2026.devpost.com/rules)。
Next Genは在学生向け。動画と公開OSSコードが審査対象で、ストア公開は不要。

## 提出物の現在地

| 条件 | 状態 |
|---|---|
| 対象端末上で動くアプリ | Androidネイティブの実操作を撮影。エミュレーター証拠。物理端末の音声QAは別途未完 |
| RevenueCat購入 | Native Test Storeで購入完了、Aurora Cape付与・装備、保護者レポート表示を確認。実課金なし |
| 公開コード + OSSライセンス | publicへ変更済み。匿名GitHub APIで公開状態・MITを確認 |
| ソース・素材・実行手順 | [英語審査ガイド](nextgen-review-guide.md)とREADMEから案内 |
| 2分以内の英語動画 | [v13 MP4](shipaton-demo-2026/shipaton-demo-v13.mp4)、67.4秒、1080×1920縦型、英語音声・字幕。単一の実画面・BGMなし。[Vimeo公開URL](https://vimeo.com/1232117345) |
| 英語提出文 | [Devpost欄ごとの原稿](shipaton-submission-copy.md)完成。外部下書きへの反映は未確認 |
| 1024×1024アイコン | `docs/store/icon-1024.png` |
| 1179×2556・フレームなし画像 | `docs/store-shots-2026/devpost/shot-1179x2556.png`。現行UIを指定サイズで直接撮影 |
| 在学生・学術メール | 本人のアカウントで確認が必要。資格を推測しない |
| 未成年の保護者同意 | 該当する場合に公式フォームの提出を確認する |
| Devpost最終提出 | ユーザー申告は未提出・下書き中。提出完了表示は未確認 |

## Plusの実装と実演の範囲

`purchases_flutter`のpackage取得、購入・復元、`plus` entitlementと端末内特典を
実装。撮影は成人の個人テストプロフィールとTest Storeを使った。
Auroraのgrantと装備、保護者レポートは実際のUIで確認した。
キャッシュされた着せ替え一覧の更新には再起動が必要だった。

サーバ再照会・webhookコードも存在するが、別の会話枠同期はリトライ表示だった。
本番ストア購入・同期成功・Live会話の提供は主張しない。
必修教材は無料のまま、外部生成AIは停止したままにする。
[実行・再現手順](nextgen-review-guide.md)、[課金設定](monetization-setup.md)。

## 審査基準への対応

アイデア、実装、RevenueCat、技術・プロダクト判断の4基準を、
[調査と編集判断](nextgen-judging-2026.md)にまとめた。
動画の冒頭に「生徒が教える」独自性を置き、実演と設計理由をつなげている。
勝敗や学習効果は保証しない。
