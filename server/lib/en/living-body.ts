import type { UnitContentText } from '../i18n-content.js'

const CHARACTERS = {
  mio: { name: 'Mio', role: 'Observation and safety checks' },
  dekisugi: { name: 'Dekisugi-kun', role: 'Overconfident hypotheses' },
  ren: { name: 'Ren', role: 'Checking conditions and records' },
}

export const livingBodyContent: UnitContentText = {
  unitId: 'living-body',
  concepts: {
    cells: {
      practice: {
        foundation: {
          recallPrompt:
            'Explain the basic structures shared by plant and animal cells separately from the structures '
            + 'characteristic of plants.',
          reasoningPrompt:
            'Using differences between plant tissues, add why a cell cannot be judged to be an animal cell '
            + 'just because no chloroplasts are visible.',
          expectedOutcome:
            'Both images share features such as boundaries that divide cells and visible internal structures, '
            + 'and the plant image can be organized by features such as the regular boundaries formed by cell walls.',
          expectedReason:
            'Plant and animal cells share basic structures but differ in features such as cell walls. How cells '
            + 'look changes with magnification, staining, and the tissue sampled, so several features are used.',
          cognitiveTask: {
            items: {
              'cell-wall': 'Cell wall',
              'cell-membrane': 'Cell membrane',
              chloroplast: 'Chloroplasts, seen in photosynthetic cells',
              cytoplasm: 'Cytoplasm',
            },
            targets: {
              shared: 'Shared by plants and animals',
              'plant-feature': 'Characteristic of plants',
            },
          },
        },
        conditions: {
          recallPrompt:
            'Explain why, when a structure is not visible in a microscope image, you cannot immediately say '
            + '“that structure is not there.”',
          reasoningPrompt:
            'Add why conditions such as magnification and staining need to be kept the same when observing '
            + 'and comparing plant and animal cells.',
          transferPrompt:
            'Image A shows a cell wall but no chloroplasts. Image B shows no cell wall, and its nuclei are '
            + 'stained. For A and B, separate what you can say from what you cannot conclude for certain.',
          expectedOutcome:
            'A shows a cell wall, which supports a plant origin, but the lack of chloroplasts alone does not '
            + 'mean it is not a plant. B may be an animal cell, but the image conditions and the tissue sampled '
            + 'need to be checked.',
          expectedReason:
            'Cell walls are characteristic of plant cells, but not every plant cell has chloroplasts. Also, a '
            + 'structure can fail to appear because of magnification or staining conditions.',
          checkpoint: {
            lure:
              'If no nucleus is visible in a microscope image, you can conclude for certain that the cell has '
              + 'no nucleus.',
            explanation:
              'Not seeing something in an image is not enough to conclude it is absent. Check the observation '
              + 'conditions and the part of the sample, and judge from several images and features.',
            options: {
              'absence-certain': {
                text: 'A structure that does not appear in the image does not exist in that cell.',
                hint:
                  'Consider how magnification, focus, the position of the section, and staining change '
                  + 'what you can see.',
              },
              'all-have-visible': {
                text:
                  'Every structure shows up equally bright in every image, so nothing can be missed.',
                hint:
                  'Think about why stains are used in microscope observation and why the focus is adjusted.',
              },
              'check-observation': {
                text:
                  'Check whether something is not visible because of the observation conditions or because '
                  + 'the structure really differs, using the magnification, staining, and tissue sampled.',
              },
            },
          },
          cognitiveTask: {
            items: {
              'compare-features':
                'Organize the similarities and differences using several features.',
              'check-source':
                'Check the image’s magnification, staining, and the tissue it was taken from.',
              'observe-image':
                'Record the boundaries and the internal structures you can see.',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Explain how cells, tissues, organs, and the whole organism are related, going in order from the '
            + 'smallest structures to the largest functions.',
          reasoningPrompt:
            'Add how the fact that not all cells in a multicellular organism have the same shape or job helps '
            + 'the body work as a whole.',
          transferPrompt:
            'A cross-section image of a leaf shows cells covering the surface and inner cells with many '
            + 'chloroplasts. Explain why they look different even though they come from the same organism, '
            + 'and what can be said about both.',
          expectedOutcome:
            'The surface and inner cells differ in shape and in how their chloroplasts appear, showing '
            + 'different roles depending on location. Still, both are cells that make up the plant.',
          expectedReason:
            'In a multicellular organism, cells have features suited to their roles and form tissues. Even in '
            + 'the same plant, not every cell shows the same structures.',
          checkpoint: {
            lure:
              'Cells from the same organism all have exactly the same shape and structures, even if their '
              + 'location and role differ.',
            explanation:
              'In a multicellular organism, cells have features suited to their location and role, and they '
              + 'form tissues and organs. Even in the same organism, not every cell looks the same.',
            options: {
              'specialized-cells': {
                text:
                  'Even in the same organism, cell shapes and prominent structures differ depending on their '
                  + 'role, and each type forms tissues.',
              },
              'identical-cells': {
                text:
                  'The cells that make up one organism have exactly the same shape and job everywhere.',
                hint:
                  'Think about how jobs differ by location, such as the leaf surface versus its interior, '
                  + 'or roots versus leaves.',
              },
              'different-organisms': {
                text:
                  'Cells with different shapes never occur in the same organism; they must come from '
                  + 'different living things.',
                hint:
                  'Remember that a single multicellular organism has several kinds of tissues and organs.',
              },
            },
          },
          cognitiveTask: {
            items: {
              'one-feature':
                'Decide where every cell came from based only on whether it has chloroplasts.',
              'multiple-evidence':
                'Judge by combining several features, such as a cell wall, with the tissue sampled and the '
                + 'observation conditions.',
              'shape-only': 'Sort plants from animals only by whether the cells are round or square.',
            },
          },
        },
      },
      story: {
        title: 'The Missing Chloroplasts and the Root’s Testimony',
        setting:
          'The image-resource corner of the science room, with microscope images of leaf cells, root cells, '
          + 'and animal tissue laid out side by side.',
        characters: CHARACTERS,
        openingLines: {
          'cells.open.1':
            'The root cell image shows cell walls, but I can’t find any chloroplasts.',
          'cells.open.2':
            'Let’s also check the image records for the tissue sampled, the magnification, and the staining.',
          'cells.open.3':
            'If the chloroplasts are absent, this root must have transferred to the animal kingdom!',
        },
        choiceResponses: {
          'shape-alone':
            'If even plant root cells had to have chloroplasts, that wouldn’t match what we observe.',
          'multiple-features':
            'You used the cell wall and the sampled tissue, not just one feature.',
          'all-animal':
            'If roots were animals, they would have escaped from the flowerpot by now!',
        },
        resolutionLines: {
          'cells.resolve.1':
            'Even among plant cells, some, such as root cells, have no chloroplasts.',
          'cells.resolve.2':
            'We check several similarities and differences and take the observation conditions into '
            + 'account when we judge.',
        },
        punchline:
          'The chloroplasts were absent today, but the root is still enrolled as a plant.',
      },
      notation: {
        tasks: {
          'cells.labelDiagram': {
            title: 'Identify the boundaries in a cell diagram',
            prompt:
              'Choose the name of the thick boundary outside the cell membrane that borders neighboring cells '
              + 'and supports the cell’s shape.',
            solutionSummary:
              'The thick boundary outside the cell membrane that supports the cell’s shape is the cell wall.',
            representation: [
              '┏━━━━━━┓  thick outer boundary',
              '┃  ┌────┐  ┃  inner cell membrane',
              '┗━━━━━━┛',
            ],
            representationSemanticsLabel:
              'Diagram of a plant cell. There is a thick boundary on the outside and, inside it, a thin '
              + 'boundary representing the cell membrane.',
            choices: {
              'cell-membrane': 'Cell membrane',
              'cell-wall': 'Cell wall',
              chloroplast: 'Chloroplast',
            },
          },
          'cells.modelBuild': {
            title: 'Build a model of the body’s levels of organization',
            prompt:
              'Arrange the structure of a multicellular organism from the smallest unit to the largest.',
            guide:
              'Expand from a single cell, to groups of cells with the same job, to organs, to the whole '
              + 'organism.',
            solutionSummary:
              'Cells group together to form tissues, tissues form organs, and organs work together to support '
              + 'the whole organism.',
            tokens: {
              tissue: 'Tissue',
              organ: 'Organ',
              organism: 'Organism',
              cell: 'Cell',
            },
          },
          'cells.tableRead': {
            title: 'Read a table of plant and animal features',
            prompt: 'Using the table, choose the structure shared by plant and animal cells.',
            solutionSummary: 'The cell membrane is shared by plant and animal cells.',
            representation: [
              'Structure | Plant | Animal',
              'Cell membrane | Yes | Yes',
              'Cell wall | Yes | No',
              'Chloroplasts | In some cells | No',
            ],
            representationSemanticsLabel:
              'Table comparing plant and animal cell structures. Both have a cell membrane, plants have a cell '
              + 'wall, and some plant cells have chloroplasts.',
            choices: {
              'cell-wall': 'Cell wall',
              'cell-membrane': 'Cell membrane',
              chloroplast: 'Chloroplast',
            },
          },
        },
      },
    },
    photosynthesisRespiration: {
      practice: {
        foundation: {
          recallPrompt:
            'Using the gases going in and out, explain that photosynthesis and respiration happen at the same '
            + 'time in a plant in light.',
          reasoningPrompt:
            'Add why a net increase in oxygen alone does not show that respiration has stopped.',
          expectedOutcome:
            'In the light data, oxygen increases overall, and in the dark data it decreases, but the '
            + 'respiration column can be recorded as “occurs” under both conditions.',
          expectedReason:
            'In light, the oxygen made by photosynthesis exceeds the oxygen used by respiration. In darkness, '
            + 'photosynthesis does not proceed, so only the oxygen used by respiration tends to show up.',
          cognitiveTask: {
            items: {
              'light-photosynthesis': 'Photosynthesis in light',
              'light-respiration': 'Respiration in light',
              'dark-photosynthesis': 'Photosynthesis in darkness',
              'dark-respiration': 'Respiration in darkness',
            },
            targets: {
              occurs: 'Occurs',
              'not-observed': 'Does not proceed',
            },
          },
        },
        conditions: {
          recallPrompt:
            'Explain the net carbon dioxide exchange at different light intensities as the difference between '
            + 'photosynthesis and respiration.',
          reasoningPrompt:
            'Add that a net exchange of zero does not necessarily mean both processes have stopped.',
          transferPrompt:
            'For the same leaf, the data show almost no net change in carbon dioxide in weak light and a '
            + 'decrease in strong light. Interpret photosynthesis and respiration under each condition.',
          expectedOutcome:
            'In weak light, the carbon dioxide taken in by photosynthesis and the carbon dioxide released by '
            + 'respiration are roughly balanced; in strong light, the uptake by photosynthesis is greater.',
          expectedReason:
            'The measured value is the difference between two processes, and zero does not necessarily mean '
            + 'both have stopped. The comparison needs other conditions, such as temperature, kept the same.',
          checkpoint: {
            lure:
              'If the net change in carbon dioxide is 0, neither photosynthesis nor respiration is happening '
              + 'at all.',
            explanation:
              'A net value of 0 also happens when photosynthesis and respiration proceed at balanced rates. '
              + 'You cannot conclude that either process has stopped.',
            options: {
              'both-stopped': {
                text: 'The exchange is 0, so both processes must have stopped.',
                hint:
                  'Think about the net result when the same amount is taken in as is released.',
              },
              'rates-balance': {
                text:
                  'The uptake by photosynthesis and the release by respiration may be nearly equal, making '
                  + 'the difference 0.',
              },
              'respiration-reverses': {
                text:
                  'In weak light, respiration reverses into a process that absorbs carbon dioxide.',
                hint: 'Check which substances respiration uses and which it produces.',
              },
            },
          },
          cognitiveTask: {
            items: {
              'both-stop': 'The net value is 0, so both processes have stopped.',
              'balanced-rates':
                'The uptake by photosynthesis and the release by respiration are nearly balanced.',
              'respiration-absorbs': 'Respiration absorbs carbon dioxide.',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Using chloroplasts and life processes, explain why leaves and roots differ in whether they carry '
            + 'out photosynthesis and respiration.',
          reasoningPrompt:
            'Add why the gas exchange of a whole plant cannot be determined from the result for a single leaf.',
          transferPrompt:
            'In bright conditions, compare gas-exchange data for branch A, which has leaves, and branch B, '
            + 'whose leaves were removed. Oxygen increased for A and decreased for B. Explain the difference.',
          expectedOutcome:
            'In A, photosynthesis in the leaves exceeds respiration, so oxygen increases overall. In B, there '
            + 'are no photosynthesizing leaves, so the oxygen used by respiration shows up.',
          expectedReason:
            'Photosynthesis proceeds mainly in cells with chloroplasts when there is light, but respiration '
            + 'continues in living cells other than leaves as well.',
          checkpoint: {
            lure:
              'A branch with its leaves removed cannot photosynthesize, so it does not respire either, and '
              + 'the amount of oxygen does not change.',
            explanation:
              'Respiration takes place in a plant’s living cells. Even if removing the leaves reduces '
              + 'photosynthesis, the stem’s respiration continues.',
            options: {
              'all-processes-leaf': {
                text:
                  'Both photosynthesis and respiration happen only in leaves, so both stop in B.',
                hint:
                  'Consider whether root and stem cells also use energy for life processes.',
              },
              'branch-makes-oxygen': {
                text:
                  'Without leaves, the branch gets more light, so oxygen increases for B.',
                hint: 'Check where the cell structures that carry out photosynthesis are concentrated.',
              },
              'respiration-remains': {
                text:
                  'Even with no leaves and little photosynthesis, the living stem cells keep respiring.',
              },
            },
          },
          cognitiveTask: {
            items: {
              'oxygen-decreases': 'The oxygen used by respiration shows up as a net change.',
              'remove-leaves': 'Remove the photosynthesizing leaves from the branch.',
              'stem-respires': 'The living stem cells keep respiring.',
            },
          },
        },
      },
      story: {
        title: 'The Plant Factory’s Night-Shift Breathing Crew',
        setting:
          'A data terminal in the library, showing a fixed graph of oxygen changes for a water plant in '
          + 'light and in darkness.',
        characters: CHARACTERS,
        openingLines: {
          'photosynthesisRespiration.open.1':
            'Oxygen goes up in the light and goes down in the dark.',
          'photosynthesisRespiration.open.2':
            'It’s a net change, so let’s think about photosynthesis and respiration separately.',
          'photosynthesisRespiration.open.3':
            'The plant’s breathing crew works the night shift only. During the day, they’re all off duty!',
        },
        choiceResponses: {
          'both-processes':
            'You read it as the difference between two processes, even in the light.',
          'only-photosynthesis':
            'Cells need energy for life processes during the day, too.',
          'respiration-night-only':
            'Turns out the breathing crew never had separate day and night shifts!',
        },
        resolutionLines: {
          'photosynthesisRespiration.resolve.1':
            'Photosynthesis proceeds when there is light, but respiration continues day and night.',
          'photosynthesisRespiration.resolve.2':
            'The oxygen increase in light is the net result of production exceeding use.',
        },
        punchline:
          'The breathing crew isn’t night-shift only — surprise, they work around the clock.',
      },
      notation: {
        tasks: {
          'photosynthesisRespiration.modelBuild': {
            title: 'Build the matter relationships of photosynthesis',
            prompt:
              'Arrange the substances photosynthesis uses and the substances it makes, including the light '
              + 'condition.',
            guide:
              'Place carbon dioxide and water, then light energy, then organic matter and oxygen, in that order.',
            solutionSummary:
              'Photosynthesis uses light to make organic matter from carbon dioxide and water, releasing oxygen.',
            tokens: {
              light: 'Uses light energy',
              organic: 'Makes organic matter',
              oxygen: 'Releases oxygen',
              inputs: 'Carbon dioxide + water',
            },
          },
          'photosynthesisRespiration.tableRead': {
            title: 'Read a gas table for light and darkness',
            prompt:
              'Choose the correct explanation of the net oxygen change and the two processes.',
            solutionSummary:
              'Respiration continues even in light; the result shows oxygen production by photosynthesis '
              + 'exceeding oxygen use.',
            representation: [
              'Condition | Net oxygen change',
              'Light | +8',
              'Dark | −3',
            ],
            representationSemanticsLabel:
              'Oxygen increased by 8 in light and decreased by 3 in darkness. The values represent the '
              + 'difference between photosynthesis and respiration.',
            choices: {
              'light-only': 'Respiration stops in light',
              'both-light': 'Both occur in light, and photosynthesis is greater',
              'dark-photosynthesis': 'Only photosynthesis occurs in darkness',
            },
          },
          'photosynthesisRespiration.labelDiagram': {
            title: 'Separate the processes in leaves and roots',
            prompt: 'Choose the process that continues in root cells in bright conditions.',
            solutionSummary:
              'Even root cells without chloroplasts carry out respiration for their life processes.',
            representation: [
              'Leaf: many chloroplasts',
              'Stem: living cells',
              'Root: many cells without chloroplasts',
            ],
            representationSemanticsLabel:
              'Diagram of a plant’s leaf, stem, and root. The root is also made of living cells.',
            choices: {
              'photosynthesis-only': 'Photosynthesis only',
              respiration: 'Respiration',
              neither: 'Neither',
            },
          },
        },
      },
    },
    digestionAbsorption: {
      practice: {
        foundation: {
          recallPrompt:
            'Explain digestion and absorption separately, in terms of how the size of substances changes and '
            + 'where they enter the body.',
          reasoningPrompt:
            'Add the difference between being inside the digestive tract and having already been absorbed '
            + 'into the body.',
          expectedOutcome:
            'In the card diagram, large nutrients are broken down into small substances inside the digestive '
            + 'tract and then pass, mainly through the villi of the small intestine, into the blood or lymph.',
          expectedReason:
            'Large nutrient molecules are hard to absorb as they are, so digestive enzymes must make them '
            + 'smaller before they can cross the wall of the digestive tract.',
          cognitiveTask: {
            items: {
              'enter-circulation': 'Enter the blood or lymph through the villi.',
              'large-nutrient': 'Large nutrients enter the digestive tract.',
              'enzyme-breakdown': 'Enzymes break them down into absorbable substances.',
            },
          },
        },
        conditions: {
          recallPrompt: 'Explain that each digestive enzyme acts on different nutrients.',
          reasoningPrompt:
            'Add why comparisons need conditions such as temperature kept the same, not just the enzyme names.',
          transferPrompt:
            'Under the same conditions, enzyme X broke down starch but not protein, and enzyme Y showed the '
            + 'opposite result. Organize what can be said from these results.',
          expectedOutcome:
            'X and Y act on different substances: X acts on starch and Y acts on protein, which shows '
            + 'substrate specificity.',
          expectedReason:
            'An enzyme’s action depends on which substance it is paired with. However, these results alone '
            + 'do not prove the rates would be the same at other temperatures or pH values.',
          checkpoint: {
            lure:
              'With just one digestive enzyme, any nutrient can be broken down under the same conditions at '
              + 'the same rate.',
            explanation:
              'Each digestive enzyme has specific substances it acts on, and the rate of its action also '
              + 'depends on conditions such as temperature and pH.',
            options: {
              'universal-enzyme': {
                text: 'Enzymes act the same way on all nutrients, no matter the type.',
                hint: 'Use the result that the substances X and Y broke down were swapped.',
              },
              'substrate-specific': {
                text:
                  'Each enzyme has substances it acts on, and conditions such as temperature and pH also '
                  + 'affect its action.',
              },
              'enzyme-is-nutrient': {
                text:
                  'The enzyme itself turns into nutrients, which makes everything absorbable.',
                hint:
                  'Distinguish whether an enzyme helps a reaction or is itself the nutrient after breakdown.',
              },
            },
          },
          cognitiveTask: {
            items: {
              'enzyme-x-starch': 'Enzyme X and starch',
              'enzyme-x-protein': 'Enzyme X and protein',
              'enzyme-y-starch': 'Enzyme Y and starch',
              'enzyme-y-protein': 'Enzyme Y and protein',
            },
            targets: {
              breakdown: 'Broken down in the data',
              unchanged: 'No change in the data',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Using surface area and the distance to blood vessels, explain why the villi of the small intestine '
            + 'are suited to absorption.',
          reasoningPrompt:
            'Add not only that there are many villi, but also how their thin walls relate to the capillaries '
            + 'and lymphatic vessels.',
          transferPrompt:
            'Tube A and tube B are the same length. A is flat inside, and B has many model villi. With wall '
            + 'thickness and other factors kept the same, compare their absorption area and how easily '
            + 'substances can move through.',
          expectedOutcome:
            'B has a larger inner surface area, so there are more places where substances can cross the wall '
            + 'at the same time, making it better suited to absorption than A.',
          expectedReason:
            'Villi increase the surface area of the small intestine within its limited length and make it '
            + 'easier to carry nutrients into the capillaries and lymphatic vessels inside them.',
          checkpoint: {
            lure:
              'Villi make the inside of the small intestine flat, reducing its surface area and slowing '
              + 'absorption.',
            explanation:
              'Many villi increase the inner surface area of the small intestine and give nutrients more '
              + 'chances to pass through the wall and be carried away.',
            options: {
              'flatten-surface': {
                text:
                  'Villi smooth out the bumps so that nutrients do not touch the wall.',
                hint: 'Compare the area of a surface with many projections to that of a flat surface.',
              },
              'digestive-teeth': {
                text:
                  'Villi only crush food like teeth and have nothing to do with absorption area.',
                hint: 'Think about the role of the capillaries and lymphatic vessels inside the villi.',
              },
              'increase-area': {
                text:
                  'Villi increase the surface area and make it easier to take broken-down nutrients into '
                  + 'the body.',
              },
            },
          },
          cognitiveTask: {
            items: {
              'flat-faster': 'The flat tube A has a larger absorption area.',
              'same-area': 'If the tubes are the same length, their surface areas are the same.',
              'villi-larger-area':
                'Tube B, with villi, has a larger surface area and is better suited to absorption.',
            },
          },
        },
      },
      story: {
        title: 'Nutrients at Small-Intestine Immigration',
        setting:
          'A materials table outside the nurse’s office. The group uses a digestive-tract diagram and '
          + 'nutrient cards to think it through without touching food or human samples.',
        characters: CHARACTERS,
        openingLines: {
          'digestionAbsorption.open.1':
            'The big starch card can’t pass straight through to the tip of a villus.',
          'digestionAbsorption.open.2':
            'Let’s separate the step where digestion makes things smaller from the step where they cross '
            + 'the wall and are absorbed.',
          'digestionAbsorption.open.3':
            'The stomach handles immigration and transport all by itself. The small intestine just has '
            + 'spectator seats!',
        },
        choiceResponses: {
          'digest-then-absorb':
            'That order is right: break things down first, then absorb them mainly in the small intestine.',
          'stomach-absorbs-all':
            'The stomach alone doesn’t finish absorbing every nutrient.',
          'intestine-only-digests':
            'I thought the capillaries in the villi were part of the spectator gallery!',
        },
        resolutionLines: {
          'digestionAbsorption.resolve.1':
            'Digestive enzymes break large nutrients down into substances that can be absorbed.',
          'digestionAbsorption.resolve.2':
            'Most of them enter the blood or lymph through the villi of the small intestine.',
        },
        punchline:
          'A nutrient’s passport must be stamped “Digested” — and the entry gate is the small intestine.',
      },
      notation: {
        tasks: {
          'digestionAbsorption.sequence': {
            title: 'Order the steps from digestion to absorption',
            prompt: 'Put in order the steps until large nutrients are carried into the body.',
            guide:
              'Connect the digestive tract, breakdown by enzymes, the villi, and the move into circulation.',
            solutionSummary:
              'After digestion makes nutrients smaller, they are absorbed mainly through the villi of the '
              + 'small intestine.',
            tokens: {
              digest: 'Broken into small substances by enzymes',
              villus: 'Pass through the villi of the small intestine',
              circulation: 'Move into the blood and lymph',
              large: 'Large nutrients enter the digestive tract',
            },
          },
          'digestionAbsorption.labelDiagram': {
            title: 'Read the job of villi from a diagram',
            prompt:
              'Choose the main advantage of having many projections on the inside of the small intestine.',
            solutionSummary:
              'Villi increase the inner surface area of the small intestine, making it easier to take in '
              + 'nutrients.',
            representation: [
              'Inside the small intestine ~~~~ many villi',
              'Inside each villus: capillaries and lymphatic vessels',
              'Wall of the digestive tract',
            ],
            representationSemanticsLabel:
              'Diagram showing the many villi on the inner surface of the small intestine and the capillaries '
              + 'and lymphatic vessels inside them.',
            choices: {
              'smaller-area': 'Makes the absorption area smaller',
              'larger-area': 'Makes the absorption area larger',
              'chew-food': 'Chews food instead of the teeth',
            },
          },
          'digestionAbsorption.tableRead': {
            title: 'Read a table of enzyme specificity',
            prompt: 'From the fixed results, choose what can be said about enzyme X.',
            solutionSummary:
              'The data show that X acted on starch under these conditions, but this cannot be generalized '
              + 'to all conditions.',
            representation: [
              'Combination | Broken down',
              'X + starch | Yes',
              'X + protein | No',
              'Y + protein | Yes',
            ],
            representationSemanticsLabel:
              'Enzyme X broke down starch but not protein, and enzyme Y broke down protein.',
            choices: {
              'all-nutrients': 'X breaks down all nutrients',
              'starch-specific': 'X acted on starch under these conditions',
              'temperature-certain': 'It was proven to work at the same rate at every temperature',
            },
          },
        },
      },
    },
  },
}
