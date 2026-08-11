# iOS / iPadOS ビルド記録（現行productionと旧Live研究）

> [!danger] 旧研究資料を配布・提出に使わない
> この文書の旧 Vertex Live 手順・審査メモは**現行productionの正本ではない**。
> 旧候補を App Store、TestFlight、学校配布、審査資料へ転用してはならない。

## 現行productionの状態（2026-08-12）

- 現行の音声体験は、外部Live AIではなく端末内の固定問い返しを使う **local Teach-back**。
- Ruby 3.3.12 / Bundler 4.0.16 / lock済みCocoaPods依存で、iOS Simulator debug buildは成功済み。
  ただし実機署名archiveや配布可否の証拠にはならない。
- iPhone / iPad実機でのマイク録音・音声再生・割り込み・ライフサイクル復帰を含む
  **物理音声QAは未完了**。
- 現行経路は音声と自由文を保存・送信しない。旧Liveのデータ境界や審査記述を
  現行productionへ適用しない。

> [!danger] 現在の Vertex ビルドを中高生・学校向けに配布しない
> Google Cloud Service Specific Terms §20(d) により、学校管理端末、MDM、TestFlight、
> カスタム App のどの配布方法でも年齢制限は解消しない。以下は18歳以上の開発確認、または
> 利用可能な AI 基盤への移行後に限る。

将来の学校導入では iPad が想定されるため、**iPadOS を主要対象**としている。
コードは Flutter で共通なので、Windows 側でできる下ごしらえは済ませてある。
ここから先は **Mac が要る**。

---

## Windows 側で済ませたこと（Historical: 旧Live）

| | 内容 |
|---|---|
| マイクの権限 | `NSMicrophoneUsageDescription` を `Info.plist` に追加。**これが無いと起動直後に落ちる** |
| 対応端末 | `TARGETED_DEVICE_FAMILY = "1,2"`（iPhone と iPad）。既定のままで正しい |
| 画面の向き | iPad は4方向すべて許可されている。既定のまま |
| 最低 iOS | 13.0。学校の iPad が古くても届く |
| 広い画面 | 読み物の幅を 640 で止めた（`ReadableWidth`）。テストで固定済み |

---

## Mac でやること（Historical: 旧Live）

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

## 実機で最初に確かめること（Historical: 旧Live）

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

## 審査で聞かれそうなこと（Historical: 旧Live）

App Store に出す場合。なお、学校向けの非公開配布でも Google Cloud §20(d) の禁止は変わらない。
配布経路によっては App Store の一般公開審査とは異なる手続になる
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

## 学校の iPad へどう配るか（Historical: 旧Live）

3通りある。学校の管理形態で決まるので、**情報担当に聞くのが早い**。

| 方法 | 向いている場合 |
|---|---|
| **Apple School Manager + MDM** | 学校が iPad を管理配布している。いちばん自然 |
| TestFlight | 試験導入。90日で切れる。人数上限あり |
| App Store 公開 | 誰でも入れられる。審査が要る |

学校が MDM で管理しているなら、**カスタム App（非公開配布）**が使える。
審査はあるが公開されない。

---

## まだやっていないこと（Historical: 旧Live）

- **Mac での実ビルドを一度もしていない。** ここに書いたことは机上
- `pod install` が通るかは未確認（`flutter_pcm_sound` / `record` の iOS 側）
- iPad 実機での動作確認
- Privacy Nutrition Label の記入
