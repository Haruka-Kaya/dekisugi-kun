import { createHmac } from 'node:crypto'

import { localizeUnit } from './i18n.js'
import { newDirectorPrefix, systemInstruction } from './live-config.js'
import { focusUnit, unitById } from './units.js'
import { type RealtimeGrantRequest } from './realtime-grant-request.js'

/** OpenAI公式のGA Realtimeモデル。変更は安全レビューを伴うコード変更にする。 */
export const OPENAI_REALTIME_MODEL = 'gpt-realtime-2.1'
export const OPENAI_REALTIME_CLIENT_SECRETS_URL =
  'https://api.openai.com/v1/realtime/client_secrets'
export const OPENAI_REALTIME_WEBRTC_URL =
  'https://api.openai.com/v1/realtime/calls'
/** 公式の許容範囲10〜7200秒。接続猶予を残しつつ再利用窓を短く固定する。 */
export const OPENAI_REALTIME_CLIENT_SECRET_TTL_SECONDS = 30
// `expires_at` is anchored to OpenAI's creation time. Allow the 8s request
// timeout plus modest clock skew, but never accept an unexpectedly reusable
// credential as if it were the requested 30-second secret.
const OPENAI_REALTIME_CLIENT_SECRET_EXPIRY_SKEW_SECONDS = 15

export type OpenAiRealtimeRuntimeConfig = {
  apiKey: string
  safetyIdentifierSecret: string
}

/**
 * 学校・未成年向け経路の運用条件。
 *
 * `OPENAI_REALTIME_ZDR_APPROVED=1` は申請の代わりではない。OpenAI側で対象
 * projectのZDRが有効になったことを人が確認したあとだけ設定する運用上の証跡。
 * key、ZDR確認、HMAC secretのどれか一つでも欠ければ閉じる。
 */
export function openAiRealtimeRuntimeConfig(
  env: NodeJS.ProcessEnv = process.env,
): OpenAiRealtimeRuntimeConfig | undefined {
  const apiKey = env.OPENAI_API_KEY
  if (!apiKey || env.OPENAI_REALTIME_ZDR_APPROVED !== '1') return undefined

  // 認証tokenのAUTH_SECRETを流用しない。用途ごとの鍵を分離し、一方の鍵の
  // 交換や漏えいがもう一方の識別・署名へ波及しないようにする。
  const safetyIdentifierSecret = env.OPENAI_SAFETY_IDENTIFIER_SECRET
  if (!safetyIdentifierSecret || safetyIdentifierSecret.length < 32) {
    return undefined
  }
  return { apiKey, safetyIdentifierSecret }
}

export function openAiRealtimeReady(): boolean {
  return openAiRealtimeRuntimeConfig() != null
}

/**
 * 匿名didをそのままOpenAIへ渡さない、安定したprivacy-preserving識別子。
 * HMACなので出力からdidを復元できず、用途ラベルで他の署名と分離する。
 */
export function openAiSafetyIdentifier(
  deviceId: string,
  secret: string,
): string {
  if (!deviceId) throw new Error('device_id_required')
  if (secret.length < 32) throw new Error('safety_identifier_secret_too_short')
  const digest = createHmac('sha256', secret)
    .update('dekisugi:openai-realtime-safety:v1\0', 'utf8')
    .update(deviceId, 'utf8')
    .digest('base64url')
  return `dekisugi_${digest}`
}

export type ProviderNeutralRealtimeGrant = {
  provider: 'openai'
  transport: 'webrtc'
  credential: {
    kind: 'ephemeral_bearer'
    value: string
    expiresAt: string
  }
  connection: {
    url: typeof OPENAI_REALTIME_WEBRTC_URL
    offerContentType: 'application/sdp'
    eventChannel: 'oai-events'
  }
  session: {
    id: string
    model: typeof OPENAI_REALTIME_MODEL
  }
  directorPrefix: string
}

type FetchLike = (
  input: string | URL,
  init?: RequestInit,
) => Promise<Response>

export type CreateOpenAiRealtimeGrantOptions = {
  fetchFn?: FetchLike
  runtimeConfig?: OpenAiRealtimeRuntimeConfig
  now?: number
  directorPrefix?: () => string
}

export class OpenAiRealtimeGrantError extends Error {
  constructor(
    readonly code:
      | 'runtime_unavailable'
      | 'unknown_unit'
      | 'unknown_concept'
      | 'upstream_rejected'
      | 'upstream_invalid_response',
    readonly status?: number,
  ) {
    super(status == null ? code : `${code}:${status}`)
    this.name = 'OpenAiRealtimeGrantError'
  }
}

function object(value: unknown): Record<string, unknown> | undefined {
  if (value == null || typeof value !== 'object' || Array.isArray(value)) {
    return undefined
  }
  return value as Record<string, unknown>
}

function isoFromEpochSeconds(value: number): string | undefined {
  if (!Number.isFinite(value) || value <= 0) return undefined
  const date = new Date(value * 1000)
  return Number.isNaN(date.valueOf()) ? undefined : date.toISOString()
}

