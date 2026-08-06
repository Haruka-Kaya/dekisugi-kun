import { jstDayKey, nextJstMidnight } from './day.js'

/**
 * 無料で使える1日の会話量。
 *
 * ## なぜ「セッション数」で数えるか
 *
 * 当初は分で数えていた。Gemini Developer API では
 * **渡すトークンの寿命がそのまま会話時間の上限**になり
 * （実測: 期限の58秒後に `code=1011 auth token has expired` でセッションごと切断）、
 * 分単位で正確に配れたため。
 *
 * Vertex へ移って、それが使えなくなった。アクセストークンは60分有効で、
 * 期限は会話時間を縛らない。代わりに**Vertex 自身がセッションを約10分で打ち切る**
 * （実測: 9分時点で `code=1000 The operation was cancelled.`）。
 *
 * → 縛れる単位が「分」から「セッション」に変わった。
 *   1セッション ≒ 10分なので、無料枠はセッション数で配る。
 *
 * ## なぜ端末に回避されないか
 *
 * 会話はサーバが発行するアクセストークンでしか始められない（資格情報は端末に無い）。
 * そして1本のトークンで何時間も話すことはできない —
 * **セッションは Vertex 側が約10分で切る。**
 *
 * > [!warning] トークン自体は60分有効
 * > セッションの長さは Vertex が守るが、**60分のあいだ何度でも新しい
 * > セッションを張れる**。だから枠は「トークンを配った回数」で数え、
 * > 配ったら即座に引く。1回配る = 1セッション分。
 */

const kvUrl = () => process.env.KV_REST_API_URL
const kvToken = () => process.env.KV_REST_API_TOKEN

/** 1セッションの実測上限（分）。表示と見積もりに使う。 */
export const MINUTES_PER_SESSION = 10

/** 1日の無料枠（セッション数）。10分 × 2 = 約20分ぶん。 */
export const FREE_SESSIONS_PER_DAY = 2

/**
 * 1枠で話せる時間（分）。**再開はこの窓の中でだけ枠を引かない。**
 *
 * Vertex は約9分でセッションを切る（実測 `code=1000`）。
 * 切れたところで会話を終わらせると、生徒には
 * 「10分と言われたのに9分で打ち切られた」ように見える。
 * だから切れたら繋ぎ直すのだが、**繋ぎ直しのたびに枠を引かない**と決めると、
 * 端末が偽の再開ハンドルを送り続けるだけで無限に無料になる。
 * ハンドルは Vertex が端末へ直接渡すのでサーバには検証しようがない。
 *
 * → **時間で縛る。** 枠を1つ引いた時刻から [RESUME_WINDOW_MINUTES] のあいだは
 *   何度でも繋ぎ直せるが、窓を出たら次は普通に1枠引く。
 *   これで1枠あたりの費用に上限がつく（何回繋ぎ直しても変わらない）。
 */
export const RESUME_WINDOW_MINUTES = MINUTES_PER_SESSION + 2

/**
 * 1つの窓で繋ぎ直せる回数。
 *
 * > [!warning] 時間だけでは縛りきれない
 * > 窓を時間だけで閉じると、**その12分のあいだは何本でも同時に張れる**。
 * > `PER_DEVICE_HOURLY = 80` なので、改造した端末が窓の中で80本の
 * > Live セッションを並行して開くと、1枠のつもりが80枠ぶんの音声代になる。
 * > 「1枠あたりの費用が変わらない」は、**回数も縛って初めて成り立つ**。
 *
 * Vertex は約9分で切るので、12分の窓で必要な繋ぎ直しは多くて1〜2回。
 * 端末側の上限（`maxResumeAttempts = 2`）より1つ多くしてある。
 */
export const MAX_RESUMES_PER_WINDOW = 3

/**
 * 「その日トークンを配った」記録を残す期間（秒）。
 *
 * 枠の判定だけなら2日で足りるが、**チームの貢献の裏取りに使う**ので
 * さかのぼれる期間（[MAX_BACKFILL_DAYS] = 14日）に近づけたい。
 * 8日にしてあるのは、それ以上は容量と実効の釣り合いが悪いため。
 *
 * これより古い日は記録が消えているので、
 * **貢献を捨てはしないが、盛れもしない**（1点に固定する）。
 */
