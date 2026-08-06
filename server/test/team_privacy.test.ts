import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

import {
  MAX_MEMBERS,
  MEMBER_ROUNDING,
  MIN_MEMBERS_FOR_TOTAL,
  buildSummary,
  memberId,
  roundMembers,
} from '../lib/team.js'

/**
 * **「やっていない人を可視化しない」を機械的に守る。**
 *
 * 未達成者を晒す設計は日本の教室では離脱の引き金になる
 * （L@S 2022 は streak 喪失によるアカウント放棄を実例として記録している）。
 *
 * このファイルは独立させてある。**消すと目立つ**ようにするため。
 * 通信を一切しないので、経路を足す前にここだけで守りを固められる。
 */

const DEVICE = 'ffffffff-1111-2222-3333-444444444444'
const SECRET = 'x'.repeat(48)

/** 応答に出てよいキー。**足すときはここも足す**（うっかり増やせない） */
const ALLOWED = new Set([
  'state',
  'teamName',
  'teamTotal',
  'myTotal',
  'memberCount',
  'periodStart',
  'periodEnd',
  'milestones',
  'key',
  'label',
  'reached',
])

/**
 * 個人に近づくキーの形。名前が変わっても引っかかるように形で見る。
 *
 * `name$` にはしない。**`teamName` は個人ではない**（実際に誤検知した）。
 * 人を指す名前だけを拾う。
 */
const SUSPICIOUS =
  /device|deviceId|mid|member(?!Count)|last|active|streak|rank|score|(student|user|display|nick|real|full)name/i

function walkKeys(v: unknown, out: string[] = []): string[] {
  if (Array.isArray(v)) {
    for (const x of v) walkKeys(x, out)
  } else if (v && typeof v === 'object') {
    for (const [k, x] of Object.entries(v)) {
      out.push(k)
      walkKeys(x, out)
    }
  }
  return out
}

const summary = (memberCount: number, teamTotal = 100, myTotal = 7) =>
  buildSummary({
    teamName: '2年A組',
    memberCount,
    teamTotal,
    myTotal,
    periodStart: '2026-08-03',
    periodEnd: '2026-08-09',
  })

describe('個人が可視化されないこと', () => {
  it('応答のキーは許可したものだけ', () => {
    // **新しい欄を足すとここが落ちる。** それが狙い
    for (const n of [2, 5, 30]) {
      for (const k of walkKeys(summary(n))) {
        assert.ok(ALLOWED.has(k), `許可していないキーを返している: ${k}`)
      }
    }
  })

  it('個人に近づくキーが1つも無い', () => {
    for (const k of walkKeys(summary(30))) {
      assert.ok(!SUSPICIOUS.test(k), `個人に近づくキー: ${k}`)
    }
  })

  it('端末IDもメンバーIDも応答に現れない', () => {
    const mid = memberId(DEVICE, SECRET)
    const json = JSON.stringify(summary(30))
    assert.ok(!json.includes(DEVICE), '端末IDが漏れている')
    assert.ok(!json.includes(mid), 'メンバーIDが漏れている')
  })

  it('日別の推移を返さない', () => {
    // 小さいチームでは、日ごとの差分から個人が復元できる。
    // 期間の端（periodStart/End）以外に日付を出さない
    const s = summary(30)
    const dates = JSON.stringify(s).match(/\d{4}-\d{2}-\d{2}/g) ?? []
    assert.equal(dates.length, 2, `日付が2つより多い: ${dates.join(', ')}`)
  })
})

describe('5人未満では合計を出さない', () => {
  it('2人なら引き算で相手の値が割れるので、出さない', () => {
    // teamTotal - myTotal が相手1人の値そのものになる。
    // **丸めでは防げない**ので、サーバが出さない以外の対処が無い
    const s = summary(2, 30, 12)
    assert.equal(s.teamTotal, null)
    assert.equal(s.state, 'pending')
  })

  it('4人まで出さない、5人から出す', () => {
    for (let n = 0; n < MIN_MEMBERS_FOR_TOTAL; n++) {
      assert.equal(summary(n).teamTotal, null, `${n}人で合計を出している`)
    }
    assert.equal(summary(MIN_MEMBERS_FOR_TOTAL).teamTotal, 100)
    assert.equal(summary(MIN_MEMBERS_FOR_TOTAL).state, 'ready')
  })

  it('人数が足りないうちは到達も出さない', () => {
    // 小さいチームでは「到達した」＝特定の誰かが働いた、になる
    assert.deepEqual(summary(3, 500).milestones, [])
    assert.ok(summary(30, 500).milestones.some((m) => m.reached))
  })

  it('自分のぶんは人数に関わらず返す', () => {
    // 自分の値は自分にしか見えないので、隠す理由が無い
    assert.equal(summary(2, 30, 12).myTotal, 12)
  })
})

describe('人数の粒度', () => {
  it('常に5の倍数で、5以上', () => {
    for (let n = 0; n <= MAX_MEMBERS; n++) {
      const r = roundMembers(n)
      assert.equal(r % MEMBER_ROUNDING, 0, `${n}人 → ${r} が5の倍数でない`)
      assert.ok(r >= MIN_MEMBERS_FOR_TOTAL, `${n}人 → ${r} が下限を割った`)
    }
  })

  it('単調非減少（増えたのに減って見えない）', () => {
    let prev = 0
    for (let n = 0; n <= MAX_MEMBERS; n++) {
      const r = roundMembers(n)
      assert.ok(r >= prev, `${n}人で減った: ${prev} → ${r}`)
      prev = r
    }
  })

  it('1人の増減が総和の変化と結びつかない', () => {
    // 実人数をそのまま返すと「誰かが抜けた」が見える
    for (let n = MIN_MEMBERS_FOR_TOTAL; n < MAX_MEMBERS; n++) {
      if (roundMembers(n) !== roundMembers(n + 1)) continue
      assert.equal(roundMembers(n), roundMembers(n + 1))
    }
    // 少なくとも一部の隣り合う人数では見分けがつかないこと
    assert.equal(roundMembers(11), roundMembers(12))
  })
})

describe('メンバーID', () => {
  it('端末IDから復元できない形にする', () => {
    const mid = memberId(DEVICE, SECRET)
    assert.notEqual(mid, DEVICE)
    assert.ok(!mid.includes(DEVICE))
    assert.match(mid, /^[0-9a-f]{32}$/)
  })

  it('同じ端末なら同じ（参加の冪等と退出に使う）', () => {
    assert.equal(memberId(DEVICE, SECRET), memberId(DEVICE, SECRET))
  })

  it('別の端末なら別', () => {
    assert.notEqual(memberId(DEVICE, SECRET), memberId('other', SECRET))
  })

  it('鍵を回すと別物になる（緊急停止スイッチとして働く）', () => {
    assert.notEqual(memberId(DEVICE, SECRET), memberId(DEVICE, 'y'.repeat(48)))
  })
})
