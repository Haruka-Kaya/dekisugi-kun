import { createHmac, randomBytes, timingSafeEqual } from 'node:crypto'
import { mkdir, open, readFile, rename, chmod } from 'node:fs/promises'
import { dirname } from 'node:path'

import { isValidDay, jstWeekKey } from './day.js'

/**
 * 外部データ処理者を使わない、LAN内ソーシャル機能の正本。
 *
 * Vercel Functions や Upstash からは呼ばない。学校・家庭が管理する同一LAN上の
 * coordinatorだけがこのファイルを使い、状態はそのPCのローカルファイルへ残す。
 * 氏名、回答、選択肢、音声、端末IDを受け取る欄は意図的に存在しない。
 */

export const LAN_SOCIAL_PROTOCOL_VERSION = 1
export const LAN_SOCIAL_CONSENT_VERSION = 'lan-social.v1'
export const LAN_SOCIAL_XP_PER_EVENT = 10
export const LAN_SOCIAL_LEAGUE_MIN_MEMBERS = 5
export const LAN_SOCIAL_LEAGUE_MAX_MEMBERS = 8
export const LAN_SOCIAL_MAX_EVENTS_PER_DAY = 10
export const LAN_SOCIAL_ROOM_RETENTION_MS = 7 * 86_400_000
export const LAN_SOCIAL_SETTLEMENT_RETENTION_MS = 104 * 7 * 86_400_000
export const LAN_SOCIAL_MAX_TERMINAL_SETTLEMENTS = 4_096

const LAN_SOCIAL_STATE_VERSION = 2

export type LanSocialRoomKind = 'friends' | 'league'

export type LanSocialParticipant = {
  participantId: string
  joinHash: string
  joinedAt: number
}

export type LanSocialContribution = {
  idempotencyHash: string
  participantId: string
  learningDay: string
  acceptedAt: number
}

export type LanSocialRoom = {
  roomId: string
  kind: LanSocialRoomKind
  capacity: number
  inviteHash: string
  createHash: string
  createdAt: number
  expiresAt: number
  weekStart: string | null
  participants: LanSocialParticipant[]
  revokedJoinHashes: string[]
  contributions: LanSocialContribution[]
}

export type LanSocialFriendsTerminalReceipt = {
  protocolVersion: 1
  roomId: string
  kind: 'friends'
  completed: boolean
  settledAt: string
}

export type LanSocialLeagueTerminalReceipt = {
  protocolVersion: 1
  roomId: string
  kind: 'league'
  weekStart: string
  participantBand: 'under5' | '5-8'
  xp: number
  rank: number | null
  tied: boolean
  participantCount: number | null
  settledAt: string
}

export type LanSocialTerminalReceipt =
  | LanSocialFriendsTerminalReceipt
  | LanSocialLeagueTerminalReceipt

type LanSocialTerminalSettlement = {
  receiptKey: string
  purgeAfter: number
  receipt: LanSocialTerminalReceipt
}

type LanSocialState = {
  version: 2
  serverSecret: string
  coordinatorKey: string
  rooms: LanSocialRoom[]
  settlements: LanSocialTerminalSettlement[]
}

export type LanSocialCreatedRoom = {
  protocolVersion: 1
  roomId: string
  kind: LanSocialRoomKind
  inviteCode: string
  capacity: number
  expiresAt: string
  weekStart: string | null
}

export type LanSocialMembership = {
  protocolVersion: 1
  roomId: string
  kind: LanSocialRoomKind
  credential: string
  expiresAt: string
  weekStart: string | null
}

export type LanSocialFriendsSnapshot = {
  protocolVersion: 1
  kind: 'friends'
  state: 'waiting_for_partner' | 'active' | 'completed' | 'expired'
  participantBand: 'one' | 'two'
  myContributed: boolean
  completed: boolean
  expiresAt: string
}

export type LanSocialLeagueStanding = {
  rank: number | null
  xp: number
  isMe: boolean
  tied: boolean
}

export type LanSocialLeagueSnapshot = {
  protocolVersion: 1
  kind: 'league'
  state: 'waiting_for_privacy_threshold' | 'active' | 'expired'
  participantBand: 'under5' | '5-8'
  standings: LanSocialLeagueStanding[]
  myXp: number
  weekStart: string
  weekEnd: string
  expiresAt: string
}

export type LanSocialSnapshot = LanSocialFriendsSnapshot | LanSocialLeagueSnapshot

export class LanSocialError extends Error {
  constructor(
    readonly code:
      | 'bad_request'
      | 'unauthorized'
      | 'unknown_room'
      | 'expired'
      | 'room_full'
      | 'join_revoked'
      | 'wrong_day'
      | 'daily_limit'
      | 'not_settled',
  ) {
    super(code)
  }
}

