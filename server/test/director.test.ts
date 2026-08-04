import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

import { parseInput } from '../api/director.js'
import { runDirector, type DirectorInput, type Generate, type Utterance } from '../lib/director.js'
import { emptyDossier, type Dossier, type Slot } from '../lib/dossier.js'
import { misconceptionById } from '../lib/misconceptions.js'

/** モデルの返答を固定する。ネットワークを使わない */
function fixed(raw: unknown): Generate {
  return (async () => raw) as Generate
}

const U: Utterance[] = [
  { id: 'u01', speaker: 'ai', text: '落下って何ですか？' },
  { id: 'u02', speaker: 'student', text: '重さは関係なくて、同時に落ちるよ' },
  { id: 'u03', speaker: 'ai', text: 'えっと、重いものの方が速く落ちるってこと？' },
  { id: 'u04', speaker: 'student', text: 'ちがうよ、空気の抵抗がなければ同じ' },
]

function input(dossier: Dossier, over: Partial<DirectorInput> = {}): DirectorInput {
  return { dossier, utterances: U, secondsLeft: 600, turnCount: 2, ...over }
}

function slot(d: Dossier, key: string): Slot {
  return d.slots.find((s) => s.key === key)!
}

function patch(d: Dossier, key: string, p: Partial<Slot>): Dossier {
  return { ...d, slots: d.slots.map((s) => (s.key === key ? { ...s, ...p } : s)) }
}

const EMPTY_RAW = {
  corrections: [],
  slots: [],
  probeUpdates: [],
  nextInstruction: '次を聞いて',
  shouldEnd: false,
  endReason: '',
}

describe('カルテの引き継ぎ', () => {
  it('根拠を書き忘れただけで既存の内容を空に戻さない', async () => {
    // jiyu-kenkyu-ai の実測で、これが無いと充足度が 56%→31% まで戻り
    // 同じことを何度も説明させることになった
    const before = patch(emptyDossier('force-motion'), 'fall', {
      status: 'explained',
      content: '重さによらない',
      evidence: ['u02'],
    })

    const out = await runDirector(input(before), {
      generate: fixed({
        ...EMPTY_RAW,
        slots: [
          { key: 'fall', status: 'untouched', content: '', evidence: [], followUpHint: 'もう一度' },
        ],
      }),
    })

    const fall = slot(out.dossier, 'fall')
    assert.equal(fall.status, 'explained')
    assert.equal(fall.content, '重さによらない')
    assert.deepEqual(fall.evidence, ['u02'])
  })

  it('根拠が増えているのに格下げしてきたら前の評価を保つ', async () => {
    const before = patch(emptyDossier('force-motion'), 'fall', {
      status: 'explained',
      content: 'A',
      evidence: ['u02'],
    })

    const out = await runDirector(input(before), {
      generate: fixed({
        ...EMPTY_RAW,
        slots: [{ key: 'fall', status: 'thin', content: 'B', evidence: ['u04'], followUpHint: '' }],
      }),
    })

    const fall = slot(out.dossier, 'fall')
    assert.equal(fall.status, 'explained')
    assert.deepEqual(fall.evidence, ['u02', 'u04'])
  })

  it('存在しない発話IDを根拠にできない', async () => {
    const out = await runDirector(input(emptyDossier('force-motion')), {
      generate: fixed({
        ...EMPTY_RAW,
        slots: [
          { key: 'fall', status: 'explained', content: 'X', evidence: ['u99'], followUpHint: '' },
        ],
      }),
    })
    assert.equal(slot(out.dossier, 'fall').status, 'untouched')
  })

  it('AI の発話を根拠にできない（生徒が言ったことだけが根拠）', async () => {
    const out = await runDirector(input(emptyDossier('force-motion')), {
      generate: fixed({
        ...EMPTY_RAW,
        slots: [
          { key: 'fall', status: 'explained', content: 'X', evidence: ['u01'], followUpHint: '' },
        ],
      }),
    })
    assert.equal(slot(out.dossier, 'fall').status, 'untouched')
  })

  it('スロットを取りこぼしても落とさない', async () => {
    const out = await runDirector(input(emptyDossier('force-motion')), {
      generate: fixed(EMPTY_RAW),
    })
    assert.equal(out.dossier.slots.length, 4)
  })

  it('校正も実在する生徒の発話IDに限る', async () => {
    const out = await runDirector(input(emptyDossier('force-motion')), {
      generate: fixed({
        ...EMPTY_RAW,
        corrections: [
          { id: 'u02', corrected: '直した' },
          { id: 'u99', corrected: '幽霊' },
          { id: 'u01', corrected: 'AIの発話' },
        ],
      }),
    })
    assert.deepEqual(out.corrections, [{ id: 'u02', corrected: '直した' }])
  })
})

