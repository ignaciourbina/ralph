#!/bin/bash

set -euo pipefail

PROJECT_DIR="${1:-.}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

mkdir -p "$PROJECT_DIR/.codex/rules"

if [[ ! -f "$PROJECT_DIR/.codex/config.toml" ]]; then
cat > "$PROJECT_DIR/.codex/config.toml" <<'TOML'
# Project-level Codex config
# Permissive, but still sandboxed.
approval_policy = "never"
sandbox_mode = "workspace-write"

[sandbox_workspace_write]
network_access = true
exclude_tmpdir_env_var = false
exclude_slash_tmp = false
TOML
fi

if [[ ! -f "$PROJECT_DIR/.codex/rules/default.rules" ]]; then
cat > "$PROJECT_DIR/.codex/rules/default.rules" <<'RULES'
# Selectively allow common dev commands to run outside the sandbox.
# Experimental Codex execpolicy rules.

# Python
prefix_rule(pattern=["python"], decision="allow")
prefix_rule(pattern=["python3"], decision="allow")
prefix_rule(pattern=["pip"], decision="allow")
prefix_rule(pattern=["pip3"], decision="allow")
prefix_rule(pattern=["uv"], decision="allow")
prefix_rule(pattern=["pytest"], decision="allow")

# Git
prefix_rule(pattern=["git"], decision="allow")

# Build / shell
prefix_rule(pattern=["make"], decision="allow")
prefix_rule(pattern=["bash"], decision="allow")
prefix_rule(pattern=["sh"], decision="allow")

# File ops
prefix_rule(pattern=["cat"], decision="allow")
prefix_rule(pattern=["ls"], decision="allow")
prefix_rule(pattern=["find"], decision="allow")
prefix_rule(pattern=["grep"], decision="allow")
prefix_rule(pattern=["rg"], decision="allow")
prefix_rule(pattern=["head"], decision="allow")
prefix_rule(pattern=["tail"], decision="allow")
prefix_rule(pattern=["wc"], decision="allow")
prefix_rule(pattern=["diff"], decision="allow")
prefix_rule(pattern=["mkdir"], decision="allow")
prefix_rule(pattern=["cp"], decision="allow")
prefix_rule(pattern=["mv"], decision="allow")
prefix_rule(pattern=["touch"], decision="allow")

# Network
prefix_rule(pattern=["curl"], decision="allow")
prefix_rule(pattern=["wget"], decision="allow")
RULES
fi

echo "Ensured .codex/config.toml and .codex/rules/default.rules exist in $PROJECT_DIR"
