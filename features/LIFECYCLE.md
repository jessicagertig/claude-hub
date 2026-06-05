# Feature Development — Lifecycle

You are the orchestrating agent. You drive this flow from start to finish, spawning sub-agents for each phase. You do NOT stop between phases and tell the user to run commands. You do NOT do the work yourself — you dispatch sub-agents and check their output.

The prompt files in this directory (and any pipeline-specific overrides) are instructions for the sub-agents, not for you. You read them to understand what each phase produces, then spawn a sub-agent to execute.

## How to find your context

1. **Working directory:** You are running from a feature working directory (e.g., `~/claude-hub/<pipeline>/YYYY-MM-DD-feature-name/`).
2. **Pipeline:** The pipeline is the parent directory of your working directory (e.g., `inflow-ats/`, `thought-leadership-automation/`).
3. **Pipeline CLAUDE.md:** Read `~/claude-hub/<pipeline>/CLAUDE.md` for the source repo path, tech stack, conventions sources, and any pipeline-specific rules. Conventions can come from multiple places — the pipeline CLAUDE.md itself, the source repo's own CLAUDE.md, a conventions directory, a reference repo, and the existing codebase patterns (analogs).
4. **REPO-PATH:** The working directory contains a `REPO-PATH` file pointing to the source repo or worktree.

## How to find prompt files

For each phase, look for the prompt file in this order:
1. `~/claude-hub/<pipeline>/features/<prompt-file>` — pipeline-specific override
2. `~/claude-hub/features/<prompt-file>` — generic default

Use whichever exists first. If a pipeline override exists, use it instead of the generic.

## How to spawn a phase

Each phase's work is done by a sub-agent. Give the sub-agent:
1. The prompt file content for that phase (read it and include it in the sub-agent's instructions)
2. The working directory path
3. The pipeline CLAUDE.md path
4. Any context it needs from prior phases
After the sub-agent completes, verify the expected output exists (check the gate condition), then proceed to the next phase.

## Phase 0: Spec Writing

**Prompt file:** `spec-writing-prompt.md`

The sub-agent writes `REPO-PATH` and `SPEC.md` in the working directory.

**Gate:** `SPEC.md` and `REPO-PATH` exist.

---

## Phase 1: Generate Review Angles

**Prompt file:** `generate-review-angles-prompt.md`

The sub-agent reads the spec, identifies subsystems, finds analogs, and writes `reviews/REVIEW-ANGLES.md`.

**Gate:** `reviews/REVIEW-ANGLES.md` exists. **Stop here and present the angles to the user.** They review and approve before you continue. They may add, remove, or modify angles. This is the one human gate in the flow.

---

## Phase 2: Spec Review

**Prompt file:** `spec-review-prompt.md`

Iterative adversarial review. The sub-agent runs up to 5 rounds against the angles in `reviews/REVIEW-ANGLES.md`. Goal: two consecutive clean passes. It amends the spec inline and writes round artifacts under `reviews/spec-round-N/`.

**Gate:** `reviews/SPEC-REVIEW-COMPLETE.md` exists and says READY FOR PLANNING. If ESCALATE: stop and present to the user.

---

## Phase 3: Planning

**Prompt file:** `_base-template.md`

The sub-agent analyzes the codebase, finds pattern precedents, and writes `plan.md`.

**Gate:** `plan.md` exists.

---

## Phase 4: Plan Review

**Prompt file:** `plan-review-prompt.md`

Exactly 2 passes. The sub-agent fact-checks the plan against the live codebase and writes `reviews/plan-review.md`.

**Gate:** `reviews/plan-review.md` verdict is APPROVED, or NEEDS-REVISION with only minor corrections (the Reviewed Plan section has corrections applied). If fundamental issues: stop and flag to the user.

---

## Phase 5: Implementation

**Prompt file:** `impl-prompt.md`

The sub-agent reads the plan (or the Reviewed Plan from `reviews/plan-review.md`) and implements it. It writes code in the repo at the path from `REPO-PATH`.

**Gate:** Implementation is complete, tests pass, summary printed.

If re-entering from Phase 6 (failure report exists), tell the sub-agent to read the most recent `reviews/impl-round-N/FAILURE-REPORT.md` and fix the issues listed there.

---

## Phase 6: Implementation Review

**Prompt file:** `impl-review-prompt.md`

Iterative adversarial review of the implementation. The sub-agent runs the impl angles from `reviews/REVIEW-ANGLES.md`. Up to 5 rounds total across all re-entries between Phase 5 and Phase 6. Goal: two consecutive clean passes.

If a round fails: the sub-agent writes `reviews/impl-round-N/FAILURE-REPORT.md`. Go back to Phase 5 — spawn a new impl sub-agent to fix the issues, then return here for the next round.

**Gate:** `reviews/IMPL-REVIEW-COMPLETE.md` exists and says APPROVED. If ESCALATE: stop and present to the user.

---

## Phase 7: Hardening

**Prompt file:** `hardening-prompt.md`

The sub-agent reads all failure reports and round verdicts, extracts lessons, and adds rules to the pipeline's CLAUDE.md. Writes `reviews/HARDENING-REPORT.md`.

**Gate:** `reviews/HARDENING-REPORT.md` exists. Proceed to Phase 8.

---

## Phase 8: QA Verification

**Prompt file:** `qa-prompt.md`

The sub-agent is the QA orchestrator. It starts the test server via `qa-harness start`, dispatches a seed planner, then runs up to 5 rounds of QA agents. Each round spawns `qa_team_size` (default 3) fresh QA agents sequentially. Goal: two consecutive clean passes (no HIGH+ findings changed).

The orchestrator owns server lifecycle (start once, stop once). Individual QA agents do NOT start or stop the server. Agents execute sequentially because they share the same server and database.

If HIGH+ findings exist after a round, the orchestrator writes a failure report and loops back to Phase 5 (implementation), skipping Phase 6 on re-entry. After the fix, QA resumes at the next round number.

**Config:** The pipeline must have `~/claude-hub/<pipeline>/qa-config.yml` declaring server commands, seed endpoints, auth instructions, and verification layers.

**Gate:** `reviews/QA-COMPLETE.md` exists and says APPROVED. If the 5-round cap is hit without convergence, `reviews/QA-ESCALATION.md` is written instead -- stop and present to the user.

---

## Full artifact trail

```
~/claude-hub/<pipeline>/YYYY-MM-DD-feature-name/
├── SPEC.md
├── REPO-PATH
├── plan.md
└── reviews/
    ├── REVIEW-ANGLES.md
    ├── spec-round-1/
    ├── spec-round-2/
    ├── SPEC-REVIEW-COMPLETE.md
    ├── plan-review.md
    ├── impl-round-1/
    ├── impl-round-2/
    ├── IMPL-REVIEW-COMPLETE.md
    ├── HARDENING-REPORT.md
    ├── seed-plans/
    ├── qa-round-1/
    ├── qa-round-2/
    └── QA-COMPLETE.md
```
