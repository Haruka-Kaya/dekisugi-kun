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
  electrolyte: {
    tasks: [
      choice(
        'electrolyte', 'tableRead', '電気を通した液の記録表を読む',
        '液ごとの記録から、イオンが存在すると判断できる液の読み取りを選ぶ。',
        ['液 | 電流 | 電極の変化', '食塩水 | 流れた | 電極に物質が生成', '砂糖水 | 流れない | 変化なし', 'うすい塩酸 | 流れた | 両極に気体'],
        '電流が流れて電極に物質ができる液には、電気を帯びた粒子（イオン）がある。',
        [
          ['ions-present', '流れた液にはイオンがあり、電極の変化がその証拠になる'],
          ['all-have-ions', 'どの液にもイオンがあるので、流れないのは別の理由'],
          ['color-decides', '透明かどうかが電気を通すかを決める'],
        ],
        'ions-present',
        '電流が流れ電極に物質ができた液だけにイオンがあると判断します。',
      ),
      arrange(
        'electrolyte', 'modelBuild', 'イオンへの道筋を組み立てる',
        '原子がイオンになる流れを、モデルの並びとして組み立てる。',
        '原子の成り立ち、電子のやりとり、電気を帯びた粒子、イオン式をつなぎます。',
        [
          ['atom-structure', '原子は電子と原子核からできている'],
          ['electron-transfer', '原子が電子を失うか受け取る'],
          ['charged-particle', '電気を帯びた粒子＝イオンになる'],
          ['ion-formula', 'Na⁺・Cl⁻のように化学式で表す'],
        ],
        '原子が電子をやりとりしてイオンになり、イオンは化学式で表します。',
      ),
      choice(
        'electrolyte', 'symbolMatch', '陽イオンと陰イオンを式で結ぶ',
        '「ナトリウム原子が電子を1つ失った」あとの粒子を表す式を選ぶ。',
        ['ナトリウム原子 | 電子を1つ失う | → ?'],
        '電子を失った原子はプラスの電気を帯びた陽イオンになる。',
        [
          ['sodium-ion', 'Na⁺（陽イオン）'],
          ['chloride-ion', 'Cl⁻（陰イオン）'],
          ['free-electron', 'e⁻（電子そのもの）'],
        ],
        'sodium-ion',
        '電子を失ったナトリウム原子は、プラスの陽イオン Na⁺ になります。',
      ),
    ],
  },
  acidAlkali: {
    tasks: [
      choice(
        'acidAlkali', 'tableRead', '指示薬の色変化表を読む',
        'BTB溶液の色変化の記録から、アルカリ性の液を示す読み取りを選ぶ。',
        ['液 | BTB溶液の色', '液A | 黄色', '液B | 緑色のまま', '液C | 青色'],
        '黄色は酸性、緑色は中性、青色はアルカリ性を示す。',
        [
          ['a-alkaline', '液Aがアルカリ性'],
          ['c-alkaline', '液Cがアルカリ性'],
          ['b-alkaline', '液Bがアルカリ性'],
        ],
        'c-alkaline',
        'BTB溶液が青色に変わるのはアルカリ性の液で、液Cが該当します。',
      ),
      arrange(
        'acidAlkali', 'sequence', '液の性質を調べる手順を並べる',
        '液が酸性かアルカリ性かを調べる手順を、記録の順に並べる。',
        '指示薬を加える、色を記録する、色表と比べる、性質を判断するをつなぎます。',
        [
          ['add-indicator', '液に指示薬を加える'],
          ['record-color', '変わった色を記録する'],
          ['compare-table', '色と性質の対応表と比べる'],
          ['decide-property', '酸性・中性・アルカリ性を判断する'],
        ],
        '指示薬の色を対応表と比べて、液の性質を判断します。',
      ),
      choice(
        'acidAlkali', 'graphRead', 'pHの目盛りを読む',
        'pHの目盛り図から、酸性・アルカリ性の強さの読み取りとして正しいものを選ぶ。',
        ['pH | 0 … 7 … 14', '小さい側 | 強い酸', '7 | 中性', '大きい側 | 強いアルカリ'],
        '7が中性で、小さいほど強い酸、大きいほど強いアルカリ。',
        [
          ['ph-correct', '7から遠いほど酸性またはアルカリ性が強い'],
          ['ph-reversed', '14に近いほど強い酸で、0に近いほど強いアルカリ'],
          ['ph-neutral-high', 'pHが大きいほど中性に近い'],
        ],
        'ph-correct',
        'pHは7が中性で、そこから離れるほど酸性・アルカリ性が強くなります。',
      ),
    ],
  },
  neutralizationBattery: {
    tasks: [
      choice(
        'neutralizationBattery', 'tableRead', '混ぜた後の液の成分表を読む',
        '中和の前後のイオンの記録から、正しい読み取りを選ぶ。',
        ['反応前のイオン | 反応後に残るもの', 'H⁺・Cl⁻・Na⁺・OH⁻ | H₂O・Na⁺・Cl⁻', '乾燥後 | 塩化ナトリウムの結晶'],
        '水素イオンと水酸化物イオンは水になり、残ったイオンから塩ができる。',
        [
          ['all-vanish', 'すべてのイオンが消えて水だけが残る'],
          ['salt-forms', '水ができ、残ったイオンから塩ができる'],
          ['acid-remains', '酸のイオンだけが残り、液は酸性のまま'],
        ],
        'salt-forms',
        'H⁺とOH⁻が結びついて水になり、残ったNa⁺とCl⁻から塩ができます。',
      ),
      arrange(
        'neutralizationBattery', 'sequence', '電池で電流が流れる順を並べる',
        'ダニエル電池で電流が取り出される流れを、出来事の順に並べる。',
        '亜鉛のイオン化、電子の移動、銅板での受け取り、電流の取り出しをつなぎます。',
        [
          ['zinc-ionizes', 'イオンになりやすい亜鉛が電子を放出して亜鉛イオンになる'],
          ['electrons-flow', '放出された電子が回路を通って銅板へ流れる'],
          ['electrons-received', '銅板で電子が受け取られる'],
          ['current-out', '外部回路に電流として取り出される'],
        ],
        'イオンへのなりやすさの差が電子の一方向の流れを生み、電流として取り出せます。',
      ),
      choice(
        'neutralizationBattery', 'symbolMatch', '中和を表す表現を選ぶ',
        '中和で起きる変化をイオンの式で正しく表したものを選ぶ。',
        ['酸の粒 | アルカリの粒 | 生成物', 'H⁺ | OH⁻ | ?'],
        '水素イオンと水酸化物イオンが結びついて水になる。',
        [
          ['water-formed', 'H⁺ ＋ OH⁻ → H₂O'],
          ['salt-direct', 'Na⁺ ＋ Cl⁻ → H₂O'],
          ['acid-joins', 'H⁺ ＋ OH⁻ → NaCl'],
        ],
        'water-formed',
        '中和では水素イオンと水酸化物イオンが結びついて水ができます。',
      ),
    ],
  },
  reproduction: {
    tasks: [
      arrange(
        'reproduction', 'sequence', '体細胞分裂の順序を並べる',
        'タマネギの根端で起きる体細胞分裂の記録を、起きる順に並べ替える。',
        '染色体の写し取りから始まり、細胞が分かれて増え、細胞の成長で体が大きくなる順です。',
        [
          ['chromosome-copy', '染色体が写し取られる'],
          ['chromosome-split', '染色体が2つの核へ分けられる'],
          ['cell-split', '細胞が2つに分かれて増える'],
          ['cell-growth', '増えた細胞が成長して体が大きくなる'],
        ],
        '写し取り→分配→分裂→細胞の成長、の順です。',
      ),
      choice(
        'reproduction', 'tableRead', '殖え方と染色体の表を読む',
        '有性生殖と無性生殖の子の染色体の記録から、正しい対応を選ぶ。',
        ['殖え方 | 受精 | 子の染色体', '有性生殖 | あり | 両親の染色体を組み合わせる', '無性生殖 | なし | 親と同じ染色体'],
        '受精の有無で、子が両親の染色体を組み合わせるか親と同じかが決まる。',
        [
          ['sexual-same', '有性生殖の子は親と同じ染色体をもつ'],
          ['correct-pair', '無性生殖の子は親と同じ染色体をもち、有性生殖の子は両親の組合せをもつ'],
          ['asexual-diverse', '無性生殖の子は兄弟で染色体が違う'],
        ],
        'correct-pair',
        '無性生殖では親の体の一部から親と同じ染色体の個体ができます。',
      ),
      arrange(
        'reproduction', 'modelBuild', '生殖細胞から成体への道筋を組む',
        '有性生殖で受精卵から新しい個体が育つ道筋を、段階順に組み立てる。',
        '減数分裂で半分になった生殖細胞が受精し、体細胞分裂で育つ順です。',
        [
          ['meiosis', '生殖細胞が減数分裂する'],
          ['fertilization', '受精して受精卵ができる'],
          ['body-division', '受精卵が体細胞分裂を繰り返す'],
          ['adult', '新しい個体が育つ'],
        ],
        '減数分裂→受精→体細胞分裂→成体、の道筋です。',
      ),
    ],
  },
  heredity: {
    tasks: [
      choice(
        'heredity', 'tableRead', '交配結果の表を読む',
        'エンドウの交配記録から、遺伝子の組合せと形質の対応を選ぶ。',
        ['交配 | 子の組合せ | 現れる形質', 'AA × aa | Aa | すべて優性形質', 'Aa × Aa | AA・Aa・aa | 優性：劣性＝3：1'],
        'Aが1つでもあれば優性形質、aaのときだけ劣性形質が現れる。',
        [
          ['aa-dominant', 'aaの組合せでも優性形質が現れる'],
          ['correct-ratio', 'Aa×Aaの子は優性形質と劣性形質がおよそ3：1になる'],
          ['half-half', 'Aa×Aaの子は優性と劣性が半々になる'],
        ],
        'correct-ratio',
        'Aa×Aaでは子の組合せがAA・Aa・Aa・aaになり、およそ3：1で現れます。',
      ),
      arrange(
        'heredity', 'modelBuild', '遺伝子の伝わる道筋を組む',
        '形質が親から子へ伝わる道筋を、染色体と遺伝子の段階順に組み立てる。',
        '遺伝子は染色体にのり、減数分裂で半分になって受精で組み合わさる順です。',
        [
          ['gene-on-chromosome', '遺伝子が染色体にのっている'],
          ['meiosis', '減数分裂で生殖細胞の染色体が半分になる'],
          ['fertilization', '受精で両親の染色体が組み合わさる'],
          ['trait', '組合せに応じて形質が現れる'],
        ],
        '染色体の遺伝子→減数分裂→受精→形質、の道筋です。',
      ),
      choice(
        'heredity', 'graphRead', '形質の割合のグラフを読む',
        'Aa×Aaの子の形質の割合を示すグラフから、正しい読み取りを選ぶ。',
        ['子の形質 | 個体数', '優性形質 | およそ3/4', '劣性形質 | およそ1/4'],
        '優性形質の個体が劣性形質のおよそ3倍になる。',
        [
          ['equal', '優性と劣性は同じ数ずつ現れる'],
          ['three-quarter', '優性形質がおよそ4分の3を占める'],
          ['recessive-more', '劣性形質の方が多く現れる'],
        ],
        'three-quarter',
        'aaは4つの組合せのうち1つなので、劣性形質はおよそ4分の1です。',
      ),
    ],
  },
  evolution: {
    tasks: [
      arrange(
        'evolution', 'sequence', '自然選択の段階を並べる',
        '暗い樹皮の森で蛾の色の割合が変わった記録を、自然選択の順に並べ替える。',
        'ばらつき→環境に合う個体が残る→割合の変化→進化、の順です。',
        [
          ['variation', '集団に色のばらつきがある'],
          ['selection', '暗色の蛾が見つかりにくく多く残る'],
          ['ratio-shift', '世代を経て暗色の割合が増える'],
          ['evolved', '集団の姿が変わる'],
        ],
        'ばらつきから選択を経て集団の姿が変わる順です。',
      ),
      choice(
        'evolution', 'tableRead', '地層と化石の表を読む',
        '地層の深さごとの化石の記録から、生物の変遷を正しく読み取る。',
        ['地層 | 時代 | 見つかる化石', '深い層 | 古い | 三葉虫・アンモナイト', '浅い層 | 新しい | 現在に近い姿の生物'],
        '深い層ほど古く、層の順に生物の姿が変わっている。',
        [
          ['same-species', 'どの層にも同じ生物の化石しかない'],
          ['chronological-change', '古い層から新しい層へ順に生物の姿が変わっている'],
          ['random-order', '化石の種類と層の深さに対応はない'],
        ],
        'chronological-change',
        '地層は下ほど古いので、化石の姿の違いは生物の変遷の記録です。',
      ),
      choice(
        'evolution', 'symbolMatch', '進化の説明を表す式を選ぶ',
        '自然選択による進化を正しく表した式を選ぶ。',
        ['要因 | 結果', 'ばらつきの中の選択 | 集団の形質の割合の変化'],
        '個体の変化ではなく、集団の中で残される形質の割合が変わる。',
        [
          ['selection-equation', '形質のばらつき ＋ 環境による選択 → 集団の姿の変化'],
          ['effort-equation', '個体が獲得した形質 → そのまま子に伝わる'],
          ['mutation-equation', '突然変異 → 一気に別の種が現れる'],
        ],
        'selection-equation',
        '進化はばらつきから環境に合った形質が残されることで起きます。',
      ),
    ],
  },
}

