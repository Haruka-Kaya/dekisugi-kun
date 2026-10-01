/**
 * Notation Labの科学内容の正本。
 *
 * 式・単位・矢印・グラフをFlutter側で概念キーから推測しない。ここで定義した
 * 公開形をAPIと同梱catalogへ同じまま載せ、端末は厳格にparseする。
 */

import { STAGE1_EXPANSION_NOTATION_LABS } from './stage1-expansion-notation.js'
import { STAGE1_PROOF_NOTATION_LABS } from './stage1-proof-notation.js'
import { STAGE2_NOTATION_LABS } from './stage2-notation.js'

export type NotationToken = { id: string; label: string }
export type NotationChoice = { id: string; label: string }

export type NotationTracePoint = { x: number; y: number }
export type NotationTraceStroke = {
  id: string
  label: string
  points: NotationTracePoint[]
}
export type NotationTracePattern = {
  semanticsLabel: string
  strokes: NotationTraceStroke[]
  strokeOrderIds: string[]
}

export type NotationOrderTask = {
  id: string
  needCode: string
  title: string
  prompt: string
  traceGuide: string
  /** 正答送信後だけ開示し、指でstroke順に通過させる固定軌跡。 */
  tracePattern: NotationTracePattern
  tokens: NotationToken[]
  correctOrderIds: string[]
  solutionSummary: string
}

export type NotationSymbolTask = {
  needCode: string
  prompt: string
  choices: NotationChoice[]
  correctChoiceId: string
  solutionSummary: string
}

export type NotationGraphTask = {
  needCode: string
  prompt: string
  graphNotation: string[]
  graphSemanticsLabel: string
  choices: NotationChoice[]
  correctChoiceId: string
  solutionSummary: string
}

export type LegacyNotationLab = {
  orderTasks: NotationOrderTask[]
  symbolMatch: NotationSymbolTask
  graphRead: NotationGraphTask
}

export const NOTATION_TASK_KINDS = [
  'modelBuild',
  'labelDiagram',
  'sequence',
  'tableRead',
  'graphRead',
  'symbolMatch',
] as const
export type NotationTaskKind = (typeof NOTATION_TASK_KINDS)[number]

type NotationTaskBase = {
  kind: NotationTaskKind
  id: string
  needCode: string
  title: string
  prompt: string
  solutionSummary: string
}

export type NotationArrangeTask = NotationTaskBase & {
  kind: 'modelBuild' | 'sequence'
  guide: string
  tokens: NotationToken[]
  correctOrderIds: string[]
  /** 既存11概念の筆順を保つ。新しいモデル・順序課題では省略できる。 */
  tracePattern?: NotationTracePattern
}

export type NotationChoiceTask = NotationTaskBase & {
  kind: 'labelDiagram' | 'tableRead' | 'graphRead' | 'symbolMatch'
  representation: string[]
  representationSemanticsLabel: string
  choices: NotationChoice[]
  correctChoiceId: string
}

export type NotationTask = NotationArrangeTask | NotationChoiceTask
export type TaggedNotationLab = { tasks: NotationTask[] }
export type NotationLab = LegacyNotationLab | TaggedNotationLab

type Pair = readonly [id: string, label: string]

type NotationSource = {
  arrowPrompt: string
  arrowGuide: string
  arrowTokens: readonly Pair[]
  arrowSummary: string
  equationPrompt: string
  equationTokens: readonly Pair[]
  equationSummary: string
  symbolPrompt: string
  symbolChoices: readonly Pair[]
  correctSymbolId: string
  symbolSummary: string
  graphPrompt: string
  graphNotation: readonly string[]
  graphSemantics: string
  graphChoices: readonly Pair[]
  correctGraphId: string
  graphSummary: string
}

function orderTask(
  id: string,
  needCode: string,
  title: string,
  prompt: string,
  traceGuide: string,
  orderedTokens: readonly Pair[],
  solutionSummary: string,
): NotationOrderTask {
  const canonical = orderedTokens.map(([tokenId, label]) => ({ id: tokenId, label }))
  // 正答順を表示順にしない。内容は変えず、先頭を末尾へ回して提示する。
  const tokens = [...canonical.slice(1), canonical[0]!]
  return {
    id,
    needCode,
    title,
    prompt,
    traceGuide,
    tracePattern: id.endsWith('.arrow')
      ? arrowTracePattern(id, solutionSummary)
      : equationTracePattern(id, canonical.map((token) => token.label).join(' ')),
    tokens,
    correctOrderIds: canonical.map((token) => token.id),
    solutionSummary,
  }
}

