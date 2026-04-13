#!/bin/bash
# Install ralph-lit-rev skills into the parent project's tool directories
# so Claude Code or Codex can discover them.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TARGET="${1:-all}"

install_to() {
  local target_dir="$1"
  mkdir -p "$target_dir"

  for skill_dir in "$SCRIPT_DIR"/skills/*/; do
    local skill_name
    skill_name="$(basename "$skill_dir")"
    if [ -f "$skill_dir/SKILL.md" ]; then
      mkdir -p "$target_dir/$skill_name"
      cp "$skill_dir/SKILL.md" "$target_dir/$skill_name/SKILL.md"
      echo "Installed skill: $skill_name -> $target_dir/$skill_name"
    fi
  done
}

case "$TARGET" in
  claude)
    install_to "$PROJECT_DIR/.claude/skills"
    ;;
  codex)
    install_to "$PROJECT_DIR/.codex/skills"
    ;;
  all)
    install_to "$PROJECT_DIR/.claude/skills"
    install_to "$PROJECT_DIR/.codex/skills"
    ;;
  *)
    echo "Usage: $0 [claude|codex|all]"
    exit 1
    ;;
esac
