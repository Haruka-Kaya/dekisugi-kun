# Store screenshots 2026

## Current Next Gen image — 2026-10-02

Only `devpost/shot-1179x2556.png` is the refreshed v12 submission image.
It is a direct Android screenshot of source `c9887bd`, English Field Notebook,
1179×2556, RGB, without resizing, device frames or seeded progress.
SHA-256: `9261c24bf46e75f227d91040ace3395b90263b2007750b33fb5519c68a4e195a`.
The old store pipeline and other images below remain historical candidates;
the manually seeded old karte images are not submission evidence.

> [!danger] 旧提出候補を配布・提出に使わない
> このディレクトリの画像・SHA・撮影手順は**現行productionの正本ではない旧候補**です。
> 現行buildから再撮影・再検証するまで、Store、Shipaton、学校向け資料へ提出してはいけません。
> `tools/capture-store-shots.sh` と `tools/verify-store-shots.sh` も、旧「30秒ミッション」を
> 現行画面として誤認証しないようfail-closedで停止しています。Field Notebookの撮影状態と
> OCR契約を作り直すまで、過去のPASSや下記SHAを現行証拠に数えません。

2026-08-10 時点の旧候補UIを、App Store Connect / Google Play の受理条件に合わせて
再撮影するための出力先です。旧 `docs/shots/` は履歴として残し、ここからは提出しません。

## 公式仕様

一次情報は次の公式ページだけを基準にしています。

