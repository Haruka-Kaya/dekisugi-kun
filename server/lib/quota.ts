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

/** 日本時間の「今日」で切る。UTC で切ると夜9時に枠が戻って不自然。 */
function dayKey(now: number): string {
  return new Date(now + 9 * 3600_000).toISOString().slice(0, 10)
}

function nextResetAt(now: number): string {
  const jst = new Date(now + 9 * 3600_000)
  jst.setUTCHours(0, 0, 0, 0)
  return new Date(jst.getTime() + 24 * 3600_000 - 9 * 3600_000).toISOString()
}

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

  if (await isEntitled(deviceId, now)) {
    return {
      granted: true,
      remainingSessions: Number.POSITIVE_INFINITY,
      entitled: true,
      resetsAt,
      backend: mode,
    }
  }

  const key = `s:${deviceId}:${dayKey(now)}`
  let used: number
  try {
    if (mode === 'kv') {
      const [v] = await kv([
        ['INCR', key],
        ['EXPIRE', key, '172800', 'NX'],
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
    return { granted: true, remainingSessions: 0, entitled: false, resetsAt, backend: mode }
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
 * 枠を引いた直後に開ける「繋ぎ直してよい窓」。
 *
 * 失敗しても投げない。**窓が開かなければ次の再開が1枠引くだけ**で、
 * 生徒が損をする方向にしか転ばない（無料が漏れる方向には転ばない）。
 */
export async function openResumeWindow(deviceId: string, now = Date.now()): Promise<void> {
  const until = now + RESUME_WINDOW_MINUTES * 60_000
  const key = `rw:${deviceId}`
  try {
    if (backend() === 'kv') {
      await kv([
        ['SET', key, String(until)],
        ['PEXPIREAT', key, String(until)],
      ])
    } else {
      local.set(key, until)
    }
  } catch (e) {
    console.error('再開の窓を開けられなかった（次の再開は1枠引く）', e)
  }
}

/**
 * まだ窓の中か。**読めなければ false**。
 *
 * ここは `reserveSession` と逆に、迷ったら**締める**。
 * 通してしまうと、KV が落ちている間だけ無料枠が無制限になる。
 */
export async function withinResumeWindow(
  deviceId: string,
  now = Date.now(),
): Promise<boolean> {
  const key = `rw:${deviceId}`
  try {
    const v = backend() === 'kv' ? (await kv([['GET', key]]))[0] : local.get(key)
    if (v == null) return false
    return Number(v) > now
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
