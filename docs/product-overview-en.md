# Dekisugi (AI デキすぎ君) — product overview for judges

*English companion to the Japanese README. Written for Shipaton 2026 Next Gen
Award reviewers who cannot read Japanese.*

## The idea in one sentence

**Students learn science by teaching it to an AI companion that never answers
first** — the app only ever stores what the *student* changed in the
companion's understanding.

Most AI study products put a chatbot between the learner and the answer:
type a question, get a fluent explanation, feel like you learned something.
Decades of learning-science results point the other way — the durable gains
come from *producing* an explanation (self-explanation, retrieval practice,
the protégé effect), not from receiving one. Dekisugi inverts the interface
accordingly: the AI companion デキすぎ君 is the student, and you are the
teacher.

## The core loop (one mission ≈ 3 minutes)

1. **Read** a compact lesson page for one science concept.
2. **Predict** the outcome of a concrete case before seeing the answer.
3. **Explain** — the lesson is *hidden* at this point (by design rule C2).
   Voice and text are equal first-class paths; a voice explanation must be
   replayed, a text one explicitly re-read, before continuing.
4. **Checkpoint** — the companion asks one *fixed, cataloged* follow-up
   question per concept. There is no free-form grading of student writing.
5. **Hint-and-retry** — a wrong answer records a canonical misconception and
   costs a heart, but never reveals the answer. The learner gets a scientific
   hint and must explain again.

## The misconception map (理解カルテ)

The distinctive asset under the hood is a **canonical misconception catalog**:
32 entries (M01–M32), one per concept, each pairing the classic textbook
misconception ("a stationary object has no forces on it") with the correct
understanding, plus a probe phrasing the companion uses to *elicit* the
misconception rather than guess it.

The カルテ ("chart/record") screen — reachable from the profile tab — surfaces
this as a map of the companion's beliefs, not a report card of the student's
weaknesses:

- each concept card shows the misconception デキすぎ君 currently holds;
- observed gaps appear as labeled work items ("仕組みの土台", "条件の整理",
  notation skills, …) derived only from cataloged need codes — never from
  free text;
- resolved items flip to 訂正できた ("corrected by your explanation") and
  display the canonical correct understanding as the student's achievement.

This is what makes the pedagogy visible: progress is literally "beliefs of
the AI corrected", which is the protégé effect made legible. Privacy-wise the
record is minimal — the note on screen states that answer text and voice are
not retained in the shipped build; only cataloged misconception codes and
their resolution events persist.

## Product constitution (C1–C9)

`AGENTS.md` pins nine invariants that every feature must respect, e.g.:

- **C2** hide the material during explanation;
- **C5** never make points/currency the main driver (intrinsic motivation);
- **C8** text input is a first-class path equal to voice;
- **C9** never tell the learner "this is your weakness" — elicit and observe
  instead.

These rules, not growth-hack metrics, are the design contract.

## Safety posture for minors

- All learning content is bundled in the app; the core loop works fully
  offline with no account.
- External generative-AI endpoints are disabled in production (503) pending a
  provider contract that permits minors — the companion's lines are cataloged,
  not generated live.
- One carefully scoped generative path exists: `/api/companion-line` produces
  only the short opening line of the companion's reply (the question and its
  choices stay verbatim catalog). It sends only the student's explanation
  text, heard keywords, and the unit label — never the answer, choices, lure,
  name, or voice — through our own server (the API key never ships to the
  device), is disclosed in the in-app consent text, and falls back
  deterministically to the cataloged line. It ships dark until a provider key
  is configured, and is a **Plus supporter perk** on the client.
- Voice audio and free text stay in RAM; the device stores only lesson IDs,
  misconception codes, hearts, and progress.
- Optional **Plus** (RevenueCat) is a supporter plan — it grants the
  Aurora Mantle companion skin, the generated-AI reply preface above, and a
  parent-facing karte report; no learning content is ever gated.

## Language

The product is fully bilingual — Japanese and English. Every user-facing
string has a canonical English build: the catalog content (lesson material,
practice prompts, checkpoint lures and options, stories, notation tasks) is
localized in `server/lib/i18n.ts` + `server/lib/en/` and machine-generated
into `app/assets/catalog/units.en.json`; UI chrome strings are bilingual via
`app/lib/config/app_language.dart`. `flutter run --dart-define=APP_LANG=en`
or the in-app language toggle runs the whole product in English, and
`/api/units?lang=en` serves the English catalog. Coverage tests
(`missingContentTranslations`, `missingTranslations`) fail the build on any
untranslated key — a partial-English build cannot ship.

## Content & platform

- 11 units / 32 concepts aligned to Japan's MEXT national science curriculum,
  each with curriculum page references.
- Flutter app (Android/iOS/desktop/web) + a small TypeScript server on Vercel
  for catalog sync and entitlement re-verification.
- ~1,260 client tests and ~400 server tests; the misconception catalog is
  linted by `tools/misconception-survey/check_items.py`.
- The misconception items come from an elicitation survey administered to
  real middle/high-school students (delivery UI in `server/public/survey`,
  analysis in `tools/misconception-survey/analyze.py`, n=18 responses so
  far) — the karte's "32 beliefs" are what actual students actually
  misbelieve, not invented distractors. The karte screen states this
  provenance to its users.
