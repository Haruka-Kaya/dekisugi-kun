import assert from 'node:assert/strict'
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { dirname, join } from 'node:path'
import { afterEach, describe, it } from 'node:test'

import { inspectLanSocialPathProtection } from '../lib/lan-social-file-security.js'
import {
  LAN_SOCIAL_MAX_EVENTS_PER_DAY,
  LAN_SOCIAL_ROOM_RETENTION_MS,
  LanSocialCoordinator,
  LanSocialError,
  LanSocialFileStore,
} from '../lib/lan-social.js'

const NOW = Date.parse('2026-08-10T12:00:00+09:00')
const DAY = '2026-08-10'
const temporaryDirectories: string[] = []

afterEach(async () => {
  while (temporaryDirectories.length > 0) {
    const path = temporaryDirectories.pop()!
    await rm(path, { recursive: true, force: true })
  }
})

async function coordinator(): Promise<{
  value: LanSocialCoordinator
  store: LanSocialFileStore
  path: string
}> {
  const directory = await mkdtemp(join(tmpdir(), 'dekisugi-lan-social-'))
  temporaryDirectories.push(directory)
  const path = join(directory, 'state.json')
  const store = await LanSocialFileStore.open(path)
  return { value: new LanSocialCoordinator(store), store, path }
}

const key = (character: string) => character.repeat(32)

const eventKey = (character: string) => character.repeat(43)

