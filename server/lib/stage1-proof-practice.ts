import type {
  CognitiveTaskPlan,
  LocalPracticePlan,
} from './local-practice-variants.js'

/** Stage 1 proof sliceの3段階課題。既存11概念の正本とは別moduleで所有する。 */
export const STAGE1_PROOF_PRACTICE_PLANS: Readonly<
  Record<string, LocalPracticePlan>
> = {
  density: {
    foundation: {
      recallPrompt:
        '密度とはどのような量か、質量と体積を使い、同じ物質の量を変えた場合まで説明してください。',
      reasoningPrompt:
        '同じ材質の物体を半分にしても密度が変わらない理由を、分子と分母の変化として足してください。',
      expectedOutcome:
        '同じ体積を入れた2個の容器では、水を入れた容器のほうが食用油を入れた容器より重く感じられます。',
      expectedReason:
        '容器と中身の体積をそろえた比較では、質量の違いが単位体積当たりの質量の違いを表します。一般的な室温では水の密度が食用油より大きいためです。',
    },
    conditions: {
      recallPrompt:
        '異なる物質の密度を公平に比べるため、最低限どの2つの量を測る必要があるか説明してください。',
      reasoningPrompt:
        '水位変化で体積を測る方法を使えない物質を一例挙げ、なぜ別の方法が必要かを足してください。',
      transferPrompt:
        '質量54 g、体積20 cm³の金属片Aと、質量78 g、体積30 cm³の金属片Bがあります。どちらの密度が大きいか、計算する量をそろえて比べてください。',
      expectedOutcome:
        'Aは2.7 g/cm³、Bは2.6 g/cm³なので、金属片Aの密度がわずかに大きいと分かります。',
      expectedReason:
        '質量の大小だけではなく、それぞれ質量を体積で割り、同じ単位の単位体積当たりの質量として比較する必要があります。',
      checkpoint: {
        lure: '質量が78 gのBは54 gのAより重いので、Bの密度のほうが大きい。',
        options: [
          {
            id: 'mass-ranking',
            text: '質量が大きい順が、そのまま密度の大きい順になる。',
            hint: '2つの金属片は体積も違います。単位体積当たりへそろえます。',
          },
          {
            id: 'normalize-volume',
            text: 'AとBで質量を体積で割って比べると、Aの密度のほうが大きい。',
          },
          {
            id: 'volume-ranking',
            text: '体積が大きいBの密度が大きく、質量は計算に要らない。',
            hint: '密度の式では、体積だけでなく質量も必要です。',
          },
        ],
        correctOptionId: 'normalize-volume',
        explanation:
          'Aの密度は54÷20=2.7 g/cm³、Bは78÷30=2.6 g/cm³です。全体の質量が小さいAでも、単位体積当たりではAのほうが大きくなります。',
      },
    },
    transfer: {
      recallPrompt:
        '形が違う2個の物体が同じ物質かを密度から調べる手順を、測定と計算に分けて説明してください。',
      reasoningPrompt:
        '計算した密度が資料値と少し違ったとき、すぐ別物質と断定せず確認する条件や誤差を一つ挙げてください。',
      transferPrompt:
        '同じ金属板から切ったとされる大きさの違う試料PとQを調べます。Pは質量27 g・体積10 cm³、Qは質量54 g・体積20 cm³でした。結果から言えることと、まだ断定できないことを書いてください。',
      expectedOutcome:
        'PとQはいずれも2.7 g/cm³となり、同じ密度をもつという結果です。大きさが2倍でも密度は同じです。',
      expectedReason:
        '質量と体積が同じ割合で変化しています。ただし密度が一致する別の物質や測定誤差もあり得るため、この結果だけで物質名や同一の板だったことまでは断定できません。',
      checkpoint: {
        lure: '2個の試料の密度が同じなら、必ず同じ物質で、同じ板から切ったと証明できる。',
        options: [
          {
            id: 'identity-certain',
            text: '密度が一致すれば、由来まで含めて必ず同じ物質だと証明できる。',
            hint: '密度が同じ別物質や、測定値の丸め・誤差がないかを考えます。',
          },
          {
            id: 'size-decides',
            text: '大きさが違うので、密度が同じでも同じ物質ではあり得ない。',
            hint: '同じ物質の量を変えたとき、質量と体積の比がどうなるかを確認します。',
          },
          {
            id: 'evidence-not-proof',
            text: '同じ物質という根拠の一つにはなるが、密度だけで由来まで断定はできない。',
          },
        ],
        correctOptionId: 'evidence-not-proof',
        explanation:
          '密度の一致は同じ物質を支持する証拠ですが、一意の識別子ではありません。測定誤差や密度の近い物質も考え、他の性質と合わせます。',
      },
    },
  },

  cells: {
    foundation: {
      recallPrompt:
        '植物と動物の細胞に共通する基本的なつくりと、植物に特徴的なつくりを分けて説明してください。',
      reasoningPrompt:
        '葉緑体が見えないことだけで動物細胞と決められない理由を、植物の組織の違いから足してください。',
      expectedOutcome:
        '2枚の画像には細胞を区切る境界や内部のつくりという共通点があり、植物の画像では細胞壁による規則的な境界などの特徴を整理できます。',
      expectedReason:
        '植物と動物の細胞は基本構造を共有しつつ、細胞壁などに相違があります。画像の倍率、染色、採取部位で見え方が変わるため、複数の特徴を使います。',
    },
    conditions: {
      recallPrompt:
        '顕微鏡画像で構造が見えないとき、「その構造が存在しない」とすぐ言えない理由を説明してください。',
      reasoningPrompt:
        '植物細胞と動物細胞を比べる観察で、倍率や染色などの条件をそろえる必要を足してください。',
      transferPrompt:
        '画像Aには細胞壁が見え、葉緑体は見えません。画像Bには細胞壁が見えず、核が染色されています。AとBについて、言えることと断定できないことを分けてください。',
      expectedOutcome:
        'Aは植物由来を支持する細胞壁が見えますが、葉緑体がないだけで植物ではないとは言えません。Bは動物細胞の可能性がありますが、画像条件と採取部位の確認が必要です。',
      expectedReason:
        '細胞壁は植物細胞に特徴的ですが、葉緑体は全ての植物細胞にあるわけではありません。また見えないことは倍率や染色の条件でも起こるためです。',
      checkpoint: {
        lure: '顕微鏡画像で核が見えなければ、その細胞には核が存在しないと断定できる。',
        options: [
          {
            id: 'absence-certain',
            text: '画像に写っていない構造は、その細胞には存在しない。',
            hint: '倍率、焦点、切片の位置、染色によって見え方が変わることを考えます。',
          },
          {
            id: 'all-have-visible',
            text: 'どの画像でも全構造が同じ明るさで見えるので、見落としは起こらない。',
            hint: '顕微鏡観察で染色を行う目的や、焦点を調整する理由を考えます。',
          },
          {
            id: 'check-observation',
            text: '見えない理由が観察条件か構造の違いかを、倍率・染色・採取部位から確かめる。',
          },
        ],
        correctOptionId: 'check-observation',
        explanation:
          '画像に見えないことだけでは存在しないと断定できません。観察条件と試料の部位を確かめ、複数の画像や特徴から判断します。',
      },
    },
    transfer: {
      recallPrompt:
        '細胞、組織、器官、個体の関係を、小さいつくりから大きい働きへ順に説明してください。',
      reasoningPrompt:
        '多細胞生物で、全ての細胞が同じ形や働きではないことが体全体の働きへどう役立つかを足してください。',
      transferPrompt:
        '葉の断面画像には表面を覆う細胞と、葉緑体が多い内部の細胞が見えます。同じ個体の細胞なのに見え方が違う理由と、共通して言えることを説明してください。',
      expectedOutcome:
        '表面と内部では細胞の形や葉緑体の見え方が異なり、場所に応じた役割の違いが見られます。一方、どちらも植物体をつくる細胞です。',
      expectedReason:
        '多細胞生物では細胞が役割に応じて特徴をもち、組織をつくります。同じ植物でも全細胞が同じ構造の見え方をするわけではありません。',
      checkpoint: {
        lure: '同じ個体の細胞なら、場所や役割が違っても形と含まれる構造はすべて同じである。',
        options: [
          {
            id: 'specialized-cells',
            text: '同じ個体でも役割に応じて細胞の形や目立つ構造が異なり、それぞれが組織をつくる。',
          },
          {
            id: 'identical-cells',
            text: '同じ個体をつくる細胞は、どの場所でも全く同じ形と働きをもつ。',
            hint: '葉の表面と内部、根と葉など、場所ごとの働きの違いを考えます。',
          },
          {
            id: 'different-organisms',
            text: '形が違う細胞は、同じ個体の中には存在せず、必ず別の生物である。',
            hint: '一つの多細胞生物が、複数種類の組織や器官をもつことを思い出します。',
          },
        ],
        correctOptionId: 'specialized-cells',
        explanation:
          '多細胞生物では、細胞が場所と役割に応じた特徴をもち、組織や器官をつくります。同じ個体でも全細胞が同じ見え方ではありません。',
      },
    },
  },

  humidityClouds: {
    foundation: {
      recallPrompt:
        '水蒸気と雲をつくる水滴の状態の違いを、見えるかどうかも含めて説明してください。',
      reasoningPrompt:
        '冷たいコップの外側に水滴ができる理由を、露点と凝結を使って足してください。',
      expectedOutcome:
        '冷水を入れたコップの外側には水滴が付き、室温のコップには同じ時間ではほとんど付きません。',
      expectedReason:
        '冷たい表面に触れた周囲の空気が露点まで冷え、空気中の見えない水蒸気が凝結したためです。水滴はコップの内側から通り抜けたものではありません。',
    },
    conditions: {
      recallPrompt:
        '水蒸気量がほぼ同じ空気を冷やすと湿度が上がる理由を、飽和水蒸気量の変化から説明してください。',
      reasoningPrompt:
        '同じ気温でも湿度が違えば、露点へ達するまでに必要な冷却が変わることを足してください。',
      transferPrompt:
        '同じ部屋で、気温20℃・湿度80%の空気Aと、気温20℃・湿度40%の空気Bを同じ速さで冷やします。どちらが先に凝結し始めると予想しますか。',
      expectedOutcome:
        '空気Aのほうが少ない温度低下で飽和し、先に露点へ達して凝結し始めます。',
      expectedReason:
        '同じ気温なら、湿度80%のAはその温度で含める最大量により近い水蒸気を含んでいるため、冷却による飽和水蒸気量の低下が小さくても飽和へ達します。',
      checkpoint: {
        lure: '同じ気温なら、湿度40%の空気のほうが乾いて軽いので、先に雲ができる。',
        options: [
          {
            id: 'nearer-saturation',
            text: '湿度80%の空気のほうが飽和に近く、少ない冷却で先に凝結する。',
          },
          {
            id: 'drier-first',
            text: '湿度40%の空気のほうが水蒸気を受け入れやすいので、先に凝結する。',
            hint: '凝結は水蒸気をさらに受け入れるときではなく、含み切れなくなったときに始まります。',
          },
          {
            id: 'temperature-only',
            text: '開始時の気温が同じなら、湿度に関係なく同時に凝結する。',
            hint: '露点は空気中に実際に含まれる水蒸気量でも変わります。',
          },
        ],
        correctOptionId: 'nearer-saturation',
        explanation:
          '同じ気温では湿度が高い空気ほど飽和に近く、より少ない冷却で露点に達します。湿度40%の空気はさらに冷やす必要があります。',
      },
    },
    transfer: {
      recallPrompt:
        '空気の上昇から雲ができるまでを、気圧、体積、気温、凝結の順序で説明してください。',
      reasoningPrompt:
        '空気が上昇しても必ず雲になるわけではない理由を、水蒸気量と露点の条件から足してください。',
      transferPrompt:
        '湿った空気が山の斜面に沿って上昇しています。上昇前後で水蒸気を外から加えていないとき、雲ができ始めるまでの変化を予想してください。',
      expectedOutcome:
        '上昇した空気は周囲の気圧低下で膨張して冷え、露点に達すると水蒸気が凝結して雲粒ができ始めます。',
      expectedReason:
        '気温低下で飽和水蒸気量が小さくなり、実際の水蒸気量に対して飽和へ達するためです。十分な水蒸気がない場合は、同じ高さまで上昇しても凝結しないことがあります。',
      checkpoint: {
        lure: '空気が山を上ると地面に近づいて押し縮められるので、温まりながら雲になる。',
        options: [
          {
            id: 'compressed-warming',
            text: '上昇するほど気圧が高くなり、空気が縮んで温まることで凝結する。',
            hint: '高度が上がったとき、周囲の気圧が高くなるか低くなるかを確認します。',
          },
          {
            id: 'expansion-cooling',
            text: '上昇して周囲の気圧が下がると空気が膨張して冷え、露点で凝結する。',
          },
          {
            id: 'vapor-turns-white',
            text: '上昇しても温度は変わらず、水蒸気という気体が集まるだけで白くなる。',
            hint: '雲として見える粒の状態と、上昇する空気の温度変化を分けます。',
          },
        ],
        correctOptionId: 'expansion-cooling',
        explanation:
          '上空ほど周囲の気圧が低いため、上昇する空気は膨張して冷えます。露点へ達すると水蒸気が凝結し、水滴や氷の粒ができます。',
      },
    },
  },

  strataRelativeAge: {
    foundation: {
      recallPrompt:
        '逆転していない地層の上下から、どちらが先に堆積したかを判断する規則を説明してください。',
      reasoningPrompt:
        '地層を横切る線と、その線に切られていない上の層から、出来事の順をどう読めるか足してください。',
      expectedOutcome:
        '青、黄、白の層が下から順に堆積した後、3層を切る線の出来事が起こり、最後に線で切られていない緑の層が堆積したと読めます。',
      expectedReason:
        '下の層ほど先に堆積し、複数の層を切る出来事は切られた層より後です。その線を覆い切られていない緑の層は、線の出来事より後です。',
    },
    conditions: {
      recallPrompt:
        '地層の上下関係から年代を読むとき、地層が逆転していない条件を確認する理由を説明してください。',
      reasoningPrompt:
        '断層と地層の前後関係を「切る側」と「切られる側」に分けて足してください。',
      transferPrompt:
        '砂岩層A、泥岩層B、火山灰層Cを一本の断層Fが切り、その上を地層Dが断層に切られず覆っています。A〜DとFの前後関係で確実に言えることを整理してください。',
      expectedOutcome:
        '断層FはA・B・Cが堆積した後に活動し、地層DはFの活動後に堆積したと分かります。A・B・C同士の順は上下配置の情報が必要です。',
      expectedReason:
        '切る関係からFは切られた3層より新しく、DがFを覆って切られていないことからDはFより新しいと読めます。記載のない上下関係までは推測しません。',
      checkpoint: {
        lure: '断層Fが地層Aを切っているなら、Fが先にあり、その上にAができた。',
        options: [
          {
            id: 'fault-first',
            text: '断層が先にでき、その割れ目の上へ切られた地層が堆積した。',
            hint: 'まだ存在しない地層を、先にできた断層が切れるかを考えます。',
          },
          {
            id: 'same-event',
            text: '切る側と切られる側は、必ず全く同時にできる。',
            hint: '一方が他方を横切る形が残るために、どちらが先に存在する必要があるかを見ます。',
          },
          {
            id: 'fault-after-layer',
            text: '地層Aが先にでき、その後の断層Fの活動がAを切った。',
          },
        ],
        correctOptionId: 'fault-after-layer',
        explanation:
          '断層が地層を切るには地層が先に存在する必要があります。そのため断層の活動は、切られた地層の堆積より後です。',
      },
    },
    transfer: {
      recallPrompt:
        '離れた地点の地層を対応させる手掛かりを、鍵層と化石から説明してください。',
      reasoningPrompt:
        '色や厚さが似るだけで同じ地層と断定できない理由と、複数の証拠を使う必要を足してください。',
      transferPrompt:
        '地点Pと離れた地点Qの柱状図に、同じ特徴をもつ薄い火山灰層があります。Pではその下に化石X、Qではその上に化石Yがあります。火山灰層を鍵層とした前後関係を説明してください。',
      expectedOutcome:
        '2地点の火山灰層を同時期の鍵層として対応させるなら、化石Xを含む層は火山灰より前、化石Yを含む層は火山灰より後に堆積したと推定できます。',
      expectedReason:
        '離れた地点でも同じ噴火由来の火山灰層は時間の目印になります。ただし鉱物組成や広がりなど、同じ鍵層である根拠も確かめる必要があります。',
      checkpoint: {
        lure: '離れた2地点で地層の色が同じなら、他の証拠がなくても必ず同じ時期の地層である。',
        options: [
          {
            id: 'color-guarantees',
            text: '色が一致すれば、距離や構成物に関係なく同じ層だと断定できる。',
            hint: '別の場所で似た色の砂や泥が異なる時期に堆積する可能性を考えます。',
          },
          {
            id: 'combine-evidence',
            text: '色だけでなく火山灰の特徴、化石、上下の順など複数の証拠で対応させる。',
          },
          {
            id: 'distance-forbids',
            text: '地点が離れていれば、同じ火山灰層が広がることはなく対応できない。',
            hint: '一度の噴火で火山灰が広い範囲へ降ることを、時間の目印として考えます。',
          },
        ],
        correctOptionId: 'combine-evidence',
        explanation:
          '色だけでは別時期の堆積物を区別できません。火山灰の鉱物などの特徴、化石、上下関係を合わせて鍵層を対応させます。',
      },
    },
  },
}

