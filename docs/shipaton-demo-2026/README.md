# Shipaton demo rehearsal 2026

`dekisugi-on-device-rehearsal.mp4` is a **rehearsal artifact**, not the public
Shipaton submission video. It records only the deterministic, bundled,
on-device route from the current Flutter build.

It does not claim Store publication, revenue, live-AI approval, purchase
success, or school deployment. Raw Android screen recordings remain outside
the repository and are printed by the capture script at the end of each run.

Reproduce and verify from the repository root:

```zsh
tools/capture-shipaton-demo-rehearsal.sh
tools/verify-shipaton-demo-rehearsal.sh
```

The verifier requires:

- duration between 1:45 and 1:55;
- 1080x1920 H.264, `yuv420p`, constant 30fps;
- no audio stream and no selectable subtitle stream;
- English captions burned into pixels and recognized from sampled frames;
- metadata that explicitly marks the file `NOT PUBLIC SUBMISSION`;
- current device-only UI evidence and no unverified RevenueCat claim.

The timing and claim source of truth remains:

- `docs/shipaton-demo-capture.md`
- `docs/shipaton-demo-captions.en.srt`
