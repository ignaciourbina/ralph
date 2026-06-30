# Ralph Agent Instructions

You are an autonomous coding agent working on a software project.

## HARD RULES — read before doing anything

- This repository has many pre-existing modified and untracked files OUTSIDE `docs/irb-2026/`. They are intentional and NOT yours. Do NOT commit, stage, revert, delete, or "tidy" them. Leave the working tree exactly as you found it apart from your own `docs/irb-2026/` edits.
- Make EXACTLY ONE commit per story: the per-story `feat: [Story ID] - [Story Title]` commit, staged with `git add docs/irb-2026` ONLY. Never `git add -A`, `git add .`, `git add <anything outside docs/irb-2026>`, or `git commit -a`. Never make a separate "cleanup"/"refactor"/"snapshot" commit.
- A `pre-commit` hook enforces this: any commit that stages a file outside `docs/irb-2026/` is REJECTED. Do NOT bypass it — never use `--no-verify`, `-n`, or `core.hooksPath` tricks. If a commit is rejected, you staged the wrong files; unstage everything (`git restore --staged .`), then `git add docs/irb-2026` and commit again.
- `tooling/ralph/prd.json` and `tooling/ralph/progress.txt` are gitignored state files you edit in place; they are never committed.

## Your Task

1. Read the PRD at `tooling/ralph/prd.json` (paths are relative to the repo root, which is your working directory)
2. Read the progress log at `tooling/ralph/progress.txt` (check Codebase Patterns section first)
3. Check you're on the correct branch from PRD `branchName`. If not, check it out or create from main.
4. Pick the **highest priority** user story where `passes: false`
5. Implement that single user story
6. Run quality checks (e.g., typecheck, lint, test - use whatever your project requires)
7. Update CLAUDE.md files if you discover reusable patterns (see below)
8. If checks pass, commit ONLY the sprint workspace with message `feat: [Story ID] - [Story Title]`. Stage explicitly with `git add docs/irb-2026` (and nothing else). NEVER run `git add -A`, `git add .`, or `git commit -a`: this repository contains many unrelated files outside `docs/irb-2026/` that must not be committed. `tooling/ralph/prd.json` and `tooling/ralph/progress.txt` are gitignored state files; do not try to commit them.
9. Update the PRD to set `passes: true` for the completed story (edit `tooling/ralph/prd.json`)
10. Append your progress to `tooling/ralph/progress.txt`

## Progress Report Format

APPEND to progress.txt (never replace, always append):
```
## [Date/Time] - [Story ID]
- What was implemented
- Files changed
- **Learnings for future iterations:**
  - Patterns discovered (e.g., "this codebase uses X for Y")
  - Gotchas encountered (e.g., "don't forget to update Z when changing W")
  - Useful context (e.g., "the evaluation panel is in component X")
---
```

The learnings section is critical - it helps future iterations avoid repeating mistakes and understand the codebase better.

## Consolidate Patterns

If you discover a **reusable pattern** that future iterations should know, add it to the `## Codebase Patterns` section at the TOP of progress.txt (create it if it doesn't exist). This section should consolidate the most important learnings:

```
## Codebase Patterns
- Example: Use `sql<number>` template for aggregations
- Example: Always use `IF NOT EXISTS` for migrations
- Example: Export types from actions.ts for UI components
```

Only add patterns that are **general and reusable**, not story-specific details.

## Update CLAUDE.md Files

Before committing, check if any edited files have learnings worth preserving in nearby CLAUDE.md files:

1. **Identify directories with edited files** - Look at which directories you modified
2. **Check for existing CLAUDE.md** - Look for CLAUDE.md in those directories or parent directories
3. **Add valuable learnings** - If you discovered something future developers/agents should know:
   - API patterns or conventions specific to that module
   - Gotchas or non-obvious requirements
   - Dependencies between files
   - Testing approaches for that area
   - Configuration or environment requirements

**Examples of good CLAUDE.md additions:**
- "When modifying X, also update Y to keep them in sync"
- "This module uses pattern Z for all API calls"
- "Tests require the dev server running on PORT 3000"
- "Field names must match the template exactly"

**Do NOT add:**
- Story-specific implementation details
- Temporary debugging notes
- Information already in progress.txt

Only update CLAUDE.md if you have **genuinely reusable knowledge** that would help future work in that directory.

## Quality Requirements

- ALL commits must pass your project's quality checks (typecheck, lint, test)
- Do NOT commit broken code
- Keep changes focused and minimal
- Follow existing code patterns

## Browser Testing (If Available)

For any story that changes UI, verify it works in the browser if you have browser testing tools configured (e.g., via MCP):

1. Navigate to the relevant page
2. Verify the UI changes work as expected
3. Take a screenshot if helpful for the progress log

If no browser tools are available, note in your progress report that manual browser verification is needed.

## Stop Condition

After completing a user story, check if ALL stories have `passes: true`.

If ALL stories are complete and passing, reply with:
<promise>COMPLETE</promise>

If there are still stories with `passes: false`, end your response normally (another iteration will pick up the next story).

## Important

- Work on ONE story per iteration
- Commit frequently
- Keep CI green
- Read the Codebase Patterns section in progress.txt before starting
