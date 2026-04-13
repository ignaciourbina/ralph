#!/bin/bash

set -euo pipefail

TARGET="${1:-all}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

install_to() {
  local dest="$1"
  mkdir -p "$dest"
  cp -R "$SCRIPT_DIR/skills/prd" "$dest/"
  cp -R "$SCRIPT_DIR/skills/ralph" "$dest/"
  echo "Installed skills to $dest"
}

case "$TARGET" in
  claude)
    install_to "$HOME/.claude/skills"
    ;;
  codex)
    install_to "$HOME/.codex/skills"
    ;;
  all)
    install_to "$HOME/.claude/skills"
    install_to "$HOME/.codex/skills"
    ;;
  *)
    echo "Usage: $0 [claude|codex|all]"
    exit 1
    ;;
esac
