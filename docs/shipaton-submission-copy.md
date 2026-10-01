# Devpost submission copy — Next Gen Award

English draft for the current native build. Replace the video URL placeholder
with a public YouTube/Vimeo URL before submitting.

## Project name

Dekisugi-kun

## Tagline

Don't just recognize the answer. Teach the science.

## Inspiration

“Heavier things always fall faster.” It sounds plausible until you have to
explain a feather and a hammer falling together on the Moon. Recognizing an
answer and explaining its conditions are different tasks. I built Dekisugi-kun
around that gap: the learner teaches a companion that needs their explanation,
then tests the idea in another situation.

## What it does

The central interaction is a teach-back loop for middle and high-school science.
The learner predicts an outcome, reads a
focused lesson, and then explains it with the material hidden. Text is a full
learning route alongside voice. The learner rereads or replays their explanation
before the companion asks a fixed follow-up from the lesson catalog.

Key-term coverage prompts reflection; it does not claim to grade understanding.
A wrong choice brings a hint and another explanation, rather than an answer to
copy. The companion's misconception record keeps uncertain ideas available for
a matching repair activity. Rewriting alone does not mark a need corrected.

This is a working native Field Notebook app, with 12 science units and 35 concepts, story
cases, diagram activities and review. Core learning works on-device without an
account. In the demonstrated route, free explanation text and voice are neither
uploaded nor retained as durable records.

A free understanding check makes the reasoning inspectable: three questions
before teaching, three different questions afterward, and a new situation. It
asks the learner to explain the principle and apply it under changed conditions.
Answers and explanations disappear on leaving the screen. Optional copying
exports aggregate counts only.

## How I built it

Flutter provides the native app, with a bundled Japanese/English curriculum and
SQLite-backed progress. The TypeScript/Vercel server serves the same catalog.
Fixed catalog checkpoints and canonical need codes connect an observed gap to
an appropriate repair activity; no external LLM grades student writing.

RevenueCat's `purchases_flutter` SDK provides store packages, purchase, restore
and the `plus` entitlement. The payer's job is concrete: “What should we review,
and what should I ask?” Plus adds a local family review plan that selects a topic,
explains why it was selected, supplies a parent question, and changes one condition
to test transfer. The report can be copied without answer text, audio or personal
scores. Aurora Cape adds a visible supporter benefit. Core lessons, text, review
and understanding checks stay free.

The video shows a native RevenueCat Test Store purchase and the family report in
a separate adult test profile. No real charge occurred. Family review is a local
plan and shareable report, not cloud-linked parent/child accounts. The current
supporter grant is retained after a subscription lapses; I do not claim that
recurring willingness to pay has been validated.

The repository includes the product constitution, tests, native run
instructions, English submission assets, and reproducible capture/edit tools.
The demo uses actual native Android emulator interactions, edited for pace,
with separate locally generated English narration and captions.

## Challenges

The important design challenge was making the learner do the explaining while
keeping the companion helpful. Hiding the material, requiring a reread/replay,
and giving a condition hint after a miss make that choice visible in the UI.

Another challenge was matching claims to what the build actually does. External
live AI stays disabled in production while the minor-safe provider path remains
unresolved. Text supports the complete learning route. A key-term match is not
reported as mastery, and an observed need remains open until its matching repair
activity resolves it.

The purchase route uses store-supplied prices and billing terms, rather than
invented trial promises. The current monetization claim is the demonstrated
supporter benefit; production-store revenue and live-conversation allowance
sync are not claimed.

## Accomplishments

A working native learning loop connects prediction, evidence, explanation,
follow-up, hints and review. The current interface makes the companion's record
part of the experience. Plus now answers a practical family-review question,
while the complete learning loop remains free. The updated app passed 1,340
client tests; the unchanged server baseline passed 399 tests.
The entry's video demonstrates the real app within two minutes.

## What I learned

The most useful product constraint was to ask what the learner must actually
do, rather than how much the companion can say. That led to hidden-source
explanations, equal text access, explicit rereading, fixed questions, and payment
that supports the app without buying the learning outcome.

## What's next

Extend the science curriculum, refine delayed review, and run classroom pilots
that compare explanations and transfer to new situations. Complete physical-device
recording/playback and permission QA. External AI will remain disabled for school/minor
distribution until the provider and consent requirements are resolved.

## Why Next Gen

This entry focuses on a clear product idea and meaningful progress toward a
working native app: a learner produces an explanation, applies the conditions,
and keeps uncertain ideas available for review. The demo shows the actual
interaction; the MIT repository exposes the implementation and its product
constitution. RevenueCat supports a specific family convenience while keeping
core learning free. Native interaction, offline access, equal text access, and
restrained data collection are deliberate product choices.

## RevenueCat integration / additional information

- Android package / application ID: **`jp.dekisugi.dekisugi`**
- SDK: **`purchases_flutter`**; entitlement: **`plus`**.
- Demo transaction: **RevenueCat Test Store, no real charge**.
- Purchase/restore adapter: `app/lib/services/revenuecat_purchase_adapter.dart`.
- Native run and Test Store replay: [reviewer guide](nextgen-review-guide.md).
- Server re-verification and webhook are implemented; production-store purchase
  and live-conversation allowance sync are not claimed.
- No store release is required for this Next Gen entry. The app has English curriculum, UI and accessibility descriptions; the demo
  and submission explanation are in English.

## Submission assets

- Source: https://github.com/Haruka-Kaya/dekisugi-kun — MIT.
- **Video URL:** `[PUBLIC YOUTUBE OR VIMEO URL — REQUIRED BEFORE SUBMIT]`
- Video file: [shipaton-demo-v13.mp4](shipaton-demo-2026/shipaton-demo-v13.mp4), 67.4 seconds.
- Captions: [English SRT](shipaton-demo-2026/shipaton-demo-v13-captions.en.srt).
- Icon: `docs/store/icon-1024.png` — 1024×1024.
- Screenshot: `docs/store-shots-2026/devpost/shot-1179x2556.png` — current native
  app, 1179×2556, no device frame.
- Confirm active student eligibility, qualifying academic account email, and
  guardian consent if applicable. These are personal eligibility requirements,
  not facts established by the code or video.
