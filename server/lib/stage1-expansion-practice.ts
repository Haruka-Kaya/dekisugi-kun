import type {
  CognitiveTaskPlan,
  LocalPracticePlan,
} from './local-practice-variants.js'

/** Stage 1 expansionの3段階練習正本。 */
export const STAGE1_EXPANSION_PRACTICE_PLANS: Readonly<
  Record<string, LocalPracticePlan>
> = {
  gasProperties: {
    foundation: {
      recallPrompt: '気体の捕集法を選ぶとき、水溶性と空気との密度差をどの順で使うか説明してください。',
      reasoningPrompt: '見た目が同じ無色の気体でも、反応の固定データを識別に使う必要を足してください。',
      expectedOutcome: '性質表から、酸素と水素は水上置換、アンモニアは上方置換、二酸化炭素は下方置換の候補へ対応します。',
      expectedReason: '酸素と水素は水に溶けにくく、アンモニアは水に非常に溶けやすく空気より軽く、二酸化炭素は空気より重いという違いを使うためです。',
    },
    conditions: {
      recallPrompt: '水に非常に溶けやすい気体へ水上置換を使えない理由を説明してください。',
      reasoningPrompt: '水上置換に向かない場合、空気より軽いか重いかで置換法を分ける手順を足してください。',
      transferPrompt: '未知気体Aは水に非常に溶けやすく、空気より軽く、水溶液がアルカリ性を示すという固定データがあります。候補と捕集法を選んでください。',
      expectedOutcome: '気体Aはアンモニアの性質と一致し、水上置換ではなく上方置換を選びます。',
      expectedReason: '非常に高い水溶性のため水上置換に向かず、空気より軽いため上方置換で空気を追い出して集めるからです。アルカリ性のデータも識別を支持します。',
      checkpoint: {
        lure: '気体Aは水に非常によく溶けるので、水上置換で最も多く集められる。',
        options: [
          { id: 'water-collection', text: '水に溶かしながら水上置換で集める。', hint: '集めたい気体が水へ溶けると、容器内に気体として残るかを考えます。' },
          { id: 'ammonia-upward', text: 'アンモニアと判断し、空気より軽い性質を使って上方置換で集める。' },
          { id: 'carbon-dioxide-downward', text: '二酸化炭素と判断し、下方置換だけを選ぶ。', hint: '水溶液がアルカリ性を示す気体の資料と照合します。' },
        ],
        correctOptionId: 'ammonia-upward',
        explanation: 'Aはアンモニアの性質に一致します。水に溶けやすいため水上置換を避け、軽さを使う上方置換を選びます。',
      },
    },
    transfer: {
      recallPrompt: '未知の無色気体を識別するとき、一つの反応だけでなく複数の性質を使う理由を説明してください。',
      reasoningPrompt: '燃焼性や刺激性のある気体を家庭で確かめず、教師の固定結果を使う安全条件を足してください。',
      transferPrompt: '未知気体Xは水に溶けにくく空気より少し重く、教師実験の固定記録では線香が激しく燃えました。未知気体Yは石灰水を白く濁らせました。識別と根拠を整理してください。',
      expectedOutcome: 'Xは酸素、Yは二酸化炭素と判断する根拠がそろいます。ただしXの密度だけ、Yの無色という見た目だけでは識別できません。',
      expectedReason: '酸素は物を燃えやすくし、二酸化炭素は石灰水を白濁させるという種類固有の反応を、溶解性や密度のデータと組み合わせるためです。',
      checkpoint: {
        lure: 'XとYはどちらも無色なので、同じ気体と判断できる。',
        options: [
          { id: 'color-only', text: '無色という共通点だけで、XとYは同じ気体だと決める。', hint: '酸素と二酸化炭素がどちらも無色でも反応が異なることを使います。' },
          { id: 'density-alone', text: '空気との密度差だけで、反応記録を使わず物質名を一つに決める。', hint: '密度が近い別の気体が候補にならないかを考えます。' },
          { id: 'combine-reactions', text: 'Xは燃焼を助ける反応から酸素、Yは石灰水の白濁から二酸化炭素と判断する。' },
        ],
        correctOptionId: 'combine-reactions',
        explanation: '見た目だけでなく、種類ごとの反応と溶解性・密度の固定データを組み合わせて識別します。',
      },
    },
  },
  stateChangeMass: {
    foundation: {
      recallPrompt: '閉じた系で液体が気体へ変わっても全質量が変わらない理由を説明してください。',
      reasoningPrompt: '見えなくなることと、測定範囲から物質が失われることを区別して足してください。',
      expectedOutcome: '密閉容器の測定記録では、内部の液体が気体へ変わっても容器を含む全質量は測定範囲内で同じです。',
      expectedReason: '状態変化では同じ物質の粒子の配置と運動が変わるだけで、閉じた容器から粒子が出入りしないためです。',
    },
    conditions: {
      recallPrompt: '開いた容器で蒸発後の質量が減る理由を、測定する系の境界を使って説明してください。',
      reasoningPrompt: '質量が消滅したのではないと確かめるには、周囲を含むどの範囲を測ればよいか足してください。',
      transferPrompt: '同量の液体を、開いた皿Aと気体を逃さない袋Bに入れた記録を比べます。蒸発後、皿・袋を含む各測定値はどうなると予想しますか。',
      expectedOutcome: 'Aでは気体が測定範囲外へ出るため皿に残る質量は減り、Bでは気体も袋内に残るため袋全体の質量は変わりません。',
      expectedReason: '違いは状態変化そのものではなく、気体となった粒子が設定した系の境界を越えるかどうかです。',
      checkpoint: {
        lure: 'Aだけ質量が減るのは、開いた場所では状態変化が物質を消すからである。',
        options: [
          { id: 'open-destroys', text: '開いた系では粒子が消滅し、閉じた系では新しい粒子が生まれる。', hint: '物質が消えたのか、測定範囲の外へ移動したのかを区別します。' },
          { id: 'boundary-transfer', text: 'Aの粒子は気体として測定範囲外へ移り、Bの粒子は袋内に残る。' },
          { id: 'bag-adds-mass', text: '袋が蒸発した粒子へ追加の質量を与えるのでBだけ一定になる。', hint: '袋の役割は物質を増やすことか、出入りを防ぐことかを見ます。' },
        ],
        correctOptionId: 'boundary-transfer',
        explanation: '開いた皿の見かけの減少は粒子が外へ移ったためです。閉じた袋では測定する全体から出ません。',
      },
    },
    transfer: {
      recallPrompt: '固体が液体へ変わるとき、粒子モデルで変わるものと変わらないものを説明してください。',
      reasoningPrompt: '体積が少し変わる場合でも全質量が同じである理由を、密度との違いから足してください。',
      transferPrompt: '密閉された柔らかい袋の中で固体が全て液体になった測定図があります。袋全体の質量、物質の体積、粒子の種類について言えることを分けてください。',
      expectedOutcome: '袋全体の質量と粒子の種類は変わりませんが、物質の体積や粒子の並び方・間隔は変わる場合があります。',
      expectedReason: '状態変化は同じ物質の粒子配置の変化です。質量保存は体積が必ず一定という意味ではなく、密度も状態によって変わり得ます。',
      checkpoint: {
        lure: '全質量が同じなら体積と密度も必ず同じで、粒子の並び方も変わらない。',
        options: [
          { id: 'all-fixed', text: '質量保存とは、質量・体積・密度・粒子配置が全て一定という意味である。', hint: '固体と液体で粒子の並び方や間隔が同じかを考えます。' },
          { id: 'new-particles', text: '液体になると別種類の粒子へ変わるが、偶然同じ質量になる。', hint: '状態変化と化学変化を区別します。' },
          { id: 'mass-only-conserved', text: '閉じた全体の質量は同じでも、体積や粒子配置は変わる場合がある。' },
        ],
        correctOptionId: 'mass-only-conserved',
        explanation: '閉じた系の質量保存は、体積や密度まで一定という意味ではありません。状態により粒子配置が変わります。',
      },
    },
  },
  photosynthesisRespiration: {
    foundation: {
      recallPrompt: '明るい植物で光合成と呼吸が同時に起こることを、気体の出入りから説明してください。',
      reasoningPrompt: '酸素が正味で増えた結果だけでは呼吸が止まったと言えない理由を足してください。',
      expectedOutcome: '明所データでは酸素が正味で増え、暗所データでは減りますが、呼吸の欄はどちらの条件でも「行う」と整理できます。',
      expectedReason: '明所では光合成による酸素生成が呼吸による消費を上回り、暗所では光合成が進まず呼吸による消費だけが表れやすいためです。',
    },
    conditions: {
      recallPrompt: '光の強さを変えたときの正味の二酸化炭素交換を、光合成と呼吸の差として説明してください。',
      reasoningPrompt: '交換量がゼロでも両方の過程が止まったとは限らないことを足してください。',
      transferPrompt: '同じ葉で、弱い光では二酸化炭素の正味変化がほぼ0、強い光では減少したデータがあります。各条件の光合成と呼吸を解釈してください。',
      expectedOutcome: '弱い光では光合成による取り込みと呼吸による放出がほぼつり合い、強い光では光合成の取り込みが上回ったと解釈できます。',
      expectedReason: '測定値は二つの過程の差であり、ゼロは必ずしも両過程の停止ではありません。温度など他条件をそろえた比較が必要です。',
      checkpoint: {
        lure: '二酸化炭素の正味変化が0なら、光合成も呼吸も全く起きていない。',
        options: [
          { id: 'both-stopped', text: '出入りが0なので、二つの過程は必ず停止している。', hint: '同じ量を取り込み、同じ量を放出した場合の正味を考えます。' },
          { id: 'rates-balance', text: '光合成の取り込みと呼吸の放出がほぼ等しく、差が0の可能性がある。' },
          { id: 'respiration-reverses', text: '弱い光では呼吸が二酸化炭素を吸収する過程へ逆転する。', hint: '呼吸で使う物質と生じる物質を確認します。' },
        ],
        correctOptionId: 'rates-balance',
        explanation: '正味0は、光合成と呼吸の速さがつり合った場合にも生じます。各過程の停止とは断定できません。',
      },
    },
    transfer: {
      recallPrompt: '葉と根で光合成・呼吸の有無が異なる理由を、葉緑体と生命活動から説明してください。',
      reasoningPrompt: '植物全体の気体交換を葉一枚の結果だけで決められない理由を足してください。',
      transferPrompt: '明るい条件で、葉の付いた枝Aと葉を除いた枝Bの気体交換データを比べます。Aは酸素が増え、Bは酸素が減りました。違いを説明してください。',
      expectedOutcome: 'Aでは葉の光合成が呼吸を上回って酸素が正味で増え、Bでは光合成する葉がなく呼吸による酸素消費が表れます。',
      expectedReason: '光合成は主に葉緑体をもつ細胞で光のあるときに進みますが、呼吸は葉以外の生きた細胞でも続くためです。',
      checkpoint: {
        lure: '葉を除いた枝は光合成できないので、呼吸も行わず酸素量は変わらない。',
        options: [
          { id: 'all-processes-leaf', text: '光合成も呼吸も葉だけの働きなので、Bでは両方止まる。', hint: '根や茎の細胞も生命活動へエネルギーを使うかを考えます。' },
          { id: 'branch-makes-oxygen', text: '葉がないほど光を受けやすくなり、Bの酸素は増える。', hint: '光合成を行う細胞器官がどこに多いかを確認します。' },
          { id: 'respiration-remains', text: '葉がなく光合成が小さくても、生きた茎の細胞は呼吸を続ける。' },
        ],
        correctOptionId: 'respiration-remains',
        explanation: '呼吸は植物の生きた細胞で行われます。葉を除いて光合成が減っても、茎の呼吸は残ります。',
      },
    },
  },
  digestionAbsorption: {
    foundation: {
      recallPrompt: '消化と吸収を、物質の大きさの変化と体内へ入る場所に分けて説明してください。',
      reasoningPrompt: '消化管の中にあることを、すでに体内へ吸収されたことと区別して足してください。',
      expectedOutcome: 'カード図では大きな栄養分が消化管内で小さな物質へ分解され、その後に主に小腸の柔毛から血液やリンパへ移ります。',
      expectedReason: '大きな栄養分子はそのままでは吸収されにくく、消化酵素で小さくしてから消化管の壁を越える必要があるためです。',
    },
    conditions: {
      recallPrompt: '消化酵素ごとに働く栄養分が異なることを説明してください。',
      reasoningPrompt: '酵素名だけでなく温度などの条件もそろえて比較する必要を足してください。',
      transferPrompt: '同じ条件で、酵素Xはデンプンを分解したがタンパク質を分解せず、酵素Yは逆の結果でした。結果から言えることを整理してください。',
      expectedOutcome: 'XとYは働く相手が異なり、Xはデンプン、Yはタンパク質に作用するという基質特異性が示されます。',
      expectedReason: '酵素の作用は相手となる物質との組合せに依存します。ただしこの結果だけで他の温度やpHでも同じ速さとは断定できません。',
      checkpoint: {
        lure: '一つの消化酵素があれば、どの栄養分も同じ条件・同じ速さで分解できる。',
        options: [
          { id: 'universal-enzyme', text: '酵素は種類に関係なく、全ての栄養分へ同じように働く。', hint: 'XとYで分解できた物質が入れ替わった結果を使います。' },
          { id: 'substrate-specific', text: '酵素には働く相手があり、温度やpHなどの条件も作用へ影響する。' },
          { id: 'enzyme-is-nutrient', text: '酵素そのものが栄養分へ変わることで、全てを吸収可能にする。', hint: '酵素は反応を助けるものか、分解後の栄養分そのものかを区別します。' },
        ],
        correctOptionId: 'substrate-specific',
        explanation: '消化酵素には特定の相手があり、作用の速さは温度やpHなどの条件にも左右されます。',
      },
    },
    transfer: {
      recallPrompt: '小腸の柔毛が吸収に適する理由を、表面積と血管への距離から説明してください。',
      reasoningPrompt: '柔毛が多いことだけでなく、薄い壁や毛細血管・リンパ管との関係を足してください。',
      transferPrompt: '同じ長さの管Aは内側が平らで、管Bは多数の柔毛模型をもちます。壁の厚さなどを同じにしたとき、吸収面積と移動のしやすさを比較してください。',
      expectedOutcome: 'Bは内側の表面積が大きいため、同時に物質が壁を通過できる場所が増え、Aより吸収に適します。',
      expectedReason: '柔毛は限られた長さの小腸で表面積を増やし、内部の毛細血管やリンパ管へ栄養分を運びやすくするためです。',
      checkpoint: {
        lure: '柔毛は小腸の内側を平らにして表面積を小さくし、吸収を遅くする。',
        options: [
          { id: 'flatten-surface', text: '柔毛は凹凸をなくして、栄養分が壁へ触れないようにする。', hint: '多数の突起がある面と平らな面の面積を比べます。' },
          { id: 'digestive-teeth', text: '柔毛は食物を歯のように砕くだけで、吸収面積には関係しない。', hint: '柔毛の内部にある毛細血管やリンパ管の役割を考えます。' },
          { id: 'increase-area', text: '柔毛は表面積を増やし、分解後の栄養分を体内へ取り込みやすくする。' },
        ],
        correctOptionId: 'increase-area',
        explanation: '多数の柔毛は小腸内面の表面積を大きくし、栄養分が壁を通って運ばれる機会を増やします。',
      },
    },
  },
  fronts: {
    foundation: {
      recallPrompt: '温暖前線で暖気と寒気がどのように重なるか説明してください。',
      reasoningPrompt: '前線通過時の天気は代表的傾向であり必ず同じではないことを足してください。',
      expectedOutcome: '資料では前線接近から層状の雲が広がって降水が続き、通過後に気温が上がるという温暖前線の代表的な時系列が見られます。',
      expectedReason: '進む暖気が密度の大きい寒気の上を緩やかに上昇し、広い範囲で冷えて雲をつくるためです。',
    },
    conditions: {
      recallPrompt: '温暖前線と寒冷前線の断面の違いを、どちらの気団が進むかから説明してください。',
      reasoningPrompt: '降水範囲や強さが水蒸気量や前線速度でも変わることを足してください。',
      transferPrompt: '断面図Aは暖気が寒気の上を緩やかに進み、図Bは寒気が暖気の下へ急に入り込みます。前線の種類と雲の傾向を対応させてください。',
      expectedOutcome: 'Aは温暖前線で広い範囲の層状雲、Bは寒冷前線で狭い範囲に発達した雲が生じやすい断面です。',
      expectedReason: '暖気の持ち上げられる傾きと速さが異なるためです。ただし実際の雲・雨は含まれる水蒸気量などにも左右されます。',
      checkpoint: {
        lure: '図AとBは線の傾きが違うだけで、気団の動きも天気の傾向も同じである。',
        options: [
          { id: 'same-front', text: 'どちらも同じ前線で、暖気と寒気の進む向きは関係しない。', hint: 'どちらの気団が前進して相手を持ち上げるかを比べます。' },
          { id: 'cross-section-match', text: 'Aは温暖前線、Bは寒冷前線で、暖気の上昇のしかたが異なる。' },
          { id: 'clouds-impossible', text: '気団の境界では空気が上下しないので、どちらも雲はできない。', hint: '暖気が持ち上げられて冷えると何が起こるかを考えます。' },
        ],
        correctOptionId: 'cross-section-match',
        explanation: '前進する気団の違いにより、暖気の持ち上げ方と代表的な雲・降水の分布が異なります。',
      },
    },
    transfer: {
      recallPrompt: '前線通過を一時刻の天気図だけでなく時系列で確かめる理由を説明してください。',
      reasoningPrompt: '前線記号だけで局地的な降水を断定できない理由を足してください。',
      transferPrompt: '地点Pで、気温が短時間に下がり、風向が変わり、狭い時間帯に強い降水がありました。前後の天気図には寒冷前線が通過しています。根拠と限界を述べてください。',
      expectedOutcome: '観測の時系列は寒冷前線通過の代表的変化と整合しますが、地点Pの一例だけで全ての寒冷前線が同じ強さの雨を降らせるとは言えません。',
      expectedReason: '寒気が暖気を急に持ち上げると発達した雲ができやすい一方、水蒸気量・地形・前線速度などで現れ方が変わるためです。',
      checkpoint: {
        lure: '一度強い雨が観測されたので、寒冷前線はどこでも必ず同じ雨量になる。',
        options: [
          { id: 'fixed-rainfall', text: '前線の種類だけで、地点や季節に関係なく雨量を一意に決められる。', hint: '雲をつくる水蒸気量や地形など、前線以外の条件を考えます。' },
          { id: 'no-front-evidence', text: '気温・風向・降水の時間変化は前線通過の判断に全く使えない。', hint: '天気図の前線位置と観測の変化が時間的に対応するかを見ます。' },
          { id: 'trend-with-limits', text: '観測は寒冷前線の傾向と整合するが、雨の強さは他条件でも変わる。' },
        ],
        correctOptionId: 'trend-with-limits',
        explanation: '複数の時間変化は前線通過の根拠になりますが、降水量まで前線の種類だけで固定できません。',
      },
    },
  },
  pressurePatternsWind: {
    foundation: {
      recallPrompt: '気圧差が風を生む向きと、実際の風向が曲がる理由を分けて説明してください。',
      reasoningPrompt: '等圧線間隔が狭い場所ほど風が強まりやすいことを足してください。',
      expectedOutcome: '過去天気図では等圧線が狭い区域の観測風速が概して大きく、広い区域では小さいという対応を読み取れます。',
      expectedReason: '同じ距離での気圧差が大きいほど空気を動かす力が大きくなるためです。ただし地形や摩擦で個々の観測値は変わります。',
    },
    conditions: {
      recallPrompt: '気圧差がない場所で強い大規模風を気圧傾度力だけから説明できない理由を述べてください。',
      reasoningPrompt: '地球の自転は風を生み始める力ではなく、動く空気の進路へ影響することを足してください。',
      transferPrompt: '同じ緯度・同じ地表条件の区域AとBで、Aの等圧線間隔はBの半分です。大規模な風速の傾向を比較してください。',
      expectedOutcome: 'Aは同じ距離での気圧差が大きいため、Bより風が強い傾向になると予想できます。',
      expectedReason: '比較条件をそろえると、等圧線間隔が気圧傾度の大きさを表します。ただし局地地形などで観測値が逆転する可能性はあります。',
      checkpoint: {
        lure: '等圧線が狭いAほど空気が通れないので、風はBより必ず弱い。',
        options: [
          { id: 'lines-block-air', text: '等圧線は壁なので、線が多いほど風を止める。', hint: '等圧線は実物の壁か、同じ気圧を結ぶ地図上の線かを確認します。' },
          { id: 'larger-gradient', text: 'Aは同じ距離で気圧が大きく変わるため、風が強まりやすい。' },
          { id: 'spacing-no-meaning', text: '等圧線の間隔は風と無関係で、色だけが風速を表す。', hint: '同じ距離で何hPa変わるかを線の間隔から読みます。' },
        ],
        correctOptionId: 'larger-gradient',
        explanation: '等圧線が狭いほど気圧傾度が大きく、他条件が同じなら風が強まりやすくなります。',
      },
    },
    transfer: {
      recallPrompt: '北半球の地表付近の風が等圧線を斜めに横切る理由を説明してください。',
      reasoningPrompt: '上空と地表で摩擦の大きさが違うため風向も変わることを足してください。',
      transferPrompt: '北半球の低気圧周辺で、上空と地表付近の風ベクトルを比べます。低圧側への向き、自転の効果、摩擦を使って違いを説明してください。',
      expectedOutcome: '上空の風は等圧線に近い向きですが、地表付近では摩擦で遅くなり、等圧線を斜めに横切って低気圧側へ入りやすくなります。',
      expectedReason: '摩擦で風速が下がると自転による見かけの曲げ効果も相対的に小さくなり、低圧側へ向かう成分が残るためです。',
      checkpoint: {
        lure: '地表摩擦は風を速くし、自転の効果を強めるので、風は低気圧から外へ吹き出す。',
        options: [
          { id: 'friction-speeds', text: '摩擦は風を加速し、低圧側から高圧側へ押し出す。', hint: '摩擦が運動の速さへ通常どの向きに働くかを考えます。' },
          { id: 'rotation-creates-pressure', text: '自転だけが低気圧をつくり、気圧差は風向へ影響しない。', hint: '気圧差による力と、動く空気を曲げる効果を分けます。' },
          { id: 'surface-crosses-isobars', text: '摩擦で風速が下がる地表付近では、風は等圧線を横切って低圧側へ向かう。' },
        ],
        correctOptionId: 'surface-crosses-isobars',
        explanation: '地表摩擦は風を弱め、気圧差による低圧側への成分が相対的に大きくなります。',
      },
    },
  },
  volcanoEarthquakes: {
    foundation: {
      recallPrompt: '火山と地震の分布に共通する傾向と、同じ現象ではない点を説明してください。',
      reasoningPrompt: '分布の重なりだけで必ず同時に起こるとは言えない理由を足してください。',
      expectedOutcome: '分布図にはプレート境界付近に火山と震央が多い共通傾向がある一方、両者が一致しない地域も見つかります。',
      expectedReason: 'どちらもプレート運動と関係しますが、地震は岩盤のずれ、噴火はマグマの上昇という異なる過程で、成立条件も異なるためです。',
    },
    conditions: {
      recallPrompt: 'マグマの粘り気と火山ガスが噴火のようすへ影響することを説明してください。',
      reasoningPrompt: 'マグマの性質だけで個々の噴火規模を完全に予測できない限界を足してください。',
      transferPrompt: '資料Aは粘り気が小さくガスが抜けやすいマグマ、資料Bは粘り気が大きくガスが抜けにくいマグマです。代表的な噴火傾向を比較してください。',
      expectedOutcome: 'Aは溶岩が流れやすい比較的穏やかな噴火、Bは圧力が高まり爆発的になりやすい傾向があります。',
      expectedReason: '粘り気が大きいと気体が抜けにくく、内部の圧力が高まりやすいためです。ただし実際の噴火はガス量や供給速度などでも変わります。',
      checkpoint: {
        lure: '粘り気が大きいマグマほど気体がすぐ抜けるので、必ず穏やかに噴火する。',
        options: [
          { id: 'viscous-releases', text: '粘り気が大きいほど気体が自由に抜け、圧力はたまらない。', hint: '動きにくい液体の中を気泡が抜けやすいかを考えます。' },
          { id: 'gas-trapped', text: '粘り気が大きいと気体が抜けにくく、圧力が高まりやすい。' },
          { id: 'viscosity-irrelevant', text: 'マグマの粘り気は噴火のようすと全く関係しない。', hint: '溶岩の流れやすさと気体の抜けやすさを比べます。' },
        ],
        correctOptionId: 'gas-trapped',
        explanation: '粘り気の大きいマグマでは気体が抜けにくく、圧力が高まって爆発的になりやすい傾向があります。',
      },
    },
    transfer: {
      recallPrompt: '震源距離とP波・S波の到着時刻差の関係を説明してください。',
      reasoningPrompt: '揺れの強さは距離だけでなく地震規模と地盤にも左右されることを足してください。',
      transferPrompt: '同じ地震を観測した地点PではP波とS波の到着差が4秒、地点Qでは12秒でした。震源からの距離について比較し、断定できないことも述べてください。',
      expectedOutcome: '同じ地震なら到着差が大きいQのほうが震源から遠いと推定できますが、この差だけで揺れの強さや正確な震源位置までは決まりません。',
      expectedReason: 'P波とS波の速さが異なるため距離とともに到着差が広がります。位置決定には複数地点、揺れには規模や地盤の情報も必要です。',
      checkpoint: {
        lure: '到着差が大きいQほど震源に近く、必ずPより強く揺れる。',
        options: [
          { id: 'larger-gap-nearer', text: '到着差が大きいほど震源に近く、揺れも必ず強い。', hint: '速さの違う二つの波が長い距離を進むと、到着差がどうなるかを考えます。' },
          { id: 'gap-fixes-intensity', text: '到着差だけから、震源位置と各地点の震度を全て決められる。', hint: '震源位置に必要な観測地点数と、地盤の影響を確認します。' },
          { id: 'larger-gap-farther', text: '同じ地震なら到着差が大きいQが遠いが、揺れの強さは別情報も必要である。' },
        ],
        correctOptionId: 'larger-gap-farther',
        explanation: '同じ地震ではP波とS波の到着差は距離とともに広がりますが、震度は距離だけで決まりません。',
      },
    },
  },
  dailyMotionSeasons: {
    foundation: {
      recallPrompt: '一晩の天体の日周運動と、一年の星座の変化を分けて説明してください。',
      reasoningPrompt: '日周運動が地球の自転と逆向きに見える理由を足してください。',
      expectedOutcome: 'シミュレーションでは一晩に星が東から西へ動き、同じ時刻でも月を進めると見える星座が西側へ移ります。',
      expectedReason: '一晩の見かけの動きは地球の西から東への自転、一年の同時刻の変化は地球の公転による観測方向の変化で生じます。',
    },
    conditions: {
      recallPrompt: '北の空と南の空で星の軌跡が違って見える理由を、天の北極との位置関係から説明してください。',
      reasoningPrompt: '観察地点の緯度や方角をそろえない図を直接比べられないことを足してください。',
      transferPrompt: '北半球の同じ地点で、北向きと南向きに固定したカメラの長時間記録があります。星の軌跡の形と東西方向を比較してください。',
      expectedOutcome: '北の空では天の北極を中心とする円弧、南の空では東から昇って西へ沈む傾いた円弧として記録されます。',
      expectedReason: '地球の自転軸を空へ延ばした方向を中心に天球が回るように見え、見る方角によって円運動の見える部分が異なるためです。',
      checkpoint: {
        lure: '星の軌跡は方角や緯度に関係なく、空のどこでも同じ直線になる。',
        options: [
          { id: 'same-lines', text: '自転していても全ての星は同じ平行な直線を描く。', hint: '自転軸を延ばした点の近くで軌跡がどう見えるかを考えます。' },
          { id: 'direction-dependent-arcs', text: '天の極との位置関係により、見る方角で円弧の見え方が変わる。' },
          { id: 'stars-random', text: '星は毎晩無関係な方向へ動くため、規則的な軌跡はできない。', hint: '同じ地点・同じ方角で長時間記録した規則性を使います。' },
        ],
        correctOptionId: 'direction-dependent-arcs',
        explanation: '星は天の極を中心に回るように見え、観察方角と緯度により見える円弧が変わります。',
      },
    },
    transfer: {
      recallPrompt: '北半球の夏に太陽高度が高く昼が長くなる理由を、地軸の傾きと公転で説明してください。',
      reasoningPrompt: '太陽との距離だけでは南北半球の反対の季節を説明できないことを足してください。',
      transferPrompt: '同じ日に北半球地点Nは太陽高度が高く昼が長く、南半球地点Sは低く昼が短い資料があります。季節と日射条件を説明してください。',
      expectedOutcome: 'Nは夏、Sは冬の条件で、Nは日射がより直角に近く当たり、受ける時間も長くなります。',
      expectedReason: '地軸が傾いたまま公転するため、一方の半球が太陽側へ傾く時期には他方が反対側へ傾きます。地球全体の太陽距離は両地点でほぼ同じです。',
      checkpoint: {
        lure: '同じ日のNとSは太陽までの距離が大きく違うので、反対の季節になる。',
        options: [
          { id: 'hemisphere-distance', text: '半球ごとの太陽距離の差だけが季節を決める。', hint: '地球の大きさによる距離差と、太陽までの距離を比べます。' },
          { id: 'same-season', text: '同じ地球なので南北半球の季節と昼の長さは常に同じである。', hint: '地軸が太陽に対してどちらへ傾いているかを比べます。' },
          { id: 'tilt-opposite-seasons', text: '地軸の傾きにより日射角度と昼の長さが反対に変わり、季節も反対になる。' },
        ],
        correctOptionId: 'tilt-opposite-seasons',
        explanation: '地軸の傾きにより両半球の日射角度と昼の長さが反対に変化するため、季節も反対になります。',
      },
    },
  },
}

