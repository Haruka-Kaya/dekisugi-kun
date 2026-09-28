import type { UnitContentText } from '../i18n-content.js'

export const chemicalChangeContent: UnitContentText = {
  unitId: 'chemical-change',
  concepts: {
    combinationDecomposition: {
      practice: {
        foundation: {
          recallPrompt:
            'Explain combination (substances joining) and decomposition (a substance splitting) in terms of whether the kind of substance changes before and after the reaction.',
          reasoningPrompt:
            'Mixing things together or dissolving them is not combination. Add one piece of evidence that lets you tell a combination apart from a mixture.',
          expectedOutcome:
            'In the record of heating a mixture of iron filings and sulfur, the black substance after the reaction is not attracted to a magnet — it has become a substance with different properties from before the reaction.',
          expectedReason:
            'Heating caused a chemical change in which iron and sulfur joined, producing iron sulfide, a substance with different properties. Simply mixing them leaves each grain with its own properties.',
          cognitiveTask: {
            items: {
              'iron-sulfur-heat':
                'Iron filings and sulfur were mixed and heated, producing a black substance that is not attracted to a magnet',
              'sand-iron-mix': 'Sand and iron filings were mixed',
              'salt-dissolve': 'Salt was dissolved in water',
              'baking-soda-heat':
                'Sodium hydrogen carbonate was heated and several substances were produced',
            },
            targets: {
              'chemical-change': 'Chemical change',
              'physical-change': 'Physical change',
            },
          },
        },
        conditions: {
          recallPrompt:
            'Explain the difference between "the two were mixed" and "the two combined" by whether each grain keeps its properties.',
          reasoningPrompt:
            'Add which properties you should compare to check whether a product is really a different substance.',
          transferPrompt:
            'Suppose a record of heating sodium hydrogen carbonate shows that a solid with different properties, water, and a gas were produced. Decide whether this is a decomposition, and give your evidence.',
          expectedOutcome:
            'One substance, sodium hydrogen carbonate, split into several substances with different properties, so it can be judged a decomposition.',
          expectedReason:
            'The products show properties different from the substance before the reaction, and one kind of substance split into two or more. This is different from a state change or a separation, where the substance does not change.',
          checkpoint: {
            lure: 'If heating splits something into several substances, it is always a decomposition.',
            options: {
              'melting-decomposition': {
                text: 'Ice turning into water is also one thing turning into something else, so it counts as decomposition.',
                hint: 'Distinguish whether the kind of substance changes between ice and water, or only its form changes.',
              },
              'new-substances-decomposition': {
                text: 'If you can confirm that several substances with different properties were produced from one substance, it is a decomposition.',
              },
              'heating-only': {
                text: 'Every change caused by heating is a chemical change, so there is no need to classify it.',
                hint: 'Think about whether some changes caused by heating leave the substance unchanged.',
              },
            },
            explanation:
              'Decomposition is a chemical change in which one substance splits into two or more different substances. '
              + 'A change where the substance stays the same, like ice turning into water, is not decomposition.',
          },
          cognitiveTask: {
            items: {
              'check-color-only':
                'Look only at the color and decide that it had already combined when it was mixed.',
              'check-magnet':
                'Bring the substance after the reaction near a magnet and check whether iron’s properties remain.',
              'do-nothing':
                'Check nothing and decide based only on the change in appearance.',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Explain the difference between a chemical change and physical changes such as state changes or dissolving.',
          reasoningPrompt:
            'Add why "a gas came out" or "the color changed" alone is not enough to conclude that a chemical change happened.',
          transferPrompt:
            'In one record, heating limestone produced a solid and a gas with different properties. '
            + 'In another record, a mixture of sand and iron filings was separated with a magnet. '
            + 'Sort out which one is a chemical change, and why.',
          expectedOutcome:
            'Heating limestone is a decomposition that produced new substances, while separating sand and iron filings is a physical operation in which the substances do not change.',
          expectedReason:
            'In a chemical change the products show properties different from the substances before the reaction, '
            + 'but when separating with a magnet, each grain keeps its properties just as they were.',
          checkpoint: {
            lure: 'Using a magnet to pull out iron filings is the same as decomposition, since both split substances apart.',
            options: {
              'separation-is-decomposition': {
                text: 'Separating a mixture into its components is a decomposition, just like heating.',
                hint: 'Compare the substances split apart by decomposition with the iron filings pulled out by a magnet — did the filings turn into a different substance?',
              },
              'all-division-chemical': {
                text: 'Every change that splits things apart is a chemical change, so both are decompositions.',
                hint: 'Think about whether the condition for a chemical change is "splitting apart" or "a different substance being produced."',
              },
              'physical-vs-chemical': {
                text: 'Separating with a magnet is a physical operation that does not change the properties of the grains, which is different from decomposition, where the products are different substances.',
              },
            },
            explanation:
              'Decomposition is a chemical change, and its products have different properties from the original substance. '
              + 'Separating with a magnet is a physical operation in which neither the iron filings nor the sand change their properties.',
          },
          cognitiveTask: {
            items: {
              'judge-change':
                'Since a different substance was produced, judge it to be a chemical change.',
              'compare-before-after':
                'Compare the properties of the substances before and after the reaction.',
              'detect-difference':
                'Check whether the products have any properties that differ from before the reaction.',
            },
          },
        },
      },
      story: {
        title: 'The Case of the Wrongly Accused Just-Mixed Powder',
        setting:
          'A materials shelf in the home economics room. Observation records of a powder of mixed iron filings and sulfur, and of the black lump after heating, sit side by side.',
        characters: {
          mio: { name: 'Mio', role: 'Observation and safety checks' },
          dekisugi: { name: 'Dekisugi-kun', role: 'Overconfident hypotheses' },
          ren: { name: 'Ren', role: 'Checking conditions and records' },
        },
        openingLines: {
          'combinationDecomposition.open.1':
            'When I bring a magnet near the powder before heating, only the dark grains stick to it.',
          'combinationDecomposition.open.2':
            'So the iron grains are still there. And the lump after heating isn’t attracted to the magnet at all.',
          'combinationDecomposition.open.3':
            'I know this one! Once you mix them, they’re already combined! I call it the "Instant Combination Theory"!',
        },
        choiceResponses: {
          'mixture-not-compound':
            'If they were only mixed, the iron grains are still iron. The record of them being pulled by the magnet proves it.',
          'mixed-means-combined':
            'Even if the grains are touching, as long as they keep their properties, it’s still a mixture.',
          'heating-restores':
            'If heating changed the color, it should change back once it cools... except it didn’t!',
        },
        resolutionLines: {
          'combinationDecomposition.resolve.1':
            'Heating caused a chemical change and produced iron sulfide, which has different properties. That’s combination.',
          'combinationDecomposition.resolve.2':
            'One substance splitting apart is decomposition, and substances joining is combination. Just mixing is neither.',
        },
        punchline:
          'The Instant Combination Theory just got pulled apart by one magnet.',
      },
      notation: {
        tasks: {
          'combinationDecomposition.tableRead': {
            title: 'Read the before-and-after properties table',
            prompt:
              'From the records before and after heating, choose the reading that lets you judge that combination occurred.',
            representation: [
              'Substance | Appearance | Response to magnet',
              'Iron filings and sulfur (before heating) | Gray and yellow grains | Only the iron grains are attracted',
              'Black lump after heating | Black solid | Not attracted',
            ],
            representationSemanticsLabel:
              'Before heating, each grain keeps its own properties; after heating, it has become a substance with different properties.',
            choices: {
              'still-mixture': 'The powder before heating is already iron sulfide',
              'reaction-occurred':
                'The substance after heating has different properties from before the reaction, so combination occurred',
              'no-change': 'Only the appearance changed; the substance did not change',
            },
            solutionSummary:
              'Because the response to the magnet disappeared, you can judge that a substance with different properties was produced.',
          },
          'combinationDecomposition.sequence': {
            title: 'Order the steps for judging a chemical change',
            prompt:
              'Arrange the steps for judging whether a reaction is a chemical change, in the order you read the records.',
            guide:
              'Connect the properties before the reaction, the properties of the products, the judgment of whether it is a different substance, and the classification of the change.',
            tokens: {
              'record-before': 'Check the properties of the substances before the reaction',
              'inspect-products': 'Examine the properties of the products',
              'compare-properties':
                'Compare whether the properties differ before and after the reaction',
              'classify-change':
                'If a different substance was produced, classify it as a chemical change such as combination or decomposition',
            },
            solutionSummary:
              'Compare the properties before and after the reaction, and judge whether it is a chemical change by whether a different substance was produced.',
          },
          'combinationDecomposition.symbolMatch': {
            title: 'Match the name of the change to the reaction',
            prompt:
              'Choose the name of the change: "Heating sodium hydrogen carbonate produced sodium carbonate, water, and carbon dioxide."',
            representation: [
              'Before the reaction | After the reaction',
              'Sodium hydrogen carbonate | Sodium carbonate, water, carbon dioxide',
            ],
            representationSemanticsLabel:
              'One substance split into several substances with different properties.',
            choices: {
              decomposition: 'Decomposition',
              combination: 'Combination',
              'state-change': 'State change',
            },
            solutionSummary:
              'A change in which one substance splits into two or more different substances is decomposition.',
          },
        },
      },
    },
    oxidationReduction: {
      practice: {
        foundation: {
          recallPrompt:
            'Explain how oxidation (a substance combining with oxygen) and reduction (removing oxygen from an oxide) are related.',
          reasoningPrompt:
            'Add why changes that happen at different speeds — burning, rusting, and respiration — are all called "oxidation."',
          expectedOutcome:
            'In the record of heating copper oxide powder mixed with carbon powder, shiny red copper forms from the black powder, and carbon dioxide is given off.',
          expectedReason:
            'The oxygen in the copper oxide moved to the carbon: the copper oxide was reduced to copper, and the carbon was oxidized to carbon dioxide.',
          cognitiveTask: {
            items: {
              'copper-lighter': 'It burned, so the copper plate gets lighter.',
              'copper-heavier':
                'The copper plate gets heavier by the amount of oxygen it combined with.',
              'copper-same': 'The mass does not change.',
            },
          },
        },
        conditions: {
          recallPrompt:
            'Explain why mass increases in oxidation, in terms of combining with oxygen.',
          reasoningPrompt:
            'Add a point that explains the record of metals gaining mass when burned in a way that does not contradict the idea that "burning should make things lighter."',
          transferPrompt:
            'There are records showing that heating a copper plate increased its mass, while burning charcoal decreased the mass of the solid left behind. '
            + 'Explain where the added mass and the seemingly lost mass each came from.',
          expectedOutcome:
            'The copper plate gets heavier by the oxygen in the air that combined with it, and the charcoal looks lighter because it left into the air as carbon dioxide, together with the oxygen it combined with.',
          expectedReason:
            'Both are oxidation, which involves exchanging oxygen. '
            + 'Whether the apparent gain or loss shows up depends on whether the surrounding oxygen and the escaping gas are included in the measurement.',
          checkpoint: {
            lure: 'Burning uses up substances, so there is always less substance after oxidation than before.',
            options: {
              'oxygen-added': {
                text: 'Burning is rapid oxidation, and the product gets heavier by the amount of oxygen that combined. You need to include escaping gases in your thinking too.',
              },
              'burning-shrinks': {
                text: 'Whatever burns disappears, so the mass of the product is always smaller.',
                hint: 'Compare the fact that oxygen combines during burning with the recorded mass of the oxide.',
              },
              'fire-is-not-oxidation': {
                text: 'Burning works differently from oxidation, so oxygen going in or out has nothing to do with it.',
                hint: 'Check whether oxygen is needed for burning.',
              },
            },
            explanation:
              'Burning is rapid oxidation. Looking only at the solid left behind, the mass may go up or down, '
              + 'but once you include the oxygen that combined and the gases that escaped, it can be explained by the exchange of oxygen.',
          },
          cognitiveTask: {
            items: {
              'burning-fast': 'Wood or charcoal burning',
              'rust-slow': 'Iron rusting',
              breathing: 'Our breathing (respiration)',
              'melting-ice': 'Ice melting',
            },
            targets: {
              oxidation: 'Oxidation',
              'not-oxidation': 'Not oxidation',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Explain, in terms of the exchange of oxygen, why oxidation and reduction are "opposite reactions."',
          reasoningPrompt:
            'Give one everyday example that uses oxidation or reduction, and add which reaction it is along with your reason.',
          transferPrompt:
            'Contrast ironmaking, which extracts iron from iron ore (iron oxide), with iron rusting, in terms of the exchange of oxygen. '
            + 'Which one is oxidation and which one is reduction?',
          expectedOutcome:
            'Removing oxygen from iron ore to get iron is reduction, and iron combining with oxygen to rust is oxidation.',
          expectedReason:
            'Reduction is a reaction that removes oxygen from an oxide, and oxidation is a reaction in which a substance combines with oxygen, '
            + 'so oxygen moves in opposite directions.',
          checkpoint: {
            lure: 'Turning the oxide formed by rusting back into the original iron is also a kind of oxidation.',
            options: {
              'return-is-oxidation': {
                text: 'Turning rust back into iron "returns" the iron to how it was, so it is oxidation.',
                hint: 'Oxidation and reduction are not classified by whether something "goes back to how it was," but by which way the oxygen moves.',
              },
              'rust-permanent': {
                text: 'Rusted iron never changes again, so it is neither reaction.',
                hint: 'Ironmaking extracts iron from iron oxide. Check the name of that reaction.',
              },
              'rust-removal-reduction': {
                text: 'Turning rust back into iron is reduction, which removes oxygen from an oxide.',
              },
            },
            explanation:
              'A reaction that removes oxygen from an oxide is reduction. '
              + 'It is classified not by the idea of "returning" something, but by the direction of the oxygen exchange.',
          },
          cognitiveTask: {
            items: {
              'copper-remains': 'Shiny red copper is left.',
              'heat-with-carbon': 'Mix carbon with copper oxide and heat it.',
              'oxygen-moves': 'Oxygen moves to the carbon, forming carbon dioxide.',
            },
          },
        },
      },
      story: {
        title: 'Track Down the Red Stain',
        setting:
          'A photo of the fence by the school entrance lies open, next to the school’s saved observation records of rust.',
        characters: {
          mio: { name: 'Mio', role: 'Observation and safety checks' },
          dekisugi: { name: 'Dekisugi-kun', role: 'Overconfident hypotheses' },
          ren: { name: 'Ren', role: 'Checking conditions and records' },
        },
        openingLines: {
          'oxidationReduction.open.1':
            'When you scrape the rusty part, it crumbles away. It feels totally different from the iron underneath.',
          'oxidationReduction.open.2':
            'There’s also a measurement record showing the rusted iron is heavier than it was before.',
          'oxidationReduction.open.3':
            'So something came in from outside! The culprit is... thin air!',
        },
        choiceResponses: {
          'surface-dirt':
            'If it were dirt, scraping it off should put things back the way they were. But rust crumbles, and the iron itself is being used up.',
          'rust-is-oxide':
            'Rust is an oxide — iron combined with oxygen. That means it’s a different substance from iron.',
          'rust-is-reduction':
            'Rust forms when oxygen leaves... wait, then it wouldn’t get heavier!',
        },
        resolutionLines: {
          'oxidationReduction.resolve.1':
            'Combining with oxygen is oxidation, and taking oxygen away from an oxide is reduction. Rust is slow oxidation.',
          'oxidationReduction.resolve.2':
            'Burning and rusting are both about combining with oxygen. They just happen at different speeds.',
        },
        punchline:
          'Thin air was guilty after all! Its method: combining with oxygen.',
      },
      notation: {
        tasks: {
          'oxidationReduction.tableRead': {
            title: 'Read the oxygen exchange table',
            prompt:
              'From the record of heating copper oxide with carbon, choose the name of the change that happened to the substance that lost oxygen.',
            representation: [
              'Substance | Change | Where the oxygen went',
              'Copper oxide | From black powder to shiny red copper | Lost oxygen',
              'Carbon | From carbon to carbon dioxide | Gained oxygen',
            ],
            representationSemanticsLabel:
              'The substance that lost oxygen was reduced, and the substance that gained oxygen was oxidized.',
            choices: {
              oxidized: 'Oxidation',
              reduced: 'Reduction',
              decomposed: 'Decomposition',
            },
            solutionSummary:
              'Copper oxide lost oxygen and became copper, so it was reduced.',
          },
          'oxidationReduction.sequence': {
            title: 'Order the reasoning for why oxidation increases mass',
            prompt:
              'Arrange the reasons why a metal gains mass when heated in air, in the order the events happen.',
            guide:
              'Connect combining with oxygen, forming an oxide, and the increase in mass.',
            tokens: {
              'oxygen-joins': 'Oxygen in the air combines with the metal',
              'oxide-forms': 'A different substance called an oxide is produced',
              'mass-increases': 'The mass increases by the amount of oxygen that combined',
            },
            solutionSummary:
              'Oxygen combines to form an oxide, so the substance is heavier after oxidation.',
          },
          'oxidationReduction.graphRead': {
            title: 'Read the copper and oxygen mass graph',
            prompt:
              'From the record of the mass of heated copper and the mass of oxygen it combined with, choose the correct reading.',
            representation: [
              'Mass of copper (g) | Mass of combined oxygen (g)',
              '0.4 | 0.1',
              '0.8 | 0.2',
              '1.2 | 0.3',
            ],
            representationSemanticsLabel:
              'When the mass of copper doubles or triples, the mass of oxygen it combines with also doubles or triples.',
            choices: {
              proportional:
                'The mass of oxygen that combines is proportional to the mass of copper',
              unrelated:
                'The mass of oxygen varies randomly, with no relation to the mass of copper',
              'fixed-oxygen':
                'Even when the mass of copper is different, the amount of oxygen that combines is always the same',
            },
            solutionSummary:
              'There is a fixed relationship between the masses of the reacting substances: oxygen combines in proportion to the mass of copper.',
          },
        },
      },
    },
    massConservation: {
      practice: {
        foundation: {
          recallPrompt:
            'Using the idea of atoms being rearranged, explain why the total mass of all the substances involved in a chemical change is the same before and after.',
          reasoningPrompt:
            'Add a point that explains substances that seem to "burn away" or "appear out of nowhere" without contradicting conservation of mass.',
          expectedOutcome:
            'In the record of reacting hydrochloric acid and sodium hydrogen carbonate inside a sealed bag, the mass of the whole bag stays equal to the mass before the reaction, even though a gas is produced.',
          expectedReason:
            'Even though the reaction changes how the atoms are combined and a gas is produced, the atoms themselves stay inside the bag, so the mass of everything being measured does not change.',
          cognitiveTask: {
            items: {
              'atom-types': 'The kinds of atoms',
              bonding: 'How the atoms are joined together',
              'atom-counts': 'The number of atoms',
              'total-mass': 'The total mass of all the substances involved',
            },
            targets: {
              conserved: 'Does not change',
              rearranged: 'Changes',
            },
          },
        },
        conditions: {
          recallPrompt:
            'Explain why mass seems to change in an open system, in terms of how you set the range being measured.',
          reasoningPrompt:
            'Give one observation that confirms gases have mass, and add it to your explanation.',
          transferPrompt:
            'There are records of the same reaction done in an open vessel and in a sealed bag. '
            + 'In the open vessel the mass decreased; in the sealed bag it did not change. '
            + 'Explain this difference without treating it as an exception to the law.',
          expectedOutcome:
            'In the open vessel, the gas produced leaves the measured range, so the mass seems to drop; in the sealed bag the gas is included in the measurement, so the mass does not change.',
          expectedReason:
            'Conservation of mass is a law about measuring "all the substances involved." '
            + 'The apparent difference comes from whether substances that moved in or out were included in the measurement — it is not an exception to the law itself.',
          checkpoint: {
            lure: 'If the mass decreased in an open vessel, conservation of mass does not hold for that reaction.',
            options: {
              'escaped-gas-counted': {
                text: 'If you add the mass of the escaped gas, the total is equal. It just left the measured range, so the law still holds.',
              },
              'mass-destroyed': {
                text: 'Atoms disappeared by the amount the mass decreased, so mass is not conserved in this reaction.',
                hint: 'Think about whether the atoms that left as a gas disappeared, or just changed location.',
              },
              'open-systems-exempt': {
                text: 'The law cannot be applied to open systems, so it cannot be tested either.',
                hint: 'Think about whether there is a way to measure the mass of the escaped gas separately.',
              },
            },
            explanation:
              'The mass seems to drop in an open system because gas left the measured range. '
              + 'Gases have mass, and once you add what left, the totals before and after the reaction are equal.',
          },
          cognitiveTask: {
            items: {
              'escaped-gas-equal':
                'If the escaped gas is included, the total mass before and after the reaction is equal.',
              'mass-vanished':
                'Mass disappears by the amount of gas that was produced.',
              'scale-error': 'The difference was caused only by an error in the scale.',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Write an explanation for cases where mass seems to increase in a chemical change, in terms of substances taken in from outside.',
          reasoningPrompt:
            'Add a point that explains the record of a metal gaining mass when heated, in terms of "what was included in the system being measured."',
          transferPrompt:
            'In Record A, heating copper in air increased its mass; in Record B, heating limestone decreased its mass. '
            + 'Name the substances that moved in or out in each case, and show that the gain and loss do not contradict the law.',
          expectedOutcome:
            'In A, the mass increased by the oxygen from the air that combined with the copper; in B, the mass seems to drop by the carbon dioxide that left. '
            + 'In both cases, the totals are equal once what moved in or out is included.',
          expectedReason:
            'When a substance that is not part of the measured system comes in, the mass seems to increase; when a substance that is part of it leaves, the mass seems to decrease. '
            + 'If everything involved in the reaction is measured, mass is conserved.',
          checkpoint: {
            lure: 'A metal gains mass when heated because heating created new atoms.',
            options: {
              'atoms-created': {
                text: 'Heating creates new atoms, so of course the mass increases.',
                hint: 'Check whether a chemical change creates new atoms, or only changes how they are combined.',
              },
              'oxygen-joined': {
                text: 'It got heavier by the amount of oxygen from the air that combined with the metal. If the air is included in the measured system, the total is equal.',
              },
              'heat-has-mass': {
                text: 'Heat itself has mass, so the more you heat something, the heavier it gets.',
                hint: 'Think about whether the added mass matches the amount of oxygen or the amount of heat.',
              },
            },
            explanation:
              'The added mass is the mass of the oxygen that combined. '
              + 'A chemical change does not create atoms — it only changes how they are combined — so if you measure the substances moving in and out too, the totals are equal.',
          },
          cognitiveTask: {
            items: {
              'open-setup':
                'Let the gas escape from an open vessel, then measure what is left.',
              'skip-measurement':
                'Do not measure the mass; decide based only on the change in appearance.',
              'sealed-setup':
                'Run the reaction in a sealed container so the gas produced is included, and measure the whole thing.',
            },
          },
        },
      },
      story: {
        title: 'The Locked-Room Case of the Missing 1.1 Grams',
        setting:
          'Measurement records in the science room. Two tables remain from running the same reaction in an open vessel and in a sealed bag.',
        characters: {
          mio: { name: 'Mio', role: 'Observation and safety checks' },
          dekisugi: { name: 'Dekisugi-kun', role: 'Overconfident hypotheses' },
          ren: { name: 'Ren', role: 'Checking conditions and records' },
        },
        openingLines: {
          'massConservation.open.1':
            'In the open vessel, the mass dropped by 1.1 grams after the reaction. But in the sealed bag, it’s exactly the same.',
          'massConservation.open.2':
            'Both used the same amounts of hydrochloric acid and sodium hydrogen carbonate. The only difference is whether the gas could escape.',
          'massConservation.open.3':
            'I’ve cracked the locked-room trick! The mass evaporated all by itself!',
        },
        choiceResponses: {
          'gas-no-mass':
            'Gases have mass too. If you count the carbon dioxide that was produced, the numbers add up.',
          'conservation-fails':
            'I think it just left the range we were measuring. It didn’t actually vanish.',
          'count-escaped-gas':
            'If we add in the gas that escaped, the totals before and after should be equal.',
        },
        resolutionLines: {
          'massConservation.resolve.1':
            'The amount lost in the open vessel matches the mass of the gas that went outside.',
          'massConservation.resolve.2':
            'Atoms don’t disappear — only their combinations change. If you include everything in what you measure, mass is conserved.',
        },
        punchline:
          'The missing mass? Carbon dioxide that slipped out the window. So much for my locked-room mystery!',
      },
      notation: {
        tasks: {
          'massConservation.tableRead': {
            title: 'Read the records from the open and closed systems',
            prompt:
              'Choose the interpretation that explains the difference between the mass records from running the same reaction in two setups.',
            representation: [
              'Setup | Before reaction (g) | After reaction (g)',
              'Open vessel | 100.0 | 98.9',
              'Sealed bag | 100.0 | 100.0',
            ],
            representationSemanticsLabel:
              'In the open vessel the mass dropped by the gas that went outside; in the sealed bag the total mass did not change.',
            choices: {
              'law-broken': 'The law of conservation of mass does not hold in an open system',
              'escaped-gas': 'In the open vessel, the gas produced went outside',
              'scale-error': 'The difference in measurements is due to a broken scale',
            },
            solutionSummary:
              'The amount lost in the open vessel is the mass of the gas that went outside; when sealed, the totals are equal.',
          },
          'massConservation.modelBuild': {
            title: 'Build a chemical change with an atom model',
            prompt:
              'Build, as a sequence of models, what happens to atoms before and after a chemical change.',
            guide:
              'Connect the atoms before the reaction, the rearranging of bonds, the atoms in the products, and what is conserved.',
            tokens: {
              'reactant-atoms': 'The group of atoms before the reaction',
              'atoms-rearranged': 'How the atoms are joined gets rearranged',
              'product-atoms': 'The same atoms form the products with different connections',
              'same-total':
                'The kinds and numbers of atoms, and the total mass, stay the same',
            },
            solutionSummary:
              'Atoms are neither destroyed nor added — only their connections change — so the total mass does not change.',
          },
          'massConservation.symbolMatch': {
            title: 'Choose the equation for conservation of mass',
            prompt:
              'Choose the expression that correctly represents conservation of mass in a chemical change.',
            representation: [
              'Reactants | → | Products',
              'Hydrochloric acid + sodium hydrogen carbonate | → | Sodium chloride + water + carbon dioxide',
            ],
            representationSemanticsLabel:
              'The total mass of all the products, including the escaped gas, equals the total mass of the reactants.',
            choices: {
              'sum-equal': 'Total mass of reactants = total mass of products',
              'products-less': 'The total mass of the products is always smaller',
              'gas-excluded': 'They are equal after subtracting the gas that came out',
            },
            solutionSummary:
              'The total mass of all the products, including gases, equals the total mass of the reactants.',
          },
        },
      },
    },
  },
}
