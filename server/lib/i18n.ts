import { type Misconception } from './misconceptions.js'
import {
  type Concept,
  type LocalCheckpoint,
  type Section,
  type Unit,
} from './units.js'

/**
 * 英語での提供。**日本語が原本で、これは差し替え表。**
 *
 * ## なぜ差し替え表なのか
 *
 * 単元・概念・誤概念の**構造は言語に依存しない**。
 * `conceptKey` と誤概念の `id` は観測の単位そのものなので、
 * 言語ごとに別の木を持つと、同じ生徒の記録が言語で分断される。
 *
 * だから構造は `units.ts` / `misconceptions.ts` の1本のままにして、
 * **文字列だけをキーで差し替える**。
 * 差し替えが無いキーは日本語のまま出る（**落とさない**）。
 *
 * ## 誘発の文言は訳ではなく作り直し
 *
 * [Misconception.lure] は固定文で、**訂正もしやすく同意もしやすい**
 * 必要がある（どちらにも倒れないと観測が誘導になる）。
 * 直訳すると英語では不自然に強い断定になるので、
 * 同じ性質を持つ英語の言い回しを別に書いてある。
 */

export type Lang = 'ja' | 'en'

export const DEFAULT_LANG: Lang = 'ja'

/** 知らない値は日本語に倒す。**英語に倒さない**（原本が日本語） */
export function parseLang(v: unknown): Lang {
  return v === 'en' ? 'en' : 'ja'
}

/**
 * 明示が無いときの既定。デモで端末を作り直さずに切り替えるための逃げ道。
 *
 * **本番の既定を env で変えられる**ようにしてあるのは、
 * 配布済みの端末に手を入れずに言語を切り替える必要があるため。
 * 端末が `lang` を明示していればそちらが勝つ。
 */
export function envLang(): Lang {
  return parseLang(process.env.DEMO_LANG)
}

// ── 単元 ────────────────────────────────────────────────────

type UnitText = {
  title: string
  brief: string
  concepts: Record<string, { label: string; intent: string }>
  sections: Record<
    string,
    { title: string; body: string[]; tryIt: string; localCheckpoint: LocalCheckpoint }
  >
}

