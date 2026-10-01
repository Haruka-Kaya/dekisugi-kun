import type { UnitContentText } from '../i18n-content.js'

const ARROW_TRACE_SUFFIX =
  ' Trace from the starting point along the shaft, then the upper arrowhead, then the lower arrowhead.'
const EQUATION_TRACE_SUFFIX =
  '. Trace the reading line of the equation, then the check line across the equals sign.'
const ARROW_TITLE = 'Trace the arrow in order of meaning'
const EQUATION_TITLE = 'Build the equation from left to right'
const EQUATION_GUIDE =
  'Say what each quantity means out loud, and place them in order from the left side to the right side.'
const SYMBOL_TITLE = 'Match the unit symbol to its meaning'
const SYMBOL_SEMANTICS = 'Match each symbol in the choices to its meaning.'
const GRAPH_TITLE = 'Read the graph'

const arrowStrokes = (taskId: string): Record<string, string> => ({
  [`${taskId}.shaft`]: 'Arrow shaft from the starting point',
  [`${taskId}.head-upper`]: 'Upper arrowhead',
  [`${taskId}.head-lower`]: 'Lower arrowhead',
})

const equationStrokes = (taskId: string): Record<string, string> => ({
  [`${taskId}.reading-line`]: 'Line reading the equation from the left side to the right side',
  [`${taskId}.meaning-link`]: 'Check line connecting the left side and the right side',
})

const CHARACTERS = {
  mio: { name: 'Mio', role: 'Observation and safety checks' },
  dekisugi: { name: 'Dekisugi-kun', role: 'Overconfident hypotheses' },
  ren: { name: 'Ren', role: 'Checking conditions and records' },
}

const CHANGE_HOLD_MEASURE = {
  change: 'Change',
  hold: 'Keep the same',
  measure: 'Measure',
}

const FALL_ARROW_SUMMARY =
  'The gravity arrow is drawn from the center of the object, straight down.'
const INERTIA_ARROW_SUMMARY =
  'With zero net force, an object stays at rest or keeps moving in a straight line at constant speed.'
const FRICTION_ARROW_SUMMARY =
  'Friction force acts along the contact surface, in the direction that resists relative motion.'
const THROWUP_ARROW_SUMMARY =
  'Ignoring air resistance, only downward gravity acts during the flight.'

