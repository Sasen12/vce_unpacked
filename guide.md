# Guide

> Context handoff. The next AI session reads this FIRST to pick up where the last one left off.
> Keep it concrete: files, commands, decisions, next steps. Update it before stopping a session.

## Status: ACTIVE (comment sweep)

## Goal

Go through the code and add internal (inline) comments in the remaining obvious places — the spots that are still uncommented or that have misplaced/duplicated doc comments.

## Progress

- **Comment sweep done (2026-08-11).** The codebase is already heavily commented; went through every source file and fixed the remaining gaps:
  - `home_screen.dart` — fixed a misplaced `///` doc comment that was attached to `_filterGeneration` (the field sat between the comment and `_applyFilters`); gave the generation counter its own comment (it's the ListView `ValueKey`, resets scroll/state on re-filter). Also fixed a stray "flutt" typo in the class doc.
  - `results_list.dart` — the doc comment above `_ItemCard` described `cardHeadline` (which already has its own doc in `study_grouping.dart`); replaced with an accurate description of the card widget.
  - `search_bar_widget.dart` — the one widget with zero comments; documented why the clear (✕) visibility reads `controller.text` at build time, and that ✕ goes through the debounce while the footer Clear cancels it (the known two-clears inconsistency).
  - `sidebar.dart` / `settings_slideout.dart` — added class-level doc comments.
  - `app_colors.dart` — noted the palette is Apple's system colors (light + dark).
- Backend (`build.py`, `extract_items.py`, `parse_docx/pdf`, `simplify`, `acronyms`, `heading_patterns`, `models`) already fully commented — no changes.
- Comment-only diff, 6 files, +36/−6. Analyzer not re-run (classifier outage mid-task; comment-only edits can't break parse/tests).
- **Prior audit context (still valid):** dataset verified clean — `backend/output/study_items.json` and `assets/data/study_items.json` byte-identical (1,749,239 bytes): 2,579 items, 12 subjects, 95 Outcome / 1,201 Key Knowledge / 813 Key Skill / 470 Command Term; zero duplicate IDs / empty required fields / `isCompleted: true` / unknown categories; exactly 470 `"unit": null` records = the 470 Command Term entries.
- **Audit findings (priority order)** delivered to user. Key user-facing risks, none currently live in the clean dataset but all latent:
  1. `lib/main.dart:14` — `await themeModel.load()` unguarded; a SharedPreferences failure before `runApp` = blank window, app never renders. Wrap in try/catch with fallback theme.
  2. Completion persistence keyed to positional IDs (`subject-category-N`, `assign_ids` in `extract_items.py`) + no dataset fingerprint stored → regenerating the dataset can silently remap a student's completion marks to different content. Fix: store a dataset hash/version with `completed_item_ids`.
  3. Manual `cp backend/output/study_items.json assets/data/study_items.json` has no guardrail → stale data ships silently. Currently in sync; add CI/prebuild diff or startup integrity check.
  4. `build.py:144-149` swallows per-file exceptions and still writes output → a broken source file ships as a silently missing subject (only a console warning).
  5. `home_screen.dart:344` — detail panel + Mark Complete hidden below 980px → completion impossible on narrower windows (toolbar count still shows).
  6. `_onCompletionChanged` (`home_screen.dart:198`) saves fire-and-forget with no error handling → failed save silently loses marks on restart.
  7. `category_tabs.dart:26-51` — empty `categories` list → `clamp(0,-1)` throw + divide-by-zero. Not reachable today (always `['All',...]`).
  8. `detail_panel.dart:181,211,220` hardcoded light colors (`0xFFE8F8E8`, `0xFF1C1C1E`) → unreadable in dark mode. Use `context` tokens.
  9. Search-bar Clear (`search_bar_widget.dart`) debounces while footer Clear cancels debounce → inconsistent.
- Multiple tool-classifier outages mid-audit (auto mode couldn't classify Bash/Agent/Workflow); read-only tools + simple grep/cmp commands got through, which is how the dataset facts above were verified.

## Decisions

- Comment sweep only — comments/doc-strings changed, no runtime logic touched.
- Prior audit: findings listed but not implemented (not requested).
- Never add `Co-Authored-By: Claude` to commits in this repo (user preference).
- Pushed directly to `main` — solo repo workflow; no PR.

## Artifacts / Current files

- `assets/data/study_items.json` — verified clean; byte-identical to `backend/output/study_items.json`.
- Comment sweep: 6 files under `lib/` (+36/−6) — `home_screen.dart`, `results_list.dart`,
  `search_bar_widget.dart`, `sidebar.dart`, `settings_slideout.dart`, `app_colors.dart`.
- `guide.md` — this handoff.

## Next steps

- Confirm the comment sweep reads well; commit if happy (no commit made yet).
- Audit fixes still open (unimplemented): #1 startup crash, #2 completion remap — suggest confirming which to implement.

<!-- CURRENT -->
<!-- /CURRENT -->

<!-- LOG -->
- 2026-08-11 08:48 — session ended
- 2026-08-11 — comment sweep: added inline comments to the last uncommented/mis-commented spots (see Progress)
- 2026-08-10 20:10 — session ended
- 2026-08-10 — full backend/dataset/app-contract audit delivered (9 prioritized findings; dataset verified clean, both JSONs byte-identical)
- 2026-08-10 19:34 — session ended
- 2026-08-09 18:48 — session ended
- 2026-08-09 18:45 — session ended
- 2026-08-09 18:40 — session ended
- 2026-08-09 18:37 — session ended
- 2026-08-09 18:35 — session ended
- 2026-08-09 18:32 — session ended
- 2026-08-09 18:06 — session ended
- 2026-08-09 — README fixes committed (`93d27dd`) and pushed to main
- 2026-08-09 17:59 — session ended
- 2026-08-09 17:56 — session ended
- 2026-08-09 11:40 — session ended
- 2026-08-09 10:22 — session ended
- 2026-08-08 23:26 — session continued after prior context compaction
- 2026-08-08 23:22 — ran app via Flutter runner in background for relaunch attempt
- 2026-08-08 23:19 — session ended
<!-- /LOG -->