const CODE_ALPHABET = '23456789ABCDEFGHJKMNPQRSTVWXYZ'
// 24 random bytesのbase64url（32文字）だけ。canonical UUIDをそのまま送る欄にしない。
const ROOM_OPERATION_KEY = /^[A-Za-z0-9_-]{32}$/
// SHA-256 digestのbase64url（43文字）だけ。ローカルevent IDそのものを受けない。
const EVENT_IDEMPOTENCY_KEY = /^[A-Za-z0-9_-]{43}$/
const ROOM_ID = /^[a-f0-9]{24}$/
const PARTICIPANT_ID = /^[a-f0-9]{24}$/
const CREDENTIAL = /^([a-f0-9]{24})\.([a-f0-9]{24})\.([A-Za-z0-9_-]{43})$/

function b64url(value: Buffer): string {
  return value.toString('base64url')
}

function hmac(secret: string, value: string): string {
  return createHmac('sha256', secret).update(value).digest('hex')
}

function hmacB64(secret: string, value: string): string {
  return createHmac('sha256', secret).update(value).digest('base64url')
}

function safeEqual(left: string, right: string): boolean {
  const a = Buffer.from(left, 'utf8')
  const b = Buffer.from(right, 'utf8')
  return a.length === b.length && timingSafeEqual(a, b)
}

function opaqueRandom(bytes = 24): string {
  return b64url(randomBytes(bytes))
}

function inviteFromDigest(digest: Buffer): string {
  let out = ''
  for (let i = 0; i < 12; i += 1) {
    out += CODE_ALPHABET[digest[i]! % CODE_ALPHABET.length]
  }
  return out
}

export function normalizeLanSocialInvite(value: unknown): string | undefined {
  if (typeof value !== 'string') return undefined
  const clean = value.toUpperCase().replace(/[\s-]/g, '')
  if (clean.length !== 12) return undefined
  for (const char of clean) if (!CODE_ALPHABET.includes(char)) return undefined
  return clean
}

export function formatLanSocialInvite(value: string): string {
  return `${value.slice(0, 4)}-${value.slice(4, 8)}-${value.slice(8, 12)}`
}

function learningDayAt(now: number): string {
  // アプリと同じ午前4時区切り。JSTへ移してから4時間戻す。
  return new Date(now + 5 * 3_600_000).toISOString().slice(0, 10)
}

function shiftDay(day: string, days: number): string {
  const epoch = Date.parse(`${day}T00:00:00Z`)
  return new Date(epoch + days * 86_400_000).toISOString().slice(0, 10)
}

function leagueExpiry(weekStart: string): number {
  const nextMonday = shiftDay(weekStart, 7)
  return Date.parse(`${nextMonday}T04:00:00+09:00`)
}

function exactObject(value: unknown, keys: readonly string[]): value is Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return false
  const actual = Object.keys(value as Record<string, unknown>).sort()
  const expected = [...keys].sort()
  return actual.length === expected.length && actual.every((key, index) => key === expected[index])
}

function migrateState(value: unknown): { state: LanSocialState; migrated: boolean } {
  if (exactObject(value, ['version', 'serverSecret', 'coordinatorKey', 'rooms'])) {
    if (
      value.version !== 1 ||
      typeof value.serverSecret !== 'string' ||
      value.serverSecret.length < 43 ||
      typeof value.coordinatorKey !== 'string' ||
      value.coordinatorKey.length < 32 ||
      !Array.isArray(value.rooms)
    ) {
      throw new Error('LAN social legacy state header is invalid')
    }
    for (const room of value.rooms) validateRoom(room)
    return {
      state: {
        version: LAN_SOCIAL_STATE_VERSION,
        serverSecret: value.serverSecret,
        coordinatorKey: value.coordinatorKey,
        rooms: value.rooms,
        settlements: [],
      },
      migrated: true,
    }
  }
  validateState(value)
  return { state: value, migrated: false }
}

function validateState(value: unknown): asserts value is LanSocialState {
  if (!exactObject(value, [
    'version', 'serverSecret', 'coordinatorKey', 'rooms', 'settlements',
  ])) {
    throw new Error('LAN social state has unknown or missing fields')
  }
  if (
    value.version !== LAN_SOCIAL_STATE_VERSION ||
    typeof value.serverSecret !== 'string' ||
    value.serverSecret.length < 43 ||
    typeof value.coordinatorKey !== 'string' ||
    value.coordinatorKey.length < 32 ||
    !Array.isArray(value.rooms) ||
    !Array.isArray(value.settlements) ||
    value.settlements.length > LAN_SOCIAL_MAX_TERMINAL_SETTLEMENTS
  ) {
    throw new Error('LAN social state header is invalid')
  }
  for (const room of value.rooms) validateRoom(room)
  const receiptKeys = new Set<string>()
  for (const settlement of value.settlements) {
    validateTerminalSettlement(settlement)
    if (receiptKeys.has(settlement.receiptKey)) {
      throw new Error('LAN social settlement is duplicated')
    }
    receiptKeys.add(settlement.receiptKey)
  }
}

