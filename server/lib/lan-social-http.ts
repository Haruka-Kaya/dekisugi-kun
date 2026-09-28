import { type IncomingMessage, type ServerResponse } from 'node:http'
import { createServer, type Server, type ServerOptions } from 'node:https'
import { isIP } from 'node:net'

import {
  LAN_SOCIAL_CONSENT_VERSION,
  LanSocialCoordinator,
  LanSocialError,
  type LanSocialRoomKind,
} from './lan-social.js'

export type LanSocialRateLimitRequest = {
  bucket: 'all' | 'create' | 'join' | 'contribution' | 'settlement'
  identity: string
  limit: number
  windowMs: number
  now: number
}

export interface LanSocialRateLimiter {
  /** trueなら許可。保存/時計/内部状態を判断できない場合はthrowし、HTTP側が503へ倒す。 */
  take(request: LanSocialRateLimitRequest): boolean | Promise<boolean>
}

type RateEntry = { count: number; resetAt: number }

/** coordinatorプロセス内だけで使う、外部保存を伴わないrate limiter。 */
export class MemoryLanSocialRateLimiter implements LanSocialRateLimiter {
  private readonly entries = new Map<string, RateEntry>()

  take(request: LanSocialRateLimitRequest): boolean {
    if (!Number.isFinite(request.now) || request.now <= 0 ||
      !Number.isInteger(request.limit) || request.limit <= 0 ||
      !Number.isInteger(request.windowMs) || request.windowMs <= 0 ||
      !request.identity) {
      throw new Error('invalid rate limit request')
    }
    const key = `${request.bucket}:${request.identity}`
    const existing = this.entries.get(key)
    const entry = !existing || existing.resetAt <= request.now
      ? { count: 0, resetAt: request.now + request.windowMs }
      : existing
    entry.count += 1
    this.entries.set(key, entry)
    if (this.entries.size > 4_096) {
      for (const [candidate, value] of this.entries) {
        if (value.resetAt <= request.now) this.entries.delete(candidate)
      }
      if (this.entries.size > 4_096) {
        // メモリ圧迫時に古い利用者を通すのではなく、全体を閉じる。
        throw new Error('rate limiter capacity exceeded')
      }
    }
    return entry.count <= request.limit
  }
}

export type LanSocialHttpOptions = {
  coordinator: LanSocialCoordinator
  tls: Pick<ServerOptions, 'key' | 'cert'>
  rateLimiter?: LanSocialRateLimiter
  now?: () => number
}

/**
 * LAN限定REST API。
 *
 * `api/` 配下へ置かないためVercelへFunctionとして公開されない。forwarded header、
 * public address、browser Originを拒否し、LAN外のreverse proxyで動かそうとすると閉じる。
 */
