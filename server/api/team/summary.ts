import { verifyToken } from '../../lib/auth.js'
import { bearer, type Req, type Res } from '../../lib/http.js'
import { hasKv } from '../../lib/kv.js'
import { buildSummary, memberId } from '../../lib/team.js'
import {
  memberCount,
  myTeamId,
  myTotalIn,
  readTeam,
  teamTotal,
} from '../../lib/team-store.js'

/**
 * チームの合計。**ここが唯一の出口。**
 *
 * 個人を可視化しない制約は `buildSummary` が返さないことで担保している。
 * このハンドラが持っている情報（メンバーの集合、日ごとの寄与）は
 * **通さない**ので、端末がどう作られていても晒しようがない。
 *
 * > [!warning] 5人未満では合計を出さない
 * > 2人のチームでは `teamTotal - myTotal` が相手1人の値そのものになる。
 * > 丸めでは防げない情報理論的な漏れなので、出さない以外の対処が無い。
 *
 * 返さないもの: 名簿、個人別の内訳、日別の推移、最終アクティブ日時、
 * 「まだやっていない人数」。
 */
export default async function handler(req: Req, res: Res) {
  if (req.method !== 'GET') {
    res.setHeader('Allow', 'GET')
    res.status(405).json({ error: 'method_not_allowed' })
    return
  }

  const auth = verifyToken(bearer(req))
  if (!auth.ok) {
    res.status(401).json({ error: auth.reason === 'expired' ? 'token_expired' : 'unauthorized' })
    return
  }
  if (!hasKv()) {
    // **0 を返さない。** 「誰もやっていない」に見えるのは、
    // 出さないことより悪い
    res.status(503).json({ error: 'no_store' })
    return
  }

  const mid = memberId(auth.token.did)
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

    const [count, total, mine] = await Promise.all([
      memberCount(teamId),
      teamTotal(team),
      myTotalIn(mid, team),
    ])

    res.status(200).json(
      buildSummary({
        teamName: team.name,
        memberCount: count,
        teamTotal: total,
        myTotal: mine,
        periodStart: team.periodStart,
        periodEnd: team.periodEnd,
      }),
    )
  } catch (e) {
    console.error('チームの合計を出せなかった', e)
    res.status(503).json({ error: 'store_failed' })
  }
}
