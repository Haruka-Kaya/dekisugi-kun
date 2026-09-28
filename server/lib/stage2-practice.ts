import type {
  CognitiveTaskPlan,
  LocalPracticePlan,
} from './local-practice-variants.js'

/** Stage 2「化学変化と原子・分子」の3段階練習正本。 */
export const STAGE2_PRACTICE_PLANS: Readonly<
  Record<string, LocalPracticePlan>
> = {
  combinationDecomposition: {
    foundation: {
      recallPrompt:
        '物質が結びつく化合と分かれる分解を、「反応前後で物質の種類が変わるか」という点から説明してください。',
      reasoningPrompt:
        '混ぜ合わせることや溶かすことは化合ではありません。化合と混合物を見分ける根拠を一つ足してください。',
      expectedOutcome:
        '鉄粉と硫黄の混合粉末を加熱した記録では、反応後の黒い物質は磁石に引かれず、反応前とは性質の違う物質になっています。',
      expectedReason:
        '加熱で鉄と硫黄が化学変化により結びつき、硫化鉄という別の性質の物質が生成したためです。混ぜただけでは粒ごとの性質が残ります。',
    },
    conditions: {
      recallPrompt:
        '「2つを混ぜた」と「化合した」の違いを、粒の性質が残るかどうかで説明してください。',
      reasoningPrompt:
        '生成物が本当に別物質か確かめるには、どの性質を比べればよいか足してください。',
      transferPrompt:
        '炭酸水素ナトリウムを加熱した記録で、性質の違う固体と水・気体が生じたとします。これは分解と言えるか、根拠を添えて判断してください。',
      expectedOutcome:
        '炭酸水素ナトリウムという1種類の物質が、性質の違う複数の物質に分かれたので、分解と判断できます。',
      expectedReason:
        '生成物が反応前と異なる性質を示し、1種類から2種類以上へ分かれたためです。物質が変わらない状態変化や分離とは違います。',
      checkpoint: {
        lure: '加熱していくつかの物質に分かれたなら、それはいつでも分解である。',
        options: [
          {
            id: 'melting-decomposition',
            text: '氷が水になるのも1種類から別のものへ分かれるので、分解に含める。',
            hint: '氷と水で物質の種類が変わるか、姿が変わるだけかを区別します。',
          },
          {
            id: 'new-substances-decomposition',
            text: '性質の違う複数の物質が1種類から生成したと確認できれば、分解である。',
          },
          {
            id: 'heating-only',
            text: '加熱さえすれば起きる変化はすべて化学変化なので、分類は不要である。',
            hint: '加熱で起きる変化にも、物質が変わらないものがあるかを考えます。',
          },
        ],
        correctOptionId: 'new-substances-decomposition',
        explanation:
          '分解とは1種類の物質が2種類以上の別物質に分かれる化学変化です。'
          + '氷が水になるような、物質が変わらない変化は分解ではありません。',
      },
    },
    transfer: {
      recallPrompt:
        '化学変化と、状態変化や溶解などの物理的な変化の違いを説明してください。',
      reasoningPrompt:
        '「気体が出た」「色が変わった」だけでは化学変化と断定できない理由を足してください。',
      transferPrompt:
        '石灰石に熱を加えた記録では、性質の違う固体と気体が生じました。'
        + 'また別の記録では、砂と鉄粉の混合物を磁石で分けました。'
        + 'どちらが化学変化で、なぜかを整理してください。',
      expectedOutcome:
        '石灰石の加熱は新しい物質が生じた分解で、砂と鉄粉の分離は物質が変わらない物理的な操作です。',
      expectedReason:
        '化学変化では生成物が反応前と異なる性質を示しますが、'
        + '磁石での分離では粒ごとの性質がそのまま残るためです。',
      checkpoint: {
        lure: '磁石で鉄粉を取り分ける操作も、物質を分ける点では分解と同じである。',
        options: [
          {
            id: 'separation-is-decomposition',
            text: '混合物を成分へ分ける操作は、加熱と同じく分解である。',
            hint: '分解で分かれた物質と、磁石で取り出した鉄粉が別物質に変わったかを見ます。',
          },
          {
            id: 'all-division-chemical',
            text: 'ものを分ける変化はすべて化学変化なので、どちらも分解である。',
            hint: '化学変化の条件は「分ける」ことか「別物質が生成する」ことかを考えます。',
          },
          {
            id: 'physical-vs-chemical',
            text: '磁石による分離は粒の性質が変わらない物理的操作で、生成物が別物質になる分解とは違う。',
          },
        ],
        correctOptionId: 'physical-vs-chemical',
        explanation:
          '分解は化学変化で、生成物はもとの物質とは性質が違います。'
          + '磁石での分離は鉄粉も砂も性質が変わらない物理的操作です。',
      },
    },
  },
  oxidationReduction: {
    foundation: {
      recallPrompt:
        '物質が酸素と結びつく酸化と、酸化物から酸素を取り去る還元の関係を説明してください。',
      reasoningPrompt:
        '燃焼・さび・呼吸など速さの違う変化が、なぜ同じ「酸化」と呼ばれるのかを足してください。',
      expectedOutcome:
        '酸化銅の粉末に炭素の粉を混ぜて加熱した記録では、黒い粉末から赤い光沢の銅が生じ、二酸化炭素が発生しています。',
      expectedReason:
        '酸化銅の酸素が炭素へ移り、酸化銅が還元されて銅に、炭素が酸化されて二酸化炭素になったためです。',
    },
    conditions: {
      recallPrompt:
        '酸化で質量が増える理由を、酸素との結びつきで説明してください。',
      reasoningPrompt:
        '金属を燃やすと質量が増える記録を、「燃えて軽くなるはず」と矛盾しない形で説明できる点を足してください。',
      transferPrompt:
        '銅板を加熱したら質量が増えた、木炭を燃やしたら残った固体の質量は減ったという記録があります。'
        + '増えた分と減って見える分はそれぞれどこから来たかを説明してください。',
      expectedOutcome:
        '銅板は空気中の酸素と結びついた分だけ重くなり、木炭は結びついた酸素といっしょに二酸化炭素として空気中へ出た分だけ軽く見えます。',
      expectedReason:
        'どちらも酸素をやりとりする酸化です。'
        + '周囲の酸素や逃げた気体を測定に含めるかどうかで、見かけの増減が決まります。',
      checkpoint: {
        lure: '燃焼では物質が消費されるので、酸化の前後で物質は必ず減る。',
        options: [
          {
            id: 'oxygen-added',
            text: '燃焼は激しい酸化で、結びついた酸素の分だけ生成物は重くなる。逃げる気体も含めて考える必要がある。',
          },
          {
            id: 'burning-shrinks',
            text: '燃えた分だけ物質は消えるので、生成物の質量は常に小さくなる。',
            hint: '燃えるとき酸素が結びつくことを、酸化物の質量の記録と照らします。',
          },
          {
            id: 'fire-is-not-oxidation',
            text: '燃焼は酸化とは別の仕組みなので、酸素の出入りは関係ない。',
            hint: '燃えるために酸素が必要かどうかを確認します。',
          },
        ],
        correctOptionId: 'oxygen-added',
        explanation:
          '燃焼は激しい酸化です。残った固体だけを見ると増減はさまざまですが、'
          + '結びついた酸素や逃げた気体まで含めれば、酸素のやりとりで説明できます。',
      },
    },
    transfer: {
      recallPrompt:
        '酸化と還元が「逆向きの反応」であることを、酸素のやりとりで説明してください。',
      reasoningPrompt:
        '日常生活で酸化・還元を使っている例を一つ挙げ、どちらの反応かを理由とともに足してください。',
      transferPrompt:
        '鉄鉱石（酸化鉄）から鉄を取り出す製鉄と、鉄がさびる変化を、酸素のやりとりで対比してください。'
        + 'どちらが酸化でどちらが還元ですか。',
      expectedOutcome:
        '鉄鉱石から酸素を取り除いて鉄にするのが還元、鉄が酸素と結びついてさびるのが酸化です。',
      expectedReason:
        '還元は酸化物から酸素を取り去る反応、酸化は物質が酸素と結びつく反応で、'
        + '酸素の移動する向きが逆だからです。',
      checkpoint: {
        lure: 'さびてできた酸化物を元の鉄に戻す操作も、同じく酸化の一種である。',
        options: [
          {
            id: 'return-is-oxidation',
            text: 'さびを鉄に戻す操作は鉄を「元へ返す」ので、名前の通り酸化である。',
            hint: '酸化・還元の分類は「元に戻すか」ではなく、酸素をどちらへ動かすかで決まります。',
          },
          {
            id: 'rust-permanent',
            text: 'さびた鉄は二度と変化しないので、どちらの反応でもない。',
            hint: '製鉄では酸化鉄から鉄を取り出しています。その反応名を確認します。',
          },
          {
            id: 'rust-removal-reduction',
            text: 'さびを鉄に戻すのは、酸化物から酸素を取り去る還元である。',
          },
        ],
        correctOptionId: 'rust-removal-reduction',
        explanation:
          '酸化物から酸素を取り去る反応は還元です。'
          + '「元へ返す」という意味ではなく、酸素のやりとりの向きで分類します。',
      },
    },
  },
  massConservation: {
    foundation: {
      recallPrompt:
        '化学変化の前後で、反応に関わる物質すべての質量の総和が等しいことを、原子の組み替えで説明してください。',
      reasoningPrompt:
        '「燃えて消えた」「発生して現れた」ように見える物質を、質量保存と矛盾なく説明する点を足してください。',
      expectedOutcome:
        '密閉した袋の中で塩酸と炭酸水素ナトリウムを反応させた記録では、気体が発生しても袋全体の質量は反応前と等しいままです。',
      expectedReason:
        '反応で原子の組合せが変わり気体が生じても、原子自体は袋内に残るため、測る全体の質量は変わりません。',
    },
    conditions: {
      recallPrompt:
        '開いた系で質量が変わって見える理由を、測定する範囲の設定で説明してください。',
      reasoningPrompt:
        '気体にも質量があることを確認できる観察を一つ挙げて、説明に足してください。',
      transferPrompt:
        '同じ反応を開いた容器と密閉袋で行った記録があります。'
        + '開いた容器では質量が減り、密閉袋では変わりません。'
        + 'この違いを法則の例外とせずに説明してください。',
      expectedOutcome:
        '開いた容器では発生した気体が測定範囲外へ出るため減って見え、密閉袋では気体も測定に含まれるため変わりません。',
      expectedReason:
        '質量保存は「関わる物質すべて」を測る法則です。'
        + '出入りした物質を測定に含めるかの違いが見かけの差を生み、法則そのものの例外ではありません。',
      checkpoint: {
        lure: '開いた容器で質量が減ったなら、その反応では質量保存が成り立たない。',
        options: [
          {
            id: 'escaped-gas-counted',
            text: '逃げた気体の質量も合わせれば総和は等しい。測る範囲の外へ出ただけで、法則は成り立つ。',
          },
          {
            id: 'mass-destroyed',
            text: '質量が減った分だけ原子が消えたので、この反応では保存されない。',
            hint: '気体として出た原子は、消えたのか場所が変わったのかを考えます。',
          },
          {
            id: 'open-systems-exempt',
            text: '開いた系では法則を適用できないので、検証もできない。',
            hint: '逃げた気体の質量を別に測る方法があるかを考えます。',
          },
        ],
        correctOptionId: 'escaped-gas-counted',
        explanation:
          '開いた系で減って見えるのは、気体が測定範囲の外へ出たためです。'
          + '気体にも質量があり、出た分まで合わせれば反応前後の総和は等しくなります。',
      },
    },
    transfer: {
      recallPrompt:
        '化学変化で質量が増えて見える場合の説明を、外から取り込まれる物質で書いてください。',
      reasoningPrompt:
        '金属を加熱して質量が増える記録を、「測る系に何を含めたか」で説明する点を足してください。',
      transferPrompt:
        '銅を空気中で加熱する記録Aでは質量が増え、石灰石を加熱する記録Bでは質量が減りました。'
        + 'それぞれ出入りした物質を挙げ、増減が法則と矛盾しないことを示してください。',
      expectedOutcome:
        'Aでは空気中の酸素が銅へ結びついた分だけ増え、Bでは二酸化炭素が外へ出た分だけ減って見えます。'
        + 'どちらも出入り分を含めれば総和は等しいです。',
      expectedReason:
        '測る系に含まれない物質が入ると増え、含まれる物質が出ると減って見えます。'
        + '反応に関わるすべてを測れば質量は保存されます。',
      checkpoint: {
        lure: '金属を加熱して質量が増えるのは、加熱で新しい原子が作られたからである。',
        options: [
          {
            id: 'atoms-created',
            text: '加熱は原子を新しく作るので、質量が増えるのは当然である。',
            hint: '化学変化で原子が新たに作られるか、組合せだけが変わるかを確認します。',
          },
          {
            id: 'oxygen-joined',
            text: '空気中の酸素が金属と結びついた分だけ重くなった。測る系に空気を含めれば総和は等しい。',
          },
          {
            id: 'heat-has-mass',
            text: '熱そのものに質量があるため、加熱するほど重くなる。',
            hint: '増えた質量が酸素の量と対応するか、熱量と対応するかを考えます。',
          },
        ],
        correctOptionId: 'oxygen-joined',
        explanation:
          '増えた分は結びついた酸素の質量です。'
          + '化学変化で原子は作られず組合せが変わるだけなので、出入りする物質まで測れば総和は等しくなります。',
      },
    },
  },
  electrolyte: {
    foundation: {
      recallPrompt:
        '水溶液に電気が流れるものと流れないものがあることを、電解質と非電解質の言葉で説明してください。',
      reasoningPrompt:
        '電解質の液で電流が流れる理由を、イオンという粒子が動くことで足してください。',
      expectedOutcome:
        '食塩水には電流が流れて電極に物質ができましたが、砂糖水には流れず電極も変化しません。',
      expectedReason:
        '食塩は溶けるとイオンに分かれてイオンが動くので電流が流れます。'
        + '砂糖は溶けてもイオンにならないので、液は電気を通しません。',
    },
    conditions: {
      recallPrompt:
        '溶けることと電気を通すことが別であることを、食塩水と砂糖水の例で説明してください。',
      reasoningPrompt:
        '液の中にイオンがあるかどうかを確かめる手がかりとして、電極の変化を使える点を足してください。',
      transferPrompt:
        'うすい塩酸に炭素電極を入れて電圧をかけた記録では、両方の電極に気体がつきました。'
        + '液の中に目に見えない粒子が動いていると考える根拠を説明してください。',
      expectedOutcome:
        '電圧をかけた電解質水溶液では、陽極と陰極に決まった物質が生成します。',
      expectedReason:
        '液の中の電気を帯びた粒子（イオン）が電極へ引かれて集まり、'
        + 'そこで別の物質になるため、電極の変化がイオンの存在を示します。',
      checkpoint: {
        lure: '電極に物質ができるのは、液の水分が電気で変化しただけである。',
        options: [
          {
            id: 'water-split-only',
            text: 'どんな液でも水が変化するので、生成物はどの液でも同じはずである。',
            hint: '砂糖水では電極に何もできなかった記録を見返します。',
          },
          {
            id: 'ions-deposited',
            text: '液の中のイオンが電極へ集まって物質になるので、生成物は液の種類ごとに決まる。',
          },
          {
            id: 'heat-changed',
            text: '電圧で液が熱くなり、蒸発した残りが電極についただけである。',
            hint: '生成した物質が電極ごとに決まっているか、記録を確認します。',
          },
        ],
        correctOptionId: 'ions-deposited',
        explanation:
          '電極にできる物質は液の種類ごとに決まっています。'
          + '液の中のイオンが電極へ集まって変化するためで、水が変化しただけでは説明できません。',
      },
    },
    transfer: {
      recallPrompt:
        '電解質と非電解質の違いを、液に電圧をかけた結果で説明してください。',
      reasoningPrompt:
        'イオンが原子とどう違うか（電子をやりとりして電気を帯びた粒子）を足してください。',
      transferPrompt:
        '食塩・砂糖・エタノールをそれぞれ水に溶かした記録で、電気を通したのは食塩水だけでした。'
        + 'また固い食塩には電気が流れませんでした。二つの結果をイオンで説明してください。',
      expectedOutcome:
        '食塩は溶けるとイオンに分かれて電気を通し、砂糖やエタノールはイオンにならず通しません。'
        + '固い食塩はイオンが動けないので電気を通しません。',
      expectedReason:
        '電解質は水に溶けて初めてイオンが自由に動けるようになります。'
        + '非電解質は溶けても電気を帯びた粒子ができず、固体ではイオンが動けません。',
      checkpoint: {
        lure: '食塩は固体でも電気を通すので、電解質と呼ばれる。',
        options: [
          {
            id: 'ions-must-move',
            text: '電解質は溶けてイオンが動けるときだけ電気を通す。固体ではイオンが動けない。',
          },
          {
            id: 'solid-salt-conducts',
            text: '食塩は固いままでも電気を通すので、溶かさなくても電解質である。',
            hint: '固い食塩に電気が流れたか、記録で確認します。',
          },
          {
            id: 'all-dissolved-conduct',
            text: '溶けた物質はすべてイオンに分かれるので、エタノール水溶液も電気を通す。',
            hint: '溶けてもイオンにならない物質があるかを考えます。',
          },
        ],
        correctOptionId: 'ions-must-move',
        explanation:
          '電気を運ぶのは動けるイオンです。'
          + '電解質は水に溶けてイオンに分かれたときだけ電気を通し、固いままではイオンが動けません。',
      },
    },
  },
  acidAlkali: {
    foundation: {
      recallPrompt:
        '酸の性質が水素イオン、アルカリの性質が水酸化物イオンによることを説明してください。',
      reasoningPrompt:
        '指示薬の色変化が酸とアルカリの手がかりになる理由を足してください。',
      expectedOutcome:
        'BTB溶液を加えた記録では、うすい塩酸は黄色、うすい水酸化ナトリウム水溶液は青色、'
        + '食塩水は緑色のままです。',
      expectedReason:
        '酸に共通する水素イオンとアルカリに共通する水酸化物イオンが指示薬を変色させるため、'
        + '色の違いで酸性・アルカリ性・中性を見分けられます。',
    },
    conditions: {
      recallPrompt:
        'pHが酸性・アルカリ性の強さを表す指標であることを説明してください。',
      reasoningPrompt:
        '「酸はすべて危険」ではなく、身の回りの液にも酸がある例を一つ足してください。',
      transferPrompt:
        '二つの酸性の液でpHが3と5でした。どちらが強い酸ですか。'
        + 'またアルカリ性の液では、pHが大きいほど何を意味しますか。',
      expectedOutcome:
        'pHが小さいほど酸性が強いのでpH3のほうが強い酸で、'
        + 'アルカリ性ではpHが大きいほど強いアルカリ性です。',
      expectedReason:
        'pHは水素イオン・水酸化物イオンの量の目安で、'
        + '7が中性で、そこから離れるほど酸性・アルカリ性が強くなります。',
      checkpoint: {
        lure: 'pHが7より大きい液は酸性である。',
        options: [
          {
            id: 'high-ph-acid',
            text: 'pHが大きいほど強い酸なので、7より大きい液は酸性である。',
            hint: 'pH7が中性で、どちら側が酸性かを確認します。',
          },
          {
            id: 'ph-direction',
            text: 'pHは7が中性で、小さいほど酸性、大きいほどアルカリ性が強い。',
          },
          {
            id: 'ph-no-meaning',
            text: 'pHの数字と酸性・アルカリ性の強さには関係がない。',
            hint: 'pHが何を表す指標かを確認します。',
          },
        ],
        correctOptionId: 'ph-direction',
        explanation:
          'pHは7が中性で、小さいほど強い酸、大きいほど強いアルカリです。'
          + '数字の向きを逆に覚えると、性質を取り違えます。',
      },
    },
    transfer: {
      recallPrompt:
        '指示薬を使わなくても、酸とアルカリの違いをそれぞれを作るイオンで説明してください。',
      reasoningPrompt:
        '食酢やレモン汁も酸であることと、硫酸など強い酸との違いを「強さ」で足してください。',
      transferPrompt:
        '炭酸水素ナトリウムの粉にうすい塩酸と食酢を加えた記録では、'
        + 'どちらにも気体が発生しましたが勢いが違いました。'
        + 'この共通点と違いを酸のイオンで説明してください。',
      expectedOutcome:
        'どちらにも気体が発生したのは、両方とも酸の水素イオンが反応したからで、'
        + '勢いの違いは酸の強さの違いです。',
      expectedReason:
        '酸に共通する性質は水素イオンの仕事です。'
        + '同じ酸でも水素イオンの量が違えば、反応の進み方が変わります。',
      checkpoint: {
        lure: '食酢では気体が弱いので、食酢は酸ではない。',
        options: [
          {
            id: 'vinegar-not-acid',
            text: '気体の勢いが弱い食酢は酸ではなく、別の性質をもつ液である。',
            hint: '気体が出たこと自体が何のイオンによるかを考えます。',
          },
          {
            id: 'gas-only-strong-acid',
            text: '気体が出るのは強い酸だけなので、食酢から気体が出た記録は誤りである。',
            hint: '弱い酸でも水素イオンがあるかを考えます。',
          },
          {
            id: 'acid-strength-varies',
            text: '酸には強さの幅がある。食酢も水素イオンをもつ酸で、反応の勢いは強さの違い。',
          },
        ],
        correctOptionId: 'acid-strength-varies',
        explanation:
          '酸の共通の性質は水素イオンによるものです。'
          + '食酢のような弱い酸でも気体は発生し、勢いの違いは酸の強さ（水素イオンの量）の違いです。',
      },
    },
  },
  neutralizationBattery: {
    foundation: {
      recallPrompt:
        '中和で水と塩ができることを、水素イオンと水酸化物イオンの結びつきで説明してください。',
      reasoningPrompt:
        '中性にならなくても中和が起きている理由（混ざった分だけ反応する）を足してください。',
      expectedOutcome:
        'うすい塩酸とうすい水酸化ナトリウム水溶液を中性になるまで混ぜて乾燥させた記録では、'
        + '白い結晶＝塩化ナトリウムが残っています。',
      expectedReason:
        '水素イオンと水酸化物イオンが結びついて水になり、'
        + '残ったナトリウムイオンと塩化物イオンが結晶になるためです。',
    },
    conditions: {
      recallPrompt:
        '塩は中和でできる物質の名前で、食塩以外にもあることを説明してください。',
      reasoningPrompt:
        '水に溶ける塩と溶けない塩がある例を一つ足してください。',
      transferPrompt:
        '酸とアルカリを混ぜた液がpH6でした。中和は起きていますか。'
        + 'また液には何が含まれていますか。',
      expectedOutcome:
        'pH7ではなくても混ざった分の水素イオンと水酸化物イオンは水になり、'
        + '液には生成した塩と余った酸のイオンが含まれます。',
      expectedReason:
        '中和反応は混ざった分だけ必ず進みます。'
        + '量が合わなければ一方が余り、中性にならなくても塩はできています。',
      checkpoint: {
        lure: '中性にならなかった液では、中和は全く起きていない。',
        options: [
          {
            id: 'partial-occurs',
            text: '中性にならなくても混ざった分は中和し、水と塩ができている。',
          },
          {
            id: 'no-neutralization',
            text: '中性にならなかったのだから、酸とアルカリは反応していない。',
            hint: '混ざった分の水素イオンと水酸化物イオンがどうなったかを考えます。',
          },
          {
            id: 'only-water-formed',
            text: '中和では水だけができ、液に残るものは何もない。',
            hint: 'ナトリウムイオンと塩化物イオンがどこへ行くかを考えます。',
          },
        ],
        correctOptionId: 'partial-occurs',
        explanation:
          '中和は混ざった分だけ必ず起きます。'
          + '余った側が残って中性にならなくても、できた水と塩は液に残っています。',
      },
    },
    transfer: {
      recallPrompt:
        '金属によってイオンへのなりやすさが違うことを説明してください。',
      reasoningPrompt:
        '電池ではこのなりやすさの差で電子が流れることを足してください。',
      transferPrompt:
        '亜鉛板と銅板を電解質水溶液に入れて回路をつないだ記録では、電流が流れました。'
        + 'どちらの金属が電子を放出し、どこで受け取られるかを'
        + 'イオンへのなりやすさで説明してください。',
      expectedOutcome:
        'イオンになりやすい亜鉛が電子を放出して亜鉛イオンになり、'
        + 'その電子が回路を通って銅板へ流れます。',
      expectedReason:
        'イオンへのなりやすさの差が電子の一方向の流れを生むため、'
        + '外部回路に電流として取り出せます。化学エネルギーが電気エネルギーに変わっています。',
      checkpoint: {
        lure: '電池は電気を蓄えた容器で、化学変化とは関係ない。',
        options: [
          {
            id: 'stored-electricity',
            text: '電池はあらかじめ溜めた電気を取り出す容器で、中では何も変化していない。',
            hint: '電池の中で金属や液が変化しているかを考えます。',
          },
          {
            id: 'copper-gives-electrons',
            text: '電子は銅板から亜鉛板へ流れるので、銅がイオンになりやすい。',
            hint: 'イオンになりやすいのは亜鉛と銅のどちらかを確認します。',
          },
          {
            id: 'ion-tendency-drives',
            text: 'イオンへのなりやすさが違う2種類の金属で電子の流れが生まれ、それが電流になる。',
          },
        ],
        correctOptionId: 'ion-tendency-drives',
        explanation:
          '電池では化学変化が起きています。'
          + 'イオンになりやすい亜鉛が電子を放出し、銅側で電子が受け取られることで電流が流れます。',
      },
    },
  },
  reproduction: {
    foundation: {
      recallPrompt:
        '細胞が分裂して増えることと、多細胞生物の成長の関係を、細胞の数と大きさの両面から説明してください。',
      reasoningPrompt:
        '「細胞自体がどんどん大きくなる」という説明では説明できない観察を一つ足してください。',
      expectedOutcome:
        'タマネギの根端の記録では、細胞分裂が起きる領域で染色体が写し取られ2つの細胞へ分けられ、'
        + '細胞の数が増えたうえで各細胞が成長し、根が伸びています。',
      expectedReason:
        '細胞は一定の大きさを保ったまま分裂で数を増やし、増えた細胞がそれぞれ大きくなるため、'
        + '体の成長は細胞の増加と細胞の成長の両方で起きます。',
    },
    conditions: {
      recallPrompt:
        '有性生殖と無性生殖の違いを、親の染色体が子にどう伝わるかで説明してください。',
      reasoningPrompt:
        '受精を経るかどうかだけでなく、減数分裂との関係を足してください。',
      transferPrompt:
        'カエルの受精卵が育つ記録と、ジャガイモの芽が育つ記録があります。'
        + 'それぞれの子がもつ染色体が親とどういう関係かを比べて説明してください。',
      expectedOutcome:
        'カエルの子は両親の染色体を組み合わせてもち、ジャガイモの芽は親と同じ染色体をもちます。',
      expectedReason:
        '有性生殖では減数分裂で半分になった生殖細胞が受精して両親の染色体を受け継ぎ、'
        + '無性生殖では親の体の一部がそのまま個体になるため同じ染色体をもちます。',
      checkpoint: {
        lure: '親と形質が違う子ができたのは、親が子に合わせて染色体を変えたからである。',
        options: [
          {
            id: 'chromosome-mix',
            text: '有性生殖では両親から受け継ぐ染色体の組合せが決まるので、親と少しずつ違う子になる。',
          },
          {
            id: 'parent-adjusts',
            text: '親が環境に合う子を作れるよう、出す染色体を調整している。',
            hint: '染色体がどの過程で決まるか、減数分裂と受精の役割を考えます。',
          },
          {
            id: 'mutation-required',
            text: '親と違う形質はすべて突然変異でしか説明できない。',
            hint: '同じ親からでも組合せが違う子ができる仕組みを考えます。',
          },
        ],
        correctOptionId: 'chromosome-mix',
        explanation:
          '有性生殖の子は両親から別々に染色体を受け継ぐため、'
          + '親とも違う組合せになります。親が意図的に変えたり突然変異が必要だったりしません。',
      },
    },
    transfer: {
      recallPrompt:
        '有性生殖と無性生殖の子の違いが、集団の多様さにどう影響するか説明してください。',
      reasoningPrompt:
        '無性生殖だけで増える集団が環境の変化に弱い理由を、形質のばらつきで説明する点を足してください。',
      transferPrompt:
        '同じ畑で栄養生殖で増えたイチゴが病害でまとめて枯れた記録と、'
        + '種子から育てた畑で一部が生き残った記録があります。この差を説明してください。',
      expectedOutcome:
        '栄養生殖のイチゴはほぼ同じ形質なので同じ病害に全株が弱く、'
        + '種子由来の畑は形質にばらつきがあって耐性のある個体が残りました。',
      expectedReason:
        '無性生殖の子は親と同じ染色体なので集団の形質がそろい、'
        + '有性生殖では組合せが違う子ができるためばらつきが残ります。',
      checkpoint: {
        lure: '無性生殖で増える植物は、環境の変化にも強い集団になる。',
        options: [
          {
            id: 'numbers-strength',
            text: '数が増えるほど集団は強くなるので、無性生殖で速く増える方が変化に強い。',
            hint: '強さの違いが数ではなく形質のばらつきによると考えます。',
          },
          {
            id: 'clone-adapts',
            text: '同じ染色体でも、それぞれの個体が環境に合わせて形質を変えられる。',
            hint: '個体が形質を変えて対応するのか、集団のばらつきの問題かを区別します。',
          },
          {
            id: 'uniform-population-fragile',
            text: '無性生殖では形質がそろうので、環境が変わると集団全体が同じ弱点をもつ。',
          },
        ],
        correctOptionId: 'uniform-population-fragile',
        explanation:
          '無性生殖の子は親と同じ染色体をもつため集団の形質がそろい、'
          + '病害や気候の変化に対して集団全体が同じ弱点をもちます。',
      },
    },
  },
  heredity: {
    foundation: {
      recallPrompt:
        '対立形質と優性・劣性の意味を、エンドウの種子の形の例で説明してください。',
      reasoningPrompt:
        '純系の丸としわを交配したとき子がすべて丸になる観察を、説明に足してください。',
      expectedOutcome:
        '丸の純系としわの純系を交配すると子はすべて丸の種子になり、'
        + 'その子同士の交配では丸としわがおよそ3：1で現れます。',
      expectedReason:
        '子に現れる丸が優性形質、現れなかったしわが劣性形質です。'
        + 'しわの遺伝子は消えたのではなく、子の中に残って次の代で現れます。',
    },
    conditions: {
      recallPrompt:
        '遺伝子の組合せ（AA・Aa・aa）と形質の対応を、優性形質が現れる条件として説明してください。',
      reasoningPrompt:
        '「優性形質を示す個体はAAに決まっている」と言えない理由を足してください。',
      transferPrompt:
        '丸の種子の親2株から、丸の子としわの子が生まれました。'
        + '両親の遺伝子の組合せを推定し、子の組合せを説明してください。',
      expectedOutcome:
        'しわの子（aa）が生まれたので、両親はともにaをもつAaで、'
        + '子の組合せはAA・Aa・Aa・aaの可能性があります。',
      expectedReason:
        'aaは両親それぞれからaを受け継ぐ必要があり、'
        + '優性形質を示す親はAAとは限らずAaでもよいためです。',
      checkpoint: {
        lure: '優性の形質を示す親同士の子が劣性形質になったのは、交配で遺伝子が劣化したからである。',
        options: [
          {
            id: 'aa-from-aa-parents',
            text: '両親がAa同士なら、各親からaを受け継いだaaの子ができて劣性形質が現れる。',
          },
          {
            id: 'gene-degraded',
            text: '遺伝子が交配のたびに弱くなるので、いずれ劣性の形質が現れる。',
            hint: '遺伝子が劣化するのか、組合せの結果としてaaができるのかを考えます。',
          },
          {
            id: 'random-appearance',
            text: '劣性形質は決まった法則なしに出るので、確率は説明できない。',
            hint: 'Aa同士の交配で子の組合せにどんな割合があるかを考えます。',
          },
        ],
        correctOptionId: 'aa-from-aa-parents',
        explanation:
          'Aa同士の交配では子の組合せがAA・Aa・Aa・aaになり、'
          + 'およそ4分の1でaaの子ができて劣性形質が現れます。遺伝子が劣化したのではありません。',
      },
    },
    transfer: {
      recallPrompt:
        '遺伝子・染色体・DNAの関係を、形質が親から子へ伝わる道筋として説明してください。',
      reasoningPrompt:
        '遺伝子が染色体にのって伝わることと、減数分裂・受精との関係を足してください。',
      transferPrompt:
        '両親の耳たぶの形が子と違う観察記録があります。'
        + 'この違いを遺伝子が伝わる道筋（減数分裂→受精）で説明してください。',
      expectedOutcome:
        '親の細胞は減数分裂で染色体が半分になり、受精で子は両親の染色体を受け継ぎます。'
        + '耳たぶの形質を決める遺伝子の組合せが親と子で違いえます。',
      expectedReason:
        '遺伝子は染色体にのって生殖細胞へ入り、受精で両親のものが組み合わさるため、'
        + '子は親とも違う組合せになりうります。',
      checkpoint: {
        lure: '形質を伝える遺伝子は、血液を通して親から子へ移る。',
        options: [
          {
            id: 'blood-carries',
            text: '親と子で血液型が関係するように、形質は血液を介して伝わる。',
            hint: '遺伝子がどの細胞を通って親から子へ行くかを考えます。',
          },
          {
            id: 'dna-direct-body',
            text: '遺伝子は体のどの細胞からも直接子の体へ移るので、すべての形質が平均して伝わる。',
            hint: '生殖細胞を通る道筋と、伝わる遺伝子の数を考えます。',
          },
          {
            id: 'chromosome-gametes',
            text: '遺伝子は染色体にのって生殖細胞へ入り、受精で両親のものが子へ伝わる。',
          },
        ],
        correctOptionId: 'chromosome-gametes',
        explanation:
          '遺伝子は染色体にのっており、減数分裂で半分になった生殖細胞を経て、'
          + '受精によって両親から子へ伝わります。血液や体の細胞から直接は移りません。',
      },
    },
  },
  evolution: {
    foundation: {
      recallPrompt:
        '化石が生物の変遷の証拠になる理由を、地層の新旧と生物の姿の対応で説明してください。',
      reasoningPrompt:
        '「地層ごとに違う生物が出る」のと「同じ生物が少しずつ変わる」の違いを足してください。',
      expectedOutcome:
        '古い層から新しい層へ順にたどると、三葉虫やアンモナイトなど'
        + '姿の異なる生物が層の時代に対応して現れ、'
        + '近縁な姿どうしが段階的に並ぶ記録が確認できます。',
      expectedReason:
        '地層は下ほど古いので、化石はその時代に生きた生物の姿を記録します。'
        + '層の順に姿が変わることは、生物の種類が時間とともに変わってきた証拠です。',
    },
    conditions: {
      recallPrompt:
        '自然選択による進化を、「ばらつき→環境に合うものが残る→形質の割合が変わる」という道筋で説明してください。',
      reasoningPrompt:
        '個体が変わったのではないことを、集団の中の形質の割合で説明する点を足してください。',
      transferPrompt:
        '暗い樹皮の森林で、明るい色の蛾と暗い色の蛾の数が記録されています。'
        + '暗い色の蛾が増えたことを自然選択で説明してください。',
      expectedOutcome:
        'もともと色にばらつきのあった蛾の集団で、暗い樹皮に似た暗色の蛾が鳥に見つかりにくく'
        + '多く子を残し、世代を経て暗色の個体の割合が増えました。',
      expectedReason:
        '個体の色が変わったのではなく、もともとのばらつきの中で'
        + '環境に合った色の個体が多く残されたため、集団の形質の割合が変わりました。',
      checkpoint: {
        lure: '環境が変わると生物は必要な形質を後から身につけ、それが子に伝わる。',
        options: [
          {
            id: 'variation-selected',
            text: 'もともとのばらつきの中で環境に合った形質が残され、集団の形質の割合が変わる。',
          },
          {
            id: 'acquire-needed-trait',
            text: '環境に必要な形質を個体が獲得し、獲得した形質が子に伝わって進化する。',
            hint: '個体が変わるのか、集団の中で残される形質が変わるのかを考えます。',
          },
          {
            id: 'all-mutate',
            text: '環境が変わると集団の全員が同じ方向に変異するので、すぐに適応できる。',
            hint: '変異が環境に合わせて起きるのか、無関係に起きたばらつきが選ばれるのかを考えます。',
          },
        ],
        correctOptionId: 'variation-selected',
        explanation:
          '進化では、もともとあった形質のばらつきから環境に合ったものが多く子を残します。'
          + '個体が必要な形質を獲得して伝えるのではありません。',
      },
    },
    transfer: {
      recallPrompt:
        '進化と「用不用進説（使った器官が発達して子に伝わる）」の違いを、変化が起きる単位で説明してください。',
      reasoningPrompt:
        'キリンの首の例で、両者が同じ観察をどう違う説明にするかを足してください。',
      transferPrompt:
        '高い葉を食べられる首の長いキリンが現れた記録を、'
        + '「努力して伸ばした」と「ばらつきから選ばれた」の2説で説明し、'
        + '化石の記録と合うのはどちらかを判断してください。',
      expectedOutcome:
        '努力説では個体が伸ばした首が子に伝わるとしますが、'
        + '自然選択説では祖先の首の長さにばらつきがあり、'
        + '高い葉を食べられた長い個体が多く子を残したと説明します。'
        + '化石が段階的な姿の変化を示すことと、自然選択説が一致します。',
      expectedReason:
        '獲得した形質は子に伝わらないという証拠と、'
        + '集団の中で残される形質が変わるという観察から、'
        + '進化は個体の変化ではなく集団の形質の割合の変化と説明されます。',
      checkpoint: {
        lure: '化石の生物が現在と違うのは、昔の生物が途中で別の種に突然変身したからである。',
        options: [
          {
            id: 'sudden-transform',
            text: 'ある世代で丸ごと別の生物に変身したので、中間的な姿は存在しない。',
            hint: '古い層から新しい層への記録が断続的か、段階的かを考えます。',
          },
          {
            id: 'extinct-only',
            text: '化石の生物はみな絶滅しただけで、現在の生物とは無関係である。',
            hint: '近縁な姿どうしが層の順に並ぶ記録をどう説明するか考えます。',
          },
          {
            id: 'gradual-change',
            text: '長い時間をかけて残される形質が少しずつ変わり、種の姿が段階的に変化した。',
          },
        ],
        correctOptionId: 'gradual-change',
        explanation:
          '化石は古い層から新しい層へ順に、近縁な姿が段階的に変わる記録を示します。'
          + '進化は長い時間をかけた形質の割合の変化で、突然の変身ではありません。',
      },
    },
  },
}

