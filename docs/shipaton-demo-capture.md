# Shipaton 2026 demo capture sheet

> [!CAUTION]
> **ARCHIVED VIDEO PLAN / LEGACY CANDIDATE — DO NOT DISTRIBUTE OR SUBMIT.**
> This is not the current production source of truth. The old Live-AI,
> free-response, shot list, hashes, and paired SRT are retained only for
> historical traceability; none is approved production evidence.

Updated: 2026-08-10

This is the shot-by-shot source of truth for the public demo. The final export
must be shorter than two minutes. Target 1:50 so the platform does not reject a
file because of an edit or encoding boundary.

The matching English caption source is `docs/shipaton-demo-captions.en.srt`.
Update the capture sheet and caption file together whenever timing changes.

Do not simulate network success, purchases, school availability, user counts,
or AI-provider approval. Every visible state must be reproduced from the same
store build given to judges.

## Capture gates

The final public video is blocked until all of these are true:

- the submitted store build is signed and publicly installable;
- the selected live-AI path is contractually available for the app's declared
  audience, or the video and listing describe only the deterministic on-device
  learning path;
- RevenueCat uses a real store product and the shown price, period, purchase,
  restore, and management states have been exercised in that build;
- the privacy and support URLs shown in the listing are public;
- captions, narration, and visible copy make the same claims as the build.

Until those gates pass, record only rehearsal footage and the deterministic
on-device path. Never publish a rehearsal as the submission video.

## Rehearsal timeline — 1:50

The current export candidate is an **on-device rehearsal**, not the public
submission video. It deliberately excludes unconfigured RevenueCat, live-AI
success, Store publication, revenue, and school-deployment claims.

| Time | Exact visual evidence | English narration / caption | Capture requirement |
|---|---|---|---|
| 0:00–0:06 | Open on the junior's misconception, select the condition-based correction, then cut to `TUTORIAL CLEAR` | **Do not pick an answer. Teach it. Challenge it. Use it.** | Fresh install; local tutorial; airplane mode permitted |
| 0:06–0:14 | Wordmark and the first local mission question; no account or dashboard first | Most study apps test recognition. Dekisugi starts by asking the learner to reason. | Show one uninterrupted tap sequence |
| 0:14–0:24 | Enter `DEVICE-ONLY STUDIO`; show the no-AI, no-server, no-purchase boundary, the free-response non-retention statement, and the exact minimal local record | No account or network is required. Free-response text is neither sent nor saved. | Enter through the actual consent-screen control; do not inject route state |
| 0:24–0:36 | Start the real `NEXT LOCAL MISSION` (`落下の速さ` on a clean install); read its focused source to the end; choose the reason tactic; source closes | A queued local mission opens its bundled source. Choose a tactic, then recall it without reading. | Use the Home recommendation itself; no picker shortcut or other concept section may appear |
| 0:36–0:54 | On-device recall → add a condition or reason → predict the concrete case | Recall, reasoning, and transfer still matter. The learner's words disappear after this practice. | Turn off network before entry; show all three stages; never describe the minimal rotation record as containing these answers |
| 0:54–1:04 | Select the heavier-first misconception; submit it; show the cataloged science hint and required retry | A wrong choice returns a science hint and requires another attempt. | Use bundled catalog content; the incorrect choice must not complete the checkpoint |
| 1:04–1:17 | Select the condition-based correction and reach `LOCAL CHECKPOINT CLEAR` | The fixed checkpoint tests the condition that commonly breaks the idea. | No AI, network, or mastery claim |
| 1:17–1:29 | Cataloged explanation; explicit free-response non-retention; the local unit/concept/count/time marker; expanded source comparison; then the Home recommendation rotates | The source returns for private self-check. Only unit, concept, count, and time stay on-device to rotate the next mission. | The source must remain absent before the correct checkpoint response; the next Home must show one practiced concept without retaining the learner's words |
| 1:29–1:42 | Real Android `Display size and text` setting at 200%, then the same device-only UI reflowed at that setting | System-level 200% text remains usable without changing the learning boundary. | Use the real OS setting page and app; no mock accessibility overlay |
| 1:42–1:50 | Return to the device-only assurance and four-step method; hold on the current wordmark | Rehearsal only: no Store release, revenue, live-AI approval, or school deployment is claimed. | End without Store badges, purchase states, analytics, or school logos |

## Optional live-AI insert

