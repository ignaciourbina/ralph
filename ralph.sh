#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop
# Usage: ./ralph.sh [--tool amp|claude|copilot|codex] [--model MODEL] [--project-dir PATH] [--dangerous] [max_iterations]

set -uo pipefail

# When stdout/stderr are redirected to regular files (e.g. nohup ... > run.log),
# reopen them in append mode. Otherwise the shell's own writes and tee's
# appends keep independent file offsets and overwrite each other's output.
for _fd in 1 2; do
  _tgt=$(readlink "/proc/$$/fd/$_fd" 2>/dev/null || true)
  if [[ -n "$_tgt" && -f "$_tgt" ]]; then
    eval "exec $_fd>>\"\$_tgt\""
  fi
done
unset _fd _tgt

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"
LOCK_DIR="$SCRIPT_DIR/.ralph.lock"

# Abort the loop after this many consecutive iterations that fail instantly
# (tool crash, auth failure, empty output) instead of burning all iterations.
MAX_FAILURE_STREAK=3
MIN_ITERATION_SECONDS=20

usage() {
  echo "Usage: $0 [--tool amp|claude|copilot|codex] [--model MODEL] [--project-dir PATH] [--dangerous] [max_iterations]"
}

die() {
  echo "Error: $*" >&2
  exit 1
}

warn() {
  echo "Warning: $*" >&2
}

# Parse arguments
TOOL="claude"  # Default to claude for local environment
MODEL="claude-fable-5"  # Claude model passed to non-interactive runs
MAX_ITERATIONS=10
DANGEROUS=false
PROJECT_DIR=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --tool)
      [[ $# -ge 2 ]] || { usage >&2; die "--tool requires a value"; }
      TOOL="$2"
      shift 2
      ;;
    --tool=*)
      TOOL="${1#*=}"
      shift
      ;;
    --model)
      [[ $# -ge 2 ]] || { usage >&2; die "--model requires a value"; }
      MODEL="$2"
      shift 2
      ;;
    --model=*)
      MODEL="${1#*=}"
      shift
      ;;
    --project-dir)
      [[ $# -ge 2 ]] || { usage >&2; die "--project-dir requires a value"; }
      PROJECT_DIR="$2"
      shift 2
      ;;
    --project-dir=*)
      PROJECT_DIR="${1#*=}"
      shift
      ;;
    --dangerous)
      DANGEROUS=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      usage >&2
      die "Unknown option: $1"
      ;;
    *)
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
      else
        usage >&2
        die "Unexpected argument: '$1' (max_iterations must be a positive integer)"
      fi
      shift
      ;;
  esac
done

# Validate tool choice
if [[ "$TOOL" != "amp" && "$TOOL" != "claude" && "$TOOL" != "copilot" && "$TOOL" != "codex" ]]; then
  die "Invalid tool '$TOOL'. Must be 'amp', 'claude', 'copilot', or 'codex'."
fi

if [[ "$MAX_ITERATIONS" -lt 1 ]]; then
  die "max_iterations must be >= 1 (got $MAX_ITERATIONS)"
fi
if [[ "$MAX_ITERATIONS" -gt 1000 ]]; then
  die "max_iterations of $MAX_ITERATIONS looks like a mistake (limit: 1000)"
fi

[[ -n "$MODEL" ]] || die "--model must not be empty"
if [[ "$TOOL" != "claude" && "$MODEL" != "claude-fable-5" ]]; then
  warn "--model only applies to --tool claude; ignored for '$TOOL'"
fi

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    die "Required command '$1' is not installed or not in PATH."
  fi
}

# Preflight checks
require_cmd jq
require_cmd git
if [[ "$TOOL" == "amp" ]]; then
  require_cmd amp
elif [[ "$TOOL" == "copilot" ]]; then
  require_cmd copilot
elif [[ "$TOOL" == "codex" ]]; then
  require_cmd codex
else
  require_cmd claude
fi

# Resolve project directory: explicit flag > superproject working tree > parent
# of ralph/. The superproject query answers only when ralph is a submodule, and
# must run before the .git strip below while the gitlink is still readable.
if [[ -z "$PROJECT_DIR" ]]; then
  PROJECT_DIR=$(git -C "$SCRIPT_DIR" rev-parse --show-superproject-working-tree 2>/dev/null || true)
