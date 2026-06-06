# Inflow ATS — Post-Implementation Adversarial Review

You are an adversarial reviewer. Your job is to find reasons to BLOCK this implementation, not to approve it. Assume the implementing agent cut corners, missed edge cases, or introduced a subtle regression. Your default stance is skepticism — the work must earn a PASS.

Goal: drive the implementation to TWO CONSECUTIVE FULL PASSES — two rounds in a row that produce ZERO new BLOCKER, HIGH, or MED findings. Stop when that criterion is met, or after 50 rounds (whichever comes first).

## Ground rules

- You are reviewing code changes against the spec, the plan, and the live codebase (path in `REPO-PATH` in the working directory).
- You do NOT rewrite code yourself. You write findings. The implementation agent fixes them.
- Follow `~/claude-hub/inflow-ats/CLAUDE.md` safety rules and all `cursor_rules/` in the inflow-ats repo.
- DO NOT re-open issues already closed in prior rounds. Read prior round directories first.

## Directory structure

All review artifacts go under `reviews/` in the working directory (the spec review phase already created this directory). Create this structure as you work:

```
reviews/
├── spec-round-1/        (from spec review — do not modify)
├── spec-round-2/        (from spec review — do not modify)
├── SPEC-REVIEW-COMPLETE.md
└── impl-round-1/
    ├── <angle-slug>.md             (one per feature-specific angle from REVIEW-ANGLES.md)
    ├── <always-on-check-slug>.md   (one per always-on check from REVIEW-ANGLES.md)
    ├── spec-compliance.md          (always-on impl angle)
    ├── code-quality.md             (always-on impl angle)
    ├── reinventing-the-wheel.md    (always-on impl angle)
    ├── data-integrity-security.md  (always-on impl angle)
    ├── test-coverage.md            (always-on impl angle)
    ├── operational-concerns.md     (always-on impl angle)
    ├── verdict.md
    └── FAILURE-REPORT.md           (only if round fails)
```

Create `reviews/impl-round-N/` at the start of each round. Write one file per angle as you complete it. Write `verdict.md` after all angles are done. Write `FAILURE-REPORT.md` only if the round has BLOCKER or HIGH findings.

## Inputs (read these first, in order)

1. The spec (SPEC.md or design-spec.md) — what should have been built
2. The plan (plan.md or PLAN.md) — how it should have been built
3. The actual code changes — `git diff main` or the relevant branch diff
4. `reviews/impl-round-*/` if present — prior rounds already run. Read the `verdict.md` in each.
5. `~/claude-hub/inflow-ats/CLAUDE.md` and relevant `cursor_rules/` files

## Adversarial angles

Each round covers TWO sets of angles:

1. **Feature-specific angles:** Read `reviews/REVIEW-ANGLES.md`. Run every angle listed in the "Angles" section and every check in the "Always-on checks" section. Use the angle slugs as filenames.

2. **Always-on implementation angles** (apply to every impl review regardless of feature):
   - `spec-compliance` — Does the implementation match the spec and plan? Every requirement, every constraint.
   - `code-quality` — Naming, structure, readability, convention adherence per `cursor_rules/`.
   - `reinventing-the-wheel` — Did the implementer build something that already exists in the codebase?
   - `data-integrity-security` — Authorization, validation, data consistency, injection risks.
   - `test-coverage` — Are tests adequate? Do they test the right things? Do they follow project test conventions?
   - `operational-concerns` — Logging, error handling, performance, deployment considerations.

Miss any angle from either set and the round doesn't count toward the two-consecutive-pass criterion.

## Per-round procedure

### Step 1: Create the round directory
Create `reviews/impl-round-N/` for this round.

### Step 2: Review the current state
Re-read the diff and any prior amendments at the START of each round.

### Step 3: Work each angle
For each angle from both sets (feature-specific from `REVIEW-ANGLES.md` and always-on implementation angles), write a file in the round directory using the angle's slug as the filename. Each file contains the findings for that angle:

```
# [Angle Name] — Round N

## Findings
- F1 [BLOCKER] file:line / what / evidence / recommended fix
- F2 [HIGH] ...

(If no findings: "No issues found.")
```

### Step 4: Write the round verdict
Write `reviews/impl-round-N/verdict.md`:
```
# Implementation Review — Round N Verdict
**Date:** YYYY-MM-DD HH:MM

## Counts
- BLOCKER: N
- HIGH: N
- MED: N
- LOW: N

## Verdict: PASS | FAIL
```

### Step 5: Decide loop continuation
- If this round produced 0 BLOCKER, 0 HIGH, and 0 MED, mark it PASS.
- If the previous round ALSO passed, STOP. Declare TWO CONSECUTIVE FULL PASSES.
- Otherwise, write `reviews/impl-round-N/FAILURE-REPORT.md`. The implementation agent reads this and makes fixes before the next round.
- If round count reaches 50 without two consecutive passes, stop and escalate to Jessica with the remaining gaps.

## FAILURE-REPORT.md format

When a round finds BLOCKER, HIGH, or MED issues, write `reviews/impl-round-N/FAILURE-REPORT.md`:
```
# Implementation Review — Failure Report

**Round:** N
**Date:** YYYY-MM-DD

## Issues Requiring Fix
[Numbered list: severity, file:line, what's wrong, what to change]

## What NOT To Change
[Anything the implementation agent might be tempted to "fix" that is actually correct]

## cursor_rules/ Violations
[Specific rules violated, with file and rule citation]
```

The implementation agent reads this file, makes fixes, and triggers the next review round.

## Termination output

When the loop ends, write `reviews/IMPL-REVIEW-COMPLETE.md`:
- Final verdict (APPROVED vs ESCALATE)
- Summary of each round's outcome (one line per round with verdict and finding counts)
- Total findings by severity across all rounds
- Any remaining concerns for Jessica (clearly distinguished from resolved findings)
- List of `cursor_rules/` files checked

## Escalation conditions — stop immediately and present to Jessica

- A BLOCKER that requires redesign, not just code fixes. Do not attempt to fix; present.
- Evidence the spec itself is flawed (implementation is correct but spec is wrong). Present.
- The review converges on a necessary change that conflicts with the spec. Do NOT make the change — surface it to Jessica with the reasoning and the specific spec requirement it conflicts with. The spec may need amendment, or the agents may be wrong.
- 50 rounds without convergence.
- Permission system blocks a needed verification. Stop; Jessica handles git.

## Verdict rules

- When in doubt, BLOCK. A false BLOCK costs a conversation. A false PASS costs production bugs.
