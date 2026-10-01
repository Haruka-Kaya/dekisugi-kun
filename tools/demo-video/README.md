# Native English demo tooling

These tools produced the v8, v9, v10 and v11 English demos from real
native Android captures. They never seed app progress or alter the emulator
database. Run from the repository root. macOS was validated with Python 3.14.6,
FFmpeg 8.1 (`ffmpeg-full`, including libass), and the built-in Avenir Next font.
Use `render.py --ffmpeg /path/to/ffmpeg --font /path/to/font.ttc` to override
paths. The font file must provide the bold and medium faces at indexes 0 and 5.

## Capture

Use a dedicated emulator serial. Do not run these against an unrelated device.

```bash
python3 tools/demo-video/capture.py --serial emulator-5560 --output app/build/demo-video-v8 snapshot lesson
python3 tools/demo-video/capture.py --serial emulator-5560 --output app/build/demo-video-v8 tap 'Teach by text'
python3 tools/demo-video/capture.py --serial emulator-5560 --output app/build/demo-video-v8 record explain
python3 tools/demo-video/capture.py --serial emulator-5560 --output app/build/demo-video-v8 stop
```

`snapshot` saves native accessibility XML and pixels. `tap` observes the UI
before selecting an enabled target, with optional `--kind button` or `edit`.
For a text field with merged semantics, `--before` can name its following
button. `text` accepts ASCII only and requires an open native keyboard.
To replace text, long-press the observed field with `tap --long`, inspect the
native selection menu, and tap **Select all**. `tap-point x,y` is a fallback
only for a coordinate confirmed in the most recent screenshot. Flutter can
merge an entire card's accessibility bounds, so a label match does not prove
the tap hit its nested button; observe the result after every action.

Keep screenshot names unique and retain action logs. `record` refuses to start
if another recorder is running; `stop` pulls the owned recording. Raw captures
may include delays and transitions; the edit decisions select useful parts.

Build the current app with the project-pinned Flutter SDK, `APP_LANG=en`, and
no `DEKISUGI_COMPANION_REMOTE` flag. Use offline on-device mode for the teaching
sequence. For the separate purchase sequence, use an adult personal test
profile and RevenueCat Test Store build flags from `docs/monetization-setup.md`.
Only press **Test valid purchase** in the native **Test Store Purchase** dialog;
do not substitute a real store checkout. Leave external generative AI disabled.
The Listening lesson in the captured build required an installed offline
Japanese TTS voice because its native narration request defaults to `ja-JP`.
The editorial English voice below is independent of that app narration.

## Narrate and render