- Shipaton: [Official Rules, Submission Requirements](https://revenuecat-shipaton-2026.devpost.com/rules)
- Apple: [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- Apple: [Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/)
- Google: [Add preview assets to showcase your app](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en)

### App Store Connect

- `.jpeg` / `.jpg` / `.png`、alpha channel・透明部分は禁止。
- 1〜10枚。
- Apple は自由な縦横比ではなく、端末区分ごとの**完全一致ピクセル**で受理する。
- iPhone 6.9-inch portrait は `1260x2736`、`1290x2796`、`1320x2868` のいずれか。
- 13-inch iPad portrait は `2064x2752` または `2048x2732`。
- 現在のバイナリは iPhone / iPad の両方で動くため、iPhoneだけでなく13-inch iPad素材も必要。
- 同じUIなら最高解像度を用意すると、Appleが小さい端末向けに縮小する。

このディレクトリでは、端末の生の比率を変形・切り抜きせず、次を使います。

| 提出先 | Simulator | 寸法 | 比率の扱い |
|---|---|---:|---|
| iPhone 6.9-inch | iPhone 17 Pro Max | 1320x2868 | Apple指定の完全一致寸法 |
| iPad 13-inch | iPad Pro 13-inch (M5) | 2064x2752 | 3:4、Apple指定の完全一致寸法 |

### Shipaton提出フォーム（Storeとは別）

Shipaton公式ルール §4 Submission Requirements は、端末枠なしの`1179x2556`を最低1枚、
**幅・高さまで固定**して要求しています。これはApp Storeの最高解像度枠やGoogle Playの
9:16推奨とは別契約です。iPhone 15 Pro Simulatorの生framebufferがこの寸法なので、
`shipaton/iphone-1179x2556/`はリサイズ・切り抜き・端末枠合成をせずに直接撮影します。

Devpost提出用の実際のスクリーンショットは `devpost/` に置き、上記のストア用
パイプラインとは別に管理します。現物はAndroidエミュレータで `wm size 1179x2556`
に設定した実画面の `adb screencap`（リサイズ・端末枠なし、必須提出画像はRGB化済み）です。

| ファイル | 内容 |
|---|---|
| `devpost/shot-1179x2556.png` | 学習パス進行中（必須提出・1179x2556・RGB） |
| `devpost/shot-1179x2556-teachback.png` | TEACH BACK導入画面（教材非表示・声/文字選択） |
| `devpost/shot-1179x2556-teachback-input.png` | 教材を隠した説明入力画面 |
| `devpost/shot-1179x2556-aurora.png` | オーロラマント装備中（Plus特典の可視状態）。RevenueCat Test Store で**実際に購入**した直後の実機キャプチャ（商品→チェックアウト→`plus` entitlement→装備までの実経路。`docs/shipaton-demo-2026/shipaton-demo-v7.mp4` に同じ経路を収録） |
| `devpost/karte-1179x2556.png` | デキすぎ君のカルテ（誤概念マップ）上部: サマリ「訂正できた2・迷い中4」+ 概念カード。撮影注記: `learning_need_state` に観測・解消行を手動挿入した実画面（表示コードは実経路と同一） |
| `devpost/karte-units-1179x2556.png` | カルテの単元別並び: 「これから」「訂正できた」chip付き概念カード |

### Google Play

- 受理条件はJPEGまたは24-bit PNG（alphaなし）。
- 公開に必要なのは、端末種別をまたいで最低2枚。
- 各辺は320〜3840px、長辺は短辺の2倍以下。受理条件上の比率範囲は1:2〜2:1。
- アプリが推薦面へ出る条件として、縦は9:16・最低1080x1920、横は16:9・最低1920x1080を4枚以上用意することが強く推奨されている。

このディレクトリではPixel 7 AVDを一時的に`1080x1920`へ設定し、変形や後付けの端末枠なしで
現在UIをそのまま撮影します。撮影中だけ未接続Wi-Fiを無効化し、batteryを100%に固定して、
navigationをimmersive設定にします。終了時にWi-Fi・battery・navigation policy・解像度を元へ戻します。

## 再生成

MacにXcode、Flutter、Android SDK、`Pixel_API36` AVDがある状態で、リポジトリ直下から実行します。

```zsh
tools/capture-store-shots.sh
```

既存のビルド成果物を使う場合:

```zsh
tools/capture-store-shots.sh --skip-build
```

片方だけを再撮影する場合は`--ios-only`または`--android-only`を併用できます。

画像だけを再検証する場合:

```zsh
tools/verify-store-shots.sh
```

以下は旧候補を作った当時の手順で、現在は実行時に停止します。旧検証は寸法・RGB
8-bit x 3 channel・alphaなし・形式・Googleの辺比に加え、Vision OCRで旧候補UIの
`30秒おためしミッション` / challenge / `TUTORIAL CLEAR` / `答えを送らず`を確認していました。
これらの文言はField Notebookの現行productionを証明しません。現行で保存するのは
教材ID・概念ID・進行・canonical need・heart・完了時刻・冪等報酬台帳だけで、
音声・自由文・選択肢IDは保存しません。
`Ready for Apple Intelligence`などSimulatorの通知が写った候補は出力ファイルへ昇格しません。
iOSは`--mask=ignored`の生framebufferを、アプリのlight背景色`#F6F2E9`へlossless合成して
RGB PNG化します。四隅も同色か機械検査するため、黒い端末マスクや透明角は残りません。
Androidも`adb screencap`の画面領域だけを使い、端末モックや外周キャンバスを合成しません。

13-inch iPad画像の右下端にある灰色の弧は、iPadOS 26がmultitasking対応アプリへ表示する
system window resize handleです。Appleも[WWDC25のiPad design session](https://developer.apple.com/videos/play/wwdc2025/208/?time=298)と
[iPadOS 26の操作ガイド](https://support.apple.com/en-us/125309)で同じ位置と役割を説明しています。
待機、Simulator mask変更、capture専用buildの`UIRequiresFullScreen=true`でも消えないことを確認済みで、
端末枠・scroll indicator・mask artifactではありません。実際のOS表示を画像編集で消さず、そのまま残します。

生成処理は専用Simulator上のアプリを一度アンインストールし、初回同意前の状態へ戻します。
Androidの解像度overrideは撮影後にresetします。実機や既存の`docs/shots/`は変更しません。

## 現在生成する画面

| ファイル | UI状態 |
|---|---|
| `app-store/iphone-6.9/01-first-mission-predict.png` | 30秒おためしミッション・予想 |
| `app-store/ipad-13/01-first-mission-predict.png` | 同上（iPadネイティブレイアウト） |
| `shipaton/iphone-1179x2556/01-first-mission-predict.png` | Shipaton固定寸法、端末枠なし |
| `google-play/phone/01-first-mission-predict.jpg` | 予想 |
| `google-play/phone/02-first-mission-challenge.jpg` | デキすぎ君の思い込みを訂正 |
| `google-play/phone/03-first-mission-clear.jpg` | 条件を使った訂正の完了 |
| `google-play/phone/04-device-only-studio.jpg` | 旧候補。現行productionでは教材ID・概念ID・進行・canonical need・heart・完了時刻・冪等報酬台帳を保存し、音声・自由文・選択肢IDは保存しない |

2026-08-10の検証済みSHA-256:

| ファイル | SHA-256 |
|---|---|
| `app-store/iphone-6.9/01-first-mission-predict.png` | `d532211c3ea828fbcfdd66a230cb94510b9d3aa73a3e5535fae5e74a3e0e4eb4` |
| `app-store/ipad-13/01-first-mission-predict.png` | `13b36235da2699d7522cb68582cf4c2229f9da9f857f104589316d6ccaad725f` |
| `shipaton/iphone-1179x2556/01-first-mission-predict.png` | `9b7e93f35def13e2fe81debfbfa677ed14a4508041a56900d7b76551fce01a01` |
| `google-play/phone/01-first-mission-predict.jpg` | `688add2ace0eb00318a5ecc622630e40e97d1e4ac69042d0c4d79ad6a59a1969` |
| `google-play/phone/02-first-mission-challenge.jpg` | `d1a10c965fe8c1d15c37c26a27a6cab0f8862e3593ccc6095541f180dab77c91` |
| `google-play/phone/03-first-mission-clear.jpg` | `e629aee3a68375e27e978693da47330fa896c90f3dbc124b06afb8678fd8498f` |
| `google-play/phone/04-device-only-studio.jpg` | `235b568d5008918820d205921a0ee63c86527a7a9ecf6c40dcbf1aba22a1983a` |

## 提出セットに残る画面

Google Playは、推薦面向けに強く推奨される4枚・9:16・1080px以上の画像数と寸法を満たします。
これは推薦掲載そのものを保証するものではありません。最終提出では現在ビルドから次も追加候補とし、
古い画面や実装されていない機能を見せません。

1. 教材を閉じ、自分の言葉で声または文字から教える本番ミッション
2. AIの誤解を条件・理由で訂正する本番会話
3. 接続できない時の「思い出す → 条件を足す → 具体場面で試す」端末内練習
4. 復習画面の概念別継続記録（点数・ランキングではないことが伝わる状態）
5. Plusは実Store価格と期間を取得できるsandbox設定後だけ撮影する

同じ順序でiPhone / iPad / Androidを撮影し、文字切れ、overflow、通知、個人情報、
古いブランド名がないことを目視確認してから提出します。
