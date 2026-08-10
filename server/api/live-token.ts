import { bearer, type Req, type Res } from '../lib/http.js'
import { verifyToken } from '../lib/auth.js'
import { createLiveGrant } from '../lib/live-token.js'
import {
  MINUTES_PER_SESSION,
  claimResume,
  openResumeWindow,
  peekRemaining,
  reserveSession,
} from '../lib/quota.js'
import { envLang, parseLang } from '../lib/i18n.js'
import { checkRate } from '../lib/ratelimit.js'
import { isMissionKind, isTeachingTactic } from '../lib/mission.js'
import { focusUnit, unitById } from '../lib/units.js'
import { generativeAiEnabled } from '../lib/generative-ai.js'

type LiveTokenDeps = {
  checkRate: typeof checkRate
  claimResume: typeof claimResume
  createLiveGrant: typeof createLiveGrant
  openResumeWindow: typeof openResumeWindow
  peekRemaining: typeof peekRemaining
  reserveSession: typeof reserveSession
}

const defaultDeps: LiveTokenDeps = {
  checkRate,
  claimResume,
  createLiveGrant,
  openResumeWindow,
  peekRemaining,
  reserveSession,
}

/** 本文が文字列で来ることがある。壊れていても 500 にしない */
function safeJson(raw: string): unknown {
  try {
    return JSON.parse(raw)
  } catch {
    return undefined
  }
}

/**
 * 会話を始めるための資格情報を渡す。
 *
 * **Vertex の鍵はここにしか無い。** 端末が持つのは期限つきのアクセストークンだけ。
 *
 * 1セッションは **Vertex 自身が約10分で打ち切る**（実測 `code=1000`）ので、
 * 1回渡す = 約10分の会話。枠は**セッション数**で数える。
 *
 * GET  … 今日あと何回始められるか（引かずに見るだけ。画面表示用）
 * POST … 1回ぶん確保して資格情報を渡す
 */

