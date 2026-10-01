import assert from 'node:assert/strict'
import { mkdtemp, rm } from 'node:fs/promises'
import { request as httpsRequest } from 'node:https'
import type { AddressInfo } from 'node:net'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { afterEach, describe, it } from 'node:test'

import {
  createLanSocialHttpServer,
  isPrivateLanAddress,
  type LanSocialRateLimiter,
} from '../lib/lan-social-http.js'
import {
  LAN_SOCIAL_CONSENT_VERSION,
  LanSocialCoordinator,
  LanSocialFileStore,
} from '../lib/lan-social.js'
import { openLanSocialTlsIdentity } from '../lib/lan-social-tls.js'

const NOW = Date.parse('2026-08-10T12:00:00+09:00')
const temporaryDirectories: string[] = []
const servers: ReturnType<typeof createLanSocialHttpServer>[] = []

type TestResponse = {
  status: number
  headers: { get(name: string): string | null }
  json(): Promise<unknown>
}

/// test coordinatorの自己署名証明書だけを、このNode test process内で受ける。
/// Flutter側のproduction clientはfingerprint完全一致でなければ受けない。
async function fetch(
  input: string,
  init: {
    method?: string
    headers?: Record<string, string>
    body?: string
  } = {},
): Promise<TestResponse> {
  const url = new URL(input)
  return new Promise<TestResponse>((resolve, reject) => {
    const request = httpsRequest({
      hostname: url.hostname,
      port: url.port,
      path: `${url.pathname}${url.search}`,
      method: init.method ?? 'GET',
      headers: init.headers,
      rejectUnauthorized: false,
    }, (response) => {
      const chunks: Buffer[] = []
      response.on('data', (chunk: Buffer) => chunks.push(chunk))
      response.once('error', reject)
      response.once('end', () => {
        const body = Buffer.concat(chunks).toString('utf8')
        resolve({
          status: response.statusCode ?? 0,
          headers: {
            get(name: string) {
              const value = response.headers[name.toLowerCase()]
              return Array.isArray(value) ? value.join(', ') : value ?? null
            },
          },
          async json() { return JSON.parse(body) as unknown },
        })
      })
    })
    request.once('error', reject)
    request.end(init.body)
  })
}

afterEach(async () => {
  await Promise.all(servers.splice(0).map((server) => new Promise<void>((resolve) => {
    server.close(() => resolve())
  })))
  while (temporaryDirectories.length > 0) {
    await rm(temporaryDirectories.pop()!, { recursive: true, force: true })
  }
})

async function fixture(
  rateLimiter?: LanSocialRateLimiter,
  now: () => number = () => NOW,
): Promise<{
  baseUrl: string
  coordinator: LanSocialCoordinator
  store: LanSocialFileStore
}> {
  const directory = await mkdtemp(join(tmpdir(), 'dekisugi-lan-http-'))
  temporaryDirectories.push(directory)
  const store = await LanSocialFileStore.open(join(directory, 'state.json'))
  const coordinator = new LanSocialCoordinator(store)
  const tls = await openLanSocialTlsIdentity(directory)
  const server = createLanSocialHttpServer({ coordinator, tls, rateLimiter, now })
  servers.push(server)
  await new Promise<void>((resolve, reject) => {
    server.once('error', reject)
    server.listen(0, '127.0.0.1', resolve)
  })
  const address = server.address() as AddressInfo
  return { baseUrl: `https://127.0.0.1:${address.port}`, coordinator, store }
}

async function createRoom(
  baseUrl: string,
  coordinatorKey: string,
  kind: 'friends' | 'league' = 'league',
  capacity = kind === 'friends' ? 2 : 5,
  createKey = 'A'.repeat(32),
): Promise<Record<string, unknown>> {
  const response = await fetch(`${baseUrl}/v1/lan-social/rooms`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Dekisugi-Coordinator-Key': coordinatorKey,
    },
    body: JSON.stringify({
      kind, capacity, createKey,
      optIn: true,
      consentVersion: LAN_SOCIAL_CONSENT_VERSION,
    }),
  })
  assert.equal(response.status, 201)
  return await response.json() as Record<string, unknown>
}

async function joinRoom(
  baseUrl: string,
  inviteCode: string,
  joinKey: string,
): Promise<Record<string, unknown>> {
  const response = await fetch(`${baseUrl}/v1/lan-social/join`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      inviteCode, joinKey,
      optIn: true,
      consentVersion: LAN_SOCIAL_CONSENT_VERSION,
    }),
  })
  assert.equal(response.status, 200)
  return await response.json() as Record<string, unknown>
}

