# English demo — Next Gen review and introduction

**Current candidate: [shipaton-demo-v10.mp4](shipaton-demo-v10.mp4)** — 56.1 seconds,
1920×1080 landscape, 30 fps, English narration and burned-in English captions.
The matching [SRT](shipaton-demo-v10-captions.en.srt) and
[poster](shipaton-demo-v10-poster.jpg) are included. This is a local video candidate;
this change does not publish it to YouTube, Vimeo, or Devpost.

The opening shows the companion-as-student idea directly in the native app.
The edit then follows one science question: predict which ball falls first, read the evidence,
hide the material, explain in English, review key terms, answer a fixed
follow-up, and receive a hint after a wrong choice. It then shows the
companion's misconception record and optional Plus purchase and benefits.
Real typing, scrolling, choice selection, question transitions and Test Store
interactions take the place of long explanatory slides. Short chapter headings
orient the viewer; a full native view and a synchronized crop from the same
recorded frame keep the app and its text readable. Captions have their own strip.
50.3 seconds (89.7%) come from recordings, with 3.6 seconds of held hint/rewrite
screenshots and a 2.2-second close. This measures source type, not continuous
movement in every frame. No synthetic pans or tap animations were added.

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
  A separate fresh adult personal test profile was used for the v10 purchase
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

[Script](v10-script.json), [edit decisions](v10-edit.json), and
[manifest](v10-manifest.json) identify scene timing, source hashes, and the final
video hash. The tools and regeneration commands are in
[tools/demo-video](../../tools/demo-video/README.md).

Raw native captures, XML observations, action logs, and narration are preserved
locally at `app/build/demo-video-v10/` (ignored by Git). A new checkout must
capture its own footage or receive that source bundle; the MP4 and its captions
are directly usable without the bundle. No emulator database or account state
is part of the public artifact.

The English narration uses [Kokoro ONNX](https://github.com/thewh1teagle/kokoro-onnx)
and [Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M), locally. The quiet
musical bed is synthesized by the renderer; no stock track was used. The end
card uses the project's current `docs/store/icon-1024.png` artwork.

## Validation

The final file was decoded from beginning to end; its audio and video timestamps
were checked for ordering. All ten scenes and purchase transitions were
visually inspected, and caption timing was checked against sentence-level
narration cues. Integrated loudness and peak measurements are recorded in
`v10-validation.json`. Listening quality still benefits from the viewer's final
playback review; this does not certify physical-device voice behavior.

## Earlier edits

[v9](shipaton-demo-v9.mp4) (93.13 seconds) and
[v8](shipaton-demo-v8.mp4) (84 seconds) remain available for comparison. v10
shortens the current demo and replaces most screenshot holds with recorded
interactions. The English reviewer guide carries the longer product rationale.


`shipaton-demo-v7.mp4` (114 seconds, portrait, silent) remains available for
comparison. v1–v6 are historical cuts under `docs/attic/`.
`docs/shipaton-demo-capture.md` and the earlier rehearsal scripts describe the
historical capture workflow; v8/v9/v10 use the tools above.
