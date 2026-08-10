# OpenAI Realtime移行境界

更新: 2026-08-10

## 現在地

`realtimeGrantHandler` は、既存のVertex `/api/live-token`を削除・置換せずに検証する
provider-neutralな移行候補である。内部test専用で、既存の生成AI hard gateを共有する。
Vercel HobbyのFunction上限内で公開機能を維持するためAPI entrypointにはしておらず、
productionの `/api/realtime-grant` は404のままである。

**2026-08-10現在、OpenAI Realtimeはproductionへ未デプロイ。** 実APIの配備と確認なしに
「OpenAIへ移行済み」と扱わない。

## サーバーの発行順序

1. 署名済み匿名端末tokenを検証する。
2. production / preview生成AI hard gateを確認する。
3. `OPENAI_API_KEY`、ZDR確認フラグ、専用HMAC secretの三条件を確認する。
4. `unitId` / `focusConceptKey` / `missionKind` / `teachingTactic` / `lang`をallowlist検証する。
5. 端末rateを消費する。
6. 日次quotaを1セッション分確保する。
7. サーバーからOpenAI `POST /v1/realtime/client_secrets`を呼ぶ。
8. 上流レスポンスから短命credentialと公開metadataだけを抽出して返す。

OpenAI標準API key、raw匿名did、HMAC用secret、`OpenAI-Safety-Identifier`、上流の完全な
session設定はレスポンスにもエラーログにも含めない。safety identifierはraw didを専用secretで
HMAC-SHA256化した安定IDで、client secret発行時の`OpenAI-Safety-Identifier`ヘッダにだけ置く。
成功応答は`Cache-Control: private, no-store`とし、上流の期限が30秒+15秒の許容範囲を
超える、数値でない、または別のtype/modelのsessionならfail closedにする。

## Flutter向けgrant契約

リクエスト例:

```json
{
  "unitId": "force-motion",
  "focusConceptKey": "fall",
  "missionKind": "repair",
  "teachingTactic": "example",
  "lang": "ja"
}
```

成功レスポンスの形:

```json
{
  "provider": "openai",
  "transport": "webrtc",
  "credential": {
    "kind": "ephemeral_bearer",
    "value": "<short-lived client secret>",
    "expiresAt": "<ISO 8601>"
  },
  "connection": {
    "url": "https://api.openai.com/v1/realtime/calls",
    "offerContentType": "application/sdp",
    "eventChannel": "oai-events"
  },
  "session": {
    "id": "sess_...",
    "model": "gpt-realtime-2.1"
  },
  "directorPrefix": "[D:...]",
  "quota": {
    "remainingSessions": 1,
    "entitled": false,
    "resetsAt": "<ISO 8601>"
  }
}
```

Flutter実装は`provider` / `transport` / `credential.kind`を判別し、次の順序で接続する。

1. grant取得前に、マイクtrackと`oai-events` data channelを持つ
   `RTCPeerConnection`とSDP offerを用意する。
2. grantを取得したら、`credential.expiresAt`より前に直ちに接続する。
3. `connection.url`へ`Content-Type: application/sdp`、
   `Authorization: Bearer <credential.value>`でSDPを直接POSTする。
4. 返ったSDP answerをremote descriptionに設定する。
5. safety identifierはclientから送らない。発行時にserver側でclient secretへ結び済み。

client secretの期限は接続開始期限であり、Realtime sessionの終了時刻ではない。発行時に
`expires_after.seconds=30`を固定するが、公式仕様ではsecretは期限内なら複数sessionの作成に
使え、開始済みsessionはsecret失効後も継続できる。この新経路にはVertexの`resumeHandle`互換を
まだ実装していない。再発行は新しい日次枠を消費するため、Flutter切替時に再接続UXを別途
設計する。

## サーバー固定のsession設定

- model: `gpt-realtime-2.1`
- transport: モバイル向けWebRTC
- output: audio
- voice: `marin`
- input transcription: `gpt-realtime-whisper`、`ja`または`en`を明示
- turn detection: `null`（既存push-to-talk / half-duplexを維持）
- noise reduction: `null`（前処理artifactを避け、既定で入れない）
- tools: 無効
- tracing: 無効
- 1応答の上限: 256 output tokens
- client secretの接続開始期限: 発行から30秒

grant APIは端末からmodel・system instruction・voice・toolsを受け取らない。ただしOpenAI公式仕様では、
client secretに関連付けたsession設定はclient接続時に上書きできる。したがって、ephemeral secret
だけで学習persona・tools無効・1secret=1session・会話時間を強制できるとは扱わない。公開前に
server-side controlsまたは中継経路、上書き検知、費用上限を追加して実証する必要がある。

## 学校・未成年向けの未完了条件

`OPENAI_REALTIME_ZDR_APPROVED=1`は、OpenAI側で対象projectのZero Data Retentionが有効に
なったことを確認したという運用上の証跡であり、申請や契約の代わりではない。OpenAI keyや
フラグを設定しただけでは学校向け公開条件を満たさない。

公開判断の前に最低限、次を別途完了・記録する。

- 対象OpenAI projectのZDR承認と実設定の確認
- 学校契約、DPA、個人情報・音声・回答データのフロー確認
- 年齢相応のAI説明、content filter、安全監視、報告・高リスク時のescalation
- 必要なage assuranceと、対象年齢・保護者/学校同意の設計
- OpenAI keyを用いた許可済み環境での実通信・音声・切断・費用上限の検証
- FlutterのWebRTC経路、イベント変換、Director連携、再接続のE2E回帰

## 公式OpenAI一次情報

- [Realtime API with WebRTC](https://developers.openai.com/api/docs/guides/realtime-webrtc)
- [Realtime Client Secrets API reference](https://developers.openai.com/api/reference/resources/realtime/subresources/client_secrets)
- [Safety best practices](https://developers.openai.com/api/docs/guides/safety-best-practices)
- [Under 18 API Guidance](https://developers.openai.com/api/docs/guides/safety-checks/under-18-api-guidance)
- [Data controls / endpoint retention](https://developers.openai.com/api/docs/guides/your-data#default-usage-policies-by-endpoint)

OpenAI公式では、モバイル/ブラウザclientはWebSocketsよりWebRTCが推奨され、標準API keyは
serverだけで使う。`/v1/realtime/client_secrets`で短命credentialを作る場合、安定した
privacy-preserving identifierを発行時の`OpenAI-Safety-Identifier`ヘッダに付けると、
そのidentifierがclient secretへ結び付く。未成年向けには追加の安全措置が必要で、13歳未満
または適用されるデジタル同意年齢未満の個人データを処理する前にZDRが必要とされている。
