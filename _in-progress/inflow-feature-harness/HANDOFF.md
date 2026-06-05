# Handoff — Inflow Feature Harness

## What this work is

A feature-development harness for inflow-ats that duplicates Nick's actual workflow. Source of truth: Nick's Slack description (2026-05-25) + his repo at `~/Projects/claude-outputs`.

## Current state (as of 2026-06-03)

### Architecture

One orchestrating agent drives the entire flow. It spawns sub-agents for each phase. The orchestrating agent reads `~/claude-hub/inflow-ats/features/LIFECYCLE.md` (pointed to by the hub CLAUDE.md). Sub-agents get the prompt files as their instructions. The orchestrating agent checks gate conditions and keeps going — it does not stop between phases except for the one human gate (angle approval).

### 9 phases, 9 prompt files — all at `~/claude-hub/inflow-ats/features/`

| Phase | Prompt file | Status |
|-------|-------------|--------|
| 0. Spec Writing | `spec-writing-prompt.md` | DONE |
| 1. Generate Review Angles | `generate-review-angles-prompt.md` | DONE — rewritten to produce thematic angles, not layer silos |
| 2. Spec Review | `spec-review-prompt.md` | DONE — reads angles from REVIEW-ANGLES.md |
| 3. Planning | `_base-template.md` | DONE |
| 4. Plan Review | `plan-review-prompt.md` | DONE |
| 5. Implementation | `impl-prompt.md` | DONE |
| 6. Implementation Review | `impl-review-prompt.md` | DONE — reads angles from REVIEW-ANGLES.md |
| 7. Hardening | `hardening-prompt.md` | DONE |

Plus `LIFECYCLE.md` — orchestration instructions for the main agent.

### Key design decisions

- **Sub-agent architecture** — main agent orchestrates, sub-agents execute each phase. Matches Nick's use of ultracode workflows. Main agent never stops to tell Jessica to run commands.
- **Thematic review angles** — angles span layers (like Nick's "state-machine-review", "graphql-contract-review"), not siloed by cursor_rules area. cursor_rules are convention context for the reviewer, not the scope of the review.
- **Full-stack analog + per-layer conventions** — angle generation finds the closest existing end-to-end flow as the primary blueprint. Per-layer conventions (3+ examples) supplement. Analog wins on conflicts.
- **One human gate** — Jessica reviews angles before spec review runs. All other transitions are automatic. Escalation (5-round cap, fundamental redesign, permission boundary) stops the flow.
- **REPO-PATH** — each feature's working directory contains a `REPO-PATH` file pointing to the worktree. Prompts are not hardcoded to one repo path. Supports multiple worktrees.
- **Hardening applies CLAUDE.md directly** — does not touch cursor_rules/.
- **Intervention points match Nick's** — "escalate to Jessica" only at terminal failures.

### Still needed

- **Testing on a real feature** — the flow hasn't been run end-to-end yet
- **QC/QA workflow** — staged testing, independent verification, binary verdict

## What to read

- `~/claude-hub/inflow-ats/features/LIFECYCLE.md` — the orchestration doc
- `~/claude-hub/inflow-ats/CLAUDE.md` — hub rules, points to LIFECYCLE.md
- `approved-decisions.md` — confirmed decisions D1-D9 from brainstorming
- `sub-project-outline.md` — original sub-project list
