# Claude Hub — Launch Registry
# Run `make help` to see all targets.
# Each target sets up the right scratchpad dir and launches Claude with the right prompt + tools.

SHELL := /bin/bash
DATE := $(shell date +%Y-%m-%d)
HUB := $(HOME)/claude-hub
TEMPLATES := $(HUB)/_templates
EFFORT ?= max

.PHONY: help

help: ## Show this help
	@echo ""
	@echo "  Claude Hub — Launch Registry"
	@echo "  ============================"
	@echo ""
	@echo "  Usage: make <target> [SLUG=my-description]"
	@echo ""
	@echo "  Targets:"
	@echo ""
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "    \033[36m%-28s\033[0m %s\n", $$1, $$2}'
	@echo ""

# ──────────────────────────────────────────────
# Inflow ATS  (focus pipeline)
# Source: /Users/jessica/wrk/wrk-corp/inflow-ats
# ──────────────────────────────────────────────

# Workflow targets will be added here as we build them.
# Pattern (do not uncomment until template + workflow exist):
#
# inflow-feature: ## Plan + implement an inflow-ats feature (SLUG=kebab-description)
# 	@if [ -z "$(SLUG)" ]; then echo "Error: SLUG required."; exit 1; fi
# 	@mkdir -p inflow-ats/features/$(DATE)-$(SLUG)
# 	cd inflow-ats/features/$(DATE)-$(SLUG) && claude --effort $(EFFORT) \
# 		--append-system-prompt-file $(TEMPLATES)/inflow-feature-agent.md \
# 		"Starting feature: $(SLUG). Read the agent prompt, then read inflow-ats/CLAUDE.md. Phase 1 — present a plan. Wait for approval before implementing."

# ──────────────────────────────────────────────
# Thought Leadership Automation  (focus pipeline)
# Source: /Users/jessica/wrk/thought-leadership-automation
# ──────────────────────────────────────────────

# ──────────────────────────────────────────────
# Other pipelines (placeholders — add targets as needed)
# ──────────────────────────────────────────────

# wrk-marketing      → /Users/jessica/wrk/wrk-corp/wrk-marketing
# rage-review-cli    → /Users/jessica/wrk/review-cli
# polymer-help       → /Users/jessica/polymer-help-pipeline
# polymer-instantly  → /Users/jessica/polymer-instantly-pipeline
# polymer-prospect   → /Users/jessica/polymer-prospecting-pipeline