function validateTerminalSettlement(
  value: unknown,
): asserts value is LanSocialTerminalSettlement {
  if (!exactObject(value, ['receiptKey', 'purgeAfter', 'receipt']) ||
    typeof value.receiptKey !== 'string' || !/^[a-f0-9]{64}$/.test(value.receiptKey) ||
    typeof value.purgeAfter !== 'number' || !Number.isFinite(value.purgeAfter)) {
    throw new Error('LAN social settlement is invalid')
  }
  validateTerminalReceipt(value.receipt)
  const settledAt = Date.parse(value.receipt.settledAt)
  if (!Number.isFinite(settledAt) ||
    value.purgeAfter !== settledAt + LAN_SOCIAL_SETTLEMENT_RETENTION_MS) {
    throw new Error('LAN social settlement retention is invalid')
  }
}

function validateTerminalReceipt(value: unknown): asserts value is LanSocialTerminalReceipt {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error('LAN social terminal receipt is invalid')
  }
  const kind = (value as Record<string, unknown>).kind
  if (kind === 'friends') {
    if (!exactObject(value, [
      'protocolVersion', 'roomId', 'kind', 'completed', 'settledAt',
    ]) || value.protocolVersion !== LAN_SOCIAL_PROTOCOL_VERSION ||
      typeof value.roomId !== 'string' || !ROOM_ID.test(value.roomId) ||
      typeof value.completed !== 'boolean' ||
      typeof value.settledAt !== 'string' || !Number.isFinite(Date.parse(value.settledAt))) {
      throw new Error('LAN social friends receipt is invalid')
    }
    return
  }
  if (kind !== 'league' || !exactObject(value, [
    'protocolVersion', 'roomId', 'kind', 'weekStart', 'participantBand',
    'xp', 'rank', 'tied', 'participantCount', 'settledAt',
  ]) || value.protocolVersion !== LAN_SOCIAL_PROTOCOL_VERSION ||
    typeof value.roomId !== 'string' || !ROOM_ID.test(value.roomId) ||
    typeof value.weekStart !== 'string' || !isValidDay(value.weekStart) ||
    (value.participantBand !== 'under5' && value.participantBand !== '5-8') ||
    typeof value.xp !== 'number' || !Number.isInteger(value.xp) ||
    value.xp < 0 || value.xp % LAN_SOCIAL_XP_PER_EVENT !== 0 ||
    !(value.rank === null || (typeof value.rank === 'number' &&
      Number.isInteger(value.rank) && value.rank >= 1 && value.rank <= 8)) ||
    typeof value.tied !== 'boolean' ||
    !(value.participantCount === null || (typeof value.participantCount === 'number' &&
      Number.isInteger(value.participantCount) &&
      value.participantCount >= LAN_SOCIAL_LEAGUE_MIN_MEMBERS &&
      value.participantCount <= LAN_SOCIAL_LEAGUE_MAX_MEMBERS)) ||
    typeof value.settledAt !== 'string' || !Number.isFinite(Date.parse(value.settledAt))) {
    throw new Error('LAN social league receipt is invalid')
  }
  if (value.participantBand === 'under5') {
    if (value.participantCount !== null || value.xp !== 0 ||
      value.rank !== null || value.tied) {
      throw new Error('LAN social private league receipt leaks a result')
    }
    return
  }
  if (value.participantCount === null ||
    (value.rank !== null && value.rank > value.participantCount)) {
    throw new Error('LAN social league receipt threshold is invalid')
  }
}