Replace, rather than extend, 0:36–1:17 with a live conversation only after the
provider, age, data, safety, and abuse-control gates are complete. The insert
must still keep the full export under 2:00 and must show all of the following:

1. the learner explains one focused concept;
2. the junior actually says the cataloged misconception;
3. a bare denial does not clear the mission;
4. the learner supplies a correct idea, condition, or reason after that utterance;
5. the mission clears once and the exact learner sentence is saved locally;
6. no hidden operator, edited response, or pre-recorded assistant output is used.

If any item cannot be reproduced from a clean store install, use the deterministic
on-device cut and remove the words “AI conversation” from the submission copy.

## Capture naming

Store raw recordings outside the repository. Copy only approved stills and the
final compressed video into the submission workspace.

| ID | Raw clip name | Required start and end state |
|---|---|---|
| C01 | `01-tutorial-misconception.mp4` | misconception correction → `TUTORIAL CLEAR` |
| C02 | `02-first-local-mission.mp4` | fresh wordmark and local question held visibly |
| C03 | `03-device-only-assurance.mp4` | actual local-only entry control → device-only assurance |
| C04 | `04-source-and-tactic.mp4` | `NEXT LOCAL MISSION` start → focused source closed |
| C05 | `05-offline-recall-reason-transfer.mp4` | stage 1 empty → stage 3 committed |
| C06 | `06-checkpoint-hint.mp4` | misconception visible → wrong-choice science hint |
| C07 | `07-local-checkpoint-clear.mp4` | condition-based correction → local checkpoint clear |
| C08 | `08-source-comparison.mp4` | completion boundary → expanded source comparison → rotated Home recommendation |
| C09 | `09-accessibility-200-percent.mp4` | real 200% OS text setting → device-only UI at 200% |
| C10 | `10-rehearsal-boundary.mp4` | device-only assurance → explicit rehearsal-only ending |

## Edit rules

- 1080p or higher, constant frame rate, with the app content readable on a phone.
- Burn in English captions; narration may be omitted if the captions carry the
  complete story.
- Use straight cuts and short state labels. Do not hide waiting time with a cut
  that changes the meaning of the interaction.
- Do not add copyrighted music, third-party mascots, store badges, or product
  logos without permission.
- Never overlay invented analytics, testimonials, school logos, prices, ratings,
  or purchase success.
- Keep the original raw clips, final timeline, captions, and store build hash so
  every claim can be reproduced during judging.

## Current local release candidates — not publishable

These hashes prove that the current source tree builds. They are not the
pre-export evidence below and must not be presented as public Store artifacts.

| Artifact | Local evidence | Distribution status |
|---|---|---|
| Android APK | `1.0.0+1`; SHA-256 `2ade1e01146cf5ce2968ccecbcfa2d2e0a0e8948b5f0f8e02a6c8f4d9493f1a8` | Release mode, non-debuggable, zipaligned, and signed by the dedicated `CN=Haruka Kaya` upload key; device QA candidate |
| Android AAB | `1.0.0+1`; SHA-256 `fddc263bf919b47d736832be1e50317d60732ce21a81dd096a8411c2411f19e1` | Upload-key signed and `bundletool validate` passes; Play acceptance is still unverified |
| iOS `Runner.app` | `1.0.0 (1)`; Dart AOT SHA-256 `e966fbe01debf74bc3eb2f795a89670c8a9723c6a518787c9f86159145f21367`; bundle aggregate `2704c3f083f8028a1acb7e5729bce28bb7fda9261bc7a2d1514c024fa02cf63a` | arm64 device Release build, but unsigned; no archive or IPA exists |

Replace this section's hashes only when rebuilding the same local candidate.
Fill the public-build evidence below only after production signing and Store
acceptance; never copy these development-signing hashes into that table.

## Pre-export evidence log

Fill this table only after testing the exact public build.

| Evidence | Value |
|---|---|
| Store build version | `[UNVERIFIED]` |
| Android AAB SHA-256 | `[UNVERIFIED]` |
| iOS archive / IPA SHA-256 | `[UNVERIFIED]` |
| Store URL | `[UNVERIFIED]` |
| RevenueCat offering and entitlement | `[UNVERIFIED]` |
| Purchase and restore test date | `[UNVERIFIED]` |
| AI provider / approved audience | `[UNVERIFIED OR ON-DEVICE ONLY]` |
| Video duration | `[MUST BE < 2:00]` |
| Public video URL | `[UNVERIFIED]` |
