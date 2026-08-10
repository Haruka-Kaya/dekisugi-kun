# Google への問い合わせ（旧下書き・送信禁止）

更新: **2026-08-09**

> [!danger] 以前の問い合わせ文は送らない
> 「Vertex AI には18歳未満向け禁止がない」という前提が誤っていたため、旧文面を廃止した。

## 公式規約で確定したこと

- [Google Cloud Service Specific Terms §20(d)](https://cloud.google.com/terms/service-terms) は、
  18歳未満向け、または18歳未満がアクセスする可能性が高いオンラインサービスでの
  生成AIサービス利用を禁止している
- [Google Cloud Platform Services Summary](https://cloud.google.com/terms/services) は、
  Vertex AI API と Vertex AI Live API を生成AIサービスに含めている
- 条項には、教育目的、学校承認、保護者同意による公開例外がない
- 年齢ゲートを設けても、中高生向け製品自体の性質は変わらない

したがって、通常のサポートへ「使ってよいか」と問い合わせて回答を待ちながら学校実証を進めることはしない。
現在必要なのは、**未成年・学校向けの提供停止と AI 基盤の移行**である。

## Google を継続候補にする場合

必要なのは非公式なサポート回答ではなく、本用途を明示的に許可する **Google との書面契約**である。
営業・法務窓口には、少なくとも次を契約文書に入れられるか確認する。

- 日本の中高生向けアプリで Vertex AI API / Vertex AI Live API を使えること
- Service Specific Terms §20(d) との優先関係
- 対象年齢、学校・家庭利用、音声・文字の処理範囲
- データ処理地域、保持、削除、再委託、事故通知、監査、SLA

口頭説明、コミュニティ回答、一般サポートの解釈だけでは再開しない。

## 次の行動

1. 未成年・学校向け Vertex 経路を fail-closed のまま維持する
2. OpenAI / Azure / AWS を、年齢規約・処理地域・DPA・音声要件で比較する
3. 学校向け注文書、個人情報取扱い、削除、障害対応、監査を整備する
4. 移行後に学校資料とストア申請資料を再レビューする

詳細は [`../age-restriction.md`](../age-restriction.md) と
[`../school-readiness.md`](../school-readiness.md) を参照する。