function validateRoom(value: unknown): asserts value is LanSocialRoom {
  if (!exactObject(value, [
    'roomId', 'kind', 'capacity', 'inviteHash', 'createHash', 'createdAt',
    'expiresAt', 'weekStart', 'participants', 'revokedJoinHashes', 'contributions',
  ])) {
    throw new Error('LAN social room has unknown or missing fields')
  }
  const validCapacity = value.kind === 'friends'
    ? value.capacity === 2
    : value.kind === 'league' &&
      Number.isInteger(value.capacity) &&
      Number(value.capacity) >= LAN_SOCIAL_LEAGUE_MIN_MEMBERS &&
      Number(value.capacity) <= LAN_SOCIAL_LEAGUE_MAX_MEMBERS
  if (
    typeof value.roomId !== 'string' || !ROOM_ID.test(value.roomId) ||
    !validCapacity ||
    typeof value.inviteHash !== 'string' || !/^[a-f0-9]{64}$/.test(value.inviteHash) ||
    typeof value.createHash !== 'string' || !/^[a-f0-9]{64}$/.test(value.createHash) ||
    typeof value.createdAt !== 'number' || !Number.isFinite(value.createdAt) ||
    typeof value.expiresAt !== 'number' || !Number.isFinite(value.expiresAt) ||
    !(value.weekStart === null || (typeof value.weekStart === 'string' && isValidDay(value.weekStart))) ||
    !Array.isArray(value.participants) || !Array.isArray(value.revokedJoinHashes) ||
    !Array.isArray(value.contributions)
  ) {
    throw new Error('LAN social room is invalid')
  }
  if (value.kind === 'league' && value.weekStart === null) {
    throw new Error('league room is missing its week')
  }
  if (value.kind === 'friends' && value.weekStart !== null) {
    throw new Error('friends room unexpectedly has a week')
  }
  if (value.participants.length > Number(value.capacity)) {
    throw new Error('LAN social room exceeds capacity')
  }
  const participantIds = new Set<string>()
  const joinHashes = new Set<string>()
  for (const participant of value.participants) {
    if (!exactObject(participant, ['participantId', 'joinHash', 'joinedAt']) ||
      typeof participant.participantId !== 'string' || !PARTICIPANT_ID.test(participant.participantId) ||
      typeof participant.joinHash !== 'string' || !/^[a-f0-9]{64}$/.test(participant.joinHash) ||
      typeof participant.joinedAt !== 'number' || !Number.isFinite(participant.joinedAt) ||
      !participantIds.add(participant.participantId) || !joinHashes.add(participant.joinHash)) {
      throw new Error('LAN social participant is invalid')
    }
  }
  for (const revoked of value.revokedJoinHashes) {
    if (typeof revoked !== 'string' || !/^[a-f0-9]{64}$/.test(revoked)) {
      throw new Error('LAN social revoked join is invalid')
    }
  }
  const idempotencyHashes = new Set<string>()
  for (const contribution of value.contributions) {
    if (!exactObject(contribution, [
      'idempotencyHash', 'participantId', 'learningDay', 'acceptedAt',
    ]) || typeof contribution.idempotencyHash !== 'string' ||
      !/^[a-f0-9]{64}$/.test(contribution.idempotencyHash) ||
      typeof contribution.participantId !== 'string' ||
      !participantIds.has(contribution.participantId) ||
      typeof contribution.learningDay !== 'string' || !isValidDay(contribution.learningDay) ||
      typeof contribution.acceptedAt !== 'number' || !Number.isFinite(contribution.acceptedAt) ||
      !idempotencyHashes.add(contribution.idempotencyHash)) {
      throw new Error('LAN social contribution is invalid')
    }
  }
}

/** 原子的なローカルJSON保存。壊れた状態は空として扱わず、起動を止める。 */
export class LanSocialFileStore {
  private constructor(
    readonly path: string,
    private state: LanSocialState,
  ) {}

  private tail: Promise<void> = Promise.resolve()

  static async open(path: string): Promise<LanSocialFileStore> {
    let state: LanSocialState
    try {
      const raw = await readFile(path, 'utf8')
      const parsed: unknown = JSON.parse(raw)
      const loaded = migrateState(parsed)
      state = loaded.state
      if (loaded.migrated) await writeState(path, state)
    } catch (error) {
      if (!isMissingFile(error)) throw error
      state = {
        version: LAN_SOCIAL_STATE_VERSION,
        serverSecret: opaqueRandom(32),
        coordinatorKey: opaqueRandom(24),
        rooms: [],
        settlements: [],
      }
      await writeState(path, state)
    }
    return new LanSocialFileStore(path, state)
  }

  get coordinatorKey(): string {
    return this.state.coordinatorKey
  }

  get serverSecret(): string {
    return this.state.serverSecret
  }

  snapshot(): LanSocialState {
    return structuredClone(this.state)
  }

  async mutate<T>(operation: (draft: LanSocialState) => T | Promise<T>): Promise<T> {
    let resolveResult!: (value: T | PromiseLike<T>) => void
    let rejectResult!: (reason?: unknown) => void
    const result = new Promise<T>((resolve, reject) => {
      resolveResult = resolve
      rejectResult = reject
    })
    this.tail = this.tail.then(async () => {
      const draft = structuredClone(this.state)
      try {
        const value = await operation(draft)
        validateState(draft)
        await writeState(this.path, draft)
        this.state = draft
        resolveResult(value)
      } catch (error) {
        rejectResult(error)
      }
    })
    // 前の失敗で直列化チェーンを永久停止させない。
    this.tail = this.tail.catch(() => undefined)
    return result
  }
}