export const SESSION_RECORD_TTL_SECONDS = 8 * 86400

export type QuotaVerdict = {
  /** 会話を始めてよいか */
  granted: boolean
  /** 今日あと何回始められるか（この確保を引いたあと） */
  remainingSessions: number
  /** 課金して上限が外れているか */
  entitled: boolean
  /** 枠が戻る時刻（ISO 8601, UTC） */
  resetsAt: string
  backend: 'kv' | 'memory'
}

function backend(): 'kv' | 'memory' {
  return kvUrl() && kvToken() ? 'kv' : 'memory'
}

/** プロセス内の控え。**インスタンスをまたがないので当てにしない。** */
const local = new Map<string, number>()

async function kv(commands: string[][]): Promise<unknown[]> {
  const res = await fetch(`${kvUrl()}/pipeline`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${kvToken()}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(commands),
  })
  if (!res.ok) throw new Error(`KV エラー: ${res.status}`)
  const out = (await res.json()) as Array<{ result: unknown }>
  return out.map((o) => o.result)
}

/**
 * 日本時間の「今日」で切る。**定義は `day.ts` の1本だけ。**
 * ここに写経すると、チームの集計と食い違ったときに気づけない。
 */
const dayKey = jstDayKey
const nextResetAt = nextJstMidnight

/**
 * 会話を1回ぶん確保する。
 *
 * **先に引いてから渡す。** 渡してから引くと、途中で落ちたときに
 * 使われたのに引かれていない回数が残る。
 */
export async function reserveSession(
  deviceId: string,
  now = Date.now(),
): Promise<QuotaVerdict> {
  const mode = backend()
  const resetsAt = nextResetAt(now)
  const entitled = await isEntitled(deviceId, now)

  // **課金済みでも数える。** 以前はここより前に return していたので、
  // entitled の端末は「その日トークンを配った」記録を1つも持たなかった。
  // チームの貢献はこの記録と突き合わせるので、無いと貢献できなくなる
  const key = `s:${deviceId}:${dayKey(now)}`
  let used: number
  try {
    if (mode === 'kv') {
      const [v] = await kv([
        ['INCR', key],
        ['EXPIRE', key, String(SESSION_RECORD_TTL_SECONDS), 'NX'],
      ])
      used = Number(v ?? 1)
    } else {
      used = (local.get(key) ?? 0) + 1
      local.set(key, used)
    }
  } catch (e) {
    // KV が読めないときは**通す**。締めると障害がそのまま全滅になる。
    // 費用側は全体の1日上限（ratelimit.ts）が別に見ている
    console.error('枠の記録に失敗（通す）', e)
    return {
      granted: true,
      remainingSessions: entitled ? Number.POSITIVE_INFINITY : 0,
      entitled,
      resetsAt,
      backend: mode,
    }
  }

  if (entitled) {
    return {
      granted: true,
      remainingSessions: Number.POSITIVE_INFINITY,
      entitled: true,
      resetsAt,
      backend: mode,
    }
  }

  const over = used > FREE_SESSIONS_PER_DAY
  return {
    granted: !over,
    remainingSessions: Math.max(0, FREE_SESSIONS_PER_DAY - used),
    entitled: false,
    resetsAt,
    backend: mode,
  }
}

/**
 * その日に何回トークンを配ったか。**チームの貢献の裏取りに使う。**
 *
 * 記録が無ければ `undefined`（0 と区別する）。
 * 0 は「その日は一度も会話していない」、
 * undefined は「古すぎて記録が消えた」で、扱いが違う。
 */
export async function sessionsOn(
  deviceId: string,
  day: string,
): Promise<number | undefined> {
  const key = `s:${deviceId}:${day}`
  try {
    const v = backend() === 'kv' ? (await kv([['GET', key]]))[0] : local.get(key)
    return v == null ? undefined : Number(v)
  } catch {
    return undefined
  }
}

/**
 * 枠を引いた直後に開ける「繋ぎ直してよい窓」。
 *
 * 失敗しても投げない。**窓が開かなければ次の再開が1枠引くだけ**で、
 * 生徒が損をする方向にしか転ばない（無料が漏れる方向には転ばない）。
 */
