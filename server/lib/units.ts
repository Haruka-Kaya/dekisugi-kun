import { MISCONCEPTIONS } from './misconceptions.js'
import {
  CURRICULUM_COVERAGE_MANIFEST,
  CURRICULUM_FIELDS,
  CURRICULUM_SAFETY_LEVELS,
} from './curriculum-coverage.js'
import {
  COGNITIVE_OPERATIONS,
  COGNITIVE_TASK_KINDS,
  LOCAL_PRACTICE_STAGES,
  type CognitiveOperation,
  type CognitiveTaskKind,
  localPracticeVariantsFor,
  scienceListeningNeedCodes,
  validateCognitiveTask,
} from './local-practice-variants.js'
import {
  NOTATION_LABS,
  notationLabFor,
  validateNotationLab,
} from './notation-labs.js'
import {
  scienceStoryFor,
  storyConceptKeys,
  validateScienceStory,
} from './science-stories.js'
import { STAGE1_EXPANSION_UNITS } from './stage1-expansion-units.js'
import { STAGE1_PROOF_UNITS } from './stage1-proof-units.js'

/**
 * 単元と、その中で生徒に説明してもらいたい概念。
 *
 * 概念の粒度は**誤概念カタログに合わせてある**。
 * 「誤概念を1つ誘発できる単位」より細かく割っても、観測する手段が無い。
 *
 * > 初期3単元は、学習指導要領のどの項目に対応するかを**未確認**。
 * > FCI 由来のカタログから逆算した区切りなので、教材本体を拡張するときに突き合わせる。
 * > 追加単元は各単元の出典コメントに、確認した学年・内容・一次資料を残す。
 *
 * ## 教材の書き方
 *
 * 教材は**説明の材料**であって、説明の完成品ではない。
 * とはいえ内容を出し惜しみしても学べないので、原理はきちんと書く。
 * 「書き写せないようにする」のは文章の側ではなく、
 * **説明フェーズで画面から消すこと**で担保する（C2）。
 *
 * 各節は、現象 → なぜそう言えるか → よくある引っかかり、の順に書く。
 * 最後の「引っかかり」は誤概念カタログと対応させてある。
 * 先に読ませておくことで、あとで AI が同じ誤りを口にしたとき
 * **「習っていないから訂正できなかった」を切り分けられる。**
 */

export type Concept = {
  key: string
  label: string
  /** 何を説明できたら「説明できた」とするか。ディレクターへの説明文 */
  intent: string
  /** 単元の中での重み。質問の優先順位と充足度の計算に使う */
  weight: number
}

/** 端末内checkpointの1選択肢。正答以外は再挑戦に使う科学的ヒントを持つ。 */
export type LocalCheckpointOption = {
  /** 翻訳しても変えない、節内で一意な識別子 */
  id: string
  text: string
  /** 誤答を答えそのものへ置き換えず、見直す観点だけを返す */
  hint?: string
  /** 誤答にだけ付く、回答IDから独立した一般化need。 */
  needCode?: string
}

/**
 * AI停止中でも1概念の思い込みを見破れる、端末内の確認問題。
 *
 * 自由記述を採点せず、ここを通っても理解度・会話枠・習得状態は更新しない。
 * `lure` はオンラインDirectorの逐語セリフとは別文にし、公開教材へそのセリフを漏らさない。
 */
export type LocalCheckpoint = {
  lure: string
  options: LocalCheckpointOption[]
  correctOptionId: string
  explanation: string
}

/**
 * 必修Speakingで端末内認識と照合する固定語句。
 *
 * `targetPhrase` は画面に出す正本、`acceptedTranscripts` はOSごとの表記揺れだけを
 * 列挙する。意味の近さで推測せず、正規化後の完全一致だけを受理する。
 */
export type LocalSpeakingPractice = {
  targetPhrase: string
  acceptedTranscripts: string[]
}

/**
 * 生徒が読む教材の1節。**概念と1対1で対応させる。**
 *
 * 対応させておくと、復習で「ここが薄い」と分かったときに
 * **読み直す先をそのまま指せる**。対応が崩れると復習が案内で終わる。
 */
export type Section = {
  /** [Concept.key] と対応 */
  conceptKey: string
  title: string
  /** 段落。1段落1トピックで、長くしない */
  body: string[]
  /** 手を動かして確かめられること。読むだけで終わらせないため */
  tryIt: string
  /** 必修Speakingの端末内認識で使う、短い固定目標語句。 */
  localSpeakingPractice: LocalSpeakingPractice
  /**
   * 旧クライアントへ返す1周目の端末内確認。
   * 新クライアントには、これを先頭にした3段階の `localPracticeVariants` を
   * `public-unit-catalog.ts` で組み立てて返す。
   */
  localCheckpoint: LocalCheckpoint
}

export type Unit = {
  id: string
  title: string
  /** 一覧に出す短い紹介 */
  brief: string
  concepts: Concept[]
  /** 読む教材。**説明フェーズでは画面から隠す**（C2） */
  sections: Section[]
}

/**
 * proof sliceで出荷済みの4単元へ、同じunit IDの追加conceptを統合する。
 *
 * 単元を二重に公開するとPath/Pickerが分断されるため、追加正本は
 * concept/sectionだけを足す。対応先不在・題名不一致・重複は起動前に拒否する。
 */
function mergeStage1Units(
  proofUnits: readonly Unit[],
  expansionUnits: readonly Unit[],
): Unit[] {
  const expansionById = new Map(expansionUnits.map((unit) => [unit.id, unit]))
  if (expansionById.size !== expansionUnits.length) {
    throw new Error('Stage 1 expansionのunit IDが重複しています')
  }

  const merged = proofUnits.map((proof) => {
    const expansion = expansionById.get(proof.id)
    if (expansion == null) {
      throw new Error(`Stage 1 expansionに対応するunitがありません: ${proof.id}`)
    }
    if (expansion.title !== proof.title) {
      throw new Error(`Stage 1 unitの題名が一致しません: ${proof.id}`)
    }
    expansionById.delete(proof.id)

    const conceptKeys = [
      ...proof.concepts.map((concept) => concept.key),
      ...expansion.concepts.map((concept) => concept.key),
    ]
    if (new Set(conceptKeys).size !== conceptKeys.length) {
      throw new Error(`Stage 1 unitのconceptが重複しています: ${proof.id}`)
    }

    return {
      ...proof,
      brief: `${proof.brief}${expansion.brief}`,
      concepts: [...proof.concepts, ...expansion.concepts],
      sections: [...proof.sections, ...expansion.sections],
    }
  })

  if (expansionById.size > 0) {
    throw new Error(
      `Stage 1 expansionが未知のunitを指しています: ${[
        ...expansionById.keys(),
      ].join(',')}`,
    )
  }
  return merged
}

const STAGE1_UNITS = mergeStage1Units(
  STAGE1_PROOF_UNITS,
  STAGE1_EXPANSION_UNITS,
)

