import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

import {
  computeCoverage,
  emptyDossier,
  gaps,
  nextProbe,
  toReview,
  type Dossier,
  type Slot,
} from '../lib/dossier.js'
import { MISCONCEPTIONS, misconceptionsFor } from '../lib/misconceptions.js'
import { UNITS, sectionFor, unitById, validateCatalog } from '../lib/units.js'

const UNIT = unitById('force-motion')!

function withSlot(d: Dossier, key: string, patch: Partial<Slot>): Dossier {
  return { ...d, slots: d.slots.map((s) => (s.key === key ? { ...s, ...patch } : s)) }
}

describe('カタログ', () => {
  it('概念と誤概念の対応が取れている', () => {
    // 対応する誤概念が無い概念は誘発できず、観測手段が無いまま出荷される
    assert.deepEqual(validateCatalog(), [])
  })

  it('すべての誤概念に固定の lure がある', () => {
    // 文言を毎回 LLM に作らせると、訂正されたかの観測が別々の試行になる
    for (const m of MISCONCEPTIONS) {
      assert.ok(m.lure.length > 5, `${m.id} の lure が短すぎる`)
      assert.ok(m.correct.length > 10, `${m.id} の correct が短すぎる`)
    }
  })

  it('lure は断定せず問いかけになっている', () => {
    // 断定すると訂正しにくくなり、観測が誘導になる
    for (const m of MISCONCEPTIONS) {
      assert.match(m.lure, /[?？]$/, `${m.id} が問いかけで終わっていない: ${m.lure}`)
    }
  })

  it('単元IDが重複していない', () => {
    const ids = UNITS.map((u) => u.id)
    assert.equal(new Set(ids).size, ids.length)
  })
})

describe('教材', () => {
  it('すべての概念に読む教材がある', () => {
    // 無いと、復習が「ここが薄い」と言えても読み直す先を出せない
    for (const u of UNITS) {
      for (const c of u.concepts) {
        assert.ok(
          sectionFor(u, c.key),
          `${u.id}/${c.key} に教材が無い`,
        )
      }
    }
  })

  it('教材に AI が言うセリフがそのまま入っていない', () => {
    // 端末に配るので、覗ける。lure が読めると誘発が成立しない
    const all = UNITS.flatMap((u) => u.sections.flatMap((s) => [...s.body, s.tryIt])).join('\n')
    for (const m of MISCONCEPTIONS) {
      assert.ok(!all.includes(m.lure), `${m.id} の lure が教材に載っている`)
    }
  })

  it('読み物として最低限の量がある', () => {
    for (const u of UNITS) {
      for (const s of u.sections) {
        assert.ok(s.body.length >= 3, `${u.id}/${s.conceptKey} の段落が少なすぎる`)
        const chars = s.body.join('').length
        assert.ok(chars >= 150, `${u.id}/${s.conceptKey} が短すぎる（${chars}字）`)
        // 長すぎると説明フェーズの前に読み切れない。1節2分をめやすにする
        assert.ok(chars <= 700, `${u.id}/${s.conceptKey} が長すぎる（${chars}字）`)
        assert.ok(s.tryIt.length > 10, `${u.id}/${s.conceptKey} に tryIt が無い`)
      }
    }
  })

  it('強調の印が閉じている', () => {
    // 端末は `**…**` だけを太字にする。閉じ忘れると記号が画面に出る
    // （実機で `**落ちる速さは重さによらない**` がそのまま表示された）
    for (const u of UNITS) {
      for (const s of u.sections) {
        for (const line of [...s.body, s.tryIt]) {
          const marks = (line.match(/\*\*/g) ?? []).length
          assert.equal(marks % 2, 0, `${u.id}/${s.conceptKey}: 強調が閉じていない: ${line}`)
          assert.ok(!line.includes('****'), `${u.id}/${s.conceptKey}: 空の強調がある`)
        }
      }
    }
  })

  it('教材が存在しない概念を指していない', () => {
    for (const u of UNITS) {
      const keys = new Set(u.concepts.map((c) => c.key))
      for (const s of u.sections) {
        assert.ok(keys.has(s.conceptKey), `${u.id}: ${s.conceptKey} は概念に無い`)
      }
    }
  })
})

describe('emptyDossier', () => {
  it('概念ごとに誤概念の枠を用意する', () => {
    const d = emptyDossier('force-motion')
    assert.equal(d.slots.length, UNIT.concepts.length)
    for (const s of d.slots) {
      assert.equal(s.status, 'untouched')
      assert.equal(s.probes.length, misconceptionsFor(s.key).length)
      assert.ok(s.probes.every((p) => p.result === 'notTried'))
    }
  })

  it('画面表示用のラベルを持つ（端末にカタログを持たせないため）', () => {
    const d = emptyDossier('force-motion')
    assert.ok(d.slots.every((s) => s.label.length > 0))
  })

  it('未知の単元では落とす', () => {
    assert.throws(() => emptyDossier('nope'))
  })
})