/** Stage 2 3概念×3周の構造化課題。項目は全員が同じ画面を共有する著者順。 */
export const STAGE2_COGNITIVE_TASKS: Readonly<
  Record<string, CognitiveTaskPlan>
> = {
  combinationDecomposition: {
    foundation: {
      kind: 'classify',
      operation: 'conditionClassify',
      items: [
        { id: 'iron-sulfur-heat', text: '鉄粉と硫黄を混ぜて加熱し、磁石に引かれない黒い物質ができた' },
        { id: 'sand-iron-mix', text: '砂と鉄粉を混ぜた' },
        { id: 'salt-dissolve', text: '食塩を水に溶かした' },
        { id: 'baking-soda-heat', text: '炭酸水素ナトリウムを加熱して複数の物質が生じた' },
      ],
      targets: [
        { id: 'chemical-change', label: '化学変化' },
        { id: 'physical-change', label: '物理的な変化' },
      ],
      solution: {
        targetByItemId: {
          'iron-sulfur-heat': 'chemical-change',
          'salt-dissolve': 'physical-change',
          'baking-soda-heat': 'chemical-change',
          'sand-iron-mix': 'physical-change',
        },
      },
    },
    conditions: {
      kind: 'singleSelect',
      operation: 'experimentPlan',
      items: [
        { id: 'check-color-only', text: '色だけを見て、混ぜたときから化合していたと判断する。' },
        { id: 'check-magnet', text: '反応後の物質を磁石へ近づけ、鉄の性質が残るかを調べる。' },
        { id: 'do-nothing', text: '何も調べず、見た目の変化だけで判断する。' },
      ],
      solution: { selectedItemId: 'check-magnet' },
    },
    transfer: {
      kind: 'sequence',
      operation: 'causalOrder',
      items: [
        { id: 'judge-change', text: '別物質が生成したので化学変化と判断する。' },
        { id: 'compare-before-after', text: '反応前後の物質の性質を比較する。' },
        { id: 'detect-difference', text: '生成物に反応前と違う性質がないか調べる。' },
      ],
      solution: {
        orderedItemIds: ['compare-before-after', 'detect-difference', 'judge-change'],
      },
    },
  },
  oxidationReduction: {
    foundation: {
      kind: 'singleSelect',
      operation: 'prediction',
      items: [
        { id: 'copper-lighter', text: '燃えたので銅板は軽くなる。' },
        { id: 'copper-heavier', text: '銅板は酸素と結びついた分だけ重くなる。' },
        { id: 'copper-same', text: '質量は変わらない。' },
      ],
      solution: { selectedItemId: 'copper-heavier' },
    },
    conditions: {
      kind: 'classify',
      operation: 'conditionClassify',
      items: [
        { id: 'burning-fast', text: '木や炭が燃える' },
        { id: 'rust-slow', text: '鉄がさびる' },
        { id: 'breathing', text: '私たちの呼吸' },
        { id: 'melting-ice', text: '氷がとける' },
      ],
      targets: [
        { id: 'oxidation', label: '酸化' },
        { id: 'not-oxidation', label: '酸化ではない' },
      ],
      solution: {
        targetByItemId: {
          'burning-fast': 'oxidation',
          'rust-slow': 'oxidation',
          'breathing': 'oxidation',
          'melting-ice': 'not-oxidation',
        },
      },
    },
    transfer: {
      kind: 'sequence',
      operation: 'causalOrder',
      items: [
        { id: 'copper-remains', text: '赤い光沢の銅が残る。' },
        { id: 'heat-with-carbon', text: '酸化銅に炭素を混ぜて加熱する。' },
        { id: 'oxygen-moves', text: '酸素が炭素へ移り、二酸化炭素ができる。' },
      ],
      solution: {
        orderedItemIds: ['heat-with-carbon', 'oxygen-moves', 'copper-remains'],
      },
    },
  },
  massConservation: {
    foundation: {
      kind: 'classify',
      operation: 'conditionClassify',
      items: [
        { id: 'atom-types', text: '原子の種類' },
        { id: 'bonding', text: '原子の結びつき方' },
        { id: 'atom-counts', text: '原子の数' },
        { id: 'total-mass', text: '関わる物質すべての質量の和' },
      ],
      targets: [
        { id: 'conserved', label: '変わらない' },
        { id: 'rearranged', label: '変わる' },
      ],
      solution: {
        targetByItemId: {
          'atom-types': 'conserved',
          'bonding': 'rearranged',
          'atom-counts': 'conserved',
          'total-mass': 'conserved',
        },
      },
    },
    conditions: {
      kind: 'singleSelect',
      operation: 'quantityCompare',
      items: [
        { id: 'escaped-gas-equal', text: '逃げた気体の分を含めれば、反応前後の質量の総和は等しい。' },
        { id: 'mass-vanished', text: '発生した気体の分だけ、質量は消えてしまう。' },
        { id: 'scale-error', text: '差が出たのは、はかりの誤差だけが原因である。' },
      ],
      solution: { selectedItemId: 'escaped-gas-equal' },
    },
    transfer: {
      kind: 'singleSelect',
      operation: 'experimentPlan',
      items: [
        { id: 'open-setup', text: '開いた容器で気体を逃がしてから残りを測る。' },
        { id: 'skip-measurement', text: '質量は測らず、見た目の変化だけで判断する。' },
        { id: 'sealed-setup', text: '発生する気体も含めて測れるよう、密閉した容器で反応させて全体を測る。' },
      ],
      solution: { selectedItemId: 'sealed-setup' },
    },
  },
  electrolyte: {
    foundation: {
      kind: 'classify',
      operation: 'conditionClassify',
      items: [
        { id: 'salt-water', text: '食塩を溶かした水' },
        { id: 'sugar-water', text: '砂糖を溶かした水' },
        { id: 'ethanol-water', text: 'エタノールの水溶液' },
        { id: 'dilute-hcl', text: 'うすい塩酸' },
      ],
      targets: [
        { id: 'conducting-liquid', label: '電気を通す液' },
        { id: 'non-conducting-liquid', label: '電気を通さない液' },
      ],
      solution: {
        targetByItemId: {
          'salt-water': 'conducting-liquid',
          'sugar-water': 'non-conducting-liquid',
          'ethanol-water': 'non-conducting-liquid',
          'dilute-hcl': 'conducting-liquid',
        },
      },
    },
    conditions: {
      kind: 'singleSelect',
      operation: 'experimentPlan',
      items: [
        { id: 'color-check', text: '液の色を見て、透明なら電気を通すと判断する。' },
        { id: 'smell-check', text: '液のにおいをかいで、刺激臭があれば電気を通すと判断する。' },
        { id: 'electrode-check', text: '液に電極を入れて電圧をかけ、電極に物質ができるかを調べる。' },
      ],
      solution: { selectedItemId: 'electrode-check' },
    },
    transfer: {
      kind: 'sequence',
      operation: 'causalOrder',
      items: [
        { id: 'substance-forms', text: '電極に新しい物質が生成する。' },
        { id: 'apply-voltage', text: '電解質水溶液に電極を入れて電圧をかける。' },
        { id: 'ions-move', text: '液の中のイオンが電極へ移動する。' },
      ],
      solution: {
        orderedItemIds: ['apply-voltage', 'ions-move', 'substance-forms'],
      },
    },
  },
  acidAlkali: {
    foundation: {
      kind: 'singleSelect',
      operation: 'prediction',
      items: [
        { id: 'btb-yellow', text: 'BTB溶液を加えると黄色になる。' },
        { id: 'btb-blue', text: 'BTB溶液を加えると青色になる。' },
        { id: 'btb-green', text: 'BTB溶液を加えても緑色のまま変わらない。' },
      ],
      solution: { selectedItemId: 'btb-yellow' },
    },
    conditions: {
      kind: 'classify',
      operation: 'conditionClassify',
      items: [
        { id: 'slippery-liquid', text: '液がぬるぬるした感触を示す' },
        { id: 'btb-turns-yellow', text: 'BTB溶液が黄色に変わる' },
        { id: 'gas-on-carbonate', text: '炭酸水素ナトリウムに加えると気体が出る' },
        { id: 'litmus-turns-blue', text: '赤色リトマス紙が青色に変わる' },
      ],
      targets: [
        { id: 'hydrogen-ion', label: '水素イオンの仕事' },
        { id: 'hydroxide-ion', label: '水酸化物イオンの仕事' },
      ],
      solution: {
        targetByItemId: {
          'slippery-liquid': 'hydroxide-ion',
          'btb-turns-yellow': 'hydrogen-ion',
          'gas-on-carbonate': 'hydrogen-ion',
          'litmus-turns-blue': 'hydroxide-ion',
        },
      },
    },
    transfer: {
      kind: 'singleSelect',
      operation: 'quantityCompare',
      items: [
        { id: 'ph5-stronger', text: 'pH5の液のほうが、pH3の液より強い酸である。' },
        { id: 'same-acidity', text: 'pH3とpH5では酸性の強さは同じである。' },
        { id: 'ph3-stronger', text: 'pH3の液のほうが、pH5の液より強い酸である。' },
      ],
      solution: { selectedItemId: 'ph3-stronger' },
    },
  },
  neutralizationBattery: {
    foundation: {
      kind: 'sequence',
      operation: 'causalOrder',
      items: [
        { id: 'salt-remains', text: '残ったナトリウムイオンと塩化物イオンから塩の結晶ができる。' },
        { id: 'ions-join', text: '水素イオンと水酸化物イオンが結びつく。' },
        { id: 'water-forms', text: '結びついた粒が水になり、酸とアルカリの性質が打ち消される。' },
      ],
      solution: {
        orderedItemIds: ['ions-join', 'water-forms', 'salt-remains'],
      },
    },
    conditions: {
      kind: 'singleSelect',
      operation: 'prediction',
      items: [
        { id: 'nothing-remains', text: '中性になった液を乾燥させても、何も残らない。' },
        { id: 'salt-crystals', text: '中性になった液を乾燥させると、塩の結晶が残る。' },
        { id: 'acid-crystals', text: '乾燥させると酸そのものが結晶になって残る。' },
      ],
      solution: { selectedItemId: 'salt-crystals' },
    },
    transfer: {
      kind: 'singleSelect',
      operation: 'experimentPlan',
      items: [
        { id: 'two-metals', text: 'イオンへのなりやすさが違う2種類の金属板を、電解質水溶液に入れて回路をつなぐ。' },
        { id: 'same-metal-pair', text: '同じ金属の板を2枚、水に入れて回路をつなぐ。' },
        { id: 'charged-battery', text: 'あらかじめ電気を溜めた容器に、回路をつなぐ。' },
      ],
      solution: { selectedItemId: 'two-metals' },
    },
  },
  reproduction: {
    foundation: {
      kind: 'sequence',
      operation: 'causalOrder',
      items: [
        { id: 'cell-split', text: '細胞が2つに分かれ、同じ性質の細胞が増える' },
        { id: 'chromosome-copy', text: '核の中の染色体が写し取られる' },
        { id: 'cell-growth', text: '増えた細胞がそれぞれ成長し、体の部分が大きくなる' },
        { id: 'chromosome-split', text: '写し取られた染色体が2つの核へ分けられる' },
      ],
      solution: {
        orderedItemIds: [
          'chromosome-copy',
          'chromosome-split',
          'cell-split',
          'cell-growth',
        ],
      },
    },
    conditions: {
      kind: 'classify',
      operation: 'conditionClassify',
      items: [
        { id: 'frog-fertilized-egg', text: 'カエルの受精卵が育つ' },
        { id: 'potato-sprout', text: 'ジャガイモの芽から新しい株が育つ' },
        { id: 'strawberry-runner', text: 'イチゴのランナーの先に新しい株ができる' },
        { id: 'chicken-egg', text: 'ニワトリの受精卵が育つ' },
      ],
      targets: [
        { id: 'sexual', label: '有性生殖' },
        { id: 'asexual', label: '無性生殖' },
      ],
      solution: {
        targetByItemId: {
          'frog-fertilized-egg': 'sexual',
          'potato-sprout': 'asexual',
          'strawberry-runner': 'asexual',
          'chicken-egg': 'sexual',
        },
      },
    },
    transfer: {
      kind: 'singleSelect',
      operation: 'prediction',
      items: [
        {
          id: 'sexual-diverse',
          text: '有性生殖で育った畑は形質にばらつきがあり、病害で一部が生き残る。',
        },
        {
          id: 'asexual-stronger',
          text: '無性生殖で育った畑は親と同じ強さをもつので、病害でも全株が生き残る。',
        },
        {
          id: 'both-same',
          text: 'どちらの殖え方でも同じ病害への強さなので、生き残る株の差は出ない。',
        },
      ],
      solution: { selectedItemId: 'sexual-diverse' },
    },
  },
  heredity: {
    foundation: {
      kind: 'singleSelect',
      operation: 'prediction',
      items: [
        { id: 'all-dominant', text: '子はすべて優性形質になる' },
        { id: 'three-to-one', text: '子は優性形質と劣性形質がおよそ3：1で現れる' },
        { id: 'half-half', text: '子は優性形質と劣性形質が半々で現れる' },
      ],
      solution: { selectedItemId: 'three-to-one' },
    },
    conditions: {
      kind: 'classify',
      operation: 'conditionClassify',
      items: [
        { id: 'genotype-aa', text: '遺伝子の組合せがaa' },
        { id: 'genotype-aa-big', text: '遺伝子の組合せがAA' },
        { id: 'genotype-aa-hybrid', text: '遺伝子の組合せがAa' },
        { id: 'genotype-aa-again', text: 'もう一組の組合せがaa' },
      ],
      targets: [
        { id: 'dominant-trait', label: '優性形質が現れる' },
        { id: 'recessive-trait', label: '劣性形質が現れる' },
      ],
      solution: {
        targetByItemId: {
          'genotype-aa': 'recessive-trait',
          'genotype-aa-big': 'dominant-trait',
          'genotype-aa-hybrid': 'dominant-trait',
          'genotype-aa-again': 'recessive-trait',
        },
      },
    },
    transfer: {
      kind: 'sequence',
      operation: 'causalOrder',
      items: [
        { id: 'fertilization', text: '両親の生殖細胞が受精し、受精卵ができる' },
        { id: 'trait-appears', text: '子の遺伝子の組合せに応じて形質が現れる' },
        { id: 'meiosis', text: '生殖細胞が減数分裂で染色体を半分にする' },
        { id: 'body-division', text: '受精卵が体細胞分裂を繰り返して育つ' },
      ],
      solution: {
        orderedItemIds: [
          'meiosis',
          'fertilization',
          'body-division',
          'trait-appears',
        ],
      },
    },
  },
  evolution: {
    foundation: {
      kind: 'sequence',
      operation: 'causalOrder',
      items: [
        { id: 'ratio-shift', text: '世代を経て集団の形質の割合が変わる' },
        { id: 'variation', text: '集団の中に形質のばらつきがある' },
        { id: 'evolved', text: '種としての姿が変わり、進化が起きる' },
        { id: 'selection', text: '環境に合った形質をもつ個体が多く子を残す' },
      ],
      solution: {
        orderedItemIds: [
          'variation',
          'selection',
          'ratio-shift',
          'evolved',
        ],
      },
    },
    conditions: {
      kind: 'singleSelect',
      operation: 'prediction',
      items: [
        { id: 'bright-moth-wins', text: '暗い樹皮の森では明るい色の蛾が目立たず増える' },
        { id: 'ratio-stays', text: '色のばらつきは変化に関係ないので、数の割合は変わらない' },
        { id: 'dark-moth-wins', text: '暗い樹皮に似た暗色の蛾が見つかりにくく、数の割合が増える' },
      ],
      solution: { selectedItemId: 'dark-moth-wins' },
    },
    transfer: {
      kind: 'classify',
      operation: 'conditionClassify',
      items: [
        { id: 'giraffe-effort', text: '高い葉を食べようと首を伸ばした姿が子に伝わった' },
        { id: 'giraffe-variation', text: '祖先に首の長さのばらつきがあり、長い個体が多く子を残した' },
        { id: 'moth-selection', text: '暗い色の蛾が見つかりにくく、多く残された' },
        { id: 'whale-effort', text: '水中で足を使わなくなった個体の変化が子に伝わった' },
      ],
      targets: [
        { id: 'natural-selection', label: '自然選択での説明' },
        { id: 'use-disuse', label: '用不用進説での説明' },
      ],
      solution: {
        targetByItemId: {
          'giraffe-effort': 'use-disuse',
          'giraffe-variation': 'natural-selection',
          'moth-selection': 'natural-selection',
          'whale-effort': 'use-disuse',
        },
      },
    },
  },
}
