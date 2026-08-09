# VCE Unpacked

Flutter desktop app that turns VCE study design documents into a
searchable, plain-language browser: pick a subject, filter by
outcome/key knowledge/key skill/command term, see official wording next
to a plain-language rewrite.

Two parts, connected only by a generated JSON file — the backend never
runs at app runtime:

- **`backend/`** — offline Python pipeline. Converts source
  `.docx`/`.pdf` study design files into `study_items.json`. Run
  manually. See [backend/README.md](backend/README.md).
- **`lib/`** — Flutter app. Reads the bundled `study_items.json` at
  startup.

## Architecture

```mermaid
flowchart LR
    A[("VCAA study design files<br/>.docx / .pdf")]

    subgraph BE["BACKEND — Python, run offline"]
        direction TB
        B["Parsing<br/>parse_docx.py · parse_pdf.py"]
        C["Extraction<br/>extract_items.py"]
        D["Simplification<br/>simplify.py · acronyms.py"]
        B --> C --> D
    end

    E[("study_items.json")]

    subgraph FE["FRONTEND — Flutter app"]
        direction TB
        F["Data layer<br/>StudyDataRepository · PreferencesRepository"]
        L["Logic layer<br/>study_filter · study_grouping"]
        G["State layer<br/>HomeScreen"]
        H["UI layer<br/>Sidebar · ResultsList · DetailPanel"]
        F --> G
        L --> G
        L --> H
        G --> H
    end

    A --> B
    D --> E
    E --> F

    classDef store fill:#fff,stroke:#333,stroke-width:2px,color:#000
    classDef tier fill:#f7f7f7,stroke:#666,stroke-width:1px,color:#000
    class A,E store
    class B,C,D,F,L,G,H tier
    style BE fill:#fff,stroke:#999,stroke-width:1px,stroke-dasharray: 4 4,color:#000
    style FE fill:#fff,stroke:#999,stroke-width:1px,stroke-dasharray: 4 4,color:#000
    linkStyle default stroke:#555,stroke-width:1.5px
```

The two sides never talk to each other directly — `study_items.json` is
the entire interface. The backend doesn't run when the app runs, and
the app has no code path back into the backend; it only ever reads
that one file, once, at startup.

Inside the backend pipeline:

1. `parse_docx.py` / `parse_pdf.py` — source file → `RawBlock` list (text + heading level).
2. `extract_items.py` — `RawBlock` list → `StudyItem` list (Outcome / Key Knowledge / Key Skill / Command Term).
3. `simplify.py` — fills in `plain_language_text` (TF-IDF extraction + jargon substitution + spaCy clause splitting).
4. `acronyms.py` — expands bare acronyms using definitions found elsewhere in the same subject.
5. `attach_shared_glossary` (in `extract_items.py`) — copies the shared VCAA command-term
   glossary (`source_docs/GlossaryOfCommandTerms.docx`) onto every subject whose study design
   has no embedded glossary, so the Command Term filter works for all 12 subjects.
6. `build.py` — writes the combined result to `output/study_items.json`.
7. Copy that file over `assets/data/study_items.json` (manual step) and the Flutter app picks it up at next launch.

No LLM, no API calls anywhere in the backend — scikit-learn
(TF-IDF/cosine similarity) and spaCy (`en_core_web_sm`, a small
statistical parser) only. Full explanation of each stage, known
limitations, and fixed bugs is in [backend/README.md](backend/README.md).

To refresh the dataset after adding/updating source files:

```bash
cd backend && source .venv/bin/activate && python -m ingest.build
cd .. && cp backend/output/study_items.json assets/data/study_items.json
```

That copy is the whole interface between the two halves and is easy to
forget — the app then ships stale content with no warning. After
re-running the pipeline, verify the two files are in sync:

```bash
diff -q backend/output/study_items.json assets/data/study_items.json
```

## Features

- **Subject sidebar** — derived from whatever subjects are in the
  bundled dataset, not hardcoded.
- **Search** — full-text, across title/official text/plain-language
  text, debounced 200ms.
- **Category filter** — segmented control (Outcome / Key Knowledge /
  Key Skill / Command Term); pills are derived from the selected
  subject's data, and Command Term data exists for every subject — from
  the study design's embedded glossary where it has one, otherwise from
  the shared VCAA command-term glossary.
- **Grouped results list** — Unit → Area of Study headers, natural
  reading order; category-colored accent per card; `ListView.builder`
  so only visible cards get built.