describe('誘発の判定', () => {
  const probed = () =>
    patch(emptyDossier('force-motion'), 'fall', {
      status: 'explained',
      content: 'A',
      evidence: ['u02'],
      probes: [{ id: 'M01', result: 'unclear', evidence: [] }],
    })

  it('根拠があれば corrected を採用する', async () => {
    const out = await runDirector(input(probed()), {
      generate: fixed({
        ...EMPTY_RAW,
        probeUpdates: [{ id: 'M01', result: 'corrected', evidence: ['u04'] }],
      }),
    })
    assert.equal(slot(out.dossier, 'fall').probes[0].result, 'corrected')
  })

  it('根拠のない accepted を通さない', async () => {
    // accepted は「生徒が誤解している」という強い主張。
    // 根拠なしで通すと、触れてもいない誤解を弱点として突きつけることになる
    const out = await runDirector(input(probed()), {
      generate: fixed({
        ...EMPTY_RAW,
        probeUpdates: [{ id: 'M01', result: 'accepted', evidence: [] }],
      }),
    })
    assert.equal(slot(out.dossier, 'fall').probes[0].result, 'unclear')
  })

  it('口にしていない誤概念の判定は捨てる', async () => {
    // 言ってもいない主張を「訂正された」と書いてくることがある
    const before = patch(emptyDossier('force-motion'), 'fall', {
      status: 'explained',
      evidence: ['u02'],
    })
    const out = await runDirector(input(before), {
      generate: fixed({
        ...EMPTY_RAW,
        probeUpdates: [{ id: 'M01', result: 'corrected', evidence: ['u04'] }],
      }),
    })
    assert.equal(slot(out.dossier, 'fall').probes[0].result, 'notTried')
  })

  it('決まった判定を unclear に戻さない', async () => {
    const before = patch(emptyDossier('force-motion'), 'fall', {
      status: 'explained',
      evidence: ['u02'],
      probes: [{ id: 'M01', result: 'corrected', evidence: ['u04'] }],
    })
    const out = await runDirector(input(before), {
      generate: fixed({
        ...EMPTY_RAW,
        probeUpdates: [{ id: 'M01', result: 'unclear', evidence: ['u02'] }],
      }),
    })
    assert.equal(slot(out.dossier, 'fall').probes[0].result, 'corrected')
  })
})

