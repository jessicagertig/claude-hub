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

Adversarial review of the implementation. The orchestrator manages the Phase 5↔6 loop — each review round is a FRESH sub-agent session running ALL angles from `reviews/REVIEW-ANGLES.md`. Goal: two consecutive clean passes.

**The orchestrator loop:**

1. Spawn a fresh Phase 6 sub-agent. It runs all angles against the current state of the code and writes findings to `reviews/impl-round-N/`.
2. If the round FAILS (any HIGH+) → the sub-agent writes `reviews/impl-round-N/FAILURE-REPORT.md`. Go to step 3.
3. Spawn a Phase 5 sub-agent to fix the issues listed in the failure report.
4. After the fix, spawn a NEW Phase 6 sub-agent (fresh session, all angles, full scrutiny of the entire codebase including the fix agent's changes). Go to step 1.

**Exit condition:** The loop exits when a Phase 6 round produces 0 HIGH+ findings — a full adversarial review across all angles that finds nothing to fix. Write `reviews/IMPL-REVIEW-COMPLETE.md`.

**Escalation (round cap hit):** If the loop reaches 50 rounds without a clean pass, write `reviews/IMPL-REVIEW-ESCALATION.md` listing: all unresolved HIGH+ findings, all fixes applied during the loop that have NOT been followed by a clean review round (unreviewed fixes), and the full round history. Stop and present to Jessica. The unreviewed fixes are the most critical part — those are code changes that shipped into the branch without passing adversarial review.

Every Phase 6 round is a fresh agent. The fix agent's changes get the same adversarial scrutiny as the original implementation — all angles, not just "did the fix resolve the original finding." This is critical: fix agents can write substantial new code that introduces new issues.

**Round cap:** 50 total rounds across all iterations of the loop.

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
