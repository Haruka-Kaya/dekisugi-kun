---
name: testing-dekisugi-kun-e2e
description: How to run and E2E-test the dekisugi-kun Flutter app locally (local catalog mode, game path navigation, text input, English i18n verification via server code path)
---

# dekisugi-kun E2E testing (Flutter web)

## Launch

```bash
cd app && ~/sdk/flutter/bin/flutter run -d chrome --web-port=7357   # tty session if you want hot-reload keys
```

- Use a **tty** `exec` session if you may need `r`/`R` hot reload/restart later; a piped/non-interactive run cannot receive keys.
- A "Chrome for Testing" window opens. Maximize it: `wmctrl -l | grep デキすぎ君` → `wmctrl -i -r <id> -b add,maximized_vert,maximized_horz`.
- Note: Flutter web runs CPU-only rendering (webGLVersion -1 warning is normal on this box).

## Entering the app (no server needed)

- Consent screen → scroll to bottom → button「通信しない端末内モードを使う」. This creates `UnitsClient(baseUrl: '')` which loads the **bundled** catalog `app/assets/catalog/units.ja.json` (schemaVersion must match; currently 10). No backend required — perfect for catalog-content PRs.
- The real "mission list" is the path tab (学ぶ) plus the 物語/練習/記号 tabs. `UnitPickerScreen` is effectively dead code in local mode.

## Navigating the game path (~170 nodes, catalog order)

- Fresh install marks every node `locked` except the first uncleared one — you cannot open later units for testing.
- Temp-patch `app/lib/learning/services/game_path_projection.dart` `_requiredState`: return `GamePathNodeState.available` instead of `locked` (revert after!).
- **Fastest way to a late unit**: also temp-patch `currentRequiredId` to `'path:v1:{unitId}:{conceptKey}:lesson'` — the path auto-scrolls to the current node on load.
- Wheel-scroll works at 100% browser zoom but **stalls at zoomed-out levels**; scroll at 100% or use the current-node patch instead. Keyboard End/PageDown and scrollbar drags do not work reliably.
- Node order per concept: lesson(flask) → practice(arrows) → story(book) → listening(headphones) → speaking(mic) → challenge.
- Concept-local tabs: 物語 = stories list (CASE numbers), 記号 = notation lab tasks grouped by unit, 練習 = practice hub. These compact lists are good proof that a unit's content rendered.

## Text input on Flutter web

- `type` action with **Japanese text does not register** in Flutter web text fields (counter stays 0). Use ASCII/romaji — free-text fields are not graded (入力は保存・送信・自動採点しません).

## English / i18n

- There is **no in-app language switch**. English is server-side only: `server/lib/i18n.ts` exposes `localizeUnit(unit,'en')`, `missingTranslations(units, misconceptions)`, used by `/api/units?lang=en`.
- Verify EN coverage without a server:
  ```bash
  cd server && node --import tsx -e "
    import('node:module').then(async (m) => {
      const mod = await import('./lib/i18n.ts'); /* adjust exports */
      // missingTranslations(...) -> [] and localizeUnit serialized has no JA chars
    })"
  ```

## Testing flow tips

- Lesson node (TEXT LAB): predict (≥1 char) → material (STEP 2) → self-compare (needs 残す点/直す点 selection + ≥1 char) → +10XP.
- Story node (CASE): acts, then a 3-option judgment; wrong answer shows that option's hint and costs a heart; correct proceeds to comparison/complete.
- Practice node (DIAGRAM LAB): pick an option → reason text → compare.
- State resets on every `flutter run` restart (fresh consent screen). Story/practice progress persists in-memory only.
