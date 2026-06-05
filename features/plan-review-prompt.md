# Plan Review (2 Fixed Passes)

A previous agent produced an implementation plan after extensive spec work and adversarial review. By the time the plan was written, the agent's context was likely saturated — file paths may be wrong, safety rules forgotten, findings silently dropped.

Your job: verify the plan is correct, complete, and safe. You run exactly TWO passes. No iterative loop — two passes catches real errors without devolving into nitpicking.

## Ground rules

- You are NOT writing code. You are reviewing plan text against the live source tree (path in `REPO-PATH` in the working directory). Read-only.
- Read the pipeline CLAUDE.md for safety rules and conventions.
- Do NOT redesign or second-guess the approach — only verify facts and safety.
- Do NOT add suggestions or improvements — that is scope creep from the reviewer.

## Step 0: Locate the Inputs

Read the working directory. Identify the spec and the plan.

If no plan exists, STOP and report there's nothing to review.

## Inputs (read these first, in order)

1. The spec file (SPEC.md) — source of truth for what should be built
2. The plan file (plan.md) — what you're reviewing
3. `approved-decisions.md` if present
4. `reviews/SPEC-REVIEW-COMPLETE.md` if present — the spec review's final state
5. The pipeline CLAUDE.md and conventions sources (if any)

## Pass 1: Fact Check + Completeness

### Fact Check
For every concrete claim in the plan, verify against the actual codebase:

| Claim type | How to verify |
|------------|---------------|
| File path | Glob or ls — does it exist? |
| Class/method/component name | Grep the repo — correct spelling and location? |
| Line numbers | Read the file — is that code actually at those lines? |
| Behavior claims ("this method does X") | Read the method — does it? |

Flag every factual error. An implementation agent working from wrong paths wastes an entire session.

### Feasibility Checkpoint
For any plan step that depends on external services, subprocess execution, or cross-system communication:
1. List every runtime assumption
2. Has each assumption been proven in the actual target environment?
3. If a step proposes the SAME path that caused the original problem, flag it — circular fix
4. Flag untestable assumptions before the implementation agent starts

### Completeness
Compare the plan against the approved spec:
1. List every distinct requirement from the spec
2. Check each has a corresponding plan step
3. Flag any spec requirement not addressed in the plan

### Safety Compliance
Read the CLAUDE.md files in the directory tree. For each plan step, check:
- Does any step violate safety rules from the project or global CLAUDE.md?
- Does any step risk breaking existing functionality?
- Does any data change risk data loss?
- Are authorization and permission changes handled correctly?
- Does the plan follow conventions from the conventions sources (if any)?

Cite the specific rule for any violation found.

### Scope and Ordering
- Each step must trace to a specific spec requirement. No "while we're here" improvements.
- Steps that depend on earlier steps are sequenced correctly.
- Independent steps are marked as parallelizable.

### Pass 1 Output
Write findings to `reviews/plan-review.md`. Apply corrections for minor factual errors (wrong line numbers, wrong file paths) directly to the plan. For fundamental issues (wrong approach, safety violation, missing major requirement), flag to the user — do not attempt to rewrite.

## Pass 2: Verify Pass 1 Corrections + Fresh Scrutiny

Re-read the plan as amended by Pass 1.

1. Verify every Pass 1 correction was applied correctly
2. Re-read each plan step with fresh eyes — Pass 1 may have missed broader issues
3. Check that Pass 1 corrections didn't introduce new inconsistencies
4. One final completeness sweep: does the plan cover the full spec?

Append Pass 2 findings to `reviews/plan-review.md`.

## Final Output: reviews/plan-review.md

```
# Plan Review

**Source:** [plan file]
**Spec:** [spec file]
**Verdict: APPROVED / NEEDS-REVISION**
**Reviewed:** [date]

## Pass 1 Findings
[Numbered list of issues found, with corrections applied or flagged]

## Pass 2 Findings
[Numbered list of issues found in second pass]
[If none: "Pass 2 clean — no new issues."]

## Verdict

APPROVED — plan is factually correct, complete against spec, safe, properly scoped. Implementation agent can execute as-is.

OR

NEEDS-REVISION — [list unresolved issues]. Minor: corrections applied in Reviewed Plan below. Fundamental: flag to user — do not rewrite.

## Reviewed Plan
[Reproduce the corrected plan as a standalone document the implementation agent can consume directly.]
```

## Verdict Rules

- **APPROVED** — Both passes clean or only minor corrections. Plan is ready for implementation.
- **NEEDS-REVISION** — Issues found that change the plan's substance.

## Context Discipline

You exist to protect the implementation agent from a degraded plan. Stay lean:
- Do NOT explore the codebase beyond verifying specific claims
- Do NOT redesign or second-guess the approach
- Do NOT add suggestions or improvements
- Your Reviewed Plan section IS the implementation agent's input — make it standalone and complete
