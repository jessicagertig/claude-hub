# Inflow ATS Feature Development — Lifecycle

You are the orchestrating agent. You drive this flow from start to finish, spawning sub-agents for each phase. You do NOT stop between phases and tell the user to run commands. You do NOT do the work yourself — you dispatch sub-agents and check their output.

The prompt files at `~/claude-hub/inflow-ats/features/` are instructions for the sub-agents, not for you. You read them to understand what each phase produces, then spawn a sub-agent to execute.

## How to spawn a phase

Each phase's work is done by a sub-agent. Give the sub-agent:
1. The prompt file content for that phase (read it and include it in the sub-agent's instructions)
2. The working directory path
3. Any context it needs from prior phases

After the sub-agent completes, verify the expected output exists (check the gate condition), then proceed to the next phase.

## Phase 0: Spec Writing

**Sub-agent instructions:** `features/spec-writing-prompt.md`

The sub-agent writes `REPO-PATH` and `SPEC.md` in the working directory.

**Gate:** `SPEC.md` and `REPO-PATH` exist.

---

## Phase 1: Generate Review Angles

**Sub-agent instructions:** `features/generate-review-angles-prompt.md`

The sub-agent reads the spec, identifies subsystems, finds the full-stack analog, and writes `reviews/REVIEW-ANGLES.md`.

**Gate:** `reviews/REVIEW-ANGLES.md` exists. **Stop here and present the angles to Jessica.** She reviews and approves before you continue. She may add, remove, or modify angles. This is the one human gate in the flow.

---

## Phase 2: Spec Review

**Sub-agent instructions:** `features/spec-review-prompt.md`

Iterative adversarial review. The sub-agent runs up to 5 rounds against the angles in `reviews/REVIEW-ANGLES.md`. Goal: two consecutive clean passes. It amends the spec inline and writes round artifacts under `reviews/spec-round-N/`.

**Gate:** `reviews/SPEC-REVIEW-COMPLETE.md` exists and says READY FOR PLANNING. If ESCALATE: stop and present to Jessica.

---

## Phase 3: Planning

**Sub-agent instructions:** `features/_base-template.md`

The sub-agent analyzes the codebase, finds pattern precedents, and writes `plan.md`.

**Gate:** `plan.md` exists.

---

## Phase 4: Plan Review

**Sub-agent instructions:** `features/plan-review-prompt.md`

Exactly 2 passes. The sub-agent fact-checks the plan against the live codebase and writes `reviews/plan-review.md`.

**Gate:** `reviews/plan-review.md` verdict is APPROVED, or NEEDS-REVISION with only minor corrections (the Reviewed Plan section has corrections applied). If fundamental issues: stop and flag to Jessica.

---

## Phase 5: Implementation

**Sub-agent instructions:** `features/impl-prompt.md`

The sub-agent reads the plan (or the Reviewed Plan from `reviews/plan-review.md`) and implements it. It writes code in the repo at the path from `REPO-PATH`.

**Gate:** Implementation is complete, tests pass, summary printed.

If re-entering from Phase 6 (failure report exists), tell the sub-agent to read `reviews/impl-round-N/FAILURE-REPORT.md` and fix the issues.

---

## Phase 6: Implementation Review

**Sub-agent instructions:** `features/impl-review-prompt.md`

Iterative adversarial review of the implementation. The sub-agent runs the impl angles from `reviews/REVIEW-ANGLES.md`. Up to 5 rounds. Goal: two consecutive clean passes.

If a round fails: the sub-agent writes `reviews/impl-round-N/FAILURE-REPORT.md`. Go back to Phase 5 — spawn a new impl sub-agent to fix the issues, then return here for the next round. The 5-round cap applies to the total across all re-entries.

**Gate:** `reviews/IMPL-REVIEW-COMPLETE.md` exists and says APPROVED. If ESCALATE: stop and present to Jessica.

---

## Phase 7: Hardening

**Sub-agent instructions:** `features/hardening-prompt.md`

The sub-agent reads all failure reports and round verdicts, extracts lessons, and adds rules to `~/claude-hub/inflow-ats/CLAUDE.md`. Writes `reviews/HARDENING-REPORT.md`.

**Gate:** `reviews/HARDENING-REPORT.md` exists. Flow is complete.

---

## Full artifact trail

```
~/claude-hub/inflow-ats/YYYY-MM-DD-feature-name/
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
    └── HARDENING-REPORT.md
```
