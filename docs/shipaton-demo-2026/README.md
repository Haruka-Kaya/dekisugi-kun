# Shipaton demo 2026

`shipaton-demo-v6.mp4` is the current submission candidate: **97s**, Android
emulator footage of the English build at 1080x1920 portrait, English captions
burned in, no audio. It opens with a hook card ("Every study app tests you. —
This one learns FROM you."), then walks the loop end to end in English: the
learning path, a lesson node whose material hides for the explanation, a typed
English teach-back, the key-term coverage panel, the fixed follow-up question,
a wrong pick costing a heart and earning a hint, the misconception record
screen ("Corrected / Still unsure"), the shareable parent report, and the
Dekisugi-kun Plus screen, closing on a feature-summary card.

The matching caption source is `shipaton-demo-v6-captions.en.srt`.

`shipaton-demo-v4.mp4` (118s) is the earlier Japanese-UI capture with the
airplane-mode beat; kept for reference — the airplane-mode claim it proves
(no network, fully on-device loop) still applies to the shipped build.

`shipaton-demo-v3.mp4` (68s, Japanese UI) is superseded by v6.
`shipaton-demo-v2.mp4` (54s) is the same footage minus the karte segment; its
final caption points judges to the paywall implementation
(`app/lib/screens/plus_screen.dart`) because no purchase appears on camera.

`shipaton-demo-v1.mp4` (114s) is archived at `docs/attic/shipaton-demo-v1.mp4`:
it was captured from the web build and does not show device footage or the
teach-back loop. Do not submit it.

Neither video claims Store publication, revenue, live-AI approval, purchase
success, or school deployment. Raw screen recordings stay outside the
repository and are printed by the capture script at the end of each run.

Reproduce and verify the v1 pipeline from the repository root:

```zsh
tools/capture-shipaton-demo-rehearsal.sh
tools/verify-shipaton-demo-rehearsal.sh
```

The verifier below applies to the v1 pipeline only:

- duration between 1:45 and 1:55;
- 1080x1920 H.264, `yuv420p`, constant 30fps;
- no audio stream and no selectable subtitle stream;
- English captions burned into pixels and recognized from sampled frames;
- metadata that explicitly marks the file `NOT PUBLIC SUBMISSION`;
- current device-only UI evidence and no unverified RevenueCat claim.

The timing and claim source of truth remains:

- `docs/shipaton-demo-capture.md`
- `docs/shipaton-demo-captions.en.srt`
