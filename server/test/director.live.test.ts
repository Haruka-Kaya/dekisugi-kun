// ディレクターを実際の Gemini に通すテスト。
//
// なぜ要るか: 構造化出力のスキーマは**呼んでみるまで通るか分からない**。
// enum の値・required の組み合わせ・ネストの深さで拒否されることがあり、
// モデル名を変えたときにも黙って壊れる。
//
//   node --test test/director.live.test.ts
//
// キーが無い環境では skip する。

import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { describe, it } from 'node:test'

import { runDirector, type Utterance } from '../lib/director.js'
import { emptyDossier } from '../lib/dossier.js'
import { liveSkip } from './support/live.js'

function loadKey(): string | undefined {
  if (process.env.GEMINI_API_KEY) return process.env.GEMINI_API_KEY
  for (const p of ['../.env.local', 'C:/Users/kayah/jiyu-kenkyu-ai/.env.local']) {
    try {
      const m = /GEMINI_API_KEY\s*=\s*(\S+)/.exec(readFileSync(p, 'utf8'))
      if (m) return m[1]!.replace(/^["']|["']$/g, '')
    } catch {
      /* 次を試す */
    }
  }
  return undefined
}

const key = loadKey()
if (key) process.env.GEMINI_API_KEY = key

const UTTERANCES: Utterance[] = [
  { id: 'u01', speaker: 'ai', text: '先輩、落下ってどうなるんですか？' },
  {
    id: 'u02',
    speaker: 'student',
    text: 'えっとね、ものが落ちる速さって、重さは関係ないんだよ。同じ高さから落としたら同時に着く',
  },
]

describe('ディレクターを実際の Gemini に通す', { skip: liveSkip || (key ? false : 'GEMINI_API_KEY が無い') }, () => {
  it('スキーマが通り、説明した概念が埋まる', async () => {
    const out = await runDirector({
      dossier: emptyDossier('force-motion'),
      utterances: UTTERANCES,
      secondsLeft: 600,
      turnCount: 1,
    })

    const fall = out.dossier.slots.find((s) => s.key === 'fall')!
    assert.notEqual(fall.status, 'untouched', `落下が埋まっていない: ${JSON.stringify(fall)}`)
    assert.ok(fall.evidence.includes('u02'), `根拠が生徒の発話を指していない: ${fall.evidence}`)

    // 触れていない概念を勝手に埋めない
    const inertia = out.dossier.slots.find((s) => s.key === 'inertia')!
    assert.equal(inertia.status, 'untouched', `触れていない概念が埋まった: ${inertia.content}`)

    assert.ok(out.dossier.coverage > 0)
    assert.equal(out.shouldEnd, false)

    console.log('カルテ:', JSON.stringify(fall, null, 2))
    console.log('次の指示:', out.nextInstruction, '/ lureId =', out.lureId)
  })

  it('説明が済んだ概念には誤概念を口にさせる', async () => {
    const dossier = emptyDossier('force-motion')
    const fall = dossier.slots.find((s) => s.key === 'fall')!
    fall.status = 'explained'
    fall.content = '落下の速さは重さによらない'
    fall.evidence = ['u02']

    const out = await runDirector({ dossier, utterances: UTTERANCES, secondsLeft: 600, turnCount: 2 })

    // 誘発するかどうかはコードが決めるので、モデルの気分で変わらない
    assert.equal(out.lureId, 'M01')
    assert.ok(out.nextInstruction.includes('重いものの方が速く落ちる'))
  })
})
