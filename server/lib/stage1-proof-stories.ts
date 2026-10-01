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
export const STAGE1_PROOF_STORY_SOURCES: Readonly<
  Record<string, StorySource>
> = {
  density: story(
    'density.twin-bottles',
    'そっくりボトルの重さ交換事件',
    '家庭科室の安定した机。同じ容器に同じ体積の水と食用油を入れ、ふたを閉めてある。',
    [
      line('density.open.1', 'mio', '見た目も体積も同じなのに、水の容器のほうが重いね。'),
      line('density.open.2', 'ren', '容器の種類と中身の体積をそろえたから、単位体積当たりを比べられる。'),
      line('density.open.3', 'dekisugi', '大きい容器へ移したら、油の密度もぐんぐん育つはず！'),
    ],
    [
      response('density', 'ratio-stays', 'ren', '質量と体積が同じ割合で変わる点まで説明できているね。'),
      response('density', 'mass-only-halves', 'mio', '切ると体積も半分になるよ。質量だけの変化ではないね。'),
      response('density', 'surface-doubles', 'dekisugi', '切り口の数を密度の式へ勝手に追加していた！'),
    ],
    [
      line('density.resolve.1', 'ren', '密度は質量を体積で割り、単位体積当たりへそろえた値だ。'),
      line('density.resolve.2', 'mio', '同じ物質の量だけを変えても、質量と体積の比は変わらない。'),
    ],
    line('density.punchline', 'dekisugi', '密度は育たず、育ったのは容器を洗う仕事だけでした。'),
  ),
  cells: story(
    'cells.missing-chloroplast',
    '消えた葉緑体と根っこの証言',
    '理科室の画像資料コーナー。葉の細胞、根の細胞、動物組織の顕微鏡画像を並べている。',
    [
      line('cells.open.1', 'mio', '根の細胞画像には細胞壁が見えるけれど、葉緑体は見当たらないね。'),
      line('cells.open.2', 'ren', '採取部位、倍率、染色条件も画像の記録から確認しよう。'),
      line('cells.open.3', 'dekisugi', '葉緑体が欠席なら、この根は動物に転校したんだ！'),
    ],
    [
      response('cells', 'shape-alone', 'ren', '植物の根の細胞まで葉緑体を必須にすると観察と合わないよ。'),
      response('cells', 'multiple-features', 'mio', '一つの特徴ではなく、細胞壁と採取部位まで使えているね。'),
      response('cells', 'all-animal', 'dekisugi', '根が動物なら、鉢から逃げ出しているはずだった！'),
    ],
    [
      line('cells.resolve.1', 'mio', '植物細胞でも、根など葉緑体をもたない細胞がある。'),
      line('cells.resolve.2', 'ren', '共通点と相違点を複数確認し、観察条件も合わせて判断する。'),
    ],
    line('cells.punchline', 'dekisugi', '葉緑体は欠席、でも根っこの植物籍はそのままでした。'),
  ),
  humidityClouds: story(
    'humidityClouds.cup-rain',
    'コップの外だけ局地雨',
    '教室の机。乾いた同じコップを並べ、片方だけに冷水を入れて外側を観察する。',
    [
      line('humidityClouds.open.1', 'mio', '冷たいコップの外側だけに、小さな水滴が増えてきた。'),
      line('humidityClouds.open.2', 'ren', 'ふたのない上面からこぼれていないし、室温のコップには付いていない。'),
      line('humidityClouds.open.3', 'dekisugi', '透明な水蒸気が白い制服へ着替えて、外へ集合したんだね。'),
    ],
    [
      response('humidityClouds', 'white-gas', 'ren', '水蒸気は気体で見えない。見えている粒の状態を区別しよう。'),
      response('humidityClouds', 'dust-only', 'mio', '水滴が成長する観察と、雨や雪につながることを説明できないね。'),
      response('humidityClouds', 'droplets-or-ice', 'dekisugi', '白い制服ではなく、水滴の光の散乱だった！'),
    ],
    [
      line('humidityClouds.resolve.1', 'ren', '空気が露点まで冷えると、見えない水蒸気の一部が凝結する。'),
      line('humidityClouds.resolve.2', 'mio', '小さな水滴や氷の粒が光を散乱するから、雲として見える。'),
    ],
    line('humidityClouds.punchline', 'dekisugi', 'コップの局地雨、予報範囲は半径5センチでした。'),
  ),
  strataRelativeAge: story(
    'strataRelativeAge.paper-cliff',
    '紙の崖に残った斜め線のアリバイ',
    '図書室の大机。色紙の地層模型に、下の3層を切る斜め線と、それを覆う上層がある。',
    [
      line('strataRelativeAge.open.1', 'ren', '斜め線は青・黄・白を切るけれど、一番上の緑は切っていない。'),
      line('strataRelativeAge.open.2', 'mio', '模型なら崖へ行かず、安全に出来事の順を確かめられるね。'),
      line('strataRelativeAge.open.3', 'dekisugi', '上の緑が一番目立つから、緑が最古の長老です！'),
    ],
    [
      response('strataRelativeAge', 'lower-first', 'ren', '逆転していない条件と堆積順を正しく使えている。'),
      response('strataRelativeAge', 'upper-older', 'mio', '見つける順と、積もった順を入れ替えているよ。'),
      response('strataRelativeAge', 'same-age', 'dekisugi', '全部同時なら、下の紙を後から差し込む大工事が必要だ！'),
    ],
    [
      line('strataRelativeAge.resolve.1', 'mio', '逆転していなければ、下の層ほど先に積もって古い。'),
      line('strataRelativeAge.resolve.2', 'ren', '切る線は切られた層より後、線を覆う緑の層はさらに後だ。'),
    ],
    line('strataRelativeAge.punchline', 'dekisugi', '紙の崖は動かず、ぼくの年代順だけが大逆転していました。'),
  ),
}
