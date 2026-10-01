# English demo — review and introduction

**Current candidate: [shipaton-demo-v8.mp4](shipaton-demo-v8.mp4)** — 84.17 seconds,
1920×1080 landscape, 30 fps, English narration and burned-in English captions.
The matching [SRT](shipaton-demo-v8-captions.en.srt) and
[poster](shipaton-demo-v8-poster.jpg) are included. This is a local video candidate;
this change does not publish it to YouTube, Vimeo, or Devpost.

The edit follows one idea: predict which ball falls first, read the evidence,
hide the material, explain in English, review key terms, answer a fixed
follow-up, and receive a hint after a wrong choice. It then shows the
companion's misconception record and optional Plus purchase and benefits.
Large editorial headings explain the purpose of each step; actual native app
footage and enlarged details show the interaction. Captions have their own
strip and never cover the app.

## Evidence and limits

- App source: `11d9ae3cc1e9e6597a6206a4ab07b80f6ac49b8e` (Field Notebook).
- Captured on a dedicated Android emulator, using the English build. Some
  existing secondary labels remain Japanese. This is not physical-device QA.
- Progress comes from real native UI interactions. No database values or UI
  screens were fabricated. Cuts and held screenshots shorten the interaction.
- The misconception shown remains **Still unsure**. Rewriting a free explanation
  or answering a checkpoint does not itself clear an observed need; the
  corresponding repair experiment is required. The edit does not claim a
  measured learning gain or a resolved misconception.
- The purchase uses the RevenueCat SDK against the project's **Test Store**.
  The native test confirmation was completed, the local Aurora Cape grant was
  verified, the look was equipped, and the parent report was opened. No real
  charge or production-store purchase occurred. See
  [monetization setup](../monetization-setup.md).
- Server conversation-allowance synchronization was not confirmed; the app
  displayed its retry notice. The purchase footage does not claim server sync
  or enabled live conversation. A restart refreshed the cached cosmetic view.
- External generative AI was disabled. Narration is a separate, locally
  generated editorial voice, not the companion speaking in the app.

## Sources and reproduction

[Script](v8-script.json), [edit decisions](v8-edit.json), and
[manifest](v8-manifest.json) identify scene timing, source hashes, and the final
video hash. The tools and regeneration commands are in
[tools/demo-video](../../tools/demo-video/README.md).

Raw native captures, XML observations, action logs, and narration are preserved
locally at `app/build/demo-video-v8/` (ignored by Git). A new checkout must
capture its own footage or receive that source bundle; the MP4 and its captions
are directly usable without the bundle. No emulator database or account state
is part of the public artifact.

The English narration uses [Kokoro ONNX](https://github.com/thewh1teagle/kokoro-onnx)
and [Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M), locally. The quiet
musical bed is synthesized by the renderer; no stock track was used. The end
card uses the project's current `docs/store/icon-1024.png` artwork.

## Validation

The final file was decoded from beginning to end; its audio and video timestamps
were checked for ordering. All nine scenes and purchase transitions were
visually inspected, and caption timing was checked against sentence-level
narration cues. Integrated loudness and peak measurements are recorded in
`v8-validation.json`. Listening quality still benefits from the viewer's final
playback review; this does not certify physical-device voice behavior.

## Earlier edits

`shipaton-demo-v7.mp4` (114 seconds, portrait, silent) remains available for
comparison. v1–v6 are historical cuts under `docs/attic/`.
`docs/shipaton-demo-capture.md` and the earlier rehearsal scripts describe the
historical capture workflow; v8 uses the tools above.