function isMissingFile(error: unknown): boolean {
  return Boolean(error && typeof error === 'object' && 'code' in error && error.code === 'ENOENT')
}

async function writeState(path: string, state: LanSocialState): Promise<void> {
  await mkdir(dirname(path), { recursive: true, mode: 0o700 })
  const temporary = `${path}.${process.pid}.${opaqueRandom(6)}.tmp`
  const file = await open(temporary, 'wx', 0o600)
  try {
    await file.writeFile(`${JSON.stringify(state)}\n`, 'utf8')
    await file.sync()
  } finally {
    await file.close()
  }
  await rename(temporary, path)
  await chmod(path, 0o600)
}

export class LanSocialCoordinator {
  constructor(private readonly store: LanSocialFileStore) {}

  coordinatorKeyMatches(value: unknown): boolean {
    return typeof value === 'string' && safeEqual(value, this.store.coordinatorKey)
  }

  rateIdentity(value: string): string {
    return hmac(this.store.serverSecret, `rate:${value}`)
  }

  async createRoom(args: {
    kind: LanSocialRoomKind
    capacity: number
    createKey: string
    now?: number
  }): Promise<LanSocialCreatedRoom> {
    if (!ROOM_OPERATION_KEY.test(args.createKey)) throw new LanSocialError('bad_request')
    if (args.kind === 'friends' && args.capacity !== 2) throw new LanSocialError('bad_request')
    if (args.kind === 'league' &&
      (!Number.isInteger(args.capacity) ||
        args.capacity < LAN_SOCIAL_LEAGUE_MIN_MEMBERS ||
        args.capacity > LAN_SOCIAL_LEAGUE_MAX_MEMBERS)) {
      throw new LanSocialError('bad_request')
    }
    const now = args.now ?? Date.now()
    if (!Number.isFinite(now) || now <= 0) throw new LanSocialError('bad_request')

    return this.store.mutate((state) => {
      pruneRooms(state, now)
      const createHash = hmac(state.serverSecret, `create:${args.createKey}`)
      const existing = state.rooms.find((room) => room.createHash === createHash)
      if (existing) {
        if (existing.kind !== args.kind || existing.capacity !== args.capacity) {
          throw new LanSocialError('bad_request')
        }
        return createdRoom(state.serverSecret, existing, args.createKey)
      }

      const roomId = hmac(state.serverSecret, `room:${args.createKey}`).slice(0, 24)
      const inviteCode = inviteFromDigest(
        createHmac('sha256', state.serverSecret).update(`invite:${args.createKey}`).digest(),
      )
      const weekStart = args.kind === 'league'
        ? jstWeekKey(learningDayAt(now))
        : null
      const expiresAt = args.kind === 'league'
        ? leagueExpiry(weekStart!)
        : now + 72 * 3_600_000
      const room: LanSocialRoom = {
        roomId,
        kind: args.kind,
        capacity: args.capacity,
        inviteHash: hmac(state.serverSecret, `invite-code:${inviteCode}`),
        createHash,
        createdAt: now,
        expiresAt,
        weekStart,
        participants: [],
        revokedJoinHashes: [],
        contributions: [],
      }
      state.rooms.push(room)
      return createdRoom(state.serverSecret, room, args.createKey)
    })
  }

  async join(args: {
    inviteCode: string
    joinKey: string
    now?: number
  }): Promise<LanSocialMembership> {
    const inviteCode = normalizeLanSocialInvite(args.inviteCode)
    if (!inviteCode || !ROOM_OPERATION_KEY.test(args.joinKey)) {
      throw new LanSocialError('bad_request')
    }
    const now = args.now ?? Date.now()
    return this.store.mutate((state) => {
      pruneRooms(state, now)
      const inviteHash = hmac(state.serverSecret, `invite-code:${inviteCode}`)
      const room = state.rooms.find((candidate) => safeEqual(candidate.inviteHash, inviteHash))
      if (!room) throw new LanSocialError('unknown_room')
      if (room.expiresAt <= now) throw new LanSocialError('expired')
      const joinHash = hmac(state.serverSecret, `join:${room.roomId}:${args.joinKey}`)
      if (room.revokedJoinHashes.includes(joinHash)) throw new LanSocialError('join_revoked')
      const participantId = hmac(
        state.serverSecret,
        `participant:${room.roomId}:${args.joinKey}`,
      ).slice(0, 24)
      let participant = room.participants.find((candidate) => candidate.joinHash === joinHash)
      if (!participant) {
        if (room.participants.length >= room.capacity) throw new LanSocialError('room_full')
        participant = { participantId, joinHash, joinedAt: now }
        room.participants.push(participant)
      }
      return membership(state.serverSecret, room, participant.participantId)
    })
  }

