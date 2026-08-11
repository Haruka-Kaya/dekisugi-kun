import type {
  ScienceStoryCharacter,
  ScienceStoryChoiceResponse,
  ScienceStoryLine,
  StorySource,
} from './science-stories.js'

const CAST: readonly ScienceStoryCharacter[] = [
  { id: 'mio', name: 'ミオ', role: '観察と安全確認' },
  { id: 'dekisugi', name: 'デキすぎ君', role: '自信満々の仮説' },
  { id: 'ren', name: 'レン', role: '条件と記録の確認' },
]

const line = (
  id: string,
  speakerId: 'mio' | 'dekisugi' | 'ren',
  text: string,
): ScienceStoryLine => ({ id, speakerId, text })

const response = (
  storyId: string,
  optionId: string,
  speakerId: 'mio' | 'dekisugi' | 'ren',
  text: string,
): ScienceStoryChoiceResponse => ({
  optionId,
  line: line(`${storyId}.response.${optionId}`, speakerId, text),
})

function story(
  id: string,
  title: string,
  setting: string,
  openingLines: ScienceStoryLine[],
  choiceResponses: ScienceStoryChoiceResponse[],
  resolutionLines: ScienceStoryLine[],
  punchline: ScienceStoryLine,
): StorySource {
  return {
    id,
    title,
    setting,
    characters: CAST.map((character) => ({ ...character })),
    openingLines,
    choiceSpeakerId: 'dekisugi',
    choiceResponses,
    resolutionLines,
    punchline,
  }
}

/** Stage 1 expansion 8概念の固有事件・会話正本。 */
export const STAGE1_EXPANSION_STORY_SOURCES: Readonly<
  Record<string, StorySource>
