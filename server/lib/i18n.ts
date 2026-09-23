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
    {
      title: string
      body: string[]
      tryIt: string
      localSpeakingPractice: { targetPhrase: string; acceptedTranscripts: string[] }
      localCheckpoint: LocalCheckpoint
    }
  >
}

/**
 * Stage 1 proof slice translations live together so that later concepts can be
 * added to each curriculum unit without having to edit the legacy physics map.
 * Keys remain the Japanese source catalog's stable unit/concept identifiers.
 */
const EN_STAGE1_PROOF_UNITS: Record<string, UnitText> = {
  'matter-properties': {
    title: 'Properties of Everyday Materials',
    brief:
      'Compare material properties by controlling mass and volume instead of relying only on appearance '
      + 'or size. Begin with density and use evidence to judge whether samples could be the same material.',
    concepts: {
      density: {
        label: 'Density',
        intent:
          'That density is mass per unit volume and, under the same conditions, is basically unchanged '
          + 'for the same material even when its amount or shape changes. Complete only when the learner '
          + 'can explain that mass alone, volume alone, or floating and sinking alone cannot identify a '
          + 'material, and that both mass and volume must be measured and compared.',
      },
    },
    sections: {
      density: {
        title: 'When size is controlled, what does a difference in mass tell us?',
        localSpeakingPractice: {
          targetPhrase: 'Density is mass per unit volume and is independent of sample size',
          acceptedTranscripts: [
            'Density is mass per unit volume and is independent of sample size',
          ],
        },
        body: [
          'Hold a wooden block and a metal block of the same size, and the metal feels heavier. '
          + 'But comparing only the masses of a large wooden block and a small metal block cannot separate '
          + 'a difference in material from a difference in amount. We therefore compare equal volumes.',
          'The mass of 1 cm³ of a material is called its **density**. Density is calculated as mass divided '
          + 'by volume and is often expressed in g/cm³. Under the same conditions, including temperature, '
          + 'cutting a sample of one material in half reduces its mass and volume in the same proportion, '
          + 'so its density is basically unchanged.',
          'Both mass and volume are needed to compare density. For an irregular solid, one method is to '
          + 'measure its mass and, if the material can safely be placed in water, find its volume from the '
          + 'rise in water level. This method cannot be used unchanged for substances that dissolve in or '
          + 'react with water.',
          '“Larger” does not necessarily mean “denser”, and neither does “heavier”. Whether an object floats '
          + 'or sinks results from comparing the object’s overall average density with the liquid’s density '
          + 'and other relevant conditions. Floating or sinking alone cannot identify one particular material.',
        ],
        tryIt:
          'With permission, prepare two identical small containers with secure lids. Put the same volume of '
          + 'water in one and cooking oil in the other, close them firmly, support them in your hands, and '
          + 'compare their masses. Explain what this equal-volume comparison reveals. Do not taste the '
          + 'liquids, and wipe up any spill immediately.',
        localCheckpoint: {
          lure:
            'If a rod made from one material is cut in half, its mass halves, so its density also halves.',
          options: [
            {
              id: 'ratio-stays',
              text:
                'Its mass and volume both halve in the same proportion, so its density does not change.',
            },
            {
              id: 'mass-only-halves',
              text: 'Only its mass halves, so its density also halves.',
              hint: 'When the rod is cut, consider what happens to volume as well as mass.',
            },
            {
              id: 'surface-doubles',
              text: 'The new cut surface makes its density double.',
              hint: 'Check whether surface area or the number of cut faces appears in the density formula.',
            },
          ],
          correctOptionId: 'ratio-stays',
          explanation:
            'Density is mass divided by volume. Cutting one material in half reduces both mass and volume '
            + 'in the same proportion, so under the same conditions, including temperature, its density '
            + 'does not change.',
        },
      },
    },
  },
  'living-body': {
    title: 'Living Bodies',
    brief:
      'Examine plants and animals down to the scale of cells, then organize their shared and differing '
      + 'structures from observable evidence.',
    concepts: {
      cells: {
        label: 'Living Things and Cells',
        intent:
          'That living bodies are made of cells and that cells share basic structures such as a cell '
          + 'membrane and cytoplasm. Complete only when the learner can distinguish plant features such as '
          + 'cell walls and vacuoles, and chloroplasts in photosynthetic cells, without claiming that every '
          + 'plant cell has all of them, using evidence from the image.',
      },
    },
    sections: {
      cells: {
        title: 'The small units shared by plants and animals',
        localSpeakingPractice: {
          targetPhrase: 'Living things are made of cells and plant and animal cells differ',
          acceptedTranscripts: [
            'Living things are made of cells and plant and animal cells differ',
          ],
        },
        body: [
          'Under a microscope, onion epidermis and animal tissue show many small compartments. Each one is '
          + 'a **cell**. A multicellular organism consists of many cells that form tissues and organs and '
          + 'work together.',
          'Plant and animal cells share basic structures, including a **cell membrane** around the cell and '
          + '**cytoplasm** inside it. Appearance depends on observation conditions, so a structure that is '
          + 'not visible in one image cannot simply be declared absent.',
          'Plant cells have a **cell wall** outside the cell membrane, and some have a conspicuous vacuole. '
          + 'Cells that carry out photosynthesis, such as many leaf cells, contain **chloroplasts**. However, '
          + 'some plant cells, including root cells, do not have chloroplasts.',
          'It is unsafe to conclude “square means plant” or “no visible chloroplast means animal” from '
          + 'shape or one structure alone. Check the magnification, staining, and sampled tissue, and combine '
          + 'several features before making a judgment.',
        ],
        tryIt:
          'Place microscope images of plant and animal cells from school materials or a textbook side by '
          + 'side, then make a table of features found in both and features characteristic of one group. '
          + 'Do not collect samples from a human body or use stains at home.',
        localCheckpoint: {
          lure: 'A cell with no visible chloroplast cannot be a plant cell.',
          options: [
            {
              id: 'shape-alone',
              text: 'Correct. Chloroplasts must be visible in every tissue of a plant.',
              hint:
                'Think about tissues such as roots, which receive little light and are not primarily '
                + 'photosynthetic.',
            },
            {
              id: 'multiple-features',
              text:
                'Some plant cells have no chloroplasts. Check several features, such as a cell wall, '
                + 'together with the tissue sampled.',
            },
            {
              id: 'all-animal',
              text: 'Every cell with no visible chloroplast is an animal cell.',
              hint:
                'Reconsider whether one structure not being visible can uniquely separate plant and '
                + 'animal cells.',
            },
          ],
          correctOptionId: 'multiple-features',
          explanation:
            'Chloroplasts occur in photosynthetic plant cells, but cells in roots and some other tissues '
            + 'may not have them. Judge from several features, such as a cell wall, together with the tissue '
            + 'from which the image was taken.',
        },
      },
    },
  },
  'weather-change': {
    title: 'Changes in Weather',
    brief:
      'Use the relationship between water vapor in air and temperature to reason step by step about the '
      + 'formation of dew, fog, and clouds.',
    concepts: {
      humidityClouds: {
        label: 'Humidity and Cloud Formation',
        intent:
          'That cooling lowers the maximum amount of water vapor air can contain, and upon reaching the '
          + 'dew point, excess water vapor condenses. Complete only when the learner can explain that clouds '
          + 'are not water vapor itself but tiny water droplets or ice crystals, and connect their formation '
          + 'with expanding and cooling rising air.',
      },
    },
    sections: {
      humidityClouds: {
        title: 'From invisible water vapor to visible droplets',
        localSpeakingPractice: {
          targetPhrase: 'When air cools to its dew point water vapor condenses into tiny droplets',
          acceptedTranscripts: [
            'When air cools to its dew point water vapor condenses into tiny droplets',
          ],
        },
        body: [
          'Water vapor is a gas and is normally invisible. The maximum amount of water vapor that air can '
          + 'contain depends on temperature and generally becomes smaller as temperature falls. Humidity '
          + 'expresses how much water vapor is actually present relative to the maximum possible at that '
          + 'temperature.',
          'If air is cooled while its amount of water vapor remains nearly constant, its humidity rises. '
          + 'Eventually it reaches the **dew point**, the temperature at which the vapor becomes saturated. '
          + 'With further cooling, excess water vapor changes into tiny liquid droplets. This change is '
          + 'called **condensation**.',
          'When air near the ground cools and droplets remain suspended, fog forms. High in the atmosphere, '
          + 'collections of droplets or ice crystals form clouds. A cloud is not transparent water vapor '
          + 'itself. Its tiny particles scatter light, so the cloud appears white or gray.',
          'As air rises into lower surrounding pressure, it expands and cools. If it then reaches the dew '
          + 'point, condensation begins. However, rising air does not always make a cloud: the outcome also '
          + 'depends on the air’s water-vapor content and temperature.',
        ],
        tryIt:
          'Place two identical dry cups side by side and put cold water in only one. After several minutes, '
          + 'observe the outside surfaces and explain where any droplets came from by comparing the cold cup '
          + 'with the room-temperature cup. Work on a stable table; do not heat or pressurize a sealed container.',
        localCheckpoint: {
          lure: 'Clouds look white because water vapor gas itself is white.',
          options: [
            {
              id: 'white-gas',
              text: 'Water vapor is a white gas, so a large amount becomes visible as a cloud.',
              hint:
                'Distinguish the invisible region immediately by a kettle’s spout from the white region '
                + 'a short distance away.',
            },
            {
              id: 'dust-only',
              text: 'Clouds contain no water; only airborne dust looks white.',
              hint: 'Connect rain and snow with the state of the particles that make up a cloud.',
            },
            {
              id: 'droplets-or-ice',
              text:
                'Tiny water droplets or ice crystals formed by condensation scatter light and become visible.',
            },
          ],
          correctOptionId: 'droplets-or-ice',
          explanation:
            'Water vapor is an invisible gas. A cloud becomes visible because cooling and related processes '
            + 'cause water vapor to condense into tiny water droplets or ice crystals that scatter light.',
        },
      },
    },
  },
  'earth-history': {
    title: 'Earth and Space',
    brief:
      'Use the order of rock layers and relationships in which one feature cuts or displaces another to '
      + 'reconstruct the sequence of events in Earth’s past.',
    concepts: {
      strataRelativeAge: {
        label: 'Rock Strata and Relative Age',
        intent:
          'That where strata have not been substantially overturned, lower layers are older, and an event '
          + 'such as faulting that cuts strata is younger than the layers it cuts. Complete only when the '
          + 'learner can combine fossils and marker beds to infer a supported sequence of events rather than '
          + 'an absolute number of years.',
      },
    },
    sections: {
      strataRelativeAge: {
        title: 'Reading layers as a sequence of events in Earth history',
        localSpeakingPractice: {
          targetPhrase: 'In unoverturned strata lower layers were deposited first and are older',
          acceptedTranscripts: [
            'In unoverturned strata lower layers were deposited first and are older',
          ],
        },
        body: [
          'Sand, mud, volcanic ash, and other deposits can accumulate in sequence and solidify into strata. '
          + 'Where the strata have not later been substantially overturned, an earlier layer lies below and '
          + 'a newer layer is deposited on top. This reveals relative order, not a numerical age in years.',
          'If a fault or an igneous intrusion crosses layers, the cutting event happened after the cut layers '
          + 'formed. Conversely, a layer that covers the fault and is not cut by it was deposited after the '
          + 'fault moved.',
          'To compare strata at separate locations, a distinctive volcanic-ash bed or similar feature can '
          + 'serve as a **marker bed**. Fossils provide another clue to depositional environment and '
          + 'geologic age. Do not identify corresponding layers from color or thickness alone.',
          '“Higher always means younger” is conditional on the layers not having been overturned by folding '
          + 'or faulting. Approaching an outcrop can itself be dangerous, so at home use photographs, column '
          + 'diagrams, or paper models. Do not enter cliffs or construction sites.',
        ],
        tryIt:
          'Stack blue, yellow, and white sheets in that order from bottom to top inside a clear folder, and '
          + 'draw one line across all three. Then place a green sheet on top without extending the line '
          + 'through it, and explain the order of deposition and line drawing. Do not approach outdoor cliffs '
          + 'or construction sites, and do not collect rocks.',
        localCheckpoint: {
          lure:
            'In strata that have not been overturned, upper layers are older because they stayed nearer '
            + 'the surface longer.',
          options: [
            {
              id: 'lower-first',
              text:
                'Lower layers were deposited first and later layers accumulated above them, so lower '
                + 'layers are older.',
            },
            {
              id: 'upper-older',
              text: 'Upper layers are nearer the surface and are found first, so they are older.',
              hint: 'Follow the order in which sediment was deposited from the bottom up, not the order found.',
            },
            {
              id: 'same-age',
              text: 'All strata at one location formed at the same time regardless of their vertical order.',
              hint: 'Ask whether the next deposit could be placed above before the lower layer existed.',
            },
          ],
          correctOptionId: 'lower-first',
          explanation:
            'Where strata have not been overturned, later deposits accumulate on top of earlier ones. '
            + 'Lower layers are therefore older and upper layers younger.',
        },
      },
    },
  },
}