describe('次の指示', () => {
  it('説明が済んだらカタログの lure をそのまま言わせる', async () => {
    // 文言を LLM に作らせない。毎回違う言い方だと観測が別々の試行になる
    const before = patch(emptyDossier('force-motion'), 'fall', {
      status: 'explained',
      evidence: ['u02'],
    })
    const out = await runDirector(input(before), { generate: fixed(EMPTY_RAW) })

    assert.equal(out.lureId, 'M01')
    assert.ok(out.nextInstruction.includes(misconceptionById('M01')!.lure))
  })

  it('説明前は誘発せず、モデルの指示をそのまま使う', async () => {
    const out = await runDirector(input(emptyDossier('force-motion')), {
      generate: fixed({ ...EMPTY_RAW, nextInstruction: '落下について説明してもらって' }),
    })
    assert.equal(out.lureId, null)
    assert.equal(out.nextInstruction, '落下について説明してもらって')
  })

  it('訂正できなかったら正しい内容を差し出す（C3）', async () => {
    const before = patch(emptyDossier('force-motion'), 'fall', {
      status: 'explained',
      evidence: ['u02'],
      probes: [{ id: 'M01', result: 'accepted', evidence: ['u04'] }],
    })
    const out = await runDirector(input(before), { generate: fixed(EMPTY_RAW) })

    assert.equal(out.lureId, null)
    assert.ok(out.nextInstruction.includes(misconceptionById('M01')!.correct))
    // 「間違っている」と言わせない
    assert.ok(out.nextInstruction.includes('間違っていると言わないこと'))
  })

  it('訂正の差し出しは一度きり（毎ターン繰り返さない）', async () => {
    const before = patch(emptyDossier('force-motion'), 'fall', {
      status: 'explained',
      evidence: ['u02'],
      probes: [{ id: 'M01', result: 'accepted', evidence: ['u04'] }],
    })
    const first = await runDirector(input(before), { generate: fixed(EMPTY_RAW) })
    assert.ok(first.nextInstruction.includes('確かめて'))

    const second = await runDirector(input(first.dossier), {
      generate: fixed({ ...EMPTY_RAW, nextInstruction: '次の概念へ' }),
    })
    assert.equal(second.nextInstruction, '次の概念へ')
  })

  it('終了時は指示を出さない', async () => {
    const out = await runDirector(input(emptyDossier('force-motion')), {
      generate: fixed({ ...EMPTY_RAW, shouldEnd: true, endReason: '一通り終わった' }),
    })
    assert.equal(out.nextInstruction, '')
    assert.equal(out.lureId, null)
  })
})

describe('打ち切り', () => {
  it('時間切れならモデルの判断に関わらず終わる', async () => {
    const out = await runDirector(input(emptyDossier('force-motion'), { secondsLeft: 0 }), {
      generate: fixed(EMPTY_RAW),
    })
    assert.equal(out.shouldEnd, true)
    assert.equal(out.endReason, '時間切れ')
  })

  it('往復数の上限で終わる', async () => {
    const out = await runDirector(input(emptyDossier('force-motion'), { turnCount: 999 }), {
      generate: fixed(EMPTY_RAW),
    })
    assert.equal(out.shouldEnd, true)
    assert.match(out.endReason, /往復に達した/)
  })
})

describe('parseInput', () => {
  it('カルテが無ければ空から始める', () => {
    const got = parseInput({ unitId: 'force-motion', utterances: [] })
    assert.ok('dossier' in got)
    assert.equal(got.dossier.slots.length, 4)
  })

  it('未知の単元を弾く', () => {
    assert.deepEqual(parseInput({ unitId: 'nope' }), {
      error: 'unknown_unit',
      detail: 'nope',
    })
  })

  it('単元の指定が無ければ弾く', () => {
    assert.deepEqual(parseInput({ utterances: [] }), { error: 'unit_required' })
  })

  it('壊れた発話を弾く（LLM を呼ぶ前に落とす）', () => {
    const got = parseInput({
      unitId: 'force-motion',
      utterances: [{ id: 'u01', speaker: 'guardian', text: 'x' }],
    })
    assert.deepEqual(got, { error: 'invalid_utterance' })
  })

  it('発話が多すぎたら弾く', () => {
    const many = Array.from({ length: 201 }, (_, i) => ({
      id: `u${i}`,
      speaker: 'student' as const,
      text: 'x',
    }))
    assert.deepEqual(parseInput({ unitId: 'force-motion', utterances: many }), {
      error: 'too_many_utterances',
    })
  })

  it('空の body を弾く', () => {
    assert.deepEqual(parseInput(null), { error: 'empty_body' })
  })
})