export function createLanSocialHttpServer(options: LanSocialHttpOptions): Server {
  const limiter = options.rateLimiter ?? new MemoryLanSocialRateLimiter()
  const now = options.now ?? Date.now
  return createServer(options.tls, async (req, res) => {
    secureHeaders(res)
    try {
      assertLanRequest(req)
      const at = now()
      const remote = normalizeAddress(req.socket.remoteAddress ?? '')
      await requireRate(limiter, {
        bucket: 'all',
        identity: options.coordinator.rateIdentity(remote),
        limit: 120,
        windowMs: 60_000,
        now: at,
      })
      const url = new URL(req.url ?? '/', 'http://lan.invalid')
      if (url.search) throw new HttpError(400, 'query_not_allowed')

      if (req.method === 'GET' && url.pathname === '/v1/lan-social/health') {
        json(res, 200, {
          ok: true,
          protocolVersion: 1,
          storage: 'coordinator_local_only',
        })
        return
      }

      if (req.method === 'POST' && url.pathname === '/v1/lan-social/rooms') {
        if (!options.coordinator.coordinatorKeyMatches(req.headers['x-dekisugi-coordinator-key'])) {
          throw new HttpError(401, 'unauthorized')
        }
        await requireRate(limiter, {
          bucket: 'create',
          identity: options.coordinator.rateIdentity('coordinator'),
          limit: 20,
          windowMs: 86_400_000,
          now: at,
        })
        const body = await readExactJson(req, [
          'kind', 'capacity', 'createKey', 'optIn', 'consentVersion',
        ])
        if (body.optIn !== true || body.consentVersion !== LAN_SOCIAL_CONSENT_VERSION ||
          (body.kind !== 'friends' && body.kind !== 'league') ||
          !Number.isInteger(body.capacity) || typeof body.createKey !== 'string') {
          throw new HttpError(400, 'bad_request')
        }
        const room = await options.coordinator.createRoom({
          kind: body.kind as LanSocialRoomKind,
          capacity: body.capacity as number,
          createKey: body.createKey,
          now: at,
        })
        json(res, 201, room)
        return
      }

      if (req.method === 'POST' && url.pathname === '/v1/lan-social/join') {
        await requireRate(limiter, {
          bucket: 'join',
          identity: options.coordinator.rateIdentity(remote),
          limit: 8,
          windowMs: 15 * 60_000,
          now: at,
        })
        const body = await readExactJson(req, [
          'inviteCode', 'joinKey', 'optIn', 'consentVersion',
        ])
        if (body.optIn !== true || body.consentVersion !== LAN_SOCIAL_CONSENT_VERSION ||
          typeof body.inviteCode !== 'string' || typeof body.joinKey !== 'string') {
          throw new HttpError(400, 'bad_request')
        }
        const membership = await options.coordinator.join({
          inviteCode: body.inviteCode,
          joinKey: body.joinKey,
          now: at,
        })
        json(res, 200, membership)
        return
      }

      if (req.method === 'GET' && url.pathname === '/v1/lan-social/snapshot') {
        const credential = bearer(req)
        json(res, 200, options.coordinator.snapshot(credential, at))
        return
      }

      if (req.method === 'GET' && url.pathname === '/v1/lan-social/settlement') {
        assertNoBody(req)
        const credential = bearer(req)
        await requireRate(limiter, {
          bucket: 'settlement',
          identity: options.coordinator.rateIdentity(credential),
          limit: 20,
          windowMs: 3_600_000,
          now: at,
        })
        json(res, 200, await options.coordinator.settlement(credential, at))
        return
      }

      if (req.method === 'POST' && url.pathname === '/v1/lan-social/contribution') {
        const credential = bearer(req)
        // 認証できない値でbucketを無限に作れないよう、header全体もHMACで短縮する。
        await requireRate(limiter, {
          bucket: 'contribution',
          identity: options.coordinator.rateIdentity(credential),
          limit: 20,
          windowMs: 3_600_000,
          now: at,
        })
        const body = await readExactJson(req, ['idempotencyKey', 'learningDay'])
        if (typeof body.idempotencyKey !== 'string' || typeof body.learningDay !== 'string') {
          throw new HttpError(400, 'bad_request')
        }
        const result = await options.coordinator.contribute({
          credential,
          idempotencyKey: body.idempotencyKey,
          learningDay: body.learningDay,
          now: at,
        })
        json(res, 200, result)
        return
      }

      if (req.method === 'POST' && url.pathname === '/v1/lan-social/leave') {
        assertNoBody(req)
        await options.coordinator.leave(bearer(req), at)
        res.statusCode = 204
        res.end()
        return
      }

      throw new HttpError(404, 'not_found')
    } catch (error) {
      respondError(res, error)
    }
  })
}

class HttpError extends Error {
  constructor(readonly status: number, readonly code: string) {
    super(code)
  }
}

async function requireRate(
  limiter: LanSocialRateLimiter,
  request: LanSocialRateLimitRequest,
): Promise<void> {
  let allowed: boolean
  try {
    allowed = await limiter.take(request)
  } catch {
    throw new HttpError(503, 'rate_limit_unavailable')
  }
  if (!allowed) throw new HttpError(429, 'rate_limited')
}

function bearer(req: IncomingMessage): string {
  const header = req.headers.authorization
  if (!header?.startsWith('Bearer ') || header.length > 256) {
    throw new HttpError(401, 'unauthorized')
  }
  return header.slice('Bearer '.length)
}

function assertLanRequest(req: IncomingMessage): void {
  if (!('encrypted' in req.socket) || req.socket.encrypted !== true) {
    throw new HttpError(426, 'tls_required')
  }
  if (req.headers.origin !== undefined) throw new HttpError(403, 'browser_not_allowed')
  for (const header of ['forwarded', 'x-forwarded-for', 'x-real-ip']) {
    if (req.headers[header] !== undefined) throw new HttpError(403, 'proxy_not_allowed')
  }
  const remote = normalizeAddress(req.socket.remoteAddress ?? '')
  if (!isPrivateAddress(remote)) throw new HttpError(403, 'lan_only')
  const hostHeader = req.headers.host
  if (!hostHeader || hostHeader.length > 128) throw new HttpError(400, 'bad_host')
  let host: string
  try {
    host = new URL(`http://${hostHeader}`).hostname.replace(/^\[|\]$/g, '')
  } catch {
    throw new HttpError(400, 'bad_host')
  }
  if (!isPrivateAddress(normalizeAddress(host)) && host !== 'localhost') {
    throw new HttpError(403, 'lan_only')
  }
}