export async function openResumeWindow(deviceId: string, now = Date.now()): Promise<void> {
  const until = now + RESUME_WINDOW_MINUTES * 60_000
  const key = `rw:${deviceId}`
  const count = `rwn:${deviceId}`
  try {
    if (backend() === 'kv') {
      // **回数も戻す。** 戻さないと、2つ目の窓が1つ目の残数を引き継ぐ
      await kv([
        ['SET', key, String(until)],
        ['PEXPIREAT', key, String(until)],
        ['DEL', count],
      ])
    } else {
      local.set(key, until)
      local.delete(count)
    }
  } catch (e) {
    console.error('再開の窓を開けられなかった（次の再開は1枠引く）', e)
  }
}

/**
 * 繋ぎ直しを1回ぶん使う。**窓の中で、まだ回数が残っていれば true。**
 *
 * 見るだけではなく**数える**。時間だけで縛ると、その12分のあいだ
 * 何本でも同時に張れてしまい、1枠の費用が青天井になる。
 *
 * ここは `reserveSession` と逆に、迷ったら**締める**（読めなければ false）。
 * 通してしまうと、KV が落ちている間だけ無料枠が無制限になる。
 * 締めても起きるのは「次の再開が1枠引く」だけで、生徒が損をする方向にしか転ばない。
 */
export async function claimResume(
  deviceId: string,
  now = Date.now(),
): Promise<boolean> {
  const key = `rw:${deviceId}`
  const count = `rwn:${deviceId}`
  try {
    if (backend() === 'kv') {
      const until = Number((await kv([['GET', key]]))[0] ?? 0)
      // 窓の外なら数えない（数えると、窓の外で叩くだけで次の窓を削れる）
      if (!(until > now)) return false
      const [n] = await kv([
        ['INCR', count],
        ['PEXPIREAT', count, String(until)],
      ])
      return Number(n ?? 0) <= MAX_RESUMES_PER_WINDOW
    }
    const until = local.get(key)
    if (until == null || until <= now) return false
    const n = (local.get(count) ?? 0) + 1
    local.set(count, n)
    return n <= MAX_RESUMES_PER_WINDOW
  } catch {
    return false
  }
}

/** 今日あと何回始められるか。**引かずに見るだけ**（画面表示用）。 */
export async function peekRemaining(
  deviceId: string,
  now = Date.now(),
): Promise<{ remainingSessions: number; entitled: boolean; resetsAt: string }> {
  const resetsAt = nextResetAt(now)
  if (await isEntitled(deviceId, now)) {
    return { remainingSessions: Number.POSITIVE_INFINITY, entitled: true, resetsAt }
  }
  const key = `s:${deviceId}:${dayKey(now)}`
  try {
    const used =
      backend() === 'kv' ? Number((await kv([['GET', key]]))[0] ?? 0) : (local.get(key) ?? 0)
    return {
      remainingSessions: Math.max(0, FREE_SESSIONS_PER_DAY - used),
      entitled: false,
      resetsAt,
    }
  } catch {
    return { remainingSessions: FREE_SESSIONS_PER_DAY, entitled: false, resetsAt }
  }
}

/**
 * 課金済みか。
 *
 * > [!warning] 課金の付与はまだ実装していない
 * > レシートの検証には Play Console のサービスアカウントが要り、
 * > アプリが未公開なので用意できない。**いまは誰も entitled にならない。**
 * > 付与の入口は `grantEntitlement` に用意してあるが、
 * > **検証を通さずに呼んではいけない**（端末の申告を信じることになる）。
 */
export async function isEntitled(deviceId: string, now = Date.now()): Promise<boolean> {
  const key = `ent:${deviceId}`
  try {
    const v = backend() === 'kv' ? (await kv([['GET', key]]))[0] : local.get(key)
    if (v == null) return false
    return Number(v) > now
  } catch {
    return false
  }
}

/**
 * 課金の付与。**検証済みのレシートからのみ呼ぶこと。**
 * 端末が「買った」と言ってきたのを信じて呼んではいけない。
 */
export async function grantEntitlement(
  deviceId: string,
  expiresAtMs: number,
): Promise<void> {
  const key = `ent:${deviceId}`
  if (backend() === 'kv') {
    await kv([
      ['SET', key, String(expiresAtMs)],
      ['PEXPIREAT', key, String(expiresAtMs)],
    ])
  } else {
    local.set(key, expiresAtMs)
  }
}
