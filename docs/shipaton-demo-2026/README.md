# English demo — Next Gen review and introduction

**Current candidate: [shipaton-demo-v11.mp4](shipaton-demo-v11.mp4)** — 52.8 seconds,
1080×1920 portrait, 30 fps, English narration and burned-in English captions.
The matching [SRT](shipaton-demo-v11-captions.en.srt) and
[poster](shipaton-demo-v11-poster.jpg) are included. This is a local video candidate;
this change does not publish it to YouTube, Vimeo, or Devpost.

The opening shows the companion-as-student idea directly in the native app.
The edit then follows one science question: predict which ball falls first, read the evidence,
hide the material, explain in English, review key terms, answer a fixed
follow-up, and receive a hint after a wrong choice. It then shows the
companion's misconception record and optional Plus purchase and benefits.
Real typing, scrolling, choice selection, question transitions and Test Store
interactions take the place of long explanatory slides. One fixed, full native
app view fills the portrait frame, with a short heading above and English
captions below. There is no duplicate crop, animated zoom, artificial tap
effect or music. The native recording timeline is expanded to 30 fps before
cuts so sparse screen-recording frames do not skip the pre-tap state.
The hint, rewritten explanation and purchase result are held screenshots
(total 5.6 seconds); the closing card is 2 seconds. Some pauses let the viewer
read or hear the explanation; recording-source share is not a motion score.

## Evidence and limits

- App source: `11d9ae3cc1e9e6597a6206a4ab07b80f6ac49b8e` (Field Notebook).
- Captured on a dedicated Android emulator, using the English build. Some
  existing secondary labels remain Japanese. This is not physical-device QA.
- Progress comes from real native UI interactions. No database values or UI
  screens were fabricated. Cuts and modest speed changes remove waits. Held
  screenshots show only the hint and the actual rewritten explanation.
- The misconception shown remains **Still unsure**. Rewriting a free explanation
  or answering a checkpoint does not itself clear an observed need; the
  corresponding repair experiment is required. The edit does not claim a
  measured learning gain or a resolved misconception.
- The purchase uses the RevenueCat SDK against the project's **Test Store**.
  A separate fresh adult personal test profile was used for the v10 source purchase
  and benefits sequence. Its empty report does not represent the earlier
  learning sequence. The native test confirmation and local Aurora Cape grant
  were verified, the look was equipped, and the parent report was opened. No real
  charge or production-store purchase occurred. See
  [monetization setup](../monetization-setup.md).
- Server conversation-allowance synchronization was not confirmed; the app
  displayed its retry notice. The purchase footage does not claim server sync
  or enabled live conversation. A restart refreshed the cached cosmetic view.
- External generative AI was disabled. Narration is a separate, locally
  generated editorial voice, not the companion speaking in the app.

## Sources and reproduction

[Script](v11-script.json), [edit decisions](v11-edit.json), and
[manifest](v11-manifest.json) identify scene timing, source hashes, and the final
video hash. The tools and regeneration commands are in
[tools/demo-video](../../tools/demo-video/README.md).

Raw native captures, XML observations, action logs, and narration are preserved
locally at `app/build/demo-video-v10/` (ignored by Git). A new checkout must
capture its own footage or receive that source bundle; the MP4 and its captions
are directly usable without the bundle. No emulator database or account state
is part of the public artifact.

The English narration uses [Kokoro ONNX](https://github.com/thewh1teagle/kokoro-onnx)
and [Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M), locally. v11 reuses
the existing English narration and removes the synthesized music. The closing
card uses the project's current `docs/store/icon-1024.png` artwork.

## Validation

The full MP4 decodes without errors, contains 1584 frames at 30 fps, and has
ordered audio/video timestamps. All captions match the complete narration.
Each shot was compared with its original source timeline near its beginning
and end (36 frame comparisons). The fixed app view and caption layout were
inspected at all scene starts and ends. QuickTime playback reached the end;
input and follow-up screens were also sampled during playback.
Integrated loudness is -16.23 LUFS and true peak is -1.5 dBFS. Details are in
`v11-validation.json`. These checks establish timing and composition, not a
subjective guarantee about the synthetic voice or physical-device behavior.

## Why v10 was replaced

The user rejected v10's presentation. Its duplicate view and changing crops
cut text or the companion, and input seeking followed by `PTS-STARTPTS` moved
the first sparse VFR frame to the cut's beginning, skipping the pre-action
state. Full decoding and static composition checks had not caught that
viewing problem. v11 removes the duplicate view and music and uses CFR before
trimming. The longer 5.3-second frozen reflection section was replaced with
the real reread interaction and the later scroll to the follow-up button.

## Earlier edits

[v10](shipaton-demo-v10.mp4) (56.1 seconds) is retained only as an earlier,
rejected cut. [v9](shipaton-demo-v9.mp4) (93.13 seconds),
[v8](shipaton-demo-v8.mp4) (84 seconds) and [v7](shipaton-demo-v7.mp4)
(114 seconds, portrait, silent) remain for comparison. v1–v6 are historical
cuts under `docs/attic/`. The English reviewer guide carries the longer
product rationale.