/** The eight concepts appended to the four proof units in `units.ts`. */
const EN_STAGE1_EXPANSION_UNITS: Record<string, UnitText> = {
  'matter-properties': {
    title: 'Properties of Everyday Materials',
    brief:
      ' Use particle models and measurements to explain gases and changes of state under stated conditions.',
    concepts: {
      gasProperties: {
        label: 'Producing and Identifying Gases',
        intent:
          'Complete when the learner can read fixed data showing that gases such as oxygen, carbon dioxide, '
          + 'hydrogen, and ammonia differ in water solubility, density relative to air, and reactions, then '
          + 'choose a collection method and identifying evidence suited to those properties.',
      },
      stateChangeMass: {
        label: 'Changes of State and Mass',
        intent:
          'Complete when the learner can explain that a change of state leaves the particle type and total '
          + 'mass of a closed system unchanged while changing particle spacing and motion, and distinguish '
          + 'this from an apparent mass change in an open system.',
      },
    },
    sections: {
      gasProperties: {
        title: 'Choose how to collect and identify a gas from its properties',
        localSpeakingPractice: {
          targetPhrase: 'Choose a gas collection method from water solubility and density relative to air',
          acceptedTranscripts: [
            'Choose a gas collection method from water solubility and density relative to air',
          ],
        },
        body: [
          'Although gases can be difficult to tell apart by appearance, their water solubility, density '
          + 'relative to air, and particular reactions differ by gas. Combine several pieces of fixed data '
          + 'rather than relying on only one property.',
          'Oxygen and hydrogen are only slightly soluble in water and do not readily react with it, so they '
          + 'can be collected over water with little mixing with air. Do not use collection over water for '
          + 'a highly water-soluble gas; instead use its density difference from air.',
          'Ammonia is extremely soluble in water and less dense than air, so it can be collected by upward '
          + 'displacement of air. Carbon dioxide is denser than air, so it can be collected by downward '
          + 'displacement. Carbon dioxide also dissolves in water, so choose the method according to the '
          + 'purpose and required purity.',
          'Reference data can identify oxygen by its support of combustion, carbon dioxide by turning limewater '
          + 'milky, and ammonia by dissolving in water to give an alkaline solution. Because hydrogen is '
          + 'flammable and ammonia is irritating, never produce or burn gases or smell them at home.',
        ],
        tryIt:
          'Using a school-provided table of oxygen, carbon dioxide, hydrogen, and ammonia, first read water '
          + 'solubility and then density relative to air. Match cards for possible collection methods and '
          + 'identifying evidence. At home, do not produce, heat, or burn gases, and never smell them directly.',
        localCheckpoint: {
          lure:
            'All gases are invisible, so they have the same properties and should all be collected over water.',
          options: [
            {
              id: 'property-based-method',
              text:
                'Check water solubility first; if collection over water is unsuitable, choose an air-displacement method from the gas’s density.',
            },
            {
              id: 'all-water-collection',
              text: 'Collect every gas over water regardless of how soluble it is.',
              hint: 'Consider what happens when a gas such as ammonia, which is extremely soluble, enters water.',
            },
            {
              id: 'appearance-identifies',
              text: 'All colorless gases are the same, so there is no need to compare reactions or density.',
              hint: 'Use the table to compare whether colorless oxygen, carbon dioxide, and hydrogen share all properties.',
            },
          ],
          correctOptionId: 'property-based-method',
          explanation:
            'First check water solubility. If collection over water is unsuitable, use whether the gas is '
            + 'less or more dense than air to choose an air-displacement method.',
        },
      },
      stateChangeMass: {
        title: 'The form changes, but the mass of a closed system does not',
        localSpeakingPractice: {
          targetPhrase: 'During a change of state the total mass of a closed system stays the same',
          acceptedTranscripts: [
            'During a change of state the total mass of a closed system stays the same',
          ],
        },
        body: [
          'A change between solid, liquid, and gas is called a change of state. It does not create a new '
          + 'substance; it changes how particles of the same substance are arranged, spaced, and moving.',
          'If no matter enters or leaves a closed system, the total mass, including the container, is unchanged '
          + 'by a change of state. Even when a liquid becomes an invisible gas, its particles remain inside '
          + 'the closed container.',
          'When liquid evaporates from an open container, the mass remaining on the balance decreases. Mass '
          + 'has not vanished: gaseous matter moved into the surroundings and left the measured system.',
          'Melting and boiling points depend on the substance and on conditions such as pressure. Do not '
          + 'confuse a change of state with decomposition or a reaction that forms a different substance '
          + 'merely from appearance.',
        ],
        tryIt:
          'Read a school-provided record of a liquid becoming a gas in a sealed container. Enter the total '
          + 'container mass before and after and mark where the particles are in a diagram. Do not perform '
          + 'heating, cooling, or sealed-container experiments at home.',
        localCheckpoint: {
          lure: 'When a liquid becomes an invisible gas, that part of its mass disappears.',
          options: [
            {
              id: 'closed-same-mass',
              text: 'In a closed system the gas remains inside, so the total mass including the container is unchanged.',
            },
            {
              id: 'gas-lost',
              text: 'A gas has no mass, so the total mass falls by the amount that changed from liquid to gas.',
              hint: 'Separate whether a gas has mass from whether it left the system being measured.',
            },
            {
              id: 'phase-changes-mass',
              text: 'Solid, liquid, and gas have different particle types, so every change of state changes total mass.',
              hint: 'Check whether the substance stays the same or a different substance forms.',
            },
          ],
          correctOptionId: 'closed-same-mass',
          explanation:
            'No matter leaves a closed system, so a change of state preserves the total number of particles '
            + 'and the total mass.',
        },
      },
    },
  },
  'living-body': {
    title: 'Living Bodies',
    brief:
      ' Follow how plants and animals take in matter, transform it, and use it for life processes.',
    concepts: {
      photosynthesisRespiration: {
        label: 'Photosynthesis and Respiration',
        intent:
          'Complete when the learner can explain, with light, organ, and time conditions, that plants '
          + 'continually respire and also photosynthesize in light, while distinguishing the net exchange '
          + 'of gases from the two processes themselves.',
      },
      digestionAbsorption: {
        label: 'Digestion and Absorption',
        intent:
          'Complete when the learner can explain that digestion breaks large nutrient molecules into small '
          + 'absorbable substances, most of which enter the body through villi in the small intestine, while '
          + 'distinguishing passage through the digestive tract from entry into the body.',
      },
    },
    sections: {
      photosynthesisRespiration: {
        title: 'Plants both make and use organic matter',
        localSpeakingPractice: {
          targetPhrase: 'Plants photosynthesize in light and also respire throughout day and night',
          acceptedTranscripts: [
            'Plants photosynthesize in light and also respire throughout day and night',
          ],
        },
        body: [
          'In photosynthesis, cells with chloroplasts use light energy to make organic matter from carbon '
          + 'dioxide and water, releasing oxygen. Light is required, so photosynthesis does not proceed in '
          + 'dark conditions.',
          'In respiration, cells use organic matter and oxygen to release energy available for life processes, '
          + 'producing carbon dioxide and water. Plant cells are alive, so they respire in both light and darkness.',
          'The net gas change observed around a leaf in light is the difference between photosynthesis and '
          + 'respiration. A net increase in oxygen does not mean respiration stopped. In weak light, the '
          + 'change from respiration may exceed that from photosynthesis.',
          'Roots and other tissues without chloroplasts also respire. When considering the matter balance of '
          + 'a whole plant, control the organ, light intensity, time, temperature, and other conditions.',
        ],
        tryIt:
          'Read school-provided gas-change data for an aquatic plant in light and darkness. Record the '
          + 'presence of photosynthesis, the presence of respiration, and the net oxygen change in separate '
          + 'columns. Do not seal up plants or use chemicals or flames.',
        localCheckpoint: {
          lure: 'In daylight, plants perform only photosynthesis and respire only at night.',
          options: [
            {
              id: 'both-processes',
              text: 'In light, plants both photosynthesize and respire; in darkness they still respire.',
            },
            {
              id: 'only-photosynthesis',
              text: 'In light, plants stop respiration completely and perform only photosynthesis.',
              hint: 'Consider whether plant cells still need energy for life processes while it is light.',
            },
            {
              id: 'respiration-night-only',
              text: 'Plant respiration begins at sunset and stops at sunrise.',
              hint: 'Check whether respiration is a process that directly requires light.',
            },
          ],
          correctOptionId: 'both-processes',
          explanation:
            'Plants respire throughout day and night. In light, photosynthesis also proceeds, and the '
            + 'observed gas change is the difference between the two processes.',
        },
      },
      digestionAbsorption: {
        title: 'How food becomes usable inside the body',
        localSpeakingPractice: {
          targetPhrase: 'Digested nutrients are broken down and mostly absorbed in the small intestine',
          acceptedTranscripts: [
            'Digested nutrients are broken down and mostly absorbed in the small intestine',
          ],
        },
        body: [
          'Chewing is a physical change that increases surface area and helps food mix with digestive fluids. '
          + 'Digestive enzymes break starch, proteins, fats, and other nutrients into smaller substances that '
          + 'can be absorbed.',
          'Each enzyme has particular substrates and suitable conditions. One enzyme does not digest every '
          + 'nutrient; different digestive fluids act in the mouth, stomach, small intestine, and other locations.',
          'Most digested nutrients enter blood capillaries or lymphatic vessels mainly through the villi of '
          + 'the small intestine. Simply passing through the inside of the digestive tract does not yet mean '
          + 'a substance has been absorbed into the body.',
          'The large intestine absorbs water and other substances. The stomach does not absorb every nutrient, '
          + 'and the small intestine does not perform digestion without also absorbing nutrients.',
        ],
        tryIt:
          'Using a textbook diagram of the digestive tract and nutrient cards, draw separate arrows for '
          + 'where starch and other nutrients are broken down and where the resulting substances are absorbed. '
          + 'Do not experiment with food, chemicals, or human samples.',
        localCheckpoint: {
          lure: 'All food is absorbed in the stomach and then digested into smaller pieces in the small intestine.',
          options: [
            {
              id: 'digest-then-absorb',
              text: 'Digestion breaks nutrients into smaller substances, most of which are absorbed mainly through the small intestine.',
            },
            {
              id: 'stomach-absorbs-all',
              text: 'The stomach absorbs every nutrient directly into the blood without breaking it down.',
              hint: 'Separate the process that makes large nutrient molecules absorbable from the main site of absorption.',
            },
            {
              id: 'intestine-only-digests',
              text: 'Only digestion occurs in the small intestine; no nutrient absorption occurs there.',
              hint: 'Check how villi and their capillaries in the small intestine are involved.',
            },
          ],
          correctOptionId: 'digest-then-absorb',
          explanation:
            'Digestive enzymes break nutrients into absorbable substances, most of which enter the body '
            + 'through villi in the small intestine.',
        },
      },
    },
  },
  'weather-change': {
    title: 'Changes in Weather',
    brief:
      ' Read fronts, pressure patterns, and wind as changes over time using weather maps and cross-sections.',
    concepts: {
      fronts: {
        label: 'Fronts and Weather',
        intent:
          'Complete when the learner can treat a front as a boundary between air masses with different '
          + 'properties, distinguish typical warm- and cold-front cross-sections, clouds, and precipitation, '
          + 'and explain that actual weather also varies with water-vapor content, terrain, and other conditions.',
      },
      pressurePatternsWind: {
        label: 'Pressure Patterns and Wind',
        intent:
          'Complete when the learner can explain the basic role of pressure differences in producing wind, '
          + 'distinguish the apparent deflection from Earth’s rotation and the effect of surface friction, '
          + 'and infer wind strength conditionally from isobar spacing.',
      },
    },
    sections: {
      fronts: {
        title: 'How does weather change when an air-mass boundary passes?',
        localSpeakingPractice: {
          targetPhrase: 'A front is a boundary between air masses and can bring clouds and precipitation',
          acceptedTranscripts: [
            'A front is a boundary between air masses and can bring clouds and precipitation',
          ],
        },
        body: [
          'An air mass is a large body of air with similar temperature and humidity. The region near the '
          + 'boundary where air masses with different properties meet is called a front. When less-dense '
          + 'warm air is lifted over denser cold air, clouds are more likely to form.',
          'At a warm front, advancing warm air rises gradually over cold air. Layered clouds and sustained '
          + 'precipitation tend to occur across a broad area ahead of the front, and temperature tends to '
          + 'rise after it passes.',
          'At a cold front, advancing cold air moves underneath warm air and lifts it relatively rapidly. '
          + 'Tall clouds and heavy precipitation can occur in a narrower area, and temperature tends to fall '
          + 'after the front passes.',
          'These are representative tendencies. Water-vapor content, front speed, season, and terrain change '
          + 'the area and intensity of clouds and rain, so do not use the symbol alone to declare local weather.',
        ],
        tryIt:
          'In the classroom, place past weather maps and cloud images published by a meteorological agency '
          + 'side by side. Make a time-series table of temperature and precipitation before, during, and '
          + 'after a front passes. Do not go outside to observe during thunderstorms or severe weather.',
        localCheckpoint: {
          lure: 'At a warm front, heavy warm air dives under cold air and causes sudden cooling.',
          options: [
            {
              id: 'warm-over-cold',
              text: 'At a warm front, warm air rises gradually over cold air, and temperature tends to rise after passage.',
            },
            {
              id: 'cold-over-warm',
              text: 'At a warm front, cold air rides over warm air, and passage always causes sudden cooling.',
              hint: 'Check the density difference and which air mass is advancing at a warm front.',
            },
            {
              id: 'no-boundary',
              text: 'A front forms in the middle of air with uniform properties and is unrelated to an air-mass boundary.',
              hint: 'Recall what boundary a front represents on a weather map.',
            },
          ],
          correctOptionId: 'warm-over-cold',
          explanation:
            'At a warm front, advancing warm air rises gradually over cold air and tends to produce clouds '
            + 'and precipitation across a broad area.',
        },
      },
      pressurePatternsWind: {
        title: 'Reading wind from the spacing of isobars',
        localSpeakingPractice: {
          targetPhrase: 'Pressure differences produce wind which is affected by rotation and friction',
          acceptedTranscripts: [
            'Pressure differences produce wind which is affected by rotation and friction',
          ],
        },
        body: [
          'At the same altitude, a pressure difference produces a force on air from the high-pressure side '
          + 'toward the low-pressure side, creating wind. Closer isobars indicate a larger pressure change '
          + 'over the same distance, so wind generally tends to be stronger.',
          'Large-scale wind is affected not only by pressure differences but also by apparent deflection due '
          + 'to Earth’s rotation. In the Northern Hemisphere this effect deflects motion to the right, and '
          + 'upper-air winds run approximately parallel to isobars.',
          'Near the surface, friction with the ground reduces wind speed and changes the deflection, so wind '
          + 'crosses isobars at an angle toward lower pressure. Terrain and temperature differences between '
          + 'land and sea also affect local winds.',
          'Wind does not necessarily blow “in a straight line from high to low” or in one fixed direction '
          + 'whenever pressure is low. Check the hemisphere, surface versus upper air, and the shape and '
          + 'spacing of the isobars.',
        ],
        tryIt:
          'On a past surface weather map from a meteorological agency, choose one region with widely spaced '
          + 'isobars and one with closely spaced isobars, then compare observed wind speeds at the same time. '
          + 'Do not go outside to observe a typhoon or strong winds; use only published data.',
        localCheckpoint: {
          lure: 'Wind is pushed from low pressure to high pressure, opposite to the pressure difference.',
          options: [
            {
              id: 'high-to-low',
              text: 'The pressure-gradient force points from high toward low pressure, while rotation and friction also alter the observed wind.',
            },
            {
              id: 'coriolis-alone',
              text: 'Earth’s rotation alone creates wind, which blows with the same strength even without a pressure difference.',
              hint: 'Separate the force that starts air moving from the effect that deflects its path.',
            },
            {
              id: 'low-to-high',
              text: 'Air flows from low toward high pressure, and closer isobars mean weaker wind.',
              hint: 'Check the direction of the pressure-gradient force and the meaning of isobar spacing.',
            },
          ],
          correctOptionId: 'high-to-low',
          explanation:
            'The pressure-gradient force points from high toward low pressure, but the wind we observe is '
            + 'also affected by Earth’s rotation and friction.',
        },
      },
    },
  },
  'earth-history': {
    title: 'Earth and Space',
    brief:
      ' Interpret activity inside Earth and the apparent motion of celestial objects using records, models, and time scales.',
    concepts: {
      volcanoEarthquakes: {
        label: 'Volcanoes and Earthquakes',
        intent:
          'Complete when the learner can relate both volcanoes and earthquakes to plate motion while '
          + 'explaining that eruption style depends on magma properties and shaking on conditions such as '
          + 'focus, distance, and ground, without treating the two as the same phenomenon.',
      },
      dailyMotionSeasons: {
        label: 'Daily Motion and Seasons',
        intent:
          'Complete when the learner can explain daily celestial motion by Earth’s rotation and annual '
          + 'changes in constellations, the Sun, and seasons by revolution and axial tilt, without claiming '
          + 'that distance from the Sun alone causes the seasons.',
      },
    },
    sections: {
      volcanoEarthquakes: {
        title: 'Related activity inside Earth, but different evidence',
        localSpeakingPractice: {
          targetPhrase: 'Volcanoes and earthquakes relate to plate motion but are not the same event',
          acceptedTranscripts: [
            'Volcanoes and earthquakes relate to plate motion but are not the same event',
          ],
        },
        body: [
          'An earthquake occurs when underground rock suddenly slips and stored energy travels as seismic '
          + 'waves. The underground point where slipping begins is the focus, and the point directly above '
          + 'it on the surface is the epicenter. Shaking depends not only on distance but also on magnitude '
          + 'and ground conditions.',
          'In a volcanic eruption, underground magma rises and material reaches the surface partly because '
          + 'dissolved gases expand. Differences in magma viscosity, gas content, and other properties '
          + 'produce different eruption styles and volcano shapes.',
          'Volcanoes and earthquakes both tend to be distributed near plate boundaries, but they do not '
          + 'necessarily occur at the same place and time. Read evidence specific to each, including their '
          + 'distributions, earthquake foci, and erupted materials.',
          'Treat disaster safety as part of the topic by checking official hazard maps and evacuation '
          + 'information. Do not visit eruption or earthquake sites, cliffs, or restricted areas to observe them.',
        ],
        tryIt:
          'Overlay past epicenter maps, volcano-distribution maps, and plate-boundary maps published by public '
          + 'agencies. Record shared patterns and nonmatching locations separately. Do not travel to disaster '
          + 'areas or volcanoes; use published materials only.',
        localCheckpoint: {
          lure:
            'Volcanoes and earthquakes have the same mechanism, so they always occur together everywhere '
            + 'and can be explained by exactly the same evidence.',
          options: [
            {
              id: 'evidence-specific',
              text: 'Both relate to plate motion, but eruptions and sudden rock slip are different phenomena requiring their own evidence.',
            },
            {
              id: 'same-everywhere',
              text: 'At every point on a plate boundary, an eruption and an earthquake occur at the same time.',
              hint: 'Separate a distributional tendency from a guaranteed match at every location and time.',
            },
            {
              id: 'one-event',
              text: 'Seismic waves and volcanic ash are the same material and are observed in exactly the same way.',
              hint: 'Check the difference between waves transmitted by an earthquake and matter emitted by an eruption.',
            },
          ],
          correctOptionId: 'evidence-specific',
          explanation:
            'Both relate to activity inside Earth and plate motion, but an earthquake involves sudden rock '
            + 'slip whereas an eruption involves rising magma, so they are different phenomena.',
        },
      },
      dailyMotionSeasons: {
        title: 'Separating motion over one day from change over one year',
        localSpeakingPractice: {
          targetPhrase: 'Rotation explains daily motion and revolution with axial tilt explains seasons',
          acceptedTranscripts: [
            'Rotation explains daily motion and revolution with axial tilt explains seasons',
          ],
        },
        body: [
          'The daily motion in which the Sun and stars appear to circle from east to west is an apparent '
          + 'motion caused by Earth rotating from west to east. It is not caused by the distance to the '
          + 'stars changing greatly within one day.',
          'Earth revolves around the Sun while its rotation axis remains tilted. Over a year, this changes '
          + 'the Sun’s noon altitude and the length of daylight, altering both the intensity and duration '
          + 'of solar energy received at the surface.',
          'Northern Hemisphere summers have a higher Sun and longer days, so the received energy is greater. '
          + 'The main cause of seasons is axial tilt together with revolution, not distance from the Sun. '
          + 'The Southern Hemisphere has the opposite season at the same time.',
          'Distinguish the movement of stars over one night from the annual change in which constellations '
          + 'are visible at the same clock time in different seasons. Do not draw conclusions from a diagram '
          + 'without controlling observation time, direction, and latitude.',
        ],
        tryIt:
          'Use a classroom celestial-sphere simulation to record star positions over one night at one '
          + 'location, then change the month and record constellations at the same clock time. Never look '
          + 'directly at the Sun or observe outdoors alone at night.',
        localCheckpoint: {
          lure:
            'Daily motion occurs because the Sun and stars orbit Earth every day, and seasons depend only '
            + 'on Earth’s distance from the Sun.',
          options: [
            {
              id: 'rotation-revolution',
              text: 'Earth’s rotation explains daily motion, while its revolution with a tilted axis explains seasonal change.',
            },
            {
              id: 'earth-still',
              text: 'Earth is stationary and every celestial object orbits it in about 24 hours.',
              hint: 'Match Earth’s rotation direction with the apparent direction of celestial motion.',
            },
            {
              id: 'sun-distance-only',
              text: 'Seasons depend only on being nearer or farther from the Sun; axial tilt is irrelevant.',
              hint: 'Ask whether that explains opposite seasons in the Northern and Southern Hemispheres.',
            },
          ],
          correctOptionId: 'rotation-revolution',
          explanation:
            'Earth’s rotation produces the apparent daily motion. Seasons occur because axial tilt changes '
            + 'solar conditions as Earth revolves around the Sun.',
        },
      },
    },
  },
}

