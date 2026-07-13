# Ralph - Autonomous AI Agent Loop
# Run `make help` for available commands

.PHONY: help run run-claude run-dangerous run-amp run-copilot run-codex run-codex-dangerous init-codex install-skills install-skills-claude install-skills-codex status reset clean

SHELL := /bin/bash
RALPH_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
PRD_FILE := $(RALPH_DIR)/prd.json
PROGRESS_FILE := $(RALPH_DIR)/progress.txt

# Default iterations
N ?= 27
# Project directory (defaults to parent of ralph/)
PROJECT_DIR ?= $(shell dirname $(RALPH_DIR))

help:
	@echo ""
	@echo "╔═══════════════════════════════════════════════════╗"
	@echo "║           Ralph - Autonomous Agent Loop           ║"
	@echo "╚═══════════════════════════════════════════════════╝"
	@echo ""
	@echo "  Usage:"
	@echo "    make run                          Run with Claude (safe mode, default)"
	@echo "    make run-claude                   Run with Claude (safe mode)"
	@echo "    make run N=10                     Custom max iterations"
	@echo "    make run PROJECT_DIR=/path/to/dir Target a specific project"
	@echo "    make run-dangerous                Run Claude with --dangerously-skip-permissions"
	@echo "    make run-amp                      Run with Amp"
	@echo "    make run-copilot                  Run with GitHub Copilot"
	@echo "    make run-codex                    Run with Codex"
	@echo "    make run-codex-dangerous          Run Codex without sandbox/approval checks"
	@echo ""
	@echo "  Setup:"
	@echo "    make init-codex                   Create .codex config/rules in PROJECT_DIR"
	@echo "    make install-skills               Copy skills to ~/.claude/skills and ~/.codex/skills"
	@echo "    make install-skills-claude        Copy skills to ~/.claude/skills"
	@echo "    make install-skills-codex         Copy skills to ~/.codex/skills"
	@echo ""
	@echo "  Status:"
	@echo "    make status           Show PRD progress"
	@echo "    make progress         Show progress log"
	@echo ""
	@echo "  Maintenance:"
	@echo "    make reset            Reset progress (keep PRD)"
	@echo "    make clean            Remove progress + archive"
	@echo ""

# Primary target: run with Claude Code (safe mode — uses settings.json + allowedTools)
run run-claude:
	@$(RALPH_DIR)/ralph.sh --tool claude --project-dir $(PROJECT_DIR) $(N)

# Dangerous mode: bypass all permission checks
run-dangerous:
	@$(RALPH_DIR)/ralph.sh --tool claude --dangerous --project-dir $(PROJECT_DIR) $(N)

# Alternative: run with Amp
run-amp:
	@$(RALPH_DIR)/ralph.sh --tool amp $(N)

# Alternative: run with GitHub Copilot
run-copilot:
	@$(RALPH_DIR)/ralph.sh --tool copilot --project-dir $(PROJECT_DIR) $(N)

# Alternative: run with Codex
run-codex:
	@$(RALPH_DIR)/ralph.sh --tool codex --project-dir $(PROJECT_DIR) $(N)

run-codex-dangerous:
	@$(RALPH_DIR)/ralph.sh --tool codex --dangerous --project-dir $(PROJECT_DIR) $(N)

# Initialize project-local Codex config in the style of init-codex
init-codex:
	@bash $(RALPH_DIR)/tools/init-codex.sh $(PROJECT_DIR)

# Install skills to both Claude and Codex homes
install-skills:
	@bash $(RALPH_DIR)/tools/install-skills.sh all

install-skills-claude:
	@bash $(RALPH_DIR)/tools/install-skills.sh claude

install-skills-codex:
	@bash $(RALPH_DIR)/tools/install-skills.sh codex

# Show PRD completion status
status:
	@echo ""
	@echo "PRD Status: $$(jq -r '.project' $(PRD_FILE))"
	@echo "Branch:     $$(jq -r '.branchName' $(PRD_FILE))"
	@echo ""
	@echo "Stories:"
	@jq -r '.userStories[] | "  " + (if .passes then "✅" else "⬜" end) + " [" + .id + "] (P" + (.priority|tostring) + ") " + .title' $(PRD_FILE)
	@echo ""
	@TOTAL=$$(jq '.userStories | length' $(PRD_FILE)); \
	 DONE=$$(jq '[.userStories[] | select(.passes == true)] | length' $(PRD_FILE)); \
	 echo "Progress: $$DONE / $$TOTAL stories complete"
	@echo ""

# Show progress log
progress:
	@if [ -f $(PROGRESS_FILE) ]; then cat $(PROGRESS_FILE); else echo "No progress log yet."; fi

# Reset progress but keep PRD
reset:
	@echo "Resetting progress..."
	@jq '.userStories |= map(.passes = false | .notes = "")' $(PRD_FILE) > $(PRD_FILE).tmp && mv $(PRD_FILE).tmp $(PRD_FILE)
	@echo "# Ralph Progress Log" > $(PROGRESS_FILE)
	@echo "Reset: $$(date)" >> $(PROGRESS_FILE)
	@echo "---" >> $(PROGRESS_FILE)
	@echo "Done. All stories reset to passes: false."

# Full clean
clean:
	@echo "Cleaning Ralph artifacts..."
	@rm -f $(PROGRESS_FILE)
	@rm -f $(RALPH_DIR)/.last-branch
	@echo "Clean complete. PRD preserved."
