# Ingestion pipeline

Converts raw VCE study design files (.docx / .pdf) into the JSON dataset
the Flutter app displays, with a plain-language rewrite generated for
each item.

This is an **offline pipeline**, not a running server: you run it
locally whenever you have new/updated study design files, then copy the
output over the Flutter app's bundled asset (`../assets/data/study_items.json`)
and commit both. The Flutter app just reads that JSON at startup, it
never talks to this code at runtime.

```
source_docs/          <- the committed .docx / .pdf study design files
  GlossaryOfCommandTerms.docx  <- required shared glossary
  subjects.json        <- optional: {"filename.docx": "Display Subject Name"} overrides
output/
  study_items.json      <- generated dataset (copy this to ../assets/data/, see Usage)
ingest/
  models.py             <- RawBlock / StudyItem data shapes
  heading_patterns.py    <- shared VCAA section-label regexes + glossary-row filtering
  parse_docx.py           <- .docx -> RawBlock list (uses paragraph styles)
  parse_pdf.py             <- .pdf -> RawBlock list (uses font-size + regex heuristics)
  extract_items.py          <- RawBlock list -> StudyItem list (the Unit/Area of Study/
                               Outcome/Key knowledge/Key skills state machine, plus
                               bundled-subject splitting and id assignment)
  simplify.py                <- StudyItem.official_text -> plain-language rewrite
  jargon_dictionary.json      <- word -> plain-language replacement map used by simplify.py
  acronyms.py                  <- cross-item acronym expansion (see "How simplification works")
  build.py                     <- CLI entry point, wires the above together
scripts/
  analyze_vocabulary.py  <- authoring aid: finds candidate words for jargon_dictionary.json
                            from the actual generated dataset (run manually, not part of build)
```