/** Mirror the concept/section merge in `units.ts` without replacing proof text. */
function mergeStage1UnitTexts(
  proof: Record<string, UnitText>,
  expansion: Record<string, UnitText>,
): Record<string, UnitText> {
  const merged: Record<string, UnitText> = { ...proof }
  for (const [unitId, added] of Object.entries(expansion)) {
    const existing = merged[unitId]
    if (existing == null) throw new Error(`English proof unit is missing: ${unitId}`)
    if (existing.title !== added.title) {
      throw new Error(`English Stage 1 unit title differs: ${unitId}`)
    }
    for (const conceptKey of Object.keys(added.concepts)) {
      if (Object.hasOwn(existing.concepts, conceptKey)) {
        throw new Error(`English Stage 1 concept is duplicated: ${unitId}/${conceptKey}`)
      }
    }
    for (const conceptKey of Object.keys(added.sections)) {
      if (Object.hasOwn(existing.sections, conceptKey)) {
        throw new Error(`English Stage 1 section is duplicated: ${unitId}/${conceptKey}`)
      }
    }
    merged[unitId] = {
      ...existing,
      brief: `${existing.brief}${added.brief}`,
      concepts: { ...existing.concepts, ...added.concepts },
      sections: { ...existing.sections, ...added.sections },
    }
  }
  return merged
}