fi
PROJECT_DIR="${PROJECT_DIR:-$(dirname "$SCRIPT_DIR")}"
[[ -d "$PROJECT_DIR" ]] || die "Project directory does not exist: $PROJECT_DIR"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"  # resolve to absolute path

if [[ "$PROJECT_DIR" == "$SCRIPT_DIR" ]]; then
  die "Project directory resolves to the ralph directory itself. Run ralph from inside a project (ralph/ as a subdirectory), or pass --project-dir."
fi

# The whole workflow commits to the project's repo; refuse to start without one.
if ! PROJECT_TOPLEVEL=$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null); then
  die "Project directory is not inside a git repository: $PROJECT_DIR (ralph commits its work; initialize a repo first)"
fi
if [[ "$PROJECT_TOPLEVEL" != "$PROJECT_DIR" ]]; then
  warn "Project directory is not the repo root (root: $PROJECT_TOPLEVEL). Commits will go to that repo."
fi

# Strip ralph's own .git so commits go to the parent project.
# Guarded: this only ever runs after the parent project repo has been
# confirmed above, so we never delete the only repository in sight.
if [[ -d "$SCRIPT_DIR/.git" ]]; then
  echo "Stripping .git from ralph directory (commits should go to parent project)"
  rm -rf "$SCRIPT_DIR/.git"
elif [[ -f "$SCRIPT_DIR/.git" ]]; then
  # A .git *file* is a submodule gitlink: ralph is installed as a submodule
  # (e.g. tooling/ralph) and its files belong to the submodule's own repo.
  # Deleting the gitlink silently destroys that registration, and it is not
  # needed anyway -- commits reach the project repo because we cd into it.
  echo "ralph/ is a git submodule; leaving its gitlink intact."
fi

# Under `--sandbox workspace-write` codex may write only inside the project
# tree. A worktree or submodule keeps its git metadata elsewhere, so commits
# fail unless those directories are handed to codex explicitly.
CODEX_EXTRA_DIR_ARGS=()
append_if_dir() {
  local candidate="$1"
  [[ -n "$candidate" && -d "$candidate" ]] || return 0
  CODEX_EXTRA_DIR_ARGS+=("--add-dir" "$(cd "$candidate" && pwd)")
}

# Single-instance lock: two concurrent loops on the same ralph dir would
# interleave commits and clobber prd.json/progress.txt.
acquire_lock() {
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    echo $$ > "$LOCK_DIR/pid"
    return 0
  fi
  local holder
  holder=$(cat "$LOCK_DIR/pid" 2>/dev/null || echo "")
  if [[ -n "$holder" ]] && kill -0 "$holder" 2>/dev/null; then
    die "Another ralph loop (PID $holder) is already running on $SCRIPT_DIR. Stop it or wait for it to finish."
  fi
  warn "Removing stale lock (PID ${holder:-unknown} is gone)."
  rm -rf "$LOCK_DIR"
  mkdir "$LOCK_DIR" 2>/dev/null || die "Could not acquire lock at $LOCK_DIR"
  echo $$ > "$LOCK_DIR/pid"
}

release_lock() {
  rm -rf "$LOCK_DIR"
}

acquire_lock
trap 'release_lock' EXIT
trap 'echo ""; echo "Interrupted. Stopping ralph loop."; exit 130' INT TERM

# Infrastructure self-repair: a previous iteration can delete or untrack the
# files the loop itself depends on, which strands every later iteration.
# Restore them from the PRD's baseBranch before spending tokens.
#
# This only applies when the PROJECT repo is what tracks ralph's files. If
# ralph is installed as a submodule they belong to the submodule instead, so
# "untracked by the project" is the normal state and there is nothing to fix.
if [[ -e "$SCRIPT_DIR/.git" ]]; then
  echo "Preflight: ralph has its own git dir; skipping infrastructure self-repair."
