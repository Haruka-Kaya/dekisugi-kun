# app — デキすぎ君 本体（Flutter）

段階1（音声会話）まで実装済み。実機での通し確認は未了。

## 動かす

```powershell
pwsh ..\tools\run-dev.ps1                 # APIキーを .env.local から渡して起動
pwsh ..\tools\run-dev.ps1 -Brightness dark
pwsh ..\tools\test-live.ps1               # Gemini Live との通信テスト（実機不要）
flutter analyze
flutter test
```

**APIキーをソースに書かないこと。** `--dart-define` で渡す。
`--dart-define` の値は APK に平文で残るので、**配布ビルドでは使えない**
（段階5 でサーバ発行の ephemeral token に差し替える）。

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

## 段階1 — Gemini Live で分かったこと

**どちらも「ビルドも接続も通るのに音だけ出ない」壊れ方をする。** 実測で見つけた。

| 罠 | 症状 | 対処 |
|---|---|---|
| `sendRealtimeText`（`realtimeInput.text`）で送る | 文字起こしは返るが**音声が1バイトも返らない** | `sendClientContent` で送る。同条件で 371KB 返った |
| `gemini-3.1-flash-live-preview` | `usageMetadata` に responseTokenCount が出ない（0トークン）。実測 0/10 | `gemini-2.5-flash-native-audio-preview-09-2025` に変更。同設定で 3/3 |

スパイク（`tools/live_spike`）は**文字起こししか見ていなかった**ので、
どちらも見逃していた。そのまま実機に持っていけば声の出ないアプリになっていた。

→ `test/live_config_network_test.dart` が**音声のバイト数**を assert する。
モデルや設定を触ったら必ずこれを通してから実機へ。

### 音声出力の作り

`flutter_pcm_sound` には**キューを空にする API が無い**（`setup` で作り直すか
`release` で壊すかの2択）。届いた音を全部 `feed()` すると、生徒が割り込んでも
AI の声が鳴り続ける。

そこで**再生待ちを Dart 側に持ち、native には 50ms ずつしか渡さない**
（`setFeedThreshold` + feed コールバックの pull 方式）。
割り込み時の鳴り残りは 100ms 以内で、その上限はテストで縛ってある。

公式 example はターン全体をバッファして WAV 化してから鳴らすので、
生成が終わるまで無音になる。会話には使えない。

### ノイズ抑制

`echoCancel` は品質ではなく**成立条件**。切ると AI の声を自分のマイクが拾って
自己割り込みする。Android は `audioManagerMode: modeInCommunication` も要る
（`flutter_pcm_sound` の出力が `USAGE_MEDIA` 固定なので、これが無いと AEC が
出力側を参照できない端末がある）。

`noiseSuppress` は**プラットフォーム標準のまま有効**にしてある。
`asr-noise-2026.md` が否定しているのは**自前で足す抑制段**で、
同文書 §10 の実装判断は「標準の抑制は維持する」。

## 段階3 — キャラクターと演出

### 4状態の描き分け（参考実装が存在しない領域）

Google 公式の Flutter デモも、音声画面は接続中スピナーと静止ロゴを切り替えるだけで
「聞いている／考えている／話している」の描き分けは**実装していない**。ここは自分で決めた。

| 状態 | 形で伝えるもの | 動きの量 |
|---|---|---|
| 待機 | 無印 | **完全静止** |
| 聞いている | 左右に開いた弧（耳） | まばたきだけ（**稼働率 3.75%**） |
| 考えている | 頭の左上に点3つが順に立つ | 連続。ただし短い（実測 約1.3秒） |
| 話している | 頭の右に3本のバー | 声の大きさで駆動。**声が無くても最低限の高さで描く** |

**どの状態も、形に加えて必ず文字を出す**（SC 1.4.1）。
Reduce Motion で動きが止まっても、形と文字だけで4状態が区別できる。

`test/goldens/character_{light,dark}.png` に4状態を並べて焼いてある。
`flutter test test/character_golden_test.dart --update-goldens` で更新。
`flutter test` は全フォントをダミーにするが、**キャラに文字は無いので図形はそのまま確認できる**。

### 口を持たせない

Gemini Live は**音素タイミングを返さない**ので、口の形は原理的に作れない。
適当に開閉させると音と合っていないことが必ずばれる。**最初から持たせない。**
声で動かすのは体の幅と高さだけで、これは包絡なので音素の精度を主張しない。