export const forceMotionContent: UnitContentText = {
  unitId: 'force-motion',
  concepts: {
    fall: {
      practice: {
        foundation: {
          recallPrompt:
            'Explain how the speed at which an object falls is related to its weight, including the condition under which that holds.',
          reasoningPrompt:
            'A heavier object is pulled by a stronger gravitational force, so what is the conclusion? Add the reason, using the idea of how hard the object is to get moving.',
          expectedOutcome:
            'Released together in air, the crumpled paper usually lands first, while the flat sheet flutters and lands later.',
          expectedReason:
            'The two sheets have the same mass, but the flat sheet catches air over a larger effective area, so air resistance matters more compared with gravity. This does not contradict the fact that falling acceleration does not depend on weight when air resistance is negligible.',
          cognitiveTask: {
            items: {
              'flat-arrival': 'The flat sheet lands first, and the crumpled paper lands after it.',
              'paired-arrival': 'Even though their shapes differ, they land at about the same time.',
              'crumpled-arrival': 'The crumpled paper lands first, and the flat sheet lands later.',
            },
          },
        },
        conditions: {
          recallPrompt:
            'When you compare dropping the same sheet of paper flat and crumpled, explain what you can find out.',
          reasoningPrompt:
            'Having the same weight does not always make two things fall the same way. Name one other condition that affects the result, and add the reason.',
          transferPrompt:
            'Inside a clear tube, a feather and a metal ball are released at the same moment from the same height. If you gradually pump the air out of the tube, how do you predict the gap between their landing times will change? Give your reason too.',
          expectedOutcome:
            'The more air is removed from the tube, the smaller the gap between the landing times becomes; once the tube is close enough to a vacuum, they land at almost the same time.',
          expectedReason:
            'With less air, the air resistance that was slowing the feather in particular becomes smaller. At the same location, when air resistance is negligible, the falling acceleration due to gravity is the same regardless of weight.',
          checkpoint: {
            lure:
              'If a feather falls more slowly than a metal ball in air, that proves heavier objects have a greater falling acceleration.',
            explanation:
              'Falling through air involves air resistance as well as gravity. A feather and a metal ball differ in shape and in how strongly air resistance affects them relative to their weight, so that observation alone does not show that mass determines falling acceleration.',
            options: {
              'air-resistance-condition': {
                text: 'That result alone does not show an effect of weight. The effects of shape and air resistance need to be separated out in the comparison.',
              },
              'mass-proven': {
                text: 'The metal ball landed first, so falling acceleration is determined by mass alone.',
                hint: 'The two objects differ not only in weight but also in shape and in the force they get from the air. Look at what must be kept the same for a fair comparison.',
              },
              'air-pushes-up-equally': {
                text: 'Air pushes up on every object with the same strength, so the difference comes from weight alone.',
                hint: 'Air resistance also changes with an object’s shape, area, speed, and so on. It is not necessarily the same for two objects.',
              },
            },
          },
          cognitiveTask: {
            items: {
              'time-gap': 'The gap between the landing times of the feather and the metal ball gets smaller.',
              'air-amount': 'There is less air inside the tube.',
              'feather-drag': 'The air resistance slowing the feather gets smaller.',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Explain the experiment of dropping a feather and a hammer at the same time on the Moon, focusing on how the conditions differ from those on Earth.',
          reasoningPrompt:
            'To compare fairly how two objects fall, what else besides air do you need to keep the same? Name at least one thing and give the reason.',
          transferPrompt:
            'Inside a vacuum chamber, two balls with the same shape but different weights are gently released at the same moment from the same height. Which do you predict reaches the bottom first? Connect your answer to the conditions of the observation.',
          expectedOutcome:
            'Released gently at the same moment from the same height, the heavy ball and the light ball reach the bottom at the same time.',
          expectedReason:
            'In a vacuum there is no air resistance, and at the same location near Earth’s surface the acceleration due to gravity does not depend on mass. This holds for a comparison in which the height, the release time, and the initial speed are kept the same.',
          checkpoint: {
            lure:
              'Even in a vacuum, a thin plate and a small ball of the same weight have different shapes, so their falling accelerations are also different.',
            explanation:
              'In a vacuum there is no air resistance, and at the same location near Earth’s surface the acceleration due to gravity is the same regardless of an object’s shape or weight. Released gently at the same moment from the same height, the objects land together.',
            options: {
              'shape-changes-vacuum': {
                text: 'A different shape changes air resistance even in a vacuum, so the falling acceleration changes too.',
                hint: 'Under the condition of a vacuum, check which force a difference in shape was supposed to change.',
              },
              'flat-object-floats': {
                text: 'An upward gravitational force acts on the thin plate, so it falls more slowly than the small ball.',
                hint: 'The direction in which Earth’s gravity acts on an object does not flip upside down depending on its shape.',
              },
              'same-gravitational-acceleration': {
                text: 'In a vacuum, falling acceleration is the same regardless of shape or weight, so objects released under the same conditions land together.',
              },
            },
          },
          cognitiveTask: {
            items: {
              'ball-mass': 'The mass of the two balls',
              'ball-shape': 'The shape and size of the two balls',
              'release-setup': 'The release height, release time, and initial speed',
              'arrival-time': 'The time each ball reaches the bottom',
            },
            targets: CHANGE_HOLD_MEASURE,
          },
        },
      },
      story: {
        title: 'The Case of the Canceled Paper Drop Race',
        setting:
          'The science room after school. A flat sheet of paper and a crumpled one sit side by side on the same starting platform.',
        characters: CHARACTERS,
        openingLines: {
          'fall.open.1': 'It’s the same paper, but the crumpled one hit the floor first.',
          'fall.open.2': 'Same weight. I’ll write down that the only thing we changed was the shape.',
          'fall.open.3': 'Heh. In a drop race, the heavier racer always has the advantage. Obviously.',
        },
        choiceResponses: {
          'heavier-first':
            'With that explanation, we still can’t say why two sheets with the same weight came out different.',
          together: 'You even included the vacuum condition. Now the comparison is fair.',
          'lighter-first':
            'Switching to a lightness championship? But wait, this time they weighed the same!',
        },
        resolutionLines: {
          'fall.resolve.1':
            'The flat sheet caught air over a wide area, so its fall was held back more than the crumpled one’s.',
          'fall.resolve.2':
            'Under the same conditions, with air ignored, weight alone doesn’t change the finishing order.',
        },
        punchline:
          'Next race: in a vacuum! …Wait, what do you mean I can’t just vacuum up the whole science room?',
      },
      notation: {
        tasks: {
          'fall.arrow': {
            title: ARROW_TITLE,
            prompt:
              'Put in order the steps for drawing the gravitational force on a falling object, starting from the object.',
            guide: 'Start at the center of the object and extend the arrow straight down.',
            solutionSummary: FALL_ARROW_SUMMARY,
            tokens: {
              body: 'Center of the object',
              down: 'Straight down',
              gravity: 'Gravity mg',
            },
            tracePattern: {
              semanticsLabel: FALL_ARROW_SUMMARY + ARROW_TRACE_SUFFIX,
              strokes: arrowStrokes('fall.arrow'),
            },
          },
          'fall.equation': {
            title: EQUATION_TITLE,
            prompt:
              'Express the speed of a freely falling object using time and the acceleration due to gravity.',
            guide: EQUATION_GUIDE,
            solutionSummary:
              'With zero initial speed, v = gt. Here g is the acceleration due to gravity, which does not depend on weight.',
            tokens: { v: 'v', eq: '=', g: 'g', t: 't' },
            tracePattern: {
              semanticsLabel: 'v = g t' + EQUATION_TRACE_SUFFIX,
              strokes: equationStrokes('fall.equation'),
            },
          },
          'fall.symbol': {
            title: SYMBOL_TITLE,
            prompt: 'What is the unit of the acceleration due to gravity, g?',
            representationSemanticsLabel: SYMBOL_SEMANTICS,
            solutionSummary: 'The unit of acceleration is m/s².',
            choices: { ms2: 'm/s²', n: 'N', pa: 'Pa' },
          },
          'fall.graph': {
            title: GRAPH_TITLE,
            prompt:
              'In free fall starting from zero speed, how does the speed change as time increases?',
            representation: ['Speed v', '／', '／', 'Time t →'],
            representationSemanticsLabel:
              'The horizontal axis is time and the vertical axis is speed. A straight line rises to the right from the origin.',
            solutionSummary:
              'Ignoring air resistance, the speed increases in proportion to time.',
            choices: {
              linear: 'Increases in proportion to time',
              constant: 'Stays constant',
              inverse: 'Decreases in inverse proportion to time',
            },
          },
        },
      },
    },

    inertia: {
      practice: {
        foundation: {
          recallPrompt:
            'When the net force on an object is zero, explain what happens to an object at rest and to an object that is moving.',
          reasoningPrompt:
            'Consider the explanation “if something is moving, it needs a force in the direction it is going.” Focusing on changes in speed and direction, add what needs to be reconsidered in it.',
          expectedOutcome:
            'The coin keeps going after the finger leaves it, but on a real table it gradually slows down and stops.',
          expectedReason:
            'After the finger leaves, the pushing force does not stay with the coin pointing forward; because of inertia, the coin tends to keep its velocity. Friction from the table and air resistance produce a net force in the opposite direction, so its speed decreases.',
          cognitiveTask: {
            items: {
              'instant-stop': 'It stops right where it is the moment the finger leaves it.',
              'keep-then-slow':
                'It keeps going even though no forward push remains, and gradually slows down because of friction from the table.',
              'steady-speedup':
                'The finger’s force remains, so it keeps speeding up in the forward direction.',
            },
          },
        },
        conditions: {
          recallPrompt:
            'Explain the motion of a space probe that has shut off its engine in space, focusing on the net force it receives from outside.',
          reasoningPrompt:
            'Explain the condition for an object to keep moving, separating the case of “no forces at all” from the case of “several forces that add up to zero.”',
          transferPrompt:
            'On level ice where friction can be ignored, you slide a puck to the right and then let go. Predict its speed and direction afterward, and connect your prediction to the net force.',
          expectedOutcome:
            'After you let go, the puck keeps moving straight ahead with the same speed and the same rightward direction it had at that moment.',
          expectedReason:
            'If friction can be ignored and the upward push from the surface balances downward gravity, the net force is zero. With zero acceleration, the velocity does not change.',
          checkpoint: {
            lure:
              'When a spaceship shuts off its engine, the forward force disappears, so it stops right there immediately.',
            explanation:
              'If the total outside force is zero, the acceleration is zero, so just shutting off the engine does not change the velocity. The spaceship keeps moving with the speed and direction it had at that moment.',
            options: {
              'keeps-velocity': {
                text: 'If the net outside force is zero, the spaceship keeps moving with the speed and direction it had at that moment.',
              },
              'stops-without-engine': {
                text: 'The instant it loses thrust, its speed becomes zero and it stops where it is.',
                hint: 'Changing the speed to zero also requires acceleration. Look for an outside force that could produce that acceleration.',
              },
              'slows-by-inertia': {
                text: 'Inertia acts opposite to the direction of motion, so it gradually slows down.',
                hint: 'Inertia is not a backward force the object exerts; it is the property of tending to keep its state of motion.',
              },
            },
          },
          cognitiveTask: {
            items: {
              'frictionless-release': 'A puck after you let go, on ice where friction can be ignored',
              'rough-release': 'A puck after you let go, on a rough surface',
              'circular-motion': 'A cart going around a circular track at constant speed',
            },
            targets: {
              'net-zero': 'Net force is zero',
              'net-present': 'Net force is not zero',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Explain how to judge the net force in a motion where the speed stays constant but the direction of travel changes.',
          reasoningPrompt:
            'Connecting it to acceleration, explain why zero net force requires not only the speed but also the direction to stay unchanged.',
          transferPrompt:
            'Consider a cart running around a circular track at constant speed. The speed stays the same, but the direction of travel changes. Predict whether the net force on the cart is zero, and give your reason.',
          expectedOutcome:
            'The net force on the cart is not zero; it points toward the center of the circle.',
          expectedReason:
            'Even if the speed stays constant, a change in the direction of the velocity means there is acceleration. An inward net force is needed to change the direction of the velocity in circular motion.',
          checkpoint: {
            lure:
              'Even in circular motion, if the speed stays constant the acceleration is zero, so the net force on the object is also zero.',
            explanation:
              'Velocity has both a size and a direction. In circular motion, even when the speed stays constant, the direction of the velocity changes, so there is acceleration and the net force changing that direction is not zero.',
            options: {
              'speed-only-zero': {
                text: 'If the speed stays constant, the net force is zero even when the direction changes.',
                hint: 'Velocity includes not only how fast something moves but also its direction. Check whether you are overlooking the change in direction.',
              },
              'direction-change-force': {
                text: 'The direction of travel is changing, so there is acceleration, and the net force changing the direction is not zero.',
              },
              'forward-force-only': {
                text: 'It keeps moving, so the net force always points only in the direction of travel.',
                hint: 'Distinguish a force that increases the speed along the direction of travel from a force that only changes the direction of the velocity.',
              },
            },
          },
          cognitiveTask: {
            items: {
              'course-center': 'Toward the center of the circular track',
              'travel-tangent': 'In the direction of travel at that instant',
              'course-outside': 'Toward the outside of the circular track',
              'force-absent': 'The net force is zero',
            },
          },
        },
      },
      story: {
        title: 'The Runaway Coin and the Missing Pusher',
        setting:
          'A lab table at lunch break. A coin that has just left someone’s finger is sliding toward the edge of the table.',
        characters: CHARACTERS,
        openingLines: {
          'inertia.open.1': 'The finger’s already off it, but the coin is still going.',
          'inertia.open.2':
            'But it slowed down little by little. Let’s keep “still moving” separate from “speed changing.”',
          'inertia.open.3':
            'I hereby submit the theory that an invisible tiny person is pulling it from the front!',
        },
        choiceResponses: {
          'forward-force':
            'If it needed a forward force, it’d be hard to explain the motion right after the finger let go.',
          'no-force-stop':
            'If it stops, its velocity changes. You’d need a force to cause that change.',
          'net-zero-motion':
            'It keeps going with zero net force… so the tiny person doesn’t get the job.',
        },
        resolutionLines: {
          'inertia.resolve.1':
            'When the net force is zero, an object keeps its speed and its direction.',
          'inertia.resolve.2':
            'On the table, friction acts in the opposite direction, so the coin’s speed went down.',
        },
        punchline:
          'Runaway coin case closed: the culprit was friction, not the tiny person. The tiny person is free to go!',
      },
      notation: {
        tasks: {
          'inertia.arrow': {
            title: ARROW_TITLE,
            prompt:
              'For an object with zero net force, put the steps for reading its motion in order.',
            guide:
              'Draw the left and right forces with the same length, and confirm that the net force is 0.',
            solutionSummary: INERTIA_ARROW_SUMMARY,
            tokens: {
              forces: 'Forces in opposite directions',
              sum0: 'Net force 0',
              keep: 'Keeps its velocity',
            },
            tracePattern: {
              semanticsLabel: INERTIA_ARROW_SUMMARY + ARROW_TRACE_SUFFIX,
              strokes: arrowStrokes('inertia.arrow'),
            },
          },
          'inertia.equation': {
            title: EQUATION_TITLE,
            prompt: 'Put the condition for inertia in order as an equation.',
            guide: EQUATION_GUIDE,
            solutionSummary: 'If ΣF = 0, the change in velocity Δv is 0.',
            tokens: { sumf: 'ΣF', eq: '=', zero: '0', arrow: '→', dv: 'Δv = 0' },
            tracePattern: {
              semanticsLabel: 'ΣF = 0 → Δv = 0' + EQUATION_TRACE_SUFFIX,
              strokes: equationStrokes('inertia.equation'),
            },
          },
          'inertia.symbol': {
            title: SYMBOL_TITLE,
            prompt: 'What does ΣF stand for?',
            representationSemanticsLabel: SYMBOL_SEMANTICS,
            solutionSummary: 'ΣF is the vector sum of the forces acting on one object.',
            choices: {
              net: 'The total of the forces acting on an object',
              speed: 'The total of the speeds',
              mass: 'The total of the masses',
            },
          },
          'inertia.graph': {
            title: GRAPH_TITLE,
            prompt: 'What does the velocity–time graph look like for an object with zero net force?',
            representation: ['Velocity v', '────', 'Time t →'],
            representationSemanticsLabel:
              'The horizontal axis is time and the vertical axis is velocity. A horizontal straight line.',
            solutionSummary:
              'With zero net force, the velocity is constant, so the graph is a horizontal line.',
            choices: {
              flat: 'A horizontal line: constant velocity',
              up: 'A straight line rising to the right',
              down: 'A straight line falling to the right',
            },
          },
        },
      },
    },

    friction: {
      practice: {
        foundation: {
          recallPrompt:
            'Explain why a sliding object eventually stops, including the directions of the forces acting on it.',
          reasoningPrompt:
            'Name one thing that “it stops because it uses up the force from the push” cannot explain, and connect it to friction or air resistance.',
          expectedOutcome:
            'With the same coin, it generally stops sooner on the towel than on the table, and travels a shorter distance.',
          expectedReason:
            'Compared at the same initial speed, the friction opposing the sliding is generally larger on the towel, so the net force opposite the motion is larger. Flicking with the same strength does not guarantee the same initial speed, so a fair comparison also keeps the initial speed the same.',
          cognitiveTask: {
            items: {
              'surface-material': 'The surface material: table or towel',
              'same-coin': 'The coin used',
              'launch-speed': 'The speed at which the coin starts moving',
              'stopping-distance': 'The distance until it stops',
            },
            targets: CHANGE_HOLD_MEASURE,
          },
        },
        conditions: {
          recallPrompt:
            'Explain why the distance an object slides before stopping depends on the floor material, even when the same object slides at the same speed.',
          reasoningPrompt:
            'On a level surface where gravity acts downward, what force reduces the object’s horizontal speed? Write your answer with the directions of the forces kept separate.',
          transferPrompt:
            'The same puck slides from the same speed on a rough level surface and on a smooth level surface. Predict the distance until it stops on each, and explain using the difference in net force.',
          expectedOutcome:
            'The puck on the smooth surface travels a longer distance before stopping.',
          expectedReason:
            'Comparing the same puck at the same initial speed, the friction opposite the motion is smaller on the smooth surface, so the puck slows down less.',
          checkpoint: {
            lure:
              'An object sliding across a level table slows down because downward gravity acts opposite to the direction of motion.',
            explanation:
              'On a level surface, gravity points downward and is balanced in the vertical direction by the normal force from the table. Friction and air resistance, acting opposite the sliding direction, make up the horizontal net force and reduce the speed.',
            options: {
              'gravity-slows-horizontal': {
                text: 'Gravity pulls opposite to the object’s direction of motion, so its horizontal speed decreases.',
                hint: 'Separate the horizontal motion from the vertical direction, and check which way the gravity arrow points.',
              },
              'friction-opposes-slip': {
                text: 'Forces such as friction from the table act opposite to the sliding direction and reduce the horizontal speed.',
              },
              'normal-force-backward': {
                text: 'The table’s upward push on the object also bends backward at the same time and stops it.',
                hint: 'Think of the normal force from the level surface and the friction force along the surface as separate forces.',
              },
            },
          },
          cognitiveTask: {
            items: {
              'shorter-distance': 'The distance until it stops gets shorter.',
              'rougher-surface': 'The same puck is moved onto a rougher surface.',
              'larger-friction': 'The friction opposite the direction of motion gets larger.',
              'larger-slowdown': 'The speed decreases faster.',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Explain how the motion of an object that starts at the same speed changes when friction and air resistance are reduced.',
          reasoningPrompt:
            'Using the change in the opposing force, explain why an object traveling farther does not necessarily mean the forward force increased.',
          transferPrompt:
            'Two pucks are moving at the same speed, and only one of them is moved onto a surface with less friction. Assuming air resistance is the same, how do you predict the time and distance until it stops will change?',
          expectedOutcome:
            'The puck on the surface with less friction takes longer and travels farther before stopping.',
          expectedReason:
            'If the initial speed and air resistance are the same, the puck with less friction has a smaller net force opposite its motion, so its speed decreases more gradually.',
          checkpoint: {
            lure:
              'An object slides farther on a smoother surface because the surface keeps pushing it forward strongly.',
            explanation:
              'On a smooth surface, the friction resisting the sliding is small, so the net force opposite the motion is small. The speed therefore decreases slowly, and both the time and the distance until the object stops become longer.',
            options: {
              'smooth-pushes-forward': {
                text: 'The smoother the surface, the larger the forward friction, which carries the object farther.',
                hint: 'After the hand lets go, think about which way the force between the surface and the object that resists sliding points.',
              },
              'no-force-ever': {
                text: 'If it travels far, you can conclude that no force in any direction acts on the object at all.',
                hint: 'Small resistance is not the same as friction and air resistance being exactly zero.',
              },
              'less-opposing-force': {
                text: 'The friction opposite the direction of motion is small, so the speed decreases more slowly and the object travels farther.',
              },
            },
          },
          cognitiveTask: {
            items: {
              'time-only-longer': 'The time gets longer, but the distance stays the same.',
              'both-longer': 'Both the time and the distance until it stops get longer.',
              'both-shorter': 'Both the time and the distance until it stops get shorter.',
            },
          },
        },
      },
      story: {
        title: 'Operation: Rescue the Coin from Towel Swamp',
        setting:
          'A towel covers only half of the lab table, and the same coin races down two different tracks.',
        characters: CHARACTERS,
        openingLines: {
          'friction.open.1': 'On the towel track, the coin stopped almost right away.',
          'friction.open.2': 'To keep it fair, let’s match the starting speed too when we compare.',
          'friction.open.3':
            'The towel gobbled up the coin’s “moving force.” What a hungry towel!',
        },
        choiceResponses: {
          'opposing-forces': 'You’ve made the force opposite the motion the cause.',
          'stored-force': 'The force from a push doesn’t stay inside an object like fuel.',
          'gravity-backward':
            'On a level table, gravity points down. It was never on backward duty!',
        },
        resolutionLines: {
          'friction.resolve.1':
            'The bigger the friction from the towel, the bigger the net force in the opposite direction.',
          'friction.resolve.2':
            'So at the same initial speed, the coin stops in a shorter distance on the towel.',
        },
        punchline:
          'Turns out the hungry one wasn’t the towel. It was me. Is it lunch yet?',
      },
      notation: {
        tasks: {
          'friction.arrow': {
            title: ARROW_TITLE,
            prompt: 'Put in order the steps for drawing the friction force on a sliding object.',
            guide:
              'Draw it along the contact surface, in the direction that resists the object’s motion relative to the surface.',
            solutionSummary: FRICTION_ARROW_SUMMARY,
            tokens: {
              motion: 'Direction of sliding',
              opposite: 'Opposite direction',
              friction: 'Friction force',
            },
            tracePattern: {
              semanticsLabel: FRICTION_ARROW_SUMMARY + ARROW_TRACE_SUFFIX,
              strokes: arrowStrokes('friction.arrow'),
            },
          },
          'friction.equation': {
            title: EQUATION_TITLE,
            prompt: 'Build the equation for the size of the kinetic friction force.',
            guide: EQUATION_GUIDE,
            solutionSummary: 'In the simple model, the kinetic friction force is F₍f₎ = μN.',
            tokens: { f: 'F₍f₎', eq: '=', mu: 'μ', n: 'N' },
            tracePattern: {
              semanticsLabel: 'F₍f₎ = μ N' + EQUATION_TRACE_SUFFIX,
              strokes: equationStrokes('friction.equation'),
            },
          },
          'friction.symbol': {
            title: SYMBOL_TITLE,
            prompt: 'What is the unit of the normal force N?',
            representationSemanticsLabel: SYMBOL_SEMANTICS,
            solutionSummary: 'The unit of force is the N (newton).',
            choices: {
              newton: 'N (newton)',
              pascal: 'Pa (pascal)',
              tesla: 'T (tesla)',
            },
          },
          'friction.graph': {
            title: GRAPH_TITLE,
            prompt:
              'If μ is constant, what happens to the kinetic friction force as the normal force increases?',
            representation: ['Friction force', '／', '／', 'Normal force →'],
            representationSemanticsLabel:
              'The horizontal axis is the normal force and the vertical axis is the friction force. The line rises to the right from the origin.',
            solutionSummary:
              'If μ is constant, the friction force is proportional to the normal force.',
            choices: {
              proportional: 'Increases in proportion',
              fixed: 'Does not change',
              decrease: 'Decreases',
            },
          },
        },
      },
    },

    throwUp: {
      practice: {
        foundation: {
          recallPrompt:
            'For a ball thrown straight up with air resistance ignored, explain the force acting on the ball after it leaves your hand, separately for the way up, the highest point, and the way down.',
          reasoningPrompt:
            'Distinguish the quantity that becomes zero for an instant at the highest point from the quantity that does not, and add the reason the ball then starts to fall.',
          expectedOutcome:
            'At the highest point, the ball’s vertical velocity is zero for an instant, but then it starts falling downward. Even at that instant, the force points downward.',
          expectedReason:
            'Ignoring air resistance, once the ball leaves the hand, downward gravity keeps acting on it on the way up, at the highest point, and on the way down. Even when the velocity is zero for an instant, the force and the acceleration are not zero.',
          cognitiveTask: {
            items: {
              ascending: 'Rising, after it leaves the hand',
              'highest-point': 'The instant it reaches the highest point',
              descending: 'Falling',
            },
            targets: {
              downward: 'Downward gravity',
              upward: 'An upward force',
              'zero-force': 'No force',
            },
          },
        },
        conditions: {
          recallPrompt:
            'Using the direction of a single force, explain why a ball thrown upward slows down on the way up and speeds up on the way down.',
          reasoningPrompt:
            'If you assume an upward force remains after the ball leaves your hand, write what fails to match the observed changes in speed.',
          transferPrompt:
            'Ignoring air resistance, compare the ball just before it reaches the highest point with the ball just after it passes the highest point. Predict whether the direction of the force and of the acceleration changes, and give your reason.',
          expectedOutcome:
            'Both just before and just after the highest point, the force on the ball and its acceleration point downward, and their sizes do not change.',
          expectedReason:
            'Near Earth’s surface with air resistance ignored, the ball out of the hand feels a constant downward gravitational force. What changes at the highest point is the direction of the velocity, not the direction of the force.',
          checkpoint: {
            lure:
              'The ball reverses its direction of motion at the highest point, so the force acting on it also switches from upward to downward.',
            explanation:
              'After the ball leaves the hand, ignoring air resistance, downward gravity always acts on it. What changes from rising to falling is the velocity; the force and the acceleration still point downward, even at the highest point.',
            options: {
              'gravity-down-throughout': {
                text: 'Ignoring air resistance, gravity points downward on the way up, at the highest point, and on the way down, and the direction of the force does not switch.',
              },
              'force-follows-motion': {
                text: 'An object’s direction of motion and the direction of the force on it are always the same, so the force flips at the highest point.',
                hint: 'While the ball is slowing down on the way up, check whether its velocity and acceleration point the same way.',
              },
              'zero-until-falling': {
                text: 'At the highest point the force becomes zero for a moment, and gravity appears only after the ball starts to fall.',
                hint: 'If the force stayed zero, nothing would start changing the velocity to downward from the highest point.',
              },
            },
          },
          cognitiveTask: {
            items: {
              'downward-speed': 'After the highest point, the downward speed increases.',
              'gravity-throughout':
                'The force and the acceleration point downward both before and after the highest point.',
              'upward-speed': 'The upward velocity decreases.',
              'vertical-zero': 'At the highest point, the vertical velocity is zero for an instant.',
            },
          },
        },
        transfer: {
          recallPrompt:
            'For a ball thrown at an angle, explain its velocity and the force on it, each separately, at the instant it reaches its highest point.',
          reasoningPrompt:
            'Splitting the motion into horizontal and vertical components, add why “it is at the highest point, so all of its velocity is zero” is not necessarily true.',
          transferPrompt:
            'Ignoring air resistance, you throw a ball upward at an angle. Predict which way the ball is moving at its highest point, and which way the force on it points.',
          expectedOutcome:
            'Even at the highest point, the ball keeps moving horizontally and feels downward gravity. What becomes zero is the vertical component of the velocity.',
          expectedReason:
            'Ignoring air resistance, there is no horizontal net force, so the horizontal velocity remains. Meanwhile, gravity acts downward even at the highest point, changing the vertical velocity from upward to downward.',
          checkpoint: {
            lure:
              'A ball thrown at an angle has zero speed at its highest point, and the force becomes zero before it starts to fall.',
            explanation:
              'At the highest point of a ball thrown at an angle, what becomes zero is the vertical velocity. The horizontal velocity remains, so the ball keeps moving sideways, and ignoring air resistance the only force is downward gravity.',
            options: {
              'all-zero-at-top': {
                text: 'At the highest point, the horizontal velocity, the vertical velocity, and the force all become zero.',
                hint: 'Think about which component of the velocity becomes zero at the highest point, including the horizontal motion after the ball leaves the hand.',
              },
              'horizontal-velocity-gravity': {
                text: 'Even at the highest point, the horizontal velocity remains and downward gravity acts. What becomes zero is the vertical component of the velocity.',
              },
              'horizontal-force-keeps-motion': {
                text: 'Because the ball keeps moving horizontally, only a horizontal force acts at the highest point.',
                hint: 'With air resistance ignored, reconsider whether a horizontal net force is needed to keep the horizontal motion going.',
              },
            },
          },
          cognitiveTask: {
            items: {
              'horizontal-velocity': 'The horizontal component of the velocity at the highest point',
              'vertical-velocity': 'The vertical component of the velocity at the highest point',
              'gravity-force': 'The force on the ball at the highest point',
            },
            targets: {
              downward: 'Downward',
              horizontal: 'Remains horizontal',
              'zero-value': 'Zero for an instant',
            },
          },
        },
      },
      story: {
        title: 'The Mystery of the Zero-Second Camera at the Top',
        setting:
          'Under the safety net in the gym. The team films a soft ball tossed straight up, in slow motion.',
        characters: CHARACTERS,
        openingLines: {
          'throwUp.open.1':
            'In the frame at the highest point, the ball’s vertical velocity is zero for an instant.',
          'throwUp.open.2':
            'But in the next frame it starts moving down. What changed its speed?',
          'throwUp.open.3':
            'The top is the universe’s rest stop. The force takes a break there too!',
        },
        choiceResponses: {
          'up-then-zero':
            'Aren’t you treating the instant when the velocity is zero as if the force were zero?',
          'gravity-after-top':
            'If gravity suddenly showed up partway through, you’d need a cause for that switch.',
          'gravity-throughout':
            'Only the velocity took a break. Gravity has perfect attendance!',
        },
        resolutionLines: {
          'throwUp.resolve.1':
            'Ignoring air resistance, once it leaves the hand, there’s only downward gravity the whole time.',
          'throwUp.resolve.2':
            'Even at the top there’s a downward acceleration, so the ball moves on into its fall.',
        },
        punchline: 'Dear Gravity: your request for a break has been denied.',
      },
      notation: {
        tasks: {
          'throwUp.arrow': {
            title: ARROW_TITLE,
            prompt:
              'Put in order the steps for drawing gravity on an object just after it is thrown upward.',
            guide: 'Even when the velocity points up, gravity points down from the object.',
            solutionSummary: THROWUP_ARROW_SUMMARY,
            tokens: {
              body: 'Object',
              down: 'Downward',
              mg: 'Gravity mg',
            },
            tracePattern: {
              semanticsLabel: THROWUP_ARROW_SUMMARY + ARROW_TRACE_SUFFIX,
              strokes: arrowStrokes('throwUp.arrow'),
            },
          },
          'throwUp.equation': {
            title: EQUATION_TITLE,
            prompt: 'Build the equation for velocity, taking upward as positive.',
            guide: EQUATION_GUIDE,
            solutionSummary: 'Taking upward as positive, v = v₀ − gt.',
            tokens: { v: 'v', eq: '=', v0: 'v₀', minus: '−', gt: 'gt' },
            tracePattern: {
              semanticsLabel: 'v = v₀ − gt' + EQUATION_TRACE_SUFFIX,
              strokes: equationStrokes('throwUp.equation'),
            },
          },
          'throwUp.symbol': {
            title: SYMBOL_TITLE,
            prompt: 'Which quantity is 0 at the highest point?',
            representationSemanticsLabel: SYMBOL_SEMANTICS,
            solutionSummary:
              'At the highest point the velocity is 0, but gravity and the downward acceleration remain.',
            choices: {
              velocity: 'Instantaneous velocity',
              gravity: 'Gravity',
              accel: 'Acceleration',
            },
          },
          'throwUp.graph': {
            title: GRAPH_TITLE,
            prompt: 'What does the velocity–time graph look like, taking upward as positive?',
            representation: ['Velocity v', '＼', '  ＼', 'Time t →'],
            representationSemanticsLabel:
              'The horizontal axis is time and the vertical axis is velocity. A straight line goes down from positive values, through 0, to negative values.',
            solutionSummary:
              'The velocity decreases along a straight line with slope −g, passing through 0 at the highest point.',
            choices: {
              downline: 'Goes down with a constant slope',
              flat0: 'Stays at 0 after the highest point',
              u: 'Turns into a U shape',
            },
          },
        },
      },
    },
  },
}