elif [[ -f "$PRD_FILE" ]]; then
  AGENT_REL_DIR=$(realpath --relative-to="$PROJECT_DIR" "$SCRIPT_DIR")
  BASE_BRANCH=$(jq -r '.baseBranch // "main"' "$PRD_FILE" 2>/dev/null || echo "main")
  INFRA_REPAIRED=()
  INFRA_FAILED=()

  for f in CLAUDE.md AGENTS.md COPILOT.md prompt.md ralph.sh Makefile; do
    fpath="$SCRIPT_DIR/$f"
    rel="$AGENT_REL_DIR/$f"
    # Never "repair" a deliberately ignored file (prd.json, progress.txt).
    git -C "$PROJECT_DIR" check-ignore -q "$rel" 2>/dev/null && continue
    # Only consider files the base branch actually carries.
    git -C "$PROJECT_DIR" cat-file -e "$BASE_BRANCH:$rel" 2>/dev/null || continue

    if [[ -f "$fpath" ]] && git -C "$PROJECT_DIR" ls-files --error-unmatch "$rel" >/dev/null 2>&1; then
      continue
    fi
    if git -C "$PROJECT_DIR" show "$BASE_BRANCH:$rel" > "$fpath" 2>/dev/null; then
      git -C "$PROJECT_DIR" add "$rel" 2>/dev/null || true
      [[ "$f" == *.sh ]] && chmod +x "$fpath" 2>/dev/null
      INFRA_REPAIRED+=("$f")
    else
      INFRA_FAILED+=("$f")
    fi
  done

  if [[ ${#INFRA_REPAIRED[@]} -gt 0 ]]; then
    echo "Preflight: restored ${#INFRA_REPAIRED[@]} infrastructure file(s) from $BASE_BRANCH: ${INFRA_REPAIRED[*]}"
    git -C "$PROJECT_DIR" commit -m "fix(preflight): restore infrastructure files from $BASE_BRANCH

Restored: ${INFRA_REPAIRED[*]}" >/dev/null 2>&1 || warn "Could not commit the restored infrastructure files."
  fi
  if [[ ${#INFRA_FAILED[@]} -gt 0 ]]; then
    die "Could not restore infrastructure files from $BASE_BRANCH: ${INFRA_FAILED[*]}"
  fi
fi

# Validate the PRD before spending any tokens on it
[[ -f "$PRD_FILE" ]] || die "Missing PRD file: $PRD_FILE (run your prd/sprint prep first)"
jq empty "$PRD_FILE" 2>/dev/null || die "PRD file is not valid JSON: $PRD_FILE"
jq -e 'has("branchName") and (.userStories | type == "array" and length > 0)' "$PRD_FILE" >/dev/null 2>&1 \
  || die "PRD file must contain branchName and a non-empty userStories array: $PRD_FILE"

REMAINING=$(jq '[.userStories[] | select(.passes != true)] | length' "$PRD_FILE")
if [[ "$REMAINING" -eq 0 ]]; then
  echo "All user stories in $PRD_FILE already have passes: true. Nothing to do."
  exit 0
fi

# Initialize Claude permissions for safe mode (default).
# Written to settings.local.json (not settings.json) so a project's checked-in
# settings are never clobbered; an existing local file is backed up first.
if [[ "$DANGEROUS" == false && "$TOOL" == "claude" ]]; then
  mkdir -p "$PROJECT_DIR/.claude"
  SETTINGS_FILE="$PROJECT_DIR/.claude/settings.local.json"
  SETTINGS_CONTENT='{
  "permissions": {
    "allow": [
      "Bash(*)",
      "Write(*)",
      "Read(*)",
      "Edit(*)",
      "Glob(*)",
      "Grep(*)"
    ]
  }
}'
  if [[ -f "$SETTINGS_FILE" ]] && ! diff -q <(echo "$SETTINGS_CONTENT") "$SETTINGS_FILE" >/dev/null 2>&1; then
    BACKUP="$SETTINGS_FILE.ralph-bak.$(date +%Y%m%d%H%M%S)"
    cp "$SETTINGS_FILE" "$BACKUP" || die "Could not back up $SETTINGS_FILE"
    warn "Existing $SETTINGS_FILE backed up to $BACKUP"
  fi
  echo "$SETTINGS_CONTENT" > "$SETTINGS_FILE"
  echo "Initialized $SETTINGS_FILE"
fi

# Initialize .codex/config.toml for safe mode to match init-codex repos
if [[ "$DANGEROUS" == false && "$TOOL" == "codex" ]]; then
  if [[ -f "$SCRIPT_DIR/tools/init-codex.sh" ]]; then
    bash "$SCRIPT_DIR/tools/init-codex.sh" "$PROJECT_DIR"
  else
    warn "tools/init-codex.sh not found; skipping codex sandbox init."
  fi
fi

if [[ "$TOOL" == "codex" && "$DANGEROUS" == false ]]; then
  append_if_dir "$(git -C "$PROJECT_DIR" rev-parse --git-dir 2>/dev/null || true)"
  append_if_dir "$(git -C "$PROJECT_DIR" rev-parse --git-common-dir 2>/dev/null || true)"
  if [[ ${#CODEX_EXTRA_DIR_ARGS[@]} -gt 0 ]]; then
    echo "Codex writable git dirs: ${CODEX_EXTRA_DIR_ARGS[*]}"
  fi
fi

# Change to project directory so the tool scopes to it via .git discovery
cd "$PROJECT_DIR" || die "Could not cd into $PROJECT_DIR"
echo "Working directory: $(pwd)"

# Each tool needs its prompt file, and it must be non-empty
PROMPT_FILE=""
case "$TOOL" in
  amp)     PROMPT_FILE="$SCRIPT_DIR/prompt.md" ;;
  claude)  PROMPT_FILE="$SCRIPT_DIR/CLAUDE.md" ;;
  copilot) PROMPT_FILE="$SCRIPT_DIR/COPILOT.md" ;;
  codex)   PROMPT_FILE="$SCRIPT_DIR/AGENTS.md" ;;
esac
[[ -f "$PROMPT_FILE" ]] || die "Missing prompt file: $PROMPT_FILE"
[[ -s "$PROMPT_FILE" ]] || die "Prompt file is empty: $PROMPT_FILE"

# Archive previous run if branch changed
if [[ -f "$LAST_BRANCH_FILE" ]]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")

  if [[ -n "$CURRENT_BRANCH" && -n "$LAST_BRANCH" && "$CURRENT_BRANCH" != "$LAST_BRANCH" ]]; then
    # Archive the previous run
    DATE=$(date +%Y-%m-%d)
    # Strip "ralph/" prefix from branch name for folder
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||' | tr '/' '-')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"
    # Never overwrite an existing archive (same branch re-prepped same day)
    if [[ -e "$ARCHIVE_FOLDER" ]]; then
      ARCHIVE_FOLDER="$ARCHIVE_FOLDER-$(date +%H%M%S)"
    fi

    echo "Archiving previous run: $LAST_BRANCH"
    if mkdir -p "$ARCHIVE_FOLDER" \
       && cp "$PRD_FILE" "$ARCHIVE_FOLDER/" \
       && { [[ ! -f "$PROGRESS_FILE" ]] || cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"; }; then
      echo "   Archived to: $ARCHIVE_FOLDER"
    else
      die "Failed to archive previous run to $ARCHIVE_FOLDER (not resetting progress log)."
    fi

    # Reset progress file for new run
    {
      echo "# Ralph Progress Log"
      echo "Started: $(date)"
      echo "---"
    } > "$PROGRESS_FILE"
  fi
fi

# Track current branch
CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
if [[ -n "$CURRENT_BRANCH" ]]; then
  echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
fi

# Initialize progress file if it doesn't exist
if [[ ! -f "$PROGRESS_FILE" ]]; then
  {
    echo "# Ralph Progress Log"
    echo "Started: $(date)"
    echo "---"
  } > "$PROGRESS_FILE"
fi

MODE="safe"
[[ "$DANGEROUS" == true ]] && MODE="dangerous"
echo "Starting Ralph - Tool: $TOOL - Model: $MODEL - Mode: $MODE - Max iterations: $MAX_ITERATIONS - Stories remaining: $REMAINING"

FAILURE_STREAK=0

for ((i = 1; i <= MAX_ITERATIONS; i++)); do
  echo ""
  echo "==============================================================="
  echo "  Ralph Iteration $i of $MAX_ITERATIONS ($TOOL)"
  echo "==============================================================="

  # Re-read the PRD rather than trusting the count taken before the loop:
  # the agent flips `passes` as it goes, so this exits on real state instead
  # of waiting for the completion token the agent may never emit.
  REMAINING=$(jq '[.userStories[] | select(.passes != true)] | length' "$PRD_FILE" 2>/dev/null || echo "-1")
  if [[ "$REMAINING" -eq 0 ]]; then
    echo ""
    echo "All user stories now pass. Stopping at iteration $i."
    exit 0
  fi
  [[ "$REMAINING" -ge 0 ]] && echo "  Stories remaining: $REMAINING"

  ITER_START=$SECONDS
  RC=0

  # Run the selected tool with the ralph prompt.
  # NOTE: tee -a is load-bearing. Plain `tee /dev/stderr` truncates its target,
  # which wipes the log file every iteration when stderr is redirected to one.
  if [[ "$TOOL" == "amp" ]]; then
    OUTPUT=$(amp --dangerously-allow-all < "$SCRIPT_DIR/prompt.md" 2>&1 | tee -a /dev/stderr) || RC=$?
  elif [[ "$TOOL" == "copilot" ]]; then
    # Copilot CLI mode
    if [[ "$DANGEROUS" == true ]]; then
      OUTPUT=$(copilot -p "$(cat "$SCRIPT_DIR/COPILOT.md")" --allow-all 2>&1 | tee -a /dev/stderr) || RC=$?
    else
      OUTPUT=$(copilot -p "$(cat "$SCRIPT_DIR/COPILOT.md")" --allow-all-tools 2>&1 | tee -a /dev/stderr) || RC=$?
    fi
  elif [[ "$TOOL" == "codex" ]]; then
    LAST_MSG=$(mktemp)
    if [[ "$DANGEROUS" == true ]]; then
      OUTPUT=$(codex exec \
        --cd "$PROJECT_DIR" \
        --dangerously-bypass-approvals-and-sandbox \
        --output-last-message "$LAST_MSG" \
        < "$SCRIPT_DIR/AGENTS.md" 2>&1 | tee -a /dev/stderr) || RC=$?
    else
      OUTPUT=$(codex exec \
        --cd "$PROJECT_DIR" \
        --sandbox workspace-write \
        ${CODEX_EXTRA_DIR_ARGS[@]+"${CODEX_EXTRA_DIR_ARGS[@]}"} \
        --output-last-message "$LAST_MSG" \
        < "$SCRIPT_DIR/AGENTS.md" 2>&1 | tee -a /dev/stderr) || RC=$?
    fi
    LAST_OUTPUT=$(cat "$LAST_MSG" 2>/dev/null || true)
    OUTPUT="$OUTPUT"$'\n'"$LAST_OUTPUT"
    rm -f "$LAST_MSG"
  elif [[ "$DANGEROUS" == true ]]; then
    # Dangerous mode: bypass all permission checks
    OUTPUT=$(claude --model "$MODEL" --dangerously-skip-permissions --print --verbose --output-format stream-json --include-partial-messages < "$SCRIPT_DIR/CLAUDE.md" 2>&1 | tee -a /dev/stderr) || RC=$?
  else
    # Safe mode: use settings.local.json + allowedTools for headless auto-approval
    OUTPUT=$(claude --model "$MODEL" --print --verbose --output-format stream-json --include-partial-messages --allowedTools "Read,Edit,Write,Bash" < "$SCRIPT_DIR/CLAUDE.md" 2>&1 | tee -a /dev/stderr) || RC=$?
  fi

  ITER_SECONDS=$((SECONDS - ITER_START))

  # Check for completion signal
  if echo "$OUTPUT" | grep -qF "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Ralph completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    exit 0
  fi

  # Fail fast on a broken setup (bad auth, missing model, crashing CLI):
  # an iteration that dies instantly or produces nothing will never make
  # progress, and burning the remaining iterations just repeats the failure.
  if [[ -z "${OUTPUT//[[:space:]]/}" || ( $RC -ne 0 && $ITER_SECONDS -lt $MIN_ITERATION_SECONDS ) ]]; then
    FAILURE_STREAK=$((FAILURE_STREAK + 1))
    warn "Iteration $i looks like a hard failure (exit=$RC, ${ITER_SECONDS}s, output ${#OUTPUT} bytes). Streak: $FAILURE_STREAK/$MAX_FAILURE_STREAK"
    if [[ $FAILURE_STREAK -ge $MAX_FAILURE_STREAK ]]; then
      die "$MAX_FAILURE_STREAK consecutive failed iterations. Aborting; check tool auth/installation and the last output above."
    fi
  else
    FAILURE_STREAK=0
  fi

  echo "Iteration $i complete (exit=$RC, ${ITER_SECONDS}s). Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