- **Detail panel** — official text + plain-language rewrite side by
  side; shows a note instead of a duplicate when there's nothing to
  simplify; toggle to mark an item complete.
- **Completion tracking** — toolbar chip, persisted via
  `SharedPreferences`.
- **Light/dark theme** — persisted via `SharedPreferences`.

## Project structure

```
lib/
├── main.dart                        # App entry point, theme wiring
├── models/
│   └── study_item.dart              # StudyItem data model + fromJson
├── logic/
│   ├── study_filter.dart            # Pure three-axis filter (subject, category, search)
│   └── study_grouping.dart          # Results-list row grouping (Unit/AoS/Glossary) + card headlines
├── data/
│   ├── study_data_repository.dart   # Loads assets/data/study_items.json
│   └── preferences_repository.dart  # Persists completion status + dark mode
├── theme/
│   ├── app_colors.dart              # Light/dark color tokens
│   ├── category_colors.dart         # Per-category accent colors
│   └── theme_model.dart             # ChangeNotifier for theme state
├── screens/
│   └── home_screen.dart             # Three-pane layout, state, filter wiring
└── widgets/
    ├── sidebar.dart                  # Subject list
    ├── search_bar_widget.dart
    ├── category_tabs.dart            # Segmented-control category filter
    ├── results_list.dart             # Grouped, filtered result cards (ListView.builder)
    ├── detail_panel.dart             # Selected item detail view
    ├── settings_slideout.dart        # Theme toggle panel
    └── loading_screen.dart           # Startup loading state
assets/data/
└── study_items.json                 # Generated dataset (copied from backend/output/)
backend/
├── ingest/
│   ├── models.py                    # RawBlock / StudyItem dataclasses
│   ├── heading_patterns.py          # VCAA heading regexes, glossary-table filtering
│   ├── parse_docx.py                # .docx -> RawBlock list
│   ├── parse_pdf.py                 # .pdf -> RawBlock list
│   ├── extract_items.py             # RawBlock list -> StudyItem list
│   ├── simplify.py                  # official_text -> plain_language_text
│   ├── jargon_dictionary.json       # word/phrase -> plain-language map
│   ├── acronyms.py                  # cross-item acronym expansion
│   └── build.py                     # CLI entry point
├── scripts/
│   └── analyze_vocabulary.py        # jargon dictionary authoring aid
├── source_docs/                     # .docx/.pdf study design files (gitignored)
└── output/study_items.json          # Pipeline output
```

## Language notes

Dart has no `public`/`private`/`protected` keywords. Its access
modifier is a naming convention: a leading underscore (`_isDark`,
`_HomeScreenState`, `_applyFilters`) makes a member private to its own
library (file); everything else is public by default. Used
consistently throughout `lib/` — see
[theme_model.dart](lib/theme/theme_model.dart) for a concrete example
(private `_isDark` field, exposed only via a read-only `isDark` getter
and a `toggleTheme()` method).

## Current state

- Dataset: 2,579 items across 12 subjects (Applied Computing, Business
  Management, Data Analytics, English EAL, Foundation Mathematics,
  General Mathematics, Mathematical Methods, Media, Philosophy,
  Physics, Software Development, Specialist Mathematics), generated
  from 7 real VCAA study design files plus the shared VCAA command-term
  glossary (95 Outcomes, 1,201 Key Knowledge, 813 Key Skill, 470
  Command Term). Every subject has Command Term data — its own embedded
  glossary where the study design has one, otherwise the shared one.
- Category pills (Outcome / Key Knowledge / Key Skill / Command Term)
  are derived from each subject's data, not hardcoded; switching
  subject resets the filter when the previous category doesn't exist
  for it.
- Completion status + dark-mode preference persist via
  `PreferencesRepository`; everything else is in-memory `setState`,
  re-read fresh from the bundled asset every launch.
- Three-column desktop layout (220px sidebar, 35%-width detail panel)
  with responsive breakpoints: the sidebar drops below 700px and the
  detail panel below 980px. Built desktop-first; no touch/gesture
  adaptations for phones.
- Plain-language rewrites are rule-based (extractive + substitution +
  clause-splitting), not true paraphrasing — see
  [backend/README.md](backend/README.md) for known limitations.

## Getting started

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(Dart SDK `^3.7.2`, per `pubspec.yaml`).

```bash
flutter pub get
flutter run
```

Platform scaffolding for Android/iOS/web/macOS/Linux/Windows is
included. `flutter devices` to list targets, `flutter run -d macos` /
`-d chrome` / etc. to target one.

### Tests

```bash
flutter test
```
