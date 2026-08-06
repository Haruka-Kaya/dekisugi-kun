# iOS / iPadOS でビルドする

学校が配っているのが iPad なので、**iPadOS が本命**。
コードは Flutter で共通なので、Windows 側でできる下ごしらえは済ませてある。
ここから先は **Mac が要る**。

---

## Windows 側で済ませたこと

| | 内容 |
|---|---|
| マイクの権限 | `NSMicrophoneUsageDescription` を `Info.plist` に追加。**これが無いと起動直後に落ちる** |
| 対応端末 | `TARGETED_DEVICE_FAMILY = "1,2"`（iPhone と iPad）。既定のままで正しい |
| 画面の向き | iPad は4方向すべて許可されている。既定のまま |
| 最低 iOS | 13.0。学校の iPad が古くても届く |
| 広い画面 | 読み物の幅を 640 で止めた（`ReadableWidth`）。テストで固定済み |

---

## Mac でやること

```bash
cd app
flutter pub get
cd ios && pod install && cd ..

# 実機（iPad）に挿して
flutter devices
flutter run --release -d <iPad の id> \
  --dart-define=SERVER_URL=https://rika-chousa.vercel.app
```

初回は Xcode で署名の設定が要る。

```
Runner > Signing & Capabilities
  Team: （Apple Developer Program のチーム）
  Bundle Identifier: jp.dekisugi.dekisugi
```

---

## 実機で最初に確かめること

**Android で動いたから iOS でも動く、とは限らないところ**を並べる。
上から順に、壊れていたら会話が成立しない。

### 1. マイクの許可が出るか

`NSMicrophoneUsageDescription` を入れたので出るはず。
出ないまま録音を始めると **その場で落ちる**（Android のように例外で済まない）。

### 2. 録音と再生が同時に動くか

iOS は**オーディオセッションのカテゴリ**で挙動が変わる。

- 再生側は `IosAudioCategory.playAndRecord` を指定済み（`pcm_player.dart`）
- 録音側は `IosRecordConfig()` の既定（defaultToSpeaker + Bluetooth 許可）

**片方が後からカテゴリを奪うと、もう片方が黙る。**
「AI の声は出るがマイクが拾わない」「マイクは拾うが声が出ない」なら、ここを疑う。

### 3. エコーキャンセルが効くか

Android（Xiaomi）では**効かなかった**ので、半二重にしてある。

iOS は `AVAudioSession` の `voiceChat` モードで AEC が効くことが多い。
**効くなら半二重をやめられる**が、まず現状のまま動かして確かめること。

確かめ方: AI が喋っている間、`[live] 自己割り込みの疑い` がログに出るか。

### 4. サンプリングレート

- 入力 16kHz / 出力 24kHz
- iOS のハードウェアは 48kHz が既定。**プラグインが変換しているはず**だが、
  声が高い・低い・早い・遅いなら、ここがずれている

### 5. 画面を消したときに切れないか

iOS は背面に回ったアプリの音声を止める。
会話中に画面が消えると切れるはずなので、**そのときの見え方**を確認する
（`stop()` が呼ばれて「続きから」が出るのが正しい挙動）。

### 6. iPad の広い画面

- 教材が読める幅で止まっているか
- 横向きにしたときに崩れないか
- **Split View（画面半分）で使われる**ことがある。狭くなっても壊れないか

---

## 審査で聞かれそうなこと

App Store に出す場合。**学校配布だけなら審査は要らない**
（Apple Business Manager / Apple School Manager 経由の配布、または TestFlight）。

| 論点 | 用意しておくもの |
|---|---|
| マイクを何に使うか | `Info.plist` の文言。具体的に書いてある |
| 未成年向けか | **年齢設定を正しく申告する。** `docs/age-restriction.md` の整理が根拠になる |
| 生成AIを使っているか | 「ユーザー生成コンテンツ」ではないが、**AI の出力が出る**ことは申告する |
| データ収集 | 音声とテキストを第三者（Google）へ送ることを Privacy Nutrition Label に書く |
| 個人情報 | 氏名・メール・生年月日は集めていない |

> [!warning] 年齢の申告
> App Store の年齢制限を「4+」にすると、Kids Category の制約に触れる可能性がある。
> **Kids Category には入れない。** 入れると第三者へのデータ送信が原則禁止になる。

---

## 学校の iPad へどう配るか

3通りある。学校の管理形態で決まるので、**情報担当に聞くのが早い**。

| 方法 | 向いている場合 |
|---|---|
| **Apple School Manager + MDM** | 学校が iPad を管理配布している。いちばん自然 |
| TestFlight | 試験導入。90日で切れる。人数上限あり |
| App Store 公開 | 誰でも入れられる。審査が要る |

学校が MDM で管理しているなら、**カスタム App（非公開配布）**が使える。
審査はあるが公開されない。

---

## まだやっていないこと

- **Mac での実ビルドを一度もしていない。** ここに書いたことは机上
- `pod install` が通るかは未確認（`flutter_pcm_sound` / `record` の iOS 側）
- iPad 実機での動作確認
- Privacy Nutrition Label の記入
