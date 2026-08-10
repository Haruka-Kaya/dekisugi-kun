import type { LocalPracticeVariant } from './local-practice-variants.js'

/**
 * Science Stories の固定会話正本。
 *
 * 答えを生成AIで補わず、11 conceptそれぞれに固有の事件・舞台・会話・落ちを
 * 持たせる。科学的な結果と理由、判断の3択はfoundation variantを唯一の正本
 * とし、公開時に完全一致させる。
 */

export type ScienceStoryCharacter = {
  id: string
  name: string
  role: string
}

export type ScienceStoryLine = {
  id: string
  speakerId: string
  text: string
}

export type ScienceStoryChoiceResponse = {
  optionId: string
  line: ScienceStoryLine
}

export type ScienceStory = {
  id: string
  title: string
  setting: string
  foundationNeedCode: string
  characters: ScienceStoryCharacter[]
  openingLines: ScienceStoryLine[]
  choiceLine: ScienceStoryLine
  choiceResponses: ScienceStoryChoiceResponse[]
  resolutionLines: ScienceStoryLine[]
  scientificResolution: {
    outcome: string
    reason: string
  }
  punchline: ScienceStoryLine
}

type StorySource = Omit<
  ScienceStory,
  'choiceLine' | 'scientificResolution' | 'foundationNeedCode'
> & {
  choiceSpeakerId: string
}

const CAST: readonly ScienceStoryCharacter[] = [
  { id: 'mio', name: 'ミオ', role: '観察と安全確認' },
  { id: 'dekisugi', name: 'デキすぎ君', role: '自信満々の仮説' },
  { id: 'ren', name: 'レン', role: '条件と記録の確認' },
]

const line = (id: string, speakerId: 'mio' | 'dekisugi' | 'ren', text: string) => ({
  id,
  speakerId,
  text,
})

const response = (
  storyId: string,
  optionId: string,
  speakerId: 'mio' | 'dekisugi' | 'ren',
  text: string,
): ScienceStoryChoiceResponse => ({
  optionId,
  line: line(`${storyId}.response.${optionId}`, speakerId, text),
})

const story = (
  id: string,
  title: string,
  setting: string,
  openingLines: ScienceStoryLine[],
  choiceResponses: ScienceStoryChoiceResponse[],
  resolutionLines: ScienceStoryLine[],
  punchline: ScienceStoryLine,
): StorySource => ({
  id,
  title,
  setting,
  characters: CAST.map((character) => ({ ...character })),
  openingLines,
  choiceSpeakerId: 'dekisugi',
  choiceResponses,
  resolutionLines,
  punchline,
})