  authenticate(credential: unknown, now = Date.now()): {
    room: LanSocialRoom
    participantId: string
  } {
    const state = this.store.snapshot()
    const { roomId, participantId } = parseCredential(state.serverSecret, credential)
    const room = state.rooms.find((candidate) => candidate.roomId === roomId)
    if (!room || room.expiresAt + LAN_SOCIAL_ROOM_RETENTION_MS <= now) {
      throw new LanSocialError('unauthorized')
    }
    if (
      !room.participants.some((candidate) => candidate.participantId === participantId)) {
      throw new LanSocialError('unauthorized')
    }
    return { room, participantId }
  }

  async contribute(args: {
    credential: string
    idempotencyKey: string
    learningDay: string
    now?: number
  }): Promise<{ applied: boolean; xpAdded: number; snapshot: LanSocialSnapshot }> {
    if (!EVENT_IDEMPOTENCY_KEY.test(args.idempotencyKey) || !isValidDay(args.learningDay)) {
      throw new LanSocialError('bad_request')
    }
    const now = args.now ?? Date.now()
    const auth = this.authenticate(args.credential, now)
    return this.store.mutate((state) => {
      const room = state.rooms.find((candidate) => candidate.roomId === auth.room.roomId)
      if (!room || !room.participants.some((p) => p.participantId === auth.participantId)) {
        throw new LanSocialError('unauthorized')
      }
      if (room.expiresAt <= now) throw new LanSocialError('expired')
      const today = learningDayAt(now)
      if (args.learningDay !== today ||
        (room.kind === 'league' && jstWeekKey(args.learningDay) !== room.weekStart)) {
        throw new LanSocialError('wrong_day')
      }
      const idempotencyHash = hmac(
        state.serverSecret,
        `event:${room.roomId}:${auth.participantId}:${args.idempotencyKey}`,
      )
      const replay = room.contributions.find(
        (item) => item.idempotencyHash === idempotencyHash,
      )
      if (replay) {
        return {
          applied: false,
          xpAdded: 0,
          snapshot: buildSnapshot(room, auth.participantId, now),
        }
      }
      const mine = room.contributions.filter(
        (item) => item.participantId === auth.participantId,
      )
      if (room.kind === 'friends' && mine.length >= 1) {
        return {
          applied: false,
          xpAdded: 0,
          snapshot: buildSnapshot(room, auth.participantId, now),
        }
      }
      const todayCount = mine.filter((item) => item.learningDay === args.learningDay).length
      if (todayCount >= LAN_SOCIAL_MAX_EVENTS_PER_DAY) {
        throw new LanSocialError('daily_limit')
      }
      room.contributions.push({
        idempotencyHash,
        participantId: auth.participantId,
        learningDay: args.learningDay,
        acceptedAt: now,
      })
      return {
        applied: true,
        // Friendsは共同状態だけで、個別得点という概念をwireへ出さない。
        // fixed 10 XPは実参加者leagueのstanding専用。
        xpAdded: room.kind === 'league' ? LAN_SOCIAL_XP_PER_EVENT : 0,
        snapshot: buildSnapshot(room, auth.participantId, now),
      }
    })
  }

  snapshot(credential: string, now = Date.now()): LanSocialSnapshot {
    const auth = this.authenticate(credential, now)
    return buildSnapshot(auth.room, auth.participantId, now)
  }

  /// Room本体のretention後も、発行済みcredentialへ最小の確定結果だけを返す。
  async settlement(
    credential: string,
    now = Date.now(),
  ): Promise<LanSocialTerminalReceipt> {
    if (!Number.isFinite(now) || now <= 0) throw new LanSocialError('bad_request')
    return this.store.mutate((state) => {
      const { roomId, participantId } = parseCredential(state.serverSecret, credential)
      pruneTerminalSettlements(state, now)
      const receiptKey = terminalReceiptKey(state.serverSecret, roomId, participantId)
      const existing = state.settlements.find(
        (candidate) => candidate.receiptKey === receiptKey,
      )
      if (existing) return structuredClone(existing.receipt)

      const room = state.rooms.find((candidate) => candidate.roomId === roomId)
      if (!room || !room.participants.some(
        (candidate) => candidate.participantId === participantId,
      )) {
        // MACが正しくても、期限を越えてreceiptも消えた資格は終了済みとして扱う。
        throw new LanSocialError('expired')
      }
      if (room.expiresAt > now) throw new LanSocialError('not_settled')
      materializeRoomSettlements(state, room, now)
      pruneRooms(state, now)
      const settled = state.settlements.find(
        (candidate) => candidate.receiptKey === receiptKey,
      )
      if (!settled) throw new LanSocialError('expired')
      return structuredClone(settled.receipt)
    })
  }