describe('LAN限定HTTP境界', () => {
  it('private/loopbackのIP literalだけを受け、似たDNS名を拒否する', () => {
    for (const value of [
      '127.0.0.1', '10.2.3.4', '172.16.0.1', '172.31.255.255',
      '192.168.4.5', '169.254.2.3', '::1', 'fd12::1', 'fc00::1', 'fe80::1',
    ]) assert.equal(isPrivateLanAddress(value), true, value)
    for (const value of [
      '8.8.8.8', '172.15.0.1', '172.32.0.1', '2001:db8::1',
      'fca.example', 'fd-school.example', 'fe80.example', 'localhost.example',
    ]) assert.equal(isPrivateLanAddress(value), false, value)
  })

  it('healthは保存先がcoordinator local onlyであることを明示する', async () => {
    const { baseUrl } = await fixture()
    const response = await fetch(`${baseUrl}/v1/lan-social/health`)
    assert.equal(response.status, 200)
    assert.deepEqual(await response.json(), {
      ok: true,
      protocolVersion: 1,
      storage: 'coordinator_local_only',
    })
    assert.equal(response.headers.get('cache-control'), 'no-store')
  })

  it('proxy headerとbrowser Originを拒否してLAN外公開へ倒れない', async () => {
    const { baseUrl } = await fixture()
    const proxied = await fetch(`${baseUrl}/v1/lan-social/health`, {
      headers: { Forwarded: 'for=203.0.113.1' },
    })
    assert.equal(proxied.status, 403)
    assert.deepEqual(await proxied.json(), { error: 'proxy_not_allowed' })
    const browser = await fetch(`${baseUrl}/v1/lan-social/health`, {
      headers: { Origin: 'https://example.test' },
    })
    assert.equal(browser.status, 403)
    assert.deepEqual(await browser.json(), { error: 'browser_not_allowed' })
  })

  it('明示opt-inが無ければ部屋を作らない', async () => {
    const { baseUrl, store } = await fixture()
    const response = await fetch(`${baseUrl}/v1/lan-social/rooms`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Dekisugi-Coordinator-Key': store.coordinatorKey,
      },
      body: JSON.stringify({
        kind: 'friends', capacity: 2, createKey: 'B'.repeat(32),
        optIn: false, consentVersion: LAN_SOCIAL_CONSENT_VERSION,
      }),
    })
    assert.equal(response.status, 400)
    assert.equal(store.snapshot().rooms.length, 0)
  })

  it('氏名・回答・音声・端末IDの追加欄を無視せず拒否する', async () => {
    const { baseUrl, store } = await fixture()
    const room = await createRoom(baseUrl, store.coordinatorKey, 'friends', 2)
    for (const [field, value] of [
      ['studentName', '山田'],
      ['answer', '自由記述'],
      ['audio', 'base64-audio'],
      ['deviceId', 'ffffffff-1111-2222-3333-444444444444'],
    ] as const) {
      const response = await fetch(`${baseUrl}/v1/lan-social/join`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          inviteCode: room.inviteCode,
          joinKey: 'C'.repeat(32),
          optIn: true,
          consentVersion: LAN_SOCIAL_CONSENT_VERSION,
          [field]: value,
        }),
      })
      assert.equal(response.status, 400, field)
      assert.deepEqual(await response.json(), { error: 'unexpected_fields' })
    }
    assert.equal(store.snapshot().rooms[0]!.participants.length, 0)
  })

  it('rate limiterが判断不能なら処理前に503で閉じる', async () => {
    const unavailable: LanSocialRateLimiter = {
      take() { throw new Error('unavailable') },
    }
    const { baseUrl, store } = await fixture(unavailable)
    const response = await fetch(`${baseUrl}/v1/lan-social/rooms`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Dekisugi-Coordinator-Key': store.coordinatorKey,
      },
      body: JSON.stringify({
        kind: 'friends', capacity: 2, createKey: 'D'.repeat(32),
        optIn: true, consentVersion: LAN_SOCIAL_CONSENT_VERSION,
      }),
    })
    assert.equal(response.status, 503)
    assert.deepEqual(await response.json(), { error: 'rate_limit_unavailable' })
    assert.equal(store.snapshot().rooms.length, 0)
  })

  it('参加コード総当たりをIPごとに8回で閉じる', async () => {
    const { baseUrl } = await fixture()
    for (let attempt = 0; attempt < 8; attempt += 1) {
      const response = await fetch(`${baseUrl}/v1/lan-social/join`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          inviteCode: '2345-6789-ABCD',
          joinKey: `${attempt}`.repeat(32),
          optIn: true,
          consentVersion: LAN_SOCIAL_CONSENT_VERSION,
        }),
      })
      // 数字だけのjoinKeyもopaqueとして有効。部屋が無いところまで進む。
      assert.equal(response.status, 404)
    }
    const blocked = await fetch(`${baseUrl}/v1/lan-social/join`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        inviteCode: '2345-6789-ABCD',
        joinKey: 'Z'.repeat(32),
        optIn: true,
        consentVersion: LAN_SOCIAL_CONSENT_VERSION,
      }),
    })
    assert.equal(blocked.status, 429)
  })
})

