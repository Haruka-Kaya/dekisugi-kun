# 年齢制限 — いまの構成は規約上使えない

**確認日: 2026-08-05**

## 何が問題か

Gemini API（`ai.google.dev` のキーで叩くもの）の追加利用規約、「Age Requirements」より:

> You must be 18 years of age or older to use the APIs. You also will not use the
> Services as part of a website, application, or other service (collectively, "API
> Clients") that is **directed towards or is likely to be accessed by individuals
> under the age of 18**.

デキすぎ君は**中高生向けだと明言している製品**なので、後半に真正面から当たる。
この条項は有料/無料の区別より前に置かれているので、**課金しても外れない**。

出典: https://ai.google.dev/gemini-api/terms

> [!caution] 見落とした経緯
> 調査フェーズでロイヤリティ・著作権・保護者同意は掘ったが、
> **API 側の年齢条項を見ていなかった。**
> 段階5 で保護者同意まで実装したあとに出てくる話ではなかった。
> **外部サービスに乗るときは、対象年齢と利用規約を先に突き合わせる。**

## Vertex AI なら通るのか

Vertex AI は Google Cloud Platform 規約の下にあり、次のどちらにも
**同じ年齢条項が見当たらない**:

- Google Cloud Platform Terms of Service
- Service Specific Terms（Vertex AI / Generative AI の節）

ただし**「条項が見当たらない」は「使ってよい」の証明ではない。**
K-12 向けの製品が GCP 上に多数あることは傍証だが、
公開前に一次情報で裏を取るか、Google に確認すること。

## 移行すると壊れるもの

**認証方式が違う。**

| | Gemini API（いま） | Vertex AI |
|---|---|---|
| 端末が持つもの | ephemeral token | OAuth 2.0 bearer token |
| 発行元 | `authTokens.create()` | サービスアカウント |
| 寿命の指定 | **分単位で自由** | OAuth の既定に従う |
| 期限切れの挙動 | **セッションごと切れる**（実測 `code=1011`） | **未確認** |

いまの「1日15分」は、**トークンの寿命がそのまま会話時間になる**ことに
乗っている（`server/lib/quota.ts` 参照）。Vertex では同じ手が使えるか分からない。

### 取りうる形

| 案 | 中身 | 効く上限 | 要るもの |
|---|---|---|---|
| A | 短命の OAuth トークンを端末へ渡す | **期限切れでセッションが切れるかに依存（未測定）** | GCP プロジェクト |
| B | **音声をサーバで中継する** | 完全に効く（こちらが全バイトを見る） | 常時接続を保てるホスト（Cloud Run 等）。Vercel の関数では持てない |

B なら端末は Gemini の資格情報を一切持たないので、上限も鍵の秘匿も同時に解ける。
代わりに、会話の音声がサーバを通るぶん遅延とホスティング費用が増える。

**A が成立するかは測れば分かる。** 短命トークンで繋いで、期限後に発話が通るかを見る。
`server/test/live-token.live.test.ts` と同じやり方。

## 測った結果（2026-08-05）

`server/_probe-vertex-life.mts` で、2分おきに一言送りながら観察した。

```
00分 トークン取得。期限まで 60 分
00分 接続 OK
00分 生きている（音声 20714 B）
02分 生きている（音声 22634 B）
...
08分 生きている（音声 24554 B）
09分 ★ 切断: code=1000 reason=The operation was cancelled.
```

**トークンの期限（60分）ではなく、Vertex 自身が約10分でセッションを打ち切る。**

### これで決まること

| 分かったこと | 設計への影響 |
|---|---|
| セッションは**約10分で必ず終わる** | 1接続で無限に話せない。**上限の土台にできる** |
| トークンの期限は会話時間を縛らない | 「渡す寿命＝会話時間」はそのままでは使えない |

→ **上限は「分」ではなく「セッション数」で数える。**
1セッション ≒ 10分なので、無料15分は「**1日2セッション**」に読み替える。

端末にアクセストークンを渡す形（案A）で成立する。**中継（案B）は要らない。**

> [!warning] トークンは60分有効で、権限も広い
> セッション上限は Vertex 側が守ってくれるが、**トークン自体は60分間、
> サービスアカウントの権限で何でもできる。**
> 端末に渡す以上、サービスアカウントの権限は
> `roles/aiplatform.user` だけに絞っておくこと（設定済み）。
>
> より厳しくするなら、`iamcredentials.generateAccessToken` で
> 寿命を短くしたトークンを配る。**これは未実装。**

## 残っている確認

- 本番の会話設定一式（システム指示・VAD・文字起こし・セッション再開）が
  Vertex でも通るか。**Developer API では「音だけ出ない」壊れ方をした**ので、
  同じ確認をやる
- Vertex では ephemeral token が無いため、**会話設定を端末が送る**ことになる。
  つまりペルソナと `[DIRECTOR]` の約束を端末から改変できてしまう。
  中継しない限りこれは避けられない