export const UNITS: Unit[] = [
  {
    id: 'force-motion',
    title: '力と運動',
    brief:
      'ものが落ちる速さ、動き続けるとき、止まるとき、投げ上げたとき。'
      + '力がはたらいているかどうかを、動きから読み取れるようにする単元です。',
    concepts: [
      {
        key: 'fall',
        label: '落下の速さ',
        intent:
          '空気の抵抗を無視できるなら落ちる速さは重さによらないこと。'
          + '**「空気の抵抗を無視すれば」という条件**まで言えて完全',
        weight: 3,
      },
      {
        key: 'inertia',
        label: '慣性',
        intent:
          'はたらく力の合計（合力）がゼロなら、動く物体は速さと向きが一定の'
          + '等速直線運動を続けること。'
          + '「動いている＝進む向きに力がはたらいている」ではないと言えて完全',
        weight: 3,
      },
      {
        key: 'friction',
        label: '止まる理由',
        intent:
          '止まるのは摩擦や空気抵抗など、動きを妨げる力がはたらくから。'
          + 'それらがすべて無ければ止まらないことと、'
          + '**止まる原因を名前で挙げられて**完全',
        weight: 2,
      },
      {
        key: 'throwUp',
        label: '投げ上げた物体にはたらく力',
        intent:
          '空気抵抗を無視できるなら、上昇中も最高点でも下降中も、'
          + '下向きの重力だけがはたらき続けていること。'
          + '**空気抵抗を無視する条件**と、'
          + '**最高点でも力はゼロにならない**ことの両方を言えて完全',
        weight: 2,
      },
    ],
    sections: [
      {
        conceptKey: 'fall',
        title: '落ちる速さは何で決まるか',
        localSpeakingPractice: {
          targetPhrase: '空気抵抗を無視すれば落下の速さは重さによらない',
          acceptedTranscripts: ['空気抵抗を無視すれば落下の速さは重さによらない'],
        },
        body: [
          '同じ高さから、ボウリングの球と野球のボールを同時に手放したとしましょう。'
          + '重い方が先に着きそうな気がしますが、実際にはほぼ同時に落ちます。',
          'ものが落ちるのは地球が引く力（重力）がはたらくからです。'
          + '重いものには強い重力がはたらきますが、重いものほど動かしにくくもあります。'
          + 'この2つがちょうど打ち消し合うので、**落ちる速さは重さによらない**ことになります。',
          'ただし、これは**空気の抵抗を無視できるとき**の話です。'
          + '紙を1枚そのまま落とすとひらひら遅く落ちますが、同じ紙を丸めると速く落ちます。'
          + '紙の重さは変わっていません。変わったのは空気から受ける抵抗の大きさです。',
          '「重いから速い」ではなく「空気の抵抗を受けやすいから遅い」。'
          + 'ここを取り違えると、羽根とコインの実験がうまく説明できなくなります。',
        ],
        tryIt:
          '同じ紙を2枚用意して、片方だけくしゃくしゃに丸めて同時に落としてみてください。'
          + '重さは同じなのに落ち方が違う理由を、自分の言葉で言えますか。',
        localCheckpoint: {
          lure: '空気のない場所でも、同じ高さなら重い球のほうが軽い球より先に着く。',
          options: [
            {
              id: 'heavier-first',
              text: '重い球が先に着く。重いほど重力が強いから。',
              hint: '重い球は強く引かれますが、そのぶん速さを変えにくいことも一緒に考えます。',
            },
            {
              id: 'together',
              text: '2つは同時に着く。空気抵抗を無視すれば、落下加速度は重さによらないから。',
            },
            {
              id: 'lighter-first',
              text: '軽い球が先に着く。軽いほど動かしやすいから。',
              hint: '動かしやすさだけでなく、地球から受ける重力の大きさも重さとともに変わります。',
            },
          ],
          correctOptionId: 'together',
          explanation:
            '空気抵抗を無視できるなら、重力の強さと動かしにくさが同じ割合で増えるため、'
            + '落下加速度は重さによらず、同じ高さから同時に放せば同時に着きます。',
        },
      },
      {
        conceptKey: 'inertia',
        title: '動き続けるのに力は要らない',
        localSpeakingPractice: {
          targetPhrase: '合力がゼロなら物体は同じ速さと向きで動き続ける',
          acceptedTranscripts: [
            '合力がゼロなら物体は同じ速さと向きで動き続ける',
            '合力が0なら物体は同じ速さと向きで動き続ける',
          ],
        },
        body: [
          '電車が急に止まると、体は前に倒れそうになります。'
          + '前向きに押されたわけではありません。'
          + '動いていた体が、そのまま動き続けようとしただけです。',
          'ものには「いまの動きを続けようとする」性質があります。これを**慣性**といいます。'
          + '止まっているものは止まり続けようとし、動いているものは'
          + '同じ速さと同じ向きのまま、まっすぐ動き続けようとします。',
          'ここが直感とずれやすいところです。'
          + 'ふだん目にするものはすぐ止まるので、「動き続けるには力が要る」と感じます。'
          + 'でも実際は逆で、**はたらく力を全部合わせた合力がゼロなら、'
          + '速さも向きも変わらない**のがものの本来のふるまいです。',
          'つまり「動いている」ことは「進む向きに力がはたらいている」ことの証拠にはなりません。'
          + '速さや向きが**変わった**なら合力はゼロではなく、'
          + '変わらないなら合力はゼロです。'
          + 'ただし、合力がゼロでも、個別の力がつり合っていることはあります。',
        ],
        tryIt:
          '机の上でコインを指ではじいてみてください。'
          + '指が離れたあともコインは進みます。そのあいだ、進む向きに何かが押していますか。',
        localCheckpoint: {
          lure: '摩擦のない氷の上でも、物体が一定の速さで進み続けるには、前向きの力が必要だ。',
          options: [
            {
              id: 'forward-force',
              text: '前向きの力が必要。力がなくなれば、すぐ止まる。',
              hint: '力は「動いていること」ではなく、速さや向きを変える原因です。',
            },
            {
              id: 'no-force-stop',
              text: 'どの向きにも力がなければ、その場で静止する。',
              hint: '力がなくなった瞬間に速さが消えるなら、何がその速さを変えたのかを考えてください。',
            },
            {
              id: 'net-zero-motion',
              text: '合力がゼロなら、物体は同じ速さと向きで進み続ける。',
            },
          ],
          correctOptionId: 'net-zero-motion',
          explanation:
            '合力がゼロなら加速度はゼロです。止まっている物体は止まり続け、動いている物体は'
            + '同じ速さと向きの等速直線運動を続けます。',
        },
      },
      {
        conceptKey: 'friction',
        title: 'では、なぜ止まるのか',
        localSpeakingPractice: {
          targetPhrase: '摩擦や空気抵抗が物体の動きを妨げる',
          acceptedTranscripts: [
            '摩擦や空気抵抗が物体の動きを妨げる',
            '摩擦や空気抵抗が物体の動きをさまたげる',
          ],
        },
        body: [
          '慣性があるなら、はじいたコインはいつまでも進み続けるはずです。'
          + 'でも実際は数十センチで止まります。何かが動きを妨げているからです。',
          '床とコインの間には**摩擦力**がはたらきます。'
          + '進む向きと逆向きにはたらくので、速さがだんだん小さくなり、やがて止まります。'
          + '空気の中を進むものには**空気抵抗**も同じようにはたらきます。',
          'つまり「ほうっておけば自然に止まる」のではありません。'
          + '**止めている力がある**から止まるのです。',
          '氷の上やエアホッケーの台のように摩擦が小さいところでは、'
          + 'ものはずっと遠くまで滑っていきます。'
          + '摩擦だけでなく、空気抵抗など動きを妨げる力をすべてゼロにできれば、'
          + '物体は止まりません。',
        ],
        tryIt:
          '同じ力ではじいたコインを、机の上と、タオルの上で比べてみてください。'
          + 'どちらが早く止まりますか。その差は何の違いから来ていますか。',
        localCheckpoint: {
          lure: '机の上を滑るコインは、押したときにもらった「動く力」を使い切ると自然に止まる。',
          options: [
            {
              id: 'opposing-forces',
              text: '摩擦や空気抵抗など、動きを妨げる力がはたらくため止まる。',
            },
            {
              id: 'stored-force',
              text: '押した力がコインの中に蓄えられ、それを使い切るため止まる。',
              hint: '手が離れたあと、押した力そのものが物体の中に残るわけではありません。',
            },
            {
              id: 'gravity-backward',
              text: '重力が進む向きと反対にはたらくため止まる。',
              hint: '水平な机では重力は下向きです。進む向きと逆向きの力を探してください。',
            },
          ],
          correctOptionId: 'opposing-forces',
          explanation:
            'コインの速さを小さくするのは、進行方向と逆向きの摩擦や空気抵抗です。'
            + 'それらの抵抗がすべてなければ、コインは自然には止まりません。',
        },
      },
      {
        conceptKey: 'throwUp',
        title: '投げ上げたボールにはたらく力',
        localSpeakingPractice: {
          targetPhrase: '最高点でも物体には下向きの重力が働く',
          acceptedTranscripts: [
            '最高点でも物体には下向きの重力が働く',
            '最高点でも物体には下向きの重力がはたらく',
          ],
        },
        body: [
          'ボールを真上に投げると、だんだん遅くなり、いちばん高いところで一瞬止まり、'
          + 'そのあと落ちてきます。',
          '**空気抵抗を無視できるとき**、このあいだ、'
          + 'ボールには**ずっと下向きの重力だけ**がはたらいています。'
          + '上がっているあいだも、いちばん高いところでも、落ちているあいだもです。'
          + '手を離れたあとは、上向きに押しているものは何もありません。',
          '上がっているのは、手を離れたときの速さが残っているからです（慣性）。'
          + 'そこに下向きの重力がはたらき続けるので、上向きの速さがだんだん削られていきます。',
          'いちばん高いところで「速さがゼロ」になりますが、'
          + '**力がゼロになったわけではありません**。'
          + '力がゼロなら、そこで止まったまま浮いていることになってしまいます。',
        ],
        tryIt:
          '空気抵抗を無視できるとして、ボールが真上に上がり、'
          + 'いちばん高いところに来た瞬間を思い浮かべてください。'
          + 'そのときボールにはたらいている力を、向きも含めて言えますか。',
        localCheckpoint: {
          lure:
            '空気抵抗を無視すると、投げ上げた球は上昇中に上向きの力を受け、'
            + '最高点では力がゼロになる。',
          options: [
            {
              id: 'up-then-zero',
              text: '上昇中は上向きの力、最高点では力がゼロになる。',
              hint: '手から離れたあとは、球を上向きに押し続けるものがあるかを確認します。',
            },
            {
              id: 'gravity-after-top',
              text: '上昇中は力がなく、最高点を過ぎてから下向きの重力がはたらく。',
              hint: '上昇中に速さが減っているなら、その時点ですでに下向きの加速度があります。',
            },
            {
              id: 'gravity-throughout',
              text: '上昇中も最高点でも下降中も、下向きの重力がはたらき続ける。',
            },
          ],
          correctOptionId: 'gravity-throughout',
          explanation:
            '空気抵抗を無視すれば、手を離れた球には常に下向きの重力だけがはたらきます。'
            + '最高点でゼロになるのは一瞬の速さであって、力ではありません。',
        },
      },
    ],
  },
  {
    id: 'force-balance',
    title: '力のつり合いと作用・反作用',
    brief:
      '2つの力がつり合うとき、押し合う2つの物体のあいだで何が起きているか。'
      + 'つり合いと作用・反作用の違いを区別できるようにする単元です。',
    concepts: [
      {
        key: 'actionReaction',
        label: '作用・反作用',
        intent:
          '作用と反作用は必ず同じ大きさで向きが反対。'
          + 'ただし二つの力は**別々の物体**にはたらき、'
          + 'つり合いのように同じ物体上で打ち消し合うのではないこと。'
          + '**重さや強さによらない**と言えて完全',
        weight: 3,
      },
      {
        key: 'balance',
        label: 'つり合いと運動',
        intent:
          'つり合いは、同じ1つの物体にはたらく個別の力が存在したまま、'
          + 'その合力がゼロになること。'
          + 'つり合っていても等速直線運動を続けることはあり、'
          + '**「つり合い＝静止」ではない**と言えて完全',
        weight: 3,
      },
    ],
    sections: [
      {
        conceptKey: 'actionReaction',
        title: '押したら、同じだけ押し返される',
        localSpeakingPractice: {
          targetPhrase: '作用と反作用は別々の物体に同じ大きさで反対向きに働く',
          acceptedTranscripts: [
            '作用と反作用は別々の物体に同じ大きさで反対向きに働く',
            '作用と反作用は別々の物体に同じ大きさで反対向きにはたらく',
          ],
        },
        body: [
          'かべを手で押すと、手が痛くなります。'
          + '自分が押しているだけのはずなのに、押し返されているからです。',
          'ものを押すと、必ず**同じ大きさで反対向きの力**で押し返されます。'
          + 'これを**作用・反作用**といいます。片方だけが力を出すことはありません。'
          + 'この2つは「手がかべに及ぼす力」と「かべが手に及ぼす力」のように、'
          + '**別々の物体にはたらく力**です。',
          '納得しにくいのは、大きさの違うものどうしがぶつかったときです。'
          + 'トラックと自転車がぶつかったら、トラックの方が強い力を出していそうに見えます。'
          + 'ですが**両者が受ける力の大きさは同じ**です。',
          'では、なぜ自転車の方がふっとぶのか。力が大きいからではなく、'
          + '**軽いほうが同じ力でも大きく動く**からです。'
          + '「受ける力の大きさ」と「動き方」は別のことだ、と分けて考える必要があります。',
        ],
        tryIt:
          'かべを弱く押したときと強く押したときで、手が受ける感触を比べてください。'
          + '自分が出した力と、返ってきた力の関係はどうなっていますか。'
          + 'また、それぞれの力はどの物体にはたらいていますか。',
        localCheckpoint: {
          lure: 'トラックと自転車が衝突すると、重いトラックが自転車へ及ぼす力のほうが大きい。',
          options: [
            {
              id: 'truck-bigger',
              text: 'トラックが及ぼす力のほうが大きい。重い物体のほうが強いから。',
              hint: '衝突中の2つの力は、同じ相互作用から同時に生じる一組として比べます。',
            },
            {
              id: 'equal-pair',
              text: '互いに及ぼす力は同じ大きさで反対向き。それぞれ別の物体にはたらく。',
            },
            {
              id: 'bicycle-bigger',
              text: '自転車が受ける損傷が大きいので、自転車が及ぼす力のほうが大きい。',
              hint: '損傷や動きの大きさと、相手へ及ぼした力の大きさは同じ量ではありません。',
            },
          ],
          correctOptionId: 'equal-pair',
          explanation:
            '作用・反作用の力は、物体の重さによらず同じ大きさで反対向きです。'
            + '別々の物体にはたらき、自転車の動きが大きいのは同じ力でも質量が小さいためです。',
        },
      },
      {
        conceptKey: 'balance',
        title: 'つり合っている＝止まっている、ではない',
        localSpeakingPractice: {
          targetPhrase: '合力がゼロでも物体が動き続けることがある',
          acceptedTranscripts: [
            '合力がゼロでも物体が動き続けることがある',
            '合力が0でも物体が動き続けることがある',
          ],
        },
        body: [
          '机の上の本は動きません。本には、下向きの重力と、'
          + '机が本を上向きに押す力が個別にはたらいています。'
          + '両方の大きさが同じで向きが反対なので、本にはたらく**合力がゼロ**になります。',
          '問題は、**つり合っていても動いていることがある**という点です。'
          + 'まっすぐ一定の速さで走っている車を考えてください。'
          + 'エンジンがタイヤを回すと、タイヤは路面を後ろ向きに押し、'
          + '**路面がタイヤを前向きに押す力**が車を進めます。'
          + 'その前向きの力と、空気抵抗や転がり抵抗などの後ろ向きの力の合計がつり合うと、'
          + '車は同じ速さと向きのまま走り続けます。',
          '力がつり合っているとき、ものは「静止し続ける」か「同じ速さでまっすぐ動き続ける」かの'
          + 'どちらかです。**速さも向きも変わらない**というのが共通点で、'
          + '止まっていることは条件ではありません。',
          'つり合いでは、同じ1つの物体にはたらく力を全部合わせるとゼロになります。'
          + '**個別の力が無くなったわけではありません**。'
          + 'これに対し、作用と反作用は別々の物体にはたらくため、'
          + '同じ1つの物体の上でつり合う2力ではありません。',
        ],
        tryIt:
          'エレベーターが一定の速さで上がっているとき、'
          + '中の人にはたらく重力と床からの力は個別に存在します。'
          + 'それらの合力はどうなっていますか。'
          + '動いていることと合わせて理由を考えてみてください。',
        localCheckpoint: {
          lure:
            '車がまっすぐ一定の速さで走っているなら、前向きの力が後ろ向きの抵抗より大きい。',
          options: [
            {
              id: 'balanced-moving',
              text: '前向きと後ろ向きの力がつり合い、合力がゼロでも一定の速さで進める。',
            },
            {
              id: 'forward-bigger',
              text: '進んでいる間は、前向きの力のほうが必ず大きい。',
              hint: '前向きの力が大きければ、速さは一定ではなく増え続けます。',
            },
            {
              id: 'no-forces',
              text: '一定の速さなら、車には個別の力が何もはたらいていない。',
              hint: '合力がゼロであることと、個別の力が存在しないことは別です。',
            },
          ],
          correctOptionId: 'balanced-moving',
          explanation:
            '一定の速さと向きなら加速度はゼロなので、車にはたらく合力もゼロです。'
            + '前向きの力と後ろ向きの抵抗は個別に存在したまま、合計がつり合っています。',
        },
      },
    ],
  },
  {
    id: 'pressure-buoyancy',
    title: '圧力と浮力',
    brief:
      '同じ力でも、面積が変わると効き方が変わる。水の中では上向きの力を受ける。'
      + '力を「面積あたり」「押しのけた量」で考えられるようにする単元です。',
    concepts: [
      {
        key: 'pressure',
        label: '圧力と面積',
        intent: '圧力 = 力 ÷ 面積。**面積が小さいほど圧力は大きい**と言えて完全',
        weight: 3,
      },
      {
        key: 'buoyancy',
        label: '浮力の大きさ',
        intent:
          '浮力は押しのけた液体の重さに等しい。'
          + '同じ液体の中で、完全に水没し、物体の体積が一定なら、'
          + '深さによって浮力は変わらない。'
          + '**物体の重さではなく、液体の密度と押しのけた体積で決まる**と言えて完全',
        weight: 3,
      },
    ],
    sections: [
      {
        conceptKey: 'pressure',
        title: '同じ力でも、当たる面積で効き方が変わる',
        localSpeakingPractice: {
          targetPhrase: '圧力は力を面積で割った大きさである',
          acceptedTranscripts: ['圧力は力を面積で割った大きさである'],
        },
        body: [
          '画びょうでは、指が触れる頭の側は広く、板に触れる針先はとがっています。'
          + '同じ大きさの力が伝わっても、広い頭は指に食い込みにくく、'
          + '面積の小さい針先は板に刺さります。',
          '面を垂直に押す力を、その面積で割ったものを**圧力**といいます。'
          + '**圧力 = 力 ÷ 面積**。同じ力でも、面積が小さいほど圧力は大きくなります。',
          '雪の上を歩くと沈むのに、スキー板をはくと沈まないのも同じ理由です。'
          + '体重は変わっていません。接する面積を広げたので、圧力が小さくなったのです。',
          '「力が強いか弱いか」だけで考えると、この違いが説明できません。'
          + '**何にどれだけの面積で当たっているか**まで見る必要があります。',
        ],
        tryIt:
          '同じ消しゴムの広い面と細い辺を、それぞれ同じ程度の力で'
          + 'スポンジかやわらかい粘土に押しつけてください。'
          + 'へこみ方が違う理由を、力と面積の言葉で言えますか。',
        localCheckpoint: {
          lure: '同じ力で押すなら、広い面でも狭い面でも圧力は同じだ。',
          options: [
            {
              id: 'same-pressure',
              text: '圧力は同じ。押す力だけで決まるから。',
              hint: '圧力は力そのものではなく、単位面積あたりの力です。',
            },
            {
              id: 'wide-higher',
              text: '広い面のほうが圧力は大きい。力が広く伝わるから。',
              hint: '同じ力をより広い面積へ分けると、単位面積あたりがどうなるか考えます。',
            },
            {
              id: 'narrow-higher',
              text: '狭い面のほうが圧力は大きい。圧力は力を面積で割るから。',
            },
          ],
          correctOptionId: 'narrow-higher',
          explanation:
            '圧力は、面を垂直に押す力を面積で割った量です。'
            + '押す力が同じなら、面積が小さいほど圧力は大きくなります。',
        },
      },
      {
        conceptKey: 'buoyancy',
        title: '浮力は何で決まるか',
        localSpeakingPractice: {
          targetPhrase: '浮力は押しのけた液体の重さに等しい',
          acceptedTranscripts: ['浮力は押しのけた液体の重さに等しい'],
        },
        body: [
          '水に入ると体が軽く感じます。水の中のものは、上向きの力を受けているからです。'
          + 'これを**浮力**といいます。',
          '浮力の大きさは、**そのものが押しのけた水の重さ**と同じです。'
          + '決めているのは、液体の密度と**液体の中に入っている体積**です。'
          + '同じ液体の中で、物体を完全に水没させ、物体の体積が変わらないなら、'
          + '深くしても押しのける液体の量は同じなので、浮力は変わりません。'
          + '一部が液面より上にあるときや、物体の体積が変わるときは別です。',
          '同じ重さの粘土でも、丸めて沈めれば沈み、'
          + '船の形に広げれば浮きます。重さは変わっていません。'
          + '形を変えたことで押しのける水の量が増え、浮力が大きくなったからです。',
          '浮くか沈むかは、浮力と重力のどちらが大きいかで決まります。'
          + '「重いものほど浮力が大きい」と考えると、'
          + 'なぜ鉄の船が浮くのかが説明できなくなります。',
        ],
        tryIt:
          '同じ量の油粘土を、まず中まで詰まった球にして水へ入れます。'
          + '次に薄い舟の形へ広げ、水が入らないよう形を調整して浮くか比べてください。'
          + '重さは同じなのに結果が変わる理由を言えますか。',
        localCheckpoint: {
          lure:
            '同じ液体に、体積が同じで形の変わらない2物体を完全に沈めると、'
            + '重い物体ほど大きな浮力を受ける。',
          options: [
            {
              id: 'heavier-more',
              text: '重い物体のほうが大きな浮力を受ける。重いほど水を強く押すから。',
              hint: '浮力を決めるのは物体の重さではなく、押しのけた液体の重さです。',
            },
            {
              id: 'same-displacement',
              text: '2物体の浮力は同じ。液体の密度と、液体中にある体積が同じだから。',
            },
            {
              id: 'lighter-more',
              text: '軽い物体のほうが大きな浮力を受ける。軽いものほど浮きやすいから。',
              hint: '浮くかどうかは浮力と重力の比較です。浮力の大きさそのものと分けて考えます。',
            },
          ],
          correctOptionId: 'same-displacement',
          explanation:
            '浮力は押しのけた液体の重さに等しいため、同じ液体中で完全に水没し、'
            + '体積が同じで変わらない2物体は、物体自身の重さによらず同じ浮力を受けます。',
        },
      },
    ],
  },
  /**
   * 中学校第2学年・第1分野 (3)「電流とその利用」(イ)「電流と磁界」。
   * 文部科学省「中学校学習指導要領（平成29年告示）解説 理科編」
   * 学年配当 p. 69、内容と取扱い pp. 45–46。
   * https://www.mext.go.jp/content/20230626-mxt_kyoikujinzai02-000033064_05.pdf
   */
  {
    id: 'current-magnetism',
    title: '電流と磁界',
    brief:
      '電流が磁界をつくり、磁界の中の電流が力を受け、コイルを貫く磁束の変化から電流が生まれる。'
      + '向きや動かし方を一つずつ変え、モーターと発電機のしくみをつなぐ単元です。',
    concepts: [
      {
        key: 'currentMagneticField',
        label: '電流がつくる磁界',
        intent:
          '電流が流れる導線やコイルの周囲には磁界ができ、磁力線は磁界の向きを表す'
          + 'モデルであって実体の線ではないこと。電流の向きを逆にすると磁界の向きも逆になり、'
          + 'ほかの条件が同じなら電流を大きくすると磁界が強くなることまで言えて完全',
        weight: 3,
      },
      {
        key: 'magneticForce',
        label: '磁界中の電流が受ける力',
        intent:
          '磁界中の電流は磁界から力を受け、その向きは電流と磁界の両方の向きで決まること。'
          + 'どちらか一方だけを逆にすると力が逆向きになり、両方を逆にすると元の向きになること。'
          + '直線導線では電流と磁界が平行なとき、この磁気的な力はゼロになる条件まで言えて完全',
        weight: 3,
      },
      {
        key: 'electromagneticInduction',
        label: '電磁誘導と発電',
        intent:
          'コイル面を貫く磁界をまとめた量（磁束）が変化すると誘導電圧が生じ、'
          + '閉回路なら誘導電流が流れること。磁石とコイルを相対的に止めて磁束が変化しなければ'
          + '流れ続けず、動かす向きや磁極を'
          + '逆にすると電流の向きも逆になること。直流は向きが一定、交流は向きが周期的に変わる'
          + 'という違いまで言えて完全',
        weight: 3,
      },
    ],
    sections: [
      {
        conceptKey: 'currentMagneticField',
        title: '電流は導線の外にも磁界をつくる',
        localSpeakingPractice: {
          targetPhrase: '電流の向きを逆にすると磁界の向きも逆になる',
          acceptedTranscripts: ['電流の向きを逆にすると磁界の向きも逆になる'],
        },
        body: [
          '方位磁針の近くに導線を置いて電流を流すと、針が振れます。'
          + '導線の外にある針が動くのは、**電流が導線の周囲の空間に磁界をつくる**からです。'
          + '電流を止めても地球などによる磁界は残りますが、その電流がつくった分はなくなります。',
          '磁界の各場所での向きをつないで表す線を**磁力線**といいます。'
          + '磁力線は磁界を読み取るためのモデルで、空間に実在する糸ではありません。'
          + '線の接線方向がその場所の磁界の向きを表し、線を密に描く場所ほど強い磁界を表します。',
          'まっすぐな導線の周囲では、磁界の向きは導線を囲む同心円に沿います。'
          + '導線を輪にしてコイルにすると、それぞれの部分がつくる磁界が重なり、'
          + '全体として内側だけでなく外側にも続く、棒磁石に似た磁界になります。'
          + '**電流の向きを逆にすると磁界の向きも逆**になり、'
          + 'コイルのN極とS極も入れ替わります。',
          '同じ形のコイルを同じ場所で比べるなら、電流を大きくすると磁界は強くなります。'
          + '同じ大きさの電流なら、巻き数を増やすことでもコイル内の磁界を強くできます。'
          + '形、巻き数、鉄心などまで同時に変えると、電流だけの効果とは区別できません。',
        ],
        tryIt:
          '学校の低電圧実験用回路で、南北に向けた絶縁導線の直線部分を方位磁針の上に置き、'
          + 'スイッチを短時間だけ入れて針の振れを観察します。次に電池の向きだけを逆にして比べます。'
          + '電池ホルダーと抵抗または豆電球を必ず使い、電池の両極を導線で直結せず、'
          + '家庭用コンセントにはつながず、先生の指示に従ってください。',
        localCheckpoint: {
          lure: '電流による磁界はコイルの内側だけにでき、コイルの外にはできない。',
          options: [
            {
              id: 'inside-only',
              text: '磁界はコイルの内側だけにあり、外側は常にゼロになる。',
              hint: '棒磁石の磁界がN極からS極へ外側も回ることと、コイル全体の形を比べます。',
            },
            {
              id: 'permanent-wire',
              text: '一度電流を流せば、電流を止めたあとも導線が永久磁石として同じ磁界をつくる。',
              hint: '電流がつくる磁界と、地球や周囲の磁石がもともとつくる磁界を分けて考えます。',
            },
            {
              id: 'around-current',
              text: '電流は導線やコイルの周囲に磁界をつくり、電流を逆にすると磁界も逆向きになる。',
            },
          ],
          correctOptionId: 'around-current',
          explanation:
            '電流が流れる導線の周囲には磁界ができます。コイルでは各部分の磁界が重なり、'
            + '内側だけでなく外側にも棒磁石に似た磁界が続きます。電流の向きを逆にすると、'
            + 'その電流がつくる磁界の向きも逆になります。',
        },
      },
      {
        conceptKey: 'magneticForce',
        title: '向きを一つ変えると、力も反転する',
        localSpeakingPractice: {
          targetPhrase: '電流か磁界の一方だけを逆にすると力の向きは逆になる',
          acceptedTranscripts: ['電流か磁界の一方だけを逆にすると力の向きは逆になる'],
        },
        body: [
          '磁石がつくる磁界の中に導線を置き、導線へ電流を流すと、導線は力を受けます。'
          + 'これは磁界と電流の相互作用による力です。電流が流れていない、または外部の磁界がない'
          + 'ときは、この**磁界中の電流が受ける力**は生じません。',
          'まっすぐな導線では、力の向きは電流の向きと磁界の向きの両方に垂直です。'
          + '**電流か磁界のどちらか一方だけを逆にすると、力の向きも逆**になります。'
          + '両方を逆にすると2回反転するため、力は元の向きです。',
          '力の大きさは電流と磁界のなす角にもよります。直線導線で両者が直角なら力は最大になり、'
          + '平行または反平行なら、この磁気的な力はゼロです。'
          + '「磁界の中なら必ず同じ力」ではなく、向きという条件が必要です。',
          'コイルでは、向かい合う導線部分が逆向きの力を受け、回そうとする作用をつくれます。'
          + 'モーターは磁界と電流を配置し、回転が続くよう電流の向きを切り替えて、'
          + '電気エネルギーを運動へ変えています。単に導線が磁石へ引き寄せられる現象ではありません。',
        ],
        tryIt:
          '学校の電気ブランコなどの低電圧実験器具で、導線が磁界と直角に交わる配置を使います。'
          + '最初の動く向きを記録し、電流だけ、次に磁界だけを逆にして予想と結果を比べます。'
          + '一度に変える条件は一つだけにし、家庭用コンセントや裸の導線で自作せず、'
          + '先生と器具の説明に従ってください。',
        localCheckpoint: {
          lure: '同じ磁界なら、電流を逆向きにしても導線は同じ向きの力を受ける。',
          options: [
            {
              id: 'one-reversal',
              text: '電流だけを逆にすると力も逆向きになる。電流と磁界の両方を逆にすると元の向きになる。',
            },
            {
              id: 'magnet-attraction',
              text: '力はいつも磁石へ向かうので、電流の向きには関係しない。',
              hint: '磁石への単純な引力ではなく、電流と磁界の2つの向きで力の向きが決まります。',
            },
            {
              id: 'reversal-zero',
              text: '電流を逆にすると、磁界と打ち消し合って力は必ずゼロになる。',
              hint: '電流の向きを反転することと、電流を止めることは違います。',
            },
          ],
          correctOptionId: 'one-reversal',
          explanation:
            '磁界中の電流が受ける力は、電流と磁界の両方の向きで決まります。'
            + '片方だけを逆にすれば力は反転し、両方を逆にすれば元の向きです。'
            + 'なお、直線導線で電流と磁界が平行なら、この力はゼロになります。',
        },
      },
      {
        conceptKey: 'electromagneticInduction',
        title: '磁束が変わると電流が生まれる',
        localSpeakingPractice: {
          targetPhrase: '磁束が変化するとコイルに誘導電圧が生じる',
          acceptedTranscripts: ['磁束が変化するとコイルに誘導電圧が生じる'],
        },
        body: [
          'コイルへ磁石を近づけたり遠ざけたりすると、検流計の針が動きます。'
          + '**磁束**とは、コイル面を貫く磁界を、磁界の強さ、コイルの面積、向きまで含めてまとめた量です。'
          + '磁束が変化すると**誘導電圧**が生じ、検流計までつながった閉回路なら'
          + '**誘導電流**が流れます。回路が開いている場合、誘導電圧は生じても電流は流れません。',
          '磁石をコイルの中で止めると、針はゼロへ戻ります。磁石があることだけでは足りず、'
          + '**コイルを貫く磁束が変化していること**が必要です。磁石を動かす代わりにコイルを動かしても、'
          + '両者の相対的な動きが磁束を変えれば同じ現象が起きます。',
          '磁石を入れる向きから抜く向きへ変える、またはN極からS極へ変えると、誘導電流の向きも逆になります。'
          + '同じコイルと回路なら、速く動かす、または強い磁石にすると、各巻きを貫く磁束の変化が'
          + '速くまたは大きくなり、誘導電圧が大きくなります。巻き数を増やす場合は、各巻きに生じる'
          + '誘導電圧が加わり、全体の誘導電圧が大きくなります。ただし、誘導電流と検流計の振れは'
          + '回路全体の抵抗にもよるため、電流を比べるときは抵抗も同じにする必要があります。',
          '発電機は、磁石やコイルを回してコイルを貫く磁束を変え、'
          + '外から加えた運動のエネルギーを電気へ変えます。'
          + '**直流**は電流の向きが一定、**交流**は向きが周期的に変わる電流です。'
          + '回転する発電機はそのままでは交流を生むことが多く、整流器を使えば一方向の直流として取り出せます。',
        ],
        tryIt:
          '学校のコイル、検流計、棒磁石を使い、電源はつながずに、N極を入れる・止める・抜くの'
          + '3段階で針の向きと大きさを記録します。次に動かす速さだけを変えて比べます。'
          + '先生と器具の説明に従い、強い磁石は電子機器や磁気カード、医療機器から離してください。',
        localCheckpoint: {
          lure: '磁石をコイルの中で止めておけば、磁界があるので誘導電流が流れ続ける。',
          options: [
            {
              id: 'field-present',
              text: '磁石がコイル内にある限り、動かなくても同じ向きの電流が流れ続ける。',
              hint: '検流計が振れる瞬間と、磁石を止めたあとの違いに注目します。',
            },
            {
              id: 'changing-field',
              text: 'コイルを貫く磁束が変化すると誘導電圧が生じ、閉回路なら電流が流れる。止めれば流れ続けない。',
            },
            {
              id: 'coil-only',
              text: '電流が生じるのはコイルを動かしたときだけで、磁石を動かしても生じない。',
              hint: 'コイルと磁石のどちらを動かしたかより、コイルを貫く磁束が変わったかを見ます。',
            },
          ],
          correctOptionId: 'changing-field',
          explanation:
            '必要なのは磁石の存在ではなく、コイルを貫く磁束の変化です。変化によって誘導電圧が生じ、'
            + '回路が閉じていれば誘導電流が流れます。相対的な動きを止めて磁束が一定になれば、'
            + '誘導電流は流れ続けません。',
        },
      },
    ],
  },
  ...STAGE1_UNITS,
]

