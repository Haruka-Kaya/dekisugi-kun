import { jstDayKey, jstWeekKey } from './day.js'
import { hasKv, kv } from './kv.js'
import { MAX_MEMBERS, newInviteCode } from './team.js'
import { CONTRIBUTE_TEAM_SCRIPT, JOIN_TEAM_SCRIPT, LEAVE_TEAM_SCRIPT } from './team-membership-scripts.js'

/**
 * チームの保存。**`team.ts` は純粋に保ち、Redis に触るのはここだけ。**
 *
 * ## 保存物に端末IDを書かない
 *
 * キーに入るのは `memberId()` の出力（HMAC）だけ。
 * Redis のダンプを見ても、どの端末のものか復元できない。
 *
 * ## KV が無ければ全部止める
 *
 * `quota.ts` / `ratelimit.ts` は「読めないときは通す」が、
 * あれは**締めると障害が全滅になる制限側**の判断。
 * **保存側に転用しない。** 200 を返しておいて実は消えている、が最悪。
 */

/** チームの器。 */
export type Team = {
  id: string
  name: string
  periodId: string
  periodStart: string
  periodEnd: string
}

export type InviteCode = {
  code: string
  teamId: string
  /** epoch ms */
  expiresAt: number
  revoked: boolean
}

export class NoStore extends Error {
  constructor() {
    super('保存先が設定されていない')
  }
}

function need(): void {
  if (!hasKv()) throw new NoStore()
}

// ── キー ────────────────────────────────────────────────────
//
// **すべて `t:` の下。** 端末IDは1文字も入らない。

export const keys = {
  code: (code: string) => `t:code:${code}`,
  team: (teamId: string) => `t:${teamId}`,
  members: (teamId: string) => `t:${teamId}:m`,
  /** そのメンバーの日ごとの寄与。退出で消す唯一の個人記録 */
  memberDays: (teamId: string, mid: string) => `t:${teamId}:d:${mid}`,
  sum: (teamId: string, periodId: string) => `t:${teamId}:sum:${periodId}`,
  mine: (mid: string) => `t:mine:${mid}`,
  cooldown: (mid: string) => `t:cool:${mid}`,
}

/** チーム変更のクールダウン（秒）。週1回まで。 */
export const CHANGE_COOLDOWN_SECONDS = 7 * 86400

/** 招待コードの既定の寿命（日）。学期末に寄せた長さ。 */
export const CODE_TTL_DAYS = 90

/**
 * 期限切れのコードを消さずに残す期間（日）。
 *
 * **TTL で消すと 404 になり、「期限切れ(410)」と区別できない。**
 * 墓標を残しておけば「先生にもう一度もらってください」と言える。
 */
const CODE_TOMBSTONE_DAYS = 90

/** ハッシュの応答を素直な連想配列にする。 */
function toHash(v: unknown): Record<string, string> {
  if (!v) return {}
  if (Array.isArray(v)) {
    const out: Record<string, string> = {}
    for (let i = 0; i + 1 < v.length; i += 2) out[String(v[i])] = String(v[i + 1])
    return out
  }
  if (typeof v === 'object') {
    return Object.fromEntries(
      Object.entries(v as Record<string, unknown>).map(([k, x]) => [k, String(x)]),
    )
  }
  return {}
}

// ── 器を作る ────────────────────────────────────────────────

/** 週の区切り。月曜はじまり。 */
export function currentPeriod(now = Date.now()): {
  periodId: string
  periodStart: string
  periodEnd: string
} {
  const start = jstWeekKey(jstDayKey(now))
  const end = jstDayKey(Date.parse(`${start}T00:00:00Z`) + 6 * 86400_000)
  return { periodId: `w:${start}`, periodStart: start, periodEnd: end }
}

/**
 * チームと招待コードを作る。**管理トークン経由でのみ呼ぶこと。**
 *
 * 先生に文字列を決めさせない。決めさせると学校名やクラス名がコードに入り、
 * それは端末→サーバへ流れる**新しい識別要素**になる（同意文面に波及する）。
 */
