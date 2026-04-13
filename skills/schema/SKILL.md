---
name: schema
description: "Design an extraction schema for a literature review. Use when starting a new review, defining what to extract from papers, or customizing extraction fields. Triggers on: create schema, design extraction, what to extract, review schema, configure extraction."
user-invocable: true
---

# Extraction Schema Designer

Build a structured extraction schema tailored to the user's literature review goals.

---

## The Job

Guide the user through defining what information to extract from each paper. The output is `extraction-schema.json` — the contract that the extraction loop uses for every article.

---

## Step 1: Understand the Review Goals

Ask the user:

```
What is the main goal of this literature review?

For example:
  - "Understand mechanisms of opinion change in deliberative mini-publics"
  - "Map computational approaches to modeling political polarization"
  - "Survey experimental designs for studying group decision-making"

Please describe your goal in 1-3 sentences.
```

Wait for their response before continuing.

---

## Step 2: Clarifying Questions

Based on the stated goal, ask 3-5 targeted questions with lettered options. Tailor these to the goal — the examples below are templates, not fixed questions.

```
1. What type of literature are you reviewing?
   A. Empirical studies (experiments, surveys, observational)
   B. Theoretical/conceptual papers
   C. Computational/simulation studies
   D. Mixed — all of the above
   E. Other: [please specify]

2. What is the primary discipline?
   A. Political science
   B. Sociology
   C. Computer science / AI
   D. Economics
   E. Interdisciplinary — specify main fields

3. What aspects matter most for your review?
   A. Methods and research design
   B. Theoretical frameworks and mechanisms
   C. Empirical findings and effect sizes
   D. Data sources and measurement
   E. All equally important

4. Do you need to track relationships between papers?
   A. Yes — citation networks, who builds on whom
   B. Yes — shared datasets or experimental paradigms
   C. No — each paper stands alone
   D. Not sure yet

5. What is the expected corpus size?
   A. Small (under 20 papers)
   B. Medium (20-50 papers)
   C. Large (50-100 papers)
   D. Very large (100+ papers)
```

The user can respond with shorthand like "1A, 2E political science and psychology, 3B, 4A, 5B".

---

## Step 3: Propose a Schema

Based on the answers, propose a schema with 10-20 fields organized in sections. Present it as a checklist so the user can accept, remove, or modify fields.

### Always include these core fields:

```
CORE (always extracted):
  [x] title — Full paper title
  [x] authors — List of authors
  [x] year — Publication year
  [x] journal_or_venue — Journal, conference, or publisher
  [x] doi — DOI if available
  [x] abstract — Paper abstract
```

### Then propose domain-specific fields based on the review goal. Example sections:

```
RESEARCH DESIGN:
  [ ] research_questions — Stated research questions or hypotheses
  [ ] methodology — Research method (experiment, survey, simulation, etc.)
  [ ] sample_description — Who/what was studied, sample size
  [ ] data_sources — Datasets, corpora, or data collection methods

THEORETICAL:
  [ ] theoretical_framework — Theory or model the paper builds on
  [ ] key_concepts — Central concepts or constructs defined
  [ ] mechanisms — Causal mechanisms proposed or tested

FINDINGS:
  [ ] key_findings — Main results, with quotes where possible
  [ ] effect_sizes — Quantitative effect sizes if reported
  [ ] limitations — Limitations stated by the authors
  [ ] future_directions — Suggested future work

CONNECTIONS:
  [ ] cited_papers_of_interest — Key references that appear relevant to this review
  [ ] builds_on — Papers this work explicitly extends
  [ ] contradicts — Papers whose findings this work challenges

CUSTOM:
  [ ] [user can add fields here]
```

Ask:

```
Here is my proposed schema. For each field:
  - [x] means I recommend including it
  - [ ] means it's optional — include if useful for your review

You can:
  1. Accept as-is
  2. Remove fields (e.g., "drop effect_sizes and contradicts")
  3. Add fields (e.g., "add a field for 'policy_implications'")
  4. Modify descriptions (e.g., "for methodology, I specifically need...")

What changes would you like?
```

---

## Step 4: Refine

Iterate with the user until they're satisfied. Each round, show the updated schema and ask for confirmation.

When the user confirms, proceed to Step 5.

---

## Step 5: Save extraction-schema.json

Write the schema to `extraction-schema.json` in the ralph directory.

### Format:

```json
{
  "reviewGoal": "User's stated review goal",
  "reviewType": "empirical|theoretical|computational|mixed",
  "fields": [
    {
      "name": "title",
      "section": "core",
      "description": "Full paper title",
      "type": "string",
      "required": true
    },
    {
      "name": "authors",
      "section": "core",
      "description": "List of author names",
      "type": "array",
      "items": "string",
      "required": true
    },
    {
      "name": "year",
      "section": "core",
      "description": "Publication year",
      "type": "number",
      "required": true
    },
    {
      "name": "key_findings",
      "section": "findings",
      "description": "Main results with brief direct quotes and section references",
      "type": "array",
      "items": "string",
      "required": true
    },
    {
      "name": "sample_description",
      "section": "research_design",
      "description": "Who or what was studied, including sample size",
      "type": "string",
      "required": false
    }
  ]
}
```

### Field type conventions:
- `"string"` — single value
- `"number"` — numeric value
- `"array"` with `"items": "string"` — list of strings
- `"array"` with `"items": "object"` — list of structured sub-objects (define `"properties"` inline)
- `"boolean"` — true/false flag

### Required vs optional:
- `required: true` — the agent must extract this or explicitly set to `null` with a note
- `required: false` — the agent should extract if present, skip silently if not

---

## Checklist Before Saving

- [ ] Review goal is captured verbatim from the user
- [ ] Core fields (title, authors, year, journal, doi, abstract) are present
- [ ] Domain-specific fields match the stated review goal
- [ ] Field descriptions are specific enough for an extraction agent to act on
- [ ] Required/optional distinction reflects the user's priorities
- [ ] User has explicitly confirmed the final schema