/**
 * OpenAIへclient secretを発行してもらう。
 *
 * 標準API keyはAuthorizationヘッダだけに置き、戻り値には含めない。上流の
 * session全体も返さず、端末に必要な短命secretと公開metadataだけを抽出する。
 */
export async function createOpenAiRealtimeGrant(
  deviceId: string,
  request: RealtimeGrantRequest,
  options: CreateOpenAiRealtimeGrantOptions = {},
): Promise<ProviderNeutralRealtimeGrant> {
  const runtime = options.runtimeConfig ?? openAiRealtimeRuntimeConfig()
  if (!runtime) throw new OpenAiRealtimeGrantError('runtime_unavailable')

  const rawUnit = unitById(request.unitId)
  if (!rawUnit) throw new OpenAiRealtimeGrantError('unknown_unit')
  const focusedUnit = focusUnit(rawUnit, request.focusConceptKey)
  if (!focusedUnit) throw new OpenAiRealtimeGrantError('unknown_concept')
  const unit = localizeUnit(focusedUnit, request.lang)

  const now = options.now ?? Date.now()
  const directorPrefix = (options.directorPrefix ?? newDirectorPrefix)()
  const teachingTactic =
    request.missionKind === 'caseRetry' ? 'reason' : request.teachingTactic

  const session = {
    type: 'realtime',
    model: OPENAI_REALTIME_MODEL,
    output_modalities: ['audio'],
    instructions: systemInstruction(
      unit,
      directorPrefix,
      request.lang,
      request.focusConceptKey,
      request.missionKind,
      teachingTactic,
    ),
    // 1応答を短く制限し、教える側へ長い解説を返しにくくする。
    max_output_tokens: 256,
    tool_choice: 'none',
    tools: [],
    tracing: null,
    audio: {
      input: {
        // 既存のpush-to-talk / half-duplex契約を維持する。
        turn_detection: null,
        // 前処理artifactを避けるため、ノイズ抑制を既定で入れない。
        noise_reduction: null,
        transcription: {
          model: 'gpt-realtime-whisper',
          language: request.lang,
        },
      },
      output: { voice: 'marin' },
    },
  }

  const fetchFn: FetchLike =
    options.fetchFn ?? ((input, init) => fetch(input, init))
  const response = await fetchFn(OPENAI_REALTIME_CLIENT_SECRETS_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${runtime.apiKey}`,
      'Content-Type': 'application/json',
      'OpenAI-Safety-Identifier': openAiSafetyIdentifier(
        deviceId,
        runtime.safetyIdentifierSecret,
      ),
    },
    body: JSON.stringify({
      expires_after: {
        anchor: 'created_at',
        seconds: OPENAI_REALTIME_CLIENT_SECRET_TTL_SECONDS,
      },
      session,
    }),
    signal: AbortSignal.timeout(8_000),
  })

  if (!response.ok) {
    // 上流本文をErrorやlogへ混ぜない。本文にcredential断片が含まれる可能性を
    // 否定できないため、statusだけを保持する。
    throw new OpenAiRealtimeGrantError('upstream_rejected', response.status)
  }

  let raw: unknown
  try {
    raw = await response.json()
  } catch {
    throw new OpenAiRealtimeGrantError('upstream_invalid_response')
  }
  const data = object(raw)
  const upstreamSession = object(data?.session)
  const clientSecret = data?.value
  const rawClientSecretExpiresAt = data?.expires_at
  const clientSecretExpiresAtEpoch =
    typeof rawClientSecretExpiresAt === 'number' &&
    Number.isSafeInteger(rawClientSecretExpiresAt)
      ? rawClientSecretExpiresAt
      : undefined
  const clientSecretExpiresAt =
    clientSecretExpiresAtEpoch == null
      ? undefined
      : isoFromEpochSeconds(clientSecretExpiresAtEpoch)
  const sessionId = upstreamSession?.id
  if (
    typeof clientSecret !== 'string' ||
    clientSecret.length === 0 ||
    !clientSecretExpiresAt ||
    clientSecretExpiresAtEpoch == null ||
    clientSecretExpiresAtEpoch * 1000 <= now ||
    clientSecretExpiresAtEpoch * 1000 >
      now +
        (OPENAI_REALTIME_CLIENT_SECRET_TTL_SECONDS +
          OPENAI_REALTIME_CLIENT_SECRET_EXPIRY_SKEW_SECONDS) *
          1000 ||
    typeof sessionId !== 'string' ||
    sessionId.length === 0 ||
    upstreamSession?.type !== 'realtime' ||
    upstreamSession.model !== OPENAI_REALTIME_MODEL
  ) {
    throw new OpenAiRealtimeGrantError('upstream_invalid_response')
  }

  return {
    provider: 'openai',
    transport: 'webrtc',
    credential: {
      kind: 'ephemeral_bearer',
      value: clientSecret,
      expiresAt: clientSecretExpiresAt,
    },
    connection: {
      url: OPENAI_REALTIME_WEBRTC_URL,
      offerContentType: 'application/sdp',
      eventChannel: 'oai-events',
    },
    session: {
      id: sessionId,
      model: OPENAI_REALTIME_MODEL,
    },
    directorPrefix,
  }
}