export async function createTeam(
  name: string,
  opts: { now?: number; ttlDays?: number; random?: () => number } = {},
): Promise<{ team: Team; code: InviteCode }> {
  need()
  const now = opts.now ?? Date.now()
  const period = currentPeriod(now)
  const teamId = newInviteCode(opts.random) + newInviteCode(opts.random)
  const code = newInviteCode(opts.random)
  const expiresAt = now + (opts.ttlDays ?? CODE_TTL_DAYS) * 86400_000

  await kv([
    [
      'HSET',
      keys.team(teamId),
      'name',
      name,
      'createdAt',
      String(now),
      'periodId',
      period.periodId,
      'periodStart',
      period.periodStart,
      'periodEnd',
      period.periodEnd,
    ],
    ['EXPIRE', keys.team(teamId), String(400 * 86400)],
    [
      'HSET',
      keys.code(code),
      'teamId',
      teamId,
      'expiresAt',
      String(expiresAt),
      'revoked',
      '0',
    ],
    // **墓標を残す。** 消すと 410 と 404 が区別できない
    ['PEXPIREAT', keys.code(code), String(expiresAt + CODE_TOMBSTONE_DAYS * 86400_000)],
  ])

  return {
    team: { id: teamId, name, ...period },
    code: { code, teamId, expiresAt, revoked: false },
  }
}

export async function revokeCode(code: string): Promise<boolean> {
  need()
  const found = await readCode(code)
  if (!found) return false
  await kv([['HSET', keys.code(code), 'revoked', '1']])
  return true
}

export async function readCode(code: string): Promise<InviteCode | undefined> {
  need()
  const h = toHash((await kv([['HGETALL', keys.code(code)]]))[0])
  if (!h.teamId) return undefined
  return {
    code,
    teamId: h.teamId,
    expiresAt: Number(h.expiresAt ?? 0),
    revoked: h.revoked === '1',
  }
}

export async function readTeam(teamId: string): Promise<Team | undefined> {
  need()
  const h = toHash((await kv([['HGETALL', keys.team(teamId)]]))[0])
  if (!h.name) return undefined
  return {
    id: teamId,
    name: h.name,
    periodId: h.periodId ?? '',
    periodStart: h.periodStart ?? '',
    periodEnd: h.periodEnd ?? '',
  }
}

// ── 参加と退出 ──────────────────────────────────────────────

export type JoinResult =
  | { ok: true; team: Team; memberCount: number; alreadyIn: boolean }
  | { ok: false; reason: 'unknown_code' | 'expired' | 'team_full' | 'in_other_team' | 'cooldown' }

/**
 * コードでチームに入る。
 *
 * **同じチームへの二度目は成功にする**（冪等）。
 * 端末が応答を取りこぼして押し直したときに、409 で止めない。
 */
export async function joinTeam(
  mid: string,
  code: string,
  now = Date.now(),
): Promise<JoinResult> {
  need()
  const found = await readCode(code)
  if (!found) return { ok: false, reason: 'unknown_code' }
  // The lookup only selects keys. Lua rechecks the current code and team before
  // checking membership/capacity and writing; a pipeline alone is not atomic.
  const [result] = await kv([[
    'EVAL', JOIN_TEAM_SCRIPT, '5', keys.code(code), keys.team(found.teamId),
    keys.members(found.teamId), keys.mine(mid), keys.cooldown(mid),
    found.teamId, mid, String(now), String(MAX_MEMBERS), String(400 * 86400),
  ]])
  const failure = () => new Error('チーム参加応答の形式が不正です')
  if (!Array.isArray(result)) throw failure()
  if (result.length === 2 && result[0] === 0) {
    const reason = result[1]
    if (reason === 'unknown_code' || reason === 'expired' || reason === 'team_full'
      || reason === 'in_other_team' || reason === 'cooldown') return { ok: false, reason }
  }
  if (result.length !== 7 || result[0] !== 1
    || result.slice(1, 5).some((value) => typeof value !== 'string')
    || !Number.isSafeInteger(result[5]) || result[5] < 0
    || (result[6] !== 0 && result[6] !== 1)) throw failure()
  return {
    ok: true,
    team: {
      id: found.teamId, name: result[1], periodId: result[2],
      periodStart: result[3], periodEnd: result[4],
    },
    memberCount: result[5], alreadyIn: result[6] === 1,
  }
}