const STORY_SOURCES: Readonly<Record<string, StorySource>> = {
  fall: story(
    'fall.paper-race',
    '紙ひこうき部、落下レース中止事件',
    '放課後の理科室。平らな紙と丸めた紙が、同じスタート台に並んでいる。',
    [
      line('fall.open.1', 'mio', '同じ紙なのに、丸めたほうが先に床へ着いたよ。'),
      line('fall.open.2', 'ren', '重さは同じ。変えたのは形だけ、と記録しておくね。'),
      line('fall.open.3', 'dekisugi', 'ふふん。落下レースなら、重い選手がいつでも有利に決まってるよ。'),
    ],
    [
      response('fall', 'heavier-first', 'mio', 'その説明だと、同じ重さの2枚で差が出た理由が残るね。'),
      response('fall', 'together', 'ren', '真空という条件まで入っている。比較の条件がそろったね。'),
      response('fall', 'lighter-first', 'dekisugi', '軽さ選手権に変更？　でも今回は重さが同じだった！'),
    ],
    [
      line('fall.resolve.1', 'mio', '平らな紙は空気を広く受け、丸めた紙より落下を妨げられたんだ。'),
      line('fall.resolve.2', 'ren', '空気を無視できる同じ条件なら、重さだけで到着順は変わらない。'),
    ],
    line('fall.punchline', 'dekisugi', '次のレースは真空で……え、理科室ごと吸っちゃだめ？'),
  ),
  inertia: story(
    'inertia.coin-runaway',
    '逃走コインと消えた押し手',
    '昼休みの実験机。指を離れたコインが、机の端へ向かって滑っている。',
    [
      line('inertia.open.1', 'ren', '指はもう離れているのに、コインはまだ進んでいる。'),
      line('inertia.open.2', 'mio', 'でも少しずつ遅くなったね。進むことと、速さが変わることを分けよう。'),
      line('inertia.open.3', 'dekisugi', '見えない小人が前から引っぱっている説を提出します！'),
    ],
    [
      response('inertia', 'forward-force', 'ren', '前向きの力が必要なら、指を離した瞬間の運動を説明しにくいよ。'),
      response('inertia', 'no-force-stop', 'mio', '止まるなら速度が変わる。その変化を起こす力が必要になるね。'),
      response('inertia', 'net-zero-motion', 'dekisugi', '合力ゼロでも進む……小人の採用は見送りかあ。'),
    ],
    [
      line('inertia.resolve.1', 'ren', '合力がゼロなら、物体はその速度と向きを保つ。'),
      line('inertia.resolve.2', 'mio', '机では摩擦が反対向きにはたらくから、コインの速さが減ったんだ。'),
    ],
    line('inertia.punchline', 'dekisugi', '逃走コイン、犯人は小人ではなく摩擦でした。小人は釈放！'),
  ),
  friction: story(
    'friction.towel-trap',
    'タオル沼のコイン救出作戦',
    '実験机の半分だけにタオルが敷かれ、同じコインが二つのコースを走る。',
    [
      line('friction.open.1', 'mio', 'タオルのコースでは、コインがすぐ止まったよ。'),
      line('friction.open.2', 'ren', '公平にするなら、スタート時の速さもそろえて比べよう。'),
      line('friction.open.3', 'dekisugi', 'コインの中の「動く力」がタオルに吸われたんだね。タオル、食いしん坊！'),
    ],
    [
      response('friction', 'opposing-forces', 'mio', '進行方向と反対の力を原因にできているね。'),
      response('friction', 'stored-force', 'ren', '押した力は、物体の中に燃料のようには残らないよ。'),
      response('friction', 'gravity-backward', 'dekisugi', '机が水平なら重力は下向き。後ろ向き担当ではなかった！'),
    ],
    [
      line('friction.resolve.1', 'mio', 'タオルとの摩擦が大きいほど、反対向きの合力が大きくなる。'),
      line('friction.resolve.2', 'ren', 'だから同じ初速度なら、タオル上のほうが短い距離で止まるんだ。'),
    ],
    line('friction.punchline', 'dekisugi', '食いしん坊なのはタオルじゃなくて、ぼくの昼休みでした。'),
  ),
  throwUp: story(
    'throwUp.ceiling-camera',
    '最高点ゼロ秒カメラの謎',
    '体育館の安全ネット下。投げ上げた柔らかい球をスローモーションで観察する。',
    [
      line('throwUp.open.1', 'ren', '最高点の一コマでは、球の鉛直速度が一瞬ゼロになっている。'),
      line('throwUp.open.2', 'mio', 'でも次のコマでは下向きに動き始めた。何が速さを変えたのかな。'),
      line('throwUp.open.3', 'dekisugi', '最高点は宇宙の休憩所。力もいったん休憩です！'),
    ],
    [
      response('throwUp', 'up-then-zero', 'mio', '速度がゼロの瞬間と、力がゼロを同じにしていないかな。'),
      response('throwUp', 'gravity-after-top', 'ren', '重力が途中から急に現れるなら、切り替わる原因が必要になるね。'),
      response('throwUp', 'gravity-throughout', 'dekisugi', '休憩していたのは速度だけ。重力は皆勤賞だった！'),
    ],
    [
      line('throwUp.resolve.1', 'mio', '空気抵抗を無視すれば、手を離れた後はずっと下向きの重力だけ。'),
      line('throwUp.resolve.2', 'ren', '最高点でも下向きの加速度があるから、球は下降へ移るんだ。'),
    ],
    line('throwUp.punchline', 'dekisugi', '重力さん、休憩申請は却下されました。'),
  ),
  actionReaction: story(
    'actionReaction.wall-high-five',
    'しゃべらない壁のハイタッチ',
    '校舎の丈夫な壁の前。手のひらで弱く、次に少し強く押した感触を比べる。',
    [
      line('actionReaction.open.1', 'mio', '強く押すほど、手も強く押し返された感じがする。'),
      line('actionReaction.open.2', 'ren', '壁への力と手への力は、別々の物体にはたらいているね。'),
      line('actionReaction.open.3', 'dekisugi', '壁は無口だけど、ハイタッチだけは全力だ。'),
    ],
    [
      response('actionReaction', 'truck-bigger', 'ren', '重さの違いは加速度や損傷の違いには関わるけど、力の対は別だよ。'),
      response('actionReaction', 'equal-pair', 'mio', '別々の物体にはたらく同じ大きさ・反対向きの対だね。'),
      response('actionReaction', 'bicycle-bigger', 'dekisugi', '壊れ方の大きさと、相互作用の力を混ぜていた！'),
    ],
    [
      line('actionReaction.resolve.1', 'ren', '作用・反作用は同じ相互作用から同時に生じる。'),
      line('actionReaction.resolve.2', 'mio', '大きさは同じで反対向き。でも別の物体にはたらくから打ち消し合わない。'),
    ],
    line('actionReaction.punchline', 'dekisugi', '壁との会話、返事は毎回「同じだけ」です。'),
  ),
  balance: story(
    'balance.elevator-alibi',
    '上昇エレベーターのアリバイ',
    '校舎のエレベーター内。表示は上向きだが、一定速度の区間を選んで考える。',
    [
      line('balance.open.1', 'ren', '今は上向きに動いているけど、速さは変わっていない。'),
      line('balance.open.2', 'mio', '床からの上向きの力と、下向きの重力はどちらもあるね。'),
      line('balance.open.3', 'dekisugi', '上へ進むなら、上向きチームが勝っているはず！'),
    ],
    [
      response('balance', 'balanced-moving', 'mio', '動いていても速度一定なら、合力ゼロで説明できるね。'),
      response('balance', 'forward-bigger', 'ren', '上向きの合力があれば、上向きの速度は増えるはずだよ。'),
      response('balance', 'no-forces', 'dekisugi', '個別の力が消えたら床も重力も欠席になっちゃう。'),
    ],
    [
      line('balance.resolve.1', 'mio', '床の力と重力が同じ大きさで反対向きなら、合力はゼロ。'),
      line('balance.resolve.2', 'ren', '合力ゼロは静止だけでなく、一定速度の運動にも対応する。'),
    ],
    line('balance.punchline', 'dekisugi', 'エレベーターは上昇中、ぼくの説は下降中でした。'),
  ),
  pressure: story(
    'pressure.eraser-footprint',
    '消しゴム足あと鑑定団',
    'やわらかい粘土の上。消しゴムの広い面と細い辺で、同じ力の跡を比べる。',
    [
      line('pressure.open.1', 'mio', '細い辺で押した跡のほうが、狭くて深い。'),
      line('pressure.open.2', 'ren', '押す力を同じにして、接する面積だけを変えたよ。'),
      line('pressure.open.3', 'dekisugi', '同じ消しゴムなら、どの面も同じ圧力の顔をしてる！'),
    ],
    [
      response('pressure', 'same-pressure', 'ren', '圧力には力だけでなく面積も入るよ。'),
      response('pressure', 'wide-higher', 'mio', '同じ力が広い面に分かれると、単位面積あたりは小さくなるね。'),
      response('pressure', 'narrow-higher', 'dekisugi', '力を面積で割る。細い辺の足あとが深いわけだ！'),
    ],
    [
      line('pressure.resolve.1', 'ren', '面に垂直な力が同じなら、面積が小さいほど圧力は大きい。'),
      line('pressure.resolve.2', 'mio', 'だから細い辺は、同じ材料へより深い跡をつくったんだ。'),
    ],
    line('pressure.punchline', 'dekisugi', '消しゴムの足あと、犯人は細い辺でした。消す係なのに！'),
  ),
  buoyancy: story(
    'buoyancy.clay-ship',
    '油粘土船、沈没からの大逆転',
    '水を張った透明容器。等しい量の油粘土を、球と水の入らない舟形で比べる。',
    [
      line('buoyancy.open.1', 'mio', '球の粘土は沈んだのに、舟形は浮いたよ。重さは同じ。'),
      line('buoyancy.open.2', 'ren', '舟形は沈む前に、球より多くの水を押しのけている。'),
      line('buoyancy.open.3', 'dekisugi', '舟の形にすると、粘土が急に軽い気持ちになるんだ。'),
    ],
    [
      response('buoyancy', 'heavier-more', 'ren', '完全に沈んだ同体積なら、押しのける液体の体積は同じだよ。'),
      response('buoyancy', 'same-displacement', 'mio', '液体の密度と液体中の体積が同じなら、浮力も同じだね。'),
      response('buoyancy', 'lighter-more', 'dekisugi', '浮きやすさと、受ける浮力の決まり方を混ぜていた！'),
    ],
    [
      line('buoyancy.resolve.1', 'mio', '浮力は押しのけた液体の重さに等しい。'),
      line('buoyancy.resolve.2', 'ren', '舟形は大きな体積の水を押しのけ、重力とつり合えるんだ。'),
    ],
    line('buoyancy.punchline', 'dekisugi', '粘土の気持ちは重いまま。でも船長の気分は浮上！'),
  ),
  currentMagneticField: story(
    'currentMagneticField.compass-whisper',
    '方位磁針が聞いた電流のひそひそ話',
    '先生の監督する低電圧実験台。抵抗を入れた導線の下に方位磁針を置く。',
    [
      line('currentMagneticField.open.1', 'ren', 'スイッチを短時間入れると針が振れ、電池を逆にすると反対へ振れた。'),
      line('currentMagneticField.open.2', 'mio', '電池の両極は直結せず、家庭用コンセントも使わない。安全条件も記録したよ。'),
      line('currentMagneticField.open.3', 'dekisugi', '針が電流のひそひそ話を盗み聞きしてる！'),
    ],
    [
      response('currentMagneticField', 'inside-only', 'mio', '直線導線のそばでも針が振れた観察と合わないね。'),
      response('currentMagneticField', 'permanent-wire', 'ren', '電流を止めた後、針は周囲の磁界が決める向きへ戻ったよ。'),
      response('currentMagneticField', 'around-current', 'dekisugi', '電流を逆にしたら磁界も逆。針は正直だった！'),
    ],
    [
      line('currentMagneticField.resolve.1', 'ren', '電流は導線の周囲に磁界をつくる。'),
      line('currentMagneticField.resolve.2', 'mio', '電流の向きを逆にすると磁界の向きも逆になるから、針の振れも反転した。'),
    ],
    line('currentMagneticField.punchline', 'dekisugi', 'ひそひそ話の内容は「右、いや左」でした。'),
  ),
  magneticForce: story(
    'magneticForce.swing-reversal',
    '電気ブランコ反転裁判',
    '先生の監督する低電圧の電気ブランコ実験。変える条件は毎回一つだけ。',
    [
      line('magneticForce.open.1', 'mio', '電流だけ逆にしたら、導線の動く向きも逆になった。'),
      line('magneticForce.open.2', 'ren', '磁界だけを逆にしても反転。両方を逆にすると元の向きだ。'),
      line('magneticForce.open.3', 'dekisugi', 'ブランコが気分で進路変更したという証言です。'),
    ],
    [
      response('magneticForce', 'one-reversal', 'ren', '一つ反転で力も一回反転、二つ反転なら元に戻る。観察どおりだ。'),
      response('magneticForce', 'magnet-attraction', 'mio', '磁石へ向かうだけなら、電流を逆にした結果を説明できないね。'),
      response('magneticForce', 'reversal-zero', 'dekisugi', 'ゼロではなく反対向きに動いた。証拠映像が強い！'),
    ],
    [
      line('magneticForce.resolve.1', 'mio', '磁気的な力の向きは、電流と磁界の両方で決まる。'),
      line('magneticForce.resolve.2', 'ren', 'どちらか一方を逆にすれば力は反転し、両方なら二回反転する。'),
    ],
    line('magneticForce.punchline', 'dekisugi', 'ブランコは無罪。気分で動いたのは、ぼくの仮説でした。'),
  ),
  electromagneticInduction: story(
    'electromagneticInduction.sleeping-magnet',
    '眠る磁石と無言の検流計',
    '先生の監督する実験台。電源をつながないコイルと検流計へ棒磁石を近づける。',
    [
      line('electromagneticInduction.open.1', 'ren', '磁石を入れる間は針が振れ、止めるとゼロ、抜くと反対へ振れた。'),
      line('electromagneticInduction.open.2', 'mio', '同じ範囲を速く動かしたら、針の振れも大きくなったね。'),
      line('electromagneticInduction.open.3', 'dekisugi', '磁石が止まったら検流計も寝た。二人は仲良しだ。'),
    ],
    [
      response('electromagneticInduction', 'field-present', 'mio', '磁界があるだけなら、止めたときも針が振れ続けるはずだね。'),
      response('electromagneticInduction', 'changing-field', 'ren', '磁束の変化と閉回路を条件にできている。'),
      response('electromagneticInduction', 'coil-only', 'dekisugi', '磁石を動かしても針は振れた。コイルだけの特技じゃない！'),
    ],
    [
      line('electromagneticInduction.resolve.1', 'ren', 'コイルを貫く磁束が変化すると、誘導電圧が生じる。'),
      line('electromagneticInduction.resolve.2', 'mio', '閉回路なら電流が流れ、変化が止まれば流れ続けないんだ。'),
    ],
    line('electromagneticInduction.punchline', 'dekisugi', '検流計の目覚まし時計は、磁束の変化でした。'),
  ),
}

