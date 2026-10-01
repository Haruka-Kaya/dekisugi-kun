# Listening human-recording assets

This directory is reserved for fixed, human-recorded Listening prompts.

- Use a flat ASCII filename: `<catalog-id>.m4a` or `<catalog-id>.wav`.
- Register the matching transcript and narrator label through
  `BundledHumanNarrationAsset`; the transcript must exactly match the fixed
  catalog prompt.
- Do not place learner recordings, transcriptions, or generated TTS output here.
- If a declared recording is missing or cannot be decoded, production falls
  back to device speech synthesis and labels that source honestly.

There are currently no human recordings in the production catalog. This file
keeps the asset directory declared without pretending that a recording exists.
