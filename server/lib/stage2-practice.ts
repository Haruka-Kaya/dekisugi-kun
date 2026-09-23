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
}