Source documents are committed (they're public VCAA files), so the
pipeline runs reproducibly on a fresh clone, see the "Fresh clone
reproducibility" note under Usage.

## Setup

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate      # Windows: .venv\Scripts\activate
pip install -r requirements.txt
python -m spacy download en_core_web_sm
```

The first run downloads NLTK's sentence-tokenizer data automatically
(needs network access once; cached under `~/nltk_data` after that).
spaCy's model is a separate, explicit download step (`en_core_web_sm`,
~13MB), `pip install spacy` only installs the library, not a language
model.

## Usage

1. Drop your source files into `source_docs/` (e.g.
   `software_development.docx`, `data_analytics.pdf`). The shared VCAA
   "Glossary of command terms" (`GlossaryOfCommandTerms.docx`) is a
   required build input too: unlike a subject file, its rows are parsed
   and *held aside*, then copied by `attach_shared_glossary()` onto
   every subject whose study design has no embedded glossary (Applied
   Computing, Data Analytics, Software Development and English EAL keep
   their own embedded tables). The current set of documents is already
   committed, so a fresh clone can run the pipeline as-is.
2. If a filename doesn't cleanly title-case into the subject name you
   want shown in the app (the default: `software_development.docx` ->
   "Software Development"), add an entry to `source_docs/subjects.json`:
   ```json
   { "sd_2024_accredited.docx": "Software Development" }
   ```
   Note some VCAA files bundle several courses into one document (the
   combined Mathematics study design covers General/Specialist/Foundation
   Mathematics and Mathematical Methods; the combined Applied Computing
   document covers Applied Computing, Data Analytics, and Software
   Development), `subjects.json` only needs a *default* name for these,
   since `extract_items.split_bundled_subjects()` automatically detects
   and splits them into their real per-course subjects based on each
   Unit's own heading text (e.g. "Unit 3: Data analytics").
3. Run the pipeline:
   ```bash
   python -m ingest.build
   ```
   Add `--dump-blocks output/blocks` to also write each source file's raw
   parsed paragraphs (with detected heading level) as its own JSON file,
   useful for seeing exactly what the parser saw before debugging a
   document whose extracted item count looks wrong.
4. Check the console output, it prints how many items were extracted
   per file (and how a bundled file split across subjects), and warns if
   any file produced **0 items** (almost always means that file's
   headings don't match the patterns below and the parser needs a small
   tweak).
5. Copy the result into the Flutter app and commit both:
   ```bash
   cp output/study_items.json ../assets/data/study_items.json
   ```

**Fresh clone reproducibility:** `source_docs/` is committed, so a brand
new `git clone` can run steps 3–5 above without any extra files. Verified:
a clean clone produces 2,579 items across 12 subjects, byte-identical to
`assets/data/study_items.json` (`diff -q` is clean). If that diff ever
fails on your machine, the committed dataset is out of date, re-sync with
step 5 and commit.

## How extraction works

Both parsers reduce their very different source formats down to a
common list of `RawBlock`s (a paragraph of text + a heading depth 0-5),
so `extract_items.py` only has to understand one thing: VCAA's
consistent document structure,

```
Unit N                          (level 1)
  Area of Study N                (level 2)
    Outcome N                     (level 3)
      <outcome statement paragraph>   -> one "Outcome" StudyItem
      Key knowledge                    (level 4)
        <dot point>                     -> one "Key Knowledge" StudyItem
        <nested sub-bullet>                -> folded into the dot point above,
                                               not its own item (see is_sub_item)
      Key skills                       (level 4)
        <dot point>                     -> one "Key Skill" StudyItem
```

Glossary tables ("Term | Definition", e.g. VCAA's command-term glossary)
are detected separately and become `"Command Term"` items regardless of
where they appear in the document. Whole tables are first filtered by
their own header row via `heading_patterns.is_non_glossary_table()`
(skips "Outcomes | Marks allocated", "Version | Status", and similar,
see its docstring for the full list and why it's a denylist, not a
"must say Term/Definition" allowlist), then each remaining row through
`looks_like_glossary_row()`, which filters out prerequisite/overlap
tables and similar row-shaped-but-not-glossary content that shares a
table's header with genuine entries. A row whose term cell contains
multiple newline-separated paragraphs (seen in one real document: two
terms accidentally sharing one table row) gets split back into
separate entries, paired positionally with the definition cell's
paragraphs, rather than kept as one entry with two glued-together terms.

Heading detection checks a heading's own **wording** first (e.g. "Unit
3", "Key knowledge", reliable regardless of styling), then falls back
to its Word paragraph style (`heading_patterns.style_heading_level()`,
which generically matches any "*Heading N*"-shaped style name, since
VCAA documents use inconsistent custom style names like "VCAA Heading
5" rather than Word's defaults). Items are emitted in natural document
reading order (Unit 1 → its Areas of Study → each Outcome and its Key
Knowledge/Key Skill points → Unit 2 → ...), which the Flutter app's
results list relies on for its Unit/Area of Study grouping, `build.py`
deliberately sorts the final output by subject only (a stable sort) so
this order is preserved, not re-sorted alphabetically by category.

If a real study design's wording differs even slightly from this (e.g.
"Areas of Study" plural, or a document that doesn't use Word heading
styles at all), extraction for that file will likely come back empty or
partial, the fix is almost always a small regex/style-name tweak in
`extract_items.py`, `parse_docx.py`, `parse_pdf.py`, or
`heading_patterns.py`, not a rewrite. Start by checking that file's
`--dump-blocks` output.

## How simplification works

`simplify.py` does **not** paraphrase, scikit-learn has no text
generation capability, it's a classical ML library. What it actually
does, per item:

1. **Extract**, split the official text into sentences (NLTK), and if
   there's more than a couple, keep only the most representative ones
   using TF-IDF + cosine similarity to the passage's "centroid" vector
   (a standard extractive-summarisation technique). This trims a dense
   paragraph down without inventing new wording.
2. **Rewrite**, swap known jargon words/phrases for plain-language
   equivalents (`jargon_dictionary.json`), and split long, multi-clause
   sentences at semicolons and genuine clause-boundary "and"s into
   shorter ones. The clause split uses spaCy's dependency parser
   (`en_core_web_sm`, a small statistical POS-tagger/parser, not a
   generative model) rather than a naive regex: an "and" only counts as
   a split point when its verb has its *own* subject (an `nsubj` in the
   parse), which distinguishes a genuine second independent clause
   ("...X and the teacher should Y", split) from VCE's actual dominant
   pattern, one instruction with several compound predicates or
   conjoined nouns sharing an implicit subject ("the student should be
   able to X, Y and Z", don't split; "belief formation and
   justification", don't split, no verb at all). An earlier
   plain-regex version split at *every* " and ", which badly
   over-fragmented outcome statements ("discuss and analyse the
   specific vocabulary..." became "Discuss." + "Analyse the specific
   vocabulary..."), a full-corpus check after switching to the
   dependency-parse version found the short-fragment failure rate went
   from a systemic problem to 1 item out of 2,206.

Text that's really a semicolon-joined list of dot points (produced when
nested sub-bullets get folded into their parent item, see above) skips
steps 1-2 entirely and goes through a separate list-aware path instead:
it keeps every list entry intact and only swaps jargon words, since
running sentence-tokenization/clause-splitting over a list chops each
entry into a meaningless fragment rather than a sentence.

3. **Expand acronyms** (`acronyms.py`), VCAA documents typically define
   an acronym once ("relational database management systems (RDBMS)")
   and use it bare in later dot points, sometimes under a completely
   different Unit/Outcome. Since each StudyItem is one self-contained
   dot point, a later item that only says "RDBMS" has no way to show
   what that means on its own. `build.py` scans every item's
   *official_text* for a subject to build a `{ABBR: expansion}` map
   (`extract_acronym_definitions`), then inserts "(expansion)" after
   the first bare use of a known acronym in each item's
   *plain-language* text only, official_text always stays verbatim.
   The phrase-matching requires the abbreviation's letters to exactly
   match the initials of a short (≤6 word) run of preceding words; if
   nothing matches exactly it's skipped rather than guessed, since a
   looser match risks grabbing the wrong/an unrelated preceding phrase
   (this happened during development, a naive character-length-capped
   regex grabbed up to 80 characters of preceding text regardless of
   word boundaries, truncating mid-word and pulling in unrelated
   clauses; fixed by matching whole words with an exact-initials check
   instead).

Both the extract and rewrite steps are deterministic rule-based text
manipulation, not machine learning "understanding" the content. Known
limitations:

- Word-for-word jargon substitution can read awkwardly for **verbs**
  that need sentence restructuring, not just a swapped word (e.g.
  "evaluate X" becoming "judge how good X is" mid-sentence).
- It can read as outright **backwards/broken** for jargon words used
  **adjectivally right before a noun**, e.g. an earlier attempt to add
  "epistemological" -> "related to how we know what we know" produced
  "analyse related to how we know what we know problems" for the
  source phrase "analyse epistemological problems". A definition-style
  replacement phrase is postpositive by nature (it explains something
  *after* the fact) and can't correctly premodify a noun the way an
  adjective does. **When adding jargon entries, only add words that
  work standalone as a noun/verb in their own right** (check a few real
  usage examples via `scripts/analyze_vocabulary.py` first), skip
  anything that's consistently used to modify a following noun.
- The dependency parser itself is imperfect (it's a statistical model,
  not a grammar oracle) and can occasionally mislabel a subject in an
  unusual construction, found during development: "the role of...
  Goals **to inspire and drive** innovation" (an infinitival purpose
  clause) got "Goals" tagged as the subject of "inspire", triggering an
  incorrect split. This is a genuine parser limitation, not a logic
  bug in `_clause_split_ranges`, a full-corpus regression check found
  exactly one such case among 2,206 items, so it's an accepted,
  documented edge case rather than something worth chasing further
  with more heuristics.

Getting genuinely fluent, reworded explanations for either limitation
would require an LLM instead of this approach, out of scope for this
pipeline by design.

`jargon_dictionary.json` deliberately excludes VCAA command terms
("Analyse", "Evaluate", etc.) even though they're jargon-ish, those
already get their own authoritative definitions as real "Command Term"
items sourced from the study design's own glossary, so duplicating them
here would risk showing a *different*, unofficial definition inline in
some other item's plain-language text. It also excludes standard
curriculum vocabulary ("qualitative", "quantitative", "mathematical",
"algorithm") that students are expected to learn, not jargon to be
simplified away, `scripts/analyze_vocabulary.py` found that the large
majority of long/frequent words in this corpus fall into that bucket
rather than being genuine jargon, which is itself a useful finding: VCE
study design language is already reasonably plain outside a
comparatively small set of words. Tune the dictionary freely, it's
just a JSON map, no code changes needed, but run the new entry against
a few real examples first given the adjective-before-noun trap above.

Entries aren't limited to single words, multi-word academic connector
phrases work too ("with reference to" -> "about", "on completion of" ->
"after finishing"), matched the same way via `_JARGON_RE`'s word-boundary
regex. These phrases account for a meaningful share of the corpus's
"nothing to simplify" items (bare word-frequency analysis undercounts
them, since `analyze_vocabulary.py` only looks at single tokens),
checking a candidate phrase's real frequency first (`grep`/a quick
Python count over `officialText`) is worth doing before adding one, the
same way `analyze_vocabulary.py` does for single words.

`_replace_jargon` capitalises the replacement when the matched text was
capitalised (e.g. a sentence-initial "On completion of" -> "After
finishing", not "after finishing"), this matters a lot more once
phrase entries are in play, since single lowercase jargon words rarely
start a sentence but phrase-shaped ones like "on completion of" often
do.

Even after word- and phrase-level substitution, some items will still
have official_text == plain_language_text, content that's already
plain (a bare list of everyday words, or a short sentence with nothing
matched) genuinely has nothing to simplify. The Flutter app shows an
explicit "already written in plain language" note for these instead of
a duplicate box, rather than trying to force a difference that isn't
there.

## Robustness

A single malformed/corrupt source file no longer crashes the whole
`build` run, parsing/extraction/simplification for each file is
wrapped so a failure there (not a valid .docx/.pdf, a permission
error, an unusual document structure a parser chokes on) prints a
warning naming the file and skips it, instead of losing every other
already-processed file's output too (previously, `output_path` was
only written once at the very end, so one bad file mid-list meant
*nothing* got written, no matter how many good files came before it).
`source_docs/subjects.json` having invalid JSON gets a clear
"which file, what's wrong" error instead of a raw traceback, for the
same reason, it's small and hand-edited, so a typo is realistic.

`_most_representative_sentences()` also no longer crashes on a passage
whose sentences are all stop words/numbers/punctuation once
`stop_words="english"` strips them (`TfidfVectorizer` raises on an
"empty vocabulary" in that case), falls back to returning the
sentences unchanged. Not currently hit by any of the 2,206 real items
in this dataset, but proven reachable (`TfidfVectorizer(stop_words=
"english").fit_transform(["it is", "of the", "and so"])` raises today)
and the failure mode was severe enough, one bad item crashing the
whole build, to guard against even as a latent risk.

## Known remaining data-quality caveats

- Extraction heuristics are tuned against the 7 real VCAA files this
  pipeline has been run against so far; a new subject's file may need
  small tweaks (see "How extraction works" above).

Previously noted here: a handful of English EAL "Command Term" entries
read oddly because they actually came from an unrelated thematic
writing-topics table ("Key idea | Elaboration"), not the real glossary
, fixed by `heading_patterns.is_non_glossary_table()`, which also fixed
the same problem in Physics (a report-structure guide table, "Poster
section | Content", was contributing fake command terms like
"Introduction" and "Discussion") and recovered 15+ legitimate Applied
Computing glossary terms ("Pseudocode", "Security threats", ...) that a
stricter first version of this fix had wrongly excluded, that version
required a table to have a literal "Term | Definition" header row to be
considered at all, but real glossary tables in practice sometimes have
no header row (the first row is already real content). The fix is a
denylist of headers confirmed NOT to be a glossary, not an allowlist of
ones that are, every other table still goes through
`looks_like_glossary_row()` per row as before.
