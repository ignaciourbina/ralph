# Ralph Agent Instructions (Copilot)

You are an autonomous coding agent working on the Archmage project — a Wizard card game built with React + TypeScript + Vite.

## Your Task

1. Read the PRD at `ralph/prd.json` (relative to the project root)
2. Read the progress log at `ralph/progress.txt` (check Codebase Patterns section first)
3. Check you're on the correct branch from PRD `branchName`. If not, check it out or create from main.
4. Read `CONSTITUTION.md` in the project root — all code must follow these engineering principles.
5. Pick the **highest priority** user story where `passes: false`
6. Implement that single user story
7. Run quality checks: `npx tsc --noEmit` must pass with zero errors
8. If checks pass, commit ALL changes with message: `feat: [Story ID] - [Story Title]`
9. Update the PRD to set `passes: true` for the completed story
10. Append your progress to `ralph/progress.txt`

## Architecture Rules (from CONSTITUTION.md)

- **Types first**: Define new types in `types.ts` before use
- **Pure core**: `engine/` files must not import from `components/`, `services/`, or `styles/`
- **Services wrap I/O**: All network/storage calls go through `services/`
- **Components are views**: No business logic in `components/` — dispatch actions or call services
- **Named constants**: No magic numbers — use `engine/constants.ts`
- **Structured logging**: Use `utils/logger.ts` (after US-002), not raw console.*

## Progress Report Format

APPEND to ralph/progress.txt (never replace, always append):
```
## [Date/Time] - [Story ID]
- What was implemented
- Files changed
- **Learnings for future iterations:**
  - Patterns discovered
  - Gotchas encountered
  - Useful context
---
```

## Consolidate Patterns

If you discover a **reusable pattern**, add it to the `## Codebase Patterns` section at the TOP of ralph/progress.txt (create it if it doesn't exist):

```
## Codebase Patterns
- Example: All constants in engine/constants.ts
- Example: Use Result<T,E> for fallible operations
```

Only add patterns that are **general and reusable**, not story-specific details.

## Quality Requirements

- ALL commits must pass typecheck: `npx tsc --noEmit`
- Do NOT commit broken code
- Keep changes focused and minimal
- Follow existing code patterns and CONSTITUTION.md
- Follow the dependency rules: components → engine ✅, engine → components ❌

## Stop Condition

After completing a user story, check if ALL stories have `passes: true`.

If ALL stories are complete and passing, reply with:
<promise>COMPLETE</promise>

If there are still stories with `passes: false`, end your response normally (another iteration will pick up the next story).

## Important

- Work on ONE story per iteration
- Commit frequently
- Keep typecheck green
- Read the Codebase Patterns section in ralph/progress.txt before starting
