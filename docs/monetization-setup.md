# Monetization setup — exercising the Plus purchase loop

The Plus supporter plan is real RevenueCat SDK code, not a mock. This page is
the complete, step-by-step way to exercise a live purchase end-to-end with
RevenueCat's free **Test Store** — no App Store / Play Console work, no real
money, about ten minutes.

## What the current purchase unlocks

1. **Family review plan and parent report** — local observation records select
   the next review topic. The plan explains why it was selected, gives a parent
   prompt and a new-situation prompt, and suggests a later review. Copying shares
   the plan without answer text, voice or personal scores. Recorded activity is
   explicitly distinguished from independently verified understanding.
2. **Aurora Mantle mascot skin** — granted once on entitlement confirmation and
   kept on the device ledger even after the entitlement lapses
   (`SafeLearningEconomyCatalogV1.auroraMascotId`, granted via `onPlusActivated`).
   The current supporter report also follows this retained local supporter grant.

Lessons, missions, text input, the learner's own record, accessibility, repair
and the optional understanding check are free. Plus does not improve scoring,
sell answers or guarantee learning outcomes. External AI conversations are
paused on all plans. Remote generated reply prefaces are an opt-in research path
and are disabled in the submission build; they are not advertised as a current
paid benefit. Future conversation allowances are not a current purchase reason.

## 1. This project's Test Store

A RevenueCat project (`dekisugi-kun`) already exists with entitlement `plus`
and a `default` offering (Monthly / Yearly / Lifetime). Its Test Store
**public** API key is:

```
test_UtdJreIqsGoYiqdCBrGBdTOOwje
```

Public keys are safe to ship — they identify the project, they cannot charge
anyone. (To reproduce the setup from scratch: sign up at
[app.revenuecat.com](https://app.revenuecat.com), **Projects → New Project**,
then copy the `test_…` public API key.)

## 2. Point the app at the Test Store

```bash
cd app
flutter run --dart-define=REVENUECAT_USE_TEST_STORE=true \
            --dart-define=REVENUECAT_TEST_PUBLIC_SDK_KEY=test_UtdJreIqsGoYiqdCBrGBdTOOwje \
            --dart-define=SERVER_URL=https://rika-chousa.vercel.app
```

The Test Store key is honoured only in debug builds — a release build ignores
it, so a `test_…` key can never ship (`RevenueCatPurchaseConfig` in
`app/lib/services/purchase_config.dart`).

The paywall (`Plus` on the profile tab) lists the Test Store offering with its
real price string, runs the purchase and restore flows, and confirms the
entitlement before granting perks — the same code path a production store
uses. `app/test/plus_screen_test.dart` exercises purchase, restore, failure
and grant sequencing against the same contract.

## 3. Enable the generated-AI reply (optional)

The Plus reply preface calls the server's `/api/companion-line`, which needs
an OpenAI-compatible key set as a Vercel environment variable:

| Variable | Default |
|---|---|
| `COMPANION_AI_API_KEY` | unset → endpoint returns 503, client falls back to the fixed preface |
| `COMPANION_AI_BASE_URL` | `https://api.openai.com/v1` |
| `COMPANION_AI_MODEL` | `gpt-4o-mini` |

The client also requires `DEKISUGI_COMPANION_REMOTE=1` at build time, so
default builds stay fully offline.

Only the student's explanation, the heard cue terms, and the unit label are
sent — never the lure, the correct answer, options, voice audio, or any
identifier. If the endpoint is unreachable or the device is not a supporter,
the deterministic catalog preface is used instead.

## Production path

For real stores: configure the RevenueCat products, then build with the
platform public SDK keys (`REVENUECAT_IOS_PUBLIC_SDK_KEY=appl_…` /
`REVENUECAT_ANDROID_PUBLIC_SDK_KEY=goog_…`, optionally
`REVENUECAT_PLUS_ENTITLEMENT_ID` to rename the entitlement), and set
`REVENUECAT_WEBHOOK_SECRET` on Vercel so `/api/revenuecat-webhook` can recheck
entitlements server-side (`server/lib/revenuecat.ts`).
