/**
 * 同じ概念へ、どの学習行為として挑むか。
 *
 * 値はFlutterの `MissionKind.wire` と共有する公開API契約。
 * 未指定の旧クライアントは必ず `teach` として扱う。
 */
export const MISSION_KINDS = ['teach', 'repair', 'caseRetry'] as const

export type MissionKind = (typeof MISSION_KINDS)[number]

export function isMissionKind(value: unknown): value is MissionKind {
  return typeof value === 'string' && MISSION_KINDS.includes(value as MissionKind)
}

/**
 * 教材を閉じる前に本人が選ぶ、説明を始める足場。
 *
 * 値はFlutterの `TeachingTactic.wire` と共有する公開API契約。
 * 未指定の旧クライアントだけは `reason` として扱う。
 */
export const TEACHING_TACTICS = ['example', 'reason', 'experiment'] as const

export type TeachingTactic = (typeof TEACHING_TACTICS)[number]

export function isTeachingTactic(value: unknown): value is TeachingTactic {
  return typeof value === 'string' && TEACHING_TACTICS.includes(value as TeachingTactic)
}
