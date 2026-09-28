import type {
  NotationArrangeTask,
  NotationChoice,
  NotationChoiceTask,
  NotationTaskKind,
  TaggedNotationLab,
} from './notation-labs.js'

type Pair = readonly [id: string, label: string]

function arrange(
  conceptKey: string,
  kind: 'modelBuild' | 'sequence',
  title: string,
  prompt: string,
  guide: string,
  orderedTokens: readonly Pair[],
  solutionSummary: string,
): NotationArrangeTask {
  const canonical = orderedTokens.map(([id, label]) => ({ id, label }))
  return {
    kind,
    id: `${conceptKey}.${kind}`,
    needCode: `science.${conceptKey}.notation.${kind}`,
    title,
    prompt,
    guide,
    tokens: [...canonical.slice(1), canonical[0]!],
    correctOrderIds: canonical.map((token) => token.id),
    solutionSummary,
  }
}
function choices(entries: readonly Pair[]): NotationChoice[] {
  return entries.map(([id, label]) => ({ id, label }))
}

function choice(
  conceptKey: string,
  kind: Exclude<NotationTaskKind, 'modelBuild' | 'sequence'>,
  title: string,
  prompt: string,
  representation: readonly string[],
  representationSemanticsLabel: string,
  entries: readonly Pair[],
  correctChoiceId: string,
  solutionSummary: string,
): NotationChoiceTask {
  return {
    kind,
    id: `${conceptKey}.${kind}`,
    needCode: `science.${conceptKey}.notation.${kind}`,
    title,
    prompt,
    representation: [...representation],
    representationSemanticsLabel,
    choices: choices(entries),
    correctChoiceId,
    solutionSummary,
  }
}

/** 物理の矢印・式を必須にせず、各領域の表現そのものを操作するv10正本。 */
export const STAGE1_PROOF_NOTATION_LABS: Readonly<
  Record<string, TaggedNotationLab>
