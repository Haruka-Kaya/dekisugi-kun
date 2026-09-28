import { verifyToken } from '../../lib/auth.js'
import { bearer, callerIp, parseBody, type Req, type Res } from '../../lib/http.js'
import { hasKv } from '../../lib/kv.js'
import { memberId, normalizeCode, roundMembers } from '../../lib/team.js'
import { joinTeam } from '../../lib/team-store.js'
import { tooManyJoinAttempts } from '../../lib/team-limit.js'
import { schoolTestingEnabled } from '../../lib/school-access.js'

/**
 * 招待コードでチームに入る。
 *
 * 端末トークンだけで足りる。**アカウントも氏名も要らない。**
 * 誰であるかではなく「同じチームか」しか要らないので、
 * 個人を識別する要素を1つも増やさずに済む。
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

  const body = parseBody(req.body) as { inviteCode?: unknown } | undefined
  const code = normalizeCode(body?.inviteCode)
  if (!code) {
    res.status(400).json({ error: 'bad_code' })
    return
  }

  // **総当たりを止める。** 30^8 でも、無制限に試せるなら時間の問題
  const mid = memberId(auth.token.did)
  if (await tooManyJoinAttempts(mid, callerIp(req))) {
    res.status(429).json({ error: 'too_many_attempts' })
    return
  }

  try {
    const r = await joinTeam(mid, code)
    if (!r.ok) {
      const status = {
        unknown_code: 404,
        // 期限切れと失効は同じ扱い。生徒がやることは「先生にもう一度もらう」で同じ
        expired: 410,
        team_full: 409,
        in_other_team: 409,
        cooldown: 429,
      }[r.reason]
      res.status(status).json({ error: r.reason })
      return
    }
    res.status(200).json({
      teamId: r.team.id,
      teamName: r.team.name,
      // **実人数を返さない。** 1人の増減が見えると「誰かが抜けた」が伝わる
      memberCount: roundMembers(r.memberCount),
      periodStart: r.team.periodStart,
      periodEnd: r.team.periodEnd,
    })
  } catch (e) {
    console.error('チームに入れなかった', e)
    res.status(503).json({ error: 'store_failed' })
  }
}
