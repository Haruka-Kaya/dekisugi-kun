# Shipaton 2026 submission copy

Updated: 2026-08-10

This file is the English source of truth for the Devpost submission. Do not add
store URLs, revenue, installs, retention, ZDR approval, or school availability
until each claim has been verified in the published build.

Official requirements: [Shipaton 2026 rules](https://revenuecat-shipaton-2026.devpost.com/rules)

## Project name

Dekisugi

## One-line pitch

Learn science by teaching it: explain one idea, catch a student's misconception,
and prove you can use the idea in a new case.

## Short description

Most study apps reward recognizing the right answer. Dekisugi asks learners to
produce an explanation instead.

Each short mission focuses on one science concept. The learner reads a compact
source, closes it, chooses a teaching tactic, and explains the idea by voice or
text to an AI junior student. The junior then voices a cataloged misconception.
The mission clears only when the learner rejects that misconception and supplies
a correct idea, condition, or reason. An unresolved attempt becomes a focused
repair mission; a successful explanation later returns as a new-case mission.

There are no coins, loot boxes, leaderboards, or streak-loss pressure. The
reward is the learner's own sentence, stored on the device as evidence of what
they can explain. The full learning loop remains free. Optional Plus removes the
daily live-mission limit through RevenueCat without locking lessons, text input,
repair missions, accessibility, or saved learning notes behind payment.

When a live connection is unavailable, bundled lessons and a private on-device
practice path still support recall, adding a condition or reason, applying the
idea to a concrete case, and correcting a fixed misconception with a cataloged
three-choice checkpoint. A wrong choice gives a scientific hint and requires a
retry; it does not reveal or award a mastery result. These entries are neither
uploaded nor falsely counted as mastery.

## What was built during Shipaton

- A three-part TEACH / REPAIR / CASE mission path, limited to one concept at a time.
- A misconception challenge that must actually be spoken before it can be evaluated.
- Evidence-based completion that rejects bare denial and model-invented corrections.
- Voice and text as equal input paths.
- On-device learning records and a no-network lesson/practice path that does not
  create an identity, start purchase services, upload answers, or claim mastery.
- A RevenueCat-powered optional Plus entitlement, purchase, restore, and server sync flow.
- Honest failure recovery for interrupted sessions and failed local saves.
- Responsive Japanese UI tested at 320 dp and 200% text size, with semantic live regions.

## RevenueCat integration

Dekisugi uses RevenueCat for one optional entitlement: `plus`. The core learning
loop is available without a purchase; Plus removes the daily live-mission limit
while per-device rate limits and per-session time limits remain.

The paywall displays only the price and subscription period returned by the
store. It explains automatic renewal and cancellation, exposes restore and
subscription-management actions, and links to the applicable store terms and
privacy policy. If price, period, offering, or public SDK configuration is
missing, purchase fails closed instead of inventing billing information.

RevenueCat receives a random app-scoped UUID and store transaction data. It does
not receive a learner's name, email, advertising ID, voice recording, transcript,
or science answer as a customer attribute.

## RevenueCat Design Award

Dekisugi turns assessment state into the interface itself. The learner always
sees the current action—not a dashboard of scores: prepare an explanation,
teach, catch a misconception, repair a gap, or apply the idea to a new case.
The source disappears before teaching to prevent reading aloud. The AI junior's
expression and the three-stage mission surface provide immediate feedback, while
the completion screen gives visual priority to the learner's exact sentence.

The visual system uses solid paper, warm note, and cool studio surfaces instead
of generic cards or game currency. Motion communicates a change of learning
state and respects Reduce Motion. Judges should look at the 30-second local
tutorial, the transition into the misconception challenge, the live mission HUD,
and the signed learner note on completion.

## Best Game Award

The gameplay is the learning action rather than a decorative points layer:

1. Prepare one concept and choose a teaching tactic.
2. Recall the idea without the source.
3. Teach a junior student.
4. Notice the junior's misconception.
5. Defend the explanation with a condition or reason.
6. Return later and transfer the idea to a different case.

Wrong or incomplete attempts create a targeted repair mission rather than taking
away a life. Success creates a harder transfer mission rather than an endless
level number. The loop is replayable because the learner's task changes with
the evidence they have produced.

Monetization fits the loop by selling additional daily live practice, not answers,
power, accessibility, or protection from punishment.

## RevenueCat Peace Prize

Dekisugi is designed for learners who can recognize an answer but struggle to
explain why it is true. Teach-back makes hidden gaps visible without publicly
ranking students. Voice helps learners who prefer speaking; equal text input
keeps the same mission usable in a classroom, library, train, or noisy home.

The app minimizes personal data, keeps online transcripts and concept records on
the device, and gives teachers no individual transcript or leaderboard. Offline
lessons and practice keep the learning action available when connectivity or a
paid AI session is unavailable. Free responses and selected answers are neither
uploaded nor retained; the device stores only the lesson ID, concept ID,
completion count, and last-completed time needed to rotate the next practice.

Under-18 and school users can enter that device-only path without accepting an
overseas-transfer disclosure. The path contains no live AI, school-server,
purchase, upload, identity, or mastery-recording dependency. Its minimal local
rotation marker can be cleared in the app. It is practice—not a claim that an
automated system has certified understanding.

School and under-18 distribution remains disabled until the selected AI provider,
data processor, consent flow, age assurance, safety monitoring, and escalation
process have all been verified. This is a deliberate safety boundary, not a
claim that a client-side age checkbox makes an AI service suitable for minors.

## Demo video description

In under two minutes, the on-device cut shows a learner correcting a
misconception, choosing a one-concept mission, closing the source, recalling it,
adding a reason, applying it to a case, and completing a private checkpoint that
is explicitly not scored as mastery. It ends with the optional RevenueCat Plus
offer and the free-core boundary. A live-AI cut may replace that middle section
only after the provider and public-build gates in the capture sheet are green.

## Testing instructions

Replace every bracketed item before submission.

1. Install the public build from `[STORE URL]`.
2. Use the app as an adult individual user and complete the disclosure screen.
3. Finish the local 30-second tutorial; it requires no network or account.
4. Open `[CONCEPT NAME]`, read to the end, and choose `[TACTIC]`.
5. Teach by text using `[SAFE TEST EXPLANATION]`, then correct the displayed misconception.
6. Open Plus and redeem `[PROMO CODE OR TRIAL INSTRUCTION]`.
7. Confirm the store price/period, purchase state, restore action, and subscription-management link.

Do not submit these instructions until the public build, US availability, premium
access path, and every named screen have been tested from a clean installation.

## Evidence still required before submission

- `[APP STORE / PLAY URL]`
- `[PUBLIC PRIVACY URL]`
- `[PUBLIC SUPPORT URL]`
- `[YOUTUBE OR VIMEO VIDEO UNDER 2:00]`
- `[PROMO CODE OR FREE TRIAL]`
- RevenueCat dashboard evidence for the live `plus` entitlement and offering
- A real purchase and restore in the store build
- Final marketing screenshot set from the verified current-build capture path
- If claiming Grand Prize: verified launch date, installs, active users, revenue,
  conversion, retention, and the experiments that caused those results
