# Ralph Lit Rev - Structured extraction from academic papers
# Run `make help` for available commands

.PHONY: help setup run run-dangerous status progress prepare reset clean

SHELL := /bin/bash
RALPH_DIR := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
ARTICLES_FILE := $(RALPH_DIR)/articles-meta.json
EXTRACTIONS_FILE := $(RALPH_DIR)/extractions.json
PROGRESS_FILE := $(RALPH_DIR)/progress.txt
SCHEMA_FILE := $(RALPH_DIR)/extraction-schema.json

# Default iterations
N ?= 50
# Project directory (defaults to parent of ralph/)
PROJECT_DIR ?= $(shell dirname $(RALPH_DIR))

help:
	@echo ""
	@echo "Ralph Lit Rev - Structured Paper Extraction"
	@echo "============================================"
	@echo ""
	@echo "  Setup:"
	@echo "    make setup                Set up Python venv and dependencies"
	@echo ""
	@echo "  Workflow:"
	@echo "    1. Run /schema skill      Design extraction schema interactively"
	@echo "    2. Run /prepare skill     Scan PDFs and build articles-meta.json"
	@echo "    3. make run               Start extraction loop"
	@echo ""
	@echo "  Run:"
	@echo "    make run                  Run extraction loop (safe mode)"
	@echo "    make run N=20             Custom max iterations"
	@echo "    make run-dangerous        Run with --dangerously-skip-permissions"
	@echo ""
	@echo "  Status:"
	@echo "    make status               Show extraction progress"
	@echo "    make progress             Show progress log"
	@echo ""
	@echo "  Maintenance:"
	@echo "    make reset                Reset all articles to unprocessed"
	@echo "    make clean                Remove extractions, progress, and venv"
	@echo ""

setup:
	@bash $(RALPH_DIR)/tools/setup.sh

run:
	@$(RALPH_DIR)/ralph.sh --project-dir $(PROJECT_DIR) $(N)

run-dangerous:
	@$(RALPH_DIR)/ralph.sh --dangerous --project-dir $(PROJECT_DIR) $(N)

status:
	@if [ ! -f $(ARTICLES_FILE) ]; then \
		echo "No articles-meta.json found. Run /prepare first."; \
		exit 0; \
	fi
	@echo ""
	@echo "Schema:  $$(if [ -f $(SCHEMA_FILE) ]; then jq -r '.reviewGoal' $(SCHEMA_FILE); else echo 'Not configured — run /schema'; fi)"
	@echo "Fields:  $$(if [ -f $(SCHEMA_FILE) ]; then jq '.fields | length' $(SCHEMA_FILE); else echo '-'; fi)"
	@echo ""
	@echo "Articles:"
	@jq -r '.articles[] | "  " + (if .processed then "done" else "    " end) + "  [" + .id + "] " + .provisionalTitle' $(ARTICLES_FILE)
	@echo ""
	@TOTAL=$$(jq '.articles | length' $(ARTICLES_FILE)); \
	 DONE=$$(jq '[.articles[] | select(.processed == true)] | length' $(ARTICLES_FILE)); \
	 echo "Progress: $$DONE / $$TOTAL articles processed"
	@echo ""

progress:
	@if [ -f $(PROGRESS_FILE) ]; then cat $(PROGRESS_FILE); else echo "No progress log yet."; fi

reset:
	@echo "Resetting all articles to unprocessed..."
	@if [ -f $(ARTICLES_FILE) ]; then \
		jq '.articles |= map(.processed = false)' $(ARTICLES_FILE) > $(ARTICLES_FILE).tmp \
		&& mv $(ARTICLES_FILE).tmp $(ARTICLES_FILE); \
	fi
	@echo "[]" > $(EXTRACTIONS_FILE)
	@echo "# Ralph Lit Rev - Progress Log" > $(PROGRESS_FILE)
	@echo "Reset: $$(date)" >> $(PROGRESS_FILE)
	@echo "---" >> $(PROGRESS_FILE)
	@echo "Done. All articles reset."

clean:
	@echo "Cleaning ralph-lit-rev artifacts..."
	@rm -f $(EXTRACTIONS_FILE)
	@rm -f $(PROGRESS_FILE)
	@rm -f $(ARTICLES_FILE)
	@rm -f $(SCHEMA_FILE)
	@rm -rf $(RALPH_DIR)/.venv
	@echo "Clean complete."
