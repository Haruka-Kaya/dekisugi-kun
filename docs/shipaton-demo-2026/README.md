# Shipaton demo 2026

`shipaton-demo-v7.mp4` is the current submission candidate: **114s**, Android
emulator footage of the English build at 1080x1920 portrait, English captions
burned in, no audio. It opens with a hook card ("Every study app tests you. —
This one learns FROM you."), then walks the loop end to end in English: the
learning path, a lesson node whose material hides for the explanation, a typed
English teach-back, the key-term coverage panel, the fixed follow-up question,
a wrong pick costing a heart and earning a hint, the misconception record
screen ("Corrected / Still unsure"), the shareable parent report, and then a
**real purchase loop** — the Plus screen listing live Test Store packages
(Monthly $9.99 / Yearly $79.98 / Lifetime $99.99), the native Test Store
checkout dialog, entitlement confirmation, the Aurora Mantle equipped, and
the unlocked parent report — closing on a feature-summary card.

The matching caption source is `shipaton-demo-v7-captions.en.srt`.

The purchase segment is real footage of the RevenueCat SDK against the
project's **Test Store** (`test_…` public key, see
[docs/monetization-setup.md](../monetization-setup.md)) — the same SDK path a
production store uses. The 会話枠 retry banner visible after the purchase is
expected: Test Store purchases cannot be verified against the real backend,
and the app surfaces that honestly instead of faking a sync.

Earlier cuts are archived under `docs/attic/`:

- `shipaton-demo-v6.mp4` (97s) — same loop minus the real purchase segment;
  superseded by v7.
- `shipaton-demo-v4.mp4` (118s) — earlier Japanese-UI capture with the
  airplane-mode beat; the on-device claim it proves still applies.
- `shipaton-demo-v3.mp4` (68s, Japanese UI) — superseded by v6.
- `shipaton-demo-v2.mp4` (54s) — same footage minus the karte segment.
- `shipaton-demo-v1.mp4` (114s) — web-build capture, no device footage or
  teach-back loop. Do not submit it.

The video does not claim Store publication, revenue, live-AI approval, or
school deployment. Raw screen recordings stay outside the repository.

Historical capture tooling (used for the earlier cuts) lives in:

- `tools/capture-shipaton-demo-rehearsal.sh`
- `tools/verify-shipaton-demo-rehearsal.sh`
- `docs/shipaton-demo-capture.md`
