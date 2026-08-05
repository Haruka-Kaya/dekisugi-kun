import { hasKv, kv } from './kv.js'

/**
 * アンケートの回答を貯める。
 *
 * ## なぜコードを手渡しさせないか
 *
 * 結果コードをコピーさせて回収する経路は動くが、**回収率がそこで決まる**。
 * 中高生に「このコードを送って」と頼む手間は、答えることそのものより重い。
 * リンクを開いて答えたら終わり、にする。
 *
 * ## 保存先
 *
 * 会話の枠と同じ Upstash Redis。**保存先を増やさない。**
 * 増やすたびに「どれが本物でどれが空か」を確かめる場所が増える。
 *
 * `RPUSH` の1件1JSON。件数が数千に収まる規模なので、
 * `LRANGE` で全部引いて集計できる。
 *
 * > [!warning] 保存できなければ受け取ったことにしない
 * > 200 を返しておいて実は消えている、が最悪。
 * > 保存先が無いときは 503 を返し、ブラウザはコード表示に落ちる。
 */

/** 受け付けるアンケートの種類。**知らない種類は保存しない**（ゴミ置き場にしない） */
export const SURVEY_KINDS = ['misconception', 'type'] as const
export type SurveyKind = (typeof SURVEY_KINDS)[number]

/** 1件の上限。自由記述2問なので十分すぎる */
export const MAX_BYTES = 64 * 1024

/** 1つの種類あたりの保存上限。**超えたら受けない**（青天井にしない） */
export const MAX_RESPONSES = 5000

export function isSurveyKind(v: unknown): v is SurveyKind {
  return typeof v === 'string' && (SURVEY_KINDS as readonly string[]).includes(v)
}

const listKey = (kind: SurveyKind) => `survey:${kind}`

export type SaveResult =
  | { ok: true; count: number }
  | { ok: false; reason: 'no_store' | 'full' }

/** 1件を貯める。**保存できたときだけ ok。** */
export async function saveResponse(
  kind: SurveyKind,
  json: string,
): Promise<SaveResult> {
  if (!hasKv()) return { ok: false, reason: 'no_store' }

  const [len] = await kv([['LLEN', listKey(kind)]])
  if (Number(len ?? 0) >= MAX_RESPONSES) return { ok: false, reason: 'full' }

  const [count] = await kv([['RPUSH', listKey(kind), json]])
  return { ok: true, count: Number(count ?? 0) }
}

/** 集計用にまとめて取り出す。 */
export async function listResponses(kind: SurveyKind): Promise<string[]> {
  if (!hasKv()) return []
  const [rows] = await kv([['LRANGE', listKey(kind), '0', '-1']])
  return Array.isArray(rows) ? rows.filter((r): r is string => typeof r === 'string') : []
}

/**
 * その種類の回答を全部捨てる。**配る前の試し投稿を片づけるためのもの。**
 *
 * 集めたあとに誤って呼ぶと戻せないので、
 * 呼び出し側で件数を突き合わせてから実行する。
 */
export async function clearResponses(kind: SurveyKind): Promise<number> {
  if (!hasKv()) return 0
  const before = await countResponses(kind)
  await kv([['DEL', listKey(kind)]])
  return before
}

export async function countResponses(kind: SurveyKind): Promise<number> {
  if (!hasKv()) return 0
  const [len] = await kv([['LLEN', listKey(kind)]])
  return Number(len ?? 0)
}

/**
 * 同じ相手からの連投を抑える。**本人確認ではない。**
 *
 * アンケートは匿名で、端末トークンも配らない。
 * ここでできるのは「1つの経路から短時間に何十件も来るのを止める」ことだけで、
 * 真面目に複数人が同じ回線から答える場合も同じ扱いになる。
 * だから**上限はゆるく**する（教室から一斉に答える場面を壊さないため）。
 */
export async function tooManyFrom(ip: string, now = Date.now()): Promise<boolean> {
  if (!hasKv() || !ip) return false
  const key = `survey:ip:${ip}:${Math.floor(now / 3600_000)}`
  const [n] = await kv([['INCR', key]])
  await kv([['EXPIRE', key, '3600']])
  return Number(n ?? 0) > 60
}
