import type { LocalCheckpoint } from './units.js'

/**
 * 同じ概念を繰り返すときの、端末内練習の認知的な進み方。
 *
 * 値と順序はFlutterの `LocalPracticeStage.wire` と共有する公開契約。
 * 見かけの難易度ではなく、思い出す → 成立条件を区別する → 新しい場面へ
 * 使う、という学習行為の違いを表す。
 */
export const LOCAL_PRACTICE_STAGES = [
  'foundation',
  'conditions',
  'transfer',
] as const

export type LocalPracticeStage = (typeof LOCAL_PRACTICE_STAGES)[number]

export const COGNITIVE_TASK_KINDS = [
  'singleSelect',
  'classify',
  'sequence',
] as const

export type CognitiveTaskKind = (typeof COGNITIVE_TASK_KINDS)[number]

export const COGNITIVE_OPERATIONS = [
  'prediction',
  'conditionClassify',
  'causalOrder',
  'forceDirection',
  'quantityCompare',
  'experimentPlan',
] as const

export type CognitiveOperation = (typeof COGNITIVE_OPERATIONS)[number]

export type CognitiveTaskItem = { id: string; text: string }
export type CognitiveTaskTarget = { id: string; label: string }

export type CognitiveTask =
  | {
      kind: 'singleSelect'
      operation: CognitiveOperation
      /** 選択内容ではなく、誤答時に残す一般化された固定コード。 */
      needCode?: string
      items: CognitiveTaskItem[]
      solution: { selectedItemId: string }
    }
  | {
      kind: 'classify'
      operation: CognitiveOperation
      needCode?: string
      items: CognitiveTaskItem[]
      targets: CognitiveTaskTarget[]
      solution: { targetByItemId: Record<string, string> }
    }
  | {
      kind: 'sequence'
      operation: CognitiveOperation
      needCode?: string
      items: CognitiveTaskItem[]
      solution: { orderedItemIds: string[] }
    }

export type LocalPracticeVariant = {
  stage: LocalPracticeStage
  /** 教材を閉じた直後に、答えを見ずに取り出す問い。 */
  recallPrompt: string
  /** 最初の説明へ、理由または成立条件を足す問い。 */
  reasoningPrompt: string
  /** 具体場面で予想と理由を結び付ける問い。 */
  transferPrompt: string
  /** transferPromptへ直接対応する観察・予測結果。完了後の比較まで隠す。 */
  expectedOutcome: string
  /** expectedOutcomeが成り立つ理由と条件。完了後の比較まで隠す。 */
  expectedReason: string
  /** transferPromptへ、選択・分類・順序のいずれかで直接答える。 */
  cognitiveTask: CognitiveTask
  /** 最後まで正答を開示せず、誤答には観点だけを返す固定3択。 */
  checkpoint: LocalCheckpoint
  /** Listeningの聞き取りと科学的意味判断を混同しない専用need。 */
  listeningNeedCodes: {
    transcript: string
    meaning: string
  }
}

type PromptPair = Pick<LocalPracticeVariant, 'recallPrompt' | 'reasoningPrompt'>

type VariantWithoutTask = Omit<
  LocalPracticeVariant,
  'stage' | 'cognitiveTask' | 'listeningNeedCodes'
>

type LocalPracticePlan = {
  foundation: PromptPair & Pick<LocalPracticeVariant, 'expectedOutcome' | 'expectedReason'>
  conditions: VariantWithoutTask
  transfer: VariantWithoutTask
}

/**
 * 2周目・3周目の科学内容の正本。
 *
 * 1周目のcheckpointは `server/lib/units.ts` の既存教材を使う。ここではその
 * 想起・理由の問いと、条件を区別する2周目、別場面へ移す3周目を定義する。
 * 端末へは3件をまとめて公開し、完了回数 `n` に対して `n % 3` を選ぶ。
 * variant IDを保存しないため、端末内保存の4フィールド契約は増えない。
 */
