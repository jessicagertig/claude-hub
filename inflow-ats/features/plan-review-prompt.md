# Inflow ATS — Plan Review (2 Fixed Passes)

A previous agent produced an implementation plan after extensive spec work and adversarial review. By the time the plan was written, the agent's context was likely saturated — file paths may be wrong, safety rules forgotten, findings silently dropped.

Your job: verify the plan is correct, complete, and safe. You run exactly TWO passes across all review angles. No iterative loop — two passes catches real errors without devolving into nitpicking.

## Ground rules

- You are NOT writing code. You are reviewing plan text against the live source tree (path in `REPO-PATH` in the working directory). Read-only.
- Follow `~/claude-hub/inflow-ats/CLAUDE.md` safety rules and all `cursor_rules/` in the inflow-ats repo.
- Do NOT redesign or second-guess the approach — only verify facts and safety.
- Do NOT add suggestions or improvements — that is scope creep from the reviewer.

## Directory structure

All review artifacts go under `reviews/` in the working directory:

```
reviews/
└── plan-review/
    ├── pass-1/
    │   ├── <angle-slug>.md
    │   ├── claude-md-compliance.md
    │   └── verdict.md
    └── pass-2/
        ├── <angle-slug>.md
        ├── claude-md-compliance.md
        └── verdict.md
```

## Inputs (read these first, in order)

1. The spec file (SPEC.md or design-spec.md) — source of truth for what should be built
2. The plan file (plan.md or PLAN.md) — what you're reviewing
3. `approved-decisions.md` if present
4. `reviews/SPEC-REVIEW-COMPLETE.md` if present — the spec review's final state
5. `reviews/REVIEW-ANGLES.md` — the review angles for this feature
6. `~/claude-hub/inflow-ats/CLAUDE.md` and `<REPO>/cursor_rules/core_critical_rules.md` (where `<REPO>` is the path in `REPO-PATH`)

If no plan exists, STOP and tell Jessica there's nothing to review.

## Step 0: Read the review angles (MANDATORY — do this before anything else)

Open and read the file `reviews/REVIEW-ANGLES.md` in the working directory NOW. This file contains the feature-specific review angles generated during Phase 1. It lists every angle you must cover and the files relevant to each.

**Print the list of angles you found in that file before proceeding.** If the file does not exist, STOP and tell Jessica — you cannot run without it.

Every angle in that file must get its own findings file in every pass. Miss an angle and the pass doesn't count. Use the angle slugs from that file as filenames.

## Pass 1

### Per-angle review

For each angle in `reviews/REVIEW-ANGLES.md`, write a file in `reviews/plan-review/pass-1/` using the angle's slug as the filename:

```
# [Angle Name] — Pass 1

## Fact Check
For every concrete claim the plan makes within this angle's scope:
| Claim type | How to verify |
|------------|---------------|
| File path | Glob or ls — does it exist? |
| Class/method/component name | Grep the repo — correct spelling and location? |
| Line numbers | Read the file — is that code actually at those lines? |
| Behavior claims ("this method does X") | Read the method — does it? |
| Schema claims ("this column is type X") | Check db/schema.rb |

## Completeness
Compare the plan against the spec for this angle's scope:
- List every spec requirement this angle covers
- Check each has a corresponding plan step
- Flag any spec requirement not addressed

Plans written under context pressure address early requirements thoroughly and quietly drop later ones.

## Findings
- F1 [BLOCKER] where / what / evidence / fix
- F2 [HIGH] ...
- F3 [MED] ...

(If no findings: "No issues found.")

## Amendments Applied
- plan.md line N: summary of edit
```

### Feasibility checkpoint

For any plan step that depends on external services, subprocess execution, or cross-system communication:
1. List every runtime assumption
2. Has each assumption been proven in the actual target environment?
3. If a step proposes the SAME path that caused the original problem, flag it — that's a circular fix
4. Flag untestable assumptions to Jessica before the implementation agent starts

### Safety compliance

Write `reviews/plan-review/pass-1/claude-md-compliance.md`:
- Read the CLAUDE.md files in the directory tree and `cursor_rules/core_critical_rules.md`
- Does any step violate database safety rules from the global CLAUDE.md?
- Does any step risk breaking existing functionality?
- Does any migration risk data loss?
- Are authorization and policy changes handled correctly?
- Does the plan follow cursor_rules/ for the relevant areas?
- Cite the specific rule for any violation found

### Scope and ordering

- Each step must trace to a specific spec requirement. No "while we're here" improvements.
- Steps that depend on earlier steps are sequenced correctly.
- Independent steps are marked as parallelizable.

### Apply amendments

For every HIGH and BLOCKER finding, apply the concrete fix to the plan now. Verify the edit by re-reading the patched section. MED findings are noted but do not require amendment or block the verdict.

### Pass 1 verdict

Write `reviews/plan-review/pass-1/verdict.md`:
```
# Plan Review — Pass 1 Verdict
**Date:** YYYY-MM-DD HH:MM

## Counts
- BLOCKER: N
- HIGH: N
- MED: N
- LOW: N

## Amendments Applied
- [summary of each amendment]

## Verdict: PASS | FAIL
```

PASS = 0 BLOCKER, 0 HIGH. FAIL = any HIGH+ finding.

## Pass 2: Verify Corrections + Fresh Scrutiny

Re-read the plan as amended by Pass 1.

For each angle in `reviews/REVIEW-ANGLES.md`, write a file in `reviews/plan-review/pass-2/`:

1. Verify every Pass 1 correction for that angle was applied correctly
2. Re-read each plan step in this angle's scope with fresh eyes — Pass 1 may have missed broader issues
3. Check that Pass 1 corrections didn't introduce new inconsistencies
4. One final completeness sweep against the spec for this angle's scope

Write `reviews/plan-review/pass-2/claude-md-compliance.md` — re-verify after amendments.

Write `reviews/plan-review/pass-2/verdict.md` with the same format as Pass 1.

## Final output: reviews/plan-review.md

After both passes, write the consolidated review:

```
# Plan Review

**Source:** [plan file]
**Spec:** [spec file]
**Verdict: APPROVED / NEEDS-REVISION**
**Reviewed:** [date]

## Pass 1 Summary
[One line per angle with finding counts]

## Pass 2 Summary
[One line per angle with finding counts]

## Verdict

APPROVED — plan is factually correct, complete against spec, safe, properly scoped. Implementation agent can execute as-is.

OR

NEEDS-REVISION — [list unresolved issues]. If minor: corrections applied in the Reviewed Plan section below. If fundamental: flag to Jessica — do not attempt to rewrite.

## Reviewed Plan
[Reproduce the corrected plan as a standalone document the implementation agent can consume directly.]
```

## Verdict rules

- **APPROVED** — Both passes clean or only minor corrections (all applied). Plan is ready for implementation.
- **NEEDS-REVISION** — HIGH findings corrected inline. Reviewed Plan section has all corrections. Implementation agent uses the Reviewed Plan.
- **NEEDS-REVISION (fundamental)** — BLOCKER that requires redesign (wrong approach, safety violation, missing major requirement). Flag to Jessica — do not attempt to rewrite the plan.

## Context discipline

You exist to protect the implementation agent from a degraded plan. Stay lean:
- Do NOT explore the codebase beyond verifying specific claims
- Do NOT redesign or second-guess the approach
- Do NOT add suggestions or improvements
- Your Reviewed Plan section IS the implementation agent's input — make it standalone and complete
