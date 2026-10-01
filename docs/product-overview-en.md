# Dekisugi-kun — product overview

**Learn science by teaching a companion.** For middle and high-school science,
Dekisugi-kun makes explaining an idea part of studying it. The companion asks
for the learner's reasoning instead of giving the answer first.

See the [reviewer guide](nextgen-review-guide.md) for the video, native run
instructions, RevenueCat replay, and criterion-to-code evidence.

## One idea, through a complete learning loop

The learner first predicts what happens in a concrete science case, then reads
a short lesson covering the principle and its conditions. The material is
hidden while the learner explains in their own words. Text is a complete route
alongside voice; the learner must reread text or replay voice before continuing.

On-device key-term coverage is a reflection aid, not a semantic score or proof
of mastery. A fixed catalog follow-up asks the learner to apply the idea. A
wrong choice records a cataloged need, offers a condition or reasoning hint,
and asks for another explanation.

The companion's misconception record keeps observed uncertainty available for
review. A matching repair activity can resolve a need. Merely rewriting a free
explanation does not mark it corrected. The record is framed as the companion's
beliefs, not a diagnosis of the student's weakness.

## Product choices

- **Close the material:** make retrieval and explanation visible actions.
- **Keep text equal to voice:** learning can continue without a microphone.
- **Use fixed checkpoints:** avoid claiming an external model can grade a
  learner's free explanation reliably.
- **Keep the core on-device:** no account or external AI connection is needed.
  The demonstrated route does not upload or persist free explanation text or
  voice; durable learning records use catalog IDs, need codes and progress.
- **Make payment optional:** sell supporter benefits while core lessons remain
  available. Do not sell answers, automatic correction, or learning progress.

These choices are pinned by the [C1–C9 constitution](../AGENTS.md). They are
informed by learning research and expressed as concrete learner actions.

## RevenueCat

The native `purchases_flutter` SDK handles packages, purchases, restore and the
`plus` entitlement. The paywall uses store-returned prices and periods rather
than invented prices. The current demo shows a completed RevenueCat Test Store
purchase and an unlocked parent report. Plus adds
a local family review plan: next topic, selection reason, parent prompt and a
new-situation check. No real
charge occurred. The cosmetic grant remains in the local grant ledger.

Server-side entitlement re-verification and webhook code also exist, but the
video does not claim a successful production purchase or conversation-allowance
sync. Live conversation remains disabled. The optional remote companion-line
research path is not enabled or demonstrated. See
[monetization setup](monetization-setup.md) and [age restrictions](age-restriction.md).

## Inspecting learning usefulness

Settings includes a free on-device understanding check: three before items,
a hidden-source explanation, three different after items and a transfer item.
The learner explains the principle, then applies it under changed conditions.
No answers or scores are saved or sent. An optional copy exports counts only.

## Build and current scope

The native Flutter app has a Field Notebook interface across exploration,
science cases, experiments, diagrams, shared observations and My Lab. Its
bundled Japanese/English curriculum contains **12 units and 35 concepts**.
The curriculum, primary and secondary learning UI, and accessibility descriptions
are available in English. The TypeScript/Vercel server serves
the catalog and implements optional server integrations.

The integrated baseline passed **1,340 app tests and 399 server tests**.
The native Android footage demonstrates the complete text learning route on an
emulator. Physical-device voice QA is the next device-validation step. Source
is licensed under [MIT](../LICENSE).