Create a local Python environment and install `requirements.txt`. Download the
`kokoro-v1.0.onnx` and `voices-v1.0.bin` files linked by the
[Kokoro ONNX example](https://github.com/thewh1teagle/kokoro-onnx/blob/main/examples/save.py)
to a local model folder. This is local inference, with no API key or cloud fee.
The model is [Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M).

```bash
python tools/demo-video/narrate.py docs/shipaton-demo-2026/v8-script.json   --models /path/to/models --output app/build/demo-video-v8/narration
python tools/demo-video/render.py   docs/shipaton-demo-2026/v8-script.json docs/shipaton-demo-2026/v8-edit.json   --raw app/build/demo-video-v8 --output docs/shipaton-demo-2026
```

`narrate.py` creates sentence-level audio and caption cues. It adapts ONNX
`speed` input to the declared model type to accommodate the 0.4.6 exporter
mismatch. `render.py` crops only device system bars, fits actual UI in a phone
frame, and places editorial text and enlarged actual details beside it.
Screenshots are held where needed for readability. It synthesizes an original,
quiet musical bed, normalizes narration, burns English captions into their own
strip, and outputs an MP4, SRT, poster, and source hash manifest. Audio and video
timestamps are normalized per scene before decoded concatenation to prevent AAC
boundary drift and filter reinitialization.
Use `--preview 04-explain` to inspect a scene composition without rendering all.

## Verify a new edit

Check the full FFmpeg decode exit code, ordered audio/video DTS, duration under
120 seconds, the intended 1080p orientation at 30 fps, and stereo AAC. Inspect each scene, the first
and last frames, and every purchase transition. Check captions for ordering,
readable holds, and agreement with narration cues. Measure integrated loudness
and true peak, and listen to the final playback before public submission.
Never label emulator capture or metadata checks as physical-device acceptance.

The checked v8 measurements and hashes are in
`docs/shipaton-demo-2026/v8-validation.json`. The local retained source bundle
is `app/build/demo-video-v8/`; raw footage and models are not committed.

## Regenerate the Next Gen cut

With the retained native v9 source files in `app/build/demo-video-v9/`:

```bash
python3 tools/demo-video/narrate.py docs/shipaton-demo-2026/v9-script.json \
  --models /path/to/local/kokoro-models --output app/build/demo-video-v9/narration
python3 tools/demo-video/render.py docs/shipaton-demo-2026/v9-script.json \
  docs/shipaton-demo-2026/v9-edit.json --raw app/build/demo-video-v9 \
  --output docs/shipaton-demo-2026 --name shipaton-demo-v9 --poster-time 3
```

`--name` chooses output names without overwriting the previous cut. Relative
raw/output paths are resolved before FFmpeg concat files are written. The v9
script, edit, manifest and validation sit alongside the final video.

## Regenerate the motion-first cut

v10 uses retained learning recordings from v8 and freshly recorded Test Store,
equip and parent-report interactions in `app/build/demo-video-v10/`.
The Plus run uses a separate fresh adult personal profile; its empty report
is a feature demonstration, not the learning run's progress. Native UI alone
creates progress and grants; no database values are seeded.

```bash
python3 tools/demo-video/narrate.py docs/shipaton-demo-2026/v10-script.json \
  --models /path/to/local/kokoro-models --output app/build/demo-video-v10/narration \
  --lead .12 --gap .08 --speed 1.06
python3 tools/demo-video/render_motion.py docs/shipaton-demo-2026/v10-script.json \
  docs/shipaton-demo-2026/v10-edit.json --raw app/build/demo-video-v10 \
  --output docs/shipaton-demo-2026
```

`render_motion.py` splits each recorded frame into a full native view and its
synchronized detail crop. It adds no artificial pans, tap indicators or UI
transitions. `start`, `duration`, `speed`, and `crop` in the edit file select
recorded actions and remove waits. Narration must finish within each scene;
the renderer fails rather than extending the scene with a frozen last frame.
Only the hint, rewritten explanation, and short closing card are held still.
Defaults in `narrate.py` retain the v8/v9 pacing; v10 explicitly shortens gaps.
The manifest distinguishes recording-source seconds from screenshot holds;
recording-source share does not mean every frame contains movement.

## Current single-view cut (v11)

v11 reuses the v10 source bundle and narration, and removes the duplicate detail
view and synthesized music. It exports 1080×1920 portrait at 30 fps. Source
recordings may be VFR: **expand the original timeline with `fps=30:start_time=0`
before trimming**, then reset PTS. Input seeking followed by `PTS-STARTPTS`
can move the next sparse frame to the start and remove the tap-before state.
The renderer keeps a fixed full app viewport; only Android system bars are
cropped. Typing is 1.25x; the other native clips play at their captured speed.

```bash
python3 tools/demo-video/narrate.py docs/shipaton-demo-2026/v11-script.json \
  --models /path/to/local/kokoro-models --output app/build/demo-video-v10/narration \
  --lead .12 --gap .08 --speed 1.06
python3 tools/demo-video/render_single.py docs/shipaton-demo-2026/v11-script.json \
  docs/shipaton-demo-2026/v11-edit.json --raw app/build/demo-video-v10 \
  --output docs/shipaton-demo-2026
```

Only native hint, rewrite and Test Store result screenshots are held. The
manifest identifies all raw-source hashes; `v11-validation.json` includes
frame comparisons against the original source timeline at the beginning and
end of every shot. Recording-source share is not used as a motion-quality score.
