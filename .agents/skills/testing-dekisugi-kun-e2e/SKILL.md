---
name: testing-dekisugi-kun-e2e
description: How to run and E2E-test the dekisugi-kun Flutter app locally (local catalog mode, game path navigation, text input, English i18n verification via server code path)
---

# dekisugi-kun E2E testing (Flutter web)

## Android emulator variant (emulator-5554)

- adb lives at `~/android-sdk/platform-tools/adb` (not on PATH). Build: `cd app && ~/sdk/flutter/bin/flutter build apk --debug` (incremental ~7s). Install: `adb -s emulator-5554 install -r app/build/app/outputs/flutter-apk/app-debug.apk` — preserves app data/DB.
- Relaunch: `adb shell am force-stop jp.dekisugi.dekisugi && adb shell am start -n jp.dekisugi.dekisugi/.MainActivity`. Onboarding (年齢→端末内モード) re-appears after reinstalls even when the DB persists — just redo it (15歳以下 → 通信しない端末内モードを使う at ~device 590,2240 after scrolling).
- Input: `adb shell input tap/swipe X Y` uses **device pixels** (1179x2556 when `wm size 1179x2556` override is set). `adb exec-out screencap -p` captures at the SAME 1179x2556 — coords are 1:1 (preview at ÷3 for quick viewing).
- The karte/profile screens' header row (incl. ← back) is **inside the scrollable ListView** — it scrolls off; use `adb shell input keyevent KEYCODE_BACK` (system back → maybePop) instead.
- The emulator window is **aspect-locked** — `wmctrl` maximize won't fullscreen it; resize to ~342x760 max (portrait). That's fine for recording since adb screencaps give full-res proof.
- DB inspection/seeding: `adb shell run-as jp.dekisugi.dekisugi sqlite3 /data/data/jp.dekisugi.dekisugi/databases/dekisugi.db '<SQL>'`. `learning_need_state` PK is (scope,skill_id,need_code); resolved rows have resolved_day/resolved_at set, active rows have them NULL.
- **Cosmetic grant tests**: `learning_cosmetic_loadout` equips a product into a slot. If you delete a grant in `learning_cosmetic_grants` while it's still equipped in the loadout, app launch bricks with「学習パスを準備できませんでした」— always delete BOTH rows (or neither) to get a clean "never owned" state, and restore both afterward.
- **Paywall reachable on Android** (unlike web): build with `--dart-define=REVENUECAT_USE_TEST_STORE=true --dart-define=REVENUECAT_TEST_PUBLIC_SDK_KEY=test_<anything>` → `PurchaseConfig.enabled=true` → 設定→Plus row and karte「Plusを見る」entries appear, and the store can't reach a real RC backend → genuine fail-closed「ストアの情報を確認できません」state.
- **Japanese text on Android**: `ime set com.android.adbkeyboard/.AdbIME` then `am broadcast -a ADB_INPUT_TEXT --es msg '日本語'` inserts into the focused field (restore with `ime set <orig>`). `ADB_CLEAR_TEXT` broadcast is unreliable — instead tap field → long-press → tap「すべてを選択」→ broadcast replaces the selection. Buttons below the fold: `input swipe` the *content* up, not the whole screen.
- **Speak-lab coverage quirk**: the re-read/submit button needs a fresh coverage evaluation — preserved text starts DISABLED; edit (e.g. append 。) to re-enable. After a wrong answer the hint card offers「ヒントを使って、同じ方法で言い直す」→ revision route →「言い直しを終えて、教材と比べる」→ compare →「比較を終えて、進捗だけ記録」→ SPEAK LAB COMPLETE.
- The karte 保護者レポート card only renders with a Plus entry (`onOpenPlus` non-null, i.e. online/store-capable builds); supporter state = aurora cosmetic grant present, not RC entitlement.

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
- **Japanese works via CDP `Input.insertText`**: `npm i playwright-core` (no browser download), `chromium.connectOverCDP('http://localhost:29229')`, then `page.keyboard.insertText('日本語…')` after clicking the field with a real mouse click. The Devin automated Chrome exposes CDP on port 29229.

## CDP screenshots at exact sizes (Devpost/store assets)

- Serve the app headless: `flutter run -d web-server --web-port=7357` (no extra Chrome window), open the tab in the Devin Chrome via `curl -X PUT http://localhost:29229/json/new?URL`.
- `page.setViewportSize({width:1179, height:2556})` then `page.screenshot()` produces a viewport-only PNG at the exact pixel size — no browser chrome, no device frame. Restore with `setViewportSize({width:1600,height:1122})` afterward.

## English / i18n

- **In-app EN build** (bilingual since en-content branch): `--dart-define=APP_LANG=en` sets the default; `app/lib/config/app_language.dart` `t(ja,en)` wraps ~750 UI strings. Settings has a Language/表示言語 SegmentedButton that persists `app_lang` in the `settings` table — the saved row overrides the dart-define, so `DELETE FROM settings WHERE key='app_lang'` restores neutral state for dart-define builds.
- EN catalog is `app/assets/catalog/units.en.json`; `UnitsClient` loads per-language bundled asset (`units.$lang.json`) + `?lang=` server param, cached under `units.v10.{lang}.*` keys.
- **Catalog decode gotcha**: `UnitDetail.fromJson` requires every `concept.storyTitle == section.scienceStory.title` — one mismatch nulls that unit; ALL units failing → bundled catalog silently rejected → `list()` returns `[]` → path shows「Could not load the learning path」(the same error UI also covers `game==null`/empty catalog — no exception needed). Verify offline with a throwaway `flutter test` that calls `UnitDetail.fromJson` per catalog unit — faster than rebuilding APKs. JA `settings` row + relaunch is a quick control to prove EN-specific failure.
- Server-side EN coverage (if needed): `server/lib/i18n.ts` `localizeUnit(unit,'en')` / `missingTranslations(...)`.

## Testing flow tips

- Lesson node (TEXT LAB): predict (≥1 char) → material (STEP 2) → self-compare (needs 残す点/直す点 selection + ≥1 char) → +10XP.
- Story node (CASE): acts, then a 3-option judgment; wrong answer shows that option's hint and costs a heart; correct proceeds to comparison/complete.
- Practice node (DIAGRAM LAB): pick an option → reason text → compare.
- Activity-screen ← exit button sits at the **left edge of the centered readable-width row** (~324,95 at 1024×768) — not the screen edge; clicking ~335,110 misses it. There is no other in-activity exit; finishing the activity returns to the path automatically.
- Match Lab / Lightning modes live at the **bottom of the 練習 hub** (scroll); they open even with 0 gems (「結晶なしで遊べます」). The 💎 gems chip in the status bar opens the economy/cosmetic sheet (Pathマスコット picker inside).
- **Plus screen is unreachable on web** — `PurchaseService` is only provided in the online tree, and every entry gates on `enabled` (always false on web). To verify the screen/fallback, temp-patch `main.dart` `_openLocalSettings` to pass `onOpenPlus` that pushes `PlusScreen` with a directly-constructed `RevenueCatPurchaseService(config: RevenueCatPurchaseConfig.fromEnvironment(), identity: DeviceIdentity(baseUrl: widget.serverUrl, store: routeContext.read<SessionStore>()), adapter: RevenueCatPurchaseAdapter())`. Do NOT `read<PurchaseService>()` inside the pushed route — the provider doesn't exist in local mode → red screen. `fromEnvironment` returns disabled config on web, so the real 「このビルドではストア購入が設定されていません」 fallback renders.
- State resets on every `flutter run` restart (fresh consent screen). Story/practice progress persists in-memory only.
