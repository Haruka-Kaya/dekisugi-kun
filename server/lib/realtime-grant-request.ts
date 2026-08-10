import { envLang, type Lang } from './i18n.js'
import {
  isMissionKind,
  isTeachingTactic,
  type MissionKind,
  type TeachingTactic,
} from './mission.js'
import { focusUnit, unitById } from './units.js'

/**
 * Realtime providerへ渡してよい、検証済みの学習ミッション。
 *
 * provider固有のcredentialを発行する前にこの形へ落とす。端末からモデル名・
 * system instruction・voiceなどを受け取らないので、providerを替えても
 * 学習契約をクライアント側から差し替えられない。
 */
export type RealtimeGrantRequest = {
  unitId: string
  focusConceptKey?: string
  missionKind: MissionKind
  teachingTactic: TeachingTactic
  lang: Lang
}

export type RealtimeGrantRequestError = {
  error:
    | 'unknown_unit'
    | 'unknown_concept'
    | 'unknown_mission_kind'
    | 'focus_required'
    | 'unknown_teaching_tactic'
    | 'unknown_language'
  detail?: string
}

export type RealtimeGrantRequestResult =
  | { ok: true; value: RealtimeGrantRequest }
  | { ok: false; response: RealtimeGrantRequestError }

function record(value: unknown): Record<string, unknown> | undefined {
  if (value == null || typeof value !== 'object' || Array.isArray(value)) {
    return undefined
  }
  return value as Record<string, unknown>
}

/**
 * 単元・対象概念・ミッション・作戦をallowlistで検証する。
 *
 * この関数はrate / quota / 外部APIより前で呼ぶこと。壊れた入力で利用枠や
 * OpenAIのclient secret発行枠を消費させないため、暗黙のfallbackは
 * 「フィールド未指定」の旧client互換だけに限定する。
 */
export function parseRealtimeGrantRequest(
  raw: unknown,
): RealtimeGrantRequestResult {
  const body = record(raw)
  if (!body) {
    return { ok: false, response: { error: 'unknown_unit' } }
  }
  const unitId = body.unitId
  const unit = typeof unitId === 'string' ? unitById(unitId) : undefined
  if (typeof unitId !== 'string' || !unit) {
    return { ok: false, response: { error: 'unknown_unit' } }
  }

  const hasFocus = Object.hasOwn(body, 'focusConceptKey')
  const rawFocus = body.focusConceptKey
  if (hasFocus && typeof rawFocus !== 'string') {
    return { ok: false, response: { error: 'unknown_concept' } }
  }
  const focusConceptKey = typeof rawFocus === 'string' ? rawFocus : undefined
  if (!focusUnit(unit, focusConceptKey)) {
    return {
      ok: false,
      response: { error: 'unknown_concept', detail: focusConceptKey },
    }
  }

  const hasMissionKind = Object.hasOwn(body, 'missionKind')
  const rawMissionKind = body.missionKind
  if (hasMissionKind && !isMissionKind(rawMissionKind)) {
    return { ok: false, response: { error: 'unknown_mission_kind' } }
  }
  const missionKind =
    hasMissionKind && isMissionKind(rawMissionKind) ? rawMissionKind : 'teach'
  if (missionKind !== 'teach' && focusConceptKey == null) {
    return { ok: false, response: { error: 'focus_required' } }
  }

  const hasTeachingTactic = Object.hasOwn(body, 'teachingTactic')
  const rawTeachingTactic = body.teachingTactic
  if (hasTeachingTactic && !isTeachingTactic(rawTeachingTactic)) {
    return { ok: false, response: { error: 'unknown_teaching_tactic' } }
  }
  const teachingTactic =
    hasTeachingTactic && isTeachingTactic(rawTeachingTactic)
      ? rawTeachingTactic
      : 'reason'

  const hasLang = Object.hasOwn(body, 'lang')
  if (hasLang && body.lang !== 'ja' && body.lang !== 'en') {
    return { ok: false, response: { error: 'unknown_language' } }
  }
  const lang = hasLang ? (body.lang as Lang) : envLang()

  return {
    ok: true,
    value: {
      unitId,
      focusConceptKey,
      missionKind,
      teachingTactic,
      lang,
    },
  }
}
