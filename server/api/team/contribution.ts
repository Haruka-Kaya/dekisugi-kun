import { verifyToken } from '../../lib/auth.js'
import { jstDayKey } from '../../lib/day.js'
import { bearer, parseBody, type Req, type Res } from '../../lib/http.js'
import { hasKv } from '../../lib/kv.js'
import {
  MAX_DAYS_PER_REQUEST,
  judgeDay,
  memberId,
  type ContributionInput,
} from '../../lib/team.js'
import { tooManyContributions } from '../../lib/team-limit.js'
import { contribute, myTeamId, readTeam } from '../../lib/team-store.js'

/**
 * その日の貢献を送る。
 *
 * 端末はオフラインぶんを溜めてまとめて送ってくる。
 * **同じ日を何度送っても総和は動かない**（差分だけ足す）ので、
 * 端末側は「送れたか分からない」ときに素直に再送してよい。
 *
 * > [!warning] `sessions` は合計に入れない
 * > Duolingo は Total Sessions の欠陥を認め、品質で重み付けた
 * > TSLW へ指標を移している。回数は開閉するだけで増え、
 * > 学びと無関係に積み上がる。**受け取るが、合計には足さない。**
 */
export default async function handler(req: Req, res: Res) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST')
    res.status(405).json({ error: 'method_not_allowed' })
    return
  }

  const auth = verifyToken(bearer(req))
  if (!auth.ok) {
    res.status(401).json({ error: auth.reason === 'expired' ? 'token_expired' : 'unauthorized' })
    return
  }
  if (!hasKv()) {
    res.status(503).json({ error: 'no_store' })
    return
  }

  const body = parseBody(req.body) as { days?: unknown } | undefined
  const raw = Array.isArray(body?.days) ? body.days : []
  if (raw.length === 0) {
    res.status(400).json({ error: 'no_days' })
    return
  }
  if (raw.length > MAX_DAYS_PER_REQUEST) {
    res.status(413).json({ error: 'too_many_days' })
    return
  }

  const mid = memberId(auth.token.did)
  if (await tooManyContributions(mid)) {
    res.status(429).json({ error: 'rate_limited' })
    return
  }

  try {
    const teamId = await myTeamId(mid)
    if (!teamId) {
      res.status(404).json({ error: 'not_in_team' })
      return
    }
    const team = await readTeam(teamId)
    if (!team) {
      res.status(404).json({ error: 'not_in_team' })
      return
    }

    const today = jstDayKey(Date.now())
    const ok: { day: string; value: number }[] = []
    const rejected: { day: string; reason: string }[] = []

    for (const item of raw as ContributionInput[]) {
      const v = judgeDay(item, today, team.periodStart)
      // **1日だめでも他を落とさない。** オフラインで溜めたぶんが全滅する
      if (v.ok) ok.push({ day: v.day, value: v.value })
      else rejected.push({ day: v.day, reason: v.reason })
    }

    const done = await contribute(mid, team, ok)
    res.status(200).json({
      applied: done.applied.map((a) => a.day),
      rejected: [...rejected, ...done.rejected],
    })
  } catch (e) {
    console.error('貢献を記録できなかった', e)
    res.status(503).json({ error: 'store_failed' })
  }
}