function arrowTracePattern(id: string, solutionSummary: string): NotationTracePattern {
  return {
    semanticsLabel: `${solutionSummary} 始点から軸、上の矢じり、下の矢じりの順になぞります。`,
    strokes: [
      {
        id: `${id}.shaft`,
        label: '始点から矢印の軸',
        points: [
          { x: 0.16, y: 0.50 },
          { x: 0.29, y: 0.50 },
          { x: 0.42, y: 0.50 },
          { x: 0.55, y: 0.50 },
          { x: 0.68, y: 0.50 },
          { x: 0.81, y: 0.50 },
        ],
      },
      {
        id: `${id}.head-upper`,
        label: '上の矢じり',
        points: [
          { x: 0.65, y: 0.31 },
          { x: 0.73, y: 0.40 },
          { x: 0.81, y: 0.50 },
        ],
      },
      {
        id: `${id}.head-lower`,
        label: '下の矢じり',
        points: [
          { x: 0.81, y: 0.50 },
          { x: 0.73, y: 0.60 },
          { x: 0.65, y: 0.69 },
        ],
      },
    ],
    strokeOrderIds: [
      `${id}.shaft`,
      `${id}.head-upper`,
      `${id}.head-lower`,
    ],
  }
}

function equationTracePattern(id: string, expression: string): NotationTracePattern {
  return {
    semanticsLabel: `${expression}。式の読み線、等号の確認線の順になぞります。`,
    strokes: [
      {
        id: `${id}.reading-line`,
        label: '式を左辺から右辺へ読む線',
        points: [
          { x: 0.12, y: 0.64 },
          { x: 0.27, y: 0.64 },
          { x: 0.42, y: 0.64 },
          { x: 0.57, y: 0.64 },
          { x: 0.72, y: 0.64 },
          { x: 0.87, y: 0.64 },
        ],
      },
      {
        id: `${id}.meaning-link`,
        label: '左辺と右辺を結ぶ確認線',
        points: [
          { x: 0.34, y: 0.39 },
          { x: 0.50, y: 0.49 },
          { x: 0.66, y: 0.39 },
        ],
      },
    ],
    strokeOrderIds: [`${id}.reading-line`, `${id}.meaning-link`],
  }
}

function choices(entries: readonly Pair[]): NotationChoice[] {
  return entries.map(([id, label]) => ({ id, label }))
}

function notationLab(conceptKey: string, source: NotationSource): LegacyNotationLab {
  const needCode = (kind: 'arrow' | 'equation' | 'symbol' | 'graph') =>
    `science.${conceptKey}.notation.${kind}`
  return {
    orderTasks: [
      orderTask(
        `${conceptKey}.arrow`,
        needCode('arrow'),
        '矢印を意味の順になぞる',
        source.arrowPrompt,
        source.arrowGuide,
        source.arrowTokens,
        source.arrowSummary,
      ),
      orderTask(
        `${conceptKey}.equation`,
        needCode('equation'),
        '式を左から組み立てる',
        source.equationPrompt,
        '量の意味を声に出し、左辺から右辺へ順に置きます。',
        source.equationTokens,
        source.equationSummary,
      ),
    ],
    symbolMatch: {
      needCode: needCode('symbol'),
      prompt: source.symbolPrompt,
      choices: choices(source.symbolChoices),
      correctChoiceId: source.correctSymbolId,
      solutionSummary: source.symbolSummary,
    },
    graphRead: {
      needCode: needCode('graph'),
      prompt: source.graphPrompt,
      graphNotation: [...source.graphNotation],
      graphSemanticsLabel: source.graphSemantics,
      choices: choices(source.graphChoices),
      correctChoiceId: source.correctGraphId,
      solutionSummary: source.graphSummary,
    },
  }
}

