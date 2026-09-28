import type { UnitContentText } from '../i18n-content.js'

const CHARACTERS = {
  mio: { name: 'Mio', role: 'Observation and safety checks' },
  dekisugi: { name: 'Dekisugi-kun', role: 'Overconfident hypotheses' },
  ren: { name: 'Ren', role: 'Checking conditions and records' },
}

export const matterPropertiesContent: UnitContentText = {
  unitId: 'matter-properties',
  concepts: {
    density: {
      practice: {
        foundation: {
          recallPrompt:
            'Using mass and volume, explain what kind of quantity density is, including what happens when you change the amount of the same material.',
          reasoningPrompt:
            'Add why cutting an object of one material in half does not change its density, in terms of how the numerator and denominator change.',
          expectedOutcome:
            'With two containers holding the same volume, the one with water feels heavier than the one with cooking oil.',
          expectedReason:
            'When the containers and the volumes of their contents are the same, the difference in mass shows a difference in mass per unit volume. At ordinary room temperature, water is denser than cooking oil.',
          cognitiveTask: {
            items: {
              mass: 'Total mass, including the container',
              volume: 'Volume of liquid in the container',
              material: 'Whether the contents are water or cooking oil',
              'cap-color': 'Color of the lid',
            },
            targets: {
              measure: 'Quantities to measure or keep equal',
              change: 'Materials being compared',
              irrelevant: 'Not used to compare density',
            },
          },
        },
        conditions: {
          recallPrompt:
            'To compare the densities of different materials fairly, explain which two quantities you must measure at minimum.',
          reasoningPrompt:
            'Give one example of a material whose volume cannot be measured from a change in water level, and add why a different method is needed.',
          transferPrompt:
            'Metal piece A has a mass of 54 g and a volume of 20 cm³. Metal piece B has a mass of 78 g and a volume of 30 cm³. Put the quantities on the same basis and compare which has the greater density.',
          expectedOutcome:
            'A is 2.7 g/cm³ and B is 2.6 g/cm³, so metal piece A has a slightly greater density.',
          expectedReason:
            'Instead of comparing masses alone, divide each mass by its volume and compare them as mass per unit volume in the same units.',
          checkpoint: {
            lure: 'B, at 78 g, is heavier than A, at 54 g, so B must have the greater density.',
            explanation:
              'The density of A is 54 ÷ 20 = 2.7 g/cm³, and B is 78 ÷ 30 = 2.6 g/cm³. Even though A has less total mass, A is greater per unit volume.',
            options: {
              'mass-ranking': {
                text: 'Ranking by mass gives the same order as ranking by density.',
                hint: 'The two metal pieces also have different volumes. Put them on a per-unit-volume basis.',
              },
              'normalize-volume': {
                text: 'Dividing each mass by its volume shows that A has the greater density.',
              },
              'volume-ranking': {
                text: 'B has the larger volume, so it has the greater density, and mass is not needed in the calculation.',
                hint: 'The density formula needs mass as well as volume.',
              },
            },
          },
          cognitiveTask: {
            items: {
              'both-quantities':
                'Measure the mass and volume of each sample, then compare mass ÷ volume in the same units.',
              'mass-alone': 'Measure only the mass of each sample and rank them from heaviest.',
              'volume-alone': 'Measure only the volume of each sample and rank them from largest.',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Explain the steps for using density to check whether two differently shaped objects are the same material, split into measuring and calculating.',
          reasoningPrompt:
            'If a calculated density differs slightly from a reference value, give one condition or source of error to check before concluding it is a different material.',
          transferPrompt:
            'You are investigating samples P and Q, which are different sizes and are said to have been cut from the same metal sheet. P has a mass of 27 g and a volume of 10 cm³; Q has a mass of 54 g and a volume of 20 cm³. Write what the results show and what you still cannot conclude.',
          expectedOutcome:
            'P and Q are both 2.7 g/cm³, so the result is that they have the same density. Even though one is twice as large, the density is the same.',
          expectedReason:
            'Mass and volume change in the same proportion. However, a different material with a matching density or measurement error is possible, so this result alone cannot determine the name of the material or prove they came from the same sheet.',
          checkpoint: {
            lure: 'If two samples have the same density, that proves they are the same material and were cut from the same sheet.',
            explanation:
              'Matching density is evidence supporting the same material, but it is not a unique identifier. Also consider measurement error and materials with similar densities, and combine density with other properties.',
            options: {
              'identity-certain': {
                text: 'If the densities match, that proves they are the same material, including where they came from.',
                hint: 'Consider whether a different material could have the same density, and whether rounding or measurement error could matter.',
              },
              'size-decides': {
                text: 'They are different sizes, so they cannot be the same material even if their densities match.',
                hint: 'Check what happens to the ratio of mass to volume when you change the amount of the same material.',
              },
              'evidence-not-proof': {
                text: 'It is one piece of evidence that they are the same material, but density alone cannot determine where they came from.',
              },
            },
          },
          cognitiveTask: {
            items: {
              compare: 'Compare P and Q as densities in the same units.',
              measure: 'Measure the mass and volume of P and of Q.',
              calculate: 'For each sample, divide the mass by the volume.',
            },
          },
        },
      },
      story: {
        title: 'The Case of the Twin Bottles',
        setting:
          'A sturdy table in the home economics room. Identical containers hold equal volumes of water and cooking oil, with their lids closed.',
        characters: CHARACTERS,
        openingLines: {
          'density.open.1':
            'They look the same and hold the same volume, but the water container is heavier.',
          'density.open.2':
            'We matched the container type and the volume inside, so we can compare per unit volume.',
          'density.open.3':
            'If we pour the oil into a bigger container, its density will grow and grow!',
        },
        choiceResponses: {
          'ratio-stays':
            'You explained it all the way to mass and volume changing in the same proportion.',
          'mass-only-halves':
            'Cutting it also halves the volume. It is not just the mass that changes.',
          'surface-doubles':
            'I snuck the number of cut faces into the density formula all by myself!',
        },
        resolutionLines: {
          'density.resolve.1':
            'Density is mass divided by volume, put on a per-unit-volume basis.',
          'density.resolve.2':
            'Changing only the amount of the same material does not change the ratio of mass to volume.',
        },
        punchline:
          'The density never grew. The only thing that grew was the pile of containers to wash.',
      },
      notation: {
        tasks: {
          'density.modelBuild': {
            title: 'Build the density ratio',
            prompt: 'Build the relationship for finding density, starting from the quantity you want.',
            guide: 'Put density on the left, then make the division that gives a per-unit-volume value.',
            solutionSummary: 'Density = mass ÷ volume. Keep mass and volume in a matching system of units.',
            tokens: {
              density: 'Density',
              equals: '=',
              mass: 'Mass',
              divide: '÷',
              volume: 'Volume',
            },
          },
          'density.tableRead': {
            title: 'Read the mass and volume table',
            prompt: 'Calculate the densities of P and Q from the table and choose the correct comparison.',
            solutionSummary: 'P is 27 ÷ 10 and Q is 54 ÷ 20, so both are 2.7 g/cm³.',
            representation: ['Sample | Mass | Volume', 'P | 27 g | 10 cm³', 'Q | 54 g | 20 cm³'],
            representationSemanticsLabel:
              'Columns are sample, mass, and volume. P is 27 grams and 10 cubic centimeters; Q is 54 grams and 20 cubic centimeters.',
            choices: {
              'q-double': 'Q has twice the mass, so it has twice the density',
              'same-ratio': 'P and Q are both 2.7 g/cm³, the same',
              'p-half': 'P has half the volume, so it has half the density',
            },
          },
          'density.symbolMatch': {
            title: 'Choose the unit of density',
            prompt: 'If mass is measured in g and volume in cm³, what is the unit of density?',
            solutionSummary: 'Density is mass ÷ volume, so its unit is g/cm³.',
            representationSemanticsLabel:
              'Choose the symbol that divides the mass unit, grams, by the volume unit, cubic centimeters.',
            choices: {
              gram: 'g',
              'gram-per-cubic-centimeter': 'g/cm³',
              'cubic-centimeter': 'cm³',
            },
          },
        },
      },
    },
    gasProperties: {
      practice: {
        foundation: {
          recallPrompt:
            'When choosing how to collect a gas, explain in what order you use water solubility and density relative to air.',
          reasoningPrompt:
            'Add why fixed data on reactions is needed for identification, even for colorless gases that look the same.',
          expectedOutcome:
            'From the property table, oxygen and hydrogen match collection over water, ammonia matches upward displacement of air, and carbon dioxide matches downward displacement of air.',
          expectedReason:
            'This uses the differences that oxygen and hydrogen are only slightly soluble in water, ammonia is extremely soluble in water and less dense than air, and carbon dioxide is denser than air.',
          cognitiveTask: {
            items: {
              oxygen: 'Oxygen, which is only slightly soluble in water',
              hydrogen: 'Hydrogen, which is only slightly soluble in water',
              ammonia: 'Ammonia, which is extremely soluble in water and less dense than air',
              'carbon-dioxide': 'Carbon dioxide, which is denser than air',
            },
            targets: {
              'water-displacement': 'Collection over water',
              'upward-displacement': 'Upward displacement of air',
              'downward-displacement': 'Downward displacement of air',
            },
          },
        },
        conditions: {
          recallPrompt:
            'Explain why collection over water cannot be used for a gas that is extremely soluble in water.',
          reasoningPrompt:
            'When collection over water is unsuitable, add the step of choosing a displacement method based on whether the gas is less or more dense than air.',
          transferPrompt:
            'Fixed data shows that unknown gas A is extremely soluble in water, less dense than air, and forms an alkaline solution in water. Choose the likely gas and a collection method.',
          expectedOutcome:
            'Gas A matches the properties of ammonia, so choose upward displacement of air instead of collection over water.',
          expectedReason:
            'Its very high water solubility makes collection over water unsuitable, and because it is less dense than air, it can be collected by pushing air out with upward displacement. The alkaline data also supports the identification.',
          checkpoint: {
            lure: 'Gas A dissolves very well in water, so collection over water will collect the most of it.',
            explanation:
              'A matches the properties of ammonia. Because it dissolves easily in water, avoid collection over water and choose upward displacement of air, which uses its lower density.',
            options: {
              'water-collection': {
                text: 'Collect it over water while letting it dissolve.',
                hint: 'Think about whether a gas you want to collect stays in the container as a gas if it dissolves in the water.',
              },
              'ammonia-upward': {
                text: 'Identify it as ammonia and collect it by upward displacement of air, using the fact that it is less dense than air.',
              },
              'carbon-dioxide-downward': {
                text: 'Identify it as carbon dioxide and choose only downward displacement of air.',
                hint: 'Check it against the data for the gas whose solution in water is alkaline.',
              },
            },
          },
          cognitiveTask: {
            items: {
              'select-upward': 'Choose upward displacement of air because the gas is less dense than air.',
              'check-solubility': 'Confirm that the gas is extremely soluble in water.',
              'match-alkaline': 'Narrow it down to ammonia from the record that its solution in water is alkaline.',
            },
          },
        },
        transfer: {
          recallPrompt:
            'When identifying an unknown colorless gas, explain why you use several properties instead of just one reaction.',
          reasoningPrompt:
            'Add the safety condition of not testing flammable or irritating gases at home and using the teacher’s fixed results instead.',
          transferPrompt:
            'Unknown gas X is only slightly soluble in water and slightly denser than air, and in the teacher’s fixed experiment record, an incense stick burned vigorously in it. Unknown gas Y turned limewater milky. Organize the identifications and the evidence for them.',
          expectedOutcome:
            'The evidence supports identifying X as oxygen and Y as carbon dioxide. However, X cannot be identified by its density alone, and Y cannot be identified just by looking colorless.',
          expectedReason:
            'This combines reactions specific to each gas, oxygen making things burn more easily and carbon dioxide turning limewater milky, with data on solubility and density.',
          checkpoint: {
            lure: 'X and Y are both colorless, so they can be judged to be the same gas.',
            explanation:
              'Do not rely on appearance alone. Identify gases by combining each gas’s own reactions with fixed data on solubility and density.',
            options: {
              'color-only': {
                text: 'Decide that X and Y are the same gas just because both are colorless.',
                hint: 'Use the fact that oxygen and carbon dioxide are both colorless but react differently.',
              },
              'density-alone': {
                text: 'Decide on one substance name from its density relative to air alone, without using the reaction records.',
                hint: 'Consider whether another gas with a similar density could also be a candidate.',
              },
              'combine-reactions': {
                text: 'Identify X as oxygen from the reaction showing it helps burning, and Y as carbon dioxide from limewater turning milky.',
              },
            },
          },
          cognitiveTask: {
            items: {
              'reaction-evidence':
                'Use the fixed reaction records to identify X as oxygen and Y as carbon dioxide.',
              'appearance-only': 'Treat X and Y as the same gas just because they look colorless.',
              'density-only': 'Decide on one substance name from density alone.',
            },
          },
        },
      },
      story: {
        title: 'The Case of the Mixed-Up Collection Cards',
        setting:
          'A reference table in the science room, laid out with a fixed property table for oxygen, carbon dioxide, hydrogen, and ammonia, plus cards for collection methods.',
        characters: CHARACTERS,
        openingLines: {
          'gasProperties.open.1':
            'It says ammonia is extremely soluble in water and less dense than air.',
          'gasProperties.open.2':
            'First we check whether collection over water works, then we read the density difference from air.',
          'gasProperties.open.3':
            'If they are clear, they are all on the same team! Everybody into the water!',
        },
        choiceResponses: {
          'property-based-method':
            'Checking water solubility first means the gas does not escape into the water.',
          'all-water-collection':
            'Ammonia dissolves in water, so collection over water will not work for it.',
          'appearance-identifies':
            'A “colorless” name tag could not even tell oxygen from carbon dioxide!',
        },
        resolutionLines: {
          'gasProperties.resolve.1':
            'Gases that barely dissolve in water are collected over water. If they dissolve easily, use the density difference to choose a displacement method.',
          'gasProperties.resolve.2':
            'For identification too, do not go by appearance. Combine reactions that were safely recorded ahead of time.',
        },
        punchline:
          'Team Invisible Gas read the property table, and it turns out every player has a different position.',
      },
      notation: {
        tasks: {
          'gasProperties.tableRead': {
            title: 'Read the gas property table',
            prompt: 'Using water solubility and density relative to air, choose how to collect ammonia.',
            solutionSummary:
              'Avoid collection over water for ammonia; collect it by upward displacement of air, using the fact that it is less dense than air.',
            representation: [
              'Gas | Solubility in water | Density vs. air',
              'NH₃ | Extremely soluble | Lower',
              'CO₂ | Soluble | Higher',
            ],
            representationSemanticsLabel:
              'Ammonia is extremely soluble in water and less dense than air. Carbon dioxide dissolves in water and is denser than air.',
            choices: {
              water: 'Collection over water',
              upward: 'Upward displacement of air',
              downward: 'Downward displacement of air',
            },
          },
          'gasProperties.sequence': {
            title: 'Order the steps for choosing a collection method',
            prompt: 'Put in order the steps for choosing a collection method for an unknown gas from the property table.',
            guide:
              'First look at how soluble it is in water; if collection over water is unsuitable, look at the density difference from air.',
            solutionSummary:
              'Check water solubility first; if the gas dissolves easily in water, choose a displacement method from the density difference.',
            tokens: {
              solubility: 'Check water solubility',
              'water-check': 'Decide whether collection over water works',
              density: 'Check the density difference from air',
              displacement: 'Choose upward or downward displacement',
            },
          },
          'gasProperties.symbolMatch': {
            title: 'Match a reaction record to a gas',
            prompt: 'Choose the gas that matches the fixed reaction record of turning limewater milky.',
            solutionSummary: 'Turning limewater milky is the evidence used to identify carbon dioxide.',
            representationSemanticsLabel:
              'Match gas names with identifying reactions that were safely recorded ahead of time.',
            choices: {
              oxygen: 'Oxygen O₂',
              'carbon-dioxide': 'Carbon dioxide CO₂',
              hydrogen: 'Hydrogen H₂',
            },
          },
        },
      },
    },
    stateChangeMass: {
      practice: {
        foundation: {
          recallPrompt:
            'Explain why the total mass of a closed system does not change even when a liquid inside becomes a gas.',
          reasoningPrompt:
            'Add the difference between becoming invisible and matter being lost from the measured system.',
          expectedOutcome:
            'In the sealed-container measurement record, the total mass including the container stays the same within the measured range, even when the liquid inside becomes a gas.',
          expectedReason:
            'In a change of state, only the arrangement and motion of particles of the same substance change, and no particles enter or leave the closed container.',
          cognitiveTask: {
            items: {
              'same-total-mass': 'The total mass, including the container, is the same.',
              'phase-transition': 'The particle arrangement of the liquid changes to that of a gas.',
              'sealed-boundary': 'The particles do not leave the sealed container.',
            },
          },
        },
        conditions: {
          recallPrompt:
            'Using the boundary of the system being measured, explain why the mass in an open container decreases after evaporation.',
          reasoningPrompt:
            'Add what range, including the surroundings, you would need to measure to confirm that mass did not vanish.',
          transferPrompt:
            'Compare records where equal amounts of liquid were placed in open dish A and in bag B, which lets no gas escape. After evaporation, what do you predict for each measurement, including the dish or the bag?',
          expectedOutcome:
            'In A, the gas leaves the measured range, so the mass left on the dish decreases. In B, the gas stays inside the bag, so the mass of the whole bag does not change.',
          expectedReason:
            'The difference is not the change of state itself, but whether the particles that became gas cross the boundary of the chosen system.',
          checkpoint: {
            lure: 'Only A loses mass because, in an open space, a change of state destroys matter.',
            explanation:
              'The apparent decrease in the open dish is because particles moved out. In the closed bag, they do not leave the whole being measured.',
            options: {
              'open-destroys': {
                text: 'In an open system particles are destroyed, and in a closed system new particles are created.',
                hint: 'Distinguish between matter disappearing and matter moving outside the measured range.',
              },
              'boundary-transfer': {
                text: 'A’s particles move outside the measured range as a gas, while B’s particles stay inside the bag.',
              },
              'bag-adds-mass': {
                text: 'The bag gives extra mass to the evaporated particles, so only B stays constant.',
                hint: 'Look at whether the bag’s job is to add matter or to keep matter from entering and leaving.',
              },
            },
          },
          cognitiveTask: {
            items: {
              'dish-vapor': 'Gas particles that moved from dish A into the surroundings',
              'bag-vapor': 'Gas particles that stayed inside bag B',
              'bag-reading': 'Measurement of the whole of bag B',
              'dish-reading': 'Measurement including dish A',
            },
            targets: {
              'outside-system': 'Moves outside the measured range / decreases',
              'inside-system': 'Stays inside the measured range / constant',
            },
          },
        },
        transfer: {
          recallPrompt:
            'When a solid becomes a liquid, explain what changes and what does not change in the particle model.',
          reasoningPrompt:
            'Using how it differs from density, add why the total mass stays the same even when the volume changes slightly.',
          transferPrompt:
            'A measurement diagram shows a solid turning completely into a liquid inside a sealed, flexible bag. Separate what you can say about the mass of the whole bag, the volume of the substance, and the type of particles.',
          expectedOutcome:
            'The mass of the whole bag and the type of particles do not change, but the volume of the substance and the arrangement and spacing of its particles may change.',
          expectedReason:
            'A change of state is a change in the arrangement of particles of the same substance. Conservation of mass does not mean the volume must stay constant, and density can also change with the state.',
          checkpoint: {
            lure: 'If the total mass is the same, then the volume and density must also be the same, and the particle arrangement does not change either.',
            explanation:
              'Conservation of mass in a closed system does not mean volume or density stay constant too. The particle arrangement changes with the state.',
            options: {
              'all-fixed': {
                text: 'Conservation of mass means mass, volume, density, and particle arrangement all stay constant.',
                hint: 'Think about whether particles are arranged and spaced the same way in a solid and a liquid.',
              },
              'new-particles': {
                text: 'Becoming a liquid turns the particles into a different type, but the mass happens to stay the same.',
                hint: 'Distinguish a change of state from a chemical change.',
              },
              'mass-only-conserved': {
                text: 'The mass of the whole closed system stays the same, but the volume and particle arrangement may change.',
              },
            },
          },
          cognitiveTask: {
            items: {
              'mass-stable-volume-variable':
                'Total mass and particle type stay the same, while volume and arrangement may change.',
              'everything-fixed': 'Mass, volume, and particle arrangement all stay the same.',
              'different-material': 'It becomes a different substance, but only the mass happens to stay the same.',
            },
          },
        },
      },
      story: {
        title: 'Where Did the Missing 1.5 Grams of Liquid Go?',
        setting:
          'The measurement data corner of the classroom, where a screen compares before-and-after evaporation data for an open dish and a sealed bag.',
        characters: CHARACTERS,
        openingLines: {
          'stateChangeMass.open.1':
            'The open dish lost mass, but the total mass of the sealed bag stayed the same.',
          'stateChangeMass.open.2':
            'We will not do any heating experiments. Let’s check the measured range using this fixed record.',
          'stateChangeMass.open.3':
            'If you cannot see it, it is gone! Mass turns into zero when it goes invisible.',
        },
        choiceResponses: {
          'closed-same-mass':
            'You measured the whole thing, including the gas inside the bag.',
          'gas-lost':
            'Gas has mass too. Let’s separate that from whether it left.',
          'phase-changes-mass':
            'I treated a costume change like a totally different person! The particles were the same type.',
        },
        resolutionLines: {
          'stateChangeMass.resolve.1':
            'In a change of state, the arrangement and motion of particles of the same substance change.',
          'stateChangeMass.resolve.2':
            'In a closed system, particles do not leave, so the total mass including the container does not change.',
        },
        punchline:
          'The 1.5 grams did not vanish. It just moved out of the measured range to a new address.',
      },
      notation: {
        tasks: {
          'stateChangeMass.sequence': {
            title: 'Follow a change of state in a closed system',
            prompt: 'Put a closed system where a liquid becomes a gas in order, from observation to conclusion.',
            guide:
              'Connect the change of state, the particles staying inside the system, and the comparison of total mass.',
            solutionSummary:
              'In a closed system, the particles that became gas also stay inside, so the total mass including the container is conserved.',
            tokens: {
              phase: 'The liquid changes state into a gas',
              retained: 'The particles stay inside the sealed container',
              weigh: 'Measure the whole container again',
              'same-mass': 'The total mass before and after is the same',
            },
          },
          'stateChangeMass.tableRead': {
            title: 'Read the open/closed mass table',
            prompt:
              'Choose the statement that correctly explains the mass change before and after evaporation using the system boundary.',
            solutionSummary:
              'The open dish lost mass because the matter that became gas moved outside the measured range.',
            representation: [
              'Condition | Before | After',
              'Open dish | 128.0 g | 126.5 g',
              'Sealed bag | 128.0 g | 128.0 g',
            ],
            representationSemanticsLabel:
              'The open dish lost 1.5 grams; the sealed bag was 128.0 grams both before and after.',
            choices: {
              'phase-destroys': 'Matter disappeared only in the open system',
              boundary: 'At the dish, gas moved outside the measured range',
              'bag-created': 'New mass was created inside the bag',
            },
          },
          'stateChangeMass.modelBuild': {
            title: 'Build a particle model of a change of state',
            prompt: 'For a change from solid to liquid, build what stays the same and what changes.',
            guide:
              'Keep the type and total number of particles, then follow with the changes in arrangement and spacing.',
            solutionSummary:
              'In a change of state, the type and total number of particles are kept, while their arrangement and motion change.',
            tokens: {
              'same-particles': 'Same type and total number of particles',
              arrangement: 'The regular arrangement breaks down',
              motion: 'Particles can change position more easily',
              'volume-limit': 'The volume may change',
            },
          },
        },
      },
    },
  },
}
