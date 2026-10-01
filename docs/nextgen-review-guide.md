# Dekisugi-kun — Next Gen reviewer guide

**Learn science by teaching a companion.** The learner predicts, reads the
scientific evidence, closes the material, and explains it from memory. A fixed
follow-up asks the learner to apply the idea to a new case. A miss brings a hint
and another explanation, rather than an answer to copy.

Start with the [53-second English demo](shipaton-demo-2026/shipaton-demo-v11.mp4), then the
[product overview](product-overview-en.md). The video is actual native Android
emulator footage, edited for pace, with separate English editorial narration.
It includes a RevenueCat **Test Store** purchase; no real charge occurred.

## Evidence against the four Next Gen criteria

| Criterion | What to look for | Source to inspect |
|---|---|---|
| Clear, useful, interesting or original idea | The companion needs the learner's explanation. The material disappears, so the student must produce an explanation. | [Product constitution](../AGENTS.md), [learning screens](../app/lib/screens) |
| Meaningful progress toward a working app | A native prediction → evidence → hidden-source explanation → follow-up → hint/retry sequence; uncertainty remains visible in the companion's record. | [Bundled English catalog](../app/assets/catalog/units.en.json), [record screen](../app/lib/screens/science_karte_screen.dart), [repair planner](../app/lib/learning/services/learning_repair_planner.dart) |
| Thoughtful use of RevenueCat | Store-provided packages, native purchase confirmation, Aurora Cape equipped, parent report unlocked. Core lessons stay free. | [Purchase adapter](../app/lib/services/revenuecat_purchase_adapter.dart), [purchase service](../app/lib/services/purchase_service.dart), [configuration](../app/lib/services/purchase_config.dart), [integration tests](../app/test/purchase_service_test.dart) |
| Technical choices, product thinking and care | Offline core, equal text route, deterministic checkpoints rather than LLM grading, minimal persisted need state, reproducible capture and edit. | [Progress store](../app/lib/learning/services/learning_progress_store.dart), [repair tests](../app/test/learning_repair_planner_test.dart), [production AI gate](../server/lib/generative-ai.ts), [video tooling](../tools/demo-video/README.md) |

## Run the native app

Use Flutter **3.47.5**, the version used for the current build and tests, with
an Android device/emulator or an iOS simulator. No API key is needed for the
core learning loop. From the repository root:

```bash
cd app
flutter pub get
flutter run --dart-define=APP_LANG=en
```

Complete the consent/onboarding screens and choose on-device learning. Open
**Field Notebook**, then the first science lesson. Make the prediction, read the
material, and continue to explanation. Choose text, type your own explanation,
explicitly reread it, then answer the catalog checkpoint. Try an incorrect
choice to inspect the hint and retry. In **My Lab**, open the companion's
misconception record. An observed need remains open until its matching repair
activity resolves it; rewriting alone is not a mastery claim.

The curriculum and main learning flow have English content. Some secondary UI
labels remain Japanese. The native app is the review target; the historical
hosted browser rehearsal is not used as a current demo.

## Optional RevenueCat replay

For a separate **adult personal test profile**, use the debug Test Store build:

```bash
flutter run --debug --dart-define=APP_LANG=en \
  --dart-define=REVENUECAT_USE_TEST_STORE=true \
  --dart-define=REVENUECAT_TEST_PUBLIC_SDK_KEY=test_UtdJreIqsGoYiqdCBrGBdTOOwje
```

This is the project's **public client SDK key**, not a server secret. Keep
external generative AI disabled; do not set `DEKISUGI_COMPANION_REMOTE`.
In the adult profile, enable the disclosed online/purchase route, open Plus,
and select a package. Continue only if the native dialog explicitly says
**Test Store Purchase**; choose **Test valid purchase**. The `plus` entitlement
grants Aurora Cape; equip it in My Lab and open the parent report. The recorded
purchase required a restart to refresh the cosmetic view. The server's separate
conversation-allowance synchronization was not confirmed and showed a retry
notice. This does not prevent the recorded local supporter grant.

Application ID / Android package: **`jp.dekisugi.dekisugi`**.
Entitlement: **`plus`**. Implementation and restore instructions:
[monetization setup](monetization-setup.md).

## Tests and limits

```bash
# From the repository root, run each in its own terminal or return to root.
(cd app && flutter test)
# From root:
(cd server && npm ci && npm test)
```

The integrated app baseline passed 1,337 app and 399 server tests. This
submission edit changes documentation, screenshots and video tooling, not
learning or billing behavior. The source is licensed under [MIT](../LICENSE).

There is no store release, measured learning-effect claim, or school rollout.
The elicitation survey has 18 responses and is not an efficacy study. Physical
mobile-device voice QA and broader learner pilots remain open. External live
AI is disabled in production; it is not a feature demonstrated in this entry.