const PLANS: Readonly<Record<string, LocalPracticePlan>> = {
  fall: {
    foundation: {
      recallPrompt:
        '物体が落ちる速さと重さの関係を、成り立つ条件も含めて説明してください。',
      reasoningPrompt:
        '重い物体ほど強い重力を受けるのに、結論がどうなるのか。その理由を「動かしにくさ」も使って足してください。',
      expectedOutcome:
        '空気中で同時に放すと、ふつうは丸めた紙が先に着き、平らな紙はひらひらして遅く着きます。',
      expectedReason:
        '紙の質量は同じですが、平らな紙は空気を受ける有効面積が大きく、重力に対する空気抵抗の影響が大きくなります。空気抵抗を無視できる条件で落下加速度が重さによらないこととは矛盾しません。',
    },
    conditions: {
      recallPrompt:
        '同じ紙を平らなまま落とす場合と、丸めて落とす場合を比べるとき、何を確かめられるか説明してください。',
      reasoningPrompt:
        '「重さが同じ」だけでは落ち方がそろわないことがあります。結果へ影響する別の条件を一つ挙げ、理由を足してください。',
      transferPrompt:
        '透明な管の中で、羽根と金属球を同じ高さから同時に放します。管の空気を少しずつ抜くと、2つの着地時刻の差はどう変わると予想しますか。理由も書いてください。',
      expectedOutcome:
        '管から空気を抜くほど2つの着地時刻の差は小さくなり、十分に真空に近づけばほぼ同時に着きます。',
      expectedReason:
        '空気が減ると、特に羽根の落下を遅らせていた空気抵抗が小さくなります。空気抵抗を無視できる同じ場所では、重さによらず重力による落下加速度は同じです。',
      checkpoint: {
        lure:
          '空気中で羽根が金属球より遅く落ちたなら、重い物体ほど落下加速度が大きい証拠になる。',
        options: [
          {
            id: 'air-resistance-condition',
            text: 'その結果だけでは重さの効果といえない。形や空気抵抗の影響を分けて比べる必要がある。',
          },
          {
            id: 'mass-proven',
            text: '金属球が先に着いたので、落下加速度は質量だけで決まる。',
            hint: '2つは重さだけでなく、形や空気から受ける力も違います。何をそろえないと比較できないかを見ます。',
          },
          {
            id: 'air-pushes-up-equally',
            text: '空気はどんな物体も同じ大きさで上へ押すので、差は重さだけから生じる。',
            hint: '空気抵抗は物体の形、面積、速さなどでも変わります。2物体で同じとは限りません。',
          },
        ],
        correctOptionId: 'air-resistance-condition',
        explanation:
          '空気中の落下には重力だけでなく空気抵抗も関わります。羽根と金属球では形や重さに対する空気抵抗の影響が違うため、その観察だけで質量が落下加速度を決めるとはいえません。',
      },
    },
    transfer: {
      recallPrompt:
        '月面で羽根とハンマーを同時に放す実験を、地球上との条件の違いに注目して説明してください。',
      reasoningPrompt:
        '2物体の落ち方を公平に比べるには、空気以外にも何をそろえる必要がありますか。少なくとも一つ挙げて理由を書いてください。',
      transferPrompt:
        '真空容器の中で、同じ高さから同時に、同じ形で重さだけが違う2個の球を静かに放します。どちらが先に底へ着くと予想しますか。観察条件と結び付けて書いてください。',
      expectedOutcome:
        '同じ高さから同時に静かに放せば、重い球と軽い球は同時に底へ着きます。',
      expectedReason:
        '真空中では空気抵抗がなく、地表付近の同じ場所なら重力による加速度は質量によりません。高さ・放す時刻・初速度をそろえた比較で成り立ちます。',
      checkpoint: {
        lure:
          '真空中でも、同じ重さの薄い板と小さな球では形が違うので、落下加速度も違う。',
        options: [
          {
            id: 'shape-changes-vacuum',
            text: '形が違えば真空中でも空気抵抗が変わるので、落下加速度も変わる。',
            hint: '真空という条件で、形の違いがどの力を変えるはずだったかを確認します。',
          },
          {
            id: 'flat-object-floats',
            text: '薄い板には上向きの重力がはたらくため、小さな球より遅くなる。',
            hint: '地球の重力が物体へはたらく向きは、形によって上下反転しません。',
          },
          {
            id: 'same-gravitational-acceleration',
            text: '真空中なら形や重さによらず落下加速度は同じで、同じ条件で放せば同時に着く。',
          },
        ],
        correctOptionId: 'same-gravitational-acceleration',
        explanation:
          '真空中では空気抵抗がなく、地表付近の同じ場所なら物体の形や重さによらず重力による加速度は同じです。同じ高さから同時に静かに放せば同時に着きます。',
      },
    },
  },

  inertia: {
    foundation: {
      recallPrompt:
        '物体にはたらく合力がゼロのとき、止まっている物体と動いている物体がそれぞれどうなるか説明してください。',
      reasoningPrompt:
        '「動いているなら進む向きの力が必要」という説明のどこを見直すべきか、速さと向きの変化に注目して足してください。',
      expectedOutcome:
        '指が離れた後もコインは進み続けますが、実際の机ではだんだん遅くなって止まります。',
      expectedReason:
        '指が離れた後に押した力が前向きに残るわけではなく、慣性によりその速度を保とうとします。机の摩擦や空気抵抗が反対向きの合力をつくるため、速さが減ります。',
    },
    conditions: {
      recallPrompt:
        '宇宙空間でエンジンを切った探査機の動きを、外から受ける合力に注目して説明してください。',
      reasoningPrompt:
        '物体が動き続ける条件を「力が一つもない」と「複数の力の合計がゼロ」に分けて説明してください。',
      transferPrompt:
        '摩擦を無視できる水平な氷の上で、パックを右向きに滑らせたあと手を離します。その後の速さと向きを予想し、合力と結び付けてください。',
      expectedOutcome:
        '手を離した後も、パックはそのときの速さと右向きを保ってまっすぐ進み続けます。',
      expectedReason:
        '摩擦を無視でき、上向きの面の力と下向きの重力がつり合うなら合力はゼロです。加速度がゼロなので速度は変わりません。',
      checkpoint: {
        lure:
          '宇宙船はエンジンを切ると、前向きの力がなくなるので、その場所ですぐ止まる。',
        options: [
          {
            id: 'keeps-velocity',
            text: '外から受ける合力がゼロなら、宇宙船はそのときの速さと向きで進み続ける。',
          },
          {
            id: 'stops-without-engine',
            text: '推進力を失った瞬間に速さがゼロになり、その場所に止まる。',
            hint: '速さをゼロへ変えるにも加速度が必要です。その加速度を生む外力があるかを探します。',
          },
          {
            id: 'slows-by-inertia',
            text: '慣性が進行方向と反対向きにはたらくので、少しずつ遅くなる。',
            hint: '慣性は物体が出す反対向きの力ではなく、運動状態を保とうとする性質です。',
          },
        ],
        correctOptionId: 'keeps-velocity',
        explanation:
          '外力の合計がゼロなら加速度はゼロなので、エンジンを切ったことだけでは速度は変わりません。宇宙船はそのときの速さと向きを保って進み続けます。',
      },
    },
    transfer: {
      recallPrompt:
        '速さの大きさが一定でも、進む向きが変わる運動では合力をどう判断するか説明してください。',
      reasoningPrompt:
        '合力がゼロなら「速さ」だけでなく「向き」も変わらない必要があるのはなぜか、加速度と結び付けてください。',
      transferPrompt:
        '一定の速さで円形コースを走る台車を考えます。速さの数値は同じでも進行方向は変わります。台車にはたらく合力がゼロかどうかを予想し、理由を書いてください。',
      expectedOutcome:
        '台車にはたらく合力はゼロではなく、円の中心方向を向きます。',
      expectedReason:
        '速さの数値が一定でも、速度の向きが変わると加速度があります。円運動の速度の向きを変えるために、内向きの合力が必要です。',
      checkpoint: {
        lure:
          '円運動でも速さの数値が一定なら加速度はゼロなので、物体にはたらく合力もゼロだ。',
        options: [
          {
            id: 'speed-only-zero',
            text: '速さの数値が一定なら、向きが変わっても合力はゼロである。',
            hint: '速度は速さの大きさだけでなく向きも含みます。向きの変化を見落としていないか確認します。',
          },
          {
            id: 'direction-change-force',
            text: '進む向きが変わっているので加速度があり、向きを変える合力はゼロではない。',
          },
          {
            id: 'forward-force-only',
            text: '進み続けているので、合力は常に進行方向だけを向く。',
            hint: '進行方向の速さを増やす力と、速度の向きだけを変える力を区別します。',
          },
        ],
        correctOptionId: 'direction-change-force',
        explanation:
          '速度は大きさと向きを持ちます。円運動では速さの大きさが一定でも速度の向きが変化するため加速度があり、向きを変える合力はゼロではありません。',
      },
    },
  },

  friction: {
    foundation: {
      recallPrompt:
        '滑っている物体がやがて止まる理由を、物体にはたらく力の向きまで含めて説明してください。',
      reasoningPrompt:
        '「押したときの力を使い切るから止まる」では説明できない点を一つ挙げ、摩擦や空気抵抗と結び付けてください。',
      expectedOutcome:
        '同じコインなら、おおむねタオルの上のほうが机の上より早く止まり、進む距離も短くなります。',
      expectedReason:
        '同じ初速度で比べれば、タオルではすべりを妨げる摩擦が一般に大きく、進行方向と反対の合力が大きくなります。「同じ力ではじく」だけでは初速度が同じとは限らないため、公平な比較では初速度もそろえます。',
    },
    conditions: {
      recallPrompt:
        '同じ物体を同じ速さで滑らせても、床の材質で止まるまでの距離が変わる理由を説明してください。',
      reasoningPrompt:
        '重力が下向きにはたらく水平面で、物体の水平方向の速さを小さくする力は何か。力の向きを分けて書いてください。',
      transferPrompt:
        '同じパックを、ざらざらした面となめらかな水平面で同じ速さから滑らせます。止まるまでの距離を予想し、合力の違いで説明してください。',
      expectedOutcome:
        'なめらかな面のパックのほうが、止まるまでに長い距離を進みます。',
      expectedReason:
        '同じパックを同じ初速度で比べると、なめらかな面では進行方向と反対の摩擦が小さく、減速の大きさも小さくなります。',
      checkpoint: {
        lure:
          '水平な机を滑る物体が遅くなるのは、下向きの重力が進行方向と反対向きにはたらくからだ。',
        options: [
          {
            id: 'gravity-slows-horizontal',
            text: '重力が物体の進行方向と反対へ引くので、水平の速さが小さくなる。',
            hint: '水平運動と鉛直方向を分け、重力の矢印がどちらを向くか確認します。',
          },
          {
            id: 'friction-opposes-slip',
            text: '机から受ける摩擦などが滑る向きと反対にはたらき、水平の速さを小さくする。',
          },
          {
            id: 'normal-force-backward',
            text: '机が物体を上向きに押す力が、同時に後ろ向きにも曲がって止める。',
            hint: '水平な面から受ける垂直抗力と、面に沿う摩擦力を別々の力として考えます。',
          },
        ],
        correctOptionId: 'friction-opposes-slip',
        explanation:
          '水平面では重力は下向きで、机からの垂直抗力と鉛直方向につり合います。滑る向きと反対の摩擦や空気抵抗が水平方向の合力となり、速さを小さくします。',
      },
    },
    transfer: {
      recallPrompt:
        '摩擦や空気抵抗を小さくすると、同じ速さで動き始めた物体の運動がどう変わるか説明してください。',
      reasoningPrompt:
        '物体が遠くまで進むことを「前向きの力が増えた」とは限らない理由を、反対向きの力の変化で説明してください。',
      transferPrompt:
        '同じ速さで進む2個のパックの一方だけを、摩擦がより小さい面へ移します。空気抵抗は同じとすると、止まるまでの時間と距離はどう変わると予想しますか。',
      expectedOutcome:
        '摩擦がより小さい面のパックは、止まるまでの時間も距離も長くなります。',
      expectedReason:
        '初速度と空気抵抗が同じなら、摩擦が小さい側は進行方向と反対の合力が小さく、速さの減り方が緩やかになるからです。',
      checkpoint: {
        lure:
          'よりなめらかな面で物体が遠くまで滑るのは、面が物体を前向きに強く押し続けるからだ。',
        options: [
          {
            id: 'smooth-pushes-forward',
            text: 'なめらかな面ほど前向きの摩擦が大きくなり、物体を遠くまで運ぶ。',
            hint: '手を離れたあと、面と物体の間で滑りを妨げる力がどちらを向くかを考えます。',
          },
          {
            id: 'no-force-ever',
            text: '遠くまで進むなら、物体にはどの向きの力も一切はたらいていないと断定できる。',
            hint: '抵抗が小さいことと、摩擦や空気抵抗が完全にゼロであることは同じではありません。',
          },
          {
            id: 'less-opposing-force',
            text: '進行方向と反対の摩擦が小さいため、速さの減り方が小さくなり、より遠くまで進む。',
          },
        ],
        correctOptionId: 'less-opposing-force',
        explanation:
          'なめらかな面では滑りを妨げる摩擦が小さく、進行方向と反対の合力が小さくなります。そのため速さがゆっくり減り、止まるまでの時間と距離が長くなります。',
      },
    },
  },

  throwUp: {
    foundation: {
      recallPrompt:
        '空気抵抗を無視した投げ上げで、手を離れた後の球にはたらく力を、上昇中・最高点・下降中に分けて説明してください。',
      reasoningPrompt:
        '最高点で一瞬ゼロになる量と、ゼロにならない量を区別し、その後に落ち始める理由を足してください。',
      expectedOutcome:
        'いちばん高い点で球の鉛直速度は一瞬ゼロになりますが、その後は下向きに落ち始めます。その瞬間も力は下向きです。',
      expectedReason:
        '空気抵抗を無視すれば、手が離れた後は上昇中も最高点も下降中も下向きの重力がはたらき続けます。速度が一瞬ゼロでも、力や加速度はゼロではありません。',
    },
    conditions: {
      recallPrompt:
        '投げ上げた球が上昇中に遅くなり、下降中に速くなることを、一つの力の向きで説明してください。',
      reasoningPrompt:
        '手を離れた後に上向きの力が残ると考えると、観察される速さの変化とどこが合わないかを書いてください。',
      transferPrompt:
        '空気抵抗を無視し、球が最高点へ近づく直前と、最高点を過ぎた直後を比べます。力の向きと加速度が変わるかどうかを予想し、理由を書いてください。',
      expectedOutcome:
        '最高点の直前でも直後でも、球にはたらく力と加速度はどちらも下向きで、大きさも変わりません。',
      expectedReason:
        '地表付近で空気抵抗を無視する条件では、手を離れた球が受けるのは一定の下向き重力です。最高点を境に変わるのは速度の向きで、力の向きではありません。',
      checkpoint: {
        lure:
          '球は最高点を境に動く向きが逆になるので、はたらく力も上向きから下向きへ切り替わる。',
        options: [
          {
            id: 'gravity-down-throughout',
            text: '空気抵抗を無視すれば、上昇中も最高点でも下降中も重力は下向きで、力の向きは切り替わらない。',
          },
          {
            id: 'force-follows-motion',
            text: '物体が動く向きと力の向きは必ず同じなので、最高点で反転する。',
            hint: '上昇中に球が遅くなっているとき、速度と加速度が同じ向きかを確認します。',
          },
          {
            id: 'zero-until-falling',
            text: '最高点で力が一度ゼロになり、下降が始まってから重力が現れる。',
            hint: '力がゼロのままなら、最高点から速度を下向きへ変え始める原因がありません。',
          },
        ],
        correctOptionId: 'gravity-down-throughout',
        explanation:
          '手を離れた後、空気抵抗を無視すれば球には常に下向きの重力がはたらきます。上昇から下降へ変わるのは速度であり、力と加速度の向きは最高点でも下向きのままです。',
      },
    },
    transfer: {
      recallPrompt:
        '斜めに投げた球が最も高い点に来た瞬間の、速度と力をそれぞれ説明してください。',
      reasoningPrompt:
        '「最も高い点だから速度がすべてゼロ」とは限らない理由を、水平成分と鉛直成分に分けて足してください。',
      transferPrompt:
        '空気抵抗を無視して球を斜め上へ投げます。最も高い点で、球がどの向きへ動き、どの向きの力を受けるかを予想してください。',
      expectedOutcome:
        '最も高い点でも球は水平方向へ動き続け、下向きの重力を受けます。ゼロになるのは速度の鉛直成分です。',
      expectedReason:
        '空気抵抗を無視すると水平向きの合力はなく、水平速度は残ります。一方、重力は最高点でも下向きにはたらき、鉛直速度を上向きから下向きへ変えます。',
      checkpoint: {
        lure:
          '斜めに投げた球は最高点で速さがゼロになり、力もゼロになってから落ち始める。',
        options: [
          {
            id: 'all-zero-at-top',
            text: '最高点では水平・鉛直の速度も力もすべてゼロになる。',
            hint: '最高点でゼロになるのは速度のどの成分か、手を離れた後の水平運動も含めて考えます。',
          },
          {
            id: 'horizontal-velocity-gravity',
            text: '最高点でも水平速度は残り、下向きの重力がはたらく。ゼロになるのは鉛直速度の成分である。',
          },
          {
            id: 'horizontal-force-keeps-motion',
            text: '水平に進み続けるため、最高点では水平向きの力だけがはたらく。',
            hint: '空気抵抗を無視した水平運動を保つのに、水平向きの合力が必要かを見直します。',
          },
        ],
        correctOptionId: 'horizontal-velocity-gravity',
        explanation:
          '斜方投射の最高点でゼロになるのは鉛直速度です。水平速度は残るため球は横へ進み続け、空気抵抗を無視すれば力は下向きの重力だけです。',
      },
    },
  },

  actionReaction: {
    foundation: {
      recallPrompt:
        '2物体が押し合うときの作用・反作用を、大きさ・向き・どの物体にはたらくかの3点で説明してください。',
      reasoningPrompt:
        '重い物体と軽い物体で動き方が違っても、力の一組について何が変わらないか理由を足してください。',
      expectedOutcome:
        'かべを強く押すほど手が強く押し返される感触になります。押している各瞬間で、手がかべへ及ぼす力とかべが手へ及ぼす力は同じ大きさで反対向きです。',
      expectedReason:
        'この2力は、手とかべの接触という同じ相互作用から同時に生じる作用・反作用の対です。一方はかべ、もう一方は手という別々の物体にはたらきます。',
    },
    conditions: {
      recallPrompt:
        '宇宙飛行士が手で人工衛星を押したとき、飛行士と衛星が互いに受ける力を説明してください。',
      reasoningPrompt:
        '同じ大きさの力を受けても加速度が同じとは限らない理由を、質量と結び付けてください。',
      transferPrompt:
        '摩擦を無視できる宇宙空間で、質量の違う2人が手のひらを合わせて押し合います。互いの力と動き方をどう予想しますか。',
      expectedOutcome:
        '押し合う間、2人が受ける力は同じ大きさで反対向きです。質量が小さい人のほうが大きく加速し、速度の変化も大きくなります。',
      expectedReason:
        '作用・反作用の力は別々の人に同じ大きさではたらきます。それぞれの加速度は力を質量で割った値なので、軽い側ほど大きくなります。',
      checkpoint: {
        lure:
          '宇宙飛行士が自分より重い人工衛星を押すと、衛星は飛行士より大きな力で押し返す。',
        options: [
          {
            id: 'satellite-bigger-force',
            text: '重い衛星のほうが出せる力が大きいので、飛行士が受ける力のほうが大きい。',
            hint: '押している間に同じ相互作用から生じる2つの力を、一組として比べます。',
          },
          {
            id: 'astronaut-bigger-force',
            text: '動きやすい飛行士のほうが大きく加速するので、衛星が受ける力のほうが大きい。',
            hint: '加速度の違いだけで力の大小を決めず、質量との関係を分けて考えます。',
          },
          {
            id: 'equal-opposite-different-acceleration',
            text: '互いに受ける力は同じ大きさで反対向きだが、質量が違えば加速度は異なる。',
          },
        ],
        correctOptionId: 'equal-opposite-different-acceleration',
        explanation:
          '押し合う間、飛行士が衛星へ及ぼす力と衛星が飛行士へ及ぼす力は同じ大きさで反対向きです。別々の物体にはたらき、同じ力でも質量が小さい側ほど加速度が大きくなります。',
      },
    },
    transfer: {
      recallPrompt:
        '2人のスケーターが押し合って離れる場面で、作用・反作用の力とそれぞれの運動を分けて説明してください。',
      reasoningPrompt:
        '作用・反作用の2力が互いに打ち消し合わない理由を、「同じ物体にはたらくか」に注目して足してください。',
      transferPrompt:
        '軽いスケーターと重いスケーターが静止した状態から手で押し合います。押している間の力と、離れた直後の速度変化を比べて予想してください。',
      expectedOutcome:
        '押している間の力は同じ大きさで反対向きで、離れた直後は軽いスケーターのほうが大きな速度変化をします。',
      expectedReason:
        '作用・反作用の2力は別々の人にはたらき、同じ大きさでも軽い側の加速度が大きくなります。初め静止し、水平の外力を無視できるなら、2人の運動量は反対向きで大きさが等しくなります。',
      checkpoint: {
        lure:
          '軽いスケーターのほうが大きく動いたので、軽い側だけがより大きな力を受けた。',
        options: [
          {
            id: 'equal-force-mass-difference',
            text: '2人が受ける力は同じ大きさで反対向き。軽い側の加速度が大きいので動きの変化も大きくなる。',
          },
          {
            id: 'lighter-receives-more',
            text: '軽い側が大きく動いたことから、軽い側が受けた力のほうが大きい。',
            hint: '動きの変化は力だけでなく質量にもよります。力の一組と加速度を分けます。',
          },
          {
            id: 'forces-cancel-between-people',
            text: '2つの力は同じ大きさなので、2人の間で打ち消し合い、どちらも動けない。',
            hint: '2つの力が同じ一つの物体にはたらいているか、それぞれの力の相手を確認します。',
          },
        ],
        correctOptionId: 'equal-force-mass-difference',
        explanation:
          '作用・反作用は別々の物体にはたらくので互いに打ち消しません。力の大きさは等しくても、質量が小さいスケーターほど加速度と速度の変化が大きくなります。',
      },
    },
  },

  balance: {
    foundation: {
      recallPrompt:
        '同じ一つの物体にはたらく力がつり合うとはどういうことか、合力と運動の両方で説明してください。',
      reasoningPrompt:
        '「つり合っているなら物体は静止する」とは限らない理由を、速さと向きの変化で足してください。',
      expectedOutcome:
        'エレベーターが上向きに一定速度で動いているとき、人が床から受ける上向きの力は下向きの重力と同じ大きさで、合力はゼロです。',
      expectedReason:
        '上向きに動いていても速度が一定なら加速度はゼロです。合力がゼロなことは個別の力がないことではなく、床の力と重力がつり合っています。',
    },
    conditions: {
      recallPrompt:
        'エレベーターが一定の速さで上がるとき、中の人にはたらく重力と床からの力の関係を説明してください。',
      reasoningPrompt:
        '上向きに動いていることと、上向きの合力があることを区別してください。どんなときに速さが変わるかも書いてください。',
      transferPrompt:
        'エレベーターが上向きに一定速度で進む場合と、上向きに速くなっていく場合を比べます。人にはたらく合力をそれぞれ予想してください。',
      expectedOutcome:
        '上向きに一定速度なら合力はゼロです。上向きに速くなっているなら合力は上向きで、床からの力が重力より大きくなります。',
      expectedReason:
        '速度が一定な場合は加速度がゼロなので力がつり合います。上向きに速度が増す場合は上向きの加速度があるため、上向きの合力が必要です。',
      checkpoint: {
        lure:
          'エレベーターが一定の速さで上がっている間は、床が人を押す上向きの力が重力より大きい。',
        options: [
          {
            id: 'upward-force-bigger',
            text: '上向きに動いているので、床からの力が重力より大きい。',
            hint: '力の差があると速度がどう変わるかを考え、「上向き」と「上向きに加速」を区別します。',
          },
          {
            id: 'balanced-at-constant-speed',
            text: '一定速度なら加速度はゼロで、床からの力と重力がつり合い、合力はゼロである。',
          },
          {
            id: 'no-floor-force-moving',
            text: '動いている間は床と接していても、床から人への力はなくなる。',
            hint: '人が床から離れず同じ動きをしているとき、床が人を支える力が存在するかを確認します。',
          },
        ],
        correctOptionId: 'balanced-at-constant-speed',
        explanation:
          '上向きに動いていても速度が一定なら加速度はゼロです。人にはたらく床からの上向きの力と下向きの重力は同じ大きさで、合力はゼロになります。',
      },
    },
    transfer: {
      recallPrompt:
        '物体が動きながら力がつり合う例を一つ挙げ、個別の力と合力を説明してください。',
      reasoningPrompt:
        '合力がゼロでも個別の力がなくなったわけではないことを、同じ物体への力の矢印で説明してください。',
      transferPrompt:
        '落下する人がやがて一定の速さになった場面を考えます。その瞬間の重力と空気抵抗、合力をどう予想しますか。',
      expectedOutcome:
        '一定の速さで落下しているとき、下向きの重力と上向きの空気抵抗は同じ大きさで、合力はゼロです。',
      expectedReason:
        '落下中でも速度が一定なら加速度はゼロです。重力と空気抵抗は個別に存在したままつり合い、この終端速度の状態では下向きの運動が続きます。',
      checkpoint: {
        lure:
          '落下中の物体は下向きに動いているので、一定の速さになった後も重力が空気抵抗より大きい。',
        options: [
          {
            id: 'gravity-bigger-while-falling',
            text: '下向きに動いている限り、重力が空気抵抗より大きくなければならない。',
            hint: '力の差が下向きに残ると、速さが一定のままでいられるかを考えます。',
          },
          {
            id: 'forces-disappear',
            text: '速さが一定になった瞬間、重力も空気抵抗も両方なくなる。',
            hint: '合力がゼロであることと、個別の力が存在しないことを区別します。',
          },
          {
            id: 'balanced-terminal-motion',
            text: '一定速度なら重力と空気抵抗がつり合い、下向きに動いていても合力はゼロである。',
          },
        ],
        correctOptionId: 'balanced-terminal-motion',
        explanation:
          '落下速度が一定なら加速度はゼロです。下向きの重力と上向きの空気抵抗は個別に存在したまま同じ大きさになり、合力はゼロです。',
      },
    },
  },

  pressure: {
    foundation: {
      recallPrompt:
        '圧力が何で決まるかを、力と面積の関係を使って説明してください。',
      reasoningPrompt:
        '同じ力でも狭い面ほど物へ食い込みやすい理由を、「単位面積あたり」という言葉で足してください。',
      expectedOutcome:
        '同じ程度の力で押すと、消しゴムの細い辺は広い面よりも、ふつうは狭く深いへこみをつくります。',
      expectedReason:
        '面に垂直な力が同じなら、接する面積が小さいほど単位面積あたりの力、つまり圧力が大きくなります。同じ材料と押し方で比べる条件です。',
    },
    conditions: {
      recallPrompt:
        '押す力を変えずに接する面積だけを半分にすると、圧力がどう変わるか説明してください。',
      reasoningPrompt:
        '圧力を比べるとき、力と面積の片方だけを見てはいけない理由を式と結び付けてください。',
      transferPrompt:
        '同じ箱を広い面と、その半分の面積の面でスポンジへ置きます。箱の重さは同じです。圧力とへこみ方を予想し、理由を書いてください。',
      expectedOutcome:
        '接する面積を半分にすると圧力は2倍になり、同じスポンジなら一般により深くへこみます。',
      expectedReason:
        '圧力は面に垂直な力を接する面積で割った量です。箱の重さと置き方以外の条件をそろえれば、力が同じで面積が半分なので圧力は2倍です。',
      checkpoint: {
        lure:
          '面を押す力が同じまま、接する面積を半分にしても圧力は変わらない。',
        options: [
          {
            id: 'half-area-double-pressure',
            text: '圧力は2倍になる。圧力は力を面積で割るので、同じ力で面積が半分なら値は2倍になる。',
          },
          {
            id: 'half-area-half-pressure',
            text: '圧力は半分になる。接する場所が半分になるから。',
            hint: '圧力の式で、面積が分母にあることを確認します。',
          },
          {
            id: 'force-only-same',
            text: '押す力が同じなら、面積に関係なく圧力も同じである。',
            hint: '圧力は力そのものではなく、力を何で割った量かを思い出します。',
          },
        ],
        correctOptionId: 'half-area-double-pressure',
        explanation:
          '圧力は力を面積で割った量です。力を変えずに面積だけを半分にすると、同じ力が半分の面積へかかるため圧力は2倍になります。',
      },
    },
    transfer: {
      recallPrompt:
        '力も面積も違う2つの場合に圧力を比べる手順を、式を使って説明してください。',
      reasoningPrompt:
        '重い物体でも接する面積を十分広くすると圧力が小さくなる場合がある理由を足してください。',
      transferPrompt:
        'Aは100 Nの力を0.5 m²へ、Bは60 Nの力を0.2 m²へ垂直に加えます。どちらの圧力が大きいか、計算の考え方を書いてください。',
      expectedOutcome:
        'Aの圧力は200 Pa、Bの圧力は300 Paなので、Bのほうが大きい圧力です。',
      expectedReason:
        '圧力は力を面積で割ります。Aは100÷0.5=200 Pa、Bは60÷0.2=300 Paと計算するため、力だけが大きいAより、面積の小さいBの圧力が大きくなります。',
      checkpoint: {
        lure:
          '100 Nで押すAと60 Nで押すBなら、面積に関係なくAの圧力のほうが大きい。',
        options: [
          {
            id: 'larger-force-always',
            text: 'Aの力が大きいので、接する面積を計算しなくてもAの圧力が大きい。',
            hint: '圧力は力だけでなく面積も使う比です。両方を同じ単位で計算します。',
          },
          {
            id: 'calculate-ratio',
            text: 'Aは200 Pa、Bは300 PaなのでBが大きい。力を面積で割って比べる。',
          },
          {
            id: 'larger-area-always',
            text: 'Aの面積が大きいので、力の違いに関係なくAの圧力が大きい。',
            hint: '面積が分母にあるとき、面積が大きいことだけで値が大きいとは限りません。',
          },
        ],
        correctOptionId: 'calculate-ratio',
        explanation:
          'Aの圧力は100÷0.5=200 Pa、Bは60÷0.2=300 Paです。力が小さいBでも面積がより小さいため、単位面積あたりの力はBのほうが大きくなります。',
      },
    },
  },

  buoyancy: {
    foundation: {
      recallPrompt:
        '液体中の物体が受ける浮力は何で決まるかを、液体と物体の両方の条件を使って説明してください。',
      reasoningPrompt:
        '浮くか沈むかと、浮力の大きさそのものを分けて考える必要がある理由を足してください。',
      expectedOutcome:
        '同じ量の油粘土でも、中まで詰まった球は沈み、水が入らない薄い舟の形に広げると浮かせられます。',
      expectedReason:
        '舟の形は、水が入らない条件で沈む前に球より大きな体積の水を押しのけます。その結果、押しのけた水の重さに等しい浮力が粘土の重力とつり合えます。粘土自体の重さは変わりません。',
    },
    conditions: {
      recallPrompt:
        '同じ体積の物体を、水と水より密度の小さい油へ完全に沈めたとき、浮力をどう比べるか説明してください。',
      reasoningPrompt:
        '完全に沈んだ体積が同じでも、液体が変わると浮力が変わる理由を「押しのけた液体の重さ」で足してください。',
      transferPrompt:
        '体積が変わらない同じ物体を、水と油へそれぞれ完全に沈めます。どちらで大きな浮力を受けるか予想し、液体の密度と結び付けてください。',
      expectedOutcome:
        '水が油より密度の大きい通常の組み合わせでは、完全に沈んだ同じ物体は水中のほうが大きな浮力を受けます。',
      expectedReason:
        '浮力は押しのけた液体の重さに等しい力です。押しのける体積が同じなら、密度が大きい液体ほどその体積の液体が重く、浮力も大きくなります。',
      checkpoint: {
        lure:
          '同じ物体を同じ体積だけ完全に沈めれば、水でも油でも浮力は必ず同じになる。',
        options: [
          {
            id: 'same-volume-always-same',
            text: '押しのける体積が同じなら、液体の種類に関係なく浮力も同じである。',
            hint: '同じ体積でも、押しのけた液体そのものの重さが同じかを確認します。',
          },
          {
            id: 'oil-always-more',
            text: '油のほうが滑りやすいので、水より大きな浮力を受ける。',
            hint: '滑りやすさではなく、押しのけた液体の密度と体積で比べます。',
          },
          {
            id: 'denser-liquid-more',
            text: '同じ体積を押しのけるなら、密度が大きい液体ほど押しのけた液体が重く、浮力も大きい。',
          },
        ],
        correctOptionId: 'denser-liquid-more',
        explanation:
          '浮力は押しのけた液体の重さに等しいため、沈んだ体積が同じでも液体の密度で変わります。一般に油より密度が大きい水では、同じ体積を押しのける物体への浮力が大きくなります。',
      },
    },
    transfer: {
      recallPrompt:
        '同じ液体中で、体積が変わらない物体を完全に沈めたまま深くすると、浮力をどう考えるか説明してください。',
      reasoningPrompt:
        '深い場所ほど水圧が大きくても、物体全体が受ける浮力が深さだけでは変わらない条件を足してください。',
      transferPrompt:
        '変形しない密閉容器を水中へ完全に沈め、浅い位置から深い位置へ移します。水の密度と容器の体積は一定です。浮力をどう予想しますか。',
      expectedOutcome:
        '水の密度と容器の体積が一定なら、完全に沈んだ容器が受ける浮力は浅い位置でも深い位置でも変わりません。',
      expectedReason:
        '完全に沈んだ変形しない容器は、どの深さでも同じ体積の水を押しのけます。浮力はその水の重さに等しいため、密度や容器の体積が変わらない条件では深さだけでは変わりません。',
      checkpoint: {
        lure:
          '同じ物体を水中で深くするほど水圧が大きくなるので、完全に沈んだ物体の浮力も必ず大きくなる。',
        options: [
          {
            id: 'same-displaced-water',
            text: '同じ液体で物体の水中体積が変わらなければ、押しのける水の重さは同じなので浮力は変わらない。',
          },
          {
            id: 'deeper-more-buoyancy',
            text: '深いほど物体の全方向へ水圧が増えるので、浮力も深さに比例して増える。',
            hint: '上面と下面の圧力を別々に増やすだけでなく、その差と押しのけた水の量を見ます。',
          },
          {
            id: 'deeper-less-buoyancy',
            text: '深いほど水に押さえつけられるため、上向きの浮力は小さくなる。',
            hint: '浮力の向きと、物体が押しのけた液体の重さとの関係を確認します。',
          },
        ],
        correctOptionId: 'same-displaced-water',
        explanation:
          '同じ密度の液体中で、物体が完全に水没し体積も変わらないなら、押しのける液体の体積と重さは一定です。そのため浮力は深さだけでは変わりません。',
      },
    },
  },

  currentMagneticField: {
    foundation: {
      recallPrompt:
        '電流が流れる直線導線やコイルの周囲に何ができるかを、向きが変わる条件も含めて説明してください。',
      reasoningPrompt:
        '磁力線が実在する糸ではないことと、何を表すモデルなのかを説明へ足してください。',
      expectedOutcome:
        '電流を流すと方位磁針は電流なしの向きから振れ、電池の向きだけを逆にすると振れる側も反対になります。電流を止めると周囲の磁界が決める向きへ戻ります。',
      expectedReason:
        '電流は導線の周囲に磁界をつくり、電流の向きを逆にするとその磁界の向きも逆になります。学校の低電圧器具、抵抗または豆電球を使い、導線・針・周囲の磁界などをそろえて比べる条件です。',
    },
    conditions: {
      recallPrompt:
        '直線導線の近くに置いた方位磁針の振れが、電流の向きを逆にするとどう変わるか説明してください。',
      reasoningPrompt:
        '電流を止めた後に方位磁針が北を指しても、導線の電流がつくる磁界が残ったとはいえない理由を足してください。',
      transferPrompt:
        '同じ位置の方位磁針の上に直線導線を置きます。電池の向きだけを逆にしたとき、針の振れる向きを予想し、磁界と結び付けてください。実験は学校の低電圧器具で先生の指示に従うものとします。',
      expectedOutcome:
        '導線と方位磁針の位置を変えずに電池の向きだけを逆にすると、電流なしの基準から針が振れる側は反対になります。',
      expectedReason:
        '電池の向きを逆にすると電流の向きが逆になり、導線の電流がつくる磁界も反転します。そのため、周囲の磁界と合成した磁界を指す方位磁針の振れも反転します。',
      checkpoint: {
        lure:
          '直線導線の電流を逆向きにしても、導線の周囲にできる磁界の向きは変わらない。',
        options: [
          {
            id: 'field-reverses-with-current',
            text: 'ほかの条件が同じなら、電流の向きを逆にすると、その電流がつくる磁界の向きも逆になる。',
          },
          {
            id: 'field-direction-fixed',
            text: '磁界の向きは導線の形だけで決まり、電流の向きには関係しない。',
            hint: '方位磁針の振れを、電池の向きだけ変えた前後で比べます。',
          },
          {
            id: 'field-disappears-when-reversed',
            text: '電流を逆にすると、最初の磁界と打ち消し合って磁界は必ずゼロになる。',
            hint: '前の電流を止めてから逆向きに流す場合、2つの電流が同時に流れているかを確認します。',
          },
        ],
        correctOptionId: 'field-reverses-with-current',
        explanation:
          '電流がつくる磁界の向きは電流の向きで決まります。導線の形や観察位置を変えず電流だけを逆にすれば、その電流による磁界も逆向きになり、方位磁針の振れも反転します。',
      },
    },
    transfer: {
      recallPrompt:
        '同じ形のコイルで磁界を強くする方法を、比較するときにそろえる条件も含めて説明してください。',
      reasoningPrompt:
        '電流と巻き数を同時に変えると、どちらの効果か区別できない理由を、一度に変える条件の数に注目して足してください。',
      transferPrompt:
        '同じ形・同じ巻き数のコイルAとBを比べ、Bだけ電流を大きくします。同じ位置で方位磁針の振れを測るとき、違いをどう予想しますか。',
      expectedOutcome:
        '同じ向きの電流でBだけ電流を大きくすると、Bがつくる磁界のほうが強くなり、測定範囲内では同じ位置の方位磁針も一般に大きく振れます。',
      expectedReason:
        'コイルの形、巻き数、鉄心、向き、測定位置をそろえたなら、電流を大きくするほど電流がつくる磁界は強くなります。針の振れは地球などの周囲の磁界との合成で決まるため、必ず電流に比例するとまでは断定しません。',
      checkpoint: {
        lure:
          'コイルBで電流と巻き数を両方増やして磁界が強くなれば、電流を増やした効果だけが証明できる。',
        options: [
          {
            id: 'current-only-proven',
            text: '磁界が強くなったなら、巻き数も変えていても電流だけの効果と断定できる。',
            hint: '結果へ影響しうる条件を二つ同時に変えたとき、どちらが原因か一つに定まるかを考えます。',
          },
          {
            id: 'control-one-variable',
            text: '電流だけの効果を確かめるなら、形・巻き数・鉄心などをそろえ、電流だけを変えて比べる。',
          },
          {
            id: 'turns-never-matter',
            text: 'コイルの磁界は電流だけで決まり、巻き数や鉄心はどんな場合も影響しない。',
            hint: '同じ電流でも、各巻きがつくる磁界が重なることを考えます。',
          },
        ],
        correctOptionId: 'control-one-variable',
        explanation:
          '電流と巻き数を同時に変えると、磁界の変化をどちらの効果か分けられません。電流の効果を調べるには、コイルの形・巻き数・鉄心・測定位置をそろえ、電流だけを変えます。',
      },
    },
  },

  magneticForce: {
    foundation: {
      recallPrompt:
        '磁界中の直線導線へ電流を流したときの力を、電流と磁界の向きを変えた場合も含めて説明してください。',
      reasoningPrompt:
        '電流と磁界のどちらか片方だけを逆にする場合と、両方を逆にする場合で、力の向きがどう違うか理由を足してください。',
      expectedOutcome:
        '元の配置から電流だけを逆にすると導線の動く向きは反転し、元に戻して磁界だけを逆にしても反転します。電流と磁界を両方とも逆にすると、力は元の向きになります。',
      expectedReason:
        '直線導線が受ける磁気的な力の向きは、電流と磁界の両方の向きで決まります。どちらか一方の反転は力を一回反転させ、両方の反転は二回反転となるため元に戻ります。導線と磁界が平行でない配置が必要です。',
    },
    conditions: {
      recallPrompt:
        '直線導線を流れる電流と磁界が平行な場合、磁気的な力をどう考えるか説明してください。',
      reasoningPrompt:
        '「磁界の中に電流があれば必ず同じ大きさの力」という説明に、向きの条件を足してください。',
      transferPrompt:
        '直線導線を回して、電流の向きが磁界に対して直角な配置から平行な配置へ変わる場面を考えます。磁気的な力の大きさを予想してください。',
      expectedOutcome:
        '電流と磁界のなす角が90度から0度に近づくにつれ、導線が受ける磁気的な力は最大から小さくなり、平行なときにゼロになります。',
      expectedReason:
        '直線導線の力の大きさは、電流と磁界のなす角の正弦に応じます。電流や磁界の強さなどをそろえると、直角で最大、平行または反平行でゼロです。',
      checkpoint: {
        lure:
          '磁界の中にある導線へ電流が流れていれば、電流と磁界が平行でも導線は最大の力を受ける。',
        options: [
          {
            id: 'parallel-maximum',
            text: '平行なときが磁界に沿って最も強く押されるので、力は最大になる。',
            hint: '直線導線の力が最大になる角度と、ゼロになる角度を区別します。',
          },
          {
            id: 'parallel-zero',
            text: '直線導線では電流と磁界が平行または反平行なら磁気的な力はゼロになる。',
          },
          {
            id: 'parallel-reverses',
            text: '平行にすると、直角のときと同じ大きさで力の向きだけが逆になる。',
            hint: '向きを反転する操作と、2つの向きのなす角を90度から0度へ変える操作は別です。',
          },
        ],
        correctOptionId: 'parallel-zero',
        explanation:
          '直線導線が受ける磁気的な力は、電流と磁界が直角のとき最大で、平行または反平行のときゼロです。磁界中にあるというだけでは力の大きさは決まりません。',
      },
    },
    transfer: {
      recallPrompt:
        '磁界中のコイルが回転できる理由を、向かい合う導線部分が受ける力の向きで説明してください。',
      reasoningPrompt:
        'コイルの両側に反対向きの力がはたらいても、回す作用をつくれる理由を、力の作用する位置と結び付けてください。',
      transferPrompt:
        '磁界と直角に交わる向かい合う2辺をもつ長方形コイルへ、2辺で逆向きになる電流を流します。2辺が受ける力と、コイル全体の動きを予想してください。',
      expectedOutcome:
        '回転軸の両側にある向かい合う2辺は、それぞれ反対向きの力を受けます。力の回転作用がゼロになる向きでなければ、その一組がコイルを回します。',
      expectedReason:
        '向かい合う2辺では電流の向きが逆なので、同じ磁界から受ける力も反対向きです。それらが回転軸から離れた異なる位置にはたらくため、平行移動ではなくコイルを回すトルクをつくります。',
      checkpoint: {
        lure:
          'モーターのコイルでは、向かい合う2辺が同じ向きの力を受けるから回転する。',
        options: [
          {
            id: 'same-direction-rotation',
            text: '2辺が同じ向きへ押され、コイル全体が平行移動することが回転になる。',
            hint: '同じ向きの2力がつくる動きと、異なる位置で反対向きの2力がつくる動きを比べます。',
          },
          {
            id: 'forces-cancel-no-motion',
            text: '2辺への力は反対向きなので、どこにはたらいても完全に打ち消し合い回転しない。',
            hint: '力の合計だけでなく、それぞれが回転軸のどちら側にはたらくかを見ます。',
          },
          {
            id: 'opposite-forces-turn-coil',
            text: '向かい合う2辺が異なる位置で反対向きの力を受け、その一組がコイルを回す作用をつくる。',
          },
        ],
        correctOptionId: 'opposite-forces-turn-coil',
        explanation:
          'コイルの向かい合う辺では電流の向きが逆なので、磁界から受ける力も反対向きになります。異なる位置にはたらくこの一組の力がコイルを回す作用をつくります。',
      },
    },
  },

  electromagneticInduction: {
    foundation: {
      recallPrompt:
        'コイルで誘導電圧が生じ、閉回路なら誘導電流が流れる条件を、磁束の変化を使って説明してください。',
      reasoningPrompt:
        '磁石がコイルの中にあるだけでは電流が流れ続けない理由を、相対的な動きと磁束で足してください。',
      expectedOutcome:
        'N極をコイルへ入れる間は検流計が一方へ振れ、止めるとゼロへ戻り、抜く間は反対方向へ振れます。同じ範囲を速く動かすほど振れは大きくなります。',
      expectedReason:
        'コイルを貫く磁束が変化すると誘導電圧が生じ、検流計までの閉回路なら誘導電流が流れます。入れると抜くとで磁束変化の符号が逆になり、止めると変化がなくなります。同じ回路では磁束を速く変えるほど誘導電圧が大きくなります。',
    },
    conditions: {
      recallPrompt:
        'コイルを貫く磁束が変化しても回路が開いている場合、誘導電圧と誘導電流を分けて説明してください。',
      reasoningPrompt:
        '誘導電流が流れるには磁束の変化以外に何が必要か、電流の通り道に注目して足してください。',
      transferPrompt:
        '棒磁石を同じ速さでコイルへ近づけます。一方は検流計まで閉じた回路、もう一方は途中で切れた回路です。誘導電圧と電流をそれぞれどう予想しますか。',
      expectedOutcome:
        '磁束が同じように変化すれば、閉回路と開回路のどちらにも誘導電圧は生じます。閉回路では誘導電流が流れて検流計が振れますが、開回路では連続した電流は流れません。',
      expectedReason:
        '誘導電圧が生じる条件は磁束の変化です。一方、電流が流れ続けるには電荷が一周できる閉じた通り道が必要なので、回路が開いている場合と区別します。',
      checkpoint: {
        lure:
          'コイルの回路が途中で切れていても、磁束が変化すれば閉回路と同じ誘導電流が流れる。',
        options: [
          {
            id: 'open-same-current',
            text: '磁束が変われば回路のつながりに関係なく、同じ電流が流れ続ける。',
            hint: '電圧が生じることと、電荷が回路を一周して流れられることを分けます。',
          },
          {
            id: 'open-no-voltage',
            text: '回路が開いていると、磁束が変化しても誘導電圧そのものが生じない。',
            hint: '誘導電圧が生じる条件と、誘導電流が流れる条件が同じかを確認します。',
          },
          {
            id: 'voltage-without-current',
            text: '磁束が変化すれば誘導電圧は生じるが、回路が開いていれば連続した誘導電流は流れない。',
          },
        ],
        correctOptionId: 'voltage-without-current',
        explanation:
          '磁束の変化によって誘導電圧は生じます。しかし回路が開いていると電流が一周する通り道がないため、閉回路のような誘導電流は流れません。',
      },
    },
    transfer: {
      recallPrompt:
        '同じコイルと回路で磁石を動かす速さを変えると、誘導電圧がどう変わるか説明してください。',
      reasoningPrompt:
        '誘導電流の大きさまで比べるには、磁束の変化だけでなく回路のどの条件もそろえる必要があるかを足してください。',
      transferPrompt:
        '同じ磁石・コイル・閉回路を使い、磁石をゆっくり入れる場合と速く入れる場合を比べます。検流計の振れをどう予想し、何を一定にしますか。',
      expectedOutcome:
        '磁石を速く入れるほど誘導電圧が大きくなり、同じ抵抗の閉回路なら検流計もより大きく振れます。',
      expectedReason:
        '同じ磁石を同じ範囲で速く動かすと、コイルを貫く磁束の時間あたりの変化が大きくなります。電流と振れを公平に比べるには、コイル、磁石の向きと移動範囲、回路全体の抵抗をそろえます。',
      checkpoint: {
        lure:
          '同じ磁石を同じコイルへ入れるなら、動かす速さを変えても誘導電圧は同じである。',
        options: [
          {
            id: 'faster-change-larger-voltage',
            text: '速く動かすほど磁束の変化が速くなり、誘導電圧は大きくなる。電流を比べるなら回路の抵抗もそろえる。',
          },
          {
            id: 'same-final-position',
            text: '最後に同じ位置へ着くので、途中の速さに関係なく誘導電圧は常に同じである。',
            hint: '最初と最後の位置だけでなく、磁束が時間あたりにどれだけ変わるかを見ます。',
          },
          {
            id: 'slower-more-voltage',
            text: 'ゆっくり動かすほど磁界がコイルへ長く当たるので、瞬間の誘導電圧は大きくなる。',
            hint: '長く動かすことと、単位時間あたりの磁束の変化の大きさを区別します。',
          },
        ],
        correctOptionId: 'faster-change-larger-voltage',
        explanation:
          '誘導電圧は磁束の変化の速さに関係するため、同じ磁石を同じ範囲でより速く動かすと大きくなります。誘導電流や検流計の振れを比べるときは、回路全体の抵抗も同じにします。',
      },
    },
  },
}

