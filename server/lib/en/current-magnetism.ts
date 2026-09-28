import type { NotationTaskText, UnitContentText } from '../i18n-content.js'

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

function arrowTask(
  id: string,
  prompt: string,
  guide: string,
  tokens: Record<string, string>,
  solutionSummary: string,
): NotationTaskText {
  return {
    title: 'Trace the arrow in order of meaning',
    prompt,
    guide,
    solutionSummary,
    tokens,
    tracePattern: {
      semanticsLabel:
        `${solutionSummary} Trace from the start point along the shaft, then the upper arrowhead, `
        + 'then the lower arrowhead.',
      strokes: {
        [`${id}.shaft`]: 'Arrow shaft from the start point',
        [`${id}.head-upper`]: 'Upper arrowhead',
        [`${id}.head-lower`]: 'Lower arrowhead',
      },
    },
  }
}

function equationTask(
  id: string,
  prompt: string,
  tokens: Record<string, string>,
  expression: string,
  solutionSummary: string,
): NotationTaskText {
  return {
    title: 'Build the equation from left to right',
    prompt,
    guide:
      'Say what each quantity means out loud, and place them in order from the left side to the right side.',
    solutionSummary,
    tokens,
    tracePattern: {
      semanticsLabel:
        `${expression}. Trace the reading line first, then the check line linking the two sides.`,
      strokes: {
        [`${id}.reading-line`]: 'Line reading the equation from the left side to the right side',
        [`${id}.meaning-link`]: 'Check line linking the left and right sides',
      },
    },
  }
}

function symbolTask(
  prompt: string,
  choices: Record<string, string>,
  solutionSummary: string,
): NotationTaskText {
  return {
    title: 'Match the unit symbol to its meaning',
    prompt,
    solutionSummary,
    representationSemanticsLabel: 'Match the symbol in each choice with its meaning.',
    choices,
  }
}

function graphTask(
  prompt: string,
  representation: string[],
  representationSemanticsLabel: string,
  choices: Record<string, string>,
  solutionSummary: string,
): NotationTaskText {
  return {
    title: 'Read the graph',
    prompt,
    solutionSummary,
    representation,
    representationSemanticsLabel,
    choices,
  }
}