### 待機中に動かさない

実測で、毎フレーム描き続けると1コアの 71〜91% を食う。Rive の有無に関わらずで、
主犯はパイプラインを毎フレーム回すこと自体。fps を落としても効かない
（Rive は約61%がフレーム非依存）。**効くのは止めることだけ。**

`TickerMode` で待機中・Reduce Motion 時はサブツリーごと止める（実測 91.4% → 0.8%）。
**この制約はテストで縛ってある** — 状態ごとにティッカーが止まっているかを assert する。

### Reduce Motion は口が2つある

- `MediaQuery.disableAnimationsOf` は **Android 専用**
- iOS の「視差効果を減らす」は `AccessibilityFeatures.reduceMotion` にしか出ない（MediaQuery に来ない）

`ReduceMotionScope` が両方を購読して1つにまとめる。片方しか見ないと半分の利用者に効かない。

### 触覚だけに頼らない

`HapticFeedback.successNotification()` は **Android API 30 未満で完全に無音**。
中高生の端末は古い可能性が高い。達成の合図は
**色 + 枠 + アイコン + 文字**が本体で、触覚（`mediumImpact`）は添えるだけ。

## 段階4 — 復習と中断再開

### OS に殺される前提で書く

**「アプリを離れる」ではなく「OS に殺される」前提**で設計してある。
Android は裏に回ったアプリを予告なく落とすので、`dispose` もライフサイクルの
コールバックも呼ばれる保証がない。

→ 終了時にまとめて書かず、**1ターンごとに丸ごと上書きする**。
差分更新にすると、途中で落ちたときに壊れた状態が残る。

Live の接続自体は復元できない（落ちた時点で切れている）。
復元するのは**逐語と理解カルテ**で、ディレクターがそれを読んで続きから指示を出す。
**サーバが状態を持たない設計だから、これで足りる。**

発話IDは連番で、再開時は `_seq = transcript.length` から続ける。
**使い回すとディレクターの根拠が別の発言を指す。**

### 復習の間隔

出典は Cepeda 2006「最適な復習間隔は**保持したい期間に応じて伸びる**」。
中高生には定期考査という明確な保持期限があるので、そこから逆算できる。

> [!warning] 比率は未検証
> 「保持期間に応じて伸びる」は確認済みだが、**何%が最適かはこのプロジェクトで検証していない**。
> いまの 15% は仮の値。テストで縛っているのは**単調性**（考査が遠いほど間隔が伸びる）と
> **考査までに1回は回ってくる**ことだけ。

考査日が未設定なら 1 → 3 → 7 → 14 → 30 日の階段を使う。

### 「弱点」と言わない

復習に出すのは2種類で、**どちらも「できていない」とは呼ばない**（C9）:

| 理由 | 文言 |
|---|---|
| 誤概念を訂正できなかった | もう一度たしかめたいところ |
| 説明が薄いまま | あと少しで説明しきれるところ |

`unclear`（判定がつかなかった）は**含めない**。
判断がついていないものを「できていない」側に置くと、触れてもいないことを突きつけることになる。
責める語（「弱点」「間違」「できていない」）が文言に入らないことはテストで縛ってある。

### 記録の置き場

sqflite は Android / iOS / macOS のみ。**web と Windows では動かない**ので、
開発プレビューが落ちないよう `MemorySessionStore` に落ちる（記録は残らない）。

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
  config/   app_theme.dart / app_radius.dart / live_config.dart（Live の設定と理由）/ env.dart
  screens/  talk_screen.dart（段階1の会話画面。演出は段階3）
  services/ live_session.dart（会話ぜんぶ）
            mic_stream.dart（16kHz PCM16 + 音量 + 録音異常）
            pcm_player.dart（24kHz ストリーム再生 + 割り込み）
            speech_gate.dart（端末側の発話終了検知）
            director_queue.dart（指示を静かなときだけ流す）
  ui/       _material.dart（import 集約点。ここ以外から material.dart を import しない）
  widgets/  StatusChip ほか
assets/fonts/  NotoSansJP-Variable.ttf（SIL OFL 1.1・OFL.txt 同梱）
```

`flutter test` は**ネットワークを使う**（`live_config_network_test.dart`）。
APIキーが見つからない環境では skip する。

`flutter create` を再実行すると `test/widget_test.dart` がテンプレのまま復活して
`flutter analyze` が落ちる。復活したら消すこと。
