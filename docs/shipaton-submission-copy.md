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
the idea by voice or text to an AI study companion. Before the explanation is
accepted, the app checks on-device whether the learner's own words touched the
key terms of the lesson — a voice explanation is echoed back for confirmation,
and either path must be re-read before continuing. Only then does the
companion ask one fixed follow-up question from the lesson catalog. A wrong
answer records a canonical misconception and costs a heart, but never reveals
the correct answer: the learner gets a scientific hint and must explain again.

Story missions let the learner catch cataloged misconceptions the companion
voices in context; notation labs train formula and diagram reasoning; spaced
review and an exam-date countdown bring completed ideas back as new cases.

The signature screen is the **カルテ (misconception map)** on the profile tab:
a canonical catalog of 32 misconceptions, one per concept, shown as beliefs
the companion holds. Each misconception a student's explanation corrects
flips to "corrected by your explanation" and reveals the canonical correct
idea — progress rendered as what the learner changed in the AI, not a score.
Only cataloged need codes persist there; answer text and voice are never
stored.

The core loop is entirely on-device: no account, no free-text upload, no LLM
grading of student writing. In the current build, voice audio and free text
stay in RAM; the device stores only lesson IDs, canonical misconception flags,
hearts, and progress.
Optional Plus, powered by the RevenueCat SDK, is a supporter plan: it grants an
exclusive Aurora Mantle look for the study companion immediately, and lifts the
daily limit on guided live-conversation sessions once that feature resumes —
live conversation is kept disabled for minors pending a provider contract, so
nothing a student needs to learn is behind payment.

## What was built during Shipaton

- A six-tab game UI with a serpentine learning path: learn / stories / practice /
  notation / compete / profile.
- The signature teach-back loop: read → hide → explain by voice or text →
  replay/re-read → fixed catalog checkpoint → hint-and-retry on miss.
- 12 curriculum units (35 concepts) aligned to Japan's national science
  curriculum guidelines, including the stage-2 chemistry units added this period.
- Misconception story missions, notation labs, spaced retrieval, hearts with
  timed recovery, daily XP caps that prevent grinding.
- The カルテ (misconception map): the 32-entry canonical misconception catalog
  surfaced as the companion's record, with observed vs. resolved needs drawn
  from durable on-device need state — the protégé effect made visible.
- A RevenueCat-powered optional Plus supporter plan: purchase and restore
  grant an exclusive Aurora Mantle companion skin on-device, a generated-AI
  reply preface that reads the student's explanation (`/api/companion-line`,
  consent-disclosed, catalog-verbatim pedagogy, deterministic fallback), plus
  a shareable 「保護者の方へのレポート」 card on the カルテ screen that
  summarizes the misconceptions the student's explanations have corrected.
  Server-side entitlement re-verification (`/api/revenuecat-webhook`,
  `/api/subscription-sync`) is implemented and unit-tested; it gates the
  live-conversation quota, which is held disabled pending a minor-safe AI
  provider agreement.
- A deliberately safe posture for minors: the live-session generative-AI
  endpoints (`/api/live-token`, `/api/director`) return 503 in production, and
  the app's required path works with no network.

## RevenueCat integration

Dekisugi uses the RevenueCat SDK (`purchases_flutter`) for one optional
entitlement: `plus`. Purchase, restore, and entitlement state are implemented
end-to-end in `app/lib/services/revenuecat_purchase_adapter.dart`. Server-side
re-verification is implemented and unit-tested (`server/lib/revenuecat.ts`,
`/api/subscription-sync` called by
`app/lib/services/subscription_sync_client.dart`, and a webhook at
`/api/revenuecat-webhook`); it currently gates only the live-conversation
quota, which is disabled in the shipped build, so the supporter perks (the
Aurora Mantle skin, the generated-AI reply preface, and the parent report)
are granted on-device from the RevenueCat entitlement listener.

The paywall shows only the price and period returned by the store, explains
renewal and cancellation, exposes restore and subscription-management actions,
and fails closed when configuration is missing rather than inventing billing
information. RevenueCat receives a random app-scoped UUID and store transaction
data — never a learner's name, email, advertising ID, voice, transcript, or
answers. The privacy policy is served from the app's own Vercel deployment
(the project predates the rename: `rika-chousa.vercel.app` is this app's
server, the same host the API uses).

