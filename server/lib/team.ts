import { createHmac } from 'node:crypto'

import { daysBetween, isValidDay } from './day.js'

/**
 * クラス・部活単位のチーム。
 *
 * ## なぜチームなのか
 *
 * 高校生年代の Duolingo streak 14日保持率は**全年齢中最低の 55%**（50代は 79%）。
 * 日本全体は世界1位の 80% 超なのに、**狙っている層にだけ効かない**。
 *
 * 一方、Duolingo の A/B で最も伸びたのは社会性のある機構だった:
 * Friend Streak が日次レッスン完了率 **+22%**、リーグが学習時間 **+17%**。
 *
 * ## 個人を可視化しない
 *
 * 表示は**貢献した量だけ**。誰が何をしたかは返さない。
 * 未達成者を晒す設計は日本の教室では離脱の引き金になる
 * （L@S 2022 は streak 喪失によるアカウント放棄を記録している）。
 *
 * これは表示の配慮ではなく**構造の制約**として実装する。
 * サーバが返さなければ、端末がどう作られていても晒しようがない。
 */

/** 1チームの人数上限。クラス＋部活を見込んだ数。 */
export const MAX_MEMBERS = 60

/**
 * これ未満なら合計を出さない。
 *
 * > [!warning] 丸めでは防げない
 * > 2人のチームでは `teamTotal - myTotal` が**相手1人の値そのもの**になる。
 * > 3〜4人でも日々の差分から個人が割れる。
 * > これは表示の配慮ではなく**情報理論的な漏れ**なので、
 * > サーバが出さない以外の対処が無い。
 */
export const MIN_MEMBERS_FOR_TOTAL = 5

/** 人数を丸める単位。1人の増減が総和の変化と結びつかないようにする。 */
export const MEMBER_ROUNDING = 5

/** 1日に積める上限。`FREE_SESSIONS_PER_DAY = 2` と整合する。 */
export const MAX_DAILY_CONTRIBUTION = 3

/** 1リクエストで送れる日数。オフライン1か月ぶん。 */
export const MAX_DAYS_PER_REQUEST = 31

/** さかのぼって送れる日数。これより古い日は受け付けない。 */
export const MAX_BACKFILL_DAYS = 14

/**
 * 招待コードの文字集合。
 *
 * Crockford Base32 から **`0 O 1 I L U`** を抜いてある。
 * 紙に書いて配る前提なので、読み違えが起きる文字を残さない
 * （`U` は英語圏で不適切な語を作りやすいため Crockford が除いている）。
 */
export const CODE_ALPHABET = '23456789ABCDEFGHJKMNPQRSTVWXYZ'

/** 招待コードの桁数。30^8 ≒ 6.5e11 で、総当たりには足りない。 */
export const CODE_LENGTH = 8

// ── メンバーID ──────────────────────────────────────────────

/**
 * 端末IDから作る、保存用のメンバーID。
 *
 * **Redis に端末IDをそのまま書かない。** 保存物だけを見ても端末に戻せない。
 *
 * 乱数ではなく決定的にするのは、参加の冪等・退出・重複判定に使うため。
 * 乱数IDだと端末が控えを失った時点で、そのメンバーが迷子になる。
 *
 * `AUTH_SECRET` を回すと全メンバーIDが孤児になる。
 * これは既存の「緊急停止スイッチ」の性質と揃っている。
 */
export function memberId(deviceId: string, secret = process.env.AUTH_SECRET ?? ''): string {
  return createHmac('sha256', secret)
    .update(`team-member:${deviceId}`)
    .digest('hex')
    .slice(0, 32)
}

// ── 招待コード ──────────────────────────────────────────────

/** 招待コードを1つ作る。表示は `ABCD-EFGH`。 */
export function newInviteCode(random: () => number = Math.random): string {
  let out = ''
  for (let i = 0; i < CODE_LENGTH; i++) {
    out += CODE_ALPHABET[Math.floor(random() * CODE_ALPHABET.length)]
  }
  return out
}

/** 入力を正規化する。ハイフン・空白・大文字小文字を吸収する。 */
export function normalizeCode(v: unknown): string | undefined {
  if (typeof v !== 'string') return undefined
  const s = v.toUpperCase().replace(/[\s-]/g, '')
  if (s.length !== CODE_LENGTH) return undefined
  for (const ch of s) if (!CODE_ALPHABET.includes(ch)) return undefined
  return s
}

/** 配る用の見た目。 */
export function formatCode(code: string): string {
  return `${code.slice(0, 4)}-${code.slice(4)}`
}

// ── 貢献 ────────────────────────────────────────────────────

export type ContributionInput = {
  day: string
  conceptsExplained: number
  sessions: number
}

export type DayVerdict =
  | { day: string; ok: true; value: number }
  | { day: string; ok: false; reason: 'invalid_day' | 'out_of_range' | 'future' }

