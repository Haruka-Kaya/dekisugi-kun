# 結果 — Gemini Live の Dart 実装は成立する

- 実行日: 2026-07-31
- Flutter 3.41.9 / `gemini_live` 2026.7.24（BSD 3-Clause）/ `gemini-3.1-flash-live-preview`
- 実行: `flutter test test/director_spike_test.dart`（**端末不要**、約1秒）

## 何を検証したか

デキすぎ君の心臓部は**二重ループ**で、サーバ側のディレクターが
`[DIRECTOR]` 付きの指示を Live セッションへ注入し、モデルがそれを
**読み上げずに**自分の言葉の発言へ変換する、という機構に依存している。

`jiyu-kenkyu-ai` は同じ機構を **TypeScript で**実子まで含めて検証済みだったが、
**Dart からできるかは前例がなく**、`flutter-app-ui-2026.md` 第2部で
「唯一の新規開発・最大の技術リスク」と評価していた。

## 結果: 通った

```
── ① 口火（ディレクターが会話を始めさせる）
   指示 : 会話を始めて。先輩に「落下」について教えてほしいと短く頼んで。
   発話 : 先輩、理科の「落下」のところ、全然わかんなくて…。教えてもらえますか？
   判定 : ✓ 読み上げなし

── ② 誤概念の誘発（デキすぎ君の核心）
   指示 : 誤概念「重い物体ほど速く落ちる」を、信じているかのように確認する形で口にして
   発話 : やっぱり、重いものの方が速く落ちるんですよね…？鉄の球と羽だったら、絶対鉄だし。
   判定 : ✓ 読み上げなし / ✓ 誤概念を口にした
```

**指示文はどちらも漏れていない。** しかも②では「鉄の球と羽だったら」という
中学生らしい根拠をモデルが自分で足している。台本を書かなくても誘発が成立する。

## 確認できた設定

`jiyu-kenkyu-ai` の TypeScript 設定と**1対1で対応する**ことを確認した。

| 設定 | 用途 | |
|---|---|---|
| `sessionResumption` | 接続10分寿命の対策 | ✓ |
| `contextWindowCompression` | コンテキスト上限の対策 | ✓ |
| `inputAudioTranscription` / `outputAudioTranscription` | 逐語の取得 | ✓ |
| `languageHints: ['ja-JP']` | 言語自動判定を切る（韓国語化事故の対策） | ✓ |
| `customVocabulary` | 同音異義語対策（行列→強烈） | ✓（未使用だが存在） |
| `realtimeInputConfig` / `automaticActivityDetection` | VAD調整 | ✓（未使用だが存在） |
| `sendActivityStart()` / `sendActivityEnd()` | push-to-talk の正規経路 | ✓（未使用だが存在） |
| `sendRealtimeText()` | **ディレクター注入の経路** | ✓ **検証済み** |

パッケージは ephemeral token も正しく扱う（`auth_tokens/` 接頭辞で
`BidiGenerateContentConstrained` に切り替え、`v1alpha` でないと警告）。
`jiyu-kenkyu-ai` が苦労して突き止めた仕様と一致している。

## 踏んだ罠

> [!warning] `gemini-3.1-flash-live-preview` は TEXT モダリティを一切サポートしない
> ```
> 1007: The requested combination of response modalities (TEXT) is not supported by the model
> ```
> 出力は **AUDIO のみ**。モデルが何と言ったかは `outputAudioTranscription` で読む。
> 「音声プラミングを省いてテキストで検証する」ができないので、最初から本番と同じ経路で組む。

> [!warning] `gemini_live` はセットアップ失敗を握りつぶす
> 上記のモダリティエラーのとき、パッケージは close code / reason を surface せず
> **10秒の `TimeoutException` になる**だけだった（`WebSocket setup timed out`）。
> 同じ設定を Python SDK に投げたら 1 秒で `1007 ... TEXT is not supported` と返ってきた。
>
> **セットアップで詰まったら、まず Python SDK（`google-genai`）に同じ設定を投げて切り分ける。**
> Dart 側のログだけ見ていると原因に到達できない。

## まだ検証していない

このスパイクが通したのは**プロトコルと注入の意味論**まで。**音声の入出力は未検証**。

1. **マイク入力**（16kHz モノラル PCM16 → `sendAudio`）
   — Google 公式 Flutter デモは `record` パッケージで `echoCancel: true` / `noiseSuppress: true` /
   Android は `voiceCommunication` ソース。同じ構成で組む
2. **音声再生**（24kHz PCM16 のストリーム再生）— Flutter でいちばん面倒な部分
3. **実機での動作** — このテストは PC 上の Dart VM で走っている
4. **割り込み（barge-in）** — `interrupted` フラグを受けて再生キューを捨てる処理
5. **接続の張り直し** — `sessionResumption` のハンドルを保存して使う経路

> [!note] 音声を足すと [!warning] がもう一つ待っている
> `rive_power_probe` の実測で、**連続アニメーションは1コアの70〜90%を食う**ことが分かっている。
> 音声処理と同時に動かすなら、キャラのアニメーションは発話中だけに絞る必要がある。

## 再現方法

```bash
cd tools/live_spike
flutter test test/director_spike_test.dart
```

`GEMINI_API_KEY` は環境変数、`.env.local`、または `jiyu-kenkyu-ai/.env.local` から読む。

## パッケージ選定の記録

| | `gemini_live` | `firebase_ai` |
|---|---|---|
| 公式 | ✗ コミュニティ（Dreamwalker） | ✓ Google |
| DL/30日 | 866 | 75,212 |
| likes | 8 | 117 |
| 依存 | websocket + http のみ | firebase_core / auth / app_check |
| Firebase 必須 | **不要** | **必要** |
| ライセンス | BSD 3-Clause | Apache 2.0 |

**スパイクでは `gemini_live` を採った。** Firebase を立てずに検証できるため。
必要な設定項目を全て持っていることも確認済み。

ただし **8 likes / 866DL の個人パッケージ**である点は本番採用のリスク。
中身は WebSocket の薄いラッパなので、放棄されてもフォークできる規模ではある。
本番の判断は、音声入出力まで通してから改めて行う。