export const NOTATION_LABS: Readonly<Record<string, NotationLab>> = {
  fall: notationLab('fall', {
    arrowPrompt: '落下中の物体にはたらく重力を、物体から描く順に置く。',
    arrowGuide: '物体の中心を始点にして、鉛直下向きへ矢印を伸ばします。',
    arrowTokens: [
      ['body', '物体の中心'],
      ['down', '鉛直下向き'],
      ['gravity', '重力 mg'],
    ],
    arrowSummary: '重力の矢印は物体の中心から鉛直下向きに描きます。',
    equationPrompt: '自由落下の速さを、時間と重力加速度で表す。',
    equationTokens: [
      ['v', 'v'],
      ['eq', '='],
      ['g', 'g'],
      ['t', 't'],
    ],
    equationSummary: '初速0なら v = gt。gは重さによらない重力加速度です。',
    symbolPrompt: '重力加速度 g の単位は？',
    symbolChoices: [
      ['ms2', 'm/s²'],
      ['n', 'N'],
      ['pa', 'Pa'],
    ],
    correctSymbolId: 'ms2',
    symbolSummary: '加速度の単位は m/s² です。',
    graphPrompt: '初速0の自由落下で、時間が増えたとき速さはどう変わる？',
    graphNotation: ['速さ v', '／', '／', '時間 t →'],
    graphSemantics: '横軸が時間、縦軸が速さ。原点から右上がりの直線。',
    graphChoices: [
      ['linear', '時間に比例して増える'],
      ['constant', '一定のまま'],
      ['inverse', '時間に反比例して減る'],
    ],
    correctGraphId: 'linear',
    graphSummary: '空気抵抗を無視すれば、速さは時間に比例して増えます。',
  }),
  inertia: notationLab('inertia', {
    arrowPrompt: '合力が0の物体について、運動の読み順を置く。',
    arrowGuide: '左右の力を同じ長さで描き、合力0を確認します。',
    arrowTokens: [
      ['forces', '反対向きの力'],
      ['sum0', '合力 0'],
      ['keep', '速度を保つ'],
    ],
    arrowSummary: '合力0なら、静止または等速直線運動を続けます。',
    equationPrompt: '慣性の条件を式の順に置く。',
    equationTokens: [
      ['sumf', 'ΣF'],
      ['eq', '='],
      ['zero', '0'],
      ['arrow', '→'],
      ['dv', 'Δv = 0'],
    ],
    equationSummary: 'ΣF = 0 なら速度の変化 Δv は0です。',
    symbolPrompt: 'ΣF が表すものは？',
    symbolChoices: [
      ['net', '物体にはたらく力の合計'],
      ['speed', '速さの合計'],
      ['mass', '質量の合計'],
    ],
    correctSymbolId: 'net',
    symbolSummary: 'ΣFは1つの物体にはたらく力のベクトル和です。',
    graphPrompt: '合力0の物体の速度―時間グラフは？',
    graphNotation: ['速度 v', '────', '時間 t →'],
    graphSemantics: '横軸が時間、縦軸が速度。水平な直線。',
    graphChoices: [
      ['flat', '速度一定の水平線'],
      ['up', '右上がりの直線'],
      ['down', '右下がりの直線'],
    ],
    correctGraphId: 'flat',
    graphSummary: '合力0なら速度は一定なので、水平線になります。',
  }),
  friction: notationLab('friction', {
    arrowPrompt: '滑る物体の摩擦力を描く順に置く。',
    arrowGuide: '接触面に沿い、物体の相対運動を妨げる向きへ描きます。',
    arrowTokens: [
      ['motion', '滑る向き'],
      ['opposite', '反対向き'],
      ['friction', '摩擦力'],
    ],
    arrowSummary: '摩擦力は接触面に沿って相対運動を妨げる向きです。',
    equationPrompt: '動摩擦力の大きさを表す式を組む。',
    equationTokens: [
      ['f', 'F₍f₎'],
      ['eq', '='],
      ['mu', 'μ'],
      ['n', 'N'],
    ],
    equationSummary: '単純なモデルでは動摩擦力 F₍f₎ = μN です。',
    symbolPrompt: '垂直抗力 N の単位は？',
    symbolChoices: [
      ['newton', 'N（ニュートン）'],
      ['pascal', 'Pa（パスカル）'],
      ['tesla', 'T（テスラ）'],
    ],
    correctSymbolId: 'newton',
    symbolSummary: '力の単位はN（ニュートン）です。',
    graphPrompt: 'μが一定なら、垂直抗力が増えると動摩擦力は？',
    graphNotation: ['摩擦力', '／', '／', '垂直抗力 →'],
    graphSemantics: '横軸が垂直抗力、縦軸が摩擦力。原点から右上がり。',
    graphChoices: [
      ['proportional', '比例して増える'],
      ['fixed', '変わらない'],
      ['decrease', '減る'],
    ],
    correctGraphId: 'proportional',
    graphSummary: 'μ一定なら、摩擦力は垂直抗力に比例します。',
  }),
  throwUp: notationLab('throwUp', {
    arrowPrompt: '投げ上げた直後の物体に重力を描く順に置く。',
    arrowGuide: '速度が上向きでも、重力は物体から下向きです。',
    arrowTokens: [
      ['body', '物体'],
      ['down', '下向き'],
      ['mg', '重力 mg'],
    ],
    arrowSummary: '空気抵抗を無視すれば、飛行中は下向きの重力だけです。',
    equationPrompt: '上向きを正とした速度の式を組む。',
    equationTokens: [
      ['v', 'v'],
      ['eq', '='],
      ['v0', 'v₀'],
      ['minus', '−'],
      ['gt', 'gt'],
    ],
    equationSummary: '上向きを正とすると v = v₀ − gt です。',
    symbolPrompt: '最高点で0になる量は？',
    symbolChoices: [
      ['velocity', '瞬間の速度'],
      ['gravity', '重力'],
      ['accel', '加速度'],
    ],
    correctSymbolId: 'velocity',
    symbolSummary: '最高点で速度は0ですが、重力と下向き加速度は残ります。',
    graphPrompt: '上向きを正にした速度―時間グラフは？',
    graphNotation: ['速度 v', '＼', '  ＼', '時間 t →'],
    graphSemantics: '横軸が時間、縦軸が速度。正から0を通って負へ下がる直線。',
    graphChoices: [
      ['downline', '一定の傾きで下がる'],
      ['flat0', '最高点後も0のまま'],
      ['u', 'U字に変わる'],
    ],
    correctGraphId: 'downline',
    graphSummary: '速度は傾き−gの直線で減り、最高点で0を通ります。',
  }),
  actionReaction: notationLab('actionReaction', {
    arrowPrompt: '作用・反作用の2本の矢印を対応付ける順に置く。',
    arrowGuide: '別々の物体を始点に、同一直線上で反対向きに描きます。',
    arrowTokens: [
      ['a-on-b', 'AがBを押す'],
      ['b-on-a', 'BがAを押す'],
      ['opposite', '同じ大きさ・反対向き'],
    ],
    arrowSummary: '作用・反作用は別々の物体にはたらく一対の力です。',
    equationPrompt: '作用・反作用のベクトル式を組む。',
    equationTokens: [
      ['fab', 'Fᴬ→ᴮ'],
      ['eq', '='],
      ['minus', '−'],
      ['fba', 'Fᴮ→ᴬ'],
    ],
    equationSummary: 'Fᴬ→ᴮ = −Fᴮ→ᴬ。大きさが等しく向きが逆です。',
    symbolPrompt: '作用・反作用がはたらく対象は？',
    symbolChoices: [
      ['different', '互いに異なる2物体'],
      ['same', '同じ1物体'],
      ['none', '物体以外の空間'],
    ],
    correctSymbolId: 'different',
    symbolSummary: '2力は別々の物体にはたらくため、1物体上で打ち消しません。',
    graphPrompt: '接触中、一方の力が大きくなったとき相手からの力は？',
    graphNotation: ['力の大きさ', '／  ／', '／  ／', '時間 →'],
    graphSemantics: '2つの力の大きさが時間に対して重なる。向きは反対。',
    graphChoices: [
      ['same-size', '同時に同じ大きさになる'],
      ['delay', '後から同じになる'],
      ['unrelated', '常に別の大きさになる'],
    ],
    correctGraphId: 'same-size',
    graphSummary: '相互作用中、2力の大きさは各瞬間で等しいです。',
  }),
  balance: notationLab('balance', {
    arrowPrompt: '1物体にはたらくつり合う力を確認する順に置く。',
    arrowGuide: '同じ物体を始点に、合計が0になるよう矢印を描きます。',
    arrowTokens: [
      ['same-body', '同じ物体'],
      ['all-forces', '全ての力'],
      ['zero-sum', 'ベクトル和0'],
    ],
    arrowSummary: 'つり合いは同じ物体にはたらく力の合力が0の状態です。',
    equationPrompt: 'つり合いの条件式を組む。',
    equationTokens: [
      ['sumf', 'ΣF'],
      ['eq', '='],
      ['zero', '0'],
    ],
    equationSummary: 'つり合いの条件は ΣF = 0 です。',
    symbolPrompt: 'Σ が表す操作は？',
    symbolChoices: [
      ['sum', '全てを向き込みで足す'],
      ['largest', '最大の力だけ選ぶ'],
      ['pair', '2力だけ比較する'],
    ],
    correctSymbolId: 'sum',
    symbolSummary: 'Σは対象物体にはたらく全ての力の和です。',
    graphPrompt: '合力0で静止している物体の位置―時間グラフは？',
    graphNotation: ['位置 x', '────', '時間 t →'],
    graphSemantics: '横軸が時間、縦軸が位置。水平な直線。',
    graphChoices: [
      ['flat', '位置一定の水平線'],
      ['linear', '右上がり'],
      ['curve', '上向きの曲線'],
    ],
    correctGraphId: 'flat',
    graphSummary: '静止を続けるなら位置は変わらず水平線です。',
  }),
  pressure: notationLab('pressure', {
    arrowPrompt: '面が受ける圧力を考える順に置く。',
    arrowGuide: '面に垂直な力と、その力が分布する面積を分けます。',
    arrowTokens: [
      ['normal-force', '面に垂直な力 F'],
      ['area', '面積 A'],
      ['pressure', '圧力 p'],
    ],
    arrowSummary: '圧力は面に垂直な力を面積で割った量です。',
    equationPrompt: '圧力の式を組む。',
    equationTokens: [
      ['p', 'p'],
      ['eq', '='],
      ['f', 'F'],
      ['divide', '÷'],
      ['a', 'A'],
    ],
    equationSummary: '圧力 p = F/A です。',
    symbolPrompt: '圧力の単位 Pa と同じものは？',
    symbolChoices: [
      ['n-m2', 'N/m²'],
      ['n-m', 'N·m'],
      ['kg-m', 'kg/m'],
    ],
    correctSymbolId: 'n-m2',
    symbolSummary: '1 Pa = 1 N/m² です。',
    graphPrompt: '力一定で、面積が増えたとき圧力は？',
    graphNotation: ['圧力 p', '＼＿', '   ＿', '面積 A →'],
    graphSemantics: '横軸が面積、縦軸が圧力。面積が増えるほど低下する曲線。',
    graphChoices: [
      ['inverse', '小さくなる'],
      ['linear-up', '比例して増える'],
      ['fixed', '一定'],
    ],
    correctGraphId: 'inverse',
    graphSummary: '力一定なら、圧力は面積に反比例して小さくなります。',
  }),
  buoyancy: notationLab('buoyancy', {
    arrowPrompt: '完全に液体中にある物体の浮力を描く順に置く。',
    arrowGuide: '物体を始点に、鉛直上向きへ浮力の矢印を描きます。',
    arrowTokens: [
      ['body', '物体'],
      ['up', '鉛直上向き'],
      ['fb', '浮力 Fᵦ'],
    ],
    arrowSummary: '浮力は液体中の物体に鉛直上向きにはたらきます。',
    equationPrompt: '押しのけた液体で浮力を表す式を組む。',
    equationTokens: [
      ['fb', 'Fᵦ'],
      ['eq', '='],
      ['rho', 'ρ'],
      ['g', 'g'],
      ['v', 'V'],
    ],
    equationSummary: '浮力 Fᵦ = ρgV（押しのけた液体の体積V）です。',
    symbolPrompt: 'ρ が表す量は？',
    symbolChoices: [
      ['density', '液体の密度'],
      ['depth', '水深'],
      ['area', '底面積'],
    ],
    correctSymbolId: 'density',
    symbolSummary: 'ρは液体の密度です。',
    graphPrompt: '同じ液体で、押しのける体積が増えると浮力は？',
    graphNotation: ['浮力', '／', '／', '体積 V →'],
    graphSemantics: '横軸が押しのけた体積、縦軸が浮力。原点から右上がり。',
    graphChoices: [
      ['proportional', '比例して増える'],
      ['fixed', '変わらない'],
      ['decrease', '減る'],
    ],
    correctGraphId: 'proportional',
    graphSummary: '同じ液体なら、浮力は押しのけた体積に比例します。',
  }),
  currentMagneticField: notationLab('currentMagneticField', {
    arrowPrompt: '直線電流のまわりの磁界方向を読む順に置く。',
    arrowGuide: '右手の親指を電流、曲げた指を磁界の向きに合わせます。',
    arrowTokens: [
      ['current', '親指＝電流'],
      ['curl', '指を巻く'],
      ['field', '指＝磁界'],
    ],
    arrowSummary: '右ねじの法則で、電流と磁界の向きを対応させます。',
    equationPrompt: '磁界の強さと電流・距離の関係を順に置く。',
    equationTokens: [
      ['b', 'B'],
      ['prop', '∝'],
      ['i', 'I'],
      ['divide', '÷'],
      ['r', 'r'],
    ],
    equationSummary: '長い直線電流の周囲では B は I/r に比例します。',
    symbolPrompt: '磁束密度 B の単位は？',
    symbolChoices: [
      ['tesla', 'T（テスラ）'],
      ['ampere', 'A（アンペア）'],
      ['volt', 'V（ボルト）'],
    ],
    correctSymbolId: 'tesla',
    symbolSummary: '磁束密度の単位はT（テスラ）です。',
    graphPrompt: '距離一定で、電流を増やすと磁界の強さは？',
    graphNotation: ['磁界 B', '／', '／', '電流 I →'],
    graphSemantics: '横軸が電流、縦軸が磁界。原点から右上がり。',
    graphChoices: [
      ['proportional', '比例して増える'],
      ['inverse', '小さくなる'],
      ['fixed', '一定'],
    ],
    correctGraphId: 'proportional',
    graphSummary: '距離一定なら、磁界の強さは電流に比例します。',
  }),
  magneticForce: notationLab('magneticForce', {
    arrowPrompt: '電流が磁界から受ける力の向きを読む順に置く。',
    arrowGuide: '磁界・電流・力の3方向を互いに直角として確かめます。',
    arrowTokens: [
      ['field', '磁界 B'],
      ['current', '電流 I'],
      ['force', '力 F'],
    ],
    arrowSummary: '磁界と電流が直角なら、力はその両方に直角です。',
    equationPrompt: '直角条件で磁力の大きさを表す式を組む。',
    equationTokens: [
      ['f', 'F'],
      ['eq', '='],
      ['b', 'B'],
      ['i', 'I'],
      ['l', 'L'],
    ],
    equationSummary: '磁界と電流が直角なら F = BIL です。',
    symbolPrompt: '式 F = BIL の L は？',
    symbolChoices: [
      ['length', '磁界中にある導線の長さ'],
      ['voltage', '電圧'],
      ['resistance', '抵抗'],
    ],
    correctSymbolId: 'length',
    symbolSummary: 'Lは磁界中にある導線部分の長さです。',
    graphPrompt: 'BとL一定で、電流を増やすと力は？',
    graphNotation: ['力 F', '／', '／', '電流 I →'],
    graphSemantics: '横軸が電流、縦軸が力。原点から右上がり。',
    graphChoices: [
      ['proportional', '比例して増える'],
      ['inverse', '小さくなる'],
      ['fixed', '一定'],
    ],
    correctGraphId: 'proportional',
    graphSummary: 'BとL一定なら、力は電流に比例します。',
  }),
  electromagneticInduction: notationLab('electromagneticInduction', {
    arrowPrompt: '電磁誘導の因果を読む順に置く。',
    arrowGuide: '回路を貫く磁束の変化から、誘導電圧の向きと大きさを考えます。',
    arrowTokens: [
      ['flux-change', '磁束が変化'],
      ['voltage', '誘導電圧'],
      ['current', '閉回路なら電流'],
    ],
    arrowSummary: '磁束の変化で誘導電圧が生じ、閉回路なら電流が流れます。',
    equationPrompt: '誘導電圧と磁束変化の関係を順に置く。',
    equationTokens: [
      ['e', '|E|'],
      ['prop', '∝'],
      ['dphi', '|ΔΦ|'],
      ['divide', '÷'],
      ['dt', 'Δt'],
    ],
    equationSummary: '誘導電圧の大きさは磁束の変化率 |ΔΦ|/Δt に比例します。',
    symbolPrompt: '誘導電圧 E の単位は？',
    symbolChoices: [
      ['volt', 'V（ボルト）'],
      ['tesla', 'T（テスラ）'],
      ['ampere', 'A（アンペア）'],
    ],
    correctSymbolId: 'volt',
    symbolSummary: '電圧の単位はV（ボルト）です。',
    graphPrompt: '同じ磁束変化を短時間で起こすと誘導電圧は？',
    graphNotation: ['電圧 |E|', '＼', '  ＼＿', '変化時間 Δt →'],
    graphSemantics: '横軸が変化にかかる時間、縦軸が誘導電圧。短時間ほど大きい。',
    graphChoices: [
      ['larger-fast', '短時間ほど大きい'],
      ['larger-slow', '長時間ほど大きい'],
      ['fixed', '時間によらず一定'],
    ],
    correctGraphId: 'larger-fast',
    graphSummary: '同じ磁束変化なら、短い時間で変えるほど誘導電圧は大きくなります。',
  }),
  ...STAGE1_PROOF_NOTATION_LABS,
  ...STAGE1_EXPANSION_NOTATION_LABS,
  ...STAGE2_NOTATION_LABS,
}

