/**
 * 教材カタログと学習指導要領の対応表。
 *
 * 科学本文とは分離し、単元を追加しただけで対応領域・学年・前提・安全条件が
 * 欠落しないようにする。参照先は文部科学省「中学校学習指導要領（平成29年
 * 告示）解説 理科編」の章節と、PDFに印刷された本文ページ番号（PageLabels）で、
 * 効果量や到達度を主張するものではない。
 */

export const CURRICULUM_FIELDS = ['matter', 'energy', 'life', 'earth'] as const
export type CurriculumField = (typeof CURRICULUM_FIELDS)[number]

export const CURRICULUM_SAFETY_LEVELS = [
  'homeSafe',
  'teacherGuided',
  'referenceOnly',
] as const
export type CurriculumSafetyLevel = (typeof CURRICULUM_SAFETY_LEVELS)[number]

export type CurriculumReference = {
  document: 'mext-jhs-science-2017'
  section: string
  /** PDFに印刷された本文ページ番号。PDFのPageLabelsと一致する。 */
  pages: number[]
  url: string
}

export type CurriculumSafety = {
  level: CurriculumSafetyLevel
  guidance: string
}

export type CurriculumCoverageEntry = {
  unitId: string
  conceptKey: string
  field: CurriculumField
  grade: 1 | 2 | 3
  curriculumRefs: CurriculumReference[]
  prerequisites: string[]
  difficulty: 1 | 2 | 3 | 4 | 5
  safety: CurriculumSafety
}

const MEXT_URL =
  'https://www.mext.go.jp/component/a_menu/education/micro_detail/'
  + '__icsFiles/afieldfile/2019/03/18/1387018_005.pdf'

function ref(section: string, ...pages: number[]): CurriculumReference {
  return {
    document: 'mext-jhs-science-2017',
    section,
    pages,
    url: MEXT_URL,
  }
}

const homeSafe = (guidance: string): CurriculumSafety => ({
  level: 'homeSafe',
  guidance,
})

const teacherGuided = (guidance: string): CurriculumSafety => ({
  level: 'teacherGuided',
  guidance,
})

const referenceOnly = (guidance: string): CurriculumSafety => ({
  level: 'referenceOnly',
  guidance,
})

/** conceptKeyを一意キーにした、現行production教材の全件manifest。 */
export const CURRICULUM_COVERAGE_MANIFEST: Readonly<
  Record<string, CurriculumCoverageEntry>
