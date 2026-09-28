import type { UnitContentText } from '../i18n-content.js'

const CHARACTERS = {
  mio: { name: 'Mio', role: 'Observation and safety checks' },
  dekisugi: { name: 'Dekisugi-kun', role: 'Overconfident hypotheses' },
  ren: { name: 'Ren', role: 'Checking conditions and records' },
}

export const chemicalChangeIonsContent: UnitContentText = {
  unitId: 'chemical-change-ions',
  concepts: {
    electrolyte: {
      practice: {
        foundation: {
          recallPrompt:
            'Some aqueous solutions carry an electric current and some do not. Explain this using the words electrolyte and non-electrolyte.',
          reasoningPrompt:
            'Add why a current flows through an electrolyte solution, in terms of particles called ions moving.',
          expectedOutcome:
            'A current flowed through salt water and substances formed at the electrodes, but no current flowed through sugar water and the electrodes did not change.',
          expectedReason:
            'Salt splits into ions when it dissolves, and the moving ions let a current flow. '
            + 'Sugar does not form ions even when it dissolves, so the liquid does not conduct electricity.',
          cognitiveTask: {
            items: {
              'salt-water': 'Water with dissolved salt',
              'sugar-water': 'Water with dissolved sugar',
              'ethanol-water': 'Ethanol solution',
              'dilute-hcl': 'Dilute hydrochloric acid',
            },
            targets: {
              'conducting-liquid': 'Conducts electricity',
              'non-conducting-liquid': 'Does not conduct electricity',
            },
          },
        },
        conditions: {
          recallPrompt:
            'Using salt water and sugar water as examples, explain that dissolving and conducting electricity are different things.',
          reasoningPrompt:
            'Add how changes at the electrodes can be used as a clue to whether a liquid contains ions.',
          transferPrompt:
            'In a record where carbon electrodes were placed in dilute hydrochloric acid and a voltage was applied, gas collected on both electrodes. '
            + 'Explain the evidence that invisible particles are moving in the liquid.',
          expectedOutcome:
            'When a voltage is applied to an electrolyte solution, definite substances form at the anode and the cathode.',
          expectedReason:
            'Charged particles (ions) in the liquid are pulled toward the electrodes, gather there and turn into other substances, '
            + 'so the changes at the electrodes show that ions are present.',
          checkpoint: {
            lure: 'Substances form at the electrodes only because the water in the liquid is changed by electricity.',
            options: {
              'water-split-only': {
                text: 'Water changes in any liquid, so the products should be the same no matter which liquid is used.',
                hint: 'Look back at the record showing that nothing formed at the electrodes in sugar water.',
              },
              'ions-deposited': {
                text: 'Ions in the liquid gather at the electrodes and become substances, so the products depend on the kind of liquid.',
              },
              'heat-changed': {
                text: 'The voltage heats the liquid, and what is left after evaporation simply sticks to the electrodes.',
                hint: 'Check the record to see whether each electrode produced a definite substance.',
              },
            },
            explanation:
              'The substances that form at the electrodes depend on the kind of liquid. '
              + 'This is because ions in the liquid gather at the electrodes and change; water changing alone cannot explain it.',
          },
          cognitiveTask: {
            items: {
              'color-check': 'Look at the color of the liquid and decide it conducts if it is clear.',
              'smell-check': 'Smell the liquid and decide it conducts if it has a sharp odor.',
              'electrode-check': 'Put electrodes in the liquid, apply a voltage, and check whether substances form at the electrodes.',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Explain the difference between electrolytes and non-electrolytes using the results of applying a voltage to their solutions.',
          reasoningPrompt:
            'Add how an ion differs from an atom (it is a particle that has gained or lost electrons and carries a charge).',
          transferPrompt:
            'In a record where salt, sugar and ethanol were each dissolved in water, only the salt water conducted electricity. '
            + 'Also, no current flowed through solid salt. Explain both results using ions.',
          expectedOutcome:
            'Salt splits into ions when dissolved and conducts, while sugar and ethanol do not form ions and do not conduct. '
            + 'Solid salt does not conduct because its ions cannot move.',
          expectedReason:
            'Only once an electrolyte dissolves in water can its ions move freely. '
            + 'A non-electrolyte forms no charged particles even when dissolved, and in a solid the ions cannot move.',
          checkpoint: {
            lure: 'Salt conducts electricity even as a solid, which is why it is called an electrolyte.',
            options: {
              'ions-must-move': {
                text: 'An electrolyte conducts only when it is dissolved and its ions can move. In a solid, the ions cannot move.',
              },
              'solid-salt-conducts': {
                text: 'Salt conducts electricity even while solid, so it is an electrolyte without being dissolved.',
                hint: 'Check the record to see whether a current flowed through solid salt.',
              },
              'all-dissolved-conduct': {
                text: 'Every dissolved substance splits into ions, so an ethanol solution conducts too.',
                hint: 'Think about whether some substances dissolve without forming ions.',
              },
            },
            explanation:
              'What carries electricity is ions that can move. '
              + 'An electrolyte conducts only when it has dissolved in water and split into ions; while solid, its ions cannot move.',
          },
          cognitiveTask: {
            items: {
              'substance-forms': 'New substances form at the electrodes.',
              'apply-voltage': 'Put electrodes in an electrolyte solution and apply a voltage.',
              'ions-move': 'Ions in the liquid move toward the electrodes.',
            },
          },
        },
      },
      story: {
        title: 'The Suspects Behind the Dark Bulb',
        setting:
          'The resource desk in the science room. Records and photos lie side by side: a small bulb that lit in salt water but stayed dark in sugar water.',
        characters: CHARACTERS,
        openingLines: {
          'electrolyte.open.1':
            'With salt water the bulb lights up, but with sugar water it stays dark. And both liquids are clear!',
          'electrolyte.open.2':
            'There\'s also a record where something red formed on an electrode in copper chloride solution. The results depend on the liquid.',
          'electrolyte.open.3':
            'I\'ve got it! The sweetness of sugar makes the electricity go soft and stops it from flowing!',
        },
        choiceResponses: {
          'conduct-any-solution':
            'Just dissolving isn\'t enough. The record shows sugar water didn\'t conduct at all.',
          'solid-conducts':
            'There\'s also a record showing no current through solid salt. What matters is whether it dissolves and can move.',
          'ions-carry':
            'Only a liquid that split into ions when it dissolved conducts. Sugar dissolves, but it never turns into ions.',
        },
        resolutionLines: {
          'electrolyte.resolve.1':
            'An electrolyte splits into ions when it dissolves, and those moving ions carry the current.',
          'electrolyte.resolve.2':
            'So substances forming at the electrodes are proof that ions in the liquid gathered there.',
        },
        punchline:
          'My sweetness theory just dissolved! The real culprit was whether ions were there or not.',
      },
      notation: {
        tasks: {
          'electrolyte.tableRead': {
            title: 'Read the table of liquids that conducted',
            prompt:
              'From the record for each liquid, choose the reading that correctly identifies which liquids contain ions.',
            representation: [
              'Liquid | Current | Change at electrodes',
              'Salt water | Flowed | Substance formed at electrodes',
              'Sugar water | Did not flow | No change',
              'Dilute hydrochloric acid | Flowed | Gas at both electrodes',
            ],
            representationSemanticsLabel:
              'A liquid in which a current flows and substances form at the electrodes contains charged particles (ions).',
            choices: {
              'ions-present':
                'The liquids that conducted contain ions, and the changes at the electrodes are the evidence',
              'all-have-ions':
                'Every liquid contains ions, so the ones that did not conduct failed for some other reason',
              'color-decides': 'Whether a liquid is clear decides whether it conducts',
            },
            solutionSummary:
              'Only the liquids in which a current flowed and substances formed at the electrodes are judged to contain ions.',
          },
          'electrolyte.modelBuild': {
            title: 'Build the path to an ion',
            prompt: 'Build the steps by which an atom becomes an ion, as a sequence in the model.',
            guide:
              'Connect how an atom is built, the exchange of electrons, the charged particle, and the ion formula.',
            tokens: {
              'atom-structure': 'An atom is made of electrons and a nucleus',
              'electron-transfer': 'The atom loses or gains electrons',
              'charged-particle': 'It becomes a charged particle — an ion',
              'ion-formula': 'It is written as a formula such as Na⁺ or Cl⁻',
            },
            solutionSummary:
              'An atom becomes an ion by exchanging electrons, and ions are written as chemical formulas.',
          },
          'electrolyte.symbolMatch': {
            title: 'Match cations and anions to their formulas',
            prompt:
              'Choose the formula for the particle left after "a sodium atom lost one electron."',
            representation: ['Sodium atom | Loses one electron | → ?'],
            representationSemanticsLabel:
              'An atom that loses electrons becomes a positively charged cation.',
            choices: {
              'sodium-ion': 'Na⁺ (cation)',
              'chloride-ion': 'Cl⁻ (anion)',
              'free-electron': 'e⁻ (the electron itself)',
            },
            solutionSummary:
              'A sodium atom that has lost an electron becomes the positive cation Na⁺.',
          },
        },
      },
    },
    acidAlkali: {
      practice: {
        foundation: {
          recallPrompt:
            'Explain that the properties of acids come from hydrogen ions and the properties of alkalis come from hydroxide ions.',
          reasoningPrompt:
            'Add why an indicator\'s color change is a clue to acids and alkalis.',
          expectedOutcome:
            'In the record where BTB solution was added, dilute hydrochloric acid turned yellow, dilute sodium hydroxide solution turned blue, '
            + 'and salt water stayed green.',
          expectedReason:
            'The hydrogen ions all acids share and the hydroxide ions all alkalis share change the indicator\'s color, '
            + 'so the color tells acidic, alkaline and neutral apart.',
          cognitiveTask: {
            items: {
              'btb-yellow': 'It turns yellow when BTB solution is added.',
              'btb-blue': 'It turns blue when BTB solution is added.',
              'btb-green': 'It stays green when BTB solution is added.',
            },
          },
        },
        conditions: {
          recallPrompt:
            'Explain that pH is a measure of how strongly acidic or alkaline a liquid is.',
          reasoningPrompt:
            'Rather than "all acids are dangerous," add one example of an acid found in everyday liquids.',
          transferPrompt:
            'Two acidic liquids had a pH of 3 and 5. Which is the stronger acid? '
            + 'And for an alkaline liquid, what does a larger pH mean?',
          expectedOutcome:
            'The smaller the pH, the stronger the acid, so pH 3 is the stronger acid; '
            + 'for alkaline liquids, a larger pH means a stronger alkali.',
          expectedReason:
            'pH is a gauge of the amount of hydrogen ions and hydroxide ions; '
            + '7 is neutral, and the farther from 7, the stronger the acidity or alkalinity.',
          checkpoint: {
            lure: 'A liquid with a pH greater than 7 is acidic.',
            options: {
              'high-ph-acid': {
                text: 'The larger the pH, the stronger the acid, so a liquid above 7 is acidic.',
                hint: 'pH 7 is neutral — check which side is acidic.',
              },
              'ph-direction': {
                text: 'pH 7 is neutral; the smaller the pH, the more acidic, and the larger, the more alkaline.',
              },
              'ph-no-meaning': {
                text: 'The pH number has nothing to do with how strongly acidic or alkaline a liquid is.',
                hint: 'Check what pH is a measure of.',
              },
            },
            explanation:
              'pH 7 is neutral; smaller means a stronger acid and larger means a stronger alkali. '
              + 'If you remember the direction backwards, you will mix up the properties.',
          },
          cognitiveTask: {
            items: {
              'slippery-liquid': 'The liquid feels slippery',
              'btb-turns-yellow': 'BTB solution turns yellow',
              'gas-on-carbonate': 'Gas is released when it is added to sodium hydrogen carbonate',
              'litmus-turns-blue': 'Red litmus paper turns blue',
            },
            targets: {
              'hydrogen-ion': 'The work of hydrogen ions',
              'hydroxide-ion': 'The work of hydroxide ions',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Without using an indicator, explain the difference between acids and alkalis in terms of the ions that make each one.',
          reasoningPrompt:
            'Vinegar and lemon juice are acids too. Add how they differ from strong acids such as sulfuric acid, in terms of "strength."',
          transferPrompt:
            'In a record where dilute hydrochloric acid and vinegar were each added to sodium hydrogen carbonate powder, '
            + 'gas was released in both cases, but with different vigor. '
            + 'Explain what they have in common and how they differ, using the ions of acids.',
          expectedOutcome:
            'Gas was released in both because the hydrogen ions of each acid reacted, '
            + 'and the difference in vigor is a difference in the strength of the acids.',
          expectedReason:
            'The properties acids share are the work of hydrogen ions. '
            + 'Even among acids, a different amount of hydrogen ions changes how the reaction proceeds.',
          checkpoint: {
            lure: 'Vinegar gave off only a little gas, so vinegar is not an acid.',
            options: {
              'vinegar-not-acid': {
                text: 'Vinegar, with its weak gas, is not an acid but a liquid with some other property.',
                hint: 'Think about which ion is responsible for gas being released at all.',
              },
              'gas-only-strong-acid': {
                text: 'Only strong acids release gas, so the record of gas from vinegar must be wrong.',
                hint: 'Think about whether weak acids also contain hydrogen ions.',
              },
              'acid-strength-varies': {
                text: 'Acids come in a range of strengths. Vinegar is also an acid with hydrogen ions, and the vigor of the reaction reflects the difference in strength.',
              },
            },
            explanation:
              'The properties acids share come from hydrogen ions. '
              + 'Even a weak acid like vinegar releases gas; the difference in vigor is the difference in acid strength (the amount of hydrogen ions).',
          },
          cognitiveTask: {
            items: {
              'ph5-stronger': 'The pH 5 liquid is a stronger acid than the pH 3 liquid.',
              'same-acidity': 'pH 3 and pH 5 are equally acidic.',
              'ph3-stronger': 'The pH 3 liquid is a stronger acid than the pH 5 liquid.',
            },
          },
        },
      },
      story: {
        title: 'The Mystery of the Three-Color Cups',
        setting:
          'The resource screen in the broadcasting room. A record shows BTB solution added to three liquids, which turned yellow, green and blue.',
        characters: CHARACTERS,
        openingLines: {
          'acidAlkali.open.1':
            'Dilute hydrochloric acid turned yellow, salt water stayed green, and dilute sodium hydroxide solution turned blue.',
          'acidAlkali.open.2':
            'Same indicator, different colors. That means the particles in each liquid are different.',
          'acidAlkali.open.3':
            'The yellow one has to be lemon flavored! It\'s bound to be sour — let\'s drink it!',
        },
        choiceResponses: {
          'acid-everywhere':
            'Vinegar and lemon juice are acids too. Acids vary in strength, and whether one is dangerous depends on its kind and strength.',
          'all-acid-danger':
            'There are acids in things at home, too. "Acid means dangerous, every time" isn\'t right.',
          'alkali-safe':
            'Alkalis can be dangerous too when they\'re strong. Never get soap solution in your eyes!',
        },
        resolutionLines: {
          'acidAlkali.resolve.1':
            'Hydrogen ions turn it yellow, and hydroxide ions turn it blue. The color is the testimony of the particles in the liquid.',
          'acidAlkali.resolve.2':
            'pH 7 is neutral, and the farther away you go, the stronger the acid or alkali. The number tells you the strength.',
        },
        punchline:
          'Yellow wasn\'t a sign of lemon flavor — it was a sign of hydrogen ions. Good thing I didn\'t take a sip!',
      },
      notation: {
        tasks: {
          'acidAlkali.tableRead': {
            title: 'Read the indicator color-change table',
            prompt:
              'From the record of BTB solution color changes, choose the reading that identifies the alkaline liquid.',
            representation: [
              'Liquid | Color of BTB solution',
              'Liquid A | Yellow',
              'Liquid B | Stays green',
              'Liquid C | Blue',
            ],
            representationSemanticsLabel:
              'Yellow means acidic, green means neutral, and blue means alkaline.',
            choices: {
              'a-alkaline': 'Liquid A is alkaline',
              'c-alkaline': 'Liquid C is alkaline',
              'b-alkaline': 'Liquid B is alkaline',
            },
            solutionSummary:
              'BTB solution turns blue in an alkaline liquid, and Liquid C is the one that did.',
          },
          'acidAlkali.sequence': {
            title: 'Order the steps for testing a liquid',
            prompt:
              'Arrange the steps for finding out whether a liquid is acidic or alkaline, in the order they are recorded.',
            guide:
              'Connect adding an indicator, recording the color, comparing with a color chart, and deciding the property.',
            tokens: {
              'add-indicator': 'Add an indicator to the liquid',
              'record-color': 'Record the color it changed to',
              'compare-table': 'Compare with the chart matching colors to properties',
              'decide-property': 'Decide whether it is acidic, neutral or alkaline',
            },
            solutionSummary:
              'Compare the indicator\'s color with the chart to decide the property of the liquid.',
          },
          'acidAlkali.graphRead': {
            title: 'Read the pH scale',
            prompt:
              'From the pH scale diagram, choose the correct reading of how strongly acidic or alkaline a liquid is.',
            representation: [
              'pH | 0 … 7 … 14',
              'Low end | Strong acid',
              '7 | Neutral',
              'High end | Strong alkali',
            ],
            representationSemanticsLabel:
              '7 is neutral; the smaller the pH, the stronger the acid, and the larger, the stronger the alkali.',
            choices: {
              'ph-correct': 'The farther from 7, the more strongly acidic or alkaline',
              'ph-reversed': 'Closer to 14 is a stronger acid, and closer to 0 is a stronger alkali',
              'ph-neutral-high': 'The larger the pH, the closer to neutral',
            },
            solutionSummary:
              'pH 7 is neutral, and the farther from it, the stronger the acidity or alkalinity.',
          },
        },
      },
    },
    neutralizationBattery: {
      practice: {
        foundation: {
          recallPrompt:
            'Explain that neutralization produces water and a salt, in terms of hydrogen ions and hydroxide ions joining together.',
          reasoningPrompt:
            'Add why neutralization happens even when the liquid does not become neutral (only the portion that mixed reacts).',
          expectedOutcome:
            'In the record where dilute hydrochloric acid and dilute sodium hydroxide solution were mixed until neutral and then dried, '
            + 'white crystals — sodium chloride — were left.',
          expectedReason:
            'Hydrogen ions and hydroxide ions join to form water, '
            + 'and the remaining sodium ions and chloride ions form crystals.',
          cognitiveTask: {
            items: {
              'salt-remains': 'Salt crystals form from the remaining sodium ions and chloride ions.',
              'ions-join': 'Hydrogen ions and hydroxide ions join together.',
              'water-forms': 'The joined particles become water, and the properties of the acid and alkali cancel out.',
            },
          },
        },
        conditions: {
          recallPrompt:
            'Explain that "salt" is the name for the substance produced by neutralization, and that there are salts other than table salt.',
          reasoningPrompt:
            'Add one example showing that some salts dissolve in water and some do not.',
          transferPrompt:
            'A liquid made by mixing an acid and an alkali had a pH of 6. Has neutralization happened? '
            + 'And what does the liquid contain?',
          expectedOutcome:
            'Even though the pH is not 7, the hydrogen ions and hydroxide ions that mixed have become water, '
            + 'and the liquid contains the salt that formed plus leftover acid ions.',
          expectedReason:
            'Neutralization always proceeds for the portion that mixed. '
            + 'If the amounts do not match, one side is left over, but a salt still forms even though the liquid is not neutral.',
          checkpoint: {
            lure: 'In a liquid that did not become neutral, no neutralization happened at all.',
            options: {
              'partial-occurs': {
                text: 'Even if it is not neutral, the portion that mixed has neutralized, producing water and a salt.',
              },
              'no-neutralization': {
                text: 'Since it did not become neutral, the acid and alkali did not react.',
                hint: 'Think about what happened to the hydrogen ions and hydroxide ions that did mix.',
              },
              'only-water-formed': {
                text: 'Neutralization produces only water, and nothing else is left in the liquid.',
                hint: 'Think about where the sodium ions and chloride ions go.',
              },
            },
            explanation:
              'Neutralization always happens for the portion that mixed. '
              + 'Even if the leftover side remains and the liquid is not neutral, the water and salt that formed are still in the liquid.',
          },
          cognitiveTask: {
            items: {
              'nothing-remains': 'Drying the neutralized liquid leaves nothing behind.',
              'salt-crystals': 'Drying the neutralized liquid leaves salt crystals behind.',
              'acid-crystals': 'Drying it leaves the acid itself behind as crystals.',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Explain that different metals become ions with different ease.',
          reasoningPrompt:
            'Add that in a battery, this difference in ease makes electrons flow.',
          transferPrompt:
            'In a record where a zinc plate and a copper plate were placed in an electrolyte solution and connected in a circuit, a current flowed. '
            + 'Explain which metal releases electrons and where they are accepted, '
            + 'using how easily each metal becomes an ion.',
          expectedOutcome:
            'Zinc, which becomes an ion more easily, releases electrons and becomes zinc ions, '
            + 'and those electrons flow through the circuit to the copper plate.',
          expectedReason:
            'The difference in how easily the metals become ions creates a one-way flow of electrons, '
            + 'which can be drawn out as a current in the external circuit. Chemical energy is being converted into electrical energy.',
          checkpoint: {
            lure: 'A battery is a container that stores electricity and has nothing to do with chemical change.',
            options: {
              'stored-electricity': {
                text: 'A battery is a container that releases electricity stored in advance, and nothing changes inside it.',
                hint: 'Think about whether the metals and the liquid inside the battery are changing.',
              },
              'copper-gives-electrons': {
                text: 'Electrons flow from the copper plate to the zinc plate, so copper becomes an ion more easily.',
                hint: 'Check which becomes an ion more easily: zinc or copper.',
              },
              'ion-tendency-drives': {
                text: 'Two metals that differ in how easily they become ions create a flow of electrons, and that flow is the current.',
              },
            },
            explanation:
              'A chemical change is happening inside a battery. '
              + 'Zinc, which becomes an ion more easily, releases electrons, and a current flows as the electrons are accepted on the copper side.',
          },
          cognitiveTask: {
            items: {
              'two-metals': 'Place plates of two metals that differ in how easily they become ions into an electrolyte solution and connect a circuit.',
              'same-metal-pair': 'Place two plates of the same metal into water and connect a circuit.',
              'charged-battery': 'Connect a circuit to a container that has electricity stored in it in advance.',
            },
          },
        },
      },
      story: {
        title: 'Where Did the Fruit Battery\'s Power Come From?',
        setting:
          'The resource terminal in the library. There is a record of a current flowing from a lemon with zinc and copper plates stuck in it, along with a photo of a dry-cell battery.',
        characters: CHARACTERS,
        openingLines: {
          'neutralizationBattery.open.1':
            'This record shows that sticking zinc and copper plates into lemon juice really made a current flow.',
          'neutralizationBattery.open.2':
            'Apparently zinc becomes an ion more easily than copper. With that difference, electrons flow in one direction.',
          'neutralizationBattery.open.3':
            'Lemons are electric fruit! The electricity lives inside the juice!',
        },
        choiceResponses: {
          'neutral-guaranteed':
            'Mixing doesn\'t always make it neutral. If the amounts don\'t match, the leftover side\'s properties remain.',
          'partial-neutralization':
            'Even if it isn\'t neutral, the part that mixed has neutralized. Water and a salt have formed.',
          'no-reaction-unless-neutral':
            'Not neutral means zero reaction... wait, then where did those crystals come from?!',
        },
        resolutionLines: {
          'neutralizationBattery.resolve.1':
            'Neutralization is the reaction where hydrogen ions and hydroxide ions join to form water. A salt forms from the ions that are left.',
          'neutralizationBattery.resolve.2':
            'A battery works because electrons flow from the difference in how easily metals become ions. It turns the power of chemical change into electricity.',
        },
        punchline:
          'The electricity wasn\'t hiding in the juice — it came from the metals\' different eagerness to become ions. Sorry, lemon, I totally squeezed you for the wrong reason!',
      },
      notation: {
        tasks: {
          'neutralizationBattery.tableRead': {
            title: 'Read the table of what the liquid contains after mixing',
            prompt:
              'From the record of ions before and after neutralization, choose the correct reading.',
            representation: [
              'Ions before the reaction | What remains after the reaction',
              'H⁺・Cl⁻・Na⁺・OH⁻ | H₂O・Na⁺・Cl⁻',
              'After drying | Sodium chloride crystals',
            ],
            representationSemanticsLabel:
              'Hydrogen ions and hydroxide ions become water, and a salt forms from the remaining ions.',
            choices: {
              'all-vanish': 'All the ions disappear and only water is left',
              'salt-forms': 'Water forms, and a salt forms from the remaining ions',
              'acid-remains': 'Only the acid\'s ions remain, and the liquid stays acidic',
            },
            solutionSummary:
              'H⁺ and OH⁻ join to form water, and a salt forms from the remaining Na⁺ and Cl⁻.',
          },
          'neutralizationBattery.sequence': {
            title: 'Order how a current flows in a battery',
            prompt:
              'Arrange the steps by which a current is drawn from a Daniell cell, in the order they happen.',
            guide:
              'Connect zinc becoming ions, electrons moving, electrons being accepted at the copper plate, and the current being drawn out.',
            tokens: {
              'zinc-ionizes': 'Zinc, which becomes an ion easily, releases electrons and becomes zinc ions',
              'electrons-flow': 'The released electrons flow through the circuit to the copper plate',
              'electrons-received': 'The electrons are accepted at the copper plate',
              'current-out': 'The flow is drawn out as a current in the external circuit',
            },
            solutionSummary:
              'The difference in how easily the metals become ions creates a one-way flow of electrons, which can be drawn out as a current.',
          },
          'neutralizationBattery.symbolMatch': {
            title: 'Choose the expression for neutralization',
            prompt:
              'Choose the ion equation that correctly represents the change in neutralization.',
            representation: [
              'Acid particle | Alkali particle | Product',
              'H⁺ | OH⁻ | ?',
            ],
            representationSemanticsLabel:
              'Hydrogen ions and hydroxide ions join to form water.',
            choices: {
              'water-formed': 'H⁺ ＋ OH⁻ → H₂O',
              'salt-direct': 'Na⁺ ＋ Cl⁻ → H₂O',
              'acid-joins': 'H⁺ ＋ OH⁻ → NaCl',
            },
            solutionSummary:
              'In neutralization, hydrogen ions and hydroxide ions join to form water.',
          },
        },
      },
    },
  },
}
