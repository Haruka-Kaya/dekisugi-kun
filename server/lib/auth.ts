import { createHmac, randomBytes, timingSafeEqual } from 'node:crypto'

/**
 * 端末ごとの署名付きトークン。
 *
 * ## 何を守り、何を守らないか
 *
 * **守る**: 端末を1つずつ識別して、濫用した端末だけを止められるようにする。
 * 期限があるので、漏れても永久には使えない。
 *
 * **守らない**: 誰でも `/api/register` を叩けばトークンを取れる。
 * これは「本人であること」の証明ではなく、**「同じ端末であること」の証明**。
 * アカウントを作る段階になったら、ここにユーザーIDを載せて本物の認証にする。
 *
 * それでも段階5 前の共有トークンよりは実質的に強い。
 * 共有トークンは APK から1本抜けば全員が通れ、しかも**止める手段が無かった**。
 *
 * ## なぜ JWT ライブラリを使わないか
 *
 * 要るのは HMAC-SHA256 の署名付き文字列だけで、アルゴリズム選択も
 * 公開鍵も要らない。`alg: none` のような事故を持ち込まないために、
 * 自前の最小形式にする（alg フィールドが存在しない ＝ 選ばせない）。
 */

export type DeviceToken = {
  /** 端末ID（端末が生成した UUID） */
  did: string
  /** 発行時刻（epoch 秒） */
  iat: number
  /** 失効時刻（epoch 秒） */
  exp: number
}

export const TOKEN_TTL_SECONDS = 30 * 24 * 60 * 60 // 30日

function secret(): Buffer {
  const s = process.env.AUTH_SECRET
  if (!s || s.length < 32) {
    throw new Error('AUTH_SECRET が未設定か短すぎる（32文字以上）')
  }
  return Buffer.from(s, 'utf8')
}

function b64url(buf: Buffer): string {
  return buf.toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

function unb64url(s: string): Buffer {
  return Buffer.from(s.replace(/-/g, '+').replace(/_/g, '/'), 'base64')
}

function sign(payload: string): string {
  return b64url(createHmac('sha256', secret()).update(payload).digest())
}

export function issueToken(deviceId: string, now = Date.now()): string {
  const iat = Math.floor(now / 1000)
  const claims: DeviceToken = { did: deviceId, iat, exp: iat + TOKEN_TTL_SECONDS }
  const payload = b64url(Buffer.from(JSON.stringify(claims), 'utf8'))
  return `${payload}.${sign(payload)}`
}

export type VerifyResult =
  | { ok: true; token: DeviceToken }
  | { ok: false; reason: 'malformed' | 'bad_signature' | 'expired' }

export function verifyToken(raw: string | undefined, now = Date.now()): VerifyResult {
  if (!raw) return { ok: false, reason: 'malformed' }
  const dot = raw.indexOf('.')
  if (dot <= 0 || dot === raw.length - 1) return { ok: false, reason: 'malformed' }

  const payload = raw.slice(0, dot)
  const got = Buffer.from(raw.slice(dot + 1), 'utf8')
  const want = Buffer.from(sign(payload), 'utf8')

  // 長さが違うと timingSafeEqual が例外を投げる。先に弾く
  if (got.length !== want.length) return { ok: false, reason: 'bad_signature' }
  if (!timingSafeEqual(got, want)) return { ok: false, reason: 'bad_signature' }

  let claims: DeviceToken
  try {
    claims = JSON.parse(unb64url(payload).toString('utf8')) as DeviceToken
  } catch {
    return { ok: false, reason: 'malformed' }
  }
  if (typeof claims?.did !== 'string' || !claims.did || typeof claims.exp !== 'number') {
    return { ok: false, reason: 'malformed' }
  }
  // **署名を確かめてから期限を見る。** 逆にすると、署名の無い文字列で
  // 「期限切れ」と「署名不正」を撃ち分けられ、内部の状態が漏れる
  if (claims.exp * 1000 <= now) return { ok: false, reason: 'expired' }

  return { ok: true, token: claims }
}

/** 端末IDの形式。端末が作った UUID しか受けない。 */
export function isValidDeviceId(id: unknown): id is string {
  return (
    typeof id === 'string' &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)
  )
}

/** 開発用。`AUTH_SECRET` を作るときに使う。 */
export function generateSecret(): string {
  return randomBytes(32).toString('base64url')
}
