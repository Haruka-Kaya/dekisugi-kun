import { jstDayKey, jstWeekKey } from './day.js'
import { hasKv, kv } from './kv.js'
import { MAX_MEMBERS, newInviteCode } from './team.js'

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
  lock: (mid: string, day: string) => `t:lock:${mid}:${day}`,
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
  if (found.revoked || found.expiresAt <= now) return { ok: false, reason: 'expired' }

  const team = await readTeam(found.teamId)
  if (!team) return { ok: false, reason: 'unknown_code' }

  const [mineRaw, coolRaw, sizeRaw, isMemberRaw] = await kv([
    ['GET', keys.mine(mid)],
    ['GET', keys.cooldown(mid)],
    ['SCARD', keys.members(team.id)],
    ['SISMEMBER', keys.members(team.id), mid],
  ])
  const mine = mineRaw == null ? undefined : String(mineRaw)
  const already = Number(isMemberRaw ?? 0) === 1

  if (already) {
    return { ok: true, team, memberCount: Number(sizeRaw ?? 0), alreadyIn: true }
  }

  // **抜けた直後は、同じチームにも入り直せない。**
  //
  // 退出は合計を減らさず個人の記録だけ消す。つまり入り直して同じ日を
  // 送り直すと、合計に二重で乗る。これは移籍だけの話ではなく
  // **同じチームへの出入りでも成立する**（設計時に見落としていた）。
  //
  // 誤って抜けた生徒は1週間戻れないが、
  // 退出は確認を挟む操作なので、青天井の水増しより受け入れる。
  // 被害は週あたり最大 3点×14日 に有界になる。
  if (coolRaw != null && Number(coolRaw) > now) {
    return { ok: false, reason: 'cooldown' }
  }
  if (mine && mine !== team.id) return { ok: false, reason: 'in_other_team' }
  if (Number(sizeRaw ?? 0) >= MAX_MEMBERS) return { ok: false, reason: 'team_full' }

  await kv([
    ['SADD', keys.members(team.id), mid],
    ['EXPIRE', keys.members(team.id), String(400 * 86400)],
    ['SET', keys.mine(mid), team.id],
    ['EXPIRE', keys.mine(mid), String(400 * 86400)],
  ])
  return { ok: true, team, memberCount: Number(sizeRaw ?? 0) + 1, alreadyIn: false }
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
  const [wasMember] = await kv([['SISMEMBER', keys.members(teamId), mid]])
  if (Number(wasMember ?? 0) !== 1) return false

  await kv([
    ['SREM', keys.members(teamId), mid],
    // **個人の記録だけ消す。** sum は触らない
    ['DEL', keys.memberDays(teamId, mid)],
    ['DEL', keys.mine(mid)],
    // 抜けて入り直すと同じ日を送り直せるので、変更に間隔を空けさせる
    ['SET', keys.cooldown(mid), String(now + CHANGE_COOLDOWN_SECONDS * 1000)],
    ['EXPIRE', keys.cooldown(mid), String(CHANGE_COOLDOWN_SECONDS)],
  ])
  return true
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
