---
name: prepare
description: "Scan a directory for PDF files and build articles-meta.json for the extraction loop. Use when starting a new review corpus, adding papers, or refreshing the article list. Triggers on: prepare articles, scan pdfs, build article list, index papers."
user-invocable: true
---

# Article Preparation

Scan a directory for PDFs and build `articles-meta.json` for the extraction loop.

---

## The Job

1. Ask the user where the PDFs are located
2. Scan that directory for `.pdf` files
3. Build `articles-meta.json` with one entry per PDF
4. Report what was found

---

## Step 1: Locate PDFs

Ask the user:

```
Where are the PDF files for this review?

  A. In a `pdfs/` folder in this directory
  B. In a specific path (please provide)
  C. Scattered across multiple directories (please list)
```

If the user picks B or C, use the path(s) they provide. For option A, use `pdfs/` relative to the ralph directory's parent (the project root).

---

## Step 2: Scan and Build

Use `find` or `glob` to locate all `.pdf` files. For each file:

- Generate a sequential ID: `ART-001`, `ART-002`, etc.
- Record the file path (relative to project root)
- Extract the filename (without extension) as a provisional title
- Set `processed: false`

If `articles-meta.json` already exists, ask the user:

```
articles-meta.json already exists with N articles.
  A. Replace it entirely with a fresh scan
  B. Add only new PDFs not already listed
  C. Cancel
```

For option B, compare file paths and only add new entries, continuing the ID sequence.

---

## Step 3: Save articles-meta.json

Write to `articles-meta.json` in the ralph directory.

### Format:

```json
{
  "corpus": "User's review name or directory name",
  "pdfDirectory": "relative/path/to/pdfs",
  "scannedAt": "2025-01-15T10:30:00Z",
  "articles": [
    {
      "id": "ART-001",
      "path": "pdfs/smith-2020-deliberation.pdf",
      "provisionalTitle": "smith-2020-deliberation",
      "processed": false
    },
    {
      "id": "ART-002",
      "path": "pdfs/habermas-1996-discourse.pdf",
      "provisionalTitle": "habermas-1996-discourse",
      "processed": false
    }
  ]
}
```

---

## Step 4: Report

Show the user a summary:

```
Found N PDF files in [path].

Articles:
  ART-001  smith-2020-deliberation.pdf
  ART-002  habermas-1996-discourse.pdf
  ...

Saved to articles-meta.json.
Run `make run` to start extraction, or `make status` to check progress.
```

---

## Checklist

- [ ] PDF directory confirmed with user
- [ ] All PDFs found and listed
- [ ] IDs are sequential and unique
- [ ] Paths are relative to project root
- [ ] articles-meta.json written successfully
- [ ] Summary shown to user
