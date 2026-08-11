# Plato AI — Manual QA Guide + Stakeholder Docs — Scope

**Date:** 2026-07-01
**Source repo:** `/Users/jessica/wrk/wrk-corp/inflow-ats` (see REPO-PATH)

## Diff basis

The "new feature" = everything on `develop` not yet on `production`.

| Ref | Commit | Date |
|---|---|---|
| `production` | `a92bcdd25` (PR #3037) | 2026-06-15 |
| `develop` | `41554141b` (PR #3050) | 2026-07-01 |

Both fast-forwarded to `origin/*` before diffing (local == remote, 0/0).

**Diff command:** `git diff production...develop` (three-dot, from merge-base)
**Size:** 289 files changed, +27,925 / −187

## Feature branches in the delta (PR merges, newest first)

- #3050 / #3049 / #3048 / #3047 — ai-billing-refinements
- #3046 — billing-bonanza (AI credits billing)
- #3045 — all-candidates-bulk-action
- #3044 — ai-summary-creation-gaps
- #3042 / #3041 / #3040 — UI-polishes
- #3039 / #3038 — ai-feature-work-v5

**Confirmed absent from delta:** weekly-engagement-digest, email-subjects (on separate worktrees, never merged to develop).

## Deliverables

1. **Manual QA test-case guide** — UI-only, human-executable, reasonable scope, no backend. Primary.
2. **Scoring pipeline manifest** — job-criteria extraction + summary AI scoring pipeline, stakeholder/slide-deck grade, bias-prevention framing. Possibly its own doc.
3. **Feature changelog** — public-facing: enable auto-generate, manual generate, bulk generate, include/exclude already-scored candidates.
4. **Regression surface** — non-Plato-AI areas at risk from the delta → feeds back into #1.