  async leave(credential: string, now = Date.now()): Promise<void> {
    const auth = this.authenticate(credential, now)
    await this.store.mutate((state) => {
      const room = state.rooms.find((candidate) => candidate.roomId === auth.room.roomId)
      if (!room) throw new LanSocialError('unauthorized')
      const participant = room.participants.find(
        (candidate) => candidate.participantId === auth.participantId,
      )
      if (!participant) throw new LanSocialError('unauthorized')
      const receiptKey = terminalReceiptKey(
        state.serverSecret,
        room.roomId,
        participant.participantId,
      )
      state.settlements = state.settlements.filter(
        (candidate) => candidate.receiptKey !== receiptKey,
      )
      room.revokedJoinHashes.push(participant.joinHash)
      room.participants = room.participants.filter(
        (candidate) => candidate.participantId !== auth.participantId,
      )
      // opt-outで、その参加者に結び付く派生記録も同時に消す。
      room.contributions = room.contributions.filter(
        (candidate) => candidate.participantId !== auth.participantId,
      )
    })
  }
}

function createdRoom(
  secret: string,
  room: LanSocialRoom,
  createKey: string,
): LanSocialCreatedRoom {
  const inviteCode = inviteFromDigest(
    createHmac('sha256', secret).update(`invite:${createKey}`).digest(),
  )
  return {
    protocolVersion: LAN_SOCIAL_PROTOCOL_VERSION,
    roomId: room.roomId,
    kind: room.kind,
    inviteCode: formatLanSocialInvite(inviteCode),
    capacity: room.capacity,
    expiresAt: new Date(room.expiresAt).toISOString(),
    weekStart: room.weekStart,
  }
}

function membership(
  secret: string,
  room: LanSocialRoom,
  participantId: string,
): LanSocialMembership {
  return {
    protocolVersion: LAN_SOCIAL_PROTOCOL_VERSION,
    roomId: room.roomId,
    kind: room.kind,
    credential: `${room.roomId}.${participantId}.${credentialMac(secret, room.roomId, participantId)}`,
    expiresAt: new Date(room.expiresAt).toISOString(),
    weekStart: room.weekStart,
  }
}

function parseCredential(
  secret: string,
  credential: unknown,
): { roomId: string; participantId: string } {
  if (typeof credential !== 'string') throw new LanSocialError('unauthorized')
  const match = CREDENTIAL.exec(credential)
  if (!match) throw new LanSocialError('unauthorized')
  const [, roomId, participantId, mac] = match
  const expected = credentialMac(secret, roomId!, participantId!)
  if (!safeEqual(mac!, expected)) throw new LanSocialError('unauthorized')
  return { roomId: roomId!, participantId: participantId! }
}

function credentialMac(secret: string, roomId: string, participantId: string): string {
  return hmacB64(secret, `credential:${roomId}:${participantId}`)
}

function terminalReceiptKey(
  secret: string,
  roomId: string,
  participantId: string,
): string {
  return hmac(secret, `settlement:${roomId}:${participantId}`)
}