describe('computeCoverage', () => {
  it('空なら 0', () => {
    assert.equal(computeCoverage(emptyDossier('force-motion')), 0)
  })

  it('根拠が無ければ explained でも 0 点', () => {
    // 「説明できた」と書いてあっても、どの発話でそう言ったか示せないなら数えない
    const d = withSlot(emptyDossier('force-motion'), 'fall', {
      status: 'explained',
      content: 'なんか説明した',
      evidence: [],
    })
    assert.equal(computeCoverage(d), 0)
  })

  it('根拠があれば重みに応じて上がる', () => {
    const d = withSlot(emptyDossier('force-motion'), 'fall', {
      status: 'explained',
      evidence: ['u01'],
    })
    // fall の weight=3 / 合計 3+3+2+2=10 → 30%
    assert.equal(computeCoverage(d), 30)
  })

  it('thin は半分', () => {
    const d = withSlot(emptyDossier('force-motion'), 'fall', {
      status: 'thin',
      evidence: ['u01'],
    })
    assert.equal(computeCoverage(d), 15)
  })
})

describe('gaps', () => {
  it('薄いものを先に、同じなら重いものを先に返す', () => {
    let d = emptyDossier('force-motion')
    d = withSlot(d, 'fall', { status: 'thin', evidence: ['u01'] })
    const order = gaps(d, UNIT).map((s) => s.key)
    assert.equal(order[order.length - 1], 'fall', '薄いだけの概念が先頭に来ている')
    // untouched のうち weight 3 の inertia が先
    assert.equal(order[0], 'inertia')
  })

  it('根拠のない explained は埋まっていない扱い', () => {
    const d = withSlot(emptyDossier('force-motion'), 'fall', {
      status: 'explained',
      evidence: [],
    })
    assert.ok(gaps(d, UNIT).some((s) => s.key === 'fall'))
  })
})

describe('nextProbe', () => {
  it('説明が済んでいない概念では誘発しない', () => {
    // 説明の前に誤概念を出すと、生徒は自分の説明ではなくこちらの誘導に答えるだけになる
    assert.equal(nextProbe(emptyDossier('force-motion'), UNIT), null)
  })

  it('説明が済んだ概念の誤概念を返す', () => {
    const d = withSlot(emptyDossier('force-motion'), 'fall', {
      status: 'thin',
      evidence: ['u01'],
    })
    assert.deepEqual(nextProbe(d, UNIT), { conceptKey: 'fall', misconceptionId: 'M01' })
  })

  it('根拠が無ければ誘発しない', () => {
    const d = withSlot(emptyDossier('force-motion'), 'fall', {
      status: 'explained',
      evidence: [],
    })
    assert.equal(nextProbe(d, UNIT), null)
  })

  it('一度誘発したものは繰り返さない', () => {
    let d = emptyDossier('force-motion')
    d = withSlot(d, 'fall', {
      status: 'explained',
      evidence: ['u01'],
      probes: [{ id: 'M01', result: 'corrected', evidence: ['u02'] }],
    })
    assert.equal(nextProbe(d, UNIT), null)
  })

  it('unclear は既定では再試行しない', () => {
    let d = emptyDossier('force-motion')
    d = withSlot(d, 'fall', {
      status: 'explained',
      evidence: ['u01'],
      probes: [{ id: 'M01', result: 'unclear', evidence: [] }],
    })
    assert.equal(nextProbe(d, UNIT), null)
    assert.ok(nextProbe(d, UNIT, { retryUnclear: true }))
  })

  it('重い概念から先に誘発する', () => {
    let d = emptyDossier('force-motion')
    d = withSlot(d, 'friction', { status: 'explained', evidence: ['u01'] }) // weight 2
    d = withSlot(d, 'inertia', { status: 'explained', evidence: ['u02'] }) // weight 3
    assert.equal(nextProbe(d, UNIT)?.conceptKey, 'inertia')
  })
})

describe('toReview', () => {
  it('訂正できなかった概念を含む', () => {
    const d = withSlot(emptyDossier('force-motion'), 'fall', {
      status: 'explained',
      evidence: ['u01'],
      probes: [{ id: 'M01', result: 'accepted', evidence: ['u02'] }],
    })
    assert.deepEqual(toReview(d).map((s) => s.key), ['fall'])
  })

  it('unclear は含めない', () => {
    // 判断がついていないものを「できていない」側に置くと、
    // 触れてもいないことを突きつけることになる
    const d = withSlot(emptyDossier('force-motion'), 'fall', {
      status: 'explained',
      evidence: ['u01'],
      probes: [{ id: 'M01', result: 'unclear', evidence: [] }],
    })
    assert.deepEqual(toReview(d), [])
  })

  it('触れていない概念を含めない', () => {
    // 「まだ」と「できなかった」は別物
    assert.deepEqual(toReview(emptyDossier('force-motion')), [])
  })

  it('説明が薄いままの概念を含む', () => {
    const d = withSlot(emptyDossier('force-motion'), 'fall', {
      status: 'thin',
      evidence: ['u01'],
    })
    assert.deepEqual(toReview(d).map((s) => s.key), ['fall'])
  })
})