/**
 * その日の寄与値を決める。
 *
 * > [!warning] `sessions` は合計に入れない
 * > Duolingo は Total Sessions の欠陥を認め、品質で重み付けた
 * > **TSLW（Time Spent Learning Well）** へ指標を移している。
 * > 逐語 "Through many nights of XP farming, I lost my drive to learn"。
 * >
 * > 回数は水増しが最も容易で（開閉するだけ）、しかも学びと無関係に増える。
 * > **受け取るが、検証にしか使わない。**
 *
 * 足すのは概念の数だけ。単元の概念数は有限なので**天井が構造的にある**し、
 * 同じ概念を何度説明しても増えない（端末側が差分で数えている）。
 */
export function contributionValue(input: ContributionInput): number {
  const n = Number(input.conceptsExplained)
  if (!Number.isFinite(n) || n <= 0) return 0
  return Math.min(Math.floor(n), MAX_DAILY_CONTRIBUTION)
}

/** 受け付けてよい日か。**未来と、古すぎる日を弾く。** */
export function judgeDay(
  input: ContributionInput,
  today: string,
  periodStart?: string,
): DayVerdict {
  if (!isValidDay(input.day)) {
    return { day: String(input.day), ok: false, reason: 'invalid_day' }
  }
  const diff = daysBetween(input.day, today)
  if (diff < 0) return { day: input.day, ok: false, reason: 'future' }
  if (diff > MAX_BACKFILL_DAYS) {
    return { day: input.day, ok: false, reason: 'out_of_range' }
  }
  if (periodStart && daysBetween(periodStart, input.day) < 0) {
    return { day: input.day, ok: false, reason: 'out_of_range' }
  }
  return { day: input.day, ok: true, value: contributionValue(input) }
}

// ── 集計の見せ方 ────────────────────────────────────────────

export type TeamSummary = {
  state: 'ready' | 'pending'
  teamName: string
  /** **5人未満なら null。** 引き算で個人が割れるため */
  teamTotal: number | null
  myTotal: number
  /** 5人単位に丸めた人数 */
  memberCount: number
  periodStart: string
  periodEnd: string
  milestones: Milestone[]
}

export type Milestone = { key: string; label: string; reached: boolean }

/**
 * 人数を丸める。**下限は [MIN_MEMBERS_FOR_TOTAL]。**
 *
 * 実人数をそのまま返すと、1人の増減が総和の変化と結びついて
 * 「誰かが抜けた」「誰かが入った」が推測できてしまう。
 */
export function roundMembers(n: number): number {
  const rounded = Math.round(n / MEMBER_ROUNDING) * MEMBER_ROUNDING
  return Math.max(MIN_MEMBERS_FOR_TOTAL, rounded)
}

/** チーム単位の到達。**個人には出さない。** */
const MILESTONES: { key: string; at: number; label: string }[] = [
  { key: 'concepts-25', at: 25, label: 'クラスで25個の説明が集まりました' },
  { key: 'concepts-100', at: 100, label: 'クラスで100個の説明が集まりました' },
  { key: 'concepts-250', at: 250, label: 'クラスで250個の説明が集まりました' },
  { key: 'concepts-500', at: 500, label: 'クラスで500個の説明が集まりました' },
]

export function milestonesFor(total: number): Milestone[] {
  return MILESTONES.map((m) => ({
    key: m.key,
    label: m.label,
    reached: total >= m.at,
  }))
}

/**
 * 端末へ返す形を組む。**ここが唯一の出口。**
 *
 * 個人を可視化しない制約は、この関数が返さないことで担保する。
 * 呼び出し側が何を持っていても、ここを通らないと外へ出ない。
 */
export function buildSummary(args: {
  teamName: string
  memberCount: number
  teamTotal: number
  myTotal: number
  periodStart: string
  periodEnd: string
}): TeamSummary {
  const small = args.memberCount < MIN_MEMBERS_FOR_TOTAL
  return {
    state: small ? 'pending' : 'ready',
    teamName: args.teamName,
    // **人数が足りないうちは合計を出さない。** 丸めでは防げない
    teamTotal: small ? null : args.teamTotal,
    myTotal: args.myTotal,
    memberCount: roundMembers(args.memberCount),
    periodStart: args.periodStart,
    periodEnd: args.periodEnd,
    // 到達も人数が足りてから。小さいチームでは到達＝特定の誰かの働きになる
    milestones: small ? [] : milestonesFor(args.teamTotal),
  }
}

/** チーム名。**唯一、人が書く文字列。** 個人名を入れさせない旨は配布資料に書く。 */
export function normalizeTeamName(v: unknown): string | undefined {
  if (typeof v !== 'string') return undefined
  const s = v.replace(/[\r\n\t]/g, ' ').trim()
  if (s.length === 0 || s.length > 24) return undefined
  // URL を名前に入れさせない（配布の抜け道になる）
  if (/https?:\/\//i.test(s)) return undefined
  return s
}