> = {
  fall: {
    unitId: 'force-motion',
    conceptKey: 'fall',
    field: 'energy',
    grade: 3,
    curriculumRefs: [ref('第1分野 (5)(イ) 運動の規則性・落下運動', 54, 56)],
    prerequisites: [],
    difficulty: 2,
    safety: homeSafe('同じ紙だけを使い、踏み台に乗らず手の高さから落とす。'),
  },
  inertia: {
    unitId: 'force-motion',
    conceptKey: 'inertia',
    field: 'energy',
    grade: 3,
    curriculumRefs: [ref('第1分野 (5)(イ) 運動の規則性・力と運動', 54, 55)],
    prerequisites: [],
    difficulty: 2,
    safety: homeSafe('小さな物体を机の上だけで動かし、人や壊れ物へ向けない。'),
  },
  friction: {
    unitId: 'force-motion',
    conceptKey: 'friction',
    field: 'energy',
    grade: 3,
    curriculumRefs: [ref('第1分野 (5)(イ) 運動の規則性・力と運動・摩擦', 56, 57)],
    prerequisites: ['inertia'],
    difficulty: 2,
    safety: homeSafe('机上の軽い物体だけを使い、床や通路では滑らせない。'),
  },
  throwUp: {
    unitId: 'force-motion',
    conceptKey: 'throwUp',
    field: 'energy',
    grade: 3,
    curriculumRefs: [ref('第1分野 (5)(イ) 運動の規則性・力と運動・落下運動', 55, 56)],
    prerequisites: ['fall', 'inertia'],
    difficulty: 3,
    safety: homeSafe('投げずに動画・図で確認し、実演する場合も柔らかい物体を人のいない場所で扱う。'),
  },
  actionReaction: {
    unitId: 'force-balance',
    conceptKey: 'actionReaction',
    field: 'energy',
    grade: 3,
    curriculumRefs: [ref('第1分野 (5)(イ) 運動の規則性・作用反作用', 55)],
    prerequisites: [],
    difficulty: 3,
    safety: homeSafe('壁や手を強く押さず、痛みが出ない弱い力だけで比べる。'),
  },
  balance: {
    unitId: 'force-balance',
    conceptKey: 'balance',
    field: 'energy',
    grade: 3,
    curriculumRefs: [ref('第1分野 (5)(イ) 運動の規則性・力と運動', 54, 55)],
    prerequisites: ['inertia'],
    difficulty: 3,
    safety: referenceOnly('乗り物内では実験せず、既存の観察経験・図・動画だけを使う。'),
  },
  pressure: {
    unitId: 'pressure-buoyancy',
    conceptKey: 'pressure',
    field: 'energy',
    grade: 2,
    curriculumRefs: [ref('第2分野 (4)(ア) 気象観測・気象要素', 92, 93)],
    prerequisites: [],
    difficulty: 2,
    safety: homeSafe('先端の鋭い物を使わず、スポンジや粘土へ消しゴムを弱く押す。'),
  },
  buoyancy: {
    unitId: 'pressure-buoyancy',
    conceptKey: 'buoyancy',
    field: 'energy',
    grade: 3,
    curriculumRefs: [ref('第1分野 (5)(ア) 力のつり合いと合成・分解・水中の物体に働く力', 52, 53)],
    prerequisites: ['pressure'],
    difficulty: 3,
    safety: homeSafe('浅い安定した容器と少量の水を使い、電気製品から離してこぼれを拭く。'),
  },
  currentMagneticField: {
    unitId: 'current-magnetism',
    conceptKey: 'currentMagneticField',
    field: 'energy',
    grade: 2,
    curriculumRefs: [ref('第1分野 (3)(イ) 電流と磁界', 44, 45)],
    prerequisites: [],
    difficulty: 3,
    safety: teacherGuided('低電圧電源と抵抗を使う教師監督実験だけとし、家庭用コンセントへ接続しない。'),
  },
  magneticForce: {
    unitId: 'current-magnetism',
    conceptKey: 'magneticForce',
    field: 'energy',
    grade: 2,
    curriculumRefs: [ref('第1分野 (3)(イ) 電流と磁界', 44, 45)],
    prerequisites: ['currentMagneticField'],
    difficulty: 3,
    safety: teacherGuided('低電圧・電流制限された教師監督実験だけで向きを比較する。'),
  },
  electromagneticInduction: {
    unitId: 'current-magnetism',
    conceptKey: 'electromagneticInduction',
    field: 'energy',
    grade: 2,
    curriculumRefs: [ref('第1分野 (3)(イ) 電流と磁界', 44, 45)],
    prerequisites: ['currentMagneticField'],
    difficulty: 4,
    safety: teacherGuided('電源を接続しないコイルと検流計を教師監督下で扱う。'),
  },
  density: {
    unitId: 'matter-properties',
    conceptKey: 'density',
    field: 'matter',
    grade: 1,
    curriculumRefs: [ref('第1分野 (2)(ア) 物質のすがた', 35, 36, 37)],
    prerequisites: [],
    difficulty: 2,
    safety: homeSafe('同じ大きさの密閉容器と水・食用油だけを使い、口に入れず、こぼれたらすぐ拭く。'),
  },
  cells: {
    unitId: 'living-body',
    conceptKey: 'cells',
    field: 'life',
    grade: 2,
    curriculumRefs: [ref('第2分野 (3)(ア) 生物と細胞', 86, 87)],
    prerequisites: [],
    difficulty: 2,
    safety: referenceOnly('学校配布・教科書の顕微鏡画像だけを観察し、人体採取や家庭での染色は行わない。'),
  },
  humidityClouds: {
    unitId: 'weather-change',
    conceptKey: 'humidityClouds',
    field: 'earth',
    grade: 2,
    curriculumRefs: [ref('第2分野 (4)(イ) 天気の変化・霧や雲の発生', 94, 95)],
    prerequisites: [],
    difficulty: 3,
    safety: homeSafe('冷水入りの安定したコップを机上で観察し、密閉加熱や加圧は行わない。'),
  },
  strataRelativeAge: {
    unitId: 'earth-history',
    conceptKey: 'strataRelativeAge',
    field: 'earth',
    grade: 1,
    curriculumRefs: [ref('第2分野 (2)(イ) 地層の重なりと過去の様子', 81, 82)],
    prerequisites: [],
    difficulty: 3,
    safety: homeSafe('紙の模型だけを使い、崖・工事現場へ近づかず岩石を採取しない。'),
  },
  gasProperties: {
    unitId: 'matter-properties',
    conceptKey: 'gasProperties',
    field: 'matter',
    grade: 1,
    curriculumRefs: [ref('第1分野 (2)(ア) 気体の発生と性質', 36, 37)],
    prerequisites: [],
    difficulty: 2,
    safety: referenceOnly('学校配布の観察記録と図表だけを使い、家庭で気体を発生させたり薬品を混ぜたり火を使ったりしない。'),
  },
  stateChangeMass: {
    unitId: 'matter-properties',
    conceptKey: 'stateChangeMass',
    field: 'matter',
    grade: 1,
    curriculumRefs: [ref('第1分野 (2)(ウ) 状態変化と熱', 38, 39)],
    prerequisites: [],
    difficulty: 2,
    safety: referenceOnly('学校配布の密閉系の測定記録だけを使い、家庭で加熱・冷却・密閉実験や容器の開封を行わない。'),
  },
  photosynthesisRespiration: {
    unitId: 'living-body',
    conceptKey: 'photosynthesisRespiration',
    field: 'life',
    grade: 2,
    curriculumRefs: [ref('第2分野 (3)(イ) 葉・茎・根のつくりと働き', 87, 88)],
    prerequisites: ['cells'],
    difficulty: 3,
    safety: referenceOnly('学校配布の葉の写真と気体データだけを使い、アルコールの加熱・ヨウ素液・植物の採取を家庭で行わない。'),
  },
  digestionAbsorption: {
    unitId: 'living-body',
    conceptKey: 'digestionAbsorption',
    field: 'life',
    grade: 2,
    curriculumRefs: [ref('第2分野 (3)(ウ) 生命を維持する働き', 89, 90)],
    prerequisites: ['cells'],
    difficulty: 3,
    safety: referenceOnly('模式図と固定データだけを使い、唾液・血液などの人体試料の採取や飲食物への薬品追加を行わない。'),
  },
  fronts: {
    unitId: 'weather-change',
    conceptKey: 'fronts',
    field: 'earth',
    grade: 2,
    curriculumRefs: [ref('第2分野 (4)(イ) 前線の通過と天気の変化', 94, 95)],
    prerequisites: ['humidityClouds'],
    difficulty: 3,
    safety: referenceOnly('気象庁などの公開済み観測データを屋内で読み、雷雨・強風・前線通過時に屋外観測しない。'),
  },
  pressurePatternsWind: {
    unitId: 'weather-change',
    conceptKey: 'pressurePatternsWind',
    field: 'earth',
    grade: 2,
    curriculumRefs: [ref('第2分野 (4)(ウ) 日本の気象', 95, 96, 97)],
    prerequisites: ['fronts'],
    difficulty: 3,
    safety: referenceOnly('過去の天気図と気象衛星画像だけを屋内で読み、災害時の外出や風の実測は行わない。'),
  },
  volcanoEarthquakes: {
    unitId: 'earth-history',
    conceptKey: 'volcanoEarthquakes',
    field: 'earth',
    grade: 1,
    curriculumRefs: [ref('第2分野 (2)(ウ) 火山と地震', 82, 83, 84)],
    prerequisites: ['strataRelativeAge'],
    difficulty: 3,
    safety: referenceOnly('公開済みの火山噴出物写真・地震記録・紙模型だけを使い、火山・断層・被災地へ観察に行かない。'),
  },
  dailyMotionSeasons: {
    unitId: 'earth-history',
    conceptKey: 'dailyMotionSeasons',
    field: 'earth',
    grade: 3,
    curriculumRefs: [ref('第2分野 (6)(ア) 天体の動きと地球の自転・公転', 104, 105, 106)],
    prerequisites: [],
    difficulty: 3,
    safety: referenceOnly('プラネタリウム画像・日影の固定写真・紙模型を使い、太陽を直接見ず夜間に一人で屋外観測しない。'),
  },
  combinationDecomposition: {
    unitId: 'chemical-change',
    conceptKey: 'combinationDecomposition',
    field: 'matter',
    grade: 2,
    curriculumRefs: [ref('第1分野 (4)(ア)(イ) 物質の成り立ち・化学変化', 46, 47, 48, 49)],
    prerequisites: ['stateChangeMass'],
    difficulty: 3,
    safety: referenceOnly('家庭で加熱・薬品の混合・気体の発生は行わず、配布された実験記録と図・動画だけを使う。'),
  },
  oxidationReduction: {
    unitId: 'chemical-change',
    conceptKey: 'oxidationReduction',
    field: 'matter',
    grade: 2,
    curriculumRefs: [ref('第1分野 (4)(イ) 化学変化における酸化と還元', 48, 49, 50)],
    prerequisites: ['combinationDecomposition'],
    difficulty: 4,
    safety: referenceOnly('さびの観察は手を洗いとがった部分に触れない範囲で行い、加熱・薬品・燃焼を伴う確かめは学校の記録と動画だけを使う。'),
  },
  massConservation: {
    unitId: 'chemical-change',
    conceptKey: 'massConservation',
    field: 'matter',
    grade: 2,
    curriculumRefs: [ref('第1分野 (4)(ウ) 化学変化と物質の質量', 50, 51)],
    prerequisites: ['combinationDecomposition'],
    difficulty: 4,
    safety: referenceOnly('気体発生や加熱を伴う反応は学校配布の測定記録だけを使い、家庭で薬品の混合・加熱・密閉実験をしない。'),
  },
  electrolyte: {
    unitId: 'chemical-change-ions',
    conceptKey: 'electrolyte',
    field: 'matter',
    grade: 2,
    curriculumRefs: [ref('第1分野 (6)(ア)(ｱ) 水溶液とイオン', 58, 59, 60)],
    prerequisites: ['combinationDecomposition'],
    difficulty: 4,
    safety: referenceOnly('水溶液への通電は学校配布の実験記録と図だけを使い、家庭で電圧をかけたり薬品や家庭用コンセントを使ったりしない。'),
  },
  acidAlkali: {
    unitId: 'chemical-change-ions',
    conceptKey: 'acidAlkali',
    field: 'matter',
    grade: 2,
    curriculumRefs: [ref('第1分野 (6)(ア)(イ) 酸・アルカリ', 59, 60)],
    prerequisites: ['electrolyte'],
    difficulty: 4,
    safety: referenceOnly('指示薬や試薬を使う確認は学校配布の色変化記録だけを使い、家庭で液を混ぜたり容器の中身を開けたりしない。'),
  },
  neutralizationBattery: {
    unitId: 'chemical-change-ions',
    conceptKey: 'neutralizationBattery',
    field: 'matter',
    grade: 2,
    curriculumRefs: [
      ref('第1分野 (6)(ア)(ウ) 中和と塩', 60, 61),
      ref('第1分野 (6)(イ) 化学変化と電池', 61, 62),
    ],
    prerequisites: ['acidAlkali'],
    difficulty: 5,
    safety: referenceOnly('中和・電池の製作は学校配布の記録と図だけを使い、家庭で薬品の混合・乾電池の分解・液への電極投入をしない。'),
  },
  reproduction: {
    unitId: 'life-continuity',
    conceptKey: 'reproduction',
    field: 'life',
    grade: 3,
    curriculumRefs: [
      ref('第2分野 (5)(ア) 生物の成長と殖え方', 99, 100),
    ],
    prerequisites: ['cells'],
    difficulty: 4,
    safety: homeSafe('発芽したジャガイモやイチゴのランナーなど身の回りの植物を観察する。食べたり切り分けたりせず、触ったあとは手を洗う。'),
  },
  heredity: {
    unitId: 'life-continuity',
    conceptKey: 'heredity',
    field: 'life',
    grade: 3,
    curriculumRefs: [
      ref('第2分野 (5)(イ) 遺伝の規則性と遺伝子', 100, 101),
    ],
    prerequisites: ['reproduction'],
    difficulty: 5,
    safety: referenceOnly('エンドウや動物の交配は学校配布の記録と図だけを使い、家庭で生き物を交配させたり薬品を使ったりしない。'),
  },
  evolution: {
    unitId: 'life-continuity',
    conceptKey: 'evolution',
    field: 'life',
    grade: 3,
    curriculumRefs: [
      ref('第2分野 (5)(ウ) 生物の変遷と進化', 101, 102),
    ],
    prerequisites: ['heredity'],
    difficulty: 4,
    safety: referenceOnly('化石・地層の資料と図鑑だけを使い、発掘や採取を伴う活動はしない。'),
  },
}

export function curriculumCoverageFor(
  conceptKey: string,
): CurriculumCoverageEntry | undefined {
  return CURRICULUM_COVERAGE_MANIFEST[conceptKey]
}
