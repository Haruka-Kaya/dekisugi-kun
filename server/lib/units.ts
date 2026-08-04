import { MISCONCEPTIONS } from './misconceptions.js'

/**
 * 単元と、その中で生徒に説明してもらいたい概念。
 *
 * 概念の粒度は**誤概念カタログに合わせてある**。
 * 「誤概念を1つ誘発できる単位」より細かく割っても、観測する手段が無い。
 *
 * > 学習指導要領のどの項目に対応するかは**未確認**。
 * > いまは FCI 由来のカタログから逆算した区切りで、教材本体を作るときに突き合わせる。
 */

export type Concept = {
  key: string
  label: string
  /** 何を説明できたら「説明できた」とするか。ディレクターへの説明文 */
  intent: string
  /** 単元の中での重み。質問の優先順位と充足度の計算に使う */
  weight: number
}

export type Unit = {
  id: string
  title: string
  /** 生徒に最初に見せる導入。**説明フェーズでは画面から隠す**（C2） */
  brief: string
  concepts: Concept[]
}

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
          '力がはたらかなくても動き続けること。'
          + '「動いている＝力がはたらいている」ではないと言えて完全',
        weight: 3,
      },
      {
        key: 'friction',
        label: '止まる理由',
        intent:
          '止まるのは摩擦や空気抵抗という力がはたらくから。'
          + '**止まる原因を名前で挙げられて**完全',
        weight: 2,
      },
      {
        key: 'throwUp',
        label: '投げ上げた物体にはたらく力',
        intent:
          '上昇中も最高点でも下降中も、下向きの重力がはたらき続けていること。'
          + '**最高点でも力はゼロにならない**と言えて完全',
        weight: 2,
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
          + '**重さや強さによらない**と言えて完全',
        weight: 3,
      },
      {
        key: 'balance',
        label: 'つり合いと運動',
        intent:
          'つり合っていても等速で動き続けることはある。'
          + '**「つり合い＝静止」ではない**と言えて完全',
        weight: 3,
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
          + '**物体の重さではなく水中の体積で決まる**と言えて完全',
        weight: 3,
      },
    ],
  },
]

const BY_ID = new Map(UNITS.map((u) => [u.id, u]))

export function unitById(id: string): Unit | undefined {
  return BY_ID.get(id)
}

/**
 * カタログの整合。**起動時に落とす。**
 * 概念に対応する誤概念が無い＝その概念は誘発できず、観測手段が無いまま出荷される。
 */
export function validateCatalog(): string[] {
  const problems: string[] = []
  const conceptKeys = new Set(UNITS.flatMap((u) => u.concepts.map((c) => c.key)))

  for (const u of UNITS) {
    const seen = new Set<string>()
    for (const c of u.concepts) {
      if (seen.has(c.key)) problems.push(`${u.id}: 概念キーが重複 ${c.key}`)
      seen.add(c.key)
      if (!MISCONCEPTIONS.some((m) => m.conceptKey === c.key)) {
        problems.push(`${u.id}/${c.key}: 対応する誤概念が無い（誘発できない）`)
      }
    }
  }
  for (const m of MISCONCEPTIONS) {
    if (!conceptKeys.has(m.conceptKey)) {
      problems.push(`${m.id}: 存在しない概念キー ${m.conceptKey}`)
    }
  }
  const ids = MISCONCEPTIONS.map((m) => m.id)
  if (new Set(ids).size !== ids.length) problems.push('誤概念IDが重複している')

  return problems
}
