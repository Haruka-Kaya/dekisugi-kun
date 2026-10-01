# Devpost submission copy — Next Gen Award

English draft for the current native build. Replace the video URL placeholder
with a public YouTube/Vimeo URL before submitting. Do not invent eligibility,
revenue, downloads, school use, or measured learning gains.

## Project name

Dekisugi-kun

## Tagline

Learn science by teaching a companion.

## Inspiration

Recognizing a correct answer and explaining why it works are different tasks.
I wanted a study experience where producing an explanation is the central
action. Dekisugi-kun gives the learner a companion to teach, a concrete science
question to reason about, and another case that tests the conditions of the idea.

## What it does

For middle and high-school science, the learner predicts an outcome, reads a
focused lesson, and then explains it with the material hidden. Text is a full
learning route alongside voice. The learner rereads or replays their explanation
before the companion asks a fixed follow-up from the lesson catalog.

Key-term coverage prompts reflection; it does not claim to grade understanding.
A wrong choice brings a hint and another explanation, rather than an answer to
copy. The companion's misconception record keeps uncertain ideas available for
a matching repair activity. Rewriting alone does not mark a need corrected.

The native Field Notebook app includes 12 science units and 35 concepts, story
cases, diagram activities and review. Core learning works on-device without an
account. In the demonstrated route, free explanation text and voice are neither
uploaded nor retained as durable records.

An optional free understanding check compares three before questions, three
different after questions, and one new situation around a hidden-source teaching
activity. It is a formative self-check, not a validated efficacy test. Answers,
explanation and counts are neither saved nor uploaded; copying aggregate counts
is the learner's choice. The app does not claim that a count difference proves
improvement.

## How I built it

Flutter provides the native app, with a bundled Japanese/English curriculum and
SQLite-backed progress. The TypeScript/Vercel server serves the same catalog.
Fixed catalog checkpoints and canonical need codes connect an observed gap to
an appropriate repair activity; no external LLM grades student writing.

RevenueCat's `purchases_flutter` SDK provides store packages, purchase, restore
and the `plus` entitlement. Plus is optional: a family review plan turns local observation records into a
next topic, a question a parent can ask, and a new-situation prompt. Parents can
copy the report without child answer text, audio or personal scores. Companion
styling is an additional benefit. Core lessons and understanding checks remain free. The video shows a
completed native RevenueCat Test Store purchase, Aurora Cape equipped, and the
parent report opened. No real charge occurred.

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

The test purchase also exposed a cached cosmetic view that needed a restart.
Server conversation-allowance sync showed a retry notice; the video demonstrates
the local supporter grant and does not claim that separate sync succeeded.

## Accomplishments

A working native learning loop connects prediction, evidence, explanation,
follow-up, hints and review. The current interface makes the companion's record
part of the experience, and the optional purchase grants a visible supporter
benefit. The updated app passed 1,340 client tests; the unchanged server baseline passed
399 tests.
The entry's video demonstrates the real app within two minutes.
[Evidence and evaluation status](learning-evidence-2026.md) separates the research
rationale from functional verification. No learner efficacy study has been conducted.

## What I learned

The most useful product constraint was to ask what the learner must actually
do, rather than how much the companion can say. That led to hidden-source
explanations, equal text access, explicit rereading, fixed questions, and payment
that supports the app without buying the learning outcome.

## What's next

Physical-device recording/playback and permission-denial QA, first-time learner
pilots, and evaluating whether the teach-back loop improves explanations. The
existing elicitation survey has 18 responses and is not evidence of learning
effectiveness. External AI will remain disabled for school/minor distribution
until the provider and consent requirements are resolved.

## Why Next Gen

This entry focuses on a clear product idea and meaningful progress toward a
working native app: a learner teaches the companion, applies an idea, and sees
what needs another look. The demo and MIT repository expose both the experience
and the decisions behind it. RevenueCat supports an optional plan with visible
benefits; it does not gate core science lessons or sell correct answers.

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
- Video file: [shipaton-demo-v11.mp4](shipaton-demo-2026/shipaton-demo-v11.mp4), 52.8 seconds.
- Captions: [English SRT](shipaton-demo-2026/shipaton-demo-v11-captions.en.srt).
- Icon: `docs/store/icon-1024.png` — 1024×1024.
- Screenshot: `docs/store-shots-2026/devpost/shot-1179x2556.png` — current native
  app, 1179×2556, no device frame.
- Confirm active student eligibility, qualifying academic account email, and
  guardian consent if applicable. These are personal eligibility requirements,
  not facts established by the code or video.
