import type { UnitContentText } from '../i18n-content.js'

export const forceBalanceContent: UnitContentText = {
  unitId: 'force-balance',
  concepts: {
    actionReaction: {
      practice: {
        foundation: {
          recallPrompt:
            'When two objects push on each other, explain action and reaction using three points: size, direction, and which object each force acts on.',
          reasoningPrompt:
            'Even when a heavy object and a light object move differently, add a reason for what stays the same about the pair of forces.',
          expectedOutcome:
            'The harder you push the wall, the harder your hand feels pushed back. At every moment of the push, the force of the hand on the wall and the force of the wall on the hand are equal in size and opposite in direction.',
          expectedReason:
            'These two forces are an action-reaction pair produced at the same time by the same interaction: the contact between hand and wall. One acts on the wall and the other acts on the hand, which are different objects.',
          cognitiveTask: {
            items: {
              'hand-on-wall': 'Force of the hand on the wall',
              'wall-on-hand': 'Force of the wall on the hand',
              'strong-wall-on-hand': 'Force of the wall on the hand when you push hard',
            },
            targets: {
              'toward-wall': 'Points from the hand toward the wall',
              'toward-hand': 'Points from the wall toward the hand',
            },
          },
        },
        conditions: {
          recallPrompt:
            'When an astronaut pushes a satellite with their hands, explain the forces the astronaut and the satellite each receive from the other.',
          reasoningPrompt:
            'Connect to mass the reason why receiving forces of the same size does not necessarily mean having the same acceleration.',
          transferPrompt:
            'In space, where friction can be ignored, two people with different masses put their palms together and push. What do you predict about the forces on each person and how each one moves?',
          expectedOutcome:
            'While they push, the forces on the two people are equal in size and opposite in direction. The person with the smaller mass accelerates more, and their velocity changes more.',
          expectedReason:
            'Action and reaction forces of the same size act on different people. Each acceleration equals the force divided by the mass, so the lighter person has the larger acceleration.',
          checkpoint: {
            lure:
              'When an astronaut pushes a satellite that is heavier than they are, the satellite pushes back with a larger force than the astronaut exerts.',
            options: {
              'satellite-bigger-force': {
                text: 'The heavy satellite can exert more force, so the force on the astronaut is larger.',
                hint: 'Compare the two forces produced by the same interaction during the push as one pair.',
              },
              'astronaut-bigger-force': {
                text: 'The astronaut moves more easily and accelerates more, so the force on the satellite is larger.',
                hint: 'Do not decide which force is bigger from the difference in acceleration alone; think about the link with mass separately.',
              },
              'equal-opposite-different-acceleration': {
                text: 'The forces they exert on each other are equal in size and opposite in direction, but if their masses differ, their accelerations differ.',
              },
            },
            explanation:
              'While they push, the force of the astronaut on the satellite and the force of the satellite on the astronaut are equal in size and opposite in direction. They act on different objects, and for the same force, the object with the smaller mass has the larger acceleration.',
          },
          cognitiveTask: {
            items: {
              'equal-force-light-acceleration':
                'The forces are equal in size and opposite in direction, and the person with the smaller mass has the larger acceleration.',
              'heavy-force-dominates':
                'The person with the larger mass exerts a larger force on the other person.',
              'equal-force-equal-acceleration':
                'Because the forces are the same size, the accelerations are the same even if the masses differ.',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Two skaters push off each other and move apart. Explain the action-reaction forces and each skater’s motion separately.',
          reasoningPrompt:
            'Add a reason why the two action-reaction forces do not cancel each other, focusing on whether they act on the same object.',
          transferPrompt:
            'A light skater and a heavy skater start at rest and push each other with their hands. Compare the forces while they push and the changes in velocity just after they separate, and make a prediction.',
          expectedOutcome:
            'While they push, the forces are equal in size and opposite in direction. Just after they separate, the lighter skater has the larger change in velocity.',
          expectedReason:
            'The two action-reaction forces act on different people, and even though they are the same size, the lighter person has the larger acceleration. If they start at rest and outside horizontal forces can be ignored, the two skaters end up with momentum of equal size in opposite directions.',
          checkpoint: {
            lure:
              'The lighter skater moved more, so only the lighter skater received a larger force.',
            options: {
              'equal-force-mass-difference': {
                text: 'The forces on the two skaters are equal in size and opposite in direction. The lighter skater has the larger acceleration, so their motion changes more.',
              },
              'lighter-receives-more': {
                text: 'Since the lighter skater moved more, the force on the lighter skater is larger.',
                hint: 'A change in motion depends on mass as well as force. Separate the pair of forces from the acceleration.',
              },
              'forces-cancel-between-people': {
                text: 'The two forces are the same size, so they cancel out between the two people, and neither can move.',
                hint: 'Check whether the two forces act on the same single object, and what each force acts on.',
              },
            },
            explanation:
              'Action and reaction act on different objects, so they do not cancel each other. Even though the forces are equal in size, the skater with the smaller mass has the larger acceleration and change in velocity.',
          },
          cognitiveTask: {
            items: {
              'interaction-forces': 'Size of the force each skater receives while they push',
              accelerations: 'Size of the acceleration while they push',
              'velocity-changes': 'Size of the change in velocity up to just after they separate',
            },
            targets: {
              'same-size': 'Same size for both skaters',
              'lighter-larger': 'Larger for the lighter skater',
              'heavier-larger': 'Larger for the heavier skater',
            },
          },
        },
      },
      story: {
        title: 'The Silent Wall’s High Five',
        setting:
          'In front of a sturdy school wall. The friends compare how it feels to push with a palm gently, then a little harder.',
        characters: {
          mio: { name: 'Mio', role: 'Observation and safety checks' },
          dekisugi: { name: 'Dekisugi-kun', role: 'Overconfident hypotheses' },
          ren: { name: 'Ren', role: 'Checking conditions and records' },
        },
        openingLines: {
          'actionReaction.open.1':
            'The harder I push, the harder my hand feels pushed back.',
          'actionReaction.open.2':
            'The force on the wall and the force on your hand act on different objects.',
          'actionReaction.open.3':
            'The wall never says a word, but it always gives a full-power high five.',
        },
        choiceResponses: {
          'truck-bigger':
            'A difference in weight matters for differences in acceleration and damage, but the force pair is a separate question.',
          'equal-pair':
            'Right: a pair of forces, equal in size and opposite in direction, acting on different objects.',
          'bicycle-bigger':
            'I was mixing up how badly something gets damaged with the force of the interaction!',
        },
        resolutionLines: {
          'actionReaction.resolve.1':
            'Action and reaction arise at the same time from the same interaction.',
          'actionReaction.resolve.2':
            'Equal in size and opposite in direction. But they act on different objects, so they don’t cancel out.',
        },
        punchline:
          'Talking with a wall is easy: it never starts the conversation, but it always matches my energy.',
      },
      notation: {
        tasks: {
          'actionReaction.arrow': {
            title: 'Trace the arrows in order of meaning',
            prompt: 'Place the two action-reaction arrows in the order that pairs them up.',
            guide:
              'Start each arrow on a different object, and draw them along the same line in opposite directions.',
            solutionSummary: 'Action and reaction are a pair of forces acting on different objects.',
            tokens: {
              'a-on-b': 'A pushes B',
              'b-on-a': 'B pushes A',
              opposite: 'Same size, opposite direction',
            },
            tracePattern: {
              semanticsLabel:
                'Action and reaction are a pair of forces acting on different objects. Trace the shaft from the starting point, then the upper arrowhead, then the lower arrowhead.',
              strokes: {
                'actionReaction.arrow.shaft': 'Arrow shaft from the starting point',
                'actionReaction.arrow.head-upper': 'Upper arrowhead',
                'actionReaction.arrow.head-lower': 'Lower arrowhead',
              },
            },
          },
          'actionReaction.equation': {
            title: 'Build the equation from left to right',
            prompt: 'Build the vector equation for action and reaction.',
            guide:
              'Say what each quantity means out loud, and place them in order from the left side to the right side.',
            solutionSummary:
              'Fᴬ→ᴮ = −Fᴮ→ᴬ. The sizes are equal and the directions are opposite.',
            tokens: {
              fab: 'Fᴬ→ᴮ',
              eq: '=',
              minus: '−',
              fba: 'Fᴮ→ᴬ',
            },
            tracePattern: {
              semanticsLabel:
                'Fᴬ→ᴮ = − Fᴮ→ᴬ. Trace the reading line of the equation, then the check line across the equals sign.',
              strokes: {
                'actionReaction.equation.reading-line':
                  'Line reading the equation from the left side to the right side',
                'actionReaction.equation.meaning-link':
                  'Check line connecting the left side and the right side',
              },
            },
          },
          'actionReaction.symbol': {
            title: 'Match the symbol to its meaning',
            prompt: 'What do action and reaction act on?',
            solutionSummary:
              'The two forces act on different objects, so they do not cancel on one object.',
            representationSemanticsLabel: 'Match each choice’s symbol to its meaning.',
            choices: {
              different: 'Two different objects',
              same: 'The same single object',
              none: 'Empty space, not an object',
            },
          },
          'actionReaction.graph': {
            title: 'Read the graph',
            prompt:
              'During contact, when one force gets larger, what happens to the force from the other object?',
            solutionSummary:
              'During the interaction, the two forces are equal in size at every moment.',
            representation: ['Force size', '／  ／', '／  ／', 'Time →'],
            representationSemanticsLabel:
              'The sizes of the two forces overlap over time. Their directions are opposite.',
            choices: {
              'same-size': 'It becomes the same size at the same moment',
              delay: 'It becomes the same size later',
              unrelated: 'It is always a different size',
            },
          },
        },
      },
    },
    balance: {
      practice: {
        foundation: {
          recallPrompt:
            'Explain what it means for the forces on one object to be balanced, in terms of both the net force and the motion.',
          reasoningPrompt:
            'Add a reason, using changes in speed and direction, why "if the forces are balanced, the object is at rest" is not always true.',
          expectedOutcome:
            'When an elevator moves upward at a constant speed, the upward force of the floor on the person is equal in size to the downward force of gravity, and the net force is zero.',
          expectedReason:
            'Even when moving upward, if the velocity is constant, the acceleration is zero. A net force of zero does not mean there are no individual forces; the floor’s force and gravity are balanced.',
          cognitiveTask: {
            items: {
              'person-gravity': 'Gravity acting on the person',
              'floor-force': 'Force of the floor pushing on the person',
              'person-net-force': 'Net force on a person rising at constant speed',
            },
            targets: {
              'zero-size': 'Size zero',
              downward: 'Downward',
              upward: 'Upward',
            },
          },
        },
        conditions: {
          recallPrompt:
            'When an elevator rises at a constant speed, explain how gravity on the person inside relates to the force from the floor.',
          reasoningPrompt:
            'Tell apart moving upward and having an upward net force. Also write when the speed changes.',
          transferPrompt:
            'Compare an elevator moving upward at a constant speed with one moving upward and speeding up. Predict the net force on the person in each case.',
          expectedOutcome:
            'Moving upward at a constant speed, the net force is zero. Moving upward and speeding up, the net force is upward, and the force from the floor is larger than gravity.',
          expectedReason:
            'When the velocity is constant, the acceleration is zero, so the forces are balanced. When the upward velocity is increasing, there is an upward acceleration, so an upward net force is needed.',
          checkpoint: {
            lure:
              'While an elevator rises at a constant speed, the upward force of the floor on the person is larger than gravity.',
            options: {
              'upward-force-bigger': {
                text: 'It is moving upward, so the force from the floor is larger than gravity.',
                hint: 'Think about how the velocity would change if there were a difference between the forces, and tell apart "moving upward" from "speeding up upward."',
              },
              'balanced-at-constant-speed': {
                text: 'At constant velocity the acceleration is zero, so the force from the floor and gravity are balanced and the net force is zero.',
              },
              'no-floor-force-moving': {
                text: 'While it is moving, the floor exerts no force on the person, even though they are in contact.',
                hint: 'When the person stays on the floor and moves along with it, check whether there is a force from the floor supporting the person.',
              },
            },
            explanation:
              'Even when moving upward, if the velocity is constant, the acceleration is zero. The upward force of the floor on the person and the downward force of gravity are equal in size, and the net force is zero.',
          },
          cognitiveTask: {
            items: {
              'constant-upward': 'Moves upward at a constant speed.',
              'speeding-upward': 'Speeds up while moving upward.',
              'slowing-upward': 'Slows down while moving upward.',
            },
            targets: {
              'net-downward': 'Net force is downward',
              'net-zero': 'Net force is zero',
              'net-upward': 'Net force is upward',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Give one example of an object whose forces are balanced while it is moving, and explain the individual forces and the net force.',
          reasoningPrompt:
            'Using force arrows on the same object, explain that a net force of zero does not mean the individual forces have disappeared.',
          transferPrompt:
            'Think about a falling person who eventually reaches a constant speed. What do you predict about gravity, air resistance, and the net force at that moment?',
          expectedOutcome:
            'While falling at a constant speed, downward gravity and upward air resistance are equal in size, and the net force is zero.',
          expectedReason:
            'Even while falling, if the velocity is constant, the acceleration is zero. Gravity and air resistance each still exist and balance each other; in this terminal-velocity state, the downward motion continues.',
          checkpoint: {
            lure:
              'A falling object is moving downward, so even after it reaches a constant speed, gravity is larger than air resistance.',
            options: {
              'gravity-bigger-while-falling': {
                text: 'As long as it is moving downward, gravity must be larger than air resistance.',
                hint: 'If a downward difference between the forces remained, think about whether the speed could stay constant.',
              },
              'forces-disappear': {
                text: 'The moment the speed becomes constant, both gravity and air resistance disappear.',
                hint: 'Tell apart a net force of zero from there being no individual forces.',
              },
              'balanced-terminal-motion': {
                text: 'At constant velocity, gravity and air resistance are balanced, so the net force is zero even while it moves downward.',
              },
            },
            explanation:
              'If the falling speed is constant, the acceleration is zero. Downward gravity and upward air resistance each still exist and become equal in size, so the net force is zero.',
          },
          cognitiveTask: {
            items: {
              'force-balance': 'Upward air resistance and downward gravity become equal in size.',
              'speed-growth': 'The object starts to fall and its speed increases.',
              'terminal-motion':
                'The net force becomes zero, and the object falls at a constant terminal velocity.',
              'drag-growth': 'As the speed increases, the upward air resistance gets larger.',
            },
          },
        },
      },
      story: {
        title: 'The Rising Elevator’s Alibi',
        setting:
          'Inside the school elevator. The display shows it going up, and the friends pick a stretch where it moves at a constant speed to think about.',
        characters: {
          mio: { name: 'Mio', role: 'Observation and safety checks' },
          dekisugi: { name: 'Dekisugi-kun', role: 'Overconfident hypotheses' },
          ren: { name: 'Ren', role: 'Checking conditions and records' },
        },
        openingLines: {
          'balance.open.1': 'We’re moving upward right now, but our speed isn’t changing.',
          'balance.open.2':
            'The upward force from the floor and the downward force of gravity are both still here.',
          'balance.open.3': 'If we’re going up, Team Up must be winning!',
        },
        choiceResponses: {
          'balanced-moving':
            'Even while moving, if the velocity is constant, a net force of zero explains it.',
          'forward-bigger':
            'If there were an upward net force, the upward velocity would have to increase.',
          'no-forces':
            'If the individual forces vanished, the floor and gravity would both be marked absent!',
        },
        resolutionLines: {
          'balance.resolve.1':
            'If the floor’s force and gravity are equal in size and opposite in direction, the net force is zero.',
          'balance.resolve.2':
            'A net force of zero fits not only being at rest, but also moving at a constant velocity.',
        },
        punchline: 'The elevator kept going up. My theory kept going down.',
      },
      notation: {
        tasks: {
          'balance.arrow': {
            title: 'Trace the arrows in order of meaning',
            prompt: 'Place the steps for checking balanced forces on one object in order.',
            guide:
              'Start the arrows on the same object and draw them so that they add up to zero.',
            solutionSummary:
              'Balanced forces means the net force of the forces acting on the same object is zero.',
            tokens: {
              'same-body': 'The same object',
              'all-forces': 'All the forces',
              'zero-sum': 'Vector sum is 0',
            },
            tracePattern: {
              semanticsLabel:
                'Balanced forces means the net force of the forces acting on the same object is zero. Trace the shaft from the starting point, then the upper arrowhead, then the lower arrowhead.',
              strokes: {
                'balance.arrow.shaft': 'Arrow shaft from the starting point',
                'balance.arrow.head-upper': 'Upper arrowhead',
                'balance.arrow.head-lower': 'Lower arrowhead',
              },
            },
          },
          'balance.equation': {
            title: 'Build the equation from left to right',
            prompt: 'Build the equation for the condition of balanced forces.',
            guide:
              'Say what each quantity means out loud, and place them in order from the left side to the right side.',
            solutionSummary: 'The condition for balanced forces is ΣF = 0.',
            tokens: {
              sumf: 'ΣF',
              eq: '=',
              zero: '0',
            },
            tracePattern: {
              semanticsLabel:
                'ΣF = 0. Trace the reading line of the equation, then the check line across the equals sign.',
              strokes: {
                'balance.equation.reading-line':
                  'Line reading the equation from the left side to the right side',
                'balance.equation.meaning-link':
                  'Check line connecting the left side and the right side',
              },
            },
          },
          'balance.symbol': {
            title: 'Match the symbol to its meaning',
            prompt: 'What operation does Σ stand for?',
            solutionSummary: 'Σ is the sum of all the forces acting on the object in question.',
            representationSemanticsLabel: 'Match each choice’s symbol to its meaning.',
            choices: {
              sum: 'Add them all, including direction',
              largest: 'Pick only the largest force',
              pair: 'Compare just two forces',
            },
          },
          'balance.graph': {
            title: 'Read the graph',
            prompt:
              'What does the position–time graph look like for an object at rest with a net force of 0?',
            solutionSummary:
              'If it stays at rest, its position does not change, so the graph is a horizontal line.',
            representation: ['Position x', '────', 'Time t →'],
            representationSemanticsLabel:
              'The horizontal axis is time and the vertical axis is position. A horizontal straight line.',
            choices: {
              flat: 'Horizontal line with constant position',
              linear: 'Slopes up to the right',
              curve: 'Curve bending upward',
            },
          },
        },
      },
    },
  },
}
