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

/** Stage 2「化学変化と原子・分子」3概念の固有事件・会話正本。 */
export const STAGE2_STORY_SOURCES: Readonly<Record<string, StorySource>> = {
  combinationDecomposition: story(
    'combinationDecomposition.mixed-powder',
    '混ぜただけ粉チームの冤罪事件',
    '家庭科室の資料棚。鉄粉と硫黄を混ぜた粉末と、加熱後の黒いかたまりの観察記録が並ぶ。',
    [
      line('combinationDecomposition.open.1', 'mio', '加熱前の粉末、磁石に近づけると黒っぽい粒だけがくっついてる。'),
      line('combinationDecomposition.open.2', 'ren', '鉄の粒が残ってるってことだね。加熱後のかたまりは磁石にも引かれない。'),
      line('combinationDecomposition.open.3', 'dekisugi', 'ぼくは知ってる！混ぜればもう化合！名づけて「瞬間化合説」！'),
    ],
    [
      response('combinationDecomposition', 'mixture-not-compound', 'ren', '混ぜただけなら鉄の粒は鉄のまま。磁石に引かれる記録がその証拠だね。'),
      response('combinationDecomposition', 'mixed-means-combined', 'mio', '粒が触れ合っていても性質が残っていれば、まだ混合物だよ。'),
      response('combinationDecomposition', 'heating-restores', 'dekisugi', '加熱で色が変わったなら、冷めれば元に戻る……はずがなかった！'),
    ],
    [
      line('combinationDecomposition.resolve.1', 'ren', '加熱で化学変化が起きて、性質の違う硫化鉄ができた。それが化合だね。'),
      line('combinationDecomposition.resolve.2', 'mio', '1種類が分かれるのが分解、結びつくのが化合。混ぜるだけはどちらでもないね。'),
    ],
    line('combinationDecomposition.punchline', 'dekisugi', '瞬間化合説、磁石の前で見事に散りました。'),
  ),
  oxidationReduction: story(
    'oxidationReduction.rust-detective',
    '赤い汚れの正体を追え',
    '昇降口のフェンスの写真と、学校で保存されたさびの観察記録が開かれている。',
    [
      line('oxidationReduction.open.1', 'mio', 'さびた部分、削るとぼろぼろ崩れて、中の鉄とは全然違う質感だよ。'),
      line('oxidationReduction.open.2', 'ren', 'さびた鉄はもとより重くなっているという測定記録もあるね。'),
      line('oxidationReduction.open.3', 'dekisugi', 'つまり外から何かが降ってきた！犯人は……空です！'),
    ],
    [
      response('oxidationReduction', 'surface-dirt', 'mio', '汚れなら削れば元通りになるはず。さびは崩れて、鉄自身が減ってるよ。'),
      response('oxidationReduction', 'rust-is-oxide', 'ren', 'さびは鉄が酸素と結びついた酸化物。鉄とは別の物質ってことだね。'),
      response('oxidationReduction', 'rust-is-reduction', 'dekisugi', '酸素が抜けてできるのがさび……あれ、それだと重くならない！'),
    ],
    [
      line('oxidationReduction.resolve.1', 'ren', '酸素と結びつくのが酸化、酸化物から酸素を取るのが還元。さびはゆっくりした酸化だ。'),
      line('oxidationReduction.resolve.2', 'mio', '燃えるのもさびるのも、酸素との結びつき。速さが違うだけなんだね。'),
    ],
    line('oxidationReduction.punchline', 'dekisugi', '犯人は空で合ってた！でも手口は「酸素と結びつく」でした。'),
  ),
  massConservation: story(
    'massConservation.vanished-gram',
    '消えた1.1グラムの密室',
    '理科室の測定記録。開いた容器と密閉袋で同じ反応をさせた二つの表が残る。',
    [
      line('massConservation.open.1', 'mio', '開いた容器だと反応後に1.1グラム減ってる。でも密閉袋だとピッタリ同じ。'),
      line('massConservation.open.2', 'ren', '同じ量の塩酸と炭酸水素ナトリウムだよ。違いは気体が逃げられるかどうかだね。'),
      line('massConservation.open.3', 'dekisugi', '密室トリックは見抜いた！質量が自ら蒸発したんだ！'),
    ],
    [
      response('massConservation', 'gas-no-mass', 'ren', '気体にも質量があるよ。発生した二酸化炭素も数えれば帳尻が合う。'),
      response('massConservation', 'conservation-fails', 'mio', '測る範囲の外へ出ただけで、消えたわけじゃないと思うよ。'),
      response('massConservation', 'count-escaped-gas', 'ren', '逃げた気体の分まで合わせれば、前後の総和は等しいはずだね。'),
    ],
    [
      line('massConservation.resolve.1', 'mio', '開いた容器で減った分は、外へ出た気体の質量と一致するね。'),
      line('massConservation.resolve.2', 'ren', '原子は消えず組合せが変わるだけ。測る全体に含めれば質量は保存される。'),
    ],
    line('massConservation.punchline', 'dekisugi', '消えた質量、実は窓から出ていった二酸化炭素でした。密室でも何でもない！'),
  ),
  electrolyte: story(
    'electrolyte.silent-bulb',
    '消えた豆電球の容疑者たち',
    '理科室の資料机。食塩水では光り、砂糖水では消えた豆電球の実験記録と写真が並ぶ。',
    [
      line('electrolyte.open.1', 'mio', '食塩水だと豆電球がついて、砂糖水だと消えたまま。どっちも透明なのにね。'),
      line('electrolyte.open.2', 'ren', '塩化銅水溶液だと電極に赤いものができた記録もあるよ。液によって結果が違うね。'),
      line('electrolyte.open.3', 'dekisugi', '分かった！砂糖の甘さが電気を甘くして、流れを止めるんだ！'),
    ],
    [
      response('electrolyte', 'conduct-any-solution', 'ren', '溶けただけじゃ駄目なんだ。砂糖水は記録でも電気を通してないよ。'),
      response('electrolyte', 'solid-conducts', 'mio', '固い食塩には電気が流れない記録もあるよ。溶けて動けるかどうかが大事だね。'),
      response('electrolyte', 'ions-carry', 'ren', '溶けてイオンに分かれた液だけが電気を通す。砂糖は溶けてもイオンにならないんだ。'),
    ],
    [
      line('electrolyte.resolve.1', 'ren', '電解質は溶けるとイオンに分かれて、そのイオンが動いて電流を運ぶんだ。'),
      line('electrolyte.resolve.2', 'mio', '電極に物質ができるのは、液の中のイオンが集まった証拠なんだね。'),
    ],
    line('electrolyte.punchline', 'dekisugi', '甘さ仮説は溶解！真犯人は「イオンがいるかどうか」でした。'),
  ),
  acidAlkali: story(
    'acidAlkali.three-cups',
    '三色に分かれた液の身元',
    '放送室の資料画面。3つの液にBTB溶液を加えた記録で、黄・緑・青に分かれている。',
    [
      line('acidAlkali.open.1', 'mio', 'うすい塩酸は黄色、食塩水は緑のまま、うすい水酸化ナトリウム水溶液は青色になってる。'),
      line('acidAlkali.open.2', 'ren', '同じ指示薬で色が違うってことは、液の中の粒が違うってことだね。'),
      line('acidAlkali.open.3', 'dekisugi', '黄色い液はレモン味に決まってる！酸っぱいはずだから飲もう！'),
    ],
    [
      response('acidAlkali', 'acid-everywhere', 'mio', '食酢やレモン汁も酸だよ。酸の強さには幅があって、危険かは種類と強さで決まるんだ。'),
      response('acidAlkali', 'all-acid-danger', 'ren', '家にあるものにも酸はあるよ。酸＝全部危険、は違うね。'),
      response('acidAlkali', 'alkali-safe', 'mio', 'アルカリだって強いと危ないよ。石けん液を目に入れたらだめだよ。'),
    ],
    [
      line('acidAlkali.resolve.1', 'ren', '黄色にするのは水素イオン、青にするのは水酸化物イオン。色は液の中の粒の証言だね。'),
      line('acidAlkali.resolve.2', 'mio', 'pH7が中性で、離れるほど強い酸・強いアルカリ。数字が強さを教えてくれるね。'),
    ],
    line('acidAlkali.punchline', 'dekisugi', '黄色はレモン味のサインじゃなくて、水素イオンのサインでした。飲まなくてよかった！'),
  ),
  neutralizationBattery: story(
    'neutralizationBattery.lemon-cell',
    '果物電池に宿った電気の行方',
    '図書室の資料端末。レモンに亜鉛板と銅板を差して電流が流れた記録と、乾電池の写真がある。',
    [
      line('neutralizationBattery.open.1', 'mio', 'レモン汁に亜鉛板と銅板を差すと、ほんとに電流が流れた記録だよ。'),
      line('neutralizationBattery.open.2', 'ren', '亜鉛は銅よりイオンになりやすいんだって。差があると電子が一方へ流れるね。'),
      line('neutralizationBattery.open.3', 'dekisugi', 'レモンは電気の実！果汁に電気が宿ってるんだ！'),
    ],
    [
      response('neutralizationBattery', 'neutral-guaranteed', 'ren', '混ぜれば必ず中性、じゃないよ。量が合わなければ余った側の性質が残るんだ。'),
      response('neutralizationBattery', 'partial-neutralization', 'mio', '中性にならなくても混ざった分は中和してるよ。水と塩はできてるね。'),
      response('neutralizationBattery', 'no-reaction-unless-neutral', 'dekisugi', '中性じゃないなら反応ゼロ……あれ、じゃあ結晶はどこから来たの！'),
    ],
    [
      line('neutralizationBattery.resolve.1', 'ren', '中和は水素イオンと水酸化物イオンが結びついて水になる反応。残ったイオンから塩ができるんだ。'),
      line('neutralizationBattery.resolve.2', 'mio', '電池はイオンへのなりやすさの差で電子が流れる仕組み。化学変化の力を電気に変えてるんだね。'),
    ],
    line('neutralizationBattery.punchline', 'dekisugi', '電気は果汁に宿ってたんじゃなくて、金属たちの「なりたさ」の差で流れてました。レモンさん、疑ってごめん！'),
  ),
}
