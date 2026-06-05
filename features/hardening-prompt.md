# CLAUDE.md Hardening from Failure Reports

A review agent has produced failure reports documenting issues found during adversarial review. All review artifacts are under `reviews/` in the working directory. Your job: extract the lessons and harden the pipeline's CLAUDE.md so these mistakes are never repeated.

## Ground rules

- Read the failure reports first. Understand what went wrong and why.
- Only add rules that prevent REAL failures that actually happened. Do not add speculative rules.
- Each new rule must cite the failure that motivated it.
- Keep rules concise — one sentence if possible, never more than a short paragraph.
- Do not duplicate rules that already exist. Check before adding.
- Do not weaken or remove existing rules.

## Inputs

1. `reviews/impl-round-*/FAILURE-REPORT.md` — failure reports from implementation review rounds
2. `reviews/impl-round-*/verdict.md` — round verdicts with finding counts
3. `reviews/IMPL-REVIEW-COMPLETE.md` — terminal verdict and summary
4. `reviews/spec-round-*/verdict.md` — spec review verdicts (for patterns that started at the spec level)
5. The pipeline CLAUDE.md — the current project-level rules

## Process

### Step 1: Extract lessons
For each BLOCKER and HIGH finding in the failure reports:
- What went wrong?
- Why did the implementing agent make this mistake?
- What rule, if it existed, would have prevented it?
- Is this a one-off or a pattern likely to recur?

Skip one-offs (typos, wrong line numbers). Focus on patterns — the kind of mistake an agent would make again on a different feature.

### Step 2: Check for existing coverage
For each candidate rule, check:
- Is this already covered in the pipeline CLAUDE.md?
- If covered but the agent violated it anyway, the fix is making the existing rule more prominent or specific — not adding a duplicate.

### Step 3: Write the rules
Add new rules directly to the pipeline's CLAUDE.md under a "Known Failure Patterns" section (create it if it doesn't exist). Do not modify convention files in the source repo.

### Step 4: Document what you did
Write `reviews/HARDENING-REPORT.md`:
```
# CLAUDE.md Hardening Report

**Source:** [failure report files]
**Date:** YYYY-MM-DD

## Rules Added
- [Rule text] — motivated by [finding reference]

## Existing Rules That Were Violated
- [Rule location]: [Rule text] — violated in [finding reference]. Action taken: [made more prominent / added example / no change needed]

## Findings Skipped (one-offs, not patterns)
- [Finding reference]: [why it's a one-off]
```