/** 未知conceptへ似た式を推測せず、必ずundefinedへ倒す。 */
export function notationLabFor(conceptKey: string): NotationLab | undefined {
  return NOTATION_LABS[conceptKey]
}

function isTaggedNotationLab(lab: NotationLab): lab is TaggedNotationLab {
  return Object.hasOwn(lab, 'tasks')
}

export function isNotationArrangeTask(
  task: NotationTask,
): task is NotationArrangeTask {
  return task.kind === 'modelBuild' || task.kind === 'sequence'
}

function conceptFromNeedCode(needCode: string): string {
  return needCode.split('.')[1] ?? 'unknown'
}

/** 旧arrow/equation/symbol/graph正本も、v10のtask unionへ損失なく投影する。 */
export function canonicalNotationTasks(lab: NotationLab): NotationTask[] {
  if (isTaggedNotationLab(lab)) return lab.tasks
  return [
    ...lab.orderTasks.map((task, index): NotationArrangeTask => ({
      kind: index === 0 ? 'sequence' : 'modelBuild',
      id: task.id,
      needCode: task.needCode,
      title: task.title,
      prompt: task.prompt,
      guide: task.traceGuide,
      tracePattern: task.tracePattern,
      tokens: task.tokens,
      correctOrderIds: task.correctOrderIds,
      solutionSummary: task.solutionSummary,
    })),
    {
      kind: 'symbolMatch',
      id: `${conceptFromNeedCode(lab.symbolMatch.needCode)}.symbol`,
      needCode: lab.symbolMatch.needCode,
      title: '単位記号を意味と結ぶ',
      prompt: lab.symbolMatch.prompt,
      representation: [],
      representationSemanticsLabel: '選択肢の記号と意味を対応させます。',
      choices: lab.symbolMatch.choices,
      correctChoiceId: lab.symbolMatch.correctChoiceId,
      solutionSummary: lab.symbolMatch.solutionSummary,
    },
    {
      kind: 'graphRead',
      id: `${conceptFromNeedCode(lab.graphRead.needCode)}.graph`,
      needCode: lab.graphRead.needCode,
      title: 'グラフを読む',
      prompt: lab.graphRead.prompt,
      representation: lab.graphRead.graphNotation,
      representationSemanticsLabel: lab.graphRead.graphSemanticsLabel,
      choices: lab.graphRead.choices,
      correctChoiceId: lab.graphRead.correctChoiceId,
      solutionSummary: lab.graphRead.solutionSummary,
    },
  ]
}

