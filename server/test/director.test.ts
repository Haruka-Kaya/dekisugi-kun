import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

import { parseInput } from '../api/director.js'
import { runDirector, type DirectorInput, type Generate, type Utterance } from '../lib/director.js'
import { emptyDossier, type Dossier, type Slot } from '../lib/dossier.js'
import { localizeMisconception } from '../lib/i18n.js'
import { misconceptionById } from '../lib/misconceptions.js'

/** モデルの返答を固定する。ネットワークを使わない */
function fixed(raw: unknown): Generate {
  return (async () => raw) as Generate
}

const U: Utterance[] = [
  { id: 'u01', speaker: 'ai', text: '落下って何ですか？' },
  { id: 'u02', speaker: 'student', text: '重さは関係なくて、同時に落ちるよ' },
  {
    id: 'u03',
    speaker: 'ai',
    text: 'えっと、じゃあ重いものの方が速く落ちるってこと？',
    challengeLureId: 'M01',
  },
  { id: 'u04', speaker: 'student', text: 'ちがうよ、空気の抵抗がなければ同じ' },
  // 実クライアントは1ターンを student → AI の順でflushしてからDirectorを呼ぶ。
  // 誤概念のAI発話が「最後のAI発話」とは限らないことを固定する。
  { id: 'u05', speaker: 'ai', text: 'あ、空気がないと同じなんですね。' },
]