function buildSnapshot(
  room: LanSocialRoom,
  participantId: string,
  now: number,
): LanSocialSnapshot {
  if (room.kind === 'friends') {
    const mine = room.contributions.some((item) => item.participantId === participantId)
    const contributed = new Set(room.contributions.map((item) => item.participantId))
    const complete = room.participants.length === 2 &&
      room.participants.every((item) => contributed.has(item.participantId))
    return {
      protocolVersion: LAN_SOCIAL_PROTOCOL_VERSION,
      kind: 'friends',
      state: room.expiresAt <= now
        ? 'expired'
        : complete
        ? 'completed'
        : room.participants.length < 2
        ? 'waiting_for_partner'
        : 'active',
      participantBand: room.participants.length < 2 ? 'one' : 'two',
      myContributed: mine,
      completed: complete,
      expiresAt: new Date(room.expiresAt).toISOString(),
    }
  }

  const counts = new Map<string, number>()
  for (const participant of room.participants) counts.set(participant.participantId, 0)
  for (const contribution of room.contributions) {
    if (!counts.has(contribution.participantId)) continue
    counts.set(contribution.participantId, (counts.get(contribution.participantId) ?? 0) + 1)
  }
  const weekStart = room.weekStart!
  const waiting = room.participants.length < LAN_SOCIAL_LEAGUE_MIN_MEMBERS
  const standings: LanSocialLeagueStanding[] = []
  if (!waiting) {
    const ordered = [...counts.entries()].sort((left, right) => {
      const score = right[1] - left[1]
      if (score !== 0) return score
      // participant IDは返さないが、同点の並びを安定させる。
      return left[0].localeCompare(right[0])
    })
    const scoreFrequency = new Map<number, number>()
    for (const count of counts.values()) {
      scoreFrequency.set(count, (scoreFrequency.get(count) ?? 0) + 1)
    }
    const anyScore = [...counts.values()].some((count) => count > 0)
    let previousScore: number | undefined
    let previousRank: number | null = null
    for (let index = 0; index < ordered.length; index += 1) {
      const [id, count] = ordered[index]!
      const rank: number | null = !anyScore
        ? null
        : previousScore === count
        ? previousRank
        : index + 1
      standings.push({
        rank,
        xp: count * LAN_SOCIAL_XP_PER_EVENT,
        isMe: id === participantId,
        tied: anyScore && (scoreFrequency.get(count) ?? 0) > 1,
      })
      previousScore = count
      previousRank = rank
    }
  }
  return {
    protocolVersion: LAN_SOCIAL_PROTOCOL_VERSION,
    kind: 'league',
    state: room.expiresAt <= now
      ? 'expired'
      : waiting
      ? 'waiting_for_privacy_threshold'
      : 'active',
    participantBand: waiting ? 'under5' : '5-8',
    standings,
    myXp: (counts.get(participantId) ?? 0) * LAN_SOCIAL_XP_PER_EVENT,
    weekStart,
    weekEnd: shiftDay(weekStart, 6),
    expiresAt: new Date(room.expiresAt).toISOString(),
  }
}

function materializeRoomSettlements(
  state: LanSocialState,
  room: LanSocialRoom,
  now: number,
): void {
  if (room.expiresAt > now ||
    room.expiresAt + LAN_SOCIAL_SETTLEMENT_RETENTION_MS <= now) {
    return
  }
  const settledAt = new Date(room.expiresAt).toISOString()
  const purgeAfter = room.expiresAt + LAN_SOCIAL_SETTLEMENT_RETENTION_MS
  for (const participant of room.participants) {
    const receiptKey = terminalReceiptKey(
      state.serverSecret,
      room.roomId,
      participant.participantId,
    )
    if (state.settlements.some((candidate) => candidate.receiptKey === receiptKey)) {
      continue
    }
    const snapshot = buildSnapshot(room, participant.participantId, room.expiresAt)
    let receipt: LanSocialTerminalReceipt
    if (snapshot.kind === 'friends') {
      receipt = {
        protocolVersion: LAN_SOCIAL_PROTOCOL_VERSION,
        roomId: room.roomId,
        kind: 'friends',
        completed: snapshot.completed,
        settledAt,
      }
    } else {
      const mine = snapshot.standings.find((standing) => standing.isMe)
      const eligible = snapshot.participantBand === '5-8' && mine !== undefined
      receipt = {
        protocolVersion: LAN_SOCIAL_PROTOCOL_VERSION,
        roomId: room.roomId,
        kind: 'league',
        weekStart: snapshot.weekStart,
        participantBand: eligible ? '5-8' : 'under5',
        xp: eligible ? mine.xp : 0,
        rank: eligible ? mine.rank : null,
        tied: eligible ? mine.tied : false,
        participantCount: eligible ? snapshot.standings.length : null,
        settledAt,
      }
    }
    state.settlements.push({ receiptKey, purgeAfter, receipt })
  }
  enforceSettlementLimit(state)
}

function pruneTerminalSettlements(state: LanSocialState, now: number): void {
  state.settlements = state.settlements.filter(
    (settlement) => settlement.purgeAfter > now,
  )
}

function enforceSettlementLimit(state: LanSocialState): void {
  if (state.settlements.length <= LAN_SOCIAL_MAX_TERMINAL_SETTLEMENTS) return
  state.settlements.sort((left, right) => {
    const byExpiry = right.purgeAfter - left.purgeAfter
    return byExpiry !== 0 ? byExpiry : left.receiptKey.localeCompare(right.receiptKey)
  })
  state.settlements = state.settlements.slice(
    0,
    LAN_SOCIAL_MAX_TERMINAL_SETTLEMENTS,
  )
}

function pruneRooms(state: LanSocialState, now: number): void {
  pruneTerminalSettlements(state, now)
  for (const room of state.rooms) {
    if (room.expiresAt + LAN_SOCIAL_ROOM_RETENTION_MS <= now) {
      materializeRoomSettlements(state, room, now)
    }
  }
  state.rooms = state.rooms.filter(
    (room) => room.expiresAt + LAN_SOCIAL_ROOM_RETENTION_MS > now,
  )
}

export function newLanSocialOpaqueKey(): string {
  return opaqueRandom(24)
}
