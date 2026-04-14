---
name: brief
description: "Synthesize a compiled extractions.json into focused, project-specific review briefs. Use after the extraction loop is complete. Triggers on: write briefs, review notes, synthesize extractions, brief the literature, write review notes."
user-invocable: true
---

# Review Brief Generator

Turn a compiled `extractions.json` into focused review notes anchored by the project's research goals.

This is the synthesis step in the pipeline: `/prepare` -> `/schema` -> extraction loop -> **`/brief`**.

---

## The Job

1. Discover the project context (abstract, extractions)
2. Classify papers into thematic groups with organizing questions
3. Compile rich prompts from actual extraction content
4. Launch parallel subagents to write the briefs

---

## Step 1: Discover Context

### Find extractions

Look for `extractions.json` in the ralph directory (same directory as this skill's parent). If not found, ask the user for the path.

Validate: the file must be a JSON array with at least one extraction object. Count the articles and report:

```
Found N extracted articles in extractions.json.
```

### Find the project framing document

Search for files that likely contain the project abstract or research goals. Check in order:

1. `design/abstract.md`
2. `abstract.md`
3. `README.md`
4. `CLAUDE.md` (for reviewGoal in the schema)

If multiple exist, show what was found and ask the user which to use. If none, ask the user to paste or point to their abstract.

Read the framing document and display a 1-2 sentence summary:

```
Project framing: [brief summary]
Using: [path to framing document]

Does this capture the right context for the briefs? (y/n, or paste alternative)
```

Wait for confirmation.

---

## Step 2: Classify Papers into Groups

### Read the corpus

For each extraction, pull: `_article_id`, `title`, `authors`, `year`, `paper_type`, `theoretical_tradition`, `journal_or_venue`.

### Propose groups

Based on `paper_type` and `theoretical_tradition`, propose 2-5 thematic groups. Each group needs:

- A **label** (e.g., "Computational Models", "Empirical Political Science")
- A **list of article IDs** assigned to it
- An **organizing question** tied to the project framing

Present as a numbered list:

```
Proposed groupings (N articles across K groups):

1. COMPUTATIONAL MODELS (5 papers)
   ART-003 Butler et al. (2019), ART-016 Kurrild-Klitgaard & Brandt (2021), ...
   Question: What have prior ABMs formalized, what parameters matter, and why
   do LLM agents solve the content bottleneck?

2. EMPIRICAL POLITICAL SCIENCE (8 papers)
   ART-001 Barabas (2004), ART-015 Jackman & Sniderman (2006), ...
   Question: What effect sizes must the simulation reproduce, and what boundary
   conditions constrain validity?

3. THEORY: QUALITATIVE AND FORMAL (7 papers)
   ART-012 Gastil & Black (2008), ART-006 Liang et al. (2023), ...
   Question: What normative standards, outcome measures, and formal tools does
   theory provide for the simulation?

You can:
  - Accept as-is
  - Move papers between groups (e.g., "move ART-006 to group 1")
  - Rename groups or change organizing questions
  - Add or remove groups
  - Exclude papers from all groups
```

Wait for the user to confirm or adjust. Iterate until confirmed.

---

## Step 3: Compile Prompts

For each confirmed group, build a prompt with four sections:

### Section A: Framing (~200 words)

```
You are writing a ~2000-word review note on **[GROUP LABEL]** for a prospectus
literature review. The note must be written FROM the perspective of the
following project:

**Project abstract**: "[FULL TEXT OF ABSTRACT]"

**The organizing question**: [GROUP'S ORGANIZING QUESTION]

Write the note to: [OUTPUT PATH]
```

### Section B: Style constraints (fixed text, always included)

```
**INSTRUCTIONS**:
- This is NOT a survey. It is a working review note for a specific paper.
  Every paragraph must contain a concrete implication for the project: a
  parameter range, a design choice, an outcome measure, a validation target,
  or a specific limitation the project addresses.
- Use actual numbers, formal specifications, and direct quotes from the
  extraction data below. Do not paraphrase around the content -- present it.
- Cover papers UNEVENLY. Give more space to papers with richer, more
  design-relevant content. Some papers deserve 400 words; others deserve
  a sentence.
- Style: research notes, not polished essay. Direct, specific, even terse.
  No filler openings ("X has generated a rich literature..."). (Author Year)
  citations. Prose paragraphs, no bullets. ## headers only.
- Organize by DESIGN QUESTION or THEMATIC ARGUMENT, not paper-by-paper.
- Do not read external files -- use only the extraction content provided below.
```

### Section C: Extraction content (~variable, budget ~3000 words per group)

For each paper in the group, pull these fields from the extraction and format them as labeled blocks:

**High-priority fields** (always include if present):
- `title`, `authors`, `year`, `journal_or_venue`
- `key_findings` (full array)
- `effect_sizes` (full array)
- `mechanisms` (full array)
- `outcome_measures` (full array)
- `boundary_conditions` (full array)
- `update_rule`
- `agent_representation`
- `design_parameters` (full array)
- `key_concepts` (full array)

**Include if space permits** (budget ~3000 words total for section C):
- `cognitive_model`
- `state_variables`
- `dynamics`
- `heterogeneity`
- `normative_assumptions`
- `builds_on`
- `contradicts`
- `limitations`

Format each paper's content as:

```
### Author (Year) -- Venue
[field content, preserving structure]
```

**Token budget**: If the combined extraction content for a group exceeds ~4000 words, prioritize papers the user hasn't flagged for less coverage. Within each paper, prioritize high-priority fields. Truncate `limitations` and `builds_on` first.

### Section D: Structure suggestion (~200 words)

Based on the group's organizing question and the papers' content, propose a structure:

```
## SUGGESTED STRUCTURE (adapt as the argument requires)

1. [Section name] (~N words): [What it covers and why it matters for the project]
2. [Section name] (~N words): [...]
...
```

The structure should be organized by **design question** or **thematic argument**, not by paper. Each section should name which papers contribute to it.

---

## Step 4: Launch Agents

### Create output directory

```bash
mkdir -p briefs/
```

relative to the ralph directory.

### Launch parallel subagents

Launch one Opus subagent per group, all in parallel. Each agent gets the compiled prompt from Step 3 and writes to `briefs/[NN]_[group_label_snake_case].md`.

Report launch:

```
Launching K agents in parallel:
  Agent 1: [group label] -> briefs/01_[name].md
  Agent 2: [group label] -> briefs/02_[name].md
  ...
```

### Report completion

When all agents finish, report word counts:

```
All briefs complete:
  01_computational_models.md     2,132 words
  02_empirical_political_science.md  1,968 words
  03_theory_qualitative_formal.md    2,011 words
  Total: 6,111 words
```

---

## Design Principles (why the skill works this way)

These are hard-won from iteration. Do not relax them.

1. **The project abstract is the North Star.** Every prompt includes it. Every paragraph the agent writes must connect back to it. Without this, briefs become generic surveys.

2. **Actual extraction content, not summaries.** The prompt includes verbatim key_findings, effect_sizes, formal specifications, and direct quotes from the extractions. Agents that receive summaries produce summaries. Agents that receive numbers produce numbers.

3. **Uneven coverage.** Papers with richer design-relevant content get more space. The prompt explicitly names which papers deserve more and less. Equal coverage produces shallow coverage.

4. **Organized by question, not by paper.** The structure suggestion groups papers around design questions ("What should agents be made of?") rather than walking through papers sequentially. Paper-by-paper organization produces narration, not synthesis.

5. **Every paragraph lands.** The style constraint "every paragraph must contain a concrete implication" is the single most important instruction. Without it, agents produce competent-sounding text with no actionable content.

---

## Checklist

- [ ] extractions.json found and validated
- [ ] Project framing document found and confirmed with user
- [ ] Paper groupings proposed and confirmed
- [ ] Organizing questions confirmed
- [ ] Prompts compiled with actual extraction content
- [ ] Output directory created
- [ ] Agents launched in parallel
- [ ] Word counts reported on completion