function copyTracePattern(trace: NotationTracePattern): NotationTracePattern {
  return {
    ...trace,
    strokes: trace.strokes.map((stroke) => ({
      ...stroke,
      points: stroke.points.map((point) => ({ ...point })),
    })),
    strokeOrderIds: [...trace.strokeOrderIds],
  }
}

function copyNotationTask(task: NotationTask): NotationTask {
  if (isNotationArrangeTask(task)) {
    return {
      ...task,
      tokens: task.tokens.map((token) => ({ ...token })),
      correctOrderIds: [...task.correctOrderIds],
      ...(task.tracePattern == null
        ? {}
        : { tracePattern: copyTracePattern(task.tracePattern) }),
    }
  }
  return {
    ...task,
    representation: [...task.representation],
    choices: task.choices.map((choice) => ({ ...choice })),
  }
}

/** 公開wireは全conceptをv10 task unionへそろえ、正本との参照共有を切る。 */
export function publicNotationLab(lab: NotationLab): TaggedNotationLab {
  return { tasks: canonicalNotationTasks(lab).map(copyNotationTask) }
}

function hasExactKeys(value: unknown, expected: readonly string[]): boolean {
  if (value == null || typeof value !== 'object' || Array.isArray(value)) return false
  const actual = Object.keys(value)
  return actual.length === expected.length && actual.every((key) => expected.includes(key))
}

