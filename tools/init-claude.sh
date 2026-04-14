#!/bin/bash

set -euo pipefail

PROJECT_DIR="${1:-.}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

mkdir -p "$PROJECT_DIR/.claude"

if [[ ! -f "$PROJECT_DIR/.claude/settings.local.json" ]]; then
cat > "$PROJECT_DIR/.claude/settings.local.json" <<'EOF'
{
  "permissions": {
    "allow": [
      "Bash(*)",
      "Write(*)",
      "Read(*)",
      "Edit(*)",
      "Glob(*)",
      "Grep(*)",
      "WebSearch(*)",
      "WebFetch(*)"
    ]
  }
}
EOF
fi

echo "Ensured .claude/settings.local.json exists in $PROJECT_DIR"
