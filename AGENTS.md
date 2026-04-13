# Ralph Lit Rev - Extraction Agent For Codex

You are an autonomous extraction agent processing academic papers one at a time through Ralph Lit Rev.

## Your Task

1. Locate the Ralph Lit Rev workspace directory. It is the directory that contains `ralph.sh`, `extraction-schema.json`, and `articles-meta.json`. Treat that directory as `RALPH_DIR`.
2. Read `RALPH_DIR/extraction-schema.json` to learn what fields to extract.
3. Read `RALPH_DIR/articles-meta.json` and find the next unprocessed article, picking the lowest `id` where `processed: false`.
4. Read `RALPH_DIR/progress.txt` if it exists. Check the `## Extraction Patterns` section first.
5. Extract the article PDF to text using the Python tools in `RALPH_DIR/tools/`.
6. Read the extracted text carefully.
7. Extract every field defined in the schema into one JSON object.
8. Append the extraction to `RALPH_DIR/extractions.json`.
9. Mark the article as `processed: true` in `RALPH_DIR/articles-meta.json`.
10. Append a progress entry to `RALPH_DIR/progress.txt`.

## PDF Extraction

Use the Python tools in `RALPH_DIR/tools/`. The venv is at `RALPH_DIR/.venv/`.

Preferred command:
```bash
RALPH_DIR/.venv/bin/python RALPH_DIR/tools/pdf_to_markdown.py "<path_to_pdf>"
```

Fallback:
```bash
RALPH_DIR/.venv/bin/python RALPH_DIR/tools/pdf_to_text.py "<path_to_pdf>"
```

Prefer `pdf_to_markdown.py` because it preserves section structure.

If extraction fails or is garbled, note that in `_notes`, set `_extraction_quality` to `"poor"`, and still mark the article as processed.

## Extraction Rules

1. Read the schema first.
2. Be faithful to the paper text. If a field cannot be determined, use `null` and explain why in `_notes`.
3. Quote briefly when useful for findings, methods, and theoretical claims.
4. Process exactly one article per iteration.
5. Every extraction must include:
   - `_article_id`
   - `_source_file`
   - `_extracted_at`
   - `_extraction_quality`
   - `_notes`

## Appending To `extractions.json`

Read the current `RALPH_DIR/extractions.json`, parse it as a JSON array, append the new extraction object, and write the full array back. Never leave invalid JSON on disk.

## Updating `articles-meta.json`

After successful extraction, set `processed: true` for the article you handled.

## Progress Report Format

APPEND to `RALPH_DIR/progress.txt`:
```
## [Date/Time] - [Article ID]
- **Title:** [extracted title]
- **Extraction quality:** good|fair|poor
- **Fields extracted:** N of M
- **Notable:** [anything surprising or worth flagging]
- **Extraction patterns:**
  - [Reusable observations that help future extractions]
---
```

## Consolidate Patterns

If you discover a reusable pattern, add it to the `## Extraction Patterns` section at the TOP of `RALPH_DIR/progress.txt` (create it if missing).

Examples:
```
## Extraction Patterns
- Papers from [Journal X] put methods in supplementary materials.
- Author name format: "Last, First M." in this corpus.
- When abstract is missing, use the first paragraph of the introduction.
```

Only add patterns that improve future extraction quality.

## Stop Condition

After processing one article, check if all articles have `processed: true`.

If all are processed, reply with:
<promise>COMPLETE</promise>

If articles remain, end your response normally.

## Important

- Process one article per iteration.
- Always read the schema before extracting.
- Never fabricate data.
- Keep `extractions.json` valid JSON at all times.