type CognitiveTaskPlan = Record<LocalPracticeStage, CognitiveTask>

function singleSelectTask(
  operation: CognitiveOperation,
  items: CognitiveTaskItem[],
  selectedItemId: string,
): CognitiveTask {
  return { kind: 'singleSelect', operation, items, solution: { selectedItemId } }
}

function classifyTask(
  operation: CognitiveOperation,
  items: CognitiveTaskItem[],
  targets: CognitiveTaskTarget[],
  targetByItemId: Record<string, string>,
): CognitiveTask {
  return {
    kind: 'classify',
    operation,
    items,
    targets,
    solution: { targetByItemId },
  }
}

function sequenceTask(
  operation: CognitiveOperation,
  items: CognitiveTaskItem[],
  orderedItemIds: string[],
): CognitiveTask {
  return { kind: 'sequence', operation, items, solution: { orderedItemIds } }
}

/**
 * 11概念×3周の構造化課題。
 *
 * 項目順は授業で全員が同じ画面を共有できる著者順で、実行時にrandomizeしない。
 * solutionは比較画面まで隠し、入力widgetにはitems/targetsだけを渡す。
 */
const COGNITIVE_TASKS: Readonly<Record<string, CognitiveTaskPlan>> = {
  fall: {
    foundation: singleSelectTask(
      'prediction',
      [
        { id: 'flat-arrival', text: '平らな紙が先に着き、丸めた紙が後から着く。' },
        { id: 'paired-arrival', text: '形が違っても、ほぼ同時に着く。' },
        { id: 'crumpled-arrival', text: '丸めた紙が先に着き、平らな紙は遅れて着く。' },
      ],
      'crumpled-arrival',
    ),
    conditions: sequenceTask(
      'causalOrder',
      [
        { id: 'time-gap', text: '羽根と金属球の着地時刻の差が小さくなる。' },
        { id: 'air-amount', text: '管の中の空気が少なくなる。' },
        { id: 'feather-drag', text: '羽根を遅らせる空気抵抗が小さくなる。' },
      ],
      ['air-amount', 'feather-drag', 'time-gap'],
    ),
    transfer: classifyTask(
      'experimentPlan',
      [
        { id: 'ball-mass', text: '2個の球の質量' },
        { id: 'ball-shape', text: '2個の球の形と大きさ' },
        { id: 'release-setup', text: '放す高さ・時刻・初速度' },
        { id: 'arrival-time', text: '底へ着く時刻' },
      ],
      [
        { id: 'change', label: '変える' },
        { id: 'hold', label: 'そろえる' },
        { id: 'measure', label: '測る' },
      ],
      {
        'ball-mass': 'change',
        'ball-shape': 'hold',
        'release-setup': 'hold',
        'arrival-time': 'measure',
      },
    ),
  },

  inertia: {
    foundation: singleSelectTask(
      'prediction',
      [
        { id: 'instant-stop', text: '指が離れた瞬間、その場所で止まる。' },
        {
          id: 'keep-then-slow',
          text: '前向きに押す力が残らなくても進み、机の摩擦でしだいに遅くなる。',
        },
        { id: 'steady-speedup', text: '指の力が残るので、前向きに速くなり続ける。' },
      ],
      'keep-then-slow',
    ),
    conditions: classifyTask(
      'conditionClassify',
      [
        { id: 'frictionless-release', text: '摩擦を無視できる氷で、手を離した後のパック' },
        { id: 'rough-release', text: 'ざらざらした面で、手を離した後のパック' },
        { id: 'circular-motion', text: '一定の速さで円形コースを曲がる台車' },
      ],
      [
        { id: 'net-zero', label: '合力はゼロ' },
        { id: 'net-present', label: '合力はゼロではない' },
      ],
      {
        'frictionless-release': 'net-zero',
        'rough-release': 'net-present',
        'circular-motion': 'net-present',
      },
    ),
    transfer: singleSelectTask(
      'forceDirection',
      [
        { id: 'course-center', text: '円形コースの中心方向' },
        { id: 'travel-tangent', text: 'その瞬間の進行方向' },
        { id: 'course-outside', text: '円形コースの外側方向' },
        { id: 'force-absent', text: '合力はゼロ' },
      ],
      'course-center',
    ),
  },

  friction: {
    foundation: classifyTask(
      'experimentPlan',
      [
        { id: 'surface-material', text: '机とタオルという面の材質' },
        { id: 'same-coin', text: '使うコイン' },
        { id: 'launch-speed', text: 'コインが動き始める速さ' },
        { id: 'stopping-distance', text: '止まるまでの距離' },
      ],
      [
        { id: 'change', label: '変える' },
        { id: 'hold', label: 'そろえる' },
        { id: 'measure', label: '測る' },
      ],
      {
        'surface-material': 'change',
        'same-coin': 'hold',
        'launch-speed': 'hold',
        'stopping-distance': 'measure',
      },
    ),
    conditions: sequenceTask(
      'causalOrder',
      [
        { id: 'shorter-distance', text: '止まるまでの距離が短くなる。' },
        { id: 'rougher-surface', text: '同じパックを、よりざらざらした面へ移す。' },
        { id: 'larger-friction', text: '進行方向と反対の摩擦が大きくなる。' },
        { id: 'larger-slowdown', text: '速さの減り方が大きくなる。' },
      ],
      ['rougher-surface', 'larger-friction', 'larger-slowdown', 'shorter-distance'],
    ),
    transfer: singleSelectTask(
      'prediction',
      [
        { id: 'time-only-longer', text: '時間は長くなるが、距離は同じになる。' },
        { id: 'both-longer', text: '止まるまでの時間も距離も長くなる。' },
        { id: 'both-shorter', text: '止まるまでの時間も距離も短くなる。' },
      ],
      'both-longer',
    ),
  },

  throwUp: {
    foundation: classifyTask(
      'forceDirection',
      [
        { id: 'ascending', text: '手を離れた後の上昇中' },
        { id: 'highest-point', text: 'いちばん高い点に来た瞬間' },
        { id: 'descending', text: '下降中' },
      ],
      [
        { id: 'downward', label: '下向きの重力' },
        { id: 'upward', label: '上向きの力' },
        { id: 'zero-force', label: '力はゼロ' },
      ],
      {
        ascending: 'downward',
        'highest-point': 'downward',
        descending: 'downward',
      },
    ),
    conditions: sequenceTask(
      'causalOrder',
      [
        { id: 'downward-speed', text: '最高点の後、下向きの速さが大きくなる。' },
        { id: 'gravity-throughout', text: '力と加速度は最高点の前後とも下向きである。' },
        { id: 'upward-speed', text: '上向きの速度が小さくなる。' },
        { id: 'vertical-zero', text: '最高点で鉛直速度が一瞬ゼロになる。' },
      ],
      ['gravity-throughout', 'upward-speed', 'vertical-zero', 'downward-speed'],
    ),
    transfer: classifyTask(
      'forceDirection',
      [
        { id: 'horizontal-velocity', text: '最高点での速度の水平成分' },
        { id: 'vertical-velocity', text: '最高点での速度の鉛直成分' },
        { id: 'gravity-force', text: '最高点で球が受ける力' },
      ],
      [
        { id: 'downward', label: '下向き' },
        { id: 'horizontal', label: '水平方向に残る' },
        { id: 'zero-value', label: '一瞬ゼロ' },
      ],
      {
        'horizontal-velocity': 'horizontal',
        'vertical-velocity': 'zero-value',
        'gravity-force': 'downward',
      },
    ),
  },

  actionReaction: {
    foundation: classifyTask(
      'forceDirection',
      [
        { id: 'hand-on-wall', text: '手がかべへ及ぼす力' },
        { id: 'wall-on-hand', text: 'かべが手へ及ぼす力' },
        { id: 'strong-wall-on-hand', text: '手で強く押したとき、かべが手へ及ぼす力' },
      ],
      [
        { id: 'toward-wall', label: '手からかべへ向く' },
        { id: 'toward-hand', label: 'かべから手へ向く' },
      ],
      {
        'hand-on-wall': 'toward-wall',
        'wall-on-hand': 'toward-hand',
        'strong-wall-on-hand': 'toward-hand',
      },
    ),
    conditions: singleSelectTask(
      'quantityCompare',
      [
        {
          id: 'equal-force-light-acceleration',
          text: '力は同じ大きさで反対向きで、質量が小さい人の加速度が大きい。',
        },
        {
          id: 'heavy-force-dominates',
          text: '質量が大きい人が、相手へより大きな力を及ぼす。',
        },
        {
          id: 'equal-force-equal-acceleration',
          text: '力が同じ大きさなので、質量が違っても加速度は同じになる。',
        },
      ],
      'equal-force-light-acceleration',
    ),
    transfer: classifyTask(
      'quantityCompare',
      [
        { id: 'interaction-forces', text: '押し合う間に2人が受ける力の大きさ' },
        { id: 'accelerations', text: '押し合う間の加速度の大きさ' },
        { id: 'velocity-changes', text: '離れた直後までの速度変化の大きさ' },
      ],
      [
        { id: 'same-size', label: '2人で同じ大きさ' },
        { id: 'lighter-larger', label: '軽い人のほうが大きい' },
        { id: 'heavier-larger', label: '重い人のほうが大きい' },
      ],
      {
        'interaction-forces': 'same-size',
        accelerations: 'lighter-larger',
        'velocity-changes': 'lighter-larger',
      },
    ),
  },

  balance: {
    foundation: classifyTask(
      'forceDirection',
      [
        { id: 'person-gravity', text: '人にはたらく重力' },
        { id: 'floor-force', text: '床が人を押す力' },
        { id: 'person-net-force', text: '一定速度で上がる人にはたらく合力' },
      ],
      [
        { id: 'zero-size', label: '大きさゼロ' },
        { id: 'downward', label: '下向き' },
        { id: 'upward', label: '上向き' },
      ],
      {
        'person-gravity': 'downward',
        'floor-force': 'upward',
        'person-net-force': 'zero-size',
      },
    ),
    conditions: classifyTask(
      'conditionClassify',
      [
        { id: 'constant-upward', text: '上向きに一定速度で進む。' },
        { id: 'speeding-upward', text: '上向きに進みながら速くなる。' },
        { id: 'slowing-upward', text: '上向きに進みながら遅くなる。' },
      ],
      [
        { id: 'net-downward', label: '合力は下向き' },
        { id: 'net-zero', label: '合力はゼロ' },
        { id: 'net-upward', label: '合力は上向き' },
      ],
      {
        'constant-upward': 'net-zero',
        'speeding-upward': 'net-upward',
        'slowing-upward': 'net-downward',
      },
    ),
    transfer: sequenceTask(
      'causalOrder',
      [
        { id: 'force-balance', text: '上向きの空気抵抗と下向きの重力が同じ大きさになる。' },
        { id: 'speed-growth', text: '落下し始めて速さが増す。' },
        { id: 'terminal-motion', text: '合力がゼロになり、一定の終端速度で落下する。' },
        { id: 'drag-growth', text: '速さとともに上向きの空気抵抗が大きくなる。' },
      ],
      ['speed-growth', 'drag-growth', 'force-balance', 'terminal-motion'],
    ),
  },

  pressure: {
    foundation: classifyTask(
      'experimentPlan',
      [
        { id: 'contact-face', text: '消しゴムの広い面と細い辺' },
        { id: 'eraser-force', text: '同じ消しゴムと押す力' },
        { id: 'soft-material', text: '押しつけるスポンジまたは粘土' },
        { id: 'dent-depth', text: 'へこみの深さ' },
      ],
      [
        { id: 'change', label: '変える' },
        { id: 'hold', label: 'そろえる' },
        { id: 'measure', label: '測る' },
      ],
      {
        'contact-face': 'change',
        'eraser-force': 'hold',
        'soft-material': 'hold',
        'dent-depth': 'measure',
      },
    ),
    conditions: singleSelectTask(
      'quantityCompare',
      [
        { id: 'half-pressure', text: '圧力は半分になる。' },
        { id: 'same-pressure', text: '圧力は変わらない。' },
        { id: 'double-pressure', text: '圧力は2倍になる。' },
        { id: 'quadruple-pressure', text: '圧力は4倍になる。' },
      ],
      'double-pressure',
    ),
    transfer: singleSelectTask(
      'quantityCompare',
      [
        { id: 'a-larger', text: 'Aの圧力のほうが大きい。' },
        { id: 'b-larger', text: 'Bの圧力のほうが大きい。' },
        { id: 'same-size', text: 'AとBの圧力は同じ。' },
      ],
      'b-larger',
    ),
  },

  buoyancy: {
    foundation: classifyTask(
      'experimentPlan',
      [
        { id: 'clay-shape', text: '油粘土を球から舟へ変える形' },
        { id: 'clay-mass', text: '油粘土の量と重さ' },
        { id: 'same-water', text: '入れる液体' },
        { id: 'float-result', text: '浮くか沈むか' },
      ],
      [
        { id: 'change', label: '変える' },
        { id: 'hold', label: 'そろえる' },
        { id: 'measure', label: '観察する' },
      ],
      {
        'clay-shape': 'change',
        'clay-mass': 'hold',
        'same-water': 'hold',
        'float-result': 'measure',
      },
    ),
    conditions: singleSelectTask(
      'quantityCompare',
      [
        { id: 'water-larger', text: '水中のほうが大きな浮力を受ける。' },
        { id: 'oil-larger', text: '油中のほうが大きな浮力を受ける。' },
        { id: 'same-buoyancy', text: 'どちらでも同じ浮力を受ける。' },
      ],
      'water-larger',
    ),
    transfer: classifyTask(
      'conditionClassify',
      [
        { id: 'top-pressure', text: '物体上面での液体の圧力' },
        { id: 'bottom-pressure', text: '物体下面での液体の圧力' },
        { id: 'displaced-volume', text: '物体が押しのける液体の体積' },
        { id: 'buoyant-force', text: '物体が受ける浮力' },
      ],
      [
        { id: 'depth-increase', label: '深くすると大きくなる' },
        { id: 'depth-steady', label: '深さだけでは変わらない' },
      ],
      {
        'top-pressure': 'depth-increase',
        'bottom-pressure': 'depth-increase',
        'displaced-volume': 'depth-steady',
        'buoyant-force': 'depth-steady',
      },
    ),
  },

  currentMagneticField: {
    foundation: sequenceTask(
      'experimentPlan',
      [
        { id: 'reverse-current', text: '電池の向きだけを逆にし、再び短時間通電する。' },
        { id: 'baseline', text: '電流を流さないときの方位磁針の向きを記録する。' },
        { id: 'compare-deflection', text: '基準から振れた側を、反転の前後で比べる。' },
        { id: 'first-current', text: '最初の向きで短時間通電し、針の振れを記録する。' },
      ],
      ['baseline', 'first-current', 'reverse-current', 'compare-deflection'],
    ),
    conditions: singleSelectTask(
      'forceDirection',
      [
        { id: 'same-deflection', text: '電流なしの基準から、同じ側へ振れる。' },
        { id: 'fixed-north', text: '通電しても振れず、常に北だけを指す。' },
        { id: 'opposite-deflection', text: '電流なしの基準から、反対側へ振れる。' },
      ],
      'opposite-deflection',
    ),
    transfer: classifyTask(
      'experimentPlan',
      [
        { id: 'current-size', text: 'コイルを流れる電流の大きさ' },
        { id: 'coil-setup', text: 'コイルの形・巻き数・鉄心' },
        { id: 'needle-position', text: '方位磁針の位置と向き' },
        { id: 'needle-deflection', text: '方位磁針の振れの大きさ' },
      ],
      [
        { id: 'change', label: '変える' },
        { id: 'hold', label: 'そろえる' },
        { id: 'measure', label: '測る' },
      ],
      {
        'current-size': 'change',
        'coil-setup': 'hold',
        'needle-position': 'hold',
        'needle-deflection': 'measure',
      },
    ),
  },

  magneticForce: {
    foundation: classifyTask(
      'forceDirection',
      [
        { id: 'reverse-current', text: '元の配置から電流だけを逆にする。' },
        { id: 'reverse-field', text: '元の配置から磁界だけを逆にする。' },
        { id: 'reverse-both', text: '元の配置から電流と磁界を両方逆にする。' },
      ],
      [
        { id: 'force-flips', label: '力は元と反対向き' },
        { id: 'force-restores', label: '力は元と同じ向き' },
      ],
      {
        'reverse-current': 'force-flips',
        'reverse-field': 'force-flips',
        'reverse-both': 'force-restores',
      },
    ),
    conditions: classifyTask(
      'conditionClassify',
      [
        { id: 'angle-ninety', text: '電流と磁界が90度で交わる。' },
        { id: 'angle-middle', text: '電流と磁界が0度と90度の間で交わる。' },
        { id: 'angle-parallel', text: '電流と磁界が平行になる。' },
      ],
      [
        { id: 'force-zero', label: '力はゼロ' },
        { id: 'force-maximum', label: '力は最大' },
        { id: 'force-between', label: '力は最大とゼロの間' },
      ],
      {
        'angle-ninety': 'force-maximum',
        'angle-middle': 'force-between',
        'angle-parallel': 'force-zero',
      },
    ),
    transfer: sequenceTask(
      'causalOrder',
      [
        { id: 'coil-turns', text: 'コイル全体が回転する。' },
        { id: 'opposite-forces', text: '向かい合う2辺が反対向きの力を受ける。' },
        { id: 'turning-effect', text: '異なる位置の2力が、回す作用をつくる。' },
      ],
      ['opposite-forces', 'turning-effect', 'coil-turns'],
    ),
  },

  electromagneticInduction: {
    foundation: sequenceTask(
      'causalOrder',
      [
        { id: 'magnet-stops', text: '磁石を止めると、磁束の変化がなくなり針はゼロへ戻る。' },
        { id: 'magnet-leaves', text: 'N極を抜くと、針は入れたときと反対へ振れる。' },
        { id: 'magnet-enters', text: 'N極を入れると磁束が変化し、針が一方へ振れる。' },
      ],
      ['magnet-enters', 'magnet-stops', 'magnet-leaves'],
    ),
    conditions: classifyTask(
      'conditionClassify',
      [
        { id: 'closed-voltage', text: '磁束が変化する閉回路の誘導電圧' },
        { id: 'closed-current', text: '磁束が変化する閉回路の誘導電流' },
        { id: 'open-voltage', text: '磁束が変化する開回路の誘導電圧' },
        { id: 'open-current', text: '磁束が変化する開回路の連続した誘導電流' },
      ],
      [
        { id: 'occurs', label: '生じる' },
        { id: 'not-continuous', label: '生じない' },
      ],
      {
        'closed-voltage': 'occurs',
        'closed-current': 'occurs',
        'open-voltage': 'occurs',
        'open-current': 'not-continuous',
      },
    ),
    transfer: classifyTask(
      'experimentPlan',
      [
        { id: 'magnet-speed', text: '磁石をコイルへ入れる速さ' },
        { id: 'magnet-range', text: '磁石の種類・向き・動かす範囲' },
        { id: 'circuit-setup', text: 'コイル・閉回路・回路全体の抵抗' },
        { id: 'meter-deflection', text: '検流計の振れの大きさ' },
      ],
      [
        { id: 'change', label: '変える' },
        { id: 'hold', label: 'そろえる' },
        { id: 'measure', label: '測る' },
      ],
      {
        'magnet-speed': 'change',
        'magnet-range': 'hold',
        'circuit-setup': 'hold',
        'meter-deflection': 'measure',
      },
    ),
  },
}

