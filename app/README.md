# app — デキすぎ君 本体（Flutter）

段階0（土台）まで実装済み。会話機能は段階1から。

## 動かす

```powershell
flutter run                                       # 端末の明暗設定に従う（本番の挙動）
flutter run --dart-define=FORCE_BRIGHTNESS=dark   # ダーク固定
flutter analyze
flutter test
```

### UI を目で確認する（Windows 開発機）

この PC には Visual Studio の C++ ツールチェーンが無く `flutter build windows` が通らない。
実機が繋がっていないときは web ビルドで見る。**web は開発プレビュー専用**で配布対象ではない。

```powershell
flutter build web --release --dart-define=FORCE_BRIGHTNESS=light
cd build\web; python -m http.server 8123 --bind 127.0.0.1
# → http://127.0.0.1:8123/
```

## 段階0 で決めたこと

| 決定 | 理由 |
|---|---|
| `lib/ui/_material.dart` に import を集約 | Material は Flutter 3.44 でコアから凍結され `material_ui` へ移行中。置換をこの1ファイルに閉じる |
| 角丸は `AppRadius` に集約（base 12.0 の倍率導出） | attendance_app は 16/12/10/20 が各ファイルに散り、`DESIGN.md:421` が未完 TODO として記録している |
| `ThemeData(...)` を一発生成 | `copyWith` で継ぎ足すと M3 の既定が半分しか効かない（DESIGN.md §1.3） |
| `google_fonts` を**使わない**。可変フォントを同梱 | google_fonts は実行時にネットワークから取りに行く。初回起動がオフラインだと和文が出ず、端末ごとに描画も変わる |
| 本文 `height: 1.7` を明示 | M3 の既定 1.43 は Noto Sans JP の自然行高 1.448em より小さく、和文に行間を足していない |
| ウェイトは `fontVariations` で軸を明示 | 可変フォント1本なので pubspec の `weight:` が使えない。`fontWeight` だけでエンジンが wght 軸を動かすか合成太字にするかは環境依存 |
| `withClampedTextScaling(1.0, 1.6)` | 無制限だと 2.0倍でレイアウトが壊れ、固定すると弱視の利用者を締め出す |

### フォントの選定

| 候補 | サイズ | 判断 |
|---|---|---|
| **Noto Sans JP 可変 (wght 100-900)** | 9.15 MB | **採用。** 見出しに w700〜w900 が要る |
| BIZ UDPGothic Regular + Bold | 8.88 MB | 保留。教育向け UD フォントとして本文の可読性は有利だが、ウェイトが2つしかない |

長文の教材本文だけ BIZ UDPGothic に分けるのは段階3で再検討する。

## 4状態の名前

`ExplainStatus` は attendance_app の検証済みパレットを流用しつつ、**枠組みを変えている**。

| 状態 | 色の出自 | ラベル | アイコン |
|---|---|---|---|
| `gotIt` | present（緑） | 説明できた | `check_circle` |
| `shaky` | partial（橙） | あと少し | `contrast` |
| `weak` | absent（赤） | ここを復習 | `bookmark` |
| `untouched` | unanswered（灰） | まだ | `circle_outlined` |

`weak` に ✗ や ! を使わない。デキすぎ君では説明できないことが日常で、
それは失敗ではなく「次に見るところ」。この制約はテストで守っている。

## 検証の限界

`flutter test` は**全フォントを固定幅のダミーに潰す**。実在しない family を指定しても
w400 でも w900 でも同じ幅（実測 528.0px = 11文字 × 48px）が返る。
したがってテストで確かめられるのは「アセットが在るか」「スタイルに軸が刻まれているか」まで。
**グリフが本当に太っているかは実機で目視する**（段階3のチェック項目）。

コントラスト比はテストで実測している（`test/app_theme_test.dart`）。
コメントに「検証済み」と書くと色を変えたときに嘘になるので、基準そのものをテストにしてある。
入力欄の枠が実際に描画されることは web ビルドの画素サンプルで確認済み
（白 `#FFFFFF` と塗り `#F6F7F9` の間に `#8D8F93` が 1px）。

## 構成

```
lib/
  config/   app_theme.dart（色・文字・角丸の適用）, app_radius.dart
  screens/  画面。段階1で会話画面に置き換える
  ui/       _material.dart（import 集約点。ここ以外から material.dart を import しない）
  widgets/  StatusChip ほか
assets/fonts/  NotoSansJP-Variable.ttf（SIL OFL 1.1・OFL.txt 同梱）
```