const BEFORE_CHALLENGE = U.slice(0, 2)

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
    const out = await runDirector(input(emptyDossier('force-motion'), {
      utterances: BEFORE_CHALLENGE,
    }), {
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
  const untried = () =>
    patch(emptyDossier('force-motion'), 'fall', {
      status: 'explained',
      content: '重さによらない',
      evidence: ['u01'],
    })
  const probed = () =>
    patch(emptyDossier('force-motion'), 'fall', {
      status: 'explained',
      content: 'A',
      evidence: ['u02'],
      probes: [{ id: 'M01', result: 'unclear', evidence: [] }],
    })

  it('M01マーカー付きでも無関係なAI本文ならnotTriedのまま', async () => {
    const utterances: Utterance[] = [
      { id: 'u01', speaker: 'student', text: '重さによらない' },
      { id: 'u02', speaker: 'ai', text: 'なるほど、理由も教えて。', challengeLureId: 'M01' },
    ]
    const out = await runDirector(input(untried(), { utterances, secondsLeft: 0 }), {
      generate: fixed(EMPTY_RAW),
    })

    assert.equal(slot(out.dossier, 'fall').probes[0]!.result, 'notTried')
  })

  it('正規lureが含まれていても前後に自然な言葉を足したAI発話はnotTried', async () => {
    const lure = misconceptionById('M01')!.lure
    for (const text of [`なるほど。${lure}`, `${lure}わかった。`]) {
      const utterances: Utterance[] = [
        { id: 'u01', speaker: 'student', text: '重さによらない' },
        { id: 'u02', speaker: 'ai', text, challengeLureId: 'M01' },
      ]
      const out = await runDirector(input(untried(), { utterances, secondsLeft: 0 }), {
        generate: fixed(EMPTY_RAW),
      })
      assert.equal(slot(out.dossier, 'fall').probes[0]!.result, 'notTried')
    }
  })

  it('M01マーカーと正規lure本文が揃ったときだけunclearに進む', async () => {
    const utterances: Utterance[] = [
      { id: 'u01', speaker: 'student', text: '重さによらない' },
      {
        id: 'u02',
        speaker: 'ai',
        text: 'えっと じゃあ 重い もの の 方 が 速く 落ちる って こと?',
        challengeLureId: 'M01',
      },
    ]
    const out = await runDirector(input(untried(), { utterances, secondsLeft: 0 }), {
      generate: fixed(EMPTY_RAW),
    })

    assert.equal(slot(out.dossier, 'fall').probes[0]!.result, 'unclear')
  })

  it('challenge IDとcatalog本文が食い違うマーカーを無視する', async () => {
    const m01 = misconceptionById('M01')!
    const m02 = misconceptionById('M02')!
    for (const marker of [
      { id: 'M01', text: m02.lure },
      { id: 'M02', text: m01.lure },
    ]) {
      const utterances: Utterance[] = [
        { id: 'u01', speaker: 'student', text: '重さによらない' },
        {
          id: 'u02',
          speaker: 'ai',
          text: marker.text,
          challengeLureId: marker.id,
        },
      ]
      const out = await runDirector(input(untried(), { utterances, secondsLeft: 0 }), {
        generate: fixed(EMPTY_RAW),
      })
      assert.equal(
        slot(out.dossier, 'fall').probes[0]!.result,
        'notTried',
        `${marker.id} に別の本文が紐づいた`,
      )
    }
  })

  it('旧dossierがcorrectedでも正規lure発話が無ければnotTriedへ戻しCLEARを防ぐ', async () => {
    const stale = patch(emptyDossier('force-motion'), 'fall', {
      status: 'explained',
      content: '重さによらない',
      evidence: ['u01'],
      probes: [{ id: 'M01', result: 'corrected', evidence: ['u03'] }],
    })
    const utterances: Utterance[] = [
      { id: 'u01', speaker: 'student', text: '重さによらない' },
      { id: 'u02', speaker: 'ai', text: '関係ない質問', challengeLureId: 'M01' },
      { id: 'u03', speaker: 'student', text: '空気抵抗がなければ同じ' },
    ]
    const out = await runDirector(input(stale, { utterances, secondsLeft: 0 }), {
      generate: fixed(EMPTY_RAW),
    })

    assert.deepEqual(slot(out.dossier, 'fall').probes[0], {
      id: 'M01',
      result: 'notTried',
      evidence: [],
    })
  })

  it('英語catalogでも正規lureの後の根拠付き訂正だけをcorrectedにする', async () => {
    const lure = localizeMisconception(misconceptionById('M01')!, 'en').lure
    const challenge: Utterance[] = [
      { id: 'u01', speaker: 'student', text: 'Weight does not determine falling speed.' },
      {
        id: 'u02',
        speaker: 'ai',
        text: lure.toUpperCase().replace('—', '-').replace(/[?,]/g, ''),
        challengeLureId: 'M01',
      },
    ]
    const first = await runDirector(
      input(untried(), { utterances: challenge, secondsLeft: 0, lang: 'en' }),
      { generate: fixed(EMPTY_RAW) },
    )
    assert.equal(slot(first.dossier, 'fall').probes[0]!.result, 'unclear')

    const corrected = await runDirector(
      input(first.dossier, {
        utterances: [
          ...challenge,
          {
            id: 'u03',
            speaker: 'student',
            text: 'No. Without air resistance, they accelerate equally and land together.',
          },
        ],
        secondsLeft: 0,
        lang: 'en',
      }),
      {
        generate: fixed({
          ...EMPTY_RAW,
          probeUpdates: [{ id: 'M01', result: 'corrected', evidence: ['u03'] }],
        }),
      },
    )
    assert.equal(slot(corrected.dossier, 'fall').probes[0]!.result, 'corrected')
  })

  it('否定に正しい条件を添えた本人の発話なら corrected を採用する', async () => {
    const out = await runDirector(input(probed()), {
      generate: fixed({
        ...EMPTY_RAW,
        probeUpdates: [{ id: 'M01', result: 'corrected', evidence: ['u04'] }],
      }),
    })
    assert.equal(slot(out.dossier, 'fall').probes[0]!.result, 'corrected')
  })

  it('「違う」だけはモデルが corrected としても unclear のままにする', async () => {
    for (const text of [
      '違うよ。',
      'そうじゃない',
      'それは間違っています',
      "That's wrong.",
      "No, that's wrong.",
      'No.',
    ]) {
      const utterances = U.map((utterance) =>
        utterance.id === 'u04' ? { ...utterance, text } : utterance,
      )
      const out = await runDirector(input(probed(), { utterances }), {
        generate: fixed({
          ...EMPTY_RAW,
          probeUpdates: [{ id: 'M01', result: 'corrected', evidence: ['u04'] }],
        }),
      })
      assert.equal(
        slot(out.dossier, 'fall').probes[0]!.result,
        'unclear',
        `否定だけで corrected になった: ${text}`,
      )
    }
  })

  it('LLM校正が否定だけの発話に内容を足しても、次ターンで corrected にしない', async () => {
    const firstUtterances = U.map((utterance) =>
      utterance.id === 'u04' ? { ...utterance, text: '違う' } : utterance,
    )
    const first = await runDirector(input(probed(), { utterances: firstUtterances }), {
      generate: fixed({
        ...EMPTY_RAW,
        corrections: [{ id: 'u04', corrected: '重さに関係なく同時に落ちる' }],
        probeUpdates: [{ id: 'M01', result: 'corrected', evidence: ['u04'] }],
      }),
    })
    assert.equal(slot(first.dossier, 'fall').probes[0]!.result, 'unclear')

    // 実クライアントはDirectorの校正を逐語へ保存し、次ターンで再送する。
    const corrected = first.corrections.find((item) => item.id === 'u04')!.corrected
    const carriedUtterances: Utterance[] = [
      ...firstUtterances.map((utterance) =>
        utterance.id === 'u04' ? { ...utterance, corrected } : utterance,
      ),
      { id: 'u06', speaker: 'ai', text: 'どこが違うの？' },
      { id: 'u07', speaker: 'student', text: 'はい' },
    ]
    const second = await runDirector(
      input(first.dossier, { utterances: carriedUtterances, turnCount: 3 }),
      {
        generate: fixed({
          ...EMPTY_RAW,
          // モデルが内容を足した旧発話を再度根拠にしても、
          // substanceは必ず生の「違う」で判定する。
          probeUpdates: [{ id: 'M01', result: 'corrected', evidence: ['u04'] }],
        }),
      },
    )

    assert.equal(slot(second.dossier, 'fall').probes[0]!.result, 'unclear')
  })

  it('誤概念より前の説明だけを corrected の根拠にできない', async () => {
    const out = await runDirector(input(probed()), {
      generate: fixed({
        ...EMPTY_RAW,
        // u02 は内容を含むが、AI が誤概念を口にした u03 より前
        probeUpdates: [{ id: 'M01', result: 'corrected', evidence: ['u02'] }],
      }),
    })
    assert.equal(slot(out.dossier, 'fall').probes[0]!.result, 'unclear')
  })

  it('challengeマーカーが無ければ旧unclearも捨て、内容つきでも訂正判定を通さない', async () => {
    const utterances = U.map(({ challengeLureId: _, ...utterance }) => utterance)
    const out = await runDirector(input(probed(), { utterances }), {
      generate: fixed({
        ...EMPTY_RAW,
        probeUpdates: [{ id: 'M01', result: 'corrected', evidence: ['u04'] }],
      }),
    })
    assert.equal(slot(out.dossier, 'fall').probes[0]!.result, 'notTried')
  })

  it('SCHEMA と SYSTEM の両方が根拠つき訂正を要求する', async () => {
    let contract = ''
    await runDirector(input(probed()), {
      generate: async (opts) => {
        contract = `${opts.systemInstruction ?? ''}\n${JSON.stringify(opts.schema)}`
        return EMPTY_RAW as never
      },
    })

    assert.ok(contract.includes('正しい内容・成立する条件・そうなる理由'))
    assert.ok(contract.includes('「違う」「そうじゃない」「No」「That\'s wrong」だけ'))
    assert.ok(contract.includes('「違う」だけを含むそれ以外すべて'))
    assert.ok(contract.includes('以前の説明だけを根拠にしない'))
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
    assert.equal(slot(out.dossier, 'fall').probes[0]!.result, 'unclear')
  })

  it('口にしていない誤概念の判定は捨てる', async () => {
    // 言ってもいない主張を「訂正された」と書いてくることがある
    const before = patch(emptyDossier('force-motion'), 'fall', {
      status: 'explained',
      evidence: ['u02'],
    })
    // 時間切れで誘発を止め、mergeProbe の判断だけを見る。
    // model の shouldEnd だけでは、学習の山場を飛ばさないガードにより
    // このターンで M01 を口にして unclear が入る。
    const out = await runDirector(input(before, {
      secondsLeft: 0,
      utterances: BEFORE_CHALLENGE,
    }), {
      generate: fixed({
        ...EMPTY_RAW,
        shouldEnd: true,
        probeUpdates: [{ id: 'M01', result: 'corrected', evidence: ['u04'] }],
      }),
    })
    assert.equal(slot(out.dossier, 'fall').probes[0]!.result, 'notTried')
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
    assert.equal(slot(out.dossier, 'fall').probes[0]!.result, 'corrected')
  })
})

