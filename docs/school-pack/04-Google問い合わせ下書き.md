# Google への問い合わせ（下書き）

<!--
  Vertex AI を18歳未満向けサービスに使ってよいか、を確認するための文面。

  書き方の方針:
  - **すでに読んだものを挙げる。** 「規約を読まずに聞いている」と思われると
    定型文で返される
  - 聞きたいことを1つに絞る。複数聞くと片方しか答えが返らない
  - 用途を具体的に書く。抽象的だと「ケースによります」で終わる
  - 回答が公式見解でないことは織り込む。**記録を残すこと自体に意味がある**

  送り先の候補:
  - Google Cloud のサポート（有償プランが要る場合あり）
  - 営業への問い合わせフォーム
  - Google Cloud Community / Issue Tracker（公開なので、学校の話は書かない）

  **公開の場に投げる場合、学校の件は一切書かないこと。**
-->

## 送り先: Cloud サポート（決定）

> [!warning] 無料の Basic プランではケースを開けない
> Google Cloud の Basic サポート（全アカウントに付く無料のもの）は
> ドキュメント・コミュニティ・**請求まわり**のみ。
> ケースの作成は **Enhanced 以上の有償プラン**が要る。
> 規約の解釈は請求サポートの対象外なので、Basic のままでは出せない。

### 契約の手順（**課金なので賀屋さんの操作**）

1. [Google Cloud Console](https://console.cloud.google.com/) にログイン
2. 左メニュー **Support** → **Overview**
3. **Manage support plans**（または Support Hub）
4. **Enhanced Support** を選ぶ
5. 料金を確認する — **月額の固定費に加えて利用額に連動する部分がある。**
   契約前に必ず表示された金額を読むこと
6. 契約すると **Support > Cases > Create case** が開く

### ケースの区分

- Category: **Billing / Account** ではなく **Technical / Other**
- Component: Vertex AI
- Priority: P4（質問）

### 1か月で解約する場合

- **回答を受け取ってから解約する。** 解約するとケースが閉じる可能性がある
- 回答は必ず**そのまま保存**する（スクリーンショットとテキストの両方）
- 解約は同じ Support Hub から

### うまくいかない場合の代替

| 送り先 | 長所 | 短所 |
|---|---|---|
| 営業への問い合わせ | 無償。人が読む | 回答に時間がかかる。契約上の効力は弱い |
| Cloud Community | 無償・早い | **公開の場。学校の件は書けない**。公式見解ではない |

---

## 件名

```
Vertex AI generative AI services: age eligibility for an application used by users under 18
```

## 本文（英語）

```
Hello,

I am developing an educational application that uses Vertex AI's generative AI
services (Gemini Live API via the Vertex AI endpoint). The application is
intended for junior high and high school students in Japan, which means a
substantial share of its users are under 18 years of age.

Before releasing it, I want to confirm that this use is permitted.

What I have already reviewed:

1. The Gemini API Additional Terms of Service state:
   "You must be 18 years of age or older to use the APIs. You also will not use
   the Services as part of a website, application, or other service that is
   directed towards or is likely to be accessed by individuals under the age of 18."

   The same document also states:
   "For clarity, these Terms do not govern your direct use of any Google Cloud
   Platform service (including those listed on the Google Cloud Services Summary)."

   I read this as meaning the 18+ requirement does not apply to Vertex AI.

2. I reviewed the Google Cloud Platform Terms of Service and the Service Specific
   Terms, and did not find any clause restricting use by, or applications directed
   toward, individuals under 18.

3. I reviewed the Generative AI Prohibited Use Policy and found no clause on this
   point either.

My question:

  Is my reading correct that Vertex AI's generative AI services may be used in an
  application that is directed toward, and accessed by, individuals under 18 —
  provided that all other terms and applicable law are complied with?

If there are additional requirements or restrictions that apply in this case
(for example, in the Cloud Data Processing Addendum, or product-specific
documentation I may have missed), I would be grateful if you could point me to them.

For context on the application:
- Users read short study material, then explain it aloud or in text to an AI character
- The AI does not provide answers; it is designed to be taught by the student
- No names, email addresses, dates of birth, or contact details are collected
- Parental consent is obtained where required under Japanese law

Thank you for your help.

[名前]
[連絡先]
```

## 本文（日本語窓口の場合）

```
お世話になっております。

Vertex AI の生成AIサービス（Vertex AI エンドポイント経由の Gemini Live API）を
利用した学習アプリケーションを開発しております。日本の中高生を対象としており、
利用者の相当数が18歳未満となります。

公開前に、この利用が許容されるかを確認させてください。

すでに確認した内容:

1. Gemini API Additional Terms of Service には
   「18歳以上である必要があり、18歳未満に向けた、または18歳未満がアクセスする
   可能性の高いサービスの一部として利用してはならない」旨の記載があります。

   同時に、同規約には
   「これらの規約は Google Cloud Platform サービスの直接利用を規律しない」
   との明示があります。

   このことから、当該18歳以上の要件は Vertex AI には適用されないと理解しています。

2. Google Cloud Platform Terms of Service および Service Specific Terms を確認
   しましたが、18歳未満の利用または18歳未満向けサービスを制限する条項は
   見当たりませんでした。

3. Generative AI Prohibited Use Policy にも該当する条項は見当たりませんでした。

お伺いしたいこと:

  他の規約および適用法令を遵守することを前提として、Vertex AI の生成AIサービスを
  18歳未満に向けた／18歳未満が利用するアプリケーションで使用してよい、という
  理解で正しいでしょうか。

本件に追加の要件や制限がある場合（Cloud Data Processing Addendum や、
私が見落としている製品固有のドキュメントなど）、お示しいただけますと幸いです。

アプリケーションの概要:
- 生徒が短い教材を読み、その内容を音声または文字で AI に説明します
- AI は答えを教えません。生徒に教わる側として設計しています
- 氏名・メールアドレス・生年月日・連絡先は一切収集しません
- 日本法上必要な場合、保護者の同意を取得します

よろしくお願いいたします。

［名前］
［連絡先］
```

---

## 回答が来たら

- **回答をそのまま `docs/age-restriction.md` に貼る**（要約しない。要約すると条件が落ちる）
- 「ケースによります」で終わった場合は、**何が決め手になるのかを聞き返す**
- 公式見解でないと断られた場合でも、**やり取りの記録は残す**。
  「確認を試みた」という事実は、学校に対して説明できる材料になる

## 送る前に

- 学校名・担当者名を**書かない**（公開の場に転載される可能性がある）
- 連絡先は個人のもの。**管理者アカウント（kayaharuka@hotmail.com）を晒したくないなら別途用意する**