/** テストでは外部処理を差し替え、停止中に一度も到達しないことを検証する。 */
export function liveTokenHandler(overrides: Partial<LiveTokenDeps> = {}) {
  const deps: LiveTokenDeps = { ...defaultDeps, ...overrides }
  return async function handler(req: Req, res: Res) {
    if (req.method !== 'POST' && req.method !== 'GET') {
      res.setHeader('Allow', 'GET, POST')
      res.status(405).json({ error: 'method_not_allowed' })
      return
    }

    const auth = verifyToken(bearer(req))
    if (!auth.ok) {
      res.status(401).json({
        error: auth.reason === 'expired' ? 'token_expired' : 'unauthorized',
      })
      return
    }
    const deviceId = auth.token.did

    // 認証の有無は隠さない一方、認証後は入力解析・rate・quota・Googleより先に止める。
    // 旧版や改造クライアントも、このサーバから資格情報やDirector応答を得られない。
    if (!generativeAiEnabled()) {
      res.status(503).json({ error: 'generative_ai_unavailable' })
      return
    }

    if (req.method === 'GET') {
      const left = await deps.peekRemaining(deviceId)
      res.status(200).json({
        remainingSessions: Number.isFinite(left.remainingSessions)
          ? left.remainingSessions
          : null,
        minutesPerSession: MINUTES_PER_SESSION,
        entitled: left.entitled,
        resetsAt: left.resetsAt,
      })
      return
    }

    // **単元は枠を引く前に確かめる。** 引いてから弾くと、
    // 会話していないのに1回ぶん減る
    const body = typeof req.body === 'string' ? safeJson(req.body) : req.body
    const requestBody = body as Record<string, unknown> | undefined
    const unitId = requestBody?.unitId
    const unit = typeof unitId === 'string' ? unitById(unitId) : undefined
    if (typeof unitId !== 'string' || !unit) {
      res.status(400).json({ error: 'unknown_unit' })
      return
    }

    // **概念も rate / quota を使う前に確かめる。**
    // 指定があるのに壊れている場合、単元全体へ黙って戻してはいけない。
    // 教材で1概念しか読んでいない生徒へ、別概念の質問が始まってしまう。
    const hasFocus = Object.hasOwn(requestBody ?? {}, 'focusConceptKey')
    const rawFocus = requestBody?.focusConceptKey
    if (hasFocus && typeof rawFocus !== 'string') {
      res.status(400).json({ error: 'unknown_concept' })
      return
    }
    const focusConceptKey = typeof rawFocus === 'string' ? rawFocus : undefined
    if (!focusUnit(unit, focusConceptKey)) {
      res
        .status(400)
        .json({ error: 'unknown_concept', detail: focusConceptKey })
      return
    }

    // ミッション種別もrate/quotaを使う前にallowlist検証する。
    // 未指定は旧クライアント互換のteach。
    const hasMissionKind = Object.hasOwn(requestBody ?? {}, 'missionKind')
    const rawMissionKind = requestBody?.missionKind
    if (hasMissionKind && !isMissionKind(rawMissionKind)) {
      res.status(400).json({ error: 'unknown_mission_kind' })
      return
    }
    const missionKind =
      hasMissionKind && isMissionKind(rawMissionKind) ? rawMissionKind : 'teach'
    if (missionKind !== 'teach' && focusConceptKey == null) {
      res.status(400).json({ error: 'focus_required' })
      return
    }

    // 作戦もrate/quotaより前にallowlist検証する。未指定だけは旧client互換のreason。
    // 明示nullを未指定扱いすると、壊れた選択状態を黙って別の会話へ変えてしまう。
    const hasTeachingTactic = Object.hasOwn(requestBody ?? {}, 'teachingTactic')
    const rawTeachingTactic = requestBody?.teachingTactic
    if (hasTeachingTactic && !isTeachingTactic(rawTeachingTactic)) {
      res.status(400).json({ error: 'unknown_teaching_tactic' })
      return
    }
    const teachingTactic =
      hasTeachingTactic && isTeachingTactic(rawTeachingTactic)
        ? rawTeachingTactic
        : 'reason'

    // 続きから繋ぎ直したいという申し出。
    // **ハンドルの中身は検証できない**（Vertex が端末へ直接渡すので
    // サーバは一度も見ていない）。信じてよいのは「窓の中かどうか」だけ
    const rawHandle = (body as { resumeHandle?: unknown } | undefined)
      ?.resumeHandle
    const resumeHandle =
      typeof rawHandle === 'string' &&
      rawHandle.length > 0 &&
      rawHandle.length <= 4096
        ? rawHandle
        : undefined

    // 端末が明示していればそれが勝つ。無ければ環境変数の既定（デモ用の逃げ道）
    const body2 = body as { lang?: unknown } | undefined
    const lang = body2?.lang == null ? envLang() : parseLang(body2.lang)

    // 濫用の歯止め。**Vertex を呼ぶ前に落とす**
    const rate = await deps.checkRate(deviceId)
    res.setHeader('X-RateLimit-Backend', rate.backend)
    if (!rate.ok) {
      res.setHeader('Retry-After', String(rate.retryAfterSeconds))
      res
        .status(429)
        .json({ error: 'rate_limited', retryAfter: rate.retryAfterSeconds })
      return
    }

    // 窓の中の繋ぎ直しは枠を引かない。
    // **窓は時間と回数の両方で閉じる。** 時間だけだと、その12分のあいだ
    // 何本でも同時に張れてしまい、1枠のつもりが何十枠ぶんの音声代になる
    const resuming = resumeHandle != null && (await deps.claimResume(deviceId))

    let quota
    if (resuming) {
      const left = await deps.peekRemaining(deviceId)
      quota = {
        granted: true,
        remainingSessions: left.remainingSessions,
        entitled: left.entitled,
        resetsAt: left.resetsAt,
        backend: 'kv' as const,
      }
    } else {
      // **先に引いてから渡す。** 渡してから引くと、途中で落ちたときに
      // 使われたのに引かれていない回数が残る
      quota = await deps.reserveSession(deviceId)
    }
    res.setHeader('X-Quota-Backend', quota.backend)
    res.setHeader('X-Resumed', resuming ? '1' : '0')
    if (!quota.granted) {
      res.status(402).json({
        error: 'quota_exhausted',
        remainingSessions: 0,
        resetsAt: quota.resetsAt,
      })
      return
    }

    // **枠を引いた時点で窓を開ける。**
    // 資格情報の作成に失敗しても開ける — 引かれたのに繋ぎ直せないのは理不尽。
    // 繋ぎ直しでは開け直さない。開け直すと窓が閉じなくなり、時間の縛りが消える
    if (!resuming) await deps.openResumeWindow(deviceId)

    try {
      // 窓の外で送られたハンドルは**使わない**。
      // 使うと「枠は引いたのに前の会話の続き」という中途半端な状態になる
      const grant = await deps.createLiveGrant(
        unitId,
        resuming ? resumeHandle : undefined,
        lang,
        focusConceptKey,
        { missionKind, teachingTactic },
      )
      res.status(200).json({
        ...grant,
        remainingSessions: Number.isFinite(quota.remainingSessions)
          ? quota.remainingSessions
          : null,
        entitled: quota.entitled,
        resetsAt: quota.resetsAt,
      })
    } catch (e) {
      // 中身は返さない。資格情報の断片が混ざりうる
      console.error('会話の資格情報を作れなかった', e)
      res.status(502).json({ error: 'grant_failed' })
    }
  }
}

export default liveTokenHandler()