const EN_UNITS: Record<string, UnitText> = {
  'force-motion': {
    title: 'Force and Motion',
    brief:
      'How fast things fall, why they keep moving, why they stop, and what happens '
      + 'when you throw something upward. The aim is to read off, from the motion itself, '
      + 'whether a force is acting.',
    concepts: {
      fall: {
        label: 'How fast things fall',
        intent:
          'That falling speed does not depend on weight when air resistance is negligible. '
          + '**Complete only if the condition "ignoring air resistance" is stated.**',
      },
      inertia: {
        label: 'Inertia',
        intent:
          'That when the sum of the forces (the net force) is zero, a moving object continues '
          + 'in a straight line with constant speed and direction. '
          + 'Complete if they can say that "moving" is not evidence of '
          + '"a force acting in the direction of motion".',
      },
      friction: {
        label: 'Why things stop',
        intent:
          'That things stop because forces opposing the motion, such as friction and air resistance, '
          + 'act on them, and that they do not stop if every such force is absent. '
          + '**Complete only if they name the cause.**',
      },
      throwUp: {
        label: 'Force on a thrown ball',
        intent:
          'That when air resistance is negligible, only gravity acts on the ball, pointing downward '
          + 'the whole time: going up, at the top, and coming down. '
          + '**Complete only if they state the condition about ignoring air resistance and say '
          + 'the force is not zero at the highest point.**',
      },
    },
    sections: {
      fall: {
        title: 'What decides how fast something falls',
        body: [
          'Imagine dropping a bowling ball and a baseball from the same height at the same moment. '
          + 'It feels as though the heavy one should land first. In fact they land together.',
          'Things fall because the Earth pulls on them. A heavier object is pulled harder — '
          + 'but a heavier object is also harder to get moving. '
          + 'These two effects cancel exactly, so **falling speed does not depend on weight**.',
          'This holds **when air resistance can be ignored**. '
          + 'A flat sheet of paper flutters down slowly; crush the same sheet into a ball and it drops fast. '
          + 'The weight has not changed. What changed is how much the air pushes back on it.',
          'So it is not "heavy, therefore fast" — it is "catches a lot of air, therefore slow". '
          + 'Mix these up and the feather-and-coin experiment stops making sense.',
        ],
        tryIt:
          'Take two identical sheets of paper, crumple one into a ball, and drop them together. '
          + 'They weigh the same. Can you say, in your own words, why they fall differently?',
        localCheckpoint: {
          lure:
            'Even with no air, a heavier ball dropped from the same height lands before a lighter ball.',
          options: [
            {
              id: 'heavier-first',
              text: 'The heavier ball lands first because gravity pulls it harder.',
              hint:
                'The heavier ball is pulled harder, but it is also proportionally harder to accelerate.',
            },
            {
              id: 'together',
              text:
                'They land together because, when air resistance is negligible, '
                + 'falling acceleration does not depend on weight.',
            },
            {
              id: 'lighter-first',
              text: 'The lighter ball lands first because it is easier to move.',
              hint:
                'Along with how easy it is to accelerate, account for how the gravitational force '
                + 'also changes with mass.',
            },
          ],
          correctOptionId: 'together',
          explanation:
            'When air resistance is negligible, gravitational force and resistance to acceleration '
            + 'increase in the same proportion. Falling acceleration is independent of weight, '
            + 'so objects released together from the same height land together.',
        },
      },
      inertia: {
        title: 'Staying in motion takes no force',
        body: [
          'When a train stops suddenly your body pitches forward. Nothing pushed you forward. '
          + 'Your body was moving, and it simply kept moving.',
          'Objects tend to keep doing whatever they are already doing. This is called **inertia**. '
          + 'Something at rest stays at rest; something moving keeps going in a straight line '
          + 'with the same speed and the same direction.',
          'This is where intuition goes wrong. Everything around us stops quickly, '
          + 'so it feels as if "staying in motion needs a force". '
          + 'The truth is the reverse: **when all the forces add up to a net force of zero, '
          + 'neither speed nor direction changes**. That is the natural behaviour.',
          'So "it is moving" is not evidence that "a force is acting in the direction of motion". '
          + 'If the speed or direction **changed**, the net force was not zero; if neither changed, '
          + 'the net force was zero. Individual forces can still be present and balance one another.',
        ],
        tryIt:
          'Flick a coin across a table with your finger. It keeps going after your finger leaves it. '
          + 'During that time, is anything pushing it forward?',
        localCheckpoint: {
          lure:
            'Even on frictionless ice, an object needs a forward force to keep moving at constant speed.',
          options: [
            {
              id: 'forward-force',
              text: 'It needs a forward force. Without one, it stops immediately.',
              hint:
                'A force is the cause of a change in speed or direction, not proof that an object is moving.',
            },
            {
              id: 'no-force-stop',
              text: 'With no force in any direction, it becomes stationary where it is.',
              hint:
                'If its speed vanished the instant the force vanished, ask what caused that change in speed.',
            },
            {
              id: 'net-zero-motion',
              text:
                'With zero net force, it keeps moving with the same speed and direction.',
            },
          ],
          correctOptionId: 'net-zero-motion',
          explanation:
            'Zero net force means zero acceleration. An object at rest stays at rest, while a moving '
            + 'object continues in a straight line with the same speed and direction.',
        },
      },
      friction: {
        title: 'So why does it stop?',
        body: [
          'If inertia is real, the coin you flicked should keep going forever. '
          + 'It actually stops after a few tens of centimetres. Something is working against the motion.',
          '**Friction** acts between the coin and the table. It acts opposite to the direction of travel, '
          + 'so the speed drops and eventually reaches zero. '
          + 'Anything moving through air gets **air resistance** in the same way.',
          'So things do not "just naturally stop if left alone". '
          + 'They stop because **something is stopping them**.',
          'On ice, or on an air-hockey table, where friction is small, things slide much further. '
          + 'If every force opposing the motion — not only friction, but air resistance and any other '
          + 'resistance too — could be reduced to zero, the object would not stop.',
        ],
        tryIt:
          'Flick a coin with the same strength on a bare table and then on a towel. '
          + 'Which stops sooner? What difference is that gap coming from?',
        localCheckpoint: {
          lure:
            'A coin sliding across a table naturally stops when it uses up the “moving force” '
            + 'it received from the push.',
          options: [
            {
              id: 'opposing-forces',
              text:
                'It stops because forces opposing the motion, such as friction and air resistance, act on it.',
            },
            {
              id: 'stored-force',
              text: 'The push is stored inside the coin, and it stops when that supply runs out.',
              hint:
                'After the hand leaves, the pushing force itself is not stored inside the object.',
            },
            {
              id: 'gravity-backward',
              text: 'It stops because gravity acts backward, opposite to its motion.',
              hint:
                'On a level table gravity points downward. Look for a force opposite the horizontal motion.',
            },
          ],
          correctOptionId: 'opposing-forces',
          explanation:
            'Friction and air resistance act opposite the motion and reduce the coin’s speed. '
            + 'If every opposing force were absent, the coin would not naturally stop.',
        },
      },
      throwUp: {
        title: 'The force on a ball thrown straight up',
        body: [
          'Throw a ball straight up: it slows down, hangs for an instant at the top, and comes back down.',
          '**When air resistance is negligible**, throughout all of that '
          + '**only gravity, pointing down**, acts on the ball — '
          + 'on the way up, at the highest point, and on the way down. '
          + 'Once it leaves your hand nothing is pushing it upward.',
          'It rises because the speed your hand gave it is still there (inertia). '
          + 'Gravity keeps acting downward, so that upward speed is steadily eaten away.',
          'At the top the **speed** is zero — but **the force is not zero**. '
          + 'If the force were zero the ball would simply hang there.',
        ],
        tryIt:
          'Assuming air resistance is negligible, picture a ball at the exact top of its flight. '
          + 'Can you state the force acting on it, including its direction?',
        localCheckpoint: {
          lure:
            'Ignoring air resistance, an upward force acts while the ball is rising, '
            + 'and the force becomes zero at the highest point.',
          options: [
            {
              id: 'up-then-zero',
              text: 'The force points upward while rising and is zero at the top.',
              hint:
                'After the ball leaves the hand, check whether anything remains in contact to push it upward.',
            },
            {
              id: 'gravity-after-top',
              text: 'There is no force while rising; downward gravity begins only after the top.',
              hint:
                'If the ball is slowing while rising, it already has downward acceleration at that time.',
            },
            {
              id: 'gravity-throughout',
              text:
                'Gravity points downward throughout the rise, at the highest point, and during the fall.',
            },
          ],
          correctOptionId: 'gravity-throughout',
          explanation:
            'When air resistance is negligible, only downward gravity acts after the ball leaves the hand. '
            + 'At the highest point its instantaneous speed is zero, but the force is not.',
        },
      },
    },
  },

  'force-balance': {
    title: 'Balanced Forces, Action and Reaction',
    brief:
      'What happens between two objects that push on each other, and what it means for '
      + 'forces to balance. The aim is to tell balance and action-reaction apart.',
    concepts: {
      actionReaction: {
        label: 'Action and reaction',
        intent:
          'That action and reaction are always equal in size and opposite in direction. '
          + 'The two forces act on **different objects**, so unlike balanced forces they do not '
          + 'cancel on one object. '
          + '**Complete only if they say it does not depend on weight or strength.**',
      },
      balance: {
        label: 'Balance and motion',
        intent:
          'That balanced forces are individual forces acting on the same object whose net force is zero, '
          + 'and that they still allow motion in a straight line at constant speed. '
          + '**Complete only if they say balanced does not mean stationary.**',
      },
    },
    sections: {
      actionReaction: {
        title: 'Push, and you get pushed back just as hard',
        body: [
          'Push a wall with your hand and your hand hurts. '
          + 'You are the one pushing — yet you are being pushed back.',
          'Whenever you push something, it pushes back with **the same size of force in the opposite direction**. '
          + 'This is **action and reaction**. One side never pushes alone. '
          + 'The two forces act on **different objects**: the hand pushes on the wall, '
          + 'and the wall pushes on the hand.',
          'It is hardest to accept when the two objects differ in size. '
          + 'If a truck hits a bicycle it looks as though the truck must exert the bigger force. '
          + 'In fact **both experience forces of the same size**.',
          'Then why does the bicycle get thrown? Not because the force is bigger, but because '
          + '**the lighter object moves more for the same force**. '
          + '"How big the force is" and "how much it moves" are two different questions.',
        ],
        tryIt:
          'Press a wall gently, then hard, and compare what your hand feels. '
          + 'How does the force you give relate to the force that comes back? '
          + 'Which object does each force act on?',
        localCheckpoint: {
          lure:
            'When a truck collides with a bicycle, the heavy truck exerts a larger force on the bicycle.',
          options: [
            {
              id: 'truck-bigger',
              text: 'The truck exerts the larger force because the heavier object is stronger.',
              hint:
                'Treat the two forces during the collision as one pair produced simultaneously '
                + 'by the same interaction.',
            },
            {
              id: 'equal-pair',
              text:
                'They exert equal-size forces in opposite directions, acting on different objects.',
            },
            {
              id: 'bicycle-bigger',
              text:
                'The bicycle exerts the larger force because the bicycle suffers more damage.',
              hint:
                'The amount of damage or motion is not the same quantity as the force exerted on the other object.',
            },
          ],
          correctOptionId: 'equal-pair',
          explanation:
            'Action and reaction forces are equal in size and opposite in direction regardless of mass. '
            + 'They act on different objects. The bicycle changes motion more because the same force '
            + 'acts on a smaller mass.',
        },
      },
      balance: {
        title: 'Balanced does not mean stopped',
        body: [
          'A book on a desk does not move. Gravity acts downward on the book, while the desk '
          + 'pushes upward on it. Both individual forces still exist; because they are equal and '
          + 'opposite, the **net force on the book is zero**.',
          'The catch is that **balanced forces can also mean moving**. '
          + 'Think of a car travelling straight at constant speed. The engine turns the tyres, '
          + 'the tyres push backward on the road, and **the road pushes forward on the tyres**. '
          + 'When that forward force balances the total backward forces, such as air resistance '
          + 'and rolling resistance, the car keeps the same speed and direction.',
          'When forces balance, an object either stays still **or** keeps moving straight at constant speed. '
          + 'What they share is that **neither speed nor direction changes**. '
          + 'Being stopped is not a requirement.',
          'For balance, add up all the forces acting on the same one object: their sum is zero. '
          + '**The individual forces have not disappeared.** In contrast, an action-reaction pair '
          + 'acts on two different objects, so it is not a pair of balanced forces on one object.',
        ],
        tryIt:
          'A lift is rising at a steady speed. Gravity and the force from the floor still act '
          + 'individually on the person inside. What is their net force? '
          + 'Explain how that fits with the person still moving.',
        localCheckpoint: {
          lure:
            'If a car is travelling straight at constant speed, the forward force must be larger '
            + 'than the backward resistance.',
          options: [
            {
              id: 'balanced-moving',
              text:
                'The forward and backward forces balance. A car can keep moving at constant speed '
                + 'with zero net force.',
            },
            {
              id: 'forward-bigger',
              text: 'As long as it is moving, the forward force must be larger.',
              hint:
                'If the forward force were larger, the speed would increase instead of staying constant.',
            },
            {
              id: 'no-forces',
              text: 'Constant speed means that no individual forces act on the car.',
              hint:
                'Zero net force and the absence of every individual force are different statements.',
            },
          ],
          correctOptionId: 'balanced-moving',
          explanation:
            'Constant speed and direction mean zero acceleration, so the net force on the car is zero. '
            + 'The forward force and backward resistances still exist individually, but their totals balance.',
        },
      },
    },
  },

  'pressure-buoyancy': {
    title: 'Pressure and Buoyancy',
    brief:
      'The same force acts differently depending on the area it acts over, and things in water '
      + 'feel an upward push. The aim is to think of force "per unit area" and "per volume displaced".',
    concepts: {
      pressure: {
        label: 'Pressure and area',
        intent:
          'That pressure = force / area. '
          + '**Complete only if they say smaller area means greater pressure.**',
      },
      buoyancy: {
        label: 'How big the buoyant force is',
        intent:
          'That buoyancy equals the weight of the fluid displaced. '
          + 'In the same fluid, a fully submerged object of fixed volume gets the same buoyant force '
          + 'at every depth. **Complete only if they say it is set by the fluid density and displaced '
          + 'volume, not the object’s weight.**',
      },
    },
    sections: {
      pressure: {
        title: 'Same force, different area, different effect',
        body: [
          'On a drawing pin, the head touching your finger is broad and the point touching the board is sharp. '
          + 'Even when the same size of force is transmitted, the broad head does not dig into your finger, '
          + 'while the point, with its much smaller area, sinks into the board.',
          'Force pressing perpendicular to a surface, divided by the area of that surface, is **pressure**. '
          + '**Pressure = force / area.** For the same force, a smaller area means greater pressure.',
          'You sink into snow when walking but not on skis, for the same reason. '
          + 'Your weight has not changed. Spreading the contact area lowered the pressure.',
          'Thinking only in terms of "a strong force or a weak force" cannot explain this. '
          + 'You have to look at **what area the force is spread over**.',
        ],
        tryIt:
          'Press the broad face and a narrow edge of the same eraser with roughly the same force '
          + 'into a sponge or soft modelling clay. The dents differ. '
          + 'Can you explain why using the words force and area?',
        localCheckpoint: {
          lure:
            'If the pushing force is the same, pressure is the same on a wide face and a narrow face.',
          options: [
            {
              id: 'same-pressure',
              text: 'The pressure is the same because only the pushing force matters.',
              hint: 'Pressure is not force alone; it is force per unit area.',
            },
            {
              id: 'wide-higher',
              text: 'The wide face has greater pressure because the force spreads farther.',
              hint:
                'If the same force is spread across a larger area, consider what happens to the force per unit area.',
            },
            {
              id: 'narrow-higher',
              text:
                'The narrow face has greater pressure because pressure is force divided by area.',
            },
          ],
          correctOptionId: 'narrow-higher',
          explanation:
            'Pressure is the perpendicular force divided by area. With the same pushing force, '
            + 'a smaller area gives greater pressure.',
        },
      },
      buoyancy: {
        title: 'What sets the buoyant force',
        body: [
          'You feel lighter in water because things in water get pushed upward. '
          + 'That upward push is **buoyancy**.',
          'The size of the buoyant force equals **the weight of the water the object pushes out of the way**. '
          + 'It is set by the fluid density and **the volume that is under the fluid**. '
          + 'In the same fluid, if the object is fully submerged and its volume stays fixed, '
          + 'moving it deeper displaces the same amount of fluid, so the buoyant force does not change. '
          + 'This does not apply while part of the object is above the surface or when its volume changes.',
          'Take a lump of clay. Rolled into a ball it sinks; spread into a boat shape it floats. '
          + 'The weight is identical. Changing the shape increased the water displaced, '
          + 'and so increased the buoyant force.',
          'Whether something floats comes down to which is larger, buoyancy or gravity. '
          + 'If you believe "heavier objects get more buoyancy", you can never explain a steel ship.',
        ],
        tryIt:
          'Roll a piece of aluminium foil into a ball and put it in water. '
          + 'Then shape the same amount of foil into a boat and float it. '
          + 'Same weight, different result — why?',
        localCheckpoint: {
          lure:
            'Put two fixed-shape objects of equal volume fully under the same fluid: '
            + 'the heavier object receives the larger buoyant force.',
          options: [
            {
              id: 'heavier-more',
              text:
                'The heavier object receives more buoyancy because it pushes down on the fluid harder.',
              hint:
                'Buoyancy is set by the weight of displaced fluid, not by the object’s own weight.',
            },
            {
              id: 'same-displacement',
              text:
                'The buoyant forces are equal because the fluid density and submerged volumes are equal.',
            },
            {
              id: 'lighter-more',
              text:
                'The lighter object receives more buoyancy because lighter things float more easily.',
              hint:
                'Whether it floats compares buoyancy with gravity. Separate that from the size '
                + 'of the buoyant force itself.',
            },
          ],
          correctOptionId: 'same-displacement',
          explanation:
            'Buoyancy equals the weight of displaced fluid. Fully submerged, fixed-volume objects '
            + 'of equal volume in the same fluid receive equal buoyant forces regardless of their own weight.',
        },
      },
    },
  },

  'current-magnetism': {
    title: 'Electric Current and Magnetic Fields',
    brief:
      'Current creates a magnetic field, current in a magnetic field experiences a force, '
      + 'and changing magnetic flux through a coil can produce current. Change one direction or motion at a time '
      + 'to connect how motors and generators work.',
    concepts: {
      currentMagneticField: {
        label: 'The magnetic field made by current',
        intent:
          'That current in a wire or coil creates a magnetic field around it, and magnetic field lines '
          + 'are a model of field direction rather than physical threads. Reversing the current reverses '
          + 'the field direction, and with other conditions fixed a larger current makes a stronger field.',
      },
      magneticForce: {
        label: 'Force on a current in a magnetic field',
        intent:
          'That a current in a magnetic field experiences a force whose direction depends on both '
          + 'the current and field directions. Reversing either one reverses the force; reversing both '
          + 'restores its original direction. For a straight wire parallel to the field, this magnetic '
          + 'force is zero.',
      },
      electromagneticInduction: {
        label: 'Electromagnetic induction and generation',
        intent:
          'That changing the magnetic flux through a coil induces a voltage and, in a closed circuit, '
          + 'a current. A stationary magnet and coil do not sustain a current when the flux is unchanged; '
          + 'reversing the motion or pole reverses the current. Direct current keeps one direction, '
          + 'while alternating current changes direction periodically.',
      },
    },
    sections: {
      currentMagneticField: {
        title: 'Current creates a field outside the wire too',
        body: [
          'Place a wire near a compass and pass current through it: the needle deflects. '
          + 'A needle outside the wire moves because **the current creates a magnetic field in the '
          + 'space around the wire**. When the current stops, the field from that current disappears, '
          + 'although fields from Earth and other sources remain.',
          '**Magnetic field lines** connect the field direction from place to place. They are a model '
          + 'for reading the field, not physical strings in space. The tangent to a line shows the field '
          + 'direction there, and drawing lines closer together represents a stronger field.',
          'Around a straight wire, the field follows concentric circles around the wire. Bend the wire '
          + 'into a coil and the fields from its parts combine into a bar-magnet-like field that continues '
          + 'both inside and outside the coil. '
          + '**Reversing the current reverses the magnetic field**, so the north and south poles of the '
          + 'coil exchange places.',
          'For coils of the same shape in the same position, increasing the current strengthens the field. '
          + 'At the same current, adding turns can also strengthen the field inside a coil. If shape, turn '
          + 'count, core material, and current all change together, you cannot isolate the effect of current.',
        ],
        tryIt:
          'Using a school low-voltage circuit, place a north-south section of insulated wire over a compass. '
          + 'Close the switch only briefly and observe the deflection, then reverse only the battery and compare. '
          + 'Always use a battery holder plus a resistor or small lamp; never connect the battery terminals '
          + 'directly, never use a household outlet, and follow the teacher’s instructions.',
        localCheckpoint: {
          lure:
            'The magnetic field made by current exists only inside a coil; there is no field outside it.',
          options: [
            {
              id: 'inside-only',
              text: 'The field exists only inside the coil and is always zero outside it.',
              hint:
                'Compare the whole pattern with a bar magnet, whose field also returns outside from '
                + 'north to south.',
            },
            {
              id: 'permanent-wire',
              text:
                'After current flows once, the wire remains a permanent magnet and keeps the same field.',
              hint:
                'Separate the field made by the current from fields already present from Earth or nearby magnets.',
            },
            {
              id: 'around-current',
              text:
                'Current creates a field around a wire or coil, and reversing the current reverses the field.',
            },
          ],
          correctOptionId: 'around-current',
          explanation:
            'A current creates a magnetic field around its wire. In a coil, the fields from each part combine '
            + 'into a bar-magnet-like field that continues outside as well as inside. Reversing the current '
            + 'reverses the field made by that current.',
        },
      },
      magneticForce: {
        title: 'Reverse one direction, and the force reverses',
        body: [
          'Put a wire in the field from a magnet and pass current through it: the wire experiences a force. '
          + 'This force comes from the interaction between field and current. With no current or no external '
          + 'magnetic field, this **force on a current in a magnetic field** is absent.',
          'For a straight wire, the force is perpendicular to both the current direction and field direction. '
          + '**Reverse either the current or the field alone, and the force reverses.** Reverse both and the '
          + 'two reversals restore the original force direction.',
          'The size of the force also depends on the angle between current and field. It is greatest when a '
          + 'straight wire crosses the field at right angles, and zero when they are parallel or antiparallel. '
          + 'Being somewhere in a magnetic field is not enough; direction is a required condition.',
          'In a coil, opposite wire sections can experience opposite forces that create a turning effect. '
          + 'A motor arranges the field and current, switching current as needed to keep rotation going, and '
          + 'converts electrical energy into motion. It is not simply a wire being attracted to a magnet.',
        ],
        tryIt:
          'Use a school low-voltage motor-effect apparatus, such as an electric swing, with the wire crossing '
          + 'the field at right angles. Record its first motion, then reverse only the current and then only '
          + 'the field, predicting each result. Change one condition at a time; do not build this with a '
          + 'household outlet or exposed wiring, and follow the teacher and equipment instructions.',
        localCheckpoint: {
          lure:
            'In the same magnetic field, reversing the current still gives the wire a force in the same direction.',
          options: [
            {
              id: 'one-reversal',
              text:
                'Reversing only the current reverses the force; reversing both current and field restores '
                + 'the original direction.',
            },
            {
              id: 'magnet-attraction',
              text:
                'The force always points toward the magnet, so current direction makes no difference.',
              hint:
                'This is not simple magnetic attraction: both current direction and field direction set '
                + 'the force direction.',
            },
            {
              id: 'reversal-zero',
              text: 'Reversing the current always cancels the field, making the force zero.',
              hint: 'Reversing current direction is not the same as switching the current off.',
            },
          ],
          correctOptionId: 'one-reversal',
          explanation:
            'The force direction depends on both current and magnetic field. Reversing one reverses the force; '
            + 'reversing both restores it. For a straight wire parallel to the field, this force is zero.',
        },
      },
      electromagneticInduction: {
        title: 'Changing magnetic flux can produce current',
        body: [
          'Move a magnet toward or away from a coil connected to a galvanometer and the needle moves. '
          + '**Magnetic flux** summarizes the field passing through the coil, including field strength, '
          + 'coil area, and orientation. A change in this flux induces a **voltage** and, when the galvanometer '
          + 'completes a closed circuit, an **induced current**. In an open circuit, a voltage can be induced '
          + 'but current cannot flow.',
          'Hold the magnet still inside the coil and the needle returns to zero. The presence of a magnet is '
          + 'not enough: **the magnetic flux through the coil must change**. Moving the coil instead of the '
          + 'magnet has the same effect when their relative motion changes that flux.',
          'Changing from inserting to withdrawing the magnet, or switching from its north pole to its south '
          + 'pole, reverses the induced current. With the same coil and circuit, faster motion or a stronger '
          + 'magnet makes the flux through each turn change faster or by more, increasing the induced voltage. '
          + 'Adding turns makes the voltages induced in the turns add to a larger total voltage. The induced '
          + 'current and galvanometer deflection also depend on total circuit resistance, so resistance must '
          + 'be held constant when currents are compared.',
          'A generator rotates a magnet or coil to change the magnetic flux through the coil and converts '
          + 'supplied mechanical energy into electrical energy. **Direct current** keeps one direction; '
          + '**alternating current** changes '
          + 'direction periodically. A rotating generator often produces AC directly, while a rectifier can '
          + 'provide a one-direction DC output.',
        ],
        tryIt:
          'Using a school coil, galvanometer, and bar magnet with no power supply attached, record the needle '
          + 'direction and size while inserting the north pole, holding it still, and withdrawing it. Then '
          + 'change only the speed. Follow the teacher and equipment instructions, and keep strong magnets '
          + 'away from electronics, magnetic cards, and medical devices.',
        localCheckpoint: {
          lure:
            'If a magnet is held inside a coil, the magnetic field is present, so induced current keeps flowing.',
          options: [
            {
              id: 'field-present',
              text:
                'As long as the magnet is inside the coil, current keeps flowing in the same direction '
                + 'even when nothing moves.',
              hint:
                'Compare the moment the galvanometer deflects with what happens after the magnet is held still.',
            },
            {
              id: 'changing-field',
              text:
                'Changing magnetic flux through the coil induces a voltage and, in a closed circuit, a current. '
                + 'Holding it still does not sustain the current.',
            },
            {
              id: 'coil-only',
              text:
                'Current is produced only when the coil moves; moving the magnet cannot produce it.',
              hint:
                'Look at whether the magnetic flux through the coil changes, not which object moves.',
            },
          ],
          correctOptionId: 'changing-field',
          explanation:
            'What is required is a change in the magnetic flux through the coil, not merely a magnet’s '
            + 'presence. The change induces a voltage, and a closed circuit carries an induced current. '
            + 'When relative motion stops and the flux becomes constant, the induced current does not continue.',
        },
      },
    },
  },
}

