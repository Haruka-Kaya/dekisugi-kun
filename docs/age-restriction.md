# 未成年に使わせてよいか — 外部 AI 規約の確認

初回調査: 2026-08-05
最終確認: **2026-08-10**

> [!warning] これは法務意見ではない
> 2026年8月10日時点の各社公式規約・公式資料を整理したもの。
> 契約主体の個別注文書や改定通知が異なる場合は、その書面を優先して確認する。

## 結論

| 論点 | 結論 |
|---|---|
| Google Cloud / Vertex AI | **中高生向けの本アプリでは No-Go** |
| Vertex AI API / Vertex AI Live API の適用範囲 | Google Cloud Services Summary が生成AIサービスとして明示 |
| 年齢ゲート・学校承認・保護者同意 | **§20(d) の禁止を解除しない** |
| Google Workspace for Education の例外 | Workspace 固有。Vertex AI API には適用されない |
| 現在必要な対応 | 未成年・学校向け提供を止め、別基盤へ移行するか個別契約を締結する |

本製品は「中高生向け」と明示している。18歳以上だけを通す年齢ゲートを設けても、
サービス自体が18歳未満向け、または18歳未満がアクセスする可能性が高いという性質は変わらない。
したがって、現在の Vertex ベースの AI 会話機能を公開・実証・授業・家庭学習へ提供してはならない。

## 1. Google Cloud §20(d) の禁止

