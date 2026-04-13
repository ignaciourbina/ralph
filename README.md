# Ralph

![Ralph](ralph.webp)

Ralph is an autonomous AI agent loop that runs AI coding tools ([Amp](https://ampcode.com), [Claude Code](https://docs.anthropic.com/en/docs/claude-code), [GitHub Copilot](https://github.com/features/copilot), or Codex) repeatedly until all PRD items are complete. Each iteration is a fresh instance with clean context. Memory persists via git history, `progress.txt`, and `prd.json`.

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

[Read my in-depth article on how I use Ralph](https://x.com/ryancarson/status/2008548371712135632)

## Prerequisites

- One of the following AI coding tools installed and authenticated:
  - [Amp CLI](https://ampcode.com)
  - [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (`npm install -g @anthropic-ai/claude-code`) (default)
  - [GitHub Copilot CLI](https://github.com/features/copilot)
  - Codex CLI (`codex`)
- `jq` installed (`brew install jq` on macOS)
- A git repository for your project

## Setup

### Option 1: Copy to your project

Copy the ralph files into your project:

```bash
# From your project root
mkdir -p scripts/ralph
cp /path/to/ralph/ralph.sh scripts/ralph/

# Copy the prompt template for your AI tool of choice:
cp /path/to/ralph/prompt.md scripts/ralph/prompt.md    # For Amp
# OR
cp /path/to/ralph/CLAUDE.md scripts/ralph/CLAUDE.md    # For Claude Code
# OR
cp /path/to/ralph/COPILOT.md scripts/ralph/COPILOT.md  # For GitHub Copilot
# OR
cp /path/to/ralph/AGENTS.md scripts/ralph/AGENTS.md    # For Codex

chmod +x scripts/ralph/ralph.sh
```

### Option 2: Install skills globally

Copy the skills to your tool config for use across all projects:

For AMP
```bash
cp -r skills/prd ~/.config/amp/skills/
cp -r skills/ralph ~/.config/amp/skills/
```

For Claude Code (manual)
```bash
cp -r skills/prd ~/.claude/skills/
cp -r skills/ralph ~/.claude/skills/
```

Or:

```bash
make install-skills-claude
```

For Codex
```bash
cp -r skills/prd ~/.codex/skills/
cp -r skills/ralph ~/.codex/skills/
```

Or use the bundled installer:

```bash
make install-skills
make install-skills-codex
```

For GitHub Copilot
Copilot uses the `COPILOT.md` prompt file and `make run-copilot`. Ralph does not currently install Copilot slash-skills because this repo only ships Claude/Codex-compatible skill directories.

### Option 3: Use as Claude Code Marketplace

Add the Ralph marketplace to Claude Code:

```bash
/plugin marketplace add snarktank/ralph
```

Then install the skills:

```bash
/plugin install ralph-skills@ralph-marketplace
```

Available skills after installation:
- `/prd` - Generate Product Requirements Documents
- `/ralph` - Convert PRDs to prd.json format

Skills are automatically invoked when you ask Claude to:
- "create a prd", "write prd for", "plan this feature"
- "convert this prd", "turn into ralph format", "create prd.json"

### Option 4: Initialize `.codex` for Codex-compatible repos

If you use a local `init-codex` alias or want the same repo-local layout Ralph expects, initialize the target project with:

```bash
make init-codex PROJECT_DIR=/path/to/project
```

This creates:
- `.codex/config.toml`
- `.codex/rules/default.rules`

Ralph also does this automatically in safe mode when running with `--tool codex`.

### Configure Amp auto-handoff (recommended)

Add to `~/.config/amp/settings.json`:

```json
{
  "amp.experimental.autoHandoff": { "context": 90 }
}
```

This enables automatic handoff when context fills up, allowing Ralph to handle large stories that exceed a single context window.

## Workflow

### 1. Create a PRD

Use the PRD skill to generate a detailed requirements document:

```
Load the prd skill and create a PRD for [your feature description]
```

Answer the clarifying questions. The skill saves output to `tasks/prd-[feature-name].md`.

### 2. Convert PRD to Ralph format

Use the Ralph skill to convert the markdown PRD to JSON:

```
Load the ralph skill and convert tasks/prd-[feature-name].md to prd.json
```

This creates `prd.json` with user stories structured for autonomous execution.

### 3. Run Ralph

```bash
# Using Claude Code (default)
./scripts/ralph/ralph.sh [max_iterations]

# Using Claude Code explicitly
./scripts/ralph/ralph.sh --tool claude [max_iterations]

# Using Amp
./scripts/ralph/ralph.sh --tool amp [max_iterations]

# Using GitHub Copilot
./scripts/ralph/ralph.sh --tool copilot [max_iterations]

# Using Codex
./scripts/ralph/ralph.sh --tool codex [max_iterations]

# Dangerous modes
./scripts/ralph/ralph.sh --tool claude --dangerous [max_iterations]
./scripts/ralph/ralph.sh --tool codex --dangerous [max_iterations]
```

Default is 10 iterations. Use `--tool amp`, `--tool claude`, `--tool copilot`, or `--tool codex` to select your AI coding tool.

Ralph will:
1. Create a feature branch (from PRD `branchName`)
2. Pick the highest priority story where `passes: false`
3. Implement that single story
4. Run quality checks (typecheck, tests)
5. Commit if checks pass
6. Update `prd.json` to mark story as `passes: true`
7. Append learnings to `progress.txt`
8. Repeat until all stories pass or max iterations reached

## Key Files

| File | Purpose |
|------|---------|
| `ralph.sh` | The bash loop that spawns fresh AI instances (supports `--tool amp`, `--tool claude`, `--tool copilot`, or `--tool codex`) |
| `prompt.md` | Prompt template for Amp |
| `CLAUDE.md` | Prompt template for Claude Code |
| `COPILOT.md` | Prompt template for GitHub Copilot |
| `AGENTS.md` | Prompt contract for Codex runs |
| `prd.json` | User stories with `passes` status (the task list) |
| `prd.json.example` | Example PRD format for reference |
| `progress.txt` | Append-only learnings for future iterations |
| `skills/prd/` | Skill for generating PRDs (works with Amp, Claude Code, and Codex skill installs) |
| `skills/ralph/` | Skill for converting PRDs to JSON (works with Amp, Claude Code, and Codex skill installs) |
| `tools/init-codex.sh` | Creates `.codex/config.toml` and rules in the target project |
| `tools/install-skills.sh` | Copies Ralph skills into `~/.claude/skills` and/or `~/.codex/skills` |
| `.claude-plugin/` | Plugin manifest for Claude Code marketplace discovery |
| `FLOWCHART.md` | Detailed documentation of the interactive flowchart visualization |

## Flowchart

[![Ralph Flowchart](ralph-flowchart.png)](https://snarktank.github.io/ralph/)

**[View Interactive Flowchart](https://snarktank.github.io/ralph/)** - Click through to see each step with animations.

See [FLOWCHART.md](FLOWCHART.md) for a detailed breakdown of the flowchart's architecture, components, and design.

## Critical Concepts

### Each Iteration = Fresh Context

Each iteration spawns a **new AI instance** (Amp, Claude Code, Copilot, or Codex) with clean context. The only memory between iterations is:
- Git history (commits from previous iterations)
- `progress.txt` (learnings and context)
- `prd.json` (which stories are done)

### Small Tasks

Each PRD item should be small enough to complete in one context window. If a task is too big, the LLM runs out of context before finishing and produces poor code.

Right-sized stories:
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic
- Add a filter dropdown to a list

Too big (split these):
- "Build the entire dashboard"
- "Add authentication"
- "Refactor the API"

### AGENTS.md Updates Are Critical

After each iteration, Ralph should update the relevant `AGENTS.md` files with learnings. This is especially important for Codex, but the same habit improves future automated runs and human handoffs too.

Examples of what to add to AGENTS.md:
- Patterns discovered ("this codebase uses X for Y")
- Gotchas ("do not forget to update Z when changing W")
- Useful context ("the settings panel is in component X")

### Feedback Loops

Ralph only works if there are feedback loops:
- Typecheck catches type errors
- Tests verify behavior
- CI must stay green (broken code compounds across iterations)

### Browser Verification for UI Stories

Frontend stories must include "Verify in browser using dev-browser skill" in acceptance criteria. Ralph will use the dev-browser skill to navigate to the page, interact with the UI, and confirm changes work.

### Stop Condition

When all stories have `passes: true`, Ralph outputs `<promise>COMPLETE</promise>` and the loop exits.

## Debugging

Check current state:

```bash
# See which stories are done
cat prd.json | jq '.userStories[] | {id, title, passes}'

# See learnings from previous iterations
cat progress.txt

# Check git history
git log --oneline -10
```

## Customizing the Prompt

After copying `prompt.md` (for Amp), `CLAUDE.md` (for Claude Code), or `AGENTS.md` (for Codex) to your project, customize it for your project:
- Add project-specific quality check commands
- Include codebase conventions
- Add common gotchas for your stack

## Archiving

Ralph automatically archives previous runs when you start a new feature (different `branchName`). Archives are saved to `archive/YYYY-MM-DD-feature-name/`.

## References

- [Geoffrey Huntley's Ralph article](https://ghuntley.com/ralph/)
- [Amp documentation](https://ampcode.com/manual)
- [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code)