// ── 誤概念 ──────────────────────────────────────────────────

type MisconceptionText = { correct: string; misconception: string; lure: string }

const EN_MISCONCEPTIONS: Record<string, MisconceptionText> = {
  M01: {
    correct:
      'When air resistance is negligible, falling speed does not depend on the object’s weight. '
      + 'Dropped together from the same height, they land together.',
    misconception: 'Heavier objects fall faster.',
    lure: 'Wait — so heavier things fall faster, right?',
  },
  M02: {
    correct:
      'With no force acting, a moving object keeps moving at constant velocity (the law of inertia).',
    misconception: 'A moving object has a force acting on it in the direction of motion.',
    lure: 'If it’s moving, that means something’s pushing it forward the whole time, right?',
  },
  M03: {
    correct:
      'Objects stop because forces such as friction and air resistance act on them. '
      + 'With nothing acting, they do not stop.',
    misconception: 'Objects naturally come to rest if left alone; being at rest is their natural state.',
    lure: 'Things just stop on their own if you leave them, don’t they?',
  },
  M04: {
    correct:
      'Action and reaction are always equal in size and opposite in direction, '
      + 'regardless of weight or size.',
    misconception: 'The heavier (stronger) object exerts the bigger force.',
    lure: 'Um, if a truck hits a bicycle, the truck exerts the bigger force — right?',
  },
  M05: {
    correct:
      'When forces balance, an object either stays at rest or moves in a straight line at constant speed. '
      + 'It is not necessarily stationary.',
    misconception: 'An object with balanced forces must be stationary.',
    lure: 'If the forces are balanced, that means it’s not moving, right?',
  },
  M06: {
    correct:
      'Pressure is the perpendicular force divided by the area. '
      + 'For the same force, a smaller area gives greater pressure.',
    misconception: 'The same pushing force gives the same pressure; area is irrelevant.',
    lure: 'If you push with the same force, the pressure is the same whatever the area, right?',
  },
  M07: {
    correct:
      'The buoyant force equals the weight of the fluid displaced; it is set by the submerged volume, '
      + 'not by the object’s own weight.',
    misconception: 'Heavier objects get a bigger buoyant force.',
    lure: 'The heavier something is, the more buoyancy it gets — right?',
  },
  M08: {
    correct:
      'A ball thrown upward has gravity acting downward the whole time: '
      + 'rising, at the top, and falling.',
    misconception:
      'A ball thrown upward has an upward force while rising, and zero force at the highest point.',
    lure: 'While it’s going up, there’s an upward force on it — that’s right, isn’t it?',
  },
  M09: {
    correct:
      'Current in a wire or coil creates a magnetic field around it. Reversing the current reverses '
      + 'the direction of that field.',
    misconception:
      'The effects of current stay inside the wire or coil, so there is no magnetic field outside.',
    lure:
      'The effect of current stays inside the wire, so a compass outside it will not move — right?',
  },
  M10: {
    correct:
      'The force direction on a current in a magnetic field depends on both current and field directions. '
      + 'Reversing either one reverses the force.',
    misconception:
      'A wire in a magnetic field is always pulled toward the magnet in the same direction, regardless '
      + 'of current direction.',
    lure:
      'In a magnetic field, reversing the current still pulls the coil the same way — right?',
  },
  M11: {
    correct:
      'Changing magnetic flux through a coil induces a voltage and, in a closed circuit, a current. '
      + 'Unchanged flux does not sustain current.',
    misconception:
      'A magnet inside a coil makes induced current keep flowing even while the magnet is stationary.',
    lure:
      'As long as the magnet is inside the coil, it keeps producing current even when it is still — right?',
  },
}

