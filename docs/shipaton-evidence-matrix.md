# Shipaton 2026 claim and evidence matrix

> [!CAUTION]
> **ARCHIVED RESEARCH / LEGACY CANDIDATE — DO NOT DISTRIBUTE OR SUBMIT.**
> This is not the current production source of truth. The Live-AI,
> free-response, store-build, and submission claims below are retained only for
> historical traceability and must not be copied into a release or application.

Updated: 2026-08-10

Use this matrix before changing the Devpost copy, store listing, screenshots, or
video. A claim may be published only when its automated contract and its manual
store-build evidence are both green.

Status meanings:

- **GREEN** — verified in the current source tree and may be described as an
  implemented feature. Store availability may still be blocked.
- **AMBER** — implementation exists, but external configuration or exact-build
  evidence is missing. Describe only as work in progress.
- **RED** — contract, legal, security, or distribution blocker. Do not publish
  the claim or expose the feature.

## Learning-loop claims

| Claim | Source contract | Automated evidence | Store-build evidence | Status |
|---|---|---|---|---|
| A mission focuses on one concept | `focusConceptKey` is carried through Material, session, token, and Director; invalid focus is rejected before quota | `material_screen_test.dart`, `home_test.dart`, `live_session_half_duplex_test.dart`, `server/test/director.test.ts`, `server/test/catalog_invariant.test.ts` | Clean install: select one concept and confirm no other section/question appears | **GREEN** |
| The learner chooses a teaching tactic | `TeachingTactic` is persisted and sent to both live and Director APIs; CASE is reason-fixed | `director_client_test.dart`, `live_session_half_duplex_test.dart`, `server/test/director.test.ts` | Capture source end → tactic selection → mission HUD | **GREEN** |
| The junior must actually voice the fixed misconception | A marker is stored only when the live utterance matches the language-specific catalog lure; server revalidates ID and text | `live_session_half_duplex_test.dart`, `dossier_model_test.dart`, `server/test/director.test.ts`, `server/test/i18n.test.ts` | Live-provider build: preserve transcript showing challenge before correction | **GREEN source / RED public AI** |
| Bare denial cannot clear a mission | Correction substance is taken from raw learner text, not model correction; denial-only input remains unresolved | Two-turn regression in `server/test/director.test.ts` | Repeat with “No” then with a reason in the exact store build | **GREEN source / RED public AI** |
| Focused-mission completion is atomic and idempotent | Session end, note, review, concept progress, and activity count commit once per focused session; the legacy unfocused compatibility path is not part of this claim | `session_store_test.dart`, `session_store_migration_test.dart`, `achievement_flow_test.dart` | Interrupt during save, relaunch, and verify no duplicate completion | **GREEN** |
| Success becomes a later CASE and unresolved work becomes REPAIR | `ConceptProgress.nextMissionKind` and due dates are persisted from actual completion | `achievement_flow_test.dart`, `home_test.dart`, `review_test.dart` | Advance test clock/build fixture and open Home | **GREEN** |
| The completion note uses the learner's real words | Achievement text is derived from the latest raw student evidence and accepted/failed states are excluded | `dossier_model_test.dart`, `achievement_flow_test.dart`, `session_complete_test.dart` | Compare typed sentence with completion note character for character | **GREEN** |

## Offline and safety claims

| Claim | Source contract | Automated evidence | Store-build evidence | Status |
|---|---|---|---|---|
| Lessons open on a fresh install without the API | Generated bundled catalog is the final fallback after online and cache | `unit_model_test.dart`, `home_test.dart`, `unit_picker_screen_test.dart`, `server/test/catalog_invariant.test.ts`; `npm run catalog:check` | Airplane mode, clear app data, open Home → concept → source | **GREEN** |
| Offline practice requires recall, reason, transfer, and misconception correction | Three non-empty free-response stages precede a cataloged three-choice checkpoint; source remains hidden until the responses are committed; wrong choices give a hint and require retry | `offline_practice_screen_test.dart`, `unit_model_test.dart`, `server/test/catalog_invariant.test.ts` | Airplane mode from focused lesson through `LOCAL CHECKPOINT CLEAR` | **GREEN** |
| Offline input is not uploaded, scored, saved as mastery, or charged to quota | Screen owns local controllers only and does not receive store/API dependencies; free responses and selected answers never enter the progress callback. Only unit ID, concept ID, completion count, and last-completed time are stored locally for rotation | `offline_practice_screen_test.dart`, `local_practice_store_test.dart`, `app_shell_test.dart`; dependency inspection | Inspect network traffic and local storage after completion: no response text, age, consent, or device identity; only the documented rotation marker | **GREEN source / AMBER device audit** |
| School and under-18 users can choose a device-only path without external consent | The local subtree is entered without saving a consent/age record and has no DeviceIdentity, Team, Purchase, Live, or Director providers; it uses bundled catalog data and routes Material directly to offline practice | `consent_test.dart`, `app_shell_test.dart`, `offline_practice_screen_test.dart` | Clean install in airplane mode: choose device-only mode, open a lesson, finish the checkpoint, and verify no traffic or saved identity | **GREEN source / AMBER device audit** |
| Under-18 and school access are currently disabled | Consent v4 accepts only adult self; production API guards deny AI, Team, and restricted data processing | `consent_test.dart`, `app_shell_test.dart`, `server/test/generative_ai_gate.test.ts`, `server/test/restricted_data_processing_gate.test.ts` | Published endpoints must return the documented 503 before quota/provider calls | **RED production not deployed** |
| The product is suitable for school deployment | Requires provider permission, age assurance, DPA/data boundary, filters, monitoring, reporting, and escalation | No passing acceptance suite yet | Written provider/data-processor approval and school pilot controls | **RED** |