export const STAGE1_PROOF_COGNITIVE_TASKS: Readonly<
  Record<string, CognitiveTaskPlan>
> = {
  density: {
    foundation: {
      kind: 'classify',
      operation: 'quantityCompare',
      items: [
        { id: 'mass', text: '容器を含む全体の質量' },
        { id: 'volume', text: '容器に入れた液体の体積' },
        { id: 'material', text: '中身が水か食用油か' },
        { id: 'cap-color', text: 'ふたの色' },
      ],
      targets: [
        { id: 'measure', label: '測る・そろえる量' },
        { id: 'change', label: '比べる物質' },
        { id: 'irrelevant', label: '密度比較に使わない' },
      ],
      solution: {
        targetByItemId: {
          mass: 'measure',
          volume: 'measure',
          material: 'change',
          'cap-color': 'irrelevant',
        },
      },
    },
    conditions: {
      kind: 'singleSelect',
      operation: 'experimentPlan',
      items: [
        { id: 'both-quantities', text: '各試料の質量と体積を測り、質量÷体積を同じ単位で比べる。' },
        { id: 'mass-alone', text: '各試料の質量だけを測り、重い順に並べる。' },
        { id: 'volume-alone', text: '各試料の体積だけを測り、大きい順に並べる。' },
      ],
      solution: { selectedItemId: 'both-quantities' },
    },
    transfer: {
      kind: 'sequence',
      operation: 'causalOrder',
      items: [
        { id: 'compare', text: '同じ単位の密度としてPとQを比較する。' },
        { id: 'measure', text: 'PとQそれぞれの質量と体積を測る。' },
        { id: 'calculate', text: '各試料で質量を体積で割る。' },
      ],
      solution: { orderedItemIds: ['measure', 'calculate', 'compare'] },
    },
  },
  cells: {
    foundation: {
      kind: 'classify',
      operation: 'conditionClassify',
      items: [
        { id: 'cell-wall', text: '細胞壁' },
        { id: 'cell-membrane', text: '細胞膜' },
        { id: 'chloroplast', text: '光合成する細胞で見られる葉緑体' },
        { id: 'cytoplasm', text: '細胞質' },
      ],
      targets: [
        { id: 'shared', label: '植物と動物に共通' },
        { id: 'plant-feature', label: '植物に特徴的' },
      ],
      solution: {
        targetByItemId: {
          'cell-membrane': 'shared',
          'cell-wall': 'plant-feature',
          cytoplasm: 'shared',
          chloroplast: 'plant-feature',
        },
      },
    },
    conditions: {
      kind: 'sequence',
      operation: 'experimentPlan',
      items: [
        { id: 'compare-features', text: '共通点と相違点を複数の特徴から整理する。' },
        { id: 'check-source', text: '画像の倍率・染色・採取部位を確認する。' },
        { id: 'observe-image', text: '境界や内部の見える構造を記録する。' },
      ],
      solution: { orderedItemIds: ['check-source', 'observe-image', 'compare-features'] },
    },
    transfer: {
      kind: 'singleSelect',
      operation: 'experimentPlan',
      items: [
        { id: 'one-feature', text: '葉緑体の有無だけで、全ての細胞の由来を決める。' },
        { id: 'multiple-evidence', text: '細胞壁など複数の特徴と採取部位・観察条件を合わせて判断する。' },
        { id: 'shape-only', text: '丸いか四角いかだけで植物と動物を分ける。' },
      ],
      solution: { selectedItemId: 'multiple-evidence' },
    },
  },
  humidityClouds: {
    foundation: {
      kind: 'sequence',
      operation: 'causalOrder',
      items: [
        { id: 'droplets', text: '余分な水蒸気が凝結して水滴になる。' },
        { id: 'cool-air', text: 'コップに触れた周囲の空気が冷える。' },
        { id: 'reach-dew-point', text: '空気が露点へ達して飽和する。' },
      ],
      solution: { orderedItemIds: ['cool-air', 'reach-dew-point', 'droplets'] },
    },
    conditions: {
      kind: 'classify',
      operation: 'conditionClassify',
      items: [
        { id: 'air-a-humidity', text: '空気Aの開始時の湿度80%' },
        { id: 'air-b-humidity', text: '空気Bの開始時の湿度40%' },
        { id: 'start-temperature', text: '両方の開始時の気温20℃' },
        { id: 'cooling-rate', text: '冷やす速さ' },
      ],
      targets: [
        { id: 'different', label: '違う条件' },
        { id: 'same', label: 'そろえた条件' },
      ],
      solution: {
        targetByItemId: {
          'air-a-humidity': 'different',
          'air-b-humidity': 'different',
          'start-temperature': 'same',
          'cooling-rate': 'same',
        },
      },
    },
    transfer: {
      kind: 'singleSelect',
      operation: 'prediction',
      items: [
        { id: 'compress-warm', text: '上昇すると圧縮されて温まり、水蒸気のまま白く見える。' },
        { id: 'unchanged', text: '上昇しても気圧と気温は変わらず、必ず同じ高さで雲になる。' },
        { id: 'expand-cool', text: '上昇して膨張・冷却し、露点へ達すれば凝結して雲粒ができる。' },
      ],
      solution: { selectedItemId: 'expand-cool' },
    },
  },
  strataRelativeAge: {
    foundation: {
      kind: 'sequence',
      operation: 'causalOrder',
      items: [
        { id: 'green-layer', text: '切られていない緑の層が上へ堆積する。' },
        { id: 'lower-layers', text: '青・黄・白の層が下から順に堆積する。' },
        { id: 'cutting-event', text: '3層を横切る出来事が起こる。' },
      ],
      solution: { orderedItemIds: ['lower-layers', 'cutting-event', 'green-layer'] },
    },
    conditions: {
      kind: 'classify',
      operation: 'causalOrder',
      items: [
        { id: 'layer-a', text: '断層Fに切られた地層A' },
        { id: 'layer-c', text: '断層Fに切られた地層C' },
        { id: 'fault-f', text: 'A・B・Cを切る断層Fの活動' },
        { id: 'layer-d', text: 'Fを覆い、Fに切られていない地層D' },
      ],
      targets: [
        { id: 'before-fault', label: '断層Fより前' },
        { id: 'event', label: '断層Fの活動' },
        { id: 'after-fault', label: '断層Fより後' },
      ],
      solution: {
        targetByItemId: {
          'layer-a': 'before-fault',
          'layer-c': 'before-fault',
          'fault-f': 'event',
          'layer-d': 'after-fault',
        },
      },
    },
    transfer: {
      kind: 'singleSelect',
      operation: 'prediction',
      items: [
        { id: 'multi-evidence', text: '火山灰の特徴、化石、上下関係を組み合わせて対応させる。' },
        { id: 'color-only', text: '色が同じなら、他の特徴に関係なく同じ時期とする。' },
        { id: 'near-only', text: '地点が隣り合う場合だけ地層を対応させ、離れていれば比較しない。' },
      ],
      solution: { selectedItemId: 'multi-evidence' },
    },
  },
}
