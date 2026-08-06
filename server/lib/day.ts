/**
 * 日本時間の「日」。
 *
 * **UTC で切らない。** UTC の 0 時は日本の朝 9 時なので、
 * 枠が夜9時に戻ったり、朝に日付が変わったりして生徒の実感と合わない。
 *
 * ここに集約しているのは、**「今日」の定義が2つあると必ずずれる**から。
 * 枠（`quota.ts`）とチームの集計（`team.ts`）が別々に日付を切ると、
 * 「枠は昨日ぶんなのに貢献は今日ぶん」という食い違いが起きる。
 */

const JST_OFFSET_MS = 9 * 3600_000

/** `YYYY-MM-DD`（日本時間）。 */
export function jstDayKey(now: number): string {
  return new Date(now + JST_OFFSET_MS).toISOString().slice(0, 10)
}

/** 次に日付が変わる時刻（ISO 8601, UTC）。 */
export function nextJstMidnight(now: number): string {
  const jst = new Date(now + JST_OFFSET_MS)
  jst.setUTCHours(0, 0, 0, 0)
  return new Date(jst.getTime() + 24 * 3600_000 - JST_OFFSET_MS).toISOString()
}

/** `YYYY-MM-DD` の形をしているか。**中身の妥当性も見る**（2026-13-45 を弾く）。 */
export function isValidDay(v: unknown): v is string {
  if (typeof v !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(v)) return false
  const t = Date.parse(`${v}T00:00:00Z`)
  if (Number.isNaN(t)) return false
  // Date.parse は 2026-02-31 を 3/3 に丸める。**戻して一致するかで確かめる**
  return new Date(t).toISOString().slice(0, 10) === v
}

/** 日キーどうしの差（日数）。[from] を含まない。 */
export function daysBetween(from: string, to: string): number {
  const a = Date.parse(`${from}T00:00:00Z`)
  const b = Date.parse(`${to}T00:00:00Z`)
  return Math.round((b - a) / 86_400_000)
}

/** その日が属する週の月曜（日本時間）。**月曜はじまり。** */
export function jstWeekKey(day: string): string {
  const t = Date.parse(`${day}T00:00:00Z`)
  const d = new Date(t)
  // getUTCDay は日曜=0。月曜=0 に直す
  const offset = (d.getUTCDay() + 6) % 7
  return new Date(t - offset * 86_400_000).toISOString().slice(0, 10)
}
