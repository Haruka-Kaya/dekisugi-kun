import { hasKv, kv } from './kv.js'

/**
 * チーム経路の連投制限。
 *
 * **`ratelimit.ts` の枠を使わない。** あれは Gemini の請求を止める砦で、
 * チームの POST がそこを消費すると、会話を始める枠を食ってしまう。
 * 目的が違うものは別の名前空間で数える。
 */

/** 招待コードの総当たり。IP は1時間あたり、端末は1日あたり。 */
export const JOIN_PER_IP_HOURLY = 20
export const JOIN_PER_MEMBER_DAILY = 10

/** 貢献の送信。オフラインぶんをまとめて送る余地は残す。 */
export const CONTRIBUTION_PER_MEMBER_HOURLY = 60

async function over(key: string, limit: number, ttlSeconds: number): Promise<boolean> {
  try {
    const [n] = await kv([
      ['INCR', key],
      ['EXPIRE', key, String(ttlSeconds), 'NX'],
    ])
    return Number(n ?? 0) > limit
  } catch (e) {
    // **読めないときは通す。** 締めると障害がそのまま全滅になる。
    // ここで止めても守れるのは総当たりだけで、費用は別の砦が見ている
    console.error('チームの連投制限を読めなかった（通す）', e)
    return false
  }
}

/** 招待コードを試しすぎていないか。 */
export async function tooManyJoinAttempts(mid: string, ip: string): Promise<boolean> {
  if (!hasKv()) return false
  const hour = Math.floor(Date.now() / 3600_000)
  const day = Math.floor(Date.now() / 86400_000)
  const byIp = ip ? await over(`t:jrl:${ip}:${hour}`, JOIN_PER_IP_HOURLY, 3600) : false
  const byMember = await over(`t:mrl:${mid}:${day}`, JOIN_PER_MEMBER_DAILY, 86400)
  return byIp || byMember
}

/** 貢献を送りすぎていないか。 */
export async function tooManyContributions(mid: string): Promise<boolean> {
  if (!hasKv()) return false
  const hour = Math.floor(Date.now() / 3600_000)
  return over(`t:crl:${mid}:${hour}`, CONTRIBUTION_PER_MEMBER_HOURLY, 3600)
}
