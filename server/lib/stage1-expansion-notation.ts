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

/** 8概念固有の表・断面・因果を操作するv10 Notation正本。 */
export const STAGE1_EXPANSION_NOTATION_LABS: Readonly<
  Record<string, TaggedNotationLab>
> = {
  gasProperties: {
    tasks: [
      choice(
        'gasProperties', 'tableRead', '気体の性質表を読む',
        '水溶性と空気との密度差から、アンモニアの捕集法を選ぶ。',
        ['気体 | 水への溶けやすさ | 空気との密度', 'NH₃ | 非常に溶けやすい | 小さい', 'CO₂ | 溶ける | 大きい'],
        'アンモニアは水に非常に溶けやすく空気より軽い。二酸化炭素は水に溶け、空気より重い。',
        [['water', '水上置換'], ['upward', '上方置換'], ['downward', '下方置換']],
        'upward',
        'アンモニアは水上置換を避け、空気より軽い性質を使う上方置換で集めます。',
      ),
      arrange(
        'gasProperties', 'sequence', '捕集法の決定手順を並べる',
        '未知気体の捕集法を性質表から選ぶ順序を並べる。',
        'まず水への溶けやすさを見て、水上置換に向かなければ空気との密度差を見ます。',
        [['solubility', '水溶性を確認'], ['water-check', '水上置換の可否を判断'], ['density', '空気との密度差を確認'], ['displacement', '上方・下方置換を選択']],
        '水溶性を先に確認し、水に溶けやすい場合は密度差から置換法を選びます。',
      ),
      choice(
        'gasProperties', 'symbolMatch', '反応記録を気体名へ結ぶ',
        '石灰水を白く濁らせる固定反応記録に対応する気体を選ぶ。',
        [], '気体名と安全に記録済みの識別反応を対応させます。',
        [['oxygen', '酸素 O₂'], ['carbon-dioxide', '二酸化炭素 CO₂'], ['hydrogen', '水素 H₂']],
        'carbon-dioxide',
        '石灰水を白く濁らせる反応は二酸化炭素の識別根拠です。',
      ),
    ],
  },
  stateChangeMass: {
    tasks: [
      arrange(
        'stateChangeMass', 'sequence', '閉じた系の状態変化を追う',
        '液体が気体へ変わる閉じた系を、観察と結論の順に並べる。',
        '状態変化、粒子が系内に残ること、全質量の比較をつなぎます。',
        [['phase', '液体が気体へ状態変化'], ['retained', '粒子は密閉容器内に残る'], ['weigh', '容器全体を再び測る'], ['same-mass', '前後の全質量は同じ']],
        '閉じた系では気体となった粒子も残るので、容器を含む全質量は保たれます。',
      ),
      choice(
        'stateChangeMass', 'tableRead', '開閉条件と質量表を読む',
        '蒸発前後の質量変化を、系の境界から正しく説明した行を選ぶ。',
        ['条件 | 前 | 後', '開いた皿 | 128.0 g | 126.5 g', '密閉袋 | 128.0 g | 128.0 g'],
        '開いた皿は1.5グラム減り、密閉袋は前後とも128.0グラム。',
        [['phase-destroys', '開いた系だけ物質が消えた'], ['boundary', '皿では気体が測定範囲外へ移った'], ['bag-created', '袋の中で質量が新しく作られた']],
        'boundary',
        '開いた皿の減少は、気体となった物質が測定範囲外へ移ったためです。',
      ),
      arrange(
        'stateChangeMass', 'modelBuild', '状態変化の粒子モデルを組む',
        '固体から液体への変化で、変わらないものと変わるものを組み立てる。',
        '粒子の種類と総数を保ち、並び方と間隔の変化を続けます。',
        [['same-particles', '同じ種類・総数の粒子'], ['arrangement', '規則的な並びが崩れる'], ['motion', '粒子が位置を変えやすくなる'], ['volume-limit', '体積は変わる場合がある']],
        '状態変化では粒子の種類と総数を保ち、配置や運動が変わります。',
      ),
    ],
  },
  photosynthesisRespiration: {
    tasks: [
      arrange(
        'photosynthesisRespiration', 'modelBuild', '光合成の物質関係を組む',
        '光合成で使う物質とできる物質を、光の条件を含めて並べる。',
        '二酸化炭素と水、光エネルギー、有機物と酸素の順に置きます。',
        [['inputs', '二酸化炭素＋水'], ['light', '光エネルギーを利用'], ['organic', '有機物をつくる'], ['oxygen', '酸素を放出']],
        '光合成は光を使い、二酸化炭素と水から有機物をつくって酸素を放出します。',
      ),
      choice(
        'photosynthesisRespiration', 'tableRead', '明所・暗所の気体表を読む',
        '酸素の正味変化と二つの過程について正しい説明を選ぶ。',
        ['条件 | 酸素の正味変化', '明所 | ＋8', '暗所 | −3'],
        '明所では酸素が8増え、暗所では3減った。値は光合成と呼吸の差を表す。',
        [['light-only', '明所では呼吸が止まる'], ['both-light', '明所は両方行い、光合成が上回る'], ['dark-photosynthesis', '暗所では光合成だけを行う']],
        'both-light',
        '明所でも呼吸は続き、光合成による酸素生成が消費を上回った結果です。',
      ),
      choice(
        'photosynthesisRespiration', 'labelDiagram', '葉と根の過程を分ける',
        '明るい条件の根の細胞で続く過程を選ぶ。',
        ['葉：葉緑体が多い', '茎：生きた細胞', '根：葉緑体をもたない細胞が多い'],
        '植物の葉、茎、根の模式図。根も生きた細胞からできる。',
        [['photosynthesis-only', '光合成だけ'], ['respiration', '呼吸'], ['neither', 'どちらも行わない']],
        'respiration',
        '葉緑体をもたない根の細胞でも、生命活動のため呼吸を行います。',
      ),
    ],
  },
  digestionAbsorption: {
    tasks: [
      arrange(
        'digestionAbsorption', 'sequence', '消化から吸収までを並べる',
        '大きな栄養分が体内へ運ばれるまでを順に並べる。',
        '消化管、酵素による分解、柔毛、循環への移動をつなぎます。',
        [['large', '大きな栄養分が消化管へ'], ['digest', '酵素で小さな物質へ分解'], ['villus', '小腸の柔毛を通過'], ['circulation', '血液・リンパへ移る']],
        '栄養分は消化で小さくなった後、主に小腸の柔毛から吸収されます。',
      ),
      choice(
        'digestionAbsorption', 'labelDiagram', '柔毛の働きを図から読む',
        '小腸の内側に多数の突起がある主な利点を選ぶ。',
        ['小腸内腔 ～～～～ 多数の柔毛', '柔毛内：毛細血管・リンパ管', '消化管の壁'],
        '小腸内面の多数の柔毛と、内部の毛細血管・リンパ管を示す模式図。',
        [['smaller-area', '吸収面積を小さくする'], ['larger-area', '吸収面積を大きくする'], ['chew-food', '歯の代わりに食物をかむ']],
        'larger-area',
        '柔毛は小腸内面の表面積を増やし、栄養分を取り込みやすくします。',
      ),
      choice(
        'digestionAbsorption', 'tableRead', '酵素の特異性表を読む',
        '固定結果から酵素Xについて言えることを選ぶ。',
        ['組合せ | 分解', 'X＋デンプン | あり', 'X＋タンパク質 | なし', 'Y＋タンパク質 | あり'],
        '酵素Xはデンプンを分解したがタンパク質は分解せず、Yはタンパク質を分解した。',
        [['all-nutrients', 'Xは全栄養分を分解する'], ['starch-specific', 'Xはこの条件でデンプンに作用した'], ['temperature-certain', '全温度で同じ速さと証明された']],
        'starch-specific',
        '資料からXはこの条件でデンプンに作用したといえますが、全条件へは一般化できません。',
      ),
    ],
  },
  fronts: {
    tasks: [
      arrange(
        'fronts', 'sequence', '温暖前線の変化を並べる',
        '暖気の進入から前線通過後までを代表的な順に並べる。',
        '暖気の上昇、雲と降水、通過後の気温をつなぎます。',
        [['warm-rises', '暖気が寒気の上を緩やかに上昇'], ['layer-clouds', '広く層状の雲ができる'], ['steady-rain', '持続的な降水が起こりやすい'], ['warmer-after', '通過後に気温が上がる傾向']],
        '温暖前線では暖気が緩やかに上昇し、広い雲と降水を経て暖気側へ入ります。',
      ),
      choice(
        'fronts', 'labelDiagram', '前線断面を見分ける',
        '寒気が暖気の下へ急に入り込む断面の前線名を選ぶ。',
        ['      暖気 ↗', '寒気 ▶＿＿／', '地表 ─────────'],
        '密度の大きい寒気が暖気の下へくさび状に入り、暖気を急に持ち上げる断面。',
        [['warm-front', '温暖前線'], ['cold-front', '寒冷前線'], ['stationary-only', '停滞前線だけ']],
        'cold-front',
        '進む寒気が暖気を急に持ち上げる断面は寒冷前線です。',
      ),
      choice(
        'fronts', 'tableRead', '通過時系列を読む',
        '気温低下・風向変化・短時間の強い降水から最も整合する説明を選ぶ。',
        ['時刻 | 気温 | 降水', '12時 | 22℃ | なし', '14時 | 18℃ | 強い', '16時 | 15℃ | 弱まる'],
        '14時前後に強い降水があり、気温は22度から15度へ下がった。',
        [['cold-passage', '寒冷前線通過の傾向と整合'], ['fixed-proof', '全寒冷前線の雨量を証明'], ['no-boundary', '前線とは無関係と断定']],
        'cold-passage',
        '複数の時間変化は寒冷前線通過と整合しますが、雨量を全事例へ固定はできません。',
      ),
    ],
  },
  pressurePatternsWind: {
    tasks: [
      arrange(
        'pressurePatternsWind', 'modelBuild', '地表風の因果を組む',
        '気圧差から地表付近の風向までを因果の順に組み立てる。',
        '気圧差、空気の運動、自転の効果、摩擦を順に扱います。',
        [['gradient', '高圧側から低圧側への力'], ['air-moves', '空気が動き始める'], ['rotation', '自転で進路が曲がる'], ['friction', '地表摩擦で遅くなる'], ['cross-isobar', '低圧側へ等圧線を斜めに横切る']],
        '地表風は気圧差で生じ、自転と摩擦の影響を受けて低圧側へ斜めに向かいます。',
      ),
      choice(
        'pressurePatternsWind', 'graphRead', '等圧線間隔を読む',
        '同じ地表条件で、風が強まりやすい区域を選ぶ。',
        ['区域A：1000｜1004｜1008 hPa（線間10 km）', '区域B：1000  ｜  1004  ｜  1008 hPa（線間30 km）'],
        'Aは10キロメートルごと、Bは30キロメートルごとに4ヘクトパスカル変化する。',
        [['area-a', '区域A'], ['area-b', '区域B'], ['same', '必ず同じ']],
        'area-a',
        'Aは同じ距離での気圧差が大きく、風が強まりやすい区域です。',
      ),
      choice(
        'pressurePatternsWind', 'labelDiagram', '低気圧周辺の矢印を読む',
        '北半球の地表付近で低気圧へ向かう代表的な風を選ぶ。',
        ['       ↙', '   L  低気圧', '       ↗'],
        '中心に低気圧Lがあり、風が反時計回りに回りながら中心側へ入る模式図。',
        [['inward-counterclockwise', '反時計回りで内向き'], ['outward-clockwise', '時計回りで外向き'], ['straight-outward', '全方向へ直線的に外向き']],
        'inward-counterclockwise',
        '北半球の地表低気圧では、風は反時計回りに中心へ吹き込みます。',
      ),
    ],
  },
  volcanoEarthquakes: {
    tasks: [
      choice(
        'volcanoEarthquakes', 'tableRead', '分布の重なりと違いを読む',
        'プレート境界・震央・火山の地点表から言えることを選ぶ。',
        ['地域 | 境界 | 震央多い | 火山多い', 'A | あり | はい | はい', 'B | あり | はい | いいえ', 'C | なし | 少ない | あり'],
        '境界のあるAは両方、Bは震央だけが多く、境界のないCにも火山がある。',
        [['always-together', '境界では必ず同時発生'], ['shared-trend', '共通傾向はあるが完全一致しない'], ['unrelated', 'プレートとは全く無関係']],
        'shared-trend',
        '境界付近に多い傾向は共有しますが、分布は完全には一致しません。',
      ),
      arrange(
        'volcanoEarthquakes', 'sequence', '粘り気と噴火傾向をつなぐ',
        '粘り気の大きいマグマが爆発的になりやすい因果を並べる。',
        '粘り気、気体の抜けやすさ、圧力、噴火傾向をつなぎます。',
        [['viscous', 'マグマの粘り気が大きい'], ['gas-trapped', '気体が抜けにくい'], ['pressure-builds', '内部の圧力が高まりやすい'], ['explosive', '爆発的な噴火になりやすい']],
        '粘り気が大きいと気体が抜けにくく、圧力が高まりやすくなります。',
      ),
      choice(
        'volcanoEarthquakes', 'labelDiagram', 'P波とS波の到着差を読む',
        '同じ地震で震源から遠いと推定できる記録を選ぶ。',
        ['地点P：P到着 0秒、S到着 4秒', '地点Q：P到着 0秒、S到着 12秒'],
        'P波を基準としたS波到着までの差は、Pが4秒、Qが12秒。',
        [['point-p', '地点P'], ['point-q', '地点Q'], ['same-distance', '同じ距離']],
        'point-q',
        '同じ地震ならP波とS波の到着差が大きいQのほうが遠いと推定できます。',
      ),
    ],
  },
  dailyMotionSeasons: {
    tasks: [
      arrange(
        'dailyMotionSeasons', 'sequence', '日周運動の見え方を並べる',
        '地球の自転から星の見かけの動きまでを並べる。',
        '実際の自転方向と反対向きの見かけの運動をつなぎます。',
        [['rotate-east', '地球が西から東へ自転'], ['observer-turns', '観測者も地球とともに回る'], ['sky-west', '天体が東から西へ動くように見える']],
        '地球が西から東へ自転するため、天体は東から西へ動くように見えます。',
      ),
      choice(
        'dailyMotionSeasons', 'tableRead', '南北半球の日射表を読む',
        '北半球Nが夏のとき、南半球Sの季節を選ぶ。',
        ['地点 | 太陽高度 | 昼の長さ', 'N | 高い | 長い', 'S | 低い | 短い'],
        '同じ日に北半球Nは太陽高度が高く昼が長い。南半球Sは低く短い。',
        [['summer', '夏'], ['winter', '冬'], ['same-season', 'Nと同じ季節']],
        'winter',
        '地軸の傾きにより日射条件が反対になるため、Sは冬です。',
      ),
      arrange(
        'dailyMotionSeasons', 'modelBuild', '季節変化の因果を組む',
        '北半球の夏を、地軸の傾きと日射条件から組み立てる。',
        '公転位置、半球の傾き、太陽高度と昼の長さ、受けるエネルギーをつなぎます。',
        [['tilt-sunward', '北半球が太陽側へ傾く'], ['sun-higher', '太陽高度が高くなる'], ['day-longer', '昼が長くなる'], ['more-energy', '受ける日射エネルギーが増える'], ['summer', '北半球は夏になる']],
        '地軸の傾きにより太陽高度と昼の長さが変わり、季節が生じます。',
      ),
    ],
  },
}
