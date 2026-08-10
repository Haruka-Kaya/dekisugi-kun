import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { describe, it } from 'node:test'

import { parseInput } from '../api/director.js'
import unitsHandler from '../api/units.js'
import { MISCONCEPTIONS, misconceptionsFor } from '../lib/misconceptions.js'
import { type Req, type Res } from '../lib/http.js'
import {
  BUNDLED_UNIT_CATALOG_SCHEMA_VERSION,
  buildBundledUnitCatalog,
  publicUnitDetail,
} from '../lib/public-unit-catalog.js'
import {
  COGNITIVE_OPERATIONS,
  COGNITIVE_TASK_KINDS,
  LOCAL_PRACTICE_STAGES,
  type CognitiveTask,
  type LocalPracticeStage,
  localPracticeVariantsFor,
  scienceListeningNeedCodes,
  sciencePracticeNeedCode,
} from '../lib/local-practice-variants.js'
import {
  NOTATION_LABS,
  notationLabFor,
  validateNotationLab,
} from '../lib/notation-labs.js'
import {
  scienceStoryFor,
  validateScienceStory,
} from '../lib/science-stories.js'
import {
  focusUnit,
  UNITS,
  unitById,
  validateCatalog,
  validateLocalSpeakingPractice,
} from '../lib/units.js'

const EXPECTED_STORY_SIGNATURES = {
  fall: ['紙ひこうき部、落下レース中止事件', '放課後の理科室。平らな紙と丸めた紙が、同じスタート台に並んでいる。', '次のレースは真空で……え、理科室ごと吸っちゃだめ？'],
  inertia: ['逃走コインと消えた押し手', '昼休みの実験机。指を離れたコインが、机の端へ向かって滑っている。', '逃走コイン、犯人は小人ではなく摩擦でした。小人は釈放！'],
  friction: ['タオル沼のコイン救出作戦', '実験机の半分だけにタオルが敷かれ、同じコインが二つのコースを走る。', '食いしん坊なのはタオルじゃなくて、ぼくの昼休みでした。'],
  throwUp: ['最高点ゼロ秒カメラの謎', '体育館の安全ネット下。投げ上げた柔らかい球をスローモーションで観察する。', '重力さん、休憩申請は却下されました。'],
  actionReaction: ['しゃべらない壁のハイタッチ', '校舎の丈夫な壁の前。手のひらで弱く、次に少し強く押した感触を比べる。', '壁との会話、返事は毎回「同じだけ」です。'],
  balance: ['上昇エレベーターのアリバイ', '校舎のエレベーター内。表示は上向きだが、一定速度の区間を選んで考える。', 'エレベーターは上昇中、ぼくの説は下降中でした。'],
  pressure: ['消しゴム足あと鑑定団', 'やわらかい粘土の上。消しゴムの広い面と細い辺で、同じ力の跡を比べる。', '消しゴムの足あと、犯人は細い辺でした。消す係なのに！'],
  buoyancy: ['油粘土船、沈没からの大逆転', '水を張った透明容器。等しい量の油粘土を、球と水の入らない舟形で比べる。', '粘土の気持ちは重いまま。でも船長の気分は浮上！'],
  currentMagneticField: ['方位磁針が聞いた電流のひそひそ話', '先生の監督する低電圧実験台。抵抗を入れた導線の下に方位磁針を置く。', 'ひそひそ話の内容は「右、いや左」でした。'],
  magneticForce: ['電気ブランコ反転裁判', '先生の監督する低電圧の電気ブランコ実験。変える条件は毎回一つだけ。', 'ブランコは無罪。気分で動いたのは、ぼくの仮説でした。'],
  electromagneticInduction: ['眠る磁石と無言の検流計', '先生の監督する実験台。電源をつながないコイルと検流計へ棒磁石を近づける。', '検流計の目覚まし時計は、磁束の変化でした。'],
} as const

type PublicConcept = { key: string; label: string; storyTitle: string }
type PublicSection = {
  conceptKey: string
  body: string[]
  tryIt: string
  localSpeakingPractice: {
    targetPhrase: string
    acceptedTranscripts: string[]
  }
  scienceStory: { title: string }
  localCheckpoint: {
    lure: string
    options: { id: string; text: string; hint?: string; needCode?: string }[]
    correctOptionId: string
    explanation: string
  }
  localPracticeVariants: {
    stage: LocalPracticeStage
    recallPrompt: string
    reasoningPrompt: string
    transferPrompt: string
    expectedOutcome: string
    expectedReason: string
    cognitiveTask: CognitiveTask
    checkpoint: {
      lure: string
      options: { id: string; text: string; hint?: string; needCode?: string }[]
      correctOptionId: string
      explanation: string
    }
    listeningNeedCodes: {
      transcript: string
      meaning: string
    }
  }[]
  notationLab: {
    orderTasks: {
      id: string
      needCode: string
      title: string
      prompt: string
      traceGuide: string
      tokens: { id: string; label: string }[]
      correctOrderIds: string[]
      solutionSummary: string
    }[]
    symbolMatch: {
      needCode: string
      prompt: string
      choices: { id: string; label: string }[]
      correctChoiceId: string
      solutionSummary: string
    }
    graphRead: {
      needCode: string
      prompt: string
      graphNotation: string[]
      graphSemanticsLabel: string
      choices: { id: string; label: string }[]
      correctChoiceId: string
      solutionSummary: string
    }
  }
}
type PublicUnit = {
  id: string
  concepts: PublicConcept[]
  sections?: PublicSection[]
}

class CapturedResponse implements Res {
  statusCode = 0
  body: unknown
  readonly headers = new Map<string, string>()

  status(code: number): Res {
    this.statusCode = code
    return this
  }

