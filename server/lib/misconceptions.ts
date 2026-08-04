/**
 * 誤概念カタログ。**デキすぎ君の心臓部。**
 *
 * ## なぜカタログを持つのか
 *
 * 「生徒の説明が正しいか」を LLM に採点させる設計にはしない。
 * 自由記述の正誤判定は当てにならず、しかも外すのは
 * **だいたい分かっているが説明が不完全な層**（＝主要ターゲットそのもの）。
 *
 * 代わりに、**既知の誤概念を AI 自身が口にして、生徒が訂正するかを見る**。
 * 判定の対象が「この自由記述は正しいか」から
 * 「いま口にした X という特定の主張を、生徒は否定したか」に狭まる。
 *
 * > これは「LLM が判定しない」設計ではない。**判定の的が小さくなる**設計。
 * > 実生徒データでの精度はまだ測れていない（アンケート回収待ち）。
 * > だから [ProbeResult] に `unclear` を持たせ、**迷ったら unclear に倒す**。
 *
 * ## 文言を LLM に作らせない
 *
 * [lure] は固定文。ディレクターが選ぶのは「どれを言うか」だけで、
 * 何と言うかは決めさせない。毎回違う言い方をされると、
 * 訂正されたかどうかの観測が条件のそろわない別々の試行になる。
 *
 * 出典は Force Concept Inventory (Hestenes, Wells & Swackhamer 1992) 系列で
 * 繰り返し報告されている誤概念のうち、中学理科の範囲に収まるもの。
 * FCI の誤答選択肢はそのまま誤概念のカタログになっている。
 */

export type Misconception = {
  id: string
  /** どの概念についての誤概念か（[Concept.key] と対応） */
  conceptKey: string
  /** 正しい理解。AI が最後に補完するときの中身 */
  correct: string
  /** 誤った理解。記録と復習の表示に使う */
  misconception: string
  /**
   * AI 生徒が口にする**固定のセリフ**。
   * 断定せず「〜ってこと？」と確認する形にしてある。
   * 訂正もしやすく、同意もしやすい ——
   * **どちらにも倒れる余地を残さないと、観測が誘導になる。**
   */
  lure: string
}

export const MISCONCEPTIONS: Misconception[] = [
  {
    id: 'M01',
    conceptKey: 'fall',
    correct:
      '空気の抵抗が無視できるとき、落下の速さは物体の重さによらない。同じ高さから同時に落とせば同時に着く。',
    misconception: '重い物体ほど速く落ちる。',
    lure: 'えっと、じゃあ重いものの方が速く落ちるってこと？',
  },
  {
    id: 'M02',
    conceptKey: 'inertia',
    correct:
      '力がはたらいていなくても、動いている物体はそのまま等速で動き続ける（慣性の法則）。',
    misconception: '動いている物体には、動く向きに力がはたらき続けている。',
    lure: '動いてるってことは、ずっと前向きに力がかかってるんだよね？',
  },
  {
    id: 'M03',
    conceptKey: 'friction',
    correct:
      '物体が止まるのは摩擦や空気抵抗などの力がはたらくから。何もはたらかなければ止まらない。',
    misconception: '物体はほうっておけば自然に止まる。止まるのが本来の状態である。',
    lure: 'ものって、ほっとけば自然に止まるものなんじゃないの？',
  },
  {
    id: 'M04',
    conceptKey: 'actionReaction',
    correct: '作用と反作用は、重さや大きさによらず必ず同じ大きさで、向きが反対。',
    misconception: '重い物体（強い方）の方が大きい力を出している。',
    lure: 'えっと、トラックと自転車がぶつかったら、トラックの方が大きい力を出してるんでしょ？',
  },
  {
    id: 'M05',
    conceptKey: 'balance',
    correct:
      '力がつり合っているとき、物体は静止し続けるか等速直線運動を続ける。静止しているとは限らない。',
    misconception: '力がつり合っている物体は必ず静止している。',
    lure: '力がつり合ってるってことは、止まってるってことだよね？',
  },
  {
    id: 'M06',
    conceptKey: 'pressure',
    correct:
      '圧力は面を垂直に押す力を面積で割ったもの。同じ力でも面積が小さいほど圧力は大きい。',
    misconception: '押す力が同じなら圧力も同じ。面積は関係ない。',
    lure: '押す力が同じなら、面積が違っても圧力は同じだよね？',
  },
  {
    id: 'M07',
    conceptKey: 'buoyancy',
    correct:
      '浮力の大きさは物体が押しのけた液体の重さに等しく、物体の重さそのものではなく水中の体積で決まる。',
    misconception: '重い物体ほど大きな浮力を受ける。',
    lure: '重いものほど浮力も大きくなるんだよね？',
  },
  {
    id: 'M08',
    conceptKey: 'throwUp',
    correct:
      '投げ上げた物体には、上昇中も最高点でも下降中も、常に下向きの重力がはたらいている。',
    misconception: '投げ上げた物体には、上昇中は上向きの力がはたらいている。最高点では力がゼロになる。',
    lure: '上に投げてる間は、上向きの力がはたらいてるってことだよね？',
  },
]

const BY_ID = new Map(MISCONCEPTIONS.map((m) => [m.id, m]))

export function misconceptionById(id: string): Misconception | undefined {
  return BY_ID.get(id)
}

export function misconceptionsFor(conceptKey: string): Misconception[] {
  return MISCONCEPTIONS.filter((m) => m.conceptKey === conceptKey)
}
