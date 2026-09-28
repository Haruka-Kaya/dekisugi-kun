import type { UnitContentText } from '../i18n-content.js'

const CHARACTERS = {
  mio: { name: 'Mio', role: 'Observation and safety checks' },
  dekisugi: { name: 'Dekisugi-kun', role: 'Overconfident hypotheses' },
  ren: { name: 'Ren', role: 'Checking conditions and records' },
}

export const lifeContinuityContent: UnitContentText = {
  unitId: 'life-continuity',
  concepts: {
    reproduction: {
      practice: {
        foundation: {
          recallPrompt:
            'Explain how cells increasing by division relates to the growth of a multicellular organism, in terms of both the number and the size of cells.',
          reasoningPrompt:
            'Add one observation that the explanation “the cells themselves just keep getting bigger” cannot account for.',
          expectedOutcome:
            'In the record of an onion root tip, chromosomes are copied and divided between two cells in the region where cell division happens; '
            + 'the number of cells increases, each cell then grows, and the root gets longer.',
          expectedReason:
            'Cells increase in number by dividing while staying about the same size, and each new cell then grows, '
            + 'so a body grows through both an increase in cells and the growth of each cell.',
          cognitiveTask: {
            items: {
              'cell-split': 'The cell splits into two, and more cells of the same kind appear',
              'chromosome-copy': 'The chromosomes inside the nucleus are copied',
              'cell-growth': 'Each new cell grows, and that part of the body gets bigger',
              'chromosome-split': 'The copied chromosomes are divided between two nuclei',
            },
          },
        },
        conditions: {
          recallPrompt:
            'Explain the difference between sexual and asexual reproduction in terms of how the parents’ chromosomes pass to the offspring.',
          reasoningPrompt:
            'Go beyond whether fertilization happens: add how meiosis fits in.',
          transferPrompt:
            'You have a record of a frog’s fertilized egg developing and a record of a potato sprout growing. '
            + 'Compare how the chromosomes of each offspring relate to its parent(s).',
          expectedOutcome:
            'The young frog carries a combination of chromosomes from both parents, while the potato sprout carries the same chromosomes as its parent.',
          expectedReason:
            'In sexual reproduction, sex cells whose chromosomes were halved by meiosis join in fertilization, so the offspring inherits chromosomes from both parents; '
            + 'in asexual reproduction, part of the parent’s body becomes a new individual directly, so it has the same chromosomes.',
          checkpoint: {
            lure: 'An offspring with traits different from its parents appeared because the parent changed its chromosomes to suit the offspring.',
            options: {
              'chromosome-mix': {
                text: 'In sexual reproduction, the combination of chromosomes inherited from the two parents is set, so offspring differ a little from their parents.',
              },
              'parent-adjusts': {
                text: 'Parents adjust the chromosomes they pass on so they can make offspring that fit the environment.',
                hint: 'Think about the process that decides the chromosomes: the roles of meiosis and fertilization.',
              },
              'mutation-required': {
                text: 'Any trait different from the parents can only be explained by mutation.',
                hint: 'Think about the mechanism that lets the same parents produce offspring with different combinations.',
              },
            },
            explanation:
              'An offspring of sexual reproduction inherits chromosomes separately from each parent, '
              + 'so its combination differs even from its parents. The parents do not change it on purpose, and no mutation is needed.',
          },
          cognitiveTask: {
            items: {
              'frog-fertilized-egg': 'A frog’s fertilized egg develops',
              'potato-sprout': 'A new plant grows from a potato sprout',
              'strawberry-runner': 'A new plant forms at the tip of a strawberry runner',
              'chicken-egg': 'A chicken’s fertilized egg develops',
            },
            targets: {
              sexual: 'Sexual reproduction',
              asexual: 'Asexual reproduction',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Explain how the difference between offspring of sexual and asexual reproduction affects the diversity of a population.',
          reasoningPrompt:
            'Add why a population that increases only by asexual reproduction is vulnerable to environmental change, explained in terms of variation in traits.',
          transferPrompt:
            'There is a record of strawberries propagated vegetatively in one field all dying together from a disease, '
            + 'and a record of a field grown from seeds where some plants survived. Explain this difference.',
          expectedOutcome:
            'The vegetatively propagated strawberries had nearly identical traits, so every plant was vulnerable to the same disease; '
            + 'the seed-grown field had variation in traits, so resistant individuals survived.',
          expectedReason:
            'Offspring of asexual reproduction have the same chromosomes as the parent, so the population’s traits are uniform; '
            + 'sexual reproduction produces offspring with different combinations, so variation remains.',
          checkpoint: {
            lure: 'Plants that increase by asexual reproduction form populations that are also strong against environmental change.',
            options: {
              'numbers-strength': {
                text: 'The more a population grows, the stronger it gets, so increasing fast by asexual reproduction makes it stronger against change.',
                hint: 'Consider that the difference in strength comes from variation in traits, not from numbers.',
              },
              'clone-adapts': {
                text: 'Even with the same chromosomes, each individual can change its traits to fit the environment.',
                hint: 'Distinguish between individuals changing their traits to cope and a question of variation within the population.',
              },
              'uniform-population-fragile': {
                text: 'In asexual reproduction traits are uniform, so when the environment changes the whole population shares the same weakness.',
              },
            },
            explanation:
              'Offspring of asexual reproduction have the same chromosomes as the parent, so the population’s traits are uniform, '
              + 'and the whole population shares the same weakness to disease or changes in climate.',
          },
          cognitiveTask: {
            items: {
              'sexual-diverse':
                'The field grown by sexual reproduction has variation in traits, so some plants survive the disease.',
              'asexual-stronger':
                'The field grown by asexual reproduction is as strong as the parent, so every plant survives the disease.',
              'both-same':
                'Both ways of reproducing give the same resistance to the disease, so there is no difference in which plants survive.',
            },
          },
        },
      },
      story: {
        title: 'The Case of the Fake Potato at Lookalike Precinct',
        setting:
          'A shelf in the science prep room. A sprouting potato sits beside an observation record of frogs developing from fertilized eggs.',
        characters: CHARACTERS,
        openingLines: {
          'reproduction.open.1':
            'The potato’s sprouts come straight out of the parent’s surface. There’s no record of pollination or fertilization anywhere.',
          'reproduction.open.2':
            'The frog side definitely has a record of sperm fertilizing an egg. These two reproduce in totally different ways.',
          'reproduction.open.3':
            'All living things fall in love and fertilize! Potatoes must have a secret romance too!',
        },
        choiceResponses: {
          'fertilization-always':
            'See? Potatoes have a hidden love story too... wait, they don’t?!',
          'asexual-same-chromosomes':
            'When a new individual with the same chromosomes grows from part of the parent’s body, that’s asexual reproduction. No romance required.',
          'sexual-identical':
            'A fertilized offspring combines chromosomes from both parents, so it actually ends up with a different combination from its parents.',
        },
        resolutionLines: {
          'reproduction.resolve.1':
            'Cells increase by dividing, and a body grows through more cells plus the growth of each cell.',
          'reproduction.resolve.2':
            'Sexual reproduction passes on chromosomes from both parents through meiosis and fertilization. Asexual reproduction makes offspring with the same chromosomes as the parent.',
        },
        punchline:
          'So potatoes multiply without ever going on a date! Lookalike Precinct closes the case: asexual reproduction!',
      },
      notation: {
        tasks: {
          'reproduction.sequence': {
            title: 'Put the steps of mitosis in order',
            prompt: 'Reorder the record of mitosis in an onion root tip into the order the steps happen.',
            guide:
              'It starts with the chromosomes being copied, then the cell splits to make more cells, and the cells grow so the body gets bigger.',
            tokens: {
              'chromosome-copy': 'Chromosomes are copied',
              'chromosome-split': 'Chromosomes are divided between two nuclei',
              'cell-split': 'The cell splits into two, increasing the number of cells',
              'cell-growth': 'The new cells grow and the body gets bigger',
            },
            solutionSummary: 'The order is copy → divide → split → cell growth.',
          },
          'reproduction.tableRead': {
            title: 'Read the table of reproduction types and chromosomes',
            prompt:
              'From the record of chromosomes in offspring of sexual and asexual reproduction, choose the correct match.',
            representation: [
              'Type of reproduction | Fertilization | Offspring’s chromosomes',
              'Sexual reproduction | Yes | Combines chromosomes from both parents',
              'Asexual reproduction | No | Same chromosomes as the parent',
            ],
            representationSemanticsLabel:
              'Whether fertilization happens decides whether the offspring combines chromosomes from both parents or has the same ones as the parent.',
            choices: {
              'sexual-same': 'Offspring of sexual reproduction have the same chromosomes as the parent',
              'correct-pair':
                'Offspring of asexual reproduction have the same chromosomes as the parent, and offspring of sexual reproduction have a combination from both parents',
              'asexual-diverse': 'Offspring of asexual reproduction have different chromosomes from their siblings',
            },
            solutionSummary:
              'In asexual reproduction, an individual with the same chromosomes as the parent grows from part of the parent’s body.',
          },
          'reproduction.modelBuild': {
            title: 'Build the path from sex cells to an adult',
            prompt:
              'Assemble, step by step, the path by which a new individual grows from a fertilized egg in sexual reproduction.',
            guide:
              'Sex cells halved by meiosis join in fertilization, and the fertilized egg grows by mitosis.',
            tokens: {
              meiosis: 'Sex cells form by meiosis',
              fertilization: 'Fertilization makes a fertilized egg',
              'body-division': 'The fertilized egg divides by mitosis again and again',
              adult: 'A new individual grows',
            },
            solutionSummary: 'The path is meiosis → fertilization → mitosis → adult.',
          },
        },
      },
    },
    heredity: {
      practice: {
        foundation: {
          recallPrompt:
            'Explain what contrasting traits, dominant and recessive mean, using the example of pea seed shape.',
          reasoningPrompt:
            'Add the observation that when pure round and pure wrinkled lines are crossed, all the children are round.',
          expectedOutcome:
            'Crossing a pure round line with a pure wrinkled line gives all round seeds, '
            + 'and crossing those children with each other gives round and wrinkled in a ratio of about 3:1.',
          expectedReason:
            'Round, which appears in the children, is the dominant trait; wrinkled, which did not appear, is the recessive trait. '
            + 'The wrinkled gene did not disappear — it stayed in the children and appears in the next generation.',
          cognitiveTask: {
            items: {
              'all-dominant': 'All the offspring show the dominant trait',
              'three-to-one': 'The offspring show the dominant and recessive traits in a ratio of about 3:1',
              'half-half': 'The offspring show the dominant and recessive traits half and half',
            },
          },
        },
        conditions: {
          recallPrompt:
            'Explain how gene combinations (AA, Aa, aa) match up with traits, as the conditions under which the dominant trait appears.',
          reasoningPrompt:
            'Add why you cannot say “an individual showing the dominant trait must be AA.”',
          transferPrompt:
            'Two parent plants with round seeds produced both round and wrinkled offspring. '
            + 'Infer both parents’ gene combinations and explain the offspring’s combinations.',
          expectedOutcome:
            'Since a wrinkled offspring (aa) appeared, both parents are Aa, each carrying a, '
            + 'and the offspring’s possible combinations are AA, Aa, Aa and aa.',
          expectedReason:
            'An aa offspring must inherit a from each parent, '
            + 'and a parent showing the dominant trait is not necessarily AA — it can also be Aa.',
          checkpoint: {
            lure: 'Children of two parents showing the dominant trait turned out recessive because the genes degraded during crossing.',
            options: {
              'aa-from-aa-parents': {
                text: 'If both parents are Aa, an aa child that inherited a from each parent can form, and the recessive trait appears.',
              },
              'gene-degraded': {
                text: 'Genes get weaker with every cross, so eventually the recessive trait appears.',
                hint: 'Think about whether genes degrade, or whether aa forms as a result of the combination.',
              },
              'random-appearance': {
                text: 'Recessive traits appear without any fixed rule, so the probability cannot be explained.',
                hint: 'Think about what ratio the offspring combinations have in an Aa × Aa cross.',
              },
            },
            explanation:
              'In an Aa × Aa cross the offspring combinations are AA, Aa, Aa and aa, '
              + 'so about a quarter of the time an aa child forms and the recessive trait appears. The genes did not degrade.',
          },
          cognitiveTask: {
            items: {
              'genotype-aa': 'Gene combination is aa',
              'genotype-aa-big': 'Gene combination is AA',
              'genotype-aa-hybrid': 'Gene combination is Aa',
              'genotype-aa-again': 'Another pair’s combination is aa',
            },
            targets: {
              'dominant-trait': 'Dominant trait appears',
              'recessive-trait': 'Recessive trait appears',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Explain how genes, chromosomes and DNA are related, as the path by which traits pass from parent to child.',
          reasoningPrompt:
            'Add how genes riding on chromosomes relates to meiosis and fertilization.',
          transferPrompt:
            'There is an observation record in which a child’s earlobe shape differs from both parents’. '
            + 'Explain this difference using the path genes travel (meiosis → fertilization).',
          expectedOutcome:
            'In the parents’ cells, meiosis halves the chromosomes, and through fertilization the child inherits chromosomes from both parents. '
            + 'The combination of genes that decides earlobe shape can differ between parents and child.',
          expectedReason:
            'Genes ride on chromosomes into the sex cells, and fertilization combines those from both parents, '
            + 'so a child can end up with a combination different from either parent.',
          checkpoint: {
            lure: 'The genes that pass on traits move from parent to child through the blood.',
            options: {
              'blood-carries': {
                text: 'Just as blood types are related between parents and children, traits are passed on through the blood.',
                hint: 'Think about which cells genes pass through on their way from parent to child.',
              },
              'dna-direct-body': {
                text: 'Genes move directly from any cell in the body into the child’s body, so every trait is passed on as an average.',
                hint: 'Think about the path through sex cells and how many genes get passed on.',
              },
              'chromosome-gametes': {
                text: 'Genes ride on chromosomes into the sex cells, and fertilization passes those from both parents to the child.',
              },
            },
            explanation:
              'Genes ride on chromosomes and pass from both parents to the child by fertilization, '
              + 'through sex cells halved by meiosis. They do not move directly from the blood or body cells.',
          },
          cognitiveTask: {
            items: {
              fertilization: 'The parents’ sex cells join in fertilization, making a fertilized egg',
              'trait-appears': 'Traits appear according to the child’s gene combination',
              meiosis: 'Sex cells halve their chromosomes by meiosis',
              'body-division': 'The fertilized egg grows by repeated mitosis',
            },
          },
        },
      },
      story: {
        title: 'The Case of the Wrinkled Seed’s Surprise Comeback',
        setting:
          'A lab bench in the science prep room. Pea-cross record cards are spread out, with one line highlighted: a wrinkled child from round parents.',
        characters: CHARACTERS,
        openingLines: {
          'heredity.open.1':
            'The children of pure round and pure wrinkled lines are all round. But wrinkled shows up again in the grandchildren from crossing those children.',
          'heredity.open.2':
            'Wrinkled didn’t disappear — it was still inside the children. It shows up cleanly in a 3:1 ratio.',
          'heredity.open.3':
            'Round parents can never have a wrinkled child! Hey, record keeper, you wrote it down wrong!',
        },
        choiceResponses: {
          'dominant-only':
            'Told you it was a typo! Dominant parents can’t have a recessive child!',
          'recessive-reappears':
            'If the round parents are both Aa, an aa child can form and wrinkled appears. It’s not a typo.',
          'half-blend':
            'Traits don’t blend half and half — depending on the combination, one or the other appears.',
        },
        resolutionLines: {
          'heredity.resolve.1':
            'Gene A decides round, and a is wrinkled. If parents showing the dominant trait carry Aa, an aa child can appear.',
          'heredity.resolve.2':
            'Genes ride on chromosomes and pass on through meiosis and fertilization. Their substance is DNA.',
        },
        punchline:
          'The wrinkles never left! They were hiding inside the parents and made a comeback in the grandkids. Sorry, record keeper — you were right all along!',
      },
      notation: {
        tasks: {
          'heredity.tableRead': {
            title: 'Read the table of cross results',
            prompt:
              'From the pea-cross record, choose the correct match between gene combinations and traits.',
            representation: [
              'Cross | Offspring combinations | Trait that appears',
              'AA × aa | Aa | All dominant',
              'Aa × Aa | AA, Aa, aa | Dominant : recessive = 3 : 1',
            ],
            representationSemanticsLabel:
              'With at least one A the dominant trait appears; only with aa does the recessive trait appear.',
            choices: {
              'aa-dominant': 'The dominant trait appears even with the combination aa',
              'correct-ratio': 'Offspring of Aa × Aa show the dominant and recessive traits in about a 3:1 ratio',
              'half-half': 'Offspring of Aa × Aa are half dominant and half recessive',
            },
            solutionSummary:
              'In Aa × Aa the offspring combinations are AA, Aa, Aa and aa, so the traits appear in about a 3:1 ratio.',
          },
          'heredity.modelBuild': {
            title: 'Build the path genes take',
            prompt:
              'Assemble the path by which traits pass from parent to child, step by step through chromosomes and genes.',
            guide:
              'Genes ride on chromosomes, are halved by meiosis, and combine at fertilization.',
            tokens: {
              'gene-on-chromosome': 'Genes ride on chromosomes',
              meiosis: 'Meiosis halves the chromosomes in sex cells',
              fertilization: 'Fertilization combines chromosomes from both parents',
              trait: 'Traits appear according to the combination',
            },
            solutionSummary: 'The path is genes on chromosomes → meiosis → fertilization → traits.',
          },
          'heredity.graphRead': {
            title: 'Read the graph of trait ratios',
            prompt:
              'From the graph showing the ratio of traits in Aa × Aa offspring, choose the correct reading.',
            representation: [
              'Offspring’s trait | Number of individuals',
              'Dominant trait | About 3/4',
              'Recessive trait | About 1/4',
            ],
            representationSemanticsLabel:
              'Individuals with the dominant trait are about three times as many as those with the recessive trait.',
            choices: {
              equal: 'Dominant and recessive appear in equal numbers',
              'three-quarter': 'The dominant trait makes up about three quarters',
              'recessive-more': 'The recessive trait appears more often',
            },
            solutionSummary:
              'aa is one of the four combinations, so the recessive trait is about one quarter.',
          },
        },
      },
    },
    evolution: {
      practice: {
        foundation: {
          recallPrompt:
            'Explain why fossils are evidence that living things have changed, by matching the age of strata with the forms of living things.',
          reasoningPrompt:
            'Add the difference between “different living things appear in each layer” and “the same living things gradually change.”',
          expectedOutcome:
            'Following the layers from oldest to newest, living things with different forms, such as trilobites and ammonites, '
            + 'appear matching the era of each layer, and the record shows closely related forms lined up step by step.',
          expectedReason:
            'Deeper strata are older, so fossils record the forms of living things that lived in that era. '
            + 'Forms changing in the order of the layers is evidence that the kinds of living things have changed over time.',
          cognitiveTask: {
            items: {
              'ratio-shift': 'Over generations, the ratio of traits in the population changes',
              variation: 'There is variation in traits within the population',
              evolved: 'The form of the species changes, and evolution occurs',
              selection: 'Individuals with traits that fit the environment leave more offspring',
            },
          },
        },
        conditions: {
          recallPrompt:
            'Explain evolution by natural selection along the path “variation → those that fit the environment survive → the ratio of traits changes.”',
          reasoningPrompt:
            'Add that individuals did not change, explained in terms of the ratio of traits within the population.',
          transferPrompt:
            'In a forest with dark tree bark, the numbers of light-colored and dark-colored moths have been recorded. '
            + 'Use natural selection to explain why dark-colored moths increased.',
          expectedOutcome:
            'In a moth population that already varied in color, dark moths resembling the dark bark were harder for birds to spot '
            + 'and left more offspring, so over generations the proportion of dark individuals increased.',
          expectedReason:
            'Individual moths did not change color; among the variation already present, '
            + 'individuals with colors that fit the environment were more often left behind, so the ratio of traits in the population changed.',
          checkpoint: {
            lure: 'When the environment changes, living things acquire the traits they need afterward, and those traits pass to their offspring.',
            options: {
              'variation-selected': {
                text: 'Among the variation already present, traits that fit the environment are left behind, and the ratio of traits in the population changes.',
              },
              'acquire-needed-trait': {
                text: 'Individuals acquire the traits the environment requires, and those acquired traits pass to their offspring, causing evolution.',
                hint: 'Think about whether individuals change, or whether the traits left behind in the population change.',
              },
              'all-mutate': {
                text: 'When the environment changes, everyone in the population mutates in the same direction, so they can adapt right away.',
                hint: 'Think about whether mutations happen to fit the environment, or whether variation that arose independently gets selected.',
              },
            },
            explanation:
              'In evolution, from variation in traits that already existed, those fitting the environment leave more offspring. '
              + 'Individuals do not acquire needed traits and pass them on.',
          },
          cognitiveTask: {
            items: {
              'bright-moth-wins': 'In a forest with dark bark, light-colored moths don’t stand out and increase',
              'ratio-stays': 'Variation in color has nothing to do with the change, so the ratio of numbers stays the same',
              'dark-moth-wins': 'Dark moths resembling the dark bark are hard to spot, so their share of the numbers increases',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Explain the difference between evolution and the “use and disuse” theory (organs that get used develop and pass to offspring) in terms of what unit the change happens in.',
          reasoningPrompt:
            'Using the giraffe’s neck, add how the two ideas explain the same observation differently.',
          transferPrompt:
            'Explain the record of long-necked giraffes that could eat high leaves appearing, using two ideas — '
            + '“they stretched their necks by effort” and “they were selected from variation” — '
            + 'and decide which one fits the fossil record.',
          expectedOutcome:
            'The effort idea says a neck an individual stretched passes to its offspring, '
            + 'while the natural selection idea says ancestors varied in neck length '
            + 'and the longer individuals, able to eat high leaves, left more offspring. '
            + 'Fossils showing step-by-step changes in form agree with natural selection.',
          expectedReason:
            'From the evidence that acquired traits are not passed to offspring, '
            + 'and the observation that the traits left behind in a population change, '
            + 'evolution is explained as a change in the ratio of traits in a population, not a change in individuals.',
          checkpoint: {
            lure: 'Fossil organisms differ from today’s because ancient living things suddenly transformed into other species partway through.',
            options: {
              'sudden-transform': {
                text: 'In one generation they transformed completely into a different organism, so no in-between forms exist.',
                hint: 'Think about whether the record from older to newer layers is broken up or step by step.',
              },
              'extinct-only': {
                text: 'Fossil organisms all simply went extinct and have nothing to do with living things today.',
                hint: 'Think about how to explain the record of closely related forms lined up in the order of the layers.',
              },
              'gradual-change': {
                text: 'Over long spans of time the traits left behind changed little by little, and the species’ form changed step by step.',
              },
            },
            explanation:
              'Fossils show a record of closely related forms changing step by step, in order from older to newer layers. '
              + 'Evolution is a change in the ratio of traits over long spans of time, not a sudden transformation.',
          },
          cognitiveTask: {
            items: {
              'giraffe-effort': 'The neck stretched to eat high leaves was passed to the offspring',
              'giraffe-variation': 'Ancestors varied in neck length, and the longer ones left more offspring',
              'moth-selection': 'Dark-colored moths were hard to spot and more of them were left behind',
              'whale-effort': 'Changes in individuals that stopped using their legs in the water were passed to their offspring',
            },
            targets: {
              'natural-selection': 'Explanation by natural selection',
              'use-disuse': 'Explanation by the use and disuse theory',
            },
          },
        },
      },
      story: {
        title: 'The Case of the Shuffled Fossil Lineup',
        setting:
          'The science room after school. Photos of fossils from each layer are lined up in time order, confirming that forms differ between old and new layers.',
        characters: CHARACTERS,
        openingLines: {
          'evolution.open.1':
            'Looking from the old layers to the new ones in order, the forms of living things change little by little.',
          'evolution.open.2':
            'Deeper layers are older, so fossils are a record of the forms from that era.',
          'evolution.open.3':
            'Giraffes stretched their necks every day because they wanted to eat high leaves! Hard work pays off!',
        },
        choiceResponses: {
          'effort-inherited':
            'The neck they worked so hard to stretch passes to their kids! The fruit of their effort!',
          'selection-variation':
            'Individuals didn’t stretch their necks — among the variation that was already there, the longer ones were the ones left behind.',
          'species-fixed':
            'If species never changed, you couldn’t explain a record where the forms change layer by layer.',
        },
        resolutionLines: {
          'evolution.resolve.1':
            'Natural selection keeps the traits that fit the environment from among the variation. That builds up into evolution.',
          'evolution.resolve.2':
            'The fossil record of forms changing in the order of the layers is the evidence that living things have changed.',
        },
        punchline:
          'So their necks didn’t grow from hard work — the long-necked relatives just left more offspring! Sorry, giraffes, for calling you try-hards!',
      },
      notation: {
        tasks: {
          'evolution.sequence': {
            title: 'Put the steps of natural selection in order',
            prompt:
              'Reorder the record of moth colors changing in a forest with dark bark into the order of natural selection.',
            guide:
              'The order is variation → individuals that fit the environment survive → the ratio changes → evolution.',
            tokens: {
              variation: 'The population varies in color',
              selection: 'Dark moths are hard to spot and more of them survive',
              'ratio-shift': 'Over generations, the share of dark moths increases',
              evolved: 'The population’s form changes',
            },
            solutionSummary:
              'The order goes from variation, through selection, to a change in the population’s form.',
          },
          'evolution.tableRead': {
            title: 'Read the table of strata and fossils',
            prompt:
              'From the record of fossils at each depth of the strata, correctly read how living things have changed.',
            representation: [
              'Layer | Era | Fossils found',
              'Deep layer | Old | Trilobites, ammonites',
              'Shallow layer | New | Living things close to today’s forms',
            ],
            representationSemanticsLabel:
              'Deeper layers are older, and the forms of living things change in the order of the layers.',
            choices: {
              'same-species': 'Every layer has fossils of only the same living things',
              'chronological-change': 'The forms of living things change in order from older to newer layers',
              'random-order': 'There is no connection between the kinds of fossils and the depth of the layer',
            },
            solutionSummary:
              'Deeper strata are older, so differences in fossil forms are a record of how living things have changed.',
          },
          'evolution.symbolMatch': {
            title: 'Choose the formula that describes evolution',
            prompt: 'Choose the formula that correctly represents evolution by natural selection.',
            representation: [
              'Cause | Result',
              'Selection among variation | Change in the ratio of traits in the population',
            ],
            representationSemanticsLabel:
              'Not a change in individuals, but a change in the ratio of traits left behind in the population.',
            choices: {
              'selection-equation': 'Variation in traits + selection by the environment → change in the population’s form',
              'effort-equation': 'Traits an individual acquires → passed straight to the offspring',
              'mutation-equation': 'A mutation → a different species appears all at once',
            },
            solutionSummary:
              'Evolution happens as traits that fit the environment are left behind from among the variation.',
          },
        },
      },
    },
  },
}
