# Shipaton 2026 submission copy — Next Gen Award

Track: **Next Gen Award** (student-only; judged on the demo video and the public
open-source repository — no store release required).

This file is the English source of truth for the Devpost submission. Do not add
claims that are not true of the current build (no live-AI claims, no store
availability, no revenue or install numbers).

Official requirements: [Shipaton 2026 rules](https://revenuecat-shipaton-2026.devpost.com/rules)

## Project name

Dekisugi (AI デキすぎ君)

## One-line pitch

Learn science by teaching it: explain an idea in your own words, answer the AI's
fixed follow-up question, and apply the idea to a new case.

## Short description

Most study apps reward recognizing the right answer. Dekisugi asks learners to
produce an explanation instead.

Each short mission focuses on one science concept. The learner reads a compact
lesson, predicts what will happen, and then — with the lesson hidden — explains
the idea by voice or text to an AI study companion. Voice explanations must be
replayed; text explanations must be explicitly re-read. Only then does the
companion ask one fixed follow-up question from the lesson catalog. A wrong
answer records a canonical misconception and costs a heart, but never reveals
the correct answer: the learner gets a scientific hint and must explain again.

Story missions let the learner catch cataloged misconceptions the companion
voices in context; notation labs train formula and diagram reasoning; spaced
review and an exam-date countdown bring completed ideas back as new cases.

The core loop is entirely on-device: no account, no free-text upload, no LLM
grading of student writing. Voice audio and free text stay in RAM; the device
stores only lesson IDs, canonical misconception flags, hearts, and progress.
Optional Plus, powered by the RevenueCat SDK, lifts the daily limit on guided
live-conversation sessions — a feature kept disabled for minors pending a
provider contract, so nothing a student needs is behind payment.

## What was built during Shipaton

- A six-tab game UI with a serpentine learning path: learn / stories / practice /
  notation / compete / profile.
- The signature teach-back loop: read → hide → explain by voice or text →
  replay/re-read → fixed catalog checkpoint → hint-and-retry on miss.
- 10 curriculum units (29 concepts) aligned to Japan's national science
  curriculum guidelines, including the stage-2 chemistry units added this period.
- Misconception story missions, notation labs, spaced retrieval, hearts with
  timed recovery, daily XP caps that prevent grinding.
- A RevenueCat-powered optional Plus entitlement: purchase, restore, and a
  server-side entitlement recheck via `/api/revenuecat-webhook`.
- A deliberately safe posture for minors: external generative-AI endpoints return
  503 in production, and the app's required path works with no network.

## RevenueCat integration

Dekisugi uses the RevenueCat SDK (`purchases_flutter`) for one optional
entitlement: `plus`. Purchase, restore, and entitlement state are implemented
end-to-end in `app/lib/services/revenuecat_purchase_adapter.dart`, with server
re-verification in `server/lib/revenuecat.ts` and a webhook at
`/api/revenuecat-webhook`.

The paywall shows only the price and period returned by the store, explains
renewal and cancellation, exposes restore and subscription-management actions,
and fails closed when configuration is missing rather than inventing billing
information. RevenueCat receives a random app-scoped UUID and store transaction
data — never a learner's name, email, advertising ID, voice, transcript, or
answers.

Plus lifts the daily live-conversation limit. Live conversation is disabled in
the shipped build pending a minor-safe AI provider agreement, so the purchase is
fully optional and the entire learning loop is free.

## Demo video notes

The video shows the current build on a real device/emulator: opening the
learning path, reading a lesson, hiding it, explaining by text, re-reading, the
fixed checkpoint with a wrong answer's hint and heart loss, the correct retry,
a story misconception mission, and the optional Plus paywall shown via the
RevenueCat Test Store. English captions overlay the Japanese UI.

## Testing instructions (for judges)

1. Clone the public repository.
2. `cd app && flutter pub get && flutter run` — the bundled-catalog mode needs
   no network, server, or credentials.
3. On the learning path, open any lesson node, read the material, hide it, type
   an explanation, re-read it, and answer the checkpoint.
4. Deliberately answer one checkpoint wrong to see the hint + re-explain flow.
5. Optional: with a RevenueCat Test Store key, run with
   `--dart-define=REVENUECAT_USE_TEST_STORE=true --dart-define=REVENUECAT_TEST_PUBLIC_SDK_KEY=<test key>`
   to see the Plus paywall and a simulated purchase.

## Evidence checklist for the submission form

- `[PUBLIC REPO URL]` — https://github.com/Haruka-Kaya/dekisugi-kun
- `[YOUTUBE OR VIMEO VIDEO UNDER 2:00, ENGLISH CAPTIONS]`
- `docs/store/icon-1024.png` — 1024×1024 icon
- One 1179×2556 screenshot, no device frame (see `docs/store-shots-2026/`)
- Student/academic email on the Devpost account
- If a minor: parent/guardian consent form submitted before the deadline