/** 各transfer場面へ直接答える端末内認知課題。 */
export const STAGE1_EXPANSION_COGNITIVE_TASKS: Readonly<
  Record<string, CognitiveTaskPlan>
> = {
  gasProperties: {
    foundation: {
      kind: 'classify', operation: 'conditionClassify',
      items: [
        { id: 'oxygen', text: '水に溶けにくい酸素' },
        { id: 'hydrogen', text: '水に溶けにくい水素' },
        { id: 'ammonia', text: '水に非常に溶けやすく空気より軽いアンモニア' },
        { id: 'carbon-dioxide', text: '空気より重い二酸化炭素' },
      ],
      targets: [{ id: 'water-displacement', label: '水上置換' }, { id: 'upward-displacement', label: '上方置換' }, { id: 'downward-displacement', label: '下方置換' }],
      solution: { targetByItemId: { oxygen: 'water-displacement', hydrogen: 'water-displacement', ammonia: 'upward-displacement', 'carbon-dioxide': 'downward-displacement' } },
    },
    conditions: {
      kind: 'sequence', operation: 'experimentPlan',
      items: [
        { id: 'select-upward', text: '空気より軽い性質から上方置換を選ぶ。' },
        { id: 'check-solubility', text: '水に非常に溶けやすいことを確認する。' },
        { id: 'match-alkaline', text: '水溶液がアルカリ性という記録からアンモニアへ絞る。' },
      ],
      solution: { orderedItemIds: ['check-solubility', 'select-upward', 'match-alkaline'] },
    },
    transfer: {
      kind: 'singleSelect', operation: 'experimentPlan',
      items: [
        { id: 'reaction-evidence', text: '固定反応記録からXを酸素、Yを二酸化炭素と判断する。' },
        { id: 'appearance-only', text: '無色という見た目だけでXとYを同じ気体とする。' },
        { id: 'density-only', text: '密度だけで物質名を一つに決める。' },
      ],
      solution: { selectedItemId: 'reaction-evidence' },
    },
  },
  stateChangeMass: {
    foundation: {
      kind: 'sequence', operation: 'causalOrder',
      items: [
        { id: 'same-total-mass', text: '容器を含む全質量は同じ。' },
        { id: 'phase-transition', text: '液体の粒子配置が気体の配置へ変わる。' },
        { id: 'sealed-boundary', text: '粒子は密閉容器の外へ出ない。' },
      ],
      solution: { orderedItemIds: ['phase-transition', 'sealed-boundary', 'same-total-mass'] },
    },
    conditions: {
      kind: 'classify', operation: 'conditionClassify',
      items: [
        { id: 'dish-vapor', text: '皿Aから周囲へ移った気体粒子' },
        { id: 'bag-vapor', text: '袋Bの中に残った気体粒子' },
        { id: 'bag-reading', text: '袋B全体の測定値' },
        { id: 'dish-reading', text: '皿Aを含む測定値' },
      ],
      targets: [{ id: 'outside-system', label: '測定範囲外へ移る・減る' }, { id: 'inside-system', label: '測定範囲内に残る・一定' }],
      solution: { targetByItemId: { 'dish-vapor': 'outside-system', 'bag-vapor': 'inside-system', 'dish-reading': 'outside-system', 'bag-reading': 'inside-system' } },
    },
    transfer: {
      kind: 'singleSelect', operation: 'quantityCompare',
      items: [
        { id: 'mass-stable-volume-variable', text: '全質量と粒子種類は同じで、体積や配置は変わり得る。' },
        { id: 'everything-fixed', text: '質量・体積・粒子配置が全て同じ。' },
        { id: 'different-material', text: '別物質へ変わるが質量だけ偶然同じ。' },
      ],
      solution: { selectedItemId: 'mass-stable-volume-variable' },
    },
  },
  photosynthesisRespiration: {
    foundation: {
      kind: 'classify', operation: 'conditionClassify',
      items: [
        { id: 'light-photosynthesis', text: '明所での光合成' },
        { id: 'light-respiration', text: '明所での呼吸' },
        { id: 'dark-photosynthesis', text: '暗所での光合成' },
        { id: 'dark-respiration', text: '暗所での呼吸' },
      ],
      targets: [{ id: 'occurs', label: '行われる' }, { id: 'not-observed', label: '進まない' }],
      solution: { targetByItemId: { 'light-photosynthesis': 'occurs', 'light-respiration': 'occurs', 'dark-photosynthesis': 'not-observed', 'dark-respiration': 'occurs' } },
    },
    conditions: {
      kind: 'singleSelect', operation: 'quantityCompare',
      items: [
        { id: 'both-stop', text: '正味0なので両過程が停止。' },
        { id: 'balanced-rates', text: '光合成の取り込みと呼吸の放出がほぼつり合う。' },
        { id: 'respiration-absorbs', text: '呼吸が二酸化炭素を吸収する。' },
      ],
      solution: { selectedItemId: 'balanced-rates' },
    },
    transfer: {
      kind: 'sequence', operation: 'causalOrder',
      items: [
        { id: 'oxygen-decreases', text: '呼吸による酸素消費が正味で表れる。' },
        { id: 'remove-leaves', text: '枝から光合成する葉を除く。' },
        { id: 'stem-respires', text: '生きた茎の細胞は呼吸を続ける。' },
      ],
      solution: { orderedItemIds: ['remove-leaves', 'stem-respires', 'oxygen-decreases'] },
    },
  },
  digestionAbsorption: {
    foundation: {
      kind: 'sequence', operation: 'causalOrder',
      items: [
        { id: 'enter-circulation', text: '柔毛から血液やリンパへ入る。' },
        { id: 'large-nutrient', text: '大きな栄養分が消化管へ入る。' },
        { id: 'enzyme-breakdown', text: '酵素で吸収可能な物質へ分解する。' },
      ],
      solution: { orderedItemIds: ['large-nutrient', 'enzyme-breakdown', 'enter-circulation'] },
    },
    conditions: {
      kind: 'classify', operation: 'experimentPlan',
      items: [
        { id: 'enzyme-x-starch', text: '酵素Xとデンプン' },
        { id: 'enzyme-x-protein', text: '酵素Xとタンパク質' },
        { id: 'enzyme-y-starch', text: '酵素Yとデンプン' },
        { id: 'enzyme-y-protein', text: '酵素Yとタンパク質' },
      ],
      targets: [{ id: 'breakdown', label: '資料で分解' }, { id: 'unchanged', label: '資料で変化なし' }],
      solution: { targetByItemId: { 'enzyme-x-starch': 'breakdown', 'enzyme-x-protein': 'unchanged', 'enzyme-y-starch': 'unchanged', 'enzyme-y-protein': 'breakdown' } },
    },
    transfer: {
      kind: 'singleSelect', operation: 'prediction',
      items: [
        { id: 'flat-faster', text: '平らなAのほうが吸収面積が大きい。' },
        { id: 'same-area', text: '管の長さが同じなら表面積も同じ。' },
        { id: 'villi-larger-area', text: '柔毛のあるBは表面積が大きく吸収に適する。' },
      ],
      solution: { selectedItemId: 'villi-larger-area' },
    },
  },
  fronts: {
    foundation: {
      kind: 'sequence', operation: 'causalOrder',
      items: [
        { id: 'temperature-rises', text: '通過後に気温が上がる傾向。' },
        { id: 'warm-air-rises', text: '暖気が寒気の上を緩やかに上昇。' },
        { id: 'layered-clouds', text: '広い範囲に層状の雲と降水。' },
      ],
      solution: { orderedItemIds: ['warm-air-rises', 'layered-clouds', 'temperature-rises'] },
    },
    conditions: {
      kind: 'classify', operation: 'conditionClassify',
      items: [
        { id: 'gentle-slope', text: '暖気が緩やかに上る断面' },
        { id: 'cold-wedge', text: '寒気が暖気の下へ入る断面' },
        { id: 'narrow-cloud', text: '狭い範囲の発達した雲' },
        { id: 'broad-cloud', text: '広い範囲の層状雲' },
      ],
      targets: [{ id: 'warm-front', label: '温暖前線A' }, { id: 'cold-front', label: '寒冷前線B' }],
      solution: { targetByItemId: { 'gentle-slope': 'warm-front', 'cold-wedge': 'cold-front', 'broad-cloud': 'warm-front', 'narrow-cloud': 'cold-front' } },
    },
    transfer: {
      kind: 'singleSelect', operation: 'prediction',
      items: [
        { id: 'same-rain-always', text: '全寒冷前線で同じ雨量になる。' },
        { id: 'observations-useless', text: '時系列観測は前線判断に使えない。' },
        { id: 'evidence-with-conditions', text: '通過傾向と整合するが降水強度は他条件でも変わる。' },
      ],
      solution: { selectedItemId: 'evidence-with-conditions' },
    },
  },
  pressurePatternsWind: {
    foundation: {
      kind: 'classify', operation: 'quantityCompare',
      items: [
        { id: 'narrow-isobars', text: '等圧線間隔が狭い区域' },
        { id: 'wide-isobars', text: '等圧線間隔が広い区域' },
        { id: 'small-gradient', text: '同距離で小さな気圧差' },
        { id: 'large-gradient', text: '同距離で大きな気圧差' },
      ],
      targets: [{ id: 'stronger-trend', label: '強風傾向' }, { id: 'weaker-trend', label: '弱風傾向' }],
      solution: { targetByItemId: { 'narrow-isobars': 'stronger-trend', 'wide-isobars': 'weaker-trend', 'large-gradient': 'stronger-trend', 'small-gradient': 'weaker-trend' } },
    },
    conditions: {
      kind: 'singleSelect', operation: 'prediction',
      items: [
        { id: 'isobar-wall', text: 'Aは線が壁になるため弱い。' },
        { id: 'greater-gradient', text: 'Aは気圧傾度が大きく強まりやすい。' },
        { id: 'map-color-only', text: '間隔は風速と関係しない。' },
      ],
      solution: { selectedItemId: 'greater-gradient' },
    },
    transfer: {
      kind: 'sequence', operation: 'causalOrder',
      items: [
        { id: 'cross-to-low', text: '風が等圧線を横切り低圧側へ向かう。' },
        { id: 'surface-friction', text: '地表摩擦が風速を下げる。' },
        { id: 'turning-weakens', text: '自転による曲げ効果が相対的に小さくなる。' },
      ],
      solution: { orderedItemIds: ['surface-friction', 'turning-weakens', 'cross-to-low'] },
    },
  },
  volcanoEarthquakes: {
    foundation: {
      kind: 'classify', operation: 'conditionClassify',
      items: [
        { id: 'plate-boundary-cluster', text: 'プレート境界付近に多い分布' },
        { id: 'rock-slip', text: '地下の岩盤の急なずれ' },
        { id: 'magma-rise', text: 'マグマの上昇と噴出' },
        { id: 'same-timing', text: '必ず同時刻に発生' },
      ],
      targets: [{ id: 'shared-tendency', label: '共通する傾向' }, { id: 'event-specific', label: '現象固有' }, { id: 'unsupported', label: '資料から支持されない' }],
      solution: { targetByItemId: { 'plate-boundary-cluster': 'shared-tendency', 'rock-slip': 'event-specific', 'magma-rise': 'event-specific', 'same-timing': 'unsupported' } },
    },
    conditions: {
      kind: 'sequence', operation: 'causalOrder',
      items: [
        { id: 'explosive-tendency', text: '爆発的な噴火になりやすい。' },
        { id: 'high-viscosity', text: 'マグマの粘り気が大きい。' },
        { id: 'gas-retained', text: '気体が抜けにくく圧力が高まる。' },
      ],
      solution: { orderedItemIds: ['high-viscosity', 'gas-retained', 'explosive-tendency'] },
    },
    transfer: {
      kind: 'singleSelect', operation: 'prediction',
      items: [
        { id: 'gap-means-near', text: '到着差12秒のQが近く必ず強く揺れる。' },
        { id: 'gap-fixes-location', text: '一地点の到着差だけで震源位置が確定する。' },
        { id: 'gap-means-far', text: '同じ地震ならQが遠いが、揺れには別条件も必要。' },
      ],
      solution: { selectedItemId: 'gap-means-far' },
    },
  },
  dailyMotionSeasons: {
    foundation: {
      kind: 'classify', operation: 'conditionClassify',
      items: [
        { id: 'nightly-east-west', text: '一晩の東から西への見かけの動き' },
        { id: 'monthly-constellation', text: '同時刻に見える星座の月ごとの変化' },
        { id: 'earth-revolution', text: '地球の公転' },
        { id: 'earth-rotation', text: '地球の自転' },
      ],
      targets: [{ id: 'daily', label: '日周運動' }, { id: 'annual', label: '年周変化' }],
      solution: { targetByItemId: { 'nightly-east-west': 'daily', 'monthly-constellation': 'annual', 'earth-rotation': 'daily', 'earth-revolution': 'annual' } },
    },
    conditions: {
      kind: 'sequence', operation: 'causalOrder',
      items: [
        { id: 'circular-arcs', text: '天の極を中心とする円弧として記録される。' },
        { id: 'earth-spins', text: '地球が西から東へ自転する。' },
        { id: 'sky-opposite', text: '天球が東から西へ回るように見える。' },
      ],
      solution: { orderedItemIds: ['earth-spins', 'sky-opposite', 'circular-arcs'] },
    },
    transfer: {
      kind: 'singleSelect', operation: 'prediction',
      items: [
        { id: 'distance-by-hemisphere', text: '半球ごとの太陽距離だけで季節が反対。' },
        { id: 'tilt-changes-insolation', text: '地軸の傾きで日射角度と昼の長さが反対に変わる。' },
        { id: 'both-same-season', text: '同じ地球なので季節は常に同じ。' },
      ],
      solution: { selectedItemId: 'tilt-changes-insolation' },
    },
  },
}
