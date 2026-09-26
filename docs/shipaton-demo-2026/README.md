# Shipaton demo 2026

`shipaton-demo-v2.mp4` is the current submission candidate: **54s**, Android
emulator footage at 1178x2416 portrait, English captions burned in, no audio.
It shows the teach-back loop end to end on a real Android runtime: the quest
map, a TEACH BACK node (mass conservation), a text explanation, the required
re-read, Dekisugi-kun's fixed follow-up question, the 3-choice correction,
the own-words-vs-textbook comparison, and completion unlocking the next node.

The matching caption source is `shipaton-demo-v2-captions.en.srt`.

`shipaton-demo-v1.mp4` (114s) is kept only as a reference: it was captured
from the web build and does not show device footage or the teach-back loop.

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
