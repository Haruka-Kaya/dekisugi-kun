import type { UnitContentText } from '../i18n-content.js'

export const weatherChangeContent: UnitContentText = {
  unitId: 'weather-change',
  concepts: {
    humidityClouds: {
      practice: {
        foundation: {
          recallPrompt:
            'Explain the difference between the state of water vapor and the state of the water droplets that make up clouds, including whether each can be seen.',
          reasoningPrompt:
            'Add an explanation, using dew point and condensation, of why water droplets form on the outside of a cold cup.',
          expectedOutcome:
            'Water droplets form on the outside of the cup filled with cold water, while almost none form on the room-temperature cup in the same amount of time.',
          expectedReason:
            'Surrounding air that touched the cold surface cooled to its dew point, and invisible water vapor in the air condensed. The droplets did not pass through from the inside of the cup.',
          cognitiveTask: {
            items: {
              droplets: 'Excess water vapor condenses into water droplets.',
              'cool-air': 'The surrounding air that touches the cup cools.',
              'reach-dew-point': 'The air reaches its dew point and becomes saturated.',
            },
          },
        },
        conditions: {
          recallPrompt:
            'Explain, using the change in the maximum amount of water vapor air can contain, why humidity rises when air with a nearly constant amount of water vapor is cooled.',
          reasoningPrompt:
            'Add that, even at the same temperature, a difference in humidity changes how much cooling is needed to reach the dew point.',
          transferPrompt:
            'In the same room, Air A (20°C, 80% humidity) and Air B (20°C, 40% humidity) are cooled at the same rate. Which do you predict will start to condense first?',
          expectedOutcome:
            'Air A becomes saturated after a smaller drop in temperature, so it reaches its dew point and starts to condense first.',
          expectedReason:
            'At the same temperature, Air A at 80% humidity contains water vapor closer to the maximum amount it can hold at that temperature, so it reaches saturation even with a smaller cooling-driven drop in that maximum amount.',
          checkpoint: {
            lure: 'At the same temperature, air at 40% humidity is drier and lighter, so it forms clouds first.',
            options: {
              'nearer-saturation': {
                text: 'Air at 80% humidity is closer to saturation, so it condenses first with less cooling.',
              },
              'drier-first': {
                text: 'Air at 40% humidity can take in water vapor more easily, so it condenses first.',
                hint: 'Condensation begins not when air takes in more water vapor, but when it can no longer hold all of it.',
              },
              'temperature-only': {
                text: 'If the starting temperature is the same, both condense at the same time regardless of humidity.',
                hint: 'The dew point also depends on the amount of water vapor actually in the air.',
              },
            },
            explanation:
              'At the same temperature, air with higher humidity is closer to saturation and reaches its dew point with less cooling. Air at 40% humidity must be cooled further.',
          },
          cognitiveTask: {
            items: {
              'air-a-humidity': 'Starting humidity of Air A: 80%',
              'air-b-humidity': 'Starting humidity of Air B: 40%',
              'start-temperature': 'Starting temperature of both: 20°C',
              'cooling-rate': 'Cooling rate',
            },
            targets: {
              different: 'Different condition',
              same: 'Controlled (same) condition',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Explain how rising air forms a cloud, in order: pressure, volume, temperature, and condensation.',
          reasoningPrompt:
            'Add, using the conditions of water-vapor amount and dew point, why rising air does not always form a cloud.',
          transferPrompt:
            'Moist air is rising along a mountain slope. If no water vapor is added from outside before or during the rise, predict the changes that occur until a cloud starts to form.',
          expectedOutcome:
            'The rising air expands as the surrounding pressure drops and cools; when it reaches its dew point, water vapor condenses and cloud droplets start to form.',
          expectedReason:
            'As the temperature falls, the maximum amount of water vapor the air can contain decreases until the actual amount of water vapor reaches saturation. If there is not enough water vapor, condensation may not occur even when air rises to the same height.',
          checkpoint: {
            lure: 'As air climbs a mountain it gets closer to the ground and is squeezed, so it warms up while forming a cloud.',
            options: {
              'compressed-warming': {
                text: 'The higher air rises, the higher the pressure becomes, so the air shrinks, warms, and condenses.',
                hint: 'Check whether the surrounding pressure becomes higher or lower as altitude increases.',
              },
              'expansion-cooling': {
                text: 'As air rises and the surrounding pressure drops, the air expands and cools, then condenses at its dew point.',
              },
              'vapor-turns-white': {
                text: 'The temperature does not change as air rises; water vapor gas simply gathers and turns white.',
                hint: 'Separate the state of the particles that make a cloud visible from the temperature change of rising air.',
              },
            },
            explanation:
              'Surrounding pressure is lower at higher altitudes, so rising air expands and cools. When it reaches its dew point, water vapor condenses into water droplets or ice crystals.',
          },
          cognitiveTask: {
            items: {
              'compress-warm': 'Rising air is compressed and warms, so it looks white while still water vapor.',
              unchanged: 'Pressure and temperature do not change as air rises, and a cloud always forms at the same height.',
              'expand-cool': 'Rising air expands and cools; if it reaches its dew point, water vapor condenses into cloud droplets.',
            },
          },
        },
      },
      story: {
        title: 'Local Rain—Outside the Cup Only',
        setting:
          'A classroom desk. Two identical dry cups sit side by side; only one is filled with cold water, and the students watch the outside surfaces.',
        characters: {
          mio: { name: 'Mio', role: 'Observation and safety checks' },
          dekisugi: { name: 'Dekisugi-kun', role: 'Overconfident hypotheses' },
          ren: { name: 'Ren', role: 'Checking conditions and records' },
        },
        openingLines: {
          'humidityClouds.open.1': 'Tiny water droplets are building up—but only on the outside of the cold cup.',
          'humidityClouds.open.2': "Nothing spilled over the open top, and the room-temperature cup doesn't have any.",
          'humidityClouds.open.3': 'The invisible water vapor changed into white uniforms and lined up outside the cup!',
        },
        choiceResponses: {
          'white-gas': "Water vapor is a gas, and you can't see it. Let's tell apart the state of the particles we can see.",
          'dust-only': "That can't explain the droplets we saw growing, or how clouds lead to rain and snow.",
          'droplets-or-ice': 'Not white uniforms—it was light scattering off water droplets!',
        },
        resolutionLines: {
          'humidityClouds.resolve.1': 'When air cools to its dew point, some of the invisible water vapor condenses.',
          'humidityClouds.resolve.2': 'Tiny water droplets and ice crystals scatter light, so we see them as a cloud.',
        },
        punchline: "Today's forecast: rain on the cup only. Coverage area: a 5-centimeter radius.",
      },
      notation: {
        tasks: {
          'humidityClouds.sequence': {
            title: 'Order the steps from rising air to cloud droplets',
            prompt: 'Arrange, in causal order, the steps from moist air rising to cloud droplets forming.',
            guide: 'Connect pressure, expansion, temperature, dew point, and condensation in that order.',
            tokens: {
              'pressure-drops': 'Surrounding pressure drops',
              'air-expands': 'The air expands',
              'air-cools': 'The temperature falls',
              'dew-point': 'The air reaches its dew point',
              condensation: 'Water vapor condenses',
            },
            solutionSummary:
              'When air rises and the pressure drops, the air expands and cools, and condensation begins at the dew point.',
          },
          'humidityClouds.tableRead': {
            title: 'Read a table of saturation vapor amounts',
            prompt:
              'Choose what happens when air containing the same amount of water vapor is cooled from 20°C to 10°C.',
            representation: [
              'Temperature | Saturation vapor amount',
              '20°C | 17.3 g/m³',
              '10°C | 9.4 g/m³',
              'Actual water vapor | 12.0 g/m³',
            ],
            representationSemanticsLabel:
              'The saturation vapor amount is 17.3 at 20 degrees and 9.4 at 10 degrees; the actual water vapor is 12.0 grams per cubic meter.',
            choices: {
              'all-vapor': 'Even at 10°C, all 12.0 g/m³ stays as water vapor',
              'condense-excess': 'At 10°C, the amount that cannot be held condenses',
              'vapor-increases': 'Cooling alone increases the water vapor to 17.3 g/m³',
            },
            solutionSummary:
              'The maximum amount air can hold at 10°C is 9.4 g/m³, so part of the difference from 12.0 condenses.',
          },
          'humidityClouds.graphRead': {
            title: 'Read a graph of temperature and saturation vapor amount',
            prompt: 'Reading the graph toward lower temperatures, what happens to the saturation vapor amount?',
            representation: ['Saturation vapor amount', '        ／', '     ／', 'Temperature →'],
            representationSemanticsLabel:
              'The horizontal axis is temperature and the vertical axis is saturation vapor amount. The curve rises toward higher temperatures.',
            choices: {
              decreases: 'It decreases',
              fixed: 'It stays the same',
              increases: 'It increases',
            },
            solutionSummary:
              'As temperature falls, the saturation vapor amount decreases, so air with the same amount of water vapor gets closer to saturation.',
          },
        },
      },
    },
    fronts: {
      practice: {
        foundation: {
          recallPrompt: 'Explain how warm air and cold air are layered at a warm front.',
          reasoningPrompt:
            'Add that the weather during a front’s passage is a typical tendency and is not always the same.',
          expectedOutcome:
            'The data show the typical time series of a warm front: layered clouds spread as the front approaches, precipitation continues, and temperature rises after it passes.',
          expectedReason:
            'Advancing warm air rises gradually over denser cold air, cooling across a broad area and forming clouds.',
          cognitiveTask: {
            items: {
              'temperature-rises': 'Temperature tends to rise after passage.',
              'warm-air-rises': 'Warm air rises gradually over cold air.',
              'layered-clouds': 'Layered clouds and precipitation over a broad area.',
            },
          },
        },
        conditions: {
          recallPrompt:
            'Explain the difference between warm-front and cold-front cross-sections based on which air mass is advancing.',
          reasoningPrompt:
            'Add that the area and intensity of precipitation also change with water-vapor content and front speed.',
          transferPrompt:
            'In cross-section A, warm air advances gradually over cold air; in cross-section B, cold air pushes suddenly under warm air. Match each to the type of front and its cloud tendency.',
          expectedOutcome:
            'A is a warm front, likely to have layered clouds over a broad area; B is a cold front, likely to have tall, developed clouds in a narrow area.',
          expectedReason:
            'The slope and speed at which warm air is lifted are different. However, actual clouds and rain also depend on factors such as the amount of water vapor present.',
          checkpoint: {
            lure: 'Diagrams A and B differ only in the slope of the line; the air-mass motion and weather tendency are the same.',
            options: {
              'same-front': {
                text: 'Both are the same front, and the direction warm and cold air advance does not matter.',
                hint: 'Compare which air mass advances and lifts the other.',
              },
              'cross-section-match': {
                text: 'A is a warm front and B is a cold front; the way warm air rises is different.',
              },
              'clouds-impossible': {
                text: 'Air does not move up or down at an air-mass boundary, so no clouds form in either case.',
                hint: 'Think about what happens when warm air is lifted and cools.',
              },
            },
            explanation:
              'Because a different air mass is advancing, the way warm air is lifted and the typical distribution of clouds and precipitation differ.',
          },
          cognitiveTask: {
            items: {
              'gentle-slope': 'Cross-section where warm air rises gently',
              'cold-wedge': 'Cross-section where cold air pushes under warm air',
              'narrow-cloud': 'Developed clouds in a narrow area',
              'broad-cloud': 'Layered clouds over a broad area',
            },
            targets: {
              'warm-front': 'Warm front A',
              'cold-front': 'Cold front B',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Explain why a front’s passage should be checked with a time series, not just a weather map from a single moment.',
          reasoningPrompt: 'Add why a front symbol alone cannot determine local precipitation.',
          transferPrompt:
            'At location P, the temperature dropped within a short time, the wind direction changed, and heavy precipitation fell during a narrow time window. Weather maps from before and after show a cold front passing. State your evidence and its limits.',
          expectedOutcome:
            'The observed time series is consistent with the typical changes of a cold-front passage, but one example at location P does not show that every cold front brings rain of the same intensity.',
          expectedReason:
            'When cold air lifts warm air suddenly, developed clouds are likely to form, but how this appears changes with water-vapor content, terrain, front speed, and other factors.',
          checkpoint: {
            lure: 'Heavy rain was observed once, so a cold front always brings the same amount of rain everywhere.',
            options: {
              'fixed-rainfall': {
                text: 'The type of front alone uniquely determines the rainfall, regardless of location or season.',
                hint: 'Consider conditions other than the front, such as the amount of water vapor that forms clouds, and terrain.',
              },
              'no-front-evidence': {
                text: 'Changes over time in temperature, wind direction, and precipitation cannot be used at all to judge a front’s passage.',
                hint: 'Check whether the front’s position on the weather maps matches the observed changes in time.',
              },
              'trend-with-limits': {
                text: 'The observations are consistent with cold-front tendencies, but rain intensity also depends on other conditions.',
              },
            },
            explanation:
              'Several changes over time are evidence of a front’s passage, but the type of front alone cannot fix the amount of precipitation.',
          },
          cognitiveTask: {
            items: {
              'same-rain-always': 'Every cold front brings the same amount of rain.',
              'observations-useless': 'Time-series observations cannot be used to judge a front.',
              'evidence-with-conditions':
                'Consistent with a front-passage tendency, but precipitation intensity also depends on other conditions.',
            },
          },
        },
      },
      story: {
        title: 'Warm Air’s Footprints on the Weather Map',
        setting:
          'A data screen in the school broadcast room. Indoors, the students review a past warm front alongside time series of temperature, clouds, and precipitation.',
        characters: {
          mio: { name: 'Mio', role: 'Observation and safety checks' },
          dekisugi: { name: 'Dekisugi-kun', role: 'Overconfident hypotheses' },
          ren: { name: 'Ren', role: 'Checking conditions and records' },
        },
        openingLines: {
          'fronts.open.1': 'Layered clouds spread out ahead of the front, and the temperature rises after it passes.',
          'fronts.open.2': 'In the cross-section, warm air is moving gradually up over the cold air.',
          'fronts.open.3': 'Warm air is heavier, so it must tunnel underneath the cold air!',
        },
        choiceResponses: {
          'warm-over-cold': 'You matched the density difference and the advancing air mass to the cross-section.',
          'cold-over-warm': 'Warm air is less dense than cold air, so it gets lifted up.',
          'no-boundary': 'I erased the air-mass boundary right out of the front symbol!',
        },
        resolutionLines: {
          'fronts.resolve.1': 'At a warm front, warm air rises gradually over cold air.',
          'fronts.resolve.2':
            'Broad clouds and precipitation are a typical tendency; their intensity also changes with water-vapor content and other factors.',
        },
        punchline: 'Warm air didn’t leave footprints underground—it left a staircase of clouds.',
      },
      notation: {
        tasks: {
          'fronts.sequence': {
            title: 'Order the changes at a warm front',
            prompt: 'Arrange, in typical order, the changes from warm air moving in until after the front passes.',
            guide: 'Connect the rising warm air, the clouds and precipitation, and the temperature after passage.',
            tokens: {
              'warm-rises': 'Warm air rises gradually over cold air',
              'layer-clouds': 'Layered clouds form over a broad area',
              'steady-rain': 'Steady precipitation is likely',
              'warmer-after': 'Temperature tends to rise after passage',
            },
            solutionSummary:
              'At a warm front, warm air rises gradually, and after broad clouds and precipitation, the location enters the warm-air side.',
          },
          'fronts.labelDiagram': {
            title: 'Identify a front cross-section',
            prompt: 'Choose the name of the front whose cross-section shows cold air pushing suddenly under warm air.',
            representation: ['      Warm air ↗', 'Cold air ▶＿＿／', 'Ground ─────────'],
            representationSemanticsLabel:
              'A cross-section in which dense cold air wedges under warm air and lifts it suddenly.',
            choices: {
              'warm-front': 'Warm front',
              'cold-front': 'Cold front',
              'stationary-only': 'Only a stationary front',
            },
            solutionSummary: 'A cross-section where advancing cold air lifts warm air suddenly is a cold front.',
          },
          'fronts.tableRead': {
            title: 'Read a passage time series',
            prompt:
              'From a temperature drop, a change in wind direction, and brief heavy precipitation, choose the most consistent explanation.',
            representation: [
              'Time | Temperature | Precipitation',
              '12:00 | 22°C | None',
              '14:00 | 18°C | Heavy',
              '16:00 | 15°C | Weakening',
            ],
            representationSemanticsLabel:
              'There was heavy precipitation around 14:00, and the temperature fell from 22 degrees to 15 degrees.',
            choices: {
              'cold-passage': 'Consistent with the tendency of a cold-front passage',
              'fixed-proof': 'Proves the rainfall of every cold front',
              'no-boundary': 'Declares it unrelated to any front',
            },
            solutionSummary:
              'Several changes over time are consistent with a cold-front passage, but the rainfall cannot be fixed for every case.',
          },
        },
      },
    },
    pressurePatternsWind: {
      practice: {
        foundation: {
          recallPrompt:
            'Explain separately the direction in which a pressure difference produces wind and the reason the actual wind direction bends.',
          reasoningPrompt: 'Add that wind tends to be stronger where isobars are more closely spaced.',
          expectedOutcome:
            'On past weather maps, observed wind speeds are generally greater in areas with closely spaced isobars and smaller in areas with widely spaced isobars.',
          expectedReason:
            'The larger the pressure difference over the same distance, the larger the force moving the air. However, terrain and friction change individual observed values.',
          cognitiveTask: {
            items: {
              'narrow-isobars': 'Area with closely spaced isobars',
              'wide-isobars': 'Area with widely spaced isobars',
              'small-gradient': 'Small pressure difference over the same distance',
              'large-gradient': 'Large pressure difference over the same distance',
            },
            targets: {
              'stronger-trend': 'Tends toward stronger wind',
              'weaker-trend': 'Tends toward weaker wind',
            },
          },
        },
        conditions: {
          recallPrompt:
            'Explain why strong large-scale wind in a place with no pressure difference cannot be explained by the pressure-gradient force alone.',
          reasoningPrompt:
            'Add that Earth’s rotation is not a force that starts wind moving; it affects the path of air that is already moving.',
          transferPrompt:
            'Areas A and B are at the same latitude with the same surface conditions, and A’s isobar spacing is half of B’s. Compare the tendencies of their large-scale wind speeds.',
          expectedOutcome:
            'A has a larger pressure difference over the same distance, so you can predict that its wind tends to be stronger than B’s.',
          expectedReason:
            'When the comparison conditions are controlled, isobar spacing shows the size of the pressure gradient. However, local terrain and other factors could reverse the observed values.',
          checkpoint: {
            lure: 'In A, where the isobars are close together, air can’t get through, so the wind is always weaker than in B.',
            options: {
              'lines-block-air': {
                text: 'Isobars are walls, so the more lines there are, the more they stop the wind.',
                hint: 'Check whether isobars are real walls or lines on a map connecting points of equal pressure.',
              },
              'larger-gradient': {
                text: 'In A, pressure changes a lot over the same distance, so the wind tends to be stronger.',
              },
              'spacing-no-meaning': {
                text: 'Isobar spacing has nothing to do with wind; only the colors show wind speed.',
                hint: 'Read from the line spacing how many hPa the pressure changes over the same distance.',
              },
            },
            explanation:
              'The closer the isobars, the larger the pressure gradient; if other conditions are the same, the wind tends to be stronger.',
          },
          cognitiveTask: {
            items: {
              'isobar-wall': 'A is weaker because the lines act as walls.',
              'greater-gradient': 'A has a larger pressure gradient, so its wind tends to be stronger.',
              'map-color-only': 'Spacing has nothing to do with wind speed.',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Explain why surface winds in the Northern Hemisphere cross isobars at an angle.',
          reasoningPrompt:
            'Add that friction differs between the upper air and the surface, so wind direction differs too.',
          transferPrompt:
            'Around a low-pressure system in the Northern Hemisphere, compare wind vectors in the upper air and near the surface. Explain the difference using the direction toward low pressure, the effect of rotation, and friction.',
          expectedOutcome:
            'Upper-air wind runs close to the isobars, but near the surface friction slows the wind, so it tends to cross the isobars at an angle and flow into the low.',
          expectedReason:
            'When friction lowers the wind speed, the apparent deflection due to rotation also becomes relatively smaller, leaving a component directed toward low pressure.',
          checkpoint: {
            lure: 'Surface friction speeds up the wind and strengthens the effect of rotation, so wind blows outward from a low.',
            options: {
              'friction-speeds': {
                text: 'Friction speeds up the wind and pushes it from the low-pressure side toward the high-pressure side.',
                hint: 'Think about which way friction normally acts on the speed of motion.',
              },
              'rotation-creates-pressure': {
                text: 'Rotation alone creates lows, and pressure differences do not affect wind direction.',
                hint: 'Separate the force from the pressure difference and the effect that deflects moving air.',
              },
              'surface-crosses-isobars': {
                text: 'Near the surface, where friction lowers wind speed, wind crosses isobars toward the low-pressure side.',
              },
            },
            explanation:
              'Surface friction weakens the wind, so the component toward low pressure from the pressure difference becomes relatively larger.',
          },
          cognitiveTask: {
            items: {
              'cross-to-low': 'Wind crosses the isobars toward the low-pressure side.',
              'surface-friction': 'Surface friction lowers the wind speed.',
              'turning-weakens': 'The deflection due to rotation becomes relatively smaller.',
            },
          },
        },
      },
      story: {
        title: 'Strong-Wind Warning for the Packed-Isobar Zone',
        setting:
          'A weather data room. The students compare isobar spacing on past weather maps with wind speeds observed at the same time.',
        characters: {
          mio: { name: 'Mio', role: 'Observation and safety checks' },
          dekisugi: { name: 'Dekisugi-kun', role: 'Overconfident hypotheses' },
          ren: { name: 'Ren', role: 'Checking conditions and records' },
        },
        openingLines: {
          'pressurePatternsWind.open.1':
            'Area A has lots of isobars packed into the same distance, and its wind speed is high too.',
          'pressurePatternsWind.open.2':
            'The lines aren’t walls—they’re marks on the map connecting points with the same pressure.',
          'pressurePatternsWind.open.3':
            'The low sucks the wind up toward the high—my reverse-pump theory!',
        },
        choiceResponses: {
          'high-to-low':
            'You separated the force from the pressure difference from the effects of rotation and friction.',
          'coriolis-alone':
            'Rotation bends moving air, but it doesn’t replace the pressure difference.',
          'low-to-high': 'I had the wind climbing up the pressure hill!',
        },
        resolutionLines: {
          'pressurePatternsWind.resolve.1':
            'The force from a pressure difference points from the high-pressure side toward the low-pressure side.',
          'pressurePatternsWind.resolve.2':
            'The actual wind direction is also changed by Earth’s rotation and surface friction.',
        },
        punchline:
          'Isobars aren’t “Road Closed” ropes—they’re the contour lines of the wind’s hillside.',
      },
      notation: {
        tasks: {
          'pressurePatternsWind.modelBuild': {
            title: 'Build the cause chain for surface wind',
            prompt: 'Build, in causal order, the chain from a pressure difference to the wind direction near the surface.',
            guide: 'Work through the pressure difference, air motion, the effect of rotation, and friction in order.',
            tokens: {
              gradient: 'Force from the high-pressure side toward the low-pressure side',
              'air-moves': 'Air starts to move',
              rotation: 'Rotation bends its path',
              friction: 'Surface friction slows it',
              'cross-isobar': 'It crosses the isobars at an angle toward low pressure',
            },
            solutionSummary:
              'Surface wind arises from a pressure difference and, affected by rotation and friction, flows at an angle toward low pressure.',
          },
          'pressurePatternsWind.graphRead': {
            title: 'Read isobar spacing',
            prompt: 'With the same surface conditions, choose the area where wind tends to be stronger.',
            representation: [
              'Area A: 1000｜1004｜1008 hPa (10 km between lines)',
              'Area B: 1000  ｜  1004  ｜  1008 hPa (30 km between lines)',
            ],
            representationSemanticsLabel:
              'Pressure changes by 4 hectopascals every 10 kilometers in A and every 30 kilometers in B.',
            choices: {
              'area-a': 'Area A',
              'area-b': 'Area B',
              same: 'Always the same',
            },
            solutionSummary:
              'A has a larger pressure difference over the same distance, so it is the area where wind tends to be stronger.',
          },
          'pressurePatternsWind.labelDiagram': {
            title: 'Read the arrows around a low',
            prompt: 'Choose the typical surface wind flowing toward a low in the Northern Hemisphere.',
            representation: ['       ↙', '   L  Low pressure', '       ↗'],
            representationSemanticsLabel:
              'A diagram with a low, L, at the center; the wind turns counterclockwise as it flows in toward the center.',
            choices: {
              'inward-counterclockwise': 'Counterclockwise and inward',
              'outward-clockwise': 'Clockwise and outward',
              'straight-outward': 'Straight outward in all directions',
            },
            solutionSummary:
              'Around a surface low in the Northern Hemisphere, wind blows counterclockwise into the center.',
          },
        },
      },
    },
  },
}