[Google Cloud Service Specific Terms](https://cloud.google.com/terms/service-terms) の
生成AIサービス条項 §20(d) は、Customer と End User に対し、18歳未満向け、または
18歳未満がアクセスする可能性が高いウェブサイト、アプリその他のオンラインサービスの一部として
生成AIサービスを使うことを禁止している。

同 §20(f) は、§20(d) 違反の疑いに基づき、Google が生成AIサービスを直ちに停止または終了できるとする。
同意取得の有無、無料・有料、学校管理下かどうかによる公開例外は、この条項には記載されていない。

### Vertex と Live に確実に適用される根拠

[Google Cloud Platform Services Summary](https://cloud.google.com/terms/services) の
「Generative AI Services」は、次を明示的に含める。

- Gemini Enterprise Agent Platform API（旧 Vertex AI API）
- Gemini Live API on Gemini Enterprise Agent Platform（旧 Vertex AI Live API）
- Generative AI on Gemini Enterprise Agent Platform（旧 Generative AI on Vertex AI）

本アプリの Live 会話とテキストのディレクター処理は、この範囲に入る。
Google Pre-Trained Model を使う場合だけの例外も、§20(d) にはない。

## 2. 条項の確認日と履歴

- 現行 Service Specific Terms の表示上の最終更新日: **2026-07-29**
- 公開アーカイブで年齢制限を確認できる最初の版: **2023-06-05**
- 直前の **2023-05-24** 版には同じ年齢制限がない

これは公開ページの版の比較であり、個別アカウントへの契約上の発効日を断定するものではない。
正確な発効日は、当該アカウントの Agreement、注文書、改定通知を確認する。

- [2023-06-05 版](https://cloud.google.com/terms/service-terms/index-20230605)
- [2023-05-24 版](https://cloud.google.com/terms/service-terms/index-20230524)

## 3. 学校・保護者同意・Workspace の例外

Google Cloud §20(d) に、学校利用、教育目的、保護者同意、学校の包括同意による公開例外はない。
個人情報保護法上の説明・同意を適切に行っても、プロバイダーとの契約上の禁止は解消しない。

[Google Workspace Specific Terms §12.6](https://workspace.google.com/terms/service-terms-20250909/)
には、Education Fundamentals / Standard / Plus が18歳未満へ Gemini for Education と
NotebookLM を有効化できる限定例外がある。一方、Google AI Pro for Education の拡張機能は
18歳未満へ提供できない。この Workspace 固有の例外は、別製品である Google Cloud / Vertex AI API
の §20(d) を変更しない。

[Google Workspace for Education の同意条項](https://workspace.google.com/terms/education-consent/)
も Workspace の Core Services / Additional Products に関する学校・保護者の責任を定めるもので、
本アプリの Vertex AI 利用を許可する条項ではない。

## 4. 移行候補

いずれも「そのまま学校導入できる」という意味ではない。外部 AI 規約の入口を比較した候補であり、
学校との注文書、個人情報取扱い、越境処理、委託先管理、削除、障害対応、監査を別途確定する。

| 候補 | 公式規約で確認できる入口 | 未確定事項 |
|---|---|---|
| OpenAI API / Realtime | Services Agreement §3.3(c) は、未成年利用に保護者・法定代理人同意を要求する | 同意証跡、DPA、保持設定、処理地域、学校向け安全設計 |
| Azure OpenAI | Product Terms と DPA の適用。公開規約で Google §20(d) と同じ一律禁止は確認できない | 個別注文書で年齢・学校用途を確認。Realtime の処理地域も確認 |
| Amazon Bedrock | AWS Service Terms に加え、選ぶモデルごとの第三者モデル規約が適用される | モデル別年齢条件。日本語リアルタイム音声の対応と処理地域 |

現実的な順序は次のとおり。

1. 未成年・学校向け Vertex 経路を fail-closed にする
2. 音声会話の置換速度を優先する場合、OpenAI Realtime を規約・DPA・保持設定込みで検証する
3. 学校調達と地域制御を優先する場合、Azure の地域別 STT / LLM / TTS 構成を検証する
4. 国内リージョンを優先する場合、AWS の STT / Bedrock / TTS 構成とモデル個別規約を検証する

公式資料:

- [OpenAI Services Agreement](https://openai.com/policies/services-agreement/)
- [OpenAI API data controls](https://platform.openai.com/docs/guides/your-data)
- [Microsoft Product Terms for Online Services](https://www.microsoft.com/licensing/terms/product/ForOnlineServices/all)
- [Azure OpenAI data, privacy, and security](https://learn.microsoft.com/azure/ai-foundry/responsible-ai/openai/data-privacy)
- [AWS Service Terms](https://aws.amazon.com/service-terms/)
- [Amazon Bedrock third-party model terms](https://aws.amazon.com/legal/bedrock/third-party-models/)

## 5. 学校導入で別途必要な確認

外部 AI の年齢規約を満たすことは入口にすぎない。学校導入前に少なくとも次を確定する。

- 学校設置者の教育情報セキュリティポリシーへの適合
- 利用目的、必要最小限のデータ、同意または他の適法な取扱根拠
- 国外処理、委託先・再委託先、責任分界、暗号化、アクセス制御、監査ログ
- 障害・事故通知、SLA、バックアップ、終了時の返却・削除、監査方法
- 学校一括契約、請求書、組織・教員・生徒・座席のライフサイクル
- 教員の監督、AI 出力の確認、成績評価などを AI だけで決めない運用

学校向けの現行ギャップは [`school-readiness.md`](school-readiness.md) を参照する。

## 6. 通信しない端末内モードのscope分離

外部サービスを使えないことと、個人のゲーム機構を止めることは同じではない。
Consent画面では次の2経路を明示的に分ける。

| 選択中の経路 | 保存scope | 個人ゲーム機構 | 外部接続 |
|---|---|---|---|
| 18歳未満の本人利用 | `personal` | streak / freeze / gems / hearts / daily・monthly quest / 同端末協力・週次リーグを有効にする | 外部AI・学校サーバ・購入Provider・外部LANを提供しない |
| 「学校からもらって使います」を選択 | `schoolLocal` | 個人報酬なし、ハート無制限、端末内の授業入口だけを有効にする | 外部AI・学校サーバ・購入Provider・外部LANを提供しない |

年齢帯、本人・学校の選択、端末内モードへの入場は永続化していない。再起動すると
Consent画面へ戻り、その回に選んだ経路からscopeを決め直す。このため、旧版が作った
`schoolLocal`記録を「実は本人利用だった」と推測して`personal`へ移す自動migrationは
行わない。既存`personal`記録はそのまま本人経路から再開し、既存`schoolLocal`記録は
学校scopeの記録として維持する。この未永続境界と再起動時の挙動はAppShell E2Eで固定する。

## 現在の運用判断

- **公開・ストア申請:** 中高生向け Vertex ビルドは提出しない
- **外部AI・学校サーバを使う学校実証:** 行わない
- **18歳未満の個人利用:** Vertex AI会話は提供しない。個人ゲーム機構を持つ、通信しない`personal`端末内モードだけを選べる
- **18歳以上の開発確認:** 開発環境に限定し、対象者と経路を明確に分離する
- **再開条件:** 利用可能な別基盤へ移行するか、対象用途を許可する Google との書面契約を締結する