function nonEmpty(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0
}

function validateTracePattern(
  trace: NotationTracePattern,
  taskId: string,
): string[] {
  const problems: string[] = []
  if (!hasExactKeys(trace, ['semanticsLabel', 'strokes', 'strokeOrderIds'])) {
    return [`${taskId}: tracePatternに未知fieldまたは必須field欠落`]
  }
  if (!Array.isArray(trace.strokes) || !Array.isArray(trace.strokeOrderIds)) {
    return [`${taskId}: tracePatternが空`]
  }
  if (trace.strokes.some((stroke) => !hasExactKeys(stroke, ['id', 'label', 'points']))) {
    return [`${taskId}: strokeに未知fieldまたは必須field欠落`]
  }
  const strokeIds = trace.strokes.map((stroke) => stroke.id)
  if (!nonEmpty(trace.semanticsLabel) || trace.strokes.length < 1) {
    problems.push(`${taskId}: tracePatternが空`)
  }
  if (new Set(strokeIds).size !== strokeIds.length
    || trace.strokes.some((stroke) => !nonEmpty(stroke.id) || !nonEmpty(stroke.label))) {
    problems.push(`${taskId}: trace strokeが空または重複`)
  }
  if (trace.strokeOrderIds.length !== strokeIds.length
    || new Set(trace.strokeOrderIds).size !== trace.strokeOrderIds.length
    || trace.strokeOrderIds.some((id) => !strokeIds.includes(id))) {
    problems.push(`${taskId}: strokeOrderIdsがstrokeの全順列でない`)
  }
  for (const stroke of trace.strokes) {
    if (!Array.isArray(stroke.points)
      || stroke.points.some((point) => !hasExactKeys(point, ['x', 'y']))) {
      problems.push(`${taskId}/${stroke.id}: strokeに未知fieldまたは座標欠落`)
      continue
    }
    const normalizedLength = stroke.points.slice(1).reduce((length, point, index) => {
      const previous = stroke.points[index]!
      return length + Math.hypot(point.x - previous.x, point.y - previous.y)
    }, 0)
    if (stroke.points.length < 3 || normalizedLength < 0.15
      || stroke.points.some((point) =>
        !Number.isFinite(point.x) || !Number.isFinite(point.y)
        || point.x < 0 || point.x > 1 || point.y < 0 || point.y > 1
      )) {
      problems.push(`${taskId}/${stroke.id}: 短すぎるstrokeまたは0..1範囲外のtrace`)
    }
  }
  return problems
}