describe('LAN socialの保存境界', () => {
  it('atomic更新後も保存directoryとstateをcurrent OS userだけにする', async () => {
    const { value, path } = await coordinator()
    await value.createRoom({
      kind: 'friends', capacity: 2, createKey: key('Z'), now: NOW,
    })

    const directoryProtection = await inspectLanSocialPathProtection(
      dirname(path),
      'directory',
    )
    const stateProtection = await inspectLanSocialPathProtection(path, 'file')
    assert.equal(
      directoryProtection.currentUserOnly,
      true,
      JSON.stringify(directoryProtection),
    )
    assert.equal(
      stateProtection.currentUserOnly,
      true,
      JSON.stringify(stateProtection),
    )
    if (process.platform === 'win32') {
      assert.equal(directoryProtection.windowsInheritanceProtected, true)
      assert.equal(directoryProtection.windowsAclRuleCount, 1)
      assert.equal(directoryProtection.windowsRuleIsInherited, false)
      // atomic replacementは保護済み親の唯一のACEを継承する。file単体で継承を
      // 切るためのPowerShellをrequestごとに起動する必要はない。
      assert.equal(stateProtection.windowsAclRuleCount, 1)
      assert.equal(stateProtection.windowsRuleIsInherited, true)
    } else {
      assert.equal(directoryProtection.posixMode, 0o700)
      assert.equal(stateProtection.posixMode, 0o600)
    }
  })

  it('壊れた保存を空部屋として起動せずfail-closedにする', async () => {
    const directory = await mkdtemp(join(tmpdir(), 'dekisugi-lan-social-corrupt-'))
    temporaryDirectories.push(directory)
    const path = join(directory, 'state.json')
    await writeFile(path, '{"version":1,"rooms":[]}', 'utf8')
    await assert.rejects(LanSocialFileStore.open(path), /state/)
    assert.equal(await readFile(path, 'utf8'), '{"version":1,"rooms":[]}')
  })

  it('参加コード・join key・端末ID・氏名・回答を保存しない', async () => {
    const { value, path } = await coordinator()
    const created = await value.createRoom({
      kind: 'friends', capacity: 2, createKey: key('A'), now: NOW,
    })
    const rawJoinKey = key('B')
    await value.join({ inviteCode: created.inviteCode, joinKey: rawJoinKey, now: NOW })
    const raw = await readFile(path, 'utf8')
    for (const forbidden of [
      created.inviteCode.replaceAll('-', ''), rawJoinKey,
      'ffffffff-1111-2222-3333-444444444444', '山田', '回答', 'audio',
    ]) {
      assert.equal(raw.includes(forbidden), false, `保存物に ${forbidden} が入った`)
    }
  })

  it('createとjoinは応答消失後の再送でも同じ部屋・同じ参加者になる', async () => {
    const { value, store } = await coordinator()
    const first = await value.createRoom({
      kind: 'league', capacity: 5, createKey: key('C'), now: NOW,
    })
    const replay = await value.createRoom({
      kind: 'league', capacity: 5, createKey: key('C'), now: NOW,
    })
    assert.deepEqual(replay, first)

    const joined = await value.join({
      inviteCode: first.inviteCode, joinKey: key('D'), now: NOW,
    })
    const joinedAgain = await value.join({
      inviteCode: first.inviteCode, joinKey: key('D'), now: NOW,
    })
    assert.deepEqual(joinedAgain, joined)
    assert.equal(store.snapshot().rooms[0]!.participants.length, 1)
  })

  it('coordinator再起動後も同じcredentialでroomと寄与を復元する', async () => {
    const { value, path } = await coordinator()
    const room = await value.createRoom({
      kind: 'league', capacity: 5, createKey: key('R'), now: NOW,
    })
    const member = await value.join({
      inviteCode: room.inviteCode, joinKey: key('S'), now: NOW,
    })
    await value.contribute({
      credential: member.credential,
      idempotencyKey: eventKey('T'),
      learningDay: DAY,
      now: NOW,
    })

    const reopened = await LanSocialFileStore.open(path)
    const restarted = new LanSocialCoordinator(reopened)
    const snapshot = restarted.snapshot(member.credential, NOW)

    assert.equal(snapshot.kind, 'league')
    if (snapshot.kind !== 'league') return
    assert.equal(snapshot.myXp, 10)
    assert.equal(snapshot.participantBand, 'under5')
    assert.deepEqual(snapshot.standings, [])
  })

  it('v1 stateをreceipt空のv2へ原子的に移行する', async () => {
    const { value, path } = await coordinator()
    const room = await value.createRoom({
      kind: 'friends', capacity: 2, createKey: key('1'), now: NOW,
    })
    const current = JSON.parse(await readFile(path, 'utf8')) as Record<string, unknown>
    delete current.settlements
    current.version = 1
    await writeFile(path, `${JSON.stringify(current)}\n`, 'utf8')

    const reopened = await LanSocialFileStore.open(path)
    assert.equal(reopened.snapshot().version, 2)
    assert.deepEqual(reopened.snapshot().settlements, [])
    assert.equal(reopened.snapshot().rooms[0]?.roomId, room.roomId)
    const migrated = JSON.parse(await readFile(path, 'utf8')) as Record<string, unknown>
    assert.equal(migrated.version, 2)
    assert.deepEqual(migrated.settlements, [])
  })

  it('同じterminal receipt keyが重複した保存状態をfail-closedにする', async () => {
    const { value, path } = await coordinator()
    const room = await value.createRoom({
      kind: 'friends', capacity: 2, createKey: key('2'), now: NOW,
    })
    await value.join({
      inviteCode: room.inviteCode, joinKey: key('3'), now: NOW,
    })
    const afterRoomRetention = Date.parse(room.expiresAt) +
      LAN_SOCIAL_ROOM_RETENTION_MS + 1
    await value.createRoom({
      kind: 'friends', capacity: 2, createKey: key('4'), now: afterRoomRetention,
    })

    const current = JSON.parse(await readFile(path, 'utf8')) as {
      settlements: unknown[]
    } & Record<string, unknown>
    assert.equal(current.settlements.length, 1)
    current.settlements.push(structuredClone(current.settlements[0]))
    await writeFile(path, `${JSON.stringify(current)}\n`, 'utf8')

    await assert.rejects(
      LanSocialFileStore.open(path),
      /settlement is duplicated/,
    )
  })

  it('同じcreate keyを違う条件へ使い回すと拒否する', async () => {
    const { value } = await coordinator()
    await value.createRoom({ kind: 'league', capacity: 5, createKey: key('E'), now: NOW })
    await assert.rejects(
      value.createRoom({ kind: 'league', capacity: 6, createKey: key('E'), now: NOW }),
      (error: unknown) => error instanceof LanSocialError && error.code === 'bad_request',
    )
  })
})

