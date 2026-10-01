import type { UnitContentText } from '../i18n-content.js'

const CHARACTERS = {
  mio: { name: 'Mio', role: 'Observation and safety checks' },
  dekisugi: { name: 'Dekisugi-kun', role: 'Overconfident hypotheses' },
  ren: { name: 'Ren', role: 'Checking conditions and records' },
}

export const energySocietyContent: UnitContentText = {
  unitId: 'energy-society',
  concepts: {
    energyResources: {
      practice: {
        foundation: {
          recallPrompt:
            'Explain that electricity is made by converting another form of energy, using hydropower and thermal generation as examples.',
          reasoningPrompt:
            'Add what the generator carries over, as the reason that “the power station makes electricity” alone is not enough.',
          expectedOutcome:
            'In hydropower, the water’s potential energy passes through the turbine’s motion energy into electricity; '
            + 'in thermal generation, the fuel’s chemical energy passes through heat and motion energy into electricity.',
          expectedReason:
            'A generator is a device that converts motion energy into electrical energy, so electricity never appears without '
            + 'a source of energy. Energy only changes its form.',
          cognitiveTask: {
            items: {
              'heat-steam': 'Thermal energy turns water into steam',
              'fuel-chemical': 'The fuel’s chemical energy is released by burning',
              'generator-electric': 'The generator converts motion energy into electrical energy',
              'turbine-motion': 'The steam turns a turbine and becomes motion energy',
            },
          },
        },
        conditions: {
          recallPrompt:
            'Explain the difference between exhaustible energy resources and renewable energy, using fossil fuels and solar/wind as examples.',
          reasoningPrompt:
            'Add one more angle beyond “whether it runs out”: the amount of carbon dioxide emitted, or the viewpoint of self-sufficiency.',
          transferPrompt:
            'In one country’s generation mix, thermal generation (fossil fuels) makes up most of it, while solar and wind '
            + 'are slowly increasing. Explain what is happening in terms of the nature of the resources.',
          expectedOutcome:
            'Fossil fuels are exhaustible resources that shrink with use, while solar and wind are renewable energy that can be '
            + 'used repeatedly, so the shift in the mix is a choice made with the finiteness of resources in mind.',
          expectedReason:
            'Exhaustible resources have limited reserves and will become unusable in the future, whereas renewable energy is '
            + 'obtained again and again from natural flows. The amounts of carbon dioxide emitted differ as well.',
          checkpoint: {
            lure: 'Renewable energy never runs out, so no matter how much we use, we can keep increasing the amount generated.',
            options: {
              'renewable-output-limited': {
                text: 'Even with renewable energy, natural conditions and the scale of facilities set the amount generated, so there is a limit.',
              },
              'unlimited-solar': {
                text: 'Sunlight keeps arriving without limit, so panels can generate as much as we need.',
                hint: 'Think about whether the amount generated is set by natural conditions and facility scale, or only by the amount of resource.',
              },
              'fossil-better': {
                text: 'Fossil fuels generate more stably, so there is no point in switching to renewable energy.',
                hint: 'Think about whether the reason for switching is only generation stability, or also includes resource finiteness and emissions.',
              },
            },
            explanation:
              'Renewable energy can be used again and again, but the amount generated is set by natural conditions such as '
              + 'sunlight and wind and by the scale of the facilities, so we cannot make as much as we want without limit.',
          },
          cognitiveTask: {
            items: {
              'renewable-limited': 'Renewable energy never runs out, so building more facilities lets us generate without limit.',
              'output-conditions': 'The amount generated is set by natural conditions and facility scale, so there is an upper limit even when the resource never runs out.',
              'fossil-replenish': 'Fossil fuels keep being made underground, so they are effectively renewable energy.',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Explain that energy conversion involves loss, using the fact that in thermal generation not all of the fuel’s chemical energy becomes electricity.',
          reasoningPrompt:
            'Add that saving energy is a matter of cleverness on the “using side”, not only on the “producing side”.',
          transferPrompt:
            'For the same amount of generation, an inefficient method needs more fuel while an efficient one needs less. '
            + 'Explain the effect of this difference on resources and on the environmental load.',
          expectedOutcome:
            'The higher the conversion efficiency, the less fuel is needed for the same generation, so resource consumption '
            + 'and the environmental load such as carbon dioxide emissions both fall.',
          expectedReason:
            'In conversion, part of the energy changes into heat we cannot use, so lower-efficiency conversion loses more '
            + 'and consumes more resources.',
          checkpoint: {
            lure: 'An efficient generation device can convert 100% of the fuel’s energy into electricity.',
            options: {
              'all-energy-electric': {
                text: 'A high-performance generator turns all of the fuel’s chemical energy into electricity.',
                hint: 'Think about whether any part of the energy changes into a form we cannot use.',
              },
              'loss-becomes-nothing': {
                text: 'The energy lost in conversion disappears, so efficiency does not matter.',
                hint: 'Distinguish between energy disappearing and energy changing into an unusable form.',
              },
              'less-fuel-same-output': {
                text: 'For the same generation, a more efficient method needs less fuel and reduces both resources and emissions.',
              },
            },
            explanation:
              'In conversion, part of the energy changes into heat we cannot use. The higher the efficiency, the smaller '
              + 'the loss and the less resource is needed to get the same electricity.',
          },
          cognitiveTask: {
            items: {
              'oil': 'Oil',
              'solar': 'Sunlight',
              'natural-gas': 'Natural gas',
              'geothermal': 'Geothermal heat',
            },
            targets: {
              exhaustible: 'Exhaustible resource',
              renewable: 'Renewable energy',
            },
          },
        },
      },
      story: {
        title: 'The Case of the Missing Ingredients at the Electricity Factory',
        setting:
          'A resource shelf in the science prep room. A pie chart of “generation shares by method” and one month’s electricity bill sit open.',
        characters: CHARACTERS,
        openingLines: {
          'energyResources.open.1':
            'The bill’s power-source breakdown shows thermal generation at more than half. It lists the energy resources behind generation.',
          'energyResources.open.2':
            'Thermal converts the fuel’s chemical energy; hydro converts the water’s potential energy. I’ll record the conversion paths.',
          'energyResources.open.3':
            'A power station is a factory that manufactures electricity! Order as much as you like!',
        },
        choiceResponses: {
          'manufacture-unlimited':
            'Output is unlimited! ...But a factory can’t run without materials. Wait, what?',
          'conversion-limited':
            '“Conversion” is the right word. The amount of resource and the efficiency decide how much can be made.',
          'thermal-only-source':
            'The record also shows electricity from solar panels and windmills. Thermal isn’t the only source.',
        },
        resolutionLines: {
          'energyResources.resolve.1':
            'Generation is a conversion of energy. Fuel, water, wind, and light change their form into electricity.',
          'energyResources.resolve.2':
            'Renewable energy that never runs out and exhaustible resources that run dry ask for different choices.',
        },
        punchline:
          'Electricity’s raw ingredient turns out to be “energy”! Factory manager, the orders go through planet Earth!',
      },
      notation: {
        tasks: {
          'energyResources.sequence': {
            title: 'Order the conversions of hydropower',
            prompt:
              'Reorder how dam water becomes electricity into the order the energy conversions happen.',
            guide:
              'The order runs from potential energy through motion energy to the generator making electrical energy.',
            tokens: {
              'potential': 'Water at a high position holds potential energy',
              'falling': 'The water falls and becomes motion energy',
              'turbine': 'The water wheel turns and passes on motion energy',
              'generator': 'The generator converts motion energy into electrical energy',
            },
            solutionSummary: 'The order is potential energy → motion energy → water wheel → generator.',
          },
          'energyResources.tableRead': {
            title: 'Read the table of generation shares',
            prompt:
              'From a table of a country’s generation shares by method, choose the correct reading.',
            representation: [
              'Generation method | Share | Nature of the resource',
              'Thermal | about 70% | Fossil fuels (exhaustible)',
              'Hydropower | about 10% | Renewable',
              'Solar and wind | growing | Renewable',
            ],
            representationSemanticsLabel:
              'Most generation depends on exhaustible resources such as fossil fuels.',
            choices: {
              'fossil-renewable': 'Fossil fuels are a renewable energy',
              'main-fossil': 'Most generation depends on exhaustible resources such as fossil fuels',
              'all-renewable': 'All generation is covered by renewable energy',
            },
            solutionSummary:
              'Thermal generation has the largest share, which shows a large dependence on exhaustible resources.',
          },
          'energyResources.symbolMatch': {
            title: 'Pick the equation that shows energy conversion',
            prompt:
              'Choose the equation that correctly represents generation as an energy conversion.',
            representation: [
              'Conversion arrow | Meaning',
              'Another energy → electricity | The work of generation',
            ],
            representationSemanticsLabel:
              'Electricity is not newly created; another energy changes its form.',
            choices: {
              'conversion-chain': 'Chemical energy → thermal and motion energy → electrical energy',
              'creation': 'Generator → electrical energy is newly created',
              'electric-stored': 'Fuel + electricity → stored electricity',
            },
            solutionSummary:
              'Generation is a process that converts chemical or motion energy into electricity.',
          },
        },
      },
    },
    natureBalance: {
      practice: {
        foundation: {
          recallPrompt:
            'Explain eat-and-be-eaten relationships and the role of decomposers, using the words producer, consumer, and decomposer.',
          reasoningPrompt:
            'Add one example of carbon moving in and out, as part of matter circulating between living things and the inorganic environment.',
          expectedOutcome:
            'Plants make organic matter by photosynthesis, consumers eat it, and decomposers return remains and droppings '
            + 'to inorganic matter, so matter circulates between living things and the environment.',
          expectedReason:
            'Matter circulates through the links of producers, consumers, and decomposers; carbon enters living things by '
            + 'photosynthesis and returns to the environment as carbon dioxide through respiration and decomposition.',
          cognitiveTask: {
            items: {
              'cascade-effect': 'When the water plants decline, the fish that eat them decline too, and the carnivorous fish that eat those fish change as well.',
              'quick-other-food': 'If the water plants decline, the fish quickly find other food, so nothing else is affected.',
              'only-producer': 'Only the producers are affected, and the consumers’ numbers stay the same.',
            },
          },
        },
        conditions: {
          recallPrompt:
            'Explain how the balance of nature is kept by the mutual influence between the eaters and the eaten.',
          reasoningPrompt:
            'Add an example where the effect of one species suddenly increasing or decreasing propagates through the food web.',
          transferPrompt:
            'A record from one lake shows fish that eat water plants increasing and the water plants decreasing, '
            + 'with those fish decreasing the next year. Explain this change in the language of balance.',
          expectedOutcome:
            'More fish reduced the water plants, and the fish then declined for lack of food, so the numbers of eaters and eaten '
            + 'influence each other and are kept roughly constant.',
          expectedReason:
            'An increase in the eaten adds food for the eaters, and when the eaten decline the eaters decline too. '
            + 'This mutual influence is the balance of nature.',
          checkpoint: {
            lure: 'Even if the eaten side’s numbers fall, the eaters quickly find other food, so it has no effect.',
            options: {
              'mutual-numbers': {
                text: 'When the eaten decline the eaters decline, and when the eaters decline the eaten increase — the numbers influence each other.',
              },
              'switch-prey-instant': {
                text: 'The eaters can immediately find other food, so their numbers do not change.',
                hint: 'Think about whether enough food alternatives exist and whether links carry changes in numbers.',
              },
              'plants-unlimited': {
                text: 'Producers can increase without limit, so the eaten side never declines.',
                hint: 'Think about the conditions — light and nutrients — that keep producers from increasing without limit.',
              },
            },
            explanation:
              'The eaters and the eaten influence each other’s numbers. A change on one side propagates through the food web '
              + 'to the other side, keeping the balance.',
          },
          cognitiveTask: {
            items: {
              'green-plant': 'A plant that photosynthesizes',
              'rabbit': 'A rabbit that eats grass',
              'fungi': 'Fungi that decompose dead matter',
              'hawk': 'A hawk that eats rabbits',
            },
            targets: {
              producer: 'Producer',
              consumer: 'Consumer',
              decomposer: 'Decomposer',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Explain an example where human activity changes the balance of nature, choosing from development, pollution, or introduced species.',
          reasoningPrompt:
            'Add an example where the recovery power of the balance has a limit, so “it will return” cannot be said for sure.',
          transferPrompt:
            'A record from one forest shows development proceeding, birds declining first, and insects increasing afterwards. '
            + 'Explain this change in terms of the food web and the limit of the balance.',
          expectedOutcome:
            'Development reduced the birds’ habitat and the insects the birds had been eating increased, so the influence is '
            + 'propagating through the links — a change that is hard to reverse.',
          expectedReason:
            'One change on the links of a food web alters the numbers of other living things in a chain. The loss of a habitat '
            + 'is a large change that can exceed the balance’s power to recover.',
          checkpoint: {
            lure: 'Nature has the power to return, so living things lost through human influence are sure to come back.',
            options: {
              'balance-no-limit': {
                text: 'Nature’s power of recovery is limitless, so even extinct species will return eventually.',
                hint: 'Think about whether an extinct species can come back through nature’s own power.',
              },
              'cascade-impact': {
                text: 'A large change can exceed the power to recover, and a lost species or environment may never return.',
              },
              'humans-only-threat': {
                text: 'Only humans break the balance, so if humans stay away nature does not change.',
                hint: 'Think about whether there are factors other than humans that change nature.',
              },
            },
            explanation:
              'The balance has a power to recover, but it has limits. A species that went extinct or an environment that '
              + 'changed greatly cannot return by nature’s power alone.',
          },
          cognitiveTask: {
            items: {
              'birds-gone-insects-same': 'Even if the birds decline, the insects’ numbers stay the same.',
              'balance-instant': 'If the birds decline, nature returns things at once, so the insects’ numbers stay constant.',
              'insects-increase': 'The birds that were eating them declined, so the insects that were being eaten increase.',
            },
          },
        },
      },
      story: {
        title: 'The Pond Census: A Chain Reaction Case',
        setting:
          'Survey records of the living things in a pond near the school. Counts of water plants, herbivorous fish, and carnivorous fish cover three years.',
        characters: CHARACTERS,
        openingLines: {
          'natureBalance.open.1':
            'In year two, the herbivorous fish increased and the water plants declined. In year three, the herbivorous fish declined and the plants came back.',
          'natureBalance.open.2':
            'The record shows the eaters’ and the eaten’s numbers influencing each other and fluctuating.',
          'natureBalance.open.3':
            'Nature returns things on its own, so even if the plants hit zero it would have been fine!',
        },
        choiceResponses: {
          'recover-anyway':
            'Unlimited recovery power, adopted! ...But an extinct species never comes back, does it?',
          'only-humans-change':
            'Even without humans, typhoons and climate shifts move the balance.',
          'linked-balance':
            'Balance on top of links, and recovery has a limit. That is how to read this record.',
        },
        resolutionLines: {
          'natureBalance.resolve.1':
            'The food web and the decomposers circulate matter and keep the balance.',
          'natureBalance.resolve.2':
            'So one change propagates down the chain. Environmental surveys are a way to catch those changes early.',
        },
        punchline:
          'The pond census was a “chain notice”! Sorry I left you hanging, water plants!',
      },
      notation: {
        tasks: {
          'natureBalance.modelBuild': {
            title: 'Assemble the path of material cycling',
            prompt:
              'Assemble, step by step, the path by which carbon circulates in the pond ecosystem.',
            guide:
              'It is taken in by photosynthesis, passed on by eating, and returned to inorganic matter by decomposition.',
            tokens: {
              'co2-uptake': 'Plants take in carbon dioxide by photosynthesis',
              'eating': 'Consumers eat organic matter and move it into their bodies',
              'decomposition': 'Decomposers return remains and droppings to inorganic matter',
              'return': 'Carbon dioxide and nutrients return to the environment',
            },
            solutionSummary: 'The cycle is uptake → eating → decomposition → return to the environment.',
          },
          'natureBalance.tableRead': {
            title: 'Read the record of population counts',
            prompt:
              'From a three-year record of water plants, herbivorous fish, and carnivorous fish in a pond, choose the correct reading.',
            representation: [
              'Year | Water plants | Herbivorous fish | Carnivorous fish',
              'Year 1 | many | average | few',
              'Year 2 | declining | increasing | average',
              'Year 3 | recovering | declining | increasing',
            ],
            representationSemanticsLabel:
              'The numbers of the eaters and the eaten fluctuate while influencing each other.',
            choices: {
              'one-direction': 'The numbers only increase one way, with no mutual influence',
              'mutual-balance': 'The numbers of eaters and eaten influence each other and fluctuate',
              'no-relation': 'The changes in the three species’ numbers are unrelated',
            },
            solutionSummary:
              'The eaters’ numbers change after the eaten’s numbers — a record of a working balance.',
          },
          'natureBalance.symbolMatch': {
            title: 'Pick the equation that shows the balance',
            prompt:
              'Choose the equation that correctly represents how the balance of nature works.',
            representation: [
              'Factor | Result',
              'Links | Fluctuation of numbers',
            ],
            representationSemanticsLabel:
              'Food-web links and material cycling keep the numbers of living things in balance.',
            choices: {
              'web-balance': 'Food-web links + material cycling → balance of numbers',
              'independent': 'Each species’ numbers → change independently of each other',
              'unlimited-growth': 'If food is available → they keep increasing without limit',
            },
            solutionSummary:
              'The balance is a result of links and cycling; individual numbers are not decided independently.',
          },
        },
      },
    },
    sustainableSociety: {
      practice: {
        foundation: {
          recallPrompt:
            'Explain why we cannot stop natural disasters from occurring, and how scientific preparation can reduce the damage.',
          reasoningPrompt:
            'Add the point that the approach is not “stop it from happening” but “predict where it happens and what the damage will be, and prepare”.',
          expectedOutcome:
            'Earthquakes and typhoons occur through natural activity inside Earth and in the atmosphere, so we cannot stop '
            + 'them from happening, but observation and forecasting, structures, and planning can reduce the damage.',
          expectedReason:
            'The energy of disasters exceeds what humans can stop, but records and observation data let us predict dangerous '
            + 'places and how events unfold, and we can prepare with earthquake-resistant structures and evacuation plans.',
          cognitiveTask: {
            items: {
              'identify-risk': 'Predict the dangerous places and the damage likely to occur',
              'prepare': 'Prepare with structures and evacuation plans',
              'collect-records': 'Collect past disaster records and observation data',
              'make-map': 'Show it on a hazard map and share it',
            },
          },
        },
        conditions: {
          recallPrompt:
            'Explain what a hazard map shows and how it is made, using past disaster records and observation data.',
          reasoningPrompt:
            'Add that evacuation routes and evacuation sites are decided on the basis of scientific data.',
          transferPrompt:
            'A town’s hazard map marks only the riverside area as having a high flood risk, while the upland residential area '
            + 'is marked low. Explain the data behind this difference.',
          expectedOutcome:
            'From records of past floods, terrain and elevation, and observed rainfall, the riverside is predicted to be a '
            + 'high-risk area prone to flooding and the uplands to be low risk.',
          expectedReason:
            'A hazard map is built by predicting where and what kind of damage is likely to occur, on the basis of past '
            + 'disaster records and observations of terrain and weather.',
          checkpoint: {
            lure: 'A hazard map is a map that accurately prophesies future disasters, so disasters are certain to occur in the marked danger zones.',
            options: {
              'prophecy-map': {
                text: 'A hazard map’s danger zones mark places where a disaster is certain to occur.',
                hint: 'Think about the difference between a prediction and a prophecy — preparation based on an uncertain forecast.',
              },
              'safe-zone-guaranteed': {
                text: 'A place marked low risk is absolutely safe, so no preparation is needed.',
                hint: 'Think about the difference between a low risk and no damage occurring.',
              },
              'data-based-risk': {
                text: 'A hazard map is a prediction based on past records and observation data — a map for preparation that shows where damage is likely.',
              },
            },
            explanation:
              'A hazard map shows places predicted to be dangerous, from past disaster records and observation data. '
              + 'It is not a prophecy that things will certainly happen, but a scientific guide for deciding preparations.',
          },
          cognitiveTask: {
            items: {
              'exact-prophecy': 'A disaster is certain to occur in a danger zone, and never occurs in a safe zone.',
              'risk-estimate': 'A prediction based on past records and data, showing how likely damage is.',
              'guessing-map': 'A map colored by residents’ intuition, with no scientific basis.',
            },
          },
        },
        transfer: {
          recallPrompt:
            'Explain what a sustainable society is: a society with low environmental load where future generations can keep using resources.',
          reasoningPrompt:
            'Add one concrete choice that reduces environmental load, such as renewable energy or saving energy.',
          transferPrompt:
            'One region is shifting from fossil fuels to solar and wind while advancing energy savings. Explain why this '
            + 'moves toward a sustainable society, in terms of both resources and environmental load.',
          expectedOutcome:
            'Switching to renewable energy reduces the consumption of exhaustible resources and reduces emitted carbon dioxide, '
            + 'so it approaches sustainability on both the resource and the environmental-load sides.',
          expectedReason:
            'Fossil fuels are finite and emit a lot, whereas renewable energy can be used repeatedly with low emissions, '
            + 'and saving energy reduces the amount needed in the first place.',
          checkpoint: {
            lure: 'A sustainable society arrives automatically once science and technology advance, so individual choices do not matter.',
            options: {
              'tech-only-solution': {
                text: 'A sustainable society is only a technology problem, so there is no need to think about people’s choices.',
                hint: 'Think about whether technology alone decides how resources are used and which choices are made.',
              },
              'choices-and-tech': {
                text: 'Both advancing technology and the choices of individuals and society reduce environmental load and bring sustainability closer.',
              },
              'return-to-nature': {
                text: 'A sustainable society means abandoning all technology and returning to nature.',
                hint: 'Check what sustainability means — weighing both convenience and environmental load.',
              },
            },
            explanation:
              'A sustainable society is realized when technology such as renewable energy and efficiency is combined with '
              + 'the decisions of society and individuals about how resources are used.',
          },
          cognitiveTask: {
            items: {
              'renewable-switch': 'Switching from fossil fuels to renewable energy',
              'mass-fossil': 'Keeping the same share of fossil fuels in the future',
              'efficiency-up': 'Energy savings and better conversion efficiency',
              'unchanged-use': 'Leaving the way we use things unchanged',
            },
            targets: {
              'sustainable-choice': 'A sustainable choice',
              'unsustainable-choice': 'A choice that is not sustainable',
            },
          },
        },
      },
      story: {
        title: 'The Case of the Typhoon-Eraser Blueprint',
        setting:
          'A disaster-preparedness study room. A regional hazard map and a record of past flooding sit open.',
        characters: CHARACTERS,
        openingLines: {
          'sustainableSociety.open.1':
            'Flood risk is high along the river and low on the uplands — a prediction built from past records and terrain data.',
          'sustainableSociety.open.2':
            'It even lists evacuation routes. If we can predict it, we can prepare with structures and plans.',
          'sustainableSociety.open.3':
            'If we build a device that erases typhoons with science power, we won’t need a hazard map! Here’s the blueprint!',
        },
        choiceResponses: {
          'mitigate-not-prevent':
            'Instead of stopping it from happening, the idea is to observe and predict to keep the damage small.',
          'stop-disasters':
            'The energy of an earthquake or typhoon is beyond anything humans can stop. Where would the device get its power?',
          'technology-fixes-all':
            'Technology solves everything and we do nothing! ...Wait, the resources run out first?',
        },
        resolutionLines: {
          'sustainableSociety.resolve.1':
            'Not stopping it, but preparing for it. Observation, warnings, structures, and plans make the damage smaller — that is mitigation.',
          'sustainableSociety.resolve.2':
            'A sustainable society also reduces environmental load through both technology and our choices.',
        },
        punchline:
          'The typhoon-eraser project is cancelled! The hazard map and the evacuation plan — my brilliant idea was “prepare” all along!',
      },
      notation: {
        tasks: {
          'sustainableSociety.sequence': {
            title: 'Order the steps of disaster preparation',
            prompt:
              'Reorder how past records become a hazard map and preparation, into the order things happen.',
            guide:
              'Records and observation → predicting risk → sharing on a map → preparing with structures and plans.',
            tokens: {
              'collect-records': 'Collect past disaster records and observation data',
              'identify-risk': 'Predict the dangerous places and how likely damage is',
              'map-share': 'Show it on a hazard map and share it',
              'prepare': 'Prepare with structures and evacuation plans',
            },
            solutionSummary: 'The order is records → prediction → sharing → preparation.',
          },
          'sustainableSociety.graphRead': {
            title: 'Read the trend of carbon dioxide concentration',
            prompt:
              'From a graph of the trend of atmospheric carbon dioxide concentration, choose the correct reading.',
            representation: [
              'Year | CO₂ concentration',
              '1960 | about 320 ppm',
              '2000 | about 370 ppm',
              '2020 | about 415 ppm',
            ],
            representationSemanticsLabel:
              'The concentration is rising over the long term as emissions accumulate.',
            choices: {
              'co2-flat': 'The concentration has stayed constant over the long term',
              'co2-falling': 'The concentration has turned to a decline in recent years',
              'co2-rising': 'The concentration is rising over the long term and emissions are accumulating',
            },
            solutionSummary:
              'The observed rise in concentration shows that emissions are accumulating.',
          },
          'sustainableSociety.symbolMatch': {
            title: 'Pick the equation for a sustainable society',
            prompt:
              'Choose the equation that correctly represents the conditions for approaching a sustainable society.',
            representation: [
              'Element | Relation',
              'Technology and choices | Environmental load',
            ],
            representationSemanticsLabel:
              'Technology plus choices about how resources are used together reduce the environmental load.',
            choices: {
              'tech-alone': 'Advancing technology alone → automatically sustainable',
              'tech-plus-choice': 'Advancing technology + choices about resource use → less environmental load',
              'stop-progress': 'Abandoning all technology → sustainable',
            },
            solutionSummary:
              'A sustainable society is realized through both technology and the choices of society and individuals.',
          },
        },
      },
    },
  },
}
