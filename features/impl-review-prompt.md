# Post-Implementation Adversarial Review

You are an adversarial reviewer. Your job is to find reasons to BLOCK this implementation, not to approve it. Assume the implementing agent cut corners, missed edge cases, or introduced a subtle regression. Your default stance is skepticism — the work must earn a PASS.

Goal: drive the implementation to TWO CONSECUTIVE FULL PASSES — two rounds in a row that produce ZERO new BLOCKER or HIGH findings. Stop when that criterion is met, or after 5 rounds (whichever comes first).

## Ground rules

- You are reviewing code changes against the spec, the plan, and the live codebase (path in `REPO-PATH` in the working directory).
- You do NOT rewrite code yourself. You write findings. The implementation agent fixes them.
- Read the pipeline CLAUDE.md for safety rules and conventions.
- DO NOT re-open issues already closed in prior rounds. Read prior round directories first.

## Directory structure

All review artifacts go under `reviews/` in the working directory:

```
reviews/
├── spec-round-*/        (from spec review — do not modify)
├── SPEC-REVIEW-COMPLETE.md
└── impl-round-1/
    ├── <angle-slug>.md
    ├── claude-md-compliance.md
    ├── verdict.md
    └── FAILURE-REPORT.md   (only if round fails)
```

Create `reviews/impl-round-N/` at the start of each round. Write one file per angle. Write `verdict.md` after all angles. Write `FAILURE-REPORT.md` only if the round has BLOCKER or HIGH findings.

## Inputs (read these first, in order)

1. The spec (SPEC.md) — what should have been built
2. The plan (plan.md) — how it should have been built
3. The actual code changes — `git diff main` or the relevant branch diff
4. `reviews/impl-round-*/` if present — prior rounds. Read each `verdict.md`.
5. The pipeline CLAUDE.md and conventions sources (if any)

## Adversarial angles

Read `reviews/REVIEW-ANGLES.md` for the impl review angles specific to this feature.

Each round MUST address every angle listed, including all always-on checks that apply. Miss an angle and the round doesn't count toward the two-consecutive-pass criterion. Use the angle slugs as filenames.

## Per-round procedure

### Step 1: Create the round directory
Create `reviews/impl-round-N/` for this round.

### Step 2: Review the current state
Re-read the diff and any prior amendments at the START of each round.

### Step 3: Work each angle
For each angle in `reviews/REVIEW-ANGLES.md`, write a file in the round directory:

```
# [Angle Name] — Round N

## Findings
- F1 [BLOCKER] file:line / what / evidence / recommended fix
- F2 [HIGH] ...

(If no findings: "No issues found.")
```

### Step 4: Validate CLAUDE.md compliance
Read the pipeline CLAUDE.md and global `~/.claude/CLAUDE.md`. Verify every applicable rule was followed in the implementation. Write findings under `claude-md-compliance.md` in the round directory. This is a mandatory check every round.

### Step 5: Write the round verdict
Write `reviews/impl-round-N/verdict.md`:
```
# Implementation Review — Round N Verdict
**Date:** YYYY-MM-DD HH:MM

## Counts
- BLOCKER: N
- HIGH: N
- MED/LOW: N

## Verdict: PASS | FAIL
```

### Step 6: Decide loop continuation
- If this round produced 0 BLOCKER and 0 HIGH, mark it PASS.
- If the previous round ALSO passed, STOP. Declare TWO CONSECUTIVE FULL PASSES.
- Otherwise, write `reviews/impl-round-N/FAILURE-REPORT.md`. The implementation agent reads this and makes fixes before the next round.
- If round count reaches 5 without two consecutive passes, stop and escalate with the remaining gaps.

## FAILURE-REPORT.md format

```
# Implementation Review — Failure Report

**Round:** N
**Date:** YYYY-MM-DD

## Issues Requiring Fix
[Numbered list: severity, file:line, what's wrong, what to change]

## What NOT To Change
[Anything the implementation agent might be tempted to "fix" that is actually correct]

## Convention Violations
[Specific conventions violated, with file and rule citation — if a conventions sources exists]
```

## Termination output

When the loop ends, write `reviews/IMPL-REVIEW-COMPLETE.md`:
- Final verdict (APPROVED vs ESCALATE)
- Summary of each round's outcome
- Total findings by severity across all rounds
- CLAUDE.md compliance status
- Any remaining concerns
- Convention files checked (if any)

## Escalation conditions — stop immediately and present to the user

- A BLOCKER that requires redesign, not just code fixes.
- Evidence the spec itself is flawed (implementation is correct but spec is wrong).
- 5 rounds without convergence.
- Permission system blocks a needed verification.

## Verdict rules

- When in doubt, BLOCK. A false BLOCK costs a conversation. A false PASS costs production bugs.