> = {
  gasProperties: story(
    'gasProperties.collection-card',
    '透明気体の捕集法取り違え事件',
    '理科室の資料机。酸素・二酸化炭素・水素・アンモニアの固定性質表と捕集法カードが並ぶ。',
    [
      line('gasProperties.open.1', 'mio', 'アンモニアは水に非常に溶けやすく、空気より軽いと書いてある。'),
      line('gasProperties.open.2', 'ren', 'まず水上置換が使えるか、その次に空気との密度差を読むんだ。'),
      line('gasProperties.open.3', 'dekisugi', '透明なら全員同じチーム！　全部、水の中へ集合です！'),
    ],
    [
      response('gasProperties', 'property-based-method', 'ren', '水溶性を先に見る手順なら、気体を水へ逃がさずに済むね。'),
      response('gasProperties', 'all-water-collection', 'mio', 'アンモニアは水に溶けてしまうから、水上置換には向かないよ。'),
      response('gasProperties', 'appearance-identifies', 'dekisugi', '無色の名札だけでは、酸素と二酸化炭素も区別できなかった！'),
    ],
    [
      line('gasProperties.resolve.1', 'ren', '水に溶けにくい気体は水上置換、溶けやすければ密度差で置換法を選ぶ。'),
      line('gasProperties.resolve.2', 'mio', '識別も見た目ではなく、安全に記録済みの反応を組み合わせよう。'),
    ],
    line('gasProperties.punchline', 'dekisugi', '透明気体チーム、性質表を読んだら全員別ポジションでした。'),
  ),
  stateChangeMass: story(
    'stateChangeMass.missing-mass',
    '消えた液体1.5グラムの行方',
    '教室の測定資料コーナー。開いた皿と密閉袋の蒸発前後データを画面で比較している。',
    [
      line('stateChangeMass.open.1', 'ren', '開いた皿は減ったけれど、密閉袋の全質量は同じだ。'),
      line('stateChangeMass.open.2', 'mio', '加熱実験はせず、この固定記録で測定範囲を確認しよう。'),
      line('stateChangeMass.open.3', 'dekisugi', '見えないなら無くなった判定！　質量は透明化するとゼロです。'),
    ],
    [
      response('stateChangeMass', 'closed-same-mass', 'ren', '気体も袋内に含めた全体を測れているね。'),
      response('stateChangeMass', 'gas-lost', 'mio', '気体にも質量があるよ。外へ出たかを分けよう。'),
      response('stateChangeMass', 'phase-changes-mass', 'dekisugi', '姿替えを別人扱いしていた！　粒子の種類は同じだった。'),
    ],
    [
      line('stateChangeMass.resolve.1', 'mio', '状態変化では、同じ物質の粒子の配置や運動が変わる。'),
      line('stateChangeMass.resolve.2', 'ren', '閉じた系なら粒子が外へ出ず、容器を含む全質量は変わらない。'),
    ],
    line('stateChangeMass.punchline', 'dekisugi', '1.5グラムは消失せず、測定範囲の外へお引っ越しでした。'),
  ),
  photosynthesisRespiration: story(
    'photosynthesisRespiration.night-shift',
    '植物工場の夜勤呼吸員',
    '図書室のデータ端末。水草の明所・暗所における酸素変化の固定グラフを開いている。',
    [
      line('photosynthesisRespiration.open.1', 'mio', '明所では酸素が増え、暗所では減っているね。'),
      line('photosynthesisRespiration.open.2', 'ren', '正味の変化だから、光合成と呼吸を別々に考えよう。'),
      line('photosynthesisRespiration.open.3', 'dekisugi', '植物の呼吸係は完全夜勤。昼は全員お休みです！'),
    ],
    [
      response('photosynthesisRespiration', 'both-processes', 'ren', '明所でも二つの過程を差し引いて読めている。'),
      response('photosynthesisRespiration', 'only-photosynthesis', 'mio', '昼の細胞も生命活動へエネルギーが必要だよ。'),
      response('photosynthesisRespiration', 'respiration-night-only', 'dekisugi', '呼吸係に昼夜交代制はなかった！'),
    ],
    [
      line('photosynthesisRespiration.resolve.1', 'ren', '光があると光合成が進むが、呼吸も昼夜を通して続く。'),
      line('photosynthesisRespiration.resolve.2', 'mio', '明所の酸素増加は、生成が消費を上回った正味の結果だ。'),
    ],
    line('photosynthesisRespiration.punchline', 'dekisugi', '呼吸員は夜勤専属ではなく、まさかの24時間シフトでした。'),
  ),
  digestionAbsorption: story(
    'digestionAbsorption.villus-gate',
    '栄養分の小腸入国審査',
    '保健室前の教材机。消化管図と栄養分カードを使い、食べ物や人体試料には触れず考える。',
    [
      line('digestionAbsorption.open.1', 'ren', '大きなデンプンカードは、そのまま柔毛の先へ通せない。'),
      line('digestionAbsorption.open.2', 'mio', '消化で小さくする段階と、壁を越えて吸収する段階を分けよう。'),
      line('digestionAbsorption.open.3', 'dekisugi', '胃が入国審査も輸送も全部担当。小腸は見学席です！'),
    ],
    [
      response('digestionAbsorption', 'digest-then-absorb', 'ren', '分解してから主に小腸で吸収する順序が合っている。'),
      response('digestionAbsorption', 'stomach-absorbs-all', 'mio', '胃だけで全栄養分の吸収が終わるわけではないよ。'),
      response('digestionAbsorption', 'intestine-only-digests', 'dekisugi', '柔毛の毛細血管を見学設備だと思っていた！'),
    ],
    [
      line('digestionAbsorption.resolve.1', 'mio', '消化酵素が大きな栄養分を吸収可能な物質へ分解する。'),
      line('digestionAbsorption.resolve.2', 'ren', 'その多くが小腸の柔毛から血液やリンパへ入る。'),
    ],
    line('digestionAbsorption.punchline', 'dekisugi', '栄養分の通行証は「消化ずみ」、入国ゲートは小腸でした。'),
  ),
  fronts: story(
    'fronts.weather-timeline',
    '天気図に残った暖気の足あと',
    '放送室の資料画面。過去の温暖前線と気温・雲・降水の時系列を室内で確認する。',
    [
      line('fronts.open.1', 'mio', '前線の前から層状の雲が広がり、通過後に気温が上がっている。'),
      line('fronts.open.2', 'ren', '断面では暖気が寒気の上を緩やかに進んでいるね。'),
      line('fronts.open.3', 'dekisugi', '暖かい空気のほうが重いから、寒気の地下へ潜るはず！'),
    ],
    [
      response('fronts', 'warm-over-cold', 'ren', '密度差と進む気団を断面へ対応できている。'),
      response('fronts', 'cold-over-warm', 'mio', '暖気は寒気より密度が小さく、上へ持ち上げられるよ。'),
      response('fronts', 'no-boundary', 'dekisugi', '前線記号から気団の境界を消してしまっていた！'),
    ],
    [
      line('fronts.resolve.1', 'mio', '温暖前線では暖気が寒気の上を緩やかに上昇する。'),
      line('fronts.resolve.2', 'ren', '広い雲や降水は代表的傾向で、強さは水蒸気量などでも変わる。'),
    ],
    line('fronts.punchline', 'dekisugi', '暖気の足あとは地下ではなく、雲の階段に残っていました。'),
  ),
  pressurePatternsWind: story(
    'pressurePatternsWind.isobar-maze',
    '等圧線ぎゅうぎゅう区画の強風予告',
    '気象資料室。過去の天気図で等圧線間隔と同時刻の観測風速を照合している。',
    [
      line('pressurePatternsWind.open.1', 'ren', '区域Aは同じ距離に等圧線が何本もあり、風速も大きい。'),
      line('pressurePatternsWind.open.2', 'mio', '線は壁ではなく、同じ気圧を結んだ地図上の印だよ。'),
      line('pressurePatternsWind.open.3', 'dekisugi', '低気圧が風を高気圧へ吸い上げる、逆流ポンプ説です！'),
    ],
    [
      response('pressurePatternsWind', 'high-to-low', 'ren', '気圧差の力と、自転・摩擦の影響を分けられている。'),
      response('pressurePatternsWind', 'coriolis-alone', 'mio', '自転の効果は動く空気を曲げるけれど、気圧差の代わりではないよ。'),
      response('pressurePatternsWind', 'low-to-high', 'dekisugi', '気圧の坂道を上る向きにしていた！'),
    ],
    [
      line('pressurePatternsWind.resolve.1', 'ren', '気圧差による力は高圧側から低圧側へ向く。'),
      line('pressurePatternsWind.resolve.2', 'mio', '実際の風向は地球の自転と地表摩擦でも変わる。'),
    ],
    line('pressurePatternsWind.punchline', 'dekisugi', '等圧線は通行止めロープではなく、風の坂道の等高線でした。'),
  ),
  volcanoEarthquakes: story(
    'volcanoEarthquakes.double-map',
    '火山マークと震央マークの別行動',
    '防災学習室。公的な火山・震央・プレート境界の過去分布図を重ねている。',
    [
      line('volcanoEarthquakes.open.1', 'mio', '境界付近に両方多いけれど、印が重ならない場所もある。'),
      line('volcanoEarthquakes.open.2', 'ren', '共通傾向と、それぞれ固有の証拠を分けて記録しよう。'),
      line('volcanoEarthquakes.open.3', 'dekisugi', '同じ地図にいるなら、火山と地震は毎回セット出演です！'),
    ],
    [
      response('volcanoEarthquakes', 'evidence-specific', 'ren', 'プレートとの関係と別現象である点を両方押さえている。'),
      response('volcanoEarthquakes', 'same-everywhere', 'mio', '分布の傾向は、全地点・全時刻での同時発生を意味しないよ。'),
      response('volcanoEarthquakes', 'one-event', 'dekisugi', '地震波と火山灰を同じ出演者にしてしまった！'),
    ],
    [
      line('volcanoEarthquakes.resolve.1', 'mio', '地震は岩盤の急なずれ、噴火はマグマの上昇に関わる別の現象だ。'),
      line('volcanoEarthquakes.resolve.2', 'ren', 'プレート境界に多い共通傾向があっても、固有の証拠が必要になる。'),
    ],
    line('volcanoEarthquakes.punchline', 'dekisugi', '地図ではご近所、事件簿では別々の担当でした。'),
  ),
  dailyMotionSeasons: story(
    'dailyMotionSeasons.sky-calendar',
    '星空カレンダー一日と一年の混線',
    'プラネタリウム教室。同じ場所の一晩と、同時刻で月を変えた星空シミュレーションを比べる。',
    [
      line('dailyMotionSeasons.open.1', 'ren', '一晩では星が東から西へ、月を進めると同時刻の星座も変わる。'),
      line('dailyMotionSeasons.open.2', 'mio', '自転による一日の変化と、公転による一年の変化を分けよう。'),
      line('dailyMotionSeasons.open.3', 'dekisugi', '季節は太陽に近づくほど夏。南半球だけ遠回りです！'),
    ],
    [
      response('dailyMotionSeasons', 'rotation-revolution', 'ren', '時間尺度と地球の二つの運動を対応できている。'),
      response('dailyMotionSeasons', 'earth-still', 'mio', '地球が西から東へ自転すると、空は反対向きに動いて見えるよ。'),
      response('dailyMotionSeasons', 'sun-distance-only', 'dekisugi', '同じ地球の南北で季節が反対な理由を説明できなかった！'),
    ],
    [
      line('dailyMotionSeasons.resolve.1', 'mio', '日周運動は自転、同時刻の星座の年周変化は公転で説明する。'),
      line('dailyMotionSeasons.resolve.2', 'ren', '季節は地軸の傾きにより太陽高度と昼の長さが変わって生じる。'),
    ],
    line('dailyMotionSeasons.punchline', 'dekisugi', '星空カレンダー、24時間欄と12か月欄を同じマスに書いていました。'),
  ),
}