describe('実在参加者だけの週次リーグ', () => {
  it('5人未満では順位も他人の得点も1行も返さない', async () => {
    const { value } = await coordinator()
    const room = await value.createRoom({
      kind: 'league', capacity: 8, createKey: key('F'), now: NOW,
    })
    const memberships = []
    for (const character of ['G', 'H', 'J', 'K']) {
      memberships.push(await value.join({
        inviteCode: room.inviteCode, joinKey: key(character), now: NOW,
      }))
    }
    await value.contribute({
      credential: memberships[0]!.credential,
      idempotencyKey: eventKey('L'),
      learningDay: DAY,
      now: NOW,
    })
    const snapshot = value.snapshot(memberships[0]!.credential, NOW)
    assert.equal(snapshot.kind, 'league')
    if (snapshot.kind !== 'league') return
    assert.equal(snapshot.state, 'waiting_for_privacy_threshold')
    assert.equal(snapshot.participantBand, 'under5')
    assert.deepEqual(snapshot.standings, [])
    assert.equal(JSON.stringify(snapshot).includes('participantId'), false)
  })

  it('5人そろって初めて匿名順位を作り、架空行を足さない', async () => {
    const { value } = await coordinator()
    const room = await value.createRoom({
      kind: 'league', capacity: 5, createKey: key('M'), now: NOW,
    })
    const memberships = []
    for (const character of ['N', 'P', 'Q', 'R', 'S']) {
      memberships.push(await value.join({
        inviteCode: room.inviteCode, joinKey: key(character), now: NOW,
      }))
    }
    await value.contribute({
      credential: memberships[0]!.credential,
      idempotencyKey: eventKey('T'), learningDay: DAY, now: NOW,
    })
    await value.contribute({
      credential: memberships[1]!.credential,
      idempotencyKey: eventKey('V'), learningDay: DAY, now: NOW,
    })
    await value.contribute({
      credential: memberships[1]!.credential,
      idempotencyKey: eventKey('W'), learningDay: DAY, now: NOW,
    })

    const snapshot = value.snapshot(memberships[0]!.credential, NOW)
    assert.equal(snapshot.kind, 'league')
    if (snapshot.kind !== 'league') return
    assert.equal(snapshot.state, 'active')
    assert.equal(snapshot.standings.length, 5, '参加していない架空行を足している')
    assert.deepEqual(snapshot.standings.map((row) => row.xp), [20, 10, 0, 0, 0])
    assert.equal(snapshot.standings.filter((row) => row.isMe).length, 1)
    assert.equal(JSON.stringify(snapshot).includes('participantId'), false)
    assert.equal(JSON.stringify(snapshot).includes('name'), false)
  })

  it('同じeventの並行再送でも1回だけfixed 10XPを足す', async () => {
    const { value } = await coordinator()
    const room = await value.createRoom({
      kind: 'league', capacity: 5, createKey: key('X'), now: NOW,
    })
    const member = await value.join({
      inviteCode: room.inviteCode, joinKey: key('Y'), now: NOW,
    })
    const results = await Promise.all(
      Array.from({ length: 8 }, () => value.contribute({
        credential: member.credential,
        idempotencyKey: eventKey('Z'), learningDay: DAY, now: NOW,
      })),
    )
    assert.equal(results.filter((result) => result.applied).length, 1)
    assert.equal(results.reduce((sum, result) => sum + result.xpAdded, 0), 10)
  })

  it('1日の上限を超える申告をfail-closedで拒否する', async () => {
    const { value } = await coordinator()
    const room = await value.createRoom({
      kind: 'league', capacity: 5, createKey: key('2'), now: NOW,
    })
    const member = await value.join({
      inviteCode: room.inviteCode, joinKey: key('3'), now: NOW,
    })
    const alphabet = '456789ABCDEFGHJKMNPQRSTVWXYZ'
    for (let index = 0; index < LAN_SOCIAL_MAX_EVENTS_PER_DAY; index += 1) {
      const result = await value.contribute({
        credential: member.credential,
        idempotencyKey: eventKey(alphabet[index]!), learningDay: DAY, now: NOW,
      })
      assert.equal(result.applied, true)
    }
    await assert.rejects(
      value.contribute({
        credential: member.credential,
        idempotencyKey: eventKey('Z'), learningDay: DAY, now: NOW,
      }),
      (error: unknown) => error instanceof LanSocialError && error.code === 'daily_limit',
    )
  })

  it('端末が申告した別日を受け付けない', async () => {
    const { value } = await coordinator()
    const room = await value.createRoom({
      kind: 'league', capacity: 5, createKey: key('C'), now: NOW,
    })
    const member = await value.join({
      inviteCode: room.inviteCode, joinKey: key('D'), now: NOW,
    })
    await assert.rejects(
      value.contribute({
        credential: member.credential,
        idempotencyKey: eventKey('E'), learningDay: '2026-08-09', now: NOW,
      }),
      (error: unknown) => error instanceof LanSocialError && error.code === 'wrong_day',
    )
  })

  it('room削除と再起動後も全参加者の実順位receiptをexact-onceで返す', async () => {
    const { value, store, path } = await coordinator()
    const room = await value.createRoom({
      kind: 'league', capacity: 5, createKey: key('4'), now: NOW,
    })
    const members = []
    for (const character of ['5', '6', '7', '8', '9']) {
      members.push(await value.join({
        inviteCode: room.inviteCode,
        joinKey: key(character),
        now: NOW,
      }))
    }
    await value.contribute({
      credential: members[0]!.credential,
      idempotencyKey: eventKey('A'),
      learningDay: DAY,
      now: NOW,
    })
    const afterRoomRetention = Date.parse(room.expiresAt) +
      LAN_SOCIAL_ROOM_RETENTION_MS + 1
    await value.createRoom({
      kind: 'friends', capacity: 2, createKey: key('B'), now: afterRoomRetention,
    })
    assert.equal(
      store.snapshot().rooms.some((candidate) => candidate.roomId === room.roomId),
      false,
    )
    assert.equal(store.snapshot().settlements.length, 5)

    const restarted = new LanSocialCoordinator(await LanSocialFileStore.open(path))
    const first = await restarted.settlement(
      members[0]!.credential,
      afterRoomRetention,
    )
    const replay = await restarted.settlement(
      members[0]!.credential,
      afterRoomRetention + 1,
    )
    assert.deepEqual(replay, first)
    assert.deepEqual(first, {
      protocolVersion: 1,
      roomId: room.roomId,
      kind: 'league',
      weekStart: DAY,
      participantBand: '5-8',
      xp: 10,
      rank: 1,
      tied: false,
      participantCount: 5,
      settledAt: room.expiresAt,
    })
    const retained = JSON.stringify(store.snapshot().settlements)
    for (const forbidden of [
      'participantId', 'joinHash', 'contributions', 'learningDay',
      members[0]!.credential,
    ]) assert.equal(retained.includes(forbidden), false, forbidden)
  })
})

