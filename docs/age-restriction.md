# 未成年に使わせてよいか — 規約と法令の確認

初回調査: 2026-08-05（Developer API で詰まっていることが判明）
**再調査・確定: 2026-08-06**（Vertex への移行後、一次ソースで裏取り）

> [!warning] これは法務の判断ではない
> 一次ソースにあたって**書いてあること／書いていないこと**を整理したもの。
> 「禁止条項が見つからない」は「許されている」ではない。
> 学校など第三者を巻き込む前に、専門家の確認を通すこと。

---

## 結論（先に）

| 論点 | 状態 |
|---|---|
| Gemini Developer API の18歳未満禁止 | **Vertex AI には適用されない**（規約に明示の除外あり） |
| Google Cloud / Vertex AI の年齢条項 | **見当たらない**（無いことの証明ではない） |
| 越境移転の同意（個情法28条） | **必要。**同意画面で3点を表示済み |
| 16歳未満の法定代理人同意 | 改正法で明文化。遅くとも2028年7月施行。**現行でもQ&Aで運用**されている |
| 未成年の最善の利益への配慮 | 改正法58条の3。**設計に効く** |

---

## 1. Developer API の18歳未満禁止は、Vertex には及ばない

### 何が書いてあるか

[Gemini API Additional Terms of Service](https://ai.google.dev/gemini-api/terms) より:

> "You must be 18 years of age or older to use the APIs. You also will not use the Services
> as part of a website, application, or other service (collectively, "API Clients") that is
> **directed towards or is likely to be accessed by individuals under the age of 18**."

これが、Developer API を使っていたときに**製品が成立しない**と判断した根拠。
中高生向けなので「likely to be accessed by individuals under 18」に真正面から当たる。
この条項は有料/無料より前に置かれているので、課金しても外れない。

### 適用範囲に明示の除外がある

同じ規約に、こうある。

> "For clarity, these Terms **do not govern your direct use of any Google Cloud Platform
> service** (including those listed on the Google Cloud Services Summary)."

Vertex AI は Google Cloud Platform のサービスなので、**この18歳条項は Vertex には及ばない。**

移行の判断は正しかった、というのがここで裏づけられた。

> [!caution] 見落とした経緯
> 調査フェーズでロイヤリティ・著作権・保護者同意は掘ったが、
> **API 側の年齢条項を見ていなかった。**
> 段階5 で保護者同意まで実装したあとに出てくる話ではなかった。
> **外部サービスに乗るときは、対象年齢と利用規約を先に突き合わせる。**

### 移行が済んでいることの確認

- 端末に API キーが無い（リリース APK に `AIza` 文字列ゼロを確認済み）
- 会話は `*-aiplatform.googleapis.com` へ、サービスアカウントのアクセストークンで繋ぐ
- ディレクターも Vertex 経由

**Developer API の経路は残っていない。** 残っていると、この整理は無効になる。

---

## 2. Google Cloud 側に年齢条項は見当たらない

次の2つを読んで、年齢・未成年・18歳・児童に関する条項を探した。**見つからなかった。**

- [Google Cloud Platform Terms of Service](https://cloud.google.com/terms/)
- [Service Specific Terms](https://cloud.google.com/terms/service-terms)

[Generative AI Prohibited Use Policy](https://policies.google.com/terms/generative-ai/use-policy) にも、
未成年の利用そのものを禁じる条項は無い（児童性的虐待コンテンツの禁止はあるが別の話）。

### ただし、責任の所在がこちらに来る

Cloud の規約は**事業者向け**に書かれていて、こういう構造になっている。

- 契約する「Customer」は賀屋さん
- 生徒は「End User」
- Customer は **End User の利用についても責任を負う**（4.1）

Google が年齢で線を引いていないぶん、**適法性の判断はこちら側の責任**になる。
「規約に書いていないからよい」ではなく「こちらで判断しろ」と言われている状態。

### 未解決

- Google に**直接確認していない**。学校で使うなら、問い合わせて記録を残すのが望ましい
- 学校が Google Workspace for Education を使っている場合、**学校側の契約に別の制約**があるかもしれない。
  学校の情報担当に確認が要る

---

## 3. 越境移転（個人情報保護法28条）

生徒の声と発話内容が米国の Google のサーバーへ渡るので、外国にある第三者への提供にあたる。

本人（16歳未満なら法定代理人）に、**次の3点を伝えたうえで**同意を得る必要がある。

1. 移転先の**国の名前**
2. その国の**個人情報保護制度**
3. 移転先が講じている**保護措置**

「海外に送信されることがあります」だけでは足りない。

### 実装

`app/lib/services/consent.dart` の `kTransferDisclosure` に3点を持ち、
同意画面で**実際に表示している**。文面は `docs/school-pack/` の説明資料と揃えてある。

---

## 4. 16歳未満の法定代理人同意

### 改正法（2026年7月17日公布）

16歳未満の個人情報を扱う場合、利用目的の通知・第三者提供の同意などにおける「本人」を
**「本人の法定代理人」に読み替える**（改正法40条の2）。

施行は公布から2年以内の政令で定める日で、**遅くとも2028年7月**。

あわせて次も入った。

- 16歳未満の本人は、要件を満たさなくても利用停止・消去・第三者提供停止を請求できる（35条9項・10項）
- 事業者は**年齢および発達の程度に応じて、その最善の利益を優先して考慮する**（58条の3第1項）

### 現行法でも

Q&A の運用として、**一般に12〜15歳以下は法定代理人等の同意取得が求められる**とされている。
「施行前だから中学生に直接同意させてよい」とはならない。

### 実装

同意画面で年齢帯（15歳以下 / 16〜17歳 / 18歳以上）を選ばせ、
**15歳以下なら保護者の確認を必須**にしている。誕生日は集めない。

> [!note] 学校で使うなら形が変わる
> 生徒一人ひとりに保護者確認をさせるのは現実的でない。
> 学校が保護者から一括で同意を取る形になる。**誰が同意を取るのかを先に決める**こと。
> 資料は `docs/school-pack/` に用意した。

---

## 5. 「最善の利益を優先して考慮」は設計に効く

改正法58条の3は努力義務だが、この製品では実装に落ちている部分がある。

| 条文の趣旨 | この製品での形 |
|---|---|
| 年齢・発達に応じた配慮 | 断定しない（C9）。「弱点」と言わず「もう一度見るところ」 |
| 最善の利益 | 答えを教えない。説明させる。役を降ろす脱獄への守り |
| 収集を必要最小限に | 名前・メール・誕生日を集めない。端末IDのみ |

**主張の材料になるが、免罪符ではない。**

---

## 6. まだ確認していないこと

- **Google への直接確認**（Vertex を未成年向けサービスに使ってよいか）
- 学校が Google Workspace for Education を使っている場合の、学校側契約の制約
- 生徒の発話が Google 側でどれだけ保持されるか（Vertex の abuse monitoring の保持期間）
- 学校での実施が「研究」にあたる場合の倫理審査の要否

---

## 出典

- [Gemini API Additional Terms of Service](https://ai.google.dev/gemini-api/terms)
- [Google Cloud Platform Terms of Service](https://cloud.google.com/terms/)
- [Google Cloud Service Specific Terms](https://cloud.google.com/terms/service-terms)
- [Generative AI Prohibited Use Policy](https://policies.google.com/terms/generative-ai/use-policy)
- [2026年（令和8年）改正個人情報保護法の概要 — のぞみ総合法律事務所](https://www.nozomisogo.gr.jp/newsletter/13819)
