import { bearer, parseBody, queryOf, type Req, type Res } from '../../lib/http.js'
import { hasKv } from '../../lib/kv.js'
import { formatCode, normalizeCode, normalizeTeamName } from '../../lib/team.js'
import { CODE_TTL_DAYS, createTeam, revokeCode } from '../../lib/team-store.js'

/**
 * チームの器と招待コードを作る。**開発者だけが叩く。**
 *
 * ## なぜ先生に自作させないか
 *
 * 先生が文字列を決めると、学校名やクラス名がコードに入る（`sakura-2026` のように）。
 * コードは端末からサーバへ流れるので、それは**新しい識別要素**になり、
 * 保護者向けの同意文面に波及する。
 *
 * 加えて、誰でもチームを作れると Redis のキーが無限に増え、掃除する主体がいない。
 *
 * 開発者が配布資料を先生に手渡す運用が既にあるので、
 * 発行を1往復増やしても運用は壊れない。
 *
 * > [!warning] 「あいことば」とは別物
 * > `docs/school-pack/README.md` は
 * > 「あいことばはサーバーには送っていません」と明記して配ってある。
 * > あれを招待コードに転用すると、配布済みの説明が嘘になる。
 * > **あいことばは端末内の経路分岐のまま据え置く。**
 *
 * POST   … チームを作って招待コードを返す
 * DELETE … 招待コードを失効させる
 */

/** 未設定なら経路ごと閉じる。**素通しにしない。** */
function adminOk(req: Req): boolean {
  const want = process.env.TEAM_ADMIN_TOKEN
  // 設定を忘れた瞬間に誰でもチームを量産できる、という形にしない
  if (!want) return false
  return bearer(req) === want
}

export default async function handler(req: Req, res: Res) {
  if (req.method !== 'POST' && req.method !== 'DELETE') {
    res.setHeader('Allow', 'POST, DELETE')
    res.status(405).json({ error: 'method_not_allowed' })
    return
  }
  if (!adminOk(req)) {
    res.status(401).json({ error: 'unauthorized' })
    return
  }
  if (!hasKv()) {
    // **200 を返さない。** 保存できていないのに成功に見えるのが最悪
    res.status(503).json({ error: 'no_store' })
    return
  }

  if (req.method === 'DELETE') {
    const code = normalizeCode(queryOf(req, 'code'))
    if (!code) {
      res.status(400).json({ error: 'bad_code' })
      return
    }
    try {
      const done = await revokeCode(code)
      res.status(done ? 200 : 404).json(done ? { revoked: true } : { error: 'unknown_code' })
    } catch (e) {
      console.error('招待コードの失効に失敗', e)
      res.status(503).json({ error: 'store_failed' })
    }
    return
  }

  const body = parseBody(req.body) as { name?: unknown; ttlDays?: unknown } | undefined
  const name = normalizeTeamName(body?.name)
  if (!name) {
    res.status(400).json({ error: 'bad_name' })
    return
  }
  const rawTtl = Number(body?.ttlDays)
  const ttlDays =
    Number.isFinite(rawTtl) && rawTtl > 0 && rawTtl <= 400 ? Math.floor(rawTtl) : CODE_TTL_DAYS

  try {
    const { team, code } = await createTeam(name, { ttlDays })
    res.status(200).json({
      teamId: team.id,
      teamName: team.name,
      // 配る用の見た目。生徒はこれを打つ
      inviteCode: formatCode(code.code),
      expiresAt: new Date(code.expiresAt).toISOString(),
      periodStart: team.periodStart,
      periodEnd: team.periodEnd,
    })
  } catch (e) {
    console.error('チームを作れなかった', e)
    res.status(503).json({ error: 'store_failed' })
  }
}
