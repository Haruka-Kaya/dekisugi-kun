/**
 * 無料で使える1日の会話時間。
 *
 * ## なぜ時間で数えるか
 *
 * Gemini Live の費用は**話した時間**にほぼ比例する。回数で数えると、
 * 1回で延々話す人と何度も短く話す人で実費が桁違いになる。
 *
 * ## なぜ端末に回避されないか
 *
 * 会話は一時トークンでしか繋げない（APIキーは端末に無い）。
 * そしてトークンの期限が来ると**セッションごと切られる**
 * （実測: `code=1011 reason=auth token has expired`、発行58秒後）。
 *
 * だから「発行するトークンの寿命 ＝ 与える会話時間」になり、
 * 端末が何を申告しようと超えられない。
 */

const kvUrl = () => process.env.KV_REST_API_URL
const kvToken = () => process.env.KV_REST_API_TOKEN

/** 1日の無料枠。 */
export const FREE_MINUTES_PER_DAY = 15

/**
 * 1回に渡す最大の時間。
 *
 * 長くすると途中の張り直しが減って会話が途切れにくいが、
 * 使い切らずに終わったぶんも消費として引くので短いほど無駄が少ない。
 * 会話1回の実測が数分なので10分にしてある。
 */
export const MAX_BLOCK_MINUTES = 10

/** 意味のある会話にならない長さは渡さない。 */
export const MIN_BLOCK_MINUTES = 2

export type QuotaVerdict = {
  /** 今回渡してよい分数。0 なら渡さない */
  grantedMinutes: number
  /** 今日あと何分使えるか（この発行を引いたあと） */
  remainingMinutes: number
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
 * 会話時間を1ブロック確保する。**確保できた分だけ返す。**
 *
 * 引いてから渡す（先に引く）。渡してから引くと、途中で落ちたときに
 * 使われたのに引かれていない時間が残る。
 */
export async function reserveMinutes(
  deviceId: string,
  now = Date.now(),
): Promise<QuotaVerdict> {
  const mode = backend()
  const entitled = await isEntitled(deviceId, now)
  const resetsAt = nextResetAt(now)

  if (entitled) {
    return {
      grantedMinutes: MAX_BLOCK_MINUTES,
      remainingMinutes: Number.POSITIVE_INFINITY,
      entitled: true,
      resetsAt,
      backend: mode,
    }
  }

  const key = `q:${deviceId}:${dayKey(now)}`
  let used = 0
  try {
    if (mode === 'kv') {
      const [v] = await kv([['GET', key]])
      used = Number(v ?? 0)
    } else {
      used = local.get(key) ?? 0
    }
  } catch (e) {
    // KV が読めないときは**無料枠を渡す**。締めると障害がそのまま全滅になる。
    // 費用側は全体の1日上限（ratelimit.ts）が別に見ている
    console.error('枠の読み出しに失敗（無料枠を渡す）', e)
    return {
      grantedMinutes: MIN_BLOCK_MINUTES,
      remainingMinutes: MIN_BLOCK_MINUTES,
      entitled: false,
      resetsAt,
      backend: mode,
    }
  }

  const left = Math.max(0, FREE_MINUTES_PER_DAY - used)
  if (left < MIN_BLOCK_MINUTES) {
    return { grantedMinutes: 0, remainingMinutes: left, entitled: false, resetsAt, backend: mode }
  }

  const granted = Math.min(left, MAX_BLOCK_MINUTES)
  try {
    if (mode === 'kv') {
      await kv([
        ['INCRBY', key, String(granted)],
        // 日付キーなので、翌々日には消えていてよい
        ['EXPIRE', key, '172800', 'NX'],
      ])
    } else {
      local.set(key, used + granted)
    }
  } catch (e) {
    console.error('枠の記録に失敗（渡すが引けていない）', e)
  }

  return {
    grantedMinutes: granted,
    remainingMinutes: left - granted,
    entitled: false,
    resetsAt,
    backend: mode,
  }
}

/** 今日あと何分使えるか。**引かずに見るだけ**（画面表示用）。 */
export async function peekRemaining(
  deviceId: string,
  now = Date.now(),
): Promise<{ remainingMinutes: number; entitled: boolean; resetsAt: string }> {
  const resetsAt = nextResetAt(now)
  if (await isEntitled(deviceId, now)) {
    return { remainingMinutes: Number.POSITIVE_INFINITY, entitled: true, resetsAt }
  }
  const key = `q:${deviceId}:${dayKey(now)}`
  try {
    const used =
      backend() === 'kv' ? Number((await kv([['GET', key]]))[0] ?? 0) : (local.get(key) ?? 0)
    return {
      remainingMinutes: Math.max(0, FREE_MINUTES_PER_DAY - used),
      entitled: false,
      resetsAt,
    }
  } catch {
    return { remainingMinutes: FREE_MINUTES_PER_DAY, entitled: false, resetsAt }
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
    const v =
      backend() === 'kv' ? (await kv([['GET', key]]))[0] : local.get(key)
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
