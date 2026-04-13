#!/bin/bash
# Ralph Lit Rev - Structured extraction loop for academic papers
# Usage: ./ralph.sh [--tool claude] [--project-dir PATH] [--dangerous] [max_iterations]

set -e

TOOL="claude"
MAX_ITERATIONS=50
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
      if [[ "$1" =~ ^[0-9]+$ ]]; then
        MAX_ITERATIONS="$1"
      fi
      shift
      ;;
  esac
done

if [[ "$TOOL" != "claude" ]]; then
  echo "Error: ralph-lit-rev currently only supports claude. Got '$TOOL'."
  exit 1
fi

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: Required command '$1' is not installed or not in PATH."
    exit 1
  fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARTICLES_FILE="$SCRIPT_DIR/articles-meta.json"
SCHEMA_FILE="$SCRIPT_DIR/extraction-schema.json"
EXTRACTIONS_FILE="$SCRIPT_DIR/extractions.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"

# Preflight
require_cmd jq
require_cmd claude

# Check required files
if [ ! -f "$SCHEMA_FILE" ]; then
  echo "Error: Missing extraction-schema.json. Run /schema skill first."
  exit 1
fi

if [ ! -f "$ARTICLES_FILE" ]; then
  echo "Error: Missing articles-meta.json. Run /prepare skill first."
  exit 1
fi

# Check Python venv and tools
VENV_DIR="$SCRIPT_DIR/.venv"
if [ ! -d "$VENV_DIR" ]; then
  echo "Error: Python venv not found. Run 'make setup' first."
  exit 1
fi

# Strip ralph's own .git so commits go to the parent project
if [ -d "$SCRIPT_DIR/.git" ]; then
  echo "Stripping .git from ralph directory (commits should go to parent project)"
  rm -rf "$SCRIPT_DIR/.git"
fi

# Resolve project directory
PROJECT_DIR="${PROJECT_DIR:-$(dirname "$SCRIPT_DIR")}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

if [ ! -d "$PROJECT_DIR" ]; then
  echo "Error: Project directory does not exist: $PROJECT_DIR"
  exit 1
fi

# Initialize .claude/settings.local.json for safe mode
if [[ "$DANGEROUS" == false ]]; then
  mkdir -p "$PROJECT_DIR/.claude"
  cat > "$PROJECT_DIR/.claude/settings.local.json" <<'SETTINGS'
{
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
}
SETTINGS
  echo "Initialized .claude/settings.local.json in $PROJECT_DIR"
fi

cd "$PROJECT_DIR"
echo "Working directory: $(pwd)"

if [ ! -f "$SCRIPT_DIR/CLAUDE.md" ]; then
  echo "Error: Missing prompt file: $SCRIPT_DIR/CLAUDE.md"
  exit 1
fi

# Initialize extractions.json if it doesn't exist
if [ ! -f "$EXTRACTIONS_FILE" ]; then
  echo "[]" > "$EXTRACTIONS_FILE"
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Lit Rev - Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

# Count articles
TOTAL=$(jq '.articles | length' "$ARTICLES_FILE")
DONE=$(jq '[.articles[] | select(.processed == true)] | length' "$ARTICLES_FILE")

MODE="safe"
[[ "$DANGEROUS" == true ]] && MODE="dangerous"
echo "Starting Ralph Lit Rev - Mode: $MODE - Max iterations: $MAX_ITERATIONS"
echo "Articles: $DONE / $TOTAL processed"

for i in $(seq 1 $MAX_ITERATIONS); do
  # Recount each iteration
  DONE=$(jq '[.articles[] | select(.processed == true)] | length' "$ARTICLES_FILE")
  REMAINING=$((TOTAL - DONE))

  if [ "$REMAINING" -eq 0 ]; then
    echo ""
    echo "All $TOTAL articles have been processed."
    exit 0
  fi

  echo ""
  echo "==============================================================="
  echo "  Ralph Lit Rev - Iteration $i of $MAX_ITERATIONS"
  echo "  Articles remaining: $REMAINING of $TOTAL"
  echo "==============================================================="

  if [[ "$DANGEROUS" == true ]]; then
    OUTPUT=$(claude --dangerously-skip-permissions --print --verbose \
      --output-format stream-json --include-partial-messages \
      < "$SCRIPT_DIR/CLAUDE.md" 2>&1 | tee /dev/stderr) || true
  else
    OUTPUT=$(claude --print --verbose \
      --output-format stream-json --include-partial-messages \
      --allowedTools "Read,Edit,Write,Bash,Glob,Grep" \
      < "$SCRIPT_DIR/CLAUDE.md" 2>&1 | tee /dev/stderr) || true
  fi

  # Check for completion signal
  if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
    echo ""
    echo "All articles processed."
    DONE=$(jq '[.articles[] | select(.processed == true)] | length' "$ARTICLES_FILE")
    echo "Final count: $DONE / $TOTAL"
    exit 0
  fi

  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Reached max iterations ($MAX_ITERATIONS)."
DONE=$(jq '[.articles[] | select(.processed == true)] | length' "$ARTICLES_FILE")
echo "Processed $DONE / $TOTAL articles."
echo "Check $PROGRESS_FILE for status."
exit 1
