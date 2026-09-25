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

/** Stage 2「化学変化と原子・分子」3概念の表・モデル・因果を操作するNotation正本。 */
export const STAGE2_NOTATION_LABS: Readonly<
  Record<string, TaggedNotationLab>
> = {
  combinationDecomposition: {
    tasks: [
      choice(
        'combinationDecomposition', 'tableRead', '反応前後の性質表を読む',
        '加熱前後の記録から、化合が起きたと判断できる行の読み取りを選ぶ。',
        ['物質 | 見た目 | 磁石への反応', '鉄粉と硫黄（加熱前） | 灰と黄の粒 | 鉄の粒だけが引かれる', '加熱後の黒いかたまり | 黒い固体 | 引かれない'],
        '加熱前は粒ごとの性質が残り、加熱後は性質の違う物質になっている。',
        [
          ['still-mixture', '加熱前の粉末はすでに硫化鉄である'],
          ['reaction-occurred', '加熱後の物質は反応前と性質が異なり、化合が起きた'],
          ['no-change', '見た目が変わっただけで、物質は変わっていない'],
        ],
        'reaction-occurred',
        '磁石への反応が消えたことから、別の性質の物質が生成したと判断します。',
      ),
      arrange(
        'combinationDecomposition', 'sequence', '化学変化を判断する手順を並べる',
        '反応が化学変化かどうかを判断する手順を、記録の読み方の順に並べる。',
        '反応前の性質、生成物の性質、別物質かの判断、変化の分類をつなぎます。',
        [
          ['record-before', '反応前の物質の性質を確認する'],
          ['inspect-products', '生成物の性質を調べる'],
          ['compare-properties', '反応前後で性質が異なるかを比べる'],
          ['classify-change', '別物質の生成なら化合・分解などの化学変化と分類する'],
        ],
        '反応前後の性質を比べ、別物質が生じたかで化学変化かを判断します。',
      ),
      choice(
        'combinationDecomposition', 'symbolMatch', '変化の名前を反応へ結ぶ',
        '「炭酸水素ナトリウムを加熱すると炭酸ナトリウム・水・二酸化炭素が生じた」変化の名前を選ぶ。',
        ['反応前 | 反応後', '炭酸水素ナトリウム | 炭酸ナトリウム・水・二酸化炭素'],
        '1種類の物質が、性質の違う複数の物質に分かれた。',
        [
          ['decomposition', '分解'],
          ['combination', '化合'],
          ['state-change', '状態変化'],
        ],
        'decomposition',
        '1種類の物質が2種類以上の別物質へ分かれる変化は分解です。',
      ),
    ],
  },
  oxidationReduction: {
    tasks: [
      choice(
        'oxidationReduction', 'tableRead', '酸素のやりとり表を読む',
        '酸化銅と炭素を加熱した記録から、酸素を失った物質に起きた変化の名前を選ぶ。',
        ['物質 | 変化 | 酸素の行き先', '酸化銅 | 黒い粉末から赤い光沢の銅へ | 酸素を失った', '炭素 | 炭素から二酸化炭素へ | 酸素を得た'],
        '酸素を失った物質は還元され、酸素を得た物質は酸化された。',
        [
          ['oxidized', '酸化'],
          ['reduced', '還元'],
          ['decomposed', '分解'],
        ],
        'reduced',
        '酸化銅は酸素を失って銅になったので、還元されました。',
      ),
      arrange(
        'oxidationReduction', 'sequence', '酸化で質量が増える筋道を並べる',
        '金属を空気中で加熱したとき質量が増える理由を、出来事の順に並べる。',
        '酸素との結びつき、酸化物の生成、質量の増加をつなぎます。',
        [
          ['oxygen-joins', '空気中の酸素が金属と結びつく'],
          ['oxide-forms', '酸化物という別の物質が生成する'],
          ['mass-increases', '結びついた酸素の分だけ質量が増える'],
        ],
        '酸素が結びついて酸化物ができるので、酸化後の物質は重くなります。',
      ),
      choice(
        'oxidationReduction', 'graphRead', '銅と酸素の質量グラフを読む',
        '加熱した銅の質量と結びついた酸素の質量の記録から、正しい読み取りを選ぶ。',
        ['銅の質量(g) | 結びついた酸素の質量(g)', '0.4 | 0.1', '0.8 | 0.2', '1.2 | 0.3'],
        '銅の質量が2倍・3倍になると、結びつく酸素の質量も2倍・3倍になる。',
        [
          ['proportional', '結びつく酸素の質量は、銅の質量に比例する'],
          ['unrelated', '酸素の質量は、銅の質量と関係なくばらばらである'],
          ['fixed-oxygen', '銅の質量が違っても、結びつく酸素は常に同じ量である'],
        ],
        'proportional',
        '反応する物質の質量の間には一定の関係があり、酸素は銅の質量に比例して結びつきます。',
      ),
    ],
  },
  massConservation: {
    tasks: [
      choice(
        'massConservation', 'tableRead', '開いた系と閉じた系の記録を読む',
        '同じ反応を2つの装置で行った質量記録の違いを説明する解釈を選ぶ。',
        ['装置 | 反応前(g) | 反応後(g)', '開いた容器 | 100.0 | 98.9', '密閉袋 | 100.0 | 100.0'],
        '開いた容器では気体が外へ出た分だけ減り、密閉袋では全体の質量が変わらない。',
        [
          ['law-broken', '開いた系では質量保存の法則が成り立たない'],
          ['escaped-gas', '開いた容器では発生した気体が外へ出た'],
          ['scale-error', '測定差ははかりの故障による'],
        ],
        'escaped-gas',
        '開いた容器で減った分は外へ出た気体の質量で、密閉すれば総和は等しくなります。',
      ),
      arrange(
        'massConservation', 'modelBuild', '原子モデルで化学変化を組み立てる',
        '化学変化の前後で原子がどうなるかを、モデルの並びとして組み立てる。',
        '反応前の原子、結びつきの組み替え、生成物の原子、保存されるものをつなぎます。',
        [
          ['reactant-atoms', '反応前の原子の集まり'],
          ['atoms-rearranged', '原子の結びつき方が組み替わる'],
          ['product-atoms', '同じ原子が別の結びつきで生成物になる'],
          ['same-total', '原子の種類と数、質量の総和は同じ'],
        ],
        '原子は消えず増えもせず、結びつきだけが変わるので質量の総和は変わりません。',
      ),
      choice(
        'massConservation', 'symbolMatch', '質量保存の式を選ぶ',
        '化学変化の質量保存を正しく表した表現を選ぶ。',
        ['反応物 | → | 生成物', '塩酸＋炭酸水素ナトリウム | → | 塩化ナトリウム＋水＋二酸化炭素'],
        '逃げた気体を含めた生成物すべての質量の和は、反応物の質量の和と等しい。',
        [
          ['sum-equal', '反応物の質量の和＝生成物の質量の和'],
          ['products-less', '生成物の質量の和は必ず小さい'],
          ['gas-excluded', '気体が出た分だけ差し引いて等しい'],
        ],
        'sum-equal',
        '気体を含めた生成物すべての質量の和は、反応物の質量の和と等しくなります。',
      ),
    ],
  },
}