describe('別端末を模したHTTP縦切り', () => {
  it('5資格情報が参加し、実学習eventだけで匿名週次順位が更新される', async () => {
    const { baseUrl, store } = await fixture()
    const room = await createRoom(baseUrl, store.coordinatorKey)
    const members = []
    for (const character of ['F', 'G', 'H', 'J', 'K']) {
      members.push(await joinRoom(baseUrl, room.inviteCode as string, character.repeat(32)))
    }
    const credential = members[0]!.credential as string
    const contribution = await fetch(`${baseUrl}/v1/lan-social/contribution`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${credential}`,
      },
      body: JSON.stringify({
        idempotencyKey: 'L'.repeat(43),
        learningDay: '2026-08-10',
      }),
    })
    assert.equal(contribution.status, 200)
    const first = await contribution.json() as Record<string, unknown>
    assert.equal(first.applied, true)
    assert.equal(first.xpAdded, 10)

    const replay = await fetch(`${baseUrl}/v1/lan-social/contribution`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${credential}`,
      },
      body: JSON.stringify({
        idempotencyKey: 'L'.repeat(43),
        learningDay: '2026-08-10',
      }),
    })
    assert.equal(replay.status, 200)
    assert.equal((await replay.json() as Record<string, unknown>).applied, false)

    const snapshotResponse = await fetch(`${baseUrl}/v1/lan-social/snapshot`, {
      headers: { Authorization: `Bearer ${credential}` },
    })
    assert.equal(snapshotResponse.status, 200)
    const snapshot = await snapshotResponse.json() as Record<string, unknown>
    assert.equal(snapshot.state, 'active')
    assert.equal((snapshot.standings as unknown[]).length, 5)
    assert.equal(JSON.stringify(snapshot).includes('participantId'), false)
    assert.equal(JSON.stringify(snapshot).includes('name'), false)
  })

  it('2端末の共同完了後、退出で資格情報とその寄与を無効化する', async () => {
    const { baseUrl, store } = await fixture()
    const room = await createRoom(baseUrl, store.coordinatorKey, 'friends', 2, 'M'.repeat(32))
    const one = await joinRoom(baseUrl, room.inviteCode as string, 'N'.repeat(32))
    const two = await joinRoom(baseUrl, room.inviteCode as string, 'P'.repeat(32))

    for (const [member, event] of [[one, 'Q'], [two, 'R']] as const) {
      const response = await fetch(`${baseUrl}/v1/lan-social/contribution`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${member.credential}`,
        },
        body: JSON.stringify({
          idempotencyKey: event.repeat(43), learningDay: '2026-08-10',
        }),
      })
      assert.equal(response.status, 200)
      const result = await response.json() as Record<string, unknown>
      assert.equal(result.xpAdded, 0)
    }
    const completed = await fetch(`${baseUrl}/v1/lan-social/snapshot`, {
      headers: { Authorization: `Bearer ${one.credential}` },
    })
    assert.equal((await completed.json() as Record<string, unknown>).completed, true)

    const leave = await fetch(`${baseUrl}/v1/lan-social/leave`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${one.credential}` },
    })
    assert.equal(leave.status, 204)
    const denied = await fetch(`${baseUrl}/v1/lan-social/snapshot`, {
      headers: { Authorization: `Bearer ${one.credential}` },
    })
    assert.equal(denied.status, 401)
    const remaining = await fetch(`${baseUrl}/v1/lan-social/snapshot`, {
      headers: { Authorization: `Bearer ${two.credential}` },
    })
    const snapshot = await remaining.json() as Record<string, unknown>
    assert.equal(snapshot.state, 'waiting_for_partner')
    assert.equal(snapshot.completed, false)
  })

  it('期限後の実CoordinatorからFriends terminal receiptを再送できる', async () => {
    let clock = NOW
    const { baseUrl, store } = await fixture(undefined, () => clock)
    const room = await createRoom(
      baseUrl,
      store.coordinatorKey,
      'friends',
      2,
      'S'.repeat(32),
    )
    const one = await joinRoom(baseUrl, room.inviteCode as string, 'T'.repeat(32))
    const two = await joinRoom(baseUrl, room.inviteCode as string, 'V'.repeat(32))
    for (const [member, event] of [[one, 'W'], [two, 'X']] as const) {
      const response = await fetch(`${baseUrl}/v1/lan-social/contribution`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${member.credential}`,
        },
        body: JSON.stringify({
          idempotencyKey: event.repeat(43), learningDay: '2026-08-10',
        }),
      })
      assert.equal(response.status, 200)
    }
    clock = Date.parse(room.expiresAt as string) + 8 * 86_400_000

    const first = await fetch(`${baseUrl}/v1/lan-social/settlement`, {
      headers: { Authorization: `Bearer ${one.credential}` },
    })
    assert.equal(first.status, 200)
    const receipt = await first.json() as Record<string, unknown>
    assert.deepEqual(receipt, {
      protocolVersion: 1,
      roomId: room.roomId,
      kind: 'friends',
      completed: true,
      settledAt: room.expiresAt,
    })
    const replay = await fetch(`${baseUrl}/v1/lan-social/settlement`, {
      headers: { Authorization: `Bearer ${one.credential}` },
    })
    assert.deepEqual(await replay.json(), receipt)
  })
})
