import { misconceptionsFor } from './misconceptions.js'
import { type Unit, unitById } from './units.js'

/**
 * 理解カルテ — 単元の概念ごとに「どこまで説明できたか」を追う。
 * 会話中はここの空きを狙って質問を作る。
 *
 * `jiyu-kenkyu-ai` の取材カルテと同じ骨格だが、
 * **誘発の観測（[Slot.probe]）が増えている**のがデキすぎ君固有。
 */

/** 生徒がその概念を説明できたか。 */
export type SlotStatus =
  /** まだ触れていない */
  | 'untouched'
  /** 触れたが薄い（結論だけ、条件が抜けている等） */
  | 'thin'
  /** 説明できた */
  | 'explained'

/**
 * 誤概念を誘発した結果。**これは正誤の採点ではなく行動の観測。**
 *
 * `accepted` は「生徒が誤概念を持っている」の証明ではない。
 * 聞き流した・言葉に詰まった・話題が流れた、でも同じ見え方になる。
 * だから画面では**断定しない**（C9）。復習に回す材料としてだけ使う。
 */
export type ProbeResult =
  /** まだ誤概念を口にしていない */
  | 'notTried'
  /** 口にしたが、生徒の反応から判断がつかない */
  | 'unclear'
  /** 生徒が訂正した */
  | 'corrected'
  /** 生徒が訂正しなかった（同意した・流した） */
  | 'accepted'

export type Probe = {
  /** 誤概念ID */
  id: string
  result: ProbeResult
  /** 判断の根拠になった生徒の発話ID。**無ければ判定を採用しない** */
  evidence: string[]
  /**
   * `accepted` のあとで正しい内容を差し出し済みか（C3）。
   * これが無いと毎ターン同じ訂正を持ち出して会話が止まる。
   */
  countered?: boolean
}

export type Slot = {
  key: string
  /** 画面表示用。クライアントに単元カタログを持たせないため入れてある */
  label: string
  status: SlotStatus
  /** 生徒が説明した内容（校正済み） */
  content: string
  /** 根拠となる発話ID。空なら status は untouched でなければならない */
  evidence: string[]
  /** 次に何を引き出せば埋まるか */
  followUpHint: string
  /** この概念に紐づく誤概念の誘発結果 */
  probes: Probe[]
}

export type Dossier = {
  unitId: string
  slots: Slot[]
  /** 0〜100。重み付き充足度 */
  coverage: number
}

export function emptyDossier(unitId: string): Dossier {
  const unit = unitById(unitId)
  if (!unit) throw new Error(`未知の単元: ${unitId}`)
  return {
    unitId,
    slots: unit.concepts.map((c) => ({
      key: c.key,
      label: c.label,
      status: 'untouched' as SlotStatus,
      content: '',
      evidence: [],
      followUpHint: c.intent,
      probes: misconceptionsFor(c.key).map((m) => ({
        id: m.id,
        result: 'notTried' as ProbeResult,
        evidence: [],
      })),
    })),
    coverage: 0,
  }
}

const STATUS_SCORE: Record<SlotStatus, number> = {
  untouched: 0,
  thin: 0.5,
  explained: 1,
}

export const STATUS_RANK: Record<SlotStatus, number> = {
  untouched: 0,
  thin: 1,
  explained: 2,
}

/**
 * 重み付き充足度。**モデルの自己申告ではなくこちらで計算する。**
 *
 * 根拠のないスロットは status を無視して 0 点。
 * 「説明できた」と書いてあっても、どの発話でそう言ったか示せないなら数えない。
 */
export function computeCoverage(dossier: Dossier): number {
  const unit = unitById(dossier.unitId)
  if (!unit) return 0
  const weightOf = new Map(unit.concepts.map((c) => [c.key, c.weight]))

  let got = 0
  let total = 0
  for (const slot of dossier.slots) {
    const weight = weightOf.get(slot.key) ?? 0
    total += weight
    const status = slot.evidence.length === 0 ? 'untouched' : slot.status
    got += weight * STATUS_SCORE[status]
  }
  return total === 0 ? 0 : Math.round((got / total) * 100)
}

/** 埋まっていない概念を、引き出すべき優先順に返す */
export function gaps(dossier: Dossier, unit: Unit): Slot[] {
  const weightOf = new Map(unit.concepts.map((c) => [c.key, c.weight]))
  return dossier.slots
    .filter((s) => s.status !== 'explained' || s.evidence.length === 0)
    .sort((a, b) => {
      const byStatus = STATUS_SCORE[a.status] - STATUS_SCORE[b.status]
      if (byStatus !== 0) return byStatus
      return (weightOf.get(b.key) ?? 0) - (weightOf.get(a.key) ?? 0)
    })
}

/**
 * 次に誘発すべき誤概念を選ぶ。**LLM に選ばせない。**
 *
 * 条件は機械的:
 * 1. その概念を生徒が説明済み（thin 以上）— 説明する前に誤概念を出すと、
 *    生徒の説明ではなくこちらの誘導に答えるだけになる
 * 2. まだ誘発していない、または unclear で再試行の余地がある
 *
 * 返すのは1件だけ。まとめて出すと1つの発話に混ざって観測が濁る。
 */
export function nextProbe(
  dossier: Dossier,
  unit: Unit,
  opts: { retryUnclear?: boolean } = {},
): { conceptKey: string; misconceptionId: string } | null {
  const weightOf = new Map(unit.concepts.map((c) => [c.key, c.weight]))
  const ready = dossier.slots
    .filter((s) => STATUS_RANK[s.status] >= STATUS_RANK.thin && s.evidence.length > 0)
    .sort((a, b) => (weightOf.get(b.key) ?? 0) - (weightOf.get(a.key) ?? 0))

  for (const slot of ready) {
    const target = slot.probes.find(
      (p) => p.result === 'notTried' || (opts.retryUnclear && p.result === 'unclear'),
    )
    if (target) return { conceptKey: slot.key, misconceptionId: target.id }
  }
  return null
}

/**
 * 復習に回すもの。**「弱点」と呼ばない。**
 *
 * - 誤概念を訂正できなかった概念
 * - 説明が薄いままの概念
 *
 * `unclear` は入れない。判断がついていないものを「できていない」側に置くと、
 * 触れてもいないことを突きつけることになる。
 */
export function toReview(dossier: Dossier): Slot[] {
  return dossier.slots.filter(
    (s) =>
      s.probes.some((p) => p.result === 'accepted') ||
      (s.evidence.length > 0 && s.status === 'thin'),
  )
}
