import { type Misconception } from './misconceptions.js'
import { type Concept, type Section, type Unit } from './units.js'

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
  sections: Record<string, { title: string; body: string[]; tryIt: string }>
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
          'That an object keeps moving with no force acting on it. '
          + 'Complete if they can say that "moving" is not evidence of "a force acting".',
      },
      friction: {
        label: 'Why things stop',
        intent:
          'That things stop because forces — friction, air resistance — act on them. '
          + '**Complete only if they name the cause.**',
      },
      throwUp: {
        label: 'Force on a thrown ball',
        intent:
          'That gravity acts downward the whole time: going up, at the top, and coming down. '
          + '**Complete only if they say the force is not zero at the highest point.**',
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
      },
      inertia: {
        title: 'Staying in motion takes no force',
        body: [
          'When a train stops suddenly your body pitches forward. Nobody pushed you. '
          + 'Your body was moving, and it simply kept moving.',
          'Objects tend to keep doing whatever they are already doing. This is called **inertia**. '
          + 'Something at rest stays at rest; something moving keeps moving at the same speed.',
          'This is where intuition goes wrong. Everything around us stops quickly, '
          + 'so it feels as if "staying in motion needs a force". '
          + 'The truth is the reverse: **with no force acting, motion continues**. That is the natural behaviour.',
          'So "it is moving" is not evidence that "a force is acting". '
          + 'To tell whether a force acts, look at whether the speed or the direction **changed**.',
        ],
        tryIt:
          'Flick a coin across a table with your finger. It keeps going after your finger leaves it. '
          + 'During that time, is anything pushing it forward?',
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
          + 'Remove friction entirely and they never stop.',
        ],
        tryIt:
          'Flick a coin with the same strength on a bare table and then on a towel. '
          + 'Which stops sooner? What difference is that gap coming from?',
      },
      throwUp: {
        title: 'The force on a ball thrown straight up',
        body: [
          'Throw a ball straight up: it slows down, hangs for an instant at the top, and comes back down.',
          'Throughout all of that, **only gravity, pointing down**, acts on the ball — '
          + 'on the way up, at the highest point, and on the way down. '
          + 'Once it leaves your hand nothing is pushing it upward.',
          'It rises because the speed your hand gave it is still there (inertia). '
          + 'Gravity keeps acting downward, so that upward speed is steadily eaten away.',
          'At the top the **speed** is zero — but **the force is not zero**. '
          + 'If the force were zero the ball would simply hang there.',
        ],
        tryIt:
          'Picture a ball at the exact top of its flight. '
          + 'Can you state the force acting on it, including its direction?',
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
          + '**Complete only if they say it does not depend on weight or strength.**',
      },
      balance: {
        label: 'Balance and motion',
        intent:
          'That balanced forces still allow steady motion. '
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
          + 'This is **action and reaction**. One side never pushes alone.',
          'It is hardest to accept when the two objects differ in size. '
          + 'If a truck hits a bicycle it looks as though the truck must exert the bigger force. '
          + 'In fact **both experience forces of the same size**.',
          'Then why does the bicycle get thrown? Not because the force is bigger, but because '
          + '**the lighter object moves more for the same force**. '
          + '"How big the force is" and "how much it moves" are two different questions.',
        ],
        tryIt:
          'Press a wall gently, then hard, and compare what your hand feels. '
          + 'How does the force you give relate to the force that comes back?',
      },
      balance: {
        title: 'Balanced does not mean stopped',
        body: [
          'A book on a desk does not move: gravity pulls down and the desk pushes up, and they balance. '
          + 'That part is easy.',
          'The catch is that **balanced forces can also mean moving**. '
          + 'Think of a car travelling at constant speed. The engine drives it forward; '
          + 'friction and air resistance pull it back; the two balance. '
          + 'The car does not stop — it keeps going at the same speed.',
          'When forces balance, an object either stays still **or** keeps moving straight at constant speed. '
          + 'What they share is that **the speed does not change**. Being stopped is not a requirement.',
          'This connects back to inertia: balanced forces mean the total force is zero, '
          + 'which is the same situation as no force at all.',
        ],
        tryIt:
          'A lift is rising at a steady speed. Are the forces on the person inside balanced? '
          + 'If "but it is moving" bothers you, work out why.',
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
          + '**Complete only if they say it is set by the submerged volume, not the object’s weight.**',
      },
    },
    sections: {
      pressure: {
        title: 'Same force, different area, different effect',
        body: [
          'A drawing pin does nothing to your thumb but sinks into a board. '
          + 'The side against your thumb is broad; the side against the board is sharp. '
          + 'The force pushing is the same.',
          'Force pressing perpendicular to a surface, divided by the area of that surface, is **pressure**. '
          + '**Pressure = force / area.** For the same force, a smaller area means greater pressure.',
          'You sink into snow when walking but not on skis, for the same reason. '
          + 'Your weight has not changed. Spreading the contact area lowered the pressure.',
          'Thinking only in terms of "a strong force or a weak force" cannot explain this. '
          + 'You have to look at **what area the force is spread over**.',
        ],
        tryIt:
          'Press the sharp end of a pencil, then the flat end, into your palm with the same strength. '
          + 'Can you explain the difference using the words force and area?',
      },
      buoyancy: {
        title: 'What sets the buoyant force',
        body: [
          'You feel lighter in water because things in water get pushed upward. '
          + 'That upward push is **buoyancy**.',
          'The size of the buoyant force equals **the weight of the water the object pushes out of the way**. '
          + 'It does not grow with depth, and it does not grow with the object’s weight. '
          + 'What sets it is **the volume that is under the water**.',
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
    return st ? { ...s, title: st.title, body: st.body, tryIt: st.tryIt } : s
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
      if (!t.sections[s.conceptKey]) {
        problems.push(`教材の英語が無い: ${u.id}/${s.conceptKey}`)
      }
    }
  }
  for (const m of misconceptions) {
    if (!EN_MISCONCEPTIONS[m.id]) problems.push(`誤概念の英語が無い: ${m.id}`)
  }
  return problems
}
