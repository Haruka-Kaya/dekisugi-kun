# Learning evidence and evaluation status

**Product efficacy study: not conducted; no learner pre/post results are available.**
The 18-response elicitation survey concerns misconception/question design. It is
not evidence that using this app improves learning. Automated tests and developer
emulator demonstrations show implementation behavior, not learner outcomes.

## Why the learning mechanism is plausible

The app requires an explanation with the material hidden, then asks a fixed
question about conditions or a new situation. This makes retrieval and application
observable instead of treating a key-term match as mastery.

Sana and Yan (2022), *Interleaving Retrieval Practice Promotes Science Learning*,
examined classroom science quizzes and a delayed test. Their experiment supports
retrieval practice as a design rationale in science education. It does not evaluate
Dekisugi-kun, prove the benefit of an AI companion, or establish an effect size for
this product. [Primary research paper](https://doi.org/10.1177/09567976211057507).

## What can be verified in this build

| Mechanism | Inspectable behavior | What it does not establish |
|---|---|---|
| Retrieval | The teaching phase hides the lesson before explanation | Correct independent understanding |
| Feedback and application | Fixed, condition-sensitive checkpoint; a miss brings a hint and retry | Valid assessment of free explanation text |
| Review support | Unresolved observations remain visible; Plus creates parent prompts and a next topic locally | That payment improves learning |
| Free before/after check | Settings → Understanding check: 3 before items, read/hide/teach, 3 different after items, 1 transfer item | Equal form difficulty, causality or lasting retention |
| Privacy | Check answers, explanation and counts exist only in screen memory; optional copy exports aggregate counts | A collected learner dataset |

The self-check is versioned `fall-check-v1`. Correct responses are withheld until
all questions are completed. Fixed feedback follows the explanation; it is clearly
identified as fixed feedback, not automated grading. No learner text or scores are
written to the progress store or sent over a network. Leaving the screen discards
the session. A copied result is user-controlled and is not automatically research
consent or a study enrollment. Developer test counts must never be presented as
learner results.

## Prospective study protocol (not executed)

1. Obtain appropriate participant/guardian consent and school authorization;
   use on-device learning with external generative AI disabled. Follow the
   [learner pilot privacy boundaries](learner-pilot-2026.md).
2. Have an independent science teacher review content validity, ambiguity and
   reading level. Pilot and calibrate alternate forms before interpreting gains.
3. Pre-register the primary outcome: a delayed, held-out explanation/transfer
   assessment scored blind to condition with a predefined rubric. Measure
   principle, conditions and reasoned prediction separately.
4. Randomly assign an adequately powered sample to the teach-back loop or a
   matched-duration active control using the same material. Counterbalance forms.
   Keep assistance, time and exposure comparable; specify exclusions in advance.
5. Report recruitment, consent, completion and attrition, item/form performance,
   blinded scoring agreement, uncertainty intervals and missing-data handling.
   Retain anonymous aggregates only. The current small self-check is a formative
   exercise, not a substitute for this study.

No improvement percentage, efficacy conclusion, participant count or classroom
adoption claim is made for Dekisugi-kun. These remain future evaluation work.