export function isPrivateLanAddress(value: string): boolean {
  return isPrivateAddress(normalizeAddress(value))
}

function normalizeAddress(value: string): string {
  const percent = value.indexOf('%')
  const withoutZone = percent >= 0 ? value.slice(0, percent) : value
  return withoutZone.startsWith('::ffff:') ? withoutZone.slice(7) : withoutZone
}

function isPrivateAddress(value: string): boolean {
  if (value === '::1' || value === '127.0.0.1') return true
  if (/^10\.(?:\d{1,3}\.){2}\d{1,3}$/.test(value)) return validIpv4(value)
  if (/^192\.168\.(?:\d{1,3})\.(?:\d{1,3})$/.test(value)) return validIpv4(value)
  if (/^169\.254\.(?:\d{1,3})\.(?:\d{1,3})$/.test(value)) return validIpv4(value)
  const match172 = /^172\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.exec(value)
  if (match172 && Number(match172[1]) >= 16 && Number(match172[1]) <= 31) {
    return validIpv4(value)
  }
  if (isIP(value) !== 6) return false
  const lower = value.toLowerCase()
  const firstHextet = Number.parseInt(lower.split(':', 1)[0] ?? '', 16)
  return (firstHextet & 0xfe00) === 0xfc00 ||
    (firstHextet & 0xffc0) === 0xfe80
}

function validIpv4(value: string): boolean {
  const parts = value.split('.').map(Number)
  return parts.length === 4 && parts.every((part) => Number.isInteger(part) && part >= 0 && part <= 255)
}

async function readExactJson(
  req: IncomingMessage,
  expectedKeys: readonly string[],
): Promise<Record<string, unknown>> {
  const contentType = req.headers['content-type'] ?? ''
  if (!contentType.toLowerCase().startsWith('application/json')) {
    throw new HttpError(415, 'json_required')
  }
  const chunks: Buffer[] = []
  let length = 0
  for await (const chunk of req) {
    const value = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk)
    length += value.length
    if (length > 2_048) throw new HttpError(413, 'body_too_large')
    chunks.push(value)
  }
  let parsed: unknown
  try {
    parsed = JSON.parse(Buffer.concat(chunks).toString('utf8'))
  } catch {
    throw new HttpError(400, 'invalid_json')
  }
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new HttpError(400, 'bad_request')
  }
  const actual = Object.keys(parsed as Record<string, unknown>).sort()
  const expected = [...expectedKeys].sort()
  if (actual.length !== expected.length ||
    actual.some((key, index) => key !== expected[index])) {
    // 未知欄を無視しない。回答・氏名を既存ID欄の隣へ足して送る抜け道を閉じる。
    throw new HttpError(400, 'unexpected_fields')
  }
  return parsed as Record<string, unknown>
}

function assertNoBody(req: IncomingMessage): void {
  const length = Number(req.headers['content-length'] ?? 0)
  if (!Number.isFinite(length) || length !== 0 || req.headers['transfer-encoding']) {
    throw new HttpError(400, 'body_not_allowed')
  }
}

function secureHeaders(res: ServerResponse): void {
  res.setHeader('Cache-Control', 'no-store')
  res.setHeader('Content-Type', 'application/json; charset=utf-8')
  res.setHeader('X-Content-Type-Options', 'nosniff')
  res.setHeader('Referrer-Policy', 'no-referrer')
}

function json(res: ServerResponse, status: number, value: unknown): void {
  res.statusCode = status
  res.end(JSON.stringify(value))
}

function respondError(res: ServerResponse, error: unknown): void {
  if (res.writableEnded) return
  if (error instanceof HttpError) {
    json(res, error.status, { error: error.code })
    return
  }
  if (error instanceof LanSocialError) {
    const status = {
      bad_request: 400,
      unauthorized: 401,
      unknown_room: 404,
      expired: 410,
      room_full: 409,
      join_revoked: 410,
      wrong_day: 409,
      daily_limit: 429,
      not_settled: 409,
    }[error.code]
    json(res, status, { error: error.code })
    return
  }
  // state保存失敗を成功扱いしない。内部情報やbodyはログ/応答へ出さない。
  json(res, 503, { error: 'coordinator_unavailable' })
}