// ── 差し替え ────────────────────────────────────────────────

/** 差し替えが無ければ**原本をそのまま返す**（落とさない） */
export function localizeUnit(unit: Unit, lang: Lang): Unit {
  if (lang === 'ja') return unit
  const t = EN_UNITS[unit.id]
  if (!t) return unit

  const concepts: Concept[] = unit.concepts.map((c) => {
    const ct = t.concepts[c.key]
    return ct ? { ...c, label: ct.label, intent: ct.intent } : c
  })
  const sections: Section[] = unit.sections.map((s) => {
    const st = t.sections[s.conceptKey]
    return st
      ? {
          ...s,
          title: st.title,
          body: st.body,
          tryIt: st.tryIt,
          localCheckpoint: st.localCheckpoint,
        }
      : s
  })

  return { ...unit, title: t.title, brief: t.brief, concepts, sections }
}

export function localizeMisconception(m: Misconception, lang: Lang): Misconception {
  if (lang === 'ja') return m
  const t = EN_MISCONCEPTIONS[m.id]
  return t ? { ...m, ...t } : m
}

/**
 * 差し替え表の穴。**テストで落とす。**
 *
 * 訳が欠けると、英語の会話の途中に日本語が1文だけ混ざる。
 * 落ちないので気づけないまま出荷される。
 */
export function missingTranslations(
  units: Unit[],
  misconceptions: Misconception[],
): string[] {
  const problems: string[] = []
  for (const u of units) {
    const t = EN_UNITS[u.id]
    if (!t) {
      problems.push(`単元の英語が無い: ${u.id}`)
      continue
    }
    for (const c of u.concepts) {
      if (!t.concepts[c.key]) problems.push(`概念の英語が無い: ${u.id}/${c.key}`)
    }
    for (const s of u.sections) {
      const translated = t.sections[s.conceptKey]
      if (!translated) {
        problems.push(`教材の英語が無い: ${u.id}/${s.conceptKey}`)
      } else if (!translated.localCheckpoint) {
        problems.push(`端末内checkpointの英語が無い: ${u.id}/${s.conceptKey}`)
      }
    }
  }
  for (const m of misconceptions) {
    if (!EN_MISCONCEPTIONS[m.id]) problems.push(`誤概念の英語が無い: ${m.id}`)
  }
  return problems
}