export function validateNotationLab(lab: NotationLab): string[] {
  const problems: string[] = []
  const topLevelKeys = isTaggedNotationLab(lab)
    ? ['tasks']
    : ['orderTasks', 'symbolMatch', 'graphRead']
  if (!hasExactKeys(lab, topLevelKeys)) {
    problems.push('notation lab: 未知fieldまたは必須field欠落')
  }
  const tasks = canonicalNotationTasks(lab)
  if (tasks.length < 2 || tasks.length > 6) {
    problems.push('notation lab: taskは2〜6件必要')
  }
  if (new Set(tasks.map((task) => task.id)).size !== tasks.length
    || new Set(tasks.map((task) => task.needCode)).size !== tasks.length) {
    problems.push('notation lab: task IDまたはneedCodeが重複')
  }
  if (new Set(tasks.map((task) => task.kind)).size < 2) {
    problems.push('notation lab: 2種類以上のtask kindが必要')
  }
  if (!tasks.some(isNotationArrangeTask)
    || !tasks.some((task) => !isNotationArrangeTask(task))) {
    problems.push('notation lab: 組み立て課題と読み取り課題が両方必要')
  }

  for (const task of tasks) {
    const taskId = nonEmpty(task?.id) ? task.id : 'unknown'
    if (!NOTATION_TASK_KINDS.includes(task.kind)
      || !nonEmpty(task.id) || !nonEmpty(task.needCode) || !nonEmpty(task.title)
      || !nonEmpty(task.prompt) || !nonEmpty(task.solutionSummary)) {
      problems.push(`${taskId}: kind・ID・needCode・文言に空欄`)
    }
    const needMatch = /^science\.([A-Za-z][A-Za-z0-9]{0,63})\.notation\.([A-Za-z][A-Za-z0-9]{0,63})$/.exec(task.needCode)
    const legacyKindBySuffix: Readonly<Record<string, NotationTaskKind>> = {
      arrow: 'sequence',
      equation: 'modelBuild',
      symbol: 'symbolMatch',
      graph: 'graphRead',
    }
    const suffix = needMatch?.[2]
    const expectedKind = suffix == null ? undefined : legacyKindBySuffix[suffix] ?? suffix
    if (needMatch == null || expectedKind !== task.kind) {
      problems.push(`${taskId}: task kindと対応する安定needCodeが無い`)
    }

    if (isNotationArrangeTask(task)) {
      const expectedKeys = task.tracePattern == null
        ? ['kind', 'id', 'needCode', 'title', 'prompt', 'guide', 'tokens', 'correctOrderIds', 'solutionSummary']
        : ['kind', 'id', 'needCode', 'title', 'prompt', 'guide', 'tracePattern', 'tokens', 'correctOrderIds', 'solutionSummary']
      if (!hasExactKeys(task, expectedKeys)
        || !Array.isArray(task.tokens) || !Array.isArray(task.correctOrderIds)) {
        problems.push(`${taskId}: arrange taskに未知fieldまたは必須field欠落`)
        continue
      }
      if (!nonEmpty(task.guide)
        || task.tokens.some((token) => !hasExactKeys(token, ['id', 'label'])
          || !nonEmpty(token.id) || !nonEmpty(token.label))) {
        problems.push(`${taskId}: guideまたはtokenが空・不正`)
      }
      const tokenIds = task.tokens.map((token) => token.id)
      if (tokenIds.length < 2 || tokenIds.length > 6
        || new Set(tokenIds).size !== tokenIds.length
        || task.correctOrderIds.length !== tokenIds.length
        || new Set(task.correctOrderIds).size !== tokenIds.length
        || task.correctOrderIds.some((id) => !tokenIds.includes(id))) {
        problems.push(`${taskId}: correctOrderIdsが2〜6 tokenの全順列でない`)
      }
      if (JSON.stringify(task.correctOrderIds) === JSON.stringify(tokenIds)) {
        problems.push(`${taskId}: 表示順が正答順を示している`)
      }
      if (task.tracePattern != null) {
        problems.push(...validateTracePattern(task.tracePattern, taskId))
      }
      continue
    }

    if (!hasExactKeys(task, [
      'kind',
      'id',
      'needCode',
      'title',
      'prompt',
      'representation',
      'representationSemanticsLabel',
      'choices',
      'correctChoiceId',
      'solutionSummary',
    ]) || !Array.isArray(task.representation) || !Array.isArray(task.choices)) {
      problems.push(`${taskId}: choice taskに未知fieldまたは必須field欠落`)
      continue
    }
    if (task.choices.some((choice) => !hasExactKeys(choice, ['id', 'label'])
      || !nonEmpty(choice.id) || !nonEmpty(choice.label))) {
      problems.push(`${taskId}: choiceが空または不正`)
    }
    const choiceIds = task.choices.map((choice) => choice.id)
    if (choiceIds.length < 2 || choiceIds.length > 5
      || new Set(choiceIds).size !== choiceIds.length
      || !choiceIds.includes(task.correctChoiceId)) {
      problems.push(`${taskId}: correctChoiceIdに対応する重複しない2〜5 choicesが必要`)
    }
    const representationRequired = task.kind !== 'symbolMatch'
    if (!nonEmpty(task.representationSemanticsLabel)
      || task.representation.some((line) => !nonEmpty(line))
      || (representationRequired && task.representation.length < 2)
      || task.representation.length > 10) {
      problems.push(`${taskId}: representationまたはSemanticsが空・過剰`)
    }
  }
  return problems
}
