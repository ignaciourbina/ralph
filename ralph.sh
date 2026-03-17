#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop
# Usage: ./ralph.sh [--tool amp|claude|copilot] [--project-dir PATH] [--dangerous] [max_iterations]

set -e

# Parse arguments
TOOL="claude"  # Default to claude for local environment
MAX_ITERATIONS=10
DANGEROUS=false
PROJECT_DIR=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --tool)
      TOOL="$2"
      shift 2
      ;;
    --tool=*)
      TOOL="${1#*=}"
      shift
      ;;
    --project-dir)
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
    *)
      # Assume it's max_iterations if it's a number
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
      fi
      shift
      ;;
  esac
done

# Validate tool choice
if [[ "$TOOL" != "amp" && "$TOOL" != "claude" && "$TOOL" != "copilot" ]]; then
  echo "Error: Invalid tool '$TOOL'. Must be 'amp', 'claude', or 'copilot'."
  exit 1
fi

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: Required command '$1' is not installed or not in PATH."
    exit 1
  fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"

# Preflight checks
require_cmd jq
if [[ "$TOOL" == "amp" ]]; then
  require_cmd amp
elif [[ "$TOOL" == "copilot" ]]; then
  require_cmd copilot
else
  require_cmd claude
fi

# Strip ralph's own .git so commits go to the parent project
if [ -d "$SCRIPT_DIR/.git" ]; then
  echo "Stripping .git from ralph directory (commits should go to parent project)"
  rm -rf "$SCRIPT_DIR/.git"
fi

# Resolve project directory: explicit flag > parent of ralph/
PROJECT_DIR="${PROJECT_DIR:-$(dirname "$SCRIPT_DIR")}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"  # resolve to absolute path

if [ ! -d "$PROJECT_DIR" ]; then
  echo "Error: Project directory does not exist: $PROJECT_DIR"
  exit 1
fi

# Initialize .claude/settings.json for safe mode (default)
if [[ "$DANGEROUS" == false && "$TOOL" == "claude" ]]; then
  mkdir -p "$PROJECT_DIR/.claude"
  cat > "$PROJECT_DIR/.claude/settings.json" <<'SETTINGS'
{
  "permissions": {
    "allow": [
      "Read",
      "Edit",
      "Write",
      "Bash"
    ]
  }
}
SETTINGS
  echo "Initialized .claude/settings.json in $PROJECT_DIR"
fi

# Change to project directory so Claude scopes to it via .git discovery
cd "$PROJECT_DIR"
echo "Working directory: $(pwd)"

if [[ "$TOOL" == "amp" && ! -f "$SCRIPT_DIR/prompt.md" ]]; then
  echo "Error: Missing prompt file: $SCRIPT_DIR/prompt.md"
  exit 1
fi

if [[ "$TOOL" == "claude" && ! -f "$SCRIPT_DIR/CLAUDE.md" ]]; then
  echo "Error: Missing prompt file: $SCRIPT_DIR/CLAUDE.md"
  exit 1
fi

if [[ "$TOOL" == "copilot" && ! -f "$SCRIPT_DIR/COPILOT.md" ]]; then
  echo "Error: Missing prompt file: $SCRIPT_DIR/COPILOT.md"
  exit 1
fi

# Archive previous run if branch changed
if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")
  
  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    # Archive the previous run
    DATE=$(date +%Y-%m-%d)
    # Strip "ralph/" prefix from branch name for folder
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"
    
    echo "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo "   Archived to: $ARCHIVE_FOLDER"
    
    # Reset progress file for new run
    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

# Track current branch
if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

MODE="safe"
[[ "$DANGEROUS" == true ]] && MODE="dangerous"
echo "Starting Ralph - Tool: $TOOL - Mode: $MODE - Max iterations: $MAX_ITERATIONS"

for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo "==============================================================="
  echo "  Ralph Iteration $i of $MAX_ITERATIONS ($TOOL)"
  echo "==============================================================="

  # Run the selected tool with the ralph prompt
  if [[ "$TOOL" == "amp" ]]; then
    OUTPUT=$(cat "$SCRIPT_DIR/prompt.md" | amp --dangerously-allow-all 2>&1 | tee /dev/stderr) || true
  elif [[ "$TOOL" == "copilot" ]]; then
    # Copilot CLI mode
    if [[ "$DANGEROUS" == true ]]; then
      OUTPUT=$(copilot -p "$(cat "$SCRIPT_DIR/COPILOT.md")" --allow-all 2>&1 | tee /dev/stderr) || true
    else
      OUTPUT=$(copilot -p "$(cat "$SCRIPT_DIR/COPILOT.md")" --allow-tool='read' --allow-tool='write' --allow-tool='edit' --allow-tool='shell(git:*)' --allow-tool='shell(npx:*)' --allow-tool='shell(node:*)' --allow-tool='shell(cat:*)' --allow-tool='shell(ls:*)' --allow-tool='shell(mkdir:*)' 2>&1 | tee /dev/stderr) || true
    fi
  elif [[ "$DANGEROUS" == true ]]; then
    # Dangerous mode: bypass all permission checks
    OUTPUT=$(claude --dangerously-skip-permissions --print --verbose --output-format stream-json --include-partial-messages < "$SCRIPT_DIR/CLAUDE.md" 2>&1 | tee /dev/stderr) || true
  else
    # Safe mode: use settings.json + allowedTools for headless auto-approval
    OUTPUT=$(claude --print --verbose --output-format stream-json --include-partial-messages --allowedTools "Read,Edit,Write,Bash" < "$SCRIPT_DIR/CLAUDE.md" 2>&1 | tee /dev/stderr) || true
  fi
  
  # Check for completion signal
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "Ralph completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    exit 0
  fi
  
  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
