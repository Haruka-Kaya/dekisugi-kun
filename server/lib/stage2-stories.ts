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
  reproduction: story(
    'reproduction.potato-mystery',
    '親そっくり署のジャガイモ偽装事件',
    '理科準備室の棚。発芽したジャガイモと、受精して育つカエルの観察記録が並んでいる。',
    [
      line('reproduction.open.1', 'mio', 'ジャガイモの芽、親の表面から直接出てる。受粉や受精の記録はどこにもないね。'),
      line('reproduction.open.2', 'ren', 'カエルの方は確かに精子と卵の受精の記録がある。殖え方がぜんぜん違う。'),
      line('reproduction.open.3', 'dekisugi', 'すべての生物は恋をして受精するんだ！ジャガイモにも秘密のロマンスがあるはず！'),
    ],
    [
      response('reproduction', 'fertilization-always', 'dekisugi', 'ほらね！ジャガイモにも見えない愛の物語が……え、ないの！？'),
      response('reproduction', 'asexual-same-chromosomes', 'mio', '親の体の一部から親と同じ染色体の個体ができるのが無性生殖だね。ロマンス不要。'),
      response('reproduction', 'sexual-identical', 'ren', '受精する子は両親の染色体が組み合わさるから、むしろ親と違う組合せになるよ。'),
    ],
    [
      line('reproduction.resolve.1', 'mio', '細胞は分裂で増えて、体は細胞の増加と成長で大きくなるんだ。'),
      line('reproduction.resolve.2', 'ren', '有性生殖は減数分裂と受精で両親の染色体を受け継ぐ。無性生殖は親と同じ染色体の子ができる。'),
    ],
    line('reproduction.punchline', 'dekisugi', 'ジャガイモは恋しなくても増えるってことか！親そっくり署、無性生殖の線で結論です！'),
  ),
  heredity: story(
    'heredity.wrinkled-seed',
    'しわしわ種子の突然復帰事件',
    '理科準備室の実験台。エンドウの交配記録カードが広げられ、丸の親からしわの子が出た一行が強調されている。',
    [
      line('heredity.open.1', 'mio', '丸の純系としわの純系の子は全部丸。でもその子同士の孫にしわが出てるね。'),
      line('heredity.open.2', 'ren', 'しわは消えたんじゃなくて、子の中に残ってたんだ。3：1の割合できれいに出てる。'),
      line('heredity.open.3', 'dekisugi', '丸い親からしわの子は絶対出ない！記録係さん、書き間違いだよ！'),
    ],
    [
      response('heredity', 'dominant-only', 'dekisugi', 'やっぱり書き間違い！優性の親から劣性の子は出ないんだよ！'),
      response('heredity', 'recessive-reappears', 'mio', '丸い親がAa同士なら、aaの子ができてしわが現れるよ。書き間違いじゃないね。'),
      response('heredity', 'half-blend', 'ren', '形質は半分ずつ混ざるんじゃなくて、組合せでどちらかが現れるんだ。'),
    ],
    [
      line('heredity.resolve.1', 'ren', '丸を決める遺伝子Aと、しわのa。優性形質の親がAaを持てば、aaの子が出るんだ。'),
      line('heredity.resolve.2', 'mio', '遺伝子は染色体にのって、減数分裂と受精で伝わる。DNAがその本体だね。'),
    ],
    line('heredity.punchline', 'dekisugi', 'しわは消えてなかった！親の中にかくれて、孫でカムバック。記録係さんごめん、君は正しかった！'),
  ),
  evolution: story(
    'evolution.fossil-lineup',
    '化石ラインナップの順番入れ替え事件',
    '放課後の理科室。地層ごとの化石写真が時代順に並べられ、古い層と新しい層で姿が違うことが確認されている。',
    [
      line('evolution.open.1', 'mio', '古い層から新しい層へ順に見ると、生物の姿が少しずつ変わってるね。'),
      line('evolution.open.2', 'ren', '地層は下ほど古いから、化石はその時代の姿の記録だね。'),
      line('evolution.open.3', 'dekisugi', 'キリンの首は、高い葉を食べたくて毎日頑張って伸ばしたんだ！努力は実るよ！'),
    ],
    [
      response('evolution', 'effort-inherited', 'dekisugi', '頑張って伸ばした首が子に伝わる！努力の結晶だよ！'),
      response('evolution', 'selection-variation', 'ren', '個体が伸ばしたんじゃなくて、もともとのばらつきの中で長い個体が多く残ったんだ。'),
      response('evolution', 'species-fixed', 'mio', '種がずっと同じなら、層ごとに姿が変わる記録は説明できないね。'),
    ],
    [
      line('evolution.resolve.1', 'mio', 'ばらつきの中で環境に合った形質が残される自然選択。それが積み重なって進化になるんだ。'),
      line('evolution.resolve.2', 'ren', '化石が層の順に姿を変えてる記録が、生物が変わってきた証拠だね。'),
    ],
    line('evolution.punchline', 'dekisugi', '努力で首が伸びたんじゃなくて、長い首の仲間が多く残ったのか！キリンさん、頑張り屋さんでごめん！'),
  ),
  energyResources: story(
    'energyResources.meter-mystery',
    '電気製造工場の原材料不明事件',
    '理科室の資料棚。「発電方法別の割合」の円グラフと、ある月の電気料金明細が開かれている。',
    [
      line('energyResources.open.1', 'mio', '料金明細の電源構成を見ると、火力が半分以上。発電のもとになるエネルギー資源が書いてあるよ。'),
      line('energyResources.open.2', 'ren', '火力は燃料の化学エネルギーを、水力は水の位置エネルギーを変換してる。変換経路を記録するね。'),
      line('energyResources.open.3', 'dekisugi', '発電所は電気を製造する工場！注文すれば作り放題だよ！'),
    ],
    [
      response('energyResources', 'manufacture-unlimited', 'dekisugi', '製造量は無限！……でも材料がないと工場は動けない。あれ？'),
      response('energyResources', 'conversion-limited', 'ren', '変換の言葉が合ってる。資源の量と効率が、作れる量を決めるんだ。'),
      response('energyResources', 'thermal-only-source', 'mio', '太陽光パネルや風車からの電気も記録にあるね。火力だけじゃないよ。'),
    ],
    [
      line('energyResources.resolve.1', 'ren', '発電はエネルギーの変換。燃料・水・風・光が電気に姿を変えるんだ。'),
      line('energyResources.resolve.2', 'mio', '枯れない再生可能エネルギーと、使えば尽きる枯渇性資源では、選び方が違ってくるね。'),
    ],
    line('energyResources.punchline', 'dekisugi', '電気の原材料は「エネルギー」でした！工場長、材料発注は地球頼みだ！'),
  ),
  natureBalance: story(
    'natureBalance.pond-investigation',
    '池の数表、連鎖反応事件',
    '学校近くの池の生き物調査記録。水草・草食魚・肉食魚の数が3年分並んでいる。',
    [
      line('natureBalance.open.1', 'mio', '2年目、草食魚が増えて水草が減ってる。3年目は草食魚が減って水草が戻ったね。'),
      line('natureBalance.open.2', 'ren', '食べる側と食べられる側の数が、互いに影響し合って変動した記録だ。'),
      line('natureBalance.open.3', 'dekisugi', '自然は自動で元に戻るんだから、水草がゼロになっても大丈夫だったんだよ！'),
    ],
    [
      response('natureBalance', 'recover-anyway', 'dekisugi', '回復力無限説、採用！……でも絶滅した種は帰ってこないか。'),
      response('natureBalance', 'only-humans-change', 'mio', '人間がいなくても、台風や気候の変化でつり合いは動くよ。'),
      response('natureBalance', 'linked-balance', 'ren', 'つながりの上のつり合い、そして回復には限界がある。それがこの記録の読み方だ。'),
    ],
    [
      line('natureBalance.resolve.1', 'mio', '食物網と分解者が物質を循環させて、つり合いを保ってるんだ。'),
      line('natureBalance.resolve.2', 'ren', 'だから一つの変化が連鎖する。環境調査はその変化を早く見つける手段だね。'),
    ],
    line('natureBalance.punchline', 'dekisugi', '池の数表は「連鎖のお知らせ」だった！水草さん、見放してごめん！'),
  ),
  sustainableSociety: story(
    'sustainableSociety.hazard-map',
    '台風を消す装置の設計図事件',
    '防災学習室。地域のハザードマップと過去の浸水記録が開かれている。',
    [
      line('sustainableSociety.open.1', 'ren', '川沿いは浸水リスクが高くて、高台は低い。過去の記録と地形データから作られた予測だね。'),
      line('sustainableSociety.open.2', 'mio', '避難経路も書いてある。予測できれば、構造物と計画で備えられるね。'),
      line('sustainableSociety.open.3', 'dekisugi', '科学力で台風を消す装置を作れば、ハザードマップはいらないよ！設計図はここに！'),
    ],
    [
      response('sustainableSociety', 'mitigate-not-prevent', 'mio', '発生を止めるんじゃなくて、観測と予測で被害を小さくする発想だね。'),
      response('sustainableSociety', 'stop-disasters', 'ren', '地震や台風のエネルギーは、人間が止められる規模じゃないよ。装置の電源は？'),
      response('sustainableSociety', 'technology-fixes-all', 'dekisugi', '全部技術が解決するから人は何もしなくていい！……って、資源が先に尽きる？'),
    ],
    [
      line('sustainableSociety.resolve.1', 'ren', '止めるんじゃなくて備える。観測・警報・構造物・計画で被害を小さくするのが減災だ。'),
      line('sustainableSociety.resolve.2', 'mio', '持続可能な社会も、技術と私たちの選択の両方で環境負荷を減らしていくんだ。'),
    ],
    line('sustainableSociety.punchline', 'dekisugi', '台風消去装置は開発中止！ハザードマップと避難計画、ぼくの名案は「備え」だった！'),
  ),
}
