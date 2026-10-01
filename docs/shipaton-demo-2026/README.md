# English demo — Next Gen review and introduction

**Current candidate: [shipaton-demo-v13.mp4](shipaton-demo-v13.mp4)** — 67.4 seconds,
1080×1920 portrait, 30 fps, English narration and burned-in English captions.
The matching [SRT](shipaton-demo-v13-captions.en.srt) and
[poster](shipaton-demo-v13-poster.jpg) are included. YouTube/Vimeo upload and
Devpost submission are separate from completion of this local artifact.

The opening asks whether the viewer can explain why things fall. The native
interaction then shows prediction, evidence, hidden-source explanation, rereading,
a fixed follow-up, a condition hint and another try. Uncertain ideas remain in
the companion's record. The last section shows optional RevenueCat Plus,
a family review plan with parent questions, copying the report, and a free
understanding check. The payer's task is concrete: decide what to review and
what to ask, while core learning remains free.

One native app view fills the frame. No duplicate view, artificial tap effect,
animated zoom or music is used. Native typing, selection, transitions and
scrolling carry the story. Hint and rewritten explanation
screenshots are held for 4.4 seconds in total; the closing card is 2 seconds.
Pauses leave time for reading and narration. Recording-source share is not a
claim that every second contains movement.

## Evidence

- Latest code: `c9887bd`. New v12 recordings cover the English prediction and
  material, current Plus purchase, family plan/report copying and free check.
  The core teach-back and need record use retained v8/v10 native recordings.
  The prior metrics bar is cropped from retained teaching shots; the source
  hashes and crop decisions are explicit in the manifest and edit file.
- All app UI is genuine native Android emulator footage. Progress was produced
  through UI interactions; no database values, temporary unlocks or app screens
  were fabricated. Cuts and a modest typing speed change remove waits.
- Plus uses a separate adult personal **RevenueCat Test Store** profile. The
  purchase confirmation and report access were verified, with no real charge.
  Its empty observation record is explicitly shown. This is a local family
  plan and shareable report, not cloud-linked parent/child accounts.
- The separate live-conversation allowance sync showed a retry notice. The
  video demonstrates the local supporter grant and report; it does not claim
  that sync succeeded. External generative AI remained disabled.
- The free check shows native questions after teaching and selection in a new
  situation. The walkthrough is developer-operated. The video focuses on
  applying the principle and does not display a before/after score comparison.
- Narration is a separate local editorial voice, not the companion's in-app
  voice. Emulator capture is not physical-device acceptance.

## Sources and reproduction

[Script](v13-script.json), [edit decisions](v13-edit.json),
[manifest](v13-manifest.json) and [validation](v13-validation.json) identify the
source hashes, timings and final video hash. Commands are documented in
[tools/demo-video](../../tools/demo-video/README.md). Raw captures, XML observations,
action logs remain locally in `app/build/demo-video-v12/`; v13 source copies
and narration are in `app/build/demo-video-v13/`. Both are ignored by Git. A new checkout needs its own capture or that source bundle to regenerate
this edit; the committed MP4 and captions are directly usable.

Narration uses local [Kokoro ONNX](https://github.com/thewh1teagle/kokoro-onnx)
and [Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M), voice `af_sarah`.
The closing card uses the project's current `docs/store/icon-1024.png` artwork.

## Validation

The entire MP4 decodes without errors. Audio/video timestamps are ordered and
captions match the complete narration. Every shot is compared against its
original source timeline near its beginning and end. Composition was inspected
at every scene start and end, including purchase, report and question selection transitions.
The original variable-frame-rate timeline is expanded to 30 fps **before**
trimming, preserving the pre-action frame. Measurements and limits are recorded
in `v13-validation.json`.

## Earlier edits

[v12](shipaton-demo-v12.mp4) (67.4 seconds) is the previous cut. v13 replaces
the check-result still with actual question selection and focuses narration on
the learner actions.
[v11](shipaton-demo-v11.mp4) (52.8 seconds) is an earlier single-view cut.
It fixed v10's duplicate view and sparse-frame input-seeking issue. v12 keeps
that timing fix and adds current English UI, family-review value and a check.
[v10](shipaton-demo-v10.mp4), [v9](shipaton-demo-v9.mp4),
[v8](shipaton-demo-v8.mp4) and [v7](shipaton-demo-v7.mp4) are historical cuts.