const BY_ID = new Map(UNITS.map((u) => [u.id, u]))

export function unitById(id: string): Unit | undefined {
  return BY_ID.get(id)
}

/**
 * 1回の会話で扱う概念だけに単元を絞る。
 *
 * 指定が無ければ従来どおり単元全体を返す。指定があるのにその単元内で
 * 見つからないときは、**全単元へ黙って戻さず** undefined を返す。
 * ここで黙って戻すと、教材で1概念しか読んでいない生徒へ別の概念まで
 * 質問する会話が始まってしまう。
 *
 * 絞った配列と要素はコピーする。呼び出し側の加工でグローバルな教材
 * カタログを書き換えないため。
 */
export function focusUnit(unit: Unit, focusConceptKey?: string): Unit | undefined {
  if (focusConceptKey == null) return unit

  const concept = unit.concepts.find((candidate) => candidate.key === focusConceptKey)
  if (!concept) return undefined

  return {
    ...unit,
    concepts: [{ ...concept }],
    sections: unit.sections
      .filter((section) => section.conceptKey === focusConceptKey)
      .map((section) => ({
        ...section,
        body: [...section.body],
        localSpeakingPractice: {
          ...section.localSpeakingPractice,
          acceptedTranscripts: [
            ...section.localSpeakingPractice.acceptedTranscripts,
          ],
        },
        localCheckpoint: {
          ...section.localCheckpoint,
          options: section.localCheckpoint.options.map((option) => ({ ...option })),
        },
      })),
  }
}