describe('2人だけのフレンズクエスト', () => {
  it('各実参加者の最初の学習1件だけで共同完了し、個別得点を返さない', async () => {
    const { value } = await coordinator()
    const room = await value.createRoom({
      kind: 'friends', capacity: 2, createKey: key('F'), now: NOW,
    })
    const one = await value.join({
      inviteCode: room.inviteCode, joinKey: key('G'), now: NOW,
    })
    const two = await value.join({
      inviteCode: room.inviteCode, joinKey: key('H'), now: NOW,
    })
    const first = await value.contribute({
      credential: one.credential,
      idempotencyKey: eventKey('J'), learningDay: DAY, now: NOW,
    })
    assert.equal(first.snapshot.kind, 'friends')
    assert.equal(first.snapshot.completed, false)
    assert.equal(first.xpAdded, 0)
    const duplicatePerson = await value.contribute({
      credential: one.credential,
      idempotencyKey: eventKey('K'), learningDay: DAY, now: NOW,
    })
    assert.equal(duplicatePerson.applied, false)

    const completed = await value.contribute({
      credential: two.credential,
      idempotencyKey: eventKey('L'), learningDay: DAY, now: NOW,
    })
    assert.equal(completed.snapshot.kind, 'friends')
    assert.equal(completed.snapshot.completed, true)
    assert.equal(completed.xpAdded, 0)
    const json = JSON.stringify(completed.snapshot)
    for (const forbidden of ['"score":', '"xp":', '"rank":', '"participantId":']) {
      assert.equal(json.includes(forbidden), false)
    }
  })

  it('退出するとその参加者と寄与を削除し、同じjoin keyは復活できない', async () => {
    const { value } = await coordinator()
    const room = await value.createRoom({
      kind: 'friends', capacity: 2, createKey: key('M'), now: NOW,
    })
    const member = await value.join({
      inviteCode: room.inviteCode, joinKey: key('N'), now: NOW,
    })
    await value.contribute({
      credential: member.credential,
      idempotencyKey: eventKey('P'), learningDay: DAY, now: NOW,
    })
    await value.leave(member.credential, NOW)
    assert.throws(() => value.snapshot(member.credential, NOW), LanSocialError)
    await assert.rejects(
      value.join({ inviteCode: room.inviteCode, joinKey: key('N'), now: NOW }),
      (error: unknown) => error instanceof LanSocialError && error.code === 'join_revoked',
    )
  })

  it('共同完了後に長期offlineでも再起動越しのreceiptを返す', async () => {
    const { value, path } = await coordinator()
    const room = await value.createRoom({
      kind: 'friends', capacity: 2, createKey: key('Q'), now: NOW,
    })
    const one = await value.join({
      inviteCode: room.inviteCode, joinKey: key('R'), now: NOW,
    })
    const two = await value.join({
      inviteCode: room.inviteCode, joinKey: key('S'), now: NOW,
    })
    await value.contribute({
      credential: one.credential,
      idempotencyKey: eventKey('T'),
      learningDay: DAY,
      now: NOW,
    })
    await value.contribute({
      credential: two.credential,
      idempotencyKey: eventKey('V'),
      learningDay: DAY,
      now: NOW,
    })
    const afterRoomRetention = Date.parse(room.expiresAt) +
      LAN_SOCIAL_ROOM_RETENTION_MS + 1
    const receipt = await value.settlement(one.credential, afterRoomRetention)
    assert.deepEqual(receipt, {
      protocolVersion: 1,
      roomId: room.roomId,
      kind: 'friends',
      completed: true,
      settledAt: room.expiresAt,
    })

    const restarted = new LanSocialCoordinator(await LanSocialFileStore.open(path))
    assert.deepEqual(
      await restarted.settlement(one.credential, afterRoomRetention + 1),
      receipt,
    )
  })
})
