import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

import {
  envLang,
  localizeMisconception,
  localizeUnit,
  missingTranslations,
  parseLang,
  validateTranslations,
} from '../lib/i18n.js'
import { liveSessionConfig, systemInstruction } from '../lib/live-config.js'
import { MISCONCEPTIONS } from '../lib/misconceptions.js'
import { UNITS, unitById, validateLocalSpeakingPractice } from '../lib/units.js'

/** 日本語の文字が混ざっていないか。**訳し漏れは1文だけ混ざるので目で見つけにくい** */
const JA = /[぀-ヿ一-龯]/

describe('英語への差し替え', () => {
  it('訳の穴が無い', () => {
    // 抜けると、英語の会話の途中に日本語が1文だけ混ざる。
    // 落ちないので気づけないまま出荷される
    assert.deepEqual(missingTranslations(UNITS, MISCONCEPTIONS), [])
    assert.deepEqual(validateTranslations(UNITS, MISCONCEPTIONS), [])
    assert.equal(UNITS.flatMap((unit) => unit.concepts).length, 29)
    assert.deepEqual(
      MISCONCEPTIONS.map((misconception) => misconception.id),
      Array.from({ length: 29 }, (_, index) => `M${String(index + 1).padStart(2, '0')}`),
    )
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
        assert.ok(
          !JA.test(s.localSpeakingPractice.targetPhrase),
          `${u.id}/${s.conceptKey}: Speaking目標に日本語`,
        )
        for (const [i, accepted] of s.localSpeakingPractice.acceptedTranscripts.entries()) {
          assert.ok(
            !JA.test(accepted),
            `${u.id}/${s.conceptKey}: Speaking受理候補${i}に日本語`,
          )
        }
        assert.deepEqual(
          validateLocalSpeakingPractice(s.localSpeakingPractice),
          [],
          `${u.id}/${s.conceptKey}: 英語Speaking正本が不正`,
        )
        assert.ok(
          !JA.test(s.localCheckpoint.lure),
          `${u.id}/${s.conceptKey}: checkpoint lure に日本語`,
        )
        assert.ok(
          !JA.test(s.localCheckpoint.explanation),
          `${u.id}/${s.conceptKey}: checkpoint explanation に日本語`,
        )
        for (const option of s.localCheckpoint.options) {
          assert.ok(
            !JA.test(option.text),
            `${u.id}/${s.conceptKey}/${option.id}: checkpoint option に日本語`,
          )
          if (option.hint != null) {
            assert.ok(
              !JA.test(option.hint),
              `${u.id}/${s.conceptKey}/${option.id}: checkpoint hint に日本語`,
            )
          }
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
      for (let i = 0; i < u.sections.length; i += 1) {
        assert.deepEqual(
          en.sections[i]!.localCheckpoint.options.map((option) => option.id),
          u.sections[i]!.localCheckpoint.options.map((option) => option.id),
        )
        assert.equal(
          en.sections[i]!.localCheckpoint.correctOptionId,
          u.sections[i]!.localCheckpoint.correctOptionId,
        )
        assert.equal(
          en.sections[i]!.localSpeakingPractice.acceptedTranscripts.length > 0,
          true,
        )
      }
      assert.deepEqual(en.concepts.map((c) => c.weight), u.concepts.map((c) => c.weight))
    }
    for (const m of MISCONCEPTIONS) {
      const en = localizeMisconception(m, 'en')
      assert.equal(en.id, m.id)
      assert.equal(en.conceptKey, m.conceptKey)
    }
  })

  it('科学的な成立条件と安全性も英語で意味等価に保つ', () => {
    const forceMotion = localizeUnit(unitById('force-motion')!, 'en')
    const forceBalance = localizeUnit(unitById('force-balance')!, 'en')
    const pressureBuoyancy = localizeUnit(unitById('pressure-buoyancy')!, 'en')
    const currentMagnetism = localizeUnit(unitById('current-magnetism')!, 'en')
    const matterProperties = localizeUnit(unitById('matter-properties')!, 'en')
    const livingBody = localizeUnit(unitById('living-body')!, 'en')
    const weatherChange = localizeUnit(unitById('weather-change')!, 'en')
    const earthHistory = localizeUnit(unitById('earth-history')!, 'en')

    const inertia = forceMotion.concepts.find((concept) => concept.key === 'inertia')!
    assert.match(inertia.intent, /net force.*zero/i)
    assert.match(inertia.intent, /speed and direction/i)

    const friction = forceMotion.sections.find((section) => section.conceptKey === 'friction')!
    assert.match(friction.body.join(''), /not only friction.*air resistance.*reduced to zero/i)

    const throwUp = forceMotion.sections.find((section) => section.conceptKey === 'throwUp')!
    assert.match(throwUp.body.join(''), /air resistance is negligible.*only gravity/i)
    assert.match(throwUp.tryIt, /air resistance is negligible/i)
    assert.match(throwUp.localCheckpoint.lure, /Ignoring air resistance/i)
    assert.match(throwUp.localCheckpoint.explanation, /only downward gravity/i)

    const actionReaction = forceBalance.sections.find(
      (section) => section.conceptKey === 'actionReaction',
    )!
    const balance = forceBalance.sections.find((section) => section.conceptKey === 'balance')!
    assert.match(actionReaction.body.join(''), /forces act on \*\*different objects\*\*/i)
    assert.match(balance.body.join(''), /same one object.*individual forces have not disappeared/i)
    assert.match(balance.body.join(''), /road pushes forward on the tyres/i)

    const pressure = pressureBuoyancy.sections.find(
      (section) => section.conceptKey === 'pressure',
    )!
    assert.doesNotMatch(pressure.tryIt, /pencil|palm/i)
    assert.match(pressure.tryIt, /sponge.*clay/i)

    const buoyancy = pressureBuoyancy.sections.find(
      (section) => section.conceptKey === 'buoyancy',
    )!
    const buoyancyText = buoyancy.body.join('')
    assert.match(buoyancyText, /same fluid/i)
    assert.match(buoyancyText, /fully submerged/i)
    assert.match(buoyancyText, /volume stays fixed/i)
    assert.match(buoyancy.localCheckpoint.lure, /equal volume.*fully under the same fluid/i)
    assert.match(
      buoyancy.localCheckpoint.explanation,
      /fully submerged.*fixed-volume.*equal volume.*same fluid/i,
    )

    const currentField = currentMagnetism.sections.find(
      (section) => section.conceptKey === 'currentMagneticField',
    )!
    assert.match(currentField.body.join(''), /current creates a magnetic field.*around the wire/i)
    assert.match(currentField.body.join(''), /magnetic field lines.*model.*tangent.*direction/i)
    assert.match(currentField.body.join(''), /coil.*continues.*inside and outside the coil/i)
    assert.match(currentField.body.join(''), /reversing the current reverses the magnetic field/i)
    assert.match(currentField.body.join(''), /increasing the current strengthens the field/i)
    assert.match(currentField.tryIt, /low-voltage/i)
    assert.match(currentField.tryIt, /never connect the battery terminals directly/i)
    assert.match(currentField.tryIt, /never use a household outlet/i)

    const magneticForce = currentMagnetism.sections.find(
      (section) => section.conceptKey === 'magneticForce',
    )!
    assert.match(magneticForce.body.join(''), /reverse either the current or the field alone.*force reverses/i)
    assert.match(magneticForce.body.join(''), /zero when they are parallel or antiparallel/i)
    assert.match(magneticForce.tryIt, /change one condition at a time/i)

    const induction = currentMagnetism.sections.find(
      (section) => section.conceptKey === 'electromagneticInduction',
    )!
    const inductionText = induction.body.join('')
    assert.match(inductionText, /magnetic flux.*field strength.*coil area.*orientation/i)
    assert.match(inductionText, /change in this flux.*induces a \*\*voltage\*\*/i)
    assert.match(inductionText, /closed circuit.*\*\*induced current\*\*/i)
    assert.match(inductionText, /open circuit.*current cannot flow/i)
    assert.match(inductionText, /hold the magnet still.*returns to zero/i)
    assert.match(inductionText, /inserting to withdrawing.*reverses the induced current/i)
    assert.match(inductionText, /north pole to its south.*reverses the induced current/i)
    assert.match(inductionText, /adding turns.*voltages induced.*larger total voltage/i)
    assert.match(inductionText, /induced current.*total circuit resistance.*held constant/i)
    assert.match(inductionText, /generator.*change the magnetic flux through the coil/i)
    assert.match(inductionText, /direct current.*one direction.*alternating current.*periodically/i)
    assert.match(induction.tryIt, /no power supply attached/i)

    const density = matterProperties.sections.find(
      (section) => section.conceptKey === 'density',
    )!
    assert.match(density.body.join(''), /mass divided by volume/i)
    assert.match(density.body.join(''), /same conditions.*temperature/i)
    assert.match(density.body.join(''), /dissolve in or react with water/i)
    assert.match(density.tryIt, /with permission/i)
    assert.match(density.tryIt, /do not taste.*wipe up any spill immediately/i)
    assert.match(density.localCheckpoint.explanation, /mass and volume.*same proportion/i)

    const gasProperties = matterProperties.sections.find(
      (section) => section.conceptKey === 'gasProperties',
    )!
    const gasText = gasProperties.body.join('')
    assert.match(gasText, /water solubility.*density relative to air.*reactions/i)
    assert.match(gasText, /ammonia.*extremely soluble.*less dense than air/i)
    assert.match(gasText, /carbon dioxide.*denser than air.*dissolves in water/i)
    assert.match(gasProperties.tryIt, /do not produce, heat, or burn gases.*never smell them directly/i)

    const stateChangeMass = matterProperties.sections.find(
      (section) => section.conceptKey === 'stateChangeMass',
    )!
    const stateText = stateChangeMass.body.join('')
    assert.match(stateText, /closed system.*total mass.*unchanged/i)
    assert.match(stateText, /open container.*mass.*decreases.*has not vanished/i)
    assert.match(stateChangeMass.tryIt, /do not perform heating, cooling, or sealed-container experiments at home/i)

    const cells = livingBody.sections.find((section) => section.conceptKey === 'cells')!
    assert.match(cells.body.join(''), /structure.*not visible.*cannot simply be declared absent/i)
    assert.match(cells.body.join(''), /root cells.*do not have chloroplasts/i)
    assert.match(cells.tryIt, /do not collect samples from a human body or use stains at home/i)
    assert.match(cells.localCheckpoint.explanation, /several features.*tissue/i)

    const photosynthesis = livingBody.sections.find(
      (section) => section.conceptKey === 'photosynthesisRespiration',
    )!
    const photosynthesisText = photosynthesis.body.join('')
    assert.match(photosynthesisText, /photosynthesis does not proceed in dark conditions/i)
    assert.match(photosynthesisText, /respire in both light and darkness/i)
    assert.match(photosynthesisText, /net gas change.*difference between photosynthesis and respiration/i)
    assert.match(photosynthesis.tryIt, /do not seal up plants or use chemicals or flames/i)

    const digestion = livingBody.sections.find(
      (section) => section.conceptKey === 'digestionAbsorption',
    )!
    const digestionText = digestion.body.join('')
    assert.match(digestionText, /digestive enzymes.*smaller substances.*absorbed/i)
    assert.match(digestionText, /villi of the small intestine/i)
    assert.match(digestionText, /digestive tract does not yet mean.*absorbed into the body/i)
    assert.match(digestion.tryIt, /do not experiment with food, chemicals, or human samples/i)

    const humidityClouds = weatherChange.sections.find(
      (section) => section.conceptKey === 'humidityClouds',
    )!
    const cloudText = humidityClouds.body.join('')
    assert.match(cloudText, /water vapor is a gas and is normally invisible/i)
    assert.match(cloudText, /dew point.*further cooling.*condensation/i)
    assert.match(cloudText, /rising air does not always make a cloud/i)
    assert.match(humidityClouds.tryIt, /stable table/i)
    assert.match(humidityClouds.tryIt, /do not heat or pressurize a sealed container/i)
    assert.match(humidityClouds.localCheckpoint.explanation, /droplets or ice crystals.*scatter light/i)

    const fronts = weatherChange.sections.find((section) => section.conceptKey === 'fronts')!
    const frontsText = fronts.body.join('')
    assert.match(frontsText, /boundary where air masses with different properties meet/i)
    assert.match(frontsText, /warm front.*rises gradually.*cold front.*underneath warm air/i)
    assert.match(frontsText, /representative tendencies.*water-vapor content.*terrain/i)
    assert.match(fronts.tryIt, /do not go outside.*thunderstorms or severe weather/i)

    const pressureWind = weatherChange.sections.find(
      (section) => section.conceptKey === 'pressurePatternsWind',
    )!
    const pressureWindText = pressureWind.body.join('')
    assert.match(pressureWindText, /high-pressure side.*low-pressure side/i)
    assert.match(pressureWindText, /closer isobars.*wind generally tends to be stronger/i)
    assert.match(pressureWindText, /Earth’s rotation.*surface.*friction/i)
    assert.match(pressureWind.tryIt, /do not go outside.*typhoon or strong winds/i)

    const strata = earthHistory.sections.find(
      (section) => section.conceptKey === 'strataRelativeAge',
    )!
    const strataText = strata.body.join('')
    assert.match(strataText, /have not later been substantially overturned.*earlier layer lies below/i)
    assert.match(strataText, /fault.*cutting event happened after the cut layers/i)
    assert.match(strataText, /relative order, not a numerical age in years/i)
    assert.match(strata.tryIt, /do not approach outdoor cliffs or construction sites/i)
    assert.match(strata.tryIt, /do not collect rocks/i)

    const volcanoes = earthHistory.sections.find(
      (section) => section.conceptKey === 'volcanoEarthquakes',
    )!
    const volcanoText = volcanoes.body.join('')
    assert.match(volcanoText, /earthquake.*rock suddenly slips.*volcanic eruption.*magma rises/i)
    assert.match(volcanoText, /do not necessarily occur at the same place and time/i)
    assert.match(volcanoes.tryIt, /do not travel to disaster areas or volcanoes.*published materials only/i)
    assert.match(volcanoes.localCheckpoint.lure, /same mechanism.*always occur together/i)

    const seasons = earthHistory.sections.find(
      (section) => section.conceptKey === 'dailyMotionSeasons',
    )!
    const seasonsText = seasons.body.join('')
    assert.match(seasonsText, /daily motion.*Earth rotating/i)
    assert.match(seasonsText, /main cause of seasons is axial tilt together with revolution, not distance/i)
    assert.match(seasonsText, /Southern Hemisphere has the opposite season/i)
    assert.match(seasons.tryIt, /never look directly at the Sun or observe outdoors alone at night/i)

    const translatedMisconceptions = new Map(
      MISCONCEPTIONS.map((m) => [m.id, localizeMisconception(m, 'en')]),
    )
    assert.match(translatedMisconceptions.get('M12')!.correct, /mass per unit volume.*same proportion/i)
    assert.match(translatedMisconceptions.get('M13')!.correct, /plant cells have no chloroplasts/i)
    assert.match(translatedMisconceptions.get('M14')!.correct, /invisible gas.*droplets or ice crystals/i)
    assert.match(translatedMisconceptions.get('M15')!.correct, /not been substantially overturned.*lower layers.*older/i)
    assert.match(translatedMisconceptions.get('M16')!.correct, /water solubility.*density relative to air.*reactions/i)
    assert.match(translatedMisconceptions.get('M17')!.correct, /closed system.*total mass does not change/i)
    assert.match(translatedMisconceptions.get('M18')!.correct, /respire throughout day and night.*net gas exchange/i)
    assert.match(translatedMisconceptions.get('M19')!.correct, /digestion.*absorbable.*small intestine/i)
    assert.match(translatedMisconceptions.get('M20')!.correct, /boundary between air masses.*temperature.*wind/i)
    assert.match(translatedMisconceptions.get('M21')!.correct, /pressure differences.*rotation.*friction/i)
    assert.match(translatedMisconceptions.get('M22')!.correct, /rising magma.*sudden rock slip.*do not necessarily occur together/i)
    assert.match(translatedMisconceptions.get('M22')!.lure, /same mechanism.*always occur together/i)
    assert.match(translatedMisconceptions.get('M23')!.correct, /daily motion.*rotation.*revolving with a tilted axis/i)
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

  it('固定challengeだけは指示を読まず、引用文のみ逐語で言う', () => {
    const ja = systemInstruction(unit, '[D:x]', 'ja')
    assert.match(ja, /引用された一文だけ.*逐語/)
    assert.match(ja, /前後に何も足さない/)

    const en = systemInstruction(localizeUnit(unit, 'en'), '[D:x]', 'en')
    assert.match(en, /only the quoted sentence verbatim/i)
    assert.match(en, /nothing before or after/i)
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

  it('1概念ミッションは対象だけを示し、他概念へ移らせない', () => {
    const s = systemInstruction(unit, '[D:x]', 'ja', 'fall')
    assert.ok(s.includes('落下の速さ'))
    assert.ok(s.includes('この1点だけ'))
    assert.ok(s.includes('他の概念へ移らず'))
    assert.ok(!s.includes('慣性'), '対象外の概念名が音声モデルへ漏れている')
    assert.ok(!s.includes('止まる理由'), '対象外の概念名が音声モデルへ漏れている')
    assert.ok(!s.includes('投げ上げた物体'), '対象外の概念名が音声モデルへ漏れている')
  })

  it('概念指定が無い旧クライアントには単元全体を保つ', () => {
    const s = systemInstruction(unit, '[D:x]')
    for (const concept of unit.concepts) assert.ok(s.includes(concept.label))
    assert.ok(s.includes('この単元について'))
  })

  it('未指定のmissionKindは明示的なteachと完全互換', () => {
    const implicit = liveSessionConfig(unit, '[D:x]', undefined, 'ja', 'fall')
    const explicit = liveSessionConfig(unit, '[D:x]', undefined, 'ja', 'fall', 'teach')
    assert.deepEqual(implicit, explicit)
  })

  it('作戦ごとに最初の引き出し方が実質的に変わる', () => {
    const prompts = {
      example: systemInstruction(unit, '[D:x]', 'ja', 'fall', 'teach', 'example'),
      reason: systemInstruction(unit, '[D:x]', 'ja', 'fall', 'teach', 'reason'),
      experiment: systemInstruction(unit, '[D:x]', 'ja', 'fall', 'teach', 'experiment'),
    }

    assert.match(prompts.example, /身の回りで起きる例/)
    assert.match(prompts.reason, /結論を先に言い.*なぜそうなるか/)
    assert.match(prompts.experiment, /試したこと・観察したこと.*その結果/)
    assert.equal(new Set(Object.values(prompts)).size, 3)

    const en = systemInstruction(
      localizeUnit(unit, 'en'),
      '[D:x]',
      'en',
      'fall',
      'teach',
      'experiment',
    )
    assert.match(en, /what they tried or observed and what happened/i)
    assert.ok(!JA.test(en))
  })

  it('REPAIRでも選んだ作戦を使い、CASEだけはreason固定', () => {
    const repair = systemInstruction(unit, '[D:x]', 'ja', 'fall', 'repair', 'example')
    assert.match(repair, /身近な別の場面/)
    assert.doesNotMatch(repair, /結論を先に言い/)

    const casePrompt = systemInstruction(
      unit,
      '[D:x]',
      'ja',
      'fall',
      'caseRetry',
      'experiment',
    )
    assert.match(casePrompt, /結果の予想と理由/)
    assert.doesNotMatch(casePrompt, /試したこと・観察したこと/)
  })

  it('CASEは対象のtryItだけを場面として渡し、教材本文と答えを渡さない', () => {
    for (const lang of ['ja', 'en'] as const) {
      const catalog = localizeUnit(unit, lang)
      const target = catalog.sections.find((section) => section.conceptKey === 'fall')!
      const setup = liveSessionConfig(
        catalog,
        '[D:x]',
        undefined,
        lang,
        'fall',
        'caseRetry',
      ) as Record<string, any>
      const prompt = setup.systemInstruction.parts[0].text as string

      assert.ok(prompt.includes(target.tryIt), `${lang}: 対象のtryItが無い`)
      for (const line of target.body) {
        assert.ok(!prompt.includes(line), `${lang}: 教材本文がCASEへ漏れた`)
      }
      for (const section of catalog.sections.filter((section) => section !== target)) {
        assert.ok(!prompt.includes(section.tryIt), `${lang}: 別概念のtryItがCASEへ漏れた`)
        for (const line of section.body) {
          assert.ok(!prompt.includes(line), `${lang}: 別概念の本文がCASEへ漏れた`)
        }
      }

      assert.match(prompt, lang === 'ja' ? /CASE MISSION/ : /CASE MISSION/)
      assert.match(
        prompt,
        lang === 'ja' ? /結果の予想と理由/ : /prediction and the reason/i,
      )
      assert.match(
        prompt,
        lang === 'ja' ? /答え・正しい法則・教材本文を先に明かしてはいけません/ : /Never reveal the answer/i,
      )
    }
  })

  it('REPAIRは未決着の説明を組み直し、答えを先回りしない', () => {
    const prompt = systemInstruction(unit, '[D:x]', 'ja', 'fall', 'repair')
    assert.ok(prompt.includes('REPAIR MISSION'))
    assert.ok(prompt.includes('前回は最後の考えに決着がつきませんでした'))
    assert.ok(prompt.includes('理由や条件から組み直して'))
    assert.ok(prompt.includes('答えを先回りせず'))
    assert.ok(!prompt.includes(unit.sections[0]!.tryIt), 'REPAIRへCASEの場面が漏れた')
  })

  it('未知の概念へ黙って単元全体へ戻らない', () => {
    assert.throws(
      () => systemInstruction(unit, '[D:x]', 'ja', 'no-such-concept'),
      /未知の概念/,
    )
  })
})