const EN_STAGE1_UNITS = mergeStage1UnitTexts(
  EN_STAGE1_PROOF_UNITS,
  EN_STAGE1_EXPANSION_UNITS,
)

const EN_UNITS: Record<string, UnitText> = {
  ...EN_STAGE1_UNITS,
  'chemical-change': {
    title: 'Chemical Change, Atoms and Molecules',
    brief:
      'Treat combination, decomposition, oxidation and reduction as rearrangements of atoms, '
      + 'and explain the amounts with the law of conservation of mass.',
    concepts: {
      combinationDecomposition: {
        label: 'Combination and decomposition',
        intent:
          'That decomposition is one substance splitting into two or more different substances, '
          + 'and combination is two or more substances joining into a different substance. '
          + 'Complete only when the learner can judge a change by evidence that the product has '
          + 'different properties, distinguishing it from separating a mixture or a state change.',
      },
      oxidationReduction: {
        label: 'Oxidation and reduction',
        intent:
          'That oxidation is a substance combining with oxygen and reduction is removing oxygen '
          + 'from an oxide — opposite reactions exchanging oxygen. Complete only when the learner '
          + 'can explain that burning, rusting and respiration are oxidation, and that the mass gain '
          + 'of an oxidized substance comes from the oxygen that joined it.',
      },
      massConservation: {
        label: 'Conservation of mass',
        intent:
          'That the total mass of all substances involved is equal before and after a chemical '
          + 'change, explained by atoms being rearranged. Complete only when the learner can also '
          + 'explain the apparent gain or loss in an open system by whether the substances that '
          + 'moved in or out were included in the measurement.',
      },
    },
    sections: {
      combinationDecomposition: {
        title: 'Just mixed together, or a different substance?',
        localSpeakingPractice: {
          targetPhrase: 'Combination joins substances; decomposition splits them',
          acceptedTranscripts: [
            'Combination joins substances; decomposition splits them',
          ],
        },
        body: [
          'Mix iron filings and powdered sulfur well, and each grain is still iron or sulfur — '
          + 'a magnet still picks out the iron grains. But heat the mixture and a reaction runs: '
          + 'the result is iron sulfide, a black substance the magnet ignores. '
          + 'Mixing and combining are not the same thing.',
          'When two or more substances join into a different substance, the change is called '
          + '**combination**; when one substance splits into two or more different substances, '
          + 'it is **decomposition**. Heating sodium hydrogen carbonate into sodium carbonate, '
          + 'water and carbon dioxide is a decomposition. Both are chemical changes: the kinds '
          + 'of substance present before and after differ.',
          'Ice melting or salt dissolving in water does not change the kind of substance, so '
          + 'those are not chemical changes. To tell one apart, check whether a substance with '
          + 'different properties was produced. Color, smell, bubbles and temperature shifts are '
          + 'clues, but in the end the properties of the product decide.',
          'In the atom and molecule model, a chemical change is a change in how atoms are '
          + '**combined**. The atoms themselves are neither destroyed nor created. That is why '
          + 'the products have properties the reactants did not.',
        ],
        tryIt:
          'Using the distributed lab record "iron filings and sulfur mixture, before and after '
          + 'heating", write down two ways the response to a magnet and the appearance differ '
          + 'before and after, and explain the evidence that a different substance was produced. '
          + 'Do not heat anything or mix chemicals at home.',
        localCheckpoint: {
          lure: 'Once iron filings and sulfur powder are well mixed, the iron is already combined with the sulfur.',
          options: [
            {
              id: 'mixture-not-compound',
              text: 'Mixing alone leaves the grains as iron and sulfur; only after a reaction such as heating produces a differently-behaving substance has combination occurred.',
            },
            {
              id: 'mixed-means-combined',
              text: 'A well-mixed powder has its grains in contact, so combination has already happened.',
              hint: 'What happens to the iron grains when a magnet is brought near the unheated mixture?',
            },
            {
              id: 'heating-restores',
              text: 'The changed color from heating returns when it cools, so the kind of substance stays the same.',
              hint: 'Does the heated substance still respond to a magnet, or is the change more than appearance?',
            },
          ],
          correctOptionId: 'mixture-not-compound',
          explanation:
            'In a mixture the iron and sulfur grains keep their own properties. Once heating causes '
            + 'a chemical change and iron sulfide — a substance the magnet ignores — is produced, '
            + 'combination has occurred.',
        },
      },
      oxidationReduction: {
        title: 'The surprising link between burning and rusting',
        localSpeakingPractice: {
          targetPhrase: 'Oxidation is combining with oxygen and reduction is removing oxygen',
          acceptedTranscripts: [
            'Oxidation is combining with oxygen and reduction is removing oxygen',
          ],
        },
        body: [
          'Heated copper turns black on its surface; iron left in air develops red rust. '
          + 'Both are chemical changes in which a substance combines with oxygen — **oxidation**. '
          + 'Oxidation that runs violently with flame is combustion; oxidation that creeps along '
          + 'is rusting. Respiration is a form of oxidation too.',
          'The substance made by oxidation is called an **oxide**: copper oxide, iron oxide, '
          + 'magnesium oxide. An oxide has properties the original substance did not, and the '
          + 'mass of the oxidized substance grows by the amount of oxygen that joined it.',
          'The chemical change that removes oxygen from an oxide is called **reduction**. '
          + 'Heat powdered copper oxide mixed with carbon and the oxygen moves to the carbon, '
          + 'leaving shiny red copper and carbon dioxide. Oxidation and reduction are opposite '
          + 'reactions passing oxygen back and forth.',
          'Rust looks like dirt stuck on the surface, but the iron itself has combined with '
          + 'oxygen and become a different substance. And although burned things look lighter, '
          + 'the picture changes once the joined oxygen and the escaped gases are counted too.',
        ],
        tryIt:
          'Safely observe a place near home where iron is rusty (a gate, a fence, a bicycle '
          + 'frame) and compare the color and surface of rusted and non-rusted parts in writing. '
          + 'Give one observation showing that rust is a substance with different properties '
          + 'from iron. Wash your hands after touching rust, and never touch sharp or '
          + 'deteriorating parts.',
        localCheckpoint: {
          lure: 'Rust is just red dirt stuck on the surface — the iron has not combined with oxygen.',
          options: [
            {
              id: 'surface-dirt',
              text: 'Rust is dirt attached from outside, so scraping it off leaves the iron completely unchanged.',
              hint: 'Does the metal keep its original mass and hardness once the rust is removed?',
            },
            {
              id: 'rust-is-oxide',
              text: 'Rust is an oxide formed when iron combines with oxygen — a different substance from the original iron.',
            },
            {
              id: 'rust-is-reduction',
              text: 'Rust forms when oxygen leaves iron, so it is a kind of reduction.',
              hint: 'Which of oxidation and reduction is the reaction that gains oxygen?',
            },
          ],
          correctOptionId: 'rust-is-oxide',
          explanation:
            'Rust is an oxide produced when iron slowly reacts with oxygen and moisture — it has '
            + 'different properties from iron. It is not surface dirt; the iron itself has become '
            + 'a different substance through oxidation.',
        },
      },
      massConservation: {
        title: 'Burned or decomposed — mass never goes anywhere',
        localSpeakingPractice: {
          targetPhrase: 'In a chemical change the total mass of all substances involved does not change',
          acceptedTranscripts: [
            'In a chemical change the total mass of all substances involved does not change',
          ],
        },
        body: [
          'Add hydrochloric acid to sodium hydrogen carbonate and carbon dioxide is produced. '
          + 'In an open vessel the gas escapes and the mass seems to drop — but if the gas is '
          + 'counted too, the total mass before and after the reaction is equal.',
          'Before and after a chemical change, the total mass of all substances taking part is '
          + 'equal. This is the **law of conservation of mass**. A chemical change only rearranges '
          + 'how atoms are combined; the atoms themselves are never destroyed or created.',
          'There are examples that look the opposite. Copper heated in air gains mass — by the '
          + 'amount of oxygen that joined it. If the air is left out of "the whole thing being '
          + 'measured", it looks like a gain; include it and the books balance.',
          'What matters is how far "everything being measured" extends. Open and closed systems '
          + 'seem to give different results only because the substances that moved in or out were '
          + 'or were not included in the measurement — not because the law has exceptions.',
        ],
        tryIt:
          'Using the distributed lab records, read the two mass records from reacting '
          + '"hydrochloric acid plus sodium hydrogen carbonate" once in an open vessel and once '
          + 'in a sealed bag that lets no gas escape, and explain the different readings by how '
          + 'much was included in the measurement. Do not mix chemicals or heat anything at home.',
        localCheckpoint: {
          lure: 'For reactions that produce an escaping gas, conservation of mass does not hold.',
          options: [
            {
              id: 'gas-no-mass',
              text: 'Gases have no mass, so any gas produced can be left out of the mass calculation.',
              hint: 'Do gases have mass? Check with an inflated balloon or a pump.',
            },
            {
              id: 'conservation-fails',
              text: 'The mass drops in an open vessel because part of the substance disappeared in the reaction.',
              hint: 'Did it disappear, or did it move outside the range being measured?',
            },
            {
              id: 'count-escaped-gas',
              text: 'If the escaped gas is measured too, the total mass before and after the reaction is equal.',
            },
          ],
          correctOptionId: 'count-escaped-gas',
          explanation:
            'In an open vessel the reading drops because the produced gas left the measured range. '
            + 'Gases have mass, so sealing the system and measuring everything makes the totals '
            + 'before and after equal.',
        },
      },
    },
  },
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
        localSpeakingPractice: {
          targetPhrase: 'Ignoring air resistance falling speed does not depend on weight',
          acceptedTranscripts: ['Ignoring air resistance falling speed does not depend on weight'],
        },
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
        localSpeakingPractice: {
          targetPhrase: 'With zero net force an object keeps the same speed and direction',
          acceptedTranscripts: ['With zero net force an object keeps the same speed and direction'],
        },
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
        localSpeakingPractice: {
          targetPhrase: 'Friction and air resistance oppose an object’s motion',
          acceptedTranscripts: ['Friction and air resistance oppose an object’s motion'],
        },
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
        localSpeakingPractice: {
          targetPhrase: 'Even at the highest point downward gravity acts on the object',
          acceptedTranscripts: ['Even at the highest point downward gravity acts on the object'],
        },
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
        localSpeakingPractice: {
          targetPhrase: 'Action and reaction are equal and opposite forces on different objects',
          acceptedTranscripts: [
            'Action and reaction are equal and opposite forces on different objects',
          ],
        },
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
        localSpeakingPractice: {
          targetPhrase: 'An object can keep moving even when the net force is zero',
          acceptedTranscripts: ['An object can keep moving even when the net force is zero'],
        },
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
        localSpeakingPractice: {
          targetPhrase: 'Pressure is force divided by area',
          acceptedTranscripts: ['Pressure is force divided by area'],
        },
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
        localSpeakingPractice: {
          targetPhrase: 'Buoyant force equals the weight of the displaced liquid',
          acceptedTranscripts: ['Buoyant force equals the weight of the displaced liquid'],
        },
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
        localSpeakingPractice: {
          targetPhrase: 'Reversing the current reverses the magnetic field',
          acceptedTranscripts: ['Reversing the current reverses the magnetic field'],
        },
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
        localSpeakingPractice: {
          targetPhrase: 'Reversing either the current or the magnetic field reverses the force',
          acceptedTranscripts: [
            'Reversing either the current or the magnetic field reverses the force',
          ],
        },
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
        localSpeakingPractice: {
          targetPhrase: 'Changing magnetic flux induces a voltage in a coil',
          acceptedTranscripts: ['Changing magnetic flux induces a voltage in a coil'],
        },
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
  M12: {
    correct:
      'Density is mass per unit volume. Under the same conditions, changing the amount or shape of one '
      + 'material changes its mass and volume in the same proportion, so its density is basically unchanged.',
    misconception:
      'A larger or heavier object must always have a greater density.',
    lure:
      'Even for the same material, a larger piece is heavier, so its density is greater too — right?',
  },
  M13: {
    correct:
      'Living bodies are made of cells, and plant and animal cells have both shared basic structures and '
      + 'differences. Some plant cells have no chloroplasts, so one feature alone is not enough to classify them.',
    misconception:
      'Every plant cell has chloroplasts, and any cell with no visible chloroplast is an animal cell.',
    lure:
      'Every plant cell should have visible chloroplasts, so if I cannot see any, it must be an animal cell — right?',
  },
  M14: {
    correct:
      'Water vapor is an invisible gas. Clouds consist of tiny water droplets or ice crystals formed when '
      + 'water vapor condenses through cooling and related processes.',
    misconception:
      'A cloud is a collection of white, visible water vapor gas.',
    lure:
      'A cloud is just white water vapor gathering in the sky where we can see it — right?',
  },
  M15: {
    correct:
      'Where strata have not been substantially overturned, lower layers were deposited first and are older. '
      + 'A fault or other event that cuts layers happened after the layers it cuts formed.',
    misconception:
      'Upper strata are older because they are found first near the surface, and lower strata are younger.',
    lure:
      'We find the upper layers first, so the top must be older and the bottom younger — right?',
  },
  M16: {
    correct:
      'Gases differ in water solubility, density relative to air, and reactions with other substances, '
      + 'so each gas must be collected and identified using methods suited to its properties.',
    misconception:
      'All invisible gases have the same properties and can be collected in the same way.',
    lure:
      'All gases are invisible, so we can always collect them the same way over water — right?',
  },
  M17: {
    correct:
      'A change of state can alter particle spacing, motion, and volume, but when no matter enters or leaves '
      + 'a closed system, its total mass does not change.',
    misconception:
      'When a liquid becomes a gas, its particles disappear and mass decreases even in a sealed container.',
    lure:
      'Once a liquid evaporates and becomes invisible, its mass decreases even inside a sealed container — right?',
  },
  M18: {
    correct:
      'Plants photosynthesize in chloroplasts when light is available, while their cells respire throughout '
      + 'day and night. The net gas exchange depends on the rates of both processes.',
    misconception:
      'Plants perform photosynthesis but do not respire.',
    lure:
      'Plants take in carbon dioxide, so they do not respire at all — right?',
  },
  M19: {
    correct:
      'Digestion breaks substances in food into small absorbable substances. Absorption is the separate '
      + 'process by which they enter the body, mainly through the wall of the small intestine.',
    misconception:
      'The moment food is digested in the stomach, all of it is absorbed into the blood there.',
    lure:
      'Once food is digested in the stomach, all of it is absorbed into the blood right there — correct?',
  },
  M20: {
    correct:
      'A front lies near where the boundary between air masses with different properties meets the surface. '
      + 'Clouds, precipitation, temperature, and wind change according to the movement of warm and cold air.',
    misconception:
      'A front is simply a line tracing rain clouds, and every type produces the same changes when it passes.',
    lure:
      'A front just traces the rain clouds, so every type brings the same weather as it passes — right?',
  },
  M21: {
    correct:
      'Pressure differences help drive wind, but its actual direction is also affected by Earth’s rotation '
      + 'and surface friction; in the Northern Hemisphere winds circulate differently around highs and lows.',
    misconception:
      'Everywhere on a weather map, wind blows in a straight line from the center of high pressure to the center of low pressure.',
    lure:
      'On a weather map, wind blows straight from the center of a high to the center of a low — right?',
  },
  M22: {
    correct:
      'Volcanoes and earthquakes both relate to activity inside Earth and plate motion, and their distributions '
      + 'share patterns. However, an eruption involves rising magma while an earthquake involves sudden rock '
      + 'slip, so they are different phenomena and do not necessarily occur together.',
    misconception:
      'Volcanoes and earthquakes are one phenomenon with the same mechanism and always occur at the same '
      + 'place and time on a plate boundary.',
    lure:
      'Volcanoes and earthquakes have the same mechanism, so they always occur together at plate boundaries — right?',
  },
  M23: {
    correct:
      'The apparent daily motion of celestial objects is mainly relative motion caused by Earth’s rotation. '
      + 'Seasonal changes in day length and the Sun’s noon altitude result from Earth revolving with a tilted axis.',
    misconception:
      'Seasons occur because Earth moves closer to the Sun in summer and farther away in winter.',
    lure:
      'Summer is hot and winter is cold because Earth moves closer to the Sun in summer — right?',
  },
  M24: {
    correct:
      'Iron filings and sulfur simply mixed stay a mixture whose grains keep their properties. '
      + 'Only once a chemical change such as heating produces iron sulfide, a differently-behaving '
      + 'substance, has combination occurred.',
    misconception: 'Mixing substances thoroughly creates a new substance (a compound).',
    lure: 'So if you mix iron and sulfur really well, that’s already iron sulfide, right?',
  },
  M25: {
    correct:
      'Rust is an oxide iron forms by slowly reacting with oxygen and moisture — a different '
      + 'substance from iron. Oxidation covers not only combustion but slow combinations with '
      + 'oxygen such as rusting and respiration.',
    misconception: 'Rust is dirt stuck to the surface; the iron has not combined with oxygen.',
    lure: 'Rust is just red stuff stuck on the surface — it’s not iron bonded with oxygen, is it?',
  },
  M26: {
    correct:
      'Gases have mass, and when the gas produced or escaping is included in the measurement, '
      + 'the total mass before and after a chemical change is equal.',
    misconception: 'Gases have no mass, so in reactions that emit gas or burn, mass is not conserved.',
    lure: 'Gases weigh nothing, so when smoke comes out, mass drops by that much — right?',
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
          localSpeakingPractice: st.localSpeakingPractice,
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
  const unitsById = new Map(units.map((unit) => [unit.id, unit]))
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
  for (const [unitId, translated] of Object.entries(EN_UNITS)) {
    const source = unitsById.get(unitId)
    if (source == null) {
      problems.push(`原本に無い単元の英語がある: ${unitId}`)
      continue
    }
    const sourceConcepts = new Set(source.concepts.map((concept) => concept.key))
    const sourceSections = new Set(source.sections.map((section) => section.conceptKey))
    for (const conceptKey of Object.keys(translated.concepts)) {
      if (!sourceConcepts.has(conceptKey)) {
        problems.push(`原本に無い概念の英語がある: ${unitId}/${conceptKey}`)
      }
    }
    for (const conceptKey of Object.keys(translated.sections)) {
      if (!sourceSections.has(conceptKey)) {
        problems.push(`原本に無い教材の英語がある: ${unitId}/${conceptKey}`)
      }
    }
  }
  const sourceMisconceptionIds = new Set(misconceptions.map((m) => m.id))
  for (const id of Object.keys(EN_MISCONCEPTIONS)) {
    if (!sourceMisconceptionIds.has(id)) {
      problems.push(`原本に無い誤概念の英語がある: ${id}`)
    }
  }
  return problems
}

/**
 * Catalog validation entry point used by release checks. Kept separate from the
 * diagnostic helper name so callers can express intent without changing the
 * established translation-key semantics.
 */
export function validateTranslations(
  units: Unit[],
  misconceptions: Misconception[],
): string[] {
  return missingTranslations(units, misconceptions)
}
