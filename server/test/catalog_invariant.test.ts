import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { describe, it } from 'node:test'

import { parseInput } from '../api/director.js'
import unitsHandler from '../api/units.js'
import { MISCONCEPTIONS, misconceptionsFor } from '../lib/misconceptions.js'
import {
  CURRICULUM_COVERAGE_MANIFEST,
  CURRICULUM_FIELDS,
  CURRICULUM_SAFETY_LEVELS,
} from '../lib/curriculum-coverage.js'
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
  NOTATION_TASK_KINDS,
  canonicalNotationTasks,
  isNotationArrangeTask,
  notationLabFor,
  publicNotationLab,
  type TaggedNotationLab,
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
  density: ['そっくりボトルの重さ交換事件', '家庭科室の安定した机。同じ容器に同じ体積の水と食用油を入れ、ふたを閉めてある。', '密度は育たず、育ったのは容器を洗う仕事だけでした。'],
  cells: ['消えた葉緑体と根っこの証言', '理科室の画像資料コーナー。葉の細胞、根の細胞、動物組織の顕微鏡画像を並べている。', '葉緑体は欠席、でも根っこの植物籍はそのままでした。'],
  humidityClouds: ['コップの外だけ局地雨', '教室の机。乾いた同じコップを並べ、片方だけに冷水を入れて外側を観察する。', 'コップの局地雨、予報範囲は半径5センチでした。'],
  strataRelativeAge: ['紙の崖に残った斜め線のアリバイ', '図書室の大机。色紙の地層模型に、下の3層を切る斜め線と、それを覆う上層がある。', '紙の崖は動かず、ぼくの年代順だけが大逆転していました。'],
  gasProperties: ['透明気体の捕集法取り違え事件', '理科室の資料机。酸素・二酸化炭素・水素・アンモニアの固定性質表と捕集法カードが並ぶ。', '透明気体チーム、性質表を読んだら全員別ポジションでした。'],
  stateChangeMass: ['消えた液体1.5グラムの行方', '教室の測定資料コーナー。開いた皿と密閉袋の蒸発前後データを画面で比較している。', '1.5グラムは消失せず、測定範囲の外へお引っ越しでした。'],
  photosynthesisRespiration: ['植物工場の夜勤呼吸員', '図書室のデータ端末。水草の明所・暗所における酸素変化の固定グラフを開いている。', '呼吸員は夜勤専属ではなく、まさかの24時間シフトでした。'],
  digestionAbsorption: ['栄養分の小腸入国審査', '保健室前の教材机。消化管図と栄養分カードを使い、食べ物や人体試料には触れず考える。', '栄養分の通行証は「消化ずみ」、入国ゲートは小腸でした。'],
  fronts: ['天気図に残った暖気の足あと', '放送室の資料画面。過去の温暖前線と気温・雲・降水の時系列を室内で確認する。', '暖気の足あとは地下ではなく、雲の階段に残っていました。'],
  pressurePatternsWind: ['等圧線ぎゅうぎゅう区画の強風予告', '気象資料室。過去の天気図で等圧線間隔と同時刻の観測風速を照合している。', '等圧線は通行止めロープではなく、風の坂道の等高線でした。'],
  volcanoEarthquakes: ['火山マークと震央マークの別行動', '防災学習室。公的な火山・震央・プレート境界の過去分布図を重ねている。', '地図ではご近所、事件簿では別々の担当でした。'],
  dailyMotionSeasons: ['星空カレンダー一日と一年の混線', 'プラネタリウム教室。同じ場所の一晩と、同時刻で月を変えた星空シミュレーションを比べる。', '星空カレンダー、24時間欄と12か月欄を同じマスに書いていました。'],
  combinationDecomposition: ['混ぜただけ粉チームの冤罪事件', '家庭科室の資料棚。鉄粉と硫黄を混ぜた粉末と、加熱後の黒いかたまりの観察記録が並ぶ。', '瞬間化合説、磁石の前で見事に散りました。'],
  oxidationReduction: ['赤い汚れの正体を追え', '昇降口のフェンスの写真と、学校で保存されたさびの観察記録が開かれている。', '犯人は空で合ってた！でも手口は「酸素と結びつく」でした。'],
  massConservation: ['消えた1.1グラムの密室', '理科室の測定記録。開いた容器と密閉袋で同じ反応をさせた二つの表が残る。', '消えた質量、実は窓から出ていった二酸化炭素でした。密室でも何でもない！'],
  electrolyte: ['消えた豆電球の容疑者たち', '理科室の資料机。食塩水では光り、砂糖水では消えた豆電球の実験記録と写真が並ぶ。', '甘さ仮説は溶解！真犯人は「イオンがいるかどうか」でした。'],
  acidAlkali: ['三色に分かれた液の身元', '放送室の資料画面。3つの液にBTB溶液を加えた記録で、黄・緑・青に分かれている。', '黄色はレモン味のサインじゃなくて、水素イオンのサインでした。飲まなくてよかった！'],
  neutralizationBattery: ['果物電池に宿った電気の行方', '図書室の資料端末。レモンに亜鉛板と銅板を差して電流が流れた記録と、乾電池の写真がある。', '電気は果汁に宿ってたんじゃなくて、金属たちの「なりたさ」の差で流れてました。レモンさん、疑ってごめん！'],  reproduction: ['親そっくり署のジャガイモ偽装事件', '理科準備室の棚。発芽したジャガイモと、受精して育つカエルの観察記録が並んでいる。', 'ジャガイモは恋しなくても増えるってことか！親そっくり署、無性生殖の線で結論です！'],
  heredity: ['しわしわ種子の突然復帰事件', '理科準備室の実験台。エンドウの交配記録カードが広げられ、丸の親からしわの子が出た一行が強調されている。', 'しわは消えてなかった！親の中にかくれて、孫でカムバック。記録係さんごめん、君は正しかった！'],
  evolution: ['化石ラインナップの順番入れ替え事件', '放課後の理科室。地層ごとの化石写真が時代順に並べられ、古い層と新しい層で姿が違うことが確認されている。', '努力で首が伸びたんじゃなくて、長い首の仲間が多く残ったのか！キリンさん、頑張り屋さんでごめん！'],
  energyResources: ['電気製造工場の原材料不明事件', '理科室の資料棚。「発電方法別の割合」の円グラフと、ある月の電気料金明細が開かれている。', '電気の原材料は「エネルギー」でした！工場長、材料発注は地球頼みだ！'],
  natureBalance: ['池の数表、連鎖反応事件', '学校近くの池の生き物調査記録。水草・草食魚・肉食魚の数が3年分並んでいる。', '池の数表は「連鎖のお知らせ」だった！水草さん、見放してごめん！'],
  sustainableSociety: ['台風を消す装置の設計図事件', '防災学習室。地域のハザードマップと過去の浸水記録が開かれている。', '台風消去装置は開発中止！ハザードマップと避難計画、ぼくの名案は「備え」だった！'],

} as const