const speakingIgnoredCharacters = /[\s　、。,.!?，．！？…〜~'‘’"“”「」『』（）()\[\]{}:：;；\-‐‑‒–—―−]/gu

function normalizeSpeakingPhrase(value: string): string {
  return value.toLowerCase().replace(speakingIgnoredCharacters, '')
}

export function validateLocalSpeakingPractice(value: unknown): string[] {
  if (value == null || typeof value !== 'object' || Array.isArray(value)) {
    return ['Speaking正本が無い']
  }
  const raw = value as Record<string, unknown>
  if (
    Object.keys(raw).length !== 2
    || !Object.hasOwn(raw, 'targetPhrase')
    || !Object.hasOwn(raw, 'acceptedTranscripts')
  ) {
    return ['Speaking正本に未知fieldまたは欠落fieldがある']
  }
  const target = raw.targetPhrase
  const accepted = raw.acceptedTranscripts
  if (typeof target !== 'string') return ['Speaking目標語句が文字列でない']
  const targetLength = Array.from(target.trim()).length
  if (target !== target.trim() || targetLength < 12 || targetLength > 80) {
    return ['Speaking目標語句は前後空白なしの12〜80文字が必要']
  }
  if (
    !Array.isArray(accepted)
    || accepted.length < 1
    || accepted.length > 5
    || accepted.some((candidate) => typeof candidate !== 'string')
  ) {
    return ['Speaking受理候補は文字列で1〜5件必要']
  }
  const candidates = accepted as string[]
  if (candidates[0] !== target) {
    return ['Speaking受理候補の先頭に表示目標語句が必要']
  }
  const normalized = candidates.map(normalizeSpeakingPhrase)
  if (
    candidates.some((candidate) => {
      const length = Array.from(candidate.trim()).length
      return candidate !== candidate.trim() || length < 12 || length > 80
    })
    || normalized.some((candidate) => candidate.length === 0)
    || new Set(normalized).size !== normalized.length
  ) {
    return ['Speaking受理候補が空・短すぎる・長すぎる・重複している']
  }
  return []
}

/** その概念の教材はどこか。復習から読み直す先を指すのに使う */
export function sectionFor(unit: Unit, conceptKey: string): Section | undefined {
  return unit.sections.find((s) => s.conceptKey === conceptKey)
}

/**
 * カタログの整合。**起動時に落とす。**
 * 概念に対応する誤概念が無い＝その概念は誘発できず、観測手段が無いまま出荷される。
 * 教材が無い概念は、復習で「読み直す先」を出せない。
 */
export function validateCatalog(): string[] {
  const problems: string[] = []
  const conceptKeys = new Set(UNITS.flatMap((u) => u.concepts.map((c) => c.key)))
  const usedTaskKinds = new Set<CognitiveTaskKind>()
  const usedOperations = new Set<CognitiveOperation>()
  const selectPositions = new Map<number, number>()
  const usedNotationKeys = new Set<string>()
  const usedStoryKeys = new Set<string>()
  const storyIds = new Set<string>()
  const storyTitles = new Set<string>()
  const storySettings = new Set<string>()
  const storyPunchlines = new Set<string>()

  const catalogConceptEntries = UNITS.flatMap((unit) =>
    unit.concepts.map((concept) => ({ unitId: unit.id, conceptKey: concept.key })),
  )
  const manifestEntries = Object.values(CURRICULUM_COVERAGE_MANIFEST)
  if (manifestEntries.length !== catalogConceptEntries.length) {
    problems.push('curriculum coverage manifestが全conceptと1対1でない')
  }
  for (const { unitId, conceptKey } of catalogConceptEntries) {
    const coverage = CURRICULUM_COVERAGE_MANIFEST[conceptKey]
    if (coverage == null || coverage.unitId !== unitId || coverage.conceptKey !== conceptKey) {
      problems.push(`${unitId}/${conceptKey}: curriculum coverageが無いか対応先が不正`)
      continue
    }
    if (!CURRICULUM_FIELDS.includes(coverage.field)
      || !Number.isInteger(coverage.grade) || coverage.grade < 1 || coverage.grade > 3
      || !Number.isInteger(coverage.difficulty)
      || coverage.difficulty < 1 || coverage.difficulty > 5) {
      problems.push(`${unitId}/${conceptKey}: field・grade・difficultyが不正`)
    }
    if (coverage.curriculumRefs.length === 0
      || coverage.curriculumRefs.some((entry) =>
        entry.document !== 'mext-jhs-science-2017'
        || !entry.section.trim()
        || !entry.url.startsWith('https://www.mext.go.jp/')
        || entry.pages.length === 0
        || entry.pages.some((page) => !Number.isInteger(page) || page < 1)
      )) {
      problems.push(`${unitId}/${conceptKey}: MEXT curriculumRefsが空または不正`)
    }
    if (!CURRICULUM_SAFETY_LEVELS.includes(coverage.safety.level)
      || !coverage.safety.guidance.trim()) {
      problems.push(`${unitId}/${conceptKey}: safety分類または具体的な安全条件が無い`)
    }
    if (coverage.prerequisites.includes(conceptKey)
      || new Set(coverage.prerequisites).size !== coverage.prerequisites.length
      || coverage.prerequisites.some(
        (key) => !catalogConceptEntries.some((entry) => entry.conceptKey === key),
      )) {
      problems.push(`${unitId}/${conceptKey}: prerequisitesが自己参照・重複・未知concept`)
    }
  }
  for (const entry of manifestEntries) {
    if (!catalogConceptEntries.some(
      (candidate) => candidate.unitId === entry.unitId
        && candidate.conceptKey === entry.conceptKey,
    )) {
      problems.push(`${entry.unitId}/${entry.conceptKey}: manifestが存在しない教材を指す`)
    }
  }

  for (const u of UNITS) {
    const seen = new Set<string>()
    for (const c of u.concepts) {
      if (seen.has(c.key)) problems.push(`${u.id}: 概念キーが重複 ${c.key}`)
      seen.add(c.key)
      if (!MISCONCEPTIONS.some((m) => m.conceptKey === c.key)) {
        problems.push(`${u.id}/${c.key}: 対応する誤概念が無い（誘発できない）`)
      }
      if (!u.sections.some((s) => s.conceptKey === c.key)) {
        problems.push(`${u.id}/${c.key}: 教材が無い（読み直す先を出せない）`)
      }
    }
    for (const s of u.sections) {
      if (!seen.has(s.conceptKey)) {
        problems.push(`${u.id}: 教材が存在しない概念を指している ${s.conceptKey}`)
      }
      if (s.body.length === 0) problems.push(`${u.id}/${s.conceptKey}: 教材が空`)

      for (const problem of validateLocalSpeakingPractice(s.localSpeakingPractice)) {
        problems.push(`${u.id}/${s.conceptKey}: ${problem}`)
      }

      const notationLab = notationLabFor(s.conceptKey)
      if (notationLab == null) {
        problems.push(`${u.id}/${s.conceptKey}: Notation Lab正本が無い`)
      } else {
        usedNotationKeys.add(s.conceptKey)
        for (const problem of validateNotationLab(notationLab)) {
          problems.push(`${u.id}/${s.conceptKey}/notationLab: ${problem}`)
        }
      }

      const checkpoint = s.localCheckpoint
      if (checkpoint.lure.trim().length === 0) {
        problems.push(`${u.id}/${s.conceptKey}: checkpointのlureが空`)
      }
      if (checkpoint.explanation.trim().length === 0) {
        problems.push(`${u.id}/${s.conceptKey}: checkpointの正答説明が空`)
      }
      if (checkpoint.options.length !== 3) {
        problems.push(`${u.id}/${s.conceptKey}: checkpointの選択肢は3件必要`)
      }
      const optionIds = checkpoint.options.map((option) => option.id)
      if (new Set(optionIds).size !== optionIds.length) {
        problems.push(`${u.id}/${s.conceptKey}: checkpointの選択肢IDが重複`)
      }
      const correctOptions = checkpoint.options.filter(
        (option) => option.id === checkpoint.correctOptionId,
      )
      if (correctOptions.length !== 1) {
        problems.push(`${u.id}/${s.conceptKey}: checkpointの正答が1件に定まらない`)
      }
      for (const option of checkpoint.options) {
        if (option.id.trim().length === 0 || option.text.trim().length === 0) {
          problems.push(`${u.id}/${s.conceptKey}: checkpointに空の選択肢がある`)
        }
        if (
          option.id !== checkpoint.correctOptionId
          && (option.hint == null || option.hint.trim().length === 0)
        ) {
          problems.push(`${u.id}/${s.conceptKey}/${option.id}: 誤答の科学的ヒントが無い`)
        }
      }

      const onlineLure = MISCONCEPTIONS.find((m) => m.conceptKey === s.conceptKey)?.lure
      if (onlineLure != null && checkpoint.lure === onlineLure) {
        problems.push(`${u.id}/${s.conceptKey}: Directorの逐語lureを公開checkpointへ流用している`)
      }

      const variants = localPracticeVariantsFor(s)
      if (variants.length !== LOCAL_PRACTICE_STAGES.length) {
        problems.push(`${u.id}/${s.conceptKey}: 端末内練習variantは3件必要`)
        continue
      }
      const foundation = variants[0]!
      const scienceStory = scienceStoryFor(s.conceptKey, foundation)
      if (scienceStory == null) {
        problems.push(`${u.id}/${s.conceptKey}: Science Story正本が無い`)
      } else {
        usedStoryKeys.add(s.conceptKey)
        for (const problem of validateScienceStory(scienceStory, s.conceptKey, foundation)) {
          problems.push(`${u.id}/${s.conceptKey}/scienceStory: ${problem}`)
        }
        for (const [label, value, seen] of [
          ['id', scienceStory.id, storyIds],
          ['title', scienceStory.title, storyTitles],
          ['setting', scienceStory.setting, storySettings],
          ['punchline', scienceStory.punchline.text, storyPunchlines],
        ] as const) {
          if (seen.has(value)) problems.push(`${u.id}/${s.conceptKey}: Story ${label}が重複`)
          seen.add(value)
        }
      }
      const stages = variants.map((variant) => variant.stage)
      if (stages.some((stage, index) => stage !== LOCAL_PRACTICE_STAGES[index])) {
        problems.push(`${u.id}/${s.conceptKey}: 端末内練習variantの段階順が不正`)
      }
      const variantLures = new Set<string>()
      const variantTransferPairs = new Set<string>()
      const correctPositions = new Set<number>()
      const conceptTaskKinds = new Set<CognitiveTaskKind>()
      const conceptSelectPositions: number[] = []
      for (const variant of variants) {
        const prefix = `${u.id}/${s.conceptKey}/${variant.stage}`
        const expectedListening = scienceListeningNeedCodes(
          s.conceptKey,
          variant.stage,
        )
        if (
          variant.listeningNeedCodes.transcript !== expectedListening.transcript
          || variant.listeningNeedCodes.meaning !== expectedListening.meaning
          || variant.listeningNeedCodes.transcript
            === variant.listeningNeedCodes.meaning
        ) {
          problems.push(`${prefix}: Listeningの聞き取り/意味need正本が不正`)
        }
        if (
          variant.recallPrompt.trim().length === 0
          || variant.reasoningPrompt.trim().length === 0
          || variant.transferPrompt.trim().length === 0
          || variant.expectedOutcome.trim().length === 0
          || variant.expectedReason.trim().length === 0
        ) {
          problems.push(`${prefix}: 問いまたは場面に対応する比較結果に空欄がある`)
        }
        const transferPair = JSON.stringify([
          variant.transferPrompt,
          variant.expectedOutcome,
          variant.expectedReason,
        ])
        if (variantTransferPairs.has(transferPair)) {
          problems.push(`${prefix}: 別variantと同じ場面・結果・理由を再利用している`)
        }
        variantTransferPairs.add(transferPair)
        const task = variant.cognitiveTask
        usedTaskKinds.add(task.kind)
        usedOperations.add(task.operation)
        conceptTaskKinds.add(task.kind)
        for (const taskProblem of validateCognitiveTask(task)) {
          problems.push(`${prefix}/cognitiveTask: ${taskProblem}`)
        }
        if (task.kind === 'singleSelect') {
          const selectedIndex = task.items.findIndex(
            (item) => item.id === task.solution.selectedItemId,
          )
          if (selectedIndex >= 0) {
            conceptSelectPositions.push(selectedIndex)
            selectPositions.set(
              selectedIndex,
              (selectPositions.get(selectedIndex) ?? 0) + 1,
            )
          }
        }
        const variantCheckpoint = variant.checkpoint
        if (variantLures.has(variantCheckpoint.lure)) {
          problems.push(`${prefix}: 別variantと同じlureを再利用している`)
        }
        variantLures.add(variantCheckpoint.lure)
        if (onlineLure != null && variantCheckpoint.lure === onlineLure) {
          problems.push(`${prefix}: Directorの逐語lureを公開checkpointへ流用している`)
        }
        if (variantCheckpoint.options.length !== 3) {
          problems.push(`${prefix}: checkpointの選択肢は3件必要`)
          continue
        }
        const ids = variantCheckpoint.options.map((option) => option.id)
        if (new Set(ids).size !== ids.length) {
          problems.push(`${prefix}: checkpointの選択肢IDが重複`)
        }
        const correctIndex = variantCheckpoint.options.findIndex(
          (option) => option.id === variantCheckpoint.correctOptionId,
        )
        if (correctIndex < 0) {
          problems.push(`${prefix}: checkpointの正答が無い`)
        } else {
          correctPositions.add(correctIndex)
        }
        const correctOption = variantCheckpoint.options[correctIndex]
        if (
          correctOption != null
          && (
            variant.expectedOutcome === correctOption.text
            || variant.expectedReason === variantCheckpoint.explanation
          )
        ) {
          problems.push(`${prefix}: checkpointの正答をtransfer場面の比較回答へ流用している`)
        }
        for (const option of variantCheckpoint.options) {
          if (option.id === variantCheckpoint.correctOptionId) {
            if (option.hint != null) {
              problems.push(`${prefix}/${option.id}: 正答へhintを付けない`)
            }
            if (option.needCode != null) {
              problems.push(`${prefix}/${option.id}: 正答へneedCodeを付けない`)
            }
          } else if (option.hint == null || option.hint.trim().length === 0) {
            problems.push(`${prefix}/${option.id}: 誤答の科学的ヒントが無い`)
          } else if (option.needCode !== task.needCode) {
            problems.push(`${prefix}/${option.id}: 誤答が一般化needCodeと対応しない`)
          }
        }
      }
      if (correctPositions.size !== 3) {
        problems.push(`${u.id}/${s.conceptKey}: 3周の正答位置を0・1・2へ分散する`)
      }
      if (conceptTaskKinds.size < 2) {
        problems.push(`${u.id}/${s.conceptKey}: 3周で最低2種類のcognitiveTaskが必要`)
      }
      if (
        conceptSelectPositions.length > 1
        && new Set(conceptSelectPositions).size === 1
      ) {
        problems.push(`${u.id}/${s.conceptKey}: singleSelectの正答位置が概念内で固定`)
      }
    }
  }
  for (const m of MISCONCEPTIONS) {
    if (!conceptKeys.has(m.conceptKey)) {
      problems.push(`${m.id}: 存在しない概念キー ${m.conceptKey}`)
    }
  }
  for (const notationKey of Object.keys(NOTATION_LABS)) {
    if (!conceptKeys.has(notationKey)) {
      problems.push(`Notation Labが存在しない概念キーを指している ${notationKey}`)
    }
  }
  if (usedNotationKeys.size !== conceptKeys.size) {
    problems.push('全conceptにNotation Labが1件ずつ対応していない')
  }
  const storyKeys = storyConceptKeys()
  if (storyKeys.some((key) => !conceptKeys.has(key))) {
    problems.push('Science Storyが存在しない概念キーを指している')
  }
  if (usedStoryKeys.size !== conceptKeys.size || storyKeys.length !== conceptKeys.size) {
    problems.push('全conceptにScience Storyが1件ずつ対応していない')
  }
  const ids = MISCONCEPTIONS.map((m) => m.id)
  if (new Set(ids).size !== ids.length) problems.push('誤概念IDが重複している')

  if (usedTaskKinds.size !== COGNITIVE_TASK_KINDS.length) {
    problems.push('cognitiveTaskの3種類を全体で使用していない')
  }
  if (usedOperations.size !== COGNITIVE_OPERATIONS.length) {
    problems.push('cognitiveTaskの6操作を全体で使用していない')
  }
  const selectCounts = [0, 1, 2].map((position) => selectPositions.get(position) ?? 0)
  if (
    selectCounts.some((count) => count === 0)
    || Math.max(...selectCounts) - Math.min(...selectCounts) > 1
  ) {
    problems.push(`singleSelectの正答位置を分散していない: ${selectCounts.join('/')}`)
  }

  return problems
}