const ANSWER_SIGNALING_ID =
  /(^|[-_])(correct|incorrect|right|wrong|answer|solution|true|false|yes|no)(?=$|[-_])/i

/** 公開前に、構造化課題1件のwire契約を検証する。 */
export function validateCognitiveTask(task: CognitiveTask): string[] {
  const problems: string[] = []
  if (task.needCode == null || !/^science\.[A-Za-z][A-Za-z0-9]{0,63}\.(foundation|conditions|transfer)$/.test(task.needCode)) {
    problems.push(`${task.kind}: 安定した一般化needCodeが無い`)
  }
  const minimumItems = task.kind === 'singleSelect' ? 2 : 3
  if (task.items.length < minimumItems || task.items.length > 4) {
    problems.push(`${task.kind}: item数は${minimumItems}〜4件`)
  }
  const itemIds = task.items.map((item) => item.id)
  if (new Set(itemIds).size !== itemIds.length) {
    problems.push(`${task.kind}: item IDが重複`)
  }
  for (const item of task.items) {
    if (item.id.trim().length === 0 || item.text.trim().length === 0) {
      problems.push(`${task.kind}: 空のitem IDまたは本文`)
    }
    if (ANSWER_SIGNALING_ID.test(item.id)) {
      problems.push(`${task.kind}/${item.id}: IDが正誤を示唆`)
    }
  }

  if (task.kind === 'singleSelect') {
    if (!itemIds.includes(task.solution.selectedItemId)) {
      problems.push('singleSelect: selectedItemIdがitemsに無い')
    }
    return problems
  }

  if (task.kind === 'sequence') {
    const order = task.solution.orderedItemIds
    if (
      order.length !== itemIds.length
      || new Set(order).size !== itemIds.length
      || order.some((id) => !itemIds.includes(id))
    ) {
      problems.push('sequence: solutionが全itemをちょうど1回使っていない')
    }
    if (
      order.length === itemIds.length
      && order.every((id, index) => id === itemIds[index])
    ) {
      problems.push('sequence: 提示順が正答順を示している')
    }
    return problems
  }

  if (task.targets.length < 2 || task.targets.length > 3) {
    problems.push('classify: target数は2〜3件')
  }
  const targetIds = task.targets.map((target) => target.id)
  if (new Set(targetIds).size !== targetIds.length) {
    problems.push('classify: target IDが重複')
  }
  for (const target of task.targets) {
    if (target.id.trim().length === 0 || target.label.trim().length === 0) {
      problems.push('classify: 空のtarget IDまたはlabel')
    }
    if (ANSWER_SIGNALING_ID.test(target.id)) {
      problems.push(`classify/${target.id}: IDが正誤を示唆`)
    }
  }
  const assignments = task.solution.targetByItemId
  const assignmentKeys = Object.keys(assignments)
  if (
    assignmentKeys.length !== itemIds.length
    || new Set(assignmentKeys).size !== itemIds.length
    || assignmentKeys.some((id) => !itemIds.includes(id))
    || itemIds.some((id) => !targetIds.includes(assignments[id] ?? ''))
  ) {
    problems.push('classify: solutionが全itemを有効なtargetへちょうど1回割り当てていない')
  }
  if (
    targetIds.length > 0
    && itemIds.every(
      (id, index) => assignments[id] === targetIds[index % targetIds.length],
    )
  ) {
    problems.push('classify: itemとtargetの提示順だけで割当が決まる')
  }
  return problems
}

