import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

import {
  envLang,
  localizeMisconception,
  localizeUnit,
  missingTranslations,
  parseLang,
} from '../lib/i18n.js'
import { liveSessionConfig, systemInstruction } from '../lib/live-config.js'
import { MISCONCEPTIONS } from '../lib/misconceptions.js'
import { UNITS, unitById } from '../lib/units.js'

/** 日本語の文字が混ざっていないか。**訳し漏れは1文だけ混ざるので目で見つけにくい** */
const JA = /[぀-ヿ一-龯]/

describe('英語への差し替え', () => {
  it('訳の穴が無い', () => {
    // 抜けると、英語の会話の途中に日本語が1文だけ混ざる。
    // 落ちないので気づけないまま出荷される
    assert.deepEqual(missingTranslations(UNITS, MISCONCEPTIONS), [])
  })

  it('単元・概念・教材のどこにも日本語が残らない', () => {
    for (const u of UNITS) {
      const en = localizeUnit(u, 'en')
      assert.ok(!JA.test(en.title), `${u.id}: title に日本語`)
      assert.ok(!JA.test(en.brief), `${u.id}: brief に日本語`)
      for (const c of en.concepts) {
        assert.ok(!JA.test(c.label), `${u.id}/${c.key}: label に日本語`)
        assert.ok(!JA.test(c.intent), `${u.id}/${c.key}: intent に日本語`)
      }
      for (const s of en.sections) {
        assert.ok(!JA.test(s.title), `${u.id}/${s.conceptKey}: 節タイトルに日本語`)
        assert.ok(!JA.test(s.tryIt), `${u.id}/${s.conceptKey}: tryIt に日本語`)
        for (const [i, b] of s.body.entries()) {
          assert.ok(!JA.test(b), `${u.id}/${s.conceptKey}: 本文${i} に日本語`)
        }
      }
    }
  })

  it('誘発のセリフに日本語が残らない', () => {
    // ここが日本語のまま出ると、デモの山場だけ日本語になる
    for (const m of MISCONCEPTIONS) {
      const en = localizeMisconception(m, 'en')
      assert.ok(!JA.test(en.lure), `${m.id}: lure に日本語`)
      assert.ok(!JA.test(en.correct), `${m.id}: correct に日本語`)
      assert.ok(!JA.test(en.misconception), `${m.id}: misconception に日本語`)
    }
  })

  it('構造は言語で変わらない', () => {
    // conceptKey と誤概念の id は観測の単位そのもの。
    // 言語で変わると、同じ生徒の記録が言語で分断される
    for (const u of UNITS) {
      const en = localizeUnit(u, 'en')
      assert.equal(en.id, u.id)
      assert.deepEqual(en.concepts.map((c) => c.key), u.concepts.map((c) => c.key))
      assert.deepEqual(
        en.sections.map((s) => s.conceptKey),
        u.sections.map((s) => s.conceptKey),
      )
      assert.deepEqual(en.concepts.map((c) => c.weight), u.concepts.map((c) => c.weight))
    }
    for (const m of MISCONCEPTIONS) {
      const en = localizeMisconception(m, 'en')
      assert.equal(en.id, m.id)
      assert.equal(en.conceptKey, m.conceptKey)
    }
  })

  it('ja では原本をそのまま返す', () => {
    for (const u of UNITS) assert.equal(localizeUnit(u, 'ja'), u)
    for (const m of MISCONCEPTIONS) assert.equal(localizeMisconception(m, 'ja'), m)
  })
})

describe('言語の決め方', () => {
  it('知らない値は日本語に倒す（英語に倒さない）', () => {
    // 原本が日本語なので、迷ったら原本側へ
    for (const v of [undefined, null, '', 'EN', 'fr', 42, {}]) {
      assert.equal(parseLang(v), 'ja')
    }
    assert.equal(parseLang('en'), 'en')
  })

  it('環境変数で既定を変えられる', () => {
    // 配布済みの端末に手を入れずに切り替えるための逃げ道
    const before = process.env.DEMO_LANG
    try {
      process.env.DEMO_LANG = 'en'
      assert.equal(envLang(), 'en')
      delete process.env.DEMO_LANG
      assert.equal(envLang(), 'ja')
    } finally {
      if (before == null) delete process.env.DEMO_LANG
      else process.env.DEMO_LANG = before
    }
  })
})

describe('会話設定', () => {
  const unit = unitById('force-motion')!

  it('en なら英語の指示になり、日本語が混ざらない', () => {
    const s = systemInstruction(localizeUnit(unit, 'en'), '[D:x]', 'en')
    assert.ok(!JA.test(s), '英語のシステム指示に日本語が混ざっている')
    assert.ok(s.includes('Force and Motion'))
  })

  it('en でも役を降りられない守りが残る', () => {
    // 5通りの手口で止まることを確認しているのはこの構造に対してで、
    // 崩すと守りごと落ちる
    const s = systemInstruction(unit, '[D:x]', 'en')
    assert.ok(/cannot step out of this role/i.test(s))
    assert.ok(/never do the following/i.test(s))
    assert.ok(s.includes('[D:x]'), '合図がシステム指示に入っていない')
  })

  it('文字起こしの言語ヒントも切り替わる', () => {
    // ここを忘れると、英語の発話が日本語として文字起こしされる
    const en = liveSessionConfig(unit, '[D:x]', undefined, 'en') as Record<string, any>
    assert.deepEqual(en.outputAudioTranscription.languageHints.languageCodes, ['en-US'])
    assert.deepEqual(en.inputAudioTranscription.languageHints.languageCodes, ['en-US'])

    const ja = liveSessionConfig(unit, '[D:x]') as Record<string, any>
    assert.deepEqual(ja.outputAudioTranscription.languageHints.languageCodes, ['ja-JP'])
  })

  it('既定は日本語のまま（原本を壊さない）', () => {
    const s = systemInstruction(unit, '[D:x]')
    assert.ok(s.includes('後輩'))
  })
})