type PublicConcept = {
  key: string
  label: string
  storyTitle: string
  field: string
  grade: number
  curriculumRefs: unknown[]
  prerequisites: string[]
  difficulty: number
  safety: { level: string; guidance: string }
}
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
  notationLab: TaggedNotationLab
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
  it('Stage 1の4単元が各3概念を1本のPathへ統合する', () => {
    const expectedStage1 = {
      'matter-properties': ['density', 'gasProperties', 'stateChangeMass'],
      'living-body': ['cells', 'photosynthesisRespiration', 'digestionAbsorption'],
      'weather-change': ['humidityClouds', 'fronts', 'pressurePatternsWind'],
      'earth-history': ['strataRelativeAge', 'volcanoEarthquakes', 'dailyMotionSeasons'],
    } as const

    assert.equal(UNITS.length, 12)
    assert.equal(UNITS.flatMap((unit) => unit.concepts).length, 35)
    for (const [unitId, conceptKeys] of Object.entries(expectedStage1)) {
      const unit = unitById(unitId)
      assert.ok(unit, `${unitId}: Stage 1 unitが無い`)
      assert.deepEqual(
        unit.concepts.map((concept) => concept.key),
        conceptKeys,
      )
      assert.deepEqual(
        unit.sections.map((section) => section.conceptKey),
        conceptKeys,
      )
    }
  })

  it('35概念のSpeaking目標を正本化し、欠落・未知field・短文・重複を拒否する', () => {
    const sections = UNITS.flatMap((unit) => unit.sections)
    assert.equal(sections.length, 35)
    assert.equal(
      new Set(sections.map((section) => section.conceptKey)).size,
      35,
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

  it('全35conceptが3周で異なる問い・正答位置・誤答だけのヒントを持つ', () => {
    assert.deepEqual(validateCatalog(), [])

    const sections = UNITS.flatMap((unit) => unit.sections)
    assert.equal(sections.length, 35)
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
      const codes = canonicalNotationTasks(notation).map((task) => task.needCode)
      notationCount += codes.length
      for (const code of codes) {
        assert.match(
          code,
          new RegExp(`^science\\.${section.conceptKey}\\.notation\\.`),
        )
        notationCodes.add(code)
      }
    }

    assert.equal(cognitiveCount, 105)
    assert.equal(wrongOptionCount, 210)
    assert.equal(notationCount, 116)
    assert.equal(practiceCodes.size, 105)
    assert.equal(notationCodes.size, 116)
  })

  it('全35concept×3stageのListening聞き取り/意味needを別codeで公開する', () => {
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
    assert.equal(variantCount, 105)
    assert.equal(codes.size, 210)
    assert.throws(() => scienceListeningNeedCodes('unknown-concept', 'foundation'))
  })

  it('全35conceptのNotationをcanonical tagged unionへ損失なく公開し、6種類を網羅する', () => {
    const sections = UNITS.flatMap((unit) => unit.sections)
    assert.equal(sections.length, 35)
    assert.deepEqual(
      new Set(Object.keys(NOTATION_LABS)),
      new Set(sections.map((section) => section.conceptKey)),
    )
    const usedKinds = new Set<string>()
    let taskCount = 0

    for (const section of sections) {
      const source = notationLabFor(section.conceptKey)
      assert.ok(source, `${section.conceptKey}: Notation正本が無い`)
      const canonical = canonicalNotationTasks(source)
      const unit = UNITS.find((candidate) => candidate.sections.includes(section))!
      const published = publicUnitDetail(unit).sections.find(
        (candidate) => candidate.conceptKey === section.conceptKey,
      )!
      assert.deepEqual(published.notationLab, publicNotationLab(source))
      assert.notEqual(published.notationLab, source, '公開形は正本の参照を共有しない')
      assert.notEqual(published.notationLab.tasks, canonical)
      assert.equal(published.notationLab.tasks.length, canonical.length)
      taskCount += canonical.length
      assert.deepEqual(validateNotationLab(published.notationLab), [], section.conceptKey)

      published.notationLab.tasks.forEach((task, index) => {
        assert.deepEqual(task, canonical[index], `${section.conceptKey}/${task.id}: task投影が損失`)
        assert.notEqual(task, canonical[index], `${section.conceptKey}/${task.id}: task参照を共有`)
        usedKinds.add(task.kind)
        if (isNotationArrangeTask(task)) {
          assert.notDeepEqual(
            task.tokens.map((token) => token.id),
            task.correctOrderIds,
            `${section.conceptKey}/${task.id}: 表示順が正答順`,
          )
        } else {
          assert.ok(task.representationSemanticsLabel.trim())
          assert.ok(
            task.choices.some((choice) => choice.id === task.correctChoiceId),
            `${section.conceptKey}/${task.id}: 正答choiceが無い`,
          )
        }
      })
    }

    assert.equal(taskCount, 116)
    assert.deepEqual([...usedKinds].sort(), [...NOTATION_TASK_KINDS].sort())
    assert.equal(notationLabFor('unknown-concept'), undefined)
  })

  it('全35 Storyが固有の事件名・舞台・落ちを持ち、foundation正本へ完全一致する', () => {
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
    assert.equal(publishedStories.length, 35)
    assert.equal(new Set(publishedStories.map((story) => story.id)).size, 35)
    assert.equal(new Set(publishedStories.map((story) => story.title)).size, 35)
    assert.equal(new Set(publishedStories.map((story) => story.setting)).size, 35)
    assert.equal(new Set(publishedStories.map((story) => story.punchline.text)).size, 35)
  })

  it('既存22 trace taskを維持し、不正なtrace・taskを拒否する', () => {
    const tasks = Object.values(NOTATION_LABS)
      .flatMap(canonicalNotationTasks)
      .filter(isNotationArrangeTask)
      .filter((task) => task.tracePattern != null)
    assert.equal(tasks.length, 22)
    assert.equal(new Set(tasks.map((task) => task.id)).size, 22)
    for (const task of tasks) {
      const trace = task.tracePattern!
      assert.ok(trace.semanticsLabel.trim())
      assert.ok(trace.strokes.length >= 1)
      assert.equal(
        new Set(trace.strokeOrderIds).size,
        trace.strokes.length,
      )
      for (const stroke of trace.strokes) {
        assert.ok(stroke.points.length >= 3)
        assert.ok(stroke.points.every(
          (point) => point.x >= 0 && point.x <= 1 && point.y >= 0 && point.y <= 1,
        ))
      }
    }

    const source = publicNotationLab(notationLabFor('fall')!)
    const broken = () => structuredClone(source)
    const firstTrace = (lab: TaggedNotationLab) => {
      const task = lab.tasks.find(
        (candidate) => isNotationArrangeTask(candidate) && candidate.tracePattern != null,
      )
      if (task == null || !isNotationArrangeTask(task) || task.tracePattern == null) {
        throw new Error('fixtureにtrace taskが無い')
      }
      return task.tracePattern
    }

    const missing = broken()
    firstTrace(missing).strokes = []
    assert.ok(validateNotationLab(missing).some((problem) => problem.includes('trace')))

    const missingField = broken()
    delete (firstTrace(missingField) as { strokes?: unknown }).strokes
    assert.ok(
      validateNotationLab(missingField).some((problem) => problem.includes('必須field欠落')),
    )

    const unknownField = broken()
    Object.assign(firstTrace(unknownField).strokes[0]!, {
      futureGestureAnswer: true,
    })
    assert.ok(
      validateNotationLab(unknownField).some((problem) => problem.includes('未知field')),
    )

    const outOfRange = broken()
    firstTrace(outOfRange).strokes[0]!.points[0]!.x = 1.1
    assert.ok(validateNotationLab(outOfRange).some((problem) => problem.includes('範囲外')))

    const tooShort = broken()
    firstTrace(tooShort).strokes[0]!.points = [
      { x: 0.1, y: 0.1 },
      { x: 0.2, y: 0.1 },
    ]
    assert.ok(validateNotationLab(tooShort).some((problem) => problem.includes('短すぎる')))

    const duplicateReference = broken()
    const duplicateTrace = firstTrace(duplicateReference)
    const firstId = duplicateTrace.strokeOrderIds[0]!
    duplicateTrace.strokeOrderIds = [firstId, firstId, firstId]
    assert.ok(
      validateNotationLab(duplicateReference).some(
        (problem) => problem.includes('strokeOrderIds'),
      ),
    )

    const duplicateTask = broken()
    duplicateTask.tasks[1]!.id = duplicateTask.tasks[0]!.id
    assert.ok(validateNotationLab(duplicateTask).some((problem) => problem.includes('重複')))

    const mismatchedLegacyNeed = broken()
    const legacyArrange = mismatchedLegacyNeed.tasks.find(isNotationArrangeTask)
    if (legacyArrange == null) throw new Error('fixtureにarrange taskが無い')
    legacyArrange.kind = legacyArrange.kind === 'sequence' ? 'modelBuild' : 'sequence'
    assert.ok(
      validateNotationLab(mismatchedLegacyNeed).some(
        (problem) => problem.includes('task kind'),
      ),
    )

    const badChoice = publicNotationLab(notationLabFor('cells')!)
    const choiceTask = badChoice.tasks.find((task) => !isNotationArrangeTask(task))
    if (choiceTask == null || isNotationArrangeTask(choiceTask)) {
      throw new Error('fixtureにchoice taskが無い')
    }
    choiceTask.correctChoiceId = 'missing-choice'
    assert.ok(validateNotationLab(badChoice).some((problem) => problem.includes('choices')))
  })

  it('105variantが監査どおり異なる認知操作を持ち、表示順で正答を示さない', () => {
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
      density: [
        ['classify', 'quantityCompare'],
        ['singleSelect', 'experimentPlan'],
        ['sequence', 'causalOrder'],
      ],
      cells: [
        ['classify', 'conditionClassify'],
        ['sequence', 'experimentPlan'],
        ['singleSelect', 'experimentPlan'],
      ],
      humidityClouds: [
        ['sequence', 'causalOrder'],
        ['classify', 'conditionClassify'],
        ['singleSelect', 'prediction'],
      ],
      strataRelativeAge: [
        ['sequence', 'causalOrder'],
        ['classify', 'causalOrder'],
        ['singleSelect', 'prediction'],
      ],
      gasProperties: [
        ['classify', 'conditionClassify'],
        ['sequence', 'experimentPlan'],
        ['singleSelect', 'experimentPlan'],
      ],
      stateChangeMass: [
        ['sequence', 'causalOrder'],
        ['classify', 'conditionClassify'],
        ['singleSelect', 'quantityCompare'],
      ],
      photosynthesisRespiration: [
        ['classify', 'conditionClassify'],
        ['singleSelect', 'quantityCompare'],
        ['sequence', 'causalOrder'],
      ],
      digestionAbsorption: [
        ['sequence', 'causalOrder'],
        ['classify', 'experimentPlan'],
        ['singleSelect', 'prediction'],
      ],
      fronts: [
        ['sequence', 'causalOrder'],
        ['classify', 'conditionClassify'],
        ['singleSelect', 'prediction'],
      ],
      pressurePatternsWind: [
        ['classify', 'quantityCompare'],
        ['singleSelect', 'prediction'],
        ['sequence', 'causalOrder'],
      ],
      volcanoEarthquakes: [
        ['classify', 'conditionClassify'],
        ['sequence', 'causalOrder'],
        ['singleSelect', 'prediction'],
      ],
      dailyMotionSeasons: [
        ['classify', 'conditionClassify'],
        ['sequence', 'causalOrder'],
        ['singleSelect', 'prediction'],
      ],
      combinationDecomposition: [
        ['classify', 'conditionClassify'],
        ['singleSelect', 'experimentPlan'],
        ['sequence', 'causalOrder'],
      ],
      oxidationReduction: [
        ['singleSelect', 'prediction'],
        ['classify', 'conditionClassify'],
        ['sequence', 'causalOrder'],
      ],
      massConservation: [
        ['classify', 'conditionClassify'],
        ['singleSelect', 'quantityCompare'],
        ['singleSelect', 'experimentPlan'],
      ],
      electrolyte: [
        ['classify', 'conditionClassify'],
        ['singleSelect', 'experimentPlan'],
        ['sequence', 'causalOrder'],
      ],
      acidAlkali: [
        ['singleSelect', 'prediction'],
        ['classify', 'conditionClassify'],
        ['singleSelect', 'quantityCompare'],
      ],
      neutralizationBattery: [
        ['sequence', 'causalOrder'],
        ['singleSelect', 'prediction'],
        ['singleSelect', 'experimentPlan'],
      ],
      reproduction: [
        ['sequence', 'causalOrder'],
        ['classify', 'conditionClassify'],
        ['singleSelect', 'prediction'],
      ],
      heredity: [
        ['singleSelect', 'prediction'],
        ['classify', 'conditionClassify'],
        ['sequence', 'causalOrder'],
      ],
      evolution: [
        ['sequence', 'causalOrder'],
        ['singleSelect', 'prediction'],
        ['classify', 'conditionClassify'],
      ],
      energyResources: [
        ['sequence', 'causalOrder'],
        ['singleSelect', 'prediction'],
        ['classify', 'conditionClassify'],
      ],
      natureBalance: [
        ['singleSelect', 'prediction'],
        ['classify', 'conditionClassify'],
        ['singleSelect', 'prediction'],
      ],
      sustainableSociety: [
        ['sequence', 'causalOrder'],
        ['singleSelect', 'prediction'],
        ['classify', 'conditionClassify'],
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
      density: [
        /容器を含む全体の質量.*液体の体積.*水か食用油/,
        /各試料の質量と体積.*質量÷体積/,
        /PとQそれぞれの質量と体積.*質量を体積で割る/,
      ],
      cells: [
        /細胞壁.*細胞膜.*葉緑体.*細胞質/,
        /倍率・染色・採取部位.*境界や内部/,
        /細胞壁.*採取部位・観察条件/,
      ],
      humidityClouds: [
        /凝結.*コップに触れた.*露点/,
        /湿度80%.*湿度40%.*開始時の気温/,
        /膨張・冷却.*露点.*凝結/,
      ],
      strataRelativeAge: [
        /緑.*青・黄・白.*横切る/,
        /断層Fに切られた地層A.*断層Fの活動.*地層D/,
        /火山灰の特徴.*化石.*上下関係/,
      ],
      gasProperties: [
        /酸素.*水素.*アンモニア.*二酸化炭素/,
        /上方置換.*水に非常に溶けやすい.*アルカリ性/,
        /固定反応記録.*Xを酸素.*Yを二酸化炭素/,
      ],
      stateChangeMass: [
        /全質量.*液体の粒子配置.*密閉容器/,
        /皿A.*袋B.*測定値/,
        /全質量.*粒子種類.*体積.*配置/,
      ],
      photosynthesisRespiration: [
        /明所.*暗所.*光合成.*呼吸/,
        /正味0.*つり合う/,
        /酸素消費.*葉を除く.*茎の細胞は呼吸/,
      ],
      digestionAbsorption: [
        /柔毛.*大きな栄養分.*酵素/,
        /酵素X.*酵素Y.*デンプン.*タンパク質/,
        /柔毛のあるB.*表面積.*吸収/,
      ],
      fronts: [
        /気温.*暖気.*上昇.*層状/,
        /暖気が緩やか.*寒気が暖気.*狭い範囲.*広い範囲/,
        /通過傾向.*降水強度.*他条件/,
      ],
      pressurePatternsWind: [
        /等圧線間隔.*気圧差/,
        /Aは気圧傾度/,
        /低圧側.*地表摩擦.*自転.*曲げ/,
      ],
      volcanoEarthquakes: [
        /プレート境界.*岩盤.*ずれ.*マグマ.*上昇/,
        /爆発的.*粘り気.*気体/,
        /到着差12秒.*Q.*遠い.*別条件/,
      ],
      dailyMotionSeasons: [
        /一晩.*同時刻.*月.*公転.*自転/,
        /円弧.*地球が西から東.*天球が東から西/,
        /地軸の傾き.*日射角度.*昼の長さ/,
      ],
      combinationDecomposition: [
        /鉄粉と硫黄を混ぜて加熱.*磁石に引かれない.*化学変化.*物理的な変化/,
        /色だけを見て.*磁石へ近づけ.*鉄の性質/,
        /化学変化と判断.*反応前後の物質の性質を比較.*違う性質がないか/,
      ],
      oxidationReduction: [
        /燃えたので銅板は軽く.*酸素と結びついた分だけ重く/,
        /木や炭が燃える.*鉄がさびる.*呼吸.*氷がとける.*酸化/,
        /赤い光沢の銅.*酸化銅に炭素を混ぜて加熱.*酸素が炭素へ移り.*二酸化炭素/,
      ],
      massConservation: [
        /原子の種類.*結びつき方.*原子の数.*質量の和/,
        /逃げた気体の分を含めれば.*質量の総和は等しい/,
        /開いた容器で気体を逃がして.*密閉した容器で反応させて全体を測る/,
      ],
      electrolyte: [
        /食塩を溶かした水.*砂糖を溶かした水.*うすい塩酸.*電気を通す液.*電気を通さない液/,
        /液の色を見て.*においをかいで.*電極を入れて電圧をかけ.*物質ができるか/,
        /電極に新しい物質が生成.*電圧をかける.*イオンが電極へ移動/,
      ],
      acidAlkali: [
        /BTB溶液を加えると黄色.*青色.*緑色/,
        /ぬるぬる.*BTB溶液が黄色.*炭酸水素ナトリウム.*リトマス紙.*水素イオン.*水酸化物イオン/,
        /pH5の液のほうが.*酸性の強さは同じ.*pH3の液のほうが/,
      ],
      neutralizationBattery: [
        /塩の結晶ができる.*水素イオンと水酸化物イオンが結びつく.*酸とアルカリの性質が打ち消される/,
        /何も残らない.*塩の結晶が残る.*酸そのものが結晶/,
        /イオンへのなりやすさが違う2種類の金属板.*同じ金属の板を2枚.*電気を溜めた容器/,
      ],
      reproduction: [
        /細胞が2つに分かれ.*染色体が写し取られる.*成長し.*2つの核へ分けられる/,
        /カエルの受精卵.*ジャガイモの芽.*イチゴのランナー.*ニワトリの受精卵/,
        /有性生殖で育った畑は形質にばらつき.*同じ強さをもつ.*生き残る株の差は出ない/,
      ],
      heredity: [
        /すべて優性形質.*およそ3：1.*半々/,
        /組合せがaa.*組合せがAA.*組合せがAa.*もう一組/,
        /受精し、受精卵ができる.*形質が現れる.*染色体を半分にする.*体細胞分裂を繰り返し/,
      ],
      evolution: [
        /世代を経て集団の形質の割合が変わる.*ばらつきがある.*姿が変わり.*多く子を残す/,
        /明るい色の蛾が目立たず増える.*割合は変わらない.*暗色の蛾が見つかりにくく/,
        /首を伸ばした姿が子に伝わった.*ばらつきがあり、長い個体が多く子を残した.*暗い色の蛾が見つかりにくく.*足を使わなくなった/,
      ],
      energyResources: [
        /蒸気.*化学エネルギー.*発電機.*タービン/,
        /再生可能エネルギーは枯れない.*自然条件と設備の規模.*化石燃料は地中/,
        /石油.*天然ガス.*太陽光.*地熱.*枯渇性資源.*再生可能エネルギー/,
      ],
      natureBalance: [
        /水草が減ると水草を食べる魚も減り.*他の生物に影響はない.*消費者の数は変わらない/,
        /光合成をする植物.*ウサギ.*菌類.*タカ.*生産者.*消費者.*分解者/,
        /鳥が減っても虫の数は変わらない.*虫の数は一定に保たれる.*食べられる側の虫が増える/,
      ],
      sustainableSociety: [
        /危険な場所.*構造物や避難計画で備える.*過去の災害記録.*ハザードマップに示して共有/,
        /過去の記録とデータに基づく予測.*必ず災害が起き.*住民の感覚/,
        /化石燃料から再生可能エネルギー.*省エネ.*同じ割合.*変えない.*持続可能な選択.*持続可能でない選択/,
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
    assert.deepEqual(selectPositions, [13, 12, 12])
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

  it('35conceptのcoverage metadataをMEXT本文の印刷ページ番号（PageLabels）・前提・安全条件と1対1で公開する', () => {
    const conceptKeys = UNITS.flatMap((unit) =>
      unit.concepts.map((concept) => concept.key),
    )
    const coverageEntries = Object.values(CURRICULUM_COVERAGE_MANIFEST)
    assert.deepEqual(new Set(Object.keys(CURRICULUM_COVERAGE_MANIFEST)), new Set(conceptKeys))
    assert.equal(coverageEntries.length, 35)
    assert.deepEqual(
      new Set(coverageEntries.map((entry) => entry.field)),
      new Set(CURRICULUM_FIELDS),
      '物質・エネルギー・生命・地球の4領域をcoverageしていない',
    )

    const stage1Slice = {
      density: { unitId: 'matter-properties', field: 'matter', grade: 1, pages: [35, 36, 37], safety: 'homeSafe', prerequisites: [] },
      gasProperties: { unitId: 'matter-properties', field: 'matter', grade: 1, pages: [36, 37], safety: 'referenceOnly', prerequisites: [] },
      stateChangeMass: { unitId: 'matter-properties', field: 'matter', grade: 1, pages: [38, 39], safety: 'referenceOnly', prerequisites: [] },
      cells: { unitId: 'living-body', field: 'life', grade: 2, pages: [86, 87], safety: 'referenceOnly', prerequisites: [] },
      photosynthesisRespiration: { unitId: 'living-body', field: 'life', grade: 2, pages: [87, 88], safety: 'referenceOnly', prerequisites: ['cells'] },
      digestionAbsorption: { unitId: 'living-body', field: 'life', grade: 2, pages: [89, 90], safety: 'referenceOnly', prerequisites: ['cells'] },
      humidityClouds: { unitId: 'weather-change', field: 'earth', grade: 2, pages: [94, 95], safety: 'homeSafe', prerequisites: [] },
      fronts: { unitId: 'weather-change', field: 'earth', grade: 2, pages: [94, 95], safety: 'referenceOnly', prerequisites: ['humidityClouds'] },
      pressurePatternsWind: { unitId: 'weather-change', field: 'earth', grade: 2, pages: [95, 96, 97], safety: 'referenceOnly', prerequisites: ['fronts'] },
      strataRelativeAge: { unitId: 'earth-history', field: 'earth', grade: 1, pages: [81, 82], safety: 'homeSafe', prerequisites: [] },
      volcanoEarthquakes: { unitId: 'earth-history', field: 'earth', grade: 1, pages: [82, 83, 84], safety: 'referenceOnly', prerequisites: ['strataRelativeAge'] },
      dailyMotionSeasons: { unitId: 'earth-history', field: 'earth', grade: 3, pages: [104, 105, 106], safety: 'referenceOnly', prerequisites: [] },
    } as const

    for (const [conceptKey, expected] of Object.entries(stage1Slice)) {
      const coverage = CURRICULUM_COVERAGE_MANIFEST[conceptKey]!
      assert.equal(coverage.unitId, expected.unitId)
      assert.equal(coverage.field, expected.field)
      assert.equal(coverage.grade, expected.grade)
      assert.deepEqual(coverage.curriculumRefs[0]?.pages, expected.pages)
      assert.equal(coverage.safety.level, expected.safety)
      assert.deepEqual(coverage.prerequisites, expected.prerequisites)
    }

    const legacyPages = {
      fall: [54, 56],
      inertia: [54, 55],
      friction: [56, 57],
      throwUp: [55, 56],
      actionReaction: [55],
      balance: [54, 55],
      pressure: [92, 93],
      buoyancy: [52, 53],
      currentMagneticField: [44, 45],
      magneticForce: [44, 45],
      electromagneticInduction: [44, 45],
    } as const
    for (const [conceptKey, expectedPages] of Object.entries(legacyPages)) {
      assert.deepEqual(
        CURRICULUM_COVERAGE_MANIFEST[conceptKey]!.curriculumRefs[0]?.pages,
        expectedPages,
        `${conceptKey}: MEXT公式PDFに印刷された本文ページ番号（PageLabels）からずれている`,
      )
    }

    const stage1TryIts = Object.fromEntries(
      UNITS.flatMap((unit) => unit.sections)
        .filter((section) => Object.hasOwn(stage1Slice, section.conceptKey))
        .map((section) => [section.conceptKey, section.tryIt]),
    )
    assert.match(stage1TryIts.density!, /口に入れず.*こぼれたらすぐ拭/)
    assert.match(stage1TryIts.cells!, /家庭で人体から試料を取ったり、染色液を使ったりはしません/)
    assert.match(stage1TryIts.humidityClouds!, /安定した机.*密閉加熱や加圧はしません/)
    assert.match(stage1TryIts.strataRelativeAge!, /崖や工事現場には近づかず、岩石も採取しません/)
    const referenceOnlySafetySignals: Readonly<Record<string, RegExp>> = {
      gasProperties: /(学校配布|教科書).*(家庭|自分で).*(気体を発生|薬品|火).*(しません|行わない)/,
      stateChangeMass: /学校配布.*家庭で加熱・冷却・密閉実験は行いません/,
      photosynthesisRespiration: /学校配布.*薬品や火を使ったりしません/,
      digestionAbsorption: /教科書.*食べ物・薬品・人体試料を使う実験は行いません/,
      fronts: /公開した過去.*雷雨時や荒天時に屋外観察へ出ません/,
      pressurePatternsWind: /過去の地上天気図.*台風や強風を屋外で観察せず/,
      volcanoEarthquakes: /公的機関が公開.*被災地や火山へ出かけず/,
      dailyMotionSeasons: /教室内.*太陽を直接見たり、夜間に一人で屋外観察したりしません/,
    }
    for (const [conceptKey, signal] of Object.entries(referenceOnlySafetySignals)) {
      assert.match(
        stage1TryIts[conceptKey]!,
        signal,
        `${conceptKey}: referenceOnlyの固定資料と禁止条件がtryItに無い`,
      )
    }

    for (const unit of UNITS) {
      const published = publicUnitDetail(unit)
      for (const concept of published.concepts) {
        const coverage = CURRICULUM_COVERAGE_MANIFEST[concept.key]
        assert.ok(coverage, `${concept.key}: coverage manifestが無い`)
        assert.equal(coverage.unitId, unit.id, `${concept.key}: unitIdが不一致`)
        assert.equal(concept.field, coverage.field)
        assert.equal(concept.grade, coverage.grade)
        assert.deepEqual(concept.curriculumRefs, coverage.curriculumRefs)
        assert.notEqual(concept.curriculumRefs, coverage.curriculumRefs)
        assert.deepEqual(concept.prerequisites, coverage.prerequisites)
        assert.equal(concept.difficulty, coverage.difficulty)
        assert.deepEqual(concept.safety, coverage.safety)
        assert.ok(CURRICULUM_SAFETY_LEVELS.includes(coverage.safety.level))
        assert.ok(coverage.safety.guidance.trim().length >= 12)
        assert.ok(coverage.curriculumRefs.length >= 1)
        for (const reference of coverage.curriculumRefs) {
          assert.equal(reference.document, 'mext-jhs-science-2017')
          assert.match(reference.url, /^https:\/\/www\.mext\.go\.jp\//)
          assert.ok(reference.section.trim())
          assert.ok(reference.pages.length >= 1)
          assert.ok(reference.pages.every((page) => Number.isInteger(page) && page > 0))
        }
        assert.equal(new Set(coverage.prerequisites).size, coverage.prerequisites.length)
        assert.ok(!coverage.prerequisites.includes(concept.key))
        assert.ok(
          coverage.prerequisites.every((prerequisite) => conceptKeys.includes(prerequisite)),
          `${concept.key}: 未知のprerequisite`,
        )
      }
    }
  })

  it('一覧APIはschema v10のexact envelopeだけを返す', () => {
    const listResponse = getUnits({ lang: 'ja' })
    const listEnvelope = listResponse.body as {
      schemaVersion: unknown
      units: PublicUnit[]
    }
    assert.deepEqual(
      Object.keys(listEnvelope).sort(),
      ['schemaVersion', 'units'],
      '一覧responseのroot契約に未知fieldが混じっている',
    )
    assert.equal(
      listEnvelope.schemaVersion,
      BUNDLED_UNIT_CATALOG_SCHEMA_VERSION,
      '一覧responseがsv10として識別できない',
    )
    assert.ok(Array.isArray(listEnvelope.units))
  })

  it('Pickerに公開する全ミッションがMaterialとDirectorの同じconceptへ進める', () => {
    const listResponse = getUnits({ lang: 'ja' })
    const listEnvelope = listResponse.body as {
      schemaVersion: unknown
      units: PublicUnit[]
    }
    const listed = listEnvelope.units

    assert.deepEqual(
      listed.map((unit) => unit.id),
      UNITS.map((unit) => unit.id),
      'Pickerに公開する単元が正カタログとずれている',
    )
    assert.equal(
      new Set(listed.flatMap((unit) => unit.concepts.map((concept) => concept.storyTitle))).size,
      35,
      'Story一覧で35件の固有事件名を公開していない',
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

  it('2・3周目も35conceptの成立条件を外さず、別の科学的判断を要求する', () => {
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

    const density = text('matter-properties', 'density')
    assert.match(density, /質量と体積.*質量÷体積/)
    assert.match(density, /PとQ.*同じ密度.*この結果だけで物質名.*断定できません/)

    const gas = text('matter-properties', 'gasProperties')
    assert.match(gas, /水に非常に溶けやすく.*上方置換/)
    assert.match(gas, /Xは酸素.*Yは二酸化炭素.*種類固有の反応/)

    const stateChange = text('matter-properties', 'stateChangeMass')
    assert.match(stateChange, /開いた皿A.*気体を逃さない袋B.*系の境界/)
    assert.match(stateChange, /全質量.*体積や粒子配置は変わる場合/)

    const cells = text('living-body', 'cells')
    assert.match(cells, /倍率・染色・採取部位/)
    assert.match(cells, /表面と内部.*葉緑体.*どちらも植物体をつくる細胞/)

    const photosynthesis = text('living-body', 'photosynthesisRespiration')
    assert.match(photosynthesis, /弱い光.*呼吸による放出.*ほぼつり合い/)
    assert.match(photosynthesis, /葉がなく.*茎の呼吸.*酸素消費/)

    const digestion = text('living-body', 'digestionAbsorption')
    assert.match(digestion, /酵素X.*デンプン.*酵素Y.*タンパク質/)
    assert.match(digestion, /柔毛.*表面積.*吸収/)

    const humidity = text('weather-change', 'humidityClouds')
    assert.match(humidity, /湿度80%.*湿度40%.*先に露点/)
    assert.match(humidity, /上昇.*膨張.*冷え.*露点.*雲粒/)

    const fronts = text('weather-change', 'fronts')
    assert.match(fronts, /温暖前線.*寒冷前線.*暖気の持ち上げられる傾き/)
    assert.match(fronts, /寒冷前線通過.*水蒸気量・地形・前線速度/)

    const wind = text('weather-change', 'pressurePatternsWind')
    assert.match(wind, /等圧線間隔.*気圧傾度.*局地地形/)
    assert.match(wind, /摩擦で風速.*自転による.*曲げ効果.*低圧側/)

    const strata = text('earth-history', 'strataRelativeAge')
    assert.match(strata, /断層F.*切られた.*DがFを覆って切られていない/)
    assert.match(strata, /火山灰層.*鍵層.*化石.*上下関係/)

    const volcanoes = text('earth-history', 'volcanoEarthquakes')
    assert.match(volcanoes, /粘り気が大きい.*気体が抜けにくく.*爆発的/)
    assert.match(volcanoes, /P波.*S波.*到着差.*震源から遠い.*地盤/)

    const sky = text('earth-history', 'dailyMotionSeasons')
    assert.match(sky, /北の空.*天の北極.*南の空.*円弧/)
    assert.match(sky, /北半球.*南半球.*地軸が傾いたまま公転.*太陽距離/)
  })

  it('105の具体場面それぞれに、checkpointと別の直接な結果と理由が対応する', () => {
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
      density: [
        /水.*食用油.*重く.*単位体積当たり/,
        /2\.7 g\/cm³.*2\.6 g\/cm³.*A.*質量を体積で割/,
        /PとQ.*2\.7 g\/cm³.*同じ密度.*断定できません/,
      ],
      cells: [
        /細胞を区切る境界.*細胞壁.*倍率.*染色.*採取部位/,
        /Aは植物由来.*葉緑体がない.*Bは動物細胞.*確認が必要/,
        /表面と内部.*役割の違い.*植物体をつくる細胞/,
      ],
      humidityClouds: [
        /冷水.*外側.*水滴.*露点.*凝結/,
        /空気A.*先に露点.*凝結.*湿度80%/,
        /気圧低下.*膨張して冷え.*露点.*雲粒/,
      ],
      strataRelativeAge: [
        /青、黄、白.*3層を切る線.*緑.*下の層ほど/,
        /断層F.*A・B・C.*地層D.*切る関係/,
        /火山灰層.*同時期の鍵層.*化石X.*前.*化石Y.*後.*同じ鍵層である根拠/,
      ],
      gasProperties: [
        /酸素と水素は水上置換.*アンモニアは上方置換.*二酸化炭素は下方置換/,
        /気体Aはアンモニア.*水上置換ではなく上方置換.*アルカリ性/,
        /Xは酸素.*Yは二酸化炭素.*石灰水を白濁/,
      ],
      stateChangeMass: [
        /密閉容器.*液体が気体.*全質量.*同じ/,
        /A.*質量は減り.*B.*袋全体の質量は変わりません.*系の境界/,
        /袋全体の質量と粒子の種類は変わりません.*体積.*粒子配置/,
      ],
      photosynthesisRespiration: [
        /明所.*酸素が正味で増え.*暗所.*減り.*呼吸.*どちら/,
        /弱い光.*光合成.*呼吸.*つり合い.*強い光.*光合成/,
        /A.*葉の光合成.*酸素が正味で増え.*B.*葉がなく呼吸.*酸素消費/,
      ],
      digestionAbsorption: [
        /大きな栄養分.*小さな物質.*小腸の柔毛.*血液やリンパ/,
        /X.*デンプン.*Y.*タンパク質.*基質特異性/,
        /B.*表面積が大きい.*Aより吸収.*柔毛/,
      ],
      fronts: [
        /層状の雲.*降水が続き.*通過後に気温が上がる.*暖気.*緩やかに上昇/,
        /Aは温暖前線.*広い範囲.*Bは寒冷前線.*狭い範囲/,
        /寒冷前線通過.*全て.*同じ強さ.*とは言えません.*水蒸気量・地形/,
      ],
      pressurePatternsWind: [
        /等圧線が狭い区域.*観測風速.*大きく.*気圧差/,
        /A.*気圧差が大きい.*Bより風が強い.*気圧傾度/,
        /地表.*摩擦で遅く.*等圧線を斜めに横切.*低気圧側/,
      ],
      volcanoEarthquakes: [
        /プレート境界.*火山と震央が多い.*一致しない.*岩盤のずれ.*マグマの上昇/,
        /A.*比較的穏やか.*B.*爆発的.*粘り気.*気体が抜けにくく/,
        /Q.*震源から遠い.*揺れの強さ.*決まりません.*規模や地盤/,
      ],
      dailyMotionSeasons: [
        /一晩に星が東から西.*月を進める.*自転.*公転/,
        /北の空.*天の北極.*円弧.*南の空.*東から昇って西/,
        /Nは夏.*Sは冬.*地軸が傾いたまま公転.*太陽距離.*ほぼ同じ/,
      ],
      combinationDecomposition: [
        /鉄粉と硫黄.*加熱.*磁石に引かれず.*硫化鉄/,
        /1種類の物質.*複数の物質に分かれ.*分解.*1種類から2種類以上/,
        /石灰石.*分解.*砂と鉄粉.*物理的な操作.*磁石での分離.*性質がそのまま残る/,
      ],
      oxidationReduction: [
        /酸化銅.*炭素.*赤い光沢の銅.*二酸化炭素.*酸素が炭素へ移り.*還元/,
        /銅板.*酸素と結びついた分だけ重く.*木炭.*二酸化炭素.*酸素をやりとりする酸化/,
        /鉄鉱石から酸素を取り除いて鉄.*還元.*さびるのが酸化.*酸素の移動する向きが逆/,
      ],
      massConservation: [
        /密閉した袋.*気体が発生しても.*質量は反応前と等しい.*原子.*袋内に残る/,
        /開いた容器.*気体が測定範囲外.*密閉袋.*気体も測定に含まれる.*関わる物質すべて/,
        /酸素が銅へ結びついた分だけ増え.*二酸化炭素が外へ出た分だけ減.*総和は等しい.*すべてを測れば質量は保存/,
      ],
      electrolyte: [
        /食塩水.*電流が流れ.*砂糖水.*流れず.*イオンに分かれ/,
        /陽極と陰極に決まった物質が生成.*イオン.*電極へ引かれ.*電極の変化がイオンの存在/,
        /食塩は溶けるとイオンに分かれて電気を通し.*砂糖やエタノールはイオンにならず.*固い食塩はイオンが動けない/,
      ],
      acidAlkali: [
        /BTB溶液.*うすい塩酸は黄色.*水酸化ナトリウム水溶液は青色.*水素イオン.*水酸化物イオン/,
        /pHが小さいほど酸性が強い.*pH3のほうが強い酸.*pHが大きいほど強いアルカリ性/,
        /どちらにも気体が発生した.*水素イオンが反応.*勢いの違いは酸の強さ.*水素イオンの仕事/,
      ],
      neutralizationBattery: [
        /中性になるまで混ぜて乾燥させた.*塩化ナトリウム.*水素イオンと水酸化物イオンが結びついて水/,
        /pH7ではなくても.*水素イオンと水酸化物イオンは水になり.*生成した塩と余った酸/,
        /亜鉛が電子を放出して亜鉛イオン.*回路を通って銅板へ流れ.*イオンへのなりやすさの差/,
      ],
      reproduction: [
        /タマネギの根端.*染色体が写し取られ.*細胞の数が増え.*成長/,
        /両親の染色体を組み合わせてもち.*親と同じ染色体.*減数分裂で半分になった生殖細胞が受精/,
        /ほぼ同じ形質.*ばらつきがあって耐性のある個体.*集団の形質がそろい/,
      ],
      heredity: [
        /すべて丸の種子になり.*およそ3：1.*優性形質.*劣性形質/,
        /両親はともにaをもつAa.*AA・Aa・Aa・aa.*優性形質を示す親はAAとは限らず/,
        /減数分裂で染色体が半分になり.*両親の染色体を受け継ぎ.*染色体にのって生殖細胞/,
      ],
      evolution: [
        /古い層から新しい層.*姿の異なる生物.*段階的に並ぶ.*種類が時間とともに変わってきた証拠/,
        /ばらつきのあった蛾.*暗色の蛾が鳥に見つかりにくく.*暗色の個体の割合が増え/,
        /首の長さにばらつきがあり.*多く子を残した.*集団の形質の割合の変化/,
      ],
      energyResources: [
        /位置エネルギー.*化学エネルギー.*変換.*姿を変えるだけ/,
        /枯渇性資源.*再生可能エネルギー.*埋蔵量.*二酸化炭素/,
        /変換効率.*燃料.*環境負荷.*利用できない熱.*損失/,
      ],
      natureBalance: [
        /光合成.*消費者.*分解者.*循環.*二酸化炭素/,
        /魚が増えて水草が減り.*相互に影響.*自然界のつり合い/,
        /鳥.*虫.*連鎖.*回復力を超える/,
      ],
      sustainableSociety: [
        /発生は止められません.*観測.*予測.*被害を小さく.*避難計画/,
        /過去の洪水の記録.*地形と標高.*降水量.*ハザードマップ.*予測/,
        /枯渇性資源の消費を減らし.*二酸化炭素.*持続可能.*省エネ/,
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