/**
 * チームを抜ける。
 *
 * > [!important] 合計を減らさない
 * > 減らすと、クラスの合計が突然落ちて**「誰かが抜けた」が全員に見える**。
 * > 誰かは分からなくても、抜けた事実の可視化そのものが離脱の引き金になる。
 *
 * 個人に紐づく唯一の記録（日ごとの寄与）を消せば、
 * 残る合計は**もう誰にも帰属しない集計値**になる。
 * 「引くと可視化／残すと個人に紐づく」のジレンマは、これで両方満たせる。
 */
export async function leaveTeam(mid: string, teamId: string, now = Date.now()): Promise<boolean> {
  need()
  // Remove only individual records (never totals), and install the one-week
  // cooldown in the same execution so a concurrent join cannot slip between.
  const [result] = await kv([[
    'EVAL', LEAVE_TEAM_SCRIPT, '4', keys.members(teamId), keys.mine(mid),
    keys.memberDays(teamId, mid), keys.cooldown(mid), mid, teamId,
    String(now + CHANGE_COOLDOWN_SECONDS * 1000), String(CHANGE_COOLDOWN_SECONDS),
  ]])
  if (result !== 0 && result !== 1) throw new Error('チーム退出応答の形式が不正です')
  return result === 1
}

// ── 貢献 ────────────────────────────────────────────────────

export type Applied = { day: string; value: number; added: number }
export type Rejected = { day: string; reason: string }

/**
 * その日の寄与を記録する。**冪等。**
 *
 * ## 差分だけ足す
 *
 * 同じ日を何度送っても総和は動かない。値を**減らして**送っても動かない。
 * これがないと、端末がオフラインぶんをまとめて再送するたびに合計が膨らむ。
 *
 * ## `kv()` はトランザクションではない
 *
 * 所属の再確認、日次の差分、合計更新を同じLua実行で確定する。
 * 退出より先なら個人記録は退出で消え、退出より後なら書き込まない。
 * 短期ロックの期限や別pipelineの順序には依存しない。
 */
export async function contribute(
  mid: string,
  team: Team,
  entries: { day: string; value: number }[],
  now = Date.now(),
): Promise<{ applied: Applied[]; rejected: Rejected[] }> {
  need()
  const applied: Applied[] = []
  const rejected: Rejected[] = []

  for (const e of entries) {
    const [result] = await kv([[
      'EVAL', CONTRIBUTE_TEAM_SCRIPT, '5', keys.mine(mid), keys.members(team.id),
      keys.memberDays(team.id, mid), keys.sum(team.id, team.periodId), keys.team(team.id),
      mid, team.id, team.periodId, e.day, String(e.value), String(400 * 86400),
    ]])
    if (Array.isArray(result) && result.length === 2
      && result[0] === 0 && result[1] === 'not_in_team') {
      rejected.push({ day: e.day, reason: 'not_in_team' })
      continue
    }
    if (!Array.isArray(result) || result.length !== 3 || result[0] !== 1
      || !Number.isSafeInteger(result[1]) || result[1] < 0
      || !Number.isSafeInteger(result[2]) || result[2] < 0 || result[2] > result[1]) {
      throw new Error('チーム寄与応答の形式が不正です')
    }
    applied.push({ day: e.day, value: result[1], added: result[2] })
  }
  return { applied, rejected }
}

/** 期間内の自分のぶん。**他人のぶんは読まない。** */
export async function myTotalIn(
  mid: string,
  team: Team,
): Promise<number> {
  need()
  const h = toHash((await kv([['HGETALL', keys.memberDays(team.id, mid)]]))[0])
  let sum = 0
  for (const [day, v] of Object.entries(h)) {
    if (day < team.periodStart || day > team.periodEnd) continue
    sum += Number(v) || 0
  }
  return sum
}

export async function teamTotal(team: Team): Promise<number> {
  need()
  const v = (await kv([['HGET', keys.sum(team.id, team.periodId), 'total']]))[0]
  return Number(v ?? 0)
}

/** いま入っているチーム。 */
export async function myTeamId(mid: string): Promise<string | undefined> {
  need()
  const v = (await kv([['GET', keys.mine(mid)]]))[0]
  return v == null ? undefined : String(v)
}

export async function memberCount(teamId: string): Promise<number> {
  need()
  return Number((await kv([['SCARD', keys.members(teamId)]]))[0] ?? 0)
}