describe('次の指示', () => {
  it('説明が済んだらカタログの lure をそのまま言わせる', async () => {
    // 文言を LLM に作らせない。毎回違う言い方だと観測が別々の試行になる
    const before = patch(emptyDossier('force-motion'), 'fall', {
      status: 'explained',
      evidence: ['u02'],
    })
    const out = await runDirector(input(before, { utterances: BEFORE_CHALLENGE }), {
      generate: fixed(EMPTY_RAW),
    })

    assert.equal(out.lureId, 'M01')
    assert.equal(out.lureText, misconceptionById('M01')!.lure)
    assert.ok(out.nextInstruction.includes(misconceptionById('M01')!.lure))
    assert.match(out.nextInstruction, /一字一句そのまま/)
    assert.match(out.nextInstruction, /前にも後にも言葉を足さない/)
    // 指示しただけでは、まだ口にしていない。
    assert.equal(slot(out.dossier, 'fall').probes[0]!.result, 'notTried')
  })

  it('同じ誤概念を続けて蒸し返さない', async () => {
    // 実機で出た症状: 生徒が訂正した直後に、同じ誤概念をもう一度口にした。
    // 誘発を notTried のまま返していたため、
    //   ① buildPrompt の「すでに口にした誤概念」が空 → 判定が来ない
    //   ② mergeProbe が notTried の更新を捨てる
    //   ③ nextProbe が同じものを選び直す
    // の3つが重なって、訂正しても永久に繰り返された
    const before = patch(emptyDossier('force-motion'), 'fall', {
      status: 'explained',
      evidence: ['u02'],
    })
    const first = await runDirector(input(before, { utterances: BEFORE_CHALLENGE }), {
      generate: fixed(EMPTY_RAW),
    })
    assert.equal(first.lureId, 'M01')

    // Liveが実際にchallengeを発話したマーカーを逐語へ載せる。
    const second = await runDirector(input(first.dossier, { utterances: U }), {
      generate: fixed({ ...EMPTY_RAW, nextInstruction: '次の概念へ' }),
    })
    assert.notEqual(second.lureId, 'M01')
    assert.ok(!second.nextInstruction.includes(misconceptionById('M01')!.lure))
  })

  it('口にしたあとなら生徒の訂正を受け取れる', async () => {
    const before = patch(emptyDossier('force-motion'), 'fall', {
      status: 'explained',
      evidence: ['u02'],
    })
    const first = await runDirector(input(before, { utterances: BEFORE_CHALLENGE }), {
      generate: fixed(EMPTY_RAW),
    })
    const second = await runDirector(input(first.dossier, { utterances: U }), {
      generate: fixed({
        ...EMPTY_RAW,
        probeUpdates: [{ id: 'M01', result: 'corrected', evidence: ['u04'] }],
      }),
    })
    assert.equal(slot(second.dossier, 'fall').probes[0]!.result, 'corrected')
  })

  it('説明前は誘発せず、モデルの指示をそのまま使う', async () => {
    const out = await runDirector(input(emptyDossier('force-motion'), {
      utterances: BEFORE_CHALLENGE,
    }), {
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

  it('説明できた同ターンの終了判断を抑止し、誘発を必ず行う（C9）', async () => {
    const out = await runDirector(input(emptyDossier('force-motion'), {
      utterances: BEFORE_CHALLENGE,
    }), {
      generate: fixed({
        ...EMPTY_RAW,
        slots: [
          {
            key: 'fall',
            status: 'explained',
            content: '重さによらず同時に落ちる',
            evidence: ['u02'],
            followUpHint: '',
          },
        ],
        shouldEnd: true,
        endReason: 'モデルは終わりと判断',
      }),
    })

    assert.equal(out.shouldEnd, false)
    assert.equal(out.endReason, '')
    assert.equal(out.lureId, 'M01')
    assert.ok(out.nextInstruction.includes(misconceptionById('M01')!.lure))
    assert.equal(slot(out.dossier, 'fall').probes[0]!.result, 'notTried')
  })

  it('訂正できなかった同ターンの終了判断を抑止し、正しい代案を必ず出す（C3）', async () => {
    const before = patch(emptyDossier('force-motion'), 'fall', {
      status: 'explained',
      evidence: ['u02'],
      probes: [{ id: 'M01', result: 'unclear', evidence: [] }],
    })
    const out = await runDirector(input(before), {
      generate: fixed({
        ...EMPTY_RAW,
        probeUpdates: [{ id: 'M01', result: 'accepted', evidence: ['u04'] }],
        shouldEnd: true,
        endReason: 'モデルは終わりと判断',
      }),
    })

    assert.equal(out.shouldEnd, false)
    assert.equal(out.endReason, '')
    assert.equal(out.lureId, null)
    assert.ok(out.nextInstruction.includes(misconceptionById('M01')!.correct))
    assert.equal(slot(out.dossier, 'fall').probes[0]!.countered, true)
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

  it('1概念ミッションは6往復で区切る', async () => {
    const before = patch(emptyDossier('force-motion'), 'fall', {
      status: 'explained',
      evidence: ['u02'],
    })
    const out = await runDirector(
      input(before, {
        focusConceptKey: 'fall',
        turnCount: 6,
        utterances: BEFORE_CHALLENGE,
      }),
      { generate: fixed(EMPTY_RAW) },
    )
    assert.equal(out.shouldEnd, true)
    assert.equal(out.endReason, '6往復に達したため')
    assert.equal(out.nextInstruction, '')
    assert.equal(slot(out.dossier, 'fall').probes[0]!.result, 'notTried')
  })

  it('時間切れは未完の学習アクションより優先して終了する', async () => {
    const before = patch(emptyDossier('force-motion'), 'fall', {
      status: 'explained',
      evidence: ['u02'],
    })
    const out = await runDirector(input(before, {
      secondsLeft: 0,
      utterances: BEFORE_CHALLENGE,
    }), {
      generate: fixed({ ...EMPTY_RAW, shouldEnd: true }),
    })

    assert.equal(out.shouldEnd, true)
    assert.equal(out.endReason, '時間切れ')
    assert.equal(out.lureId, null)
    assert.equal(out.nextInstruction, '')
    assert.equal(slot(out.dossier, 'fall').probes[0]!.result, 'notTried')
  })
})

describe('1概念ミッション', () => {
  it('カルテ・プロンプト・モデル出力を対象概念だけへ閉じる', async () => {
    const before = patch(emptyDossier('force-motion'), 'inertia', {
      status: 'explained',
      content: '対象外の慣性の説明',
      evidence: ['u02'],
    })
    let prompt = ''
    const out = await runDirector(
      input(before, { focusConceptKey: 'fall', turnCount: 2 }),
      {
        generate: async (opts) => {
          prompt = opts.prompt
          return {
            ...EMPTY_RAW,
            slots: [
              {
                key: 'inertia',
                status: 'explained',
                content: '混入させようとした内容',
                evidence: ['u02'],
                followUpHint: '',
              },
            ],
          } as never
        },
      },
    )

    assert.deepEqual(out.dossier.slots.map((s) => s.key), ['fall'])
    assert.ok(prompt.includes('fall=落下の速さ'))
    assert.ok(prompt.includes('上限 6 往復'))
    assert.ok(!prompt.includes('inertia'), '対象外のキーがDirectorへ漏れている')
    assert.ok(!prompt.includes('慣性'), '対象外の概念名がDirectorへ漏れている')
    assert.ok(!prompt.includes('対象外の慣性の説明'))
    assert.ok(!prompt.includes('friction'))
    assert.ok(!prompt.includes('throwUp'))
    assert.ok(out.nextInstruction.includes('落下の速さ'))
  })

  it('CASEをDirectorへ伝え、定義だけではexplainedにしない契約を入れる', async () => {
    let prompt = ''
    await runDirector(
      input(emptyDossier('force-motion'), {
        focusConceptKey: 'fall',
        missionKind: 'caseRetry',
      }),
      {
        generate: async (opts) => {
          prompt = opts.prompt
          return EMPTY_RAW as never
        },
      },
    )

    assert.ok(prompt.includes('CASE RETRY'))
    assert.ok(prompt.includes('CASE RETRY: 次の場面の予想と、原因・条件を結びつけて'))
    assert.ok(prompt.includes('同じ紙を2枚用意して'))
    assert.ok(prompt.includes('用語の定義だけならexplainedではなくthin'))
  })

  it('REPAIRをDirectorへ伝え、未決着の説明を組み直す', async () => {
    let prompt = ''
    await runDirector(
      input(emptyDossier('force-motion'), {
        focusConceptKey: 'fall',
        missionKind: 'repair',
      }),
      {
        generate: async (opts) => {
          prompt = opts.prompt
          return EMPTY_RAW as never
        },
      },
    )

    assert.ok(prompt.includes('REPAIR: 前回決着しなかった説明を組み直す'))
    assert.ok(prompt.includes('答えを先回りしない'))
  })

  it('作戦ごとにDirectorの最初の引き出し方が変わる', async () => {
    const prompts = new Map<string, string>()
    for (const teachingTactic of ['example', 'reason', 'experiment'] as const) {
      await runDirector(
        input(emptyDossier('force-motion'), {
          focusConceptKey: 'fall',
          teachingTactic,
        }),
        {
          generate: async (opts) => {
            prompts.set(teachingTactic, opts.prompt)
            return EMPTY_RAW as never
          },
        },
      )
    }

    assert.match(prompts.get('example')!, /身近な場面の例.*その例を通して/)
    assert.match(prompts.get('reason')!, /結論を先に.*なぜそうなるか/)
    assert.match(prompts.get('experiment')!, /試したこと・観察したこと.*その結果/)
  })

  it('CASEは入力された作戦にかかわらずreason固定', async () => {
    let prompt = ''
    await runDirector(
      input(emptyDossier('force-motion'), {
        focusConceptKey: 'fall',
        missionKind: 'caseRetry',
        teachingTactic: 'experiment',
      }),
      {
        generate: async (opts) => {
          prompt = opts.prompt
          return EMPTY_RAW as never
        },
      },
    )

    assert.match(prompt, /REASON（CASE固定）/)
    assert.doesNotMatch(prompt, /EXPERIMENT: 最初のnextInstruction/)
  })

  it('概念指定が無い旧クライアントは従来の全単元カルテと上限を保つ', async () => {
    let prompt = ''
    const out = await runDirector(input(emptyDossier('force-motion')), {
      generate: async (opts) => {
        prompt = opts.prompt
        return EMPTY_RAW as never
      },
    })

    assert.equal(out.dossier.slots.length, 4)
    assert.ok(prompt.includes('fall=落下の速さ'))
    assert.ok(prompt.includes('inertia=慣性'))
    assert.ok(prompt.includes('上限 24 往復'))
  })
})

describe('parseInput', () => {
  it('カルテが無ければ空から始める', () => {
    const got = parseInput({ unitId: 'force-motion', utterances: [] })
    assert.ok('dossier' in got)
    assert.equal(got.dossier.slots.length, 4)
    assert.equal(got.missionKind, 'teach')
    assert.equal(got.teachingTactic, 'reason')
  })

  it('teachingTacticをallowlistから受け取り、CASEだけreasonへ固定する', () => {
    for (const teachingTactic of ['example', 'reason', 'experiment'] as const) {
      const got = parseInput({
        unitId: 'force-motion',
        focusConceptKey: 'fall',
        teachingTactic,
      })
      assert.ok(!('error' in got), JSON.stringify(got))
      assert.equal(got.teachingTactic, teachingTactic)
    }

    const caseMission = parseInput({
      unitId: 'force-motion',
      focusConceptKey: 'fall',
      missionKind: 'caseRetry',
      teachingTactic: 'experiment',
    })
    assert.ok(!('error' in caseMission), JSON.stringify(caseMission))
    assert.equal(caseMission.teachingTactic, 'reason')
  })

  it('明示null・未知のteachingTacticは未指定扱いにしない', () => {
    for (const teachingTactic of ['examples', '', null, undefined, 42, false]) {
      assert.deepEqual(
        parseInput({
          unitId: 'force-motion',
          focusConceptKey: 'fall',
          teachingTactic,
        }),
        { error: 'unknown_teaching_tactic' },
      )
    }
  })

  it('missionKindをallowlistから受け取りDirectorInputへ残す', () => {
    for (const missionKind of ['teach', 'repair', 'caseRetry'] as const) {
      const got = parseInput({
        unitId: 'force-motion',
        focusConceptKey: 'fall',
        missionKind,
        utterances: [],
      })
      assert.ok(!('error' in got), JSON.stringify(got))
      assert.equal(got.missionKind, missionKind)
    }
  })

  it('未知・不正なmissionKindをLLMの前に弾く', () => {
    for (const missionKind of ['case', '', null, undefined, 42, false]) {
      assert.deepEqual(
        parseInput({
          unitId: 'force-motion',
          focusConceptKey: 'fall',
          missionKind,
        }),
        { error: 'unknown_mission_kind' },
      )
    }
  })

  it('REPAIRとCASEは対象概念なしで始めない', () => {
    for (const missionKind of ['repair', 'caseRetry'] as const) {
      assert.deepEqual(
        parseInput({ unitId: 'force-motion', missionKind }),
        { error: 'focus_required' },
      )
    }
  })

  it('1概念指定なら最初からそのスロットだけ作る', () => {
    const got = parseInput({
      unitId: 'force-motion',
      focusConceptKey: 'fall',
      utterances: [],
    })
    assert.ok('dossier' in got)
    assert.equal(got.focusConceptKey, 'fall')
    assert.deepEqual(got.dossier.slots.map((s) => s.key), ['fall'])
  })

  it('既存の全単元カルテも1概念へ絞る', () => {
    const got = parseInput({
      dossier: emptyDossier('force-motion'),
      focusConceptKey: 'inertia',
      utterances: [],
    })
    assert.ok('dossier' in got)
    assert.deepEqual(got.dossier.slots.map((s) => s.key), ['inertia'])
  })

  it('未知・不正な概念をLLMの前に弾く', () => {
    assert.deepEqual(
      parseInput({ unitId: 'force-motion', focusConceptKey: 'no-such-concept' }),
      { error: 'unknown_concept', detail: 'no-such-concept' },
    )
    for (const focusConceptKey of [null, 42, false]) {
      assert.deepEqual(
        parseInput({ unitId: 'force-motion', focusConceptKey }),
        { error: 'unknown_concept' },
      )
    }
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