> = {
  density: {
    tasks: [
      arrange(
        'density',
        'modelBuild',
        '密度の比を組み立てる',
        '密度を求める関係を、求める量から順に組み立てる。',
        '密度を左に置き、単位体積当たりになる割り算をつくります。',
        [
          ['density', '密度'],
          ['equals', '＝'],
          ['mass', '質量'],
          ['divide', '÷'],
          ['volume', '体積'],
        ],
        '密度＝質量÷体積。質量と体積を同じ単位系でそろえます。',
      ),
      choice(
        'density',
        'tableRead',
        '質量と体積の表を読む',
        'PとQの密度を表から計算し、正しい比較を選ぶ。',
        ['試料 | 質量 | 体積', 'P | 27 g | 10 cm³', 'Q | 54 g | 20 cm³'],
        '列は試料、質量、体積。Pは27グラムと10立方センチメートル、Qは54グラムと20立方センチメートル。',
        [
          ['q-double', 'Qは質量が2倍なので密度も2倍'],
          ['same-ratio', 'PもQも2.7 g/cm³で同じ'],
          ['p-half', 'Pは体積が半分なので密度も半分'],
        ],
        'same-ratio',
        'Pは27÷10、Qは54÷20で、どちらも2.7 g/cm³です。',
      ),
      choice(
        'density',
        'symbolMatch',
        '密度の単位を選ぶ',
        '質量をg、体積をcm³で測ったときの密度の単位は？',
        [],
        '質量の単位グラムを、体積の単位立方センチメートルで割った記号を選びます。',
        [
          ['gram', 'g'],
          ['gram-per-cubic-centimeter', 'g/cm³'],
          ['cubic-centimeter', 'cm³'],
        ],
        'gram-per-cubic-centimeter',
        '密度は質量÷体積なので、単位はg/cm³です。',
      ),
    ],
  },
  cells: {
    tasks: [
      choice(
        'cells',
        'labelDiagram',
        '細胞図の境界を見分ける',
        '細胞膜の外側に厚い境界があり、隣の細胞と形を支える部分の名称を選ぶ。',
        ['┏━━━━━━┓  外側の厚い境界', '┃  ┌────┐  ┃  内側の細胞膜', '┗━━━━━━┛'],
        '植物細胞の模式図。外側に厚い境界、その内側に細胞膜を示す細い境界がある。',
        [
          ['cell-membrane', '細胞膜'],
          ['cell-wall', '細胞壁'],
          ['chloroplast', '葉緑体'],
        ],
        'cell-wall',
        '細胞膜の外側にあり、形を支える厚い境界は細胞壁です。',
      ),
      arrange(
        'cells',
        'modelBuild',
        '体の階層モデルを組む',
        '多細胞生物のつくりを、小さい単位から大きい単位へ並べる。',
        '一つの細胞から、同じ働きの集まり、器官、個体へ広げます。',
        [
          ['cell', '細胞'],
          ['tissue', '組織'],
          ['organ', '器官'],
          ['organism', '個体'],
        ],
        '細胞が集まって組織をつくり、組織が器官をつくり、器官が協力して個体を支えます。',
      ),
      choice(
        'cells',
        'tableRead',
        '植物と動物の特徴表を読む',
        '表から、植物と動物の細胞に共通する構造を選ぶ。',
        ['構造 | 植物 | 動物', '細胞膜 | あり | あり', '細胞壁 | あり | なし', '葉緑体 | 一部にあり | なし'],
        '植物と動物の細胞構造の比較表。細胞膜は両方、細胞壁は植物、葉緑体は一部の植物細胞にある。',
        [
          ['cell-wall', '細胞壁'],
          ['cell-membrane', '細胞膜'],
          ['chloroplast', '葉緑体'],
        ],
        'cell-membrane',
        '細胞膜は植物と動物の細胞に共通します。',
      ),
    ],
  },
  humidityClouds: {
    tasks: [
      arrange(
        'humidityClouds',
        'sequence',
        '上昇から雲粒までを並べる',
        '湿った空気が上昇して雲粒ができるまでを、因果の順に並べる。',
        '気圧、膨張、気温、露点、凝結の順でつなぎます。',
        [
          ['pressure-drops', '周囲の気圧が下がる'],
          ['air-expands', '空気が膨張する'],
          ['air-cools', '気温が下がる'],
          ['dew-point', '露点へ達する'],
          ['condensation', '水蒸気が凝結する'],
        ],
        '上昇して気圧が下がると空気が膨張・冷却し、露点で凝結が始まります。',
      ),
      choice(
        'humidityClouds',
        'tableRead',
        '飽和水蒸気量の表を読む',
        '同じ水蒸気量を含む空気を20℃から10℃へ冷やしたときの変化を選ぶ。',
        ['気温 | 飽和水蒸気量', '20℃ | 17.3 g/m³', '10℃ | 9.4 g/m³', '実際の水蒸気量 | 12.0 g/m³'],
        '20度の飽和水蒸気量17.3、10度は9.4、実際の水蒸気量は1立方メートル当たり12.0グラム。',
        [
          ['all-vapor', '10℃でも12.0 g/m³すべてが水蒸気のまま'],
          ['condense-excess', '10℃で含み切れない分が凝結する'],
          ['vapor-increases', '冷やすだけで水蒸気量が17.3 g/m³へ増える'],
        ],
        'condense-excess',
        '10℃で含める最大量は9.4 g/m³なので、12.0との差の一部が凝結します。',
      ),
      choice(
        'humidityClouds',
        'graphRead',
        '気温と飽和水蒸気量のグラフを読む',
        '気温が下がる向きへグラフを読んだとき、飽和水蒸気量はどうなる？',
        ['飽和水蒸気量', '        ／', '     ／', '気温 →'],
        '横軸が気温、縦軸が飽和水蒸気量。気温が高い側ほど曲線が上がる。',
        [
          ['decreases', '小さくなる'],
          ['fixed', '変わらない'],
          ['increases', '大きくなる'],
        ],
        'decreases',
        '気温が下がると飽和水蒸気量は小さくなり、同じ水蒸気量でも飽和へ近づきます。',
      ),
    ],
  },
  strataRelativeAge: {
    tasks: [
      arrange(
        'strataRelativeAge',
        'sequence',
        '地層模型の出来事を並べる',
        '下の3層を切る断層と、それを覆う上層の出来事を古い順に並べる。',
        '堆積した層、切った出来事、切られていない上層の順を確かめます。',
        [
          ['lower-layers', '下の3層が堆積'],
          ['fault', '断層が3層を切る'],
          ['upper-layer', '上層が断層を覆う'],
        ],
        '下の3層の堆積、断層の活動、上層の堆積の順です。',
      ),
      choice(
        'strataRelativeAge',
        'labelDiagram',
        '地層断面の前後関係を読む',
        '斜め線FがA・B・Cを切り、Dには届かない。Fより後にできた層を選ぶ。',
        ['──────── D', '────╱── C', '───╱─── B', '──╱──── A', '  F'],
        '下からA、B、C、Dの地層。斜めの断層FはA、B、Cを切るがDには届かない。',
        [
          ['layer-a', '地層A'],
          ['layer-c', '地層C'],
          ['layer-d', '地層D'],
        ],
        'layer-d',
        'Dは断層Fを覆い、Fに切られていないため、Fの活動より後に堆積しました。',
      ),
      arrange(
        'strataRelativeAge',
        'modelBuild',
        '離れた柱状図を鍵層で結ぶ',
        '2地点の前後関係を、同じ火山灰層を時間の目印として組み立てる。',
        '地点Pの下位層、共通の鍵層、地点Qの上位層の順に読みます。',
        [
          ['p-lower', 'Pの化石X層'],
          ['key-layer', '共通の火山灰鍵層'],
          ['q-upper', 'Qの化石Y層'],
        ],
        '鍵層を同時期の目印とすれば、X層は鍵層より前、Y層は鍵層より後です。',
      ),
    ],
  },
}