Plus is a supporter plan, not a paywall for learning: it grants the exclusive
Aurora Mantle companion skin, the generated-AI reply preface (gated to
supporter devices via `/api/companion-line`), and a shareable parent report
card on the misconception map, and will lift the daily live-conversation
limit when that feature resumes. Live conversation is disabled in the shipped build
pending a minor-safe AI provider agreement, so the purchase is fully optional
and the entire learning loop is free.

## Demo video notes

The submitted video (`docs/shipaton-demo-2026/shipaton-demo-v6.mp4`, ~97s) is
filmed on the English build of the app on an Android emulator in portrait:
a short hook card, then the learning path, a lesson node (the material hides
when it is time to explain — C2), a typed English teach-back explanation, the
on-device key-term coverage panel, the companion's fixed follow-up question,
a wrong pick costing a heart and earning a hint instead of the answer, the
misconception record screen ("Corrected / Still unsure"), the shareable
parent report, and the Plus screen. English captions overlay the English UI;
there is no audio track. The whole loop shown is on-device — no LLM, no
cloud, nothing a student writes leaves the phone.

The on-device coverage check is a vocabulary floor, not a grader: it verifies
that the key terms from the expected explanation appear in the student's own
words (stem-matched, normalization applied) before the follow-up question
proceeds. Correctness is still decided by the fixed 3-choice correction, so a
missed term asks for more detail instead of wrongly blocking a right answer.

The video does not include a purchase: the RevenueCat Test Store key is not in
the repository (it is a personal credential). The final segment shows the
paywall's fail-closed branch instead — with no reachable store, the app refuses
to guess a price and blocks the purchase operation ("Can't check store information"),
while free features keep working. Judges can exercise the full
paywall themselves with the `--dart-define` command in "Testing instructions".

The earlier Japanese-UI capture (`shipaton-demo-v4.mp4`, ~118s, airplane-mode
beat included) remains in this directory for reference; the submitted video
is the English-build capture. An even earlier web-build capture is archived
at `docs/attic/shipaton-demo-v1.mp4`.

## Testing instructions (for judges)

1. Clone the public repository.
2. `cd app && flutter pub get && flutter run` — the bundled-catalog mode needs
   no network, server, or credentials. The app also ships a full English build:
   `flutter run --dart-define=APP_LANG=en`, or toggle 表示言語 → English in
   Settings at runtime. Every lesson, practice stage, misconception follow-up,
   story, and notation task renders in English; the English catalog is
   machine-generated from the same server source (`assets/catalog/units.en.json`)
   and served over the network at `/api/units?lang=en`.
3. On the learning path, open any lesson node, read the material, hide it, type
   an explanation, re-read it, and answer the checkpoint.
4. Deliberately answer one checkpoint wrong to see the hint + re-explain flow.
5. Open the profile tab → 「思い込みの記録を見る」 to see the カルテ: the
   companion's misconception map with observed/corrected need states.
6. Optional: with a RevenueCat Test Store key, run with
   `--dart-define=REVENUECAT_USE_TEST_STORE=true --dart-define=REVENUECAT_TEST_PUBLIC_SDK_KEY=<test key>`
   to see the Plus paywall and a simulated purchase that grants the Aurora
   Mantle companion skin in the cosmetic picker.

## Evidence checklist for the submission form

- `[PUBLIC REPO URL]` — https://github.com/Haruka-Kaya/dekisugi-kun
- `[YOUTUBE OR VIMEO VIDEO UNDER 2:00, ENGLISH CAPTIONS]`
- `docs/store/icon-1024.png` — 1024×1024 icon
- One 1179×2556 screenshot, no device frame, plus optional gallery shots of the
  teach-back screens and the Aurora Mantle equipped state (see
  `docs/store-shots-2026/devpost/`)
- Student/academic email on the Devpost account
- If a minor: parent/guardian consent form submitted before the deadline
