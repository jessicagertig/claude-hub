# Hardening Report -- AI Scoring Integration

**Date:** 2026-06-12
**Feature:** AI Scoring Integration (ai-scoring-v3)
**Review rounds analyzed:** Spec rounds 1-4, Plan review passes 1-2, Impl rounds 1-5

## Findings Analyzed

### Impl Round 1: 3 HIGH, 3 MED

| ID | Severity | Description | Rule action |
|----|----------|-------------|-------------|
| F1 | HIGH | Dictation garbage committed to file | Skip -- one-off (dictation artifact, not a code pattern) |
| F5 | HIGH | `AiJobApplicationSummaryStatus` never created for auto-triggered evaluations | **New rule #16** -- companion records via model callback |
| F7 | HIGH | Three core service specs missing | Already covered by existing rule #3 (specs must include test requirements) |
| F3 | MED | Double credit consumption risk on resume | Skip -- pre-existing pattern, acknowledged as acceptable |
| F6 | MED | `AiApiRequest.create` return value unchecked | Skip -- matches existing analog pattern |
| F8 | MED | Test helper enum compatibility | Skip -- one-off |

### Impl Round 3: 1 BLOCKER

| ID | Severity | Description | Rule action |
|----|----------|-------------|-------------|
| B1 | BLOCKER | 12 files with critical implementation changes never committed; Rounds 1-2 reviewed working tree instead of committed code | **New rule #15** -- review committed code, not working tree |

### Spec Round 1: 4 HIGH, 7 MED

| ID | Severity | Description | Rule action |
|----|----------|-------------|-------------|
| F1-F2 | HIGH | `Summary::Generate` status references not updated for redesigned enum | Already covered by rules #5 (list all modified files) and #6 (rename cascades) -- the spec redesigned the enum but didn't enumerate cascading changes to existing code |
| F3 | HIGH | `destroy_previous_textract_results` callback safety with new pipeline stages | Skip -- domain-specific, not a pattern |
| F4 | HIGH | Job enqueued inside `before_update` (inside transaction) | Skip -- domain-specific, documented as safe |
| MED findings | MED | Resume points incomplete, integer renumbering, guard gaps, overwrite paths, `update` vs `update_columns`, prompt file count, missing test plan | All caught and amended in spec review. Test plan gap already covered by rule #3 |

### Plan Review: 1 HIGH, 4 MED

| ID | Severity | Description | Rule action |
|----|----------|-------------|-------------|
| F1 | HIGH | Orchestrator case statement omitted `status_retrying?` | Skip -- one-off omission in plan, not a pattern |
| F2-F5 | MED | Line number error, audit omission, comment vs task step, error status mismatch | Skip -- plan-level precision issues, all caught in review |

## New Rules Added

### Rule 15: Implementation reviews must review committed code, not the working tree

Review agents must check `git diff HEAD` before starting. If uncommitted changes exist, require a commit first or explicitly note the limitation. A PASS on working-tree code that was never committed is meaningless.

**Why this is a pattern, not a one-off:** The failure mode is structural -- review agents that read files from disk (which is the natural thing to do) will always see the working tree, not the committed branch. Without an explicit check, this will recur on any feature where the implementation agent develops incrementally and forgets to commit intermediate work. Two consecutive review rounds missed this.

### Rule 16: Companion records: create via model callback, not individual call sites

When a model has a companion record that must exist whenever the parent exists, create it via `after_commit` callback with `find_or_create_by`. Individual call-site creation misses code paths.

**Why this is a pattern, not a one-off:** The codebase has multiple models with companion records (status records, summary records). Any new companion record created only in one interactor will silently miss other creation paths. The auto-trigger path (the most common path for AI summaries) was completely uncovered. The fix -- an `after_commit` callback -- is the idiomatic Rails solution and should be the default pattern going forward.

## Rules NOT Added (with reasoning)

1. **Dictation garbage in committed files (F1):** One-off. Not a code pattern -- it's a workflow artifact of voice-to-text input.

2. **Spec enum redesign cascade (Spec R1 F1-F2):** Already covered by existing rules #5 (list all modified files) and #6 (rename cascades). The spec failed to enumerate cascading changes, which is exactly what those rules address.

3. **Missing test specs (F7):** Already covered by existing rule #3 (specs must include test requirements). The spec was amended in spec review to add a test plan section.

4. **Plan omissions (Plan F1-F5):** Plan-level precision issues. All were caught by plan review and amended. Not indicative of a recurring code pattern.

## Existing Rules Validated

These existing rules were validated by this feature's review cycle (they prevented failures or caught them correctly):

- **Rule #3** (test requirements): Spec review Round 1 caught missing test plan section
- **Rule #5** (list all modified files): Would have caught the enum cascade if applied at spec time
- **Rule #6** (rename cascades): Directly relevant to the enum redesign -- impl review verified all stale references were updated
- **Rule #14** (analog structural matching): Impl review verified bulk controller parameter pattern and job exhaustion blocks matched analogs

## Files Modified

- `~/claude-hub/inflow-ats/CLAUDE.md` -- added rules #15 and #16 under Known Failure Patterns