export const currentMagnetismContent: UnitContentText = {
  unitId: 'current-magnetism',
  concepts: {
    currentMagneticField: {
      practice: {
        foundation: {
          recallPrompt:
            'Explain what forms around a straight wire or coil carrying current, including the condition '
            + 'that changes its direction.',
          reasoningPrompt:
            'Add to your explanation that magnetic field lines are not real threads, and what they are a model of.',
          expectedOutcome:
            'When current flows, the compass needle deflects from its no-current direction, and reversing only '
            + 'the battery makes it deflect to the opposite side. When the current stops, the needle returns to '
            + 'the direction set by the surrounding magnetic field.',
          expectedReason:
            'Current creates a magnetic field around the wire, and reversing the current reverses that field. '
            + 'The comparison uses school low-voltage equipment with a resistor or small lamp, keeping the wire, '
            + 'needle, surrounding field, and other conditions the same.',
          cognitiveTask: {
            items: {
              'reverse-current': 'Reverse only the battery and pass current briefly again.',
              baseline: 'Record the compass needle direction with no current flowing.',
              'compare-deflection':
                'Compare which side of the baseline the needle deflected to, before and after reversing.',
              'first-current':
                'Pass current briefly in the first direction and record the needle deflection.',
            },
          },
        },
        conditions: {
          recallPrompt:
            'Explain how the deflection of a compass placed near a straight wire changes when the current '
            + 'direction is reversed.',
          reasoningPrompt:
            'Add why, even if the compass points north after the current is switched off, you cannot say the '
            + 'magnetic field made by the wire’s current is still there.',
          transferPrompt:
            'A straight wire is placed over a compass in the same position. Predict which way the needle '
            + 'deflects when only the battery is reversed, and connect your prediction to the magnetic field. '
            + 'Assume the experiment uses school low-voltage equipment and follows the teacher’s instructions.',
          expectedOutcome:
            'With the wire and compass kept in place and only the battery reversed, the needle deflects to the '
            + 'opposite side of its no-current baseline.',
          expectedReason:
            'Reversing the battery reverses the current, so the magnetic field made by the wire’s current also '
            + 'reverses. The compass points along the combination of this field and the surrounding field, so '
            + 'its deflection reverses too.',
          checkpoint: {
            lure:
              'Even if the current in a straight wire is reversed, the direction of the magnetic field around '
              + 'the wire does not change.',
            options: {
              'field-reverses-with-current': {
                text:
                  'With other conditions the same, reversing the current reverses the magnetic field that '
                  + 'the current creates.',
              },
              'field-direction-fixed': {
                text:
                  'The field direction is set only by the shape of the wire and has nothing to do with the '
                  + 'current direction.',
                hint:
                  'Compare the compass deflection before and after changing only the battery direction.',
              },
              'field-disappears-when-reversed': {
                text:
                  'Reversing the current always cancels out the original field, so the field becomes zero.',
                hint:
                  'If the first current is stopped before the reversed current flows, check whether two '
                  + 'currents are flowing at the same time.',
              },
            },
            explanation:
              'The direction of the magnetic field made by a current is set by the current direction. If only '
              + 'the current is reversed, with the wire shape and observation position unchanged, the field from '
              + 'that current also reverses, and so does the compass deflection.',
          },
          cognitiveTask: {
            items: {
              'same-deflection': 'It deflects to the same side of the no-current baseline.',
              'fixed-north': 'It does not deflect even with current flowing, and always points north.',
              'opposite-deflection': 'It deflects to the opposite side of the no-current baseline.',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Explain how to make the magnetic field of coils with the same shape stronger, including which '
            + 'conditions to keep the same when comparing.',
          reasoningPrompt:
            'Add why you cannot tell which change caused the effect if the current and the number of turns are '
            + 'changed at the same time, focusing on how many conditions change at once.',
          transferPrompt:
            'Compare coils A and B, which have the same shape and the same number of turns, and increase the '
            + 'current only in B. When you measure the compass deflection at the same position, what difference '
            + 'do you predict?',
          expectedOutcome:
            'With current in the same direction and only B’s current increased, the field made by B is stronger, '
            + 'and within the measurement range the compass at the same position generally deflects more.',
          expectedReason:
            'If the coil shape, number of turns, core, orientation, and measurement position are kept the same, '
            + 'a larger current makes a stronger field. The needle deflection depends on how this field combines '
            + 'with Earth’s and other surrounding fields, so we do not claim it is always proportional to the '
            + 'current.',
          checkpoint: {
            lure:
              'If increasing both the current and the number of turns in coil B makes the field stronger, that '
              + 'proves the effect of increasing the current alone.',
            options: {
              'current-only-proven': {
                text:
                  'If the field became stronger, you can conclude it was the effect of current alone, even '
                  + 'though the number of turns also changed.',
                hint:
                  'When two conditions that could affect the result are changed at once, think about whether '
                  + 'the cause can be narrowed down to one.',
              },
              'control-one-variable': {
                text:
                  'To test the effect of current alone, keep the shape, number of turns, core, and so on the '
                  + 'same, and change only the current.',
              },
              'turns-never-matter': {
                text:
                  'A coil’s magnetic field depends only on the current; the number of turns and the core never '
                  + 'have any effect.',
                hint:
                  'Consider that, at the same current, the fields made by each turn add together.',
              },
            },
            explanation:
              'If the current and the number of turns change at the same time, you cannot separate which one '
              + 'caused the change in the field. To study the effect of current, keep the coil shape, number of '
              + 'turns, core, and measurement position the same, and change only the current.',
          },
          cognitiveTask: {
            items: {
              'current-size': 'Size of the current in the coil',
              'coil-setup': 'Coil shape, number of turns, and core',
              'needle-position': 'Compass position and orientation',
              'needle-deflection': 'Size of the compass deflection',
            },
            targets: CHANGE_HOLD_MEASURE,
          },
        },
      },
      story: {
        title: 'The Compass Overhears the Current',
        setting:
          'A teacher-supervised low-voltage lab bench. A compass sits under a wire that has a resistor in '
          + 'its circuit.',
        characters: CHARACTERS,
        openingLines: {
          'currentMagneticField.open.1':
            'When I switched it on briefly, the needle deflected. When I reversed the battery, it deflected '
            + 'the other way.',
          'currentMagneticField.open.2':
            'We never connected the battery terminals directly, and we didn’t use a household outlet. I '
            + 'recorded the safety conditions too.',
          'currentMagneticField.open.3': 'The needle is eavesdropping on the current’s secrets!',
        },
        choiceResponses: {
          'inside-only':
            'That doesn’t match what we saw: the needle deflected right next to a straight wire.',
          'permanent-wire':
            'After the current stopped, the needle went back to the direction set by the surrounding field.',
          'around-current':
            'Reverse the current, and the field reverses too. The needle was telling the truth!',
        },
        resolutionLines: {
          'currentMagneticField.resolve.1': 'Current creates a magnetic field around the wire.',
          'currentMagneticField.resolve.2':
            'Reversing the current reverses the field direction, so the needle’s deflection flipped too.',
        },
        punchline:
          'And the secret it overheard? “Turn right... no wait, left!” Worst directions ever.',
      },
      notation: {
        tasks: {
          'currentMagneticField.arrow': arrowTask(
            'currentMagneticField.arrow',
            'Put the steps in order for reading the magnetic field direction around a straight current.',
            'Point your right thumb along the current; your curled fingers show the field direction.',
            {
              current: 'Thumb = current',
              curl: 'Curl your fingers',
              field: 'Fingers = field',
            },
            'Use the right-hand rule to match the current direction with the field direction.',
          ),
          'currentMagneticField.equation': equationTask(
            'currentMagneticField.equation',
            'Put the parts in order to show how field strength relates to current and distance.',
            { b: 'B', prop: '∝', i: 'I', divide: '÷', r: 'r' },
            'B ∝ I ÷ r',
            'Around a long straight current, B is proportional to I/r.',
          ),
          'currentMagneticField.symbol': symbolTask(
            'What is the unit of magnetic flux density B?',
            { tesla: 'T (tesla)', ampere: 'A (ampere)', volt: 'V (volt)' },
            'The unit of magnetic flux density is T (tesla).',
          ),
          'currentMagneticField.graph': graphTask(
            'At a fixed distance, what happens to the field strength as the current increases?',
            ['Magnetic field B', '／', '／', 'Current I →'],
            'The horizontal axis is current and the vertical axis is magnetic field. The line rises to the '
            + 'right from the origin.',
            {
              proportional: 'Increases proportionally',
              inverse: 'Decreases',
              fixed: 'Stays constant',
            },
            'At a fixed distance, the field strength is proportional to the current.',
          ),
        },
      },
    },

    magneticForce: {
      practice: {
        foundation: {
          recallPrompt:
            'Explain the force on a straight wire carrying current in a magnetic field, including what happens '
            + 'when the current and field directions are changed.',
          reasoningPrompt:
            'Add the reason the force direction differs between reversing only one of the current or the field '
            + 'and reversing both.',
          expectedOutcome:
            'From the original setup, reversing only the current reverses the direction the wire moves; going '
            + 'back to the original setup and reversing only the field also reverses it. Reversing both the '
            + 'current and the field gives a force in the original direction.',
          expectedReason:
            'The direction of the magnetic force on a straight wire depends on both the current direction and '
            + 'the field direction. Reversing either one flips the force once; reversing both flips it twice, '
            + 'which restores it. The wire must not be parallel to the field.',
          cognitiveTask: {
            items: {
              'reverse-current': 'Reverse only the current from the original setup.',
              'reverse-field': 'Reverse only the magnetic field from the original setup.',
              'reverse-both': 'Reverse both the current and the field from the original setup.',
            },
            targets: {
              'force-flips': 'Force is opposite to the original',
              'force-restores': 'Force is the same as the original',
            },
          },
        },
        conditions: {
          recallPrompt:
            'Explain how to think about the magnetic force when the current in a straight wire is parallel to '
            + 'the magnetic field.',
          reasoningPrompt:
            'Add a direction condition to the explanation “if there is current in a magnetic field, there is '
            + 'always a force of the same size.”',
          transferPrompt:
            'Imagine rotating a straight wire so that the current goes from being at right angles to the field '
            + 'to being parallel to it. Predict the size of the magnetic force.',
          expectedOutcome:
            'As the angle between the current and the field goes from 90 degrees toward 0 degrees, the magnetic '
            + 'force on the wire decreases from its maximum and becomes zero when they are parallel.',
          expectedReason:
            'The size of the force on a straight wire depends on the sine of the angle between the current and '
            + 'the field. With the current, field strength, and other conditions kept the same, it is greatest '
            + 'at right angles and zero when parallel or antiparallel.',
          checkpoint: {
            lure:
              'If current flows in a wire in a magnetic field, the wire gets the maximum force even when the '
              + 'current and field are parallel.',
            options: {
              'parallel-maximum': {
                text:
                  'When they are parallel, the wire is pushed hardest along the field, so the force is at its '
                  + 'maximum.',
                hint:
                  'Distinguish the angle at which the force on a straight wire is greatest from the angle at '
                  + 'which it is zero.',
              },
              'parallel-zero': {
                text:
                  'For a straight wire, the magnetic force is zero when the current and field are parallel or '
                  + 'antiparallel.',
              },
              'parallel-reverses': {
                text:
                  'Making them parallel keeps the force the same size as at right angles and only reverses its '
                  + 'direction.',
                hint:
                  'Reversing a direction is a different operation from changing the angle between two '
                  + 'directions from 90 degrees to 0 degrees.',
              },
            },
            explanation:
              'The magnetic force on a straight wire is greatest when the current and field are at right angles '
              + 'and zero when they are parallel or antiparallel. Simply being in a magnetic field does not '
              + 'determine the size of the force.',
          },
          cognitiveTask: {
            items: {
              'angle-ninety': 'The current and the field cross at 90 degrees.',
              'angle-middle': 'The current and the field cross at an angle between 0 and 90 degrees.',
              'angle-parallel': 'The current and the field are parallel.',
            },
            targets: {
              'force-zero': 'Force is zero',
              'force-maximum': 'Force is at its maximum',
              'force-between': 'Force is between the maximum and zero',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Explain why a coil in a magnetic field can rotate, using the directions of the forces on its '
            + 'opposite wire sections.',
          reasoningPrompt:
            'Add why forces in opposite directions on the two sides of a coil can still create a turning effect, '
            + 'connecting your answer to where the forces act.',
          transferPrompt:
            'A rectangular coil has two opposite sides that cross the magnetic field at right angles, and current '
            + 'flows in opposite directions along these two sides. Predict the forces on the two sides and the '
            + 'motion of the whole coil.',
          expectedOutcome:
            'The two opposite sides, on either side of the rotation axis, receive forces in opposite directions. '
            + 'Unless the coil is at an orientation where their turning effect is zero, that pair of forces turns '
            + 'the coil.',
          expectedReason:
            'The current flows in opposite directions in the two opposite sides, so the forces from the same '
            + 'field are also opposite. Because they act at different positions away from the rotation axis, '
            + 'they create a torque that turns the coil instead of sliding it.',
          checkpoint: {
            lure:
              'In a motor coil, the two opposite sides receive forces in the same direction, and that is what '
              + 'makes it rotate.',
            options: {
              'same-direction-rotation': {
                text:
                  'The two sides are pushed the same way, and the whole coil sliding along counts as rotation.',
                hint:
                  'Compare the motion made by two forces in the same direction with the motion made by two '
                  + 'opposite forces at different positions.',
              },
              'forces-cancel-no-motion': {
                text:
                  'The forces on the two sides are opposite, so no matter where they act, they cancel out '
                  + 'completely and the coil does not rotate.',
                hint:
                  'Look not only at the total force but also at which side of the rotation axis each force '
                  + 'acts on.',
              },
              'opposite-forces-turn-coil': {
                text:
                  'The opposite sides receive opposite forces at different positions, and that pair of forces '
                  + 'creates a turning effect on the coil.',
              },
            },
            explanation:
              'The current flows in opposite directions in the opposite sides of a coil, so the forces from the '
              + 'field are also opposite. This pair of forces, acting at different positions, creates the turning '
              + 'effect on the coil.',
          },
          cognitiveTask: {
            items: {
              'coil-turns': 'The whole coil rotates.',
              'opposite-forces': 'The two opposite sides receive forces in opposite directions.',
              'turning-effect': 'The two forces at different positions create a turning effect.',
            },
          },
        },
      },
      story: {
        title: 'The Trial of the Reversing Electric Swing',
        setting:
          'A teacher-supervised low-voltage electric swing experiment. Only one condition is changed each time.',
        characters: CHARACTERS,
        openingLines: {
          'magneticForce.open.1':
            'When we reversed only the current, the wire moved the opposite way too.',
          'magneticForce.open.2':
            'Reversing only the field flipped it as well. Reversing both brought it back to the original direction.',
          'magneticForce.open.3':
            'Witnesses testify that the swing changed course on a whim.',
        },
        choiceResponses: {
          'one-reversal':
            'One reversal flips the force once, and two reversals bring it back. Exactly what we observed.',
          'magnet-attraction':
            'If it just moved toward the magnet, that can’t explain what happened when we reversed the current.',
          'reversal-zero':
            'It didn’t stop; it moved the opposite way. The video evidence is solid!',
        },
        resolutionLines: {
          'magneticForce.resolve.1':
            'The direction of the magnetic force depends on both the current and the field.',
          'magneticForce.resolve.2':
            'Reversing either one flips the force, and reversing both flips it twice.',
        },
        punchline:
          'Verdict: the swing is not guilty. The only thing acting on a whim was my hypothesis.',
      },
      notation: {
        tasks: {
          'magneticForce.arrow': arrowTask(
            'magneticForce.arrow',
            'Put the steps in order for reading the direction of the force a current receives from a magnetic '
            + 'field.',
            'Check that the field, current, and force directions are all at right angles to one another.',
            {
              field: 'Field B',
              current: 'Current I',
              force: 'Force F',
            },
            'When the field and current are at right angles, the force is at right angles to both.',
          ),
          'magneticForce.equation': equationTask(
            'magneticForce.equation',
            'Build the equation for the size of the magnetic force when the current and field are at right '
            + 'angles.',
            { f: 'F', eq: '=', b: 'B', i: 'I', l: 'L' },
            'F = B I L',
            'When the field and current are at right angles, F = BIL.',
          ),
          'magneticForce.symbol': symbolTask(
            'In the equation F = BIL, what is L?',
            {
              length: 'Length of the wire inside the magnetic field',
              voltage: 'Voltage',
              resistance: 'Resistance',
            },
            'L is the length of the part of the wire inside the magnetic field.',
          ),
          'magneticForce.graph': graphTask(
            'With B and L fixed, what happens to the force as the current increases?',
            ['Force F', '／', '／', 'Current I →'],
            'The horizontal axis is current and the vertical axis is force. The line rises to the right from '
            + 'the origin.',
            {
              proportional: 'Increases proportionally',
              inverse: 'Decreases',
              fixed: 'Stays constant',
            },
            'With B and L fixed, the force is proportional to the current.',
          ),
        },
      },
    },

    electromagneticInduction: {
      practice: {
        foundation: {
          recallPrompt:
            'Using the change in magnetic flux, explain the conditions for an induced voltage in a coil and, '
            + 'in a closed circuit, an induced current.',
          reasoningPrompt:
            'Using relative motion and magnetic flux, add why a magnet simply sitting inside a coil does not keep '
            + 'a current flowing.',
          expectedOutcome:
            'While the north pole is being pushed into the coil, the galvanometer deflects one way; when the '
            + 'magnet stops, it returns to zero; while the magnet is pulled out, it deflects the opposite way. '
            + 'The faster the magnet moves over the same range, the larger the deflection.',
          expectedReason:
            'When the magnetic flux through the coil changes, a voltage is induced, and in a closed circuit '
            + 'through the galvanometer an induced current flows. Inserting and withdrawing change the flux in '
            + 'opposite senses, and stopping means there is no change. In the same circuit, changing the flux '
            + 'faster induces a larger voltage.',
          cognitiveTask: {
            items: {
              'magnet-stops':
                'When the magnet stops, the flux stops changing and the needle returns to zero.',
              'magnet-leaves':
                'When the north pole is pulled out, the needle deflects opposite to when it went in.',
              'magnet-enters':
                'When the north pole is pushed in, the flux changes and the needle deflects one way.',
            },
          },
        },
        conditions: {
          recallPrompt:
            'If the magnetic flux through a coil changes but the circuit is open, explain the induced voltage '
            + 'and the induced current separately.',
          reasoningPrompt:
            'Add what else, besides a change in flux, is needed for an induced current to flow, focusing on the '
            + 'path the current takes.',
          transferPrompt:
            'A bar magnet is moved toward a coil at the same speed in two setups: one is a closed circuit through '
            + 'a galvanometer, and the other is broken partway. What do you predict for the induced voltage and '
            + 'the current in each?',
          expectedOutcome:
            'If the flux changes in the same way, a voltage is induced in both the closed and the open circuit. '
            + 'In the closed circuit an induced current flows and the galvanometer deflects, but in the open '
            + 'circuit no continuous current flows.',
          expectedReason:
            'The condition for an induced voltage is a change in magnetic flux. For current to keep flowing, '
            + 'however, charge needs a closed path to travel all the way around, so the open-circuit case must be '
            + 'treated separately.',
          checkpoint: {
            lure:
              'Even if the coil’s circuit is broken partway, a changing flux makes the same induced current flow '
              + 'as in a closed circuit.',
            options: {
              'open-same-current': {
                text:
                  'If the flux changes, the same current keeps flowing whether or not the circuit is connected.',
                hint:
                  'Separate a voltage being produced from charge being able to flow all the way around the '
                  + 'circuit.',
              },
              'open-no-voltage': {
                text:
                  'If the circuit is open, no induced voltage is produced at all, even when the flux changes.',
                hint:
                  'Check whether the condition for an induced voltage is the same as the condition for an '
                  + 'induced current.',
              },
              'voltage-without-current': {
                text:
                  'A changing flux induces a voltage, but if the circuit is open, no continuous induced current '
                  + 'flows.',
              },
            },
            explanation:
              'A change in magnetic flux induces a voltage. But in an open circuit there is no path for current '
              + 'to travel all the way around, so no induced current flows the way it does in a closed circuit.',
          },
          cognitiveTask: {
            items: {
              'closed-voltage': 'Induced voltage in a closed circuit with changing flux',
              'closed-current': 'Induced current in a closed circuit with changing flux',
              'open-voltage': 'Induced voltage in an open circuit with changing flux',
              'open-current': 'Continuous induced current in an open circuit with changing flux',
            },
            targets: {
              occurs: 'Produced',
              'not-continuous': 'Not produced',
            },
          },
        },
        transfer: {
          recallPrompt:
            'With the same coil and circuit, explain how the induced voltage changes when you change how fast '
            + 'the magnet moves.',
          reasoningPrompt:
            'Add which circuit conditions, besides the flux change, must be kept the same to also compare the '
            + 'size of the induced current.',
          transferPrompt:
            'Using the same magnet, coil, and closed circuit, compare pushing the magnet in slowly with pushing '
            + 'it in quickly. What do you predict for the galvanometer deflection, and what do you keep constant?',
          expectedOutcome:
            'The faster the magnet is pushed in, the larger the induced voltage, and in a closed circuit with the '
            + 'same resistance the galvanometer deflects more.',
          expectedReason:
            'Moving the same magnet over the same range faster makes the flux through the coil change more per '
            + 'unit of time. To compare the current and deflection fairly, keep the coil, the magnet’s orientation '
            + 'and range of motion, and the total circuit resistance the same.',
          checkpoint: {
            lure:
              'If the same magnet goes into the same coil, the induced voltage is the same no matter how fast it '
              + 'moves.',
            options: {
              'faster-change-larger-voltage': {
                text:
                  'Moving it faster makes the flux change faster, so the induced voltage is larger. To compare '
                  + 'currents, also keep the circuit resistance the same.',
              },
              'same-final-position': {
                text:
                  'It ends up in the same position, so the induced voltage is always the same regardless of the '
                  + 'speed along the way.',
                hint:
                  'Look not just at the starting and ending positions but at how much the flux changes per unit '
                  + 'of time.',
              },
              'slower-more-voltage': {
                text:
                  'Moving it slowly lets the field act on the coil for longer, so the induced voltage at each '
                  + 'moment is larger.',
                hint:
                  'Distinguish moving for a longer time from the size of the flux change per unit of time.',
              },
            },
            explanation:
              'The induced voltage depends on how fast the flux changes, so moving the same magnet over the same '
              + 'range faster makes it larger. When comparing the induced current or galvanometer deflection, also '
              + 'keep the total circuit resistance the same.',
          },
          cognitiveTask: {
            items: {
              'magnet-speed': 'Speed of pushing the magnet into the coil',
              'magnet-range': 'Magnet type, orientation, and range of motion',
              'circuit-setup': 'Coil, closed circuit, and total circuit resistance',
              'meter-deflection': 'Size of the galvanometer deflection',
            },
            targets: CHANGE_HOLD_MEASURE,
          },
        },
      },
      story: {
        title: 'The Sleeping Magnet and the Silent Galvanometer',
        setting:
          'A teacher-supervised lab bench. A bar magnet is brought toward a coil and galvanometer with no '
          + 'power supply attached.',
        characters: CHARACTERS,
        openingLines: {
          'electromagneticInduction.open.1':
            'While the magnet was going in, the needle deflected. When it stopped, zero. When it came out, the '
            + 'needle deflected the other way.',
          'electromagneticInduction.open.2':
            'When we moved it faster over the same range, the needle deflected more.',
          'electromagneticInduction.open.3':
            'When the magnet stopped, the galvanometer fell asleep too. Those two must be best friends.',
        },
        choiceResponses: {
          'field-present':
            'If just having a field were enough, the needle would keep deflecting even after the magnet stopped.',
          'changing-field':
            'That makes a changing flux and a closed circuit the conditions.',
          'coil-only':
            'The needle deflected when we moved the magnet, too. It’s not a trick only the coil can do!',
        },
        resolutionLines: {
          'electromagneticInduction.resolve.1':
            'When the magnetic flux through the coil changes, a voltage is induced.',
          'electromagneticInduction.resolve.2':
            'In a closed circuit a current flows, and once the change stops, the current doesn’t keep flowing.',
        },
        punchline:
          'So the galvanometer’s alarm clock is a changing flux. Hold the magnet still, and it hits snooze.',
      },
      notation: {
        tasks: {
          'electromagneticInduction.arrow': arrowTask(
            'electromagneticInduction.arrow',
            'Put the cause-and-effect steps of electromagnetic induction in reading order.',
            'Starting from the change in flux through the circuit, think about the direction and size of the '
            + 'induced voltage.',
            {
              'flux-change': 'Flux changes',
              voltage: 'Induced voltage',
              current: 'Current, if the circuit is closed',
            },
            'A change in magnetic flux induces a voltage, and in a closed circuit a current flows.',
          ),
          'electromagneticInduction.equation': equationTask(
            'electromagneticInduction.equation',
            'Put the parts in order to relate the induced voltage to the change in flux.',
            { e: '|E|', prop: '∝', dphi: '|ΔΦ|', divide: '÷', dt: 'Δt' },
            '|E| ∝ |ΔΦ| ÷ Δt',
            'The size of the induced voltage is proportional to the rate of flux change, |ΔΦ|/Δt.',
          ),
          'electromagneticInduction.symbol': symbolTask(
            'What is the unit of the induced voltage E?',
            { volt: 'V (volt)', tesla: 'T (tesla)', ampere: 'A (ampere)' },
            'The unit of voltage is V (volt).',
          ),
          'electromagneticInduction.graph': graphTask(
            'If the same flux change happens in a shorter time, what happens to the induced voltage?',
            ['Voltage |E|', '＼', '  ＼＿', 'Time of change Δt →'],
            'The horizontal axis is the time the change takes and the vertical axis is the induced voltage. '
            + 'Shorter times give larger values.',
            {
              'larger-fast': 'Larger for shorter times',
              'larger-slow': 'Larger for longer times',
              fixed: 'Constant regardless of time',
            },
            'For the same flux change, the shorter the time it takes, the larger the induced voltage.',
          ),
        },
      },
    },
  },
}
