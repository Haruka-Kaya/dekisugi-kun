import type { UnitContentText } from '../i18n-content.js'

const CHARACTERS = {
  mio: { name: 'Mio', role: 'Observation and safety checks' },
  dekisugi: { name: 'Dekisugi-kun', role: 'Supremely confident hypotheses' },
  ren: { name: 'Ren', role: 'Checking conditions and records' },
}

const ARROW_TITLE = 'Trace the arrow in order of meaning'
const ARROW_TRACE_SUFFIX =
  ' Trace from the start point along the shaft, then the upper arrowhead, then the lower arrowhead.'
const EQUATION_TITLE = 'Build the equation from left to right'
const EQUATION_GUIDE =
  'Say what each quantity means out loud, and place them in order from the left side to the right side.'
const EQUATION_TRACE_SUFFIX =
  '. Trace the reading line first, then the check line across the equals sign.'
const SYMBOL_TITLE = 'Match the unit symbol to its meaning'
const SYMBOL_SEMANTICS = 'Match each symbol in the choices to its meaning.'
const GRAPH_TITLE = 'Read the graph'

const arrowStrokes = (taskId: string) => ({
  [`${taskId}.shaft`]: 'Arrow shaft from the start point',
  [`${taskId}.head-upper`]: 'Upper arrowhead',
  [`${taskId}.head-lower`]: 'Lower arrowhead',
})

const equationStrokes = (taskId: string) => ({
  [`${taskId}.reading-line`]: 'Line reading the equation from the left side to the right side',
  [`${taskId}.meaning-link`]: 'Check line connecting the left side and the right side',
})

const PRESSURE_ARROW_SUMMARY =
  'Pressure is the force perpendicular to a surface divided by the area.'
const BUOYANCY_ARROW_SUMMARY =
  'The buoyant force acts vertically upward on an object in a liquid.'

