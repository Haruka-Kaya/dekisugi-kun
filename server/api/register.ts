import { type Req, type Res } from '../lib/http.js'
import { isValidDeviceId, issueToken, TOKEN_TTL_SECONDS } from '../lib/auth.js'

/**
 * 端末の登録。署名付きトークンを発行する。
 *
 * **これは本人確認ではない。** 誰でも叩けば取れる。
 * 目的は「同じ端末であること」を識別して、濫用した端末だけを止められるようにすること。
 *
 * アカウントを作る段階になったら、ここにユーザーIDを載せて本物の認証にする。
 */


export default function handler(req: Req, res: Res) {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST')
    res.status(405).json({ error: 'method_not_allowed' })
    return
  }

  let body = req.body
  if (typeof body === 'string') {
    try {
      body = JSON.parse(body)
    } catch {
      res.status(400).json({ error: 'invalid_json' })
      return
    }
  }

  const deviceId = (body as { deviceId?: unknown } | null)?.deviceId
  if (!isValidDeviceId(deviceId)) {
    res.status(400).json({ error: 'invalid_device_id' })
    return
  }

  try {
    res.status(200).json({
      token: issueToken(deviceId),
      expiresIn: TOKEN_TTL_SECONDS,
    })
  } catch (e) {
    // AUTH_SECRET 未設定。中身は返さない
    console.error('トークン発行に失敗', e)
    res.status(503).json({ error: 'not_configured' })
  }
}
