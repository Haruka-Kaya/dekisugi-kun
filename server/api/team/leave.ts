import { verifyToken } from '../../lib/auth.js'
import { bearer, parseBody, type Req, type Res } from '../../lib/http.js'
import { hasKv } from '../../lib/kv.js'
import { memberId } from '../../lib/team.js'
import { leaveTeam, myTeamId } from '../../lib/team-store.js'
import { schoolTestingEnabled } from '../../lib/school-access.js'

/**
 * チームを抜ける。
 *
 * > [!important] 合計を減らさない
 * > 減らすと、クラスの合計が突然落ちて**「誰かが抜けた」が全員に見える**。
 * > 誰かは分からなくても、抜けた事実の可視化そのものが離脱の引き金になる。
 *
 * 消すのは**個人に紐づく記録だけ**（日ごとの寄与）。
 * 残る合計はもう誰にも帰属しない集計値になる。
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
  if (!schoolTestingEnabled()) {
    res.status(503).json({ error: 'school_features_unavailable' })
    return
  }
  if (!hasKv()) {
    res.status(503).json({ error: 'no_store' })
    return
  }

  const mid = memberId(auth.token.did)
  const body = parseBody(req.body) as { teamId?: unknown } | undefined

  try {
    // teamId は端末が覚えていなくてもよい。**サーバが知っている**
    const current = await myTeamId(mid)
    const teamId = typeof body?.teamId === 'string' && body.teamId ? body.teamId : current
    if (!teamId) {
      res.status(404).json({ error: 'not_in_team' })
      return
    }
    const done = await leaveTeam(mid, teamId)
    if (!done) {
      res.status(404).json({ error: 'not_in_team' })
      return
    }
    res.status(200).json({ left: true })
  } catch (e) {
    console.error('チームを抜けられなかった', e)
    res.status(503).json({ error: 'store_failed' })
  }
}