export const pressureBuoyancyContent: UnitContentText = {
  unitId: 'pressure-buoyancy',
  concepts: {
    pressure: {
      practice: {
        foundation: {
          recallPrompt:
            'Explain what determines pressure, using the relationship between force and area.',
          reasoningPrompt:
            'Add, using the words "per unit area," why a narrower surface digs into things more easily even with the same force.',
          expectedOutcome:
            'When pressed with about the same force, the narrow edge of an eraser usually makes a smaller, deeper dent than the wide face.',
          expectedReason:
            'If the force perpendicular to the surface is the same, a smaller contact area means a greater force per unit area, that is, a greater pressure. The comparison uses the same material and the same way of pressing.',
          cognitiveTask: {
            items: {
              'contact-face': 'The eraser’s wide face vs. its narrow edge',
              'eraser-force': 'The same eraser and the pushing force',
              'soft-material': 'The sponge or clay it is pressed into',
              'dent-depth': 'The depth of the dent',
            },
            targets: {
              change: 'Change',
              hold: 'Keep the same',
              measure: 'Measure',
            },
          },
        },
        conditions: {
          recallPrompt:
            'Explain how the pressure changes if you keep the pushing force the same and cut only the contact area in half.',
          reasoningPrompt:
            'Connect to the formula why you must not look at only force or only area when comparing pressures.',
          transferPrompt:
            'The same box is placed on a sponge, once on a wide face and once on a face with half that area. The box’s weight is the same. Predict the pressure and how the sponge dents, and write your reason.',
          expectedOutcome:
            'Halving the contact area doubles the pressure, so on the same sponge the dent is generally deeper.',
          expectedReason:
            'Pressure is the force perpendicular to a surface divided by the contact area. If everything except the box’s weight and how it is placed is kept the same, the force is the same and the area is halved, so the pressure doubles.',
          checkpoint: {
            lure:
              'If the force pushing on the surface stays the same, the pressure does not change even when the contact area is halved.',
            options: {
              'half-area-double-pressure': {
                text: 'The pressure doubles. Pressure is force divided by area, so with the same force and half the area, the value doubles.',
              },
              'half-area-half-pressure': {
                text: 'The pressure is halved, because the contact area is halved.',
                hint: 'In the pressure formula, check that area is in the denominator.',
              },
              'force-only-same': {
                text: 'If the pushing force is the same, the pressure is the same no matter the area.',
                hint: 'Recall that pressure is not the force itself, but the force divided by something.',
              },
            },
            explanation:
              'Pressure is force divided by area. If only the area is halved while the force stays the same, the same force acts on half the area, so the pressure doubles.',
          },
          cognitiveTask: {
            items: {
              'half-pressure': 'The pressure is halved.',
              'same-pressure': 'The pressure stays the same.',
              'double-pressure': 'The pressure doubles.',
              'quadruple-pressure': 'The pressure becomes four times as large.',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Using the formula, explain the steps for comparing pressure in two cases where both the force and the area are different.',
          reasoningPrompt:
            'Add why even a heavy object can produce a small pressure if its contact area is large enough.',
          transferPrompt:
            'A applies a force of 100 N perpendicular to 0.5 m², and B applies a force of 60 N perpendicular to 0.2 m². Which has the greater pressure? Write how you would calculate it.',
          expectedOutcome:
            'A’s pressure is 200 Pa and B’s is 300 Pa, so B has the greater pressure.',
          expectedReason:
            'Pressure is force divided by area. A is 100 ÷ 0.5 = 200 Pa and B is 60 ÷ 0.2 = 300 Pa, so B, with its smaller area, has a greater pressure than A, which only has the larger force.',
          checkpoint: {
            lure:
              'If A pushes with 100 N and B pushes with 60 N, A’s pressure is greater no matter the area.',
            options: {
              'larger-force-always': {
                text: 'A’s force is larger, so A’s pressure is greater without even calculating the contact areas.',
                hint: 'Pressure is a ratio that uses area as well as force. Calculate both in the same units.',
              },
              'calculate-ratio': {
                text: 'A is 200 Pa and B is 300 Pa, so B is greater. Compare by dividing force by area.',
              },
              'larger-area-always': {
                text: 'A’s area is larger, so A’s pressure is greater regardless of the difference in force.',
                hint: 'When area is in the denominator, a larger area alone does not mean a larger value.',
              },
            },
            explanation:
              'A’s pressure is 100 ÷ 0.5 = 200 Pa and B’s is 60 ÷ 0.2 = 300 Pa. Even though B’s force is smaller, its area is smaller still, so B has the greater force per unit area.',
          },
          cognitiveTask: {
            items: {
              'a-larger': 'A has the greater pressure.',
              'b-larger': 'B has the greater pressure.',
              'same-size': 'A and B have the same pressure.',
            },
          },
        },
      },
      story: {
        title: 'The Eraser Footprint Investigators',
        setting:
          'On top of soft clay. The team compares the marks the same force leaves from an eraser’s wide face and its narrow edge.',
        characters: CHARACTERS,
        openingLines: {
          'pressure.open.1': 'The mark from the narrow edge is smaller and deeper.',
          'pressure.open.2': 'I kept the pushing force the same and changed only the contact area.',
          'pressure.open.3': 'It’s the same eraser, so every face must have the same pressure!',
        },
        choiceResponses: {
          'same-pressure': 'Pressure depends on area too, not just force.',
          'wide-higher':
            'When the same force is spread over a wide face, the force per unit area gets smaller.',
          'narrow-higher': 'Divide force by area. That’s why the narrow edge’s footprint is deeper!',
        },
        resolutionLines: {
          'pressure.resolve.1':
            'If the perpendicular force is the same, the smaller the area, the greater the pressure.',
          'pressure.resolve.2':
            'That’s why the narrow edge left a deeper mark in the same material.',
        },
        punchline:
          'Case closed: the narrow edge left the footprint. An eraser leaving marks instead of removing them!',
      },
      notation: {
        tasks: {
          'pressure.arrow': {
            title: ARROW_TITLE,
            prompt: 'Place these in the order you think through the pressure on a surface.',
            guide:
              'Separate the force perpendicular to the surface from the area that force is spread over.',
            solutionSummary: PRESSURE_ARROW_SUMMARY,
            tokens: {
              'normal-force': 'Force perpendicular to the surface F',
              area: 'Area A',
              pressure: 'Pressure p',
            },
            tracePattern: {
              semanticsLabel: `${PRESSURE_ARROW_SUMMARY}${ARROW_TRACE_SUFFIX}`,
              strokes: arrowStrokes('pressure.arrow'),
            },
          },
          'pressure.equation': {
            title: EQUATION_TITLE,
            prompt: 'Build the equation for pressure.',
            guide: EQUATION_GUIDE,
            solutionSummary: 'Pressure p = F/A.',
            tokens: {
              p: 'p',
              eq: '=',
              f: 'F',
              divide: '÷',
              a: 'A',
            },
            tracePattern: {
              semanticsLabel: `p = F ÷ A${EQUATION_TRACE_SUFFIX}`,
              strokes: equationStrokes('pressure.equation'),
            },
          },
          'pressure.symbol': {
            title: SYMBOL_TITLE,
            prompt: 'Which is the same as the pressure unit Pa?',
            solutionSummary: '1 Pa = 1 N/m².',
            representationSemanticsLabel: SYMBOL_SEMANTICS,
            choices: {
              'n-m2': 'N/m²',
              'n-m': 'N·m',
              'kg-m': 'kg/m',
            },
          },
          'pressure.graph': {
            title: GRAPH_TITLE,
            prompt: 'With the force held constant, what happens to the pressure as the area increases?',
            solutionSummary:
              'With a constant force, pressure is inversely proportional to area, so it gets smaller.',
            representation: ['Pressure p', '＼＿', '   ＿', 'Area A →'],
            representationSemanticsLabel:
              'The horizontal axis is area and the vertical axis is pressure. A curve that falls as the area increases.',
            choices: {
              inverse: 'It gets smaller',
              'linear-up': 'It increases proportionally',
              fixed: 'It stays constant',
            },
          },
        },
      },
    },
    buoyancy: {
      practice: {
        foundation: {
          recallPrompt:
            'Explain what determines the buoyant force on an object in a liquid, using conditions of both the liquid and the object.',
          reasoningPrompt:
            'Add why you need to think about whether something floats or sinks separately from the size of the buoyant force itself.',
          expectedOutcome:
            'Even with the same amount of modeling clay, a solid ball sinks, but spreading it into a thin, watertight boat shape lets it float.',
          expectedReason:
            'As long as no water gets in, the boat shape pushes aside a larger volume of water than the ball before it sinks. As a result, the buoyant force, equal to the weight of the water pushed aside, can balance the gravity on the clay. The weight of the clay itself does not change.',
          cognitiveTask: {
            items: {
              'clay-shape': 'The clay’s shape, changed from a ball to a boat',
              'clay-mass': 'The amount and weight of the clay',
              'same-water': 'The liquid it is placed in',
              'float-result': 'Whether it floats or sinks',
            },
            targets: {
              change: 'Change',
              hold: 'Keep the same',
              measure: 'Observe',
            },
          },
        },
        conditions: {
          recallPrompt:
            'Explain how you would compare the buoyant forces when objects of the same volume are fully submerged in water and in oil, which is less dense than water.',
          reasoningPrompt:
            'Using "the weight of the liquid pushed aside," add why the buoyant force changes when the liquid changes, even if the submerged volume is the same.',
          transferPrompt:
            'The same object, whose volume does not change, is fully submerged in water and then in oil. Predict which gives the larger buoyant force, and connect your answer to the density of the liquids.',
          expectedOutcome:
            'In the usual case where water is denser than oil, the same fully submerged object receives a larger buoyant force in water.',
          expectedReason:
            'The buoyant force equals the weight of the liquid pushed aside. If the volume pushed aside is the same, that volume of a denser liquid weighs more, so the buoyant force is larger.',
          checkpoint: {
            lure:
              'If the same object is fully submerged with the same volume, the buoyant force is always the same in water and in oil.',
            options: {
              'same-volume-always-same': {
                text: 'If the volume pushed aside is the same, the buoyant force is the same no matter what kind of liquid it is.',
                hint: 'Even at the same volume, check whether the liquid pushed aside has the same weight.',
              },
              'oil-always-more': {
                text: 'Oil is more slippery, so it gives a larger buoyant force than water.',
                hint: 'Compare using the density and volume of the liquid pushed aside, not how slippery it is.',
              },
              'denser-liquid-more': {
                text: 'When the same volume is pushed aside, the denser the liquid, the heavier the liquid pushed aside, so the buoyant force is larger.',
              },
            },
            explanation:
              'Because the buoyant force equals the weight of the liquid pushed aside, it depends on the liquid’s density even when the submerged volume is the same. In water, which is generally denser than oil, an object pushing aside the same volume receives a larger buoyant force.',
          },
          cognitiveTask: {
            items: {
              'water-larger': 'It receives a larger buoyant force in water.',
              'oil-larger': 'It receives a larger buoyant force in oil.',
              'same-buoyancy': 'It receives the same buoyant force in both.',
            },
          },
        },
        transfer: {
          recallPrompt:
            'In the same liquid, explain how to think about the buoyant force when an object whose volume does not change is kept fully submerged and moved deeper.',
          reasoningPrompt:
            'Even though water pressure is greater at greater depth, add the conditions under which the buoyant force on the whole object does not change with depth alone.',
          transferPrompt:
            'A sealed container that does not change shape is fully submerged in water and moved from a shallow position to a deep one. The density of the water and the container’s volume stay constant. What do you predict for the buoyant force?',
          expectedOutcome:
            'If the water’s density and the container’s volume are constant, the buoyant force on the fully submerged container is the same at the shallow position and the deep position.',
          expectedReason:
            'A fully submerged container that does not change shape pushes aside the same volume of water at any depth. The buoyant force equals the weight of that water, so as long as the density and the container’s volume do not change, depth alone does not change it.',
          checkpoint: {
            lure:
              'The deeper the same object goes in water, the greater the water pressure, so the buoyant force on a fully submerged object must also get larger.',
            options: {
              'same-displaced-water': {
                text: 'In the same liquid, if the object’s submerged volume does not change, the weight of the water pushed aside is the same, so the buoyant force does not change.',
              },
              'deeper-more-buoyancy': {
                text: 'The deeper it goes, the more water pressure there is on the object from every direction, so the buoyant force also increases in proportion to depth.',
                hint: 'Don’t just raise the pressure on the top and bottom faces separately; look at their difference and the amount of water pushed aside.',
              },
              'deeper-less-buoyancy': {
                text: 'The deeper it goes, the more the water presses it down, so the upward buoyant force gets smaller.',
                hint: 'Check the direction of the buoyant force and how it relates to the weight of the liquid the object pushed aside.',
              },
            },
            explanation:
              'In a liquid of the same density, if the object is fully submerged and its volume does not change, the volume and weight of the liquid pushed aside stay constant. So the buoyant force does not change with depth alone.',
          },
          cognitiveTask: {
            items: {
              'top-pressure': 'The liquid pressure on the object’s top face',
              'bottom-pressure': 'The liquid pressure on the object’s bottom face',
              'displaced-volume': 'The volume of liquid the object pushes aside',
              'buoyant-force': 'The buoyant force on the object',
            },
            targets: {
              'depth-increase': 'Gets larger when deeper',
              'depth-steady': 'Does not change with depth alone',
            },
          },
        },
      },
      story: {
        title: 'The Clay Ship’s Big Comeback from the Deep',
        setting:
          'A clear container filled with water. Equal amounts of modeling clay are compared as a ball and as a watertight boat shape.',
        characters: CHARACTERS,
        openingLines: {
          'buoyancy.open.1': 'The clay ball sank, but the boat shape floated. They weigh the same.',
          'buoyancy.open.2': 'Before it sinks, the boat shape pushes aside more water than the ball does.',
          'buoyancy.open.3': 'Shape it like a boat and the clay suddenly feels light at heart.',
        },
        choiceResponses: {
          'heavier-more':
            'If they’re fully submerged with the same volume, they push aside the same volume of liquid.',
          'same-displacement':
            'If the liquid’s density and the volume under the liquid are the same, the buoyant force is the same too.',
          'lighter-more':
            'I was mixing up how easily something floats with what decides the buoyant force it gets!',
        },
        resolutionLines: {
          'buoyancy.resolve.1': 'The buoyant force equals the weight of the liquid pushed aside.',
          'buoyancy.resolve.2':
            'The boat shape pushes aside a large volume of water, so it can balance gravity.',
        },
        punchline:
          'The clay is just as heavy as ever. But the captain’s spirits? Fully afloat!',
      },
      notation: {
        tasks: {
          'buoyancy.arrow': {
            title: ARROW_TITLE,
            prompt:
              'Place these in the order for drawing the buoyant force on an object that is completely in a liquid.',
            guide:
              'Starting from the object, draw the buoyant-force arrow pointing vertically upward.',
            solutionSummary: BUOYANCY_ARROW_SUMMARY,
            tokens: {
              body: 'Object',
              up: 'Vertically upward',
              fb: 'Buoyant force Fᵦ',
            },
            tracePattern: {
              semanticsLabel: `${BUOYANCY_ARROW_SUMMARY}${ARROW_TRACE_SUFFIX}`,
              strokes: arrowStrokes('buoyancy.arrow'),
            },
          },
          'buoyancy.equation': {
            title: EQUATION_TITLE,
            prompt: 'Build the equation that expresses the buoyant force using the liquid pushed aside.',
            guide: EQUATION_GUIDE,
            solutionSummary:
              'Buoyant force Fᵦ = ρgV (V is the volume of liquid pushed aside).',
            tokens: {
              fb: 'Fᵦ',
              eq: '=',
              rho: 'ρ',
              g: 'g',
              v: 'V',
            },
            tracePattern: {
              semanticsLabel: `Fᵦ = ρ g V${EQUATION_TRACE_SUFFIX}`,
              strokes: equationStrokes('buoyancy.equation'),
            },
          },
          'buoyancy.symbol': {
            title: SYMBOL_TITLE,
            prompt: 'What quantity does ρ stand for?',
            solutionSummary: 'ρ is the density of the liquid.',
            representationSemanticsLabel: SYMBOL_SEMANTICS,
            choices: {
              density: 'Density of the liquid',
              depth: 'Water depth',
              area: 'Base area',
            },
          },
          'buoyancy.graph': {
            title: GRAPH_TITLE,
            prompt:
              'In the same liquid, what happens to the buoyant force as the volume pushed aside increases?',
            solutionSummary:
              'In the same liquid, the buoyant force is proportional to the volume pushed aside.',
            representation: ['Buoyant force', '／', '／', 'Volume V →'],
            representationSemanticsLabel:
              'The horizontal axis is the volume pushed aside and the vertical axis is the buoyant force. A line rising to the right from the origin.',
            choices: {
              proportional: 'It increases proportionally',
              fixed: 'It does not change',
              decrease: 'It decreases',
            },
          },
        },
      },
    },
  },
}