  json(body: unknown): void {
    this.body = body
  }

  setHeader(name: string, value: string): void {
    this.headers.set(name.toLowerCase(), value)
  }
}

function getUnits(query: Req['query'] = {}): CapturedResponse {
  const response = new CapturedResponse()
  unitsHandler({ method: 'GET', query }, response)
  assert.equal(response.statusCode, 200, JSON.stringify(response.body))
  return response
}

describe('学習ミッションのカタログ不変条件', () => {
  it('11概念のSpeaking目標を正本化し、欠落・未知field・短文・重複を拒否する', () => {
    const sections = UNITS.flatMap((unit) => unit.sections)
    assert.equal(sections.length, 11)
    assert.equal(
      new Set(sections.map((section) => section.conceptKey)).size,
      11,
      'Speaking目標が概念と1対1でない',
    )
    for (const section of sections) {
      assert.deepEqual(
        validateLocalSpeakingPractice(section.localSpeakingPractice),
        [],
        section.conceptKey,
      )
      assert.equal(
        section.localSpeakingPractice.acceptedTranscripts[0],
        section.localSpeakingPractice.targetPhrase,
        `${section.conceptKey}: targetが受理候補に含まれない`,
      )
    }
    assert.notDeepEqual(validateLocalSpeakingPractice(undefined), [])
    assert.notDeepEqual(
      validateLocalSpeakingPractice({
        targetPhrase: '十分に長い固定の目標語句をここへ用意する',
        acceptedTranscripts: ['十分に長い固定の目標語句をここへ用意する'],
        futureScore: 0.8,
      }),
      [],
    )
    assert.notDeepEqual(
      validateLocalSpeakingPractice({
        targetPhrase: '短い',
        acceptedTranscripts: ['短い'],
      }),
      [],
    )
    const targetPhrase = '十分に長い固定の目標語句をここへ用意する'
    assert.notDeepEqual(
      validateLocalSpeakingPractice({
        targetPhrase,
        acceptedTranscripts: [targetPhrase, `${targetPhrase}。`],
      }),
      [],
    )
  })

  it('アプリ同梱教材が正カタログからの機械生成結果と完全一致する', async () => {
    const assetUrl = new URL(
      '../../app/assets/catalog/units.ja.json',
      import.meta.url,
    )
    const actual = JSON.parse(await readFile(assetUrl, 'utf8')) as unknown
    const expected = buildBundledUnitCatalog(UNITS)

    assert.equal(
      (actual as { schemaVersion?: unknown }).schemaVersion,
      BUNDLED_UNIT_CATALOG_SCHEMA_VERSION,
      'needCode必須化後の生成物を旧schemaとして配っている',
    )

    assert.deepEqual(
      actual,
      expected,
      'server/lib/units.ts を変えたら npm run catalog:generate が必要',
    )

    const published = JSON.stringify(actual)
    assert.doesNotMatch(published, /"intent"|"weight"/)
    for (const online of MISCONCEPTIONS) {
      assert.ok(
        !published.includes(online.lure),
        `${online.id}: Directorの逐語lureを同梱教材へ漏らしている`,
      )
    }
  })

  it('全11conceptが3周で異なる問い・正答位置・誤答だけのヒントを持つ', () => {
    assert.deepEqual(validateCatalog(), [])

    const sections = UNITS.flatMap((unit) => unit.sections)
    assert.equal(sections.length, 11)
    const correctPositions = new Set<number>()

    for (const section of sections) {
      const variants = localPracticeVariantsFor(section)
      assert.deepEqual(
        variants.map((variant) => variant.stage),
        LOCAL_PRACTICE_STAGES,
        `${section.conceptKey}: 認知段階の順序が不正`,
      )
      assert.equal(
        new Set(variants.map((variant) => variant.checkpoint.lure)).size,
        3,
        `${section.conceptKey}: 再挑戦でも同じlure`,
      )
      const conceptPositions = new Set<number>()
      for (const variant of variants) {
        assert.ok(variant.recallPrompt.trim(), `${section.conceptKey}/${variant.stage}: 想起が空`)
        assert.ok(variant.reasoningPrompt.trim(), `${section.conceptKey}/${variant.stage}: 理由が空`)
        assert.ok(variant.transferPrompt.trim(), `${section.conceptKey}/${variant.stage}: 場面が空`)
        assert.ok(variant.expectedOutcome.trim(), `${section.conceptKey}/${variant.stage}: 場面の結果が空`)
        assert.ok(variant.expectedReason.trim(), `${section.conceptKey}/${variant.stage}: 場面の理由が空`)
        const checkpoint = variant.checkpoint
        assert.equal(checkpoint.options.length, 3, `${section.conceptKey}/${variant.stage}`)
        assert.equal(
          new Set(checkpoint.options.map((option) => option.id)).size,
          3,
          `${section.conceptKey}/${variant.stage}: 選択肢IDが重複`,
        )
        const correctIndex = checkpoint.options.findIndex(
          (option) => option.id === checkpoint.correctOptionId,
        )
        assert.ok(correctIndex >= 0, `${section.conceptKey}/${variant.stage}: 正答が無い`)
        assert.notEqual(
          variant.expectedOutcome,
          checkpoint.options[correctIndex]!.text,
          `${section.conceptKey}/${variant.stage}: checkpoint正答を場面の結果へ流用`,
        )
        assert.notEqual(
          variant.expectedReason,
          checkpoint.explanation,
          `${section.conceptKey}/${variant.stage}: checkpoint解説を場面の理由へ流用`,
        )
        correctPositions.add(correctIndex)
        conceptPositions.add(correctIndex)
        for (const option of checkpoint.options) {
          if (option.id === checkpoint.correctOptionId) {
            assert.equal(
              option.hint,
              undefined,
              `${section.conceptKey}/${variant.stage}/${option.id}: 正答をhintで補強しない`,
            )
          } else {
            assert.ok(
              option.hint?.trim(),
              `${section.conceptKey}/${variant.stage}/${option.id}: ヒントが無い`,
            )
          }
        }
      }
      assert.deepEqual(
        [...conceptPositions].sort(),
        [0, 1, 2],
        `${section.conceptKey}: 3周の正答位置を分散していない`,
      )
    }

    assert.deepEqual(
      [...correctPositions].sort(),
      [0, 1, 2],
      '正答位置が固定だと内容を考えず通過できる',
    )

    assert.equal(correctPositions.size, 3)
  })

  it('全固定誤答とNotation課題が回答IDから独立した安定needCodeを持つ', () => {
    let cognitiveCount = 0
    let wrongOptionCount = 0
    let notationCount = 0
    const practiceCodes = new Set<string>()
    const notationCodes = new Set<string>()

    for (const section of UNITS.flatMap((unit) => unit.sections)) {
      for (const variant of localPracticeVariantsFor(section)) {
        const expected = sciencePracticeNeedCode(section.conceptKey, variant.stage)
        cognitiveCount++
        practiceCodes.add(expected)
        assert.equal(variant.cognitiveTask.needCode, expected)
        for (const option of variant.checkpoint.options) {
          if (option.id === variant.checkpoint.correctOptionId) {
            assert.equal(option.needCode, undefined, '正答をneedとして保存しない')
          } else {
            wrongOptionCount++
            assert.equal(option.needCode, expected)
            assert.notEqual(option.needCode, option.id, '選択肢IDをneedCodeへ流用しない')
          }
        }
      }

      const notation = notationLabFor(section.conceptKey)!
      const codes = [
        ...notation.orderTasks.map((task) => task.needCode),
        notation.symbolMatch.needCode,
        notation.graphRead.needCode,
      ]
      notationCount += codes.length
      for (const code of codes) {
        assert.match(
          code,
          new RegExp(`^science\\.${section.conceptKey}\\.notation\\.`),
        )
        notationCodes.add(code)
      }
    }

    assert.equal(cognitiveCount, 33)
    assert.equal(wrongOptionCount, 66)
    assert.equal(notationCount, 44)
    assert.equal(practiceCodes.size, 33)
    assert.equal(notationCodes.size, 44)
  })

  it('全11concept×3stageのListening聞き取り/意味needを別codeで公開する', () => {
    const codes = new Set<string>()
    let variantCount = 0
    for (const unit of UNITS) {
      const published = publicUnitDetail(unit)
      for (const section of published.sections) {
        for (const variant of section.localPracticeVariants) {
          variantCount++
          const expected = scienceListeningNeedCodes(
            section.conceptKey,
            variant.stage,
          )
          assert.deepEqual(variant.listeningNeedCodes, expected)
          assert.notEqual(expected.transcript, expected.meaning)
          assert.match(
            expected.transcript,
            new RegExp(
              `^science\\.${section.conceptKey}\\.listening\\.${variant.stage}\\.transcript$`,
            ),
          )
          assert.match(
            expected.meaning,
            new RegExp(
              `^science\\.${section.conceptKey}\\.listening\\.${variant.stage}\\.meaning$`,
            ),
          )
          codes.add(expected.transcript)
          codes.add(expected.meaning)
        }
      }
    }
    assert.equal(variantCount, 33)
    assert.equal(codes.size, 66)
    assert.throws(() => scienceListeningNeedCodes('unknown-concept', 'foundation'))
  })

  it('全11conceptの式・単位・矢印・graphがserver正本から損失なく公開される', () => {
    const sections = UNITS.flatMap((unit) => unit.sections)
    assert.equal(sections.length, 11)
    assert.deepEqual(
      new Set(Object.keys(NOTATION_LABS)),
      new Set(sections.map((section) => section.conceptKey)),
    )

    for (const section of sections) {
      const source = notationLabFor(section.conceptKey)
      assert.ok(source, `${section.conceptKey}: Notation正本が無い`)
      const unit = UNITS.find((candidate) => candidate.sections.includes(section))!
      const published = publicUnitDetail(unit).sections.find(
        (candidate) => candidate.conceptKey === section.conceptKey,
      )!
      assert.deepEqual(published.notationLab, source)
      assert.notEqual(published.notationLab, source, '公開形は正本の参照を共有しない')
      assert.equal(published.notationLab.orderTasks.length, 2)
      for (const task of published.notationLab.orderTasks) {
        assert.notDeepEqual(
          task.tokens.map((token) => token.id),
          task.correctOrderIds,
          `${section.conceptKey}/${task.id}: 表示順が正答順`,
        )
      }
      assert.ok(
        published.notationLab.symbolMatch.choices.some(
          (choice) => choice.id === published.notationLab.symbolMatch.correctChoiceId,
        ),
      )
      assert.ok(published.notationLab.graphRead.graphNotation.length >= 2)
      assert.ok(published.notationLab.graphRead.graphSemanticsLabel.trim())
      assert.ok(
        published.notationLab.graphRead.choices.some(
          (choice) => choice.id === published.notationLab.graphRead.correctChoiceId,
        ),
      )
    }

    assert.equal(notationLabFor('unknown-concept'), undefined)
  })

  it('全11 Storyが固有の事件名・舞台・落ちを持ち、foundation正本へ完全一致する', () => {
    const seenLineIds = new Set<string>()
    const publishedStories = []
    for (const unit of UNITS) {
      const published = publicUnitDetail(unit)
      for (const section of unit.sections) {
        const foundation = localPracticeVariantsFor(section)[0]!
        const story = scienceStoryFor(section.conceptKey, foundation)
        assert.ok(story, `${section.conceptKey}: Storyが無い`)
        assert.deepEqual(
          [story.title, story.setting, story.punchline.text],
          EXPECTED_STORY_SIGNATURES[
            section.conceptKey as keyof typeof EXPECTED_STORY_SIGNATURES
          ],
        )
        assert.deepEqual(validateScienceStory(story, section.conceptKey, foundation), [])
        assert.equal(story.foundationNeedCode, `science.${section.conceptKey}.foundation`)
        assert.equal(story.choiceLine.text, foundation.checkpoint.lure)
        assert.deepEqual(story.scientificResolution, {
          outcome: foundation.expectedOutcome,
          reason: foundation.expectedReason,
        })
        assert.deepEqual(
          new Set(story.choiceResponses.map((entry) => entry.optionId)),
          new Set(foundation.checkpoint.options.map((option) => option.id)),
        )
        const lines = [
          ...story.openingLines,
          story.choiceLine,
          ...story.choiceResponses.map((entry) => entry.line),
          ...story.resolutionLines,
          story.punchline,
        ]
        const usedCharacters = new Set(lines.map((line) => line.speakerId))
        assert.deepEqual(
          usedCharacters,
          new Set(story.characters.map((character) => character.id)),
          `${section.conceptKey}: 未使用character`,
        )
        for (const line of lines) {
          assert.ok(line.text.trim(), `${section.conceptKey}: 空会話`)
          assert.ok(!seenLineIds.has(line.id), `${line.id}: 全Storyで会話ID重複`)
          seenLineIds.add(line.id)
        }
        const publicStory = published.sections.find(
          (candidate) => candidate.conceptKey === section.conceptKey,
        )!.scienceStory
        const summaryConcept = published.concepts.find(
          (candidate) => candidate.key === section.conceptKey,
        )!
        assert.equal(summaryConcept.storyTitle, story.title)
        assert.deepEqual(publicStory, story)
        assert.notEqual(publicStory, story)
        publishedStories.push(publicStory)
      }
    }
    assert.equal(publishedStories.length, 11)
    assert.equal(new Set(publishedStories.map((story) => story.id)).size, 11)
    assert.equal(new Set(publishedStories.map((story) => story.title)).size, 11)
    assert.equal(new Set(publishedStories.map((story) => story.setting)).size, 11)
    assert.equal(new Set(publishedStories.map((story) => story.punchline.text)).size, 11)
  })

  it('22 trace taskを公開し、未知field・欠落・範囲外・短すぎ・重複参照を拒否する', () => {
    const tasks = Object.values(NOTATION_LABS).flatMap((lab) => lab.orderTasks)
    assert.equal(tasks.length, 22)
    assert.equal(new Set(tasks.map((task) => task.id)).size, 22)
    for (const task of tasks) {
      assert.ok(task.tracePattern.semanticsLabel.trim())
      assert.ok(task.tracePattern.strokes.length >= 1)
      assert.equal(
        new Set(task.tracePattern.strokeOrderIds).size,
        task.tracePattern.strokes.length,
      )
      for (const stroke of task.tracePattern.strokes) {
        assert.ok(stroke.points.length >= 3)
        assert.ok(stroke.points.every(
          (point) => point.x >= 0 && point.x <= 1 && point.y >= 0 && point.y <= 1,
        ))
      }
    }

    const source = notationLabFor('fall')!
    const broken = () => structuredClone(source)

    const missing = broken()
    missing.orderTasks[0]!.tracePattern.strokes = []
    assert.ok(validateNotationLab(missing).some((problem) => problem.includes('trace')))

    const missingPattern = broken()
    delete (missingPattern.orderTasks[0]! as { tracePattern?: unknown }).tracePattern
    assert.ok(
      validateNotationLab(missingPattern).some((problem) => problem.includes('必須field欠落')),
    )

    const unknownField = broken()
    Object.assign(unknownField.orderTasks[0]!.tracePattern.strokes[0]!, {
      futureGestureAnswer: true,
    })
    assert.ok(
      validateNotationLab(unknownField).some((problem) => problem.includes('未知field')),
    )

    const outOfRange = broken()
    outOfRange.orderTasks[0]!.tracePattern.strokes[0]!.points[0]!.x = 1.1
    assert.ok(validateNotationLab(outOfRange).some((problem) => problem.includes('範囲外')))

    const tooShort = broken()
    tooShort.orderTasks[0]!.tracePattern.strokes[0]!.points = [
      { x: 0.1, y: 0.1 },
      { x: 0.2, y: 0.1 },
    ]
    assert.ok(validateNotationLab(tooShort).some((problem) => problem.includes('短すぎる')))

    const duplicateReference = broken()
    const firstId = duplicateReference.orderTasks[0]!.tracePattern.strokeOrderIds[0]!
    duplicateReference.orderTasks[0]!.tracePattern.strokeOrderIds = [firstId, firstId, firstId]
    assert.ok(
      validateNotationLab(duplicateReference).some(
        (problem) => problem.includes('strokeOrderIds'),
      ),
    )
  })

  it('33variantが監査どおり異なる認知操作を持ち、表示順で正答を示さない', () => {
    const expected = {
      fall: [
        ['singleSelect', 'prediction'],
        ['sequence', 'causalOrder'],
        ['classify', 'experimentPlan'],
      ],
      inertia: [
        ['singleSelect', 'prediction'],
        ['classify', 'conditionClassify'],
        ['singleSelect', 'forceDirection'],
      ],
      friction: [
        ['classify', 'experimentPlan'],
        ['sequence', 'causalOrder'],
        ['singleSelect', 'prediction'],
      ],
      throwUp: [
        ['classify', 'forceDirection'],
        ['sequence', 'causalOrder'],
        ['classify', 'forceDirection'],
      ],
      actionReaction: [
        ['classify', 'forceDirection'],
        ['singleSelect', 'quantityCompare'],
        ['classify', 'quantityCompare'],
      ],
      balance: [
        ['classify', 'forceDirection'],
        ['classify', 'conditionClassify'],
        ['sequence', 'causalOrder'],
      ],
      pressure: [
        ['classify', 'experimentPlan'],
        ['singleSelect', 'quantityCompare'],
        ['singleSelect', 'quantityCompare'],
      ],
      buoyancy: [
        ['classify', 'experimentPlan'],
        ['singleSelect', 'quantityCompare'],
        ['classify', 'conditionClassify'],
      ],
      currentMagneticField: [
        ['sequence', 'experimentPlan'],
        ['singleSelect', 'forceDirection'],
        ['classify', 'experimentPlan'],
      ],
      magneticForce: [
        ['classify', 'forceDirection'],
        ['classify', 'conditionClassify'],
        ['sequence', 'causalOrder'],
      ],
      electromagneticInduction: [
        ['sequence', 'causalOrder'],
        ['classify', 'conditionClassify'],
        ['classify', 'experimentPlan'],
      ],
    } as const
    const directSignals: Readonly<Record<string, readonly RegExp[]>> = {
      fall: [/平らな紙.*丸めた紙/, /着地時刻.*空気.*抵抗/, /質量.*高さ.*着く時刻/],
      inertia: [/指が離れ.*摩擦/, /合力/, /コースの中心方向/],
      friction: [/面の材質.*止まるまでの距離/, /摩擦.*速さの減り方/, /時間も距離も長く/],
      throwUp: [/上昇中.*高い点.*下降中/, /力と加速度.*下向き/, /水平成分.*鉛直成分.*受ける力/],
      actionReaction: [/手がかべ.*かべが手/, /力は同じ大きさ.*加速度/, /力の大きさ.*速度変化/],
      balance: [/重力.*床.*合力/, /一定速度.*速く.*遅く/, /空気抵抗.*終端速度/],
      pressure: [/広い面.*細い辺.*へこみ/, /圧力は2倍/, /Bの圧力/],
      buoyancy: [/油粘土.*浮くか沈むか/, /水中.*油中/, /液体の圧力.*浮力/],
      currentMagneticField: [
        /電池の向き.*電流を流さない.*振れ/,
        /反対側へ振れる/,
        /電流の大きさ.*巻き数.*振れ/,
      ],
      magneticForce: [
        /電流だけ.*磁界だけ.*両方/,
        /90度.*平行/,
        /回転.*反対向きの力.*回す作用/,
      ],
      electromagneticInduction: [
        /磁石を止める.*N極を抜く.*N極を入れる/,
        /閉回路.*開回路/,
        /磁石.*速さ.*回路全体の抵抗/,
      ],
    }
    const usedKinds = new Set<string>()
    const usedOperations = new Set<string>()
    const selectPositions = [0, 0, 0]
    const answerSignalingId =
      /(^|[-_])(correct|incorrect|right|wrong|answer|solution|true|false|yes|no)(?=$|[-_])/i

    for (const section of UNITS.flatMap((unit) => unit.sections)) {
      const variants = localPracticeVariantsFor(section)
      assert.equal(variants[0]!.transferPrompt, section.tryIt)
      assert.deepEqual(
        variants.map((variant) => [
          variant.cognitiveTask.kind,
          variant.cognitiveTask.operation,
        ]),
        expected[section.conceptKey as keyof typeof expected],
        `${section.conceptKey}: 監査した割当からずれた`,
      )
      assert.ok(
        new Set(variants.map((variant) => variant.cognitiveTask.kind)).size >= 2,
        `${section.conceptKey}: 3周とも同じ操作`,
      )
      const conceptSelectPositions: number[] = []
      variants.forEach((variant, index) => {
        const task = variant.cognitiveTask
        usedKinds.add(task.kind)
        usedOperations.add(task.operation)
        assert.match(
          JSON.stringify(task),
          directSignals[section.conceptKey]![index]!,
          `${section.conceptKey}/${variant.stage}: transferPromptへ直接答えるtaskでない`,
        )
        assert.equal(new Set(task.items.map((item) => item.id)).size, task.items.length)
        for (const item of task.items) {
          assert.ok(item.id.trim() && item.text.trim())
          assert.doesNotMatch(item.id, answerSignalingId)
        }
        if (task.kind === 'singleSelect') {
          const selected = task.items.findIndex(
            (item) => item.id === task.solution.selectedItemId,
          )
          assert.ok(selected >= 0)
          selectPositions[selected] = (selectPositions[selected] ?? 0) + 1
          conceptSelectPositions.push(selected)
        } else if (task.kind === 'sequence') {
          assert.deepEqual(
            new Set(task.solution.orderedItemIds),
            new Set(task.items.map((item) => item.id)),
          )
          assert.notDeepEqual(
            task.solution.orderedItemIds,
            task.items.map((item) => item.id),
            `${section.conceptKey}/${variant.stage}: 提示順が正答順`,
          )
        } else {
          const itemIds = task.items.map((item) => item.id)
          const targetIds = task.targets.map((target) => target.id)
          assert.deepEqual(
            new Set(Object.keys(task.solution.targetByItemId)),
            new Set(itemIds),
          )
          assert.ok(
            itemIds.every((id) =>
              targetIds.includes(task.solution.targetByItemId[id]!),
            ),
          )
          assert.ok(
            itemIds.some(
              (id, itemIndex) =>
                task.solution.targetByItemId[id]
                !== targetIds[itemIndex % targetIds.length],
            ),
            `${section.conceptKey}/${variant.stage}: itemとtargetの表示順が正答を示す`,
          )
        }
      })
      if (conceptSelectPositions.length > 1) {
        assert.ok(
          new Set(conceptSelectPositions).size > 1,
          `${section.conceptKey}: singleSelectの正答位置が固定`,
        )
      }
    }

    assert.deepEqual([...usedKinds].sort(), [...COGNITIVE_TASK_KINDS].sort())
    assert.deepEqual([...usedOperations].sort(), [...COGNITIVE_OPERATIONS].sort())
    assert.deepEqual(selectPositions, [3, 3, 3])
  })

  it('全conceptにsectionと固定misconceptionがちょうど1つずつ対応する', () => {
    const conceptKeys = UNITS.flatMap((unit) =>
      unit.concepts.map((concept) => concept.key),
    )
    assert.equal(
      new Set(conceptKeys).size,
      conceptKeys.length,
      'conceptKeyが単元をまたいで重複すると固定misconceptionが1対1に定まらない',
    )

    for (const unit of UNITS) {
      for (const concept of unit.concepts) {
        const sections = unit.sections.filter(
          (section) => section.conceptKey === concept.key,
        )
        const misconceptions = misconceptionsFor(concept.key)

        assert.equal(
          sections.length,
          1,
          `${unit.id}/${concept.key}: sectionはちょうど1つ必要`,
        )
        assert.equal(
          misconceptions.length,
          1,
          `${unit.id}/${concept.key}: 固定misconceptionはちょうど1つ必要`,
        )
        assert.ok(
          sections[0]!.tryIt.trim().length > 0,
          `${unit.id}/${concept.key}: CASEに使うtryItが空`,
        )
      }
    }
  })

  it('Pickerに公開する全ミッションがMaterialとDirectorの同じconceptへ進める', () => {
    const listResponse = getUnits({ lang: 'ja' })
    const listed = (listResponse.body as { units: PublicUnit[] }).units

    assert.deepEqual(
      listed.map((unit) => unit.id),
      UNITS.map((unit) => unit.id),
      'Pickerに公開する単元が正カタログとずれている',
    )
    assert.equal(
      new Set(listed.flatMap((unit) => unit.concepts.map((concept) => concept.storyTitle))).size,
      11,
      'Story一覧で11件の固有事件名を公開していない',
    )

    for (const summary of listed) {
      const canonical = unitById(summary.id)
      assert.ok(canonical, `Pickerが未知の単元を表示している: ${summary.id}`)
      assert.deepEqual(
        summary.concepts.map((concept) => concept.key),
        canonical.concepts.map((concept) => concept.key),
        `${summary.id}: Pickerのミッション一覧が正カタログとずれている`,
      )

      const detailResponse = getUnits({ id: summary.id, lang: 'ja' })
      const detailEnvelope = detailResponse.body as {
        schemaVersion: unknown
        unit: PublicUnit
      }
      assert.equal(
        detailEnvelope.schemaVersion,
        BUNDLED_UNIT_CATALOG_SCHEMA_VERSION,
      )
      const detail = detailEnvelope.unit
      const sections = detail.sections
      assert.ok(sections, `${summary.id}: Material用教材が無い`)
      assert.deepEqual(
        detail.concepts,
        summary.concepts,
        `${summary.id}: 一覧と詳細のconcept summaryが不一致`,
      )

      for (const mission of summary.concepts) {
        const materialSections: PublicSection[] = sections.filter(
          (section) => section.conceptKey === mission.key,
        )
        assert.equal(
          materialSections.length,
          1,
          `${summary.id}/${mission.key}: Pickerから開くMaterialが1つに定まらない`,
        )
        assert.equal(
          mission.storyTitle,
          materialSections[0]!.scienceStory.title,
          `${summary.id}/${mission.key}: Story一覧と詳細の事件名が不一致`,
        )
        const speaking = materialSections[0]!.localSpeakingPractice
        assert.ok(
          Array.from(speaking.targetPhrase).length >= 12,
          `${summary.id}/${mission.key}: Speaking目標語句が短すぎる`,
        )
        assert.equal(
          speaking.acceptedTranscripts[0],
          speaking.targetPhrase,
          `${summary.id}/${mission.key}: 表示正本が受理候補の先頭にない`,
        )
        const checkpoint = materialSections[0]!.localCheckpoint
        assert.equal(checkpoint.options.length, 3)
        assert.ok(
          checkpoint.options.some((option) => option.id === checkpoint.correctOptionId),
          `${summary.id}/${mission.key}: 公開詳細のcheckpointに正答が無い`,
        )
        const variants = materialSections[0]!.localPracticeVariants
        assert.deepEqual(variants.map((variant) => variant.stage), LOCAL_PRACTICE_STAGES)
        assert.deepEqual(variants[0]!.checkpoint, checkpoint)

        const focused = focusUnit(canonical, mission.key)
        assert.ok(focused, `${summary.id}/${mission.key}: focusUnitで進めない`)
        assert.deepEqual(focused.concepts.map((concept) => concept.key), [mission.key])
        assert.deepEqual(focused.sections.map((section) => section.conceptKey), [mission.key])

        const directorInput = parseInput({
          unitId: summary.id,
          focusConceptKey: mission.key,
          utterances: [],
          secondsLeft: 600,
          turnCount: 0,
        })
        assert.ok(
          !('error' in directorInput),
          `${summary.id}/${mission.key}: Directorに入れない: ${JSON.stringify(directorInput)}`,
        )
        assert.equal(directorInput.focusConceptKey, mission.key)
        assert.deepEqual(
          directorInput.dossier.slots.map((slot) => slot.key),
          [mission.key],
          `${summary.id}/${mission.key}: Directorのカルテに別概念が混ざっている`,
        )
        assert.equal(
          directorInput.dossier.slots[0]?.probes.length,
          1,
          `${summary.id}/${mission.key}: Directorの固定誘発が1つに定まらない`,
        )
      }
    }
  })

  it('理科教材の成立条件と安全なCASEを失わない', () => {
    const forceMotion = unitById('force-motion')!
    const forceBalance = unitById('force-balance')!
    const pressureBuoyancy = unitById('pressure-buoyancy')!
    const currentMagnetism = unitById('current-magnetism')!

    const inertia = forceMotion.concepts.find((concept) => concept.key === 'inertia')!
    assert.match(inertia.intent, /合力.*ゼロ/)
    assert.match(inertia.intent, /速さと向き.*等速直線運動/)

    const friction = forceMotion.sections.find((section) => section.conceptKey === 'friction')!
    assert.match(friction.body.join(''), /摩擦だけでなく.*空気抵抗.*すべてゼロ/)

    const throwUp = forceMotion.sections.find((section) => section.conceptKey === 'throwUp')!
    assert.match(throwUp.body.join(''), /空気抵抗を無視できるとき.*重力だけ/)
    assert.match(throwUp.tryIt, /空気抵抗を無視/)

    const actionReaction = forceBalance.sections.find(
      (section) => section.conceptKey === 'actionReaction',
    )!
    const balance = forceBalance.sections.find((section) => section.conceptKey === 'balance')!
    assert.match(actionReaction.body.join(''), /別々の物体にはたらく力/)
    assert.match(balance.body.join(''), /同じ1つの物体.*個別の力が無くなったわけでは/)
    assert.match(balance.body.join(''), /路面がタイヤを前向きに押す力/)

    const pressure = pressureBuoyancy.sections.find(
      (section) => section.conceptKey === 'pressure',
    )!
    assert.doesNotMatch(pressure.tryIt, /鉛筆|手のひら/)
    assert.match(pressure.tryIt, /スポンジ.*粘土/)

    const buoyancy = pressureBuoyancy.sections.find(
      (section) => section.conceptKey === 'buoyancy',
    )!
    const buoyancyText = buoyancy.body.join('')
    assert.match(buoyancyText, /同じ液体/)
    assert.match(buoyancyText, /完全に水没/)
    assert.match(buoyancyText, /体積が変わらない/)

    assert.deepEqual(
      currentMagnetism.concepts.map((concept) => concept.key),
      ['currentMagneticField', 'magneticForce', 'electromagneticInduction'],
      '学習指導要領の「電流と磁界」3項目を欠かさない',
    )

    const currentField = currentMagnetism.sections.find(
      (section) => section.conceptKey === 'currentMagneticField',
    )!
    assert.match(currentField.body.join(''), /導線の周囲の空間に磁界/)
    assert.match(currentField.body.join(''), /磁力線.*磁界.*向き/)
    assert.match(currentField.body.join(''), /コイルにすると.*外側にも続く.*棒磁石に似た磁界/)
    assert.match(currentField.body.join(''), /電流の向きを逆にすると磁界の向きも逆/)
    assert.match(currentField.body.join(''), /電流を大きくすると磁界は強く/)
    assert.match(currentField.tryIt, /低電圧/)
    assert.match(currentField.tryIt, /両極を導線で直結せず/)
    assert.match(currentField.tryIt, /家庭用コンセントにはつながず/)

    const magneticForce = currentMagnetism.sections.find(
      (section) => section.conceptKey === 'magneticForce',
    )!
    assert.match(magneticForce.body.join(''), /どちらか一方だけを逆にすると、力の向きも逆/)
    assert.match(magneticForce.body.join(''), /平行または反平行.*力はゼロ/)
    assert.match(magneticForce.tryIt, /一度に変える条件は一つだけ/)

    const induction = currentMagnetism.sections.find(
      (section) => section.conceptKey === 'electromagneticInduction',
    )!
    const inductionText = induction.body.join('')
    assert.match(inductionText, /磁束.*磁界の強さ.*コイルの面積.*向き/)
    assert.match(inductionText, /磁束が変化すると.*誘導電圧/)
    assert.match(inductionText, /閉回路なら.*誘導電流/)
    assert.match(inductionText, /回路が開いている場合.*電流は流れません/)
    assert.match(inductionText, /磁石をコイルの中で止めると.*ゼロ/)
    assert.match(inductionText, /入れる向きから抜く向き.*誘導電流の向きも逆/)
    assert.match(inductionText, /N極からS極.*誘導電流の向きも逆/)
    assert.match(inductionText, /巻き数を増やす.*誘導電圧が加わり.*全体の誘導電圧/)
    assert.match(inductionText, /誘導電流.*回路全体の抵抗.*抵抗も同じ/)
    assert.match(inductionText, /発電機.*コイルを貫く磁束を変え/)
    assert.match(inductionText, /直流.*向きが一定.*交流.*周期的に変わる/)
    assert.match(induction.tryIt, /電源はつながず/)
  })

  it('2・3周目も11conceptの成立条件を外さず、別の科学的判断を要求する', () => {
    function text(unitId: string, conceptKey: string): string {
      const unit = unitById(unitId)!
      const section = unit.sections.find((candidate) => candidate.conceptKey === conceptKey)!
      return JSON.stringify(localPracticeVariantsFor(section))
    }

    const fall = text('force-motion', 'fall')
    assert.match(fall, /空気抵抗/)
    assert.match(fall, /真空中なら形や重さによらず落下加速度は同じ/)

    const inertia = text('force-motion', 'inertia')
    assert.match(inertia, /合力がゼロなら.*速さと向き/)
    assert.match(inertia, /円運動.*速度の向きが変化.*合力はゼロではありません/)

    const friction = text('force-motion', 'friction')
    assert.match(friction, /重力は下向き/)
    assert.match(friction, /摩擦が小さく.*速さがゆっくり減り/)

    const throwUp = text('force-motion', 'throwUp')
    assert.match(throwUp, /上昇中も最高点でも下降中も重力は下向き/)
    assert.match(throwUp, /最高点でゼロになるのは鉛直速度/)

    const actionReaction = text('force-balance', 'actionReaction')
    assert.match(actionReaction, /同じ大きさで反対向き/)
    assert.match(actionReaction, /別々の物体にはたらくので互いに打ち消しません/)

    const balance = text('force-balance', 'balance')
    assert.match(balance, /一定速度なら加速度はゼロ/)
    assert.match(balance, /重力と空気抵抗がつり合い/)

    const pressure = text('pressure-buoyancy', 'pressure')
    assert.match(pressure, /面積だけを半分.*圧力は2倍/)
    assert.match(pressure, /100÷0\.5=200 Pa.*60÷0\.2=300 Pa/)

    const buoyancy = text('pressure-buoyancy', 'buoyancy')
    assert.match(buoyancy, /密度が大きい液体ほど.*浮力も大きい/)
    assert.match(buoyancy, /完全に水没し体積も変わらないなら.*深さだけでは変わりません/)

    const field = text('current-magnetism', 'currentMagneticField')
    assert.match(field, /電流の向きを逆にすると.*磁界も逆向き/)
    assert.match(field, /電流と巻き数を同時に変えると.*分けられません/)

    const force = text('current-magnetism', 'magneticForce')
    assert.match(force, /平行または反平行のときゼロ/)
    assert.match(force, /異なる位置にはたらくこの一組の力がコイルを回す/)

    const induction = text('current-magnetism', 'electromagneticInduction')
    assert.match(induction, /磁束の変化によって誘導電圧.*回路が開いていると/)
    assert.match(induction, /回路全体の抵抗も同じ/)
  })

  it('33の具体場面それぞれに、checkpointと別の直接な結果と理由が対応する', () => {
    const signals: Readonly<Record<string, readonly RegExp[]>> = {
      fall: [
        /丸めた紙が先.*平らな紙.*遅く/,
        /着地時刻の差は小さく.*真空.*ほぼ同時/,
        /重い球と軽い球は同時/,
      ],
      inertia: [
        /指が離れた後.*進み続け.*止.*摩擦/,
        /速さと右向きを保.*進み続け/,
        /合力はゼロではなく.*円の中心方向/,
      ],
      friction: [
        /タオルの上.*早く止まり.*距離.*短く/,
        /なめらかな面.*長い距離/,
        /摩擦がより小さい面.*時間も距離も長く/,
      ],
      throwUp: [
        /鉛直速度.*ゼロ.*力は下向き/,
        /最高点の直前でも直後でも.*下向き.*変わりません/,
        /水平方向へ動き続け.*下向きの重力/,
      ],
      actionReaction: [
        /同じ大きさで反対向き.*別々の物体/,
        /力は同じ大きさで反対向き.*質量が小さい人.*大きく加速/,
        /軽いスケーター.*大きな速度変化/,
      ],
      balance: [
        /一定速度.*床.*重力.*合力はゼロ/,
        /一定速度なら合力はゼロ.*速くなって.*合力は上向き/,
        /重力と上向きの空気抵抗.*同じ大きさ.*合力はゼロ/,
      ],
      pressure: [
        /細い辺.*狭く深いへこみ/,
        /面積を半分.*圧力は2倍/,
        /200 Pa.*300 Pa.*Bのほうが大きい/,
      ],
      buoyancy: [
        /球は沈み.*舟の形.*浮かせ/,
        /水中のほうが大きな浮力/,
        /浅い位置でも深い位置でも変わりません/,
      ],
      currentMagneticField: [
        /電流を流す.*方位磁針.*振れる側.*反対/,
        /電流なしの基準.*振れる側は反対/,
        /Bがつくる磁界.*強く.*方位磁針.*大きく振れ/,
      ],
      magneticForce: [
        /電流だけ.*反転.*磁界だけ.*反転.*両方.*元の向き/,
        /90度.*0度.*最大.*ゼロ/,
        /反対向きの力.*コイルを回し/,
      ],
      electromagneticInduction: [
        /N極.*入れる間.*止めるとゼロ.*抜く間.*反対方向/,
        /閉回路と開回路.*誘導電圧.*閉回路.*検流計.*開回路.*流れません/,
        /速く入れる.*誘導電圧.*検流計.*大きく振れ/,
      ],
    }

    const sections = UNITS.flatMap((unit) => unit.sections)
    assert.equal(Object.keys(signals).length, sections.length)
    for (const section of sections) {
      const variants = localPracticeVariantsFor(section)
      const conceptSignals = signals[section.conceptKey]
      assert.ok(conceptSignals, `${section.conceptKey}: 直接回答のレビュー定義が無い`)
      assert.equal(conceptSignals.length, variants.length)
      assert.equal(
        new Set(
          variants.map((variant) =>
            JSON.stringify([
              variant.transferPrompt,
              variant.expectedOutcome,
              variant.expectedReason,
            ]),
          ),
        ).size,
        3,
        `${section.conceptKey}: 場面と直接回答を再利用している`,
      )
      variants.forEach((variant, index) => {
        const directAnswer = `${variant.expectedOutcome}${variant.expectedReason}`
        assert.match(
          directAnswer,
          conceptSignals[index]!,
          `${section.conceptKey}/${variant.stage}: transferPromptへ直接答えていない`,
        )
      })
    }
  })
})
