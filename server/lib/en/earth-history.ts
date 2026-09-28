import type { UnitContentText } from '../i18n-content.js'

const CAST = {
  mio: { name: 'Mio', role: 'Observation and safety checks' },
  dekisugi: { name: 'Dekisugi-kun', role: 'Overconfident hypotheses' },
  ren: { name: 'Ren', role: 'Checking conditions and records' },
}

export const earthHistoryContent: UnitContentText = {
  unitId: 'earth-history',
  concepts: {
    strataRelativeAge: {
      practice: {
        foundation: {
          recallPrompt:
            'Explain the rule for deciding which of two layers was deposited first, based on their positions in strata that have not been overturned.',
          reasoningPrompt:
            'Add how you can read the order of events from a line that crosses the layers and an upper layer that the line does not cut.',
          expectedOutcome:
            'You can read that the blue, yellow, and white layers were deposited in that order from the bottom, then the event that made the line cutting all three layers happened, and finally the green layer, which the line does not cut, was deposited.',
          expectedReason:
            'Lower layers were deposited first, and an event that cuts several layers happened after the layers it cuts. The green layer covers the line without being cut, so it came after the event that made the line.',
          cognitiveTask: {
            items: {
              'green-layer': 'The uncut green layer is deposited on top.',
              'lower-layers': 'The blue, yellow, and white layers are deposited in order from the bottom.',
              'cutting-event': 'An event cuts across the three layers.',
            },
          },
        },
        conditions: {
          recallPrompt:
            'When reading age from the vertical order of strata, explain why you must check that the strata have not been overturned.',
          reasoningPrompt:
            'Add the time relationship between a fault and the strata by separating “the side that cuts” from “the side that is cut.”',
          transferPrompt:
            'A single fault F cuts sandstone layer A, mudstone layer B, and volcanic-ash layer C, and layer D lies on top, covering the fault without being cut by it. Organize what you can say for certain about the order of A–D and F.',
          expectedOutcome:
            'Fault F moved after A, B, and C were deposited, and layer D was deposited after F moved. The order of A, B, and C relative to one another requires information about their vertical arrangement.',
          expectedReason:
            'Because F cuts them, F is younger than the three layers it cuts, and because D covers F without being cut, D is younger than F. Vertical relationships that are not described are not guessed.',
          checkpoint: {
            lure: 'If fault F cuts layer A, then F came first and A formed on top of it.',
            options: {
              'fault-first': {
                text: 'The fault formed first, and the layer it cuts was deposited over the crack.',
                hint: 'Consider whether a fault that formed first could cut a layer that did not exist yet.',
              },
              'same-event': {
                text: 'The side that cuts and the side that is cut always form at exactly the same time.',
                hint: 'For one feature to be left crossing another, look at which one must already exist first.',
              },
              'fault-after-layer': {
                text: 'Layer A formed first, and fault F moved later and cut A.',
              },
            },
            explanation:
              'For a fault to cut a layer, the layer must already exist. So the fault moved after the layers it cuts were deposited.',
          },
          cognitiveTask: {
            items: {
              'layer-a': 'Layer A, cut by fault F',
              'layer-c': 'Layer C, cut by fault F',
              'fault-f': 'Movement of fault F, which cuts A, B, and C',
              'layer-d': 'Layer D, which covers F and is not cut by F',
            },
            targets: {
              'before-fault': 'Before fault F',
              event: 'Movement of fault F',
              'after-fault': 'After fault F',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Explain the clues, marker beds and fossils, used to match strata at separate locations.',
          reasoningPrompt:
            'Add why you cannot conclude two layers are the same just because their color or thickness is similar, and why you need several kinds of evidence.',
          transferPrompt:
            'The columnar sections at location P and at distant location Q each contain a thin volcanic-ash layer with the same features. At P, fossil X lies below it; at Q, fossil Y lies above it. Using the ash layer as a marker bed, explain the order of events.',
          expectedOutcome:
            'If the ash layers at the two locations are matched as a marker bed of the same age, you can infer that the layer containing fossil X was deposited before the ash, and the layer containing fossil Y after the ash.',
          expectedReason:
            'Even at separate locations, an ash layer from the same eruption serves as a time marker. However, you also need to check evidence that it really is the same marker bed, such as its mineral composition and extent.',
          checkpoint: {
            lure: 'If layers at two distant locations have the same color, they are always from the same time, even without other evidence.',
            options: {
              'color-guarantees': {
                text: 'If the colors match, you can conclude they are the same layer regardless of distance or composition.',
                hint: 'Consider that sand or mud of similar color may be deposited at different times in different places.',
              },
              'combine-evidence': {
                text: 'Match them using several kinds of evidence, not just color: features of the volcanic ash, fossils, and vertical order.',
              },
              'distance-forbids': {
                text: 'If the locations are far apart, the same ash layer cannot spread between them, so they cannot be matched.',
                hint: 'Think of how a single eruption can drop ash over a wide area as a time marker.',
              },
            },
            explanation:
              'Color alone cannot tell apart deposits from different times. Match marker beds by combining features such as the ash’s minerals, fossils, and vertical relationships.',
          },
          cognitiveTask: {
            items: {
              'multi-evidence': 'Match them by combining the ash’s features, fossils, and vertical order.',
              'color-only': 'If the color is the same, treat them as the same age regardless of other features.',
              'near-only': 'Match layers only when the locations are next to each other; do not compare distant ones.',
            },
          },
        },
      },
      story: {
        title: 'The Alibi of the Slanted Line on the Paper Cliff',
        setting:
          'A large table in the library. A colored-paper model of strata has a slanted line cutting the lower three layers and an upper layer covering it.',
        characters: CAST,
        openingLines: {
          'strataRelativeAge.open.1':
            'The slanted line cuts the blue, yellow, and white layers, but not the green one on top.',
          'strataRelativeAge.open.2':
            'With a model, we can check the order of events safely without going to a cliff.',
          'strataRelativeAge.open.3':
            'Green on top stands out the most, so green must be the oldest elder!',
        },
        choiceResponses: {
          'lower-first':
            'You used both the not-overturned condition and the order of deposition correctly.',
          'upper-older': 'You swapped the order we find the layers with the order they were deposited.',
          'same-age':
            'If they were all made at once, we’d need major construction to slip the bottom sheet in afterward!',
        },
        resolutionLines: {
          'strataRelativeAge.resolve.1':
            'If the layers aren’t overturned, lower layers were deposited earlier and are older.',
          'strataRelativeAge.resolve.2':
            'The cutting line came after the layers it cuts, and the green layer covering the line came even later.',
        },
        punchline:
          'The paper cliff never moved. The only thing that got flipped upside down was my timeline.',
      },
      notation: {
        tasks: {
          'strataRelativeAge.sequence': {
            title: 'Order the events in the strata model',
            prompt:
              'Put the events of the fault cutting the lower three layers and the upper layer covering it in order from oldest.',
            guide: 'Check the order: the deposited layers, the cutting event, then the uncut upper layer.',
            tokens: {
              'lower-layers': 'Lower three layers deposited',
              fault: 'Fault cuts the three layers',
              'upper-layer': 'Upper layer covers the fault',
            },
            solutionSummary:
              'The order is: the lower three layers are deposited, the fault moves, then the upper layer is deposited.',
          },
          'strataRelativeAge.labelDiagram': {
            title: 'Read the order in a cross section of strata',
            prompt:
              'Slanted line F cuts A, B, and C but does not reach D. Choose the layer that formed after F.',
            representation: ['──────── D', '────╱── C', '───╱─── B', '──╱──── A', '  F'],
            representationSemanticsLabel:
              'Layers A, B, C, and D from the bottom. Slanted fault F cuts A, B, and C but does not reach D.',
            choices: {
              'layer-a': 'Layer A',
              'layer-c': 'Layer C',
              'layer-d': 'Layer D',
            },
            solutionSummary:
              'D covers fault F and is not cut by it, so it was deposited after F moved.',
          },
          'strataRelativeAge.modelBuild': {
            title: 'Link distant columnar sections with a marker bed',
            prompt:
              'Build the order of events at two locations, using the same volcanic-ash layer as a time marker.',
            guide: 'Read in this order: the lower layer at P, the shared marker bed, then the upper layer at Q.',
            tokens: {
              'p-lower': 'Layer with fossil X at P',
              'key-layer': 'Shared volcanic-ash marker bed',
              'q-upper': 'Layer with fossil Y at Q',
            },
            solutionSummary:
              'If the marker bed is taken as a same-age marker, the X layer is before the marker bed and the Y layer is after it.',
          },
        },
      },
    },
    volcanoEarthquakes: {
      practice: {
        foundation: {
          recallPrompt:
            'Explain the shared tendency in where volcanoes and earthquakes occur, and how they are not the same phenomenon.',
          reasoningPrompt:
            'Add why overlapping distributions alone do not mean the two always happen at the same time.',
          expectedOutcome:
            'Distribution maps show a shared tendency for volcanoes and epicenters to be common near plate boundaries, but there are also regions where the two do not match.',
          expectedReason:
            'Both relate to plate motion, but an earthquake is sudden rock slip and an eruption is rising magma, which are different processes with different conditions for occurring.',
          cognitiveTask: {
            items: {
              'plate-boundary-cluster': 'Common near plate boundaries',
              'rock-slip': 'Sudden slip of underground rock',
              'magma-rise': 'Magma rising and erupting',
              'same-timing': 'Always occur at the same time',
            },
            targets: {
              'shared-tendency': 'Shared tendency',
              'event-specific': 'Specific to one phenomenon',
              unsupported: 'Not supported by the data',
            },
          },
        },
        conditions: {
          recallPrompt: 'Explain how magma viscosity and volcanic gas affect the way a volcano erupts.',
          reasoningPrompt:
            'Add the limitation that magma properties alone cannot fully predict the size of an individual eruption.',
          transferPrompt:
            'Source A describes magma with low viscosity from which gas escapes easily; Source B describes magma with high viscosity from which gas escapes with difficulty. Compare their typical eruption tendencies.',
          expectedOutcome:
            'A tends toward relatively gentle eruptions in which lava flows easily, while B tends to build pressure and erupt explosively.',
          expectedReason:
            'When viscosity is high, gas has difficulty escaping and internal pressure builds more easily. However, actual eruptions also vary with factors such as gas amount and supply rate.',
          checkpoint: {
            lure: 'The more viscous the magma, the faster gas escapes, so it always erupts gently.',
            options: {
              'viscous-releases': {
                text: 'The more viscous the magma, the more freely gas escapes, so no pressure builds up.',
                hint: 'Consider whether bubbles can easily escape through a liquid that barely moves.',
              },
              'gas-trapped': {
                text: 'When magma is highly viscous, gas has difficulty escaping and pressure builds more easily.',
              },
              'viscosity-irrelevant': {
                text: 'Magma viscosity has nothing to do with how a volcano erupts.',
                hint: 'Compare how easily lava flows with how easily gas escapes.',
              },
            },
            explanation:
              'In highly viscous magma, gas has difficulty escaping, so pressure builds and eruptions tend to be explosive.',
          },
          cognitiveTask: {
            items: {
              'explosive-tendency': 'The eruption tends to be explosive.',
              'high-viscosity': 'The magma is highly viscous.',
              'gas-retained': 'Gas has difficulty escaping, and pressure builds.',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Explain the relationship between distance from the focus and the difference in arrival times of P waves and S waves.',
          reasoningPrompt:
            'Add that the strength of shaking depends not only on distance but also on earthquake magnitude and ground conditions.',
          transferPrompt:
            'For the same earthquake, the gap between P-wave and S-wave arrivals was 4 seconds at location P and 12 seconds at location Q. Compare their distances from the focus, and also state what cannot be concluded.',
          expectedOutcome:
            'For the same earthquake, you can infer that Q, with the larger arrival gap, is farther from the focus, but this gap alone does not determine the strength of shaking or the exact location of the focus.',
          expectedReason:
            'Because P waves and S waves travel at different speeds, the arrival gap grows with distance. Locating the focus requires several locations, and shaking also requires information about magnitude and ground conditions.',
          checkpoint: {
            lure: 'Q, with the larger arrival gap, is closer to the focus and always shakes more strongly than P.',
            options: {
              'larger-gap-nearer': {
                text: 'The larger the arrival gap, the closer to the focus, and the shaking is always stronger.',
                hint: 'Consider what happens to the arrival gap when two waves with different speeds travel a long distance.',
              },
              'gap-fixes-intensity': {
                text: 'The arrival gap alone determines the location of the focus and the seismic intensity at every location.',
                hint: 'Check how many observation locations are needed to locate the focus, and the effect of ground conditions.',
              },
              'larger-gap-farther': {
                text: 'For the same earthquake, Q with the larger arrival gap is farther away, but the strength of shaking requires other information too.',
              },
            },
            explanation:
              'For the same earthquake, the gap between P-wave and S-wave arrivals grows with distance, but seismic intensity is not determined by distance alone.',
          },
          cognitiveTask: {
            items: {
              'gap-means-near': 'Q, with a 12-second gap, is closer and always shakes more strongly.',
              'gap-fixes-location': 'The arrival gap at one location alone pins down the focus.',
              'gap-means-far': 'For the same earthquake, Q is farther, but shaking also depends on other conditions.',
            },
          },
        },
      },
      story: {
        title: 'The Volcano Marks and the Epicenter Marks Go Their Separate Ways',
        setting:
          'The disaster-preparedness classroom. Past distribution maps of volcanoes, epicenters, and plate boundaries from public agencies are laid on top of one another.',
        characters: CAST,
        openingLines: {
          'volcanoEarthquakes.open.1':
            'There are lots of both near the boundaries, but in some places the marks don’t overlap.',
          'volcanoEarthquakes.open.2':
            'Let’s record the shared pattern and the evidence specific to each one separately.',
          'volcanoEarthquakes.open.3':
            'If they’re on the same map, volcanoes and earthquakes must always appear as a duo!',
        },
        choiceResponses: {
          'evidence-specific':
            'You’ve covered both the link to plates and the fact that they’re different phenomena.',
          'same-everywhere':
            'A pattern in where they occur doesn’t mean they happen together at every place and every moment.',
          'one-event': 'I cast seismic waves and volcanic ash as the same actor!',
        },
        resolutionLines: {
          'volcanoEarthquakes.resolve.1':
            'An earthquake involves sudden rock slip, and an eruption involves rising magma. They’re different phenomena.',
          'volcanoEarthquakes.resolve.2':
            'Even with a shared tendency to cluster at plate boundaries, each needs its own evidence.',
        },
        punchline:
          'On the map they’re neighbors, but in the case files they’re handled by different detectives.',
      },
      notation: {
        tasks: {
          'volcanoEarthquakes.tableRead': {
            title: 'Read where the distributions overlap and differ',
            prompt:
              'Choose what the table of plate boundaries, epicenters, and volcanoes by region supports.',
            representation: [
              'Region | Boundary | Many epicenters | Many volcanoes',
              'A | Yes | Yes | Yes',
              'B | Yes | Yes | No',
              'C | No | Few | Some',
            ],
            representationSemanticsLabel:
              'Region A, with a boundary, has many of both; B has many epicenters only; and C, with no boundary, still has volcanoes.',
            choices: {
              'always-together': 'Always occur together at boundaries',
              'shared-trend': 'Shared tendency, but not a perfect match',
              unrelated: 'Completely unrelated to plates',
            },
            solutionSummary:
              'They share a tendency to be common near boundaries, but their distributions do not match perfectly.',
          },
          'volcanoEarthquakes.sequence': {
            title: 'Connect viscosity to eruption tendency',
            prompt: 'Order the causes that make highly viscous magma tend to erupt explosively.',
            guide: 'Connect viscosity, how easily gas escapes, pressure, and eruption tendency.',
            tokens: {
              viscous: 'Magma is highly viscous',
              'gas-trapped': 'Gas has difficulty escaping',
              'pressure-builds': 'Internal pressure builds more easily',
              explosive: 'Eruption tends to be explosive',
            },
            solutionSummary:
              'When viscosity is high, gas has difficulty escaping and pressure builds more easily.',
          },
          'volcanoEarthquakes.labelDiagram': {
            title: 'Read the gap between P-wave and S-wave arrivals',
            prompt:
              'For the same earthquake, choose the record you can infer is farther from the focus.',
            representation: [
              'Location P: P arrives 0 s, S arrives 4 s',
              'Location Q: P arrives 0 s, S arrives 12 s',
            ],
            representationSemanticsLabel:
              'Measured from the P-wave arrival, the gap until the S wave arrives is 4 seconds at P and 12 seconds at Q.',
            choices: {
              'point-p': 'Location P',
              'point-q': 'Location Q',
              'same-distance': 'Same distance',
            },
            solutionSummary:
              'For the same earthquake, you can infer that Q, with the larger gap between P-wave and S-wave arrivals, is farther away.',
          },
        },
      },
    },
    dailyMotionSeasons: {
      practice: {
        foundation: {
          recallPrompt:
            'Explain the daily motion of celestial objects over one night separately from the change in constellations over one year.',
          reasoningPrompt:
            'Add why daily motion appears to go in the direction opposite to Earth’s rotation.',
          expectedOutcome:
            'In the simulation, stars move from east to west over one night, and at the same clock time, advancing the month shifts the visible constellations toward the west.',
          expectedReason:
            'The apparent motion over one night is caused by Earth rotating from west to east, and the change at the same clock time over a year is caused by the change in viewing direction as Earth revolves.',
          cognitiveTask: {
            items: {
              'nightly-east-west': 'Apparent east-to-west motion over one night',
              'monthly-constellation': 'Month-to-month change in constellations seen at the same clock time',
              'earth-revolution': 'Earth’s revolution',
              'earth-rotation': 'Earth’s rotation',
            },
            targets: {
              daily: 'Daily motion',
              annual: 'Annual change',
            },
          },
        },
        conditions: {
          recallPrompt:
            'Explain why star trails look different in the northern and southern sky, using their positions relative to the north celestial pole.',
          reasoningPrompt:
            'Add that diagrams made without matching the observer’s latitude and viewing direction cannot be compared directly.',
          transferPrompt:
            'At the same location in the Northern Hemisphere, there are long-exposure records from cameras fixed facing north and facing south. Compare the shapes of the star trails and their east–west direction.',
          expectedOutcome:
            'In the northern sky, trails are recorded as arcs centered on the north celestial pole; in the southern sky, as tilted arcs that rise in the east and set in the west.',
          expectedReason:
            'The celestial sphere appears to turn around the direction of Earth’s rotation axis extended into the sky, and the part of that circular motion you see depends on which direction you look.',
          checkpoint: {
            lure: 'Star trails are the same straight lines everywhere in the sky, regardless of direction or latitude.',
            options: {
              'same-lines': {
                text: 'Even though Earth rotates, every star traces the same parallel straight line.',
                hint: 'Consider how the trails look near the point where the rotation axis meets the sky.',
              },
              'direction-dependent-arcs': {
                text: 'Depending on their position relative to the celestial pole, the arcs look different in each viewing direction.',
              },
              'stars-random': {
                text: 'Stars move in unrelated directions each night, so no regular trails form.',
                hint: 'Use the regular pattern recorded over a long time from the same location and direction.',
              },
            },
            explanation:
              'Stars appear to circle around the celestial pole, and the arcs you see change with viewing direction and latitude.',
          },
          cognitiveTask: {
            items: {
              'circular-arcs': 'Trails are recorded as arcs centered on the celestial pole.',
              'earth-spins': 'Earth rotates from west to east.',
              'sky-opposite': 'The celestial sphere appears to turn from east to west.',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Explain why the Sun is higher and days are longer in a Northern Hemisphere summer, using axial tilt and revolution.',
          reasoningPrompt:
            'Add why distance from the Sun alone cannot explain the opposite seasons in the Northern and Southern Hemispheres.',
          transferPrompt:
            'Data from the same day show that Northern Hemisphere location N has a high Sun and long days, while Southern Hemisphere location S has a low Sun and short days. Explain the seasons and the solar conditions.',
          expectedOutcome:
            'N has summer conditions and S has winter conditions. At N, sunlight strikes closer to straight on and for a longer time.',
          expectedReason:
            'Because Earth revolves with its axis tilted, when one hemisphere is tilted toward the Sun, the other is tilted away. The distance to the Sun is almost the same for both locations on Earth.',
          checkpoint: {
            lure: 'On the same day, N and S are at very different distances from the Sun, so they have opposite seasons.',
            options: {
              'hemisphere-distance': {
                text: 'Only the difference in each hemisphere’s distance from the Sun determines the seasons.',
                hint: 'Compare the distance difference due to Earth’s size with the distance to the Sun.',
              },
              'same-season': {
                text: 'Since it is the same Earth, both hemispheres always have the same season and day length.',
                hint: 'Compare which way the axis is tilted relative to the Sun.',
              },
              'tilt-opposite-seasons': {
                text: 'Axial tilt makes the angle of sunlight and day length change in opposite ways, so the seasons are opposite too.',
              },
            },
            explanation:
              'Axial tilt makes the angle of sunlight and day length change in opposite ways in the two hemispheres, so their seasons are also opposite.',
          },
          cognitiveTask: {
            items: {
              'distance-by-hemisphere': 'Each hemisphere’s distance from the Sun alone makes the seasons opposite.',
              'tilt-changes-insolation': 'Axial tilt makes the angle of sunlight and day length change in opposite ways.',
              'both-same-season': 'Since it is the same Earth, the seasons are always the same.',
            },
          },
        },
      },
      story: {
        title: 'The Star Calendar’s Day-and-Year Mix-Up',
        setting:
          'The planetarium classroom. The class compares star-sky simulations of one night at one place with the same clock time across different months.',
        characters: CAST,
        openingLines: {
          'dailyMotionSeasons.open.1':
            'Over one night the stars move from east to west, and when we advance the month, the constellations at the same time change too.',
          'dailyMotionSeasons.open.2':
            'Let’s separate the daily change from rotation and the yearly change from revolution.',
          'dailyMotionSeasons.open.3':
            'The closer we get to the Sun, the more summer it is. The Southern Hemisphere just takes the long way around!',
        },
        choiceResponses: {
          'rotation-revolution': 'You matched each time scale with one of Earth’s two motions.',
          'earth-still':
            'When Earth rotates from west to east, the sky appears to move the opposite way.',
          'sun-distance-only':
            'I couldn’t explain why the north and south of the same Earth have opposite seasons!',
        },
        resolutionLines: {
          'dailyMotionSeasons.resolve.1':
            'Daily motion is explained by rotation, and the yearly change in constellations at the same time by revolution.',
          'dailyMotionSeasons.resolve.2':
            'Seasons happen because axial tilt changes the Sun’s altitude and the length of the day.',
        },
        punchline:
          'Turns out I was writing the 24-hour column and the 12-month column in the same box of my star calendar.',
      },
      notation: {
        tasks: {
          'dailyMotionSeasons.sequence': {
            title: 'Order how daily motion appears',
            prompt: 'Order the steps from Earth’s rotation to the apparent motion of the stars.',
            guide: 'Connect the actual direction of rotation to the apparent motion in the opposite direction.',
            tokens: {
              'rotate-east': 'Earth rotates from west to east',
              'observer-turns': 'The observer turns along with Earth',
              'sky-west': 'Celestial objects appear to move from east to west',
            },
            solutionSummary:
              'Because Earth rotates from west to east, celestial objects appear to move from east to west.',
          },
          'dailyMotionSeasons.tableRead': {
            title: 'Read the sunlight table for both hemispheres',
            prompt:
              'When Northern Hemisphere location N is in summer, choose the season at Southern Hemisphere location S.',
            representation: [
              'Location | Sun’s altitude | Day length',
              'N | High | Long',
              'S | Low | Short',
            ],
            representationSemanticsLabel:
              'On the same day, Northern Hemisphere location N has a high Sun and long days. Southern Hemisphere location S has a low Sun and short days.',
            choices: {
              summer: 'Summer',
              winter: 'Winter',
              'same-season': 'Same season as N',
            },
            solutionSummary:
              'Axial tilt makes the solar conditions opposite, so S is in winter.',
          },
          'dailyMotionSeasons.modelBuild': {
            title: 'Build the causes of seasonal change',
            prompt:
              'Build a Northern Hemisphere summer from axial tilt and solar conditions.',
            guide:
              'Connect the orbital position, the hemisphere’s tilt, the Sun’s altitude and day length, and the energy received.',
            tokens: {
              'tilt-sunward': 'The Northern Hemisphere tilts toward the Sun',
              'sun-higher': 'The Sun’s altitude gets higher',
              'day-longer': 'Days get longer',
              'more-energy': 'More solar energy is received',
              summer: 'The Northern Hemisphere has summer',
            },
            solutionSummary:
              'Axial tilt changes the Sun’s altitude and the length of the day, which produces the seasons.',
          },
        },
      },
    },
  },
}