/** Story一覧でも詳細と同じ固定事件名を使うための、正本への読み取り口。 */
export function scienceStoryTitleFor(conceptKey: string): string | undefined {
  return STORY_SOURCES[conceptKey]?.title
}

function copyLine(source: ScienceStoryLine): ScienceStoryLine {
  return { ...source }
}

/** foundation variantへ結合した、端末へ公開できる完成Story。 */
export function scienceStoryFor(
  conceptKey: string,
  foundation: LocalPracticeVariant,
): ScienceStory | undefined {
  const source = STORY_SOURCES[conceptKey]
  if (source == null || foundation.stage !== 'foundation') return undefined
  return {
    id: source.id,
    title: source.title,
    setting: source.setting,
    foundationNeedCode: foundation.cognitiveTask.needCode ?? '',
    characters: source.characters.map((character) => ({ ...character })),
    openingLines: source.openingLines.map(copyLine),
    choiceLine: line(
      `${source.id}.choice`,
      source.choiceSpeakerId as 'mio' | 'dekisugi' | 'ren',
      foundation.checkpoint.lure,
    ),
    choiceResponses: source.choiceResponses.map((entry) => ({
      optionId: entry.optionId,
      line: copyLine(entry.line),
    })),
    resolutionLines: source.resolutionLines.map(copyLine),
    scientificResolution: {
      outcome: foundation.expectedOutcome,
      reason: foundation.expectedReason,
    },
    punchline: copyLine(source.punchline),
  }
}