export type LocalPracticeSectionSource = {
  conceptKey: string
  tryIt: string
  localCheckpoint: LocalCheckpoint
}

/** 文言・選択肢ID・翻訳に依存しない、concept×認知段階の公開need正本。 */
export function sciencePracticeNeedCode(
  conceptKey: string,
  stage: LocalPracticeStage,
): string {
  if (!/^[A-Za-z][A-Za-z0-9]{0,63}$/.test(conceptKey)) {
    throw new Error(`needCodeを作れないconceptKey: ${conceptKey}`)
  }
  return `science.${conceptKey}.${stage}`
}

/** 回答本文を含まない、concept×stage×Listening課題の公開need正本。 */
export function scienceListeningNeedCodes(
  conceptKey: string,
  stage: LocalPracticeStage,
): LocalPracticeVariant['listeningNeedCodes'] {
  if (!/^[A-Za-z][A-Za-z0-9]{0,63}$/.test(conceptKey)) {
    throw new Error(`Listening needCodeを作れないconceptKey: ${conceptKey}`)
  }
  const prefix = `science.${conceptKey}.listening.${stage}`
  return {
    transcript: `${prefix}.transcript`,
    meaning: `${prefix}.meaning`,
  }
}

/** 1周目の既存checkpointと、2・3周目を一つの公開配列へ組み立てる。 */
export function localPracticeVariantsFor(
  section: LocalPracticeSectionSource,
): LocalPracticeVariant[] {
  const plan = PLANS[section.conceptKey]
  const tasks = COGNITIVE_TASKS[section.conceptKey]
  if (!plan || !tasks) return []

  return [
    {
      stage: 'foundation',
      ...plan.foundation,
      transferPrompt: section.tryIt,
      cognitiveTask: cloneCognitiveTask(
        tasks.foundation,
        sciencePracticeNeedCode(section.conceptKey, 'foundation'),
      ),
      checkpoint: cloneCheckpoint(
        section.localCheckpoint,
        sciencePracticeNeedCode(section.conceptKey, 'foundation'),
      ),
      listeningNeedCodes: scienceListeningNeedCodes(
        section.conceptKey,
        'foundation',
      ),
    },
    {
      stage: 'conditions',
      ...plan.conditions,
      cognitiveTask: cloneCognitiveTask(
        tasks.conditions,
        sciencePracticeNeedCode(section.conceptKey, 'conditions'),
      ),
      checkpoint: cloneCheckpoint(
        plan.conditions.checkpoint,
        sciencePracticeNeedCode(section.conceptKey, 'conditions'),
      ),
      listeningNeedCodes: scienceListeningNeedCodes(
        section.conceptKey,
        'conditions',
      ),
    },
    {
      stage: 'transfer',
      ...plan.transfer,
      cognitiveTask: cloneCognitiveTask(
        tasks.transfer,
        sciencePracticeNeedCode(section.conceptKey, 'transfer'),
      ),
      checkpoint: cloneCheckpoint(
        plan.transfer.checkpoint,
        sciencePracticeNeedCode(section.conceptKey, 'transfer'),
      ),
      listeningNeedCodes: scienceListeningNeedCodes(
        section.conceptKey,
        'transfer',
      ),
    },
  ]
}

function cloneCognitiveTask(task: CognitiveTask, needCode: string): CognitiveTask {
  if (task.kind === 'singleSelect') {
    return {
      ...task,
      needCode,
      items: task.items.map((item) => ({ ...item })),
      solution: { ...task.solution },
    }
  }
  if (task.kind === 'sequence') {
    return {
      ...task,
      needCode,
      items: task.items.map((item) => ({ ...item })),
      solution: { orderedItemIds: [...task.solution.orderedItemIds] },
    }
  }
  return {
    ...task,
    needCode,
    items: task.items.map((item) => ({ ...item })),
    targets: task.targets.map((target) => ({ ...target })),
    solution: { targetByItemId: { ...task.solution.targetByItemId } },
  }
}

function cloneCheckpoint(
  checkpoint: LocalCheckpoint,
  needCode: string,
): LocalCheckpoint {
  return {
    ...checkpoint,
    options: checkpoint.options.map((option) => {
      if (option.id !== checkpoint.correctOptionId) {
        return { ...option, needCode }
      }
      const { needCode: _, ...withoutNeed } = option
      return withoutNeed
    }),
  }
}