## Accessibility and UI claims

| Claim | Automated evidence | Manual evidence | Status |
|---|---|---|---|
| Core screens reflow at 320 dp and 200% text | Screen-specific widget tests including `home_test.dart`, `material_screen_test.dart`, `talk_safety_test.dart`, `offline_practice_screen_test.dart`, `plus_screen_test.dart` | Android and iOS device screenshots with OS text scaling | **GREEN source** |
| Voice and text are equal learning inputs | Talk UI exposes both paths; typed turns use the same session evidence pipeline | Use both paths in the exact store build | **GREEN source / live provider blocked** |
| Status is not conveyed by color alone | State labels, icons, and semantics are tested across mission, dossier, quota, and completion widgets | TalkBack and VoiceOver pass on physical devices | **GREEN source / AMBER device audit** |
| Reduce Motion is respected | Tutorial transition chooses immediate visibility instead of animation when accessibility navigation is set | Toggle Reduce Motion on iOS and record the tutorial transition | **GREEN source / AMBER manual proof** |
| Store screenshots show current UI and contain no alpha | The former capture/verification scripts are fail-closed because their OCR contract targets the retired 30-second mission UI | Only legacy candidates exist; recapture Field Notebook on current iPhone/iPad/Android builds, then add exact dimensions, RGB/no-alpha, new-copy OCR, notification, and corner checks | **RED — do not submit existing files** |

## RevenueCat and distribution claims

| Claim | Source contract | Automated evidence | External evidence | Status |
|---|---|---|---|---|
| Plus changes only the daily live-conversation limit | Free lessons, text, notes, accessibility, REPAIR/CASE remain available; entitlement affects server quota | `plus_screen_test.dart`, `purchase_service_test.dart`, `quota_view_test.dart`, `server/test/quota.test.ts` | Dashboard entitlement and clean free/Plus device comparison | **AMBER** |
| The paywall displays real price and period | Store package data is required; unsupported/missing billing terms fail closed | `plus_screen_test.dart`, `purchase_service_test.dart` | App Store sandbox and Play internal purchase screenshots | **AMBER** |
| Purchase, restore, management, and server sync work | RevenueCat adapter, typed sync client, one-retry auth renewal, and webhook verification exist | `purchase_service_test.dart`, `subscription_sync_client_test.dart`, `server/test/revenuecat.test.ts` | Real purchase, relaunch, restore on second install, cancellation/expiry | **AMBER** |
| The app is available in the stores | Release artifacts must use production signing and approved listings | Local APK/AAB/iOS build only | Public App Store and Play URLs | **RED** |
| The Android artifact is distributable | Current APK/AAB uses the dedicated `CN=Haruka Kaya` upload key | `apksigner verify`, `zipalign`, `jarsigner`, `bundletool validate` | Upload-key-signed AAB accepted by Play | **AMBER** |
| The iOS artifact is distributable | Current device build is no-codesign | plist/architecture checks only | Team-signed archive uploaded and accepted | **RED** |

Current local candidate evidence: upload-key-signed APK SHA-256
`2ade1e01146cf5ce2968ccecbcfa2d2e0a0e8948b5f0f8e02a6c8f4d9493f1a8`,
upload-key-signed AAB SHA-256
`fddc263bf919b47d736832be1e50317d60732ce21a81dd096a8411c2411f19e1`,
and unsigned iOS Dart AOT SHA-256
`e966fbe01debf74bc3eb2f795a89670c8a9723c6a518787c9f86159145f21367`
(bundle aggregate `2704c3f083f8028a1acb7e5729bce28bb7fda9261bc7a2d1514c024fa02cf63a`).
These prove buildability only and do not change the RED distribution status.

## OpenAI Realtime migration claim

The internal `realtimeGrantHandler` is a disabled migration scaffold, not a public
Function or school-safe feature. It validates audience inputs, HMACs the device identifier,
requests a 30-second client secret, checks the effective upstream model/session/
expiry, returns no-store, and does not expose the standard API key.

Do not enable or market it until a server-controlled session boundary prevents
one client secret from creating multiple sessions, overriding protected persona
and safety configuration, or continuing beyond the paid time limit. School use
also requires verified ZDR, age assurance, age-appropriate filtering, monitoring,
reporting, escalation, and abuse-resistant identity/rate/quota storage.

Current status: **RED for public use**.

## Required verification commands

Run from the repository root after every integrated feature change:

```sh
cd app
flutter analyze --no-pub
flutter test

cd ../server
npm run catalog:check
npm run typecheck
npm test

cd ..
git diff --check
git status --short
```

Before submission, append the exact command output, store-build hashes, public
URLs, RevenueCat product identifiers, purchase/restore timestamps, screenshot
dimensions, and final video duration to the evidence log. Do not replace missing
evidence with a prose assertion.