export function storyConceptKeys(): string[] {
  return Object.keys(STORY_SOURCES)
}

export function validateScienceStory(
  story: ScienceStory,
  conceptKey: string,
  foundation: LocalPracticeVariant,
): string[] {
  const problems: string[] = []
  const prefix = story.id || conceptKey
  if (foundation.stage !== 'foundation') problems.push(`${prefix}: foundation以外へ結合`)
  if (!story.id.trim() || !story.title.trim() || !story.setting.trim()) {
    problems.push(`${prefix}: id・題名・舞台に空欄`)
  }
  const expectedNeed = `science.${conceptKey}.foundation`
  if (story.foundationNeedCode !== expectedNeed
    || story.foundationNeedCode !== foundation.cognitiveTask.needCode) {
    problems.push(`${prefix}: foundation needCodeと一致しない`)
  }
  if (story.choiceLine.text !== foundation.checkpoint.lure) {
    problems.push(`${prefix}: 判断会話がfoundation checkpointと一致しない`)
  }
  if (story.scientificResolution.outcome !== foundation.expectedOutcome
    || story.scientificResolution.reason !== foundation.expectedReason) {
    problems.push(`${prefix}: 科学的解決がfoundation結果・理由と一致しない`)
  }

  const characterIds = story.characters.map((character) => character.id)
  if (story.characters.length < 2
    || new Set(characterIds).size !== story.characters.length
    || story.characters.some(
      (character) => !character.id.trim() || !character.name.trim() || !character.role.trim(),
    )) {
    problems.push(`${prefix}: 登場人物が空または重複`)
  }
  if (story.openingLines.length < 3 || story.resolutionLines.length < 2) {
    problems.push(`${prefix}: opening/resolution会話が不足`)
  }
  const allLines = [
    ...story.openingLines,
    story.choiceLine,
    ...story.choiceResponses.map((entry) => entry.line),
    ...story.resolutionLines,
    story.punchline,
  ]
  const lineIds = allLines.map((entry) => entry.id)
  if (new Set(lineIds).size !== lineIds.length
    || allLines.some(
      (entry) => !entry.id.trim() || !entry.text.trim() || !characterIds.includes(entry.speakerId),
    )) {
    problems.push(`${prefix}: 会話ID重複・空会話・未知speaker参照`)
  }
  const usedCharacters = new Set(allLines.map((entry) => entry.speakerId))
  if (characterIds.some((id) => !usedCharacters.has(id))) {
    problems.push(`${prefix}: 会話に登場しないcharacterがある`)
  }

  const checkpointIds = foundation.checkpoint.options.map((option) => option.id)
  const responseIds = story.choiceResponses.map((entry) => entry.optionId)
  if (story.choiceResponses.length !== checkpointIds.length
    || new Set(responseIds).size !== responseIds.length
    || responseIds.some((id) => !checkpointIds.includes(id))
    || checkpointIds.some((id) => !responseIds.includes(id))) {
    problems.push(`${prefix}: 3選択肢と人物別反応が1対1でない`)
  }
  return problems
}
